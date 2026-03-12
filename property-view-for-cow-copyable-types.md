# Property for @CoW Copyable Types

<!--
---
version: 2.0.0
last_updated: 2026-03-12
status: DECISION
supersedes: v1.0.0 (which incorrectly recommended Property.View)
---
-->

## Context

During verb-as-property refactoring of `PDF.Context` (a `@CoW public struct`), a conflict emerged between [IMPL-021] and practical requirements. [IMPL-021] states:

- Copyable → `Property<Tag, Base>`
- ~Copyable → `Property<Tag, Base>.View`

All operations on `PDF.Context` (emit, flush, advance, page) are **mutating**. The question: does `Property(self)` on a `@CoW` type trigger unnecessary deep copies?

## Analysis

### Property.View is compiler-rejected for Copyable types

`Property.View` is defined in `extension Property where Base: ~Copyable` as `~Copyable, ~Escapable`. The compiler rejects `mutating _read` returning a `~Escapable` result for Copyable base types:

```
error: a mutating method cannot return a ~Escapable result
```

This is not a convention — it's a **language constraint**. Property.View cannot be used with Copyable types.

### Property with _modify avoids CoW overhead

The CoW Mutation Recipe (documented in `Property.swift` lines 116-131):

```swift
var emit: Property<Emit, Self> {
    _modify {
        var property = Property(self)   // 8-byte ref copy, refcount → 2
        self = Self._transferDummy      // release self's ref, refcount → 1
        defer { self = property.base }  // restore on exit
        yield &property
    }
}
```

After `self = _transferDummy`, the original storage's refcount is 1 (only property holds it). When `@CoW`'s auto-generated setters call `ensureUnique()`, `isKnownUniquelyReferenced` returns true → no deep copy.

### @CoW's ensureUnique() is private — and that's fine

`@CoW` generates `private mutating func ensureUnique()` called automatically by every property setter. The CoW Mutation Recipe's `makeUnique()` step is for containers with public uniqueness methods. For `@CoW` types, the transfer pattern (`self = dummy`) achieves the same effect: refcount = 1 during yield.

### Nested _modify for cross-accessor calls

Property extensions may call other Property accessors (e.g., `emit.line()` calls `base.flush.text()`). Each level creates its own Property, transfers, and restores via defer. No exclusivity violation: each `_modify` coroutine operates on distinct memory (the outer yields `&property._base`, the inner creates a fresh Property from that reference). Cost: ~4 ARC operations per nesting level (~4ns on modern hardware).

## Outcome

**Status**: DECISION

**[IMPL-021] is correct as written.** `Property<Tag, Base>` for Copyable types, `Property.View` for ~Copyable types. The CoW Mutation Recipe in `_modify` accessors prevents unnecessary deep copies. No rule change needed.

| Base type | Use |
|-----------|-----|
| Copyable (including @CoW) | `Property<Tag, Base>` with `_modify` + transfer |
| ~Copyable | `Property<Tag, Base>.View` |

For read-only access, provide `get { Property(self) }` alongside `_modify`. The compiler selects `get` for reads (cheap 8-byte copy) and `_modify` for mutations (transfer pattern).

## References

- `Property.swift` lines 116-131 — CoW Mutation Recipe
- `@CoW` macro — `swift-copy-on-write/Sources/Copy on Write Macros/CoWMacro.swift`
- `PDF.Context` — `swift-pdf-rendering/Sources/PDF Rendering/PDF.Context.swift`
