---
date: 2026-04-03
session_objective: Investigate io-bench Channel benchmark hang attributed to ~Copyable closure capture through Lane.box double-wrapping
packages:
  - swift-io
  - swift-kernel-primitives
  - swift-ownership-primitives
status: pending
---

# ~Copyable Closure Capture Investigation — Hypothesis Disproven, Verification Order Matters

## What Happened

Picked up `HANDOFF-noncopyable-closure-capture.md` which attributed the io-bench Channel benchmark hang to a Swift 6.3 compiler bug: `~Copyable Kernel.Descriptor` captured via `[peerDesc]` in an `@escaping @Sendable` closure being invalidated when that closure passes through `Lane.box()` (which wraps it in a second closure). The handoff was specific and confident in this diagnosis.

Traced the full 6-step chain from capture to worker thread execution: `lane.run.sync` -> `Sync.callAsFunction` -> `Property.callAsFunction` -> `Lane.box` (creates wrapper closure) -> `Threads.enqueue` (stores in `Job.Instance`) -> worker calls `job.run()`. Found the `isValid` guard in `ISO 9945.Kernel.IO.Read.read` passes for zeroed `_raw = 0` (fd 0 / stdin), which would explain a hang. Found 3 related swiftlang/swift issues (#69496, #75172, #85275). Wrote extensive findings section in the handoff doc.

Applied the `Ownership.Transfer.Cell` workaround (already validated in `IO.Event.Channel.Tests.swift:500`) to all 3 Channel benchmarks — completely bypasses closure capture by transferring `peerDesc` through a thread-safe cell. **Still hangs.** The ~Copyable capture hypothesis is wrong.

Also added `print("[DIAG]")` diagnostics, but swift-testing captures stdout — no output visible. Session ended before switching to stderr.

## What Worked and What Didn't

**Didn't work**: The investigation order. Spent ~80% of session time building a detailed causal chain and writing findings, then tested the core hypothesis last. The Cell workaround disproved the entire analysis in one test. Had the workaround been applied first (15 minutes), the remaining time could have been spent finding the real cause.

**Worked**: The Cell/Token pattern itself is confirmed sound — it compiles, builds cleanly, and correctly transfers `~Copyable` values across the `@Sendable` boundary. The infrastructure trace is also accurate and useful for the real investigation.

**Didn't work**: stdout diagnostics in swift-testing. The `print()` output is captured and only shown on failure. For a hanging test, it's never flushed. Must use `fputs(msg, stderr)`.

## Patterns and Root Causes

**Confirmation bias from confident handoffs.** The branching handoff document presented a specific, plausible hypothesis with supporting evidence (single closure works, double-wrapped doesn't; CopyPropagation involvement; known Swift bugs). This framing channeled the investigation toward confirming the hypothesis rather than testing it. The analysis found what it was looking for — a coherent causal chain — without empirical verification.

The correct investigation order for any "suspected root cause" handoff is: **(1) test the hypothesis first** (apply workaround, add diagnostic, check fd value), **(2) if confirmed, analyze the mechanism**, **(3) write findings last**. This session did 2 -> 3 -> 1 and wasted effort on 2 and 3.

**The real differentiator is unknown.** Channel benchmarks differ from passing benchmarks in multiple ways: socket pairs, `IO.Event.Selector.shared()`, `IO.Event.Channel.wrap`, async channel I/O (`channel.write/read`), and the `~Copyable` capture. The prior investigation fixated on the last one. The real cause could be any of the others — particularly the async Channel/Selector interaction, which is unique to the Channel benchmarks.

## Action Items

- [ ] **[skill]** issue-investigation: Add requirement to empirically verify the core hypothesis BEFORE analyzing mechanism or writing findings — "test first, analyze second"
- [ ] **[skill]** handoff: Add optional `confidence:` field (high/medium/low) to branching template Issue section, signaling whether the new session should verify or proceed
- [ ] **[package]** swift-io: Channel benchmark hang root cause is unknown — stderr diagnostics needed to determine if hang is in worker `read()`, async `channel.write()`, or `echoHandle.value()`
