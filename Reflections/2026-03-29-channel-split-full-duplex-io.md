---
date: 2026-03-29
session_objective: Implement Channel split() API for full-duplex I/O (Phase 3 of Channel Full-Duplex refactor)
packages:
  - swift-io
status: pending
---

# Channel split() — Full-Duplex I/O via Ecosystem-Aligned Split Pattern

## What Happened

Implemented `consuming func split() -> Split` on `IO.Event.Channel`, producing independent `Reader` and `Writer` halves for concurrent read/write from separate tasks. This was Phase 3 of the Channel Full-Duplex refactor (HANDOFF.md).

**Types created**: `Storage` (shared ARC class with 2-bit atomic alive mask), `Reader` (~Copyable read half), `Writer` (~Copyable write half), `Split` (~Copyable bundle with one-shot extraction), `Storage.Alive` (bit mask namespace), `Read`/`Write` namespace enums with nested `.Result` types.

**Key design decisions**:
- Storage mirrors `Async.Channel.Unbounded.Storage` ARC-lifetime pattern — multiple views share one class, last reference triggers cleanup
- Event delivery reuses existing `Async.Channel.Unbounded.Ends` (no reimplementation)
- `Ownership.Transfer.Cell` used for ~Copyable Writer transfer across @Sendable boundary in tests
- 2-bit atomic alive mask (CAS loop) coordinates last-close: each half clears its own bit, the half that reaches zero does async deregister + fd close

**Compiler constraints encountered**:
1. Tuples cannot contain ~Copyable elements — required `Split` struct with Optional members and one-shot `reader()`/`writer()` extraction methods
2. Implicit conversion of ~Copyable to Optional is consuming — required explicit `consume` in Channel init
3. Channel has a deinit, preventing partial consumption of stored properties — required making `readEnds`/`writeEnds` Optional with `.take()!` extraction in `split()`

**Test**: Enabled the previously-deadlocking `pipelinedEcho` test (500 × 64B over AF_UNIX socket pair, 32 KB total — exceeds 8 KB buffer). Passes in 4ms.

## What Worked and What Didn't

**Worked well**:
- The architectural question "can IO.Event.Channel be replaced by Async.Channel?" was worth asking before implementation. The answer (no — different domains, but the split pattern mirrors the ecosystem) clarified the design boundary and prevented over-abstraction.
- `Ownership.Transfer.Cell` from swift-ownership-primitives was the exact primitive needed for ~Copyable task transfer. Ecosystem reuse per [IMPL-060].
- The alive mask CAS protocol is correct for all interleavings (both close concurrently, one close + one deinit, both deinit). The review agent incorrectly flagged a "double-abandon" — tracing the CAS through all interleavings confirmed single-cleanup.

**Friction points**:
- Multiple rounds of naming review were needed. Initial code had compound names (`closeDescriptor`, `fireAndForgetClose`, `pendingSocketError`, `readerBit`/`writerBit`) that violated [API-NAME-002]. Required loading `/implementation` and `/code-surface` skills before writing code.
- `ReadResult`/`WriteResult` compound names were pre-existing but became visible when widened from `private` to `internal`. Required full namespace refactor (`Read.Result`/`Write.Result`) with 4 new files.
- The `Split` struct was not in the original design (which planned a tuple return). Compiler limitation forced the indirection.

## Patterns and Root Causes

**Pattern: ~Copyable tuples are not yet supported in Swift.** This forced the `Split` struct with Optional members and one-shot extraction. The Async.Channel ecosystem solved a similar problem with `Take` + `Ends` — a consuming namespace struct that yields a bundle. Our case is harder because we have TWO ~Copyable values to extract (Reader + Writer), while Async.Channel only extracts one (Receiver; Sender is Copyable). The Optional-with-take() pattern is the current workaround. When Swift adds ~Copyable tuple support, `Split` can be replaced with a direct tuple return.

**Pattern: Skills must be loaded before writing code, not after.** The first two attempts at Storage.swift were rejected for compound naming violations. Loading `/implementation` and `/code-surface` skills first would have prevented the iterations. This reinforces that the CLAUDE.md's "Before Writing Code" section exists for a reason.

**Pattern: Internal type visibility changes surface naming debt.** `ReadResult`/`WriteResult` were `private` — hidden from naming scrutiny. Widening to `internal` for Reader/Writer access exposed the compound naming violation. The fix (namespace enum + `.Result`) is the ecosystem pattern. Lesson: when widening access, audit the name against current conventions.

## Action Items

- [ ] **[skill]** implementation: Add guidance for ~Copyable tuple limitation — when returning multiple ~Copyable values, use a ~Copyable bundle struct with Optional members and one-shot extraction methods. Reference Split pattern.
- [ ] **[package]** swift-io: Phase 4 (epoll interest combining) and Phase 5 (pipelined benchmark) remain. Update HANDOFF.md with Phase 3 completion status and Split struct API shape.
- [ ] **[skill]** code-surface: Add guidance that widening access level (private → internal/public) is a naming audit trigger — the name must pass [API-NAME-002] at its new visibility.
