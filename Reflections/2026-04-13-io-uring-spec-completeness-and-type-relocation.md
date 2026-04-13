---
date: 2026-04-13
session_objective: Audit io_uring implementation against kernel 6.12 spec for completeness and module placement, then close all gaps
packages:
  - swift-linux-standard
  - swift-iso-9945
status: pending
---

# io_uring Spec Completeness Audit, Type Relocation, and Gap Closure

## What Happened

Resumed from a handoff (`HANDOFF.md`) targeting two questions: (1) does our io_uring implementation cover the full Linux kernel 6.12 `io_uring.h` interface, and (2) are all 88 types in the right module?

**Spec audit** found opcodes at 100% but significant gaps in flags and register operations. Register ops were at 39% (12/31). Recv/send flags, accept flags, SQ/CQ ring flags were at 0%. Fetched the kernel 6.12 header via WebFetch and systematically compared every constant.

**Module placement** identified 3 types over-nested in io_uring that belong elsewhere:
- `Priority` → `Kernel.IO.Priority` in `Linux Kernel IO Standard` (ioprio is block I/O subsystem, not io_uring)
- `Vector` → `ISO_9945.Kernel.IO.Vector.Segment` in swift-iso-9945 (iovec is POSIX)
- `Timeout.Specification` → `Linux.Kernel.Time.Specification` in `Linux Kernel System Standard` (__kernel_timespec is general Linux)

All three relocations were implemented and verified (Docker swift:6.3, 260 tests pass).

**Gap closure** was planned in 4 phases and executed autonomously overnight:
1. Phase 1: 13 missing flags on 6 existing OptionSet types
2. Phase 2: 5 new flag types (Socket.Transfer.Options, Accept.Options, SQ/CQ Queue.Options, Ring.Command.Options) + breaking change on zero-copy send prepare methods
3. Phase 3: 19 missing register operations via nested accessors
4. Phase 4: Remaining constants (Nop.Options, Restriction.Kind, Socket.Command, Message.Kind, mmap offsets, splice flag, speculative opcode annotations)

**Post-closure review** found 12 issues (1 critical, 7 high). All fixed:
- Critical: `Register.Rings.enable` had rawValue 11 instead of kernel's 12 — pre-existing bug exposed by adding `Register.Restriction.register` (correctly 11)
- 7 [API-IMPL-005] violations: nested types in parent files, extracted to own files
- `Register.Opcode.sparse` was semantically wrong (resource flag, not opcode)
- Priority body had statics and operator; Socket.Command init missing `@inlinable`

Final state: 109 source files, 260 tests, 9 commits across 2 repos.

## What Worked and What Didn't

**Worked well:**
- Fetching the kernel header via WebFetch produced a complete, structured reference. The systematic table-driven comparison caught everything.
- The 4-phase plan with build/test/commit after each phase kept the repo buildable throughout.
- The post-closure self-review caught real issues — the `enable` rawValue bug is a correctness defect that would have caused wrong register operations at runtime.

**Didn't work well:**
- I initially claimed `Kernel.Time` being a typealias "blocks" nesting. The user corrected me — Swift extensions on typealiases resolve to the underlying type. This was a fundamental Swift knowledge gap that nearly caused me to skip the Timeout.Specification relocation.
- The first plan draft had compound type names (`SyncCancel`, `FileAlloc`, `ProvidedBuffers`) and unexpanded abbreviations (`Fd`, `Sq`, `Buf`). The user pushed back twice before the plan met convention standards. I should have loaded the skill requirements more carefully before naming.
- Seven [API-IMPL-005] violations in my own code — I knew the one-type-per-file rule but habitually nested sub-namespace types inside parent files. The rule is clear; I ignored it under time pressure during overnight implementation.

## Patterns and Root Causes

**The "namespace needs a file" blind spot.** When creating `Register.Worker` with nested `Affinity` and `Kind`, the instinct was to keep them together because they're conceptually one unit. But [API-IMPL-005] is mechanical, not conceptual — it's about file granularity for navigation and merge conflicts, not about conceptual coupling. The systematic violation across 7 files shows this is a habit, not a one-off. Root cause: treating the file structure as a documentation tool rather than an engineering constraint.

**Abbreviation expansion requires active discipline.** The kernel uses `FD`, `SQ`, `CQ`, `BUF`, `MMAP`. Our ecosystem expands these (`Descriptor`, `Submission`, `Completion`, `Buffer`, `MemoryMap`). When transcribing quickly, the kernel abbreviations leak through. The fix isn't "try harder" — it's to establish the expansion as the default and treat any abbreviation as requiring justification.

**Pre-existing bugs surface during completeness work.** The `Rings.enable` rawValue 11→12 bug existed before this session. It only became visible because adding `Restriction.register` (correctly 11) created a collision. This validates the spec audit approach: systematic comparison against the source catches latent errors, not just omissions.

## Action Items

- [ ] **[skill]** implementation: Add guidance that [API-IMPL-005] applies to namespace enums/structs — even empty ones get their own file. The "one type per file" rule includes zero-stored-property namespace types.
- [ ] **[skill]** code-surface: Expand [API-NAME-002] spec-mirroring exception guidance to explicitly state that kernel abbreviations (FD, SQ, CQ, BUF) must be expanded to ecosystem vocabulary (Descriptor, Submission, Completion, Buffer) — spec-mirroring covers the semantic structure, not the abbreviation.
- [ ] **[package]** swift-linux-standard: The Domain Modelling audit (2026-04-09) has 26 OPEN findings about raw UInt32 in ring stored properties and public API parameters. These are the next priority for io_uring quality — the ring has no typed domain model.
