# Supervise Skill Rationale Archive

<!--
version: 1.0.0
last_updated: 2026-07-02
status: REFERENCE
-->

> Non-normative companion to `Skills/supervise/SKILL.md` (per Research/ecosystem-meta-setup-target-state.md §D1).
> This document holds evicted rationale prose, provenance, extended worked examples, incident narratives,
> and the dated amendment changelog. The skill file remains the CANONICAL source for all `[SUPER-*]`
> requirement statements; nothing in this archive is normative. Organized by rule ID in skill order; the
> dated frontmatter changelog entries are collected in the final section. Where a one-sentence retention
> remains in-skill, the FULL original paragraph is preserved here so no content is lost.

---

## §[SUPER-002a] Scope-Lock Precedes Architecture-Lock

**Example (defect) — full walkthrough** (evicted; condensed retention remains in-skill):

**Example (defect)** — the 2026-04-16 Executor.Main R1→R2→R3 churn:

```
MUST: Architecture Option B (minimal Kernel.Main.Dispatch.async wrapper).
```

— locked without a scope fact; user subsequently imposed platform-agnostic constraint → R2 pivot; R2 locked without `no-Apple-framework` scope confirmation → R3 pivot; R3 locked without `GUI-in-scope` confirmation → R4 pivot. Three architectural reversals driven by implicit scope assumptions surfacing after the architecture was locked.

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Architecture-lock-before-scope-lock is the dominant failure mode observed across multi-revision design sessions. Scope-boundary questions feel like "setup work" compared to the "real work" of comparing alternatives; in reality, architecture comparison against an undefined scope is wasted analysis. A 30-minute scope conversation saves multiple revision cycles.

**Provenance** (evicted verbatim):

**Provenance**: 2026-04-16-executor-main-witness-pattern-four-revision-journey.md; 2026-04-16-supervise-in-practice-three-failure-modes.md (same failure mode, two independent observations)


---

## §[SUPER-003] Mandatory Fields

**Rationale (full text; definitional final sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Anthropic's multi-agent research system identified vague subagent briefs ("research the semiconductor shortage") as the dominant cause of duplicated and off-mark subagent work. The four fields are the empirically-grounded fix. The ground-rules block (per [SUPER-002]) is the *constraint* layer; the four mandatory fields are the *task* layer.


---

## §[SUPER-004] Rationale on Forbidden Entries

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: A MUST NOT with no rationale will be broken the moment a plausible-looking document, research note, or alternative pattern suggests the forbidden approach is sensible. The rationale lets the subordinate recognize the rule's grounding and the principal recognize when the rule could legitimately stop applying.


---

## §[SUPER-005] Question Classification

**Rationale (full text; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Cooperative on facts, strict on scope. The principal's job is to be a useful technical resource for in-scope questions and a reliable boundary for out-of-scope ones. Mixing the two — being strict on facts or cooperative on scope changes — degrades both.


---

## §[SUPER-006] Drift Signal Enumeration

**Rationale (full text incl. the 2026-04-17 user-authorization origin incident; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Magentic-One's Progress Ledger demonstrates that drift detection works only when the signals are enumerated and checked counter-style, not inferred ad hoc. Without an explicit list, the principal misses signals it has not pre-named. The user-authorization qualifier closes a real failure mode observed 2026-04-17: a returning principal applied the original HANDOFF.md's pre-staged recommendations to a draft that had been user-revised during live supervision (length tripled, sections added, branch strategy changed); the subordinate had to push back with structured what-was-revised evidence before the stale critique was withdrawn. Without the qualifier, stale drift signals would have driven the deletion of user-authorized work.


---

## §[SUPER-009] Acceptance Criteria

**Rationale (full text; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Subordinate "I'm done" reports are not acceptance. The handoff research's ATC read-back pattern applies here: the principal MUST verify against criteria the principal authored, not against the subordinate's self-report. Naming the positive source per criterion makes the verification step concrete — the principal cannot skip verification by inferring it happened. The three sources are exhaustive for code-bearing supervision; document-only supervision uses only the disk/git-state and current-file-state rows.

**Read the artifact, not the summary (full paragraph; normative sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Read the artifact, not the summary**: when the subordinate's deliverable at a phase-completion intervention point is a *document* (research note, decision doc, handoff, analysis), the principal MUST read the document itself before approving the phase. The subordinate's summary of the document is an attestation, not verification. Summaries are faster than reads and usually directionally correct, but a summary of a defective document reads as a clean summary of a clean document — only independent read catches the contradictions the author themselves missed. Concrete test: if the approval decision turns on the document's internal consistency (section A doesn't contradict section B; decisions in §Outcome match recommendations in §Analysis; classification in §Scope matches implementation in §Procedure), the principal's read is non-delegable. The 2026-04-16 Executor.Main R3 approval cycle hit this failure: supervisor approved on subordinate summary; independent re-read surfaced five real defects (§3/§11 naming contradiction, §7/§10 `@inlinable` contradiction, misleading §4.2 heading, overbroad Criterion-2 wording, missing pre-step). All were obvious on careful read.

**Verify named blockers exist (full paragraph; normative sentences + probe shapes retained in-skill)** (evicted; condensed retention remains in-skill):

**Verify named blockers exist**: when a HALT doc or dispatch names an external action as a *blocker* between options (App-install, branch-creation, secret-rotation, manual UI step, admin op of any kind), the principal MUST run the relevant state probe BEFORE adjudicating between options. The principal cannot adjudicate "Option α requires X; Option β requires Y" without verifying whether X is actually pending or already in place. Operational state moves under the corpus; subordinate-authored HALT docs encode the subordinate's *belief* about operational state at HALT-write time, not the live state at adjudication time. Generalizes "read the artifact, not the summary" from document-level (subordinate's document vs document's actual content) to environment-level (subordinate's claim about blocker vs blocker's actual state). Origin incident: 2026-05-14 Phase B-2 follow-up adjudication of Option α (Skills cross-repo App-token auth) — HALT doc framed "required admin op: install swift-institute-bot on swift-institute/Skills with contents: read"; verification via `gh api /orgs/swift-institute/installations` revealed the bot was already installed org-wide with `contents: write` since 2026-04-29 (months prior). The "admin op required" framing was operationally moot; principal adjudication that authorized Option α was correct but the implicit cost was incorrect. Probe shape: `gh api /orgs/<org>/installations` for App-installs; `gh api /repos/<o>/<r>/branches/<branch>/protection` for branch protection; `gh secret list -R <repo>` for secrets; whatever state oracle is relevant to the named blocker. Codified per reflection `2026-05-14-ci-review-arc-phase-a-c-supervision-gaps.md` via `/reflections-processing` 2026-05-15.


---

## §[SUPER-009a] Verification Scope Sub-Rule for Acceptance Criteria

**Worked example (the origin incident) — narrative lead-in** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**:

Path X Phase 2 mirrored INVERTED Pattern A across `swift-windows-standard`'s 22-file Pattern A surface. Original criterion #3: "Windows build green at every wave." Empirical reality: no Windows host or cross-compile SDK in workspace; macOS `swift build` of `swift-windows-standard` succeeds in 25s but every Phase 2 source file is wrapped in `#if os(Windows)`, so the build elides every body. The criterion was unverifiable as stated.

**Worked example closing note** (evicted verbatim):

The rewritten criterion is honest about scope and lets future cycles reproduce the verification's actual reach.

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Partial verification dressed as full verification is the failure mode that lets defects pass acceptance gates. The cost of stating verification scope explicitly is one or two extra lines per criterion at authoring time; the cost of acting on a falsely-passed criterion is rework downstream when the elided defect surfaces. Codifying the explicit-scope discipline prevents the next cycle from inheriting the same ambiguity.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-04-29-path-x-phase-2-windows-mirror-execution.md` (Phase 2 acceptance #3 rewrite from "Windows build green" to "best-effort macOS build + canonical pattern citation").


---

## §[SUPER-011] Re-Handoff Composition

**Rationale (full text; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: The handoff inherits the supervisor's ground rules. A new principal picking up the handoff should know which constraints have been verified (and so MAY be relied on) versus which are still open. Without this citation the new principal cannot tell whether to re-verify or trust. Without entry-type-specific evidence forms, "verified" collapses to a checkbox with no audit trail.


---

## §[SUPER-012] Escalation Triggers

**Rationale (full text; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Escalation is correct behavior, not failure. The principal is itself a delegate of the user; questions outside the principal's authority must be returned to the user. Answering from first principles in this case is exceeding authority, which is worse than pausing. The persistence requirement closes a real gap: without it, escalation is the only termination mode that produces no on-disk artifact, and a session that ends with an escalation outstanding loses the question entirely.


---

## §[SUPER-014a] Supervisor in Absentia

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: a subordinate self-authoring constraints in absentia is structurally indistinguishable from drift — re-proposing rejected alternatives, expanding scope, silent decisions on open questions are all [SUPER-006] drift signals, and a subordinate adding new entries to its own constraint set replicates exactly that pattern. The escalation cost (one user-facing question instead of one autonomous answer) is acceptable in exchange for preserving the supervisor block's integrity. The pre-escalation check prevents trivial questions from cluttering the user's inbox when the existing block already answers them.


---

## §[SUPER-015] Progressive Refinement

**Operational trigger (full paragraph; normative first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Operational trigger**: compression MUST fire at whichever comes first — (a) *architectural pivot boundary* (a new revision supersedes ≥3 prior entries, as with R1→R2 or R2→R3 architectural flips), OR (b) *entry-count threshold* (the block would exceed 10 active entries with the next append). Deferring compression until the block "feels too big" in practice results in 30+ entry blocks that become wallpaper and stop being checked. At a pivot, the supersession map is cheapest to author — the principal still holds the motivation for each retiring entry in working memory. Waiting past the pivot makes the compression archaeology, not decision.

**Target ratio (full paragraph; normative first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Target ratio**: compress to ≤6 active entries. The 32→7 compression observed in the 2026-04-16 Executor.Main handoff is the empirical worked example — ~80% of the historical volume was redundant once pivots had resolved.


---

## §[SUPER-017] Tentative-Language Detection at Principal Input

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Exploratory principal-language treated as dispatch creates drift at the principal-subordinate boundary, precisely the boundary `/supervise` is designed to harden. Both sides lose visibility: the principal assumed they were thinking aloud; the subordinate assumed direction was given. Surfacing the tentativeness makes the choice explicit at the cheapest moment — before work begins.

**Provenance** (evicted verbatim):

**Provenance**: 2026-04-21-descriptor-a-audit-close-and-remediation-rhythm.md


---

## §[SUPER-018] Supervisor Re-Reads Skill at Intervention Points

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: The memory of a skill rule degrades across turns in predictable ways: exceptions and examples get dropped first, procedure-text second, scope last. Memorized citations are enough for quick references but not enough for decision-bearing authorizations. The re-read cost is seconds; the cost of a reversed authorization includes subordinate rework, audit-trail cleanup, and a loss of principal credibility that affects the next intervention.

**Provenance** (evicted verbatim):

**Provenance**: 2026-04-21-descriptor-migration-supervisor-flipping-and-v6-convergence.md


---

## §[SUPER-019] Supervisor Objective Hierarchy

**Why each ranking matters (full bullets)** (evicted; condensed retention remains in-skill):

**Why each ranking matters**:

- **Coherence > scope minimization**: Scope-minimizing recommendations that break architectural invariants (e.g., a local rename that creates a namespace collision downstream) shift the cost from "fix the one thing" to "fix the one thing plus the downstream fallout." The supervisor's scope-minimization bias is a common failure mode; the hierarchy forces a coherence check at decision time.
- **Scope minimization > speed**: Speed-maximizing recommendations without scope discipline produce bundled commits that are hard to review, bisect, or revert. Scope discipline slows the commit slightly and accelerates the post-commit work.

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Without an explicit hierarchy, supervisors default to scope minimization (local, visible, measurable) while coherence (global, invisible-until-broken) is implicit. When a session produces three coherence-ground reversals of the supervisor's scope-minimizing recommendations, the defect is a missing priority order, not three independent misjudgments.

**Provenance** (evicted verbatim):

**Provenance**: 2026-04-21-descriptor-migration-supervisor-flipping-and-v6-convergence.md


---

## §[SUPER-020] Pre-Authorization Architectural-Constraint Scan

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Parallels [REFL-006]'s post-commit memory scan, positioned at authorization-time when correction is cheap. Architectural constraints are exactly the class of knowledge that decays from the supervisor's working memory fastest — they are usually consulted when writing code, not when authorizing scope. The mechanical scan restores the rule-check to the authorization point. Observed twice within one week of each other (2026-04-20 and 2026-04-22) as the same supervisor-side [PLAT-ARCH-007] miss; a rule positioned at the authorization point would have fired in both.

**Provenance** (evicted verbatim):

**Provenance**: 2026-04-22-supervisor-arc-investigation-through-cycle-two-dispatch.md (the second occurrence of the pattern class)


---

## §[SUPER-021] Mid-Cycle Principal Decision Revision as Fourth Termination-Avoiding Pattern

**Why only for weakening revisions (full paragraph; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Why only for weakening revisions**: Strengthening revisions (adding requirements, tightening constraints) change the contract in a direction the subordinate did not pre-consent to. Weakening revisions remove load the subordinate was already carrying; re-consent is automatic because the new scope is a subset of the old. The distinction matters because handling both identically would allow silent scope creep disguised as "revision."

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: [SUPER-010]'s three termination modes assume each cycle ends with the original dispatch. Real cycles encounter mid-flight blockers where the principal's optimal response is to revise the spec in-place rather than abort and re-handoff. Denying this path forces either abort (wastes subordinate progress) or silent scope drift (defect). Codifying it as a distinct pattern with three conditions preserves supervision integrity while permitting in-flight adaptation.

**Provenance** (evicted verbatim):

**Provenance**: 2026-04-22-cycle-2-close-beta-prime-and-c-representability.md (β' revision at IP5-second-failure)


---

## §[SUPER-022] Per-Intervention-Point Verification

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Trust-but-verify *per turn*, not only at termination, catches subordinate drift at the earliest point. Accepting subordinate attestations structurally fails because the subordinate has no independent reason to catch the defect the supervision is designed to surface. Mechanical verification is both faster and attestation-proof: the command either returns the expected value or it doesn't, with no ambiguity.

**Provenance** (evicted verbatim):

**Provenance**: 2026-04-21-property-primitives-release-polish-supervised.md


---

## §[SUPER-023] Supervision-Mode Dimension at Invocation

**Rationale (full text; second sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Previously, mode selection was inertia-driven — whatever pattern happened to fit the turn. Naming the three patterns and providing a selection heuristic makes the choice explicit, which surfaces the tradeoffs at the moment they are cheapest to evaluate. The 2026-04-22 Cycle 2 dispatch is the first observed session where the mode was chosen deliberately rather than inherited; the visibility itself improved supervision quality.

**Provenance** (evicted verbatim):

**Provenance**: 2026-04-22-supervisor-arc-investigation-through-cycle-two-dispatch.md


---

## §[SUPER-024] Ground-Rule Compliance Via Inaction

**Rationale (full text; second sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Rules are written for the common case where the prescribed action is the correct action. Executing mechanically when preconditions have shifted inverts the rule's spirit: a rule that exists to *prevent drift* becomes a rule that *causes drift* when applied to a state the rule's author did not anticipate. Non-execution with explicit acknowledgement preserves the rule's spirit; reconstructive execution corrupts it.

**Provenance** (evicted verbatim):

**Provenance**: 2026-04-15-executor-judgment-calls-handoff-closure.md


---

## §[SUPER-025] Research Gate as First Ground-Rule When Dispatch Rests on Unverified Assumption

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Unverified assumptions at dispatch time generate cascading rework if the dispatch turns out to rest on a false premise. The research gate converts the cascading-rework cost into a fixed pre-execution cost; when the assumption is wrong, only the gate's output is thrown away, not any execution built on it. The 2026-04-15 Phase 3b supervision validated this pattern by catching a correctness bug the original dispatch would have shipped; absent the gate, the subordinate would have executed against the false premise.

**Provenance** (evicted verbatim):

**Provenance**: 2026-04-15-executor-toolkit-phase3-completion.md


---

## §[SUPER-026] Delete-Public-Type Disposition Verification

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**:

Cycle 4 P2.9 Phase 0.5 produced "drop-all" disposition on `Linux.Kernel.Signal.Information` (the duplicate declaration). Grep found one type-name reference: a waitid parameter declaration in `Linux.Kernel.IO.Uring.Entry+Prepare.swift`. Reference-count = 1; principal authorized drop-all. Phase 2 deletion built clean on `Linux Kernel System Standard` (the deleted type's containing target) but failed on `Linux Kernel IO Uring Standard` with `'Information' is not a member type of enum 'Kernel_Namespace.Kernel.Signal'`. Root cause: the deleted type's co-location in `Linux_Kernel_System_Standard` had been providing accidental transitive module-import visibility for the type name; when it was deleted, the io_uring consumer's missing `public import ISO_9945_Kernel_Signal` surfaced. Subordinate correctly escalated per ask:; principal authorized the one-line import addition. The defect was not a reference-count miss; it was a module-import-graph miss.

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Swift 6.3's `InternalImportsByDefault` + `MemberImportVisibility` features narrow transitive visibility, making accidental visibility (via co-location, umbrella re-export, or transitive transitive-import) a now-load-bearing artifact of the package layout. Deleting a publicly-declared type can surface previously-masked missing-import defects in any number of consumer sites. Reference-count audits assume text-level matches map to module-level visibility; under the new strictness they no longer do. The principal's authorization gate is the right place to enforce the additional check because the principal is the last decision point before the deletion lands; subordinate self-policing under ask: works for known-unknown cases but the import-graph check needs to be a default principal step.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-04-24-p29-cycle-4-option-a-unify-and-structural-correctness-framing.md` (Phase 2 build-time failure on io_uring orphan-reference).


---

## §[SUPER-027] Pre-Dispatch Ecosystem-Constraint Scan

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**:

A 2026-04-28 Phase 1.5 dispatch authorized introducing `POSIX.Kernel.Descriptor` at L2 in `swift-iso-9945`. The dispatch's ground-rules block had nine well-typed entries covering empirical count, build verification, L1 boundary, cascade pattern, ask-triggers, compat-wrapper deletion, socklen scope, Research-doc citation, and L1→L2 dep direction. None covered namespace ownership. A 30-second `grep -rln "public enum POSIX"` would have revealed: the POSIX namespace is owned exclusively by `swift-posix` (L3-policy); `swift-iso-9945` has no authority to declare it.

The dispatch was authorized; the subordinate executed Phase 1.5 cleanly through 12 commits and supervisor-stamped clean. The principal then surfaced the namespace-ownership constraint post-execution; the entire Phase 1.5 was reverted (6 correction commits) with zero net progress on the type relocation. The pre-dispatch scan would have surfaced the constraint at the cheapest moment — before authorization — instead of after 12 commits of execution.

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: The supervisor model's risk surface defaults to what the dispatch text names; an axis the dispatch text doesn't name has no entry to enforce, and the supervisor block can be perfectly executed while the dispatch itself is structurally unsound. Codifying a default pre-dispatch scan against a fixed risk-surface enumeration is the structural fix: the scan fires regardless of what the dispatch text names, so it catches axes the dispatch missed. The cost is seconds; the cost of a defective dispatch authorized without the scan is potentially dozens of commits of churn.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-04-28-phase-1-5-l2-pivot-attempt-and-namespace-correction.md` (Phase 1.5 namespace-ownership omission discovered post-execution after 12-commit dispatch).


---

## §[SUPER-028] In-Absentia Decision Matrix — Class-(a) Inaction Before Class-(b) Escalation

**Why in-action precedes escalation (full paragraph; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Why in-action precedes escalation**: The escalation reflex ([SUPER-014a]) and the in-action reflex ([SUPER-024]) are both correct, but they apply to different question shapes. An apparent (b) question may dissolve into a clear (a) answer once existing rules are consulted; escalating it would burn user attention on a question the rules already handle. The decision matrix makes this preference explicit: check axis B (compliance form) before invoking axis A's escalation route.

**Worked examples (the origin incidents)** (evicted; condensed retention remains in-skill):

**Worked examples (the origin incidents)**:

| Question | Axis A | Axis B | Outcome |
|----------|--------|--------|---------|
| "Pipe.swift was in the `[HANDOFF-029]` grep set but contains zero Pattern A function sites — should I refactor it?" | Class-(a): [SUPER-024] applies — preconditions for refactor (Pattern A function sites) are unmet | Compliance form: in-action | Leave Pipe.swift untouched; document the discovery in commit body and close report. NO escalation needed. |
| "Brief's `@_disfavoredOverload` directive premise (shim file existence) is empirically false (precondition is method-name overlap, not shim-file existence) — should I follow brief's literal text or the empirical state?" | Class-(b): no existing rule resolves "follow defective brief vs apply empirical state"; user judgment needed on whether to override the brief | Not applicable (escalated) | Escalate to user (b)→(c) per [SUPER-014a]; user adjudicates. |

The first case dissolves into class-(a) once [SUPER-024] is consulted; in-action is correct. The second case is genuinely class-(b) because the question is "which authority wins — brief text or empirical state" — that is a user-judgment call, not a rule-application.

**Rationale (full text; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: In-absentia subordinates lack a live principal to filter trivial questions. Without a decision matrix, every apparent (b) question routes through escalation, cluttering the user's queue with questions existing rules already answer. The matrix's first axis (A) preserves [SUPER-014a]'s integrity (existing entries bind, new entries forbidden); the second axis (B) preserves [SUPER-024]'s integrity (in-action is compliant when preconditions are unmet). Composing them into a single decision procedure prevents the escalation-reflex from over-firing.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-04-29-path-x-phase-2-windows-mirror-execution.md` (Pipe.swift in-action case + `@_disfavoredOverload` escalation case).


---

## §[SUPER-029] Drift Signal Extension — Subordinate-Initiated Plan Restructuring

**Why structural changes are class-(c) (full bullets; framing sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Why structural changes are class-(c)**:

A plan's phase structure encodes the principal's chosen *path*, not just the destination. Re-ordering or collapsing phases:

- Re-allocates rollback granularity (a flag-day collapse loses per-phase rollback)
- Re-allocates verification gates (a phase merge skips one set of build gates)
- Changes the dispatch attribution (commits collapse into one author, the next attribution becomes ambiguous)
- May invalidate downstream plan elements (e.g., a phase that depended on Phase-N completing as scheduled)

Even when the final state is identical to the prescribed plan, the path differs structurally. The principal authored the path; the subordinate executes against it.

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**:

A 2026-04-22 Phase 2+6 flag-day collapse during the Borrow unification cascade was authorized by direct user directive ("lets do it in one go"). The subsequent v1.1.0 attribution conflated commits across the collapsed phases, with no per-phase rollback granularity available when a defect surfaced. The collapse was correct *with explicit authorization*; the failure mode would have been a subordinate self-collapsing without surfacing — the same final state but an authorization gap.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-04-23-ownership-borrow-unification-arc-and-defect-recovery.md`.


---

## §[SUPER-030] Bounded Final-Exchange for Supervisor Review Cycles

**Worked example** (evicted; condensed retention remains in-skill):

**Worked example**: A 2026-04-23 Phase 1 heritage-transfers supervisor review cycle converged on Q1 (Option B for path-dep) + Q2 (rm+checkout primary recipe) in one round, with a brief closing-note from the supervisor on follow-up cleanup. No drift, no second round needed.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-04-23-phase-1-heritage-transfers-and-supervisor-review-cycles.md`.


---

## §[SUPER-015a] Empirical-Provenance Note (Compression-at-Pivot)

**Full provenance note** (evicted; condensed retention remains in-skill):

[SUPER-015] codifies progressive refinement and compression-at-pivot. The 2026-04-23 Borrow unification cascade is the empirical worked example of *"compression as constraint strengthening, not just size management"*: at the v1.0 → v1.1 pivot, the supervisor block was rewritten from 6 entries to 6 entries with #2 and #4 absorbing Q1/Q2/Q3 decisions via the `(merges #N, #M)` notation. The total entry count stayed the same, but the rules became more constraining (post-merge entries had stricter pre/post-conditions). Post-pivot drift signal #6 fired zero times — supersession-via-merge produced binding constraints, not just compressed text.

(The provenance note is appended here rather than re-stating the rule; the rule body at [SUPER-015] above is unchanged.)


---

## §[SUPER-031] CI-Failure Attribution from Aggregator Output

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**:

A 2026-05-07 supervisor cycle read aggregator JSON output (`{"lint": "success", ...}`) and concluded "our swift-linter workflow passed." The user pushed back with a screenshot showing `swift-linter (Phase 1, advisory) FAILED`. The aggregator's `"lint"` entry was SwiftLint (existing institute tool); the failed job was the new swift-linter advisory workflow. The label collision masked the failure; the right move was to read the failed job's log first and only consult the aggregator label as a cross-check.

**Rationale (full text; first sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Aggregator output is summary, not evidence. CI infrastructure produces summaries optimized for at-a-glance status, which inherently coalesces categories. When verification depends on attribution, summaries are unreliable; the failed-job log is unambiguous. The cost of reading the log is one `gh run view` invocation; the cost of misattribution is downstream — wrong corrections, wrong adjudications, supervised work that proceeds on a false-pass premise.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-05-07-supervisor-seat-swift-linter-cohort-orchestration.md` (Pattern 2).


---

## §[SUPER-032] Push-Bundle Discipline at Terminal Authorization

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**:

A 2026-05-07 pre-publishable polish dispatch specified "per-action authorization at terminal" but pushed 4 of 7 commits mid-stream (principal-initiated on Skills + swift-linter) and 3 of 7 at terminal under explicit `YES PUSH`. The terminal authorization decided the residue, not the full set. The rhythm-axis discipline (`feedback_user_plan_is_roadmap_not_authorization`) was the right shape on the per-action axis but degraded on the bundling axis. Codifying push-bundle discipline as a separate rule prevents future cohorts from collapsing the bundling distinction silently.

**Rationale (full text; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Terminal-authorization rhythms exist to compress N reviews into 1, amortizing the principal's per-action attention cost across a bundle. Interleaved pushes preserve N reviews while losing the compression benefit. The principal accumulates context per push, so by terminal time the bundled review has effectively already been split across N moments. The fix is mechanical (hold pushes); the cost of not holding is the cohort-rhythm degradation that compounds across subsequent cohorts.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-05-07-pre-publishable-polish-stream-2.md` (Pattern: push-timing interleaving as supervisor-rhythm equivalent of test-pyramid inversion).


---

## §[SUPER-033] In-Absentia + User-Intent-Primary Cascade Composition

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**:

A 2026-05-07 D4' branching dispatch had Rule #6 (`ask:` Surface positive-test invalidation; escalate before loosening tests) triggered when 11 existing positive Cardinal.Count tests would fail under the narrowed predicate. The subordinate derived the boundary "an update is loosening iff the rule has fewer detected scenarios post-update; updates that migrate inputs to a narrowed-API analogue while preserving the detected defect class are NOT loosening" and proceeded. Supervisor accepted post-hoc ("interpretation is sound"). The reasoning was non-mechanical and could have gone wrong; codifying the rule makes future similar cases mechanical without losing the user-intent-primary primacy.

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: [SUPER-014a]'s default "re-classify (b) to (c) and escalate" is correct for non-cascade contexts but produces user-attention pressure when applied to every `ask:` trigger in a routine cascade. The user-intent-primary feedback memory establishes that user goals dominate principal-tangent stop conditions; this rule extends the principle to in-absentia ground-rule triggers. The lowest-loss interpretation + transparent surface preserves the supervisor in-absentia integrity (no self-authored block entries, no scope expansion) while honoring user intent (the cascade completes).

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-05-07-d4-linter-rules-predicate-narrowing-and-readme-repair.md` (Pattern: in-absentia ask: + user-intent-primary feedback compose to a specific decision pattern).


---

## §[SUPER-034] Principal MUST NOT Drift Into Subordinate Execution

**Recurrences (incident table)** (evicted; condensed retention remains in-skill):

**Recurrences**:

| Date | Incident |
|---|---|
| 2026-04-21 | swift-property-primitives docs — principal applied A/B/C @PageColor edit + commit `8fafbfa` instead of relaying decision back; reverted via `git reset --hard 0423d56`. |
| 2026-04-29 | Path X Phase 2 dispatch — principal authored pre-dispatch HANDOFF, subordinate reported with 3 escalations; principal resolved them correctly THEN drifted into executing Wave 1 (IO.Read/Write rewrites + macOS build + commit `8813e09`) AND made a wrong type-design decision (UInt instead of HANDLE) inside the drift. User caught both (role drift AND wrong type). Reverted via `git reset --hard 1be7df4` + Escalation 2 re-resolution to HANDLE. The "lets make progress" preceding the drift was NOT execution authorization. |


---

## §[SUPER-035] Pre-Dispatch Empirical State Verification

**Worked examples (the origin incidents)** (evicted; condensed retention remains in-skill):

**Worked examples** (the origin incidents):

| Incident | Failed axis | Cost of miss |
|----------|-------------|--------------|
| Path X G6.B Event L3 attempt (2026-04-30) | Cycle-precedent transfer (Cycle 23 Completion → L3 worked because Linux io_uring was single-platform; G6.B Event has darwin-standard kqueue + linux-standard epoll L2 extensions) | Full unwind cycle; G6.B re-disposed to iso-9945 L2 |
| Item 1.5 Memory.Lock.Token Path δ (2026-05-02) | Research-doc layering claim (Option B's `_descriptor: Kernel.Descriptor?` field at L1 swift-memory-primitives — L1 cannot import L2 Kernel.Descriptor) | Phase 2 BLOCKER + 5-path empirical experimentation cycle |
| Item 3.5 Glob L1 relocation (2026-05-02) | Enumerated-state count (dispatch said "Glob is at L1, do consumer cascade"; actual state was Glob at L2 awaiting L2→L1 relocation) | Reverse-direction consumer rewrites averted by Cycle 3 pre-flight research |
| Path X G6.D Kernel namespace shape (2026-04-30) | Cycle-precedent transfer (chose simpler top-level `enum Kernel {}` form; user's preferred shape was canonical-nested per [PLAT-ARCH-005]) | Substantial bulk-rename refactor across ~9 packages |

**Rationale (full text; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Auto-mode + parallel-dispatch creates pressure to dispatch quickly; first-principles correctness creates pressure to research before dispatching. The pre-dispatch empirical verification collapses the false dichotomy: the verification IS the make-progress work for high-stakes dispatches. The cost asymmetry favors verification — minutes at dispatch time vs hours of forced unwind.

**Provenance** (evicted verbatim):

**Provenance**: 2026-04-30 Path X arc (Reflections `2026-04-30-path-x-multi-cycle-kernel-primitives-removal.md` Pattern 1 — "Cycle X precedent applies" requires precondition check; `2026-04-30-path-x-completion-cycles-19-23-and-g6.md` G6.B unwind); 2026-05-02 multi-envelope arc (Reflection `2026-05-02-supervisor-multi-envelope-parallel-dispatch-and-verification-rhythm.md` 2/2 research-then-dispatch hit rate); 2026-05-02 Glob L1 relocation (Reflection `2026-05-02-glob-l1-relocation-and-premise-inversion-research-gate.md` Pattern 1 — premise-inversion catch via research gate).


---

## §[SUPER-036] Edit-Zone Non-Overlap for Parallel Dispatch

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**:

The 2026-05-02 supervisor session ran two parallel subordinates closing ~10 cycle-equivalents (Items 5 / 1.5 / 3.5 + Tier 5 envelopes + Wave 3.5-Final-Atomic). Each dispatch's MUST NOT clauses named the other subordinate's edit zones. Both subordinates self-classified diffs in non-owned packages as "the other subordinate's work, not mine" — they assimilated the discipline. Zero edit-zone collisions across the entire session.

**Rationale (full text incl. failure/success-mode evidence; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Parallel-dispatch coordination cannot rely on subordinates' a-priori awareness — neither subordinate sees the other's session. Without explicit MUST NOT enumeration, a subordinate's "fix this related thing while I'm here" instinct causes silent overwrites of the other subordinate's in-flight work. The 2026-05-06 SwiftSyntax linter Phase 2 Stream A+B incident (parallel chats edited the same package without git-branch isolation per `feedback_cross_stream_working_tree_isolation`) is the failure-mode evidence; the 2026-05-02 zero-collision session is the success-mode evidence. Both validate the discipline.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-05-02-supervisor-multi-envelope-parallel-dispatch-and-verification-rhythm.md` (parallel-dispatch coordination; zero collisions across ~10 cycle-equivalents); cross-references `feedback_cross_stream_working_tree_isolation.md` (failure-mode counterpart on 2026-05-06).


---

## §[SUPER-037] Build-Warning Classification at Verification Boundary

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**:

The 2026-05-02 multi-envelope supervisor session reported "GREEN" for ~10 cycles spanning Wave 3.5-Corrective sites (Stats / Open / Memory.Map / Time). The verification rhythm checked `swift build` exit code and file edits but did NOT inspect warnings. `swift build` had been emitting `warning: function call causes an infinite recursion` for 16 method bodies across the four sites — L3 wrappers self-recursing because Swift's overload resolution prefers same-module declarations over `@_spi`-imported declarations with identical signatures on the same nominal type. At runtime: stack overflow on first invocation. Tests didn't exercise the runtime paths. The Wave 3.5-Corrective pattern itself was structurally broken; the verification rhythm was incapable of catching it because it only inspected compilation success.

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: A verification rhythm that conflates "compiled cleanly" with "behaves correctly" is structurally blind to a class of defects that the compiler itself diagnosed but didn't promote to errors. The cost of the blind spot accumulates across cycles silently — each "GREEN" disposition adds another compounding defect. Adding warning-classification is one extra grep at verification time; the cost is seconds per cycle, the benefit is catching defects at the moment they emerge instead of post-merge investigation.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-05-02-supervisor-multi-envelope-parallel-dispatch-and-verification-rhythm.md` (the largest miss — 16 self-recursing method bodies across Wave 3.5-Corrective sites; "GREEN" reports for ~10 cycles concealed structurally broken pattern).


---

## §[SUPER-038] Brief-vs-State-Staleness Pre-Send Verification

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**:

The 2026-05-06 cross-ecosystem CI wrapper rollout's first brief committed + pushed `L3 profile/README.md`. The supervisor wrote a second brief later in the same session listing "DO NOT push L3 profile/README.md yet" as an acceptance criterion. The subordinate detected the discrepancy via `git log` against the L3 README and surfaced via [HANDOFF-045]. Had the supervisor pre-verified the post-execution state of the L3 README before sending the second brief, the criterion would have been removed at brief-author time instead of recovered at brief-execution time.

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Brief authoring under context-loading pressure tends to copy literal text from prior templates without re-verifying state. The verification cost is seconds (a handful of greps); the cost of NOT verifying is the subordinate's cycle to detect + surface + recover, plus the principal's cycle to amend the brief. Front-loading the verification at the supervisor's desk is the load-bearing intervention.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-05-06-supervisor-mode-cleanup-cycle-and-secret-management-seed.md` (brief-vs-state-staleness rule for re-issued briefs).


---

## §[SUPER-039] Class-(c) Trigger for Build-Gate Failure from Upstream-Package State Divergence

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**:

The 2026-05-08 X2 dispatch's clean-build requirement surfaced a Memory.Page → System.Page upstream-state divergence in `swift-posix` (NOT in the X2 subordinate's authorized swift-linter package). The subordinate correctly surfaced as class-(c) and awaited authorization to expand scope to swift-posix. The principal authorized the expansion; X2 + swift-posix patch landed together.

**Rationale (full text; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: Without this rule, the subordinate's natural disposition on hitting an upstream defect during clean-build is either (a) silent fix (scope-creep without authorization) or (b) silent halt (uninformative blocked-state). Class-(c) escalation is the right shape because it surfaces the structural condition (upstream defect) AND requests scope expansion — both load-bearing for the principal's disposition.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-05-08-x2-build-cache-masked-defect-and-supervised-class-c-flow.md` (X2 swift-posix Memory.Page fallout via clean-build gate).


---

## §[SUPER-040] `swift package clean` After Upstream Branch-Tracking Dependency Prune

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**:

The 2026-05-09 cascade-tail-prune execution removed Property+Collection ~Escapable upgrades from a tier. `swift package update` reported up-to-date on swift-property-primitives. `swift build` failed at link time with "symbol not found" against the pre-prune-mangled Property.View symbols. `swift package clean` followed by re-build resolved the staleness.

**Rationale (full text; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: The compiler's incremental cache is keyed on file contents, not on dependency-graph identity. Branch-tracking dependencies (the predominant pre-1.0 form per the swift-package skill) can have their public surface change without any local file changing — the change is upstream of the local `.build/`. Without `clean`, the linker silently uses cached object files compiled against the prior public API. The cost of the clean step is wall-clock seconds (small package) to minutes (large package); the cost of skipping it is silent wrong-version linkage.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-05-09-cascade-tail-prune-execution-and-doc-amendment.md` (post-prune `swift package update` reported up-to-date but link failed against pre-prune-mangled Property.View symbols).


---

## §[SUPER-041] Calibration: Option-Matrix → Recommendation-First on User Trust Signal

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**:

The 2026-05-09 escapable-property-tier-prune supervision arc had ~5 class-(b)/(c) adjudications in sequence. User authorized recommendations with "all YES" / "GO" twice in the session. Supervisor continued option-matrix format past the trust-signal trigger. Mid-arc, user explicitly directed "just give me the recommendation" — the supervisor's calibration miss cost three turns of unnecessary option enumeration.

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-05-09-escapable-property-tier-prune-supervision-arc.md` (calibration rule: option-matrix → recommendation-first when user signals trust).


---

## §[SUPER-042] Escalations Land as Inline Markdown the User Forwards; Never Use AskUserQuestion

**Provenance** (evicted verbatim):

**Provenance**: memory `feedback_escalate_inline_not_askuserquestion.md` (recurring pattern — agents reaching for AskUserQuestion when the question is for the absent supervisor).


---

## §[SUPER-043] Subordinate Owns Own Close-Out (Push, Verify, Wrap-Up)

**Why (full paragraph; first sentence retained in-skill — the "different scopes" clause is restated normatively in How to apply)** (evicted; condensed retention remains in-skill):

**Why**: Close-out work (final push, build/test verification, summary report) is the subordinate's responsibility because the subordinate has the live context: which commits, what to verify, what to summarize. The supervisor would have to reconstruct that context to execute, which loses precision. "No more new dispatches" does NOT mean "no more close-out from in-flight work" — those are different scopes.

**Provenance** (evicted verbatim):

**Provenance**: memory `feedback_subordinate_owns_close_out.md` (supervisor preempting subordinate close-out on user's "stop new work" signal).


---

## §[SUPER-044] Inline Relay Responses Are Self-Contained Per Subordinate; No `[paste X verbatim]` Placeholders

**Provenance** (evicted verbatim):

**Provenance**: memory `feedback_inline_relay_no_placeholders.md` (recurring relay-friction pattern — placeholders forced manual substitution).


---

## §[SUPER-045] User Multi-Step Plan Descriptions Are Roadmaps, Not Authorization for All Steps

**Why (full paragraph; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Why**: Multi-step plans serve as roadmaps and shared mental models, not as binding pre-authorizations. A user listing 4 steps is articulating intent and ordering; "proceed" means "start the cascade," not "execute steps 2–4 without further check-in." Treating the description as authorization causes the supervisor / subordinate to bypass scope-lock per [SUPER-002a] when downstream steps would otherwise warrant it.

**Provenance** (evicted verbatim):

**Provenance**: memory `feedback_user_plan_is_roadmap_not_authorization.md` (subordinate jumping ahead in a roadmap-described cascade).


---

## §[SUPER-046] Alpha-Pace: Bundle Ecosystem-Gap Fixes Into the Active Dispatch

**Why (full paragraph; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Why**: Pre-1.0 development is correctness-driven (per `[ARCH-LAYER-008]`). When the active dispatch surfaces an ecosystem gap, deferral creates two units of work where one would suffice. The active dispatch's context is fresh; folding the fix in costs ~1 commit. A deferred fix costs (a) a future dispatch (re-establishing context), (b) the user's authorization, (c) a re-review of the original gap finding. The asymmetry favors bundling.

**Provenance** (evicted verbatim):

**Provenance**: memory `feedback_no_deferral_bundle_ecosystem_fixes.md` (recurring user direction — fold the fix into the active dispatch).


---

## §[SUPER-047] Git-Branch Isolation Upfront When N≥2 Subordinates Edit the Same Package

**Provenance** (evicted verbatim):

**Provenance**: memory `feedback_cross_stream_working_tree_isolation.md` (2026-05-06 SwiftSyntax linter Phase 2 Stream A+B incident — parallel chats edited same package without git-branch isolation; failure-mode counterpart to [SUPER-036]'s success-mode evidence).


---

## §[SUPER-048] Per-Wave Cleanup Inventory MUST Enumerate the Complete Violator Set

**Why (full paragraph; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Why**: Multi-wave cleanups deliberately split work into manageable batches. The split is sound only if every violator lives in exactly one wave. A subset-enumeration leaves the remainder invisible until a verification pass discovers them — typically days/weeks after the original enumeration, when context is stale and the cleanup is "done" by attestation. Mandatory post-hardening verification scan exists as a backstop, but the right discipline is exhaustive enumeration upfront so the backstop fires zero defects.

**Provenance** (evicted verbatim):

**Provenance**: memory `feedback_per_wave_inventory_must_be_exhaustive.md` (recurring pattern: subset-enumeration leaving residuals discovered post-attestation).


---

## §[SUPER-049] Sub-Agent Output Discipline: Files + One-Line Confirmations

**Why (full paragraph; first sentence retained in-skill)** (evicted; condensed retention remains in-skill):

**Why**: Sub-agents in Claude Code consume the dispatcher's context budget on return — the sub-agent's full session history collapses to its return message, but a verbose return message still counts. A 5,000-token "here's everything I did" return drains the dispatcher's budget; a 50-token "Wrote `Audit.md` (12 findings, 3 HIGH); summary in §1" preserves it. The dispatcher reads the artifact; the return-message exists only to point.

**Provenance** (evicted verbatim):

**Provenance**: memory `feedback_agent_output_discipline.md` (recurring pattern — sub-agents flooding main context with verbose returns).


---

## §[SUPER-050] Run Commands Once and Wait — No Duplicate Re-Runs on Slow Output

**Why (full paragraph; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Why**: Output latency is not failure. Builds, sub-agents, network calls, and CI dispatches frequently produce no stdout for tens of seconds while running. Re-running the command starts a parallel invocation that competes with the first. For idempotent commands the cost is wasted work; for non-idempotent commands (commit, push, file rewrite, gh dispatch) the cost is doubled side effects.

**Provenance** (evicted verbatim):

**Provenance**: memory `feedback_no_duplicate_commands.md` (recurring pattern: re-running commands when output is slow).


---

## §[SUPER-051] Start Implementing Instead of Over-Researching

**Provenance** (evicted verbatim):

**Provenance**: memory `feedback_start_implementing.md` (recurring pattern — implementation requests degenerating into research rounds).


---

## §[SUPER-052] Push-Set Membership Is Set-Membership Against the Enumerated Window, Never `ahead>0`

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**: an MSB W3 push stage over-included 7 repos — each had exactly one principal-confirmed commit, so each was "ahead," but none was in the program's enumerated push window. The content was cleared and the over-inclusion honestly disclosed, and the principal accepted it — the predicate was still wrong, and the supervisor ruled it a PERMANENT process lesson: "push-set predicates are SET-MEMBERSHIP against the enumerated window, never `ahead>0`."

**Provenance** (evicted verbatim):

**Provenance**: Reflection `2026-06-04-msb-capability-tower-w3-endgame.md` (Stage-6 7-repo over-inclusion; supervisor's permanent-lesson ruling).


---

## §[SUPER-053] Named Gates Are Never Absorbed by Pre-Authorization Classes

**Worked example (the origin incident)** (evicted; condensed retention remains in-skill):

**Worked example (the origin incident)**: an MSB post-push track merged an external-arc fix under the program's standing authorizations; the verification substance was three-key (the executing agent's independent re-derivation + the executor's [SUPER-009] first-hand check + the seat's post-hoc verification), so the outcome stood unconditionally — but the program had a DECLARED seat GO-gate ("seat verifies the arc first-hand → one-line GO → merge") that never fired. The seat's ruling, verbatim distinction: "pre-authorization classes never absorb a declared named gate; skipping one is a deviation even when the substance is otherwise covered."

**Rationale (full text; first two sentences retained in-skill)** (evicted; condensed retention remains in-skill):

**Rationale**: named gates are the principal's chosen observation points; their value is partly WHEN they fire (sequencing, attention, the option to redirect) — not only WHAT they verify. Substance-coverage reasoning silently converts the declarer's checkpoint into the executor's judgment call, an authority transfer no pre-authorization class grants. The asymmetry is deliberate: a redundant gate costs one round-trip; an absorbed gate costs the principal's standing ability to rely on declared checkpoints.

**Provenance** (evicted verbatim):

**Provenance**: principal addendum (2026-06-04) to Reflection `2026-06-04-msb-capability-tower-w3-endgame.md` (the P-1 GO-gate skip; seat instruction at program termination).


---

## Changelog-Provenance (Dated Amendment History)

Evicted verbatim from the SKILL.md frontmatter comment block (2026-06-09 state). Git history of
`Skills/supervise/SKILL.md` remains the authoritative record; these entries are preserved because
they carry narrative value (amendment reasoning, provenance chains). Ordered as they appeared in
the frontmatter.

- **2026-06-09**: Cleanup — repointed a dangling provenance citation (a [SUPER-*] rule's Why) from the nonexistent feedback_correctness_sole_driver_during_development.md memory to [ARCH-LAYER-008] (which now embodies the correctness-sole-driver discipline, generalized to all phases 2026-06-09). Clarifying per [SKILL-LIFE-003].
- **2026-06-04**: [SUPER-052] push-set membership is set-membership against the enumerated window, never `ahead>0` (Stage-6 7-repo over-inclusion; supervisor permanent-lesson ruling) + [SUPER-053] named gates are never absorbed by pre-authorization classes (P-1 declared seat GO-gate skipped under covered substance; deviation even so). Both additive per [SKILL-LIFE-003]. Provenance: Reflections/2026-06-04-msb-capability-tower-w3-endgame.md + principal addendum 2026-06-04.
- **2026-05-10**: [SUPER-038] Brief-vs-State-Staleness Pre-Send Verification added per Reflections/2026-05-06-supervisor-mode-cleanup-cycle-and-secret-management-seed.md (Cluster F consolidation)
- **2026-05-10**: [SUPER-035] Pre-Dispatch Empirical State Verification + [SUPER-036] Edit-Zone Non-Overlap for Parallel Dispatch + [SUPER-037] Build-Warning Classification added per Reflections/{2026-04-30-path-x-multi-cycle-kernel-primitives-removal, 2026-04-30-path-x-completion-cycles-19-23-and-g6, 2026-05-02-supervisor-multi-envelope-parallel-dispatch-and-verification-rhythm}.md (Cluster A consolidation)
- **2026-05-05**: Track B Phase B-2 — `**Composite:**` annotations on 12 composite rules per HANDOFF-skills-quality-refactor-track-b.md

---

## §D1 Eviction Pass 2026-07-05

Non-normative content evicted from `Skills/supervise/SKILL.md` to clear the skill-size gate (baseline 1407). One-line pointers or cross-refs remain in-skill.

### §[SUPER-001] Handoff-vs-Supervise Distinction — Rationale (evicted 2026-07-05)

**Rationale**: Conflating the two produces either a handoff that depends on a still-living principal (broken when the session ends) or a supervisor that can only intervene after the fact (no in-flight oversight).

### §[SUPER-002/003] Ground-Rules Block Size — Rationale (evicted 2026-07-05)

**Rationale**: 4–6 entries is the size at which the subordinate can hold the full block in working memory while writing each turn. Larger blocks become wallpaper and stop being checked.

### §[SUPER-002a] Scope-Lock Precedes Architecture-Lock — Example (correct) (evicted 2026-07-05)

**Example (correct)**:

```
fact: In scope — GUI consumers of Executor.Main on Darwin and non-Darwin
      (user confirmed 2026-04-16, theoretical-best framing regardless of current consumer count).
      Out of scope — embedded environments (deferred).
      Explicitly rejected — import Foundation anywhere in the stack (γ lock-out).
MUST: Platform-agnostic Executor.Main (no #if os(...) in the file).
MUST NOT: Import Dispatch directly inside Executor.Main.
  (why: scope fact above — GUI consumers on non-Darwin need a unified type.)
```

### §[SUPER-006] Boundary-Triggered Intervention — Rationale (evicted 2026-07-05)

**Rationale**: Continuous intervention defeats the subordinate's autonomy and inflates context cost. Zero intervention defeats supervision. Boundary-triggered intervention is the productive middle: the subordinate runs freely between boundaries, the principal verifies at each one.

### §[SUPER-008] Reject-and-Redo — Rationale (evicted 2026-07-05)

**Rationale**: Silent rewrites destroy the subordinate's ability to learn from correction, produce two half-authored artifacts whose authorship is unclear, and erode the verification trail that supervision exists to preserve. Reject-and-redo preserves authorship and corrective signal.

### §[SUPER-009] Acceptance Criteria — Example (evicted 2026-07-05)

**Example**:
```
Acceptance:
  1. swift test green on macOS for the new Listener events strategy.
     (verified via: build/test output — principal runs `swift test` locally)
  2. swift test green on Linux Docker for blocking + events + completions.
     (verified via: build/test output — principal runs Docker test in its own shell)
  3. No diffs to swift-kernel-primitives or swift-linux-standard.
     (verified via: disk/git state — `git diff --stat` on those packages)
  4. Phase 3A research note written at Research/sockets-phase-3-plan.md.
     (verified via: current file state — principal reads the file)
```

### §[SUPER-013] Cite-the-Rule Drift Correction — Rationale (evicted 2026-07-05)

**Rationale**: Quoting the rule and citing its number turns drift correction from a personal exchange into a verifiable check against a shared artifact. The subordinate can re-read the cited entry; the principal can re-apply the same check next turn.

### §[SUPER-014] Block-on-Disk — Rationale (evicted 2026-07-05)

**Rationale**: A block held only in conversation context is lost on session end and re-derivable only from memory. The block must be on disk or in the prompt for re-injection to be reliable.

### §[SUPER-015] Append In-Scope Answers — Rationale (evicted 2026-07-05)

**Rationale**: An in-scope answer is a new constraint on the subordinate's remaining work. If it is not added to the block, the subordinate forgets it, the principal re-derives it, and the answer drifts across turns. Appending it freezes the decision and makes it citable for future drift checks.

### §[SUPER-026] Principal-Side Import-Grep — Why Principal-Side (evicted 2026-07-05)

**Why principal-side, not just writer-side**: [HANDOFF-013b] (the writer-side counterpart) catches the methodology gap at handoff-write time. [SUPER-026] catches the same defect at supervision time, when the dispatched approach is being authorized. The two rules are complementary: in single-actor sessions where the writer is also the principal, both fire at the same moment; in dispatched sessions, [HANDOFF-013b] fires first (write time) and [SUPER-026] is the second-line defense at the corresponding authorization moment. A defect that slips past [HANDOFF-013b] (writer didn't grep for explicit imports) is still catchable at [SUPER-026] (principal checks before authorizing the disposition).

### §[SUPER-027] Pre-Dispatch Ecosystem-Constraint Scan — Relationship to [SUPER-020] (evicted 2026-07-05)

**Relationship to [SUPER-020] Pre-Authorization Architectural-Constraint Scan**: [SUPER-020] covers cross-package Package.swift edits, cross-layer type references, and dependency-direction changes at *class (b) authorization* time during execution. [SUPER-027] (this rule) covers the same risk-surface dimensions plus namespace-ownership and Research-doc-recommendation at *dispatch authorization* time, before the subordinate begins. The two rules compose: [SUPER-027] catches the dispatch-time class; [SUPER-020] catches the in-flight class. A defect that slips past [SUPER-027] (dispatcher missed the constraint) is still catchable at [SUPER-020] (principal re-checks before authorizing the in-flight class (b) escalation that surfaces the same defect).

### §[SUPER-055] Orchestrator Match STOP — Relationship, Worked Example, Rationale (evicted 2026-07-05)

**Relationship to adjacent rules**:

- **Subordinate-side symmetry — [SUPER-039]**: [SUPER-039] obligates the *subordinate* to treat an upstream-state divergence surfaced during verification as a class-(c) escalation (neither silent fix nor silent halt). [SUPER-055] is the receiving-end obligation: the orchestrator that receives that class-(c) STOP relays-and-waits rather than absorbing the fix itself.
- **Distinct from [SUPER-034]**: [SUPER-034] forbids the principal taking over the subordinate's *own in-arc* execution (edits, commits, stamping). [SUPER-055] forbids the orchestrator reaching *outside* the arc into an unrelated package. A "make progress" / "I don't want to keep discussing" user signal authorizes faster relay per [SUPER-034]; it does NOT authorize cross-arc execution.
- **Composes with [SUPER-056]**: the blocker is frequently parallel-session state; [SUPER-056] governs the general non-interference posture the orchestrator must adopt while waiting.

**Worked example (origin incident)**: 2026-05-18 — a B2 verification dispatch surfaced a `swift-array-primitives` protocol/witness mismatch (`Collection.Remove.Last` requires `static func last(_:)`; five Array witnesses were still named `removeLast`). The subordinate correctly STOPPED per its "if blocked by unrelated work, stop — don't work around" ground rule. The orchestrator then renamed the five signatures in `swift-array-primitives` to unblock B2 — stepping on the principal's parallel work on that same package. Corrected twice ("revert the array-primitives changes, we're working on that separately"; "if parallel work interferes, stop the work and inform me"). The compliant move was to relay the STOP verbatim and wait.

**Rationale**: A subordinate's disciplined STOP is defeated if the layer above it silently performs the very cross-arc edit the subordinate refused. Matching the STOP up the chain preserves authorship boundaries, avoids racing the principal's parallel work on the same package, and keeps the escalation trail intact.

### §[SUPER-056] Non-Interference With Parallel State — Rationale (evicted 2026-07-05)

**Rationale**: Parallel sessions own their working-tree edits; source-level interference (editing their files, reverting their state, committing their WIP) is destructive across sessions and conflates authorship and commit cadence. Build-cache mutation is local and safe. STOP-and-INFORM when blocked, plus work-around when not, is the only posture that neither races parallel work nor stalls the arc.
