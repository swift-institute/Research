# Stdlib Collection Map Actor-Isolation Overhead

<!--
---
version: 1.0.0
last_updated: 2026-05-07
status: DECISION
tier: 2
scope: ecosystem-wide
---
-->

## Context

`result-builder-performance-optimization.md` v2.1.0 [Residual section] filed an unresolved finding: stdlib `Collection.map` measured ~19× slower than an equivalent same-module `@inlinable` map at N=100 (4083 ns/iter vs 211 ns/iter), in or out of a result-builder body. The v2.1.0 framing labelled this "stdlib's specialization gap — `Collection.map` does not specialize the closure at the consumer call site despite `@inlinable` markers," and routed the open question to a separate investigation.

This document is that investigation. It refutes the specialization-gap framing on primary-source evidence and re-characterizes the cost as a runtime actor-isolation check mandated by SE-0423, conditioned on the standard library's `.swiftinterface` being built in Swift 5 mode.

## Question

Why does stdlib `Collection.map` (and `Sequence.map`, `LazyMapSequence` materialized to `Array`) measure ~19× slower than an equivalent same-module `@inlinable` map when both are `@inlinable`, both have closure literals available at the call site, and both run under release-mode whole-module optimization with cross-module optimization enabled? Specifically: is the cause (a) cross-module generic-specialization failure, (b) `rethrows` / typed-throws machinery, (c) library-evolution / `@_alwaysEmitIntoClient` interaction, (d) runtime actor-isolation enforcement, or (e) something else? And what should the institute do about it?

## Internal Prior Art

Per [RES-019], internal research grep before external survey:

| Doc | Relevance | Verdict |
|-----|-----------|---------|
| `lazy-pipeline-release-mode/` (Experiment, 2026-02-25) | Same shape: institute-defined `@inlinable` lazy `Mapped`/`Filtered` types match hand-rolled within 2% in -O at N=10M; stdlib `.map`/`.filter` materialised to intermediate arrays is 7× slower at N=10M. | Closest neighbour. Localised the slowdown to "intermediate arrays" — a partial-truth that this doc supersedes. |
| `sequence-operator-unification.md` | Cites the same lazy-pipeline data. | Carries same partial-truth framing. |
| `result-builder-performance-optimization.md` v2.1.0 | Parent doc. Residual section frames this as "stdlib specialization gap." | This doc supersedes the Residual diagnosis. |
| `benchmark-inline-strategy.md`, `spi-inlinable-incompatibility-survey.md` | About `@inlinable` semantics generally. | No bearing on stdlib `.map` performance. |

No prior institute research on stdlib higher-order-function actor-isolation costs. This doc is first-of-its-kind in the corpus.

## Analysis

### Empirical Triangulation

Three configurations of the same call-site shape, isolated to the smallest reproduction.

#### Config A — Existing experiment (SwiftPM target, swift-tools-version 6.3, Swift 6 language mode, `-O`, WMO, default cross-module optimization)

Source: `Experiments/result-builder-map-investigation/`. Re-run on Swift 6.3.1 / arm64-apple-macosx26.0 [Verified: 2026-05-07, this session]:

| Variant | Shape | ns/iter |
|---------|-------|--------:|
| V8 | `(0..<N).map { $0 * 2 }` standalone | **4167** |
| V14 | `(0..<N).sameModuleMap { $0 * 2 }` (`@inlinable` on `Collection`) | **200** |
| V8 / V14 | | 20.8× |

#### Config B — Single-file `swiftc -O` (no SwiftPM, no Swift 6 strict-concurrency main wrapping)

Source: `/tmp/map-sil-spike/bench.swift` [Verified: 2026-05-07, this session]:

| Variant | ns/iter |
|---------|--------:|
| stdlib `.map` (V8 shape) | **241.86** |
| `sameModuleMap` (V14 shape) | **224.74** |
| ratio | 1.07× |

The gap **does not reproduce** in single-file `swiftc -O`. Cause is therefore not intrinsic to stdlib `Collection.map`.

#### Config C — SwiftPM target, same source as Config B, with the call-site routed through a `nonisolated` function

Source: `/tmp/map-spm-spike/Sources/MapSpike/main.swift` [Verified: 2026-05-07, this session]:

| Variant | ns/iter | Notes |
|---------|--------:|-------|
| V8 stdlib `.map`, `@MainActor` top-level closure | **4318** | Reproduces the gap |
| V14 sameModuleMap, `@MainActor` top-level closure | **197** | No gap |
| V8n stdlib `.map`, closure inside `nonisolated func` | **202** | Gap vanishes |
| V14n sameModuleMap, closure inside `nonisolated func` | **202** | Reference |
| V8 / V8n | 23.4× | The cost is paid only when the closure is `@MainActor`-isolated |
| V14 / V14n | 0.98× | Same-module path is unaffected by isolation |
| (V8 − V8n) / N | **44.7 ns/element** | Per-call overhead at the closure-invocation site |

Wrapping the call site in a `nonisolated` function eliminates the gap entirely for the stdlib path; the same-module path is unaffected. The cost is a per-element overhead at the closure invocation.

### SIL Inspection

Release-mode SIL emitted by SwiftPM for the closure body of V8 [Verified: 2026-05-07, `/tmp/map-spm-spike/main.sil`, scope 343, lines 1176–1212]:

```sil
%62 = metatype $@thick MainActor.Type
%63 = function_ref @$sScM6sharedScMvgZ : ... // MainActor.shared.getter
%67 = function_ref @swift_task_isCurrentExecutor : (Builtin.Executor) -> Bool
%74 = apply %63(%62)
%75 = extract_executor %74
%76 = apply %67(%75)                          // ← runtime executor check
%77 = struct_extract %76, #Bool._value
cond_br %77, bb10, bb11

bb11:
  %81 = function_ref @swift_task_reportUnexpectedExecutor
  %82 = apply %81(%64, %65, %8, %66, %75)     // ← failure path

bb12:
  %85 = builtin "smul_with_overflow_Int64"(%71, %68, %8)  // ← `$0 * 2`
  cond_fail %86, "arithmetic overflow"
  ...
```

The SIL of the V8 closure body is **fully specialized** — `smul_with_overflow_Int64` is the inlined `$0 * 2`, the `Range<Int>` iteration is inlined, the `ContiguousArray<Int>` operations are inlined. Generic specialization is not failing. What the SIL adds, on every iteration, is a sequence: load `MainActor.shared` → `extract_executor` → `swift_task_isCurrentExecutor` → conditional `swift_task_reportUnexpectedExecutor`.

The same SIL inspection of V14's closure body [Verified: 2026-05-07, same file, scope 414] contains the `smul_with_overflow_Int64` and no executor check.

A `grep -c "apply.*swift_task_isCurrentExecutor"` of the V14 closure body returns 0; of the V8 closure body, 1.

### Primary-Source Verification

#### SE-0423 *Dynamic actor isolation enforcement from non-strict-concurrency contexts* (Implemented Swift 6.0)

Per [the proposal text](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0423-dynamic-actor-isolation.md) [Verified: 2026-05-07]:

> When API comes from a module that doesn't have strict concurrency checking enabled it's possible that it could introduce actor isolation violations that would not be surfaced to a client. In such cases actor isolation erasure should be handled defensively by introducing a runtime check at each position for granular protection.

The proposal's transformation: an isolated synchronous function value passed to such an API is rewritten, conceptually, as `MainActor.assumeIsolated { … }`-wrapped at every invocation.

Elision rule per the proposal's source-compatibility section: dynamic checks "only" performed for synchronous functions that are witnesses to explicitly annotated `@preconcurrency` protocol conformances, OR code compiled under the Swift 6 language mode.

#### PR #82795 *Avoid dynamic executor checks when calling synchronous non-escaping closures* (closed without merge, 2025-07-24)

Per harlanhaskins's closing comment on [the PR](https://github.com/swiftlang/swift/pull/82795) [Verified: 2026-05-07]:

> Hm, I'm looking now and in the `.swiftinterface` for Swift it's still built with `-swift-version 5`, which seems unexpected but probably intentional? That's the real reason cause of this bug; the stdlib comes in with `isConcurrencyChecked` false.

The PR was closed because the executor-check insertion is *correct* under SE-0423's normative rules, given that stdlib's binary `.swiftinterface` advertises `-swift-version 5`. The bug is in the stdlib's build configuration (or in deciding whether stdlib should be a special case), not in the optimizer's elision logic.

#### Stdlib `Collection.map` declaration

[`stdlib/public/core/Collection.swift:1191–1214`](https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Collection.swift) [Verified: 2026-05-07, local clone at `/Users/coen/Developer/swiftlang/swift/`]:

```swift
@inlinable
@_alwaysEmitIntoClient
public func map<T, E>(
  _ transform: (Element) throws(E) -> T
) throws(E) -> [T] {
  let n = self.count
  if n == 0 { return [] }
  var result = ContiguousArray<T>()
  result.reserveCapacity(n)
  var i = self.startIndex
  for _ in 0..<n {
    result.append(try transform(self[i]))
    formIndex(after: &i)
  }
  _expectEnd(of: self, is: i)
  return Array(result)
}
```

`@_alwaysEmitIntoClient` ensures the body is emitted into the client's compilation unit (per `lib/SIL/IR/SILFunction.cpp:519` `isAlwaysEmitIntoClient() ⇔ codeGenerationModel() == Implementation`). The body's content is irrelevant to the diagnosis; what matters is the `.swiftinterface` from which the function is *imported* — that file determines `isConcurrencyChecked()`.

### Mechanism Synthesis

The four findings compose into a single causal chain:

1. SwiftPM's release build of an `executableTarget` with `swift-tools-version: 6.3` compiles the target in Swift 6 language mode. Top-level code in `main.swift` is implicitly `@MainActor`-isolated.
2. A closure literal `{ $0 * 2 }` written at top level inherits `@MainActor` isolation as a non-escaping isolated synchronous function value.
3. The closure is passed to `Collection.map`. The compiler resolves `Collection.map` against stdlib's binary `.swiftinterface`. Stdlib's `.swiftinterface` is built with `-swift-version 5`; the import is treated as a non-strict-concurrency module.
4. SE-0423 mandates: when an isolated synchronous function value is passed to a non-strict-concurrency module's API, the compiler "introduces a runtime check at each position." For a higher-order function called per element, "each position" is each element.

The same-module map (V14) is in a target compiled in Swift 6 mode; both call site and callee are concurrency-checked; the elision rule fires; no check is emitted.

The single-file `swiftc -O` reproduction (Config B) does not run as Swift 6 strict-concurrency main-actor-isolated top-level code (no SwiftPM `-entry-point-function-name`, no implicit `@MainActor` on top-level let-bindings); the closure is not isolated; SE-0423's transformation does not fire; there is no gap.

The `nonisolated` wrapper (Config C, V8n) lifts the closure out of the `@MainActor` top-level scope into a function body whose closure inherits the function's nonisolated context; the closure is no longer isolated; SE-0423's transformation does not fire; the gap vanishes.

### Refutation of v2.1.0 Framing

The v2.1.0 Residual section read: "stdlib's `Collection.map` does not specialize the closure at the consumer call site despite `@inlinable` markers on both `map` and the closure literal." This is **not correct**.

| Claim from v2.1.0 | Status |
|-------------------|--------|
| `Collection.map`'s body is not emitted at the client | False. `@_alwaysEmitIntoClient` emits it; SIL confirms full inlining. |
| The closure literal is not specialized | False. SIL shows `smul_with_overflow_Int64` inlined into the loop body for both V8 and V14. |
| ~40 ns/element of indirect-call overhead | The 40 ns figure is correct, but is the cost of the per-element executor check, not indirect call. |
| Builder is irrelevant; cost is intrinsic to stdlib `.map` | First half correct, second half false. The cost is intrinsic to the `@MainActor` ↔ Swift-5-`.swiftinterface` boundary. |

The empirical predictions of the v2.1.0 framing happen to be approximately right because the *magnitude* of the actor-isolation runtime check (~40 ns/element) coincides with the *magnitude* one would expect from an indirect-call hypothesis. The mechanism is different.

## Outcome

**Status**: DECISION

### Diagnosis

Per-element ~40 ns overhead in stdlib `Collection.map`, `Sequence.map`, and `LazyMapSequence` materialised to an `Array`, when called from a `@MainActor`-isolated context in a Swift 6-mode SwiftPM target, is the dynamic actor-isolation runtime check (`swift_task_isCurrentExecutor` + `swift_task_reportUnexpectedExecutor`) mandated by SE-0423. The mechanism is correct under the proposal's normative rules. The trigger is stdlib's `.swiftinterface` being built with `-swift-version 5`, which causes `isConcurrencyChecked()` to return false at the import boundary.

The institute's same-module `@inlinable` higher-order functions (e.g., `sameModuleMap`, the institute's lazy `Mapped`/`Filtered` types in `lazy-pipeline-release-mode`) do not exhibit this overhead because they are compiled in Swift 6 mode in the same target as the call site; SE-0423's elision rule fires.

### Recommendation: (C) Accept and document

The institute should NOT report upstream, NOT ship `Collection.fastMap` workaround helpers, and SHOULD update its performance and concurrency documentation to call out the gotcha and the structural workaround.

#### Why not (A) report upstream

The cause is known; the upstream tracking artifact is PR #82795 (closed because the underlying issue was identified, not because it was rejected); the resolution path is a stdlib build-configuration change. There is nothing useful to add — a Forums post by the institute would re-litigate harlanhaskins's already-correct diagnosis. If the institute wants to advance the upstream resolution it should write to the `swift-stdlib` Forums category requesting that stdlib's `.swiftinterface` be migrated to `-swift-version 6` (or that stdlib be special-cased in `closuresRequireDynamicIsolationChecking`), but this is a contribution to the resolution, not a new report.

#### Why not (B) ship workaround helpers

`Collection.fastMap` would be a synonym for `Collection.map` that happens to live in an institute module compiled in Swift 6 mode. It would carry `@inlinable` and a body identical to stdlib's. Consumers who route hot loops through it would benefit *until* stdlib's `.swiftinterface` is migrated, after which the workaround becomes a permanent ergonomic tax (a parallel API that exists only to exhibit the eliding behaviour stdlib will then also exhibit). The fix is structural — the call site, not a new API.

The same critique applies more strongly to `Sequence.fastFilter`, `Sequence.fastReduce`, etc.: shipping a parallel HOF surface is a substantial commitment that resolves a transition-period gap. After the transition, the institute would carry a deprecation cost.

#### Why (C) is right

The cost manifests only at:
1. `@MainActor`-isolated call sites (top-level `main.swift` in Swift 6 mode, view bodies, view models).
2. Calling stdlib HOFs (`map`, `filter`, `reduce`, `flatMap`, `lazy.map.../Array(_:)`, etc.) — institute HOFs are unaffected.
3. With small `N` (the per-element overhead amortises down at large N as the per-element work grows).

The structural workaround is a single-line refactor: hoist the loop body into a `nonisolated` function or method. This is the same shape as the institute's existing convention for separating UI-isolated dispatch from work bodies. Documenting this gotcha in the performance / concurrency skill body, and back-referencing it from `result-builder-performance-optimization.md`, suffices.

### Documentation Updates

| Target | Status | Change |
|--------|--------|--------|
| `result-builder-performance-optimization.md` v2.1.0 → v2.2.0 | Applied 2026-05-07 | Residual section's Root cause + Implications updated to the SE-0423 framing; cross-link this doc; update _index.json's `statusDetail`. |
| `swift-institute/Research/_index.json` | Applied 2026-05-07 | This doc's entry added; parent doc's `statusDetail` refined. |
| `Blog/Draft/result-builder-for-loop-performance.md` | Patched 2026-05-07; revision pending | "A note on `.map` and `.flatMap`" section's factual claims and the recommendations table updated to the SE-0423 framing. Frontmatter `revision_pending` block lists what the future full-prose revision needs to address before publish. |
| `benchmark` skill (or wherever applicable) | Not yet applied | Optionally codify the rule "hot HOF loops over stdlib types should be called from a `nonisolated` context when the surrounding module is `@MainActor`-isolated." Decide outside this doc; not in scope. |

### What Would Resolve This Upstream

Two paths, either sufficient:

1. Stdlib's `.swiftinterface` is rebuilt with `-swift-version 6`. Then the import is `isConcurrencyChecked() == true`, SE-0423's elision rule fires for *all* stdlib HOF call sites, and the gap goes away ecosystem-wide without any client change.
2. The compiler special-cases stdlib in `closuresRequireDynamicIsolationChecking` (the path xedin suggested in PR #82795 before harlanhaskins identified the underlying configuration issue). This is the narrower fix; it leaves other Swift 5 system frameworks unhelped.

Either way: no institute-side action is required to consume the fix when it lands. The institute's existing call sites become correct-and-fast automatically.

## Workaround pattern (appendix)

For consumers who measure the gap and need to mitigate it before the upstream resolution lands, the structural workaround is:

```swift
// Before — inside @MainActor context (top-level main.swift, view body, view model):
let doubled = (0..<n).map { $0 * 2 }   // ~40 ns/element executor check overhead

// After — same shape, nonisolated boundary:
@inline(__always) nonisolated
func doubleAll(_ n: Int) -> [Int] { (0..<n).map { $0 * 2 } }

let doubled = doubleAll(n)             // No overhead
```

The `@inline(__always)` is optional; the load-bearing token is `nonisolated`, which causes the closure literal to inherit the function's nonisolated context, which lets SE-0423's elision rule fire on the call.

For `for`-style consumption that doesn't need the resulting `[Int]`, an imperative loop is unaffected by the issue (there is no closure crossing a module boundary). Imperative loops remain a valid and often-better answer when the only consumer is an immediate enumeration.

## References

Primary sources, all verified against their canonical location during this session:

- [SE-0423 *Dynamic actor isolation enforcement from non-strict-concurrency contexts*](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0423-dynamic-actor-isolation.md) — Status: Implemented (Swift 6.0). Normative source for the runtime-check insertion rule.
- [PR #82795 *Avoid dynamic executor checks when calling synchronous non-escaping closures*](https://github.com/swiftlang/swift/pull/82795) — Closed without merge 2025-07-24. harlanhaskins's identification of the stdlib `.swiftinterface` Swift 5 mode as root cause.
- [`stdlib/public/core/Collection.swift:1191–1214`](https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Collection.swift) — `Collection.map` declaration and attributes.
- [`stdlib/public/core/Sequence.swift:686–706`](https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Sequence.swift) — `Sequence.map` declaration; identical pattern.
- `Experiments/result-builder-map-investigation/` — The 16-variant empirical baseline (V1–V16). Re-run 2026-05-07 reproduces the gap.
- `Research/result-builder-performance-optimization.md` — Parent doc; v2.1.0 carried the original "specialization gap" framing in its Residual section, v2.2.0 is the back-reference home for the corrected framing this doc establishes.
- `Research/sequence-operator-unification.md` — Cites the same lazy-pipeline data; carries the partial-truth framing.
- `Experiments/lazy-pipeline-release-mode/` — Independent confirmation that institute-defined `@inlinable` HOFs do not exhibit the gap.
- `lib/SIL/IR/SILFunction.cpp:519–525` (in local Swift compiler clone) — `isAlwaysEmitIntoClient` semantics.
