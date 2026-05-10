---
date: 2026-05-09
session_objective: Take over supervisor role mid-arc on the active ~Escapable cascade dispatch; orchestrate it to substantive close; then orchestrate a surgical prune of the Property+Collection tier when the cascade's runtime call-site pattern was discovered to be language-blocked.
packages:
  - swift-property-primitives
  - swift-collection-primitives
  - swift-ownership-primitives
  - swift-institute
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: SkillUpdate [HANDOFF-047] consolidates Pattern 2 generalized writer-side discipline. SkillUpdate [SUPER-041] Calibration: Option-Matrix to Recommendation-First on User Trust Signal (entry 6 AI 2). NoAction [SUPER-NNN] CI-status-delta as automatic diagnostic deferred (narrow workflow detail, candidate for follow-up).
---

# Cascade-Tail Prune Supervision Arc and Three-Strikes Writer-Side Staleness

## What Happened

Taken-over supervisor role mid-arc via `HANDOFF-supervisor-relay-property-inout-cascade.md`. The active dispatch (`HANDOFF-property-inout-raw-address-init-cascade.md`) was in flight; subordinate had completed Pre-Flight + Phase 0 escalation already adjudicated by prior supervisor. My session covered:

**Original cascade dispatch wrap** (5 supervisor turns, ~3 hours):

- Phase 0 → 1: subordinate's bucket-(b) inventory (2 files: Collection.Protocol+ForEach + Collection.Count.View) + design decisions sign-off. Two-doc Phase 1 shape confirmed. Class-(b) inline.
- Phase 1 → 2: read-not-summary review per [SUPER-009] of two CONVERGED design docs (`property-inout-raw-address-init.md`, `escapable-protocol-foreach-count-view.md`). Mechanically verified Ownership.Inout/Borrow precedent shape at `30f44a2:113-139` and `:257-284`. Material new finding (Doc 1 §B + Appendix A: Swift's implicit `inout T` → `UnsafeMutableRawPointer` conversion admitting `~Escapable T`) classified as per-package documentation, not institute-wide elevation.
- PUSH #1 framing → user authorization: swift-property-primitives `be0e3a2` shipped — 7 raw-address-form inits across Property.{Inout,Borrow}[.Typed[.Valued[.Valued]]] variants. Class-(c) per [GIT-001].
- PUSH #2 framing → CRITICAL ESCALATION: subordinate's real-code Phase 2 implementation hit `error: overlapping accesses to 'self', but modification requires exclusive access [#ExclusivityViolation]` + lifetime-escape on the documented consumer pattern. Independently reproduced via `swiftc -emit-sil`. Phase 1's `swiftc -typecheck` "verification" was a false-positive — typecheck doesn't run borrow-check; SIL generation does. The view-of-self pattern (`Property.Inout(unsafeRawAddress: &self, mutating: &self)` from `mutating _read`) is structurally uncompilable under Swift's exclusive-access law on dual-`&self` arguments at one call site.
- User adjudicated A+C: corrective amend `9ee0c37` shipped on swift-property-primitives (strikes the misleading consumer-call-site doc comment, replaces with explicit borrow-check-limitation `> Note:` block); doc-only PUSH #2 `2e60130` shipped on swift-collection-primitives (status DEFERRED-TOOLCHAIN). Wrap-up surface received.

**Strategic exploration with user** (~6 turns): user surfaced the evergreen-vs-speculative question on the 7 PUSH #1 inits. After framework axes (mechanical-ness, correctness-driver, cost-to-verify, live-state-vs-reproducer) + the standing `feedback_no_removal_during_development` rule, user chose to suspend the no-removal rule for this case and authorize a surgical prune of the Property+Collection tier. Surgical-vs-blanket cut: keep Ownership tier (institute's broader systematic ~Escapable program; plausible non-view-of-self consumers); prune Property+Collection tier (view-of-self-locked).

**New prune dispatch authored**: `HANDOFF-escapable-property-tier-prune.md`. Six-entry supervisor ground-rules block; pre-flight verification with mechanical commands; phases 0–4. Subordinate executed:

- Phase 0 surfaced 3 corrections to my dispatch: test-count "41 → 48" miscalculation (I assumed `5bb2f67` added 7 base tests; reality: only typealias additions inside existing test files); 3 stale cohort SHAs in dispatch's Current State table (transcription staleness from predecessor handoff); 3 swift-strings comment-only references (not code dependencies). All resolved via Phase 0 → 1 adjudication; ground-rule entry (7) added per [SUPER-015] correcting test-count predicate.
- Phase 1 prune push at `8ea61bb`: revert Sources/+Tests/ to `49dce56` baseline; preserve research notes with `CONVERGED-PRUNED` frontmatter. Subordinate raised push-form ambiguity (force-rewrite vs fast-forward — my dispatch was internally ambiguous); adjudicated fast-forward append (post-publication corrective discipline, precedent set by `be0e3a2 → 9ee0c37` earlier in arc). Force-pushed.
- Phase 1 follow-on warning fix → HALT: User authorized "GO. also fix warnings while we're at it." Subordinate's REMOVE direction triggered Swift 6.3.1 `[#StrictMemorySafety]` regression (toolchain disagreement: 6.3.1 wants the `unsafe` keyword present; 6.4-dev nightly + Embedded say it's redundant). Empirical matrix surfaced: no simple keyword toggle satisfies both. User adjudicated: Option A (revert REMOVE; ship `8ea61bb` as-is; accept 6.4-dev redundancy as baseline noise).
- Phase 2: swift-collection-primitives `c138e61` doc-only forward-amendment (status DEFERRED-TOOLCHAIN-PRUNED; new §L Prune-Outcome section). Regular push.
- Phase 3: cohort hand-back trail at `HANDOFF-escapable-cohort-followups.md` updated.
- Phase 4: wrap-up surface. CI on swift-property-primitives `8ea61bb` returned to **green** (was failing on `9ee0c37` + `be0e3a2`). The cascade itself was the CI-failure cause — confirmed empirically.

**Final state**: 5 commits across 2 PUBLIC repos (3 cascade + 2 prune); cohort base + institute protocols + Ownership tier untouched; all research notes preserved with amended frontmatter; Item B Candidate 2 stays DEFERRED-TOOLCHAIN-PRUNED with language-affordance trigger.

**Side query**: user asked for review of `Blog/Draft/introducing-pair-either-product-primitives.md`. Read in full; surfaced ship-blocker (verify SE-0413 "canonical realisation" claim); recommended compression of conformance paragraph; flagged opener-metaphor-density. Returned to dispatch context after.

**HANDOFF scan ([REFL-009])**: 47 files at workspace root; in-session-scope: 5 (`HANDOFF-supervisor-relay-property-inout-cascade.md`, `HANDOFF-property-inout-raw-address-init-cascade.md`, `HANDOFF-property-primitives-escapable-upgrade.md`, `HANDOFF-escapable-cohort-followups.md`, `HANDOFF-escapable-property-tier-prune.md`). Dispositions: 4 deleted (all complete + ground-rules verified end-to-end), 1 left annotated (cohort hand-back trail, multi-cycle ACTIVE). Other 42 out-of-session-scope per bounded cleanup authority.

## What Worked and What Didn't

**Worked well**:

- **Mechanical verification per [SUPER-022] at every intervention point**. Independently reproduced the borrow-check failure via `swiftc -emit-sil` (matched subordinate's escalation exactly). Verified SHAs landed via `gh api` at each push. Verified working-tree states via `git status`. CI status check at wrap-up confirmed cascade-as-cause hypothesis. The discipline produced load-bearing evidence at each gate; trust-but-verify is mechanical.
- **Read-not-summary discipline on Phase 1 design docs**. Both docs read end-to-end (8000+ tokens combined) before sign-off — the design itself was clean; the verification methodology gap was elsewhere. Discipline applied; no shortcut taken; the docs were structurally correct as written. The methodology gap (typecheck-vs-emit-sil) wasn't a defect of the docs but of the verification framework that produced their §B "empirical" claims.
- **Class-(b) vs class-(c) discipline**. Class-(b) adjudications inline (test-count correction, stale SHA table, swift-strings refs, push-form ambiguity, fix-direction inversion). Class-(c) escalations to user (push authorizations, scope expansions, prune authorization, Option A vs B vs C vs D). Boundary held even under user pressure to wrap up.
- **Surgical-vs-blanket prune cut**. Kept Ownership tier (institute's broader systematic ~Escapable program shipped alongside Tagged + Carrier + cohort base; plausible non-view-of-self consumers); pruned Property+Collection tier (Property's value-add IS the fluent-accessor namespace pattern, which is structurally view-of-self). Cohort base + institute protocols untouched (proven consumers). The cut is principled, not ad hoc — based on each tier's value-add relative to the structural blocker.
- **Subordinate discipline throughout**. Surfaced ambiguities cleanly (push form A vs B); surfaced empirical surprises immediately (warning fix direction, structural blocker); halt-and-surface on regression (REMOVE direction triggered 6.3.1 regression — halted per ground rule, did not silently push). Three writer-side staleness defects in my supervisor framing all caught pre-execution; zero damage shipped.
- **CI-as-diagnostic at wrap-up**. The pre-prune CI failure on `be0e3a2` and `9ee0c37` was a real signal of unknown root cause. Post-prune CI green on `8ea61bb` confirmed cascade-as-cause empirically — without manually digging through logs. CI signal becomes automatic diagnostic when the prune target is the suspected cause.

**Didn't work well**:

- **Three writer-side proposal-staleness defects in the same arc** — same root cause, three surfaces:
  1. **Phase 1 verification methodology**: I authored the cascade dispatch (in the prior chat) treating `swiftc -typecheck` empirical claims as sufficient. Borrow-check rejection only surfaces at SIL generation. Cost: PUSH #1 shipped with misleading consumer-call-site doc comment (corrected at `9ee0c37`); cascade tail eventually pruned.
  2. **"41 → 48" arithmetic miscalculation**: I authored the prune dispatch with test-count predicate "41" based on assumption that `5bb2f67` added 7 base tests symmetric to `be0e3a2`'s 7 admission tests. Reality: only typealias additions inside existing test files. Caught by subordinate at Phase 0 via empirical `swift test` on detached HEAD `49dce56`.
  3. **Unsafe-keyword direction inversion**: I framed Step 2 as "wrap calls in `unsafe(...)` per Swift 6.3 strict-memory-safety" based on misreading prior dispatch's wrap-up. Reality: predecessor §L explicitly stated "REMOVE the redundant unsafe keyword." Caught by subordinate before destructive execution. (Then the actual REMOVE attempt revealed cross-toolchain disagreement requiring Option A revert.)

  All three: writer-side propagation of unverified claims from prior context. The pattern is **carrying-forward technical detail from predecessor or prior-self without re-deriving from primary source at write time**. Working memory's paraphrase of the relevant detail is the input; mechanical verification at write time is the missing discipline.

- **Over-deliberation in user-facing strategic phase**. When user asked "what should we do now?" + "what would you prune?" + "what are the consequences", I produced extended option matrices and analysis — appropriate for first-pass framework-then-apply, but beyond the calibration point where the user signaled trust ("all YES, all authorizations given"). User's "stop discussing so much, do the work" signal arrived after the warning-fix HALT framing. Cost: extra round-trips, friction, eventual user fatigue. The right calibration would be: drop option-matrix structure once user signals trust; lead with recommendation + one-line rationale; offer alternatives only when materially different in cost.

- **Dispatch-internal ambiguity on push form**. Wrote `HANDOFF-escapable-property-tier-prune.md` with conflicting cues across §Goal ("force-pushed back to 49dce56's source state") and §Phase 1 ("Single new commit ON TOP of `9ee0c37`"). Subordinate's Phase 1 framing question caught it cleanly, but write-correct-the-first-time would be better. Root cause: I conflated [RELEASE-013] First-Publication Clean-History (which applies to first publication, force-rewrite-during-iteration) with post-publication corrective discipline (fast-forward append). The cascade IS already published; the prune is post-publication; ordinary push wins. The discipline-conflation in writing is symptomatic of the same paraphrase-over-derivation pattern: I had the discipline correctly internalized; I wrote it without re-checking which discipline applied to the case at hand.

## Patterns and Root Causes

The dominant pattern across the three writer-side proposal-staleness defects: **memorized-paraphrase-as-prescription**. In each case I had the relevant context (prior dispatch's wrap-up; predecessor research note; cascade structure), formed a working-memory representation of the technical detail, and wrote the new instruction *from that representation* rather than re-deriving from primary source at write time.

This is the same defect class the prior arc's reflection (`2026-05-09-escapable-cohort-property-detour-orchestration.md` Action Item #1) named for memory-entry-cited prescriptions. The generalization: **all paraphrased technical detail decays between context-formation and write time**, even within a single session. The prior reflection scoped it to "memory entries that prescribe future actions"; this arc surfaces:

- Predecessor research note empirical claims (the "Default toolchain accepts the unwrapped form" claim from `escapable-base-upgrade.md §L` was correct at authoring time but didn't hold at consumption time)
- Within-session arithmetic from cascade structure (the "41" miscalculation came hours after I had read the relevant material)
- Within-session diagnostic-message text (the unsafe-keyword direction inversion came after multiple intermediate adjudications)
- Cross-discipline application (the [RELEASE-013] vs post-publication-corrective conflation in the prune dispatch's push-form ambiguity)

Working-memory paraphrase is unreliable across all four axes. Mechanical re-derivation at write time is the only stable discipline. Cost: seconds per detail. Forward-prevention rule is generalizable: every technical detail that ends up in a supervisor instruction (test counts, file lists, command shapes, diagnostic message text, line numbers, init signatures, applicable-discipline citations) gets re-derived at write time via the appropriate command (grep, swift test, git diff --stat, swiftc -emit-sil, gh api, the actual skill text). Cite the command alongside the value.

The over-deliberation pattern is different in shape but same in family — over-investing in the *form* of supervision (option matrices, framework-then-apply) when the substance has been settled. The user's trajectory across the arc went: framework-curious early ("give me thoughts on evergreen") → trust-axes mid ("all YES, all authorizations given") → wrap-up-fatigue late ("stop discussing so much, do the work"). The supervisor-side calibration should track this trajectory: full-form on novel decision classes; recommendation-first once axes have been validated; tight relay once the user has signaled trust + the work is mechanical.

The over-deliberation also cost: when the warning-fix HALT surfaced, my response was a 5-option matrix (A revert / B keep / C conditional compilation / D different stdlib pattern / E accept as documented baseline). User's "GO" + scope expansion had implied authorization to act, not to deliberate. The right response for the HALT would have been: "Option A — revert; here's the relay; one line." Instead I produced the matrix; the user's "stop discussing so much" landed after. The cost was friction, not decision-quality (Option A was right and was chosen) — but friction at the wrap-up boundary is exactly when supervisor patience runs lowest.

The CI-as-diagnostic insight is a positive pattern worth keeping. The cascade was failing CI; nobody knew why; the prune was authorized for orthogonal reasons (evergreen scope discipline). Post-prune CI green confirmed cascade-as-cause without manual log investigation. When a prune is targeted at suspected-but-unconfirmed-cause work, the CI signal becomes automatic root-cause confirmation. Worth noting in supervise or release-readiness skill: at prune-or-revert intervention points, the CI-status-delta is a free post-action diagnostic.

The structural-blocker insight (Swift's exclusive-access law on dual-`&self` at call site) is preserved in research notes and the cohort hand-back trail; the re-ship trigger is well-defined (any Swift toolchain user-package mechanism for raw-pointer derivation from `inout self` without dual-borrow violation). The cascade was net-positive *learning*: we now know exactly which language-affordance gap is missing, with `swiftc -emit-sil` reproductions on disk. Re-shipping when Swift provides the affordance is bounded (~1-2 days) because the design space is documented.

## Action Items

- [ ] **[skill]** research-process: extend the existing writer-side prior-research grep discipline ([HANDOFF-013a] family) to cover **all paraphrased technical detail** — test counts, file lists, command shapes, diagnostic message text, line numbers, init signatures, empirical claims from predecessor research notes, applicable-discipline citations. Generalizes the prior arc's Action Item #1 from "memory-entry-cited prescriptions" to "all paraphrased technical detail." Mechanical: cite the command that produced the value alongside the value (e.g., *"55 → 48 (per `swift test` at detached HEAD `49dce56`)"*); subsequent paraphrase-without-citation is a defect signal.
- [ ] **[skill]** supervise: codify a **calibration rule** for user-facing supervision form. After ~3 successive class-(b)/(c) adjudications where supervisor's framework axes hold and user authorizes recommendation without modification, transition from option-matrix format to recommendation-first format (one-line recommendation + one-line rationale + auth phrase). Reserve option matrices for genuinely-undecided situations (cost-comparable alternatives, novel decision class, unknown user preference). The signal is *user trust in the framework*; the response is *form contraction*. Concrete trigger language: when the user has used compressed authorization phrases ("all YES", "GO") at least twice in the session, default to recommendation-first for the remainder.
- [ ] **[skill]** supervise: codify the **CI-status-delta as automatic diagnostic** at prune-or-revert intervention points. When a class-(c) action is targeted at suspected-but-unconfirmed-cause work, the supervisor's wrap-up MUST include the CI-status delta (pre-action vs post-action) as a free post-action root-cause confirmation. Reduces "did the action address the issue?" to a mechanical check; surfaces when CI failure was orthogonal infrastructure rather than the targeted work.
