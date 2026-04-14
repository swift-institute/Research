---
date: 2026-04-08
session_objective: Validate io_uring eventfd integration path, create Kernel.Completion types, begin IOUring backend
packages:
  - swift-kernel-primitives
  - swift-kernel
  - swift-io
  - swift-iso-9945
  - swift-linux-primitives
  - swift-linux
status: processed
---

# io_uring Integration Foundation — Architecture Validated, Type Design Iterated

## What Happened

Session started from the swift-io HANDOFF.md targeting the eventfd integration experiment (prerequisite 1 for io_uring integration). Before the experiment could run, we discovered the Linux build chain was broken — swift-iso-9945 had an undeclared `Binary_Primitives` dependency that failed on Linux but resolved transitively on Darwin. Fixed. Verified the full L1→L3 chain builds on Linux via Docker (`swift:6.3` + `uuid-dev`).

The eventfd experiment validated the single-thread architecture: io_uring completions discovered via eventfd registered with epoll, 100K NOPs in 13ms. MPSC + SINGLE_ISSUER submission path resolved by architecture constraint (Loop is SerialExecutor, SQ ring thread-confined).

Created `Kernel.Completion` + `Kernel.Completion.Driver` types. Iterated through three design rounds:
1. First version: Sendable with @Sendable closures — rejected (forces @unchecked on captured ring state)
2. Second version: non-Sendable, `sending` transfer — correct isolation, but raw Int32/UInt64 in Submission/Event
3. Third version (by second agent): typed wrappers via Tagged + custom structs, borrowing Kernel.Descriptor for target fd

Moved Completion types to L1 (`Kernel Completion Primitives` target in swift-kernel-primitives) to break circular dependency — swift-linux can't depend on swift-kernel. Extracted `Kernel.Wakeup.Channel` to `Kernel Primitives Core` (shared by Readiness + Completion), replaced `Kernel.Readiness.Wakeup.Channel` throughout — no typealias, direct usage.

IOUring backend attempted twice. First version deleted (raw Int types, compiler bug with ~Copyable deferred init). Second version (by second agent) written with proper typed API, Ring class encapsulating mechanism, prepare methods with borrowed descriptors. Pending Linux build verification.

## What Worked and What Didn't

**Worked**: The review-prompt pattern. Writing inline review prompts for a second agent produced three rounds of actionable feedback (harvest deadline, bufferGroup, Sendable removal, typed wrappers, borrowing target fd). Each round caught real issues the implementation agent missed.

**Worked**: Docker verification before writing backend code. The Linux build chain breakages (Binary_Primitives, uuid-dev) were found and fixed before they could block the io_uring work.

**Didn't work**: Writing the IOUring backend before finalizing the Submission/Event types. The first backend was deleted because raw Int types violated [IMPL-002]. The correct order: type design first (per [IMPL-000] call-site-first), then backend.

**Didn't work**: Assuming `Kernel.Descriptor(_rawValue:)` was acceptable for temporary non-owning references. The user caught this — the prepare methods take `borrowing Kernel.Descriptor`, so the submit closure should too. The Submission shouldn't store a descriptor at all.

## Patterns and Root Causes

**Pattern: Type design drives API shape.** The Submission type went through three iterations. Each iteration changed the Driver closure signatures, which changed the backend implementation. Settling the type design first would have avoided two rounds of rework. This is [IMPL-000] (call-site-first) applied to data types: define the typed value first, then write the code that fills it.

**Pattern: Raw values at boundaries are a design smell, not a necessity.** The initial justification for raw Int32 fd was "we're at the kernel boundary." But the epoll driver passes `borrowing Kernel.Descriptor` all the way to the prepare methods. The kernel boundary is INSIDE the prepare method (where `_rawValue` is extracted), not at the Driver closure interface. The typed boundary should be as deep as possible — [MEM-SAFE-020] isolation principle applied to type boundaries.

**Pattern: Transitive dependency resolution differs between platforms.** The Binary_Primitives import in swift-iso-9945 worked on Darwin but failed on Linux. SwiftPM's transitive resolution makes undeclared dependencies accidentally visible. Darwin builds are not sufficient verification — Linux Docker builds catch real dependency gaps.

## Action Items

- [ ] **[skill]** implementation: Add guidance that Submission/Event-style flat value types should be typed first (per [IMPL-000]) before writing backend code that fills them. The pattern: define the typed struct → define the Driver closure signatures → write the backend.
- [ ] **[skill]** platform: Add `uuid-dev` to the Docker build prerequisites documentation. The `swift:6.3` image doesn't include it; every Linux build of swift-linux-primitives needs it.
- [ ] **[package]** swift-linux-primitives: Consider splitting `CLinuxKernelShim` into UUID shim and syscall shim. The UUID header dependency (`<uuid/uuid.h>`) blocks all io_uring/epoll/eventfd compilation when `uuid-dev` is missing, even for code that doesn't use UUID.
