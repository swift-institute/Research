# Naming: `Ownership.Slot.Store` (result enum) → removed; `store(_)` returns `Value?`

<!--
---
version: 2.0.0
last_updated: 2026-04-24
status: IMPLEMENTED
tier: 1
scope: cross-package
---
-->

## Changelog

- **v2.0.0 (2026-04-24)** — Revised outcome. The rename-to-`Outcome` recommendation is
  SUPERSEDED by **removal**: `store(_ value:)` returns `Value?` directly.
  The `Slot.Store` enum is deleted from the public API. Rationale: the enum
  is isomorphic to `Optional<Value>` (`.stored` ≡ `nil`, `.occupied(v)` ≡
  `.some(v)`), and Apple's stdlib has the exact shape as `Dictionary.updateValue(_:forKey:)`.
  Ecosystem sweep confirmed zero external consumers of the enum cases —
  every `slot.store(_)` caller uses `_ = slot.store(...)` and the signature
  change is source-compatible. Change landed with `store(_)`'s signature
  preserving the original `consuming Value` input (no `sending`) to avoid
  cascading breaks in swift-async-primitives and swift-pool-primitives.

- **v1.0.0 (2026-04-24)** — Recommended rename to `Slot.Outcome` to break
  the verb/noun collision with `slot.store(_)`. SUPERSEDED by v2.0.0 which
  removes the enum entirely.

## Context

`Ownership.Slot` exposes a total store operation:

```swift
public func store(_ value: consuming Value) -> Store
public enum Store: ~Copyable {
    case stored
    case occupied(Value)
}
```

The operation is `store`; its result type is also `Store`. The verb
and the result-type noun collide at the call site:

```swift
switch slot.store(value) {   // method named "store"
case .stored: …              // case name
case .occupied(let v): …
}
// type of the switched value is Slot.Store — verb/noun collision
```

Ahead of the 0.1.0 tag, this naming is flagged as a readability wart.

## Question

Should the result-enum name be disambiguated from the method name?

## Prior Art — Result-Type Naming

### Apple stdlib

Where Apple stdlib returns a named result from a mutation, the result
type is named for the **outcome**, not the **operation**:

- `Dictionary.insert(_:)` returns `(inserted: Bool, memberAfterInsert: Element)`
  (tuple — the fields are named for outcome, not for "insert").
- `Set.insert(_:)` → `(inserted: Bool, memberAfterInsert: Element)`.
- `Atomic<T>.compareExchange` → `(exchanged: Bool, original: T)` (SE-0410).
- `Result<Success, Failure>` — the top-level type is itself named
  "Result" (the outcome), not for any specific operation.

The consistent pattern: the result-type name describes **what happened**,
not **what was called**.

### Swift language guide

The Swift API Design Guidelines (the design guide Apple ships with
Swift) state under "Strive for Fluent Usage": "When the first argument
forms part of a prepositional phrase, give it an argument label" —
and under "Name variables, parameters, and associated types according
to their roles, not their types". Both principles nudge away from
naming a result for the method that produced it.

### Academia

Functional / dependently-typed literature consistently uses *outcome*
or *result*:

- Haskell `Either e a`, `These a b` — outcome, not operation.
- Rust `std::collections::btree_map::Entry` — the state of a slot, the
  outcome of a lookup, not the lookup itself.
- Idris, Agda: `Dec P` — decision result. Outcome-named.

### Other result-type idioms in this ecosystem

From a grep of `swift-primitives/`:

- `Kernel.Readiness.Outcome`
- `Parser.Match.Result`
- `Input.Read.Outcome`
- `Channel.Send.Action` — post-lock action enum
- `Channel.Receive.Action`

The dominant ecosystem pattern is `{Operation}.Outcome` or
`{Operation}.Action` (for imperative side-effect dispatch) or
`{Operation}.Result` (for value-like result-of-computation). None
reuses the method's name for the result type.

## Analysis

### Name alternatives

| Option | Reads as | Collision? | Notes |
|--------|----------|-----------|-------|
| `Slot.Store` (current) | `slot.store(_) -> Slot.Store` | **YES** — verb and noun identical | Confusing when reading the switch site |
| `Slot.Outcome` | `slot.store(_) -> Slot.Outcome` | None | Matches ecosystem pattern (`Kernel.Readiness.Outcome`) |
| `Slot.Stored` (past participle) | `slot.store(_) -> Slot.Stored` | Weaker collision | "Stored" reads as a state, fine |
| `Slot.Store.Outcome` (nested) | `slot.store(_) -> Slot.Store.Outcome` | Keeps collision at `Store` | Extra nesting, no net gain |
| `Slot.StoreResult` | `slot.store(_) -> Slot.StoreResult` | Compound name | **Violates [API-NAME-002]** |

### Argument for `Outcome`

1. Matches the ecosystem convention (`Kernel.Readiness.Outcome`).
2. Describes what happened, not what was called — aligns with Apple's
   API Design Guidelines.
3. Does not collide with the `store(_)` method.
4. Single leaf noun, no compound identifier.
5. Rapidly disambiguates at the switch site:
   ```swift
   switch slot.store(value) {       // method
   case .stored: …                  // outcome case
   case .occupied: …
   }
   // result type: Slot.Outcome  (reads natural)
   ```

### Argument for `Stored` (past participle)

1. Reads slightly more specifically than `Outcome`.
2. Signals "this describes what happened AFTER the store".

The problem: `Slot.Stored` reads as "the `Stored` variant of `Slot`",
suggesting a state discriminator — not a result enum. `Outcome` is
less ambiguous because it is a dedicated noun for "what the operation
resolved to".

### Argument against renaming

1. v1.0.0 inventory: non-zero but small internal surface. Every
   `switch slot.store(_)` call site needs updating.
2. The collision is a readability wart, not a correctness issue.

The cost is tiny and confined to this package; the benefit lands at
every future reader.

## Outcome

**Status**: IMPLEMENTED 2026-04-24 — `Slot.Store` enum removed; `store(_)`
returns `Value?` directly.

**Decision basis**: the enum is isomorphic to `Optional<Value>` (one arm
is `Void`-tagged). Apple stdlib's `Dictionary.updateValue(_:forKey:)`
is the canonical precedent for exactly this shape: the `Optional`
carries the value the operation did NOT consume (`nil` = "I took/stored
it; nothing to return"; `.some(v)` = "I rejected yours; here it is").
Removing the enum is strictly better than renaming it to `Outcome`:

- drops one type from the 0.1.0 frozen API surface,
- makes `store(_)` and `take()` symmetric on return shape (both `Value?`),
- removes the `Slot.Store` DocC page (one fewer to maintain),
- reuses existing ecosystem idiom (`Optional+take.swift` extends
  `Optional<Wrapped: ~Copyable>` with Rust-style `.take()`).

**Implemented signature**:
```swift
public func store(_ value: consuming Value) -> Value?
// nil               — slot was empty; value is now stored
// .some(returned)   — slot was occupied; caller's value bounced back
```

Ecosystem sweep (2026-04-24) confirmed zero external consumers of the
`.stored` / `.occupied` enum cases. Every external `slot.store(_)` call
uses `_ = slot.store(...)` — source-compatible with the new `Value?`
return.

Files changed in `swift-ownership-primitives`:

- `Sources/Ownership Slot Primitives/Ownership.Slot.Store.swift` — deleted;
  replaced by `Ownership.Slot+Store.swift` (store operations) and
  `Ownership.Slot+Take.swift` (take operations, unchanged behavior).
- `Sources/Ownership Slot Primitives/Ownership.Slot.swift` — docstring
  updated.
- `Tests/Ownership Primitives Tests/Ownership.Slot Tests.swift` — three
  tests updated to match on `nil` / `.some` instead of `.stored` / `.occupied`.
- `Sources/Ownership Primitives/Ownership Primitives.docc/Ownership.Slot.Store.md` — deleted.
- `Sources/Ownership Primitives/Ownership Primitives.docc/Ownership.Slot.md` — topic list + example updated.
- `Sources/Ownership Primitives/Ownership Primitives.docc/Slot-Move-vs-Store.md` — total-API description updated.

Builds clean on Swift 6.3.1; 84 tests in 33 suites pass. Consumers verified:
- `swift-async-primitives` — builds clean (9 `_ = slot.store(...)` sites unchanged)
- `swift-pool-primitives` — builds clean (typealias-only, no method use)

## References

- [Dictionary.updateValue(_:forKey:)](https://developer.apple.com/documentation/swift/dictionary/updatevalue(_:forkey:)) — Apple's canonical shape: Optional carries the value the operation did NOT consume
- [Array.popLast()](https://developer.apple.com/documentation/swift/array/poplast()) — Optional return for may-fail total operation
- [Dictionary.removeValue(forKey:)](https://developer.apple.com/documentation/swift/dictionary/removevalue(forkey:)) — same shape
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) — Apple, role-based naming
- [SE-0437: Noncopyable stdlib primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md) — Optional<~Copyable> support
- `Sources/Ownership Primitives Standard Library Integration/Optional+take.swift` — in-package `Optional<Wrapped: ~Copyable>.take()` extension (Rust-style), already in use by `slot.take()`
- v2.1.0 `ownership-types-usage-and-justification.md` — Cluster E (superseded by this removal)

## Provenance

Per-module naming research requested 2026-04-24 to align the 0.1.0 API
surface with Apple's API Design Guidelines and the ecosystem's
`.Outcome` pattern. During review, the principal identified that
`Optional<Value>` (stdlib) captures the same shape with Apple-canonical
precedent (`Dictionary.updateValue`), and the named enum is unnecessary.
Landed as removal rather than rename.
