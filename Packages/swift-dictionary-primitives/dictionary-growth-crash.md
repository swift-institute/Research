# Dictionary Growth Crash Investigation

<!--
---
version: 2.0.0
last_updated: 2026-02-24
status: DECISION
---
-->

## Context

Phase 2b restructured `Buffer.Slab` to use `Storage<Element>.Slab` (class, owns deinit) instead of having `deinit` directly on `Buffer.Slab`. This enables conditional `Copyable` conformance. After the restructuring, inserting >33 elements into `Dictionary<String, Int>` crashes with:

```
Bit_Vector_Primitives/Bit.Vector.Bounded.swift:149: Precondition failed: Index out of bounds
```

Line 149 is the `Bit.Vector.Bounded` subscript setter:
```swift
precondition(index < _count, "Index out of bounds")
```

The crash threshold is inconsistent between runs (34-35 elements), suggesting hash-distribution dependence.

## Question

What causes the `Bit.Vector.Bounded` subscript setter to receive an `index >= _count` during Dictionary growth, and what is the correct fix?

## Analysis

### Confirmed Root Cause: ManagedBuffer Capacity Divergence

`Dictionary<Key, Value>` uses two independent `Buffer.Slab` instances — `_keys: Buffer<Key>.Slab` and `_values: Buffer<Value>.Slab` — that share a slot namespace. A slot returned by `_keys.firstVacant()` is used to index into BOTH buffers:

```swift
// Dictionary+set.swift:39-43
guard let slot = _keys.firstVacant() else { fatalError(...) }
_keys.insert(key, at: slot)
_values.insert(consume value, at: slot)  // slot must be valid here too
```

Both slabs are created with the same `minimumCapacity`. However, `ManagedBuffer.create(minimumCapacity:)` rounds up based on **allocation granularity and element stride**. Different element types receive different actual capacities:

| Element type | Stride | Requested `minimumCapacity` | Actual `slotCapacity` |
|-------------|--------|-----|---|
| `String` | 24 bytes | 32 | **36** |
| `Int` | 8 bytes | 32 | **33** |

The growth trigger only checks `_keys.isFull` (`Dictionary+set.swift:36`). When keys has capacity 36 and values has capacity 33:

1. After 33 inserts: keys `occ=33, cap=36, isFull=false`; values `occ=33, cap=33, isFull=true`
2. `_keys.isFull` is `false` — no growth triggered
3. `_keys.firstVacant()` returns slot **33** (valid for keys: 33 < 36)
4. `_values.insert(value, at: 33)` attempts `header.bitmap[33] = true`
5. Values bitmap has `_count == _capacity == 33` → `precondition(33 < 33)` FAILS

### Experiment Evidence

Experiment `growth-crash/` (4 iterations) confirmed this:

```
[16] >>> GREW: keys 16→36 vals 17→33
...
[33] keys: cap=36 occ=33 full=false
[33] vals: cap=33 occ=33 full=true
[33] keysVacant=Optional(33) valsVacant=nil
[33] probing vals.isOccupied(at: keys_vacant=33)...
Bit_Vector_Primitives/Bit.Vector.Bounded.swift:144: Precondition failed: Index out of bounds
```

A direct `Buffer<String>.Slab` test inserting at slot 33 with capacity 36 succeeded — confirming the bug is in Dictionary's dual-buffer slot sharing, not in Buffer.Slab itself.

### Why This Bug Was Hidden Before Phase 2b

This is **NOT** a regression from Phase 2b. The bug exists in the Dictionary design itself — it was present from the moment `Dictionary` was created with separate key/value slabs. Phase 2b restructured `Buffer.Slab` storage but did not change the Dictionary growth logic. The bug simply wasn't triggered until tests exercised >33 elements.

### Eliminated Hypotheses (from v1.0.0)

| # | Hypothesis | Status | Reason |
|---|-----------|--------|--------|
| H1 | `_count` vs `_capacity` semantics mismatch | ELIMINATED | `_count == _capacity` is correct for slab bitmaps |
| H2 | ManagedBuffer rounding creates divergence | **CONFIRMED** — but the divergence is between KEY and VALUE buffers, not within a single buffer |
| H3 | Hash table position exceeds slab capacity | ELIMINATED | Hash table rebuilt after growth |
| H4 | Hash table `shouldGrow` interaction | ELIMINATED | No bitmap interaction |
| H5 | Storage.Slab deinit timing | ELIMINATED | Empirically — crash occurs before growth, not during deinit |
| H6 | Crash in subsequent set() after _grow() | ELIMINATED | Crash is in the insert path, not post-growth |
| H7 | firstVacant trailing bits | ELIMINATED | `guard globalIndex < max` is correct |
| H8 | Conversion chain overflow | ELIMINATED | Small values, conversions are safe |

## Fix Options

### Option A: Dual isFull Check + Constrained firstVacant

Change `set()` to check both buffers:
```swift
if _keys.isFull || _values.isFull { _grow() }
```

And constrain `firstVacant()` to the minimum capacity:
```swift
let effectiveCapacity = Bit.Index.Count.min(_keys.capacity, _values.capacity)
guard let slot = _keys.firstVacant(max: effectiveCapacity) else { ... }
```

**Requires**: Adding `firstVacant(max:)` to `Buffer.Slab` public API.

| Criterion | Assessment |
|-----------|-----------|
| Correctness | Correct — prevents slot overflow in all paths |
| Minimality | Moderate — changes both `set()` and `_grow()`, adds method to Buffer.Slab |
| Transparency | Poor — "shared slot space" concern leaks into every Dictionary operation |
| Efficiency | Neutral — no wasted memory, but redundant min computation on every insert |

### Option B: Dictionary Stores Effective Capacity

Add stored property `_effectiveCapacity: Bit.Index.Count` to Dictionary. Set at init and after `_grow()`.

| Criterion | Assessment |
|-----------|-----------|
| Correctness | Correct — centralized tracking |
| Minimality | Poor — new stored property, must stay in sync |
| Transparency | Moderate — named concept is clear |
| Efficiency | Good — one computation per init/grow, cached for reads |

### Option C: Ensure Values Capacity >= Keys Capacity at Construction

After creating the keys slab, use its **actual capacity** as the minimum for the values slab:

```swift
// Dictionary.init
self._keys = Buffer<Key>.Slab(minimumCapacity: minimumCapacity)
self._values = Buffer<Value>.Slab(minimumCapacity: self._keys.capacity.retag(Value.self))

// Dictionary._grow()
var newKeys = Buffer<Key>.Slab(minimumCapacity: newCapacity)
var newValues = Buffer<Value>.Slab(minimumCapacity: newKeys.capacity.retag(Value.self))
```

Since `ManagedBuffer.create(minimumCapacity: N)` always returns capacity >= N, requesting `keys.actualCapacity` for values guarantees `values.capacity >= keys.capacity`. Any slot returned by `_keys.firstVacant()` (which is `< keys.capacity`) is therefore valid for values.

| Criterion | Assessment |
|-----------|-----------|
| Correctness | Correct — values always has >= keys capacity; firstVacant on keys returns < keys.capacity |
| Minimality | **Best** — 2-line change (init + _grow), no new APIs, no new stored properties |
| Transparency | **Best** — the invariant is established at construction; callers never see capacity divergence |
| Efficiency | Good — values may allocate slightly more memory than strictly needed, but this is bounded by ManagedBuffer rounding (typically 0-3 extra slots) |

### Option D: Use Fixed (Non-Rounded) Capacity

Override ManagedBuffer rounding by using `minimumCapacity` instead of `slotCapacity` for bitmap creation.

| Criterion | Assessment |
|-----------|-----------|
| Correctness | Correct but wasteful — allocated memory goes unused |
| Minimality | Poor — changes Buffer.Slab initialization for all users, not just Dictionary |
| Transparency | Moderate — hides the rounding benefit |
| Efficiency | Bad — wastes allocated memory system-wide |

### Comparison

| Criterion | Option A | Option B | **Option C** | Option D |
|-----------|----------|----------|--------------|----------|
| Correctness | Yes | Yes | **Yes** | Yes |
| Lines changed | ~8 | ~12 | **~4** | ~6 |
| New public API | Yes (`firstVacant(max:)`) | No | **No** | No |
| New stored property | No | Yes | **No** | No |
| Blast radius | Dictionary + Buffer.Slab | Dictionary only | **Dictionary only** | Buffer.Slab (all users) |
| Memory efficiency | Optimal | Optimal | Near-optimal | Wasteful |
| Invariant location | Distributed (every insert) | Centralized (stored) | **Structural (at construction)** | Global (all slabs) |

## Outcome

**Status**: DECISION

**Chosen**: **Option C — Ensure values capacity >= keys capacity at construction.**

**Rationale**: This establishes the invariant structurally — at the two construction sites (`init` and `_grow`). No ongoing bookkeeping, no new APIs, no leaking of the "shared slot space" concern into mutation methods. The invariant is: `_values.capacity >= _keys.capacity`, guaranteed because values is created with `minimumCapacity: keys.actualCapacity`. Since `firstVacant()` always returns `< keys.capacity`, and `keys.capacity <= values.capacity`, every slot is valid for both buffers.

**Implementation**:

1. `Dictionary.init(minimumCapacity:)` — create values with `_keys.capacity` as minimum
2. `Dictionary._grow()` — create `newValues` with `newKeys.capacity` as minimum
3. No changes to `set()`, `remove()`, `drain()`, `forEach()`, or any other method
4. No changes to `Buffer.Slab` or any other package

**Edge cases verified**:
- Same Key/Value type: same stride → same rounding → no divergence (no-op fix)
- `minimumCapacity: .zero`: keys gets capacity 0 (or small), values created with that → both match
- During `_grow()` rehash loop: iterates up to old `_keys.capacity`; old values has >= old keys capacity (by invariant); new values has >= new keys capacity (by fix)
- `remove()` + re-insert: slot was originally from `_keys.firstVacant()`, valid for both by invariant
