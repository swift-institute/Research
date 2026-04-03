<!--
version: 1.0.0
last_updated: 2026-04-02
status: RECOMMENDATION
tier: 2
consolidates:
  - sending-expansion-audit.md (COMPLETE, 2026-03-31)
  - tilde-sendable-semantic-inventory.md (RECOMMENDATION, 2026-03-25)
  - nonsending-ecosystem-migration-audit.md (IN_PROGRESS, 2026-03-31)
  - nonsending-adoption-audit.md (COMPLETE, 2026-02-25)
  - nonsending-compiler-patterns.md (RECOMMENDATION, 2026-03-22)
  - non-sendable-strategy-isolation-design.md (RECOMMENDATION, 2026-03-04)
  - tagged-structural-sendable.md (DEFERRED, 2026-03-10)
  - sendable-in-rendering-and-snapshot-infrastructure.md (SUPERSEDED, 2026-03-22)
  - callback-isolated-nonsending-design.md (IMPLEMENTED, 2026-03-22)
-->

# Ownership Transfer Conventions: sending, Sendable, and Nonsending

## Question

What are the ecosystem conventions for transferring values across isolation
boundaries? When should code use `sending`, `Sendable`, `@Sendable`, `~Sendable`,
or `nonisolated(nonsending)` — and when should it use none of these?

## Context

Nine separate research documents investigated overlapping aspects of this question
across the Swift Institute ecosystem. This consolidation unifies their findings into
a single authoritative reference. The directional principle is:

> **Prefer `sending` over `Sendable`. Prefer isolation over sendability.**

---

## 1. Ecosystem Principle

**Statement**: Sendable is an isolation-boundary annotation, not a type-parameter
default. Require it only where values actually cross isolation domains.
(from sendable-in-rendering-and-snapshot-infrastructure.md, 2026-03-22)

**Evidence**:

- **Swift Evolution direction**: SE-0461 `NonisolatedNonsendingByDefault` reduces the
  need for explicit Sendable. The language is moving toward isolation-based safety.
  (from non-sendable-strategy-isolation-design.md, 2026-03-04)
- **SwiftUI precedent**: `View` protocol does NOT require Sendable. View values exist
  within a single isolation domain.
  (from sendable-in-rendering-and-snapshot-infrastructure.md, 2026-03-22)
- **Point-Free alignment**: Brandon Williams (PF #356): "A major theme is going to be
  about avoiding sendability when possible." TCA2 makes Store non-Sendable.
  (from non-sendable-strategy-isolation-design.md, 2026-03-04)
- **Ecosystem validation**: Async.Callback redesigned from `Callback<Value: Sendable>:
  Sendable` to `Callback<Value>` (no Sendable on either). 23 tests passing.
  (from callback-isolated-nonsending-design.md, 2026-03-22)

---

## 2. Four-Tool Taxonomy

| Tool | Semantics | When to Use | Example |
|------|-----------|-------------|---------|
| `Value: Sendable` | Type permanently lives in concurrent contexts | Shared mutable state with synchronization | `Async.Stream.Element: Sendable` |
| `sending Value` | One-time ownership transfer across isolation | Actor init boundaries, promise fulfillment | `Promise.fulfill(sending Value)` |
| `@Sendable () -> T` | Closure stored/invoked across isolation | Stream operator closures, actor-stored callbacks | `map(@Sendable (Element) -> T)` |
| No annotation | Value stays in caller's isolation domain | Snapshot strategies, dependency injection | `Strategy<Value, Format>` |

(from sendable-in-rendering-and-snapshot-infrastructure.md, 2026-03-22;
sending-expansion-audit.md, 2026-03-31)

### Key distinctions

- `sending` constrains a **single transfer**. `Sendable` is a **permanent type constraint**.
  (from sending-expansion-audit.md, 2026-03-31)
- `@Sendable` on closures constrains **captures**, not **parameters**. A function
  `@Sendable (Value) -> Format` is valid even when `Value` is not Sendable.
  (from sendable-in-rendering-and-snapshot-infrastructure.md, 2026-03-22)
- `sending` and `borrowing` are **mutually exclusive**.
  (from sending-expansion-audit.md, 2026-03-31)

---

## 3. Sending Convention

### Definition

`sending` annotates parameters and return values that transfer ownership across
isolation boundaries. The compiler verifies the caller does not retain a reference
after transfer, preventing data races without requiring `Sendable` conformance.
(from sending-expansion-audit.md, 2026-03-31)

### Rules

- **At actor init boundaries, not public API**: Public methods that capture values
  in escaping closures cannot use `sending` (causes `#SendableClosureCaptures`
  errors). The transfer belongs at the actor init boundary.
  (from sending-expansion-audit.md, 2026-03-31)

- **Redundant on Sendable-constrained types**: When `Element: Sendable`, adding
  `sending` to returns is informational only.
  (from sending-expansion-audit.md, 2026-03-31)

- **`consuming sending` is stronger**: Channel sends use `consuming sending`, which
  additionally consumes the value at the call site.
  (from sending-expansion-audit.md, 2026-03-31)

- **Pairs with `nonisolated(nonsending)`**: Stdlib pairs nonsending functions with
  `-> sending T` for cross-isolation returns.
  (from nonsending-compiler-patterns.md, 2026-03-22)

- **Callback boundaries**: CPS inner callbacks use `(sending Value) -> Void` because
  the value crosses from producer into continuation consumer.
  (from sending-expansion-audit.md, 2026-03-31)

### Audit results (ALL COMPLETE)

16 sites across swift-async and swift-async-primitives:

**v1.0** (10 sites): `Scan.State.init(initial:)`, `FlatMap.Latest.State.Async.receiveInner`,
`Unfold.State.init(initial:)`, `Bridge.push`, `Promise.fulfill`,
`Channel.Bounded.Sender.send`, `Channel.Bounded.Sender.Send.immediate`,
`Channel.Unbounded.Sender.send`, `Broadcast.send`, `Completion.complete`.

**v2.0** (6 sites): `Replay.Subscription.init(replay:)`, `Repeat.State.init(value:)`,
`Repeat.Interval.State.init(value:)`, `Timer.Value.State.init(value:)`,
`Continuation.Storage.callback`, `Callback.init(wrapping:)` CPS inner callback.
(from sending-expansion-audit.md, 2026-03-31)

---

## 4. ~Sendable (SE-0518) Adoption

### Three semantic categories of @unchecked Sendable

| Category | Description | Correct Annotation |
|----------|-------------|-------------------|
| A: Synchronized | Internal mutex/atomic/lock | `@unsafe @unchecked Sendable` |
| B: Ownership transfer | `~Copyable` prevents sharing | `@unsafe @unchecked Sendable` |
| C: Thread-confined | Single-thread access, `@unchecked` to cross one boundary | **Should be `~Sendable`** |

(from tilde-sendable-semantic-inventory.md, 2026-03-25)

### Tier 1 types (should be ~Sendable)

3 types: `IO.Completion.IOUring.Ring`, `IO.Completion.IOCP.State`,
`File.Directory.Contents.IteratorHandle`. All poll-thread-confined, marked
`@unchecked Sendable` to cross one initialization boundary.
(from tilde-sendable-semantic-inventory.md, 2026-03-25)

### Tier 2 types (debatable)

4 types where stored properties are data-safe to memcpy but operational protocols
require single-threaded access. The question: does Sendable encode data-level or
protocol-level safety?
(from tilde-sendable-semantic-inventory.md, 2026-03-25)

### Layer philosophy

At L1 (primitives), Sendable mirrors kernel semantics — `~Sendable` would be
semantically wrong. At L3 (foundations), types encode higher-level contracts —
this is where `~Sendable` adds value.
(from tilde-sendable-semantic-inventory.md, 2026-03-25)

### `~Copyable` already solves most of the problem

~555 types audited. Only 3 Tier 1. ~489 pure value Sendable. Aggressive `~Copyable`
adoption for resource-owning types handles the primary use case for `~Sendable`.
`~Copyable + Sendable` = "transferable but not sharable."
(from tilde-sendable-semantic-inventory.md, 2026-03-25)

### Adoption plan (DEFERRED, ready to execute)

Phase 1: Enable `TildeSendable` + `ManualOwnership` experimental features.
Phase 2: Apply to 3 Tier 1 types. Phase 3: Build/test/triage.
Phase 4: Tier 2 design discussion.
(from tilde-sendable-semantic-inventory.md, 2026-03-25)

### Tagged phantom types

`Tagged<Element, Cardinal>` may not prove structural Sendable even when both params
are Sendable. `Hash.Table.Static<N>` uses `@unchecked Sendable` as workaround.
Sound by construction, low safety risk. DEFERRED.
(from tagged-structural-sendable.md, 2026-03-10)

---

## 5. Nonsending Migration

### Deprecation

The `isolation:` parameter is **DEPRECATED** in the stdlib. All concurrency
primitives have `nonisolated(nonsending)` primary APIs; old overloads are
`@_disfavoredOverload @available(*, deprecated)`.
(from nonsending-compiler-patterns.md, 2026-03-22)

### Ecosystem adoption

`NonisolatedNonsendingByDefault` enabled in **252/252 packages**.
(from nonsending-ecosystem-migration-audit.md, 2026-03-31)

### Migration surface

| Category | Count | Status |
|----------|:-----:|--------|
| SE-0421 `next(isolation:)` conformances | 10 | KEEP (new protocol requirement) |
| Deprecated `isolation:` parameters | 16 | COMPLETE (migrated) |
| Bare `() async` closure parameters | 16 | PENDING (Convention 4 compliance) |

(from nonsending-ecosystem-migration-audit.md, 2026-03-31)

### The double-nonsending pattern

Canonical stdlib form: both the function AND its operation closure parameter are
`nonisolated(nonsending)`:

```swift
nonisolated(nonsending)
public func withDependencies<T, E: Error>(
    _ modify: (inout __DependencyValues) -> Void,
    operation: nonisolated(nonsending) () async throws(E) -> T
) async throws(E) -> T
```

When a callback fires from external/arbitrary context, use `sending` instead.
(from nonsending-compiler-patterns.md, 2026-03-22;
nonsending-ecosystem-migration-audit.md, 2026-03-31)

### `nonisolated(nonsending)` is async-only

Cannot be applied to non-async function types. This permanently eliminates ~22
sync closure sites from migration scope. Accept as permanent.
(from nonsending-adoption-audit.md, 2026-02-25;
callback-isolated-nonsending-design.md, 2026-03-22)

### `sending Element` + `nonisolated(nonsending)` combined

Validated working on `Channel.send`.
(from nonsending-ecosystem-migration-audit.md, 2026-03-31)

---

## 6. Compiler Mechanics

### SIL representation

`nonisolated(nonsending)` functions receive an implicit
`@sil_isolated @sil_implicit_leading_param @guaranteed Builtin.ImplicitActor`
parameter. Consecutive calls with the same actor can DCE redundant hops.
(from nonsending-compiler-patterns.md, 2026-03-22)

### Function type conversion lattice

- `nonisolated(nonsending)` ↔ `@concurrent`: freely interconvertible
- `@MainActor` → `nonisolated(nonsending)`: allowed
- `nonisolated(nonsending)` → `@MainActor`: requires Sendable
- `nonisolated(nonsending)` → `@isolated(any)`: NOT allowed

This validates that plain closures in nonsending context are safe without Sendable.
(from nonsending-compiler-patterns.md, 2026-03-22)

### Conformance trap

Under `NonisolatedNonsendingByDefault`, implementation's parameter is implicitly
`nonisolated(nonsending)` but a protocol compiled without the feature requires
`@concurrent`. Witness thunk mediates. `next(isolation:)` bypasses entirely.
(from nonsending-compiler-patterns.md, 2026-03-22)

### `#isolation` returns nil in `Task {}`

Nonsending isolation does NOT propagate into detached tasks. Confirms removal of
`.async(isolation:_:)` from Callback.
(from nonsending-compiler-patterns.md, 2026-03-22)

### ObjC interop forces nil isolation

C ABI cannot represent the implicit actor parameter. CPS bridges from OS/ObjC
callbacks require `Value: Sendable`.
(from nonsending-compiler-patterns.md, 2026-03-22)

### Compiler issue #83812

Stored `nonisolated(nonsending)` closure called from another nonsending closure does
NOT inherit caller actor. `callAsFunction(isolation:)` method wrapper is structurally
necessary. `map`/`flatMap` MUST use `await self()`, never `self.operation()`.
(from callback-isolated-nonsending-design.md, 2026-03-22)

---

## 7. Domain Applications

### Async.Callback redesign (IMPLEMENTED)

CPS-based `Callback<Value: Sendable>: Sendable` replaced entirely with direct-style
`Callback<Value>` using nonsending closure. Value has no Sendable constraint, struct
is not Sendable. Bridge `init(wrapping:)` for legacy CPS callers requires
`Value: Sendable`.
(from callback-isolated-nonsending-design.md, 2026-03-22)

### Non-Sendable Strategy (RECOMMENDED, not yet implemented)

`Test.Snapshot.Strategy` instances never cross isolation boundaries. Remove
`@Sendable` from all Strategy closures, making Strategy non-Sendable. Cascade:
`Faceted` must also become non-Sendable. `Diffing` stays Sendable (genuinely pure).
(from non-sendable-strategy-isolation-design.md, 2026-03-04)

### Closure-only anti-pattern (10 types fixed)

Generic parameter constrained `: Sendable` but type stores only closures taking
that parameter. Optics demonstrates correct pattern: `Lens<Whole, Part>: Sendable`
with `@Sendable (Whole) -> Part` but `Whole`/`Part` unconstrained.
(from sendable-in-rendering-and-snapshot-infrastructure.md, 2026-03-22)

### Stream isolation boundary

Async.Stream is architecturally a concurrency boundary. `@Sendable Iterator._next`
severs caller isolation. 100% of stream operators break isolation. Stream operators
MUST keep `@Sendable`. The nonsending opportunity is in dependency injection and
direct async APIs, not streams.
(from nonsending-adoption-audit.md, 2026-02-25)

### IO layer

13 files with `@concurrent` — all genuine executor-boundary crossings. Zero
`@concurrent` in stdlib; it is exceptional, not standard.
(from nonsending-ecosystem-migration-audit.md, 2026-03-31)

### Clock implementations

9 Clock types with exemplary `nonisolated(nonsending)` sleep — both stored closure
and method annotated.
(from nonsending-ecosystem-migration-audit.md, 2026-03-31)

---

## 8. Outstanding Work

| Item | Status | Priority |
|------|--------|----------|
| Convention 4: 16 bare closure parameters need explicit `nonisolated(nonsending)` | PENDING | Medium (readability, not correctness) |
| ~Sendable Tier 1: Apply to 3 thread-confined types | DEFERRED (ready to execute) | Medium |
| ~Sendable Tier 2: Design discussion for 4 debatable types | DEFERRED | Low |
| Non-Sendable Strategy: Remove @Sendable from Strategy closures | RECOMMENDED | Medium |
| Tagged structural Sendable: Phantom type inference | DEFERRED | Low |
| `Callback.callAsFunction` migration to nonsending | FUTURE (after #83812 fix) | Low |
| Remaining opportunities: `__EffectProtocol.Value`, Infinite.Map/Scan/Zip | PENDING | Low |

---

## Cross-References

- **memory-safety** skill: [MEM-SEND-001] through [MEM-SEND-004], [MEM-OWN-014]
- **modern-concurrency-conventions.md**: Convention 2 ("Non-Sendable over Sendable")
- **async-stream-sendable-requirement.md**: Active investigation (not consolidated here)
- Experiments: nonsending-sendable-iterator, nonsending-clock-feasibility,
  nonsending-generic-dispatch, nonsending-method-annotation,
  sending-mutex-noncopyable-region, callback-isolated-prototype
