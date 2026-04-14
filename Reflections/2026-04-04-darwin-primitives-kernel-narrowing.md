---
date: 2026-04-04
session_objective: Narrow Kernel Primitives umbrella imports in darwin-primitives to specific variant modules
packages:
  - swift-darwin-primitives
  - swift-ascii-parser-primitives
status: processed
---

# Darwin Primitives Kernel Narrowing — Re-export Chain as Narrowing Leverage

## What Happened

Session resumed from HANDOFF.md. Step 1 (push 6 sub-repos) was already complete. Proceeded to step 2: narrow `Kernel_Primitives` umbrella imports in darwin-primitives to specific variant modules.

Analyzed all 15 source files and 8 test files in `Darwin Kernel Primitives` target. Mapped each file's kernel type usage to the specific variant module that defines it (Core, Descriptor, Error, Event, File). Key insight: `Kernel_File_Primitives` re-exports 10 of 22 variant modules (Core, Descriptor, Error, IO, Memory, Permission, Process, Time, System, Path), so a single File import covers most files that use rich kernel types.

Package.swift narrowed from 1 umbrella to 2 products: `Kernel File Primitives` + `Kernel Event Primitives`. Source imports narrowed across 12 files to 5 distinct variant modules. Removed umbrella imports from all 8 test files (types flow through `@testable import Darwin_Kernel_Primitives`). Fixed module-qualified typealias (`Kernel_Primitives.Kernel` → `Kernel_Primitives_Core.Kernel`).

Also fixed a pre-existing MIV failure in `swift-ascii-parser-primitives`: `FixedWidthInteger+Parseable.swift` used `Array.Indexed` conformance from `Array_Dynamic_Primitives` in public declarations without importing the declaring module.

All builds pass: sub-package, root target, root full build, downstream swift-io.

## What Worked and What Didn't

**Worked well**: The re-export chain analysis was the right first move. Reading `exports.swift` in each kernel variant module immediately revealed which imports would be redundant. `Kernel_File_Primitives` re-exporting 10 modules meant only 2 Package.swift products needed — much simpler than the 5 I initially considered listing.

**Worked well**: Removing `import Kernel_Primitives` from test files entirely. The test target depends on `Darwin Kernel Primitives` which publicly imports the variant modules, so all kernel types flow transitively. Zero test narrowing needed beyond deletion.

**Minor friction**: Module-qualified name in the typealias (`Kernel_Primitives.Kernel`) wasn't caught until the first build. The narrowing of import statements was straightforward, but references to the umbrella MODULE NAME required a separate pass.

**Confidence was high**: The pattern is now well-understood from prior packages in this handoff. The only unknown was `@_spi(Syscall)` propagation through `@_exported` re-exports, which I handled conservatively with explicit `@_spi(Syscall) public import Kernel_Descriptor_Primitives` alongside the broader variant import.

## Patterns and Root Causes

**Re-export chains as narrowing leverage**: The deeper into the kernel variant tree a module sits, the more it re-exports. `Kernel_File_Primitives` at the "top" re-exports nearly everything. This means narrowing doesn't always mean MORE imports — sometimes one well-chosen variant covers more types with fewer imports than the umbrella. The narrowing is about precision of the dependency graph, not about multiplying import statements.

**MIV conformance visibility is the hardest class**: The ascii-parser-primitives failure was a conformance used transitively through a typealias chain (`Parser.Input.Bytes` → `Input.Slice<Array.Indexed<UInt8>>` → needs `Array.Indexed`'s conformance). These are invisible at the source level — the file doesn't mention `Array.Indexed` anywhere. This class of MIV error will recur in any package that uses typealias-heavy APIs.

**`@_spi` doesn't propagate through `@_exported`**: When module A `@_exported public import`s module B, importing A gives you B's public API. But `@_spi(Syscall) import A` does NOT give you `@_spi(Syscall)` access to B's SPI symbols. You need a separate `@_spi(Syscall) import B`. This is the correct design (SPI should be opt-in per module), but it means SPI files always need at least one extra import targeting the SPI-declaring module.

## Action Items

- [ ] **[package]** swift-ascii-parser-primitives: Check if other source files have similar MIV conformance visibility gaps (only `FixedWidthInteger+Parseable.swift` was broken, but `ASCII.Decimal.Parser` and `ASCII.Hexadecimal.Parser` may have latent issues)
- [ ] **[skill]** implementation: Add guidance that module-qualified names (`Module.Type`) must be updated when narrowing umbrella imports — easy to miss since they're not in import statements
- [ ] **[doc]** HANDOFF.md: Update to reflect darwin-primitives completion; linux-primitives and windows-primitives remain
