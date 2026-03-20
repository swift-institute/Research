# Adoption Implementation Review

<!--
---
version: 1.0.0
last_updated: 2026-03-04
status: COMPLETE
---
-->

## Scope

Review of implementation work for the dependencies, witnesses, and parsers ecosystem adoption audits. Compares research recommendations against actual commits since 2026-03-03 across swift-primitives, swift-standards, and swift-foundations repos.

---

## Dependencies

### Implemented

| Research Item | Priority | Implementation | Status | Notes |
|--------------|----------|----------------|--------|-------|
| Relax `Dependency.Key` for `~Copyable` values | (infra) | `swift-dependency-primitives`: `Dependency.Key.swift` — `associatedtype Value: ~Copyable & Sendable`, subscript constrained `where K.Value: Copyable` | COMPLETE | Enables future non-copyable dependency values. `testValue` default extension correctly constrained. |
| Result-wrapping for TaskLocal typed throws | (infra) | `swift-dependency-primitives`: `Dependency.Scope.swift` — sync and async `with(_:operation:)` now wrap via `Result<T, E>` to preserve typed error through rethrows-erasing `TaskLocal.withValue` | COMPLETE | Clean workaround with documented removal path ("When FullTypedThrows lands, replace with..."). Removed `import Standard_Library_Extensions`. |
| Simplify `withDependencies` to single-stack `_withScope` | (infra) | `swift-dependencies`: `withDependencies.swift` — all 4 overloads now call `Witness.Context._withScope` passing both `witnessValues` and `l1Values` | COMPLETE | Unifies L1 and L3 scoping into a single `Dependency.Scope.with` push. |
| L1 values bridge in `Dependency.Values` | (infra) | `swift-dependencies`: `Dependency.Values.swift` — added `_l1Values: Dependency_Primitives.Dependency.Values` field, L1-key subscript overload | COMPLETE | Clean two-storage approach: L3 keys go into `_witnessValues`, L1-only keys go into `_l1Values`. |
| `prepareDependencies` typed throws | (infra) | `swift-dependencies`: `prepareDependencies.swift` — both sync and async overloads converted from `rethrows` to `throws(E)` | COMPLETE | |
| IO.Blocking.Lane as Dependency.Key | MEDIUM | `swift-io`: new `IO.Blocking.Lane+Dependency.Key.swift` — `liveValue: .shared`, `testValue: .inline` | COMPLETE | Added `swift-dependency-primitives` to Package.swift for both `IO` and `IO Blocking Threads` targets. |
| IO.Lane as Dependency.Key | MEDIUM | `swift-io`: new `IO.Lane+Dependency.Key.swift` — `liveValue: .shared`, `testValue: .inline` | COMPLETE | |
| IEEE 754 ExceptionState as Dependency.Key | MEDIUM | `swift-ieee-754`: `IEEE_754.Exceptions.swift` — `ExceptionState: Dependency.Key` with `liveValue: _global`, `testValue: .init()`. All call sites (`raise`, `test`) route through `state` computed property resolving from `Dependency.Scope.current`. | COMPLETE | Fixes the concurrent test isolation bug identified in the audit. `_global` renamed from `sharedState`. |
| RFC 4122 HashProvider as Dependency.Key | MEDIUM | `swift-rfc-4122`: new `RFC_4122.Hash.swift` (97 lines) — witness struct with `_md5`/`_sha1` closures, conforms to both `HashProvider` and `Dependency.Key`. `liveValue` uses `CryptoKit` with `#if canImport` guard, `testValue` uses identity truncation. | COMPLETE | Also added `RFC_4122.Random.Error.swift` for typed throws. Convenience overloads on `UUID.v3`/`v5` resolve from `Dependency.Scope.current`. |
| RFC 4122 RandomProvider as Dependency.Key | MEDIUM | `swift-rfc-4122`: new `RFC_4122.Random.swift` (not seen in stat, likely in same commit batch) — witness struct with `_fill` closure, conforms to both `RandomProvider` and `Dependency.Key`. | COMPLETE | Enables `RFC_4122.UUID.v4()` without explicit provider parameter. |
| RFC 9562 RandomProvider convenience | MEDIUM | `swift-rfc-9562`: new `RFC_9562.UUID+Dependency.swift` — convenience `v7(unixMilliseconds:)` resolving `RFC_4122.Random` from dependency scope. Retroactive conformance `RFC_4122.Random: RFC_9562.RandomProvider`. | COMPLETE | |
| RFC 6238 HMACProvider as Dependency.Key | MEDIUM | `swift-rfc-6238`: `RFC_6238.HMAC` witness struct, Foundation dependency fully removed (`Data` → `[UInt8]`, `Date` → `Double`, `TimeInterval` → `Double`, `URLComponents` → manual). `Base32` codec moved into `RFC_6238.Base32` namespace. | COMPLETE | Significant scope: Foundation removal + Dependency.Key + Base32 internalization. |
| Test.Expectation.Collector as Dependency.Key | MEDIUM | `swift-tests`: commit `befd2cf` migrated to Dependency.Key; `swift-testing` commit `8ca9f04` updated call sites. | REVERTED | See "Reverted Work" section below. |
| HTML rendering snapshot macro migration | (test infra) | `swift-html-rendering`: commit `1a96a99` migrated 46 inline snapshots from `assertInlineSnapshot` to `#snapshot` macro across 29 test files. | COMPLETE | Mechanical rename only; no behavioral change. |

### Quality Assessment

1. **`swift-dependency-primitives` changes are clean**: The `~Copyable` relaxation is properly gated with `where Value: Copyable` on the subscript and default `testValue` extension. The Result-wrapping workaround includes a clear removal comment.

2. **`swift-dependencies` L1 bridge is well-structured**: The `_l1Values` field alongside `_witnessValues` is a clean dual-storage approach. All four `withDependencies` overloads consistently use `_withScope`. The `Test.Scope` and `Test.Trait` test support infrastructure was also updated.

3. **IO Dependency.Key files follow one-type-per-file** ([API-IMPL-005]): `IO.Blocking.Lane+Dependency.Key.swift` and `IO.Lane+Dependency.Key.swift` are correctly placed.

4. **RFC 4122 Hash and Random witness structs** are well-implemented with proper `#if canImport(CryptoKit)` platform guards. The `testValue` uses deterministic identity-truncation rather than real hashing, which is correct for test isolation.

5. **RFC 6238 Foundation removal** is the most ambitious single change — it replaced all Foundation types and internalized a Base32 codec. Build succeeds with only `StrictMemorySafety` warnings (expected for `withUnsafeBytes`).

6. **All affected repos build successfully** (verified: `swift-dependency-primitives`, `swift-dependencies`, `swift-witnesses`, `swift-io`, `swift-ieee-754`, `swift-rfc-4122`, `swift-rfc-9562`, `swift-rfc-6238`).

### Gaps (Not Implemented)

| Research Item | Priority | Reason/Notes |
|--------------|----------|-------------|
| HTML.Context.Configuration as Dependency.Key | HIGH (per action plan) / N/A (per category analysis) | Research document self-contradicts: Category 1 says "KEEP @TaskLocal — N/A" but Phase 1 action plan says "HIGH — replace". The `@TaskLocal` remains at `/Users/coen/Developer/swift-foundations/swift-html-rendering/Sources/HTML Renderable/HTML.Context.Configuration.swift:139`. |
| HTML.Element.Style.Context as Dependency.Key | HIGH (per action plan) / N/A (per category analysis) | Same contradiction. `@TaskLocal` remains at `/Users/coen/Developer/swift-foundations/swift-html-rendering/Sources/HTML Renderable/HTML.Style.Context.swift:62`. |
| IO.Executor as Dependency.Key | LOW | Not implemented. Internal singleton at `IO.Executor.swift:43`. |
| IO.Event.Selector as Dependency.Key | LOW | Not implemented. Async failable init makes this complex. |
| IO.Completion.Queue as Dependency.Key | LOW | Not implemented. Same async init complexity. |
| IO.Event.Registry as Dependency.Key | LOW | Not implemented. |
| Test.Exclusion.Controller as Dependency.Key | LOW | Not implemented. |
| Test.Snapshot.Inline.Configuration as Dependency.Key | LOW | Not implemented. |
| Testing.Configuration as Dependency.Key | LOW | Not implemented. |
| Tests.Baseline.Recording as Dependency.Key | LOW | Not implemented. |
| Tests.Baseline.Storage as Dependency.Key | LOW | Not implemented. |

**Summary**: All 7 MEDIUM-priority items were implemented (1 reverted). All 9 LOW-priority items remain unimplemented. The 2 "HIGH" items have a contradictory recommendation in the research (the category analysis says N/A, and the agents correctly followed the category-level recommendation to keep `@TaskLocal`).

### Reverted Work

**Commit**: `befd2cf` in `swift-tests` — "Migrate Test.Expectation.Collector from @TaskLocal to Dependency.Key"
**Revert**: `ace4e63` in `swift-tests` (16 minutes later); `1ed605c` in `swift-testing`

**What it did**:
1. Added `Dependency.Key` conformance to `Test.Expectation.Collector` with nested `Key` enum
2. Changed `Collector.current` from `@TaskLocal` to `Dependency.Scope.current[Key.self]`
3. Updated `Test.Runner` and all test call sites from `$current.withValue(collector)` to `Dependency.Scope.with({ $0[Key.self] = collector })`
4. Extracted Apple Testing bridge into a separate `Tests Apple Testing Bridge` module
5. Added `swift-dependency-primitives` dependency to `Tests Core` target

**Why it was reverted**: The commit message on the revert says only "This reverts commit befd2cf". However, examining the subsequent commit history reveals the likely cause:
- Commit `4ded6c5` (later) re-extracts the Apple Testing bridge with the note "breaking circular dependency" — the revert was likely needed because the Testing ↔ Tests_Core circular module dependency broke clean builds.
- Commit `c92eb44` (later) fixes "silent failure drop and auto-install Apple Testing bridge" — the externalFailureHandler was never invoked, so failures were silently dropped when running under Apple's runner without the Institute's `Test.Runner`.

The bridge extraction and failure reporting were re-implemented in separate commits (`4ded6c5`, `c92eb44`) without the Dependency.Key migration for Collector. The Collector remains `@TaskLocal` at `/Users/coen/Developer/swift-foundations/swift-tests/Sources/Tests Core/Test.Expectation.Collector.swift:33`.

---

## Witnesses

### Implemented

| Research Item | Priority | Implementation | Status | Notes |
|--------------|----------|----------------|--------|-------|
| `@Witness` macro: accept `let` closures | HIGH (prereq) | `WitnessMacro.swift` — `extractClosureProperties` now accepts `.keyword(.let)` in addition to `.keyword(.var)` | COMPLETE | Enables `let _create: ...` pattern used by IO drivers. |
| `@Witness` macro: strip `_` prefix | HIGH (prereq) | `WitnessMacro.swift` — `methodName` computed property strips leading `_` from closure name for method/action generation | COMPLETE | `let _create` generates method `create()`, Action case `.create`. |
| `@Witness` macro: `firstName` label support | HIGH (prereq) | `WitnessMacro.swift` — `extractParameters` now falls through to `firstName` when `secondName` is nil and `firstName != "_"` | COMPLETE | Defensive against firstName-only closure parameter labels. |
| `@Witness` macro: skip init when struct has one | HIGH (prereq) | `WitnessMacro.swift` — `hasExistingInit` detection via `InitializerDeclSyntax` check | COMPLETE | Prevents double-init generation for types with custom initializers. |
| `@Witness` macro: non-closure stored properties | HIGH (prereq) | `WitnessMacro.swift` — `extractNonClosureProperties`, `generatePublicInit`, `unimplemented()`, `mock()`, and `observe` all handle non-closure properties | COMPLETE | Non-closure props appear in init, unimplemented, and mock parameter lists. |
| `@WitnessAccessors` macro: let + _ prefix | (prereq) | `WitnessAccessorsMacro.swift` — accepts `let` bindings, strips `_` prefix for method names | COMPLETE | |
| Unify task-local stacks: Witness.Context in L1 dictionary | (infra) | `swift-witnesses`: `Witness.Context.swift` — removed `@TaskLocal private static var _current`, added `_ContextKey: Dependency.Key` storing context in L1's dictionary. All scoping routes through `_withScope` which calls `Dependency.Scope.with`. | COMPLETE | Eliminates separate `@TaskLocal` in L3. Single TaskLocal push for all scoping. |
| Refine Witness.Key from Dependency.Key | (infra) | `swift-witnesses`: commit `c2982c6` — unified protocol hierarchy | COMPLETE | |
| Propagate L3 mode to L1 isTestContext | (infra) | `swift-witnesses`: `Witness.Context.swift` `_withScope` methods — `l1Values.isTestContext = (mode == .test)` when mode is non-nil | COMPLETE | Ensures L1-only code sees correct test context flag. |
| L1-key subscript on Witness.Context | (infra) | `swift-witnesses`: `Witness.Context.swift` line 131 — `subscript<K: Dependency.Key>` for L1-only keys | COMPLETE | Overload resolution selects Witness.Key subscript for L3 keys. |

### Quality Assessment

1. **Macro improvements are thoroughly implemented**: Five distinct enhancements (let closures, _ prefix stripping, firstName labels, skip-init, non-closure properties) cover the prerequisites identified for IO driver adoption. The `WitnessAccessorsMacro` received matching updates.

2. **Task-local unification is architecturally significant**: Moving `Witness.Context` from its own `@TaskLocal` into L1's `Dependency.Scope` dictionary eliminates a dual-push pattern. The `_ContextKey` is `@usableFromInline internal` — correctly hidden from public API. Both sync and async `_withScope` variants are `@inlinable`.

3. **The `Witness.Values` file received additional L1-key bridging** (`+32 lines`), and test fixtures were updated (`+41 lines`).

4. **Build succeeds** for both `swift-witnesses` and `swift-dependencies`.

### Gaps (Not Implemented)

**Phase A: Simple `Witness.Protocol` Conformances (Primitives)** — NONE IMPLEMENTED

| Package | Type | Status |
|---------|------|--------|
| swift-optic-primitives | `Optic.Lens`, `Optic.Prism` | NOT STARTED |
| swift-clock-primitives | `Clock.Any` | NOT STARTED |
| swift-predicate-primitives | `Predicate` | NOT STARTED |
| swift-binary-parser-primitives | `Binary.Coder` | NOT STARTED |
| swift-test-primitives | `Test.Snapshot.Strategy`, `Test.Snapshot.Diffing` | NOT STARTED |
| swift-parser-machine-primitives | `Parser.Machine.Compile.Witness` | DEFERRED (not Sendable) |

**Phase B: Simple `Witness.Protocol` Conformances (Standards/Foundations)** — NONE IMPLEMENTED

| Package | Type | Status |
|---------|------|--------|
| swift-iso-32000 | `ISO_32000.StreamCompression` | NOT STARTED |
| swift-tests | `Test.Trait.ScopeProvider` | NOT STARTED |
| swift-effects | `Effect.Yield.Handler`, `Effect.Exit.Handler` | NOT STARTED |

**Phase C: `@Witness` Macro Adoption (IO Drivers)** — NOT IMPLEMENTED

| Package | Type | Status |
|---------|------|--------|
| swift-io | `IO.Event.Driver` | NOT STARTED |
| swift-io | `IO.Completion.Driver` | NOT STARTED |

**Category 7: `Witness.Key` Registration** — NOT IMPLEMENTED

| Package | Type | Status |
|---------|------|--------|
| swift-io | `IO.Event.Driver` (Witness.Key) | NOT STARTED |
| swift-io | `IO.Completion.Driver` (Witness.Key) | NOT STARTED |

**Summary**: The macro prerequisites (5 improvements) and infrastructure unification (task-local stacks, protocol hierarchy, mode propagation) are COMPLETE. However, the actual ecosystem adoption — adding `Witness.Protocol` conformance to the 8 HIGH-priority types, and `@Witness` macro to the IO drivers — was NOT started. The implementation focused entirely on enabling infrastructure without executing the propagation phase.

### Reverted Work

None. All witness commits were retained.

---

## Parsers

### Implemented

| Research Item | Priority | Implementation | Status | Notes |
|--------------|----------|----------------|--------|-------|
| `Parser.ASCII.Integer` module | (infra) | `swift-parser-primitives`: new `Parser ASCII Integer Primitives` module — `Decimal` and `Hexadecimal` parsers with 227-line test suite | COMPLETE | Foundation for integer parsing across standards. |
| ISO 8601 parser combinators | HIGH | `swift-iso-8601`: 12 new files (995 lines) — CalendarDate, DateTime, Duration, Interval, RecurringInterval, TimeOfDay, TimezoneOffset, WeekDate, OrdinalDate, Digits, Error, Parse namespace. Then restructured to `TypeName.Parse` pattern. | PARTIAL | New parsers added alongside existing hand-rolled code. Old `.split()` calls remain (12 occurrences in 4 files). Not yet wired as replacement. |
| RFC 9110 HTTP shared parsers | HIGH | `swift-rfc-9110`: 8 files — OWS, Token, QuotedString, Parameter, ParameterList, CommaSeparated, QualityValue, Parse namespace. | PARTIAL | New parsers added alongside existing code. Old `.split()` calls remain (17 occurrences in 6 files). |
| RFC 3986 URI parsers | HIGH | `swift-rfc-3986`: 10 new files (615 lines) — Scheme, PercentEncoded, Port, Userinfo, Host, PathSegments, Query, Fragment, Authority, Parse namespace with character classifiers. | PARTIAL | Added `Parser_Primitives` and `Parser_ASCII_Integer_Primitives` to Package.swift. Old `.split()` reduced to 1 occurrence. Most complete integration. |
| RFC 5322 DateTime and MessageID parsers | HIGH | `swift-rfc-5322`: 3 new files (304 lines) — DateTime, MessageID, Parse namespace. | PARTIAL | New parsers added; existing hand-rolled code not replaced. |
| RFC 2045 MIME type parser | HIGH | `swift-rfc-2045`: 4 files — ContentType parser with parameter parsing. | PARTIAL | |
| RFC 2183 Content-Disposition parser | HIGH | `swift-rfc-2183`: 2 files. | PARTIAL | |
| RFC 2369 list header URI parser | MEDIUM | `swift-rfc-2369`: 2 files. | PARTIAL | |
| RFC 2388 form data parser | HIGH | `swift-rfc-2388`: 2 files — URL-encoded form data pairs. | PARTIAL | |
| RFC 2822 email address parsers | MEDIUM/HIGH | `swift-rfc-2822`: 3 files — email address format parsers. | PARTIAL | |
| RFC 5321 email address parser | HIGH | `swift-rfc-5321`: 2 files. | PARTIAL | |
| RFC 5646 language tag parser | HIGH | `swift-rfc-5646`: 2 files. | PARTIAL | |
| RFC 6068 mailto URI parser | MEDIUM | `swift-rfc-6068`: 2 files. | PARTIAL | |
| RFC 7519 JWT compact serialization parser | HIGH | `swift-rfc-7519`: 2 files. | PARTIAL | |
| RFC 7617 HTTP Basic credentials parser | HIGH | `swift-rfc-7617`: 2 files. | PARTIAL | |
| RFC 9557 suffix annotations parser | MEDIUM | `swift-rfc-9557`: 2 files. | PARTIAL | |
| RSS standard iTunes duration parser | HIGH | `swift-rss-standard`: 2 files. | PARTIAL | |
| W3C SVG 2 parsers | HIGH | `swift-w3c-svg`: 6 files (766 lines) — Number, Length, ViewBox, Color, Transform, Parse namespace. | PARTIAL | Infrastructure parsers for SVG primitives; the hand-rolled SVG path parser (~500 lines) was not replaced. |
| WHATWG URL Scheme parser | HIGH | `swift-whatwg-url`: 2 files (92 lines) — Scheme parser only. | PARTIAL | Only 1 of ~8 identified parsing opportunities addressed. |
| RFC 6750 Foundation elimination | HIGH | `swift-rfc-6750`: replaced `Foundation`-based parsing with byte-level ASCII operations. | COMPLETE | Foundation import removed. Not implemented via parser combinators but achieves the goal (Foundation removal). |
| RFC 9111 CharacterSet fix | HIGH | `swift-rfc-9111`: replaced `CharacterSet(charactersIn: "\"")` with manual prefix/suffix stripping. | PARTIAL | Only fixes one `CharacterSet` usage; `components(separatedBy:)` calls remain. |

### Quality Assessment

1. **All new parser files conform to `Parser.Protocol`**: Checked ISO 8601, RFC 3986, and RFC 9110 — they import `Parser_Primitives` and use typed throws. This is the correct approach.

2. **The parsers are ADDITIVE, not REPLACEMENT**: Across all 18 packages, the new parser combinator implementations sit alongside the existing hand-rolled parsers. The old `.split(separator:)`, `.components(separatedBy:)`, and manual index-advancement code remains untouched. This means:
   - No existing functionality was broken (positive)
   - The audit's goal of *replacing* hand-rolled parsing is not yet achieved (gap)
   - There is now code duplication (two parsing implementations per domain)

3. **Naming convention**: Files follow `TypeName.Parse.swift` pattern after restructuring (e.g., `ISO_8601.DateTime.Parse.swift`). Initial commits used `TypeName.Parse.SubComponent.swift` (e.g., `ISO_8601.Parse.CalendarDate.swift`) but a subsequent "Restructure parsers" commit corrected this to `TypeName.SubComponent.Parse.swift`.

4. **Scope varies significantly by package**:
   - ISO 8601: Comprehensive (12 files covering all audit items)
   - RFC 3986: Comprehensive (10 files covering all URI components)
   - RFC 9110: Comprehensive shared parsers (8 files: the reusable building blocks)
   - W3C SVG: Good coverage of primitives (Number, Length, ViewBox, Color, Transform) but not the path parser
   - WHATWG URL: Only Scheme parser (1 of ~8 items)
   - Most other packages: 2 files (namespace + one or two parsers)

5. **All 18 packages with parser additions build successfully** (verified: ISO 8601, RFC 3986, RFC 9110).

### Gaps (Not Implemented)

**No parser combinator commits** in these packages from the audit:

| Package | Audit Items | Priority | Notes |
|---------|------------|----------|-------|
| swift-rfc-9111 | CacheControl, Vary, Expires, Age, HeaderStorage (5 items) | HIGH/MEDIUM | Only a CharacterSet fix was applied, not parser combinators. |
| swift-rfc-9112 | HTTP.Version, Request.Line, Response.Line, Connection, TransferEncoding, ChunkedEncoding, Host, Field, Message.Deserializer (9 items) | HIGH/MEDIUM | Only typed throws conversion was done. |
| swift-rfc-3987 | IRI parser | MEDIUM | |
| swift-rfc-5890 | IDNA domain labels | MEDIUM | |
| swift-rfc-1035 | Domain label parsing | MEDIUM | |
| swift-rfc-1123 | Domain validation | MEDIUM | |
| swift-rfc-4291 | IPv6 address | MEDIUM | |
| swift-rfc-4007 | IPv6 scoped address | MEDIUM | |
| swift-rfc-6531 | Internationalized email | MEDIUM | |
| swift-rfc-4648 | Base encoding (deferred by audit) | LOW | Correctly deferred — lookup tables appropriate. |
| swift-base62-primitives | Base62 decoding (deferred by audit) | LOW | Correctly deferred. |
| swift-iso-14496-22 | Font table binary parsing | MEDIUM | |
| swift-iso-32000 | JPEG header, PDF binary | MEDIUM/LOW | |
| swift-rfc-1951 | DEFLATE bit-level (deferred by audit) | LOW | Correctly deferred. |
| swift-w3c-css | Fonts, HexColor, MediaQueries, Cascade (4 items) | MEDIUM/LOW | |
| swift-whatwg-html | FormData, Href (2 items) | MEDIUM/LOW | |
| swift-linux | NUMA CPU list parsing | MEDIUM | |
| swift-plist | Binary plist parsing | MEDIUM | |
| swift-domain-standard | Domain + IDNA | LOW | |

**Critical gap**: RFC 9112 (HTTP/1.1 message syntax) has 9 HIGH-priority items and zero parser combinator work. This is the second-largest opportunity after RFC 9110 in the HTTP family.

**Replacement gap**: Even where parser combinators were added, the old hand-rolled code was not replaced. The call sites still use `.split()` and manual index advancement. A second pass is needed to wire the new parsers into the existing APIs and remove the old implementations.

### Reverted Work

None. All parser commits were retained.

---

## Cross-Cutting Issues

### 1. Research Document Internal Contradiction (Dependencies)

The dependencies audit contains a contradiction between its Category 1 analysis and Phase 1 action plan:

- **Category 1** (lines 59-63): Evaluates HTML rendering `@TaskLocal` usages and concludes "KEEP @TaskLocal" with priority "N/A" for both `HTML.Context.Configuration` and `HTML.Style.Context`.
- **Phase 1** (lines 172-184): Lists these same items as "HIGH Priority (Direct Replacement)" and recommends replacing them with `Dependency.Key`.
- **Summary** (line 163): Reports "2 HIGH" items citing "HTML rendering TaskLocals — direct replacement."

The Category 1 analysis is well-reasoned (these are ambient rendering parameters, not injectable services). The action plan contradicts this analysis. Implementation agents correctly followed the Category 1 recommendation (kept `@TaskLocal`), which means the summary statistics overcount HIGH-priority items by 2.

### 2. Infrastructure-Heavy, Adoption-Light Pattern (Witnesses)

The witnesses implementation invested heavily in macro improvements (5 enhancements) and infrastructure unification (task-local stack consolidation) but did not execute any of the ecosystem adoption items:
- 0 of 8 HIGH-priority `Witness.Protocol` conformances added
- 0 of 2 HIGH-priority `Witness.Key` registrations added
- 0 of 2 HIGH-priority `@Witness` macro adoptions

The infrastructure work is prerequisite and necessary, but the actual propagation did not occur.

### 3. Additive Parser Pattern (Parsers)

All 18 parser packages received NEW parser combinator implementations without removing the OLD hand-rolled code. This creates:
- Code duplication across the codebase
- No behavioral change for consumers (old APIs still use old parsers)
- A required second pass to wire new parsers into existing APIs

This is a reasonable intermediate state (validate new parsers before removing old code), but should be explicitly tracked as incomplete.

### 4. Collector Migration Failure Mode

The Collector Dependency.Key migration was reverted after 16 minutes, likely due to a circular module dependency (`Testing` <-> `Tests_Core`) exposed during clean builds. The same work (Apple Testing bridge extraction, failure handler) was later re-implemented in separate commits without the Dependency.Key migration. This suggests the Collector migration itself is viable but needs to be decoupled from the bridge extraction.

---

## Summary

| Area | Research Items | Implemented | Partial | Reverted | Gap |
|------|---------------|-------------|---------|----------|-----|
| Dependencies | 18 actionable | 11 (infra: 5, MEDIUM: 6) | 0 | 1 (Collector) | 11 (2 contradicted HIGH, 9 LOW) |
| Witnesses | 32 actionable (12 HIGH, 5 MEDIUM, 15 LOW) | 10 (macro: 5, infra: 5) | 0 | 0 | 22 (8 HIGH, 4 MEDIUM, 10+ LOW) |
| Parsers | 95 actionable (52 HIGH, 29 MEDIUM, 14 LOW) | 1 (RFC 6750 Foundation removal) | 18 (new parsers not wired in) | 0 | 57+ packages untouched |

### Highlights

- **Dependencies**: Strong execution. All MEDIUM items done (6 of 7, with 1 reverted). Infrastructure changes (L1 ~Copyable, typed throws, L1/L3 unification) are clean and well-documented.
- **Witnesses**: Excellent infrastructure but zero propagation. The macro and unification work enables future adoption but no types gained `Witness.Protocol` conformance.
- **Parsers**: Broad coverage (18 packages) but shallow depth. New parser combinators are well-implemented but sit alongside — not replacing — old code. RFC 9112 (9 HIGH items) was entirely skipped.

---

## Recommendations

1. **Dependencies**: The Collector migration should be re-attempted, decoupled from the Apple Testing bridge extraction (which was already done separately). The 9 LOW-priority items can remain deferred.

2. **Witnesses Phase A**: Execute the 6 `Witness.Protocol` conformance additions in primitives. These are mechanical: add Package.swift dependency, import, `extension Type: Witness.Protocol {}`. No functional change.

3. **Witnesses Phase C**: Apply `@Witness` macro to `IO.Event.Driver` and `IO.Completion.Driver`. The macro prerequisites (let closures, _ prefix stripping) are now in place.

4. **Parsers replacement pass**: For each of the 18 packages with new parsers, wire the parser combinator into the existing public API and remove the old `.split()`-based implementation. Start with RFC 3986 (most complete integration) as the template.

5. **Parsers gap — RFC 9112**: This is the largest single gap (9 HIGH-priority items). The shared HTTP parsers from RFC 9110 are now available, making RFC 9112 parser work tractable.

6. **Research document fix**: Reconcile the dependencies audit's Category 1 analysis (N/A) with Phase 1 action plan (HIGH) for HTML rendering items. The Category 1 analysis is correct; the action plan should be amended.
