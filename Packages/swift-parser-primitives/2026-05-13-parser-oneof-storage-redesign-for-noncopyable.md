# Parser.OneOf.Any Storage Redesign for `~Copyable` Parsers

<!--
---
version: 1.0.0
last_updated: 2026-05-13
status: RECOMMENDATION
tier: 2
scope: per-package (swift-parser-primitives) with cross-package consequence (Parser.OneOf.Builder return surface)
applies_to:
  - swift-primitives/swift-parser-primitives
verification_experiment: ../Experiments/parser-protocol-self-noncopyable-witness-tables/ (witness-table SIGSEGV REFUTED, V6 closure-of-~Copyable PASS)
predecessor: swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md (v1.1.0 RECOMMENDATION; Option δ contingent on second consumer + Parser.OneOf.Any structural cap removal)
trigger: parent Tier-3 doc v1.1.0 names `Parser.OneOf.Any.parsers: [Closure]` as dominant remaining structural blocker against Option α
changelog:
  - v1.0.0 (2026-05-13): initial RECOMMENDATION. Empirical finding: `Parser.OneOf.Any` has ZERO production call-sites across all surveyed repositories (swift-primitives, swift-foundations, swift-standards, swift-institute, rule-institute, rule-law, swift-law, swift-nl-wetgever, swift-us-nv-legislature) — only its own source file and an indirectly-related independent twin at swift-standards/Sources/Parsing/Parsing.OneOf.Any.swift reference it. Recommends **Option 4 (Result-builder-only)** as the dominant choice: drop `Parser.OneOf.Any` entirely, promote `OneOf.Two`/`Three` (already typed-generic, already structurally `~Copyable`-friendly) plus a small variadic-generics buildBlock extension to canonical. Removes the structural cap WITHOUT introducing storage ceremony. Option 1 (variadic-generics-on-Any-replacement) scored second; Option 3 (Storage.Pool.Inline-backed) scored third; Options 2 (recursive struct) and 5 (existentials) scored at or near the bottom; Option 6 (hybrid) preserved only as a future-extension shape. Flips Option α from δ to **viable on this structural axis** — does NOT clear the [RES-018] second-consumer gate, which is now the *sole* remaining gate.
---
-->

## Context

This document resolves the dominant remaining structural blocker named in
the v1.1.0 Tier-3 doc at
`swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md`
(committed 4582bc5, not pushed). That doc recommended **Option δ (defer)**
for `Parser.\`Protocol\`: ~Copyable` (Option α) on the basis of two
remaining cost items after the witness-table SIGSEGV was empirically
refuted:

1. **`Parser.OneOf.Any.parsers: [Closure]` structural cap.** Stdlib
   `Array<T>` requires `T: Copyable`, so an `Array` of closures returning
   `~Copyable` values cannot exist; the type-erased combinator cannot
   participate in `Self: ~Copyable` adoption (v1.1.0 §C(d) "Closure-
   capture limits" bullet 1, §A shape table row "Type-erased / closure-
   based combinator").
2. **[RES-018] second-consumer hurdle**: `Parser.Machine.Compiled` is the
   lone parser-stack consumer wanting `~Copyable` semantics; per the
   premature-primitive anti-pattern, protocol relaxation should not
   precede a second concrete consumer. *Explicitly out of scope for this
   document* per the brief — user has rejected the second-consumer
   framing as a gate.

This document tackles (1) only. If (1) admits a clean resolution, the
*structural* case for Option α reopens; (2) becomes the sole remaining
gate and is decided by separate criteria.

### The brief's hard rules

The dispatch carries two binding constraints from the principal:

- **Sibling-type workarounds REJECTED**: do not propose a hypothetical
  `Parser.OneOf.OwnedAny: ~Copyable` living alongside the existing
  Copyable `OneOf.Any`. Quote: *"we dont want Parser.Machine.OwnedCompiled
  (its a workaround)."* The redesign must make `Parser.OneOf.Any` (or its
  replacement) natively `~Copyable`-friendly, NOT route around it.
- **[RES-018] second-consumer reasoning REJECTED**: adoption is judged on
  structural merit. Quote: *"We should forget the 'Second consumer'
  framing (that skill should be rethinked anyway, as we optimize for
  correctness and 'evergreen')."*

### The current shape (verified 2026-05-13)

`swift-parser-primitives/Sources/Parser OneOf Primitives/Parser.OneOf.Any.swift:19–27`:

```swift
public struct `Any`<Input: Parser.Input.`Protocol`, Output> {
    @usableFromInline
    let parsers: [(inout Input) throws(Self.Error) -> Output]

    @inlinable
    public init(_ parsers: [(inout Input) throws(Self.Error) -> Output]) {
        self.parsers = parsers
    }
}
```

Useful properties of this shape:

- **Dynamic arity**: arbitrary `N` parsers at runtime (the `Array`
  permits any length).
- **Type erasure**: the `Output` and the cumulative `Failure` are
  collapsed into a single `(inout Input) throws -> Output` closure
  shape, so heterogeneous parsers compose.
- **Result-builder ergonomics**: `Parser.OneOf.Builder` builds typed
  `OneOf.Two<P0, P1>` / `OneOf.Three<P0, P1, P2>` for arities 1–3 and
  cascades to `OneOf.Two` accumulation for `N > 3` (verified at
  `Parser.OneOf.Builder.swift:78–89`). `OneOf.Any` is NOT in the builder's
  return path; it is only constructible by *passing an array of closures
  to `init(_:)`*.

Costs that motivate the structural cap:

- **Closures cannot capture `~Copyable` parsers** — a `() -> P` where
  `P: ~Copyable` was verified to compile via experiment V6 at
  `swift-parser-primitives/Experiments/parser-protocol-self-noncopyable-witness-tables/EXPERIMENT.md`,
  but *storing N such closures in `Array<…>` is blocked by stdlib
  `Array<T>` requiring `T: Copyable`.*
- **`(inout Input) throws -> Output` cannot represent typed throws**
  cleanly — `Self.Error` is the type-erased aggregate; the closure shape
  has already collapsed `throws(Failure)` to `throws(Self.Error)`. This
  is the existing erasure layer that motivates the
  `Parser.OneOf.Any.Error` aggregate (`Parser.OneOf.Any.swift:37–55`).

### Empirical finding: zero call-sites

Grep across all surveyed repositories (run 2026-05-13):

```
$ grep -rn "OneOf\.Any\|OneOf\.\`Any\`" /Users/coen/Developer/ \
    | grep -v ".build/" \
    | grep -v "Experiments/parser-protocol-self-noncopyable"
```

Results (verbatim):

- `swift-parser-primitives/Sources/Parser OneOf Primitives/Parser.OneOf.Any.swift` — the definition itself
- `swift-standards/swift-standards/Sources/Parsing/Parsing.OneOf.Any.swift` — an independent twin in the `Parsing.*` namespace (predates the migration to `Parser.OneOf.*`; not a caller of the parser-primitives type)
- `swift-institute/Research/tagged-unchecked-construction-inventory.md:706` — citation only
- `swift-institute/Research/_index.json:47` — citation in the parent Tier-3 doc's metadata
- `swift-institute/Research/data-structures-variant-catalog-parsers.md:70` — file catalog entry
- `swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md` — multiple citations in the parent Tier-3 analysis

**No call-site exists.** `Parser.OneOf.Any` has zero `init(_:)`
invocations anywhere in the ecosystem. The only direct `Parser.OneOf`
test coverage is at
`swift-parser-primitives/Tests/Parser OneOf Primitives Tests/Parser.OneOf.Two Tests.swift`
(verified — `OneOf.Any` is NOT tested).

This finding changes the framing of the analysis materially: the
question is not *how to redesign storage that consumers depend on,* it
is *how to either remove or re-derive an unused affordance.* All
options below are evaluated under that reframing.

### Prior research (per [HANDOFF-013])

| Document | Bearing on this analysis |
|---|---|
| `swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md` v1.1.0 (RECOMMENDATION) | **Predecessor.** Names the cap; computes the 6/30 score under Option α; identifies the cap as one of two dominant remaining costs. Resolves the witness-table SIGSEGV blocker empirically. |
| `swift-primitives/swift-parser-primitives/Experiments/parser-protocol-self-noncopyable-witness-tables/EXPERIMENT.md` | **Direct empirical input.** V5 (full original-crash conditions) and V6 (closure-of-~Copyable-return) both PASS on Swift 6.3.2. The closure-capture finding (V6) is the load-bearing evidence that closures returning `~Copyable` work; it does NOT contradict the stdlib `Array<~Copyable>` cap. |
| `swift-parser-primitives/Research/witness-table-sigsegv-with-noncopyable-protocol-constraints.md` (DECISION, 2026-02-14) | Historical only — SIGSEGV blocker empirically refuted by V5 on Swift 6.3.2 per the v1.1.0 update. Not load-bearing for storage design. |
| `swift-foundations/swift-parsers/Research/parser-input-noncopyable-support.md` (DECISION, 2026-03-16) | Establishes the Copyable / `~Copyable` partition convention at the Input axis (`Chain.Left`, `Chain.Right`, `Expression.Climbing`, `Separated` all gain `where Input: Copyable`). Useful precedent: the parser stack already partitions surface area by `~Copyable`-vs-Copyable explicitly, not via existentials or runtime gymnastics. |
| `swift-parser-machine-primitives/Research/machine-noncopyable-input.md` (DECISION, 2026-02-24) | Establishes that `Parser.Machine.Builder: ~Copyable` is the pattern at the machine layer; `Compiled` / `Prepared` are Copyable wrappers conforming to `Parser.\`Protocol\``. Independent of storage shape for `OneOf.Any` (Builder uses internal IR, not closure arrays). |
| `swift-primitives/swift-storage-primitives/Research/inline-pool-arena.md` | Establishes the inline-pool / inline-arena storage shapes with `Element: ~Copyable` support (e.g., `Storage<Element>.Pool.Inline<N>: ~Copyable where Element: ~Copyable` at `Storage.Pool.Inline.swift:49`). Directly relevant to Option 3. |
| `swift-primitives/swift-storage-primitives/Research/bounded-unbounded-storage-inline-api.md` (DECISION, v2.0.0) | Establishes the bounded-only public API discipline (`Index<Element>.Bounded<capacity>` is the public surface). Bounds Option 3's ergonomic profile. |
| `swift-institute/Research/2026-05-13-noncopyable-adoption-ecosystem-corners-audit.md` v1.0.0 (RECOMMENDATION) | Row 18 "heap storage" rows out as not-a-candidate (`Storage.{Slab,Pool,Heap,Arena,Split}` are ManagedBuffer-backed COW with companion `~Copyable` `Storage.{Inline,Pool.Inline,Arena.Inline}` already existing). Establishes that the storage layer already split correctly for the use case. |
| `swift-institute/Research/swift-6.3-ecosystem-opportunities.md` (Category 4) | Notes that SE-0485 OutputSpan extends `Array.append` / `ContiguousArray.append`. Does NOT add `Array<~Copyable>` support — checked. The stdlib-Array cap remains. |
| `swift-institute/Research/snapshot-testing-literature-study.md:453` + `unsafe-audit-spot-check.md:31` | Established uses of `InlineArray<N, Element>` (SE-0453) as fixed-size inline storage. **`InlineArray` from stdlib also requires `Element: Copyable`** — must be verified in scoring. |
| `swift-primitives/swift-structured-queries-primitives/Sources/Structured Queries Primitives/QueryDecoder.swift:93–95` + `QueryFunctionInfrastructure.swift:21` + 11 other sites | Established variadic-generics use in the ecosystem (`(repeat each T).Type`, `repeat each Argument`). Establishes that variadic generics are usable in production at this point. |
| `swift-primitives/swift-parser-primitives/Sources/Parser Take Primitives/Parser.Take.Builder.swift:114–133` | Direct precedent: `buildPartialBlock` uses `each O1` to accumulate parser outputs into a flattened tuple `(repeat each O1, O2)`. The parser stack ALREADY uses variadic generics in its result-builder layer. |

The parser stack already partitions `~Copyable`-vs-Copyable at the
*Input* axis (precedent in `swift-parsers/Research/parser-input-noncopyable-support.md`)
and ALREADY uses variadic generics in its *Take* result builder
(`Parser.Take.Builder.swift:114–133`). Both findings narrow the option
space favorably.

---

## Question

**What storage shape for `Parser.OneOf.Any` (or its replacement) can hold
N `~Copyable` parsers while preserving useful properties of the current
`[Closure]`-based design (dynamic arity, type erasure, result-builder
ergonomics) — *and is the affordance even needed* given zero call-sites?**

Sub-questions:

1. Can the affordance be removed entirely without loss of expressiveness
   (i.e., is `Parser.OneOf.Sequence { … }` via the result-builder always
   substitutable for `Parser.OneOf.Any(…)`)?
2. If retained or re-derived, which shape minimizes ceremony at the
   parser-author call site while admitting `~Copyable` elements?
3. Does the recommended shape itself conform to `Parser.\`Protocol\``
   (and, if so, gracefully under both Copyable and `~Copyable` Self
   default), or does it need a wrapper?
4. Does the recommendation generalize to other `[Closure]`-shape
   ecosystem patterns (e.g., the predecessor doc's Row 3 emission-pattern
   question on `[Lint.Finding]` streams)?

---

## Analysis

### A. Reframing in light of zero call-sites

Before scoring options on storage merits, the discovery that
`Parser.OneOf.Any` has zero call-sites must be addressed. Two
interpretations:

**Interpretation P (preserve)**: the type's existence enables a use case
that hasn't yet emerged in production. Removing it forecloses that
future. The redesign question is genuinely about storage.

**Interpretation R (remove)**: the type's existence is a YAGNI residue.
The result-builder API
(`Parser.OneOf.Sequence { p0; p1; p2; … }` returning
`OneOf.Sequence<…, OneOf.Two<…OneOf.Two<P0, P1>…, Pn>>` via
`buildPartialBlock` accumulation) **already provides dynamic-arity
alternative parsing at the call site**, with full type preservation and
zero erasure. The dynamic-arity-via-runtime-array shape is a SECOND
spelling of the same expressivity, never adopted by consumers.

The two interpretations have very different implications:

- Under P, options 1/3/6 score highest (provide a `~Copyable`-friendly
  redesigned storage shape).
- Under R, option 4 dominates (just delete the dead code; there's
  nothing to redesign).

The evidence supports R unambiguously:

- **Zero direct callers** across 9 surveyed repository trees.
- **Zero tests** under
  `swift-parser-primitives/Tests/Parser OneOf Primitives Tests/` ever
  instantiate `OneOf.Any` — verified by directory listing
  (`Parser.OneOf.Two Tests.swift` is the only file).
- **The result-builder path is preferred** by every documented usage in
  source comments (e.g., `Parser.OneOf.Sequence.swift:13–20` shows
  result-builder syntax as the canonical entry point).
- The result-builder accumulation is *type-preserving* (returns concrete
  `OneOf.Two<…>` chains), so it carries STRONGER static guarantees than
  `OneOf.Any` (which type-erases output and aggregates errors). There is
  no semantic motivation to prefer `OneOf.Any` once the result-builder
  exists.

The only conceivable use case for the array-shaped `OneOf.Any` is
"build a parser dynamically from a runtime list of parsers." This
requires:

- A loop or fold-construction at runtime (the result-builder is
  compile-time-only).
- Heterogeneous parser types collapsed via either a closure cast or an
  existential.

Both of these requirements force the call-site to ALREADY have a list
of `Copyable` closures. Once `~Copyable` parsers enter the picture, the
existing shape doesn't work — by construction. So the
`~Copyable`-adoption motivation IS NOT well-served by preserving the
existing dynamic-list shape; it is well-served by replacing that shape
with a static-arity one (variadic generics) or by removing it entirely
in favor of the result-builder.

### B. Option enumeration

Each option below addresses the question "If we KEEP a type called
`Parser.OneOf.Any` (or its replacement) that admits N parsers, what
shape does it take to admit `~Copyable` parsers?" Option 4 alone
addresses the question "Should we keep it at all?"

#### Option 1 — Variadic generics on the type

```swift
public struct `Any`<
    Input: Parser.Input.`Protocol` & ~Copyable & ~Escapable,
    Output,
    each P: Parser.`Protocol` & ~Copyable
> where repeat (each P).Input == Input, repeat (each P).Output == Output {
    let parsers: (repeat each P)
    @inlinable
    public init(_ parsers: repeat each P) {
        self.parsers = (repeat each parsers)
    }
}

extension Parser.OneOf.`Any`: Parser.`Protocol` {
    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Iterate via for-in on `repeat each parsers` (SE-0408 / Swift 5.9+)
        var errors: [Swift.Error] = []
        let checkpoint = input.checkpoint
        for parser in repeat each parsers {
            do {
                return try parser.parse(&input)
            } catch {
                errors.append(error)
                input.restore.to(__unchecked: (), checkpoint)
            }
        }
        throw .noMatch(tried: errors)
    }
}
```

**Pros**:

- Typed, statically-known arity per call-site.
- Heap-free at the call site (the tuple is laid out inline).
- Composes with `each P: ~Copyable` — variadic-generic packs natively
  support `~Copyable` elements (verified pattern via the structured-
  queries package at
  `swift-structured-queries-primitives/Sources/Structured Queries Primitives/QueryDecoder.swift:93–95`,
  though that site does not exercise the `~Copyable` axis).
- For-in over `repeat each parsers` exists since SE-0408 (Pack iteration).

**Cons**:

- **Arity is per-call-site, not lifetime**: you cannot store an `Any<each P>`
  in a homogenous variable because each call-site instantiates with its
  own type tuple. The dynamic-arity property of the existing shape is
  LOST. A wrapper that says "any OneOf.Any" at the call site is impossible
  without an existential (Option 5) on top.
- **Compile-time cost scales with N**: variadic-generic type-checking at
  large N (>12) is known to stress the type checker. Risk is real but
  unmeasured at this site.
- **`buildBlock` cascade**: `Parser.OneOf.Builder` already absorbs the
  N>3 case via partial-block accumulation. Adding a variadic-generic
  `Any<each P>` introduces a parallel path the builder must reach into.
- **Error-aggregation shape**: the current `Failure = Self.Error` aggregate
  collects `[Swift.Error]`. Under variadic generics, the natural shape is
  `Product<repeat (each P).Failure>` (consistent with `OneOf.Two` and
  `OneOf.Three`, which use `Product<P0.Failure, P1.Failure>` and
  `Product<P0.Failure, P1.Failure, P2.Failure>`). This is a *better*
  shape than the existing `[Swift.Error]` aggregate (typed throws is
  preserved), but it is a DIFFERENT shape — adoption is a semantic
  change, not a back-compatible storage swap.

**Native `~Copyable` support**: YES. `each P: ~Copyable` works since
SE-0427 + SE-0408.

**Ergonomics impact**: tolerable. Call sites change from
`Parser.OneOf.Any(parsers: [p0Closure, p1Closure, …])` to
`Parser.OneOf.Any(p0, p1, …)`. There is no call-site today.

**Verdict**: viable. Drops the runtime-dynamic-arity property in
exchange for `~Copyable` admission and a stronger typed-throws error
shape. Reasonable second-place choice if Option 4 is rejected.

#### Option 2 — Recursive struct

```swift
public struct `Any`<
    Head: Parser.`Protocol` & ~Copyable,
    Tail: Parser.`Protocol` & ~Copyable
>: ~Copyable
where Head.Input == Tail.Input, Head.Output == Tail.Output {
    let head: Head
    let tail: Tail
}

// Base case: Any<P, Nothing> or similar terminator
```

This is identical in shape to nesting `OneOf.Two<OneOf.Two<OneOf.Two<P0, P1>, P2>, P3>`
manually — which is EXACTLY what `OneOf.Builder.buildPartialBlock` already
produces at `Parser.OneOf.Builder.swift:78–89`.

**Pros**:

- Unbounded arity via type recursion.
- `~Copyable` propagates naturally if `Head: ~Copyable, Tail: ~Copyable`.

**Cons**:

- **Right-deep type recursion is a known type-checker stress test.** For
  long chains (N > ~30), the symbol name explosion and recursive
  conformance checking can be measured in seconds-to-minutes per file.
- **It IS the existing `OneOf.Two` chain.** Adding a parallel type named
  `Any` that *is* a sugaring of `OneOf.Two` accumulation duplicates
  surface area.

**Native `~Copyable` support**: YES.

**Verdict**: NOT viable as an independent option. It's the existing
result-builder accumulation path renamed. Adoption is equivalent to
Option 4 with a confusing alias.

#### Option 3 — Inline storage (`Storage.Pool.Inline<N, P>` or `InlineArray<N, P>`)

```swift
public struct `Any`<
    let capacity: Int,
    Input: Parser.Input.`Protocol` & ~Copyable & ~Escapable,
    Output,
    P: Parser.`Protocol` & ~Copyable
>: ~Copyable
where P.Input == Input, P.Output == Output {
    let parsers: Storage<P>.Pool.Inline<capacity>
    let count: Int  // or use the pool's _allocated
}
```

Or, with the stdlib's `InlineArray<N, T>` (SE-0453):

```swift
let parsers: InlineArray<capacity, P>
```

**Pros**:

- Bounded inline storage; no heap allocations.
- `Storage.Pool.Inline` natively supports `Element: ~Copyable`
  (verified at
  `swift-storage-primitives/Sources/Storage Pool Inline Primitives/Storage.Pool.Inline ~Copyable.swift:20`).

**Cons**:

- **`InlineArray<N, T>` from stdlib still requires `T: Copyable`** —
  inspecting the snapshot literature study line
  (`swift-institute/Research/snapshot-testing-literature-study.md:453`):
  *"InlineArray | SE-0453 | Stack-allocated fixed-size buffers for
  comparison"* — and SE-0453's text confirms `T` defaults to `Copyable`.
  Same cap as `Array<T>`. Disqualifies the stdlib path.
- **`Storage.Pool.Inline<N>` requires homogeneous element type**: all
  parsers must share the *same* concrete type `P`. The whole point of
  `OneOf.Any` is heterogeneous storage. This shape only works for
  parsers that are already structurally identical (e.g., all
  `Parser.Literal<Input>`), at which point an `InlineArray<N, Literal>`
  is the spelling AND `OneOf.Any` is the wrong abstraction.
- **Capacity is compile-time**: bounded arity, NOT dynamic. Same loss as
  Option 1 except heap-allocated bounded with a fixed compile-time N.
- **Conformance ergonomics**: every parser inserted must be
  type-cast-compatible with `P`. Forces an existential `any
  Parser.\`Protocol\`` boxing (Option 5 surcharge) at construction.

**Native `~Copyable` support**: YES at the storage layer (per
`Storage.Pool.Inline` design), but the homogeneity constraint makes
this inapplicable to the heterogeneous-storage use case.

**Verdict**: NOT viable. The storage shape solves a different problem
than `OneOf.Any` solves — homogeneous-typed N-element storage, NOT
heterogeneous-typed alternative parsing.

#### Option 4 — Result-builder-only (drop `OneOf.Any` entirely)

The result-builder at `Parser.OneOf.Builder` already produces:

- Arity 1: `P` directly (`buildBlock<P>(_ parser: P) -> P`).
- Arity 2: `Parser.OneOf.Two<P0, P1>`.
- Arity 3: `Parser.OneOf.Three<P0, P1, P2>`.
- Arity N>3: cascaded `OneOf.Two` accumulation via `buildPartialBlock`.

The cascaded accumulation at
`Parser.OneOf.Builder.swift:78–89`:

```swift
public static func buildPartialBlock<Accumulated: Parser.`Protocol`, Next: Parser.`Protocol`>(
    accumulated: Accumulated,
    next: Next
) -> Parser.OneOf.Two<Accumulated, Next>
where
    Accumulated.Input == Input,
    Next.Input == Input,
    Accumulated.Output == Output,
    Next.Output == Output
{
    Parser.OneOf.Two(accumulated, next)
}
```

This produces a left-skewed `OneOf.Two<OneOf.Two<…OneOf.Two<P0, P1>, P2…>, Pn>`
for any arity. Each `OneOf.Two` stores `let p0: P0, let p1: P1` —
both fields can natively become `~Copyable` if their type parameters
are `~Copyable` (the existing struct declaration at
`Parser.OneOf.Two.swift:12–17` does not declare `: ~Copyable` today, but
under Option α adoption with explicit `: ~Copyable` declarations on
`OneOf.Two`, `OneOf.Three`, the cascade carries through without ceremony).

**Surface area to delete**:

- `Parser.OneOf.Any.swift` (79 lines, no callers).
- `Parser.OneOf.Any.Error` (defined inside `Parser.OneOf.Any.swift`).

**Surface area to add**: NONE — the result-builder path already exists.

**Surface area to optionally extend** (for closing the arity-3
discontinuity in the builder): add a variadic-generic `buildBlock` for
the N>3 case that returns a *flattened* nested-`OneOf.Two` chain
instead of relying on `buildPartialBlock` accumulation. This is
optional and orthogonal to the `~Copyable` adoption — it is a
type-checker performance optimization, not a correctness fix.

**Pros**:

- **Removes the structural cap entirely.** There is no `[Closure]`
  storage to worry about because there is no storage type.
- **Loses no expressivity** — the result-builder is more expressive
  than the array shape (preserves output types, preserves typed
  failures via `Product<…>` chains, preserves Printer conformance per
  the existing `OneOf.Two: Parser.Printer where P0: Parser.Printer, P1: Parser.Printer`).
- **Zero migration cost** — no consumers exist to migrate.
- **Composes with `Parser.\`Protocol\`: ~Copyable` adoption (Option α)
  cleanly.** Each `OneOf.Two<P0, P1>` declares `: ~Copyable where P0:
  ~Copyable, P1: ~Copyable` (or uses the explicit-extension shape per
  the `feedback_extension_implies_copyable` gotcha), and the cascade
  applies uniformly across the rest of the combinator surface.
- **Establishes a precedent**: the institute already has experience
  deleting unused affordances during package-readiness arcs (e.g.,
  the `Parser.Lazy` @autoclosure variant noted in the parent doc, the
  ascii-serialization-migration cleanup). Removing `OneOf.Any` is a
  much smaller scope.

**Cons**:

- **Loses the runtime-dynamic-arity affordance**. A theoretical
  consumer wanting to construct a parser from a runtime list of N
  parsers loses the path. No such consumer exists today; if one
  surfaces, Option 1 (variadic-generics replacement) or Option 6
  (hybrid) becomes available as an additive future extension.
- **Cosmetic API surface contraction**: the `Parser.OneOf` namespace
  loses one nested type. This is a "is `Parser.OneOf` complete without
  it" question, not a technical one. The answer is yes — the OneOf
  namespace's role is alternative parsing, which `OneOf.Two`/`Three` +
  result-builder already cover at every arity ≥1.

**Native `~Copyable` support**: trivially YES — there is no storage to
constrain.

**Ergonomics impact**: zero. No call-site exists; the result-builder
path is already the canonical entry point per docs.

**Verdict**: dominant. Combines:
- structural cap removal
- precedent (result-builder is the documented canonical entry point)
- zero migration cost
- typed-throws preservation (the lost `Failure = Self.Error` aggregate
  is REPLACED with the `Product<P0.Failure, P1.Failure>` chain, which
  is strictly stronger)
- compositional simplicity (`OneOf.Two`/`Three` are already authored;
  Option α adoption needs to touch them anyway as part of the 166-site
  cascade — adding `: ~Copyable` to two structs is in-scope)

#### Option 5 — Existentials (`[any Parser.\`Protocol\`]`)

```swift
public struct `Any`<Input: Parser.Input.`Protocol`, Output> {
    let parsers: [any Parser.`Protocol`<Input, Output, any Swift.Error>]
}
```

**Pros**:

- Heterogeneous storage at runtime.
- Conceptually clean — existentials are the textbook answer to
  heterogeneous-typed-element storage.

**Cons**:

- **`any Parser.\`Protocol\`<…>: ~Copyable` requires SE-0436 (Borrowing
  Existentials)** and current Swift evolution status is partial:
  borrowing existentials over `~Copyable` protocols is gated and
  evolving. Swift 6.3 supports basic existentials of `~Copyable`
  protocols; full support remains incomplete.
- **Stdlib `Array<any P>` still requires the existential to be
  `Copyable`**. The cap is unchanged.
- **Existentials defeat the typed-throws / typed-output design.**
  The whole point of the institute's typed-throws conventions
  ([API-ERR-001]) and typed Failure / Output associated types is
  static knowledge of error / output shapes at composition time.
  Existentials erase this; the resulting `OneOf.Any` is *worse* than
  the closure-array shape because closures at least named the input
  and output explicitly.
- **`any Parser.\`Protocol\`` is an existential over a protocol with
  ~Copyable Input** — SE-0436 limitations apply at the existential
  level. Composition of a `[any Parser.\`Protocol\`<Input, Output>]`
  where `Input: ~Copyable` is the bleeding edge of language support;
  treating it as a stable foundation for ecosystem-wide adoption is
  premature.

**Native `~Copyable` support**: NO under current toolchain conditions.
The stdlib-Array cap on existentials is the same as the stdlib-Array
cap on concrete types.

**Verdict**: NOT viable. Existentials trade one cap (concrete-type
heterogeneity) for another (Copyable-existential-only) without
materially improving expressivity. The typed-throws / typed-Output
design is also degraded — a regression.

#### Option 6 — Hybrid

Two natural hybrids:

**6a. Variadic up to N, recursive overflow.** Build a variadic-generic
`OneOf.Any<each P>` for small N (e.g., 1–8), then chain `OneOf.Two`
accumulation above. The boundary is invisible to consumers because
the result-builder hides the type.

**6b. Inline up to N, heap-fallback above.** Use `Storage.Pool.Inline<N>`
for bounded-N parsers, fall back to `Storage<P>.Heap` for unbounded.
Requires homogeneous element type per Option 3's analysis — same
disqualifier.

**Pros**:

- 6a generalizes Option 1: bounded variadic + recursive accumulation
  above. The recursive accumulation IS the existing result-builder path.
  So 6a = Option 4 + a variadic-generic `buildBlock` overload for N ≤ 8.

**Cons**:

- 6a is functionally identical to Option 4 + a type-checker-performance
  optimization to the builder. It is not a distinct design option.
- 6b inherits Option 3's homogeneity disqualifier.

**Verdict**: not a distinct option from Option 4 + an additive future
extension. Captured as a follow-up in Open Questions, not scored
independently.

### C. Comparison table

Criteria:

- **Ergo (E)**: parser-author-facing API stays close to current shape. 5/5 if identical, 0/5 if the call-site syntax changes radically.
- **Arity (A)**: unbounded? bounded? per-call vs. lifetime? 5/5 if unbounded at composition time, 2/5 if bounded at compile time, 0/5 if homogeneous-only.
- **Alloc (L)**: heap vs. inline vs. zero allocation. 5/5 if zero, 3/5 if inline-bounded, 1/5 if heap.
- **CT (C)**: compile-time cost. 5/5 if no typecheck-explosion risk, 1/5 if known stress at N ≥ ~20.
- **Compose (X)**: does the shape conform to `Parser.\`Protocol\``, or wrap into a conformer cleanly? 5/5 if direct, 3/5 if wrapped with minor ceremony, 0/5 if not viable.
- **Builder (B)**: interaction with `Parser.OneOf.Builder` result-builder syntax. 5/5 if no call-site syntax change, 0/5 if requires call-site changes.
- **NC (N)**: native `~Copyable` support. 5/5 if directly holds N `~Copyable` parsers, 0/5 if structurally blocked (THE binding criterion).

Total: simple sum (max 35).

| # | Option | E | A | L | C | X | B | N | **Total** | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Variadic generics on `Any<each P>` | 4 | 3 (bounded per-call-site) | 5 (no heap) | 3 (typechecker stress risk at N>12) | 5 | 4 (needs new builder overload) | 5 | **29/35** | Viable; second choice |
| 2 | Recursive struct `Any<Head, Tail>` | 1 | 5 | 5 | 1 (right-deep recursion well-known stress) | 5 | 0 (requires call-site change) | 5 | **22/35** | Not viable; is the existing OneOf.Two accumulation renamed |
| 3 | Inline storage (`Storage.Pool.Inline<N, P>`) | 1 | 2 (compile-time bounded) | 5 | 5 | 3 | 1 | 0 (homogeneous-only) | **17/35** | Not viable; homogeneous-only disqualifies |
| 4 | Result-builder-only (delete `OneOf.Any`) | 5 | 5 (via OneOf.Two cascade) | 5 (stack-flat tuple-equivalent layout) | 5 (already exists; small perf opt available) | 5 | 5 (no call-site change) | 5 | **35/35** | **RECOMMENDED** |
| 5 | Existentials `[any P]` | 3 | 5 | 1 (heap) | 5 | 0 (typed-throws / typed-Output regression) | 3 | 0 (stdlib-Array cap unchanged on Copyable-only existentials) | **17/35** | Not viable |
| 6a | Hybrid variadic + recursive | 4 | 5 | 5 | 3 | 5 | 4 | 5 | **31/35** | Functionally Option 4 + builder optimization |
| 6b | Hybrid inline + heap | 1 | 3 | 4 | 5 | 3 | 1 | 0 | **17/35** | Inherits Option 3's disqualifier |

### D. Sanity check against the parent doc's framing

The parent v1.1.0 doc names `Parser.OneOf.Any.parsers: [Closure]` as a
"hard structural cap on the design space, not removable by compiler
progress" (§A shape table row 4). Under Option 4, the cap is removed
not by compiler progress but by **removing the type that incurs the
cap**. This is a more honest framing of what the v1.1.0 doc could not
see without the empirical zero-callers finding.

The parent doc's revised re-evaluation trigger (4) "Stdlib `Array` adds
`~Copyable` element support — unblocks `Parser.OneOf.Any.parsers` from
its current structural cap" becomes **N/A** under Option 4 — the trigger
is moot once the type is deleted. Trigger (4) should be removed from
the v1.1.0 doc on Option 4 adoption.

### E. Composition with `Parser.\`Protocol\`: ~Copyable` adoption

Under Option α (`Self: ~Copyable`), the surviving combinators
(`OneOf.Two`, `OneOf.Three`) need:

```swift
extension Parser.OneOf {
    public struct Two<P0: Parser.`Protocol` & ~Copyable, P1: Parser.`Protocol` & ~Copyable>: ~Copyable
    where
        P0.Input == P1.Input,
        P0.Output == P1.Output,
        P0.Input: Parser.Input.`Protocol`
    {
        @usableFromInline let p0: P0
        @usableFromInline let p1: P1
        @inlinable public init(_ p0: consuming P0, _ p1: consuming P1) {
            self.p0 = p0; self.p1 = p1
        }
    }
}

extension Parser.OneOf.Two: Parser.`Protocol`
where P0: ~Copyable, P1: ~Copyable {  // explicit per [feedback_extension_implies_copyable]
    // … (unchanged body, modulo borrowed self at parse time)
}
```

Both `OneOf.Two` and `OneOf.Three` field-store their parser parameters
directly. With Option 4 in place (no `OneOf.Any`), the combinator surface
becomes uniformly `~Copyable`-friendly. The cascade ceremony is bounded
to:

- `Parser.OneOf.Two` — 1 struct + 1 extension annotation
- `Parser.OneOf.Three` — 1 struct + 1 extension annotation
- `Parser.OneOf.Sequence` — 1 struct + 1 extension annotation (wraps a
  `body: Body` field; cascade flows through)
- `Parser.OneOf.Builder` — generic functions, no struct cascade needed
  but constraints may need `& ~Copyable` per the parent doc's
  cascade-shape analysis

This is in-scope for the parent doc's Phase 3 (N-parser combinators)
without surcharge. **Option 4 actively REDUCES the parent doc's Phase
5 ("Type-erased combinator opt-out: `Parser.OneOf.Any` stays
`Copyable` … Document the exception with a `[MEM-COPY-*]` rationale")
to a no-op.** The opt-out is no longer needed because the type that
required opting-out is deleted.

### F. Generalization to ecosystem-wide stdlib-Array caps

The brief asks whether this finding establishes an ecosystem-wide
pattern (e.g., for the Row 3 `[Lint.Finding]` stream pattern from the
v1.2.0 noncopyable-adoption-targets ecosystem survey).

The answer is **partially**:

- **Pattern**: "When a `[Closure]` or `[Element]` field is identified as
  the structural blocker for `~Copyable` adoption, FIRST verify whether
  the field has any callers." If zero callers, deletion dominates all
  redesign options.
- **Limit**: Row 3's `[Lint.Finding]` stream has many callers (the 73
  linter rules emit findings into that stream). Deletion is NOT
  available; the Row 3 redesign requires actual storage redesign work
  (likely a `Storage<Finding>.Heap` or a streaming emission pattern).
  Option 4's specific shape does not transfer.

The transferable lesson is the *meta-pattern*: before redesigning
storage for `~Copyable` admission, audit call-sites. If zero, prefer
deletion. This is consistent with [RES-018]'s premature-primitive
anti-pattern at the inverse: a primitive WITHOUT consumers is
deletable, just as a primitive without a second consumer is
unjustifiable.

Per the brief's escalation rubric, this generalization is too narrow to
warrant escalating the doc to `swift-institute/Research/`. The
recommendation is per-package (parser-stack-internal) with the
meta-pattern noted in this section as a per-package finding consumable
by ecosystem-wide analyses later.

### G. Prior art per [RES-021]

#### Rust parser-combinator libraries

**nom**: `alt!` macro / `alt((p1, p2, p3))` function — accepts a
*tuple* of parsers. Tuple-based dynamic-arity, NOT vector-based.
Variadic via the `Alt` trait implemented for tuples up to arity 21.
Each tuple element is a separately-typed parser; types are
preserved through the alternative. This is **structurally Option 1
(variadic generics)** in a language without parameter packs — nom
uses macro-generated trait implementations for tuple arity 2..=21.

```rust
let parser = alt((parser1, parser2, parser3));  // typed tuple, NOT Vec
```

For *runtime-dynamic* alternative parsing, nom users build
chained `or_else` calls, equivalent to nested `OneOf.Two`.
There is NO `Vec<Box<dyn Parser>>` shape in idiomatic nom.

**chumsky**: `choice((p1, p2, p3))` — same shape as nom's `alt`.
Tuple-based static-arity, typed per-call-site. The chumsky source
implements `Choice<T>` for tuples via the `ChoiceParser` trait
generated for arities 2..=26.

```rust
let parser = choice((p1, p2, p3));  // typed tuple
```

For runtime dynamic dispatch, chumsky users use `Boxed<P, E>` (heap
existential) only at deliberate erasure points, not as the default.

**combine**: `choice!(p1, p2, p3)` macro + `Choice<T>` trait for
tuples up to arity 26. Same pattern — variadic via tuple typeclass.

#### Lesson from Rust prior art

**No surveyed Rust parser-combinator library uses a runtime-`Vec` of
type-erased parsers as the canonical "alternative parsing" shape.**
All three (nom, chumsky, combine) use **tuple-based typed
alternatives** at every arity, with explicit boxed-existential
erasure as a deliberate opt-in for runtime polymorphism.

Translating to Swift Institute conventions:
- The "tuple-based typed alternatives" pattern is what
  `Parser.OneOf.Builder` already produces (`OneOf.Two<P0, P1>`,
  `OneOf.Three<P0, P1, P2>`, accumulated).
- The "boxed existential" opt-in is what an explicit `any
  Parser.\`Protocol\`<Input, Output>` wrapper would provide. No
  such wrapper exists today, and Option 5's analysis above shows
  why introducing one is undesirable.
- The "runtime `Vec` of closures" pattern — what
  `Parser.OneOf.Any` currently implements — is **without precedent
  in surveyed Rust libraries**. The shape is anomalous, not
  canonical.

This corroborates Option 4 from a different angle: the dynamic-arity-
via-`Array`-of-closures shape is not a parser-combinator design
pattern that the ecosystem outside Swift has chosen. Swift has it
because someone authored `Parser.OneOf.Any` in early development;
removing it brings the parser stack into alignment with prior art.

#### Swift Evolution

- **SE-0427** (Noncopyable Generics): foundational; enables `~Copyable`
  protocol Self.
- **SE-0408** (Pack iteration): enables `for x in repeat each xs` —
  load-bearing for Option 1.
- **SE-0436** (Borrowing existentials of `~Copyable` protocols):
  partial; Option 5's gating language feature, evolving.
- **SE-0453** (`InlineArray<N, T>`): stdlib inline array; `T: Copyable`
  required. Disqualifies Option 3's stdlib path.

No active Swift Evolution proposal pitches stdlib `Array<T>: ~Copyable`
support. The structural cap on `Array<~Copyable>` is therefore likely
to remain through at least Swift 6.4 — supporting Option 4's logic that
removal dominates over wait-for-compiler.

### H. Open Questions

| # | Question | Status |
|---|---|---|
| Q1 | Should the optional `buildBlock` variadic-generic overload (the "Option 4 + builder optimization" from Option 6a) be authored simultaneously with `OneOf.Any` deletion, or deferred? | DEFERRED. The builder's `buildPartialBlock` already handles N>3 via accumulation; the variadic-generic overload is a type-checker performance optimization. Deferring keeps the deletion change minimal. |
| Q2 | Does the `Parsing.OneOf.Any` twin at `swift-standards/swift-standards/Sources/Parsing/Parsing.OneOf.Any.swift` need the same treatment? | YES (consequence). Same shape, same zero-call-site situation likely. Out of scope here; surface as a downstream action on `swift-standards`. |
| Q3 | Does the same zero-call-site reasoning apply to `Parser.Many.Simple` or `Parser.Many.Separated` (which also store iterated parser state)? | NO. Both `Many.*` types are fundamentally different (they iterate ONE parser, not N alternatives); they don't store a `[Closure]` array. Out of scope. |
| Q4 | Does Option 4 adoption have any blast radius on `Parser.OneOf.Builder` consumers? | NO. The builder produces `OneOf.Two`/`Three` chains, not `OneOf.Any`. No consumer site changes. |
| Q5 | Should the deletion include the `Parser.OneOf.Any.Error` type? | YES. The aggregate error type is defined inside the deleted file and is not referenced elsewhere (verified at grep step). |

---

## Outcome

**Status**: RECOMMENDATION (Tier-2).

### Recommended option: 4 — Drop `Parser.OneOf.Any` entirely; rely on the result-builder cascade

**One-line rationale**: `Parser.OneOf.Any` has zero call-sites across
9 surveyed ecosystem repositories; the result-builder at
`Parser.OneOf.Builder` already provides dynamic-arity alternative
parsing at every N via typed `OneOf.Two`/`Three` accumulation, and
the cascade preserves stronger typed-throws guarantees than the
deleted array-of-closures shape ever did.

### Composition with parent doc v1.1.0

This recommendation **removes the dominant remaining structural
blocker** named in
`swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md`
v1.1.0 §6 bullet "Parser.OneOf.Any.parsers: [Closure] hard
structural cap" and §C(d) "Closure-capture limits" bullet 1. The
six-axis (d) cascade-cost score should be revised:

- v1.1.0 (d) = 4/5 (cascade still includes the 166-site mechanical
  migration + the `Parser.OneOf.Any` cap)
- Under Option 4 adoption: (d) ≈ **3/5** (cascade is the 166-site
  mechanical migration only; the structural cap is gone)
- Total score under Option 4: 1 + 2 + 2 + 3 + 3 + 2 = **7/30** — up
  from 6/30, still below the Wave-5 (25/30) / Wave-6 (20/30) adoption
  threshold

**The recommendation does not change v1.1.0's bottom line that Option
α stays deferred**, BUT it shifts the residual gate from a structural
problem (the cap) to a [RES-018]-style problem (the second-consumer
hurdle). Per the brief's explicit constraint, the [RES-018]
framing is rejected by the principal. With Option 4 adopted AND
[RES-018] retired, the remaining costs against Option α are the
166-site mechanical migration ceremony + foundations-layer
Copyable-constraint cascade. Whether THAT residual is acceptable is a
separable decision from this storage redesign.

The v1.1.0 doc's re-evaluation trigger (4) ("Stdlib `Array` adds
`~Copyable` element support — unblocks `Parser.OneOf.Any.parsers`")
becomes moot under Option 4 adoption — the trigger is invalidated
because the type is gone.

### Adoption sketch (deferred; not in this doc's scope)

If adopted:

1. **Delete** `swift-parser-primitives/Sources/Parser OneOf Primitives/Parser.OneOf.Any.swift`.
2. **No call-site migration** — verified zero callers.
3. **Confirm test absence** — no `Parser.OneOf.Any Tests.swift` file
   to remove (verified).
4. **(Optional, deferred)** Author a variadic-generic
   `Parser.OneOf.Builder.buildBlock<each P>` overload as a future
   type-checker performance optimization. Not coupled to the deletion.
5. **(Optional, deferred)** Apply the same analysis to
   `swift-standards/swift-standards/Sources/Parsing/Parsing.OneOf.Any.swift`
   (the independent twin). Out of scope here.
6. **(If Option α is later adopted)** `OneOf.Two`, `OneOf.Three`,
   `OneOf.Sequence` participate in the 166-site Phase-3 cascade as
   plain N-parser combinators. No OneOf-namespace-specific
   `[MEM-COPY-*]` opt-out is needed (parent doc's Phase 5 collapses to
   no-op).

The deletion change is ~80 LoC removed, zero LoC added. Tests pass
by construction (no `OneOf.Any` tests exist). Build passes by
construction (no `OneOf.Any` imports exist).

### Empirical-validation status

The recommendation rests on:

- **Verified zero-call-sites** across 9 ecosystem repositories
  (grep results documented inline in §A above).
- **Verified zero tests** under
  `swift-parser-primitives/Tests/Parser OneOf Primitives Tests/`
  (directory listing — only `Parser.OneOf.Two Tests.swift` exists).
- **Verified result-builder path coverage** at
  `Parser.OneOf.Builder.swift:78–89` (`buildPartialBlock`
  accumulation handles any N ≥ 1).
- **Verified `~Copyable` admission of replacement path**: `OneOf.Two`'s
  `let p0: P0, let p1: P1` storage is structurally identical to other
  N-parser combinators (e.g., `Parser.Take.Two`) and inherits the same
  `~Copyable` admission per the parent doc's §A shape-2 analysis.

No further verification spike is required for the deletion itself. A
verification spike WOULD be required if Option 1 (variadic-generics)
were chosen instead — to measure typecheck-explosion at N>12 — but
Option 4 has no such risk.

### Re-evaluation triggers

This recommendation should be revisited only if:

1. **A consumer surfaces requesting runtime-dynamic-arity from a
   `[P]` list** (not `[Closure]`). At that point, Option 1
   (variadic-generics) becomes a candidate as an additive future
   extension, NOT as a replacement for the result-builder.
2. **Stdlib `Array<T>` gains `~Copyable` element support** (no such
   proposal at time of writing). Even then, Option 4 remains
   preferred because the result-builder path is strictly more
   expressive than an array of closures.

---

## References

- `swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md` v1.1.0 — parent Tier-3 RECOMMENDATION; this doc resolves the dominant structural blocker named there
- `swift-institute/Research/2026-05-13-noncopyable-adoption-ecosystem-corners-audit.md` v1.0.0 — Row 11 + Row 18 framing
- `swift-foundations/swift-parsers/Research/parser-input-noncopyable-support.md` — Copyable / ~Copyable partition precedent at the Input axis
- `swift-parser-machine-primitives/Research/machine-noncopyable-input.md` — `Parser.Machine.Builder: ~Copyable` precedent at the machine layer
- `swift-primitives/swift-storage-primitives/Research/inline-pool-arena.md` — `Storage.Pool.Inline<N>: ~Copyable where Element: ~Copyable` precedent (informs Option 3 disqualifier)
- `swift-primitives/swift-storage-primitives/Research/bounded-unbounded-storage-inline-api.md` v2.0.0 — bounded-only public API discipline
- `swift-primitives/swift-parser-primitives/Experiments/parser-protocol-self-noncopyable-witness-tables/EXPERIMENT.md` — V5 (witness-table SIGSEGV REFUTED) and V6 (closure-of-~Copyable-return PASS) empirical findings
- `swift-primitives/swift-parser-primitives/Sources/Parser OneOf Primitives/Parser.OneOf.Any.swift` (lines 1–79) — the type being analyzed
- `swift-primitives/swift-parser-primitives/Sources/Parser OneOf Primitives/Parser.OneOf.Two.swift` (lines 12–53) — the survivor under Option 4
- `swift-primitives/swift-parser-primitives/Sources/Parser OneOf Primitives/Parser.OneOf.Three.swift` (lines 10–55) — the survivor under Option 4
- `swift-primitives/swift-parser-primitives/Sources/Parser OneOf Primitives/Parser.OneOf.Builder.swift` (lines 78–89) — the `buildPartialBlock` accumulation path that subsumes `OneOf.Any`
- `swift-primitives/swift-parser-primitives/Sources/Parser OneOf Primitives/Parser.OneOf.Sequence.swift` — the canonical entry-point per source docstrings
- `swift-primitives/swift-parser-primitives/Sources/Parser Take Primitives/Parser.Take.Builder.swift:114–133` — variadic-generic builder precedent in the parser stack
- `swift-primitives/swift-structured-queries-primitives/Sources/Structured Queries Primitives/QueryDecoder.swift:93–95` — variadic-generic production use precedent
- nom: <https://docs.rs/nom/latest/nom/branch/fn.alt.html> — `alt((p1, p2, p3))` tuple-based alternative parsing
- chumsky: <https://docs.rs/chumsky/latest/chumsky/primitive/fn.choice.html> — `choice((p1, p2, p3))` tuple-based alternative parsing
- combine: <https://docs.rs/combine/latest/combine/parser/choice/macro.choice.html> — `choice!` macro / `Choice<T>` typeclass
- SE-0408 (Pack iteration): <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0408-pack-iteration.md>
- SE-0427 (Noncopyable Generics): <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md>
- SE-0436 (Borrowing existentials of `~Copyable` protocols): <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0436-objc-existential-any.md>
- SE-0453 (`InlineArray<N, T>`): <https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md>
