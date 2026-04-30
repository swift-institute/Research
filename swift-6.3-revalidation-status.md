---
title: Swift 6.3 Corpus Revalidation Status
version: 1.1.0
status: RECOMMENDATION
tier: 2
created: 2026-04-14
last_updated: 2026-04-30
applies_to:
  - swift-primitives
  - swift-standards
  - swift-foundations
  - swift-institute
---

# Context

This document captures the outcome of the corpus-wide revalidation sweep against Swift 6.3, now the baseline toolchain for the Swift Institute ecosystem. Per [META-006] (toolchain revalidation trigger), a new compiler baseline requires re-running findings that are tied to compiler bugs, workarounds, or experimental features to determine which remain valid, which are now obsolete, and which have new regressions. Swift 6.3 shipped with several fixes that retire long-standing workarounds in our corpus, while introducing (or exposing) new regressions in 6.4-dev nightly builds that affect our dual-compiler compatibility goals.

## Update Log

- **v1.0.0 (2026-04-14)**: Initial recommendation reflecting the 04-14 sweep against Swift 6.3.
- **v1.1.0 (2026-04-30)**: Phase 7a follow-up sweep against Swift 6.3.1 (`swiftlang-6.3.1.1.2`, Xcode 26.4.1 default). 315 additional experiments stamped (215 first pass + 32 anchor-add per [EXP-007a] + 68 third-pass drift-triage/SUPERSEDED-confirmation). 5 EarlyPerfInliner reproducers across 4 packages now confirmed (4 from this sweep, 1 from 04-21 baseline). 2 #86652 LLVM VerifierPass reproducers added. No fix-status flips since the 2026-04-17 prior sweep. Audit: `swift-institute/Audits/swift-6.3.1-revalidation-sweep-2026-04-30.md`.

# Scope

The revalidation sweep covers 290 experiments across four repositories: `swift-primitives`, `swift-standards`, `swift-foundations`, and `swift-institute`. Focus was placed on HIGH priority items with direct ties to compiler bugs or documented workarounds — specifically experiments annotated with `@_optimize(none)`, `_deinitWorkaround`, experimental feature flags, or cross-references to upstream Swift issues. Items validated solely against stable language features (no workaround, no experimental flag) were sampled rather than exhaustively re-run.

# Known Fixed in Swift 6.3

| Bug | Upstream ID | Previous workaround | Status |
|-----|-------------|---------------------|--------|
| CopyPropagation ~Escapable coroutine yield crash | swiftlang/swift#88022 | @_optimize(none) on 149 sites | Removed — Property.View types re-added ~Escapable + @_lifetime(borrow) |
| SIL CopyPropagation crash on ~Copyable enum switch consume | swiftlang/swift#85743 | @_optimize(none) on ~8 functions | Removal blocked until Xcode ships Swift 6.4+ |
| InoutLifetimeDependence experimental feature | SE-0452 baseline | .enableExperimentalFeature("InoutLifetimeDependence") | Removable from Package.swift |
| LifetimeDependenceMutableAccessors | Features.def baseline | .enableExperimentalFeature(...) | Removable |
| NonescapableTypes baseline | SE-0446 | (already baseline) | N/A |
| LayoutPrespecialization | Features.def | (already baseline) | N/A |

# Known Still Broken in Swift 6.3

| Bug | Upstream ID | Workaround | Affected Experiments |
|-----|-------------|------------|---------------------|
| @_rawLayout element destruction LLVM IR domination | swiftlang/swift#86652 | _deinitWorkaround: AnyObject? + field-ordering | rawlayout-llvm-verifier-crash, rawlayout-access-level-trigger, rawlayout-deinit-alternatives, rawlayout-minimal-reproducer, noncopyable-nested-deinit-chain, 36 inline storage types across 9 packages |
| WMO + CopyToBorrowOptimization miscompiles actor enum state | Not filed upstream | Removed Mutex<Token?> from IO.Event.Selector.Scope (commit 6dad19ba, 2026-04-13) OR global -sil-disable-pass=copy-to-borrow-optimization | 3 swift-io shutdown tests depend on this; standalone reproducer at swift-institute/Experiments/copytoborrow-actor-state-mutex-miscompile (~99/100 BUG iterations on 6.3.1) |
| CopyPropagation try_apply borrow scope shortening | Not filed upstream | Replace do/catch with try? on ~Copyable Channel access | swift-io full build only (no standalone repro) |
| SIL CopyPropagation crash on ~Copyable enum switch consume | swiftlang/swift#85743 | @_optimize(none) on ~8 functions | swift-institute/Experiments/copypropagation-noncopyable-switch-consume (still crashes MoveOnlyChecker pass #214 on 6.3.1; fix not in 6.3.1 cherry-pick set) |
| SendNonSendable SILFunctionTransform abort on cross-module ~Copyable/~Escapable borrowing init inside IIFE | Not filed upstream | Bind view at outer function scope | swift-institute/Experiments/sendnonsendable-iife-borrowing-init-crash (10-line cross-module reducer, signal 6 in SendNonSendable::run()) |
| SIL EarlyPerfInliner crash on cross-module `~Copyable` value-type yield through `_read` coroutine | Not filed upstream | `@_optimize(none)` on the affected accessor; or keep class-based State (Option A) | 5 reproducers across 4 packages: swift-property-primitives/Experiments/{property-consuming-value-state, language-semantic-property-replacement, language-semantic-property-typed-replacement}, swift-render-primitives/Experiments/body-getter-stack-overflow, swift-pdf/Experiments/result-builder-stack-overflow. All crash in SILPerformanceInlinerPass::run(). |

# Swift 6.4-dev Regressions

| Regression | Manifests When | Workaround | Blocker |
|------------|---------------|------------|---------|
| @_lifetime rejection on Escapable returns | 6.4-dev only | Removed @_lifetime(self:) from ~25 functions | Dual-compiler incompatible with 6.2.4 requirement |
| Closure IRGen crash on identity closures | 6.4-dev + complex contexts | Named static function references | Affects typed-throws closure patterns |
| DeinitDevirtualizer SIL assertion | 6.4-dev release builds | None — blocks 6.4-dev goal | Requires compiler fix |
| Static property resolution in protocol extensions | 6.4-dev + Property.View | Inline Ordering.Comparator instead of .ascending | 2 package updates |
| Optional.take sending RegionIsolation | 6.4-dev only (6.3 passes) | Split into Sendable/non-Sendable overloads | Regression: compiler can no longer prove consume self disconnects from caller region for non-Sendable |

# Experiments Updated in This Sweep

- rawlayout-llvm-verifier-crash
- rawlayout-access-level-trigger
- rawlayout-deinit-alternatives
- noncopyable-nested-deinit-chain
- copypropagation-nonescapable-yield
- copypropagation-noncopyable-enum-consume
- copytoborrow-actor-enum-state
- inout-lifetime-dependence-baseline
- lifetime-dependence-mutable-accessors
- nonescapable-types-baseline
- layout-prespecialization-baseline
- property-view-reescapable-relift
- channel-trycatch-borrow-scope
- lifetime-escapable-return-6.4-dev
- closure-irgen-identity-6.4-dev
- deinit-devirtualizer-sil-assertion
- static-property-protocol-extension-6.4-dev
- optional-take-sending-region-isolation

(Details of each update recorded in the experiment's `main.swift` header comment.)

# Implications for Blog Pipeline

- **BLOG-IDEA-033 (rawlayout deinit saga)**: Main #86652 bug STILL BROKEN — post narrative needs clarification. #88022 IS fixed — alternative narrative angle.
- **BLOG-IDEA-041 (WMO + CopyToBorrow)**: Still present in 6.3. Post angle intact.
- **BLOG-IDEA-048 (Storage.Inline Bottom-Up Deinit)**: Depends on #86652 which is still broken — post angle intact.
- **BLOG-IDEA-049 (Parameter Pack Concrete Extensions)**: Limitation persists per memory file — post remains valid.
- **BLOG-IDEA-051 (Upgrading 1,390 Packages to 6.3)** from revalidation task: this doc IS the research basis — ready for drafting.

# Next Actions

1. Remove `@_optimize(none)` annotations on 149 sites tied to #88022 now that fix is in 6.3 baseline.
2. Remove experimental feature flags from `Package.swift` files (`InoutLifetimeDependence`, `LifetimeDependenceMutableAccessors`).
3. Monitor upstream for #86652 fix landing — maintain `_deinitWorkaround` pattern until then.
4. Track 6.4-dev stabilization path — some regressions must be fixed before 6.4 ships.

# Phase 7a Sweep Outcomes (2026-04-30)

The Phase 7a sweep extended coverage from the 04-17 baseline. Toolchain unchanged (Swift 6.3.1 `swiftlang-6.3.1.1.2`); the goal was to close the residual gap (experiments authored after 04-17 plus older experiments missed in the prior sweep).

**Final corpus state**: 435/440 experiments now stamped with a `// Revalidated: Swift 6.3.1 (YYYY-MM-DD)` line (120 from 04-17 + 315 from 04-30). 5 ANCHORLESS package-level configs remain (Package.swift-only or multi-package probe packages where source-level anchors don't apply).

**Verdict distribution across the 315 newly-stamped experiments**:

| Verdict | Count | Notes |
|---------|-------|-------|
| PASSES | ~219 | Clean release build (dominant bucket) |
| STILL PRESENT | ~19 | Lifetime-tightening on Escapable target/result; documented per memory |
| STILL CRASHES | ~10 | EarlyPerfInliner (5 sites) + #85743 + SendNonSendable IIFE + #86652 (2 sites) |
| SUPERSEDED | ~67 | 32 confirmation-of-existing + ~35 drift-triage |
| FIXED | 0 | (Tagged.modify already FIXED on 04-17; no new flips on 04-30) |

**No status flips since 04-17** — every previously-broken bug remains broken; the previously-fixed bug remains fixed. The toolchain didn't change, so no flips are expected.

**API-drift triage outcome**: 36 UNEXPECTED_FAIL cases triaged into 2 fixed (mechanical Storage<Element> migration + `swift package resolve`), 1 stamped STILL CRASHES (5th EarlyPerfInliner reproducer), 31 marked SUPERSEDED with cluster-specific notes. Notable clusters needing later per-package re-authoring: Storage<Element> generic migration (3 experiments), Sequence/Collection protocol restructure (5 experiments), Tagged Ordinal→Affine.Discrete.Vector migration (1 experiment), Index.Bounded / Array.Unbounded namespace removals (2 experiments).

**NOPRIMARY cleanup**: 15 empty post-consolidation residue directories deleted (8 in `swift-storage-primitives/Experiments/`, 6 in `swift-buffer-primitives/Experiments/`, 1 SUPERSEDED.md redirect in `swift-effect-primitives/Experiments/noncopyable-optional-capture-crash/`).

**[EXP-007a] anchor-add round**: 31 previously-anchorless experiments received header anchors (`// Toolchain:` + `// Revalidated:` lines prepended) so future sweeps can stamp them mechanically. The remaining 5 ANCHORLESS are package-level configurations.

**`_index.json` sync**: ~33 experiments' status fields updated to `SUPERSEDED` to surface their state in the canonical catalog per [EXP-003e]. 2 new `_index.json` files created (`swift-queue-primitives`, `swift-rfc-8259`) and 1 legacy `_index.md` removed (`swift-rfc-8259`).

# Cross-References

- `Research/swift-6.3-ecosystem-opportunities.md` — comprehensive 6.3 feature catalog (per-package audit)
- `Research/noncopyable-ecosystem-state.md` — consolidated ~Copyable state
- `Research/compiler-pr-copypropagation-mark-dependence-handoff.md` — #88022 root cause
- `Audits/swift-6.3.1-revalidation-sweep-2026-04-30.md` — Phase 7a sweep audit (full per-cluster receipts)
- Memory: `swift-6.3-fix-status.md` (canonical fix-status surface), `copypropagation-nonescapable-fix.md`, `noncopyable-deinit-workaround.md`, `copytoborrow-actor-state-barrier.md`
- Reflections: `2026-04-17-swift-6-3-1-experiment-revalidation.md`, `2026-04-17-swift-6-3-1-corpus-completion-and-drift-relocation.md`, `2026-03-22-copypropagation-nonescapable-root-cause-and-fix.md`, `2026-03-22-rawlayout-deinit-compiler-fix.md`, `2026-03-31-copypropagation-noncopyable-enum-already-fixed.md`, `2026-03-22-swift-64-dev-compatibility-and-dual-compiler-discovery.md`
