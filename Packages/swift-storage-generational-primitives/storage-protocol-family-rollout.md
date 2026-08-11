# Storage.Protocol Family Rollout — Wave 2 Findings

**Status**: RECOMMENDATION
**Date**: 2026-05-25
**Toolchain**: Swift 6.3.1 (default), macOS arm64
**Scope**: Wave 2 of the `Storage.Protocol` unification pilot — rolling the
already-proven conformance pattern to the remaining single-region storage
disciplines.
**Branches**: `spike/storage-protocol` in each in-scope package; committed per
phase per package; NOT pushed.

---

## Summary

`Storage.\`Protocol\`` (hoisted `__StorageProtocol`, aliased
`Storage.\`Protocol\``, declared in `swift-storage-primitives` /
`Storage Protocol Primitives`) requires two members on single-region,
slot-addressed storage:

```swift
var capacity: Index<Element>.Count { get }                                  // natural name
@unsafe func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element>
```

Waves 1/3 landed + SIL-verified three conformers: `Storage.Inline` (struct,
value-generic `<let capacity>` → `<let count>` rename), `Storage.Pool` (final
class, direct), `Storage.Heap` (value-type `~Copyable` façade over a private
`ManagedBuffer` subclass). Wave 2 applies those proven patterns to the rest of
the single-region family.

| Leaf | Package | Shape | Pattern | Outcome |
|------|---------|-------|---------|---------|
| `Storage.Arena` | swift-storage-generational-primitives | `final class` | class-direct (like Pool) | **CONFORMED** |
| `Storage.Pool.Inline` | swift-storage-pool-inline-primitives | `struct <let count>: ~Copyable` | value-generic rename (like Inline) | **CONFORMED** |
| `Storage.Arena.Inline` | swift-storage-arena-inline-primitives | `struct <let count>: ~Copyable` | value-generic rename (like Inline) | **CONFORMED** |
| `Storage.Slab` | swift-storage-slab-primitives | `final class` | class-direct (intended) | **SURFACED (ask:)** — baseline broken against landed `~Copyable` Heap; conforming needs out-of-scope redesign |

`Storage.Split` (swift-storage-split-primitives) is multi-region and explicitly
non-conforming per `Storage.Protocol.swift:67-69`; out of scope, untouched.

---

## Per-leaf inventory

### Storage.Arena — CONFORMED (class-direct)

Branch HEAD: `4e59858`. `swift build` + `swift test` green (11/11 tests).

| Requirement | Status before | Action |
|-------------|---------------|--------|
| `pointer(at: Index<Element>) -> UnsafeMutablePointer<Element>` (unbounded, public, `@unsafe`) | **Already present** — `Storage.Arena.swift:149` | none |
| `capacity: Index<Element>.Count` | Had public `slotCapacity` accessor (`Storage.Arena ~Copyable.swift:74`) | **Renamed** `slotCapacity` → `capacity` |
| conformance | — | **Added** `Storage.Arena+Storage.Protocol.swift` (empty body) |
| `Storage Protocol Primitives` dep | absent | **Added** to target (package already depended on `swift-storage-primitives`) |

Generic renames: none (class, no value-generic). The `package`-level
`_slotCapacity` stored property and the `package init(slotCapacity:)` label are
internal, not public — left as-is (rule 4 forbids only public `slotCapacity`).
Tests + doc comments updated to the `capacity` name (`[API-NAME-006]`).

### Storage.Pool.Inline — CONFORMED (value-generic rename)

Branch HEAD: `7189103`. `swift build` + `swift test` green (12/12 tests).
Baseline built clean before edits (depends on `Storage Pool Primitives`, the
landed final-class Pool — not the restructured Heap).

| Requirement | Status before | Action |
|-------------|---------------|--------|
| value-generic `<let capacity: Int>` | occupied the name `capacity` | **Renamed** → `<let count: Int>` at every site |
| `capacity: Index<Element>.Count` | Had public `slotCapacity` accessor | **Renamed** `slotCapacity` → `capacity` |
| `pointer(at: Index<Element>) -> UnsafeMutablePointer<Element>` (unbounded) | present but `package` (deinit-iteration helper) | **Promoted** to `public` (witness) |
| conformance | — | **Added** `Storage.Pool.Inline+Storage.Protocol.swift` |
| `Storage Protocol Primitives` dep | absent | **Added** |

Generic-rename sites (`capacity` → `count`): struct decl;
`@_rawLayout(likeArrayOf: Element, count:)`; `precondition`; the two bounded
`pointer(at: ...Bounded<count>)` overloads; `allocate()` return type +
`deallocate(at:)` param type; the positional `<let count: Int>` generic on the
`Property.Inout.all` extension method + its `Storage<Element>.Pool.Inline<count>`
constraint. Preserved (correctly NOT renamed): the `Storage.Pool.Error.exhausted(capacity:)`
error-case label (error-domain API surface).

### Storage.Arena.Inline — CONFORMED (value-generic rename)

Branch HEAD: `f3e9e66`. `swift build` + `swift test` green (11/11 tests).
Baseline built clean before edits (composes the `Storage.Arena` namespace +
inline `@_rawLayout` storage; does not touch the parent class internals or the
restructured Heap).

Structurally identical to Pool.Inline. Same rename sites (struct decl,
`@_rawLayout`, `precondition`, both bounded `pointer` overloads, `allocate()` +
`unallocate(_:)` signatures, the `Property.Inout.all` extension positional
generic + constraint), same `slotCapacity` → `capacity` accessor rename, same
`package` → `public` promotion of the unbounded `pointer(at:)` witness, same
conformance file + dep addition.

---

## ask: surface — Storage.Slab does NOT fit cleanly (misfit, not forced)

**Branch**: `spike/storage-protocol` at HEAD `4db87d6` (== `main`; no commits —
no source edits made). Surfaced per ground-rule 6.

**The mismatch is NOT the one anticipated.** The brief flagged Slab as the
likely misfit on the theory that "slab/free-list allocators often lack a single
`capacity` or a linear `pointer(at: Index<Element>)`." That theory does **not**
hold for this Slab: `Storage.Slab` is a bitmap-tracked discipline over a
contiguous `Storage<Element>.Heap`. It DOES have a single `capacity`
(`_heap`'s slot capacity) and a linear unbounded `pointer(at: Index<Element>)`
witness (`Storage.Slab ~Copyable.swift:62`, delegating to `_heap.pointer(at:)`).
On the addressing axis it fits the single-region contract as cleanly as Arena.

**The actual blocker is a pre-existing baseline breakage from the landed wave-3
Heap refactor.** `Storage.Slab` (`main`) was written against the *old*
reference-type `Storage.Heap` (a `final class`, Copyable). Wave 3 restructured
`Storage.Heap` into a value-type **`~Copyable`** façade
(`Storage.Heap.swift:62`: `public struct Heap: ~Copyable`). `Storage.Slab`
(`final class`) stores and exposes that Heap **by value, assuming Copyable**, so
its `main` source no longer compiles against the on-disk
`swift-storage-primitives` `spike/storage-protocol` branch — *before any
conformance change*:

```
Storage.Slab ~Copyable.swift:29  error: value of type 'Storage<Element>.Heap' has no member 'slotCapacity'
Storage.Slab ~Copyable.swift:30  error: value of type 'Storage<Element>.Heap' has no member 'slotCapacity'
Storage.Slab.swift:56            error: parameter of noncopyable type 'Storage<Element>.Heap' must specify ownership
Storage.Slab ~Copyable.swift:32  error: extra arguments / missing argument 'minimumCapacity' (cascade from :56)
Storage.Slab ~Copyable.swift:41  error: value of type 'Storage<Element>.Heap' has no member 'slotCapacity'
```

Two distinct problems are tangled here:

1. **Mechanical (in scope, but blocked behind #2)**: `_heap.slotCapacity` →
   `_heap.capacity` (Heap's own accessor was renamed in wave 1/3) at
   `~Copyable.swift:29,30,41`.
2. **Structural redesign (OUT of scope, rule 4: "no API redesign")**: adapting
   Slab to a `~Copyable` Heap:
   - `package var _heap: Storage<Element>.Heap` — a `var` field of a now-`~Copyable`
     type, owned by a `final class`.
   - `package init(_heap: Storage<Element>.Heap, ...)` (`Storage.Slab.swift:56`)
     needs `consuming`/`borrowing` ownership.
   - `public var heap: Storage<Element>.Heap { _heap }` (`~Copyable.swift:48`)
     is **illegal** — a getter cannot return a `~Copyable` value by copy. Its
     documented purpose ("exposed for buffer-layer consumers that need to pass
     `Storage<Element>.Heap` to static operations e.g. `Buffer.Slab.insert`")
     presumes a Copyable Heap, so the `Buffer.Slab` consumer contract is
     entangled too.
   - `deinit` borrows `_heap.pointer(at:)` per bitmap bit — needs re-checking
     under the new ownership model.

Conforming Slab therefore requires deciding how a `final class` wraps a
`~Copyable` value-type Heap (ownership of init, how/whether to expose the inner
Heap, the CoW story, and the downstream `Buffer.Slab` contract). That is a
structural redesign, not "conformance + value-generic rename preserving the
existing surface," and it touches the `Buffer.Slab` boundary — explicitly
deferred to the later buffer wave (rule 3). Per rule 6, Slab is surfaced rather
than force-fitted. Per rule 5, the pre-existing baseline breakage is surfaced
rather than silently repaired with a redesign.

**Recommendation**: handle `Storage.Slab` in its own follow-up that (a) migrates
Slab onto the `~Copyable` Heap façade and (b) conforms it to `Storage.\`Protocol\``
with the natural `capacity`, coordinated with the `Buffer.Slab` migration. The
`slotCapacity` → `capacity` rename and the protocol conformance fall out of that
work for free once the ownership model is settled. Note: the Slab baseline is
already red against landed `swift-storage-primitives` independent of this pilot —
that breakage exists today and is worth tracking regardless of the protocol work.

---

## SIL gate

Per the pilot's wave-2 disposition, the specialization mechanism is already
proven for both shapes (struct + class + ManagedBuffer-façade in waves 1/3), so
no per-leaf SIL gate was run for the three CONFORMED leaves — none has a
structurally novel backing:

- `Storage.Arena` — plain `final class` (same shape as `Storage.Pool`, which had
  the wave-1 SIL gate).
- `Storage.Pool.Inline` / `Storage.Arena.Inline` — value-generic `~Copyable`
  structs with `@_rawLayout` inline storage (same shape as `Storage.Inline`,
  which had the wave-1 SIL gate).

`swift build` + `swift test` green in all three was the wave-2 acceptance bar.

---

## Acceptance state

| Criterion | State |
|-----------|-------|
| Each fitting leaf conforms with public `capacity: Index<Element>.Count`, no public `slotCapacity`, no `capacity: Int` collision | ✅ Arena, Pool.Inline, Arena.Inline |
| `swift build` + `swift test` green per conformed package | ✅ Arena 11/11, Pool.Inline 12/12, Arena.Inline 11/11 |
| Misfit leaf surfaced with specific mismatch | ✅ Slab (above) |
| Zero diffs to swift-storage-primitives, swift-storage-pool-primitives, swift-buffer-*, swift-storage-split-primitives | ✅ verified clean |
| Combined findings doc; per-package `spike/storage-protocol`; committed per phase; not pushed | ✅ this doc; Arena `4e59858`, Pool.Inline `7189103`, Arena.Inline `f3e9e66`, Slab `4db87d6` (no commits) |

---

# Wave 7 — `Storage.Arena` as a Conditionally-Copyable Value-Type Façade

<!-- wave-7 section appended 2026-05-25 -->

> Wave 7 of the Storage value-type-façade migration. Waves 3/4 converted
> `Storage.Heap` and wave 6 converted `Storage.Slab` from `final class` to
> conditionally-`Copyable` value-type façades over a private backing class with
> internal copy-on-write. `Storage.Arena` was the **last single-region
> value-semantic storage still a `final class`**. Wave 7 applies the identical
> treatment. Principal + user decision.

## Why the class was load-bearing (the constraint wave 7 had to preserve)

`Buffer.Arena` / `Buffer.Arena.Bounded` (in `swift-buffer-arena-primitives`) are
**conditionally `Copyable`** (`extension Buffer.Arena: Copyable where Element:
Copyable {}`), hold `Storage<Element>.Arena` **by value** (`var storage:
Storage<Element>.Arena`), and have **no element-cleanup `deinit` of their own**.
They relied on `Storage.Arena` being a refcounted class so the generation-token
slot-cleanup deinit runs **exactly once** across `Copyable` copies. Any restructure
had to keep that single-shot deinit guarantee intact — which means the deinit had
to stay on a **refcounted class**. This is the exact condition that justified the
Heap/Slab conversions.

## The façade structure

```
Storage<Element>.Arena            public struct Arena: ~Copyable        ← value façade
  └─ _backing: Backing            @usableFromInline var (internal)      ← the one ref
       Storage<Element>.Arena.Backing  @usableFromInline final class    ← the one allocation
         ├─ _arena:        Memory.Arena               (~Copyable; owns the raw bytes, RAII)
         ├─ _slotCapacity: Index<Element>.Count
         ├─ _highWater:    Index<Element>.Count
         ├─ _metaBase / _meta(at:) / pointer(at:)     (internal helpers)
         └─ deinit { slot in 0..<highWater where _meta(at:slot).isOccupied:
                       pointer(at:slot).deinitialize(count:.one) }       (moved verbatim)

Storage<Element>.Arena.Meta       public @frozen struct (kept on the struct façade — public path
                                  `Storage<E>.Arena.Meta` preserved; Backing references it qualified)

extension Storage.Arena: Copyable where Element: Copyable {}            ← co-located [COPY-FIX-004]
```

This is the exact `Storage.Slab` shape: a `~Copyable` struct over a private
`@usableFromInline final class`, conditionally `Copyable`, with the slot-cleanup
`deinit` on the class. A value-copy of the struct shares `_backing` shallowly
(retaining the same class); the single shared `Backing` is released exactly once
at the last `Copyable`-copy's death → its deinit fires **once** → each occupied
slot is deinitialized **once**. `Buffer.Arena`'s no-own-deinit posture continues to
work because the single-shot guarantee it depends on is preserved.

`Backing` is declared as a **sibling member** of `extension Storage where Element:
~Copyable` (not nested in the struct body) so the enclosing extension's `Element:
~Copyable` suppression propagates to the `pointer(at:)` element helper — same
placement as `Storage.Slab.Backing` / `Storage.Heap.Buffer`. The `_arena` field is
a stored `Memory.Arena` (`~Copyable`); the parts-init and `Backing.init` take it
`consuming`. `Meta` stays nested on the **struct façade** (preserving the public
path `Storage<E>.Arena.Meta` and all test references verbatim); `Backing`'s
internal helpers reference it fully-qualified as `Storage<Element>.Arena.Meta`.

**Feasibility gate (step 1): PASS.** Conditional `Copyable` on the `~Copyable`
struct façade is expressible here exactly as for Heap/Slab — no structural
obstruction; `swift build` green on the first structural pass.

## The occupancy-driven CoW mechanism (Arena's own allocation tracking)

Arena's occupancy oracle is the per-slot **`Meta.token` parity** (odd = occupied),
bounded by `highWater` — the exact predicate the backing's `deinit` iterates. The
CoW deep-copy is therefore occupancy-driven (the Arena analog of Heap copying
`initialization`-tracked ranges and Slab copying `bitmap.ones`):

```swift
guard !isKnownUniquelyReferenced(&_backing) else { return false }
let old = _backing
let freshArena = Memory.Arena(capacity: Storage.Arena._totalBytes(capacity: capacity))
unsafe freshArena.start.initializeMemory(as: Meta.self, repeating: .virgin, count: …)   // virgin meta
let fresh = Backing(_arena: freshArena, slotCapacity: capacity, highWater: highWater)
unsafe fresh._metaBase.update(from: old._metaBase, count: Int(bitPattern: capacity))     // 1. wholesale meta copy (BitwiseCopyable)
let end = highWater.map(Ordinal.init)                                                    // 2. occupied elements only
var slot: Index<Element> = .zero
while slot < end {
    if unsafe old._meta(at: slot).pointee.isOccupied {
        unsafe fresh.pointer(at: slot).initialize(to: old.pointer(at: slot).pointee)     //    at ORIGINAL position
    }
    slot = slot.successor.saturating()
}
_backing = fresh
return true
```

Two-step copy: (1) the **meta region** (`Meta` is `BitwiseCopyable`) is copied
wholesale via a typed `update(from:count:)` over `slotCapacity` entries, so tokens,
free-list links, and occupancy state transfer verbatim — slot indices used as
cross-references (tree parent/child, list next/prev) stay valid; (2) **only the
occupied** element slots (token parity odd, up to `highWater`) are
`initialize`-copied at their **original positions**, leaving free/virgin slots'
element memory uninitialized exactly as the original holds them. A sparse arena
stays sparse after CoW. (This deliberately mirrors `Buffer.Arena.copy()`'s existing
`newMeta.update(from: oldMeta, count: hw)` + `forEach(occupied:)` shape — the same
two-step recipe, now at the Storage layer.)

## Which op got `ensureUnique()`

The only genuinely-mutating public op is the **`highWater` setter**
(`set { _backing._highWater = newValue }`). The `Element: Copyable` overload gates
on `ensureUnique()` before writing. `pointer(at:)` and `meta` stay **non-mutating**
— `pointer(at:)` witnesses `Storage.`Protocol``'s `@unsafe func pointer(at:)` and
is the documented CoW-bypass escape hatch (exactly like Heap/Slab). `capacity` stays
a non-mutating read.

### The overload-selection split (same posture as Heap/Slab)

`highWater` is split into two overloads — a `~Copyable` form (direct write, no CoW;
correct because `~Copyable` Arenas are uniquely owned) in `Storage.Arena
~Copyable.swift`, and a `Copyable` form (CoW setter calling `ensureUnique()` first)
in `Storage.Arena Copyable.swift`. Swift selects the CoW-bearing overload at
concrete `Copyable` call sites; a generic `~Copyable` extension always resolves to
the no-CoW form. Same posture as `Storage.Slab`'s `bitmap` setter and
`Storage.Heap`'s `initialize` accessor — adopted preemptively here (no silent-CoW
defect was hit, the Slab wave-6 diagnosis having already established the pattern).

The `~Copyable` path carries **no** `isUnique`/`ensureUnique` surface — a
negative-space anchor comment in `Storage.Arena ~Copyable.swift` records that a
`~Copyable` Arena is statically uniquely owned (uncopyable, `_backing` never
exposed) so there is nothing to check or restore. No `~Copyable` no-op
`ensureUnique()` was added (the footgun the brief warns against).

## Tests (extended the EXISTING `Storage Arena Primitives Tests` target)

Added `Tests/Storage Arena Primitives Tests/Storage.Arena CoW Tests.swift`
mirroring `Storage.Slab CoW Tests.swift`. Per [SWIFT-TEST-003] the suite uses the
**parallel-namespace pattern** (top-level non-generic `StorageArenaCoWTests` with
`Unit` / `` `Edge Case` `` / `Integration` sub-suites) because `Storage.Arena` is
generic. The shared `occupy(&arena, slots:element:)` helper initializes each slot
via the CoW-bypass `pointer(at:)`, marks `meta[slot].token = 1` (occupied), and
advances `highWater` past the highest slot. Five new tests, all PASS (16/16 total,
debug + release):

| Test | Asserts |
|------|---------|
| `value-copied arena deinitializes each occupied slot exactly once` | **DOUBLE-FREE SAFETY** — occupy 2 slots with a tracked `Element`, value-copy, drop both, assert each element deinits **exactly once** (not twice). The load-bearing test; would over-release if the backing weren't refcounted. |
| `mutating a value-copy's highWater leaves the original unchanged` | **CoW value-semantics** — copy, confirm `isUnique == false` right after the copy (deferred), mutate the copy's `highWater` (the choke point), assert original's `highWater` + element values UNCHANGED and the copy reflects the change. |
| `CoW gives the copy an independent backing` | post-CoW both backings hold the retained shared reference; dropping both deinits the object exactly once. |
| `capacity and pointer round-trip survive the façade restructure` | `capacity`, `pointer(at:)`, `meta` occupancy round-trip, `highWater` advancement. |
| `arena over a ~Copyable element is ~Copyable` | compile-checked: `Storage<NonCopyable>.Arena` is `~Copyable` (no value-copy taken). |

The 11 pre-existing tests were preserved; the only edit was `let arena` → `var
arena` at the **three** `highWater`-mutating sites (`HighWater get and set`, both
`Deinit …` tests) — the value-semantics shift makes the `highWater` setter
`mutating`. Element ops (`initialize`/`move`/`deinitialize`) and `pointer(at:)`/
`meta`/`capacity` reads stay non-mutating, so the other 8 tests' `let arena`
bindings were untouched.

## Preserved public surface

All of: `init(minimumCapacity:)` (was `convenience` on the class; now a normal
struct init), `package init(_arena: consuming Memory.Arena, slotCapacity:,
highWater:)` (wraps into a `Backing`), the nested `@frozen public struct Meta`
(`token`/`link`/`isOccupied`/`virgin`), the static layout helpers
`_elementRegionOffset(capacity:)` / `_totalBytes(capacity:)`, `capacity`,
`highWater { get set }`, `@unsafe var meta`, `@unsafe func pointer(at:)`, the
element ops (`initialize(to:at:)`, `move(at:)`, `deinitialize(at:)`), the
`Storage.`Protocol`` conformance (`Storage.Arena+Storage.Protocol.swift` —
witnesses `capacity` + `pointer(at:)`, both preserved on the façade), and the
`@unsafe @unchecked Sendable where Element: Sendable` conformance. No public class
remains.

## Surfaced (under ask:) — `Buffer.Arena` consumer migration, NOT solved here

**Flag for the deferred consumer-migration wave** (same shape as Heap→buffer-linear,
explicitly out of scope per the brief). `Buffer.Arena` and `Buffer.Arena.Bounded`
in `swift-buffer-arena-primitives` will **not compile** against the value-type
`Storage.Arena` until migrated — `Buffer.Arena` breaking is EXPECTED. The specific
breakage (read-only inspection; **that package was not touched**, working tree clean):

- `Buffer.Arena.swift:49` / `Buffer.Arena.Bounded.swift:23` hold
  `var storage: Storage<Element>.Arena` **by value**.
- `Buffer.Arena Copyable.swift:13` (and `Buffer.Arena.Bounded Copyable.swift:13`)
  call **`Swift.isKnownUniquelyReferenced(&storage)`**. Under the old `final class
  Arena`, `storage` was a class reference and this was legal. Now
  `Storage<Element>.Arena` is a value-type struct, so
  `isKnownUniquelyReferenced(&storage)` is **illegal** (the argument must be a class
  instance) — this is the hard compile break.
- `Buffer.Arena.copy()` (`Buffer.Arena Copyable.swift:26-40`) hand-rolls the exact
  two-step deep-copy now built into `Storage.Arena.ensureUnique()`
  (`newMeta.update(from: oldMeta, count: hw)` + `forEach(occupied:)` element copy).
- `Buffer.Arena.swift:69` doc comment ("owns `Storage.Arena` (a final class)") is
  now stale.

**Migration target** (the deferred wave's work): delete `Buffer.Arena`'s own
`isKnownUniquelyReferenced(&storage)` / `copy()` CoW and **delegate to the new
`Storage.Arena.isUnique` / `ensureUnique()`** surface this wave built — the same
collapse the Heap→buffer-linear wave performed (the buffer layer stops doing its
own class-uniqueness check and adopts the Storage façade's CoW). Coordinated with
that, `var storage` ownership and the `Storage.Arena.Meta`/`pointer(at:)`/`meta`
access sites (which all remain valid — non-mutating reads) need a review pass.
**This wave does NOT touch `swift-buffer-arena-primitives`** and does not solve the
ordering here; `Storage.Arena`'s own package builds + tests green because
Buffer.Arena is a consumer, not a dependency (the dependency arrow points the other
way).

## References (wave 7 additions)

- `Storage.Slab.swift` + `Storage.Slab ~Copyable.swift` + `Storage.Slab
  Copyable.swift` (the exact façade + two-overload CoW template wave 7 mirrors, one
  discipline over).
- `swift-storage-primitives` `Tests/Storage Heap Primitives Tests/Storage.Heap CoW
  Tests.swift` + `swift-storage-slab-primitives` `Storage.Slab CoW Tests.swift`
  (test model: function-local tracker for deinit counting; parallel-namespace
  pattern).
- `swift-buffer-arena-primitives` `Buffer.Arena Copyable.swift` (the consumer's
  existing two-step `copy()` recipe `Storage.Arena.ensureUnique()` now subsumes).
- [COPY-FIX-004] (conditional conformance co-located with the type),
  [SWIFT-TEST-003] (parallel-namespace pattern for generic types),
  [DS-022] (`Memory.Arena` / value-type façade over a refcounted backing).

## Acceptance state (wave 7)

| Criterion | State |
|-----------|-------|
| `Storage.Arena` = `struct: ~Copyable` façade over a private `Backing` class; `Copyable where Element: Copyable`; deinit on `Backing`; no `~Copyable` CoW surface | ✅ |
| Double-free + CoW tests PASS; `swift build` + `swift test` green | ✅ 16/16 debug + release |
| Public surface + `Storage.`Protocol`` + `Sendable` preserved | ✅ |
| ZERO diffs outside `swift-storage-generational-primitives` | ✅ `swift-buffer-arena-primitives` working tree clean (read-only inspection) |
| Findings appended; branch `spike/storage-protocol`; committed per phase; NOT pushed | ✅ this section; phase 1+2 `21cacf6`, phase 4 tests `bb5deb3`, findings this commit |
