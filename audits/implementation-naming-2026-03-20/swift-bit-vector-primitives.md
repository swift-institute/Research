# swift-bit-vector-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (Opus 4.6)
**Skills**: implementation, naming
**Scope**: All 82 `.swift` files in `Sources/`
**Status**: READ-ONLY audit

---

## Summary Table

| ID | Severity | Rule | File(s) | Description |
|----|----------|------|---------|-------------|
| BV-001 | MEDIUM | [API-NAME-002] | Protocol.swift | `setWord(at:to:)` is a compound method name |
| BV-002 | COMPLIANT | [IMPL-024] | Protocol+defaults.swift | `clearAll(_:)` and `setAll(_:)` — compound statics are allowed per IMPL-024 |
| BV-003 | MEDIUM | [API-NAME-002] | Protocol+defaults.swift | `allFalse` and `allTrue` are compound property names |
| BV-004 | MEDIUM | [API-NAME-002] | Protocol+defaults.swift | `popFirst()` is compound; should be `package` (public API is `pop.first()`) |
| BV-005 | MEDIUM | [API-NAME-002] | Protocol.swift | `bitCapacity` is a compound property name |
| BV-006 | MEDIUM | [API-NAME-002] | Protocol+defaults.swift | `wordCount` is a compound property name |
| BV-007 | MEDIUM | [API-NAME-002] | Bounded/Inline/Dynamic+growth.swift | `popLast()` is a compound method name |
| BV-008 | MEDIUM | [API-NAME-002] | Bounded/Inline/Dynamic+growth.swift | `removeLast()` is a compound method name |
| BV-009 | MEDIUM | [API-NAME-002] | Bounded/Inline/Dynamic+growth.swift | `removeAll()` is a compound method name |
| BV-010 | MEDIUM | [API-NAME-002] | Bounded/Inline+mutating.swift | `setAll()` compound instance method duplicates protocol-level `set.all()` |
| BV-011 | MEDIUM | [API-NAME-002] | Bit.Vector.swift | `withUnsafeWords(_:)` and `withUnsafeMutableWords(_:)` are compound names |
| BV-012 | LOW | [IMPL-010] | 10 locations across modules | `Int(bitPattern:)` at non-boundary call sites |
| BV-013 | LOW | [PATTERN-021] | Dynamic+ones.swift:49, Dynamic+zeros.swift:51 | `__unchecked` construction instead of typed arithmetic |
| BV-014 | MEDIUM | [IMPL-026] | Dynamic+ones.swift, Dynamic+zeros.swift | Dynamic uses per-type Property.View for ones/zeros; diverges from shared sequence pattern |
| BV-015 | INFO | [IMPL-026] | Bounded/Dynamic/Inline .All.swift | Inconsistent Property pattern for `all` across variants |
| BV-016 | COMPLIANT | [IMPL-033] | Protocol+defaults.swift | Raw `for i in 0..<N` loops — acceptable inside infrastructure implementation |
| BV-017 | INFO | [IMPL-050] | Inline.swift, Static.swift | Static-capacity types accept unbounded `Bit.Index` (bounded infrastructure gap) |
| BV-018 | INFO | [API-IMPL-005] | Bounded/Inline/Dynamic+Sequence.swift | Iterator defined in conformance file (acceptable convention) |
| BV-019 | COMPLIANT | [API-NAME-002] | All Sequence types | `makeIterator()`, `nextSpan()` — stdlib-mandated compound names |
| BV-020 | LOW | [IMPL-033] | Dynamic+ones.swift, Dynamic+zeros.swift | Manual enumerated() + while loop reimplements iteration available via sequence types |
| BV-021 | MEDIUM | [IMPL-INTENT] | Protocol+set.range.swift, Protocol+clear.range.swift | Mask computation reads as mechanism (acceptable for infrastructure) |
| BV-022 | LOW | [IMPL-002] | Dynamic+ones.swift:41, Dynamic+zeros.swift:42 | `Int(clamping:)` extracts typed count to raw Int |
| BV-023 | INFO | [IMPL-026] | Bounded/Inline+mutating.swift | `setAll()` duplicated instead of delegating to protocol static |
| BV-024 | MEDIUM | [IMPL-026] | Bounded/Dynamic/Inline .Statistic.swift | Identical semantics with inconsistent Property patterns across variants |

---

## Findings

### BV-001: `setWord(at:to:)` compound method name [MEDIUM]

**Rule**: [API-NAME-002] Methods MUST NOT use compound names.

**Location**: `Bit Vector Primitives Core/Bit.Vector.Protocol.swift:44`

```swift
mutating func setWord(at index: Int, to value: UInt)
```

Protocol requirement used across all 5 conformers. The name `setWord` combines verb+noun. The companion getter is `word(at:)`. Since `set` already exists as a Property.View tag for bit-level operations, disambiguation would be needed.

**Recommendation**: Consider a word-level subscript or `word.set(at:to:)` pattern.

---

### BV-002: `clearAll(_:)` and `setAll(_:)` compound statics [COMPLIANT]

**Rule**: [IMPL-024] allows compound names in the static implementation layer.

**Location**: `Bit Vector Primitives Core/Bit.Vector.Protocol+defaults.swift:70,81`

```swift
public static func clearAll(_ vector: inout Self)
public static func setAll(_ vector: inout Self)
```

These are static methods serving as core logic per [IMPL-023]. The public API uses `clear.all()` and `set.all()` via Property.View. Compound names in the static layer are explicitly allowed.

---

### BV-003: `allFalse` and `allTrue` compound property names [MEDIUM]

**Rule**: [API-NAME-002]

**Location**: `Bit Vector Primitives Core/Bit.Vector.Protocol+defaults.swift:48,57`

```swift
public var allFalse: Bool
public var allTrue: Bool
```

Compound properties on the protocol. Container variants already provide the correct `all.true` / `all.false` pattern. These are used internally by `isEmpty`/`isFull` on Bit.Vector and Bit.Vector.Static.

**Recommendation**: Make `package` visibility. Add `all.true`/`all.false` to Bit.Vector and Static, matching container variants.

---

### BV-004: `popFirst()` compound method — public but should be package [MEDIUM]

**Rule**: [API-NAME-002]

**Location**: `Bit Vector Primitives Core/Bit.Vector.Protocol+defaults.swift:105`

```swift
public mutating func popFirst() -> Bit.Index?
```

The public API correctly delegates to `pop.first()` via Property.View. But `popFirst()` is also `public`, so consumers can call the compound name directly.

**Recommendation**: Change to `package` visibility.

---

### BV-005: `bitCapacity` compound property name [MEDIUM]

**Rule**: [API-NAME-002]

**Location**: `Bit Vector Primitives Core/Bit.Vector.Protocol.swift:38`

```swift
var bitCapacity: Bit.Index.Count { get }
```

Combines `bit` + `capacity`. Since `Bit.Vector.Protocol` already establishes the bit-vector domain, `capacity` alone would suffice as the requirement name.

---

### BV-006: `wordCount` compound property name [MEDIUM]

**Rule**: [API-NAME-002]

**Location**: `Bit Vector Primitives Core/Bit.Vector.Protocol+defaults.swift:22`

```swift
public var wordCount: Int
```

Combines `word` + `count`. Consider `words.count` pattern.

---

### BV-007 through BV-009: Container compound methods [MEDIUM]

**Rule**: [API-NAME-002]

**Locations**: Bounded/Inline/Dynamic `+growth.swift`

```swift
public mutating func popLast() -> Bool?     // BV-007
public mutating func removeLast()            // BV-008
public mutating func removeAll()             // BV-009
```

Compound method names. Should be `pop.last()`, `remove.last()`, `remove.all()` via Property.View. Note: these mirror stdlib `Array` conventions, creating a tension between ecosystem convention and [API-NAME-002].

**Recommendation**: Add Property.View accessors and make compound variants `package`.

---

### BV-010: `setAll()` instance method duplicates `set.all()` [MEDIUM]

**Rule**: [API-NAME-002]

**Locations**: `Bounded+mutating.swift:49`, `Inline+mutating.swift:49`

```swift
public mutating func setAll()
```

The protocol already provides `set.all()` via Property.View. These instance methods duplicate the operation with a compound name AND reimplement the word-level loop instead of delegating to `Self.setAll(&self)`.

**Recommendation**: Remove or make `package`. The protocol-provided `set.all()` should be the sole public API.

---

### BV-011: `withUnsafeWords` / `withUnsafeMutableWords` [MEDIUM]

**Rule**: [API-NAME-002]

**Location**: `Bit Vector Primitives Core/Bit.Vector.swift:130,139`

```swift
public func withUnsafeWords<R>(_ body: ...) -> R
public func withUnsafeMutableWords<R>(_ body: ...) -> R
```

Compound names. Follows stdlib `withUnsafe*` convention. Only on Bit.Vector (not containers).

**Recommendation**: Low priority given stdlib precedent.

---

### BV-012: `Int(bitPattern:)` at non-boundary call sites [LOW]

**Rule**: [IMPL-010]

**Locations** (10 instances):
- `Protocol+defaults.swift:23` — `wordCount` computation
- `Protocol+set.range.swift:31-32` — word index extraction
- `Protocol+clear.range.swift:31-32` — word index extraction
- `Dynamic+growth.swift:22` — word index comparison
- `Dynamic+growth.swift:84` — word count in `resize`
- `Dynamic+conversions.swift:34` — `reserveCapacity`
- `Inline.swift:84` — word count in init
- `Bounded.swift:93` — word count in init

These convert typed counts to stdlib `Int` for interop with `ContiguousArray`, `InlineArray`, and pointer APIs. They occur inside implementation methods, not at consumer call sites.

**Verdict**: Defensible — these are stdlib interop boundaries inside infrastructure code.

---

### BV-013: `__unchecked` construction at call sites [LOW]

**Rule**: [PATTERN-021]

**Locations**: `Dynamic+ones.swift:49`, `Dynamic+zeros.swift:51`

```swift
body(Bit.Index(__unchecked: (), Ordinal(UInt(globalIndex))))
```

Constructs `Bit.Index` via `__unchecked` from raw Int arithmetic. Other variants use typed `Bit.Pack.Location` for index computation.

**Recommendation**: Align with typed pattern used by other variants. Would be eliminated by BV-014.

---

### BV-014: Dynamic ones/zeros diverges from shared sequence pattern [MEDIUM]

**Rule**: [IMPL-026]

**Locations**: `Dynamic+ones.swift`, `Dynamic+zeros.swift`

All other variants provide `ones`/`zeros` as dedicated Sequence types (`Ones.Bounded`, `Zeros.Inline`, etc.). Dynamic provides Property.View accessors with hand-rolled `forEach` methods only.

**Impact**: Dynamic `ones`/`zeros` provides only `forEach`, not the full `Sequence` protocol. Consumers cannot use `map`, `filter`, `for-in`, `reduce` on `dynamic.ones`. This is a capability gap.

**Recommendation**: Create `Bit.Vector.Ones.Dynamic` and `Bit.Vector.Zeros.Dynamic` sequence types, or return `Ones.Bounded`/`Zeros.Bounded` types (Dynamic stores `ContiguousArray<UInt>` like Bounded).

---

### BV-015: Inconsistent Property pattern for `all` across variants [INFO]

**Rule**: [IMPL-026]

- **Bounded**: `Property<All, Self>` (owned, Copyable)
- **Dynamic**: `Property<All, Self>` (owned, Copyable)
- **Inline**: `Property.View.Typed.Valued` (pointer-based)

Identical semantics, different patterns.

---

### BV-017: Static-capacity types accept unbounded `Bit.Index` [INFO]

**Rule**: [IMPL-050]

`Bit.Vector.Static<N>` and `Bit.Vector.Inline<N>` have compile-time capacity but accept unbounded `Bit.Index` in subscripts. Infrastructure gap — `Bit.Index.Bounded<N>` does not yet exist.

---

### BV-020: Dynamic ones/zeros reimplements iteration with raw arithmetic [LOW]

**Rule**: [IMPL-033]

**Locations**: `Dynamic+ones.swift:44-53`, `Dynamic+zeros.swift:45-55`

```swift
for (wordIndex, var word) in storage.enumerated() {
    while word != 0 {
        let bitIndex = word.trailingZeroBitCount
        let globalIndex = wordIndex * bitsPerWord + bitIndex
```

Raw `Int` arithmetic where other variants use typed `Bit.Pack.Location` + `location.index(bitsPerWord:)`. Would be eliminated by BV-014.

---

### BV-021: Range set/clear mask computation reads as mechanism [MEDIUM]

**Rule**: [IMPL-INTENT]

**Locations**: `Protocol+set.range.swift:23-52`, `Protocol+clear.range.swift:23-53`

Dense bit-manipulation logic for mask computation. The intent IS expressed at the call site (`set.range(r)` / `clear.range(r)`). The mechanism inside infrastructure is acceptable per [IMPL-033].

**Recommendation**: Consider extracting mask computation into a named helper on `Bit.Pack`.

---

### BV-022: `Int(clamping:)` extracts typed count to raw Int [LOW]

**Rule**: [IMPL-002]

**Locations**: `Dynamic+ones.swift:41`, `Dynamic+zeros.swift:42`

```swift
let countInt = Int(clamping: count)
```

Typed `Bit.Index.Count` extracted to raw `Int` for comparison. Would be eliminated by BV-014.

---

### BV-023: `setAll()` duplicated on Bounded and Inline [INFO]

**Rule**: [IMPL-026]

**Locations**: `Bounded+mutating.swift:49-62`, `Inline+mutating.swift:49-62`

Nearly identical implementations. Protocol provides `static func setAll(_:)` and `set.all()`. These should delegate to the static.

---

### BV-024: Inconsistent Property pattern for Statistic [MEDIUM]

**Rule**: [IMPL-026]

- **Bounded**: `Property<Statistic, Self>` (owned)
- **Dynamic**: `Property<Statistic, Self>` (owned)
- **Inline**: `Property.View.Typed.Valued` (pointer-based)

Identical semantics (`popcount` and `_count.subtract.saturating(popcount)`) from protocol-accessible properties. Could be unified at protocol level.

---

## Structural Assessment

### What works well

1. **Type naming**: All types follow `Nest.Name` perfectly. `Bit.Vector.Static`, `Bit.Vector.Bounded`, `Bit.Vector.Ones.Static.Iterator`. Zero compound TYPE names. Full [API-NAME-001] compliance.

2. **One type per file**: Full [API-IMPL-005] compliance across all 82 files.

3. **Property.View for ~Copyable protocol**: `set`, `clear`, `pop` on `Bit.Vector.Protocol` use Property.View with protocol-constrained extensions per [IMPL-026]. Exemplary.

4. **Typed throws**: All throwing functions use typed throws. Full [API-ERR-001] compliance.

5. **Error type hoisting**: `__BitVector*Error` types hoisted for typed throws compatibility. Correct pattern.

6. **Ones/Zeros sequence architecture**: Dedicated sequence types with Wegner/Kernighan iterators using typed arithmetic (except Dynamic).

7. **Bit.Pack.Location**: Typed word/bit decomposition throughout (except Dynamic ones/zeros).

### Primary improvement areas

1. **Compound method names** (BV-001, BV-003-011): ~15 compound public methods/properties. Most have Property.View equivalents; compound names should become `package` visibility.

2. **Dynamic variant divergence** (BV-013, BV-014, BV-020, BV-022): Dynamic ones/zeros bypasses typed arithmetic and sequence patterns used by all other variants.

3. **Property pattern inconsistency** (BV-015, BV-024): Three different Property patterns for identical semantics across Bounded, Dynamic, and Inline.

---

## Statistics

- **Files audited**: 82
- **Total findings**: 24
- **MEDIUM**: 12 (compound names: 10, implementation divergence: 2)
- **LOW**: 5
- **INFO**: 4
- **COMPLIANT (with note)**: 3
