# Noncopyable Property Extract via UnderscoreOwned

<!--
---
version: 1.1.0
last_updated: 2026-05-09
status: DECISION
tier: 2
scope: ecosystem-wide
applies_to: [swift-either-primitives, any package vending an extraction property over ~Copyable storage]
trigger: forums-review of swift-either-primitives flagged a missing accessor — `Either<Never, T>.value` does not compile for `T: ~Copyable`. User asked to verify whether ANY non-method, non-init property-form exists in current Swift before accepting the gap.
toolchains_verified:
  - Swift 6.3.1 (Xcode 26.4 default)
  - Swift 6.4-dev nightly snapshot 2026-03-16-a (`org.swift.64202603161a`)
  - Swift 6.4-dev nightly snapshot 2026-05-07-a (`org.swift.64202605071a`) — installed this session
  - swiftlang/swift HEAD `e578b3a1e17` (read-only — not run)
changelog:
  - v1.1.0 (2026-05-09): Phase 2 blocked. Installed 2026-05-07 nightly post the 2026-04-30 consuming-accessor PR; the "copy of noncopyable typed value" compiler bug IS resolved, but a different structural rejection ("noncopyable 'X' cannot be consumed when captured by an escaping closure or borrowed by a non-Escapable type") fires on EVERY generic `~Copyable` enum with `@_owned consuming get` regardless of call-site shape (let-binding, consuming-parameter, explicit `consume` keyword). Non-generic `~Copyable` enums work; generic ones don't. Either's exact shape is generic. Phase 2 deferred indefinitely pending Swift compiler progress on generic-enum `@_owned` getters. Phase 1 (free function `value(of:)`) ships today as the working solution. Status moved IN_PROGRESS → DECISION.
  - v1.0.0 (2026-05-09): Initial RECOMMENDATION.
supersedes_partial: feature-flags-assessment.md §3.3 (UnderscoreOwned verdict was SKIP based on Swift 6.2.4 state; that classification is now stale — the feature has moved from Nascent to Maturing through Apr 2026 commits)
---
-->

## Context

The 2026-05-09 forums-review of `swift-either-primitives` flagged that `Either<Never, T>.value` does not compile for `T: ~Copyable`. The current `Either+Never.swift` declares `var value: Right` with an implicit borrowing-self getter; for `Right: ~Copyable`, the body `case .right(let right): right` cannot return `right` because the accessor cannot move out of the borrowed receiver.

The institute's prior `property-consuming-get-and-read` experiment (2026-05-04, Swift 6.3.1) tested four `consuming get` variants and concluded ALL were REFUTED — only the V6 stored-property pattern (`public private(set) var underlying: NC` on a `~Copyable` struct) supported consume-extract. V6 does not apply to enums because enum payloads live inside cases, not as top-level stored properties.

The institute's prior `feature-flags-assessment.md` (2026-03-03, v1.0.1 last updated 2026-04-16) classified `UnderscoreOwned` as Nascent maturity with verdict SKIP — "no production usage, existing Property.View / Property.Consuming workarounds are superior, consuming get cannot move stored properties from self — the fundamental limitation remains."

The user (correctly) pushed back: *"there should be a way to get the non-method form."*

## Question

Is there ANY non-method, non-init form for `~Copyable` consume-extract from a property in Swift 6.3.1 or Swift 6.4-dev? If yes, what's the cost? If no, confirm the gap with primary-source evidence.

## Analysis

### Verified mechanism: `@_owned` + `consuming get` + `UnderscoreOwned` experimental feature

The Swift compiler source at HEAD `e578b3a1e17` (May 2026, /Users/coen/Developer/swiftlang/swift) ships an `@_owned` attribute gated behind the experimental feature `UnderscoreOwned`. When applied to a property whose getter is `consuming get`, the receiver is consumed at the call site and the body can move out of stored fields or pattern-bind enum case payloads.

**Primary-source citations**:

- Attribute definition: `include/swift/AST/DeclAttr.def:611` — `SIMPLE_DECL_ATTR(_owned, Owned, ...)` `[Verified: 2026-05-09]`
- Feature flag: `include/swift/Basic/Features.def:611` — `EXPERIMENTAL_FEATURE(UnderscoreOwned, true)` `[Verified: 2026-05-09]`
- Feature gate enforced in Sema: commit `58c1cfeea60` "Sema: require UnderscoreOwned to use `@_owned`" (PR #88507, merged 2026-04 era) `[Verified: 2026-05-09]`
- Working test file: `test/SILGen/Inputs/resilient_consuming_getter_nonescapable.swift` lines 4-9 (struct shape), 15-19 (struct shape returning new value), `test/SILGen/resilient_consuming_getter_nonescapable_test.swift` lines 1-7 (REQUIRES swift_feature_UnderscoreOwned, REQUIRES swift_feature_Lifetimes) `[Verified: 2026-05-09]`

The canonical source pattern (from `resilient_consuming_getter_nonescapable.swift:12-20`):

```swift
public struct NC: ~Copyable {
    public init() {}

    @_owned public var value: NC {
        consuming get {
            NC()
        }
    }
}
```

### Empirical verification — minimum-shape reproductions

Three test variants exercised on Swift 6.3.1 + Swift 6.4-dev nightly 2026-03-16-a, all with `-enable-experimental-feature UnderscoreOwned`. Test files at `/tmp/either-checks/`.

| Variant | Shape | 6.3.1 | 6.4-dev 2026-03-16 | Notes |
|---|---|---|---|---|
| Struct stored field | `struct Box: ~Copyable { @_owned var value: NC { consuming get { _stored } } }` | `error: unknown attribute '_owned'` | **PASS** (prints 42) `[Verified: 2026-05-09]` | `@_owned` not recognized on 6.3.1; works on 6.4-dev for non-generic struct |
| Non-generic enum | `enum BoxOrEmpty: ~Copyable { case empty, some(NC); @_owned var unwrapped: NC { consuming get { switch consume self { ... } } } }` | `error: unknown attribute '_owned'` | **PASS** (prints 42) `[Verified: 2026-05-09]` | `consume self` + `switch` + case-bind extraction works for monomorphic enum |
| **Generic ~Copyable enum** (matches `Either`'s shape) | `enum Box<T: ~Copyable>: ~Copyable { case wrapping(T); @_owned var unwrapped: T { consuming get { switch consume self { case .wrapping(let v): v } } } }` | `error: unknown attribute '_owned'` | **FAIL** — `error: copy of noncopyable typed value. This is a compiler bug. Please file a bug with a small example of the bug` `[Verified: 2026-05-09]` | This IS our Either's shape. Triggers a move-checker bug. |

Diagnostic source: `include/swift/AST/DiagnosticsSIL.def:964` — `"copy of noncopyable typed value. This is a compiler bug..."` `[Verified: 2026-05-09]`

### Phase 2 verification on 2026-05-07 nightly — REGRESSION TO STRUCTURAL REJECTION

After the 2026-04-30 consuming-accessor PR (`645e2dc3bad`), I installed the 2026-05-07 nightly (`org.swift.64202605071a`, version `6.4.20260507101`) and re-ran the generic-enum reproduction. The "copy of noncopyable typed value" compiler-bug diagnostic IS resolved. **A different rejection fires in its place**:

```
error: noncopyable 'b' cannot be consumed when captured by an escaping closure
or borrowed by a non-Escapable type
   |     let v = b.unwrapped
   |               `- error: ...
```

The new diagnostic is structural (the move-checker now correctly identifies the shape as one it doesn't support), not a bug-style emit. Tested call-site variants on 2026-05-07:

| Call-site shape | 2026-05-07 result |
|---|---|
| `let v = b.unwrapped` (let-binding read) | FAIL — "borrowed by a non-Escapable type" `[Verified: 2026-05-09]` |
| `let v = consume b.unwrapped` (explicit consume keyword) | FAIL — "consume can only be used to partially consume storage; non-storage produced by this computed property" — V5-experiment finding restated by the new compiler `[Verified: 2026-05-09]` |
| `func extract(_ b: consuming Box<NC>) -> NC { return b.unwrapped }` (consuming-parameter wrapper) | FAIL — same "non-Escapable type" diagnostic `[Verified: 2026-05-09]` |
| Adding `@_lifetime(copy self)` to the getter | FAIL — `error: invalid lifetime dependence on an Escapable result` `[Verified: 2026-05-09]` |
| **Non-generic** `enum BoxOrEmpty: ~Copyable` (no type parameter) — same `@_owned consuming get` shape, called from inside a `func` | **PASS** — prints 42 `[Verified: 2026-05-09]` |
| Top-level (global) let-binding read on the non-generic version | FAIL — "cannot consume noncopyable stored property 'b' that is global" — orthogonal global-storage issue `[Verified: 2026-05-09]` |

**Empirical conclusion**: `@_owned consuming get` works for **non-generic** `~Copyable` types (struct or monomorphic enum) but is structurally unsupported for **generic** `~Copyable` enums. The Either type IS generic. Phase 2 is therefore blocked on an in-flight Swift compiler limitation that is NOT a bug (no "compiler bug" emission) and not addressed by the Apr 2026 fix wave; it's a coverage gap in the move-checker for generic-enum consuming getters.

### Recent compiler commits addressing related bugs

The Apr 2026 wave of consuming-accessor fixes in swiftlang/swift (HEAD `e578b3a1e17`):

| Commit | Date | Subject |
|---|---|---|
| `458b62c9ed0` | (introduce) | introduce UnderscoreOwned feature |
| `adf14929f9f` | 2026 | Merge PR #86337 (kavon/noncopyable-opaque-read-ownership) |
| `dc073c4b3ae` | 2026 | Merge PR #88507 (kavon/require-feature-underscoreowned) |
| `2637592bee3` | 2026 | [SILGen] Move self into consuming accessors when possible |
| `4640b58e990` | 2026 | [SILGen] Mark +0 base unresolved for consuming accessor |
| `645e2dc3bad` | 2026-04-30 | Merge PR #88699 (consuming-accessor-resilient-base, rdar://175724267) |

The 2026-04-30 PR #88699 merged AFTER the workspace's installed nightly was built (2026-03-16). The "copy of noncopyable typed value" diagnostic is a known move-checker emit point; the recent SILGen fixes plausibly address the generic-enum case but this requires a newer nightly to verify empirically.

`[Verified: 2026-05-09]` — git log dates retrieved from /Users/coen/Developer/swiftlang/swift; verification pending re-run on a post-2026-04-30 nightly.

### Why the institute's earlier UnderscoreOwned skip is now stale

`feature-flags-assessment.md §3.3` (2026-03-03) classified `UnderscoreOwned` as Nascent (1 lib file, 3 attribute touch points, 1 test file, not in stdlib) with verdict SKIP. Two factors have shifted since:

1. **Test footprint has grown.** The skip was based on "1 test file" — our 2026-05-09 inspection of HEAD found at least two relevant SILGen tests (`moveonly_coroutine_access.swift`, `resilient_consuming_getter_nonescapable_test.swift`) plus `Inputs/resilient_consuming_getter_nonescapable.swift`, all exercising the consuming-getter shape on `~Copyable` types.

2. **Production need has surfaced.** The `feature-flags-assessment.md` skip rationale was "no production sites need this — Property.View / Property.Consuming alternatives exist." That assessment was correct for property-bag types where a separate viewer wraps the storage. It's incorrect for **enum-payload extraction** (Either-shape) — there's no Property.View pattern that extracts a payload from a case, because the enum is the storage. The `Either<Never, T>.value` accessor is the production site that the earlier audit didn't have.

3. **Compiler maturity has moved from Nascent → Maturing.** The Apr 2026 commits (Sema enforcement, SILGen base-handling fixes, resilient-base support) indicate active investment, not feature-rot. The diagnostic-emission TODO around "compiler bug" is a known move-checker rough edge, not a fundamental design block.

The earlier verdict was correct **at the time**; this note supersedes §3.3 specifically for the enum-payload-extraction use case.

### Cost assessment if we adopt

| Concern | Assessment |
|---|---|
| Toolchain floor | Adopting `@_owned` requires Swift 6.4-dev or later. swift-either-primitives currently floors at Swift 6.3.1. Gating via `#if compiler(>=6.4)` is feasible but adds two-version source maintenance. |
| Experimental-feature dependency | `enableExperimentalFeature("UnderscoreOwned")` declared in Package.swift would extend to every consumer's build. The flag is not currently in the institute baseline (feature-flags-assessment.md §2). |
| ABI stability | `@_owned` is an underscored attribute. Renaming risk if/when SE proposal lands. The current pattern (`@_owned var x: T { consuming get { ... } }`) may translate mechanically to a stabilized form (`consuming var x: T { ... }`?) but this is speculation; no SE pitch text exists yet. |
| Compiler-bug exposure | Generic `~Copyable` enum payload extraction triggers "copy of noncopyable typed value" on the 2026-03-16 nightly. Not yet verified resolved on HEAD. |
| Cohort impact | If UnderscoreOwned is adopted in `swift-either-primitives` only, the cohort (`Pair`, `Product`) doesn't need it (their value-shapes are accessor-via-stored-field, V6-eligible). Single-package adoption is feasible. |

### Alternatives weighed

**A. Accept the gap.** Document that `Either<Never, T>.value` works for `T: Copyable` only. Consumers with `T: ~Copyable` use `Either.fold(left:right:)` (the universal coproduct map) or pattern-match `.right` directly. Zero compile-time cost; zero experimental-feature dependency.

**B. Method form `consuming func value()`.** User rejected: *"we dont want method form"*.

**C. Free function `value(of:)`.** Matches `swapped(_:)` precedent on `swift-product-primitives`. Discoverable via the import. Not on the type, so call-site ergonomics differ from `e.value`.

**D. UnderscoreOwned + `@_owned` + `consuming get`.** Works in principle (verified on non-generic enum); blocked by a compiler bug on the generic shape. Requires a newer nightly to verify resolved.

| Criterion | A. Accept gap | C. Free function | D. UnderscoreOwned |
|---|---|---|---|
| Property-form access (`e.value`) | No (gap documented) | No (`value(of: e)`) | **Yes** — once compiler bug resolved |
| Compile-time cost | None | None | Experimental-feature flag in Package.swift |
| ABI risk | None | None | Underscored-attribute future rename |
| Toolchain floor | 6.3.1 | 6.3.1 | 6.4-dev (gated `#if compiler(>=6.4)`) |
| Verified working today | Yes | Yes | No (compiler bug on generic shape) |
| Path to property-form once Swift fixes | Reopen the question | Stays as-is, property gap remains | Mechanical attribute swap when SE proposal lands |

## Outcome

**Status**: DECISION (v1.1.0 supersedes v1.0.0's RECOMMENDATION)

**Verdict on the user's hypothesis** ("*there should be a way to get the non-method form*"): **Confirmed — there IS a non-method, non-init form** (`@_owned` + `consuming get` + `UnderscoreOwned`). The institute's prior research was incomplete because it tested the syntax without the `@_owned` attribute. **However**, on the latest publicly-available nightly (2026-05-07-a), the mechanism works only for non-generic `~Copyable` types. Generic `~Copyable` enums (Either's exact shape) are structurally rejected. Phase 2 is deferred indefinitely.

**Decision for swift-either-primitives**: ship a **free-function form** `value(of:)` that admits `~Copyable` arms today. Keep the existing property-form accessor (`e.value`) for Copyable arms. Document the asymmetry. When Swift compiler progresses on generic-enum `@_owned` getters, replace the free function with the property form under `#if compiler(>=N) && hasFeature(UnderscoreOwned)`.

**Phase 1 (shipping today)**:

`Sources/Either Primitives/Either+Never.swift` carries:

- **Property form** (Copyable arms — existing): `extension Either where Left == Never { var value: Right { ... } }` and the symmetric Right-Never variant. Implicit `Copyable & Escapable` from extension defaults.
- **Free-function form** (~Copyable arms — new):

  ```swift
  @inlinable
  public func value<Right: ~Copyable>(
      of either: consuming Either<Never, Right>
  ) -> Right {
      switch consume either {
      case .right(let right): right
      }
  }

  @inlinable
  public func value<Left: ~Copyable>(
      of either: consuming Either<Left, Never>
  ) -> Left {
      switch consume either {
      case .left(let left): left
      }
  }
  ```

Call sites:

```swift
// Copyable case — property and free-function both work
let e1: Either<Never, Int> = .right(42)
let v1 = e1.value         // property form, multi-read
let v2 = value(of: e1)    // free-function form, consumes e1

// ~Copyable case — only the free-function form compiles
struct NCResource: ~Copyable { let id: Int }
let e2: Either<Never, NCResource> = .right(NCResource(id: 7))
let v3 = value(of: e2)    // moves the resource out of e2
```

Three new tests in `NeverElimination` suite:
- `value of free function on copyable right matches property` — round-trip equality between property and free-function paths
- `value of free function extracts noncopyable right`
- `value of free function extracts noncopyable left`

The `~Escapable` arm is intentionally not admitted (function would require an explicit `@_lifetime(copy either)` annotation that conflicts with consuming semantics). `~Copyable + Escapable` covers the realistic majority of use cases; `~Escapable` arms can be addressed in a follow-up if a concrete consumer surfaces.

**Phase 2 (when Swift compiler progresses)**:

The blocking diagnostic is structural ("noncopyable 'X' cannot be consumed when captured by an escaping closure or borrowed by a non-Escapable type"), not a bug. Tracking signal: when a future Swift nightly compiles the empirical reproduction in this note's §"Empirical reproductions" without the diagnostic, Phase 2 unblocks.

When that lands:

1. Add `enableExperimentalFeature("UnderscoreOwned")` to swift-either-primitives `Package.swift`'s `swiftSettings`.
2. Add a `#if compiler(>=N) && hasFeature(UnderscoreOwned)` block to `Either+Never.swift` declaring the property form for `~Copyable` arms:
   ```swift
   #if compiler(>=N) && hasFeature(UnderscoreOwned)
   extension Either where Left == Never, Right: ~Copyable {
       @_owned public var value: Right {
           consuming get {
               switch consume self {
               case .right(let right): right
               }
           }
       }
   }
   #endif
   ```
3. The free function `value(of:)` REMAINS — older toolchain consumers continue to use it. Both call paths work on newer toolchains; consumers may pick either.
4. Triple-toolchain verification: floor toolchain (free function only), newer-than-N toolchain (property + free function), Embedded (verify gate).

**Phase 3 (when SE proposal lands)**: Mechanical replacement of `@_owned var x: T { consuming get { ... } }` with the stabilized form (likely `consuming var x: T { ... }` without an attribute, or whatever shape Swift Evolution accepts).

### Cohort implications

This research is scoped to swift-either-primitives because:

- `swift-pair-primitives` and `swift-product-primitives` do not have an enum-payload-extraction site. Their stored-property patterns are V6-eligible (or already work).
- `swift-tagged-primitives` has the same stored-property structure as Tagged.swift's V6 fix — already addressed.

If a future package vends an enum with a `Never`-eliminated accessor (or any analogous shape), this research applies directly: gate behind `UnderscoreOwned` + `#if compiler(>=6.4)`, and document the fallback for `<6.4` toolchains.

## References

- swiftlang/swift HEAD `e578b3a1e17` (May 2026):
  - `include/swift/AST/DeclAttr.def:611` — `@_owned` attribute definition
  - `include/swift/Basic/Features.def:611` — `UnderscoreOwned` experimental feature
  - `include/swift/AST/DiagnosticsSIL.def:964` — "copy of noncopyable typed value" diagnostic
  - `test/SILGen/Inputs/resilient_consuming_getter_nonescapable.swift` — primary working pattern for `@_owned` + `consuming get`
  - `test/SILGen/resilient_consuming_getter_nonescapable_test.swift` — REQUIRES line confirming `swift_feature_UnderscoreOwned`
  - Commits `458b62c9ed0` / `adf14929f9f` / `dc073c4b3ae` / `2637592bee3` / `4640b58e990` / `645e2dc3bad` — Apr 2026 wave of consuming-accessor fixes
- Institute prior research:
  - `feature-flags-assessment.md` v1.0.1 — §3.3 UnderscoreOwned verdict (SKIP, now superseded for the enum-payload-extraction use case)
  - `feature-flags-coroutine-borrow-accessors.md` v1.0.0 (SUPERSEDED) — §3 UnderscoreOwned earlier framing
  - `noncopyable-ecosystem-state.md` — broader ~Copyable ergonomics state (unaffected by this finding)
- Institute prior experiment:
  - `swift-institute/Experiments/property-consuming-get-and-read/` — V1-V5 REFUTED, V6 CONFIRMED for stored-property struct extraction. This research extends the experiment by demonstrating that V3-shape (`consuming get` alone) DOES work when paired with `@_owned` + `UnderscoreOwned` for non-generic shapes.
- Empirical reproductions: `/tmp/either-checks/` (struct, non-generic enum, generic-enum tests)
