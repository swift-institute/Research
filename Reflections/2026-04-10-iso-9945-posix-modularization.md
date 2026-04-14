---
date: 2026-04-10
session_objective: Modularize ISO 9945 Kernel (97 files) into domain-specific targets and mirror the structure in swift-posix
packages:
  - swift-iso-9945
  - swift-posix
  - swift-kernel-primitives
status: processed
---

# ISO 9945 + swift-posix Domain Modularization

## What Happened

Analyzed the monolithic ISO 9945 Kernel target (97 files, 11,834 lines) for modularization, produced a research document, then implemented the split into 14 targets (Core + 12 domain variants + umbrella). Mirrored the structure in swift-posix (16 targets). Both packages build clean. Three commits shipped.

**Phase 1 — Implementation** (this session):
- Cross-domain coupling analysis revealed only one genuine L2 dependency: Process ↔ Signal (bidirectional via `Signal.Number` and `Process.Group.ID`)
- Broke the cycle by moving vocabulary types to Core — minimum necessary, constants and operations stay in their domain targets
- Discovered `@_spi(Syscall)` is per-file, not per-module — required adding explicit imports to ~80 source files
- Moved `POSIX` typealias ownership from L2 to L3 after discovering the name conflict between the L2 typealias and L3 enum
- Mirrored structure in swift-posix: 13 domain targets (10 re-export-only) + Core + Glob + umbrella + Loader

**Phase 2 — Follow-up investigation** (parallel agent):
- 5 research documents produced (A: L3 policy design, B: process/signal vocabulary, C: SPI + path analysis, D: dependency shape verification, E: modularization doc update)
- Identified `Process.Signal` duplicate in `Process.Kill.swift` — unified with `Signal.Number` from Core
- Fixed `Process.Session.ID` from `pid_t` to `Int32` (consistency with Group.ID)
- Eliminated Terminal → File dependency by duplicating `Error.current()` as `fileprivate`
- Agent also standardized all 22 `Error.current()` instances across iso-9945, finding a real bug (Pipe missing `.io` check)

**Final dependency graph** (one cross-domain edge):
```
Core → (File, Dir, Socket, Mem, Signal, Process, Thread, Terminal, Env) → Lock → System
```

## What Worked and What Didn't

**Worked well**: The L1 vs L2 coupling distinction was the key insight — most apparent coupling was through L1 vocabulary types (`Kernel.Descriptor`, `Kernel.File.Size`), not L2 types. Only two genuine L2 cross-references existed (Signal.Number, Process.Group.ID). The parallel agent workflow for follow-up investigations was effective — 5 research documents produced independently while this session continued.

**Didn't work**: Three assumptions failed:
1. `@_spi(Syscall)` on `@_exported` imports would propagate to sibling files — it doesn't (per-file). Caused multiple build-fix-rebuild cycles.
2. `Process.Group.ID` could promote to L1 — it can't (`pid_t` is POSIX-specific, process groups don't exist on Windows).
3. The `POSIX` typealias at L2 was harmless — it created an unresolvable name conflict when swift-posix defined its own `POSIX` enum. Only surfaced when modularizing swift-posix.

**Follow-up agent quality**: B (process/signal vocabulary) and C (SPI + path) were publish-quality. A needed a correction (type-definition conflict, not overload ambiguity). D and E needed current-state framing. The unsolicited Error.current() standardization was beyond scope but found a real bug.

## Patterns and Root Causes

**Per-file SPI is a modularization tax**: `@_spi(Syscall)` being per-file means every modularization touches every source file. The SPI research (document C) correctly concludes this is "a feature, not a bug" — the per-file opt-in documents the exact blast radius of the syscall boundary. But it needs to be in the modularization skill as a known cost.

**Namespace ownership must be decided before modularization**: The `POSIX` conflict reveals that cross-layer namespace ownership (L2 defines `POSIX`, L3 also defines `POSIX`) must be settled before splitting targets. When both are in one monolith, the shadowing is invisible. Modularization surfaces it because `@_exported` re-exports both definitions into the same scope. The fix (moving `POSIX` to L3, L2 uses `ISO_9945` directly) is correct but required a workspace-wide rename (149 occurrences).

**Vocabulary types as cycle-breakers work but need discipline**: Core now holds Signal namespace + Signal.Number + Process.Group.ID beyond its original scope (namespace + error base). The research confirmed this placement is correct — both types are cross-domain vocabulary — but the pattern should be explicitly documented: Core holds types that would otherwise create inter-target cycles.

**L3 POSIX enum is necessary for shadowing**: The L3 `POSIX.Kernel.File.Flush` enum cannot be a typealias to `ISO_9945.Kernel.File.Flush` because you cannot add `enum Flush {}` to a type that already has a `Flush` member. This is a type-definition conflict, not overload ambiguity. The separate L3 namespace is structurally required for the policy-wrapper pattern.

## Action Items

- [ ] **[skill]** modularization: Add guidance for `@_spi` handling during target decomposition — per-file opt-in is a known cost; `@_spi` does NOT propagate through `@_exported` to sibling files within the same target
- [ ] **[research]** Glob layering anomaly: directory traversal (opendir/readdir/stat) is L2 spec behavior but currently lives at L3. Should the traversal extract to iso-9945 with L3 keeping only the pattern matching algorithm?
- [ ] **[package]** swift-iso-9945: Process.Kill doc examples still reference `.terminate`, `.stop`, `.continue` — verify these are Signal.Number constants (not the removed Process.Signal constants) and that callsites in tests are updated
