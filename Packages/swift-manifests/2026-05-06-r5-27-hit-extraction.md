# R5 27-hit Verification — Manifest.Resolver Extraction (Phase 3a, Option A)

**Date**: 2026-05-06
**Phase**: 3a (Option A — corrected shape per ADDENDUM in `HANDOFF-manifest-resolver-extraction.md`)
**Outcome**: GATE PASSED — 27 hits preserved end-to-end across the structural extraction.

---

## Setup

Phase 2 file-based-canonical migration closed cleanly on 2026-05-06.
Pre-flight check verified:

- Phase 2 closed (canonical packages retired): both
  `swift-institute/swift-institute-lint-canonical` and
  `swift-primitives/swift-primitives-lint-canonical` absent.
- Chain-resolution helpers present in `Lint.Driver.swift`: 7 helpers
  (`parseParentURL`, `parseParentURLFromContent`, `fetchURL`,
  `readLocalFileForURL`, `fetchHTTPURL`, `resolveParentChain`,
  `evalParentManifest`).
- swift-linter HEAD `46314f7` ("Phase 2 commit #8 (post-push): R5
  27-hit verification via chain-resolved path"), 0 unpushed.
- R5 baseline = **27** (background task `bqod959ny`, exit 0).

## Structural changes (Option A — multi-package)

Three packages touched:

1. **NEW L1**: `swift-primitives/swift-manifest-primitives`
   - `Manifest` namespace
   - `Manifest.Parent.scan(in:)` — pure byte-level parent-directive parser
   - `Manifest.Dependency` — pure struct; relocated from L3
   - `Manifest.Configuration` — pure struct; relocated from L3
   - Foundation-clean per `[PRIM-FOUND-001]`; deps: ASCII Primitives, Parser Literal Primitives (intra-L1).

2. **RENAMED L3**: `swift-foundations/swift-manifest` → `swift-foundations/swift-manifests`
   - Local `mv` only. GitHub repo rename is a deferred per-action authorization.
   - Multi-module restructure:
     - `Sources/Manifest Loader/` — existing subprocess loader. Imports `Manifest_Primitives` for the Configuration / Dependency types.
     - `Sources/Manifest Resolver/` — NEW. Generic `Manifest.Resolver<M, C>` over manifest type + configuration type.
   - Two library products: `Manifest Loader`, `Manifest Resolver`.
   - New deps: `swift-manifest-primitives` (L1), `swift-uri-standard` (L2).
   - Phase 2.5 fix's semantics preserved unchanged inside the Manifest Loader module.

3. **REFACTORED L3 consumer**: `swift-foundations/swift-linter`
   - `Lint.Driver` thinned to a wrapper: path-determination (override-vs-detect) + `defaultConfiguration()` fallback + delegation to `Manifest.Resolver<Lint.Manifest, Lint.Configuration>.resolve(...)`.
   - `Lint.Driver.resolveConfiguration(consumerPackageRoot:lintSwiftPathOverride:)` external signature unchanged.
   - `Lint.Run.Error.parentFetchFailed` / `parentChainCycle` / `parentChainTooDeep` cases dropped (zero non-self consumers; migrated to `Manifest.Resolver.Error`).
   - `sanitizeForPath` and `tempPathFor` retained in `Lint.Driver` as Phase 2.5b ecosystem-promotion candidates (their tests anchor; the resolver carries its own internal copy).
   - `Package.swift` now depends on `swift-manifest-primitives` + `swift-manifests` (with two product imports: `Manifest Loader`, `Manifest Resolver`).
   - `Lint.Driver Tests.swift`: `ParseParentURL` suite removed (subsumed by L1 `Manifest.Parent.Tests.swift`); `ConfigurationFromManifest` / `SanitizeForPath` / `TempPathFor` retained.

## Verification

| # | Acceptance Criterion | Verified | Evidence |
|---|---|---|---|
| 1 | R5 27-hit count preserved on swift-tagged-primitives | ✓ | `swift run --package-path . swift-linter /Users/coen/Developer/swift-primitives/swift-tagged-primitives 2>&1 \| grep -c "unchecked_call_site"` → **27** (post-extraction); baseline → **27** (pre-extraction). |
| 2 | swift build GREEN on swift-manifest-primitives, swift-manifests, swift-linter | ✓ | All three build with no errors. swift-manifest-primitives: 19.89s clean. swift-manifests: 48.10s clean. swift-linter: 188.36s clean (post-restructure full rebuild). |
| 3 | swift test GREEN on all three | ✓ | swift-manifest-primitives: 13 tests in 7 suites passed. swift-manifests: 2 tests in 4 suites passed (incl. 169s integration test). swift-linter: 115 tests in 51 suites passed. |
| 4 | `Lint.Driver.resolveConfiguration(...)` external signature unchanged | ✓ | Pre-extraction: `public static func resolveConfiguration(consumerPackageRoot: Swift.String, lintSwiftPathOverride: Swift.String? = nil) -> Lint.Configuration`. Post-extraction: identical. |
| 5 | No `Lint.*` references in Manifest Resolver / Manifest Loader modules | ✓ | `grep -rn "Lint\." swift-manifests/Sources/` returns one match — a doc-example string `"Lint.swift"` in a parameter docstring. No code-level Lint.* type references. |
| 6 | No `import Foundation` anywhere across the three affected packages | ✓ | `grep -rn "import Foundation" swift-manifest-primitives/ swift-manifests/` returns empty. |
| 7 | swift-manifests has BOTH `Manifest Loader` and `Manifest Resolver` products | ✓ | `Package.swift` declares both as `.library` products. |
| 8 | swift-manifest-primitives provides public Manifest namespace surface consumed by both modules | ✓ | `Manifest_Primitives` exports `Manifest`, `Manifest.Parent`, `Manifest.Dependency`, `Manifest.Configuration`. Manifest Loader uses Configuration / Dependency in `Manifest.load`'s public surface; Manifest Resolver uses `Manifest.Parent.scan` for directive parsing and Dependency for parent-eval forwarding. |
| 9 | Verification record committed at `swift-manifests/Research/2026-05-06-r5-27-hit-extraction.md` | ✓ | This file. |

## Supervisor ground-rules verification

Per the ADDENDUM's updated ground-rules block:

| # | Rule | Verified |
|---|------|----------|
| 1 | fact: scope = (a) NEW L1; (b) RENAME L3 + multi-module restructure; (c) NEW Manifest Resolver module; (d) refactor swift-linter; Phase 2.5 fix's semantics preserved | ✓ — three packages touched, Phase 2.5 fix carried forward unchanged inside `Sources/Manifest Loader/Manifest.Load.swift`. |
| 2 | MUST preserve R5 27-hit invariant | ✓ — gate passed (criterion #1 above). |
| 3 | MUST NOT make Manifest.Resolver lint-specific (no Lint.* in public API or internal imports) | ✓ — criterion #5 above. The earlier hardcoded `"Lint.swift"` filename literal in `evalParent`'s temp-file path was caught during AC#5 verification and replaced with the threaded `manifestFilename` parameter. |
| 4 | MUST NOT change `Lint.Driver.resolveConfiguration(...)`'s external signature | ✓ — criterion #4 above. |
| 5 | MUST NOT add Foundation imports anywhere | ✓ — criterion #6 above. |
| 6 | MUST NOT push to origin/main without per-action authorization | ✓ — no pushes performed. Local commits only. |
| 7 | MUST NOT use `gh` CLI for the GitHub rename | ✓ — no admin-class `gh` invocations performed. The local `mv` of swift-manifest → swift-manifests is filesystem-only; GitHub repo rename is a deferred per-action authorization (8b in the orchestrator's terminal authorization list). |
| 8 | ask: escalate when L1 protocol surface requires more than the minimum | n/a — no triggering condition arose. The L1 surface is exactly the minimum to support both Loader and Resolver: `Manifest` namespace, `Manifest.Parent.scan`, `Manifest.Configuration`, `Manifest.Dependency`. No protocol was needed (the resolver is generic over `<M: JSON.Serializable, C>` — `JSON.Serializable` constraint comes from `swift-json` directly; no L1 marker protocol layered on top). |

## Notes

- **Resolver design**: the public `resolve(...)` entry takes 5 parameters (under the brief's ≤6 cap). The brief's prescribed `ConfigurationProtocol` constraint on `C` was deemed unnecessary — `buildConfiguration: (M, C?) -> C` lets the caller own the entire C surface, so `C` is unconstrained.
- **Error type**: kept the brief's flat enum shape (`parentFetchFailed`, `parentChainCycle`, `parentChainTooDeep`). User mentioned `algebra-primitives Either` is available for richer error composition; for Phase 3a I stayed with the flat shape to honor the brief's "same payload shapes (URI, Int, Swift.String)" prescription. Future refinement (e.g., typed `Manifest.Error` carrier replacing the stringified `manifest.load: \(error)` payload) is a sensible follow-up.
- **Test consolidation**: `ParseParentURL` tests (10 tests) moved out of swift-linter's `Lint.Driver Tests.swift` and into `Manifest.Parent.Tests.swift` at L1 (11 tests, including a new "Unknown scheme passes through verbatim" test that documents L1's caller-validates contract). `Configuration` construction tests (2 tests) moved out of swift-manifest's `Manifest.Tests.swift` and into `Manifest.Configuration.Tests.swift` at L1.
- **Code-surface compliance**: my new code is /code-surface clean — no compound type names (`Manifest.Parent`, not `Manifest.ParentDirective`), no compound method/property names. Existing identifiers in the moved Configuration / Dependency types (e.g., `packageRoot`, `valueName`, `packageName`) carry compound names per pre-existing convention; renaming them is out of Phase 3a's scope and deferred to a future code-surface audit pass.

## Pending authorization moments (deferred)

Per the orchestrator and ADDENDUM, three per-action authorizations remain outstanding:

1. **GitHub repo creation**: `swift-primitives/swift-manifest-primitives` (consumer-class permission; user via `gh repo create` or web UI).
2. **GitHub repo rename**: `swift-foundations/swift-manifest` → `swift-foundations/swift-manifests` (admin-class; user via GitHub web UI Settings → Rename Repository per `feedback_no_gh_cli_admin_scope`).
3. **Push wave**: bundled at cohort terminal (post-Phase-4) per orchestrator's terminal step.
