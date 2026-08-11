# Naming: `Transfer.Cell` / `Transfer.Storage` → `Transfer.Outgoing` / `Transfer.Incoming`

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

`Ownership.Transfer` is a family of one-shot primitives for transferring
`~Copyable` / `AnyObject` values across a boundary that `sending`
cannot cross (pthread hand-off, Swift-task + non-Swift boundary,
callback-reception from C APIs).

Current members:

| Member | Direction | Specialisation |
|--------|-----------|----------------|
| `Transfer.Cell` | producer→consumer (outbound) | generic `~Copyable` |
| `Transfer.Storage` | consumer→producer (inbound) | generic `~Copyable` |
| `Transfer.Retained` | producer→consumer (outbound) | `AnyObject`, zero-alloc |
| `Transfer.Box` | producer→consumer (outbound) | type-erased (see A1) |

`Cell` and `Storage` form a pair on the **direction** axis, but the
names do not read as a pair. An engineer seeing `Transfer.Storage`
cannot guess the direction from the name.

## Question

Should `Transfer.Cell` / `Transfer.Storage` be renamed to
`Transfer.Outgoing` / `Transfer.Incoming` to expose the direction
symmetry?

## Prior Art — Direction-Named Transfer

### Apple / Swift

- `sending T` (SE-0430): the term is direction-neutral. `sending` covers
  both inbound (parameter) and outbound (return) transfers via the
  parameter/result distinction.
- `@Sendable` closures: directionally agnostic.
- `Unmanaged.passRetained(_:)` / `takeRetainedValue()` — "pass" /
  "take" carry direction without naming it.

Swift stdlib does not have a direction-named transfer primitive. The
direction is usually implicit in the method name (pass / take,
`withContinuation` / `resume`).

### Rust / concurrency libraries

- `std::sync::mpsc::channel()` returns `(Sender<T>, Receiver<T>)` —
  direction-named endpoint types. `Sender` sends; `Receiver` receives.
  This is the clearest prior art: an endpoint-pair naming scheme that
  exposes direction.
- `crossbeam::channel` — `Sender<T>` / `Receiver<T>`.
- `tokio::sync::mpsc` — `Sender<T>` / `Receiver<T>`.

Rust's concurrency channels consistently pair Sender/Receiver. "Cell"
in Rust means interior mutability (`std::cell::Cell<T>`), not "channel
endpoint" — which is why our `Transfer.Cell` also misreads to a Rust
engineer.

### Networking / messaging systems

- POSIX pipes: "read end" and "write end".
- Message queues: `send` / `receive`.
- Kafka/RabbitMQ: producer / consumer.
- TCP sockets: outbound / inbound connections.

All use direction-named endpoints. The direction appears in the name.

### Academia

Session-type literature (Honda et al. *Session types for object-oriented
languages*, 2008) uses direction-named types: `!T.S` (output of type T,
continue as S) and `?T.S` (input of type T, continue as S). The direction
is a first-class primitive of the type system.

Linear-type channel primitives (Gay & Vasconcelos, 2010) similarly use
"send end" / "receive end" or equivalent.

## Analysis

### Semantic content of the current names

| Current | Inherent meaning | Reveals direction? |
|---------|------------------|-------------------|
| `Transfer.Cell` | "a cell" (Rust: interior mutability!) | No |
| `Transfer.Storage` | "storage" (very generic) | No |
| `Transfer.Retained` | "retained" (Swift `Unmanaged` vocab) | No (but specialises direction implicitly via pass/take) |
| `Transfer.Box` | "box" (Rust: heap-owned; misleads) | No |

None of the four names reveals direction. The type's direction only
becomes visible after reading the method vocabulary (`take` vs `store`,
`pass` vs `receive`).

### Alternative naming schemes

| Scheme | Outbound | Inbound | Reads as |
|--------|----------|---------|----------|
| Current | `Cell` | `Storage` | Asymmetric; direction hidden |
| Direction-adjective | `Outgoing` | `Incoming` | Symmetric; explicit |
| Role-noun | `Sender` | `Receiver` | Symmetric; Rust-familiar |
| Action-noun | `Send` | `Receive` | Symmetric; verb-ish |
| Pipe-metaphor | `Outbox` | `Inbox` | Symmetric; mail metaphor |
| Channel-endpoint | `Source` | `Sink` | Symmetric; FP-familiar |

### Why `Outgoing` / `Incoming` over the alternatives

1. **Not verbs**. `Send`/`Receive` read as imperative methods; the type
   is a noun. `Outgoing`/`Incoming` are participial adjectives that
   also serve as nouns ("the outgoing" = "the outgoing thing").
2. **Not specialised**. `Sender`/`Receiver` sound like "a thing that
   sends / receives" — the endpoints. Our types are the *medium*
   through which the transfer happens (the slot, not the actor). The
   `-ing` form captures "the slot carrying the direction of transfer".
3. **Composable**. Under the rename, the AnyObject specialisation
   becomes `Transfer.Outgoing.Retained` — reads as "the Retained variant
   of an Outgoing transfer". Same for `Transfer.Incoming.Retained` (a
   completeness gap, see B1 in the audit).
4. **Apple-compatible**. Apple uses "incoming" in
   `URLSessionDelegate`'s `urlSession(_:task:didReceive:completionHandler:)`
   docs (incoming authentication challenge), in
   `CNContactStore` (incoming contacts), and in various `NSInputStream`
   contexts. "Outgoing" appears in `NSOutgoingChannel` (deprecated)
   and networking. The words are ecosystem-idiomatic English.

### Why NOT pick `Sender` / `Receiver`

- **Confusion with Combine / Concurrency**. Swift has `ObservableObject`,
  publishers/subscribers, and Rust-adjacent engineers have
  `tokio::mpsc::Sender`. Overloading the name in a different contract
  (one-shot transfer, not a channel) risks mis-intuition.
- **The type is a slot, not an actor**. `Sender` implies an active
  role; our types are passive slots that hold the value during
  transfer.

### The completeness argument

Under the current scheme, the AnyObject specialisation (`Retained`) is
outbound-only. This is an *accidental asymmetry* — the inbound
counterpart is technically implementable but hidden by the naming.
Under `Outgoing` / `Incoming`:

| Position | Type |
|----------|------|
| Outbound generic | `Transfer.Outgoing` |
| Outbound AnyObject | `Transfer.Outgoing.Retained` |
| Outbound type-erased | `Transfer.Outgoing.Erased` |
| Inbound generic | `Transfer.Incoming` |
| Inbound AnyObject | `Transfer.Incoming.Retained` (completeness gap B1) |
| Inbound type-erased | `Transfer.Incoming.Erased` (completeness gap B2) |

The gaps become *obvious* and *nameable*. The current scheme hides
them (there is no obvious place to hang `Storage.Retained`).

## Blast radius

From v2.1.0 inventory:

| Type | File count (non-own-package) | Blast detail |
|------|------------------------------|--------------|
| `Transfer.Cell` | 3 files (1 real consumer) | swift-kernel `Thread.spawn` |
| `Transfer.Storage` | 0 | None |
| `Transfer.Retained` | 6 files (executor infra) | swift-executors `Executor.Scheduled` etc. |

Total: ~10 call sites. The primary external consumers are:

1. `swift-kernel/Sources/Kernel Thread Primitives/Thread.swift` —
   `Thread.spawn` takes a `Transfer.Cell<Void>`.
2. `swift-executors/Sources/Executor Kernel Thread Primitives/…` —
   `Transfer.Retained` used in `Executor.Scheduled.run`.

Both repos are under this workspace and can be migrated in the same
session that lands the rename.

## Outcome

**Status**: RECOMMENDATION.

**Decision basis**:

1. Direction is a first-class axis of the type family; the names should
   reflect it.
2. Rust / session-types / messaging-systems precedent is unanimous on
   direction-named primitives.
3. The rename surfaces the two known completeness gaps (B1, B2) as
   nameable inbound-* positions.
4. Blast radius is under 10 call sites, all in monorepo siblings.

**Action**: apply the pair rename in the 0.1.0 cycle:

- `Transfer.Cell` → `Transfer.Outgoing`
- `Transfer.Storage` → `Transfer.Incoming`
- `Transfer.Retained` → `Transfer.Outgoing.Retained`
- `Transfer.Box` → `Transfer.Outgoing.Erased` (combined with A1 —
  simplifies the A1 rename target to a directionally-correct name)

**Coordination**:

- swift-kernel: 1 site in `Thread.spawn`.
- swift-executors: 6 sites across `Executor.Scheduled` family.

Migrate both in parallel with the ownership-primitives rename, verify
their tests, commit each repo separately.

**Completeness follow-ups (landed)**: B1 and B2 (inbound AnyObject and
inbound type-erased) become trivially nameable under the rename and are
filled in the 0.1.0 cycle as `Transfer.Retained<T>.Incoming` and
`Transfer.Erased.Incoming`.

## Historical note — implementation refinement

The literal form applied at implementation time refines the proposal
above: the generic moves to the **kind layer** (`Transfer.Value<V>`,
`Transfer.Retained<T>`) rather than the direction layer, because
Swift 6.3.1 forbids accessing `Foo<V>.Bar<U>` as `Foo.Bar<U>`
(verified in `Experiments/nested-type-generic-escape/`). Landed shape:

- `Transfer.Cell<V>` → `Transfer.Value<V>.Outgoing`
- `Transfer.Storage<V>` → `Transfer.Value<V>.Incoming`
- `Transfer.Retained<T>` → `Transfer.Retained<T>.Outgoing`
- `Transfer.Box` → `Transfer.Erased.Outgoing`
- NEW: `Transfer.Retained<T>.Incoming`
- NEW: `Transfer.Erased.Incoming`

The direction-pair symmetry from the original proposal is preserved;
the generic placement binds to the cell's payload identity (Value,
Retained, Erased) rather than the handle role (Outgoing, Incoming),
which is the correct semantic anchor.

## References

- [SE-0430: Sending](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md) — Apple's direction-neutral transfer primitive
- [Rust std::sync::mpsc](https://doc.rust-lang.org/std/sync/mpsc/) — `Sender` / `Receiver`
- [tokio::sync::mpsc](https://docs.rs/tokio/latest/tokio/sync/mpsc/) — `Sender` / `Receiver`
- Honda, K., Vasconcelos, V. T., Kubo, M. (1998). *Language primitives
  and type discipline for structured communication-based programming*.
  ESOP. (foundational session-types paper)
- Gay, S. J., Vasconcelos, V. T. (2010). *Linear type theory for
  asynchronous session types*. JFP.
- v2.1.0 `ownership-types-usage-and-justification.md` — Cluster B
- `swift-kernel/Sources/Kernel Thread Primitives/Thread.swift` — consumer
- `swift-executors/Sources/Executor Kernel Thread Primitives/…` — consumers

## Provenance

Per-module naming research requested 2026-04-24.
