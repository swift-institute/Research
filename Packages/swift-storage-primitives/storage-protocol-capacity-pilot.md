# Storage.Protocol Capacity Pilot — Wave 1 Findings

**Status**: CONFIRMED (SIL gate PASS)
**Date**: 2026-05-25
**Toolchain**: Apple Swift 6.3.2 (default macOS toolchain), macOS 26 (arm64)
**Branch**: `spike/storage-protocol` (swift-storage-primitives + swift-storage-pool-primitives)
**Scope**: `Storage.Inline` (struct) + `Storage.Protocol` in swift-storage-primitives; `Storage.Pool` (class) in swift-storage-pool-primitives. Heap / Split / buffer untouched.

## Objective

Give `Storage.Protocol` its natural typed name (`capacity: Index<Element>.Count`) and empirically prove a `some Storage.\`Protocol\`` generic specializes to **zero witness-table dispatch** through one real STRUCT conformer (`Storage.Inline`) AND one real CLASS conformer (`Storage.Pool`), in release + cross-module. This closes the [EXP-020] synthetic-to-production gap for the non-Heap, non-ManagedBuffer conformers.

## Protocol (no change required)

`Storage.Protocol` (hoisted `__StorageProtocol`, namespace alias `Storage.\`Protocol\``) already required the natural-named members at baseline — no rename was needed:

- `var capacity: Index<Element>.Count { get }` (already the natural name; the brief's `slotCapacity` retirement applies only to the leaves)
- `@unsafe func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element>`

Only the doc comment was reviewed (it referenced `capacity` / `pointer(at:)`, not `slotCapacity`, so no edit). File: `Sources/Storage Protocol Primitives/Storage.Protocol.swift`.

## Per-leaf inventory (had vs added)

### `Storage.Inline` (struct, `~Copyable`) — swift-storage-primitives

| Requirement | Baseline | Wave-1 action |
|---|---|---|
| Value-generic name | `Inline<let capacity: Int>` — blocked a `capacity` property | **Renamed** to `Inline<let count: Int>` everywhere it resolves (struct decl, `precondition(count <= 256)`, `@_rawLayout(...count: count)`, `Bounded<count>` in `extension Storage.Inline`, invariant doc comments). The `Property.Inout` extension methods declared their own positional `<let capacity: Int>` generics; those were renamed to `<let count: Int>` for consistency (independent declarations; binding is positional). |
| `capacity: Index<Element>.Count` | exposed as compound `slotCapacity` | **Renamed** `slotCapacity` → `capacity` (the renamed value-generic freed the name). Internal user `Storage.Inline+Initialize.swift` (`base.value.slotCapacity` → `base.value.capacity`) updated. The compound `slotCapacity` is fully retired in the Inline layer — no permanent alias. |
| `pointer(at: Index<Element>) -> UnsafeMutablePointer<Element>` | **absent as a public unbounded form** — Inline had `package func pointer(at: Index<Element>) -> UnsafePointer` (immutable), `package _mutablePointer(at:) -> UnsafeMutablePointer`, and `public func pointer(at: Index<Element>.Bounded<count>)` overloads | **Added** the public unbounded witness `pointer(at: Index<Element>) -> UnsafeMutablePointer<Element>` (delegates to `_mutablePointer(at:)`), mirroring `Storage.Heap+pointer.swift`. New file `Storage.Inline+Storage.Protocol.swift`. |
| Conformance | none | **Added** `extension Storage.Inline: Storage.\`Protocol\` where Element: ~Copyable {}` (same file; conformance + witness co-located per [API-IMPL-008]/[MEM-COPY-006]). |
| Package dep | `Storage Inline Primitives` did not depend on `Storage Protocol Primitives` | **Added** that dep to the target. |

### `Storage.Pool` (`final class`) — swift-storage-pool-primitives

| Requirement | Baseline | Wave-1 action |
|---|---|---|
| `capacity: Index<Element>.Count` | **already present** (`Storage.Pool ~Copyable.swift`, delegates to `_pool.capacity.retag(...)`) | none |
| `pointer(at: Index<Element>) -> UnsafeMutablePointer<Element>` | **already present** (`Storage.Pool.swift`, the non-disfavored mutable form; an immutable `@_disfavoredOverload` exists too) | none |
| Conformance | none | **Added** `extension Storage.Pool: Storage.\`Protocol\` where Element: ~Copyable {}`. New file `Storage.Pool+Storage.Protocol.swift`. |
| Package dep | did not depend on `Storage Protocol Primitives` (already depends on swift-storage-primitives for 4 other products) | **Added** that dep — clean L1→L1 within the storage family; no dep-direction question. |

Pool is NOT a ManagedBuffer subclass; `init(capacity: Index<Element>.Count)` and the direct `capacity`/`pointer(at:)` exposure required no restructure (as the brief anticipated).

## SIL gate (the hypothesis) — PASS

**Experiment**: `swift-storage-pool-primitives/Experiments/storage-protocol-sil-gate/` (placed in the highest-layer dep per [EXP-002c]: the pool package depends on swift-storage-primitives, so it transitively owns both conformers).

- Module 1 `StorageProtocolGeneric`: `@inlinable func probe<S: Storage.\`Protocol\` & ~Copyable>(_ s: borrowing S, at: Index<Int>) -> Int where S.Element == Int` — touches BOTH `capacity` and `pointer(at:)`.
- Module 2 `storage-protocol-sil-gate` (`main`): calls `probe` with a concrete `Storage<Int>.Inline<8>` AND a concrete `Storage<Int>.Pool`. Cross-module + release per [EXP-017].

**Receipts** (`Experiments/storage-protocol-sil-gate/Outputs/`):
- `build-release.txt` — cross-module release build (compiles `StorageProtocolGeneric` then `storage_protocol_sil_gate` then links).
- `run.txt` — runtime: `inline probe = 50` (42 + capacity 8), `pool probe = 107` (99 + capacity 8).
- `exe.sil` — full optimized SIL of the executable module (`swiftc -emit-sil -O`, same flags as SwiftPM release).
- `sil-grep.txt` — the analysis receipt.

**Result**: `0 witness_method` AND `0 class_method` in the entire optimized cross-module executable. Under `-O` the `@inlinable probe<S>` body inlines into both concrete callers; the inlined witness sites are:

- **Inline (struct)** — `callInline` SIL: `capacity` → constant-folded to `integer_literal $Builtin.Int64, 8`; `pointer(at:)` → concrete `address_to_pointer` / `index_raw_pointer` / `pointer_to_address` arithmetic. No witness.
- **Pool (class)** — `callPool` SIL: `capacity` → direct `struct_extract` chain through `Memory.Pool._capacity`; `pointer(at:)` → direct `function_ref` to `Memory.Pool.pointer(at:)` (concrete static dispatch). No witness, no `class_method`.

The `Tg5`-suffixed specialized `function_ref`s present in the SIL are the test-setup Property accessors (Inline initialize/move; Pool init/allocate/deallocate) — concrete specialized clones, not witness dispatch, and not part of `probe`.

## Deviations / forwarders

1. **No `slotCapacity` forwarder retained.** The compound name is fully retired in the Inline layer per [API-NAME-002]; no transient internal forwarder was needed (the package builds standalone with the rename alone).
2. **`pointer(at:)` overload ambiguity at Inline test call sites (resolved, not a forwarder).** Adding the public unbounded `pointer(at: Index<Element>)` witness created an overload set with the pre-existing bounded `pointer(at: Index<Element>.Bounded<count>)`. Integer-literal / `.init(integerLiteral:)` call sites in the Inline test suite (`Storage.Inline Tests.swift`, `Storage.Inline Invariants Tests.swift`, `Storage.Inline Edge Cases Tests.swift`) became ambiguous and were disambiguated to the bounded form (`<lit> as Index<E>.Bounded<N>`, or a typed `Bounded` argument). This is an intrinsic consequence of the directed "add the unbounded witness" action, not an API regression — production call sites use the typed forms. Both Inline tests (135) and Pool tests (15) pass.
3. **`Property.Inout` local generics renamed for consistency.** The `extension Property.Inout` methods in `Storage.Inline+{Initialize,Move,Deinitialize}.swift` declared their own positional `<let capacity: Int>` generics (independent of the struct's value-generic; they bind by position to `Inline<...>`). Renamed to `<let count: Int>` so the Inline surface uniformly names the slot-count dimension `count`. Functionally a no-op (positional binding).

## Verification summary

- `Storage.Protocol.swift` requires `capacity: Index<Element>.Count` + `pointer(at:)` (disk).
- `swift build` + `swift test` green in BOTH packages; Inline + Pool conform to `Storage.\`Protocol\``.
- SIL receipt: 0 `witness_method` on `capacity`/`pointer(at:)` for BOTH conformers, release + cross-module.
- Zero diffs to `Storage.Heap`, swift-storage-split-primitives, any swift-buffer-* package.

## Cross-references

- [EXP-017] release + cross-module validation; [EXP-020] synthetic-to-production gap (this pilot closes it for Inline + Pool).
- [API-NAME-002] compound-name retirement (`slotCapacity` → `capacity`).
- [API-IMPL-008] / [MEM-COPY-006] conformance + witness co-location for `~Copyable`-aware types.
- `Storage.Protocol.swift:67-69` — Split is explicitly multi-region and non-conforming (out of scope).

---

# Wave 3 Findings — Storage.Heap value-type façade (Opt A)

**Status**: CONFIRMED (SIL gate PASS)
**Date**: 2026-05-25
**Toolchain**: Apple Swift 6.3.2 (default macOS toolchain), macOS 26 (arm64)
**Branch**: `spike/storage-protocol` (swift-storage-primitives only)
**Scope**: `Storage.Heap` in swift-storage-primitives ONLY. Buffer-layer CoW call-site change, swift-storage-split-primitives, and the rest of the storage family are SEPARATE later waves — untouched here.

## Objective

Restructure `Storage.Heap` from a stdlib-`ManagedBuffer` SUBCLASS into a **value-type façade** (the stdlib `Array` pattern, principal-decided Opt A), conform it to `Storage.\`Protocol\`` with the natural typed `capacity: Index<Element>.Count`, and prove it specializes to zero witness/class dispatch through `some Storage.\`Protocol\``. The façade makes `Storage.Heap` stop publicly leaking `ManagedBuffer.capacity: Int`, which was the exact collision that blocked conforming the class to a protocol requiring `capacity: Index<Element>.Count`.

## The shape that landed

| Layer | Before (class) | After (Opt A façade) |
|---|---|---|
| Public type | `public final class Heap: ManagedBuffer<Header, Element>` (Storage.Heap.swift:39) | `public struct Heap: ~Copyable` (value-type façade) under `extension Storage where Element: ~Copyable` |
| The allocation | the class itself (1 combined header+tail alloc) | `Storage.Heap.Buffer` — a `@usableFromInline final class Buffer: ManagedBuffer<Header, Element>` carrying the slot-deinit; the ONE heap allocation, internal (not public) |
| Façade storage | — | `@usableFromInline var _buffer: Buffer` (a value field holding the one class ref) |
| Capacity surface | inherited public `ManagedBuffer.capacity: Int` + a typed `slotCapacity: Index<Element>.Count` | ONLY `public var capacity: Index<Element>.Count` (computed from the now-private `_buffer.capacity: Int`). No public `capacity: Int` remains — the collision is gone. `slotCapacity` retired. |
| Conformance | none (the `Int`/`Index<>.Count` `capacity` collision blocked it) | `extension Storage.Heap: Storage.\`Protocol\` where Element: ~Copyable {}` (Storage.Heap+Storage.Protocol.swift) |

### What moved to PRIVATE (the `Buffer` allocation class)

`Storage.Heap.Buffer` (renamed from the would-be `_Buffer` — `Buffer` nested under `Storage.Heap` reads `Storage.Heap.Buffer`, a proper Nest.Name, not compound). It is `@usableFromInline`, NOT public, and is declared as a **sibling member of `extension Storage where Element: ~Copyable`** (not nested inside the struct body). The sibling placement is load-bearing: nesting the `ManagedBuffer<_, Element>`-subclass inside the `~Copyable` struct body did NOT propagate the enclosing extension's `Element: ~Copyable` suppression (compiler error `type 'Element' does not conform to protocol 'Copyable'` at the `ManagedBuffer<_, Element>` clause). Declaring it as an extension sibling — the same placement the predecessor public `Heap` class used — propagates the suppression. It carries the slot-deinit (iterate `header.initialization` ranges, deinitialize the initialized slots).

### What stays on / moved onto the FAÇADE (delegating to `_buffer`)

All existing public Heap API moved onto the struct and delegates to `_buffer`:

- `create(minimumCapacity:)` — allocates the `Buffer` via `Buffer.create` + `unsafeDowncast`, wraps in `Storage.Heap(_buffer:)`.
- `pointer(at:)` (the `Storage.\`Protocol\`` witness, mutable + `@_disfavoredOverload` immutable) — delegates to `_buffer.withUnsafeMutablePointerToElements`.
- `capacity: Index<Element>.Count` (typed witness), `initialization` get/`nonmutating set`, `isEmpty` — delegate to `_buffer.capacity` / `_buffer.header`.
- `span`, `withUnsafeBufferPointer` (the `Span.Protocol` witness), `withMutableSpan`, `withUnsafeMutableBufferPointer` — delegate to `_buffer.header` + `pointer(at:)`.
- The tracked accessors `initialize` / `move` / `deinitialize` (and the `Copyable` `copy`) — see the Property migration below.

### Property accessor migration: method-case → `Property.Inout`

The class form used the **method-case** `Property<Tag>` pattern (`var initialize: Property<Storage.Initialize, Storage.Heap>` with `Property(self)` and extensions on `Property` doing `base.header.initialization = …`). That pattern transfers the base into the `Property` by value — fine for a Copyable class (copies the shared reference), impossible for a `~Copyable` struct through a non-mutating accessor. The façade therefore migrates these accessors to the **`Property.Inout`** pattern — the canonical `~Copyable` shape already used by `Storage.Inline` in wave 1:

```swift
public var initialize: Property<Storage.Initialize, Self>.Inout {
    mutating _read  { yield Property<Storage.Initialize, Self>.Inout(&self) }
    mutating _modify { var a = Property<Storage.Initialize, Self>.Inout(&self); yield &a }
}
extension Property.Inout where Base: ~Copyable {
    public mutating func next<Element: ~Copyable>(to: consuming Element) throws(…) -> Index<Element>
    where Tag == Storage<Element>.Initialize, Base == Storage<Element>.Heap { … base.value.initialization … }
}
```

Method bodies change `base.X` → `base.value.X` and `base.header.X` → `base.value.initialization` (delegating through the façade's accessor, which reaches `_buffer.header`). The public call-site surface is preserved (`heap.initialize.next(to:)`, `heap.move.last()`, `heap.deinitialize.all()`, `heap.copy()`, `heap.move(at:)`, `heap.deinitialize(range:)`, …). The accessor's underlying Property *variant* changed; the spelling did not.

### CoW uniqueness primitive (stays inside Heap)

The façade exposes the CoW uniqueness primitive (Storage.Heap ~Copyable.swift):

- `var isUnique: Bool { mutating get { isKnownUniquelyReferenced(&_buffer) } }`
- `mutating func ensureUnique() -> Bool` (the `~Copyable`-Element overload reports uniqueness; copying to restore uniqueness requires `Element: Copyable` and is not expressible for `~Copyable` elements — those owners maintain uniqueness structurally).

`_buffer` is `var` (not the brief's literal `let`) for exactly one reason: `isKnownUniquelyReferenced(&_buffer)` requires a mutable reference. This is the same reason the stdlib `Array` holds its `_buffer` mutably. It does **not** affect the single-allocation invariant — `var` here is value-level reassignability of the struct's one field, not a second heap allocation. (If a future `let`-only uniqueness primitive lands, the field can revert; the explicitly-required `isKnownUniquelyReferenced(&_buffer)` mechanism is what forces `var` today.)

### Deferred: the buffer-layer CoW call-site change

The buffer LAYER currently calls `isKnownUniquelyReferenced(&storage)` directly on the Heap storage. Swapping that call site to the façade's `ensureUnique()` / `isUnique` primitive is the **next downstream wave** — it touches `swift-buffer-*` packages, which are out of scope here (single-writer / branch isolation). This wave only *exposes* the primitive on the façade; no buffer package was touched.

## Single allocation — preserved (how)

One `Storage.Heap.Buffer` (`ManagedBuffer` subclass) allocation per `Heap`; the façade is a value wrapping that one class reference. The SIL confirms it directly: `callHeap`'s body has exactly one `alloc_ref [tail_elems $Int * %1] $Storage<Int>.Heap.Buffer` (the single combined header+tail allocation), and `%9 = struct $Storage<Int>.Heap (%2)` wraps that class ref into the value-type façade with no second allocation. There is no façade-class-holding-a-separate-buffer double-alloc, and `~Copyable` Element support is retained (the `Buffer` keeps subclassing `ManagedBuffer`, which is what supports `~Copyable` tail elements + the combined allocation + the slot-deinit).

## SIL gate (the hypothesis) — PASS

**Experiment**: `swift-storage-primitives/Experiments/storage-protocol-heap-sil-gate/` (placed in storage-primitives per [EXP-002c] — storage-primitives owns `Storage.Heap`; the wave-1/2 `storage-protocol-sil-gate` in swift-storage-pool-primitives was NOT edited, per scope).

- Module 1 `StorageHeapProtocolGeneric`: `@inlinable func probe<S: Storage.\`Protocol\` & ~Copyable>(_ s: borrowing S, at: Index<Int>) -> Int where S.Element == Int` — touches BOTH `capacity` and `pointer(at:)`.
- Module 2 `storage-protocol-heap-sil-gate` (`main`): calls `probe` with a concrete `Storage<Int>.Heap`. Cross-module + release per [EXP-017].

**Receipts** (`Experiments/storage-protocol-heap-sil-gate/Outputs/`): `build-release.txt` (cross-module release build), `run.txt` (`heap probe = 51` — pointee 42 + capacity; `ManagedBuffer` over-allocates ≥ the requested 8, so capacity is 9 here, expected), `exe.sil` (full optimized SIL via `swiftc -emit-sil -O` with the SwiftPM release flags + SDK), `sil-grep.txt` (the analysis receipt).

**Result**: **0 `witness_method` AND 0 `class_method`** in the entire optimized cross-module executable. Under `-O` the `@inlinable probe<S>` body inlines into the concrete `callHeap`; the inlined witness sites are:

- `capacity` → inlined concrete capacity computation through the backing `ManagedBuffer` (`_swift_stdlib_malloc_size` → pointer-delta `sub_Word` → `sdiv_Int64` by 8 = `MemoryLayout<Int>.stride`). No witness.
- `pointer(at:)` → inlined concrete tail-element address arithmetic (`ref_tail_addr` + `index_addr`). No witness, no `class_method`.
- The `probe` body itself fully inlines (`load` pointee + `sadd_with_overflow` with capacity = `pointee &+ capacity`).

The `Property.Inout` setup/teardown for the `.one(…)` initialization store and `deinitialize` are concrete inlined SIL (Property.Inout accessors + `ManagedBuffer.header` stores), NOT witness/class dispatch. This closes [EXP-020] for `Storage.Heap`.

## Storage-internal users updated (same package)

- `Storage.Inline` `copy(to:)` / `copy(range:to:)` (Storage.Inline Copyable.swift) and the cross-storage `move(range:to:[at:])` (Storage.Inline+Move.swift) take their `Storage<Element>.Heap` `destination` as `borrowing` (a `~Copyable` value passed non-consuming). They call `destination.pointer(at:)` (non-mutating `@unsafe`).
- Heap's own tests + the Inline tests that bind a *mutated* `Storage.Heap` migrate `let storage`/`heap`/`source`/`destination`/`original`/`copied` → `var` (mutating `Property.Inout` accessors + the `nonmutating set` on `initialization` require a mutable binding now that Heap is a value). `slotCapacity` → `capacity` at the two test sites. Bare `#expect(storage.isEmpty)` / `#expect(!storage.isEmpty)` / `#expect(heap.initialization.isEmpty)` → the `== true` / `== false` form: Swift Testing's `#expect` lowers a bare property-access expression through `__checkPropertyAccess`, which requires `Copyable`; the `== bool` form lowers through `__checkBinaryOperation` instead and is the form the suite already uses elsewhere. Test intent unchanged.

## Verification summary

- `Storage.Heap` is a `~Copyable` struct façade; no public `var capacity: Int`; public `capacity: Index<Element>.Count`; conforms to `Storage.\`Protocol\`` (disk).
- `swift build` + `swift test` green in swift-storage-primitives (135 tests).
- Heap SIL receipt: 0 `witness_method` / 0 `class_method` on `capacity`/`pointer(at:)` for a concrete `Storage<Int>.Heap`, release + cross-module — `Experiments/storage-protocol-heap-sil-gate/Outputs/sil-grep.txt`.
- Single allocation preserved (one `Storage.Heap.Buffer` `ManagedBuffer`-subclass alloc per Heap; façade is a value).
- Zero diffs outside swift-storage-primitives (no `swift-buffer-*`, no swift-storage-split-primitives, no other storage-family package touched).

## Cross-references

- [EXP-017] release + cross-module validation; [EXP-020] synthetic-to-production gap — closed for `Storage.Heap` by this wave.
- [EXP-002c] experiment placement by highest-layer dep (storage-primitives owns Heap).
- [API-NAME-002] compound-name retirement (`slotCapacity` → `capacity`); [API-NAME-001] Nest.Name (`Storage.Heap.Buffer`).
- [API-IMPL-008] / [MEM-COPY-006] conformance + storage-type co-location for `~Copyable`-aware types; the sibling-extension placement of `Buffer` propagates the `Element: ~Copyable` suppression.
- [PRP-008] `Property.Inout` is the canonical `~Copyable`-container accessor pattern (mirrors `Storage.Inline`).
- `DS-022` — `ManagedBuffer` is vestigial-but-correct as the interim heap-storage backing; the façade keeps the single `ManagedBuffer` allocation while presenting a value-typed, protocol-conforming surface.

---

# Wave 4 Findings — Storage.Heap conditionally Copyable with internal CoW (the Array model)

**Date**: 2026-05-25 · **Branch**: `spike/storage-protocol` · **Toolchain**: Apple Swift 6.3.2 · **Scope**: swift-storage-primitives only.

## Objective

Make `Storage.Heap` **conditionally Copyable** — `Copyable where Element: Copyable` (value semantics via internal copy-on-write), `~Copyable` for `~Copyable` elements — the stdlib `Array` / `Array_Primitives.Array` model. Wave 3 left Heap *unconditionally* `~Copyable`, which is poison to Copyable value-type containers: a `~Copyable` stored property forces its holder to be `~Copyable`, so a Copyable CoW container that holds `Heap` by value cannot stay Copyable. Making Heap own its CoW internally (like `Array`) removes the poison and lets consumers (Buffer.Linear's Copyable variant, Slab in wave 5) keep value semantics and drop their own `isKnownUniquelyReferenced`.

## Feasibility gate (#1) — PASS

`extension Storage.Heap: Copyable where Element: Copyable {}` on the `~Copyable`-declared generic struct (`public struct Heap: ~Copyable`) is **fully expressible**. The Heap target builds clean with only the conformance added; no constraint/diagnostic blocks conditional `Copyable` here. This is the exact shape `Array_Primitives.Array` uses in production (`Array.swift`: `public struct Array<Element: ~Copyable>: ~Copyable` + `extension Array: Copyable where Element: Copyable {}`), so the gate was expected to pass and did. The conformance is co-located with the struct declaration in `Storage.Heap.swift` per [COPY-FIX-004]. The Array-model approach holds; no fallback (Copyable-class Heap) needed.

## The CoW mechanism — accessor choke point, gated on `Element: Copyable`

The structural constraint that shaped the design: **a `~Copyable`-generic mutator cannot call a `Copyable`-only `ensureUnique()`** — `error: referencing instance method 'ensureUnique()' ... requires that 'Element' conform to 'Copyable'` (verified in a `/tmp` probe). So CoW cannot be driven from the existing `Property.Inout where Base: ~Copyable` mutators by simply calling `ensureUnique()`; the call would not see the Copyable overload. This is the same split `Buffer.Linear` uses: its CoW-safe `append`/`remove`/`replace` and `ensureUnique()` are all `where Element: Copyable`; the `~Copyable` ops mutate directly.

The implementation, mirroring that precedent:

1. **`ensureUnique()` (the real CoW)** — `extension Storage.Heap where Element: Copyable` (Storage.Heap Copyable.swift). When `!isKnownUniquelyReferenced(&_buffer)`, it allocates a fresh `Buffer` at the same capacity, copies the initialized elements **at their original slot positions** (preserving the exact `Storage.Initialization` layout, including disjoint `.two` ring spans — a wrapped ring stays a wrapped ring after CoW, rather than linearizing), sets the fresh buffer's `initialization`, and swaps `self`. The wave-3 `~Copyable` no-op `ensureUnique()` (returns `false`) is retained: at a concrete `Copyable`-element call site Swift prefers the more-constrained Copyable method (CoW); a `~Copyable`-element Heap prefers the no-op, which is correct — such a Heap is uniquely owned and never value-copied, so uniqueness needs no restoration (and copying is impossible). The element copy is thereby **gated on `Element: Copyable`**.

2. **Copyable-constrained CoW choke-point overloads of the three mutating accessors** — `initialize`, `move`, `deinitialize` each gain an `extension Storage.Heap where Element: Copyable` overload whose `mutating _read` / `mutating _modify` calls `ensureUnique()` **before** yielding the `Property.Inout`. A concrete `Storage<Int>.Heap` call site selects these (more-constrained) overloads; a `~Copyable`-element Heap selects the existing direct accessors (no CoW). Verified that property-accessor overloading on the `Copyable` vs `~Copyable` constraint is accepted by Swift (no redeclaration error) and that the concrete-Copyable site picks the Copyable overload (a `/tmp` probe reproducing the exact accessor-yields-Property.Inout shape showed value semantics: mutate-copy left original unchanged).

### Which mutators got `ensureUnique()`

Every `mutating` Heap operation flows through one of the three mutating accessors (`initialize`, `move`, `deinitialize`), so CoW at those three choke points covers the entire `mutating` element/header-write surface — including all `Property.Inout` `callAsFunction` forms (`initialize(to:at:)`, `move(at:)`, `move(range:to:[at:])`, `deinitialize(at:)`, `deinitialize(range:)`) and the tracked methods (`initialize.next(to:)`, `move.last()`, `deinitialize.all()`), because each is reached *through* the corresponding accessor's `_modify`. The `copy` accessor (`Element: Copyable`) is NOT a CoW site: `copy()` / `copy(to:)` read self and write a *new or borrowed destination* — they never mutate self's shared buffer.

Out of CoW scope (consistent with the brief's `mutating`-scoped requirement and the Buffer.Linear precedent): the `nonmutating set` on `initialization` and the non-`mutating` span/raw-pointer escape hatches (`withMutableSpan`, `withUnsafeMutableBufferPointer`) — these mutate through the class buffer and are not declared `mutating`, exactly like Buffer.Linear's raw static helpers and span access, which also do not self-CoW. They remain advanced/escape-hatch surfaces.

## CoW value-semantics (the load-bearing test) — PASS

New suite `StorageHeapCoWTests` (Tests/Storage Heap Primitives Tests/Storage.Heap CoW Tests.swift), 5 tests, all pass:

- **`value copy then mutate copy leaves original unchanged`** — the canonical check: `var a` with slot 0 = 42; `let`→`var b = a` (shares buffer); `b.move.last()` (mutation) triggers CoW on `b`; the ORIGINAL `a`'s slot 0 still reads 42 and count is still 1; `b` is empty.
- **`appending to a copy does not grow the original`** — append-path mutation on the copy; original stays at 1 element.
- **`plain copy is deferred; copy happens on mutation`** — `a.isUnique == true` before copy; after `let b = a` both `a.isUnique` and `b.isUnique` are `false` (buffer SHARED — **copy deferred, not eager**); after a mutation on `b`, both are `true` again (b moved to a fresh unique buffer). Directly evidences the "no copy on the plain `let b = a`" requirement.
- **`ensureUnique reports whether a copy was made`** — `false` when already unique, `true` exactly once on first shared-mutation.
- **`CoW preserves independent element lifecycle`** — class-element Heap: CoW retains the shared reference (does not clone the object); draining the copy then the original releases each retained reference with no double-free (`deinitCount == 2` for two distinct objects).

## Single allocation — preserved; CoW allocates a second buffer ONLY on shared mutation

The conditional `Copyable` conformance adds only a **shallow memberwise copy of the class reference** `_buffer` (retain), no allocation. The hot, uniquely-owned path is unchanged from wave 3: one `Storage.Heap.Buffer` (`ManagedBuffer` subclass) allocation per Heap. A second `Buffer` allocation happens **only** inside `ensureUnique()`'s copy branch, reached only when the buffer is shared AND about to be mutated. The SIL gate (single-owner call site) confirms no extra allocation on the non-CoW path.

## SIL gate (#3) — PASS (re-run)

Re-ran `Experiments/storage-protocol-heap-sil-gate/` against the changed package (release + cross-module, `swiftc -emit-sil -O`, importing the rebuilt release modules). Result unchanged from wave 3: **0 `witness_method` AND 0 `class_method`** in the whole optimized executable. The concrete `callHeap` body keeps the single `alloc_ref [tail_elems $Int * N] $Storage<Int>.Heap.Buffer`; `pointer(at:)` inlines to `ref_tail_addr`; `capacity` inlines to the `_swift_stdlib_malloc_size` computation. The conditional-Copyable + internal-CoW change did **not** regress zero-witness specialization. Receipt: `Outputs/sil-grep.txt` (wave-4 verdict section); `run.txt` = `heap probe = 51` (unchanged).

## Verification summary

- `extension Storage.Heap: Copyable where Element: Copyable` present; Heap value-semantic for Copyable Element, `~Copyable` otherwise (disk: Storage.Heap.swift).
- CoW value-semantics test passes (copy → mutate-copy → original unchanged; copy deferred to mutation) — `StorageHeapCoWTests`, 5/5.
- Heap SIL gate PASS — 0 `witness_method` / 0 `class_method`, release + cross-module.
- Single allocation preserved on the non-CoW path; CoW allocates a second `Buffer` ONLY on shared-mutation.
- `swift build` + `swift test` green — 140 tests (135 existing + 5 new CoW).
- Zero diffs outside swift-storage-primitives (no `swift-buffer-*`, no swift-storage-slab-primitives, no other storage-family package touched). Consumer migrations (Buffer.Linear dropping its own `isKnownUniquelyReferenced`, Slab) are the next waves.

## Cross-references

- [COPY-FIX-007] CoW in mutating ops when `Element: Copyable`; `~Copyable` tier mutates directly — the rule this wave implements for Heap. (The "update cached pointers after CoW copy" caveat does not apply: Heap holds no cached pointer; slot access goes through `_buffer.withUnsafeMutablePointerToElements` each time.)
- `Array_Primitives.Array` (`swift-array-primitives`, `Array.swift` / `Array.Dynamic *.swift`) — the canonical institute precedent: `public struct Array<Element: ~Copyable>: ~Copyable` + `extension Array: Copyable where Element: Copyable {}`, delegating CoW to `Buffer.Linear`. Heap plays for itself the CoW-owning role that `Buffer.Linear` plays for `Array`.
- `Buffer.Linear` (`swift-buffer-linear-primitives`, `Buffer.Linear Copyable.swift`) — the split-by-Copyable CoW entry-point precedent that resolves the "can't call Copyable `ensureUnique` from a `~Copyable` mutator" constraint.
- [IMPL-064] / [DS-002] conditional-Copyable variant pattern; [MEM-COPY-006] / [COPY-FIX-004] conditional-conformance co-location.
- [EXP-017] release + cross-module SIL validation; [IMPL-077] verify the constraint by minimal experiment (the two `/tmp` overload-resolution probes).
