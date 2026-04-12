---
date: 2026-04-12
session_objective: Research ISO 9945 spec gaps and implement missing POSIX modules
packages:
  - swift-iso-9945
  - swift-linux-standard
status: pending
---

# ISO 9945 POSIX Gap Analysis and Implementation

## What Happened

Session spanned 2026-04-10 through 2026-04-12. Started with a gap analysis of swift-iso-9945 against the full IEEE 1003.1-2024 specification, then shifted to implementation and cross-package migration.

**Research phase**: Created `iso-9945-spec-coverage-gap-analysis.md` — a Tier 2 Discovery research document comparing ~120 existing POSIX function wrappers against the ~400+ system interfaces in the spec. Identified the package was at ~30% coverage with massive gaps in sockets (15%), I/O multiplexing (0%), and user/group identity (0%).

**Implementation phase** (13 commits across two repos):

*swift-iso-9945*:
- Created `ISO 9945 Kernel Socket Address` target — 8 files, cross-platform socket address types (Family, Storage, IPv4, IPv6, Unix, Kind)
- Expanded `ISO 9945 Kernel Socket` from 6 to 22 files — full lifecycle (create/bind/listen/accept/connect), I/O (send/recv/sendmsg/recvmsg), name queries, options, message headers
- Created `ISO 9945 Kernel Poll` target — 5 files, poll(2) wrapper
- Created `ISO 9945 Kernel Identity` target — 11 files, user/group IDs, passwd/group database lookup
- Added `Process.Wait.Kind` + waitid options to Process target
- Added `IO.Vector` (readv/writev) and `File.Truncate` to File target
- Code-surface compliance fix: split multi-type files, renamed compound identifiers

*swift-linux-standard*:
- Deleted 14 files (-824 lines) of duplicate POSIX types
- Re-exported ISO 9945 types through Socket Standard and System Standard
- Verified full Linux build via Docker (Swift 6.3) including io_uring consumer

**Discovery**: The Darwin layer (swift-darwin-standard, swift-posix, swift-darwin) was already clean — it never had duplicate POSIX types because it was built later and went through swift-posix from the start.

## What Worked and What Didn't

**Worked well**:
- The gap analysis as a structured research document was valuable — it gave clear priority ordering and prevented scope creep during implementation
- Migrating types from swift-linux-standard to ISO 9945 was mostly mechanical once the cross-platform import pattern was established
- The `withUnsafeBytes`/`withUnsafeMutableBytes` API on Storage was the right solution for cross-target sockaddr access — avoids exposing C types in public API while being ergonomic

**Didn't work well**:
- The gap analysis initially listed `mprotect` as missing — it already existed at `Map.swift:117`. The analysis was done by an agent that read file inventories but missed functions within existing files. Lesson: gap analysis for functions-within-files requires grepping, not just file listing
- Socket.Kind used `Int32(SOCK_STREAM)` which worked on Darwin but failed on Linux where Glibc wraps SOCK_STREAM as `__socket_type` (a C enum). Caught only via Docker Linux build. Cross-platform types need Linux build verification, not just macOS
- First attempt at the Identity target used `User.ID` as a namespace enum, shadowing the L1 `typealias ID = Tagged<User, UInt32>`. Had to restructure to `User.Real`/`User.Effective` namespaces. Lesson: check L1 namespace occupancy before creating L2 namespaces

**Code-surface compliance**: Initial implementation had 9 naming violations (compound identifiers like `sendTo`, `setReuseAddress`, `realID`) and 5 one-type-per-file violations. These were caught and fixed in a dedicated compliance pass. The violations were predictable — they happened where I was moving fast without the skill loaded.

## Patterns and Root Causes

**Pattern: specification-driven gap analysis works well as a research artifact but imperfectly as a function-level inventory.** The analysis correctly identified missing *domains* (sockets, poll, identity) and new *targets* needed. It incorrectly assessed function-level presence/absence within existing targets (mprotect false positive). The right granularity for gap analysis is target-level, with per-function verification deferred to implementation time.

**Pattern: cross-platform C type differences are invisible until you build on the target platform.** Glibc's `__socket_type` enum wrapper for SOCK_STREAM, the different sizes of `msg_iovlen`/`msg_controllen` between Darwin and Linux msghdr — these are the kinds of issues that only surface in a Linux build. The Docker verification step should be standard for any cross-platform ISO 9945 work.

**Pattern: Nest.Name namespace collisions with L1 typealiases.** When L1 defines `Kernel.User.ID` as a `typealias` for `Tagged<User, UInt32>`, L2 cannot create `extension Kernel.User { enum ID {} }` — the names collide. The fix was `User.Real`/`User.Effective` instead of `User.ID.real`/`User.ID.effective`. This is a structural consequence of Tagged typealiases occupying the namespace slot that would otherwise hold a namespace enum.

## Action Items

- [ ] **[skill]** implementation: Add guidance for Docker Linux build verification when writing cross-platform C wrapper types. The `__socket_type` enum and msghdr field type differences are representative of a class of issues invisible to macOS-only builds.
- [ ] **[package]** swift-iso-9945: Socket.Protocol type (IPPROTO_TCP/UDP/RAW) still lives in swift-linux-standard as a Linux-only type. Should migrate to ISO 9945 alongside Socket.Kind — it's POSIX, not Linux-specific.
- [ ] **[research]** Investigate whether the Shutdown.Mode type in swift-linux-standard duplicates the Shutdown.How type at L1. If so, migrate or unify.
