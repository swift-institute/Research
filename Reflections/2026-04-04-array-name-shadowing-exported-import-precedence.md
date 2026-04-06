---
date: 2026-04-04
session_objective: Eliminate Array_Primitives_Core.Array disambiguation throughout the ecosystem
packages:
  - swift-array-primitives
  - swift-io
  - swift-tree-primitives
  - swift-memory-primitives
  - swift-hash-primitives
  - swift-bitset-primitives
  - swift-test-primitives
  - swift-binary-parser-primitives
status: pending
---

# Array Name Shadowing: @_exported Import Already Works

## What Happened

Investigated why `Array_Primitives_Core.Array` disambiguation is used throughout the ecosystem when `import Array_Primitives` should make bare `Array` resolve to the custom type. Built a 7-scenario experiment package (`swift-institute/Experiments/exported-import-name-shadowing/`) that tested name resolution through `@_exported` chains of varying depth.

**Key finding**: `@_exported import` already gives the custom Array type precedence over `Swift.Array` in all tested contexts — expressions, type annotations, generic returns, extension declarations, protocol conformances, 3+ levels of `@_exported`, and multiple independent re-export paths. The existing qualifications were purely defensive.

Applied the cleanup iteratively, package by package with build+test verification:
- swift-array-primitives: Removed `Array_Primitives_Core.Array` qualifications (3 files)
- swift-io: Removed 17 qualifications across 8 files (sources + tests)
- swift-tree-primitives: Comment update
- swift-bitset-primitives: Removed 2 defensive `Swift.Array` in expression contexts
- swift-test-primitives: Removed 1 defensive `Swift.Array`
- swift-binary-parser-primitives: Fixed test directory naming mismatch

Also applied Phase 1 of the borrowing-forEach gap fix (removing `Array.Protocol.func forEach` from `Array.Protocol+defaults.swift`) to resolve the tree-primitives three-way overload ambiguity, and fixed memory-primitives test compilation (Inline @Suite in generic context + missing Vector TS in re-export chain).

Fixed pre-existing test failures in swift-tree-primitives (wrong test dependency: `Array Primitives Core` → `Array Primitives`) and swift-memory-primitives (3 issues: `@Suite` inside generic `Memory.Inline`, missing `Vector_Primitives_Test_Support` re-export, and Cardinal/Ordinal range iteration).

## What Worked and What Didn't

**Worked**: The build-and-verify approach for each package caught false assumptions about which `Swift.Array` usages were defensive. Initial static analysis (checking direct `import Array_Primitives` statements) missed deep `@_exported` chains — binary-parser-primitives, json, and tests/snapshot all transitively import Array_Primitives through the parser chain. Only building revealed this.

**Worked**: The existing handoff document (`HANDOFF-borrowing-foreach-gap.md`) contained the exact Phase 1 fix for the forEach ambiguity — one deletion, thoroughly researched with experiment validation. This saved significant investigation time.

**Didn't work**: Initial attempt to fix the tree-primitives forEach ambiguity by rewriting `borrowing Array<Int>` to `Array<Int>` and using `for in` — this was a regression from borrowing semantics. The user correctly blocked this and directed me to find the prior research.

**Convention discovered**: `extension Swift.Array: Protocol` should keep `Swift.` even when Array_Primitives is not imported — it communicates intent and prevents silent retargeting if Array_Primitives is ever imported transitively. Expression contexts (`Swift.Array(...)`) are safe to clean up. Two changes (hash-primitives, memory-primitives) were committed then reverted.

## Patterns and Root Causes

**Pattern: @_exported chains are deeper than they appear**. The initial analysis categorized packages as "defensive" based on direct `import` statements. But `@_exported` chains like `JSON → Parser_Error_Primitives → Parser_Primitives_Core → Array_Primitives_Core` mean that most packages in the ecosystem transitively receive the custom Array type. The only genuinely defensive `Swift.Array` usages were in low-tier packages with no parser/collection dependencies (bitset, test-primitives).

**Pattern: Test Support re-export gaps create silent compilation failures**. Memory_Primitives_Test_Support was missing `Vector_Primitives_Test_Support` in its re-export chain. The `(.zero..<count).forEach` pattern requires the `Index.Count+Vector.swift` operator from vector-primitives. Without it, the range can't be constructed and the test fails with opaque type errors. The fix belonged in the Test Support module per [TEST-020], not in individual test targets.

**Pattern: Defensive qualification was cargo-culted, not empirically needed**. The `Array_Primitives_Core.Array` qualification was documented in the type's own doc comment as required. Nobody had tested whether bare `Array` actually resolves. Once the experiment proved it does, the qualification could be removed ecosystem-wide. This suggests other similar assumptions may exist.

## Action Items

- [ ] **[skill]** existing-infrastructure: Add note that `(.zero..<count).forEach` requires Vector_Primitives (Index.Count+Vector.swift operator) — not obvious from the pattern
- [ ] **[package]** swift-sequence-primitives: HANDOFF-borrowing-foreach-gap.md Phase 1 was applied then reverted upstream — handoff remains active, re-apply when ready
- [ ] **[research]** Audit ecosystem for other cargo-culted disambiguations beyond Array (e.g., Dictionary, Set, Optional shadows)
