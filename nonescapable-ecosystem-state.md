<!--
version: 1.0.0
last_updated: 2026-04-02
status: DECISION
tier: 2
consolidates:
  - nonescapable-readiness-assessment.md (DECISION, 2026-03-26)
  - noncopyable-peek-escapable.md (RECOMMENDATION, 2026-03-31)
  - nonescapable-storage-mechanisms.md (DECISION, 2026-03-02)
  - lifetime-annotation-escapable-swift-6.3.md (DECISION, 2026-03-25) [primitives — findings only]
-->

# ~Escapable Ecosystem State

## Question

What is the readiness of `~Escapable` in Swift 6.2/6.3 for production adoption?
What works, what is blocked, what are the storage patterns, and what are the
strategic recommendations?

## Context

Four separate research documents investigated overlapping aspects of ~Escapable
readiness, storage mechanisms, borrowed access patterns, and lifetime annotation
rules. This consolidation unifies their findings. The primitives-scoped
`lifetime-annotation-escapable-swift-6.3.md` retains its original location (correct
scope); findings are integrated here by reference.

---

## 1. Readiness Matrix

### Ready for Production

| Feature | Evidence |
|---------|---------|
| ~Escapable type declaration | Compiler infrastructure stable |
| @_lifetime annotations | Stable (underscored, experimental) |
| ~Escapable + Sendable | Orthogonal, confirmed experimentally |
| ~Escapable + @escaping closure storage (immortal) | Pattern works; Resumption reverted due to downstream, not the pattern |
| ~Escapable + consuming func | Stable |
| Optional<~Copyable + ~Escapable> | SE-0465 |
| Conditional Escapable (inline: Box, Pair) | Stable |
| Enum-based variable-occupancy (2–8 elements) | V14/V15 in pointer-nonescapable-storage |
| Immediately-invoked closures capturing ~Escapable (Gap B+) | Fixed in 6.2.4 |
| Optional<Copyable & ~Escapable> from _read / computed property | All 7 variants pass Swift 6.3 |
| Borrowed<T: ~Copyable>: ~Escapable wrapper | Confirmed |

(from nonescapable-readiness-assessment.md, 2026-03-26;
noncopyable-peek-escapable.md, 2026-03-31;
nonescapable-storage-mechanisms.md, 2026-03-02)

### NOT Ready

| Feature | Root Cause | Impact |
|---------|-----------|--------|
| Closure parameter lifetime dependencies (Gap A) | @_lifetime cannot depend on Escapable values | Blocks zero-allocation closure storage |
| Stored closure capture of ~Escapable (Gap B) | Compiler treats closure capture as escape | Blocks Receiver pattern |
| UnsafeMutablePointer<T: ~Escapable> | Pointee implicitly requires Escapable. FIXME at `lib/ClangImporter/ImportType.cpp:507`. SE-0465 deferred. | **Blocks all heap-backed containers** |
| Optional<Element> stored property in ~Escapable container | Lifetime escape error even with non-nil init | Blocks "empty slot" semantics |
| InlineArray<N, Element: ~Escapable> | Implicit Escapable on Element | Blocks fixed-capacity inline containers |
| @_rawLayout element access | Typed access requires pointer types with implicit Escapable | Layout-vs-access gap |
| Lifetime dependencies between heap objects | Not proposed | Future |

(from nonescapable-readiness-assessment.md, 2026-03-26;
nonescapable-storage-mechanisms.md, 2026-03-02)

---

## 2. Storage Patterns

### Root cause of limitations

UnsafeMutablePointer declares `Pointee: ~Copyable` but NOT `& ~Escapable`.
Same implicit Escapable affects `UnsafeMutableRawPointer.initializeMemory`,
`.assumingMemoryBound`, `InlineArray`, `withUnsafePointer`.
(from nonescapable-storage-mechanisms.md, 2026-03-02)

### Working storage paths

| Path | Mechanism | Capacity |
|------|-----------|----------|
| Non-Optional struct fields | Inline storage | Fixed at compile time |
| Enum associated values | Compiler layout engine | Variable (one case per occupancy) |
| consuming take() | Move semantics | N/A (extraction) |
| Nested containers | Composition | Depth, not breadth |
| @_rawLayout declaration | Attribute compiles with ~Escapable | Layout only (access blocked) |

(from nonescapable-storage-mechanisms.md, 2026-03-02)

### Enum-based variable-occupancy storage

Canonical pattern using `consume self` + full reinit. Practical for capacities 2–8:

```swift
enum EnumStack4<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    case zero
    case one(Element)
    case two(Element, Element)
    case three(Element, Element, Element)
    case four(Element, Element, Element, Element)

    @_lifetime(self: copy self, copy element)
    mutating func push(_ element: consuming Element) {
        switch consume self {
        case .zero: self = .one(element)
        case .one(let a): self = .two(a, element)
        // ...
        }
    }
}
extension EnumStack4: Copyable where Element: Copyable & ~Escapable {}
extension EnumStack4: Escapable where Element: Escapable & ~Copyable {}
```

Scalability: 2 elements = 3 cases (practical), 4 = 5 (practical), 8 = 9 (marginal),
16+ = impractical.
(from nonescapable-storage-mechanisms.md, 2026-03-02)

### @_lifetime(immortal) pattern

For ~Escapable types storing @escaping closures when no borrowable source exists:

```swift
struct ScopedResumption: ~Escapable {
    let thunk: @Sendable () -> Void
    @_lifetime(immortal)
    init(_ action: @escaping @Sendable () -> Void) {
        self.thunk = action
    }
    consuming func execute() { thunk() }
}
```

Achieves scope enforcement but NOT zero-allocation (closure is still heap-allocated).
(from nonescapable-readiness-assessment.md, 2026-03-26)

---

## 3. Borrowed Access (Peek)

### The Borrowed<T> wrapper type

`Borrowed<T: ~Copyable>: ~Escapable` wrapping `UnsafePointer<T>` with
`@_lifetime(borrow pointer)`. The wrapper is **Copyable** (pointer is trivially
copyable) but **~Escapable** (lifetime-scoped).
(from noncopyable-peek-escapable.md, 2026-03-31)

### Critical distinction: ~Copyable vs ~Escapable with Optional

| Combination | Works? | Why |
|-------------|:------:|-----|
| Optional<~Copyable> from _read | No | .some() consumes the ~Copyable value |
| Optional<Copyable & ~Escapable> from _read | **Yes** | .some() copies the Copyable wrapper |
| var x: ~Escapable? = nil (stored property) | No | No lifetime source for nil default |
| return nil in @_lifetime(borrow) function | **Yes** | Function's annotation covers nil |

This refutes the prior hypothesis that Optional<~Escapable> is blocked. The blocker
is Optional<~Copyable>, not Optional<~Escapable>.
(from noncopyable-peek-escapable.md, 2026-03-31)

### SE-0519 alignment

SE-0519 (Borrow<T> and Inout<T>) is structurally identical to Borrowed<T>. Review
complete, decision pending. When SE-0519 ships, replace Borrowed<T> with stdlib
Borrow<T>. API shape identical — `peek?.pointee` becomes the permanent pattern.
(from noncopyable-peek-escapable.md, 2026-03-31)

### Proposed var peek property

```swift
var peek: Borrowed<Element>? {
    _read {
        guard !(unsafe base.pointee.isEmpty) else { yield nil; return }
        yield unsafe Borrowed(base.pointee._buffer.frontPointer)
    }
}
```

Call site changes from `deque.front.peek { $0.value }` (closure) to
`deque.front.peek?.pointee.value` (property).
(from noncopyable-peek-escapable.md, 2026-03-31)

---

## 4. Lifetime Annotations (Swift 6.3)

### Discriminating rule

@_lifetime is valid **if and only if** the target is ~Escapable:
- Result-lifetime: return type must be ~Escapable
- Self-lifetime: self's type must be ~Escapable

Swift 6.3 now rejects annotations on Escapable types that were silently accepted
in 6.2. Two new diagnostics: "invalid lifetime dependence on an Escapable result"
and "invalid lifetime dependence on an Escapable target."
(from lifetime-annotation-escapable-swift-6.3.md, 2026-03-25)

### Pattern classification

| Pattern | Example | Fix |
|---------|---------|-----|
| A: @_lifetime(self: immortal) on Escapable iterator next() | ~50 files across 15+ packages | Remove — tautological |
| B: @_lifetime(&self) on methods returning Escapable | `last() -> Element?`, `all() -> Void` | Remove — return independent of self |
| C: @_lifetime(copy/borrow self) on Escapable returns | `collect() -> [Element]` | Remove |

(from lifetime-annotation-escapable-swift-6.3.md, 2026-03-25)

### Valid annotations (no change)

@_lifetime on `nextSpan() -> Span<E>`, `var span: Span<E>`,
`var mutableSpan: MutableSpan<E>`, ~Escapable wrapper inits and iterators.
(from lifetime-annotation-escapable-swift-6.3.md, 2026-03-25)

### Semantic gap

Removing @_lifetime(borrow self) from `makeIterator()` on `Sequence.Borrowing.Protocol`
leaves a semantic gap: protocol doc says iterator borrows from self, but no
compiler-enforced annotation. Comment preserved: "Will be restored when Iterator
gains ~Escapable."
(from lifetime-annotation-escapable-swift-6.3.md, 2026-03-25)

---

## 5. Compiler Gaps and Workarounds

| Gap | Workaround | Expected Resolution |
|-----|-----------|---------------------|
| Gap A (lifetime from Escapable closure) | @_lifetime(immortal) | Unknown (not proposed) |
| Gap B (stored closure capture) | Immediately-invoke (Gap B+) | Unknown |
| UnsafeMutablePointer Escapable constraint | Enum-based storage (cap 2–8) | Future proposal (no timeline) |
| Optional<~Escapable> stored property | Computed property or coroutine | Unknown |
| @_rawLayout access for ~Escapable | No workaround; wait for pointer changes | Follows UnsafeMutablePointer |
| @_lifetime on Escapable (Swift 6.3) | Remove annotation | N/A (intentional) |

### Expected milestones

| Feature | Timeline |
|---------|----------|
| SE-0474 yielding borrow / yielding mutate | Swift 6.4 |
| SE-0507 borrow / mutate accessors | Swift 6.4 |
| SE-0519 Borrow<T> / Inout<T> | Review complete, decision pending |
| @lifetime (official, non-underscore) | Pitch #3 |
| UnsafeMutablePointer<T: ~Escapable> | Future (no timeline) |

(from noncopyable-peek-escapable.md, 2026-03-31;
nonescapable-readiness-assessment.md, 2026-03-26)

---

## 6. Strategic Recommendations

1. **No async type should adopt ~Escapable today.** The Resumption revert
   demonstrates cascading incompatibility when heap-backed containers are needed.
   (from nonescapable-readiness-assessment.md, 2026-03-26)

2. **Track three milestones before re-attempting**: (a) UnsafeMutablePointer<T:
   ~Escapable>, (b) closure parameter lifetime dependencies (Gap A),
   (c) non-escaping closure storage.
   (from nonescapable-readiness-assessment.md, 2026-03-26)

3. **Conditional Escapable is viable for inline containers today.** Box, Pair,
   fixed-element-count containers using the Sequence.Map pattern.
   (from nonescapable-readiness-assessment.md, 2026-03-26)

4. **Implement Borrowed<T> in swift-property-primitives** as precursor to SE-0519.
   Add `var peek: Borrowed<Element>?` to Front.View and Back.View.
   (from noncopyable-peek-escapable.md, 2026-03-31)

5. **Enum-based storage for small-capacity ~Escapable containers** (2–8 elements).
   This is the only production-viable multi-element pattern today.
   (from nonescapable-storage-mechanisms.md, 2026-03-02)

---

## Cross-References

- **memory-safety** skill: [MEM-LIFE-001] through [MEM-LIFE-005], [MEM-SPAN-001]
- **noncopyable-ecosystem-state.md**: Companion document for ~Copyable
- **lifetime-annotation-escapable-swift-6.3.md**: Full audit in swift-primitives (retains original scope)
- Experiments: nonescapable-closure-storage, conditional-escapable-container,
  nonescapable-gap-revalidation-624, pointer-nonescapable-storage,
  escapable-accessor-patterns, escapable-lazy-sequence-borrowing,
  noncopyable-peek-escapable, nonescapable-edge-cases
