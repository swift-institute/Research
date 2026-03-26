# Defunctionalized Work Queue Extraction

<!--
---
version: 2.0.0
last_updated: 2026-03-26
status: RECOMMENDATION
tier: 2
changelog:
  - 2.0.0 (2026-03-26): Expanded scope to cover interpreter-layer extraction (Machine.Interpret). Original v1.0 value-layer analysis preserved as Section 1. New Section 2 analyzes run-loop duplication between parser-machine and binary-parser. Actionable implementation plan added. Status: IN_PROGRESS → RECOMMENDATION.
  - 1.0.0 (2026-03-18): Initial investigation — value-layer extraction between machine-primitives and rendering-primitives.
---
-->

## Context

Machine-primitives provides defunctionalized IR (`Machine.Node`, `Machine.Frame`, `Machine.Value`) for stack-safe interpretation. Multiple packages consume this IR:

| Consumer | Package | Leaf Type | Extra Frame | Input Constraint |
|----------|---------|-----------|-------------|------------------|
| Text/data parsing | swift-parser-machine-primitives | Closure `(inout Input) throws(Failure) -> Value` | `.memoization(node:startPosition:)` | Generic `Parser.Input.Protocol & Sendable` |
| Binary parsing | swift-binary-parser-primitives | `Instruction` enum (21 cases) | `Never` | `~Escapable` Span-based view |
| View rendering | swift-rendering-primitives | Thunk (dispatch + destroy) | N/A — own work stack | N/A — effect-only, no machine-primitives |
| Serialization | swift-serializer-primitives | N/A — stateless closures | N/A | N/A |
| Higher-level parsing | swift-parsers (L3) | N/A — consumer of parser-machine | N/A | N/A |

Two extraction questions arise from this landscape:

1. **Value-layer**: Should rendering-primitives share machine-primitives' type-erased storage? (v1.0 analysis)
2. **Interpreter-layer**: Should machine-primitives provide shared run-loop infrastructure that parser-machine and binary-parser both consume? (v2.0 analysis)

## Section 1: Value-Layer Extraction (v1.0)

### Question

Should the "type-erased heap allocation + witness dispatch + iterative work stack" pattern be extracted into a shared primitive that both machine-primitives and rendering-primitives consume?

### Prior Art

#### Internal

- `Machine.Value<Mode>` — type-erased value with ARC `_Storage` class, `ObjectIdentifier` for type-safe extraction, `_Table` for destruction. Production since 2026-01.
- `Rendering.Thunk` — witness struct storing `dispatch` + `destroy` closures, paired with `UnsafeMutableRawPointer`. Implemented 2026-03-18.
- Both derive from the same insight: recursive traversal overflows the 544 KB cooperative thread pool stack; defunctionalize continuations onto the heap.

#### External

- **Trampoline pattern** (functional programming) — convert recursive calls to heap-allocated thunks processed in a loop. Standard technique in Haskell, Scala, and continuation-passing style transforms.
- **Defunctionalization** (Reynolds 1972) — replace higher-order functions with first-order data + dispatch. Machine.Frame is a textbook defunctionalized continuation.
- **Work-stealing queues** (Cilk, Swift concurrency) — related but different: concurrent work distribution vs. single-threaded traversal.

### Instance Comparison

#### Shared Shape

Both consumers implement four components:

| Component | Description |
|-----------|-------------|
| **Type-erased heap value** | Allocate `T` on heap via `UnsafeMutablePointer<T>`, carry `UnsafeMutableRawPointer` |
| **Witness closures** | Closures specialized at creation time capturing `T.self` for type-specific operations |
| **Work stack** | LIFO collection of work items; dispatch may push new items |
| **Iterative loop** | `while let item = stack.pop() { dispatch(item) }` replacing recursion |

#### Concrete Divergences

| Aspect | Machine (parser) | Rendering |
|--------|-------------------|-----------|
| **Computational model** | Value-producing (every node yields `Machine.Value`) | Effect-only (views emit side effects into `Context`) |
| **Value lifetime** | ARC (`_Storage` class) — values may be referenced from multiple frames via handles | Manual alloc/dealloc — each value consumed exactly once |
| **Type extraction** | Yes — `ObjectIdentifier` + `read<T>/take<T>` to recover typed value | No — dispatch closure is fully type-erased, never extracts |
| **Witness shape** | `_Table` (destroy only) + separate `Transform.Erased` (dispatch via capture system) | `Thunk` (dispatch + destroy bundled) |
| **Work item type** | `Machine.Frame` — 11 domain-specific continuation cases (map, flatMap, oneOf, many, fold, optional, sequence, recursiveExit, tryMap, extra) | `Rendering.Work` — 3 cases (render, action, frame) |
| **Stack type** | `Stack<Frame>` from stack-primitives (typed, ~Copyable) | `[Work]` plain Array |
| **Arena** | `Machine.Value.Arena` — slot-based random access with handle indirection + generation counter (ABA prevention) | None — sequential LIFO only |
| **Error recovery** | Backtracking: unwind frame stack on failure, try alternatives | None |
| **~Copyable support** | No — `Machine.Value` stores Copyable values only | Yes — `Rendering.Thunk` borrows through raw pointer for ~Copyable views |
| **Combinators** | 12 node types: leaf, pure, map, tryMap, flatMap, sequence, oneOf, many, fold, optional, ref, hole | 5 composition types: Tuple, Conditional, Pair, Optional, Array — no map/flatMap/oneOf/many/fold |

### Options Evaluated

**Option A: Status Quo** — each consumer maintains its own implementation.
- ✓ Zero coupling, domain-optimal implementations, no overhead
- ✗ Pattern duplicated for future consumers

**Option B: Shared `Thunk` type** — extract type-erased heap value into a new primitive.
- ✓ Centralizes unsafe alloc/init/deinit/dealloc
- ✗ Machine can't use it (needs ARC + extraction); only 15 lines; abstraction too thin

**Option C: Use `Machine.Value<Mode.Unchecked>` in Rendering**
- ✗ ~Copyable blocker: `Machine.Value.read<T>()` returns a copy; rendering needs borrow-through
- ✗ ARC overhead per work item (1000-view tree → 1000 class allocations)

**Option D: Generalized `Trampoline`** — extract the loop itself.
- ✗ Trivially thin (3 lines); consumers still need domain-specific work items

**Option E: Extend Machine.Value with borrowing access**
- Fixes ~Copyable blocker from Option C
- ✗ Still ARC overhead; still ObjectIdentifier overhead; API change benefits rendering only

### Comparison

| Criterion | A: Status Quo | B: Thunk | C: Machine.Value | D: Trampoline | E: Value+Borrow |
|-----------|:---:|:---:|:---:|:---:|:---:|
| Code reuse | None | Partial | Full storage | Loop only | Full storage |
| ~Copyable support | ✓ | ✓ | ✗ **blocker** | N/A | ✓ (API change) |
| ARC overhead | None | None | Per work item | None | Per work item |
| Abstraction value | — | Marginal (15 lines) | Moderate | Trivial (3 lines) | Moderate |
| Coupling | None | Low | High | Low | High |
| Machine can use? | N/A | No | N/A | No | N/A |

### Section 1 Outcome

**Option A (Status Quo)** — confirmed. Verified: 2026-03-26.

The overlap between machine-primitives and rendering-primitives is at the **design pattern level**, not the **reusable type level**:

- **Storage**: ARC multi-reference vs. manual single-owner
- **Witness**: separate destroy + dispatch-via-captures vs. bundled thunk
- **Work items**: 11-case parser continuation vs. 3-case render-or-action
- **Loop**: two-phase (node-execution + frame-processing) vs. simple pop-dispatch
- **Computational model**: value-producing vs. effect-only (fundamental mismatch)

Per [IMPL-060], machine-primitives does not provide equivalent functionality to rendering's needs. Per [PATTERN-013], extending machine-primitives with effect-only nodes for one consumer is premature.

Rendering-primitives already follows [IMPL-035] (uniform execution model) and [IMPL-036] (minimal storage for deferred computation) — both principles that originated from rendering's own implementation.

---

## Section 2: Interpreter-Layer Extraction (v2.0)

### Question

Parser-machine-primitives and binary-parser-primitives both implement ~300-line iterative interpreters for the same `Machine.Node`/`Machine.Frame` IR. Should machine-primitives provide shared run-loop infrastructure?

### Analysis

#### Line-by-line comparison

Three source files compared:
- `swift-parser-machine-primitives/.../Parser.Machine.Run.swift` (non-memoized)
- `swift-parser-machine-primitives/.../Parser.Machine.Run.Memoization.swift` (memoized)
- `swift-binary-parser-primitives/.../Binary.Bytes.Machine.Run.swift`

The interpreter has three sections. Each was compared:

**Frame handling (pending-value branch)** — 11 cases, ~50 lines per consumer:

| Frame case | Logic | Identical? |
|------------|-------|:---:|
| `.map(transform)` | Apply transform, allocate result | ✓ |
| `.tryMap(transform)` | Apply throwing transform, handle error | ✓ |
| `.flatMap(next)` | Compute next node from value | ✓ |
| `.sequence(.second)` | Stash first value, push combine frame, descend to b | ✓ |
| `.sequence(.combine)` | Release first, combine with second, allocate | ✓ |
| `.oneOf` | Success — allocate value, discard alternatives | ✓ |
| `.many` | Append handle, save checkpoint, push continuation, descend | ✓ |
| `.fold` | Combine accumulator, save checkpoint, push continuation, descend | ✓ |
| `.optional` | Release none handle, wrap with some, allocate | ✓ |
| `.recursiveExit` | Decrement depth, allocate value | ✓ |
| `.extra` | **DOMAIN-SPECIFIC**: memoization cache store (parser) vs `switch never {}` (binary) | ✗ |

**Failure recovery (frame unwinding)** — 7 cases, ~25 lines per consumer:

| Frame case | Recovery action | Identical? |
|------------|----------------|:---:|
| `.oneOf` (has alternatives) | Restore checkpoint, push incremented frame, try next | ✓ |
| `.oneOf` (exhausted) | Continue unwinding | ✓ |
| `.many` | Restore checkpoint, finalize collected results | ✓ |
| `.fold` | Restore checkpoint, return accumulator | ✓ |
| `.optional` | Restore checkpoint, return none handle | ✓ |
| `.recursiveExit` | Decrement depth, continue unwinding | ✓ |
| `.map/.tryMap/.flatMap/.sequence` | Skip, continue unwinding | ✓ |
| `.extra` | **DOMAIN-SPECIFIC**: memoization stores failure (parser) vs skip (binary) | ✗ |

**Node dispatch** — 12 cases, ~40 lines per consumer:

| Node case | Action | Identical? |
|-----------|--------|:---:|
| `.pure(value)` | Allocate, yield | ✓ |
| `.map(child, transform)` | Push map frame, descend | ✓ |
| `.tryMap(child, transform)` | Push tryMap frame, descend | ✓ |
| `.flatMap(child, next)` | Push flatMap frame, descend | ✓ |
| `.sequence(a, b, combine)` | Push sequence(.second) frame, descend to a | ✓ |
| `.oneOf(alternatives)` | Push oneOf frame (if >1), descend to [0] | ✓ |
| `.many(child, finalize)` | Push many frame with checkpoint, descend | ✓ |
| `.fold(child, initial, combine)` | Push fold frame with checkpoint, descend | ✓ |
| `.optional(child, wrapSome, noneValue)` | Push optional frame with checkpoint, descend | ✓ |
| `.ref(target)` | Check depth, push recursiveExit, descend | ✓ |
| `.hole` | fatalError | ✓ |
| `.leaf(leaf)` | **DOMAIN-SPECIFIC**: call closure (parser) vs switch instruction enum (binary) | ✗ |

**Summary**: ~115 lines of identical logic per consumer. Only 3 points diverge: leaf execution, extra frame handling, and error propagation model.

#### Why the Leaf type parameter makes a shared run loop impossible

The `~Escapable` boundary prevents a universal `run()` function. Binary-parser's `Input.View` is `~Copyable, ~Escapable` — it cannot cross closure or protocol boundaries. A shared run loop would need a leaf-dispatch callback:

```swift
Machine.run(program, root, input: &input) { leaf, input in try leaf.execute(&input) }
```

But `inout Input` where `Input: ~Escapable` cannot be a closure parameter. This is the exact constraint that motivated binary-parser's separate machine in the first place.

**The solution**: Factor out everything EXCEPT leaf dispatch and extra handling. The shared functions work with `Machine.Value`, `Machine.Frame`, carriers (`Transform`, `Combine`, `Next`, `Finalize`), and the arena — none of which involve Input. The `~Escapable` boundary is respected because Input handling stays in the consumer.

#### Skill compliance

| Rule | Current state | Required state |
|------|--------------|----------------|
| [IMPL-060] | Both consumers reimplement identical frame/node/failure handling | Ecosystem infrastructure must be used; ad-hoc reimplementation forbidden |
| [IMPL-INTENT] | Consumer run loops are ~300 lines of frame-switching mechanism | Should read as intent: "handle frame → act on result" |
| [PATTERN-013] | 2 consumers (parser-machine, binary-parser) | Meets threshold — both consume identical IR from machine-primitives |
| [PATTERN-052] | N/A (shared code doesn't exist yet) | Shared functions must be `@usableFromInline package` for cross-module inlining |
| [API-ERR-001] | Typed throws preserved in both consumers | Shared functions must preserve `throws(Failure)` chain |
| [API-NAME-001] | N/A | `Machine.Interpret.Frame.Action`, `Machine.Interpret.Node.Action`, `Machine.Interpret.Failure.Action` |
| [API-IMPL-005] | N/A | One type per file |

### Design: `Machine.Interpret`

#### Module

New target: **Machine Interpret Primitives**.

Dependencies: `Machine Frame Primitives`, `Machine Node Primitives`, `Machine Capture Primitives`.

```
Machine Frame Primitives + Machine Node Primitives + Machine Capture Primitives
                              ↓
                Machine Interpret Primitives (NEW)
```

Both consumers depend on `Machine Primitives` (umbrella), which re-exports the new module.

#### Action Enums

All use `@safe`. Conditional Sendable conformances mirror `Machine.Frame`/`Machine.Node` patterns.

**`Machine.Interpret.Frame.Action<NodeID, Checkpoint, Mode, Failure: Error, Extra>`**

```swift
case yield(Machine.Value<Mode>.Handle)
    // Transformed value ready — set as pending handle.
    // Produced by: .map, .tryMap (success), .sequence(.combine), .oneOf, .optional

case descend(NodeID)
    // Descend to a new node.
    // Produced by: .flatMap

case push(Machine.Frame<NodeID, Checkpoint, Mode, Failure, Extra>, descend: NodeID)
    // Push frame and descend to child.
    // Produced by: .sequence(.second), .many (continue), .fold (continue)

case failure(Failure)
    // Throwing transform failed — caller routes to failure recovery.
    // Produced by: .tryMap (failure)

case extra(Extra, Machine.Value<Mode>)
    // Domain-specific extra frame — caller handles.
    // Produced by: .extra (e.g. memoization stores success)

case recursiveReturn(Machine.Value<Mode>.Handle)
    // Recursive exit — caller decrements depth, then treats as yield.
    // Produced by: .recursiveExit
    // Rationale: depth tracking is execution-model state, not frame semantics.
    // Keeping it out of the function signature makes the depth mutation visible at the call site.
```

**`Machine.Interpret.Node.Action<Leaf, NodeID, Checkpoint, Mode, Failure: Error, Extra>`**

```swift
case leaf(Leaf)
    // Execute leaf — domain-specific.

case yield(Machine.Value<Mode>.Handle)
    // Pure value ready.

case descend(NodeID)
    // Descend to child (single-alternative oneOf, no frame needed).

case push(Machine.Frame<NodeID, Checkpoint, Mode, Failure, Extra>, descend: NodeID)
    // Push frame and descend to child.

case ref(target: NodeID)
    // Recursive reference — caller manages depth check + recursiveExit frame push.

case hole
    // Unpatched hole — fatalError at call site.
```

Note: `Checkpoint` and `Extra` are not generic parameters of `Machine.Node` — they are carried through the `Machine.Frame` type inside `.push`. Node dispatch only creates combinator frames (never `.extra`).

**`Machine.Interpret.Failure.Action<NodeID, Checkpoint, Mode, Failure: Error, Extra>`**

```swift
case recover(checkpoint: Checkpoint, pushFrame: Machine.Frame<NodeID, Checkpoint, Mode, Failure, Extra>, descend: NodeID)
    // Try next alternative — restore checkpoint, push frame, descend.
    // Produced by: .oneOf (has remaining alternatives)
    // pushFrame is non-Optional: only .oneOf produces .recover, always with a frame.

case ready(checkpoint: Checkpoint, handle: Machine.Value<Mode>.Handle)
    // Failure produced a ready value — restore checkpoint, yield handle.
    // Produced by: .many (finalize collected), .fold (return accumulator), .optional (return none)

case unwindRecursion
    // Recursive exit during unwind — caller decrements depth, continues unwinding.
    // Produced by: .recursiveExit

case extra(Extra)
    // Domain-specific extra frame — caller handles.
    // Produced by: .extra (e.g. memoization stores failure entry)

case skip
    // Skip this frame, continue unwinding.
    // Produced by: .map, .tryMap, .flatMap, .sequence, .oneOf (exhausted)
```

#### Shared Functions

Three `@inlinable package static` methods on `Machine.Interpret`. They never touch Input or the frame stack.

**`Machine.Interpret.frame()`** — handles one popped frame with a pending value:

```swift
@inlinable
package static func frame<NodeID, Checkpoint, Mode, Failure, Extra>(
    _ frame: Machine.Frame<NodeID, Checkpoint, Mode, Failure, Extra>,
    pending value: Machine.Value<Mode>,
    inputCheckpoint: Checkpoint,
    arena: inout Machine.Value<Mode>.Arena,
    captures: borrowing Machine.Capture.Frozen<Mode>
) -> Frame.Action<NodeID, Checkpoint, Mode, Failure, Extra>
```

- `inputCheckpoint` (not `checkpoint`) — distinguishes from `savedCheckpoint` inside frames. Read-only. Used by `.many`/`.fold` to save current position in continuation frames.
- No `depth` parameter — `.recursiveReturn(handle)` signals the caller to decrement.

**`Machine.Interpret.node()`** — dispatches one node:

```swift
@inlinable
package static func node<Leaf, Failure: Error, Mode, Checkpoint, Extra>(
    _ node: Machine.Node<Leaf, Failure, Mode>,
    inputCheckpoint: Checkpoint,
    arena: inout Machine.Value<Mode>.Arena
) -> Node.Action<Leaf, Machine.Node<Leaf, Failure, Mode>.ID, Checkpoint, Mode, Failure, Extra>
```

- No `captures` needed — node dispatch moves data from Node cases to Frame cases without carrier operations.
- `Checkpoint` and `Extra` are additional generics not on Node — carried through the Frame type.

**`Machine.Interpret.failure()`** — classifies one frame during failure recovery:

```swift
@inlinable
package static func failure<NodeID, Checkpoint, Mode, Failure: Error, Extra>(
    frame: Machine.Frame<NodeID, Checkpoint, Mode, Failure, Extra>,
    arena: inout Machine.Value<Mode>.Arena,
    captures: borrowing Machine.Capture.Frozen<Mode>
) -> Failure.Action<NodeID, Checkpoint, Mode, Failure, Extra>
```

- Consumer loops calling this per frame popped during unwinding.
- Consumer applies checkpoint restoration to input and manages depth.
- `arena` inout for `.many` finalization (release handles, finalize array) and handle passthrough.

#### Consumer Run Loop Shape

**Parser Machine (non-memoized)**:

```swift
while true {
    if let handle = pendingHandle {
        pendingHandle = nil
        let value = arena.release(handle)
        if frames.isEmpty { return value[as: Output.self] }
        guard let frame = frames.pop() else { fatalError() }

        switch Machine.Interpret.frame(frame, pending: value, inputCheckpoint: input.checkpoint,
                                       arena: &arena, captures: program.captures) {
        case .yield(let h):                  pendingHandle = h
        case .recursiveReturn(let h):        depth -= 1; pendingHandle = h
        case .descend(let node):             current = node
        case .push(let f, descend: let n):   try! frames.push(f); current = n
        case .failure(let error):
            switch handleFailure(error: error, ...) { /* .continueWith / .handleReady / .propagate */ }
        case .extra(let e, _):
            fatalError("Memoization in non-memoized")
        }
        continue
    }

    switch Machine.Interpret.node(program[current], inputCheckpoint: input.checkpoint, arena: &arena) {
    case .leaf(let leaf):
        do { pendingHandle = arena.allocate(try leaf.run(&input)) }
        catch { /* route to handleFailure */ }
    case .yield(let h):                  pendingHandle = h
    case .descend(let node):             current = node
    case .push(let f, descend: let n):   try! frames.push(f); current = n
    case .ref(let target):
        if let limit = program.maxDepth, depth >= limit { /* handleFailure */ }
        else { depth += 1; try! frames.push(.recursiveExit); current = target }
    case .hole: fatalError("Unpatched hole")
    }
}
```

`handleFailure` using shared failure classification:

```swift
func handleFailure(...) throws(Failure) -> Recovery {
    while let frame = frames.pop() {
        switch Machine.Interpret.failure(frame: frame, arena: &arena, captures: program.captures) {
        case .recover(let cp, let pushFrame, let node):
            input.setPosition(to: cp)
            try! frames.push(pushFrame)
            return .continueWith(node.retag(Recovery.Tag.self))
        case .ready(let cp, let h):
            input.setPosition(to: cp)
            return .handleReady(h)
        case .unwindRecursion:
            depth -= 1
        case .extra(.memoization):
            fatalError("Memoization in non-memoized")
        case .skip:
            continue
        }
    }
    return .propagate
}
```

**Parser Machine (memoized)** — same as above with two additions:

1. Before node dispatch — cache lookup:
```swift
    let memoKey = MemoKey(position: input.checkpoint, node: current.rawValue)
    if let cached = memoization.lookup(memoKey) {
        switch cached {
        case .success(let output, let endPosition):
            input.setPosition(to: endPosition)
            pendingHandle = arena.allocate(output)
            continue
        case .failure:
            // Route to handleMemoizedFailure
        }
    }
    try! frames.push(.extra(.memoization(node: current.rawValue, startPosition: input.checkpoint)))
```

2. Extra frame handling in both paths:
```swift
    // In frame() switch — memoization success:
    case .extra(.memoization(let node, let startPosition), let value):
        let key = MemoKey(position: startPosition, node: node)
        memoization.store(.success(output: value, end: input.checkpoint), for: key)
        pendingHandle = arena.allocate(value)

    // In failure() switch — memoization failure:
    case .extra(.memoization(let node, let startPosition)):
        let key = MemoKey(position: startPosition, node: node)
        memoization.store(.failure, for: key)
```

**Binary Parser** — same shared infrastructure with these domain-specific parts:

1. Leaf execution: `case .leaf(let instruction):` → switch on 21-case `Instruction` enum (unchanged)
2. Extra handling: `case .extra(let never, _): switch never {}` / `case .extra(let never): switch never {}` (uninhabited)
3. Stack migration: `[Frame]` → `Stack<Frame>` (add swift-stack-primitives dependency) — `Stack` supports `~Copyable` elements per [IMPL-060]
4. Error model change: `instructionError: Fault?` two-phase pattern → single-phase direct routing through action cases. Leaf failure enters `handleFailure` loop immediately. Semantics identical; control flow structure changes.

#### File Structure

Per [API-IMPL-005] (one type per file) and [API-IMPL-006] (dot-separated names):

```
Sources/Machine Interpret Primitives/
  exports.swift                              — @_exported imports
  Machine.Interpret.swift                    — namespace enum
  Machine.Interpret.Frame.swift              — namespace enum
  Machine.Interpret.Frame.Action.swift       — action enum + Sendable
  Machine.Interpret.Node.swift               — namespace enum
  Machine.Interpret.Node.Action.swift        — action enum + Sendable
  Machine.Interpret.Failure.swift            — namespace enum
  Machine.Interpret.Failure.Action.swift     — action enum + Sendable
  Machine.Interpret+Frame.swift              — frame() static function
  Machine.Interpret+Node.swift               — node() static function
  Machine.Interpret+Failure.swift            — failure() static function

Tests/Machine Interpret Primitives Tests/
  InterpretFrameTests.swift
  InterpretNodeTests.swift
  InterpretFailureTests.swift
```

### Section 2 Outcome

**RECOMMENDATION**: Implement `Machine Interpret Primitives` in swift-machine-primitives.

**Rationale**: [IMPL-060] — both consumers reimplement identical frame-handling, node-dispatch, and failure-recovery logic. The shared functions work purely with `Machine.Value`, `Machine.Frame`, carriers, and the arena — never touching Input. The `~Escapable` boundary is respected because leaf dispatch and input manipulation stay in the consumer.

**Implementation path**:
1. Add `Machine Interpret Primitives` target to swift-machine-primitives (Package.swift + source files + tests)
2. Add to umbrella re-exports
3. Migrate parser-machine-primitives run loops (non-memoized + memoized)
4. Migrate binary-parser-primitives run loop (`[Frame]` → `Stack<Frame>` + adopt Machine.Interpret)
5. Build and test: swift-machine-primitives, swift-parser-machine-primitives, swift-binary-parser-primitives, swift-foundations (swift-parsers downstream)

---

## Packages NOT Recommended for Machine Adoption

### Rendering-primitives

**Should NOT use machine-primitives.** The computational model diverges fundamentally:

| Concern | Machine (parsing) | Rendering |
|---------|-------------------|-----------|
| Computational model | Value-producing | Effect-only |
| Combinator match | 12/12 node types used | 4/12 partial match, 8 inapplicable |
| Return values | Every node yields `Machine.Value` | No return values — side effects only |
| Backtracking | Checkpoint-based with alternatives | None — one-pass traversal |
| Error handling | Typed failure recovery | None |
| Current machine | 3 work cases, ~15-line loop | Would become 12+ node cases, most dead |

Per [IMPL-060], machine-primitives does not provide equivalent functionality. Per [PATTERN-013], extending it for one consumer is premature. The rendering machine is right-sized: 3 cases, each one sentence of intent per [IMPL-INTENT].

### Serializer-primitives

**Should NOT use machine-primitives.** Serialization is fundamentally simpler:

- One-pass append — no backtracking, no alternatives, no recursion concerns
- Stateless closure wrappers — no graph structure needed
- `@Serializer.Builder` composition — different builder model from `Machine.Builder: ~Copyable`
- Adding machine would be mechanism inflation per [IMPL-INTENT]

**Exception**: If a future `Binary.Bytes.Machine.Serializer` needs `~Escapable` output buffers (the dual of binary parsing), machine-based serialization would be warranted. But this would be a new consumer, not retrofitting `Serializer.Protocol`.

---

## Deferred: Naming Fixes (Second Pass)

Identified during analysis, independent of Machine.Interpret:

| Current | Target | Rule | Rationale |
|---------|--------|------|-----------|
| `Machine.Builder` | `Machine.Program.Builder` | [API-NAME-001] | "A builder, for programs, in the machine domain" is more precise than "a builder in the machine domain" |
| `Binary.Bytes.Machine.Fault` | `Binary.Bytes.Machine.Error` | [API-ERR-002] | Error types must be nested as `Domain.Error` |
| `Rendering.Thunk` | `Rendering.Machine.Thunk` | [API-NAME-001] | Thunk is machine execution infrastructure, not a general rendering concept |

---

## Verification

1. `cd swift-machine-primitives && swift build` — new module compiles
2. `cd swift-machine-primitives && swift test` — Machine Interpret unit tests pass
3. `cd swift-parser-machine-primitives && swift build && swift test` — parser machine works with shared infrastructure
4. `cd swift-binary-parser-primitives && swift build && swift test` — binary parser works with shared infrastructure + Stack
5. `cd /Users/coen/Developer/swift-foundations && swift build` — swift-parsers (downstream) still builds

## References

- Reynolds, J.C. (1972). *Definitional interpreters for higher-order programming languages*. (Defunctionalization)
- `swift-rendering-primitives/Research/cooperative-pool-stack-overflow.md` (v6) — root cause analysis and option evaluation
- `swift-machine-primitives/Research/machine-value-api-surface.md` — Machine.Value extraction patterns
- `swift-institute/Research/Reflections/2026-03-18-iterative-render-machine-stack-overflow-fix.md`
- `swift-institute/Research/Reflections/2026-03-18-store-view-not-body-noncopyable-rendering.md`
- `swift-institute/Skills/implementation` — [IMPL-060], [IMPL-INTENT], [IMPL-035], [IMPL-036], [PATTERN-013]
- `swift-institute/Skills/code-surface` — [API-NAME-001], [API-ERR-002], [API-IMPL-005], [PATTERN-052]
