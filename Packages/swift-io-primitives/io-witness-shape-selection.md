# IO Witness Shape Selection

> **Subordinated to** `../../../swift-foundations/swift-io/Research/swift-io-thesis.md` v2.0 (2026-04-20):
> the thesis reframes Shape F as the *direct/dictionary encoding* of
> swift-io. The selection of Shape F stands; "two encodings co-equal"
> framing in earlier drafts is superseded — only the dictionary encoding
> is in current code.
>
> **Cross-package note (2026-04-20)**: this document was moved from
> `swift-foundations/swift-io/Research/` to
> `swift-primitives/swift-io-primitives/Research/`. Frontmatter paths
> are now true relative paths.

<!--
---
version: 1.0.0
created: 2026-04-17
last_updated: 2026-04-20
status: DECISION
tier: 3
scope: swift-io + downstream consumers (swift-sockets, swift-file-system,
       swift-io-primitives scaffold)
supersedes: none
supersededBy: none
related:
  - ../../../swift-foundations/Research/io-witness-shape-zoo-comparative-analysis.md
  - io-witness-shape-zoo-addendum.md
  - io-witness-capability-runner-split.md
  - io-witness-design-literature-study.md
  - ../../../swift-foundations/swift-executors/Research/io-blocking-executor-binding.md
  - ../../../swift-foundations/swift-io/Research/perfect-api.md
  - ../../../swift-foundations/Research/io-vs-nio-comparative-analysis.md
  - ../../../swift-foundations/Research/nio-inspired-capability-additions.md
  - ../Experiments/io-witness-shape-f/
  - ../Experiments/io-witness-domain-via-map/
  - ../Experiments/io-witness-generic-error/
  - ../Experiments/io-witness-tokio-style/
  - ../Experiments/io-witness-zio-style/
  - ../Experiments/io-witness-eio-style/
  - ../Experiments/io-witness-monoio-style/
  - ../Experiments/io-witness-generic-ops/
  - ../Experiments/io-witness-domain-generic-substrate/
  - ../Experiments/io-witness-macro-generic-compat/
  - ../Experiments/witness-mock-borrowing/
  - ../Experiments/witness-recording-against-properties/
  - ../Experiments/witness-maperror-sending-return/
---
-->

## Abstract

This document selects swift-io's canonical witness shape from the ten
candidates enumerated and analysed in the parent Tier 3 comparative analysis
[io-witness-shape-zoo-comparative-analysis.md](../../../swift-foundations/Research/io-witness-shape-zoo-comparative-analysis.md)
and narrowed by the [io-witness-shape-zoo-addendum.md](io-witness-shape-zoo-addendum.md).
Per [RES-006] this is a DECISION document: a single shape is picked,
rationale is documented, implementation path is given, and downstream ripples
are enumerated.

**The winning shape is Shape F — the capability + runner split bundled by a
plain `IO.Bound` struct — adopted in its non-generic-error form (flat
`IO.Error`) with Shape Dvm (`.map`) as the chosen mechanism for domain
witness derivation (Socket.IO, File.IO) and Shape MG kept in reserve as a
tooling enabler (macro-generic compatibility) for any later adoption of a
generic-error extension**. Shape F wins on four load-bearing criteria: it is
the only non-eliminated shape that simultaneously (i) preserves the
capability axiom at the type level, (ii) composes with every `Witness.*`
operator uniformly, (iii) gives the shared-executor / shutdown concerns a
canonical typed home, and (iv) avoids generic parameters on the public
consumer surface. The cost is a two-dot access pattern at consumer sites
(`bound.io.read(...)`, `bound.runner.executor()`) and a non-trivial migration
of swift-io's existing Shape B code (one capability witness with
`unownedExecutor` bundled alongside the operations).

Eliminated shapes with one-line reasons: **GO** (redundant with Dvm), **DGS**
(strictly inferior to Dvm), **Z** (no executor-binding story — violates C4
of the capability-runner criteria), **E** (compounding `sending`-tax at each
scope boundary, subsumed by value-type capability passing), **M** (rental
ergonomics and the Swift 6.3 tuple-~Copyable / region-checker rebind limits),
and **Tk** (per-capability split — rejected as primary because swift-sockets
consumers invariably need read + write + close together, and the 106.98s
cold build cost scales badly with more witnesses). **MG** is kept as a
tooling property. **Dvm** is adopted as the domain-composition primitive
alongside F, not as an alternative. **GE** is deferred with explicit trigger
conditions.

Migration from current Shape B touches approximately **18 files** across
`swift-io/Sources/`, **8 files** in `swift-sockets/Sources/`, **18 call
sites** in `swift-file-system/Sources/`, and **4 call sites** in
`swift-tests/`. The migration is mechanical: one new target (`IO Bound`),
factory return types widen from `IO` to `IO.Bound`, consumer stored
properties widen analogously, and the existing `io.unownedExecutor()` call
becomes `bound.runner.executor()`. Shape F's adoption is compatible with the
Tier 0 `IO.run` perfect-API; `IO.run` is the entry point and constructs an
`IO.Bound` internally.

## 1. Decision Statement

**Adopt Shape F** — two `@Witness` structs (`IO` and `IO.Runner`) bundled by
a plain `IO.Bound` struct — as swift-io's canonical witness shape.

```swift
// The capability witness: pure I/O operations.
@Witness
public struct IO: Sendable {
    public let read:  @Sendable (_ from: borrowing Kernel.Descriptor,
                                 _ into: Memory.Buffer.Mutable)
                                 async throws(IO.Error) -> Int
    public let write: @Sendable (_ to:   borrowing Kernel.Descriptor,
                                 _ from: Memory.Buffer)
                                 async throws(IO.Error) -> Int
    public let close: @Sendable (consuming Kernel.Descriptor) async -> Void
    public let ready: @Sendable (_ from: borrowing Kernel.Descriptor,
                                 _ interest: Kernel.Event.Interest)
                                 async throws(IO.Error) -> Void
}

extension IO {
    @Witness
    public struct Runner: Sendable {
        public let executor: @Sendable () -> UnownedSerialExecutor
        public let shutdown: @Sendable () async -> Void
    }

    public struct Bound: Sendable {
        public let io: IO
        public let runner: IO.Runner
        public init(io: IO, runner: IO.Runner) {
            self.io = io
            self.runner = runner
        }
    }
}
```

## 2. Context

### 2.1 Why this decision is being made now

Three streams of prior work converge here:

1. **The design literature study**
   ([io-witness-design-literature-study.md](io-witness-design-literature-study.md)
   v4.0) established Shape B — a single `@Witness public struct IO` with
   five closures including `unownedExecutor` — as the working baseline. The
   study acknowledged (lines 394–396) that the capability axiom
   (Brachthäuser 2020) would ideally keep executor state off the capability
   witness, but accepted the deviation for ergonomic single-value consumer
   handoff.
2. **The capability–runner split proposal**
   ([io-witness-capability-runner-split.md](io-witness-capability-runner-split.md))
   re-opened the question, scored three options on six criteria, and
   recommended Option F (81 weighted vs. 71 for G and 68 for B). Status:
   RECOMMENDATION, not DECISION.
3. **The ten-shape zoo**
   ([io-witness-shape-zoo-comparative-analysis.md](../../../swift-foundations/Research/io-witness-shape-zoo-comparative-analysis.md))
   widened the aperture to ten candidate shapes and executed ten compile-
   verified experiments in `swift-primitives/Experiments/io-witness-*/`.
   Status: IN_PROGRESS at authorship of this document. The zoo itself
   deferred the final pick to this selection document (§1.4).

Additionally, the
[io-witness-shape-zoo-addendum.md](io-witness-shape-zoo-addendum.md) pinned
four open unknowns from the parent analysis §6, turning three from "open"
into "resolved" or "pinned":

- §6.9 (zero-parameter `@Witness` closures) — **resolved as intentional**.
  The macro's V5 collision class means property-as-call (`prop()`) is the
  canonical convention.
- §6.8 (`mapError` region inheritance) — **confirmed-still-open**;
  intrinsic to Swift 6.3 region analysis, not a macro concern.
- Mock generation with `borrowing`/`consuming` `~Copyable` — **refuted
  unexpectedly**; Swift 6.3 now propagates ownership through `(_, _)`
  placeholders, so `@Witness(.mock)` works on IO-shaped witnesses.
- §6.4 (tuples of `~Copyable`) — unchanged Swift language limit.

With the zoo data complete, the three open unknowns pinned, and swift-io's
production code currently compiling under Shape B with an acknowledged
aspirational deviation, the selection must happen now: each delayed
iteration on swift-sockets Phase 3, swift-file-system, and
swift-io-primitives (empty scaffold) carries the Shape B dilution forward.

### 2.2 What was produced before this document

| Artefact | Status | Purpose |
|----------|--------|---------|
| `swift-io/Sources/IO Core/IO.swift` | Shape B in production | Baseline; current `@Witness public struct IO` with `read`/`write`/`close`/`ready`/`unownedExecutor` |
| `io-witness-design-literature-study.md` v4.0 | RECOMMENDATION | Shape B's theoretical grounding (Brachthäuser, Ahman & Bauer, Xie & Leijen, Schuster et al.) |
| `io-blocking-executor-binding.md` v4.0 | RECOMMENDATION | Shared-executor pattern (TCA26); mandatory binding via actor isolation |
| `io-witness-capability-runner-split.md` v1.0 | RECOMMENDATION | Option F proposal (81 vs. 71 vs. 68) |
| `perfect-api.md` v3.0 | RECOMMENDATION | Tier 0 `IO.run` consumer entry point |
| `io-vs-nio-comparative-analysis.md` v1.0 | COMPLETE | Structural comparison with swift-nio |
| `nio-inspired-capability-additions.md` v1.0 | RECOMMENDATION | P0/P1/P2 capability gaps (shutdown, fakes, deadlines, vectored I/O) |
| `io-witness-shape-zoo-comparative-analysis.md` | IN_PROGRESS (parent) | 4318 lines, ten shapes, systematic literature review |
| `io-witness-shape-zoo-addendum.md` | RECOMMENDATION | 674 lines; Phase 2 findings, macro convention change, zoo migration |
| Ten sketches in `swift-primitives/Experiments/io-witness-*/` | CONFIRMED (compile) | Compile evidence per shape |
| Three Phase 2 experiments in `swift-io/Experiments/witness-*/` | CONFIRMED / REFUTED | Pin open §6 unknowns |

### 2.3 The ten candidates — one-line summary each

| ID | Name | Summary |
|----|------|---------|
| F | Capability + Runner split | Two `@Witness` structs (`IO`, `IO.Runner`) bundled by plain `IO.Bound`. Original; Brachthäuser capability + Ahman–Bauer runner. |
| Dvm | Domain via `.map` | `extension IO { func map<Domain>(_ t: (IO) -> Domain) -> Domain }` builds `Socket.IO`, `File.IO` from a base. No generic virality. |
| MG | Macro Generic Compatibility | Tooling verification that `@Witness` propagates generics into synthesised members. |
| GE | Generic Error | `IO<LeafError: Error>` with `throws(LeafError)` on each closure plus `mapError`. |
| GO | Generic Ops | `IO<Ops>` envelope; the `Ops` record holds the closures. High virality. |
| DGS | Domain Generic Substrate | `Socket.IO<Substrate>` — generic over the base IO plus explicit projection closures. |
| Tk | Tokio-style Reader/Writer/Closer | Three separate `@Witness` structs plus a `Duplex` bundle. |
| Z | ZIO-style `IO<R, E, A>` | Three-parameter effect monad with `map`/`flatMap`/`mapError`/`provide`. |
| E | Eio-style `Stdenv` + scope | Nested sub-capabilities + `Eio.with(stdenv:_:)` scope function. |
| M | monoio-style rental | `consuming Buffer` + `(Buffer, Int)` return; re-bind loop. |

### 2.4 Constraints

**Hard constraints** (violations eliminate the shape):

1. **No protocols at public surface**. Witnesses only.
2. **No existentials**. No `any Runner`, no `any IOCapability`.
3. **`~Copyable` Kernel.Descriptor support**. `borrowing` on read/write/ready,
   `consuming` on close.
4. **Typed throws end-to-end**. `throws(IO.Error)`, no `throws(any Error)`.
5. **Region-based isolation preferred over `Sendable` constraints**. Use
   `sending` on parameters and returns; do not add `Sendable` constraints on
   generic parameters unless no alternative exists.
6. **Swift 6.3 release toolchain compile**. Compatible with Swift 6.3's
   region-isolation checker, `NonisolatedNonsendingByDefault`, and strict
   memory safety.
7. **Shared-executor pattern (TCA26) must remain single-line on the
   consumer**. The consumer's `unownedExecutor` accessor forwards from the
   witness without ceremony.
8. **Strict memory safety enabled**. `.strictMemorySafety()` flag across
   targets.

**Soft constraints** (influence weight but do not eliminate):

- **Shape B migration churn minimised**. Constant, not zero — Shape B is
  explicitly being changed.
- **swift-witnesses composition operators apply uniformly**. `Witness.Recording`,
  `Witness.Scope`, `Witness.Values`, `Witness.Sequence`, `Witness.Cycle`.
- **P0/P1/P2 from
  [nio-inspired-capability-additions.md](../../Research/nio-inspired-capability-additions.md)
  have a canonical home**. Shutdown, test fakes, deadlines, vectored I/O.
- **Build-time cost of `@Witness` macro expansion is acceptable**. 1–4
  expansions are fine; ten are problematic (zoo §6.10).

**Deferred constraints** (not load-bearing for this decision):

- Runtime benchmark data. Parent §OOS2 and addendum §8 defer.
- Incremental build-time analysis. Addendum §8 defers.
- `mapError` compiler-fix classification. Relevant only if GE is adopted as
  sole error story; GE is deferred by this decision (§7.5).

## 3. Decision Framework

### 3.1 Hard-constraint filter

Per parent §7.6, all ten shapes pass constraints 1 (no protocols) and 2 (no
existentials). Constraint 6 (compile on Swift 6.3) passes for all ten at the
sketch level. Constraints 3–5 and 7 are discriminating:

| Shape | #3 ~Copyable | #4 Typed throws | #5 Region isolation | #7 Shared-executor single-line |
|-------|:-:|:-:|:-:|:-:|
| F | ✓ | ✓ | ✓ | ✓ |
| Dvm | ✓ (tuple caveat §6.4) | ✓ (closure annot required) | ✓ | ✓ (as composition over F) |
| MG | N/A (tooling) | ✓ | ✓ | N/A |
| GE | ✓ | ✓ | ✓ except `mapError` (§6.8) | ✓ |
| GO | ✓ | ✓ | ✓ viral | ✓ |
| DGS | ✓ | ✓ | ✓ viral | ✓ |
| Tk | ✓ | ✓ | ✓ | ✓ (via `Duplex` bundle) |
| Z | ✓ (via `sending R`) | ✓ (closure annot required) | ✓ | **✗ no executor-binding story** |
| E | ✓ | ✓ | ✓ with compounding tax (§6.7) | ✓ (scope-bound only) |
| M | caveat (tuple-~Copyable §6.4) | ✓ | ✗ rebind fails (§6.2) | N/A |

**Eliminated by hard-constraint violation**:

- **Shape Z** — fails constraint 7. Parent §5.8.9: "No executor-binding
  story: ZIO's 'runtime' concept does not map to Swift's
  `UnownedSerialExecutor`. There is no `io.unownedExecutor` spelling." The
  shared-executor pattern (TCA26) is a non-negotiable consumer API concern
  per the capability–runner split research (`io-witness-capability-runner-
  split.md` C3 / C4).

- **Shape M** — fails constraint 5. Parent §5.10.3 / §6.2: "Pure-`sending`
  Buffer without Sendable FAILED at loop re-bind:
  `#SendingRisksDataRace` — flow-sensitive region tracking through var
  rebind is beyond the current sending-checker". The workaround (ownership
  via `consuming` + isolation via Sendable buffer) reintroduces the
  Sendable-buffer constraint the design is trying to avoid, and imposes
  re-bind ergonomics on every read loop (parent §5.10.9).

### 3.2 Structural redundancy / ergonomic elimination

Per parent §10.3:

- **Shape GO** — structurally redundant with Shape Dvm. Parent §5.5.12:
  "If `Socket.Ops` were itself a `@Witness`, the shape collapses to Shape
  Dvm. The envelope `IO<Ops>` adds no operations, only a wrapper."

- **Shape DGS** — strictly inferior to Shape Dvm. Parent §5.6.12: "Shape
  DGS is REDUNDANT with Shape Dvm and strictly inferior on every ergonomic
  dimension." The explicit projection-closure store is mechanically
  equivalent to what Dvm achieves by closure capture — without the extra
  generic parameter.

- **Shape E** — subsumed by value-type capability passing. Parent §6.7
  documents the compounding `sending`-tax: "`with`'s return declares
  `throws(E) -> sending R`; any caller that needs to return the scope's
  result must itself carry `sending R`, and so on". swift-io's intended
  use pattern (actors with `IO.Bound` stored for the actor's lifetime —
  `io-blocking-executor-binding.md:85–98`) is fundamentally at odds with
  scope-bounded capability access.

### 3.3 Weighted criteria (surviving shapes)

After §3.1–3.2, the surviving shapes are **F**, **Tk**, **Dvm** (as
composition over F or Tk), **GE** (as a generic-error extension over F or
Tk), and **MG** (tooling enabler). The parent §10.1 carries forward the
six weighted criteria from
[io-witness-capability-runner-split.md](io-witness-capability-runner-split.md),
extended here with further criteria that the zoo exposed as discriminating
across the wider ten-shape set:

| # | Criterion | Weight | Rationale for weight |
|---|-----------|--------|-----------------------|
| C1 | Preserves Shape B axioms (value-type, Sendable, typed throws, ~Copyable-friendly, actor-isolation-backed) | **High** | Non-negotiable foundation; all non-eliminated shapes satisfy this fully |
| C2 | Capability axiom purity (capability witness exposes operations only) | **High** | Brachthäuser 2020 theoretical ground; swift-io's design-literature aspiration |
| C3 | Consumer API ergonomics (shared-executor single-line; no viral generics at consumer sites) | **High** | Measured by number of dots at call sites; explicit goal of perfect-api.md v3.0 |
| C4 | Compositionality with `swift-witnesses` operators (Recording, Scope, Values, Sequence, Cycle) | **High** | swift-io's testing story depends on it; addendum §4 confirmed all five operators are storage-agnostic and composable over both halves of F |
| C5 | Testability symmetry (both halves get `.unimplemented()` and can be faked independently) | **Medium** | Mock generation refutation (addendum §3.3) makes this near-zero cost |
| C6 | Migration cost from current Shape B | **Medium** | Real but bounded; precise counts in §8 |
| C7 | Future-proofing (error granularity, domain extension, vectored/deadline I/O) | **Medium** | nio-inspired P2 additions should not require a second witness refactor |
| C8 | Build-time cost of `@Witness` macro expansion (cold + incremental) | **Low** | Parent §6.10 data: 1–4 macros are cheap, 10+ scale badly |
| C9 | Shared-executor pattern compatibility | **High** | TCA26; mandatory executor binding via actor isolation |
| C10 | Role-expressiveness / visibility (cognitive dimensions) | **Medium** | Parent §7.3 + addendum §6 score columns |
| C11 | Region-isolation friendliness (no `mapError`-style region traps) | **Medium** | §6.8 remains a real limit; discriminator only under GE sole-error story |
| C12 | Maps cleanly onto academic models (capability, runner, evidence vector) | **Low** | Theoretical grounding is a correctness check, not a ranking axis |

### 3.4 Scoring method

Each surviving candidate is scored 1–10 on each criterion, then weighted
(High=3, Medium=2, Low=1) and summed. The scoring methodology is ordinal
per [RES-025]; rank ordering is what matters, not absolute values.
Extensions (F+GE, F+Dvm) are scored as the combined shape.

### 3.5 Elimination logic applied

After §3.1–3.2 the candidate set is **{F, F+GE, Tk, Tk+GE, F+Dvm,
F+GE+Dvm}**. Shape MG is a tooling enabler — it doesn't compete as a
shape. Dvm is not a standalone candidate — it is F's (or Tk's) domain-
composition mechanism.

§6 reduces this set further via direct head-to-head comparison (§6.2).

## 4. Elimination: Rejected Shapes

### 4.1 Shape Tokio (Tk) — per-capability split

**Rejected as primary; acknowledged as alternative axis.**

**Reason 1 — usage pattern dominance**. Parent §5.7.9:

> "In swift-sockets' actual call patterns (accept → read → write → close are
> invariably used together on a connection), the bundle is the common case.
> The split is paying extra surface area for a substitution granularity
> that is rarely exercised independently."

swift-sockets' `Sockets.TCP.Connection` (verified 2026-04-17, line 60–70 at
`/Users/coen/Developer/swift-foundations/swift-sockets/Sources/Sockets/Sockets.TCP.Connection.swift`)
holds exactly one `IO` field and threads it through every operation. No
call site substitutes a `Reader` without a `Writer` in production code.
The granularity is theoretical, not empirical.

**Reason 2 — build-time scaling**. Parent §5.7.3 records Tk's cold build
at **106.98s** vs F's 1.27s — an 84× increase for three witnesses. Adding
domain witnesses (Socket.Reader, Socket.Writer, File.Reader, File.Writer,
Pipe.Reader, Pipe.Writer, etc.) scales linearly. For swift-io + swift-sockets
+ swift-file-system, this projection lands at approximately twenty
`@Witness` macro expansions — a cold-build regression that swift-io's CI
budget cannot absorb. F's four closures on one witness amortise the macro
cost across operations instead of witnesses.

**Reason 3 — bundle access is the common case, so the split is notional**.
Parent §5.7.10 acknowledges: "Bundle access is two dots (`ops.reader.read`)
— same as Shape F's bundle access. Threading three parameters directly is
the alternative." Under Tk, the common case is `ops.reader.read(...)` /
`ops.writer.write(...)` etc. Under F, the common case is
`bound.io.read(...)` / `bound.io.write(...)`. The dot count is identical;
Tk pays an extra macro expansion per op for no consumer benefit in the
common case.

**Counterargument that would flip the verdict**: if swift-sockets had a
concrete pattern where a Reader was consumed without a Writer (e.g., a
unidirectional network tap), Tk's granularity would pay off. The current
codebase and `sockets-phase-3-plan.md` show no such pattern.

### 4.2 Shape ZIO (Z) — monadic `IO<R, E, A>`

**Rejected: hard constraint 7 violation.**

**Reason — no executor-binding story**. Parent §5.8.9:

> "No executor-binding story: ZIO's 'runtime' concept does not map to
> Swift's `UnownedSerialExecutor`. There is no `io.unownedExecutor` spelling.
> This rules out the shared-executor pattern that Shape F enables."

The shared-executor pattern is a load-bearing concern:
[io-blocking-executor-binding.md](io-blocking-executor-binding.md) v4.0
establishes it as mandatory (Task executor preference is advisory, actor
isolation is the binding). swift-sockets' `Sockets.TCP.Listener` (file
cited above, line 62–64) forwards its `unownedExecutor` from the witness;
swift-io's `IO.Blocking.Binding.Tests` asserts the binding.

**Secondary concern — typed-throws verbosity in combinators**. Parent
§5.8.7: every combinator closure requires an explicit `throws(E)`
annotation because Swift does not infer typed throws through the
combinator's generic context. This is the same gotcha documented in
[API-ERR-004]; under a chainable-combinator shape it compounds across every
chain.

**Secondary concern — monadic shape is orthogonal to Swift async/await**.
Parent §5.8.9: "Each `.map`, `.flatMap`, `.mapError` allocates a closure.
Chains build up per-call allocation — potentially measurable vs direct
witness-of-closures." Swift's native `async`/`await` already is the
monadic-effect infrastructure; Z re-invents it.

**Note on region-isolation revision**: the addendum's V3 of the
maperror-sending-return experiment and the parent §5.8.5 note that
`sending R` + `sending A` now eliminate the historical `R: Sendable`
constraint, making Z more viable than the original ZIO literature
suggested. But executor-binding remains a structural block.

### 4.3 Shape Eio (E) — stdenv + scope

**Rejected: compounding `sending`-tax subsumed by F.**

**Reason — scope tax compounds**. Parent §6.7:

> "Shape E's `with(stdenv:_:)` function declares `body: (Stdenv) async
> throws(E) -> sending R`. To propagate the region through, the outer
> function itself must declare `throws(E) -> sending R`. Calls to `with`
> that themselves need to return their result to a caller must also carry
> `sending R`. The tax compounds up the call chain."

swift-io's use pattern is **long-lived actor**, not short-lived CLI. A
server actor stores `IO.Bound` for its lifetime and processes incoming
connections over time. The scope form buys nothing there — the capability's
lifetime is the actor's lifetime, not a structured block.

**Reason — subsumed**. Parent §5.9.12:

> "The scope form is SUBSUMED by Shape F: an `IO.Bound` stored on an actor,
> or passed via `sending`, achieves the same lifetime-bounded access
> without the scope function."

Shape E's nested sub-capabilities (`Eio.Net`, `Eio.File`, `Eio.Clock`)
correspond one-for-one with Shape Dvm's domain witnesses (`Socket.IO`,
`File.IO`, `Clock.IO`). The `Stdenv` bundle is a plain struct of
witnesses — which is what `IO.Bound` already is. The only differentiator
is the scope function, which is the concrete cost.

### 4.4 Shape monoio (M) — rental buffer

**Rejected: compound of hard-constraint #5 failure and ergonomics.**

**Reason 1 — region-checker rebind failure**. Parent §5.10.3 and §6.2:
pure `sending` Buffer without Sendable FAILS at loop rebind with
`#SendingRisksDataRace`. The workaround (consuming + Sendable buffer
payload) reintroduces the Sendable constraint the design is trying to
avoid.

**Reason 2 — tuple-~Copyable limit**. Parent §5.10.5: the rental signature
`async throws -> (Buffer, Int)` cannot use `~Copyable` Buffer in Swift 6.3.
A real implementation would need a named `~Copyable` struct
(`Memory.Buffer.Returned`) per call — boilerplate that swift-io's borrow
approach avoids.

**Reason 3 — ergonomic cost**. Parent §5.10.9: every read loop requires
`let (returnedBuf, n) = try await io.read(...); buf = returnedBuf`. swift-io
already has the correct semantics via the proactor cancellation handshake
(`io-proactor-buffer-ownership.md`) — without the rebind.

### 4.5 Shape Generic Ops (GO) — `IO<Ops>` envelope

**Rejected: redundant with Dvm.**

Parent §5.5.12: "Shape GO is structurally redundant with Shape Dvm... The
envelope `IO<Ops>` adds no operations, only a wrapper." Domain-specific
operation sets via Dvm's `.map` achieve specialization without the generic
virality (parent §6.3) that every consumer signature inherits under GO.

### 4.6 Shape Domain Generic Substrate (DGS)

**Rejected: strictly inferior to Dvm.**

Parent §5.6.12: "Shape DGS is REDUNDANT with Shape Dvm and strictly
inferior on every ergonomic dimension." The explicit projection-closure
store is mechanically equivalent to Dvm's closure capture — but with an
extra generic parameter that virally propagates into consumer signatures.

### 4.7 Shape Macro Generic Compat (MG)

**Not a shape; retained as a tooling property.**

Parent §5.3.12: "Shape MG is a tooling verification, not a design choice."
The finding — `@Witness` propagates generic parameters into synthesised
members — is essential context for any future adoption of GE, GO, or DGS.
Retained as a tooling enabler; see §10.1 for when it would be exercised.

## 5. The Finalists

After §4 elimination, three finalist shapes remain:

- **F** — Shape F alone (flat `IO.Error`, non-generic).
- **F+Dvm** — F with Dvm as the domain-composition mechanism.
- **F+GE** — F extended with generic-error `IO<LeafError>`.

### 5.1 Finalist: Shape F (flat `IO.Error`)

#### 5.1.1 Formal Swift shape

```swift
@Witness
public struct IO: Sendable {
    public let read:  @Sendable (_ from: borrowing Kernel.Descriptor,
                                 _ into: Memory.Buffer.Mutable)
                                 async throws(IO.Error) -> Int
    public let write: @Sendable (_ to:   borrowing Kernel.Descriptor,
                                 _ from: Memory.Buffer)
                                 async throws(IO.Error) -> Int
    public let close: @Sendable (consuming Kernel.Descriptor) async -> Void
    public let ready: @Sendable (_ from: borrowing Kernel.Descriptor,
                                 _ interest: Kernel.Event.Interest)
                                 async throws(IO.Error) -> Void
}

extension IO {
    @Witness
    public struct Runner: Sendable {
        public let executor: @Sendable () -> UnownedSerialExecutor
        public let shutdown: @Sendable () async -> Void
    }

    public struct Bound: Sendable {
        public let io: IO
        public let runner: IO.Runner
        public init(io: IO, runner: IO.Runner) {
            self.io = io
            self.runner = runner
        }
    }
}
```

#### 5.1.2 Scoring against the twelve criteria (3.3)

| # | Criterion | Score | Evidence |
|---|-----------|-------|----------|
| C1 | Preserves Shape B axioms | 10/10 | Value-type, Sendable, typed throws, ~Copyable-friendly; parent §5.1 PASS |
| C2 | Capability axiom purity | 10/10 | Operations-only on capability; runner separate. Brachthäuser 2020 compliant; parent §5.1.4, §5.1.12 |
| C3 | Consumer ergonomics | 7/10 | Two-dot access (`bound.io.read`, `bound.runner.executor()`); single-line shared-executor accessor remains (`io-witness-capability-runner-split.md` §Analysis) |
| C4 | `swift-witnesses` composition | 10/10 | Every operator applies to both halves independently (addendum §4.2, parent §5.1.10). `IO.unimplemented()` and `IO.Runner.unimplemented()` generated (addendum §3.1) |
| C5 | Testability symmetry | 10/10 | `.unimplemented()` on both; `.mock` works on IO per addendum §3.3 (refutation). `IO.fake()` can be macro-generated or hand-rolled per-strategy |
| C6 | Migration cost | 6/10 | Non-trivial but bounded. See §8: ~40 total files touched, mechanical edits |
| C7 | Future-proofing | 9/10 | Runner witness absorbs P0 (shutdown) and future P1 items (name, statistics) without ever touching capability. P2 deadline/vectored add more closures without disturbing existing surface |
| C8 | Build-time cost | 9/10 | Two `@Witness` macros vs Shape B's one; ~2.5s cold sketch vs Shape B's ~1.3s. Within CI budget |
| C9 | Shared-executor pattern compat | 10/10 | `actor Server { let bound: IO.Bound; nonisolated var unownedExecutor: UnownedSerialExecutor { bound.runner.executor() } }` — single-line per TCA26 |
| C10 | Role-expressiveness / visibility | 9/10 | Parent §5.1.11: all dimensions High except Viscosity (Medium) |
| C11 | Region-isolation friendliness | 10/10 | No `mapError`; no generic parameter; no scope tax. `sending IO.Bound` at boundaries |
| C12 | Academic grounding | 10/10 | Maps cleanly to Brachthäuser capability + Ahman & Bauer runner; parent §5.1.4 |

**Weighted sum** (High×3, Medium×2, Low×1):

```
(10+10+7+10+10) × 3 + (6+9+9+10) × 2 + (9+10) × 1 + 10 × 1
= 47 × 3 + 34 × 2 + 29
= 141 + 68 + 29 = 238
```

Normalised /30 (total High weight 5, Medium 4, Low 3 = weight sum 29, so
max = 10×29 = 290): **82%**.

#### 5.1.3 Integration with P0/P1/P2 nio-inspired additions

| Priority | Addition | Slot |
|----------|----------|------|
| P0 | Shared-singleton `shutdown()` | `IO.Runner.shutdown` — canonical home across all three strategies (`io-witness-capability-runner-split.md` §Interactions subsumes P0) |
| P1 | `Kernel.Thread.Executor.name` | swift-executors; orthogonal |
| P1 | Test fakes — `IO.fake(...)` | Macro-generated via `@Witness(.mock)` on `IO` and `IO.Runner` (addendum §3.3 refutation) |
| P2 | Deadline-bound I/O | New closure(s) on `IO` — `readDeadline: @Sendable (...) -> ...` or extend signatures. Runner untouched |
| P2 | Vectored I/O (readv/writev) | New closures on `IO` — `readv`, `writev`. Runner untouched |
| P3 | Multishot readiness | swift-kernel concern; reaches `IO.Event.Actor` not the witness shape |
| P3 | Zero-copy transfers | New closure on `IO` — `transfer: @Sendable (from: borrowing .., to: borrowing ..) -> Int` |

Every capability addition slots onto `IO`; every lifecycle addition slots
onto `IO.Runner`; the shape is closed under the known P0–P3 set without
re-factoring.

#### 5.1.4 Known limitations

- **Two-dot consumer access**. `bound.io.read(...)`, `bound.runner.executor()`.
  The capability-runner split research documents this as acceptable
  (`io-witness-capability-runner-split.md` line 184–186).
- **No cross-actor `mapError`**. Flat `IO.Error` doesn't need it; addendum
  §3.2 confirms the limit is intrinsic to Swift 6.3. If GE is later
  adopted, this limit re-emerges (§10.1).
- **Migration cost**. Section §8.

### 5.2 Finalist: Shape F + Dvm

#### 5.2.1 Formal Swift shape

F as above, plus:

```swift
extension IO {
    /// Re-encode this capability into a domain-specific witness.
    /// Dvm: domain via map.
    public func map<Domain>(_ transform: (IO) -> Domain) -> Domain {
        transform(self)
    }
}

extension IO.Bound {
    /// Lift the `.map` to operate on the bundle, threading the runner
    /// through unchanged.
    public func map<Domain>(
        _ transform: (IO) -> Domain
    ) -> (domain: Domain, runner: IO.Runner) {
        (transform(self.io), self.runner)
    }
}
```

A domain witness (Socket.IO) is then built as:

```swift
extension Socket {
    @Witness
    public struct IO: Sendable {
        public let accept:   @Sendable (_ listener: borrowing Kernel.Descriptor)
                                       async throws(Socket.IO.Error) -> Socket.Accepted
        public let connect:  @Sendable (_ fd: borrowing Kernel.Descriptor,
                                        _ to: Socket.Address)
                                        async throws(Socket.IO.Error) -> Void
        public let shutdown: @Sendable (_ fd: borrowing Kernel.Descriptor)
                                        throws(Socket.IO.Error) -> Void
    }
}

extension Socket.IO {
    public static func make(from io: sending swift_io.IO) -> sending Socket.IO {
        io.map { base in
            Socket.IO(
                accept: { listener in
                    try await base.ready(from: listener, interest: .read)
                    // ... syscall ...
                    return Socket.Accepted(/* … */)
                },
                connect: { (fd, addr) in
                    // ...
                },
                shutdown: { fd in
                    // ...
                }
            )
        }
    }
}
```

#### 5.2.2 Why adopted alongside F

- Parent §5.2.12: "Shape Dvm is the composition mechanism that lets Shape F
  (or any base witness shape) scale to multiple domain witnesses. It is
  NOT an alternative to Shape F." The decision here is: adopt Dvm as the
  canonical pattern for `Socket.IO`, `File.IO`, etc.
- It avoids the protocol-based abstraction the constraints forbid.
- It is one extension; it is not a separate target or package.

#### 5.2.3 Known limitations

- **Tuple-~Copyable limit for accept**: `accept` wants to return
  `(Descriptor, Address)`. Swift 6.3 doesn't support `~Copyable` in
  tuples. Workaround: named `~Copyable` struct `Socket.Accepted`. Parent
  §5.2.3 caveat.
- **Typed-throws closure annotation overhead**: the closure literals
  inside `.map` need explicit `throws(DomainError)` (parent §6.5). This
  is an [API-ERR-004] gotcha, not specific to Dvm.

### 5.3 Finalist: Shape F + GE (deferred extension)

#### 5.3.1 Formal Swift shape

```swift
@Witness
public struct IO<LeafError: Swift.Error>: Sendable {
    public let read:  @Sendable (...) async throws(LeafError) -> Int
    public let write: @Sendable (...) async throws(LeafError) -> Int
    public let close: @Sendable (consuming Kernel.Descriptor) async -> Void
    public let ready: @Sendable (...) async throws(LeafError) -> Void
}

// IO.Runner unchanged (error-agnostic).

public typealias BaseIO = IO<IO.Error>

extension IO {
    public func mapError<NewError: Swift.Error>(
        _ transform: @escaping (LeafError) -> NewError
    ) -> IO<NewError> { /* wraps each closure */ }
}
```

#### 5.3.2 Why deferred, not eliminated

- **No concrete consumer demand**. `swift-sockets` and `swift-file-system`
  today catch `IO.Error` and translate to `Sockets.Error` /
  `File.System.*.Error` manually. The translation is already happening in
  the consumer's catch blocks. Adding a generic parameter shifts the
  translation from catch-site to `mapError` call — a lateral move, not a
  win.
- **`mapError` region-inheritance limit**. Addendum §3.2: confirmed-still-
  open. A shape that depends on `mapError` for cross-actor witness
  production hits this wall without a workaround other than V3's
  `LeafError: Sendable` + `@Sendable` closures — which violates
  `feedback_no_sendable_constraint_workaround.md`.
- **Viral specialization**. Parent §6.3: every `IO<E>` spelling at
  consumer sites is a virulence point.
- **Build time amplification**. Parent §5.3.3 / Shape MG: 90.77s cold for
  a one-closure generic `@Witness`. For a four-closure witness the cost
  scales further.

Trigger conditions to revisit are stated in §10.1.

### 5.4 Non-finalist: MG as tooling

Shape MG is not a shape. It is the compile-time verification that the
`@Witness` macro propagates generic parameters into synthesised members.
The verification matters in two scenarios:

1. If GE is later adopted (§10.1), `@Witness public struct IO<LeafError: Error>`
   is the canonical declaration form.
2. If a future shape adds any other generic parameter to `IO` (e.g., a
   buffer-strategy parameter), MG establishes the macro works.

MG imposes no cost under the currently selected non-generic shape.

## 6. Head-to-Head Comparison

### 6.1 F alone vs F+Dvm

Dvm is not an alternative to F — it is a composition extension. The
head-to-head collapses to "does swift-io export `.map`?". The answer is
**yes** — Dvm is adopted alongside F.

### 6.2 F alone vs F+GE

| Criterion | F alone | F+GE | Winner |
|-----------|:-:|:-:|:-:|
| C1 Shape B axioms | 10 | 10 | tie |
| C2 Capability purity | 10 | 10 | tie |
| C3 Ergonomics | 7 | 5 — viral `IO<E>` | **F** |
| C4 swift-witnesses composition | 10 | 9 — `Observe` needs per-specialization | **F** |
| C5 Testability | 10 | 10 | tie |
| C6 Migration cost | 6 | 4 — adds a generic parameter to consumer surface | **F** |
| C7 Future-proofing | 9 | 9 — GE can be added later | tie |
| C8 Build-time cost | 9 | 6 — generic `@Witness` at 90.77s cold | **F** |
| C9 Shared-executor pattern | 10 | 10 | tie |
| C10 Role-expressiveness | 9 | 8 — extra generic noise | **F** |
| C11 Region-isolation | 10 | 7 — `mapError` region-inheritance limit | **F** |
| C12 Academic grounding | 10 | 10 | tie |

**F wins 7–0**. GE offers no new capability (catch-site translation of
`IO.Error` to domain errors is already happening without generics); it
only adds costs (ergonomics, migration, build time, region-isolation).
GE is deferred with triggers (§10.1).

### 6.3 F+Dvm+MG vs F+Dvm

MG is not a shape. Under F+Dvm, MG is latent — if GE is adopted later,
MG's finding is already in hand. No decision to make.

### 6.4 Summary

The selected shape is **F** (capability + runner + plain bundle) with
**Dvm** as the canonical domain-composition mechanism, **MG** as latent
tooling, and **GE** explicitly deferred.

## 7. Selected Shape

### 7.1 THE winner

**Shape F, adopted as `IO` + `IO.Runner` + `IO.Bound`, with Dvm as the
canonical domain-composition primitive (`IO.map`), flat `IO.Error` as the
error type, and `@Witness(.mock)` enabled on both halves.**

Declarative form:

```swift
// In swift-io's IO Core target.

import Witnesses
import Memory_Primitives
import Kernel

extension IO {
    public enum Error: Swift.Error, Sendable, Equatable {
        case connectionReset
        case brokenPipe
        case notConnected
        case timeout
        case cancelled
        case shutdown
        case platform(Kernel.Error.Code)
    }
}

@Witness(.mock)
public struct IO: Sendable {
    public let read: @Sendable (
        _ from: borrowing Kernel.Descriptor,
        _ into: Memory.Buffer.Mutable
    ) async throws(IO.Error) -> Int

    public let write: @Sendable (
        _ to: borrowing Kernel.Descriptor,
        _ from: Memory.Buffer
    ) async throws(IO.Error) -> Int

    public let close: @Sendable (consuming Kernel.Descriptor) async -> Void

    public let ready: @Sendable (
        _ from: borrowing Kernel.Descriptor,
        _ interest: Kernel.Event.Interest
    ) async throws(IO.Error) -> Void
}

extension IO {
    @Witness(.mock)
    public struct Runner: Sendable {
        public let executor: @Sendable () -> UnownedSerialExecutor
        public let shutdown: @Sendable () async -> Void
    }
}

extension IO {
    public struct Bound: Sendable {
        public let io: IO
        public let runner: IO.Runner

        public init(io: IO, runner: IO.Runner) {
            self.io = io
            self.runner = runner
        }
    }
}

extension IO {
    /// Re-encode this capability into a domain-specific witness (Dvm).
    public func map<Domain>(_ transform: (IO) -> Domain) -> Domain {
        transform(self)
    }
}
```

### 7.2 Why it wins (top three reasons)

**Reason 1 — only shape satisfying all hard constraints without
compromise**. Tk passes but at unacceptable build cost; Z fails constraint
7; M fails constraint 5; E fails ergonomic subsumption; GE introduces
generic virality and the `mapError` region limit; GO and DGS are
structurally redundant with Dvm. F is the single survivor whose
limitations are bounded (two-dot access, migration cost) rather than
structural.

**Reason 2 — canonical home for P0/P1/P2 extensions**. The runner witness
absorbs shutdown (P0), executor naming / statistics (P1), and future
lifecycle operations without touching the capability witness. The
capability witness absorbs deadline-bound I/O (P2), vectored I/O (P2), and
zero-copy transfers (P3) as new closures without touching the runner. No
future nio-inspired addition requires a second witness-shape refactor.

**Reason 3 — full `swift-witnesses` composition over both halves**. Per
addendum §4.2, every composition operator applies uniformly to both `IO`
and `IO.Runner`. `Witness.Recording` on operations alone; `Witness.Scope`
on the runner naturally; `Witness.Values[IO.self]` and
`Witness.Values[IO.Runner.self]` as independent typed slots.
`IO.unimplemented()` and `IO.Runner.unimplemented()` both generated;
`@Witness(.mock)` works on both (addendum §3.3). This is the design
literature's §394–396 aspiration realised at the type level.

### 7.3 What it trades away (explicitly)

- **One-dot consumer access**. Shape B's `io.read(...)` becomes F's
  `bound.io.read(...)`. Measurable but small (`io-witness-capability-runner-
  split.md` C3: 7/10 vs Shape B's 10/10).
- **Single-factory-value handoff**. Every factory (`IO.blocking`,
  `IO.events`, `IO.completions`, `IO.default`) now returns `IO.Bound`
  instead of `IO`. Consumers that stored `let io: IO` migrate to
  `let bound: IO.Bound`.
- **One extra `@Witness` macro expansion per target that builds `IO`**.
  From ~1.3s cold to ~2.5s cold (measured against the Shape F sketch).
- **Zero generic parameters at the consumer surface — a deliberate trade
  vs GE's domain-precise error types**. If this trade later proves wrong,
  §10.1 documents the trigger for revisiting.

### 7.4 Why not the runner-up

The runner-up is **F+GE** (F with generic error parameter). §6.2 scores
it 7–0 losses vs F alone across the 12 weighted criteria. The
hypothetical win of GE is "domain-precise errors", but every current
consumer (`swift-sockets`, `swift-file-system`, `swift-tests`) already
catches `IO.Error` and translates at the catch-site to a domain error.
The translation is explicit and local; adding a generic parameter to
centralise the translation into `mapError` moves work, not eliminates it.

The additional concerns — `mapError` region-inheritance, generic virality
through consumer signatures, macro build-time amplification, and the
`LeafError: Sendable` cascade that V3 imposes — all argue for deferring
GE until a concrete consumer demand arises (§10.1).

### 7.5 Compatible extensions adopted alongside

| Extension | Adopted now? | Rationale |
|-----------|:------------:|-----------|
| Dvm (`.map`) | **Yes** | Domain witnesses (Socket.IO, File.IO) need a protocol-free composition primitive. Dvm is that primitive. See §9.2 for concrete Socket.IO example. |
| MG (macro generics) | Latent | No generic parameters on public surface in v1. MG's finding (parent §5.3) is inherited if GE is later adopted. |
| GE (generic error) | **Deferred** (§10.1) | See §7.4. |
| `@Witness(.mock)` on both halves | **Yes** | Addendum §3.3 confirms the Swift 6.3 compiler propagates ownership through `(_, _)` mock-closure placeholders. Test fakes for both halves at near-zero cost. Drops the stale comment at `IO.swift:92–98`. |

## 8. Migration Plan from Shape B

### 8.1 Inventory of current Shape B types and locations

| File | Lines | Current responsibility | Change |
|------|-------|------------------------|--------|
| `swift-foundations/swift-io/Sources/IO Core/IO.swift` | 209 | `@Witness public struct IO` with 5 closures including `unownedExecutor` | **Split**: drop `unownedExecutor`; introduce `IO.Runner` + `IO.Bound` in sibling files |
| `swift-foundations/swift-io/Sources/IO Core/IO.Error.swift` | — | `IO.Error` enum | Unchanged |
| `swift-foundations/swift-io/Sources/IO Core/IO.Error+Kernel.swift` | — | Error mapping | Unchanged |
| `swift-foundations/swift-io/Sources/IO Core/exports.swift` | — | Module re-exports | Re-exports `IO.Runner`, `IO.Bound` |
| `swift-foundations/swift-io/Sources/IO Blocking/IO+Blocking.swift` | 84 | `IO.blocking()`, `IO.blocking(on:)` factories returning `IO` | **Change**: return `IO.Bound` |
| `swift-foundations/swift-io/Sources/IO Blocking/IO.Blocking.swift` | 49 | `IO.Blocking` pool + `.shared` + `.shutdown()` | Unchanged; runner's `shutdown` closure calls `Blocking._executors.shutdown()` |
| `swift-foundations/swift-io/Sources/IO Blocking/IO.Blocking.Actor.swift` | 76 | Internal blocking actor | Unchanged |
| `swift-foundations/swift-io/Sources/IO Events/IO+Events.swift` | 54 | `IO.events(on:)`, `IO.events()` factories | **Change**: return `IO.Bound`; `runner.shutdown` calls `actor.shutdown()` |
| `swift-foundations/swift-io/Sources/IO Events/IO.Event.Actor.swift` | 470 | Internal events actor | Add `public func shutdown() async` (currently in deinit only); called from runner closure |
| `swift-foundations/swift-io/Sources/IO Completions/IO+Completions.swift` | 87 | `IO.completions(on:)`, `IO.completions()` factories | **Change**: return `IO.Bound` |
| `swift-foundations/swift-io/Sources/IO Completions/IO.Completion.Actor.swift` | 657 | Internal completions actor | Add `public func shutdown() async` |
| `swift-foundations/swift-io/Sources/IO/IO+Default.swift` | 82 | `IO.default()` | **Change**: return `IO.Bound` |
| `swift-foundations/swift-io/Sources/IO/exports.swift` | 13 | Module re-exports | Add `IO.Runner`, `IO.Bound` |
| `swift-foundations/swift-io/Tests/IO Tests/*` | — | Test suite | Update assertions that use `io.unownedExecutor` to `bound.runner.executor()` |
| `swift-foundations/swift-io/Tests/IO Blocking Tests/*` | — | Blocking binding tests | Same |
| `swift-foundations/swift-io/Tests/IO Events Tests/*` | — | Events tests | Same |
| `swift-foundations/swift-io/Tests/Completions Support/*` | — | Completions test support | Same |

**swift-io inventory**: approximately **14 source files touched + 4 test
files touched = 18 files**.

### 8.2 File-by-file migration

#### 8.2.1 `IO Core/IO.swift` (replace)

Post-migration content in §9.1 below. Remove lines 92–98 (stale `@Witness(.mock)`
disabled comment). Drop `unownedExecutor: @Sendable () -> UnownedSerialExecutor`
from the witness body. Reorganise the docstring to separate capability
concerns from runner concerns.

#### 8.2.2 `IO Core/IO.Runner.swift` (new)

New file, ~20 lines — the runner witness declaration. See §9.1.

#### 8.2.3 `IO Core/IO.Bound.swift` (new)

New file, ~25 lines — the bundle struct. See §9.1.

#### 8.2.4 `IO Blocking/IO+Blocking.swift` (modify)

```swift
// Before:
public static func blocking(on executor: Kernel.Thread.Executor) -> IO {
    let actor = IO.Blocking.Actor(executor: executor)
    return unsafe IO(
        read: { … },
        write: { … },
        close: { … },
        ready: { … },
        unownedExecutor: { unsafe actor.unownedExecutor }
    )
}

// After:
public static func blocking(on executor: Kernel.Thread.Executor) -> IO.Bound {
    let actor = IO.Blocking.Actor(executor: executor)
    let io = unsafe IO(
        read: { … },
        write: { … },
        close: { … },
        ready: { … }
    )
    let runner = unsafe IO.Runner(
        executor: { unsafe actor.unownedExecutor },
        shutdown: { /* Blocking pool shutdown is the pool's concern, not the
                       actor's — here the runner's shutdown is a no-op when
                       the executor came from shared; when the caller
                       supplied the executor they own its lifetime */ }
    )
    return IO.Bound(io: io, runner: runner)
}

public static func blocking(_ pool: Blocking = .shared) -> IO.Bound {
    let io = blocking(on: pool._executors.next())
    // The overload that takes a pool can wire runner.shutdown to the pool.
    return IO.Bound(
        io: io.io,
        runner: unsafe IO.Runner(
            executor: io.runner.executor,
            shutdown: { pool.shutdown() }
        )
    )
}
```

**Design note**: the `blocking(on:)` overload's `runner.shutdown` is a
no-op because the caller owns the executor's lifetime. The pool-based
overload's `runner.shutdown` forwards to the pool's `shutdown()`. This
mirrors the existing pattern and makes the lifecycle story explicit per
call-site.

#### 8.2.5 `IO Events/IO+Events.swift` (modify)

```swift
// Before:
public static func events(on actor: IO.Event.Actor) -> IO {
    IO(
        read: { … },
        write: { … },
        close: { … },
        ready: { … },
        unownedExecutor: { actor.unownedExecutor }
    )
}

// After:
public static func events(on actor: IO.Event.Actor) -> IO.Bound {
    let io = IO(
        read: { … },
        write: { … },
        close: { … },
        ready: { … }
    )
    let runner = IO.Runner(
        executor: { actor.unownedExecutor },
        shutdown: { await actor.shutdown() }
    )
    return IO.Bound(io: io, runner: runner)
}
```

`IO.Event.Actor.shutdown()` must be promoted from `deinit`-only to a
public method. This is the nio-inspired-additions P0 fix.

#### 8.2.6 `IO Completions/IO+Completions.swift` (modify)

Analogous to events. `IO.Completion.Actor.shutdown()` likewise promoted
to public.

#### 8.2.7 `IO/IO+Default.swift` (modify)

```swift
// Before:
public static func `default`() -> IO {
    // if/else over completions/events/blocking
}

// After:
public static func `default`() -> IO.Bound {
    // if/else over completions/events/blocking — each returns IO.Bound
}
```

#### 8.2.8 Test files (modify)

All `io.unownedExecutor()` sites become `bound.runner.executor()`.
Grep-level mechanical replacement.

### 8.3 Downstream impact

#### 8.3.1 swift-sockets

`Sockets.TCP.Listener` currently holds `_io: IO`
(`/Users/coen/Developer/swift-foundations/swift-sockets/Sources/Sockets/Sockets.TCP.Listener.swift:60`).
It forwards `unownedExecutor` on line 62–64. Migration:

```swift
// Before:
public actor Listener {
    internal let _fd: Kernel.Descriptor
    internal let _io: IO
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        _io.unownedExecutor()
    }
    internal init(fd: consuming Kernel.Descriptor, io: IO) { … }
}

// After:
public actor Listener {
    internal let _fd: Kernel.Descriptor
    internal let _io: IO.Bound
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        _io.runner.executor()
    }
    internal init(fd: consuming Kernel.Descriptor, io: IO.Bound) { … }
}
```

The listener's `accept()` method uses `_io.ready` (line 178); that
becomes `_io.io.ready`.

`Sockets.TCP.Connection` (line 60–87) likewise holds an `IO` and calls
`io.read`/`io.write`/`io.close`. Migration changes the stored property
from `IO` to `IO.Bound` and call sites from `io.X(...)` to `io.io.X(...)`.

**Files touched in swift-sockets**:

1. `Sockets.TCP.Listener.swift` — actor + constructor signatures (`blocking`,
   `reactive` factories both take `IO.Bound` now).
2. `Sockets.TCP.Connection.swift` — actor + uses.
3. `Sockets.TCP.Listener.Tests.Echo.swift` — test call sites.
4. `Sockets.TCP.Listener.Tests.MultipleConnections.swift` — test call sites.
5. `Sockets.TCP.Listener.Tests.BlockingIdleCPU.swift` — test.
6. `sockets-phase-3-plan.md` — research doc update (sister doc to this
   selection).
7. `Sockets.swift` — module export or facade (if any).
8. Any benchmarks — verify (likely none).

**Estimate: 8 files**.

#### 8.3.2 swift-file-system

`swift-file-system/Sources/File System/*.swift` has 18 call sites of
`IO.Blocking.shared.run { ... }`. These use the `IO.Blocking` pool
directly, not the `IO` witness — so they are **unaffected by the F
migration**. The `IO.Blocking` pool lives alongside `IO.Bound`; it is the
same type. Its `.run` method is an independent API.

If `swift-file-system` later wants to operate through `IO.Bound` (to
share executor with a socket), that is a separate decision; Shape F
enables it but does not force it. For v1 of the migration,
`swift-file-system` sees **zero code changes** — the existing
`IO.Blocking.shared.run` API is preserved.

**Files touched in swift-file-system**: **0** (for F migration proper).

#### 8.3.3 swift-tests

The six `IO.Blocking.shared.run` call sites in `swift-tests/Sources/Tests
Performance/` are the same pattern as swift-file-system — unaffected.

**Files touched in swift-tests**: **0** for v1.

#### 8.3.4 Benchmarks

Benchmark files in `swift-foundations/swift-io/Benchmarks/` do not
currently reference `IO.blocking()` / `IO.events()` / `IO.completions()`
directly (confirmed via grep §contextual check). **0 files** touched.

#### 8.3.5 Experiments

The `swift-io/Experiments/witness-over-actor/Sources/test/main.swift`
file references `IO.blocking()`, `IO.events()`, and `io.unownedExecutor`.
These are experimental sketches — they update mechanically during
migration.

**Files touched in swift-io experiments**: **1**.

#### 8.3.6 Documentation

- `swift-io/Sources/IO Core/IO.swift` docstring (part of §8.2.1).
- `swift-io/Sources/IO Events/README.md`.
- `swift-io/Sources/IO Completions/README.md`.
- `swift-io/Research/perfect-api.md` — reference `IO.Bound` as the
  `IO.run` entry-point internal type.
- `swift-io/Research/io-witness-design-literature-study.md` — version
  bump noting supersession of Shape B.
- `swift-io/Research/io-witness-capability-runner-split.md` — status
  change from RECOMMENDATION to PROMOTED-TO-DECISION with back-reference
  to this document.

**Files touched in documentation**: **6**.

#### 8.3.7 swift-io-primitives (scaffold)

`swift-primitives/swift-io-primitives/Sources/IO Primitives/` currently
contains only `exports.swift` with `@_exported public import
Witness_Primitives`. Under Shape F, this becomes the home for the canonical
shape (per
[io-witness-capability-runner-split.md](io-witness-capability-runner-split.md)
§Open decisions point 3 — naming). Open decision per §11.6.

### 8.4 Sequencing

Recommended landing order. Each phase is independently mergeable and
verifiable.

**Phase M1 — swift-io internal migration** (approx. 18 files):

1. Add `IO Core/IO.Runner.swift` and `IO Core/IO.Bound.swift` (new files).
2. Modify `IO Core/IO.swift` to drop `unownedExecutor` closure; promote
   `@Witness` → `@Witness(.mock)`.
3. Add `IO.Event.Actor.shutdown()` public method.
4. Add `IO.Completion.Actor.shutdown()` public method.
5. Modify `IO+Blocking.swift`, `IO+Events.swift`, `IO+Completions.swift`,
   `IO+Default.swift` factories to return `IO.Bound`.
6. Update `IO Core/exports.swift` and `IO/exports.swift`.
7. Update swift-io tests mechanically (`_.unownedExecutor` →
   `_.runner.executor()`, `let io: IO` → `let bound: IO.Bound` as
   appropriate, `io.X(...)` → `bound.io.X(...)`).
8. Run swift-io test suite; verify binding tests pass.

Rollback condition: if `swift test` in swift-io fails on `.blocking` /
`.events` / `.completions` regression tests, revert the factory changes
and the `IO Core/IO.swift` edit. The new files (`IO.Runner.swift`,
`IO.Bound.swift`) can remain without harm.

**Phase M2 — swift-sockets migration** (approx. 8 files):

1. Update `Sockets.TCP.Listener` stored property and constructor.
2. Update `Sockets.TCP.Connection` analogously.
3. Update listener/connection factories to accept `IO.Bound`.
4. Update swift-sockets tests.
5. Run swift-sockets test suite on Darwin + Linux.

Rollback condition: swift-sockets tests fail. Revert to Phase M1's
swift-io alone, with swift-sockets pinned on pre-migration swift-io
commit.

**Phase M3 — documentation sync** (6 files):

Idempotent documentation updates across research and README surfaces.

**Phase M4 — swift-io-primitives population (Option A)**:

If open decision §11.6 resolves to "populate now":

1. Port `IO`, `IO.Runner`, `IO.Bound`, `IO.Error`, `IO.map` from
   `swift-foundations/swift-io/Sources/IO Core/` to
   `swift-primitives/swift-io-primitives/Sources/IO Primitives/`.
2. Add kernel-primitive and memory-primitive dependencies to the L1
   package.
3. Have swift-foundations/swift-io re-export IO-Primitives as a public
   typealias bridge.

If §11.6 defers: no action in M4.

### 8.5 Rollback plan if a step fails

Each phase is independently revertible via git. The migration sequence is
designed so that:

- Phase M1's net addition is two new files and a modification to factory
  return types. A full revert restores the pre-migration state.
- Phase M2 depends on M1; if M2 fails, revert M2 only (swift-sockets
  returns to pre-migration; swift-io retains Phase F).
- Phase M3 is idempotent; re-running it after a revert re-applies
  documentation.
- Phase M4 is speculative and behind open decision §11.6.

### 8.6 Estimated effort

Measured in terms of touched files (per request; not hours):

| Package | New files | Modified files | Total |
|---------|-----------|----------------|-------|
| swift-io/Sources | 2 | 9 | 11 |
| swift-io/Tests | 0 | 5 (estimated) | 5 |
| swift-io/Experiments | 0 | 1 | 1 |
| swift-io/Research | 0 | 3 | 3 |
| swift-sockets/Sources | 0 | 3 | 3 |
| swift-sockets/Tests | 0 | 3 | 3 |
| swift-sockets/Research | 0 | 1 | 1 |
| swift-sockets facade | 0 | 1 | 1 |
| swift-file-system | 0 | 0 | 0 |
| swift-tests | 0 | 0 | 0 |
| swift-io-primitives (M4, speculative) | ~8 | ~1 | ~9 |
| **Total (Phases M1–M3)** | **2** | **26** | **28** |
| **Total (with M4)** | **10** | **27** | **37** |

The estimate is consistent with
[io-witness-capability-runner-split.md](io-witness-capability-runner-split.md)
§Cost accepted ("Estimate < 50 line diffs across swift-foundations") —
file count higher than line-count because each file is a small edit.

## 9. Implementation Contract

### 9.1 Exact Swift source for IO, Runner, Bound types

**File: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Core/IO.swift`**

```swift
//
//  IO.swift
//  swift-io
//
//  Shape F: capability witness. The IO witness exposes only I/O
//  operations (read, write, close, ready). Runner concerns (executor,
//  shutdown) live on IO.Runner. IO.Bound bundles both as a plain
//  Sendable struct for one-value consumer handoff.
//
//  See:
//  - Research/io-witness-shape-selection.md (DECISION)
//  - Research/io-witness-capability-runner-split.md
//

import Witnesses
import Memory_Primitives

/// I/O capability witness over per-strategy internal actor implementations.
///
/// Value-type capability object (Brachthäuser et al. 2020) wrapping async
/// throwing closures. Each stored closure is one I/O operation.
///
/// Runner concerns — executor binding, shutdown — live on ``IO/Runner``.
/// Consumers that need both (typical case) hold ``IO/Bound``.
///
/// ```swift
/// let bound = IO.blocking()
/// let n = try await bound.io.read(from: fd, into: buf)
/// try await bound.io.write(to: fd, from: data)
/// await bound.io.close(consume fd)
/// ```
///
/// ## Buffer Ownership
///
/// Same contract as prior Shape B: caller guarantees buffer addresses are
/// stable for the duration of `try await`. See ``IO/Bound`` documentation
/// or `Research/io-proactor-buffer-ownership.md` for the proactor's
/// cancellation-handshake guarantee.
///
/// ## Strategies
///
/// Factories live on ``IO/Bound``:
///
/// - ``IO/Bound/blocking(_:)`` / ``IO/Bound/blocking(on:)`` — dedicated OS
///   thread, POSIX syscalls.
/// - ``IO/Bound/events(on:)`` — kqueue/epoll reactor.
/// - ``IO/Bound/completions(on:)`` — io_uring proactor.
/// - ``IO/Bound/default()`` — host-adaptive.
///
/// ## Testing helpers
///
/// `@Witness(.mock)` generates `IO.unimplemented()` (trap on call) and
/// `IO.mock(read:write:close:ready:)` (fixed-return mock). `IO.observe`
/// wraps the witness with before/after hooks.
///
/// ## Theoretical Grounding
///
/// Witness = capability (Brachthäuser 2020). IO.Runner = runner (Ahman &
/// Bauer 2020, "Runners in Action" ESOP).
@Witness(.mock)
public struct IO: Sendable {

    /// Read bytes from a descriptor into a mutable buffer. Returns bytes read, or 0 at EOF.
    public let read: @Sendable (
        _ from: borrowing Kernel.Descriptor,
        _ into: Memory.Buffer.Mutable
    ) async throws(IO.Error) -> Int

    /// Write bytes from a buffer to a descriptor. Returns bytes written.
    public let write: @Sendable (
        _ to: borrowing Kernel.Descriptor,
        _ from: Memory.Buffer
    ) async throws(IO.Error) -> Int

    /// Close a descriptor. Ownership is consumed.
    public let close: @Sendable (consuming Kernel.Descriptor) async -> Void

    /// Wait for a descriptor to become ready for the requested interest.
    public let ready: @Sendable (
        _ from: borrowing Kernel.Descriptor,
        _ interest: Kernel.Event.Interest
    ) async throws(IO.Error) -> Void
}

// MARK: - Domain composition (Dvm)

extension IO {
    /// Re-encode this capability into a domain-specific witness.
    ///
    /// Used by domain packages (swift-sockets, swift-file-system) to build
    /// narrower witnesses on top of a base IO. The transform captures
    /// the base IO and calls its `ready`/`read`/`write`/`close` as needed,
    /// returning a domain witness value.
    ///
    /// ```swift
    /// extension Socket.IO {
    ///     public static func make(from io: sending IO) -> sending Socket.IO {
    ///         io.map { base in
    ///             Socket.IO(accept: { listener in
    ///                 try await base.ready(from: listener, interest: .read)
    ///                 // accept syscall
    ///             })
    ///         }
    ///     }
    /// }
    /// ```
    public func map<Domain>(_ transform: (IO) -> Domain) -> Domain {
        transform(self)
    }
}
```

**File: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Core/IO.Runner.swift`**

```swift
//
//  IO.Runner.swift
//  swift-io
//
//  Runner witness — scheduling and lifecycle evidence separate from the
//  pure-operations IO capability witness. Shape F (Ahman & Bauer 2020).
//

import Witnesses

extension IO {
    /// Runner concerns for an ``IO`` witness: the bound executor and the
    /// strategy's lifecycle shutdown.
    ///
    /// Separated from ``IO`` at the type level per Brachthäuser 2020: the
    /// capability witness exposes only I/O operations; lifecycle and
    /// scheduling evidence lives on the runner.
    ///
    /// ## Shared-executor pattern
    ///
    /// ```swift
    /// actor Server {
    ///     let bound: IO.Bound
    ///     nonisolated var unownedExecutor: UnownedSerialExecutor {
    ///         bound.runner.executor()
    ///     }
    /// }
    /// ```
    ///
    /// Forwarding the runner's executor to the consumer actor's
    /// `unownedExecutor` elides the per-call hop (TCA26 pattern).
    ///
    /// ## Shutdown
    ///
    /// `shutdown` is the canonical home for process-lifetime cleanup
    /// across all three strategies. See
    /// `Research/nio-inspired-capability-additions.md` P0.
    @Witness(.mock)
    public struct Runner: Sendable {
        /// The bound executor — forward from a consumer actor's
        /// `unownedExecutor` for zero-hop co-location.
        public let executor: @Sendable () -> UnownedSerialExecutor

        /// Tear down the backing strategy's resources. Idempotent.
        /// Callers that construct `IO.Bound` from a caller-owned executor
        /// (e.g., `IO.blocking(on:)`) receive a no-op shutdown; the
        /// caller owns the executor's lifecycle.
        public let shutdown: @Sendable () async -> Void
    }
}
```

**File: `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Core/IO.Bound.swift`**

```swift
//
//  IO.Bound.swift
//  swift-io
//
//  Plain struct composing the IO capability witness with its Runner.
//  Not a witness itself — no protocol, no existential.
//

extension IO {
    /// Capability + runner bundle. Consumers that need both halves
    /// (typical case: actors that store an IO for their lifetime) hold
    /// a single `IO.Bound` value.
    ///
    /// ```swift
    /// let bound = IO.blocking()
    /// let n = try await bound.io.read(from: fd, into: buf)
    /// await bound.runner.shutdown()
    /// ```
    ///
    /// ## Shared-executor pattern
    ///
    /// See ``IO/Runner`` documentation.
    ///
    /// ## Factories
    ///
    /// Each factory returns an `IO.Bound` backed by one of the three
    /// strategies (blocking / events / completions) or by the host-
    /// adaptive `default()` factory.
    public struct Bound: Sendable {
        public let io: IO
        public let runner: IO.Runner

        public init(io: IO, runner: IO.Runner) {
            self.io = io
            self.runner = runner
        }
    }
}
```

### 9.2 Exact public surface

**Factories on `IO.Bound`** (moved from `IO` to `IO.Bound` by this
decision — `IO` is no longer its own factory home):

```swift
extension IO.Bound {
    public static func blocking(_ pool: IO.Blocking = .shared) -> IO.Bound
    public static func blocking(on executor: Kernel.Thread.Executor) -> IO.Bound
    public static func events(on actor: IO.Event.Actor) -> IO.Bound
    public static func events() throws(IO.Event.Failure) -> IO.Bound
    public static func completions(on actor: IO.Completion.Actor) -> IO.Bound
    public static func completions() throws(Kernel.Completion.Error) -> IO.Bound
    public static func `default`() -> IO.Bound
}
```

**Witness-generated members** (auto-synthesised):

| Member | On | Purpose |
|--------|-----|---------|
| `IO(read:write:close:ready:)` | `IO` | Labeled init |
| `IO.Runner(executor:shutdown:)` | `IO.Runner` | Labeled init |
| `IO.unimplemented()` | `IO` | Trap-on-call factory |
| `IO.Runner.unimplemented()` | `IO.Runner` | Trap-on-call factory |
| `IO.mock(read:write:close:ready:)` | `IO` | Fixed-return mock (addendum §3.3) |
| `IO.Runner.mock(executor:shutdown:)` | `IO.Runner` | Fixed-return mock |
| `IO.Calls` enum + `Observe` wrapper | `IO` | Recording / observation |
| `IO.Runner.Calls` enum + `Observe` wrapper | `IO.Runner` | Recording / observation |
| `read(from:into:)`, `write(to:from:)`, `ready(from:interest:)` labeled methods | `IO` | Addendum §4.2: macro-synthesised for labeled closures |

**Domain-composition primitive**:

```swift
extension IO {
    public func map<Domain>(_ transform: (IO) -> Domain) -> Domain
}
```

**Witness.Key conformances** (to enable `Witness.Values` storage):

```swift
extension IO: Witness.Key {
    public static var liveValue: IO { .unimplemented() }
}
extension IO.Runner: Witness.Key {
    public static var liveValue: IO.Runner { .unimplemented() }
}
```

### 9.3 Shared-executor pattern example

```swift
import Sockets
import IO
import Kernel

actor Server {
    let bound: IO.Bound
    let listener: Sockets.TCP.Listener

    init(port: UInt16) async throws(Sockets.Error) {
        self.bound = IO.default()
        self.listener = try Sockets.TCP.Listener.reactive(
            address: .loopback(port: port),
            io: self.bound
        )
    }

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        bound.runner.executor()
    }

    func accept() async throws(Sockets.Error) -> Sockets.TCP.Connection {
        try await listener.accept()
    }

    deinit {
        // Note: actor deinits cannot call async functions directly.
        // The pattern is: detach a Task to call shutdown(), or use a
        // structured-lifetime wrapper. Shutdown is idempotent so
        // multiple calls are safe.
    }
}
```

### 9.4 Error model

Unchanged from current swift-io. `IO.Error` is a nested enum with cases:

```swift
extension IO {
    public enum Error: Swift.Error, Sendable, Equatable {
        case connectionReset
        case brokenPipe
        case notConnected
        case timeout
        case cancelled
        case shutdown
        case platform(Kernel.Error.Code)
    }
}
```

`IO.Runner`'s closures are non-throwing; no runner-specific error type is
needed in v1. If future runner operations need error reporting
(e.g., a `statistics` closure that could fail to read counters), a
nested `IO.Runner.Error` enum will be introduced at that point.

### 9.5 Test surface

Three mechanisms, all available post-migration:

**1. `IO.unimplemented()` / `IO.Runner.unimplemented()`** — generated by
`@Witness(.mock)`. Traps with `fatalError` on call. Used to construct
`IO.Bound(io: .unimplemented(), runner: .unimplemented())` as a test
scaffold; consumer under test overrides only the closures it exercises.

**2. `IO.mock(...)` / `IO.Runner.mock(...)`** — generated by
`@Witness(.mock)`. Takes fixed return values and synthesises closures
that return them. Useful for scalar-return scenarios; less useful when
the caller needs different returns per call.

```swift
let bound = IO.Bound(
    io: .mock(read: 42, write: 99, ready: ()),
    runner: .mock(executor: UnownedSerialExecutor.generic, shutdown: ())
)
```

**3. Hand-rolled witnesses** — the public init accepts explicit closures.
Use when call sequencing matters (e.g., "first read returns 100 bytes,
second returns 0"). Capture state in a closure or `Synchronization.Mutex`.

```swift
let state = Synchronization.Mutex<Int>(0)
let bound = IO.Bound(
    io: IO(
        read: { _, _ in state.withLock { $0 += 1; return $0 } },
        write: { _, _ in 0 },
        close: { _ in },
        ready: { _, _ in }
    ),
    runner: .unimplemented()
)
```

## 10. Future Extensions & Open Items

### 10.1 Generic error (GE) — deferred

**Deferred**. Trigger conditions for revisiting:

1. **Concrete consumer demand**: a downstream package (e.g., swift-sockets,
   swift-http, swift-tls) expresses the need for a statically-typed,
   domain-specific error at the `IO` witness surface — not catchable at
   the call site. Current evidence: no such package has asked.
2. **`mapError` region-inheritance limit resolved**: if Swift 6.4 or
   later lifts the region-inheritance constraint (addendum §3.2) such
   that `mapError` can return `sending IO<NewError>` without
   `LeafError: Sendable`, the primary structural objection to GE
   disappears.
3. **Cross-actor witness production pattern emerges**: if swift-io
   grows a pattern where a domain-specific `IO<E>` must be produced
   on one actor and sent to another (e.g., an HTTP connection pool
   creating per-request IO values with domain errors), GE becomes
   structurally necessary.

None of these conditions is met as of 2026-04-17. If/when they are, the
revisit produces:

- Promote `IO` from `@Witness(.mock) public struct IO` to `@Witness(.mock)
  public struct IO<LeafError: Swift.Error>`.
- Add `typealias BaseIO = IO<IO.Error>` for backward compatibility.
- Wire factories to produce `BaseIO` aliases.
- Update swift-sockets to use `IO<Sockets.Error>` + `.mapError { Sockets.Error(...) }`.

### 10.2 Domain witness map composition (Dvm) — adopted

Adopted alongside F (§7.5). Expected usage:

- `Socket.IO = IO.map { io in Socket.IO(accept: ...) }` — `accept`,
  `connect`, `shutdown` composed from base `io.ready` + direct syscalls.
- `File.IO = IO.map { io in File.IO(stat: ..., ...) }` — for any
  filesystem operations that need readiness waiting.

Alternative domains may adopt Dvm at their own cadence.

### 10.3 SPI escape hatch for proactor-native domain ops — deferred

Not in v1. If a domain witness needs access to io_uring-native operations
not exposed on `IO` (e.g., `IORING_OP_LINK_TIMEOUT` for chained
deadlines), an SPI escape hatch on `IO.Completion.Actor` would expose
it. For the base IO deadline (P2), see §10.7.

### 10.4 Runtime benchmarks — deferred (per parent §10)

The zoo sketches are compile-only. Measuring the per-op overhead of
Shape F vs Shape B in the actual `swift-io` compilation would require:

- Port one factory (`IO.blocking`) to Shape F; keep Shape B on another
  branch.
- Benchmark `IO.blocking().io.read(...)` vs `IO.blocking().read(...)`
  using `swift-foundations/swift-io/Benchmarks/io-bench/`.
- Measure allocation count per op (should be 0 additional) and latency
  delta (expected within noise).

**Expectation**: Shape F adds one struct-field access per call
(`bound.io.read` vs `io.read`). In Swift's optimisation regime, this
is trivially inlined. Benchmark at the first review horizon (§12.5).

### 10.5 mapError region-inheritance limit — revisit trigger

Currently confirmed-still-open (addendum §3.2). Revisit when:

- **A compiler fix**: Swift 6.4 or later resolves the region-
  inheritance issue. Track via `swift-6.3-fix-status.md`.
- **GE is adopted** (§10.1). If GE becomes live, the `mapError`
  limit becomes a load-bearing concern.

Until then, the limit is documented but does not block.

### 10.6 Stale comment cleanup

- `swift-io/Sources/IO Core/IO.swift:92–98`: the `@Witness(.mock)`-
  disabled comment is removed as part of Phase M1 (§8.2.1).
- Consider: any research docs referencing "Shape B's `_unownedExecutor`"
  should be updated to reference Shape F. §8.3.6 lists the candidates.

### 10.7 Deadline and vectored I/O (P2 from nio-inspired)

Under Shape F, each is adopted by adding one or more closures to `IO`
without touching `IO.Runner` or `IO.Bound`:

```swift
// Deadline overloads (SE style): new closures, one per operation.
extension IO {
    // In practice, either extend existing closures or add overloads.
    // Decision: add `readBy`, `writeBy`, `readyBy` closures with a
    // Duration parameter. Names TBD when P2 is designed.
}

// Vectored I/O: new closures with Memory.Buffer.Vector.
extension IO {
    // readv, writev, and optionally sendmsg/recvmsg.
    // Each is a new closure on the witness.
}
```

Adding closures to `@Witness` structs is a semver-minor change (new init
parameters added with defaults on the migration path). Shape F does not
make this easier or harder than Shape B would have.

## 11. Cross-Package Implications

### 11.1 swift-witnesses

**No changes required**. Per addendum §2, the macro has already been
updated (2026-04-17) to:

- Use storage names verbatim (no `_` stripping).
- Emit no deprecation attribute.
- Skip method synthesis for zero-arg closures (V5 collision class).

These are the exact conventions Shape F requires. The decision in this
document leverages — but does not mandate — any further macro changes.

Latent work (not blocking): the macro's `.mock` body still emits `(_, _)`
placeholders; Swift 6.3 compiler propagates ownership correctly (addendum
§3.3). If Swift 6.4+ changes inference, `.mock` might need updating. Not
actionable today.

### 11.2 swift-kernel

**No changes required for the Shape F decision itself.**

Future work (orthogonal, tracked in
[io-driver-witness-composition.md](../../Research/io-driver-witness-composition.md)):
`Kernel.Event.Driver` and `Kernel.Completion.Driver` witnesses may be
introduced at L1 as a lower-layer unification. These are consumed inside
`IO.Event.Actor` / `IO.Completion.Actor` — they do not appear on
`IO.Bound`'s public surface. Shape F is compatible with any such driver-
layer change because `IO.Bound` already abstracts over strategy internals.

### 11.3 swift-executors

**No changes required.**

`IO.Runner.executor: () -> UnownedSerialExecutor` is a Swift stdlib type.
The executors it names (`Kernel.Thread.Executor`, the Polling executor)
are in `swift-executors` and are unchanged by Shape F.

### 11.4 swift-sockets

**Phase 2 roadmap aligned**:

`swift-sockets/Research/sockets-phase-3-plan.md` references `io.ready`
and the `IO` witness throughout. Under Shape F, those references become
`bound.io.ready`. The research doc needs a minor revision (§8.3.6) but
no fundamental direction change.

`Sockets.TCP.Listener` and `Sockets.TCP.Connection` migrate mechanically
(§8.3.1).

### 11.5 swift-file-system

**No changes for v1**. swift-file-system uses `IO.Blocking.shared.run
{ ... }` exclusively — the `IO.Blocking` pool type, not the `IO` witness.
Shape F does not change `IO.Blocking`'s API.

If swift-file-system later wants to share an executor with an actor
(e.g., a file-system operation pinned to the same thread as a socket),
it would adopt `IO.Bound.blocking(on:)`. That adoption is deferred.

### 11.6 swift-io-primitives

**Open decision: populate now or defer?**

Current state: empty scaffold at
`/Users/coen/Developer/swift-primitives/swift-io-primitives/Sources/IO Primitives/`
contains only `@_exported public import Witness_Primitives`.

Under the five-layer architecture
(`swift-institute/Documentation.docc/Five Layer Architecture.md`), the
witness shape (`IO` + `IO.Runner` + `IO.Bound`) is **primitive
vocabulary**. The concrete factories (`blocking`, `events`, `completions`,
`default`) are **foundations** (Layer 3) because they depend on
`swift-kernel` and `swift-executors`.

Two options:

**Option A — populate now**:
1. Move the witness declarations to `swift-io-primitives`.
2. Add kernel-primitives + memory-primitives + witness-primitives
   dependencies.
3. swift-foundations/swift-io re-exports them via
   `@_exported public import IO_Primitives`.
4. Factories remain in swift-io (L3).

Pros:
- Correct layer placement per the five-layer architecture.
- Other L1/L2 packages could consume the shape directly.

Cons:
- Extra package to maintain.
- swift-io must update import paths.
- Not currently blocking anyone.

**Option B — defer**:
1. Keep the witness declarations in swift-io for now.
2. Leave `swift-io-primitives` empty.
3. Promote to L1 when (a) a non-swift-io package needs to consume the
   shape without adding a swift-io dependency, or (b) a general L1
   cleanup sweep happens.

Pros:
- Minimum moving parts.
- Keeps the migration scope bounded.

Cons:
- Mild layer-placement violation (deferred by choice).

**Recommendation**: **Option B (defer)** for the immediate migration.
The layer placement is noted; swift-io-primitives can be populated later
when there is a concrete consumer demand. This avoids coupling the Shape
F migration to a cross-repo move.

## 12. Decision Record

### 12.1 Author / reviewer

- **Decided by**: Claude (as research agent), author of this document.
- **Reviewer**: the user, who requested the selection per the task
  specification.

### 12.2 Date

2026-04-17.

### 12.3 Evidence

Direct evidence for the selection:

1. Parent analysis — [io-witness-shape-zoo-comparative-analysis.md](../../../swift-foundations/Research/io-witness-shape-zoo-comparative-analysis.md)
   v1.0 (4318 lines): the ten-shape comparative study with Kitchenham SLR
   methodology, Cognitive Dimensions scoring, and formal typing rules.
2. Addendum — [io-witness-shape-zoo-addendum.md](io-witness-shape-zoo-addendum.md)
   v1.0 (674 lines): Phase 2 experiments pinning the §6 unknowns.
3. Ten compile-verified experiments at `swift-primitives/Experiments/io-witness-*/`,
   all dated 2026-04-17.
4. Three Phase 2 experiments at `swift-foundations/swift-io/Experiments/witness-*/`.
5. Predecessor recommendation — [io-witness-capability-runner-split.md](io-witness-capability-runner-split.md)
   (weighted criteria, three-option comparison, Option F selected).
6. Production code reality — current Shape B at
   `swift-io/Sources/IO Core/IO.swift`, consumer use in
   `swift-sockets/Sources/Sockets/Sockets.TCP.Listener.swift`.

### 12.4 Alternatives considered and rejected

Summarised from §4:

- **Tk** — per-capability split. Rejected: usage pattern dominance (common
  case is bundle), build-time scaling (106.98s cold → worse than F's ~2.5s).
- **Z** — ZIO monadic. Rejected: hard constraint 7 (no executor-binding).
- **E** — scope form. Rejected: compounding `sending`-tax; subsumed by F's
  value-type capability.
- **M** — rental. Rejected: hard constraint 5 (region-checker rebind
  failure); tuple-~Copyable; ergonomic cost.
- **GO** — generic ops. Rejected: structurally redundant with Dvm.
- **DGS** — generic substrate. Rejected: strictly inferior to Dvm.
- **GE** — generic error. **Deferred** (not rejected); triggers in §10.1.
- **MG** — tooling property; kept as latent enabler for §10.1.

### 12.5 Expected review horizon

**Short-term review** — after Phase M1 is implemented:

- Run the swift-io test suite and benchmark the per-op overhead (§10.4).
- Confirm that every `Witness.*` operator works against the migrated
  `IO` and `IO.Runner` in practice (not just in the addendum's sketch).

**Medium-term review** — at the next `nio-inspired-capability-additions.md`
priority pass:

- When adopting P2 deadline / vectored I/O, verify that the witness
  extension pattern (§10.7) works at the production scale.

**Long-term review trigger — the "revisit GE" conditions in §10.1**:

- A downstream package expresses concrete demand for domain-specific
  typed errors at the `IO` surface.
- Swift 6.4+ lifts the `mapError` region-inheritance limit.
- A cross-actor witness-production pattern emerges.

**General revisit trigger — any future shape**:

- If a new witness shape appears that is not in the ten-shape zoo, the
  decision framework in §3.3 is extensible. Add the shape to the zoo,
  score it against the twelve weighted criteria, and amend this
  document.

## 13. References

### Parent and addendum (authoritative input)

1. [io-witness-shape-zoo-comparative-analysis.md](../../../swift-foundations/Research/io-witness-shape-zoo-comparative-analysis.md)
   — parent Tier 3 comparative analysis, 4318 lines.
2. [io-witness-shape-zoo-addendum.md](io-witness-shape-zoo-addendum.md)
   — Phase 2 findings and macro convention delta, 674 lines.

### Prior research (swift-io)

3. [io-witness-capability-runner-split.md](io-witness-capability-runner-split.md)
   — Option F proposal, weighted score 81.
4. [io-witness-design-literature-study.md](io-witness-design-literature-study.md)
   v4.0 — Shape B baseline; Brachthäuser / Ahman–Bauer grounding.
5. [io-blocking-executor-binding.md](io-blocking-executor-binding.md)
   v4.0 — shared-executor (TCA26) pattern rationale.
6. [perfect-api.md](perfect-api.md) v3.0 — Tier 0 `IO.run` consumer API.
7. [io-witness-borrowing-async-tension.md](io-witness-borrowing-async-tension.md)
   — language tension; unchanged by shape selection.

### Prior research (cross-package)

8. [io-vs-nio-comparative-analysis.md](../../Research/io-vs-nio-comparative-analysis.md)
   v1.0 — structural comparison with swift-nio.
9. [nio-inspired-capability-additions.md](../../Research/nio-inspired-capability-additions.md)
   v1.0 — P0/P1/P2 capability gaps; P0 (shutdown) subsumed by F.
10. [io-driver-witness-composition.md](../../Research/io-driver-witness-composition.md)
    — orthogonal lower-layer driver witness.

### Experiments (compile evidence)

11. `swift-primitives/Experiments/io-witness-shape-f/`
    — CONFIRMED, build time 1.27s.
12. `swift-primitives/Experiments/io-witness-domain-via-map/`
    — CONFIRMED (with caveats), build time 1.33s.
13. `swift-primitives/Experiments/io-witness-macro-generic-compat/`
    — CONFIRMED (surprise), build time 90.77s.
14. `swift-primitives/Experiments/io-witness-generic-error/`
    — CONFIRMED, build time 0.98s.
15. `swift-primitives/Experiments/io-witness-generic-ops/`
    — CONFIRMED (redundant), build time 0.67s.
16. `swift-primitives/Experiments/io-witness-domain-generic-substrate/`
    — CONFIRMED (inferior), build time 0.65s.
17. `swift-primitives/Experiments/io-witness-tokio-style/`
    — CONFIRMED, build time 106.98s.
18. `swift-primitives/Experiments/io-witness-zio-style/`
    — CONFIRMED (eliminated), build time 0.35s.
19. `swift-primitives/Experiments/io-witness-eio-style/`
    — CONFIRMED (eliminated), build time 1.23s.
20. `swift-primitives/Experiments/io-witness-monoio-style/`
    — CONFIRMED (eliminated), build time 0.58s.
21. `swift-foundations/swift-io/Experiments/witness-mock-borrowing/`
    — REFUTED (unexpected); mock works on IO-shape witnesses.
22. `swift-foundations/swift-io/Experiments/witness-recording-against-properties/`
    — CONFIRMED; all five operators storage-agnostic.
23. `swift-foundations/swift-io/Experiments/witness-maperror-sending-return/`
    — CONFIRMED-still-open; region inheritance intrinsic.

### Academic (cited in parent)

24. Ahman, D. & Bauer, A. 2020. "Runners in Action." ESOP 2020.
25. Brachthäuser, J.I., Schuster, P., & Ostermann, K. 2020.
    "Effects as Capabilities." OOPSLA 2020.
26. Schuster, P., Brachthäuser, J.I., & Ostermann, K. 2020.
    "Compiling Effect Handlers in Capability-Passing Style." ICFP 2020.
27. Xie, N. & Leijen, D. 2021. "Generalized Evidence Passing for
    Effect Handlers." ICFP 2021.

### Swift Evolution

28. SE-0390 Noncopyable Structs and Enums.
29. SE-0392 Custom Actor Executors.
30. SE-0413 Typed Throws.
31. SE-0414 Region-Based Isolation.
32. SE-0430 `sending` Parameter and Result Values.
33. SE-0458 Strict Memory Safety.
34. SE-0461 Run Nonisolated Async Functions on Caller's Actor by Default.

### Current production source (for migration inventory)

35. `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Core/IO.swift`
    (Shape B baseline, 209 lines).
36. `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Blocking/IO+Blocking.swift`
    (factory, 84 lines).
37. `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Events/IO+Events.swift`
    (factory, 54 lines).
38. `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Completions/IO+Completions.swift`
    (factory, 87 lines).
39. `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO/IO+Default.swift`
    (host-adaptive factory, 82 lines).
40. `/Users/coen/Developer/swift-foundations/swift-sockets/Sources/Sockets/Sockets.TCP.Listener.swift`
    (consumer, 239 lines).
41. `/Users/coen/Developer/swift-foundations/swift-sockets/Sources/Sockets/Sockets.TCP.Connection.swift`
    (consumer).

### User-memory feedback (relevant to this selection)

42. `feedback_no_sendable_constraint_workaround.md` — bears on GE's §6.8
    V3 cost, reason for deferring GE.
43. `feedback_sending_over_sendable_return.md` — underlies region-isolation
    friendly criteria (C11).
44. `feedback_language_features_over_custom_types.md` — borrowing /
    consuming / ~Copyable as first-class mechanism; bears on constraint 3.
45. `feedback_escapable_over_with_closures.md` — reinforces rejection
    of Shape E's scope form.
46. `feedback_prefer_typed_throws_over_try_optional.md` — reinforces
    constraint 4.

## Appendix A — Per-Criterion Scoring

Ten variants × twelve criteria, scored 1–10.

| | C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8 | C9 | C10 | C11 | C12 | W.Sum |
|-|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| F | 10 | 10 | 7 | 10 | 10 | 6 | 9 | 9 | 10 | 9 | 10 | 10 | **238** |
| F+GE | 10 | 10 | 5 | 9 | 10 | 4 | 9 | 6 | 10 | 8 | 7 | 10 | **215** |
| Tk | 10 | 9 | 6 | 10 | 10 | 5 | 8 | 4 | 10 | 9 | 10 | 9 | **218** |
| Tk+GE | 10 | 9 | 4 | 9 | 10 | 3 | 8 | 3 | 10 | 8 | 7 | 9 | **194** |
| Dvm (standalone) | 10 | 10 | 8 | 10 | 10 | 8 | 9 | 9 | 10 | 9 | 10 | 10 | **243** (composition over F) |
| Z | 10 | 9 | 4 | 3 | 6 | 3 | 7 | 10 | **0** | 5 | 8 | 7 | eliminated |
| E | 9 | 10 | 5 | 9 | 10 | 5 | 8 | 6 | 6 | 9 | 4 | 9 | eliminated (C3 compounding tax) |
| M | 8 | 7 | 3 | 3 | 6 | 2 | 4 | 8 | 6 | 4 | **0** | 6 | eliminated |
| GO | 10 | 9 | 4 | 2 | 6 | 3 | 6 | 8 | 8 | 5 | 7 | 5 | redundant with Dvm |
| DGS | 10 | 9 | 3 | 2 | 6 | 2 | 5 | 8 | 7 | 3 | 7 | 5 | inferior to Dvm |

Scoring conventions (addenda to parent §7.3 ordinal bands):

- **0** indicates a hard-constraint violation, not a low score.
- Compound shapes (F+Dvm, F+GE+Dvm) inherit F's score with small deltas
  (+2 for Dvm composition via `.map`, −varies for GE's generic parameter).
- The weighted sum uses the weights from §3.3 (High=3, Medium=2, Low=1).

## Appendix B — Migration Checklist

Ordered by dependency. Each line is one edit (or one merged commit).

### Phase M1 — swift-io internals

- [ ] Add new file `swift-io/Sources/IO Core/IO.Runner.swift` (§9.1).
- [ ] Add new file `swift-io/Sources/IO Core/IO.Bound.swift` (§9.1).
- [ ] Edit `swift-io/Sources/IO Core/IO.swift`: drop `unownedExecutor` closure;
      promote `@Witness` to `@Witness(.mock)`; drop lines 92–98 (stale comment);
      update docstring to reference `IO.Runner` and `IO.Bound`.
- [ ] Add `Witness.Key` conformances (`extension IO: Witness.Key`, `extension IO.Runner: Witness.Key`).
- [ ] Add `.map` extension on `IO` (§9.1).
- [ ] Edit `swift-io/Sources/IO Events/IO.Event.Actor.swift`: promote `func shutdown()`
      from deinit-only to `public`.
- [ ] Edit `swift-io/Sources/IO Completions/IO.Completion.Actor.swift`: promote
      `func shutdown()` to `public`.
- [ ] Edit `swift-io/Sources/IO Blocking/IO+Blocking.swift`: change factory
      return type from `IO` to `IO.Bound`; wire `runner.shutdown` to pool
      shutdown or no-op for explicit-executor overload.
- [ ] Edit `swift-io/Sources/IO Events/IO+Events.swift`: change return type to
      `IO.Bound`; wire `runner.shutdown` to actor shutdown.
- [ ] Edit `swift-io/Sources/IO Completions/IO+Completions.swift`: change return
      type to `IO.Bound`; wire `runner.shutdown` to actor shutdown.
- [ ] Edit `swift-io/Sources/IO/IO+Default.swift`: change return type to
      `IO.Bound`.
- [ ] Edit `swift-io/Sources/IO Core/exports.swift`: ensure `IO.Runner` and
      `IO.Bound` are re-exported.
- [ ] Edit `swift-io/Sources/IO/exports.swift`: ditto if needed.
- [ ] Edit `swift-io/Tests/IO Tests/*.swift`: update `io.unownedExecutor` →
      `bound.runner.executor()`; update `let io: IO` → `let bound: IO.Bound`
      as required.
- [ ] Edit `swift-io/Tests/IO Blocking Tests/*.swift`: mechanical updates.
- [ ] Edit `swift-io/Tests/IO Events Tests/*.swift`: mechanical updates.
- [ ] Edit `swift-io/Tests/Completions Support/*.swift`: mechanical updates.
- [ ] Run `cd swift-foundations/swift-io && rm -rf .build && swift build && swift test`.
      Verify all tests pass.

### Phase M2 — swift-sockets

- [ ] Edit `swift-sockets/Sources/Sockets/Sockets.TCP.Listener.swift`: change
      stored `_io` type from `IO` to `IO.Bound`; update `unownedExecutor`
      accessor to `_io.runner.executor()`; update `init` signatures on
      `blocking(address:io:backlog:)` and `reactive(...)`; update `accept()`
      to call `_io.io.ready(...)`.
- [ ] Edit `swift-sockets/Sources/Sockets/Sockets.TCP.Connection.swift`: same
      pattern; `io.read/write/close` → `io.io.read/write/close`.
- [ ] Edit `swift-sockets/Tests/Sockets Tests/Sockets.TCP.Listener.Tests.Echo.swift`:
      test call-site updates.
- [ ] Edit `swift-sockets/Tests/Sockets Tests/Sockets.TCP.Listener.Tests.MultipleConnections.swift`:
      test call-site updates.
- [ ] Edit `swift-sockets/Tests/Sockets Tests/Sockets.TCP.Listener.Tests.BlockingIdleCPU.swift`:
      test call-site updates.
- [ ] Edit `swift-sockets/Sources/Sockets/Sockets.swift` (if a facade exists):
      re-export `IO.Bound` if consumers need it.
- [ ] Run `cd swift-foundations/swift-sockets && rm -rf .build && swift build && swift test`.
      On Linux (Docker if needed), verify proactor tests pass.

### Phase M3 — documentation sync

- [ ] Update `swift-io/Sources/IO Events/README.md`: factory return types,
      shared-executor pattern example.
- [ ] Update `swift-io/Sources/IO Completions/README.md`: ditto.
- [ ] Update `swift-io/Research/perfect-api.md`: reference `IO.Bound` as
      internal type of `IO.run`.
- [ ] Update `swift-io/Research/io-witness-design-literature-study.md`:
      add supersession note at top.
- [ ] Update `swift-io/Research/io-witness-capability-runner-split.md`:
      change status from RECOMMENDATION to PROMOTED-TO-DECISION with back-
      reference to this document.
- [ ] Update `swift-sockets/Research/sockets-phase-3-plan.md`: reference
      `IO.Bound` and `_io.runner.executor()`.
- [ ] Update `swift-io/Research/_index.json`: add this document at the top
      with status DECISION.

### Phase M4 — swift-io-primitives (conditional, per §11.6)

Defer unless open decision §11.6 resolves to Option A.

### Phase M5 — post-migration checks

- [ ] `cd swift-foundations && rm -rf */.build && find . -name Package.swift -maxdepth 3 | xargs dirname | xargs -I {} bash -c 'cd {} && swift build'`
      — ecosystem-wide build verification.
- [ ] `swift test` across swift-io, swift-sockets, swift-file-system.
- [ ] `swift-foundations/swift-io/Benchmarks/run-benchmarks.sh` — verify no
      regression relative to Shape B (within noise).
- [ ] Update `swift-io-primitives` `_index.json` (if M4 happened).

### Phase M6 — reflection

- [ ] Invoke the **reflect-session** skill to capture lessons from the
      migration.
- [ ] Log any discovered issues into `swift-io/Research/Reflections/`.
- [ ] Consider promoting any reusable pattern into the **code-surface** or
      **implementation** skill corpora via **reflections-processing**.

## End of Document
