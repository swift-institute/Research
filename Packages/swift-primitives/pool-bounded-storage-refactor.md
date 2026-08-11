# Pool.Bounded Storage Refactor

<!--
---
version: 1.0.0
last_updated: 2026-02-24
status: RECOMMENDATION
tier: 1
---
-->

## Context

Pool.Bounded manages two parallel fixed-capacity arrays:

1. **`slots: [Slot]`** — mutable slot state machine (inside `Mutex<State>`)
2. **`entries: [Entry]`** — immutable class-reference storage for ~Copyable resources (on the class)

Both are stdlib `Swift.Array` subscripted by `Slot.Index`, which was `Tagged<Slot, Int>` (now changed to `Tagged<Slot, Ordinal>` = `Index<Slot>`). The current code uses `.rawValue` at 30+ call sites because stdlib Array only accepts `Int` subscripts.

An agent added `Array+Ordinal.Protocol.swift` to pool-primitives as a boundary overload. This is wrong — pool-primitives should not extend stdlib Array. The question is: what should it do instead?

## Question

What is the ideal storage type for Pool.Bounded's `slots` and `entries` arrays to eliminate `.rawValue` while staying within the typed infrastructure?

## Constraints

1. **Slots** are Copyable structs (index + state enum), mutable, inside `Mutex<State>`
2. **Entries** are Copyable class references (`Ownership.Slot<Resource>`), immutable array, mutation is on the class objects via `.move.in`/`.move.out`
3. Both arrays are fixed-capacity, set at init, never grow
4. Both indexed by the same `Slot.Index` = `Index<Slot>` = `Tagged<Slot, Ordinal>`
5. Entry's element type (`Ownership.Slot<Resource>`) differs from the index tag (`Slot`)
6. `State` is `~Copyable` (contains `Async.Waiter.Queue.Unbounded`)
7. Pool doesn't need `Swift.Collection` conformance on these arrays
8. Pool doesn't need copy-on-write — slots mutated only inside Mutex, entries are `let`
9. No new infrastructure should be needed in other packages (upstream changes acceptable if justified)

## Analysis

### Option A: Array.Fixed + Array.Fixed.Indexed\<Slot\>

**Slots**: `Array<Slot>.Fixed` — its index type IS `Index<Slot>` = `Slot.Index`. Direct match.

**Entries**: `Array<Entry>.Fixed.Indexed<Slot>` — wraps `Array<Entry>.Fixed`, provides subscripts accepting `Index<Slot>`, retags to `Index<Entry>` internally via zero-cost `.retag()`.

```swift
// State
var slots: Array<Slot>.Fixed

// Pool.Bounded
let entries: Array<Entry>.Fixed.Indexed<Slot>

// Call sites — zero .rawValue
slots[slotIndex].state              // Index<Slot> → direct match
entries[slotIndex].move.out         // Index<Slot> → retag → Index<Entry>
```

**Init**:
```swift
self.slots = try Array<Slot>.Fixed(count: capacity) { i in
    Slot(index: /* typed index from i */)
}
self.entries = Array<Entry>.Fixed.Indexed(
    try Array<Entry>.Fixed(count: capacity) { _ in Entry() }
)
```

| Criterion | Assessment |
|-----------|------------|
| Zero `.rawValue` | Yes — both arrays accept `Index<Slot>` directly |
| Infrastructure exists | Yes — `Array.Fixed.Indexed<Tag>` already in array-primitives |
| Upstream changes | None |
| Semantic clarity | High — types express intent (fixed-capacity, tagged access) |
| Over-engineering risk | Low — uses existing types as designed |
| CoW overhead | Present but inert (slots in Mutex = single owner, entries = let) |
| findEmptySlot() | Uses `RandomAccessCollection` iteration on Array.Fixed |

**Advantages**:
- Both types already exist, battle-tested
- Zero-cost retag for entries — no runtime overhead
- Bounds checking via precondition (safety net)
- `Array.Fixed` conforms to `RandomAccessCollection` when Copyable — enables `for i in slots.indices` patterns

**Disadvantages**:
- Array.Fixed wraps Buffer.Linear.Bounded which includes CoW machinery (ensureUnique). For slots (inside Mutex) and entries (let), CoW is never triggered but the machinery exists.
- Two different types for semantically parallel storage

---

### Option B: Buffer.Linear.Bounded directly + manual .retag()

**Slots**: `Buffer<Slot>.Linear.Bounded` — subscript takes `Index<Slot>`. Direct match.

**Entries**: `Buffer<Entry>.Linear.Bounded` — subscript takes `Index<Entry>`. Requires `.retag()` at every call site.

```swift
// Call sites
slots[slotIndex].state                          // direct match
entries[slotIndex.retag(Entry.self)].move.out    // manual retag
```

| Criterion | Assessment |
|-----------|------------|
| Zero `.rawValue` | Yes — but retag ceremony at every entry site |
| Infrastructure exists | Partial — no `Buffer.Linear.Bounded.Indexed<Tag>` |
| Upstream changes | None (if using manual retag) |
| Semantic clarity | Medium — retag is explicit but repetitive |
| Over-engineering risk | None |
| CoW overhead | None — buffer layer, no CoW |

**Advantages**:
- Leanest possible abstraction — no CoW, no stdlib conformances
- Direct pointer-based access via `storage.pointer(at:)`

**Disadvantages**:
- Manual `.retag(Entry.self)` at 15+ entry access sites — trades one ceremony (`.rawValue`) for another (`.retag()`)
- No `Buffer.Linear.Bounded.Indexed<Tag>` exists — would need to be added to buffer-primitives (Option E)
- No RandomAccessCollection — need typed while loops for iteration

---

### Option C: Array.Fixed for slots + stdlib [Entry] with upstream ordinal subscript

**Slots**: `Array<Slot>.Fixed` — direct match.

**Entries**: Keep `[Entry]` but add `subscript<O: Ordinal.Protocol>` to `Array` in ordinal-primitives' Standard Library Integration module.

```swift
// ordinal-primitives (new upstream addition)
extension Array {
    public subscript<O: Ordinal.Protocol>(_ position: O) -> Element {
        get { self[Int(bitPattern: position.ordinal)] }
        set { self[Int(bitPattern: position.ordinal)] = newValue }
    }
}
```

| Criterion | Assessment |
|-----------|------------|
| Zero `.rawValue` | Yes |
| Infrastructure exists | No — needs upstream addition |
| Upstream changes | ordinal-primitives: add Array subscript |
| Semantic clarity | Medium — entries remain stdlib Array (untyped capacity) |
| Over-engineering risk | Low |

**Advantages**:
- Minimal change to pool — only slots type changes
- The ordinal Array subscript is genuinely useful ecosystem-wide (parity with ContiguousArray)
- Entries stay simple

**Disadvantages**:
- Requires upstream work in ordinal-primitives
- Entries remain stdlib Array — no typed capacity, no typed count
- Mixed types: primitive Array.Fixed for slots, stdlib Array for entries

---

### Option D: Combined single storage type

Merge Slot and Entry into one array.

```swift
struct SlotEntry {
    var state: Slot.State
    let entry: Entry  // class ref
}
var storage: Array<SlotEntry>.Fixed
```

| Criterion | Assessment |
|-----------|------------|
| Zero `.rawValue` | Yes — single array, one index type |
| Simplification | Eliminates dual-array pattern |

**Rejected**: Entries are accessed OUTSIDE the lock (strict stance). Slots are mutated INSIDE the lock. Combining them into one array breaks this separation — you'd either need to access the combined struct outside the lock (unsafe) or copy the entry reference out first (which is what the current design already does via Checkout). The dual-array design is intentional and correct.

---

### Option E: Add Buffer.Linear.Bounded.Indexed\<Tag\> upstream

Add `Buffer.Linear.Bounded.Indexed<Tag>` to buffer-primitives (mirroring `Buffer.Slab.Bounded.Indexed<Tag>`), then use:

**Slots**: `Buffer<Slot>.Linear.Bounded`
**Entries**: `Buffer<Entry>.Linear.Bounded.Indexed<Slot>`

| Criterion | Assessment |
|-----------|------------|
| Zero `.rawValue` | Yes |
| Infrastructure exists | No — needs new type in buffer-primitives |
| Semantic fit | Highest — buffer layer matches Pool's needs exactly |
| CoW overhead | None |

**Advantages**:
- Leanest runtime — no CoW, no stdlib conformances
- Perfect semantic match — fixed buffer with retagged access
- New type benefits other consumers (pattern already proven by Slab.Bounded.Indexed)

**Disadvantages**:
- Requires upstream infrastructure addition
- Pool loses RandomAccessCollection iteration convenience
- More work for marginal benefit over Option A (CoW in Array.Fixed is never triggered)

---

## Comparison

| Criterion | A (Array.Fixed) | B (Buffer direct) | C (stdlib + upstream) | D (Combined) | E (Buffer.Indexed) |
|-----------|:-:|:-:|:-:|:-:|:-:|
| Zero `.rawValue` | **Yes** | retag ceremony | **Yes** | **Yes** | **Yes** |
| No upstream changes | **Yes** | **Yes** | No | N/A | No |
| Type-safe capacity | **Yes** | **Yes** | No (entries) | **Yes** | **Yes** |
| No CoW overhead | No (inert) | **Yes** | No (entries) | No | **Yes** |
| Iteration support | **Yes** (RAC) | Manual | **Yes** (stdlib) | **Yes** | Manual |
| Semantic clarity | **High** | Medium | Medium | Rejected | **High** |
| Implementation effort | **Low** | Low | Medium | N/A | Medium |

## Outcome

**Status**: RECOMMENDATION

**Recommendation: Option A** — `Array<Slot>.Fixed` for slots, `Array<Entry>.Fixed.Indexed<Slot>` for entries.

**Rationale**:

1. **Zero upstream changes** — both types already exist and are designed for exactly this use case. `Array.Fixed.Indexed<Tag>` is the retagging wrapper for cross-domain fixed-capacity access.

2. **Zero `.rawValue`, zero `.retag()` at call sites** — slots match directly, entries retag internally and invisibly.

3. **Typed capacity** — `Array.Fixed` tracks count as `Index<Element>.Count`, not bare `Int`.

4. **The CoW concern is theoretical** — `ensureUnique()` is never called because: (a) slots are inside a Mutex (single accessor), (b) entries are `let` (subscript only reads the class reference, mutation happens on the class object). The CoW machinery costs zero at runtime — it's a branch-never-taken.

5. **RandomAccessCollection** — enables `for index in slots.indices` patterns, which cleans up `findEmptySlot()`.

**Follow-up (non-blocking)**: Consider adding the generic `Ordinal.Protocol` subscript to `Array` in ordinal-primitives Standard Library Integration (Option C's upstream addition). This is independently valuable for ecosystem parity with ContiguousArray, but Pool should not wait for it.

**Follow-up (non-blocking)**: Consider adding `Buffer.Linear.Bounded.Indexed<Tag>` to buffer-primitives (Option E). This is a natural extension of the `Slab.Bounded.Indexed` pattern and would benefit future consumers who need buffer-level retagging without Array overhead. But Array.Fixed.Indexed is sufficient for Pool.

## Implementation Notes

1. Delete `Array+Ordinal.Protocol.swift` from pool-primitives (wrong location for stdlib extension)
2. Change `slots: [Slot]` → `slots: Array<Slot>.Fixed` in State
3. Change `entries: [Entry]` → `entries: Array<Entry>.Fixed.Indexed<Slot>` in Pool.Bounded
4. Update State.init to use `Array<Slot>.Fixed(count:body:)` initializer
5. Update Pool.Bounded.init to use `Array<Entry>.Fixed.Indexed(...)` initializer
6. Verify `Slot.Index` = `Index<Slot>` = `Tagged<Slot, Ordinal>` — confirm the typealias chain
7. All `.rawValue` sites become direct subscript access — verify with grep
8. Update `findEmptySlot()` to use typed iteration
9. Build and test

## References

- `Array.Fixed.Indexed<Tag>`: `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Fixed Primitives/Array.Fixed.Indexed.swift`
- `Buffer.Slab.Bounded.Indexed<Tag>` (pattern precedent): `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Sources/Buffer Slab Primitives/Buffer.Slab.Bounded.Indexed.swift`
- Pool audit: `/Users/coen/Developer/swift-institute/Research/async-pool-primitives-audit.md`
