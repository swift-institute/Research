# swift-dimension-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: implementation, naming
**Package**: `/Users/coen/Developer/swift-primitives/swift-dimension-primitives/`
**Files audited**: 28 source files in `Sources/Dimension Primitives/`

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 0 |
| HIGH | 4 |
| MEDIUM | 8 |
| LOW | 7 |
| **Total** | **19** |

| Requirement | Findings |
|-------------|----------|
| [API-NAME-001] Nest.Name | 1 |
| [API-NAME-002] No compound identifiers | 3 |
| [API-IMPL-005] One type per file | 1 |
| [IMPL-INTENT] Intent over mechanism | 2 |
| [IMPL-002] Typed arithmetic | 1 |
| [IMPL-003] Functor ops for domain crossing | 2 |
| [PATTERN-017] rawValue confinement | 2 |
| [PATTERN-019] No blanket Tagged init | 1 |
| [PATTERN-021] Prefer typed arithmetic | 3 |
| Filename spelling | 2 |
| Code duplication (structural) | 1 |

## Root Cause Analysis: Why 206 __unchecked and 192 .rawValue?

The high counts are **not** a violation pattern. They are **infrastructure density** -- this package IS the operator layer for affine geometry.

**Breakdown of 206 `__unchecked`**:
- **103 in `Tagged+Arithmatic.swift`**: Operator overload implementations (same-type +/-, cross-type Coord-Disp, Disp*Disp->Area, Scale ops). These are boundary overloads per [IMPL-010] -- the CORRECT location for `__unchecked`.
- **39 in `Degree.swift`**: Static angle constants (`rightAngle`, `thirty`, etc.) and operator implementations. Constants are legitimate; the concern is duplication (Double/Float) and compound names.
- **22 in `Radian.swift`**: Static constants and Pi accessor. Same pattern as Degree.
- **10 in `Tagged+Dimension.swift`**: FloatingPoint property forwarding (`ulpOfOne`, `infinity`, `nan`, `pi`), `sqrt` dimension-crossing, `init(_ value:)` for Spatial types. Legitimate infrastructure.
- **13 in `Axis.swift`**: Static `primary`/`secondary`/`tertiary`/`quaternary` constructors and validated init. Legitimate -- Axis is not a Tagged type.
- **7 in `Radian+Trigonometry.swift`**: Inverse trig functions (`asin`, `acos`, `atan`, `atan2`), pi helpers, normalization. Legitimate infrastructure.
- **7 in `Interval.Unit.swift`**: Complement, interpolation, multiplication clamping. Custom bounded type -- legitimate.
- **3 in `Tagged+Quantized.swift`**: `_quantize` static method. This IS the quantization infrastructure.
- **2 in `Axis+CaseIterable.swift`**: `Finite.Enumerable` conformance. Legitimate.

**Conclusion**: ~95% of `__unchecked`/`.rawValue` usage is correctly placed inside infrastructure operators. The remaining ~5% is the subject of the findings below.

---

## Findings

### Finding [DIM-001]: Dimension.swift contains multiple types
- **Severity**: HIGH
- **Requirement**: [API-IMPL-005]
- **Location**: Dimension.swift:1-281
- **Current**: One file contains `Spatial` (protocol), `Coordinate` (enum with 5 nested enums), `Displacement` (enum with 5 nested enums), `Extent` (enum with 4 nested enums), `Measure` (enum), plus 3 measure typealiases (`Magnitude`, `Area`, `Volume`), 12 `Value` typealiases, and 7 semantic typealiases (`Length`, `Radius`, `Diameter`, `Distance`, `Circumference`, `Perimeter`, `ArcLength`).
- **Proposed**: Split into: `Spatial.swift`, `Coordinate.swift`, `Displacement.swift`, `Extent.swift`, `Measure.swift`, `Measure+Typealiases.swift`, `Coordinate+Value.swift`, `Displacement+Value.swift`, `Extent+Value.swift`, `Measure+Value.swift`, `Coordinate+Spatial.swift`, `Displacement+Spatial.swift`, `Extent+Spatial.swift`.
- **Rationale**: This file defines 4 primary types, 1 protocol, and 14+ nested/auxiliary types. [API-IMPL-005] requires one type per file. The file is 281 lines -- manageable in size -- but violates the structural rule that aids discoverability and change tracking.

### Finding [DIM-002]: `ArcLength` compound typealias at file scope
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-001]
- **Location**: Dimension.swift:280
- **Current**: `public typealias ArcLength<Space, Scalar> = Magnitude<Space>.Value<Scalar>`
- **Proposed**: Nest under a domain namespace, e.g., `Curve.ArcLength`, or remove it (it is structurally identical to `Length`/`Radius`/`Distance`/etc. -- all resolve to `Magnitude<Space>.Value<Scalar>`).
- **Rationale**: `ArcLength` is a compound name at file scope. All other geometric concepts use `Nest.Name` nesting. This is the only compound-named typealias in the file.

### Finding [DIM-003]: `rightAngle`, `straightAngle`, `fullCircle`, `fortyFive` compound property names
- **Severity**: HIGH
- **Requirement**: [API-NAME-002]
- **Location**: Degree.swift:74, 78, 82, 86 (Double), Degree.swift:102, 106, 110, 114 (Float)
- **Current**:
  ```swift
  public static var rightAngle: Self { Self(__unchecked: (), 90) }
  public static var straightAngle: Self { Self(__unchecked: (), 180) }
  public static var fullCircle: Self { Self(__unchecked: (), 360) }
  public static var fortyFive: Self { Self(__unchecked: (), 45) }
  ```
- **Proposed**: The package already provides the correct nested accessor API (`Degree.right.full`, `Degree.straight.full`, `Degree.full.full`). These compound-named statics are redundant. Remove them, or if retained for backward compatibility, deprecate in favor of the accessor pattern.
- **Rationale**: [API-NAME-002] forbids compound property names. The nested accessor pattern (`.right.full`, `.right.half`) already exists in the same file and supersedes these.

### Finding [DIM-004]: `halfPi`, `twoPi`, `quarterPi` compound property names
- **Severity**: HIGH
- **Requirement**: [API-NAME-002]
- **Location**: Radian.swift:43, 47, 51
- **Current**:
  ```swift
  public static var halfPi: Self { Self(__unchecked: (), .pi / 2) }
  public static var twoPi: Self { Self(__unchecked: (), .pi * 2) }
  public static var quarterPi: Self { Self(__unchecked: (), .pi / 4) }
  ```
- **Proposed**: The package already provides `Radian.pi.half`, `Radian.pi.two`, `Radian.pi.quarter`. These compound statics are redundant. Remove or deprecate.
- **Rationale**: Same as [DIM-003]. The nested accessor API already exists.

### Finding [DIM-005]: Degree constants duplicated for Double and Float
- **Severity**: MEDIUM
- **Requirement**: [IMPL-INTENT]
- **Location**: Degree.swift:71-95 (Double), Degree.swift:99-123 (Float)
- **Current**: Identical constant definitions duplicated verbatim for `RawValue == Double` and `RawValue == Float`. Each defines `rightAngle`, `straightAngle`, `fullCircle`, `fortyFive`, `sixty`, `thirty`.
- **Proposed**: Use a single extension constrained on `BinaryFloatingPoint` (which both Double and Float satisfy). The constants are all integer-literal-expressible, so `Self(__unchecked: (), 90)` works for any `BinaryFloatingPoint`.
- **Rationale**: The `BinaryFloatingPoint`-constrained extensions already exist in the same file (e.g., the `Right`/`Straight`/`Full` accessors). Duplicating for concrete types is unnecessary mechanism. Note: this finding becomes moot if [DIM-003] results in removal.

### Finding [DIM-006]: Same-type arithmetic uses `__unchecked` where `.map` suffices
- **Severity**: LOW
- **Requirement**: [PATTERN-021], [IMPL-003]
- **Location**: Tagged+Arithmatic.swift (throughout same-type operators, e.g., lines 148-159, 163-176, 254-269, etc.)
- **Current**:
  ```swift
  public func + <Space, Scalar: AdditiveArithmetic>(
      lhs: Displacement.X<Space>.Value<Scalar>,
      rhs: Displacement.X<Space>.Value<Scalar>
  ) -> Displacement.X<Space>.Value<Scalar> {
      Tagged(__unchecked: (), lhs.rawValue + rhs.rawValue)
  }
  ```
- **Proposed**:
  ```swift
  public func + <Space, Scalar: AdditiveArithmetic>(
      lhs: Displacement.X<Space>.Value<Scalar>,
      rhs: Displacement.X<Space>.Value<Scalar>
  ) -> Displacement.X<Space>.Value<Scalar> {
      lhs.map { $0 + rhs.rawValue }
  }
  ```
- **Rationale**: For same-type operations (where input and output share the same Tag), `.map` preserves the tag and eliminates the `__unchecked` construction. This is an incremental improvement, not a violation -- these are infrastructure implementations where `__unchecked` is permitted by [PATTERN-017]. However, `.map` is more intent-oriented per [IMPL-003]. Affects ~30 same-type +/- operators.

### Finding [DIM-007]: Cross-axis extent comparisons extract `.rawValue` (observational)
- **Severity**: LOW
- **Requirement**: [PATTERN-017]
- **Location**: Tagged+Arithmatic.swift:399-472
- **Current**:
  ```swift
  public func < <Space, Scalar: Comparable>(
      lhs: Extent.X<Space>.Value<Scalar>,
      rhs: Extent.Y<Space>.Value<Scalar>
  ) -> Bool { lhs.rawValue < rhs.rawValue }
  ```
- **Proposed**: No change needed -- this IS the infrastructure layer. These are cross-axis comparison overloads that enable `width < height` at call sites. The `.rawValue` extraction is correctly confined to the operator implementation.
- **Rationale**: These comparisons are correctly placed as boundary overloads. Noted for completeness; no action needed.

### Finding [DIM-008]: `Tagged+Arithmatic.swift` filename misspelling
- **Severity**: LOW
- **Requirement**: Code quality
- **Location**: `Tagged+Arithmatic.swift` (filename)
- **Current**: "Arithmatic" (incorrect)
- **Proposed**: "Arithmetic" (correct English spelling)
- **Rationale**: The correct spelling is "arithmetic" (from Greek arithmetikos). The misspelling appears in two files: `Tagged+Arithmatic.swift` and `Dimension+Arithmatic.swift`.

### Finding [DIM-009]: `Dimension+Arithmatic.swift` filename misspelling
- **Severity**: LOW
- **Requirement**: Code quality
- **Location**: `Dimension+Arithmatic.swift` (filename)
- **Current**: "Arithmatic"
- **Proposed**: "Arithmetic"
- **Rationale**: Same as [DIM-008]. This file contains only the `Scale` negation operator (15 lines).

### Finding [DIM-010]: `Tagged+Arithmatic.swift` header says "File.swift" and "swift-standards"
- **Severity**: LOW
- **Requirement**: Code quality
- **Location**: Tagged+Arithmatic.swift:1-6
- **Current**:
  ```swift
  //  File.swift
  //  swift-standards
  //
  //  Created by Coen ten Thije Boonkkamp on 13/12/2025.
  ```
- **Proposed**: Correct to `Tagged+Arithmetic.swift` / `swift-dimension-primitives`.
- **Rationale**: The file header references the wrong file name and wrong package. Likely a copy-paste artifact.

### Finding [DIM-011]: Radian conversion init uses `__unchecked` (observational)
- **Severity**: LOW
- **Requirement**: [PATTERN-021]
- **Location**: Radian.swift:169
- **Current**: `self.init(__unchecked: (), degrees.rawValue * .pi / 180)`
- **Proposed**: No change needed -- this is inside an initializer, the canonical infrastructure location per [PATTERN-012].
- **Rationale**: Noted for completeness. The `__unchecked` is correctly placed.

### Finding [DIM-012]: `Axis.perpendicular(of:)` uses `1 - axis.rawValue`
- **Severity**: MEDIUM
- **Requirement**: [IMPL-002]
- **Location**: Axis.swift:104
- **Current**: `Self(__unchecked: (), 1 - axis.rawValue)`
- **Proposed**: Since `Axis` is a custom struct with `rawValue: Int` (not a `Tagged` type), this is standard arithmetic. However, the operation is semantically "the other axis in 2D." Acceptable as-is given the simplicity.
- **Rationale**: `1 - axis.rawValue` is mechanical. The intent is "the perpendicular axis." Minor clarity issue -- `Axis` is not a `Tagged` wrapper, so [IMPL-002] does not strictly apply.

### Finding [DIM-013]: `Axis.count` uses explicit `integerLiteral:` label
- **Severity**: MEDIUM
- **Requirement**: [IMPL-INTENT]
- **Location**: Axis+CaseIterable.swift:11
- **Current**: `public static var count: Cardinal { Cardinal.init(integerLiteral: UInt(N)) }`
- **Proposed**: `public static var count: Cardinal { Cardinal(UInt(N)) }` -- or if a direct init from Int exists, `Cardinal(N)`. The `.init(integerLiteral:)` is an explicit call to a protocol-provided init that obscures simple construction.
- **Rationale**: `Cardinal.init(integerLiteral: UInt(N))` reads as mechanism (explicitly selecting the `integerLiteral:` overload). The intent is "N as a cardinal value."

### Finding [DIM-014]: `Tagged+Dimension.swift` blanket `init(_ value: RawValue)` for `Spatial` tags
- **Severity**: HIGH
- **Requirement**: [PATTERN-019]
- **Location**: Tagged+Dimension.swift:90-110
- **Current**:
  ```swift
  extension Tagged where Tag: Spatial {
      @_disfavoredOverload
      public init(_ value: RawValue) {
          self.init(__unchecked: (), value)
      }
  }

  extension Tagged where Tag: Spatial, RawValue: BinaryFloatingPoint {
      public init(_ value: RawValue) {
          self = ._quantize(value, in: Tag.Space.self)
      }
  }
  ```
- **Proposed**: These inits enable `Coordinate.X<Space>.Value<Double>(42.0)` -- convenient for call sites. However, `Tag: Spatial` is a wide constraint covering ALL spatial types (Coordinate, Displacement, Extent, Measure). This creates a public `init` on `Tagged` for every spatial tag, bypassing any potential validation. Per [PATTERN-019], blanket `Tagged` init constructors on protocol constraints are suspect. The `@_disfavoredOverload` on the non-quantized overload mitigates some risk. Mark with WORKAROUND comment documenting the design trade-off.
- **Rationale**: [PATTERN-019] warns against blanket `init` on `Tagged where RawValue == T`. This extends to protocol-constrained inits. For floating-point geometry values with no invariants beyond "any real number," the init is defensible -- but it should be documented as an explicit design choice.

### Finding [DIM-015]: Negation operator and other `Scale` methods use raw `for i in 0..<N` loops
- **Severity**: MEDIUM
- **Requirement**: [IMPL-033]
- **Location**: Dimension+Arithmatic.swift:9-14, Scale.swift:35, 48, 69, 77, 222, 241
- **Current**:
  ```swift
  public static prefix func - (scale: Self) -> Self {
      var result = scale.factors
      for i in 0..<N {
          result[i] = -scale.factors[i]
      }
      return Self(result)
  }
  ```
- **Proposed**: If `InlineArray` provides `.map` or element-wise transformation, use it. If not, this is acceptable infrastructure-level iteration. This is an infrastructure gap in `InlineArray`, not a deficiency in dimension-primitives.
- **Rationale**: Seven locations use `for i in 0..<N` iteration over `InlineArray` factors. These are all implementation internals of `Scale`. The pattern is consistent and correct, but represents typed mechanism (level 3 of [IMPL-033]) rather than typed intent.

### Finding [DIM-016]: `min`/`max` free functions may not need `.rawValue`
- **Severity**: MEDIUM
- **Requirement**: [PATTERN-017]
- **Location**: Tagged+Arithmatic.swift:71-79
- **Current**:
  ```swift
  public func min<Tag, T: Comparable>(_ x: Tagged<Tag, T>, _ y: Tagged<Tag, T>) -> Tagged<Tag, T> {
      x.rawValue <= y.rawValue ? x : y
  }
  public func max<Tag, T: Comparable>(_ x: Tagged<Tag, T>, _ y: Tagged<Tag, T>) -> Tagged<Tag, T> {
      x.rawValue >= y.rawValue ? x : y
  }
  ```
- **Proposed**: If `Tagged: Comparable where RawValue: Comparable`, replace with `x <= y ? x : y`. The `.rawValue` extraction would then be unnecessary even in infrastructure.
- **Rationale**: If `Tagged` already conforms to `Comparable`, the `.rawValue` extraction is mechanism that typed comparison eliminates.

### Finding [DIM-017]: `Winding` and `Chirality` do not conform to `Orientation`
- **Severity**: MEDIUM
- **Requirement**: [IMPL-INTENT]
- **Location**: Winding.swift, Chirality.swift
- **Current**: `Winding` and `Chirality` each manually implement `opposite`, `!` prefix, and paired `Value` typealias. They do NOT conform to `Orientation` despite being structurally isomorphic to `Direction`/`Horizontal`/`Vertical`/`Depth`/`Temporal`.
- **Proposed**: Conform `Winding` and `Chirality` to `Orientation` by adding `direction` property and `init(direction:)`. This provides `allCases`, `!` prefix, `isPositive`/`isNegative`, and `init(_ condition: Bool)` for free.
- **Rationale**: The `Orientation` protocol captures the exact algebraic structure (Z/2Z binary type with opposite involution). `Winding` and `Chirality` duplicate the pattern manually. Conformance eliminates boilerplate and makes the isomorphism explicit.

---

## Infrastructure Assessment

The package is **well-designed** for its domain. Key strengths:

1. **Affine geometry correctness**: Coordinate + Displacement = Coordinate, Coordinate - Coordinate = Displacement. This is mathematically principled per [IMPL-001].
2. **Quantization architecture**: The `_quantize` overload selection pattern using `@_disfavoredOverload` + `BinaryFloatingPoint` specialization is elegant.
3. **Scale type**: `Scale<N, Scalar>` as dimensionless factor correctly separates scaling from dimension-carrying types.
4. **Nested accessor pattern**: `Radian.pi.half`, `Degree.right.full`, `Degree.full.fraction<1, 12>()()` follows [API-NAME-002] well.
5. **Functor usage**: `.retag()` used correctly in displacement-to-extent conversions (`width`, `height`, `depth` free functions). `.map` used for negation.

The high `__unchecked` count (206) is **correctly placed** -- this package IS the dimensional operator infrastructure. The findings above identify the ~5% that could be improved.
