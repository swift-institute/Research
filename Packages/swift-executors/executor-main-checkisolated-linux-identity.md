---
title: Executor.Main checkIsolated Treatment and Linux Main-Thread Identity
version: 0.1.0
status: IN_PROGRESS
tier: 2
created: 2026-04-16
last_updated: 2026-04-16
applies_to:
  - swift-executors
  - swift-linux-standard
  - swift-darwin-standard
  - swift-iso-9945-kernel
---

# Context

The polling-tick isolation session landed `checkIsolated` +
`isIsolatingCurrentContext` on `Kernel.Thread.Executor.Polling` and
`Kernel.Thread.Executor`, bridging the Swift runtime's isolation check
to the executor's OS thread identity. This eliminated
`nonisolated(unsafe)` from `IO.Events.Actor` state and registrations.
The same pattern applies to `Executor.Main`: main-thread callbacks run
on the main OS thread but outside a Swift Task context, so
`assumeIsolated` traps there too. Apple's `DispatchMainExecutor`
handles this via `_dispatchAssertMainQueue()`. We need an analogous
implementation. On Darwin, `pthread_main_np()` is the direct primitive.
On Linux, there is no equivalent — candidates include `gettid() ==
getpid()` (TID-of-process-group-leader is the main thread), reading
`/proc/self/status` (slow, fs-dependent), or capturing the main-thread
TID at executor construction time and comparing against the current
TID.

# Question

Should `Executor.Main` get the same `checkIsolated` +
`isIsolatingCurrentContext` treatment as `Polling`, and what's the
right Linux main-thread identity mechanism? Specifically:

- Which identity mechanism (`gettid() == getpid()` vs `/proc/self/status`
  vs construction-time capture) is fastest, most correct, and most
  portable across kernel versions?
- Does ISO 9945 already expose a main-thread-identity primitive we've
  missed?
- Is the construction-time-capture approach safe if the main thread's
  TID is stable across the process lifetime? (On Linux it is, per
  `pthread_create(3)` semantics.)
- Does this need a new `gettid` / `getpid` shim, or are both already
  exposed by `iso-9945-kernel`?

# Prior Work

- `swift-foundations/swift-io/Research/polling-tick-isolation-checkisolated.md`
- `swift-foundations/swift-io/Research/executor-conformance-triage.md`
- Apple's `DispatchMainExecutor` in `swift-platform-executors`
- Swift runtime source: `Actor.cpp:497-557`
- Source reflection: `swift-io/Research/Reflections/2026-04-15-polling-tick-isolation-checkisolated-landing.md`

# Analysis

_Stub — to be filled in during investigation._

Key sub-questions to work through:

- Does `pthread_main_np` exist on Linux via any libc? (No — it's BSD.)
- Does `gettid() == getpid()` survive `setuid`, `clone()`, or
  container namespace transitions?
- What's `DispatchMainExecutor`'s identity mechanism on Linux? (Check
  swift-corelibs-libdispatch.)

# Outcome

_Placeholder — to be filled when analysis completes._

# Provenance

Source: `swift-foundations/swift-io/Research/Reflections/2026-04-15-polling-tick-isolation-checkisolated-landing.md` action item.
