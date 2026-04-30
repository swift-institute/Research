---
date: 2026-04-24
session_objective: Execute the AUDIT-0.1.0-release-readiness.md brief for swift-ownership-primitives through all phases, pivoting to a merit-based design review + workaround revalidation mid-session.
packages:
  - swift-ownership-primitives
  - swift-property-primitives
  - swift-institute
status: processed
processed_date: 2026-04-30
triage_outcomes:
  - type: skill_update
    target: memory-safety
    description: "[MEM-SEND-006] Compiler-Limitation-Citing @unchecked Sendable Requires Revalidation Anchor."
  - type: skill_update
    target: research-process
    description: "[RES-020a] Total-Taxonomy / Lattice-Position Justification for Foundational Packages — merit framing MUST drive add/remove decisions for total-taxonomy packages, NOT adoption count."
  - type: no_action
    description: "AI 3 (5-axis lattice in Research doc) — operational framing already codified in [RES-020a]; lattice docs in Research/ownership-types-usage-and-justification.md per reflection pointer."
---

# Ownership-primitives pre-0.1.0 audit + workaround revalidation

## What Happened

Session goal: execute the 3-phase `AUDIT-0.1.0-release-readiness.md` brief for `swift-ownership-primitives` through the 0.1.0 tag gate.

Executed (15 commits on ownership-primitives `main`, local only):

- Phase 0: V12 `Ownership.Inout.value` accessor split committed (from the V12 parent-session investigation).
- Phase 1: README (mirror property-primitives shape), DocC catalog (landing + tutorial + 14 per-symbol articles + 4 topical articles per `[DOC-019a]`), 2 seed experiments, test expansion 24→84 in 33 suites.
- Phase 2: systematic source audit. Found 2 CRITICAL/HIGH `where Value: ~Copyable` omissions on `Ownership.Unique` / `Slot` extensions — `take()` / `hasValue` / `isEmpty` etc. were silently gated to `Copyable` `Value` (fix applied + regression tests). Modularized into 12 library products per `[MOD-015]` primary decomposition (Namespace + Core + 8 variants + StdLib Integration + umbrella + Test Support). Code-surface polish (Retained.take → extension, Mutable body methods → extensions, `@inlinable` audit, docstring reorderings). Consumer narrow-import migration of swift-property-primitives (46/46 tests green).
- Phase 3: release-readiness checklist. Package metadata clean; no TODO/FIXME/@_spi; `.gitignore` covers; staged `git tag -a 0.1.0` command in `Audits/audit.md` but DO NOT EXECUTE without principal authorization.

Mid-session pivot: user asked for merit-based + completeness + naming evaluation of each `Ownership.*` type (not usage-based). Produced `Research/ownership-types-usage-and-justification.md` v1.0.0 (usage-centric) → v2.0.0 (merit-reframed) → v2.1.0 (after experiment findings landed). Also ran `/experiment-process` to revalidate 4 workaround claims: 3 STILL PRESENT on Swift 6.3.1 (static-stored-in-generic, nested-protocol-in-generic SE-0404, generic-thin-fn-ptr bitcast); 1 FIXED (cross-target Token-extension mangling — allowed moving `Cell.Token.take()` / `Storage.Token.store()` to constrained extensions); 1 REFUTED (the "~Copyable generic blocks Sendable inference on class" claim — `Ownership.Shared` simplified to plain `Sendable`, dropping `@unsafe @unchecked`).

Parked per `[AUDIT-017]`: 26-finding "Design Review — 2026-04-24" section in `Audits/audit.md` across 7 categories (5 naming rename clusters, 2 completeness gaps, 5 validated claims, 10 not-yet-validated, 6 explorations, 4 docs polish, 4 downstream items).

HANDOFF.md written at package root with full Next Steps / Open Questions / Constraints for the resuming session.

Companion commits:
- `swift-institute/Experiments`: 3 new experiments (2 STILL-PRESENT workarounds, 1 refutation of the Sendable-inference claim)
- `swift-property-primitives`: narrow-import migration commit `b4ae443` (bundled with pre-existing V12-parent WIP in same files — flagged honestly in commit message).

**HANDOFF scan (per [REFL-009])**: 1 file in this session's cleanup authority (`swift-ownership-primitives/HANDOFF.md`, written this session, Next Steps pending principal decision — annotated-and-left). Out-of-authority: ~15 HANDOFF-*.md files at `/Users/coen/Developer/` and `/Users/coen/Developer/swift-primitives/` roots from other sessions — not touched. 1 AUDIT-prefixed dispatch (`AUDIT-0.1.0-release-readiness.md` at package root, gitignored local-only) — annotated with completion status since Phase 0.2 (CI green) is DEFERRED, not all work complete.

**Audit cleanup (per [REFL-010])**: the Phase 2 audit section has 6 RESOLVED / 1 OPEN / 2 DEFERRED statuses already reflecting the in-session fix work; the Phase 3 and Design Review sections were written in-session with status-accurate intent. No status updates needed.

## What Worked and What Didn't

### Worked

- **Phased brief kept focus**. The 3-phase structure from the brief gave the session a deterministic path through the work. `[HANDOFF-019]` commit-as-you-go discipline paid off — each phase produced a self-contained commit that survives independently.
- **Workaround revalidation via /experiment-process**. Running minimal reproducers of each justification-cited workaround caught two that were stale:
  1. The Token-extension cross-target-mangling "constraint poisoning" was a stale-.build-cache artifact, not a real Swift limitation — caught by `rm -rf .build && swift test`. Extensions moved to correct location per `[API-IMPL-008]`.
  2. The "`~Copyable` generic blocks Sendable inference on class with immutable payload" claim on `Ownership.Shared` is false on Swift 6.3.1. Doc comment was inherited from a pre-6.3 era and never revalidated. Source simplified to plain `Sendable`.
- **Modularization landed cleanly**. 12-product decomposition built first-try after fixing a circular dep on `__Ownership_Borrow_Protocol` (moved Core → Borrow Primitives). Consumer migration was mechanical.
- **Design Review parking per [AUDIT-017]**. Using `Audits/audit.md` as the parking destination for 26 findings-with-status gave the user a crisp decision surface. The 5 naming clusters are each a labeled DEFERRED finding with severity, location, and a recommendation.

### Didn't

- **First-pass usage-based evaluation was wrong-framed**. My v1.0.0 research recommended DEPRECATING `Ownership.Transfer.Storage` + `Transfer.Box` based on zero ecosystem usage. User correctly reframed: for foundational / total-taxonomy packages, types are evaluated by their position in the domain lattice, not by adoption count. v2.0.0 reversed the DEPRECATE verdicts. I had to be told this.
- **Accidentally committed to wrong repo**. During the Research v1.0.0 commit, my shell was in `swift-property-primitives` (leftover from the consumer-migration work). `git add -A` picked up pre-existing property-primitives WIP + my ownership research file — commit went to the wrong repo. Recovered via `git reset HEAD~1`. Root cause: no `pwd` verification between repos.
- **Initial Token-extension "exception" accepted without revalidation**. I hit the linker error, added a NOTE comment justifying keeping the method in-body per `[API-IMPL-008]` exception, moved on. User asked to validate the claim; clean rebuild showed no failure. The exception was a false workaround. A `rm -rf .build` pass before adopting the exception would have caught it — `feedback_clean_build_first` was relevant and not consulted.
- **Initially claimed "Audits/_index.json created" when the file was gitignored**. Not tracked in git; the audit.md mention is accurate for disk state but misleading for commit state. Fix: made the audit.md description accurate.

## Patterns and Root Causes

### Workaround justifications age silently

Two of five revalidated claims (Token-extension cross-target, Shared Sendable-inference) were STALE on Swift 6.3.1 despite being cited as active constraints in source doc comments. Both came from earlier Swift versions; both survived via doc-comment inheritance across refactors; neither had an associated experiment that could have triggered revalidation when toolchain versions advanced.

This isn't unique to this session. `feedback_toolchain_versions.md` notes "only use Swift 6.3 and 6.4-dev nightly; never test against 6.1"; `swift-6.3-fix-status.md` memory tracks revalidated bugs. But there's no discipline requiring that `@unchecked Sendable` justifications cite the specific experiment that established them. The rule exists for `// WORKAROUND:` code comments per `[DOC-045]` (must include WHY / WHEN TO REMOVE / TRACKING), but not for the common case of `@unchecked Sendable` annotations where the justification lives in prose doc comments.

Failure mode: inherited workaround becomes load-bearing in 0.1.0's API design (extra type parameter, extra accessor, extra trust boundary). The inheritance is invisible unless someone remembers to re-run the claim.

### Merit vs usage for foundational packages

My instinct for "should we include this?" is "who uses it?". That's the right framing for application-layer code, where each feature justifies itself by consumer demand. For foundational primitives whose mission is to define a domain *totally* (the ownership lattice), the framing inverts: each type is justified by its unique position in the taxonomy, and absence is a *gap*, not a *signal of low demand*.

The two frames point in opposite directions. Usage-based reasoning deprecates types with zero consumers. Merit-based reasoning *adds* types when the lattice has empty cells. For a "primitives" package at L1 of the ecosystem, the layer commits to completeness; the evaluation must commit to merit.

This is an extensible pattern — similar traps lurk in every primitives package. What's the taxonomy this package is trying to be total for? Answer that, then evaluate by position, not by downstream demand.

### Clean-build discipline as a pre-condition for workaround adoption

`feedback_clean_build_first` exists. I didn't consult it when the Token-extension cross-target link failure first appeared. Adding a NOTE comment justifying an `[API-IMPL-008]` exception is a consequential act — it's encoding a claim into the package's design rationale. The discipline ought to be:

1. Observe the failure.
2. `rm -rf .build && swift build && swift test` to rule out stale-cache.
3. Only if the failure reproduces from clean → accept and document the workaround.

I did 1 and 3; I skipped 2. The fact that memory contained a rule for exactly this case and I didn't consult it is the meta-pattern. The post-commit memory scan added to `[REFL-006]` targets this class of gap.

## Action Items

- [ ] **[skill]** memory-safety: Add a requirement that `@unchecked Sendable` annotations whose justification cites a compiler-limitation claim (e.g., "X blocks Sendable inference", "X must use UnsafePointer") MUST cite a revalidation experiment (per `/experiment-process`) that can be re-run on toolchain bumps. Mirrors `[DOC-045]` WORKAROUND template (WHY / WHEN TO REMOVE / TRACKING). Without the experiment anchor, the annotation's justification ages silently. Provenance: this session's `Ownership.Shared` simplification (refuted claim) + Token-extension revalidation (FIXED workaround).
- [ ] **[skill]** research-process: Add to `[RES-020]` or as a new rule that for foundational / total-taxonomy packages, per-type evaluation MUST be framed by position-in-the-domain-lattice (merit), not adoption count (usage). Decision test: *"does this package aspire to cover a domain completely, such that adding a type fills a lattice cell, not a consumer need?"* If yes → merit framing is mandatory; deprecation by adoption count is forbidden.
- [ ] **[package]** swift-ownership-primitives: Record the 5-axis lattice (lifetime × mutability × ownership-multiplicity × sync × copyability) in a Research doc (or promote it into the `Research/ownership-types-usage-and-justification.md` v2.1.0 already written) as the canonical justification basis for future type additions. Any new type added to the package must cite the lattice cell it fills; any proposed removal must prove the cell is no longer needed.
