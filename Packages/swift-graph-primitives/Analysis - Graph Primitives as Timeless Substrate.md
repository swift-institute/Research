# Graph Primitives as Timeless Substrate

<!--
---
document_type: architectural_specification
version: 1.0.0
date: 2026-01-19
author: Swift Institute
status: RECOMMENDATION
design_principle: |
  1. Implement each primitives package in isolation (total, coherent, consumer-agnostic)
  2. Only afterwards, maximize reuse by refactoring consumers to depend on primitives
  3. Never shape primitives to fit consumers; shape consumers to fit primitives
supersedes:
  - "Analysis - Graph Extraction and Dependency Structure.md"
  - "Analysis - Maximalist Graph Extraction.md"
---
-->

## Design Principle

> **Primitives are designed in isolation.** Graph.Primitives is not "Machine.Program's structure extracted." It is the canonical, timeless, consumer-agnostic definition of what "graph" means in this ecosystem. Machine.Primitives then adapts itself to reuse Graph.Primitives—not the reverse.

This paper answers two questions:
1. What is the complete, timeless meaning of "graph primitives"?
2. How far can Machine.Primitives be refactored to reuse that substrate?

---

## Part I: Graph.Primitives (Consumer-Agnostic Design)

### 1. What Is a Graph?

At the primitive level, a graph is:

- **Nodes**: Discrete elements with identity
- **Adjacency**: Which nodes reference which other nodes
- **Payloads**: Data attached to nodes

Everything else—traversal algorithms, mutation strategies, serialization—is either derived or belongs to higher layers.

### 2. Foundational Decisions

#### 2.1 Identity Model

**Decision**: Node identity is `Tagged<Tag, Int>` from Identity.Primitives.

```swift
import Tagged_Primitives

extension Graph {
    /// A node's identity within a graph.
    /// The `Tag` parameter prevents mixing nodes from different graphs.
    public typealias Node<Tag> = Tagged<Tag, Int>
}
```

**Rationale**:
- `Tagged` provides zero-cost type safety via phantom types
- `Int` backing enables O(1) array indexing
- Tag parameter prevents accidental cross-graph node confusion
- Already used throughout the ecosystem (154 usages)

#### 2.2 Storage Model

**Decision**: Dense sequential storage. Nodes are stored in a contiguous array; node identity equals array index.

```swift
extension Graph {
    /// An immutable graph with sequentially-allocated nodes.
    public struct Sequential<Tag, Payload> {
        @usableFromInline
        let storage: [Payload]
    }
}
```

**Rationale**:
- Simplest possible representation
- O(1) node access
- Cache-friendly iteration
- Matches the ecosystem's "Builder → Frozen" discipline
- Sufficient for IR graphs, dependency graphs, state machines, planners

**What this excludes**:
- Sparse graphs with stable IDs across mutations (use `MutableGraph` if ever needed)
- Persistent/functional graphs with structural sharing (different package if needed)

This is a deliberate scope decision: Graph.Primitives is "index-addressed frozen graphs."

#### 2.3 Adjacency Representation

**Decision**: Adjacency is encoded in payloads, extracted via protocol. No separate edge storage.

```swift
extension Graph {
    /// A payload that references other nodes.
    public protocol Adjacency {
        associatedtype Tag

        /// The nodes this payload references.
        /// Returns a view, not an allocated array.
        var adjacent: Adjacent { get }

        /// Associated type for the adjacency view.
        associatedtype Adjacent: Swift.Sequence<Node<Tag>>
    }
}
```

**Critical**: `adjacent` returns a `Sequence`, not `[Node<Tag>]`. This enables:
- Zero-allocation for fixed-arity nodes (return tuple or inline storage)
- Lazy iteration for variable-arity nodes
- No heap allocation for the common case

**Example conformances**:

```swift
// Unary node: single child
struct UnaryPayload: Graph.Adjacency {
    typealias Tag = MyTag
    let child: Graph.Node<Tag>

    var adjacent: Swift.CollectionOfOne<Graph.Node<Tag>> {
        CollectionOfOne(child)
    }
}

// Binary node: two children
struct BinaryPayload: Graph.Adjacency {
    typealias Tag = MyTag
    let left: Graph.Node<Tag>
    let right: Graph.Node<Tag>

    var adjacent: some Swift.Sequence<Graph.Node<Tag>> {
        [left, right]  // Stack-allocated array literal
    }
}

// N-ary node: variable children
struct NaryPayload: Graph.Adjacency {
    typealias Tag = MyTag
    let children: [Graph.Node<Tag>]

    var adjacent: [Graph.Node<Tag>] { children }
}
```

#### 2.4 Mutability Discipline

**Decision**: Mutable builder, consuming freeze, immutable graph.

```swift
extension Graph.Sequential {
    /// Mutable builder for constructing graphs.
    public struct Builder {
        @usableFromInline
        var storage: [Payload]

        public init() { self.storage = [] }

        /// Allocate a node, returning its identity.
        @inlinable
        public mutating func allocate(_ payload: Payload) -> Graph.Node<Tag> {
            let id = Graph.Node<Tag>(storage.count)
            storage.append(payload)
            return id
        }

        /// Freeze the builder into an immutable graph.
        @inlinable
        public consuming func build() -> Graph.Sequential<Tag, Payload> {
            Graph.Sequential(storage: storage)
        }
    }
}
```

**Forward references** (holes):

```swift
extension Graph.Sequential.Builder {
    /// Allocate a placeholder node to be filled later.
    @inlinable
    public mutating func allocateHole() -> Graph.Node<Tag>
        where Payload: Graph.Defaultable
    {
        allocate(.graphDefault)
    }

    /// Fill a previously allocated hole.
    @inlinable
    public mutating func fill(_ node: Graph.Node<Tag>, with payload: Payload) {
        storage[node.rawValue] = payload
    }
}

extension Graph {
    /// A payload type that can represent an unfilled hole.
    public protocol Defaultable {
        static var graphDefault: Self { get }
    }
}
```

### 3. Graph Access

```swift
extension Graph.Sequential {
    /// Number of nodes in the graph.
    @inlinable
    public var count: Int { storage.count }

    /// Access a node's payload by identity.
    @inlinable
    public subscript(node: Graph.Node<Tag>) -> Payload {
        storage[node.rawValue]
    }

    /// All node identities in allocation order.
    @inlinable
    public var nodes: some Swift.Sequence<Graph.Node<Tag>> {
        storage.indices.lazy.map { Graph.Node<Tag>($0) }
    }
}

extension Graph.Sequential: Sendable where Payload: Sendable {}
extension Graph.Sequential.Builder: ~Copyable {}
```

### 4. Traversal

Traversal belongs in Graph.Primitives because it defines the meaningful utility of a graph substrate.

#### 4.1 Depth-First

```swift
extension Graph {
    /// Depth-first traversal from given roots.
    public struct DepthFirst<Tag, Payload: Adjacency>: Swift.Sequence
        where Payload.Tag == Tag
    {
        public let graph: Sequential<Tag, Payload>
        public let roots: [Node<Tag>]

        // Iterator yields (node, payload) pairs in DFS order
        public func makeIterator() -> Iterator { ... }
    }
}

extension Graph.Sequential where Payload: Graph.Adjacency, Payload.Tag == Tag {
    @inlinable
    public func depthFirst(from roots: [Graph.Node<Tag>]) -> Graph.DepthFirst<Tag, Payload> {
        Graph.DepthFirst(graph: self, roots: roots)
    }

    @inlinable
    public func depthFirst(from root: Graph.Node<Tag>) -> Graph.DepthFirst<Tag, Payload> {
        depthFirst(from: [root])
    }
}
```

#### 4.2 Breadth-First

```swift
extension Graph {
    /// Breadth-first traversal from given roots.
    public struct BreadthFirst<Tag, Payload: Adjacency>: Swift.Sequence
        where Payload.Tag == Tag
    {
        public let graph: Sequential<Tag, Payload>
        public let roots: [Node<Tag>]

        public func makeIterator() -> Iterator { ... }
    }
}
```

#### 4.3 Topological Order

```swift
extension Graph {
    /// Topological ordering (for DAGs only).
    /// Returns nil if the graph contains cycles.
    public struct Topological<Tag, Payload: Adjacency>: Swift.Sequence
        where Payload.Tag == Tag
    {
        // ...
    }
}

extension Graph.Sequential where Payload: Graph.Adjacency, Payload.Tag == Tag {
    /// Topological sort, or nil if cycles exist.
    @inlinable
    public func topological() -> Graph.Topological<Tag, Payload>? {
        let order = Graph.Topological(graph: self)
        return order.hasCycles ? nil : order
    }
}
```

### 5. Analysis

Minimal but complete analysis surface:

```swift
extension Graph.Sequential where Payload: Graph.Adjacency, Payload.Tag == Tag {
    /// All nodes reachable from the given roots.
    @inlinable
    public func reachable(from roots: [Graph.Node<Tag>]) -> Set<Graph.Node<Tag>> {
        var visited = Set<Graph.Node<Tag>>()
        for (node, _) in depthFirst(from: roots) {
            visited.insert(node)
        }
        return visited
    }

    /// Whether the graph contains any cycles.
    @inlinable
    public var hasCycles: Bool {
        // Tarjan's algorithm or DFS with coloring
    }

    /// Strongly connected components (Tarjan's algorithm).
    @inlinable
    public func stronglyConnectedComponents() -> [[Graph.Node<Tag>]] {
        // ...
    }
}
```

### 6. Transformation

```swift
extension Graph.Sequential {
    /// Map payloads without changing structure.
    @inlinable
    public func mapPayloads<NewPayload>(
        _ transform: (Payload) -> NewPayload
    ) -> Graph.Sequential<Tag, NewPayload> {
        Graph.Sequential<Tag, NewPayload>(storage: storage.map(transform))
    }
}

extension Graph.Sequential where Payload: Graph.Adjacency, Payload.Tag == Tag {
    /// Extract subgraph containing only specified nodes.
    /// Node identities are compacted (remapped to 0..<n).
    public func subgraph(
        containing nodes: Set<Graph.Node<Tag>>
    ) -> (graph: Graph.Sequential<Tag, Payload>, mapping: [Graph.Node<Tag>: Graph.Node<Tag>])
        where Payload: Graph.Remappable
    {
        // ...
    }
}

extension Graph {
    /// A payload whose node references can be remapped.
    public protocol Remappable: Adjacency {
        func mapNodes(_ transform: (Node<Tag>) -> Node<Tag>) -> Self
    }
}
```

### 7. What Graph.Primitives Does NOT Include

Explicitly out of scope (would be separate packages or higher layers):

- **Mutable graphs**: Insert/delete nodes post-construction
- **Sparse graphs**: Stable IDs with tombstones
- **Persistent graphs**: Structural sharing, undo/redo
- **Weighted edges**: Separate edge storage with weights
- **Graph DSLs**: Pattern matching, rewriting rules
- **Serialization**: Codable conformance (add in extension if needed)
- **Visualization**: DOT export, layout algorithms

Graph.Primitives is the minimal, timeless substrate. Everything else builds on it.

### 8. Complete File Structure

```
swift-graph-primitives/
├── Package.swift
└── Sources/
    └── Graph Primitives/
        ├── Graph.swift                      // Namespace
        ├── Graph.Node.swift                 // typealias Node<Tag> = Tagged<Tag, Int>
        ├── Graph.Sequential.swift           // Sequential<Tag, Payload>
        ├── Graph.Sequential.Builder.swift   // Builder pattern
        ├── Graph.Adjacency.swift            // Adjacency protocol
        ├── Graph.Defaultable.swift          // Defaultable protocol (holes)
        ├── Graph.Remappable.swift           // Remappable protocol
        ├── Graph.Traversal.DepthFirst.swift
        ├── Graph.Traversal.BreadthFirst.swift
        ├── Graph.Traversal.Topological.swift
        └── Graph.Analysis.swift             // reachable, hasCycles, SCC
```

### 9. Package.swift

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-graph-primitives",
    platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26), .watchOS(.v26), .visionOS(.v26)],
    products: [
        .library(name: "Graph Primitives", targets: ["Graph Primitives"]),
    ],
    dependencies: [
        .package(path: "../swift-tagged-primitives"),
    ],
    targets: [
        .target(
            name: "Graph Primitives",
            dependencies: [
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictMemorySafety")]
        ),
        .testTarget(
            name: "Graph Primitives Tests",
            dependencies: ["Graph Primitives"]
        ),
    ]
)
```

---

## Part II: Machine.Primitives Adaptation

With Graph.Primitives complete and frozen, Machine.Primitives adapts to maximize reuse.

### 10. What Machine.Primitives Deletes

| Current | Action | Rationale |
|---------|--------|-----------|
| `Machine.Node.ID` (Tagged<Tag, Int>) | Delete | Use `Graph.Node<Machine.Tag>` |
| `Machine.Program.nodes: [Node]` | Delete | Use `Graph.Sequential<Machine.Tag, Instruction>` |
| `Machine.Program.subscript(id:)` | Delete | Use `graph[node]` |
| `Machine.Program.Builder` storage logic | Delete | Use `Graph.Sequential.Builder` |
| Any bespoke traversal | Delete | Use `graph.depthFirst(from:)` etc. |

### 11. What Machine.Primitives Keeps

| Component | Reason |
|-----------|--------|
| Instruction vocabulary (12 cases) | Domain-specific semantics |
| Capture.Store / Capture.Frozen | Type-erased heterogeneous storage |
| Value<Mode> | Mode-indexed boxing |
| Transform / Combine / Next / Finalize.Erased | Operation references |
| Frame types | Execution stack semantics |
| Mode.Reference / Mode.Unchecked | Sendability stratification |

### 12. The Refactored Types

#### 12.1 Machine.Tag

```swift
extension Machine {
    /// Phantom tag for machine program graphs.
    public enum Tag {}
}
```

#### 12.2 Machine.Instruction (renamed from Machine.Node)

```swift
import Graph_Primitives

extension Machine {
    /// An instruction in a defunctionalized machine program.
    public enum Instruction<Leaf, Failure: Error, Mode> {
        // Primitives
        case leaf(Leaf)
        case pure(Value<Mode>)

        // Unary
        case map(child: Graph.Node<Tag>, transform: Transform.Erased<Mode>)
        case tryMap(child: Graph.Node<Tag>, transform: Transform.Throwing<Mode, Failure>)
        case flatMap(child: Graph.Node<Tag>, next: Next.Erased<Mode, Graph.Node<Tag>>)
        case many(child: Graph.Node<Tag>, finalize: Finalize.Array<Mode>)
        case optional(child: Graph.Node<Tag>, wrapSome: Transform.Erased<Mode>, noneValue: Value<Mode>)

        // Binary
        case sequence(a: Graph.Node<Tag>, b: Graph.Node<Tag>, combine: Combine.Erased<Mode>)
        case fold(child: Graph.Node<Tag>, initial: Value<Mode>, combine: Combine.Erased<Mode>)

        // Control flow
        case oneOf([Graph.Node<Tag>])
        case ref(Graph.Node<Tag>)

        // Construction
        case hole
    }
}
```

#### 12.3 Graph.Adjacency Conformance

```swift
extension Machine.Instruction: Graph.Adjacency {
    public typealias Tag = Machine.Tag

    public var adjacent: some Swift.Sequence<Graph.Node<Machine.Tag>> {
        switch self {
        case .leaf, .pure, .hole:
            return EmptyCollection()
        case .map(let child, _), .tryMap(let child, _), .flatMap(let child, _),
             .many(let child, _), .optional(let child, _, _), .ref(let child):
            return CollectionOfOne(child)
        case .sequence(let a, let b, _):
            return [a, b]
        case .fold(let child, _, _):
            return CollectionOfOne(child)
        case .oneOf(let alts):
            return alts
        }
    }
}

extension Machine.Instruction: Graph.Defaultable {
    public static var graphDefault: Self { .hole }
}

extension Machine.Instruction: Graph.Remappable {
    public func mapNodes(_ transform: (Graph.Node<Machine.Tag>) -> Graph.Node<Machine.Tag>) -> Self {
        switch self {
        case .leaf, .pure, .hole:
            return self
        case .map(let child, let t):
            return .map(child: transform(child), transform: t)
        case .tryMap(let child, let t):
            return .tryMap(child: transform(child), transform: t)
        // ... all cases
        }
    }
}
```

#### 12.4 Machine.Program

```swift
extension Machine {
    /// A complete machine program: instruction graph + captures.
    public struct Program<Leaf, Failure: Error, Mode> {
        /// The instruction graph.
        public let graph: Graph.Sequential<Tag, Instruction<Leaf, Failure, Mode>>

        /// Captured operations referenced by instructions.
        public let captures: Capture.Frozen<Mode>

        /// Maximum recursion depth (optional).
        public let maxDepth: Int?

        /// Program entry point.
        public let entry: Graph.Node<Tag>

        /// Convenience subscript.
        @inlinable
        public subscript(node: Graph.Node<Tag>) -> Instruction<Leaf, Failure, Mode> {
            graph[node]
        }
    }
}

extension Machine.Program: Sendable
    where Leaf: Sendable, Failure: Sendable, Mode: Sendable {}
```

#### 12.5 Machine.Program.Builder

```swift
extension Machine.Program {
    /// Mutable builder for constructing programs.
    public struct Builder {
        /// Graph builder.
        public var graph: Graph.Sequential<Machine.Tag, Instruction<Leaf, Failure, Mode>>.Builder

        /// Capture store.
        public var captures: Capture.Store<Mode>

        /// Maximum depth.
        public let maxDepth: Int?

        public init(maxDepth: Int? = nil) {
            self.graph = .init()
            self.captures = .init()
            self.maxDepth = maxDepth
        }

        @inlinable
        public mutating func allocate(
            _ instruction: Instruction<Leaf, Failure, Mode>
        ) -> Graph.Node<Machine.Tag> {
            graph.allocate(instruction)
        }

        @inlinable
        public mutating func allocateHole() -> Graph.Node<Machine.Tag> {
            graph.allocateHole()
        }

        @inlinable
        public mutating func fill(
            _ node: Graph.Node<Machine.Tag>,
            with instruction: Instruction<Leaf, Failure, Mode>
        ) {
            graph.fill(node, with: instruction)
        }

        @inlinable
        public consuming func build(entry: Graph.Node<Machine.Tag>) -> Program {
            Program(
                graph: graph.build(),
                captures: captures.freeze(),
                maxDepth: maxDepth,
                entry: entry
            )
        }
    }
}
```

### 13. What Machine.Primitives Gains

With the refactor, Machine.Primitives gains access to Graph algorithms:

```swift
extension Machine.Program {
    /// All instructions reachable from entry.
    public var reachableInstructions: Set<Graph.Node<Machine.Tag>> {
        graph.reachable(from: [entry])
    }

    /// Whether the program contains recursive references.
    public var hasRecursion: Bool {
        graph.hasCycles
    }

    /// Dead code: allocated but unreachable instructions.
    public var deadCode: Set<Graph.Node<Machine.Tag>> {
        let all = Set(graph.nodes)
        let live = reachableInstructions
        return all.subtracting(live)
    }

    /// Execution order for non-recursive programs.
    public var executionOrder: [Graph.Node<Machine.Tag>]? {
        graph.topological().map(Array.init)
    }
}
```

### 14. Frame and Execution Adaptation

Frames reference `Graph.Node<Machine.Tag>` instead of `Machine.Node.ID`:

```swift
extension Machine {
    public enum Frame<Checkpoint, Failure: Error, Mode, Extra> {
        case map(transform: Transform.Erased<Mode>)
        case tryMap(transform: Transform.Throwing<Mode, Failure>)
        case flatMap(next: Next.Erased<Mode, Graph.Node<Tag>>)
        case sequence(Sequence)
        case oneOf(alternatives: [Graph.Node<Tag>], index: Int, savedCheckpoint: Checkpoint)
        case many(child: Graph.Node<Tag>, savedCheckpoint: Checkpoint, ...)
        case fold(child: Graph.Node<Tag>, savedCheckpoint: Checkpoint, ...)
        case optional(savedCheckpoint: Checkpoint, ...)
        case recursiveExit
        case extra(Extra)
    }
}
```

---

## Part III: Validation

### 15. Layering Verification

```
┌─────────────────────────────────┐
│ Parsing.Primitives              │  Uses: Machine.Primitives
│  - Memoization, Input protocols │
└─────────────────────────────────┘
              ↑
┌─────────────────────────────────┐
│ Machine.Primitives              │  Uses: Graph.Primitives, Identity.Primitives
│  - Instruction, Capture, Frame  │
└─────────────────────────────────┘
              ↑
┌─────────────────────────────────┐
│ Graph.Primitives                │  Uses: Identity.Primitives
│  - Sequential, Traversal, Analysis │
└─────────────────────────────────┘
              ↑
┌─────────────────────────────────┐
│ Identity.Primitives             │  Uses: Nothing
│  - Tagged<Tag, RawValue>        │
└─────────────────────────────────┘
```

Each layer depends only downward. No upward or lateral dependencies.

### 16. Consumer-Agnostic Test

Graph.Primitives can be tested without any knowledge of Machine:

```swift
// Graph.Primitives tests

enum TestTag {}

struct SimplePayload: Graph.Adjacency, Graph.Defaultable {
    typealias Tag = TestTag
    let children: [Graph.Node<TestTag>]

    var adjacent: [Graph.Node<TestTag>] { children }
    static var graphDefault: Self { SimplePayload(children: []) }
}

func testReachability() {
    var builder = Graph.Sequential<TestTag, SimplePayload>.Builder()
    let a = builder.allocate(SimplePayload(children: []))
    let b = builder.allocate(SimplePayload(children: [a]))
    let c = builder.allocate(SimplePayload(children: [b]))
    let orphan = builder.allocate(SimplePayload(children: []))

    let graph = builder.build()
    let reachable = graph.reachable(from: [c])

    #expect(reachable.contains(a))
    #expect(reachable.contains(b))
    #expect(reachable.contains(c))
    #expect(!reachable.contains(orphan))
}
```

No imports from Machine.Primitives. Graph.Primitives is self-contained.

### 17. Reuse Verification

Machine.Primitives reuses:
- `Graph.Node<Tag>` for all node identity
- `Graph.Sequential<Tag, Payload>` for storage
- `Graph.Sequential.Builder` for construction
- `graph.depthFirst(from:)` for traversal
- `graph.reachable(from:)` for analysis
- `graph.hasCycles` for recursion detection

Machine.Primitives adds only:
- `Instruction` enum (domain vocabulary)
- `Capture` infrastructure (type erasure)
- `Frame` types (execution semantics)
- `Mode` stratification (Sendability)

---

## Summary

**Graph.Primitives** is designed as a complete, timeless, consumer-agnostic substrate:
- Dense sequential storage with `Tagged` identity
- Non-allocating adjacency via protocol
- Builder → Frozen mutability discipline
- DFS/BFS/topological traversal
- Reachability, cycle detection, SCC analysis

**Machine.Primitives** adapts to maximize reuse:
- Deletes bespoke node ID, storage, builder logic
- Renames `Node` → `Instruction` (clarifies role)
- Conforms `Instruction` to `Graph.Adjacency`
- Uses `Graph.Sequential` for storage
- Gains access to graph algorithms

**The principle holds**: Graph.Primitives exists independently. Machine.Primitives shapes itself to fit the primitive, not vice versa.

---

*Document version 1.0.0. Last updated 2026-01-19.*
