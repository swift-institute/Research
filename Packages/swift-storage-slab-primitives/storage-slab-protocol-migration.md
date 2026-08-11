# Storage.Slab — Value-Type-Heap Migration + Storage.Protocol Conformance

<!--
---
version: 2.0.0
last_updated: 2026-05-25
status: DECISION
---
-->

> Wave 5 of the `Storage.Protocol` unification pilot. Migrates `Storage.Slab`
> onto the now-conditionally-`Copyable` value-type `Storage.Heap` (landed on
> `spike/storage-protocol` in swift-storage-primitives, waves 1–4) and conforms
> it to `Storage.`Protocol``. This is a Heap-ownership migration + conformance,
> NOT a discipline redesign.

## Context

After waves 1–4, `Storage<Element>.Heap` is a value-type façade:
`public struct Heap: ~Copyable` over a private `@usableFromInline final class
Buffer: ManagedBuffer<…>`, **conditionally `Copyable where Element: Copyable`**
with internal copy-on-write (the stdlib `Array` model). It conforms to
`Storage.`Protocol`` via a natural `capacity: Index<Element>.Count` plus
`@unsafe pointer(at:)`. The slot-capacity accessor was renamed `slotCapacity` →
`capacity`; the old name was retired.

`Storage.Slab` (`final class Slab`) is a bitmap-tracked discipline over a
contiguous `Storage<Element>.Heap`. Wave 2 surfaced that it did not build
against the new Heap. The blocker was **purely the Heap-ownership change** — the
slab discipline (bitmap occupancy tracking, allocation model) was and remains
correct.

## Outcome

**Status**: DECISION — migrated, conformed, build green.

### What changed (all in swift-storage-slab-primitives)

| # | Site | Before | After |
|---|------|--------|-------|
| 1 | `Storage.Slab ~Copyable.swift:29,30` (factory) | `heap.slotCapacity` | `heap.capacity` |
| 2 | `Storage.Slab ~Copyable.swift` (property) | `var slotCapacity` → `_heap.slotCapacity` | `var capacity` → `_heap.capacity` (renamed to witness `Storage.`Protocol``) |
| 3 | `Storage.Slab.swift:56` (init) | `init(_heap: Storage<Element>.Heap, …)` | `init(_heap: consuming Storage<Element>.Heap, …)` |
| 4 | `Storage.Slab ~Copyable.swift` (accessor) | `var heap: …Heap { _heap }` (by-copy getter) | `var heap: …Heap { _read { yield _heap } }` (borrowing) |
| 5 | new `Storage.Slab+Storage.Protocol.swift` | — | `extension Storage.Slab: Storage.`Protocol` where Element: ~Copyable {}` |
| 6 | `Package.swift` | — | added `Storage Protocol Primitives` product dep |

`deinit` (iterates `_bitmap.ones`, borrows `_heap.pointer(at:)` per set bit,
deinitializes each) was re-verified and compiles **unchanged** — `pointer(at:)`
is a non-mutating method on the value-type façade, so borrowing `_heap` from
within `deinit` is fine; the cleanup logic is untouched.

### The `heap`-accessor decision + canonical-pattern citation

A by-copy getter (`{ _heap }`) is illegal once `Storage.Heap` is `~Copyable`
for a `~Copyable` `Element` — returning it would copy a non-copyable value. The
fix is a **borrowing accessor**, `_read { yield _heap }`, which yields a borrow
of the stored field rather than a copy.

This mirrors the canonical ecosystem pattern for exposing a `~Copyable` (or
otherwise borrow-only) stored field. Precedents verified, not invented:

- `swift-binary-primitives` `Binary.Mask.underlying`:
  `public var underlying: Int { _read { yield _storage } }` — a non-mutating
  computed property yielding a stored field by borrow (the Carrier witness).
- `swift-buffer-linear-primitives` `Buffer.Linear.Bounded.peek`:
  `public var peek: Peek.View { _read { yield Peek.View(self) } }` — same
  `_read`/`yield` shape on a `~Copyable`-element buffer.

The `_read { yield … }` form is the established idiom (40+ sites across
array / buffer / bit-vector primitives) for borrow-exposing a field; this
migration adopts it directly.

### Conformance verification (non-vacuous)

`Storage.Slab` is a `final class`; conforming a class to the `~Copyable`
`Storage.`Protocol`` (`__StorageProtocol: ~Copyable`, `associatedtype
Element: ~Copyable`) is structurally distinct from `Storage.Heap`'s struct
conformance, so a spot-check was warranted. A standalone path-dependency probe
confirmed:

- a generic `func slotCount<S: Storage.`Protocol` & AnyObject>(_ s: borrowing S)
  -> Index<S.Element>.Count { s.capacity }` accepts `Storage<Int>.Slab` and the
  `capacity` witness resolves;
- a generic `func firstPointer<S: …>(_ s: borrowing S) ->
  UnsafeMutablePointer<S.Element> { unsafe s.pointer(at: .zero) }` reaches the
  `@unsafe pointer(at:)` witness through the protocol.

Both compile and run — the conformance is real, not silently no-op'd. SIL was
not required (the specialization mechanism is proven waves 1/3/4); build + the
generic-binding probe is the bar.

On the ADDRESSING axis the slab IS single-region, slot-addressed storage (one
`capacity`, one linear `pointer(at:)`); the bitmap tracks occupancy on top but
does not change the addressing contract — so it fits the single-region
`Storage.`Protocol`` contract (the same one `Storage.Split`, being
multi-region, deliberately does not conform to).

### Tests

The package has **no test target** (no `Tests/` directory, no `testTarget` in
`Package.swift`). There were therefore no "Slab's own tests" to migrate
(brief step 6 was vacuous here). `swift build` is green; `swift test` reports
"no tests found" (the SwiftPM no-test-target message), not a failure. A test
target was **not** added — that is outside this Heap-ownership-migration arc.

## Surfaced (under ask:) — downstream `Buffer.Slab` wave, NOT forced

The `heap`-accessor change from by-copy to borrowing is the seam where the
**downstream `Buffer.Slab` consumer** (`swift-buffer-slab-primitives`) is
affected. That package — which is OUT of scope for this wave and is NOT a
dependency of swift-storage-slab-primitives (the dependency arrow points the
other way: Buffer.Slab consumes Storage.Slab) — passes `storage.heap` by value
into static operations, e.g.:

```
// swift-buffer-slab-primitives/.../Buffer.Slab+Operations.swift:55
Buffer<Element>.Slab.insert(consume element, at: slot, header: &header, storage: storage.heap)
// …also storage.heap.deinitialize(at:), storage.heap.move(at:), and
//   storage.slotCapacity (which this wave renamed to `capacity`).
```

With a borrowing `heap` accessor and a conditionally-`Copyable` Heap, those
call sites will need review when `Buffer.Slab` is migrated onto the value-type
Heap: whether `Buffer<Element>.Slab.insert(…, storage:)` accepts a borrowed
Heap, and the `storage.slotCapacity` → `storage.capacity` rename, are the
downstream wave's questions.

**This wave does NOT touch swift-buffer-slab-primitives** and does not force any
`Storage.Slab` API redesign to accommodate it. `Storage.Slab`'s own package
builds green without any cross-package change because Buffer.Slab is a consumer,
not a dependency. The entanglement is surfaced here as the next wave's scope, per
the brief's ask: rules.

### No Heap rough edge surfaced

Slab is the first real consumer of the conditionally-`Copyable` Heap exercised
here. The migration required no Heap API beyond what waves 1–4 shipped
(`capacity`, `@unsafe pointer(at:)`, `consuming`-friendly value semantics). No
CoW/ownership rough edge in `Storage.Heap` surfaced; nothing in
swift-storage-primitives was touched.

## References

- `swift-storage-primitives` `spike/storage-protocol`:
  `Storage.Heap ~Copyable.swift` (`capacity`, `isUnique`, `ensureUnique`),
  `Storage.Heap+Storage.Protocol.swift` (Heap conformance precedent),
  `Storage.Protocol.swift` (`__StorageProtocol` hoisted protocol).
- Canonical `_read`/`yield` borrow-accessor precedents:
  `Binary.Mask.underlying`, `Buffer.Linear.Bounded.peek`.

---

# Wave 6 — `Storage.Slab` as a Conditionally-Copyable Value-Type Façade

<!-- wave-6 section appended 2026-05-25; doc bumped 1.0.0 → 2.0.0 -->

> Wave 6 of the `Storage.Protocol` unification pilot. Wave 5 (above) kept
> `Storage.Slab` a `public final class Slab`. Wave 6 applies the **Heap treatment
> one level up**: `Storage.Slab` becomes a conditionally-`Copyable` **value-type
> struct façade** over a PRIVATE backing class, with internal bitmap-driven
> copy-on-write. Principal + user decision.

## Why the class was load-bearing (the constraint wave 6 had to preserve)

`Buffer.Slab` (in `swift-buffer-slab-primitives`) is **conditionally `Copyable`**
(`extension Buffer.Slab: Copyable where Element: Copyable {}`), holds
`Storage<Element>.Slab` **by value**, and has **no `deinit` and no
`isKnownUniquelyReferenced` of its own**. It relied on `Storage.Slab` being a
refcounted class so the bitmap-driven slot-cleanup deinit runs **exactly once**
across `Copyable` copies. Any restructure had to keep that single-shot deinit
guarantee intact — which means the deinit had to stay on a **refcounted class**.

## The façade structure

```
Storage<Element>.Slab            public struct Slab: ~Copyable        ← value façade
  └─ _backing: Backing           @usableFromInline var (internal)     ← the one ref
       Storage<Element>.Slab.Backing   @usableFromInline final class  ← the one allocation
         ├─ _heap:   Storage<Element>.Heap
         ├─ _bitmap: Bit.Vector.Bounded
         └─ deinit { for bit in _bitmap.ones { _heap.pointer(at: bit.retag(Element)).deinitialize(count: .one) } }

extension Storage.Slab: Copyable where Element: Copyable {}            ← co-located [COPY-FIX-004]
```

This is the exact `Storage.Heap` shape one level up: a `~Copyable` struct over a
private `@usableFromInline final class`, conditionally `Copyable`, with the
slot-cleanup `deinit` on the class. A value-copy of the struct shares `_backing`
shallowly (retaining the same class); the single shared `Backing` is released
exactly once at the last `Copyable`-copy's death → its deinit fires **once** →
each occupied slot is deinitialized **once**. The `Buffer.Slab` composition's
no-deinit/no-uniqueness-check posture continues to work unchanged because the
single-shot guarantee it depends on is preserved.

**Feasibility gate (step 1): PASS.** Conditional `Copyable` on the `~Copyable`
struct façade is expressible here exactly as it is for `Storage.Heap` — no
structural obstruction; `swift build` green on first structural pass (after a
visibility cleanup — see below).

### Visibility cleanup at the gate

The backing-class type is `@usableFromInline internal`, so the struct's
`_backing` field and its wrapping `init(_backing:)` are also `@usableFromInline
internal` (a `package`/`public` member cannot expose an internal type). This
mirrors `Storage.Heap._buffer` exactly. The **package** parts-init
`init(_heap:bitmap:)` is preserved as a separate `package`-visible entry point on
the struct that wraps the parts into a fresh `Backing` (its `@inlinable package`
body may reference the internal `Backing`). No current downstream consumer calls
the parts-init — buffer-slab uses only the `minimumCapacity:` factory — but the
surface is retained per the brief.

## The bitmap-driven CoW mechanism

`Storage.Slab` keeps the backing Heap's `initialization` at `.empty` — the
**bitmap is the occupancy source of truth**. So the CoW deep-copy is
**bitmap-driven**, NOT `Heap.initialization`-driven, and **cannot delegate to
`Heap.copy()` / `Heap.ensureUnique()`** (those copy `initialization`-tracked
ranges, which are empty here). The `Element: Copyable` `ensureUnique()`:

```swift
guard !isKnownUniquelyReferenced(&_backing) else { return false }
let oldBacking = _backing
let fresh = Storage<Element>.Heap.create(minimumCapacity: oldBacking._heap.capacity)
for bit in oldBacking._bitmap.ones {                          // ← BITMAP-driven
    let slot = bit.retag(Element.self)
    unsafe fresh.pointer(at: slot).initialize(to: oldBacking._heap.pointer(at: slot).pointee)
}
_backing = Backing(_heap: fresh, bitmap: oldBacking._bitmap)  // copy bitmap by value
return true
```

Each occupied element is copied **at its original slot position** — a sparse slab
stays sparse after CoW.

## Which op got `ensureUnique()`

The only genuinely-mutating public op is the **`bitmap` setter** (`set { _bitmap
= newValue }`). It gates on `ensureUnique()` before writing. `pointer(at:)` stays
**non-mutating** — it witnesses `Storage.`Protocol``'s `@unsafe func
pointer(at:)` and is the documented CoW-bypass escape hatch, exactly like
`Storage.Heap.pointer(at:)`. `capacity` and `heap` stay non-mutating reads.

### The overload-selection trap (the one real defect found + fixed)

First implementation put a single `bitmap` setter calling `ensureUnique()` inside
`extension Storage.Slab where Element: ~Copyable`. **CoW silently did not fire**
(value-semantics test: a value-copy's bitmap mutation perturbed the original).
Root cause: inside a generic `~Copyable` extension, `Element` is only known to be
`~Copyable`, so the unqualified `ensureUnique()` call **always resolves to the
`~Copyable` no-op overload** even when the concrete `Element` is `Copyable` —
the more-specialized `Element: Copyable` overload is only selected at concrete
call sites, never from within a generic `~Copyable` extension.

**Fix (matches the `Storage.Heap` precedent exactly):** split the `bitmap`
property into two overloads — a `~Copyable` form (direct write, no CoW; correct
because `~Copyable` Slabs are uniquely owned) in `Storage.Slab ~Copyable.swift`,
and a `Copyable` form (CoW setter) in `Storage.Slab Copyable.swift`. Swift selects
the CoW-bearing overload at concrete `Copyable` call sites. This is the same
posture as `Storage.Heap`'s `initialize` accessor, whose CoW-bearing overload
likewise lives in the `Copyable` file for the same reason. (Diagnosed with a
throwaway in-package probe per `feedback_inpkg_iter_over_tmp_probes.md`, then
removed.)

## Tests (NEW — package had ZERO tests)

Added a `testTarget` (`Storage Slab Primitives Tests`) to `Package.swift` with a
`Storage Primitives Test Support` product dep (gives `Index<T>.Count` /
`Bit.Index` integer literals via the Identity-TS re-export chain), and
`Tests/Storage Slab Primitives Tests/Storage.Slab CoW Tests.swift`. The toolchain
`Testing` is used directly (no nested `Tests/Package.swift`), mirroring how
swift-storage-primitives wires its Heap CoW tests (plain `.testTarget`). Per
[SWIFT-TEST-003] the suite uses the **parallel-namespace pattern** (a top-level
non-generic `StorageSlabCoWTests` struct) because `Storage.Slab` is generic and
`extension Storage.Slab { @Suite struct Test }` would fail `@section cannot be
used in a generic context`. Five tests, all PASS:

| Test | Asserts |
|------|---------|
| `value-copied slab deinitializes each occupied slot exactly once` | **DOUBLE-FREE SAFETY** — occupy 2 slots with a tracked `Element`, value-copy, drop both, assert each element deinits **exactly once** (not twice). The load-bearing test; would over-release if the backing weren't refcounted. |
| `mutating a value-copy's bitmap leaves the original unchanged` | **CoW value-semantics** — copy, confirm `isUnique == false` (deferred), mutate the copy's bitmap, assert original's bitmap + element values UNCHANGED and the copy reflects the change. |
| `CoW gives the copy an independent backing` | post-CoW both backings hold the retained shared reference; dropping both deinits the object exactly once. |
| `capacity and pointer round-trip survive the façade restructure` | `capacity`, `pointer(at:)` occupy/read round-trip, `heap.capacity == slab.capacity`. |
| `slab over a ~Copyable element is ~Copyable` | compile-checked: `Storage<NonCopyable>.Slab` is `~Copyable` (no value-copy taken). |

**Two test-authoring notes** (both fixed; neither an implementation defect):
1. **Capacity rounds up.** `Storage.Heap.create(minimumCapacity: n)` returns
   `capacity ≥ n` (the allocator's slot count, e.g. 8 → 9). Assertions use `≥`,
   not `==`.
2. **Shared-static deinit-counter race.** Two deinit-counting tests initially
   shared one file-private `Tracker` with a `static deinitCount`; default-parallel
   execution raced the reset-then-assert. Fixed by giving each counting test its
   own **function-local** tracker class (distinct type ⇒ distinct static ⇒ no
   cross-test race) — the exact shape the Heap CoW test's local `Tracker` uses.

## Preserved public surface

All of: `init(minimumCapacity:)` (was `convenience` on the class; now a normal
struct init), `package init(_heap: consuming …, bitmap:)` (wraps into a
`Backing`), `capacity`, `heap` (`_read { yield _backing._heap }`), `bitmap { get
set }`, `@unsafe pointer(at:)`, the `Storage.`Protocol`` conformance
(`Storage.Slab+Storage.Protocol.swift` unchanged — witnesses `capacity` +
`pointer(at:)`, both preserved), and the `@unsafe @unchecked Sendable where
Element: Sendable` conformance. No public class remains.

## Surfaced (under ask:) — `Buffer.Slab` CoW-ordering follow-up, NOT solved here

**Flag for the next wave.** `Buffer.Slab` (downstream, out of scope) mutates
elements via the raw `pointer(at:)` escape hatch, which by design **bypasses
copy-on-write** (it is the documented non-mutating CoW-bypass, mirroring
`Storage.Heap.pointer(at:)`). With `Storage.Slab` now conditionally `Copyable`,
a `Buffer.Slab` value-copy shares the backing, and a subsequent element mutation
through `pointer(at:)` on one copy would perturb the other — the CoW only fires
on the `bitmap` setter, not on element writes through the bypass. Resolving the
`Buffer.Slab` CoW ordering (e.g. routing its element-mutating ops through an
`ensureUnique()` choke point, or adopting `Storage.Slab.isUnique` at the buffer
layer) is a **separate downstream wave** in `swift-buffer-slab-primitives`. This
wave does **not** touch that package and does **not** solve the ordering here;
`Storage.Slab`'s own package builds + tests green because Buffer.Slab is a
consumer, not a dependency.

## References (wave 6 additions)

- `Storage.Heap.swift` + `Storage.Heap ~Copyable.swift` + `Storage.Heap
  Copyable.swift` + `Storage.Heap+Initialize.swift` (the exact façade + two-overload
  CoW template wave 6 mirrors).
- `swift-storage-primitives` `Tests/Storage Heap Primitives Tests/Storage.Heap CoW
  Tests.swift` (test model: function-local tracker for deinit counting).
- [COPY-FIX-004] (conditional conformance co-located with the type),
  [SWIFT-TEST-003] (parallel-namespace pattern for generic types),
  [TEST-005] / [SWIFT-TEST-004] (observation-sensitive test isolation).
