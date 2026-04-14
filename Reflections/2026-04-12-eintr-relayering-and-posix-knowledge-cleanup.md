---
date: 2026-04-12
session_objective: Implement EINTR wrappers for read/accept and resolve structural layering of isInterrupted across L1-L3
packages:
  - swift-kernel-primitives
  - swift-iso-9945
  - swift-posix
  - swift-darwin-standard
  - swift-linux-standard
status: processed
---

# EINTR Relayering — POSIX Knowledge Out of L1

## What Happened

Started from a handoff targeting EINTR wrappers for read/pread/accept/send/recv. During implementation, the user questioned whether `code.posix == 4` (EINTR check) belonged at L1. Loading `/platform` confirmed it violated [PLAT-ARCH-008c]: platform-specific behavior must live in platform packages as extensions on lower-layer types.

This led to a structural redesign. Instead of scattered `isInterrupted` properties on each error type at L1, the session converged on **one definition on `Kernel.Error.Code` at L2**, with L3 using `error.code.isInterrupted`. The composition is self-documenting: "the error's code represents an interruption."

Secondary findings:
- **Lock.Error had a platform bug**: EAGAIN (Darwin=35, Linux=11) and EDEADLK (Darwin=11, Linux=35) have swapped values. The hardcoded switch gave wrong semantics on Darwin — lock contention mapped to `.deadlock` and vice versa. Fixed with platform-specific named constants.
- **`init(posixErrno:)` at L1**: Found on Handle.Error (dead code — deleted), Copy.Error (relocated to L2 platform packages), and Stats.Error (already at L2). All instances replaced magic numbers with platform errno constants.
- **Either-based error composition**: User identified that `Either<DomainError, Kernel.Interrupt>` with typed throws is the correct pattern for cross-cutting concerns, not adding `.interrupted` cases to domain error enums and not using `Kernel.Outcome`.

## What Worked and What Didn't

**Worked**: The `/platform` skill provided the exact framework needed to evaluate the layering question. [PLAT-ARCH-008c] directly answered "is this correct at L1?" The exploration agents found `Kernel.Interrupt` and `Kernel.Outcome` at L1 — infrastructure that already modeled interruption as a cross-cutting concern, validating the relocation.

**Worked**: The "one definition on `Kernel.Error.Code`" design eliminated per-error-type convenience extensions entirely. Every error type that has `code` (structural, at L1) gets `isInterrupted` (semantic, at L2) for free. No new code needed per error type.

**Didn't work well**: The Copy.Error relocation initially targeted ISO 9945 Kernel File, but neither Darwin Standard nor Linux Standard's copy targets depend on it. Adding ISO 9945 as a dependency to both would have been heavy. Pivoted to per-platform `internal` extensions — some duplication, but no dependency graph changes.

**Surprise**: The Lock.Error EAGAIN/EDEADLK swap was a genuine runtime bug, not cosmetic. The cross-platform helper pattern (`isEDEADLK`) turned out to be impossible — EAGAIN and EDEADLK share the same two values (11, 35), making a multi-platform matcher ambiguous. Only platform-specific named constants work.

## Patterns and Root Causes

**Pattern: Magic numbers as platform debt**. Every hardcoded errno value at L1 is an implicit platform assumption. The named constants infrastructure (`Kernel.Error.Code.POSIX.EBADF`, `isEAGAIN()`, etc.) exists precisely to encapsulate platform variance, but several error types predated it and used raw numbers. This session showed that the debt isn't just stylistic — Lock.Error had incorrect semantics because EAGAIN/EDEADLK values are swapped between Darwin and Linux.

**Pattern: Cross-platform helpers only work for non-colliding errno values**. EAGAIN and EDEADLK share values {11, 35} with different meanings per platform. A cross-platform `isEDEADLK()` would be indistinguishable from `isEAGAIN()`. The correct approach for colliding values is equality against platform-specific named constants (`code == Kernel.Error.Code.POSIX.EAGAIN`), which resolves at compile time. This is a hard constraint on the helper pattern.

**Pattern: L1 error types should have `code` but not semantic interpretation**. The `code` property is structural (switch over cases, extract the underlying code). The `isInterrupted` property is semantic (POSIX 4 means "interrupted by signal"). The structural accessor belongs at L1; the semantic interpretation belongs at L2. This mirrors the shell + values pattern [PLAT-ARCH-013] applied to error types.

## Action Items

- [ ] **[skill]** platform: Add guidance on errno collision handling — cross-platform helpers cannot be used when two errno constants share the same numeric values across platforms (EAGAIN/EDEADLK). Document that platform-specific named constants via equality are the only correct approach for colliding values.
- [ ] **[package]** swift-kernel-primitives: Audit remaining L1 error types for hardcoded magic numbers — `Kernel.IO.Blocking.Error`, `Kernel.IO.Error`, `Kernel.Descriptor.Validity.Error` all have `init?(code:)` initializers that may use raw numbers instead of named constants.
- [ ] **[research]** Either-based error composition: Design `throws(Either<Handle.Error, Kernel.Interrupt>)` pattern end-to-end — how does the L3 EINTR retry wrapper compose with Either? What does the consumer call site look like? Does `Either: Error` work seamlessly with `catch where` patterns?
