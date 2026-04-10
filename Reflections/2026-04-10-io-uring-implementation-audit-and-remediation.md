---
date: 2026-04-10
session_objective: Research io_uring spec, audit existing implementation, remediate all findings, establish semantic flag modeling, L2 reclassification, platform skill update
packages:
  - swift-linux-standard (was swift-linux-primitives)
  - swift-kernel-primitives
  - swift-cpu-primitives
  - swift-iso-9945
  - swift-darwin-standard
  - swift-windows-standard
  - swift-x86-standard
  - swift-arm-standard
  - swift-riscv-standard
status: pending
---

# IO Uring Implementation Audit, Remediation, and Semantic Flag Modeling

## What Happened

Session began with researching the Linux io_uring specification from kernel sources, man pages, and authoritative references. Produced 7 research documents: API reference (spec), 4 implementation studies (Zig stdlib, TigerBeetle, Rust io-uring, liburing), Swift feature inventory mapping 14 io_uring concerns to existing ecosystem research/experiments, and an L1 API audit.

The audit discovered the existing `Kernel.IO.Uring` implementation (72 files, 6171 lines) was **architecturally sound** (namespace, ~Copyable ring, typed throws, ecosystem types) but had two P0 correctness bugs (missing atomics on ring head/tail, no sqe_head/sqe_tail batch amortization) and numerous convention issues (raw C types in public API, magic numbers, duplicate types).

Remediation produced 6 commits:
1. **Atomics + batch flush + SINGLE_MMAP** — fixed ARM64 data race via CPU.Atomic from swift-cpu-primitives; implemented sqe_head/sqe_tail split with single atomic store-release per batch; added SINGLE_MMAP feature check to prevent double-munmap
2. **OptionSet types for all 29 raw flags** — created 13 typed OptionSets + Vector wrapper for iovec
3. **.Flags → .Options rename** — new ecosystem convention for OptionSet naming
4. **Semantic decomposition** — timeout (clock enum + overloads), poll (trigger enum + events), fallocate (mode enum with associated values), xattr (disposition enum)
5. **Move types to correct owners** — MSG_* → Kernel.Socket.Message.Options, AT_* → Kernel.File.At.Options, SPLICE_F_* → Kernel.Pipe.Splice.Options, etc. Deleted 6 io_uring duplicate files
6. **Cross-package ecosystem rename** — 10 types renamed from .Flags to .Options across kernel-primitives + linux-primitives; openat Access decomposition; poll Events typing

## What Worked and What Didn't

**Worked well:**
- The four-implementation-study approach (Zig, TigerBeetle, Rust, liburing) gave unanimous agreement on memory ordering — all four use identical acquire/release patterns. This unanimity gave high confidence in the fix.
- The existing `CPU.Atomic` infrastructure in swift-cpu-primitives was exactly what we needed — load(.acquiring), store(.releasing), and the barrier. Zero new C code required.
- The `Target` enum (descriptor/registered/allocate) was better than any reference implementation's approach — compiler-enforced fd/index discrimination.
- Parallelizing subagents for independent file edits (different packages, different files) worked efficiently.

**Didn't work well:**
- The initial impulse was to add atomic C shim functions to CLinuxKernelShim. The user correctly identified this as architecturally wrong — C11 atomics are CPU-level, not Linux-specific. This led to using the existing CPU Primitives instead. **Lesson: always check existing infrastructure before creating new code.**
- The first Prepare file typed with OptionSets had to be partially undone — the OptionSet model was wrong for mutually exclusive choices (timeout clock, fallocate mode, xattr disposition). We created OptionSets, then deleted them and created enums. **Lesson: model the semantics first, then choose the Swift type. Don't default to OptionSet for everything the kernel calls "flags."**
- Agent work sometimes needed correction — one agent doing edits one-by-one (per static constant) instead of using replace_all; another missed the Wait.Options wiring. Review caught both.

## Patterns and Root Causes

**Pattern 1: "io_uring is a submission mechanism, not a domain owner"**

This was the key architectural insight. The io_uring SQE is a transport format — it accepts socket operations but doesn't own socket types, accepts file operations but doesn't own file types. We initially created 20+ types in the io_uring namespace. After analysis, io_uring correctly owns only ~7 types (Clock, Poll.Trigger, Message.Options, Fixed.Install.Options, Target, Vector, Wait.Options). Everything else references the owning domain.

This principle applies beyond io_uring: any submission/dispatch mechanism (epoll, kqueue, IOCP) should reference domain types, not define them.

**Pattern 2: "OptionSet is for genuinely combinable flags; enum is for mutually exclusive choices"**

The kernel uses a single `__u32 flags` field for everything. But "flags" in the kernel sense conflates two concepts: (1) independent options that combine via bitwise OR, and (2) mutually exclusive selections encoded as non-overlapping bit patterns. Swift can distinguish these at compile time — OptionSet for (1), enum for (2). The semantic decomposition reduced the invalid-combination surface from 5 flag sets to zero.

**Pattern 3: "Check rawValue type at the boundary"**

POSIX syscalls use `int` (Int32). The io_uring SQE packs everything into `__u32` (UInt32). The ecosystem types correctly use the POSIX type (Int32). The boundary conversion `UInt32(bitPattern:)` lives inside the prep method — exactly where [IMPL-010] says it should. This came up three times (File.At.Options, Pipe.Options, open flags) and was the same fix each time.

**Pattern 4: "L1 vocabulary / L2 spec / L3 composition"**

The io_uring implementation exposed that platform packages (linux-primitives, darwin-primitives, etc.) answer "what is specified externally?" — the L2 question, not "what must exist?" (L1). This led to reclassifying all 6 platform/ISA packages from L1 to L2, with dedicated GitHub organizations. The shell+values workaround (empty OptionSets in L1 so L1 could avoid L2 dependency) was a dependency-inversion smell from the misclassification.

**Pattern 5: "Shell + values for universal concepts, direct definition for POSIX-only"**

Shell type audit revealed: genuinely cross-platform concepts (Socket.Options, File.Open.Options — used on Linux, Darwin, AND Windows) correctly use the shell pattern. POSIX-only concepts (File.At.Options, Memory.Lock.All.Options, Memory.Map.Sync.Options — no Windows equivalent) were incorrectly shelled in L1 and moved to iso-9945.

## Action Items

- [x] **[skill]** platform: Added [PLAT-ARCH-012] vocabulary/spec/composition principle, [PLAT-ARCH-013] shell+values pattern with boolean init, [PLAT-ARCH-014] ISA standard packages. Updated [PLAT-ARCH-010] package reference table. Commit bba321e.
- [ ] **[skill]** implementation: Add guidance that OptionSet is only correct for genuinely combinable flags. When flags encode mutually exclusive choices, use enum (possibly with associated values). Reference the timeout/fallocate/xattr decompositions as examples.
- [ ] **[skill]** code-surface: Document the `.Options` naming convention for OptionSet types (replacing `.Flags`). Reference [IMPL-INTENT] — Options reads as intent, Flags as mechanism.
