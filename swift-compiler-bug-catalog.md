---
title: Swift Compiler Bug Catalog
tier: 2
scope: cross-package
status: REFERENCE
created: 2026-05-10
last_reviewed: 2026-05-10
last_verified: 2026-04-30
toolchains:
  - Swift 6.3.1 (Xcode 26.4.1, swiftlang-6.3.1.1.2)
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
### Fixed upstream on 6.4-dev nightly-main (awaiting backport or 6.4 release)

| Bug | Upstream ID | Workaround for shipped 6.3.x | Evidence |
|-----|-------------|------------------------------|----------|
| Array-literal storage + chained `index_addr` `+M, −N` with compile-time-constant offsets miscompiles under `-O` / `-Osize` (macOS arm64 + Linux x86_64). DSE eliminates the live stores at intermediate array-literal indices, so the chained load reads uninitialized storage. | [`swiftlang/swift#77558`](https://github.com/swiftlang/swift/issues/77558) (existing upstream report from 2024-11-12). Confirmation [comment](https://github.com/swiftlang/swift/issues/77558#issuecomment-4425028051) posted 2026-05-11 under `coenttb` (empirical narrowing: SwiftPM-test-runner-path firing on `swift:6.3-jammy`; bare `swiftc -O` does not reproduce on current 6.3.x distributions; fix-detection harness flips red on `nightly-main-jammy`). | Subscript `buf[i]` OR single positive `.advanced(by:)` OR use `Array(repeating:count:)` instead of literal init. Narrower trigger than initially scoped — does NOT bug with non-literal init, ARC-bearing elements, parameterized offsets, or manual `UnsafeMutableBufferPointer.allocate`. See `swift-affine-primitives/Research/swift-issue-pointer-arithmetic-workaround.md`. | 8-line standalone `swiftc -O` reproducer at `swift-institute/Issues/swift-issue-pointer-arithmetic-linux-miscompile/`. SIL byte-identical between with/without `unsafe` keyword. Optimized SIL keeps only stores at offsets 0 and 4 of the 5-element literal; chained `index_addr +4, −2` reads from offset 2 (eliminated). Linux `-Osize` per-run variance is uninitialized-memory signature. **Fixed on `swiftlang/swift:nightly-main` (Swift 6.4-dev, commit `82b7720768ba875`).** Candidate fix-commits (2025-10-10 quad): `1cbed39f326` (COWOpts), `de557cab56f` (ArrayCountPropagation), `71381fab3c0` (ConstExpr), `02fafc63d67` (ForEachLoopUnroll) — all "Optimizer: support the new array literal initialization pattern". Investigation arc with false trails (.Lifetimes, `unsafe` keyword, operator wrapping — all ruled out) at `swift-institute/Issues/swift-issue-pointer-arithmetic-linux-miscompile/INVESTIGATION-ARC.md`. |
| Parameterized-typealias + Base-constrained extension on a generic type in an imported module's scope triggers "failed to produce diagnostic for expression" ICE during test-target compilation of files that contain parameterized-protocol opaque-return type declarations (`var body: some P<TypeParam, Output, Error> { ... }`). Both `public typealias X = Generic<Concrete>` and `public extension Generic where Base == Concrete { ... }` are independently sufficient triggers. | Not yet filed (fix is on 6.4-dev nightly-main snapshot `swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a`; upstream commit search pending). | **File-split**: keep parser declarations and test method bodies in separate files. The parser-declaration file does NOT import the module exposing the parameterized typealias. The test-method-body file DOES import it. Test H8 confirmed: removing the import from the parser-declarations file eliminates the ICE. See § A8. | In-cohort reproducer: `swift-ascii-parser-primitives/Tests/Declarative Parser Syntax Tests/Declarative Parser Syntax Tests.swift` at baseline commit `17b97da`, with `swift-parser-primitives` at `eb01abd` or any commit exposing `Parser.Test.Input` as a public typealias. 4 ICEs at lines 121/162/205/258. Single-file `swiftc` and 2-module minimal SwiftPM did NOT reproduce — full trigger requires multi-module + complex body builder (result builder, chained `.map` transformations). Full investigation arc (11 hypothesis tests, 8 disconfirmed) at `swift-institute/Issues/swift-issue-parameterized-typealias-opaque-return-ice/INVESTIGATION-ARC.md`. |

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
| B1 | `Property.View ~Copyable` extension constraint placement | 6.3.x (lang spec) | All constraints MUST be at extension level, not method level — implicit `Base: Copyable` else |
| B2 | `Property.View` rejected on `Copyable` types (~Copyable + ~Escapable result from mutating method) | 6.3.x (lang spec) | Use `Property<Tag, Base>` for `@CoW` Copyable types instead |
| B3 | Tagged constrained-extension nested-type ambiguity | 6.3.1 (still broken) | `extension Tagged where Tag == X, RawValue == Y { typealias Foo = ... }` causes cross-instantiation ambiguity |
| B4 | Tagged generic param can be `Underlying` (despite typealias collision) | 6.3.1 (works under recipe) | Carrying conformance via `extension Tagged: Carrying` + `Self.Underlying` qualification — verified |
| B5 | Pack same-type requirements with concrete types not yet supported | 6.2.4 / 6.3.x (lang spec) | Inside `extension Product<Int, String, Double>`, `values` is NOT narrowed to `(Int, String, Double)` |
| C1 | Actor isolation — three mechanisms model | 6.3.x (lang spec) | When to use `Actor.run` vs `assumeIsolated` vs `isolated` parameter |
| C2 | Typed throws — Swift 6.2.4 stdlib support matrix | 6.2.4 / 6.3.x (lang spec) | Some stdlib `rethrows` APIs propagate `throws(E)`; many erase to `any Error` |
| C3 | Typed throws — catch blocks preserve concrete typed error | 6.3.x (lang spec) | `error` in catch IS the concrete typed error, NOT `any Error` |

**Total entries: 17** (16 distinct bugs/patterns + the master fix-status table). Worked-example sections begin below.

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

**Swift versions**: 6.3.2 (FIRES); 6.4-dev snapshot `swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a` (FIXED).

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

The bug is fixed in Swift 6.4-dev (snapshot `swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a`); reduction was deprioritized once upstream fix was confirmed.

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
