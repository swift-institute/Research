---
date: 2026-04-04
session_objective: Fix MemberImportVisibility and import precision violations across swift-primitives to unblock downstream builds
packages:
  - swift-storage-primitives
  - swift-network-primitives
  - swift-terminal-primitives
  - swift-queue-primitives
  - swift-tree-primitives
  - swift-parser-primitives
  - swift-pool-primitives
  - swift-darwin-primitives
  - swift-kernel-primitives
status: processed
---

# MemberImportVisibility Cascade Remediation

## What Happened

Session spanned two days. Original objective: resume handoff C (narrowing Kernel Primitives umbrella in 5 platform packages). Completed network and terminal (simplest), then the user asked to fix pre-existing storage-primitives build errors that were blocking root `swift build`.

Fixing storage exposed queue errors (package-access inits). Fixing queue exposed tree errors (missing Queue Dynamic import). A clean root build then exposed parser errors (Array shadowing). Each fix unlocked the next layer. Total: 9 packages touched, ~80 source files modified, 3 feature branches merged to main.

After root build passed, building swift-io exposed two more packages: darwin-primitives (missing Time dep) and pool-primitives (extensive Async/Array variant deps). User fixed pool's Array shadowing between sessions by adding `Array_Dynamic_Primitives`. Second day fixed tree's `internal` -> `public` import regression and verified pool + swift-io build clean.

## What Worked and What Didn't

**Worked well**: The cascading fix pattern was efficient once understood. Every error followed one of ~4 templates: (1) add variant product to Package.swift, (2) add source import, (3) upgrade `internal`/`package` import to `public` for `@inlinable`/`@usableFromInline`, (4) remove dead imports. Mechanical but predictable.

**Didn't work**: Initial `package import` for `@usableFromInline` properties — required three build-fix cycles before the `public import` rule was internalized. Also, building from root to verify sub-package changes hit SPM dependency ordering issues where newly-added modules weren't compiled yet ("no such module"). Building from sub-package directories first was the reliable path.

**Confidence gap**: The scope kept expanding. What started as "fix 2 platform packages" became "fix 9 packages across 80 files." The user's "we should fix those too" directive on storage errors was the right call — it prevented shipping a root build that only worked because it stopped at storage.

## Patterns and Root Causes

The root cause is a phase transition in Swift's module system. MemberImportVisibility (enabled via `enableUpcomingFeature`) changes the contract: importing a module at the target level in Package.swift is necessary but no longer sufficient — each source file must independently import the module that defines the types it uses. This interacts multiplicatively with primary decomposition: a package with N variant products requires N separate imports where 1 umbrella import used to suffice.

Three recurring sub-patterns:
1. **Visibility escalation**: `@inlinable` and `@usableFromInline` silently require `public import`. The compiler error message is clear but the rule is non-obvious — `package` properties feel like they should accept `package import`.
2. **Name shadowing from Core imports**: `Array_Primitives_Core.Array` and potentially other namespace types shadow stdlib types. Importing Core for the namespace breaks unqualified `[T]` usage. The fix is either `Swift.Array` disambiguation or importing the Dynamic variant that provides `.append()` on the custom type.
3. **Init locality**: Public convenience inits live in variant modules, not Core. Core declares the struct with `package` memberwise inits; variant modules add `public init()`. Consumers need the variant import, not just Core.

## Action Items

- [ ] **[skill]** modularization: Add rule about `public import` requirement for `@inlinable`/`@usableFromInline` — this was the most repeated mistake across storage, pool, and tree fixes
- [ ] **[skill]** modularization: Add rule about Array/namespace type shadowing when importing Core modules — document the disambiguation pattern
- [ ] **[package]** swift-primitives: Darwin/linux/windows kernel variant narrowing remains from original handoff — 3 complex packages not yet started
