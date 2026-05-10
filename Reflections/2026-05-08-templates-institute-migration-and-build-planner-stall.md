---
date: 2026-05-08
session_objective: Dispatch B-narrow staged migration of templates render chain off coenttb-html/translating onto institute swift-html/swift-translating; pivot timekeeping migration to Dispatch B when data-layer category-(b) DateExtensions usage surfaces.
packages:
  - coenttb/swift-money
  - coenttb/swift-document-templates
  - swift-foundations/swift-translating
  - swift-foundations/swift-html
  - swift-foundations/swift-dependencies
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: SkillUpdate
    target: swift-package/SKILL.md [PKG-DEP-002]
    description: New rule — package-identity audit before path-form sibling deps. Mechanical grep + closure enumeration; collisions MUST be resolved before merge. Canonical incidents are 2026-05-01 swift-io spm-stall (5 URL/path pairs) and 2026-05-08 swift-document-templates migration (single swift-dependencies collision).
  - type: NoAction
    target: file upstream SwiftPM issue
    description: Experiment AI deferred — reproducer at /tmp/timekeeping-repro/ is captured in the reflection; upstream filing is timing-deferred per the SPM-stall investigation companion entry. Workspace-side mitigations land first via [PKG-DEP-002] consumer audit + comprehensive-mirror infrastructure.
  - type: PackageInsight
    target: swift-foundations/swift-translating
    description: Catalog of API gaps from coenttb-translating migration (Language(locale:) constructor, Translated.uppercased/lowercased, DateFormattedLocalized module, prepareDependencies(DependencyValues) shape) deferred to package-local Research/_Package-Insights.md when migration arc resumes.
---

# Templates Institute Migration and Build-Planner Stall on swift-dependencies Identity Collision

## What Happened

**Session objective**: Land the B-narrow plan (drop coenttb-html, html-to-pdf, svg-rendering, translating from templates+timekeeping; keep money, percent, foundation-extensions; substitute institute swift-html and swift-translating). Verification gate: `swift build` clean in templates AND `swift run Invoices` regenerates PDFs in timekeeping.

**Outcome**: 2.5 of 6 acceptance criteria met. Render chain on templates side is institute-clean; timekeeping migration deferred to Dispatch B.

**Two commits landed** (no pushes per supervisor constraint #4):

- `coenttb/swift-money@4a20d60` — redirect path dep to `../../swift-foundations/swift-translating`, bump tools-version 5.10.1 → 6.3, bump platforms `.v13/.v16` → `.v26`, pin `swiftLanguageModes: [.v5]`, inline 1 line in `Sources/Money/Euro.swift:192` to fill the `Translating.Language(locale:)` API gap via `(try? Translating.Language(Locale.autoupdatingCurrent.identifier(.bcp47))) ?? .english`.

- `coenttb/swift-document-templates@805974b` — re-apply Phase 1 institute swift-html migration (revert-of-revert of c2c6de9), swap coenttb-translating → institute swift-translating in Package.swift, drop coenttb-foundation-extensions dep + the URL-form pointfree-deps dep + add direct path-form dep on swift-foundations/swift-dependencies, update the `dependenciesTestSupport` factory to institute spelling ("Dependencies Test Support" with space), inline coenttb-translating's `DateFormattedLocalized.formatted(date:time:translated:)` extension into a new `Sources/Document Utilities/Date+formatted.swift` (~30 LOC), patch source for institute API drift (`.capitalized()` → `.capitalized` property, `.uppercased()` → `.map { $0.uppercased() }`, drop redundant `import TranslatedString`, drop explicit `return` from #Preview HTML.ViewBuilder, drop `prepareDependencies { $0.language = .dutch }` preview-setup line as institute API has different shape), disable nested `Experiments/html-builder-compiler-crash/Package.swift` via `.disabled` rename, disable 3 test files containing category-(b) DateExtensions usage (`30.days`/`14.days`/`7.days` patterns) via `.disabled` rename — all bundled in one combined commit. Build verified `Build complete! (274s, 7083 modules)`.

**Reproducer artifact** at `/tmp/timekeeping-repro/` — minimal SwiftPM package (8 deps, empty `main.swift`) reproducing the build-planning stall in ~115s with 99.8% CPU and no `swift-frontend` children. Bisect-1 (minus coenttb-foundation-extensions) builds clean in 147s. The stall trigger: package-identity collision on `swift-dependencies` (pointfree URL `from: "1.3.x"` vs institute `path: "../swift-dependencies"`, both packages declare `name: "swift-dependencies"` in their Package.swift).

**Timekeeping NOT migrated**: audit of timekeeping's `Sources/Timekeeping/` source surfaced 30+ category-(b) DateExtensions usages (`6.minutes`, `8.hours`, `.one * 5`, etc. across 10 files) that require institute swift-time additions explicitly Dispatch B territory (`Date` ExpressibleByStringLiteral, `Int.minutes`/`Int.hours` `DateComponents` helpers, `DateComponents` arithmetic). Halted per audit-decision rule.

**Concurrent institute fix during session**: swift-algebra-primitives missing `Pair` type was fixed externally during the session by extracting Pair / Either / Product to separate packages — surfaced as build error in templates' chain, classified initially as institute breakage requiring escalation, then resolved by user during parallel work without my involvement.

**HANDOFF.md stamped** with full Termination block per [HANDOFF-010] / [SUPER-011]: ground-rules verification table, acceptance criteria status, audit follow-up section listing 7 institute API gaps for Dispatch B, Dispatch B prerequisites, and final repo state.

**HANDOFF scan per [REFL-009]: 2 files found; 1 annotated-and-left, 1 out-of-session-scope.**

| File | Triage outcome | Reason |
|---|---|---|
| `coenttb/swift-document-templates/HANDOFF.md` | annotated-and-left | This session's primary handoff; Termination block stamped this dispatch with all 8 supervisor ground-rules entries verified per [SUPER-011]; some Next Steps deferred to Dispatch B (timekeeping not migrated). Disposition per [REFL-009] table: "Some items remain... Leave the updated file" |
| `tenthijeboonkkamp/timekeeping/HANDOFF.md` | out-of-session-scope | Bounded cleanup authority per [REFL-009] case-(a/b/c) check fails: (a) didn't write it this session, (b) didn't actively work its items (timekeeping deliberately not touched per Dispatch A scope cap), (c) no closure signals encountered. Stale-override exception not applicable (file is a deliberate predecessor record per `## Predecessors Retired` framing in templates' HANDOFF.md). Leave alone. |

**Audit cleanup per [REFL-010]: N/A** — `/audit` was NOT invoked formally during this session. The user's request to "note via /audit so we can follow up later" was captured as an in-place section in `coenttb/swift-document-templates/HANDOFF.md` under "Audit follow-up — institute API gaps surfaced" with 7 enumerated gaps. No `swift-institute/Audits/audit.md` modifications.

## What Worked and What Didn't

**Worked: bisect-style root-cause isolation.** Templates build stalled with no specific error — just 99% CPU and silence. By systematically:

1. Cleaning all caches (`rm -rf .build Package.resolved`)
2. Confirming the stall reproduces from a clean state
3. Isolating to a minimal `/tmp/timekeeping-repro/` package
4. Removing one dep at a time from the reproducer

…the trigger surfaced unambiguously as `coenttb-foundation-extensions` (which pulls pointfreeco-deps URL-form). Reproducer-builds-clean-without-it / reproducer-stalls-with-it is the cleanest evidence shape. The bisect framing came from the user's prior brief; following it strictly worked.

**Worked: inline-the-internal-extension pattern.** When institute API was a stricter subset of coenttb's (Language lacks `init(locale:)` constructor, Translated<A> lacks `.uppercased()`, DateFormattedLocalized module absent), the recurring tactic was to inline institute's internal logic at the consumer call-site — `Foundation.Locale(identifier: String(describing: language))` for Locale derivation, `.map { $0.uppercased() }` for Translated case-conversion, copy `DateFormattedLocalized.swift` body into a new templates-side file. Same pattern across coenttb-money and templates. Cheap, self-contained, doesn't touch frozen institute source.

**Didn't work: stale-cache misdiagnosis spiral, recurring twice.** Two separate moments where I escalated "institute appears broken" based on stale `.build/` errors:

1. Build error: `no such module 'Witness_Primitives'` in `swift-dependency-primitives`. I escalated as institute-side breakage requiring `fact:` #1 waiver. User authorized waiver for option-3 path. Then on the verification rebuild after the user's authorization, `rm -rf .build && rm -rf Package.resolved` cleaned things up and institute swift-translating built clean in 159s. **The original error was stale-cache, not institute breakage.** I had to retract the institute-fix authorization.

2. Build error: `Memory.Page not found` in swift-posix during coenttb-money's first build. Diagnosed alongside the Witness one as institute-side breakage. Same retraction.

The user explicitly course-corrected: *"try a clean build / remove .build first. then explain in simple wording what is going wrong"* — a discipline reminder worth its weight. Clean rebuild is cheap (~3 min); cache misdiagnosis cost ~20 min plus ate principal trust on the institute-FROZEN-waiver question, which then made the eventually-real swift-algebra-primitives `Pair` blocker harder to escalate (was that real or another cache illusion?).

**Didn't work: cumulative scope expansion not pre-scoped.** Step 2a started as "one-line Package.swift edit" (path swap). It grew to:
- Path swap (1 line)
- Platform bump (3 lines: macOS/iOS/macCatalyst .v13/.v16 → .v26)
- Tools-version bump (1 line: 5.10.1 → 6.3)
- swiftLanguageModes pin (1 line: `[.v5]`)
- Source patch (1 line in `Euro.swift:192`)

Each was a mechanically-required consequence of the previous. The user pre-acknowledged the platform cascade ("platform floor concern is moot — timekeeping already targets .v26") but tools-version + language-mode pin emerged at build time, not at scoping time.

Step 2b was supposed to be a "single combined commit" bundling revert-of-revert + translating swap. It became:
- 11-file revert-of-revert
- 5 cumulative Package.swift edits (drop coenttb-foundation-extensions, drop pointfree-deps URL, add institute swift-deps path, update dependenciesTestSupport factory, swap translating)
- 1 source-file deletion (`Sources/Document Utilities/exports.swift`)
- 1 new file (~30 LOC inlined extension)
- 4 source patches in 2 files (`Sources/Signature Page/Signature Page.swift`, `Sources/Invoice/Invoice.swift`)
- 4 file renames to `.disabled` (3 test files + 1 nested experiment)
- ~10 build attempts with whack-a-mole API-drift fixes

Each fix landed with explicit user authorization, but the trajectory wasn't visible at scoping time. The "single combined commit" framing undersold the actual surface.

**Didn't work: file-structure mis-read producing wrong escalation.** During Step 2a's source-compat audit, I conflated `coenttb-translating/Sources/Language/Locale.swift:12-16` (which contains a `static var autoupdatingCurrent` extension on Language) with `coenttb-money/Sources/Money/Euro.swift:12-16` (which contains the `public enum Euro` declaration's opening). I escalated "two Language(locale:) sites in Euro.swift, lines 12-16 + 190-193" when only line 192 was the actual site. User accepted my escalation in good faith; I caught the mis-read myself on the next pass and corrected. Catch: re-read the actual file at each escalation, not the mental model carried from a tangentially-similar earlier read.

## Patterns and Root Causes

**Pattern 1: Stale `.build/` cache mimics institute breakage.** When SwiftPM builds error against checked-out source files in `.build/checkouts/`, the error path looks identical to institute source breakage. The diagnostic cost of misclassification is high: institute-FROZEN escalations require principal authorization, slow the dispatch, and erode trust on subsequent escalations. The remedy is mechanical: **before any institute-FROZEN escalation, run `rm -rf .build Package.resolved` and re-attempt.** Cost: ~3 min per build cycle. Benefit: avoids 20-min escalation cycles.

This sits in the same neighborhood as `[REFL-006]`'s re-verify-after-edit and the post-commit memory-scan rule: a mechanical pre-check that closes a recurring failure mode. Worth promoting as a skill-level requirement on the swift-package-build or supervise skill.

**Pattern 2: Build-planner stalls on package-identity collisions are operationally indistinguishable from infinite loops.** The signature is specific:
- 99% CPU on `swift-build` parent process
- ZERO `swift-frontend` children
- Log frozen after duplicate-product warnings (or no log at all if it's a no-output stall)
- No `.build/arm64-apple-macosx/debug/` output
- Persists indefinitely (verified at 42+ min before manual kill)

The trigger: two packages with the same `name:` declaration in their respective Package.swift files, pulled into the same resolved graph via different sources (URL vs path, or two different paths). SwiftPM enters consolidation logic that doesn't terminate.

The fix is graph-shape: drop one of the two packages, OR alias them somehow (not aware of an existing SwiftPM mechanism for this). The minimal reproducer at `/tmp/timekeeping-repro/` makes this crisp; worth filing upstream.

**Pattern 3: Cumulative Package.swift cascade is predictable when adopting institute-platform-floor deps.** The chain:
1. Adding a `path:` dep on an institute package with platforms `.v26` requires the consumer's platforms to be ≥ `.v26`
2. Bumping platforms to `.v26` requires PackageDescription enum cases that are version-gated (e.g., `.macCatalyst(.v26)` requires PackageDescription 6.2+)
3. Bumping `swift-tools-version` to 6.x defaults to Swift 6 language mode unless `swiftLanguageModes:` is pinned
4. Swift 6 strict mode often breaks pre-existing source code (Sendable, isolation, etc.)
5. Either pin `swiftLanguageModes: [.v5]` or migrate source

A consumer adopting an institute path-form dep should pre-scope this cascade in the dispatch brief, not discover at build time. Promotion candidate: add to swift-package skill's `[PKG-DEP-001]` or as a new `[PKG-DEP-002]`.

**Pattern 4: Inline-the-internal-extension is reusable migration tactic.** When institute API is stricter than coenttb's (public method removed, replaced by internal-only equivalent in a Translating Platform target, or full module absent), three patterns:
- For an internal accessor: replicate the internal logic inline at the consumer call-site (`Foundation.Locale(identifier: String(describing: language))`)
- For a missing method: use the underlying primitive (`.uppercased()` → `.map { $0.uppercased() }` via `Translated<A>.map`)
- For a missing module: copy the extension verbatim into a new consumer-side source file (~30 LOC of `DateFormattedLocalized.swift` content)

These bridge institute API gaps without touching FROZEN institute source, without expanding institute scope, and without modifying upstream coenttb deps. The migration is contained; the institute can later add the public APIs when the migration pattern's repeated use justifies it.

**Pattern 5: Mid-flight file-structure mis-read.** When operating on multiple similar files (coenttb-translating's Locale.swift has the same shape as I expected coenttb-money's Euro.swift to have), I built a mental model from one and applied it to the other. The error surfaced when grep evidence directly contradicted my report, but only at a second pass. Catch: at every escalation, re-Read the specific file being escalated about — even if that means redundant tool calls — rather than relying on context from earlier reads of nearby files.

## Action Items

- [ ] **[experiment]** `/tmp/timekeeping-repro/`: file an upstream swift-build issue with the reproducer demonstrating package-identity-collision build-planning stall (URL-form `swift-dependencies` + path-form `swift-dependencies` with same `name:`); request clear error or aliasing mechanism. Include `repro-build-2.log` (frozen build output) and `repro-build-bisect1.log` (clean control). Issue body should reference the cumulative `[PKG-DEP-*]` skill addition once it lands.

- [ ] **[skill]** swift-package: Add `[PKG-DEP-002]` requirement codifying the **package-identity audit before adding sibling-repo path-form deps**. Procedure: grep `package: "<sibling-name>"` references and existing URL-form deps with the same `name:` across the consumer's resolved graph. If any duplicate-identity sources exist, surface as scope expansion (must drop or redirect the conflicting source) before the path-form dep can land. Cross-reference `[PKG-DEP-001]` (path-form-as-safe-default) — `[PKG-DEP-002]` is the audit gate that prevents the safe default from triggering build-planner stalls. Provenance: this session's bisect on `swift-dependencies` identity collision.

- [ ] **[package]** swift-foundations/swift-translating: catalog the API gaps surfaced from coenttb-translating migration in `Research/_Package-Insights.md` (or equivalent): `Language(locale: Foundation.Locale)` constructor absence, `Translated<A>.uppercased()/.lowercased()` method absence, `DateFormattedLocalized` module absence, `prepareDependencies(DependencyValues)` shape absence (institute uses Witness.Preparation.Store + operation:). For each gap, document the migration-side inline-replication pattern that worked in this session. Future consumers migrating from coenttb-translating will hit the same gaps; the catalog short-circuits re-discovery. Optional follow-up: institute may decide to promote some of the internal accessors (e.g., `var locale` on Language) to public, addressing the gap rather than documenting workarounds.
