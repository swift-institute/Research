---
date: 2026-03-31
session_objective: Audit String-as-path usage across the ecosystem and design the remediation architecture
packages:
  - swift-path-primitives
  - swift-kernel
  - swift-file-system
  - swift-paths
  - swift-iso-9945
  - swift-posix
  - swift-windows
status: processed
processed_date: 2026-04-01
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Added [IMPL-081] null-termination awareness for sub-view APIs on C-string-derived types
  - type: package_insight
    target: swift-path-primitives
    description: Phase 4a decomposition primitives with null-termination constraints
  - type: research_topic
    target: path-decomposition-delegation-strategy.md
    description: Span vs offset for Paths.Path→L1 delegation
---

# Path Type Compliance Audit and L1 Decomposition Design

## What Happened

Session began with `/audit` for path type usage. Discovered 58 findings (10 HIGH) across 3 superrepos where `Swift.String` is used for file system paths instead of typed path types. The audit identified the systemic root cause: `path-primitives` (L1) provides `Path` and `Path.View` but no decomposition primitives (`parent`, `lastComponent`, `appending`). This forces `Kernel.File.Write` to convert to String for path manipulation and forces `Paths.Path` (L3) to reimplement decomposition independently.

The architectural conversation went through three iterations:
1. Initial plan: add swift-paths as dependency to swift-kernel → rejected (10 L3 dependents gain transitive path dep)
2. Second plan: relocate composed write ops from swift-kernel to swift-file-system → rejected (reimplements rather than reuses upstream)
3. Final plan: add decomposition to path-primitives (L1), single implementation, all layers delegate

Critical review identified that `Path.View.parent` as a zero-alloc sub-view is semantically wrong: parent bytes are NOT null-terminated (separator byte at boundary, not `\0`). The solution: L1 scanning returns `Span<Char>?` (zero-alloc), callers construct owned `Path(copying: span)` when syscall use is needed. `lastComponent` IS safe as a sub-view (shares original null terminator).

Two experiments validated the approach (all variants CONFIRMED on Swift 6.3).

## What Worked and What Didn't

**Worked well**: The iterative architectural refinement. Each rejection was principled (dependency fan-out, reimplementation vs reuse, null-termination semantics). The user's challenge "check path-primitives" redirected from an L3 solution to the correct L1 solution. The null-termination analysis caught a semantic error before implementation.

**Worked well**: The experiment design. Both experiments compiled and ran first try (after one fix for ~Copyable Optional consumption pattern). The experiments validated exactly the unknowns we identified.

**Didn't work**: Initial audit overclassified test helper String usage as violations. Test code at L2 where `Kernel.Path` (~Copyable) is the only typed path has legitimate reasons to use String + `scope()`. The scoped `withTempFile` pattern is the correct approach, not typed path returns from test helpers.

**Didn't work**: Three audit plan rewrites. Each iteration improved the plan but cost significant context. The second iteration ("relocate to swift-file-system") was architecturally plausible but violated [IMPL-060] — reusing upstream is always preferred over reimplementation. The user had to correct this.

## Patterns and Root Causes

**Pattern: Missing L1 primitives force String bypass.** This is the same pattern as the Cardinal/Ordinal audit — when L1 doesn't provide the typed operation, consumers fall back to raw types (String for paths, Int for indices). The fix is always bottom-up: add the primitive, then migrate consumers. The ecosystem's layered architecture means L1 gaps have outsized impact — every consumer above must work around the same missing primitive.

**Pattern: Null-termination as hidden invariant.** `Path.View` appears to be "just pointer + count" but carries an implicit null-termination contract for syscall safety. Sub-views that change the count break this contract silently. This is a general issue with C-string-derived types: the `count` field and the null terminator are redundant sources of truth, and sub-slicing preserves one but not the other. The design must make this explicit: `Span<Char>` (no null guarantee, for reading) vs `Path.View` (null-terminated, for syscalls).

**Pattern: Architectural convergence through rejection.** The three-iteration refinement (L3 dep → relocation → L1 decomposition) followed a pattern: each proposal was architecturally valid in isolation but violated a principle that only became visible when challenged. The final design is better BECAUSE the alternatives were explored and rejected with specific reasons.

## Action Items

- [ ] **[skill]** implementation: Add guidance for null-termination awareness when designing sub-view APIs on C-string-derived types. `Span<Char>` is the safe sub-view return; `Path.View` carries a null-termination contract that sub-slicing can silently break.
- [ ] **[package]** swift-path-primitives: Implement Phase 4a — `parentBytes`, `lastComponentBytes`, `appending` on `Path.View`. Use experiments as reference implementations. Handle Windows edge cases using `Paths.Path.Navigation.swift` as oracle.
- [ ] **[research]** Should `Paths.Path` decomposition delegate to L1 via `Span<Char>` or via raw offset computation (`parentLength: Int`)? The Span approach is validated but the offset approach avoids ~Escapable lifetime complexity entirely. Trade-off analysis needed.
