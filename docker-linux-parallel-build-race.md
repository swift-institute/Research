# Docker Linux Cold-Build Parallel-Build Race

| Field | Value |
|-------|-------|
| Tier | 1 |
| Scope | Verification discipline across Linux Docker cycles |
| Status | **SUPERSEDED 2026-04-25** by [`spm-build-parallelism-spurious-module-errors.md`](spm-build-parallelism-spurious-module-errors.md) |
| Provenance | 2026-04-22-iso9945-socket-message-header-cycle1-and-layer-correction.md; 2026-04-17-kernel-completion-opcode-enum-reshape-implementation.md |

> **Superseded.** This stub captured the question; the successor note provides
> empirical evidence (six concrete transient observations across five upstream
> packages collected 2026-04-24 → 2026-04-25 during the D5 sweep + D3+D6
> re-derivation cycles), a 5-step verification protocol, and implications for
> /audit, /platform, and /handoff workflows. Open questions (1)/(3) below are
> answered by the successor; question (2) — minimal reproducer for upstream
> bug filing — remains open and is appropriate for a `/issue-investigation`
> follow-up. The stub is preserved for provenance.

## Context

Multiple sessions have observed a cold-cache Docker Linux build race where `swift test` with default parallelism fails on a kernel-primitives dependency ordering issue, while `swift test -j 4` or pre-warmed builds succeed. ≥3 occurrences this cycle, plus prior scattered sightings.

## Question

1. Is this a SwiftPM + Swift 6.3.1 ordering bug worth filing upstream?
2. What's the minimal reproducer?
3. Does `-j 1` or pre-warming `kernel-primitives` eliminate the race reliably, or just reduce its probability?

## Analysis (stub)

Observations to capture:

- Cold Docker container with no `.build` cache.
- Large package graph including `swift-kernel-primitives` transitively.
- Failure mode: import error, usually `@_spi(Syscall) import Kernel_Completion_Primitives` reported as unresolved.
- Reliable invocation: `swift test -j 4` OR full `.build` wipe + retry.

## Outcome (pending)

Either:

- Upstream bug report to `swiftlang/swift` with minimal reproducer.
- Workaround documentation in the `/platform` skill (mitigation via `-j` setting).
- Both.

## References

- Reflections: 2026-04-22-iso9945-socket-message-header-cycle1-and-layer-correction.md, 2026-04-17-kernel-completion-opcode-enum-reshape-implementation.md
