---
title: Swift 6.3 Corpus Revalidation Status
version: 1.0.0
status: RECOMMENDATION
tier: 2
created: 2026-04-14
last_updated: 2026-04-14
applies_to:
  - swift-primitives
  - swift-standards
  - swift-foundations
  - swift-institute
---

# Context

This document captures the outcome of the corpus-wide revalidation sweep against Swift 6.3, now the baseline toolchain for the Swift Institute ecosystem. Per [META-006] (toolchain revalidation trigger), a new compiler baseline requires re-running findings that are tied to compiler bugs, workarounds, or experimental features to determine which remain valid, which are now obsolete, and which have new regressions. Swift 6.3 shipped with several fixes that retire long-standing workarounds in our corpus, while introducing (or exposing) new regressions in 6.4-dev nightly builds that affect our dual-compiler compatibility goals.

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
| @_rawLayout element destruction LLVM IR domination | swiftlang/swift#86652 | _deinitWorkaround: AnyObject? + field-ordering | rawlayout-llvm-verifier-crash, rawlayout-access-level-trigger, rawlayout-deinit-alternatives, noncopyable-nested-deinit-chain, 36 inline storage types across 9 packages |
| WMO + CopyToBorrowOptimization miscompiles actor enum state | Not filed upstream | Removed Mutex<Token?> from IO.Event.Selector.Scope (commit 6dad19ba, 2026-04-13) OR global -sil-disable-pass=copy-to-borrow-optimization | 3 swift-io shutdown tests depend on this |
| CopyPropagation try_apply borrow scope shortening | Not filed upstream | Replace do/catch with try? on ~Copyable Channel access | swift-io full build only (no standalone repro) |

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

# Cross-References

- `Research/swift-6.3-ecosystem-opportunities.md` — comprehensive 6.3 feature catalog (per-package audit)
- `Research/noncopyable-ecosystem-state.md` — consolidated ~Copyable state
- `Research/compiler-pr-copypropagation-mark-dependence-handoff.md` — #88022 root cause
- Memory: `copypropagation-nonescapable-fix.md`, `noncopyable-deinit-workaround.md`, `copytoborrow-actor-state-barrier.md`
- Reflections: `2026-03-22-copypropagation-nonescapable-root-cause-and-fix.md`, `2026-03-22-rawlayout-deinit-compiler-fix.md`, `2026-03-31-copypropagation-noncopyable-enum-already-fixed.md`, `2026-03-22-swift-64-dev-compatibility-and-dual-compiler-discovery.md`
