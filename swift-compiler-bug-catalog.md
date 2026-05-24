---
title: Swift Compiler Bug Catalog
tier: 2
scope: cross-package
status: REFERENCE
created: 2026-05-10
last_reviewed: 2026-05-24
last_verified: 2026-05-24
toolchains:
  - Swift 6.3.1 (Xcode 26.4.1, swiftlang-6.3.1.1.2)
  - Swift 6.3.2 (swiftlang-6.3.2.1.108, SDK MacOSX26.5) — § A11
  - Swift 6.4-dev nightly
---

# Swift Compiler Bug Catalog

Verified Swift compiler bugs, language-feature pitfalls, and recommended workarounds. Cross-package reference: applies to every package's Swift code in this ecosystem. CONSULT before designing around an apparent compiler limitation, per `[ISSUE-028]`.

The catalog is organized in three layers:

1. **Master fix-status table** — which bugs are fixed/broken/regressed across the supported toolchains, with upstream IDs and verification anchors. Read this first.
2. **Table of contents** — one row per per-entry section below; scan-fast index by symptom.
3. **Per-entry sections** — full diagnosis, workaround, evidence, and provenance for each bug or pattern.

The catalog is a Tier 2 cross-package REFERENCE doc per `[RES-020]`. It supersedes the prior `swift-6.3-fix-status.md` "CANONICAL REFERENCE" framing — that doc's content is absorbed below as the master fix-status table.

---

## Master Fix-Status Table

**As of 2026-04-30** (Phase 7a follow-up sweep stamped ~315 experiments; all 5 strategic STILL-PRESENT bug reproducers re-confirmed). Latest baseline: Xcode 26.4.1 ships Swift 6.3.1 (`swiftlang-6.3.1.1.2`) as the default toolchain; 6.3.1 is a point release dominated by stack-nesting fixes for async/concurrency runtime builtins; no language-surface changes. Canonical revalidation document: `swift-institute/Research/swift-6.3-revalidation-status.md`.

Verification anchor: 215 first-pass + 32 anchor-add second pass per `[EXP-007a]` + 68 third-pass drift-triage / SUPERSEDED-confirmation = 315/440 stamped 2026-04-30 + 120/440 from 2026-04-17 = **435/440 covered** (5 ANCHORLESS package-level configs remain). Audit: `swift-institute/Audits/swift-6.3.1-revalidation-sweep-2026-04-30.md`.

### Fixed in 6.3 (workarounds removable) — confirmed still fixed on 6.3.1

| Bug | Upstream ID | Previous workaround | Status |
|-----|-------------|---------------------|--------|
| CopyPropagation ~Escapable coroutine yield crash | `swiftlang/swift#88022` | `@_optimize(none)` on 149 sites | Removed — Property.View types re-added ~Escapable + `@_lifetime(borrow)` (see § A2) |
| InoutLifetimeDependence | SE-0452 baseline | `.enableExperimentalFeature` | Removable from `Package.swift` |
| LifetimeDependenceMutableAccessors | `Features.def` baseline | `.enableExperimentalFeature` | Removable |
| Expression-level `unsafe` on `for-in` over `[UnsafeMutablePointer<T>]` release-mode SIL crash | Not filed | Index-based loop replacement | `Experiments/unsafe-forin-release-crash` builds clean on 6.3.1 release+StrictMemorySafety; the documented Signal 6 no longer reproduces. Workaround unnecessary. |
| SwiftPM "dynamic libraries for unknown os" crash on visionOS build with macro deps | Not filed | None (was a crash) | `Experiments/swiftpm-visionos-implicit-platform/v3-with-deps` builds clean on 6.3.1; the documented SwiftPM crash with `swift-dependencies` macro deps no longer reproduces. |
| Tagged.modify ~Escapable inout closure-parameter-lifetime gap | Not filed | `RawValue: ~Copyable & Escapable` scope on the extension | `swift-tagged-primitives/Experiments/tagged-modify-escapable-revalidation` builds + runs clean on 6.3.1; minimal Variant 2 (`~Escapable RawValue` + `inout RawValue` closure) compiles. Production `modify` widened to `RawValue: ~Copyable & ~Escapable` in swift-tagged-primitives pre-0.1.0 work 2026-04-24; 59/59 tests still pass. |
| Synthesized Equatable on nested type with constraint extension on `~Copyable` Outer (RandomAccessCollection conformance + nested Storage class) | Not filed | None (was a crash) | `swift-array-primitives/Experiments/equatable-crash` builds clean on 6.3.1 (debug + release); `swift run` outputs "SUCCESS: Equatable and Hashable conformances work". Original 2026-01-23 hypothesis no longer reproduces. Revalidated 2026-04-30 per Phase 1b stale-triage. |
| SIL synthesis on `extension Container<Marker>.Outer.Bounded: Equatable {}` (nested type in conditional extension of `~Copyable` enum) | Not filed | None (was a crash) | `swift-set-primitives/Experiments/bit-packed-crash` typechecks + emits-module + emits-SIL `-O` clean on 6.3.1 (1090 lines SIL, no `__derived_struct_equals` crash, no "ambiguous use of operator '=='" diagnostic). Original 2026-01-23 hypothesis no longer reproduces. Revalidated 2026-04-30 per Phase 1b stale-triage; package layout fixed (Sources/Lib/main.swift renamed to BitPackedCrash.swift). |

### Still Broken on 6.3.1 (empirically verified 2026-04-30)

| Bug | Upstream ID | Workaround | Evidence |
|-----|-------------|------------|----------|
| SIL CopyPropagation crash on ~Copyable enum switch consume | `swiftlang/swift#85743` | `@_optimize(none)` on ~8 functions | `Experiments/copypropagation-noncopyable-switch-consume` crashes MoveOnlyChecker pass #214 on 6.3.1. Earlier claim ("fix in compiler, waiting on Xcode") was incorrect — the fix was NOT in 6.3.1's cherry-pick set. |
| `@_rawLayout` element destruction LLVM IR domination | `swiftlang/swift#86652` | `_deinitWorkaround: AnyObject?` + field-ordering | 36 inline storage types across 9 packages |
| WMO + CopyToBorrowOptimization miscompiles actor enum state | Not filed | Removed `Mutex<Token?>` from `IO.Event.Selector.Scope` (commit `6dad19ba`) OR `-sil-disable-pass=copy-to-borrow-optimization` | Standalone 87-line repro at `Experiments/copytoborrow-actor-state-mutex-miscompile/` still fails 100/100 on 6.3.1. See § A6. |
| SendNonSendable SILFunctionTransform abort on cross-module ~Copyable/~Escapable borrowing init inside IIFE | Not filed | Bind the view at the outer function scope — do NOT wrap construction in `_ = { _ = View(base) }()` | `swift-institute/Experiments/sendnonsendable-iife-borrowing-init-crash/` — 10-line cross-module reducer aborts `swift build` with signal 6 in `SendNonSendable::run()`. Surfaced 2026-04-21 during swift-property-primitives test coverage work. |
| CopyPropagation try_apply borrow scope shortening | Not filed | Replace `do/catch` with `try?` on ~Copyable access | swift-io full release build clean on 6.3.1 — workaround still in place, bug presence not independently verified. See § A5. |
| SIL EarlyPerfInliner crash on ~Copyable value-type yield through `_read` coroutine ("Cannot initialize a nonCopyable type with a guaranteed value") | Not filed | `@_optimize(none)` on any accessor whose `_read` yields a cross-module ~Copyable value-type. swift-property-primitives DID NOT adopt Option C (value-type State) because the workaround would distribute to every consumer accessor site — ergonomics too hostile for a published API. Kept Option A (conditional `@unchecked Sendable` on the class-based State). Revisit Option C when this crash is fixed upstream. | Primary reproducer: `swift-property-primitives/Experiments/property-consuming-value-state/` crashes on `swift build -c release` at SILPerformanceInlinerPass. Additional reproducers surfaced during 2026-04-30 Phase 7a sweep — same crash signature: `swift-property-primitives/Experiments/language-semantic-property-typed-replacement`, `swift-property-primitives/Experiments/language-semantic-property-replacement`, `swift-render-primitives/Experiments/body-getter-stack-overflow`, `swift-pdf/Experiments/result-builder-stack-overflow`. All five crash in the same pass; the bug is broader than originally scoped (any cross-module ~Copyable value-type yield through `_read`). Companion perf benchmark `swift-property-primitives/Experiments/property-consuming-state-allocation-benchmark` showed no runtime upside for Option C. Revalidate by rebuilding any of the four experiments `-c release` — when they stop crashing, Option C becomes viable. |
| Constrained-extension nested-type lookup ignores where-clause | Not filed (gap candidate for SE-discussion) | At ecosystem scale, do NOT use `extension Tagged where Tag == X, RawValue == Y { typealias Foo = ... }` as a layer-discrimination pattern when other libraries declare same-name nested typealiases on disjoint Tagged instantiations. Use fresh nominal types at L3 (`Path β` shape) instead of `Tagged<L3-Tag, L2-Type>` variants. Plain typealias chains still fine where no L3 policy substance applies. | `swift-institute/Experiments/tagged-cross-instantiation-nested-type-ambiguity/` — 4-target minimal repro, CONFIRMED 2026-05-02 on Apple Swift 6.3.1. See § B3. |
| Unconditional protocol-conformance extension on a `~Copyable`-generic nested type leaks `Element: Copyable` constraint back to the primary declaration | Not filed | **Workaround D** — add `where Element: ~Copyable` to the conformance extension. One-line fix: `extension Storage.Inline: SomeProtocol { … }` → `extension Storage.Inline: SomeProtocol where Element: ~Copyable { … }`. The constraint is INCLUSIVE (allows both Copyable and ~Copyable Element); no body change. | `swift-institute/Issues/swift-issue-rawlayout-noncopyable-extension-rejection/` — 17-variant variable-isolation table; minimum reproducer is single-module / single-file / 13 lines / no `@_rawLayout` / no `deinit` / no `let-capacity`. Production blocker: swift-storage-primitives@ee86ee0 `Storage Inline Primitives` target (Cohort III Pilot 1 [MOD-031] restructure). See § A10. |
### Fixed upstream on 6.4-dev nightly-main (awaiting backport or 6.4 release)

| Bug | Upstream ID | Workaround for shipped 6.3.x | Evidence |
|-----|-------------|------------------------------|----------|
| Array-literal storage + chained `index_addr` `+M, −N` with compile-time-constant offsets miscompiles under `-O` / `-Osize` (macOS arm64 + Linux x86_64). DSE eliminates the live stores at intermediate array-literal indices, so the chained load reads uninitialized storage. | [`swiftlang/swift#77558`](https://github.com/swiftlang/swift/issues/77558) (existing upstream report from 2024-11-12). Confirmation [comment](https://github.com/swiftlang/swift/issues/77558#issuecomment-4425028051) posted 2026-05-11 under `coenttb` (empirical narrowing: SwiftPM-test-runner-path firing on `swift:6.3-jammy`; bare `swiftc -O` does not reproduce on current 6.3.x distributions; fix-detection harness flips red on `nightly-main-jammy`). | Subscript `buf[i]` OR single positive `.advanced(by:)` OR use `Array(repeating:count:)` instead of literal init. Narrower trigger than initially scoped — does NOT bug with non-literal init, ARC-bearing elements, parameterized offsets, or manual `UnsafeMutableBufferPointer.allocate`. See `swift-affine-primitives/Research/swift-issue-pointer-arithmetic-workaround.md`. | 8-line standalone `swiftc -O` reproducer at `swift-institute/Issues/swift-issue-pointer-arithmetic-linux-miscompile/`. SIL byte-identical between with/without `unsafe` keyword. Optimized SIL keeps only stores at offsets 0 and 4 of the 5-element literal; chained `index_addr +4, −2` reads from offset 2 (eliminated). Linux `-Osize` per-run variance is uninitialized-memory signature. **Fixed on `swiftlang/swift:nightly-main` (Swift 6.4-dev, commit `82b7720768ba875`).** Candidate fix-commits (2025-10-10 quad): `1cbed39f326` (COWOpts), `de557cab56f` (ArrayCountPropagation), `71381fab3c0` (ConstExpr), `02fafc63d67` (ForEachLoopUnroll) — all "Optimizer: support the new array literal initialization pattern". Investigation arc with false trails (.Lifetimes, `unsafe` keyword, operator wrapping — all ruled out) at `swift-institute/Issues/swift-issue-pointer-arithmetic-linux-miscompile/INVESTIGATION-ARC.md`. |
| Parameterized-typealias + Base-constrained extension on a generic type in an imported module's scope triggers "failed to produce diagnostic for expression" ICE during test-target compilation of files that contain parameterized-protocol opaque-return type declarations (`var body: some P<TypeParam, Output, Error> { ... }`). Both `public typealias X = Generic<Concrete>` and `public extension Generic where Base == Concrete { ... }` are independently sufficient triggers. | Not yet filed (fix is on 6.5-dev nightly-main snapshot `swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a`; upstream commit search pending). | **File-split**: keep parser declarations and test method bodies in separate files. The parser-declaration file does NOT import the module exposing the parameterized typealias. The test-method-body file DOES import it. Test H8 confirmed: removing the import from the parser-declarations file eliminates the ICE. See § A8. | In-cohort reproducer: `swift-ascii-parser-primitives/Tests/Declarative Parser Syntax Tests/Declarative Parser Syntax Tests.swift` at baseline commit `17b97da`, with `swift-parser-primitives` at `eb01abd` or any commit exposing `Parser.Test.Input` as a public typealias. 4 ICEs at lines 121/162/205/258. Single-file `swiftc` and 2-module minimal SwiftPM did NOT reproduce — full trigger requires multi-module + complex body builder (result builder, chained `.map` transformations). Full investigation arc (11 hypothesis tests, 8 disconfirmed) at `swift-institute/Issues/swift-issue-parameterized-typealias-opaque-return-ice/INVESTIGATION-ARC.md`. |

### Language-surface tightening between 6.2.3 and 6.3.x

Not 6.3.1 regressions — these landed somewhere in the 6.2.3 → 6.3.0 window and persist in 6.3.1 and 6.4-dev.

| Behavior | Effect |
|----------|--------|
| `@_lifetime(copy self)` / `@_lifetime(self: immortal)` rejected on Escapable results/targets | `escapable-lazy-sequence-borrowing` (validated on 6.2.3 as ALL CONFIRMED) no longer compiles |
| `@lifetime` (single-underscore, no stable form) unsupported | Warning + error in `contiguous-protocol-escapable`; must use `@_lifetime` |

### Swift 6.4-dev Regressions (from 6.3.1 baseline)

| Regression | Workaround | Blocker |
|------------|-----------|---------|
| `Optional.take` sending RegionIsolation | Split into Sendable / non-Sendable overloads | Non-Sendable consume self disconnection no longer proven |
| Closure IRGen crash on identity closures | Named static function references | Affects typed-throws closure patterns |
| DeinitDevirtualizer SIL assertion | None — blocks 6.4-dev | Compiler fix needed |
| Static property resolution in protocol extensions | Inline `Ordering.Comparator` | 2 package updates |

### 6.3.1 release highlights

- ~30 commits for stack-nesting of async runtime builtins: `[non_nested]` flag on `alloc_stack`, `alloc_ref`, `alloc_pack_metadata`, `partial_apply [on_stack]`. Fixes async-let / task-local / cancellation / priority-escalation handler interactions with the SIL optimizer.
- AutoDiff: VJP/JVP force-inlining (`#87959`) + `differentiable_function` borrowed scopes (`#87961`).
- OpenBSD unversioned triples.

### Stale experiment documentation cleared

- `actor-state-inline-fallback-repro` and `actor-state-cross-thread-inline` (both under `swift-institute/Experiments/`): 0 reproductions on 6.3.1, but per § A6 the inline-fallback / cross-thread theories were already ruled out as red herrings; these experiments were likely non-reproducing already on 6.3.

**Source: `swift-6.3-fix-status.md` (deleted 2026-05-10 in Wave 6).**

---

## Table of Contents

| § | Bug class | Swift versions | One-line symptom |
|---|-----------|----------------|------------------|
| A1 | `@inlinable + withUnsafePointer(to: borrowing ~Copyable)` miscompile (Instance A) | 6.3.1 / 6.4-dev | Cross-module release inlines away `@in_guaranteed`; `withUnsafePointer` returns dead callee-frame slot |
| A2 | `@inlinable + withUnsafePointer(to: self.~Copyable_field)` miscompile (Instance B) | 6.3.1 / 6.4-dev | Cross-module release returns divergent stack addresses 8 bytes apart with garbage dereferences |
| A3 | CopyPropagation ~Escapable coroutine yield crash | 6.2.x (FIXED 6.3) | `~Escapable` + `@_lifetime(borrow base)` triggers four-pass interaction ending in "Found over consume?!" |
| A4 | Pack-expand on `consuming` parameter member-access SIGSEGV | 6.3.1 / 6.4-dev nightly / 6.4-dev/Embedded | `each product.values` (where `product` is `consuming`) crashes `swift-frontend` in CSE pass |
| A5 | CopyPropagation `try_apply` borrow-scope shortening | 6.3.1 (workaround in place) | `do/catch` around `~Copyable` borrow generates `try_apply`; CopyPropagation ends `begin_borrow` early |
| A6 | WMO + CopyToBorrowOptimization actor-state miscompile | 6.3.1 (still broken) | `guard state == .running` constant-folded to `true` after shutdown; 6 trigger conditions required |
| A7 | SIL EarlyPerfInliner crash on ~Copyable value-type `_read` yield | 6.3.1 (still broken) | "Cannot initialize a nonCopyable type with a guaranteed value" at SILPerformanceInlinerPass |
| A8 | Parameterized-typealias × parameterized-protocol opaque-return ICE | 6.3.2 (FIXED 6.4-dev) | `public typealias X = Generic<Concrete>` OR `extension Generic where Base == Concrete` in imported module triggers "failed to produce diagnostic" at test-target opaque returns |
| A9 | `Atomic<Tagged<…>>` and `Dictionary<Tagged<…>, ~Copyable>` runtime metadata-lookup defect | 6.3.2 (still broken; evergreen wrapper fix landed) | `swift_getTypeByMangledName` returns `TypeLookupError("unknown error")` for institute-Tagged inside generic stdlib/institute containers needing full metadata; downstream loads of null metadata fault at `0x10` (advance) or `0xfffffffffffffff8` (deinit) |
| A10 | Unconditional protocol-conformance extension leaks `Element: Copyable` to primary declaration of `~Copyable`-generic nested type | 6.3.2 / 6.4-dev (still broken) | `extension Storage.Inline: SomeProtocol { … }` (no `where Element: ~Copyable`) causes `type 'Element' does not conform to protocol 'Copyable'` at every Element reference in a sibling `extension Storage where Element: ~Copyable`-scoped declaration |
| A11 | `DiagnoseStaticExclusivity` SIGSEGV on a borrow returned through a `~Copyable` enum payload | 6.3.2 (still broken) | `@inlinable` getter returning `Span`/`MutableSpan`/`_read`-view from a `switch` over a `~Copyable` enum payload crashes emit-module; workaround is non-`@inlinable` + package window. Context-sensitive (no standalone reducer yet) |
| B1 | `Property.View ~Copyable` extension constraint placement | 6.3.x (lang spec) | All constraints MUST be at extension level, not method level — implicit `Base: Copyable` else |
| B2 | `Property.View` rejected on `Copyable` types (~Copyable + ~Escapable result from mutating method) | 6.3.x (lang spec) | Use `Property<Tag, Base>` for `@CoW` Copyable types instead |
| B3 | Tagged constrained-extension nested-type ambiguity | 6.3.1 (still broken) | `extension Tagged where Tag == X, RawValue == Y { typealias Foo = ... }` causes cross-instantiation ambiguity |
| B4 | Tagged generic param can be `Underlying` (despite typealias collision) | 6.3.1 (works under recipe) | Carrying conformance via `extension Tagged: Carrying` + `Self.Underlying` qualification — verified |
| B5 | Pack same-type requirements with concrete types not yet supported | 6.2.4 / 6.3.x (lang spec) | Inside `extension Product<Int, String, Double>`, `values` is NOT narrowed to `(Int, String, Double)` |
| C1 | Actor isolation — three mechanisms model | 6.3.x (lang spec) | When to use `Actor.run` vs `assumeIsolated` vs `isolated` parameter |
| C2 | Typed throws — Swift 6.2.4 stdlib support matrix | 6.2.4 / 6.3.x (lang spec) | Some stdlib `rethrows` APIs propagate `throws(E)`; many erase to `any Error` |
| C3 | Typed throws — catch blocks preserve concrete typed error | 6.3.x (lang spec) | `error` in catch IS the concrete typed error, NOT `any Error` |

**Total entries: 20** (19 distinct bugs/patterns + the master fix-status table). Worked-example sections begin below.

---

## A. Miscompiles and SIL-Level Crashes

### A1. `@inlinable + withUnsafePointer(to: borrowing ~Copyable)` miscompile — Instance A (borrowing parameter)

**Swift versions**: 6.3.1, 6.4-dev (release mode).

**Pattern**:
```swift
public @inlinable init(... value: borrowing Value) where Value: ~Copyable {
    // ...
    withUnsafePointer(to: value) { ptr in
        // store ptr past the closure
    }
}
```

**Symptom**: Inlined cross-module in release, the optimizer inlines-away the `@in_guaranteed` ABI. `withUnsafePointer` returns a callee-frame slot that dies on closure return. Debug-mode reads happen to return stale bits; release-mode returns garbage / SIGTRAP.

**Workaround (works)**: Remove `@inlinable`. The cross-module function-call boundary preserves `@in_guaranteed`. Verified empirically via swift-property-primitives `borrowing init supports multiple reads` release test (cross-module, let-bound, multi-read → passes).

**Production sites** (workaround applied):
- `swift-ownership-primitives` `Ownership.Borrow.init(borrowing: ~Copyable Value)` — fixed via non-`@inlinable`, commit `ece5d7e`.
- `swift-property-primitives` `Property.View.@unsafe init(_ base: borrowing Base)` — fixed via non-`@inlinable`, commit `764db07`.

**Evidence**: experiment V1/V7 (crash in single-file), `/tmp/borrow-repro.swift` minimal V1-vs-V2 contrast. Audit: `swift-institute/Audits/borrow-pointer-storage-release-miscompile.md`. Unfiled upstream as of 2026-04-24; filing authorized per A2; V13 runs first to characterise the discriminator.

**Review heuristic**: `public @inlinable` + `borrowing value: borrowing Value` parameter + `withUnsafePointer(to: value)` in body + result stored/returned past closure. Treat as a latent miscompile site. Check whether any cross-module release-mode test exercises it. If not, absence of failure is absence of evidence.

**Source: `inlinable-noncopyable-withUnsafePointer-miscompile.md` (deleted 2026-05-10 in Wave 6).**

---

### A2. `@inlinable + withUnsafePointer(to: self.~Copyable_field)` miscompile — Instance B (field-of-self narrow shape)

**Swift versions**: 6.3.1, 6.4-dev (release mode).

**Pattern**:
```swift
public @inlinable func m() -> UnsafePointer<X> on a ~Copyable type {
    withUnsafePointer(to: self.stored_~Copyable_field) { ptr in
        // return the pointer
    }
}
```

**Symptom**: Cross-module in release, two successive calls return different stack addresses (8 bytes apart) with garbage dereferences.

**Workaround**: Non-`@inlinable` does NOT rescue this shape. `withUnsafePointer` creates per-call borrow-locals inside the callee frame regardless of cross-module boundary.

**Production status**: Does NOT apply in production. In-package positive-assertion regression guards in `swift-memory-primitives` (`e390d7a`), `swift-buffer-primitives` (`92e53fe`), `swift-async-primitives` (`26e76e1`) all PASS in release. The production shape uses `@_rawLayout(likeArrayOf: Element, count: capacity)`-backed `_storage` with generic specialization over Element and stride-advance arithmetic — one or more of these (most likely the compile-time-known `@_rawLayout` offset) is the structural discriminator that protects the production path. Precise discriminator not isolated; a V13 experiment is deferred until upstream filing is authorized.

**Evidence**: experiment V10 (crashes SIGTRAP) / V11 (divergent addresses + garbage) in `swift-institute/Experiments/borrow-pointer-storage-release-miscompile` commit `cee7a7a`. Two-target SwiftPM layout: library `V10FieldOfSelfLib` + executable `main`.

**Contrast**: `withUnsafeMutablePointer(to: &value)` with `value: inout Value` works regardless — the `@inout` ABI provides caller-stable indirect pointer through any inlining.

**Review heuristic**: `public @inlinable func` on `~Copyable` type + `withUnsafePointer(to: self.storedField)` for `~Copyable` stored field + result escaping closure. In-package regression guards should assert address stability + dereferenced-value correctness on let-bound-container + multi-read shape. If guards pass, the `@_rawLayout` (or similar) discriminator holds.

**Source: `inlinable-noncopyable-withUnsafePointer-miscompile.md` (deleted 2026-05-10 in Wave 6).**

---

### A3. CopyPropagation ~Escapable coroutine yield crash (FIXED in 6.3)

**Swift versions**: 6.2.x (BROKEN); 6.3 onward (FIXED).

**Pattern**: `~Escapable` + `@_lifetime(borrow base)` annotation on Property.View types yielded from `_read` coroutines.

**Multi-pass interaction (now fixed)**:
1. `PredictableDeadAllocationElimination` introduces a spurious `destroy_value`.
2. `SILCombine` removes `mark_dependence` (trivial base → redundant), causing triple consume.
3. `DeinitDevirtualizer` converts to `end_lifetime`, serialized to module.
4. When inlined into consumer, CopyPropagation catches double `end_lifetime` — "Found over consume?!".

**Status (2026-03-25 → still fixed on 6.3.1)**: Bug FIXED in Swift 6.3 (Xcode 26.4). Standalone reproducer (`swift-issue-copypropagation-nonescapable-mark-dependence`) builds and runs clean in release mode. Property.View types in `swift-property-primitives` re-added `~Escapable` and `@_lifetime(borrow base)` annotations.

**Upstream ID**: `swiftlang/swift#88022`.

**Standalone reproducer**: <https://github.com/coenttb/swift-issue-copypropagation-nonescapable-mark-dependence>.

**Source: `copypropagation-nonescapable-fix.md` (deleted 2026-05-10 in Wave 6).**

---

### A4. Pack-expand on `consuming` parameter member-access SIGSEGV

**Swift versions**: 6.3.1 (Xcode default), 6.4-dev nightly (`org.swift.64202603161a`), 6.4-dev/Embedded.

**Pattern**:
```swift
public static func map<each NewElement, E: Swift.Error>(
    _ product: consuming Product,
    _ transforms: repeat (each Element) throws(E) -> each NewElement
) throws(E) -> Product<repeat each NewElement> {
    Product<repeat each NewElement>(
        repeat try (each transforms)(each product.values)  // ← SIGSEGV
    )
}
```

`each product.values` (pack-expand of a member-access on a `consuming` function parameter, where `values` is a `(repeat each Element)` stored property) crashes `swift-frontend` with SIGSEGV in CSE pass.

**Workarounds**:

1. **Local-let extract** (works for static methods that must keep `consuming` parameter):
   ```swift
   let values = (consume product).values
   return Product<...>(repeat try (each transforms)(each values))
   ```
   Adds one binding; in release mode the optimizer should fold it away (not measured).

2. **Instance-canonical with self-pack** (cleaner; expands `each values` = `each self.values` directly inside `consuming func`):
   ```swift
   public consuming func map<...>(_:) -> ... {
       Product<repeat each NewElement>(
           repeat try (each transforms)(each values)  // ← works
       )
   }
   ```
   The static layer becomes a thin delegate: `try product.map(repeat each transforms)`.

**Decision rule for cohort uniformity (Pair / Either / Product)**:

| Type | Has packs? | Canonical layer |
|------|------------|-----------------|
| `Pair` | No | Static (no compiler bug; clean `consume pair` + `consumed.first` works) |
| `Either` | No | Static |
| `Product` | Yes (`<repeat each Element>`) | **Instance** — static-canonical requires the local-let workaround which adds indirection; user explicitly preferred instance-canonical for Product over the workaround. "performance and memory allocations is more important [than static-canonical]" — 2026-05-09. |

**Filed upstream (2026-05-09)**:
- [`swiftlang/swift#88985`](https://github.com/swiftlang/swift/issues/88985) — pack-expand on consuming-PARAMETER member-access (the original failure shape above). Reproduces on Swift 6.4-dev nightly 2026-05-07-a; minimal repro at `/tmp/swift-bug-1-pack-expand-consuming.swift`. CSE-pass assertion failure.
- [`swiftlang/swift#88987`](https://github.com/swiftlang/swift/issues/88987) — pack-expand on instance-self (`each values` from `consuming func`). The cohort's *workaround* for `#88985` ALSO crashes under release-mode optimization. Manifestation appears in CSE on minimal repro and SILCombine on the full Product Tests function. Filed as a sibling issue; likely the same underlying parameter-pack-lowering bug.
- [`swiftlang/swift#88986`](https://github.com/swiftlang/swift/issues/88986) — `@_owned consuming get` on generic `~Copyable` enum (separate but session-related; coverage gap in move-checker for generic-enum consuming getters).

**Cross-references**: § A1 / A2 (`@inlinable` + `withUnsafePointer` miscompile), § B5 (pack-concrete same-type).

**Source: `pack-expand-on-consuming-param-property.md` (deleted 2026-05-10 in Wave 6).**

---

### A5. CopyPropagation `try_apply` borrow-scope shortening

**Swift versions**: 6.3.1 (workaround in place; bug not independently re-verified post-workaround).

**Pattern**: `IO.Event.Channel.socketError()` crashed CopyPropagation (pass #1534) in release mode.

**Root cause**: `do { try getError(descriptor!) } catch { nil }` generates a `try_apply` with normal+error continuation blocks. CopyPropagation shortens the `begin_borrow` / `end_borrow` scope of `self` (`Channel: ~Copyable`) to end before the `try_apply` that still uses the borrowed `descriptor` field. Ownership verification catches "outside of lifetime use" violation.

**Workaround**: Replace `do/catch` with `try?` which avoids the `try_apply` SIL pattern entirely. This enables plain `swift build -c release` without `-sil-disable-pass=CopyPropagation`.

**Why standalone reproduction is hard**: Crash requires WMO + cross-module inlining. Only triggers in full swift-io module build.

**Separate from**: The 3 shutdown test failures (actor state visibility, § A6) are independent — they reproduce in plain `-c release` without the CopyPropagation workaround flag.

**Source: `consuming-async-escapable-extraction-pattern.md` (deleted 2026-05-10 in Wave 6).**

---

### A6. WMO + CopyToBorrowOptimization actor-state miscompile

**Swift versions**: 6.3.1 (still broken; standalone reproducer fails 100/100 iterations).

**Pattern**: 3 shutdown tests in swift-io fail in `-c release` because WMO + CopyToBorrowOptimization causes `guard state == .running` to be constant-folded to `true` after shutdown.

**Self-contained reproducer**: `swift-institute/Experiments/copytoborrow-actor-state-mutex-miscompile/` (moved 2026-04-17 from `/Users/coen/Developer/swift-copytoborrow-bug-standalone/`). 87 lines total, zero external deps. `swift build -c release && .build/release/BugTest` → BUG. Confirmed still failing 100/100 iterations on Swift 6.3.1 (Xcode 26.4.1).

**Essential trigger conditions** (all six required):
1. `enum State` on actor (Bool doesn't trigger — needs `select_enum` SIL pattern).
2. `consuming func close()` on `~Copyable` Scope (mutating doesn't trigger).
3. `Mutex<Bool>` field on the `~Copyable` Scope (plain `~Copyable` padding doesn't; stdlib `Mutex` specifically; never needs to be read).
4. Selector struct wrapping Runtime with `register()` forwarding.
5. Custom serial executor (`SerialExecutor` + `unownedExecutor`).
6. Cross-module async call.

**Mechanism (updated 2026-04-13)**: The earlier theory about C2B removing retain/release on Lock class in `enqueue` was a RED HERRING — a threadless executor with no lock still triggers. The actual mechanism: C2B changes BugLib's `.swiftmodule` in a way that causes LLVM to misoptimize the CALLER's async continuation handling. SIL/IR/asm for `register()` and `shutdown()` are identical with and without C2B — the bug is downstream in LLVM.

**Workaround for swift-io**: APPLIED (commit `6dad19ba`, 2026-04-13). Removed `Mutex<Token?>` from `IO.Event.Selector.Scope`, replaced with direct `var Shutdown.Token?`. All 143 tests pass in release mode. Note: `IO.Completion.Queue.Scope` still uses the same Mutex pattern — not yet changed (different trigger conditions or not yet confirmed affected).

**Global workaround**: `-Xswiftc -Xllvm -Xswiftc -sil-disable-pass=copy-to-borrow-optimization`.

**Source: `copytoborrow-actor-state-barrier.md` (deleted 2026-05-10 in Wave 6).**

---

### A7. SIL EarlyPerfInliner crash on ~Copyable value-type `_read` yield

**Swift versions**: 6.3.1 (still broken).

**Pattern**: `@_optimize(none)` is required on any accessor whose `_read` yields a cross-module `~Copyable` value-type. Without it, SILPerformanceInlinerPass crashes with "Cannot initialize a nonCopyable type with a guaranteed value".

**Production decision (swift-property-primitives)**: DID NOT adopt Option C (value-type State) because the workaround would distribute to every consumer accessor site — ergonomics too hostile for a published API. Kept Option A instead (conditional `@unchecked Sendable` on the class-based State). Revisit Option C when this crash is fixed upstream.

**Reproducers** (all five crash in the same pass; the bug is broader than originally scoped — any cross-module `~Copyable` value-type yield through `_read`, not just specific patterns):
- Primary: `swift-property-primitives/Experiments/property-consuming-value-state/` crashes on `swift build -c release` at SILPerformanceInlinerPass.
- `swift-property-primitives/Experiments/language-semantic-property-typed-replacement` (Property.Typed pure-language replacement).
- `swift-property-primitives/Experiments/language-semantic-property-replacement` (Property pure-language replacement).
- `swift-render-primitives/Experiments/body-getter-stack-overflow` (production SIGBUS reproducer).
- `swift-pdf/Experiments/result-builder-stack-overflow` (PDF result-builder pattern; same crash).

**Companion benchmark**: `swift-property-primitives/Experiments/property-consuming-state-allocation-benchmark` showed no runtime upside for Option C (within noise of Option A) — no offsetting win.

**Revalidation**: rebuild any of the four experiments `-c release` — when they stop crashing, Option C becomes viable.

**Source: master fix-status table (still-broken section); `swift-6.3-fix-status.md` (deleted 2026-05-10 in Wave 6).**

---

### A8. Parameterized-typealias × parameterized-protocol opaque-return ICE

**Swift versions**: 6.3.2 (FIRES); 6.5-dev snapshot `swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a` (FIXED).

**Symptom**: `error: failed to produce diagnostic for expression; please submit a bug report (https://swift.org/contributing/#reporting-bugs)` emitted at the `}` of `var body: some SomeProtocol<TypeParam, Output, Error> { ... }` declarations during **test-target** compilation (`swift test`). Library targets (`swift build`) compile cleanly — only test-target compilation reaches the ICE site. The error cascade terminates the build with `error: fatalError`.

**Trigger** (either is independently sufficient when in an imported module's public scope):

1. **Parameterized typealias**: `public typealias X = Generic<Concrete>` — a typealias for a generic-type instantiation (the typealias's right-hand side is `SomeType<ConcreteTypeArg>`).
2. **Base-constrained extension on a generic type**: `public extension Generic where Base == Concrete { ... }` — an extension constrained to a specific generic instantiation.

Both must be in module-export scope (visible to the consumer via `import`). Same-file declarations do not trigger.

**Empirically NOT the trigger** (each independently disconfirmed via 11 hypothesis tests, see `swift-institute/Issues/swift-issue-parameterized-typealias-opaque-return-ice/INVESTIGATION-ARC.md`):
- Stale `.build/` artifacts (clean build reproduces).
- The typealias name (any identifier ICEs the same).
- Local-generic-param × typealias-name shadowing (renaming local param doesn't help).
- The namespace location (nested in a parent enum vs top-level both ICE).
- Explicit `<ExplicitParam, …>` binding in body builders (vs `_` placeholder; both ICE).
- `@retroactive` conformance status of constrained extensions (both retroactive and non-retroactive extensions trigger when Base-constrained on a parameterized type).

**Workaround for shipped 6.3.x — SwiftPM `exclude` the offending file**:

Defer compilation of the test file that contains the ICE-triggering parser declarations via SwiftPM `exclude` on the test target. The file stays in the repo with cohort-renamed types so it's re-enable-ready when 6.4 ships.

```swift
.testTarget(
    name: "Declarative Parser Syntax Tests",
    dependencies: [
        "ASCII Decimal Parser Primitives",
        .product(name: "Parser Primitives Test Support", package: "swift-parser-primitives"),
    ],
    exclude: ["Declarative Parser Syntax Tests.swift"]
)
```

Empirical confidence: **HIGH — directly validated 2026-05-16**. With this workaround applied in `swift-ascii-parser-primitives`, `swift test` produces 29 tests pass / 0 ICEs. The other 3 cohort packages (parser-primitives, parser-machine-primitives, byte-parser-primitives) pass cleanly with the public typealias `Parser.Test.Input` retained — Step 1+2 commits (subagent's defensive workaround that removed the public typealias) were `git reset`'d after empirical verification confirmed they were unnecessary.

**Trigger model — UNDERDETERMINED**. The apparent ingredients (parameterized typealias `X = Input.Slice<Concrete>` in module-export scope + `var body: some Parser.\`Protocol\`<TypeParam, …>` opaque return in same test target) are present in BOTH:
- parser-primitives `Tests/Parser Take Primitives Tests/Parser.Builder Tests.swift` — **passes** (150 tests green)
- ascii `Tests/Declarative Parser Syntax Tests/Declarative Parser Syntax Tests.swift` — **ICEs** (4 sites)

So the apparent pattern is necessary but not sufficient. Some additional structural factor in ascii's file distinguishes it; the precise minimum was not isolated. Candidate axes (each plausible, none confirmed in isolation):
- Cross-module parser type inside body result builder (`ASCII.Decimal.Parser<_, UInt16>` in ascii vs same-file `Digit<Input>` in parser-primitives)
- Placeholder generic argument `<_, UInt16>` (ascii) vs explicit `<Input>` (parser-primitives)
- String-literal `ExpressibleByStringLiteral` triggers in the result builder
- Number of parser declarations (ascii has 4; parser-primitives Parser.Builder Tests has ~10)

The bug is fixed in Swift 6.5-dev (snapshot `swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a`); reduction was deprioritized once upstream fix was confirmed.

**Workarounds considered and rejected**:
- *Struct wrapper instead of typealias* — heavy consumer-side rewrite (~340 call sites), conformance forwarding non-trivial.
- *Remove public typealias + file-private aliases at consumers* (subagent's Path C-original) — verified insufficient; ICE persists in ascii after the underlying defensive change.
- *File-split (parser decls in one file, test bodies in another)* — verified insufficient. Failed empirically against the same ICE sites.
- *Move parser declarations to a separate library target* — violates `[MOD-DOMAIN]` ("a new target MUST represent a coherent semantic domain"). The deferred file's content (Network.Endpoint.Parser, Geometry.Point.Parser, etc.) has no coherent semantic identity — they're declarative-syntax examples, not a domain.
- *Roll back the parent rename* — loses three `[API-NAME-002]` cleanups permanently.

**Pattern coverage redundancy**: the deferred `Declarative Parser Syntax Tests.swift` exercises the `var body: some Parser.\`Protocol\`<TypeParam, …>` declarative-syntax pattern. The same pattern is exercised redundantly by parser-primitives' `Parser.Builder Tests.swift` (which passes on 6.3.2). Deferring ascii's file loses no unique coverage.

**In-cohort reproducer**: `swift-ascii-parser-primitives/Tests/Declarative Parser Syntax Tests/Declarative Parser Syntax Tests.swift` at any state where the file references `Parser.Test.Input` typealias and the file is NOT excluded from its test target. Run `swift test` in `swift-ascii-parser-primitives` to reproduce — 4 ICEs at the `var body:` lines of the 4 parser conformances.

**Standalone reproducer status**: ATTEMPTED, NOT ACHIEVED. Single-file `swiftc`-buildable reproducer compiles cleanly. Minimal 2-module SwiftPM reproducer with simple body (returning a single P conformer) also did not reproduce on 6.3.2.

**Revalidation**: when `TOOLCHAINS=swift swift test` (against any current 6.4-dev snapshot) in `swift-ascii-parser-primitives` with the `exclude:` clause REMOVED from `Package.swift` emits zero `failed to produce diagnostic` messages, the fix has landed. Verified on snapshot `swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a` 2026-05-16.

**Sunset condition — when this workaround is removed**: when the workspace migrates default toolchain to Swift 6.4+ (currently 6.4-dev only). Remove the `exclude:` clause from `swift-ascii-parser-primitives/Package.swift`; the file's content is already at canonical `Parser.Test.*` names. No content change required.

**Source: `swift-institute/Issues/swift-issue-parameterized-typealias-opaque-return-ice/{INVESTIGATION-ARC.md, README.md}` — investigation arc 2026-05-16.**

---

### A9. `Atomic<Tagged<…>>` and `Dictionary_Primitives.Dictionary<Tagged<…>, ~Copyable>` runtime metadata-lookup defect

**Swift versions**: 6.3.2 (`swiftlang-6.3.2.1.108`), Xcode 26.4.1; macOS 26.2 (build 25C56) arm64. Dev-toolchain (6.4-dev nightly) check blocked by the unrelated DeinitDevirtualizer SIL assertion on `swift-array-primitives` (see Master Fix-Status Table → Swift 6.4-dev Regressions).

**Symptom**: Any generic stdlib or institute container that requires `Tagged_Primitives.Tagged<…>`'s **full type metadata** at runtime crashes with `EXC_BAD_ACCESS (code=1, address=0x10)` or `(code=1, address=0xfffffffffffffff8)`. Specifically:

| Site | Trigger | Faulting load |
|---|---|---|
| `Atomic<Tagged<Tag, Ordinal>>.advance(within:)` | generic-method dispatch on the `@inlinable` `advance` extension in `Atomic+Ordinal.swift` | `ldr x2, [x1, #0x10]` — generic-arg[0] off null metadata |
| `Atomic<Tagged<Tag, Underlying>>` synthesized `~Copyable` deinit | scope-end destroy of even a discarded `let _ = Atomic<Tagged<…>>(.zero)` | `ldur x8, [x1, #-0x8]` — VWT pointer off null metadata |
| `Dictionary_Primitives.Dictionary<Tagged<Tag, U>, ~CopyableValue>.set(_:_:)` | hash-table insert/lookup that needs Tagged's value-witness table | `Dictionary<>.set+108` — same null-metadata pattern |
| `Dictionary_Primitives.Dictionary<Tagged<Tag, U>, ~CopyableValue>.remove(_:)` | identical | identical |

The runtime helper `__swift_instantiateConcreteTypeFromMangledNameV2` returns a default-constructed `TypeLookupError("unknown error")` for the symbolic mangled name representing `Atomic<Tagged<…>>` / `Dictionary<Tagged<…>, …>`. Verified via lldb breakpoint inside `libswiftCore.dylib!swift_getTypeByMangledNameInContextImpl + 192`, inspecting the `TypeLookupErrorOr` result struct: `tag = 1`, `message = "unknown error"`, `invoke vtable = TypeLookupError::TypeLookupError(char const*)::__invoke`. Reachable observationally via `SWIFT_DEBUG_FAILED_TYPE_LOOKUP=1` (the runtime warns before the SIGSEGV).

None of the high-level metadata / witness / conformance runtime entry points are reached — the failure originates in the demangling-resolution stage of `swift_getTypeByMangledName` before any of `swift_getCanonicalSpecializedMetadata*`, `swift_conformsToProtocol*`, `swift_getAssociatedTypeWitness`, `swift_lookUpProtocolConformance`, or even `swift::ResolveAsSymbolicReference::operator()` dispatches. The conformance descriptor IS present in the binary (verified at `_$s17Tagged_Primitives0A0Vyxq_G15Synchronization19AtomicRepresentable…Mc`); the runtime simply can't materialize the wrapping metadata.

**Variable isolation result** (per `[ISSUE-013]`):

| Variant | Result |
|---|---|
| `Atomic<UInt>` lifecycle / ops | PASS |
| `Atomic<Ordinal>` (no Tagged) lifecycle / advance / all ops | PASS |
| `Tagged<Tag, Ordinal>` arithmetic with `Synchronization` imported | PASS |
| `Atomic<Tagged<Tag, U>>` create+drop (lifecycle only) | **CRASH** |
| `Atomic<Tagged<Tag, U>>.load(ordering:)` | PASS (specialized fast path, no metadata fetch) |
| `Atomic<Tagged<Tag, U>>.advance(within:)` (generic extension) | **CRASH** |
| Local `Wrapper<Tag, U>: ~Copyable & ~Escapable + AtomicRepresentable` mirroring Tagged's shape | PASS (proves it's `Tagged_Primitives.Tagged` specifically, not the shape pattern) |
| Hoisting Tagged's AtomicRepresentable conformance from `Tagged_Primitives_Standard_Library_Integration` into the main `Tagged_Primitives` module | Does NOT fix the crash |
| Dropping `Tag: ~Copyable` from `Tagged: AtomicRepresentable` where-clause | Does NOT fix the crash |
| Tag identity (SimpleTag local enum / Int / String / class / `POSIX.Kernel.Thread` extension-nested enum) | All crash identically |
| Underlying identity (UInt / Int / Ordinal) | All crash identically |
| `Dictionary<Tagged<Tag, UInt>, Int>` (stdlib Dictionary, Copyable value) | PASS |
| `Dictionary_Primitives.Dictionary<Tagged<Tag, UInt>, ~CopyableStruct>` (institute Dictionary, ~Copyable value) | **CRASH** |

The trigger is specific to `Tagged_Primitives.Tagged` materialized inside a generic container that wants its full type metadata (value-witness table, layout, generic-arg vector). Whatever the actual runtime defect is, it lives in the runtime's resolution of that specific Tagged's mangled name — local replicas of Tagged's shape do not reproduce. Cross-module conformance lookup was ruled out as the trigger (hoist had no effect).

**Reproducer**: `swift-foundations/swift-executors/Experiments/sigsegv-repro/` — 3 path: dependencies (`swift-tagged-primitives`, `swift-ordinal-primitives`, `swift-cardinal-primitives`), single `main.swift`, ~10 lines exercising `Atomic<Tagged<SimpleTag, Ordinal>>.advance(within: Tagged<SimpleTag, Cardinal>)`. Build + run → exit 139 before the fix; `result = 0` + exit 0 with the fix applied. Pre-`swift package update` rules out stale-resolved-revision.

**Evergreen fix shape** (no workarounds; survives a future runtime fix as a useful named primitive):

Replace `Atomic<Tagged<…>>` and `Dictionary_Primitives.Dictionary<Tagged<…>, …>` storage with the **raw-Underlying-storage + typed-surface wrapper** pattern. The container holds the bare-`UInt`/`UInt64` (the Tagged's `underlying.rawValue`); the public surface accepts/returns `Tagged<Tag, …>` values so the phantom-Tag domain discipline carries through every API. Three landed instances of this pattern:

| Component | Wrapper / refactor | Commit |
|---|---|---|
| `Atomic<Tagged<Tag, Ordinal>>` round-robin cursor | New `Ordinal.AtomicPosition<Tag>` in `swift-ordinal-primitives` (holds `Atomic<UInt>` internally; typed `Tagged<Tag, Ordinal>` load + advance API) | swift-primitives/swift-ordinal-primitives **88780ee** |
| `Atomic<Index<Kernel.Thread>>` in `Stealing.cursor` / `Sharded.cursor` | Replaced with `Ordinal.AtomicPosition<Kernel.Thread>` (call sites unchanged) | swift-foundations/swift-executors **dd34b04** |
| `Dictionary_Primitives.Dictionary<Kernel.Event.ID, Registration>` in `Kernel.Event.Driver.init` | Inline refactor: key is bare `UInt`, conversion at every method boundary | swift-foundations/swift-kernel **a79ca49** |
| `Dictionary_Primitives.Dictionary<Kernel.Completion.Token, Completion.Entry>` in `Completion.Actor.entries` | Inline refactor: key is bare `UInt64`, conversion at every method boundary | swift-foundations/swift-io **7c3c6207** |

Each fix preserves the typed surface (callers pass and receive `Kernel.Event.ID` / `Kernel.Completion.Token` / `Tagged<Kernel.Thread, Ordinal>` unchanged); only the internal storage uses the bare-Underlying raw value. The pattern remains useful as a named abstraction even when the underlying runtime defect is fixed upstream — `Ordinal.AtomicPosition<Tag>` is also a clearer API than ad-hoc `Atomic<Index<Tag>>` regardless of the bug.

**Revalidation procedure**:

```bash
# Reproducer-side
cd /Users/coen/Developer/swift-foundations/swift-executors/Experiments/sigsegv-repro
rm -rf .build && swift build && ./.build/arm64-apple-macosx/debug/sigsegv-repro
# expect: "advanced -> 0,1,2,0,1" and "PASSED"; exit 0

# Consumer-side, all three packages must complete without signal 11
( cd /Users/coen/Developer/swift-foundations/swift-executors && rm -rf .build && swift test )
( cd /Users/coen/Developer/swift-foundations/swift-threads && rm -rf .build && swift test )
( cd /Users/coen/Developer/swift-foundations/swift-io && rm -rf .build && swift test )
# expect: each prints a final "Test run with N tests in M suites passed" line.
```

Confirmed 2026-05-22: swift-executors 33/33 in 27 suites, swift-threads 22/22 in 16 suites, swift-io 61/61 in 26 suites. Zero `exited with unexpected signal code` across all three.

**Discovery & investigation arc**: `HANDOFF-test-sigsegv-post-cycle-break.md` in the workspace root. Investigation 2026-05-22 narrowed from "swift test exits with signal 11 in three packages" to a 5-line `@main` reproducer, then to the runtime null-metadata return, then ruled out the Tag suppression and the cross-module-conformance hypotheses, then identified that the bug surfaces broadly across containers needing Tagged's full metadata (not just `Atomic`). The evergreen wrapper pattern (raw storage + typed surface) is the structural fix.

**Cross-references**: §A1, §A2 (other Tagged + cross-module-inline interactions on 6.3.x). Closest related entries in spirit are §A6 (CopyToBorrowOptimization actor-state miscompile) and §A7 (~Copyable value-type `_read` yield SILPerfInliner crash) — different defects, same "runtime can't materialize this type metadata for a specific institute-Tagged shape" family.

**Upstream filing status**: NOT YET FILED. The bare-`swiftc` standalone reproducer per `[ISSUE-002]` has not been achieved — the failure depends on the `Tagged_Primitives.Tagged` definition + its full conformance set, which is heavy to inline into a single file. The SwiftPM reproducer at `Experiments/sigsegv-repro/` is the current minimum; upstream filing should wait for a bare-`swiftc` reduction or for an opportunistic dev-toolchain check once `swift-array-primitives` compiles on 6.4-dev.

#### §A9 Update (2026-05-23 Arc 4) — Bug fixed on Swift 6.5-dev; Issues entry staged; workaround commits reverted

This subsection appends Arc 4 findings without rewriting the original §A9 body.

**Dev-toolchain status — FIXED on 6.5-dev** (resolves the prior "blocked" claim in this entry's `Swift versions` header):

| Toolchain | Bundle ID | Build | Run |
|-----------|-----------|-------|-----|
| Apple Swift 6.3.2 RELEASE (default Xcode 26.4.1) | `swiftlang-6.3.2.1.108` | OK | **CRASH** (exit 139) |
| Swift 6.5-dev nightly `2026-03-16-a` | `org.swift.64202603161a` | OK | **PASS** (exit 0) |
| Swift 6.5-dev nightly `2026-05-07-a` | `org.swift.64202605071a` | OK | **PASS** (exit 0) |
| Swift 6.5-dev nightly `2026-05-12-a` | `org.swift.64202605121a` | OK (debug + release) | **PASS** (exit 0) |

The standalone reproducer at `swift-foundations/swift-executors/Experiments/sigsegv-repro/` PASSES on every 6.5-dev nightly sampled. The `swift-array-primitives` DeinitDevirtualizer SIL assertion still affects a full `swift-executors swift test` run on 6.5-dev (because that package's transitive dep graph includes `swift-array-primitives`), but does NOT block the standalone reproducer, whose direct deps (`swift-tagged-primitives` / `swift-ordinal-primitives` / `swift-cardinal-primitives`) bypass `swift-array-primitives`. The bug is therefore distinct from and independent of the DeinitDevirtualizer regression, and is genuinely fixed in the 6.4-dev → 6.5-dev nightly stream (exact commit window not yet pinpointed).

**Workaround commits — REVERTED** (resolves the prior "Evergreen fix shape" claim in this entry):

The four typed-surface-wrapper-over-raw-storage commits listed in this entry's `Evergreen fix shape` table were REVERTED on 2026-05-23 by orchestrator decision (per `feedback_correctness_and_evergreen.md` — degrading typed storage discipline for an unblock is not acceptable on correctness grounds):

| Original workaround commit | Revert commit | Repo |
|---------------------------|---------------|------|
| `88780ee` (Ordinal.AtomicPosition<Tag>) | `e46b3b7` | swift-primitives/swift-ordinal-primitives |
| `dd34b04` (Stealing/Sharded cursor switch) | `106d914` | swift-foundations/swift-executors |
| `a79ca49` (Kernel.Event.Driver registry) | `44ab1f8` | swift-foundations/swift-kernel |
| `7c3c6207` (Completion.Actor.entries) | `b77a4f03` | swift-foundations/swift-io |

The three handoff-flagged packages (swift-executors, swift-threads, swift-io) currently SIGSEGV on Apple Swift 6.3.2 with no landed Institute-side workaround. Resolution path per `[ISSUE-008]`: wait for the Swift 6.5 release, which carries the upstream fix.

**Bare-`swiftc` reduction — five-shape attempt; v1 untested** (refines the `Upstream filing status: NOT YET FILED` paragraph's "should wait for a bare-`swiftc` reduction" note):

Arc 4 attempted bare-`swiftc` reduction across five shapes (full source in `/tmp/sigsegv-bare/`, not committed):

| Shape | Description | Result on 6.3.2 |
|-------|-------------|-----------------|
| **v1** single-file with full Tagged | `@frozen`, `package(set)`, `@_lifetime`, `~Escapable` storage, all conformances | **NOT TESTED** — compile-errored at the unflagged `swiftc` invocation; the errors (`-package-name` / `-enable-experimental-feature Lifetimes` / `~Escapable`-storage ergonomics) are resolvable with the required flag scaffolding, but the retry was not performed |
| v2 single-file simplified Tagged + inline `AtomicRepresentable` + `Atomic<Tagged>.load + compareExchange` | local-copy Tagged without `package(set)` / `@_lifetime` / `~Escapable` | **PASS** |
| v3 two-module split (Tagged + inline conformance in module A; consumer in B) | tests whether cross-module is the trigger | **PASS** |
| v4 three-module split (Tagged / `@retroactive AtomicRepresentable` conformance / consumer) | tests whether sibling-submodule conformance is the trigger | **PASS** |
| v5 four-module split with generic Atomic extension | Tagged / Conformance / Atomic extension `bumpZero` / consumer | **PASS** |

Per `[ISSUE-026]` coverage-scope discipline, the truthful conclusion from this experiment is:

> v2–v5 (four simplified-Tagged shapes) all PASS on 6.3.2 — none of the simplified bare-`swiftc` shapes reproduces. Combined with Arc 3's nine-candidate Tagged.swift single-file bisection and Arc 1's local-wrapper-shape non-reproduction, the *conditional* conclusion is consistent: the production `Tagged_Primitives.Tagged` symbol with its production module structure appears to be load-bearing.
>
> The v1 hypothesis (full-attribute single-file with the required flag scaffolding) is **UNTESTED**. It may reproduce in isolation; it may not. The four-shape attempt does NOT empirically close that question. Pursuing v1 is deferred — per `[ISSUE-008]` resolution path ("Fixed on dev toolchain, not in Xcode → apply workaround, document, wait for release"), further reduction effort is not load-bearing for the resolution decision.

The canonical reproducer preserves `import Tagged_Primitives` (with `Ordinal_Primitives` / `Cardinal_Primitives` for the `.advance(within:)` extension and the `Cardinal` Underlying) per `[ISSUE-002]`'s "If the issue requires SwiftPM" branch — *accommodating* the SwiftPM dependency, not *proving* SwiftPM is required.

**v1 retry update (2026-05-23)**: v1 was subsequently retried with the four-flag scaffolding (`swiftc -O -package-name v1pkg -enable-experimental-feature Lifetimes -enable-experimental-feature SuppressedAssociatedTypes`). Two triggers exercised:

- **Trigger A** — `Atomic<Tagged<SimpleTag, Int>>.load(ordering: .relaxed)` (production-verbatim Tagged declaration with `@_lifetime(copy underlying)`, `package(set)`, `~Escapable` storage, full conditional Copyable/Escapable/Sendable/BitwiseCopyable/Equatable/Hashable/Comparable conformance chain, `modify` extension, inline `AtomicRepresentable` conformance). Result: **PASS** (compile + run + exit 0).
- **Trigger B** — `Atomic<Tagged<SimpleTag, UInt>>.bumpZero(within:)` with a generic-extension whose where-clause chain (`Value.AtomicRepresentation == UInt.AtomicRepresentation` + `C.AtomicRepresentation == UInt.AtomicRepresentation`) mirrors production `.advance(within:)`'s metadata-forcing same-type-constraint shape. Result: **PASS** (compile + run + exit 0).

Files at `/tmp/sigsegv-v1/v1_trigger_a.swift` (123 lines) and `/tmp/sigsegv-v1/v1_trigger_b.swift` (164 lines), not committed (empirical scratch).

With v1 added, the empirical record now reads: all five bare-`swiftc` reduction shapes (v1 full-attribute single-file + v2 simplified single-file + v3 two-module split + v4 three-module retroactive-conformance split + v5 four-module split with generic Atomic extension) PASS on 6.3.2 — none of the five reproduces. Combined with Arc 3's nine-candidate `Tagged.swift` single-file bisection (also fails to fix the crash) and Arc 1's local-wrapper-shape non-reproduction, the production `Tagged_Primitives.Tagged` symbol with its production module structure is **strongly supported** as the load-bearing trigger — not just consistent with prior evidence but empirically tested against the strongest single-file approximation that fits the bare-`swiftc` budget.

**Remaining caveat** (per `[ISSUE-026]` coverage-scope discipline): v1's Trigger B captures the same-type-constraint *shape* used by production `.advance(within:)` but drops the specific protocol identities (`Ordinal.\`Protocol\`` / `Carrier.\`Protocol\`<Cardinal>` / `Cardinal`) because inlining them would exceed a reasonable single-file budget (~200 lines). If the bug is gated by those specific protocol identities rather than the constraint shape, that cell remains untested. A Trigger C with full protocol-identity scaffolding was orchestrator-decided 2026-05-23 to be diminishing returns — per `[ISSUE-008]` resolution path ("Fixed on dev toolchain, not in Xcode → wait for release"), further reduction is not load-bearing for the resolution decision.

**Issues directory staged** (resolves the `NOT YET FILED` paragraph's filing-prep half):

`swift-institute/Issues/swift-issue-tagged-noncopyable-atomic-metadata-crash/` is now the canonical public-facing reproducer + record. Contains:

- `README.md` — bug summary, toolchain matrix, crash signature, trigger characterization, workaround status (no landed workaround)
- `INVESTIGATION-ARC.md` — full 4-arc convergence record including ecosystem blast radius (4 confirmed crash sites + 1 possibly-affected) + 3-axis bisection matrix (Atomic / Dictionary container / Value-side suppression)
- `SIBLING-COMMENT-DRAFT.md` — staged data-point comment for posting on [`swiftlang/swift#74303`](https://github.com/swiftlang/swift/issues/74303) (the existing open `__swift_instantiateConcreteTypeFromMangledName`-null-return issue with DiscordBM Codable+Optional reproducer); NOT a new issue and NOT a 6.3.x-backport request. Pending orchestrator authorization to post.
- `Sources/Reproducer/main.swift` — SwiftPM executable; on 6.3.2 exits 139, on 6.5-dev prints `result = 0` exit 0
- `Tests/Reproducer.swift` — `withKnownIssue("…", when: { #if compiler(<6.5) … })` harness

The Issues `Package.swift` adds three external deps (`swift-tagged-primitives` / `swift-ordinal-primitives` / `swift-cardinal-primitives`) — the only Issues entry to require external deps, documented in the package manifest as the per-issue accommodation for the SwiftPM-only-reproducer case. Issues repo HEAD as of Arc 4 commit: `336cbe8`.

**Upstream-duplicate search result** (per `[ISSUE-007]`):

`gh search issues` against `swiftlang/swift`:

- [`#74303`](https://github.com/swiftlang/swift/issues/74303) — OPEN — DiscordBM `IntBitField<Flag>?` Codable+Optional. Same family (`__swift_instantiateConcreteTypeFromMangledName` null return), different domain.
- [`#69615`](https://github.com/swiftlang/swift/issues/69615) — OPEN — Kubrick `@JobBuilder buildBlock` opaque-return-type metadata (`getTypeByMangledNameInContext` TypeLookupError). Same family, different domain.
- `#74333` — CLOSED — dupe of `#74303`.

No exact-shape duplicate for cross-module conditional `AtomicRepresentable` conformance with `~Copyable` Tag suppression. The two open issues confirm `swift_getTypeByMangledName → TypeLookupError("unknown error")` is a broader runtime defect class with distinct domain instances; our entry is a new sibling.

**Three-axis bisection matrix** (orchestrator 2026-05-23 ecosystem mapping):

| Axis | Status |
|------|--------|
| A. Does plain `Atomic<Tagged<Copyable_X, Copyable_U>>` crash by itself, or are Tag/Underlying suppressions load-bearing? | PARTIAL — Atomic<Tagged<>>.load PASSES; only `.advance(within:)` generic extension crashes. Tag/Underlying suppression on the conformance side ruled out (Shape A1 refuted). OPEN: whether a generic extension method without Ordinal.Protocol constraints still triggers on `Tagged_Primitives.Tagged<X, UInt>`. |
| B. Container choice — stdlib `Swift.Dictionary` vs institute `Dictionary_Primitives.Dictionary`? | RULED OUT as discriminator — site 3 (kernel, institute Dict) and site 4 (io, stdlib Dict) both crash; both have `~Copyable` Value. |
| C. Value-side suppression — `~Copyable Value` required, or does Copyable Value also crash? | LIKELY LOAD-BEARING — swift-linter's `[Lint.Rule.ID: Lint.Rule]` (stdlib Dict, Copyable Value) PASSES; ecosystem sites with `~Copyable` Value CRASH. Untested: institute Dictionary + Copyable Value. |

The collapsed signal: `~Copyable` somewhere in the type's full mangled name (Atomic's own `~Copyable Self` or Dictionary's `~Copyable Value`) + Tagged_Primitives.Tagged in a generic-arg slot + generic-method dispatch needing full type metadata = trigger. Pinpointing further requires upstream-side bisection out of scope for Arc 4 per `[ISSUE-022]`.

#### §A9 Correction (2026-05-23) — Snapshot version labels

The toolchain tables in §A9 Update (Arc 4) and §v1 retry update label three snapshots uniformly as "Swift 6.5-dev". Empirical `swift --version` shows the first two are actually **6.4-dev**; only the third is **6.5-dev**:

| Bundle ID | Snapshot date | Empirically-reported version |
|-----------|---------------|------------------------------|
| `org.swift.64202603161a` | 2026-03-16-a | `Apple Swift version 6.4-dev` (LLVM `a3655ee8d8c4d74`, Swift `d13cbbfd336f246`) |
| `org.swift.64202605071a` | 2026-05-07-a | `Apple Swift version 6.4-dev` (LLVM `d2079213f1d4451`, Swift `82b7720768ba875`) |
| `org.swift.64202605121a` | 2026-05-12-a | `Apple Swift version 6.5-dev` (LLVM `7c86461e21cca7e`, Swift `6da4da7153e8252`) |

The bug-status conclusion is unchanged — all three nightlies PASS; the fix landed in main on or before `2026-03-16-a` (commit `d13cbbfd336f246` cut). The version-label discrepancy is naming only.

---

### A10. Unconditional protocol-conformance extension leaks `Copyable` to primary declaration of `~Copyable`-generic nested type

**Swift versions**: 6.3.2 (Xcode 26.4.1 default, `swiftlang-6.3.2.1.108`) and 6.4-dev nightly (`swift-latest.xctoolchain`) — STILL BROKEN on both. Investigation 2026-05-23.

**Pattern**:

```swift
public enum Storage<Element: ~Copyable> {}
public protocol Marker: ~Copyable {
    associatedtype Element: ~Copyable
}

extension Storage where Element: ~Copyable {
    public struct Inline: ~Copyable {
        public init() {}
        public func foo() {
            _ = Element.self   // ← error: type 'Element' does not conform to protocol 'Copyable'
        }
    }
}

extension Storage.Inline: Marker {}   // ← THE TRIGGER (no `where Element: ~Copyable`)
```

**Symptom**: `error: type 'Element' does not conform to protocol 'Copyable'` fires at every reference to `Element` inside the nested type's body, even though the body's enclosing extension correctly declares `where Element: ~Copyable`.

**Mechanism (hypothesized)**: per SE-0427 Noncopyable Generics, "An extension of a concrete type must introduce a default `T: Copyable` requirement on every generic parameter of the extended type." The unconditional `extension Storage.Inline: Marker { … }` adds an implicit `Element: Copyable` requirement, which the implementation propagates beyond the extension's scope — back to the type's primary declaration and any sibling extensions. Expected behavior is for the constraint to apply only within the extension's body.

**Trigger conditions (all required)**:

1. `enum Storage<Element: ~Copyable>` root namespace.
2. Nested type declared in `extension Storage where Element: ~Copyable { struct Inline: ~Copyable { … } }`.
3. At least one reference to `Element` inside Inline's body (`@_rawLayout(likeArrayOf: Element, …)`, `Element.self`, `Index<Element>.…`, etc.).
4. **Unconditional** protocol-conformance extension `extension Storage.Inline: SomeProtocol { … }` (no `where Element: ~Copyable`), where `SomeProtocol` has an `associatedtype Element: ~Copyable` requirement OR is implicitly Copyable.

**Bug fires regardless of**: cross-module vs same-module split (V10 / V16 / V17 all fail in same module), file separation (V7 / V17 fail in single file), `@_rawLayout` presence (V4 / V12 / V14 / V15 / V17 fail without it), `deinit` presence (V3 / V13 / V14 / V17 fail without it), access level (V9 with `package` still fails), and inner-type repeated `where` clause (V8 fails).

**Workaround (verified)**: **Workaround D** — add `where Element: ~Copyable` to the conformance extension:

```diff
- extension Storage.Inline: Marker {
+ extension Storage.Inline: Marker where Element: ~Copyable {
      // body unchanged
  }
```

The constraint is INCLUSIVE — it allows the conformance for both Copyable and ~Copyable Element types. Verified on production source: `swift-storage-primitives/Sources/Storage Inline Primitives/Storage.Inline+Memory.Contiguous.Protocol.swift` line 69, single-character change, full target builds clean.

**Reproducer**: `swift-institute/Issues/swift-issue-rawlayout-noncopyable-extension-rejection/` — 17-variant variable-isolation table; minimum reproducer is **single file, single module, 13 lines, no `@_rawLayout`, no `deinit`, no `let-capacity`** (V17). The `@_rawLayout` / cross-module / deinit structure of the production blocker are NOT load-bearing for the trigger.

**Production blocker**: `swift-primitives/swift-storage-primitives@ee86ee0` (Cohort III Pilot 1 [MOD-031] restructure) — `Storage Inline Primitives` target. Error sites at `Sources/Storage Inline Primitives/Storage.Inline.swift` lines 97, 139, 142, 143; trigger at `Storage.Inline+Memory.Contiguous.Protocol.swift` line 69.

**Upstream filing**: NOT YET FILED. Pending principal authorization. No exact-shape duplicate found in `swiftlang/swift` issues via the keyword combinations searched (see `INVESTIGATION-ARC.md` §8). SE-0427 documents the implicit `Copyable` rule but not the cross-sibling leak; the leak appears to be an implementation defect against the proposal's documented scope.

**Cross-references**: related but DISTINCT — § (master fix-status table) entry for `swiftlang/swift#86652` (~Copyable nested-deinit / `@_rawLayout` ELEMENT DESTRUCTION) is a runtime bug. § A10 is compile-time. § B3 (Tagged constrained-extension nested-type ambiguity) is also type-checker but on Tagged-instantiation typealiases, different mechanism. Memory entry `feedback_extension_implies_copyable.md` documents the implicit-Copyable rule on bare extensions; the LEAK behavior across sibling declarations is what § A10 newly identifies.

---

### A11. `DiagnoseStaticExclusivity` SIGSEGV on a borrow returned through a `~Copyable` enum payload

**Pattern**: An `@inlinable` accessor returns a borrow — a `Span`, a `MutableSpan`, or a `_read`/borrow-view projection — obtained from a payload bound inside a `switch` over a `~Copyable` enum:

```swift
var span: Span<Element> {
    @_lifetime(borrow self) @inlinable borrowing get {
        switch _storage {
        case .heap(let inner):  return inner.span        // SIGSEGV
        case .inline(let inner): return inner.span
        }
    }
}
// Also fires through a `_read` borrow-view whose result is a COPY:
//   case .heap(let inner): return inner.peek.front      // SIGSEGV (peek is `_read { yield View(self) }`)
```

**Symptom**: `emit-module command failed due to signal 11` → `While running pass #N SILModuleTransform "DiagnoseStaticExclusivity"` → `DiagnoseStaticExclusivity::run() + 5000`. Fires only for `@inlinable` accessors (the emit-module path processes inlinable bodies); the identical body marked **non-`@inlinable`** compiles.

**Swift version**: 6.3.2 (swiftlang-6.3.2.1.108), Xcode default toolchain, SDK MacOSX26.5, macOS 26 arm64. **Still broken.**

**Workaround**: source the inner base pointer via a package-scoped window, build the `Span`/`MutableSpan`/element **outside** the `switch`, and mark the op **non-`@inlinable`** (the `package` window is not cross-package-inlinable). Consumers reach the op via a static call — **no `witness_method`**, so the SIL acceptance bar is preserved; the only cost is a non-inlined call boundary. Mark each site with `// TODO(C):` to restore `@inlinable` + the elegant `.span` delegation when fixed.

**Evidence**: verified in-package in `swift-buffer-linear-primitives` (`Buffer.Linear.Small` refined-C arc, 2026-05-24). **Context-sensitive**: a standalone `~Copyable` enum + Span-delegation shape does NOT reproduce even with generics + `@inlinable` + `deinit` (3 clean reduction variants). Candidate missing triggers: class-backed `~Copyable` storage handle, `@_rawLayout` storage, the inner `.span`'s `_overrideLifetime`, two-level delegation. Reproducer + ingredient list: `swift-buffer-linear-primitives/Experiments/small-span-diagnose-static-exclusivity-crash/`.

**Upstream filing**: NOT YET FILED (DRAFT at the experiment dir, pending principal authorization + standalone-reducer isolation per [ISSUE-013]/[EXP-021]).

**Source**: 2026-05-24 refined-C Small (A) execution on swift-buffer-linear-primitives.

---

## B. Type-System Pitfalls and Language-Spec Constraints

### B1. `Property.View ~Copyable` extension constraint placement

**Swift versions**: 6.3.x (language spec — implicit `Base: Copyable` insertion).

**Statement**: When extending `Property.View.Typed` (or `.View`) for containers with `~Copyable` elements, ALL constraints (`Tag ==`, `Base ==`, `Element: ~Copyable`) MUST be at the **extension level**, NOT the method level. The compiler adds implicit `Base: Copyable` when `Base` isn't concretely constrained at extension level.

**Shape options**:
- 1 value generic: `Property.View.Typed<Element>.Valued<N>`
- 2 value generics: `Property.View.Typed<Element>.Valued<N>.Valued<capacity>`
- `Valued.Valued` was added to `swift-property-primitives` on 2026-02-12.

**Reference**: `swift-property-primitives/Experiments/view-typed-overload-coexistence/`.

**Source: `property-view-noncopyable-pattern.md` (deleted 2026-05-10 in Wave 6).**

---

### B2. `Property.View` rejected on `Copyable` types — use `Property<Tag, Base>` for `@CoW`

**Swift versions**: 6.3.x (language spec — `~Escapable` result from mutating method on Copyable type is rejected).

**Statement**: `Property<Tag, Base>` is correct for `@CoW` Copyable types. `Property.View` is compiler-rejected for Copyable types ("error: ~Escapable result from mutating method"). The v1 research document incorrectly recommended Property.View for `@CoW` types.

**For `@CoW` types**:
```swift
public var emit: Property<Emit, Self> {
    get { Property(self) }
    _modify {
        var property = Property<Emit, Self>(self)
        defer { self = property.base }
        yield &property
    }
}
```

No transfer dummy needed — `@CoW`'s `_read` / `_modify` property accessors handle uniqueness via `ensureUnique()` inside `_modify`. First mutation copies once (refcount 2→1); subsequent mutations are free.

**Reference**: `swift-institute/Research/property-view-for-cow-copyable-types.md` (v2).

**Source: `cow-property-pattern.md` (deleted 2026-05-10 in Wave 6).**

---

### B3. Tagged constrained-extension nested-type ambiguity

**Swift versions**: 6.3.1 (still broken; CONFIRMED 2026-05-02 on Apple Swift 6.3.1 system default).

**Rule**: NEVER declare nested types (`typealias`, `enum`, `struct`) inside `extension Tagged where Tag == X, RawValue == Y`. Swift's constrained-extension nested-type lookup IGNORES the where-clause filter and treats the declarations as candidates across ALL `Tagged<…>` instantiations, causing `ambiguous type name` errors at consumer sites.

**Empirical case (Wave 3.5-Corrective Phase 2 at swift-posix, 2026-05-02)**:
```swift
extension Tagged where Tag == POSIX, RawValue == ISO_9945.Kernel.File.Open {
    public typealias Error = ISO_9945.Kernel.File.Open.Error
    public typealias Options = ISO_9945.Kernel.File.Open.Options
}
```

Caused `error: ambiguous type name 'Error' in 'POSIX.Kernel.File.Open' (aka 'Tagged<POSIX, ISO_9945.Kernel.File.Open>')` at swift-kernel because `swift-memory-primitives/Memory.Address.Error.swift` already declared:

```swift
extension Tagged where Tag == Memory, RawValue == Ordinal {
    public enum Error: Swift.Error, ... { ... }
}
```

Both `Error` declarations show up as candidates in `Open.Error` lookup despite incompatible where-clauses (`Tag == POSIX, RawValue == ISO_9945.Kernel.File.Open` vs `Tag == Memory, RawValue == Ordinal`).

**Workaround — namespace `enum`** instead of `Tagged` typealias:

```swift
// ❌ Avoid — Tagged with nested types creates cross-instantiation ambiguity
extension POSIX.Kernel.File {
    public typealias Open = Tagged<POSIX, ISO_9945.Kernel.File.Open>
}
extension Tagged where Tag == POSIX, RawValue == ISO_9945.Kernel.File.Open {
    public typealias Error = ISO_9945.Kernel.File.Open.Error
}

// ✓ Prefer — namespace enum has unambiguous nested types
extension POSIX.Kernel.File {
    public enum Open {
        public typealias Error = ISO_9945.Kernel.File.Open.Error
    }
}
extension POSIX.Kernel.File.Open {
    public static func open(...) throws(Error) -> ... { ... }
}
```

The namespace enum gives:
- A distinct nominal type (breaks recursion when delegating to L2 since `POSIX.Kernel.File.Open.open` ≠ `ISO_9945.Kernel.File.Open.open`).
- Unambiguous nested types (consumer `Open.Error` resolves cleanly).

**Tradeoff**: Loses Tagged-via-Carrier dispatch unification. Carrier conformance at the L1/L2 carrier type still provides `T.underlying` for layer-agnostic generics — Tagged is not required for that.

**Existing precedent — when Tagged with nested types DOES work**: Tagged hosting a SINGLE nested-type declaration within the workspace works (e.g., `Memory.Address.Error` is the only `Tagged.Error` in swift-memory-primitives — no clash). The pitfall only triggers when **two or more** Tagged constrained extensions declare identically-named nested types anywhere in the dependency graph.

**Reproducer**: `swift-institute/Experiments/tagged-cross-instantiation-nested-type-ambiguity/` — 4-target minimal repro. Diagnostic: `error: ambiguous type name 'Error' in 'Tagged<TagA, RawA>'` with both LegA's typealias (NestedAError) and LegB's typealias (NestedBError) listed as candidates despite LegB's where-clause being `RawValue == RawB`. Type-check error (debug + release both fail; not optimization-dependent).

**Branching investigation**: `HANDOFF-constrained-extension-nested-type-lookup-prior-art.md` queued at `/Users/coen/Developer/` to map upstream + cross-language prior art and decide whether to file SE-discussion. Comparison: Rust impls / C++ template specializations / Haskell type families all DO discriminate at this lookup point.

**Source: `tagged-nested-type-ambiguity-pitfall.md` (deleted 2026-05-10 in Wave 6).**

---

### B4. Tagged generic param can be `Underlying` (despite typealias collision) — works under specific recipe

**Swift versions**: 6.3.1 (verified 2026-05-03 with `-enable-experimental-feature Lifetimes -enable-experimental-feature SuppressedAssociatedTypes`).

**Statement**: When Tagged's generic parameter is named `Underlying` AND it conforms to `Carrying` (or `Carrier.\`Protocol\``) with associated type also named `Underlying`, the design FAILS if conformance is in the type body OR if witness signatures use unqualified `Underlying`.

**SUCCESS recipe**:
1. Carrying conformance lives in a separate `extension Tagged: Carrying { ... }` block (NOT in the type body).
2. Witness signatures use `Self.Underlying` qualification: `var underlying: Self.Underlying`, `init(_ underlying: consuming Self.Underlying)`.
3. Init body uses unqualified `Underlying` to refer to the generic parameter: `self.init(_unchecked: Underlying(underlying))`.
4. `@_lifetime(copy underlying)` is on the protocol declaration only; conformers don't repeat.

**Verification**: 3-deep nesting spike at `/tmp/underlying-shadowing-spike/spike-final.swift` using `-enable-experimental-feature Lifetimes -enable-experimental-feature SuppressedAssociatedTypes` on Swift 6.3.1.

**Why this surfaced**: Initial spike used in-body conformance with unqualified `Underlying` — produced "candidate has non-matching type 'Underlying'" because Swift binds unqualified `Underlying` to the generic parameter. Concluded incorrectly that the rename couldn't work and proposed renaming the generic param to `Wrapped`. User pushed back saying prior research validated this works. They were right; the spike was structurally wrong.

**How to apply**: When designing or reviewing Tagged's Carrying conformance with `Underlying` as both the generic parameter and the protocol's associated type, ALWAYS use the extension+`Self.Underlying` pattern. Don't propose renaming the generic parameter to avoid the collision — the collision is solvable.

**Source: `tagged-underlying-as-generic-param.md` (deleted 2026-05-10 in Wave 6).**

---

### B5. Pack same-type requirements with concrete types — "not yet supported"

**Swift versions**: 6.2.4 / 6.3.x (language spec — known limitation per `swiftlang/swift` `test/Generics/variadic_generic_types.swift:128`).

**Statement**: Swift does NOT unwrap parameter pack types inside concrete extensions. "Same-type requirements between packs and concrete types are not yet supported."

**Symptoms**: Inside `extension Product<Int, String, Double>`, `values` (typed `(repeat each Element)`) is NOT narrowed to `(Int, String, Double)`. Direct assignment, `.0` access, and `self.0` via `@dynamicMemberLookup` all fail. The runtime type IS correct (`type(of: self)` shows `Product<Pack{Int, String, Double}>`), but the static type system doesn't unwrap.

**What works**:
- Concrete extension declarations compile (improvement over Swift 5.9 ABI target).
- `as!` forced cast to concrete tuple type at runtime.
- External `.0` / `.1` access via `@dynamicMemberLookup` at call site.
- Free functions with generic constraints CAN constrain pack shapes.
- Pack iteration for `AdditiveArithmetic` (`.zero`, `+`, `-`).

**What doesn't**:
- `values.0` inside extension body.
- `let t: (Int, String) = values` (direct assignment).
- Generic pack-shape extensions (no syntax for unbound generics).
- `where (repeat each T) == (Int, Int)` same-type constraints.

**Reference**: `swift-institute/Experiments/parameter-pack-concrete-extension/` (verified empirically).

**Source: `pack-concrete-same-type.md` (deleted 2026-05-10 in Wave 6).**

---

### B6. `var → let` false positive on `~Copyable` enum-payload binding

**Symptom**: the compiler's "variable was never mutated; consider changing to 'let'" warning fires on `case .x(var buf):` bindings where `buf` is a `~Copyable` payload, even when `buf` is never mutated. **Following the warning breaks the build**: `case .x(let buf)` only *borrows* the payload, but the code path *consumes* it (moves it out — hands it to a `consuming` API, returns it, reinitializes the enum). `var` is required for the consuming move-out; `let` grants only a borrow.

**Rule**: do NOT apply the "consider let" cleanup on `~Copyable` enum-payload bindings (`switch` / `if case` over a `~Copyable` enum). Treat the warning as a false positive there. An incremental build can mask the breakage — only a clean build surfaces it.

**Provenance**: 2026-05-24 buffer refined-C arc (`swift-buffer-linear-primitives`, `Buffer.Linear.Small._Representation`); a var→let "tidy" on 7 sites broke the clean build. Composes with [MOD-037] and the `~Copyable` satellite work.

---

## C. Patterns and Reference Tables

### C1. Actor isolation — three mechanisms model

**Swift versions**: 6.3.x (language spec).

Three mechanisms for actor transactional access, each with distinct trade-offs:

| Mechanism | Closure | `@Sendable` | Borrow `~Copyable` | Cross-actor | Use when |
|-----------|---------|-------------|---------------------|-------------|----------|
| `actor.run { }` | Yes (escaping) | Yes | No | Sync: no / Async: yes | General batching, stream operators |
| `actor.assumeIsolated { }` | Yes (non-escaping) | No | Yes | N/A (must be on executor) | Shared-executor cross-actor access |
| `f(on: isolated Actor)` | No | No | Yes | Via `assumeIsolated` | Direct actor access with `~Copyable` borrows |

**Discovery context**: Point-Free `#362` study + 5 experiments. Applied `Actor.run` to 6 swift-async operators and `isolated` parameter to `IO.Event.Selector.register` (2 hops → 1).

**How to apply**:
- Default to `Actor.run` for batching multiple actor operations.
- Use `isolated` parameter when `borrowing ~Copyable` must cross actor boundary (no closure → borrow survives).
- Use `assumeIsolated` for cross-actor on shared executors from within sync `run` context.
- Combine: `run` to enter executor + `assumeIsolated` for cross-actor + borrowing.

**Source: `actor-isolation-three-mechanisms.md` (deleted 2026-05-10 in Wave 6).**

---

### C2. Typed throws — Swift 6.2.4 stdlib support matrix

**Swift versions**: 6.2.4 / 6.3.x (language spec — partial typed-throws support; NO compiler flags needed).

**WORKS** with explicit `throws(E)` closure annotation:
- `Sequence.map`, `withUnsafeBytes(of:)`, `withUnsafeMutableBytes(of:)`, `Mutex.withLock`.

**FAILS** (`rethrows` still erases `E`):
- `compactMap`, `flatMap`, `filter`, `forEach`, `reduce`, `contains(where:)`, `allSatisfy`, `first(where:)`, `sorted(by:)`, `min(by:)`, `max(by:)`, `drop(while:)`, `prefix(while:)`, `withContiguousStorageIfAvailable`, `withUnsafeTemporaryAllocation`.

**Critical pitfall**: `@_disfavoredOverload` same-name overloads INTERFERE with stdlib's native support. Do NOT add `@_disfavoredOverload map<T, E: Error>`.

**Consumer cost**: Closures need explicit annotation: `{ (x: T) throws(E) -> U in ... }`. Implicit `{ try f($0) }` infers `any Error`.

**Future fix**: `FullTypedThrows` experimental feature in compiler source — not yet in production toolchains.

**Throws covariance**: Swift 6.2.4 DOES support narrowing `throws` → `throws(E)` on conformances. Blocker for Codable is downstream APIs, not the conformance itself.

**Reference**: `swift-standard-library-extensions/Experiments/typed-throws-overload-resolution/`, `swift-standards/Experiments/typed-throws-protocol-conformance/`.

**Source: `typed-throws-stdlib.md` (deleted 2026-05-10 in Wave 6).**

---

### C3. Typed throws — catch blocks preserve concrete typed error

**Swift versions**: 6.3.x (language spec).

**Statement**: In Swift 6 with typed throws, `error` in a `catch` block IS the concrete typed error (e.g., `IO.Lifecycle.Error<Lane.Error>`), NOT `any Error`. Methods like `mapFailure` work directly on the caught error.

**How to apply**: When a catch block follows a `do` with typed throws, treat the caught error as the concrete type. Don't manually re-implement switch mappings that existing methods already handle.

**Why this surfaced**: An incorrect assumption that catch blocks always give `any Error` led to reverting a `mapFailure` call to a manual switch. The real compilation failure was a cascade from an unrelated `@escaping` bug.

**Source: `typed-throws-catch-blocks.md` (deleted 2026-05-10 in Wave 6).**

---

## Cross-References

- **issue-investigation** skill `[ISSUE-028]` — the rule that mandates consultation of this catalog.
- **swift-package-build** skill `[PKG-BUILD-001]` / `[PKG-BUILD-007]` / `[PKG-BUILD-008]` — toolchain selection and Embedded build mechanics; this catalog's verification anchors depend on the same toolchain matrix.
- `swift-institute/Research/swift-6.3-revalidation-status.md` — canonical revalidation document referenced from the master fix-status table.
- `swift-institute/Research/swift-6.3-ecosystem-opportunities.md` — per-package 6.3 migration plan.
- `swift-institute/Audits/swift-6.3.1-revalidation-sweep-2026-04-30.md` — verification audit for the master fix-status table.

## How to add a new entry

1. Verify the bug empirically (minimal reproducer, toolchain pin).
2. Choose a section: A (miscompiles / SIL crashes), B (type-system pitfalls / language-spec), or C (patterns / reference tables).
3. Append a row to the Table of Contents with bug-class, Swift version, one-line symptom, and target section number.
4. Append the per-entry section with: pattern, symptom, workaround, evidence, upstream filing status, source citation.
5. If the entry is sourced from a deleted memory file, cite `Source: <filename>.md (deleted YYYY-MM-DD in Wave N)`.
6. Update `last_reviewed` and `last_verified` in the frontmatter.
