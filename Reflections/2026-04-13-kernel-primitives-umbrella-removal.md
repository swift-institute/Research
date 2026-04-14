---
date: 2026-04-13
session_objective: Remove Kernel_Primitives umbrella target so each consumer imports only specific sub-targets
packages:
  - swift-kernel-primitives
  - swift-linux-primitives
  - swift-windows-primitives
  - swift-darwin-primitives
  - swift-async-primitives
  - swift-iso-9945
  - swift-kernel
  - swift-paths
  - swift-posix
  - swift-file-system
status: processed
---

# Kernel Primitives Umbrella Removal — Cross-Ecosystem Migration

## What Happened

Removed the `Kernel Primitives` umbrella target that `@_exported import`ed 23 sub-targets. Every consumer (336 source files across 14 repos in 3 layers) was migrated to import only the specific sub-targets it needs. Tests were split from 1 monolithic target into 13 per-sub-target test targets.

Execution followed a 6-phase plan derived from a thorough audit (6 parallel investigation agents mapped every consumer file). Phases 2–4 were parallelized via 5 concurrent agents handling linux, windows, iso-9945, L3 foundations, and test restructuring simultaneously.

Build verification caught 3 module-qualified reference bugs (`Kernel_Primitives.Kernel` in typealiases/extensions) that import greps missed. Also completed the interrupted `File.System.Write` namespace merge (circular typealiases + duplicate method declarations).

The glob layering question surfaced during file-system build verification — `Kernel.Glob.match` now takes `Kernel.Path.View` but the file-system consumer has `String`. Handed off as a research investigation rather than applying a quick `Kernel.Path.scope` patch.

## What Worked and What Didn't

**Worked well:**
- Parallel agent dispatch for investigation (6 agents) and execution (5 agents). The investigation agents produced per-file type analysis that made execution agents' instructions precise. Total wall-clock time was ~10 minutes for investigation, ~5 minutes for execution.
- The audit-first approach. Writing the full inventory before touching code prevented surprises. The only consumer not in the original handoff (swift-iso-9945) was caught during the audit sweep.
- Phase ordering (L1 → L2 → L3 → indirect → delete) prevented cascading failures.

**Didn't work well:**
- Agents couldn't catch module-qualified references (`Kernel_Primitives.Kernel`). These only surface at build time. The grep for `import Kernel_Primitives` misses `extension Kernel_Primitives.Kernel.Foo`. Needed a separate sweep for `Kernel_Primitives\.` (dot suffix).
- The L3 agent moved Readiness files to a new `Kernel Event` directory — changes outside its brief that were resolved by a separate session. Agent scope instructions should be more explicit about "do not move or restructure files."
- ISO 9945's `Kernel.Glob.match` API change wasn't anticipated in the audit. The `String` → `Kernel.Path.View` migration happened in a prior session, and the file-system consumer hadn't been updated.

## Patterns and Root Causes

**Module-qualified references are invisible to import greps.** This is the third time a module removal has been tripped up by `ModuleName.Type` references in typealiases and extensions. The pattern: `import Module` is the obvious search target, but `extension Module.Namespace { ... }` and `typealias X = Module.Namespace.Y` also bind to the module. A post-migration build is mandatory, but a `Module\.` (dot) grep before the build catches most of them cheaply.

**Parallel agent execution scales linearly for mechanical migrations.** The umbrella removal is ideal agent work: repetitive, well-specified, independent per-package. The key was making investigation agents produce data (type→sub-target mappings) that execution agents consumed as precise instructions. Vague agent briefs ("figure out what to change") produce vague results.

**Re-export surfaces are the real complexity.** The 336 file changes were mechanical. The hard decisions were about what L3 `exports.swift` files should re-export after the umbrella disappears. The user's decision to preserve current behavior (re-export all 22 sub-targets) was the right call — it decoupled the structural cleanup from API surface changes.

## Action Items

- [ ] **[skill]** handoff: Add guidance to always grep for `DeletedModule\.` (dot suffix) in branching investigations that recommend module deletion, not just `import DeletedModule`
- [ ] **[research]** Glob layering: where should String-accepting convenience live? Handed off to `HANDOFF-glob-layering-research.md` — the L1/L2/L3 boundary question needs platform skill analysis
- [ ] **[package]** swift-kernel-primitives: Consider whether per-sub-target test targets should each get their own test support target (currently all share `Kernel Primitives Test Support`)
