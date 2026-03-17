# Collaborative Discussion: Localization Architecture for Swift Institute

Started: 2026-03-17
Participants: Claude (Anthropic), ChatGPT (OpenAI)

---

## Round 1 - Claude

### Position

The localization architecture needs a unified design across the five-layer stack. After inventorying every source file across 4 packages and their dependencies, I propose:

1. **Single dependency**: `@Dependency(\.locale)` is the one source of truth. Formatters read it internally — call sites are `time.formatted(.long)`, not `time.formatted(locale: .nl, style: .long)`. `Translated<A>` reads `locale.language`. No separate `@Dependency(\.language)`.

2. **L2 locale data**: CLDR-derived month names, day names, separators live at L2 (Standards) because they're specification data — "what are the Dutch month names?" is the same kind of question as "what is the ISO 639 code for Dutch?"

3. **Formatters with DI-reading inits**: `Format.Date(style: .long)` reads `@Dependency(\.locale)` in its init, captures it as a stored property. The formatter value itself is pure once constructed. Explicit `Format.Date(locale: .nl, style: .long)` overrides for one-off cases.

4. **L2 Language as canonical**: `Language` wraps `ISO_639.LanguageCode`. It's a pure language identifier. `BCP47.LanguageTag` is a locale tag, not a language — the L3 typealias conflates these concepts.

5. **Translated<A> stays**: It serves pre-computed human translations. Locale-aware formatting serves algorithmic on-demand formatting. They compose via shared locale dependency.

### Agreements
(First round - none yet)

### Concerns

**Self-critique — things I'm not fully confident in:**

- **CLDR at L2**: Is CLDR data really "specification" data? It's maintained by Unicode Consortium, versioned, and structured — but it's also large, frequently updated, and not a formal standard like ISO 639. Could argue it's "composed behavior" (L3) rather than "specification" (L2).

- **DI in init**: Reading `@Dependency(\.locale)` inside a struct initializer means the formatter captures the locale at construction time, not at format-call time. If someone creates a `Format.Date()` early and uses it later after the dependency changes, they get the old locale. Is this the right semantic?

- **Language unification breaking change**: Migrating `Translated<A>` from `BCP47.LanguageTag` keys to `Language` keys is a breaking change for every consumer. The migration path for code that uses regional variants (`.auEnglish`, `.ukEnglish`) is unclear — these exist as BCP47 tags but not as ISO 639 codes.

- **Locale data size**: 183 languages × (12 months + 7 days + abbreviations + number conventions) could be 10K+ strings. Is that acceptable at L2 where packages are meant to be lightweight?

### Proposals

1. Consider whether locale data should be a **separate L2 package** (`swift-locale-data`) rather than a target within `swift-locale-standard`, to keep the core locale types lightweight.

2. The `@Dependency(\.locale)` pattern should be validated with an experiment before committing — specifically testing: DI reading in init vs at format-call time, interaction with `withDependencies` scoping, and Sendable implications.

3. The Language migration needs a compatibility shim phase — perhaps a deprecated `BCP47.LanguageTag` extension that converts to `Language`, giving consumers time to migrate.

### Questions

1. **For ChatGPT**: In your experience with localization systems (ICU, Android resources, gettext, Rails i18n), is there a precedent for splitting "locale identity" from "locale data" the way we're proposing (L2 types vs L2 data tables)? Or do successful systems always keep them together?

2. **For ChatGPT**: The single `@Dependency(\.locale)` replacing both language and locale — do you see cases where a user genuinely needs different languages for translation vs formatting? (e.g., "show me Dutch text but format dates in English"). If so, does the single-dependency design handle this, or do we need an escape hatch?

3. **For ChatGPT**: Is reading DI in a struct initializer a known pattern or anti-pattern in dependency injection systems? The alternative is reading at format-call time (lazy), but that makes the formatter impure.

4. **For ChatGPT**: For the CLDR data scope question — what's the minimum viable locale data set that would cover 90%+ of real-world formatting needs? We estimated ~183 languages × basic fields. Is that right, or is there a smarter 80/20 cut?

### Status: EXPLORING

---
## Round 2 - Claude

### Position

ChatGPT's pushback has moved me on three significant points. Updated position:

1. **Translated<A> should key on `Locale`, not `Language`**. ChatGPT is right that zh-Hans vs zh-Hant and sr-Latn vs sr-Cyrl are translation-level distinctions, not just formatting. The user reinforced this: "we should NOT assume current code is perfect — could be that they should rely on full locale." L2's `Locale` already has `language + region? + script?`, making it the right key. `Locale(language: .zh, script: .Hans)` and `Locale(language: .zh, script: .Hant)` are different translation targets. The fallback chain becomes locale-level: strip region → strip script → linguistic fallback.

2. **DI reads at the call boundary, not in formatter init**. ChatGPT's alternative is strictly better. `Format.Date` stays a pure deterministic value — always requires `locale:` in its init. The `time.formatted(.long)` convenience reads `@Dependency(\.locale)` at the extension method boundary and passes it through. No hidden capture, no snapshot semantics, no caching surprises. I concede this fully.

3. **Locale data as separate L2 package**. Not a target within `swift-locale-standard`, but a dedicated `swift-locale-data` package. This is the right architectural boundary — identity types stay lightweight, generated CLDR tables have their own versioning/size lifecycle.

Remaining position (unchanged):
- Single `@Dependency(\.locale)` as default path — but with explicit override on every API
- `Format.Date` under `Format` namespace (not `Time`)
- Foundation elimination scoped to date + basic number formatting for MVP; currency/spell-out deferred
- L1 `FormatStyle` stays locale-unaware

### Agreements

**New agreements this round:**

1. **DI at call boundary, not in init** — ChatGPT's `Time.formatted(_:)` pattern is correct:
   ```swift
   extension Time {
       func formatted(_ style: Format.Date.Style) -> String {
           @Dependency(\.locale) var locale
           return Format.Date(locale: locale, style: style).format(self)
       }
   }
   ```
   `Format.Date` is always constructed with an explicit locale. The ambient read happens once, at the outermost convenience, where the user expects it. This eliminates snapshot semantics, caching edge cases, and the "formatter value plus ambient capture" problem. Fully agreed.

2. **Translation keying needs more than pure ISO 639** — The zh-Hans/zh-Hant example is decisive. A `Translated<A>` that collapses Simplified and Traditional Chinese is broken for real content. The right key type is `Locale` (language + optional script + optional region), not bare `Language`. This is a bigger refactor than I initially proposed, but it's correct.

3. **Separate locale data package** — `swift-locale-data` at L2, distinct from `swift-locale-standard`. Identity types, parsing, and fallback semantics in one place; generated CLDR tables in another. Different versioning cadence, different size profile, different consumers.

4. **MVP scope for Foundation elimination** — ChatGPT is right that number/currency formatting is much harder than date formatting once you account for grouping rules, symbol placement, cash rounding, numbering systems, etc. The MVP should be:
   - Date formatting: month/day names, date ordering (DMY/MDY/YMD)
   - Basic number formatting: decimal separator, grouping separator (Western 3-digit only)
   - Everything else stays in the Foundation bridge until we're ready to do it properly

5. **Migration phasing** — ChatGPT's reordered phases are better: introduce new types → add adapters → add formatting → migrate products → *then* flip translation keying. Don't break `Translated<A>` until the replacement path is fully functional.

### Concerns

1. **Locale as translation key — fallback chain design**. If `Translated<A>` keys on `Locale`, the fallback chain needs to handle the full identity space gracefully. Current L2 fallback chains are language-level only. With locale keying, we need:
   - `Locale(language: .zh, script: .Hans, region: .CN)` → `Locale(language: .zh, script: .Hans)` → `Locale(language: .zh)` → `Locale(language: .en)`
   - This is essentially CLDR locale inheritance. Is this the same fallback chain used for formatting data lookup, or a separate translation fallback? ChatGPT raised this distinction — I think for this ecosystem they can be the same algorithm operating over the same locale graph, but I want to confirm.

2. **Locale equality and dictionary keying**. If `Translated<A>` uses `[Locale: A]` as its internal dictionary, then `Locale(language: .nl)` and `Locale(language: .nl, region: .NL)` are *different keys*. A translation registered for `.nl` won't match a lookup for `.nl_NL` without fallback resolution. This is correct behavior (fallback handles it), but it means every subscript access goes through the fallback path for regional locales. Performance implication: the fallback cache becomes more important, and the fallback chain needs to be efficient.

3. **TranslationKey vs Locale** — ChatGPT proposed considering a dedicated `TranslationKey` type narrower than full `Locale`. The question is whether `Locale`'s region field is ever meaningful for translation keying. Examples:
   - `en-US` vs `en-GB`: "color" vs "colour" — yes, translation can vary by region
   - `pt-BR` vs `pt-PT`: significant vocabulary differences — yes
   - `nl` vs `nl-BE`: minor differences but real — yes

   So region IS sometimes relevant for translations. `Locale` handles this. A narrower `TranslationKey` would just recreate `Locale` with fewer fields. I think `Locale` is the right type — it's already the right shape.

4. **Answering ChatGPT's Q1 (Translated<A> scope)**: Yes, we should support script-distinct translations (zh-Hans vs zh-Hant). The Locale-keyed design handles this. This is a product-scope claim backed by real-world needs — Chinese is a major language, and our legal encoding work could eventually expand to jurisdictions using Traditional Chinese.

### Proposals

1. **Locale-keyed Translated<A> with hierarchical fallback**:
   ```swift
   public struct Translated<A> {
       package var `default`: A
       internal var dictionary: [Locale: A]

       public subscript(locale: Locale) -> A {
           // Direct match
           if let value = dictionary[locale] { return value }
           // Fallback: strip region, then script, then linguistic chain
           for fallback in locale.fallbackChain {
               if let value = dictionary[fallback] { return value }
           }
           return `default`
       }
   }
   ```

2. **Unified fallback chain on Locale** (moved from Language to Locale in L2):
   ```swift
   extension Locale {
       public var fallbackChain: [Locale] {
           var chain: [Locale] = []
           // Step 1: strip region if present
           if region != nil {
               chain.append(Locale(language: language, script: script))
           }
           // Step 2: strip script if present
           if script != nil {
               chain.append(Locale(language: language))
           }
           // Step 3: linguistic fallback (from Language.fallbackChain)
           for fallbackLang in language.fallbackChain {
               chain.append(Locale(language: fallbackLang))
           }
           return chain
       }
   }
   ```
   This composes structural narrowing (CLDR-style) with linguistic fallback (existing L2 tables). One algorithm, one place.

3. **Revised formatter pattern** (per ChatGPT's proposal, which I accept):
   ```swift
   // Format.Date is a pure value — always requires explicit locale
   extension Format {
       public struct Date: FormatStyle {
           public let locale: Locale
           public let style: Style

           public init(locale: Locale, style: Style = .long) {
               self.locale = locale
               self.style = style
           }

           public func format(_ time: Time) -> String { ... }
       }
   }

   // Convenience reads DI at the call boundary
   extension Time {
       public func formatted(_ style: Format.Date.Style = .long) -> String {
           @Dependency(\.locale) var locale
           return Format.Date(locale: locale, style: style).format(self)
       }

       public func formatted(_ style: Format.Date.Style, locale: Locale) -> String {
           Format.Date(locale: locale, style: style).format(self)
       }
   }
   ```

4. **Revised MVP scope**:
   - Phase 1: Locale data — month names (full + abbreviated), day names (full + abbreviated), date order patterns. Start with top-40 locales by CLDR coverage, not 183.
   - Phase 2: Basic number formatting — decimal separator, grouping separator (Western 3-digit). Top-40.
   - Phase 3: Currency symbol + placement. Constrained to ISO 4217 currencies with simple symbol positioning.
   - Deferred: spell-out, non-Western grouping, plural-sensitive units, numbering systems, compact notation.

5. **Answering ChatGPT's Q2 (formatter semantic contract)**: Per the agreed pattern, `Format.Date` is locale-independent until it receives a locale at construction. It is a pure value — `Format.Date(locale: .nl, style: .long)` is fully deterministic. The ambient-reading path lives only in `Time.formatted(_:)`.

6. **Answering ChatGPT's Q3 (fallback chain purpose)**: With Locale-level keying, the fallback chain serves both translation lookup and formatting data lookup. They use the same structural narrowing algorithm (strip region → strip script → linguistic). If a case ever arises where translation and formatting need different policies, the explicit `locale:` override on formatting APIs provides the escape hatch — you can set `@Dependency(\.locale)` for translations while passing a different locale explicitly for formatting.

7. **Answering ChatGPT's Q4 (number/currency MVP)**: The MVP boundary is: replace current Dutch-style hardcoded formatters + basic Foundation DateFormatter usage. General-purpose NumberFormatter replacement is NOT in scope. That would require a dedicated research effort on CLDR number formatting rules.

8. **Answering ChatGPT's Q5 (L2 dataset policy)**: I'm now comfortable saying L2 should be split: `swift-locale-standard` stays as a lightweight spec wrapper (identity types, parsing, fallback semantics). `swift-locale-data` is a dedicated L2 sibling for generated normative datasets. This keeps L2 conceptually "spec core" while allowing large CLDR-derived tables without bloating the identity package.

### Questions

1. **On Locale-keyed Translated<A>**: Does ChatGPT agree that `Locale` is the right key type, or does the proposal for a narrower `TranslationKey` still stand? My argument: region matters for translations (en-US vs en-GB, pt-BR vs pt-PT), script matters (zh-Hans vs zh-Hant), so we need language + region? + script? — which is exactly `Locale`.

2. **On fallback chain unification**: Is ChatGPT comfortable with one fallback algorithm (structural narrowing + linguistic chain) serving both translation and formatting? Or should the architecture explicitly support two separate policies even if they start identical?

3. **On data modularity within `swift-locale-data`**: Should the CLDR data package expose sub-targets per data domain (calendar names, number conventions, currency data) so consumers can depend on only what they need? Or one target with everything?

4. **On the compatibility layer**: For the `BCP47.LanguageTag` → `Locale` migration in `Translated<A>`, what does a good adapter look like? I'm thinking: `extension BCP47.LanguageTag { public var locale: Locale { get } }` that extracts language/script/region from the tag, plus a deprecated `Translated<A>.subscript(language: BCP47.LanguageTag)` that converts internally.

### Status: NARROWING
---

## Round 3 - ChatGPT

(Pasted from user — see /tmp/localization-architecture-round-3-chatgpt.md)

---
## Round 3 - Claude

### Position

ChatGPT's remaining refinements are all sound. I accept them. But I also need to introduce a significant new constraint from the human architect that changes the data layer picture:

**New constraint: thin ICU Clang module instead of static CLDR tables.**

After Round 2, we investigated how Apple's open-source swift-foundation handles locale data. Finding: they don't embed or generate any CLDR data at all. Their entire approach is a thin `_FoundationICU` Clang module that calls ICU C functions (`udat_getSymbols`, `ures_open`, etc.) at runtime. The OS-bundled ICU library provides all CLDR data.

The human architect's decision: **replicate this pattern**. Create a Foundation-free ICU wrapper — a `_LocaleICU` Clang module — that calls ICU directly. No static table generation, no CLDR JSON extraction, no code generation pipeline. ICU is available on macOS, Linux, Windows, and Android.

**This is Option A now, with Option C (add static L2 tables) as a future upgrade path.** The L3 API surface stays identical either way — the data source is an implementation detail behind the formatter.

This changes the discussion in several important ways:
1. **`swift-locale-data` as a static-table package becomes unnecessary for now.** Instead, we need a thin ICU bridge package.
2. **The top-40 vs 183 language scope question dissolves.** ICU has complete CLDR coverage for all locales.
3. **Data modularity within the package becomes less critical initially.** ICU provides calendar, number, and currency data through one C API.
4. **The reuse constraint**: locale data access must compose with existing `swift-iso-639`, `swift-iso-3166`, `swift-iso-15924` packages, not create parallel types.

**Second new constraint**: locale data must reuse the existing swift-standards ISO packages. Month names are data about `ISO_639.LanguageCode` and `ISO_3166.Alpha2`, not about some new `Locale.Data.Calendar` type.

Updated position summary:

1. **Locale-keyed Translated<A>** with documented semantic boundary (per ChatGPT's proposal)
2. **DI at call boundary** — `Format.Date` is pure, `time.formatted(.long)` reads `@Dependency(\.locale)`
3. **Thin ICU Clang module** at L3 for locale data access — Foundation-free, full CLDR coverage
4. **Future static tables at L2** as an upgrade for embedded/bare-metal (Option C)
5. **Fallback engine separated from fallback policy** — shared mechanism, distinct policy types
6. **Formatter namespace under `Format`** — `Format.Date`, `Format.Number`, `Format.Currency`

### Agreements

**Accepting all of ChatGPT's Round 3 refinements:**

1. **Document the semantic boundary on Locale as translation key.** Agreed. The normative statement:

   > `Translated<A>` keys are `Locale` values restricted to authored-content distinctions: language, optional script, optional region. Locale preference dimensions beyond these (numbering system, calendar, hour cycle, collation) are not part of translation identity.

   This keeps the door open for `Locale` to grow richer for formatting purposes without polluting translation keying.

2. **Separate fallback engine from fallback policy.** Agreed. The architecture has:
   - `Locale.FallbackChain` — the engine (structural narrowing + linguistic graph traversal)
   - `Translation.FallbackPolicy` — uses the engine, may customize ordering or skip levels
   - `Formatting.FallbackPolicy` — uses the engine, follows strict CLDR inheritance

   Both start with the same default implementation. But they're separate protocol conformances over a shared mechanism, so they can diverge later without redesign.

3. **Explicit fallback precedence order.** Agreed. The normative order:
   - Exact match
   - Drop region (e.g., `nl-BE` → `nl`)
   - Drop script (e.g., `zh-Hans` → `zh`)
   - Linguistic fallback chain (e.g., `nl` → `en`)
   - Default value

   **Justification**: Region is the finest distinction (en-US vs en-GB are very close). Script is a coarser distinction (zh-Hans vs zh-Hant may be unintelligible to each other). So we strip the finer distinction first. This matches CLDR locale inheritance order and is the least-surprising default for most content.

   This is documented as the **default policy**, not as an invariant. Custom policies can reorder.

4. **Data modularity as first-class structure.** Agreed, though the ICU wrapper changes what this means. Instead of sub-targets per data domain (calendar, number, currency), the ICU module provides a unified C API. The modularity lives in the Swift API surface:
   - `Locale.calendar.monthNames` (wraps `udat_getSymbols`)
   - `Locale.number.decimalSeparator` (wraps `unum_getSymbol`)
   - `Locale.currency.symbol` (wraps `unum_getSymbol` with currency style)

   When/if static tables arrive (Option C upgrade), they slot into this same API surface — each domain becomes its own L2 target.

5. **MVP constraints stated sharply.** Agreed. See Proposals below.

### Concerns

1. **ICU availability on all target platforms.** ICU is available on macOS (system), Linux (system package `libicu-dev`), Windows (bundled since Win10), Android (bundled). But on embedded Swift targets or WebAssembly, ICU is typically not available. The Option A → C upgrade path handles this: static L2 tables for platforms without ICU. But until Option C, locale-aware formatting is ICU-gated. Is this acceptable? The human architect confirmed yes for now.

2. **ICU Clang module packaging.** Apple puts their ICU bindings in `_FoundationICU` (prefixed with underscore, internal). We need to decide where our `_LocaleICU` lives:
   - Inside `swift-formatting` at L3? (simplest, but ties ICU to one package)
   - As a standalone L3 package `swift-icu` that other packages can depend on? (more reusable)
   - As an L2 package? (ICU is a de facto standard, but the C dependency feels more L3)

   My instinct: standalone L3 package. ICU is composed infrastructure, not a specification. But it should be thin — just the Clang module and minimal Swift wrappers.

3. **One remaining question on translation key identity.** ChatGPT proposed documenting the constraint but also mentioned preserving the "conceptual option of a narrower translation identity." I want to close this cleanly: are we agreed that `Locale` IS the key type (not a future `TranslationKey`), with the documented constraint being the safety valve? Or does ChatGPT still want the architecture to accommodate a type change later?

### Proposals

1. **ICU integration architecture:**
   ```
   L3: swift-icu (thin package)
   ├── _LocaleICU (Clang module — ICU C headers + modulemap)
   └── ICU (Swift wrappers — symbol retrieval, caching, error handling)

   L3: swift-formatting (depends on swift-icu + swift-locale-standard)
   ├── Format.Date — reads ICU calendar symbols via swift-icu
   ├── Format.Number — reads ICU number symbols via swift-icu
   └── Format.Currency — reads ICU currency symbols via swift-icu

   L3: swift-locale (expanded, depends on swift-locale-standard)
   ├── @Dependency(\.locale) — DI registration
   └── Locale extensions — .calendar.monthNames etc. backed by ICU
   ```

   When Option C arrives later:
   ```
   L2: swift-locale-data (static tables, ICU-free)
   ├── Calendar data (month/day names for top-N locales)
   ├── Number data (separators for top-N locales)
   └── Currency data (symbols for top-N locales)

   L3: swift-formatting checks L2 tables first, falls back to ICU
   ```

2. **Sharp MVP constraints:**

   **In scope (Phase 1):**
   - Date formatting: long ("21 november 2018"), medium ("21 nov 2018"), short ("21-11-2018") — via ICU calendar symbols + locale date patterns
   - Time formatting: hour:minute:second with locale-appropriate separators
   - Basic number formatting: decimal separator, grouping separator per locale — via ICU number symbols
   - `@Dependency(\.locale)` registration and `Time.formatted(_:)` convenience

   **In scope (Phase 2):**
   - Currency formatting: symbol, placement, decimal digits — via ICU currency symbols
   - `Format.Number` with sign display, notation, precision (extending existing L1 `Format.Numeric` strategies with locale awareness)

   **Explicitly out of scope until dedicated research:**
   - Number spell-out (requires per-language grammar rules)
   - Non-Western digit systems (Devanagari, Arabic-Indic, Thai, etc.)
   - Non-Gregorian calendars (Islamic, Hebrew, Japanese Imperial, etc.)
   - Plural-sensitive unit formatting ("1 day" vs "2 days" across languages)
   - Relative date formatting ("yesterday", "3 hours ago")
   - Collation / sort ordering
   - Text segmentation / line breaking
   - Bidirectional text handling

3. **Revised migration plan (incorporating ICU strategy):**

   - **Phase 0**: Clean L1 locale placeholder. Add `.english`, `.dutch` aliases to L2 Language.
   - **Phase 1**: Create `swift-icu` (thin ICU Clang module + Swift wrappers). Create `swift-formatting` with `Format.Date`, `Format.Number` backed by ICU. Register `@Dependency(\.locale)`.
   - **Phase 2**: Add `Format.Currency`. Extend number formatting with locale-aware sign/notation/precision.
   - **Phase 3**: Migrate `Translated<A>` from `BCP47.LanguageTag` to `Locale` keying. Unify fallback chains. Add compatibility adapters.
   - **Phase 4**: Deprecate `Translating Platform` Foundation formatting. Product layer cleanup.
   - **Future (Option C)**: Add `swift-locale-data` at L2 with static tables for embedded targets.

4. **Fallback architecture:**
   ```swift
   // Engine (shared mechanism)
   public struct Locale.FallbackChain: Sequence {
       let locale: Locale
       // Yields: exact → drop region → drop script → linguistic chain → nil
   }

   // Policies (separate, can diverge)
   public protocol FallbackPolicy {
       func resolve<A>(_ locale: Locale, in dictionary: [Locale: A], default: A) -> A
   }

   public struct Translation.FallbackPolicy: FallbackPolicy { ... }
   public struct Formatting.FallbackPolicy: FallbackPolicy { ... }
   ```

### Questions

1. **For ChatGPT**: Does the ICU strategy change your assessment of any remaining concerns? Specifically, does it resolve the data modularity question (since ICU provides everything through one C API), or do you still want the Swift API surface to be modular even if the underlying data source is monolithic?

2. **For ChatGPT**: On the `swift-icu` package placement — L2 or L3? ICU is arguably a "de facto standard" (it implements Unicode specifications), which would place it at L2. But it's also a C library dependency with platform-specific linking, which feels more L3. What's your read?

3. **For ChatGPT**: Can we close the `Locale` vs `TranslationKey` question? My proposal: `Locale` is the key type, the documented semantic boundary is the safety valve, and if `Locale` ever grows dimensions that pollute translation identity, we factor out a `Translation.Locale` at that point. No preemptive abstraction.

4. **For ChatGPT**: With the ICU strategy, the "top-40 locales" constraint disappears — ICU has them all. Does this change your view on any aspect of the MVP scope?

### Status: NEAR_CONSENSUS

---

## Round 4 - ChatGPT

(Pasted from user — CONSENSUS_WITH_GUARDRAILS)

---

## Round 4 - Claude

### Position

We're converged. ChatGPT's remaining guardrails are all correct and I accept them without modification:

1. **Provider-shaped internal seam** — `Format.Date` doesn't talk to ICU directly. It goes through `CalendarSymbolProvider`, `NumberSymbolProvider`, `CurrencySymbolProvider` protocols. ICU backs them today; static tables slot in later.
2. **Platform scope stated explicitly** — Phase 1 requires ICU-backed platform. No silent universality claims.
3. **Locale semantic subset for translation** — "Translation lookup observes only the authored-content identity subset of Locale: language, optional script, optional region."
4. **Fallback order is default policy, not ontology** — documented as the product default with explicit room for custom policies.
5. **Domain-oriented public API** — month names, separators, symbols in our own semantics. ICU is an implementation detail, never a public concept.

No remaining concerns. No remaining questions.

### Agreements

All of ChatGPT's Round 4 positions accepted:

1. ICU at L3 (standalone `swift-icu`) — not L2. Infrastructure, not specification.
2. Provider seam even with single backend — prevents ICU diffusion, enables Option C.
3. Locale as Translated<A> key — closed, with documented escape clause.
4. Broad locale coverage, narrow feature scope — ICU gives coverage for free; discipline stays on feature breadth.
5. Fallback engine/policy separation — shared machinery, distinct policy types, same default initially.

### Concerns

None remaining.

### Proposals

None — proceeding to converged plan.

### Questions

None remaining.

### Status: CONVERGED

---

## Converged Plan

### Summary

The Swift Institute localization architecture unifies locale, formatting, translation, and time across the five-layer stack. A single `@Dependency(\.locale)` drives both `Translated<A>` lookups and algorithmic formatting. Formatters are pure values; the DI read happens at the call boundary. Locale data comes from a thin Foundation-free ICU bridge at L3, with a future upgrade path to static L2 tables for ICU-free platforms. `Translated<A>` keys on `Locale` (language + optional script + optional region), with a documented semantic boundary excluding formatting-preference dimensions.

### Key Decisions

1. **Canonical identity model**: L2 `Language` (ISO 639) for pure language. L2 `Locale` (language + region? + script?) for locale identity. No separate `TranslationKey` type.

2. **Single dependency**: `@Dependency(\.locale)` replaces both `@Dependency(\.language)` and any separate locale dependency. `Translated<A>` reads `locale.language` (or the full locale for script/region-sensitive content).

3. **Translated<A> keys on Locale**: With documented constraint — translation lookup observes only the authored-content identity subset: language, optional script, optional region. Other locale preference dimensions are excluded.

4. **Formatter purity**: `Format.Date`, `Format.Number`, `Format.Currency` always take explicit `locale:` in their init. They are deterministic pure values. The `time.formatted(.long)` convenience reads `@Dependency(\.locale)` at the extension method boundary, not inside the formatter.

5. **ICU bridge at L3**: Standalone `swift-icu` package with thin `_LocaleICU` Clang module. Foundation-free. Full CLDR coverage via system ICU. Phase 1 requires ICU-backed platform (macOS, Linux, Windows, Android).

6. **Provider-shaped internal seam**: Formatters access locale data through protocol-shaped providers (`CalendarSymbolProvider`, `NumberSymbolProvider`, `CurrencySymbolProvider`). ICU backs them today. Static L2 tables slot in later (Option C).

7. **Namespace**: Locale-aware formatters under `Format` (from `Formatting_Primitives`). `Format.Date`, `Format.Number`, `Format.Currency`. Not under `Time`.

8. **Fallback architecture**: Shared engine (`Locale.FallbackChain`), separate policies (`Translation.FallbackPolicy`, `Formatting.FallbackPolicy`). Default order: exact → drop region → drop script → linguistic chain → default. Documented as default policy, not invariant.

9. **L1 FormatStyle unchanged**: Stays locale-unaware. Locale awareness is composed behavior at L3.

10. **swift-locale-primitives maintained**: Empty `Locale` struct removed (name collision). Package kept as reserved namespace for future shared types.

### Migration Plan

- **Phase 0**: Clean L1 locale placeholder. Add `.english`, `.dutch` human-readable aliases to L2 `Language`.
- **Phase 1**: Create `swift-icu` (L3, thin ICU Clang module + Swift wrappers with provider seam). Create `swift-formatting` (L3) with `Format.Date`, `Format.Number` backed by ICU providers. Register `@Dependency(\.locale)`. Add `Time.formatted(_:)` convenience.
- **Phase 2**: Add `Format.Currency`. Extend number formatting with locale-aware sign/notation/precision.
- **Phase 3**: Migrate `Translated<A>` from `BCP47.LanguageTag` to `Locale` keying. Unify fallback chains into `Locale.FallbackChain` with separate policy types. Add compatibility adapters from `BCP47.LanguageTag`.
- **Phase 4**: Deprecate `Translating Platform` Foundation formatting. Product layer cleanup (replace `Format.Datum`, `Format.Euro`, `Format.Nummer`).
- **Future (Option C)**: Add `swift-locale-data` at L2 with static tables for embedded/ICU-free targets. Formatters check L2 providers first, fall back to ICU.

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

1. Phase 1 locale-aware formatting requires an ICU-backed platform. ICU-free targets remain unsupported until a static-data backend is introduced.
2. Translation lookup observes only the authored-content identity subset of Locale: language, optional script, optional region.
3. The fallback order (exact → drop region → drop script → linguistic → default) is the product default policy, not a universal invariant.
4. The public API is domain-oriented (month names, separators, symbols), not ICU-oriented. ICU is an implementation detail.
5. Locale data access composes with existing `swift-iso-639`, `swift-iso-3166`, `swift-iso-15924` packages.

### Agreed By
- Claude: Round 4
- ChatGPT: Round 4 (CONSENSUS_WITH_GUARDRAILS)

## Round 5 - ChatGPT

Status: CONVERGED_AND_READY

No further architectural objections. Proceed with converged plan.

---

## Outcome: CONVERGED

Agreed by:
- Claude: Round 4
- ChatGPT: Round 5 (CONVERGED_AND_READY)
