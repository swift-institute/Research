# Foundation-Free Time and Locale in swift-translating

<!--
---
version: 1.0.0
last_updated: 2026-03-26
status: RECOMMENDATION
tier: 2
---
-->

## Context

swift-translating is being migrated from coenttb/ to swift-foundations (Layer 3). The package currently imports Foundation in 30 of 33 source files, primarily for:

1. **Date/DateComponents/DateFormatter** — time representation and formatting
2. **Locale** — locale-aware formatting and Language ↔ Locale bridging
3. **String.folding(options:locale:)** — diacritic-insensitive normalization

The swift-primitives layer already provides Foundation-free alternatives for time (`Time`, `Instant`, `Duration`) and has a locale stub awaiting implementation. The question is how to eliminate Foundation from swift-translating's core modules.

**Trigger**: During Phase 3a migration, `DateComponents.swift` caused a Sendable violation (tuples aren't Sendable in Swift 6). Rather than patching with `nonisolated(unsafe)`, we need the correct Foundation-free design.

## Question

What upstream additions and downstream changes are needed to make swift-translating Foundation-free?

## Foundation Usage Inventory

| Module | Foundation Types Used | Essential? |
|--------|---------------------|------------|
| Language | `Locale.init(identifier:)`, `Locale.LanguageDirection` | Bridging only |
| Language (Locale.Language.swift) | 200+ `Locale` static extensions | Convenience |
| Language (Language.locale.swift) | 980-line Language → `Locale` mapping | Core bridging |
| Language (Locale.swift) | `Locale.autoupdatingCurrent`, `locale.language.languageCode` | Core bridging |
| Translated | None (via Language re-export) | No |
| TranslatedString | None (via Language re-export) | No |
| SinglePlural | None (via Language re-export) | No |
| Translating+Dependencies | None (via Dependencies) | No |
| Translating (String.swift) | `String.folding(options:locale:)` | Replaceable |
| Translating (Date.swift) | `Date`, `DateFormatter`, `DateFormatter.Style` | **Now in DateFormattedLocalized** |
| Translating (DateComponents.swift) | `DateComponents`, KeyPath access | **Now in DateFormattedLocalized** |
| DateFormattedLocalized | `Date.FormatStyle`, `DateFormatter`, `DateComponents`, `Locale` | Essential for Foundation bridge |
| Translations | None | No |
| TranslatingTestSupport | None | No |

## Analysis

### Option A: Stratified Foundation Isolation

**Approach**: Keep Foundation confined to explicit bridging modules. Core modules (Language, Translated, TranslatedString, SinglePlural, Translating) become Foundation-free. Foundation usage lives only in `DateFormattedLocalized` (explicit Foundation bridge) and `Language` (locale bridging layer).

**Upstream changes needed**:
- None immediately — `Time` already covers calendar components

**Downstream changes**:
1. **Already done**: Move `Date.swift` and `DateComponents.swift` from Translating → DateFormattedLocalized
2. **String.swift**: Replace `String.folding(options: .diacriticInsensitive, locale:)` with a manual Unicode normalization or accept Foundation for this one file
3. **Language module**: Accept Foundation here — Language ↔ Locale bridging is inherently a Foundation bridge. The 980-line mapping file IS the bridge layer.

**Pros**: Minimal upstream work. Clear boundary: "DateFormattedLocalized and Language use Foundation; everything else doesn't."
**Cons**: Language module still uses Foundation. Locale.Language.swift (200+ convenience extensions) keeps Foundation.

### Option B: Full Primitives Replacement

**Approach**: Implement `Locale` in swift-locale-primitives with language/region fields, replace Foundation.Locale entirely. Replace `Date` with `Time`/`Instant` throughout.

**Upstream changes needed**:
1. **swift-locale-primitives**: Implement locale data (BCP 47 language tags, ISO 639 codes, ISO 3166 regions). This is a major effort — Foundation's Locale wraps ICU data.
2. **swift-time-primitives**: Add `Time.Components` (optional bag, like DateComponents) for partial time representations
3. **swift-formatting-primitives**: Add locale-aware date formatting (day/month names per locale)

**Downstream changes**:
1. Replace all `Foundation.Locale` with primitives `Locale`
2. Replace all `Date` usage with `Time` or `Instant`
3. Replace `DateFormatter` with primitives formatting
4. Replace `DateComponents` with `Time.Components` or direct `Time` usage

**Pros**: Fully Foundation-free. Sendable by default. Aligns with Layer 1 philosophy.
**Cons**: Massive upstream effort. Locale data (ICU equivalent) is person-years of work. Premature for current migration timeline.

### Option C: Trait-Gated Foundation Bridge (Recommended)

**Approach**: Core swift-translating is Foundation-free. Foundation integration is provided via a trait-gated target (SE-0450 pattern). Language ↔ Locale bridging moves to a separate `Language+Foundation` target activated by trait.

**Upstream changes needed**:
1. **swift-time-primitives**: Add `Time.Delta` — a bag of optional time components for representing durations/differences (replaces DateComponents for the "2 years 3 months" use case)

**Downstream changes**:
1. **Already done**: Date.swift, DateComponents.swift moved to DateFormattedLocalized
2. **Language module**: Extract Foundation-dependent files (`Language.locale.swift`, `Locale.swift`, `Locale.Language.swift`) into a new `Language+Foundation` target
3. **Language core**: Keep enum definition, raw values, allCases — no Foundation needed
4. **DateComponents.swift**: Rewrite to use `Time.Delta` instead of Foundation.DateComponents
5. **String.swift**: Extract `normalized()` to a Foundation-gated extension or implement manually
6. **Translating target**: Remove `import Foundation` — should have none after Date/DateComponents moved out
7. **Package.swift**: Add trait `.foundation` gating `Language+Foundation` and `DateFormattedLocalized`

**Structure after migration**:
```
Language                    — Foundation-FREE (enum + raw values)
Language+Foundation         — trait-gated: Language ↔ Locale bridging
Translated                  — Foundation-FREE
TranslatedString            — Foundation-FREE
SinglePlural                — Foundation-FREE
Translating+Dependencies    — Foundation-FREE
Translating                 — Foundation-FREE
Translations                — Foundation-FREE
DateFormattedLocalized      — trait-gated: Date/DateFormatter extensions
```

**Upstream: Time.Offset design sketch**:

`Time.Offset` follows the affine displacement pattern: `Time` is a point in calendar space, `Time.Offset` is a displacement. Uses `Tagged<CoordinateType, Int>` for type-safe components with existing coordinate types (`Time.Year`, `Time.Month`, etc.) as phantom tags.

```swift
extension Time {
    /// A displacement in calendar space.
    ///
    /// Unlike `Time` (an absolute moment), `Offset` represents a relative
    /// duration in calendar terms (e.g., "2 years, 3 months, 5 days").
    /// Unlike `Duration` (absolute seconds + attoseconds), calendar components
    /// have variable length (months, years) and cannot be converted to fixed durations
    /// without a reference point.
    public struct Offset: Sendable, Equatable, Hashable {
        public var years: Tagged<Time.Year, Int>
        public var months: Tagged<Time.Month, Int>
        public var weeks: Tagged<Time.Week, Int>
        public var days: Tagged<Time.Day, Int>
        public var hours: Tagged<Time.Hour, Int>
        public var minutes: Tagged<Time.Minute, Int>
        public var seconds: Tagged<Time.Second, Int>

        public init(
            years: Int = 0,
            months: Int = 0,
            weeks: Int = 0,
            days: Int = 0,
            hours: Int = 0,
            minutes: Int = 0,
            seconds: Int = 0
        ) { ... }
    }
}
```

**Note**: With production `ExpressibleByIntegerLiteral` on `Tagged` (approved in `tagged-literal-conformances.md` v3.0), `Tagged<Time.Year, Int>` accepts literals directly. The convenience init taking `Int` parameters follows [IMPL-010] (push Int to the edge) but default parameter values also work on Tagged stores: `years: Tagged<Time.Year, Int> = 0`.

**Pros**: Clean Foundation boundary. Core modules compile without Foundation. Incremental — can implement locale primitives later without breaking existing code. `Time.Offset` is a small, useful upstream addition. Follows SE-0450 trait pattern already used elsewhere in the ecosystem.

**Cons**: More targets to manage. Trait-gated targets add Package.swift complexity.

### Comparison

| Criterion | A: Stratified | B: Full Primitives | C: Trait-Gated |
|-----------|--------------|-------------------|----------------|
| Foundation-free core | Partial (Language still uses it) | Complete | Complete |
| Upstream effort | None | Very high (locale data) | Low (Time.Offset only) |
| Migration effort | Low | Very high | Medium |
| Sendable safety | Partial | Complete | Complete |
| Future-proof | Moderate | Excellent | Excellent |
| Timeline risk | None | Blocks migration | Low |
| Follows ecosystem patterns | Yes | Yes | Yes (SE-0450 traits) |

## Outcome

**Status**: RECOMMENDATION

**Recommended**: Option C (Trait-Gated Foundation Bridge)

**Rationale**:
1. Core translation types (Language, Translated, TranslatedString, SinglePlural) have no inherent need for Foundation
2. Foundation dependency exists only for bridging (Language ↔ Locale) and formatting (Date/DateFormatter)
3. Trait-gated targets cleanly separate the Foundation bridge from the Foundation-free core
4. `Time.Offset` is a small, well-scoped upstream addition that fills a real gap (calendar displacement)
5. This doesn't block future work on primitives Locale — when that's ready, the trait-gated bridge becomes less necessary

**Implementation order**:
1. Add `Time.Offset` to swift-time-primitives (small PR)
2. Rewrite DateComponents.swift to use `Time.Offset`
3. Extract Language Foundation bridging to `Language+Foundation` target
4. Remove Foundation from Translating module's String.swift (manual diacritic folding or separate target)
5. Verify all core targets build without Foundation

## References

- swift-time-primitives: `/Users/coen/Developer/swift-primitives/swift-time-primitives/`
- swift-locale-primitives: `/Users/coen/Developer/swift-primitives/swift-locale-primitives/`
- swift-formatting-primitives: `/Users/coen/Developer/swift-primitives/swift-formatting-primitives/`
- SE-0450: Package traits (trait-gated targets)
- Prior research: `sendable-in-rendering-and-snapshot-infrastructure.md`
- `swift-identity-primitives/Research/tagged-literal-conformances.md` v3.0 — production literal conformance approved
- `swift-identity-primitives/Research/revisiting-tagged-production-literal-conformances.md` — identity-numeric safety analysis
