---
date: 2026-05-08
session_objective: Execute two L1-layering corrections dispatched off a prior read-only dep-necessity audit — reverse Memory↔System (move Page bridge), and reverse Algebra↔Optic/Witness (introduce Algebra.Iso, drop empty Witness.Protocol marker, rewrite .z2 factories)
packages:
  - swift-memory-primitives
  - swift-system-primitives
  - swift-algebra-primitives
  - swift-algebra-magma-primitives
  - swift-algebra-monoid-primitives
  - swift-algebra-semiring-primitives
  - swift-algebra-semilattice-primitives
  - swift-algebra-group-primitives
  - swift-algebra-ring-primitives
  - swift-algebra-field-primitives
  - swift-algebra-module-primitives
  - swift-finite-primitives
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: SkillUpdate [HANDOFF-040] amended with form-position variants in conformance lists (entry 7 AI 1). Tier-table update is data work for primitives skill (entry 7 AI 2), tracked separately. Layering-inversion-via-small-bridge research (entry 7 AI 3) deferred to a follow-up sweep real ecosystem class, but small instance count (2 in 2 days) does not yet warrant a Tier-2 doc.
---

# Two L1 Layer Reversals: Memory↔System and Algebra↔Iso

## What Happened

Subordinate session under an orchestrator dispatching off `HANDOFF-ds-dep-necessity-audit.md`. Three sequential dispatches:

1. **Read-only audit** of three dep clusters (witness/optic/dependency, system, algebra hierarchy) for the data-structure publish chain. Wrote `## Findings` to the handoff per its Findings Destination.
2. **Memory↔System reverse**: deleted `swift-memory-primitives/Sources/Memory Primitives Core/Memory.Page.swift`; moved its two extensions (`Memory.Alignment.init(_: System.Page.Size)` + `System.Page.Size.alignment`) to a new file `swift-system-primitives/Sources/System Primitives/System.Page+Alignment.swift` with `public import Memory_Primitives_Core`. Two commits (memory `af0e924`, system `014598f`). Both packages clean-built.
3. **Algebra↔Optic/Witness reverse**: created `swift-algebra-primitives/Sources/Algebra Primitives Core/Algebra.Iso.swift` (pure forward+backward data carrier), dropped the empty `Witness.\`Protocol\`` marker conformance from 14 algebra struct sites across 8 packages, rewrote 3 `.z2(via:)` factories from `Optic.Iso<E, P>` to `Algebra.Iso<E, P>`, dropped optic re-export from `swift-finite-primitives` exports.swift, and removed corresponding deps from 4 Package.swifts (magma drops witness; group/field/finite drop optic). Ten commits across ten packages. All 11 packages (incl. modular and bit-primitives sanity check) clean-built.

Workspace impact scans returned zero source consumers of the bridges in both reverses.

The brief's enumeration cited 5 Witness.Protocol sites; exhaustive grep found 14. The brief's grep regex (`: Witness\.\`Protocol\`\|Witness\.\`Protocol\`,`) missed 2 sites (`Algebra.Magma`, `Algebra.Semigroup`) that use the form `Sendable, Witness.\`Protocol\`` (Sendable first, no comma after). A re-grep with the looser pattern `Witness\.\`Protocol\`` caught all 14 across 8 algebra packages, including swift-algebra-module-primitives and swift-algebra-semilattice-primitives — packages NOT listed in the brief's 7-package scope.

Per `feedback_per_wave_inventory_must_be_exhaustive`, expanded scope to all 14 sites + 9 algebra packages. The constraint allowed it ("algebra+finite+bit set"), but the literal wave enumeration in the brief did not cover all of them — the exhaustive check was a conscious extension.

HANDOFF scan at session end: 46 `HANDOFF-*.md` + 7 `AUDIT-*.md` files at workspace root. Triaged 1 (`HANDOFF-ds-dep-necessity-audit.md`, the file my session worked); the other 52 are out-of-session-scope (case-(a)/(b) authority absent, no stale-override fired since the orchestrator is actively working topics adjacent to many of them per [REFL-009a]). The one in-scope file: investigation findings written to it per its Findings Destination; subsequent two follow-up dispatches today (executed in this session) consumed those findings; the orchestrator may have additional follow-ups (tier-table refresh flagged, array→algebra-modular pruning explicitly deferred). Disposition: leave unchanged — orchestrator-owned, in-flight per [REFL-009a]'s no-touch-wins rule for active topics.

## What Worked and What Didn't

**Worked**

- Reading prior research before editing: `swift-institute/Research/witness-macro-algebra-types-assessment.md` (2026-03-04 DECISION) confirmed 14 catalog count and the marker-only nature of the conformance; `swift-algebra-primitives/Research/deferred-work.md` v2.0.0 confirmed `.z2(via: Iso)` is the canonical Z₂ transport mechanism. Both prevented design retreat.
- Verified `Algebra_Primitives` umbrella's `@_exported public import Algebra_Primitives_Core` chain BEFORE depending on it: meant `.z2` files needed no source-edit beyond parameter type rename — `.init(forward:..., backward:...)` re-binds to `Algebra.Iso.init` automatically via type inference.
- Per-package serial clean-build (per `feedback_no_parallel_swift_builds`) at each step — caught no errors but provided fast confidence.
- Workspace consumer scan returned zero hits for both bridges, both times. The bridges were truly self-contained, validating the choice to NOT add `@_exported public import` re-exports for the moved types.
- Per-step commits (separate commit per package) — consistent with the prior memory/system task's per-package commit discipline; matches `[HANDOFF-019]` commit-as-you-go.
- Took the prior-task tier-table flag and re-flagged it without bundling, per task constraints.

**Didn't Work**

- Initial grep regex was non-exhaustive on the conformance enumeration. The brief cited 5 sites from a verified prior count; the brief's own regex (or my reproduction of it) was syntactic-pattern-narrow. Cost: one re-grep round-trip; no silent miss because I caught it pre-edit. Could have been a silent miss if I'd taken the brief's "5 cited sites" at face value and not re-grep'd.
- Edit tool's "must Read first" friction: when files were inspected via `cat` in Bash, Edit refused the first call until I Read them. Caught early; minor latency cost.
- The `primitives` skill's tier-table is now drift-stale on TWO axes from this session's work (system-primitives no longer Tier 0; algebra packages drop witness/optic/dependency from transitive dep sets) plus the prior session's. Still flagged-but-unfixed per task constraint. Risk: tier-table drift compounds with each session that flags-without-fixing.

**Confidence assessment**

- High: the design correctness ("L1 doesn't depend on L-higher" arg). Both reverses follow the same shape; both have no consumer impact; both satisfy the parent conversation's stated direction. The Iso-as-math-not-software-pattern argument is principled (cited `deferred-work.md` §2 Z₂ transport).
- Medium: scope expansion to module + semilattice. The brief's 7-package list excluded these but they had the same conformance pattern. I judged inclusion correct (per `feedback_per_wave_inventory_must_be_exhaustive`); if the orchestrator preferred narrow scope, this would have been a class-(b) escalation question, but the constraints permitted the algebra+finite+bit set so I treated it as expected scope per [HANDOFF-018]'s "is my situation the class of case the rule had in mind?" check.
- Medium-low: the tier-table being un-touched is a known load-bearing gap; my report flags it but doesn't fix it. Anti-pattern risk: deferral as procrastination dressed as caution per [REFL-006]'s "future work verification" check. Counter-argument: the explicit task constraint forbade bundling, and the gap requires a separate small-but-not-trivial computation across all 61 primitive packages.

## Patterns and Root Causes

**Pattern 1: empty marker conformance is a layer-inversion vehicle.** A protocol with zero requirements can pull entire dep clusters down a layer in service of "identity claim" semantics. The 14-site Witness.Protocol case dragged witness-primitives → dependency-primitives down to L1 algebra. Removing it had zero functional effect — the marker was load-bearing only on a software-pattern-identity axis, not a code axis. The bridge to memory/system case is the structural twin: a small two-extension file in the wrong package dragged system-primitives down to memory-primitives' core. Same shape: small surface area, large transitive dep cost, zero functional payload at the use-site.

**Pattern 2: enumeration regex shape gap is a recurring failure mode.** The session's [HANDOFF-040]-class instance: brief enumerated 5 Witness.Protocol sites via a regex that matched `: Witness.\`Protocol\`` and `Witness.\`Protocol\`,` but missed `Sendable, Witness.\`Protocol\``. [HANDOFF-040] addresses literal vs generic-instantiated forms (`Type.Member` vs `Type<X>.Member`). This session hit the parallel axis: form-position variants in conformance lists (`: X` vs `Sendable, X` vs `Sendable, X,`). Same root: the enumerator wrote a regex that captured the "obvious" syntactic shape and missed semantically-equivalent but syntactically-distinct neighbors. The semantic category (struct conforms to X) is broader than any single regex; either narrow enough to match all forms (`X\`Protocol\`` would have caught all 14) or supplement with semantic anchors (per [HANDOFF-031]'s syntactic-vs-semantic disclaimer).

**Pattern 3: layering inversions are accreted, not designed.** Both reverses flipped a dep direction that was the wrong way around — and both originated as small bridges added for convenience. `Memory.Page.swift` was 15 lines. The `.z2(via: Optic.Iso)` parameter was 1 type reference. The bridge files entered the dep tree in service of a small affordance; once in, the heavy transitive cost (full algebra → witness → dependency tree, full memory → ordinal/cardinal/carrier/affine/tagged/property/index/bit/error tree) was invisible at the bridge author's desk. The audit-then-reverse cycle is the corrective; the absence of an audit at write-time is the recurring root.

**Pattern 4: read-only audit before write-edit dispatches works.** The prior `HANDOFF-ds-dep-necessity-audit.md` did the static analysis once; both subsequent dispatches consumed its findings without re-investigating. This is the inverse of the pattern in [HANDOFF-024]'s "empirical-grep-first at scope-expansion blockers" — applied proactively at scope-bound rather than reactively at scope-expansion. Cheap pre-audit dispatch reduces follow-up dispatch ambiguity to zero.

## Action Items

- [ ] **[skill]** handoff: Generalize [HANDOFF-040] (literal vs generic-instantiated grep) to a broader class — *form-position variants in conformance/inheritance lists*. Concrete amendment: add a new patterns row to [HANDOFF-040]'s pattern-coverage table covering `: X`, `Sendable, X`, `protocol P, X`, etc., with the canonical narrowing (`X\`Protocol\`` or equivalent symbol-anchored form). Provenance: this session's 5-vs-14 conformance-site gap on the algebra/witness reversal.

- [ ] **[skill]** primitives: Update the Tier 0 list and the 13-tier table to reflect (a) swift-system-primitives now depends on swift-memory-primitives' Core target so it is no longer Tier 0; (b) witness-primitives, optic-primitives, dependency-primitives drop out of the algebra packages' transitive dep tree, which may shift several algebra-* packages' tier classification; (c) swift-memory-primitives' Tier 12 placement should be re-derived from current deps (it lost system, kept the rest). Pre-requisite: small audit pass across all 61 primitive packages computing `tier = max(tier[dep]) + 1`. Two consecutive sessions (memory/system + algebra/iso) both flagged-without-fixing — the gap is now compound.

- [ ] **[research]** Layering-inversion-via-small-bridge as an ecosystem class. Two instances surfaced in two days: memory→system via Memory.Page.swift, algebra→optic via .z2(via: Optic.Iso). Both share the structural shape (small bridge, large transitive cost, zero use-site payload). Worth a targeted research doc enumerating other instances (likely candidates: any L1 package with a single-file integration into a higher-layer concept) and proposing a write-time discipline that catches this at bridge-author-time, not at audit-time. Destination: `swift-institute/Research/`.
