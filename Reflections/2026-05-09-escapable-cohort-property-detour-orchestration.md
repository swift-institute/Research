---
date: 2026-05-09
session_objective: Orchestrate ~Escapable adoption across Pair / Either / Product cohort, then a Property+Ownership detour, then hand off the raw-address-form init cascade. Acted as supervisor across three subordinate dispatches.
packages:
  - swift-pair-primitives
  - swift-either-primitives
  - swift-product-primitives
  - swift-equation-primitives
  - swift-hash-primitives
  - swift-comparison-primitives
  - swift-property-primitives
  - swift-ownership-primitives
  - swift-collection-primitives
  - swift-institute (Research)
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: SkillUpdate [HANDOFF-047] Writer-Side Primary-Source Sampling for All Paraphrased Technical Detail (consolidates entry 5 memory-entry-cited prescriptions + entry 6 paraphrased technical detail + entry 7 concrete-number primary-source sampling). NoAction [SUPER-NNN] triple-toolchain refined rule covered by [SUPER-037] Build-Warning Classification + existing [PKG-BUILD-*] practices. NoAction [AUDIT-NNN] Deferred/Resolved Capabilities pattern is audit-skill amendment deferred (small but real, candidate for follow-up).
---

# ~Escapable Cohort + Property Detour Multi-Chat Orchestration

## What Happened

Multi-day arc, single supervisor chat (this one) coordinating three subordinate dispatches:

**Phase A — Cohort followups dispatch** (`HANDOFF-escapable-cohort-followups.md`):
The forums-review skill's outputs on swift-pair-primitives, swift-either-primitives, swift-product-primitives surfaced an 11-item punch list. Subordinate worked through it: cross-package conformer audit (A) clean; sibling institute protocol survey (B) found 0 mechanical candidates needing upgrade (all already done) plus 6 non-mechanical surfacing per-candidate decisions; DocC + README updates (C); test coverage for institute conformances on ~Escapable arms (D); @frozen deferred-deinit research note (E); Codable formal disposition note (F); CI matrix verification (G) showed swift-product-primitives Ubuntu 6.4-dev nightly Release-mode SILCombine crash (filed as #88987); mixed-suppression arm test (H); equal-arm methods on Either (I) deferred on two-toolchain failure mode; var left/right accessors (J) Path A shipped, Path B deferred; upstream Swift compiler bugs (K) — three filed: #88985 (pack-expand CSE assertion), #88986 (`@_owned consuming get` on generic ~Copyable enum), #88987 (Product Ubuntu nightly Release SILCombine).

The Item B Candidate 2 (Collection.Protocol upgrade) hit a structural blocker: Collection.Protocol+ForEach's `Property<Collection.ForEach, Self>.Inout` accessor cannot admit `Self: ~Copyable & ~Escapable` because Property's Base parameter was `~Copyable` only. Subordinate took Path A (rollback the attempt; capture deferral pointing at a separate dispatch).

**Phase B — Property+Ownership detour** (`HANDOFF-property-primitives-escapable-upgrade.md`, superseded):
Spawned a fresh chat. Phase 0 discovery surfaced two findings: (1) the Property.View family the handoff prescribed re-adding `~Escapable` to had ALREADY been renamed to Property.Inout/Borrow + `~Escapable` already restored at HEAD `49dce56` (commits `acec3c5`, `a372ee0`, etc.) — my handoff was stale on this entire half of its scope; (2) Tagged itself was fine, but Ownership.Inout's `Value: ~Copyable` constraint blocked Property's Base widening — scope-expansion needed.

User authorized the ownership-primitives expansion. Phase 0.5 characterized the cost (~50-line file rewrite mirroring solved Ownership.Borrow precedent). Phase 1 produced three CONVERGED research notes (institute-wide DECISION + per-package execution notes). Phase 2 sequenced cascade: ownership-primitives `30f44a2` first, property-primitives `5bb2f67` second, swift-institute/Research `773992e` third. Phase 3 surfaced a partial-resolution finding: type-level admission cleared, but `Property.Inout(_:)` inout-init signature still requires Escapable, so Collection.Protocol+ForEach's parked widening hits a NEW boundary.

**Phase C — Next-dispatch handoff** (`HANDOFF-property-inout-raw-address-init-cascade.md`, just authored):
Authored the next dispatch covering raw-address-form inits on Property.Inout/Borrow + Collection.Protocol+ForEach + Collection.Count.View widening + ~45 downstream consumer cascade. Sequenced Chat A (detour) close-out → Chat B (cohort) close-out → fresh chat for the new dispatch.

**Cross-cutting artifacts**: 5 ecosystem-wide research notes at `swift-institute/Research/` (escapable-support-pair-either-product, noncopyable-property-extract-via-underscore-owned, escapable-cohort-deferrals via subordinate, frozen-noncopyable-deinit-tradeoff, codable-untyped-throws-disposition, property-ownership-escapable-base-upgrade). Per-package research + experiments in cohort packages. Per-package `Audits/audit.md` Deferred Capabilities sections (gitignored). Three upstream Swift compiler bug filings.

**Refined ground rule shipped mid-arc**: triple-toolchain "MUST pass" gate refined to "no NEW regressions; pre-existing documented baseline failures verified independent via git-stash-baseline + accommodated by package CI policy MAY be accepted with commit-message citation; MUST NOT silently expand scope to fix them." Triggered by Optional+take.swift's RegionIsolation nightly noise.

**HANDOFF scan ([REFL-009])**: 3 files in cleanup authority — `HANDOFF-escapable-cohort-followups.md` (annotated substantively closed by Chat B), `HANDOFF-property-primitives-escapable-upgrade.md` (annotated superseded by Chat A), `HANDOFF-property-inout-raw-address-init-cascade.md` (fresh dispatch authored this session, pending verification — leave as-is). All three correctly handled by the close-out chats and this session; no deletions appropriate yet (next dispatch is in flight; the cohort and detour annotations preserve accountability trail). The other 40+ HANDOFF-*.md files at `/Users/coen/Developer/` are out-of-session-scope.

## What Worked and What Didn't

**Worked well**:
- **Framework-then-apply orchestration**. User asked "give me a framework to decide outstanding items"; I delivered principled axes (mechanical-ness; correctness-driver; repro-quality; filing-identity); user said "apply it"; I delivered the two-sentence resolution per item. Cleaner than direct decision-making — the framework is reusable, the user retained agency over the abstract decision while delegating mechanical application.
- **Class-(b)/(c) triage discipline**. Most decisions class-(b) decided inline (ground-rule interpretation, scope clarification, cost framing). Class-(c) escalated to user only at genuine policy boundaries (push authorization, scope expansion to non-cohort packages, public bug filings).
- **Cost-to-verify gate for upstream bug filings**. Bugs 1+2 had minimal+verified repros and well-bounded diagnostics → filed. Bug 3 candidate was unverified; subordinate spent ~30 min extracting a clean repro from the Product Map test, then filed (#88987). Pattern generalizes.
- **Sequenced multi-chat close-out**. Chat A (detour) → Chat B (cohort-followups) → new chat for next dispatch. Each chat's audit.md scope was non-overlapping; Chat A's hand-back paragraph landed in cohort-followups.md before Chat B's cohort-deferrals consolidation; no file conflicts.
- **Refined ground-rule mid-arc**. The triple-toolchain "MUST pass" → "no NEW regressions" refinement, triggered by Optional+take.swift's documented pre-existing nightly noise, generalized cleanly. Subordinate caught the conflict before pushing; supervisor adjudicated; rule shipped forward to PUSH #2 + PUSH #3 + the next dispatch.

**Didn't work well**:
- **Writer-side handoff staleness**. I authored `HANDOFF-property-primitives-escapable-upgrade.md` citing a memory entry (`copypropagation-nonescapable-fix.md`, 2026-03-25) without verifying live source. The Property.View → Property.Inout/Borrow rename had already shipped (commits `acec3c5`, `a372ee0` etc.); the `~Escapable` re-adoption was already in place at HEAD `49dce56`. Subordinate's Phase 0 caught it via direct source verification — the handoff lost ~half its prescribed scope to "already done" status. The detour did not waste real work (Phase 0 verification is cheap), but the handoff misled on its own scope at write time. Cost ~30 minutes of subordinate time to surface and re-scope.
- **Memory-entry-as-prescription staleness**. The deeper failure mode: the memory entry I cited was itself stale — it said "re-add `~Escapable` to Property.View" but Property.View no longer existed; the prescribed action was both already completed and pointed at types that had been renamed. Memory entries that prescribe future actions need explicit "Status: SHIPPED at {commit}" annotations to prevent re-citation as if action were pending.
- **Audit.md scope ambiguity**. Initial directive split audit.md updates between Chat A (detour-touched packages) and Chat B (cohort packages) but both had legitimate touch on `swift-institute/Audits/escapable-cohort-deferrals.md`. Resolved by sequencing (Chat A first, Chat B incorporates), but the original directive should have surfaced the cross-cutting file ownership upfront.
- **Item I deferral diagnosis**. Subordinate's empirical finding (equal-arm `map { f }` widening compiles in isolation but breaks under (a) Swift 6.3.1 lifetime checker + (b) overload-resolution ambiguity for Either<T,T> Copyable+Escapable) is two distinct toolchain failure modes both gating the ship. The "deferred pending both" outcome is correct but reads as one failure mode in summaries — easy to misread. Deferred-with-multiple-triggers items should explicitly enumerate the AND in the trigger.

## Patterns and Root Causes

**Writer-side prior-state verification gap (the highest-frequency defect)**. [HANDOFF-013a] codifies writer-side prior-research grep. [RES-023] codifies empirical-claim verification. Both rules existed; both fired in spirit on this arc; neither caught the property-view-rename premise-staleness in my handoff. The defect class is: *citing a memory entry or research note as the source of truth for a prescription, without re-verifying that the prescribed state still maps to live source*.

The structural fix isn't "be more careful." It's mechanical: any handoff that prescribes a structural change MUST run a 30-second `grep` + `head` + `git log -1` against the named types/files at write time. If the prescribed action is already complete, the handoff scope shrinks before authoring continues. The cost is bounded; the cost of a stale handoff is unbounded (re-scope + Phase 0 surfacing + occasionally duplicated work).

This generalizes to memory entries: an entry that says "re-add X to type Y" is a prescription. Prescriptions decay. Memory entries that prescribe future actions need a Status field — "Status: SHIPPED at {commit}" annotations transform decayed prescriptions into historical record without losing the rationale. Without the field, every future re-citation re-prescribes the already-shipped action.

**Refined-rule-mid-arc as a productive supervisor pattern**. The triple-toolchain "MUST pass" → "no NEW regressions" refinement happened because the rule's intent (catch new regressions across cross-platform builds) and its strict reading (each toolchain MUST pass before push) diverged on a real case (Optional+take.swift documented pre-existing noise). The supervisor doesn't need to anticipate every edge case at handoff write time; the supervisor needs to be reachable when the subordinate surfaces a conflict, and the refinement needs to ship forward in the same arc so subsequent steps benefit.

The pattern is: ship rules that work for the ~80% case; surface conflicts as escalations; refine when the surface justifies; carry the refinement forward. The alternative (over-specifying ground rules at handoff write time to cover every edge case) produces over-restrictive handoffs that the subordinate has to violate or escalate around. Better to start strict and relax with cause than start loose and tighten under pressure.

**Cost-to-verify gate for noise triage**. Bug 3's "extract repro if ≤30 min, else triage as advisory" rule generalizes: any time a session encounters apparent upstream noise, the gate is a bounded extraction attempt. ≤30 min produces actionable upstream filings; >30 min documents the noise without forcing a productive deflection. The rule's value is converting "is this worth filing?" from a judgment call into a mechanical test.

**Multi-chat orchestration coordination cost**. Three subordinate dispatches across the arc: cohort followups → property+ownership detour → raw-address-form init cascade. Real coordination overhead surfaced: (a) audit.md cross-file conflicts when both chats own deferred-capability sections that compose; (b) handoff staleness when one chat's wrap-up updates SHAs that another chat's pre-flight assumes; (c) predecessor-retirement [HANDOFF-039] discipline (the detour handoff needed an explicit "Superseded by" annotation, accomplished by Chat A). The [HANDOFF-043] multi-cohort pattern partly addresses this. Concrete additions from this arc: explicit cross-cutting-file ownership in close-out directives; sequencing notes ("run Chat A first, wait for confirmation, then Chat B") in supervisor instructions; predecessor retirement as standard close-out step.

**Live-state stronger than reproducer**. Subordinate twice surfaced "verification spike not needed" findings via [SUPER-024] (precondition unmet). Once for Property.View ~Escapable re-adoption (already shipped — no spike needed); once for #88022 verification (live-source-build-clean across triple toolchain is stronger evidence than a standalone reproducer would produce). Pattern: when the live state covers the proposition the spike would test, the live state IS the verification.

This is a useful generalization of "test what's actually used, not what's hypothetically vulnerable." For institute work, the live state is right there in source; the synthetic repro often duplicates what the live source already proves. Worth codifying as a [RES-*] or [SUPER-*] rule.

## Action Items

- [ ] **[skill]** handoff: Add a writer-side prior-state verification step to [HANDOFF-013a] explicitly extending to memory-entry-cited prescriptions. The current rule covers research-doc citations; this arc surfaced that memory-entry citations need the same discipline. Specifically: when a handoff prescribes a structural change citing a memory entry as the source, the writer MUST `grep` + `head` + `git log -1` the live source for the prescribed types/files before authoring the prescription, OR explicitly mark the prescription as "verify-only" if live-state already matches.

- [ ] **[skill]** supervise: Codify the triple-toolchain refined rule as [SUPER-*] (or [PKG-BUILD-*]): "Triple-toolchain verification MUST surface no NEW regressions. Pre-existing documented baseline failures (a) verified independent via git-stash-baseline, (b) documented in source comments or upstream-tracked issues, AND (c) accommodated by package CI policy MAY be accepted with commit-message citation. Silent scope expansion to fix pre-existing failures is forbidden without authorization." This generalized cleanly mid-arc; should land as durable rule.

- [ ] **[skill]** audit: Add a "Deferred Capabilities" / "Resolved Capabilities" section pattern to [AUDIT-*] alongside the per-skill findings tables. Captures operations-completeness state (capabilities deferred + reasons + triggers to revisit; capabilities resolved + commits) without bending [AUDIT-011]'s compliance-not-ops-completeness scope. The audit.md files in this arc shipped this pattern; codifying lets future audits adopt without re-deriving.
