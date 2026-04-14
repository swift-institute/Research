---
date: 2026-04-06
session_objective: Research executor-first architecture for swift-io and implement Phase 2 (actor coordination)
packages:
  - swift-io
  - swift-institute
status: processed
---

# Executor-First Architecture Research and Phase 2 Implementation

## What Happened

Session started from a HANDOFF requesting research into evolving swift-io from its current bottom-up architecture (poll thread + manual sync) to an executor-first model. Produced `Research/executor-first-architecture.md` (Tier 2, ~400 lines) analyzing three models: retrofit (Phase 1), two-thread actor coordination (Phase 2), and integrated event loop (Phase 3).

Identified an open question about whether `.serial` mode executors work with `withTaskExecutorPreference`. Created experiment `executor-serial-mode-task-preference` in swift-institute (5 variants, all CONFIRMED). This resolved the question: a single `.serial` executor serves both actor pinning and task preference — no dual-mode or second executor needed.

Performed comparative analysis between the literature study (`executor-lifecycle-literature-study.md`) and the new research. Key finding: Phase 2 has no precedent in surveyed frameworks — all reference architectures converge on the integrated model (Phase 3). Phase 2 is engineering convenience, not an architectural target.

Verified that a parallel session had completed Phase 1 (executor threading, 8 steps, all tests passing). Then implemented Phase 2:
- Lifted `IO.Event.Selector.Runtime` to `IO.Event.Runtime`, pinned to executor via `unownedExecutor`
- Absorbed admission gate (Atomic CAS) and halt flag (Atomic.Flag) into actor isolation
- Added `.shutdown` request sentinel to MPSC queue

Hit a critical design issue during implementation: the poll thread needs to signal the actor when it exits. Initial approach used `Task { await runtime.pollThreadDidExit() }` — an unstructured task that breaks structured concurrency and reintroduces cooperative pool dependency. User caught this immediately. Reverted to keeping `Async.Gate` (the existing exit gate), recognizing it as a communication channel rather than a state guard.

Final state: 5 primitives (down from 7), 109/109 tests pass. HANDOFF written for Phase 3.

## What Worked and What Didn't

**Worked well:**
- The experiment process was high-value: the serial-mode question would have been a blocker in Phase 2 without empirical evidence. 15 minutes of experiment saved potentially hours of design iteration.
- The user's challenge on `IO.Event.Selector.EventLoop` naming caught a [API-NAME-001] violation before it was coded. Loading `/code-surface` at the naming decision point was the right call.
- The user's sharp question about `Task {}` breaking structured concurrency caught a real architectural flaw. The instinct to use `Task {}` as a "bridge from sync to async" is a dangerous reflex — it's the async equivalent of force-unwrapping.

**Didn't work well:**
- The original research overestimated Phase 2's primitive elimination (claimed 7→3, actual is 7→5). The exit gate was categorized as "eliminatable" without considering that the replacement (continuation + `Task {}`) is strictly worse. The research should have distinguished state guards from communication channels earlier.
- Attempted to implement Steps 2-4 as one atomic change rather than incrementally. This meant the broken `Task {}` approach was deep in the code before the design flaw was identified.

## Patterns and Root Causes

**Pattern: State guards vs communication channels.** The research treated all Topology primitives as "manual synchronization" to be eliminated by actor isolation. But there are two distinct categories:
- **State guards** (admission, halt flag) protect mutable state. Actor serialization genuinely replaces them.
- **Communication channels** (exit gate, request queue, wakeup) bridge two threads. They exist because two threads exist. Only merging the threads (Phase 3) eliminates them.

This distinction maps cleanly to the literature: Tokio's ownership model eliminates state guards via type system. Its thread pool communication uses channels — which aren't eliminated, they're structural. The exit gate is swift-io's equivalent.

**Pattern: `Task {}` as async bridge is an anti-pattern.** The reflex to bridge sync→async via `Task {}` recurs across sessions. It feels natural ("I need to call an async method from a sync context") but introduces unstructured concurrency, cooperative pool dependency, and ordering hazards. The correct primitive is always a purpose-built bridge (gate, stream continuation, channel). If no bridge exists, the design needs rethinking, not a `Task {}` band-aid.

**Pattern: Phase-skip evaluation is valuable.** The user asking "why not skip to Phase 3?" forced an honest assessment. Phase 2's value is as a tested intermediate, not as a destination. The comparative analysis already said this — but it took the user's question during implementation to make it actionable.

## Action Items

- [ ] **[skill]** research-process: Add guidance for distinguishing eliminatable primitives (state guards) from structural primitives (communication channels) when analyzing sync primitive reduction. The current methodology ([RES-005]) treats all primitives uniformly.
- [ ] **[research]** Phase 3 integrated executor design: `IO.Event.Loop.Executor` with poll-integrated run loop. HANDOFF written at `swift-io/HANDOFF.md`. Key questions: driver ownership (~Copyable through executor), wakeup coupling, `withTaskExecutorPreference` interaction.
- [ ] **[package]** swift-io: The `~Copyable` enum multi-pattern case label limitation (`case .arm, .shutdown:` fails) forced separate branches in Poll.Loop. Track for Swift 6.4 — MoveOnlyAddressChecker improvement.
