---
date: 2026-04-02
session_objective: Investigate and fix io-bench benchmark hang and Channel "Invalid descriptor" failures
packages:
  - swift-io
  - swift-kernel-primitives
  - swift-iso-9945
  - swift-algebra-primitives
status: pending
---

# io-bench Hang Fix and ~Copyable Socket.Descriptor Migration

## What Happened

Session began with an investigation handoff: io-bench hung during `pure rejection latency on saturated lane` and all Channel benchmarks failed with "Invalid descriptor."

**Hang root cause**: `SaturatedLaneFixture` and `BusyLaneFixture` used `withTaskGroup` + `cancelAll()` for fixture setup. This required cooperative pool threads for cancellation handlers — starved under concurrent test execution. Fix: replaced with `lane.run.sync` (sync enqueue, zero pool involvement). Also re-enabled `pre-acceptance cancellation latency` test (was disabled with "Cooperative pool starvation — pending sync lane.run API").

**Channel "Invalid descriptor" root cause**: `Kernel.Socket.Descriptor` was Copyable, enabling double-ownership bugs. `makeSocketPairForChannel()` created a temporary `Kernel.Descriptor(sockets.0)` for `setNonBlocking` — the temporary's deinit closed the fd. Every subsequent use of that fd failed. The Selector benchmarks (same shared selector, no `Channel.wrap()`) passed — confirming the bug was in the descriptor ownership pattern, not the selector.

**Fix**: Made `Kernel.Socket.Descriptor` `~Copyable` across all platforms. On POSIX: wraps `Kernel.Descriptor` (deinit delegates to `close()`). On Windows: wraps raw `UInt64` with `closesocket` deinit. Public API identical on both platforms per [PLAT-ARCH-008]. Conversion via initializers on target type per [PATTERN-012].

**New blocker discovered**: `~Copyable` consuming capture `[peerDesc]` in `lane.run.sync { }` closure hangs — the `Lane.box()` wrapping layer double-wraps the closure, and Swift 6.3 mismanages the `~Copyable` capture lifetime in the nested closure. Handed off for `/issue-investigation`.

## What Worked and What Didn't

**Worked**: The investigation methodology was effective — reading the handoff, tracing all code paths, identifying both root causes independently. The `lane.run.sync` fix for cooperative pool starvation was immediate and correct (all non-Channel benchmarks pass, 4x faster saturated lane test). The ~Copyable Socket.Descriptor design landed cleanly across three repos (356/356 main tests pass).

**Didn't work**: The `_take()` consuming method on `Kernel.Descriptor` triggered a Swift 6.3 CopyPropagation SIL crash. Removed it and inlined the invalidation directly. The Channel benchmark rewrite using `[peerDesc]` consuming capture in `lane.run.sync` hits a separate Swift 6.3 compiler bug with ~Copyable captures through closure nesting.

**Confidence gap**: Spent significant time analyzing the Channel "Invalid descriptor" error through complex hypotheses (async lifetime analysis, poll thread fatal exit) before noticing the simple cause: a temporary `Kernel.Descriptor` in `makeSocketPairForChannel()` closing the fd via deinit. The Selector benchmark results (present in the test output) would have immediately disambiguated — should have checked diagnostic data before deep code analysis.

## Patterns and Root Causes

**Pattern: ~Copyable adoption exposes double-ownership bugs that were silent under Copyable.** The `Kernel.Descriptor(rawFd)` temporary pattern was used pervasively — it compiled and "worked" because Socket.Descriptor was Copyable (no closing deinit). Making Socket.Descriptor ~Copyable made every double-ownership site a compile error. This is exactly [IMPL-COMPILE] in action: the type system now prevents the bug class entirely.

**Pattern: Swift 6.3 has multiple SIL-level bugs with ~Copyable types in closure nesting.** The `_take()` consuming method crashed CopyPropagation. The `[peerDesc]` capture through `Lane.box` hangs (likely premature destroy of capture storage). Both are in the same family as swiftlang/swift#69496, #75172, #85275. The workaround space is constrained: can't use `_take()` (SIL crash), can't capture ~Copyable in nested closures (hang), can't disable CopyPropagation (separate SIL crash).

**Pattern: Cooperative pool starvation is a fixture design problem, not a runtime problem.** The `withTaskGroup` + `cancelAll()` pattern for benchmark fixtures inherently depends on the cooperative pool for cancellation handlers. The `lane.run.sync` API exists precisely for this — synchronous submission without pool involvement. The disabled `BusyLaneFixture` test annotation ("pending sync lane.run API") was the direct clue.

## Action Items

- [ ] **[skill]** platform: Add guidance for ~Copyable descriptor type unification across platforms — the POSIX "sockets are file descriptors" vs Windows "SOCKET ≠ HANDLE" distinction drove the dual-storage design and should be documented as a pattern
- [ ] **[skill]** implementation: Add [IMPL-COMPILE] corollary — when making a type ~Copyable, check ALL sites that create temporaries of the old Copyable type (the `Type(rawValue)` → use → deinit pattern is the canonical double-ownership bug)
- [ ] **[research]** Swift 6.3 ~Copyable closure nesting SIL bugs: consolidate the three known instances (_take() crash, [capture] hang, #69496/#75172/#85275) into a single research document with minimal reproducers for upstream filing
