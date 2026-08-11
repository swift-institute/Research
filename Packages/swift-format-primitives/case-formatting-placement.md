# Case Formatting Placement

<!--
---
version: 1.0.0
last_updated: 2026-04-22
status: RECOMMENDATION
tier: 2
scope: cross-package
-->

## Context

`swift-standard-library-extensions` currently hosts four related declarations that are not stdlib-extension content in the self-containment sense; they are **case-formatting domain** content that happens to live there for historical reasons:

1. `public struct String.Case` — a case-transformation type (closure over `String → String`) with static presets `.upper`, `.lower`, `.title`, `.sentence`.
2. `public struct String.Case.Insensitive` — a case-insensitive string wrapper for use as dictionary keys (`Hashable`, `Comparable`, `Sendable`).
3. `extension StringProtocol { public func formatted(as case: String.Case) -> String }` — the consumer entry point.
4. `extension String { public var caseInsensitive: Case.Insensitive }` — factory for the hashing wrapper.

These types block strict per-type modularization of `swift-standard-library-extensions`: `StringProtocol.swift` uses `String.Case` declared in `String.swift`, producing a cross-file reference that cannot be resolved internally without either accepting a Core target (violates strict) or renaming `String.Case.Insensitive` → `String.CaseInsensitive` (violates [API-NAME-002] No Compound Identifiers — attempted and reverted, 2026-04-22).

Moving these to `swift-format-primitives` is the architecturally-aligned fix: format-primitives already owns `Format.Decimal`, `Format.Numeric.*`, and the `Format.Style<Input, Output>` protocol; case formatting is the same kind of concern. `swift-format-primitives` already depends on `swift-standard-library-extensions`, so the dependency direction supports the move.

## Question

How does this relocation map concretely onto `swift-format-primitives`' existing conventions? What file layout, type naming, Format.Style conformance, and consumer API best preserves the current behavior while aligning with how `Format.Decimal`, `Format.Numeric`, etc. are organized?

Secondary: how does the (breaking) API change cascade to downstream consumers, tests, and the modularization story for `swift-standard-library-extensions`?

## Analysis

### Precedent in swift-format-primitives

Existing conventions observed from the current package sources (`Sources/Format Primitives/*.swift`):

| Aspect | Convention (from Format.Decimal, Format.Numeric) |
|---|---|
| Namespace | `public enum Format {}` at top level (`Format.swift`) |
| Format styles | Nested structs under `Format`: `Format.Decimal`, `Format.Numeric` |
| Style protocol | `Format.Style<Input, Output>: Sendable` declared in `FormatStyle.swift` with `func format(_ value: Input) -> Output` |
| Format.Style conformance | Styles *may* conform; `Format.Decimal` deliberately does NOT because it works across multiple `BinaryFloatingPoint` inputs. Styles whose `Input` is a single concrete type (like `Case`'s `Input = String`) are natural conformers |
| Presets | `public static var number: Self`, `public static var percent: Self` — conventional factory pattern |
| Chaining | `public func rounded() -> Self`, `.precision(Int) -> Self` return new instances |
| Consumer entry | Per-type-family extensions: `extension BinaryFloatingPoint { public func formatted(_ format: Format.Decimal) -> String }` — one concrete overload; and a generic `func formatted<S>(_: S) where S: Format.Style` |
| File naming | Dot-separated: `Format.Decimal.swift`, `Format.Numeric.Notation.swift`. Extensions to external types: `Tagged+Format.swift` (type-being-extended `+` extending-package) |
| External-type extension pattern | One file per concern, extends stdlib/external type with `.formatted(_:)` variants |

### Option A: `Format.Case` as a Format.Style conformer (recommended)

Place case transformation as a first-class `Format.Style`:

```swift
// Sources/Format Primitives/Format.Case.swift
extension Format {
    /// Format style for case transformation of strings.
    ///
    /// ## Example
    /// ```swift
    /// "hello world".formatted(.upper)     // "HELLO WORLD"
    /// "hello world".formatted(.title)     // "Hello World"
    /// "hello world".formatted(.sentence)  // "Hello world"
    ///
    /// let custom = Format.Case { $0.map { $0.isLetter ? $0.uppercased() : $0.lowercased() }.joined() }
    /// "hello".formatted(custom)
    /// ```
    public struct Case: Sendable, Format.Style {
        public typealias Input = String
        public typealias Output = String

        @usableFromInline
        let transform: @Sendable (String) -> String

        @inlinable
        public init(_ transform: @escaping @Sendable (String) -> String) {
            self.transform = transform
        }

        @inlinable
        public func format(_ value: String) -> String {
            transform(value)
        }

        public static let upper: Self = Self { $0.uppercased() }
        public static let lower: Self = Self { $0.lowercased() }
        public static let title: Self = Self { string in
            string.split(separator: " ")
                .map { word in
                    guard let first = word.first else { return "" }
                    return first.uppercased() + word.dropFirst().lowercased()
                }
                .joined(separator: " ")
        }
        public static let sentence: Self = Self { string in
            guard let first = string.first else { return string }
            return first.uppercased() + string.dropFirst().lowercased()
        }
    }
}
```

**Pros**: matches existing precedent exactly; presets `.upper`/`.lower`/`.title`/`.sentence` work at the call site via type inference; future Format.Style consumers get it for free; small, self-contained file.

**Cons**: none identified relative to the current design.

### Option B: Insensitive placement

`String.Case.Insensitive` is a **hashing/equality** wrapper, not a format transformation. But it shares the "case" domain and is most naturally discovered alongside `Format.Case`. Two candidate locations:

**B1 — nested in `Format.Case` (recommended)**:
```swift
// Sources/Format Primitives/Format.Case.Insensitive.swift
extension Format.Case {
    /// Case-insensitive string wrapper for dictionary keys / equality.
    ///
    /// Distinct concern from `Format.Case` the transformation style: this is an
    /// equality/hashing wrapper. Co-located here because the natural discovery
    /// path for case-insensitive operations is the Case namespace.
    public struct Insensitive: Hashable, Comparable, Sendable {
        public let value: String

        @inlinable
        public init(_ value: some StringProtocol) {
            self.value = String(value)
        }

        @inlinable
        public func hash(into hasher: inout Hasher) {
            value.lowercased().hash(into: &hasher)
        }

        @inlinable
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.value.lowercased() == rhs.value.lowercased()
        }

        @inlinable
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.value.lowercased() < rhs.value.lowercased()
        }
    }
}
```

Path: `Format.Case.Insensitive` — proper `Nest.Name` per [API-NAME-001], no compound identifier.

**B2 — split to a hashing-focused package (deferred)**: a future `swift-hash-primitives` or `swift-tagged-primitives` could reasonably own `Case.Insensitive` as a case-folding wrapper. Not pursued in this move — would fragment the case surface across two packages when consumers expect one discovery point. If hashing-primitives materializes later, migration is a straightforward rename-import.

**Recommendation**: B1. The `Case` namespace is small; housing both the transformation style and the hashing wrapper keeps case-related surface discoverable from one import.

### Option C: Consumer entry points

The existing package exposes `.formatted(_:)` as **per-type-family extensions**, not a single generic. The same pattern extended to strings:

```swift
// Sources/Format Primitives/StringProtocol+Format.swift
extension StringProtocol {
    /// Converts this string to formatted output using the specified Format.Case style.
    ///
    /// ## Example
    /// ```swift
    /// "hello world".formatted(.upper)     // "HELLO WORLD"
    /// let sub = "hello world"[...]; sub.formatted(.title)  // "Hello World" (Substring too)
    /// ```
    @inlinable
    public func formatted(_ format: Format.Case) -> String {
        format.format(String(self))
    }

    /// Generic form — any Format.Style over `String` works.
    @inlinable
    public func formatted<S>(_ format: S) -> S.Output
    where S: Format.Style, S.Input == String {
        format.format(String(self))
    }
}

extension String {
    /// A case-insensitive wrapper for the string, suitable as a dictionary key.
    ///
    /// ## Example
    /// ```swift
    /// var headers: [Format.Case.Insensitive: String] = [:]
    /// headers["Content-Type".caseInsensitive] = "text/html"
    /// headers["content-type".caseInsensitive]  // "text/html"
    /// ```
    @inlinable
    public var caseInsensitive: Format.Case.Insensitive {
        Format.Case.Insensitive(self)
    }
}
```

API change from current:
- `"hello".formatted(as: .upper)` → `"hello".formatted(.upper)` — drops the `as:` label, matching `42.formatted(.binary)` and `0.75.formatted(.percent)` precedent.
- `String.Case.Insensitive` → `Format.Case.Insensitive`. Import site is different (`import Format_Primitives` vs `import Standard_Library_Extensions`).
- `caseInsensitive` property is preserved verbatim on `String`.

### Option D: Tagged integration

Existing `Tagged+Format.swift` extends `Tagged` for numeric formatting. An analogous `Tagged+Format.Case.swift` would let tagged strings format too — but this is out of scope unless there's an identified tagged-string consumer. Defer.

### File layout (proposed)

```
swift-format-primitives/Sources/Format Primitives/
├── Format.swift                        (unchanged)
├── FormatStyle.swift                   (unchanged)
├── Format.Decimal.swift                (unchanged)
├── Format.Numeric.swift                (unchanged)
├── Format.Numeric.Notation.swift       (unchanged)
├── Format.Numeric.Separator.swift      (unchanged)
├── Format.Numeric.Sign.swift           (unchanged)
├── Tagged+Format.swift                 (unchanged)
├── Format.Case.swift                   (NEW — Option A)
├── Format.Case.Insensitive.swift       (NEW — Option B1)
└── StringProtocol+Format.swift         (NEW — Option C: formatted + caseInsensitive)
```

Three new files, ~250 lines total. Matches existing per-concern file granularity.

## Consumer Migration

### Source consumers

| Before | After |
|---|---|
| `import Standard_Library_Extensions` + `"x".formatted(as: .upper)` | `import Format_Primitives` + `"x".formatted(.upper)` |
| `String.Case.Insensitive` | `Format.Case.Insensitive` |
| `String.Case.upper` etc. | `Format.Case.upper` etc. |
| `"x".caseInsensitive` (any import) | `"x".caseInsensitive` — requires `import Format_Primitives` |

### Breaking changes summary

1. **API rename** (label drop): `formatted(as:)` → `formatted(_:)`. Mechanical find-replace per call site.
2. **Type path change**: `String.Case` → `Format.Case`, `String.Case.Insensitive` → `Format.Case.Insensitive`. Find-replace.
3. **Import requirement**: consumers of `.caseInsensitive` now require `import Format_Primitives`. Consumers already importing `Format_Primitives` (which transitively pulls standard-library-extensions) gain the API automatically; consumers importing only `Standard_Library_Extensions` must add the import.

### Test migration

Current: `Tests/Standard Library Extensions Tests/String Tests.swift` has suites:
- `` `String.Case.Insensitive - Equality` ``
- `` `String.Case.Insensitive - Hashing` ``
- (potentially others)

These move to `Tests/Format Primitives Tests/` with renamed suites (`` `Format.Case.Insensitive - ...` ``). Body stays identical except for the type path.

## Impact on Modularization Experiment

With this relocation complete:
- `swift-standard-library-extensions/Sources/Standard Library Extensions/String.swift` loses Case + CaseInsensitive declarations.
- `StringProtocol.swift` loses `formatted(as:)` (the whole "Case Formatting" MARK section).
- The generator's special-case `stem == "StringProtocol" ? "String"` mapping becomes unnecessary. Strict per-file (per-type) partitioning produces **78 truly independent targets** with zero intra-package deps.
- Re-measurement expected to hold at ~2.83× clean-debug cost (the current number already reflects the format-subsystem folded via special case; independent targets add one unit of parallelism, minor change).

`swift-format-primitives` itself remains a single-target package at L1. The move doesn't affect its modularization profile — it's small enough that per-type partitioning would not pay off even if the strict modularization pattern were adopted for it.

## Title-Case Algorithm (non-blocking optional improvement)

Current `Format.Case.title` algorithm:

```swift
string.split(separator: " ")
    .map { word in
        guard let first = word.first else { return "" }
        return first.uppercased() + word.dropFirst().lowercased()
    }
    .joined(separator: " ")
```

Limitations:
- Only splits on ASCII space. Tab, newline, non-breaking space, em-dash don't trigger word-casing.
- Unicode word-boundary rules (UAX #29) are not applied.
- Idiomatic title case (lowercase articles, prepositions) not supported.

Consider replacing with `string.capitalized` (stdlib) which uses Unicode word segmentation. Different behavior — preserves existing intent explicitly documenting the naive algorithm if retaining. **Out of scope for this relocation**; noted for follow-on design.

## Outcome

**Status**: RECOMMENDATION.

Adopt Option A (`Format.Case` conforming to `Format.Style<String, String>`) + Option B1 (Insensitive nested in `Format.Case`) + Option C (`StringProtocol+Format.swift` for entry points).

### Execution order

1. Create `Format.Case.swift`, `Format.Case.Insensitive.swift`, `StringProtocol+Format.swift` in `swift-format-primitives/Sources/Format Primitives/`.
2. Move/rename test suites from `swift-standard-library-extensions/Tests/.../String Tests.swift` to `swift-format-primitives/Tests/Format Primitives Tests/Format.Case Tests.swift` and `Format.Case.Insensitive Tests.swift`.
3. Delete from `swift-standard-library-extensions/Sources/Standard Library Extensions/`:
   - `String.swift`: the `extension String.Case { public struct Insensitive }` block, the `caseInsensitive` computed var, the whole `public struct Case` declaration.
   - `StringProtocol.swift`: the `MARK - Case Formatting` section (`formatted(as:)` method).
4. Remove the `StringProtocol → String` special case from `Experiments/modularization-compile-time/scripts/generate-variant.sh` — no longer needed.
5. Re-run the MVP to confirm 78-target strict per-file modularization builds and measure the (small) ratio delta.
6. Update callers across the ecosystem: grep for `formatted(as:`, `String.Case`, `String.Case.Insensitive` and mechanically update.

### What this does NOT decide

- Title-case algorithm quality. Preserved verbatim during relocation.
- Tagged-string formatting. Deferred.
- Whether `Case.Insensitive` should eventually move to a hashing-focused package. Revisit if/when `swift-hash-primitives` materializes.

## References

- `swift-format-primitives/Sources/Format Primitives/Format.swift:12` — Format namespace.
- `swift-format-primitives/Sources/Format Primitives/FormatStyle.swift:21` — Format.Style protocol.
- `swift-format-primitives/Sources/Format Primitives/Format.Decimal.swift:23` — Format.Decimal precedent.
- `swift-format-primitives/Sources/Format Primitives/Format.Numeric.swift:10` — Format.Numeric sub-namespace pattern.
- `swift-standard-library-extensions/Sources/Standard Library Extensions/String.swift:65` — current `String.Case` declaration to be removed.
- `swift-standard-library-extensions/Sources/Standard Library Extensions/StringProtocol.swift:19` — current `formatted(as:)` method to be removed.
- `swift-standard-library-extensions/Research/modularization-compile-time-impact.md` — upstream research flagging this subsystem as out-of-place.
- [API-NAME-001] Namespace Structure (Nest.Name pattern).
- [API-NAME-002] No Compound Identifiers.
- [MOD-010] Standard Library Integration Module — related pattern, not directly applied.
