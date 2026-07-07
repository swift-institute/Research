---
title: Swift Compiler Bug Catalog
tier: 2
scope: cross-package
status: REFERENCE
created: 2026-05-10
last_reviewed: 2026-06-26
last_verified: 2026-06-26
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
| `@_rawLayout` element destruction LLVM IR domination | `swiftlang/swift#86652` | `_deinitWorkaround: AnyObject?` + field-ordering — **works for DIRECT `@_rawLayout` only; composed/nested (`Storage.Contiguous<Memory.Inline>`) is unrecoverable, see § A14** | 36 inline storage types across 9 packages |
| WMO + CopyToBorrowOptimization miscompiles actor enum state | Not filed | Removed `Mutex<Token?>` from `IO.Event.Selector.Scope` (commit `6dad19ba`) OR `-sil-disable-pass=copy-to-borrow-optimization` | Standalone 87-line repro at `Experiments/copytoborrow-actor-state-mutex-miscompile/` still fails 100/100 on 6.3.1. See § A6. |
| SendNonSendable SILFunctionTransform abort on cross-module ~Copyable/~Escapable borrowing init inside IIFE | Not filed | Bind the view at the outer function scope — do NOT wrap construction in `_ = { _ = View(base) }()` | `swift-institute/Experiments/sendnonsendable-iife-borrowing-init-crash/` — 10-line cross-module reducer aborts `swift build` with signal 6 in `SendNonSendable::run()`. Surfaced 2026-04-21 during swift-property-primitives test coverage work. |
| CopyPropagation try_apply borrow scope shortening | Not filed | Replace `do/catch` with `try?` on ~Copyable access | swift-io full release build clean on 6.3.1 — workaround still in place, bug presence not independently verified. See § A5. |
| CopyPropagation crash on `Property.Borrow` temporary in `~Copyable` deinit loop | Not filed | Keep a named `pointer(at:)` method; do NOT inline the pointer chain into `deinit` | `swift-storage-pool-primitives` `Storage.Pool.swift:243–255` — inlining `_pool.pointer(at:)` into `Backing.deinit` (looping `_pool.allocation.indices`, which creates a `Property.Borrow` temporary) crashes CopyPropagation. Workaround in place; toolchain/pass not recorded in-code; bug presence not independently verified (catalogued 2026-05-25). |
| SIL EarlyPerfInliner crash on ~Copyable value-type yield through `_read` coroutine ("Cannot initialize a nonCopyable type with a guaranteed value") | Not filed | `@_optimize(none)` on any accessor whose `_read` yields a cross-module ~Copyable value-type. swift-property-primitives DID NOT adopt Option C (value-type State) because the workaround would distribute to every consumer accessor site — ergonomics too hostile for a published API. Kept Option A (conditional `@unchecked Sendable` on the class-based State). Revisit Option C when this crash is fixed upstream. | Primary reproducer: `swift-property-primitives/Experiments/property-consuming-value-state/` crashes on `swift build -c release` at SILPerformanceInlinerPass. Additional reproducers surfaced during 2026-04-30 Phase 7a sweep — same crash signature: `swift-property-primitives/Experiments/language-semantic-property-typed-replacement`, `swift-property-primitives/Experiments/language-semantic-property-replacement`, `swift-render-primitives/Experiments/body-getter-stack-overflow`, `swift-pdf/Experiments/result-builder-stack-overflow`. All five crash in the same pass; the bug is broader than originally scoped (any cross-module ~Copyable value-type yield through `_read`). Companion perf benchmark `swift-property-primitives/Experiments/property-consuming-state-allocation-benchmark` showed no runtime upside for Option C. Revalidate by rebuilding any of the four experiments `-c release` — when they stop crashing, Option C becomes viable. |
| Constrained-extension nested-type lookup ignores where-clause | Not filed (gap candidate for SE-discussion) | At ecosystem scale, do NOT use `extension Tagged where Tag == X, RawValue == Y { typealias Foo = ... }` as a layer-discrimination pattern when other libraries declare same-name nested typealiases on disjoint Tagged instantiations. Use fresh nominal types at L3 (`Path β` shape) instead of `Tagged<L3-Tag, L2-Type>` variants. Plain typealias chains still fine where no L3 policy substance applies. | `swift-institute/Experiments/tagged-cross-instantiation-nested-type-ambiguity/` — 4-target minimal repro, CONFIRMED 2026-05-02 on Apple Swift 6.3.1. See § B3. |
| Unconditional protocol-conformance extension on a `~Copyable`-generic nested type leaks `Element: Copyable` constraint back to the primary declaration | Not filed | **Workaround D** — add `where Element: ~Copyable` to the conformance extension. One-line fix: `extension Storage.Inline: SomeProtocol { … }` → `extension Storage.Inline: SomeProtocol where Element: ~Copyable { … }`. The constraint is INCLUSIVE (allows both Copyable and ~Copyable Element); no body change. | `swift-institute/Issues/swift-issue-rawlayout-noncopyable-extension-rejection/` — 17-variant variable-isolation table; minimum reproducer is single-module / single-file / 13 lines / no `@_rawLayout` / no `deinit` / no `let-capacity`. Production blocker: swift-storage-primitives@ee86ee0 `Storage Inline Primitives` target (Cohort III Pilot 1 [MOD-031] restructure). See § A10. |
| Corrupt associated-type-witness mangled name (`'}'`) for a deep generic instantiation (`Memory.Cursor<Buffer<A>.Linear.Inline<8>>`) as a `Sequenceable.Iterator` witness | Not filed (no standalone reducer) | **Flatten the witness** to an element-only-generic type (`Memory.Snapshot.Cursor<Element>`, eager span→`[Element]` snapshot) so the witness mangled name never embeds the deep conforming type. Production currently uses the equivalent dodge: a hand-written **concrete** scalar iterator. | `swift-institute/Experiments/memory-cursor-generic-witness-demangle` (targets A–F). Reproduces ONLY on the literal `Buffer.Linear.Inline` (target F, transient-restore); ~10 synthetic reconstructions (incl. faithful 3-module topology) all PASS. Same compiler-emission class as § A9. Ambient release-mode confound: § A12 release symptom is masked by the buffer-linear `@_rawLayout` verifier ICE (`swiftlang/swift#86652`), present even with the production scalar iterator. See § A12. |
| `FunctionSignatureOpts` `SILArgument.cpp:40` `!type.hasTypeParameter()` assertion: a generic function whose typed-throws error type carries its own abstract type parameter (`func f<T>() throws(E<T>)`), with a same-module caller, under `-O` | FILED: `swiftlang/swift#89617` (2026-06-02; closest-distinct dup-search in § A13) | `@_optimize(none)` on the **crashing function** (on the caller does NOT help), OR hoist the error type to non-generic when it doesn't use the type parameter. "Require 6.4+" does NOT help — affected ≥6.2 (NOT a 6.3 regression), live through 6.5-dev. See § A13. | 3-line standalone `swiftc -O` reducer at `swift-institute/Issues/swift-issue-functionsignatureopts-generic-typed-throws-error/`. CRASH on 6.2 → 6.5-dev (verifier-caught on 6.2/6.2.3 with asserts off; assertion-caught on 6.3.1+; all dev snapshots through `2026-05-12-a` / `swift-latest`). Production: `swift-parser-primitives` `Tests/…/Parser.Builder Tests.swift:29` `Digit.parse` via `swift test -c release` (test target only; `Sources/` release-clean); **`swift-iso-8601` `DateTime.Parse.parse` library `Sources/` release-crash** (2026-06-29 — first `Sources/`-level §A13 manifestation; re-confirmed on `2026-05-27-a`); **`swift-w3c-xml` `W3C_XML.Lexer.lexDoctype` `Sources/` Linux-release+CMO crash** (2026-07-06, CI-surfaced on 6.3.3-RELEASE — second `Sources/`-level manifestation; pre-existing; +transitive `swift-xml`; see § A13 manifestation (3)); **`swift-ietf/swift-rfc-9110` `HTTP.Parse.QuotedString.parse`** and **`swift-ietf/swift-rfc-2369` `RFC_2369.List.Header.Parse.parse`** (2026-07-07, CI-surfaced during lint-quality-arc CI triage on 6.3.3-RELEASE — third/fourth `Sources/`-level manifestations, firing on both the Ubuntu-release CI leg AND the DocC-archive leg; pre-existing; +transitive `swift-ietf/swift-rfc-9112`; see § A13 manifestations (4)–(5)). |
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
| A9 | `Atomic<Tagged<…>>`, `Dictionary<Tagged<…>, ~Copyable>`, and `Set<Tagged/Index>.Ordered.insert` runtime metadata-lookup defect | 6.3.x broken / fixed on 6.4-dev+ (wrapper workaround reverted 2026-05-23; require Swift 6.4+) | `swift_getTypeByMangledName` returns `TypeLookupError("unknown error")` for institute-Tagged inside generic stdlib/institute containers needing full metadata; downstream loads of null metadata fault at `0x10` (advance), `0xfffffffffffffff8` (deinit), or in `Hash.Table` insert (Set.Ordered) |
| A10 | Unconditional protocol-conformance extension leaks `Element: Copyable` to primary declaration of `~Copyable`-generic nested type | 6.3.2 / 6.4-dev (still broken) | `extension Storage.Inline: SomeProtocol { … }` (no `where Element: ~Copyable`) causes `type 'Element' does not conform to protocol 'Copyable'` at every Element reference in a sibling `extension Storage where Element: ~Copyable`-scoped declaration |
| A11 | `DiagnoseStaticExclusivity` SIGSEGV on a borrow returned through a `~Copyable` enum payload | 6.3.2 (still broken) | `@inlinable` getter returning `Span`/`MutableSpan`/`_read`-view from a `switch` over a `~Copyable` enum payload crashes emit-module; workaround is non-`@inlinable` + package window. Context-sensitive (no standalone reducer yet) |
| A12 | Corrupt associated-type-witness mangled name for a deep generic instantiation as a `Sequenceable.Iterator` witness | 6.3.1 (still broken; no standalone reducer) | Deep `Memory.Cursor<Buffer.Linear.Inline>` witness emits a malformed mangled name (`'}'`); same emission class as §A9. Workaround: flatten the witness to element-only-generic |
| A13 | `FunctionSignatureOpts` `SILArgument.cpp:40` assertion on a generic fn with a generic typed-throws error | 6.2 → 6.5-dev CRASH (NOT a 6.3 regression; verifier-caught 6.2/6.2.3, assertion-caught 6.3+; unfixed) | `func f<T>() throws(E<T>)` + same-module caller + `-O` aborts FunctionSignatureOpts creating a `SILArgument` whose type still has a type parameter |
| A15 | Runtime cannot verify a conditional conformance whose same-type RHS is `~Copyable` → null-metadata SIGSEGV at `-Onone` + silent wrong dynamic casts | 6.2 → 6.5-dev compiler AND runtime, ALL broken (NOT a regression; distinct from §A9 despite identical 0x10 signature) | `extension Gen: P where A == Pool` (`Pool: ~Copyable`) + a generic wrapper `W<S: P>` storing `S`: any member access at `-Onone` derefs null metadata at `+0x10`; `(Gen<Pool>() as Any) is any P` returns false; runtime says `subject type x does not conform to protocol P`. 8-declaration bare-swiftc repro, no feature flags. Tower trigger: the ecosystem's only same-type conditional conformance, `Storage.Generational: Store.Protocol where Allocation == Memory.Allocator<Memory.Heap>.Pool` (the LEG-7 slotmap DEBUG wall) |
| A16 | Bodyless `shared [serialized]` default-witness `read` accessor for a `~Copyable` associated-type property bound to `Never` (cross-module) | 6.3.2 → 6.5-dev (UNFIXED; surfaces only when SIL verification runs: +Asserts/Embedded/`-sil-verify-all`) | A protocol with `associatedtype Body: ~Copyable` + a `Body == Never` leaf-default `var body` + a `Body == Never` conformer in BOTH the defining and a consumer module emits a bodyless `body.read` in the consumer → "Must have a construct to emit for" / "function must have a body". Latent/silent on NoAsserts RELEASE (macOS/Linux pass); crashes Windows + Embedded. Surfaced by swift-serializer-primitives (ALL leaf combinators, not just Trace) |
| A17 | Sema `getEffects(req).contains(getEffects(witness))` assertion: `throws(Never)` derived witness vs non-throwing `IteratorProtocol.next()` | 6.3.2 +Asserts CRASH / FIXED 6.5-dev | A type conforming to BOTH a custom chunk protocol (whose `where Element: Copyable` extension provides `throws(Never) next() -> Element?`) AND stdlib `IteratorProtocol` trips the effects-containment assertion at TypeCheckProtocol.cpp:1311 during witness resolution. +Asserts-only (Windows); release legs pass; fixed on 6.5-dev. Surfaced by swift-input-primitives tests |
| A18 | `Mem2Reg`/`OSSACompleteLifetime` `SILBitfield.h:60` (`endBit <= numCustomBits`) per-function bitfield overflow compiling a test function under `-O` | 6.3.2 macOS+Linux release (UNFIXED) | `-O` inlines an `@inlinable` ~Copyable/generic accessor+init chain (e.g. `Fixed<Buffer<Storage<…>.Contiguous<E>>.Linear.Bounded>`) into a `@Test` function; the deep nested-borrow graph overflows `Mem2Reg`'s per-function `SILBitfield` budget → signal 6. Crash site is the inlining-sink (test) function, not any library decl. WA: `@_optimize(none)` on the crash-prone test(s). Distinct from §A13. Surfaced by swift-fixed-primitives |
| A19 | `@_optimize(none)` + `consume` of a `~Copyable`-with-`deinit` value elides the element deinits (NoOptimization-in-`-O` teardown miscompile) | 6.3.2 macOS+Linux release (UNFIXED) | Annotating a function `@_optimize(none)` inside an `-O` module makes a `consume` of a move-only value skip its `deinit`s (`destroyedCount → 0`); full `-Onone`/debug are correct. WA: never `@_optimize(none)` a function that must observe move-only deinits. Surfaced by swift-fixed-primitives (the §A18 workaround exposed it) |
| A20 | `Mangler::verify` (`Mangler.cpp:176`) abort on the `@_implements(Iterable, makeIterator())` witness returning a nested-generic `Materializing<Vector.Iterator>` | 6.3.0-dev / 6.3.2 / 6.3.3-dev +Asserts CRASH (UNFIXED); NoAsserts macOS/Linux green | The Iterable `@_implements` witness `iterableMakeIterator → Iterator.Chunk.Materializing<Vector<A>.Iterator>` (deep generic instantiation + `~Escapable` `Ri_z` + associated-conformance `HCg`) mangles to a symbol the compiler's own round-trip verifier cannot demangle → `abort()` during AST→SIL lowering. `Mangler::verify` is `CONDITIONAL_ASSERT`-gated → +Asserts-only (Windows); NoAsserts emits the malformed name unverified → latent. Same class as §A12 (NOT the Sequenceable witness the handoff presumed). WA: drop or flatten the Iterable witness. Surfaced by swift-vector-primitives |
| A21 | `getMangledName` (`IRGenDebugInfo.cpp:1098`) abort emitting debug info for a named local of a value-generic same-type-constrained typealias (`Axis<N>.*`) | 6.3.x +Asserts CRASH (UNFIXED); NoAsserts macOS/Linux green | A test `let v: Axis<2>.Vertical = …` (value-generic `Axis<let N: Int>` + `extension Axis where N == 2 { typealias Vertical = … }`) makes IRGen `emitVariableDeclaration` mangle the variable's debug type to a `$…_Rsz…` name the round-trip self-check can't re-demangle → abort. Assert-gated (`-disable-round-trip-debug-types`) → +Asserts-only (Windows); NoAsserts latent. Same class as §A20. Whole `Axis<N>.{Vertical,Depth,Horizontal,Direction,Temporal}` family affected. WA: reference `Axis<N>.*` in expression position (no named local of the sugared type) — the flag and dropping the family were both principal-rejected. Surfaced by swift-dimension-primitives |
| A22 | `hasErrorResult()` (`Types.h:5274`, `SILFunctionType::getMutableErrorResult`) abort on a non-throwing → typed-throws (nested-generic error) conversion thunk | 6.3.x +Asserts CRASH (UNFIXED); NoAsserts macOS/Linux green | A bare non-throwing literal `{ _ in false }` assigned to `Field.reciprocal: (Element) throws(Field<Element>.Error) -> Element` inserts a reabstraction thunk whose SIL function type trips `getMutableErrorResult`'s `hasErrorResult()` assert during `-Onone -g` IRGen. Assert-gated → +Asserts-only (Windows + assertions-nightly); NoAsserts latent. Distinct from §A13 (FunctionSignatureOpts `-O`). WA: spell the closure's typed-throws signature explicitly. Surfaced by swift-algebra-primitives |
| A23 | CopyPropagation shortens a `borrowing ~Copyable` value's borrow scope to end before a `try_apply` consuming its `@guaranteed` field (the §A5 mechanism, clean single-file reducer) | 6.3.3 `-O` CRASH / FIXED 6.5-dev (`2026-05-27-a`, `Swift 4d0c97fa5b05711`, +assertions) | `do { try callee(span, to: value.field!) } catch { throw Mapped(error) }` over a `borrowing ~Copyable` value → CopyPropagation ends `begin_borrow` before the `try_apply`; "Found outside of lifetime use?!" signal 6. SILGen is well-formed. Trigger is the field-projected borrow scope, NOT the `try_apply` (a plain `apply` over a `Result`-returning helper crashes identically). FIX (shipped): structural borrowing-method restructure, no suppression (`4b19e6b`); `@_optimize(none)`/`-sil-disable-pass` rejected as ungated footguns. Surfaced by swift-file-system `Streaming.write(chunk:to:)`, was blocking swift-pdf release |
| B1 | `Property.View ~Copyable` extension constraint placement | 6.3.x (lang spec) | All constraints MUST be at extension level, not method level — implicit `Base: Copyable` else |
| B2 | `Property.View` rejected on `Copyable` types (~Copyable + ~Escapable result from mutating method) | 6.3.x (lang spec) | Use `Property<Tag, Base>` for `@CoW` Copyable types instead |
| B3 | Tagged constrained-extension nested-type ambiguity | 6.3.1 (still broken) | `extension Tagged where Tag == X, RawValue == Y { typealias Foo = ... }` causes cross-instantiation ambiguity |
| B4 | Tagged generic param can be `Underlying` (despite typealias collision) | 6.3.1 (works under recipe) | Carrying conformance via `extension Tagged: Carrying` + `Self.Underlying` qualification — verified |
| B5 | Pack same-type requirements with concrete types not yet supported | 6.2.4 / 6.3.x (lang spec) | Inside `extension Product<Int, String, Double>`, `values` is NOT narrowed to `(Int, String, Double)` |
| C1 | Actor isolation — three mechanisms model | 6.3.x (lang spec) | When to use `Actor.run` vs `assumeIsolated` vs `isolated` parameter |
| C2 | Typed throws — Swift 6.2.4 stdlib support matrix | 6.2.4 / 6.3.x (lang spec) | Some stdlib `rethrows` APIs propagate `throws(E)`; many erase to `any Error` |
| C3 | Typed throws — catch blocks preserve concrete typed error | 6.3.x (lang spec) | `error` in catch IS the concrete typed error, NOT `any Error` |

**Total entries: 26** (25 distinct bugs/patterns + the master fix-status table). Worked-example sections begin below.

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

#### §A9 Correction (2026-05-28) — Root cause is codegen, NOT the demangler; bc44d42f11 is not the fix

The Arc 5 conclusion (and the resulting filings) attributed this defect to a missing demangler case — PR #87066 / `bc44d42f11`, the `'j'`/`'J'` inverse-assoc additions to `Demangler::demangleGenericRequirement()` — and asked release-management to cherry-pick it to `release/6.3`. **That diagnosis was wrong.** It was a code-search heuristic (commit in the right branch window + touches the demangler + PR acknowledges runtime breakage), never an empirical test.

A controlled compiler/runtime swap of the same reproducer (2026-05-28) refutes it:

| Binary built by | Runtime (`libswiftCore`) | Result |
|-----------------|--------------------------|--------|
| 6.3.2 | 6.3.2 (OS) | CRASH (139) |
| 6.3.2 | 6.4-dev nightly `2026-03-16-a` (fixed demangler present, confirmed via `DYLD_PRINT_LIBRARIES`) | **CRASH (139)** — same null-metadata deref at `advance` |
| 6.4-dev nightly `2026-03-16-a` | 6.3.2 (OS) | **PASS (`result = 0`)** |

The fix travels with the **binary**, not the runtime: the shipping 6.3.2 runtime resolves the type fine once a 6.4-dev compiler emitted it, and the newer demangler cannot rescue a 6.3.2-emitted binary. The symbolic mangled name emitted for `Atomic<Tagged<…>>` differs structurally between the two compilers (6.3.2 emits a spurious `_` after the 46-char SLI identifier and collapses `HC_HCg` → `HCHCg`) — a malformed name no demangler version can resolve. So the locus is **compiler emission**, not the runtime demangler.

This is the incomplete-on-6.3 `SuppressedAssociatedTypes` feature, exactly as @kavon stated on #89389: the production path enables `-enable-experimental-feature SuppressedAssociatedTypes` (swift-tagged-primitives + swift-ordinal-primitives), and the crashing `Atomic<Tagged<…>>.advance(within:)` is constrained on a suppressed associated type (`Ordinal.Domain: ~Copyable`, Ordinal.Protocol.swift:65). The feature's codegen is incomplete on 6.3 and complete by 6.4-dev — the same statement as "fixed by 6.4-dev." Exact fixing commit not bisected (would require a from-source compiler build).

**Disposition**: backport-request #89389 withdrawn; #74303 sibling note corrected (both 2026-05-28). Resolution for consumers is to require Swift 6.4+ for these paths.

#### §A9 New Site (2026-06-01) — `Set.Ordered<Tagged>.insert` / `Set<Index>.Ordered.insert` (Hash.Table value-witness-table forcing)

A new site of the same family was found during the queue dissolve-Core cascade while greening `swift-graph-primitives`: `swift-graph-primitives` builds green (debug + release) but `swift test` SIGSEGVs. Confirmed §A9 by **both** type identity and the canonical failed-type-lookup signature — this is *not* a new bug, it is the `swift_getTypeByMangledName`-null-metadata family surfacing in a new container.

| Site | Trigger | Faulting path |
|---|---|---|
| `Set_Primitives.Set<Tagged<Tag, Ordinal>>.Ordered.insert(_:)` | `Hash.Table` insert/lookup that needs the element's **value-witness table** | `swift_getTypeByMangledName` → `TypeLookupError("unknown error")` → null-metadata deref → SIGSEGV |

`Index_Primitives.Index<Element> = Tagged_Primitives.Tagged<Element, Ordinal>` (`swift-index-primitives/Sources/Index Primitives/Index.swift:38`), and `Graph.Node<Tag> = Index<Tag>` (`swift-graph-primitives/Sources/Graph Primitives Core/Graph.Node.swift:16`). So graph's `Set<Graph.Node<Tag>>.Ordered.insert` *is* `Set<Tagged<…>>.Ordered.insert` via two typealias hops — which is why a literal `Set<Tagged…>`/`Set<Index…>` grep does not find it.

**Empirical crash confirmation (2026-06-01, Apple Swift 6.3.2 `swiftlang-6.3.2.1.108`)**: a minimal **3-package** reproducer with **zero graph code** — `swift-set-ordered-primitives` + `swift-set-primitives` + `swift-index-primitives` — crashes identically:

```swift
import Set_Ordered_Primitives; import Set_Primitives; import Index_Primitives
enum SimpleTag {}
var set = Set<Index<SimpleTag>>.Ordered()
set.insert(Index<SimpleTag>.zero)   // ← SIGSEGV here
```

```
$ SWIFT_DEBUG_FAILED_TYPE_LOOKUP=1 .build/debug/repro
failed type lookup for �$: unknown error
[exit 139]
```

The `failed type lookup … unknown error` warning is the exact §A9 `swift_getTypeByMangledName` → `TypeLookupError("unknown error")` signature; exit 139 is the SIGSEGV. (Reproducer kept at `/tmp/setord-tagged-repro/`, not committed — empirical scratch.)

**Dev-toolchain status (PASS-on-dev — inherited, not re-run)**: no 6.4-dev+ snapshot is currently installed (only 6.3.1-RELEASE / 6.3.2). This site inherits the §A9 family fix established in the §A9 Update (2026-05-23 Arc 4) toolchain matrix and the §A9 Correction (2026-05-28) controlled compiler/runtime swap: the defect is incomplete `SuppressedAssociatedTypes` codegen on 6.3 (the insert path is constrained on the suppressed `Ordinal.Domain: ~Copyable`, `Ordinal.Protocol.swift:65`), the fix travels with the **binary**, and the feature's codegen is complete by 6.4-dev. §A9 axis-B already established the trigger is container-agnostic (stdlib `Swift.Dictionary` and institute `Dictionary` both crash), so `Hash.Table`-backed `Set.Ordered` is a predicted new surface, not new ground. A per-container 6.4-dev re-confirm was deemed low marginal value (orchestrator decision 2026-06-01); the accurate version gate for this family is `compiler(<6.4)`, not `<6.5` (the `<6.5` gate used in older §A9 records predates the 2026-05-23 version-label correction that pinned `2026-03-16-a` as 6.4-dev).

**Ecosystem blast radius** (grep'd 2026-06-01 across swift-primitives / swift-foundations / swift-standards):

| Kind | Site | Status on 6.3.2 |
|---|---|---|
| Direct (concrete Tagged element via typealias) | `swift-graph-primitives` — `Set<Graph.Node<Tag>>.Ordered` in `Graph.Sequential.Analyze.Reachable`, `…Analyze.Dead`, `…Reverse.Reachable` (3 source constructors) + `…Transform.Subgraph` (consumes one) | CRASH |
| Generic carrier (latent; crashes only at a Tagged-key instantiation) | `swift-dictionary-ordered-primitives` `Dictionary.Ordered.Keys._keys: Set<Key>.Ordered` and `swift-dictionary-primitives` `Dictionary._keys: Set<Key>.Ordered` | CRASH iff `Key` is `Index`/`Tagged` |
| Candidate (untested 2026-06-01) | plain `Set<Index<Int>>` (non-`.Ordered`, same `Hash.Table` family) — appears in `swift-index-primitives` tests | LIKELY CRASH (same VWT-forcing path) |

**Consumer mitigation (graph)**: graph's four uniformly-affected test suites (`Graph.Sequential.Transform.Subgraph`, `Graph.Sequential.Analyze.Dead`, `Graph.Reachability`, `Graph.Sequential.Reverse.Reachable`) were guarded 2026-06-01 with a suite-level `.disabled(if: Toolchain.hasTaggedMetadataSIGSEGV, …)` trait gated on `compiler(<6.4)`. A `.disabled(if:)` trait (not `withKnownIssue`) is required: a SIGSEGV kills the test runner before swift-testing can register a known issue, so `withKnownIssue` cannot make a crashing suite report clean — only *skipping the body* yields a clean 6.3.2 run, and the guard auto-recovers (runs normally) on 6.4+. No raw-storage wrapper was introduced (the §A9 wrapper was reverted on correctness grounds 2026-05-23).

**Disposition**: same as §A9 — no Institute-side code fix; require Swift 6.4+ for `Set<Tagged>.Ordered` / `Set<Index>.Ordered` / `Dictionary.Ordered<Tagged-key>` paths; wait for the Swift 6.5 release.

**Re-probe (2026-06-12, Round M C2 — post-reshape)**: with set-ordered fully reshaped onto
`Hash.Indexed` (3e44537) and graph on the tower columns (cc97736), the four guards were removed
on 6.3.2 and the suites re-run from a clean build: **all four SIGSEGV — in the full-suite run
AND each in isolation**. The vector therefore does NOT depend on the old `Hash.Table`-backed
set-ordered internals: axis-B container-agnosticism is re-confirmed for the NEW engine — the
trigger remains forcing `Tagged`'s value-witness metadata for `Set<Graph.Node>.Ordered`
(= `Set<Tagged>.Ordered`) elements under 6.3's incomplete `SuppressedAssociatedTypes` codegen,
whatever the container's backing. Guards restored VERBATIM (zero source delta; graph stays at
its tip); `Toolchain.hasTaggedMetadataSIGSEGV` and the `compiler(<6.4)` gate stand. Retirement
re-tries at the swift-6.4-RELEASE canon bump (the staged-bump ruling's wall re-probes).

#### §A9 New Site (2026-06-27) — `Parser.Machine.Parser<Byte.Input, …>.parse` (machine-parser metadata / `Parser.Protocol` witness-table forcing)

A new site of the same family, found while greening `swift-w3c-xml` after its
`Parser.Input.Bytes` → `Input_Primitives.Input` + `Byte.Input` migration (commit `57ebb7d`).
`swift-w3c-xml` builds green (debug + release) but `W3C_XML.parse("<root/>")` SIGSEGVs at
runtime — even on the most trivial input. Confirmed §A9 by **both** type identity and the
canonical failed-type-lookup signature — *not* a new bug, *not* a migration defect, *not* a
w3c-xml logic error.

| Site | Trigger | Faulting path |
|---|---|---|
| `Parser.Machine.Parser<Byte.Input, Element, Parse.Error>.parse` | machine-parser type-metadata / `Parser.Protocol` witness-table instantiation that forces `Byte.Input`'s `Index == Tagged<Element, Ordinal>` VWT | `__swift_instantiateConcreteTypeFromMangledNameV2` → `swift_getTypeByMangledName` → `TypeLookupError("unknown error")` → null-metadata deref `EXC_BAD_ACCESS 0x10` (`var parse` getter path) / `instantiateWitnessTable` null deref (direct-method / `Parser.Protocol` witness path) |

`Byte_Parser_Primitives.Byte.Input = Input_Primitives.Input.Slice<Array<Column.Shared<Byte>>>`
(`swift-byte-parser-primitives/Sources/Byte Parser Primitives/Byte.Input.swift:54`), and
`Input.Slice`'s `Input.Protocol` conformance is constrained `A.Index == Tagged_Primitives.Tagged<A.Element, Ordinal>`.
So `Parser.Machine.Parser<Byte.Input, …>`'s metadata transitively forces `Tagged`'s full
value-witness table — the §A9 trigger — exactly as `Set<Graph.Node>.Ordered` does via
`Graph.Node = Index = Tagged`. A literal `Tagged…` grep does not find it (the `Tagged` is two
typealias/conformance hops down inside `Byte.Input`).

**Empirical crash confirmation (2026-06-27, Apple Swift 6.3.3 `swiftlang-6.3.3.1.3`)**: a minimal
**3-package** standalone reproducer with **zero w3c-xml code** —
`swift-parser-primitives` + `swift-parser-machine-primitives` + `swift-byte-parser-primitives` —
crashes identically:

```swift
import Parser_Primitives; import Parser_Machine_Primitives; import Byte_Parser_Primitives
enum E: Error { case fail }
let parser = Parser.Machine.build { (b: inout Parser.Machine.Builder<Byte.Input, E>) -> Parser.Machine.Expression<Byte.Input, E, Int> in
    Parser.Machine.pure(42, in: &b)
}
var input = Byte.Input(utf8: "<root/>")
_ = try parser.parse(&input)   // ← SIGSEGV
```

```
$ SWIFT_DEBUG_FAILED_TYPE_LOOKUP=1 .build/debug/repro
failed type lookup for +o: unknown error
[exit 139]
```

`-Onone` **and** `-O` both crash. The `var parse` getter (`Parse(parser: self)`), the
getter-only form (`let _ = parser.parse`), and the direct `func parse(_:)` reached via the
`Parser.Protocol` witness **all** crash — the trigger is the type's VWT / witness-table
instantiation, not the `parse` getter specifically. (Reproducer kept at scratchpad `MachineRepro/`,
not committed — empirical scratch.)

**Pre-existing institutional knowledge**: `swift-parser-primitives/Tests/Support/Parser.Test.Input.swift:8-10`
already documents this exact SIGSEGV class — it deliberately uses a flat local `Parser.Test.Bytes`
backing "to avoid a Swift runtime SIGSEGV … when composing parser types over
`Input.Slice<Buffer<…Memory.Heap…>.Linear>` across modules." That is why
`swift-parser-machine-primitives`' own tests pass (flat `Parser.Test.Input`) while a
canonical-`Byte.Input` consumer crashes.

**Dev-toolchain status (PASS-on-dev — inherited; direct re-confirm blocked)**: inherits the §A9
family fix (incomplete `SuppressedAssociatedTypes` codegen on 6.3, complete by 6.4-dev; the fix
travels with the binary). A direct per-site re-confirm on a 6.4/6.5-dev snapshot is currently
BLOCKED: every installed dev snapshot frontend-crashes compiling the `swift-parser-primitives`
stack (`Parser.Fail.swift` on `2026-05-27-a`; `Parser.Trace.swift` on `2026-05-12-a`) — unrelated
dev-toolchain regressions, not this bug. Per the §A9 new-site precedent (2026-06-01), signature +
type identity is sufficient to classify; per-site 6.4-dev re-confirm is low marginal value.

**Consumer mitigation (w3c-xml)**: the five `W3C_XML.parse`-exercising suites (`W3C_XML Parser
Tests`, `…Error Handling Tests`, `…Parser Edge Cases`, `…Deep Nesting Tests`, `…Round-trip Tests`)
and the two `parse`-calling tests in `…Character Validation Tests` were guarded 2026-06-27 with
`.disabled(if: Toolchain.hasTaggedMetadataSIGSEGV, …)` gated on `compiler(<6.4)`
(`swift-w3c-xml/Tests/W3C XML Tests/{Toolchain.swift, ParserTests.swift}`). The non-`parse` suites
(`…Encoder Tests`, `…Type Tests`, the five character-predicate tests) run unguarded. No
source/manifest change; the `Byte.Input` migration (`57ebb7d`) is correct and stands.

**Disposition**: same as §A9 — no Institute-side code fix; require Swift 6.4+ for
`Parser.Machine.Parser<Byte.Input, …>` (and, by extension, any byte-domain machine-parser
composition over `Byte.Input`). **Principal decision (2026-06-27)**: accept the "require 6.4+" stance
— **no `Byte.Input` change, no flatter cursor backing**; the `compiler(<6.4)` guards retire when the
workspace adopts Swift 6.4 at its **~September 2026** launch (the family's `compiler(<6.4)` gate, not
the older "wait for 6.5" phrasing). The 6.3.x coverage gap until then is accepted. **Ecosystem note**:
the trigger is `Byte.Input`'s `Tagged`-bearing `Index`, so this affects the **entire** byte-domain
machine-parser surface, not only w3c-xml — every such site inherits the same accepted stance and the
September-2026 retirement trigger.

**Gated consumer sites (retirement checklist — delete the `Toolchain.swift` + `.disabled(if:)` guards at 6.4 adoption)**:
- `swift-w3c-xml/Tests/W3C XML Tests/{Toolchain.swift, ParserTests.swift}` (5 parse suites + 2 char-validation tests) — gated 2026-06-27.
- `swift-graph-primitives/Tests/Support/Toolchain.swift` + 4 analyze/transform/reverse suites — gated 2026-06-01.
- **`swift-foundations/swift-xml/Tests/XML Tests/{Toolchain.swift, StreamTests.swift, XMLTests.swift}`** — L3 consumer (`XML.parse` / `XML.ND.stream` / `XML` string-literal init → `W3C_XML.parse`); 4 parse-exercising suites (`Stream Tests`, `XML Wrapper Tests`, `XML.Document Tests`, `XML Literal Tests`) gated **2026-07-03**. Was missed in the 2026-06-27 sweep. Note: `XML Literal Tests` parses via `ExpressibleByStringLiteral`/`StringInterpolation` → `Self.fragment`, not obvious from a `parse(` grep.
- **Likely still-missed**: the plist consumer (same `Byte.Input` machine-parser surface) — audit before the retirement sweep.
- **`swift-foundations/swift-io/Tests/{Support/Toolchain.swift, IO Event Tests/IO.Event.Driver.Contract.Tests.swift}`** — `SourceContractTests` suite (`Event.Source.Contract`) gated **2026-07-06** (the io `__Dictionary.insert` new site below).

**`@_specialize` real-fix spike (2026-07-03) — NEGATIVE; do not re-run.** Empirically established (minimal 3-package reproducer, 6.3.3): the crash fires whenever the concrete `Byte.Input` metadata / `Input.Protocol` witness table is **materialized at runtime**. Calling `parse` from a *generic* context (Input abstract) dodges it at **`-Onone` only** (debug PASS); under `-O` / `@_specialize` / `@inlinable` the optimizer re-specializes to concrete `Byte.Input` and the crash returns (release CRASH). **Specialization is the trigger, not the cure** — so no `@_specialize`-family source fix exists, and the `-Onone`-only generic-indirection dodge is strictly worse than the gate (it would green a debug build while shipping a guaranteed release crash). This is the empirical basis for the "no source fix, require 6.4+" disposition.

#### §A9 New Site (2026-07-06) — swift-io `Kernel.Event.Driver` registry `Dictionary<Tagged-key>.insert` (institute `__Dictionary`/`__HashIndexed` engine)

The io driver-contract test `poll drops events for deregistered IDs` SIGSEGVs on 6.3.2/6.3.3 at the
first `shared.registry.insert(...)` in `Kernel.Event.Driver.init` (`Kernel.Event.Driver.swift:136`).
Registry = `Dictionary_Primitives.Dictionary<Kernel.Event.ID, Registration>`,
`Kernel.Event.ID = Tagged<ISO_9945.Kernel.Event, UInt>`. Confirmed §A9 by type identity + the
canonical `swift_getTypeByMangledName → TypeLookupError("unknown error")` → null-metadata deref at
`0x10` signature (`__Dictionary<>.insert`; the register holds the demangling-cache symbol for
`__Dictionary<__HashIndexed<Buffer<…Hash.Entry<Tagged<ISO_9945.Kernel.Event, UInt>, …Registration>>…>.Linear>>`).
This is §A9 **site 3** (the io/kernel registry, workaround `a79ca49` reverted `44ab1f8`) re-surfacing
after the ADT-tower reshape relocated it into `ISO_9945.Kernel` and respelled the container onto the
`Hash.Indexed`-backed `__Dictionary` engine (same reshape as set-ordered `3e44537`; axis-B
container-agnosticism holds).

**Bisection refinements** (5-target reducer, real `Kernel.Event.ID` + institute `Dictionary`;
terminal record + reducer + three `.ips`: `Issues/swift-issue-tagged-dictionary-insert-metadata-crash`,
landed `afeabd7`): (1) the **Tagged key** is load-bearing — a non-Tagged `UInt` key PASSES;
(2) **axis-C open cell RESOLVED** — institute `Dictionary` + Tagged key + **Copyable** value (`Int`)
**CRASHES**, so a `~Copyable` user value is NOT required for the institute container (the
`__Dictionary`/`__HashIndexed`/`Hash.Entry`/`Buffer.Linear` engine composes `~Copyable` types into the
mangled name itself); contrast stdlib `Dictionary` + Tagged key + Copyable value = PASS; (3) **crashes
in DEBUG and RELEASE** at this site (emission defect, not optimizer; distinct from §A15's
`-Onone`-only); (4) closure/actor context is incidental — a 3-line straight-line `main` reproduces.

**Dev-toolchain**: PASS-on-dev inherited from the §A9 family (fix travels with the 6.4 compiler
binary — Correction 2026-05-28), per the 2026-06-01 Set.Ordered new-site precedent; a direct dev
re-run is deferred (installed snapshots trip the `#if swift(>=6.4)` forward gates — non-probative
per [ISSUE-001]). **Disposition**: same as the family — no Institute source fix; suite-level
`.disabled(if: Toolchain.hasTaggedMetadataSIGSEGV)` gated `compiler(<6.4)` landed on swift-io
(`90abb792`, mirrors graph's `Tests/Support/Toolchain.swift`); listed in the retirement checklist
above; require Swift 6.4+.

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

### A12. Corrupt associated-type-witness mangled name (`'}'`) for a deep generic instantiation as a `Sequenceable.Iterator` witness

**Swift versions**: 6.3.2 (`swiftlang-6.3.2.1.108`, Xcode 26.4.1 default) AND 6.4-dev nightly — STILL BROKEN on both (the 6.4-dev result is inherited from the prior 2026-05-27 investigation; the 2026-05-28 literal-topology reproduction was on 6.3.2). macOS 26 arm64.

**Symptom**:
- **Debug**: runtime SIGABRT (exit 134) in `Sequenceable.collect()`:
  ```
  failed to demangle witness for associated type 'Iterator' in conformance
  '…Buffer<A>.Linear.Inline<8>: Sequenceable' from mangled name '}' - unknown error
  ```
  The mangled name handed to `swift_getAssociatedTypeWitness` is the **single byte `'}'`** — a truncated/garbage string.
- **Release**: the symptom is masked by the ambient buffer-linear LLVM "Broken module" verifier ICE (see "Confound" below); with `-disable-llvm-verify`, the baseline links and the corrupt witness still aborts at runtime, while the reshape runs correctly.

**Trigger**: an `@_implements(Sequenceable, Iterator) typealias = Memory.Cursor<Self>` binding where the conforming type is the deeply-nested, value-generic, `@_rawLayout`-backed `Buffer<Element>.Linear.Inline<capacity>`. IRGen emits a corrupt mangled name for the **deep generic instantiation** `Memory.Cursor<Buffer<A>.Linear.Inline<8>>` in the associated-type-witness table.

**NOT synthetically reproducible** (verified across ~10 reconstructions, `Experiments/memory-cursor-generic-witness-demangle`, targets A–E): hand-rolled bare-generic witnesses, single/dual `@_implements`, value-generic, `@_rawLayout`-owning, cross-module, cross-module bridge-default witness, AND the faithful **3-module topology** (type module / ops module / bridge-default module + span-witness-in-type-module) all PASS. Only the **literal `Buffer.Linear.Inline`** (target F, via a principal-authorized transient-restore of the crashing form) reproduces. The trigger needs some factor of the full literal type's member/conformance-cluster surface that resists isolation.

**Root cause class**: compiler **emission** of a malformed mangled name for a deep generic instantiation involving institute primitives — the **same class as §A9** (`Atomic<Tagged<…>>` / `Dictionary<Tagged<…>>` null-metadata, where §A9's 2026-05-28 correction established the locus is compiler emission, not the runtime demangler, and "a malformed name no demangler version can resolve"). §A12 is the `swift_getAssociatedTypeWitness` (associated-type-witness table) surface of that class; §A9 is the `swift_getTypeByMangledName` (full type metadata) surface.

**Confound — ambient buffer-linear release ICE (DISTINCT bug)**: `swift-buffer-linear-primitives` fails to compile in **release** with an LLVM "Broken module found" verifier abort **even at clean HEAD with the production hand-written scalar iterator** (no `Memory.Cursor` at all) — verified by building the standalone `Buffer Linear Inline Primitives` target at HEAD, `-c release`. This is almost certainly the documented `@_rawLayout`+deinit verifier issue (cf. `swiftlang/swift#86652`, and the WORKAROUND comments in `Buffer.Linear.Inline.swift` / `Storage.Inline.swift`). It is independent of §A12; do not conflate the two. (This release ICE is itself a candidate catalog entry / upstream filing — flagged, out of scope for this investigation.)

**Workaround / RESHAPE (verified dodge)**: flatten the `Sequenceable.Iterator` witness from the deep `Memory.Cursor<Self>` to an **element-only-generic** `Memory.Snapshot.Cursor<Element>` (eager span→`[Element]` snapshot), vended by a `makeSnapshotIterator()` bridge witness in `swift-memory-sequence-primitives`. The witness mangled name becomes the shallow `Memory.Snapshot.Cursor<A>`, never embedding the conforming type → dodges the corrupt-emission path. **Validated against the literal topology** (target F, debug + release-with-`-disable-llvm-verify`). Triangulated: removing `@frozen` and making the conformance unconditional both FAIL to dodge — only witness-flattening works, so the trigger is specifically the deep generic instantiation in the witness mangled name. Trade-off: one eager `[Element]` allocation vs the lazy cursor's per-`next()` re-derivation; for inline `@_rawLayout` conformers this is the only safe element-only-generic shape (a lazy element-only iterator would dangle into consumed inline storage). The production decision (the hand-written concrete scalar iterator, current HEAD) is an alternative dodge of the same kind (also a concrete, non-deep-generic witness).

**Reproducer**: `swift-institute/Experiments/memory-cursor-generic-witness-demangle` (targets A–F + Outputs). Findings: `swift-institute/Research/memory-cursor-generic-witness-demangle-reshape.md` and `unified-iteration-design.md` (Outcome OQ-2).

**Upstream filing**: NOT FILED — still no `swiftc`-reproducible or SwiftPM-reproducible-outside-buffer-linear reducer ([ISSUE-002]/[ISSUE-017]). The reproduction requires a transient edit to the literal buffer-linear type. Filing-readiness would need either the full literal type vendored into a self-contained reducer, or upstream-side bisection of the mangled-name emission for this instantiation.

**Cross-references**: §A9 (sibling corrupt-mangled-name-emission class, the `swift_getTypeByMangledName` surface), §A11 (same buffer-linear `@_rawLayout`/Span context, also context-sensitive/non-standalone-reproducible), `swiftlang/swift#86652` (the ambient release-mode `@_rawLayout` verifier confound). [ISSUE-013]/[ISSUE-025]/[EXP-020] (synthetic-vs-literal discipline).

**Source**: 2026-05-28 reshape-to-dodge investigation on the literal `Buffer.Linear.Inline` (principal-authorized transient-restore, fully reverted).

---

### A13. `FunctionSignatureOpts` `SILArgument.cpp:40` assertion on a generic function with a generic typed-throws error type

**Pattern**: A generic function whose typed-throws error type is parameterized by the function's own generic parameter — `func f<T>(…) throws(E<T>) -> R` — together with ≥1 same-module caller, compiled `-O`.

```swift
public enum MyError<T>: Swift.Error { case fail }
public func parse<T>(_ x: T) throws(MyError<T>) -> UInt8 { throw .fail }          // crashes
public func run<T>(_ x: T) -> UInt8 { do { return try parse(x) } catch { return 0 } }
```

**Symptom**: `Assertion failed: (!type.hasTypeParameter()), function SILArgument at SILArgument.cpp:40` → signal 6 → `While running pass SILFunctionTransform "FunctionSignatureOpts"` → `FunctionSignatureTransform::createFunctionSignatureOptimizedFunction()` → `SILArgument::SILArgument(…)`. The pass builds a signature-optimized clone of the generic function and creates a `SILArgument` (the indirect typed-error result) whose type `E<T>` still contains the abstract parameter `T`.

**Swift version**: **affected on every tested toolchain 6.2 → 6.5-dev; NOT a 6.3 regression; NOT fixed on the latest 6.5-dev.** Verified by *running the reducer* under each toolchain (`swift --version`-confirmed): CRASH on 6.2, 6.2.3, 6.3.1, 6.3.2 (Xcode default), 6.3-dev (`2026-01-07/01-09/02-05-a`), 6.4-dev (`2026-03-16-a`, `2026-05-07-a`), 6.5-dev (`2026-05-12-a`, `swift-latest`). The *manifestation* differs by build: on 6.2 / 6.2.3 (assertions off) the malformed FunctionSignatureOpts SIL is caught by the **SIL verifier** (`error destination of try_apply must take argument of error result type` — `$E<τ_0_0>` block arg vs `$E<T>` try_apply error result); on 6.3.1+ the *same* malformed SIL is caught earlier by the **always-on `ASSERT(!type.hasTypeParameter())`** in `SILArgument` (the `ASSERT` macro fires even in NDEBUG compiler builds — `include/swift/Basic/Assertions.h`). Typed throws shipped in 6.0, so the true floor may predate 6.2 (untested — no 6.0/6.1 toolchain installed). Contrast §A9 (fixed on 6.4-dev): **"require Swift 6.4+" does NOT remediate this bug.** **[Correction 2026-06-01: an earlier revision of this entry read "regression introduced in 6.3 / CLEAN on 6.2-6.2.3." That was a misclassification — 6.2/6.2.3 were graded by grepping for the `hasTypeParameter` assertion text, which those toolchains do not emit (they print the verifier message instead) → "no match" → wrongly read as clean. An independent re-investigation re-ran the reducer on 6.2/6.2.3 and observed the crash. Do NOT file "regression in 6.3" upstream.]**

**Verified ingredient list** (remove any one → compiles clean): (1) a generic function; (2) typed throws whose error type carries the **abstract** type parameter — a non-generic error, or a *concrete* `E<Int>`, is clean; (3) ≥1 same-module caller — the generic function alone is clean; (4) `-O` (FunctionSignatureOpts only runs at `-O`; debug is clean); (5) an **eliminable (dead) argument** so FunctionSignatureOpts builds a signature-optimized thunk — a function whose *every* argument (including `self`) is genuinely used compiles clean; the trigger is an unused parameter (the reducer's `_ x: T`) **or** the empty struct's dead `self` (production `Digit`/`Expect` are empty structs → `self` is the eliminated argument). *(Calibration: FSO may also build the thunk via other signature opts, e.g. owned→guaranteed; not exhaustively tested — but every no-eliminable-argument shape tested was clean.)* NOT required: protocol conformance, struct/nesting, `inout`, `Sendable`, `@inline(never)`, `-enable-testing`, `-parse-as-library`, `-enable-default-cmo`, or any experimental/upcoming feature (`SuppressedAssociatedTypes`, `Lifetimes`, …).

**Workaround** (all validated on 6.3.2): `@_optimize(none)` on the **crashing function** (on the *caller* does NOT help); OR hoist the error type to a **non-generic** type when it doesn't use the type parameter (behaviour-preserving — the production `Digit<Input>.Error` is a non-payload enum that never uses `Input`, i.e. only *accidentally* generic via nesting); OR exclude the affected test target from release builds. "Require 6.4+" does not work.

**Production manifestation**: `swift-parser-primitives`, `swift test -c release`, test target `Parser_Take_Primitives_Tests`, `Tests/Parser Take Primitives Tests/Parser.Builder Tests.swift:29` `Digit.parse` (mangled `@$s28Parser_Take_Primitives_Tests5DigitV5parseys5UInt8VxzAC5ErrorOyx_GYKF`). The package's `Sources/` release-compile clean (55 modules built before the crash); the crash is confined to the **test target** (the `Parser.Builder` fixtures — `Digit`, `Expect`, … — share the shape). **Distinct from §A8** (same file, but a debug-time type-checker "failed to produce diagnostic" ICE, fixed on 6.5-dev) and from **§A9** (runtime metadata-lookup SIGSEGV needing `SuppressedAssociatedTypes`, fixed on 6.4-dev).

**Production manifestation (2)** — `swift-iso-8601` (independently re-discovered + re-confirmed 2026-06-29): `ISO_8601.DateTime.Parse.parse` (`Sources/ISO 8601/ISO_8601.DateTime.Parse.swift:32`, mangled `@$s8ISO_8601AAO8DateTimeV5ParseV5parseyAF6OutputVy__x_GxzAF5ErrorOy__x_GYKF`) — same ingredient set (empty-struct dead `self`; the four `<Domain>.Parse.Error` enums are nested in generic `Parse<Input>` but never use `Input` — phantom). **First §A13 manifestation that crashes a library `Sources/` release build** — every consumer's `-c release` of the ISO_8601 graph aborts, not just a test target. Independently bisected to package commit `821a6d0` ("Nest `__` error types… [API-IMPL-005]"), which **reverted an earlier mitigation** — `d4a5d30` "Hoist parser Error enums to avoid SIL FunctionSignatureOpts crash" — re-introducing the phantom for naming-convention compliance. Re-confirmed crashing on the **`2026-05-27-a` dev snapshot** (`swift-latest`), extending the matrix above by one. Evergreen fix **LANDED 2026-06-29** (`swift-iso-8601` `aa1c557..8ad787e`, pushed): the four `<Domain>.Parse.Error` enums de-phantomed to module-scope `__<Domain>ParserError`, and the parser family re-aligned onto `swift-parser-primitives` (legacy String `enum Parser`s deleted; byte `Parse`→`Parser`; `Output` = the domain value, with §E(B) positional dispatch closing the week/ordinal gap). Verified `swift build -c release` clean (0 ICE) + `swift test` 235/235 green + consumer `swift-html-render` `-c release` end-to-end. (The §A13 minimal error-hoist alone had earlier been validated `Build complete (7.57s)` / ICE-clean.) **Latent sibling to watch**: `RSS.Parse.Duration<Input>.Error` (`swift-standards/swift-rss-standard/Sources/RSS Standard/RSS.Parse.Duration.swift:41`) carries the identical nested-generic-phantom-error shape — not yet crashing (no `-c release` exercised on that path), ICE-prone on its next release pass.

**Production manifestation (3)** — `swift-w3c-xml` (CI-surfaced 2026-07-06 during the post-tower render/standards migration): `W3C_XML.Lexer.lexDoctype(startPos:)` (`Sources/W3C XML/W3C_XML.Lexer.swift`, mangled `@$s7W3C_XMLAAO5LexerV10lexDoctype8startPosAB5TokenOAB8PositionV_tAD5ErrorOy_x_GYKF` — a generic `Lexer` method throwing the accidentally-generic `Lexer<…>.Error`). **Second `Sources/`-level §A13 manifestation** (after iso-8601): the whole `W3C_XML` module aborts under Linux x86_64 `swift build -c release` (`-O -enable-default-cmo`) on **Swift 6.3.3-RELEASE** — `Assertion failed: (!type.hasTypeParameter()), SILArgument.cpp:40` in `FunctionSignatureOpts`. **macOS 6.3 debug builds clean** (FSO is `-O`-only), which is why local macOS verification did not surface it. **Pre-existing, NOT this arc's regression** — the prior commit `2ca691c` (before the ownership-shared rename respell `f60dd74`) failed the identical Ubuntu-release leg; a 1-line import respell cannot cause or fix a codegen assertion. Transitively re-manifests in the consumer **`swift-xml`** (its `-c release` builds `W3C_XML` → same abort). Evidence: `swift-w3c-xml` CI run [28802981666](https://github.com/swift-w3c/swift-w3c-xml/actions/runs/28802981666) + `swift-xml` run [28802984515](https://github.com/swift-foundations/swift-xml/actions/runs/28802984515) (both Ubuntu 6.3 release). **NOT remediated (tracking only)** — the §A13 source fix (hoist `Lexer`'s phantom-generic `Error` out of the generic context, as done for iso-8601, or `@_optimize(none)` on `lexDoctype`) is owned by a w3c-xml session. **Latent siblings**: any other phantom-generic typed-throws-error method in `W3C_XML` (other `Lexer`/`Parse*` methods) will abort on its next `-c release`.

**Production manifestation (4)** — `swift-ietf/swift-rfc-9110` (CI-surfaced 2026-07-07 during lint-quality-arc CI triage): `RFC_9110.Parse.QuotedString.parse` (`Sources/RFC 9110/HTTP.Parse.QuotedString.swift:31`, mangled `@$s8RFC_9110AAO5ParseO12QuotedStringV5parseySay14Byte_Primitive0F0VGxzAF5ErrorOy__x_GYKF` — a generic `Parse.QuotedString` method throwing an accidentally-generic error type, matching §A13's ingredient list). Fires under Linux x86_64 `-O -enable-default-cmo` on **Swift 6.3.3-RELEASE**, on BOTH the `ci / matrix / Ubuntu (Swift 6.3, release)` leg AND the `docs / docs / DocC archive` leg — `Assertion failed: (!type.hasTypeParameter()), SILArgument.cpp:40` in `FunctionSignatureOpts` on SILFunction `@$s8RFC_9110AAO5ParseO12QuotedStringV5parseySay14Byte_Primitive0F0VGxzAF5ErrorOy__x_GYKF`. macOS debug builds clean (FSO is `-O`-only). **Transitively re-manifests in the consumer `swift-ietf/swift-rfc-9112`** (its `swift build` / DocC-archive builds resolve `RFC_9110` via `.build/checkouts/swift-rfc-9110` → identical abort at the same source line). **Pre-existing, NOT the lint-quality arc's regression** — both repos' arc diffs were format-only (lint/whitespace); a formatting diff cannot cause or fix a codegen assertion. Evidence: `swift-rfc-9110` CI run [28857604519](https://github.com/swift-ietf/swift-rfc-9110/actions/runs/28857604519); `swift-rfc-9112` CI run [28855220352](https://github.com/swift-ietf/swift-rfc-9112/actions/runs/28855220352) (both Ubuntu 6.3 release + DocC archive legs). **NOT remediated (tracking only)** — the §A13 source fix (hoist `QuotedString`'s error type out of the generic context, or `@_optimize(none)` on `parse`) is owned by a swift-rfc-9110 session; `swift-rfc-9112` inherits the fix once it lands upstream in `swift-rfc-9110`.

**Production manifestation (5)** — `swift-ietf/swift-rfc-2369` (CI-surfaced 2026-07-07 during lint-quality-arc CI triage): `RFC_2369.List.Header.Parse.parse` (`Sources/RFC 2369/RFC_2369.List.Header.Parse.swift:36`, mangled `@$s8RFC_2369AAO4ListO6HeaderV5ParseV5parseySayxGxzAH5ErrorOy___x_GYKF` — a generic `List.Header.Parse` method, same ingredient shape as manifestation (4)). Fires under Linux x86_64 `-O -enable-default-cmo` on **Swift 6.3.3-RELEASE**, on BOTH the `ci / matrix / Ubuntu (Swift 6.3, release)` leg AND the `docs / docs / DocC archive` leg — identical `SILArgument.cpp:40` assertion in `FunctionSignatureOpts` on SILFunction `@$s8RFC_2369AAO4ListO6HeaderV5ParseV5parseySayxGxzAH5ErrorOy___x_GYKF`. macOS debug builds clean. **Pre-existing, NOT the lint-quality arc's regression** — the arc's diff was format-only. Evidence: `swift-rfc-2369` CI run [28860372471](https://github.com/swift-ietf/swift-rfc-2369/actions/runs/28860372471) (Ubuntu 6.3 release + DocC archive legs). **NOT remediated (tracking only)** — fix (hoist the error type or `@_optimize(none)` on `parse`) owned by a swift-rfc-2369 session.

**Note on manifestations (4)–(5)**: independently discovered during a 2026-07-07 CI triage that initially read these as a candidate NEW crash family (distinct assertion investigation opened before this catalog was consulted). Cross-checked against this entry: same assertion text, same pass (`FunctionSignatureOpts`), same crash site (`SILArgument.cpp:40`), same trigger shape (generic function + typed-throws error type carrying the function's own type parameter, `-O`) — **this is §A13, not a new family.** Filed correctly under the existing `swiftlang/swift#89617`; no new upstream filing needed. Distinct only from §A9 and the Windows +Asserts-only families (§A16/A17/A20/A21/A22), as the CI triage's framing correctly noted — but not distinct from §A13 itself.

**Evidence / reproducer**: 3-line standalone `swiftc -O` reducer + full writeup, toolchain matrix, and validated workarounds at `swift-institute/Issues/swift-issue-functionsignatureopts-generic-typed-throws-error/`.

**Upstream filing**: **FILED as `swiftlang/swift#89617`** (2026-06-02; reducer was filing-ready per [ISSUE-002]/[ISSUE-017]). Duplicate search ([ISSUE-007]): no exact match. Closest, all **distinct**: `swiftlang/swift#73345` (assertion `signature || !origType->hasTypeParameter()` but in **SILGen** `AbstractionPattern.h:529`, different pass); `swiftlang/swift#81317` (typed-throws + `-enable-testing`; this reducer needs neither); `#83597` / `#84899` (release-mode **OwnershipModelEliminator** verifier crashes — load-borrow and parameter-packs respectively, not FSO); `#83744` (`-enable-sil-opaque-values`, a different `SILArgument` assertion). **Explicitly distinct from our own `swiftlang/swift#87030`** (the IRGen `getMutableErrorResult`/`Types.h:5174` crash — closure field + `extension … where T == Concrete`; **clean on 6.3.2**, only crashes on 6.5-dev) **and its fix `#88931`** (changes `SILGenProlog.cpp` / `SILVerifier.cpp` / `IRGenSIL.cpp` — **not** FunctionSignatureOpts): #87030/#88931 are a **different bug** and do **NOT** cover this FSO crash (this one crashes on 6.3.2 where #87030 is clean; #88931 does not touch the FSO code path, and the FSO crash still reproduces on 6.5-dev). **Disposition**: filed upstream as #89617 (2026-06-02) after two independent fresh-eyes reviews + a live duplicate re-check (which added #88959 [closest relative — `-Onone` protocol-associatedtype crash], #80732, #77612 to the dup-search — all distinct; full list in the Issues entry / #89617). The source-side fix to `swift-parser-primitives` remains owned by that package's session.

**Source**: 2026-06-01 parser release-config SIL-crash investigation (`/issue-investigation`).

---

### A14. `swift#86652` cross-package deinit fires ONLY for DIRECT `@_rawLayout` — composed/nested `@_rawLayout` is unrecoverable by any workaround

**Swift versions**: 6.3.2 (empirically; the master `swiftlang/swift#86652` row is the parent bug).

**Statement (Cleave-7 refinement of the `#86652` workaround)**: The canonical `_deinitWorkaround: AnyObject? = nil` + manual-cleanup workaround makes a `~Copyable` buffer's `deinit` fire during cross-package member-destruction **iff the buffer's `@_rawLayout` storage is a DIRECT field whose `@_rawLayout`-bearing TYPE is declared in the SAME module as the buffer** (e.g. `Buffer.Arena.Inline`'s nested `_Elements`). When the `@_rawLayout` is reached through a **cross-module generic composition** — `Storage.Contiguous<Memory.Inline<E,n>>`, where `Memory.Inline._Raw` (`@_rawLayout`) lives in a different package — the buffer's value-witness is misclassified **trivial** cross-package and its `deinit` is **skipped**, and the `AnyObject?` workaround is **inert**: it neither makes the deinit fire cross-package nor compiles safely same-package.

**Empirical matrix (faithful production bed; list-linked consuming buffer-linked, member-destruction)**:

| Config | substrate `Memory.Inline` | buffer-local WA | same-pkg | cross-pkg |
|---|---|---|---|---|
| composed (current prod) | `AnyObject?` | none | works | **LEAK** (deinit skipped) |
| composed + double WA | `AnyObject?` | `AnyObject?` | — | **SIGSEGV** |
| composed + single buffer WA (H1) | **clean** | `AnyObject?` | **SIGSEGV** | **LEAK** (deinit skipped) |
| DIRECT `@_rawLayout` (Arena.Inline) | n/a (direct `_Elements`, same module) | `AnyObject?` | works | **works** |

**Consequence for the MSB tower**: "compose `Storage.Contiguous<Memory.Inline>` AND tear down leak-free cross-package AND no direct `@_rawLayout`" is **simultaneously unsatisfiable** on 6.3.2 — composition makes the `@_rawLayout` cross-module by construction. The inline-sparse buffers (`Buffer.{Slab,Linked,Arena}.Inline`) therefore require EITHER a direct-`@_rawLayout` carve-out (Cleave-6 Option A) OR an upstream `#86652` fix. **Do NOT re-run the H1 spike** (single buffer WA + clean composed substrate) — it is refuted here (cross-package leak + same-package SIGSEGV).

**What an upstream fix must do**: classify a struct whose value-witness transitively contains a cross-module `@_rawLayout` member as **non-trivially destructible** cross-package (so member-destruction + the buffer `deinit` fire), and stop the buffer-`AnyObject?` + nested-`@_rawLayout` same-package miscompile.

**NOT synthetically reproducible** — a faithful 5-package /tmp model (Element→MemLeaf→StoreSeam→BufTier→Holder→consumer) does NOT reproduce the deinit-skip in debug (passes where prod fails) and release-ICEs on the `@_rawLayout`+deinit LLVM verifier ("Instruction does not dominate all uses"). Consistent with §A9/§A11/§A12: this bug class is context-sensitive; the **production tree is the only faithful bed**.

**Evidence**: Cleave-7 session 2026-06-06; spike + restoration receipts (commit SHAs, deinit-entry-print diagnostic confirming the body is skipped) in `~/Developer/.handoffs/cleave-7-PROGRESS.md`. Original production reproduction: `swift-list-linked-primitives` "List - Deinit" (6 inline-mode leaks, `deinitCount → 0`) — **NOTE: those tests were dissolved with `List.Linked.Inline`/`.Small` in Cleave-7 §C.1** (the in-tower cross-package consumers were removed, so the skip no longer manifests in the tower). The bug remains reproducible by ANY cross-package consumer of a kept `Buffer.{Slab,Linked,Arena}.Inline` (a `.disabled(swift#86652)` canary is the recommended removal-gate tripwire).

**Source**: 2026-06-06 Cleave-7 family-2 cross-package seam-fix investigation (`/goal`; DESIGN-FIRST; surfaced to the seat as a genuine wall).

---

### A15. Runtime cannot verify a conditional conformance whose same-type RHS is a `~Copyable` type (null-metadata SIGSEGV + silent wrong dynamic casts)

**Swift versions**: ALL — compilers 6.2, 6.2.3, 6.3.1, 6.3.2, 6.5-dev (2026-05-27 snapshot) × runtimes macOS 26.2 OS `libswiftCore` AND the 6.5-dev toolchain runtime (which exports `swift_runtimeSupportsNoncopyableTypes`). NOT a regression; NOT fixed upstream as of swiftlang/swift `6f5d855aedf` (2026-06-10). Investigation 2026-06-10 (`/issue-investigation`, the LEG-7 slotmap wall).

**Minimal reproducer** (8 declarations, single file, bare `swiftc`, NO feature flags; preserved at `.handoffs/probes-2026-06-10/noncopyable-sametype-conformance-crash/m20.swift`):

```swift
protocol P {}
struct Pool: ~Copyable {}
struct Gen<A: ~Copyable> {}
extension Gen: P where A == Pool {}          // ← same-type conditional conformance, ~Copyable RHS
struct W<S: P> { var s: S; var c: Int { 42 } }
let w = W<Gen<Pool>>(s: .init())             // construction OK
print(w.c)                                   // ← SIGSEGV at -Onone: EXC_BAD_ACCESS (code=1, address=0x10)
```

**Two symptoms**: (1) at `-Onone`, any computed-member access on `W<Gen<Pool>>` (class wrapper: even instantiation) dereferences null metadata at `+0x10`; (2) crash-free and silent — `(Gen<Pool>() as Any) is any P` returns **false** (should be true). `SWIFT_DEBUG_FAILED_TYPE_LOOKUP=1` prints `subject type x does not conform to protocol P` before the fault.

**Constraint model** (each independently verified): requires same-type conditional conformance (inverse-only condition passes) + `~Copyable` RHS (Copyable RHS passes) + wrapper generic bound on the protocol (unbounded passes) + a stored field of the bound param (phantom-only passes) + `-Onone` member access (`-O` statically specializes — but `_mangledTypeName(W<Gen<Pool>>.self)` crashes even at `-O`). NOT required: any protocol requirement, associated types, `SuppressedAssociatedTypes`, Tagged, `~Copyable` on the conforming/wrapper types, nesting, module boundaries, SwiftPM.

**Mechanism** (lldb-traced; sources @ `6f5d855aedf`): `__swift_instantiateConcreteTypeFromMangledName` → `_gatherGenericParameters` → `_checkGenericRequirements(S: P)` → `Gen: P` conditional → `TargetProtocolConformanceDescriptor::getWitnessTable` → SameType case (`stdlib/public/runtime/ProtocolConformance.cpp:1843`) — BOTH sides of `A == Pool` resolve (Pool's metadata accessor fires from inside the check) yet the check fails; error swallowed; lookup returns null; IRGen's stub has no null check. Related runtime property: noncopyable nominals are invisible to textual by-name lookup on EVERY runtime — records segregated into `__swift5_types2` (`lib/IRGen/GenDecl.cpp:977`) which no runtime scans (`ImageInspectionCommon.h:35` is the sole mention); `_typeByName` on any noncopyable nominal returns nil.

**Distinct from §A9** (which has the same observable 0x10 family): §A9 = malformed `SuppressedAssociatedTypes` mangling emitted by 6.3.x ("unknown error"; fix travels with the 6.4-dev+ compiler). §A15 = runtime conditional-conformance logic ("does not conform to protocol"; broken everywhere incl. 6.5-dev). The LEG-7 slotmap DEBUG wall carries the §A15 signature (`subject type x does not conform to protocol __StoreProtocol`), NOT §A9's — the "§A9 family" label in the 2026-06-10 handoff conflated two distinct bugs. The recorded Set.Ordered/Graph crashes remain §A9 (correctly gated `compiler(<6.4)`); they are NOT §A15 (no same-type-noncopyable conformance on those paths — ecosystem grep finds exactly one such conformance, Generational's).

**Tower trigger**: `Storage.Generational: Store.Protocol where Allocation == Memory.Allocator<Memory.Heap>.Pool` (`swift-storage-arena-primitives/…/Storage.Generational+Store.Protocol.swift:39-40`) — the ecosystem's ONLY same-type conditional conformance. Any generic wrapper bounded on `Store.Protocol` (& anything) storing a `Generational` column crashes on first member access in DEBUG.

**Mitigation — APPLIED 2026-06-10 (W5-1)**: the protocol-bound respelling, shipped as the law-bearing capability seam `Memory.Pool.`Protocol`` (+ the `Memory.Pooling` gerund) in swift-memory-allocation-primitives `9dd38e7`; `Storage.Generational`'s DECLARATION binds `Allocation: Memory.Pooling` (the deinit oracle derives slot addresses per access once the `_baseRaw`/`_slotStride` caches drop, so the bound must live on the type) and the seam conformance conditions become INVERSE-ONLY (arena `208c8d1`) — the ecosystem's last same-type `~Copyable` conditional conformance is gone. A bare marker protocol was REJECTED (principal policy + witness-availability degeneration: the witness bodies call pool ops, so the "empty" marker degenerates into a protocolized pool). The explicit `, A: ~Copyable` next to the protocol bound is load-bearing (bare `A: Marker` re-defaults Copyable per SE-0427 — `m30.swift` compile error). Verification: spike over the real packages debug+release (`.handoffs/probes-2026-06-10/a15-pooling-seam-spike/`); the preserved slotmap repro probe passes BOTH configs post-fix; the slot-map LEG-7 debug carve-outs are lifted and the `.disabled` [DS-024] law test re-enabled (slot-map `f89363f`, 10/5 both configs).

**A′ — constrained-nesting descriptor shape verified clean** (`aprime.swift`, bare swiftc, no flags, -Onone AND -O 3/3): with the capability bound riding the ENCLOSING extension (`extension Storage where A: Cap, A: ~Copyable { struct Gen<E: ~Copyable> }`) and inverse-only conformance conditions, (1) nested-type metadata instantiation through a protocol-bounded wrapper passes, (2) the dynamic cast is truthful, (3) `_mangledTypeName` over the wrapper instantiation returns a value (it crashed even at `-O` on the broken same-type shape).

**No-auto-lift record (§A15 ≠ §A9)**: §A15 is NOT fixed by the 6.4-dev+ compiler (broken through 6.5-dev); the mitigation is the institute-side respelling above. The `compiler(<6.4)` gates protecting the recorded §A9 paths (Set.Ordered/Graph) must NOT be lifted on §A15 grounds, and a future 6.4 gate-bump does not retire this entry — only an upstream runtime fix does.

**Reproducer + dossier**: probes at `.handoffs/probes-2026-06-10/noncopyable-sametype-conformance-crash/` (FINDINGS.md = full bisect record; `aprime.swift` = the A′ probe); upstream dossier STAGED (not filed — needs principal YES) at `swift-institute/Issues/swift-issue-noncopyable-sametype-conditional-conformance/`.

---

### A16. Bodyless `shared [serialized]` default-witness `read` accessor for a `~Copyable` associated-type property bound to `Never` (cross-module)

**Swift versions**: 6.3.2 → 6.5-dev (2026-05-27 snapshot) — UNFIXED. Surfaces only when SIL verification runs: +Asserts toolchains (Windows 6.3.2-RELEASE), Embedded (any toolchain), or `-Xfrontend -sil-verify-all` on any toolchain. On NoAsserts RELEASE (stock macOS/Linux) the malformed SIL is emitted but never verified → silent success (latent). Investigation 2026-06-25 (`/issue-investigation`, `HANDOFF-windows-compiler-crashes.md`).

**Symptom**: emit-module / `-c` of a *consumer* module crashes lowering AST to SIL —
```
<unknown>:0: note: Must have a construct to emit for           # +Asserts (Windows)
SIL verification failed: public/package/shared function must have a body   # Embedded / -sil-verify-all
While verifying SIL function "...Protocol...body...read" for read for body (in module '<DefiningModule>')
```
The crashing function demangles to `<Proto>.Protocol.body.read where Body == Never, Self: ~Copyable` — the leaf-default `read` accessor, originating in the *defining* module but emitted bodyless into the consumer.

**Minimal reproducer** (2 files, bare `swiftc`, stock Xcode 6.3.2, no SwiftPM):
```swift
// module M
public protocol P: ~Copyable {
    associatedtype Body: ~Copyable
    var body: Body { borrowing get }
}
extension P where Self: ~Copyable, Body == Never {
    @inlinable public var body: Never { borrowing get { fatalError() } }
}
public struct InCore: P { public typealias Body = Never; public init() {} }   // in-defining-module conformer
// module N
public import M
public struct Use: P { public typealias Body = Never; public init() {} }       // consumer-module conformer
```
```
swiftc -enable-experimental-feature SuppressedAssociatedTypes -wmo -parse-as-library \
       -emit-module -emit-module-path M.swiftmodule -module-name M repro-core.swift
swiftc -enable-experimental-feature SuppressedAssociatedTypes -Xfrontend -sil-verify-all \
       -wmo -parse-as-library -c repro-consumer.swift -I . -module-name N        # → "Must have a construct to emit for"
```

**Constraint model** (each verified by removal): requires (1) `associatedtype Body: ~Copyable` (Copyable `Body` passes; the protocol/`Self` being `~Copyable` is NOT required — only the associated type); (2) a property requirement of that type + a `Body == Never` default returning `Never`; (3) a `Body == Never` conformer in the *defining* module; (4) a `Body == Never` conformer in a *consumer* module; (5) SIL verification active. NOT required: `@inlinable`, `borrowing get` (plain `get` also crashes), result builders, the package's experimental feature flags.

**Mechanism**: the leaf-default's `read` coroutine yields the uninhabited `Never`. The in-defining-module conformer forces the generic default to be serialized into the defining `.swiftmodule`; a consumer conformer's witness table then references it and the compiler emits it as a `shared [serialized]` SIL function with no body. SIL verification rejects a bodyless public/package/shared function. Only the verifier's presence differs across platforms — hence macOS/Linux RELEASE pass while Windows/Embedded fail on identical code.

**Workarounds**: `@_optimize(none)`, `@inline(never)`, `@_alwaysEmitIntoClient` on the default — all FAIL (verification, not optimization). The only verified mitigation is structural: remove the `Body == Never` conformer from the *defining* module (relocate it to a separate target), so the serialized default is never instantiated there. A `#if !os(Windows)`/`#if !hasFeature(Embedded)` guard does NOT apply (guarding the default out leaves leaf conformers without a `body` witness; and the malformed SIL is emitted on every platform regardless). **APPLIED 2026-06-25**: `Serializer.Witness` relocated to its own `Serializer Witness Primitives` target (`swift-primitives/swift-serializer-primitives` `a652cec`); verified clean (stock Xcode 6.3.2 + `-sil-verify-all`, Embedded 6.5-dev). Workaround only — compiler bug still unfixed on 6.5-dev.

**Scope**: affects EVERY leaf combinator in swift-serializer-primitives (Map/Optional/Many/Filter/Lazy/Literal/Always/Fail/Trace/Tagged), not only Trace — the Windows build merely halted at Trace first.

**Reproducer + dossier**: STAGED (not pushed) at `swift-institute/Issues/swift-issue-noncopyable-assoctype-never-bodyless-witness/`. Windows evidence: `swift-primitives/swift-serializer-primitives` CI run `28169921710` job `83431175554`. Source: `Serializer.Protocol.swift:73-81` (leaf-default), `Serializer.Witness+Protocol.swift:13-22` (in-core conformer).

---

### A17. Sema `getEffects(req).contains(getEffects(witness))` assertion: `throws(Never)` derived witness vs non-throwing `IteratorProtocol.next()`

**Swift versions**: 6.3.2 (+Asserts) CRASH; **FIXED on 6.5-dev** (2026-05-27 snapshot — real swift-input-primitives test target and a faithful cross-module model both build clean). +Asserts-only; NoAsserts RELEASE legs (macOS/Linux) pass. Investigation 2026-06-25 (`/issue-investigation`, `HANDOFF-windows-compiler-crashes.md`).

**Symptom**: type-checking a protocol conformance aborts —
```
Assertion failed: getEffects(req).contains(getEffects(witness)) &&
    "witness has more effects than requirement?", lib/Sema/TypeCheckProtocol.cpp:1311
While evaluating request ResolveValueWitnessesRequest(... : IteratorProtocol)
```

**Trigger**: a type conforms in one extension to BOTH (a) a custom chunk protocol whose `where Element: Copyable` extension supplies a derived `mutating func next() throws(Failure) -> Element?` (with `Failure == Never`, i.e. `throws(Never)`), and (b) stdlib `IteratorProtocol` (a non-throwing `next()` requirement). When resolving the `IteratorProtocol.next()` witness, the `throws(Never)` derived candidate's effect set carries a `throws` effect the requirement lacks; the effects-containment assertion fires before `throws(Never)` is reduced to non-throwing. (An explicitly-written `next() -> Element?` is also present → witness contention under typed throws.)

**Reproducer**: faithful cross-module model preserved at `swift-institute/Issues/swift-issue-typed-throws-never-witness-effects-assertion/repro.swift` (depends on swift-iterator-primitives). It reproduces the shape but cannot trigger the assertion on any locally-available toolchain (the 6.3.2 snapshots on this machine are NoAsserts; 6.5-dev has the fix); the Windows CI run is the reproduction of record.

**Fix verification ([ISSUE-001])**: `TOOLCHAINS=org.swift.64202605271a swift build --build-tests` on the real package → `Build complete!`, zero crash markers. **Coverage scope ([ISSUE-026])**: confirmed PRESENT on 6.3.2 +Asserts (Windows CI), confirmed FIXED on 6.5-dev; exact 6.4-stable status not locally verifiable (no 6.3.2/6.4 +Asserts toolchain on hand).

**Resolution ([ISSUE-008] fixed-on-dev)**: Windows 6.3.2-RELEASE won't get the fix until its toolchain advances → a test-code workaround is needed to green Windows CI now (guard `#if !os(Windows)`, drop the `IteratorProtocol` conformance if unused, or disambiguate the witness). Left to principal per [ISSUE-022]. Distinct from the typed-throws-in-`#expect` SIL crash already worked around in `Input.Buffer/Slice Tests.swift`.

**Dossier**: STAGED (not pushed) at `swift-institute/Issues/swift-issue-typed-throws-never-witness-effects-assertion/`. Windows evidence: `swift-primitives/swift-input-primitives` CI run `28169939296` job `83431230550`. Source: `Input.Slice Tests.swift:31`; derived witness `Iterator.Chunk.Protocol.swift:15-27`.

---

### A18. `Mem2Reg` / `OSSACompleteLifetime` `SILBitfield.h:60` per-function bitfield overflow from `@inlinable` inlining into a test function

**Swift versions**: 6.3.2 — reproduces on BOTH macOS-release (arm64) and Linux-release (x86_64) at `-O`; `-Onone`/debug clean on all platforms. UNFIXED (not retested on 6.4/6.5-dev). **Distinct from §A13/#89617** (different pass, function, and assertion).

**Symptom**:
```
Assertion failed: (endBit <= T::numCustomBits && "too many/large bit fields allocated in function"),
  function SILBitfield at SILBitfield.h:60.
While running pass "Mem2Reg" on SILFunction "<the @Test function>"
  → OSSACompleteLifetime::analyzeAndUpdateLifetime ⇄ InteriorLiveness::compute (deep recursion)
  → StackAllocationPromoter::run → SILMem2Reg::run → signal 6 / fatalError
```

**Root cause**: `SILBitfield` is a per-`SILFunction` scratch bit allocator with a fixed budget (`numCustomBits`). `Mem2Reg`'s `StackAllocationPromoter` calls `OSSACompleteLifetime::completeOSSALifetime`, which walks borrow scopes via `InteriorLiveness` and **recurses on a deeply nested interior-borrow graph**, allocating `SILBitfield`s as it descends; past a threshold it overflows. Under `-O` the inliner collapses an `@inlinable` ~Copyable/generic/closure-bearing accessor+init chain into one function, producing the deep graph. The crash is on the **inlining-sink** function (here a `@Test`), not the library declarations (Sources release-compile clean). A scalability limit, not a miscompile; the `ASSERT` fires even in NDEBUG → loud build-blocker.

**Ingredients**: (1) `-O`; (2) an `@inlinable` chain over a move-only/generic value heavy on nested borrows (e.g. `Fixed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear.Bounded>` accessors); (3) a sink function the inliner collapses it into above an accessor-count threshold (the smaller move-only test in the same suite did NOT trip it).

**Workaround**: source-restructuring — split the sink function, or reduce its per-function inlined complexity so the inliner cannot collapse the chain past the budget (per amended [ISSUE-008], `swift-institute/Skills`). `@_optimize(none)` on the sink function is **forbidden**, not merely disfavoured: it is itself miscompile-prone — see §A19, which documents that it elides move-only element `deinit`s inside an `-O` module (a silent teardown miscompile).

**Production / evidence**: `swift-fixed-primitives` `Tests/Fixed Primitives Tests/Fixed Tests.swift` (5 of 6 `@Test`s tripped it). CI run `28230583451` (Linux); macOS-release `swift build --build-tests -c release` reproduces byte-identical (same pass/function/assertion). Fix committed `5457eca`; 6.3-release CI leg green (runs `28243845222`/`28244117012`). Dossier: `swift-institute/Issues/swift-issue-fixed-release-compiler-crash/`.

**Source**: 2026-06-26 swift-fixed-primitives release-CI investigation.

---

### A19. `@_optimize(none)` + `consume` of a `~Copyable`-with-`deinit` value elides the element `deinit`s

**Swift versions**: 6.3.2 — macOS-release AND Linux-release at `-O`; full `-Onone`/debug correct. UNFIXED.

**Symptom**: a function marked `@_optimize(none)` (inside an otherwise `-O` module) that `consume`s a move-only value whose elements have observable `deinit`s runs **0** deinits instead of N (`destroyedCount → 0`). No diagnostic; a silent missed-destroy.

**Root cause (hypothesis)**: NoOptimization codegen for a `consume`/end-of-scope destroy of a `~Copyable` value within an `-O` module fails to emit the element teardown. The library type's value-witness/teardown is correct on its own — full `-Onone` AND the unannotated `-O` build both run the deinits — so the defect is the hybrid `@_optimize(none)`-function-inside-an-`-O`-module mode, not the library.

**Ingredients (verified by [ISSUE-013] variable isolation)**: (1) `-O` build; (2) `@_optimize(none)` on the function; (3) the function `consume`s / end-of-scope destroys a `~Copyable` value with element `deinit`s. Removing **only** (2) restores correct teardown (`destroyedCount → 2`).

**NOT a library bug**: this explicitly refutes an intermediate "release teardown miscompile with blast radius across the `Buffer`/`Storage` family (other public packages silently leaking)" reading. The `Fixed`/Buffer/Storage teardown is correct at `-O`; only the `@_optimize(none)` annotation suppresses it. The misreading came from observing failure on both macOS- and Linux-release *with the annotation present* and inferring platform-independence of a library bug; the missing control was release *without* the annotation.

**Workaround**: never `@_optimize(none)` a function that must observe move-only element `deinit`s. (It surfaced only because §A18's workaround put `@_optimize(none)` on a deinit-counting test; leaving that one test unannotated fixed it, and it does not trip §A18 anyway.)

**Production / evidence**: `swift-fixed-primitives` test `move-only elements live in Fixed and tear down once`. Dossier: `swift-institute/Issues/swift-issue-fixed-release-compiler-crash/` (Issue #2).

**Source**: 2026-06-26 swift-fixed-primitives release-CI investigation.

---

### A20. `Mangler::verify` (`Mangler.cpp:176`) abort on the `@_implements(Iterable, makeIterator())` witness returning a nested-generic `Materializing<Vector.Iterator>`

**Swift versions**: 6.3.2 `+Asserts` (Windows CI gating leg) CRASH; reproduced on `swiftlang/swift:nightly-6.3-jammy` = 6.3.0-dev (`f30e11b`) AND 6.3.3-dev (`c83acbf`), both `+assertions`. UNFIXED across the 6.3 line. NoAsserts (stock macOS/Linux 6.3.2 release) GREEN. Investigation 2026-06-26 (`/issue-investigation`, `HANDOFF-vector-sequenceable-windows-asserts-ice.md`).

**Symptom**: emit-module / `-c` of the consumer (ops) module aborts lowering AST to SIL —
```
While evaluating request ASTLoweringRequest(Lowering AST to SIL for module Vector_Primitives)
Abort: function verify at Mangler.cpp:176
Can't demangle: $s16Vector_Primitive0A0V0A11_PrimitivesE20iterableMakeIterator0f1_B00F0O0f7_Chunk_C0E13MaterializingVy_AcARi_zrlEAGVyx_GAmH0F9_ProtocolE0I0AD_HCg_GyF
```
The symbol demangles to `Vector.(ext in Vector_Primitives).iterableMakeIterator() -> Iterator.Chunk.Materializing<Vector<A>.Iterator>` — the **Iterable `@_implements(Iterable, makeIterator())` witness**. Stack: `Mangle::Mangler::verify` ← `ASTMangler::mangleEntity` ← `SILDeclRef::mangle` ← `SILFunctionBuilder::getOrCreateFunction` ← `SILGenModule::emitFunction(FuncDecl*)` ← `SILGenExtension::visitFuncDecl`.

**Mechanism**: the `+Asserts` mangler emits a symbol for a witness whose signature embeds the **deep generic instantiation** `Materializing<Vector<A>.Iterator>` (an adapter parameterized by the conforming type's own nested `~Copyable` iterator), carrying a `~Escapable` requirement (`Ri_z`) and an associated-conformance node (`HCg`) — and the mangler's own round-trip self-check cannot re-demangle it. `Mangler::verify` is `CONDITIONAL_ASSERT_enabled()`-gated, so it runs only on +Asserts toolchains; NoAsserts emits the malformed name unverified → latent (macOS/Linux pass). **Same class as §A12** (corrupt/un-roundtrippable mangled name for a nested-generic iterator-adapter witness); §A12 was a `Sequenceable.Iterator` witness surfacing at IRGen/runtime, this is an `Iterable.Iterator` witness surfacing at SILGen via `Mangler::verify`. Distinct from §A16 (bodyless witness) and §A17 (Sema effects-containment assertion).

**Attribution correction**: the originating handoff presumed the crash was the **Sequenceable** witness (because the WMO emit-module diagnostic's *file* attribution lands on `Vector+Sequenceable.swift`). It is the **Iterable** witness `iterableMakeIterator` in `Vector+Iterable.swift`. Verified three ways: (1) the real-package crash symbol is `iterableMakeIterator`; (2) reducer matrix — removing the Sequenceable conformance does NOT fix it; (3) **dropping the Iterable conformance turns CRASH → PASS** (the isolation proof).

**Minimal reproducer** (2 modules, bare `swiftc`, host-PASS + asserts-CRASH): `swift-institute/Issues/swift-issue-vector-iterable-materializing-mangler-verify/` (`defining.swift` + `consumer.swift` + `build.sh`; `CHARACTERIZATION.md` has the full analysis; `real-package-crash-6.3.3-dev.log` is the real-package abort).

**Why Vector and no other Iterable conformer** (built on the +Asserts image): the `Materializing<Iterator>` + `@_implements(Iterable, makeIterator())` pattern is used by ~10 types; `swift-bit-vector-primitives` (8 types, value-generic), `swift-buffer-slab-primitives` (type param `S` kept `~Copyable`), and `swift-single-iterator-primitives` (binds the SHARED `Materializing<Iterator.Once<Element>>`) all compile CLEAN. Vector is the only one combining **two** traits, each harmless alone: **(A)** Iterable.Iterator wraps Vector's OWN nested iterator `Materializing<Vector<Bound>.Iterator>` (deep generic — confirmed load-bearing: swapping to a shared element-generic iterator flips CRASH→PASS), and **(B)** Vector re-Copyable-izes its `~Copyable` type param (`Vector<Bound: ~Copyable>` + `where Bound: Copyable`, because its param IS its element). buffer-slab has A-not-B → pass; Single has B-without-A → pass; Vector has both → the mangler can't round-trip the name.

**Workaround — APPLIED & VALIDATED (the §A12 element-only-generic dodge)**: bind `Iterable.Iterator` to the SHARED element-generic `Iterator.Witness<Bound, Never>` instead of Vector's own nested iterator (exactly the Single pattern). Type-erase the scalar cursor through `Iterator.Witness` before materializing — lazy, behavior-preserving, no new Vector type, all three conformances retained:
```swift
public typealias IterableIterator = Iterator.Materializing<Iterator.Witness<Bound, Never>>          // was Materializing<Iterator>
func iterableMakeIterator() -> Iterator.Materializing<Iterator.Witness<Bound, Never>> {
    Iterator.Materializing(Iterator.Witness(makeIterator())) }                                       // was Materializing(scalar)
// + "Vector Primitives" target dep on product "Iterator Witness Primitives"
```
`Materializing<Iterator.Witness<Bound, Never>>` mangles shallow, dodging the verifier. **Validated**: +Asserts (nightly-6.3-jammy 6.3.3-dev) `Vector Primitives` build clean; macOS 106 tests pass. Applied to `swift-vector-primitives` `64daf53` 2026-06-26 (Vector + Vector.Reversed). Drop-Iterable and `#if !os(Windows)` were the rejected alternatives; `@_optimize(none)`/`@inline(never)` do NOT help (mangling, not optimization). Compiler bug itself UNFIXED.

**Production / evidence**: `swift-primitives/swift-vector-primitives` @ `6b85557`, target `Vector Primitives`. CI: vector run `28250591435` job `Windows (Swift 6.3, debug)` step `Build`; pre-restructure run `28244613615` (sha `7740cc4`) shows the identical crash attributed to `Vector+Iterable.swift`. Source: `Vector+Iterable.swift:75-97` (the `@_implements` Iterable conformance + `iterableMakeIterator`), `Vector+Iterable.swift:38` (dual `IterP`/`IteratorProtocol`), `Vector+ConformanceSupport.swift:35` (`_makeSequenceIterator` window).

**Source**: 2026-06-26 swift-vector-primitives Windows +Asserts investigation (`HANDOFF-vector-sequenceable-windows-asserts-ice.md`).

---

### A21. `getMangledName` (`IRGenDebugInfo.cpp:1098`) abort emitting debug info for a named local of a value-generic same-type-constrained typealias (`Axis<N>.*`)

**Swift versions**: 6.3 `+Asserts` (Windows CI gating leg, `swift-6.3-windows-toolchain`) CRASH; reproduced on `swiftlang/swift:nightly-6.3-jammy` = 6.3.3-dev (`c83acbf`), `+assertions`. UNFIXED on the 6.3 line. NoAsserts (stock macOS/Linux 6.3.3 release) GREEN. The library compiles clean everywhere — only the **test target** crashes. Investigation 2026-06-27 (`/issue-investigation`, `HANDOFF-dimension-algebra-windows-asserts-ice.md`).

**Symptom**: `-Onone -g` build of the test target aborts in IRGen debug-info emission —
```
Abort: function getMangledName at .../lib/IRGen/IRGenDebugInfo.cpp:1098
Failed to reconstruct type for $s14Axis_Primitive0A0V20Dimension_PrimitivesSiRVz$1_RszlE8Verticalay$1__GD
Pass '-Xfrontend -disable-round-trip-debug-types' to disable this assertion.
```
The symbol is `Axis<2>.Vertical` (value-generic same-type-constrained member typealias; `$…_Rsz…` carries the value-generic requirement). Stack: `IRGenDebugInfoImpl::getMangledName` ← `getOrCreateType` ← `emitVariableDeclaration` — the decisive frame is `emitVariableDeclaration`: the crash emits the debug-info type record for a **source variable** whose declared type is the sugared typealias.

**Mechanism**: `Axis<let N: Int>` (swift-axis-primitives) + `extension Axis where N == 2 { typealias Vertical = Dimension_Primitives.Vertical }` (and the Depth/Horizontal/Direction/Temporal siblings, each `where N == k`). A test declares a **named local of the sugared type** (`let v: Axis<2>.Vertical = .downward`); under `-g` IRGen mangles its debug type to a name the round-trip self-check cannot re-demangle → abort. Assert-gated → +Asserts-only (Windows); NoAsserts emits it unverified → latent (macOS/Linux green). **Same class as §A20** (vector): +Asserts mangled-name round-trip on a value-generic/deep institute construct — §A20 is `Mangler::verify` at SILGen on an `@_implements` witness name, this is `getMangledName` at IRGen debug-info on a variable's declared type. The whole `Axis<N>.{Vertical,Depth,Horizontal,Direction,Temporal}` family is affected (CI hit `Axis<3>.Depth` first, the local baseline hit `Axis<2>.Vertical` first — file ordering).

**Reproducer**: canonical = build the real package's test target on the +Asserts image (dossier `evidence/real-package-crash-6.3.3-dev.log`). A minimal 2-module bare-`swiftc` reduction did **not** reproduce (the trigger needs the cross-module named-local context) — recorded as a negative result per [ISSUE-026]. Ingredient model: value-generic typealias + named local of the sugared type in a downstream module + `-g` + +Asserts; removing any one (drop `-g`, annotate with the canonical underlying type, or reference in expression position) clears it.

**Workaround — APPLIED & VALIDATED (test-side expression-position rewrite)**: reference `Axis<N>.*` in expression position instead of as the declared type of a named local:
```swift
#expect(Axis<2>.Vertical.downward == Vertical.downward)          // was: let v: Axis<2>.Vertical = .downward; #expect(v == …)
```
Expression-position member access yields inferred-**canonical** types (`Vertical`), so no `emitVariableDeclaration` runs for the sugared type and `getMangledName` is never called on it. All 5 typealias **source files are untouched** (API maintained); no unsafeFlags. Coverage preserved (identity via homogeneous `==`, all members, existence, multi-dim `Axis<1..4>.Direction`). The two structural dodges — `-Xfrontend -disable-round-trip-debug-types` on the test target, and removing the (0-consumer) family — were **both principal-rejected** (no unsafeFlags; the family is domain-complete API per [ARCH-LAYER-006]/[ARCH-LAYER-008], consumer count must not drive removal). **Validated**: +Asserts `build --build-tests` clean (19.88s); macOS 268 tests pass. Applied to `swift-dimension-primitives` `5b940ee` 2026-06-27; Windows leg run `28280214029` => success. Compiler bug UNFIXED — latent-on-+Asserts for any consumer declaring a named local of a value-generic same-type-constrained typealias under `-g`.

**Production / evidence**: `swift-primitives/swift-dimension-primitives` `6939cea`→`5b940ee`. Dossier: `swift-institute/Issues/swift-issue-dimension-axis-typealias-windows-asserts-ice/`.

**Source**: 2026-06-27 swift-dimension-primitives Windows +Asserts investigation.

---

### A22. `hasErrorResult()` (`Types.h:5274`) abort on a non-throwing → typed-throws (nested-generic error) conversion thunk

**Swift versions**: 6.3 `+Asserts` (Windows CI gating leg) CRASH; reproduced on `swiftlang/swift:nightly-6.3-jammy` 6.3.3-dev (`c83acbf`), `+assertions`; also fired the advisory `Ubuntu (Swift main nightly, release)` leg (assertions-enabled nightly, `Types.h:5374`). UNFIXED on the 6.3 line. NoAsserts (stock macOS/Linux 6.3.3 release) GREEN. The library compiles clean everywhere — only the **test target** crashes. Investigation 2026-06-27 (`HANDOFF-dimension-algebra-windows-asserts-ice.md`).

**Symptom**: `-Onone -g` IRGen of the test file aborts —
```
swift-frontend: .../AST/Types.h:5274: SILResultInfo &swift::SILFunctionType::getMutableErrorResult(): Assertion `hasErrorResult()' failed.
While evaluating request IRGenRequest(IR Generation for file ".../Algebra.Law Tests.swift")
... for expression at [Algebra.Law Tests.swift:100:25 - line:100:38] RangeText="{ _ in false "
```

**Mechanism**: `Algebra.Field<Element>` stores `reciprocal: (Element) throws(Algebra.Field<Element>.Error) -> Element` — typed-throws with the **nested-generic** error `Field<Element>.Error`. A test fixture assigns a **bare non-throwing** literal `{ _ in false }`. The non-throwing → typed-throws subtype conversion inserts a reabstraction thunk; under +Asserts `-g`, IRGen of the thunk's SIL function type calls `getMutableErrorResult()`, whose `hasErrorResult()` assert fails (the thunk's type lacks the error result the assert expects). Assert-gated → +Asserts-only; NoAsserts skips it → latent. **Distinct from §A13** (`FunctionSignatureOpts` `SILArgument.cpp:40` on a generic *thrown* error at `-O`): this is `-Onone -g` IRGen of the *non-throwing→typed-throws conversion thunk*.

**Reproducer**: single-file `main.swift`, bare `swiftc`, host-PASS + asserts-CRASH (dossier `main.swift` + `build.sh`; `evidence/repro-crash-6.3.3-dev.log`). Ingredient model: a generic struct with a typed-throws stored closure whose error is the struct's own nested generic error, assigned a bare non-throwing literal. Explicit closure signature or a non-generic error removes the trigger.

**Workaround — APPLIED & VALIDATED (test-side explicit typed-throws signature)**:
```swift
reciprocal: { (_: Bool) throws(Algebra.Field<Bool>.Error) -> Bool in false }   // was: { _ in false }
```
Spelling the signature makes the closure natively typed-throws, so no conversion thunk is generated. Matches the already-working sibling `Algebra.Field Tests.swift:31`; library API (the nested-generic `Field<Element>.Error`, correct per [API-NAME-001]/[API-ERR-001]) unchanged. The library-side alternative (non-generic error) was rejected as an API change to dodge a compiler bug. **Validated**: +Asserts `build --build-tests` clean (6.80s); macOS 122 tests pass. Applied to `swift-algebra-primitives` `2b41253` 2026-06-27; Windows leg run `28280214397` => success. Compiler bug UNFIXED — latent-on-+Asserts for the same bare-literal-into-nested-generic-typed-throws pattern.

**Production / evidence**: `swift-primitives/swift-algebra-primitives` `8fe0381`→`2b41253`. Dossier: `swift-institute/Issues/swift-issue-algebra-field-typed-throws-windows-asserts-ice/`.

**Source**: 2026-06-27 swift-algebra-primitives Windows +Asserts investigation.

---

### A23. CopyPropagation shortens a `borrowing ~Copyable` value's borrow scope to end before a `try_apply` that consumes its `@guaranteed` field (the §A5 mechanism, now with a clean single-file reducer)

**Swift versions**: 6.3.3 (Xcode default, `swiftlang-6.3.3.1.3`) **CRASH** at `-O`; clean at `-Onone`. **FIXED** on 6.5-dev (`swift-latest` = `swift-DEVELOPMENT-SNAPSHOT-2026-05-27-a`, `Swift 4d0c97fa5b05711`, `+assertions`).

**Pattern**: A static func taking a `borrowing` `~Copyable` value plus a `borrowing Span<Byte>`, whose body is `do { try callee(span, to: value.field!) } catch { throw Mapped(error) }`, where the `catch` performs a typed-throws **error-type mapping** and `field` is itself a `~Copyable` (owning) optional. The `do/catch` lowers to a `try_apply` (normal + error continuation blocks) that consumes the `@guaranteed` borrowed field.

**Symptom** (`swiftc -O`, pass #226 `CopyPropagation`):
```
Found outside of lifetime use?!
Value:   %6 = begin_borrow %1 : $Context
Consuming User:   end_borrow %6 : $Context
Non Consuming User:   try_apply %15(%5, %13) : $@convention(thin)
        (@guaranteed Span<UInt8>, @guaranteed Descriptor) -> @error InnerError, normal bb3, error bb4
Found ownership error?!  →  signal 6
```

**Root cause**: SILGen emits a **well-formed** borrow scope (`end_borrow` in *both* the normal and error continuations, after the `try_apply` — verified via `-emit-silgen`). **CopyPropagation** shortens the `begin_borrow`/`end_borrow` of the borrowed value to end *before* the `try_apply`, which still uses the borrowed field; ownership verification then aborts. Identical mechanism to **§A5**; this entry adds the missing standalone reducer (§A5 had assumed WMO + cross-module inlining were required — **disproven**: a single-file `swiftc -O` reproduces). `-Xfrontend -sil-verify-all` surfaces the same failure as early as the mandatory `MoveOnlyChecker` (#448), confirming the lowering is fragile pre-optimizer; the default `-Onone` pipeline (verification off) compiles it cleanly.

**Reducer** (standalone, single file, zero deps — `swiftc -O reducer.swift`): `swift-institute/Issues/swift-issue-file-system-streaming-write-ownership/reducer.swift`. Ingredients (each required): (1) `~Copyable` value with an Optional `~Copyable` owning field (with `deinit`); (2) `borrowing` of that value + `borrowing Span<UInt8>`; (3) `do { try callee(span, to: value.field!) } catch { throw Mapped(error) }` typed-throws error mapping; (4) callee taking `@guaranteed Span` + `@guaranteed field` → `@error Inner`; (5) `-O`.

**Resolution (SHIPPED 2026-06-30 — STRUCTURAL, no suppression)**: house each descriptor-field-projecting throwing call inside a `borrowing` method on the `~Copyable` value (here `Context.write(chunk:)`/`sync()` propagating `File.System.Write.Error`); the caller maps the error at the boundary (`do { try context.write(chunk: span) } catch { throw Error(error) }`). Inside a `borrowing` method `self` is a whole-function `@guaranteed` parameter — no nested `begin_borrow`/`end_borrow` for CopyPropagation to shorten — and the caller's wrapped call takes the *whole* value as `@guaranteed self` (not a field projection), so the borrow spans the call by construction. Correct on ALL toolchains → no compiler gate. swift-file-system `-c release` crash→clean (commit `4b19e6b`).

**Empirical correction (2026-06-30)**: the abort is NOT specific to the `try_apply`. A reducer that eliminated the `try_apply` by giving the helper a non-throwing `Result<Void, …>` form STILL crashed — SIL then shows a plain `apply … -> @owned Result<…>` as the offending "Non Consuming User", same `begin_borrow`/`end_borrow`-of-value shortened before it. So the trigger is the *field-projected nested borrow scope*, independent of `try_apply` vs plain `apply`; the fix must target the borrow scope, not the error-mapping continuation. (Reducer variants: scratchpad `reducer-exp/` — `v0_baseline`/`vB_shim`/`vBmethod_shim` crash, `vA_borrowing_method` clean.)

**Rejected workaround**: `@_optimize(none)` on the crashing function (verified clean on the reducer) and the module-wide `-Xllvm -sil-disable-pass=CopyPropagation` (release only) were both rejected by the principal — ungated suppression is a footgun that would silently survive into Swift 6.5 (where the bug is FIXED), and the module-wide flag costs the whole module its CopyPropagation pass. §A5's `try?` fix does **not** apply (the `catch` maps the error type), and the descriptor cannot be hoisted out of the borrow (the field type is itself `~Copyable`).

**Distinct from**: upstream **#89787** (SILGenCleanup crash requiring `catch <enum-case-pattern>`; a 6.4 regression that *works* on 6.3.2 — opposite version profile; no `~Copyable` borrow) and **#78447** (C-header struct-pointer trigger). The `Found outside of lifetime use?!` string is the generic ownership-verifier diagnostic and is not itself a duplicate signal.

**Production / evidence**: `swift-foundations/swift-file-system` (crash at HEAD `7f1b013`; fixed at `4b19e6b`), module **File System Core**, `File.System.Write.Streaming.write(chunk:to:)` (`Sources/File System Core/File.System.Write.Streaming+API.swift:264`); was blocking `swift-pdf`'s `-c release` build. All three same-shape sites in the file (`write(chunk span:to:)`, `write(chunk buffer:to:)`, `commit(_:)`'s `syncFile` call) fixed with the one shared borrowing-method pattern; the reusable-buffer + Atomic APIs verified unaffected (owned-local, not borrowed, contexts). Dossier: `swift-institute/Issues/swift-issue-file-system-streaming-write-ownership/INVESTIGATION.md`.

**Source**: 2026-06-30 swift-file-system streaming-write ownership-verifier investigation.

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

**GENERALIZATION (2026-07-06, P4 leg — the mechanism is NOT Tagged-specific).** Member-TYPE lookup
on ANY generic carrier offers ALL same-named conditional typealiases regardless of where-clause
disjointness — verified on 6.3.3 (`swiftlang-6.3.3.1.3`) with a plain-`swiftc` 8-line reproducer,
no experimental features:

```swift
struct Carrier<S> {}
struct A {}; struct B {}
extension Carrier where S == A { typealias Member = Int }
extension Carrier where S == B { typealias Member = Bool }
let x: Carrier<A>.Member = 1     // error: ambiguous type name 'Member' in 'Carrier<A>'
let y: Carrier<B>.Member = true  // error: ambiguous type name 'Member' in 'Carrier<B>'
```

Even mutually exclusive concrete same-type pins collide, in concrete and generic contexts alike;
conformance-gated variants are additionally offered with ILL-FORMED substitutions (a witness
instantiated with a type argument violating its own generic bound). **Value-member lookup prunes by
constraints; type-member lookup does not.** Tower consequence: per-instantiation member-type names
on a shared carrier (e.g. `__Tree.Error` meaning a different error per storage column) CANNOT be
expressed as multiple conditional aliases — the working pattern is ONE flow-through alias +
an associatedtype witness on the column protocol (`extension __Tree where S: __TreeStorage
{ typealias Error = S.Error }` + per-column `Error` witnesses — the P4 S.Error shape, landed
tree `ea60802` / tree-keyed `e33e743`; probe matrix in the P4 leg's report, reproducer at the
rulings-log session scratchpad `repro-member-lookup.swift`). Discovered W3.2-B→P4; not
upstream-filed (the dossier/catalog is the terminal record per the workspace rule).

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

### B7. Mangling collision: body member vs defaulted-conformance extension member on an EXTENSION-NESTED inverse-generic type (VERIFIED 2026-06-11 — root-caused; collides 6.2 → 6.5-dev, not a regression)

**Symptom**: Sema accepts constraint-split twins — a member in the PRIMARY BODY of a generic type declared inside `extension P where Element: ~Copyable`, plus a same-signature member in `extension P.Child where Element: Copyable` — and overload resolution picks the correct twin; the mangler then conflates them. Same-file: frontend `multiple definitions of symbol`. Cross-file (the form production layouts hit): a misleading SIL `function type mismatch` pointing at the CALL SITE. Cross-file `-emit-library`: `ld: duplicate symbol`.

**Root cause** (read at swiftlang/swift `6f5d855aedf`): SE-0427 mangles only the ABSENCE of Copyable/Escapable, so `ASTMangler::gatherGenericSignatureParts` judges the Copyable-requiring extension "unconstrained" and `ASTMangler::appendExtension` (ASTMangler.cpp:3094) renders its member as a plain nominal member — byte-identical to the body member's context precisely when the child is extension-nested, because the child's nominal context chain itself carries the parent extension's inverse segment (forms F2 == F3 in the dossier's five-form table). Sema's redeclaration checker is constraint-aware (the same-constraint pair is correctly rejected, including vs the synthesized `init()`) — the compiler distinguishes in one phase exactly what it conflates in the other.

**Boundary (verified)**: extension-nesting of the child is LOAD-BEARING — top-level, body-nested, and non-generic-parent shapes are all immune (seat re-verified the immunity pair independently). Generalizes to `~Escapable` (`Ri0_zrl`), every member kind, depth-2 nesting; collides even against the compiler-synthesized implicit `init()`. Build-failure class — no silent-miscompile shape found ([ISSUE-026] residue: library-evolution mode, non-Darwin linkers, `.swiftinterface`-mediated clients untested; every within-module emission route errored).

**Workarounds (BOTH verified, every tested shape and depth)**: (1) member-level `where Element: Copyable` (SE-0267) — mangles with no extension segment, always distinct; (2) extension-homed twins — the `~Copyable` extension's requirement IS mangled (second inverse segment), distinct from the Copyable twin's dropped-requirement form; NOTE the Copyable extension member still occupies the body-member symbol form, so this spelling requires the primary body to declare NO same-signature member.

**Status**: VERIFIED + root-caused (was CANDIDATE → RECURRED). **CORRECTION 2026-06-11 — the `610e697` recurrence claim is FALSIFIED**: "on a nested-in-extension type even EXTENSION-HOMED twins collide" is false. Reconstruction on an isolated copy of swift-tree-unbounded-primitives: the committed member-where spelling builds clean; respelling all four inits as extension-homed twins ALSO builds clean (six distinct constructor symbols, demangle-verified); re-homing the `~Copyable` pair into the body reproduces the recorded collision exactly. The misread: the collision symbol demangles with an `(extension in …)< where A: ~Copyable>` prefix for BOTH definitions — including the body twin — so the collision genuinely reads as "extension-level twins" (seat re-verified the prefix on its own reproducer run). Both occurrences (stack `7e4200a`; trees 2026-06-11) were the SAME variant: body-vs-extension. The former resolution ladder's "(top-level generic types only)" restriction on extension-homing is WITHDRAWN. Toolchain matrix (labels per `swift --version`): collides on 6.2, 6.2.3, 6.3.1, 6.3.2 (RELEASE + Apple 6.3.2.1.108), 6.3-dev ×3, 6.4-dev ×2, 6.5-dev ×2 (through 2026-05-27 main); the ext-vs-ext control passes everywhere.

**Record (TERMINAL — no upstream filing, standing principal policy 2026-06-11)**: dossier `swift-institute/Issues/swift-issue-noncopyable-extension-member-mangling-collision/` (commits `19c6d40`+`093742e`, staged, unpushed) — 9-line reproducer, controls, ingredient/form tables, `evidence/captures.txt` §1–§11, differentiation vs #89684/#89389/#74303/#69615 and §A15; lane report `.handoffs/REPORT-lane-b7.md`; seat re-verification 2026-06-11 (probes 1–6 + demangle on `org.swift.632202605101a`) is this entry's basis.

**Provenance**: Lane A′ deviation 2, W5 Wave-2 (stack A-1) → trees-round recurrence record (`610e697`, now corrected) → lane tower-lane-b7 reduction + falsification (2026-06-11).

---

### B8. TSan × LifetimeDependence: `-sanitize=thread` falsely rejects mutating calls through `_modify`/address-accessor projections on `~Copyable & ~Escapable` lifetime-dependent self (6.3.2 — VERIFIED, carve ratified)

**Symptom**: with `-sanitize=thread`, 6.3.2 rejects code that is GREEN unsanitized at identical pins: `error: lifetime-dependent variable 'self' escapes its scope` (+ "depends on the lifetime of argument 'self'"). First site: sequence-primitives `Sequence.Drain+Property.Inout.swift:23` (`base.value.drain(body)`), failing dependents' whole TSan builds at dep-compile time.

**Isolated trigger** (single-file reduction + R/V/E matrix, probe corpus `.handoffs/probes-2026-06-11/tsan-spike/reduction/`): a mutating member call through a `nonmutating _modify` (or address-accessor) projection whose `self` is `~Copyable & ~Escapable` lifetime-dependent (`@_lifetime(&base)` init over a stored pointer — the `Ownership.Inout` shape). Ruled out: stale pins, fresh-scratch artifacts, emit-module-specificity, `@inlinable`, consuming-closure arguments. Borrowing/`_read` paths are CLEAN; `-enforce-exclusivity=unchecked` does NOT avoid it.

**Blast radius**: the projection idiom is the CANONICAL `Property.Inout` pattern — same-class sites in buffer-ring, buffer-linear, hash-table, bit-vector (~6 packages); uncarved, the wall blocks every tower TSan build.

**Workarounds (both verified)**: (1) source-level — the scoped-door respell (`withBase { $0.drain(body) }` over raw-pointer mutation; V2); (2) invocation-level — `-Xllvm -sil-disable-pass=lifetime-dependence-diagnostics`, RATIFIED 2026-06-11 as the arc-1 TSan-gate carve under conditions: sanitized legs only, never in manifests/sources, unsanitized legs remain the lifetime-diagnostics gate of record, and a seeded-race positive control rides every TSan gate (signal proven to survive the carve: 6/6 warnings).

**Status**: VERIFIED (TSan-conditional class — distinct from §A9/§A15, which are sanitizer-independent). 6.3.2; upstream state unknown — re-probe at the 6.4 canon bump. Terminal-record policy: no upstream filing.

**Provenance**: arc-1 W1 TSan feasibility spike (`REPORT-arc-shared-soundness-W1.md` §2–3), 2026-06-11; seat re-ran the positive control independently same day.

---

### B9. `-O` CopyPropagation crash: Bool-flow closures over `Span<class-element>` from a generic `throws(Failure)` scoped accessor (6.3.2 — VERIFIED, repro preserved)

**Symptom**: swift-frontend signal 6 at `-O` — `While running pass … "CopyPropagation" … Error! Found a leaked owned value that was never consumed. Value: %81 = copy_value %2 : $Span<Payload>` — compiling a TEST module whose closure does `guard count else { return false }` + `&&`-accumulation over the `Span<Payload>` (class element) vended by `Shared.withSpan`, inside nested async `@Sendable` closures.

**Boundary**: debug fine; `Span<Int>` (trivial element) fine; tsan-release WITH the B8 carve does not crash (instrumentation changes the SIL). A bare-Array single-file reduction did NOT reproduce — the wall needs the `withSpan` generic `throws(Failure)` hop context; the deterministic repro is the snapshotted pre-respell suite at `.handoffs/probes-2026-06-11/tsan-spike/w2-release-wall/` (crash log + the non-reproducing reduction attempt, preserved).

**Workaround (lawful, test-spelling)**: extract-then-assert — pull `[Int]` values out inside the borrow, assert OUTSIDE the closure. Tower relevance: any consumer writing the natural Bool-verification shape over a class-element span hits this at `-O`.

**Status**: VERIFIED with preserved deterministic repro (not single-file-reduced). 6.3.2; re-probe at the 6.4 bump. No upstream filing (standing policy).

**Provenance**: arc-1 W2 (`REPORT-arc-shared-soundness-W2.md` §3), 2026-06-11.

---

### B10. `-Onone` MovedAsyncVarDebugInfoPropagator: superlinear/non-terminating SIL pass on monolithic move-dense function bodies (6.3.2 — CANDIDATE, mitigated)

**Symptom**: the 6.3.2 frontend spins 1h19m+ at 100% CPU compiling a test module at `-Onone`; stack samples put 100% of time inside single `MovedAsyncVarDebugInfoPropagatorTransform::run()` invocations.

**Trigger shape**: ONE large function body dense with moves — an op loop + 10-case switch + move-only traffic + nested functions borrow-capturing `~Copyable` locals.

**Mitigation (one-variable flip, confirmed)**: identical semantics restructured as small per-op `mutating` methods on `~Copyable` stream structs → the same module compiles in ~6s. Binding shape constraint for arc-2's model-suite code: no monolithic stream bodies; no nested functions borrow-capturing `~Copyable` locals.

**Status**: CANDIDATE — not reduced to a minimal repro; the hanging variant is preserved verbatim as the seed at `.handoffs/probes-2026-06-11/arc2-w1-silhang/` (with frontend stack samples). 6.3.2 `-Onone`; re-probe at the 6.4 bump. No upstream filing (standing policy).

**Provenance**: arc-2 W1 incident (`REPORT-arc-model-tests-W1.md` Entry 2.5), 2026-06-11.

---

### B11. `-O` counted-loop-only "pool exhausted" trap on per-rep move-only arena creates (6.3.2 — CANDIDATE, mechanism unproven)

**Symptom**: a counted loop performing per-rep `Memory.Allocator<…>.Arena`/`Storage.Generational` create-fill-destroy cycles traps "pool exhausted" under `-O`, while the IDENTICAL straight-line sequence succeeds. Bisect: exact-fill 4 ✓, 256 ✓, fill-200 ✓; the FIRST in-loop repetition traps.

**Workaround (verified, bench-side)**: make the per-rep capacity loop-variant (`n &+ (r & 1)`) — the benches are immunized this way.

**Status**: CANDIDATE — NO wall-claim; the mechanism is unproven. Suspicion class: R-6-adjacent (`-O` move-only lifecycle mishandling, cf. swiftlang/swift#89832 — the deinit-omission family). Distillation to a minimal repro is /issue-investigation material; per standing policy any record is a swift-institute/Issues terminal dossier, never an upstream filing. Re-probe at the 6.4 canon bump.

**Evidence**: the bisect table + workaround in `REPORT-arc-bench-W4.md`; bench-side observation against arena `52537ef`.

**Provenance**: arc-3 batch-2 (2026-06-12), banked B-10 in `tower-family-benchmark-baselines.md`; catalog triage per the Round-W wrap-up.

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
