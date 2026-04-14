---
date: 2026-04-06
session_objective: Investigate and implement dedicated executor threading for IO.Stream full-duplex scheduling
packages:
  - swift-io
  - swift-kernel
status: processed
---

# Executor Threading and ~Copyable Closure Constraints

## What Happened

Session began with investigating how to thread `Kernel.Thread.Executor` through
the IO Events stack to eliminate cooperative pool dependency for the `async let`
write child in `IO.Stream.callAsFunction`. Read all relevant files, mapped the
8-step implementation path, wrote findings to `HANDOFF-io-executor-thread.md`.

Owner review raised Risk 3: executor preference leaking into user closures,
blocking the serial executor with user computation. This triggered a deeper
investigation into scoping the preference narrowly.

Three approaches were identified and experimentally verified:
- **A**: `TaskGroup` + `addTask(executorPreference:)` — 2 Transfer.Cells, structural change
- **B**: `async let` + `withTaskExecutorPreference` inside child — 1 cell, minimal change
- **C**: Broad `withTaskExecutorPreference` wrapping `async let` — 2 cells, Risk 3

Approach B was optimal. Key discovery: `withTaskGroup` body IS escaping for
`~Copyable` consume — same as all closures. A dedicated experiment
(`async-closure-noncopyable-escaping`) confirmed this is a fundamental Swift
language constraint, not specific to any API. Apple's swift-http-api-proposal
confirms: "lacking call-once closures" appears 20+ times.

A parallel session's experiment (`executor-serial-mode-task-preference`) proved
`.serial` mode works with `withTaskExecutorPreference`, enabling a single executor
for both Phase 1 (task preference) and Phase 2 (actor pinning).

Implementation: 7 files, 44 insertions, 10 deletions. 381 tests pass, 0 failures.

## What Worked and What Didn't

**Worked**: The investigation-first approach. Reading all files before proposing
changes avoided false starts. The experiment process caught the `withTaskGroup`
body escaping constraint before it became an implementation dead end.

**Worked**: The three-approach comparison. Testing A/B/C side-by-side with a
single experiment package made the trade-offs concrete and verifiable.

**Didn't work initially**: Assumed `withTaskGroup` body was non-escaping (takes
`inout TaskGroup`). This led to the hypothesis that Approach A needed zero
Transfer.Cells. The experiment refuted this quickly — but the assumption was
plausible and would have been costly to discover during implementation.

**Sharp edge**: `async let` inside `withTaskExecutorPreference` breaks typed throws
inference. Requires explicit closure annotation `() async throws(IO.Error) -> R in`.
Discovered during experiment, documented, not a blocker for Approach B.

## Patterns and Root Causes

**~Copyable closure constraint is universal, not API-specific.** The error
"captured by an escaping closure" fires for ALL closures — sync, async, escaping,
non-escaping. The underlying reason: closures can be called multiple times, so
consuming a captured ~Copyable value would leave it invalid on the second call.
The error message is misleading (says "escaping" when it means "any closure").
Transfer.Cell is the permanent pattern until Swift gains call-once closures.

**Two tiers of ~Copyable closure crossing.** `var Optional.take()` works for
non-`@Sendable` closures (zero cost, stack-local). Transfer.Cell (heap + ARC)
is needed for `@Sendable` closures. Apple uses the same split.

**The executor is an architectural primitive, not a fix.** The session started
with "bolt executor onto step 7" and ended with "the executor should be the
foundation." The custom executor unifies actor coordination (Phase 2) and task
preference (Phase 1) on a single dedicated thread. Starting with the executor
would have eliminated half the manual sync primitives in IO Events.

## Action Items

- [ ] **[skill]** memory-safety: Add guidance for the two-tier ~Copyable closure crossing pattern (var Optional.take() for non-@Sendable, Transfer.Cell for @Sendable) with reference to async-closure-noncopyable-escaping experiment
- [ ] **[package]** swift-io: File Swift compiler issue for misleading error message "captured by an escaping closure" on non-escaping closures — should say "cannot consume captured noncopyable value in closure"
- [ ] **[research]** Investigate call-once closure proposals in Swift Evolution — is there an active pitch? What would the timeline be? This determines whether Transfer.Cell is a 6-month workaround or a permanent pattern.
