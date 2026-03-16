# Time/Duration API Prior Art Across Languages

<!--
---
type: research
created: 2026-02-27
status: COMPLETE
scope: time-primitives API design
---
-->

## Purpose

Survey how major programming languages design their time/duration APIs, focusing on:
1. Duration unit-conversion accessors
2. Instant/timestamp stored-component exposure
3. Consistency of accessor patterns across related types

---

## 1. Rust: `std::time`

### 1.1 `std::time::Duration`

**Storage**: Two fields internally -- whole seconds (`u64`) and subsecond nanoseconds (`u32`).

**Total-conversion methods** (entire duration expressed in one unit):

| Method | Signature | Returns |
|--------|-----------|---------|
| `as_secs` | `pub const fn as_secs(&self) -> u64` | Whole seconds (truncated) |
| `as_millis` | `pub const fn as_millis(&self) -> u128` | Total milliseconds |
| `as_micros` | `pub const fn as_micros(&self) -> u128` | Total microseconds |
| `as_nanos` | `pub const fn as_nanos(&self) -> u128` | Total nanoseconds |
| `as_secs_f64` | `pub fn as_secs_f64(&self) -> f64` | Fractional seconds as f64 |
| `as_secs_f32` | `pub fn as_secs_f32(&self) -> f32` | Fractional seconds as f32 |

**Subsecond-component methods** (fractional part only, less than one second):

| Method | Signature | Returns |
|--------|-----------|---------|
| `subsec_millis` | `pub const fn subsec_millis(&self) -> u32` | 0..999 |
| `subsec_micros` | `pub const fn subsec_micros(&self) -> u32` | 0..999_999 |
| `subsec_nanos` | `pub const fn subsec_nanos(&self) -> u32` | 0..999_999_999 |

**Pattern**: Flat namespace, `as_` prefix for total conversions, `subsec_` prefix for fractional components. Compound names throughout (e.g., `as_secs_f64`, `subsec_nanos`).

### 1.2 `std::time::Instant`

**Opaque**: No public fields. No method to obtain seconds-since-epoch. Only relative methods:

| Method | Signature |
|--------|-----------|
| `elapsed` | `pub fn elapsed(&self) -> Duration` |
| `duration_since` | `pub fn duration_since(&self, earlier: Instant) -> Duration` |
| `checked_duration_since` | `pub fn checked_duration_since(&self, earlier: Instant) -> Option<Duration>` |
| `saturating_duration_since` | `pub fn saturating_duration_since(&self, earlier: Instant) -> Duration` |

**Design rationale**: `Instant` uses a monotonic clock with no defined epoch. Epoch-relative access is deliberately omitted.

### 1.3 `std::time::SystemTime`

**Epoch-relative** via subtraction from `UNIX_EPOCH`:

```rust
let duration = system_time.duration_since(UNIX_EPOCH)?;  // -> Duration
duration.as_secs()       // seconds since epoch
duration.subsec_nanos()  // nanosecond remainder
```

No direct `.seconds()` or `.nanoseconds()` on `SystemTime` itself. You obtain a `Duration` and use its accessors.

### 1.4 `chrono::TimeDelta` (formerly `chrono::Duration`)

**Storage**: Seconds (`i64`) + nanoseconds (`u32`) internally.

**Total-conversion methods**:

| Method | Signature | Returns |
|--------|-----------|---------|
| `num_weeks` | `fn num_weeks(&self) -> i64` | Total whole weeks |
| `num_days` | `fn num_days(&self) -> i64` | Total whole days |
| `num_hours` | `fn num_hours(&self) -> i64` | Total whole hours |
| `num_minutes` | `fn num_minutes(&self) -> i64` | Total whole minutes |
| `num_seconds` | `fn num_seconds(&self) -> i64` | Total whole seconds |
| `num_milliseconds` | `fn num_milliseconds(&self) -> i64` | Total milliseconds |
| `num_microseconds` | `fn num_microseconds(&self) -> Option<i64>` | Total microseconds, `None` on overflow |
| `num_nanoseconds` | `fn num_nanoseconds(&self) -> Option<i64>` | Total nanoseconds, `None` on overflow |

**Subsecond-component methods**:

| Method | Signature | Returns |
|--------|-----------|---------|
| `subsec_nanos` | `fn subsec_nanos(&self) -> i32` | Fractional nanoseconds |
| `subsec_micros` | `fn subsec_micros(&self) -> i32` | Fractional microseconds |
| `subsec_millis` | `fn subsec_millis(&self) -> i32` | Fractional milliseconds |

**Pattern**: `num_` prefix for totals (instead of `as_`), `subsec_` prefix for fractional parts. Still compound names.

### 1.5 `chrono::NaiveDateTime`

**Epoch-timestamp methods**:

| Method | Signature | Returns |
|--------|-----------|---------|
| `timestamp` | `fn timestamp(&self) -> i64` | Non-leap seconds since 1970-01-01 |
| `timestamp_millis` | `fn timestamp_millis(&self) -> i64` | Total milliseconds since epoch |
| `timestamp_micros` | `fn timestamp_micros(&self) -> i64` | Total microseconds since epoch |
| `timestamp_nanos_opt` | `fn timestamp_nanos_opt(&self) -> Option<i64>` | Total nanoseconds, `None` on overflow |
| `timestamp_subsec_millis` | `fn timestamp_subsec_millis(&self) -> u32` | 0..999 |
| `timestamp_subsec_micros` | `fn timestamp_subsec_micros(&self) -> u32` | 0..999_999 |
| `timestamp_subsec_nanos` | `fn timestamp_subsec_nanos(&self) -> u32` | 0..999_999_999 |

**Pattern**: `timestamp` prefix with `_subsec_` infix for fractional parts. Compound names, no nesting.

---

## 2. Java: `java.time`

### 2.1 `java.time.Duration`

**Storage**: Two fields -- `seconds` (`long`) and `nanos` (`int`, 0..999_999_999).

**Component-extraction methods** (stored representation):

| Method | Signature | Returns |
|--------|-----------|---------|
| `getSeconds` | `public long getSeconds()` | Whole-seconds field |
| `getNano` | `public int getNano()` | Nanosecond-within-second field (0..999_999_999) |

**Total-conversion methods** (entire duration in one unit):

| Method | Signature | Returns |
|--------|-----------|---------|
| `toDays` | `public long toDays()` | Total whole days |
| `toHours` | `public long toHours()` | Total whole hours |
| `toMinutes` | `public long toMinutes()` | Total whole minutes |
| `toSeconds` | `public long toSeconds()` | Total whole seconds |
| `toMillis` | `public long toMillis()` | Total milliseconds |
| `toNanos` | `public long toNanos()` | Total nanoseconds |

**Part-extraction methods** (Java 9+, component within next-larger unit):

| Method | Signature | Returns |
|--------|-----------|---------|
| `toDaysPart` | `public long toDaysPart()` | Days part |
| `toHoursPart` | `public int toHoursPart()` | Hours within day (0..23) |
| `toMinutesPart` | `public int toMinutesPart()` | Minutes within hour (0..59) |
| `toSecondsPart` | `public int toSecondsPart()` | Seconds within minute (0..59) |
| `toMillisPart` | `public int toMillisPart()` | Millis within second (0..999) |
| `toNanosPart` | `public int toNanosPart()` | Nanos within second (0..999_999_999) |

**Pattern**: Three distinct naming conventions:
- `get*` for stored field access
- `to*` for total conversion
- `to*Part` for decomposed components

All compound names, no nesting.

### 2.2 `java.time.Instant`

**Storage**: `seconds` from epoch (`long`) + `nanos` within second (`int`).

| Method | Signature | Returns |
|--------|-----------|---------|
| `getEpochSecond` | `public long getEpochSecond()` | Seconds since 1970-01-01T00:00:00Z |
| `getNano` | `public int getNano()` | Nanos within second (0..999_999_999) |
| `toEpochMilli` | `public long toEpochMilli()` | Total milliseconds since epoch |
| `getLong` | `public long getLong(TemporalField field)` | Generalized field accessor |

**Pattern**: Same `get*` / `to*` convention as Duration. `getEpochSecond` is a compound name that encodes both the epoch reference and the unit.

**Consistency note**: Both `Duration` and `Instant` use `getNano()` with the same semantics (nanoseconds within current second). The `get*` prefix is uniform across `java.time`.

---

## 3. C++ (`std::chrono`)

### 3.1 `std::chrono::duration<Rep, Period>`

**Storage**: A single `Rep` count of ticks, where `Period` is a compile-time `std::ratio` defining seconds-per-tick.

**Single accessor**:

```cpp
constexpr Rep count() const;
```

**Unit conversion**: Via `duration_cast` or implicit conversion:

```cpp
template <class ToDuration, class Rep, class Period>
constexpr ToDuration duration_cast(const duration<Rep, Period>& d);
```

**Predefined type aliases**:

| Type | Definition |
|------|------------|
| `std::chrono::nanoseconds` | `duration</*signed*/, std::nano>` |
| `std::chrono::microseconds` | `duration</*signed*/, std::micro>` |
| `std::chrono::milliseconds` | `duration</*signed*/, std::milli>` |
| `std::chrono::seconds` | `duration</*signed*/>` |
| `std::chrono::minutes` | `duration</*signed*/, std::ratio<60>>` |
| `std::chrono::hours` | `duration</*signed*/, std::ratio<3600>>` |

**Pattern**: Rather than named accessor methods, C++ uses the type system. "Get as milliseconds" is:

```cpp
auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(d);
ms.count();  // the numeric value
```

No compound-named conversion methods at all. The unit information is encoded in the type, not the method name.

### 3.2 `std::chrono::time_point<Clock, Duration>`

**Single accessor**:

```cpp
constexpr duration time_since_epoch() const;
```

Returns the duration since the clock's epoch. Unit conversion uses the same `duration_cast` pattern.

**Utility**:

```cpp
static std::time_t std::chrono::system_clock::to_time_t(const time_point& t);
```

**Pattern**: Consistent with `duration` -- a single accessor that returns a typed duration, then you cast to get specific units.

---

## 4. Haskell: `Data.Time`

### 4.1 `DiffTime`

**Representation**: Picosecond-precision rational number (internally `Pico`, a fixed-precision decimal).

**Conversion functions** (free functions, not methods):

| Function | Signature |
|----------|-----------|
| `secondsToDiffTime` | `Integer -> DiffTime` |
| `picosecondsToDiffTime` | `Integer -> DiffTime` |
| `diffTimeToPicoseconds` | `DiffTime -> Integer` |

`DiffTime` also has `Num`, `Fractional`, and `Real` instances, so arithmetic and `realToFrac` work directly.

**Pattern**: Free functions with the pattern `unitToDiffTime` / `diffTimeToUnit`. No methods. The type itself is abstract.

### 4.2 `NominalDiffTime`

Similar to `DiffTime` but ignores leap seconds.

| Function | Signature |
|----------|-----------|
| `secondsToNominalDiffTime` | `Pico -> NominalDiffTime` |
| `nominalDiffTimeToSeconds` | `NominalDiffTime -> Pico` |

`Pico` is `Fixed E12` (12 decimal places = picosecond precision).

**Pattern**: Same naming convention as `DiffTime`. Functions named `<source>To<target>`.

### 4.3 `UTCTime`

**Stored fields** (record syntax):

```haskell
data UTCTime = UTCTime
  { utctDay     :: Day
  , utctDayTime :: DiffTime
  }
```

`utctDayTime` is the offset from midnight (0 to 86401s for leap seconds).

**Pattern**: Record field accessors with the type name as prefix (`utct`). No epoch-seconds accessor -- the representation is day + time-within-day, not seconds-since-epoch.

### 4.4 `SystemTime` (`Data.Time.Clock.System`)

**Stored fields**:

```haskell
data SystemTime = MkSystemTime
  { systemSeconds     :: {-# UNPACK #-} !Int64
  , systemNanoseconds :: {-# UNPACK #-} !Word32
  }
```

**Pattern**: Record fields with a `system` prefix. `systemSeconds` is epoch-seconds, `systemNanoseconds` is the sub-second component (0..999_999_999, or up to 1_999_999_999 for leap seconds).

---

## 5. Go: `time`

### 5.1 `time.Duration`

**Storage**: Single `int64` representing nanoseconds.

**Conversion methods** (total duration in one unit):

| Method | Signature | Returns |
|--------|-----------|---------|
| `Hours` | `func (d Duration) Hours() float64` | Total hours (fractional) |
| `Minutes` | `func (d Duration) Minutes() float64` | Total minutes (fractional) |
| `Seconds` | `func (d Duration) Seconds() float64` | Total seconds (fractional) |
| `Milliseconds` | `func (d Duration) Milliseconds() int64` | Total milliseconds |
| `Microseconds` | `func (d Duration) Microseconds() int64` | Total microseconds |
| `Nanoseconds` | `func (d Duration) Nanoseconds() int64` | Total nanoseconds |

**Return type split**: `float64` for coarse units (Hours/Minutes/Seconds), `int64` for fine units (Milliseconds/Microseconds/Nanoseconds). Rationale: the dominant use for coarse units is printing fractional values.

**Predefined constants**:

```go
const (
    Nanosecond  Duration = 1
    Microsecond          = 1000 * Nanosecond
    Millisecond          = 1000 * Microsecond
    Second               = 1000 * Millisecond
    Minute               = 60 * Second
    Hour                 = 60 * Minute
)
```

No `Day` or larger constants, to avoid daylight-saving ambiguity.

**Pattern**: Simple plural-noun method names. No prefix (`as_`, `to_`, `num_`). No subsecond component methods -- because the storage is a single nanosecond count, the total-conversion methods are sufficient.

### 5.2 `time.Time`

**Epoch-timestamp methods** (total time since Unix epoch in one unit):

| Method | Signature | Returns |
|--------|-----------|---------|
| `Unix` | `func (t Time) Unix() int64` | Seconds since epoch |
| `UnixMilli` | `func (t Time) UnixMilli() int64` | Milliseconds since epoch |
| `UnixMicro` | `func (t Time) UnixMicro() int64` | Microseconds since epoch |
| `UnixNano` | `func (t Time) UnixNano() int64` | Nanoseconds since epoch |

**Calendar-component methods** (decomposed wall-clock fields):

| Method | Signature | Returns |
|--------|-----------|---------|
| `Hour` | `func (t Time) Hour() int` | 0..23 |
| `Minute` | `func (t Time) Minute() int` | 0..59 |
| `Second` | `func (t Time) Second() int` | 0..59 |
| `Nanosecond` | `func (t Time) Nanosecond() int` | 0..999_999_999 |

**Pattern**: `Unix*` prefix for epoch-relative total conversions. Simple singular nouns for calendar components. Compound names for `UnixMilli`, `UnixMicro`, `UnixNano`.

---

## 6. Python: `datetime`

### 6.1 `datetime.timedelta`

**Storage**: Three read-only attributes:

| Attribute | Type | Range |
|-----------|------|-------|
| `days` | `int` | -999_999_999 .. 999_999_999 |
| `seconds` | `int` | 0 .. 86_399 |
| `microseconds` | `int` | 0 .. 999_999 |

These are component fields, not totals. A timedelta of 90 seconds has `days=0, seconds=90, microseconds=0`.

**Total-conversion method**:

| Method | Signature | Returns |
|--------|-----------|---------|
| `total_seconds` | `def total_seconds(self) -> float` | Total duration as fractional seconds |

**Pattern**: Only one total-conversion method (`total_seconds`). The stored attributes are decomposed components using plain nouns (no prefix). No `total_milliseconds()` or `total_microseconds()` -- users must compute from `total_seconds()`.

**Common pitfall**: `.seconds` returns the seconds component (0..86399), not the total seconds. This is a well-known source of bugs.

### 6.2 `datetime.datetime`

**Stored attributes** (read-only):

| Attribute | Type | Range |
|-----------|------|-------|
| `year` | `int` | 1 .. 9999 |
| `month` | `int` | 1 .. 12 |
| `day` | `int` | 1 .. varies |
| `hour` | `int` | 0 .. 23 |
| `minute` | `int` | 0 .. 59 |
| `second` | `int` | 0 .. 59 |
| `microsecond` | `int` | 0 .. 999_999 |
| `tzinfo` | `tzinfo or None` | -- |

**Epoch conversion**:

| Method | Signature | Returns |
|--------|-----------|---------|
| `timestamp` | `def timestamp(self) -> float` | Seconds since 1970-01-01 as float |

**Pattern**: Plain singular-noun attributes for calendar components. Single `timestamp()` method for epoch conversion. No `timestamp_millis()` or `timestamp_nanos()`.

---

## 7. Swift stdlib: `Swift.Duration`

### 7.1 `Duration`

**Storage**: 128-bit value split as `(seconds: Int64, attoseconds: Int64)` internally.

**Component accessor**:

```swift
public var components: (seconds: Int64, attoseconds: Int64) { get }
```

**Initializer**:

```swift
public init(secondsComponent: Int64, attosecondsComponent: Int64)
```

**Static factory methods** (construction only, not extraction):

| Method | Signature |
|--------|-----------|
| `.seconds(_:)` | `static func seconds<T: BinaryInteger>(_ value: T) -> Duration` |
| `.seconds(_:)` | `static func seconds(_ value: Double) -> Duration` |
| `.milliseconds(_:)` | `static func milliseconds<T: BinaryInteger>(_ value: T) -> Duration` |
| `.milliseconds(_:)` | `static func milliseconds(_ value: Double) -> Duration` |
| `.microseconds(_:)` | `static func microseconds<T: BinaryInteger>(_ value: T) -> Duration` |
| `.microseconds(_:)` | `static func microseconds(_ value: Double) -> Duration` |
| `.nanoseconds(_:)` | `static func nanoseconds<T: BinaryInteger>(_ value: T) -> Duration` |

**What is notably absent**: There are no `asSeconds`, `asMilliseconds`, `asNanoseconds`, or similar extraction/conversion properties. The only way to read the value back is through `components`, which returns the raw (seconds, attoseconds) pair.

**Design rationale** (from SE-0329):
1. 128-bit storage is required to represent nanosecond precision across the full range (+/- thousands of years).
2. Since Swift lacks a native `Int128`, the value is exposed as two `Int64` components.
3. Attoseconds (10^-18) were chosen for the sub-second field to avoid precision loss when converting between units.
4. The `components` property is described as an interoperability mechanism (e.g., for `timespec`), not a primary API surface.
5. The proposal states that if Swift gains `Int128`, `components` should be replaced with direct access to a single attoseconds value.

**Pattern**: Asymmetric API -- static factory methods use unit names (`.seconds`, `.milliseconds`) but there is no corresponding read-back API using unit names. The single `components` accessor returns a labeled tuple.

---

## Cross-Language Comparison

### Duration Unit-Conversion Patterns

| Language | Pattern | Naming Convention | Example |
|----------|---------|-------------------|---------|
| Rust std | Named methods | `as_` prefix + compound unit | `as_millis()`, `as_secs_f64()` |
| Rust chrono | Named methods | `num_` prefix + compound unit | `num_seconds()`, `num_milliseconds()` |
| Java | Named methods | `to` prefix + compound unit | `toMillis()`, `toNanos()` |
| C++ | Type-system cast | Generic `duration_cast<T>` + `.count()` | `duration_cast<milliseconds>(d).count()` |
| Haskell | Free functions | `diffTimeTo` + unit | `diffTimeToPicoseconds(dt)` |
| Go | Named methods | Plural unit noun (no prefix) | `Milliseconds()`, `Seconds()` |
| Python | Single method | `total_seconds()` only | `td.total_seconds()` |
| Swift | Tuple decomposition | `.components.seconds` | `d.components.seconds` |

### Instant/Timestamp Epoch Accessors

| Language | Seconds-since-epoch | Sub-second component |
|----------|--------------------|-----------------------|
| Rust std | Indirect: `system_time.duration_since(UNIX_EPOCH)?.as_secs()` | `.subsec_nanos()` on resulting Duration |
| Rust chrono | `.timestamp()` -> `i64` | `.timestamp_subsec_nanos()` -> `u32` |
| Java | `.getEpochSecond()` -> `long` | `.getNano()` -> `int` |
| C++ | `.time_since_epoch().count()` (type-dependent) | Cast to desired unit |
| Haskell | `systemSeconds` field -> `Int64` | `systemNanoseconds` field -> `Word32` |
| Go | `.Unix()` -> `int64` | `.Nanosecond()` -> `int` (wall-clock ns) |
| Python | `.timestamp()` -> `float` | Encoded in float fractional part |

### Subsecond Component Naming

| Language | Pattern | Names |
|----------|---------|-------|
| Rust std | `subsec_` prefix | `subsec_millis`, `subsec_micros`, `subsec_nanos` |
| Rust chrono (Duration) | `subsec_` prefix | `subsec_millis`, `subsec_micros`, `subsec_nanos` |
| Rust chrono (DateTime) | `timestamp_subsec_` prefix | `timestamp_subsec_millis`, `timestamp_subsec_nanos` |
| Java | `getNano()` / `to*Part()` | `getNano`, `toMillisPart`, `toNanosPart` |
| C++ | N/A (type-system) | Cast to sub-unit then `.count()` |
| Haskell | Field name | `systemNanoseconds` |
| Go | Singular noun | `Nanosecond()` |
| Python | Attribute | `.microseconds` |

### Accessor Pattern Consistency Within Each Language

| Language | Consistent? | Notes |
|----------|------------|-------|
| **Rust std** | Yes | Duration and SystemTime both use `as_` / `subsec_` uniformly |
| **Rust chrono** | Mostly | Duration uses `num_*`, DateTime uses `timestamp*` -- different prefixes for different domains |
| **Java** | Yes | Uniform `get*` / `to*` / `to*Part` across Duration and Instant |
| **C++** | Yes | Everything goes through `count()` + type-system casting |
| **Haskell** | Yes | Free functions follow `<source>To<target>` pattern consistently |
| **Go** | Mixed | Duration uses plural nouns (`Seconds()`), Time uses `Unix*` for epoch + singular for components |
| **Python** | No | `total_seconds()` on timedelta vs `.timestamp()` on datetime; `.seconds` (component) vs `.second` (calendar field) |
| **Swift** | N/A | Only one accessor (`.components`) -- too minimal to assess pattern consistency |

---

## Key Design Observations

### 1. Total vs. Component Ambiguity

The `total_seconds()` vs `.seconds` confusion in Python is the canonical example of this problem. Java explicitly addresses it with `toSeconds()` (total) vs `toSecondsPart()` (component) vs `getSeconds()` (stored field). Rust uses `as_secs()` (total, truncated) vs `subsec_nanos()` (component).

**Takeaway**: Any API that exposes both total-duration-in-unit and component-within-second must make the distinction unambiguous in the naming.

### 2. Prefix Conventions Encode Semantics

| Prefix | Language | Meaning |
|--------|----------|---------|
| `as_` | Rust | "View the whole duration as this unit" |
| `to` | Java | "Convert the whole duration to this unit" |
| `num_` | chrono | "The number of whole [units] in the duration" |
| `subsec_` | Rust/chrono | "The fractional sub-second part, in this unit" |
| `get` | Java | "Read the stored field" |
| `total_` | Python | "The whole duration, not just a component" |

### 3. The C++ Type-System Approach

C++ is unique in encoding units at the type level rather than in method names. This eliminates the need for per-unit accessor methods entirely. The trade-off is verbosity at call sites (`duration_cast<milliseconds>(d).count()`), but it provides compile-time unit safety.

### 4. Swift's Asymmetric Design

Swift `Duration` is the only API surveyed that has unit-named factory methods (`.seconds()`, `.milliseconds()`) but no corresponding unit-named extraction methods. All extraction goes through `.components`, which returns the raw storage representation. This is explicitly described as a transitional design pending `Int128` support.

### 5. Opaque vs Transparent Instants

- **Opaque**: Rust `Instant` (no epoch access), C++ `steady_clock::time_point` (implementation-defined epoch)
- **Transparent**: Java `Instant`, Go `time.Time`, Haskell `SystemTime` (all expose epoch-seconds + sub-second)
- **Semi-transparent**: Rust `SystemTime` (epoch access only via `duration_since(UNIX_EPOCH)`)

---

## Sources

- [Rust std::time::Duration](https://doc.rust-lang.org/std/time/struct.Duration.html)
- [Rust std::time::Instant](https://doc.rust-lang.org/std/time/struct.Instant.html)
- [Rust std::time::SystemTime](https://doc.rust-lang.org/std/time/struct.SystemTime.html)
- [chrono::TimeDelta](https://docs.rs/chrono/latest/chrono/struct.TimeDelta.html)
- [chrono::NaiveDateTime](https://docs.rs/chrono/latest/chrono/naive/struct.NaiveDateTime.html)
- [Java java.time.Duration (JDK 21)](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/time/Duration.html)
- [Java java.time.Instant (JDK 21)](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/time/Instant.html)
- [C++ std::chrono::duration (cppreference)](https://en.cppreference.com/w/cpp/chrono/duration.html)
- [C++ std::chrono::time_point (cppreference)](https://en.cppreference.com/w/cpp/chrono/time_point.html)
- [C++ std::chrono::duration_cast (cppreference)](https://en.cppreference.com/w/cpp/chrono/duration/duration_cast.html)
- [Haskell Data.Time.Clock (Hackage)](https://hackage.haskell.org/package/time/docs/Data-Time-Clock.html)
- [Haskell Data.Time.Clock.System (Hackage)](https://hackage.haskell.org/package/time/docs/Data-Time-Clock-System.html)
- [Go time package (pkg.go.dev)](https://pkg.go.dev/time)
- [Python datetime (docs.python.org)](https://docs.python.org/3/library/datetime.html)
- [Swift SE-0329: Clock, Instant, and Duration](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0329-clock-instant-duration.md)
- [Swift Duration (swiftinit.org)](https://swiftinit.org/docs/swift/swift/duration)
