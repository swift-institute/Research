---
date: 2026-04-12
session_objective: Complete EINTR relayering open items from handoff — Dimension scoping, Either-based error composition, send/recv/connect EINTR wrappers
packages:
  - swift-kernel-primitives
  - swift-iso-9945
  - swift-darwin-standard
  - swift-linux-standard
  - swift-posix
status: processed
---

# EINTR Completion, Either Error Composition, and Safe Socket API

## What Happened

Resumed from a multi-session EINTR relayering handoff. Verified all prior commits, then completed the remaining open items:

1. **Dimension_Primitives scoping**: Discovered Kernel Primitives Core re-exported all of Dimension_Primitives (Angle, Axis, Coordinate, etc.) when only `Tagged` was needed. Replaced with direct `Identity_Primitives` re-export. Scoped Dimension to the one file that uses Coordinate/Displacement (Kernel.File.Offset). Propagated to darwin-standard (removed dep entirely) and linux-standard (added explicit dep for IO Uring Offset).

2. **Either-based error composition**: Made `Kernel.Interrupt: Swift.Error`, deleted `Kernel.Interrupt.Thrown` (zero consumers). Removed `.interrupted` from `Handle.Error` — domain purity. Changed L2 Handle read/write to `throws(Either<Handle.Error, Kernel.Interrupt>)` with EINTR detected via `error.code.isInterrupted`.

3. **Socket send/recv EINTR wrappers**: Found L2 send/recv/connect already existed (handoff was stale). Added Span-only public API at L2 — raw pointer versions eliminated entirely, not just made internal. L3 wrappers call safe L2 Span APIs; zero unsafe at L3.

4. **Connect EINTR completion**: Added `awaitCompletion` at L2 (poll(POLLOUT) + getsockopt(SO_ERROR)) because L3 can't access `_rawValue` on Socket.Descriptor (SPI-only). L3 connect wrapper detects EINTR → delegates to `awaitCompletion`.

5. **Glob Path migration**: Verified all 9 steps from the branch plan are satisfied by main — branch is fully superseded.

## What Worked and What Didn't

**Worked well**: The user's challenge on Dimension_Primitives ("should Core re-export it? Is it used?") uncovered unnecessary transitive dependencies across the entire kernel-primitives tree. The initial task was "remove unused imports from two files" — but the root cause was the Core re-export pulling in Angle, Axis, etc. everywhere. Challenging assumptions early produced a much better outcome.

**Worked well**: The layered EINTR design — L1 domain-pure, L2 detection + Either composition, L3 retry policy — held together cleanly across all the new socket operations. The same pattern applied to send/recv (simple retry) and connect (poll-based completion) without modification.

**Correction mid-session**: The initial socket L3 wrappers exposed `UnsafeRawPointer + length` in public API. The user caught this immediately — "we should not have ANY Pointer based public API." This escalated through three iterations: (1) add Span adapters alongside pointer API, (2) make pointer API internal, (3) eliminate pointer API entirely and inline syscalls into Span closures. The final result is cleaner, but the instinct to wrap-then-improve instead of designing safe-first wasted two rounds.

**Correction**: `sendAll` flagged as compound identifier violating [API-NAME-002]. Dropped it — partial-send loops are caller-controlled policy.

## Patterns and Root Causes

**Safe-first API design at syscall boundaries**: The IO Uring refactor established a pattern the ecosystem should follow: public API accepts only safe types (Span, MutableSpan); unsafe pointer manipulation is contained within `withUnsafeBytes` closures at the implementation boundary. The socket send/recv now follows this pattern. The existing L2 IO Read/Write still has public `UnsafeMutableRawBufferPointer` overloads alongside Span — these could be candidates for the same treatment (make internal, keep only Span public).

**Transitive dependency bloat via @_exported**: The Dimension_Primitives issue is a general pattern — `@_exported` re-exports are convenient but create invisible dependency chains. Every kernel target got Angle, Axis, Finite_Primitives, Ordinal_Primitives, Algebra.Pair through a chain they didn't need. The fix (re-export Identity_Primitives directly for Tagged, scope Dimension to its one user) is the general approach: `@_exported` should target the actual dependency, not a bundle that happens to re-export it.

**L2 as the natural home for unsafe-to-safe boundary**: The connect EINTR wrapper demonstrated why: L3 can't access `_rawValue` (SPI), so poll(fd) + getsockopt must live at L2 where SPI access exists. This is not a workaround — it's the correct layering. L2 wraps syscalls in safe types; L3 adds policy (EINTR retry). The awaitCompletion pattern is reusable for any future "wait for fd readiness" operation.

## Action Items

- [ ] **[skill]** implementation: Add guidance that public API at L2+ MUST use Span/MutableSpan for buffer parameters; raw pointer versions are implementation-only, contained within withUnsafeBytes closures
- [ ] **[research]** Should existing L2 IO Read/Write public UnsafeMutableRawBufferPointer overloads be made internal, matching the new socket Span-only pattern?
- [ ] **[package]** swift-kernel-primitives: Audit remaining @_exported re-exports in Kernel Primitives Core for unnecessary transitive dependencies (CPU_Primitives, ASCII_Primitives, etc.)
