# Audit Skill Rationale Archive

<!--
version: 1.0.0
last_updated: 2026-07-05
status: REFERENCE
-->

> Non-normative companion to `Skills/audit/SKILL.md` (per Research/ecosystem-meta-setup-target-state.md §D1).
> This document holds evicted rationale prose, provenance, extended worked examples, incident narratives,
> second/third example variants, and relationship-to-adjacent-rule essays. The skill file remains the
> CANONICAL source for all `[AUDIT-*]` requirement statements; nothing in this archive is normative.
> Organized by rule ID in skill order.

---

## §[AUDIT-024] META-Deflection Anti-Pattern (evicted 2026-07-05)

**Worked example (the origin incident)**:

During the 2026-04-25 platform audit dispatch, three observations were initially logged as META rather than P-series findings on the rationale "no [PLAT-ARCH-*] explicitly authorizes lateral L3 → L3 composition" / "no [PLAT-ARCH-005a] sub-rule explicitly addresses non-pointer C-struct types in `@unsafe public init`." All three were violations of the existing rules' spirits ([ARCH-LAYER-001] forbids lateral regardless of pervasiveness; [PLAT-ARCH-005a] forbids C types in public API regardless of init shape). Principal review correctly promoted them to P2.11 / P2.12 / P4.7 with explicit remediation routes (restructure OR codify the carve-out). The META observations were kept separately as codification candidates. Each finding's tracker row is the durable record of the violation; the META observation is the durable record of the codification proposal.

**Relationship to other anti-patterns**:

- [HANDOFF-024] codifies the parallel rule for **sample-and-extrapolate** (writer checks N items, claims pattern holds for N+M without verifying the M).
- [AUDIT-017] codifies the legitimate use of **DEFERRED** (parking destination for findings whose remediation depends on a decision outside the current session's authority); the anti-pattern shape would be DEFERRED-without-investigation-pointer.

This rule completes the trio: sample-and-extrapolate ([HANDOFF-024]), defer-without-discipline (out-of-scope-of [AUDIT-017]), and now deflect-via-META ([AUDIT-024]). All three are writer-side mechanisms for avoiding diligence at audit-write time while preserving the appearance of completeness; all three are now structurally rule-bound.

**Rationale**: Writer-side audit shortcuts compound across audit cycles. Each shortcut saves the writer minutes at audit-write time and costs every downstream consumer of the audit hours of re-derivation. The structural fix is rule-level: the audit-writer must log the finding regardless of rule-ambiguity, and the rule-question goes in a separate META observation. The two are parallel work products, not substitutes.

---

## §[AUDIT-025] PREMISE-STALE Status Code (evicted 2026-07-05)

**Worked examples (origin incidents)**:

| Finding | Audit-write state | Current state | Classification | Why not RESOLVED or FALSE_POSITIVE |
|---------|-------------------|---------------|----------------|------------------------------------|
| 2026-04-25 D2 (swift-buffer-primitives module gap) | Finding cited "missing required module" diagnostic from build log | Diagnostic no longer reproduces; clean rebuild PASSes | PREMISE-STALE | Not RESOLVED: nobody specifically fixed it. Not FALSE_POSITIVE: the diagnostic was real at audit-write time, just transient. |
| 2026-04-25 D3 (swift-kernel L3 source-target Package.swift gap) | Finding cited a missing target-dep declaration | Re-derivation finds the dep declared; gate PASSes | PREMISE-STALE | Not RESOLVED: parallel work silently closed the gap (nobody addressed the audit row). Not FALSE_POSITIVE: the gap was real at audit-write time, then closed by unrelated work. |

**Distinction from RESOLVED**:

RESOLVED is targeted: a remediation cycle directly addressed the finding, citable by commit SHA against the finding row. PREMISE-STALE is incidental: the finding was undone by parallel work without anyone specifically fixing it. The distinction matters for synthesis: RESOLVED counts toward audit-cycle effectiveness; PREMISE-STALE counts toward state drift and might warrant tighter audit-window scheduling.

**Distinction from FALSE_POSITIVE**:

FALSE_POSITIVE means the audit was wrong at audit-write time — the finding cited a non-existent defect (hallucinated type, misapplied rule, transient artifact). PREMISE-STALE means the audit was right at audit-write time, but the world has moved.

**Rationale**: Without PREMISE-STALE, the audit-writer faces a forced choice between RESOLVED (which falsely claims a fix landed) and FALSE_POSITIVE (which falsely impugns the audit-write moment). Both mis-attribute. PREMISE-STALE gives the audit-writer a precise mid-status that records "the world changed under this finding" without overclaiming on either dimension. The distinction also feeds back into audit-cycle cadence decisions: a high PREMISE-STALE rate suggests the audit window is too long; a high RESOLVED rate suggests the remediation cycle is healthy.

---

## §[AUDIT-026] Substantive Canary Gate Substitution (evicted 2026-07-05)

**Worked examples (origin incidents)**:

| Cycle | Terminal gate | Blocker | Substantive canary | Logged drift |
|-------|---------------|---------|---------------------|--------------|
| Cycle 3 (2026-04-23) | Docker Linux swift-kernel `Kernel File` `--build-tests` clean | Cross-cycle Signal.Information ambiguity (later promoted to P2.9) | Docker Linux swift-posix `--build-tests` clean (gate b) | P2.9 |
| Cycle 4 (2026-04-24) | Docker Linux swift-kernel `Kernel File` `--build-tests` clean | swift-foundations/swift-linux Random module-import drift (D5) | Docker Linux swift-linux-standard `--build-tests` clean with both unified A + post-deletion linux-standard in scope together | D5 |

Both cycles closed SUCCESS via [AUDIT-026]-shaped substitution. Both blockers were logged and remediated separately. Cycle 4's D5 was resolved 2026-04-24 via commit `61e52c4`; Cycle 3's P2.9 was resolved 2026-04-24 via Cycle 4 itself.

**Rationale**: Multi-cycle remediation arcs accumulate cross-cycle interactions that only surface at the broadest gates; the broadest gates are also the most likely to be blocked on unrelated ecosystem drift. Without [AUDIT-026], cycles either (a) wait indefinitely for orthogonal drift to clear (losing-battle pattern, the broadest gate becomes a moving target as ecosystem drift accumulates) or (b) re-derive the substitution framework each time and re-defend the close decision against principal review. Codifying the conditions standardizes the evidence-cite discipline and prevents the "fix the broad gate at all costs" anti-pattern.

---

## §[AUDIT-027] Shipping HOLD Evidence Bar (evicted 2026-07-05)

**Worked example (the origin incident)**:

Finding #12 in `swift-institute/Audits/borrow-pointer-storage-release-miscompile.md` proposed HIGH/HOLD on swift-memory-primitives + swift-buffer-primitives + swift-async-primitives based on V10/V11 synthetic reproducer (`@inlinable + withUnsafePointer(to: borrowing _storage) + ~Copyable container`). Without [AUDIT-027], the HOLD recommendation would have shipped on three packages.

The walkback: in-package release-mode tests on each production shape PASSED 3/3 (Memory.Inline, Buffer.Ring.Bounded, Async.Timer.Wheel). Finding #12 was rewritten from HIGH/HOLD to LOW/watchflag (commit `64f8362`); the regression guards landed as positive-assertion tests (commits `e390d7a`, `92e53fe`, `26e76e1`); shipping scope restored to NORMAL.

**Why the in-package test is the load-bearing artifact**:

The in-package test forces the audit author to construct the production shape — which is the step that exposes whether the extrapolation holds. A synthetic reproducer narrows the bug to a specific feature combination; the production shape may evade the combination by structural accident or design. The in-package test produces an unambiguous binary signal: either the shape exhibits the bug (HOLD justified) or it doesn't (HOLD overclaim). The synthetic reproducer alone cannot distinguish the two; only the in-package test can.

---

## §[AUDIT-028] Ghost-Reference Detection — Notation-Variant Coverage (evicted 2026-07-05)

**Worked example (the origin incident)**:

The 2026-04-24 implementation-layer cluster audit (8 skills, 600+ lines) initially missed three ghost-reference defects until the scanner was extended:

- (a) `existing-infrastructure/SKILL.md` See-Also line cited `[PATTERN-017–019]`. Per-ID grep matched only `[PATTERN-017]`. The `[PATTERN-018]` reference (not defined anywhere) was invisible until the em-dash form was explicitly handled.
- (b) `swift-forums-review/SKILL.md` uses `## [FREVIEW-XXX]` (level-2) for top-level rules. The cluster audit's cross-reference universe (anchored on `^### `) excluded these entirely. Initial misreport claimed `swift-institute-core` had broken `[FREVIEW-012]` / `[FREVIEW-018]` references; correction required re-running with `^#{2,3} ` prefix.
- (c) `implementation/SKILL.md` body of `[IMPL-050]` defines `[IMPL-051]` / `[IMPL-052]` / `[IMPL-053]` as in-body sub-labels. External citations from sibling skills referenced these as if they were top-level. Without sub-label inspection, the citations appeared as ghost references.

**Rationale**: Ghost-reference scans report a count; under notation-variant blindness, the count is a lower bound. Three independent failure modes each compound: cluster audit findings are systematically under-reported until every notation form is covered. Codifying the notation variants in the audit skill prevents future audits from re-deriving the scanner extensions and produces consistent counts across audit cycles.

---

## §[AUDIT-029] Empirical Census Before Options Matrix (evicted 2026-07-05)

**Worked example (the origin incident)**:

The 2026-04-26 lateral-L3 codification cycle started from audit findings P2.11 + P2.12 (two instances of L3 → L3 lateral composition flagged in `swift-institute/Audits/audit.md`). On principal direction, an empirical census of within-L3 imports across all 13 audit packages was run before drafting the options matrix. The census surfaced four additional patterns (Pattern 3 — swift-windows → swift-systems via `Windows.Thread.Affinity`; Pattern 4 — swift-file-system → unifier; Pattern 5 — same-tier domain-specific; Pattern 6 — test-scope laxer) that were not on the audit's P-series radar. The eventual rule shape ([PLAT-ARCH-008h] within-L3 sub-tiering matrix + [PLAT-ARCH-008i] POSIX-shared base composition carve-out) addressed Patterns 1-6, not just 1-2. Without the census, the rule would have been narrowly tailored to the two findings and would have left Patterns 3-6 un-codified, requiring later amendment cycles.

**Relationship to [HANDOFF-021]**: [HANDOFF-021] is the parallel discipline for handoff dispatch lists ("don't trust the agent's recall; re-derive the empirical package list from source"). [AUDIT-029] (this rule) extends the same discipline to rule codification: don't trust the audit's finding set as a complete sample of the pattern space; re-derive the population from source before codifying.

**Rationale**: Audits sample the rule space; their findings reflect the audit's coverage, not the population's distribution. Research Docs that codify patterns from audit findings without an empirical census produce rules that over-fit the audit's discovered cases and under-fit the broader pattern space. The census closes the sampling gap and ensures the rule extracts the population-level pattern. The cost is one grep / scan; the benefit is preventing rule-amendment cycles to absorb later-surfaced patterns.

---

## §[AUDIT-038] Four-Disposition Lint/Audit-Finding Triage (evicted 2026-07-05)

**Why the four dispositions, not two**: A two-class scheme ("rule is right → fix source" vs. "disable with reason") silently bakes rule-bugs into source workarounds whenever the rule is immature. The corpus being in development means neither "always trust the rule" nor "always fix the rule" is safe. Dispositions 2 and 3 separate the two ways a rule can be the thing that moves — *wrong shape* (fix-rule) versus *right shape but must carve out a structural pattern* (deliberate-exemption via a named `[RULE-EXEMPT-N]` shape) — and disposition 4 keeps genuinely-undecided findings out of both source and rule until the principal decides.

**Ghost-repair note**: this rule resolves the [AUDIT-035] ghost — the 2026-05-15 changelog claimed a four-disposition framework at [AUDIT-035] but the body was never written ([SKILL-LIFE-006] silent-edit-failure class). The [AUDIT-035] slot stays burned per the 2026-06-04 [AUDIT-036] note; the real body is this rule, [AUDIT-038]. The disposition set here promotes the deliberate-exemption route (via the **rule-exemptions** skill) in place of the ghost line's "ACCEPT-AS-WARNING".

**Provenance (full form)**: memory `feedback_lint_triage_three_class.md` (three-class scheme: fix-source / fix-rule / ambiguous, "rule is right" not assumed), extended with the deliberate-exemption disposition routed through the **rule-exemptions** skill's `[RULE-EXEMPT-*]` shapes.

---

## §[AUDIT-039] Re-Verify a Just-Observed Baseline Failure (evicted 2026-07-05)

**Relationship to [AUDIT-034]**: [AUDIT-034] re-verifies *inherited prior-document findings* (audit.md, research, handoff) before carrying them into synthesis. [AUDIT-039] (this rule) is its live-session sibling: re-verify a *just-observed* baseline failure before it becomes the premise of an escalation or path-choice. Same principle — a state claim's authority decays between observation and action — applied at two different timescales (30-day inherited findings vs. seconds-to-minutes in a fast-moving zone).

**Worked example (origin incident)**: 2026-05-15 cardinal-canary run during the swift-linter bottom-up sweep read `swift-process` as "1 commit behind origin" with `Poll.Entry._raw` at `Process.Spawn.Capture.POSIX.swift:678`, then immediately drafted an A/B/C escalation (pull-origin / local-fix / hold). By the time the principal responded, swift-process was 3 commits AHEAD (a parallel v2 Windows arc) and `_raw` had already been revised out in the working tree — all three options were wrong because the premise was stale.

**Rationale**: Composes with [SUPER-056] non-interference — the same iteration-zone churn that makes cross-arc edits forbidden also makes a just-observed failure a decaying state claim. Anchoring the escalation to verified-now evidence prevents drafting a path-choice on a premise that has already resolved itself.

---

## §[AUDIT-040] Weigh Evidence by Commit Recency When Adjudicating (memory-drain fold 2026-07-05)

**Why recency, not existence**: The ecosystem is a maturing corpus — conventions (namespace shape, typed throws, `~Copyable`/ownership adoption, region-based `Sendable`) converged over time, so a given file's shape encodes *the convention as of its last touch*, not the current model. Treating "it exists and compiles" as a blessing grandfathers pre-convention legacy into current decisions. The failure mode is asymmetric and expensive at flip time: an irreversible public flip (tag, visibility change) made on the strength of an old surface's mere existence cannot be walked back cheaply. Commit recency is the cheap discriminator — `git log` the cited paths and let the newest converged pattern win.

**The two directions**:
- **Choosing a precedent / model to emulate**: pick the newest converged pattern. `array-primitives` (the `Array<S>`-over-column design, the column vocabulary) is a current reference MODEL for the column-ADT family; emulate it.
- **Readying OLD code**: scrutinise for staleness rather than assume-correct. Old `Heap.Min/Max` `fatalError` stubs are a flip-readiness *question* (should public `fatalError` stubs ship?), not a benign "`@frozen` doesn't fire" precedent; a stale README on an old package is a defect to fix, not a template to copy.

**Relationship to the sibling rules**: [AUDIT-033] bounds what grep-EMPTY can prove (negative claims only); [AUDIT-034] re-verifies inherited *findings* against current code; [AUDIT-040] (this rule) governs which *code* counts as the model when two surfaces conflict. All three share one root: authority is not conferred by age or by prior status — it is conferred by verification against the current corpus. Generalises the memory-safety legacy posture (`@Sendable` sites are pre-[MEM-SEND-012] legacy, revised freely when touched; [MEM-SEND-*]) from one annotation class to the whole code corpus.

**Provenance (full form)**: memory `feedback_weigh_by_commit_recency` (principal directive 2026-06-15), which generalised `feedback_sendable_sites_not_presumed_correct` / `feedback_sendable_legacy_posture_default_revise` across the corpus and relates to `feedback_lint_triage_three_class` (the corpus is still maturing, so "the rule/old-code is right" is never assumed).
