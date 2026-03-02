# Owned Typed Memory Region Abstraction

<!--
---
version: 2.1.0
last_updated: 2026-02-25
status: DECISION
tier: 3
applies_to: [swift-memory-primitives, swift-string-primitives, swift-identity-primitives, swift-storage-primitives, swift-buffer-primitives]
normative: true
changelog:
  - v2.1.0 (2026-02-25): Experiment `memory-contiguous-owned` (11 variants, all confirmed, debug + release). Key finding: direct stored property access works for @_lifetime propagation — no closure pattern needed. Updated code samples, resolved Open Question #3, added implementation plan with experiment-validated patterns.
  - v2.0.0 (2026-02-25): Converged on Memory.Contiguous<Element>. Reframed from ownership concern to contiguous memory concern. Rejected "cardinality axis" framing — ownership and value are separate concerns. Added protocol hoisting analysis, Type/Type.View pattern, formal boundary (BitwiseCopyable). Decision: Memory.Contiguous<Element> fills the Level 2 gap.
  - v1.0.0 (2026-02-25): Initial draft. Five options (A–E) analyzed. Identified Level 2 gap between Ownership.Unique (Level 1) and Storage (Level 3).
---
-->

## Context

The Swift Institute primitives ecosystem manages typed memory at two levels:

| Package | What it does | Level |
|---------|-------------|-------|
| `Ownership.Unique<T>` | Owns one heap-allocated `T` with deinit | Value ownership |
| `Storage<E>.Heap`, `.Inline<N>`, etc. | Per-element lifecycle tracking (initialize, move, deinitialize) | Managed storage |

Between these, there is no reusable abstraction for **owned contiguous typed memory with bulk deallocation** — no per-element lifecycle, just "I own this region, deallocate when I die."

`String_Primitives.String` implements this manually: `UnsafePointer<Char>` + `count` + `deinit { deallocate() }`. Adding phantom-typed string domains via `Tagged<Domain, String.Storage>` (validated by experiments `tagged-string-literal` and `phantom-tagged-string-unification`) requires naming `String.Storage` — which raises the question: where does this concept belong in the ecosystem?

**Trigger**: `string-path-type-unification.md` (v3.0) established `Tagged<Domain, String.Storage>` as the correct unification. The compound name `StringStorage` violates [API-NAME-001]. The natural nesting `String.Storage` requires determining the correct foundation.

**Scope**: Ecosystem-wide per [RES-002a].

**Constraint**: Major refactoring authorized to reach the correct endstate.

---

## Question

**What is the correct abstraction for "owned contiguous typed memory with bulk deallocation," and where should it live?**

---

## Part I: Systematic Literature Review

### 1.1 Research Questions

Per [RES-023] (Kitchenham methodology):

- **RQ1**: What taxonomies exist for owned memory abstractions in systems programming?
- **RQ2**: How do existing languages stratify ownership (exclusive, shared, region-based)?
- **RQ3**: What formal frameworks distinguish "owns a typed buffer with bulk lifecycle" from "manages elements with per-element lifecycle"?

### 1.2 Search Strategy

Sources: Swift Evolution (SE-0377, SE-0390, SE-0427, SE-0437), Rust RFCs and std documentation, C++ Core Guidelines, Cyclone region-based memory, Capability Calculus (Crary/Walker/Morrisett 1999), Resource Polymorphism (Pottier 2007), Mezzo (Balabonski et al.), Alms (Tov & Pucella), Austral (Borretti).

### 1.3 Synthesis: Two Levels of Typed Memory Management

The literature distinguishes two fundamentally different relationships to typed memory:

**Contiguous Region** — "I own a contiguous region of typed memory. Deallocation is bulk."
- C++: `unique_ptr<T[]>`, `string`, `vector<T>` (buffer ownership aspect)
- Rust: `Box<[T]>`, `String` (newtype over `Vec<u8>`), `OsString`, `CString`
- Cyclone: Region types with static capabilities (Grossman/Morrisett 2002)
- Capability Calculus: Region capability — deallocation requires relinquishing capability (Crary/Walker/Morrisett 1999)
- Swift Institute: **GAP** — `String` does this manually

**Managed Storage** — "I own typed memory with per-element lifecycle tracking."
- C++: `vector<T>` (element lifecycle aspect), `deque<T>`
- Rust: `Vec<T>` with `unsafe { ptr::drop_in_place }` per element
- Swift Institute: `Storage<Element>.Heap`, `Storage<Element>.Inline<N>`, etc.

**Key formal distinction** (Capability Calculus): A **region capability** grants access to a memory region as a single affine resource — deallocation is bulk. An **element capability** grants per-element operations (initialize, move, deinitialize) within the region. `Storage<Element>` provides element capabilities. The gap is a type providing only region capability.

### 1.4 Rust's Hierarchy

```
Contiguous Region:  Box<[T]>      — owned slice (pointer + length, drop deallocates)
                    String        — newtype over Vec<u8> (contiguous bytes)
                    OsString      — platform-string (owned contiguous)
                    CString       — null-terminated (owned contiguous)

Managed Storage:    Vec<T>        — growable, per-element Drop
                    (in libraries) — arena allocators, slab allocators
```

Critical: **`String` is a newtype over `Vec<u8>`** — Rust strings compose contiguous-region ownership rather than implementing their own. The string domain logic (UTF-8, null-termination) wraps the generic owned region.

**Deref coercions** (`String` → `&str`, `Vec<T>` → `&[T]`) create the owned/borrowed pair. In Swift Institute terms: Type / Type.View.

### 1.5 Formal Framework: Capability Calculus

Crary, Walker, and Morrisett (1999):

| Capability Calculus | Swift ~Copyable |
|---|---|
| Capability `C(r)` | The `~Copyable` owner itself — existence proves liveness |
| Allocation | `init` — creates the owner |
| Deallocation (capability consumed) | `deinit` — owner consumed, region freed |
| Subcapability (borrowed access) | `borrowing` / `~Escapable` View / `Span` |

The region capability is a single affine resource. Borrowed access (`Span`) does not consume it. The `~Escapable` constraint ensures borrowed views cannot outlive the region.

### 1.6 Resource Polymorphism (Pottier 2007)

Pottier distinguishes affine resources (used at most once) from duplicable resources (freely copied). A memory region is affine — freed exactly once in `deinit`. Elements within may be independently affine (per-element lifecycle) or the region may be treated as a single affine unit (bulk deallocation). This maps directly to the contiguous-region vs managed-storage distinction.

The constraint that makes bulk deallocation sound: **elements must not require individual deinitialization.** In Swift terms: `BitwiseCopyable`. This is the formal boundary between the two levels.

---

## Part II: Architecture Analysis

### 2.1 The Existing Ecosystem

The ecosystem already has a namespace for contiguous memory:

| Type | Role |
|------|------|
| `Memory.Contiguous` | Namespace enum (empty) |
| `Memory.Contiguous.Protocol` | Protocol: `var span: Span<Element>` + `withUnsafeBufferPointer` |
| `Storage.Heap`, `Buffer.Linear`, `Swift.Array` | Conformers (all Level 3 — per-element lifecycle) |

The protocol defines what contiguous access looks like. But **there is no concrete self-owning conformer that provides only contiguous access** — every existing conformer adds per-element lifecycle management on top.

### 2.2 Reframing: Not an Ownership Concern

Initial analysis (v1.0) framed this as a gap in `Ownership` — a missing "cardinality axis" (one value vs. contiguous region). This framing was **incorrect**.

`Ownership.Unique<T>` owns one T. But T can be anything — including a contiguous region type. Ownership and value are separate concerns. The gap is not in the ownership taxonomy; it is in the **contiguous memory** taxonomy. There is no reusable type that represents "owned contiguous typed region with bulk deallocation."

### 2.3 Memory.Contiguous IS the Type

The ecosystem pattern is: the type IS the owned form, the `.View` is the borrowed form.

| Owned | Borrowed |
|-------|----------|
| `String` | `String.View` |
| `Tagged<Domain, RawValue>` | `Tagged<Domain, RawValue>.View` |
| `Storage.Heap` | access via `Span` |

Applying this pattern:

- `Memory.Contiguous<Element>` — the owned contiguous typed region (struct, `~Copyable`, `deinit`)
- `Memory.Contiguous<Element>.View` — the borrowed view (`Span<Element>`, typealias)

`Memory.Contiguous` transforms from an empty namespace enum into the concrete type that fills the gap. It becomes the simplest possible self-owning conformer of its own protocol.

### 2.4 Protocol Hoisting

The experiment `protocol-inside-generic-namespace` confirmed: **protocols cannot nest inside generic types** in Swift. If `Memory.Contiguous` becomes a generic struct, `Memory.Contiguous.Protocol` cannot remain nested.

The experiment `protocol-typealias-hoisting` confirmed the workaround: hoist the protocol outside, typealias back.

```swift
// Protocol hoisted to Memory level (associatedtype: BitwiseCopyable works without
// SuppressedAssociatedTypes; use ~Copyable only if feature flag available)
extension Memory {
    public protocol ContiguousProtocol: ~Copyable {
        associatedtype Element: BitwiseCopyable
        var count: Int { get }
    }
}

// The concrete type — IS Memory.Contiguous
extension Memory {
    @safe
    public struct Contiguous<Element: BitwiseCopyable>: ~Copyable, @unchecked Sendable {
        @usableFromInline
        internal let pointer: UnsafePointer<Element>

        public let count: Int

        @inlinable
        public init(adopting pointer: UnsafeMutablePointer<Element>, count: Int) {
            unsafe self.pointer = UnsafePointer(pointer)
            self.count = count
        }

        @inlinable
        deinit {
            unsafe UnsafeMutablePointer(mutating: pointer).deallocate()
        }

        /// Borrowed view — Span is the non-owning counterpart.
        public typealias View = Span<Element>

        /// Contiguous access protocol (hoisted).
        public typealias `Protocol` = Memory.ContiguousProtocol
    }
}

// Span access — uses _overrideLifetime to rebind span lifetime to self
extension Memory.Contiguous {
    public var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            let s = unsafe Span(_unsafeStart: pointer, count: count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }

    public var view: View {
        @_lifetime(borrow self)
        borrowing get { span }
    }
}

// Protocol conformance
extension Memory.Contiguous: Memory.ContiguousProtocol {}
```

**Experiment-validated pattern** (`memory-contiguous-owned`, 11 variants, all confirmed):

- `@safe` annotation required under StrictMemorySafety for types holding `UnsafePointer`
- `_overrideLifetime(span, borrowing: self)` required at each layer when forwarding span through wrappers
- Direct stored property access (`_storage.span`) works for `@_lifetime` propagation — no closure pattern needed
- Unlike `rawValue` (`_read { yield _storage }`) which creates a lifetime scope boundary, stored property access chains cleanly through multiple layers:

```
Tagged.span → _storage.span → _contiguous.span → Span<Char>
```

Each layer uses `_overrideLifetime` to rebind the span's lifetime to its owner. The chain works in both debug and release with no CopyPropagation crash (#87029).

### 2.5 The BitwiseCopyable Boundary

`Memory.Contiguous<Element: BitwiseCopyable>` — the `BitwiseCopyable` constraint is the formal boundary between this type and `Storage<Element>`:

| | `Memory.Contiguous<Element>` | `Storage<Element>` |
|---|---|---|
| Element constraint | `BitwiseCopyable` | `~Copyable` |
| Per-element deinit | Not needed (trivially destructible) | Required (tracked) |
| Deallocation | Bulk `deallocate()` | Deinitialize each, then deallocate |
| Initialization tracking | None | `Storage.Initialization` enum |
| Mutability | Immutable after construction | Mutable |

`BitwiseCopyable` guarantees bulk deallocation is sound — no element can be leaked. This is not a limitation; it is a correctness boundary.

### 2.6 String Layering

```
Tagged<Domain, String.Storage>     — domain safety (phantom type)
         ↓ RawValue
String.Storage                     — string invariants (null-termination, platform Char)
         ↓ wraps
Memory.Contiguous<Char>            — owned contiguous typed region
         ↓ .view / .span
Span<Char>                         — borrowed access (stdlib)
```

Each layer adds exactly one concern. `Memory.Contiguous<Char>` doesn't know about null termination. `String.Storage` doesn't know about domains. `Tagged` doesn't know about memory.

**Tier resolution**: String can be at a higher tier than its current placement. The semantic dependency (String depends on Memory.Contiguous) drives the tier, not the other way around. `Memory.Contiguous` has zero ecosystem dependencies — it uses only Swift stdlib types (`UnsafePointer`, `Span`, `Int`, `BitwiseCopyable`).

### 2.7 Span Duality

The relationship between `Memory.Contiguous` and `Span` mirrors the owned/borrowed duality throughout the ecosystem:

| Owned | Borrowed |
|-------|----------|
| `Memory.Contiguous<Element>` | `Span<Element>` (stdlib) |
| `String` | `String.View` |
| `Ownership.Unique<T>` | `borrowing T` |

`Memory.Contiguous<Element>` is to `Span<Element>` what `String` is to `String.View`: the self-owning form that provides borrowed access to the data it owns.

---

## Part III: Formal Semantics

### 3.1 Typing Rules

**Contiguous Region (Memory.Contiguous)**

```
Γ ⊢ ptr : Pointer<τ>, Γ ⊢ n : Nat, τ : BitwiseCopyable
──────────────────────────────
Γ ⊢ Contiguous(ptr, n) : Memory.Contiguous<τ>    (affine — owns [ptr, ptr + n×stride(τ)))

Γ ⊢ c : Memory.Contiguous<τ>
──────────────────────────────
Γ ⊢ c.span : Span<τ>                             (borrowing — c not consumed)
Γ ⊢ c.count : Nat                                (borrowing)
Γ ⊢ deinit(c) : ⊤                                (automatic — deallocate region)
```

No element-level capability is granted. The region is a single affine resource.

**Managed Storage (Storage<Element>)**

```
Γ ⊢ ptr : MutPointer<τ>, Γ ⊢ cap : Nat, Γ ⊢ init : Initialization<τ>
──────────────────────────────
Γ ⊢ Storage(ptr, cap, init) : Storage<τ>    (affine)

Γ ⊢ s : Storage<τ>, Γ ⊢ i : Index, Γ ⊢ v : τ
──────────────────────────────
Γ ⊢ s.initialize(v, at: i) : Storage<τ>     (mutating — updates init tracking)
Γ ⊢ s.move(at: i) : (τ, Storage<τ>)         (mutating — moves element, updates tracking)
Γ ⊢ deinit(s) : ⊤                            (automatic — deinitialize tracked elements + deallocate)
```

### 3.2 Soundness Argument

**Bulk deallocation safety**: `Memory.Contiguous<τ>` requires `τ: BitwiseCopyable`. This ensures no element requires individual deinitialization. Bulk `deallocate()` is sufficient — no resource leak is possible.

**Affine ownership**: `Memory.Contiguous<τ>` is `~Copyable` — consumed at most once (by `deinit`). Borrowed access (`Span`) does not consume the region. The `Span` lifetime is tied to the region via `@_lifetime(borrow self)`.

**Phantom typing preservation**: `Tagged<Tag, String.Storage>` where `String.Storage` wraps `Memory.Contiguous<Char>` preserves all capabilities. The Tag adds domain safety without affecting ownership. `.retag()` changes the Tag without touching the region. `.map()` transforms the storage while preserving the Tag.

---

## Part IV: Alternatives Considered

| Option | Summary | Disposition |
|--------|---------|-------------|
| **A: String.Storage only** | Ad-hoc, no reusable abstraction | Rejected — Level 2 gap persists, inconsistent with ecosystem rigor |
| **B: Ownership.Region** | New type in Ownership namespace | Rejected — "Region" carries misleading connotations (Cyclone/Tofte-Talpin); ownership and value are separate concerns |
| **C: Storage refactor** | Split Storage into low-tier kernel + high-tier tracking | Rejected — two packages cannot share the `Storage` namespace (module collision) |
| **D: Ownership.Buffer** | New buffer type in Ownership | Rejected — wrong namespace (Ownership is about sharing discipline, not memory structure); "Buffer" name conflicts with buffer-primitives |
| **E: String.Storage + defer** | Define String.Storage, defer generalization | Superseded — `Memory.Contiguous` is the correct generalization and the infrastructure already has the namespace |
| **F: Memory.Contiguous\<Element\>** | Concrete self-owning type in existing namespace | **SELECTED** — fills the gap in its natural home |

**Why Option F over Options B/D** (Ownership placement): The v1.0 analysis incorrectly framed this as an ownership concern with a missing "cardinality axis." Ownership types describe sharing discipline (exclusive, shared, mutable). `Memory.Contiguous` describes memory structure (contiguous typed region). These are orthogonal. The gap is in the memory taxonomy, not the ownership taxonomy.

**Why Option F over Option E** (deferral): The `Memory.Contiguous` namespace and protocol already exist. Adding the concrete type is not premature abstraction — it is completing an existing abstraction that has a protocol but no self-owning implementation. The protocol has conformers (Storage.Heap, Buffer.Linear, Swift.Array) but they all add per-element lifecycle. The simplest conformer — the one that provides only what the protocol requires — does not yet exist.

---

## Part V: Outcome

**Status**: DECISION

### Decision: `Memory.Contiguous<Element: BitwiseCopyable>`

`Memory.Contiguous` transforms from a namespace enum into the concrete self-owning contiguous typed memory region. It fills the Level 2 gap in its natural home — the `Memory.Contiguous` namespace that already hosts the protocol for contiguous access.

**Type structure**:
- `Memory.Contiguous<Element: BitwiseCopyable>` — owned, immutable, `~Copyable`, `@unchecked Sendable`
- `Memory.Contiguous<Element>.View` — typealias for `Span<Element>` (borrowed counterpart)
- `Memory.Contiguous.Protocol` — hoisted to `Memory.ContiguousProtocol` per `protocol-typealias-hoisting` pattern, typealiased back

**Formal boundary**: `BitwiseCopyable` on Element guarantees bulk deallocation soundness. This is the formal separation from `Storage<Element>`, which tracks per-element lifecycle for `~Copyable` elements.

**String composition**:
```
Tagged<Domain, String.Storage>     — phantom-typed string
String.Storage                     — null-termination + platform Char
Memory.Contiguous<Char>            — owned contiguous typed region
Span<Char>                         — borrowed access (via .view / .span)
```

**Tier implications**: `Memory.Contiguous` has zero ecosystem dependencies (Swift stdlib only). String moves to a higher tier to depend on it. Tier follows semantic dependency.

### Implementation Plan

Validated by experiment `memory-contiguous-owned` (11 variants, all confirmed, debug + release).

**Phase 1: memory-primitives** — Transform `Memory.Contiguous`

1. Hoist `Memory.Contiguous.Protocol` to `Memory.ContiguousProtocol` (protocol cannot nest in generic type)
2. Transform `Memory.Contiguous` from namespace enum to `@safe struct Contiguous<Element: BitwiseCopyable>: ~Copyable, @unchecked Sendable`
3. Add stored properties: `pointer: UnsafePointer<Element>`, `count: Int`
4. Add `init(adopting:count:)`, `deinit { deallocate }`, `span` (with `_overrideLifetime`), `view` (typealias `Span<Element>`)
5. Typealias `Memory.Contiguous.Protocol = Memory.ContiguousProtocol` back into the generic struct
6. Add conformance `Memory.Contiguous: Memory.ContiguousProtocol`
7. Update existing conformers (unchanged — they already conform to the protocol)

**Phase 2: string-primitives** — Define `String.Storage`

1. Define `PlatformString.Storage` (or `String.Storage`) wrapping `Memory.Contiguous<Char>`
2. Add null-termination invariant, `span` forwarding with `_overrideLifetime`
3. Add `init(ascii:)` convenience for StaticString literals
4. Sendable inheritance: `@unchecked Sendable` (wraps `Memory.Contiguous` which is already Sendable)
5. Update tier to depend on memory-primitives

**Phase 3: Tagged integration** — No changes needed

- `Tagged<Domain, String.Storage>` works today (validated by experiments `tagged-string-literal` and `memory-contiguous-owned`)
- Direct span access through stored property chain works: `tagged.span` → `_storage.span` → `_contiguous.span`
- Conditional Sendable: `extension Tagged: Sendable where Tag: ~Copyable, RawValue: ~Copyable & Sendable {}`
- Domain migration: `retag()` consuming function (no `discard self` needed without Tagged deinit)

**Experiment-validated patterns** (must follow exactly):

| Pattern | Validated | Notes |
|---------|-----------|-------|
| `@safe` on types holding `UnsafePointer` | V1 | Required under StrictMemorySafety |
| `_overrideLifetime(span, borrowing: self)` | V2, V5, V7 | Required at each wrapper layer |
| Protocol with `associatedtype Element: BitwiseCopyable` | V3, V4 | Works without SuppressedAssociatedTypes |
| `some Protocol & ~Copyable` in function signatures | V4 | Suppresses implicit Copyable requirement |
| Span forwarding via stored property access | V5, V7 | NOT via `rawValue` (`_read` coroutine blocks lifetime) |
| Conditional `Sendable` with `~Copyable` constraints | V6, V8 | `where Tag: ~Copyable, RawValue: ~Copyable & Sendable` |
| Consuming `retag` without `discard self` | V9 | No deinit on Tagged — consuming `_storage` suffices |

### Open Questions (Implementation-Level)

1. **Mutable variant**: Should `Memory.Contiguous.Mutable<Element>` exist? (Growable owned buffer — closer to current `Memory.Buffer.Mutable` but typed.)
2. **Memory.Buffer relationship**: Current `Memory.Buffer` is raw byte access via `Memory.Address`. Should it be refactored to compose `Memory.Contiguous<UInt8>`, or do they remain parallel?

---

## References

1. Crary, K., Walker, D., Morrisett, G. (1999). *Typed Memory Management in a Calculus of Capabilities*. POPL '99. [ACM DL](https://dl.acm.org/doi/10.1145/292540.292564)
2. Grossman, D., Morrisett, G., et al. (2002). *Region-Based Memory Management in Cyclone*. PLDI '02. [PDF](https://www.cs.umd.edu/projects/cyclone/papers/cyclone-regions.pdf)
3. Pottier, F. (2007). *Wandering through linear types, capabilities, and regions*. [INRIA](https://pauillac.inria.fr/~fpottier/slides/fpottier-2007-05-linear-bestiary.pdf)
4. Balabonski, T., Pottier, F., Protzenko, J. (2014). *Resource Polymorphism*. [HAL](https://inria.hal.science/hal-01724997)
5. Tov, J.A., Pucella, R. (2011). *Practical Affine Types*. POPL '11.
6. Borretti, F. (2023). *Type Systems for Memory Safety*. [Blog](https://borretti.me/article/type-systems-memory-safety)
7. Bernardy, J.-P., et al. (2017). *Retrofitting Linear Types*. [Microsoft Research](https://www.microsoft.com/en-us/research/wp-content/uploads/2017/03/haskell-linear-submitted.pdf)
8. Swift Evolution SE-0377: *borrowing and consuming parameter ownership modifiers*. [GitHub](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0377-parameter-ownership-modifiers.md)
9. Swift Evolution SE-0390: *Noncopyable structs and enums*. [GitHub](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md)
10. Swift Evolution SE-0427: *Noncopyable generics*. [GitHub](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
11. Swift Evolution SE-0437: *Noncopyable Standard Library Primitives*. [GitHub](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md)
12. Rust Standard Library: `OsString`, `CString`, `Box<[T]>`. [docs.rs](https://doc.rust-lang.org/std/ffi/struct.OsString.html)
13. C++ Core Guidelines R: *Resource Management*. [isocpp](https://cpp-core-guidelines-docs.vercel.app/resource)
14. Verdagon (2023). *Higher RAII, and the Seven Arcane Uses of Linear Types*. [Blog](https://verdagon.dev/blog/higher-raii-uses-linear-types)
15. Tofte, M., Talpin, J.-P. (1997). *Region-Based Memory Management*. Information and Computation 132(2).
16. *Storage and Buffer Abstraction Analysis*. Swift Institute Research, v1.2.0 (2026-02-12).
17. *String and Path Type Unification*. Swift Institute Research, v3.0.0 (2026-02-25).

---

## Cross-References

- **string-path-type-unification.md** — Tier 3, v3.0. Option D' (Tagged<Domain, String.Storage>) depends on this research for the storage type naming and placement.
- **storage-buffer-abstraction-analysis.md** — Tier 3, v1.2.0. Analyzes Storage/Buffer variant proliferation at managed-storage level.
- **experiment: tagged-string-literal** — Validates that Tagged<Domain, StringStorage> works (10 variants, all confirmed).
- **experiment: phantom-tagged-string-unification** — Validates phantom-typed string pattern (9 variants, all confirmed).
- **experiment: protocol-inside-generic-namespace** — Confirms protocols cannot nest in generic types.
- **experiment: protocol-typealias-hoisting** — Confirms hoisting + typealias-back workaround.
- **experiment: memory-contiguous-owned** — Validates the complete Memory.Contiguous<Element> design (11 variants, all confirmed, debug + release). Key finding: direct stored property access works for @_lifetime propagation.
