# Cross-Domain Init Overload Resolution Footgun

<!--
---
version: 1.0.0
last_updated: 2026-02-11
status: RECOMMENDATION
---
-->

## Context

A production test crash was discovered in `Bit.Vector.Dynamic Tests.swift` where `initRepeatingTrue` and `initRepeatingFalse` tests crashed with `signal code 5` (out-of-bounds memory access). The root cause: Swift's overload resolution silently chose a cross-domain conversion init that multiplied values by 8 instead of constructing direct bit indices.

The original test code:

```swift
for i in (0..<5).map(Bit.Index.init) {
    #expect(bits[i] == true)  // CRASH: i = 0, 8, 16, 24, 32 — not 0, 1, 2, 3, 4
}
```

Swift resolved `Bit.Index.init` to `init(_ index: Index<UInt8>)` from `Bit.Index+Byte.swift`, which converts byte positions to bit positions by multiplying by 8. The programmer intended direct ordinal construction.

**Prior art**: `blanket-tagged-init-audit.md` covers a related but distinct issue — blanket inits on `Tagged where RawValue == Ordinal` bypassing bounded type invariants. This document covers a different anti-pattern: unlabeled cross-domain conversion inits creating ambiguous overload resolution.

## Question

How should cross-domain conversion inits on Tagged types be protected from accidental overload resolution in function-reference contexts like `.map(Type.init)`?

## Analysis

### The Resolution Chain

The footgun requires three components interacting:

**Component 1 — Unlabeled cross-domain init** (`Bit.Index+Byte.swift:28-32`):

```swift
extension Bit.Index {
    @inlinable
    public init(_ index: Index_Primitives.Index<UInt8>) {
        self = .zero + Index<UInt8>.Count(index) * .bitsPerByte  // Multiplies by 8
    }
}
```

This is a legitimate byte-to-bit position conversion. Byte 1 corresponds to bit 8. The init is mathematically correct.

**Component 2 — Blanket `ExpressibleByIntegerLiteral`** (`Tagged Primitives Test Support.swift:16-21`):

```swift
extension Tagged: ExpressibleByIntegerLiteral
where Tag: ~Copyable, RawValue: ExpressibleByIntegerLiteral {
    @_disfavoredOverload
    public init(integerLiteral value: RawValue.IntegerLiteralType) {
        self = .init(__unchecked: (), RawValue(integerLiteral: value))
    }
}
```

This conformance makes ALL `Tagged<_, Ordinal>` types — including `Index<UInt8>` — accept integer literals. It exists in test support to enable convenient test expressions like `let idx: Bit.Index = 5`.

**Component 3 — Swift's literal type inference**:

When the compiler sees `(0..<5).map(Bit.Index.init)`:
1. It searches for `Bit.Index.init` overloads
2. Finds `init(_ index: Index<UInt8>)` — a non-throwing, unlabeled init
3. Since `Index<UInt8>` (= `Tagged<UInt8, Ordinal>`) conforms to `ExpressibleByIntegerLiteral` (from test support), the integer literals `0` and `5` can be inferred as `Index<UInt8>`
4. Swift infers `0..<5` as `Range<Index<UInt8>>`, not `Range<Int>`
5. Each element (0, 1, 2, 3, 4 as `Index<UInt8>`) passes through the byte-to-bit init
6. Result: bit indices 0, 8, 16, 24, 32 — out of bounds for a 5-bit vector

The crash is silent (no compiler warning), non-obvious (the code reads as "create bit indices 0-4"), and only manifests at runtime.

### Footgun Surface Area

Beyond `Bit.Index`, the same pattern could occur wherever:
- A type has an unlabeled `init(_ :)` accepting a different `Tagged` specialization
- The parameter type conforms to `ExpressibleByIntegerLiteral` (via test support)
- The init performs a non-identity transformation (scaling, wrapping, etc.)

Currently identified cross-domain conversion inits with this risk:

| Type | Init | Parameter | Transformation | Risk |
|------|------|-----------|----------------|------|
| `Bit.Index` | `init(_ index: Index<UInt8>)` | `Index<UInt8>` | ×8 (byte→bit) | **CONFIRMED** — caused crash |
| Future types | Any `init(_ : Index<Other>)` | Various | Varies | Structural risk |

The 165 `.map(Ordinal.init)` call sites in production code are a different pattern — they transform raw values within the same domain, not across domains. These are not affected by this specific footgun.

### Option A: Add Argument Label to Cross-Domain Inits

Change the unlabeled cross-domain init to require a label:

```swift
// Before:
public init(_ index: Index<UInt8>) { ... }

// After:
public init(byte index: Index<UInt8>) { ... }
```

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Prevents the footgun | Yes — `.map(Bit.Index.init)` no longer matches; requires `.map { Bit.Index(byte: $0) }` |
| Communicates intent | Yes — `byte:` makes the semantic transformation explicit |
| API clarity | Improved — the label documents that this is a domain-crossing conversion |
| Migration cost | Low — search for `Bit.Index(` with `Index<UInt8>` argument; likely very few call sites |
| Convention alignment | Yes — [API-NAME-002] already requires descriptive identifiers over compound names |
| Prevents future footguns | Partially — only fixes this specific init; doesn't establish an ecosystem-wide guard |

### Option B: Remove Blanket `ExpressibleByIntegerLiteral` from Test Support

Remove the conformance that allows `Tagged` types to be constructed from integer literals.

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Prevents the footgun | Yes — without literal conformance, Swift can't infer `Range<Index<UInt8>>` from `0..<5` |
| Communicates intent | No — removes a testing convenience without addressing the root cause |
| API clarity | No change — the unlabeled init remains ambiguous |
| Migration cost | Very high — hundreds of test files use `let idx: Bit.Index = 5` syntax |
| Convention alignment | Conflicts with [TEST-018] which explicitly provides literal conformances for tests |
| Prevents future footguns | Partially — prevents literal-inference chains but not explicit `.map(Type.init)` footguns |

### Option C: `@_disfavoredOverload` on Cross-Domain Inits

Add `@_disfavoredOverload` to the byte-to-bit conversion init.

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Prevents the footgun | Partially — Swift prefers other overloads but may still choose this one if it's the only non-throwing match |
| Communicates intent | No — `@_disfavoredOverload` is an implementation detail, not a semantic signal |
| API clarity | No change |
| Migration cost | Minimal — one annotation added |
| Convention alignment | Weak — `@_disfavoredOverload` is an underscored attribute (not part of stable API) |
| Prevents future footguns | No — disfavoring is fragile and depends on what other overloads exist |

### Option D: Ecosystem-Wide Audit of Unlabeled Cross-Domain Inits

Audit all `init(_ :)` patterns on `Tagged` types (or typealiases thereof) where the parameter type is a different `Tagged` specialization, and add argument labels to all cross-domain conversion inits.

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Prevents the footgun | Yes — systematically eliminates the anti-pattern |
| Communicates intent | Yes — labels document what each conversion does |
| API clarity | Improved across the ecosystem |
| Migration cost | Medium — requires identifying and migrating all affected call sites |
| Convention alignment | Yes — extends [PATTERN-019] (no blanket Tagged init constructors) to cover unlabeled cross-domain inits |
| Prevents future footguns | Yes — establishes a convention that cross-domain inits require labels |

### Comparison

| Criterion | A: Label this init | B: Remove literals | C: Disfavor | D: Ecosystem audit |
|-----------|-------------------|-------------------|-------------|-------------------|
| Fixes confirmed crash | Yes | Yes | Partially | Yes |
| Prevents similar future bugs | Partially | Partially | No | Yes |
| Migration cost | Low | Very High | Minimal | Medium |
| Aligns with conventions | Yes | No (conflicts [TEST-018]) | Weak | Yes |
| Documents semantic intent | Yes | No | No | Yes |

## Constraints

1. **Test support `ExpressibleByIntegerLiteral` serves a real need**: Tests need concise index construction. Removing it entirely would be a net negative. The conformance should be retained but its interaction with overload resolution must be understood.

2. **Cross-domain conversion inits are legitimate**: `Bit.Index(byte: someByteIndex)` is a valid operation. The problem is not the existence of the init but its unlabeled form enabling accidental use.

3. **`.map(Type.init)` is an idiomatic Swift pattern**: Programmers will continue to write `.map(Bit.Index.init)`. The type system should make this safe, not rely on programmer awareness.

4. **[PATTERN-019] already forbids blanket Tagged init constructors**: This footgun is a specialization of the same anti-pattern — an init that applies too broadly because it lacks sufficient constraints or labels.

## Outcome

**Status**: RECOMMENDATION

### Immediate Fix (Option A)

Add an argument label to the byte-to-bit conversion init in `Bit.Index+Byte.swift`:

```swift
// Before:
public init(_ index: Index_Primitives.Index<UInt8>) { ... }

// After:
public init(byte index: Index_Primitives.Index<UInt8>) { ... }
```

This directly fixes the confirmed crash, communicates intent, and has minimal migration cost.

### Convention Extension (Option D)

Extend [PATTERN-019] or create a new rule:

> **Cross-domain conversion inits on Tagged types MUST use argument labels.** An unlabeled `init(_ :)` where the parameter is a different `Tagged` specialization creates an overload resolution footgun: Swift's literal type inference can silently choose the cross-domain conversion over the intended direct construction, applying a hidden transformation (scaling, wrapping, etc.) to the input values.

### Anti-Pattern Documentation

Add to the implementation skill:

| You want to write | Why it's dangerous | What to write instead |
|---|---|---|
| `init(_ index: Index<Other>)` on `Tagged<Tag, Ordinal>` | Swift may infer literal type as `Index<Other>`, silently applying cross-domain transformation | `init(other index: Index<Other>)` with descriptive argument label |

### Ecosystem Audit (Future)

Conduct an audit of all unlabeled `init(_ :)` patterns on Tagged types where the parameter is a different Tagged specialization. Priority by risk:
1. Inits that perform non-identity transformations (scaling, modular arithmetic)
2. Inits where the parameter type gains `ExpressibleByIntegerLiteral` from test support
3. Inits where the parameter type is commonly used with `.map` patterns

## References

### Primary Sources
- `swift-bit-index-primitives/Sources/Bit Index Primitives/Bit.Index+Byte.swift:28-32` — cross-domain init (root cause)
- `swift-tagged-primitives/Tests/Support/Tagged Primitives Test Support.swift:16-21` — blanket `ExpressibleByIntegerLiteral` (enabler)
- `swift-bit-vector-primitives/Tests/Bit Vector Primitives Tests/Bit.Vector.Dynamic Tests.swift` — crash site (fixed)

### Prior Art
- `Research/blanket-tagged-init-audit.md` — related anti-pattern (blanket inits bypassing bounded invariants)

### Convention References
- [API-NAME-002] — no compound identifiers; descriptive argument labels
- [PATTERN-019] — no blanket Tagged init constructors
- [TEST-018] — literal conformances for test support
- [IMPL-000] — call-site-first design
