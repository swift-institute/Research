---
date: 2026-03-20
session_objective: Diagnose and fix Swift 6.2 release mode compiler crash across the ecosystem
packages:
  - swift-buffer-primitives
  - swift-primitives
status: pending
---

# Release Mode LLVM Verifier Crash: Investigation and File-Split Fix

## What Happened

The ecosystem could not build in release mode — `swift build -c release` crashed with "Instruction does not dominate all uses!" in the LLVM verifier (signal 6). The initial hypothesis pointed at `Buffer.Aligned`'s `Int(bitPattern: count.cardinal)` pattern and CopyPropagation on `~Copyable` types.

After extensive systematic elimination (emptying files, toggling `@inlinable`, disabling CMO, removing deinits, standalone reproducers), the true root cause was identified: `Buffer.swift` — a 1345-line monolithic file — contained 4 `~Copyable` structs with `@_rawLayout` stored fields + explicit `deinit` blocks. When compiled in a single WMO translation unit with both `Storage_Primitives` and `Cyclic_Index_Primitives` imported, the SIL → LLVM IR lowering generated broken code.

The proven fix: splitting the 4 Inline types into separate files eliminates the crash with zero code changes. A cross-extension nested type visibility issue (`Small._Representation` referencing `Inline` by unqualified name) blocks the simple file split and requires either separate SPM modules or restructured nesting.

Enum workaround approaches (`_StorageRepr`, `_DeinitStorage` wrapper) were explored extensively but create cascading problems: `_modify` doesn't work on enum payloads when the type has a deinit, single-field wrappers only fix simple deinits (Ring/Linear), multi-field wrappers with deinit trigger the same crash.

Research document written: `swift-buffer-primitives/Research/release-mode-llvm-verifier-crash-diagnosis.md`. Handoff document written: `swift-buffer-primitives/Research/release-crash-fix-handoff.md`.

## What Worked and What Didn't

**Worked well**:
- Systematic file-level elimination was decisive. Emptying `exports.swift` → no crash. Adding imports back one by one → pinpointed `Storage_Primitives` + `Cyclic_Index_Primitives`. Adding `Buffer.swift` back → crash. This took minutes and gave definitive answers.
- Disabling all 4 deinits at once → 0 errors. This immediately confirmed the trigger.
- Building storage-primitives in release first ruled out the dependency chain.

**Didn't work**:
- The initial focus on `Buffer.Aligned` and `Int(bitPattern: count.cardinal)` consumed significant time. The typed API improvements are architecturally correct but unrelated to the crash.
- `@inline(never)` was applied to progressively more methods without progress — because the crash is in IRGen, not inlining.
- Standalone reproducers (even cross-module with identical type structure) never reproduced the crash. The bug requires the full dependency graph's serialized SIL volume.
- Enum workarounds consumed extensive iteration. Each variant exposed a new constraint (can't `_modify` enum payloads, can't partially consume self with deinit, multi-field wrappers still crash).

**Confidence was low**: when the empty convenience file still crashed. That was the turning point — it proved the crash was not in any code I was editing, but in how WMO assigned other files' code to that translation unit.

## Patterns and Root Causes

**Pattern: Monolithic files amplify optimizer bugs.** The crash requires enough type metadata in a single compilation unit for the optimizer to miscompile. The same code in separate files doesn't crash — the optimizer processes less complex IR per unit and doesn't trigger the dominance violation. This is the same class of issue as the Small types' enum workaround (documented in `small-buffer-enum-compiler-workarounds.md`).

**Pattern: Initial hypothesis anchoring.** The task description pointed at CopyPropagation and `Buffer.Aligned`. Hours were spent on that lead before the file-emptying approach found the real trigger. The correct first step was the file-level elimination, not code-level modification.

**Pattern: Workaround cascades.** Each workaround for the LLVM bug introduced a new Swift type-system limitation. Enum → can't `_modify`. Wrapper struct → multi-field triggers same crash. Single-field wrapper → can't access header in deinit. The cascade signals that the workaround axis is wrong — the structural fix (file split) avoids the entire cascade.

**Root cause of the investigation inefficiency**: treating a compiler bug as a code bug. The code was correct. The fix is structural (split files) or external (compiler fix), not a code workaround.

## Action Items

- [ ] **[package]** swift-buffer-primitives: Split `Buffer.swift` (1345 lines) into per-type files/modules — this fixes the release crash AND satisfies [API-IMPL-005]. Handoff document at `Research/release-crash-fix-handoff.md`.
- [ ] **[skill]** existing-infrastructure: Add guidance that `Int(bitPattern: count)` (Tagged) is the correct stdlib boundary pattern, not `Int(bitPattern: count.cardinal)` which chains through `.rawValue`. This matches [CONV-001] but the existing-infrastructure skill doesn't have a decision tree entry for it.
- [ ] **[research]** File a Swift compiler bug: `~Copyable` struct with 2+ fields (one `@_rawLayout`) + deinit + release optimization = LLVM verifier crash. Reproducible in swift-buffer-primitives but not in standalone packages.
