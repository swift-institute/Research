# Graph Extraction and Dependency Structure: swift-machine-primitives and swift-graph-primitives

<!--
---
document_type: architectural_analysis
version: 1.0.0
date: 2026-01-19
author: Swift Institute
status: RECOMMENDATION
related_packages:
  - swift-machine-primitives
  - swift-graph-primitives
---
-->

## Abstract

The `swift-machine-primitives` package implements a defunctionalized parser combinator architecture centered on `Machine.Program`—an explicit graph of nodes representing parsing operations. This paper analyzes whether the graph-related abstractions in `machine-primitives` should be extracted to the currently-stubbed `swift-graph-primitives` package, establishing a dependency where `machine-primitives` depends on `graph-primitives`. We identify which components are genuinely graph-generic versus parsing-specific, propose a concrete extraction boundary, and evaluate the architectural trade-offs of this refactoring.

---

## 1. Current State

### 1.1 swift-graph-primitives: Infrastructure Without Implementation

The `swift-graph-primitives` package exists as a skeleton repository:

**Present:**
- GitHub workflows (CI/CD for macOS, Ubuntu, Windows)
- Code formatting and linting configuration
- Apache 2.0 license
- Standard `.gitignore`

**Absent:**
- `Package.swift`
- `Sources/` directory
- Any Swift implementation

This suggests a planned package awaiting design decisions, not an abandoned one.

### 1.2 swift-machine-primitives: Graph Abstractions Embedded in Parsing

The `machine-primitives` package contains substantial graph infrastructure:

| Component | Lines | Purpose |
|-----------|-------|---------|
| `Machine.Node` | ~70 | Node enum with 12 variant cases |
| `Machine.Program` | ~40 | Immutable graph container |
| `Machine.Program.Builder` | ~35 | Mutable graph construction |
| `Machine.Frame` | ~50 | Execution stack frames |
| `Machine.Value.*` | ~150 | Type-erased value storage |
| `Machine.Capture.*` | ~300 | Capture store infrastructure |
| `Machine.Transform/Combine/Next/Finalize` | ~200 | Type-erased operations |

Total: ~850 lines of graph-related code interleaved with parsing-specific semantics.

---

## 2. Separation Analysis

### 2.1 The Core Question

Can we cleanly separate:
1. **Graph structure**: Nodes, edges, IDs, containers, builders
2. **Machine semantics**: Parsing operations, captures, execution frames, type erasure

### 2.2 Node Taxonomy

Examining `Machine.Node<Leaf, Failure, Mode>`:

```swift
public enum Node<Leaf, Failure: Error, Mode> {
    // Graph-generic (no parsing semantics)
    case pure(Value<Mode>)                           // Constant node
    case map(child: ID, transform: Transform.Erased<Mode>)
    case sequence(a: ID, b: ID, combine: Combine.Erased<Mode>)
    case oneOf([ID])                                 // Branching
    case ref(ID)                                     // Recursion
    case hole                                        // Forward reference

    // Parsing-flavored but structurally generic
    case tryMap(child: ID, transform: Transform.Throwing<Mode, Failure>)
    case flatMap(child: ID, next: Next.Erased<Mode, ID>)
    case many(child: ID, finalize: Finalize.Array<Mode>)
    case fold(child: ID, initial: Value<Mode>, combine: Combine.Erased<Mode>)
    case optional(child: ID, wrapSome: Transform.Erased<Mode>, noneValue: Value<Mode>)

    // Domain-specific
    case leaf(Leaf)                                  // Primitive operation
}
```

**Observation**: 11 of 12 cases are graph combinators parameterized by operation references. Only `leaf` is truly domain-specific—it injects external operations into the graph.

### 2.3 The Mode Entanglement

The `Mode` type parameter threads through everything:

```swift
Node<Leaf, Failure, Mode>
Program<Leaf, Failure, Mode>
Builder<Leaf, Failure, Mode>
Transform.Erased<Mode>
Capture.Store<Mode>
Capture.Frozen<Mode>
```

`Mode` controls Sendability stratification (`Mode.Reference` vs `Mode.Unchecked`). This is a machine-primitives concern—it determines whether captured closures must be `Sendable`.

**Question**: Can graph-primitives be mode-agnostic?

### 2.4 The Capture Coupling

The `Transform.Erased<Mode>`, `Combine.Erased<Mode>`, etc. types store `Capture.RawID` references into a `Capture.Frozen<Mode>` store. The graph nodes don't store closures—they store references to closures in an external store.

This design enables:
- Structural Sendability (no closure captures in nodes)
- Inspectability (nodes are pure data)
- Heterogeneous type erasure (captures have different types)

**But it couples** graph structure to capture infrastructure.

---

## 3. Extraction Strategies

### 3.1 Strategy A: Minimal Graph Primitives

Extract only the most generic components:

```swift
// Graph.Primitives

public struct ID<Tag, Raw: Hashable>: Hashable, Sendable {
    public let rawValue: Raw
}

public protocol GraphNode {
    associatedtype NodeID: Hashable
    func children() -> [NodeID]
}

public struct Graph<Node: GraphNode> {
    public let nodes: [Node]
    public subscript(id: Node.NodeID) -> Node { ... }
}

public struct GraphBuilder<Node: GraphNode> {
    public mutating func allocate(_ node: Node) -> Node.NodeID
    public consuming func build() -> Graph<Node>
}
```

**Machine.Primitives would:**
- Define `Machine.Node` conforming to `GraphNode`
- Use `Graph<Machine.Node>` internally or wrap it
- Keep all capture, transform, and mode infrastructure

**Pros:**
- Minimal extraction surface
- Graph-primitives is truly generic
- No mode coupling

**Cons:**
- Limited code sharing (mostly patterns, not implementations)
- Machine.Node still contains all complexity
- `GraphNode` protocol may be too abstract to be useful

### 3.2 Strategy B: Combinator-Aware Graph Primitives

Extract graph combinators as a vocabulary:

```swift
// Graph.Primitives

public enum Combinator<Leaf, NodeID, OperationRef> {
    case leaf(Leaf)
    case pure(OperationRef)
    case map(child: NodeID, operation: OperationRef)
    case sequence(a: NodeID, b: NodeID, operation: OperationRef)
    case branch([NodeID])
    case recurse(NodeID)
    case placeholder
    // ... etc
}

public struct Program<Leaf, NodeID, OperationRef> {
    public let nodes: [Combinator<Leaf, NodeID, OperationRef>]
}
```

**Machine.Primitives would:**
- Use `Graph.Combinator` as the underlying node type
- Define `OperationRef` as `Capture.RawID` or similar
- Layer machine semantics (Mode, Failure, Frame) on top

**Pros:**
- More substantial extraction
- Combinator vocabulary is reusable
- Clear separation of structure vs. semantics

**Cons:**
- `OperationRef` abstraction may be leaky
- Loss of domain-specific node names (`tryMap`, `flatMap`, `many`, `fold`, `optional`)
- Two levels of indirection

### 3.3 Strategy C: Keep Machine.Node, Extract Infrastructure

Keep `Machine.Node` as-is but extract supporting infrastructure:

```swift
// Graph.Primitives

public struct TaggedID<Tag, Raw: Hashable & Sendable>: Hashable, Sendable {
    public let rawValue: Raw
}

public protocol SequentiallyAllocated {
    associatedtype ID: Hashable
    static func id(for index: Int) -> ID
}

public struct SequentialGraph<Element: SequentiallyAllocated> {
    public let elements: [Element]
    public subscript(id: Element.ID) -> Element { ... }
}

public struct SequentialGraphBuilder<Element: SequentiallyAllocated> {
    public var elements: [Element]
    public mutating func allocate(_ element: Element) -> Element.ID
}
```

**Machine.Primitives would:**
- Conform `Machine.Node` to `SequentiallyAllocated`
- Use `SequentialGraph<Machine.Node>` as storage
- Keep all node definitions and semantics

**Pros:**
- Extracts the "array of nodes with integer IDs" pattern
- Minimal conceptual overhead
- Machine.Node unchanged

**Cons:**
- Very thin abstraction
- Questionable whether worth a separate package
- Doesn't address combinator generality

### 3.4 Strategy D: No Extraction (Status Quo with Documentation)

Keep all code in `machine-primitives`. Use `graph-primitives` for different graph abstractions (adjacency lists, generic traversal algorithms, etc.) unrelated to the combinator pattern.

**Pros:**
- No refactoring risk
- Machine.Primitives remains self-contained
- Graph.Primitives can serve different needs

**Cons:**
- Combinator pattern not reusable
- Larger machine-primitives package
- Potential duplication if other packages need similar patterns

---

## 4. Recommendation: Strategy C with Extensions

### 4.1 Rationale

The combinator vocabulary in `Machine.Node` is valuable but deeply intertwined with:
- The `Mode` stratification system
- The capture store pattern
- Typed throws (`Failure`)

Attempting to factor out combinators (Strategy B) would either:
- Lose the vocabulary (generic `operation: OperationRef`)
- Duplicate the vocabulary (both Graph.Combinator and Machine.Node)

Strategy C extracts what is genuinely generic—sequential allocation with tagged IDs—while preserving Machine.Node's expressive power.

### 4.2 Proposed Graph.Primitives Contents

```
swift-graph-primitives/
├── Package.swift
└── Sources/
    └── Graph Primitives/
        ├── Graph.swift                    // Namespace
        ├── Graph.ID.swift                 // TaggedID<Tag, Raw>
        ├── Graph.Sequential.swift         // SequentialGraph<Element>
        ├── Graph.Sequential.Builder.swift // Builder pattern
        ├── Graph.Visitor.swift            // Generic traversal protocol
        └── Graph.Analysis.swift           // Reachability, cycles, etc.
```

### 4.3 Proposed Dependency Structure

```
┌─────────────────────────┐
│ Identity.Primitives     │
└─────────────────────────┘
           ↑
           │
┌─────────────────────────┐
│ Graph.Primitives        │
│  - TaggedID             │
│  - SequentialGraph      │
│  - Visitor protocol     │
│  - Analysis algorithms  │
└─────────────────────────┘
           ↑
           │
┌─────────────────────────────────┐
│ Machine.Primitives              │
│  - Machine.Node (full vocab)    │
│  - Machine.Program (wraps       │
│    SequentialGraph internally)  │
│  - Capture infrastructure       │
│  - Frame, Transform, etc.       │
└─────────────────────────────────┘
           ↑
           │
┌─────────────────────────────────┐
│ Parsing.Primitives              │
│  - Parsing.Machine              │
│  - Memoization                  │
│  - Incremental parsing          │
└─────────────────────────────────┘
```

### 4.4 What Machine.Primitives Would Extract

**Move to Graph.Primitives:**
- `TaggedID` pattern (currently `Tagged<Tag, Int>` from Identity.Primitives—may already be there)
- Sequential array + ID indexing pattern
- Generic graph visitor protocol
- Cycle detection, reachability analysis (if/when needed)

**Keep in Machine.Primitives:**
- `Machine.Node` enum (all 12 cases)
- `Machine.Program` (wrapping `SequentialGraph` + captures)
- `Machine.Program.Builder` (wrapping `SequentialGraphBuilder` + capture store)
- All capture infrastructure
- All frame/execution infrastructure
- All type-erased operation wrappers

### 4.5 Interface Sketch

```swift
// Graph.Primitives

public struct SequentialGraph<Element> {
    public let elements: [Element]

    @inlinable
    public subscript<ID: RawRepresentable>(id: ID) -> Element
        where ID.RawValue == Int
    {
        elements[id.rawValue]
    }
}

public struct SequentialGraphBuilder<Element> {
    public var elements: [Element] = []

    @inlinable
    public mutating func allocate<ID: RawRepresentable>(_ element: Element) -> ID
        where ID.RawValue == Int, ID: ExpressibleByIntegerLiteral
    {
        let id = ID(rawValue: elements.count)!
        elements.append(element)
        return id
    }

    @inlinable
    public consuming func build() -> SequentialGraph<Element> {
        SequentialGraph(elements: elements)
    }
}
```

```swift
// Machine.Primitives

public struct Program<Leaf, Failure: Error, Mode> {
    @usableFromInline
    let graph: SequentialGraph<Node<Leaf, Failure, Mode>>

    public let captures: Capture.Frozen<Mode>
    public let maxDepth: Int?

    @inlinable
    public subscript(id: Node<Leaf, Failure, Mode>.ID) -> Node<Leaf, Failure, Mode> {
        graph[id]
    }
}
```

---

## 5. Trade-off Analysis

### 5.1 Benefits of Extraction

| Benefit | Impact |
|---------|--------|
| Reusable sequential graph pattern | Other packages can use array+ID storage |
| Cleaner layering | Graph structure separate from execution semantics |
| Testable in isolation | Graph algorithms tested without machine dependencies |
| Validates architecture | Proves combinator design is layered correctly |

### 5.2 Costs of Extraction

| Cost | Impact |
|------|--------|
| Additional package dependency | Build complexity, version coordination |
| Indirection overhead | Minor—`@inlinable` eliminates at compile time |
| Design coordination | Graph.Primitives API must satisfy Machine needs |
| Migration effort | Refactoring existing code and tests |

### 5.3 Risk Assessment

**Low risk**: The extraction is mechanical. `Machine.Program` already uses `[Node]` with integer indexing. Wrapping this in `SequentialGraph` changes no semantics.

**Medium risk**: Designing `Graph.Visitor` protocol that works for both generic graphs and the specific traversal needs of `Machine.Program`. May require iteration.

**Low risk**: The dependency direction is correct. Graph.Primitives has no knowledge of parsing; Machine.Primitives builds on generic graph infrastructure.

---

## 6. Implementation Path

### Phase 1: Establish Graph.Primitives (Non-Breaking)

1. Create `Package.swift` in `swift-graph-primitives`
2. Implement `Graph.ID` (or use Identity.Primitives)
3. Implement `SequentialGraph<Element>`
4. Implement `SequentialGraphBuilder<Element>`
5. Add comprehensive tests

### Phase 2: Add Graph Analysis (Optional)

1. Design `Graph.Visitor` protocol
2. Implement reachability analysis
3. Implement cycle detection
4. These are useful for Machine.Program optimization passes

### Phase 3: Migrate Machine.Primitives

1. Add dependency on `Graph.Primitives`
2. Refactor `Machine.Program` to use `SequentialGraph` internally
3. Refactor `Machine.Program.Builder` to use `SequentialGraphBuilder`
4. Verify all tests pass
5. Verify Sendability conformances unchanged

### Phase 4: Documentation

1. Update companion documentation
2. Add migration guide if API changed
3. Document the layering rationale

---

## 7. Open Questions

### 7.1 Should Graph.Primitives Support Non-Sequential Graphs?

The current Machine.Program uses sequential allocation (node ID = array index). Some graph use cases need:
- Sparse graphs (hash map storage)
- Persistent graphs (structural sharing)
- Mutable graphs (insert/delete)

**Recommendation**: Start with sequential only. Add other representations when concrete needs arise.

### 7.2 Should Graph.Primitives Include Combinator Vocabulary?

A generic `Combinator<Leaf, ID, OpRef>` enum could be useful for other defunctionalized systems (state machines, query plans, etc.).

**Recommendation**: Not in Phase 1. The Machine.Node vocabulary is parsing-flavored (`many`, `optional`, `tryMap`). A truly generic combinator vocabulary would look different. Revisit after seeing other use cases.

### 7.3 How Does This Affect Sendability?

`SequentialGraph<Element>: Sendable where Element: Sendable`

Machine.Program's Sendability depends on:
- `Node<Leaf, Failure, Mode>: Sendable where Leaf: Sendable, Failure: Sendable, Mode: Sendable`
- `Capture.Frozen<Mode>: Sendable where Mode: Sendable`

The extraction preserves this structure. No `@unchecked Sendable` needed.

---

## 8. Conclusion

The `swift-machine-primitives` package contains graph abstractions that are partially generic and partially parsing-specific. A clean extraction is possible but should be limited to:

1. **Sequential graph container**: Array storage with typed ID indexing
2. **Sequential graph builder**: Allocation pattern with ID generation
3. **Graph analysis utilities**: Visitor protocol, reachability, cycle detection

The `Machine.Node` vocabulary, capture infrastructure, and execution semantics should remain in `machine-primitives`. Attempting to generalize the combinator vocabulary would sacrifice expressiveness without clear benefit.

The recommended dependency structure:

```
Graph.Primitives  ←  Machine.Primitives  ←  Parsing.Primitives
```

This layering validates the Five-Layer Architecture principle: lower layers are generic infrastructure; higher layers add domain semantics. The extraction is low-risk, provides modest code sharing, and establishes a foundation for future graph-based packages in the ecosystem.

---

*Document version 1.0.0. Last updated 2026-01-19.*
