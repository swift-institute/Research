# ~Escapable Arm Support

<!--
---
version: 1.0.0
last_updated: 2026-05-09
status: DECISION
tier: 1
scope: package
trigger: forums-review of swift-either-primitives flagged "Verify and document the ~Escapable × swapped() lifetime story." Per-package operationalization of the ecosystem-wide research at `swift-institute/Research/escapable-support-pair-either-product.md`.
related:
  - swift-institute/Research/escapable-support-pair-either-product.md (ecosystem-wide DECISION)
  - swift-institute/Research/nonescapable-ecosystem-state.md (canonical state)
  - swift-institute/Research/noncopyable-property-extract-via-underscore-owned.md (companion: ~Copyable property extraction)
empirical_validation: Experiments/escapable-arm-support/
---
-->

## Question

Which of Either's functor-surface methods can admit `~Escapable` arms today? What lifetime annotations are required? Where does Swift's closure-parameter lifetime limitation (Gap A) prevent full ~Escapable adoption?

## Empirical results

`Experiments/escapable-arm-support/Sources/EscapableArmSupport/EscapableArmSupport.swift` validates each shape on Swift 6.3.1, Swift 6.4-dev nightly 2026-05-07-a, and Swift 6.4-dev/Embedded.

| Method | ~Escapable support | Lifetime annotation | Status |
|---|---|---|---|
| `Either.swapped(_:)` static | Both arms `~Escapable & ~Copyable` | `@_lifetime(copy either)` | CONFIRMED |
| `Either.swapped()` instance | Both arms `~Escapable & ~Copyable` | `@_lifetime(copy self)` | CONFIRMED |
| `value(of:)` free function | `Right` (or `Left` for the symmetric variant) `~Escapable & ~Copyable` | `@_lifetime(copy either)` | CONFIRMED |
| `Either.map(right:)` static | `Left` (un-transformed) `~Escapable & ~Copyable`; `Right` and `NewRight` Escapable | `@_lifetime(copy either)` | CONFIRMED |
| `Either.map(left:)` static | `Right` (un-transformed) `~Escapable & ~Copyable`; `Left` and `NewLeft` Escapable | `@_lifetime(copy either)` | CONFIRMED |
| `Either.map(left:right:)` static | Both arms must be Escapable | — | BLOCKED — Gap A |
| `Either.flatMap(right:)` / `flatMap(left:)` | Both arms must be Escapable | — | BLOCKED — closure-returns-its-own-Either |
| `Either.fold(left:right:)` | Both arms must be Escapable | — | BLOCKED — closure return-Result with independent lifetime |
| `Either<Never, T>.value` property | Copyable-only | — | BLOCKED — `consuming get` on generic ~Copyable enums (see companion research note) |
| Equation/Hash/Comparison.Protocol institute conformances | Both arms `Equation/Hash/Comparison.Protocol & ~Copyable & ~Escapable` | — | CONFIRMED (after upstream protocol upgrade in swift-equation/hash/comparison-primitives `3495e50` / `0e5708e` / `a4fd209`) |

## What's BLOCKED and why

**Gap A** (per `nonescapable-ecosystem-state.md` §5): closure-parameter lifetime dependencies are not yet ready in Swift. When a closure consumes a `~Escapable` arm and returns a `~Escapable` result, the result's lifetime cannot be tied back to the consumed input. The diagnostic surfaces as:

```
error: lifetime-dependent value escapes its scope
```

Verified empirically on Swift 6.4-dev nightly 2026-05-07-a (`org.swift.64202605071a`).

**flatMap's specific shape**: the closure returns its own `Either<Left, NewRight>`, which has lifetime independent of the consumed input. Adding `@_lifetime(copy either)` would lie about the right-case branch — the result comes from `transform`, not from `either`. flatMap therefore stays Escapable-only on both arms.

**fold's specific shape**: both arms transformed via closures producing `Result`. The result lifetime would need to come from `either`, but the closures' outputs have whatever lifetime the closures decide.

**Mixed-arm map works** because the un-transformed arm's `~Escapable` lifetime IS the result's lifetime — `@_lifetime(copy either)` is faithful to the right-case branch (left arm preserved verbatim) and the wrong-case branch produces an Escapable NewRight independent of either's lifetime.

## Decision

Ship the ~Escapable extensions for the CONFIRMED shapes. Defer the BLOCKED shapes pending Swift compiler progress on Gap A (no SE proposal yet).

The shipped surface uses asymmetric where-clauses on the closure-bearing methods:

- `map(right:)` extension: `where Left: ~Copyable & ~Escapable, Right: ~Copyable`
- `map(left:)` extension: `where Left: ~Copyable, Right: ~Copyable & ~Escapable`
- `map(left:right:)` extension: `where Left: ~Copyable, Right: ~Copyable` (no `~Escapable`)

Instance overloads mirror the static layer's where-clauses.

## Follow-up: equal-arm and accessor coverage (2026-05-09)

Verification spikes against Swift 6.4-dev nightly 2026-05-07-a triaged two
additional shapes after the cohort's main wave:

- **Equal-arm `map { f }` and `flatMap { f }`** (where `Left == Right`)
  with widened constraint `Left: ~Copyable & ~Escapable` and
  `@_lifetime(copy either)`: **DEFERRED**. Compiles in isolation on Swift
  6.4-dev nightly but BLOCKED on two different toolchain failure modes:
  (a) Swift 6.3.1's lifetime checker rejects the widened where-clause
  ("lifetime-dependent value escapes its scope" on the `switch consume
  either`); (b) on Swift 6.4-dev nightly, integrating the widened
  equal-arm extension into the production source introduces an overload-
  resolution ambiguity with the labelled `map(right:)`/`map(left:)` forms
  for `Either<T, T>` where T is Copyable+Escapable (e.g., `Int`).
  Triggers to revisit: (a) Swift 6.3.1 lifetime-checker improvement to
  match 6.4-dev; AND (b) overload-resolution disambiguation strategy
  (e.g., `@_disfavoredOverload` on labelled forms when the trailing
  closure resolves equal-arm). Deferred pending both.

- **`.left` / `.right` peek accessors** for `Copyable & ~Escapable` arms:
  **SHIPPED** with `@_lifetime(borrow self)`. Path A from
  `swift-institute/Research/noncopyable-peek-escapable.md`. Lives in
  `Either+Accessors.swift` as a separate extension matching only on the
  `Copyable & ~Escapable` arm; the existing accessor stays for the
  Copyable+Escapable case; ~Copyable arms have no accessor in either form.

**Path B deferred**: `~Copyable & ~Escapable` peek accessors via a public
`Borrowed<T>` wrapper. Triggers to revisit: (a) explicit need from a real
consumer, OR (b) SE-0519 stdlib `Borrow<T>` shipping with the arity needed.
See `swift-institute/Research/noncopyable-peek-escapable.md` for the
wrapper-pattern verification.

## Cross-references

- Empirical reproduction: `Experiments/escapable-arm-support/`
- Ecosystem-wide research: `swift-institute/Research/escapable-support-pair-either-product.md`
- Sibling-package research (Pair): `swift-pair-primitives/Research/escapable-arm-support.md`
- Sibling-package research (Product): `swift-product-primitives/Research/escapable-blocked.md`
- Upstream institute protocol upgrades: swift-equation-primitives `3495e50`, swift-hash-primitives `0e5708e`, swift-comparison-primitives `a4fd209`
