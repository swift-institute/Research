<!--
status: AGENTS_FILLING
scope: Phase 1 parallel classification, Category D candidates for principal adjudication
-->

# Category D Adjudication Queue

> Phase 1 agents flag `@unchecked Sendable` sites they believe are **Category D** (structural Sendable workaround / phantom-type inference gap) here. Do NOT classify D yourself — principal adjudicates in one pass after all agents return, ensuring consistent D-vs-B judgment across the ecosystem.

**Category D criteria** (from `unsafe-audit-findings.md`):

- No runtime synchronization (no mutex, atomic, lock)
- Not `~Copyable` ownership transfer (or `~Copyable` is incidental — the Sendable claim doesn't hinge on single-owner semantics)
- No caller-visible invariant (the caller would have nothing to uphold)
- The `@unchecked` exists to work around a compiler gap — typically: phantom `Tagged<T, Marker>` does not prove structural Sendable from `T: Sendable`, or `<let N: Int>` value-generic blocks inference

If any of the above is false → likely A or B → classify normally in your findings file.

---

## Agent 1 — Threads / Executors / Kernel / Witnesses / Dependencies

_(to be filled by Agent 1)_

---

## Agent 2 — Storage / Queue / Stack

_(to be filled by Agent 2)_

---

## Agent 3 — Heap / List / Memory

_(to be filled by Agent 3)_

---

## Agent 4 — Hash / Identity / Index / Cardinal / Ordinal

**Scope totals**: 3 `@unchecked Sendable` hits total, all in swift-hash-table-primitives. swift-identity-primitives / swift-index-primitives / swift-cardinal-primitives / swift-ordinal-primitives are **clean** (zero hits each). 2 D candidates + 1 LOW_CONFIDENCE (see agent4 findings file for the LOW_CONFIDENCE case).

### D-candidate: `Hash.Table<Element: ~Copyable>` — swift-hash-table-primitives/Sources/Hash Table Primitives Core/Hash.Table.swift:141

**Why D, not B**: The `@unchecked` conformance is constrained `where Element: Sendable`. If the conformance genuinely encoded `~Copyable` single-owner move semantics for the heap buffer, the `Element: Sendable` constraint would be incoherent — `Element` is a **phantom parameter** (never stored; used only for phantom position typing via `Index<Element>` and resolving `Hash.Protocol` at call sites). The gated constraint betrays the phantom-type inference gap: the compiler cannot propagate `Sendable` through the phantom `Element` parameter, so the author explicitly gated it. If `~Copyable` ownership were the real reason, an unconstrained `extension Hash.Table: @unchecked Sendable {}` would be correct.

**Stored fields**:
- `_count: Index<Element>.Count` — pure value (Cardinal-backed typed count)
- `_occupied: Index<Bucket>.Count` — pure value (Cardinal-backed typed count)
- `_buffer: Buffer<Int>.Slots<Int>` — heap-allocated `~Copyable` slots buffer; itself carries `@unchecked Sendable where Element: Sendable` (Agent 2 scope — buffer-primitives)

**Generic parameters involved**:
- `Element: ~Copyable` — **phantom type-generic** (never stored; used only for phantom position typing and `Hash.Protocol` resolution at call sites)

**Current annotation site**: Extension: `extension Hash.Table: @unchecked Sendable where Element: Sendable {}`

**Is it also `~Copyable`?**: **Yes** — declared `public struct Table<Element: ~Copyable>: ~Copyable`. It owns a heap-allocated `Buffer.Slots` via unique ownership. However, the **reason** for `@unchecked Sendable` appears to be the phantom-type gap (evidenced by the `where Element: Sendable` constraint — an irrelevant constraint if ownership-transfer were the real concern), not ownership transfer per se. Principal to adjudicate whether the phantom-type-gap motivation outweighs the `~Copyable` ownership reality for classification purposes.

---

### D-candidate: `Hash.Table.Static<let bucketCapacity: Int>` — swift-hash-table-primitives/Sources/Hash Table Primitives Core/Hash.Table.Static.swift:164

**Why D, not B**: This is the **canonical Category D example** per `unsafe-audit-findings.md` §"Known sites". Two compounding structural inference gaps: (1) value-generic `<let bucketCapacity: Int>` — Swift's structural Sendable inference does not propagate through integer-valued generic parameters, so even though `InlineArray<bucketCapacity, Int>` is provably pure value bytes, the compiler cannot prove it; (2) phantom `Element: ~Copyable` parameter (inherited from extension scope) — never stored. Conformance gated `where Element: Sendable`, betraying the phantom-type concern. All storage is inline — no heap, no owned resource, no deinit, no single-owner semantic necessity.

**Stored fields**:
- `_hashes: InlineArray<bucketCapacity, Int>` — pure inline value bytes (no heap)
- `_positions: InlineArray<bucketCapacity, Int>` — pure inline value bytes (no heap)
- `_count: Index<Element>.Count` — pure value (Cardinal-backed typed count)
- `_occupied: Bucket.Index.Count` — pure value (Cardinal-backed typed count)

**Generic parameters involved**:
- `Element: ~Copyable` — **phantom type-generic** (inherited from extension scope `extension Hash.Table where Element: ~Copyable`; never stored; used only for `Hash.Table<Element>.empty` / `.deleted` / `.normalize` forwarding and phantom position typing)
- `bucketCapacity: Int` — **value-generic** (drives `InlineArray` dimension; Swift does not propagate Sendable through `let N: Int` parameters)

**Current annotation site**: Extension: `extension Hash.Table.Static: @unchecked Sendable where Element: Sendable {}`

**Is it also `~Copyable`?**: **Yes, but incidentally.** Declared `public struct Static<let bucketCapacity: Int>: ~Copyable`. The `~Copyable` trait is **inherited from parent-type layering** (Hash.Table is ~Copyable because `Element` may be ~Copyable), NOT because the type owns a heap resource. Unlike `Hash.Table` (which owns `Buffer.Slots`), `Hash.Table.Static` has nothing to single-own — all storage is inline `InlineArray` and typed counts. This is the cleanest D candidate in Agent 4's scope: the `~Copyable` is a type-system artifact of the extension scope, not a semantic ownership claim.

---

## Agent 5 — swift-io + small primitives scatter

**Scope totals**: 57 total `@unchecked Sendable` hits (exceeds the 40-hit guardrail; proceeded given well-established pattern families). See `unsafe-audit-agent5-findings.md` for full per-site classification. Counts: **A: 13, B: 10, C: 1, D-candidate: 27, LOW_CONFIDENCE: 6 (some overlap with D/B).**

### D-candidate: `Plist.ND.State<I>` — swift-plist/Sources/Plist/Plist.Stream.swift:131

**Why D, not B**: No `~Copyable`, no synchronization. Holds an `AsyncIteratorProtocol`, a buffer, a done flag. Used inside an Async.Stream pull loop — genuinely single-thread-confined via stream semantics. The `@unchecked` is there because the generic parameter `I: AsyncIteratorProtocol` blocks structural Sendable inference (AsyncIteratorProtocol has no Sendable refinement).
**Stored fields**: `iterator: I`, `buffer: [UInt8]`, `done: Bool`
**Generic parameters involved**: `I: AsyncIteratorProtocol` (where `I.Element == UInt8`)
**Current annotation site**: Type declaration
**Is it also `~Copyable`?**: No

---

### D-candidate: `JSON.ND.State<I>` — swift-json/Sources/JSON/JSON.Stream.swift:78

**Why D, not B**: Identical pattern to `Plist.ND.State`. No synchronization. AsyncIteratorProtocol generic blocks inference.
**Stored fields**: `iterator: I`, `buffer: [UInt8]`, `done: Bool`
**Generic parameters involved**: `I: AsyncIteratorProtocol` (where `I.Element == UInt8`)
**Current annotation site**: Type declaration
**Is it also `~Copyable`?**: No

---

### D-candidate: `XML.ND.State<I>` — swift-xml/Sources/XML/XML.Stream.swift:133

**Why D, not B**: Identical pattern. No synchronization, AsyncIteratorProtocol generic blocks inference.
**Stored fields**: `iterator: I`, `buffer: [UInt8]`, `done: Bool`
**Generic parameters involved**: `I: AsyncIteratorProtocol` (where `I.Element == UInt8`)
**Current annotation site**: Type declaration
**Is it also `~Copyable`?**: No

---

### D-candidate: `CoW.Storage` (macro-generated) — swift-copy-on-write/Sources/Copy on Write Macros/CoWMacro.swift:624

**Why D, not B**: Macro-generated storage class for `@CoW`. The CoW discipline itself prevents shared-mutation (any mutation path copies storage first), but the storage class itself has no runtime enforcement. No Mutex/Atomic; no `~Copyable`.
**Stored fields**: Generated from user-declared properties; varies per expansion.
**Generic parameters involved**: None at the macro template level.
**Current annotation site**: Macro-generated source.
**Is it also `~Copyable`?**: No
**Additional note**: Decision affects every `@CoW`-using type across the ecosystem. Macro policy choice.

---

### D-candidate: `PDF.HTML.Context.Table.Recording` — swift-pdf-html-rendering/Sources/PDF HTML Rendering/PDF.HTML.Context.Table.Recording.swift:13

**Why D, not B**: Struct not `~Copyable`. Holds a commands array; used only as a temporary recording buffer within one push/pop traversal. Docstring explicitly says "recording is temporary and does not cross concurrency boundaries." The `@unchecked` is forced by the next item (the Command enum).
**Stored fields**: `commands: [Command]`, `savedY`, `elementDepth: Int`, `columnCount: Int`, `pendingColspan: Int`
**Generic parameters involved**: None
**Current annotation site**: Type declaration
**Is it also `~Copyable`?**: No

---

### D-candidate: `PDF.HTML.Context.Table.Recording.Command` — swift-pdf-html-rendering/Sources/PDF HTML Rendering/PDF.HTML.Context.Table.Recording.Command.swift:12

**Why D, not B**: Enum with `inlineStyle(Any)` case — the `Any` existential blocks Sendable inference. All other cases are value types (String, Int, Bool, typed enums). Per docstring, recording stays thread-local.
**Stored fields**: Enum cases; only `inlineStyle(Any)` is non-Sendable.
**Generic parameters involved**: None (the `Any` is an existential).
**Current annotation site**: Type declaration
**Is it also `~Copyable`?**: No

---

### D-candidate: `Predicate<T>` — swift-predicate-primitives/Sources/Predicate Primitives/Predicate.swift:29

**Why D, not B**: Struct, not `~Copyable`. Holds `var evaluate: (T) -> Bool` — non-`@Sendable` closure. The `@unchecked` is the workaround for the closure type. No invariant in practice; Predicate is treated as a pure function value.
**Stored fields**: `evaluate: (T) -> Bool`
**Generic parameters involved**: `T`
**Current annotation site**: Type declaration
**Is it also `~Copyable`?**: No
**Principal note**: Arguably the correct fix is to make the closure `@Sendable` in the stored-property type, which would obsolete `@unchecked`. That is a source-breaking API change, so a separate decision.

---

### D-candidate: `__InfiniteObservableIterator<Source>` — swift-infinite-primitives/Sources/Infinite Primitives/Infinite.Observable.Iterator.swift:66

**Why D, not B**: Conditional `where Source: Sendable`. Iterator struct (`~Copyable`) holding a generic `Source` and inline `Optional<Source.Element>`. The `~Copyable` is for iterator semantics, not ownership transfer across threads. No invariant beyond "if Source is Sendable, the iterator is too". Phantom-forwarding over generic.
**Stored fields**: `current: Source`, `_element: Source.Element?`
**Generic parameters involved**: `Source: Infinite.Observable` (where `Source.Tail == Source`)
**Current annotation site**: Extension: `extension __InfiniteObservableIterator: @unchecked Sendable where Source: Sendable {}`
**Is it also `~Copyable`?**: Yes (iterator semantics, not ownership transfer)

---

### D-candidate: `Infinite.Map.Iterator` — swift-infinite-primitives/Sources/Infinite Primitives/Infinite.Map.swift:120

**Why D, not B**: Conditional `where Source.Iterator: Sendable`. Same family as `__InfiniteObservableIterator`.
**Stored fields**: iterator + transform closure
**Generic parameters involved**: `Source.Iterator: Sendable`
**Current annotation site**: Extension
**Is it also `~Copyable`?**: Presumably yes (iterator convention in this package)

---

### D-candidate: `Infinite.Zip.Iterator` — swift-infinite-primitives/Sources/Infinite Primitives/Infinite.Zip.swift:141

**Why D, not B**: Same family. Conditional over `First.Iterator: Sendable, Second.Iterator: Sendable`.
**Generic parameters involved**: `First.Iterator: Sendable`, `Second.Iterator: Sendable`
**Current annotation site**: Extension
**Is it also `~Copyable`?**: Presumably yes

---

### D-candidate: `Infinite.Scan.Iterator` — swift-infinite-primitives/Sources/Infinite Primitives/Infinite.Scan.swift:160

**Why D, not B**: Same family. Conditional over `Source.Iterator: Sendable, Result: Sendable`. Already referenced in ownership-transfer-conventions.md line 345 as a low-priority deferred item.
**Generic parameters involved**: `Source.Iterator: Sendable`, `Result: Sendable`
**Current annotation site**: Extension
**Is it also `~Copyable`?**: Presumably yes

---

### D-candidate: `Infinite.Cycle.Iterator` — swift-infinite-primitives/Sources/Infinite Primitives/Infinite.Cycle.swift:127

**Why D, not B**: Same family. Conditional over `Base: Sendable, Base.Index: Sendable`.
**Generic parameters involved**: `Base: Sendable`, `Base.Index: Sendable`
**Current annotation site**: Extension
**Is it also `~Copyable`?**: Presumably yes

---

### D-candidate: `Sample.Batch<Element>` — swift-sample-primitives/Sources/Sample Primitives Core/Sample.Batch.swift:31

**Why D, not B**: Conditional `where Element: Sendable`. Struct holds a reference to `_SampleBatchStorage<Element>`. The struct itself is `~Copyable` unconditionally, but the Sendable refinement is phantom-forwarding over `Element`.
**Stored fields**: `_storage: _SampleBatchStorage<Element>`
**Generic parameters involved**: `Element: ~Copyable` (conditional `Sendable`)
**Current annotation site**: Extension
**Is it also `~Copyable`?**: Conditional (only `Copyable` when `Element: Copyable`).

---

### D-candidate: `_SampleBatchStorage<Element>` — swift-sample-primitives/Sources/Sample Primitives Core/Sample.Batch.Storage.swift:8

**Why D, not B**: UNCONDITIONAL `@unchecked Sendable` — not conditional on Element: Sendable. Internal class with raw pointer + count, both `let` (immutable after init). Used from Sample.Batch (also @unchecked conditionally). No synchronization. The unconditional form is suspect; likely should be conditional on `Element: Sendable`.
**Stored fields**: `base: UnsafeMutablePointer<Element>`, `count: Int` (both `let`)
**Generic parameters involved**: `Element: ~Copyable`
**Current annotation site**: Type declaration
**Is it also `~Copyable`?**: No (class)
**Principal note**: The unconditional Sendable is arguably a bug — should be conditional on `Element: Sendable`. That's a separate correctness issue.

---

### D-candidate: `Tree.N<Element>` — swift-tree-primitives/Sources/Tree Primitives Core/Tree.N.swift:774

**Why D, not B**: Conditional `where Element: Sendable`. Arena-backed tree using raw pointers, but the data is structurally value-like. No synchronization. Phantom-forwarding over Element.
**Stored fields**: Arena (raw-pointer-backed), node metadata.
**Generic parameters involved**: `Element: ~Copyable`
**Current annotation site**: Extension
**Is it also `~Copyable`?**: Conditional (`Copyable` when `Element: Copyable`)
**Principal note**: Check whether Agent 4's scope overlaps; tree-primitives may have been intended for another agent.

---

### D-candidate: `Tree.N.Small<Element>` — swift-tree-primitives/Sources/Tree N Small Primitives/Tree.N.Small.swift:522

**Why D, not B**: Same pattern as Tree.N.
**Generic parameters involved**: `Element: ~Copyable`
**Current annotation site**: Extension
**Is it also `~Copyable`?**: Conditional

---

### D-candidate: `Tree.N.Bounded<Element>` — swift-tree-primitives/Sources/Tree N Bounded Primitives/Tree.N.Bounded.swift:603

**Why D, not B**: Same pattern.
**Generic parameters involved**: `Element: ~Copyable`
**Current annotation site**: Extension
**Is it also `~Copyable`?**: Conditional

---

### D-candidate: `Tree.Unbounded<Element>` — swift-tree-primitives/Sources/Tree Unbounded Primitives/Tree.Unbounded.swift:680

**Why D, not B**: Same pattern.
**Generic parameters involved**: `Element: ~Copyable`
**Current annotation site**: Extension
**Is it also `~Copyable`?**: Conditional

---

### D-candidate: `Tree.Keyed<Key, Element>` — swift-tree-primitives/Sources/Tree Keyed Primitives/Tree.Keyed.swift:467

**Why D, not B**: Same pattern, two type parameters. Conditional on `Key: Sendable, Element: Sendable`.
**Generic parameters involved**: `Key`, `Element: ~Copyable`
**Current annotation site**: Extension
**Is it also `~Copyable`?**: Conditional

---

### D-candidate: `Tree.N.Inline<Element>` — swift-tree-primitives/Sources/Tree N Inline Primitives/Tree.N.Inline.swift:505

**Why D, not B**: Same pattern.
**Generic parameters involved**: `Element: ~Copyable`
**Current annotation site**: Extension
**Is it also `~Copyable`?**: Conditional

---

### D-candidate: `Rendering.Indirect<Content: ~Copyable>` — swift-rendering-primitives/Sources/Rendering Primitives Core/Rendering.Indirect.swift:22

**Why D, not B**: UNCONDITIONAL `@unchecked Sendable` on a `final class Indirect<Content: ~Copyable>` with a `let value: Content`. Near-identical pattern to `Ownership.Shared`. `~Copyable` generic in class storage blocks Sendable inference. Value is immutable (`let`), so structurally safe when Content is Sendable.
**Stored fields**: `value: Content` (`let`)
**Generic parameters involved**: `Content: ~Copyable`
**Current annotation site**: Type declaration
**Is it also `~Copyable`?**: No (class)
**Principal note**: Likely should be conditional `where Content: Sendable` rather than unconditional.

---

### D-candidate: `Bit.Vector.Ones.View` — swift-bit-vector-primitives/Sources/Bit Vector Primitives Core/Bit.Vector.Ones.View.swift:21

**Why D, not B**: `Copyable` struct holding raw pointer `_words: UnsafeMutablePointer<UInt>`. Non-owning view — caller manages buffer lifetime. No `~Copyable`, no synchronization. The `@unchecked` exists because raw-pointer fields block Sendable inference.
**Stored fields**: `_words: UnsafeMutablePointer<UInt>`, `_wordCount`, `_capacity`
**Generic parameters involved**: None
**Current annotation site**: Type declaration
**Is it also `~Copyable`?**: No

---

### D-candidate: `Bit.Vector` — swift-bit-vector-primitives/Sources/Bit Vector Primitives Core/Bit.Vector.swift:146

**Why D, not B**: UNCONDITIONAL `@unchecked Sendable` on a raw-pointer-backed vector. Exposes `withUnsafeMutableWords` — so mutation is possible. Would need principal to confirm whether concurrent mutation is a documented non-goal or a latent issue.
**Stored fields**: `_words` (raw mutable pointer), `_wordCount`, etc.
**Generic parameters involved**: None
**Current annotation site**: Extension
**Is it also `~Copyable`?**: Not read at declaration; verify.

---

### D-candidate: `Bit.Vector.Zeros.View` — swift-bit-vector-primitives/Sources/Bit Vector Primitives Core/Bit.Vector.Zeros.View.swift:21

**Why D, not B**: Same pattern as `Bit.Vector.Ones.View`.
**Stored fields**: Same pattern
**Generic parameters involved**: None
**Current annotation site**: Type declaration
**Is it also `~Copyable`?**: No

---

### D-candidate: `CopyOnWrite.Storage` (structured-queries) — swift-structured-queries-primitives/Sources/Structured Queries Primitives/Statements/Select/Select.swift:500

**Why D, not B**: Conditional `where Value: Sendable`. CoW storage — no external sharing (CoW discipline). Structural phantom-forwarding.
**Stored fields**: Depends on the CopyOnWrite definition; not re-read here.
**Generic parameters involved**: `Value`
**Current annotation site**: Extension
**Is it also `~Copyable`?**: No

---

### D-candidate: `Sequence.Consume.View<Element, State>` — swift-sequence-primitives/Sources/Sequence Consuming Primitives/Sequence.Consume.View.swift:86

**Why D, not B**: Conditional `where Element: Sendable, State: Sendable`. The struct is `~Copyable` for iteration semantics, not ownership transfer. Phantom-forwarding over two parameters.
**Stored fields**: `_state: State`, `_next: (inout State) -> Element?` (closure)
**Generic parameters involved**: `Element: ~Copyable`, `State: ~Copyable`
**Current annotation site**: Extension
**Is it also `~Copyable`?**: Yes (iterator semantics, not ownership transfer)
**Principal note**: The stored `_next` is a non-`@Sendable` closure. Same concern as Predicate.

---

### D-candidate: `Property.Consuming.State` — swift-property-primitives/Sources/Property Primitives Core/Property.Consuming.swift:98

**Why D, not B**: Inner `final class State: @unchecked Sendable` inside `Property.Consuming<Element>` (itself `~Copyable`, `Sendable where Base: Sendable`). State holds mutable `_base: Base?` and `_consumed: Bool`. Scope: tied to a `_modify` accessor lifecycle (state survives the mutating-method call to enable defer-based restoration). Intended single-threaded per accessor.
**Stored fields**: `_base: Base?`, `_consumed: Bool`
**Generic parameters involved**: Outer `Tag`, `Base`, `Element`.
**Current annotation site**: Inner class declaration
**Is it also `~Copyable`?**: No (class)
**Principal note**: Could also be Cat C (thread-confined to the accessor). The unconditional `@unchecked` (not `where Base: Sendable`) is what makes it read as D rather than C.

---

**Total from Agent 5**: 27 D-candidates queued.

---

## Agent 6 — swift-buffer-primitives (coverage gap fill, ~41 hits)

_(to be filled by Agent 6)_

---

## Agent 7 — data structures + async scatter (coverage gap fill, ~45 hits)

_(to be filled by Agent 7)_
