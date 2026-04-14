---
date: 2026-04-13
session_objective: Isolate the CopyToBorrowOptimization bug that eliminates actor state after shutdown, build a self-contained reproducer, and fix swift-io
packages:
  - swift-io
  - swift-kernel
status: processed
---

# CopyToBorrowOptimization + WMO Miscompiles Actor Enum State

## What Happened

Continued from a prior session's handoff. The goal was to isolate which Kernel `@inlinable` code triggers WMO + CopyToBorrowOptimization eliminating an actor's `private var state` field, then file upstream.

**SIL/IR/asm analysis**: Generated SIL with and without C2B for the full BugModule. Found that C2B does NOT change `register()`, `shutdown()`, or `Selector.register()` at any level — SIL, LLVM IR, and machine code are identical. C2B only removes `strong_retain`/`strong_release` around the Lock class reference in `enqueue()`.

**Caller-side diagnosis**: Discovered `@_optimize(none)` on BugTest's `run()` fixes the bug. Adding diagnostic reads of the state byte also fixes it (Heisenbug). BugModule is not recompiled between these tests. Concluded the bug is in LLVM's optimization of the caller's async continuation handling, triggered by something in BugLib's `.swiftmodule`.

**Self-contained reproducer**: Built a standalone 2-target SwiftPM package with zero external dependencies that reproduces 100%. Reduced from 9 files / 421 lines to 2 files / 87 lines through systematic elimination.

**Trigger isolation**: Identified six essential ingredients — removing any one makes the bug disappear. Most surprising: the Lock class and thread machinery were red herrings; a threadless executor that always calls `runSynchronously` still triggers. The actual essential ingredients are: `enum State` (not Bool), `consuming` (not mutating), stdlib `Mutex` on `~Copyable` struct (not plain `~Copyable` padding), Selector wrapper, custom executor, cross-module async call.

**Fix applied**: Removed `Mutex<Shutdown.Token?>` from `IO.Event.Selector.Scope`, replaced with direct `var Shutdown.Token?`. Workaround was applied by a separate session per handoff. All 143 tests pass in release mode.

## What Worked and What Didn't

**Worked well**: SIL diff methodology for ruling out what C2B doesn't change. The `@_optimize(none)` experiment was the key insight that located the bug in the caller, not the callee. Binary reduction (remove one thing, rebuild, test) was effective once the standalone reproducer existed.

**Didn't work**: The initial SIL analysis led to a plausible but wrong theory (Lock class retain/release removal in `enqueue`). We spent significant time on that before the standalone reproducer revealed the Lock was irrelevant. The early handoff's "fake @inlinable types don't trigger" finding was also misleading — the fake types failed for different reasons than we assumed.

**Confidence boundary**: We never identified the exact LLVM optimization that goes wrong. We know WHERE the bug manifests (caller's async continuation) and WHAT triggers it (the six ingredients) but not the precise mechanism inside LLVM. This is sufficient for a workaround and a bug report, but not for proposing a compiler fix.

## Patterns and Root Causes

**Pattern: Heisenbug = look at the caller, not the callee.** When adding observation (diagnostic reads) changes behavior without recompiling the observed module, the problem is in how the caller is compiled. This is a general diagnostic principle for cross-module optimization bugs.

**Pattern: Reduction reveals, theory misleads.** The SIL diff gave a plausible theory (Lock retain/release removal) that survived until the standalone reproducer disproved it. Building the reproducer — which required actually matching the SIL pattern — inadvertently tested whether the theory was correct. Reduction to essentials is more reliable than forward reasoning from SIL diffs.

**Pattern: `~Copyable` + `Mutex` + `consuming async` is a compiler-fragile corner.** The six-ingredient trigger list is suspiciously specific. It involves multiple recent language features (`~Copyable`, typed throws, custom executors, `consuming` functions) interacting through WMO cross-module serialization. This corner of the optimizer is likely undertested. The segfault we found when removing the Selector wrapper (direct `runtime.register()` call after `consuming close()`) may be a related but separate issue.

**Observation on workaround validity**: The `Mutex` on the `~Copyable` Scope was defensive but redundant — `~Copyable` ownership already guarantees single-owner semantics, and `consuming` enforces at-most-once on `close()`. Removing it is a correct simplification independent of the compiler bug.

## Action Items

- [ ] **[research]** The segfault when accessing an actor reference directly from a `~Copyable` struct after `consuming` a method (without the Selector wrapper) — is this a second compiler bug or UB in our code? Reproducer exists in the standalone package's git history.
- [ ] **[package]** swift-io: `IO.Completion.Queue.Scope` uses the same `Mutex<Token?>` pattern on a `~Copyable` struct — verify whether it's affected and apply the same fix if so.
- [ ] **[skill]** memory-safety: Add guidance that `Mutex` on `~Copyable` structs with `consuming async` methods triggers a known Swift 6.3 miscompilation under WMO. Prefer actor-isolated state or direct `var` fields with `~Copyable` ownership guarantees.
