# Stdlib Array Family Source Archaeology (6.3.2 → 6.4.x → main)

<!--
---
version: 1.0.0
last_updated: 2026-06-10
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

The five-layer container tower (Memory → `Memory.Allocator` → `Storage<Allocation>.Contiguous<Element>` →
`Buffer<S>` → ADTs) was ratified 2026-06-09 (`/Users/coen/Developer/.handoffs/PROPOSAL-tower-perfected-design.md`):
move-only substrate (R-1), CoW value semantics entering at the ADT tier via the column combinator
`Shared<Element, B>` (R-2), the binding drain-box rule (R-5), a deferred upstream filing for the `-O`
deinit-omission miscompile (R-6), and an accepted 2-allocation CoW cost with single-allocation fusion held
as a future internal option. This note is the dispatched source-archaeology study: how does the Swift
standard library *actually* implement `Array` and its relatives across the live release lines, and what
does that confirm, refute, or inform in the ratified design.

One correction this note exists to land: the ratified proposal's TL;DR justifies `Shared`'s conditional
copyability as *"the stdlib `Array` posture"* (`PROPOSAL-tower-perfected-design.md` §0). That phrasing is
wrong, and the dispatch asked for the definitive answer. Stdlib `Array` is **not** conditionally Copyable
and supports **no** `~Copyable` elements on any line (§Q2); the conditional-copyability precedent in stdlib
is `InlineArray` (eager-copy, no CoW), and upstream **explicitly considered and rejected** a
conditionally-copyable `Array` (SE-0527). The *design* the proposal ratified — explicit move-only column +
explicit CoW column — is unaffected and is in fact the shape upstream itself converged on (§Q7); only the
justification sentence misattributes it.

### Ref discovery and pinning

The dispatch asked for "6.4, 6.5, main", guessing `release/6.4` / `release/6.5`. Reality in the reference
clone (`/Users/coen/Developer/swiftlang/swift`, fetched 2026-06-09):

| Asked | Actual ref pinned | SHA | Date | Notes |
|---|---|---|---|---|
| (baseline) | tag `swift-6.3.2-RELEASE` — **"632"** | `cd8d8ad0019` | 2026-05-10 | Current stable; the toolchain the institute builds with. Added as baseline so the trajectory has substance. |
| "6.4" | tag `swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-06-07-a` — **"64x"** | `0b7717dc5b6` | 2026-06-06 | The 6.4 line exists upstream as branch `release/6.4.x` (ls-remote verified); this is its latest published snapshot tag, *not* an ancestor of main. `release/6.4` (without `.x`) does not exist. |
| "6.5" | **does not exist** | — | — | No `release/6.5*` branch upstream (ls-remote) and no 6.5 tags. `main` is the 6.5-dev trunk. |
| "main" | local `main` — **"main"** | `6f5d855aedf` | 2026-06-10 | Trunk (= 6.5-dev). |

Method: three detached `git worktree`s under `/tmp/swift-arch/{632,64x,main}`; read-only throughout (no
checkout of the primary tree, no builds, no commits). All file:line citations below are against these three
pinned SHAs; paths are relative to the worktree root, defaulting to `stdlib/public/core/`.

### Verification protocol

Per [RES-020], every load-bearing claim below was re-derived by independent parallel verification agents on
2026-06-10: tree claims re-read from the pinned worktrees; web claims re-fetched from the primary source
(swift-evolution raw files, forums.swift.org JSON, swift-collections at pinned commit
`af174fe4476842b2558069e64feae8ddc2e665ff`, GitHub PR API). Claims are tagged `[Verified: 2026-06-10]` at
the granularity of their citation. The verification pass caught and corrected two discovery-agent errors
(the `@_lifetime`-vs-`@lifetime` spelling on 632, §Q5; the OutputSpan SE number, §References) — both
corrections are incorporated below.

## Question

1. **CoW mechanism** — how exactly does `Array` do copy-on-write, and how does it map onto `Shared<Element, B>`?
2. **`~Copyable` elements** — the definitive per-type, per-ref element constraints (settling a prior over-claim).
3. **Teardown** — who destroys elements; does it confirm the drain-box rule (R-5)?
4. **One-allocation layout** — the exact tail-allocation mechanism; the template for future single-alloc fusion.
5. **Span surface** — internals + vending model; SE-0465 status; does it validate span-canonical?
6. **InlineArray** — the inline-storage mechanism vs our `Store.Inline` `@_rawLayout`.
7. **Façade precedent** — does a conditionally-Copyable CoW container exist anywhere (stdlib, swift-collections, Swift Evolution)?
8. **Miscompile neighborhood** — stdlib annotations/idioms near the R-6 shape; anything to copy?

## Headline findings

### F1 (Q2) — the `~Copyable` truth

**Stdlib `Array`, `ContiguousArray`, and `ArraySlice` accept Copyable elements only, on all three refs, with
zero movement across the trajectory.** [Verified: 2026-06-10]

- `@frozen @_eagerMove public struct Array<Element>: _DestructorSafeContainer {` — identical on 632/64x/main
  (`Array.swift:299–301` on all three). No `~Copyable` anywhere in the generic clause.
- Negative proof: `grep -n '~Copyable'` over `Array.swift`, `ContiguousArray.swift`, `ArraySlice.swift`,
  `ArrayBuffer.swift`, `ContiguousArrayBuffer.swift`, `ArrayBufferProtocol.swift`, `ArrayShared.swift`
  returns **zero matches on each of the three refs** (exit 1).
- The types that DO take `~Copyable` elements (all refs): `InlineArray<let count: Int, Element: ~Copyable>:
  ~Copyable` (`InlineArray.swift:101`), `Span<Element: ~Copyable>: ~Escapable, Copyable, BitwiseCopyable`
  (`Span/Span.swift:29`), `MutableSpan<Element: ~Copyable>: ~Copyable, ~Escapable`
  (`Span/MutableSpan.swift:23–24`), `OutputSpan<Element: ~Copyable>: ~Copyable, ~Escapable`
  (`Span/OutputSpan.swift:25`), and — load-bearing for §Q4 — `open class ManagedBuffer<Header, Element:
  ~Copyable>` (`ManagedBuffer.swift:38`, **including on 632**) plus
  `ManagedBufferPointer<Header, Element: ~Copyable>: Copyable`.
- Trajectory signal: files mentioning `~Copyable` under `stdlib/public/core`: 31 (632) → 42 (64x) → 42
  (main) — the 6.4 jump is protocol generalization (SE-0499, "Support ~Copyable, ~Escapable in simple
  standard library protocols", Implemented Swift 6.4), **not** Array-family movement.
- Upstream's chosen direction for noncopyable dynamic arrays is **separate sibling types**, not a
  conditional `Array`: SE-0527 "RigidArray and UniqueArray" (status **Accepted in Principle**); its
  implementation PR swiftlang/swift#87521 merged to main 2026-06-04 and was reverted the same day
  (PR #89696: "CMake changes are needed before this can go in (need to start using response files)") — a
  mechanical revert; landing is imminent. The pre-revert tree shows
  `public struct UniqueArray<Element: ~Copyable>: ~Copyable` with **no** Copyable conformance
  (`git show ec1c9320b97:stdlib/public/core/UniqueArray/UniqueArray.swift:42`). [Verified: 2026-06-10]

So: the previously circulated claim that "a conditionally-Copyable Array is stdlib's posture" is **retired**.
Stdlib's posture is: CoW containers are Copyable-only; noncopyable-element dynamic arrays are a separate,
unconditionally move-only family; the only conditionally-Copyable container is `InlineArray`, which is
**eager-copy** (SE-0453: "there are no copy-on-write semantics; it is eagerly copied").

### F2 (Q7) — façade precedent: none, anywhere

**No shipped or in-progress design anywhere combines value-semantic CoW for Copyable elements and move-only
behavior for `~Copyable` elements in a single container type.** Surveyed: the three stdlib refs,
apple/swift-collections at `af174fe` (main HEAD, 2026-06-09), and Swift Evolution
(accepted/in-review/pitched + visions/). [Verified: 2026-06-10] The full taxonomy of what exists:

| Category | Instances | Copyability clause |
|---|---|---|
| (i) Conditionally-Copyable **eager-copy** container | `InlineArray` (shipped, 6.2); `Optional` (enum-shaped, SE-0532 generalizing) | `extension InlineArray: Copyable where Element: Copyable {}` (`InlineArray.swift:107`) |
| (ii) Conditionally-Copyable **CoW-box** container | **NONE — zero instances found anywhere** | — |
| (iii) Unconditionally move-only dynamic containers | swift-collections `UniqueArray`/`RigidArray` (stable since 1.3.0/1.5.0), `Unique/RigidDeque`, trait-gated Set/Dictionary variants, `UniqueBox` (SE-0517, Accepted); stdlib SE-0527 (imminent) | e.g. `public struct UniqueArray<Element: ~Copyable>: ~Copyable {` (swift-collections `Sources/BasicContainers/UniqueArray/UniqueArray.swift:66`); zero `extension …: Copyable` conformances anywhere in Sources (tarball grep) |
| (iv) Copyable-only CoW containers | stdlib `Array`/`Set`/`Dictionary`/`String` | unconditional Copyable |

Three decisive pieces of evidence:

1. **SE-0527 considered exactly the façade design and rejected it** — Motivation: *"A (superficially) more
   attractive idea would be to make `Array` _conditionally copyable_, depending on the copyability of its
   elements"* … the two named blockers being that Swift cannot check copyability of a type argument at
   runtime, and *"consulting the Swift runtime every time a function needs to mutate an array instance
   seems unlikely to be acceptable"*; Alternatives: *"it would be wholly impractical in practice. … That
   said, this proposal does nothing to rule out such work in the future."* Author confirmation in the pitch
   thread (Alejandro Alonso, post #7): *"`Array`'s copy on write nature is fundamentally incompatible with
   non-copyable elements like I laid out in the motivation. There is no extending `Array`."*
2. **The nearest artifact is swift-collections' `Shared<Storage: ~Copyable>`**
   (`Sources/ContainersPreview/Types/Shared.swift:28` @ `af174fe`) — *"A utility adapter that wraps a
   noncopyable storage type in a copy-on-write struct"*: a refcounted `final class _Box` with
   `@exclusivity(unchecked) var storage: Storage`, `isUnique()` = `isKnownUniquelyReferenced(&_box)`,
   `ensureUnique(cloner:)`, `edit(shared:unique:)`. It validates the institute's *mechanism* (refcounted box
   + uniqueness check + explicit clone) almost name-for-name — **but** it is *unconditionally* Copyable
   (no conditional conformance), documented as internal-implementation-only ("Like `ManagedBufferPointer`
   … aren't designed to be exposed as public"), gated `#if false // TODO`, and has zero consumers.
3. **Upstream's settled shape is two parallel families** — John McCall in the SE-0517 review (post #30/#58):
   `UniqueBox` noncopyable now, and *"it would also be useful to have a copyable variant of the type … which
   would use copy-on-write to manage the value under sharing"* — i.e. a sibling-type matrix
   {Array, Dictionary, Set, Box} (CoW, Copyable) vs {UniqueArray, UniqueDictionary, UniqueSet, UniqueBox}
   (move-only), with the copyable `Box` *"unclear whether … worth having"* (Ben Cohen, #60).

**Verdict for the tower.** The ratified two-column design (`Array<Buffer<…>.Linear>` move-only default;
`Array<Shared<E, Buffer<…>.Linear>>` explicit CoW) is **convergent with upstream's chosen direction** —
two explicit families, mechanism-equivalent to swift-collections' staged `Shared`. The *façade* variant (one
`Array<Element>` baking `Shared` in, `Copyable where Element: Copyable`) is **genuinely novel territory with
zero precedent**, and SE-0527's objection names its real design risk: in `Element: ~Copyable`-generic code,
copyability of the instantiation is a runtime fact, so a single conditionally-copyable type's mutations
either need a runtime copyability dispatch (inexpressible today, and per-mutation overhead) or must be
API-split per column constraint — at which point the façade collapses into the explicit two-column design
anyway. Combined with the R-6 miscompile living in exactly the façade's shape (§Q8), the recommendation is
to keep the façade **shelved** and the explicit `Shared` column **as ratified**.

## Q1 — The CoW mechanism

All quotes from main; verified byte-identical in mechanism on 632/64x (§Trajectory). [Verified: 2026-06-10]

The mutation gateway (`Array.swift:349–356`):

```swift
@inlinable
@_semantics("array.make_mutable")
@_effects(notEscaping self.**)
internal mutating func _makeMutableAndUnique() {
  if _slowPath(!_buffer.beginCOWMutation()) {
    _buffer = _buffer._consumeAndCreateNew()
  }
}
```

Every public mutation routes through this (subscript `_modify`, `append` via
`_makeUniqueAndReserveCapacityIfNotUnique` with `@_semantics("array.make_mutable")`, `Array.swift:1137–1146`)
and is paired with `_endMutation()` (`@_semantics("array.end_mutation")`, `Array.swift:373–378`). The
uniqueness check bottoms out in builtins (`BridgeStorage.swift:83,146`):
`Bool(Builtin.beginCOWMutation(&rawValue))` / `Bool(Builtin.beginCOWMutation_native(&rawValue))` — a
COW-flagged variant of the uniqueness check (the flag side is debug-only `COW_CHECKS` machinery;
`ContiguousArrayBuffer.swift:15–18`). The *public* door is the same primitive the tower uses:
`isKnownUniquelyReferenced<T: AnyObject>(_:) { _isUnique(&object) }` (`ManagedBuffer.swift:712–715`) →
`Bool(Builtin.isUnique(&object))` (`Builtin.swift:765–768`); `ManagedBufferPointer.isUniqueReference()` is
the same call (`ManagedBuffer.swift:491–493`).

The copy path (`ArrayBuffer.swift:204–229`, `_consumeAndCreateNew`): allocate a fresh
`_ContiguousArrayBuffer(_uninitializedCount:minimumCapacity:)` with `_growArrayCapacity`, then — the detail
worth copying — **if the old buffer was unique but merely under-capacity, elements are *moved*, not copied**
(`dest.moveInitialize(from: mutableFirstElementAddress, count: c); _native.mutableCount = 0`); only the
genuinely-shared case copies (`_copyContents`). Out-of-place mutations go through `_arrayOutOfPlaceUpdate`
(`ArrayShared.swift:268–336`).

Mapping onto the ratified `Shared<Element, B>`:

| stdlib | tower `Shared` column | parity |
|---|---|---|
| `Array` struct = one word (buffer ref) | `Shared` struct = one `Box<B>` ref | same |
| `_makeMutableAndUnique()` at every public mutation boundary | `ensureUnique()` first in every `Shared`-column mutating op (ratified mechanic #2) | same placement — "at the semantic API boundary", never in the seam |
| `Builtin.beginCOWMutation` (stdlib-private flagged variant) | `isKnownUniquelyReferenced(&box)` → `Builtin.isUnique` | same primitive family; the flagged variant + `@_semantics("array.make_mutable"/"end_mutation")` + SIL COW-optimization (uniqueness-check hoisting) are **stdlib-private advantages the tower cannot replicate**; the mitigation available to us is `@inlinable` + `_slowPath`-style branch shaping, which stdlib also uses |
| unique-but-growing path **moves** elements | `Buffer.Linear` grow path | verify at W4 that the `Shared` clone path distinguishes unique-grow (move) from shared-clone (copy) — stdlib's `bufferIsUnique` flag is the template |
| count/capacity live in the heap header (`_ArrayBody`) | count lives in `B` (inside the box) | same locality (one deref per count read on the CoW column) |

## Q2 — Element constraints, per type, per ref

All declarations re-verified on all three refs; line numbers per ref where they differ. [Verified: 2026-06-10]

| Type | Declaration (verbatim core) | 632 | 64x | main | `~Copyable` elements? |
|---|---|---|---|---|---|
| `Array` | `@frozen @_eagerMove public struct Array<Element>: _DestructorSafeContainer` | Array.swift:301 | :301 | :301 | **NO** |
| `ContiguousArray` | `@frozen @_eagerMove @safe public struct ContiguousArray<Element>: _DestructorSafeContainer` | ContiguousArray.swift:39 | :39 | :39 | **NO** |
| `ArraySlice` | `@frozen public struct ArraySlice<Element>: _DestructorSafeContainer` | ArraySlice.swift:117 | :117 | :117 | **NO** |
| `_ArrayBuffer` | `@usableFromInline @frozen internal struct _ArrayBuffer<Element>: _ArrayBufferProtocol` | ArrayBuffer.swift:27 | :27 | :27 | NO |
| `_ContiguousArrayBuffer` | `@_fixed_layout internal struct _ContiguousArrayBuffer<Element>: _ArrayBufferProtocol` | ContiguousArrayBuffer.swift:338 | :339 | :339 | NO |
| `_ContiguousArrayStorage` | `@_fixed_layout @usableFromInline internal final class _ContiguousArrayStorage<Element>: __ContiguousArrayStorageBase` | ContiguousArrayBuffer.swift:132–134 | :132–134 | :132–134 | NO |
| `__ContiguousArrayStorageBase` | non-generic `internal class … : __SwiftNativeNSArrayWithContiguousStorage` | SwiftNativeNSArray.swift:519 | :519 | :519 | n/a |
| `InlineArray` | `@frozen @safe @_addressableForDependencies public struct InlineArray<let count: Int, Element: ~Copyable>: ~Copyable` | InlineArray.swift:101 | :101 | :101 | **YES** — `Copyable where Element: Copyable` (:107), `BitwiseCopyable where Element: BitwiseCopyable` (:110), `@unchecked Sendable where Element: Sendable & ~Copyable` (:113) |
| `Span` | `@frozen @safe public struct Span<Element: ~Copyable>: ~Escapable, Copyable, BitwiseCopyable` | Span/Span.swift:29 | :29 | :29 | **YES** — Span itself stays unconditionally Copyable (it is a borrow) |
| `RawSpan` | `@frozen @safe public struct RawSpan: ~Escapable, Copyable, BitwiseCopyable` (non-generic) | RawSpan.swift:29 | :29 | :29 | n/a |
| `MutableSpan` | `@safe @frozen public struct MutableSpan<Element: ~Copyable>: ~Copyable, ~Escapable` | MutableSpan.swift:23–24 | same | same | **YES** |
| `OutputSpan` | `@safe @frozen public struct OutputSpan<Element: ~Copyable>: ~Copyable, ~Escapable` | OutputSpan.swift:25 | :25 | :25 | **YES** |
| `ManagedBuffer` | `@_fixed_layout open class ManagedBuffer<Header, Element: ~Copyable>` | ManagedBuffer.swift:38 | :38 | :38 | **YES — including on 6.3.2** |
| `ManagedBufferPointer` | `public struct ManagedBufferPointer<Header, Element: ~Copyable>: Copyable` | ManagedBuffer.swift:244–247 | :253–256 | :253–256 | **YES** |

Negative proof (the over-claim killer): on each ref, `grep -n '~Copyable'` across the seven Array-family
files listed in §F1 → **zero hits** (exit 1). The Array trio also acquired no conditional `Copyable`
extension anywhere (their only conditional conformances are `Equatable`/`Hashable`/`@unchecked Sendable
where Element: Sendable`).

## Q3 — Teardown, and the R-5 verdict

**The drain-box rule (R-5) is stdlib-convergent: element teardown is owned by the refcounted storage
class's `deinit`.** The proposal §1.4 asserted this convergence; here is the verified primary evidence.
[Verified: 2026-06-10]

`_ContiguousArrayStorage` deinit — **identical on all three refs** (`ContiguousArrayBuffer.swift:136–140`):

```swift
@inlinable
deinit {
  unsafe _elementPointer.deinitialize(count: countAndCapacity.count)
  _fixLifetime(self)
}
```

with `_elementPointer` projected from the tail allocation
(`UnsafeMutablePointer(Builtin.projectTailElems(self, Element.self))`, `ContiguousArrayBuffer.swift:308`),
and `_fixLifetime` (`LifetimeManager.swift:94–98`, `@_transparent … Builtin.fixLifetime(x)`) pinning the
object so ARC cannot shorten its lifetime while element destructors run. Count/capacity live in the object
header: `final var countAndCapacity: _ArrayBody` on the non-generic base
(`SwiftNativeNSArray.swift:517–529`), wrapping the C-visible `_SwiftArrayBodyStorage { count;
_capacityAndFlags }` (SwiftShims `GlobalObjects.h`).

Differences from the tower's mechanism, same responsibility placement: stdlib's box destroys elements
*directly* (pointer `deinitialize` over the tail region) because the elements live in the box's own
allocation; the tower's `Box<B>` drains through the move-only buffer's public API (R-5) because the region
is a separate allocation. Equivalent law: **the class deinit owns teardown; nothing above it does** —
ManagedBuffer's own deinit is explicitly empty (`@_preInverseGenerics @inlinable deinit {}`,
`ManagedBuffer.swift:66–68`) with the doc comment delegating teardown: it "destroys any live elements in
the `deinit` of a subclass" (`ManagedBuffer.swift:34`).

Two adjacent facts worth recording:

- **Uninitialized-array dealloc zeroes count first**: `_deallocateUninitializedArray`
  (`@_semantics("array.dealloc_uninitialized")`, `ArrayShared.swift:63`) → `_deallocateUninitialized()`
  sets `_buffer.mutableCount = 0` ("Somewhat of a hack.", `Array.swift:1003`) so the storage deinit
  destroys zero elements — i.e. *count-driven drain*, exactly the tower's count-driven no-double-free
  argument in PROPOSAL §1.4.
- **The empty singleton is immortal**: all empty arrays share one statically-allocated
  `__EmptyArrayStorage` (`_swiftEmptyArrayStorage` C global; `ContiguousArrayBuffer.swift:121–127`), and
  the storage deinit asserts it never deallocates it (`self !== _emptyArrayStorage`,
  `ContiguousArrayBuffer.swift:586–589`).

## Q4 — The single-allocation layout (fusion template)

The mechanism, end to end [Verified: 2026-06-10]:

1. **Allocate with tail elements** — `_ContiguousArrayBuffer.init(_uninitializedCount:minimumCapacity:)`
   (`ContiguousArrayBuffer.swift:348–382`):
   `Builtin.allocWithTailElems_1(getContiguousArrayStorageType(for: Element.self),
   realMinimumCapacity._builtinWordValue, Element.self)`. `ManagedBuffer.create` is the same call on `self`
   (`ManagedBuffer.swift:85–100`).
2. **Sizing/alignment (compiler lowering)** — `lib/IRGen/GenClass.cpp:820–842`
   `appendSizeForTailAllocatedArrays`: size is rounded up by the element alignment mask, then
   `ElemStride × Count` is added, and the allocation's `alignMask` is OR-ed with the element's. The runtime
   entry is `swift_allocObject(metadata, requiredSize, requiredAlignmentMask)`
   (`stdlib/public/runtime/HeapObject.cpp:127–130`).
3. **Header layout** — `HeapObject { HeapMetadata const *metadata; InlineRefCounts refCounts }`
   (SwiftShims `HeapObject.h:48–54`): 2 words. `ManagedBufferPointer` computes
   `_headerOffset = _roundUp(MemoryLayout<_HeapObject>.size, toAlignment: MemoryLayout<Header>.alignment)`
   and `_elementOffset = _roundUp(_headerOffset + MemoryLayout<Header>.size, toAlignment:
   MemoryLayout<Element>.alignment)` (`ManagedBuffer.swift:598–635`).
4. **Element base projection** — `Builtin.projectTailElems(self, Element.self)`
   (`ManagedBuffer.swift:120–123`; `ContiguousArrayBuffer.swift:431–434`).
5. **Capacity reclaim from the malloc bucket** — after allocating, capacity is *recomputed from the actual
   allocation size*: `allocSize = _mallocSize(ofAllocation: storageAddr)` →
   `realCapacity = endAddr.assumingMemoryBound(to: Element.self) - firstElementAddress`
   (`ContiguousArrayBuffer.swift:358–376`); `_mallocSize` wraps `_swift_stdlib_has_malloc_size()
   ? _swift_stdlib_malloc_size(ptr) : nil` (`Shims.swift:41–42`). `ManagedBuffer.capacity` does the same
   (`ManagedBuffer.swift:110–116`). The slack of the malloc size class becomes free capacity.

Net layout: `[ metadata | refCounts | (round to Header align) Header/_ArrayBody | (round to Element align)
elements… ]` — one allocation.

**The userland door.** `Builtin.*` is stdlib-internal; the only supported userland tail-allocation door is
`ManagedBuffer` / `ManagedBufferPointer` — and (F1 table) **both admit `Element: ~Copyable` on all three
refs, including the 6.3.2 toolchain the institute pins**. So the deferred single-alloc fusion has a
supported door today, for both columns' element kinds. Two recorded tensions, unchanged by this finding:

- The ratified proposal already names tail-allocation a **layer collapse** ("the class IS the memory" —
  PROPOSAL §1.2 footnote ¹): fusion would make `Shared`'s internal `Box` bypass Memory/Allocator. It stays
  what the ratification said it is: a future, *non-breaking, internal* optimization (the box is internal),
  to be taken only on measurement.
- Strict-memory-safety friction is arriving: the 6.4.x line adds `@unsafe` to
  `withUnsafeMutablePointerToHeader/Elements/Pointers` on both ManagedBuffer types (632→64x delta, six
  methods).

Independently adoptable now (no fusion): the **malloc-size capacity-reclaim idiom** (5) at the tower's
heap-allocation leaf, and the **immortal empty singleton** (§Q3) for empty-ADT fast paths.

## Q5 — Span surface

**Representation (all refs, unchanged):** `Span` wraps a raw pointer + count —
`internal let _pointer: UnsafeRawPointer?` / `internal let _count: Int` (`Span/Span.swift`, decl at :29).
`MutableSpan`/`OutputSpan` hold `UnsafeMutableRawPointer?` (+ `capacity`/`_count` for OutputSpan). SE-0465
("Standard Library Primitives for Nonescapable Types", Implemented Swift 6.2) explicitly **postpones**
`~Escapable` pointer pointees: *"we have to postpone that work until we are able to precisely reason about
lifetime requirements"*. So on every current line, span types are safe *surfaces* over an irreducible
internal unsafe pointer — precisely the posture `store-inline-span-vs-in-place-pointer.md` (ACCEPTED)
already adopted for `Store.Inline`; its REMOVE-WHEN tracker (SE-0465 pointer-pointee deferral) is confirmed
still-open on main. [Verified: 2026-06-10]

**Vending from Array** (`Array.swift:1758/1885` on main; same shape on 632 at :1745/:1865):

```swift
public var span: Span<Element> {
  @_lifetime(borrow self)
  @_alwaysEmitIntoClient
  borrowing get {
    …
    let span = unsafe Span(_unsafeStart: pointer, count: count)
    return unsafe _overrideLifetime(span, borrowing: self)
  }
}
public var mutableSpan: MutableSpan<Element> {
  @_lifetime(&self)
  mutating get {
    _makeMutableAndUnique()        // ← CoW boundary BEFORE vending the mutable view
    …
    return unsafe _overrideLifetime(span, mutating: &self)
  }
}
```

Three findings for the tower:

1. **`mutableSpan` is a CoW boundary**: stdlib runs `_makeMutableAndUnique()` *before* vending. The
   `Shared` column's scoped/yielding span at the box hop (ratified §1.3 finding 2) must do `ensureUnique()`
   first — same placement.
2. **Stdlib itself uses `_overrideLifetime`** to re-anchor the span to `self` in returning accessors — the
   exact bridge the institute carries as "returning-model technical debt" (28 sites). The debt is
   stdlib-idiomatic, not an institute deviation; the yielding-where-possible preference still stands, but
   parity with stdlib is now documented.
3. **Lifetime-annotation spelling is in mid-migration** (verification-corrected finding): 632 spells it
   `@_lifetime(…)` exclusively (`Span/Span.swift`: 0 × `@lifetime`); 64x and main spell Span-family
   internals mostly `@lifetime(…)` (32 ×) with `@_lifetime` remnants (4 ×) — and `Array.span`/`mutableSpan`
   accessors still carry `@_lifetime` on main (`Array.swift:1759,1886`). Institute code pinned to 6.3.2
   must keep `@_lifetime`; expect a renaming sweep when the build-gate moves to 6.4. No *numbered* SE
   proposal for lifetime dependencies exists yet (swift-evolution PRs #2305/#3145 are open, unmerged).
4. `OutputSpan` **owns partial teardown**: its `deinit` deinitializes the initialized prefix
   (`if _count > 0 { _start().withMemoryRebound(to: Element.self, capacity: _count) { … $0.deinitialize… } }`,
   `OutputSpan.swift:37–46`) — which is why stdlib's OutputSpan-based `Array.init(capacity:initializingWith:)`
   (present on all three refs; `Array.swift:1638` area on main) does the finalize-then-reset dance. The
   tower's `Buffer.Linear` OutputSpan affordances already mirror this; keep it.

Span-canonical (ACCEPTED 2026-06-09) is **validated**: spans are stdlib's only contiguous-region surface on
every line, `Span` stays Copyable even over `~Copyable` elements (a borrow is freely copyable), and the
sole-pointer-inside posture matches.

## Q6 — InlineArray's inline storage vs `Store.Inline`

Mechanism (all refs identical) [Verified: 2026-06-10]: storage is a **compiler-managed builtin aggregate** —
`internal var _storage: Builtin.FixedArray<count, Element>` under
`public struct InlineArray<let count: Int, Element: ~Copyable>: ~Copyable` with
`@_addressableForDependencies` on the struct (`InlineArray.swift:100–104`). Address projection goes through
borrow builtins, not stored pointers: `Builtin.unprotectedAddressOfBorrow(_storage)` (fast path) /
`Builtin.addressOfBorrow(_storage)` (`InlineArray.swift:125–155`, behind `$AddressOfProperty2`).
**InlineArray declares no `deinit` on any ref** (grep: zero hits in `InlineArray.swift` +
`_InlineArray.swift`) — element destruction is the compiler's, because `Builtin.FixedArray` is a managed
aggregate whose destroy is element-wise destroy.

That last fact is the structural explanation the conditional-deinit study (Tier 3) predicted: InlineArray
gets `extension InlineArray: Copyable where Element: Copyable {}` **only because it needs no user
`deinit`** — the SE-0427 law (`deinit ⟹ unconditionally ~Copyable`) never fires. The userland analogue of
`Builtin.FixedArray` is `@_rawLayout(likeArrayOf:count:)` (`Store.Inline`), which is *unmanaged bytes*:
teardown must be a user deinit, so the type is forced unconditionally `~Copyable` (Wall 1), and typed access
is irreducibly pointer-mediated (`nonescapable-storage-mechanisms.md`). Same corner, two privilege levels —
stdlib's escape hatch is a builtin the language does not expose. This *confirms* `occupancy-lives-in-the-leaf.md`'s
placement law (copyability flows from the leaf; inline `@_rawLayout` leaf ⇒ move-only) and marks the exact
upstream feature that would dissolve it (a userland managed fixed-size aggregate — none proposed anywhere;
checked in the §Q7 sweep).

Housekeeping facts: `_InlineArray.swift` declares `internal struct _InlineArray<let count: Int, Element:
~Copyable>: ~Copyable` — a stdlib-internal twin (no availability gate) of the public type, same
`Builtin.FixedArray` storage. The 632→main delta on both files is the subscript-accessor migration from
`unsafeAddress`/`unsafeMutableAddress` to **`borrow`/`mutate` accessors** with
`@_unsafeSelfDependentResult` (§Trajectory). Sugar `[n of T]` is SE-0483 (separate proposal; compiler-side).
Span vending exists on all refs (`InlineArray.swift:588/603`) via `_protectedAddress` +
`_overrideLifetime`.

## Q7 — Façade precedent (full record)

Covered in §F2. Supplementary record for completeness:

- **Stdlib trees**: `git grep -niE 'RigidArray|UniqueArray|DynamicArray|Hypoarray' -- stdlib docs` → zero
  on all three refs (the only whole-tree hits are an optimizer identifier and a test fixture). No
  noncopyable-container vision doc in the compiler repo; swift-evolution `visions/` has none either.
- **SE-0437**'s appendix `Hypoarray` (non-normative sketch) is the ancestor of the Unique/Rigid family —
  "replaces copy-on-write behavior with strict ownership control."
- **SE-0517 UniqueBox** (Accepted): `public struct UniqueBox<Value: ~Copyable>: ~Copyable` — the pitch's
  rationale is the same law the tower met: *"We can't make Box a copyable type because we need to be able
  to customize deinitialization"* (forums t/84014 post #1). The copyable CoW `Box` is future work, as a
  **separate type**.
- **swift-collections** (current main @ `af174fe`, 2026-06-09): `BasicContainers` DocC overview: *"Unlike
  `Array`, these new types do not support copy-on-write value semantics -- indeed, they aren't (implicitly)
  copyable at all, even if their element type happens to be copyable."* Release 1.3.0 notes introduce
  `UniqueArray` as *"a noncopyable array variant that takes away `Array`'s copy-on-write behavior."*
  Whole-Sources grep at the pinned commit: **zero** conditional `: Copyable` conformances.

## Q8 — Miscompile neighborhood and annotation inventory

**The R-6 shape is unexercised by stdlib.** The search for [generic class + `~Copyable` stored payload +
deinit-owned teardown] across `stdlib/public/core` and `stdlib/public/Synchronization` on main returns
exactly one generic class with a `~Copyable` parameter — `ManagedBuffer` — whose payload lives in the tail
allocation (not a stored property) and whose deinit is empty; `_ContiguousArrayStorage` (the only
deinit-draining generic storage class) is Copyable-elements-only; `Synchronization` stores `~Copyable`
values in `@_rawLayout(like: Value, movesAsLike) public struct _Cell<Value: ~Copyable>: ~Copyable` with a
*struct* deinit (`Cell.swift:17–44`) — Wall-1-conformant, no class box. [Verified: 2026-06-10] A targeted
GitHub issue search found no existing upstream report of the R-6 shape (`-O` + `isKnownUniquelyReferenced`
+ nested-generic `~Copyable` payload deinit omission) — distinct from `swift#86652` (cross-module
`@_rawLayout` value-witness misclassification). Consequences:

- There is **no stdlib idiom to copy** that guards the R-6 corner — stdlib simply never builds a CoW box
  whose payload has a user deinit. The drain-box rule (R-5) remains the institute's own, stdlib-*convergent*
  (§Q3) mitigation, and the ratified posture (preserve the repro durably; file upstream when ready) is
  unchanged — when filed, it will be novel, not a duplicate.
- The repro at `/tmp/cow-skip-repro/` is still in `/tmp` — the ratification (R-6) requires moving it into
  `Experiments/` durably; that action is pending and should ride the next tower commit wave.

**Annotation inventory** (main; the toolbox stdlib brings to the CoW path):

| Annotation | Where (example) | Transferable to the tower? |
|---|---|---|
| `@_semantics("array.make_mutable" / "array.end_mutation" / "array.uninitialized_intrinsic" / "array.dealloc_uninitialized" / 13 more `array.*` tags) | Array.swift:350,374; ArrayShared.swift:36,63 | **No** — SIL COWArrayOpt machinery is recognized for stdlib Array only |
| `Builtin.beginCOWMutation` / `endCOWMutation` | BridgeStorage.swift:83,146 | **No** — builtins; userland equivalent is `isKnownUniquelyReferenced` |
| `@_eagerMove` | `Array` :300, `ContiguousArray` :39 | Investigate — lifetime-shortening attribute on the CoW *wrapper* struct; interacts with uniqueness timing; underscored/unofficial |
| `@frozen` / `@_fixed_layout` | Array :299; storage classes :132 | Already institute practice where applicable |
| `_fixLifetime(self)` **inside the storage deinit** | ContiguousArrayBuffer.swift:139 | **Yes — adopt in `Box.deinit`'s drain** (guards ARC shortening during teardown; cheap; sits exactly in the R-6 deinit-timing neighborhood) |
| `@_alwaysEmitIntoClient` on mutation gateways | `_endMutation`, span accessors | Yes where back-deployment/inlining warrants |
| `@unsafe` / `@safe` / `unsafe` exprs (SE-0458 wave) | ManagedBuffer pointer methods (new in 64x); `@safe` on ContiguousArray/InlineArray/Span but *not* on `Array`/`ArraySlice` | Already institute practice (`.strictMemorySafety()`) |
| `@exclusivity(unchecked)` on the box's stored payload | swift-collections `Shared._Box.storage` (Shared.swift:43–46) | Investigate at W4 — drops dynamic exclusivity checks on the box hop; measure before adopting |

## Trajectory — what changed 6.3.2 → 6.4.x → main

**The Array-family CoW mechanism and teardown model are stable across all three refs** — no change to the
uniqueness check, copy path, storage layout, or deinit (verified by per-file diff sweep). What did move:

| Area | 632 → 64x | 64x → main |
|---|---|---|
| Strict memory safety | `@unsafe` added to ManagedBuffer/ManagedBufferPointer `withUnsafeMutablePointerTo*` (6 methods); `@safe` waves on `with*` functions (e.g. commit `453277eb74b`) | embedded-Swift guards (`@_unavailableInEmbedded`, `#if !$Embedded`) on buffer-class validation |
| Lifetime annotations | `@_lifetime` → `@lifetime` sweep in Span-family files (632: 0/`@lifetime`; 64x/main: 32 vs 4 remnants); `Array.span/mutableSpan` still `@_lifetime` on main | further cleanup commits (e.g. `c878730bda6` "switch away from old @lifetime annotations") |
| Accessor model | InlineArray/Span subscripts migrate `unsafeAddress`/`unsafeMutableAddress` → `borrow`/`mutate` accessors + `@_unsafeSelfDependentResult`; `_unsafeAddressOfElement` returns `Builtin.RawPointer` | continued |
| `~Copyable` reach | SE-0499 lands (simple stdlib protocols generalized; Swift 6.4); `~Copyable` file count 31 → 42 in core | flat (42) |
| New containers | — | **SE-0527 `UniqueArray`/`RigidArray` merged 2026-06-04 (PR #87521) and reverted same day (PR #89696, CMake response-files); re-land imminent.** Both unconditionally `~Copyable`. |
| Array API | OutputSpan-based `init(capacity:initializingWith:)` / append present on all three refs (SE-0485, Implemented 6.2; stdlib-type extensions still listed pending) | append-error-path fix (`58b0e565f02`) |

Practical consequences for the institute (build-gate 6.3.2, dev toolchains 6.4.x): keep `@_lifetime`
spelling until the 6.4 gate bump, then sweep; expect `Swift.UniqueArray`/`RigidArray` to appear in 6.5-dev
snapshots shortly (name-collision check for the tower's vocabulary: institute types are namespaced
(`Array<S>` top-level shadow + nested variants), s-c/stdlib names are compound — no collision, but
`swift-array-primitives`'s shadow of `Swift.Array` should re-verify overload resolution when stdlib gains
`UniqueArray`).

## Tower impact — findings against decisions

| # | Finding | Tower element | Verdict |
|---|---|---|---|
| 1 | Array trio Copyable-only everywhere; SE-0527 rejected conditional-copyable Array | PROPOSAL §0 "the stdlib `Array` posture" justification | **Correct the sentence** (seat's call — ratified text): the conditional-copyability precedent is `InlineArray` (eager-copy); `Shared`'s real precedent is the upstream two-family direction + s-c `Shared` mechanism |
| 2 | Upstream direction = sibling families (CoW-copyable vs Unique/Rigid move-only); s-c `Shared` = same box mechanism, unconditionally Copyable, internal-only | R-1/R-2 two-column design | **CONFIRMED / convergent** |
| 3 | No conditionally-Copyable CoW container anywhere; SE-0527 names the runtime-copyability-dispatch objection | The optional façade (`Array<Element>` baking `Shared` in) | **Keep shelved** — novel, risk-named, collapses to two-column under API-split anyway; R-6 lives in its shape |
| 4 | `_ContiguousArrayStorage.deinit` drains elements; ManagedBuffer deinit empty + subclass-drain contract; count-driven dealloc hack | R-5 drain-box rule | **CONFIRMED stdlib-convergent** — cite this evidence in the W4 `skill-lifecycle` encoding; adopt `_fixLifetime(self)` at the end of `Box.deinit`'s drain |
| 5 | `ManagedBuffer<Header, Element: ~Copyable>` on 6.3.2; tail-alloc mechanism fully documented; malloc-size capacity reclaim | Deferred single-alloc fusion; allocator leaf | Fusion door exists today for both element kinds; stays future/internal per ratification (layer-collapse tension recorded). Malloc-size reclaim + immortal empty singleton adoptable independently |
| 6 | `mutableSpan` runs `_makeMutableAndUnique()` before vending; stdlib uses `_overrideLifetime` in returning accessors; SE-0465 pointer-pointee deferral still open | Span-canonical (ACCEPTED); W4 scoped span at box hop | **CONFIRMED**; `ensureUnique()` must precede any mutable-span vend on the `Shared` column; `_overrideLifetime` debt is stdlib-idiomatic parity, not deviation |
| 7 | `Builtin.FixedArray` is a managed aggregate ⇒ InlineArray needs no deinit ⇒ conditional Copyable; userland `@_rawLayout` is unmanaged ⇒ Wall 1 | `Store.Inline` move-only law; `occupancy-lives-in-the-leaf.md` | **CONFIRMED with mechanism identified**; the dissolving feature (userland managed fixed-size aggregate) is proposed nowhere |
| 8 | R-6 shape unexercised by stdlib; no upstream issue exists; no guarding idiom to copy | R-6 deferred filing + durable repro | **Posture confirmed**; repro still in `/tmp/cow-skip-repro` — move to `Experiments/` (pending ratified action) |
| 9 | `@_lifetime` (632) vs `@lifetime` (64x+) spelling split | All institute `~Escapable` surfaces | Pin `@_lifetime` until the 6.4 gate bump; plan a mechanical sweep then |

## Outcome

**Status: RECOMMENDATION** (reference + findings; no tower source was edited — research-only per the
dispatch).

1. **Adopt the corrections**: retire the "stdlib `Array` posture" phrasing (PROPOSAL §0 — seat edits or
   annotates the ratified text); henceforth cite: *InlineArray = conditional-Copyable eager-copy precedent;
   upstream two-family direction + swift-collections `Shared` = the `Shared`-column precedent; façade = no
   precedent.*
2. **Keep the façade shelved** with the named risk (SE-0527's runtime-copyability-dispatch objection +
   R-6's shape). Revisit only if upstream ships runtime copyability queries or the sibling-family direction
   reverses.
3. **W4 implementation notes now grounded in stdlib evidence**: `ensureUnique()` before any mutable-span
   vend; unique-grow moves rather than copies; `_fixLifetime(self)` closing `Box.deinit`'s drain; consider
   `@exclusivity(unchecked)` on the box payload (measure); cite `_ContiguousArrayStorage.deinit` in the
   R-5 skill encoding.
4. **Fusion dossier complete** (§Q4): ManagedBuffer door incl. `~Copyable` elements on 6.3.2; layout math;
   malloc-size reclaim; `@unsafe` friction at 6.4. No action now (2-alloc ratified); the dossier de-risks
   the future decision.
5. **Corpus errata to fix** (one-line each, seat's call since both docs are recent/ratified):
   `store-inline-span-vs-in-place-pointer.md:350` says "SE-0527 (OutputSpan)" — OutputSpan is **SE-0485**;
   SE-0527 is RigidArray/UniqueArray. `se-0527-rigid-unique-array-alignment.md` cites "SE-0506 OutputSpan"
   — `0506` is Advanced Observation Tracking; the OutputSpan proposal is `0485-outputspan.md`.
6. **Watch items**: SE-0527 re-land on main (re-verify `swift-array-primitives` shadow-resolution then);
   SE-0516 `Iterable` review closes 2026-06-18; lifetime-annotation rename at the 6.4 gate bump;
   `/tmp/cow-skip-repro` → `Experiments/` (ratified R-6 action, still pending).

## Residual (per [RES-027])

| Item | Class | Disposition |
|---|---|---|
| ManagedBuffer-based single-alloc fusion *compiles and behaves* for the `Shared` shape (subclass + drain deinit + conditional-Copyable wrapper) on 6.3.2 — note R-6 lurks in exactly this composition | **direction** (not load-bearing now: 2-alloc is ratified; fusion gated on future measurement) | When fusion is considered: ≤1h spike extending `/tmp/tower-cow-spike` (swap `Box` for a `ManagedBuffer` subclass; re-run the 14-test suite + the R-6 oracle in `-O`) **before** any design reliance |
| Malloc-size capacity reclaim at the tower's heap leaf (does our allocation path expose `malloc_size`-equivalent slack?) | direction | Allocator-tier check when touched next |
| `@exclusivity(unchecked)` / `@_eagerMove` adoption on `Box`/`Shared` | direction | Measure at W4; both underscored/semi-official — record toolchain-risk if adopted |
| Whether stdlib's `beginCOWMutation`-flag machinery ever becomes userland-reachable (would upgrade `Shared`'s check) | direction | None — watch Swift Evolution |
| R-6 repro durability | **premise** (the drain-box rule's backing evidence) | Extant artifact: `/tmp/cow-skip-repro/` + `/tmp/tower-cow-spike/` (seat-verified 2026-06-09 per the ratification). Action already ratified (R-6): move into `Experiments/` — flagged in Outcome 6; this doc adds no new unverified premise |

## References

### Primary — swiftlang/swift (pinned: 632 `cd8d8ad0019` · 64x `0b7717dc5b6` · main `6f5d855aedf`)

- `stdlib/public/core/Array.swift` :299–301 (decl), :349–378 (`_makeMutableAndUnique`/`_endMutation`),
  :1003 (`_deallocateUninitialized`), :1638 area (OutputSpan init), :1758/:1885 (span/mutableSpan, main).
- `stdlib/public/core/ArrayBuffer.swift` :204–229 (`_consumeAndCreateNew`); `BridgeStorage.swift` :83,146
  (`Builtin.beginCOWMutation[_native]`); `Builtin.swift` :765–768 (`_isUnique`).
- `stdlib/public/core/ContiguousArrayBuffer.swift` :132–140 (storage class + deinit), :308
  (`projectTailElems`), :348–382 (tail alloc + malloc-size reclaim), :586–589 (empty-singleton guard).
- `stdlib/public/core/ManagedBuffer.swift` :38 (decl, `Element: ~Copyable` — all refs), :66–68 (empty
  deinit), :85–123 (create/capacity/firstElementAddress), :598–635 (offset math), :712–715
  (`isKnownUniquelyReferenced`).
- `stdlib/public/core/ArrayShared.swift` :34–70 (uninitialized intrinsics), :268–336 (`_arrayOutOfPlaceUpdate`).
- `stdlib/public/core/InlineArray.swift` :100–113 (decl + conditional conformances), :125–155 (address
  projection), :588/:603 (span vending); `_InlineArray.swift` :13–19 (internal twin).
- `stdlib/public/core/Span/{Span,RawSpan,MutableSpan,OutputSpan}.swift` (decls :29/:29/:23–24/:25;
  OutputSpan deinit :37–46).
- `stdlib/public/Synchronization/Cell.swift` :17–44 (`@_rawLayout` `_Cell` + struct deinit).
- `stdlib/public/SwiftShims/swift/shims/HeapObject.h` :48–54; `stdlib/public/runtime/HeapObject.cpp`
  :127–130; `lib/IRGen/GenClass.cpp` :820–842 (`appendSizeForTailAllocatedArrays`).
- Pre-revert: `git show ec1c9320b97:stdlib/public/core/UniqueArray/UniqueArray.swift` (:42); revert
  `dcd214065fd` (PR #89696).

### Primary — Swift Evolution (verified against the live proposals/ directory, 2026-06-10)

- SE-0427 Noncopyable Generics — Implemented (Swift 6.0).
- SE-0437 Noncopyable Standard Library Primitives — Implemented (6.0); Hypoarray appendix.
- SE-0446 Nonescapable Types — Implemented (6.2).
- SE-0447 Span: Safe Access to Contiguous Storage — Implemented (6.2).
- SE-0453 InlineArray, a fixed-size array (`0453-vector.md`) — Implemented (6.2); conditional-copy +
  eager-copy quotes.
- SE-0458 Opt-in Strict Memory Safety Checking — Implemented (6.2).
- SE-0465 Standard Library Primitives for Nonescapable Types — Implemented (6.2); pointer-pointee deferral.
- SE-0467 MutableSpan / MutableRawSpan — Implemented (6.2).
- SE-0483 InlineArray Type Sugar — Implemented (6.2).
- **SE-0485 OutputSpan** — Implemented (6.2), stdlib-type extensions pending. *(Corrects two internal docs;
  Outcome 5.)*
- SE-0499 Support ~Copyable, ~Escapable in simple standard library protocols — Implemented (6.4).
- SE-0516 `Iterable` — Active review (June 4–18, 2026).
- SE-0517 UniqueBox — Accepted.
- **SE-0527 RigidArray and UniqueArray — Accepted in Principle**; impl PR swiftlang/swift#87521
  (merged+reverted 2026-06-04, PR #89696).
- Lifetime dependencies: no numbered proposal (open swift-evolution PRs #2305, #3145).

### Primary — swift-collections & forums (fetched 2026-06-10)

- apple/swift-collections @ `af174fe4476842b2558069e64feae8ddc2e665ff`:
  `Sources/ContainersPreview/Types/Shared.swift` (:14–16 `#if false // TODO`, :28 decl, :43–46 `_Box` +
  `@exclusivity(unchecked)`, :58–66 `isUnique`/`ensureUnique`);
  `Sources/BasicContainers/{UniqueArray/UniqueArray.swift:66, RigidArray/RigidArray.swift:84}`;
  `Sources/BasicContainers/BasicContainers.docc/BasicContainers.md` :9; release notes 1.3.0/1.4.0/1.5.0.
- Forums: `[Pitch] Box` t/84014 (post #1); SE-0517 review t/85107 (McCall #30, #58; Ben Cohen #60);
  RigidArray/UniqueArray pitch t/85455 (Alejandro #7).

### Internal ([RES-019])

- `/Users/coen/Developer/.handoffs/PROPOSAL-tower-perfected-design.md` (RATIFIED 2026-06-09) +
  `HANDOFF-tower-flag-day-migration.md` — R-1…R-7; the corrected §0 phrase.
- `conditional-deinit-conditionally-copyable-generics.md` (Tier 3) — Wall 1/Wall 2; SE-0427 law; S1–S8.
- `occupancy-lives-in-the-leaf.md` (Tier 3, DECISION) — placement law this note's Q6 confirms.
- `store-inline-span-vs-in-place-pointer.md` (ACCEPTED) — span-canonical; SE-0465 REMOVE-WHEN; erratum in
  Outcome 5.
- `swift-array-primitives/Research/se-0527-rigid-unique-array-alignment.md` — SE-0527 adoption ledger;
  erratum in Outcome 5.
- `copyable-wrapper-vs-multi-buffer-storage.md`; `apple-swiftlang-memory-buffer-allocator-survey.md`;
  `memory-buffer-allocator-institute-vs-apple-comparative.md` — adjacent-tier surveys this note extends to
  the ADT/Array tier.

### Verification

[RES-020] parallel verification, 2026-06-10: tree-claims verifier (21 claims; 19 confirmed, 2 corrected —
lifetime spelling, OutputSpan-deinit detail) and web-claims verifier (16 claims; 15 confirmed, 1 corrected —
OutputSpan = SE-0485, not 0506/0527). Corrections incorporated; no unverified load-bearing claim remains.
