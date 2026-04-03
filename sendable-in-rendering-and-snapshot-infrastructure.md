# Sendable in Rendering and Snapshot Infrastructure

<!--
---
version: 1.4.0
last_updated: 2026-03-22
status: SUPERSEDED
superseded_by: ownership-transfer-conventions.md
tier: 2
---
-->

> **SUPERSEDED** (2026-04-02) by [ownership-transfer-conventions.md](ownership-transfer-conventions.md).
> All findings consolidated into the topic-based document. This file retained as historical rationale.

## Context

The rendering DSL stack spans three layers of the Swift Institute architecture:

| Layer | Package | Role |
|-------|---------|------|
| 1 | `swift-rendering-primitives` | `Rendering.Protocol` — no Sendable requirement |
| 2 | `swift-svg-standard` | Geometry/element value types (implicitly Sendable) |
| 3 | `swift-svg-rendering`, `swift-html-rendering` | View protocols + DSL |
| 3 | `swift-testing`, `swift-tests` | `#snapshot` macro + `Test.Snapshot.Strategy` |

The snapshot testing infrastructure (`Test.Snapshot.Strategy`) requires `Value: Sendable` at the struct level:

```swift
// swift-test-primitives: Test.Snapshot.Strategy.swift:63
public struct Strategy<Value, Format>: Sendable, Witness.`Protocol`
    where Value: Sendable, Format: Sendable { ... }
```

This constraint propagates to:
- `pullback<NewValue: Sendable>` (Strategy.swift:153)
- `asyncPullback<NewValue: Sendable>` (Strategy.swift:181)
- `assertInlineSnapshot<Value: Sendable>` (swift-tests)
- `assertSnapshot<Value: Sendable, Format: Sendable>` (swift-tests)
- `__snapshotInline<Value: Sendable>` and `__snapshotFile<Value: Sendable, Format: Sendable>` (Snapshot.swift:79, 107, 137, 165)

Neither `Rendering.Protocol`, `HTML.View`, nor `SVG.View` inherit from `Sendable`.

## Question

**Should rendering DSL types (HTML.View, SVG.View, etc.) and their snapshot testing infrastructure require Sendable conformance, or should an alternative isolation strategy be adopted?**

## Trigger

SVG snapshot tests fail when `callAsFunction` returns `some SVG.View`:

```swift
// SVG.Elements.swift:15-22
extension SVG_Standard.Shapes.Circle {
    public func callAsFunction<Content: SVG.View>(
        @SVG.Builder _ content: () -> Content = { SVG.Empty() }
    ) -> some SVG.View {
        SVG.Element(tag: Self.tagName) { content() }
            .cx(self.cx).cy(self.cy).r(self.r)
    }
}
```

```swift
let circle = SVG_Standard.Shapes.Circle(cx: 50, cy: 50, r: 40)()  // some SVG.View
#snapshot(circle, as: .svg) { ... }
// ERROR: 'some SVG.View' does not conform to 'Sendable'
```

The concrete type underneath IS Sendable (all SVG types have explicit conformances — `SVG.Element: Sendable where Content: Sendable`, `SVG._Attributes: Sendable where Content: Sendable`, etc.), but the compiler cannot see through the opaque return type.

HTML tests pass because they use concrete types directly (`HTML.Document { ... }`), not opaque returns. The SVG `callAsFunction` pattern exposes the architectural tension.

## Analysis

### Option A: Add `& Sendable` to Opaque Return Types

Change all `callAsFunction` methods:

```swift
public func callAsFunction<Content: SVG.View & Sendable>(
    @SVG.Builder _ content: () -> Content = { SVG.Empty() }
) -> some SVG.View & Sendable { ... }
```

**Advantages**:
- Minimal change — fixes the immediate compiler error
- Accurate — concrete types ARE Sendable
- No changes to snapshot infrastructure

**Disadvantages**:
- Viral spread: every `SVG.View`-returning function must add `& Sendable`
- 24+ `callAsFunction` methods need updating in SVG.Elements.swift alone
- All geometry context methods (`translated`, `scaled`, `rotated`) need updating
- Sets precedent: every `some SVG.View` or `some HTML.View` return must carry `& Sendable`
- Content generic parameters need `Content: SVG.View & Sendable` constraints
- Forecloses future `~Copyable` or `~Escapable` rendering types that may not be Sendable

### Option B: Remove `Value: Sendable` from Snapshot Infrastructure

Remove the Sendable constraint from `Strategy<Value, Format>`:

```swift
public struct Strategy<Value, Format>: Sendable where Format: Sendable { ... }
```

Update downstream:
- `pullback<NewValue>` — remove `NewValue: Sendable`
- `assertInlineSnapshot<Value>` — remove `Value: Sendable`
- `assertSnapshot<Value, Format>` — remove `Value: Sendable`
- `__snapshotInline`, `__snapshotFile` — remove `Value: Sendable`

**Advantages**:
- Addresses the root cause — Strategy doesn't NEED Value to be Sendable
- Strategy stores `@Sendable (Value) -> Async.Callback<Format>` — the closure is Sendable (captures only Sendable state), but Value is a parameter, not a capture. No Sendable requirement on Value is needed for the closure to be `@Sendable`
- Strategy's stored properties are: `pathExtension` (String?), `diffing` (Diffing<Format>), `snapshot` (@Sendable closure), `syncSnapshot` (optional @Sendable closure) — none store a Value instance
- Snapshot testing is fundamentally synchronous — `syncSnapshot` and even `assertInlineSnapshot` operate within a single isolation domain
- No viral Sendable spread onto rendering protocols
- Future-proof: `~Copyable` or `~Escapable` rendering types work without constraint changes
- Aligns with Point-Free's direction (minimize Sendable)

**Disadvantages**:
- Requires changes across three packages (swift-test-primitives, swift-tests, swift-testing)
- Async snapshot variants may legitimately need Value: Sendable if the value crosses isolation boundaries
- Less compile-time protection if someone accidentally passes a Strategy to another isolation domain and calls it with a non-Sendable value

**Technical feasibility note**: The `@Sendable` attribute on a closure constrains what the closure *captures*, not what its *parameters* are. A function `@Sendable (Value) -> Format` is valid even when `Value` is not Sendable — the `@Sendable` means the closure itself can be sent across boundaries, and the Value is provided at call time by whichever isolation domain invokes it. This is why removing `Value: Sendable` from Strategy while keeping `Strategy: Sendable` is sound.

### Option C: Isolation-First Approach

Use `nonisolated(nonsending)` or `@MainActor` isolation on test infrastructure instead of Sendable constraints:

```swift
public nonisolated(nonsending) func assertInlineSnapshot<Value>(
    of value: Value,
    as strategy: Test.Snapshot.Strategy<Value, String>,
    ...
) -> Test.Expectation { ... }
```

**Advantages**:
- Aligns with Point-Free's TCA2 / SQLiteData direction
- Propagates caller isolation — no boundary crossing, no Sendable needed
- Modern Swift concurrency best practice per PF #355/#356

**Disadvantages**:
- Requires Swift 6.2+ (NonisolatedNonsendingByDefault or explicit annotations)
- More invasive change to the testing infrastructure API surface
- May conflict with existing async test patterns that DO cross boundaries
- `nonisolated(nonsending)` on functions returning `Test.Expectation` may interact poorly with Swift Testing's `@Test` macro expectations

### Option D: Dual Sendable/Non-Sendable Snapshot Paths

Provide overloaded `pullback` and assert functions:

```swift
// For Sendable values (async-safe)
public func pullback<NewValue: Sendable>(...) -> Strategy<NewValue, Format>

// For non-Sendable values (sync-only)
public func pullback<NewValue>(...) -> Strategy<NewValue, Format>
```

**Advantages**:
- Backward compatible — existing Sendable paths unchanged
- Non-Sendable values get sync-only snapshot support

**Disadvantages**:
- Doubles API surface area
- Overload ambiguity when Value IS Sendable — compiler may select wrong overload
- Strategy struct still requires `Value: Sendable` on the type, so non-Sendable Strategy instances need a separate type or the constraint must be removed anyway
- Complexity for no real benefit — if we can remove the constraint cleanly (Option B), there's no reason for dual paths

### Option E: Protocol-Level Sendable Inheritance

Make `Rendering.Protocol` (or `SVG.View` / `HTML.View`) inherit from Sendable:

```swift
extension SVG {
    public protocol View: Rendering.`Protocol` & Sendable
    where Content: SVG.View, Context == SVG.Context, RenderOutput == UInt8 { ... }
}
```

**Advantages**:
- Simple — single change, all conforming types already satisfy Sendable
- `some SVG.View` automatically implies `& Sendable`
- No changes to snapshot infrastructure

**Disadvantages**:
- **Permanent semantic commitment**: forces ALL future rendering types to be Sendable forever
- Forecloses `~Copyable` rendering types (non-copyable types cannot conform to Sendable in current Swift)
- Forecloses rendering types that hold mutable references (e.g., a rendering type backed by a class-based DOM node)
- Inappropriately elevates a testing concern into the rendering protocol definition
- Rendering.Protocol at Layer 1 should not carry concurrency constraints — it's about rendering semantics, not thread safety
- Violates the principle that protocols should have minimal requirements

## Prior Art Survey

### Point-Free: swift-snapshot-testing

Point-Free's `Snapshotting` type in swift-snapshot-testing (v1.17+) uses `Sendable` constraints on its `Snapshotting<Value, Format>` type. However, their recent work on TCA2 and SQLiteData (PF #355, #356, Feb/Mar 2026) represents a philosophical shift:

> "A major theme of this upcoming series is going to be about avoiding sendability when possible." — Brandon Williams, PF #356

> "Minimizing how much we need to employ sendable types and closures, making it very easy to use, and without using locks to enforce correctness." — Brandon Williams, PF #355

Their newer libraries (SQLiteData) demonstrate achieving strict concurrency without Sendable, using `~Copyable`, `~Escapable`, and `nonisolated(nonsending)` instead.

### SwiftUI's View Protocol

SwiftUI's `View` protocol does **not** require `Sendable` conformance. View values are not designed to cross isolation boundaries — they exist within a single isolation domain (typically `@MainActor`). SwiftUI's approach validates that rendering protocols should not carry Sendable requirements.

### Swift Evolution Direction

Swift 6.2's `NonisolatedNonsendingByDefault` feature (SE-0461) makes `nonisolated(nonsending)` the default for functions, reducing the need for explicit Sendable constraints. The ecosystem direction is toward isolation-based safety rather than Sendable-based safety.

### Internal Precedent: Swift Institute Concurrency Research

Six prior research documents establish a consistent ecosystem-wide principle: **Sendable should be required only where isolation-domain crossing actually occurs**. This decision directly extends that principle.

#### Witness.Protocol Sendable Removal (DECISION, witness-protocol-sendable-requirement.md)

Removed `: Sendable` from `Witness.Protocol`, the semantic marker protocol for closure-struct witnesses. Rationale: Sendable is orthogonal to the witness pattern — it belongs on the conforming type, not the marker protocol. All 13 existing conformances already declared `: Sendable` explicitly, so removal caused zero breakage. This is directly analogous to our Strategy case: Strategy is a witness (`Witness.Protocol` conformance), and requiring `Value: Sendable` on the *pattern* rather than at *use sites* is the same category of over-constraint.

#### Nonsending Adoption Audit (CORRECTED, nonsending-adoption-audit.md)

Audited 52 `@Sendable` sites across async-primitives and async-stream. Key finding: `nonisolated(nonsending)` **only applies to async function types** — sync closures cannot carry isolation context. This is critical for snapshot testing: `syncSnapshot: @Sendable (Value) -> Format` is a sync closure, so `nonisolated(nonsending)` cannot replace `@Sendable` on it. Option C (isolation-first) is therefore less viable than originally assessed for sync snapshot paths. The audit's recommendation to keep `@Sendable` on closures that genuinely cross boundaries while removing it from type parameters validates Option B.

#### Async.Callback.Isolated — Nonsending Callback (IMPLEMENTED, callback-isolated-nonsending-design.md)

Replaced `Async.Callback<Value: Sendable>: Sendable` with a new `Async.Callback<Value>` that has **no `Sendable` constraint on `Value`**. The value never crosses isolation boundaries — it flows through `nonisolated(nonsending) () async -> Value` closures that propagate caller isolation. This is the exact same pattern we're applying: the callback stores closures that take/produce `Value`, but `Value` itself never needs to be Sendable because it never leaves the caller's isolation domain. The Async.Callback redesign is a proven, implemented precedent.

#### Stream Isolation Propagation (IN_PROGRESS, stream-isolation-propagation.md)

Found that 100% of `Async.Stream` operators break isolation through four independent mechanisms. The document recommends accepting `Async.Stream` as an explicit concurrency boundary where `@Sendable` is appropriate. This validates the principle by its converse: Sendable is warranted at genuine concurrency boundaries (streams), and inappropriate where no boundary exists (snapshot testing).

#### Sending Expansion Audit (COMPLETE, sending-expansion-audit.md)

Identified 10 sites requiring the `sending` parameter annotation — all are ownership transfer operations at isolation boundaries (Promise.fulfill, Channel.send, Bridge.push). The audit distinguishes between `sending` (per-transfer annotation) and `Sendable` (permanent type constraint), recommending `sending` for transfer sites. This supports our async consideration: async snapshot variants can use `sending Value` instead of `Value: Sendable`.

#### Isolation-Preserving Entry Point API (DECISION, isolation-preserving-entry-point-api.md)

Solved stdlib overload resolution defeating isolation-preserving concrete types by providing sync-closure overloads. The pattern of sync-closure overloads winning over async `@Sendable` variants validates that sync paths can coexist with async-Sendable paths without constraint pollution.

### Cognitive Dimensions Assessment (per [RES-025])

| Dimension | Option A | Option B | Option E |
|-----------|----------|----------|----------|
| **Visibility** | Every opaque return needs `& Sendable` — visible noise | Constraint absence — clean | Protocol carries it — invisible |
| **Consistency** | Inconsistent — some returns have it, some don't | Consistent — no rendering type needs Sendable | Consistent — all do |
| **Viscosity** | High — adding a new SVG element requires `& Sendable` | Low — no Sendable ceremony | Low — but permanent lock-in |
| **Error-proneness** | High — forgetting `& Sendable` causes cryptic errors | Low — no constraint to forget | Low — protocol handles it |
| **Role-expressiveness** | Misleading — implies concurrency intent where none exists | Accurate — rendering is synchronous | Misleading — rendering ≠ concurrency |

## Comparison

| Criterion | A: Opaque `& Sendable` | B: Remove from Strategy | C: Isolation-first | D: Dual paths | E: Protocol Sendable |
|-----------|------------------------|------------------------|-------------------|---------------|---------------------|
| Fixes SVG tests | Yes | Yes | Yes | Partially | Yes |
| Viral constraint spread | **High** | **None** | None | Medium | **High** (permanent) |
| Changes needed | 24+ SVG methods | 3 packages, ~8 functions | 3 packages, API change | 3 packages, doubled API | 1-3 protocols |
| Future ~Copyable support | No | **Yes** | Yes | Partial | **No** |
| Aligns with PF direction | No | **Yes** | **Yes** | Partial | No |
| Aligns with SwiftUI pattern | No | **Yes** | Yes | Partial | No |
| Breaking change | No | Relaxation (non-breaking) | Signature change | Non-breaking | Protocol requirement change |
| Complexity | Low per-site, high total | Low | Medium | High | Low |
| Root cause addressed | No (symptom fix) | **Yes** | Yes | Partially | No (different symptom fix) |

## Constraints

1. `Strategy<Value, Format>` stores no `Value` instances — only `@Sendable` closures that take `Value` as parameter
2. All current SVG and HTML rendering types are value types with explicit Sendable conformances
3. Snapshot testing is fundamentally synchronous — even async variants run within a single test function's isolation
4. Swift 6.2's `NonisolatedNonsendingByDefault` is available across our packages
5. `Rendering.Protocol` at Layer 1 should remain maximally general — no concurrency constraints

## Outcome

**Status**: SUPERSEDED

**Superseded by**: [non-sendable-strategy-isolation-design.md](non-sendable-strategy-isolation-design.md) — The decided parts (remove `Value: Sendable`) are implemented. The remaining question (remove `@Sendable` from Strategy's closures entirely, making Strategy non-Sendable with isolation-first design) is the successor's scope.

**Original decision** (implemented):

**Decision**: **Option B — Remove `Value: Sendable` from `Test.Snapshot.Strategy` and downstream infrastructure**

### Rationale

1. **Root cause**: The Sendable constraint on `Strategy<Value, Format>` is unnecessary. Strategy stores closures (`@Sendable (Value) -> Format`), not Value instances. The `@Sendable` attribute constrains what the closure captures, not its parameters. Removing `Value: Sendable` while keeping `Strategy: Sendable` is type-theoretically sound.

2. **Non-breaking**: Removing a generic constraint is a relaxation — existing code that passes Sendable values continues to work. No call sites break.

3. **No viral spread**: Unlike Options A and E, this doesn't force Sendable onto any rendering types. The rendering layer remains free to define types with any ownership model.

4. **Future-proof**: When `~Copyable` or `~Escapable` rendering types emerge (e.g., a streaming SVG renderer that uses non-copyable buffer handles), they work with snapshot testing without constraint changes.

5. **Ecosystem alignment**: Matches Point-Free's philosophical direction (minimize Sendable), SwiftUI's View protocol (no Sendable), and Swift Evolution's isolation-first trajectory.

6. **Consistency**: Resolves the HTML/SVG asymmetry — HTML tests work by accident (concrete types happen to be Sendable), SVG tests fail by design (opaque return types don't carry Sendable). Removing the constraint makes both work by intent.

7. **Internal precedent**: Follows the same principle established by six prior ecosystem decisions — Sendable belongs at isolation boundaries, not on type parameters that never cross boundaries. The `Witness.Protocol` Sendable removal and `Async.Callback<Value>` redesign (removing `Value: Sendable`) are direct structural analogues.

### Implementation (completed)

1. **swift-test-primitives**: Removed `Value: Sendable` from `Strategy<Value, Format>` struct declaration. Kept `Format: Sendable` (needed for `Diffing<Format>` storage). Removed `NewValue: Sendable` from `pullback` and `asyncPullback`.

2. **swift-tests**: Removed `Value: Sendable` from `assertInlineSnapshot` and `assertSnapshot` function signatures (all overloads).

3. **swift-testing**: Removed `Value: Sendable` from `__snapshotInline` and `__snapshotFile` bridge functions.

4. **SVG strategy**: Removed `& Sendable` from `Test.Snapshot.Strategy` extension constraint (`where Value: SVG.View`).

### Async Consideration

For async snapshot variants where the Value genuinely crosses isolation boundaries, the `sending` parameter modifier (SE-0430) is the correct tool:

```swift
public func assertSnapshot<Value, Format: Sendable>(
    capturing value: sending Value,
    ...
)
```

The `sending` modifier ensures the value is safely transferred without requiring a permanent `Sendable` conformance. This is more precise than `Value: Sendable` because it constrains the *transfer*, not the *type*. The sending-expansion-audit.md identifies this as the ecosystem-wide pattern for ownership transfer at isolation boundaries.

Note from the nonsending-adoption-audit: `nonisolated(nonsending)` only applies to async function types — sync closures cannot carry isolation context. Since `syncSnapshot: @Sendable (Value) -> Format` is a sync closure, `nonisolated(nonsending)` cannot replace `@Sendable` on it. The `@Sendable` on the closure itself remains correct (it constrains captures, not parameters); removing `Value: Sendable` from the type parameter is the precise fix.

### What NOT to Do

- Do NOT add `& Sendable` to opaque return types (Option A) — treats the symptom, spreads the constraint
- Do NOT add Sendable to `Rendering.Protocol` or `SVG.View` (Option E) — permanent semantic commitment to a testing concern
- Do NOT create dual Strategy types (Option D) — unnecessary complexity

### Ecosystem Principle

This decision reinforces the ecosystem-wide concurrency principle emerging from seven research documents:

> **Sendable is an isolation-boundary annotation, not a type-parameter default.** Require it only where values actually cross isolation domains. For type parameters that flow through closures without leaving the caller's isolation, omit the constraint entirely. For one-time transfers, use `sending`. For closures that must be stored across isolation domains, use `@Sendable`. These are three distinct tools for three distinct situations.

| Tool | When to use | Example |
|------|-------------|---------|
| `Value: Sendable` | Type permanently lives in concurrent contexts | `Async.Stream.Element: Sendable` |
| `sending Value` | One-time ownership transfer across isolation | `Promise.fulfill(sending Value)` |
| `@Sendable () -> T` | Closure stored/invoked across isolation | `Strategy.snapshot` closure |
| No annotation | Value stays in caller's isolation domain | `Strategy<Value, Format>` — Value parameter |

## Appendix: Ecosystem-Wide Inventory of Closure-Only Sendable Constraints

Phase 1 audit across swift-primitives (631 total Sendable sites) identified **10 types** exhibiting the same anti-pattern as `Strategy<Value, Format>`: generic type parameter constrained `: Sendable` but the type stores only closures taking that parameter — never the parameter itself.

### Exemplar: Optics (correct pattern — no over-constraint)

The optics package already implements the correct pattern:

```swift
// Optic.Lens — Sendable type, @Sendable closures, UNCONSTRAINED type params
public struct Lens<Whole, Part>: Sendable, Witness.`Protocol` {
    public let get: @Sendable (Whole) -> Part
    public let set: @Sendable (Whole, Part) -> Whole
}
```

`Lens` is `Sendable` and stores `@Sendable` closures, but `Whole` and `Part` are **not** constrained to `Sendable`. This compiles because `@Sendable` constrains captures, not parameters. All five optic types (Lens, Prism, Iso, Affine, Traversal) follow this pattern. They are the existence proof that the Strategy fix is sound.

### Candidates for Constraint Relaxation

#### Tier 1: Closure-only types (direct analogues to Strategy)

| Type | Package | Params | Stored Properties |
|------|---------|--------|-------------------|
| `Algebra.Magma<Element: Sendable>` | algebra-magma | `Element` | `combining: @Sendable (Element, Element) -> Element` |
| `Algebra.Semigroup<Element: Sendable>` | algebra-magma | `Element` | `combining: @Sendable (Element, Element) -> Element` |
| `Test.Snapshot.Redaction<Format: Sendable>` | test | `Format` | `apply: @Sendable (Format) -> Format` |
| `Serialization.Serializing.Value<Output: Sendable, Representation: Sendable, Context: Sendable, Failure: Error & Sendable>` | serialization | 4 params | `call: @Sendable (Output, Context) throws(Failure) -> Representation` |
| `Serialization.Parsing.Whole<Output: Sendable, Representation: Sendable, Context: Sendable, Failure: Error & Sendable>` | serialization | 4 params | `call: @Sendable (Representation, Context) throws(Failure) -> Output` |
| `Serialization.Parsing.Prefix.Witness<Output: Sendable, Count: Sendable, Representation: Sendable, Context: Sendable, Failure: Error & Sendable>` | serialization | 5 params | `call: @Sendable (Representation, Context) throws(Failure) -> Result<Output, Count>` |
| `Serialization.Serializing.Buffer<Output: Sendable, Element: Sendable, Context: Sendable>` | serialization | 3 params | `call: @Sendable (Output, Context, inout [Element]) -> Void` |
| `Serialization.Measuring<Output: Sendable, Context: Sendable>` | serialization | 2 params | `call: @Sendable (Output, Context) -> Int` |

All 8 types store **zero instances** of their constrained type parameters — only `@Sendable` closures taking them as parameters. The constraint is unnecessary by the same reasoning as Strategy.

#### Tier 2: Protocol-mediated (implemented)

| Type | Package | Issue | Status |
|------|---------|-------|--------|
| `Effect.Continuation.One<Value: Sendable>` | effect | `_resume: @Sendable (sending Result<Value, Failure>) async -> Void` — closure-only | **FIXED** |
| `Effect.Continuation.Multi<Value: Sendable>` | effect | Same pattern and same protocol constraint | **FIXED** |

Removed `Value: Sendable` from `__EffectContinuation` protocol, `One`, `Multi` structs, and factory methods. Kept `Value: Sendable` on `__EffectProtocol` — the broader effect system (Spy.Invocation, Test.Handler in swift-effects) genuinely stores `E.Value` in Sendable contexts. The `onResume` method on `One` was moved to a `where Value: Sendable` extension because it legitimately uses the result in two `sending` contexts (callback and original closure).

#### Function-level Sendable constraints (implemented)

Phase 2 audit identified 26 function-level `Sendable` constraints that were unnecessary. After verification, **15 sites across 9 packages** were corrected:

| Package | Sites | Constraint removed | Reason |
|---------|-------|--------------------|--------|
| `swift-algebra-law-primitives` | 2 | `Element: Sendable` on Associativity, Commutativity | Accept Semigroup (no longer requires Sendable) |
| `swift-pool-primitives` | 4 | `T: Sendable` on TryAcquire methods | Synchronous, no isolation crossing |
| `swift-dimension-primitives` | 4 | `Scalar: Sendable` on `fraction()` methods | Unlocked by fixing `Numeric.Fraction` |
| `swift-async-primitives` | 2 | `T: Sendable` on Channel.Storage `withLock` | Synchronous return from `Mutex.withLock` |
| `swift-binary-parser-primitives` | 2 | `Output: Sendable` on borrowed prefix | Synchronous; unconstrained sibling exists |
| `swift-bit-pack-primitives` | 1 | `Word: Sendable` | Structural constraints sufficient |

Additionally, `Numeric.Fraction<..., Result: Sendable>: Sendable` was changed to conditional Sendable conformance (`extension Numeric.Fraction: Sendable where Result: Sendable {}`), since it stores `value: Result` directly. This was the root cause requiring `where Scalar: Sendable` on the dimension fraction methods.

**Correctly retained** (audit initially classified as unnecessary but proved load-bearing):
- `Optic.Traversal.set` — `Part` captured in `@Sendable` closure via `modify`
- `Sample.Metric.extract` — `Sample.Averaging<T>` struct requires `T: Sendable`
- 9 algebra-law functions accepting Monoid/Group/Ring/Field (all require `Element: Sendable`)
- 4 dimension-primitives sites (before `Numeric.Fraction` root cause fix)

#### Not candidates (store values directly)

| Type | Why correct |
|------|------------|
| `Algebra.Monoid<Element: Sendable>` | Stores `identity: Element` directly |
| `Algebra.Group<Element: Sendable>` | Stores `identity: Element` directly |
| `Infinite.Repeat<Element: Sendable>` | Stores `value: Element` directly |
| `Infinite.Iterate<Element: Sendable>` | Stores `initial: Element` directly |
| `Infinite.Unfold<State: Sendable, Element: Sendable>` | Stores `seed: State` directly |
| All Ring, Field, Module types | Store nested witnesses containing `identity` values |

### Algebra Chain Impact

Removing `Element: Sendable` from Magma and Semigroup is safe because they are leaf types in the algebra hierarchy:

```
Magma<Element: Sendable>          → REMOVE (closure-only)
  └─ Semigroup<Element: Sendable> → REMOVE (closure-only)
       └─ Monoid<Element: Sendable>  → KEEP (stores identity: Element)
            ├─ Monoid.Commutative    → KEEP (wraps Monoid)
            └─ Group<Element: Sendable>  → KEEP (stores identity: Element)
                 └─ Group.Abelian    → KEEP (wraps Group)
                      └─ Ring, Field, Module, VectorSpace → KEEP (compose higher types)
```

The constraint break is clean: Magma and Semigroup don't store Element, so removing `: Sendable` is a pure relaxation. Monoid and above need it because they store `identity`.

### Serialization Impact

All 5 serialization types are independent — they don't form a hierarchy. Each can be relaxed independently. The serialization package has the highest constraint density (5 types × 2-5 params each = ~18 unnecessary constraints).

### Implementation Status

All tiers implemented and verified:

| Priority | Package | Types | Params freed | Status |
|----------|---------|-------|-------------|--------|
| 1 | swift-test-primitives | Redaction | 1 | **DONE** |
| 2 | swift-serialization-primitives | 5 types + Prefix.Result conditional | ~18 + 1 conditional | **DONE** |
| 3 | swift-algebra-magma-primitives | Magma, Semigroup | 2 | **DONE** |
| 4 | swift-effect-primitives | One, Multi + `__EffectContinuation` protocol | 2 + protocol | **DONE** |
| 5 | swift-numeric-primitives | Numeric.Fraction → conditional Sendable | 1 | **DONE** |
| 6 | 8 packages (function-level) | 15 function constraints | 15 | **DONE** |

### Remaining Opportunities

| Category | Scope | Description |
|----------|-------|-------------|
| `__EffectProtocol.Value: Sendable` | effect-primitives + swift-effects | Removing requires redesigning Spy.Invocation and Test.Handler which store `E.Value` |
| `Infinite.Map/Scan/Zip` struct-level | infinite-primitives | Store Element directly but could use conditional Sendable |
| `Algebra.Monoid+` conditional | algebra hierarchy | Store `identity: Element` — could use conditional Sendable instead of `Element: Sendable` |
| swift-standards audit | standards layer | Not yet audited |
| swift-foundations audit | foundations layer | Not yet audited |

## References

### External
- Point-Free Video #355: "Beyond Basics: Isolation, ~Copyable, ~Escapable" (Feb 2026)
- Point-Free Video #356: "Beyond Basics: Superpowers" (Mar 2026)
- SE-0461: NonisolatedNonsendingByDefault
- SE-0430: `sending` parameter and result values
- SwiftUI View protocol — no Sendable inheritance

### Internal Research (cross-references)
- `nonsending-adoption-audit.md` — 52-site audit establishing sync/async nonsending viability
- `callback-isolated-nonsending-design.md` — Async.Callback `Value: Sendable` removal precedent
- `witness-protocol-sendable-requirement.md` — Witness.Protocol Sendable removal precedent
- `stream-isolation-propagation.md` — Async.Stream as legitimate Sendable boundary
- `sending-expansion-audit.md` — `sending` annotation for isolation-boundary transfers
- `isolation-preserving-entry-point-api.md` — sync overloads defeating async-Sendable constraints
- `tagged-structural-sendable.md` — phantom type Sendable investigation (related, IN_PROGRESS)
- `snapshot-testing-literature-study.md` — related Tier 3 study

### Source Files
- `swift-test-primitives/Sources/Test Snapshot Primitives/Test.Snapshot.Strategy.swift` — Strategy definition
- `swift-tests/Sources/Tests Inline Snapshot/Test.Snapshot.Inline.assert.swift` — assertInlineSnapshot
- `swift-tests/Sources/Tests Snapshot/Test.Snapshot.assert.swift` — assertSnapshot
- `swift-testing/Sources/Testing Umbrella/Snapshot.swift` — macro bridge functions
- `swift-svg-rendering/Sources/SVG Rendering/SVG.Elements.swift` — opaque return callAsFunction pattern

## Changelog

- v1.3.0 (2026-03-04): All tiers implemented. Removed Value: Sendable from __EffectContinuation protocol, One, Multi, and factory methods. Phase 2 function-level audit: 15 constraints removed across 9 packages. Fixed Numeric.Fraction root cause (conditional Sendable). Documented remaining opportunities (effect protocol, infinite types, algebra conditional, standards/foundations audit).
- v1.2.0 (2026-03-04): Added Appendix: Ecosystem-Wide Inventory. Phase 1 audit of 631 Sendable sites across swift-primitives. Found 10 types with the closure-only anti-pattern (8 Tier 1 direct analogues, 2 Tier 2 protocol-mediated). Identified optics as exemplar of correct pattern. Mapped algebra chain impact (Magma/Semigroup removable, Monoid+ must keep). Prioritized implementation path.
- v1.1.0 (2026-03-04): Status RECOMMENDATION → DECISION. Added Internal Precedent section with cross-references to 6 ecosystem concurrency research documents. Added Ecosystem Principle summary with annotation taxonomy table. Updated Implementation section to reflect completed work. Strengthened async consideration with nonsending-adoption-audit finding (sync closures cannot be nonsending). Added Changelog.
- v1.0.0 (2026-03-04): Initial analysis. 5 options evaluated. Option B recommended.
