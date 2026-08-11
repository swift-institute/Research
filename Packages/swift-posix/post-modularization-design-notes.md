# Post-Modularization Design Notes

Date: 2026-04-10

These are investigation results for design questions raised during the ISO 9945 + swift-posix modularization.

---

## 1. Linux Namespace Ownership (Item 7)

**Status: Low risk, no action needed now.**

L3 (`swift-linux`) uses `public typealias Linux = Linux_Kernel_System_Standard.Linux` — a typealias to L2's `public enum Linux`. L3 extends the namespace with new types (`Linux.Thread`, `Linux.Random`) that don't exist in L2. No conflict.

**Risk trigger:** If L3 ever needs to wrap an existing L2 type with policy (e.g., `Linux.Memory` with allocation policy), the same type-definition conflict as POSIX will occur. At that point, L3 would need its own `public enum Linux {}`.

**Difference from POSIX:** POSIX hit this immediately because L3 needed `POSIX.Kernel.File.Flush` (wrapping L2's `ISO_9945.Kernel.File.Flush`). Linux L3 currently only adds new domains, not wrapping existing ones.

**Action:** Monitor. No preemptive rename of L2 to `Linux_Standard` needed — that would be premature disruption.

---

## 2. POSIX Namespace Depth (Item 8)

**Status: Not a real problem.**

`POSIX.Kernel.IO.Write.writeAll()` is 5 levels deep. Investigation of actual consumers shows:

- **swift-file-system** (the primary consumer) uses L1/L2 directly: `Kernel.IO.Write.write(fd, from: buffer)` — 4 levels
- **L3 policy wrappers** are opt-in. A consumer that wants EINTR retry accepts the extra level as an explicit signal
- **No call sites** were found in the codebase actually using the 5-level `POSIX.Kernel.*` path outside of documentation

Shorter access paths (`POSIX.write(...)`) would:
- Pollute the `POSIX` namespace with flat method names
- Lose the semantic grouping by domain
- Sacrifice self-documentation for marginal convenience

**Decision:** Keep the 5-level path. The depth is intentional and consumers that need L3 accept it.

---

## 3. strerror Layering (Item 9)

**Status: Should move to L2.**

`strerror()` is a POSIX.1 spec-defined function (ISO 9945). Currently, `Kernel.Error.Code.posixMessage` in L3 (`POSIX Core`) calls `strerror()` directly via `import Darwin`/`import Glibc`. This bypasses L2.

**Rationale for L2:** L2 mirrors the specification faithfully. `strerror()` is not policy — it's a specified mapping from error code to message string. It belongs alongside `captureErrno()` in `ISO 9945 Core`.

**Implementation:**
1. Move `posixMessage` property to `ISO 9945 Core` (file: `ISO 9945.Kernel.Error.Code+message.swift`)
2. Remove the implementation from `POSIX Core`
3. L3 gets the property for free via `@_exported public import ISO_9945_Core` in `POSIX Core/exports.swift`

**Impact:** Zero consumer-visible change. The property exists on the same type (`Kernel.Error.Code`), just provided at L2 instead of L3.

---

## 4. EINTR Coverage Expansion (Item 10)

**Current state:** Only flush and write have EINTR retry wrappers at L3.

**Prioritization by consumer frequency and risk:**

| Priority | Syscall | Domain Target | Rationale |
|----------|---------|---------------|-----------|
| P0 | `read`, `pread` | POSIX Kernel File | Symmetric with write; swift-file-system uses directly |
| P0 | `close` | POSIX Kernel File | EINTR on close is a notorious POSIX pitfall (Linux vs other platforms disagree on fd state after EINTR) |
| P1 | `accept` | POSIX Kernel Socket | Network servers hit EINTR on accept in signal-heavy environments |
| P1 | `connect` | POSIX Kernel Socket | Interrupted connect needs careful restart logic |
| P1 | `send`, `recv` | POSIX Kernel Socket | Network I/O — same pattern as read/write |
| P2 | `poll` | POSIX Kernel File or Socket | Event loop foundation — EINTR is the normal case in signal handlers |
| P2 | `flock` | POSIX Kernel Lock | Advisory locking under signals |
| P3 | `waitpid` | POSIX Kernel Process | Child reaping under signal handlers |
| P3 | `nanosleep` | POSIX Kernel System | Sleep interrupted by signals — needs remaining-time handling |

**Note on `close` EINTR:** This is a platform-divergent edge case. On Linux, `close` always closes the fd regardless of EINTR return. On other POSIX systems, the fd state after EINTR is unspecified. The L3 policy wrapper for close needs platform-specific behavior — this is genuine L3 value-add, not just a retry loop.

**Each EINTR wrapper populates one of the 10 currently-empty re-export targets** (Item 11). The empty targets are growth scaffolding awaiting these wrappers.

---

## Relation to Handoff Items

| Handoff Item | Status | Document |
|--------------|--------|----------|
| 6. ISO 9945 System decomposition | Investigated → split recommended | `swift-iso-9945/Research/system-decomposition.md` |
| 7. Linux namespace ownership | Investigated → low risk, monitor | This document §1 |
| 8. POSIX namespace depth | Investigated → not a problem | This document §2 |
| 9. strerror layering | Investigated → move to L2 | This document §3 |
| 10. EINTR coverage expansion | Prioritized | This document §4 |
| 11. Empty POSIX targets | Depends on #10 | This document §4 (last paragraph) |
