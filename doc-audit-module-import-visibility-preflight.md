# Doc-Class Audit Module-Import-Visibility Pre-Flight

Date: 2026-04-26
Scope: ecosystem-wide (any Doc-class investigation that recommends deleting a publicly-declared type without adoption elsewhere)
Tier: 2 (cross-package, methodology guidance, reversible precedent)
Status: IN_PROGRESS — methodology survey; recommendation to follow once empirical comparison lands
Provenance: Reflection `2026-04-24-post-cycle-3-audit-and-p2-9-unify-cycle-4.md` (Cycle 4 Phase 2 io_uring orphan-reference build-time failure); informs codified rules [HANDOFF-013b] (writer-side), [SUPER-026] (principal-side)

---

## Context

Cycle 4 P2.9 closure of the `Kernel.Signal.Information` dual-declaration (2026-04-24) executed a "drop-all" disposition on the duplicate type after a Phase 0.5 grep produced one consumer reference (a waitid parameter declaration in `Linux.Kernel.IO.Uring.Entry+Prepare.swift`). Reference-count = 1; the consumer was just a type-name reference. Drop-all dispatched.

Phase 2 deletion built clean on `Linux Kernel System Standard` (the deleted type's containing target) but failed on `Linux Kernel IO Uring Standard` with `'Information' is not a member type of enum 'Kernel_Namespace.Kernel.Signal'`. Root cause: the deleted type's co-location in `Linux_Kernel_System_Standard` had been providing accidental transitive module-import visibility for the type name; when it was deleted, the io_uring consumer's missing `public import ISO_9945_Kernel_Signal` surfaced. The consumer's source file had never explicitly imported the unified declaration's containing module — its visibility was an artifact of the old co-location.

The defect was not a reference-count miss; it was a module-import-graph miss. Grep finds text matches; the compiler enforces import relationships. Pre-Swift-6 ecosystems had lax transitive visibility through umbrella re-exports that made grep-level consumer counts approximately correct. Swift 6.3+ ecosystems using `InternalImportsByDefault` + `MemberImportVisibility` narrow transitive visibility; accidental visibility via co-location can mask missing-import defects until deletion exposes them.

The codified rules [HANDOFF-013b] (writer-side) and [SUPER-026] (principal-side) close the gap as a discipline. This Doc surveys the candidate verification mechanisms, comparing rigor + cost, to inform which mechanism a given session should reach for given the deletion's scope.

---

## Question

What is the minimum-cost verification mechanism a Doc-class deletion-without-adoption proposal MUST execute before authorization, and at what scope does the proposal warrant a more rigorous mechanism?

Three candidate mechanisms (in increasing rigor, increasing cost):

1. **`grep -l "public import {DeclaringModule}" {consumer-file}`** — text-level check that the consumer's file (or the target's `exports.swift`) explicitly imports the declaring module. Seconds per site.
2. **`swift symbolgraph-extract` per consumer module** — compiler-level enumeration of visible types per module. Minutes per consumer module.
3. **Trial-deletion-plus-build at each consumer's target** — empirical confirmation by attempting the deletion in a branch and observing the build outcome. Tens of minutes; requires Docker Linux for cross-platform consumer surfaces.

Each mechanism has different defect-class coverage. Grep-l (#1) catches the explicit-import-absent case but misses the case where the consumer's transitive-import chain is the only path. Symbolgraph-extract (#2) enumerates all visible types but requires interpreting the output against the declaring module. Trial-deletion (#3) is empirical and catches everything but costs the most.

---

## Analysis (stub)

This Doc's analysis section will:

- Survey 3-5 historical Doc-class delete-public-type proposals across the ecosystem; classify each by whether it would have been caught by mechanism #1 alone vs needing #2/#3.
- Empirically test mechanism #2 (`swift symbolgraph-extract`) on a representative consumer module; record the output format and the per-module interpretation cost.
- Document a decision matrix: deletion scope (single consumer vs many) × deletion publicity (private vs SPI vs public) → recommended mechanism.

Pending the analysis, the codified rules [HANDOFF-013b] and [SUPER-026] specify mechanism #1 as the minimum requirement and mechanisms #2/#3 as escalation options when #1 flags substantial follow-on work.

---

## Outcome (placeholder)

To be authored once the analysis section completes. Expected shape:

- **Mechanism #1 (`grep -l`)**: minimum requirement for every deletion proposal. Catches the lion's share of defects at near-zero cost.
- **Mechanism #2 (`swift symbolgraph-extract`)**: escalation when #1 flags >N sites, where N is to be determined empirically.
- **Mechanism #3 (trial-deletion)**: escalation when the deletion crosses Docker Linux module boundaries (cross-platform consumer surfaces) where symbolgraph-extract output is ambiguous or platform-dependent.

The codified rules [HANDOFF-013b] and [SUPER-026] will reference this Doc when it lands; until then, mechanism #1 is the working minimum.

---

## Cross-references

- Reflection: `2026-04-24-post-cycle-3-audit-and-p2-9-unify-cycle-4.md` (origin incident)
- Skill rules: [HANDOFF-013b] (writer-side build-level visibility pre-flight), [SUPER-026] (principal-side delete-public-type disposition verification)
- Related: `swift-institute/Research/spm-build-parallelism-spurious-module-errors.md` (REFERENCE 2026-04-25; documents the `-j 1` build-verification protocol that interacts with mechanism #3's empirical-build cost)
