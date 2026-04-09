---
date: 2026-04-09
session_objective: Audit Kernel.Event.Poll (epoll) and Kernel.Event.Queue (kqueue) across L1 and L3 for compliance with code-surface, implementation, platform, and modularization skills, then remediate all findings.
packages:
  - swift-darwin-primitives
  - swift-linux-primitives
  - swift-foundations
status: pending
---

# Kernel.Event Audit and C Type Elimination

## What Happened

Session ran two parallel audit agents against the Event.Poll (epoll, 14 L1 files) and Event.Queue (kqueue, 10 L1 files + 1 L3 file) implementations. Audits checked against [API-NAME-*], [API-ERR-*], [API-IMPL-*], [IMPL-*], [PLAT-ARCH-*], [PATTERN-*], and [MOD-*] requirement IDs.

Audits found 15 violation categories total, 6 clean categories. Key findings:
- Platform conditional misuse (`canImport` for platform identity) in 17 files
- Musl compilation failure from `Glibc.`-qualified `read`/`write` calls
- 5 public methods exposing raw C types (`kevent`, `timespec`) in kqueue API
- Typed throws erosion via `catch let error as Error` + dead `catch {}` in `withUnsafeTemporaryAllocation` closures
- Missing L3 dependency declaration (already fixed in prior session)

Consolidated a remediation plan (7 phases), then executed all phases via two parallel agents (epoll + kqueue). The kqueue refactoring eliminated the entire raw C API layer — collapsed a three-layer architecture (consumer -> Swift-native -> raw C -> `_kevent`) to two layers (consumer -> Swift-native -> `_kevent`).

During remediation plan review, the user rejected the `Result`-based error propagation pattern and directed use of direct typed throws through `rethrows`. Pointed to `Either<L: Error, R: Error>: Error` from `Algebra_Primitives` as the coproduct approach when multiple error domains converge — keeping typed throws pure without boxing.

Verified: macOS clean build (darwin-primitives, linux-primitives), Linux clean build (Docker swift:6.3 with libuuid-dev). L3 swift-darwin builds clean with the refactored Queue.swift.

## What Worked and What Didn't

**Worked well:**
- Parallel audit agents produced thorough, well-structured findings. Both completed in ~8-10 minutes and caught violations the other didn't (different subsystems, different patterns).
- Parallel remediation agents executed 30 file changes across both subsystems without conflicts.
- The agent-written commits were accepted without modification.

**Friction:**
- The epoll agent removed `Glibc.` qualifiers from `read`/`write` as the plan specified, but unqualified `read`/`write` resolves to instance methods (not C functions) on Swift 6.3 Linux. The user had already fixed this with module-qualified `Glibc.read`/`Musl.read` per the iso-9945 pattern. The audit finding was correct (Musl breakage) but the proposed fix was wrong — needed conditional module qualification, not removal.
- The `Result`-based error propagation pattern was the wrong approach. `rethrows` preserves typed errors from the closure in Swift 6.2+, so direct `throw` inside the closure works. The `Result` wrapping was a workaround for a problem that no longer exists.

## Patterns and Root Causes

**C name shadowing in extension methods is a recurring hazard.** When an extension method on a type has the same name as a C function (`read`, `write`, `close`), unqualified calls inside the type resolve to `self.method()`. The fix is always conditional module qualification — not removal of the qualifier. This is the same pattern documented in `HANDOFF-kernel-event-consolidation.md` under Dead Ends.

**`rethrows` + typed throws eliminates the need for `Result`-based error escape from stdlib closures.** The `Result` pattern was needed when `rethrows` erased the error type. In Swift 6.2+, `rethrows` preserves the closure's typed error. Every `withUnsafeTemporaryAllocation` / `withUnsafeBufferPointer` call site using `Result` to tunnel errors is now unnecessary ceremony. `Either<A, B>: Error` covers the multi-domain case without boxing.

**Audit-then-remediate is effective as a parallel pipeline.** Running audits as background agents while the main conversation continues other work, then consolidating findings into a phased remediation plan, then executing phases via parallel agents — this three-stage pipeline maximizes throughput while maintaining architectural coherence.

## Action Items

- [ ] **[skill]** implementation: Add guidance that `rethrows` preserves typed errors in Swift 6.2+ — direct `throw` inside `rethrows` closures is preferred over `Result`-based tunneling. Reference `Either<A, B>: Error` for multi-domain error coproduct. Relates to [IMPL-075].
- [ ] **[skill]** platform: Add warning about C function name shadowing in extension methods — when a type has a method named `read`/`write`/`close`, calls to the C function inside that type must use conditional module qualification (`Glibc.read` / `Musl.read`). Reference the iso-9945 pattern.
- [ ] **[package]** swift-linux-primitives: Audit remaining `Result`-based error tunneling in epoll `poll()` methods — same pattern as kqueue, should use direct typed throws.
