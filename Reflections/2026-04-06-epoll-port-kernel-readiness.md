---
date: 2026-04-06
session_objective: Port epoll driver from swift-io to Kernel.Readiness in swift-kernel, completing platform stack alignment
packages:
  - swift-kernel-primitives
  - swift-linux-primitives
  - swift-kernel
  - swift-io
status: processed
---

# Epoll Port to Kernel.Readiness — ~Copyable Ownership Design Under Review Pressure

## What Happened

Ported the epoll driver from `IO.Event.Poll.Operations` (swift-io, Layer 3) down to `Kernel.Readiness.Driver+Epoll` (swift-kernel, Layer 3), mirroring the completed kqueue port. Created `Kernel.Event.Descriptor` as a ~Copyable eventfd primitive in the Linux primitives layer. Wired `IO.Event.Driver.epoll()`, deleted dead IO code. All 361 swift-io tests and 91 swift-kernel tests pass on Darwin.

The session went through three design iterations on eventfd ownership, each caught by review:

1. **Raw Int32 via `take()`** — created a `take()` method that stripped the ~Copyable wrapper to store a raw fd in the class. Reviewer flagged as [IMPL-INTENT] violation: the type exists to enforce lifecycle, stripping it defeats the purpose.
2. **`Kernel.Eventfd` as top-level type** — proposed but rejected for violating [API-NAME-001] (compound name) when `Kernel.Event.Descriptor` already had Error/Flags/Counter defined.
3. **`Epoll.State` stores `var eventfd: Kernel.Event.Descriptor?`** — final design. Class owns the ~Copyable value. Drain sets nil for deterministic close. Raw Int32 only in the wakeup closure through the dedicated `signal(rawDescriptor:)` SPI.

Also fixed a pre-existing test bug: `_Lock Test Process` helper created a temporary `Kernel.Descriptor` that died before `Token.release()` could use the fd. Same ~Copyable lifetime class of issue.

## What Worked and What Didn't

**Worked**: The kqueue driver was an excellent template. The structural translation (7 invariants, closure signatures, error conversion) was mechanical and correct on first pass. The ID boundary (`.zero` sentinel for eventfd wakeup) and `EPOLLONESHOT` one-shot semantics were clean adaptations.

**Didn't work**: The eventfd ownership story required three iterations. The root cause was an incorrect assumption that classes cannot store ~Copyable properties — this led to the `take()` escape hatch. The assumption was never verified; it was treated as "probably true in Swift 6.3" rather than tested. The reviewer correctly identified that the entire `take()` mechanism was a workaround for a problem that doesn't exist.

**Missed on first pass**: `.priority` → `EPOLLPRI` mapping was silently dropped. The old IO code had it; the port omitted it. Caught by reviewer comparing against the deleted source file.

## Patterns and Root Causes

**~Copyable ownership assumptions propagate into wrong design**: When I assumed "classes can't store ~Copyable properties," everything downstream was shaped by that assumption — `take()`, raw Int32 storage, manual `Kernel.Descriptor` reconstruction in drain. One incorrect premise generated an entire subsystem of workarounds. The fix was trivial (just store the value), but the workarounds took significant design effort. Pattern: verify language capability claims before building on them.

**Port fidelity requires mechanical diff, not reimplementation**: The `.priority` bug happened because I reimplemented the helpers from understanding rather than mechanically translating the deleted source. The kqueue driver doesn't have `.priority` (no `EPOLLPRI` equivalent), so comparing only against kqueue missed it. The source of truth was the file being deleted — and I didn't diff against it line-by-line.

**Temporary ~Copyable values are a recurring footgun**: Both the epoll driver's `Kernel.Event.Poll.ctl()` calls and the lock test helper create `Kernel.Descriptor(_rawValue: rawFd)` temporaries that die at end-of-expression, closing the fd. This pattern exists in the kqueue driver too. It works because the fd is owned elsewhere, but it's fragile — any change to expression evaluation order could break it.

## Action Items

- [ ] **[skill]** implementation: Add guidance on verifying Swift language capability claims (e.g., "can classes store ~Copyable?") before building design decisions on them. Pattern: assumption → verify → build, not assumption → build → discover.
- [ ] **[research]** Should `Kernel.Descriptor(_rawValue:)` temporaries in ctl()/register() calls be replaced with a borrowing pattern that doesn't create a closing owner? Affects both kqueue and epoll drivers. The current pattern is a latent fd-close footgun.
- [ ] **[package]** swift-linux-primitives: Add buffer-pointer overload to `Kernel.Event.Poll.wait` so epoll driver can use pre-allocated scratch buffer like kqueue (F10 follow-up — heap allocation on hot path).
