---
date: 2026-04-09
session_objective: Refactor swift-kernel Kernel.Completion+IOUring backend for new L1 Uring API
packages:
  - swift-kernel
  - swift-kernel-primitives
  - swift-linux-primitives
status: processed
---

# Completion API Architecture Pivot — Tactical Refactor Reveals Design Question

## What Happened

Session began by reading the `HANDOFF-kernel-event-consolidation.md` from swift-primitives. L1 work was complete: `Kernel.IO.Uring` IS the ring struct, full typed API, io_uring domain model done. Task was to update L3 consumers in swift-kernel, starting from the "Next Steps" section.

Explored the L3 state in detail: `Kernel.Completion+IOUring.swift` (untracked, compiles on Linux) wraps L1 Uring in a `Kernel.Completion.IOUring.Ring` class. The swift-kernel HANDOFF listed 6 type-upgrade items. Analysis showed most were already resolved by the L1 refactor — the main change was `Kernel.IO.Uring.Ring` → `Kernel.IO.Uring` rename plus count type conversions.

Started applying mechanical edits (3 of ~13 completed). User challenged:
1. "What is this Ring type?" — the L3 Ring class wrapping the L1 Uring
2. "There should NOT be a Kernel.Completion.IOUring L3" — rejected the platform-specific L3 type entirely
3. Confirmed Driver witness stays for testability

Session pivoted from implementation to architecture: the right design for the unified Completion API needs research, not coding. Reverted partial edits. Wrote research handoff to swift-kernel/HANDOFF.md.

## What Worked and What Didn't

**Worked**: The thorough L1 API surface exploration (Uring struct, SQE/CQE types, Params, Flags, count types) was valuable — this understanding carries forward into the research. Reading the existing research documents (io-uring-integration-architecture, perfect-api, completion-queue-ownership-redesign) provided essential context.

**Didn't work**: Starting implementation before confirming the design. The mechanical refactor (rename Ring → Uring, update count types) would have produced code that still had the wrong architecture. Three edits applied then reverted.

**Confidence gap**: When proposing `Kernel.Completion.createUring` as a factory helper, the user immediately flagged it as wrong namespace. The instinct to create wrappers and helpers at L3 was solving the wrong problem — the question was whether L3 types should exist at all.

## Patterns and Root Causes

**Pattern: tactical work masks architectural questions.** The swift-kernel HANDOFF framed the work as "type upgrade pass" — replace raw Int/UInt32 with typed wrappers. This was accurate for the L1 types but obscured a deeper question: why does L3 have a `Kernel.Completion.IOUring` namespace with a Ring class at all? The handoff's tactical framing led to 90 minutes of API surface exploration before the architecture question surfaced.

This is the same pattern as "premature optimization" but for abstraction: premature implementation of a design that hasn't been validated. The L3 Ring class existed because the L1 Uring was a separate type from the ring. Now that L1 Uring IS the ring, the L3 wrapper's reason for existing dissolved — but the code remained, and the handoff described upgrading it rather than questioning it.

**The ~Copyable shared state problem is the real design constraint.** The Driver witness has 4 closures that share mutable access to `Kernel.IO.Uring` (which is ~Copyable). A class provides reference semantics. The question is whether this class needs to be a named L3 type or can be structured differently (anonymous class in factory, Uring stored on Completion itself, single closure instead of 4, redesigned Driver).

## Action Items

- [ ] **[research]** swift-kernel: What does the ideal witness-based Completion API look like without platform-specific L3 types? (Handoff written to `swift-kernel/HANDOFF.md`)
- [ ] **[skill]** handoff: Consider adding a "verify architecture before implementing" checkpoint when a handoff describes upgrading code that wraps a recently-refactored lower layer
- [ ] **[package]** swift-kernel: Readiness → Event rename needs a naming collision resolution — L1 `Kernel.Event` (data type) vs L3 `Kernel.Event` (resource)
