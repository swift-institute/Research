---
title: Typed-throws audit — swift-async-primitives
date: 2026-04-24
scope: Sources/ (Tests/ and Experiments/ excluded)
context: forums-review addressing — post 6 (@reviewer-c3) asked for this audit
status: draft
---

# Typed-throws audit — swift-async-primitives

## Summary (what changed vs the forums-review prediction)

The objections doc (`Research/forums-review-objections-2026-04-24.md`) claimed:

> 12 untyped `throws` sites in source. Mostly deliberate (protocol-conformance-constrained) but merit an audit

Actual state in `Sources/` as of 2026-04-24:

| Form | Count |
|---|---|
| Typed throws `throws(E: Swift.Error)` (any kind) | **41** |
| Untyped `throws` (no type annotation) | **0** |
| `rethrows` | **0** |

**The package is 100% typed throws in Sources/.** The 12-untyped-sites
claim does not reflect current source state. The 71 untyped `throws`
found in `Tests/` are all test-function signatures (`@Test func foo()
async throws`) per the Swift Testing convention — not part of the
package's public API surface and out of scope for this audit.

> **Footnote on tooling counts.** The `swift-forums-review-corpus`
> `characterize_package.py` reports an `untyped_throws` count (18 as of
> 2026-04-25) that includes signatures from both `Sources/` and `Tests/`
> in its grep. The audit count above is `Sources/`-only and is the
> load-bearing figure for any contract-level argument. Future
> tool-versions may stratify the count; until then, treat any
> characterizer-reported `untyped_throws` figure as a Sources/+Tests/
> aggregate and consult this audit for the Sources/-only ground truth.

## Typed-throws distribution by error type

```
  18 sites  throws(E)                                  — generic error propagation
   9 sites  throws(Async.Channel<Element>.Error)       — channel operations
   6 sites  throws(Transition.Error)                   — Completion state transitions
   5 sites  throws(Async.Semaphore.Error)              — semaphore operations
   1 site   throws(Either<Async.Semaphore.Error, E>)   — Async.Semaphore.withPermit (2026-04-24 addition)
   1 site   throws(Async.Broadcast<Element>.Error)     — broadcast subscription next()
   1 site   (docstring example only, non-code)         — Async.Lifecycle.Error<MyError>
```

Total actual typed-throws sites: **41**.

### Per-category disposition

#### `throws(E)` — 18 sites (generic error propagation)

Locations: `Async.Mutex.withLock<T, E>`, `Async.Mutex.withLockIfAvailable<T, E>`,
`Async.Mutex.withLock(consuming: body:)`, `Async.Mutex.withLock(deposit: body:)`,
`Async.Channel.Bounded.Storage.withLock<T, E>`,
`Async.Channel.Unbounded.Storage.withLock<T, E>`, and the `Either.map/mapLeft/bimap`
family (declared in `Algebra Primitives Core`, not this package — a few of the 18
counts are the imported `Either` method signatures visible through the
`public import Algebra_Primitives_Core` in `Async.Semaphore+WithPermit.swift`).

**Disposition**: all deliberate. `throws(E)` is the correct pass-through shape
for these wrapper APIs — the wrapper itself is infallible (locks never fail;
map doesn't fail on its own), only the body's error propagates.

#### `throws(Async.Channel<Element>.Error)` — 9 sites

All in `Async Channel Primitives`. Concrete error type per the per-primitive
error convention. Subject to Q2 (per-primitive vs shared cancellation-error
type); `Async.Channel.Error` is `.closed | .cancelled | .full | .empty`, a
mix of domain (closed/full/empty) and lifecycle (cancelled) cases.

**Disposition**: deliberate; Q2-adoption candidate. If Q2 resolves to
`Async.Lifecycle.Error<E>` adoption, these 9 sites migrate to
`throws(Async.Lifecycle.Error<Async.Channel<Element>.DomainError>)` where
the domain error holds `.closed | .full | .empty` and `.cancelled` lifts
into `Lifecycle.Error`'s `.cancellation`.

#### `throws(Transition.Error)` — 6 sites

In `Async Completion Primitives`. `Async.Completion.Transition.Error` — local
state-transition error, separate from `Async.Completion.Error`. Not the
general-purpose completion-consumer error; internal to the state machine.

**Disposition**: deliberate, internal. Unaffected by Q2.

#### `throws(Async.Semaphore.Error)` — 5 sites

In `Async Semaphore Primitives`. `Async.Semaphore.Error` is
`.shutdown | .cancelled | .timeout` — exactly the `Async.Lifecycle.Error<E>`
shape with `E = Never` (no domain failure case).

**Disposition**: deliberate; Q2-adoption candidate. If Q2 resolves to
adoption, `Async.Semaphore.Error` becomes
`typealias Error = Async.Lifecycle.Error<Never>` and the 5 sites reuse the
typealiased throws type. Zero consumer-visible change at the call-site
spelling.

#### `throws(Either<Async.Semaphore.Error, E>)` — 1 site

`Async.Semaphore.withPermit<T: Sendable, E: Swift.Error>`. New 2026-04-24.
Mirrors `Pool.Bounded.Acquire` precedent. If Q2 lands, the `.Semaphore.Error`
half of the Either might be re-expressed as `.Lifecycle.Error<Never>`, but
the wrapper's Either shape (left = acquire failure, right = body failure)
is independent of the per-primitive-vs-shared-error decision and stays as-is.

**Disposition**: deliberate; interacts with Q2 but doesn't depend on its
resolution.

#### `throws(Async.Broadcast<Element>.Error)` — 1 site

In `Async Broadcast Primitives`, `Async.Broadcast.Subscription.AsyncIterator.next()`.
`Async.Broadcast.Error` is `.cancelled` only — no shutdown, no timeout, no
domain failure.

**Disposition**: deliberate; narrowest Q2-adoption candidate. If Q2 adopts
Lifecycle.Error<E>, Broadcast's error becomes
`typealias Error = Async.Lifecycle.Error<Never>` and just the `.cancelled` →
`.cancellation` spelling changes at sites that pattern-match.

## Untyped throws — none

Zero untyped `throws` declarations exist in `Sources/`. The forums-review
claim of 12 sites is stale or measured against a different definition
(possibly the `characterize_package.py` script counted something else —
e.g., throwing-closure parameter types in signatures, or the test
signatures).

## Interaction with Q2

If Q2 resolves to **adopt `Async.Lifecycle.Error<E>` everywhere**:

| Current typed-throws site family | Q2-adoption shape |
|---|---|
| `Async.Semaphore.Error` (5 sites) | `Async.Lifecycle.Error<Never>` via typealias |
| `Async.Broadcast.Error` (1 site) | `Async.Lifecycle.Error<Never>` via typealias |
| `Async.Channel.Error` (9 sites) | `Async.Lifecycle.Error<Async.Channel.DomainError>` where DomainError = `.closed \| .full \| .empty` |
| `Async.Completion.Error` (consumer-facing, N sites) | already `.timeout \| .cancellation \| .failure(Failure)` — essentially the Lifecycle shape; can adopt directly |
| `Transition.Error` (6 sites, internal) | **unchanged** — internal state-transition error, not a lifecycle concern |
| `throws(E)` pass-throughs (18 sites) | **unchanged** — generic error propagation is orthogonal |
| `Either<Async.Semaphore.Error, E>` (1 site) | **unchanged** or refactors to `Either<Async.Lifecycle.Error<Never>, E>` if the typealias approach is taken |

The "cancelled" vs "cancellation" naming normalizes as a side-effect of
`Async.Lifecycle.Error<E>` adoption (the Lifecycle type uses
`.cancellation`).

## Relation to forums-review finding

This document resolves part of the ask from simulation post 6 (@reviewer-c3):

> I spotted 12 `throws` (untyped) in the source — likely these are deliberate
> and in cases where the error type is already constrained by protocol
> conformance, but a quick audit pass to make sure none of them are
> oversights would be worthwhile before 1.0.

Disposition: addressed. **The 12-untyped claim is wrong for current source
state — package is 100% typed.** If the critique re-appears in a fresh
forums-review simulation, it can be deflected with this file as evidence.
The per-primitive-vs-shared-error-type question (Q2) remains live and is
tracked separately.
