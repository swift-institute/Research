---
date: 2026-04-09
session_objective: Complete Kernel.IO.Uring refactor from handoff, apply audit fixes, then audit and refactor the io_uring domain model
packages:
  - swift-linux-primitives
  - swift-darwin-primitives
  - swift-system-primitives
  - swift-kernel-primitives
status: processed
---

# Kernel.Event Consolidation + io_uring Domain Model Refactor

## What Happened

Session started from `HANDOFF-kernel-event-consolidation.md` with Phases 0–2 complete. Completed the Uring enum→struct refactor (absorbing Ring), applied all audit findings from both Event.Poll and Event.Queue handoffs, then pivoted to a full domain model audit of the io_uring target against /implementation.

The audit revealed 26 findings (7 critical, 12 high) with a clear systemic pattern: the ecosystem had exactly the typed infrastructure io_uring needed (Cardinal, Ordinal, Memory.Address.Offset, Buffer.Ring.Header patterns) but it wasn't being used. The refactor replaced every public API parameter and return type with domain types — `Submission.Count`, `Completion.Count`, `Params.Features`, `System.Processor.ID`, `Duration`, `Memory.Address.Offset`, typed entry flags.

Added `System.Processor.ID = Tagged<System.Processor, Ordinal>` to system-primitives as the ordinal complement to the existing `System.Processor.Count` cardinal.

Hit three infrastructure gaps during implementation: (1) `MemberImportVisibility` requires explicit imports per-file — many files broke, (2) `CLinuxShim` was the wrong module name across 16+ files (should be `CLinuxKernelShim`), (3) `Memory Primitives Standard Library Integration` isn't re-exported through kernel-primitives, so typed `advanced(by: Memory.Address.Offset)` overloads aren't available to io_uring. Used `.vector.rawValue` with a WHY/WHEN TO REMOVE comment.

## What Worked and What Didn't

**Worked well**: The "adoption over invention" approach. Almost every audit finding was resolved by importing existing ecosystem types rather than creating new ones. Only `Params.Features` was genuinely new. The ecosystem's typed infrastructure (Cardinal, Ordinal, Tagged, Memory.Address.Offset) composed cleanly with io_uring's domain concepts.

**Worked well**: Docker verification after each commit caught real issues — nested type resolution (`Error`, `Counter`, `Self`), missing imports, C shim module names. These only manifest on Linux.

**Didn't work**: The nightly toolchain (`swiftlang/swift:nightly-main`) was 6.4-dev with stricter behavior than 6.3. Wasted several Docker cycles before discovering `swift:6.3` image exists. Should have started with the target toolchain.

**Didn't work**: The previous session's Musl fix (removing `Glibc.read` qualifier) introduced a method-shadowing bug on 6.3. The correct cross-platform pattern was already established in iso-9945 — module-qualified `Glibc.read`/`Musl.read` conditional. Should have checked the standards layer first.

## Patterns and Root Causes

**Pattern: ecosystem-first domain modelling eliminates most findings as corollaries.** The audit found 26 violations, but the actual type changes were ~8 types. Each ecosystem type adoption resolved multiple findings simultaneously. `Submission.Count` alone fixed 5 call sites. This validates [IMPL-060]'s "ecosystem dependencies over ad-hoc implementation" — the infrastructure exists, the cost is wiring it up.

**Pattern: MemberImportVisibility is the new compilation boundary.** Files that compiled via transitive imports now fail. Every file needs explicit imports. This is especially painful in platform packages where files were added incrementally across sessions without consistent import discipline. The umbrella target (`Kernel_Primitives`) masked this — removing it will surface hundreds of these.

**Pattern: the C library module name is a recurring cross-platform hazard.** `Glibc`/`Musl`/`Darwin` as module names for the same POSIX functions creates a three-way conditional at every syscall site. iso-9945 handles this at L2. L1 packages that call POSIX directly must replicate the pattern. This is structural friction that won't go away.

## Action Items

- [ ] **[package]** swift-kernel-primitives: Re-export `Memory Primitives Standard Library Integration` so downstream consumers get typed `advanced(by: Memory.Address.Offset)` overloads without `.vector.rawValue` extraction
- [ ] **[skill]** implementation: Add guidance for L1 POSIX call disambiguation — module-qualified `Glibc.read`/`Musl.read` conditional is the canonical pattern (matching iso-9945), not unqualified calls
- [ ] **[research]** Should the ecosystem provide a unified C library module name (e.g., `CLibrary.read`) that abstracts Glibc/Musl/Darwin at the import level? Current pattern requires 3-way `#if` at every syscall call site in L1
