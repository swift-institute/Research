# Sink Concurrent Sharing Pattern

<!--
---
version: 2.0.0
last_updated: 2026-03-02
status: DECISION
---
-->

## Context

`Test.Reporter.Sink` is a `~Copyable` type with consuming `finish()` semantics.
The tree-walking test runner needs to share event emission across concurrent task
group closures. The type system must make incorrect code impossible — relying on
code discipline to not call `finish()` is rejected per [IMPL-INTENT].

**Trigger**: Implementation of hierarchical test execution engine requires
concurrent event emission from multiple task group children to a single sink.

## Question

What is the theoretically correct ownership pattern for sharing a `~Copyable`
sink's event emission capability across concurrent tasks, where the type system
enforces the capability restriction?

## Analysis

### Type-Theoretic Structure

The Sink presents a **substructural capability split**:

1. **Send capability**: `send(_ event:) async` — non-consuming, idempotent,
   safe for concurrent use. Substructurally **unrestricted** (copyable).
2. **Finish capability**: `finish() consuming async` — consuming, exactly-once.
   Substructurally **affine** (at most once).

The `~Copyable` constraint on Sink correctly encodes the affine finish
capability. The challenge: project the unrestricted send capability as a
separate Copyable type without exposing finish.

### Option A: `Ownership.Shared(sink)`

Consume the Sink into `Ownership.Shared`. The `let value: Sink` binding
provides borrowed access — `send()` works (non-consuming), `finish()` is
rejected by the compiler (consuming on `let`).

```swift
let shared = Ownership.Shared(sink)  // consumes sink
// shared.value.send(event) — ✓ borrowed access, non-consuming
// shared.value.finish()    — ✗ compiler error: consuming on let
```

**Type-system enforcement**: Perfect. The compiler prevents `finish()`.

**Fatal flaw**: The Sink is consumed into Shared with no way to recover it.
`finish()` can never be called. The `SinkImplementation.finish()` cleanup
(flushing buffers, closing files, signaling completion) is permanently lost.
`Ownership.Shared` has no `take()` — values are reclaimed only by ARC
deallocation, which cannot run async cleanup.

**Verdict**: Rejected. Correct send restriction, but destroys the finish path.

### Option B: Pass `any SinkImplementation` Directly

Extract `_impl` from the Sink and pass the protocol existential through the
tree walk.

```swift
let sink = reporter.makeSink()
let impl = sink._impl  // Copyable + Sendable existential
// impl.send(event)  — ✓
// impl.finish()     — ✓ type system allows this!
```

**Type-system enforcement**: None. `SinkImplementation` exposes both `send`
and `finish`. Callers must discipline themselves to not call `finish()`.

**Verdict**: Rejected per [IMPL-INTENT]. Incorrect code compiles.

### Option C: ~Copyable Capability Projection (`Sink.Sender`)

The ~Copyable Sink projects a Copyable, Sendable send-only type. This follows
the standard ~Copyable projection pattern ([IMPL-021]): the ~Copyable owner
retains the affine capability while projecting the unrestricted capability as
a separate Copyable type.

```swift
extension Test.Reporter.Sink {
    /// The copyable send-only projection of this ~Copyable sink.
    ///
    /// Sink is ~Copyable (affine: consuming finish). Sender is the
    /// unrestricted capability projection — Copyable and Sendable,
    /// can be captured in any number of concurrent task group closures.
    ///
    /// The type system enforces the split: Sender has send(), Sink
    /// retains finish(). Incorrect code does not compile.
    public struct Sender: Sendable {
        private let _impl: any SinkImplementation
        public func send(_ event: Test.Event) async { await _impl.send(event) }
    }

    /// Projects the send-only capability.
    ///
    /// Non-consuming: the Sink retains ownership and can still be finished.
    public var sender: Sender { Sender(_impl: _impl) }
}
```

Usage:
```swift
let sink = reporter.makeSink()   // ~Copyable, owns finish
let sender = sink.sender         // Copyable, send-only — non-consuming
// ... pass sender to concurrent task group closures ...
// sender.send(event)  — ✓ compile
// sender.finish()     — ✗ no such method
await sink.finish()              // ✓ Sink still alive, consumed here
```

**Type-system enforcement**: Complete. `Sender` has no `finish()` method.
The compiler prevents incorrect code. The Sink retains ownership of finish
and is consumed exactly once after all tasks complete.

**No `Ownership.Shared` needed**: The underlying `any SinkImplementation`
existential is already Copyable and Sendable (protocol existentials are
reference-counted). Wrapping a Copyable value in `Ownership.Shared` (designed
for `~Copyable` values) would be a semantic type error — double-wrapping a
reference with no benefit.

**Naming**: `Sender` per [IMPL-INTENT] — communicates what the type does (sends
events), not what it is mechanistically (a handle). `Handle` is mechanism-speak.

**File placement**: Defined in the same file as `Sink` (`Test.Reporter.Sink.swift`).
This keeps `_impl` private — the `sender` property accesses it within the same
file, `Sender._impl` is independently private. No encapsulation break.

### Comparison

| Criterion | A: Shared | B: Impl Direct | C: Sender |
|-----------|-----------|-----------------|-----------|
| Type-system enforcement | Partial (blocks finish, but finish is lost) | None | Complete |
| finish() callable afterward | No (consumed into Shared) | Yes | Yes |
| _impl visibility change | Yes | Yes | No (same file) |
| New types | 0 | 0 | 1 (Sender) |
| Correct ~Copyable pattern | Wrong (consumes owner) | N/A | Yes (projection) |
| Intent-communicating name | N/A | N/A | Yes ("Sender") |

### Theoretical Grounding

The ~Copyable projection pattern is an instance of **capability decomposition**
from linear type theory. A value with mixed substructural profile (some
capabilities unrestricted, some linear/affine) is decomposed by projecting
the unrestricted capabilities as a separate type:

- **Owner** (affine): `Sink` — ~Copyable, retains `finish()`
- **Projection** (unrestricted): `Sender` — Copyable, has only `send()`

This is the Swift analog of Rust's borrowing/sharing model where `&T` (shared
reference) provides read-only access while `T` (owned) provides consuming
operations. In Swift's ~Copyable system, the projection is explicit (a separate
type) rather than implicit (a reference).

The pattern appears throughout the primitives ecosystem:
- `Property<Tag, Base>.View` projects mutable access from ~Copyable owners
- `Tree.Keyed` projects `Tree.Position` (Copyable cursor) from ~Copyable tree
- `Ownership.Transfer.Cell.Token` projects take-capability from ~Copyable Cell

`Sink.Sender` follows the same structural pattern: a Copyable projection of
a specific capability from a ~Copyable owner.

## Outcome

**Status**: DECISION

**Option C: `Sink.Sender` — the ~Copyable capability projection pattern.**

The Sink projects a Copyable, Sendable `Sender` type that only exposes `send()`.
The type system prevents calling `finish()` through the Sender — incorrect code
does not compile. The Sink retains `finish()` and is consumed exactly once after
all concurrent tasks complete.

**Implementation**:
1. Define `Sink.Sender` in `Test.Reporter.Sink.swift` (same file, `_impl` stays private)
2. Add `var sender: Sender` non-consuming property to Sink
3. Delete `Test.Reporter.Sink.Handle.swift` (the bespoke Handle file)
4. Runner passes `Sender` (not Handle, not `any SinkImplementation`) through tree walk

**Why not Ownership.Shared**: The Sink must be finished after sharing. Shared
consumes the value permanently — no way to call `finish()` afterward. And
wrapping an already-Copyable existential in Shared is a semantic type error.

**Why not raw impl**: The type system would allow calling `finish()` on the
shared existential. Code discipline is not a substitute for type safety.

## Changelog

- v2.0.0 (2026-03-02): Revised decision from Option C (impl direct) to
  Option C (Sender projection). Previous decision relied on code discipline
  for capability restriction; revised to type-system enforcement per
  [IMPL-INTENT] and ~Copyable-first-class principle.
- v1.0.0 (2026-03-02): Initial analysis with 4 options.

## References

- [IMPL-INTENT] Code Reads as Intent, Not Mechanism
- [IMPL-021] Property vs Property.View (~Copyable projection pattern)
- Ownership Primitives: `Ownership.Shared`, `Ownership.Transfer.Cell.Token`
- Wadler, "Linear Types Can Change the World!" (affine/linear decomposition)
