# swift-affine-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: implementation [IMPL-*], naming [API-NAME-*]
**Scope**: All `.swift` files in `Sources/`

---

## Summary Table

| ID | Severity | Requirement | File | Title |
|----|----------|-------------|------|-------|
| AFF-001 | MEDIUM | [IMPL-002] | Tagged+Affine.swift:108 | `.rawValue.rawValue` in Tagged Vector from Cardinal init |
| AFF-002 | MEDIUM | [IMPL-002] | Tagged+Affine.swift:204-207 | `.rawValue.rawValue` x3 in Tagged Cardinal from Vector init |
| AFF-003 | MEDIUM | [IMPL-002] | Tagged+Affine.swift:219-220 | `.rawValue.rawValue` x2 in unchecked Tagged Cardinal from Vector init |
| AFF-004 | MEDIUM | [IMPL-002] | Tagged+Affine.swift:254 | `.rawValue.rawValue` in Cardinal * Ratio operator |
| AFF-005 | MEDIUM | [IMPL-002] | Tagged+Affine.swift:279 | `.rawValue.rawValue` in Vector * Ratio operator |
| AFF-006 | LOW | [IMPL-002] | Tagged+Affine.swift:78 | `.rawValue.magnitude` in Tagged Vector magnitude |
| AFF-007 | LOW | [PATTERN-017] | Affine.Discrete.Vector.Protocol.swift:86 | `.vector.rawValue` in Vector.Protocol + operator |
| AFF-008 | LOW | [PATTERN-017] | Affine.Discrete.Vector.Protocol.swift:92 | `.vector.rawValue` in Vector.Protocol - operator |
| AFF-009 | LOW | [PATTERN-017] | Affine.Discrete.Vector.Protocol.swift:111 | `.vector.rawValue` in Vector.Protocol negation |
| AFF-010 | LOW | [PATTERN-017] | Affine.Discrete+Arithmetic.swift:148-206 | `.vector.rawValue` / `.cardinal.rawValue` in cross-type comparisons (x8) |
| AFF-011 | LOW | [PATTERN-017] | Affine.Discrete+Arithmetic.swift:29-73 | `.ordinal.rawValue` / `.vector.rawValue` in Position +/- Vector operators |
| AFF-012 | MEDIUM | [IMPL-002] | UnsafePointer+Tagged.Ordinal.swift:23,32,41 | `.rawValue.rawValue` in pointer arithmetic (x3) |
| AFF-013 | MEDIUM | [IMPL-002] | UnsafeMutablePointer+Tagged.Ordinal.swift:23,32,41 | `.rawValue.rawValue` in mutable pointer arithmetic (x3) |
| AFF-014 | MEDIUM | [IMPL-002] | Int+Affine.Discrete.Vector.swift:32 | `.rawValue.rawValue` in Int(bitPattern:) for tagged vector |
| AFF-015 | LOW | [PATTERN-017] | Ordinal+Affine.swift:22-25 | `.rawValue` in Ordinal init from Vector |

**Totals**: 0 CRITICAL, 0 HIGH, 7 MEDIUM, 8 LOW

---

## .rawValue.rawValue Chain Analysis

The package has 15 `.rawValue.rawValue` double-chains. This section classifies each and identifies what operator or accessor is missing.

### Chain Pattern 1: `Tagged<Tag, Affine.Discrete.Vector>` -> `Affine.Discrete.Vector` -> `Int`

This is the most frequent chain (10 occurrences). The path is:
```
offset.rawValue          -> Affine.Discrete.Vector
       .rawValue         -> Int
```

**What is missing**: A direct `Int` accessor on `Tagged<Tag, Affine.Discrete.Vector>`. The `Int(bitPattern:)` overload in `Int+Affine.Discrete.Vector.swift:31` exists precisely for this purpose, but the operator/conversion sites in Tagged+Affine.swift and the pointer files do not use it -- they inline the chain instead.

**Occurrences**:
1. `Tagged+Affine.swift:108` -- `Int(count.rawValue.rawValue)` -- could use a Cardinal-to-Vector conversion that avoids the chain
2. `Tagged+Affine.swift:204` -- `offset.rawValue.rawValue >= 0` -- guard check
3. `Tagged+Affine.swift:205` -- `offset.rawValue.rawValue` -- error associated value
4. `Tagged+Affine.swift:207` -- `offset.rawValue.rawValue` -- UInt construction
5. `Tagged+Affine.swift:219` -- `offset.rawValue.rawValue >= 0` -- assert
6. `Tagged+Affine.swift:220` -- `offset.rawValue.rawValue` -- UInt construction
7. `Tagged+Affine.swift:254` -- `Int(lhs.rawValue.rawValue)` -- cardinal scaling
8. `Tagged+Affine.swift:279` -- `lhs.rawValue.rawValue * rhs.factor` -- vector scaling
9. `UnsafePointer+Tagged.Ordinal.swift:23,32,41` -- `Int(rhs.rawValue.rawValue)`
10. `UnsafeMutablePointer+Tagged.Ordinal.swift:23,32,41` -- `Int(rhs/lhs.rawValue.rawValue)`
11. `Int+Affine.Discrete.Vector.swift:32` -- `offset.rawValue.rawValue`

### Chain Pattern 2: `Tagged<Tag, Cardinal>` -> `Cardinal` -> `UInt`

This appears in `Tagged+Affine.swift:254`:
```
lhs.rawValue             -> Cardinal
    .rawValue             -> UInt
```

**What is missing**: This file already has `Int(bitPattern:)` for `Cardinal` available via the cardinal-primitives import. The scaling operator at line 254 should use `Int(bitPattern: lhs.rawValue)` or `Int(bitPattern: lhs.cardinal)` instead of `Int(lhs.rawValue.rawValue)`.

### Proposed Resolution

A single accessor `var intValue: Int` on `Tagged where RawValue == Affine.Discrete.Vector` (returning `Int(bitPattern: self)` via the existing `Int(bitPattern:)` overload) would eliminate chains in the pointer arithmetic and ratio files. However, the chain sites inside `Tagged+Affine.swift` are themselves boundary code (operator definitions), so the severity is MEDIUM rather than HIGH -- the chains do not leak to consumer call sites.

For `Tagged<Tag, Cardinal>`, the existing `Int(bitPattern:)` overload should be used consistently.

---

## Findings

### Finding [AFF-001]: .rawValue.rawValue in Tagged Vector from Cardinal init
- **Severity**: MEDIUM
- **Requirement**: [IMPL-002]
- **Location**: Tagged+Affine.swift:108
- **Current**: `self.init(__unchecked: (), Affine.Discrete.Vector(Int(count.rawValue.rawValue)))`
- **Proposed**: `self.init(__unchecked: (), Affine.Discrete.Vector(Int(bitPattern: count.cardinal)))` or add a `Vector(cardinal:)` initializer
- **Rationale**: Double-chain `.rawValue.rawValue` extracts `Tagged<T, Cardinal>` -> `Cardinal` -> `UInt` -> `Int` -> `Vector`. The `Int(bitPattern:)` boundary overload for `Cardinal` already exists. Alternatively, a `Vector.init(_ cardinal: Cardinal)` initializer would express the conversion as intent ("vector from cardinal") rather than mechanism ("extract UInt, cast to Int, wrap in Vector").

---

### Finding [AFF-002]: .rawValue.rawValue x3 in Tagged Cardinal from Vector init (checked)
- **Severity**: MEDIUM
- **Requirement**: [IMPL-002]
- **Location**: Tagged+Affine.swift:204-207
- **Current**:
  ```swift
  guard offset.rawValue.rawValue >= 0 else {
      throw .negativeSource(offset.rawValue.rawValue)
  }
  self.init(__unchecked: (), Cardinal(UInt(offset.rawValue.rawValue)))
  ```
- **Proposed**: Use `offset.vector` accessor (which returns `Affine.Discrete.Vector`) then `.rawValue` once:
  ```swift
  guard offset.vector.rawValue >= 0 else {
      throw .negativeSource(offset.vector.rawValue)
  }
  self.init(__unchecked: (), Cardinal(UInt(offset.vector.rawValue)))
  ```
  Or add `Int(bitPattern:)` for `Tagged<Tag, Vector>` and use it.
- **Rationale**: `offset.rawValue.rawValue` is the double-chain `Tagged` -> `Vector` -> `Int`. The `.vector` accessor exists on `Tagged where RawValue == Affine.Discrete.Vector` (defined at line 64 of this same file) and returns the bare `Affine.Discrete.Vector`, reducing the chain to a single `.rawValue`. This is still boundary code (inside an initializer definition), but the accessor already exists and is unused here.

---

### Finding [AFF-003]: .rawValue.rawValue x2 in unchecked Tagged Cardinal from Vector init
- **Severity**: MEDIUM
- **Requirement**: [IMPL-002]
- **Location**: Tagged+Affine.swift:219-220
- **Current**:
  ```swift
  assert(offset.rawValue.rawValue >= 0, "...")
  self.init(__unchecked: (), Cardinal(UInt(offset.rawValue.rawValue)))
  ```
- **Proposed**: Use `offset.vector.rawValue` as in AFF-002.
- **Rationale**: Same double-chain as AFF-002. The `.vector` accessor at line 64 should be used instead of `.rawValue`.

---

### Finding [AFF-004]: .rawValue.rawValue in Cardinal * Ratio operator
- **Severity**: MEDIUM
- **Requirement**: [IMPL-002]
- **Location**: Tagged+Affine.swift:254
- **Current**: `let result = Int(lhs.rawValue.rawValue) * rhs.factor`
- **Proposed**: `let result = Int(bitPattern: lhs.cardinal) * rhs.factor`
- **Rationale**: `lhs.rawValue.rawValue` is `Tagged<From, Cardinal>` -> `Cardinal` -> `UInt`. The `.cardinal` accessor (from `Cardinal.Protocol`) and `Int(bitPattern:)` for `Cardinal` both exist. Using them is both shorter and more intentional.

---

### Finding [AFF-005]: .rawValue.rawValue in Vector * Ratio operator
- **Severity**: MEDIUM
- **Requirement**: [IMPL-002]
- **Location**: Tagged+Affine.swift:279
- **Current**: `Affine.Discrete.Vector(lhs.rawValue.rawValue * rhs.factor)`
- **Proposed**: `Affine.Discrete.Vector(lhs.vector.rawValue * rhs.factor)` or `Affine.Discrete.Vector(Int(bitPattern: lhs) * rhs.factor)`
- **Rationale**: `lhs.rawValue.rawValue` is `Tagged<From, Vector>` -> `Vector` -> `Int`. The `.vector` accessor exists at line 64 and returns the bare `Vector`, reducing to a single `.rawValue`. Alternatively, `Int(bitPattern:)` for `Tagged<Tag, Vector>` is defined in `Int+Affine.Discrete.Vector.swift:31`.

---

### Finding [AFF-006]: .rawValue.magnitude in Tagged Vector magnitude property
- **Severity**: LOW
- **Requirement**: [IMPL-002]
- **Location**: Tagged+Affine.swift:78
- **Current**: `.init(__unchecked: (), Cardinal(vector.rawValue.magnitude))`
- **Proposed**: `.init(__unchecked: (), vector.magnitude)` -- since `vector.magnitude` already returns `Cardinal` (defined at Affine.Discrete.Vector.swift:78-80).
- **Rationale**: `vector.rawValue.magnitude` extracts the `Int`, gets `UInt.magnitude`, then wraps in `Cardinal`. But `vector.magnitude` already does this and returns `Cardinal` directly. The `.rawValue` extraction is unnecessary because the typed accessor exists on the same type.

---

### Finding [AFF-007]: .vector.rawValue in Vector.Protocol + operator
- **Severity**: LOW
- **Requirement**: [PATTERN-017]
- **Location**: Affine.Discrete.Vector.Protocol.swift:86
- **Current**: `Self(Affine.Discrete.Vector(lhs.vector.rawValue + rhs.vector.rawValue))`
- **Proposed**: Could delegate to `Affine.Discrete.Vector.+` if one existed: `Self(lhs.vector + rhs.vector)` -- but `Affine.Discrete.Vector` does not define `+` on itself (only via the protocol). This is a bootstrapping necessity.
- **Rationale**: This is boundary-correct -- the protocol operator definition IS the boundary layer. The `.vector.rawValue` access is needed because Vector itself has no `+` operator (it gets one from this very protocol extension). This is a bootstrapping constraint, not a violation. **LOW severity: acceptable.**

---

### Finding [AFF-008]: .vector.rawValue in Vector.Protocol - operator
- **Severity**: LOW
- **Requirement**: [PATTERN-017]
- **Location**: Affine.Discrete.Vector.Protocol.swift:92
- **Current**: `Self(Affine.Discrete.Vector(lhs.vector.rawValue - rhs.vector.rawValue))`
- **Proposed**: Same bootstrapping constraint as AFF-007.
- **Rationale**: Same analysis as AFF-007. Boundary-correct.

---

### Finding [AFF-009]: .vector.rawValue in Vector.Protocol negation
- **Severity**: LOW
- **Requirement**: [PATTERN-017]
- **Location**: Affine.Discrete.Vector.Protocol.swift:111
- **Current**: `V(Affine.Discrete.Vector(-v.vector.rawValue))`
- **Proposed**: Same bootstrapping constraint as AFF-007.
- **Rationale**: Same analysis as AFF-007. Boundary-correct.

---

### Finding [AFF-010]: .vector.rawValue / .cardinal.rawValue in cross-type comparisons
- **Severity**: LOW
- **Requirement**: [PATTERN-017]
- **Location**: Affine.Discrete+Arithmetic.swift:148-206 (8 operators)
- **Current**: e.g., `lhs.vector.rawValue < Int(rhs.cardinal.rawValue)`
- **Proposed**: These ARE the boundary operators. They define the typed cross-type comparison. No simpler expression exists.
- **Rationale**: These 8 operators are the infrastructure that enables typed `Vector <=> Cardinal` comparisons at call sites. The `.rawValue` access inside them is definitionally correct -- this is where the boundary belongs per [PATTERN-017]. **LOW severity: boundary-correct.**

---

### Finding [AFF-011]: .ordinal.rawValue / .vector.rawValue in Position +/- Vector operators
- **Severity**: LOW
- **Requirement**: [PATTERN-017]
- **Location**: Affine.Discrete+Arithmetic.swift:29-73
- **Current**: e.g., `lhs.ordinal.rawValue.addingReportingOverflow(UInt(rhs.vector.rawValue))`
- **Proposed**: These ARE the core affine arithmetic operators. The `.rawValue` access is the necessary boundary implementation.
- **Rationale**: These operators define `Position + Vector -> Position` and `Position - Vector -> Position`. They are the canonical boundary layer for affine arithmetic. All `.rawValue` access here is confined to operator definitions. **LOW severity: boundary-correct.**

---

### Finding [AFF-012]: .rawValue.rawValue in UnsafePointer arithmetic
- **Severity**: MEDIUM
- **Requirement**: [IMPL-002]
- **Location**: UnsafePointer+Tagged.Ordinal.swift:23, 32, 41
- **Current**:
  ```swift
  unsafe lhs.advanced(by: Int(rhs.rawValue.rawValue))  // line 23
  unsafe rhs.advanced(by: Int(lhs.rawValue.rawValue))  // line 32
  unsafe lhs.advanced(by: -Int(rhs.rawValue.rawValue)) // line 41
  ```
- **Proposed**: Use the `Int(bitPattern:)` overload defined in `Int+Affine.Discrete.Vector.swift:31`:
  ```swift
  unsafe lhs.advanced(by: Int(bitPattern: rhs))   // line 23
  unsafe rhs.advanced(by: Int(bitPattern: lhs))   // line 32
  unsafe lhs.advanced(by: -Int(bitPattern: rhs))  // line 41
  ```
- **Rationale**: The `Int(bitPattern: Tagged<Tag, Affine.Discrete.Vector>)` overload exists in this same package's Standard Library Integration module. It does exactly `offset.rawValue.rawValue`. The pointer operators should use it rather than inlining the chain. This is boundary code defining typed pointer arithmetic, but the boundary overload already exists and should be used for consistency. Note: there may be a module visibility issue if the overload is in the same module -- verify compilation.

---

### Finding [AFF-013]: .rawValue.rawValue in UnsafeMutablePointer arithmetic
- **Severity**: MEDIUM
- **Requirement**: [IMPL-002]
- **Location**: UnsafeMutablePointer+Tagged.Ordinal.swift:23, 32, 41
- **Current**:
  ```swift
  unsafe lhs.advanced(by: Int(rhs.rawValue.rawValue))  // line 23
  unsafe rhs.advanced(by: Int(lhs.rawValue.rawValue))  // line 32
  unsafe lhs.advanced(by: -Int(rhs.rawValue.rawValue)) // line 41
  ```
- **Proposed**: Same as AFF-012 -- use `Int(bitPattern:)`.
- **Rationale**: Same as AFF-012.

---

### Finding [AFF-014]: .rawValue.rawValue in Int(bitPattern:) for tagged vector
- **Severity**: MEDIUM
- **Requirement**: [IMPL-002]
- **Location**: Int+Affine.Discrete.Vector.swift:32
- **Current**: `self = offset.rawValue.rawValue`
- **Proposed**: `self = offset.vector.rawValue`
- **Rationale**: This IS the boundary overload definition itself, so the `.rawValue` access is inherently correct. However, the `.vector` accessor (which returns `Affine.Discrete.Vector`) exists and is semantically clearer than `.rawValue` (which happens to also be `Affine.Discrete.Vector` but reads as "raw" rather than "vector"). Using `.vector.rawValue` reads as "the raw int of the vector" vs `.rawValue.rawValue` which reads as "the raw of the raw." Strictly this is a readability improvement, not a correctness issue. **MEDIUM** because it is the canonical boundary site where the double-chain pattern originates.

---

### Finding [AFF-015]: .rawValue in Ordinal init from Vector
- **Severity**: LOW
- **Requirement**: [PATTERN-017]
- **Location**: Ordinal+Affine.swift:22-25
- **Current**:
  ```swift
  guard vector.rawValue >= 0 else {
      throw .negativeSource(vector.rawValue)
  }
  self.init(UInt(vector.rawValue))
  ```
- **Proposed**: This is a boundary initializer. The `.rawValue` access is correct.
- **Rationale**: This initializer IS the boundary between `Affine.Discrete.Vector` (signed) and `Ordinal` (unsigned). The `.rawValue` access is necessary and correctly confined. **LOW severity: boundary-correct.**

---

## Classification Summary

### Boundary-Correct (.rawValue confined to operator/overload definitions)

These are the infrastructure definitions that ENABLE typed arithmetic at call sites. The `.rawValue` access is definitionally correct per [PATTERN-017]:

| Location | What it defines |
|----------|----------------|
| Affine.Discrete.Vector.swift:49-70 | Vector ==, <, <=, >, >= |
| Affine.Discrete.Vector.Protocol.swift:86,92,111 | Vector.Protocol +, -, prefix - (bootstrapping) |
| Affine.Discrete+Arithmetic.swift:29-73 | Position +/- Vector operators |
| Affine.Discrete+Arithmetic.swift:91-103 | Position - Position -> Vector |
| Affine.Discrete+Arithmetic.swift:148-206 | Vector <=> Cardinal cross-type comparisons |
| Ordinal+Affine.swift:22-25 | Ordinal.init(Vector) |
| Int+Affine.Discrete.Vector.swift:22 | Int(bitPattern: Vector) |

### Improvable (.rawValue.rawValue chains where typed accessors exist)

These use double-chains where a single accessor or existing boundary overload could be used instead:

| Location | Chain | Available Alternative |
|----------|-------|----------------------|
| Tagged+Affine.swift:108 | `count.rawValue.rawValue` | `Int(bitPattern: count.cardinal)` |
| Tagged+Affine.swift:204-207 | `offset.rawValue.rawValue` | `offset.vector.rawValue` |
| Tagged+Affine.swift:219-220 | `offset.rawValue.rawValue` | `offset.vector.rawValue` |
| Tagged+Affine.swift:254 | `lhs.rawValue.rawValue` | `Int(bitPattern: lhs.cardinal)` |
| Tagged+Affine.swift:279 | `lhs.rawValue.rawValue` | `lhs.vector.rawValue` |
| Tagged+Affine.swift:78 | `vector.rawValue.magnitude` | `vector.magnitude` (returns Cardinal directly) |
| UnsafePointer lines 23,32,41 | `rhs.rawValue.rawValue` | `Int(bitPattern: rhs)` |
| UnsafeMutablePointer lines 23,32,41 | `rhs.rawValue.rawValue` | `Int(bitPattern: rhs/lhs)` |
| Int+Affine.Discrete.Vector.swift:32 | `offset.rawValue.rawValue` | `offset.vector.rawValue` |

### __unchecked Usage Classification

All 22 `__unchecked` usages are inside operator/initializer definitions (boundary code). None leak to consumer call sites. The `__unchecked` label is correctly used for:

1. **Tagged construction in operators**: `Tagged<To, Cardinal>(__unchecked: (), ...)` -- the operator has already validated or computed the value.
2. **Ordinal-to-Offset conversion in subscripts**: `Tagged<Pointee, Ordinal>.Offset(__unchecked: (), index)` -- the index is known valid from the caller's contract.
3. **Self-init delegation**: `self.init(__unchecked: (), vector)` -- the public convenience init wraps a validated value.

No `__unchecked` violations found.

---

## Naming Audit

No naming violations found. All types follow the Nest.Name pattern:

- `Affine` -- root namespace
- `Affine.Discrete` -- nested namespace for discrete affine space
- `Affine.Discrete.Vector` -- nested type
- `Affine.Discrete.Vector.Error` -- nested error type
- `Affine.Discrete.Vector.Protocol` -- nested protocol
- `Affine.Discrete.Ratio<From, To>` -- nested generic type

No compound type names, no compound method names.

---

## Missing Operator Analysis

The audit identifies one category of missing infrastructure that would eliminate the MEDIUM-severity chains:

### Missing: `Affine.Discrete.Vector.init(_ cardinal: Cardinal)`

A direct `Vector(cardinal)` initializer would eliminate the `Int(count.rawValue.rawValue)` chain in Tagged+Affine.swift:108. The conversion is total (all cardinals fit in a non-negative vector).

### Observation: Existing `Int(bitPattern:)` overloads are underused

The `Int(bitPattern: Tagged<Tag, Affine.Discrete.Vector>)` overload defined at `Int+Affine.Discrete.Vector.swift:31` is not used by the pointer arithmetic operators in the same module. The `Int(bitPattern: Cardinal)` overload from cardinal-primitives is not used by the ratio scaling operator. Consistent use of these existing overloads would eliminate 9 of the 15 double-chains without adding any new infrastructure.
