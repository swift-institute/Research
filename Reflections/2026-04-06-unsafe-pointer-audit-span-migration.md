---
date: 2026-04-06
session_objective: Audit and reduce unsafe pointer usage across the IO read/write data path
packages:
  - swift-io
  - swift-iso-9945
  - swift-ownership-primitives
status: pending
---

# Unsafe Pointer Audit — Span Migration Eliminates 18 Sites

## What Happened

Started from HANDOFF-unsafe-pointer-audit.md, which defined two investigation tracks: (1) push Channel.read/write to Span/MutableSpan, and (2) explore typed alternatives to Ownership.Transfer.Box raw pointer boxing.

Track 1 investigation discovered three key facts: the kernel layer (ISO 9945) already provides Span overloads for read/write, Swift 6.3 supports ~Escapable parameters across async suspension points (proven by existing Tier 0 code), and `Span.extracting(droppingFirst:)` solves the partial-write slicing problem. All three findings pointed to feasibility with no blockers.

Implemented Track 1: changed Channel.Reader.read to accept `inout MutableSpan<UInt8>`, Channel.Writer.write to accept `Span<UInt8>`, and the unsplit Channel equivalents. Updated IO.Stream, IO.Reader, IO.Writer callers — each went from multiple `unsafe` sites to zero. Converted all test call sites from manual `UnsafeMutableRawBufferPointer.allocate` to `Array<UInt8>` with `.span`/`.mutableSpan`. Build clean, 381 tests pass.

Track 2 investigation concluded that Ownership.Transfer.Box is optimal and irreducible. The raw pointer serves type erasure (not thread transfer — `sending` handles that). Alternatives (AnyObject, Any, generic Lane) all have worse trade-offs.

Added a REVALIDATION file for the TemporaryPointers workaround in the Shutdown view types.

## What Worked and What Didn't

**Worked well**: The investigation-first approach. Reading all relevant files before proposing changes revealed that the kernel Span overloads already existed — the migration was pulling an existing API up through the stack, not designing a new one. High confidence throughout.

**Worked well**: The `extracting(droppingFirst:)` discovery. The write-all partial retry loop was the case I expected to be hardest (raw pointer arithmetic for offset slicing). Finding that Span has a stdlib method for exactly this pattern turned the hardest case into the cleanest.

**Worked well**: Test conversion to Array + .span/.mutableSpan was mechanical and produced cleaner test code — no manual allocate/deallocate, no defer blocks, no `unsafe` in tests.

**Minor friction**: Three test files needed updates, not just the two initially expected. The Selector.Iteration.Tests file also called Channel.read/write directly. Caught by the build — no runtime risk.

## Patterns and Root Causes

**Span as the async-safe view type**: The key insight is that Swift 6.3 already supports ~Escapable function parameters surviving across async suspension points. The existing `IO.Stream.write(all: Span<UInt8>) async` proved this — the Span parameter is used across `try await channel.write()`. This means ~Escapable types are more capable in async contexts than I initially assumed. The limitation is on *storing* ~Escapable values in escaping contexts (class fields, closure captures), not on using them as function parameters in async functions.

**Type erasure vs thread transfer — orthogonal concerns**: Track 2's conclusion is worth internalizing as a general pattern. `sending` solves cross-isolation transfer. Raw pointers solve type erasure. They address different problems. When evaluating whether unsafe can be removed, identify WHICH concern the pointer serves. Transfer concerns can use `sending`. Erasure concerns require language-level features that don't exist yet (move-only existentials, consuming boxes).

**REVALIDATION as institutional memory**: The TemporaryPointers workaround is the kind of thing that silently persists forever without a tracking mechanism. The REVALIDATION file pattern names the exact test to run on a new toolchain. Worth applying to any workaround that has a concrete "try this again when X ships" condition.

## Action Items

- [ ] **[skill]** memory-safety: Add guidance that ~Escapable types (Span, MutableSpan) can be function parameters in async methods and survive across suspension points — this is a common misconception
- [ ] **[package]** swift-io: Audit whether any downstream transport libraries (TLS, HTTP layers) still call Channel read/write with raw pointers — they now get the Span API
- [ ] **[research]** Can the TemporaryPointers workaround in Shutdown views be eliminated with a different ~Escapable view design that avoids UnsafeMutablePointer entirely?
