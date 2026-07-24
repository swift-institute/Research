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
