# Storage.Pool — Value-Type Façade Conversion (Wave 8)

- **Status**: DECISION — CONVERTED
- **Date**: 2026-05-25
- **Branch**: `spike/storage-protocol`
- **Scope**: `swift-storage-pool-primitives` only (consumer breakage out of scope — deferred migration)
- **Arc**: Storage value-type-façade migration, wave 8

---

## Summary

`Storage.Pool` was the last single-region `Storage.`Protocol`` conformer still a
`final class`. The principal's decided default — consistency: convert it like the
rest of the family (`Storage.Heap`, `Storage.Slab`, in-flight `Storage.Arena`)
unless a genuine structural blocker forces reference-semantics. **Investigation
found neither blocker holds, so Pool was CONVERTED** to a conditionally-`Copyable`
value-type façade over a private `@usableFromInline final class Backing`, using
the exact Heap/Slab playbook.

---

## Step 1 — Investigation (B1 / B2 verdict)

The two blockers that would force reference-semantics, evaluated against the
consumers (`swift-link-primitives`, `swift-buffer-linked-primitives` — READ-ONLY).

### (B1) Shared mutation — DOES NOT HOLD

A single `Storage.Pool` is **not** mutated through multiple independent owners
that must observe each other's allocations. The consumer treats the pool exactly
as the stdlib `Array` / `Buffer.Linear` CoW model treats its backing class:

- `swift-buffer-linked-primitives/Sources/Buffer Linked Primitive/Buffer.Linked.swift:55-70`
  — `Buffer.Linked` is a `~Copyable` struct with a stored `var storage: Storage<Node>.Pool`
  field. It is conditionally `Copyable where Element: Copyable` (line 75), and its
  doc (lines 24-29) states it owns the pool with CoW via `isKnownUniquelyReferenced`.
- `swift-buffer-linked-primitives/Sources/Buffer Linked Primitive/Buffer.Linked Copyable.swift:30-36`
  — `ensureUnique()` does `if !isKnownUniquelyReferenced(&storage) { self = copy() }`,
  and `copy()` (line 21-23) does `storage.copy()`.
- Every mutating op calls `base.value.ensureUnique()` FIRST
  (`Buffer.Linked Copyable.swift:57, 76, 100, 113, 130, 139, 148, 155`).

So each `Buffer.Linked` value owns its own pool **after CoW**; a value-copy shares
the pool reference only until the first mutation, at which point the mutator
deep-copies into its own pool. That is value semantics — divergence on mutation,
not mutual observation. The pool's reference-semantics is an implementation detail
the consumer **already wraps with CoW**; it is NOT relied upon for cross-value
observation. → **No B1.**

`swift-link-primitives` has no operational use — only a doc mention
(`Sources/Link Primitives/Link.swift:26`). → No B1 there either.

### (B2) Non-relocatable handles — DOES NOT HOLD

Allocations are handed out as `Index<Element>` **slot numbers**, never as raw
`UnsafeMutablePointer`/addresses retained across allocations:

- `header.head`, `header.sentinel`, traversal cursors, and slot results are all
  `Index<Node>` (`Buffer.Linked ~Copyable.swift:203-249`,
  `Buffer.Linked+Pool ~Copyable.swift` throughout).
- `pointer(at:)` derives a pointer on demand from a slot index every call; no
  consumer retains a raw pointer across a subsequent `allocate()`.
- The pre-existing `Storage.Pool.copy()` (and `Memory.Pool.duplicate`,
  `swift-memory-pool-primitives/Sources/Memory Pool Primitives/Memory.Pool.Duplicate.swift`)
  preserve the exact slot layout (free list, virgin cursor, allocation bits), so
  `Index<Element>` values "remain valid in the copy" — slot numbers survive a CoW
  relocation to a fresh backing.

→ **No B2.**

### Decision

Neither B1 nor B2 holds → **CONVERT**.

---

## Step 2 — Conversion (façade structure)

Followed the exact Heap/Slab playbook
(`swift-storage-primitives/.../Storage.Heap*.swift`,
`swift-storage-slab-primitives/.../Storage.Slab*.swift`).

### Façade structure

- `public struct Pool: ~Copyable` (`Storage.Pool.swift`) over a single private
  `@usableFromInline var _backing: Backing`.
- `Backing` is a `@usableFromInline final class`, declared as a **sibling** member
  of `extension Storage where Element: ~Copyable` (so the `Element: ~Copyable`
  suppression propagates to the `Memory.Pool` field and the typed `pointer(at:)`
  chain — same placement as `Storage.Heap.Buffer` / `Storage.Slab.Backing`). It
  holds the composed `var _pool: Memory.Pool` and the slot-cleanup `deinit`.
- `extension Storage.Pool: Copyable where Element: Copyable {}` co-located in
  `Storage.Pool.swift` per [COPY-FIX-004].
- `_backing` is `var` (not `let`) so `isKnownUniquelyReferenced(&_backing)` works.

### Per-type CoW-copy logic

- CoW (`isUnique` / `ensureUnique()`) lives **ONLY** `where Element: Copyable`
  (`Storage.Pool Copyable.swift`). The deep-copy is **free-list/occupancy-driven**:
  `copy()` delegates to `_backing._pool.duplicate { src, dst in dst...initialize(to: src...pointee) }`,
  which copies allocated slots element-by-element at their ORIGINAL positions and
  raw-copies freed slots' in-band links, preserving virgin cursor + allocation
  bits. This is why slot numbers survive the copy.
- **No `~Copyable` CoW surface, no `~Copyable` no-op** — a `~Copyable` Pool is
  statically unique; the negative space is anchored with a comment in
  `Storage.Pool ~Copyable.swift` (mirroring Heap's/Slab's anchor). A `~Copyable`
  no-op would be a footgun masking the static-uniqueness guarantee.

### Choke-point split (genuinely-mutating ops)

The genuinely-mutating public ops are `allocate()`, `deallocate(at:)`, and the
`deinitialize` accessor (`.all()` → `reset()`). Each has the two-overload split:

| Op | `~Copyable` overload (no CoW) | `Copyable` overload (CoW choke point) |
|----|-------------------------------|----------------------------------------|
| `allocate()` | `Storage.Pool ~Copyable.swift` (mutating, direct) | `Storage.Pool Copyable.swift` (mutating, `ensureUnique()` first) |
| `deallocate(at:)` | `Storage.Pool ~Copyable.swift` | `Storage.Pool Copyable.swift` (`ensureUnique()` first) |
| `deinitialize` accessor | `Storage.Pool ~Copyable.swift` (`mutating _read`/`_modify`) | `Storage.Pool Copyable.swift` (`ensureUnique()` then yield) |

Swift selects the more-constrained `Copyable` overload at concrete
`Copyable`-element call sites; `~Copyable` Pools use the direct overloads. This
mirrors `Storage.Heap`'s `initialize` accessor split.

`pointer(at:)` (both mutable and `@_disfavoredOverload` immutable) stays
**non-mutating** — the documented CoW-bypass escape hatch, like
`Storage.Heap.pointer(at:)` / `Storage.Slab.pointer(at:)`.

### Public surface preserved

Full public surface retained: `init(capacity:)`, `pointer(at:)` (both overloads),
`capacity`/`allocated`/`available`/`isExhausted`/`isEmpty`, `allocate()`,
`deallocate(at:)`, `deinitialize.all()`, `copy()`, the `Error` enum, the
`Storage.`Protocol`` conformance, and `@unsafe @unchecked Sendable where Element: Sendable`.
**API delta**: `allocate()` / `deallocate(at:)` / `deinitialize` are now
`mutating` (intrinsic to the value-type façade — stdlib `Array.append` is
`mutating`). The `package init(_wrapping:)` is retained for the copy path.

### Tests

- Reworked the existing `Storage.Pool Tests.swift` to `var pool` for the now-
  `mutating` ops (functionality preserved).
- Added `Storage.Pool CoW Tests.swift` (mirrors `Storage.Slab CoW Tests.swift`,
  [SWIFT-TEST-003] parallel-namespace pattern):
  - **Double-free safety** (load-bearing): value-copy a `Storage<Tracker>.Pool`
    (refcounted element), drop both, assert each element deinitialized EXACTLY
    once — proves the deinit fires once at the last release, not per value-copy.
  - **CoW value semantics**: mutate a value-copy (`allocate`), assert the original
    is unchanged and `isUnique` flips correctly; element values survive at their
    original slot positions.
  - **CoW independence** with refcounted elements (no double-free across two
    backings).
  - `~Copyable` element compile-check (`Storage<NonCopyable>.Pool` is `~Copyable`).

---

## Verification

- `swift build` — green.
- `swift test` (debug) — 20/20 pass.
- `swift test -c release` — 20/20 pass (release-mode validation per [EXP-017] —
  the double-free / refcount-once guarantee holds under SIL optimization, which is
  where such bugs surface).
- Zero diffs outside `swift-storage-pool-primitives`.

---

## Consumer-Migration Flag (DEFERRED, out of scope)

Converting `Storage.Pool` from `final class` → `~Copyable` value-type façade
**breaks** the two consumers, as expected. The breakage is a deferred migration
(NOT fixed here):

- `swift-buffer-linked-primitives`:
  - `Buffer.Linked Copyable.swift:31` — `isKnownUniquelyReferenced(&storage)` no
    longer typechecks (storage is now a struct, not a class). Migration: the
    consumer's CoW should delegate to the pool's own `isUnique`/`ensureUnique()`
    (or hold the pool by its `_backing`), rather than reach for
    `isKnownUniquelyReferenced` on the struct directly.
  - `Buffer.Linked Copyable.swift:22` — `storage.copy()` is now
    `where Element: Copyable` and returns a value; semantics differ from the prior
    class-clone.
  - All `storage.allocate()` / `storage.deallocate()` / `storage.deinitialize`
    call sites are now `mutating` and require a mutable `storage` binding (it is a
    `var` field, so this mostly holds, but the static-op call sites passing
    `storage:` by value need review).
  - Stale doc comments referencing "`Storage<Node>.Pool` is a `final class`"
    (`Buffer.Linked.swift:26`, `:52`) need updating.
- `swift-link-primitives`: doc mention only (`Link.swift:26`); no code change
  required beyond doc accuracy.

The consumer migration is its own wave — likely tracked alongside the
`Buffer.Linked` value-type-façade alignment.
