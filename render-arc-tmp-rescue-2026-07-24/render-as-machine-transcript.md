# Collaborative Discussion: Render as Machine

Started: 2026-07-24
Participants: Claude (Anthropic), ChatGPT (OpenAI)

Question: Should `swift-render-primitives`'s bespoke execution machinery dissolve
into `swift-machine-primitives` (+ `swift-effect-primitives` naming), each render
domain supplying its own Leaf set?

Context bundle: /tmp/render-machine-context.md (~19.1K tokens)
Round 1 file:   /tmp/render-as-machine-round-1-for-chatgpt.md (~26.3K tokens)

Full package exports (for reference):
  /tmp/swift-render-primitives-sources.swift   ~12,060 tokens
  /tmp/swift-machine-primitives-sources.swift  ~20,319 tokens
  /tmp/swift-effect-primitives-sources.swift   ~9,993 tokens
  /tmp/swift-svg-render-sources.swift          ~21,507 tokens

---

## Round 1 - Claude


### Position

**No merge. No Effect naming borrow. No new signature concept. The real defect is a target boundary, not a missing abstraction.**

#### Round-1 binding constraint ([COLLAB-002])

My position rests on two ratified constraints. If either is up for revision, my answer changes:

1. **The render path's governing constraint set R1–R10**, from `swift-render-primitives/Research/cooperative-pool-stack-overflow.md:518-527`. Load-bearing here:
   - **R1 — static dispatch (100%)**: *"No dynamic dispatch, no vtable lookups. Every `_render` call resolves at compile time. This is the foundation of the rendering architecture's performance model."*
   - **R2 — no existentials**: *"No `any View`, no `Any`, no protocol-typed storage. Existentials erase type information and introduce heap allocation + witness table indirection. Contradicts R1."*
   - **R3 — `~Copyable` support**, **R7 — arbitrary depth AND width** on a 544 KB cooperative pool stack.
2. **The 2026-03-12 DECISION** in `swift-render-primitives/Research/unified-rendering-context-architecture.md` (status: DECISION, tier 2): composition types (`Builder`, `_Tuple`, `Conditional`, `Pair`) are *unconstrained*, with per-domain conformances added conditionally; each render domain owns its own `View`/`Context`. That decision was reached through a prior collaborative discussion and validated by six experiments (`generic-rendering-context`, `borrowing-pattern-matching`, `embedded-rendering-context`, `embedded-style-extensions`, `conditional-copyable-conformance`, `vertical-slice-rendering`).

I am *not* treating either as unchallengeable — R1/R2 in particular are the crux, and if you think they are the wrong constraints, say so directly. But they are the base rate my cost calculus uses.

#### First: three of the four premises I was handed do not survive source

I verified every claim in my brief against source before it entered this position. Two survive, two do not.

**Claim 1 — Machine is defunctionalization generic over its operation set. VERIFIED, with a material correction.**

`Machine.swift:1-14` says exactly what was reported. Two live, independent instantiations exist:

```swift
// swift-parser-machine-primitives/.../Parser.Machine.Node.swift:9
public typealias Node = Machine_Primitives.Machine.Node<Leaf<Input, Failure>, Failure, Mode>
// swift-binary-parser-primitives/.../Binary.Machine.Node.swift:9
public typealias Node = Machine_Primitives.Machine.Node<Instruction, Fault, Mode>
```

The correction: the case list I was given (`.leaf/.pure/.map/.tryMap/.flatMap/.sequence/.oneOf/.many`) is **incomplete**. `Machine.Node` also has `.fold`, `.optional`, `.ref`, `.hole` (`Machine.Node.swift:44-63`). Those four are not incidental — see (a) below.

**Claim 2 — Effect is algebraic effects. VERIFIED, with a material correction.**

`Effect.Protocol` is an operation symbol with `Arguments`/`Value`/`Failure` (`Effect.Protocol.swift:45-57`). `Effect.Handler` is the interpretation (`Effect.Handler.swift:48-61`). `Effect.Outcome` is `resumed`/`threw`/`aborted` (`Effect.Outcome.swift:44-53`). `Effect.Context` is scoped registration over `Dependency.Scope` (`Effect.Context.swift:46-83`).

The correction: **`Effect.Handler.Sync` is not a synchronous handler.** It is `public typealias Sync = __EffectHandler` (`Effect.Handler.Sync.swift:33`) — literally the same async protocol under a second name, with a doc comment claiming synchronous applicability. There is no sync handler shape anywhere in the package. This is decisive for (c).

**Claim 3 — Render "independently reinvented" a narrower Machine. REFUTED as to independence.**

`swift-render-primitives/Research/rendering-machine-handoff.md:127` lists, under "Key files in other packages":

> `swift-parser-machine-primitives/Sources/Parser Machine Core Primitives/Parser.Machine.Run.swift` | Reference: the parser machine execution loop **this is adapted from**

The resemblance is genealogical and documented, not accidental convergence. That reframes the question: it is not "two teams built the same thing twice," it is "one team deliberately borrowed a loop shape and then narrowed it." The right question about a deliberate narrowing is whether the narrowing was correct — not whether the duplication was an accident.

The structural mapping is also looser than reported. `Render.Action` is *not* "the leaf set" in Machine's sense: a `Machine` Leaf **produces a value** that flows through `map`/`combine`/`finalize`; a `Render.Action` **produces a side effect** on a context and returns `Void`. That is not a narrower leaf set — it is a different kind of thing.

**Claim 4 — "the same composition types are hand-re-conformed in every render consumer." LARGELY REFUTED. This one matters most.**

I was told the duplication tell is `SVG._Tuple`, `SVG.AnyView`, `SVG.Empty`, `Never+SVG`, `Optional+SVG`, `HTML.AnyView`, `HTML.Empty`, `Never+HTML`, `_Array+HTML`. Source says:

- `swift-html-render/.../HTML.Empty.swift:13` — `public typealias Empty = Render.Empty`
- `swift-html-render/.../HTML.Group.swift:13` — `public typealias Group = Render.Group`
- `_Tuple+HTML.swift:14` — `extension Render._Tuple: HTML.View where repeat each Content: HTML.View {}` — **empty body**
- `_Conditional+HTML.swift:14`, `_Array+HTML.swift:14`, `Never+HTML.swift:14`, `Optional+HTML.swift:14` — all **one-line, empty-bodied marker conformances**

There is **zero re-implementation** in `swift-html-render`. `HTML.View: Render.View` (`HTML.View.swift:30`), so every `_render` is inherited. `swift-pdf-render` has the same shape. These files are the *sharing already working*, not evidence of its absence.

In `swift-svg-render`:
- `SVG.Builder.swift:9` — `public typealias Builder = Render.Builder`
- `SVG._Tuple.swift:8` — `extension Render._Tuple: SVG.View where ...` — a conformance on the **shared** type, not a redeclaration
- `SVG._Conditional.swift:8` — same, on shared `Render.Conditional`

Only `SVG.Empty`, `SVG.Group`, and `SVG.AnyView` are genuinely SVG-owned declarations. `Never+SVG`, `Optional+SVG`, `SVG._Array` are conformances of *stdlib* types, which Swift's nominal conformance system requires per protocol, per module, forever — no amount of Leaf-genericity removes them.

**So the duplication that motivated this entire investigation is about three small types in one package.** `Render.Builder`'s doc comment ("This allows the same builder to serve document rendering (`Render.View`), graphics rendering (`SVG.View`), and any future rendering domain") is not an unmet aspiration. It is a description of shipping code.

### (a) MISSION — Machine does not generalize; its *name* overreaches its essence

The framing I was given ("the docs lag the type") assumes the type is neutral and only the prose is parochial. Source says the **type** is parochial too.

**Evidence 1 — `Checkpoint` is a mandatory generic parameter of the frame type.**

```swift
public enum Frame<NodeID, Checkpoint, Mode, Failure: Swift.Error, Extra> {
    case oneOf(alternatives: [NodeID], index: Int, savedCheckpoint: Checkpoint)
    case many(child: NodeID, savedCheckpoint: Checkpoint, resultHandles: [Value<Mode>.Handle], finalize: Finalize.Array<Mode>)
    case fold(child: NodeID, savedCheckpoint: Checkpoint, accumulatorHandle: Value<Mode>.Handle, combine: Combine.Erased<Mode>)
    case optional(savedCheckpoint: Checkpoint, wrapSome: Transform.Erased<Mode>, noneHandle: Value<Mode>.Handle)
    // ...
}
```

Four of ten cases store a `savedCheckpoint`. A checkpoint is a *rewindable cursor position*. Machine does not merely permit backtracking — backtracking is in its frame vocabulary as a structural requirement.

**Evidence 2 — the node algebra is a parser-combinator algebra.** `.oneOf` is *"try alternatives in order until one succeeds"* — ordered choice, which presupposes failure and rewind. `.many` is Kleene star. `.fold` is star-with-accumulator. `.ref` and `.hole` are recursive-grammar reference and forward-reference patching. That is PEG, spelled as an enum.

**Evidence 3 — Machine's own doc names its domain.** `Machine.swift:1` — *"A namespace for defunctionalized machine-based **parsing** infrastructure."* The doc does not lag the type; it agrees with it. What overreaches is the *package and namespace name*, `Machine`, which promises generality the type does not deliver.

**Answer to (a):** Machine's essence is *"a backtracking, value-producing recognizer over a rewindable cursor, represented as data."* Render's essence is *"a single LIFO walk of a statically-typed view tree emitting bracketed side effects, without recursion."* Those are different questions, so under [ARCH-LAYER-014] (layer/identity follows essence) and [ARCH-LAYER-010] (strict mission) they are different packages. **Render needs no sibling and no merge — it already is the sibling.**

A secondary finding, which I raise because consistency demands it: by the same test I just applied to Render, **`swift-machine-primitives` has a mission-boundary defect of its own.** It is named for a general concept and delivers a specific one. That is a separate dispatch, not this session's question — but I will not argue "Machine is parochial" as a defence of Render and then decline to say so about Machine.

### (b) SHAPE FIT — the profiles do not reconcile; three structural mismatches, each independently fatal

**Mismatch 1: Machine requires a build phase. Render has no program to build.**

`Machine.Program.Builder` accumulates nodes into a `Graph.Sequential<...>.Builder` and `consuming func build()` produces the immutable `Program`. Interpretation runs *afterwards*, over node IDs. Render has no such artifact: the view tree **is** the program, and `_render` consumes it during the walk. Hosting Render on Machine means materialising every document as a node graph before emitting a single byte — a whole extra pass, with allocation proportional to document size, plus `Machine.Value` boxes for what is currently pure control flow.

Machine's arena design *amortises*: build one grammar, run it against many inputs. That is the correct trade for parsing. A document renders **once**. The amortisation denominator is 1, so the build cost is pure loss.

**Mismatch 2: `Machine.Value` is a type-erased heap box. R1 and R2 forbid exactly that.**

```swift
public struct Value<Mode> {
    let type: ObjectIdentifier
    let storage: _Storage          // final class holding UnsafeMutableRawPointer
}
public static func make<T: Sendable & ~Copyable>(_ value: consuming T) -> Machine.Value<Mode> {
    let payload = UnsafeMutablePointer<T>.allocate(capacity: 1)   // heap alloc per value
    ...
}
public subscript<T: ~Copyable>(as type: T.Type) -> T {
    _read {
        precondition(self.type == ObjectIdentifier(T.self), ...)   // runtime type check
        yield unsafe _project(type).pointee                        // assumingMemoryBound
    }
}
```

This is an existential in all but spelling: erased type identity, heap allocation, runtime-checked projection. R2 forbids it by name (*"Existentials erase type information and introduce heap allocation + witness table indirection"*). Render's `Render.Thunk` is the opposite construction — its `dispatch`/`destroy` closures are **monomorphised at construction** per concrete view type (`Render.Thunk.swift:17-28`), so every dispatch is a static call through a known function. That is R1 satisfied by design.

Note also `Machine.Value<Mode.Reference>.make<T: Sendable>` — Reference mode **requires Sendable payloads**. `Render.View` types carry no such constraint. `Mode.Unchecked` escapes it, at the price of surrendering the Sendable guarantee wholesale.

**Mismatch 3: Render produces no values at all.**

Machine's entire middle layer — `Transform.Erased`, `Combine.Erased`, `Next.Erased`, `Finalize.Array`, the `Value.Arena` and its ABA-guarded handles — exists to move **result values** between frames. Render's drain loop moves nothing:

```swift
mutating func _drain(above marker: Int) {
    while _stack.count > marker {
        let work = _stack.removeLast()
        switch work {
        case .render(let pointer, let thunk):
            unsafe thunk.dispatch(pointer, &self)
            unsafe thunk.destroy(pointer)
        case .action(let action):    interpret(action)
        case .frame(let frame):
            switch frame { case .closeScope(let action): interpret(action) }
        }
    }
}
```

Three cases, no value plumbing, no failure path, no checkpoint. Hosting this on Machine means instantiating `Failure = Never`, `Checkpoint = Never`, `Mode = Unchecked`, and leaving `.oneOf`/`.many`/`.fold`/`.optional`/`.ref`/`.hole` present-but-unreachable in a hot switch.

**Answer to (b):** the profiles do not reconcile. Hosting Render on Machine imposes a materialisation pass, per-value heap boxing, and runtime type checks on a path whose three governing constraints (R1, R2, R3) each independently forbid one of them. I did not measure, because the argument is structural and measurement would only price a change that is already ruled out on correctness grounds ([ARCH-LAYER-008]).

### (c) EFFECT — borrowing only the naming is a misuse; the answer is no

`Effect.perform.swift:1-4` is explicit that the implementation *"requires integration with a runtime layer that provides the suspension/resumption coordination"*; `Effect.Perform` is an empty marker enum. `Effect.Handler.Protocol.handle` is `async` and takes `consuming Effect.Continuation.One`. And as noted above, `Effect.Handler.Sync` is a typealias to that same async protocol — the package ships no synchronous handler shape.

So there are exactly two options, and both fail:

1. **Use the real protocols.** Every render backend becomes an `async` handler consuming a one-shot continuation. Rendering is synchronous; this is a non-starter.
2. **Borrow only the words.** Rename `Render.Action` → an "Effect", `Render.Context` → a "Handler". But a reader who knows `Effect.Handler` expects `handle(_:continuation:) async` and resumable control flow, and will find neither. Borrowing a vocabulary while discarding its semantics is *worse* than an honest new name, because it actively misleads. The scoping model differs too: `Effect.Context` is task-local storage over `Dependency.Scope`; `Render.Context` is a value threaded `inout` through a synchronous call tree. Same word, opposite mechanism.

**Answer to (c):** No. Effect cannot supply the vocabulary without the continuation machinery, and taking the vocabulary alone is a misuse.

### The naming question — the concept exists, it is called a **witness**, and Render.Context already is one

I claim no signature concept is needed. But the question deserves a direct answer rather than a dodge, so: **if one were needed, the non-invented name is not from universal algebra. It is `Witness`, and the ecosystem already owns it.**

`swift-witness-primitives` (L1) and `swift-witnesses` (L3) both exist. A "signature reified as a value — one operation per field, supplied by the domain" is precisely what the ecosystem calls a witness. And `Render.Context` **is** one: [API-IMPL-017] describes the migration that produced it as *"converting a protocol to a witness struct with stored closures,"* citing `Rendering.Context` by name.

So the universal-algebra framing would be both **over-abstraction** and **a synonym**: `Σ` for something already called a witness, `Σ-algebra` for something already called a witness *instance*, and "the unique homomorphism from the free algebra" for `_drain(above:)`. Under "no invented concepts at L1 — prefer an existing ecosystem name first," `Witness` wins outright and `Σ` never gets its turn. Introducing `Render.Signature` or `Render.Algebra` would also collide with [API-NAME-001a]: whatever nest held it would hold one type.

### The real defect: `swift-render-primitives` is one target fusing two semantic domains

Having refuted the merge, I owe a positive finding, and there is one — just not where I was pointed.

`Render Primitive` is a **single target** containing both:

| Domain-neutral composition | Document interpretation |
|---|---|
| `Render.Builder` | `Render.View`, `Render.Context` |
| `Render._Tuple`, `Render.Pair`, `Render.Conditional` | `Render.Action{,.Push,.Pop,.Break}` |
| `Render.Group`, `Render.Empty` | `Render.Push`, `Render.Pop`, `Render.Break` |
| `Render.Indirect` | `Render.Style`, `Render.Semantic.{Block,Inline,List}` |
| | `Render.Work`, `Render.Thunk`, `Render.Machine.Frame`, `Render.Speculative` |

The left column serves every render domain. The right column is one domain's vocabulary. They are two concepts in one target, which is exactly what [MOD-DOMAIN] asks about: *"Is this a concept, or just code?"* — and here there are two concepts.

The consequence is concrete and already being paid: `swift-svg-render` imports `Render_Primitives` to reach `Render.Builder` and `Render._Tuple`, and thereby links the entire document machine — `Render.Context`'s twelve stored closures, `Render.Action`, `Render.Thunk`, the LIFO drain loop — none of which it calls. Any future non-document domain (raster/video is the live motivating case) pays the same toll.

**Proposed split** — target boundaries only, no type renames:

- `Render Primitive` — `Render` namespace + composition: `Builder`, `_Tuple`, `Pair`, `Conditional`, `Group`, `Empty`, `Indirect`. Zero dependencies. This is the [MOD-017] singular root target holding namespace + foundational types.
- `Render Document Primitives` — `View`, `Context`, `Work`, `Thunk`, `Machine.Frame`, `Action.*`, `Push`, `Pop`, `Break`, `Style`, `Semantic.*`, `Speculative`, plus the `Render.View` conditional conformances on the composition types and on `Array`/`Optional`.
- `Render Primitives` — umbrella re-exporting both ([MOD-005]).

The `Render.View` conformances move to the document target. That is [MOD-004] constraint isolation working as intended, and needs no `@retroactive` since it is same-package ([API-IMPL-018]).

This is the [ARCH-LAYER-008] answer: the split is right because the target currently spans two domains, independent of how many consumers would benefit.

### On the motivating case (CoreImage-based declarative video)

The port does not need a Vocabulary parameter, a Leaf set, or a signature concept. It needs what SVG already does: its own `Raster.View` and `Raster.Context`, plus `typealias Builder = Render.Builder` and conditional conformances on the shared `Render._Tuple` / `Render.Conditional` / `Render.Pair`. That is the 2026-03-12 decision applied to a third domain. The target split above is what makes it cost one dependency instead of the whole document machine.

### On [ARCH-LAYER-009]'s two guards

My answer is **not** dissolution, so the committed-first and verified-dead guards are **not engaged** for `swift-render-primitives`. I state this explicitly because my brief asked me to name them if the answer were dissolution. They *would* apply to the target split only in the trivial sense that files move between targets within one package — no code is removed, so nothing needs to be proven dead.

### Agreements

(First round — none yet.)

### Concerns

1. **My own strongest counter-argument, which I want you to press.** The 2026-03-12 rationale for keeping SVG separate says forcing SVG through document methods *"would produce a meaningless mapping (what is `pushBlock(role: .paragraph)` for a circle?)"* — but that was written when `Rendering.Context` was a **15-method protocol**. It is now a **witness struct whose closures are almost all defaulted** (`Render.Context.swift:57-83`). Under a defaulted-closure witness, SVG would supply only `push.element(tagName:block:void:preformatted:)`, `set(attribute:)`, `text`, `write(raw:)` and leave the document closures as no-ops — and `<circle cx="10"/>` maps onto exactly that. **The old rationale may not survive the protocol→witness migration.** I now think SVG's real reason for separateness is different and narrower: `SVG.View._render` is generic over the output buffer (`into buffer: inout Buffer where Buffer.Element == UInt8`), whereas `Render.View._render` captures the buffer inside the context's closures. That is a genuine incompatibility, but it is a *plumbing* incompatibility, not a *vocabulary* one. If you think that is surmountable, the SVG-migration question is live and I want to hear it.

2. **The document types arguably overclaim the `Render` namespace**, by the same test I applied to `Machine`. `Render.Context`'s vocabulary is document structure; SVG and raster get their own. Should the right column become `Render.Document.View`, `Render.Document.Context`, and so on — leaving `Render.*` for what is genuinely shared? It passes [API-NAME-001a] (many types). It is a large rename across three L3 packages. Under [ARCH-LAYER-008] cost is not a reason to decline, but I am genuinely unsure whether it is *correct* or merely *symmetric*, and I have deliberately not asserted it.

3. **I have not measured anything.** My (b) argument is entirely structural. I judged measurement not worth its cost because the change is already excluded on correctness grounds, but if you think a measurement would change the answer rather than just price it, name the specific measurement.

4. **`Render.Context.apply(inlineStyle property: Any) -> Bool`** (`Render.Context.swift:121`) takes `Any`, in a package whose R2 forbids `Any`. It is a pre-existing escape hatch unrelated to this question, but I am flagging it rather than pretending the constraint set is perfectly upheld.

### Proposals

1. **Reject the merge.** `swift-render-primitives` does not dissolve into `swift-machine-primitives`. Grounds: (a) different essence, (b) three independently fatal shape mismatches.
2. **Reject the Effect naming borrow.** Grounds: (c) — the package ships no synchronous handler shape, and taking the words without the semantics misleads.
3. **Introduce no signature concept.** If one were ever needed the ecosystem name is `Witness`, not `Σ`; and `Render.Context` already is one.
4. **Split `Render Primitive` into a composition target and a document target**, with `Render Primitives` as umbrella. This is the actual correctness finding.
5. **Record separately** that `swift-machine-primitives`' name overclaims its essence ([ARCH-LAYER-010]). Not this session's decision to make, but it should not go unrecorded.
6. **Leave SVG alone pending Concern 1.** If the witness-struct migration really does dissolve the old rationale, that is a separate investigation with its own evidence bar.

### Questions

1. Do you accept that `Checkpoint` as a mandatory `Machine.Frame` parameter, plus `.oneOf`/`.many`/`.fold`/`.optional`/`.ref`/`.hole`, make Machine's node algebra a *parser* algebra rather than a neutral program algebra? If not, what would a genuinely neutral defunctionalized-program algebra look like, and how would it differ from what Machine has?
2. Is there a formulation of "host Render on Machine" that avoids `Machine.Value` entirely — i.e. a `Leaf` whose result type is `Void` and a `Mode` that skips the arena? If so, what would remain of Machine that Render would actually be *using*, beyond the node-graph storage it does not want?
3. On Concern 1: does the protocol→witness-struct migration invalidate the 2026-03-12 "SVG cannot use Rendering.Context" rationale? Is the buffer-genericity difference decisive, or is it plumbing?
4. On Concern 2: is `Render.Document.*` correct, or merely symmetric with my critique of `Machine`?
5. Have I mis-weighted anything by treating the R1/R2 constraint set as binding? Those constraints are the reason Machine's design is disqualified. If you think R2 in particular is over-strict for a rendering path, that is the single argument most likely to move my position.

### Status: EXPLORING

---

## Round 2 - ChatGPT

(pasted by user; see session transcript — Position: reject wholesale merge and Effect dependency, keep a lower-level `Machine.Trampoline` extraction open under a strict concept test; Render target needs a three-way split because `Render.Context` fuses backend witness with execution runtime. Status: NARROWING)
## Round 3 - Claude

### Position

**Merge rejected (unchanged). Trampoline extraction rejected — on new empirical evidence, not on the argument I gave in Round 1. Three-way Render split accepted. `Render.Document.*` accepted. Machine's own audit is larger than either of us said, and I have concrete ecosystem replacements for most of its bespoke machinery.**

I concede five of your eleven concerns outright, one partially, and hold three with new evidence. Taking them in the order that changes the most.

---

### Concessions

**C1 — R1/R2 were applied inconsistently. You are right; I withdraw the framing.**

You are correct that `Render.Thunk` is manual type erasure — raw pointer plus a two-function table — and that thunk *selection* is a runtime-indirect call. A strict reading of R1 ("every `_render` call resolves at compile time") and R2 ("no protocol-typed storage… heap allocation + witness table indirection") condemns the current implementation. I cannot use those constraints as vetoes while the code violates them.

Two things sharpen this, and both cut against my Round-1 use of them:

The constraint doc's own recommended fix was **"Option F (closure render queue)"** — `cooperative-pool-stack-overflow.md` §Recommendations: *"Ship F + C. Option F addresses depth (the dominant cause)."* The authors selected a stored-closure work queue as the R1/R2-compatible answer. And R4 carries the only explicit carve-out in the table: *"Internal implementation may use `@escaping` if scoped to the traversal mechanism."*

So the honest operational reading, answering your Q3 directly:

| | Permitted | Forbidden |
|---|---|---|
| Stored closure calls | **Yes**, scoped to the traversal mechanism (R4's carve-out; Option F is the selected design) | At the API boundary — `body`, `@Builder` blocks, view initialisers |
| Raw-pointer + function-table erasure | **Yes**, of the *view type*, to defer it | Of the *view protocol* — no `any View`, no protocol-typed storage |
| Heap allocation | **Yes**, to achieve arbitrary depth (R7 requires it; R3+R7+R9 is named as the "key tension" whose only resolution is heap storage) | Per-operation on the emission path |

R1/R2 are about **the view protocol's dispatch**, not about every indirect call in the package. Under that reading Render complies and my Round-1 use of them was overbroad.

**And the argument against `Machine.Value` does not need R1/R2 at all.** Here is the version that survives your critique:

Render's erasure is of **one thing** — the view type — and its cardinality is *the number of deferred composite views*. `Machine.Value`'s erasure is of **a different thing** — result values — and its cardinality in a parsing run is *every intermediate result*. For Render, the number of result values is **zero**. Adding `Machine.Value` would not swap one erasure for another; it would introduce a data channel for data that does not exist. That is the argument, and it stands on semantics rather than on a constraint I was over-reading.

**C2 — `Witness` names the interpretation side, not the operation vocabulary. You are right; I conflated two levels.**

A signature is the vocabulary of operation symbols with their arities and typed input/output relationships. A witness/algebra/dictionary supplies implementations. `Render.Context` is the witness. `Render.Action` is a *partial reification of the vocabulary* — and only partial, per your point 6, which I also accept.

`Witness` therefore does not answer the naming question for the operation set. My Round-1 answer was wrong on the reasoning even though we agree on the conclusion. The correct reason to introduce no public `Signature` type is the one you gave: no current API needs to quantify generically over signatures.

**C3 — `Void`-producing does not disqualify a leaf.** I overstated "a different kind of thing." `Void` is a legitimate result type and a one-shot machine need not have a result channel. The correct, narrower objection is yours: *the current `Machine.Node` assumes value-producing composition throughout its algebra* — `.map`, `.tryMap`, `.sequence`'s `combine`, `.many`'s `finalize`, `.fold`'s accumulator all thread a value. Instantiating that algebra at `Void` leaves most of it inert.

**C4 — `Checkpoint` alone is not fatal.** `Checkpoint = Never` makes those frame cases uninhabited, exactly as `Extra = Never` is already designed to do. My argument rests on the algebra, not the type parameter, and I withdraw the parameter as independent evidence. I also withdraw the "residual hot-switch overhead" implication — that was an unmeasured code-generation claim.

**C5 — "SVG links the entire document machine" is unmeasured; I withdraw it.** SVG acquires a source-module and build dependency on the document machinery under the current target layout. That is an architectural fact and it is sufficient for the split under [MOD-DOMAIN]. Whether the symbols survive dead-stripping I did not measure and the argument does not need.

**C6 (partial) — the universal-algebra correspondence is only partial, and your list is right.** `registerStyle` returns `String?`, `applyInlineStyle` returns `Bool`, `Thunk` holds opaque function values, `View.body` runs arbitrary Swift, and the stack holds continuation frames as well as actions. `Render.Action` reifies only the homogeneous `Void` subset. Calling `_drain` "the unique homomorphism from the free algebra" overstates it, and I withdraw that phrasing. Universal algebra models the *reified command sublanguage* accurately and the runtime as a whole inaccurately.

---

### Agreements (beyond the concessions)

**A1 — `Render.Machine` is a naming defect. Verified, and it is worse than you inferred from the export.**

```swift
// Render.Machine.swift:9
public enum Machine {}
// Render.Machine.Frame.swift:8-15
@usableFromInline
enum Frame { case closeScope(Render.Action) }
```

`Render.Machine` is a **public** namespace whose sole member is **internal**. It exports nothing at all. That is past [API-NAME-001a] (namespace-holding-one-type) into "public namespace with no public content." It should not survive in that shape regardless of how the larger question resolves.

**A2 — `Render.Context` fuses the backend witness with the execution runtime. My split was incomplete; yours is better.**

```swift
public struct Context: ~Copyable {
    @usableFromInline var _stack: [Render.Work] = []   // ← the runtime
    public var text: (String) -> Void                   // ← the witness
    public var push: Render.Push
    // … eleven more backend closures …
}
```

Those are two responsibilities in one type, and `_drain(above:)`, `_cleanupStack()`, `_reverseAbove(_:)`, `open(push:pop:)` all live on the witness because the stack does. I adopt the three-way decomposition.

**A3 — `Render.Document.*` is semantically justified, not merely symmetric.** Your framing settles my Round-1 Concern 2: if `Render` is the cross-domain home of composition primitives, then document-only types sitting directly under it overclaim their scope, and the rename is a correctness fix rather than a symmetry gesture. Applies to `View`, `Context`, `Action`, `Push`, `Pop`, `Break`, `Semantic`, `Style`, `Speculative` — **not** to the shared composition types.

**A4 — SVG's separation is semantic, not just plumbing.** You are right that default no-op closures make the type system *less* truthful, not more accommodating: an SVG context that silently accepts `push.list(kind:.ordered, start:)` and `break.page()` is lying about what it supports. Silent acceptance is not semantic support. I withdraw the suggestion that the protocol→witness migration reopened this, and I accept that the buffer-genericity difference is secondary rather than decisive.

**A5 — `Effect.Handler.Sync` is internally inconsistent and should be corrected independently of this decision.** Agreed on both halves.

**A6 — `Render.Indirect` needs an essence analysis rather than assignment-by-grouping.** Agreed, and I now have the answer — see E2 below.

---

### Concerns — where I hold, with new evidence

**#1 — Your Q1 answered: the Trampoline extraction fails empirically. Parser and Binary are not trampolines.**

You asked for the actual interpreters. I read both in full. They have the same structure as each other, and it is not Render's.

`Parser.Machine.Run.swift:96-140` and `Binary.Machine.Run.swift:53-90` both declare:

```swift
var current = root                    // ← a PROGRAM COUNTER over a graph
var pendingHandle: Value.Handle? = nil // ← a VALUE REGISTER
var frames = Stack<Frame>(...)         // ← a CONTINUATION stack
var arena = Value.Arena(...)
var depth = 0
```

and both run this shape:

```swift
while true {
    if let handle = pendingHandle {          // a value came back —
        pendingHandle = nil                  // pop a continuation and apply it
        let value = arena.release(handle)
        if frames.isEmpty { return value[as: Output.self] }
        switch frames.pop() { case .map(let t): pendingHandle = arena.allocate(t.apply(…)) … }
        continue
    }
    switch program[current] {                // no value pending — advance the PC
    case .map(let child, let t): frames.push(.map(transform: t)); current = child
    …
    }
}
```

That is a **CEK-style abstract machine**: program counter, value register, continuation stack, driven by graph lookup. The frame stack holds *"what to do with the value when it comes back"*.

Render's loop has **no program counter and no value register**:

```swift
mutating func _drain(above marker: Int) {
    while _stack.count > marker {
        switch _stack.removeLast() {
        case .render(let pointer, let thunk): thunk.dispatch(pointer, &self); thunk.destroy(pointer)
        case .action(let action):             interpret(action)
        case .frame(.closeScope(let action)): interpret(action)
        }
    }
}
```

Its stack holds *"what to do next"*. That is a **worklist scheduler**, not a continuation machine.

Now apply this to the six responsibilities you proposed for `Machine.Trampoline<Work>`:

| Responsibility | Render | Parser | Binary |
|---|---|---|---|
| LIFO work scheduling | yes | **no** — PC + continuation stack | **no** |
| Scoped drain above a marker | yes (`_drain(above:)`) | **no** — unwinds to a *recoverable frame*, not a depth | **no** |
| Deferred continuation work | yes (`.frame(.closeScope)`) | yes (every frame) — different shape | yes |
| Deterministic cleanup of owned pending work | yes (`_cleanupStack` destroys orphaned pointers) | via `arena` generation bump | via arena |
| Max depth / work-count enforcement | **no** — bounded by heap, not stack | yes (`maxDepth` + `.recursiveExit`) | yes |
| Synchronous stepping over domain-owned `Work` | yes | **no** — steps over `Node`, fetched by PC | **no** |

Only row 3 is shared, in three different shapes. So the extraction would not factor anything Parser and Binary already have in common — it would mint a concept whose only implementation is Render's. That is not [ARCH-LAYER-008] consumer-counting; it is that the *premise of the extraction* — "Parser, Binary and Render share a trampoline lifecycle" — is false.

Applying your own concept test: strip Render's `Thunk`, action interpretation, and frame cases back into Render, and what remains is `Stack<Work>` + `while stack.count > marker { step(stack.pop()) }` + a cleanup hook whose destroy operation is domain-supplied. **Reject under [MOD-DOMAIN]** — by your criterion, not mine.

**But your Concern 7 still lands**, and I want to separate the two things you bundled. "Get the stack out of the witness" is correct. "Put it in `swift-machine-primitives`" does not follow. See Proposal 2.

**#2 — I accept your reframing of Machine's mission defect, and the audit is larger than either of us said.**

You are right that I did not distinguish *"Machine is really parser machinery"* from *"Machine is the abstract-machine domain and parser syntax has leaked inward."* Your split of the cases is fair: `.leaf`/`.pure`/`.map`/`.tryMap`/`.flatMap`/`.sequence`/`.ref`/`.hole` are general graph-program constructs; `.oneOf`/`.many`/`.fold`/`.optional` plus checkpoint-bearing frames are recognizer syntax. I do not need to settle which direction the fix runs to reject the Render merge, and I withdraw the claim that I had settled it.

**Two new inputs materially change what that audit should cover.**

*First — `swift-machine-primitives` predates the ecosystem's `~Copyable` / `~Escapable` / `sending` adoption, and much of its bespoke machinery may be a workaround for a Swift that no longer exists.* Current adoption is thin: `~Copyable` appears in only three source files (`Machine.Value`, `Machine.Value.Arena`, `Machine.Program.Builder`); `~Escapable` appears in exactly one type (`Machine.Value.Ref`); `sending` appears **only in doc comments**, never in a signature. The package carries its own removal notes:

```swift
// Machine.Value.swift:44 — on _Storage: @unchecked Sendable
// WHEN TO REMOVE: When compiler gains structural Sendable through raw pointers.

// Machine.Capture.Mode.Unchecked.swift:8
/// `sending` parameters at the program-transport boundary — not via
/// [a structural Sendable conformance]
```

Concretely, three candidates for the audit:

- **The whole `Machine.Capture.Mode.Reference` / `.Unchecked` dichotomy** exists to split "payloads must be `Sendable`" from "payloads need not be." `Machine.Value<Mode.Reference>.make<T: Sendable>` versus `Machine.Value<Mode.Unchecked>.make<T>` is the entire difference, duplicated across `Transform.Erased`, `Combine.Erased`, `Next.Erased` and `Finalize.Array` as paired initialisers. Region-based isolation with `sending` at the transport boundary is precisely the feature that dissolves that dichotomy — and the package's own doc already says that is where it should go. **Collapsing `Mode` would remove a generic parameter from `Node`, `Program`, `Frame`, `Value` and all four carriers.**
- **`Machine.Value`'s existence.** `Machine.swift:4-6` says the package exists *"enabling zero-copy parsing with Swift 6's `~Escapable` types where the lifetime checker rejects closures at abstraction boundaries."* `Machine.Value` heap-boxes and type-erases because a value could not be carried across a frame boundary otherwise. `Machine.Value.Ref<T>: ~Copyable, ~Escapable` with `@_lifetime(borrow self)` already exists as a partial adoption. Whether a fuller `~Escapable` design removes the box is a real question I cannot answer without an experiment.
- **`Machine.Node` / `Program` are `Copyable`** and could be move-only under the `~Copyable` regime the rest of the ecosystem now uses.

*Second — three of Machine's hand-rolled types already exist in the ecosystem.* Detailed in the inventory below; the headline is that `Machine.Value.Arena` + `Machine.Value.Handle` are a reimplementation of `SlotMap` + `Store.Generational.Handle`.

**#3 — On the empirical comparison (your Proposal 8).** I accept the benchmark shape and the acceptance criteria. But since #1 rejects the trampoline prototype, there is no candidate to compare against, and I would rather not build one to disprove a concept whose premise I have now falsified. If you still want it built after reading the two run loops above, say so and name what it would settle that the loops do not.

---

### Ecosystem inventory — types neither of us can see from the exports

You are working from source I selected; several of your open questions turn on what the ecosystem already owns. Here is what I found. `swift-primitives` has roughly 200 packages, so treat this as targeted rather than exhaustive.

**E1 — `Machine.Value.Arena` and `Machine.Value.Handle` are a hand-rolled `SlotMap`.**

`swift-slot-map-primitives` ships `SlotMap<E>` (front door over the hoisted `__SlotMap<S: ~Copyable>`), documented as:

> HANDLES, not positions, are the slot map's identity: `insert` mints a `(index, generation)` `Store.Generational.Handle`; `remove` bumps the slot's generation so outstanding handles to it go stale; access validates.

And `swift-storage-generational-primitives` ships:

```swift
extension Store.Generational {
    @frozen public struct Handle: Hashable, Sendable {
        public let index: Int
        public let generation: Int
    }
}
```

Compare `Machine.Value.Handle`: `(index: Int, generation: UInt32)`, `Hashable, Sendable`. Same type, hand-rolled, with a narrower generation width. `Machine.Value.Arena` is `[Machine.Value<Mode>?]` with a bump `nextSlot`, a generation counter, `allocate`/`read`/`release`/`reset`, and `fatalError` on stale handles — which is `SlotMap`'s contract with worse ergonomics. **This is a concrete answer to your Proposal 3's carrier audit**: `Value.Arena` and `Value.Handle` are not part of a coherent reusable typed-program representation. They are duplicated infrastructure.

`SlotMap` also composes over an explicit ownership column — `SlotMap<E>` is move-only by default, `SlotMap<E>.Shared` is CoW — so adopting it is simultaneously the `~Copyable` adoption the package is missing.

**E2 — `Render.Indirect` is `Ownership.Box`, and this answers your Q6.**

`Render.Indirect<Content: ~Copyable>` is a `final class` with `public let value: Content`, immutable after construction, ARC-managed, conditionally `Sendable`. Its stated purpose is to bound per-level type size by moving the payload to the heap.

`swift-ownership-primitives` ships:

```swift
extension Ownership {
    /// A heap-allocated copy-on-write cell — the single copy-on-write box of the ownership layer.
    /// `Box` is the copy-on-write sibling of ``Ownership/Unique`` (the exclusive `~Copyable`
    /// cell), mirroring Apple's `Swift.Box` / `Swift.UniqueBox` split — SE-0517 reserves bare
    /// `Box` for exactly this copy-on-write variant.
    public struct Box<Value> { … }
}
```

plus `Ownership.Unique<Value: ~Copyable>` (exclusive ownership, deterministic cleanup), `Ownership.Slot`, `Ownership.Transfer`, `Ownership.Immutable`, `Ownership.Latch`.

So the honest answer to your Q6: **`Render.Indirect` is not rendering-specific.** It is a heap box whose invariant ("immutable after construction, `~Copyable` payload") is `Ownership.Box`'s or `Ownership.Immutable`'s. It should be audited against those rather than assigned to a render target at all — the essence question you raised resolves *outside* `Render`.

There is a further thread I have not pulled: `Render.Work.render(pointer:thunk:)` is a raw pointer with a manual `destroy` — exclusive ownership with deterministic cleanup, which is `Ownership.Unique`'s stated contract. Whether `Ownership.Unique` can carry a `~Copyable` view across the work stack the way the raw pointer does, I have not verified.

**E3 — `Stack` exists, and its use is inconsistent across all three loops.**

`swift-stack-primitives` ships `Stack<E: ~Copyable>` (front door over `__Stack<S: ~Copyable>`) with `push`/`pop`/`top`/`count`/`isEmpty`, plus `Stack.Bounded` and a typed `Stack.Error`. Parser's run loop uses it (`internal import Stack_Primitives`; `var frames = Stack<Frame>(minimumCapacity:)`). **Binary uses a bare `[Frame]` with `reserveCapacity`. Render uses a bare `[Render.Work]`.** Same package family, three different stack representations. `Stack.Bounded` is also the obvious home for the depth-limit enforcement Parser and Binary hand-roll with `maxDepth` + a `depth` counter.

**E4 — typed indices exist.** `swift-index-primitives` ships `Index<T>` (a `Tagged` ordinal, per [IDX-001]). Inside `swift-machine-primitives` itself, `Machine.Node.ID` is `Graph.Node<Self>` — a typed index — while `Machine.Value.Handle.index` is a bare `Int`. That inconsistency is internal to one package.

**E5 — `swift-effect-primitives`' consumers, for the record**, since your Proposal 6 touches it: `swift-effects` (L3 runtime), `swift-cache-primitives`, `swift-parser-effect-primitives`, `swift-pool-primitives`. Correcting `Effect.Handler.Sync` is a four-consumer change, not a zero-consumer one.

---

### Proposals (revised)

1. **Reject the merge.** Unchanged, but now resting on: (a) the algebra assumes value-producing composition throughout and Render has no values, not on `Checkpoint`; (b) Machine is a PC+value-register graph machine and Render is a worklist scheduler.

2. **Reject the `Machine.Trampoline` extraction; accept the responsibility separation it was reaching for, inside Render.** Extract the executor out of `Render.Context` — but to the **render-composition** target, not to `swift-machine-primitives`, and generic over the work type:
   - `Render.Context` keeps only the backend witness (the twelve closures).
   - The executor owns `Stack<Work>`, `drain(above:)`, cleanup-on-abort, and the deferred-close bracket, parameterised over a domain-supplied `Work` and `step`.
   - It sits beside `Render.Builder` as the second render-domain-neutral facility: `Builder` is neutral *composition*, the executor is neutral *traversal*. A raster/video domain that builds deep trees gets both without touching the document vocabulary — which is exactly the reuse your Concern 7 wanted, delivered without a false claim about Parser and Binary.
   - Naming: **not** `Render.Machine`, which per A1 is already a defective namespace and would now overclaim twice. I do not have a name I am confident in and would rather converge on the shape first.

3. **Audit `swift-machine-primitives` along four boundaries, not three.** Yours: neutral execution / graph-program representation / erased carriers / parser syntax. Add a fourth, cutting across all of them: **which machinery exists only because `~Copyable`, `~Escapable` and `sending` were unavailable when it was written.** Concretely — collapse `Capture.Mode.Reference`/`.Unchecked` under region-based isolation with `sending` at the transport boundary (removing a generic parameter from `Node`, `Program`, `Frame`, `Value` and four carriers); re-examine whether `Machine.Value`'s box survives a fuller `~Escapable` design given `Value.Ref` already exists; replace `Value.Arena`/`Value.Handle` with `SlotMap`/`Store.Generational.Handle` per E1. This is a separate dispatch — but it changes the answer to "which carriers survive the audit," which you deliberately left open.

4. **Split Render three ways.** Composition (`Builder`, `_Tuple`, `Conditional`, `Pair`, `Group`, `Empty`) + neutral traversal executor / Document (`Render.Document.*`: `View`, `Context`, `Action`, `Push`, `Pop`, `Break`, `Semantic`, `Style`, `Speculative`, `Thunk`) / umbrella. `Render.Indirect` leaves the package pending the E2 audit rather than joining composition. `Render.Machine` is deleted; its `Frame` becomes a case of the executor's work type or of a document-owned continuation type.

5. **`Render.Document.*` for document-specific types**, shared composition names unchanged. Accepted as you framed it.

6. **Effect stays out.** Agreed in full, including that `Effect.Handler.Sync` is corrected separately — with E5's four consumers in scope.

7. **No public signature abstraction.** Agreed, for your reason rather than mine. On your naming shortlist: `Action` is right for `Render` precisely because it *is* externally meaningful — `Render.Action` is a public, `Sendable`, recordable/spliceable value (`Context.splice(_:)`, `Context.interpret(_:)`), not merely machine fuel. `Instruction` would be right if it were consumed only by the executor, which it is not.

8. **Defer the benchmark** — see Concern #3. No candidate exists to measure.

9. **[ARCH-LAYER-009] applies to the executor extraction.** Agreed and unchanged: commit the working state, land the replacement, remove `Render.Work`/`Render.Thunk`/`Render.Machine`/the drain loop from `Render.Context`, then clean build + full test run as the dead-code proof. Moving composition files between targets does not engage the guard; removing the bespoke executor does.

---

### Questions

1. Having seen both run loops — do you accept that `Machine.Trampoline` would have no implementation in Parser or Binary, and that the extraction premise is falsified? If you still want it, is the argument now "it is a good concept on its own merits with one user" rather than "it factors shared machinery"? Those need different justifications and I would answer them differently.

2. Given E1 (`SlotMap` + `Store.Generational.Handle` already exist) and the `sending`/`~Escapable` angle in Proposal 3 — does your Proposal 3 audit still expect `Value`, `Capture` and the transform carriers to form a coherent reusable typed-program representation? My reading is that `Value.Arena`/`Handle` are duplicated infrastructure and `Capture.Mode` is a pre-`sending` workaround, which leaves `Value` itself and the four `Erased` carriers as the only genuine candidates.

3. On Proposal 2: is a render-domain-neutral traversal executor, generic over `Work`, living beside `Render.Builder`, an acceptable resolution of your Concern 7 — or do you think neutral traversal has to leave the `Render` namespace entirely to be honest about its scope?

4. What should the executor be called? It is not a `Machine` (that name is taken and defective here), not a `Trampoline` (that word implies the Parser/Binary shape it does not have). Candidates I am unsatisfied with: `Render.Executor`, `Render.Traversal`, `Render.Schedule`, `Render.Worklist`. `Worklist` is the most literally accurate and the least established.

5. Does `Render.Indirect` leaving the package for `Ownership.Box`/`Ownership.Immutable` follow from E2 in your view, or do you see a rendering-specific invariant in it that I have missed?

### Status: NARROWING


---

## Round 4 - ChatGPT

(pasted by user; see session. Position: merge rejected, Effect excluded, `Render.Document.*` and `Render.Machine` removal accepted; accepts that Parser/Binary do not share Render’s worklist model, closing the Machine.Trampoline extraction; REJECTS Claude’s generic executor in the composition target; proposes staged Stage A (concrete `Render.Document.Traversal`) / Stage B (extract only after a second render domain); retains "trampoline" as technique classification; pushes back on `sending` dissolving Capture.Mode, `~Escapable` removing Machine.Value, and `Ownership.Box` matching Render.Indirect. Status: NEAR_CONSENSUS)
## Round 5 - Claude

### Position

**Stage A accepted in full. `Trampoline` naming concession accepted. All six of your factual questions answered from source — two of them change the picture.**

**A new binding constraint has entered the discussion that neither of us had, and it is load-bearing enough that I am restating it before anything else: the HTML rendering engine is required to build under Swift Embedded.**

That constraint retroactively explains R1/R2, decisively settles the `Machine.Value` question on grounds stronger than either of us used, and — I have to report — reveals that the requirement is **not currently met**. Concrete blocking sites below.

I concede your Concerns 1, 2, 3, 4, 5, 7, 8, 10 and 11, and hold none against you. This round is mostly convergence plus evidence.

---

### The Embedded constraint

Verified: `swift-render-primitives/Experiments/embedded-rendering-context/Package.swift:11` carries `.enableExperimentalFeature("Embedded")`, and `unified-rendering-context-architecture.md:1084` records the outcome — *"**Embedded Swift**: full architecture monomorphizes under `-enable-experimental-feature Embedded` (E1-E8)."* The same research doc's Constraints section lists, verbatim:

> - No `any` types (existential containers) — embedded Swift
> - No `Mirror` — embedded Swift
> - No `as?` runtime casts — embedded Swift
> - No `AnyObject`, `AnyHashable` — embedded Swift

**This reframes R1/R2 entirely.** I presented them in Round 1 as a performance model and conceded in Round 3 that they were being applied inconsistently. Both readings were wrong. R1 and R2 are **Embedded-viability requirements wearing performance clothing**. "No existentials" is not a preference about witness-table indirection — it is that Embedded Swift *cannot compile* them. "100% static dispatch" is not an optimisation target — it is that Embedded requires full monomorphisation.

So the honest operational reading, superseding my Round-3 table:

| | Embedded verdict |
|---|---|
| Stored closure calls in the traversal | **Fine** — closures monomorphise under Embedded; E1–E8 confirm the whole architecture does |
| Raw pointer + function-table erasure of the *view type* | **Fine** — `Render.Thunk`'s two fields are specialised at construction per concrete view type; no metadata, no witness table |
| Heap allocation for arbitrary depth | **Fine** — Embedded supports classes and allocation |
| `any P`, `Any`, `AnyObject`, `Mirror`, `as?` | **Fatal** — not compilable |

This is why your Round-4 Agreement 3 lands where it does, and it is a firmer footing than the reading I gave.

**It also settles `Machine.Value` on a ground neither of us used.** `Machine.Value` is not merely a heavier erasure than `Render.Thunk` — it is an erasure of a *kind Embedded cannot express*:

```swift
let type: ObjectIdentifier                              // metatype identity of an arbitrary T
precondition(self.type == ObjectIdentifier(T.self), …)  // runtime type comparison
yield unsafe _project(type).pointee                     // assumingMemoryBound under that check
```

`ObjectIdentifier(T.self)` over an unconstrained generic is runtime type metadata. Render's thunk carries *no* type identity at runtime — the concrete `Body._render` is baked into the closure at construction and the pointer is untyped precisely because the function already knows the type statically. That is the difference between the two erasures, and under Embedded it is categorical rather than a matter of degree.

`swift-machine-primitives` has **no Embedded validation at all**: one incidental doc-comment mention (`Machine.Value.swift:78`, asserting the `_Table.destroy` closure is *"acceptable for Embedded compatibility"*), no Embedded experiment, no Embedded flag anywhere. Render's architecture is Embedded-validated with an 8-hypothesis experiment. That asymmetry is worth recording independently of this decision.

**And the requirement is not currently met. Three sites, verified:**

```swift
// swift-render-primitives/Sources/Render Primitive/Render.Context.swift
:47   @usableFromInline var _applyInlineStyle: (Any) -> Bool
:67   applyInlineStyle: @escaping (Any) -> Bool = { _ in false },
:121  public func apply(inlineStyle property: Any) -> Bool
```

`Any` is an existential container. This is the exact wart I flagged in my Round-1 Concern 4 as "a pre-existing escape hatch unrelated to this question." Under the Embedded requirement it is not unrelated — it is **the** Embedded blocker in Render L1, which is otherwise entirely clean (grep for `any P` / `AnyObject` / `AnyHashable` / `Mirror` / `as?` across `Render Primitive` returns nothing else).

Two more in the HTML path:

```swift
// swift-html-render/Sources/HTML Rendering Core/HTML.AnyView.swift:39
if let anyView = base as? HTML.AnyView                       // dynamic cast
// swift-html-render/Sources/HTML Rendering Core/HTML.Element.swift:48
-> (any WHATWG_HTML.Element.`Protocol`.Type)?                 // existential metatype
```

`swift-html-render` also carries no Embedded flag in its manifest and no Embedded experiment. `HTML.AnyView` is otherwise well-designed for this — it erases through `renderInto: (inout Render.Context) -> Void`, a closure rather than an existential, and its own doc says erasure goes *"through this concrete eraser plus generics and NEVER through `any HTML.View`."* The `as?` on line 39 is a flattening optimisation, not the erasure mechanism.

This does not change any decision we have reached. It adds a work item that outranks most of them, and it is a reason to be conservative about anything that introduces new erasure on the render path.

---

### Answers to your six questions

**Q1 — Stage A accepted, without reservation.** Your Concern 1 is right and my Proposal 2 was wrong. Putting a generic executor in the composition target answers two different questions in one target and re-creates the defect one level over. Concrete `Render.Document.Traversal` first, no generic `Work` executor anywhere, extraction deferred until a second domain supplies evidence about which invariants are render-general.

Your Concern 3 also corrects a misreading on my part. I treated "wait for a second domain" as consumer-count reasoning barred by [ARCH-LAYER-008]. It is not: [ARCH-LAYER-008] bars consumer count as an argument *against a correct abstraction*, and says nothing about how you *discover* a mission boundary. A correct one-consumer abstraction is extracted immediately; an *unproven* one is not an abstraction yet. That distinction is right and I accept it.

**Q2 — I cannot name one. That is the answer, and it decides Q1.** Every invariant the current executor holds is document-shaped at its edges: `.render(pointer:thunk:)` erases a `Render.View`; `.action` calls document interpretation; `.frame(.closeScope)` closes a document bracket; `_cleanupStack()` knows only how to destroy `.render` work; `Pair`'s marker-scoped drain exists to preserve *document emission order*. Strip those out and I am left with `Stack<Work>` plus a stepping loop plus a destroy hook — which is your Concern 2's `while count > marker { step(pop()) }`. That is a mechanism, not a concept, and I said as much about the trampoline extraction in Round 3 without noticing it applied equally to my own proposal.

**Q3 — Yes. I rejected `Trampoline` for the wrong reason.** A trampoline is an iterative loop that repeatedly invokes deferred computations to avoid consuming the native call stack. That is exactly what `_drain` does, and Render's queue of type-erased deferred view calls is *closer* to the textbook trampoline than Parser and Binary's graph machines are. "Parser and Binary don't use it" was an argument about where the code belongs, and I misapplied it to the name. Agreed on your resolution: **trampoline is the technique classification in design documentation; `Render.Document.Traversal` is the API name**, because the type is richer than a minimal trampoline (actions and continuation frames, not just thunks) and `Traversal` names the responsibility rather than the strategy. Agreed on excluding `Render.Executor` — the collision with Swift concurrency executors is real and avoidable.

**Q4 — I do not know, and your table is the right way to decide it. I withdraw the claim that `sending` dissolves `Capture.Mode`.** Your Concerns 7 and 8 are both correct and I over-read the package's own doc comment as a plan rather than a gesture. `sending` expresses one-time transfer across an isolation boundary; it does not make a stored closure `Sendable`, does not make a frozen capture store shareable, and does not license repeated execution over shared captures. A `Program` that can be moved once into another region is genuinely not a `Program` that can be shared across tasks and re-run — and re-running the same compiled grammar against many inputs is the whole point of the arena design. Which capability is wanted is exactly what the audit must establish first; I asserted the conclusion. Same concession on Concern 8: `Value.Ref<T>: ~Copyable, ~Escapable` improves typed projection *from* existing storage; it does not remove the need for heterogeneous storage of intermediate results across frame transitions. The box may survive with a different implementation.

**Q5 — `SlotMap` covers six of your seven requirements from source; one is unverified.**

```swift
// swift-slot-map-primitives/Sources/SlotMap Primitives/SlotMap+Columns.swift
:37  public mutating func insert<E: ~Copyable>(_ element: consuming E) -> Handle
:66  public mutating func remove<E: ~Copyable>(_ handle: Handle) -> E?
:82  public mutating func removeAll<E: ~Copyable>()
:102 public func contains<E: ~Copyable>(_ handle: Handle) -> Bool
:118 public func withElement<E: ~Copyable, R>(…)
:172 public func forEach<E: ~Copyable>(_ body: (borrowing E) -> Void)
```

| Your requirement | Verdict |
|---|---|
| Move-only stored value | **Yes** — `SlotMap<E: ~Copyable>` front door is move-only by default; `.Shared` is the explicit CoW opt-in |
| Allocate + consume/release | **Yes** — `insert(consuming E)`, `remove(Handle) -> E?` returns the element |
| Stale-handle detection | **Yes** — `contains(Handle) -> Bool` plus a validated subscript |
| No unintended CoW storage | **Yes** — by construction; CoW is a separate front door |
| Expected failure behaviour | **Better than Machine's** — `remove` returns `E?` and `contains` is non-trapping, where `Machine.Value.Arena` calls `fatalError` on a stale handle in `read`/`release`/`validateHandle` |
| Predictable allocation reuse | **Yes** — pool-backed generational column owns placement |
| **O(1) whole-run generation invalidation** | **Unverified.** `removeAll()` exists and forwards to `store.removeAll()`. Whether that is a single generation bump (matching `Machine.Value.Arena.reset()`'s `generation &+= 1`) or a per-slot walk, I did not confirm — it needs reading `Store.Generational`. This is the one open item, and it matters because the arena is reset per parse run. |

So your Concern 9 stands as written: strong evidence of duplication, not complete proof. The reset semantics are the thing to check first.

**Q6 — `Ownership.Box` is the wrong match; `Ownership.Immutable` is a near-exact one. Your Concern 10 was right to push back.**

```swift
// swift-ownership-primitives/Sources/Ownership Immutable Primitives/Ownership.Immutable.swift
/// A heap-allocated wrapper for an immutable value with shared ownership.
/// `Immutable` provides reference semantics for value types via ARC, enabling:
/// - Heap allocation for values that need stable identity
/// - Breaking recursive type definitions
/// - Storage for `~Copyable` values that need heap allocation
@safe
public final class Immutable<Value: ~Copyable & Sendable>: Sendable {
    public let value: Value
    @inlinable public init(_ value: consuming Value) { self.value = value }
}
```

Against `Render.Indirect<Content: ~Copyable>`: `final class`, `public let value: Content`, `init(_ value: consuming Content)`. Structurally identical, and the documented purpose ("breaking recursive type definitions", "heap allocation for values that need stable identity") is Render's stated reason verbatim.

Filling in your semantic matrix:

| Property | `Render.Indirect` | `Ownership.Immutable` | `Ownership.Box` |
|---|---|---|---|
| Payload may be `~Copyable` | required | **yes** | unclear — `Box<Value>` is not `~Copyable`-bound |
| Mutation | none | **none** (`let`) | CoW mutation is its purpose |
| Shared identity | acceptable | **yes**, ARC | shared until mutation, then diverges |
| Copy-on-write | unnecessary | **absent** | present |
| Sendability | conditional on payload | `Value: Sendable` **required**, conformance *checked* | — |

`Ownership.Box`'s copy-on-write semantics are wrong for an immutable box — copies diverge on mutation, which is precisely what `Render.Indirect` must not permit. You caught that correctly.

**One real gap.** `Ownership.Immutable` requires `Value: ~Copyable & Sendable` unconditionally, and gets *checked* `Sendable` for it. `Render.Indirect` permits non-`Sendable` content and carries `@unsafe @unchecked Sendable where Content: Sendable & ~Copyable`. A straight swap therefore **tightens** the constraint: any `Render.View` that is not `Sendable` could no longer be indirected.

That gap cuts in the ecosystem's favour on the safety axis. `Render.Indirect`'s own doc comment spends fifteen lines agonising over exactly this: *"An unconditional `@unchecked Sendable` here would defeat the compiler's data-race checking for every `Content` type, checked or not — that was the bug this conditional conformance fixed."* `Ownership.Immutable` gets a *structurally synthesised* conformance with no escape hatch at all. So the question is empirical: are Render's indirected view types all `Sendable`? If yes, adopt `Ownership.Immutable` and the `@unchecked` disappears. If no, the correct move is a non-`Sendable` sibling in the ownership package — which, as you put it, would be a coverage gap in that package rather than evidence Render should keep its own box.

---

### Agreements and concessions

Beyond the four above: I accept Concern 2 (the generic `Work` executor is under-specified and your ten-question list is the right bar — it is also the bar my own Round-3 proposal failed), Concern 5 (naming), Concern 6 (`Thunk` is domain-specific and belongs to `Render.Document`, and a generic traversal facility should not own it), and Concern 11 (the [ARCH-LAYER-009] removal list was too aggressive — `Render.Machine` is removable now; `Render.Thunk` is not dead until something concretely replaces it, and arbitrary-depth traversal still requires deferred ownership and typed dispatch).

I accept Proposal 1's settled-negatives list, Proposal 2's Stage A/Stage B sequencing, Proposal 3, Proposal 4's traversal contract, Proposal 5's hypothesis framing for the Machine audit, Proposal 6's semantic matrix, and Proposal 7's narrow removal procedure.

**Two additions to Proposal 4's traversal contract**, both from the Embedded constraint:
- *The traversal and every work representation must fully monomorphise under `-enable-experimental-feature Embedded`* — no existential work storage, no runtime type identity, no dynamic casts. This is a law of the contract, not an implementation note.
- *Work items may be `~Copyable`.* You listed this as an open question; under Embedded plus the ecosystem's `~Copyable` direction, it should be a yes.

**One addition to the settled-negatives list:** record that `Render.Context.apply(inlineStyle:)`'s `Any` parameter is an Embedded blocker requiring its own fix, and that it is unrelated to the traversal split — so it does not get bundled into Stage A and quietly deferred.

---

### Proposals (delta only — everything else adopted as you wrote it)

1. **Add an Embedded gate to Stage A's acceptance criteria.** Stage A ships when the document target still builds under `-enable-experimental-feature Embedded` — reusing the existing `embedded-rendering-context` experiment shape. Otherwise a refactor that separates witness from traversal could silently regress the property the whole architecture was validated for.

2. **Raise the `Any` fix out of Stage A into its own item, ahead of it.** Three sites in `Render.Context` plus `HTML.AnyView.swift:39` and `HTML.Element.swift:48`. The stated requirement is that HTML renders under Embedded; it does not today. That is a defect in force now, independent of every architectural question in this discussion, and it should not queue behind a refactor.

3. **Add Embedded viability to the Machine audit's hypothesis list** (your Proposal 5). Not as an acceptance criterion — Machine has no stated Embedded requirement — but because `ObjectIdentifier(T.self)` over an unconstrained generic is the kind of construct that decides whether `Machine.Value` can *ever* be shared with an Embedded-targeted consumer. It bounds who Machine can serve.

4. **Check `Store.Generational.removeAll()`'s reset complexity first** in the `SlotMap` substitution audit. It is the single open item from Q5 and it gates the rest.

5. **Resolve the `Ownership.Immutable` `Sendable` gap by census, not by assumption**: enumerate the `Render.Indirect` instantiations in `swift-html-render` and `swift-pdf-render` and check whether their `Content` types are `Sendable`. That census decides between "adopt directly" and "the ownership package needs a non-`Sendable` sibling."

---

### Questions

1. Does the Embedded requirement change your Stage B trigger? My reading is that it does not change *whether* to wait for a second domain, but it does add a law to the eventual contract — any extracted traversal must monomorphise under Embedded, which rules out an existential-typed `Work` up front and constrains what "generic over `Work`" may mean.

2. Given that `Machine.Value`'s `ObjectIdentifier` projection is Embedded-incompatible, and `swift-machine-primitives` has no Embedded validation — is that a finding for the Machine audit (bounding which consumers Machine can serve) or is it out of scope because Machine has no Embedded requirement of its own? I lean toward recording it as a bound rather than a defect.

3. On the `Ownership.Immutable` `Sendable` gap — if the census finds non-`Sendable` indirected content, do you agree the fix is a sibling in the ownership package rather than Render retaining `Indirect`? Or is there a case for Render keeping a local box when the ecosystem type is *safer* but *narrower*?

4. Anything remaining that blocks CONVERGED? By my count every concern you raised in Round 4 is either accepted or answered from source, and the only open items are empirical (the `Store.Generational` reset complexity, the `Sendable` census) rather than positional. I am willing to mark CONVERGED next round if you are.

### Status: NEAR_CONSENSUS

