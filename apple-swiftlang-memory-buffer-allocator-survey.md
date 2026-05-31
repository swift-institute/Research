# Apple / Swiftlang Memory, Buffer, and Allocator Survey

<!--
---
version: 1.2.0
last_updated: 2026-05-31
status: ANALYSIS
statusDetail: "Round 1 of 2 — external survey of apple/swiftlang only. Round 2 (comparative vs. Institute) is COMPLETE: see memory-buffer-allocator-institute-vs-apple-comparative.md. No Institute comparison or gap-classification in THIS document by design."
changelog: "v1.2.0 (2026-05-31): Round 2 landed — cross-linked memory-buffer-allocator-institute-vs-apple-comparative.md. v1.1.0: added companion implementation deep-dive apple-swiftlang-arena-allocator-family-implementations.md. v1.0.0: initial external survey."
tier: 2
scope: ecosystem-wide
---
-->

## Context

**Trigger.** Principal requested a research-process survey of the approaches taken by recent **apple/\*** and **swiftlang/\*** GitHub repositories to **memory, buffers, and allocator types** — "what is their approach to that topic."

**Two-round structure (explicit constraint).** This is **Round 1 of 2**:

- **Round 1 (this document):** a *pure external description* of apple/swiftlang's own design. By principal instruction, it deliberately does **not** look at, reference, or compare against any Swift Institute package. It also does **not** classify anything as a "gap" — per [RES-021], universal external adoption must not be mistaken for universal necessity, and the contextualization step belongs in Round 2.
- **Round 2 (pending, separate document):** comparative analysis between the apple/swiftlang approach catalogued here and what the Institute does.

**Scope.** Public material only: the `apple/*` and `swiftlang/*` GitHub orgs, `swiftlang/swift-evolution` (proposals + visions), and `forums.swift.org`. **Recency focus** is the Swift 6.x era (~2024–2026); older foundational mechanisms are included where they are load-bearing for the recent work and are labelled *established*.

**Method.** Eight parallel primary-source discovery agents (Span family; OutputSpan/construction; InlineArray/value generics; raw memory/allocators/synchronization; swift-java arenas; swift-foundation `Data`; Embedded/MMIO; landscape scout) on 2026-05-31, followed by three adversarial verification agents resolving the load-bearing and conflicting claims. Per [RES-019], the internal `swift-institute/Research/` corpus was grepped first: no prior *external* apple/swiftlang memory/buffer/allocator survey exists (the adjacent docs — `comparative-buffer-primitives.md`, `canonical-buffer-discipline-cross-language-survey.md`, `apple-http-outputspan-writer-pattern.md`, `lifetime-annotation-escapable-swift-6.3.md`, `swift-6.3-ecosystem-opportunities.md` — are Institute-internal/comparative and are reserved for Round 2; they were **not** read for this round to keep the external description uncontaminated).

**Verification convention.** Load-bearing claims carry `[Verified: 2026-05-31]` when confirmed against primary source (proposal header text, live stdlib source on `main`, or repo file). Single-source reads from the proposal-index sweep are tagged `[Proposal index: 2026-05-31]`. Residual unverified items are collected in the Confidence appendix.

**Companion document (added v1.1.0).** A follow-on deep-dive, [`apple-swiftlang-arena-allocator-family-implementations.md`](apple-swiftlang-arena-allocator-family-implementations.md), drills from this landscape into *how* the arena / pool / bump / slab / stack allocator families are implemented (data structures, free/growth/alignment/thread-safety), reading nine concrete types verbatim from source. Read it alongside §6 and §10 below.

---

## Question

What is apple/swiftlang's approach to **memory, buffers, and allocators** — the concrete types and APIs, the design models behind them, and the recent trajectory of the work?

---

## Analysis

### 0. The organizing thesis

Across the surveyed surface, apple/swiftlang's recent memory work is organized around **one dominant idea and one conspicuous non-idea**:

- **Dominant idea — safe, non-owning, lifetime-checked *views* over contiguous memory.** The centre of gravity (Swift 6.2, mid-2025) is the **`Span` family**, built on a new ownership substrate (`~Copyable`, `~Escapable`, lifetime dependencies). Safety comes from the *type system forbidding a view from outliving its storage* — not from reference counting and not from a runtime. `Span` is positioned explicitly as the safe successor to `Unsafe*BufferPointer`.
- **Conspicuous non-idea — pluggable allocators.** There is **no user-facing custom-allocator facility** in the standard library and **no accepted or actively-pitched proposal for one** `[Verified: 2026-05-31]`. "Allocators" is the quietest of the three topics: control over allocation is expressed through the unsafe-pointer layer, scoped temporary allocation, and *per-library* storage/allocator types — never a stdlib `Allocator` abstraction.

Two further cross-cutting themes:

- **A recurring storage idiom** across the ecosystem: *value-type façade + `final class` copy-on-write storage + `isKnownUniquelyReferenced` + index/slice bookkeeping*, with `Span` layered on top as a borrowed view (NIO `ByteBuffer`, swift-system `_RawBuffer`, Foundation `Data`).
- **A safety *policy* layer** (the `memory-safety` vision → SE-0458 opt-in strict mode) that frames the whole effort and names `Span` as the migration destination for unsafe pointers.

The remainder of this section catalogues each layer.

---

### 1. The ownership / lifetime substrate (the machinery that makes everything else safe)

These are the language-level primitives the buffer/memory types are built on. Most predate the Span family by a release or two and are *established* by 2026, but they are the foundation.

| Mechanism | Proposal | Status | What it provides |
|---|---|---|---|
| `consume` operator | SE-0366 | Implemented 5.9 | Explicit end-of-lifetime / ownership transfer |
| `borrowing` / `consuming` parameter modifiers | SE-0377 | Implemented 5.9 | Caller↔callee ownership convention |
| Noncopyable structs & enums (`~Copyable`) | SE-0390 | Implemented 5.9 | Move-only value types (no implicit copy) |
| `BitwiseCopyable` | SE-0426 | Implemented 6.0 | Marker for trivially-copyable (no refcount/pointer) layout |
| Noncopyable generics | SE-0427 | Implemented 6.0 | `~Copyable` in generic position |
| `sending` parameter/result | SE-0430 | Implemented 6.0 | Region transfer across isolation (thread-safety) |
| Region-based isolation | SE-0414 | Implemented 6.0 | Thread-safety dimension |
| **Nonescapable types (`~Escapable`)** | **SE-0446** | **Implemented 6.2** | Values that **cannot escape their defining scope** — the prerequisite for a safe non-owning view |
| Lifetime dependencies (`@lifetime` / `@_lifetime`) | *experimental, not yet through Evolution* | feature flag `Lifetimes` | Ties a returned `~Escapable` value's lifetime to a borrow/inout/copy of its source |
| Borrow & Mutate accessors | SE-0507 | Implemented 6.4 | In-place `borrow`/`mutate` coroutine accessors (no copy) |

**`~Escapable` (SE-0446)** `[Verified: 2026-05-31]` is the keystone. It is a suppressible marker protocol — every type is `Escapable` by default; `~Escapable` suppresses it, yielding instances that "cannot escape out of the context in which they were created with *no runtime overhead*." The proposal draws the analogy to escaping vs. non-escaping closures (heap-captured vs. stack-representable). SE-0446 deliberately *deferred* the ability to **return** non-escapable values, because that requires lifetime-dependency syntax.

**Lifetime dependencies — deliberately still unstable.** The annotation that ties a view's lifetime to its source is **not an accepted Swift Evolution proposal** `[Verified: 2026-05-31]`. It exists only as an experimental feature (compiler flag `Lifetimes` enabling `@_lifetime`; broader `LifetimeDependence`). The Language Steering Group has *intentionally* held it back from Evolution (John McCall, LSG, 2025-03: the LSG "is wary of formalizing `@lifetime` … as the right way to write lifetime dependencies, which is why it has not been proposed as an official feature"); stdlib proposals describe it as a "didactic placeholder." Spelling nuance worth recording: **proposals use the underscored `@_lifetime`; the current `main`-branch stdlib source uses the non-underscored `@lifetime`** — both map to the same experimental feature, and the final blessed spelling is still being pitched (Pitch #3, 2026-02-25). Observed dependency kinds: `@lifetime(borrow x)` (valid within a borrow scope of `x`), `@lifetime(copy x)` (inherits `x`'s existing dependency), `@lifetime(&self)` / `@_lifetime(inout self)` (exclusive-borrow), `@lifetime(immortal)` (no constraint).

> Net: the entire Span family shipped in Swift 6.2 **riding an un-reviewed, experimental lifetime annotation**. This is the single most important caveat about the maturity of the model.

---

### 2. The `Span` family (the centerpiece)

A coherent arc of proposals (Guillaume Lessard et al., review-managed by Doug Gregor, under the "BufferView Roadmap"). The unifying design: each is a `~Escapable` value holding `(base pointer + count)` that **owns no storage**; safety is the compiler preventing the view from outliving its backing storage.

| Type | Proposal | Status | Copyability / Escapability | Role |
|---|---|---|---|---|
| `Span<Element>` | SE-0447 | Implemented 6.2 | `Copyable`, `~Escapable` (also `BitwiseCopyable` in shipped source) | **Shared read-only** borrow of initialized contiguous memory |
| `RawSpan` | SE-0447 | Implemented 6.2 | `Copyable`, `~Escapable` | Untyped/raw-bytes read-only borrow |
| `MutableSpan<Element>` | SE-0467 | Implemented 6.2 | **`~Copyable`, `~Escapable`** | **Exclusive mutable** borrow (in-place mutation) |
| `MutableRawSpan` | SE-0467 | Implemented 6.2 | `~Copyable`, `~Escapable` | Exclusive mutable raw-bytes borrow |
| `OutputSpan<Element>` | SE-0485 | Implemented 6.2* | `~Copyable`, `~Escapable` | **Incremental initialization** of uninitialized capacity |
| `OutputRawSpan` | SE-0485 | Implemented 6.2* | `~Copyable`, `~Escapable` | Incremental byte-buffer initialization |
| `UTF8Span` | SE-0464 | Implemented 6.2 | `~Escapable` | Validated-UTF-8 view over contiguous code units |

\* SE-0485 core types shipped in 6.2; some *container* extensions are still landing (Array's `OutputSpan` initializers shipped; the String forms had not, as of the surveyed `main`) `[Verified: 2026-05-31]`.

**The read / mutate / construct triad** is the conceptual core: a buffer can be *read* (`Span`/`RawSpan`), *mutated in place* (`MutableSpan`/`MutableRawSpan`), or *initialized from uninitialized* (`OutputSpan`/`OutputRawSpan`) — and each verb is a distinct type because its invariant differs. Read-only is `Copyable` (many readers OK); mutation/output are `~Copyable` **because non-copyability is what statically enforces exclusive access** under the Law of Exclusivity ("a copy would represent" a second concurrent access).

Representative shipped signatures `[Verified: 2026-05-31]` (from `stdlib/public/core/Span/*`):

```swift
@frozen public struct Span<Element: ~Copyable>: ~Escapable, Copyable, BitwiseCopyable {
  public var count: Int { get }
  public subscript(_ index: Int) -> Element { _read }
  public subscript(unchecked position: Int) -> Element { _read }   // unsafe, unchecked
}
@frozen public struct RawSpan: Copyable, ~Escapable {
  public func unsafeLoad<T>(fromByteOffset: Int = 0, as: T.Type) -> T
  public func unsafeLoadUnaligned<T: BitwiseCopyable>(fromByteOffset: Int = 0, as: T.Type) -> T
}
@frozen public struct MutableSpan<Element: ~Copyable>: ~Copyable, ~Escapable { … }
@frozen public struct OutputSpan<Element: ~Copyable>: ~Copyable, ~Escapable {
  public let capacity: Int
  public var count: Int { get }; public var freeCapacity: Int { get }
  @_lifetime(self: copy self) public mutating func append(_ value: consuming Element)
  public var span: Span<Element> { @_lifetime(borrow self) borrowing get }
  @unsafe public consuming func finalize(for buffer: UnsafeMutableBufferPointer<Element>) -> Int
}
```

`OutputSpan`'s design is notable: it tracks the initialized-prefix `count` automatically, **auto-deinitializes the partial prefix if the closure throws** (exception safety for free), and `finalize(for:)` is a `consuming` method that re-checks buffer identity (traps on mismatch) before returning the count to the container — a *typed handoff* replacing the old "trust me, I set `initializedCount` right."

**How spans enter real code** (the migration path off unsafe-pointer closures):

| Proposal | Status | Adds |
|---|---|---|
| Span-providing properties (SE-0456) | Implemented 6.2 | `.span` / `.bytes` on `Array`, `ArraySlice`, `ContiguousArray`, `String.UTF8View`, `Substring.UTF8View`, `InlineArray`, `CollectionOfOne`, `KeyValuePairs`, `Unsafe[Raw]BufferPointer`; **`Data` carries `bytes`/`span` directly** |
| Nonescapable stdlib primitives (SE-0465) | Implemented 6.2 | `Optional`/`Result`/`MemoryLayout`/`ObjectIdentifier` etc. work with `~Escapable` payloads; `extendLifetime()` |
| Safe loading API for `RawSpan` (SE-0525) | **Accepted with Modifications** | Typed loads from raw spans |
| `withTemporaryAllocation` yielding `Output(Raw)Span` (SE-0524) | Implemented 6.4 | Scratch buffers as init-tracking spans (see §5) |

The triad as adopted: **read → `.span`** (SE-0456), **mutate-in-place → `.mutableSpan`** (SE-0467, `@_lifetime(inout self)` getter), **construct/fill → container `init(capacity:initializingWith:)` taking `inout OutputSpan`** (SE-0485). Each replaces a `withUnsafe…BufferPointer { … }` closure with a direct, composable, typed-throws-friendly value.

---

### 3. Fixed-size and inline storage

| Type / feature | Proposal | Status | Storage model |
|---|---|---|---|
| Integer generic parameters (`<let count: Int>`) | SE-0452 | Implemented 6.2 | Language mechanism: a generic parameter that is an `Int` value |
| `InlineArray<count, Element>` | SE-0453 | Implemented 6.2 | **Inline, no implicit heap allocation**; eager value copy (like a tuple) |
| `InlineArray` type sugar `[N of T]` | SE-0483 | Implemented 6.2 | `let x: [5 of Int]` — `of` is a contextual keyword `[Verified: 2026-05-31]` |
| `ManagedBuffer` / `ManagedBufferPointer` | *established* | shipping | Tail-allocated header + raw element storage, one heap object, ARC-owned |
| `ContiguousArray` | *established* | shipping | Heap, CoW, guaranteed-contiguous (never `NSArray`-bridged) |
| `Builtin.FixedArray<count, Element>` | *compiler builtin* | shipping | The inline storage primitive `InlineArray` wraps |

**`InlineArray` (SE-0453)** `[Verified: 2026-05-31]` is the headline fixed-size type. Apple's docs: *"a specialized container that doesn't use a separate memory allocation just to store its elements. When a value is copied, all of its elements are copied eagerly, like those of a tuple."* Hard guarantee: it *"will never introduce an implicit heap allocation just for its storage alone."* It is `~Copyable`-generic (supports non-copyable elements), conditionally `Copyable`/`BitwiseCopyable`/`Sendable`, and exposes `.span`/`.mutableSpan` (via SE-0456/0467). It deliberately does **not** conform to `Collection`/`Sequence` — to prevent silent implicit copies given the eager-copy semantics; safe iteration is routed through `Span` (and the provisional `BorrowingSequence`, below).

The **`Vector` → `InlineArray` rename** is documented design rationale: the LSG chose the `Inline-` prefix because it "captured the salient aspects of how this type's storage is organized," prioritizing the storage/eager-copy implication over the fixed-size aspect, and avoiding the overloaded meaning of `Vector` (C++/Rust/math).

**`<let count: Int>` (SE-0452)** is the enabling mechanism — currently only `Swift.Int` value parameters are allowed; each becomes a static member (`Matrix<4,3>.columns == 4`). Stated future directions (arithmetic in generic params, non-Int value params, parameter packs) are **not** confirmed shipped post-6.2 `[Proposal index: 2026-05-31]`.

**`ManagedBuffer` / `ManagedBufferPointer`** is the *established* hand-managed heap primitive (header inline + tail-allocated raw element storage; `create(minimumCapacity:makingHeaderWith:)`, `withUnsafeMutablePointers`). Recently modernized for `~Copyable` elements and typed throws. It is the heap, dynamically-sized, manually-managed counterpart to `InlineArray`'s inline, statically-sized, automatically-managed model — and it is the building block under the CoW storage idiom in §6.

**Provisional:** a `BorrowingSequence` protocol (`~Copyable, ~Escapable`, with `SpanIterator`) exists in `stdlib/public/core/BorrowingSequence.swift` gated `@available(SwiftStdlib 6.4, *)`, and `InlineArray` conforms — but its proposal **SE-0516 "Borrowing Sequence" is *Returned for revision*** `[Verified: 2026-05-31]`. So the implementation has landed on `main` ahead of a finalized proposal; treat the API as unstable/provisional.

---

### 4. Strict memory safety — the policy layer

| Artifact | Status | What it is |
|---|---|---|
| `visions/memory-safety.md` | LSG-endorsed | The roadmap framing the whole effort |
| Opt-in Strict Memory Safety (SE-0458) | Implemented 6.2 | `-strict-memory-safety` / `#if hasFeature(StrictMemorySafety)`; `@unsafe`, `@safe`, `unsafe { }` |

The **memory-safety vision** `[Verified: 2026-05-31]` defines a **five-dimension taxonomy** — *lifetime, bounds, type, initialization,* and *thread* safety — observing that Swift provides the first four by default *except* at "low-level access to contiguous memory," and that Swift 6 strict concurrency added thread safety. It names three features as the path forward: non-escapable types, `Span` ("the memory-safe counterpart to the unsafe buffer types"), and lifetime dependencies. It commits that strict checking "should remain an opt-in feature for the foreseeable future" because unsafe pointers stay essential for C interop.

**SE-0458** realizes it: an opt-in mode that marks the unsafe surface `@unsafe` (e.g. `@unsafe public struct UnsafeBufferPointer<…>`), lets you vouch safety with `@safe`, and requires an `unsafe` expression marker (like `try`/`await`). It changes no defaults; it is *migration pressure* toward `Span`. The unsafe surface it enumerates includes `Unsafe*Pointer`, `Unmanaged`, `unsafeBitCast`, `VolatileMappedRegister.init(unsafeBitPattern:)`, and `Span.subscript(unchecked:)`. The C-interop half (`__counted_by`, `lifetimebound` → safe `Span` projections) is demonstrated in `apple/sample-fbounds-safety-adoption`.

---

### 5. Raw memory, temporary allocation, synchronization

| API / type | Proposal | Status | Model |
|---|---|---|---|
| `Unsafe[Mutable][Raw]Pointer.allocate/initialize/deinitialize/deallocate` | *established* | shipping | Caller owns the full lifecycle; explicit power-of-two alignment |
| `withUnsafeTemporaryAllocation(byteCount:alignment:_:)` | SE-0322 | Implemented 5.6 | Scoped scratch buffer; **stack allocation NOT guaranteed** |
| `withTemporaryAllocation(... ) -> inout Output(Raw)Span` | SE-0524 | Implemented 6.4 | Safe successor yielding an init-tracking span `[Verified: 2026-05-31]` |
| `Atomic<Value>` (+ orderings) | SE-0410 | Implemented 6.0 | `~Copyable`, inline storage via `@_rawLayout` |
| `Mutex<State>` | SE-0433 | Implemented 6.0 | `~Copyable`, **no heap box** — inline lock+state via `@_rawLayout` |
| `@_rawLayout` / `_Cell` | *underscored/experimental* | shipping (6.0) | Inline raw storage for noncopyable cells |

Two design points stand out:

- **Stack allocation is an optimization, never a contract.** SE-0322 *intentionally* refuses to promise the stack ("The proposed functions do not guarantee that their buffers will be stack-allocated. This omission is intentional") to avoid VLA-style security issues; the compiler chooses per-size and falls back to the heap via `_swift_stdlib_isStackAllocationSafe()`.
- **Sync primitives store inline, and live in a separate module.** `Atomic`/`Mutex` avoid an out-of-line allocation by storing their cell inline via the underscored `@_rawLayout` attribute (and the `_Cell` type) — trading a heap box for a stable-address raw storage and explicit non-Sendability. They live in `import Synchronization`, *not* the default `Swift` module — signalling "sharp, opt-in, low-level." (`@_rawLayout` semantics, verbatim: "specifies the declared type consists of raw storage. The type must be noncopyable, and declare no stored properties.") The standalone `apple/swift-atomics` *package* (2020) predates and is functionally superseded for new code by `Synchronization.Atomic`.

---

### 6. Buffer storage patterns across the package ecosystem

Beyond the stdlib, the surveyed libraries converge on **one recurring idiom**: a `struct` value-type façade wrapping a `final class` CoW storage, guarded by `isKnownUniquelyReferenced`, with index/slice bookkeeping — and `Span` retrofitted on top as a borrowed view.

**SwiftNIO `ByteBuffer` / `ByteBufferAllocator`** (`apple/swift-nio`, *established* prior art) `[Verified: 2026-05-31]`:

```swift
public struct ByteBuffer {                         // value façade
  @usableFromInline var _storage: _Storage         // CoW class
  @usableFromInline var _readerIndex: _Index
  @usableFromInline var _writerIndex: _Index
}
@usableFromInline final class _Storage {           // heap, malloc-backed
  @usableFromInline private(set) var bytes: UnsafeMutableRawPointer
  @usableFromInline let allocator: ByteBufferAllocator
}
public struct ByteBufferAllocator: Sendable {      // a *library* allocator
  public func buffer(capacity: Int) -> ByteBuffer
}
```

`ByteBuffer` uses the reader/writer-index model (`discardable | readable | writable` regions); `ByteBufferAllocator` defaults to libc `malloc/realloc/free`. **Recent change:** a `readableBytesSpan: RawSpan` getter gated `#if compiler(>=6.2)`, plus a `NIOPooledRecvBufferAllocator` for read-path pooling — i.e. NIO is retrofitting the Span model. Note its legacy `withUnsafeReadableBytes` is *already* typed-throws.

**Foundation `Data`** (`swiftlang/swift-foundation`) — the most nuanced finding, and one where verification corrected the initial read:

- The storage representation is forked by `#if DATA_LEGACY_ABI` `[Verified: 2026-05-31]`. The **legacy** branch is the classic enum `_Representation { empty / inline(InlineData) / slice(InlineSlice) / large(LargeSlice) }` with the famous **inline small-data optimization** (≤14 bytes inline on 64-bit, no heap). The **new** branch is a `struct _Representation { _storage: __DataStorage; _slice: Range<Int> }` with **no inline case** — every non-empty `Data` is a single heap allocation + slice, CoW-shared.
- **Crucial correction (platform-dependent default)** `[Verified: 2026-05-31]`: `Package.swift:156` reads `.define("DATA_LEGACY_ABI", .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS]))` (mirrored in `CMakeLists.txt` for Darwin). **So on Apple platforms the legacy enum *with* the inline optimization is the default** (preserving binary compatibility with the shipping OS Foundation); the new heap-only struct model is the default **only on non-Apple platforms** (Linux/Windows/Android/WASI), which have no ABI to preserve. The inline optimization is *not* dropped on Apple OSes.
- **Allocation details (new `__DataStorage`):** on Darwin 64-bit it uses Apple's **typed allocator** (`malloc_type_calloc/malloc/realloc` with `layout_semantics.contains_generic_data = true`), else plain `calloc/malloc/realloc`. Geometric growth ~1.5× small / ~1.25× past `4×pageSize`, snapped to `malloc_good_size`; `malloc`-grade alignment guaranteed (PR #1883, Apr 2026). This typed-malloc tagging is the closest thing to an "allocator hook" — heap-tagging, *not* a pluggable allocator.
- **Span adoption (per SE-0456):** `Data` exposes all four — `bytes: RawSpan`, `span: Span<UInt8>`, `mutableBytes: MutableRawSpan`, `mutableSpan: MutableSpan<UInt8>` — plus `OutputRawSpan`-based `init(capacity:_:)` / `append(addingCapacity:_:)` (the append surface was still settling as of May 2026, PR #1971). No `DiscontiguousData` type exists in the rewrite; `Data` is always single-contiguous.

**New, Span-native libraries** (no legacy to retrofit):

- `apple/swift-binary-parsing` (created 2025-05) — core type `ParserSpan` is `~Escapable, ~Copyable` wrapping a `RawSpan` with `@_lifetime` annotations; ships an `InlineArray` parser and an embedded example. The newest dedicated buffer/parsing repo.
- `swiftlang/swift-subprocess` (created 2025-03) — output `Buffer` wraps `[UInt8]` internally but the *public* read surface is Span-first: `var bytes: RawSpan { @_lifetime(borrow self) borrowing get }`, with dedicated `Span+Subprocess.swift`.
- `apple/swift-system` — internal `_RawBuffer` is a "copy-on-write fixed-size buffer of raw memory" on `ManagedBuffer<Int, UInt8>`; the **`IORing/`** (Linux io_uring) subsystem added mid-2025 carries `RawIORequest` and uses non-escapable API behind a feature flag.

---

### 7. swift-java — the one place with explicit "allocator/arena" *types*

`swiftlang/swift-java` (created 2024-09, actively developed into 2026) is the clearest example of named allocator/arena types in a recent swiftlang repo — but a structural surprise: **the arena types are written in *Java*, not Swift** `[Verified: 2026-05-31]`. They manage *Swift-object* memory *from the Java side*, layered on JDK 22+'s `java.lang.foreign` (FFM/Panama) `Arena`/`MemorySegment`. The Swift side is the `jextract` binding generator that emits Java code calling these arenas.

The type family (Java, `org.swift.swiftkit.{core,ffm}`):

```java
public interface SwiftArena {                       // root: lifetime scope for Swift objects
  void register(SwiftInstance instance);
  static ClosableSwiftArena ofConfined();           // deterministic, try-with-resources
  static SwiftArena ofAuto();                        // GC/Cleaner-driven (documented "LESS reliable")
}
public interface ClosableSwiftArena extends SwiftArena, AutoCloseable { void close(); }
public interface AllocatingSwiftArena extends SwiftArena, SegmentAllocator {   // FFM-only
  MemorySegment allocate(long byteSize, long byteAlignment);
}
```

Design points:

- **An "arena" is a *lifetime scope for Swift objects*, not merely a byte allocator.** `register(SwiftInstance)` enrolls each Swift class/struct/enum; closing/collecting destroys them "in a way appropriate to their type" — FFM mode calls the Swift runtime's **value-witness-table `destroy`**; JNI mode calls a generated native destroy.
- **Two disciplines, one interface:** `ofConfined()` (deterministic, thread-confined, *verifying* close that throws on over-retained objects) vs. `ofAuto()` (GC/`Cleaner`-driven, explicitly documented as less reliable — "prefer confined"). The whole API is biased toward explicit ownership.
- **Composes JDK FFM:** allocating arenas *wrap* `Arena.ofConfined()`/`ofAuto()` and implement `SegmentAllocator`, so a Swift arena is simultaneously a native-segment allocator. Close ordering is explicit: Swift destroys run **before** native memory is freed (`super.close()` then `arena.close()`); destroys are one-shot CAS-guarded (double-free throws); `$ensureAlive()` guards use-after-free.
- **Policy enforced at generation time:** FFM mode mandates explicit arenas; the global GC-arena shortcut (`allowGlobalAutomatic`) is JNI-mode-only.
- **Recent, still-evolving:** core/FFM split landed 2025-07 (#300); the confined-session cleanup was reworked as recently as 2026-05-20.

---

### 8. Constrained environments — Embedded Swift + swift-mmio

**Embedded Swift** (`visions/embedded-swift.md`, LSG-accepted; live docs at docs.swift.org/embedded) `[Verified: 2026-05-31]` splits into **two bottom layers**:

- **"Allocating" Embedded Swift** — classes/indirect enums allowed; external deps add `malloc`/`calloc`/`free` + a sub-kilobyte Swift runtime exposing `swift_allocObject` / `swift_initStackObject` / `swift_initStaticObject` / `swift_retain` / `swift_release`.
- **"Non-allocating" Embedded Swift** (`-no-allocations`) — no heap; deps are **only `memset`/`memcpy`**; classes, indirect enums, escaping closures, and the dynamic containers/strings that need them are disallowed.

Cross-cutting embedded memory rules: *"No hidden allocations which would cause unpredictable performance cliffs"*; the runtime "does not manage any data structures behind your back, is itself less than a kilobyte, and is eligible to be removed if unused" (achieved by eliminating runtime type metadata and forcing compile-time **specialization/monomorphization** of generics). The heap allocator itself is **platform-owned**, never shipped by the toolchain — *"malloc/calloc/free APIs are expected to be provided by the platform."* ARC survives but is stripped: **`weak`/`unowned` are forbidden** ("a simplified reference-counting model that cannot support them" — no side tables). On baremetal, the integrator supplies the entire memory environment (custom linker script with `MEMORY`/`SECTIONS`, startup code to zero `.bss` and copy `.data` flash→RAM, `-nostdlib`).

**swift-mmio** (`apple/swift-mmio`, created 2023-09; 0.1.0 on 2025-09-05 renamed `@RegisterBank`→`@RegisterBlock`) `[Verified: 2026-05-31]` models hardware memory as **zero-allocation value types**:

```swift
public struct Register<Value>: RegisterProtocol where Value: RegisterValue {
  public var unsafeAddress: UInt                    // stores ONLY an address; allocates nothing
  public func read() -> Value.Read
  public func write(_ newValue: Value.Write)
  public func modify<T>(_ body: (Value.Read, inout Value.Write) -> T) -> T  // 1 volatile read + 1 write
}
```

`@RegisterBlock` structs (+ `RegisterArray`) express a peripheral's memory map as nested value types with `base + offset (+ stride*i)` arithmetic, all `@inline(__always)`; type-safe **bit-field projection** (`@ReadWrite/@ReadOnly/@WriteOnly/@Reserved(bits:as:)`, `.raw` views, `BitFieldProjectable`) replaces manual masking, with runtime bounds/alignment traps. Because Swift has no `volatile` keyword, every access routes through a tiny `always_inline` C shim (`mmio_volatile_load/store_uintN_t`, storage restricted to `UInt8/16/32/64`) that deliberately avoids even `stdint.h`; the header explicitly anticipates replacement "with a Swift language primitive for volatile." **`Span` is not used in the MMIO core** — hardware memory is modeled as discrete typed register pointers (`Unsafe[Mutable]Pointer` reconstructed from a `UInt` address), not a contiguous span.

---

### 9. Recency-ranked landscape of relevant repos

| Repo | Created | Relevance to memory/buffers/allocators |
|---|---|---|
| `apple/swift-binary-parsing` | 2025-05 | **Newest dedicated buffer/parse repo**; `ParserSpan` over `RawSpan`, Span-era native |
| `swiftlang/swift-subprocess` | 2025-03 | Output `Buffer` with `bytes: RawSpan`; Span-adopting IO |
| `apple/swift-system` | 2020 (IORing 2025-07) | `_RawBuffer` CoW; io_uring non-escapable API |
| `apple/swift-nio` | 2018 | **Established** `ByteBuffer`/`ByteBufferAllocator`; recent `RawSpan` adoption |
| `swiftlang/swift-java` | 2024-09 | `SwiftArena`/`AllocatingSwiftArena` FFM arena family (Java side) |
| `apple/swift-mmio` | 2023-09 | Zero-allocation typed MMIO registers (embedded) |
| `swiftlang/swift-foundation` | 2023-01 | `Data` storage model + Span bridging |
| `swiftlang/swift` | — | Home of the `Span` family, `InlineArray`, `Synchronization` |
| `apple/swift-collections` | 2021 | CoW container storage (Deque/OrderedSet…) |
| `apple/corecrypto` | **2026-05-22** | Brand-new source drop; crypto buffer/zeroing handling — *uninspected, follow-up candidate* |
| `apple/sample-fbounds-safety-adoption` | 2025-04 | C bounds-safety (`__counted_by`) → safe Span interop |

No dedicated standalone *allocator library* exists in either org; allocator work lives in the stdlib `Span` family, SE-0454 (toolchain mimalloc), or per-package storage types.

---

### 10. Allocators — the verified absence (load-bearing for Round 2)

Stated explicitly because it is the most consequential finding and was adversarially verified `[Verified: 2026-05-31]`:

- The Swift standard library has **no `Allocator` protocol, no arena/bump allocator type, no pluggable-allocator API.** A grep of `stdlib/public/core/` (243 files) finds exactly one alloc-named file, `TemporaryAllocation.swift`, whose entire public surface is the two free functions `withUnsafeTemporaryAllocation`/`withTemporaryAllocation`. `protocol Allocator` matches **only third-party repos**, never `swiftlang/swift`.
- Across all ~536 evolution proposals, exactly **two** are allocator-named: **SE-0454 "Custom Allocator for Toolchain"** (Accepted) — verbatim scope: *"This change has no implications for the runtime, only the toolchain is changed"* (mimalloc for the compiler build, Windows) — and **SE-0524** (the Span-yielding `withTemporaryAllocation`, not a pluggable allocator).
- No 2024–2026 vision or forum pitch proposes a user-facing stdlib allocator. The historical position holds (Lattner, 2018: "Not with safe code currently. You can use unsafe constructs to do this though."). SE-0503's `associatedtype Allocator = DefaultAllocator` is a *pedagogical Queue example*, not proposed API.

The sanctioned mechanisms for controlling allocation are therefore: the **unsafe-pointer layer**, **`withUnsafeTemporaryAllocation`/`withTemporaryAllocation`** (SE-0322/0524), and **per-library storage/allocator types** (NIO `ByteBufferAllocator`, swift-system `_RawBuffer`, swift-java arenas, Foundation `__DataStorage`).

---

## Outcome

**Status: ANALYSIS — Round 1 complete (external survey). Round 2 (comparative vs. Institute) is the next step and is *not* performed here.**

Synthesized characterization — **how apple/swiftlang currently think about memory, buffers, and allocators**:

1. **Memory safety is delivered through *type-level borrowed views*, not runtime mechanisms.** The `Span` family (`Span`/`RawSpan`/`MutableSpan`/`MutableRawSpan`/`OutputSpan`/`OutputRawSpan`/`UTF8Span`) is a non-owning, bounds-checked, lifetime-checked view whose safety is enforced statically by `~Escapable` + lifetime dependencies, at zero runtime overhead relative to a raw pointer. It is the explicit successor to `Unsafe*BufferPointer`.
2. **The three buffer verbs are three types.** Read (`Span`, `Copyable`), mutate-in-place (`MutableSpan`, `~Copyable`), and initialize-from-uninitialized (`OutputSpan`, `~Copyable`) are distinct because their invariants differ; non-copyability is the mechanism that statically enforces exclusive mutable access.
3. **Storage location is a first-class, compile-time concern.** `InlineArray` (inline, eager-copy, no implicit heap) vs. `Array`/`ContiguousArray` (heap, CoW) is now a type-level choice, enabled by integer generic parameters (`<let count: Int>`) and surfaced with `[N of T]` sugar.
4. **There is no allocator abstraction — and that appears deliberate.** Allocation control is unsafe-pointer + scoped-temporary + per-library types. (Whether this is a genuine gap *for the Institute* is a Round-2 question, not asserted here, per [RES-021].)
5. **A common storage idiom recurs ecosystem-wide:** value façade + `final class` CoW storage + `isKnownUniquelyReferenced` + index/slice bookkeeping, with `Span` layered on top — visible in NIO `ByteBuffer`, swift-system `_RawBuffer`, and Foundation `Data`.
6. **Constrained environments get a distinct, allocation-minimizing track:** Embedded Swift's two-tier allocating/non-allocating model (platform-owned heap, stripped ARC, no hidden allocations) and swift-mmio's zero-allocation typed registers.
7. **A safety *policy* layer frames it all:** the `memory-safety` vision's five dimensions and SE-0458's opt-in `-strict-memory-safety` make `@unsafe` visible and position `Span` as the migration destination.
8. **Maturity caveat:** the entire Span family shipped in Swift 6.2 on an **experimental, un-reviewed `@lifetime`/`@_lifetime`** annotation the LSG has intentionally not yet standardized; `BorrowingSequence` (SE-0516) is *Returned for revision* yet present in source. The model is landing fast and is not fully settled.

**Round 2 (COMPLETE — see [`memory-buffer-allocator-institute-vs-apple-comparative.md`](memory-buffer-allocator-institute-vs-apple-comparative.md)).** The comparison drew on this internal material (reserved/unread during Round 1): `comparative-buffer-primitives.md`, `canonical-buffer-discipline-cross-language-survey.md`, `apple-http-outputspan-writer-pattern.md`, `lifetime-annotation-escapable-swift-6.3.md`, `swift-6.3-ecosystem-opportunities.md`, `nonescapable-*`/`noncopyable-*` series, `storage-arena-architecture.md`, `memory-pool-arena-buffer-usage-analysis.md`, `buffer-arena-conditional-copyable.md`. The proposal table (§1–§5) and the allocator-absence finding (§10) are the highest-value reusable artifacts for that comparison.

---

## References

**Standard-library / language proposals** (`github.com/swiftlang/swift-evolution/blob/main/proposals/`):
- Span family: [SE-0447](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md) · [SE-0456](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md) · [SE-0467](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0467-MutableSpan.md) · [SE-0485](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0485-outputspan.md) · [SE-0464](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0464-utf8span-safe-utf8-processing.md) · [SE-0465](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0465-nonescapable-stdlib-primitives.md) · [SE-0525](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0525-rawspan-safe-loading-api.md)
- Ownership substrate: [SE-0446](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md) · [SE-0390](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md) · [SE-0426](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0426-bitwise-copyable.md) · [SE-0377](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0377-parameter-ownership-modifiers.md) · [SE-0366](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0366-move-function.md) · [SE-0507](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0507-borrow-accessors.md) · [SE-0516](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0516-borrowing-sequence.md)
- Fixed-size storage: [SE-0452](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0452-integer-generic-parameters.md) · [SE-0453](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md) · [SE-0483](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0483-inline-array-sugar.md)
- Raw / temp / sync: [SE-0322](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0322-temporary-buffers.md) · [SE-0524](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0524-span-temporary-allocation.md) · [SE-0410](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0410-atomics.md) · [SE-0433](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0433-mutex.md)
- Policy / toolchain: [SE-0458](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md) · [SE-0454](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0454-memory-allocator.md)

**Visions** (`github.com/swiftlang/swift-evolution/blob/main/visions/`): [memory-safety.md](https://github.com/swiftlang/swift-evolution/blob/main/visions/memory-safety.md) · [embedded-swift.md](https://github.com/swiftlang/swift-evolution/blob/main/visions/embedded-swift.md)

**Standard-library source** (`github.com/swiftlang/swift/blob/main/`): `stdlib/public/core/Span/{Span,RawSpan,MutableSpan,OutputSpan,OutputRawSpan}.swift` · `stdlib/public/core/{InlineArray,ManagedBuffer,BorrowingSequence,TemporaryAllocation}.swift` · `stdlib/public/Synchronization/{Cell,Atomics,Mutex}` · `include/swift/Basic/Features.def` · `docs/ReferenceGuides/UnderscoredAttributes.md`

**Repositories:** [apple/swift-nio](https://github.com/apple/swift-nio) (`Sources/NIOCore/ByteBuffer-*.swift`) · [swiftlang/swift-foundation](https://github.com/swiftlang/swift-foundation) (`Sources/FoundationEssentials/Data/`; `Package.swift:156`) · [swiftlang/swift-java](https://github.com/swiftlang/swift-java) (`SwiftKitCore/`, `SwiftKitFFM/`) · [apple/swift-mmio](https://github.com/apple/swift-mmio) · [apple/swift-binary-parsing](https://github.com/apple/swift-binary-parsing) · [swiftlang/swift-subprocess](https://github.com/swiftlang/swift-subprocess) · [apple/swift-system](https://github.com/apple/swift-system) · docs.swift.org/embedded

**Forums:** [Experimental lifetime dependencies in 6.2+](https://forums.swift.org/t/experimental-support-for-lifetime-dependencies-in-swift-6-2-and-beyond/78638) · [Pitch #3: compile-time lifetime dependency annotations](https://forums.swift.org/t/pitch-3-compile-time-lifetime-dependency-annotations/84968) · [Implementation details of new Mutex type](https://forums.swift.org/t/implementation-details-of-new-mutex-type/71942) · [Are custom allocators possible in Swift?](https://forums.swift.org/t/are-custom-allocators-possible-in-swift/10797) · [Default allocator for Swift](https://forums.swift.org/t/default-allocator-for-swift/64970)

---

## Appendix — Confidence & residual gaps

**Independently double-verified (adversarial pass, 2026-05-31):** the SE-0483 `[N of T]` sugar (resolved a discovery-agent conflict); the platform-dependent `Data` `DATA_LEGACY_ABI` default (corrected an initial "new model is default everywhere" overstatement — it is Apple-platform-legacy by default); the decisive non-existence of a user-facing stdlib allocator (SE-0454 verbatim scope; no `Allocator` protocol in `stdlib/public/core/`); SE-0524/0525/0507/0516 titles + statuses.

**High confidence (verbatim primary source):** Span-family declarations and statuses (SE-0447/0456/0464/0465/0467/0485, all Implemented 6.2); InlineArray + value generics (SE-0452/0453); Synchronization (SE-0410/0433, Implemented 6.0); `@_rawLayout`/`_Cell`; swift-java arena type family + FFM/JNI split; NIO `ByteBuffer` shape; Embedded two-tier model + dependency symbol lists; swift-mmio API surface.

**Single-source (proposal-index sweep, not independently re-read):** statuses of the broader ownership-substrate proposals (SE-0427/0429/0432/0437/0494/0499/0515) and the in-flight SE-0532 ("Optional noncopyable improvements," Active review May 26–Jun 8 2026). These are not load-bearing for the synthesis.

**Known unverified / follow-up candidates (carried forward honestly):**
- String's `OutputSpan`-based initializers (`repairingUTF8WithCapacity:` etc.) are *proposed* in SE-0485 but **not yet present** in `main` `String.swift`; the Array forms shipped, the String forms had not as of the surveyed snapshot.
- Exact `@available` version triples and a few precise internal member names in NIO/subprocess/system were WebFetch-summarized, not line-read; re-read if a signature becomes load-bearing in Round 2.
- `apple/corecrypto` (created 2026-05-22) is uninspected — crypto buffer/zeroing handling may be notable.
- Stdlib-internal *implementations* (vs. proposal text) of `RawSpan`/`MutableRawSpan` exact stored layout, and the full `OutputSpan` allocate-side witness path in swift-java, were not exhaustively transcribed.
- `swift-system` `_RawBuffer` `withUnsafeBytes` is still `rethrows` (not typed-throws), unlike most surveyed surface — minor consistency note.
