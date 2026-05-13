# Parser.`Protocol`: ~Copyable (and ~Escapable) Relaxation

<!--
---
version: 1.0.0
last_updated: 2026-05-13
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
applies_to:
  - swift-primitives/swift-parser-primitives
  - swift-primitives/swift-parser-machine-primitives
  - swift-primitives/swift-binary-parser-primitives
  - swift-primitives/swift-ascii-parser-primitives
  - swift-foundations/swift-parsers
verification_experiment: none (analysis-only; spike scoped at adoption time if reconsidered)
predecessor: 2026-05-13-noncopyable-adoption-ecosystem-corners-audit.md (v1.0.0 RECOMMENDATION; Row 11 gating decision lift)
trigger: HANDOFF-parser-protocol-noncopyable-escapable-relaxation.md (Tier-3 follow-up to ecosystem-corners audit Q1)
---
-->

## Context

The 2026-05-13 ecosystem-corners audit
(`swift-institute/Research/2026-05-13-noncopyable-adoption-ecosystem-corners-audit.md`
v1.0.0 RECOMMENDATION) surfaced
**Row 11: `Parser.Machine.Compiled` (14/30)** as the highest-scoring
structural `~Copyable` candidate beyond the already-adopted Rows 1 + 2
(Wave 5 `Lint.Source.Parsed`, Wave 6 `Source.Manager`). Row 11 was
recorded as **blocked on**: relaxation of `Parser.`Protocol`` itself
across the parser stack — characterized as a Tier-3 cross-package
decision affecting ~30+ combinator types. The audit's Open Question Q1
deferred the protocol-level decision pending a *second* parser-stack
consumer per [RES-018].

This document scores `Parser.`Protocol`: ~Copyable` on `Self`
independently, enumerates the conformer cascade, surveys prior art per
[RES-021], applies Tier-3 rigor per [RES-023]/[RES-024], and recommends
among four options.

### Key structural fact (verified)

`Parser.`Protocol`.Input` is already declared `~Copyable & ~Escapable`
at
`swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift:95`:

```swift
public protocol `Protocol`<Input, Output, Failure> {
    associatedtype Input: ~Copyable & ~Escapable   // Input IS already ~Copyable
    associatedtype Output
    associatedtype Failure: Swift.Error
    associatedtype Body
    @Parser.Builder<Input>
    var body: Body { get }
    func parse(_ input: inout Input) throws(Failure) -> Output
}
```

Implicit (default): `Self: Copyable & Escapable`. The open question is
whether `Self` itself (the conforming parser type) should also be
`~Copyable` and/or `~Escapable`.

### Prior research (per [RES-019] step-0 internal grep)

| Document | Bearing on this Tier-3 decision |
|---|---|
| `swift-institute/Research/2026-05-13-noncopyable-adoption-ecosystem-corners-audit.md` (v1.0.0 RECOMMENDATION, 2026-05-13) | **Predecessor.** Row 11 scoring (14/30) + the explicit Q1 deferral, naming this protocol-relaxation as the gating decision. This Tier-3 doc resolves Q1. |
| `swift-institute/Research/2026-05-13-noncopyable-adoption-targets-ecosystem-survey.md` (v1.2.0 RECOMMENDATION, 2026-05-13) | **Six-axis framework predecessor.** Establishes the scoring axes (a)–(f) and the inversion convention for cascade cost. Rows 1+2 adoption history. |
| `swift-institute/Research/se-0499-implications-for-equation-hash-comparison-primitives.md` (v1.3.0 RECOMMENDATION, 2026-05-03) | Empirical verification of SE-0499 (Hashable / Equatable / Comparable natively support `~Copyable` from Swift 6.4). Demonstrates that the stdlib-protocol cascade-cost line item has narrowed since 2026-Q1. Does not bear on parser-protocol relaxation directly (`Parser.`Protocol`` is institute-owned, not stdlib). |
| `swift-primitives/swift-parser-primitives/Research/witness-table-sigsegv-with-noncopyable-protocol-constraints.md` (v1.0.0 DECISION, 2026-02-14) | **Critical compiler-bug evidence.** SIGSEGV during cross-module witness-table instantiation when `~Copyable` protocol constraints combine with composed generic types from external packages (Swift 6.2.3, `swiftlang/swift#85441` pattern). Currently confined to the `Parser.`Protocol`.Input: ~Copyable` surface; production workaround uses local wrapper types in tests. Extending `~Copyable` to `Self` materially expands the cross-module exposure surface and the compiler-bug attack surface. |
| `swift-foundations/swift-parsers/Research/parser-input-noncopyable-support.md` (v1.0.0 DECISION, 2026-03-16) | **Direct precedent.** Documents the `Parser.`Protocol`.Input: ~Copyable & ~Escapable` decision (Option B chosen). Establishes that *Input* is checkpoint/restore on `Input.`Protocol``; consumer cascade for the foundations combinators (Separated, Chain.Left/Right, Expression.Climbing) absorbed via explicit `where Input: Copyable` re-constraints on copy-based-backtracking combinators. |
| `swift-primitives/swift-parser-machine-primitives/Research/machine-noncopyable-input.md` (v1.0.0 DECISION, 2026-02-24) | **Direct precedent (Option B, ~Copyable Input cascade).** Resolves the Machine.Compile.Witness / Compiled / Prepared cascade for `~Copyable Input`. Closure-types-with-`~Copyable` `inout` parameters, Sendable / Copyable derivation with phantom `~Copyable` parameters — all three compiler unknowns resolved positively. Establishes that Machine *Builder* is `~Copyable` (Machine.swift:71), while Machine *Compiled* / *Prepared* remain Copyable conformers of `Parser.`Protocol`` (the exact pattern surfaced as Row 11). |
| `swift-institute/Research/noncopyable-ecosystem-state.md` (v1.0.0 DECISION, 2026-04-02) | Canonical state-of-ecosystem reference. Five permanent-by-design `~Copyable` limitations; three transfer patterns ([MEM-OWN-010]/[MEM-OWN-011]/[MEM-OWN-012]); Layer 0/1/2 discipline ([IMPL-070]); 3× write-throughput synchronization-as-ownership finding ([IMPL-063]). |
| `swift-institute/Research/parser-combinator-algebraic-foundations.md` (RECOMMENDATION) | Algebraic-foundations comparison across parser-combinator libraries (nom, combine, chumsky, swift-parsing). Establishes what is universally absent (algebraic-laws-as-trait) — direct ownership-discipline comparison not the doc's focus. |
| `swift-institute/Research/parser-bridge-architecture.md` | Documents `Collection.Slice.Protocol & Copyable` constraint where copy-based input bridging is needed. Same partial-Copyable pattern surfaced at `Parser.Span.swift:48` — confirms the ecosystem already partitions `~Copyable Input` vs `Copyable Input` at the Input axis. |
| `swift-institute/Research/parser-syntax-ergonomics-comparison.md` (RECOMMENDATION, 2026-03-05) | Architectural-strength comparison vs pointfreeco/swift-parsing. Documents the current `var body` / `func parse` shape with `~Copyable & ~Escapable` Input support. |
| `swift-institute/Research/path-type-ecosystem-model.md` (2026-04-18) | The L3-Copyable-wraps-L1-`~Copyable` reference architectural shape. Cited as the canonical answer to *"when should `Self: ~Copyable` propagate up the stack?"* — definitively NOT when the Copyable wrapper IS the architectural bridge to stdlib containers. |

This Tier-3 doc **extends** the predecessor framework; it does not
duplicate or revise Rows 1–10 from v1.2.0 nor Rows 11–18 from the
ecosystem-corners audit. The audit's Q1 is **resolved** here.

### Constraints

(carry-forward from predecessors — re-verified 2026-05-13)

- **Toolchain matrix**: Swift 6.3 stable + 6.4-dev nightly per
  `feedback_toolchain_versions.md`. SE-0499 (stdlib Hashable / Equatable
  / Comparable on `~Copyable`) is in Swift 6.4. Does not directly bear
  on `Parser.`Protocol`` (institute-owned protocol).
- **SuppressedAssociatedTypes feature flag**: required for the
  associated-type-side suppression (`associatedtype Input: ~Copyable &
  ~Escapable`); already enabled on `swift-parser-primitives`,
  `swift-parser-machine-primitives`, `swift-parsers`. Self-side
  suppression (`protocol Foo: ~Copyable`) does NOT require this flag —
  it has shipped since Swift 5.9 / SE-0427.
- **Witness-table SIGSEGV** (`swiftlang/swift#85441` pattern): cross-
  module ~Copyable witness-table instantiation crash documented for
  `Parser.`Protocol`.Input: ~Copyable` in February 2026. NO upstream
  fix shipped; workaround is local wrapper types in tests. The bug
  scales with the metadata complexity of the concrete type — extending
  `~Copyable` to `Self` materially worsens exposure (every composed
  combinator with cross-module concrete Self would hit the same path).
- **Stdlib `Array`, `Set`, `Dictionary`**: still do NOT support
  `~Copyable` elements as of Swift 6.4. Parser values are often stored
  in stdlib arrays at consumer sites (e.g., `Parser.OneOf.Any.parsers:
  [(inout Input) throws -> Output]` — actually closures, but
  semantically a heterogeneous list).
- **Stdlib `IteratorProtocol`, `Sequence`, `Collection`**: still
  require Copyable elements. Parsers are not iterators, but consumer-
  side patterns like `for parser in [p0, p1, p2] { … }` would break.
- **Result-builder generic functions** (Parser.Take.Builder,
  Parser.OneOf.Builder): use generic functions like `buildBlock<P0:
  Parser.`Protocol`, P1: Parser.`Protocol`>(P0, P1) -> Take.Two<P0, P1>`.
  Result builders work with `~Copyable` types in Swift 6.x but the
  cascade through every `Take.Two<P0, P1>` / `Skip.First<P0, P1>` /
  `OneOf.Two<P0, P1>` wrapper field-stores `let p0: P0, let p1: P1`
  requires every wrapper to opt into the same kind (Copyable or
  ~Copyable) as the type parameters it stores.

### Scope

In scope (research only — NO code modifications):

1. Prior-research check per [HANDOFF-013] — completed (table above).
2. Score `Parser.`Protocol`: ~Copyable on Self` independently using the
   v1.2.0 six-axis framework.
3. Score `Parser.`Protocol`: ~Escapable on Self` as a separable axis.
4. Survey the ~166 direct conformer cascade and characterize shapes.
5. Examine the `Parser.Printer` extension constraint at
   `Parser.Span.swift:48` as informative evidence for already-partial
   Copyable / ~Copyable Input partitioning.
6. Examine the swift-parser-machine-primitives `Machine.*` family —
   determine whether Row 11 / Row 12 are downstream of the gating
   decision or independent of it.
7. Recommend among Options α / β / γ / δ; identify the highest-
   information first step if reconsidered.
8. Tier-3 rigor: prior art per [RES-021] (Rust nom / chumsky, Haskell
   parsec / megaparsec, Swift Evolution discussions on protocol
   `~Copyable` inheritance); formal semantics per [RES-024];
   systematic literature review per [RES-023].

Out of scope: implementation work; revisiting Rows 1+2 (already
adopted) or Row 3 (deferred); modifying `Parser.Input` (already
`~Copyable & ~Escapable`); swift-parser-machine-primitives `Machine.*`
family internal redesign beyond characterizing its relationship to the
gating decision; pitching protocol-level `~Copyable Self` upstream
beyond the institute.

---

## Question

Should `Parser.`Protocol`` be relaxed to `: ~Copyable` (Option α), or
to `: ~Copyable & ~Escapable` (Option β), or held at the current
`: Copyable & Escapable` (Self default; Option δ), or applied
selectively (Option γ)?

Sub-questions:

1. What is the score of `Parser.`Protocol`: ~Copyable on Self` under
   the v1.2.0 six-axis framework, and how does it compare to the audit's
   Row 11 score (14/30 on `Parser.Machine.Compiled` in isolation)?
2. Is `~Escapable on Self` a separable, defensible axis from `~Copyable
   on Self`, or are they entangled?
3. Of the ~166 conformer sites, what proportion fall into shapes that
   absorb the cascade cheaply (per the Wave-5+6 ecosystem-readiness
   lens) vs. require structural API redesign?
4. What does prior art (Rust nom / chumsky, Haskell parsec /
   megaparsec, Swift Evolution) tell us about whether a parser-
   combinator protocol benefits from move-only Self semantics, and does
   that prior art translate to Swift's ownership-default conventions?
5. If `Parser.`Protocol`` is *not* relaxed, can `Parser.Machine.Compiled`
   (audit's Row 11, 14/30) be adopted as `~Copyable` *without* protocol
   relaxation — or is the protocol relaxation strictly necessary?

---

## Analysis

### A. Conformer Cascade Survey

Per `grep ": Parser.\`Protocol\`"` measured 2026-05-13, the direct-
conformance cascade is:

| Package | Sources / direct conformer sites |
|---|---|
| swift-parser-primitives | 111 |
| swift-parsers (Foundations) | 45 |
| swift-binary-parser-primitives | 8 |
| swift-ascii-parser-primitives | 2 |
| swift-parser-machine-primitives | 0 (uses Machine.* shapes; see §B) |
| **Total direct** | **166 across 4 packages** |

Additionally, generic functions in result builders accept `P:
Parser.`Protocol`` as type parameters (12 sites in
`Parser.Take.Builder`, 5 sites in `Parser.OneOf.Builder`, plus
distributed across foundations combinators). These are NOT direct
conformers but participate in the protocol-Self generic frontier and
must be re-evaluated as part of any cascade.

#### Shape characterization

Conformers fall into five structural shapes:

| Shape | Description | Stored-property contents | Count (approx.) | Cascade impact under Self: ~Copyable |
|---|---|---|---|---|
| **Leaf parser** | No `Parser.`Protocol`` field; pure value or closure | `init()` only, or stored error / config value | ~25 (Fail, Always, End, Rest, First.Element, First.Where, Byte, Literal, Skip.* leaves, Prefix.*, Consume.Exactly, Discard.Exactly, byte/char/literal/tracked leaves, ASCII / Binary leaf parsers) | Compatible; conformer body trivially `~Copyable` (no Copyable fields to constrain). |
| **Single-parser combinator** | Stores ONE `Upstream: Parser.`Protocol`` field | `let upstream: Upstream`, plus closures or config | ~20 (Map.Transform, Map.Throwing, FlatMap, Filter, Trace, Lazy, Optional, Optionally, Peek, Not, Error.Map, Error.Replace, Many.Simple, Many.Separated, Span, Tracked-wrappers) | Must propagate Self: ~Copyable to wrapper. If Upstream: ~Copyable (default), wrapper must be ~Copyable. If Upstream: Copyable, wrapper MAY be either; default to ~Copyable for consistency. |
| **N-parser combinator** | Stores N `Parser.`Protocol`` fields (Take.Two, OneOf.Two, Skip.First, Skip.Second, OneOf.Three, Chain.Left, Chain.Right, Expression.Climbing, Separated) | `let p0: P0, let p1: P1` (+ Pn) | ~15 | Same as single-parser; cascade multiplies by N at type level (every field-store must propagate). |
| **Type-erased / closure-based combinator** | Stores `[(inout Input) throws -> Output]` or similar closure-array | `let parsers: [Closure]` | 1 (Parser.OneOf.Any) | Compatible at conformer level. Closures cannot capture `~Copyable` parsers — type-erasure forces a copy at construction. Conformer can be either Copyable or ~Copyable. |
| **Machine wrapper** | Stores compiled state-machine + reference-typed Cache | `let source: P, witness: ..., cache: Cache (final class)` | 2 (Parser.Machine.Compiled, Parser.Machine.Prepared) | The audit's Row 11/12. *Wants* to be `~Copyable` (single-owner cache); blocked at the protocol level today. |

#### Result builder generic functions

`Parser.Take.Builder` and `Parser.OneOf.Builder` contain ~17 generic
functions of shape `buildBlock<P0: Parser.`Protocol`, P1:
Parser.`Protocol`>(P0, P1) -> Two<P0, P1>` etc. These are NOT direct
conformers but are participating callers of the generic frontier. If
`Self: ~Copyable` is opt-in:

- The function signature must constrain `P0, P1` against `~Copyable`-
  suppression; Swift's default is to constrain on `Copyable`, so the
  function defaults absorb today's authored code.
- The returned wrapper types (`Two<P0, P1>`, `OneOf.Two<P0, P1>`, etc.)
  field-store `let p0: P0, let p1: P1`. Storing a `~Copyable P0` in a
  `Copyable` wrapper is forbidden (Swift error: "cannot store a value
  of `~Copyable` type"). So either:
  (i) wrapper types declare `: ~Copyable` AND constrain `P0, P1: ~Copyable`
  (cascade), or
  (ii) wrapper types stay `Copyable` AND constrain `P0, P1: Copyable`
  in the builder signature (NO cascade at wrapper, but cascade at
  builder constraint surface).

Either path multiplies the cascade by ~30 additional sites at the
builder layer.

#### Closure-capture cascade

`Parser.Lazy<P: Parser.`Protocol`>` stores `let build: () -> P`. If
`P: ~Copyable`, the closure return-type is `~Copyable` — closures
returning `~Copyable` values DID become legal at SE-0427 / SE-0432, but
the @autoclosure variant of Lazy may need re-shaping:

```swift
// Today:
public struct Lazy<P: Parser.`Protocol`> {
    internal let build: () -> P
    public init(_ build: @escaping @autoclosure () -> P) { … }
}

// Under Self: ~Copyable, with P: ~Copyable:
public struct Lazy<P: Parser.`Protocol` & ~Copyable>: ~Copyable {
    internal let build: () -> P                          // closure-returns-~Copyable: works post-SE-0432
    public init(_ build: @escaping () -> P) { … }        // @autoclosure on ~Copyable expression: WIP per SE-0432 / SE-0497
}
```

The @autoclosure case is the riskiest; @autoclosure with ~Copyable
returns is partially supported, behavior varies by toolchain.

Additionally, `Parser.OneOf.Any.parsers: [(inout Input) throws -> Output]`
already type-erases via closures. Closures cannot capture `~Copyable`
parsers, so `OneOf.Any` cannot construct ~Copyable parsers as
elements — this is a hard cap on the type-erasure shape under
Option α.

#### Foundations cascade (swift-parsers)

`swift-parsers` already exhibits a partial cascade for `Input:
Copyable` constraints (per `parser-input-noncopyable-support.md`
Phase 2):

- `Parser.Chain.Left<Operand, Operator>`: `where Operand.Input: Copyable`
- `Parser.Chain.Right<Operand, Operator>`: `where Operand.Input: Copyable`
- `Parser.Expression.Climbing<Atom, Op>`: `where Atom.Input: Copyable`
- `Parser.Separated<Element, Separator>`: `where Element.Input: Copyable`

These combinators use copy-based backtracking and require `Input:
Copyable`. Under Option α / β, the SAME pattern would emerge for Self:
combinators that semantically need to copy-construct or store an
Upstream by value would need `where Upstream: Copyable` constraints,
EXACTLY mirroring the Input cascade. The number of such combinators is
not obviously much smaller than the total combinator count.

### B. Machine.* family relationship to the gating decision

The Machine.* family (`swift-parser-machine-primitives`) has 0 direct
`Parser.`Protocol`` conformers in its Sources/ count, but it contains:

- `Parser.Machine.Compiled<P: Parser.`Protocol`>: Parser.`Protocol``
  (Row 11; the audit's highest-scoring structural candidate)
- `Parser.Machine.Prepared<P: Parser.`Protocol`>: Parser.`Protocol``
  (Row 12; the immutable, conditionally-Sendable counterpart)
- `Parser.Machine.Parser<Input, Output, Failure>: Parser.`Protocol``
  (concrete machine-runner; conforms directly)
- `Parser.Machine.Compile.Witness<P>` (NOT a Parser.`Protocol`
  conformer; the compilation strategy)

Per `machine-noncopyable-input.md` (DECISION, 2026-02-24), the Machine
internals are already partially `~Copyable`:

- `Parser.Machine.Builder<Input, Failure>: ~Copyable` at Machine.swift:71
- `Parser.Machine.Leaf<Input, Failure>` — Sendable closure store; remains
  Copyable
- `Parser.Machine.Expression<Input, Failure, Output>` — node-id wrapper;
  remains Copyable

The pattern at the machine layer is **single-mutable-Builder is
~Copyable, executor wrappers are Copyable** — analogous to the L1-
~Copyable Path / L3-Copyable Paths.Path pattern documented at
`path-type-ecosystem-model.md`. This pattern is already RESOLVED for
the Machine internals.

What is NOT resolved: the wrappers that conform to
`Parser_Primitives.Parser.`Protocol`` (`Compiled`, `Prepared`, `Machine.Parser`).
These are wrappers around the immutable Machine runtime; they're
**users** of the protocol, not internals of the machine.

**Relationship to the gating decision**: the Machine.* family's
`Compiled` wants `~Copyable` semantics (Row 11) — it ALONE among the
166 conformers has the resource-correlation that motivates ~Copyable.
The Machine.* internals themselves (`Builder`, `Leaf`, `Expression`)
are downstream of the gating decision (already partially adopted in
the Builder; not affected by `Parser.`Protocol`: ~Copyable` because
they're not conformers).

So: **Row 11 is the ONE structural consumer.** The Machine.* family
as a whole is *not* a second consumer — the rest of the family is
either internal-only or shares the same single use case.

### C. Six-axis Scoring: `Parser.`Protocol`: ~Copyable on Self`

Axes definitions per v1.2.0 (predecessor framework):

| Axis | What it measures |
|---|---|
| (a) Resource-correlation | Does the type wrap a real acquire/release lifecycle? |
| (b) Size / hot-path | Is move-vs-copy observable at consumer call sites? |
| (c) Safety bug class prevented | Does `~Copyable` close a specific bug class (UAF, double-free, aliasing, stale-state)? |
| (d) Cascade cost | Total cascade footprint. **High score = high cost = inverted in ranking.** |
| (e) Pattern-establishing | Does adoption exercise broad ecosystem infrastructure? |
| (f) Existing alignment | Does the type already smuggle single-owner semantics through a Copyable boundary, or already pass `inout`? |

Scoring scale 0–5. Total = (a)+(b)+(c)+(e)+(f) − (d).

#### Scoring Option α (`Self: ~Copyable`)

**(a) Resource-correlation: 1/5.** The `Parser.`Protocol`` protocol
itself acquires no resource. Of 166 conformers, exactly TWO are
resource-bearing: `Parser.Machine.Compiled` (final-class `Cache`;
single-isolation-domain compile cache) and `Parser.Machine.Prepared`
(immutable shared program — but Row 12 expressly argues against
`~Copyable` for this; it's the shared variant of Compiled by design).
The remaining 164 conformers are pure-value combinators describing
parsing logic; they own nothing acquireable. Resource-correlation of
the PROTOCOL is essentially `(2 of 166)` × the Row 11 motivation —
asking 164 non-resource types to inherit `~Copyable` for the benefit
of ONE terminal type ([RES-018] second-consumer hurdle is not cleared).

**(b) Size / hot-path: 2/5.** Parser values are typically small —
stored closures, generic type parameters, witness pointers. The hot
path is `parse(_ input: inout Input)` — already inout-based, the
parser is borrowed via `self` at call time, no per-call copy of `Self`
occurs in well-optimized inlined code. The only "size" concern is
deeply-composed parser trees where each combinator's `let upstream:
Upstream` accumulates — but Swift's existential elision and inlining
typically collapse these to flat-storage layouts at the call site.
Move-vs-copy of `Self` is not observable in measured hotspots; ~Copyable
provides no measurable wins. Same conclusion at the foundations
combinators per `parser-input-noncopyable-support.md` v1.0.0 Option B
rationale §3.

**(c) Safety bug class: 2/5.** Concrete bug classes that
`Self: ~Copyable` would close:

1. Accidental aliasing of `Parser.Machine.Compiled.Cache` (a `final
   class`) when a `Compiled` value is copied into two `some Parser.`Protocol``
   slots crossing isolation domains. The doc-comment at
   `Parser.Machine.Compiled.swift:27–31` documents this as an invariant;
   `~Copyable` would promote it to a compile-time guarantee. This is
   the audit's Row 11 (c)-3 finding.
2. **Lazy parser re-construction** (`Parser.Lazy.build()` called per-
   `parse`): if `Self: ~Copyable`, the closure could not capture a
   ~Copyable parser by value, forcing inout-style or borrowed access.
   The current shape is a benign optimization, not a bug class.
3. **Stateful parsers**: a parser holding mutable cursor state in
   Self. **The current ecosystem deliberately puts ALL state in Input**,
   making Self stateless. No current conformer has stateful Self;
   `~Copyable Self` would protect against a bug class that does NOT
   exist in the current design.

The bug class is therefore narrow: ONE confirmed case (Row 11 Cache
aliasing). The other two are either non-existent or speculative.

**(d) Cascade cost: 5/5 (HIGHEST — STRUCTURAL BARRIER).** Cascade
breakdown:

- **166 direct conformer sites** across 4 packages — every conformer
  must be re-evaluated for `~Copyable` propagation.
- **~30 wrapper types** with parser-typed fields must propagate
  `~Copyable` through their type declarations OR explicitly constrain
  `Upstream: Copyable`.
- **~17 builder generic functions** in `Parser.Take.Builder` and
  `Parser.OneOf.Builder` must be re-evaluated; result-builder
  wrappers (`Take.Two`, `Skip.First`, `OneOf.Two`, etc.) become
  wrapper-cascade points.
- **Closure-capture limits**: `Parser.OneOf.Any.parsers: [(inout Input) throws -> Output]`
  cannot host `~Copyable` parser elements — forces the type-erased
  combinator to remain Copyable, creating an in-ecosystem asymmetry.
- **`@autoclosure` for `Parser.Lazy`**: partially supported for
  ~Copyable returns per SE-0432 / SE-0497; risks toolchain-specific
  fragility.
- **Witness-table SIGSEGV** (`swiftlang/swift#85441` pattern): the
  predecessor research confirmed cross-module witness-table
  instantiation crashes when ~Copyable protocol constraints meet
  composed generic types from external packages on Swift 6.2.3. The
  bug is currently confined to the `Input: ~Copyable` surface;
  extending to `Self: ~Copyable` materially expands exposure across the
  166-site cascade. No upstream fix has shipped. The workaround (local
  wrapper types in tests) does not scale to production cross-package
  composition.
- **Stdlib-protocol losses**: SE-0499 unblocks Hashable / Equatable /
  Comparable on `~Copyable`, but parsers do not currently conform to
  these (parsers are descriptions, not data). `Sendable` is the only
  parser-relevant stdlib protocol — it supports `~Copyable`
  conformers under SE-0427.
- **Foundations cascade**: `swift-parsers/Sources/Parsers/Parsers.{Chain,Expression,Separated}.swift`
  already constrains `Input: Copyable` because copy-based backtracking
  is structurally Copyable-only. The same partition pattern would
  emerge for `Self: Copyable` constraints on combinators that need to
  store an Upstream by value — likely covering 30–50 % of the
  combinator set.

The witness-table SIGSEGV is the decisive factor: this is a
**verified, unfixed compiler bug** that scales adversely with the
proposed change.

**(e) Pattern-establishing: 3/5.** If adopted, this would be the
institute's largest protocol-Self `~Copyable` adoption to date. It
would establish patterns like:

- result-builder generic functions accepting `~Copyable` conformers
  systematically
- closure-store-of-~Copyable-body workarounds at scale
- cross-module witness-table-with-`~Copyable`-protocol production
  shape (IF the SIGSEGV gets fixed first)

However, per [RES-018] premature primitive anti-pattern: there is no
named second consumer demanding borrow-by-default parser semantics.
The audit's Row 11 (`Parser.Machine.Compiled`) is the lone consumer
within the parser stack. Pattern-establishing value depends on whether
the pattern gets re-used, which the audit Q1 explicitly deferred to
"if a second consumer surfaces."

Counter-argument credit: the institute does have a pattern of
authoring "timeless infrastructure" — adopting protocols-as-~Copyable
preemptively could have value for parser packages not yet written
(SQL parsers, JSON parsers with streaming state, network-protocol
parsers with connection state, etc.). But this is speculative; per
[RES-018] symmetric-completeness reasoning is explicitly disallowed
as sole justification.

**(f) Existing alignment: 2/5.** The current alignment is asymmetric:

- `Input: ~Copyable & ~Escapable` — yes, the protocol acknowledges
  that *inputs* can be move-only.
- `Self: Copyable` (implicit) — the typical parser is *stored as a
  field* (`let upstream: Upstream` in 80+ combinators), *passed by
  value* into builder generic functions, and *constructed at
  composition time* via copy semantics. The ecosystem has NOT
  structured parser instances around inout discipline.
- `inout` is on `parse(_ input: inout Input)`, not on Self. Self is
  threaded through composition by-value, then accessed via borrowed
  `self` at parse time.
- The Machine layer's `Builder: ~Copyable` (Machine.swift:71) is the
  ONE exception, AND it is NOT a `Parser.`Protocol`` conformer —
  reinforcing the partition.

Adopting `Self: ~Copyable` would invert the access discipline at every
combinator. This is OPPOSITE the Wave-6 Source.Manager pattern (where
consumer sites ALREADY used inout). The 2026-05-13 ecosystem-corners
audit explicitly noted (`§ Wave-5+6 ecosystem-readiness — generalization
or accident?`) that the Wave-5+6 cheap-cascade is the EXCEPTION within
the Copyable residual, NOT the rule. Parser protocol relaxation is the
canonical example of the rule.

**Total: 1 + 2 + 2 + 3 + 2 − 5 = 5/30** (cascade-cost-inverted).

Compare to v1.2.0's adopted Row 1 (`Lint.Source.Parsed`: 25/30) and
Row 2 (`Source.Manager`: 20/30): **5/30 is decisively below the
adoption threshold**.

#### Scoring Option β (`Self: ~Copyable & ~Escapable`)

**(a) Resource-correlation: 0/5.** Self being ~Escapable would bind
parser instances to a particular borrowed Input lifetime. But parsers
DO NOT hold borrowed inputs as fields — they hold descriptions,
closures, and other parsers. The motivation for ~Escapable on Self is
essentially nil.

**(b) Size / hot-path: 0/5.** Lifetime scoping doesn't affect size or
hotpath observability.

**(c) Safety bug class: 1/5.** ~Escapable could prevent escaping a
parser to a context where Input has been deallocated. But parsers are
typically constructed once and re-used across many parse calls (e.g.,
`let p = SomeParser(); for input in inputs { try p.parse(&input) }`);
binding the parser's lifetime to a specific Input invocation is anti-
ergonomic and would block this idiom.

**(d) Cascade cost: 5/5.** Massive cascade additional to ~Copyable:
every parser becomes lifetime-bound, cannot be stored in `var`, cannot
escape closures, cannot return from a function. This breaks `var body:
some Parser.`Protocol`<…>` (returning a parser), `let parser =
SomeParser()` (storing in a let with implicit lifetime), and result
builder return chains.

**(e) Pattern-establishing: 1/5.** ~Escapable parsers — no second
consumer wanting them, and no parser-combinator library in the
surveyed prior art (nom, combine, chumsky, parsec, megaparsec, swift-
parsing) imposes a lifetime constraint on the parser itself.

**(f) Existing alignment: 0/5.** Currently parsers are stored as
fields throughout the ecosystem. ~Escapable Self would break all of
these field stores; the current shape `let upstream: Upstream` at
~80 + sites is incompatible with `Upstream: ~Escapable` unless every
wrapper is also ~Escapable, which propagates to the same field-store
discipline at the wrapper, recursively.

**Total: 0 + 0 + 1 + 1 + 0 − 5 = −3/30** (floored to 0/30).

Option β is **structurally untenable**. ~Escapable Self is
categorically wrong for a description/witness type that needs to
outlive any particular parse invocation. The Parser.Tracked /
Parser.Span Input wrappers use ~Escapable on *Input* precisely because
*Input* IS the consumed buffer; *Self* IS the witness that explains
how to consume.

#### Scoring Option γ (`~Copyable` on Self constrained to leaf parsers only; combinators stay Copyable)

This option is **not implementable as stated** at the protocol level.
Swift's protocol-Self model is binary: either `Self: ~Copyable` (some
conformers may be ~Copyable, others Copyable) or `Self: Copyable`
implicit (all conformers must be Copyable). There is no "Self:
~Copyable only for some conformers" at the protocol declaration.

Interpreting γ as "the protocol declares `Self: ~Copyable`, but the
ecosystem actively maintains the invariant that combinators remain
Copyable while leaf parsers MAY be ~Copyable":

**Cascade cost is essentially identical to Option α at the protocol
boundary** — every combinator wrapper that field-stores
`let upstream: Upstream` must EITHER inherit ~Copyable from Upstream OR
constrain `Upstream: Copyable` explicitly. The 166-site cascade is
NOT reduced by partitioning at conformance time; it surfaces as
explicit Copyable-re-constraints across the combinator surface.

The ONE potential win of Option γ: `Parser.Machine.Compiled` can
become `: ~Copyable` (Row 11 unblocks) without forcing every leaf
parser to become `~Copyable`. The Foundations layer's `Chain.Left`,
`Chain.Right`, `Expression.Climbing`, `Separated` would add
`where Upstream: Copyable` constraints (analogous to their existing
`where Input: Copyable` constraints).

**Total score**: same axes as α with marginal (d) reduction (maybe
4/5 instead of 5/5 — the witness-table SIGSEGV exposure is identical,
but the cascade-shape ceremony is reduced). Estimate: 6/30.

Marginally better than α (5/30) but still decisively below threshold.
Plus γ introduces an *invariant the type system does not enforce*
("combinators stay Copyable by convention") — a fragile discipline.

#### Scoring Option δ (Defer indefinitely; cite blocker)

This is a meta-option (no protocol change). Costs and benefits:

- **(d) Cost: 0/5.** No cascade. No protocol change. No type-system
  re-evaluation needed across 166 sites.
- **Cost: forfeits Row 11 adoption.** `Parser.Machine.Compiled` cannot
  become `~Copyable` while conforming to `Parser.`Protocol``. Workarounds:
  - Document the Cache-aliasing invariant (current state; in place per
    `Parser.Machine.Compiled.swift:27–31`).
  - Provide a sibling `Parser.Machine.Compiled.Owned: ~Copyable` type
    that does NOT conform to `Parser.`Protocol`` and is consumed
    directly by callers via `compiledOwned.parse(&input)`. This is
    the audit's Option (ii); it preserves the resource-correlation
    win for the single-owner use case AND keeps the Copyable
    composability surface for the protocol-typed compositional use
    case. **This is the canonical L1-~Copyable / L3-Copyable
    bifurcation per `path-type-ecosystem-model.md`.**
- **Cost: forfeits the speculative pattern-establishing win** (e)
  from Option α. Acceptable per [RES-018] absent a second consumer.

**Total: 0/30 cascade cost; full benefit of leaving the ecosystem
shape intact.**

#### Summary scoring table

| Option | (a) | (b) | (c) | (d) cost | (e) | (f) | **Total** | Verdict |
|---|---|---|---|---|---|---|---|---|
| α (Self: ~Copyable) | 1 | 2 | 2 | **5** | 3 | 2 | **5/30** | Below threshold |
| β (Self: ~Copyable & ~Escapable) | 0 | 0 | 1 | **5** | 1 | 0 | **0/30** floored from −3 | Structurally untenable |
| γ (Self: ~Copyable; combinators Copyable by convention) | 1 | 2 | 2 | **4** | 3 | 2 | **6/30** | Below threshold; fragile invariant |
| δ (Defer; sibling-type workaround for Row 11) | n/a | n/a | n/a | **0** | n/a | n/a | **n/a — meta-option, no cascade** | **RECOMMENDED** |

### D. Examination of `Parser.Span.swift:48` constraint

```swift
extension Parser.`Protocol` where Input: Parser.Input.`Protocol` & Copyable {
    public func spanned() -> Parser.Span<Input, Self> { … }
}
```

The `& Copyable` constraint here is informative evidence that the
ecosystem has **already established a partition pattern** at the Input
axis: convenience methods explicitly constrain `Input: Copyable`
where copy-based wrapping is needed. The conformance shape of the
protocol does NOT presuppose Copyable Input; it allows ~Copyable
Input but provides Copyable-only conveniences at extension scope.

This pattern is **directly applicable** to the Option δ
recommendation: rather than relax `Parser.`Protocol`: ~Copyable on Self`
at protocol scope, the institute can offer `Self: ~Copyable` shapes at
extension scope (sibling types not conforming to the protocol;
specialized conveniences with Copyable-Self constraints). The audit's
Option (ii) for Row 11 follows exactly this shape.

### E. Tier-3 Prior Art Survey per [RES-021], [RES-023]

#### Rust ecosystem (move-only-first)

**nom**: function-based combinators of shape `fn parser(input: I) -> IResult<I, O>`.
There is no "Parser trait" in nom — combinators are just generic
functions. Rust's default `Sized + ?Move` semantics handle ownership at
the function boundary; the equivalent of "Self: ~Copyable" question
doesn't arise because there is no Self at the protocol level.

**combine**: `trait Parser { type Input; type Output; … fn parse_stream(&mut self, input: ...) -> ParseResult }`.
Self uses `&mut self`. Rust traits do NOT presuppose `Copy` (`Copy` is
opt-in; the default is move-only). All Parser conformers are move-only
by default. The trait is the closest direct analog to a hypothetical
Option α design.

**chumsky**: `trait Parser<'a, I: Input<'a>, O>` with rich method chaining
(`.map`, `.or`, `.then`, etc.). Self is move-only by default; combinator
wrappers are move-only structs. Parser instances are constructed once,
typically by reference (`&p`) or via cloning when needed. The trait
design is **exactly** what Option α would produce in Swift —
specifically because Rust's protocol-Self default IS move-only.

**Contextualization per [RES-021]**: Rust's parser libraries adopt
move-only-first Self semantics because **Rust's protocol-Self default
IS move-only**, not because parser-combinator semantics specifically
benefit from move-only Self. Translating this to Swift is the
**universal-adoption-does-not-imply-universal-necessity** anti-pattern
that [RES-021] warns against: the Rust ecosystem inherits move-only
defaults from Rust's type system, not from parser-domain requirements.
Swift's default protocol-Self IS Copyable. Aligning Swift with Rust
here would invert Swift's default for the entire parser-stack
ecosystem to match a property Rust gets for free. The cost is one-
ecosystem-deep; the benefit is conformity to a pattern Rust did not
choose deliberately.

#### Haskell ecosystem (purity, laziness, monads)

**parsec**: `data Parsec s u a` — a type, not a class. The "parser"
*type* is a monad transformer over Stream and State. Move/copy isn't
a relevant axis in Haskell because all values are immutable; lazy
evaluation handles "stateful" composition without explicit
ownership annotations. There is no analog to the "Self: ~Copyable"
question.

**megaparsec**: `class Stream s m t => MonadParsec e s m | m -> e s t`.
Self is "the monad" — an instance of a typeclass over Stream and Error.
Same as parsec: Haskell's value semantics make move/copy a non-axis.

**Contextualization**: Haskell informs the *algebraic structure* of
parser combinators (functor, alternative, monad — captured in
`swift-institute/Research/parser-combinator-algebraic-foundations.md`)
but provides NO precedent for Self ownership discipline because
Haskell doesn't have ownership in the Rust / Swift sense.

#### Swift ecosystem

**pointfreeco/swift-parsing**: `protocol Parser<Input, Output>` —
Self: Copyable (implicit), Input: Collection (Copyable element). No
~Copyable adoption; the library predates SE-0427. Per
`parser-syntax-ergonomics-comparison.md`, the institute's
`Parser.`Protocol`` is **architecturally stronger** (typed throws,
~Copyable Input support) than swift-parsing, but syntactically heavier
in some idioms. swift-parsing's design provides NO ~Copyable Self
precedent — confirms the absence of upstream demand.

#### Swift Evolution proposals

- **SE-0390 Noncopyable structs and enums**: introduces `~Copyable`
  for nominal types.
- **SE-0427 Noncopyable Generics**: introduces `~Copyable` for
  generic / protocol Self.
- **SE-0432 Borrowing and consuming pattern matching for noncopyable types**:
  `switch consume value { case … }` discipline.
- **SE-0437 Noncopyable Standard Library Primitives**: Optional, Result
  as `~Copyable`-able.
- **SE-0497 Closures capturing noncopyable types** (status: in
  review at time of this writing per Swift Evolution corpus): would
  unblock closure-capture for Lazy / OneOf.Any. Until SE-0497 ships,
  the Option α cascade is materially worse than projected here.
- **SE-0499 Support `~Copyable` and `~Escapable` in Standard Library
  Protocols**: brings Hashable / Equatable / Comparable to ~Copyable.
  Not directly relevant to `Parser.`Protocol`` (institute-owned), but
  relevant precedent for "the stdlib is gradually unblocking ~Copyable
  protocols."

**No SE proposal currently pitches the equivalent of "protocols should
be authored as `Self: ~Copyable` when their semantic content permits."**
The Swift Evolution direction has been *unblocking* `~Copyable`
incrementally (SE-0427 made it possible; SE-0499 unblocks stdlib
protocols), NOT *advocating* protocol-Self relaxation pre-emptively.

#### Systematic literature review (per [RES-023] Kitchenham methodology)

Research questions:

1. **Does parser-combinator design benefit from move-only Self
   semantics?** Inclusion criteria: peer-reviewed papers, library
   documentation, language design retrospectives addressing parser-
   combinator ownership.
2. **In ecosystems with move-only-first defaults (Rust), is the move-
   only Parser shape adopted deliberately or inherited?** Inclusion:
   library design docs, comparative analyses.

Sources screened:

| Source | Relevance | Finding |
|---|---|---|
| Hutton & Meijer, "Monadic Parser Combinators" (1996) | Foundational | Self is a monad value; ownership not addressed. |
| Leijen & Meijer, "Parsec: Direct Style Monadic Parser Combinators" (2001) | Foundational | Haskell value semantics; no ownership analog. |
| Krishnaswami & Yallop, "A Typed, Algebraic Approach to Parsing" (PLDI 2019) | Algebraic structure | Operational semantics for parsers; ownership not addressed. |
| Couprie, nom design docs (2015–) | Library design | Function-based; ownership inherited from Rust function call semantics. |
| Westerlind, combine design docs (2015–) | Library design | `&mut self` discipline; inherits Rust's move-only default. |
| Barretto, chumsky design notes (2021–) | Library design | Self move-only by default (Rust); no design rationale tying parser semantics to move-only Self specifically. |
| Williams & Celis, swift-parsing v0.13 (2020–) | Library design | Self: Copyable (Swift default); no `~Copyable` precedent. |
| `swift-institute/Research/parser-combinator-algebraic-foundations.md` | Internal | Algebraic-structure framing; ownership orthogonal. |

**Conclusion of the SLR**: across the surveyed corpus, *no parser-
combinator library adopts move-only Self because parser-combinator
semantics demand it.* Rust libraries adopt move-only Self because Rust
defaults are move-only. Haskell libraries don't have the question.
Swift-parsing keeps Copyable Self because Swift defaults are Copyable.
Adopting move-only Self in Swift's parser-combinator stack would be
**inverting Swift's default to align with a property Rust gets for
free** — not adopting a feature parser-combinator semantics
intrinsically demand.

### F. Formal Semantics per [RES-024]

#### Typing rules

Let `Π` denote the proposed protocol `Parser.`Protocol``. The current
authoring is:

```
Π ≜ protocol { 
  associatedtype Input : ~Copyable, ~Escapable
  associatedtype Output
  associatedtype Failure : Swift.Error
  associatedtype Body
  var body : Body { get }
  func parse(_ : inout Input) throws(Failure) -> Output
}
```

Implicit (default): `Self : Copyable, Escapable` on the protocol.

Option α modifies the implicit Self constraints to:

```
Π_α ≜ protocol : ~Copyable { 
  …  (rest unchanged)
}
```

The typing rule for protocol conformance changes:

- **Status quo (Π)**: `Γ ⊢ T : Π` requires `Γ ⊢ T : Copyable`.
- **Option α (Π_α)**: `Γ ⊢ T : Π_α` does NOT require `Γ ⊢ T : Copyable`.
  `T` may be either `Copyable` or `~Copyable`.

For a wrapper `W<U : Π_α> = struct { let u : U; … }`, the wrapper's
Copyable disposition is:

- If `U : Copyable`, then `W<U> : Copyable` (default).
- If `U : ~Copyable`, then `W<U> : ~Copyable` (must be explicitly
  `: ~Copyable`).

The wrapper cannot be `Copyable` while storing a `~Copyable U` —
this is the **cascade rule**.

#### Operational semantics (sketch)

For a combinator `let p = Map<U, O>(upstream: u, transform: f)`:

Under Π (status quo): `p` is a Copyable value; `let p2 = p` creates a
copy; both `p.parse(&input)` and `p2.parse(&input)` work with their
own captured `upstream`. No aliasing of mutable state (since `upstream:
U` is itself a Copyable value, copies are independent).

Under Π_α: if `U : ~Copyable`, then `p : ~Copyable` (cascade); `let p2 = p`
is **consume**, not copy. `p` is moved into `p2`; further use of `p` is
a compile error.

For the audit's Row 11 case `Parser.Machine.Compiled<P>: ~Copyable`
(under Π_α):
- `let c1 = parser.compiled(...)` constructs a `Compiled` with its
  own `Cache`.
- `let c2 = c1` is **consume**; `c1.parse(&input)` is then a compile
  error. Result: aliasing of `c1.cache.compiled` and `c2.cache.compiled`
  is **prevented at compile time** — the audit's Row 11 motivation.

For a Copyable terminal type wrapping a Π_α conformer (e.g., the
sibling-type workaround under Option δ): the Copyable terminal stores
a `~Copyable` parser internally and provides its own copy semantics
explicitly — same architectural pattern as `Path_Primitives.Path`
(`~Copyable`) wrapped by `Paths.Path` (Copyable).

#### Soundness argument

Option α is type-sound (Swift's type system enforces the cascade
mechanically). Cascade is not a soundness concern but a **shape**
concern: the type system correctly propagates `~Copyable` through
wrappers; the question is whether the resulting shape is
ergonomically usable across the 166-site surface.

The witness-table SIGSEGV (`swiftlang/swift#85441` pattern) is a
**runtime** unsoundness — a verified compiler bug, not a design flaw.
But it is operationally relevant: under Option α, the bug's
exploitability surface multiplies by the cross-module cascade.

### G. Empirical Validation per [RES-025]

Per [RES-025], for API-facing decisions, Tier-2 + research SHOULD
include Cognitive Dimensions Framework evaluation. This Tier-3 doc
inherits and extends:

| Dimension | Option α evaluation |
|---|---|
| **Visibility** | The cascade is hidden behind the protocol declaration; consumers see the wrapper types' explicit constraint surface. Cognitive load HIGH at every combinator definition site (must reason about whether wrapper inherits `~Copyable` or constrains to `Copyable`). |
| **Consistency** | The pattern inverts the existing ecosystem default (parsers stored as fields throughout). Inconsistency between parser stack (Option α) and rest of ecosystem (Copyable-Self protocols) HIGH. |
| **Viscosity** | Adoption is high-cost (166 sites + ~30 builder generics + closure-capture re-shaping). Reversion is high-cost (every conformer's `: ~Copyable` declaration must be reverted; opposite cascade). |
| **Role-expressiveness** | "Self is ~Copyable" signals "this parser instance owns a resource" — but 164 of 166 conformers don't own resources. The signal is misleading for the majority. |
| **Error-proneness** | High. The cascade interacts with closure capture (Lazy, OneOf.Any), result builders, and stdlib container storage. Each interaction is a potential foot-gun for consumers. |
| **Abstraction** | The change abstracts up at the protocol level (one declaration changes; ~166 conformer sites change with it). High-leverage but high-blast-radius. |

For Option δ:

| Dimension | Option δ evaluation |
|---|---|
| **Visibility** | The protocol shape is preserved; Row 11 workaround surfaces a clearly-named sibling type (`Parser.Machine.Compiled.Owned` or similar) at the call site for consumers who want ~Copyable semantics. |
| **Consistency** | Matches the L1-~Copyable / L3-Copyable bifurcation already established for `Path_Primitives.Path` / `Paths.Path`. |
| **Viscosity** | Low adoption cost (one or two new types; no cascade). Reversion: trivially preserved (no shape change to protocol). |
| **Role-expressiveness** | The `Parser.Machine.Compiled.Owned : ~Copyable` type signals "single-owner cache" explicitly without forcing the signal across the rest of the protocol. |
| **Error-proneness** | Low. Consumer who wants ~Copyable semantics opts in by-type-name; consumer who doesn't gets the protocol-typed compositional surface. |
| **Abstraction** | Low-leverage but low-blast-radius. Targeted to the audit's Row 11 motivation. |

---

## Outcome

**Status**: RECOMMENDATION (Tier-3).

### Recommended option: δ — Defer indefinitely; offer a sibling-type workaround for Row 11

**Rationale**:

1. **Six-axis score 5/30 for Option α is decisively below the v1.2.0
   adoption threshold (Wave-5 Row 1: 25/30; Wave-6 Row 2: 20/30).** The
   protocol-level `~Copyable` carries weak resource-correlation (the
   resource is in ONE type, not the protocol), weak safety-bug-class
   payback (the bug class exists only at Row 11), and a 5/5 cascade
   cost across 166 conformer sites + builder generics + closure-
   capture surface + the verified witness-table SIGSEGV (`swiftlang/
   swift#85441` pattern).

2. **Option β (~Escapable Self) is structurally untenable** — 0/30
   floored from −3. ~Escapable Self is categorically wrong for a
   description/witness type. The Parser.Tracked / Parser.Span Input
   wrappers correctly use ~Escapable on *Input*; the same does not
   apply to *Self*.

3. **Option γ is the same cascade with a less defensible invariant.**
   The "combinators stay Copyable by convention" rule is not type-
   system-enforced; it would degrade over time as new combinators are
   added. Marginal score improvement (6/30) does not change the
   verdict.

4. **Prior art per [RES-021] does NOT support universal
   adoption-implies-necessity.** Rust parser libraries adopt move-only
   Self because **Rust's defaults are move-only**, not because parser-
   combinator semantics demand it. The contextualization step per
   [RES-021] surfaces: Swift's Copyable-Self default is not a gap to be
   filled; it is a deliberate alignment with Swift's broader protocol-
   Self conventions.

5. **Audit Q1 deferral stands and is reinforced.** The ecosystem-corners
   audit deferred Q1 pending a second consumer per [RES-018]. This
   Tier-3 analysis confirms: there is no second consumer. The Machine.*
   family's Row 11 (`Compiled`) is the lone parser-stack consumer
   wanting `~Copyable` semantics; everything else in the family is
   internal (Builder, already ~Copyable) or shares the same single use
   case (Prepared, deliberately Copyable for cross-task sharing).

6. **The L1-~Copyable / L3-Copyable bifurcation already in the
   ecosystem (Path / Paths.Path; Kernel.Thread.Handle / Kernel.Thread.
   Handle.Reference; Parser.Machine.Compiled / Parser.Machine.Prepared)
   IS the canonical pattern.** Option δ's sibling-type workaround
   (`Parser.Machine.Compiled.Owned : ~Copyable`, NOT conforming to
   `Parser.`Protocol``, consumed directly) preserves the resource-
   correlation win for the one consumer without forcing the protocol
   to invert its conventions.

### Sibling-type workaround for Row 11 (concrete shape under Option δ)

Add a sibling type to `Parser.Machine`:

```swift
extension Parser.Machine {
    /// Single-owner compiled wrapper.
    /// 
    /// Use when the cache must be uniquely owned (e.g., a single-isolation-
    /// domain parse pipeline). For protocol-typed composition (`some
    /// Parser.\`Protocol\`<…>` slots), use `Parser.Machine.Compiled`
    /// (Copyable), which trades single-ownership documentation for
    /// composability.
    public struct OwnedCompiled<P: Parser.\`Protocol\`>: ~Copyable
    where
        P.Input: Parser.Input.\`Protocol\`,
        P.Failure: Swift.Error
    {
        @usableFromInline let source: P
        @usableFromInline let witness: Compile.Witness<P>
        @usableFromInline var cache: Cache  // structural change: cache as inout-mutable struct, or final-class with consume-discipline
        
        public consuming func parse(_ input: inout P.Input) throws(P.Failure) -> P.Output {
            // single-owner parse implementation; consumes self
        }
        
        public consuming func prepared() -> Parser.Machine.Prepared<P> {
            // single-owner prepared() implementation; consumes self
        }
    }
}
```

This type:

- Does NOT conform to `Parser.`Protocol`` — avoids the protocol-level
  cascade entirely.
- IS `~Copyable` — closes the audit's Row 11 (c)-3 bug class at compile
  time for callers who opt in.
- Offers a consuming `prepared()` to transition to the immutable
  shared variant — preserving the architectural Compiled/Prepared
  bifurcation.
- Calling sites that need protocol-typed composition continue to use
  the Copyable `Parser.Machine.Compiled` (no behavior change for
  existing code).

### Highest-information first step (IF the recommendation is reconsidered)

If, in the future, a second parser-stack consumer surfaces with
strong borrow-by-default needs (e.g., a stateful streaming parser
with a connection handle in Self, or a memory-mapped Binary parser
with mmap region ownership in Self), and reconsideration of Options
α / γ is warranted, the highest-information first step is:

**Spike Parser.Fail as an Option α proof-of-shape.**

Parser.Fail is the simplest leaf parser:

```swift
public struct Fail<Input, Output, F: Swift.Error>: Sendable {
    let error: F
    public init(_ error: F) { self.error = error }
}
extension Parser.Fail: Parser.`Protocol` { … }
```

It has:
- No stored `Parser.`Protocol`` field (so no upward cascade).
- A simple `Sendable` constraint.
- A single error stored property.
- Conforms to `Parser.`Protocol`` directly.
- Is named in the brief as a candidate.

Spike steps:

1. Change `Parser.`Protocol`` to `: ~Copyable` on its declaration.
2. Add `: ~Copyable` to `Parser.Fail` and verify it still compiles in
   isolation.
3. Build the package in 6.4-dev nightly.
4. If the build succeeds, compose `Parser.Fail` into a `Parser.Map.Transform`
   (the simplest single-parser combinator) in a cross-module consumer
   (e.g., a test target in another package). This exercises the witness-
   table SIGSEGV surface for the smallest combinator shape.
5. If the spike runs cleanly without SIGSEGV, the witness-table bug
   is partially relaxed and the analysis can be re-opened. If it
   crashes, δ remains irrefutable.

Spike scope: ~30 lines of edits + one cross-module test target. Cost:
≤ 2 hours. Information-yield: validates / invalidates the most cost-
dominating axis (cascade cost (d), specifically the witness-table SIGSEGV
contribution).

### Re-evaluation triggers

Option δ should be revisited if:

1. A second parser-stack consumer (beyond `Parser.Machine.Compiled`)
   surfaces with strong borrow-by-default needs ([RES-018] second-
   consumer hurdle).
2. The witness-table SIGSEGV (`swiftlang/swift#85441` pattern) is
   fixed upstream and re-verified against the ecosystem's cross-module
   surface.
3. SE-0497 (closure-capture for ~Copyable) ships and the Lazy /
   OneOf.Any cascade is materially de-risked.
4. The ecosystem authors a new parser package whose primary type IS
   resource-correlated (e.g., a kernel-level network parser whose
   parser instance owns a socket descriptor).

In the absence of any of these, the recommendation stands.

---

## Open Questions

| # | Question | Status | Resolution path |
|---|---|---|---|
| Q1 | Is the proposed `Parser.Machine.OwnedCompiled` sibling type the right shape for Row 11 adoption under Option δ, or is a different shape preferable (e.g., `extension Parser.Machine.Compiled where Self: …`)? | DEFERRED. The naming + exact API surface is a per-package detail; the architectural pattern (sibling ~Copyable type not conforming to the protocol) is the recommendation. | Resolve at Row 11 adoption time. |
| Q2 | If SE-0497 (closure-capture for ~Copyable) ships, does the Lazy / OneOf.Any cascade collapse enough to re-open the analysis? | DEFERRED. The witness-table SIGSEGV remains the dominant cost; SE-0497 addresses a different axis (closure-capture, axis (d)). Both would need to land for material re-opening. | Re-evaluate when both SE-0497 ships AND `swiftlang/swift#85441` is fixed. |
| Q3 | Should `Parser.Printer` (the sibling protocol at `Parser.Printer.swift:46`) also be re-evaluated as part of any future Option α reconsideration? | YES (downstream consequence). `Parser.Printer` shares the `Self: Copyable` (implicit) shape with `Parser.`Protocol``. Any future relaxation should apply symmetrically. | Couple any reconsideration to a `Parser.Printer` parallel analysis. |
| Q4 | Does the Machine.* family's `Parser.Machine.Builder<Input, Failure>: ~Copyable` (at Machine.swift:71) serve as evidence that a partial `~Copyable` adoption is viable in the parser stack? | RESOLVED INLINE. Yes for the Builder (which doesn't conform to Parser.`Protocol`). The pattern is "Builder is `~Copyable`, executor wrappers Conform-as-Copyable" — exactly what Option δ recommends preserving for the protocol-level shape. | No further action. |
| Q5 | Are there ASCII / Binary parser-primitives consumers (e.g., `Binary.Parse.Access<P>`) that suggest a second consumer is imminent? | INSUFFICIENT EVIDENCE. The 8 binary-parser-primitives conformers + 2 ASCII-parser-primitives conformers are leaf-shape and combinator-shape; none are resource-correlated. The `Binary.Bytes.Input.View` is a borrowed-Input shape, but it's an Input, not a Self. | Watch for new Binary / ASCII consumer arc; re-survey if one lands. |

---

## References

### Internal research (per [RES-019] step-0 grep)

- `swift-institute/Research/2026-05-13-noncopyable-adoption-ecosystem-corners-audit.md` v1.0.0 RECOMMENDATION (2026-05-13) — Row 11 + Q1 deferral; **direct predecessor**
- `swift-institute/Research/2026-05-13-noncopyable-adoption-targets-ecosystem-survey.md` v1.2.0 RECOMMENDATION (2026-05-13) — six-axis framework predecessor
- `swift-institute/Research/se-0499-implications-for-equation-hash-comparison-primitives.md` v1.3.0 RECOMMENDATION (2026-05-03) — SE-0499 implications
- `swift-institute/Research/noncopyable-ecosystem-state.md` v1.0.0 DECISION (2026-04-02) — canonical state-of-ecosystem
- `swift-primitives/swift-parser-primitives/Research/witness-table-sigsegv-with-noncopyable-protocol-constraints.md` v1.0.0 DECISION (2026-02-14) — **critical compiler-bug evidence**
- `swift-foundations/swift-parsers/Research/parser-input-noncopyable-support.md` v1.0.0 DECISION (2026-03-16) — direct precedent for Input cascade
- `swift-primitives/swift-parser-machine-primitives/Research/machine-noncopyable-input.md` v1.0.0 DECISION (2026-02-24) — Machine.* internals ~Copyable cascade
- `swift-institute/Research/parser-combinator-algebraic-foundations.md` RECOMMENDATION — algebraic-structure framing
- `swift-institute/Research/parser-bridge-architecture.md` — partial-Copyable patterns at Input axis
- `swift-institute/Research/parser-syntax-ergonomics-comparison.md` RECOMMENDATION (2026-03-05) — comparison vs pointfreeco/swift-parsing
- `swift-institute/Research/path-type-ecosystem-model.md` (2026-04-18) — L3-Copyable / L1-~Copyable bifurcation reference architectural shape

### Source files (verified 2026-05-13)

- `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift:90` — `Parser.`Protocol`` declaration; `Input: ~Copyable & ~Escapable` at line 95
- `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parser.Printer.swift:46` — `Parser.Printer` declaration; same shape as `Parser.`Protocol``
- `swift-primitives/swift-parser-primitives/Sources/Parser Span Primitives/Parser.Span.swift:48` — `extension Parser.`Protocol` where Input: Parser.Input.`Protocol` & Copyable` constraint
- `swift-primitives/swift-parser-machine-primitives/Sources/Parser Machine Core Primitives/Parser.Machine.swift:71` — `Parser.Machine.Builder<Input, Failure>: ~Copyable`
- `swift-primitives/swift-parser-machine-primitives/Sources/Parser Machine Compile Primitives/Parser.Machine.Compiled.swift:37` — `Parser.Machine.Compiled<P>` Row 11 candidate
- `swift-primitives/swift-parser-machine-primitives/Sources/Parser Machine Compile Primitives/Parser.Machine.Prepared.swift:40` — `Parser.Machine.Prepared<P>` Row 12
- `swift-foundations/swift-parsers/Sources/Parsers/Parsers.Chain.swift`, `Parsers.Expression.swift`, `Parsers.Separated.swift` — Foundations combinators with `where Input: Copyable` constraints (precedent pattern)

### Swift Evolution proposals

- [SE-0390 Noncopyable structs and enums](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md) — base `~Copyable` introduction
- [SE-0427 Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md) — protocol-Self `~Copyable`
- [SE-0432 Borrowing and consuming pattern matching for noncopyable types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0432-noncopyable-switch.md) — `switch consume` discipline
- [SE-0437 Noncopyable Standard Library Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md) — Optional / Result `~Copyable`
- [SE-0497 Closures capturing noncopyable types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0497-closures-capturing-noncopyable.md) — closure capture for `~Copyable`
- [SE-0499 Support `~Copyable` and `~Escapable` in Standard Library Protocols](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md) — stdlib protocol relaxation

### External prior art

- [nom (Rust)](https://github.com/rust-bakery/nom) — function-based combinator library; no Parser trait
- [combine (Rust)](https://github.com/Marwes/combine) — `trait Parser` with `&mut self` discipline
- [chumsky (Rust)](https://github.com/zesterer/chumsky) — `trait Parser` move-only Self by Rust default
- [parsec (Haskell)](https://hackage.haskell.org/package/parsec) — monadic value-semantics; no ownership axis
- [megaparsec (Haskell)](https://hackage.haskell.org/package/megaparsec) — typeclass-based; no ownership axis
- [pointfreeco/swift-parsing](https://github.com/pointfreeco/swift-parsing) — Swift Self: Copyable; no `~Copyable` precedent
- Hutton & Meijer (1996), "Monadic Parser Combinators" — foundational design rationale (ownership not addressed)
- Krishnaswami & Yallop (2019), "A Typed, Algebraic Approach to Parsing" (PLDI 2019) — algebraic foundations (ownership orthogonal)

### Skill requirements

- [MEM-COPY-001] / [MEM-COPY-001a] — noncopyable type declaration + deinit immutability
- [MEM-COPY-004] — extension constraints for `~Copyable` types
- [MEM-COPY-005] — nested accessor pattern incompatibility
- [MEM-COPY-006] — `~Copyable` propagation gotchas
- [MEM-COPY-014] — native ownership for resource types
- [MEM-OWN-010] / [MEM-OWN-011] / [MEM-OWN-012] — three canonical transfer patterns
- [MEM-LINEAR-001] / [MEM-LINEAR-002] — exactly-once / at-most-once types
- [IMPL-070] — Layer 0/1/2 model
- [RES-018] — premature primitive anti-pattern (second-consumer check)
- [RES-019] — step-0 internal research grep (applied above)
- [RES-020] — research tiers; this doc is Tier 3 per ecosystem-wide scope + foundational semantic commitment
- [RES-021] — prior art survey + contextualization step (universal-adoption ≠ universal-necessity)
- [RES-022] — theoretical grounding
- [RES-023] — systematic literature review (Kitchenham methodology) — applied above
- [RES-024] — formal semantics — applied above
- [RES-025] — empirical validation (Cognitive Dimensions Framework) — applied above
- [HANDOFF-013] — prior research check (applied above)
- [HANDOFF-019] — commit-as-you-go (per dispatch instruction)
