# Cardinal Clamping Init from Int

<!--
---
version: 1.0.0
last_updated: 2026-02-10
status: SUPERSEDED
---
-->

## Context

The buffer layer makeover (stack and heap primitives) introduced `truncate(to newCount: Int)` methods that must convert a signed `Int` to a typed `Index.Count` (i.e., `Tagged<Tag, Cardinal>`). Negative values must clamp to zero since a negative count is meaningless.

Every call site currently writes the same 3-operation chain:

```swift
let targetCount = Index.Count(UInt(Swift.max(0, newCount)))
```

This pattern appears at 12 sites across 2 packages (11 truncate + 1 reserveCapacity). The `Swift.max(0, x)` is necessary because `UInt(Int)` traps on negative input.

The existing `Int(clamping: Cardinal)` provides the reverse direction: large cardinal clamped to `Int.max`. The forward direction — negative int clamped to zero — is missing.

## Question

What is the ideal call-site syntax for converting a signed `Int` to `Tagged<Tag, Cardinal>` with negative-to-zero clamping, and where should the implementation live?

## Analysis

### Option A: `Cardinal(clamping: Int)` + `Tagged(clamping: Int)`

Add clamping inits at both layers, mirroring the existing reverse direction.

Call site:
```swift
let targetCount = Index.Count(clamping: newCount)
```

Implementation (two layers):
```swift
// Cardinal Primitives Core — Int+Cardinal.swift
extension Cardinal {
    public init(clamping value: Int) {
        self.init(UInt(Swift.max(0, value)))
    }
}

// Cardinal Primitives — Tagged+Cardinal.swift
extension Tagged where RawValue == Cardinal, Tag: ~Copyable {
    public init(clamping int: Int) {
        self.init(Cardinal(clamping: int))
    }
}
```

### Option B: Only `Cardinal(clamping: Int)`, reuse existing `Tagged(_ cardinal: Cardinal)`

Add clamping only at `Cardinal` level. Call sites use existing `Tagged(Cardinal(...))`.

Call site:
```swift
let targetCount = Index.Count(Cardinal(clamping: newCount))
```

### Option C: Status quo — `Swift.max` at each call site

No infrastructure change. Each site continues writing `Index.Count(UInt(Swift.max(0, newCount)))`.

### Comparison

| Criterion | A: Both layers | B: Cardinal only | C: Status quo |
|-----------|---------------|-------------------|---------------|
| Call-site clarity | `Index.Count(clamping: newCount)` | `Index.Count(Cardinal(clamping: newCount))` | `Index.Count(UInt(Swift.max(0, newCount)))` |
| Mechanism visible | No | Partially | Yes |
| Number of sites changed | 1 impl, 12 call sites | 1 impl, 12 call sites | 0 |
| Symmetry with `Int(clamping:)` | Full | Partial | None |
| [IMPL-002] compliance | Perfect | Imperfect (intermediate Cardinal) | Violation (mechanism at call site) |
| [IMPL-010] compliance | Perfect (boundary invisible) | Acceptable | Violation (Int escape at call site) |

## Outcome

**Status**: DECISION

**Option A**: Add `Cardinal(clamping: Int)` and `Tagged(clamping: Int)` at both layers.

Rationale:

1. **Symmetry**: `Int(clamping: Cardinal)` already exists. `Cardinal(clamping: Int)` is its natural dual.
2. **[IMPL-010]**: The Int-to-typed boundary becomes invisible at call sites.
3. **[IMPL-002]**: Call sites express intent (`clamping:`) not mechanism (`UInt(Swift.max(0, ...))`).
4. **Single implementation**: The `Swift.max(0, x)` logic lives in one place, once, forever. 12+ call sites benefit.

The `clamping:` label is self-documenting: it tells the reader that negative values are mapped to zero, matching the established Swift convention (`UInt(clamping: -5) == 0`).

## Superseded

This decision was superseded before implementation. The real fix is to change
`truncate(to:)` from `Int` to typed `Index.Count` parameter, eliminating the
boundary conversion entirely. The `Int` parameter was the design smell —
`clamping:` was a band-aid. With a typed parameter, no conversion is needed
at all, and test call sites use `ExpressibleByIntegerLiteral` from Test Support
([TEST-018]).

## References

- `Int+Cardinal.swift` line 57: `Int(clamping: Cardinal)` — the existing reverse direction
- `Tagged+Cardinal.swift` line 67: `Int(clamping: Tagged<Tag, Cardinal>)` — tagged reverse direction
- [IMPL-010]: Push Int to the Edge
- [IMPL-002]: Write the Math, Not the Mechanism
