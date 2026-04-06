---
date: 2026-04-06
session_objective: Docker-based Linux verification of the epoll port across four repos
packages:
  - swift-linux-primitives
  - swift-linux
  - swift-iso-9945
  - swift-kernel
  - swift-io
status: pending
---

# Linux Docker Verification Exposes Cross-Repo Compilation Debt

## What Happened

Spun off from the parent epoll port session to verify Linux compilation via Docker. Set up `swift:6.3` container with bind-mounted Developer directory. The epoll-specific code (eventfd wrappers, epoll driver) was never reached — blocked by pre-existing compilation errors in never-compiled `#if canImport(Glibc)` code across three repos.

Fixed ~30 files across `swift-linux-primitives` (L1), `swift-linux` (L3), and `swift-iso-9945` (L2). Error categories: duplicate type declarations, stale module names (`Binary` → `Binary_Primitives_Core`), `Tagged.__unchecked` init pattern, `@_spi(Syscall)` for `~Copyable` `Kernel.Descriptor`, `borrowing`/`consuming` annotations, SwiftGlibc gaps (`sysinfo`, `DIR`, `dup3`, `statfs`), `MemberImportVisibility` missing imports, errno shadowing. Moved `Kernel.IO.Uring.isSupported` from L1 to L3 because `Kernel.Environment.get` is L2 POSIX.

Handed off at the `swift-iso-9945` layer with one remaining blocker (`dup3` — Linux extension misplaced in POSIX layer).

## What Worked and What Didn't

**Worked**: Iterative fix-rebuild-fix loop was effective — each Docker build revealed the next error layer. The `swift:6.3` image worked perfectly. Bind-mounting the entire Developer directory preserved all relative path dependencies.

**Didn't work**: Scope expanded far beyond the epoll port. The handoff anticipated fixing "compilation errors in the epoll code" but the actual blocker was never-compiled code across the entire Linux dependency chain. Each fix unmasked the next layer. The session fixed code in three repos and four architectural layers but never reached the epoll driver itself.

**Confidence gap**: Early on I used ad-hoc patterns (private `_errno` helper, manual whitespace trimming) instead of consulting the ecosystem. The user corrected twice — once for `trimming(where:)` from `Standard_Library_Extensions`, once for the errno module-qualification pattern. Loading `/platform`, `/implementation`, `/existing-infrastructure` should have been step one, not step three.

## Patterns and Root Causes

**Never-compiled code accumulates silently.** Every `#if canImport(Glibc)` block was written on Darwin, never cross-compiled, and contained errors invisible to CI (which uses `swift:6.2` → can't even parse `swift-tools-version: 6.3`). The fix is CI with `swift:6.3` on Linux, but the debt already exists across the entire platform stack.

**SwiftGlibc gaps are unpredictable.** Functions missing from SwiftGlibc (`sysinfo`, `dup3`, `statfs`, `pipe2` as module members, `DIR` as a type) have no obvious pattern. The C shim layer exists for this reason ([PATTERN-001]), but the code was written assuming SwiftGlibc would expose everything. Each gap requires a different fix: C shim wrapper, unqualified call, `OpaquePointer`, or `/proc` filesystem fallback.

**Ecosystem conventions prevent ad-hoc solutions.** When I tried `_errno()` helper functions or raw `getenv`, the user corrected to module-qualified constants and `Kernel.Environment.withValueBytes`. The conventions exist to keep the codebase uniform — short-cutting them creates inconsistency that's harder to fix later than doing it right initially.

**The platform stack works but demands discipline.** The L1→L2→L3 separation correctly predicted where `isSupported` belongs (L3, not L1) and where `dup3` belongs (linux-primitives, not iso-9945). When the architecture was followed, fixes were clean. When pre-existing code violated it (`dup3` in POSIX, `Darwin.ENOENT` without platform conditional), the fixes were harder.

## Action Items

- [ ] **[skill]** platform: Add guidance for SwiftGlibc gaps — document the C shim escalation path when a glibc function isn't in SwiftGlibc (check availability → unqualified call → C shim wrapper → /proc fallback)
- [ ] **[package]** swift-io: CI ymls must update `swift:6.2` → `swift:6.3` for Linux jobs to catch future Linux compilation errors
- [ ] **[research]** Cross-repo Linux compilation audit: systematically compile every `#if canImport(Glibc)` block rather than discovering errors incrementally through the dependency chain
