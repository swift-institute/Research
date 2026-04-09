---
date: 2026-04-08
session_objective: Implement IO.run(fd) single-stream entry point and plan io_uring integration into single-thread Events loop
packages:
  - swift-io
  - swift-kernel
  - swift-kernel-primitives
status: pending
---

# io_uring Integration Architecture and L1 Completion Migration

## What Happened

Session started with implementing `IO.run(fd) { reader, writer in }` — the
single-stream entry point using the shared selector. Two overloads added
(standalone + explicit context), error mapping moved from `IO.Stream.mapError`
to `IO.Error.init(_ IO.Event.Failure)`.

The session then pivoted to a deep investigation of how IO Completions should
integrate with the Events architecture. Through Socratic questioning, the user
drove to the key insight: **io_uring does not need its own poll thread**. Submissions
are non-blocking ring buffer writes; completions are discovered via eventfd
registered with epoll. The existing Events loop handles both.

Research produced: `io-uring-integration-architecture.md` (v2) covering prior art
(monoio, libxev), multishot operations, SQPOLL mode, provided buffer groups, and
a 6-step execution plan. The eventfd integration experiment confirmed the path
(100K NOPs in 13ms via epoll_wait on eventfd).

A parallel agent session (which I advised on) then executed Steps 1-3: created
`Kernel.Completion` + `Kernel.Completion.Driver` at L1, extracted
`Kernel.Wakeup.Channel` to a shared L1 location, and attempted the IOUring
backend (Step 4) — which was deleted because raw Int types violated [IMPL-002].

## What Worked and What Didn't

**Worked well:**
- The Socratic questioning approach ("why is there even a poll thread?", "are you
  sure you need an event loop for io_uring?") drove from a wrong assumption
  (separate Completions loop) to the correct architecture (integrated eventfd)
  in three exchanges. First-principles reasoning > pattern matching.
- `inout` parameters for the IO.run closure — user's suggestion was strictly
  better than the consuming approach I initially proposed. Clean 90% case.
- Shared selector for standalone IO.run(fd) — avoids per-call thread overhead.
- Non-Sendable Driver decision — my review feedback (drop Sendable, use sending
  transfer) was adopted. Eliminates @Sendable on all closures, allowing natural
  capture of mmap'd ring state.
- L1 migration of Completion types — resolved the circular dependency that would
  have blocked the IOUring backend in swift-linux. User pushed for the correct
  architecture (Option A) despite my recommending the pragmatic shortcut (Option B).

**Didn't work:**
- I initially designed the IO.run closure with `consuming sending` parameters,
  requiring `var reader = reader` rebinding at every call site. The user
  identified this ergonomic issue and proposed `inout` instead.
- The IOUring backend attempt hit the typed wrapper blocker — Submission/Event
  use raw Int32/UInt64. This should have been caught during the type design review
  (I reviewed the types and said "Int usage is acceptable at the kernel layer").
  The user was right to insist on typed wrappers.

## Patterns and Root Causes

**"Don't patch, don't rewrite, just prove the path"** — The IO Completions
target has 62 files of broken-on-Linux code. The temptation was to either patch
it (5-line fix) or rewrite it. The correct move was neither: build the experiment
standalone (zero dependency on broken code), prove the architecture, then build
the replacement from scratch. The old code is reference material, not foundation.
This pattern applies whenever legacy code exists alongside a planned replacement.

**User-driven architecture > agent-proposed architecture** — I proposed a
separate IO.Completion.Loop (Option A in the original plan). The user asked
"why?" three times and I arrived at "it doesn't need one." The Socratic method
worked because each question removed an assumption rather than adding complexity.
The final architecture (one thread, eventfd piggybacking) is simpler than anything
I would have designed top-down.

**Typed wrappers as a blocker, not a follow-up** — I said "Int usage is acceptable
at the kernel layer" during the Completion type review. The agent session then
built an IOUring backend with raw Ints and had to delete it. The lesson: [IMPL-002]
applies at every layer. The kernel types ARE the vocabulary for the backend.
If they use raw Ints, the backend will too, and it cascades upward. Getting the
types right at L1 is prerequisite to everything above.

## Action Items

- [ ] **[skill]** implementation: Add guidance that [IMPL-002] applies at L1 kernel layer — raw Int for syscall boundaries only, not for inter-layer vocabulary types like Submission/Event
- [ ] **[research]** Typed wrapper design for Kernel.Completion.Submission/Event — platform-agnostic equivalents of io_uring's Operation.Data, Length, Offset
- [ ] **[package]** swift-io: Triage the 4 stale HANDOFF-*.md branching files (actor-state, blocking-driver, linux-docker, split-cancellation)
