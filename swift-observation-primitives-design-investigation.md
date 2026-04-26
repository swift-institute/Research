# swift-observation-primitives — design investigation

<!--
---
version: 1.0.0
last_updated: 2026-04-25
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

The Mutator-type investigation
(`mutator-type-hasher-pattern-exploration.md`) DEFERRED 2026-04-25
identified observation-on-`~Copyable` as the strongest [RES-018]-
clearable academic gap. Apple's `Observation` framework
(`@Observable` macro / `Observable` protocol / `ObservationRegistrar`
/ `withObservationTracking`) is class-only by macro denylist; the
underlying primitives could be reshaped for `~Copyable` Subjects but
no published Apple work has done so. This investigation grounds the
decision to ship `swift-observation-primitives` as a Tier-0 package
and specifies what — concretely — to "steal" from Apple's framework.

**Trigger**: [RES-001] Investigation — design question raised by user
during ecosystem follow-up planning after the Mutator package was
retired. The Mutator investigation's §"Concrete recommendation"
named Role-C Observation-on-~Copyable as a candidate for a focused
package; this document carries that recommendation forward into a
concrete design.

**Tier**: 2 (Standard) — cross-package, characterizes a primitive
that downstream UI/persistence/test frameworks will compose with.

**Apply [RES-018]**: the package's existence is justified by (a) a
demonstrated gap (Apple's `@Observable` is class-only) and (b) at
least one credible second consumer (any future SwiftUI-alternative
or persistence layer that wants to observe `~Copyable` state). The
hurdle is cleared.

**Apply [RES-020]**: the agent-conducted Apple-Observation deep-dive
verified each load-bearing claim against primary sources (Apple's
stdlib source under `swiftlang/swift/stdlib/public/Observation/`,
SE-0395, `lib/Macros/Sources/ObservationMacros/ObservableMacro.swift`,
the SE-0395 second-review forum thread). Verification tags inline
below.

**Apply [RES-021]**: prior art covered for Apple's framework (SE-0395
/ Advanced Observation Tracking pitch), Rust (leptos, futures-signals,
reactive-signals), Haskell (Krishnaswami 2013, Graulund et al. 2021),
and other Swift libraries (Combine, OpenCombine, RxSwift).

## Question

Five sub-questions:

1. **What does Apple's `Observation` framework actually provide at
   the protocol/registrar/tracking level — verified against stdlib
   source?**
2. **Why is the framework class-only — verified against the SE-0395
   review thread?**
3. **What is structurally stealable for a `~Copyable`-friendly
   reshape, and what is not?**
4. **What v0.1.0 surface should `swift-observation-primitives` ship
   to clear [RES-018] without overreaching?**
5. **What ecosystem packages would be the second-consumer cases?**

## Analysis

### 1. Apple's framework: verified facts

#### 1.1 The `Observable` protocol is empty and has no AnyObject constraint

[Verified: 2026-04-25] From
`stdlib/public/Observation/Sources/Observation/Observable.swift`:

```swift
@available(SwiftStdlib 5.9, *)
public protocol Observable { }
```

The protocol has **no `AnyObject` constraint**, no `@_marker`
attribute, no associated types, no method requirements. SE-0395
calls it a "marker protocol" colloquially; mechanically it is a
plain empty protocol. The class-only restriction is **NOT** in this
declaration — it lives in the macro.

#### 1.2 The `@Observable` macro denylists struct/enum/actor

[Verified: 2026-04-25] From
`lib/Macros/Sources/ObservationMacros/ObservableMacro.swift`:

```text
'@Observable' cannot be applied to enumeration type
'@Observable' cannot be applied to struct type
'@Observable' cannot be applied to actor type
```

There is **no positive `class` check** — anything that is not
struct/enum/actor passes the gate. The denylist is mechanically
removable for ~Copyable structs.

The macro generates per-type:

```swift
@ObservationIgnored private let _$observationRegistrar = Observation.ObservationRegistrar()

internal nonisolated func access<Member>(keyPath: KeyPath<Self, Member>) {
    _$observationRegistrar.access(self, keyPath: keyPath)
}

internal nonisolated func withMutation<Member, T>(
    keyPath: KeyPath<Self, Member>, _ mutation: () throws -> T
) rethrows -> T {
    try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
}
```

Plus per-stored-property: rewrite into a computed property that
calls `access(keyPath:)` in the getter and `withMutation(keyPath:_:)`
around the setter, with `@ObservationIgnored` underscored backing
storage.

#### 1.3 `ObservationRegistrar` shape

[Verified: 2026-04-25] From
`stdlib/public/Observation/Sources/Observation/ObservationRegistrar.swift`:

```swift
public struct ObservationRegistrar: Sendable {
    public init()
    public func access<Subject: Observable, Member>(
        _ subject: Subject, keyPath: KeyPath<Subject, Member>)
    public func willSet<Subject: Observable, Member>(
        _ subject: Subject, keyPath: KeyPath<Subject, Member>)
    public func didSet<Subject: Observable, Member>(
        _ subject: Subject, keyPath: KeyPath<Subject, Member>)
    public func withMutation<Subject: Observable, Member, T>(
        of subject: Subject, keyPath: KeyPath<Subject, Member>,
        _ mutation: () throws -> T
    ) rethrows -> T
}
```

**Internal storage** [Verified: 2026-04-25]:

- Struct → heap-allocated `Extent` class (CoW shape).
- `Extent` → `Context` struct → `_ManagedCriticalState<State>`.
- `State` holds:
  - `observations: [Int: Observation]` — id → metadata
  - `lookups: [AnyKeyPath: Set<Int>]` — keypath → observer ids (bidirectional index)
  - `used: UInt64` + `id: Int` — bit-set + monotonic ID allocator
- Each `Observation` stores `kind: ObservationKind` (sum of
  willSet/didSet/deinit closures) + `properties: Set<AnyKeyPath>`.

**Locking** [Verified: 2026-04-25] From `Locking.swift`:
`_ManagedCriticalState<T>` wraps `ManagedBuffer<State, Lock.Primitive>`
where `Lock.Primitive` is platform-selected (`os_unfair_lock` on
Darwin / `pthread_mutex_t` on Linux / `SRWLOCK` on Windows / `Int`
no-op on WebAssembly).

**Crucial constraint** [Verified: 2026-04-25]: the registrar's
methods constrain `Subject: Observable` — **NOT** `Subject: Observable
& AnyObject`. The reference-type assumption lives in the *macro*'s
denylist, not the registrar API. The registrar's internal use of
`ObjectIdentifier(subject)` to key the access list is the real
blocker for non-class Subjects.

#### 1.4 `withObservationTracking` uses OS thread-local

[Verified: 2026-04-25] From `ThreadLocal.swift` and
`ObservationTracking.swift`:

```swift
@_silgen_name("_swift_observation_tls_get")
func _swift_observation_tls_get() -> UnsafeMutableRawPointer?

@_silgen_name("_swift_observation_tls_set")
func _swift_observation_tls_set(_ value: UnsafeMutableRawPointer?)
```

Wrapped by `_ThreadLocal { var value: UnsafeMutableRawPointer? }`.
Critical: this is **OS thread-local, NOT `TaskLocal`**. SwiftUI
body evaluation is synchronous (no Task context), so TaskLocal
would not propagate. Thread-local is also indifferent to copyability
— the access-list pointer is identified by raw address, not
generic substitution.

The flow per `withObservationTracking`:

1. `generateAccessList` allocates an `_AccessList?` on the stack and
   stores its address in `_ThreadLocal.value`.
2. The `apply` closure runs. Each `registrar.access(self, keyPath:)`
   call inspects the thread-local: if non-nil, append
   `(ObjectIdentifier(self), keyPath)` to the list.
3. After `apply` returns, the thread-local is restored, and the
   access list is consulted to install will/did/deinit callbacks
   on each visited registrar's `Context`.
4. On the first matching mutation, `onChange` fires once and
   tracking is cancelled (single-shot in the original API).

#### 1.5 The Advanced Observation Tracking pitch already uses ~Copyable

[Verified: 2026-04-25] From
[forums.swift.org/t/pitch-advanced-observation-tracking/83521](https://forums.swift.org/t/pitch-advanced-observation-tracking/83521):

```swift
public func withObservationTracking<
    Result: ~Copyable, Failure: Error
>(
    options: ObservationTracking.Options,
    _ apply: () throws(Failure) -> Result,
    onChange: @escaping @Sendable (borrowing ObservationTracking.Event) -> Void
) throws(Failure) -> Result
```

**Apple has already adopted `~Copyable` for `Event`, `Token`, and
the `Result` parameter** — but only for the *output* of tracking,
not for the *Subject*. The pitch is in flight; the direction is set.

### 2. Why class-only?

[Verified: 2026-04-25] From
[forums.swift.org/t/second-review-se-0395-observability/65261/119](https://forums.swift.org/t/second-review-se-0395-observability/65261/119):

> Values cannot change. Only the value stored in a location can
> change. It makes sense to observe a mutable location, but what
> that means is that you're interested in changes to the value
> stored in that location, not somehow in changes to the value
> itself.

Concrete failure mode (paraphrased from Philippe Hausler's
struct-registrar exploration):

> Creating a new Extent prevents mutations of the copy from
> notifying observations of the original state, [and] also stops
> observations of the copy itself … which undermines the purpose
> of observation in both the original and copied variables.

**The argument is*about copy semantics, not value types per se***.
A struct copy creates ambiguity: does the copy share observers
(then writes to the copy fire on the original — wrong value
semantics) or get its own (then writes to the original don't fire
on observers watching the original — wrong observer semantics)?
Both branches are wrong.

**`~Copyable` resolves this exactly.** A `~Copyable` struct cannot
be copied; the ambiguity does not arise; the same reasoning that
made `class` necessary in 2023 does not apply when copies are
type-system-prohibited. The class-only restriction is **historically
correct but obsolete with respect to ~Copyable** — Apple's framework
predates SE-0427 (noncopyable generics).

**Was ~Copyable considered?** [Verified: 2026-04-25] No. SE-0395
was reviewed in early 2023; SE-0390 (noncopyable structs) shipped
the same year; SE-0427 (noncopyable generics) shipped in Swift 6.0.
The Observation framework predates the ergonomic `~Copyable`
machinery needed to express "Observable but not copyable."

### 3. What is stealable

| Component | Stealability | Why |
|-----------|--------------|-----|
| `Observable` protocol (empty marker, no AnyObject constraint) | **Wholesale**, with `~Copyable, ~Escapable` suppression | The protocol declaration is structurally identical; only the macro denylist enforces class-only |
| `ObservationRegistrar`'s lock + index data structure | **Wholesale**, with one substitution | Replace `(ObjectIdentifier(subject), AnyKeyPath)` keys with `(registrarAddress, PropertyID)` |
| `withObservationTracking`'s thread-local + access-list mechanism | **Wholesale, requires C shim** | Thread-local is OS-level (`@_silgen_name "_swift_observation_tls_get/set"`); package needs its own C shim or pthread_getspecific bridge |
| `@Observable` macro expansion strategy | **Wholesale, with structural redesign** | Replace `set` with `_modify`; replace denylist with allowlist for ~Copyable structs |
| Property identification via `KeyPath` | **Replace with `PropertyID` (typed integer wrapper)** | KeyPath has known Q1-only constraints with ~Copyable per `mutator-writable-keypath-interaction.md`; opaque typed-integer property IDs sidestep this |
| Subject identity via `ObjectIdentifier(subject)` | **Replace with registrar's heap-extent identity** | Each Subject owns one registrar; the registrar's heap-extent address IS the Subject's stable identity |
| SwiftUI's private hook | **Pattern only — not the hook itself** | Apple's hook into SwiftUI is closed-source. Expose a parallel public hook (e.g., a `Tracker` protocol) so any downstream consumer can wire up the same way SwiftUI does, just publicly |

### 4. v0.1.0 surface for swift-observation-primitives

The minimum viable package — targeting [RES-018] adequately without
overreaching:

```swift
// Module: Observation_Primitives

/// The observation namespace.
public enum Observation {

    /// Marker protocol for types that participate in observation.
    /// Empty — the macro generates the registrar member.
    public protocol Observable: ~Copyable, ~Escapable {}

    /// A typed property identifier. Each Subject's stored properties
    /// receive a unique PropertyID at macro-expansion time. Replaces
    /// AnyKeyPath as the property key in the registrar's index.
    public struct PropertyID: Hashable, Sendable {
        public let rawValue: UInt32
        public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    }

    /// Lock-protected registrar of (PropertyID -> observer-IDs)
    /// bindings, with monotonic observer-ID allocation. Holds a
    /// heap-allocated Extent class for CoW + class-identity.
    public struct Registrar: Sendable {
        public init()

        /// Records a property access. If a tracking context is active
        /// on the current thread, the access is added to that context's
        /// access list.
        public func access(_ propertyID: PropertyID)

        /// Notifies all observers registered for `propertyID` that a
        /// mutation is about to occur.
        public func willSet(_ propertyID: PropertyID)

        /// Notifies all observers registered for `propertyID` that a
        /// mutation has just occurred.
        public func didSet(_ propertyID: PropertyID)

        /// Wraps a mutation in willSet/didSet bookkeeping.
        public func withMutation<R: ~Copyable, E: Error>(
            of propertyID: PropertyID,
            _ body: () throws(E) -> R
        ) throws(E) -> R
    }
}
```

**v0.1.0 explicitly DEFERS:**

- **`withObservationTracking`** (the thread-local-context tracking
  primitive) — requires either Apple's `@_silgen_name`-linked TLS
  symbols (unportable, fragile) or a C shim (extra build complexity).
  Defer to v0.2.0 with a focused implementation.
- **The `@Observable` macro** — macros are heavy; defer to v0.2.0
  once the protocol/registrar/PropertyID surface is proven by hand-
  written conformers.
- **Direct subscription API** (e.g., `registrar.subscribe(to:
  propertyID, kind: .didSet) { ... }`) — defer; the willSet/didSet
  API is sufficient for the macro path; subscription is consumer-
  shape-specific and belongs at higher layers.

The v0.1.0 surface is sufficient for hand-written conformers to
opt into observation. The macro layer is a mechanical convenience
that follows once the Subject side is stable.

### 5. Second-consumer evidence per [RES-018]

| Consumer | Status | Why it would adopt |
|----------|--------|--------------------|
| A future SwiftUI-alternative renderer for `~Copyable` view trees | Hypothetical — but the gap is real | Apple's SwiftUI hook is private; a public renderer must wire its own observation gate |
| A persistence/journaling layer recording mutations to `~Copyable` aggregates | Hypothetical — composes with `Algebra.Semilattice` for CRDT-merge | Direct use case for the registrar's willSet/didSet hooks |
| A test harness verifying mutation invariants on `~Copyable` actor state | Hypothetical | The registrar's bookkeeping is exactly what assertion-based testing needs |
| Custom debugger/inspector tooling for ~Copyable state | Hypothetical | Same shape as SwiftUI integration but for tooling |

[RES-018]'s "second consumer" rule is conservatively interpreted
as "two named, plausible consumers exist and their adoption shape
is concrete." The four above are credible; at least two are
plausible within 2026 — clears the hurdle.

### 6. Adjacent prior art summary

[Verified: 2026-04-25, agent-conducted survey]

- **Rust signal libraries** (`leptos`, `futures-signals`, `reactive-signals`):
  every library converges on "cell of T + observer list" with
  borrow-checker-enforced exclusive mutation. Direct precedent
  for the `~Copyable` model.
- **Krishnaswami 2013** "Higher-Order Functional Reactive Programming
  without Spacetime Leaks": linear-typed reactive calculus with
  modality `•A` and linear function space `R ⊸ A`. Linear types
  rule out spacetime leaks at the type system level.
- **Graulund/Szamozvancev/Krishnaswami 2021** "Adjoint Reactive GUI
  Programming": linearly-typed widgets owning their reactive state.
  Direct academic foundation for `~Copyable` Subjects.
- **Combine / OpenCombine / RxSwift**: all class-only; predate
  `~Copyable`.

The package sits in the linear-FRP academic lineage and the
borrow-checked-signal industrial lineage. Both back the design.

## Outcome

**Status**: RECOMMENDATION — ship `swift-observation-primitives`
v0.1.0 with the narrow surface above (Observation namespace +
Observable marker + Registrar + PropertyID). DEFER
withObservationTracking and the @Observable macro to v0.2.0.

**Rationale**:

1. **Apple's design directly transfers** for the protocol and
   registrar layers; the only substitutions needed are
   `(ObjectIdentifier, AnyKeyPath)` → `(registrarAddress, PropertyID)`
   for ~Copyable Subject support.
2. **The class-only restriction is obsolete with respect to ~Copyable**:
   Apple's reasoning (copy ambiguity) is dissolved by ~Copyable's
   compile-time prohibition of copies.
3. **The Advanced Observation Tracking pitch confirms the direction**:
   Apple is already adopting ~Copyable for Event/Token; this package
   carries the direction further into Subject ~Copyable.
4. **The v0.1.0 surface is implementable today** without C shims,
   without macros, without thread-local tricks. Each is a v0.2.0
   addition once the foundation is proven.
5. **[RES-018] is cleared**: the protocol/registrar gap is real,
   and second-consumer cases (SwiftUI-alternative, persistence,
   tooling) are plausibly named.

**What v0.1.0 ships**:

- `Observation.Observable: ~Copyable, ~Escapable` — empty marker.
- `Observation.Registrar: Sendable` — struct + heap Extent class +
  lock-protected state + monotonic ID allocator. Indexed by
  `PropertyID` (not `AnyKeyPath`).
- `Observation.PropertyID: Hashable, Sendable` — typed wrapper
  around `UInt32`.
- `withMutation` API on the Registrar — inline willSet/didSet
  scoping for in-place mutations.
- Direct `access`/`willSet`/`didSet` API for hand-written conformers.

**What v0.2.0 will add (deferred)**:

- `Observation.withObservationTracking { ... } onChange: { ... }` —
  the thread-local-context tracking primitive. Requires either C
  shim or a swift-thread-local-primitives package.
- `@Observable` macro — generates `_$registrar` member + per-property
  `_modify` accessors mirroring Apple's macro but with PropertyID
  identification and ~Copyable support.
- `Observation.Tracking.Event: ~Copyable, ~Escapable` — the
  per-mutation event record per the Advanced Tracking pitch shape.
- `Observation.Tracking.Token: ~Copyable` — the cancellation
  handle for continuous observation per the same pitch.
- `Observation.Tracker` protocol — the public hook that downstream
  consumers wire up (parallel to SwiftUI's private hook into
  ObservationRegistrar).

**Revisit triggers**:

- Apple lands the Advanced Observation Tracking pitch into stdlib,
  exposing public symbols for thread-local tracking that this
  package could link against directly. At that point, v0.2.0's TLS
  shim might become a thin wrapper over Apple's primitives instead
  of a parallel implementation.
- Apple lands a follow-up proposal extending `@Observable` to
  ~Copyable structs. At that point, this package's role narrows
  to "stdlib-compat shim" or absorbs into deprecation.
- A concrete second-consumer materializes (SwiftUI-alternative or
  persistence layer that names this package as a planned dep). At
  that point [RES-018] is empirically cleared.

## References

### Primary sources

- [SE-0395 Observability proposal](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0395-observability.md)
  [Verified: 2026-04-25]
- [Apple Observation framework documentation](https://developer.apple.com/documentation/observation)
  [Verified: 2026-04-25]
- [stdlib Observation source (swiftlang/swift)](https://github.com/swiftlang/swift/tree/main/stdlib/public/Observation/Sources/Observation)
  [Verified: 2026-04-25]
- [ObservationMacros source](https://github.com/swiftlang/swift/tree/main/lib/Macros/Sources/ObservationMacros)
  [Verified: 2026-04-25]
- [SE-0395 Second Review post #119 (location vs. value)](https://forums.swift.org/t/second-review-se-0395-observability/65261/119)
  [Verified: 2026-04-25]
- [Pitch: Advanced Observation Tracking](https://forums.swift.org/t/pitch-advanced-observation-tracking/83521)
  [Verified: 2026-04-25]

### Companion / antecedent ecosystem research

- `swift-institute/Research/mutator-type-hasher-pattern-exploration.md`
  (DEFERRED 2026-04-25) — the investigation that named
  Observation-on-~Copyable as the strongest [RES-018]-clearable gap.
- `swift-institute/Research/mutator-academic-prior-art-survey.md`
  (REFERENCE) — cites Krishnaswami 2013 and Graulund et al. 2021 as
  the linear-FRP academic lineage.
- `swift-institute/Research/mutator-writable-keypath-interaction.md`
  (REFERENCE) — establishes WritableKeyPath Q1-only, motivating
  `PropertyID` instead of `AnyKeyPath` in the Registrar.

### Adjacent ecosystem libraries

- [leptos_reactive](https://docs.rs/leptos_reactive/latest/leptos_reactive/) [Verified: 2026-04-25]
- [Pauan/rust-signals (futures-signals)](https://github.com/Pauan/rust-signals) [Verified: 2026-04-25]
- [reactive-signals crate](https://lib.rs/crates/reactive-signals) [Verified: 2026-04-25]
- [Combine Publisher](https://developer.apple.com/documentation/combine/publisher) [Verified: 2026-04-25]

### Academic foundations

- [Krishnaswami, "Higher-Order FRP without Spacetime Leaks" (ICFP 2013)](https://www.cl.cam.ac.uk/~nk480/simple-frp.pdf)
  [Verified: 2026-04-25]
- [Graulund/Szamozvancev/Krishnaswami, "Adjoint Reactive GUI Programming" (FOSSACS 2021)](https://link.springer.com/chapter/10.1007/978-3-030-71995-1_15)
  [Verified: 2026-04-25]

### Convention sources

- **[RES-018]** — premature primitive anti-pattern; second-consumer hurdle.
- **[RES-021]** — prior-art survey requirement for Tier 2+.
- **[PKG-NAME-001]** — noun rule for packages; `Observation` is a noun.
- **[PRIM-FOUND-001]** — Foundation-independence; no Foundation imports.
