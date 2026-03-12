# Converged Plan: swift-translating Migration

## Summary

Replace swift-translating's `Language` enum with `public typealias Language = BCP47.LanguageTag`, organize language tag constants across four distinct surfaces (standards type, canonical conveniences, regional conveniences, library policy sets), split Foundation-dependent code into a downstream `Translating Platform` module, and establish a strict one-way dependency graph where core modules never import Foundation.

## Architectural Invariants

These are non-negotiable guardrails for the migration:

1. **`BCP47.LanguageTag` owns tag semantics** — construction, validation, normalization, Codable
2. **`Translating.Languages` owns product policy** — supported sets, defaults, fallback language
3. **`Translating Platform` owns Foundation/system integration** — locale bridging, date formatting, system language detection, number spellout
4. **Core modules must not import Foundation** — enforced at package level
5. **Aggregate language collections must not be attached to the standards type** — no `BCP47.LanguageTag.wellKnown` or `.supported`
6. **Future regional convenience additions require**: ISO-standard components (ISO 639 + ISO 3166) AND widespread real-world use

## Key Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | `Language = BCP47.LanguageTag` via typealias | Direct replacement per user decision; preserves call-site ergonomics |
| 2 | Four surfaces: type, canonical conveniences, regional conveniences, policy sets | Separates standards semantics from product policy |
| 3 | Generated `try!` constants (Tier A); structured RFC 5646 constructors deferred (Tier B) | Preserves momentum; doesn't block on upstream |
| 4 | Codable: decode leniently, encode canonically | RFC 5646 already normalizes case on input; no custom logic needed |
| 5 | Module name: `Translating Platform` | Role-based, avoids Foundation/Foundations naming confusion |
| 6 | One-way dependency: Platform → Core, never reverse | Package-level enforcement |
| 7 | `Translating.Languages.supported` replaces `Language.allCases` | Explicit policy ownership, no fake completeness claims |
| 8 | Mass initializers kept as-is | Reduces blast radius; redesign is a separate track |
| 9 | String.swift strict triage: keep/move/evict | Only translation-adjacent Foundation-free helpers stay |
| 10 | `swift-locale-primitives` deferred | Don't couple two design problems |
| 11 | `Dependency.Key` liveValue = `Translating.Languages.fallback`; system detection opt-in via Platform | Mechanism/policy separation |

## Four-Surface Model

| Surface | Location | Examples |
|---------|----------|----------|
| Standards type | `Language` module | `public typealias Language = BCP47.LanguageTag` |
| Canonical conveniences | Extension on `BCP47.LanguageTag` in `Language` module | `.english`, `.dutch`, `.french` (~170 from ISO 639 alpha-2) |
| Regional conveniences | Extension on `BCP47.LanguageTag` in `Language` module | `.usEnglish` (en-US), `.ukEnglish` (en-GB), `.auEnglish` (en-AU), `.caEnglish` (en-CA) |
| Library policy sets | `Translating.Languages` in `Translating` module | `.supported`, `.common`, `.fallback` |

## Module Graph (Post-Migration)

```
Language                    → BCP 47 (Layer 2)
Translated                  → Language
TranslatedString            → Translated
SinglePlural                → Language, Translated, TranslatedString
Translating+Dependencies    → Language, Translated, TranslatedString, Dependencies
Translating                 → Language, Translated, TranslatedString, SinglePlural,
                               Translating+Dependencies, Translations
                               (NO DateFormattedLocalized, NO Foundation)
Translations                → Translating
TranslatingTestSupport      → (no deps)

Translating Platform        → Translating, Foundation  (downstream, opt-in)
```

## String.swift Triage

| Verdict | Members |
|---------|---------|
| **Keep (core)** | `any`/vowels/consonants, `nonBreakingSpace`/`withNonBreakingSpace`, `if(_:append:)`, punctuation helpers (period/semicolon/colon/comma/questionmark), case transforms (capitalizingFirstLetter etc.), Placeholder, trunc/ifEmpty/truncated, plural |
| **Move to Platform** | `number_in_writing` (NumberFormatter spellout) |
| **Evict from package** | `normalized()`, `slug()`, `camelized`, `isAlphanumeric`, `typeName()`, `variableName()`, `sanitized()`/`sanitize()`/`whitespaceCondensed()`, `fileName()`/`filePathSafe()`, `write(toFile:)`, `importTitle()`, `kvk`, `toPostCodeString` |

## Action Items

### Phase 1: Upstream preparation
- [ ] Write generator script for BCP 47 static constants from ISO 639 alpha-2 data
- [ ] Generate ~170 canonical convenience extensions (`static let english = try! BCP47.LanguageTag("en")`)
- [ ] Hand-write 4 regional English variant constants

### Phase 2: Language module rewrite
- [ ] Replace `Language` enum with `public typealias Language = BCP47.LanguageTag`
- [ ] Add generated static convenience extensions
- [ ] Remove Foundation files: `Locale.swift`, `Language.locale.swift`, `Locale.Language.swift`
- [ ] Remove empty `exports .swift`
- [ ] Update `Package.swift`: add `swift-bcp-47` dependency for Language target

### Phase 3: Core module cleanup
- [ ] Remove all `import Foundation` from core modules
- [ ] Add `Translating.Languages` namespace with `supported`, `common`, `fallback`
- [ ] Replace all `Language.allCases` with `Translating.Languages.supported`
- [ ] Update `LanguagesKey` to derive from `Translating.Languages.supported`
- [ ] Update `Language: Dependency.Key` liveValue to `Translating.Languages.fallback`
- [ ] Remove `Locale.preferredLanguages` usage from `Translating+Dependencies/extensions.swift`
- [ ] Drop `DateFormattedLocalized` dependency from `Translating` target

### Phase 4: String.swift triage
- [ ] Keep Foundation-free translation-adjacent helpers in core
- [ ] Move `number_in_writing` to Platform module
- [ ] Evict non-translation utilities (~15 members)

### Phase 5: Create `Translating Platform` module
- [ ] New target in Package.swift: depends on `Translating` + Foundation
- [ ] New library product: `Translating Platform`
- [ ] Move `DateFormattedLocalized` content (Date formatting, DateComponents)
- [ ] Move `Translating/Date.swift` (DateFormatter usage)
- [ ] Move `number_in_writing` from String.swift
- [ ] Add `Language ↔ Foundation.Locale` bridge (from removed Locale.swift / Language.locale.swift)
- [ ] Add system language resolver (from removed `preferredLanguageForUser()`)
- [ ] Expose resolver for installation via `prepareDependencies`

### Phase 6: Package.swift finalization
- [ ] Add `swift-bcp-47` dependency (via path to swift-standards)
- [ ] Add `Translating Platform` library product
- [ ] Verify core targets have no Foundation dependency
- [ ] Add ecosystem swift settings to new targets

### Phase 7: Migration contract verification
- [ ] All core modules compile without Foundation
- [ ] No reverse dependency from core to `Translating Platform`
- [ ] `translated[.english]` style ergonomics work
- [ ] Mass initializers remain source-compatible
- [ ] Hash/key stability: `[Language: A]` dictionary behavior regression-tested across old values and new canonicalized tags
- [ ] Codable round-trips correctly, including legacy `"en-au"` decoding → canonical `"en-AU"` encoding
- [ ] Snapshot/golden-file tests updated for canonical case normalization
- [ ] Policy collections referenced only through `Translating.Languages`
- [ ] System-language behavior present only when Platform resolver is explicitly installed
- [ ] All tests pass (update test imports for Platform module)

## Agreed By
- Claude: Round 3
- ChatGPT: Round 4 (confirmed CONVERGED, no remaining concerns)
