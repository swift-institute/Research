# Split Storage Design

<!--
---
version: 3.0.0
last_updated: 2026-02-07
status: RECOMMENDATION
research_tier: 2
applies_to: [swift-storage-primitives, swift-buffer-primitives]
normative: false
upstream: metadata-parametric-slots.md (v1.0.0, Buffer.Slots substrate)
changelog:
  - 3.0.0 (2026-02-07): Converged via Claude-ChatGPT collaborative discussion.
    Header simplified (capacity only). Two-tier creation API. Debug bounds
    checking. OQ-4 resolved (Element stays distinguished). Metadata-driven
    storage framing. Fixed-capacity invariant documented.
  - 2.0.0 (2026-02-07): Field-handle-based access pattern. Lane: ~Copyable.
    N-ary migration path. Informed by nary-soa-feasibility experiment.
  - 1.0.0 (2026-02-07): Initial design with Property-based lane accessor.
---
-->

## Context

The `metadata-parametric-slots` research (buffer-primitives) identified a need for `Buffer.Slots<Metadata, Payload>` — a fourth buffer discipline providing fixed-capacity, metadata-annotated, random-access slots. The initial design bypassed the Storage tier entirely, using `ManagedBuffer<Header, UInt8>` directly.

This bypass is **not acceptable**. The canonical layering is:

```
ADT → Buffer → Storage → Pointer
```

Queue, Array, and other current bypasses are known debt that will be resolved in the storage/buffer refactor. New types MUST NOT introduce additional bypasses. Every buffer discipline MUST consume a Storage primitive.

The problem: `Storage<Element>.Heap` is single-typed. Buffer.Slots needs **two types** (`Metadata` and `Payload`) in a single allocation with separate, typed lanes. No existing Storage type supports this.

**Trigger**: [RES-001] Investigation — the Storage tier is missing a fundamental variant, and the absence would force a bypass.

**Scope**: Per [RES-002a], this is package-specific to storage-primitives with cross-package implications (buffer-primitives consumes the result).

### Design Constraint: Anticipate N-ary Generalization

The `nary-soa-feasibility` experiment (2026-02-07) established that Swift parameter packs cannot currently suppress `~Copyable` (`each Field: ~Copyable` is a compiler error). However, this is a language limitation likely to be lifted in a future Swift release. The current binary design MUST anticipate N-ary generalization so that migration is a type-signature change, not an API redesign.

**Empirical basis**: The experiment validated 8 alternative approaches (C1–C8), confirming that field-handle-based access (C7) is the pattern that bridges binary and N-ary without call-site changes. See `Experiments/nary-soa-feasibility/`.

### Collaborative Review

This design was reviewed through a structured Claude-ChatGPT collaborative discussion (3 rounds, CONVERGED). The discussion confirmed the core architecture and refined:

1. **Header simplified** — field handles are the single source of layout truth; Header stores only `capacity`
2. **Two-tier creation** — `create(capacity:)` primitive + `create(capacity:laneInitial:)` convenience
3. **Debug bounds checking** — assertion in `pointer(field, at:)` mirroring `Storage.Heap`
4. **OQ-4 resolved** — Element stays distinguished in N-ary (defines index domain)
5. **Narrative framing** — "metadata-driven storage" to set correct consumer expectations
6. **Fixed-capacity invariant** — field handles valid for storage lifetime; no in-place resizing

See `/tmp/split-storage-design-transcript.md` for the full discussion transcript.

---

## Question

What is the principled design for a **metadata-driven** Storage type that provides **two typed lanes** in a single allocation, suitable as the substrate for `Buffer.Slots` and other dual-array structures, while anticipating generalization to N-ary when parameter packs support `~Copyable`?

### Sub-questions

- SQ1: What should the type be named?
- SQ2: What generic parameters does it take?
- SQ3: How does a consumer access each lane?
- SQ4: Should it track initialization, and if so, per-lane or combined?
- SQ5: What is the ManagedBuffer layout (element type, alignment, offset computation)?
- SQ6: Should there be an inline variant?
- SQ7: How does this relate to `Storage.Heap` — peer or generalization?
- SQ8: What is the migration path from binary to N-ary?

---

## Call-Site-First Design [IMPL-000]

Per [IMPL-000], we write the ideal expression first and work backward to the type.

### Ideal Buffer.Slots Implementation

```swift
// Buffer.Slots creates its storage:
let storage = Storage<Index<Element>>.Split<UInt8>.create(
    capacity: bucketCapacity,
    fill: \.lane, with: 0x80  // Swiss table EMPTY sentinel
)
// All lane slots initialized to 0x80.
// All element slots uninitialized.

// Field handles — the stable access abstraction:
let lane = storage.laneField          // Storage<Index<Element>>.Field<UInt8>
let element = storage.elementField    // Storage<Index<Element>>.Field<Index<Element>>

// Read/write lane (Copyable → subscript):
let ctrl = storage[lane, at: bucket]
storage[lane, at: bucket] = h2

// Read/write element (may be ~Copyable → pointer):
unsafe storage.pointer(element, at: bucket).initialize(to: position)
let pos = unsafe storage.pointer(element, at: bucket).pointee

// Bulk lane operations:
storage.fill(lane, with: 0x80)

// Contiguous lane pointer (SIMD access):
storage.withPointer(lane) { ctrl in
    let group = SIMD16<UInt8>(unsafePointer: ctrl + groupStart)
}
```

### What This Tells Us

The ideal call-site requires:

1. **Field handles** — `storage.laneField` and `storage.elementField` return Copyable, phantom-typed descriptors that carry offset/stride info. All access goes through handles.
2. **Uniform `pointer(field, at:)` method** — works for ANY field, both Copyable and ~Copyable values. This is the core primitive.
3. **Convenience `subscript[field, at:]`** — available when Value is Copyable. Syntactic sugar over `pointer`.
4. **Shared index domain** — both lanes use `Index<Element>`. The Element type defines the index domain.
5. **Bulk operations via handle** — `fill(field, with:)` takes a handle to identify which lane.
6. **Single allocation** — `create()` produces one ARC-managed object.

### Why Field Handles?

The previous design (v1.0.0) used named Property accessors:

```swift
// v1.0.0 (Property-based, binary-specific):
storage.lane.pointer(at: bucket)     // lane via Property accessor
storage.pointer(at: bucket)          // element via direct method
```

This doesn't generalize to N-ary. With three lanes, you'd need `storage.lane1`, `storage.lane2` — the accessor names are baked into the type. Field handles eliminate this:

```swift
// v2.0.0 (handle-based, generalizes to N-ary):
storage.pointer(lane, at: bucket)       // lane via handle
storage.pointer(element, at: bucket)    // element via handle — SAME METHOD
```

Both lanes use the **same `pointer` method** with different handles. When N-ary packs arrive, only handle acquisition changes (see SQ8). Access methods are unchanged.

---

## Analysis

### SQ1: Naming

#### Option N1: `Storage.Split<A, B>`

```swift
public enum Storage<Element: ~Copyable> {
    public enum Split<First: ~Copyable, Second: ~Copyable> {
        // But this puts Split inside Storage<Element>, creating Storage<Element>.Split<A, B>
        // with three generic parameters — Element is meaningless here
    }
}
```

**Problem**: `Storage<Element>` is already generic over `Element`. Nesting `Split` inside it creates `Storage<Element>.Split<A, B>` with `Element` as a phantom parameter that means nothing for split storage. This is structurally wrong.

#### Option N2: Top-level `Storage.Split<A, B>` via Protocol

Not applicable — Storage is an enum, not a protocol. We can't extend the namespace without the outer generic parameter.

#### Option N3: `Storage.Split` as a Non-Generic Namespace

```swift
extension Storage where Element == Never {
    public enum Split {}
}

extension Storage.Split {
    public final class Heap<First: ~Copyable, Second: ~Copyable>: ... { }
}
```

**Problem**: `Storage<Never>.Split` is valid Swift but semantically bizarre. `Never` as the element type is a type-level lie.

#### Option N4: Parallel Namespace

```swift
public enum SplitStorage<First: ~Copyable, Second: ~Copyable> {
    public final class Heap: ManagedBuffer<Header, UInt8> { ... }
}
```

**Problem**: Breaks [API-NAME-001] Nest.Name. `SplitStorage` is a compound name.

#### Option N5: `Storage.Heap.Split<A, B>` as a Peer

```swift
extension Storage.Heap {
    public final class Split<A, B>: ManagedBuffer<Header, UInt8> where Element == Never { ... }
}
```

**Problem**: `Storage<Never>.Heap.Split<A, B>` — same issue with the outer generic.

#### Option N6: `Storage<B>.Split<A>` — First Lane is the Extra

```swift
extension Storage {
    public final class Split<Lane: ~Copyable>: ManagedBuffer<Split.Header, UInt8> {
        // Lane: the annotation/metadata type
        // Element (from Storage<Element>): the primary/payload type
        // Index domain: Index<Element>
    }
}
```

**Insight**: This reuses the existing `Storage<Element>` generic parameter. `Element` IS the payload (the "primary" type that defines the index domain). `Lane` is the "annotation" type. The index domain `Index<Element>` is already correct.

**Usage**:
```swift
// Hash.Table storage:
var storage: Storage<Index<Element>>.Split<UInt8>
//                   ^^^^^^^^^^^^^^^^^  ^^^^^^
//                   Payload type        Metadata type
//                   (defines index)     (annotation lane)

// Access via field handles:
let lane = storage.laneField
let payload = storage.elementField
storage[lane, at: bucket] = h2
unsafe storage.pointer(payload, at: bucket).initialize(to: pos)
```

Wait — this is very interesting. `Storage<Element>` already defines the index domain as `Index<Element>`. Adding a `Split<Lane>` class inside the same namespace means:
- `Element` is the primary element type (payload), defining `Index<Element>`
- `Lane` is the secondary element type (metadata)
- The index domain `Index<Element>` is shared across both

The element field is accessed via `storage.pointer(storage.elementField, at:)`. The lane field is accessed via `storage.pointer(storage.laneField, at:)`. Same method, different handles.

This is elegant because:
1. The `Storage<Element>` generic parameter retains its meaning — it's the primary stored type
2. `Index<Element>` works unchanged
3. `pointer(field, at:)` is uniform across all fields
4. The naming is natural: `Storage<Payload>.Split<Metadata>`
5. The N-ary extension is `Storage<Element>.Split<each Lane>` — Element is still the primary type

**Naming consideration**: The class name `Split` inside `Storage<Element>` names the *structure* (split into lanes), not the *placement* (heap vs inline). This differs from `Heap`/`Inline` which name placement. However, "Split" describes a structural variant that can have both heap and inline placement — `Storage<E>.Split<L>` is heap-placed (ManagedBuffer), a future `Storage<E>.Split<L>.Inline<cap>` would be inline-placed.

#### Recommendation: N6 — `Storage<Element>.Split<Lane>`

N6 is the strongest option:

1. **Preserves `Storage<Element>` semantics**: `Element` defines the primary element type and index domain
2. **`Split<Lane>` adds the secondary lane**: The annotation/metadata type
3. **Index domain unchanged**: `Index<Element>` works for both lanes
4. **Nest.Name compliant**: `Storage.Split` is `Namespace.Name`
5. **Clear reading**: `Storage<Index<Element>>.Split<UInt8>` = "storage of element-indices, split with byte lane"
6. **N-ary ready**: `Storage<E>.Split<each Lane>` when packs support `~Copyable`
7. **Naming analysis**: See `split-storage-naming.md` — "Split" is supported by `DSPSplitComplex`, compiler literature, and PEP 412

Full type path: `Storage<Payload>.Split<Metadata>`

### SQ2: Generic Parameters

```swift
Storage<Element: ~Copyable>.Split<Lane: ~Copyable>
```

- **`Element`**: The primary element type. Defines the index domain `Index<Element>`. May be `~Copyable`.
- **`Lane`**: The secondary (annotation) element type. May be `~Copyable`.

#### Why `Lane: ~Copyable` (not `Lane: Copyable & Sendable`)

The v1.0.0 design constrained `Lane: Copyable & Sendable` because metadata is typically copyable (`UInt8`, `Int`, `Bool`). However, this constraint prevents N-ary generalization:

- When packs arrive, `Split<each Lane: ~Copyable>` treats all lanes uniformly
- If the binary version constrains `Lane: Copyable`, the migration to packs would be a breaking change — existing code that relied on Copyable lane access would need updating
- `~Copyable` on Lane means the type ACCEPTS both Copyable and ~Copyable lanes
- Convenience methods (`subscript`, `fill`) are gated on `Value: Copyable` — available when the lane IS Copyable, unavailable when it isn't

The practical impact is zero: existing consumers pass `UInt8` (Copyable), which satisfies `~Copyable`. All convenience methods remain available. But the type is forward-compatible with the pack generalization.

### SQ3: Field-Handle-Based Access

#### `Storage<Element>.Field<Value>` — The Stable Abstraction

```swift
extension Storage where Element: ~Copyable {
    /// A typed field handle describing the position of a `Value` array within a split storage.
    ///
    /// Field handles are:
    /// - **Copyable and Sendable** — always, regardless of Value's copyability
    /// - **Phantom-tagged** — scoped to `Storage<Element>`, preventing cross-storage misuse
    /// - **Instance-specific** — offset depends on the storage's capacity
    ///
    /// Structural analog: `SoAField` from `nary-soa-feasibility` experiment (C7).
    public struct Field<Value: ~Copyable>: Copyable, Sendable {
        /// Byte offset from the buffer base to the start of this field's array.
        public let offset: Int
        /// Byte stride between consecutive elements of this field.
        public let stride: Int

        @inlinable
        init(offset: Int, stride: Int) {
            self.offset = offset
            self.stride = stride
        }
    }
}
```

**Key properties**:
- `Field<Value: ~Copyable>: Copyable` — the handle is ALWAYS Copyable, even when Value is ~Copyable. This is the same pattern as `FieldDescriptor<T: ~Copyable>: Copyable` (C6 experiment).
- Phantom-tagged by `Element` — a `Storage<Int>.Field<UInt8>` can't be used with a `Storage<String>.Split<UInt8>`.
- Carries offset/stride — computed at init time, deterministic for a given capacity and type.

#### Core Access Methods

```swift
extension Storage.Split where Element: ~Copyable, Lane: ~Copyable {
    /// The field handle for the lane (secondary) array.
    @inlinable
    public var laneField: Storage.Field<Lane> { get }

    /// The field handle for the element (primary) array.
    @inlinable
    public var elementField: Storage.Field<Element> { get }

    /// Returns a mutable pointer to the value at the given slot in the given field.
    ///
    /// This is the core access primitive. ALL other access methods delegate to this.
    @unsafe
    @inlinable
    public func pointer<Value: ~Copyable>(
        _ field: Storage.Field<Value>, at slot: Index<Element>
    ) -> UnsafeMutablePointer<Value>
}
```

#### Copyable Convenience

```swift
extension Storage.Split where Element: ~Copyable, Lane: ~Copyable {
    /// Subscript access for Copyable field values.
    @inlinable
    public subscript<Value: Copyable>(
        _ field: Storage.Field<Value>, at slot: Index<Element>
    ) -> Value {
        get { unsafe pointer(field, at: slot).pointee }
        set { unsafe pointer(field, at: slot).pointee = newValue }
    }

    /// Fills all slots of the given field with the given value.
    @inlinable
    public func fill<Value: Copyable>(
        _ field: Storage.Field<Value>, with value: Value
    ) {
        let cap = Int(bitPattern: header.capacity)
        unsafe pointer(field, at: .zero).initialize(repeating: value, count: cap)
    }

    /// Calls body with a pointer to the contiguous array of the given field.
    @inlinable
    public func withPointer<Value: Copyable, R>(
        _ field: Storage.Field<Value>,
        _ body: (UnsafePointer<Value>) throws(E) -> R
    ) throws(E) -> R {
        try body(unsafe UnsafePointer(pointer(field, at: .zero)))
    }
}
```

#### Why This Generalizes

The access methods take a `Storage.Field<Value>` handle and an `Index<Element>` slot. They don't know or care which field they're accessing — lane or element, first or fifth. When N-ary packs arrive:

- `pointer(field, at:)` — **unchanged**
- `subscript[field, at:]` — **unchanged**
- `fill(field, with:)` — **unchanged**
- `withPointer(field)` — **unchanged**

Only handle acquisition changes (see SQ8).

### SQ4: Initialization Tracking

#### What Each Lane Needs

| Lane | Initialization at Creation | Lifecycle | Tracking |
|------|---------------------------|-----------|----------|
| Lane (annotation) | Bulk-initialized with caller-supplied value (when Copyable) | Always initialized; overwrite-semantic | None needed — always full |
| Element (primary) | Uninitialized | Consumer-managed via lane interpretation | Consumer's responsibility |

The annotation lane is **always fully initialized** (when Copyable — the common case). It starts with a sentinel value (e.g., `0x80` for Swiss table EMPTY) and is overwritten as slots are used. There is never a "partially initialized" annotation lane.

The element lane follows the same model as `Buffer.Slots` R4: **no Storage-level initialization tracking**. The consumer uses the annotation lane to determine which element slots are valid.

#### What This Means for Storage.Initialization

`Storage.Initialization` (.empty, .one, .two) does not apply to `Storage.Split`:
- The annotation lane is always `.linear(count: capacity)` — tracking this is pointless
- The element lane's initialization is metadata-driven, not range-driven — `Storage.Initialization` cannot express "slots 0, 3, 7, 12 are initialized"

**Recommendation**: `Storage.Split` does NOT provide `Storage.Initialization`. Its Header contains only `capacity`. This is principled — the absence of initialization tracking is not a gap but a design choice matching the overwrite-semantic / consumer-managed model.

**Narrative framing**: `Storage.Split` is **metadata-driven storage**. The consumer determines slot validity through the metadata (lane) values, not through storage-managed state. This distinguishes it from `Storage.Heap`, which tracks initialization ranges internally. Documentation should frame this distinction explicitly to prevent consumers from expecting `Storage.Initialization`-style APIs.

#### deinit Behavior

`Storage.Heap.deinit` iterates `initialization.forEach` to deinitialize elements. `Storage.Split.deinit` must:

1. **Lane**: When Lane is `BitwiseCopyable` (UInt8, Int), deinit is a no-op. When Lane is Copyable but non-trivial, deinit each slot. Since the lane is always fully initialized, this is `deinitializeAll(count: capacity)`. When Lane is `~Copyable`, the consumer must deinitialize lane slots before dropping.

2. **Element**: The storage does NOT know which element slots are initialized. The consumer must call a cleanup method before dropping the storage. For `Copyable` and `BitwiseCopyable` elements (the common case — `Int`, `Index<Element>`), no deinit is needed.

This is correct for a primitives-tier type. The consumer knows the metadata interpretation; the storage doesn't.

### SQ5: ManagedBuffer Layout

```
ManagedBuffer<Split.Header, UInt8>

Allocation layout (in the UInt8 elements region):
┌─────────────────────────────────────────────────────────────────┐
│ Lane_0 │ Lane_1 │ ... │ Lane_{n-1} │ [padding] │ Elem_0 │ ... │
└─────────────────────────────────────────────────────────────────┘
│←── n × stride(Lane) ──→│←─ align ─→│←── n × stride(Element) ─→│
```

The element type of the ManagedBuffer is `UInt8` (raw bytes). The actual typed regions are computed as offsets:

```swift
extension Storage.Split where Element: ~Copyable, Lane: ~Copyable {
    /// Computes the byte offset where the element region begins.
    @inlinable
    static func elementRegionOffset(capacity: Int) -> Int {
        let laneBytes = capacity * MemoryLayout<Lane>.stride
        let elementAlignment = MemoryLayout<Element>.alignment
        // Round up to element alignment
        return (laneBytes + elementAlignment - 1) & ~(elementAlignment - 1)
    }

    /// Total bytes needed for the raw elements region.
    @inlinable
    static func totalBytes(capacity: Int) -> Int {
        elementRegionOffset(capacity: capacity) + capacity * MemoryLayout<Element>.stride
    }
}
```

#### Two-Tier Creation API

The creation API is split into a primitive (always available) and a convenience (requires `Lane: Copyable`):

```swift
// Primitive — always available:
extension Storage.Split where Element: ~Copyable, Lane: ~Copyable {
    /// Creates a split storage with the given capacity.
    /// Both lanes are uninitialized. The consumer must initialize before use.
    @inlinable
    public static func create(
        capacity: Index<Element>.Count
    ) -> Storage.Split {
        let cap = Int(bitPattern: capacity)
        let totalBytes = Self.totalBytes(capacity: cap)

        let storage = Self.create(minimumCapacity: totalBytes) { _ in
            Header(capacity: capacity)
        }

        return unsafe unsafeDowncast(storage, to: Storage.Split.self)
    }
}

// Convenience — requires Lane: Copyable for bulk fill:
extension Storage.Split where Element: ~Copyable, Lane: Copyable {
    /// Creates a split storage with the given capacity, bulk-initializing the lane.
    /// Lane slots are initialized to `laneInitial`. Element slots are uninitialized.
    @inlinable
    public static func create(
        capacity: Index<Element>.Count,
        laneInitial: Lane
    ) -> Storage.Split {
        let split = Self.create(capacity: capacity)
        let cap = Int(bitPattern: capacity)

        // Initialize all lane slots
        let laneField = split.laneField
        unsafe split.pointer(laneField, at: .zero).initialize(
            repeating: laneInitial,
            count: cap
        )

        return split
    }
}
```

The convenience delegates to the primitive, then fills the lane. When `Lane` is `~Copyable`, only the primitive is available — the consumer must initialize lane slots individually.

### SQ6: Inline Variant

An inline variant (`Storage<E>.Split<L>.Inline<capacity>`) would compose `@_rawLayout` fields — the C5 experiment confirmed this works:

```swift
@_rawLayout(likeArrayOf: A, count: capacity)
struct RawField<A: ~Copyable, let capacity: Int>: ~Copyable {}

struct InlineSplit<A: ~Copyable, B: ~Copyable, let capacity: Int>: ~Copyable {
    var _fieldA: RawField<A, capacity>
    var _fieldB: RawField<B, capacity>
}
// InlineSplit<UInt8, Int, 4> = 40 bytes (verified)
```

**Assessment**: Legitimate but lower priority. The heap-backed variant serves the primary consumer (Hash.Table). The inline variant should be designed after the heap variant is proven.

### SQ7: Relationship to Storage.Heap

`Storage.Split` is a **peer** to `Storage.Heap`, not a generalization:

| Aspect | `Storage.Heap` | `Storage.Split` |
|--------|---------------|----------------|
| Element types | One (`Element`) | Two (`Lane` + `Element`) |
| Index domain | `Index<Element>` | `Index<Element>` (shared) |
| Initialization tracking | `Storage.Initialization` | None (consumer-managed) |
| Access primitive | `pointer(at:)` | `pointer(field, at:)` |
| Lifecycle | ARC-managed, deinit cleans up via tracking | ARC-managed, consumer must clean up elements |
| ManagedBuffer element | `Element` | `UInt8` (raw bytes with typed overlay) |
| N-ary path | N/A (single-typed) | `Split<each Lane>` when packs support ~Copyable |

The access pattern differs: `Storage.Heap` has a single `pointer(at:)` because there's only one field. `Storage.Split` has `pointer(field, at:)` because there are multiple fields. Both return `UnsafeMutablePointer<V>` to the value at the given slot.

`Storage.Split` does NOT subsume `Storage.Heap`:
- `Storage.Heap` provides initialization tracking — essential for Linear/Ring/Slab buffers
- `Storage.Split` does not — appropriate for metadata-driven buffers
- Using `Storage.Split<Never, Element>` to emulate `Storage.Heap` would lose initialization tracking

### SQ8: N-ary Migration Path

When parameter packs support `~Copyable`, the migration from binary to N-ary is:

#### Type Signature Change

```swift
// Binary (today):
final class Split<Lane: ~Copyable>: ManagedBuffer<Split.Header, UInt8> { ... }

// N-ary (future):
final class Split<each Lane: ~Copyable>: ManagedBuffer<Split.Header, UInt8> { ... }
```

#### Handle Acquisition Change

```swift
// Binary (today):
let lane = storage.laneField          // Storage.Field<Lane>
let element = storage.elementField    // Storage.Field<Element>

// N-ary (future):
let (ctrl, hash) = storage.laneFields // (Storage.Field<UInt8>, Storage.Field<Int>)
let element = storage.elementField    // Storage.Field<Element> — unchanged
```

The `laneField` property becomes `laneFields` returning a tuple. Destructuring gives named handles.

#### Access Methods — UNCHANGED

```swift
// Binary AND N-ary — identical:
storage.pointer(lane, at: slot)        // ~Copyable access
storage[lane, at: slot]                // Copyable subscript
storage.fill(lane, with: sentinel)     // Copyable bulk fill
storage.withPointer(lane) { ptr in }   // Contiguous access
```

The `pointer`, `subscript`, `fill`, and `withPointer` methods take a `Storage.Field<Value>` handle. They don't know or care whether the storage has 1 lane or 5 lanes. This is the key invariant that makes the migration non-breaking for call sites.

#### Summary of Changes

| Aspect | Binary → N-ary | Call-site impact |
|--------|---------------|-----------------|
| Type annotation | `Split<Lane>` → `Split<each Lane>` | Type declarations only |
| Handle acquisition | `.laneField` → `.laneFields.0` or destructure | Handle binding site only |
| `pointer(field, at:)` | unchanged | **None** |
| `subscript[field, at:]` | unchanged | **None** |
| `fill(field, with:)` | unchanged | **None** |
| `withPointer(field)` | unchanged | **None** |
| `create()` | Signature changes for N lane initializers | Factory call only |

---

## Proposed Type Hierarchy

```swift
public enum Storage<Element: ~Copyable> {
    // Existing:
    public final class Heap: ManagedBuffer<Heap.Header, Element> { ... }
    public struct Inline<let capacity: Int>: ~Copyable { ... }

    // New — field handle:
    public struct Field<Value: ~Copyable>: Copyable, Sendable {
        public let offset: Int
        public let stride: Int
    }

    // New — metadata-driven split storage:
    /// Field handles are valid for the lifetime of the storage instance.
    /// `Storage.Split` is fixed-capacity and is never resized in place.
    /// Consumers requiring growth must allocate a new `Storage.Split` and
    /// copy fields individually.
    public final class Split<Lane: ~Copyable>: ManagedBuffer<Split.Header, UInt8> {
        public struct Header: Sendable {
            public let capacity: Index<Element>.Count
        }
    }
}
```

### Header

```swift
extension Storage.Split where Element: ~Copyable, Lane: ~Copyable {
    public struct Header: Sendable {
        /// Total slot capacity (same for both lanes).
        public let capacity: Index<Element>.Count

        @inlinable
        public init(capacity: Index<Element>.Count) {
            self.capacity = capacity
        }
    }
}
```

The Header stores only `capacity`. Layout offsets are computed by field handles on demand — field handles are the single source of layout truth (see "Field Handle Construction" below). This avoids dual-authority between Header and handles, and simplifies N-ary generalization (N handles, zero header offset fields).

### Field Handle Construction

Field handles derive offsets deterministically from `header.capacity` and type layout. Consumers should capture handles once and reuse them — the computation is a few integer ops (one multiply, one alignment round-up) but capturing avoids redundant work.

```swift
extension Storage.Split where Element: ~Copyable, Lane: ~Copyable {
    @inlinable
    public var laneField: Storage.Field<Lane> {
        Storage.Field<Lane>(
            offset: 0,
            stride: MemoryLayout<Lane>.stride
        )
    }

    @inlinable
    public var elementField: Storage.Field<Element> {
        let cap = Int(bitPattern: header.capacity)
        let laneBytes = cap * MemoryLayout<Lane>.stride
        let align = MemoryLayout<Element>.alignment
        let offset = (laneBytes + align - 1) & ~(align - 1)
        return Storage.Field<Element>(
            offset: offset,
            stride: MemoryLayout<Element>.stride
        )
    }
}
```

**Usage pattern** — capture once, reuse throughout:
```swift
let lane = storage.laneField       // computed once
let element = storage.elementField // computed once
// then reuse `lane` and `element` for all access
```

### Pointer Implementation

```swift
extension Storage.Split where Element: ~Copyable, Lane: ~Copyable {
    @unsafe
    @inlinable
    public func pointer<Value: ~Copyable>(
        _ field: Storage.Field<Value>, at slot: Index<Element>
    ) -> UnsafeMutablePointer<Value> {
        let slotIndex = Int(bitPattern: Index<Element>.Offset(fromZero: slot))
        assert(
            slotIndex >= 0 && slotIndex < Int(bitPattern: header.capacity),
            "Storage.Split: slot \(slotIndex) out of bounds for capacity \(header.capacity)"
        )
        return unsafe withUnsafeMutablePointerToElements { base in
            UnsafeMutableRawPointer(base)
                .advanced(by: field.offset + slotIndex * field.stride)
                .assumingMemoryBound(to: Value.self)
        }
    }
}
```

The debug-only bounds assertion mirrors `Storage.Heap`'s approach — safety in debug builds, zero overhead in release. The check validates the slot against capacity (shared across all fields), not against a field-specific bound.

### File Organization [API-IMPL-005]

```
swift-storage-primitives/Sources/
  Storage Primitives Core/
    Storage.swift                              → existing
    Storage.Field.swift                       → struct Storage.Field<Value>
    Storage.Split.swift                       → class Storage.Split<Lane>
    Storage.Split.Header.swift                → struct Storage.Split.Header

  Storage Split Primitives/                   → new module (or extend existing)
    Storage.Split ~Copyable.swift             → create, pointer(field:at:), slotCapacity
    Storage.Split Copyable.swift              → subscript, fill, withPointer, copy operations
```

---

## Dependency Impact

`Storage.Split` adds **no new dependencies** beyond what storage-primitives already imports:
- `Index_Primitives` — `Index<Element>`, `Index<Element>.Count`
- `Bit_Vector_Primitives` — NOT needed (no bitmap tracking)

The `fill` method uses stdlib's `UnsafeMutablePointer.initialize(repeating:count:)` for bulk fill — no additional primitives needed.

---

## Integration with Buffer.Slots

After this research, `Buffer.Slots` in buffer-primitives consumes `Storage.Split`:

```swift
extension Buffer.Slots {
    public struct Fixed: ~Copyable {
        public var header: Header
        public var storage: Storage<Payload>.Split<Metadata>

        // Field handles — captured once per instance, reused throughout.
        // Avoids recomputing offset on every access.
        private let metaField: Storage<Payload>.Field<Metadata>
        private let payloadField: Storage<Payload>.Field<Payload>

        public init(capacity: Index<Payload>.Count, metadataInitial: Metadata) {
            self.header = Header(capacity: capacity)
            self.storage = Storage<Payload>.Split<Metadata>.create(
                capacity: capacity,
                laneInitial: metadataInitial
            )
            // Capture handles once at init
            self.metaField = storage.laneField
            self.payloadField = storage.elementField
        }

        // Metadata access — via handle:
        public func metadata(at slot: Index<Payload>) -> Metadata {
            storage[metaField, at: slot]
        }
        public func setMetadata(_ value: Metadata, at slot: Index<Payload>) {
            storage[metaField, at: slot] = value
        }

        // Payload access — via handle:
        public func payload(at slot: Index<Payload>) -> Payload where Payload: Copyable {
            unsafe storage.pointer(payloadField, at: slot).pointee
        }

        // SIMD access — via handle:
        public func withMetadataPointer<R>(_ body: (UnsafePointer<Metadata>) -> R) -> R {
            storage.withPointer(metaField, body)
        }
    }
}
```

The layering is clean:

```
Hash.Table → Buffer.Slots → Storage.Split → ManagedBuffer
                                ↑
                          Storage tier (Tier 12)
```

No bypass.

---

## Empirical Validation (Cognitive Dimensions)

| Dimension | Assessment | Rationale |
|-----------|------------|-----------|
| **Visibility** | HIGH | `Storage<Payload>.Split<Metadata>` immediately communicates: split storage with typed lanes. Field handles are discoverable via `.laneField` / `.elementField`. |
| **Consistency** | HIGH | `pointer(field, at:)` is the uniform access method for all fields. Subscript and fill are gated on Copyable — consistent with stdlib patterns. |
| **Viscosity** | LOW | Adding a new consumer requires only choosing `Lane` and `Element` types. N-ary migration changes type signatures, not access patterns. |
| **Role-expressiveness** | HIGH | `Storage<Index<Element>>.Split<UInt8>` reads as "storage of element-indices, split with byte lane." Field handles carry their Value type visibly. |
| **Error-proneness** | LOW | Field handles are phantom-tagged — can't mix handles from `Storage<Int>` with `Storage<String>`. Copyable/~Copyable access is enforced at compile time (subscript vs pointer). |
| **Abstraction** | APPROPRIATE | Minimal: dual-array layout + field handles + typed pointers. Does not impose initialization tracking, growth policy, or interpretation semantics. |

---

## Comparison

| Criterion | Storage.Heap | Storage.Split (v3.0) | ManagedBuffer (bypass) |
|-----------|-------------|---------------------|----------------------|
| Typed coordinates | Index\<Element\> | Index\<Element\> (shared) | Manual |
| Init tracking | Storage.Initialization | None (principled) | Manual |
| Access primitive | `pointer(at:)` | `pointer(field, at:)` | Manual |
| N-ary path | N/A | `Split<each Lane>` | N/A |
| Single allocation | Yes | Yes | Yes |
| Dual-typed lanes | No | Yes | Manual |
| Layering preserved | Yes | Yes | **NO** |
| SIMD-friendly lane | N/A | Yes (`withPointer(field)`) | Manual |
| ~Copyable lanes | Yes (Element) | Yes (both) | Manual |
| Field handle pattern | N/A | Yes | N/A |

---

## Outcome

**Status**: RECOMMENDATION

### Recommendation

Introduce `Storage<Element>.Split<Lane>` with field-handle-based access:

1. **Name**: `Storage<Element>.Split<Lane>` — `Element` is the primary type (defines index domain), `Lane` is the annotation type. See `split-storage-naming.md` for literature analysis.
2. **Constraint**: `Lane: ~Copyable` (anticipates N-ary pack generalization)
3. **Layout**: Single `ManagedBuffer<Header, UInt8>` with `[lane...][padding][elements...]`
4. **Header**: Stores only `capacity: Index<Element>.Count`. No offset fields — layout is derived by field handles on demand.
5. **Field handle**: `Storage<Element>.Field<Value: ~Copyable>: Copyable, Sendable` — typed descriptor carrying offset/stride. Single source of layout truth.
6. **Core access**: `pointer(_ field: Storage.Field<V>, at: Index<Element>)` — uniform for all fields. Includes debug-only bounds assertion.
7. **Subscript order**: `storage[field, at: slot]` — field-first, documented as field-qualified access (not collection subscript).
8. **Copyable convenience**: `subscript[field, at:]`, `fill(field, with:)`, `withPointer(field)` — gated on `Value: Copyable`
9. **Creation**: Two-tier — `create(capacity:)` primitive (always available) + `create(capacity:laneInitial:)` convenience (requires `Lane: Copyable`)
10. **No initialization tracking**: Principled absence — metadata-driven storage. The consumer determines slot validity through lane values, not storage-managed state.
11. **Fixed-capacity invariant**: Field handles are valid for the lifetime of the storage instance. No in-place resizing. Growth requires new allocation + copy.
12. **N-ary migration**: `Split<Lane>` → `Split<each Lane>`. Handle acquisition changes; access methods unchanged. Element stays distinguished.

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Field handles over named accessors | Generalizes to N-ary without API change |
| `Lane: ~Copyable` over `Lane: Copyable` | Forward-compatible with pack generalization |
| `Storage.Field` as nested type | Phantom-tagged by Element; co-located with Storage namespace |
| Uniform `pointer(field, at:)` | Single method for all fields, both Copyable and ~Copyable |
| Element remains primary | Index domain is `Index<Element>`; asymmetry is semantic, not accidental |
| Header stores only capacity | Field handles are the single layout authority; avoids dual-authority with Header |
| Field-first subscript order | Field-qualified access pattern, not collection subscript |
| Two-tier creation | Primitive always available; convenience gated on Lane: Copyable |
| Debug bounds checking | Mirrors Storage.Heap; debug safety, release performance |
| Metadata-driven framing | Sets correct consumer expectations; prevents init-tracking misuse |

### Open Questions

| # | Question | Status |
|---|----------|--------|
| OQ-1 | Should the `fill` convenience also accept a `Range<Index<Element>>` for partial fills? | OPEN |
| OQ-2 | Should `pointer(field, at:)` bounds-check against capacity in debug builds? | **RESOLVED** — Yes, debug-only bounds assertion |
| OQ-3 | Should `Storage.Split.Inline<capacity>` exist alongside the heap variant? (C5 experiment confirms feasibility) | DEFERRED |
| OQ-4 | When packs support `~Copyable`, should Element become just another field (fully symmetric) or remain distinguished? | **RESOLVED** — Element stays distinguished (defines index domain). Asymmetry is semantic. |

### Verification Plan

- [x] Experiment: `nary-soa-feasibility` — validates field handle pattern (C7), ~Copyable access, N-ary layout computation
- [ ] Experiment: Implement `Storage<Int>.Split<UInt8>` with field handles, verify pointer access compiles
- [ ] Experiment: Verify alignment of element region for various Lane/Element stride combinations
- [ ] Experiment: Instantiate `Storage<Index<Element>>.Split<UInt8>`, verify SIMD-compatible lane pointer via handle
- [ ] Audit: Verify `pointer(field, at:)` uses `Index<Element>.Offset` consistently

---

## References

### Internal
- `split-storage-naming.md` (storage-primitives) — naming literature analysis
- `metadata-parametric-slots.md` (buffer-primitives) — upstream consumer research
- `hash-table-storage-buffer-layering.md` (hash-table-primitives) — original motivation
- `theoretical-buffer-primitives-design.md` (buffer-primitives) — three-discipline design establishing the Storage → Buffer → ADT layering
- `storage-primitives-comparative-analysis.md` (swift-primitives) — Tier 3 evaluation of storage-primitives
- `storage-ownership-reference-synthesis.md` (storage-primitives) — conceptual model, canonical primitives

### Experiments
- `nary-soa-feasibility` (storage-primitives) — N-ary SoA feasibility: packs, fixed-arity, HList, schema, field handles. Validates C7 field-handle pattern as the stable access abstraction.

### Collaborative Discussion
- `split-storage-design-transcript.md` — 3-round Claude-ChatGPT discussion, CONVERGED. Resolved header simplification, two-tier creation, debug bounds checking, OQ-4, metadata-driven framing.

### Patterns
- [IMPL-000] Call-Site-First Design — ideal expression drives the type design
- [IMPL-011] Pointer Primitives — `pointer(at:)` as fundamental slot access
- [API-NAME-001] Nest.Name — `Storage.Split` naming compliance
- [API-IMPL-005] One Type Per File — file organization
