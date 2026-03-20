# swift-region-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: implementation, naming
**Package**: `/Users/coen/Developer/swift-primitives/swift-region-primitives/`
**Files audited**: 8 source files in `Sources/Region Primitives/`

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 0 |
| HIGH | 8 |
| MEDIUM | 12 |
| LOW | 2 |
| **Total** | **22** |

| Requirement | Findings |
|-------------|----------|
| [API-NAME-002] No compound identifiers | 20 |
| [PATTERN-017] rawValue confinement | 2 |

## Structural Observations

The package is well-structured overall:
- **[API-NAME-001] Nest.Name**: PASS. All types use `Region.Cardinal`, `Region.Quadrant`, `Region.Octant`, etc. No compound type names.
- **[API-IMPL-005] One type per file**: PASS. Each file contains exactly one type.
- **[IMPL-INTENT] Intent over mechanism**: PASS (with exceptions noted under [PATTERN-017]). Switch-based implementations read clearly as spatial logic.
- **[IMPL-002] Typed arithmetic**: N/A. No arithmetic on tagged types in this package.

The dual static-function/instance-property pattern (e.g., `static func opposite(of:)` + `var opposite`) is clean and consistent across all types.

---

## Findings

### Finding [REG-001]: `isHorizontal` compound property name on Cardinal
- **Severity**: HIGH
- **Requirement**: [API-NAME-002]
- **Location**: Cardinal.swift:109, 115
- **Current**:
  ```swift
  public static func isHorizontal(_ direction: Region.Cardinal) -> Bool
  public var isHorizontal: Bool
  ```
- **Proposed**: Nested accessor, e.g., `cardinal.axis == .horizontal` or `cardinal.is(.horizontal)`. Alternatively, expose an `Axis` property: `cardinal.axis` returning `.horizontal` or `.vertical`.
- **Rationale**: `isHorizontal` is a compound identifier joining a query verb (`is`) with a domain noun (`Horizontal`). [API-NAME-002] requires nested accessors instead.

### Finding [REG-002]: `isVertical` compound property name on Cardinal
- **Severity**: HIGH
- **Requirement**: [API-NAME-002]
- **Location**: Cardinal.swift:121, 127
- **Current**:
  ```swift
  public static func isVertical(_ direction: Region.Cardinal) -> Bool
  public var isVertical: Bool
  ```
- **Proposed**: Same resolution as [REG-001]. An `.axis` property returning `.horizontal` / `.vertical` eliminates both compound names.
- **Rationale**: Same as [REG-001].

### Finding [REG-003]: `hasPositiveX` compound property name on Quadrant
- **Severity**: HIGH
- **Requirement**: [API-NAME-002]
- **Location**: Quadrant.swift:93, 99
- **Current**:
  ```swift
  public static func hasPositiveX(_ quadrant: Region.Quadrant) -> Bool
  public var hasPositiveX: Bool
  ```
- **Proposed**: `quadrant.sign.x == .positive` or a nested accessor `quadrant.x.isPositive`. Alternatively, expose a `signs` property returning a structured type with `.x` and `.y` components.
- **Rationale**: `hasPositiveX` compounds three concepts: possession (`has`), sign (`Positive`), axis (`X`). [API-NAME-002] prohibits this.

### Finding [REG-004]: `hasPositiveY` compound property name on Quadrant
- **Severity**: HIGH
- **Requirement**: [API-NAME-002]
- **Location**: Quadrant.swift:105, 110
- **Current**:
  ```swift
  public static func hasPositiveY(_ quadrant: Region.Quadrant) -> Bool
  public var hasPositiveY: Bool
  ```
- **Proposed**: Same resolution as [REG-003].
- **Rationale**: Same as [REG-003].

### Finding [REG-005]: `hasPositiveX` compound property name on Octant
- **Severity**: HIGH
- **Requirement**: [API-NAME-002]
- **Location**: Octant.swift:86, 95
- **Current**:
  ```swift
  public static func hasPositiveX(_ octant: Region.Octant) -> Bool
  public var hasPositiveX: Bool
  ```
- **Proposed**: `octant.sign.x == .positive` or nested accessor `octant.x.isPositive`. A structured `signs` type with `.x`, `.y`, `.z` components resolves all three Octant compound names simultaneously.
- **Rationale**: Same as [REG-003].

### Finding [REG-006]: `hasPositiveY` compound property name on Octant
- **Severity**: HIGH
- **Requirement**: [API-NAME-002]
- **Location**: Octant.swift:101, 110
- **Current**:
  ```swift
  public static func hasPositiveY(_ octant: Region.Octant) -> Bool
  public var hasPositiveY: Bool
  ```
- **Proposed**: Same resolution as [REG-005].
- **Rationale**: Same as [REG-003].

### Finding [REG-007]: `hasPositiveZ` compound property name on Octant
- **Severity**: HIGH
- **Requirement**: [API-NAME-002]
- **Location**: Octant.swift:116, 125
- **Current**:
  ```swift
  public static func hasPositiveZ(_ octant: Region.Octant) -> Bool
  public var hasPositiveZ: Bool
  ```
- **Proposed**: Same resolution as [REG-005].
- **Rationale**: Same as [REG-003].

### Finding [REG-008]: `nearestCardinal` compound property name on Clock
- **Severity**: HIGH
- **Requirement**: [API-NAME-002]
- **Location**: Clock.swift:157, 168
- **Current**:
  ```swift
  public static func nearestCardinal(of clock: Region.Clock) -> Region.Cardinal
  public var nearestCardinal: Region.Cardinal
  ```
- **Proposed**: Nested accessor: `clock.nearest.cardinal` or `clock.cardinal` (since "nearest" is implicit -- a clock position can only map to one cardinal).
- **Rationale**: `nearestCardinal` compounds a qualifier (`nearest`) with a domain type (`Cardinal`). [API-NAME-002] requires decomposition into nested accessors.

### Finding [REG-009]: `isHorizontal` compound property name on Edge
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Edge.swift:76, 82
- **Current**:
  ```swift
  public static func isHorizontal(_ edge: Region.Edge) -> Bool
  public var isHorizontal: Bool
  ```
- **Proposed**: `edge.orientation == .horizontal` or `edge.axis == .horizontal`. Edge already has a natural orientation concept; expose it as a typed property.
- **Rationale**: Same compound pattern as [REG-001]. Rated MEDIUM because Edge is a simpler type where the compound name is less ambiguous.

### Finding [REG-010]: `isVertical` compound property name on Edge
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Edge.swift:88, 94
- **Current**:
  ```swift
  public static func isVertical(_ edge: Region.Edge) -> Bool
  public var isVertical: Bool
  ```
- **Proposed**: Same resolution as [REG-009].
- **Rationale**: Same as [REG-009].

### Finding [REG-011]: `isUpperHalf` compound property name on Sextant
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Sextant.swift:121, 130
- **Current**:
  ```swift
  public static func isUpperHalf(_ sextant: Region.Sextant) -> Bool
  public var isUpperHalf: Bool
  ```
- **Proposed**: `sextant.half == .upper` or `sextant.half.y == .upper`. Expose a `Half` type with `.upper` / `.lower` cases.
- **Rationale**: `isUpperHalf` compounds a query (`is`), a position (`Upper`), and a partition concept (`Half`). [API-NAME-002] prohibits compound identifiers.

### Finding [REG-012]: `isRightHalf` compound property name on Sextant
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Sextant.swift:136, 145
- **Current**:
  ```swift
  public static func isRightHalf(_ sextant: Region.Sextant) -> Bool
  public var isRightHalf: Bool
  ```
- **Proposed**: `sextant.half == .right` or `sextant.half.x == .right`. Same `Half` type as [REG-011].
- **Rationale**: Same as [REG-011].

### Finding [REG-013]: `isCardinal` compound property name on Clock
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Clock.swift:178, 187
- **Current**:
  ```swift
  public static func isCardinal(_ clock: Region.Clock) -> Bool
  public var isCardinal: Bool
  ```
- **Proposed**: `clock.kind == .cardinal` or `clock.is(.cardinal)`. Expose a `Kind` enum with `.cardinal` / `.ordinal` cases.
- **Rationale**: `isCardinal` compounds a query with a domain concept. With `.isOrdinal` also present, a `Kind` property resolves both.

### Finding [REG-014]: `isOrdinal` compound property name on Clock
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Clock.swift:193, 202
- **Current**:
  ```swift
  public static func isOrdinal(_ clock: Region.Clock) -> Bool
  public var isOrdinal: Bool
  ```
- **Proposed**: `clock.kind == .ordinal`. Same resolution as [REG-013].
- **Rationale**: Same as [REG-013].

### Finding [REG-015]: `isUpperHalf` compound property name on Clock
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Clock.swift:208, 217
- **Current**:
  ```swift
  public static func isUpperHalf(_ clock: Region.Clock) -> Bool
  public var isUpperHalf: Bool
  ```
- **Proposed**: `clock.half == .upper` or `clock.half.y == .upper`. Same `Half` pattern as [REG-011].
- **Rationale**: Same as [REG-011].

### Finding [REG-016]: `isRightHalf` compound property name on Clock
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Clock.swift:223, 231
- **Current**:
  ```swift
  public static func isRightHalf(_ clock: Region.Clock) -> Bool
  public var isRightHalf: Bool
  ```
- **Proposed**: `clock.half == .right` or `clock.half.x == .right`. Same pattern as [REG-012].
- **Rationale**: Same as [REG-011].

### Finding [REG-017]: `horizontalAdjacent` compound property name on Corner
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Corner.swift:133, 139
- **Current**:
  ```swift
  public static func horizontalAdjacent(of corner: Region.Corner) -> Region.Corner
  public var horizontalAdjacent: Region.Corner
  ```
- **Proposed**: `corner.adjacent.horizontal` -- nested accessor decomposing the relationship (`adjacent`) from the axis (`horizontal`).
- **Rationale**: `horizontalAdjacent` compounds an axis qualifier with a relationship concept. The nested form reads as intent: "the corner adjacent along the horizontal axis."

### Finding [REG-018]: `verticalAdjacent` compound property name on Corner
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Corner.swift:145, 151
- **Current**:
  ```swift
  public static func verticalAdjacent(of corner: Region.Corner) -> Region.Corner
  public var verticalAdjacent: Region.Corner
  ```
- **Proposed**: `corner.adjacent.vertical` -- same pattern as [REG-017].
- **Rationale**: Same as [REG-017].

### Finding [REG-019]: `topLeft`, `topRight`, `bottomLeft`, `bottomRight` compound static properties on Corner
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-002]
- **Location**: Corner.swift:50-59
- **Current**:
  ```swift
  public static let topLeft = Region.Corner(horizontal: .leftward, vertical: .upward)
  public static let topRight = Region.Corner(horizontal: .rightward, vertical: .upward)
  public static let bottomLeft = Region.Corner(horizontal: .leftward, vertical: .downward)
  public static let bottomRight = Region.Corner(horizontal: .rightward, vertical: .downward)
  ```
- **Proposed**: Nested accessors: `Corner.top.left`, `Corner.top.right`, `Corner.bottom.left`, `Corner.bottom.right`. This decomposes the vertical position (`.top`, `.bottom`) from the horizontal position (`.left`, `.right`).
- **Rationale**: These are compound identifiers combining two spatial concepts. The existing init `Corner(horizontal:vertical:)` already decomposes them; the static properties should follow the same decomposition. However, this matches SwiftUI's `Alignment.topLeading` pattern, so this is a design trade-off rather than a clear violation. Rated MEDIUM because the compound form is ubiquitous in platform conventions.

### Finding [REG-020]: `topLeft`, `topRight`, `bottomLeft`, `bottomRight` compound case references in Edge.corners
- **Severity**: LOW
- **Requirement**: [API-NAME-002]
- **Location**: Edge.swift:106-109
- **Current**:
  ```swift
  case .top: return (.topLeft, .topRight)
  case .left: return (.topLeft, .bottomLeft)
  case .bottom: return (.bottomLeft, .bottomRight)
  case .right: return (.topRight, .bottomRight)
  ```
- **Proposed**: Resolves automatically when [REG-019] is addressed.
- **Rationale**: These are references to the compound names defined in [REG-019]. Not a separate violation -- cascading from [REG-019].

### Finding [REG-021]: `.rawValue` used in rotation arithmetic (Sextant, Quadrant, Clock)
- **Severity**: LOW
- **Requirement**: [PATTERN-017]
- **Location**: Sextant.swift:53, 65, 77; Quadrant.swift:48, 60, 71; Clock.swift:79, 93, 105, 124
- **Current**:
  ```swift
  // Sextant.next
  Region.Sextant(rawValue: (sextant.rawValue % 6) + 1)!
  // Clock.clockwise
  let next = clock.rawValue % 12 + 1
  ```
- **Proposed**: These are internal implementation details of the rotation operations -- the `.rawValue` access is the mechanism for modular arithmetic on the underlying integer representation. This is legitimate boundary code: the rawValue is used inside the static function implementations (which ARE the boundary layer for these cyclic group operations) and is not exposed to call sites. **No action required** -- this is correctly confined.
- **Rationale**: [PATTERN-017] confines `.rawValue` to boundary code. These static functions ARE the boundary. The instance property accessors delegate to them, keeping call sites clean (e.g., `sextant.next`, `clock.clockwise`). This is noted for completeness but is not a violation.

---

## Design Observations (Non-Finding)

### Consistent Dual API Pattern
Every operation follows a disciplined pattern: `static func name(of:)` + `var name`. This is clean, testable, and consistent across all 7 types. No recommendation to change.

### Cyclic Group Modeling
The package correctly models Z_n groups (Z_4 for Cardinal/Quadrant, Z_6 for Sextant, Z_12 for Clock, Z_2^3 for Octant). The algebraic structure is sound and well-documented.

### Potential Unification Opportunity
The compound name findings cluster into three patterns that could be resolved with small accessor types:
1. **Axis/Orientation**: `.axis` property returning `.horizontal` / `.vertical` (resolves [REG-001], [REG-002], [REG-009], [REG-010])
2. **Half-plane**: `.half` property with `.upper` / `.lower` / `.left` / `.right` (resolves [REG-011], [REG-012], [REG-015], [REG-016])
3. **Sign**: `.sign` property with `.x` / `.y` / `.z` components (resolves [REG-003] through [REG-007])

These accessor types could live on the respective types or be shared via a common protocol/namespace.
