---
date: 2026-04-03
session_objective: Investigate and fix the io-bench Channel benchmark hang after poll-thread dispatch migration
packages:
  - swift-io
status: processed
---

# io-bench Echo Hang — Pipeline Deadlock, Not Pool Starvation

## What Happened

Picked up from HANDOFF.md which hypothesized cooperative pool starvation as the cause of the io-bench Channel echo benchmark hanging after commit `48db9ea5` (poll-thread dispatch migration). The handoff suggested attaching a debugger and profiling thread blocking.

Performed a structural analysis of every point where cooperative pool threads are consumed in the benchmark. Found that with ~3 tasks (test body, SharedSelector actor, Runtime actor) on 8+ pool threads, saturation is structurally impossible. Every async point properly suspends and releases its thread. The Mutex acquisitions (registration table, lane enqueue) are microsecond-scale.

The actual root cause: **pipelined write buffer deadlock**. The echo benchmark writes 64 KB (1000 x 64B) before reading any echoed data. With 8 KB AF_UNIX socket buffers (`net.local.stream.sendspace: 8192`), the echo driver's write-back fills the receive buffer at ~128 messages, blocking the echo driver's `write()`. This prevents the echo driver from reading, the send buffer stays full, write-readiness never fires, and the benchmark task is suspended in `receive()` forever.

This deadlock had already been discovered and documented in `channel-full-duplex-split.md` (2026-03-27, commit `dad03cc1`). The `split()` API was implemented as Phase 3. The `pipelinedEcho` correctness test passes using the split pattern. But Phase 5 (update the benchmark to use split) was never done.

Fix: applied the `pipelinedEcho` test pattern to the echo benchmark — `channel.split()` with concurrent Writer (`Task.detached` via `Ownership.Transfer.Cell`) and Reader (current task). Committed as `c79a0f74`.

Also explored a larger API redesign (moving `Channel.wrap` to `selector.register()` returning Split directly, eliminating Channel from the bidirectional path). After critical analysis, deferred — the 50-line benchmark fix has better ROI than a public API overhaul, and split() as opt-in was a considered design decision.

## What Worked and What Didn't

**Worked**: The structural analysis methodology. Instead of attaching a debugger (expensive, noisy), systematically tracing every cooperative pool consumption point from the code proved the starvation hypothesis wrong in minutes. The `sysctl net.local.stream.sendspace` check immediately confirmed the buffer math.

**Worked**: Having prior research. The `channel-full-duplex-split.md` document and the `pipelinedEcho` test provided both the diagnosis and the proven fix pattern. The fix was a mechanical application of an already-validated design.

**Didn't work**: The HANDOFF hypothesis. "Cooperative pool starvation" was plausible-sounding but wrong. The real cause was simpler and more fundamental — a buffer deadlock that's independent of the concurrency runtime. The poll-thread dispatch migration was a red herring; the hang existed before that change too.

**Didn't work well**: Initial investigation scope. Started with sampling the process (got SwiftPM runner, not the test binary), explored driver kqueue flags, and read many files before the buffer size check made the root cause obvious. A more disciplined "cheapest check first" approach would have identified the 8 KB buffer limit earlier.

## Patterns and Root Causes

**HANDOFF hypothesis inertia**: The HANDOFF framed the problem as cooperative pool starvation, and the initial investigation followed that framing. The structural analysis that disproved it came from stepping back and asking "is this even possible?" rather than "where is the saturation?" This is a general pattern: inherited hypotheses from prior sessions carry authority they haven't earned. The handoff said "pool starvation" so the investigation looked for pool starvation.

**Phase completion gaps**: The full-duplex plan had 5 phases. Phases 1-3 were implemented (including the correctness test proving the fix works). Phase 5 (apply to benchmark) was trivial but never done. The research correctly identified the problem, the implementation correctly solved it, but the final wiring step was lost across session boundaries. This suggests handoffs should track phase completion state, not just "next steps."

**API design vs pragmatic fix**: Explored a significant API redesign (selector-centric registration, Channel elimination) before the user redirected to "fix the hang first." The opposing-view analysis revealed that the proposed redesign doesn't actually prevent the deadlock at the type level (Reader + Writer in the same task still deadlocks), making the ROI poor. A documented opt-in split() is sufficient.

## Action Items

- [ ] **[skill]** handoff: Add guidance to track phased plan completion state — when a HANDOFF references a multi-phase plan, each phase should have explicit status (done/pending), not just "next steps"
- [ ] **[skill]** issue-investigation: Add "check buffer/resource bounds" as a cheap first step for hang investigations — before attaching debuggers, verify that the workload fits within OS resource limits (socket buffers, file descriptor limits, thread pool sizes)
- [ ] **[package]** swift-io: Phase 4 (epoll interest combining for Linux full-duplex) remains the last blocking item for cross-platform split() support
