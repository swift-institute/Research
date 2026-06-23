# Buffer Storage-As-Associated-Type: Cross-Language Prior-Art Survey

<!--
---
version: 1.0.0
last_updated: 2026-05-30
status: RECOMMENDATION
tier: 2
scope: cross-package
applies_to: [swift-buffer-primitives, swift-storage-primitives, swift-memory-primitives, swift-collection-primitives]
normative: false
---
-->

## Context

**Trigger.** Swift Institute is deciding whether the buffer/collection capability
protocol `Buffer.Protocol` should expose its underlying **storage** as an
**associated type** on its public surface, so a single generic
`extension Iterable where Self: Buffer.Protocol` can vend a borrow-iterator for
*all* buffers — "maximum for free." Concretely the proposed addition is:

```swift
protocol Buffer.Protocol {                       // logical capability: count / isEmpty
    associatedtype Element: ~Copyable
    associatedtype Storage: Storage.Protocol      // ← the proposed addition: a buffer HAS-A storage
    var count: Count { get }
    var storage: Storage { borrowing get }        // ← exposes the storage core
}
// then one generic extension uses storage.pointer(at: 0) + count to vend the iterator.
```

where `Storage.Protocol = { pointer(at:) -> UnsafeMutablePointer<Element>, capacity }`
(physical slot-addressing core) and `Buffer.Protocol = { count, isEmpty }` (logical
core). The buffer COMPOSES (has-a) a storage; the question is whether *exposing that
storage as an associated TYPE on the public protocol surface* is sound and precedented.

**Why now.** The motivating wall is concrete: Swift's `Span`/`MutableSpan`
(SE-0447) is a *scoped* capability and **cannot yield an escaping element address
for a `~Copyable` element** — so the borrow-iterator the Institute wants cannot be
built from `Span` alone, which is what pushed the design toward reaching *past*
`Span` to the raw `pointer(at:)` of the storage core, and hence toward exposing
that core on the protocol.

**Constraints.** Research-only; no code touched. Tier 2 per [RES-020] (cross-package,
reversible-but-precedent-shaping). Citations required for every load-bearing claim
([RES-026], [RES-032]).

**Internal prior research consulted ([RES-019]).** Three internal docs bear
directly and govern pending explicit override:

- `cross-layer-capability-protocol-model.md` (v1.1.0, **APPROVED 2026-05-28**, Tier 3) —
  the ecosystem-wide capability-protocol model. **It already answers this question.**
  It positions `Buffer.Protocol` as logical-occupancy (`count`/`isEmpty`) that
  **"Does NOT refine `Storage.Protocol` (has-a) nor `Iterable` (orthogonal)"**, and
  routes the contiguous-read surface to the *orthogonal* `Span.Protocol`
  (a `span` capability), with iteration composed `where Self: Iterable`
  (`cross-layer-capability-protocol-model.md`, §3.4, lines 200–204).
- `storage-buffer-abstraction-analysis.md` (v1.2.0, Tier 3) — surveyed Rust Storage
  API, C++ pmr, Zig; concluded storage-strategy abstraction under one protocol is
  intractable, and the right abstraction point is the *ownership discipline*
  (capability), not a storage type.
- `storage-generic-buffer-core.md` (v1.1.0) — the two-lever model where a generic
  algorithm over `some Storage.Protocol` is the *cold* path and a concrete-`Base`
  `Property.Inout` is the *hot* path; proven 0-`witness_method` cross-module.

This survey contextualizes that internal position against external prior art and
confirms it.

---

## Question

Do other languages / ecosystems expose the underlying storage (or a base pointer)
as an **associated/parameterized TYPE on a buffer/collection abstraction**, so
generic code composes over it? Or do they universally do something else:

- (a) **encapsulate** storage and expose only a *scoped* base/slice accessor
  (closure-scoped / borrowed-with-release);
- (b) parameterize on an **allocator/storage-strategy** type — but NOT expose the
  base as a composable surface;
- (c) express "contiguous/addressable" as a **capability/concept** (a method or
  refinement that yields a base/slice), not a storage type?

And what does the dominant pattern imply for the Institute's proposal?

---

## The taxonomy

We classify each ecosystem along four mutually-exclusive design choices for "how a
container relates to its physical storage on a generic/abstraction surface":

| Class | Name | Shape | What is on the abstraction surface |
|-------|------|-------|------------------------------------|
| **T1** | **Storage-as-associated-TYPE** | `associatedtype Storage` + `var storage: Storage` on the protocol | the storage *object* itself (an escaping, composable member) |
| **T2** | **Allocator/storage-STRATEGY param** | `Container<T, A: Allocator>` | an allocation *strategy* type — **not** the base; base stays private |
| **T3** | **Scoped-accessor** | `with…(body: (BufferPointer) -> R)` / get+release | a *borrowed* base, valid only for a bounded scope |
| **T4** | **Contiguous-as-CAPABILITY/concept** | a concept/refinement (`ranges::data`, `Deref<Target=[T]>`, `span`) that *yields* a base | a *capability* (the ability to produce a base/slice), not a stored type |

The Institute's proposal is **T1**. The survey question is whether **T1** is
precedented anywhere.

---

## Per-language survey

### 1. Swift standard library — T3 + T4 (never T1)

**`Sequence`/`Collection`/`MutableCollection`/`RandomAccessCollection` associated
types.** The associated types are `Iterator`, `Element`, `Index`, `SubSequence`,
`Indices`. **There is no `Storage` associated type** anywhere in the `Collection`
hierarchy. Contiguity is not modelled as a stored type at all
([Apple Developer — Collection](https://developer.apple.com/documentation/swift/collection)).

**Scoped accessor (T3).** SE-0237 added the contiguous *access* surface as a
**closure-scoped method**, not a type:

> `withContiguousStorageIfAvailable<R>(_ body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R?`
> `withContiguousMutableStorageIfAvailable<R>(_ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R) rethrows -> R?`

SE-0237 *"added only a method/closure-scoped accessor, not an associated type"*; the
pointer is valid only for the body's duration
([SE-0237](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0237-contiguous-collection.md)).
[Verified: 2026-05-30]

**The T1-adjacent design was proposed and REJECTED.** SE-0256 (*ContiguousCollection*)
proposed protocols (`ContiguousCollection`/`MutableContiguousCollection`) refining
`Collection` — but even these added **no storage associated type**; they only
*re-stated the closure-scoped accessor as a protocol requirement* (a T3-as-refinement).
SE-0256's status is **Rejected**
([SE-0256](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0256-contiguous-collection.md)).
[Verified: 2026-05-30]

**The capability (T4) won, and the storage-type protocol was deliberately deferred.**
SE-0447 (`Span`) is explicit. An earlier draft proposed a `ContiguousStorage`
protocol "by which a type could indicate that it can provide a `Span`":

> "An earlier version of this proposal proposed a `ContiguousStorage` protocol by
> which a type could indicate that it can provide a `Span`. `ContiguousStorage`
> would form a bridge between generically-typed interfaces and a performant concrete
> implementation."

It was **not** proposed, for two reasons quoted verbatim:

> "Two issues prevent us from proposing it at this time: (a) the ability to suppress
> requirements on `associatedtype` declarations was deferred during the review of
> SE-0427, and (b) we cannot declare a `_read` accessor as a protocol requirement."

And `Span` itself is a **capability yielded by a scoped borrow**, not an exposed
storage member; the scoped variant *"yields an element whose lifetime is scoped
around this particular access, as opposed to matching the lifetime dependency of the
`Span` itself"*
([SE-0447](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)).
[Verified: 2026-05-30]

**Crucially for the Institute's wall:** even the *would-be* `ContiguousStorage`
protocol bridges to a `Span` (T4), **not** to a raw escaping `pointer(at:)`. Swift's
own designers hit the *same* limitation the Institute hit — you cannot put a
`_read`-accessor (the borrow-yielding accessor) as a protocol requirement, and you
could not suppress `Copyable` on the associated type — and their response was to
**ship the `Span` capability and DEFER the storage-bearing protocol entirely**, not
to expose a storage type. Swift is T3 (scoped) + T4 (capability); it has never been T1.

### 2. Rust — T2 (allocator strategy) + T4 (deref-to-slice capability); T1 only as a perennially-unstable pre-RFC

**Allocator is a STRATEGY type param (T2), not base exposure.** `Vec`'s signature:

```rust
pub struct Vec<T, A = Global> where A: Allocator { /* private fields */ }
```

The allocator `A` is a *storage-strategy* type parameter (controls allocate/deallocate
behaviour); the actual buffer fields are **private**
([std::vec::Vec](https://doc.rust-lang.org/std/vec/struct.Vec.html)). [Verified: 2026-05-30]

**The base is exposed as a CAPABILITY via deref-to-slice (T4), not a named storage
type.** `Vec` implements `Deref` with `type Target = [T]`, so `&Vec<T>` coerces to
`&[T]` and slice methods become available; there is **no** `type Storage = [T]`
associated type. `as_slice(&self) -> &[T]` and `as_ptr(&self) -> *const T` yield a
*borrowed view* / raw pointer; the slice is "a borrowed view of the vector's contents,
not an owned storage field"
([std::vec::Vec](https://doc.rust-lang.org/std/vec/struct.Vec.html)). [Verified: 2026-05-30]

The blanket-conversion traits (`AsRef<[T]>`, `Borrow<[T]>`, `Deref<Target=[T]>`) are
the idiomatic "expose contiguous contents" surface across Rust — and every one of
them yields a **slice view** (a capability), never a stored storage type
([Deref vs AsRef vs Borrow](https://dev.to/zhanghandong/rust-concept-clarification-deref-vs-asref-vs-borrow-vs-cow-13g6)).

**The one place Rust attempts T1 — the Storage API — is the cautionary tale.** The
"Storage API" pre-RFC proposes a `Storage` trait with an associated **`Handle`** type
(opaque, *not* a pointer — precisely so inline/relocatable storage is expressible,
which `Allocator` cannot), refined by `MultipleStorage`/`StableStorage`/`PinningStorage`.
It remains **a pre-RFC in active design with no stabilization** (May 2023 onward),
with open questions on `dyn Storage`, clone semantics, and handle fungibility:
"storage-as-trait abstraction remains experimental and unstabilized in standard Rust"
([Pre-RFC: Storage API](https://internals.rust-lang.org/t/pre-rfc-storage-api/18822)).
[Verified: 2026-05-30] (Cross-confirmed by internal `storage-buffer-abstraction-analysis.md`
§2.3, which records the same 2+-year non-stabilization.)

Note the divergence even *within* the Rust T1 attempt: its associated type is an
opaque **`Handle`** (a `Copy` token, often a `u32` index or `()` for inline), *not* a
storage object exposing `pointer(at:)`. The Institute's proposal exposes a storage
object whose method *returns an escaping `UnsafeMutablePointer`*. So Rust's nearest
T1 analog is both (i) unstabilized and (ii) deliberately *not* pointer-exposing.

### 3. C++ — T2 (allocator) + T4 (contiguous_range concept); never T1

**Allocator is a STRATEGY template param (T2).** `std::vector<T, Allocator>` and PMR
(`std::pmr::polymorphic_allocator`) parameterize the *allocation strategy*; `data()`
returns a raw `T*` accessor but there is no exposed storage *type* on any abstraction.
P3002R1 (WG21, 2024) standing policy is that new facilities accept an *allocator*, not
that they expose a base type
([P3002R1](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2024/p3002r1.html);
internal `storage-buffer-abstraction-analysis.md` §2.3).

**Contiguity is a CONCEPT (T4), the canonical modern form.** C++20 `<ranges>` models
"contiguous" as a *concept requiring a data capability*, verbatim:

```cpp
template<class T>
concept contiguous_range =
    random_access_range<T> && contiguous_iterator<iterator_t<T>> &&
    requires(T& t) {{ ranges::data(t) } -> same_as<add_pointer_t<range_reference_t<T>>>;};
```

The concept requires that **`ranges::data(t)` yields a pointer** — a *capability*,
not an exposed storage type. "The elements of a `contiguous_range` are stored
sequentially in memory and can be accessed using pointer arithmetic"
([Microsoft Learn — `<ranges>` concepts](https://learn.microsoft.com/en-us/cpp/standard-library/range-concepts?view=msvc-170);
[cppreference — contiguous_range](https://en.cppreference.com/w/cpp/ranges/contiguous_range.html)).
[Verified: 2026-05-30] `std::span` is itself a *non-owning view* (a capability over a
contiguous sequence), not a stored member of the container it views.

This is the strongest external statement of the alternative the Institute should
adopt: **contiguity-as-a-concept**, where the abstraction requires the *ability to
produce a base pointer* (`ranges::data` ⇔ Swift `span` / `pointer(at:)`-capability),
not the *possession of a base-exposing storage type*.

### 4. Others — Zig (T2), Python (T3)

**Zig — explicit allocator (T2).** `std.mem.Allocator` is a struct (a manual VTable)
*passed in* to every function that needs memory; no collection trait carries a storage
type, and the "no hidden allocations" principle keeps allocation an explicit
*strategy* parameter, never an exposed base
([Zig Allocator](https://github.com/ziglang/zig/blob/master/lib/std/mem/Allocator.zig);
internal `storage-buffer-abstraction-analysis.md` §2.3).

**Python buffer protocol / PEP 3118 — scoped C-level base + metadata (T3).** This is
the closest *spiritual* analog to "expose a base pointer + metadata," and it is
instructive that it is **T3, not T1**. The base pointer is exposed via a C struct
`Py_buffer` (`void *buf;` base pointer, `Py_ssize_t len;`, plus `format`/`ndim`/
`shape`/`strides`/`suboffsets`/`readonly` metadata) — but only through a **get/release
lifecycle**:

> Acquire: `int PyObject_GetBuffer(PyObject *obj, Py_buffer *view, int flags)`
> Release: `void PyBuffer_Release(PyObject *obj, Py_buffer *view)` —
> "Callers ... must make sure that this function is called when memory previously
> acquired from the object is no longer needed."

The buffer is "a temporary, scoped window into memory requiring explicit release — not
a persistent type attribute," and the caller must keep a reference to `obj` until
release
([PEP 3118](https://peps.python.org/pep-3118/);
[CPython Buffer Protocol C-API](https://docs.python.org/3/c-api/buffer.html)).
[Verified: 2026-05-30] So even the one "expose a base pointer" protocol in wide use is
a **borrowed, lifetime-managed view** (T3), structurally the same shape as Swift's
`with…`/`Span` scoped access — *not* a permanently-exposed storage member on a
high-level abstraction.

---

## Taxonomy fill-in

| Ecosystem | T1 storage-as-type | T2 allocator strategy | T3 scoped accessor | T4 contiguous capability/concept |
|-----------|:---:|:---:|:---:|:---:|
| **Swift stdlib** | — (proposed `ContiguousStorage`, **deferred**; SE-0256 **rejected**) | (`ContiguousArray` is a *type*, not a param) | ✓ `with…IfAvailable` | ✓ `Span` / would-be `ContiguousStorage`→`Span` |
| **Rust** | only as **unstable pre-RFC** (Storage API; `Handle`, not pointer) | ✓ `Vec<T, A: Allocator>` | (slice borrow is scope-bounded by lifetimes) | ✓ `Deref<Target=[T]>`, `AsRef<[T]>`, `as_slice` |
| **C++** | — | ✓ `vector<T, Alloc>`, PMR | ✓ `data()` raw accessor | ✓ `contiguous_range` concept, `std::span` |
| **Zig** | — | ✓ explicit `Allocator` param | (`[]T` slice handed back) | — |
| **Python** | — | — | ✓ `Py_buffer` get/release | — |

**No surveyed mainstream, stabilized ecosystem exposes the storage object as an
associated/member TYPE on a buffer/collection abstraction surface (T1).** The only
T1 instance is Rust's Storage API — **unstabilized after 2+ years**, and even it
exposes an opaque `Handle`, not a pointer-vending storage object.

---

## Adversarial check

### Why does no stabilized ecosystem do T1? (the contextualization step, [RES-021])

Three independent forces, each confirmed by primary sources:

1. **Encapsulation / evolution.** Putting the storage *type* on the public surface
   freezes the storage representation into the abstraction's ABI/API. Rust keeps
   `Vec`'s fields private and exposes only a slice *view* precisely so the
   representation can evolve; C++ exposes only `data()`/`size()`. Exposing a storage
   *type* is the one thing all four avoid.

2. **Lifetime / aliasing safety.** A stored, escaping base is an aliasing hazard. Both
   Swift (`Span` scoped borrow) and Python (`Py_buffer` get/release) **deliberately
   scope** the base to a bounded access so the exporter controls its validity window.
   T1 hands out an escaping `pointer(at:)` whose validity is no longer scoped by the
   abstraction — exactly the hazard the scoped designs exist to prevent.

3. **The `~Copyable` / `_read`-accessor wall is not incidental — it is Swift telling
   you T1 is the wrong shape.** SE-0447's two blockers (cannot suppress `Copyable` on
   an `associatedtype`; cannot put a `_read` accessor in a protocol requirement) are
   the *same* wall the Institute hit. Swift's authors treated that wall as a reason to
   **defer the storage-bearing protocol and ship the `Span` capability instead** — not
   as a defect to route around by exposing the raw storage core.

### Is the Institute's case genuinely different? (it needs an *escaping* base)

The Institute's distinguishing need is real: it wants a **borrow-iterator over a
`~Copyable` element**, which requires an *escaping* element address that `Span`'s
scoped accessor cannot give. This is the one way the case differs from the stdlib's.
But the survey shows the response to that exact need, everywhere it has arisen:

- Swift: defer the storage protocol; keep the capability (`Span`), accept the
  iteration gap as a *capability composition* problem, not a storage-exposure problem.
- Rust: the escaping-handle need is *exactly* what the Storage API's opaque `Handle`
  was invented for — and it has **not** stabilized; and notably it is a `Handle`, not
  a pointer-vending storage object, so even Rust did not expose `pointer(at:)` on the
  surface.

And the Institute already has a non-T1 answer in hand: the **APPROVED**
`cross-layer-capability-protocol-model.md` routes the *escaping-base* read surface to
the orthogonal **`Span.Protocol`** (a `span` capability requirement, with
`withUnsafeBufferPointer` as the C-interop escape) and composes iteration via
`extension … where Self: Iterable`. A `~Copyable` borrow-iterator is the
`Iterator.Borrow` concern composed onto whichever capability core can vend a base —
*without* `Buffer.Protocol` exposing a `Storage` associated type
(`cross-layer-capability-protocol-model.md` §3.4 lines 188–204). The model's own words
on the buffer layer: it **"Does NOT refine `Storage.Protocol` (has-a)"** and
**"`span` stays on `Span.Protocol` for contiguous variants"** (line 203).

### Why-not-compose-existing-primitives ([RES-018] case (b), domain-owned vocabulary)

This proposal is not a new cross-cutting primitive; it reshapes an existing
domain-owned protocol (`Buffer.Protocol`). The composition alternative is already
designed and SIL-proven: a generic algorithm over `some Storage.Protocol` is the cold
path (0 `witness_method` cross-module, per the `storage-protocol-specialization`
experiment), and the contiguous-read capability lives on `Span.Protocol`.
The borrow-iterator can be vended by `extension Iterable where Self:
Span.Protocol` (capability) — **not** by `extension Iterable where Self:
Buffer.Protocol` reaching through an exposed `Storage` type. Composition covers the
use case; T1 is not required.

---

## Outcome

**Status: RECOMMENDATION.**

**Verdict: prior art does NOT support exposing `associatedtype Storage` on
`Buffer.Protocol` (T1). T1 is novel / anti-precedented among stabilized ecosystems.**
The dominant, cross-ecosystem pattern is **T4 — express contiguity / addressability
as a CAPABILITY/concept that *yields* a base** (`ranges::data` in C++20, `Span` /
would-be `ContiguousStorage`→`Span` in Swift, `Deref<Target=[T]>` / `as_slice` in
Rust), backed by **T2** allocator-*strategy* parameterization for the storage policy
(Rust `A: Allocator`, C++ allocator/PMR, Zig explicit allocator) and **T3** scoped
accessors where an escaping base would be unsafe (Swift `with…`, Python `Py_buffer`
get/release). The single T1 instance (Rust Storage API) is **unstabilized after 2+
years** and even it exposes an opaque `Handle`, not a pointer-vending storage object.

**Recommended alternative (concrete):** keep `Buffer.Protocol` as the *logical*
occupancy core (`count` / `isEmpty`) that **HAS-A** storage by composition but does
**not** expose it as an associated type — exactly the **APPROVED 2026-05-28**
`cross-layer-capability-protocol-model.md` shape. Vend the borrow-iterator from a
**contiguous-read CAPABILITY** — `Span.Protocol` (`span` +
`withUnsafeBufferPointer`) for contiguous disciplines, or a generic algorithm over
`some Storage.Protocol` for slot-addressed ones — composed via `extension Iterable
where Self: <capability>`. This is the T4 form, matches the SIL-proven two-lever
model, and avoids freezing storage into the buffer ABI and handing out an unscoped
escaping base.

**This recommendation aligns with — and is governed by ([RES-019]) — the APPROVED
internal model;** the T1 proposal would *contradict* that model's explicit
"`Buffer.Protocol` does NOT refine `Storage.Protocol`" decision. If T1 is still
desired, it must first explicitly override that APPROVED Tier-3 decision, with the
adversarial points above (encapsulation, escaping-base aliasing, the `_read`/
`~Copyable` wall as signal-not-defect) answered.

**Flagged / could-not-fully-verify.** (i) SE-0256's full text was summarized via a
secondary fetch of the proposal (status "Rejected" and "no storage associated type"
confirmed); the rejection-rationale nuance is paraphrased, not block-quoted. (ii) The
Rust Storage API summary is from the pre-RFC thread plus the internal Tier-3 doc;
"unstabilized as of May 2026" is inferred from the absence of a stabilized
`core::storage` (no RFC merged), not from a single dated statement. Both are
non-load-bearing for the verdict (the verdict rests on Swift SE-0447/0237 and C++
`contiguous_range`, both block-quoted from primary sources).

---

## References

### Swift (primary)
1. SE-0447 — Span: Safe access to contiguous storage (the `ContiguousStorage`-deferral quotes). https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md
2. SE-0237 — withContiguousStorageIfAvailable (scoped-accessor, no associated type). https://github.com/swiftlang/swift-evolution/blob/main/proposals/0237-contiguous-collection.md
3. SE-0256 — ContiguousCollection (**Rejected**; refinement, not a storage type). https://github.com/swiftlang/swift-evolution/blob/main/proposals/0256-contiguous-collection.md
4. Apple Developer — Collection (associated types: Iterator/Index/SubSequence/Indices; no Storage). https://developer.apple.com/documentation/swift/collection
5. Apple Developer — withContiguousStorageIfAvailable. https://developer.apple.com/documentation/swift/sequence/withcontiguousstorageifavailable(_:)

### Rust (primary)
6. std::vec::Vec — `Vec<T, A=Global>`, `Deref<Target=[T]>`, `as_slice`/`as_ptr`. https://doc.rust-lang.org/std/vec/struct.Vec.html
7. std::ops::Deref. https://doc.rust-lang.org/std/ops/trait.Deref.html
8. Pre-RFC: Storage API (the unstabilized T1 attempt; opaque `Handle`). https://internals.rust-lang.org/t/pre-rfc-storage-api/18822
9. Deref vs AsRef vs Borrow vs Cow (idiomatic slice-view exposure). https://dev.to/zhanghandong/rust-concept-clarification-deref-vs-asref-vs-borrow-vs-cow-13g6

### C++ (primary)
10. Microsoft Learn — `<ranges>` concepts (verbatim `contiguous_range` definition). https://learn.microsoft.com/en-us/cpp/standard-library/range-concepts?view=msvc-170
11. cppreference — std::ranges::contiguous_range. https://en.cppreference.com/w/cpp/ranges/contiguous_range.html
12. WG21 P3002R1 — Policies for using allocators (allocator-strategy standing policy). https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2024/p3002r1.html

### Others (primary)
13. PEP 3118 — Revising the buffer protocol (`Py_buffer`, scoped get/release). https://peps.python.org/pep-3118/
14. CPython C-API — Buffer Protocol (PyObject_GetBuffer / PyBuffer_Release lifecycle). https://docs.python.org/3/c-api/buffer.html
15. Zig std.mem.Allocator (explicit allocator passing). https://github.com/ziglang/zig/blob/master/lib/std/mem/Allocator.zig

### Internal research (governs per [RES-019])
16. `cross-layer-capability-protocol-model.md` (v1.1.0, APPROVED 2026-05-28, Tier 3) — Buffer HAS-A Storage, does NOT refine it; span on Span.Protocol; iteration composed `where Self: Iterable`. §3.4 lines 188–211.
17. `storage-buffer-abstraction-analysis.md` (v1.2.0, Tier 3) — Rust Storage API / C++ pmr / Zig survey; storage-strategy-under-one-protocol intractable; abstract at the ownership-capability level.
18. `storage-generic-buffer-core.md` (v1.1.0) — two-lever model; generic-over-`some Storage.Protocol` cold path proven 0-`witness_method`.
