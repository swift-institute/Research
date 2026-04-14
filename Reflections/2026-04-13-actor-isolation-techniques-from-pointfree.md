---
date: 2026-04-13
session_objective: Study Point-Free #362 "Isolation: Actor Enqueuing" and apply techniques to ecosystem
packages:
  - swift-standard-library-extensions
  - swift-async
  - swift-io
status: processed
---

# Actor Isolation Techniques: From Video Study to Ecosystem Application

## What Happened

Studied Point-Free #362 on actor enqueuing. Identified three mechanisms for actor transactional access, implemented them, and applied across the ecosystem.

**Built:** 4 `Actor.run` overloads in swift-standard-library-extensions (sync/async × Copyable/~Copyable). The sync/async disambiguation is by closure async-ness (presence of `await`). The Copyable/~Copyable disambiguation is by the compiler's generic resolution. Return type uses `sending R` rather than Apple's `R: Sendable` — strictly more flexible, proven via cross-module testing.

**Applied to swift-async:** 6 stream operator feeder tasks (Merge, CombineLatest, Replay, FlatMapLatest, Sample, LatestFrom). Each task's for-await + completion pattern wrapped in `state.run { }` — per-element `send`/`update` calls become synchronous within the actor's isolation domain. N+1 enqueued jobs → 1.

**Applied to swift-io:** `IO.Event.Selector.register` refactored from 2 actor hops to 1 via `isolated Runtime` parameter on a private helper. The `borrowing Kernel.Descriptor` (~Copyable) survives because there's no closure — the borrow lives in the function scope.

**Experiments:** 5 experiments in swift-institute:
- `shared-executor-actor-communication` — 7 variants, proved 1 job for 4 cross-actor operations on shared executor
- `actor-run-noncopyable-return` — 11 variants, all ~Copyable combinations work
- `actor-run-sending-closure` — REFUTED: `sending` on closure parameter doesn't replace `@Sendable`
- `actor-run-closure-alternatives` — REFUTED all reformulations (free functions, nonisolated), then CONFIRMED `assumeIsolated` + `isolated` parameter as the complete model

## What Worked and What Didn't

**Worked well:** The incremental experiment-driven approach. Each hypothesis was tested empirically before committing to a design. The `sending R` vs `R: Sendable` investigation saved us from copying Apple's less-capable signature. The `isolated` parameter discovery came from challenging the assumption that `@Sendable` was unavoidable — the user's question "why does run require @Sendable" forced deeper investigation that led to the theoretical perfect.

**Worked well:** The shared-executor experiment produced concrete numbers (1 job vs 4-5) that made the pattern tangible rather than theoretical.

**Didn't work:** Initial attempt to apply `Actor.run` to IO.Event.Selector.register was blocked by `borrowing ~Copyable` + `@Sendable` incompatibility. Three experiments explored dead ends (`sending` closure, free functions, nonisolated methods) before finding the `isolated` parameter solution. The exploration was necessary but expensive — 3 REFUTED experiments before 1 CONFIRMED.

**Didn't work:** Proposed `registerAndPublish` combined actor method — correctly rejected by user as a workaround rather than the right tool. The `isolated` parameter was the right answer, found later.

## Patterns and Root Causes

**The closure tax on actor boundaries.** Every closure-based mechanism for crossing actor isolation inherits two constraints: `@Sendable` (captures must be Sendable) and escaping (closures outlive the function scope). These are properties of the isolation model, not implementation choices — proven by testing every alternative formulation against the compiler source (`TypeCheckConcurrency.cpp:2808`). The `isolated` parameter sidesteps both by eliminating closures entirely.

**Three complementary mechanisms, not one general solution.** The session started looking for one tool (`Actor.run`) and discovered a spectrum:
- `Actor.run`: general-purpose, closure-based, @Sendable required
- `assumeIsolated`: non-escaping, non-@Sendable, but requires being on the executor already
- `isolated` parameter: no closure at all, borrow survives, but restructures the call site

Each fills a gap the others can't. The compound pattern (`run` to enter executor + `assumeIsolated` for cross-actor) is strictly more capable than any single mechanism.

**`nonisolated(nonsending)` is about WHERE, not WHAT.** The user correctly challenged whether `isolated` parameter was superseded by `nonisolated(nonsending)`. Testing proved they're orthogonal: `nonisolated(nonsending)` keeps you on the caller's executor but grants no actor-isolated access. `isolated` grants access. They serve different purposes. `nonisolated(nonsending)` superseded `@_unsafeInheritExecutor`, not `isolated`.

## Action Items

- [ ] **[skill]** implementation: Add actor isolation mechanism guidance — when to use `run` vs `assumeIsolated` vs `isolated` parameter, with the three-mechanism table
- [ ] **[package]** swift-async: Profile the `Actor.run` operator changes (Merge, CombineLatest, etc.) to measure actual throughput improvement for high-element-count streams
- [ ] **[blog]** "Actor.run, assumeIsolated, and isolated: The Complete Actor Transactional Access Model" — the session produced a teaching arc from simple to complex that maps well to a blog post
