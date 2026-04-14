# Localization Architecture Analysis

<!--
---
version: 2.0.0
last_updated: 2026-03-17
status: CONVERGED
tier: 1
collaborative_discussion: swift-institute/Research/localization-architecture-discussion-transcript.md
---
-->

## Context

While implementing a Dutch-locale PDF product, we needed `Format.Datum` — a Dutch date formatter producing "21 november 2018". This required hardcoding Dutch month names in a product-layer file, because no locale-aware formatting path exists in the ecosystem.

The same product file also contains `Format.Euro` and `Format.Nummer` — Dutch-locale currency and number formatters — both hardcoding Dutch conventions (€ prefix, period thousand separators, comma decimal separator).

This is a symptom. The disease is that the localization architecture is fragmented: locale, formatting, translation, and time are disconnected across layers.

## Question

What is the current state of localization across the Swift Institute ecosystem, what are the architectural gaps and inconsistencies, and what concrete plan reaches a unified Foundation-free localization architecture?

---

## Phase 1: Complete Inventory

### Layer 1 — Primitives

#### swift-locale-primitives (`https://github.com/swift-primitives/swift-locale-primitives`)

**Status**: Empty placeholder.

Single file: `Sources/Locale Primitives/Locale.swift`

```swift
public struct Locale: Sendable, Equatable, Hashable {
    public init() { }
}
```

No fields, no properties, no methods. The TODO comments reference BCP 47, ISO 639, ISO 3166, ISO 4217 as future backing. Depends only on `Standard_Library_Extensions`.

#### swift-formatting-primitives (`https://github.com/swift-primitives/swift-formatting-primitives`)

**Status**: Functional but locale-unaware.

7 source files. Depends on `Standard_Library_Extensions` + `Identity_Primitives`.

| Type | API Surface | Locale Awareness |
|------|-------------|------------------|
| `FormatStyle` protocol | `format(_:) -> FormatOutput` | None — no locale parameter |
| `Format` enum | Root namespace | — |
| `Format.FloatingPoint` | `.number`, `.percent`, `.precision(_:)`, `.rounded()` | None — hardcodes "." decimal |
| `Format.Numeric.SignDisplayStrategy` | `.automatic`, `.never`, `.always(includingZero:)` | None |
| `Format.Numeric.DecimalSeparatorStrategy` | `.automatic`, `.always` | None |
| `Format.Numeric.Notation` | `.automatic`, `.compactName`, `.scientific` | None — hardcodes K/M/B |

Extensions on `BinaryFloatingPoint`, `BinaryInteger`, and `Tagged<_, BinaryFloatingPoint>` provide `.formatted(_:)` syntax.

**Key observation**: `Format.FloatingPoint.format(_:)` directly interpolates with `"."` as decimal separator, `"E"` for scientific notation, and English compact names (K, M, B). These are NOT configurable.

#### swift-time-primitives (`https://github.com/swift-primitives/swift-time-primitives`)

**Status**: Rich calendar type system with Duration formatting only.

Three modules: `Time Primitives Core`, `Time Julian Primitives`, `Time Primitives` (umbrella).

Calendar types:

| Type | Purpose |
|------|---------|
| `Time` | Calendar representation (year/month/day/hour/minute/second + sub-second) |
| `Time.Year` | Unbounded year (RawRepresentable<Int>) |
| `Time.Month` | Refined 1–12 with static `.january` ... `.december` |
| `Time.Month.Day` | Dependent refinement (validates against month/year) |
| `Time.Hour` through `Time.Yoctosecond` | 10 precision levels |
| `Time.Week.Day` / `Time.Weekday` | Zeller's congruence |
| `Time.Timezone.Offset` | UTC offset in seconds |
| `Time.Calendar` / `Time.Calendar.Gregorian` | Calendar algorithms |
| `Time.Epoch` / `Time.Epoch.Conversion` | 6 standard epochs + O(1) conversion |
| `Instant` | Timeline point (secondsSinceUnixEpoch + nanosecondFraction) |
| `Duration` | Alias for `Swift.Duration` |
| `Time.Julian.Day` / `Time.Julian.Offset` | Julian Day coordinate geometry |

Formatting: `Time.Format` struct conforming to `FormatStyle<Duration, String>` with unit selection and notation. Only handles Duration → String (e.g., "150.00 ms"). No date formatting exists — `Time.Month` has `.january` ... `.december` as code identifiers, not localized names.

`Time Primitives Core` publicly imports `Formatting_Primitives`.

### Layer 2 — Standards

#### swift-locale-standard (`https://github.com/swift-standards/swift-locale-standard`)

**Status**: Structurally complete, well-designed. Disconnected from formatting.

6 source files. Depends on `BCP_47`, `ISO_15924`, `ISO_3166`, `ISO_639`, `Standard_Library_Extensions`.

| Type | Properties | Purpose |
|------|-----------|---------|
| `Locale` | `language: Language`, `region: ISO_3166.Alpha2?`, `script: ISO_15924.Alpha4?` | BCP 47 locale composite |
| `Language` | `code: ISO_639.LanguageCode` | Pure language without region/script |

`Language` features:
- 183 static accessors (`.en`, `.nl`, `.zh`, etc.) — generated
- `CaseIterable` over all ISO 639-1 languages
- `fallbackChain: [Language]` — 183-entry lookup table ordered by linguistic proximity
- Bidirectional `BCP47.LanguageTag` conversion via `Locale.init(_: BCP47.LanguageTag)` and `Locale.languageTag()`
- `Codable`, `ExpressibleByStringLiteral`

Static locale accessors: `Locale.en`, `Locale.en_US`, `Locale.en_GB`, etc.

**Key observation**: This `Language` wraps `ISO_639.LanguageCode` (a struct). It is a **different type** from `BCP47.LanguageTag` used in swift-translating.

#### swift-time-standard (`https://github.com/swift-standards/swift-time-standard`)

**Status**: Format conversion hub, no locale-aware formatting.

Re-exports `ISO_8601` and `RFC_5322`. Provides bidirectional conversions: ISO 8601 ↔ RFC 3339 ↔ RFC 5322. DateTime arithmetic on ISO 8601 types. No `Time` formatting beyond these wire formats.

#### Underlying ISO/IETF packages

| Package | Types | Purpose |
|---------|-------|---------|
| swift-iso-639 | `ISO_639.LanguageCode`, `.Alpha2`, `.Alpha3` | 183 language codes with bidirectional 2↔3 conversion |
| swift-iso-3166 | `ISO_3166.Code`, `.Alpha2`, `.Alpha3`, `.Numeric` | 249 country codes with 3-way conversion |
| swift-iso-15924 | `ISO_15924.Alpha4`, `.Numeric` | 226 script codes with 2-way conversion |
| swift-bcp-47 | `BCP47.LanguageTag` (= `RFC_5646.LanguageTag`) | Full RFC 5646 structured tag with language/script/region/variant/extension/privateuse |
| swift-rfc-5646 | `RFC_5646.LanguageTag` | Actual implementation — parsed, normalized, validated |

### Layer 3 — Foundations

#### swift-locale (`https://github.com/swift-foundations/swift-locale`)

**Status**: Pure re-export.

Single file `exports.swift` re-exporting `Locale_Standard`. No additional API.

#### swift-translating (`https://github.com/swift-foundations/swift-translating`)

**Status**: Full translation system. Uses Foundation for date/number formatting. Different `Language` type than L2.

9 modules:

| Module | Foundation? | Key Types |
|--------|------------|-----------|
| `Language` | No | `typealias Language = BCP47.LanguageTag` |
| `Translated` | No | `Translated<A>` — generic container with fallback |
| `TranslatedString` | No | `typealias TranslatedString = Translated<String>` |
| `SinglePlural` | No | `SinglePlural<A>` — singular/plural pair |
| `Translating` | No | String utilities, time unit translations, language names |
| `Translating+Dependencies` | No | `@Dependency(\.language)`, `@Dependency(\.languages)` — to be replaced by `@Dependency(\.locale)` |
| `Translations` | No | Built-in translation data |
| `Translating Platform` | **Yes** | `Date.description(dateStyle:timeStyle:)`, `Date.formatted(date:time:translated:)`, `Numeric.numberInWriting(language:)`, `Language.locale: Foundation.Locale`, `Language.preferred: Self` |
| `TranslatingTestSupport` | No | Dutch mock names |

**Translated<A>** internals:
- Stores `default: A` + `dictionary: [Language: A]` + `fallbackCache: [Language: A]`
- Subscript does: direct lookup → cache → compute fallback → cache → return default
- 183-entry `languageFallbackChains` table (private module-level constant in `Translated.swift`)
- Uses `Language` = `BCP47.LanguageTag` as dictionary key

**Translating Platform** Foundation usage:
- `Language.locale` — 980-line mapping from BCP47 tag → `Foundation.Locale`
- `Date.description(...)` — `DateFormatter` with per-language locale
- `Date.formatted(...)` — `Date.FormatStyle` with per-language locale
- `Numeric.numberInWriting(...)` — `NumberFormatter(.spellOut)` with per-language locale

#### swift-time (`https://github.com/swift-foundations/swift-time`)

**Status**: Pure re-export.

Re-exports `Time_Primitives`, `Clock_Primitives`, `Time_Standard`. No additional API.

### Product Layer — Triggering Example

A product-layer file required Dutch-locale formatters:

```swift
extension Format {
    struct Datum: FormatStyle {
        private static let maanden: [String] = [
            "", "januari", "februari", "maart", "april", "mei", "juni",
            "juli", "augustus", "september", "oktober", "november", "december",
        ]
        func format(_ value: Time) -> String {
            let dag = value.day.rawValue
            let maandIndex = value.month.rawValue
            let maand = maandIndex >= 1 && maandIndex <= 12
                ? Self.maanden[maandIndex] : "onbekend"
            let jaar = value.year.rawValue
            return "\(dag) \(maand) \(jaar)"
        }
    }
}
```

Same file also has `Format.Euro` (€ X.XXX,XX) and `Format.Nummer` (period thousand separator). All hardcoded Dutch.

---

## Phase 2: Gap Analysis

### GAP-1: Duplicate `Language` Types (CRITICAL)

**L2** (`swift-locale-standard`):
```swift
public struct Language: Sendable, Equatable, Hashable {
    public let code: ISO_639.LanguageCode
}
```
- Wraps `ISO_639.LanguageCode` (language + alpha2/alpha3)
- Pure language, no region/script

**L3** (`swift-translating`):
```swift
public typealias Language = BCP47.LanguageTag
```
- Full RFC 5646 tag with language + script + region + variant + extension + privateuse
- `LanguageTag.language` is an enum: `.iso639(ISO_639.LanguageCode)` or `.reserved(String)`

**These are fundamentally different concepts:**
- L2 `Language` = "What language is this?" (Dutch, English)
- L3 `Language` = "What is the full locale tag?" (nl, nl-BE, sr-Latn-RS)

Despite the same name, they model different levels of specificity. L3's `Language` (= `BCP47.LanguageTag`) is semantically equivalent to L2's `Locale`, not L2's `Language`.

**Impact**: Any code importing both `Locale_Standard` and `Language` (from translating) gets ambiguous `Language`. The two cannot interoperate without explicit conversion.

### GAP-2: Duplicate Fallback Chains

**L2** (`swift-locale-standard/Language.Fallback.swift`):
- `Language.fallbackChain: [Language]` (instance property)
- 183-entry `fallbackChains: [String: [Language]]` keyed by alpha2 code string
- Returns `[Language]` where `Language` = L2's ISO 639 wrapper

**L3** (`swift-translating/Translated.swift`):
- Private `languageFallbackChains: [Language: [Language]]` keyed by BCP47 tag
- 183 entries using `.english`, `.dutch`, `.french` etc. (BCP47 tags)
- Called from `Translated<A>.computeFallback(for:)`

**Identical data, incompatible types, different access patterns.** The L2 table keys on alpha2 strings; the L3 table keys on BCP47 tags. Both tables contain the same linguistic proximity ordering (e.g., Afrikaans → Dutch → English).

### GAP-3: Empty L1 Locale (Name Collision)

`swift-locale-primitives` defines:
```swift
public struct Locale: Sendable, Equatable, Hashable {
    public init() { }
}
```

Meanwhile L2 `swift-locale-standard` defines a fully functional `Locale` with language/region/script. L1's `Locale` struct has zero fields and zero consumers.

**Name collision**: L1's `Locale` and L2's `Locale` are different types with the same name. Importing both creates ambiguity. The empty struct should be removed, but the package should be maintained as a reserved namespace for future shared types that multiple L2 standards may need.

### GAP-4: No FormatStyle ↔ Locale Connection

`FormatStyle` protocol at L1:
```swift
public protocol FormatStyle<FormatInput, FormatOutput>: Sendable {
    func format(_ value: FormatInput) -> FormatOutput
}
```

No locale parameter. No locale-aware variant. The concrete formatters (`Format.FloatingPoint`, `Format.Numeric.*`) hardcode English conventions:
- `"."` as decimal separator
- `"E"` for scientific notation
- `K`, `M`, `B` for compact names
- `"%"` for percent

There is no `Format.Date`, `Format.Currency`, or locale-aware `Format.Number` anywhere in L1–L3.

The product layer workaround (`Format.Datum`, `Format.Euro`, `Format.Nummer`) demonstrates the pattern that should exist at a lower layer.

### GAP-5: Foundation Dependency in Translation Formatting

`Translating Platform` uses:
- `Foundation.DateFormatter` + `Foundation.Locale` for `Date.description(dateStyle:timeStyle:)`
- `Foundation.Date.FormatStyle` for `Date.formatted(date:time:translated:)`
- `Foundation.NumberFormatter(.spellOut)` for `Numeric.numberInWriting(language:)`
- `Foundation.Locale` for the 980-line `Language.locale` mapping

This is the only Foundation bridge for locale-aware formatting in the ecosystem. The prior research document (`foundation-free-time-and-locale-in-swift-translating.md`) recommended Option C: Trait-Gated Foundation Bridge, which isolates Foundation into gated targets.

**What that research did NOT address**: Where does the Foundation-free locale-aware formatting *actually live* once Foundation is isolated? The trait-gated approach removes Foundation from core modules but doesn't create a replacement. The triggering `Format.Datum` exists precisely because no Foundation-free formatting path exists.

### GAP-6: Time.Format Namespace Collision

`Time.Format` is a concrete struct for Duration formatting:
```swift
extension Time {
    public struct Format: Sendable { ... }
}
```

Adding date formatting like `Format.Datum` (Dutch date) inside `extension Time` would shadow `Time.Format`. The product-layer workaround placed `Format.Datum` inside the `Format` namespace (from `Formatting_Primitives`), not inside `Time` — but this means the formatter lives orphaned from its input type.

**The actual namespace question**: Should date formatters be `Time.Format.Date(...)` (time-centric) or `Format.Date(...)` (formatting-centric)?

### GAP-7: Missing Locale Data Tables (NEW)

No package in the ecosystem contains locale-specific data:
- Month names per language (the trigger for this research)
- Day names per language
- Number formatting conventions per locale (decimal separator, grouping separator, grouping size)
- Currency formatting conventions per locale (symbol, symbol position, decimal digits)
- Date format patterns per locale (DMY vs MDY vs YMD order, separator conventions)

ICU/CLDR provides this data for Foundation. The ecosystem has no equivalent.

### GAP-8: No Locale-Aware .formatted() on Time (NEW)

`Time` has no `.formatted()` method at all. `Duration` has `.formatted(_ format: Time.Format)` but `Time` (calendar representation) has no way to produce "March 17, 2026" or "17 maart 2026" or "2026-03-17". Only ISO 8601/RFC 3339 wire formats exist via the standards layer.

### GAP-9: Translated<A> vs Locale-Aware Formatting — Unclear Relationship (NEW)

Two approaches to localization coexist without connection:

1. **Translated<A>**: Pre-compute all translations upfront, store in dictionary, look up by language.
   - Good for: static content (labels, UI text)
   - Wasteful for: computed values (dates, numbers, currencies) — must compute for every language

2. **Locale-aware formatting**: Take a value + locale, produce a string on demand.
   - Good for: computed values
   - Not available: FormatStyle has no locale parameter

`Translating Platform` bridges these by using Foundation to format dates for every supported language into a `TranslatedString`. This is O(n) in languages for every date value, even when only one language is displayed.

---

## Phase 3: Design Proposal

### Principle: Locale-Aware Formatting is Composed Behavior

Per the five-layer architecture:
- **L1 (Primitives)**: `FormatStyle` protocol stays locale-unaware. Format types for basic (locale-independent) formatting.
- **L2 (Standards)**: `Locale`, `Language` as data types. Locale data tables.
- **L3 (Foundations)**: Locale-aware formatting. Connects `FormatStyle` + `Locale` + locale data.

This is consistent with the existing constraint: "The `FormatStyle` protocol must remain simple and non-locale-aware at L1."

### Decision 1: Canonical `Language` Type

**Recommendation**: L2's `Language` (ISO 639 wrapper) is the canonical language type.

**Rationale**:
- A language IS a language code (ISO 639), not a full BCP 47 tag
- L3's `Language = BCP47.LanguageTag` conflates language with locale — a `BCP47.LanguageTag` like `sr-Latn-RS` is a locale, not a language
- L2's `Language` has the right semantics: pure language, composed into `Locale` for region/script
- `Translated<A>` should key on `Language` (what language is this text in?), not on `BCP47.LanguageTag` (what is the full locale?)

**Migration**: `swift-translating`'s `Language` typealias changes from `BCP47.LanguageTag` to re-exporting `Locale_Standard.Language`. The `BCP47.LanguageTag` static accessors (`.english`, `.dutch`, etc.) become `Language` static accessors on the L2 type (they already exist as `.en`, `.nl`, etc. — add human-readable aliases).

**Fallback chain unification**: Delete the private fallback table in `Translated.swift`. Instead, `Translated<A>` calls `language.fallbackChain` from `Locale_Standard.Language.fallbackChain`. Single source of truth.

### Decision 2: Locale-Aware FormatStyle Pattern + Dependency Injection

**Recommendation**: Introduce `LocaleFormatStyle` protocol at L3 that composes `FormatStyle` with `Locale`. Formatters read `@Dependency(\.locale)` internally so call sites don't thread locale through.

```swift
// Layer 3: swift-formatting
public protocol LocaleFormatStyle<FormatInput>: FormatStyle where FormatOutput == String {
    var locale: Locale { get }
    init(locale: Locale)
}
```

**Locale dependency** (in `swift-locale` or `swift-formatting` — replaces the existing `@Dependency(\.language)`):

```swift
extension Dependency.Values {
    public var locale: Locale { get set }
}

extension Locale: Dependency.Key {
    public static let liveValue: Locale = .en  // or detect from system in platform target
    public static let testValue: Locale = .en
}
```

**Formatters read the dependency internally.** Call sites are clean:

```swift
// Default: locale comes from DI — no threading needed
let date = time.formatted(.long)               // reads @Dependency(\.locale)
let price = amount.formatted(.currency(.EUR))   // reads @Dependency(\.locale)
let title = translatedTitle[locale.language]     // reads @Dependency(\.locale).language

// Override granularly (tests, multi-tenant, per-request):
withDependencies {
    $0.locale = Locale(language: .nl)
} operation: {
    generatePDF()  // everything inside uses Dutch translation + formatting
}

// Explicit override when you need a specific locale in one spot:
let date = time.formatted(.long, locale: Locale(language: .nl))
```

**Implementation**: Each `LocaleFormatStyle` conformer has a stored `locale` property. The default initializer reads from DI; an explicit `locale:` parameter overrides:

```swift
extension Format {
    public struct Date: LocaleFormatStyle {
        public let locale: Locale
        public let style: Style

        /// Reads locale from @Dependency(\.locale)
        public init(style: Style = .long) {
            @Dependency(\.locale) var locale
            self.locale = locale
            self.style = style
        }

        /// Explicit locale override
        public init(locale: Locale, style: Style = .long) {
            self.locale = locale
            self.style = style
        }

        public func format(_ time: Time) -> String { ... }
    }
}
```

**Convenience on Time** (reads DI implicitly via `Format.Date()`):

```swift
extension Time {
    public func formatted(_ style: Format.Date.Style = .long) -> String {
        Format.Date(style: style).format(self)
    }

    public func formatted(_ style: Format.Date.Style = .long, locale: Locale) -> String {
        Format.Date(locale: locale, style: style).format(self)
    }
}
```

**Testability**: The DI-reading init is the *default convenience*, not a hidden side effect. The formatter itself is a pure value — once constructed with a locale, `format(_:)` is deterministic. Tests can either override via `withDependencies` or use the explicit `locale:` init directly.

**Replaces `@Dependency(\.language)`**: The existing `@Dependency(\.language)` in `swift-translating` is subsumed by `@Dependency(\.locale)`. Since `Locale` has a `language` property, `Translated<A>` reads `@Dependency(\.locale).language` instead of a separate language dependency. One dependency, one source of truth:

```swift
// Single dependency drives both translation and formatting:
withDependencies {
    $0.locale = Locale(language: .nl)
} operation: {
    let title = translatedTitle[locale.language]  // Dutch translation
    let date = time.formatted(.long)               // Dutch date formatting
}
```

This eliminates the awkwardness of setting `\.locale` and `\.language` separately and prevents them from drifting apart.

L1's `FormatStyle` stays unchanged. L3 adds the locale dimension.

**Why not add locale to FormatStyle at L1?** Because:
- Most L1 formatters (Duration, floating-point precision) are locale-independent
- Locale requires ISO standards (L2) — L1 cannot import L2
- Adding an optional locale parameter pollutes the protocol for all conformers

### Decision 3: Locale Data Tables

**Recommendation**: Locale data lives at **L2** as a new package `swift-locale-data` (or within `swift-locale-standard`).

Locale data is fundamentally specification data — it answers "what are the month names in Dutch?" the same way ISO 639 answers "what is the alpha-2 code for Dutch?". The data comes from CLDR (Unicode Common Locale Data Repository), which is an external specification.

```
swift-locale-standard/
  Sources/
    Locale Standard/          — existing: Locale, Language, fallback chains
    Locale Standard Data/     — NEW: locale-specific formatting conventions
```

Or as a separate package within swift-standards:

```
swift-locale-data/
  Sources/
    Locale Data/
      Locale.Data.swift                     — root type
      Locale.Data.Calendar.swift            — month/day names per language
      Locale.Data.Number.swift              — decimal/grouping separators per locale
      Locale.Data.Currency.swift            — currency formatting per locale
      Generated/
        Locale.Data.Calendar+Generated.swift  — CLDR-derived tables
        Locale.Data.Number+Generated.swift
```

**Minimal viable subset**: Start with the languages that have fallback chains (183 ISO 639-1 languages), covering:
1. Month names (12 × 183 = 2,196 strings)
2. Day names (7 × 183 = 1,281 strings)
3. Decimal separator, grouping separator, grouping size (3 × 183)
4. Date component ordering (DMY/MDY/YMD + separator per locale)

This is a finite, manageable dataset. We don't need full ICU/CLDR — just the formatting-relevant subset.

**Data source**: CLDR JSON (`cldr-dates-modern`, `cldr-numbers-modern`) provides exactly this data. A code generator script produces the Swift tables.

### Decision 4: Time.formatted() End-to-End

**Layer 1** (unchanged):
```swift
// Time already has year/month/day components
let time = Time(year: 2018, month: 11, day: 21, ...)
```

**Layer 2** (new locale data):
```swift
// Locale data provides month names per language
extension Locale.Data.Calendar {
    public func monthName(_ month: Time.Month) -> String
    public func dayName(_ weekday: Time.Weekday) -> String
    // ... abbreviated variants
}
```

**Layer 3** (new locale-aware formatter — reads `@Dependency(\.locale)`):
```swift
extension Format {
    public struct Date: LocaleFormatStyle {
        public let locale: Locale
        public let style: Style

        public enum Style: Sendable {
            case long      // "21 november 2018" / "November 21, 2018"
            case medium    // "21 nov 2018" / "Nov 21, 2018"
            case short     // "21-11-2018" / "11/21/2018"
            case iso8601   // "2018-11-21" (locale-independent)
        }

        public init(style: Style = .long) {
            @Dependency(\.locale) var locale
            self.locale = locale
            self.style = style
        }

        public func format(_ time: Time) -> String { ... }
    }
}

extension Time {
    public func formatted(_ style: Format.Date.Style = .long) -> String {
        Format.Date(style: style).format(self)
    }
}
```

**Product layer**:
```swift
// Before (hardcoded Dutch):
let dateString = Format.Datum().format(time)  // "21 november 2018"

// After (locale from DI — set once at the PDF generation boundary):
withDependencies { $0.locale = .nl } operation: {
    let dateString = time.formatted(.long)  // "21 november 2018"
}
```

### Decision 5: Eliminating Foundation from Translating Platform

The prior research recommended Option C (Trait-Gated Foundation Bridge). This proposal completes that picture:

**Current Foundation usage** → **Foundation-free replacement**:

| Foundation API | Replacement | Layer |
|---------------|-------------|-------|
| `DateFormatter(locale:)` → date string | `Format.Date(locale:).format(time)` | L3 |
| `Date.FormatStyle(locale:)` → date string | `Format.Date(locale:).format(time)` | L3 |
| `NumberFormatter(.spellOut, locale:)` → "twenty-one" | `Format.Number.SpellOut(locale:).format(21)` | L3 (deferred — complex) |
| `Language.locale: Foundation.Locale` | `Locale(language:)` from L2 | L2 |
| `Locale.current.language.languageCode` | Platform-specific system language detection | L3 trait-gated target |
| `String.folding(options: .diacriticInsensitive)` | Unicode NFC/NFD normalization or trait-gated target | L3 |

**Phased elimination**:
1. `Format.Date` + locale data tables replace `DateFormatter` and `Date.FormatStyle` for date formatting
2. `Format.Number` + locale data tables replace number formatting (decimal/grouping separators)
3. Number spell-out is deferred — it requires per-language grammar rules (not just data tables)
4. System language detection stays in trait-gated Foundation target (inherently platform-specific)
5. Diacritic folding stays in trait-gated Foundation target (or implement via Unicode normalization)

### Decision 6: Namespace Design

**Recommendation**: Formatting types live under `Format` (from `Formatting_Primitives`), not under `Time`.

```
Format                      (L1 — existing)
├── .FloatingPoint          (L1 — existing)
├── .Numeric                (L1 — existing)
│   ├── .SignDisplayStrategy
│   ├── .DecimalSeparatorStrategy
│   └── .Notation
├── .Date                   (L3 — new, locale-aware)
├── .Number                 (L3 — new, locale-aware)
│   └── .SpellOut           (L3 — deferred)
└── .Currency               (L3 — new, locale-aware)
```

**Rationale**:
- `Format` is the established namespace for all formatters
- `Time.Format` stays as-is for Duration formatting (locale-independent)
- No namespace collision — `Format.Date` is distinct from `Time.Format`
- Input type (`Time`) and output concern (formatting) are separate namespaces

This means: `time.formatted(locale: .nl)` calls `Format.Date(locale:).format(time)`, not `Time.Format.Date(locale:).format(time)`.

### Decision 7: L1 Locale Primitives — Maintain

**Recommendation**: Maintain `swift-locale-primitives`. Remove the current empty `Locale` struct, but keep the package alive for future shared types.

**Rationale**: L1 primitives answer "what must exist?" — and as locale-related standards grow, they may need shared primitive types that don't belong in any single standard. Examples:
- A `Locale.Identifier` protocol or trait that multiple L2 standards conform to
- Shared component types (e.g., script classification, region classification) used by ISO 15924, ISO 3166, and BCP 47
- A `LocaleAwareFormatStyle` protocol that adds a locale dimension to `FormatStyle`

The package costs nothing to maintain and prevents having to introduce an L1 dependency later when standards need shared ground.

**Immediate action**: Remove the empty `Locale` struct (it conflicts with L2's `Locale`). The package stays as a reserved namespace with `exports.swift` only, ready for population when concrete needs emerge.

### Decision 8: Translated<A> vs Locale-Aware Formatting Relationship

These are **orthogonal** mechanisms:

| | `Translated<A>` | Locale-aware formatting |
|---|---|---|
| **Purpose** | Store pre-translated content | Compute formatted output on demand |
| **When to use** | Static labels, UI text, legal terms | Dates, numbers, currencies |
| **Data shape** | Dictionary of pre-computed values | Function from (value, locale) → string |
| **Evaluation** | O(1) lookup | O(1) computation |
| **Storage** | O(n) in languages | O(1) — locale data is shared |

**They compose, not compete**:
```swift
// Set locale once at the boundary — drives both translation and formatting:
withDependencies {
    $0.locale = Locale(language: .nl)
} operation: {
    @Dependency(\.locale) var locale

    // Translated: for static text (reads locale.language)
    let title: TranslatedString = [.en: "Report", .nl: "Rapport"]

    // Locale-aware formatting: for dynamic values (reads locale)
    let dateString = time.formatted(.long)  // "21 november 2018"

    // Combined:
    let header = "\(title[locale.language]) — \(dateString)"
}
```

`Translating Platform`'s `Date.formatted(translated:)` should be deprecated once `Format.Date` exists. Instead of pre-computing dates for all languages, format on demand using the ambient locale.

---

## Architecture Summary

```
Layer 5: Applications
  └── Dutch-locale PDF product (uses Format.Date, TranslatedString)
          ↓
Layer 4: Components
          ↓
Layer 3: Foundations
  ├── swift-locale          — re-exports L2
  ├── swift-translating     — Translated<A>, TranslatedString, SinglePlural<A>
  │   ├── Language module   — re-exports L2 Language (was: BCP47.LanguageTag typealias)
  │   └── Translating Platform — trait-gated Foundation bridge (system language, spell-out)
  ├── swift-formatting      — NEW: locale-aware formatters
  │   ├── Format.Date       — locale-aware date formatting
  │   ├── Format.Number     — locale-aware number formatting
  │   └── Format.Currency   — locale-aware currency formatting
  └── swift-time            — re-exports L1 + L2
          ↓
Layer 2: Standards
  ├── swift-locale-standard — Locale, Language, fallback chains
  ├── swift-locale-data     — NEW: CLDR-derived locale data tables
  │   ├── month/day names per language
  │   ├── number formatting conventions per locale
  │   └── date ordering/separator per locale
  ├── swift-time-standard   — ISO 8601, RFC 3339/5322 conversions
  └── ISO/IETF packages     — ISO 639, ISO 3166, ISO 15924, BCP 47
          ↓
Layer 1: Primitives
  ├── swift-formatting-primitives  — FormatStyle protocol, Format namespace (UNCHANGED)
  ├── swift-time-primitives        — Time, Instant, Duration, Time.Format (UNCHANGED)
  └── swift-locale-primitives      — MAINTAINED: empty Locale struct removed, reserved for future shared types
```

---

## Migration Plan

### Phase 0: Prep (no breaking changes)

1. **Clean `swift-locale-primitives`** — remove empty `Locale` struct (name collision with L2), keep package as reserved namespace for future shared types
2. **Add human-readable aliases to L2 Language** — `.english`, `.dutch`, `.french` as aliases for `.en`, `.nl`, `.fr` in `swift-locale-standard` (enables name compatibility with L3's `Language` static accessors)

### Phase 1: Locale Data (L2, new package/target)

3. **Create `Locale.Data` in `swift-locale-standard`** (or new `swift-locale-data` package):
   - `Locale.Data.Calendar` — month names, day names per `Language` (183 languages)
   - `Locale.Data.Number` — decimal separator, grouping separator per `Locale`
   - `Locale.Data.Date` — component ordering (DMY/MDY/YMD) per `Locale`
   - Generate from CLDR JSON using a build script
   - Start with top-20 languages, expand incrementally

4. **Experiment**: Validate locale data table design with a minimal test:
   - Dutch month names → `Locale.Data.Calendar(.nl).monthName(.november)` → "november"
   - English month names → `Locale.Data.Calendar(.en).monthName(.november)` → "November"

### Phase 2: Locale-Aware Formatting (L3, new package/target)

5. **Create `swift-formatting` in `swift-foundations`** (or add targets to `swift-locale`):
   - `Format.Date` conforming to `FormatStyle<Time, String>` with `locale:` parameter
   - `Format.Number` conforming to `FormatStyle<Int, String>` and `FormatStyle<Double, String>` with locale
   - `Format.Currency` conforming to `FormatStyle<some CurrencyType, String>` with locale
   - All depend on `Locale_Standard` + `Locale.Data` (L2) + `Formatting_Primitives` (L1)

6. **Add `Time.formatted(locale:style:)`** extension via `swift-formatting` or `swift-time`:
   - `time.formatted(locale: .nl, style: .long)` → "21 november 2018"
   - `time.formatted(locale: .en, style: .long)` → "November 21, 2018"

### Phase 3: Unify Language Type

7. **Migrate `swift-translating`'s `Language`** from `BCP47.LanguageTag` to `Locale_Standard.Language`:
   - Update typealias: `public typealias Language = Locale_Standard.Language`
   - Add `.english`, `.dutch` etc. as static extensions on `Locale_Standard.Language`
   - Update `Translated<A>` dictionary key type
   - Delete private `languageFallbackChains` table — use `Language.fallbackChain` from L2
   - This is a breaking change for any consumer using `Language` as `BCP47.LanguageTag`

8. **Audit `Translated<A>` subscript** — ensure fallback resolution works with L2's `Language`:
   - L2's `Language.fallbackChain` returns `[Language]` — direct use in `computeFallback(for:)`
   - Regional variants (e.g., `.auEnglish`, `.ukEnglish`) need handling — these exist in L3 but not L2

### Phase 4: Eliminate Foundation from Formatting

9. **Deprecate `Translating Platform` date formatting** once `Format.Date` exists:
   - `Date.description(dateStyle:timeStyle:)` → `time.formatted(locale:style:)`
   - `Date.formatted(date:time:translated:)` → compute single locale on demand
   - `DateComponents` formatting → `Time.Offset` (from prior research) + locale-aware formatting

10. **Keep trait-gated Foundation bridge** for:
    - System language detection (`Locale.current.language`)
    - Number spell-out (requires per-language grammar, not just data tables)
    - Diacritic folding (unless we implement Unicode normalization)

### Phase 5: Product Layer Cleanup

11. **Replace `Format.Datum`/`Format.Euro`/`Format.Nummer`** in the product layer with L3 formatters:
    - `Format.Datum()` → `Format.Date(locale: .nl, style: .long)`
    - `Format.Euro()` → `Format.Currency(locale: .nl, currency: .EUR)`
    - `Format.Nummer()` → `Format.Number(locale: .nl)`

---

## Open Questions

### Q1: Package or Target for Locale Data?

Should locale data be a separate package (`swift-locale-data`) or a new target within `swift-locale-standard`?

**Arguments for separate package**: Large generated data files shouldn't bloat the locale-standard package. Consumers who don't need formatting don't need the data.

**Arguments for same package**: It's all locale specification data. One fewer package to manage.

**Recommendation**: New target within `swift-locale-standard` initially. Extract to separate package if size becomes an issue.

### Q2: CLDR Data Scope

How much CLDR data do we need? Full CLDR covers hundreds of locales with extensive formatting rules.

**Recommendation**: Start with the 183 ISO 639-1 languages that have fallback chains. Cover:
- Month names (full + abbreviated)
- Day names (full + abbreviated)
- Decimal/grouping separators
- Date component ordering

This is the minimum viable set. Expand as needed.

### Q3: Regional Variants in Translated<A>

L3's `Language` (currently `BCP47.LanguageTag`) supports regional variants like `.auEnglish`, `.ukEnglish`. L2's `Language` (ISO 639) does not — it only has `.en`.

**Options**:
a) `Translated<A>` keys on `Locale` (language + region) instead of `Language`
b) `Translated<A>` keys on `Language`, regional variants resolve to base language
c) Add regional variant support to L2's `Language` (breaks clean ISO 639 semantics)

**Recommendation**: Option (b). `Translated<A>` is for translation (language-level), not locale-specific formatting. "Hello" is the same in US English and UK English. Formatting ("11/21/2018" vs "21/11/2018") is a locale concern handled by `Format.Date(locale:)`.

### Q4: Interaction with Time.Offset (Prior Research)

The prior research document proposed `Time.Offset` for calendar displacements (replacing Foundation's `DateComponents`). Locale-aware formatting of offsets ("2 years 3 months") requires both `Time.Offset` and locale data. Should `Time.Offset` and locale-aware offset formatting be part of this plan?

**Recommendation**: Yes, but as a later phase. `Time.Offset` is an L1 addition (already designed). Locale-aware offset formatting would be an L3 formatter: `Format.Duration.Calendar(locale:)` or similar.

### Q5: `swift-locale` at L3 — Expand or Keep as Re-export?

Currently `swift-locale` at L3 is a pure re-export of `swift-locale-standard`. Should locale-aware formatters live in `swift-locale` or a new `swift-formatting` package?

**Recommendation**: New `swift-formatting` package at L3. Locale-aware formatting composes locale + formatting primitives + locale data — it's a distinct concern from the locale type itself. Keeps `swift-locale` as the simple locale type re-export.

---

## Converged Design (Collaborative Discussion with ChatGPT, 2026-03-17)

The following design was converged through a 4-round collaborative discussion between Claude and ChatGPT, then refined based on standards-dependency analysis. Full transcript: `swift-institute/Research/localization-architecture-discussion-transcript.md`.

**This section supersedes the Phase 3 Design Proposal above** where they conflict. The Phase 1–2 inventory and gap analysis remain valid.

### Standards Foundation

The localization architecture is built on existing standard implementations, not reimplementations. The dependency graph:

```
ISO 639, ISO 3166, ISO 15924       (L2 — atomic standard types)
              ↓
         RFC 5646                    (L2 — language tag parsing, uses ISO types directly)
              ↓
          BCP 47                     (L2 — thin re-export: BCP47.LanguageTag = RFC_5646.LanguageTag)
              ↓
       Locale Standard               (L2 — composes Language + region? + script?)
```

`RFC_5646.LanguageTag` stores `ISO_639.LanguageCode`, `ISO_3166.Alpha2`, `ISO_15924.Alpha4` directly. L2's `Locale` is a narrower projection of the same standard types (language + region? + script?), excluding BCP 47's variants, extensions, and private-use subtags. Both compose FROM the standards — neither reimplements them.

### Key Decisions

1. **Standards-based identity model**: All locale identity is built on existing standard packages (`swift-iso-639`, `swift-iso-3166`, `swift-iso-15924`, `swift-rfc-5646`, `swift-bcp-47`). L2 `Language` (ISO 639 wrapper) for pure language. L2 `Locale` (language + region? + script?) for locale identity — a narrower view of the same ISO types that `RFC_5646.LanguageTag` uses. No separate `TranslationKey` type. No reimplementation of BCP 47 or any standard.

2. **Single dependency**: `@Dependency(\.locale)` replaces both `@Dependency(\.language)` and any separate locale dependency. `Translated<A>` reads the locale directly.

3. **Translated<A> keys on Locale**: `Locale` is a projection of the standard types (language + optional script + optional region), not a replacement for `BCP47.LanguageTag`. Translation lookup observes only this authored-content identity subset. Other locale preference dimensions (numbering system, calendar, collation, hour cycle) are excluded from translation identity. If `Locale` later grows such dimensions, they must either be excluded from equality/hash used by translation lookup, or a narrower translation identity must be factored out then.

4. **Formatter purity**: `Format.Date`, `Format.Number`, `Format.Currency` always take explicit `locale:` in their init. They are deterministic pure values. The `time.formatted(.long)` convenience reads `@Dependency(\.locale)` at the extension method boundary, not inside the formatter:
   ```swift
   extension Time {
       public func formatted(_ style: Format.Date.Style = .long) -> String {
           @Dependency(\.locale) var locale
           return Format.Date(locale: locale, style: style).format(self)
       }
   }
   ```

5. **ICU bridge at L3**: Standalone `swift-icu` package with thin `_LocaleICU` Clang module (replicating Apple's swift-foundation pattern, but Foundation-free). Full CLDR coverage via system ICU. Phase 1 requires ICU-backed platform (macOS, Linux, Windows, Android).

6. **Provider-shaped internal seam**: Formatters access locale data through protocol-shaped providers (`CalendarSymbolProvider`, `NumberSymbolProvider`, `CurrencySymbolProvider`). ICU backs them today. Static L2 tables slot in later (Option C) without changing the public API.

7. **Namespace**: Locale-aware formatters under `Format` (from `Formatting_Primitives`). `Format.Date`, `Format.Number`, `Format.Currency`. Not under `Time`.

8. **Fallback architecture**: Shared engine (`Locale.FallbackChain`), separate policies (`Translation.FallbackPolicy`, `Formatting.FallbackPolicy`). Default order: exact → drop region → drop script → linguistic chain → default. Documented as default policy, not invariant. Existing L2 `Language.fallbackChain` data feeds the linguistic step.

9. **L1 FormatStyle unchanged**: Stays locale-unaware. Locale awareness is composed behavior at L3.

10. **swift-locale-primitives maintained**: Empty `Locale` struct removed (name collision). Package kept as reserved namespace for future shared types.

### Architecture

```
L3: swift-icu (thin package — Foundation-free ICU bridge)
├── _LocaleICU (Clang module — ICU C headers + modulemap)
└── ICU (Swift wrappers — symbol retrieval, caching, error handling)

L3: swift-formatting (depends on swift-icu + L2 standards)
├── Format.Date — via CalendarSymbolProvider (backed by ICU)
├── Format.Number — via NumberSymbolProvider (backed by ICU)
├── Format.Currency — via CurrencySymbolProvider (backed by ICU)
├── @Dependency(\.locale) registration
└── Time.formatted(_:) convenience (DI read at call boundary)

L3: swift-translating (updated)
├── Translated<A> keyed on Locale (narrowed from BCP47.LanguageTag)
├── Locale.FallbackChain engine + Translation.FallbackPolicy
└── Compatibility adapters from BCP47.LanguageTag

L2: swift-locale-standard (existing, enhanced)
├── Locale (composes Language + ISO_3166.Alpha2? + ISO_15924.Alpha4?)
├── Language (wraps ISO_639.LanguageCode)
├── Locale.FallbackChain (shared engine)
└── depends on: swift-bcp-47, swift-iso-639, swift-iso-3166, swift-iso-15924

L2: swift-bcp-47 → swift-rfc-5646 (existing — BCP47.LanguageTag = RFC_5646.LanguageTag)
└── depends on: swift-iso-639, swift-iso-3166, swift-iso-15924

L2: swift-iso-639, swift-iso-3166, swift-iso-15924 (existing — atomic standard types)

L1: swift-formatting-primitives (UNCHANGED)
├── FormatStyle protocol
└── Format namespace, Format.FloatingPoint, Format.Numeric.*
```

Future Option C upgrade (ICU-free targets):
```
L2: swift-locale-data (static tables extending existing standard types)
├── Calendar data — extends ISO_639.LanguageCode with month/day names
├── Number data — extends ISO_3166.Alpha2 with separator conventions
└── Currency data — extends ISO_4217 codes with symbol/placement

L3: swift-formatting checks L2 providers first, falls back to ICU
```

### Migration Plan

- **Phase 0**: Clean L1 locale placeholder. Add `.english`, `.dutch` aliases to L2 `Language`.
- **Phase 1**: Create `swift-icu` (L3). Create `swift-formatting` (L3) with `Format.Date`, `Format.Number`, provider seam, `@Dependency(\.locale)`, `Time.formatted(_:)`.
- **Phase 2**: Add `Format.Currency`. Extend number formatting with locale-aware sign/notation/precision.
- **Phase 3**: Narrow `Translated<A>` keying from `BCP47.LanguageTag` to `Locale` (same underlying ISO types, minus variants/extensions/private-use). Unify fallback chains. Add BCP47 compatibility adapters.
- **Phase 4**: Deprecate `Translating Platform` Foundation formatting. Product layer cleanup.
- **Future**: Add `swift-locale-data` at L2 for embedded/ICU-free targets.

### MVP Scope (Phase 1)

**In scope:**
- Date formatting: long, medium, short styles via ICU calendar symbols
- Basic number formatting: decimal separator, grouping separator per locale
- `@Dependency(\.locale)` registration
- `Time.formatted(_:)` and `Time.formatted(_:locale:)` conveniences

**Explicitly out of scope:**
- Number spell-out, non-Western digit systems, non-Gregorian calendars
- Plural-sensitive units, relative dates, collation, text segmentation
- ICU-free targets (requires Option C)

### Normative Constraints

1. **Standards-based**: All locale identity types compose FROM existing standard packages (`swift-iso-639`, `swift-iso-3166`, `swift-iso-15924`, `swift-rfc-5646`, `swift-bcp-47`). No reimplementation of standard parsing, validation, or semantics. L2 `Locale` is a narrower projection of the same ISO types that `RFC_5646.LanguageTag` uses.
2. **ICU-backed Phase 1**: Locale-aware formatting requires an ICU-backed platform. ICU-free targets remain unsupported until a static-data backend is introduced (Option C).
3. **Translation identity subset**: Translation lookup observes only the authored-content identity subset of Locale: language, optional script, optional region. If `Locale` later grows formatting-preference dimensions, those must be excluded from translation lookup equality/hash.
4. **Fallback as policy**: The fallback order (exact → drop region → drop script → linguistic → default) is the product default policy, not a universal invariant. Custom policies can reorder.
5. **Domain-oriented API**: The public API is domain-oriented (month names, separators, symbols), not ICU-oriented. ICU is an implementation detail behind provider protocols.
6. **Future static tables extend standards**: When Option C is implemented, static locale data tables extend existing standard types (`ISO_639.LanguageCode`, `ISO_3166.Alpha2`, `ISO_4217` codes), not parallel data types.

---

## References

- Collaborative discussion transcript: `swift-institute/Research/localization-architecture-discussion-transcript.md`
- Prior research: `Research/foundation-free-time-and-locale-in-swift-translating.md` (Option C recommendation)
- Apple swift-foundation ICU pattern: `https://github.com/swiftlang/swift-foundation/tree/main/Sources/FoundationInternationalization/`
- L2 Locale: `https://github.com/swift-standards/swift-locale-standard/tree/main/Sources/Locale Standard/`
- L3 Translating: `https://github.com/swift-foundations/swift-translating/tree/main/Sources/`
- L1 Formatting: `https://github.com/swift-primitives/swift-formatting-primitives/tree/main/Sources/Formatting Primitives/`
- L1 Time: `https://github.com/swift-primitives/swift-time-primitives/tree/main/Sources/Time Primitives Core/`
- CLDR: Unicode Common Locale Data Repository (accessed via ICU, not embedded)
