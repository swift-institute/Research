---
date: 2026-04-01
session_objective: Fix kqueue EBADF by making IO.Event.Driver.Handle own Kernel.Descriptor
packages:
  - swift-io
  - swift-darwin-primitives
  - swift-kernel-primitives
status: processed
---

# Handle Descriptor Ownership Refactor — Ownership Cascades and Lifecycle Footguns

## What Happened

Resumed from HANDOFF.md in swift-io. The prior session added a deinit to `Kernel.Descriptor` that auto-closes its fd, which broke all kqueue-based tests with EBADF. The root cause was straightforward: `IO.Event.Driver.Handle` stored a raw `Int32`, so the `Kernel.Descriptor` returned by `Kernel.Kqueue.create()` went out of scope and closed the kqueue fd before the Handle was ever used. Additionally, every `Kernel.Descriptor(_rawValue: kq)` temporary throughout Operations created an owning wrapper whose deinit closed the fd after each syscall.

The fix: Handle now stores `Kernel.Descriptor` directly. All 9 call sites in kqueue Operations borrow `handle.descriptor` instead of creating temporaries. One escape hatch added: `@_spi(Syscall) Kernel.Kqueue.register(rawDescriptor:events:)` for the wakeup closure (escaping @Sendable context can't borrow ~Copyable types). Epoll Operations partially updated with the same pattern.

All tests pass. But the test runner hangs after all tests complete — process never exits. Investigation revealed `Kernel.Thread.Executor` requires manual `shutdown()`. Added `executor.shutdown()` to all kqueue test functions. Hang persists. Root cause unidentified at session end.

## What Worked and What Didn't

**Worked well**: The diagnosis was fast — tracing from `Kernel.Kqueue.create()` through Handle construction to the deinit immediately revealed the ownership gap. The fix was principled: Handle owns the descriptor, Operations borrow it. Zero `Kernel.Descriptor(_rawValue:)` temporaries remain in kqueue Operations.

**Worked well**: The user's insistence on the principled fix (no `_invalidate()` patches) led to a cleaner architecture. The Handle now has correct ownership semantics that will survive future changes.

**Didn't work**: The test runner hang consumed significant investigation time and remains unsolved. The `executor.shutdown()` hypothesis was plausible but incorrect — the hang persists. This means either (a) executor shutdown isn't working as expected, (b) the hang source is something else entirely (Swift Concurrency Task, actor, or another OS thread), or (c) there's a double-close or resource corruption that blocks process exit.

**Low confidence**: Whether `handle.descriptor` can be borrowed inside `handle.buffer.withRebound` closures (simultaneous per-field borrows through a borrowed ~Copyable parameter). The code compiles and tests pass, but I'm not certain the compiler's borrow tracking is correct here vs silently producing undefined behavior.

## Patterns and Root Causes

**The ~Copyable deinit cascade**: Adding a deinit to a ~Copyable type creates a blast radius across every site that constructs or stores the type. The `Kernel.Descriptor` deinit was correct and necessary, but it broke code throughout swift-io because the code was written assuming descriptors were inert wrappers. This is the same pattern as Rust's `Drop` propagation — adding resource management to a previously-inert type forces ownership audits at every call site.

**The escaping closure ownership gap**: Swift's ~Copyable types can't be captured by escaping closures. This is a fundamental limitation that forces raw-value escape hatches in any architecture where a long-lived callable (like a wakeup channel) needs to use a resource. Rust solves this with `Arc<Mutex<T>>` or `BorrowedFd`; Swift currently has no equivalent for ~Copyable types. The `rawDescriptor` SPI overload is principled at the syscall layer but is a symptom of a language gap.

**The lifecycle footgun pattern**: Both `Kernel.Thread.Executor` and `IO.Event.Selector` require explicit shutdown calls that are easy to forget. The test hang exposed this: the kqueue tests never exercised these paths before because EBADF prevented selector creation. The question isn't "did we add the shutdown calls" — it's "should the type system prevent forgetting them?" A `consuming shutdown()` on a ~Copyable executor would make the compiler enforce cleanup.

## Action Items

- [ ] **[research]** Investigate test runner hang: use `sample` or `lldb` to identify what keeps the process alive after all tests pass. Is it the Executor thread, a poll thread, a Swift Concurrency Task, or something else?
- [ ] **[package]** swift-io: Consider making `Selector.make` own the executor lifecycle — create the executor internally and shut it down during `selector.shutdown()`, eliminating the dual-shutdown footgun
- [ ] **[skill]** memory-safety: Add guidance for ~Copyable deinit cascade patterns — when adding a deinit to a ~Copyable type, audit all sites that construct or store the type for ownership correctness
