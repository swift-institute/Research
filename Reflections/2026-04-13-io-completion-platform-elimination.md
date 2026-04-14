---
date: 2026-04-13
session_objective: Migrate swift-io completion layer from direct L2 io_uring/IOCP calls to Kernel.Completion abstraction, eliminating all platform-specific code
packages:
  - swift-io
  - swift-kernel
  - swift-kernel-primitives
status: processed
---

# IO Completion Platform Elimination

## What Happened

Started from a handoff to migrate IO.Completion.IOUring to use Kernel.Completion. Scope expanded mid-session: instead of rewriting the IOUring backend, we eliminated ALL platform code from swift-io's completion layer — no `#if os(Linux)`, no `IOUring` namespace, no `IOCP` namespace.

Deleted 10 platform backend files (~1,271 lines). Created `IO.Completion.Driver.bestAvailable()` (~185 lines) that delegates to `Kernel.Completion.platform()`. Simplified Handle from platform-conditional storage to a single opaque pointer. Added `Kernel.Completion.platform()` factory and `Notification.wait()` at L3 swift-kernel.

Hit three `~Copyable` borrow chain blockers: `Optional<~Copyable>` force-unwrap consumes on class properties, `Optional.map` requires Copyable, and `Notification.wait()` needed correct MemberImportVisibility + typed throws. Resolved with `Optional.take()` + explicit put-back, non-throwing `wait()`, and `import POSIX_Kernel_File` for member visibility.

Fixed EPOLLRDHUP registration in the epoll backend — read interest wasn't requesting `EPOLLRDHUP`, so peer close only delivered `.hangup` without `.readHangup`. One-line fix. Identified a latent epoll interest-clobbering issue with split channels (handoff created).

Final state: 141/141 tests pass on macOS and Linux (3/3 runs).

## What Worked and What Didn't

**Worked**: The scope expansion from "rewrite IOUring backend" to "eliminate platform code entirely" was the right call. It brought Completion to parity with Event (which already used `Kernel.Event.Source.platform()`). The resulting code is cleaner and shorter.

**Didn't work**: The initial plan underestimated `~Copyable` complexity. Three separate mechanisms were needed (`Optional.take()`, non-throwing `wait()`, `consume` keyword for Optional assignment) where the plan assumed simple borrow chains would work. Each required a build-fix-build cycle. Should have written a minimal experiment for `Optional<~Copyable>` on class properties before starting.

**Didn't work**: Grepping for references to deleted types BEFORE deleting them. The `IOUring.isSupported` reference in `Queue.swift:301` was inside `#if os(Linux)` — invisible on macOS builds. Only caught on the Linux Docker build. Lesson: when deleting platform-conditional code, grep the ENTIRE file content (not just what compiles on the current platform).

## Patterns and Root Causes

**Pattern: `~Copyable` Optional on class properties is a distinct interaction space.** Force-unwrap (`!`) consumes. `Optional.map` requires Copyable. `if let` moves. The only safe access pattern is `Optional.take()` + explicit put-back. This deserves a dedicated section in the memory-safety skill — it's not just "~Copyable" and not just "Optional" but the intersection with class stored properties that creates the constraint.

**Pattern: Platform elimination follows Event's lead.** The Event side was already abstracted (`Kernel.Event.Source.platform()`). Completion now matches. The pattern: L3 swift-kernel provides a `platform()` factory that dispatches per-platform. L3 swift-io calls it. No platform conditionals in the consumer. This is the mature form of [PLAT-ARCH-008].

**Pattern: MemberImportVisibility requires importing the defining module, not a re-exporter.** `@_exported` chains don't propagate extension member visibility. `Notification.wait()` needed `import POSIX_Kernel_File` — the module where `Kernel.IO.Read.read()` is defined (via re-export from ISO_9945). This was also hit with `Linux_Kernel_IO_Uring` vs `Linux_Kernel_IO_Uring_Standard`.

## Action Items

- [ ] **[skill]** memory-safety: Add `~Copyable Optional on class properties` section — document that `!` consumes, `map` requires Copyable, `if let` moves; `Optional.take()` + put-back is the canonical pattern [MEM-COPY-*]
- [ ] **[skill]** platform: Add guidance that platform elimination follows Event's `platform()` factory pattern; consumer packages call `Kernel.X.platform()`, never construct backends directly [PLAT-ARCH-008]
- [ ] **[skill]** implementation: Document MemberImportVisibility rule — import the L3 module that defines or re-exports the extension, not the L1 re-export chain [IMPL-*]
