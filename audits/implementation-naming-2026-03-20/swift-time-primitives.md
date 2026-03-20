# swift-time-primitives Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: naming [API-NAME-*], implementation [IMPL-*]
**Package**: swift-time-primitives (3 modules: Time Primitives Core, Time Julian Primitives, Time Primitives)
**Files audited**: 39 .swift files

## Summary

| Severity | Count |
|----------|-------|
| HIGH     | 5     |
| MEDIUM   | 9     |
| LOW      | 5     |
| INFO     | 3     |
| **Total**| **22**|

## Findings

### HIGH

#### [TIME-001] .rawValue at call sites in Julian Day conversion algorithms
**Rule**: [IMPL-002], [PATTERN-017]
**Severity**: HIGH
**Files**:
- `Time Julian Primitives/Time.Julian.Day+Time.swift:25-27`
- `Time Julian Primitives/Time.Julian.Day+Time.swift:61`
- `Time Julian Primitives/Time.Julian.Day+Properties.swift:23`
- `Time Julian Primitives/Instant+Julian.swift:46`

**Description**: Six `.rawValue` accesses in Julian conversion code extract raw `Int`/`Double` values for computation. These are domain algorithm implementations, not boundary code.

```swift
// Time.Julian.Day+Time.swift:25-27
let year = time.year.rawValue
let month = time.month.rawValue
let day = time.day.rawValue

// Time.Julian.Day+Time.swift:61
let jd = julianDay.rawValue

// Time.Julian.Day+Properties.swift:23
rawValue - Time.Julian.Offset.modified.rawValue

// Instant+Julian.swift:46
let days = offset.rawValue
```

**Recommendation**: For `Time.Year`, `Time.Month`, and `Time.Month.Day`, the `.rawValue` access is forced by the refinement type design (these types store `rawValue`/`value` directly with no arithmetic operators). The Julian Day `.rawValue` accesses extract from `Tagged<Coordinate.X<Space>, Double>`, which is a Dimension_Primitives type. The `modified` property returns `Double` instead of staying in the Julian domain. Consider providing typed subtraction or an accessor that stays within the Julian type system.

---

#### [TIME-002] .rawValue at call sites in Zeller's congruence algorithm
**Rule**: [IMPL-002], [PATTERN-017]
**Severity**: HIGH
**File**: `Time Primitives Core/Time.Week.Day.swift:74-75, 83`

**Description**: Three `.rawValue` accesses to extract year, month, and day values for the Zeller algorithm.

```swift
var y = year.rawValue
var m = month.rawValue
let q = day.rawValue
```

**Recommendation**: Same structural issue as [TIME-001] -- refinement types lack arithmetic operators so `.rawValue` extraction is currently necessary for algorithms. Consider adding typed arithmetic operations to `Time.Year`, `Time.Month`, `Time.Month.Day` if these are intended to participate in computation at L1.

---

#### [TIME-003] .rawValue at call sites in epoch conversion algorithms
**Rule**: [IMPL-002], [PATTERN-017]
**Severity**: HIGH
**File**: `Time Primitives Core/Time.Epoch.Conversion.swift:176, 182, 194, 196, 201`

**Description**: Five `.rawValue` accesses on `year`, `month`, and `day` in the core epoch conversion algorithm.

```swift
let yearsSince1970 = year.rawValue - 1970       // :176
let yearBefore = year.rawValue - 1              // :182
let monthDays = ...daysInMonths(year: year.rawValue)  // :194
for m in 0..<(month.rawValue - 1) {             // :196
days += day.rawValue - 1                         // :201
```

**Recommendation**: These are internal to the Conversion algorithm and represent the core boundary where typed values meet raw arithmetic. The `daysInMonths(year: Int)` overload forces `.rawValue` extraction. Consider an overload accepting `Time.Year` directly.

---

#### [TIME-004] .rawValue at call sites in Gregorian calendar algorithms
**Rule**: [IMPL-002], [PATTERN-017]
**Severity**: HIGH
**File**: `Time Primitives Core/Time.Calendar.Gregorian.swift:64, 95`

**Description**: Two `.rawValue` accesses in leap year and days-in-month calculations.

```swift
let y = year.rawValue                         // :64 (isLeapYear)
return monthArray[month.rawValue - 1]         // :95 (daysInMonth)
```

**Recommendation**: `isLeapYear` could accept and work through `Time.Year` arithmetic if `Time.Year` supported modulo. The `month.rawValue - 1` for array indexing is a boundary access that is hard to avoid without an `Index` type.

---

#### [TIME-005] .rawValue at call sites in Easter algorithm
**Rule**: [IMPL-002], [PATTERN-017]
**Severity**: HIGH
**File**: `Time Primitives Core/Time.Calendar.Gregorian.Easter.swift:45`

**Description**: One `.rawValue` access to extract year value for the Easter algorithm.

```swift
let y = year.rawValue
```

**Recommendation**: Same structural issue -- pure arithmetic algorithm requires raw integer extraction.

---

### MEDIUM

#### [TIME-006] __unchecked construction in Julian Day -> Time conversion
**Rule**: [IMPL-040], [PATTERN-021]
**Severity**: MEDIUM
**File**: `Time Julian Primitives/Time.Julian.Day+Time.swift:100-111`

**Description**: Constructs `Time` via `__unchecked` from computed values. The Richards algorithm guarantees valid ranges by construction, so this is defensible, but no safety comment accompanies the call.

```swift
return Time(
    __unchecked: (),
    year: year, month: month, day: day,
    hour: hour, minute: minute, second: second,
    millisecond: nanoseconds / 1_000_000,
    microsecond: (nanoseconds % 1_000_000) / 1000,
    nanosecond: nanoseconds % 1000
)
```

**Recommendation**: Add a `// SAFE:` comment explaining why the algorithm output is guaranteed valid (as done in `Time.swift:194`).

---

#### [TIME-007] __unchecked construction in Julian Day -> Instant conversion
**Rule**: [IMPL-040], [PATTERN-021]
**Severity**: MEDIUM
**File**: `Time Julian Primitives/Instant+Julian.swift:55-59`

**Description**: Constructs `Instant` via `__unchecked` from Julian Day arithmetic. The nanosecond value computed from `fractionalSeconds * 1_000_000_000` could theoretically overflow `Int32` range or be negative depending on rounding.

```swift
return Instant(
    __unchecked: (),
    secondsSinceUnixEpoch: wholeSeconds,
    nanosecondFraction: nanoseconds
)
```

**Recommendation**: This is a genuine concern -- `fractionalSeconds` could be slightly negative due to floating-point rounding, producing a negative `nanoseconds`. Add bounds clamping or a `// SAFE:` comment with justification.

---

#### [TIME-008] __unchecked construction in epoch constant definitions
**Rule**: [IMPL-040]
**Severity**: MEDIUM
**File**: `Time Primitives Core/Time.Epoch.swift:40, 55, 71, 86, 104, 122`

**Description**: Six `__unchecked` constructions for epoch constants (unix, ntp, gps, tai, windowsFileTime, appleAbsolute). All values are compile-time literals.

**Recommendation**: These are acceptable -- values are constant and verified by inspection. However, the `@_spi(Internal)` initializer is `public`, meaning external consumers could misuse it. The `__unchecked` naming convention makes this clear, but consider whether `internal`-only epoch construction is feasible.

---

#### [TIME-009] Compound property names on Duration extensions
**Rule**: [API-NAME-002]
**Severity**: MEDIUM
**File**: `Time Primitives Core/Duration+Conversions.swift:31, 44, 56, 68`

**Description**: Four compound property names: `inSeconds`, `inMilliseconds`, `inMicroseconds`, `inNanoseconds`.

```swift
public var inSeconds: Double
public var inMilliseconds: Double
public var inMicroseconds: Double
public var inNanoseconds: Double
```

**Recommendation**: Per [API-NAME-002], these should use nested accessors. Possible pattern: `duration.as.seconds`, `duration.as.milliseconds`, or `duration.to.seconds`. However, these are extensions on `Swift.Duration` (stdlib type), which limits namespace nesting options. Assess whether the compound name ban applies to stdlib extensions.

---

#### [TIME-010] Compound property name `isLeapYear`
**Rule**: [API-NAME-002]
**Severity**: MEDIUM
**Files**:
- `Time Primitives Core/Time.Year.swift:49`
- `Time Primitives Core/Time.Calendar.Gregorian.swift:63, 70`
- `Time Primitives Core/Time.Calendar.swift:24`

**Description**: `isLeapYear` is a compound property/method name used across multiple types. The `is` prefix is Swift convention for Boolean properties, which creates tension with [API-NAME-002].

**Recommendation**: Swift API Design Guidelines specifically endorse `is`-prefixed Boolean properties. This is arguably an exception to [API-NAME-002] for Boolean accessors. However, `isLeapYear` is still compound (`is` + `Leap` + `Year`). A nested alternative would be `year.leap` (returns Bool). Flag for design decision.

---

#### [TIME-011] Compound method names: `daysInMonth`, `daysInMonths`, `secondsSinceEpoch`, `daysSinceEpoch`
**Rule**: [API-NAME-002]
**Severity**: MEDIUM
**Files**:
- `Time Primitives Core/Time.Calendar.Gregorian.swift:92, 100, 110` (`daysInMonth`, `daysInMonths`)
- `Time Primitives Core/Time.Epoch.Conversion.swift:24, 43, 170` (`secondsSinceEpoch`, `daysSinceEpoch`)
- `Time Primitives Core/Time.swift:383, 391` (`secondsSinceEpoch`)

**Description**: Multiple compound method/property names that join domain concepts.

**Recommendation**: These are domain-standard terms in calendar/epoch computation. Possible nested alternatives:
- `Time.Calendar.Gregorian.days(in: month, year: year)` -- already partially exists via `Time.Month.days(in:)`
- `Time.Epoch.Conversion.seconds(since: .epoch, from: components)` -- restructure around `.since`
Flag for design decision on whether domain-standard compound terms are exempt.

---

#### [TIME-012] Compound property names on Instant
**Rule**: [API-NAME-002]
**Severity**: MEDIUM
**File**: `Time Primitives Core/Instant.swift:26, 29`

**Description**: `secondsSinceUnixEpoch` and `nanosecondFraction` are compound stored property names.

**Recommendation**: These are the type's core stored properties and serve as precise domain identifiers. Renaming would reduce clarity. However, strictly per [API-NAME-002], they are compound. Possible nested alternatives: `instant.seconds.sinceUnixEpoch` or `instant.epoch.seconds`, but these would require structural changes. Flag for design decision.

---

#### [TIME-013] Compound static constant name `windowsFileTime`
**Rule**: [API-NAME-002]
**Severity**: MEDIUM
**File**: `Time Primitives Core/Time.Epoch.swift:102`

**Description**: `windowsFileTime` is a compound static constant name.

**Recommendation**: Could be `Time.Epoch.windows.fileTime` with a nested namespace, or `Time.Epoch.ntfs`. The current name joins three concepts.

---

#### [TIME-014] Compound enum case name `compactName`
**Rule**: [API-NAME-002]
**Severity**: MEDIUM
**File**: `Time Primitives Core/Duration+Format.swift:100`

**Description**: `compactName` is a compound enum case in `Time.Format.Notation`.

**Recommendation**: Could be `.compact` instead of `.compactName`.

---

### LOW

#### [TIME-015] Magic number 86400.0 duplicated in Julian conversions
**Rule**: [IMPL-INTENT]
**Severity**: LOW
**Files**:
- `Time Julian Primitives/Instant+Julian.swift:23, 48`
- `Time Julian Primitives/Time.Julian.Day+Time.swift:40`

**Description**: The constant `86400.0` (seconds per day) appears as a raw literal in Julian conversion code, duplicating `Time.Calendar.Gregorian.TimeConstants.secondsPerDay`. The Julian module uses `let secondsPerDay: Double = 86400.0` as a local variable instead of referencing the shared constant.

**Recommendation**: Use `Double(Time.Calendar.Gregorian.TimeConstants.secondsPerDay)` or introduce a Julian-specific constant. Reduces duplication and improves intent clarity.

---

#### [TIME-016] `.value` accessor inconsistency with `.rawValue`
**Rule**: [IMPL-INTENT]
**Severity**: LOW
**Files**: All sub-second types (Hour, Minute, Second, Millisecond, Microsecond, Nanosecond, Picosecond, Femtosecond, Attosecond, Zeptosecond, Yoctosecond) use `.value`, while Month, Year, Month.Day use `.rawValue`.

**Description**: The refinement types in this package have two different property naming conventions:
- `.value`: Hour, Minute, Second, Millisecond, Microsecond, Nanosecond, Picosecond, Femtosecond, Attosecond, Zeptosecond, Yoctosecond
- `.rawValue`: Year (via RawRepresentable), Month (via RawRepresentable), Month.Day

This creates inconsistency. Call sites accessing `time.hour.value` vs `time.month.rawValue` use different property names for the same conceptual operation (extract the underlying integer).

**Recommendation**: Unify on a single convention. Since `Year` and `Month` conform to `RawRepresentable`, `.rawValue` is mandated there. Consider adding `RawRepresentable` conformance to all refinement types, or add `.rawValue` computed properties as aliases.

---

#### [TIME-017] Stale comment references `.value` on Month
**Rule**: [IMPL-INTENT]
**Severity**: LOW
**File**: `Time Primitives Core/Time.Calendar.Gregorian.swift:94`

**Description**: Comment says `month.value` but the property is `month.rawValue`:

```swift
// SAFE: month.value is guaranteed to be in range 1-12 by Time.Month invariant
return monthArray[month.rawValue - 1]
```

**Recommendation**: Fix comment to say `month.rawValue`.

---

#### [TIME-018] Compound property `julianDay` on Time and Instant
**Rule**: [API-NAME-002]
**Severity**: LOW
**Files**:
- `Time Julian Primitives/Instant+Julian.swift:63`
- `Time Julian Primitives/Time.Julian.Day+Time.swift:119`

**Description**: `julianDay` is a compound property name. However, `Julian.Day` is itself a domain term, and `.julian.day` would require a `Julian` namespace on `Time` which already exists -- but these are extensions on the value types, not the namespace.

**Recommendation**: Could be `time.julian.day` if a `julian` computed property returning a namespace proxy were introduced. Low priority -- the compound here mirrors the type name `Time.Julian.Day`.

---

#### [TIME-019] `totalNanoseconds` compound property and method
**Rule**: [API-NAME-002]
**Severity**: LOW
**File**: `Time Primitives Core/Time.swift:321, 333`

**Description**: `totalNanoseconds` is a compound property/method name.

**Recommendation**: Could be `nanoseconds.total` via a nested accessor, but this is a derived computation property on `Time` and renaming would be a breaking change. Low priority.

---

### INFO

#### [TIME-020] __unchecked construction pattern is consistent and well-documented
**Rule**: [IMPL-040]
**Severity**: INFO

**Description**: The package uses `__unchecked` consistently across 17 call sites. All unchecked initializers are either `@_spi(Internal) public` (Time) or `internal` (refinement types). The `__unchecked` naming convention makes unsafe construction visible. Most call sites have `// SAFE:` comments explaining the invariant guarantee.

---

#### [TIME-021] One-type-per-file rule is well followed
**Rule**: [API-IMPL-005]
**Severity**: INFO

**Description**: All 39 files follow the one-type-per-file rule. Each refinement type (Hour, Minute, Second, etc.) has its own file. Extension files use the `Type+Extension.swift` naming pattern correctly. Namespace files (`Time.Week.swift`, `Time.Julian.swift`, `Time.Timezone.swift`) contain only the empty enum declaration.

---

#### [TIME-022] Naming pattern follows Nest.Name correctly
**Rule**: [API-NAME-001]
**Severity**: INFO

**Description**: All types use the `Nest.Name` pattern correctly:
- `Time.Year`, `Time.Month`, `Time.Month.Day`, `Time.Hour`, `Time.Minute`, `Time.Second`
- `Time.Millisecond`, `Time.Microsecond`, `Time.Nanosecond`, etc.
- `Time.Calendar`, `Time.Calendar.Gregorian`, `Time.Calendar.Gregorian.Easter`
- `Time.Epoch`, `Time.Epoch.Conversion`
- `Time.Week`, `Time.Week.Day`
- `Time.Julian`, `Time.Julian.Day`, `Time.Julian.Offset`, `Time.Julian.Space`
- `Time.Timezone`, `Time.Timezone.Offset`
- `Time.Format`, `Time.Format.Unit`, `Time.Format.Notation`

No compound type names found. The `Instant` and `Duration` types are top-level (not nested under `Time`), which is a deliberate design choice for ergonomics.

---

## Structural Summary

### .rawValue usage (33 occurrences)

| Category | Count | Assessment |
|----------|-------|------------|
| Internal to type definition (init, stored property, Comparable) | 14 | Acceptable -- boundary code |
| Algorithm extraction (Zeller, Easter, epoch, Gregorian, Julian) | 13 | Findings [TIME-001] through [TIME-005] |
| Int comparison operators (==) | 4 | Acceptable -- explicit cross-domain comparison |
| Doc comment references | 2 | N/A |

### __unchecked usage (17 occurrences)

| Category | Count | Assessment |
|----------|-------|------------|
| Epoch constant definitions | 6 | Acceptable -- compile-time literals |
| Algorithm output construction (epoch, Julian) | 5 | Findings [TIME-006], [TIME-007] |
| Instant arithmetic normalization | 2 | Acceptable -- post-normalization values guaranteed valid |
| Time convenience initializers | 4 | Acceptable -- computed from validated algorithms |

### Key design tension

The `.rawValue` findings ([TIME-001] through [TIME-005]) are all structurally the same issue: the refinement types (`Time.Year`, `Time.Month`, `Time.Month.Day`) are designed as validation wrappers without arithmetic operators. Every algorithm that needs to compute with these values must extract via `.rawValue`. This is a design-level tension between type safety (preventing invalid values) and intent-first code (avoiding raw value extraction).

**Options**:
1. **Add typed arithmetic to refinement types** -- e.g., `Time.Year` supports `- 1970`, `% 4`, `/ 100`. This is the [IMPL-002] ideal but increases API surface significantly.
2. **Accept .rawValue in algorithm code** -- Treat algorithm implementations as boundary code where `.rawValue` extraction is expected. Document this as a design decision.
3. **Introduce algorithm-internal typealiases** -- Use `typealias RawYear = Int` within algorithm bodies to make the domain crossing explicit.

Option 2 is the pragmatic choice for time algorithms. The `.rawValue` accesses are confined to internal/algorithm code and do not leak to consumer call sites.
