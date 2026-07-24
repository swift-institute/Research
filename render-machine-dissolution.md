# Render Machine Dissolution

<!--
---
version: 1.1.0
last_updated: 2026-07-24
status: DECISION
tier: 2
scope: cross-package
---
-->

> **Changelog — v1.1.0 (2026-07-24).** Three corrections to the factorization matrix, none
> affecting the primary decision. (1) The matrix now uses four verdicts rather than three,
> and axis 13 (Embedded viability) is reclassified from decomposition debt to a cross-cutting
> platform constraint. (2) The axis-1 claim is weakened: v1.0.0 called it "a theorem" and
> canonized the current CEK representation as inevitable; the defensible statement is that a
> value-producing computation requires result transport and result-sensitive continuation
> state while a command-emitting one does not, so their *minimal* execution states differ.
> "Never unify execution disciplines" becomes "do not unify the *current* ones." (3) Axes 8
> and 9 are reclassified from debt to **unproven commonality**: the input-checkpoint /
> speculative-render equivalence and the two-variant erased-payload design were both asserted
> ahead of their evidence. Tiers 1 and 2 become investigations rather than predetermined
> moves. Net tally change: 5 already-existing unadopted primitives (★) becomes 4.

## Context

**Trigger.** While scoping an institute port of a private CoreImage-based declarative
video framework, a proposal emerged to generalize `swift-render-primitives` so one
render machine could serve both documents and raster/video, by making the render
context generic over a "Vocabulary" of operations. The principal rejected "Vocabulary"
as an invented concept: L1 primitives stay close to pure/mathematical concepts rather
than minting bespoke abstractions. A follow-up look suggested the concept already
existed in the ecosystem twice over — as `swift-machine-primitives` (defunctionalization
generic over a `Leaf` set) and `swift-effect-primitives` (algebraic effects) — which
raised the question this document answers.

**Constraints.** The HTML rendering engine is required to build under Swift Embedded.
This constraint entered the investigation late (Round 5) and materially reframed the
analysis; it is recorded here as binding.

**Method.** Collaborative discussion with ChatGPT per [COLLAB-001]–[COLLAB-014], seven
rounds, CONVERGED. Full transcript: `/tmp/render-as-machine-transcript.md` (session-local).
Claude's analysis was primary per [COLLAB-014]; every claim entering a Position was
verified against source first.

**Skills loaded** per [RES-033]: swift-institute-core, swift-institute, code-surface,
modularization, package-export, collaborative-discussion, research-process.

## Question

Should `swift-render-primitives`'s bespoke execution machinery dissolve into
`swift-machine-primitives` (with `swift-effect-primitives` supplying naming), each
render domain supplying its own `Leaf` set — as `swift-parser-machine-primitives` and
`swift-binary-parser-primitives` already do?

Three sub-questions:

- **(a) MISSION.** Does `Machine`'s mission generalize to "defunctionalized program over
  an arbitrary leaf set," with the docs merely lagging the type?
- **(b) SHAPE FIT.** Do an arena-backed graph machine and a one-shot tree walk reconcile?
- **(c) EFFECT'S RUNTIME.** Can Effect supply operation-symbol / handler / outcome
  vocabulary without its continuation machinery?

And: if a *signature* concept is genuinely needed, what is the non-invented name?

## Analysis

### Premise audit

Four claims were inherited from a prior session. Two survived source; two did not.

| Claim | Verdict |
|---|---|
| `Machine` is defunctionalization generic over its operation set | **Verified**, with correction: the node case list also includes `.fold`, `.optional`, `.ref`, `.hole`. Two live instantiations exist — `Machine.Node<Leaf<Input,Failure>, Failure, Mode>` (Parser) and `Machine.Node<Instruction, Fault, Mode>` (Binary) |
| `Effect` is algebraic effects | **Verified**, with correction: `Effect.Handler.Sync` is `typealias Sync = __EffectHandler` — literally the async protocol under a second name. The package ships **no** synchronous handler shape |
| Render *independently reinvented* a narrower Machine | **Refuted as to independence.** `swift-render-primitives/Research/rendering-machine-handoff.md:127` cites `Parser.Machine.Run.swift` as "the parser machine execution loop **this is adapted from**" |
| The duplication tell: composition types hand-re-conformed in every consumer | **Largely refuted.** In `swift-html-render`, `HTML.Empty`/`HTML.Group` are *typealiases* to `Render.Empty`/`Render.Group`, and `_Tuple+HTML`/`_Conditional+HTML`/`_Array+HTML`/`Never+HTML`/`Optional+HTML` are one-line **empty-bodied** marker conformances. `swift-pdf-render` is the same. `swift-svg-render` typealiases `Render.Builder` and conformances the *shared* `Render._Tuple`/`Render.Conditional`. Only `SVG.Empty`, `SVG.Group`, `SVG.AnyView` are genuinely SVG-owned. `Render.Builder`'s doc comment describes shipping code, not an unmet aspiration |

### (a) MISSION — Machine's name overreaches its essence

`Machine.Frame<NodeID, Checkpoint, Mode, Failure, Extra>` takes `Checkpoint` as a
**mandatory** generic parameter, and four of ten cases store a `savedCheckpoint`. The
node algebra is a parser-combinator algebra: `.oneOf` is ordered choice (presupposing
failure and rewind), `.many` is Kleene star, `.fold` is star-with-accumulator, `.ref`
and `.hole` are recursive-grammar reference and forward-reference patching. `Machine.swift:1`
names the domain itself — *"defunctionalized machine-based **parsing** infrastructure."*

The documentation does not lag the type; it agrees with it. What overreaches is the
package and namespace name.

**However** (ChatGPT's Round-4 Concern 2, accepted): the current node algebra is *mixed*,
not uniformly PEG-specific. `.leaf`/`.pure`/`.map`/`.tryMap`/`.flatMap`/`.sequence`/`.ref`/`.hole`
are general graph-program constructs. The source therefore supports the narrower conclusion
that **`Machine.Node` combines a general defunctionalized computation core with
parser-specific alternative and repetition syntax** — and does not by itself decide
between "rename Machine" and "move the parser syntax outward." Either direction requires
correcting the defect; neither is settled here.

**Answer:** Machine's essence as currently written is *a backtracking, value-producing
recognizer over a rewindable cursor, represented as data*. Render's essence is *a single
LIFO walk of a statically-typed view tree emitting bracketed side effects, without
recursion*. Different questions ⇒ different packages under [ARCH-LAYER-010] / [ARCH-LAYER-014].
Render needs no merge and no sibling — it already is the sibling.

### (b) SHAPE FIT — two different abstract machines

The decisive evidence is the two interpreters. `Parser.Machine.Run.swift:96-140` and
`Binary.Machine.Run.swift:53-90` both declare and run the same shape:

```swift
var current = root                      // PROGRAM COUNTER over a graph
var pendingHandle: Value.Handle? = nil  // VALUE REGISTER
var frames = Stack<Frame>(...)          // CONTINUATION stack
var arena = Value.Arena(...)
while true {
    if let handle = pendingHandle { … pop a frame, apply it to the returned value … }
    switch program[current] { … push a frame, redirect the PC … }
}
```

`Render.Context._drain(above:)` has neither a program counter nor a value register:

```swift
while _stack.count > marker {
    switch _stack.removeLast() {
    case .render(let pointer, let thunk): thunk.dispatch(pointer, &self); thunk.destroy(pointer)
    case .action(let action):             interpret(action)
    case .frame(.closeScope(let action)): interpret(action)
    }
}
```

| | Render | Parser / Binary |
|---|---|---|
| Program source | existing typed value tree, traversed directly | frozen arena graph, built then interpreted |
| Stack holds | what executes **next** | continuations for **returned values** |
| Program counter | none | explicit `Graph.Node` PC |
| Result register | none | erased register + arena |
| Effects | synchronous emission | heterogeneous intermediate values |
| Lifetime | one-shot traversal | program intended for repeated execution |

**Answer:** the profiles do not reconcile. Generic `Leaf` does not bridge two different
execution models. Hosting Render on Machine would impose a program-materialisation pass
and a value channel for data that does not exist.

### (c) EFFECT — no

`Effect.perform.swift:1-4` states the implementation *"requires integration with a runtime
layer that provides the suspension/resumption coordination"*; `Effect.Perform` is an empty
marker enum. `Effect.Handler.Protocol.handle` is `async` and consumes an
`Effect.Continuation.One`. `Effect.Handler.Sync` is a typealias to that same async protocol.
`Effect.Context` is task-local storage over `Dependency.Scope`; `Render.Context` is a value
threaded `inout` through a synchronous call tree — same word, opposite mechanism.

Using the real protocols makes every render backend `async`. Using only the words misleads
a reader who expects resumable continuations and finds none.

**Answer:** no, on both branches.

### The Embedded constraint (entered Round 5)

`swift-render-primitives/Experiments/embedded-rendering-context/Package.swift:11` carries
`.enableExperimentalFeature("Embedded")`; `unified-rendering-context-architecture.md:1084`
records *"full architecture monomorphizes under `-enable-experimental-feature Embedded`
(E1-E8)"*. That document's Constraints section lists "No `any` types", "No `Mirror`",
"No `as?` runtime casts", "No `AnyObject`, `AnyHashable`" — each annotated *"embedded Swift"*.

**This reframes R1/R2** from `cooperative-pool-stack-overflow.md:518-519`. They are not a
performance model; they are Embedded-viability requirements. "No existentials" means
Embedded cannot compile them; "100% static dispatch" means Embedded requires full
monomorphisation. Under that reading, stored closures and raw-pointer thunks scoped to
the traversal are **fine** (they monomorphise; E1–E8 confirm it), while `any P` / `Any` /
`AnyObject` / `Mirror` / `as?` are fatal.

It also distinguishes the two erasures categorically rather than by degree: `Render.Thunk`
carries **no runtime type identity** (the concrete `Body._render` is baked into the closure
at construction), whereas `Machine.Value` stores `ObjectIdentifier` and performs a checked
projection. `swift-machine-primitives` has no Embedded validation — one incidental doc
comment, no experiment, no flag.

**The requirement is not currently met.** Five blocking sites, verified:

| Site | Construct |
|---|---|
| `Render.Context.swift:47` | `@usableFromInline var _applyInlineStyle: (Any) -> Bool` |
| `Render.Context.swift:67` | `applyInlineStyle: @escaping (Any) -> Bool = { _ in false }` |
| `Render.Context.swift:121` | `public func apply(inlineStyle property: Any) -> Bool` |
| `HTML.AnyView.swift:39` | `if let anyView = base as? HTML.AnyView` |
| `HTML.Element.swift:48` | `-> (any WHATWG_HTML.Element.\`Protocol\`.Type)?` |

Neither `swift-render-primitives` nor `swift-html-render` carries an Embedded flag in its
manifest, and neither has an Embedded CI job. `Render Primitive` is otherwise clean — a
sweep for `any P` / `AnyObject` / `AnyHashable` / `Mirror` / `as?` returns nothing else.

### Naming — no signature concept

A **signature** is the vocabulary of operation symbols with arities and typed input/output
relationships. A **witness** supplies implementations. These are different levels, and an
initial answer conflating them ("the ecosystem name is `Witness`") was withdrawn:
`Render.Context` is the witness; `Render.Action` is a partial reification of the vocabulary
(partial because `registerStyle` returns `String?` and `applyInlineStyle` returns `Bool`,
neither representable in the `Void`-returning action set).

The universal-algebra framing (signature Σ, Σ-algebra, free algebra, unique homomorphism)
models the *reified command sublanguage* accurately and the runtime as a whole inaccurately —
`View.body` runs arbitrary Swift, `Thunk` holds opaque function values, and the stack holds
continuation frames as well as actions.

**Decision:** introduce no L1 `Signature` / `Algebra` type. Reason: no current API quantifies
generically over operation vocabularies. Vocabulary settled as — *signature* in design
documents; *action* for the public recordable command subset; *context/witness* for
implementations; *traversal* for the document execution responsibility; *trampoline* for the
stack-avoidance technique.

### Factorization matrix

The converged rejection prompted a sharper question from the principal: is the
non-reuse absolute, or an artifact of incomplete decomposition? The matrix answers it.

#### The irreducible difference, stated at the right strength

A **value-producing** computation requires result transport and result-sensitive
continuation state. A purely **command-emitting** computation requires neither. Their
minimal execution states therefore differ intrinsically.

That is the defensible claim, and it is enough. An earlier draft (v1.0.0) overstated it as
*"this is a theorem"* and canonized the current CEK representation as mathematically
inevitable. It is not. A value-producing evaluator must represent the returned value, the
remaining computation, and the location being evaluated — but the choice to represent those
as an explicit program counter over a graph plus an erased value register is one design
among several: an instruction stream with an operand stack, typed continuation work items
carrying values directly, CPS with closures, a recursive evaluator, a stack machine,
direct-threaded instructions, homogeneous specialized registers, or a tree zipper in place
of a graph PC.

Symmetrically, a `Void`-returning traversal does not lose *all* continuation structure.
Render already has continuation-like frames — `Render.Machine.Frame.closeScope` defers a
bracket's close action past its children. What it loses is the need for **result-consuming**
continuations, which is why its stack can hold work items directly rather than
value-consuming closures.

So the correct rule is **"do not unify the *current* execution disciplines"**, not "never
unify execution disciplines." Their minimal control-state requirements differ intrinsically,
yet both may still compose from lower-level execution and ownership primitives, and a future
decomposition could discover a common stepping kernel without making either runtime
instantiate the other.

#### The matrix

Four verdicts, not three:

| Verdict | Meaning |
|---|---|
| **Intrinsic requirement** | The domains minimally require different capabilities |
| **Domain policy** | A legitimate choice that should remain selectable, not hardcoded into a shared algebra |
| **Shared infrastructure debt** | One concept, implemented repeatedly. ★ = the ecosystem primitive already exists and is simply unadopted |
| **Unproven commonality** | Strong resemblance; the semantic laws are not yet established |

| # | Axis | Parser / Binary | Render | Existing owner | Verdict |
|---|---|---|---|---|---|
| 1 | Execution discipline | CEK | worklist + non-result continuation frames | — | Intrinsic requirement (minimal control state), then domain policy |
| 2 | Failure | typed `Failure` / `Fault` + backtracking | none | language | Intrinsic requirement |
| 3 | Result transport | heterogeneous erased | none | — | Domain policy |
| 4 | Repeatability | build once, run many | one-shot | — | Domain policy |
| 5 | Program representation | `Graph.Sequential` | the view tree | swift-graph-primitives | Domain policy |
| 6 | Control stack | `Stack<Frame>` / bare `[Frame]` | bare `[Render.Work]` | **swift-stack-primitives** | Shared infrastructure debt ★ |
| 7 | Depth bounding | `maxDepth` + counter + `.recursiveExit` | n/a (heap-bounded) | **`Stack.Bounded`** | Shared infrastructure debt ★ |
| 8 | Checkpoint / rollback | `input.checkpoint` / `seek(to:)` | `Render.Speculative` closures | `Input.Protocol` (positional only) | **Unproven commonality** |
| 9 | Owned erased payload | `Value._Storage` + `_Table` | `Render.Thunk` | `Ownership.Unique` (typed case only) | **Unproven commonality**, over a shared ownership core |
| 10 | Slot storage + generational handles | `Value.Arena` + `Value.Handle` | — | **`SlotMap` + `Store.Generational.Handle`** | Shared infrastructure debt ★ |
| 11 | Typed handles | `Node.ID` typed, `Value.Handle.index` raw `Int` | — | **swift-index-primitives** | Shared infrastructure debt ★ |
| 12 | Cleanup discipline | `arena.reset()` | `_cleanupStack()` | `Ownership.Unique.deinit` | Shared infrastructure debt, probably via ownership |
| 13 | Embedded viability | unvalidated | validated, one blocker | — | **Cross-cutting platform constraint** |

**Tally: 2 intrinsic requirements, 3 domain policies, 5 shared-infrastructure debts (4 of
them ★), 2 unproven commonalities, 1 cross-cutting constraint.**

Axis 13 is deliberately *not* a decomposition verdict. Embedded viability is neither a
reusable concept nor a duplicated implementation — it is a platform capability constraint
every relevant primitive must satisfy. v1.0.0 miscategorized it as debt, which obscured its
nature.

**Axis 8 — the most promising claim, and the least proven.** `Input.Protocol` already
refines a separate `Streaming` protocol, so the *iteration* axis was correctly split out.
The checkpoint members were not:

```swift
// swift-input-primitives/Sources/Input Protocol Primitives/Input.Protocol.swift:66-100
public protocol `Protocol`<Element>: Streaming, ~Copyable {
    associatedtype Checkpoint: Comparable
    var checkpoint: Checkpoint { get }
    var bounds: ClosedRange<Checkpoint> { get }
    mutating func seek(to checkpoint: Checkpoint)
}
```

Nothing there depends on the state being an input cursor, and `Render.Speculative`
hand-rolls a strictly weaker interface for a related need. But v1.0.0 concluded too fast
that the two require the *same* capability and that these members should be lifted
unchanged. An input checkpoint is **positional and totally ordered**; speculative rendering
is **transactional** — begin, attempt output, measure fit, commit or roll back. Concrete
differences, several verifiable in source:

- Render must restore several coupled state components, not seek one ordered position.
- Its snapshot need not be meaningfully `Comparable`, so `bounds` may not apply.
- Valid checkpoints may form a stack rather than a total order.
- **Commit is semantically meaningful for render and vacuous for cursor seek.**
- Rollback must undo registrations and generated identifiers:
  `Render.Context._registerStyle` (`Render.Context.swift:46`) returns a *generated class
  name*, so a rolled-back speculative render must not leak it.
- `Render.Speculative.check(fit:)` is measure-and-conditionally-rollback, which has no
  analogue in `seek(to:)`.

The likely shape is a base capability with two refinements — positional (comparable
checkpoint, bounds, seek) and transactional (savepoint, rollback, commit) — under a name
from `Checkpointable` / `Restorable` / `Snapshot` / `Transaction` / `Savepoint`. Establishing
which is Tier 1's job; the protocol move is its possible *outcome*, not its premise.

**Axis 9 — one mechanism, two type-discrimination policies, and probably one shared core
rather than two symmetric variants.** `Render.Thunk` (pointer + `dispatch` + `destroy`, type
known to the function table) and `Machine.Value` (pointer + `destroy` + `ObjectIdentifier`,
type checked at runtime) are both *owned heap payload + statically-paired operations +
exact-once destruction*. The ecosystem owns the **typed** case
(`Ownership.Unique<Value: ~Copyable>`, "consume() and deinit are the only exits"); neither
erased variant exists.

But a two-variant design would be premature. The two façades support materially different
operations:

| Capability | Render payload | Machine value |
|---|---|---|
| Execute a type-specific operation | yes (`dispatch`) | no — via an external transform |
| Destroy | yes | yes |
| Recover an arbitrary concrete type | no | yes, checked projection |
| Runtime type identity | no | yes |
| Embedded viability | required | uncertain |
| Result transport | no | central |
| Stored operation table | `dispatch` + `destroy` | `destroy`, possibly copy/send |

The canonical shared primitive may therefore be only the lower ownership cell and its
destruction table, with Render and Machine owning distinct façades over it. That is still
valuable decomposition, and it is the axis most likely to be the real architectural centre.

#### `Machine` as three layers

The rejection exposed that `swift-machine-primitives` is a premature *product* of several
axes rather than a basis from which different machines compose. The corrective framing
distinguishes:

1. **`Machine` as the mathematical domain** — an explicit transition system, `step: State →
   Transition`. Under that mission both Parser and Render belong conceptually under Machine.
2. **Machine-form primitives** — established execution forms as siblings (Graph,
   Continuation, Worklist, Stack, Trampoline), existing **only where each owns substantive
   laws**, never merely a loop.
3. **Domain machines** — `Parser.Machine`, `Binary.Machine`, `Render.Document.Traversal`,
   a future `Raster.Traversal` — each supplying its own state and transitions.

`Render.Document.Traversal` need not be publicly nested under `Machine` at any point: the
conceptual classification can precede, and need not force, an API extraction.

## Outcome

**Status**: DECISION

### Settled negatives

1. `swift-render-primitives` does **not** dissolve into `swift-machine-primitives`. The
   current Machine algebra and runtime are value-producing, graph-addressed abstract-machine
   infrastructure and are not an appropriate representation for one-shot document traversal.
2. No `Machine.Value` channel for rendering.
3. No `swift-effect-primitives` dependency and no adoption of its vocabulary.
4. No public signature abstraction at L1.
5. SVG retains its own `View` and `Context`. Default no-op closures would make the type
   system *less* truthful — silent acceptance is not semantic support.
6. No generic traversal abstraction is extracted at this stage.

### Settled positives

7. Shared render composition remains under `Render`; document-specific concepts move under
   `Render.Document` (`View`, `Context`, `Action`, `Push`, `Pop`, `Break`, `Semantic`,
   `Style`, `Speculative`). Shared composition names are unchanged.
8. Execution state leaves the backend witness: `Render.Document.Context` becomes witness-only;
   a concrete `Render.Document.Traversal` owns LIFO work storage, marker-scoped draining,
   depth-first ordering, pending-value cleanup, and action/frame dispatch.
9. `Render.Machine` is removed. It is a **public** namespace whose sole member
   (`Render.Machine.Frame`) is `@usableFromInline` — it exports nothing, past [API-NAME-001a].
10. `Render.Document.Thunk` and the document work cases remain until a concrete replacement
    makes them dead.
11. *Trampoline* names the implementation technique; *Traversal* names the API responsibility.
    `Render.Executor` is rejected — it collides with Swift concurrency executors.
12. Embedded compatibility becomes an explicit acceptance criterion for the render path.

### Target shape (Stage A)

| Target | Contents |
|---|---|
| Render Composition Primitives | `Render`, `Builder`, `_Tuple`, `Conditional`, `Pair`, `Group`, `Empty` |
| Render Document Primitives | `Render.Document.{View, Context, Traversal, Work, Thunk, Action, Push, Pop, Break, Semantic, Style, Speculative}` |
| Render Primitives | umbrella re-export ([MOD-005]) |

`Render.Indirect` is excluded pending the ownership audit — its essence
("heap-allocated wrapper for an immutable value with shared ownership", breaking recursive
type definitions) matches `Ownership.Immutable<Value: ~Copyable & Sendable>` almost exactly.
`Ownership.Box` is **not** the match: its copy-on-write semantics let copies diverge on
mutation, which an immutable box must forbid. One gap remains — `Ownership.Immutable`
requires `Value: Sendable` (earning a *checked* conformance) where `Render.Indirect` permits
non-`Sendable` content behind `@unsafe @unchecked Sendable`. Resolve by census, not assumption.

### Traversal contract (to be stated before code moves)

Depth-first LIFO ordering; stepping may append further work; a marker-scoped drain completes
all work scheduled above the marker; work above a marker is atomic relative to later siblings;
pending owned view values are destroyed exactly once; cleanup runs on abnormal exit; a
traversal is one-shot per top-level render; traversal and backend context are synchronously
borrowed/`inout`; **no result register**; **no backtracking or graph program is implied**;
all execution and work representations compile under the supported Embedded configuration
with no existential storage, dynamic casting, reflection, or runtime type-identity dispatch;
work items may be `~Copyable`.

### Sequencing

**Embedded API repairs run as a parallel prerequisite branch, merged before Stage A is
declared complete.** They are a defect in force now and Stage A's acceptance criterion is a
clean Embedded build, so Stage A cannot be judged complete without them — but they are
independently reviewable and must not be entangled with the traversal refactor's
characterization tests. The `Any` channel cannot be replaced mechanically: a raw-pointer
substitute would avoid the spelling while recreating an open unsafe type channel.

**Stage B** remains evidence-driven. A second render domain is required as semantic evidence
for which traversal laws are genuinely render-general. This is not consumer counting barred
by [ARCH-LAYER-008]: that rule bars consumer count as an argument *against a correct
abstraction*, and is silent on how a mission boundary is *discovered*. A correct one-consumer
abstraction is extracted immediately; an unproven one is not yet an abstraction. As of today
no non-document invariant can be named that a generic traversal would own and
`Render.Document.Traversal` would not.

### Decomposition programme (answering the principal's follow-up)

Ordered by cost. [MOD-RENT] charges rent per package; a single over-parameterised generic
type would be the wrong shape.

- **Tier 0 — pure adoption, zero new concepts.** Axes 6, 7, 10, 11. `Machine` adopts
  `Stack`/`Stack.Bounded`, `SlotMap` + `Store.Generational.Handle`, and `Index<T>`; Render
  adopts `Stack`. Verify the semantic contracts first — notably whether
  `Store.Generational.removeAll()` matches `Machine.Value.Arena.reset()`'s whole-run
  invalidation, comparing *total reset semantics and cost*, not whether one integer increments.
  `SlotMap` already satisfies six of seven requirements from source: move-only by default
  (`.Shared` is the explicit CoW opt-in), `insert(consuming E) -> Handle`,
  `remove(Handle) -> E?`, `removeAll`, `contains`, and non-trapping failure — better than
  `Machine.Value.Arena`, which `fatalError`s on stale handles.
- **Tier 1 — a checkpoint/savepoint taxonomy investigation.** Axis 8. **Not** a
  predetermined protocol move. Establish the algebraic laws first — snapshot, restore,
  optional commit, nesting, ordering, bounds, resource invalidation — then decide whether
  `Input` and `Render` share a base capability with separate positional and transactional
  refinements, or whether their needs merely resemble one another. Lifting `Input.Protocol`'s
  members unchanged is one possible outcome, not the premise. Highest potential
  value-per-unit-change in the matrix, and the item most likely to be wrong if rushed.
- **Tier 2 — investigate owned erased payloads, starting from lifecycle laws.** Axis 9.
  Derive the shared laws (allocation, move-only ownership, exact-once destruction,
  deinitialization of abandoned work, function-table storage, projection policy,
  Embedded-compatible specialization) *before* proposing names or a variant split. The
  capability table above suggests the canonical shared primitive may be only the ownership
  cell and its destruction table, with Render and Machine owning distinct façades — not two
  symmetric variants of one type. Requires an Embedded compile test for the
  runtime-identity policy.
- **Tier 3 — decompose `Machine.Node`.** Axes 3, 4, 5. Separate graph representation, result
  transport, captures, repeatability, parser combinators, and general computational
  combinators, so that a machine needing none of them can still be a machine.
- **Out of scope.** Axis 1. Do **not** unify the *current* execution disciplines — their
  minimal control-state requirements differ intrinsically. This is not a permanent bar on any
  shared stepping kernel: a future decomposition could discover one without either runtime
  instantiating the other.

### Follow-on dispatches (not decided here)

- **Machine audit.** Parser-specific cases inside the nominally general node algebra;
  generational value storage; stack primitives; typed handles; capture-sharing vs transfer
  semantics; `~Copyable`/`~Escapable` opportunities; Embedded boundaries; move-only program
  and builder. Run as falsifiable experiments. The **first** experiment verifies rather than
  assumes the Embedded behaviour of `ObjectIdentifier`, generic metatype identity, and checked
  projection — recorded as a prospective-consumer bound, not a defect against Machine's
  current mission. Note that `swift-machine-primitives` predates the ecosystem's `~Copyable` /
  `~Escapable` / `sending` adoption: `~Copyable` appears in three source files, `~Escapable`
  in one type, `sending` **only in doc comments**. Whether `sending` permits collapsing
  `Capture.Mode.Reference`/`.Unchecked` is an open experimental question — `sending` expresses
  one-time transfer and does not by itself license repeated execution over shared captures,
  which is the arena design's whole point.
- **`Effect.Handler.Sync` correction.** The alias and its documentation are internally
  inconsistent. Four consumers in scope: `swift-effects`, `swift-cache-primitives`,
  `swift-parser-effect-primitives`, `swift-pool-primitives`.
- **`Render.Indirect` ownership census.** Enumerate instantiations across `swift-html-render`
  and `swift-pdf-render`; classify each `Content`'s Sendability; then choose between adopting
  `Ownership.Immutable`, correcting it to conditional Sendability, or adding a non-`Sendable`
  sibling. Do not retain a Render-owned box merely to avoid correcting the ownership layer.
- **Machine mission.** Whether `swift-machine-primitives` is renamed to match its parser
  essence, or its parser syntax moves outward leaving a neutral abstract-machine core, is
  undecided. Either direction corrects the [ARCH-LAYER-010] defect.
- **Continuous Embedded validation.** The architectural requirement is established; the
  experiment validated a representative slice; a continuously enforced package guarantee is
  absent. Add a production-representative Embedded CI job compiling the actual document and
  HTML path, so the property cannot silently regress again.

### [ARCH-LAYER-009] guards

Dissolution is **not** the outcome for `swift-render-primitives`, so the guards are not
engaged for the package. They apply narrowly, per removed concept:

1. Commit the functioning state (git-recoverable).
2. Introduce the replacement and migrate all call sites.
3. Remove only the superseded symbols.
4. Clean-build every affected package; run the full test matrix.
5. Confirm no stale source or product dependency remains (**verified dead**).

`Render.Machine` is removable immediately under this procedure. `Render.Thunk` is **not**
dead until a concrete replacement makes it so — arbitrary-depth traversal still requires
deferred ownership and typed dispatch. Moving composition files between targets does not
engage the dead-code guard.

## References

### Source (verified 2026-07-24)

- `swift-primitives/swift-render-primitives/Sources/Render Primitive/` — `Render.Context.swift`, `Render.Work.swift`, `Render.Thunk.swift`, `Render.View.swift`, `Render.Machine{,.Frame}.swift`, `Render.Builder.swift`
- `swift-primitives/swift-machine-primitives/Sources/` — `Machine.swift`, `Machine.Node.swift`, `Machine.Frame.swift`, `Machine.Program{,.Builder}.swift`, `Machine.Value.swift`
- `swift-primitives/swift-parser-machine-primitives/.../Parser.Machine.Run.swift` — the CEK loop
- `swift-primitives/swift-binary-parser-primitives/.../Binary.Machine.Run.swift` — the same loop
- `swift-primitives/swift-effect-primitives/Sources/Effect Primitives/` — `Effect.Handler{,.Sync}.swift`, `Effect.perform.swift`, `Effect.Context.swift`
- `swift-primitives/swift-input-primitives/.../Input.Protocol.swift` — the mis-homed checkpoint axis
- `swift-primitives/swift-slot-map-primitives/`, `swift-storage-generational-primitives/.../Store.Generational.swift`, `swift-ownership-primitives/.../Ownership.{Unique,Immutable,Box}.swift`, `swift-stack-primitives/`
- `swift-foundations/swift-html-render/Sources/HTML Rendering Core/`, `swift-foundations/swift-svg-render/Sources/SVG Rendering/`, `swift-foundations/swift-pdf-render/Sources/PDF Rendering/`

### Prior research

- `swift-render-primitives/Research/unified-rendering-context-architecture.md` (v2.2.0, DECISION, 2026-03-12) — the converged composition-decoupling decision and the Embedded validation (E1–E8)
- `swift-render-primitives/Research/cooperative-pool-stack-overflow.md` — the R1–R10 governing constraints
- `swift-render-primitives/Research/rendering-machine-handoff.md` — records the adaptation from `Parser.Machine.Run`
- `swift-render-primitives/Research/prior-art-view-tree-materialization.md` — OpenSwiftUI / Elementary survey

### Superseded

- `swift-institute/Research/danceui-architectural-analysis.md` — lists `swift-state-primitives` and `swift-driver-primitives` (neither exists), names the package `swift-rendering-primitives`, and describes `swift-render-primitives` as a paint/rendering substrate when it is a document render machine. **Do not plan from its table.**
