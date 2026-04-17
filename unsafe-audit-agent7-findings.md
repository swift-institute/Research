<!--
version: 1.0.0
last_updated: 2026-04-15
status: COMPLETE
scope: Phase 1 Agent 7 classification of @unchecked Sendable sites in 11 coverage-gap packages (swift-array-primitives, swift-set-primitives, swift-dictionary-primitives, swift-async-primitives, swift-clock-primitives, swift-slab-primitives, swift-machine-primitives, swift-input-primitives, swift-loader-primitives, swift-parser-machine-primitives, swift-test-primitives)
agent: 7 of 7
-->

# Agent 7 Findings — Data structures + Async scatter (coverage gap fill)

## Summary

| Metric | Count |
|--------|:-----:|
| Total hits | 45 |
| Cat A (synchronized) | 7 |
| Cat B (ownership transfer) | 27 |
| Cat C (thread-confined) | 0 |
| Cat D candidates (flagged to queue) | 11 |
| Low-confidence | 8 (the `<let N: Int>` outer container variants + `@_rawLayout` _Value — primary B with plausible D per Agent 2 precedent) |
| Preexisting deviations noted | 1 (Loader.Library.Handle uses `@unsafe` on the struct — violates [MEM-SAFE-021]) |

### Per-package breakdown

| Package | Expected (handoff) | Actual | A | B | C | D |
|---------|:----:|:----:|:-:|:-:|:-:|:-:|
| swift-array-primitives | ~11 | 11 | 0 | 10 | 0 | 1 |
| swift-set-primitives | ~8 | 8 | 0 | 6 | 0 | 2 |
| swift-dictionary-primitives | ~6 | 6 | 0 | 6 | 0 | 0 |
| swift-async-primitives | ~5 | 5 | 4 | 1 | 0 | 0 |
| swift-clock-primitives | ~5 | 5 | 2 | 0 | 0 | 3 |
| swift-slab-primitives | ~3 | 3 | 0 | 3 | 0 | 0 |
| swift-machine-primitives | ~3 | 3 | 0 | 0 | 0 | 3 |
| swift-input-primitives | ~1 | 1 | 0 | 1 | 0 | 0 |
| swift-loader-primitives | ~1 | 1 | 0 | 0 | 0 | 1 |
| swift-parser-machine-primitives | ~1 | 1 | 0 | 0 | 0 | 1 |
| swift-test-primitives | ~1 | 1 | 1 | 0 | 0 | 0 |
| **Total** | **~45** | **45** | **7** | **27** | **0** | **11** |

Counts match the handoff's `~45` expectation exactly.

### Grep notes

Comment-line matches excluded from the conformance totals:

- `swift-async-primitives/Async Channel Primitives/Async.Channel.Bounded.Sender.swift:110` — a comment referencing `Ownership.Slot`, not a conformance in this scope.
- `swift-async-primitives/Async Timer Primitives/Async.Timer.Wheel.Storage.swift:23` — the "Thread Safety" docstring comment before the `struct Storage` declaration; not a separate conformance site.
- `swift-machine-primitives/Machine Value Primitives/Machine.Value.swift:42,48` — two docstring comment lines preceding the actual `final class _Storage: @unchecked Sendable` on line 51.
- `swift-machine-primitives/Machine Capture Primitives/Machine.Capture.Frozen.swift:12` — docstring comment; the actual conformance is `extension Machine.Capture.Frozen: Sendable where Mode: Sendable {}` on line 26 (plain `Sendable`, no `@unchecked`).
- `swift-machine-primitives/Machine Capture Primitives/Machine.Capture.Slot.swift:10,11,31` — docstring comment lines; the two actual conformances are `public struct Slot: @unchecked Sendable` on line 17 and `final class _Storage: @unchecked Sendable` on line 37.
- `swift-array-primitives/Array Static Primitives/Array.Static.Indexed.swift:22` — **commented-out** (`//extension Array.Static.Indexed: @unchecked Sendable ...`); not an active conformance.

### Overall shape

- **Async synchronization stack concentrates Cat A** — Async.Mutex's `_Lock`, `_Value`, the outer `Mutex`, and the Embedded no-op stub form a tightly-synchronized family of 4 Cat A sites. `Clock.Immediate` and `Clock.Test` (both `final class` with `Mutex<State>` internal storage) round out Cat A. `Test.Attachment.Collector` (class with `Mutex<[Test.Attachment]>`) is the single scattered Cat A.
- **Data structure packages are near-entirely Cat B** — array / set / dictionary / slab / input follow the same ownership-transfer pattern as Agent 2's storage/queue/stack. Iterators (Array/Set/Dict iterator variants) wrap buffer iterators that hold raw pointers; outer containers are `~Copyable` with CoW or inline storage.
- **Indexed phantom-Tag wrappers are Cat D** — `Array.Dynamic.Indexed`, `Set.Ordered.Fixed.Indexed`, `Set.Ordered.Indexed` are `Copyable` structs carrying a phantom `Tag: Copyable` generic that is never stored. Ownership transfer is incidental; the `@unchecked` exists because phantom Tag blocks structural Sendable inference. These mirror Agent 4's `Hash.Table` D-candidate reasoning.
- **Clock.Any type-erasure family is Cat D** — `Clock.Any<D>`, its abstract `Box`, and concrete `ConcreteBox<I, D>` are type-erasure machinery with immutable fields + stored closures. No synchronization, no `~Copyable`. `@unchecked` covers the stored `@Sendable` closures + generic pinning.
- **Machine.Value / Machine.Capture erased-value storage is Cat D** — `_Storage` classes hold immutable pointer + destroy function; docstrings explicitly state "immutable after construction". No runtime synchronization; the `@unchecked` exists because `UnsafeMutableRawPointer` and stored function pointers block structural inference.
- **`<let N: Int>` value-generic variants (Array.Small, Array.Static, Array.Bounded, Set.Ordered.Small, Set.Ordered.Static, Dictionary.Ordered.Small, Dictionary.Ordered.Static, Slab.Static)** — primary classification **B** (ownership transfer via `~Copyable`), dual-flagged as D candidates per Agent 2's precedent for consistent adjudication of value-generic structural inference gaps. LOW_CONFIDENCE on B-vs-D.

No Category C (thread-confined) anywhere in scope. No mutex/atomic infrastructure in data structure packages.

---

## Classifications

| # | File:Line | Type | Category | Reasoning | Docstring ref |
|---|-----------|------|:--------:|-----------|---------------|
| 1 | `swift-array-primitives/Sources/Array Dynamic Primitives/Array.Dynamic.Indexed.swift:25` | `Array.Indexed<Tag: Copyable>` (`Copyable`) | **D candidate** | `Copyable` struct wrapping `Array<Element>` + phantom `Tag: Copyable` generic. Tag never stored; conformance gated `where ...` is absent (declaration-site form). The `@unchecked` exists because the wrapped `Array<Element>` itself is `@unchecked Sendable where Element: Sendable` and the phantom Tag blocks structural inference. No synchronization, no `~Copyable` invariant on this wrapper. | — |
| 2 | `swift-array-primitives/Sources/Array Dynamic Primitives/Array.Dynamic.swift:81` | `Array.Iterator` (struct, `Element: Copyable`) | **B** | Sequence iterator wrapping `Buffer.Linear.Iterator` whose internal state holds raw pointers into CoW-backed storage. Transferable iteration token. Direct analog of Agent 2's `Queue.Fixed.Iterator` (Appendix B16). | Appendix B-Iter |
| 3 | `swift-array-primitives/Sources/Array Fixed Primitives/Array.Fixed ~Copyable.swift:84` | `Array.Fixed.Iterator` (struct, `Element: Copyable`) | **B** | Wraps `Buffer.Linear.Bounded.Iterator` holding raw pointers. Same pattern as Agent 2's `Queue.Fixed.Iterator`. | Appendix B-Iter |
| 4 | `swift-array-primitives/Sources/Array Fixed Primitives/Array.Fixed.Indexed ~Copyable.swift:15` | `Array.Fixed.Indexed<Tag: ~Copyable>` (`~Copyable`) | **B** (flagged D candidate; LOW_CONFIDENCE) | `~Copyable` wrapper around `Array.Fixed` that smuggles phantom `Tag: ~Copyable`. Ownership transfer invariant primary. Phantom Tag is a D-candidate signal (mirrors Agent 4's `Hash.Table` reasoning); principal to adjudicate. | Appendix B1 |
| 5 | `swift-array-primitives/Sources/Array Small Primitives/Array.Small.swift:70` | `Array.Small.Iterator` (struct, `Element: Copyable`) | **B** | Wraps `Buffer.Linear.Small<inlineCapacity>.Iterator` holding raw pointers. Transferable iteration token. | Appendix B-Iter |
| 6 | `swift-array-primitives/Sources/Array Small Primitives/Array.Small.swift:86` | `Array.Small<let inlineCapacity: Int>` (`~Copyable`) | **B** (flagged D candidate; LOW_CONFIDENCE) | `~Copyable` small-buffer container. Primary B (ownership transfer via `~Copyable`); `<let inlineCapacity: Int>` value-generic flagged per Agent 2 precedent. | Appendix B2 |
| 7 | `swift-array-primitives/Sources/Array Small Primitives/Array.Small.Indexed.swift:144` | `Array.Small.Indexed<Tag: ~Copyable>` (`~Copyable`) | **B** (flagged D candidate; LOW_CONFIDENCE) | `~Copyable` wrapper around `Array.Small<inlineCapacity>` + phantom `Tag: ~Copyable`. Ownership transfer invariant primary. Value-generic + phantom Tag, both D-candidate signals. | Appendix B1 |
| 8 | `swift-array-primitives/Sources/Array Primitives Core/Array.Static.swift:50` | `Array.Static<let capacity: Int>` (`~Copyable`) | **B** (flagged D candidate; LOW_CONFIDENCE) | `~Copyable` fixed-capacity inline container over `Buffer.Linear.Inline<capacity>`. Primary B (ownership transfer). Value-generic flagged per Agent 2 precedent. | Appendix B3 |
| 9 | `swift-array-primitives/Sources/Array Primitives Core/Array.swift:138` | `Array<Element>` (`~Copyable`, conditionally `Copyable`) | **B** | Dynamically-growing CoW array wrapping `Buffer.Linear`. `~Copyable`; conditionally `Copyable` with CoW on `Element: Copyable`. Direct analog of Agent 2's `Queue` (Appendix B4). | Appendix B4 |
| 10 | `swift-array-primitives/Sources/Array Primitives Core/Array.swift:142` | `Array.Fixed` (struct, conditionally `Copyable`) | **B** | Fixed-count, heap-allocated array wrapping `Buffer.Linear.Bounded`. Same CoW pattern as `Array`. Direct analog of Agent 2's `Queue.Fixed` (Appendix B5). | Appendix B5 |
| 11 | `swift-array-primitives/Sources/Array Primitives Core/Array.Bounded.swift:61` | `Array.Bounded<let N: Int>` (`~Copyable`) | **B** (flagged D candidate; LOW_CONFIDENCE) | `~Copyable` compile-time dimensioned array with CoW heap storage. `<let N: Int>` value-generic flagged per Agent 2 precedent. | Appendix B6 |
| 12 | `swift-set-primitives/Sources/Set Primitives Core/Set.swift:104` | `Set.Ordered` (struct, conditionally `Copyable`) | **B** | Ordered set composing `Buffer.Linear` + `Hash.Table`. `~Copyable`; conditionally `Copyable` with CoW. | Appendix B7 |
| 13 | `swift-set-primitives/Sources/Set Primitives Core/Set.swift:105` | `Set.Ordered.Fixed` (struct, conditionally `Copyable`) | **B** | Fixed-capacity ordered set composing `Buffer.Linear.Bounded` + `Hash.Table`. Same CoW pattern. | Appendix B8 |
| 14 | `swift-set-primitives/Sources/Set Primitives Core/Set.Ordered.Small.swift:52` | `Set.Ordered.Small<let inlineCapacity: Int>` (`~Copyable`) | **B** (flagged D candidate; LOW_CONFIDENCE) | Small-buffer ordered set composing `Buffer.Linear.Small` + conditional heap hash table. Value-generic flagged. | Appendix B9 |
| 15 | `swift-set-primitives/Sources/Set Primitives Core/Set.Ordered.Static.swift:51` | `Set.Ordered.Static<let capacity: Int>` (`~Copyable`) | **B** (flagged D candidate; LOW_CONFIDENCE) | Inline-storage ordered set composing `Buffer.Linear.Inline` + `Hash.Table.Static`. Value-generic flagged. | Appendix B10 |
| 16 | `swift-set-primitives/Sources/Set Ordered Primitives/Set.Ordered.Fixed.Indexed.swift:57` | `Set.Ordered.Fixed.Indexed<Tag: Copyable>` (`Copyable`) | **D candidate** | `Copyable` struct wrapping `Set.Ordered.Fixed` + phantom `Tag: Copyable` generic. Tag never stored. No synchronization, no `~Copyable` invariant. `@unchecked` exists because phantom Tag blocks structural inference over the wrapped (`@unchecked Sendable`) `Set.Ordered.Fixed`. | — |
| 17 | `swift-set-primitives/Sources/Set Ordered Primitives/Set.Ordered.Indexed.swift:57` | `Set.Ordered.Indexed<Tag: Copyable>` (`Copyable`) | **D candidate** | Same pattern as #16 for dynamic `Set.Ordered`. | — |
| 18 | `swift-set-primitives/Sources/Set Ordered Primitives/Set.Ordered.Fixed Copyable.swift:45` | `Set.Ordered.Fixed.Iterator` (struct, `Element: Copyable`) | **B** | Wraps `Buffer.Linear.Bounded.Iterator` holding raw pointers. Same pattern as Agent 2's `Queue.Fixed.Iterator`. | Appendix B-Iter |
| 19 | `swift-set-primitives/Sources/Set Ordered Primitives/Set.Ordered.Iterator.swift:56` | `Set.Ordered.Iterator` (struct, `Element: Copyable`) | **B** | Wraps `Buffer.Linear.Iterator`. Same pattern. | Appendix B-Iter |
| 20 | `swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.swift:129` | `Dictionary<Key, Value>` (`~Copyable`, conditionally `Copyable where Value: Copyable`) | **B** | Slab-backed unordered dictionary composing `Hash.Table<Key>` + `Buffer<Key>.Slab` + `Buffer<Value>.Slab`. `~Copyable` with conditional CoW. | Appendix B11 |
| 21 | `swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.swift:116` | `Dictionary.Ordered` (`~Copyable`, conditionally `Copyable where Value: Copyable`) | **B** | Ordered dictionary composing `Set<Key>.Ordered` + `Buffer<Value>.Linear`. `~Copyable` with conditional CoW. Docstring explicitly says "Not thread-safe for concurrent mutation. Synchronize externally." | Appendix B12 |
| 22 | `swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.Bounded.swift:69` | `Dictionary.Ordered.Bounded` (`~Copyable`, conditionally `Copyable where Value: Copyable`) | **B** | Fixed-capacity ordered dictionary. Same pattern. | Appendix B13 |
| 23 | `swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.Small.swift:92` | `Dictionary.Ordered.Small<let inlineCapacity: Int>` (`~Copyable`) | **B** (flagged D candidate; LOW_CONFIDENCE) | Small-buffer ordered dictionary. Value-generic flagged per Agent 2 precedent. | Appendix B14 |
| 24 | `swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.Static.swift:54` | `Dictionary.Ordered.Static<let capacity: Int>` (`~Copyable`) | **B** (flagged D candidate; LOW_CONFIDENCE) | Inline-storage ordered dictionary composing `Hash.Table.Static` + inline buffers. Value-generic flagged. | Appendix B15 |
| 25 | `swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.Values.swift:201` | `Dictionary.Ordered.Values.Iterator` (struct, `Value: Copyable`) | **B** | Wraps `Buffer<Value>.Linear.Iterator`. Same pattern as other iterators. | Appendix B-Iter |
| 26 | `swift-async-primitives/Sources/Async Timer Primitives/Async.Timer.Wheel.Storage.swift:36` | `Async.Timer.Wheel.Storage` (`~Copyable`) | **B** | `~Copyable` arena-backed timer node storage. Docstring explicitly says "wheel is `~Copyable` and intended for single-actor use. All mutations are serialized by the owning actor." No internal synchronization inside `Storage` itself — the serialization is external (actor-owned). This is ownership-transfer, not internal synchronization. Direct analog of Agent 2's arena-backed storage classes. | Appendix B16 |
| 27 | `swift-async-primitives/Sources/Async Mutex Primitives/Async.Mutex.swift:53` | `Async.Mutex._Lock` (`~Copyable`, `@_rawLayout(like: os_unfair_lock_s)`) | **A** | Inner raw-layout wrapper that IS the `os_unfair_lock_s` storage. While `@_rawLayout` is structural, this type's semantic role is the synchronization primitive itself — not a value-storage workaround. Conformance makes the lock representable across ownership transfers of the enclosing Mutex. | Appendix A1 |
| 28 | `swift-async-primitives/Sources/Async Mutex Primitives/Async.Mutex.swift:75` | `Async.Mutex<Value: ~Copyable>` (`~Copyable`) | **A** | Public value-owning mutex. `os_unfair_lock` serializes all access to the stored `Value`. Existing docstring already says "Internal `os_unfair_lock` serializes all access to the stored value." Canonical Cat A. | Appendix A2 |
| 29 | `swift-async-primitives/Sources/Async Mutex Primitives/Async.Mutex.swift:77` | `Async.Mutex._Value` (`~Copyable`, `@_rawLayout(like: Value, movesAsLike)`) | **A** | Inner raw-storage wrapper for the protected `Value`. Existing inline comment says "Access serialized by external lock." This differs from Agent 2's `_Raw` candidates: here the `@_rawLayout` type has a runtime caller invariant (use only under the outer Mutex's lock). The synchronization is real even though the lock is external to this struct. | Appendix A3 |
| 30 | `swift-async-primitives/Sources/Async Mutex Primitives/Async.Mutex.swift:191` | `Async.Mutex<Value: ~Copyable>` (`final class`, Embedded / non-kernel stub) | **A** (LOW_CONFIDENCE) | Compatibility stub for environments without any lock primitive (embedded, no kernel). Structurally a no-op — access is trivially safe because there are no threads. Arguably Cat C (thread-confined), but classified A for family consistency with the primary platform implementations and because the stub exists to maintain the Mutex API contract. LOW_CONFIDENCE on A-vs-C boundary. | Appendix A4 |
| 31 | `swift-clock-primitives/Sources/Clock Primitives/Clock.Immediate.swift:30` | `Clock.Immediate` (`final class`) | **A** | Class holds `state: Mutex<State>` (`Synchronization.Mutex`). All access through `state.withLock`. Canonical Cat A. | Appendix A5 |
| 32 | `swift-clock-primitives/Sources/Clock Primitives/Clock.Test.swift:41` | `Clock.Test` (`final class`) | **A** | Same pattern as `Clock.Immediate`: class with `state: Mutex<State>` serializing all access. Canonical Cat A. | Appendix A6 |
| 33 | `swift-clock-primitives/Sources/Clock Primitives/Clock.Any.swift:28` | `Clock.Any<D: DurationProtocol & Hashable>` (struct) | **D candidate** | Type-erased clock struct. Stored fields: three `@Sendable` closures (`_now`, `_minimumResolution`, `_sleep`). No `~Copyable`, no synchronization. The `@unchecked` exists because stored function-type properties and the generic `D: DurationProtocol & Hashable` (without Sendable) block structural inference. No caller invariant beyond "the wrapped clock is Sendable when boxed" (enforced by the generic init's `C: Sendable` constraint). | — |
| 34 | `swift-clock-primitives/Sources/Clock Primitives/Clock.Any.swift:93` | `Clock.Any<D>.Instant.Box` (`fileprivate class`, abstract base) | **D candidate** | Empty abstract class with no stored state; all methods `fatalError`. No synchronization, no `~Copyable`. `@unchecked` exists to enable the `ConcreteBox` subclass hierarchy to propagate Sendable through the `D` generic. No caller invariant. | — |
| 35 | `swift-clock-primitives/Sources/Clock Primitives/Clock.Any.swift:105` | `ConcreteBox<I, D>` (`private final class`) | **D candidate** | `let instant: I` immutable after init. No synchronization. `@unchecked` exists because the `I: InstantProtocol & Hashable & Sendable, D: DurationProtocol & Hashable` generics — while Sendable on `I` is declared — don't propagate structurally through the class + inheritance from the `Box` base (which is itself `@unchecked Sendable`). The whole hierarchy is a D-candidate family. | — |
| 36 | `swift-slab-primitives/Sources/Slab Primitives Core/Slab.swift:105` | `Slab<Element>` (`~Copyable`) | **B** | `~Copyable` fixed-capacity slab wrapping `Buffer.Slab.Bounded`. Ownership transfer primary. Direct analog of Agent 2's storage classes. | Appendix B17 |
| 37 | `swift-slab-primitives/Sources/Slab Primitives Core/Slab.swift:107` | `Slab.Static<let wordCount: Int>` (`~Copyable`) | **B** (flagged D candidate; LOW_CONFIDENCE) | `~Copyable` inline slab wrapping `Buffer.Slab.Inline<wordCount>`. Value-generic flagged per Agent 2 precedent. | Appendix B18 |
| 38 | `swift-slab-primitives/Sources/Slab Primitives Core/Slab.swift:109` | `Slab.Indexed<Tag: ~Copyable>` (`~Copyable`) | **B** (flagged D candidate; LOW_CONFIDENCE) | `~Copyable` wrapper around `Slab<Element>` with phantom `Tag: ~Copyable`. Ownership transfer primary; phantom Tag D-candidate signal. | Appendix B1 |
| 39 | `swift-machine-primitives/Sources/Machine Value Primitives/Machine.Value.swift:51` | `Machine.Value<Mode>._Storage` (`final class`) | **D candidate** | Class holds `let payload: UnsafeMutableRawPointer` (immutable) + `let table: _Table` (Sendable). Existing docstring already enumerates the D-signals: "payload pointer is immutable after construction", "table is Sendable (contains only @Sendable function)", "pointee is immutable". No synchronization, no `~Copyable`. `@unchecked` exists because `UnsafeMutableRawPointer` + the generic `Mode` (phantom) block structural inference. | — |
| 40 | `swift-machine-primitives/Sources/Machine Capture Primitives/Machine.Capture.Slot.swift:17` | `Machine.Capture.Slot` (struct) | **D candidate** | Struct wraps `_Storage` + `ObjectIdentifier` (Sendable) + debug-only `String`. Docstring already names the Sendable reasoning: "`_Storage` is `@unchecked Sendable` (immutable after construction)", "`type` is `ObjectIdentifier` which is Sendable". No synchronization, no `~Copyable`. The `@unchecked` is forced because the inner `_Storage` is itself `@unchecked`. | — |
| 41 | `swift-machine-primitives/Sources/Machine Capture Primitives/Machine.Capture.Slot.swift:37` | `Machine.Capture.Slot._Storage` (`final class`) | **D candidate** | Same shape as Machine.Value._Storage: immutable `let payload: UnsafeMutableRawPointer` + `let destroy: @Sendable ...`. Docstring identical reasoning. No synchronization, no `~Copyable`. | — |
| 42 | `swift-input-primitives/Sources/Input Primitives/Input.Buffer.swift:118` | `Input.Buffer<Storage: RandomAccessCollection & Sendable>` (`~Copyable`) | **B** | `~Copyable` cursor wrapping `Storage` + typed `position: Index<Storage.Element>`. Ownership transfer primary. Conformance gated on `Storage: Sendable, Storage.Index: Sendable` — this is coherent with B (a `~Copyable` container that transfers only when its constituent parts are Sendable). | Appendix B19 |
| 43 | `swift-loader-primitives/Sources/Loader Primitives/Loader.Library.Handle.swift:38` | `Loader.Library.Handle` (struct, `@unsafe`) | **D candidate** | Struct wraps `let rawValue: UnsafeMutableRawPointer` (immutable). No synchronization, no `~Copyable`. `@unchecked` exists because raw-pointer stored property blocks Sendable inference. Analogous to Agent 5's `Bit.Vector.Ones.View` / `Bit.Vector.Zeros.View` D-candidates (immutable raw-pointer wrappers). **Preexisting deviation**: the type is declared `@unsafe public struct Handle` — `@unsafe` on a struct is forbidden by [MEM-SAFE-021] because it would infect all self-accesses. Principal should separate-PR the struct-level `@unsafe` removal from this audit. | — |
| 44 | `swift-parser-machine-primitives/Sources/Parser Machine Core Primitives/Parser.Machine.Node.swift:13` | `Parser.Machine.Leaf<Input: ~Copyable & Parser.Input.Protocol, Failure: Error & Sendable>` (struct) | **D candidate** | Struct stores `let run: @Sendable (inout Input) throws(Failure) -> Value`. No `~Copyable`, no synchronization. `@unchecked` exists because the generic `Input: ~Copyable` is phantom to this struct (never stored — it only appears in the closure signature) and the `@Sendable` closure storage forces the conformance. Constraint `where Input: Sendable` betrays the phantom-type concern. Same family as Agent 5's closure-holding D candidates (`Predicate<T>`, `Sequence.Consume.View`). | — |
| 45 | `swift-test-primitives/Sources/Test Primitives Core/Test.Attachment.Collector.swift:30` | `Test.Attachment.Collector` (`final class`) | **A** | Class holds `private let _storage = Mutex<[Test.Attachment]>([])` (`Synchronization.Mutex`). All access through `_storage.withLock`. Canonical Cat A. | Appendix A7 |

---

## Appendix — Draft docstrings

All docstrings follow the pilot's three-section form (Safety Invariant / Intended Use / Non-Goals). Where the existing code already has a narrative docstring (e.g. `Clock.Immediate`'s SwiftUI preview example, `Loader.Library.Handle`'s platform notes), preserve the existing docstring and add the three sections below it.

For Category B sites, the Safety Invariant paragraph uses the ownership-transfer template. Every annotation should be written as extension-site where the existing form is extension-site, declaration-site where the existing form is declaration-site, matching the current file layout.

### Category A docstrings

#### Appendix A1 — `Async.Mutex._Lock`

```swift
/// Raw-layout storage wrapper for `os_unfair_lock_s`.
///
/// ## Safety Invariant
///
/// `_Lock` holds the raw bytes of an `os_unfair_lock_s` via `@_rawLayout`. It is
/// the synchronization primitive itself — Sendability here represents the
/// ability to transfer the enclosing `Async.Mutex` across threads along with
/// its lock state. All mutation goes through `os_unfair_lock_lock` /
/// `os_unfair_lock_unlock`, which are the platform's atomic primitives.
///
/// ## Intended Use
///
/// Used as the `_lockRaw` field of `Async.Mutex`. Not accessed directly.
///
/// ## Non-Goals
///
/// Not a standalone type — clients never construct `_Lock` independently.
/// The Sendable conformance exists solely because `Async.Mutex` holds this
/// as a stored field and must itself be Sendable.
struct _Lock: ~Copyable, @unsafe @unchecked Sendable {
    @inlinable init() {}
}
```

#### Appendix A2 — `Async.Mutex`

```swift
/// `Async.Mutex` is `Sendable` for any `Value`.
///
/// ## Safety Invariant
///
/// Internal `os_unfair_lock` serializes all access to the stored `Value`.
/// All mutation is routed through `withLock(_:)` or the `locked` `_read`
/// coroutine, both of which acquire the lock before yielding the value
/// and release it on scope exit. The `~Copyable` constraint on `Value`
/// ensures callers cannot accidentally copy the protected value out from
/// under the lock.
///
/// ## Intended Use
///
/// - Actor-free mutual exclusion for `~Copyable` or `Copyable` state.
/// - Coroutine-based direct property access: `mutex.locked.value.count += 1`.
/// - Transactional multi-step updates: `mutex.withLock { state in ... }`.
///
/// ## Non-Goals
///
/// Does NOT support recursive locking (`os_unfair_lock` is non-reentrant).
/// Does NOT coordinate with async suspension — this is a sync mutex; use
/// `Async.Semaphore` if you need cross-suspension mutual exclusion.
extension Async.Mutex: @unsafe @unchecked Sendable where Value: ~Copyable {}
```

#### Appendix A3 — `Async.Mutex._Value`

```swift
/// Raw-layout storage for the protected `Value`.
///
/// ## Safety Invariant
///
/// `_Value` holds the raw bytes of `Value` via `@_rawLayout(like: Value, movesAsLike)`.
/// All access to the stored value is serialized by the enclosing `Async.Mutex`'s
/// `_Lock` — callers must never reach into `_valuePointer()` except from within
/// `withLock` / `_read` scopes that have acquired the lock.
///
/// ## Intended Use
///
/// Used as the `_valueRaw` field of `Async.Mutex`. Not accessed directly by
/// consumers of the Mutex API.
///
/// ## Non-Goals
///
/// Not a standalone type. The Sendable conformance exists solely because
/// `Async.Mutex` holds this as a stored field and must itself be Sendable.
/// Access outside the enclosing Mutex's lock is a data race.
extension Async.Mutex._Value: @unsafe @unchecked Sendable where Value: ~Copyable {}
```

#### Appendix A4 — `Async.Mutex` (Embedded stub)

```swift
/// A no-op mutex for single-threaded embedded environments.
///
/// ## Safety Invariant
///
/// On embedded platforms there is no OS kernel and typically no threading,
/// so "mutual exclusion" is trivially satisfied by the absence of concurrent
/// observers. The Sendable conformance preserves API compatibility with the
/// platforms that do have real locks, while compiling to a no-op body.
///
/// ## Intended Use
///
/// - Platform-polymorphic code that depends on `Async.Mutex` must continue
///   to compile under `#if hasFeature(Embedded)` targets.
/// - As a compile-shim only — no runtime behavior is intended.
///
/// ## Non-Goals
///
/// Does NOT provide mutual exclusion. If embedded code ever gains threading
/// (custom scheduler, bare-metal multi-core), this stub MUST be replaced
/// with a real implementation.
public final class Mutex<Value: ~Copyable>: @unsafe @unchecked Sendable {
    // ...
}
```

#### Appendix A5 — `Clock.Immediate`

```swift
/// `Clock.Immediate` is `Sendable`.
///
/// ## Safety Invariant
///
/// Internal `Synchronization.Mutex<State>` serializes all access to `now`,
/// `minimumResolution`, and the cancellation signal. Every public accessor
/// goes through `state.withLock`.
///
/// ## Intended Use
///
/// - SwiftUI previews and other contexts where `sleep` should complete
///   instantly without real time elapsing.
/// - Deterministic unit tests of time-dependent code where wall-clock
///   delays are unacceptable.
/// - Shared across tasks and isolation domains (the Mutex makes this safe).
///
/// ## Non-Goals
///
/// Does NOT model real time. Do NOT use in production code paths that
/// require actual sleep semantics. Does NOT coordinate with the task
/// scheduler beyond `Task.checkCancellation()` on entry.
public final class Immediate: _Concurrency.Clock, @unsafe @unchecked Sendable {
    // ...
}
```

#### Appendix A6 — `Clock.Test`

```swift
/// `Clock.Test` is `Sendable`.
///
/// ## Safety Invariant
///
/// Internal `Synchronization.Mutex<State>` serializes all access to the
/// current instant, `minimumResolution`, the suspension list, and the
/// ID counter. Time advancement (`advance(by:)`, `advance(to:)`, `run()`)
/// and the corresponding resumption of waiting continuations all route
/// through `state.withLock`.
///
/// ## Intended Use
///
/// - Unit and integration tests of time-dependent async code where the
///   test harness controls time progression explicitly.
/// - Replacing a `ContinuousClock` / `SuspendingClock` in code-under-test
///   to exercise timer, debounce, throttle, and timeout operators.
///
/// ## Non-Goals
///
/// Does NOT model real time. Does NOT integrate with production timer
/// infrastructure. Tests that rely on `Clock.Test` must call `advance`
/// or `run` explicitly to unblock suspended continuations.
public final class Test: _Concurrency.Clock, @unsafe @unchecked Sendable {
    // ...
}
```

#### Appendix A7 — `Test.Attachment.Collector`

```swift
/// `Test.Attachment.Collector` is `Sendable`.
///
/// ## Safety Invariant
///
/// Internal `Synchronization.Mutex<[Test.Attachment]>` serializes all
/// `record` and `drain` operations. Assertion helpers called from multiple
/// test runner threads may concurrently append; `drain` atomically takes
/// the accumulated array and resets storage to empty.
///
/// ## Intended Use
///
/// - Accumulating diagnostic artifacts (diffs, snapshots, traces) from
///   failing assertions during a test run.
/// - Drained once by CI integrations after the test suite finishes to
///   surface attachments to the CI UI.
/// - Accessible from any isolation domain via the global
///   `Test.Attachment.collector` singleton.
///
/// ## Non-Goals
///
/// Does NOT preserve ordering guarantees across concurrent recorders.
/// Does NOT bound memory usage — consumers are expected to `drain`
/// periodically.
public final class Collector: @unsafe @unchecked Sendable {
    // ...
}
```

### Category B docstrings

#### Appendix B-Iter — Iterator family template

(Applies to: Array.Iterator #2, Array.Fixed.Iterator #3, Array.Small.Iterator #5, Set.Ordered.Fixed.Iterator #18, Set.Ordered.Iterator #19, Dictionary.Ordered.Values.Iterator #25.)

```swift
/// `{IteratorType}` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Wraps `{WrappedBufferIterator}` whose internal state holds raw pointers
/// into CoW-backed storage. The iterator is a one-shot iteration token;
/// sending it across threads transfers the iteration state as a
/// move-equivalent unit. The underlying buffer must not be mutated while
/// the iterator is in use.
///
/// ## Intended Use
///
/// - Producing elements on one thread and consuming them on another where
///   the iterator is fully constructed before transfer.
/// - Routing iteration through an actor that owns the consumer side.
///
/// ## Non-Goals
///
/// Does NOT support concurrent iteration — two threads must not advance
/// the same iterator. Sendability is transfer, not sharing.
extension {IteratorType}: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B1 — Phantom-Tag `~Copyable` wrapper family

(Applies to: Array.Fixed.Indexed #4, Array.Small.Indexed #7, Slab.Indexed #38.)

```swift
/// `{IndexedType}` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership of the wrapped container. The
/// phantom `Tag` is never stored — it exists only to smuggle typed index
/// access. Transfer across threads is a move of the wrapped container;
/// the old thread cannot access the wrapper after the move.
///
/// ## Intended Use
///
/// - Type-safe index access via `Index<Tag>` where `Tag` differs from
///   `Element`, with ownership-transfer semantics inherited from the
///   wrapped container.
///
/// ## Non-Goals
///
/// Does NOT support concurrent access — ownership is single-owner and
/// transfer is one-shot.
extension {IndexedType}: @unsafe @unchecked Sendable where Element: Sendable, Tag: ~Copyable {}
```

#### Appendix B2 — `Array.Small<let inlineCapacity: Int>`

```swift
/// `Array.Small` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership. The small-buffer-optimized
/// storage (inline path up to `inlineCapacity`, heap path after spill)
/// travels as one unit under ownership transfer. The old thread cannot
/// access the array after the move.
///
/// ## Intended Use
///
/// - Cross-thread transfer of a small-buffer-optimized array (inline fast
///   path, heap spill path, same handoff semantics).
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation. Ownership is single-owner;
/// transfer is one-shot.
extension Array.Small: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B3 — `Array.Static<let capacity: Int>`

```swift
/// `Array.Static` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` guarantees single ownership of the inline storage. Transfer
/// across threads is a move; the old thread cannot access the array after
/// the move. All storage is inline in the struct — no heap allocation.
///
/// ## Intended Use
///
/// - Zero-allocation cross-thread transfer of a compile-time-sized array.
/// - Embedded / real-time contexts where heap allocation is forbidden.
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation. Ownership is single-owner;
/// transfer is one-shot.
extension Array.Static: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B4 — `Array<Element>`

```swift
/// `Array` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` (conditionally `Copyable` when `Element: Copyable`). Ownership
/// transfer across threads is a move: the CoW `Buffer.Linear` storage
/// reference travels with the array, and the old thread loses access. When
/// `Element: Copyable`, CoW via `isKnownUniquelyReferenced` ensures
/// mutations never observe shared storage.
///
/// ## Intended Use
///
/// - Handoff of a producer-filled array to a consumer thread.
/// - Sending into an `actor`'s initializer.
/// - Move-only `Element` storage (e.g. `Array<FileHandle>`).
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation. The array has no internal locks.
/// Ownership is single-owner; transfer is one-shot.
extension Array: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B5 — `Array.Fixed`

```swift
/// `Array.Fixed` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Fixed-count heap-allocated array wrapping `Buffer.Linear.Bounded` with
/// CoW on `Element: Copyable`. Ownership transfer across threads is a move;
/// the old thread loses access. CoW ensures mutations never observe shared
/// storage.
///
/// ## Intended Use
///
/// - Handoff of a fixed-count array between producer/consumer threads.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation. Ownership is single-owner;
/// transfer is one-shot.
extension Array.Fixed: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B6 — `Array.Bounded<let N: Int>`

```swift
/// `Array.Bounded` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` compile-time-dimensioned array wrapping `Buffer.Linear.Bounded`
/// with CoW on `Element: Copyable`. The `<let N: Int>` value-generic pins
/// the dimension at compile time; the `Algebra.Z<N>` index type guarantees
/// in-bounds access. Ownership transfer across threads is a move.
///
/// ## Intended Use
///
/// - Handoff of a compile-time-dimensioned array between threads.
/// - Contexts where the dimension is a type-level invariant carried across
///   ownership transfers.
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation. Ownership is single-owner;
/// transfer is one-shot.
extension Array.Bounded: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B7 — `Set.Ordered`

```swift
/// `Set.Ordered` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` (conditionally `Copyable` when `Element: Copyable`). Composes
/// `Buffer.Linear` for insertion-ordered element storage + `Hash.Table` for
/// O(1) position lookup. Ownership transfer across threads is a move of the
/// composite; both the buffer and the hash table travel together, and the
/// old thread loses access.
///
/// ## Intended Use
///
/// - Handoff of a producer-populated ordered set to a consumer thread.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent insertion/removal. Ownership is single-owner;
/// transfer is one-shot.
extension Set.Ordered: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B8 — `Set.Ordered.Fixed`

```swift
/// `Set.Ordered.Fixed` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// Fixed-capacity ordered set composing `Buffer.Linear.Bounded` + `Hash.Table`.
/// Throws on overflow. Ownership transfer across threads is a move.
///
/// ## Intended Use
///
/// - Handoff of a fixed-capacity ordered set between threads.
///
/// ## Non-Goals
///
/// Does NOT support concurrent insertion/removal. Ownership is single-owner;
/// transfer is one-shot.
extension Set.Ordered.Fixed: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B9 — `Set.Ordered.Small<let inlineCapacity: Int>`

```swift
/// `Set.Ordered.Small` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` small-buffer ordered set composing `Buffer.Linear.Small` +
/// conditional heap hash table (allocated only after spill). Ownership
/// transfer across threads is a move of the composite.
///
/// ## Intended Use
///
/// - Cross-thread transfer of a small-buffer-optimized ordered set.
///
/// ## Non-Goals
///
/// Does NOT support concurrent insertion/removal. Ownership is single-owner;
/// transfer is one-shot.
extension Set.Ordered.Small: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B10 — `Set.Ordered.Static<let capacity: Int>`

```swift
/// `Set.Ordered.Static` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` inline-storage ordered set composing `Buffer.Linear.Inline`
/// + `Hash.Table.Static`. All storage is inline — no heap allocation.
/// Ownership transfer across threads is a move.
///
/// ## Intended Use
///
/// - Zero-allocation cross-thread transfer of a compile-time-sized
///   ordered set.
///
/// ## Non-Goals
///
/// Does NOT support concurrent insertion/removal. Ownership is single-owner;
/// transfer is one-shot.
extension Set.Ordered.Static: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B11 — `Dictionary<Key, Value>`

```swift
/// `Dictionary` is `Sendable` when its keys and values are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` (conditionally `Copyable` when `Value: Copyable`). Composes
/// `Hash.Table<Key>` + `Buffer<Key>.Slab` + `Buffer<Value>.Slab` for
/// O(1) hash-indexed removal without element shifting. Ownership transfer
/// across threads is a move of the composite.
///
/// ## Intended Use
///
/// - Handoff of a producer-filled dictionary to a consumer thread.
/// - Sending into an `actor`'s initializer.
/// - Move-only value storage (e.g. `Dictionary<String, FileHandle>`).
///
/// ## Non-Goals
///
/// Does NOT support concurrent insertion/removal. Ownership is single-owner;
/// transfer is one-shot.
extension Dictionary: @unsafe @unchecked Sendable where Key: Sendable, Value: Sendable {}
```

#### Appendix B12 — `Dictionary.Ordered`

```swift
/// `Dictionary.Ordered` is `Sendable` when its keys and values are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` ordered dictionary composing `Set<Key>.Ordered` + `Buffer<Value>.Linear`
/// with 1:1 index correspondence. Ownership transfer across threads is a move.
/// The existing docstring already states: "Not thread-safe for concurrent
/// mutation. Synchronize externally."
///
/// ## Intended Use
///
/// - Handoff of an ordered dictionary between producer/consumer threads.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation. Ownership is single-owner;
/// transfer is one-shot.
extension Dictionary.Ordered: @unsafe @unchecked Sendable where Key: Sendable, Value: Sendable {}
```

#### Appendix B13 — `Dictionary.Ordered.Bounded`

```swift
/// `Dictionary.Ordered.Bounded` is `Sendable` when its keys and values are `Sendable`.
///
/// ## Safety Invariant
///
/// Fixed-capacity ordered dictionary. Ownership transfer across threads is a
/// move of the composite.
///
/// ## Intended Use
///
/// - Handoff of a fixed-capacity ordered dictionary between threads.
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation. Ownership is single-owner;
/// transfer is one-shot.
extension Dictionary.Ordered.Bounded: @unsafe @unchecked Sendable where Key: Sendable, Value: Sendable {}
```

#### Appendix B14 — `Dictionary.Ordered.Small<let inlineCapacity: Int>`

```swift
/// `Dictionary.Ordered.Small` is `Sendable` when its keys and values are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` small-buffer ordered dictionary. Inline path stores up to
/// `inlineCapacity` keys + values; spill path migrates to heap. The
/// composite travels as one unit under ownership transfer.
///
/// ## Intended Use
///
/// - Cross-thread transfer of a small-buffer-optimized ordered dictionary.
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation. Ownership is single-owner;
/// transfer is one-shot.
extension Dictionary.Ordered.Small: @unsafe @unchecked Sendable where Key: Sendable, Value: Sendable {}
```

#### Appendix B15 — `Dictionary.Ordered.Static<let capacity: Int>`

```swift
/// `Dictionary.Ordered.Static` is `Sendable` when its keys and values are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` inline-storage ordered dictionary composing `Hash.Table.Static`
/// + inline key/value buffers. All storage is inline — no heap allocation.
/// Ownership transfer across threads is a move.
///
/// ## Intended Use
///
/// - Zero-allocation cross-thread transfer of a compile-time-sized ordered
///   dictionary.
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation. Ownership is single-owner;
/// transfer is one-shot.
extension Dictionary.Ordered.Static: @unsafe @unchecked Sendable where Key: Sendable, Value: Sendable {}
```

#### Appendix B16 — `Async.Timer.Wheel.Storage`

```swift
/// `Async.Timer.Wheel.Storage` is `Sendable` (unconditionally — nodes are internal
/// and not exposed to consumers).
///
/// ## Safety Invariant
///
/// `~Copyable` arena-backed node storage wrapping `Buffer.Node.Arena.Bounded`
/// with generation tokens for per-slot ABA protection. The existing docstring
/// already states the invariant: "the wheel is `~Copyable` and intended for
/// single-actor use. All mutations are serialized by the owning actor." This
/// is ownership transfer, not internal synchronization — the serialization
/// happens one level up, at the actor that owns the Wheel.
///
/// ## Intended Use
///
/// - Internal storage for `Async.Timer.Wheel` — not surfaced publicly.
/// - Transferred as part of the enclosing Wheel's ownership hand-off to
///   the actor that will drive scheduling.
///
/// ## Non-Goals
///
/// Does NOT support concurrent mutation. All access must be serialized by
/// the owning actor. Sendability is ownership transfer, not sharing.
struct Storage: ~Copyable, @unsafe @unchecked Sendable {
    // ...
}
```

#### Appendix B17 — `Slab<Element>`

```swift
/// `Slab` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` fixed-capacity slab wrapping `Buffer.Slab.Bounded` — bitmap-
/// tracked occupancy with O(1) insert/remove at consumer-chosen indices.
/// Ownership transfer across threads is a move; the old thread loses access.
///
/// ## Intended Use
///
/// - Cross-thread handoff of a slab with consumer-chosen slot indices.
/// - Sending into an `actor`'s initializer.
///
/// ## Non-Goals
///
/// Does NOT support concurrent insert/remove. Ownership is single-owner;
/// transfer is one-shot.
extension Slab: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B18 — `Slab.Static<let wordCount: Int>`

```swift
/// `Slab.Static` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` inline slab wrapping `Buffer.Slab.Inline<wordCount>`. All
/// storage is inline — the bitmap and slot array sit in the struct. Ownership
/// transfer across threads is a move.
///
/// ## Intended Use
///
/// - Zero-allocation cross-thread transfer of a compile-time-sized slab.
///
/// ## Non-Goals
///
/// Does NOT support concurrent insert/remove. Ownership is single-owner;
/// transfer is one-shot.
extension Slab.Static: @unsafe @unchecked Sendable where Element: Sendable {}
```

#### Appendix B19 — `Input.Buffer<Storage>`

```swift
/// `Input.Buffer` is `Sendable` when its storage and storage index are `Sendable`.
///
/// ## Safety Invariant
///
/// `~Copyable` parser-input cursor wrapping `Storage: RandomAccessCollection &
/// Sendable` + typed `position: Index<Storage.Element>`. Single-ownership
/// ensures the cursor travels as one unit across threads, preserving the
/// checkpoint/restore semantics the parser depends on.
///
/// ## Intended Use
///
/// - Cross-thread handoff of a parser cursor for pipeline-style parsing
///   (e.g. producer reads bytes, consumer parses them).
/// - Sending into an `actor` that owns the parsing loop.
///
/// ## Non-Goals
///
/// Does NOT support concurrent cursor advancement — two threads must not
/// hold the same cursor. Sendability is ownership transfer, not sharing.
extension Input.Buffer: @unsafe @unchecked Sendable where Storage: Sendable, Storage.Index: Sendable {}
```

---

## Low-Confidence Flags

Eight entries are flagged LOW_CONFIDENCE on the B-vs-D boundary per Agent 2's precedent for `<let N: Int>` value-generic containers and phantom-Tag wrappers:

1. **#4 Array.Fixed.Indexed** — phantom `Tag: ~Copyable`; `~Copyable` outer. B primary, D plausible.
2. **#6 Array.Small** — `<let inlineCapacity: Int>`; `~Copyable`. B primary, D plausible per Agent 2.
3. **#7 Array.Small.Indexed** — `<let inlineCapacity: Int>` + phantom `Tag: ~Copyable`. B primary, D plausible.
4. **#8 Array.Static** — `<let capacity: Int>`; `~Copyable`. B primary, D plausible per Agent 2.
5. **#11 Array.Bounded** — `<let N: Int>`; `~Copyable`. B primary, D plausible.
6. **#14 Set.Ordered.Small** — `<let inlineCapacity: Int>`; `~Copyable`. B primary, D plausible per Agent 2.
7. **#15 Set.Ordered.Static** — `<let capacity: Int>`; `~Copyable`. B primary, D plausible per Agent 2.
8. **#23 Dictionary.Ordered.Small** — `<let inlineCapacity: Int>`; `~Copyable`. B primary, D plausible per Agent 2.

Additionally:

- **#24 Dictionary.Ordered.Static** — `<let capacity: Int>`; `~Copyable`. Same B-vs-D tension. (Listed for completeness; same plus-one judgement as #23.)
- **#37 Slab.Static** — `<let wordCount: Int>`; `~Copyable`. Same.
- **#38 Slab.Indexed** — phantom `Tag: ~Copyable`. Same.
- **#29 Async.Mutex._Value** — `@_rawLayout(like: Value, movesAsLike)` shape is structurally identical to Agent 2's `_Raw` D-candidates. However, the runtime invariant "access only under the enclosing lock" is a real caller invariant, which pushes this to Cat A. LOW_CONFIDENCE on A-vs-D; filed as A because the invariant is non-trivial.
- **#30 Async.Mutex (Embedded stub)** — no-op on single-threaded platforms. A-vs-C tension: classified A for family consistency, but C (thread-confined) is structurally honest. Principal to adjudicate.

Principal should decide whether to treat the `<let N: Int>` value-generic + `~Copyable` family as B (ownership transfer primary, value-generic secondary) or as D (structural inference workaround, ownership incidental), ideally consistently with Agent 2's eventual adjudication.

The three Indexed phantom-Tag `Copyable` wrappers (#1 Array.Dynamic.Indexed, #16 Set.Ordered.Fixed.Indexed, #17 Set.Ordered.Indexed) are listed **ONLY** as D candidates — these are `Copyable` structs where the phantom Tag is the only reason `@unchecked` appears; there is no `~Copyable` ownership invariant to fall back on.

## Preexisting Warnings

- **Loader.Library.Handle (#43)**: the struct is declared `@unsafe public struct Handle`. Per [MEM-SAFE-021], `@unsafe` on a struct/class is the correctly-avoided pattern in the ecosystem — it infects every `self`-access. Zero `@unsafe struct` sites were found ecosystem-wide per the Phase 0 inventory (`unsafe-audit-findings.md` §Q3). Handle is an **exception** that predates this audit; it should be separately PR'd to remove the struct-level `@unsafe` and reduce the surface to the genuine `@unsafe` operations (e.g. the pointer dereference). Out of scope for this audit; flagged for principal.
- No compiler warnings encountered while reading Sources/ for the 11 packages. The repos compile clean under `.strictMemorySafety()` per the Phase 0 inventory.
