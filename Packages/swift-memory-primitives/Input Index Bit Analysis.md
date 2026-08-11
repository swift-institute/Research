Foundational Primitives for Type-Safe Data Structure Design in Swift
<!--
---
version: 1.0.0
last_updated: 2026-01-20
status: RECOMMENDATION
---
-->

Abstract                                                                                                            
                                                                                                                    
This paper examines three foundational primitive packages in the Swift Institute                                    
architecture—swift-index-primitives, swift-input-primitives, and swift-bit-primitives—and their systematic          
application across fourteen data structure implementations. We argue that principled reuse of these primitives,     
rather than dependency minimization, produces semantically correct, type-safe APIs that prevent classes of          
programming errors at compile time. We provide concrete integration recommendations for each data structure package 
following the maxim: reuse wherever possible and semantically correct.                                              
                                                                                                                    
---                                                                                                                 
1. Introduction                                                                                                     
                                                                                                                    
The Swift Institute primitive layer provides atomic building blocks for higher-layer software. Among these, three   
packages form a conceptual triad for collection-oriented programming:                                               
┌────────────────┬─────────────┬─────────────────────────────────────────────┐                                      
│    Package     │   Domain    │              Core Abstraction               │                                      
├────────────────┼─────────────┼─────────────────────────────────────────────┤                                      
│ Index<Element> │ Position    │ Type-tagged location within a collection    │                                      
├────────────────┼─────────────┼─────────────────────────────────────────────┤                                      
│ Input.Protocol │ Consumption │ Checkpointable cursor over sequences        │                                      
├────────────────┼─────────────┼─────────────────────────────────────────────┤                                      
│ Bit            │ Binary      │ Single binary digit with ordering semantics │                                      
└────────────────┴─────────────┴─────────────────────────────────────────────┘                                      
Current data structure implementations use raw Int for indexing, forgoing the type safety that Index<Element>       
provides. This paper demonstrates how systematic adoption of these primitives eliminates cross-collection index     
confusion, enables uniform consumption patterns, and provides canonical bit-level semantics.                        
                                                                                                                    
---                                                                                                                 
2. Foundational Primitive Analysis                                                                                  
                                                                                                                    
2.1 Index Primitives: Type-Tagged Positions                                                                         
                                                                                                                    
The Index<Element> type implements a phantom-type pattern where the Element parameter serves as a compile-time tag: 
                                                                                                                    
public struct Index<Element>: Hashable, Comparable, Sendable {                                                      
    public let position: Int                                                                                        
                                                                                                                    
    @inlinable                                                                                                      
    public init(_ position: Int) {                                                                                  
        precondition(position >= 0, "Index position must be non-negative")                                          
        self.position = position                                                                                    
    }                                                                                                               
}                                                                                                                   
                                                                                                                    
Key Property: Two indices Index<A> and Index<B> are incompatible types even when their position values are equal.   
This prevents a class of errors where indices are accidentally used across different collections:                   
                                                                                                                    
let stackIndex: Index<Stack<Int>> = 5                                                                               
let queueIndex: Index<Queue<Int>> = 5                                                                               
// stackIndex == queueIndex  // Compile error: type mismatch                                                        
                                                                                                                    
The Index.Safe<Base> wrapper provides optional-returning subscripts via the .safe accessor:                         
                                                                                                                    
extension Collection {                                                                                              
    public var safe: __IndexSafe<Self> { __IndexSafe(self) }                                                        
}                                                                                                                   
                                                                                                                    
// Usage: array.safe[10] returns nil instead of trapping                                                            
                                                                                                                    
2.2 Input Primitives: Consumable Cursors                                                                            
                                                                                                                    
The Input package defines a three-tier protocol hierarchy for position-aware consumption:                           
                                                                                                                    
Input.Streaming           ← Forward-only: isEmpty, first, removeFirst()                                             
        ↑                                                                                                           
Input.Protocol            ← Backtracking: checkpoint, restore(to:), count                                           
        ↑                                                                                                           
Input.Access.Random       ← Random access: subscript(offset:), starts(with:)                                        
                                                                                                                    
Checkpoint Semantics: The checkpoint property returns a Sendable value that can restore the cursor to a prior       
position:                                                                                                           
                                                                                                                    
var input = Input.Buffer([1, 2, 3, 4, 5])                                                                           
let cp = input.checkpoint                                                                                           
_ = input.removeFirst()  // consume 1                                                                               
input.restore(to: cp)    // back to [1, 2, 3, 4, 5]                                                                 
                                                                                                                    
This pattern enables backtracking parsers, speculative consumption, and transaction-like semantics over sequences.  
                                                                                                                    
2.3 Bit Primitives: Binary Digit Semantics                                                                          
                                                                                                                    
The Bit type provides a semantically meaningful wrapper over UInt8 for single binary digits:                        
                                                                                                                    
public typealias Bit = UInt8                                                                                        
                                                                                                                    
extension Bit {                                                                                                     
    public static let zero: Self = 0                                                                                
    public static let one: Self = 1                                                                                 
                                                                                                                    
    public static func xor(_ lhs: Bit, _ rhs: Bit) -> Bit  // Z₂ field addition                                     
    public static func and(_ lhs: Bit, _ rhs: Bit) -> Bit  // Z₂ field multiplication                               
}                                                                                                                   
                                                                                                                    
Bit.Order distinguishes MSB-first vs LSB-first processing:                                                          
                                                                                                                    
public enum Order: Sendable {                                                                                       
    case msb  // Most significant bit first (bit 7 → bit 0)                                                         
    case lsb  // Least significant bit first (bit 0 → bit 7)                                                        
}                                                                                                                   
                                                                                                                    
Bit.Index is a typealias for Index<Bit>, providing type-safe bit positions.                                         
                                                                                                                    
---                                                                                                                 
3. Current State Analysis                                                                                           
                                                                                                                    
An examination of fourteen data structure packages reveals systematic non-adoption of these primitives:             
┌────────────────┬───────────────────────┬───────────────────────┐                                                  
│   Primitive    │   Packages Using It   │ Packages Not Using It │                                                  
├────────────────┼───────────────────────┼───────────────────────┤                                                  
│ Index<Element> │ 0                     │ 14                    │                                                  
├────────────────┼───────────────────────┼───────────────────────┤                                                  
│ Input.Protocol │ 0                     │ 14                    │                                                  
├────────────────┼───────────────────────┼───────────────────────┤                                                  
│ Bit            │ 3 (array, set, graph) │ 11                    │                                                  
└────────────────┴───────────────────────┴───────────────────────┘                                                  
All packages use raw Int for indexing. This creates several problems:                                               
                                                                                                                    
1. Cross-collection index confusion: Nothing prevents using a Stack index with a Queue                              
2. No safe access pattern: Out-of-bounds access causes runtime crashes                                              
3. Missing consumption abstraction: No uniform way to iterate with backtracking                                     
4. Inconsistent bit semantics: Bit order assumptions are implicit                                                   
                                                                                                                    
---                                                                                                                 
4. Integration Recommendations                                                                                      
                                                                                                                    
We now provide concrete recommendations for each data structure package, following the principle that correct       
semantic dependencies are preferable to minimal dependencies.                                                       
                                                                                                                    
4.1 Array Primitives                                                                                                
                                                                                                                    
Current State: Uses Bit for Bit.Array variants; uses raw Int subscripts.                                            
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Add Array.Index<Element> as Index<Array.Element> for type-safe subscripting                                
- Input: Add Input.Protocol conformance to enable consumption patterns                                              
                                                                                                                    
extension Array: Input.Protocol {                                                                                   
    public typealias Checkpoint = Int                                                                               
    public var checkpoint: Int { startIndex }                                                                       
    public mutating func restore(to checkpoint: Int) { /* adjust startIndex */ }                                    
}                                                                                                                   
                                                                                                                    
Rationale: Arrays are frequently consumed element-by-element in parsing; checkpoint support enables speculative     
matching.                                                                                                           
                                                                                                                    
4.2 Buffer Primitives                                                                                               
                                                                                                                    
Current State: Uses raw Int for slot access; depends on Handle/Reference primitives.                                
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Add Buffer.Index as Index<Buffer.Element>                                                                  
- Bit: Add Bit.Order for byte-order-aware buffer operations                                                         
- Input: Conform ring buffer variant to Input.Protocol                                                              
                                                                                                                    
extension Buffer.Ring: Input.Protocol {                                                                             
    public typealias Checkpoint = Int  // Read position                                                             
    public var checkpoint: Int { readPosition }                                                                     
}                                                                                                                   
                                                                                                                    
Rationale: Ring buffers naturally support cursor semantics; bit order is essential for binary protocol parsing.     
                                                                                                                    
4.3 Deque Primitives                                                                                                
                                                                                                                    
Current State: No primitive dependencies; uses raw Int head/tail indices.                                           
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Add Deque.Index<Element> for type-safe double-ended access                                                 
- Input: Conform to Input.Protocol for front-to-back consumption                                                    
                                                                                                                    
extension Deque {                                                                                                   
    public typealias Index = Index_Primitives.Index<Element>                                                        
                                                                                                                    
    public subscript(index: Index) -> Element {                                                                     
        get { storage[(head + index.position) % capacity] }                                                         
    }                                                                                                               
}                                                                                                                   
                                                                                                                    
Rationale: Deques are commonly used as sliding windows; checkpoint support enables lookahead without mutation.      
                                                                                                                    
4.4 Dictionary Primitives                                                                                           
                                                                                                                    
Current State: Uses Set.Ordered for key storage; raw Int indices.                                                   
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Add Dictionary.Index<Key, Value> for type-safe key-value pair access                                       
- Bit: Add Bit.Set integration for key presence bitmaps in future optimizations                                     
                                                                                                                    
extension Dictionary {                                                                                              
    public struct Index<Key, Value>: Hashable {                                                                     
        let keyIndex: Set.Ordered<Key>.Index                                                                        
    }                                                                                                               
}                                                                                                                   
                                                                                                                    
Rationale: Dictionary iteration order is meaningful in ordered variants; typed indices prevent mixing with other    
collection types.                                                                                                   
                                                                                                                    
4.5 Graph Primitives                                                                                                
                                                                                                                    
Current State: Uses Graph.Node<Tag> wrapping Int; depends on Bit for algorithms.                                    
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Refactor Graph.Node<Tag> to use Index<Graph.Node<Tag>> internally                                          
- Input: Add traversal cursors conforming to Input.Protocol                                                         
                                                                                                                    
extension Graph.Traversal: Input.Protocol {                                                                         
    public typealias Checkpoint = (nodeStack: Stack<Node>, visited: Bit.Set)                                        
    // Enables checkpointed graph exploration                                                                       
}                                                                                                                   
                                                                                                                    
Rationale: Graph traversal is inherently a consumption pattern; checkpointing enables backtracking search           
algorithms.                                                                                                         
                                                                                                                    
4.6 Handle Primitives                                                                                               
                                                                                                                    
Current State: Uses SlotAddress with Int index + UInt32 generation.                                                 
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Wrap the index component as Index<Handle.Slot<Phantom>>                                                    
- Bit: Use Bit.Set for free-slot tracking                                                                           
                                                                                                                    
public struct SlotAddress<Phantom> {                                                                                
    public let index: Index<Handle.Slot<Phantom>>                                                                   
    public let generation: UInt32                                                                                   
}                                                                                                                   
                                                                                                                    
Rationale: Handle systems benefit from type-safe indices to prevent cross-pool confusion.                           
                                                                                                                    
4.7 Heap Primitives                                                                                                 
                                                                                                                    
Current State: No dependencies; uses implicit Int indices in binary heap array.                                     
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Add Heap.Index<Element> for type-safe heap position references                                             
- Bit: Add comparison result caching via Bit flags                                                                  
                                                                                                                    
extension Heap {                                                                                                    
    public typealias Index = Index_Primitives.Index<Element>                                                        
                                                                                                                    
    public func peekIndex() -> Index? {                                                                             
        isEmpty ? nil : Index(0)                                                                                    
    }                                                                                                               
}                                                                                                                   
                                                                                                                    
Rationale: Heap indices have specific semantics (parent at i/2, children at 2i and 2i+1); typing prevents misuse.   
                                                                                                                    
4.8 List Primitives                                                                                                 
                                                                                                                    
Current State: Uses arena-based storage with raw Int node indices.                                                  
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Add List.Index<Element> for type-safe node references                                                      
- Input: Conform linked lists to Input.Protocol                                                                     
                                                                                                                    
extension List.Linked: Input.Protocol {                                                                             
    public typealias Checkpoint = Index                                                                             
    public var checkpoint: Index { currentNode }                                                                    
                                                                                                                    
    public mutating func restore(to checkpoint: Index) {                                                            
        currentNode = checkpoint                                                                                    
    }                                                                                                               
}                                                                                                                   
                                                                                                                    
Rationale: Linked list traversal is a canonical cursor pattern; typed indices prevent using a singly-linked list    
index with a doubly-linked list.                                                                                    
                                                                                                                    
4.9 Machine Primitives                                                                                              
                                                                                                                    
Current State: Uses raw Int slot indices for captures; depends on Handle.                                           
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Add Machine.CaptureIndex as Index<Machine.Capture>                                                         
- Input: Internal instruction pointer as Input.Protocol cursor                                                      
- Bit: Use Bit.Set for capture group presence tracking                                                              
                                                                                                                    
extension Machine.Program {                                                                                         
    public typealias InstructionIndex = Index<Machine.Instruction>                                                  
}                                                                                                                   
                                                                                                                    
Rationale: Machine execution is fundamentally a cursor over instructions; typed indices improve debuggability.      
                                                                                                                    
4.10 Queue Primitives                                                                                               
                                                                                                                    
Current State: Uses List for backing storage; raw Int for head/tail.                                                
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Add Queue.Index<Element> (position from head)                                                              
- Input: Natural fit for Input.Streaming (forward-only consumption)                                                 
                                                                                                                    
extension Queue: Input.Streaming {                                                                                  
    public var isEmpty: Bool { count == 0 }                                                                         
    public var first: Element? { peek() }                                                                           
    public mutating func removeFirst() -> Element { dequeue() }                                                     
}                                                                                                                   
                                                                                                                    
Rationale: Queues are the prototypical forward-only consumption pattern; Input.Streaming conformance enables uniform
 treatment.                                                                                                         
                                                                                                                    
4.11 Set Primitives                                                                                                 
                                                                                                                    
Current State: Uses Bit for Bit.Set variants; raw Int subscripts.                                                   
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Add Set.Index<Element> for type-safe ordered set access                                                    
- Input: Conform Set.Ordered to Input.Protocol for iteration with checkpointing                                     
                                                                                                                    
extension Set.Ordered: Input.Protocol {                                                                             
    public typealias Checkpoint = Index                                                                             
    public var checkpoint: Index { currentIndex }                                                                   
}                                                                                                                   
                                                                                                                    
Rationale: Ordered sets have meaningful iteration order; checkpoint support enables set-difference streaming.       
                                                                                                                    
4.12 Stack Primitives                                                                                               
                                                                                                                    
Current State: No dependencies; uses raw Int for positions.                                                         
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Add Stack.Index<Element> (position from bottom)                                                            
- Input: Non-conformant (LIFO doesn't match streaming semantics)                                                    
                                                                                                                    
extension Stack {                                                                                                   
    public typealias Index = Index_Primitives.Index<Element>                                                        
                                                                                                                    
    public subscript(index: Index) -> Element {                                                                     
        storage[index.position]                                                                                     
    }                                                                                                               
}                                                                                                                   
                                                                                                                    
Rationale: Stack positions are meaningful (depth from bottom); typed indices prevent stack/queue confusion. Note:   
Stacks should NOT conform to Input.Protocol as LIFO access contradicts the streaming model.                         
                                                                                                                    
4.13 Tree Primitives                                                                                                
                                                                                                                    
Current State: Uses Tree.Position for navigation; depends on Stack/Queue/Array.                                     
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Refactor Tree.Position to use Index<Tree.Node<Element>>                                                    
- Input: Add traversal orders as Input.Protocol cursors                                                             
- Bit: Use Bit.Set for visited-node tracking                                                                        
                                                                                                                    
extension Tree.Binary.InorderTraversal: Input.Protocol {                                                            
    public typealias Checkpoint = (nodeStack: Stack<Index>, current: Index?)                                        
}                                                                                                                   
                                                                                                                    
Rationale: Tree traversals are cursor patterns; checkpointing enables subtree skipping.                             
                                                                                                                    
4.14 Vector Primitives                                                                                              
                                                                                                                    
Current State: No dependencies; fixed-size with raw Int subscripts.                                                 
                                                                                                                    
Recommended Additions:                                                                                              
- Index: Add Vector.Index<Element, N> with compile-time bounds checking                                             
- Bit: Add Bit.Vector<N> specialization for bit vectors                                                             
                                                                                                                    
extension Vector {                                                                                                  
    public typealias Index = Index_Primitives.Index<Element>                                                        
                                                                                                                    
    public subscript(index: Index) -> Element                                                                       
    where index.position >= 0, index.position < N {  // Compile-time constraint                                     
        storage[index.position]                                                                                     
    }                                                                                                               
}                                                                                                                   
                                                                                                                    
Rationale: Fixed-size vectors have statically-known bounds; typed indices enable compile-time safety.               
                                                                                                                    
---                                                                                                                 
5. Dependency Graph After Integration                                                                               
                                                                                                                    
The recommended integration produces this dependency structure:                                                     
                                                                                                                    
Layer 0 (No Dependencies):                                                                                          
  ├── swift-index-primitives                                                                                        
  ├── swift-input-primitives                                                                                        
  ├── swift-algebra-primitives                                                                                      
  └── swift-tagged-primitives                                                                                     
                                                                                                                    
Layer 1 (Index/Algebra/Identity):                                                                                   
  └── swift-bit-primitives                                                                                          
      └── depends on: Index, Algebra, Identity                                                                      
                                                                                                                    
Layer 2 (Bit + Index + Input):                                                                                      
  ├── swift-array-primitives    → Index, Input, Bit                                                                 
  ├── swift-deque-primitives    → Index, Input                                                                      
  ├── swift-list-primitives     → Index, Input                                                                      
  ├── swift-queue-primitives    → Index, Input (Streaming only)                                                     
  ├── swift-set-primitives      → Index, Input, Bit                                                                 
  ├── swift-stack-primitives    → Index (no Input - LIFO incompatible)                                              
  ├── swift-vector-primitives   → Index, Bit                                                                        
  └── swift-heap-primitives     → Index                                                                             
                                                                                                                    
Layer 3 (Composite):                                                                                                
  ├── swift-buffer-primitives   → Index, Input, Bit, Handle                                                         
  ├── swift-dictionary-primitives → Index, Set                                                                      
  ├── swift-graph-primitives    → Index, Input, Bit, Stack, Set, Heap                                               
  ├── swift-handle-primitives   → Index, Bit                                                                        
  ├── swift-machine-primitives  → Index, Input, Bit, Handle                                                         
  └── swift-tree-primitives     → Index, Input, Bit, Stack, Queue, Array                                            
                                                                                                                    
---                                                                                                                 
6. Benefits of Systematic Adoption                                                                                  
                                                                                                                    
6.1 Type Safety                                                                                                     
                                                                                                                    
Cross-collection index errors become compile-time failures:                                                         
                                                                                                                    
let stackIdx: Stack.Index<Int> = 5                                                                                  
let queueIdx: Queue.Index<Int> = 5                                                                                  
queue[stackIdx]  // ❌ Compile error: expected Queue.Index<Int>, got Stack.Index<Int>                               
                                                                                                                    
6.2 Uniform Consumption                                                                                             
                                                                                                                    
All iterable structures support checkpoint-based traversal:                                                         
                                                                                                                    
func consume<I: Input.Protocol>(_ input: inout I) where I.Element == UInt8 {                                        
    let cp = input.checkpoint                                                                                       
    // Try pattern match                                                                                            
    if failed {                                                                                                     
        input.restore(to: cp)  // Backtrack                                                                         
    }                                                                                                               
}                                                                                                                   
                                                                                                                    
// Works uniformly with:                                                                                            
var array = Array([1, 2, 3])                                                                                        
var deque = Deque([1, 2, 3])                                                                                        
var set = Set.Ordered([1, 2, 3])                                                                                    
                                                                                                                    
6.3 Safe Access                                                                                                     
                                                                                                                    
The .safe accessor provides uniform nil-returning subscripts:                                                       
                                                                                                                    
array.safe[100]   // nil, not crash                                                                                 
deque.safe[100]   // nil                                                                                            
stack.safe[100]   // nil                                                                                            
                                                                                                                    
6.4 Bit Semantics                                                                                                   
                                                                                                                    
Binary operations use canonical types:                                                                              
                                                                                                                    
var visited: Bit.Set = ...                                                                                          
visited.insert(node.index)  // Type-safe: node.index is Index<Graph.Node<T>>                                        
                                                                                                                    
---                                                                                                                 
7. Conclusion                                                                                                       
                                                                                                                    
The principle of semantic correctness over dependency minimization leads to a more robust architecture. The three   
foundational primitives—Index<Element> for typed positions, Input.Protocol for consumable cursors, and Bit for      
binary semantics—provide orthogonal capabilities that compose cleanly across all data structure implementations.    
                                                                                                                    
By adopting these primitives systematically, the Swift Institute data structure packages gain:                      
                                                                                                                    
1. Compile-time prevention of cross-collection index confusion                                                      
2. Uniform consumption patterns with backtracking support                                                           
3. Canonical bit-level semantics with explicit ordering                                                             
4. Safe accessor patterns that return optionals instead of trapping                                                 
                                                                                                                    
The resulting dependency graph, while richer than the minimal approach, reflects the true semantic relationships    
between abstractions and produces APIs that are correct by construction.                                            
                                                                                                                    
---                                                                                                                 
Appendix: Summary Table                                                                                             
┌────────────┬────────────┬──────────────┬──────────┬─────────────────────┐                                         
│  Package   │ Add Index  │  Add Input   │ Add Bit  │      Rationale      │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ array      │ ✓          │ ✓ Protocol   │ (has)    │ Parsing consumption │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ buffer     │ ✓          │ ✓ Protocol   │ ✓ Order  │ Binary protocols    │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ deque      │ ✓          │ ✓ Protocol   │ -        │ Sliding windows     │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ dictionary │ ✓          │ -            │ -        │ Type safety only    │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ graph      │ (refactor) │ ✓ Protocol   │ (has)    │ Traversal cursors   │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ handle     │ ✓          │ -            │ ✓ Set    │ Pool management     │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ heap       │ ✓          │ -            │ -        │ Position semantics  │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ list       │ ✓          │ ✓ Protocol   │ -        │ Cursor iteration    │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ machine    │ ✓          │ ✓ (internal) │ ✓ Set    │ Execution state     │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ queue      │ ✓          │ ✓ Streaming  │ -        │ FIFO consumption    │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ set        │ ✓          │ ✓ Protocol   │ (has)    │ Ordered iteration   │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ stack      │ ✓          │ ✗            │ -        │ LIFO incompatible   │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ tree       │ ✓          │ ✓ Protocol   │ ✓ Set    │ Traversal cursors   │                                         
├────────────┼────────────┼──────────────┼──────────┼─────────────────────┤                                         
│ vector     │ ✓          │ -            │ ✓ Vector │ Compile-time bounds │                                         
└────────────┴────────────┴──────────────┴──────────┴─────────────────────┘                                         
