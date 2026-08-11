# Maximalist Graph Extraction: Building Machine.Primitives on Graph.Primitives

<!--
---
document_type: architectural_analysis
version: 1.0.0
date: 2026-01-19
author: Swift Institute
status: RECOMMENDATION
supersedes: "Analysis - Graph Extraction and Dependency Structure.md"
design_principle: Maximize primitive reuse
---
-->

## Design Principle

> If we are building a primitives ecosystem, then `Graph.Primitives` should be **the** graph package—complete, general-purpose, and reusable. `Machine.Primitives` should add only what is specific to defunctionalized execution, building entirely on graph infrastructure.

This analysis reverses the question from "what can we extract?" to "what does a complete graph primitives package look like, and how does Machine.Primitives specialize it?"

---

## 1. What Is a Graph?

At the primitive level, a graph is:

1. **Nodes**: Discrete elements with identity
2. **Edges**: Directed relationships between nodes
3. **Payloads**: Data attached to nodes and/or edges
4. **Structure**: The topology (DAG, tree, cyclic, etc.)

Everything else—traversal, analysis, mutation, serialization—is operations on this foundation.

---

## 2. Graph.Primitives: The Complete Package

### 2.1 Core Types

```swift
// Graph.Primitives

/// A unique identifier for a node within a graph.
public struct Node<Tag>: Hashable, Sendable {
    public let rawValue: Int
}

/// A directed edge from source to target.
public struct Edge<Tag>: Hashable, Sendable {
    public let source: Node<Tag>
    public let target: Node<Tag>
}

/// A graph storing nodes with payloads of type `Payload`.
public struct Graph<Tag, Payload> {
    public let nodes: [Payload]

    @inlinable
    public subscript(node: Node<Tag>) -> Payload {
        nodes[node.rawValue]
    }

    @inlinable
    public var nodeIDs: some Swift.Sequence<Node<Tag>> {
        nodes.indices.lazy.map { Node(rawValue: $0) }
    }
}

extension Graph: Sendable where Payload: Sendable {}
```

### 2.2 Builder Pattern

```swift
/// Mutable builder for constructing graphs.
public struct Graph<Tag, Payload>.Builder {
    public var nodes: [Payload]

    public init() { self.nodes = [] }

    @inlinable
    public mutating func allocate(_ payload: Payload) -> Node<Tag> {
        let id = Node<Tag>(rawValue: nodes.count)
        nodes.append(id)
        return id
    }

    /// Allocate a placeholder node to be filled later.
    @inlinable
    public mutating func allocateHole() -> Node<Tag> where Payload: Defaultable {
        allocate(.default)
    }

    /// Fill a previously allocated hole.
    @inlinable
    public mutating func fill(_ node: Node<Tag>, with payload: Payload) {
        nodes[node.rawValue] = payload
    }

    @inlinable
    public consuming func build() -> Graph<Tag, Payload> {
        Graph(nodes: nodes)
    }
}
```

### 2.3 Edge Extraction Protocol

Graphs don't store edges explicitly—they're encoded in payloads. A protocol extracts them:

```swift
/// A payload type that contains references to other nodes.
public protocol GraphPayload {
    associatedtype Tag

    /// All nodes this payload references (outgoing edges).
    func children() -> [Node<Tag>]

    /// Transform all node references using the given mapping.
    func mapChildren(_ transform: (Node<Tag>) -> Node<Tag>) -> Self
}
```

### 2.4 Traversal Infrastructure

```swift
/// Depth-first traversal order.
public struct DepthFirst<Tag, Payload: GraphPayload>: Swift.Sequence
    where Payload.Tag == Tag
{
    public let graph: Graph<Tag, Payload>
    public let roots: [Node<Tag>]

    // Iterator implementation...
}

/// Breadth-first traversal order.
public struct BreadthFirst<Tag, Payload: GraphPayload>: Swift.Sequence
    where Payload.Tag == Tag
{
    // ...
}

/// Topological sort (for DAGs).
public struct TopologicalOrder<Tag, Payload: GraphPayload>: Swift.Sequence
    where Payload.Tag == Tag
{
    // ...
}

extension Graph where Payload: GraphPayload, Payload.Tag == Tag {
    public func depthFirst(from roots: [Node<Tag>]) -> DepthFirst<Tag, Payload>
    public func breadthFirst(from roots: [Node<Tag>]) -> BreadthFirst<Tag, Payload>
    public func topological() -> TopologicalOrder<Tag, Payload>?
}
```

### 2.5 Analysis Algorithms

```swift
extension Graph where Payload: GraphPayload, Payload.Tag == Tag {
    /// All nodes reachable from the given roots.
    public func reachable(from roots: [Node<Tag>]) -> Set<Node<Tag>>

    /// Whether the graph contains cycles.
    public var hasCycles: Bool

    /// Strongly connected components.
    public func stronglyConnectedComponents() -> [[Node<Tag>]]

    /// Nodes with no incoming edges.
    public func roots() -> [Node<Tag>]

    /// Nodes with no outgoing edges.
    public func leaves() -> [Node<Tag>]
}
```

### 2.6 Transformation

```swift
extension Graph {
    /// Map payloads without changing structure.
    public func mapPayloads<NewPayload>(
        _ transform: (Payload) -> NewPayload
    ) -> Graph<Tag, NewPayload>

    /// Filter to subgraph containing only specified nodes.
    public func subgraph(
        containing nodes: Set<Node<Tag>>
    ) -> Graph<Tag, Payload> where Payload: GraphPayload, Payload.Tag == Tag
}

extension Graph where Payload: GraphPayload, Payload.Tag == Tag {
    /// Remap all node references (for embedding graphs).
    public func offsetNodes(by delta: Int) -> Graph<Tag, Payload>
}
```

### 2.7 Visitor Protocol

```swift
/// Protocol for graph visitors (double-dispatch pattern).
public protocol GraphVisitor {
    associatedtype Tag
    associatedtype Payload: GraphPayload where Payload.Tag == Tag
    associatedtype Result

    mutating func visit(node: Node<Tag>, payload: Payload, in graph: Graph<Tag, Payload>) -> Result
    mutating func descend(into child: Node<Tag>) -> Bool
}

extension Graph where Payload: GraphPayload, Payload.Tag == Tag {
    public func accept<V: GraphVisitor>(_ visitor: inout V) -> [V.Result]
        where V.Tag == Tag, V.Payload == Payload
}
```

### 2.8 Mutable Graphs (Optional)

```swift
/// A mutable graph supporting insertion and deletion.
public struct MutableGraph<Tag, Payload> {
    public var nodes: [Payload?]  // Sparse storage
    private var freeList: [Int]

    public mutating func insert(_ payload: Payload) -> Node<Tag>
    public mutating func remove(_ node: Node<Tag>) -> Payload?
    public mutating func update(_ node: Node<Tag>, with payload: Payload)
}
```

---

## 3. What Machine.Primitives Adds

With a complete Graph.Primitives, Machine.Primitives becomes a thin specialization layer:

### 3.1 The Machine-Specific Node Payload

```swift
// Machine.Primitives

import Graph_Primitives

/// Tag type for machine program graphs.
public enum MachineTag {}

/// A node in a defunctionalized machine program.
public enum Instruction<Leaf, Failure: Error, Mode> {
    // Primitives
    case leaf(Leaf)
    case pure(Value<Mode>)

    // Unary combinators
    case map(child: Graph.Node<MachineTag>, transform: Transform.Erased<Mode>)
    case tryMap(child: Graph.Node<MachineTag>, transform: Transform.Throwing<Mode, Failure>)
    case flatMap(child: Graph.Node<MachineTag>, next: Next.Erased<Mode, Graph.Node<MachineTag>>)
    case many(child: Graph.Node<MachineTag>, finalize: Finalize.Array<Mode>)
    case optional(child: Graph.Node<MachineTag>, wrapSome: Transform.Erased<Mode>, noneValue: Value<Mode>)

    // Binary combinators
    case sequence(a: Graph.Node<MachineTag>, b: Graph.Node<MachineTag>, combine: Combine.Erased<Mode>)
    case fold(child: Graph.Node<MachineTag>, initial: Value<Mode>, combine: Combine.Erased<Mode>)

    // Control flow
    case oneOf([Graph.Node<MachineTag>])
    case ref(Graph.Node<MachineTag>)

    // Construction
    case hole
}
```

### 3.2 GraphPayload Conformance

```swift
extension Instruction: GraphPayload {
    public typealias Tag = MachineTag

    public func children() -> [Graph.Node<MachineTag>] {
        switch self {
        case .leaf, .pure, .hole:
            return []
        case .map(let child, _), .tryMap(let child, _), .flatMap(let child, _),
             .many(let child, _), .optional(let child, _, _), .ref(let child):
            return [child]
        case .sequence(let a, let b, _), .fold(let child, _, _):
            return [a, b]  // fold has child + implicit accumulator path
        case .oneOf(let alternatives):
            return alternatives
        }
    }

    public func mapChildren(_ transform: (Graph.Node<MachineTag>) -> Graph.Node<MachineTag>) -> Self {
        switch self {
        case .leaf, .pure, .hole:
            return self
        case .map(let child, let t):
            return .map(child: transform(child), transform: t)
        // ... etc for all cases
        }
    }
}

extension Instruction: Sendable
    where Leaf: Sendable, Failure: Sendable, Mode: Sendable {}
```

### 3.3 Machine.Program as Graph + Captures

```swift
/// A complete machine program: graph + capture store.
public struct Program<Leaf, Failure: Error, Mode> {
    /// The instruction graph.
    public let graph: Graph<MachineTag, Instruction<Leaf, Failure, Mode>>

    /// Captured values referenced by instructions.
    public let captures: Capture.Frozen<Mode>

    /// Maximum recursion depth (optional).
    public let maxDepth: Int?

    /// Entry point of the program.
    public let entry: Graph.Node<MachineTag>

    // Convenience subscript
    @inlinable
    public subscript(node: Graph.Node<MachineTag>) -> Instruction<Leaf, Failure, Mode> {
        graph[node]
    }
}

extension Program: Sendable
    where Leaf: Sendable, Failure: Sendable, Mode: Sendable {}
```

### 3.4 Builder Wrapping Graph.Builder

```swift
public struct Program<Leaf, Failure: Error, Mode>.Builder {
    public var graph: Graph<MachineTag, Instruction<Leaf, Failure, Mode>>.Builder
    public var captures: Capture.Store<Mode>
    public let maxDepth: Int?

    public init(maxDepth: Int? = nil) {
        self.graph = .init()
        self.captures = .init()
        self.maxDepth = maxDepth
    }

    @inlinable
    public mutating func allocate(
        _ instruction: Instruction<Leaf, Failure, Mode>
    ) -> Graph.Node<MachineTag> {
        graph.allocate(instruction)
    }

    @inlinable
    public mutating func allocateHole() -> Graph.Node<MachineTag> {
        graph.allocate(.hole)
    }

    @inlinable
    public mutating func fill(
        _ node: Graph.Node<MachineTag>,
        with instruction: Instruction<Leaf, Failure, Mode>
    ) {
        graph.fill(node, with: instruction)
    }

    @inlinable
    public consuming func build(entry: Graph.Node<MachineTag>) -> Program<Leaf, Failure, Mode> {
        Program(
            graph: graph.build(),
            captures: captures.freeze(),
            maxDepth: maxDepth,
            entry: entry
        )
    }
}
```

### 3.5 What Remains Machine-Specific

| Component | Location | Reason |
|-----------|----------|--------|
| `Instruction` enum | Machine.Primitives | Domain vocabulary |
| `Capture.Store/Frozen` | Machine.Primitives | Typed heterogeneous erasure |
| `Value<Mode>` | Machine.Primitives | Mode-indexed boxing |
| `Transform/Combine/Next/Finalize.Erased` | Machine.Primitives | Operation type erasure |
| `Frame` | Machine.Primitives | Execution stack semantics |
| `Mode.Reference/Unchecked` | Machine.Primitives | Sendability stratification |

---

## 4. Benefits of Maximalist Extraction

### 4.1 True Primitive Reuse

Other packages can use Graph.Primitives for:

- **State machines**: `Graph<StateTag, Transition>`
- **Query plans**: `Graph<QueryTag, Operation>`
- **Dependency graphs**: `Graph<PackageTag, Dependency>`
- **ASTs**: `Graph<ASTTag, SyntaxNode>`
- **Control flow graphs**: `Graph<CFGTag, BasicBlock>`

None of these need Machine.Primitives.

### 4.2 Graph Algorithms Apply to Machine.Program

```swift
// Reachable instructions from entry
let reachable = program.graph.reachable(from: [program.entry])

// Dead code elimination
let live = program.graph.subgraph(containing: reachable)

// Cycle detection (for recursion analysis)
let hasCycles = program.graph.hasCycles

// Topological execution order (for non-recursive programs)
if let order = program.graph.topological() {
    // Execute in dependency order
}
```

### 4.3 Cleaner Layering

```
┌─────────────────────────┐
│ Parsing.Primitives      │  Domain: Incremental parsing
│  - Memoization          │
│  - Input protocols      │
└─────────────────────────┘
           ↑
┌─────────────────────────┐
│ Machine.Primitives      │  Domain: Defunctionalized execution
│  - Instruction enum     │
│  - Capture store        │
│  - Execution frames     │
└─────────────────────────┘
           ↑
┌─────────────────────────┐
│ Graph.Primitives        │  Domain: Graph data structures
│  - Node, Edge, Graph    │
│  - Traversal, Analysis  │
│  - Builder, Visitor     │
└─────────────────────────┘
           ↑
┌─────────────────────────┐
│ Identity.Primitives     │  Domain: Tagged types
└─────────────────────────┘
```

Each layer adds domain semantics without duplicating infrastructure.

### 4.4 Testability

- Graph.Primitives tested with simple payloads (integers, strings)
- Machine.Primitives tested for instruction-specific behavior
- No need to test graph algorithms in Machine context

---

## 5. The Rename Question

With maximalist extraction, `Machine.Node` becomes `Machine.Instruction` (or similar). This is more accurate:

| Current | Proposed | Rationale |
|---------|----------|-----------|
| `Machine.Node` | `Machine.Instruction` | It's an instruction in a program, not a generic graph node |
| `Machine.Node.ID` | `Graph.Node<MachineTag>` | Node identity is graph infrastructure |
| `Machine.Program.nodes` | `Machine.Program.graph` | The graph is the structure; instructions are the payload |

This naming clarifies that:
- **Graph.Node**: A position in a graph (identity)
- **Machine.Instruction**: What's at that position (payload)

---

## 6. Implementation Sketch

### 6.1 Graph.Primitives File Structure

```
swift-graph-primitives/
├── Package.swift
└── Sources/
    └── Graph Primitives/
        ├── Graph.swift                    // Namespace
        ├── Graph.Node.swift               // Node<Tag> identifier
        ├── Graph.Edge.swift               // Edge<Tag> (optional)
        ├── Graph.Graph.swift              // Graph<Tag, Payload>
        ├── Graph.Graph.Builder.swift      // Builder pattern
        ├── Graph.Payload.swift            // GraphPayload protocol
        ├── Graph.Traversal.swift          // DepthFirst, BreadthFirst
        ├── Graph.Traversal.Topological.swift
        ├── Graph.Analysis.swift           // Reachability, cycles
        ├── Graph.Analysis.SCC.swift       // Strongly connected components
        ├── Graph.Visitor.swift            // Visitor protocol
        ├── Graph.Transform.swift          // map, filter, subgraph
        └── Graph.Mutable.swift            // MutableGraph (optional)
```

### 6.2 Package.swift

```swift
// swift-graph-primitives/Package.swift

let package = Package(
    name: "swift-graph-primitives",
    products: [
        .library(name: "Graph Primitives", targets: ["Graph Primitives"]),
    ],
    dependencies: [
        // None - truly primitive
    ],
    targets: [
        .target(name: "Graph Primitives"),
        .testTarget(name: "Graph Primitives Tests", dependencies: ["Graph Primitives"]),
    ]
)
```

### 6.3 Machine.Primitives Package.swift Update

```swift
// swift-machine-primitives/Package.swift

let package = Package(
    name: "swift-machine-primitives",
    products: [
        .library(name: "Machine Primitives", targets: ["Machine Primitives"]),
    ],
    dependencies: [
        .package(path: "../swift-graph-primitives"),
        .package(path: "../swift-tagged-primitives"),  // May still need for other tags
    ],
    targets: [
        .target(
            name: "Machine Primitives",
            dependencies: [
                .product(name: "Graph Primitives", package: "swift-graph-primitives"),
            ]
        ),
        .testTarget(name: "Machine Primitives Tests", dependencies: ["Machine Primitives"]),
    ]
)
```

---

## 7. What We Gain

| Capability | Without Extraction | With Maximalist Extraction |
|------------|-------------------|---------------------------|
| Reusable graph container | ❌ Embedded in Machine | ✅ Graph.Primitives |
| Graph traversal algorithms | ❌ None | ✅ DFS, BFS, topological |
| Graph analysis | ❌ None | ✅ Reachability, cycles, SCC |
| Visitor pattern | ❌ Ad-hoc | ✅ Protocol-based |
| Subgraph extraction | ❌ Manual | ✅ Built-in |
| Other graph-based packages | ❌ Must reinvent | ✅ Import Graph.Primitives |
| Machine.Program optimization | ❌ Custom code | ✅ Use graph algorithms |
| Testing isolation | ❌ Coupled | ✅ Separated |

---

## 8. What Machine.Primitives Becomes

With maximalist extraction, Machine.Primitives is:

1. **Instruction vocabulary**: The 12-case enum defining parser operations
2. **Capture infrastructure**: Type-erased heterogeneous storage
3. **Mode stratification**: Sendability control
4. **Execution frames**: Stack-based interpretation support
5. **Program = Graph + Captures**: Thin wrapper combining graph with captured operations

Lines of code estimate:
- **Before**: ~850 lines (graph + machine interleaved)
- **After**: ~550 lines (machine-specific only)

Graph.Primitives: ~400 lines (reusable across ecosystem)

---

## 9. Recommendation

**Adopt the maximalist extraction.**

The primitives ecosystem should maximize reuse. Graph.Primitives as a complete package:

1. **Validates the architecture**: If Machine.Program cleanly separates into graph + domain, the abstraction is correct
2. **Enables future packages**: State machines, query planners, etc. don't need Machine.Primitives
3. **Improves Machine.Primitives**: Access to graph algorithms (reachability, cycles) enables optimization
4. **Follows the principle**: Primitives are atomic building blocks; Machine adds domain semantics

The cost (refactoring, additional dependency) is modest. The benefit (reusable graph infrastructure) compounds across the ecosystem.

---

## 10. Next Steps

1. **Design Graph.Primitives API** with Machine.Program requirements in mind
2. **Implement Graph.Primitives** with comprehensive tests
3. **Refactor Machine.Primitives** to use Graph.Primitives
4. **Rename Machine.Node → Machine.Instruction** to clarify roles
5. **Add graph algorithms** to Machine.Program (dead code elimination, etc.)
6. **Document the layering** for future package authors

---

*Document version 1.0.0. Last updated 2026-01-19.*
