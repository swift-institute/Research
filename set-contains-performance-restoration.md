# Set Contains Performance Restoration

<!--
---
version: 2.0.0
last_updated: 2026-03-02
status: DECISION
tier: 2
---
-->

## Context

`Set.Protocol` (`__SetProtocol`) was implemented with `contains(_ element: borrowing Element) -> Bool` as a protocol requirement. To support `~Copyable` elements unconditionally, all four set variants replaced their O(1) hash-table `contains` with O(n) linear scan. The regression is measurable: "Large set operations" test went from 0.29s to 0.79s.

**Root cause**: F2 (set-protocol-noncopyable-conformance experiment). Closures consume captured `~Copyable` values — `borrowing Element` cannot be captured. The old O(1) `contains` relied on `{ idx in buffer[idx] == element }` which captures `element`.

**Trigger**: The `set-protocol-abstraction` research (v2.0.0) flagged the O(n) regression as a known trade-off and recommended investigating restoration.

**Precedent**: `index(_ element: Element)` on `Set.Ordered.Static` (line 55, unconstrained extension) already uses the closure pattern `{ idx in _buffer[idx] == element }` on a ~Copyable container. It works because `element` is **owned** (not borrowing) and nonescaping closures **borrow** self implicitly.

## Question

What is the optimal architecture for `Set.Protocol.contains` that provides:
1. O(1) hash-table lookup as the default for all variants
2. `~Copyable` element support as first-class (not conditional)
3. `Copyable` elements getting O(1) without witness ambiguity

## Analysis

### Constraint Inventory

| ID | Constraint | Impact |
|----|-----------|--------|
| C1 | Protocol witness: `func contains(_ element: borrowing Element) -> Bool` | Signature is fixed |
| C2 | Closures cannot capture `borrowing` parameters (F2) | `element` must not be captured |
| C3 | Nonescaping closures CAN borrow `self` in non-mutating functions | `buffer[idx]` access works even for ~Copyable self |
| C3a | Extensions of ~Copyable generics get implicit `where Element: Copyable` (F7) | Must use explicit `where Element: ~Copyable` opt-out |
| C4 | `element: Element` (owned) CAN be captured by closures | `index(_ element: Element)` already proves this |
| C5 | Hash.Table stores only Ints (hashes + positions) — element-agnostic | Hash table API is the integration point |
| C6 | Buffer types vary: Ordered/Fixed are class-backed (Copyable ref), Static/Small are inline (~Copyable) | Class-backed: extract ref. Inline: extract pointer or use probe iterator |
| C7 | `element.hashValue` requires owned Element (Hashable) | Must use `hash(into:)` for borrowing elements |

**Key insight**: C2 + C3a together mean closures on ~Copyable containers cannot capture either `borrowing element` (C2) or `self` implicitly (C3a without opt-out). The solution: pass element as a `borrowing Context` parameter (not captured), and capture only Copyable storage handles (pointers, class refs) instead of self. This is validated by F8.

### Prior Art

**Static's `index` method** (Set.Ordered.Static.swift:55, unconstrained extension):

```swift
// This ALREADY COMPILES on ~Copyable Static (unconstrained extension)
public func index(_ element: Element) -> Index<Element>.Bounded<capacity>? {
    let hashValue = element.hashValue
    guard let position = _hashTable.position(forHash: hashValue, equals: { idx in
        _buffer[idx] == element     // closure borrows self for _buffer ✓
                                    // closure captures owned element ✓
    }) else { return nil }
    return position
}
```

This proves: nonescaping closures borrow ~Copyable self without issue. The only difference between `index` (works) and `contains` (doesn't) is parameter convention: `Element` (owned) vs `borrowing Element`.

### Option A: Context-Passing Overload on Hash.Table

Add a new overload to `Hash.Table` that passes the element **through** to the closure as a parameter instead of requiring capture:

```swift
// New Hash.Table API
extension Hash.Table where Element: ~Copyable {
    public borrowing func position<Context: ~Copyable>(
        forHash hashValue: Hash.Value,
        context: borrowing Context,
        equals: (Index<Element>, borrowing Context) -> Bool
    ) -> Index<Element>?
}
```

The implementation is identical to the existing `position(forHash:equals:)` except it threads `context` through to each `equals` call.

**Set variant usage** (all four variants, unconstrained):

```swift
func contains(_ element: borrowing Element) -> Bool {
    var hasher = Hasher()
    element.hash(into: &hasher)
    let hashValue = hasher.finalize()
    return hashTable.position(
        forHash: hashValue,
        context: element,
        equals: { idx, elem in buffer[idx] == elem }
        //       ↑                ↑           ↑
        //       position         borrows     parameter
        //       from table       self        (not captured)
    ) != nil
}
```

**Why this works**:
- `buffer[idx]`: closure borrows self for buffer access (C3 — proven by `index`)
- `elem`: received as `borrowing Context` parameter (C2 — not captured)
- `element.hash(into:)`: uses borrowing accessor (C7 — no `hashValue` property needed)

**Pros**:
- O(1) for ALL variants, ALL element types
- Single `contains` implementation per variant — no overloads, no ambiguity
- The protocol witness IS the O(1) version
- Minimal API addition: one overloaded method on Hash.Table

**Cons**:
- Requires adding overload to Hash.Table and Hash.Table.Static
- **Unvalidated**: nonescaping closure borrowing ~Copyable self with context-passing hasn't been tested in an experiment with production-like types

**Risk**: The critical assumption (C3) is demonstrated by `index` but not yet validated for the context-passing pattern. If the compiler treats context-passing closures differently (e.g., implicit self capture behaves differently when the closure also has a `borrowing Context` parameter), this would fail.

### Option B: Probe Iterator on Hash.Table

Add a closure-free probing API that returns candidate positions:

```swift
extension Hash.Table where Element: ~Copyable {
    public struct ProbeSequence: ~Escapable { ... }
    public borrowing func candidates(forHash: Hash.Value) -> ProbeSequence
}
```

**Set variant usage**:

```swift
func contains(_ element: borrowing Element) -> Bool {
    var probe = hashTable.candidates(forHash: computeHash(element))
    while let pos = probe.next() {
        if buffer[pos] == element { return true }
    }
    return false
}
```

**Pros**:
- No closures at all — sidesteps all capture issues
- Caller drives equality checking — maximum flexibility
- Would work even if C3 turns out to be fragile

**Cons**:
- Exposes hash table internals (probing sequence, bucket structure)
- ProbeSequence must be `~Escapable` (borrows hash table's buffer) — adds complexity
- Or ProbeSequence copies out hash/position arrays — O(n) setup cost
- Larger API surface change than Option A

### Option C: Dual Overloads (Unconstrained O(n) + Copyable O(1))

Keep the current unconstrained O(n) `contains` as the protocol witness. Add a Copyable-constrained O(1) overload:

```swift
// Protocol witness — unconstrained, O(n)
extension Set.Ordered {
    func contains(_ element: borrowing Element) -> Bool { /* linear scan */ }
}

// Direct-call overload — Copyable, O(1)
extension Set.Ordered where Element: Copyable {
    func contains(_ element: Element) -> Bool {
        index(element) != nil  // uses existing O(1) index
    }
}
```

**Pros**:
- No changes to Hash.Table
- Ships immediately
- Copyable callers get O(1) through overload resolution

**Cons**:
- **Call-site ambiguity**: when `Element: Copyable`, both overloads are available. `set.contains(x)` is ambiguous (owned vs borrowing parameter)
- ~Copyable elements remain O(n) — not first-class
- Protocol defaults (`isDisjoint`, `isSubset`, `isSuperset`) always use the witness (O(n)), even for Copyable elements
- Code duplication: two `contains` per variant

**Verdict**: Violates the goal of ~Copyable as first-class. The ambiguity is a known problem from the initial implementation.

### Option D: Single Owned `contains` (Drop `borrowing`)

Change the protocol requirement from `borrowing Element` to `consuming Element`:

```swift
public protocol __SetProtocol: ~Copyable {
    func contains(_ element: consuming Element) -> Bool
}
```

**Pros**:
- Closures can capture consumed elements — existing O(1) works unchanged
- No Hash.Table changes needed

**Cons**:
- **Destroys the element**: callers must give up ownership. `if set.contains(key)` consumes `key`
- Protocol defaults (`isDisjoint`) can't use it: `forEach` provides `borrowing Element`, which can't satisfy `consuming`
- Fundamentally wrong semantics — querying a set should not destroy the query

**Verdict**: Rejected. Membership queries must not consume the element.

### Comparison

| Criterion | A: Context-passing | B: Probe iterator | C: Dual overloads | D: Consuming |
|-----------|-------------------|-------------------|-------------------|--------------|
| O(1) for ~Copyable elements | Yes | Yes | No (O(n)) | Yes |
| O(1) for Copyable elements | Yes | Yes | Yes (overload) | Yes |
| No call-site ambiguity | Yes | Yes | No | Yes |
| Protocol witness is O(1) | Yes | Yes | No (O(n)) | Yes |
| Hash.Table changes | 1 overload | New type + API | None | None |
| Semantic correctness | ✓ | ✓ | ✓ | ✗ (consuming) |
| Validated by experiment | Partial (F4) | Partial (F5) | Known ambiguity | N/A |
| ~Copyable first-class | Yes | Yes | No | Technically yes |

## Outcome

**Decision**: Option A (context-passing overload on Hash.Table).

This is the theoretical optimal: a single O(1) `contains` that serves as the protocol witness for all element types. The closure captures a Copyable storage handle and receives the element as a `borrowing Context` parameter (not captured). No overloads, no ambiguity, no O(n) fallback.

### H5 Validation (2026-03-02)

**H5 CONFIRMED** with refinements (F7, F8):

- **F7**: Extensions of `~Copyable` generic types get implicit `where Element: Copyable` on ALL extensions — even empty functions. Root cause: `extension Foo<T>` implicitly constrains `T: Copyable` unless the extension explicitly writes `where T: ~Copyable`. Fix: explicit `& ~Copyable` opt-out on the extension.

- **F8**: ~Copyable container with context-passing lookup **works** when:
  (a) The extension has explicit `where Element: ~Copyable` (or `& ~Copyable`),
  (b) A Copyable storage handle (e.g., `UnsafeMutablePointer`, `Array` ref) is extracted to a local and captured in the closure instead of self,
  (c) The element is passed as `borrowing Context` parameter — not captured.
  Tested with `NCBuffer<MoveOnlyKey>` where `MoveOnlyKey: ~Copyable`. `lookup(20) = true`, `lookup(99) = false`. Build Succeeded.

**Architectural implication**: The original H5 hypothesis assumed closures could implicitly borrow ~Copyable self. F7 shows they cannot without explicit `& ~Copyable` on the extension. But this is not a blocker — it means the production code must either:
1. Use explicit `where Element: ~Copyable` on extensions (for Static/Small), or
2. Extract a Copyable handle to avoid self-capture entirely (works for all variants)

For production, approach (2) is preferred: all four variants already have a Copyable storage handle:
- **Ordered/Fixed**: `buffer` is `Buffer<Element>.Linear` / `.Bounded` — class-backed, ref is Copyable
- **Static**: `_hashTable` is `Hash.Table.Static` — Copyable value type. But `_buffer` is inline (`Buffer.Linear.Inline`) — ~Copyable. The context-passing closure captures `_hashTable` (Copyable) while `_buffer` access goes through the hash table's position (Int), which is Copyable.
- **Small**: `_heapHashTable` is `Hash.Table?` — Copyable when spilled. Inline mode uses linear scan (no hash table).

### Implementation Record (2026-03-02)

Option A implemented. `position(forHash:context:equals:)` added to `Hash.Table` and `Hash.Table.Static`. All four set variants use O(1) context-passing `contains` as the protocol witness. All 59 tests pass.

**F7/F8 did not apply to production**: The experiment's F7 (implicit `where Element: Copyable` on all extensions) was specific to standalone generic types like `NCBuffer<Element: ~Copyable>`. Production types are nested inside `Set<Element>` — the generic parameter `Element` comes from the outer scope, not the type's own parameter list. Extensions of nested types do NOT get implicit Copyable constraints. This means the closure `{ idx, elem in buffer[idx] == elem }` borrows self directly — no need for explicit `where Element: ~Copyable` or Copyable handle extraction.

**F3 did not apply**: `element.hashValue` resolves on `borrowing Element` in nested type extensions. The F3 finding was also specific to standalone generics. All four variants use `element.hashValue` directly.

**Small optimization**: Small uses O(1) hash-table lookup when spilled (via extracted `_heapHashTable!` local to avoid exclusivity conflicts), O(n) linear scan when inline (no hash table in inline mode).

Files changed:
- `Hash.Table+Lookup.swift` — context-passing `position(forHash:context:equals:)` overload
- `Hash.Table.Static+Lookup.swift` — context-passing `position(forHash:context:equals:)` overload
- `Set.Ordered ~Copyable.swift` — O(1) `contains` via `hashTable.position(context:)`
- `Set.Ordered.Fixed.swift` — O(1) `contains` via `hashTable.position(context:)`
- `Set.Ordered.Static.swift` — O(1) `contains` via `_hashTable.position(context:)`
- `Set.Ordered.Small.swift` — O(1) `contains` (spilled) / O(n) (inline)

### Resolved Questions

1. **`hashValue` vs `hash(into:)`**: `element.hashValue` works in nested type extensions — F3 was experiment-specific. Using `element.hashValue` directly.
2. **Hash.Table.Static position type**: Context-passing overload uses `Index<Element>.Bounded<bucketCapacity>`, matching existing API.
3. **Deprecate closure-based API?**: No — it remains useful for cases where element is owned (e.g., `index`, `insert`).

## References

- `set-protocol-abstraction.md` — v2.0.0, Option B implementation record
- `set-protocol-noncopyable-conformance/` — F1, F2, F3 findings
- `hash-table-context-passing-lookup/` — F4, F5, F6, F7, F8 findings
- `Set.Ordered.Static.swift:55` — `index` proving closure borrows ~Copyable self
- `Hash.Table+Lookup.swift` — closure-based and context-passing position API
