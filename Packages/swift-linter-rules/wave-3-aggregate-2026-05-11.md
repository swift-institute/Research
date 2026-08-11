# Wave 3 Aggregate — Post-Amendment Validation

<!--
---
version: 1.7.0
last_updated: 2026-05-12
status: IMPLEMENTED
---
-->

## Changelog

- **v1.7.0 (2026-05-12)** — Brand-feature reverted; numerics rule-recognizer landed Option 7 (rule decomposition via bundle composition):
  - **Architectural reversal**. The v1.6.0 brand-feature (Option 1 attempt B — `brands:` kwarg + typed `Lint.Brand` + per-source `Parsed.brandTypes` engine threading) was reverted across 5 linter packages. Architectural review concluded the brand feature itself is bloat: PATTERN-017 / CONV-016 / IMPL-010 / IMPL-011 encode "wrong at consumer call sites"; brand-newtype-owning primitive packages aren't consumer call sites. Loading the rule everywhere and admitting at runtime via per-file brand context is strictly more machinery than not loading the rule in packages where it doesn't apply.
  - **Landed shape**: `Lint.Rule.Bundle.brandOwner` (in `swift-primitives-linter-rules/Sources/Linter Primitives Rules/Lint.Rule.Bundle.brandOwner.swift`) filters `Bundle.primitives` to exclude the four consumer-side rule IDs (`"raw value access"`, `"chained rawvalue access"`, `"int public parameter"`, `"pointer advanced by"`). Brand-newtype-owning numerics packages declare a Shape-γ `Lint.swift` loading `Bundle.brandOwner` instead of `Bundle.primitives`. Cross-package consumers continue to load `Bundle.primitives` and see all four rules fire — strict-superset is preserved structurally rather than via per-package config.
  - **Reverted (12 commits across 5 linter packages)**:
    - `swift-primitives/swift-linter-primitives`: `77e062a` (Parsed.brandTypes field), `f16abd7` (Configuration.brands + effectiveBrands), `e9500cb` (Lint.Brand type).
    - `swift-foundations/swift-linter`: `d0cbd73` (Lint.run brands: kwarg), `0f59532` (engine effectiveBrands sourcing), `611b42f` (typed-Brand engine threading).
    - `swift-foundations/swift-linter-rules`: `4f83196` / `82e0537` (PATTERN-017 brand-admission code; rule fires as pre-recognizer).
    - `swift-primitives/swift-primitives-linter-rules`: `56df8fc` / `65729b1` (CONV-016 chain + bitpattern brand-admission).
    - `swift-foundations/swift-institute-linter-rules`: `3641811` / `8fc3bba` (IMPL-010 brand-admission + test retypes).
  - **Kept** (architecturally useful independent of the brand feature):
    - `595c138` (Shape γ SingleFile Lint.swift dispatch with self-reference path fix) — the dispatch infrastructure that supports the new `Lint.swift` per numerics package.
    - `e6d1fb5` (`Lint.Rule.Bundle` namespace) — the namespace that hosts `Bundle.universal`, `Bundle.institute`, `Bundle.primitives`, and now `Bundle.brandOwner`.
    - `fe2c18e` (typed-path `resolveConsumerPath` via `File.Path.appending`) — ecosystem-reuse fix.
    - `411670a` (dep-form aligned back to `path:`) — neutral.
    - `21c2136` (delete `Lint.Package.Brands.swift`) — JSON cache; gone regardless.
    - `d7e7b7f` (delete `Schemas/swift-linter-v1.json`) — no JSON config surface remains.
    - `3d8cb46` / `57ceef6` / `5445a13` (numerics `.swift-linter.json` deletions) — JSON sidecars removed per `project_linter_config_all_swift.md`.
  - **New shape — added**:
    - `Lint.Rule.Bundle.brandOwner` (in `swift-primitives-linter-rules/Sources/Linter Primitives Rules/Lint.Rule.Bundle.brandOwner.swift`). One file, one extension, one static-let; filters `Bundle.primitives` to exclude the four consumer-side rule IDs. ~10 LOC of substance + docstring.
    - `Lint.swift` in each of the three numerics packages (`swift-ordinal-primitives/Lint.swift`, `swift-cardinal-primitives/Lint.swift`, `swift-affine-primitives/Lint.swift`). Shape γ: declares the rule pack dep + activates `Bundle.brandOwner`. ~15 LOC per file.
  - **Dogfood verified** 2026-05-12 by running `swift-linter` debug build against `swift-cardinal-primitives` (which has multiple `.rawValue` access sites in `Cardinal Primitives Core/Cardinal.swift` and the stdlib-integration files): zero findings for the four excluded rule IDs; many findings for other rules. Bundle.brandOwner correctly excludes the four rules structurally — verified by `.rawValue` sites that would fire under `Bundle.primitives` being silent under `Bundle.brandOwner`.
  - **Test state**: all 5 linter packages green. swift-linter-primitives 36 tests, swift-linter-rules 587 tests, swift-primitives-linter-rules 47 tests, swift-institute-linter-rules 190 tests, swift-linter 36 tests. All pass after revert. The Package Scope test suites previously added in v1.6.0 (5 PATTERN-017, 4 Chain, 4 BitPattern, 4 IMPL-010 = 17 tests) and the Configuration.brands tests (3) were removed alongside the engine machinery.
  - **Rationale**: all-Swift convention (no JSON sidecars per `project_linter_config_all_swift.md`) plus bloat-avoidance (rule decomposition achieves the same observable behavior as the brand feature with zero engine machinery, zero new types, zero per-file metadata threading). The precision tradeoff (Option 1 could admit `Cardinal.underlying` while still flagging `OtherType.underlying` in the same file; Option 7 cannot) is theoretical, not empirical — a brand-newtype-owning primitive's cross-brand raw access is to sibling brand primitives it bridges to, legitimate by construction.
  - **Cross-link**: numerics rule-recognizer doc at `swift-foundations/swift-linter-rules/Research/numerics-rule-recognizer-2026-05-12.md` v1.2.0 DECISION captures the same architectural conclusion from the rule-recognizer side.
- **v1.6.0 (2026-05-12)** — Numerics rule-recognizer landed (Option 1, package-scoped admission):
  - **Tier 2 research-to-implementation**: closure of the numerics cluster (~180 sites across `swift-ordinal-primitives`, `swift-cardinal-primitives`, `swift-affine-primitives`) per the RECOMMENDATION at `swift-foundations/swift-linter-rules/Research/numerics-rule-recognizer-2026-05-12.md` (Option 1 — Package-scoped admission). The rule prose's "same-package implementation" clause is now structurally honored by the engine; per-site `disable:next` directives are no longer required for the numerics cluster.
  - **Engine layer** (`swift-foundations/swift-linter`): added `Lint.Brands` discovery + cache. For each linted file the engine walks up to find the nearest `Package.swift`, reads any adjacent `.swift-linter.json`, validates it against the schema, and caches `(packageRoot → brandTypes)`. Cache amortizes across all files in the same package per run. The `Lint.Source.Parsed.brandTypes` field is populated by `Lint.Run.parsedSource(...)` and surfaced to every rule's `findings(...)` closure. The engine extension is one new file (`Lint.Package.Brands.swift`, ~220 LOC) plus a small wire-in to `Lint.Run`. Run-error type extended with `invalidLintConfiguration(reason:)` for schema-validation failures.
  - **Primitives layer** (`swift-primitives/swift-linter-primitives`): `Lint.Source.Parsed` gained a `brandTypes: Set<String>` field with a default-empty parameter. Existing call sites (rule tests, test-support factories) inherit the back-compat empty default. Field is documented; tests pass.
  - **Schema** (`swift-foundations/swift-linter-rules/Schemas/swift-linter-v1.json`): new draft-2020-12 JSON Schema. Top-level keys: `$schema` (string, optional), `brandTypes` (string array, optional). `additionalProperties: false` — unknown keys are an error at engine startup, not a silent ignore-typo. Empty `brandTypes` is permitted (no-op config).
  - **Rule wirings** (4 rules):
    - `Lint.Rule.Structure.RawValueAccess` (PATTERN-017) — `swift-foundations/swift-linter-rules`. Visitor now threads `brandTypes`; admission gate is `structureRawValueAccessIsAdmitted` (type-name match for direct `Brand.rawValue` access, package-scope fallback for variable/chain access).
    - `Lint.Rule.RawValue.Chain` (CONV-016 chain) — `swift-primitives/swift-primitives-linter-rules`. Same shape as PATTERN-017's recognizer.
    - `Lint.Rule.RawValue.BitPattern` (CONV-016 bitpattern) — `swift-primitives/swift-primitives-linter-rules`. Admission inspects the contained `.rawValue` access's base.
    - `Lint.Rule.Naming.IntParameter` (IMPL-010) — `swift-foundations/swift-institute-linter-rules`. Admission is coarser (package-scope only) because the rule fires on signatures, not on `.rawValue` access where the type-name extractor can apply.
  - **IMPL-011 verification FAILED — not wired**: the dispatch added IMPL-011 (`Lint.Rule.Memory.PointerArithmetic`, "pointer advanced by") contingent on rule-body authorization for the recognizer ("this site IS the wrapper" / "bottom-out" / "same-package" / "integration target" language). Inspection of the rule body found: "raw pointer arithmetic via `.advanced(by:)` is mechanism. Types managing memory SHOULD expose a typed `pointer(at: Index<Element>)` primitive... Either (a) add the typed primitive to the storage type and call it, or (b) confine the `.advanced(by:)` to a designated pointer-primitives package." The semantics are different — confinement to a designated package, not admission inside the brand-newtype's own package. Per the dispatch's explicit STOP instruction, IMPL-011 was not wired; the 8 IMPL-011 fires (2 Ordinal, 6 Affine) remain.
  - **Per-package `.swift-linter.json` files** (3 files):
    - `swift-ordinal-primitives/.swift-linter.json` → `{"brandTypes": ["Ordinal"]}`.
    - `swift-cardinal-primitives/.swift-linter.json` → `{"brandTypes": ["Cardinal"]}`.
    - `swift-affine-primitives/.swift-linter.json` → `{"brandTypes": ["Affine.Discrete.Vector"]}` (verified by reading `Affine.Discrete.Vector.swift` — Vector has `public let rawValue: Int`; `Affine.Discrete.Ratio` uses `.factor`, not `.rawValue`, so it is not in the brand list).
  - **Test coverage**: per-rule positive (matching brand admits), negative-mismatch (different brand still fires — strict-superset), negative-default (no `.swift-linter.json` still fires — back-compat), plus a variable-base package-scope-fallback row for the three `.rawValue` rules. 17 new tests across the 4 rules (5 PATTERN-017, 4 Chain, 4 BitPattern, 4 IMPL-010). The "Tagged extension public init" tests in primitives-linter-rules also exercised the path. Total test impact: 585 (swift-linter-rules), 51 (swift-primitives-linter-rules), 194 (swift-institute-linter-rules) — all green; 32 (swift-linter) — all green.
  - **Empirical closure** (verified 2026-05-12, post-fix counts vs pre-fix counts):
    - Ordinal: PATTERN-017 69→0, CONV-016 4→0, IMPL-010 2→0. **75/75 in-scope close.** Residue: 5 SOURCE-WRONG fires (Agent A) + 2 IMPL-011 (not wired).
    - Cardinal: PATTERN-017 27→0, CONV-016 4→0, IMPL-010 2→0. **33/33 in-scope close.** Residue: 6 SOURCE-WRONG fires (Agent A) + 0 IMPL-011.
    - Affine: PATTERN-017 63→0, CONV-016 4→0, IMPL-010 5→0. **72/72 in-scope close.** Residue: 7 SOURCE-WRONG fires (Agent A — all PATTERN-019 `tagged extension public init` in `Tagged+Affine.swift`) + 6 IMPL-011 (not wired).
    - **Total target close: 180/180** (PATTERN-017: 159/159, CONV-016: 12/12, IMPL-010: 9/9). The re-verified IMPL-010 count was 9, matching the 2026-05-12 recommendation doc's verification, not the original dispatch's 18.
  - **Strict-superset preservation** (verified): cross-package consumers without `.swift-linter.json` continue to face the rule as today; per-rule negative-default tests pin this contract. The dispatch's explicit cross-package regression check — running the linter from inside a nested `Lint/` package (which is itself a separate SwiftPM package with no `.swift-linter.json`) — was exercised empirically (the nested Lint/main.swift accesses no rawValue, so no fire is the expected output) and through the rule-level test matrix.
  - **Files touched** (this v1.6.0 entry):
    - Engine: `swift-foundations/swift-linter/Sources/Linter Core/Lint.Package.Brands.swift` (new), `Lint.Run.swift` (wire), `Lint.Run.Error.swift` (new case).
    - Primitives: `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Source.Parsed.swift`.
    - Schema: `swift-foundations/swift-linter-rules/Schemas/swift-linter-v1.json` (new).
    - Rule (Structure): `swift-foundations/swift-linter-rules/Sources/Linter Rule Structure/Lint.Rule.Structure.RawValueAccess.swift`.
    - Rule (RawValue): `swift-primitives/swift-primitives-linter-rules/Sources/Linter Rule RawValue/Lint.Rule.RawValue.Chain.swift`, `Lint.Rule.RawValue.BitPattern.swift`.
    - Rule (Naming): `swift-foundations/swift-institute-linter-rules/Sources/Linter Rule Naming/Lint.Rule.Naming.IntParameter.swift`.
    - Tests: `swift-foundations/swift-linter-rules/Tests/Linter Rule Structure Tests/Lint.Rule.Structure.RawValueAccess Tests.swift`, `swift-primitives/swift-primitives-linter-rules/Tests/Linter Rule RawValue Tests/Lint.Rule.RawValue.Chain Tests.swift`, `Lint.Rule.RawValue.BitPattern Tests.swift`, `swift-foundations/swift-institute-linter-rules/Tests/Linter Rule Naming Tests/Lint.Rule.Naming.IntParameter Tests.swift`. Test-support factory extended at `swift-foundations/swift-linter-rules/Tests/Support/Linter Rules Test Support.swift` (new `brandTypes:` parameter on `Lint.Source.parsed(...)`).
    - Consumer configs: `swift-primitives/swift-ordinal-primitives/.swift-linter.json`, `swift-primitives/swift-cardinal-primitives/.swift-linter.json`, `swift-primitives/swift-affine-primitives/.swift-linter.json`.
  - **Cross-link**: recommendation doc at `swift-foundations/swift-linter-rules/Research/numerics-rule-recognizer-2026-05-12.md` (Option 1).
  - **Out of scope** for v1.6.0: the SOURCE-WRONG residuals in each numerics package (PATTERN-019 in `Tagged+*.swift`, IMPL-109 in `Tagged+*.Successor.swift` / `.Predecessor.swift`, PATTERN-020 in `Tagged+Cardinal.swift` / `Tagged+Ordinal.swift`, API-NAME-002 in `OutputSpan+Cardinal.swift`, IMPL-011 in `Unsafe*+*Ordinal.swift`). These are Agent A's territory.
  - **Per-rule-author skill bookmark**: the package-scope admission mechanism is the missing engine-context-based counterpart to `[RULE-EXEMPT-*]` (currently AST-context only). Codification as `[RULE-EXEMPT-7]` is deferred per the recommendation doc's Follow-Up Actions §5 — wait until at least one more recognizer-class rule wires in.
- **v1.5.0 (2026-05-12)** — Wave 4 closed via Option B inversion (research-driven framework correction):
  - **Wave 4 carve-out reverted in favor of inversion** per Tier 2 research at `swift-institute/Research/safe-attribute-absorber-pattern-fundamentals.md` v1.1.0 DECISION. The carve-out approach (v1.4.0's `[MEM-SAFE-025b]` exception for type-decl absorber pattern) was tool-capability-bound rather than structurally principled. Empirical surprise (~120 residuals vs <10 predicted) was the symptom of the underlying framing being wrong, not of carve-out being too narrow.
  - **`[MEM-SAFE-025b]` inverted** (Skills `b72677a`): admit `@safe` per SE-0458's intent instead of forbidding; the Wave 4 absorber-pattern carve-out language is removed. The "direct `@safe` on funcs/vars/lets/inits/subscripts remains forbidden" clause from Wave 3 also removed — `@safe` admitted on all declaration kinds per SE-0458's permission.
  - **`[MEM-SAFE-025c]` authored** (Skills `b72677a`): disclosure requirement. Every `@safe` declaration MUST carry an adjacent invariant disclosure — either a `// SAFETY:` / `// WHY:` line block OR a `## Safety Invariant` doc-comment section. Category citation per `[MEM-SAFE-024]` is SHOULD-strength (some sites don't categorize cleanly under A/B/C/D).
  - **Rule rename + inversion** (swift-linter-rules `a881e0f`): `Lint.Rule.Memory.SafeForbidden` → `Lint.Rule.Memory.SafeAttributeUndocumented`. Predicate flipped — fires when `@safe` present without adjacent disclosure (drops the Wave 4 condition-1 unsafe-internals check entirely). Applies uniformly to struct/class/enum/actor/extension/protocol/func/var/init/deinit/subscript/typealias/associatedtype. 26 new tests + 577-test suite green.
  - **Source migration cascade**: 29 packages touched, ~120 invariant disclosures added across the ecosystem. Per-package commits enumerated in the v1.5.0 References section below. Final ecosystem-wide lint sweep: **0 `safe attribute undocumented` findings** across all 150 `@safe` sites in 134 files.
  - **Empirical correction**: live `@safe` count was 150 occurrences in 134 files, not the ~125 the research doc estimated. Three-cluster framing held; counts skewed higher (cluster C pure-documentation dominated).
  - **Pre-existing unrelated build failure noted**: `swift-darwin-standard` has a Tagged.rawValue lookup error in `Darwin.Loader.Image.swift:121` that pre-dates this work; reproduces on unmodified tree. Not Wave 4 related; tracked separately.
  - **Wave 4 carve-out doc status**: `wave-4-absorber-pattern-policy-lean-2026-05-12.md` flipped to **SUPERSEDED** v1.2.0 (swift-linter-rules `294393b`). The carve-out implementation commits (Skills `e4d66dd`, swift-linter-rules `cbf4922`) remain in history but are functionally replaced.
- **v1.4.0 (2026-05-12)** — Wave 3 Open Q1 closed (post-Wave-3 Phase 2 closure):
  - **Re-triage of 2.1 (takeIfPresent / consumeIfStored)** at `HANDOFF-rule-triage-re-examination.md` Findings reversed the prior RECOMMENDATION (RULE-WRONG → stdlib-idiom exemption) to **SOURCE-WRONG**: refactor the compound-named sites to single-word verbs, drop the trapping siblings (Option A — the institute's `pop.first` usage in adjacent packages is the worked precedent; the cited `popFirst` stdlib analog has verb+target shape, not the verb+suffix-modifier shape of `takeIfPresent`).
  - **Implementation landed at swift-ownership-primitives `6adf223`** (pushed):
    - `Ownership.Latch.takeIfPresent()` → `Ownership.Latch.take()` (Optional-returning, canonical); trapping sibling `Latch.take() -> Value` **deleted**.
    - `Ownership.Transfer.{Erased,Retained,Value}.Incoming.consumeIfStored(...)` → `Ownership.Transfer.{Erased,Retained,Value}.Incoming.consume(...)` (Optional-returning, canonical); trapping siblings **deleted** on each variant.
    - `Ownership.Transfer.Value.Outgoing.Token.take() -> V` preserved (different surface, exactly-once semantics) — wraps the new Optional `Latch.take()` with `preconditionFailure`.
  - **External consumer cascade**: `swift-foundations/swift-observations/Sources/Observations/withObservationTracking.swift` updated (1 production call site + 1 docstring), commit `13cff4d` — LOCAL ONLY (swift-observations has no remote configured).
  - **Residual count**: 4 → 0. The compound-identifier residuals are fully closed.
  - **Surface-label correction**: prior ledger entries (v1.0.0 through v1.3.0) named the residuals as on "Slot.Move + retained-incoming/outgoing." On inspection, the real surfaces were `Ownership.Latch` + `Ownership.Transfer.{Erased,Retained,Value}.Incoming`. `Slot.Move` itself (file `Ownership.Slot.Move.swift`) has `out` / `in(_:)` only. The "Slot.Move" label was a shorthand/misnomer carried forward from the initial Wave 3 dispatch. Subsequent ledger references should use the correct surface names.
  - **Tests**: 115/115 pass on swift-ownership-primitives; swift-observations builds clean. Lint pass: 4 → 0 compound-identifier findings (verified).
  - **Pattern note**: `Optional<T>` where `T: ~Copyable` cannot be borrowed twice across multiple `#expect` calls — initial test rewrite hit "consumed more than once"; corrected pattern is `guard let x = … else { Issue.record(…); return }`. Worth capturing as a corpus pattern (testing-swiftlang or memory-safety skill addendum) — surfaced for orchestrator awareness.
- **v1.3.0 (2026-05-12)** — Post-closure empirical follow-ups (Phase 1.4
  of the post-Wave-3 quick-wins dispatch):
  - Open Follow-Up #4 answered — `nonisolated(unsafe)` site enumeration
    ecosystem-wide: **28 occurrences across 20 files in production
    Sources** (24 real + 4 in-rule token references). Workspace-wide
    grep against `swift-primitives/*/Sources`, `swift-foundations/*/Sources`,
    `swift-standards/*/Sources` 2026-05-12. `@safe`-on-same-line adjacency
    rate: 0. Structural adjacency via enclosing-type `@safe` (absorber
    pattern): observed, not enumerated per-site.
  - Open Follow-Up #5 scope refined — Wave 4's absorber-pattern footprint
    is **~128 sites, not ~80**. Empirical count: 140 `@safe` occurrences
    in 125 files, of which ~128 attach to type-decls (absorber pattern)
    and ~22 attach to individual decls (direct). Hot-spot packages
    enumerated in Open Follow-Up #5 entry. Wave 4 dispatch sizing should
    use 128, not 80.
  - No engine / rule / Skills changes in v1.3.0 — empirical refinement
    of Open Follow-Ups only.
- **v1.2.0 (2026-05-12)** — Wave 3 fully closed:
  - All 3 user-tier policy decisions stamped DECISION (Options B, B, D) at swift-institute/Research stamp commit `78f9bea` (after the 3 RECOMMENDATION docs `59f3906`, `5e2b1c5`, `c3dfd92`).
  - **Thread 4 implemented** — [API-NAME-002] amended for fileprivate+private exemption. Skills `3a36ce3` + swift-institute-linter-rules `1c06647`. Visibility check walks the parent chain for effective visibility (the simple-modifier sketch in the research doc was insufficient — `Header` fields had no explicit modifier; visibility came from enclosing fileprivate struct). 15 new tests; 182 total pass. 2 Header.* residuals close (in-test verified via verbatim regression test).
  - **Thread 7 implemented** — [MEM-SAFE-025] split into [MEM-SAFE-025a] (invariant comment) + [MEM-SAFE-025b] (@safe forbidden in Sources). Skills `677ccaa` + swift-linter-rules `8e06283` (delete NonisolatedUnsafeSafe + create NonisolatedUnsafeInvariant + SafeForbidden + 20 new tests). 5-package source migration: swift-render-primitives `c205917`, swift-machine-primitives `063a6e1`, swift-witnesses `b241dc5`, swift-cpu-primitives `2eaf579`, swift-memory-primitives `56bd0f6`. The 4 AMBIGUOUS residuals (3 on swift-ownership-primitives + 1 on swift-property-primitives) close vacuously — neither package has any `nonisolated(unsafe)` decls in Sources (the doc-enumerated reference to "3 nonisolated(unsafe) AMBIGUOUS findings" was misattributed).
  - **Thread 8 implemented** — per-finding disable mechanism via Option D hybrid. Engine commit swift-linter `f913d1b` (line-comment scan + suppression map; ~314 LOC). Config-file thread via swift-linter-primitives `d15e030` (Manifest.disabledRuleIDs → Driver → Configuration, previously silently ignored post-Phase-B.1 decouple). Rule message updates swift-linter-rules `2d5dc2f` (6 rules: unchecked call site, enumerated with subscript, count minus one, zero or one literal, for loop in result builder, raw value access). Slot.Move sites suppressed in swift-ownership-primitives `cbce2cd`. 24/24 tests pass. 2 unchecked-call-site residuals close.
  - **Per-target residual count: 12 → 4.** The 4 remaining are all `takeIfPresent` / `consumeIfStored` compound-name findings on `swift-ownership-primitives` (HANDOFF Open Q3) — breaking-API rename deferred until next API-design pass.
  - **New scope surfaced (Wave 4):** Thread 7's `SafeForbidden` rule fires on ~80 `@safe` absorber-pattern sites ecosystem-wide ([MEM-SAFE-021]/[MEM-SAFE-022]/[MEM-SAFE-023]). [MEM-SAFE-025b] body explicitly names this as out-of-scope for Wave 3. Future dispatch options: (a) extend [MEM-SAFE-025b] with absorber-pattern carve-out, (b) migrate all ~80 sites, or (c) introduce a `@unsafe` escape hatch via Thread 8's `// swift-linter:disable` directive.
  - **Pre-existing test failures closed** (orthogonal to Wave 3 but flagged by Thread 7/8 subagents; closure included in this ledger for completeness):
    - swift-machine-primitives `Machine.Node Tests:252` — Tagged API rename `.rawValue` → `.underlying` not propagated to test (`8695ce4`).
    - swift-witnesses `@Witness` macro — `__unchecked` → `_unchecked` init-label cascade missed from 2026-05-04 finite-primitives migration (`3556323`).
    - swift-linter-rules `MockFactoryZeroCollision Tests` — test fixture default path `Sources/X/Test.swift` didn't satisfy Wave 2 amendment #10's `/Tests/` scope gate; fixture corrected to `/Tests/X/Test.swift` (`40608cb`). Root cause was fixture drift, not rule logic drift.
  - **Engine on main**: swift-linter ff-merged `lint-pass-audit-2026-05-11` into `main` (THROWAWAY `17a9777` survives in history per user "will be squashed later before publication"); feature branch deleted.
- **v1.1.0 (2026-05-11)** — appended:
  - stdlib-extensions Lint build defect fixed (swift-primitives/swift-standard-library-extensions commit `02ac34f`); re-ran lint to obtain the 11-package number (0 findings).
  - Thread 2 partial-gap closed via follow-up amendment (swift-linter-rules commit `ac40ca1`); 1 residual `extension noncopyable constraint` finding on `Erased.Incoming:57` no longer fires.
  - Updated per-target table and totals to reflect both fixes.
- **v1.0.0 (2026-05-11)** — initial 9-of-10-packages aggregate; documented stdlib-extensions build defect + Thread 2 partial-gap as follow-ups.

## Context

Wave 3 dispatch (HANDOFF.md) landed 5 rule-amendment commits across two
rule packages, plus 3 RECOMMENDATION research docs for the queued
policy/design questions. This ledger captures the post-amendment
aggregate lint pass against the same 10 leaf packages used for the
2026-05-11 pre-amendment baseline (`lint-pass-2026-05-11-aggregate.md`).

**Engine (v1.2.0)**: swift-linter @ `f913d1b` on `main` (post-ff-merge):
- `b060fb3` Three-tier hierarchy: drop rule deps; hoist Lint.run() helper (pre-Wave-3)
- `86856c1` Exclude `*.docc/**` from source discovery; add path-substring safety net (pre-Wave-3)
- `f913d1b` Wave 3 Thread 8: add per-finding disable mechanism (line-comment + config-file)

**Rule packages (v1.2.0)**:
- swift-linter-rules @ `40608cb` — includes Wave 3 #1, #2, #2-ext, #5, #6, #7 split (NonisolatedUnsafeInvariant + SafeForbidden), #8 rule-message updates, and MockFactoryZeroCollision fixture-path fix
- swift-institute-linter-rules @ `1c06647` — includes Wave 3 #3, #4 (BoxClass), #4-amend (visibility check)
- swift-linter-primitives @ `d15e030` — Wave 3 #8 Lint.Configuration.disabledRuleIDs
- swift-institute/Skills @ `677ccaa` — Wave 3 #4 [API-NAME-002] amendment + #7 [MEM-SAFE-025] split

**Lint executable build**: per-package `Lint/` nested sub-package; path-
deps onto rule packages pick up Wave 3 amendments locally without
`swift package update`.

## Per-target totals

| Target | Baseline | Wave 3 v1.1.0 | Wave 3 v1.2.0 | Δ | Notes |
|--------|---------:|--------------:|--------------:|---:|------|
| swift-carrier-primitives | 18 | 0 | 0 | -18 | DocC findings cleared via engine exclusion (86856c1); MEM-COPY + minimal Protocol closed by Wave 2 ledger entries |
| swift-comparison-primitives | 45 | 0 | 0 | -45 | DocC + Wave 2 closeouts |
| swift-either-primitives | 6 | 0 | 0 | -6 | Compound `flatMap` exempted via stdlib-idiom citations (Wave 2 ledger #1) |
| swift-equation-primitives | 55 | 0 | 0 | -55 | DocC + Wave 2 closeouts |
| swift-hash-primitives | 46 | 0 | 0 | -46 | DocC + Wave 2 closeouts |
| swift-ownership-primitives | 56 | 11 | 0 (v1.4.0) | -56 | v1.2.0: Thread 4 closes 2 Header.* (private surface); Thread 7 closes 3 nonisolated-unsafe vacuously; Thread 8 closes 2 unchecked-call-site (suppressed at Slot.Move). **v1.4.0**: Open Q1 closes via SOURCE-WRONG refactor — Latch.takeIfPresent → take(), Transfer.{Erased,Retained,Value}.Incoming.consumeIfStored → consume(), trapping siblings deleted. Zero residuals. |
| swift-product-primitives | 13 | 0 | 0 | -13 | MEM-COPY pack-expansion + Existential — Wave 2 ledger amendments |
| swift-property-primitives | 15 | 1 | 0 | -15 | v1.2.0: Thread 7 closes the 1 AMBIGUOUS vacuously (no nonisolated(unsafe) in Sources) |
| swift-standard-library-extensions | 620 | 0 | 0 | -620 | v1.1.0: Lint sub-package build defect fixed (`02ac34f`); re-ran clean. All 620 baseline findings closed via combined engine DocC exclusion + Wave 2 source-fixes (d19e725) + `.disable(.\`int public parameter\`)` directive (54) + Wave 3 amendments |
| swift-tagged-primitives | 22 | 0 | 0 | -22 | Tagged-init + bridge + Compound closeouts |
| **Total (11 packages)** | **896** | **12** | **0 (v1.4.0)** | **-896** | **100% drop ecosystem-wide; all original Wave 3 residuals closed** |

**Wave 4 emergence (out-of-scope for this ledger; tracked separately):**
Thread 7's new `SafeForbidden` rule fires on ~80 `@safe` absorber-pattern
sites ecosystem-wide ([MEM-SAFE-021]/[MEM-SAFE-022]/[MEM-SAFE-023]).
These sites are NOT counted in the per-target totals above (the
ledger scope is the original Wave 3 residual). Wave 4 dispatch will
need its own ledger.

The 263-finding drop on the 9 cleanly-building packages confirms the
handoff's prediction ("compound identifier findings drop materially
due to local-var scope gate; docc findings clear via engine
exclusion"). The compound_identifier rule's 363 baseline findings
were dominated by DocC step-files (the per-leaf reports cited
`Carrier Primitives.docc/Resources/step-*` paths as the bulk); the
engine's `*.docc/**` exclusion (`86856c1`, landed pre-Wave-3 but
post-baseline) removes those without rule changes.

## Per-rule breakdown — all original Wave 3 residuals closed (v1.4.0)

Zero residuals. Every finding in the original 12-residual ledger has a verified disposition.

### swift-ownership-primitives — 0 findings (v1.4.0)

| Rule | Count | Disposition |
|------|------:|-------------|
| ~~compound identifier (takeIfPresent / consumeIfStored)~~ | ~~4~~ | **CLOSED in v1.4.0** via SOURCE-WRONG refactor (swift-ownership-primitives `6adf223`): `Ownership.Latch.takeIfPresent` → `take()`, `Ownership.Transfer.{Erased,Retained,Value}.Incoming.consumeIfStored` → `consume()`; trapping siblings deleted (Option A). External cascade: swift-observations `13cff4d` (local-only). Prior surface label "Slot.Move" was a misnomer; correct surfaces are Latch + Transfer.*.Incoming. |
| ~~compound identifier (Header)~~ | ~~2~~ | **CLOSED in v1.2.0** via Thread 4 (`1c06647`) — fileprivate/private exemption added to [API-NAME-002]; `destroyPayload` / `payloadOffset` on `Erased.Outgoing.Header` no longer flagged |
| ~~unchecked sendable noncopyable~~ | ~~3~~ | **CLOSED in v1.2.0** vacuously via Thread 7 (`8e06283` + skill split `677ccaa`) — no `nonisolated(unsafe)` decls in swift-ownership-primitives Sources |
| ~~unchecked call site~~ | ~~2~~ | **CLOSED in v1.2.0** via Thread 8 (`f913d1b` engine + `cbce2cd` source) — `Slot.Move.in/out` suppressed with `// swift-linter:disable:next` + REASON |
| ~~extension noncopyable constraint~~ | ~~1~~ | **CLOSED in v1.1.0** via Thread 2 extension (`ac40ca1`) |

### swift-property-primitives — 0 findings (v1.2.0)

| Rule | Count | Disposition |
|------|------:|-------------|
| ~~unchecked sendable categorization~~ | ~~1~~ | **CLOSED in v1.2.0** vacuously via Thread 7 — no `nonisolated(unsafe)` decls in Sources |

## Wave 3 thread-by-thread validation

| Thread | Wave 3 deliverable | Baseline finding | Post-amendment | Result |
|--------|--------------------|------------------|----------------|--------|
| #1 — ExtensionNoncopyableConstraint nested-type skip | Code amendment (f89c4d4) + 3 tests | 6 RULE-WRONG | 0 of these 6 remain | ✓ Closed |
| #2 — ExtensionNoncopyableConstraint method-local generics | Code amendment (4f85e1a) + 4 tests; **v1.1.0 extension** `ac40ca1` adds consuming-self/own-generics exemption + 3 tests | 1 RULE-WRONG | 0 of these remain (both parameter-shape AND consuming-self shape now exempt) | ✓ Closed (v1.1.0) |
| #3 — NamingCompound SE-0517 mutableSpan/span exemption | Code amendment (02cab07) + 2 tests | 1 RULE-WRONG | 0 of this 1 remains | ✓ Closed |
| #4 — NamingCompound private-surface policy | Research doc + DECISION (Option B) `78f9bea` + Skills `3a36ce3` + rule amendment `1c06647` (visibility helper walks parent chain for effective visibility) | 2 RULE-WRONG (held) | 0 remain | ✓ Closed (v1.2.0) |
| #5 — BoxClass canonical-CoW-backing exemption | Code amendment (686f208) + 4 tests | 1 RULE-WRONG (ad_hoc_box_class on Indirect.Storage) | 0 of this 1 remains | ✓ Closed |
| #6 — InlinableInternalAccess init-specific message | Code amendment (d18e62a) + 3 tests | 0 (Wave 2 source-fix already closed) | n/a — message-quality amendment, not a finding-count amendment | ✓ Closed (consumer-experience improvement) |
| #7 — [MEM-SAFE-025] reconciliation | Research doc + DECISION (Option B) `78f9bea` + Skills split `677ccaa` + rule split `8e06283` (NonisolatedUnsafeSafe → NonisolatedUnsafeInvariant + SafeForbidden) + 5-package source migration (`c205917`, `063a6e1`, `b241dc5`, `2eaf579`, `56bd0f6`) | 3 unchecked-sendable-noncopyable + 1 AMBIGUOUS (held) | 0 remain (closed vacuously — no nonisolated(unsafe) in Sources of ownership/property primitives) | ✓ Closed (v1.2.0); ~80 absorber-pattern sites surfaced → Wave 4 |
| #8 — Per-finding disable mechanism | Research doc + DECISION (Option D) `78f9bea` + engine `f913d1b` (line-comment + suppression map) + Configuration thread `d15e030` + rule-message updates `2d5dc2f` + source migration `cbce2cd` | 2 unchecked-call-site (held) | 0 remain (Slot.Move.in/out suppressed with REASON citing [CONV-016]) | ✓ Closed (v1.2.0) |

## Wave 3 amendment summary

- **5 rule amendments landed in v1.0.0** (Threads #1, #2, #3, #5, #6) across 2 rule packages, 12 new tests added.
- **1 rule amendment + 1 follow-up landed in v1.1.0** (Thread 2 extension `ac40ca1` + stdlib-extensions build fix `02ac34f`).
- **3 user-tier-decision implementations landed in v1.2.0** (Threads #4, #7, #8): 1 [API-NAME-002] amendment + 1 [MEM-SAFE-025] split (2-rule replacement) + 1 engine extension (per-finding disable). 59 new tests added (15 + 20 + 24). 4 user-tier-decision-blocked rule classes close.
- **3 pre-existing test failures closed in v1.2.0** (orthogonal to Wave 3): machine-primitives Tagged API drift, witnesses macro init-label cascade, MockFactoryZeroCollision fixture path.
- **892 finding drop** ecosystem-wide (v1.2.0 11-package number: 896 → 4; 99.6%).

## Residuals after Wave 3 (v1.5.0)

**Zero on Wave 3 scope.** Every original Wave 3 residual was closed at
v1.4.0 (Open Q1 takeIfPresent refactor).

**Wave 4 (absorber-pattern carry-forward) also closed at v1.5.0** via
Option B research-driven inversion. The ~128 carve-out target became
150 sites empirically; all admitted under the inverted
`[MEM-SAFE-025b]` + new `[MEM-SAFE-025c]` framework with disclosure
required. Zero `safe attribute undocumented` findings ecosystem-wide.

**Wave 4 carry-forward**: Thread 7's new `SafeForbidden` rule fires on
~80 `@safe` absorber-pattern sites ecosystem-wide ([MEM-SAFE-021] /
[MEM-SAFE-022] / [MEM-SAFE-023]). These sites are NOT in this
ledger's per-target scope — they emerged from a rule whose previous
form ([MEM-SAFE-025] requires `@safe`) actually MANDATED the pattern
that the new form forbids. The ~80-site footprint informs Wave 4
dispatch: extend [MEM-SAFE-025b] with absorber-pattern carve-out, or
migrate all sites, or apply Thread 8's `// swift-linter:disable`
directive site-by-site.

## Outstanding follow-ups

1. ~~**Thread 2 follow-up amendment**~~ — **CLOSED in v1.1.0** via
   commit `ac40ca1` (Wave 3 ledger #2 extension: consuming-self with
   own generic params). The pattern-based exemption per the
   recommendation: when a function declares `consuming`/`borrowing`
   modifier AND has its own generic parameter clause, treat as
   method-scoped (not type-scoped). 3 new tests added; 16 tests
   total in the ExtensionNoncopyableConstraint suite, all pass.

2. ~~**swift-standard-library-extensions Lint sub-package build defect**~~
   — **CLOSED in v1.1.0** via commit `02ac34f` in
   swift-primitives/swift-standard-library-extensions. Added direct
   `swift-institute-linter-rules` package dep + `Linter Rule Naming`
   product dep + `internal import Linter_Rule_Naming` to main.swift.
   Build clean; lint runs to completion at 0 findings.

3. **Visibility-tagged lint pass** (per Thread 4 research doc empirical
   follow-up) — extend the lint pass to capture visibility per
   finding to measure the fileprivate/private slice ecosystem-wide.
   The v1.2.0 amendment ships without this empirical measurement;
   would inform a future tightening pass.

4. **`nonisolated(unsafe)` site enumeration** (per Thread 7 research
   doc empirical follow-up) — **answered 2026-05-12** via workspace-wide
   grep across `swift-primitives/*/Sources`, `swift-foundations/*/Sources`,
   `swift-standards/*/Sources`. Total: **28 occurrences across 20 files
   in production Sources** (24 real + 4 in-rule token references inside
   `Lint.Rule.Memory.NonisolatedUnsafeInvariant.swift` / `Lint.Rule.Memory.SafeForbidden.swift`).
   `@safe`-on-same-line adjacency: 0 sites. Structural adjacency via
   enclosing-type `@safe` (absorber pattern): observed e.g.
   `swift-darwin-standard/Darwin.Loader.Image.Header.swift:31` where
   `nonisolated(unsafe) let rawValue` lives inside a `@safe public struct Header`.

5. **Wave 4 absorber-pattern dispatch** — Thread 7 surfaced **~128 `@safe`
   absorber-pattern sites** (NOT the initial ~80 estimate) — empirical
   count 2026-05-12 across the same Sources/ scope: **140 `@safe`
   occurrences total** (125 distinct files), of which **~128 attach to
   type-decls (struct/class/enum/actor/extension/protocol)** (absorber
   pattern) and **~22 attach to individual decls** (func/var/let/init/
   subscript/typealias) (direct). Top packages by absorber-pattern
   density: `swift-bit-vector-primitives` (17), `swift-ownership-primitives`
   (14), `swift-machine-primitives` (9), `swift-buffer-primitives` (8),
   `swift-queue-primitives` (7), `swift-property-primitives` (7),
   `swift-memory-primitives` (6). Needs its own ledger + policy decision
   (carve-out / migrate / disable-directive). [MEM-SAFE-025b] body
   explicitly names this as Wave 3's out-of-scope follow-up. Scope is
   60% larger than initial estimate — Wave 4 dispatch sizing should
   reflect the ~128 figure, not ~80.

6. **takeIfPresent / consumeIfStored API-rename pass** (HANDOFF Open
   Q3) — accept compound-name exception OR refactor to
   `take.ifPresent` nested accessor (breaking API for 4 call sites
   on `Slot.Move` retained-incoming/outgoing). Hold for next
   API-design cycle.

## Closeout

Wave 3 dispatch is **fully closed (v1.2.0)**. The aggregate validation
confirms:

- Predicted compound-identifier finding drop materialized.
- All Wave 3 rule amendments hold in the aggregate (no surprise
  regressions).
- All three user-tier policy decisions stamped, implemented, and
  validated.
- 8 of 12 residuals closed via implementation; 4 deferred to the next
  API-design cycle.
- A new scope (Wave 4: `@safe` absorber-pattern, ~80 sites) surfaced
  as a consequence of Thread 7's two-rule replacement and is tracked
  as a separate dispatch.

## References

- Pre-amendment baseline: [lint-pass-2026-05-11-aggregate.md](lint-pass-2026-05-11-aggregate.md)
- Wave 2 dispatch ledger: [wave-2-rule-amendments-2026-05-11.md](wave-2-rule-amendments-2026-05-11.md)
- Wave 3 dispatch source: `HANDOFF.md` (Wave 3 rule-amendment backlog + queued policy decisions)
- Wave 2 leaf triage commits: swift-ownership-primitives `b475d6f`, swift-standard-library-extensions `d19e725`, swift-institute/Scripts `54c55d9`
- Wave 3 ledger commits (rule amendments):
  - swift-linter-rules: `f89c4d4` (#1), `4f85e1a` (#2), `d18e62a` (#5 — InlinableInternalAccess), `ac40ca1` (#2 extension: consuming-self with own generic params)
  - swift-institute-linter-rules: `02cab07` (#3), `686f208` (#4 — BoxClass)
- Wave 3 thread #9 follow-ups (v1.1.0):
  - swift-primitives/swift-standard-library-extensions: `02ac34f` (Lint sub-package build fix)
  - swift-linter-rules: `ac40ca1` (Thread 2 extension)
- Wave 3 v1.2.0 implementation commits (user-tier decisions):
  - swift-institute/Research: `59f3906`, `5e2b1c5`, `c3dfd92` (RECOMMENDATION docs) + `78f9bea` (stamp DECISION Options B/B/D)
  - Thread #4 (Option B — fileprivate/private exemption):
    - swift-institute/Skills: `3a36ce3` ([API-NAME-002] visibility-scope sub-section)
    - swift-institute-linter-rules: `1c06647` (Lint.Rule.Naming.Compound visibility helper + 15 tests)
  - Thread #7 (Option B — two-rule replacement):
    - swift-institute/Skills: `677ccaa` ([MEM-SAFE-025] SUPERSEDED + [MEM-SAFE-025a/b])
    - swift-linter-rules: `8e06283` (NonisolatedUnsafeInvariant + SafeForbidden, 20 tests)
    - swift-render-primitives: `c205917` (Thunk/Work @safe → SAFETY)
    - swift-machine-primitives: `063a6e1` (Value/Capture.Slot _Storage @safe → SAFETY)
    - swift-foundations/swift-witnesses: `b241dc5` (Values._Storage @safe → SAFETY)
    - swift-cpu-primitives: `2eaf579` (CPU.Cache.Padded @safe → SAFETY)
    - swift-memory-primitives: `56bd0f6` (DocC examples updated)
  - Thread #8 (Option D — hybrid line-comment + config-file):
    - swift-linter: `f913d1b` (Lint.Suppression + Lint.Run elision + Driver threading)
    - swift-linter-primitives: `d15e030` (Lint.Configuration.disabledRuleIDs)
    - swift-linter-rules: `2d5dc2f` (6 rule messages updated; natural-English IDs)
    - swift-ownership-primitives: `cbce2cd` (Slot.Move.in/out suppressed per [CONV-016])
- Wave 3 v1.2.0 pre-existing test fixes (orthogonal cleanup):
  - swift-machine-primitives: `8695ce4` (Tagged `.rawValue` → `.underlying`)
  - swift-foundations/swift-witnesses: `3556323` (@Witness macro `__unchecked` → `_unchecked` cascade)
  - swift-linter-rules: `40608cb` (MockFactoryZeroCollision test fixture path `/Tests/`)
- Wave 3 research docs (DECISION, v1.2.0):
  - `swift-institute/Research/api-name-002-private-surface-applicability.md` (Thread #4, Option B)
  - `swift-institute/Research/mem-safe-025-reconciliation.md` (Thread #7, Option B)
  - `swift-institute/Research/swift-linter-per-finding-disable-mechanism.md` (Thread #8, Option D)
