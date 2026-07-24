## Round 7 - Claude — Factorization Matrix

### Position

**CONVERGED on everything in your Round 6. This round answers the reframed question only.**

The reframe is right and the answer is quantifiable. I built the matrix against source. Of thirteen axes, **two are intrinsically domain-specific, three are legitimate per-domain choices that Machine has wrongly fused into its algebra, and eight are decomposition debt — of which five have an existing Swift Institute primitive that simply is not adopted.**

*(Corrected: this opening previously read "two … and nine", contradicting the table and the tally line below it. The rows support 2 / 3 / 8. Superseded in any case by the four-verdict scheme in `Research/render-machine-dissolution.md` v1.1.0, which re-tallies to 2 intrinsic / 3 domain policy / 5 debt / 2 unproven / 1 cross-cutting constraint.)*

So: the dissatisfaction is justified. Render and Parser share almost nothing today not because they are different in nine ways, but because `Machine` bundles nine separable axes into one product and five already-built primitives go unused by both.

One correction to your framing before the matrix, because it changes which axes are negotiable.

---

### The one difference that is not decomposition debt

Execution discipline is not a design choice either package made. It is forced.

Reynolds' defunctionalization of a recursive traversal produces machinery whose shape follows from **whether the primitive operation returns a value the caller consumes**:

- `Leaf × Cursor → Result<Value, Failure>` — later operations consume earlier results, so a defunctionalized evaluator must carry *what to do with the value when it comes back*. That is a continuation stack, and it requires a value register to hold the returning value and a program counter to know where in the program the continuation resumes. **CEK machine.**
- `Action × Context → Void` — nothing comes back, so "what to do with the value" is empty. The continuation stack degenerates into a list of pending operations. No value register is needed because there is no value; no program counter is needed because each stack entry *is* the next operation. **Worklist / trampoline.**

Parser and Binary defunctionalize the first shape; Render defunctionalizes the second. That is a theorem about the source functions, not an artifact of how the packages were carved. No amount of re-decomposition makes a value-free traversal need a value register.

**And that is fine.** Worklist and CEK evaluator are both established, named abstract-machine forms. Under a corrected `Machine` mission — *"computations represented through explicit control state and stepped without the native call stack"* — they are **siblings**, not competitors. The mistake was ever expecting one to instantiate the other. The reuse should come from the axes *underneath* both, and there are more of those than either of us credited.

---

### The matrix

Legend: **INTRINSIC** = follows from the domain's semantics, correctly domain-owned. **FUSED** = a legitimate per-domain choice that `Machine` has hardcoded into its algebra rather than exposed as an axis. **DEBT** = one concept, multiple hand-rolled implementations. **DEBT★** = DEBT where the ecosystem primitive **already exists**.

| # | Axis | Parser | Binary | Render | Existing owner | Verdict |
|---|---|---|---|---|---|---|
| 1 | **Execution discipline** | CEK: PC + value register + continuation stack | same | worklist / trampoline | — | **INTRINSIC** |
| 2 | **Failure** | typed `Failure` + backtracking recovery | typed `Fault` | none — no failure path exists | typed throws (language) | **INTRINSIC** |
| 3 | **Result transport** | heterogeneous erased (`Machine.Value`) | same | none | — | **FUSED** — the per-domain choice is legitimate; hardcoding "heterogeneous erased" into `.map`/`.tryMap`/`.sequence`/`.many`/`.fold` is not |
| 4 | **Repeatability** | build once, run many | same | one-shot | — | **FUSED** — a property of the *program representation*, not of "machine"; `Program`+`Builder`+`Capture.Frozen` exist only to serve it |
| 5 | **Program representation** | `Graph.Sequential` via `Machine.Program` | same | the typed view tree itself | `swift-graph-primitives` | **FUSED** — `Machine.Node.ID = Graph.Node<Self>` bakes graph-addressing into the node type. Graph is *one* program representation |
| 6 | **Control stack** | `Stack<Frame>` | bare `[Frame]` + `reserveCapacity` | bare `[Render.Work]` | **`swift-stack-primitives`** | **DEBT★** — one concept, three representations, one of them already the right primitive |
| 7 | **Depth bounding** | `maxDepth` + `depth` counter + `.recursiveExit` frame | same, hand-rolled | none needed (heap-bounded) | **`Stack.Bounded`** | **DEBT★** |
| 8 | **Checkpoint / rollback** | `input.checkpoint` / `seek(to:)` | same | `Render.Speculative.begin()` / `check(fit:)` | **`Input.Protocol` — but mis-homed** | **DEBT★** — see below; the clearest single instance |
| 9 | **Owned erased payload** | `Value._Storage` + `_Table`: ptr + `destroy` + `ObjectIdentifier` | same | `Render.Thunk`: ptr + `dispatch` + `destroy`, **no type tag** | `Ownership.Unique<Value: ~Copyable>` owns the *typed* case | **DEBT** — two policies over one mechanism; the erased variants are unfactored |
| 10 | **Slot storage + generational handles** | `Value.Arena` + `Value.Handle` | same | — | **`SlotMap` + `Store.Generational.Handle`** | **DEBT★** |
| 11 | **Typed handles / indices** | `Node.ID = Graph.Node<Self>` (typed) but `Value.Handle.index: Int` (raw) | same | — | **`swift-index-primitives`** (`Index<T>`) | **DEBT★** — inconsistent *within a single package* |
| 12 | **Cleanup discipline** | `arena.reset()` generation bump | same | `_cleanupStack()` walks and destroys | `Ownership.Unique.deinit`, `SlotMap.removeAll` | **DEBT** |
| 13 | **Embedded viability** | unvalidated | unvalidated | validated E1–E8; one `Any` blocker | — | **DEBT** — nothing intrinsic blocks Machine except axis 9's type-identity policy |

**Tally: 2 INTRINSIC, 3 FUSED, 8 DEBT (5 of them DEBT★).**

---

### Axis 8 in detail — the clearest proof that this is decomposition, not difference

You wrote that speculative rendering and parser backtracking suggest "a reusable concept below both domains." It is stronger than that: **the concept is already factored out, into the wrong namespace.**

```swift
// swift-input-primitives/Sources/Input Protocol Primitives/Input.Protocol.swift:66-100
public protocol `Protocol`<Element>: Streaming, ~Copyable {
    associatedtype Checkpoint: Comparable
    var checkpoint: Checkpoint { get }
    var bounds: ClosedRange<Checkpoint> { get }
    mutating func seek(to checkpoint: Checkpoint)
    …
}
```

Note that `Input.Protocol` already refines a separate `Streaming` protocol — so the *iteration* axis was correctly split out. The **checkpoint** axis was not. `Checkpoint` / `checkpoint` / `bounds` / `seek(to:)` describe *positionally checkpointable state*, with no dependence on the state being an input cursor. It is fused to `Input` for no reason except that inputs were the first consumer.

The consequence is exact and measurable: `Render.Speculative` needs snapshot / tentative-execute / restore over **backend output state**, and cannot reuse a single line of the above. So it hand-rolls two closures:

```swift
public struct Speculative {
    @usableFromInline var _begin: () -> Void
    @usableFromInline var _check: (_ minimumRequired: Int) -> Void
}
```

— a strictly weaker interface (no checkpoint value, so no nesting, no `bounds` validation, no `commit`), reinvented because the capability it needs is trapped inside a cursor protocol.

This is the archetype for the whole matrix: the institute *did* factor the concept, then homed it on its first consumer instead of on its own essence. That is precisely the [ARCH-LAYER-014] failure mode — layer/identity follows essence — applied at the protocol level rather than the package level.

---

### Axis 9 in detail — one mechanism, two policies, neither factored

```swift
// Render.Thunk — type known statically, baked into the function pair
struct Thunk {
    let dispatch: (UnsafeMutableRawPointer, inout Render.Context) -> Void
    let destroy:  (UnsafeMutableRawPointer) -> Void
    init<Body: Render.View & ~Copyable>(_: Body.Type) { … }   // monomorphised here
}

// Machine.Value — type checked at runtime, tag stored alongside
struct Value<Mode> {
    let type: ObjectIdentifier                                 // runtime identity
    let storage: _Storage                                      // ptr + destroy closure
}
```

Both are: **an owned heap payload + statically-paired operations + exact-once destruction.** They differ on one policy bit — *is the payload's type known to the function table, or checked against a stored identity?* Your two-branch taxonomy was right, and the Embedded requirement decides which branch Render may use: the type-identity branch needs runtime metadata, so Render gets the function-table branch and Machine currently takes the other.

The ecosystem owns the **typed** case already:

```swift
// swift-ownership-primitives — Ownership.Unique.swift:57
@safe @frozen
public struct Unique<Value: ~Copyable>: ~Copyable {
    internal let _storage: UnsafeMutablePointer<Value>
    public init(_ initialValue: consuming Value) { … }        // allocate + move
    // "consume() and deinit are the only exits"
}
```

That is `Render.Work.render(pointer:)`'s contract with the type still attached. Neither erased variant exists anywhere. This is the one axis in the matrix where the right extraction is genuinely **new work** rather than adoption — and it is the axis with the highest payoff, because it is shared by Parser, Binary and Render simultaneously.

---

### What this changes about the answer

The objective was never "Render uses `Machine.Node`." Under the correct objective — *every genuinely shared axis has one canonical implementation* — Parser, Binary and Render would share:

- `Stack` / `Stack.Bounded` (axes 6, 7)
- a re-homed checkpoint capability (axis 8)
- an erased owned-payload primitive, in two policy variants (axis 9)
- `SlotMap` + `Store.Generational.Handle` (axis 10)
- `Index<T>` typed handles (axis 11)
- a common cleanup discipline falling out of 9 and 10 (axis 12)

— while retaining different **execution disciplines** (axis 1) and **failure models** (axis 2), because those genuinely differ; and while `Machine` stops hardcoding **result transport**, **repeatability** and **program representation** (axes 3–5) into its node algebra, so a machine that needs none of them can still be a machine.

That is a much larger reuse surface than "Render should compile to `Machine.Node`" would ever have delivered — and it is available *without* either domain pretending its runtime shape is the other's.

Your `Machine` mission sentence supports it directly. Under *"primitives for explicit abstract machines: computations represented through explicit control state and stepped without relying on the native call stack,"* Render's traversal **is** a machine. It just is not a graph evaluator. The namespace was never the problem; the product boundary was.

---

### Proposed ordering — by cost, not by ambition

[MOD-RENT] charges rent per package, and your warning about a single over-parameterised generic type is right. So the sequence should start where no new concept is minted at all.

**Tier 0 — pure adoption. Zero new packages, zero new concepts.**
Axes 6, 7, 10, 11. Every primitive already exists and ships. `Machine` adopts `Stack`/`Stack.Bounded` (replacing `[Frame]` and the hand-rolled depth counter), `SlotMap` + `Store.Generational.Handle` (replacing `Value.Arena`/`Value.Handle`), and `Index<T>` for its remaining raw `Int` identities. Render adopts `Stack`. These are your Proposal 7 experiments 2 and 3, plus two more; nothing here needs a design decision, only verification of the semantic contracts you listed in Round 6 Concern 7.

**Tier 1 — re-home one existing capability.** Axis 8. Lift `Checkpoint` / `checkpoint` / `bounds` / `seek(to:)` out of `Input.Protocol` into a capability owned by its own essence, with `Input.Protocol` refining it exactly as it already refines `Streaming`. Then `Render.Speculative` conforms output/backend state to the same capability and gains checkpoint values, nesting and bounds validation it does not have today. **This is the highest-value single move in the matrix**: it is one protocol extraction, it is non-breaking for `Input` conformers, and it converts a hand-rolled two-closure struct into a conformance.

**Tier 2 — the one genuinely new factoring.** Axis 9. An erased owned-payload primitive with exact-once destruction, in two policy variants (function-table-typed; runtime-identity-typed), most plausibly homed in `swift-ownership-primitives` beside `Ownership.Unique`. Needs design, needs an Embedded compile test for the second variant, and is the only item here I would not start before Tiers 0 and 1 are landed.

**Tier 3 — decouple Machine's fused axes.** Axes 3, 4, 5. This is your Round-6 Proposal 7 experiment 6 (separating neutral node forms from parser combinators) generalised: `Machine.Program`'s graph-addressing, the repeatability apparatus, and the heterogeneous-value assumption should each be an axis a machine may decline. Largest and least urgent, and it should be informed by whatever Tiers 0–2 reveal.

**Not in scope at any tier:** unifying execution disciplines. Axis 1 is a theorem.

---

### What does not change

Every decision in your Round 6 stands. Stage A proceeds exactly as specified — `Render.Document.Traversal`, no generic abstraction, Embedded as an acceptance criterion, `Render.Machine` removed, the three Embedded API defects on their own track. Nothing in this matrix is a reason to delay Stage A; Tier 0 is independent of it, Tier 1 touches `Render.Speculative` which Stage A only relocates, and Tiers 2–3 are downstream of both.

Answering your Round-6 Question 2 on sequencing: **the Embedded API repairs run as a parallel prerequisite branch, merged before Stage A is declared complete.** They are a defect in force now and Stage A's acceptance criterion is a clean Embedded build, so Stage A cannot be judged complete without them — but they are independently reviewable and should not be entangled with the traversal refactor's characterization tests.

And Question 3: agreed, the `ObjectIdentifier` / generic-metatype / checked-projection behaviour under Embedded is the **first** Machine experiment, recorded as a hypothesis and a prospective-consumer bound, not as a defect against Machine's current mission. My Round-5 phrasing overstated it; your Round-6 Concern 1 wording is the one to record.

### Status: CONVERGED
