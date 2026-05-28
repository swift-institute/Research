# Iteration Architecture — Expressibility Envelope (current Swift)

> **RECOMMENDATION (v1.1.0, 2026-05-28)** — Tier 2, cross-package.
> Empirically maps what the three-route iteration architecture
> (`Iterable` / `Sequenceable` / `Iterator.Borrow`) **+ the family-protocol-with-`Backing`
> shape** can and cannot express in **Apple Swift 6.3.2** (`swiftlang-6.3.2.1.108`,
> `arm64-apple-macosx26.0`, debug **and** release), **under the full ecosystem Swift settings**
> (`.strictMemorySafety()`, `Lifetimes`, `SuppressedAssociatedTypes`, `ExistentialAny`,
> `InternalImportsByDefault`, `MemberImportVisibility`, `NonisolatedNonsendingByDefault`,
> `InferIsolatedConformances`, `LifetimeDependence`). The toy builds **warning-clean**.
>
> Backing experiment: [`Experiments/iteration-architecture-toy`](../Experiments/iteration-architecture-toy)
> — a self-contained top-to-bottom toy (no package deps; toy protocols defined in-package).
> Companion to [memory-contiguous-iteration-bridge.md](memory-contiguous-iteration-bridge.md)
> (the substrate bridges + OQ-1/OQ-2) and `HANDOFF-iteration-architecture-probe.md` (the arc).
>
> **v1.1.0 correction (do not skip):** v1.0.0 reported makeIterator delegation through `Backing`
> as flatly REFUTED. That was wrong — it is refuted only for a **borrow-self** backing. With a
> **`~Escapable` view backing whose makeIterator is `@_lifetime(copy self)`**, delegation
> compiles checker-clean **and runs** (shape **D1**). The handoff's goal — "a `Backing` carries
> makeIterator delegation once" — **is achievable.** Headline rewritten accordingly.
>
> **This is an empirical probe for principal architecture confirmation. It does NOT touch the
> real packages.** §4 implications are recommendations, not landed work.

## 1. The question

The probe handoff proposed a family-protocol "lean" to collapse per-variant iteration
boilerplate across ~18 data-structure packages:

> `X.Protocol` **refines `Collection.Protocol`** (intrinsic), **conditional-conforms**
> `Iterable`/`Sequenceable` (`where Element: Copyable`), and a **`Backing` associated type**
> carries `makeIterator` delegation **once** (collapsing per-variant repetition).

This experiment verifies the two reported-REFUTED "lift" shapes minimally, then maps the
surrounding envelope: what *does* compile and run end-to-end, exercising **both Copyable and
`~Copyable` elements**, with **route 3 (`~Copyable` borrowing) the crux**.

## 2. Verdicts

Each verdict is the **first clean signal** per `[EXP-011a]`; diagnostics are captured verbatim in
the experiment's per-file source headers (`Family.swift` A/B/C; `Phase2Revisit.swift` D1/D2/D3;
`Phase2RevisitRun.swift` boundary). "family default" = a body written **once** on the family
protocol that all conformers inherit.

| # | Shape | Verdict | Mechanism / diagnostic |
|---|-------|---------|------------------------|
| **A** | **Lift**: `extension MyFamily.Protocol: Iterable where Backing: Iterable` | **REFUTED** (compile) | `error: extension of protocol 'Protocol' cannot have an inheritance clause`. A protocol cannot gain conformance to another protocol via an extension. |
| **B** | `makeIterator` family default via `backing.makeIterator()` where the backing makeIterator is **`@_lifetime(borrow self)`** (the current `Iterable`) | **REFUTED** (compile) | `error: lifetime-dependent value escapes its scope`. The iterator depends on the **temporary `backing` projection**; `@_lifetime(borrow backing)` is not flattened into `@_lifetime(borrow self)`. |
| **D1** | `makeIterator` family default via `backing.makeIterator()` where the backing is a **`~Escapable` view** with **`@_lifetime(copy self)`** makeIterator | **CONFIRMED** (compiles + runs) | **The rescue.** `copy` propagates the view's own (borrow-outer-self) dependency into the iterator → flattens to `@_lifetime(borrow self)`. Checker-clean, no `unsafe`. Runs: `[11, 22, 33]`. |
| **b** | `makeIterator` default via **direct `self.span` projection** + `@_lifetime(copy span)` iterator init | **CONFIRMED** (compiles + runs) | Same `copy`-flattening, on the substrate. **This is the existing green `Memory.Contiguous → Iterable` bridge.** |
| **C** | `forEach` family default via `backing.forEach(body)` **delegation** (route 3, `~Copyable`) | **CONFIRMED** (compiles + runs, debug+release) | `forEach` returns `Void` — no escaping lifetime-dependent value. Runs: `sum=600`. |
| **2** | `Sequenceable` consuming `makeIterator` family default via generic owning-drain over consumed `Self` | **CONFIRMED in toy** (runs) | Real generic path is REFUTED-at-runtime per [memory-contiguous-iteration-bridge.md](memory-contiguous-iteration-bridge.md) OQ-2 (`swift_getAssociatedTypeWitness` demangle); the minimal toy **does not reproduce** it (`[EXP-021]`, trigger in the delta). |
| **a** | closure-callback `withBacking<R>(_ body: (borrowing Backing) -> R) -> R` | **CONFIRMED** (runs) | Lends the backing for the call's duration; no escaping value. |
| **c** | witness-struct delegation (value holding a `(borrowing Source, (borrowing Element) -> Void) -> Void` closure) | **CONFIRMED** (runs) | Iteration-as-data; borrowing-`~Copyable` closure signatures are expressible and invocable. |
| **D2** | rescue B via `_overrideLifetime(view.makeIterator(), borrowing: self)` at the family-default level | **REFUTED** (compile) | Through a family default the backing is a **computed `view` getter** (a temporary). Inline → `lifetime-dependent value escapes its scope`; bound to a local → `'self.view' is borrowed and cannot be consumed`. `_overrideLifetime` works for a *stored* projection (the `span` getter uses it) but not a borrow-self makeIterator through a computed view. **D1 (copy-self) is the clean rescue.** |
| **D3** | add `where Element: ~Copyable` / `~Escapable` to the extension (the literal suggestion to "narrow Element") | **REFUTED** (compile) | `error: cannot suppress '~Copyable' on generic parameter 'Self.Element' defined in outer scope`. You cannot re-suppress an inherited associated type in an extension where-clause — and it would not help: the escape is about the **iterator's** lifetime, not the element's. |
| **boundary** | an **Escapable OWNED** container conforming the copy-self protocol *directly* (by constructing its own `~Escapable` iterator) | **REFUTED** (compile) | `error: lifetime-dependent value escapes its scope`. `@_lifetime(borrow self)` does not satisfy a `@_lifetime(copy self)` requirement (the `~Escapable` iterator escapes the copy-self "immortal" contract); `@_lifetime(copy self)` is invalid on an Escapable self. Owned containers **expose** a copy-self view; they don't conform copy-self. |

### 2.1 Substrate-level envelope findings (Phase 1)

- **`associatedtype Element: ~Copyable`** (and `~Escapable`) requires **`SuppressedAssociatedTypes`**; **`@_lifetime`** requires **`Lifetimes`** (NOT `LifetimeDependence` alone).
- **`Span`, `UnsafePointer`, `withUnsafePointer` force `Element: Escapable`** — so `Ownership.Borrow<Wrapped>` wraps a `~Copyable`-**but-Escapable** element; route-3 borrowable storage holds `~Copyable` Escapable elements (a `Span` of them works).
- **`@_lifetime(borrow/copy self)` is invalid on an Escapable result.** The base iterator's `next() -> Element?` (owned Escapable element) carries no `@_lifetime`; only `~Escapable` results take it.
- **Namespace shadowing**: an `associatedtype Iterator` shadows an `Iterator` namespace inside the declaring scope; references must be module-qualified (the ecosystem sidesteps this with `Sequence.Iterator.\`Protocol\``).
- **Protocol subscripts allow only `{ get }`/`{ set }`** — `_read` is rejected in a requirement; the borrowing read is a witness detail.
- **Extension-implies-Copyable** (`feedback_extension_implies_copyable`): a bare `extension Family.Protocol { }` or `extension Iterator.Drain: Iterator.Protocol { }` silently adds `Self`/`Base: Copyable`, excluding the `~Copyable` conformers. Every family-default / conformance extension MUST restate `~Copyable` (and `~Escapable`).
- **`Span(_unsafeElements:)` ties the span's lifetime to its argument**; re-attribute to `self` with `_overrideLifetime(span, borrowing: self)` in a `@_lifetime(borrow self)` getter.
- **`.strictMemorySafety()`**: `UnsafePointer`/`UnsafeMutableBufferPointer`/`withUnsafePointer`/`Span(_unsafeElements:)`/`_overrideLifetime` emit `#StrictMemorySafety` warnings unless marked. Safe-interface wrapper types take `@safe`; unsafe expressions take `unsafe`; **assignments to an unsafe-typed stored property must mark the whole assignment** (`unsafe buffer = .allocate(...)`), and a "safe" call on an unsafe value (e.g. `UnsafeMutableBufferPointer.initializeElement`) needs the **receiver read** marked (`(unsafe buffer).initializeElement(...)`), not the call.

## 3. The governing principle

> **A lifetime-dependent return value (an iterator) composes through `@_lifetime(copy …)`,
> never through `@_lifetime(borrow <local>)`.** `copy` propagates the source's *own* dependency
> into the result; `borrow` of a local temporary ties the result to that temporary's scope, which
> ends at the expression and escapes.

This single principle explains the whole table:

- `Iterator.Chunk(self.span)` with `init … @_lifetime(copy span)` (shape **b**) — the iterator
  inherits `span`'s borrow-self dependency. Composes.
- `view.makeIterator()` where the view's makeIterator is `@_lifetime(copy self)` and the view is
  `~Escapable` with lifetime borrow-outer-self (shape **D1**) — the iterator inherits the view's
  dependency. Composes, **even through the `Backing` indirection**.
- `backing.makeIterator()` where makeIterator is `@_lifetime(borrow self)` (shape **B**) — the
  iterator borrows the local `backing` temporary. Escapes.

Internal iteration (`forEach`/`withBacking`/witness, shapes **C/a/c**) sidesteps the issue
entirely: returning `Void`, there is no lifetime-dependent value to compose.

## 4. The positive architecture (compiles + runs end-to-end)

The toy runs all six exercises green (debug + release, clean + warning-clean):

```
route 1 (Iterable makeIterator over span):                       [10, 20, 30]
route 3 (forEach borrowing ~Copyable):                           sum=600
route 2 (Sequenceable drain, generic owning iterator):           total=10
alt (a) withBacking closure-callback:                            count=3
alt (c) witness-struct delegation:                               sum=12
D1 (copy-lifetime makeIterator delegation via Backing):          [11, 22, 33]
```

Mapping the handoff lean onto the verdicts:

1. **`refines Collection.Protocol` (intrinsic): CONFIRMED.**
2. **`conditional-conforms Iterable/Sequenceable`: REFUTED** (shape A — no protocol-extension
   inheritance clause). **Each variant declares `: Iterable` / `: Sequenceable` itself** (one
   line; `@_implements` to disambiguate the dual `Iterator`, since `Iterable.makeIterator` is
   `borrowing` and `Sequenceable`'s is `consuming`). Conformance is per-variant; the **body** is
   inherited.
3. **`Backing` carries makeIterator delegation once: ACHIEVABLE** (shape **D1**) — provided the
   `Backing` is a **`~Escapable` view whose makeIterator is `@_lifetime(copy self)`**. The variant
   exposes such a view (e.g. a span view); the family default delegates to it. (The substrate-
   direct form **b** — `@_lifetime(borrow self)` over `self.span` — is the alternative when no
   view indirection is wanted; it is the existing green bridge.)
4. **Lifetime-shape split (not a unification).** An Escapable **owned** container takes
   `@_lifetime(borrow self)` makeIterator (direct, shape b); a `~Escapable` **view** takes
   `@_lifetime(copy self)` (delegable, D1). They do **not** collapse into one protocol (the
   boundary row). But the family delegates through the copy-self view regardless, so "once" still
   holds at the family level.
5. **The consuming route (2) needs OWNED storage to consume** — it cannot share the borrowing
   routes' `~Escapable` view backing. Route 2 is its own conformance.

### 4.1 Recommended fan-out template

For each data-structure variant:

- Expose a **`~Escapable` `Backing` view** with a **`@_lifetime(copy self)` makeIterator** (route 1)
  and a borrowing **`forEach`** (route 3). Inherit BOTH from single family-protocol defaults
  (D1 + C) — the bodies live once.
- Declare `: Iterable` / `: Sequenceable` **per-variant** (one line each; `@_implements` split).
  Conformance is per-variant; bodies are inherited.
- `~Copyable`-element variants use **route-3 `forEach`** (the memory→Iterable copy bridge needs
  `Copyable`); because a borrow serves Copyable too, **the borrowing `forEach` unifies the
  copyability split for internal iteration**.
- Alternative (no view indirection): conform the substrate (`Memory.Contiguous`) and take the
  borrow-self direct makeIterator (shape b) — the existing bridge. Choose per family.

### 4.2 Answers to the handoff's open questions

- **"Compose with variant generics + `@_implements` split, or fall back to per-variant?"** —
  conformance **declarations** are per-variant (lift refuted); the makeIterator and forEach
  **bodies** are single family defaults (D1 + C).
- **"Does one borrowing `forEach` unify and subsume Step-1?"** — **Yes for internal iteration.**
- **"Where does each default live?"** — makeIterator and forEach: **family-protocol defaults**
  delegating to a copy-self `~Escapable` view backing (D1 + C). Conformance declarations:
  per-variant. Substrate-direct makeIterator (b) is the no-view-indirection alternative.

## 5. Caveats & scope

- **Single-module** (`[EXP-017]`). Refutations (A, B, D2, D3, boundary) are module-independent
  (compile errors). The positive D1/C delegations mirror the production bridge's already-cross-
  module shape; **cross-module re-validation is deferred to the real-package fan-out.**
- **Decision required from the principal:** adopting D1 means the institute's **backing-view**
  iteration protocol must use **`@_lifetime(copy self)`** makeIterator (distinct from the current
  borrow-self `Iterable`/`Sequence.Borrowing.Protocol`, which stays for substrate-direct). This is
  a new protocol shape, not a change to the existing one — confirm before fan-out.
- **Route 2's real-world REFUTED-at-runtime** verdict is **inherited** from
  [memory-contiguous-iteration-bridge.md](memory-contiguous-iteration-bridge.md) OQ-2, not from
  this toy (which does not reproduce the demangle crash minimally; `[EXP-021]`).
- The toy is faithful in **shape** and **build settings** (full ecosystem flags, warning-clean),
  but minimal. It is an **expressibility** probe, not a performance or ABI probe.

## 6. Cross-references

- Experiment: `swift-institute/Experiments/iteration-architecture-toy` (this note's evidence).
- [memory-contiguous-iteration-bridge.md](memory-contiguous-iteration-bridge.md) — the substrate
  bridges, OQ-1, OQ-2 (generic demangle). Shape b here = that doc's memory→Iterable bridge.
- `HANDOFF-iteration-architecture-probe.md` — the arc; the three routes; the family-protocol lean.
- `[EXP-011a]`, `[EXP-017]`, `[EXP-021]`, `feedback_extension_implies_copyable`.
