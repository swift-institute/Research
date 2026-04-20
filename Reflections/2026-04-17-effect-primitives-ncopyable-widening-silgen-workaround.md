---
date: 2026-04-17
session_objective: Modernize swift-effect-primitives to admit ~Copyable & Sendable associated types per §10.1 of the effect-primitives-and-io-algebra-relation research, and report cascade impact to the parallel L3 swift-effects handoff.
packages:
  - swift-effect-primitives
  - swift-equation-primitives
  - swift-hash-primitives
status: processed
processed_date: 2026-04-20
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Extended [IMPL-092] with two-callback storage fallback for toolchain-blocked composition; heuristic for recognizing the failure mode
  - type: experiment_topic
    target: swift-effect-primitives
    description: Re-run noncopyable-optional-capture-crash on 6.4-dev nightly (deferred to future session)
  - type: research_topic
    target: ecosystem
    description: Survey of ≥3-primitive SILGen-bug-prone compositions — stub landed at Research/silgen-bug-prone-primitive-compositions.md (Tier 2, IN_PROGRESS)
---

# Effect-Primitives `~Copyable` Widening — Two-Callback Workaround for a Swift 6.3.1 SILGen Bug

## What Happened

Dispatched from `swift-primitives/HANDOFF-effect-primitives-ncopyable-modernization.md` with `/implementation /code-surface /platform /modularization` skills loaded. The handoff prescribed widening `__EffectProtocol.Arguments` and `__EffectProtocol.Value` to `~Copyable & Sendable`, suppressing `Copyable` on `__EffectHandler`, evaluating whether `@Sendable` on `Effect.Continuation.One._resume` is load-bearing, and cascading conditional conformances through `Effect.Outcome` per the `Pair<First: ~Copyable, Second: ~Copyable>` reference pattern.

Landed (all 38 package tests pass, `Effect Primitives` target green):

- `__EffectProtocol: ~Copyable, Sendable`; `Arguments: ~Copyable & Sendable = Void`; `Value: ~Copyable & Sendable`; `var arguments: Arguments { borrowing get }` (`Effect.Protocol.swift`).
- `__EffectHandler: ~Copyable, Sendable`; `Handled: ~Copyable & __EffectProtocol`; `handle(_ effect: borrowing Handled, continuation: consuming ...)` (`Effect.Handler.swift`).
- `__EffectContinuation: ~Copyable, Sendable` with widened `Value: ~Copyable & Sendable`; `resume(with:)` dropped from the protocol requirement and re-added as a `Value: Copyable` extension (`Effect.Continuation.swift`).
- `Effect.Continuation.One` storage reshaped — see §"What Didn't Work" for why it isn't the thunk form prescribed by [IMPL-092].
- `Effect.Outcome<Value: ~Copyable, Failure>: ~Copyable` with conditional stdlib `Copyable`, `Sendable`, `Equatable`, `Hashable` extensions AND net-new `Equation.Protocol` / `Hash.Protocol` conformances for the `~Copyable` Value path.
- `Package.swift` gained deps on `swift-equation-primitives` and `swift-hash-primitives`; dependency graph verified acyclic via `swift package show-dependencies`.

Downstream L1 consumers rebuilt clean: `swift-pool-primitives`, `swift-cache-primitives`, `swift-parser-primitives`. L3 `swift-foundations/swift-effects` broke as expected — documented the cascade inventory (stdlib `CheckedContinuation` requires Copyable; `Dependency.Values` subscript requires Copyable; `Result<E.Value, Never>` needs ownership; `any __EffectProtocol` existential can't be formed over a `~Copyable` protocol) and passed it through to the parallel L3 handoff in the Findings section so the L3 agent does not have to rediscover it.

Produced: one research-doc "Findings (Modernization)" section appended to `/Users/coen/Developer/swift-primitives/Research/effect-primitives-and-io-algebra-relation.md`; one package-level reproducer experiment at `swift-effect-primitives/Experiments/noncopyable-optional-capture-crash/` with README and revisit instructions; revisit-trigger doc comment on `Effect.Continuation.One` pointing at the experiment.

The session asked for supervision at the two-callback inflection point. Supervisor response: accept, but require a bug reproducer, code-level revisit triggers, and an explicit §"open" flag on the `Equation.Protocol` / `Hash.Protocol` addition (net-new capability, not literally in the handoff's scope). All three were executed before closing out.

## What Worked and What Didn't

### Worked

1. **Reading before writing.** Before any edit, read the handoff, §4 and §10.1 of the research doc, all six L1 source files, the existing test suite, and three downstream consumers (`swift-pool-primitives`, `swift-cache-primitives`, `swift-parser-primitives`, plus L3 `swift-effects`). Twenty minutes of reading prevented multiple speculative rewrites.
2. **Backward-compat overloads via `@_disfavoredOverload`.** The pre-modernization `Effect.Continuation.one { (result: Result<V, F>) in ... }` factory kept working unchanged. The new `one(onValue:onError:)` factory for `~Copyable` Value carries `@_disfavoredOverload` so the call-site ambiguity the old tests hit on Void-typed closures resolves cleanly.
3. **Mid-session user redirect accepted on the spot.** When the user said "also see equation-primitives, hash-primitives for replacements for `~Copyable`," treating it as a binding direction and reshaping `Outcome`'s conditional conformances produced a better design than the `#if compiler(>=6.4)` Pair trick would have. Trade-off: two new package deps (flagged for the reviewer per supervisor guidance; default recommendation = keep).
4. **Supervision invocation at the right inflection point.** The two-callback decision is exactly the kind of question worth asking — a principled rule ([IMPL-092]) was pointing one way, and a workaround was pointing another. Asking rather than deciding preserved reversibility: the reproducer + revisit trigger lands today; the thunk form can be restored on a 6.4-dev nightly with zero archaeology.

### Didn't Work

1. **Initial thunk-form attempt burned three build/test cycles.** The canonical pattern for moving `~Copyable` across a closure boundary — `var slot: Value? = consume value` + `slot.take()!` — is used cleanly at `Kernel.Event.Driver.swift:117`. Replicating it inside an `@Sendable` async closure passing a `sending () throws(Failure) -> sending Value` thunk compiled but produced `freed pointer was not the last allocation` (SIGABRT) on the first suspension. Took three iterations (dropping `@Sendable`, then attempting different capture forms) before recognizing this was a compiler bug, not a code-shape problem.
2. **Pattern-match ergonomics on `~Copyable` enums.** Writing `==` on `~Copyable Effect.Outcome` hit two distinct Swift 6.3 restrictions in sequence: `switch (lhs, rhs)` where the tuple contains `~Copyable` elements is "not supported"; `case .threw, .aborted:` with multi-pattern case labels on `~Copyable` enums is "not implemented." The nested-switch-with-separate-cases form works but is three times the line count of the intended implementation. No blocker, but a noticeable ergonomic tax per Equation.Protocol conformance site.
3. **Late realization that `Equation.Protocol`/`Hash.Protocol` were scope expansion.** The user's mid-session direction landed as "use these primitives," but it took the supervisor's checkpoint to recognize the addition was net-new capability (the pre-modernization `Outcome` had no `~Copyable`-compatible equality/hashing at all) rather than a lateral port. Flagging this as OPEN in the Findings is the right resolution, but the framing as "scope expansion, flag for reviewer" should have happened when the change was made, not at the post-implementation supervisor checkpoint.

## Patterns and Root Causes

### Pattern 1 — Compositional ownership failures are compiler bugs, not code smells

When `~Copyable` + `sending` + `@Sendable` capture compose at a single closure boundary, Swift 6.3.1 produces either a SILGen crash (compile-time, SIGSEGV in `emitApplyWithRethrow` → `buildThunkBody` → `createThunk`) or bogus SIL that later detonates at runtime as a task-allocator violation. The in-package and isolated-reproducer variants exhibit different symptoms of the same class of bug — one compiles and crashes at runtime, one crashes during SILGen outright. The invariant: **if three or more ownership/concurrency primitives layer at one syntactic site, expect a compiler bug before assuming your code shape is wrong.**

This is a testable heuristic. The `Kernel.Event.Driver` site uses `var slot + take!` *synchronously, inside the same scope.* The effect-primitives site adds two more primitives on top (`sending` thunk + `@Sendable` outer async). The failing configuration is the composition, not any single part.

Consequence for the [IMPL-092] canonical rule: the thunk form **is** the right interface, but current Swift toolchains cannot always emit it. The fallback needs to be explicit in the skill — two-callback storage is denotationally equivalent (tagged union delivered via two channels) and avoids the failing configuration entirely. This should not read as "[IMPL-092] was wrong"; it should read as "[IMPL-092] has a documented fallback for toolchain-blocked cases." Mirrors `copypropagation-nonescapable-fix.md`'s precedent — Property.View omits `~Escapable` to avoid a CopyPropagation bug, and the omission is tracked with a revisit trigger, not treated as architectural surrender.

### Pattern 2 — Workarounds that preserve semantics are fine; capture the path back

The two-callback storage carries zero denotational loss — `_onValue` + `_onError` *is* a tagged union. What it loses is the single-point-of-delivery intuition that makes `Result` / thunk forms read more like "here is one outcome." Replacing the interface would be scope-expansion and the semantic loss would be real (users would lose typed-throws composition at the call site). Replacing the *internal storage* while keeping the public API (including the `Result`-based factory for `Value: Copyable`) preserves everything at the boundary.

The generalization: when a compiler bug blocks the ideal internal shape, find the smallest structural change that preserves the *public* interface and semantics, land it behind a revisit trigger, and capture the path back (reproducer experiment, doc-comment pointer, Findings §). The cost of documenting the revisit is roughly 15 minutes; the cost of rediscovering the path back from cold context in six months is multiple hours. This is directly applying the cleanup-session-context-now principle from `[REFL-008]` to *deferrals*, not just artifacts: the session that discovered the workaround is the cheapest evaluator of how to undo it.

### Pattern 3 — Mid-session user direction IS scope guidance, but only the supervisor sees the scope frame

The user's "also see equation-primitives, hash-primitives for replacements for `~Copyable`" was both technically right (these are the ecosystem-native primitives) and scope-expanding (the pre-modernization `Outcome` did not have `~Copyable` Equatable/Hashable). Inside the session the direction reads as endorsement; from the supervisor's frame it reads as a design decision worth a second opinion.

What this means operationally: when a mid-session user message introduces ecosystem primitives that were not in the original handoff, the session should note explicitly whether the addition is a lateral port (preserves existing capability) or net-new capability. That framing decision is part of what the supervisor needs. I got it right on the second pass (the Findings §14.4 flags OPEN correctly) but should have done it proactively when writing the Outcome extensions.

## Action Items

- [ ] **[experiment]** `swift-effect-primitives/Experiments/noncopyable-optional-capture-crash/`: Re-run on a Swift 6.4-dev nightly toolchain; if the SILGen crash is fixed, retire the two-callback workaround in `Effect.Continuation.One` in favour of the thunk form and drop `@Sendable` on the storage (§14.2 and §14.3 of the research doc). If still broken on 6.4-dev, file upstream at swiftlang/swift citing the reabstraction-thunk frame.
- [ ] **[skill]** implementation: Extend [IMPL-092] (or add an adjacent rule) to document the "two-callback storage" fallback for cases where the canonical `() throws(E) -> sending Value` thunk form is blocked by compiler bugs involving composed `~Copyable` + `sending` + `@Sendable` capture — both forms are denotationally equivalent (tagged union of value / error); the thunk form is preferred when it compiles and the runtime is stable. Precedent: `copypropagation-nonescapable-fix.md` (Property.View omits `~Escapable` with revisit trigger).
- [ ] **[research]** Survey other ecosystem sites where three-or-more-primitive compositions (e.g., `~Copyable` + `sending` + `@Sendable` capture + typed-throws boundaries + `consuming` parameters) could trip the same class of SILGen bug. The effect-primitives case surfaced by accident; a deliberate sweep of L1 primitives against a bug-prone-composition checklist may catch latent hazards before they fire in consumer code.
