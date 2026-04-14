---
date: 2026-04-01
session_objective: Redo per-variant-core modularization from current main and fix release-mode test failures
packages:
  - swift-buffer-primitives
  - swift-property-primitives
status: processed
---

# Buffer Modularization Redo and Property.View.Read Release-Mode Miscompile

## What Happened

Session began with reading the HANDOFF-modularization-redo.md investigation brief. Investigated whether the stale `per-variant-core-split` worktree (6 unique commits, 20+ on main) could be deleted and redone from current main. Findings confirmed yes — no unique content on the branch survived.

Executed the modularization: split monolithic `Buffer Primitives Core` (30 files) into slim shared Core (4 files) + 8 per-variant Core targets. All tests passed in debug and release.

During release-mode testing, discovered 24 pre-existing test failures — `peek.front`/`peek.back` returning garbage values. Traced to `Property.View.Read.Typed.init(borrowing:)` using `withUnsafePointer(to: base) { $0 }` to escape a pointer from the closure scope. SIL dump confirmed: optimizer allocates stack slot, takes address, immediately deallocates without storing the value. Applied `@_optimize(none)` on 4 `init(borrowing:)` methods — eliminates all 24 failures.

Committed Link extraction to `swift-link-primitives`, then redid modularization on post-extraction main. Merged via fast-forward. Also discovered that Arena.Inline and Slab.Inline deinit canaries pass not because #86652 is fixed, but because their deinits bypass `Storage.Inline` entirely — Arena.Inline hand-rolls its own `@_rawLayout` storage, which is architecturally inconsistent.

## What Worked and What Didn't

**Worked**: The investigation-first approach. Reading both Package.swift files, cataloging every file's variant ownership, and verifying cross-variant dependencies before touching anything produced a clean mechanical split with zero content changes. The split was redone twice (pre- and post-Link extraction) with no issues either time.

**Worked**: The /issue-investigation skill for the peek miscompile. Classification as Miscompile → dev toolchain check → standalone reproducer → SIL dump gave a clear root cause within minutes. The SIL evidence (`alloc_stack` → `address_to_pointer` → `dealloc_stack` with no store) was unambiguous.

**Didn't work**: Initial assumption that removing `~Escapable` would fix the miscompile. It doesn't — the dangling pointer from `withUnsafePointer(to:) { $0 }` is the direct cause regardless of `~Escapable`. The `~Escapable` removal only addresses the *compiler crash* (#88022), not the *runtime* miscompile. This distinction (compiler crash vs runtime miscompile from the same pattern) wasn't immediately obvious.

**Didn't work**: Canary test interpretation. The Arena.Inline and Slab.Inline canaries appeared to show #86652 was fixed in release mode, but debug mode still fails. The canaries pass because those types bypass `Storage.Inline` entirely — a false signal that needed careful analysis to disambiguate.

## Patterns and Root Causes

**`withUnsafePointer(to:) { $0 }` is fundamentally unsafe with borrowing parameters.** The Swift documentation says the pointer is valid only within the closure. Escaping it is undefined behavior that the optimizer correctly (from its perspective) exploits. The `@_lifetime(borrow)` annotation doesn't help because the optimizer's dead-store elimination runs before lifetime analysis can protect the temporary. This is the same root cause as #88022 and #87029 — three manifestations (compiler crash, SIL verifier crash, runtime miscompile) of one underlying gap: no safe borrow-to-pointer conversion exists in Swift.

**Canary tests that pass for the wrong reason are worse than failing tests.** The Arena.Inline/Slab.Inline canaries created a false signal that #86652 was partially fixed. In reality, those types work because they violate the architecture (hand-rolled storage at the buffer layer). The canary should test the *storage-layer deinit path*, not just "does any deinit fire."

## Action Items

- [ ] **[package]** swift-buffer-primitives: Arena.Inline should compose Storage.Arena.Inline — blocked on #86652 but design investigation written in HANDOFF-arena-inline-storage-alignment.md
- [ ] **[skill]** issue-investigation: Add guidance for distinguishing compiler crashes vs runtime miscompiles from the same pattern (e.g., ~Escapable + withUnsafePointer causes both ICE and miscompile via different paths)
- [ ] **[research]** File standalone reproducer for the peek miscompile as a new manifestation on swiftlang/swift#88022 (runtime miscompile, not just compiler crash)
