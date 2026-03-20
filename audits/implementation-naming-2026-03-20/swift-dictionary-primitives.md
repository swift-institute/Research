# swift-dictionary-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: /implementation [IMPL-*], /naming [API-NAME-*]
**Scope**: All 26 `.swift` files in `Sources/`
**Status**: READ-ONLY audit — findings only

---

## Summary Table

| ID | Severity | Rule | File | Line(s) | Description |
|----|----------|------|------|---------|-------------|
| DICT-001 | MEDIUM | [IMPL-010] | Dictionary.Ordered.Values.swift | 142,147 | `Int(bitPattern:)` at call site in `subscript(raw:)` getter and setter |
| DICT-002 | MEDIUM | [IMPL-010] | Dictionary.Ordered.Values.swift | 143,149 | `Ordinal(UInt(index))` raw construction chain at call site |
| DICT-003 | MEDIUM | [IMPL-010] | Dictionary.Ordered Copyable.swift (Core) | 152 | `Int(bitPattern:)` at call site in `subscript(index:)` |
| DICT-004 | MEDIUM | [IMPL-010] | Dictionary.Ordered Copyable.swift (Core) | 153 | `Ordinal(UInt(index))` raw construction chain at call site |
| DICT-005 | MEDIUM | [IMPL-010] | Dictionary.Ordered Copyable.swift (Core) | 226 | `Int(bitPattern:)` at call site in Bounded `subscript(index:)` |
| DICT-006 | MEDIUM | [IMPL-010] | Dictionary.Ordered Copyable.swift (Core) | 227 | `Ordinal(UInt(index))` raw construction chain in Bounded `subscript(index:)` |
| DICT-007 | MEDIUM | [IMPL-010] | Dictionary.Ordered Copyable.swift (Core) | 280 | `Int(bitPattern:)` at call site in Static `subscript(index:)` |
| DICT-008 | MEDIUM | [IMPL-010] | Dictionary.Ordered Copyable.swift (Core) | 281 | `Ordinal(UInt(index))` raw construction chain in Static `subscript(index:)` |
| DICT-009 | MEDIUM | [IMPL-010] | Dictionary.Ordered Copyable.swift (Core) | 305 | `Int(bitPattern:)` at call site in Small `subscript(index:)` |
| DICT-010 | MEDIUM | [IMPL-010] | Dictionary.Ordered Copyable.swift (Core) | 306-311 | `Ordinal(UInt(index))` raw construction chains (2x) in Small `subscript(index:)` |
| DICT-011 | MEDIUM | [IMPL-010] | Dictionary.Ordered ~Copyable.swift | 408 | `Int(bitPattern:)` in Static `withValue(atIndex:_:)` |
| DICT-012 | MEDIUM | [IMPL-010] | Dictionary.Ordered ~Copyable.swift | 409 | `Ordinal(UInt(index))` raw construction chain in Static `withValue(atIndex:_:)` |
| DICT-013 | MEDIUM | [IMPL-010] | Dictionary.Ordered ~Copyable.swift | 558 | `Int(bitPattern:)` in Small `withValue(atIndex:_:)` |
| DICT-014 | MEDIUM | [IMPL-010] | Dictionary.Ordered ~Copyable.swift | 559 | `Ordinal(UInt(index))` raw construction chain in Small `withValue(atIndex:_:)` |
| DICT-015 | MEDIUM | [IMPL-010] | Dictionary.Ordered Copyable.swift (Ordered module) | 93,128 | `Int(bitPattern: count)` in `underestimatedCount` |
| DICT-016 | MEDIUM | [IMPL-010] | Dictionary.Ordered.Bounded Copyable.swift | 93,113 | `Int(bitPattern: count)` in Bounded `underestimatedCount` and `endIndex` |
| DICT-017 | MEDIUM | [IMPL-010] | Dictionary.Ordered.Static Copyable.swift | 124 | `Int(bitPattern: count)` in Static `underestimatedCount` |
| DICT-018 | MEDIUM | [IMPL-010] | Dictionary.Ordered.Small Copyable.swift | 128 | `Int(bitPattern: count)` in Small `underestimatedCount` |
| DICT-019 | MEDIUM | [IMPL-010] | Dictionary Copyable.swift (Slab module) | 93 | `Int(bitPattern: count)` in unordered Dict `underestimatedCount` |
| DICT-020 | MEDIUM | [IMPL-010] | Dictionary.Ordered Copyable.swift (Ordered module) | 130,134-136 | `Int(bitPattern: count)` and `Ordinal(UInt(position))` in Collection `endIndex` and `subscript(position:)` |
| DICT-021 | MEDIUM | [IMPL-010] | Dictionary.Ordered.Bounded Copyable.swift | 117-119 | `Int(bitPattern: count)` and `Ordinal(UInt(position))` in Bounded Collection subscript |
| DICT-022 | LOW | [API-NAME-002] | Dictionary.Ordered ~Copyable.swift | 407 | `withValue(atIndex:)` — compound parameter label; typed overloads use cleaner `at:` |
| DICT-023 | LOW | [API-NAME-002] | Dictionary.Ordered ~Copyable.swift | 557 | `withValue(atIndex:)` — same compound parameter on Small variant |
| DICT-024 | LOW | [IMPL-033] | Dictionary.Ordered ~Copyable.swift | 461-468 | `_inlineIndex(of:)` uses typed while loop outside iteration infrastructure |
| DICT-025 | LOW | [API-IMPL-005] | Dictionary.Ordered.swift | 86,120,204,215,277 | Five type declarations in one file (Dictionary, Entry, Ordered, Ordered.Entry, Bounded) |
| DICT-026 | INFO | [PATTERN-017] | Dictionary.Ordered ~Copyable.swift | 358 | `__unchecked` at call site in Static `set(_:_:)` hash table insert |
| DICT-027 | INFO | [PATTERN-017] | Dictionary ~Copyable.swift | 152-153 | `__unchecked` at call site in unordered Dict `_grow()` hash table insert |
| DICT-028 | INFO | [PATTERN-017] | Dictionary+set.swift | 44-46 | `__unchecked` at call site in unordered Dict `set(_:_:)` hash table insert |
| DICT-029 | LOW | [IMPL-020] | Dictionary.Ordered ~Copyable.swift | various | Ordered Dictionary ~Copyable operations are bare methods, not Property.View nested accessors |
| DICT-030 | INFO | [IMPL-021] | Dictionary.Ordered.Merge.swift | 52 | Hand-rolled `Merge` struct instead of `Property<Merge, Base>.View` pattern |
| DICT-031 | INFO | [IMPL-021] | Dictionary.Ordered.Values.swift | 50 | Hand-rolled `Values` struct instead of `Property<Values, Base>.View` pattern |
| DICT-032 | LOW | [IMPL-050] | Dictionary.Ordered ~Copyable.swift | 329,421 | Static variant `withValue(at:)` accepts unbounded `Index<Key>`, not `Bounded<capacity>` |

---

## Detailed Findings

### DICT-001 through DICT-021: `Int(bitPattern:)` and Raw Construction at Call Sites

**Rule**: [IMPL-010] — `Int(bitPattern:)` conversions MUST live inside boundary overloads, never at call sites.

These findings cluster into two categories:

**Category A — `subscript(index index: Int)` and `withValue(atIndex index: Int)` methods**
(DICT-001 through DICT-014)

Every variant (Ordered, Bounded, Static, Small) provides a raw-Int subscript or `withValue(atIndex:)` method for "stdlib compatibility." Each contains:

```swift
precondition(index >= 0 && index < Int(bitPattern: _keys.count), "Index out of bounds")
let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(index)))
```

The `Int(bitPattern:)` conversion and `Ordinal(UInt(index))` construction chain appear at the call site rather than being hidden in a boundary overload. These methods exist 8 times across variants with nearly identical bodies.

**File**: `Dictionary.Ordered.Values.swift` lines 140-152 (Values subscript)
**File**: `Dictionary.Ordered Copyable.swift` (Core) lines 151-155 (Ordered), 225-229 (Bounded), 279-283 (Static), 304-313 (Small)
**File**: `Dictionary.Ordered ~Copyable.swift` lines 407-411 (Static), 557-561 (Small)

**Category B — `underestimatedCount`, `endIndex`, Collection subscripts**
(DICT-015 through DICT-021)

Swift.Sequence and Swift.Collection conformances require `Int` return types. Each variant converts via `Int(bitPattern: count)` at the property level. The Collection subscripts additionally chain `Ordinal(UInt(position))`.

These are stdlib boundary points and arguably the correct location for the conversion. However, the pattern is repeated identically across 5 variant modules. A shared boundary overload or protocol default would centralize the conversion.

**Recommendation**: For Category A, consider whether a typed-index-only API is sufficient (the typed `subscript(at:)` already exists). If the raw-Int overload must remain for stdlib interop, centralize the conversion via a shared extension or protocol default. For Category B, these are inherent to stdlib conformance but could be centralized.

---

### DICT-022 and DICT-023: `withValue(atIndex:)` Compound Parameter Label

**Rule**: [API-NAME-002] — Methods MUST NOT use compound names.

```swift
// Static variant (line 407):
public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R

// Small variant (line 557):
public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R
```

The label `atIndex` combines a preposition with a noun in a single parameter label. The typed-index overloads use the cleaner `at index: Index<Key>` label. The `atIndex` variant diverges from the naming pattern used by the typed overloads on the same types.

This is LOW severity because it is an argument label rather than a method name, and the method itself (`withValue`) is not compound. However, the inconsistency with the `at:` label on the typed overloads is worth noting.

---

### DICT-024: Typed While Loop in `_inlineIndex(of:)`

**Rule**: [IMPL-033] — Iteration MUST use the highest-level abstraction that expresses intent.

```swift
// Dictionary.Ordered ~Copyable.swift, lines 461-468:
func _inlineIndex(of key: Key) -> Index_Primitives.Index<Key>? {
    var idx: Index_Primitives.Index<Key> = .zero
    let end = _inlineKeys.count.map(Ordinal.init)
    while idx < end {
        if _inlineKeys[idx] == key { return idx }
        idx += .one
    }
    return nil
}
```

This is a Level 3 "typed while loop" used outside iteration infrastructure. The intent is "find the first index where the key matches" — a `firstIndex(where:)` or equivalent. However, `_inlineKeys` is `Buffer<Key>.Linear.Inline<inlineCapacity>` which is `~Copyable` and may not have a `firstIndex(where:)` method. The finding is LOW because this may be an infrastructure gap in `Buffer.Linear.Inline` rather than a dictionary-primitives issue.

---

### DICT-025: Multiple Type Declarations in `Dictionary.Ordered.swift`

**Rule**: [API-IMPL-005] — Each `.swift` file MUST contain exactly one type declaration.

`Dictionary.Ordered.swift` declares:

1. `Dictionary<Key, Value>` (line 86)
2. `Dictionary.Entry` (line 120)
3. `Dictionary.Ordered` (line 204)
4. `Dictionary.Ordered.Entry` (line 215)
5. `Dictionary.Ordered.Bounded` (line 277)

Five type declarations in one file. Per the rule, each should have its own file:
- `Dictionary.swift` — the unordered `Dictionary` struct
- `Dictionary.Entry.swift` — the `Entry` nested type
- `Dictionary.Ordered.swift` — the `Ordered` struct
- `Dictionary.Ordered.Entry.swift` — the `Ordered.Entry` nested type
- `Dictionary.Ordered.Bounded.swift` — the `Bounded` struct

The conditional Copyable conformances and Sendable extensions at the bottom of the file could remain with their respective type files or in a separate conformances file.

**Note**: `Dictionary.Ordered.Static.swift` and `Dictionary.Ordered.Small.swift` correctly follow one-type-per-file.

---

### DICT-026, DICT-027, DICT-028: `__unchecked` at Call Sites

**Rule**: [PATTERN-017] — `.rawValue` and `__unchecked` MUST be confined to boundary code.

Three locations use `_hashTable.insert(__unchecked: (), ...)`:

1. **Static `set`** (Dictionary.Ordered ~Copyable.swift, line 358):
   ```swift
   _ = _hashTable.insert(__unchecked: (), position: position, hashValue: hashValue)
   ```

2. **Unordered `_grow`** (Dictionary ~Copyable.swift, lines 151-155):
   ```swift
   newHashTable.insert(__unchecked: (), position: newSlot.retag(Key.self), hashValue: key.hashValue)
   ```

3. **Unordered `set`** (Dictionary+set.swift, lines 44-46):
   ```swift
   _hashTable.insert(__unchecked: (), position: slot.retag(Key.self), hashValue: hashValue)
   ```

These are INFO severity. The `__unchecked` here is the Hash.Table API's way of signaling that the caller has already verified capacity. This is internal implementation code (not consumer-facing call sites), and the dictionary type is the direct consumer of its own hash table — the `__unchecked` is a deliberate contract between co-designed types. Whether this violates [PATTERN-017] depends on how strictly "call site" is defined versus "same-package co-designed implementation."

---

### DICT-029: Bare Methods Instead of Property.View Accessors

**Rule**: [IMPL-020] — Verb-like operation namespaces SHOULD be expressed as Property.View accessors.

Dictionary.Ordered exposes operations as bare methods:
- `dict.set("key", value)` — could be `dict.values.set("key", value)` (which exists for Copyable)
- `dict.remove("key")` — could be `dict.remove("key")` via Property.View
- `dict.clear(keepingCapacity:)` — could be `dict.remove.all()`

The `Values` accessor does provide `dict.values.set(...)` and `dict.values.remove(...)` for Copyable values. However, the base `~Copyable` methods are bare. The unordered `Dictionary` correctly uses `dict.forEach { }` via `Property.View.Read`, showing the pattern is partially adopted.

This is LOW severity because the bare method names are not compound — they are single verbs (`set`, `remove`, `clear`). The `values` accessor pattern for Copyable values already provides the nested API. The question is whether `~Copyable` operations should also go through Property.View, which may be blocked by ownership constraints.

---

### DICT-030 and DICT-031: Hand-Rolled Accessor Structs

**Rule**: [IMPL-021] — Use `Property<Tag, Base>.View` for `~Copyable` bases. MUST NOT hand-roll accessor structs.

**Merge** (Dictionary.Ordered.Merge.swift, line 52):
```swift
public struct Merge {
    @usableFromInline var dict: Dictionary<Key, Value>.Ordered
    ...
}
```

**Values** (Dictionary.Ordered.Values.swift, line 50):
```swift
public struct Values {
    @usableFromInline var dict: Dictionary<Key, Value>.Ordered
    ...
}
```

Both are hand-rolled accessor structs that store a copy of the dictionary and swap back on `_modify`. The file `Dictionary.Ordered.Merge.swift` contains a comment (lines 19-24) explaining the rationale: Property<Tag, Base> loses access to Key/Value generics.

This is INFO severity because the comment documents a principled limitation. However, the note should be verified against current Property.View.Typed capabilities — `Property.View.Typed<Element>` with `Valued<N>` now supports value-generic threading.

---

### DICT-032: Incomplete Bounded Index Flow in Static Variant

**Rule**: [IMPL-050] / [IMPL-052] — Static-capacity types MUST accept `Index<Element>.Bounded<N>` and propagate it through APIs.

The Static variant returns `Index<Key>.Bounded<capacity>?` from `index(of:)` (line 329), which is correct. However:

- `withValue(at:)` — accepts unbounded `Index<Key>`, not `Bounded<capacity>` (line 421)
- `withValue(at:)` with typed error — same, accepts unbounded `Index<Key>` (line 428)

The `set` and `remove` methods accept keys (not indices), so bounded index flow is not directly applicable to them. However, `withValue(at:)` on a static-capacity type should accept `Index<Key>.Bounded<capacity>` per [IMPL-052]. Currently it accepts unbounded `Index<Key>` and does a runtime precondition check that would be statically provable with a bounded index.

---

## Compliant Patterns (No Findings)

The following areas are well-implemented:

1. **[API-NAME-001] Nest.Name pattern**: All types follow `Dictionary.Ordered`, `Dictionary.Ordered.Bounded`, `Dictionary.Ordered.Static`, `Dictionary.Ordered.Small`, `Dictionary.Ordered.Keys`, `Dictionary.Ordered.Values`, `Dictionary.Ordered.Merge`, `Dictionary.Ordered.Merge.Keep`. No compound type names found.

2. **[IMPL-002] Typed arithmetic**: Typed operations are used consistently — `.retag(Value.self)`, `.map(Ordinal.init)`, `.subtract.saturating(.one)`, `+= .one`. No raw value arithmetic at call sites outside the `Int` boundary methods.

3. **[IMPL-003] Functor ops for domain crossing**: `.retag()` is used consistently for cross-domain index conversion (Key to Value, Key to Bit). No `__unchecked` construction for index domain crossing.

4. **[API-ERR-001] Typed throws**: All throwing functions use typed throws — `throws(Error)`, `throws(__DictionaryOrderedError<Key>)`, `throws(__DictionaryOrderedBoundedError<Key>)`.

5. **[PRIM-FOUND-001] No Foundation**: No Foundation imports anywhere.

6. **[IMPL-INTENT] Intent over mechanism**: The core dictionary operations read clearly as intent. `_keys.insert(key)`, `_values.append(value)`, `_values.remove(at:)`, `_keys.contains(key)` — all express what, not how.

7. **[API-NAME-002] Nested accessors**: The merge API correctly uses `dict.merge.keep.first(pairs)` — a three-level nested accessor that reads as intent. The `keys` and `values` accessors follow the same pattern.

8. **Error type hoisting**: The `__DictionaryOrdered*Error` types are correctly hoisted to module level with typealiases providing the `Dictionary.Ordered.Error` Nest.Name API, documented with WORKAROUND comments per [PATTERN-016].

9. **Property.View for forEach**: The unordered `Dictionary` correctly uses `Property<Sequence.ForEach, Self>.View.Read` for the forEach accessor with `callAsFunction`.

---

## Statistics

- **Total files audited**: 26
- **Total findings**: 32
- **MEDIUM**: 21 (all `Int(bitPattern:)` / raw construction at call sites)
- **LOW**: 5
- **INFO**: 6
- **Critical / High**: 0
