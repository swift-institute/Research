# Iteration Architecture — Expressibility Envelope (current Swift)

> **RECOMMENDATION (v1.3.0, 2026-05-28)** — Tier 2, cross-package.
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
> **v1.3.0 addition — TRAVERSAL-ONLY RE-ATTACK (do not skip; OVERTURNS the headline of gap (b)):**
> v1.2.0's gap (b) reported "non-contiguous D1 **REFUTED**" — but it used the **easy Escapable walker**
> (a plain `struct` owning a `[TreeNode]` stack / `[[Int]]` arrays, i.e. *Escapable*), so
> `@_lifetime(copy self)` was "invalid on an Escapable result." **That refutes only ONE formulation.**
> v1.3.0 re-attacks with a **`~Escapable`, self-lifetime-tied walker** (the supervisor's lead
> hypothesis) and finds the traversal-only design space **RE-OPENS**: trees and hashes **DO** ride a
> unified family delegation. Three angles (§7):
> **(A)** a `~Escapable` walker tied to `self` — **flat/heap trees, hashes, and boxed trees with a real
> borrowed region all ride the SAME D1 family default** (debug **and** release). A genuinely-boxed
> walker with `@_lifetime(immortal)` (no borrowed region) compiles+runs **debug** but hits a **release
> compiler crash** through the generic default (a SIL inliner bug, *not* a language wall — the direct
> path and the real-region variant are release-clean). `~Copyable` elements cannot use the external-
> iterator route at all (move-out wall). **(B)** **ONE** family protocol with **two** conditional
> same-named `makeIterator` defaults (copy-self vs plain), dispatched by `Backing.Iterator`
> escapability — **CONFIRMED** debug+release. **(C)** **ONE `forEach` family default** unifies
> span-projecting + boxed-tree + `~Copyable` — **CONFIRMED** debug+release, the **most complete**
> unification. **Net: a single unified family delegation across span-projecting + traversal-only IS
> achievable** (Angle C universally; Angle A/B for the external-iterator + Copyable subset), with one
> compiler bug to route around for the pure-`immortal` boxed case. See §7.
>
> **v1.2.0 addition (retained):** v1.1.0 proved D1 only for the **contiguous** (single-`Span`)
> case and explicitly deferred cross-module. v1.2.0 closes three gating gaps for the
> ~18-data-structure-package decision (§7): **(a) piecewise** (ring/deque, two segments, no single
> span) — D1 **CONFIRMED**; **(b) non-contiguous** (tree/hash, no span at all) — D1 **REFUTED for the
> easy-Escapable walker** (superseded by §7); **(c) cross-module** — D1, `forEach` (C), and route-2
> **CONFIRMED** across a real library→executable module boundary in debug **and** release. The §5
> single-module caveat is lifted for D1/C/route-2.
>
> **v1.1.0 correction (retained):** v1.0.0 reported makeIterator delegation through `Backing`
> as flatly REFUTED. That was wrong — it is refuted only for a **borrow-self** backing. With a
> **`~Escapable` view backing whose makeIterator is `@_lifetime(copy self)`**, delegation
> compiles checker-clean **and runs** (shape **D1**). The handoff's goal — "a `Backing` carries
> makeIterator delegation once" — **is achievable.** Headline rewritten accordingly.
>
> **This is an empirical probe for principal architecture confirmation. It does NOT touch the
> real packages.** §4 and §7 implications are recommendations, not landed work — the choice
> between the D1-family lean and per-variant shape-b is the principal's/supervisor's to make.

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
| **a (v1.2.0)** | **Piecewise**: D1 over a **two-segment** ring/deque view holding two spans (no single span) | **CONFIRMED** (compiles + runs, debug+release) | The iterator and the view each hold two spans; declaring `@_lifetime(copy a, copy b)` flattens **both** borrow-self dependencies. Runs in logical order `[50, 60, 10, 20, 30]`. The only delta from contiguous D1: a single-arg `@_lifetime(copy a)` on a two-span init gives `error: lifetime-dependent variable 'self' escapes its scope … it depends on the lifetime of argument 'b'`; adding `copy b` clears it. **Piecewise stays inside the D1 envelope.** |
| **b (v1.2.0)** | **Non-contiguous**: D1 over a tree (boxed nodes) / hash (array-of-buckets) view with **no span at all** | **REFUTED** (compile) | `error: invalid lifetime dependence on an Escapable result` on the view's `@_lifetime(copy self)` makeIterator. A node-/bucket-walking iterator holds ARC refs / value arrays — it borrows no memory region, so it is **Escapable**, and `@_lifetime` is invalid on it. **Surviving routes:** a **plain** (non-lifetime) `Sequence`-style `makeIterator` (a *different* protocol from D1) and route-3 `forEach` (C). Both run (tree in-order `[1..7]`; hash chains `[10,11,22,30,31,32]`; tree `forEach` sum=28). **Non-contiguous falls outside the D1 envelope.** |
| **c (v1.2.0)** | **Cross-module**: D1, `forEach` (C), route-2 across a library→executable module boundary | **CONFIRMED** (compiles + runs, debug+release, cross-module) | Downstream conformers (executable target) inherit family-default bodies defined in the upstream library target. Runs `[14,25,36]` / sum=600 / total=10. Only cross-module deltas (routine import discipline, **not** mechanics): the consumer must `import` the library (`#MemberImportVisibility`: `instance method 'makeIteratorD1()' is not available due to missing import…`), and a leaf executable's conformers stay `internal` (a `public` conformance to an internally-imported protocol needs `public import`). **Lifts the §5 single-module caveat for D1/C/route-2.** |
| **A1 (v1.3.0)** | **Traversal-only tree (flat/heap, index-addressed)** via the D1 family default — `~Escapable` walker borrows the node array as `Span<Node>` + internal index-stack | **CONFIRMED** (compiles + runs, debug+release) | A heap-style tree (nodes in `[Node]`, children by index) IS span-projecting (one span = the node array). A `~Escapable` walker over it (`@_lifetime(copy nodes)`) rides the **same** `FamD.makeIteratorD1`. Runs `[1..7]`. The traversal *logic* is irrelevant to the lifetime mechanics. **Overturns gap (b) for flat trees.** |
| **A2 (v1.3.0)** | **Traversal-only BOXED tree** (genuinely no span — `TreeNode` refs) via the D1 family default — `~Escapable` walker, `@_lifetime(immortal)` | **PARTIAL** — compiles + runs **debug**; **RELEASE COMPILER CRASH** | The boxed walker (`: ~Escapable`, ARC refs + `[TreeNode]` stack, `@_lifetime(immortal)` init) compiles checker-clean and runs in **debug**. `swift build -c release` **crashes the compiler**: `Abort: function forwardToInit … Cannot initialize a nonCopyable type with a guaranteed value` while the inliner specializes `makeIteratorD1<ToyBoxedTree>`. **Not a language wall** — it is a SIL-optimizer bug: **A2-direct** (call `view.makeIterator()` directly, bypassing the generic default) is release-clean, and **A2b** (give the walker a *real* borrowed `Span`) is release-clean through the default. The `~Escapable` is a real lifetime tie, not a vacuous escape hatch (a no-source return errors: "a function with a ~Escapable result needs a parameter to depend on"). |
| **A3 (v1.3.0)** | **Traversal-only HASH (separate chaining)** via the D1 family default — flatten chains into one `[Int]` pool, `~Escapable` walker over `Span<Int>` | **CONFIRMED** (compiles + runs, debug+release) | Real flat/open-addressed hashes store values in one pool; the walker borrows it as a span (same A1 mechanism). Rides `FamD.makeIteratorD1`, no crash (real span = A1/A2b happy case). Runs `[10,11,22,30,31,32]`. The "hash has no span" framing was about the `[[Int]]` *representation*, not the structure. |
| **A4 (v1.3.0)** | **`~Copyable` elements via the D1 / external-iterator route** (`next() -> Element?`) | **REFUTED for D1** (CRASHES SILGen) | `next()` returns the element **by value** → moving a `~Copyable` out of a borrowed span. `return span[i]` **crashes the compiler at SILGen** (`forwardToInit`, even debug) — the same bug family as A2; reduction confirms the move-out is the trigger (`return span[i].copyableField` and `return nil` both compile clean). The boundary is real *and* the language shape of `next()` makes the external-iterator route **inherently Copyable-only**. `~Copyable` iteration belongs to route-3 `forEach` (C). |
| **B (v1.3.0)** | **ONE family protocol, TWO conditional `makeIterator` defaults** (same method name) gated by `Backing.Iterator` escapability (copy-self vs plain) | **CONFIRMED** (compiles + runs, debug+release) | One protocol carries both `@_lifetime(borrow self)` (gated `Backing: IterableByCopy`) and plain-no-`@_lifetime` (gated `Backing: PlainIterable`) defaults for the same `makeIteratorB()`; the compiler dispatches per-conformer. Runs `[10,20,30]` (copy-self) / `[7,8,9]` (plain). A genuine **protocol-level** unification (one protocol, two families). Only release hazard is the orthogonal A2 bug (an earlier `immortal`-boxed plain conformer crashed release; an Escapable owning walker is clean). |
| **C (v1.3.0)** | **ONE `forEach` family default** unifying span-projecting + traversal-only + `~Copyable` | **CONFIRMED** (compiles + runs, debug+release) | **The most complete unification.** One `FamC.forEach` (backing-delegation) default serves a span array (`sum=60`), a boxed tree (`[1..7]`), and `~Copyable` `Resource` elements (`sum=600`). `forEach` returns `Void` and *lends* via a borrowing closure → no lifetime-dependent return (no copy-self view, no A4 move-out), and carries `~Copyable` natively. **Cost:** internal-iteration only (no pull-style `next()`, lazy, zip, peek, early-exit). A boxed backing still needs the A2b real-span workaround to dodge the A2 bug. |

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

**Corollary (v1.2.0) — the two directions the principle generalises:**

- **Out to N segments (piecewise, gap a):** the `copy`-flatten composes per *field*, not per *type*.
  A view/iterator holding K lifetime-dependent spans declares `@_lifetime(copy a, copy b, …)` for
  each; the merged dependency flattens into the result exactly as the single-span case does.
  Ring/deque-shaped containers therefore ride the **same** D1 family default as contiguous ones.
- **But only where there is a lifetime to copy (non-contiguous, gap b):** `@_lifetime(copy self)`
  requires a **`~Escapable`** (lifetime-dependent) result. An iterator that walks boxed nodes or
  hash buckets holds ARC references / value arrays — it borrows no memory region, so it is
  **Escapable**, and the compiler rejects `@_lifetime` on it (`invalid lifetime dependence on an
  Escapable result`). With no span to borrow, there is no dependency to copy, and **D1 is
  structurally inapplicable.** Such structures use a plain (non-lifetime) `makeIterator` or
  route-3 `forEach` instead — neither returns a lifetime-dependent value, so neither needs D1.

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

> **v1.2.0 scope note (⚠ revised by §7, v1.3.0):** v1.2.0 said this template applies only to
> **span-projecting** variants and that **traversal-only** (tree/hash/graph) is "outside the D1
> family." §7 revises that: **flat/heap trees and hashes ARE span-projecting** (one span = the node
> array / value pool) and ride D1 (the template applies to them too); **boxed** trees ride D1 *modulo*
> the §7.4 release compiler bug (route around it, or use the A2b real-region form); and **one `forEach`
> default (C) unifies every structure + `~Copyable`** (the universal vehicle). Prefer `forEach` (C) as
> the primary default with `makeIterator` (D1) as the secondary pull-style witness — see §7.5.

For each **span-projecting** data-structure variant:

- Expose a **`~Escapable` `Backing` view** with a **`@_lifetime(copy self)` makeIterator** (route 1)
  and a borrowing **`forEach`** (route 3). Inherit BOTH from single family-protocol defaults
  (D1 + C) — the bodies live once. For **piecewise** (ring/deque) backings the view holds K
  segment spans and lists `@_lifetime(copy s1, copy s2, …)` per segment — same default, gap (a).
- Declare `: Iterable` / `: Sequenceable` **per-variant** (one line each; `@_implements` split).
  Conformance is per-variant; bodies are inherited.
- `~Copyable`-element variants use **route-3 `forEach`** (the memory→Iterable copy bridge needs
  `Copyable`); because a borrow serves Copyable too, **the borrowing `forEach` unifies the
  copyability split for internal iteration**.
- Alternative (no view indirection): conform the substrate (`Memory.Contiguous`) and take the
  borrow-self direct makeIterator (shape b) — the existing bridge. Choose per family.

For each **traversal-only** variant (no span — tree/hash/graph, gap (b)):

- D1 is inapplicable (`@_lifetime(copy self)` is invalid on the Escapable node/bucket iterator).
- Take a **plain Escapable `makeIterator`** on an ordinary `Sequence`-style protocol (no lifetime
  regime) and/or a route-3 **`forEach`** that walks nodes/buckets. Both can be family defaults.

### 4.2 Answers to the handoff's open questions

- **"Compose with variant generics + `@_implements` split, or fall back to per-variant?"** —
  conformance **declarations** are per-variant (lift refuted); the makeIterator and forEach
  **bodies** are single family defaults (D1 + C).
- **"Does one borrowing `forEach` unify and subsume Step-1?"** — **Yes for internal iteration.**
- **"Where does each default live?"** — makeIterator and forEach: **family-protocol defaults**
  delegating to a copy-self `~Escapable` view backing (D1 + C). Conformance declarations:
  per-variant. Substrate-direct makeIterator (b) is the no-view-indirection alternative.

## 5. Caveats & scope

- **Cross-module validated for D1/C/route-2 (v1.2.0, `[EXP-017]`).** Gap (c) exercises the D1
  copy-self makeIterator, route-3 `forEach` (C), and route-2 consuming drain across a real
  library→executable module boundary in debug **and** release — the single-module caveat is
  **lifted** for those three. Refutations (A, B, D2, D3, boundary, non-contiguous-D1) are
  module-independent (compile errors). Piecewise (a) and the non-contiguous surviving routes (b)
  are validated single-module debug+release; their mechanics are the same plain/forEach shapes
  proven cross-module in (c).
- **Decision required from the principal:** adopting D1 means the institute's **backing-view**
  iteration protocol must use **`@_lifetime(copy self)`** makeIterator (distinct from the current
  borrow-self `Iterable`/`Sequence.Borrowing.Protocol`, which stays for substrate-direct). This is
  a new protocol shape, not a change to the existing one — confirm before fan-out.
- **Route 2's real-world REFUTED-at-runtime** verdict is **inherited** from
  [memory-contiguous-iteration-bridge.md](memory-contiguous-iteration-bridge.md) OQ-2, not from
  this toy (which does not reproduce the demangle crash minimally; `[EXP-021]`).
- The toy is faithful in **shape** and **build settings** (full ecosystem flags, warning-clean),
  but minimal. It is an **expressibility** probe, not a performance or ABI probe.

## 6. Gating verdicts for the ~18-package decision (v1.2.0)

The architecture choice this note feeds — adopt the **ambitious D1 family-protocol lean** across
~18 data-structure packages, or fall back to **per-variant shape-b** (`@_lifetime(borrow self)`
directly over `self.span`) — could not be made on v1.1.0 evidence, because D1 was proven only for
the **contiguous** case and the ~18 packages are not all contiguous. v1.2.0 adds the three missing
verdicts. **They are evidence for the decision, not the decision** (which is the principal's /
supervisor's).

| Gap | Structure class | D1 family default? | Surviving route(s) | Toolchain / mode |
|-----|-----------------|--------------------|--------------------|------------------|
| **(a) Piecewise** | ring / deque (two segments, no single span) | **CONFIRMED** — same D1 default, with `@_lifetime(copy a, copy b)` per segment | D1 (and forEach/route-2 as for contiguous) | Swift 6.3.2, debug + release |
| **(b) Non-contiguous** | tree (boxed nodes), hash (array-of-buckets); no span | **REFUTED for the easy-Escapable walker** — `invalid lifetime dependence on an Escapable result`. **⚠ SUPERSEDED by §7 (v1.3.0):** with a `~Escapable` self-tied walker, flat trees + hashes ride D1, boxed trees ride it modulo a release compiler bug, and `forEach` (C) unifies all of them. | (superseded — see §7) | Swift 6.3.2, debug + release |
| **(c) Cross-module** | contiguous D1 + C + route-2 across a module boundary | **CONFIRMED** — downstream conformers inherit upstream lib defaults | D1, forEach (C), route-2 — all survive | Swift 6.3.2, debug + release, lib→exe |

### 6.1 What this means for the decision (not a decision)

- **A single D1 family default does NOT cover all ~18 packages.** It covers **contiguous +
  piecewise** (array/buffer/ring/deque-shaped) variants — those with a span (or a fixed set of
  spans) to project. It does **not** cover **tree/hash/graph** variants, which have no span: those
  need a structurally **different** iteration shape (a plain Escapable `makeIterator`, and/or
  route-3 `forEach`). So the lean is not "one default everywhere"; it is "one D1 default for the
  span-projecting family, a second plain/`forEach` shape for the traversal-only family."
- **Piecewise is a free extension of D1**, not a new shape — the only delta is enumerating each
  segment's lifetime in the `@_lifetime(copy …)` list. This *strengthens* the D1 lean for the
  span-projecting family (it scales past simple contiguity at zero protocol cost).
- **Cross-module + release hold** for D1/C/route-2 — the production fan-out shape is validated, so
  the "deferred to real-package fan-out" risk in v1.1.0 §5 is discharged for these mechanics.
- **The crux for the decision** is therefore *not* "does D1 work" (it does, including piecewise,
  cross-module, release) but *how many of the ~18 packages are span-projecting vs traversal-only*.
  The span-projecting subset can take the D1 family default (or shape-b, per-family choice); the
  traversal-only subset is **outside D1 either way** and takes plain `makeIterator` / `forEach`.
  Per Ground Rule 6, this "non-contiguous needs a second shape" finding is itself gating evidence.

> **⚠ §6.1 is superseded by §7 (v1.3.0).** The conclusion "a single D1 family default does NOT cover
> trees/hashes/graphs" rested on the **easy Escapable walker** (a plain `struct` owning a node stack).
> With a **`~Escapable`, self-lifetime-tied walker**, flat/heap trees and hashes ARE span-projecting and
> ride the same D1 default; boxed trees ride it too (modulo a release compiler bug, routable-around); and
> a single `forEach` default unifies everything including `~Copyable`. Read §7 before acting on §6.1.

## 7. Traversal-only re-attack — a UNIFIED family delegation IS achievable (v1.3.0)

§6.1 (v1.2.0) concluded trees/hashes fall **outside** the D1 family. That conclusion was an artifact
of the **easy Escapable walker**: `Phase6NonContiguous.swift`'s `TreeInOrderIterator` /
`HashChainIterator` are plain `struct`s owning `[TreeNode]` / `[[Int]]` storage — i.e. **Escapable** —
so `@_lifetime(copy self)` was rejected as "invalid on an Escapable result." That refutes **one
formulation**, not the design space. v1.3.0 re-attacks per the supervisor's lead hypothesis: re-do the
walker as a **`~Escapable`, self-lifetime-tied** type (like `Iterator.Ring` in gap (a)). Three angles,
attacked A→B→C, first clean signal each (`[EXP-011a]`); evidence in `Phase8TraversalEscapable.swift`,
`Phase9HashAndNonCopyable.swift`, `Phase10AngleB.swift`, `Phase11AngleC.swift`.

### 7.1 Angle A — `~Escapable` self-tied walker via the D1 family default

| Sub-angle | Structure | Verdict | Note |
|-----------|-----------|---------|------|
| **A1** | flat/heap **tree** (nodes in `[Node]`, children by index) | **CONFIRMED** (debug+release) | A `~Escapable` walker borrows the node array as `Span<Node>` (`@_lifetime(copy nodes)`) + an internal index-stack; rides the **same** `FamD.makeIteratorD1`. It is span-projecting after all (one span = the node array). |
| **A2** | genuinely **boxed** tree (`TreeNode` refs, no span) | **PARTIAL** — debug OK; **release compiler crash** | `~Escapable` walker, `@_lifetime(immortal)` (no borrowed region). Compiles + runs **debug**; `swift build -c release` crashes the SIL inliner (`forwardToInit` / "Cannot initialize a nonCopyable type with a guaranteed value") specializing `makeIteratorD1<ToyBoxedTree>`. **Not a language wall:** **A2-direct** (bypass the generic default, call `view.makeIterator()`) and **A2b** (walker holds a *real* `Span`) are both release-clean. The `~Escapable` is a genuine lifetime tie (a no-source return errors). |
| **A3** | **hash** (separate chaining) | **CONFIRMED** (debug+release) | Flatten chains into one `[Int]` pool; `~Escapable` walker over `Span<Int>`; rides `makeIteratorD1` (real span = A1 happy case). The "no span" framing was about the `[[Int]]` representation, not the structure. |
| **A4** | **`~Copyable` elements** via the D1/external-iterator route | **REFUTED for D1** (crashes SILGen) | `next() -> Element?` returns by value → moving a `~Copyable` out of a borrowed span. `return span[i]` crashes the compiler at SILGen (same bug family as A2; reduction confirms the move-out is the trigger). The external-iterator route is **inherently Copyable-only**; `~Copyable` iterates via route-3 `forEach` (C). |

### 7.2 Angle B — one protocol, two conditional defaults gated by `Backing.Iterator` escapability

**CONFIRMED** (debug+release). One `FamB.Protocol` carries two same-named `makeIteratorB()` defaults —
`@_lifetime(borrow self)` gated `where Backing: IterableByCopy` (the `~Escapable`-iterator family), and
plain-no-`@_lifetime` gated `where Backing: PlainIterable` (the Escapable-iterator family). The compiler
**accepts both and dispatches per-conformer** by the backing constraint (`[10,20,30]` copy-self /
`[7,8,9]` plain). This is a genuine **protocol-level** unification (one protocol, two families), distinct
from Angle A's "one default for everything." The only release hazard is the orthogonal A2 bug (an
`immortal`-boxed plain conformer crashed release; a genuinely Escapable owning walker is clean).

### 7.3 Angle C — one `forEach` family default unifies everything (the most complete)

**CONFIRMED** (debug+release). One `FamC.forEach` (backing-delegation) default serves a span array
(`sum=60`), a boxed tree (`[1..7]`), and `~Copyable` `Resource` elements (`sum=600`) — span-projecting +
traversal-only + `~Copyable`, all via **one body**. `forEach` returns `Void` and **lends** each element
via a `(borrowing Element) -> Void` closure: no lifetime-dependent return (no copy-self view, no A4
move-out wall) and `~Copyable` carried natively. **Cost (decision-relevant):** internal iteration only —
no pull-style `next()`, lazy, `zip`, `peek`, or cheap early-exit. A boxed backing still needs the A2b
real-span workaround to dodge the A2 compiler bug.

### 7.4 The A2 compiler bug (one bug, three angles)

The release `forwardToInit` / "nonCopyable from guaranteed value" abort fires whenever an
`@_lifetime(immortal)` `~Escapable` **backing/walker** is specialized through **any** generic family
default (`makeIteratorD1` / `makeIteratorB` / `forEach`) — **independent of the default's return type**
(`forEach` returns `Void` and still crashes). It is a SIL-optimizer/SILGen bug, not a language wall.
**Workaround:** give the backing a **real borrowed region** (A2b) — flat trees (A1) and hashes (A3) are
already in this case; only the *pure-pointer boxed* walker needs it. (Candidate for an `issue-investigation`
reduction + upstream report; out of scope for this probe.)

### 7.5 What this means for the decision (not a decision)

- **A single unified family delegation across span-projecting + traversal-only IS achievable.** The
  cleanest universal vehicle is **Angle C's one `forEach` default** (all element kinds, all structures,
  debug+release). For **pull-style external iteration**, **Angle A's D1 default** covers span-projecting
  Copyable structures *including flat/heap trees and hashes* (debug+release), and **Angle B** lets one
  protocol also serve the plain-Escapable-iterator family. So the v1.2.0 "trees/hashes need a *separate*
  family outside D1" framing is **overturned**: most are span-projecting (flat trees, hashes ride D1) and
  *all* are covered by the one `forEach` default.
- **The residual gaps are two, and both are narrow:** (1) a *pure-pointer* boxed structure routed through
  a generic family default hits the **A2 compiler bug** in release — routable-around (direct call, or a
  real borrowed region) until upstream-fixed; (2) `~Copyable` elements cannot use the *external-iterator*
  route at all (a language property of by-value `next()`), so they use `forEach` — which is exactly the
  unified vehicle anyway.
- **Recommended unified shape (evidence, not decision):** `forEach` (C) as the **primary** universal
  family default (covers every structure + every element kind), **plus** an external `makeIterator`
  (D1/A copy-self for span-projecting Copyable; plain for Escapable) as a **secondary** witness where
  pull-style/Copyable consumption is wanted. This is the v1.1.0 §4 "lifetime-shape split" + "forEach
  unifies the copyability split," now confirmed end-to-end across traversal-only + `~Copyable`.

## 8. Cross-references

- Experiment: `swift-institute/Experiments/iteration-architecture-toy` (this note's evidence;
  v1.2.0 gaps in `Phase5Piecewise.swift`, `Phase6NonContiguous.swift`, `Phase7CrossModule.swift`;
  v1.3.0 re-attack in `Phase8TraversalEscapable.swift` (A1/A2/A2-direct/A2b),
  `Phase9HashAndNonCopyable.swift` (A3/A4), `Phase10AngleB.swift` (B), `Phase11AngleC.swift` (C);
  + the `iteration-architecture-toy-lib` second target).
- [memory-contiguous-iteration-bridge.md](memory-contiguous-iteration-bridge.md) — the substrate
  bridges, OQ-1, OQ-2 (generic demangle). Shape b here = that doc's memory→Iterable bridge.
- `HANDOFF-iteration-architecture-probe.md` — the arc; the three routes; the family-protocol lean.
- The **A2 compiler bug** (§7.4, `forwardToInit` / "nonCopyable from guaranteed value" on an
  `@_lifetime(immortal)` `~Escapable` value specialized through a generic family default) is a
  candidate for an `issue-investigation` reduction + upstream report — out of scope for this probe.
- `[EXP-011a]`, `[EXP-017]`, `[EXP-021]`, `feedback_extension_implies_copyable`.
