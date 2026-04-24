# Variant Catalog: Data Structures

Exhaustive inventory of public types per variant module for the eight
data-structure umbrella packages. Types are listed with their fully-qualified
API name and Swift kind. Umbrella modules (re-export only, no own types) are
noted as such.

---

## swift-array-primitives

### Array Primitives (umbrella)
Re-exports all variant modules. No own types.

### Array Primitives Core
- `Array` (struct, generic over `Element: ~Copyable`)
- `Array.Fixed` (struct, namespace)
- `Array.Fixed.Error` (enum, typed error)
- `Array.Bounded` (struct, generic over `let N: Int`)
- `Array.Small` (struct, generic over `let inlineCapacity: Int`)
- `Array.Static` (struct, generic over `let capacity: Int`)
- `Array.Static.Error` (enum, `__ArrayStaticError`)
- `Array.Small.Error` (enum, `__ArraySmallError`)
- `Array.Protocol` (protocol, `__ArrayProtocol`)

### Array Bounded Primitives
Extensions on `Array.Bounded`. No new type declarations.

### Array Dynamic Primitives
- `Array.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Array.Indexed` (struct, generic over `Tag: Copyable`)
- `Array.Drain` (enum, namespace)

### Array Fixed Primitives
- `Array.Fixed.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Array.Fixed.Indexed` (struct, generic over `Tag: ~Copyable`)

### Array Small Primitives
- `Array.Small.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Array.Small.Indexed` (struct, generic over `Tag: ~Copyable`)
- `Array.Small.Drain` (enum, namespace)

### Array Static Primitives
- `Array.Static.Drain` (enum, namespace)

---

## swift-buffer-primitives

### Buffer Primitives (umbrella)
Re-exports all variant modules. No own types.

### Buffer Primitives Core
- `Buffer` (enum, namespace, generic over `Element: ~Copyable`)
- `Buffer.Growth` (enum, namespace)
- `Buffer.Growth.Policy` (struct)

### Buffer Aligned Primitives Core
- `Buffer.Aligned` (struct, `Element == UInt8`)
- `Buffer.Aligned.Error` (enum, typed error)
- `Buffer.Aligned.Space` (enum, namespace)

### Buffer Ring Primitives Core
- `Buffer.Ring` (struct)
- `Buffer.Ring.Header` (struct)
- `Buffer.Ring.Header.Cyclic` (struct, generic over `let capacity: Int`)
- `Buffer.Ring.Inline` (struct, generic over `let capacity: Int`)
- `Buffer.Ring.Inline.Error` (enum, typed error)
- `Buffer.Ring.Bounded` (struct)
- `Buffer.Ring.Bounded.Error` (enum, typed error)
- `Buffer.Ring.Checkpoint` (struct)
- `Buffer.Ring.Small` (struct, generic over `let inlineCapacity: Int`)
- `Buffer.Ring.Small.Checkpoint` (struct)

### Buffer Ring Primitives
- `Buffer.Ring.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Buffer.Ring.Push` (enum, namespace)
- `Buffer.Ring.Pop` (enum, namespace)
- `Buffer.Ring.Peek` (enum, namespace)
- `Buffer.Ring.Remove` (enum, namespace)
- `Buffer.Ring.Bounded.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Buffer.Ring.Bounded.Push` (enum, namespace)
- `Buffer.Ring.Bounded.Pop` (enum, namespace)
- `Buffer.Ring.Bounded.Peek` (enum, namespace)
- `Buffer.Ring.Bounded.Remove` (enum, namespace)

### Buffer Ring Inline Primitives
- `Buffer.Ring.Inline.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Buffer.Ring.Inline.Push` (enum, namespace)
- `Buffer.Ring.Inline.Pop` (enum, namespace)
- `Buffer.Ring.Inline.Peek` (enum, namespace)
- `Buffer.Ring.Inline.Remove` (enum, namespace)
- `Buffer.Ring.Small.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Buffer.Ring.Small.Push` (enum, namespace)
- `Buffer.Ring.Small.Pop` (enum, namespace)
- `Buffer.Ring.Small.Peek` (enum, namespace)
- `Buffer.Ring.Small.Remove` (enum, namespace)

### Buffer Linear Primitives Core
- `Buffer.Linear` (struct)
- `Buffer.Linear.Header` (struct)
- `Buffer.Linear.Inline` (struct, generic over `let capacity: Int`)
- `Buffer.Linear.Inline.Error` (enum, typed error)
- `Buffer.Linear.Bounded` (struct)
- `Buffer.Linear.Bounded.Error` (enum, typed error)
- `Buffer.Linear.Small` (struct, generic over `let inlineCapacity: Int`)

### Buffer Linear Primitives
- `Buffer.Linear.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Buffer.Linear.Peek` (enum, namespace)
- `Buffer.Linear.Remove` (enum, namespace)
- `Buffer.Linear.Bounded.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Buffer.Linear.Bounded.Peek` (enum, namespace)
- `Buffer.Linear.Bounded.Remove` (enum, namespace)
- `Buffer.Linear.Header` extensions (lifecycle methods)
- `Storage.Initialization` extensions (ring-buffer support)

### Buffer Linear Inline Primitives
- `Buffer.Linear.Inline.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Buffer.Linear.Inline.Peek` (enum, namespace)
- `Buffer.Linear.Inline.Remove` (enum, namespace)

### Buffer Linear Small Primitives
- `Buffer.Linear.Small.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Buffer.Linear.Small.Peek` (enum, namespace)
- `Buffer.Linear.Small.Remove` (enum, namespace)

### Buffer Linked Primitives Core
- `Buffer.Linked` (struct, generic over `let N: Int`)
- `Buffer.Linked.Error` (enum, typed error)
- `Buffer.Linked.Inline` (struct, generic over `let capacity: Int`)
- `Buffer.Linked.Inline.Error` (enum, typed error)
- `Buffer.Linked.Small` (struct, generic over `let inlineCapacity: Int`)

### Buffer Linked Primitives
- `Buffer.Linked.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Buffer.Linked.Insert` (enum, namespace)
- `Buffer.Linked.Remove` (enum, namespace)

### Buffer Linked Inline Primitives
- `Buffer.Linked.Inline.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Buffer.Linked.Inline.Insert` (enum, namespace)
- `Buffer.Linked.Inline.Remove` (enum, namespace)
- `Buffer.Linked.Small.Insert` (enum, namespace)
- `Buffer.Linked.Small.Remove` (enum, namespace)

### Buffer Slab Primitives Core
- `Buffer.Slab` (struct)
- `Buffer.Slab.Header` (struct)
- `Buffer.Slab.Header.Static` (struct, generic over `let wordCount: Int`)
- `Buffer.Slab.Inline` (struct, generic over `let wordCount: Int`)
- `Buffer.Slab.Inline.Error` (enum, typed error)
- `Buffer.Slab.Bounded` (struct)
- `Buffer.Slab.Bounded.Error` (enum, typed error)
- `Buffer.Slab.Bounded.Indexed` (struct, generic over `Tag: ~Copyable`)
- `Buffer.Slab.Small` (struct, generic over `let inlineCapacity: Int`)

### Buffer Slab Primitives
- `Buffer.Slab.Header.Static` extensions (lifecycle methods)
- `Buffer.Slab.Header` extensions (lifecycle methods)
- `Buffer.Slab.Bounded.Indexed` extensions (iteration)
Extensions on `Buffer.Slab`, `Buffer.Slab.Bounded`. No new type declarations.

### Buffer Slab Inline Primitives
- `Buffer.Slab.Inline.Iterator` (struct, `Sequence.Iterator.Protocol`)

### Buffer Slots Primitives Core
- `Buffer.Slots` (struct, generic over `Metadata: BitwiseCopyable`)
- `Buffer.Slots.Header` (struct)

### Buffer Slots Primitives
Extensions on `Buffer.Slots`. No new type declarations.

### Buffer Unbounded Primitives Core
- `Buffer.Unbounded` (struct, `Element == UInt8`)

### Buffer Arena Primitives Core
- `Buffer.Arena` (struct)
- `Buffer.Arena.Header` (struct)
- `Buffer.Arena.Inline` (struct, generic over `let inlineCapacity: Int`)
- `Buffer.Arena.Inline.Error` (enum, typed error)
- `Buffer.Arena.Error` (enum, typed error)
- `Buffer.Arena.Position` (struct)
- `Buffer.Arena.Bounded` (struct)
- `Buffer.Arena.Bounded.Error` (enum, typed error)
- `Buffer.Arena.Small` (struct, generic over `let inlineCapacity: Int`)

### Buffer Arena Primitives
Extensions on `Buffer.Arena`, `Buffer.Arena.Bounded`. No new type declarations.

### Buffer Arena Inline Primitives
Extensions on `Buffer.Arena.Inline`, `Buffer.Arena.Small`. No new type declarations.

---

## swift-storage-primitives

### Storage Primitives (umbrella)
Re-exports all variant modules. No own types.

### Storage Primitives Core
- `Storage` (enum, namespace, generic over `Element: ~Copyable`)
- `Storage.Initialization` (enum, tracks initialized slot ranges)
- `Storage.Error` (enum, typed error)
- `Storage.Heap` (class, `ManagedBuffer`-based)
- `Storage.Heap.Header` (struct)
- `Storage.Inline` (struct, generic over `let capacity: Int`)
- `Storage.Pool` (class, reference-semantic pool allocator)
- `Storage.Pool.Error` (enum, typed error)
- `Storage.Pool.Inline` (struct, generic over `let capacity: Int`)
- `Storage.Arena` (class, reference-semantic arena storage)
- `Storage.Arena.Meta` (struct, `BitwiseCopyable`)
- `Storage.Arena.Inline` (struct, generic over `let capacity: Int`)
- `Storage.Slab` (class, bitmap-tracked heap storage)
- `Storage.Copy` (enum, namespace)
- `Storage.Deinitialize` (enum, namespace)
- `Storage.Initialize` (enum, namespace)
- `Storage.Move` (enum, namespace)

### Storage Heap Primitives
Extensions on `Storage.Heap` (copy, deinitialize, initialize, move,
`Memory.Contiguous.Protocol` conformance). No new type declarations.

### Storage Inline Primitives
Extensions on `Storage.Inline` (deinitialize, initialize, move,
`Memory.Contiguous.Protocol` conformance). No new type declarations.

### Storage Pool Primitives
Extensions on `Storage.Pool`. No new type declarations.

### Storage Pool Inline Primitives
Extensions on `Storage.Pool.Inline`. No new type declarations.

### Storage Arena Primitives
Extensions on `Storage.Arena`. No new type declarations.

### Storage Arena Inline Primitives
Extensions on `Storage.Arena.Inline`. No new type declarations.

### Storage Slab Primitives
Extensions on `Storage.Slab`. No new type declarations.

### Storage Split Primitives
- `Storage.Split` (class, `ManagedBuffer`-based, generic over `Lane: BitwiseCopyable`)
- `Storage.Split.Header` (struct)
- `Storage.Field` (struct, generic over `Value: ~Copyable`)

---

## swift-slab-primitives

### Slab Primitives (umbrella)
Re-exports all variant modules. No own types.

### Slab Primitives Core
- `Slab` (struct, generic over `Element: ~Copyable`)
- `Slab.Static` (struct, generic over `let wordCount: Int`)
- `Slab.Indexed` (struct, generic over `Tag: ~Copyable`)
- `Slab.Error` (enum, typed error)

### Slab Dynamic Primitives
Extensions on `Slab`, `Slab.Indexed` (Copyable collection conformances,
`Sequence.Drain.Protocol`). No new type declarations.

### Slab Static Primitives
Extensions on `Slab.Static` (Copyable collection conformances,
`Sequence.Drain.Protocol`). No new type declarations.

---

## swift-heap-primitives

### Heap Primitives (umbrella)
Re-exports all variant modules. No own types.

### Heap Primitives Core
- `Heap` (struct, generic over `Element: ~Copyable & Comparison.Protocol`)
- `Heap.Order` (enum)
- `Heap.Error` (enum, typed error)
- `Heap.Fixed` (struct)
- `Heap.Fixed.Error` (enum, typed error)
- `Heap.Push` (enum, namespace, `~Copyable`)
- `Heap.Push.Outcome` (enum, `~Copyable`)
- `Heap.Remove` (enum, namespace)
- `Heap.Navigate` (struct)
- `Heap.Navigate.Child` (enum)
- `Heap.MinMax` (struct)
- `Heap.Small` (struct, generic over `let inlineCapacity: Int`)
- `Heap.Small.Error` (enum, typed error)
- `Heap.Static` (struct, generic over `let capacity: Int`)
- `Heap.Static.Error` (enum, typed error)

### Heap Binary Primitives
- `Heap.Iterator` (struct, `Sequence.Iterator.Protocol`)

### Heap Fixed Primitives
- `Heap.Fixed.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Heap.Fixed.Remove` (enum, namespace)

### Heap Static Primitives
- `Heap.Static.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Heap.Static.Remove` (enum, namespace)
- `Heap.Static.Drain` (enum, namespace)
- `Heap.Static.ForEach` (enum, namespace)
- `Heap.Static.Satisfies` (enum, namespace)
- `Heap.Static.First` (enum, namespace)
- `Heap.Static.Reduce` (enum, namespace)
- `Heap.Static.Contains` (enum, namespace)
- `Heap.Static.Drop` (enum, namespace)
- `Heap.Static.Prefix` (enum, namespace)

### Heap Small Primitives
- `Heap.Small.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Heap.Small.Remove` (enum, namespace)
- `Heap.Small.Drain` (enum, namespace)
- `Heap.Small.ForEach` (enum, namespace)
- `Heap.Small.Satisfies` (enum, namespace)
- `Heap.Small.First` (enum, namespace)
- `Heap.Small.Reduce` (enum, namespace)
- `Heap.Small.Contains` (enum, namespace)
- `Heap.Small.Drop` (enum, namespace)
- `Heap.Small.Prefix` (enum, namespace)

### Heap Min Primitives
- `Heap.Min` (struct)

### Heap Max Primitives
- `Heap.Max` (struct)

### Heap MinMax Primitives
- `Heap.MinMax.Position` (enum)
- `Heap.MinMax.Min` (enum, namespace)
- `Heap.MinMax.Max` (enum, namespace)
- `Heap.MinMax.Remove` (enum, namespace)
- `Heap.MinMax.Peek` (enum, namespace)
- `Heap.MinMax.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Heap.MinMax.Fixed` (struct)
- `Heap.MinMax.Static` (struct, generic over `let capacity: Int`)
- `Heap.MinMax.Static.Error` (enum, typed error)
- `Heap.MinMax.Small` (struct, generic over `let inlineCapacity: Int`)
- `Heap.MinMax.Small.Error` (enum, typed error)

---

## swift-tree-primitives

### Tree Primitives (umbrella)
Re-exports all variant modules. No own types.

### Tree Primitives Core
- `Tree` (enum, namespace, generic over `Element: ~Copyable`)
- `Tree.Binary` (enum, namespace)
- `Tree.N` (struct, generic over `let n: Int`)
- `Tree.N.Node` (struct)
- `Tree.N.Error` (enum, `__TreeNError`)
- `Tree.N.ChildSlot` (struct, `__TreeNChildSlot`, generic over `let n: Int`)
- `Tree.N.InsertPosition` (enum, `__TreeNInsertPosition`, generic over `let n: Int`)
- `Tree.N.Order` (enum, namespace)
- `Tree.N.Order.In` (enum, namespace)
- `Tree.N.Order.In.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Tree.N.Order.In.Sequence` (struct, `Swift.Sequence`)
- `Tree.N.Order.Pre` (enum, namespace)
- `Tree.N.Order.Pre.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Tree.N.Order.Pre.Sequence` (struct, `Swift.Sequence`)
- `Tree.N.Order.Post` (enum, namespace)
- `Tree.N.Order.Post.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Tree.N.Order.Post.Sequence` (struct, `Swift.Sequence`)
- `Tree.N.Order.Level` (enum, namespace)
- `Tree.N.Order.Level.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Tree.N.Order.Level.Sequence` (struct, `Swift.Sequence`)
- `Tree.Position` (struct, `__TreePosition`)

### Tree N Bounded Primitives
- `Tree.N.Bounded` (struct)
- `Tree.N.Bounded.Error` (enum, `__TreeNBoundedError`)
- `Tree.N.Bounded.Order` (enum, namespace)
- `Tree.N.Bounded.Order.In` (enum, namespace)
- `Tree.N.Bounded.Order.In.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Tree.N.Bounded.Order.In.Sequence` (struct, `Swift.Sequence`)
- `Tree.N.Bounded.Order.Pre` (enum, namespace)
- `Tree.N.Bounded.Order.Pre.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Tree.N.Bounded.Order.Pre.Sequence` (struct, `Swift.Sequence`)
- `Tree.N.Bounded.Order.Post` (enum, namespace)
- `Tree.N.Bounded.Order.Post.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Tree.N.Bounded.Order.Post.Sequence` (struct, `Swift.Sequence`)
- `Tree.N.Bounded.Order.Level` (enum, namespace)
- `Tree.N.Bounded.Order.Level.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Tree.N.Bounded.Order.Level.Sequence` (struct, `Swift.Sequence`)

### Tree N Inline Primitives
- `Tree.N.Inline` (struct, generic over `let capacity: Int`)
- `Tree.N.Inline.Error` (enum, `__TreeNInlineError`)

### Tree N Small Primitives
- `Tree.N.Small` (struct, generic over `let inlineCapacity: Int`)
- `Tree.N.Small.Error` (enum, `__TreeNSmallError`)

### Tree Unbounded Primitives
- `Tree.Unbounded` (struct)
- `Tree.Unbounded.Node` (struct)
- `Tree.Unbounded.Error` (enum, `__TreeUnboundedError`)
- `Tree.Unbounded.Bounded.Error` (enum, `__TreeUnboundedBoundedError`)
- `Tree.Unbounded.Small.Error` (enum, `__TreeUnboundedSmallError`)
- `Tree.Unbounded.InsertPosition` (enum, `__TreeUnboundedInsertPosition`)

### Tree Keyed Primitives
- `Tree.Keyed` (struct, generic over `Key: Hash.Protocol`)
- `Tree.Keyed.Node` (struct)
- `Tree.Keyed.Error` (enum, `__TreeKeyedError`, generic over `Key: Hash.Protocol`)
- `Tree.Keyed.InsertPosition` (enum, `__TreeKeyedInsertPosition`, generic over `Key: Hash.Protocol`)
- `Tree.Keyed.Diff` (struct, `__TreeKeyedDiff`, generic over `Key: Hash.Protocol, Value: Equatable`)
- `Tree.Keyed.Diff.Operation` (enum)
- `Tree.Keyed.Order` (enum, namespace)
- `Tree.Keyed.Order.Pre` (enum, namespace)
- `Tree.Keyed.Order.Pre.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Tree.Keyed.Order.Pre.Sequence` (struct, `Swift.Sequence`)
- `Tree.Keyed.Order.Post` (enum, namespace)
- `Tree.Keyed.Order.Post.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Tree.Keyed.Order.Post.Sequence` (struct, `Swift.Sequence`)
- `Tree.Keyed.Order.Level` (enum, namespace)
- `Tree.Keyed.Order.Level.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `Tree.Keyed.Order.Level.Sequence` (struct, `Swift.Sequence`)

---

## swift-list-primitives

### List Primitives (umbrella)
Re-exports all variant modules. No own types.

### List Primitives Core
- `List` (enum, namespace, generic over `Element: ~Copyable`)
- `List.Linked` (struct, generic over `let N: Int`)
- `List.Linked.Peek` (enum, namespace)
- `List.Linked.Reversed` (enum, namespace)
- `List.Linked.Error` (enum, `__ListLinkedError`)
- `List.Linked.Bounded` (struct)
- `List.Linked.Bounded.Peek` (enum, namespace)
- `List.Linked.Bounded.Reversed` (enum, namespace)
- `List.Linked.Bounded.Error` (enum, `__ListLinkedBoundedError`)
- `List.Linked.Inline` (struct, generic over `let capacity: Int`)
- `List.Linked.Inline.Peek` (enum, namespace)
- `List.Linked.Inline.Reversed` (enum, namespace)
- `List.Linked.Inline.Error` (enum, `__ListLinkedInlineError`)
- `List.Linked.Small` (struct, generic over `let inlineCapacity: Int`)
- `List.Linked.Small.Error` (enum, `__ListLinkedSmallError`)

### List Linked Primitives
- `List.Linked.Iterator` (struct, `Sequence.Iterator.Protocol`)
- `List.Linked.Bounded.Iterator` (struct, `Sequence.Iterator.Protocol`)

---

## swift-pool-primitives

### Pool Primitives (umbrella)
Re-exports all variant modules. No own types.

### Pool Primitives Core
- `Pool` (enum, namespace)
- `Pool.Error` (enum, typed error)
- `Pool.Capacity` (struct)
- `Pool.ID` (struct)
- `Pool.Scope` (struct)
- `Pool.Metrics` (struct)
- `Pool.Lifecycle` (enum, namespace)
- `Pool.Lifecycle.Error` (enum, typed error)
- `Pool.Lifecycle.State` (typealias to `Async.Lifecycle.State`)
- `Pool.Lifecycle.Precedence` (enum, namespace)
- `Pool.Acquire` (struct, generic over `Resource: ~Copyable & Sendable`)
- `Pool.Release` (struct, generic over `Resource: ~Copyable & Sendable`)

### Pool Bounded Primitives
- `Pool.Bounded` (class, generic over `Resource: ~Copyable & Sendable`)
- `Pool.Bounded.Acquire` (struct, accessor namespace)
- `Pool.Bounded.Acquire.Try` (struct, non-blocking acquire)
- `Pool.Bounded.Acquire.Timeout` (struct, timed acquire)
- `Pool.Bounded.Acquire.Callback` (struct, callback-based acquire)
- `Pool.Bounded.Fill` (struct, eager-fill accessor)
- `Pool.Bounded.Fill.Error` (enum, typed error)
- `Pool.Bounded.Shutdown` (struct, shutdown accessor)
