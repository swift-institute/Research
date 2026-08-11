# IO Architecture: Layering, Domain Witnesses, and Strategy Composition

<!--
---
version: 1.0.0
last_updated: 2026-04-20
status: RECOMMENDATION
tier: 2
scope: cross-package
related:
  - swift-io-thesis.md
  - io-algebraic-effects-foundation.md
  - io-witness-shape-selection.md
  - io-witness-capability-runner-split.md
  - ../../../swift-foundations/swift-io/Sources/IO/IO+Default.swift
  - ../../../swift-foundations/swift-io/Sources/IO Blocking/
  - ../../../swift-foundations/swift-io/Sources/IO Events/README.md
  - ../../../swift-foundations/swift-io/Sources/IO Completions/README.md
  - ../../../swift-foundations/swift-threads/Sources/Thread Pool/
---
-->

## Context

Through a sequence of design conversations in April 2026, a coherent
architecture emerged for swift-io and its downstream consumers
(swift-sockets, swift-file-system, swift-server). Individual pieces
were decided or sketched in separate notes; this document harmonizes
them and records the resulting picture.

### Decisions that feed into this

- **swift-io-thesis v2.0** — swift-io encodes an algebraic effect
  theory at L1; `IO<Capabilities>` is generic over domain-specific
  capability sets; only the dictionary encoding ships.
- **io-witness-shape-selection** — Shape F (capability + runner split
  bundled by `IO<C>` — formerly `IO.Bound`) wins; adopted with flat
  error.
- **io-algebraic-effects-foundation §6** — Socket / File / Server etc.
  extend Σ_IO by signature coproduct; each domain carries its own
  capability set.
- **swift-threads extraction** — `Kernel.Thread.Pool.run` moved out
  of swift-io (2026-04-14 strict-mission refactor) and into swift-
  threads; swift-io's `IO.Blocking` collapsed to a shard provider.
- **swift-io-primitives minimum core** — L1 now holds
  `IO<Capabilities>` and `IO.Runner` only; no fixed capability set,
  no strategy types.

### The remaining open questions

1. How do domain witnesses (Socket.IO, File.IO, Server.IO) get
   constructed against the "best available" platform IO mechanism
   without re-deriving platform selection per domain?
2. Is a new `IO.Strategy` type needed to keep strategy composition
   open to third-party extensions, or does the existing L1 surface
   (`IO<Capabilities>` + factory methods) already provide openness?
3. Should the pinned-actor pattern currently in
   `IO.Blocking.Actor` be generalized as a shared primitive, and
   where should it live?
4. Can the existing `IO Blocking` module be removed, and what (if
   anything) would be lost?

## Question

**How should IO strategies compose across per-domain witnesses so that:**

- The platform unification already done at swift-kernel
  (`Kernel.Event.Driver`, `Kernel.Completion.Driver`) is fully
  leveraged without duplication at higher layers.
- Each domain package (swift-io, swift-sockets, swift-file-system,
  swift-server) ships factories that pair its `Capabilities` with
  the best available IO mechanism, without re-deriving platform
  selection logic per domain.
- The strategy surface remains open to third-party extensions
  without introducing closed-system machinery.
- Blocking, events, and completions are expressed as uniformly as
  their semantics allow, accepting the asymmetry where it is real.

## Analysis

### The four-layer picture

```
L1 Primitives
├── swift-kernel-primitives     Kernel.Descriptor, Kernel.Event, Kernel.Completion
├── swift-executors             Kernel.Thread.Executor (+ Sharded, Polling, Completion variants)
├── swift-threads               Kernel.Thread.Pool (admission-gated dispatch)
│                               Kernel.Thread.Actor (proposed: pinned-actor primitive)
└── swift-io-primitives         IO<Capabilities> + IO.Runner (minimum core)

L2 Standards (per-platform encodings)
└── swift-darwin-standard / swift-linux-standard  (kqueue / epoll / io_uring SQE-CQE)

L3 Foundations
└── swift-io                    IO.Event.Actor (reactor; owns Kernel.Thread.Executor.Polling + Kernel.Event.Driver)
                                IO.Completion.Actor (proactor; owns Kernel.Thread.Executor.Completion + Kernel.Completion.Driver)
                                Basic-fd-byte-ops Capabilities + factories

L3 Domain packages
├── swift-sockets               Socket.Capabilities + Kernel.Thread.Actor extensions + factories
├── swift-file-system           File.Capabilities + extensions + factories
└── swift-server                Server.Capabilities + extensions + factories
```

Each layer owns exactly one concern:
- **Kernel primitives** unify platform mechanisms (kqueue/epoll as
  `Kernel.Event.Driver`; io_uring as `Kernel.Completion.Driver`).
- **Executor/thread primitives** provide dispatch mechanisms
  (admission-gated pool; pinned single-thread executor).
- **L1 IO primitives** define the witness shape (`IO<C>` + `Runner`)
  without committing to a capability set.
- **L3 strategy actors** inherit the kernel's platform unification
  and provide a per-call async surface (`ready(…)`, `submit(…)`).
- **L3 domain packages** define their `Capabilities` structs and
  write per-(domain × strategy) factories that wire capability
  closures to strategy actors.

### Platform unification leverage

Already done. `Kernel.Event.Driver.platform()` selects kqueue on
Darwin, epoll on Linux. `Kernel.Completion.Driver.platform()`
selects io_uring on Linux (throws elsewhere until IOCP lands).
These L1 witnesses are consumed by swift-io's strategy actors:

- `IO.Event.Actor()` constructs a `Kernel.Event.Driver` via
  `.platform()` — consumer code is Darwin/Linux-agnostic.
- `IO.Completion.Actor()` constructs a `Kernel.Completion.Driver`
  via `.platform()` — throws on unsupported platforms, which the
  consumer's `try?` pattern handles.

**No per-domain platform code is needed beyond the `#if` that
decides which strategy actor to try first.**

### Option A — Closed enum for strategy selection

```swift
public enum IO.Strategy {
    case completions
    case events
    case blocking
}
```

**Pros**: simple, exhaustive.

**Cons**:
- Closed system: adding a 4th strategy is a semantically expanding
  change; all `switch` sites must add handling (or use `@unknown
  default` which defeats exhaustiveness).
- Third-party strategies are impossible.
- Test doubles must either pretend to be an existing case or escape
  the enum via a non-canonical path.
- Fallback composition is hardcoded in a `switch` body; user-level
  composition is limited.

Eliminated.

### Option B — Witness-struct `IO.Strategy<Capabilities>`

```swift
public struct IO.Strategy<Capabilities: Sendable>: Sendable {
    public let tryMake: @Sendable () -> IO<Capabilities>?
}

extension IO.Strategy {
    public func orElse(_ fallback: Self) -> Self {
        IO.Strategy { tryMake() ?? fallback.tryMake() }
    }
}
```

**Pros**: open; composable via `.orElse`; matches ecosystem witness
philosophy; test doubles are first-class values.

**Cons**: introduces a new L1 public type whose function is
entirely reified from closure application; the composition it
provides (`.orElse`) is the same thing `try? X else try? Y else Z`
does at the call site; the openness it provides is already what
"any package may add a factory method" provides for free; the
type is decoration, not semantics.

Eliminated.

### Option C — No strategy type; factory methods ARE the strategies

```swift
// Per-domain (e.g., swift-sockets)
extension IO where Capabilities == Socket.Capabilities {
    public static func blocking(executor: Kernel.Thread.Executor) -> IO<Socket.Capabilities> { ... }
    public static func events(on reactor: IO.Event.Actor) -> IO<Socket.Capabilities> { ... }
    public static func completions(on proactor: IO.Completion.Actor) -> IO<Socket.Capabilities> { ... }

    public static func `default`() -> IO<Socket.Capabilities> {
        #if os(Linux)
        if Kernel.IO.Uring.isSupported,
           let proactor = try? IO.Completion.Actor() {
            return .completions(on: proactor)
        }
        if let reactor = try? IO.Event.Actor() {
            return .events(on: reactor)
        }
        return .blocking(executor: Kernel.Thread.Executor())
        #elseif canImport(Darwin)
        if let reactor = try? IO.Event.Actor() {
            return .events(on: reactor)
        }
        return .blocking(executor: Kernel.Thread.Executor())
        #else
        return .blocking(executor: Kernel.Thread.Executor())
        #endif
    }
}
```

**Pros**:
- Zero new L1 types; uses existing `IO<Capabilities>` only.
- Open: any package can add a new factory (`extension IO where
  Capabilities == X { public static func newStrategy(...) -> ... }`)
  without requiring any central type to be updated.
- Composition via Swift's native `try?` / `if let` / `#if` — no
  reified helper machinery required.
- Test doubles are just factory methods returning pre-built
  `IO<Capabilities>` values.
- Exactly the shape already used by `swift-io/Sources/IO/IO+Default.swift`.
  Each domain replicates the template.
- Platform-selection logic is localized to each domain's
  `default()` — and because the underlying strategy actors
  (`IO.Event.Actor`, `IO.Completion.Actor`) inherit platform
  unification from `Kernel.*.Driver`, what looks like "duplicated
  `#if`" is actually just per-domain *preference ordering*
  (the platform-specific *availability* lives one level below).

**Cons**:
- The `#if os(Linux) / elseif canImport(Darwin) / else` block is
  replicated in each domain's `default()` — ~10 lines per domain.
  Across four domains: ~40 LoC of mostly-mechanical duplication.
- No single place to change the preferred ordering (e.g., if Windows
  IOCP adoption changes Linux's preference chain). Each domain's
  `default()` needs a matching edit.

Selected.

### Comparison

| Criterion | A (enum) | B (witness) | C (methods only) |
|-----------|----------|-------------|------------------|
| Openness (new strategies without central update) | ✗ | ✓ | ✓ |
| Third-party extensibility | ✗ | ✓ | ✓ |
| Test doubles | Awkward | First-class | First-class |
| L1 surface additions | 1 type | 1 type + methods | 0 |
| Uses existing L1 only | ✗ | ✗ | ✓ |
| Composition machinery | Switch body | `.orElse` | `try?` / `if let` |
| Matches existing `IO+Default.swift` template | ✗ | ✗ | ✓ |
| Platform-`#if` duplication across domains | Via switch body | Via selector helper | ~10 LoC per domain |

### The Kernel.Thread.Actor generalization

Separately from strategy selection: the pinned-actor pattern inside
`IO.Blocking.Actor` generalizes. Strip it to:

```swift
extension Kernel.Thread {
    public actor Actor {
        public let executor: Kernel.Thread.Executor

        public init(executor: Kernel.Thread.Executor) {
            self.executor = executor
        }

        public nonisolated var unownedExecutor: UnownedSerialExecutor {
            unsafe executor.asUnownedSerialExecutor()
        }
    }
}
```

Each domain adds syscall methods via extensions:

```swift
// swift-io (basic-fd domain)
extension Kernel.Thread.Actor {
    public func read(from fd: borrowing Kernel.Descriptor, into buf: Memory.Buffer.Mutable) throws(IO.Error) -> Int { ... }
    public func write(to fd: borrowing Kernel.Descriptor, from buf: Memory.Buffer) throws(IO.Error) -> Int { ... }
    public func close(_ fd: consuming Kernel.Descriptor) { ... }
}

// swift-file-system
extension Kernel.Thread.Actor {
    public func open(path: File.Path, flags: File.Flags) throws(File.Error) -> File.Descriptor { ... }
    public func stat(path: File.Path) throws(File.Error) -> File.Info { ... }
    ...
}

// swift-sockets
extension Kernel.Thread.Actor {
    public func connect(fd: borrowing Kernel.Descriptor, to: Socket.Address) throws(Socket.Error) { ... }
    public func accept(on fd: borrowing Kernel.Descriptor) throws(Socket.Error) -> Kernel.Descriptor { ... }
    ...
}
```

**Placement**: swift-threads (the new home for
`Kernel.Thread.Pool`). It joins `Pool` as the second
thread-based-dispatch primitive: Pool is admission-gated generic
dispatch; Actor is pinned single-thread dispatch for actor-method-
style TCA26 co-location.

**Semantics to document**: one `Kernel.Thread.Actor` instance =
one thread = one isolation domain. All extension methods on that
instance run serialised on its pinned thread. Consumers that want
distinct thread residences create distinct actor instances.

### The IO Blocking module decomposition

With `Kernel.Thread.Actor` in swift-threads and the basic-fd
syscall bindings as extensions on it, the `IO Blocking` module in
swift-io decomposes cleanly:

| Current piece | Destination |
|---------------|-------------|
| `IO.Blocking` (shard provider over `Executor.Sharded`) | Delete — `Kernel.Thread.Pool` already provides this |
| `IO.Blocking.Options` | Delete — `Kernel.Thread.Pool.Options` has the same fields |
| `IO.Blocking.Actor` (pinned actor + syscall methods) | Delete as a type; preserve pattern as `Kernel.Thread.Actor` in swift-threads + basic-fd syscall extensions in swift-io |
| `IO.blocking(_:)` / `IO.blocking(on:)` factories | Reshape into `IO<BasicFD.Capabilities>.blocking(executor:)` factory in swift-io |
| Syscall bindings (read/write/close) | Move to `extension Kernel.Thread.Actor { … }` in swift-io |
| `README.md` | Archive or relocate to `Research/` |
| Module entry in `Package.swift` | Remove |

Nothing architecturally load-bearing is lost. The pinned-actor
pattern is preserved via `Kernel.Thread.Actor`; the syscall bindings
move to where their domain lives; the admission-gated-dispatch
alternative remains in `Kernel.Thread.Pool`.

### Why Blocking is not a peer of Events/Completions

Events and Completions are *strategies* that own IO-specific kernel
machinery:

- Events owns a polling thread + `Kernel.Event.Driver` (kqueue or
  epoll) + registration table + per-call async channel fan-out.
- Completions owns a proactor thread + `Kernel.Completion.Driver`
  (io_uring) + Entry table + multi-CQE cancel handshake.

Blocking owns nothing IO-specific. It is:

- A pinned thread (via `Kernel.Thread.Executor`, a swift-executors
  primitive — not IO-specific) + an actor holding it (via
  `Kernel.Thread.Actor`, a swift-threads primitive — not IO-specific)
  + syscall bindings (via per-domain extension — these ARE IO-
  specific, but each domain provides its own).

The "three strategies" framing is convenient at the consumer level
but asymmetric at the implementation level: Events and Completions
are substantive L3 types; Blocking is a composition of L1 primitives
plus per-domain extensions.

This asymmetry is **accepted rather than resolved**. A consumer sees
three factories (`.blocking(_:)`, `.events(on:)`, `.completions(on:)`)
that all produce an `IO<Capabilities>`. Underneath, Events and
Completions delegate to real strategy actors; Blocking delegates to
`Kernel.Thread.Actor` methods. The surface is uniform; the
machinery is not, and that is correct.

### Per-domain factory cost accounting

For `N` domains and `M` "strategies":

- Kernel primitives (`Event.Driver`, `Completion.Driver`, `Thread.Pool`, `Thread.Actor`): written once each, lives at L1.
- Strategy actors (`IO.Event.Actor`, `IO.Completion.Actor`): written once each, lives in swift-io at L3.
- Per-domain `Capabilities` struct: 1 per domain, domain-specific.
- Per-domain strategy factories: `N × M` small factories (~30–50 LoC each), domain-specific.
- Per-domain `default()`: `N` factories (~15 LoC each), platform-select + try/fallthrough.

For `N=4, M=3`: 12 strategy factories (~400 LoC) + 4 `default()` (~60 LoC). The only duplicated code is the `#if` block across `default()` factories — ~40 LoC of mostly-mechanical repetition. This is accepted as the honest floor.

### What stays constant across all domains

- The `IO<Capabilities>` shape (from L1).
- The `IO.Runner` shape — executor + shutdown closures (from L1).
- The `Kernel.Thread.Actor` shape (from swift-threads) — for blocking.
- `IO.Event.Actor` and `IO.Completion.Actor` (from swift-io) — for
  events and completions.
- TCA26 co-location — always via `io.runner.executor()`.
- Host-adaptive selection — always via `default()` factory with
  `#if` + `try?` + fallthrough.

The Runner's role: provide a uniform TCA26 surface (`executor`) and
uniform shutdown surface across all domains and all strategies.
Consumer code is strategy-agnostic because Runner normalizes the
scheduling-metadata exposure.

## Outcome

**Status**: RECOMMENDATION

### Architectural principles (committed)

1. **L1 swift-io-primitives stays minimal** — `IO<Capabilities>` +
   `IO.Runner` only. No new types; no strategy selector.

2. **Per-domain witnesses via `IO<Capabilities>`** — each domain
   defines its `Capabilities` struct and ships per-strategy factory
   methods. No central registry.

3. **Strategy composition without a strategy type** — factory
   methods ARE the strategies; `default()` factories compose them
   via `#if os(...)` + `try?` + `if let` + fallthrough.
   Extensibility is provided by Swift's own extension mechanism;
   no reified witness needed.

4. **Platform unification is inherited** — `Kernel.*.Driver` at L1
   already unifies per-platform mechanisms; `IO.*.Actor` at L3
   inherits this; per-domain factories see "the strategy actor"
   and do not branch on platform themselves.

5. **`Kernel.Thread.Actor` as generic pinned-actor primitive** —
   lives in swift-threads alongside `Kernel.Thread.Pool`. Each
   domain extends it with its syscall methods. No per-domain
   actor type.

6. **`IO Blocking` module can be removed** — its content decomposes
   into `Kernel.Thread.Pool` (swift-threads; admission-gated), `Kernel.Thread.Actor` (swift-threads; pinning), and
   `extension Kernel.Thread.Actor { ... }` basic-fd-syscall
   bindings (swift-io). The basic-fd-byte-ops capability lives
   inline in swift-io at L3.

7. **Asymmetry between Blocking and Events/Completions is
   accepted** — Events and Completions are substantive L3 strategy
   types; Blocking is a composition of L1 primitives + per-domain
   extensions. Uniform surface, non-uniform machinery.

### Implementation sequencing

| Phase | Work | Package |
|-------|------|---------|
| 1 (done) | L1 core | swift-io-primitives: `IO<Capabilities>` + `IO.Runner` |
| 2 | Add `Kernel.Thread.Actor` | swift-threads |
| 3 | Rebuild swift-io | swift-io: remove `IO Blocking`, define `BasicFD.Capabilities`, add per-strategy factories, provide `default()`, keep `IO.Event.Actor` and `IO.Completion.Actor` |
| 4 | Migrate consumers | swift-file-system first (path ops immediate need), then swift-sockets, then swift-server |

### Implications

- **No `IO.Strategy` type at any layer.**
- **`IO+Default.swift` is the template** for per-domain `default()`
  factories; each domain replicates its shape verbatim (modulo
  domain-specific strategy factory names).
- **`Kernel.Thread.Pool` and `Kernel.Thread.Actor` are the two
  generic thread-based dispatch primitives** in swift-threads;
  choose Pool for admission-gated generic dispatch, Actor for
  pinned-thread isolation + TCA26 co-location.
- **Documentation promotion**: the "factories ARE the strategies"
  pattern should be promoted to swift-io's design documentation
  as a first-class rule.

### Open items explicitly deferred

- **Windows IOCP**: when IOCP lands, `Kernel.Completion.Driver`
  gains IOCP support; `IO.Completion.Actor()` starts succeeding on
  Windows; each domain's `default()` `#if` block gains a Windows
  branch preferring completions. Mechanical change.
- **Platform-preference helper extraction**: if per-domain `#if`
  duplication becomes painful (likely only once 3+ domains exist
  AND a platform expansion touches all of them), a small helper
  like `IO.preferredStrategyHint` (just an ordering of factory
  names, not a type) could be extracted. Not now.

## References

- Plotkin, G. & Pretnar, M. (2009). *Handlers of Algebraic Effects.*
  ESOP 2009.
- Leijen, D. (2017). *Type Directed Compilation of Row-Typed
  Algebraic Effects.* POPL 2017.
- swift-io-thesis.md (v2.0) — position document for swift-io.
- io-algebraic-effects-foundation.md — algebraic theory grounding.
- io-witness-shape-selection.md — Shape F selection.
- `swift-io/Sources/IO/IO+Default.swift` — template for
  host-adaptive factory pattern.
- `swift-threads/Sources/Thread Pool/Kernel.Thread.Pool.swift` —
  admission-gated dispatch primitive.
