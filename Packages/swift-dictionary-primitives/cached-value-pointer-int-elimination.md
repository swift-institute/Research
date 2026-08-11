# Cached Value Pointer Int Elimination

<!--
---
version: 1.0.0
last_updated: 2026-02-10
status: DECISION
---
-->

## Context

An `/implementation` audit (Phase 8) identified 12+ sites in `Dictionary.Ordered`, `Bounded`, and `Small` where `_cachedValuePtr` access uses `Int(bitPattern:)` at call sites:

```swift
let pos = Int(bitPattern: keyIndex)
return body(unsafe _cachedValuePtr[pos])
```

This violates [IMPL-010] ("push Int to the edge") and [IMPL-003] (functor operations for domain crossing). The initial remediation proposed adding per-type helper methods (`_readCachedValue`, `_withCachedValue`). That approach was rejected — helpers mask infrastructure gaps rather than fixing them.

## Question

What is the correct infrastructure-level fix for `Int(bitPattern:)` at `_cachedValuePtr` access sites?

## Constraints

- `_cachedValuePtr` is `UnsafeMutablePointer<Value>` — a performance optimization caching the base pointer to avoid per-access `Storage.pointer(at:)` overhead (closure + lifetime binding)
- Values are addressed by `Index<Key>` (= `Tagged<Key, Ordinal>`) — the key determines the position, the value lives at the same position
- The typed subscript on `UnsafeMutablePointer` expects `Tagged<Pointee, Ordinal>` where `Pointee = Value`, i.e., `Index<Value>` (= `Tagged<Value, Ordinal>`)
- The mismatch is a phantom type tag: `Key` vs `Value`. The underlying ordinal is identical.

## Analysis

### Option A: Per-type helper methods

Add `_readCachedValue(at:)` / `_withCachedValue(at:body:)` on each Dictionary variant.

- Moves `Int(bitPattern:)` one call deep — doesn't eliminate it
- Must be duplicated on Ordered, Bounded, and Small (3 types)
- Doesn't improve infrastructure — no other type benefits
- Violates [IMPL-000]: masks the gap instead of fixing it

### Option B: New typed subscript overload on UnsafeMutablePointer accepting any Tag

Add `subscript<Tag>(index: Tagged<Tag, Ordinal>) -> Pointee` — accepts any phantom tag.

- Would work, but weakens the type safety the existing subscript provides
- `Tagged<Pointee, Ordinal>` constraint is intentional — it prevents using an `Index<Foo>` to access a pointer to `Bar`
- Dictionary's cross-domain access (Key index → Value position) is a *deliberate* domain crossing that should be explicit

### Option C: Use `.retag(Value.self)` with existing typed subscript

`keyIndex.retag(Value.self)` converts `Index<Key>` → `Index<Value>` (zero-cost, same memory layout). Then `_cachedValuePtr[keyIndex.retag(Value.self)]` uses the existing typed subscript.

- Zero new infrastructure — the subscript already exists in `swift-affine-primitives`
- `.retag()` is the canonical functor operation for phantom type crossing per [IMPL-003]
- The domain crossing is explicit and visible: "I'm using a key-position to access a value-pointer"
- All `Int(bitPattern:)` eliminated — the subscript handles conversion internally
- Works for both `_cachedValuePtr` (Ordered/Bounded) and `_heapValuePtr!` (Small)

### Option D: Eliminate `_cachedValuePtr` entirely — use Storage's typed API

Replace all `_cachedValuePtr` reads with `_values.pointer(at: valueIndex).pointee` or `_values._readValue(at:)`.

- Eliminates the cached pointer and its invalidation burden
- But: `_readValue` only works for Copyable values
- `pointer(at:)` uses `withUnsafeMutablePointerToElements` — closure + lifetime binding per access
- Hot-path penalty in tight loops (forEach, equality, hashing)
- Would require benchmarking to validate performance acceptability

### Comparison

| Criterion | A (helpers) | B (any-tag subscript) | C (retag) | D (no cache) |
|-----------|-------------|----------------------|-----------|--------------|
| [IMPL-000] fixes infrastructure | no | yes | yes (already done) | yes |
| [IMPL-003] functor operation | no | no | yes | n/a |
| [IMPL-010] no Int at call site | partial (hidden) | yes | yes | yes |
| Type safety preserved | n/a | weakened | preserved | preserved |
| New code required | 6 methods | 1 subscript | 0 | refactor |
| Performance impact | none | none | none | potential regression |
| Benefits other types | no | yes (questionable) | no (not needed) | no |

## Outcome

**Status**: DECISION

**Chosen**: Option C — `.retag(Value.self)` with existing typed subscript.

The infrastructure already exists. Every `_cachedValuePtr` access site changes from:

```swift
let pos = Int(bitPattern: keyIndex)
return body(unsafe _cachedValuePtr[pos])
```

to:

```swift
return body(unsafe _cachedValuePtr[keyIndex.retag(Value.self)])
```

The `.retag(Value.self)` is the correct [IMPL-003] functor operation for the Key→Value domain crossing. The typed subscript `UnsafeMutablePointer.subscript(index: Tagged<Pointee, Ordinal>)` in `swift-affine-primitives` handles all `Int` conversion internally. Zero new infrastructure needed.

### Impact on Phase 8 categories

Categories B and C from the audit plan collapse into one change:

1. Convert raw `for i in 0..<count` loops to typed `while idx < end` loops ([IMPL-033])
2. Within those loops (and all other access sites), use `.retag(Value.self)` + typed subscript ([IMPL-003])

These are inseparable — the typed loop variable enables the typed subscript.

### Affected sites (12 non-loop + 7 loop = 19 total)

| File | Line(s) | Current | After |
|------|---------|---------|-------|
| `~Copyable.swift` | 171-172 | `Int(bitPattern: keyIndex); _cachedValuePtr[pos]` | `_cachedValuePtr[keyIndex.retag(Value.self)]` |
| `~Copyable.swift` | 185-186 | `Int(bitPattern: index); _cachedValuePtr[pos]` | `_cachedValuePtr[index.retag(Value.self)]` |
| `~Copyable.swift` | 201-202 | `Int(bitPattern: index); _cachedValuePtr[pos]` | `_cachedValuePtr[index.retag(Value.self)]` |
| `~Copyable.swift` | 217-222 | raw for loop + `_cachedValuePtr[i]` | typed while loop + `_cachedValuePtr[idx.retag(Value.self)]` |
| `~Copyable.swift` | 234-240 | raw for loop + `_values.move(at:)` | typed while loop + `_values.move(at: idx.retag(Value.self))` |
| `~Copyable.swift` | 321-322 | `Int(bitPattern: keyIndex); _cachedValuePtr[pos]` | `_cachedValuePtr[keyIndex.retag(Value.self)]` |
| `~Copyable.swift` | 329-330 | `Int(bitPattern: index); _cachedValuePtr[pos]` | `_cachedValuePtr[index.retag(Value.self)]` |
| `~Copyable.swift` | 339-340 | `Int(bitPattern: index); _cachedValuePtr[pos]` | `_cachedValuePtr[index.retag(Value.self)]` |
| `~Copyable.swift` | 624-625 | `Int(bitPattern: keyIndex); _heapValuePtr![pos]` | `_heapValuePtr![keyIndex.retag(Value.self)]` |
| `Copyable.swift` | 52 | `_cachedValuePtr[Int(bitPattern: valueIndex)]` | `_cachedValuePtr[valueIndex]` (already Index\<Value\>) |
| `Copyable.swift` | 150-151 | `Int(bitPattern: keyIndex); _cachedValuePtr[pos]` | `_cachedValuePtr[keyIndex.retag(Value.self)]` |
| `Copyable.swift` | 168-170 | `Int(bitPattern: index); _cachedValuePtr[pos]` | `_cachedValuePtr[index.retag(Value.self)]` |
| `Copyable.swift` | 188-194 | raw for loop, `_cachedValuePtr[i]` | typed while loop + retag |
| `Copyable.swift` | 203-209 | raw for loop, `_cachedValuePtr[i]` | typed while loop + retag |
| `Copyable.swift` | 219-225 | raw for loop, `_cachedValuePtr[i]` | typed while loop + retag |
| `Copyable.swift` | 239-240 | `Int(bitPattern: keyIndex); _cachedValuePtr[pos]` | `_cachedValuePtr[keyIndex.retag(Value.self)]` |
| `Copyable.swift` | 257-263 | raw for loop, `_cachedValuePtr[i]` | typed while loop + retag |
| `Copyable.swift` | 270-277 | raw for loop, `_cachedValuePtr[i]` | typed while loop + retag |
| `Copyable.swift` | 311-312 | `Int(bitPattern: keyIndex); _heapValuePtr![pos]` | `_heapValuePtr![keyIndex.retag(Value.self)]` |
| `Dictionary.Index.swift` | 58-59 | `Int(bitPattern: index); _cachedValuePtr[pos]` | `_cachedValuePtr[index.retag(Value.self)]` |
| `Dictionary.Index.swift` | 70-71 | `Int(bitPattern: index); _cachedValuePtr[pos]` | `_cachedValuePtr[index.retag(Value.self)]` |

## References

- `UnsafeMutablePointer+Tagged.Ordinal.swift:55-81` — existing typed subscript
- [IMPL-003] Functor Operations for Domain Crossing — `.retag()` pattern
- [IMPL-010] Push Int to the Edge — boundary overload principle
- [IMPL-033] Typed Iteration Loops — typed loop variable requirement
