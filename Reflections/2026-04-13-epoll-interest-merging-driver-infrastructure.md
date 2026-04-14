---
date: 2026-04-13
session_objective: Investigate and fix epoll EPOLL_CTL_MOD clobbering split channel interests
packages:
  - swift-kernel-primitives
  - swift-io
status: processed
---

# Epoll Interest Merging — Driver Infrastructure vs. IO Layer Placement

## What Happened

Resumed from a handoff investigating epoll EPOLL_CTL_MOD clobbering when split Channel
halves arm independently. The prior research (channel-full-duplex-split.md) had identified
the problem and proposed Option B (shared coordinator with arm coordination), but the
interest merging implementation was deferred.

The investigation confirmed the problem: on epoll with EPOLLONESHOT, `EPOLL_CTL_MOD`
replaces the entire interest mask. Reader arms with `EPOLLIN`, Writer arms with `EPOLLOUT`
— the second call removes `EPOLLIN`, starving the reader. Kqueue doesn't have this
because each filter (EVFILT_READ, EVFILT_WRITE) is an independent kernel event.

Initial implementation placed the fix in swift-io with `#if os(Linux)` — merging interests
in `Runtime.arm()` and re-arming residual interests in `Loop.dispatchEvents()`. All 142
tests passed. The user correctly challenged this: swift-io had just been cleaned of
platform conditionals. The fix belongs where the platform-specific behavior is already
encapsulated.

Relocated the fix to `Kernel.Event.Driver.init` (L1 swift-kernel-primitives). The Driver
init already wraps backend closures with common infrastructure (ID generation, registry
management, staleness suppression). Interest merging is another piece of that
infrastructure. The `_arm` wrapper unions new interest with `armedInterest` on Registration
before calling the backend. The `_poll` wrapper re-arms for residual interest after
one-shot delivery. No platform conditionals needed — on kqueue, the merge and re-arm
are harmless no-ops (one extra kevent per event under split full-duplex load).

Six unit tests verify the mechanics directly using test-double backends — no real
kqueue/epoll, no timing, no buffer sizes. All pass on both macOS and Linux (Docker
Swift 6.3). An integration test (512KB echo under backpressure) was added to swift-io
but is not definitive — it passes in 6ms on Linux without actually hitting backpressure
(AF_UNIX buffers absorb everything). The Driver unit tests are the definitive proof.

## What Worked and What Didn't

**Worked**: The handoff document was well-structured — it identified the exact files,
the root cause, and the prior research. The initial implementation was fast because the
problem was well-understood. The test-double approach for Driver unit tests is clean —
testing the merge/re-arm mechanics without any real kernel involvement.

**Didn't work**: The initial L3 placement (`#if os(Linux)` in swift-io) was the wrong
architectural layer. This was caught by the user, not by me. The integration test
(fullDuplexBackpressure) doesn't actually exercise the bug — 512KB flows through in 6ms
without the writer ever hitting EAGAIN. The test validates code correctness but not the
specific deadlock scenario. The Driver unit tests were needed to fill this gap.

**Low confidence area**: On kqueue, the re-arm in `_poll` re-enables an already-enabled
filter. I assert this is a kernel no-op based on EV_DISPATCH documentation, but haven't
verified the syscall overhead empirically. One extra kevent per event under split
full-duplex — probably negligible, but unmeasured.

## Patterns and Root Causes

**Pattern: Infrastructure belongs at the infrastructure layer.** The Driver init is explicitly
designed as the place where backend-specific closures are wrapped with common infrastructure.
The docstring enumerates: "ID generation, registry management, staleness suppression, and
descriptor lifecycle." Interest merging fits this list. The initial instinct to put it at
L3 was driven by "this is a platform-specific concern" — but the Driver's _arm/_poll
wrappers already have access to `Shared.registry` (which holds the fd and the registration)
and the backend `arm` closure. No new capabilities needed.

**Pattern: Integration tests under favorable conditions don't test failure paths.** The
512KB backpressure test passes because AF_UNIX buffers (~200KB on Linux) plus concurrent
echo draining absorb everything. The writer never hits EAGAIN. To truly test the epoll
clobber, you'd need to either (a) overwhelm the buffers or (b) inject artificial delays.
The Driver unit tests sidestep this entirely by testing the merge/re-arm mechanics directly
with test doubles.

**Pattern: The `#if os(Linux)` smell.** When reaching for `#if os(Linux)` in a cross-platform
layer, that's a signal the abstraction boundary is wrong. The platform-specific behavior
should be encapsulated behind an abstraction. Here, the Driver already provides that
abstraction — the fix just needed to be at the right level.

## Action Items

- [ ] **[package]** swift-kernel-primitives: Measure kqueue overhead of the re-arm path under split full-duplex load (one extra kevent per event) to confirm it's negligible
- [ ] **[skill]** testing-swiftlang: Add guidance for integration tests that depend on kernel buffer behavior — recommend Driver-level unit tests as the primary verification, integration tests as supplementary
- [ ] **[research]** Can the fullDuplexBackpressure integration test be made deterministic? Investigate controlling AF_UNIX buffer sizes via SO_SNDBUF/SO_RCVBUF to force backpressure at smaller data volumes
