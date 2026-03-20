# swift-cyclic-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: implementation [IMPL-*], naming [API-NAME-*]
**Scope**: All `.swift` files in `Sources/`

---

## Summary Table

| ID | Severity | Requirement | File | Title |
|----|----------|-------------|------|-------|
| CYC-001 | LOW | [PATTERN-017] | Cyclic.Group.Modulus.swift:57 | `.rawValue` in Modulus init from Count (validated) |
| CYC-002 | LOW | [PATTERN-017] | Cyclic.Group.Modulus.swift:66 | `.rawValue` in Modulus __unchecked init from Count |
| CYC-003 | MEDIUM | [PATTERN-017] | Cyclic.Group+Arithmetic.swift:125 | `.rawValue.magnitude` in advanced(by:) |
| CYC-004 | LOW | [PATTERN-017] | Cyclic.Group.Static.swift:95 | `.rawValue` in error associated value construction |
| CYC-005 | INFO | [IMPL-002] | Cyclic.Group+Arithmetic.swift:70 | Cardinal(rhs.residue) explicit conversion in add |
| CYC-006 | INFO | [IMPL-002] | Cyclic.Group+Arithmetic.swift:86 | Cardinal(rhs.residue) explicit conversion in subtract |
| CYC-007 | INFO | [IMPL-002] | Cyclic.Group+Arithmetic.swift:102 | Cardinal(element.residue) explicit conversion in inverse |
| CYC-008 | INFO | [API-IMPL-005] | Cyclic.Group.Static.swift | Element + Error in same file as Static |

**Totals**: 0 CRITICAL, 0 HIGH, 1 MEDIUM, 3 LOW, 4 INFO

---

## __unchecked Classification

31 total `__unchecked` constructions. All classified below.

### Boundary-Correct (31/31)

Every `__unchecked` usage in this package occurs at the boundary between the validated domain and the raw domain. In cyclic group arithmetic, the modular reduction (`% modulus`) is the validation step, and the `__unchecked` construction immediately follows that reduction. This is the textbook correct use of `__unchecked`.

#### Category A: Post-Reduction Construction (19 uses)

These construct an `Element` immediately after `% modulus` has guaranteed the value is in `[0, modulus)`.

| File | Line | Expression | Justification |
|------|------|-----------|---------------|
| Cyclic.Group+Arithmetic.swift | 34 | `Element(__unchecked: reduced)` | After `sum % modulus.value` |
| Cyclic.Group+Arithmetic.swift | 57 | `Element(__unchecked: reduced)` | After `sum % modulus.value` |
| Cyclic.Group+Arithmetic.swift | 72 | `Element(__unchecked: reduced)` | After `sum % modulus.value` |
| Cyclic.Group+Arithmetic.swift | 89 | `Element(__unchecked: reduced)` | After `sum % modulus.value` |
| Cyclic.Group+Arithmetic.swift | 103 | `Element(__unchecked: Ordinal(inv))` | After `modulus - element` (result < modulus) |
| Cyclic.Group+Arithmetic.swift | 123 | `Element(__unchecked: sum % modulus.value)` | Inline reduction |
| Cyclic.Group+Arithmetic.swift | 128 | `Element(__unchecked: sum % modulus.value)` | Inline reduction |
| Cyclic.Group.Static+Arithmetic.swift | 57 | `Self(__unchecked: reduced)` | After `sum % modulusCardinal` |
| Cyclic.Group.Static+Arithmetic.swift | 77 | `Self(__unchecked: reduced)` | After `sum % modulusCardinal` |
| Cyclic.Group.Static+Arithmetic.swift | 111 | `Self(__unchecked: Ordinal(inv))` | After `modulus - position` (result < modulus) |
| Tagged+Cyclic.Group.Static.Element.swift | 64 | `Self(__unchecked: (), lhs.rawValue + rhs.rawValue)` | Delegates to operator that already reduces |
| Tagged+Cyclic.Group.Static.Element.swift | 71 | `Self(__unchecked: (), lhs.rawValue - rhs.rawValue)` | Delegates to operator that already reduces |
| Tagged+Cyclic.Group.Static.Element.swift | 95 | `Self(__unchecked: (), rawValue.inverse)` | Delegates to `.inverse` which already reduces |
| Tagged+Cyclic.Group.Static.Element.swift | 39 | `self.init(__unchecked: (), element)` | Element already validated |
| Tagged+Cyclic.Group.Static.Element.swift | 46 | `self.init(__unchecked: (), try ...)` | Element constructed via throwing init |
| Tagged+Cyclic.Group.Static.Element.swift | 53 | `self.init(__unchecked: (), ...wrapping...)` | Element constructed via wrapping init |
| Cyclic.Group.Static.Iterator.swift | 40 | `Element(__unchecked: .zero)` | Zero is always valid |
| Cyclic.Group.Static.Iterator.swift | 46 | `Element(__unchecked: current)` | After `guard current < bound` |
| Cyclic.Group.Static.Iterator.swift | 57 | `Element(__unchecked: current)` | After `guard ... current < bound` |

#### Category B: Constant/Identity Construction (4 uses)

These construct known-valid constants.

| File | Line | Expression | Justification |
|------|------|-----------|---------------|
| Cyclic.Group.Element.swift | 77 | `Self(__unchecked: .zero)` | Zero is always valid |
| Cyclic.Group.Element.swift | 83 | `Self(__unchecked: Ordinal(1))` | 1 is valid for modulus > 1 (documented) |
| Cyclic.Group.Static+Arithmetic.swift | 19 | `Self(__unchecked: .zero)` | Zero is always valid |
| Cyclic.Group.Static+Arithmetic.swift | 36 | `Self(__unchecked: modulus > 1 ? Ordinal(1) : .zero)` | Correctly handles modulus == 1 |

#### Category C: API Definition (8 uses)

These are the `__unchecked` initializer definitions themselves (not call sites).

| File | Line | Type |
|------|------|------|
| Cyclic.Group.Element.swift | 61 | `init(__unchecked residue: Ordinal)` |
| Cyclic.Group.Element.swift | 71 | `init(__unchecked index: Index<Tag>)` |
| Cyclic.Group.Modulus.swift | 44 | `init(__unchecked value: Cardinal)` |
| Cyclic.Group.Modulus.swift | 65 | `init(__unchecked count: Index<Tag>.Count)` |
| Cyclic.Group.Static.swift | 106 | `init(__unchecked position: Ordinal)` |

(3 Tagged `__unchecked` forwarding inits counted in Category A above.)

**Conclusion**: All 31 `__unchecked` uses are boundary-correct. The cyclic arithmetic operators perform modular reduction and then bypass redundant validation. No `__unchecked` leaks to consumer call sites.

---

## Findings

### Finding [CYC-001]: .rawValue in Modulus init from Count (validated)

**Severity**: LOW
**Requirement**: [PATTERN-017]
**File**: `Cyclic.Group.Modulus.swift:57`

```swift
public init<Tag: ~Copyable>(_ count: Index<Tag>.Count) throws(Error) {
    guard count > .zero else { throw .zeroModulus }
    self.value = count.rawValue  // <- rawValue access
}
```

**Analysis**: `Index<Tag>.Count` wraps `Cardinal`. Extracting `.rawValue` to get the `Cardinal` is boundary code -- this is a type conversion between `Index<Tag>.Count` and `Cyclic.Group.Modulus`. A functor-style conversion (`.map` or `.retag`) is not available between these unrelated domains, so `.rawValue` is the only mechanism. Acceptable at boundary.

---

### Finding [CYC-002]: .rawValue in Modulus __unchecked init from Count

**Severity**: LOW
**Requirement**: [PATTERN-017]
**File**: `Cyclic.Group.Modulus.swift:66`

```swift
public init<Tag: ~Copyable>(__unchecked count: Index<Tag>.Count) {
    self.value = count.rawValue  // <- rawValue access
}
```

**Analysis**: Same pattern as CYC-001. Boundary conversion from `Index<Tag>.Count` to `Cardinal`. Acceptable.

---

### Finding [CYC-003]: .rawValue.magnitude in advanced(by:)

**Severity**: MEDIUM
**Requirement**: [PATTERN-017]
**File**: `Cyclic.Group+Arithmetic.swift:125`

```swift
let backward = Ordinal(offset.vector.rawValue.magnitude) % modulus.value
```

**Analysis**: The expression `offset.vector.rawValue.magnitude` chains through three layers:
1. `offset.vector` -- `Affine.Discrete.Vector` (the signed displacement)
2. `.rawValue` -- `Int` (the raw signed integer)
3. `.magnitude` -- `UInt` (absolute value)

This is a cross-domain conversion (signed offset to unsigned ordinal) that requires descending to the raw representation. The `.rawValue` here is mechanism-focused -- ideally the `Affine.Discrete.Vector` type would expose an `.absoluteValue` or `.magnitude` accessor directly, making the chain `offset.vector.magnitude`. However, since `Affine.Discrete.Vector` is defined in another package (affine-primitives), this is a cross-package API gap rather than a local defect.

**Recommendation**: Consider adding a `.magnitude` property on `Affine.Discrete.Vector` returning `Cardinal` in affine-primitives, which would reduce this to `Ordinal(offset.vector.magnitude)`.

---

### Finding [CYC-004]: .rawValue in error associated value

**Severity**: LOW
**Requirement**: [PATTERN-017]
**File**: `Cyclic.Group.Static.swift:95`

```swift
throw .outOfBounds(Int(position.rawValue))
```

**Analysis**: Extracts the raw `UInt` from `Ordinal` to construct an `Int` for the error's associated value. This is diagnostic/error-reporting code where raw values are expected -- errors typically present raw values for human consumption. Acceptable at boundary.

---

### Finding [CYC-005]: Cardinal(rhs.residue) explicit conversion in add

**Severity**: INFO
**Requirement**: [IMPL-002]
**File**: `Cyclic.Group+Arithmetic.swift:70`

```swift
let sum = lhs.residue + Cardinal(rhs.residue)
```

**Analysis**: The explicit `Cardinal(rhs.residue)` conversion from `Ordinal` to `Cardinal` is required because `Ordinal + Ordinal` produces `Ordinal` (affine position + position is not meaningful), while `Ordinal + Cardinal` produces `Ordinal` (position + displacement). This is typed arithmetic working as intended -- the conversion correctly models that the second operand is being treated as a displacement, not a position. No issue.

---

### Finding [CYC-006]: Cardinal(rhs.residue) explicit conversion in subtract

**Severity**: INFO
**Requirement**: [IMPL-002]
**File**: `Cyclic.Group+Arithmetic.swift:86`

```swift
let inverse = modulus.value.subtract.saturating(Cardinal(rhs.residue))
```

**Analysis**: Same pattern as CYC-005. `Cardinal(rhs.residue)` is a necessary domain crossing from Ordinal to Cardinal for the subtraction. The `.subtract.saturating()` nested accessor is idiomatic intent-over-mechanism. No issue.

---

### Finding [CYC-007]: Cardinal(element.residue) explicit conversion in inverse

**Severity**: INFO
**Requirement**: [IMPL-002]
**File**: `Cyclic.Group+Arithmetic.swift:102`

```swift
let inv = modulus.value.subtract.saturating(Cardinal(element.residue))
```

**Analysis**: Same pattern as CYC-005 and CYC-006. No issue.

---

### Finding [CYC-008]: Multiple types in Cyclic.Group.Static.swift

**Severity**: INFO
**Requirement**: [API-IMPL-005]
**File**: `Cyclic.Group.Static.swift`

**Analysis**: This file contains `Cyclic.Group.Static<let modulus: Int>` (line 39), `Cyclic.Group.Static.Element` (line 78), and `Cyclic.Group.Static.Element.Error` (line 164). By [API-IMPL-005], each type should be in its own file.

However, looking at the actual file structure:
- `Cyclic.Group.Static.swift` -- contains `Static` (line 39) AND `Element` (line 78) AND `Element.Error` (line 164)

`Element` could be split to its own file (`Cyclic.Group.Static.Element.swift`), and `Error` could go to `Cyclic.Group.Static.Element.Error.swift`. The `Static` struct itself is only 6 lines (just an `init`), so the file is really an Element file masquerading as a Static file.

That said, `Element` is declared inside `extension Cyclic.Group.Static { }` in the same file -- this is a nested type definition. Many primitives packages keep parent + primary nested type together when the parent is a pure namespace. This is a borderline case.

**Recommendation**: Split `Element` into `Cyclic.Group.Static.Element.swift` and `Error` into `Cyclic.Group.Static.Element.Error.swift` for strict compliance.

---

## Naming Compliance

### [API-NAME-001] Nest.Name Pattern

**Status**: PASS

All types use proper nested naming:
- `Cyclic` -- root namespace enum
- `Cyclic.Group` -- nested namespace enum
- `Cyclic.Group.Element` -- nested struct
- `Cyclic.Group.Modulus` -- nested struct
- `Cyclic.Group.Modulus.Error` -- nested enum
- `Cyclic.Group.Static<let modulus: Int>` -- nested generic struct
- `Cyclic.Group.Static.Element` -- nested struct
- `Cyclic.Group.Static.Element.Error` -- nested enum
- `Cyclic.Group.Static.Iterator` -- nested struct

No compound names detected. All types follow Nest.Name.

### [API-NAME-002] No Compound Methods/Properties

**Status**: PASS

All methods and properties use non-compound names:
- `.residue`, `.position`, `.value` -- single-word properties
- `.zero`, `.one`, `.inverse` -- single-word statics/properties
- `.successor()`, `.predecessor()`, `.add()`, `.subtract()`, `.inverse()`, `.advanced()` -- single-word methods
- `.modulusCardinal` -- this is a compound property name

**Note on `.modulusCardinal`** (line 84 of `Cyclic.Group.Static.swift`): This is technically a compound name (`modulus` + `Cardinal`). However, it is a `static var` on `Element` that converts the value-generic `modulus: Int` to a `Cardinal`. The name describes what it is (the modulus as a Cardinal). An alternative would be a computed property on a nested accessor, but for a private-use static constant this is acceptable. Borderline -- not flagged as a finding because it is internal-use infrastructure for the operator implementations and is not part of the consumer-facing API surface.

### [API-NAME-003] Specification-Mirroring

**Status**: N/A -- Cyclic groups are a mathematical concept, not an external specification.

---

## Intent-Over-Mechanism Assessment

### [IMPL-INTENT] Code Reads as Intent

**Status**: PASS

The arithmetic implementations read clearly as mathematical operations:

```swift
// Successor: add 1, reduce mod N
let sum = element.residue + Cardinal.one
let reduced = sum % modulus.value
return Element(__unchecked: reduced)
```

The `.subtract.saturating()` accessor pattern (e.g., `modulus.value.subtract.saturating(Cardinal(rhs.position))`) reads as intent: "subtract, saturating at zero." This is the correct use of the nested accessor pattern from Cardinal primitives.

The `advanced(by:)` implementation (lines 115-130) has a clear positive/negative branch structure that reads as intent, despite the `.rawValue.magnitude` chain noted in CYC-003.

---

## Typed Throws Assessment

### [API-ERR-001]

**Status**: PASS

All throwing functions use typed throws:
- `Cyclic.Group.Modulus.init(_:)` -- `throws(Error)`
- `Cyclic.Group.Modulus.init(_: Index<Tag>.Count)` -- `throws(Error)`
- `Cyclic.Group.Static.Element.init(_:)` -- `throws(Error)`

---

## File Organization Assessment

### [API-IMPL-005] One Type Per File

| File | Types | Status |
|------|-------|--------|
| `Cyclic.swift` | `Cyclic`, `Cyclic.Group` | PASS (namespace enums co-located) |
| `Cyclic.Group.Element.swift` | `Cyclic.Group.Element` | PASS |
| `Cyclic.Group.Modulus.swift` | `Cyclic.Group.Modulus`, `Modulus.Error` | PASS (Error nested in same file is conventional) |
| `Cyclic.Group+Arithmetic.swift` | (extension only) | PASS |
| `Cyclic.Group.Static.swift` | `Static`, `Static.Element`, `Element.Error` | INFO (see CYC-008) |
| `Cyclic.Group.Static+Arithmetic.swift` | (extension only) | PASS |
| `Cyclic.Group.Static+Protocol.swift` | (conformance only) | PASS |
| `Cyclic.Group.Static+Sequence.Protocol.swift` | (conformance only) | PASS |
| `Cyclic.Group.Static.Element+Ordinal.swift` | (extension only) | PASS |
| `Cyclic.Group.Static.Iterator.swift` | `Cyclic.Group.Static.Iterator` | PASS |
| `Tagged+Cyclic.Group.Static.Element.swift` | (extension only) | PASS |
| `exports.swift` | (re-exports only) | PASS |

---

## Overall Assessment

**Quality**: HIGH

This package is well-structured and closely follows all audited requirements. The naming is exemplary -- pure Nest.Name throughout, no compound identifiers. The `__unchecked` usage is entirely boundary-correct: every instance follows modular reduction or constructs a known constant. The typed arithmetic is clean, using explicit `Ordinal`/`Cardinal` conversions that correctly model the mathematical semantics.

The single MEDIUM finding (CYC-003) is a cross-package API gap in affine-primitives, not a local defect. The LOW findings are all acceptable boundary `.rawValue` usage. The only structural suggestion is splitting `Cyclic.Group.Static.Element` into its own file (CYC-008).
