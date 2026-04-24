# swift-user-interface — Tree Traversal

<!--
---
version: 1.0.0
last_updated: 2026-04-21
status: DECISION
tier: 2
scope: cross-package
---
-->

## Context

Follow-up to `danceui-architectural-analysis.md`. DanceUI uses the **visitor
pattern** extensively for view-tree traversal:
`MultiPreferenceCombinerVisitor`, `PairwisePreferenceCombinerVisitor`,
`ResolvedPaintVisitor`, `_VariadicView_ImplicitRootVisitor`, `MakeViewRoot`.
Visitors open existentials and dispatch through protocol conformances.
Before we commit to any traversal style in `swift-user-interface`, we need
to decide whether visitors are avoidable in our ecosystem — specifically
for the `@ViewBuilder` / `TupleView` case where variadic heterogeneous
children are the core challenge.

## Question

Does `swift-machine-primitives` + `swift-rendering-primitives` (+
`swift-witness-primitives`) let us walk a `@ViewBuilder`-shaped declarative
tree with typed composition end-to-end, without reaching for visitor-based
existential dispatch? If yes, is a visitor ever genuinely needed anywhere
in a view-tree pass?

## Analysis

### 1. `Machine.Node` is a typed heterogeneous AST

`/Users/coen/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Node Primitives/Machine.Node.swift` models a graph of nodes with **statically-typed** child references via phantom-tagged `ID`s. Cases include `leaf`, `pure`, `map`, `flatMap`, `sequence`, `oneOf`, `many`, `fold`, `optional`, `ref`, `hole`. Heterogeneous composition is supported: `sequence(a: ID, b: ID, combine: Combine.Erased<Mode>)` composes two distinct machine expressions with a witness-closure combiner (`Machine.Combine.Erased`). Erasure happens at the combiner closure level, not at the node level — the walker remains statically typed.

### 2. `Rendering.View` is a typed tree walk with witness dispatch

`/Users/coen/Developer/swift-primitives/swift-rendering-primitives/Sources/Rendering Primitives Core/Rendering.View.swift`:

```swift
public protocol View: ~Copyable {
    associatedtype Body: View & ~Copyable
    @Builder var body: Body { get }
    static func _render(_ view: borrowing Self, context: inout Context)
}
```

`Rendering.Context` is a mutable `~Copyable` context. The walk loop is
iterative / stack-based — `Rendering.Thunk` stores a typed dispatch fn:

```swift
struct Thunk {
    let dispatch: (UnsafeMutableRawPointer, inout Rendering.Context) -> Void
    init<Body: Rendering.View>(_: Body.Type) { ... }
}
```

This is **witness-based typed dispatch** — the `Body.Type` is known at
thunk construction, and the dispatch fn captures it. No existential `any
View`, no protocol-conformance lookup at each step.

### 3. `Rendering._Tuple<each Content>` covers TupleView natively

`/Users/coen/Developer/swift-primitives/swift-rendering-primitives/Sources/Rendering Primitives Core/Rendering._Tuple.swift`:

```swift
@resultBuilder
public enum Builder {
    public static func buildBlock<each Content>(
        _ content: repeat each Content
    ) -> Rendering._Tuple<repeat each Content> { ... }
}

public struct _Tuple<each Content> {
    public let content: (repeat each Content)
}

extension Rendering._Tuple: Rendering.View
where repeat each Content: Rendering.View {
    public static func _render(_ view: borrowing Self, context: inout Context) {
        repeat push(each view.content, &context)
    }
}
```

Variadic generics unpack statically. The same file also defines
`Rendering.Conditional<First, Second>` as a typed enum with `case first` /
`case second` — an `if` in `@ViewBuilder` lowers to this, and the `_render`
switch is static case dispatch into each branch's concrete `_render`.

### 4. `@ViewBuilder { Text; Image; if flag { Button } }` — end to end

Lowering trace:

- `Text("a")` → `Text` (concrete `View`)
- `Image(...)` → `Image`
- `if flag { Button("x") }` → `Rendering.Conditional<Button, EmptyView>`
- Combined: `Rendering._Tuple<Text, Image, Rendering.Conditional<Button, EmptyView>>`

The final tree's static type is spelled out end to end. Every `_render`
dispatch is to a concrete type. No `any View` appears.

### 5. Witnesses over protocols, already in the ecosystem

`/Users/coen/Developer/swift-primitives/swift-parser-machine-primitives/Sources/Parser Machine Compile Primitives/Parser.Machine.Compile.Witness.swift`:

```swift
public struct Witness<P: Parser_Primitives.Parser.Protocol> {
    let _compile: (P, inout Parser.Machine.Builder<P.Input, P.Failure>)
        -> Parser.Machine.Expression<P.Input, P.Failure, P.Output>
}
```

This is already how the parser-machine composes. The rendering and machine
primitives use the same pattern:

- DanceUI: protocol conformance (`MultiPreferenceCombinerVisitor`) with
  existentials
- swift-primitives: typed Node tree + closure-witnesses in capture tables
  (`Machine.Combine.Erased`), typed `Rendering.Thunk` dispatch, typed
  `Rendering._Tuple`

### 6. The genuinely unavoidable visitor case

Multi-pass traversal where every node must be visited to compute a
*global* value across the whole tree — classic example is DanceUI's
`MultiPreferenceCombinerVisitor` accumulating preference values across the
entire tree. Even there, the accumulation can be expressed as a **fold
over the action stream** the rendering pass already produces: the tree
walk emits `push` / `pop` / `Action` events, and a consumer folds them
into a preference map. That fold is typed, and the visitor disappears.

For a *single-pass* traversal (rendering, layout, measurement, a11y
extraction), witnesses + typed trees suffice. For multi-pass accumulation,
the same action stream is reused; different consumers fold it differently.
In neither case does an existential-opening visitor become necessary.

### Comparison

| Criterion                          | Visitor (DanceUI)         | Witness + typed tree (ours) |
|------------------------------------|---------------------------|-----------------------------|
| Type erasure                        | Required (`any View`)     | None                         |
| Dispatch cost                       | Protocol witness table    | Static / closure            |
| Typed throws compatible             | Hard                      | Yes                          |
| `~Copyable` compatible              | Hard                      | Yes (`Rendering.View: ~Copyable`) |
| Multi-pass accumulation             | Dedicated visitor per pass | Fold over action stream      |
| Source-compat with SwiftUI          | Yes (SwiftUI works this way) | No (but we don't want it)  |

## Outcome

**Status**: DECISION.

**Decision**: `swift-user-interface` will use **typed tree traversal via
witnesses**, not the visitor pattern. Specifically:

1. The View protocol mirrors `Rendering.View`: `static func _render(_ view:
   borrowing Self, context: inout Context)`, with `@Builder var body:
   Body { get }`.
2. `@ViewBuilder` composition lowers to `Rendering._Tuple<repeat each
   Content>` and `Rendering.Conditional<First, Second>`. The final tree
   type is fully concrete.
3. Dynamic dispatch, where unavoidable (e.g., storing a subtree of unknown
   type in a container), uses `Rendering.Thunk`-style typed witnesses,
   not `any View`.
4. Multi-pass accumulation (preference combine, a11y extraction, tree
   diagnostics) is expressed as a **fold over the action stream** produced
   by a single rendering walk, not as a per-pass visitor.

**Why**: the substrate is already in place (`swift-rendering-primitives`,
`swift-machine-primitives`, `swift-witness-primitives`,
`swift-parser-machine-primitives`). The same pattern is already used
elsewhere in the ecosystem. No new machinery is introduced; we inherit
typed composition, `~Copyable` compatibility, and typed throws for free.

**Consequences**:

- SwiftUI source-compat is out of scope (already decided in the parent
  research). A SwiftUI-interop adapter, if wanted, lives in its own sibling
  foundations package where visitor-style code may appear in the adapter
  boundary only.
- `@ViewBuilder` macro (if any is needed beyond `@resultBuilder`) is minimal
  and lowers to existing `Rendering._Tuple` / `Rendering.Conditional`.
- The DanceUI subsystems listed as visitor-based (preference combiners,
  paint resolution, implicit root visitor) all collapse to folds over the
  rendering action stream.

## References

- `/Users/coen/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Node Primitives/Machine.Node.swift`
- `/Users/coen/Developer/swift-primitives/swift-machine-primitives/Sources/Machine Combine Primitives/Machine.Combine.Erased.swift`
- `/Users/coen/Developer/swift-primitives/swift-rendering-primitives/Sources/Rendering Primitives Core/Rendering.View.swift`
- `/Users/coen/Developer/swift-primitives/swift-rendering-primitives/Sources/Rendering Primitives Core/Rendering._Tuple.swift`
- `/Users/coen/Developer/swift-primitives/swift-rendering-primitives/Sources/Rendering Primitives Core/Rendering.Conditional.swift`
- `/Users/coen/Developer/swift-primitives/swift-rendering-primitives/Sources/Rendering Primitives Core/Rendering.Thunk.swift`
- `/Users/coen/Developer/swift-primitives/swift-parser-machine-primitives/Sources/Parser Machine Compile Primitives/Parser.Machine.Compile.Witness.swift`
- `/Users/coen/Developer/bytedance/DanceUI/Sources/DanceUI/Internal/_VariadicView/`
- `/Users/coen/Developer/bytedance/DanceUI/Sources/DanceUI/Internal/Visitor/`
