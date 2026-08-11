# Static vs Cyclic Variant Naming Analysis

<!--
---
version: 2.0.0
last_updated: 2026-01-29
status: DECISION
tier: 3
collaborative_review: Claude + ChatGPT (2026-01-29)
---
-->

## Context

The swift-set-primitives package contains inline storage variants with compile-time known capacity:

- `Set.Ordered.Static<let capacity: Int>`
- `Set<Bit>.Vector.Static<let wordCount: Int>`

These variants can use `Index.Cyclic<N>` for wrap-around index arithmetic. The question is whether the variant name should reflect the cyclic capability (`.Cyclic<N>`) or the storage characteristic (`.Static<N>`).

## Question

Should `.Static<N>` variants be renamed to `.Cyclic<N>` to reflect their cyclic index capability?

## Research Tier

**Tier 3: Deep Analysis**

This decision establishes long-lived semantic contracts affecting the entire primitives ecosystem. The naming pattern will propagate to Array, Set, and potentially other collection types.

---

## 1. Prior Art Survey

### 1.1 Mathematics: Cyclic Groups ℤ/nℤ

The mathematical foundation is the cyclic group ℤ/nℤ (integers modulo n) [Cyclic group - Wikipedia](https://en.wikipedia.org/wiki/Cyclic_group):

- Standard notations: ℤ/nℤ, ℤ/n, ℤ/(n), Cₙ
- Elements form a cyclic group under addition with modular wrapping
- Every finite cyclic group G is isomorphic to ℤ/nZ where n = |G|

**Key observation**: Mathematical nomenclature uses "cyclic" to describe the **algebraic structure**, not the elements themselves. The group is cyclic; indices are elements of the group.

### 1.2 Data Structures: Ring Buffers

From [Circular buffer - Wikipedia](https://en.wikipedia.org/wiki/Circular_buffer):

> "A circular buffer, circular queue, cyclic buffer or ring buffer is a data structure that uses a single, fixed-size buffer as if it were connected end-to-end."

Four names coexist: circular, cyclic, ring, buffer. The terminology describes the **access pattern**, not the storage.

**Key observation**: "Cyclic" describes how indices wrap, not how data is stored.

### 1.3 C++: static_vector → inplace_vector

The C++ standardization process for fixed-capacity inline vectors [P0843](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2023/p0843r8.html) considered these names:

| Name | Emphasis | Rejection Reason |
|------|----------|------------------|
| `static_vector` | Compile-time allocation | "static" overloaded (static storage duration, static member) |
| `fixed_capacity_vector` | Fixed capacity | Verbose |
| `bounded_vector` | Bounded size | Unclear what is bounded |
| `inline_vector` | Inline storage | "inline" overloaded (inline functions, inlining) |
| `stack_vector` | Stack allocation | Misleading (can be heap member) |
| `embedded_vector` | Embedded storage | "embedded" overloaded (embedded systems) |
| **`inplace_vector`** | In-place storage | **Selected in C++26** |

LEWG chose `inplace_vector` because it describes **where elements are stored** without semantic overload.

**Key observation**: C++ prioritized storage location over other characteristics.

### 1.4 Rust: ArrayVec and SmallVec

The Rust ecosystem uses:

- [`ArrayVec<T, CAP>`](https://docs.rs/arrayvec/latest/arrayvec/): Fixed-capacity array-backed vector
- [`SmallVec<A>`](https://docs.rs/smallvec/latest/smallvec/): Hybrid inline/heap vector

Both names describe **storage mechanism**, not access patterns.

### 1.5 Swift Evolution: InlineArray (SE-0453)

The Swift Language Steering Group chose `InlineArray` over `Vector` and `FixedSizeArray` [SE-0453](https://forums.swift.org/t/accepted-with-modifications-se-0453-inlinearray-formerly-vector-a-fixed-size-array/77678):

> "The name InlineArray was favored because it makes clear that the storage is inline, which is the most important characteristic of this type."

Rationale:
1. **Storage model matters for performance**: Inline storage means eager copying, not copy-on-write
2. **Fixed size is self-evident**: Compiler errors reveal size constraints
3. **"Vector" is overloaded**: Different meanings across language communities

**Key observation**: Swift prioritized communicating **performance-relevant storage characteristics** over other properties.

---

## 2. Formal Semantics

### 2.1 Type Structure

The current type hierarchy:

```
Set.Ordered.Static<let capacity: Int>
├── Element: Hash.Protocol & ~Copyable
├── Capacity: compile-time constant
└── Index: Index<Element> (linear, not cyclic)

Index.Cyclic<let N: Int>
├── RawValue: Cyclic.Group<N>.Element
├── Arithmetic: wraps modulo N
└── Precondition: N must match container capacity
```

### 2.2 The Cyclic Index Compatibility Principle

For a container to use `Index.Cyclic<N>`, the capacity must be:
1. Known at compile time (embedded in type)
2. Equal to N

This principle determines which variants can use cyclic indices:

| Variant | Capacity | Can Use Index.Cyclic<N>? |
|---------|----------|--------------------------|
| `.Static<N>` | Compile-time, equals N | Yes |
| `.Fixed` | Runtime | No |
| `.Small<N>` | Initially N, can grow | Partially (before growth) |
| Base (growable) | Dynamic | No |

### 2.3 Semantic Invariants

**Current naming (`.Static<N>`)**:
- Describes storage: inline, compile-time sized
- **Derived property**: Can use cyclic indices (not stated in name)

**Proposed naming (`.Cyclic<N>`)**:
- Describes capability: cyclic index access
- **Derived property**: Has inline storage (not stated in name)

---

## 3. Cognitive Dimensions Analysis

Using the [Cognitive Dimensions Framework](https://www.ppig.org/files/2003-PPIG-15th-clarke.pdf) adapted for API usability:

### 3.1 Abstraction Level

| Name | Abstraction | Evaluation |
|------|-------------|------------|
| `.Static<N>` | Implementation (storage) | Lower abstraction |
| `.Cyclic<N>` | Capability (access pattern) | Higher abstraction |

**Finding**: `.Cyclic<N>` operates at a higher abstraction level, describing what you can **do** rather than **how it's stored**.

### 3.2 Role-Expressiveness

**Question**: Does the name convey why you would choose this type?

- `.Static<N>`: "I want inline storage" → Storage optimization use case
- `.Cyclic<N>`: "I want wrap-around indices" → Ring buffer use case

**Finding**: Both are expressive for different use cases. Most users want inline storage; fewer specifically need cyclic indices.

### 3.3 Consistency

**Within swift-primitives**:
- `Cyclic.Group<N>.Element` — algebraic type, correctly named
- `Index.Cyclic<N>` — index type, correctly named
- `Set.Ordered.Static<N>` → `Set.Ordered.Cyclic<N>` — container type?

**Concern**: Container is not cyclic; it's the index that's cyclic. The container has fixed inline storage that *enables* cyclic indexing.

### 3.4 Error-Proneness

**Misleading implications of `.Cyclic<N>`**:
1. Suggests iteration wraps (it doesn't — iteration is linear)
2. Suggests all access is cyclic (it isn't — subscripts don't wrap)
3. Suggests circular buffer semantics (FIFO with wrap — not what this is)

**Example confusion**:
```swift
let set = Set<Int>.Ordered.Cyclic<4>()  // Is this a ring buffer?
for element in set { ... }              // Does this wrap?
set[5]                                  // Does this wrap to set[1]?
```

None of these wrap. Only `Index.Cyclic<N>` arithmetic wraps.

---

## 4. Analysis of Options

### Option A: Keep `.Static<N>`

**Advantages**:
1. **Accurate**: Describes what the container **is** (inline, static-capacity)
2. **Consistent with C++/Rust/Swift stdlib**: All use storage-focused naming
3. **Non-misleading**: Doesn't imply circular buffer semantics
4. **Array alignment**: Matches `Array.Static<N>` naming

**Disadvantages**:
1. **Doesn't advertise cyclic capability**: Users must discover it
2. **"Static" overload**: Could be confused with Swift `static` keyword

### Option B: Rename to `.Cyclic<N>`

**Advantages**:
1. **Advertises capability**: Users know they can use cyclic indices
2. **Higher abstraction**: Describes purpose, not implementation
3. **Type alignment**: Matches `Index.Cyclic<N>` naming

**Disadvantages**:
1. **Misleading**: Suggests the container itself has cyclic behavior
2. **Not all uses are cyclic**: Most uses don't need wrap-around
3. **Semantic mismatch**: Container isn't cyclic; index arithmetic is
4. **Prior art conflict**: No major language/library uses "cyclic" for containers
5. **Array misalignment**: `Array.Cyclic<N>` sounds like a ring buffer, not a fixed-size array

### Option C: Use `.Inline<N>` (matching Swift SE-0453)

**Advantages**:
1. **Matches Swift stdlib**: `InlineArray` precedent
2. **Describes storage**: Clear, well-defined meaning
3. **Non-overloaded in Swift context**: Unlike "static"

**Disadvantages**:
1. **Already used**: `Array.Inline<N>` is a typealias to `Swift.InlineArray`
2. **Conflict**: Can't have both a type and typealias with same name

### Option D: Add `.Ring<N>` as Ring Buffer Type

Instead of renaming, add a purpose-built ring buffer type:

```swift
Set.Ordered.Ring<let capacity: Int>
// or
RingBuffer<Element, let capacity: Int>
```

**Advantages**:
1. **Purpose-specific**: Clear ring buffer semantics
2. **Preserves `.Static<N>`**: No breaking change
3. **Appropriate naming**: "Ring" correctly describes circular access

**Disadvantages**:
1. **Different scope**: This is a feature request, not a naming question
2. **Orthogonal**: Ring buffers need different APIs (enqueue/dequeue)

---

## 5. Evaluation Matrix

| Criterion | Weight | Static | Cyclic | Notes |
|-----------|--------|--------|--------|-------|
| Semantic accuracy | High | ★★★★★ | ★★☆☆☆ | Container is not cyclic |
| Prior art alignment | High | ★★★★★ | ★☆☆☆☆ | All prior art uses storage naming |
| Non-misleading | High | ★★★★☆ | ★★☆☆☆ | Cyclic implies iteration wraps |
| Capability advertisement | Medium | ★★☆☆☆ | ★★★★★ | Cyclic advertises index capability |
| Cross-package consistency | High | ★★★★★ | ★★★☆☆ | Array.Static aligns; Array.Cyclic misleads |
| Abstraction level | Low | ★★★☆☆ | ★★★★☆ | Higher abstraction less important than accuracy |

**Weighted score**:
- `.Static<N>`: 4.2 / 5.0
- `.Cyclic<N>`: 2.6 / 5.0

---

## 6. Formal Semantics Assessment

### 6.1 Naming Principle

From [Google API Design Guide](https://cloud.google.com/apis/design/naming_convention):

> "Use the same name or term for the same concept... Avoid name overloading. Use different names for different concepts."

**Assessment**:
- `Cyclic.Group<N>` — the algebraic structure (cyclic)
- `Index.Cyclic<N>` — an index with cyclic arithmetic (cyclic)
- `Set.Ordered.Cyclic<N>` — a set with inline storage (NOT cyclic)

Naming the set "Cyclic" when it isn't cyclic violates the "same name for same concept" principle.

### 6.2 Implementation vs Capability Naming

From the API design principle [TechTarget](https://www.techtarget.com/searchapparchitecture/feature/Why-API-naming-conventions-matter-and-how-to-master-the-art):

> "API names should describe **what capability is provided** (semantic meaning) rather than **how it's implemented**"

**Assessment**: This principle supports capability-based naming, but:

1. The **capability** of inline storage is: no heap allocation, eager copy
2. The **capability** of cyclic indexing is: wrap-around arithmetic

Both are capabilities. The question is which is more fundamental to the container's identity.

**Answer**: Inline storage is intrinsic to the container. Cyclic indexing is a capability of the **index type**, not the container.

---

## 7. Collaborative Review (Claude + ChatGPT)

A structured collaborative discussion was conducted to validate this analysis. The discussion converged after 3 rounds.

### Key Arguments from ChatGPT

ChatGPT identified the **category error** as the decisive issue:

> "The container is not cyclic. It has linear storage, linear iteration, linear logical order. Only the index algebra is cyclic. Naming the container `.Cyclic` misidentifies the locus of cyclicity."

Additional arguments:

1. **Violation of naming invariants**: Across the primitives stack, type names encode storage strategy, allocation model, and capacity semantics. They do not encode usage patterns or algorithms. `.Static` follows this rule; `.Cyclic` would be the first algorithmic container name.

2. **Forced semantics reduce reuse**: Valid non-cyclic uses exist:
   - Small bounded stacks
   - Fixed-capacity work queues with explicit bounds checking
   - Scratch buffers
   - Parsers requiring deterministic overflow failure, not wraparound

3. **Precedent risk**: Allowing "Cyclic" opens the door to `Array.Windowed`, `Array.Zipped`, `Array.Rotated` — eroding the strict separation between data representation and algorithms.

### Design Principle Established

**Containers encode storage; indices encode algebra.**

This principle cleanly separates:
- `.Static<N>` — describes where/how elements are stored (inline, compile-time capacity)
- `Index.Cyclic<N>` — describes arithmetic behavior (wrap-around modulo N)

These are orthogonal concerns that should not be conflated.

### Converged Implementation Plan (Proposal D)

The discussion converged on **Proposal D: Static container with canonical cyclic index support**:

1. **Keep `.Static<N>`** — storage-focused naming, consistent with ecosystem

2. **Bless `Index.Cyclic<N>`** — official way to get wrap-around semantics with `.Static<N>`

3. **Dual subscripts**:
   ```swift
   subscript(_ index: Index<Element>) -> Element  // bounds-checked, traps
   subscript(_ index: Index<Element>.Cyclic<capacity>) -> Element  // wraps
   ```

4. **Overloaded APIs** (return type differentiates):
   ```swift
   // Same method, overloaded by return type
   let idx: Index<Element> = try set.insert(element)                    // Linear
   let idx: Index<Element>.Cyclic<capacity> = try set.insert(element)   // Cyclic

   // Subscripts overloaded by parameter type
   set[linearIdx]   // Index<Element> - bounds checked, traps
   set[cyclicIdx]   // Index<Element>.Cyclic<N> - wraps
   ```

5. **Conversion via initializers** (not properties):
   ```swift
   extension Index.Cyclic {
     init(_ index: Index<Element>)  // precondition: index < N
   }

   extension Index {
     init(_ cyclic: Index<Element>.Cyclic<N>)  // always total
   }
   ```

6. **Compile-time safety enforced** — Type system ensures `Index.Cyclic<N>` only used with matching-capacity containers

7. **Future adapter deferred** — `CyclicView<Base>` possible later if needed

---

## 8. Outcome

**Status**: DECISION

**Decision**: Keep `.Static<N>` as the variant name. Do not rename to `.Cyclic<N>`. Implement Proposal D for cyclic index support.

### Rationale

1. **Category error**: The container is not cyclic. The index can be cyclic. Naming the container "Cyclic" misattributes a property of the index to the container.

2. **Design principle**: Containers encode storage; indices encode algebra. This is now an established principle for the primitives ecosystem.

3. **Prior art consensus**: C++ (`inplace_vector`), Rust (`ArrayVec`), and Swift stdlib (`InlineArray`) all use storage-focused naming. No major language uses "cyclic" for container types.

4. **Misleading implications**: `.Cyclic<N>` suggests ring buffer semantics that the type doesn't have. Iteration doesn't wrap. Subscripts don't wrap. Only explicit use of `Index.Cyclic<N>` provides cyclic behavior.

5. **Cross-package consistency**: `Array.Static<N>` and `Set.Ordered.Static<N>` should align. Renaming to `Array.Cyclic<N>` would sound like a ring buffer, which it is not.

6. **Non-cyclic uses are first-class**: Inline variable-count storage is not intrinsically cyclic and must not force wrap-around semantics.

### Action Items

- [ ] Add `insert(_:)` overload to `Set.Ordered.Static<N>` returning `Index<Element>.Cyclic<capacity>`
- [ ] Add `insert(_:)` overload to `Set<Bit>.Vector.Static<N>` returning `Index<Bit>.Cyclic<wordCount>`
- [ ] Add subscript overload accepting `Index<Element>.Cyclic<capacity>`
- [ ] Add conversion initializers between `Index<Element>` and `Index<Element>.Cyclic<N>`
- [ ] Document the design principle: "Containers encode storage; indices encode algebra"
- [ ] Add documentation section on cyclic index support to `.Static<N>` types
- [ ] Defer `StaticCapacityCollection<N>` protocol until concrete need arises

### Documentation Recommendation

Add documentation to `.Static<N>` variants explaining:

```swift
/// A fixed-capacity set with inline storage.
///
/// ## Cyclic Index Support
///
/// Because the capacity is known at compile time, this type supports
/// `Index.Cyclic<capacity>` for wrap-around index arithmetic. Use type
/// annotation to select the cyclic overload:
///
/// ```swift
/// var set = Set<Int>.Ordered.Static<8>()
/// let idx: Index<Int>.Cyclic<8> = try set.insert(42)  // Cyclic overload
/// idx += .one  // Wraps at capacity
/// set[idx]     // Cyclic subscript (wraps)
/// ```
///
/// > Note: Cyclicity is a property of the index algebra, not the container.
/// > Iteration remains linear. Subscript behavior depends on index type.
```

### Future Direction

If true ring buffer semantics are needed, consider adding:

```swift
RingBuffer<Element, let capacity: Int>  // FIFO circular buffer
```

This would correctly use "ring" or "circular" terminology for a type with actual wrap-around behavior.

---

## References

### Swift Evolution
- [SE-0453: InlineArray](https://forums.swift.org/t/accepted-with-modifications-se-0453-inlinearray-formerly-vector-a-fixed-size-array/77678)
- [SE-0453 Proposal](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md)

### C++ Standards
- [P0843: inplace_vector](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2023/p0843r8.html)
- [std::inplace_vector - cppreference](https://en.cppreference.com/w/cpp/container/inplace_vector.html)
- [Tesla fixed-containers](https://github.com/teslamotors/fixed-containers)

### Rust
- [arrayvec crate](https://docs.rs/arrayvec/latest/arrayvec/)
- [Rust API Guidelines - Naming](https://rust-lang.github.io/api-guidelines/naming.html)

### Mathematics
- [Cyclic group - Wikipedia](https://en.wikipedia.org/wiki/Cyclic_group)
- [Circular buffer - Wikipedia](https://en.wikipedia.org/wiki/Circular_buffer)

### API Design
- [Google API Design Guide - Naming](https://cloud.google.com/apis/design/naming_convention)
- [Cognitive Dimensions Framework (Clarke 2003)](https://www.ppig.org/files/2003-PPIG-15th-clarke.pdf)
- [API Naming Conventions - TechTarget](https://www.techtarget.com/searchapparchitecture/feature/Why-API-naming-conventions-matter-and-how-to-master-the-art)

### Internal References
- `swift-cyclic-primitives/Sources/Cyclic Primitives/Cyclic.Group.swift`
- `swift-cyclic-index-primitives/Sources/Cyclic Index Primitives/Index.Cyclic.swift`
- `swift-set-primitives/Research/array-set-primitives-comparison.md`
