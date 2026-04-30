# Cross-Platform Sibling as Refactor Template

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: IN_PROGRESS
tier: 2
---
-->

## Context

When fixing a layering or structural violation in one per-platform package, the working analog in sibling per-platform packages is often the fastest refactor template: read what swift-linux does, then make swift-windows match. The heuristic was empirically observed during the 2026-04-26 swift-windows.Thread.Affinity refactor (`swift-foundations/swift-windows@6503806`), where the fix shape became obvious by comparing against swift-linux.Thread.Affinity's working pattern.

Cross-platform symmetry as a refactor heuristic is intuitive but not always applicable. Genuinely platform-divergent subsystems (Mach-specific extensions on Darwin, io_uring on Linux, Job Objects on Windows) do not mirror across the per-platform packages, and the heuristic fails when applied to them. This Doc scopes the analysis to identify when the heuristic applies, when it does not, and what evidence supports either disposition.

## Question

When fixing a structural violation in one per-platform package P_X (where X ∈ {Darwin, Linux, Windows, Android, FreeBSD, ...}), under what conditions is the working analog in sibling packages P_{X'} (X' ≠ X) the appropriate refactor template?

## Analysis

### The heuristic in concrete form

The per-platform packages mirror each other for cross-platform-shared concerns. When P_X has a structural violation in subsystem S, the sibling packages' implementations of S — when they exist and are non-violating — provide the structural template:

1. Read sibling P_{X'}'s implementation of S.
2. Identify the structural shape that makes P_{X'}'s version compliant: which dependencies it imports, which functions it calls, which types it owns, where the platform-specific syscall is invoked.
3. Refactor P_X to mirror P_{X'}'s shape, substituting the platform-specific bits (different syscalls, different system types) into the same overall flow.

The fix is not "copy the code"; it is "match the structural shape, with platform-specific substitutions."

### Origin instance — swift-windows.Thread.Affinity (2026-04-26)

**P_X**: swift-windows.

**Subsystem S**: Thread.Affinity (NUMA-aware thread placement).

**Violation**: `public import Systems` — upward dep into the L3-unifier swift-systems, in violation of [PLAT-ARCH-008] (the consumer-import rule for L3 packages).

**P_{X'}**: swift-linux. The working sibling for the same syscall family. swift-linux.Thread.Affinity uses:

- `public import System_Primitives` — a downward L1 import for primitive types.
- `let numa = System.Topology.NUMA.discover()` — a same-package call to swift-linux's own NUMA implementation, not a swift-systems unifier delegation.

**Refactor**: P_X (swift-windows) was refactored to mirror P_{X'} (swift-linux) exactly:

- Replaced `public import Systems` with `public import System_Primitives` (downward).
- Replaced `let topology = System.topology()` (which called the swift-systems unifier) with `let numa = System.Topology.NUMA.discover()` (a same-package call to swift-windows's own Windows-NUMA implementation).

**Build evidence**: `swift build` clean in 2.80s for swift-windows; swift-systems downstream rebuild clean in 64.08s.

The sibling's structural shape was the answer; the platform-specific bits (Windows NUMA APIs vs Linux NUMA APIs) substituted into the same flow.

### When the heuristic applies

| Condition | Test |
|-----------|------|
| The subsystem expresses a cross-platform-shared concern | The same conceptual API (NUMA discovery, thread affinity, file IO retry policy, signal handling, descriptor lifecycle) is implemented in 2+ per-platform packages with the same surface. |
| The sibling's version is non-violating against the rule of interest | Sibling's implementation passes the audit / the rule P_X violates. |
| Platform-specific differences are sub-structural | The platform-specific bits (different syscalls, different system types, different error codes) substitute into the same overall shape; the difference is "what call" not "what flow". |
| The platforms have a common conceptual model for the subsystem | All target platforms agree on what NUMA discovery, thread affinity, etc. means at the API level — the structural shape is shared because the model is shared. |

### When the heuristic does not apply

| Condition | Why it fails |
|-----------|--------------|
| Subsystem is genuinely platform-divergent | Mach ports (Darwin), io_uring (Linux), Job Objects / Wait Chains (Windows) — the platforms diverge structurally, not just syntactically. The sibling shape is misleading because there is no shared model. |
| All siblings violate the same rule | If all per-platform packages exhibit the same violation, none is a valid template; the fix must be derived from the rule itself, not from sibling mirroring. |
| The rule itself is platform-conditional | If the violation involves a rule that intentionally varies across platforms (per-platform native-shape rules, platform-specific layering carve-outs), the sibling's "fix" may not be applicable to P_X. |
| Subsystem is an emergent abstraction in P_X | When P_X is the first per-platform package to model a subsystem (e.g., a new platform extension landing before the abstraction is generalized), there is no sibling template — the structural shape must be derived directly. |

### Open analysis

| Question | Status |
|----------|--------|
| Beyond Thread.Affinity, how often does the heuristic apply across per-platform package subsystems? | TODO — survey swift-darwin / swift-linux / swift-windows for cross-platform-shared subsystems and count instances |
| What is the failure mode when the heuristic is misapplied? | TODO — capture an instance where mirroring produced a worse fix or masked a platform-specific concern |
| Can the heuristic be codified as a skill rule? | TODO — current candidate is the platform skill (likely as a guideline rather than a MUST/SHOULD rule, given the boundary cases) |
| What is the relationship to [PLAT-ARCH-008h] within-L3 sub-tiering and [PLAT-ARCH-008i] POSIX-shared base composition? | TODO — the heuristic operates inside the sub-tiering structure; clarify the composition |

## Outcome

**Status**: IN_PROGRESS

**Recommendation (preliminary)**: For cross-platform-shared subsystems, sibling per-platform packages are valid refactor templates. The heuristic does not apply to genuinely platform-divergent subsystems. Further empirical census across the swift-darwin / swift-linux / swift-windows packages is required to identify the boundary cases and to determine whether the heuristic warrants codification at skill level.

**Tier classification**: Tier 2 per [RES-020] — cross-package, reversible precedent. The heuristic is observable and useful but is not foundational; codifying it later (or not codifying it) does not invalidate package designs that rely on or ignore it.

## References

- Reflection: [Research/Reflections/2026-04-26-lateral-l3-doc-stamp-and-platform-skill-amendment.md](Reflections/2026-04-26-lateral-l3-doc-stamp-and-platform-skill-amendment.md) — origin instance and pattern observation.
- Commit: `swift-foundations/swift-windows@6503806` — the P3.5 refactor that demonstrated the heuristic.
- Commit: `swift-foundations/swift-windows@551305a` — synthesis-tracker stamp for the resolved finding.
- Sibling implementation: `swift-foundations/swift-linux/Sources/Linux/Thread/Affinity.swift` — working template (NUMA discovery via same-package call + downward `System_Primitives` import).
