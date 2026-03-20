# swift-geometry-primitives Audit: Implementation & Naming

**Date**: 2026-03-20
**Package**: `swift-geometry-primitives`
**Scope**: All 18 `.swift` source files in `Sources/Geometry Primitives/`
**Skills**: naming (`[API-NAME-*]`), implementation (`[IMPL-*]`, `[PATTERN-*]`)
**Status**: READ-ONLY audit

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 3 |
| HIGH | 9 |
| MEDIUM | 18 |
| LOW | 8 |
| **Total** | **38** |

### By Requirement

| Requirement | Count | Severity Range |
|-------------|-------|----------------|
| [API-NAME-001] Compound type names | 4 | CRITICAL-HIGH |
| [API-NAME-002] Compound method/property names | 2 | HIGH |
| [API-IMPL-005] One type per file | 5 | MEDIUM |
| [PATTERN-017] .rawValue at call sites | 11 | HIGH-MEDIUM |
| [PATTERN-021] __unchecked over typed ops | 5 | MEDIUM |
| [IMPL-INTENT] Mechanism over intent | 4 | MEDIUM-LOW |
| [IMPL-002] Typed arithmetic | 3 | HIGH-MEDIUM |
| [IMPL-033] Iteration mechanism | 2 | LOW |
| [IMPL-030] Intermediate variables | 2 | LOW |

---

## CRITICAL Findings

### Finding [GEO-001]: `EdgeInsets` is a compound type name
- **Severity**: CRITICAL
- **Requirement**: [API-NAME-001]
- **Location**: Geometry.EdgeInsets.swift:18
- **Current**: `public struct EdgeInsets`
- **Proposed**: `public struct Insets` nested under `Geometry.Edge` or simply `Geometry.Insets` (since it is already nested in `Geometry`, `Edge.Insets` would read as `Geometry.Edge.Insets`)
- **Rationale**: "EdgeInsets" is a compound name combining two concepts (Edge + Insets). Under [API-NAME-001], it MUST use the Nest.Name pattern. The type is already nested in `Geometry<Scalar, Space>`, so a single word `Insets` or nesting under `Edge` would comply.

### Finding [GEO-002]: `BezierSegment` is a compound type name
- **Severity**: CRITICAL
- **Requirement**: [API-NAME-001]
- **Location**: Geometry.Ball.swift:413
- **Current**: `public struct BezierSegment`
- **Proposed**: `Geometry.Bezier.Segment` (move to separate file, nested in Bezier) or `Geometry.Ball.Bezier` (renaming to a single concept)
- **Rationale**: "BezierSegment" combines two nouns. Since `Geometry.Bezier` already exists as a type, a `Bezier.Segment` or `Bezier.Cubic` nesting would be more natural and compliant.

### Finding [GEO-003]: `CardinalDirection` is a compound type name
- **Severity**: CRITICAL
- **Requirement**: [API-NAME-001]
- **Location**: Geometry.Ray.swift:360
- **Current**: `public enum CardinalDirection`
- **Proposed**: `Geometry.Direction` (the "cardinal" aspect is implicit from having exactly 4 cases: right, up, left, down)
- **Rationale**: "CardinalDirection" is a compound name. The type lives inside `Geometry` and only has four cardinal cases, so `Direction` alone is sufficient. Alternatively, consider `Cardinal.Direction` if cardinal specificity is needed.

---

## HIGH Findings

### Finding [GEO-004]: `AffineTransform` typealias is a compound name
- **Severity**: HIGH
- **Requirement**: [API-NAME-001]
- **Location**: Geometry.swift:114
- **Current**: `public typealias AffineTransform = Affine.Continuous<Scalar, Space>.Transform`
- **Proposed**: `public typealias Transform = Affine.Continuous<Scalar, Space>.Transform` (the `Affine` context is redundant since `Affine.Continuous.Transform` already encodes it)
- **Rationale**: The typealias name "AffineTransform" is compound. Since it aliases `Affine.Continuous.Transform`, the word "Affine" is redundant in the Geometry namespace. Just `Transform` suffices.

### Finding [GEO-005]: `ArcLength` typealias is a compound name
- **Severity**: HIGH
- **Requirement**: [API-NAME-001]
- **Location**: Geometry.swift:108
- **Current**: `public typealias ArcLength = Linear<Scalar, Space>.Magnitude`
- **Proposed**: Remove this typealias. It is semantically identical to `Length`, `Radius`, `Distance`, `Circumference`, `Perimeter` (all alias `Linear.Magnitude`). Having 7 typealiases all pointing to the same type adds no type safety. If distinct semantics are desired, a newtype (not typealias) is needed.
- **Rationale**: Compound name. Additionally, this is one of 7 typealiases all resolving to `Linear.Magnitude` with no distinguishing type information.

### Finding [GEO-006]: `containsBarycentric` is a compound method name
- **Severity**: HIGH
- **Requirement**: [API-NAME-002]
- **Location**: Geometry.Ngon.swift:1015
- **Current**: `public func containsBarycentric(_ point: Geometry.Point<2>) -> Bool`
- **Proposed**: `public func contains(_ point: Geometry.Point<2>, method: ContainmentMethod = .barycentric) -> Bool` or nest as `public var contains: Contains { ... }` with `contains.barycentric(point)`.
- **Rationale**: The method combines "contains" (verb) with "Barycentric" (qualifier) into a single compound identifier, violating [API-NAME-002].

### Finding [GEO-007]: `containsInterior` is a compound method name
- **Severity**: HIGH
- **Requirement**: [API-NAME-002]
- **Location**: Geometry.Ball.swift:160
- **Current**: `public func containsInterior(_ point: Geometry.Point<2>) -> Bool`
- **Proposed**: `public func contains(interior point: Geometry.Point<2>) -> Bool` (using a label to distinguish from boundary-inclusive `contains`)
- **Rationale**: Compound method identifier violates [API-NAME-002]. A labeled parameter or nested accessor pattern would comply.

### Finding [GEO-008]: Massive .rawValue density in `Geometry.Ball.swift` static implementations
- **Severity**: HIGH
- **Requirement**: [PATTERN-017], [IMPL-002]
- **Location**: Geometry.Ball.swift:289-360 (intersection static methods)
- **Current**: 44 `.rawValue` extractions across `intersection`, `closestPoint`, `surfaceArea`, `volume` methods. E.g.: `let fx = line.point.x.rawValue - circle.center.x.rawValue` (line 289), `let r = circle.radius.rawValue` (line 293), etc.
- **Proposed**: For geometric intersection calculations that inherently mix coordinate components, `.rawValue` is partially justified. However, many usages could be eliminated by adding typed operators. For example, `circle.radius * circle.radius` already works (returns `Area`), but `let r = circle.radius.rawValue` then `r * r` discards this.
- **Rationale**: While some raw arithmetic is justified for coordinate-mixing algorithms, the current pattern extracts raw values eagerly at method entry rather than at the precise point where mixing occurs. This inflates the `.rawValue` count unnecessarily.

### Finding [GEO-009]: Massive .rawValue density in `Geometry.Ellipse.swift`
- **Severity**: HIGH
- **Requirement**: [PATTERN-017], [IMPL-002]
- **Location**: Geometry.Ellipse.swift:141, 170-187, 340-387 (foci, perimeter, point, contains methods)
- **Current**: 63 `.rawValue` extractions. E.g.: `let c: Scalar = focalDistance.rawValue` (line 141), `let a: Scalar = semiMajor.rawValue` / `let b: Scalar = semiMinor.rawValue` repeated in 5+ methods.
- **Proposed**: Extract raw values only at the precise mixing boundary. For `perimeter`, the entire Ramanujan formula operates on dimensionless ratios -- the extraction is defensible but could use `Scale` types for intermediate terms. For `contains`, the ellipse equation naturally reduces to a dimensionless comparison.
- **Rationale**: Same pattern as GEO-008. Eager extraction at method entry inflates mechanism exposure.

### Finding [GEO-010]: .rawValue in `Geometry+Arithmatic.swift` operator bodies
- **Severity**: HIGH
- **Requirement**: [PATTERN-017]
- **Location**: Geometry+Arithmatic.swift:213, 226, 239, 251, 261, 271, 281, 292, 301, 310, 319, 331, 351, 372, 390
- **Current**: Height/Width arithmetic operators extract `.rawValue` for computation: `Scale(lhs.rawValue / rhs.rawValue)` (line 213), `Geometry<Scalar, Space>.Height(lhs.rawValue + rhs.rawValue)` (line 251).
- **Proposed**: These ARE boundary implementations (operator overloads), so `.rawValue` is acceptable per [PATTERN-017] ("confined to extension initializers and same-package implementations"). However, many could delegate to existing typed operators on the underlying `Linear` types rather than extracting raw values.
- **Rationale**: Borderline acceptable. These are same-package operator implementations, which [PATTERN-017] permits. Listing for completeness; severity downgraded from what the raw count suggests.

### Finding [GEO-011]: .rawValue density in `Geometry.Arc.swift` boundingBox
- **Severity**: HIGH
- **Requirement**: [PATTERN-017], [IMPL-002]
- **Location**: Geometry.Arc.swift:231-297
- **Current**: 24 `.rawValue` extractions in `boundingBox(of:)`. Every coordinate, radius, and angle is immediately extracted: `let cx = arc.center.x.rawValue`, `let r = arc.radius.rawValue`, `let sweep = arc.sweep.rawValue`, etc.
- **Proposed**: The bounding box algorithm inherently mixes coordinates. However, the typed system already supports `center.x + radius` (Coordinate + Magnitude = Coordinate) and `center.x - radius`. The full-circle special case (lines 237-243) already constructs typed `X(cx - r)` from raw values -- those `X(...)` constructions could use typed arithmetic directly.
- **Rationale**: Typed operations exist for the simple cases (full circle bounding box). The cardinal-direction checking loop legitimately needs raw angle comparison, but the min/max tracking could use typed `X`/`Y` values with `Swift.min`/`Swift.max`.

---

## MEDIUM Findings

### Finding [GEO-012]: `Geometry.swift` contains both `Geometry` enum and `Geometry.Magnitude` struct
- **Severity**: MEDIUM
- **Requirement**: [API-IMPL-005]
- **Location**: Geometry.swift:46, 137
- **Current**: `Geometry.swift` defines both `public enum Geometry<...>` (line 46) and `public struct Magnitude` (line 137), plus type aliases.
- **Proposed**: Move `Magnitude` to `Geometry.Magnitude.swift`.
- **Rationale**: [API-IMPL-005] requires one type per file. Typealiases are acceptable in the namespace file, but the `Magnitude` struct with its own conformances and methods should be in its own file.

### Finding [GEO-013]: `Geometry.Ball.swift` contains both `Ball` and `BezierSegment`
- **Severity**: MEDIUM
- **Requirement**: [API-IMPL-005]
- **Location**: Geometry.Ball.swift:29, 413
- **Current**: Two distinct structs in one file.
- **Proposed**: Move `BezierSegment` to `Geometry.Ball.BezierSegment.swift` (after renaming per GEO-002).
- **Rationale**: [API-IMPL-005] one type per file.

### Finding [GEO-014]: `Geometry.Ray.swift` contains both `Ray` and `CardinalDirection`
- **Severity**: MEDIUM
- **Requirement**: [API-IMPL-005]
- **Location**: Geometry.Ray.swift:23, 360
- **Current**: Two distinct types in one file.
- **Proposed**: Move `CardinalDirection` to `Geometry.CardinalDirection.swift` (after renaming per GEO-003).
- **Rationale**: [API-IMPL-005] one type per file.

### Finding [GEO-015]: `Geometry.Path.swift` contains `Path`, `Subpath`, and `Segment`
- **Severity**: MEDIUM
- **Requirement**: [API-IMPL-005]
- **Location**: Geometry.Path.swift:31, 59, 97
- **Current**: Three types in one file.
- **Proposed**: `Geometry.Path.Subpath.swift` and `Geometry.Path.Segment.swift`.
- **Rationale**: [API-IMPL-005] one type per file. Subpath and Segment are nested inside Path but are substantial types with their own conformances.

### Finding [GEO-016]: `Geometry.Ngon.swift` contains both `Ngon` and `Edges`
- **Severity**: MEDIUM
- **Requirement**: [API-IMPL-005]
- **Location**: Geometry.Ngon.swift:31, 154
- **Current**: Two distinct types in one file.
- **Proposed**: Move `Edges` to `Geometry.Edges.swift`.
- **Rationale**: [API-IMPL-005] one type per file.

### Finding [GEO-017]: `__unchecked` Radian construction in Arc
- **Severity**: MEDIUM
- **Requirement**: [PATTERN-021]
- **Location**: Geometry.Arc.swift:283, 287, 375, 408, 504-505
- **Current**: `Radian(__unchecked: (), Scalar.pi)`, `Radian(__unchecked: (), Scalar.pi * 1.5)`, `Radian(__unchecked: (), segmentAngle)`, `Radian(__unchecked: (), halfSweepRaw / 2)`
- **Proposed**: Use typed Radian factory methods. `Radian.pi` already exists. For `Scalar.pi * 1.5`, use `Radian.pi + Radian.halfPi` or add a `Radian.threeHalfPi` constant. For arithmetic results, consider typed Radian arithmetic operators.
- **Rationale**: [PATTERN-021] states typed arithmetic MUST be preferred over `__unchecked` when a typed operator exists. `Radian` has `.pi`, `.halfPi`, `.twoPi` constants and `+`/`-` operators that would replace most of these.

### Finding [GEO-018]: `__unchecked` Radian construction in Ellipse
- **Severity**: MEDIUM
- **Requirement**: [PATTERN-021]
- **Location**: Geometry.Ellipse.swift:84, 93, 403, 416, 682-683, 761, 908, 963, 1130-1132, 1145-1147
- **Current**: 16 instances of `Radian(__unchecked: (), ...)` across Ellipse and Ellipse.Arc.
- **Proposed**: Use `Radian.zero` where appropriate, or typed `Radian` arithmetic. For angle computation results (e.g., `atan2` returns), consider adding a factory method like `Radian.from(rawAngle:)`.
- **Rationale**: Same as GEO-017. Many of these could use existing Radian operators or constants.

### Finding [GEO-019]: `__unchecked` Radian construction in Ngon regular polygon factories
- **Severity**: MEDIUM
- **Requirement**: [PATTERN-021]
- **Location**: Geometry.Ngon.swift:495, 502, 536, 551, 559
- **Current**: `Radian<Scalar>(__unchecked: (), piOverNValue)`, `Radian<Scalar>(__unchecked: (), angleValue)` repeated in Double and Float overloads.
- **Proposed**: Add `Radian.init(_ scalar: Scalar)` or use `Radian.pi / Scalar(N)` if typed division exists.
- **Rationale**: [PATTERN-021]. These are systematic constructions where a validated Radian init would eliminate all `__unchecked` usage.

### Finding [GEO-020]: `__unchecked` in Ray cardinal direction vectors
- **Severity**: MEDIUM
- **Requirement**: [PATTERN-021]
- **Location**: Geometry.Ray.swift:367-370
- **Current**: `.init(__unchecked: (), 1)`, `.init(__unchecked: (), 0)`, `.init(__unchecked: (), -1)` for creating unit vectors for cardinal directions.
- **Proposed**: Use typed constructors. `Linear.Dx(1)` and `Linear.Dy(0)` should be available via `ExpressibleByIntegerLiteral`.
- **Rationale**: If `Dx` and `Dy` conform to `ExpressibleByIntegerLiteral`, these can be written as `.init(1)` without `__unchecked`.

### Finding [GEO-021]: `Geometry.Magnitude` wraps `Linear.Magnitude` creating double-wrapping
- **Severity**: MEDIUM
- **Requirement**: [IMPL-002]
- **Location**: Geometry.swift:137-206
- **Current**: `Geometry.Magnitude` has `rawValue: Linear<Scalar, Space>.Magnitude`, and `Linear.Magnitude` itself wraps `Scalar`. So `Geometry.Magnitude.value` goes through `rawValue.rawValue` (line 194-195).
- **Proposed**: Consider whether `Geometry.Magnitude` adds value over just using `Linear.Magnitude` directly. The projections (`.width`, `.height`) could be extension methods on `Linear.Magnitude` instead.
- **Rationale**: Double-wrapping creates `.rawValue.rawValue` chains, which [IMPL-002] discourages.

### Finding [GEO-022]: `Geometry.Hypercube` uses `.rawValue` for all computed properties
- **Severity**: MEDIUM
- **Requirement**: [PATTERN-017]
- **Location**: Geometry.Hypercube.swift:104, 114-115, 121, 128, 173, 178-179, 189, 196-197, 201-203, 235
- **Current**: Properties like `side`, `diagonal`, `area`, `perimeter`, `width`, `height` all extract `halfSide.rawValue` then multiply by 2: `halfSide.rawValue * 2`.
- **Proposed**: Add a typed `Magnitude * Int` or `Magnitude * Scale` operator so `halfSide * 2` works directly, or store the full side length instead of half-side.
- **Rationale**: Every computed property extracts `.rawValue` to perform basic arithmetic (doubling). This is infrastructure gap territory per [IMPL-000].

### Finding [GEO-023]: `Geometry.Orthotope` BinaryInteger init uses `.rawValue` chains
- **Severity**: MEDIUM
- **Requirement**: [PATTERN-017]
- **Location**: Geometry.Orthotope.swift:230-242
- **Current**: `let halfWidth = (urx.rawValue - llx.rawValue) / 2` followed by raw-value reconstruction.
- **Proposed**: Use typed arithmetic: `(urx - llx) / 2` should yield a typed displacement, then construct Width from that.
- **Rationale**: The FloatingPoint overload (lines 172-188) uses typed operations. The BinaryInteger overload falls back to `.rawValue` extraction. Either typed operators for BinaryInteger are missing (infrastructure gap) or the typed versions can be used here.

### Finding [GEO-024]: Duplicated regular polygon factory for Double and Float
- **Severity**: MEDIUM
- **Requirement**: [IMPL-INTENT]
- **Location**: Geometry.Ngon.swift:487-540 (Double), 544-597 (Float)
- **Current**: Three factory methods (`regular(sideLength:)`, `regular(circumradius:)`, `regular(inradius:)`) are copy-pasted verbatim for `Scalar == Double` and `Scalar == Float`.
- **Proposed**: Constrain on `Scalar: BinaryFloatingPoint & Numeric.Transcendental` (or just `BinaryFloatingPoint`) to unify the two copies into one.
- **Rationale**: Code duplication across concrete-type constraints when a protocol constraint would suffice. This is a mechanical issue that obscures intent.

### Finding [GEO-025]: Duplicated triangle `.angles` for Double and Float
- **Severity**: MEDIUM
- **Requirement**: [IMPL-INTENT]
- **Location**: Geometry.Ngon.swift:865-900 (Double), 902-937 (Float)
- **Current**: Identical law-of-cosines implementation for `Scalar == Double` and `Scalar == Float`.
- **Proposed**: Unify under `Scalar: BinaryFloatingPoint & Numeric.Transcendental` or similar.
- **Rationale**: Same as GEO-024. The only difference is the concrete scalar type.

### Finding [GEO-026]: `.rawValue` in `Polygon.boundingBox`
- **Severity**: MEDIUM
- **Requirement**: [PATTERN-017]
- **Location**: Geometry.Polygon.swift:137-154
- **Current**: `var minX = first.x.rawValue` / `maxX = max(maxX, vertex.x.rawValue)` etc.
- **Proposed**: Use typed `X` comparisons with `Swift.min`/`Swift.max`, which work on `Comparable` types. The `Ngon.boundingBox` (Geometry.Ngon.swift:327-347) already does this correctly with typed values.
- **Rationale**: The Ngon version uses typed comparisons (`min(minX, vertices[i].x)`), but the Polygon version extracts raw values. Inconsistency within the same package.

### Finding [GEO-027]: `Polygon.contains` uses `.rawValue` for ray casting
- **Severity**: MEDIUM
- **Requirement**: [PATTERN-017]
- **Location**: Geometry.Polygon.swift:238-249
- **Current**: `vi.y.rawValue > point.y.rawValue`, `vi.x.rawValue + slope * (point.y.rawValue - vi.y.rawValue)`
- **Proposed**: The `Ngon.contains` (Geometry.Ngon.swift:423-448) uses a mix of typed and raw. Both could benefit from typed slope calculation, but the ray-casting algorithm inherently mixes coordinates. The Polygon version extracts more eagerly than necessary.
- **Rationale**: Compare with `Ngon.contains` which uses `(vj.x - vi.x).rawValue` -- extracting at the last moment rather than at entry.

### Finding [GEO-028]: `Curvature` is a top-level type, not nested in `Geometry`
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-001]
- **Location**: Curvature.swift:17
- **Current**: `public enum Curvature: Sendable, Hashable, Codable, CaseIterable`
- **Proposed**: This may be intentional since `Curvature` is domain-independent and not parameterized by `Scalar`/`Space`. However, it breaks the pattern of all other types being nested in `Geometry`. Consider `Geometry.Curvature` if it's geometry-specific, or leave as-is if it's a general algebraic concept (which the Z2 group description suggests).
- **Rationale**: Inconsistency with the rest of the module. The `Curvature.Value<Payload>` typealias uses `Pair` from algebra-primitives, suggesting it may belong at a different layer.

### Finding [GEO-029]: `LineSegment` backward-compat typealias
- **Severity**: MEDIUM
- **Requirement**: [API-NAME-001]
- **Location**: Geometry.Line.swift:356
- **Current**: `public typealias LineSegment = Line.Segment`
- **Proposed**: Remove this typealias. It enshrines a compound name (`LineSegment`) as a public API surface item. If backward compatibility is needed, mark as deprecated.
- **Rationale**: [API-NAME-001] forbids compound names. A backward-compat typealias that IS a compound name propagates the violation to consumer code.

---

## LOW Findings

### Finding [GEO-030]: Arithmetic file has a typo in filename
- **Severity**: LOW
- **Requirement**: General quality
- **Location**: `Geometry+Arithmatic.swift`
- **Current**: "Arithmatic" (misspelled)
- **Proposed**: `Geometry+Arithmetic.swift`
- **Rationale**: "Arithmetic" is the correct English spelling.

### Finding [GEO-031]: Seven typealiases all resolve to the same type
- **Severity**: LOW
- **Requirement**: [IMPL-INTENT]
- **Location**: Geometry.swift:78-108
- **Current**: `Length`, `Radius`, `Diameter`, `Distance`, `Circumference`, `Perimeter`, `ArcLength` all resolve to `Linear<Scalar, Space>.Magnitude`.
- **Proposed**: Either keep as documentation-only intent markers (acceptable) or elevate some to newtypes if dimensional distinction is important (e.g., `Radius` vs `Perimeter` should not be freely interchangeable).
- **Rationale**: Typealiases provide zero type safety. `radius + perimeter` compiles without complaint. If these concepts are truly distinct, they should be distinct types. If not, having 7 names for the same type adds API surface without value.

### Finding [GEO-032]: `bezierCurves` property on Ball uses intermediate variable `k`
- **Severity**: LOW
- **Requirement**: [IMPL-030]
- **Location**: Geometry.Ball.swift:449
- **Current**: `let k: Geometry.Radius = radius * Scale(0.5522847498)` then used 8 times.
- **Proposed**: This is justified under [IMPL-EXPR-001] boundary condition 1 (multi-use). No change needed.
- **Rationale**: Listing for completeness. Multi-use justifies the intermediate variable.

### Finding [GEO-033]: `for i in 0..<N` loop pattern repeated across InlineArray operations
- **Severity**: LOW
- **Requirement**: [IMPL-033]
- **Location**: Geometry.Size.swift (5 loops), Geometry.Ngon.swift (12 loops), Geometry+Arithmatic.swift (6 loops)
- **Current**: Manual `for i in 0..<N { result[i] = ... }` for element-wise operations on InlineArray.
- **Proposed**: This is currently the only way to iterate InlineArray. If InlineArray gains `.map` or `.forEach`, these should migrate. As-is, this is the infrastructure limit, not a code quality issue.
- **Rationale**: InlineArray iteration infrastructure is missing, making these loops the mechanism of necessity.

### Finding [GEO-034]: `isOnBoundary` in Polygon uses intermediate `threshold` variable
- **Severity**: LOW
- **Requirement**: [IMPL-030]
- **Location**: Geometry.Polygon.swift:257
- **Current**: `let threshold = Geometry.Distance(.ulpOfOne * 100)`
- **Proposed**: Inline: `if edge.distance(to: point) < Geometry.Distance(.ulpOfOne * 100)`
- **Rationale**: The variable name "threshold" restates the expression. Minor.

### Finding [GEO-035]: `bezierStartPoint` on Ball could be derived from `bezierCurves`
- **Severity**: LOW
- **Requirement**: [IMPL-INTENT]
- **Location**: Geometry.Ball.swift:487-490
- **Current**: Separate property `bezierStartPoint` that computes `center.x + radius, center.y`.
- **Proposed**: Could delegate to `bezierCurves.first?.start` but the current implementation avoids computing all 4 curves. Acceptable as-is for performance.
- **Rationale**: Minor duplication of the "3 o'clock" point computation.

### Finding [GEO-036]: `Ngon` has both generic `contains(_:)` (ray casting) and `containsBarycentric(_:)` (N==3)
- **Severity**: LOW
- **Requirement**: [IMPL-INTENT]
- **Location**: Geometry.Ngon.swift:422-448 (generic), 1015-1020 (barycentric)
- **Current**: Two different containment algorithms with different API surfaces.
- **Proposed**: The triangle-specific barycentric method is more robust and should ideally shadow the generic `contains` for N==3. Currently it's a separate method, requiring callers to know which to use.
- **Rationale**: API discoverability issue. A caller working with `Triangle` might use the less-robust generic `contains` without knowing `containsBarycentric` exists.

### Finding [GEO-037]: `lengthSquared` on Line.Segment returns raw `Scalar` instead of `Linear.Area`
- **Severity**: LOW
- **Requirement**: [IMPL-002]
- **Location**: Geometry.Line.swift:273
- **Current**: `public var lengthSquared: Scalar { vector.lengthSquared }`
- **Proposed**: Return `Linear<Scalar, Space>.Area` since squared length has area dimensions.
- **Rationale**: Returning raw `Scalar` for a squared-length quantity discards dimensional information.

### Finding [GEO-038]: File header comment in `Geometry+Arithmatic.swift` says "File.swift"
- **Severity**: LOW
- **Requirement**: General quality
- **Location**: Geometry+Arithmatic.swift:3
- **Current**: `//  File.swift`
- **Proposed**: `//  Geometry+Arithmetic.swift`
- **Rationale**: Copy-paste artifact. The header comment names the wrong file.

---

## Justified .rawValue Usage (Not Findings)

The following `.rawValue` usages are justified per [PATTERN-017] (same-package implementation) or because the algorithms inherently mix coordinate components in ways that typed arithmetic cannot express:

1. **Bounding box calculations** (Arc, Ellipse, Ellipse.Arc) -- inherently mix X and Y coordinates for min/max tracking.
2. **Bezier control point calculations** (Arc-to-Bezier, Ellipse-to-Bezier) -- affine transformations that mix coordinates.
3. **Circle-line intersection** (Ball.swift:289-312) -- quadratic formula solving inherently mixes coordinate components.
4. **Circle-circle intersection** (Ball.swift:316-360) -- algebraic geometry requiring raw arithmetic.
5. **Centroid calculation** (Ngon, Polygon) -- weighted coordinate mixing.
6. **Circumcircle/Incircle** (Ball.swift:501-578) -- determinant-based formulas.
7. **Operator implementations** in `Geometry+Arithmatic.swift` -- same-package boundary implementations per [PATTERN-017].
8. **SVG endpoint-to-center arc conversion** (Ellipse.swift:768-927) -- W3C spec algorithm with inherent coordinate mixing.

These account for roughly 160 of the 252 `.rawValue` usages. The remaining ~92 are covered by the findings above.
