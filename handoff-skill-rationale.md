# Handoff Skill Rationale Archive

<!--
version: 1.0.0
last_updated: 2026-07-02
status: REFERENCE
-->

> Non-normative companion to `Skills/handoff/SKILL.md` (per Research/ecosystem-meta-setup-target-state.md §D1).
> This document holds evicted rationale prose, provenance, extended worked examples, incident narratives,
> second/third example variants, and the dated amendment changelog. The skill file remains the CANONICAL
> source for all `[HANDOFF-*]` requirement statements; nothing in this archive is normative. Organized by
> rule ID in skill order; the dated frontmatter changelog entries are collected in the final section.

---

## §[HANDOFF-004] Sequential Template

**Section ordering rationale (full form)** (evicted; the one-sentence form remains in-skill):

**Section ordering rationale** (from "lost in the middle" research):
- Goal at the top — establishes context in the highest-attention position
- Next Steps at the bottom — action items in the second-highest-attention position
- Background in the middle — the new agent reads it but doesn't need to recall it verbatim

---

## §[HANDOFF-007] Token Budget

**Rationale**: A bloated handoff consumes the new session's context, accelerating the next degradation cycle. Program briefs additionally consume *every* session's context that picks up *any* wave, because the next session has to decide which wave to claim before reading wave-specific detail. Pre-splitting moves the wave-claim decision to the workspace-level (file selection) and keeps each session's context budget proportional to the wave it actually picks up.

**Provenance**: Reflection `2026-04-30-phase-1b-stale-triage-and-deferred-fixed-codification.md` (Tier-2 skill-corpus-cleanup + handoff-lifecycle-research drafts both exceeded 800 tokens because deliverable scope was the brief; wave-split was the correct shape but the rule didn't surface until post-hoc).

---

## §[HANDOFF-009] Progressive Capture

**Unrelated-prior-task collision branch — origin incident** (provenance tail of the in-skill paragraph):

Provenance: end of the 2026-05-14 CI Review arc — invoking `/handoff` for Phase C while a 22-day-stale unrelated `HANDOFF.md` (Property Primitives 0.1.0 launch, blocked on user tag auth) was holding the canonical filename slot. Ad-hoc rename-to-topic-suffix preserved the launch handoff as `HANDOFF-property-primitives-launch.md` while allowing the new CI-arc handoff to land at `HANDOFF.md`. Codified per reflection `2026-05-14-ci-review-arc-phase-a-c-supervision-gaps.md` action item via `/reflections-processing` 2026-05-15.

---

## §[HANDOFF-010] Resume Protocol

**Rationale**: Verification prevents acting on stale context. Confirmation gives the user a chance to correct. The supervisor-block step ensures handoffs that carry ground-rules from a prior supervisory phase do not silently drop those constraints when the supervisor's session ends — the block becomes the supervisor in absentia.

---

## §[HANDOFF-008a] Retirement on Consumption

**Rationale**: Without a retirement step, handoffs accumulate indefinitely — the rootless workspace reached 71 (31 in one week) by 2026-06-01 because the create→consume lifecycle had no delete. Tracking does NOT fix this (a tracked handoff piles up identically and pollutes history); a *lifecycle* does.

**Provenance**: institute leanness program 2026-06-01 (`project_institute_leanness_program`); closes the silent-accumulation gap in the unconditional location rule.

---

## §[HANDOFF-013] Prior Research Check for Branching Investigations

**Example (defect)**:
```
Step 1: Read HANDOFF-public-api-review.md
Step 2: Draft Research/public-api-spec.md from scratch
Step 3: Reviewer discovers prior tier-0-consumer-api-review.md contradicting the new spec
Step 4: Delete the new spec; re-do the work
```

**Rationale**: The 2026-04-07 swift-io session produced a public-API spec that duplicated and contradicted a pre-existing `tier-0-consumer-api-review.md` from the day before. A subagent's fresh-eyes review caught it with one grep. The discipline is cheap (seconds) and the cost of skipping it is high (deleted work + reviewer friction + contradictory docs live simultaneously). Research-heavy repos (swift-io has 7+ research docs) carry high duplicate-likelihood.

**Provenance**: 2026-04-07-actor-state-inline-fallback-visibility.md

---

## §[HANDOFF-014] Pre-Existing Code in Scope

**Example (defect)**:
A handoff whose Goal is "redesign full IO public API" but whose investigation was scoped to the blocking subsystem. 100 files of pre-existing `IO.Event.*` / `IO.Completion.*` runtime code treated as "Phase 2/3 roadmap items" with no enumeration of their pre-existing status or intended treatment. Fresh-perspective review catches the elision; without the review, Phase 2 collides with production code at execution time.

**Rationale**: The 2026-04-14 swift-io handoff elided ~100 files of pre-existing runtime code because the originating investigation had narrow scope and the plan scope widened without re-inventorying the workspace. The pattern recurs whenever investigation-scope and plan-scope diverge. Forcing enumeration surfaces the gap at handoff-writing time rather than execution time.

**Provenance**: 2026-04-14-io-design-review-cycle.md

---

## §[HANDOFF-015] Audit Handoff Naming

**Rationale**: The 2026-04-15 swift-institute perfection-check cycle ran three audit phases producing 69 findings across integrity, CI/OSS-norms, and content-correctness. Distinguishing audit artifacts from task artifacts (a) allows differential gitignore treatment — audit history stays in the repo, task handoffs churn — and (b) helps reviewers scan filenames and route audits to the audit skill's tooling. Absent the convention, `HANDOFF-*.md` matches both audits and task handoffs, triggering the audit skill's in-place-update behavior on files never meant for it.

**Provenance**: 2026-04-15-three-phase-perfection-check-and-supervision.md

---

## §[HANDOFF-017] Terminal Consumer Migration for Multi-Finding Audit Cycles

**Rationale**: Two 2026-04-20 audit cycles (Platform Compliance + L3 Unifier Composition) each produced findings whose consumer migrations overlapped substantially — error-code predicates affected one accessor extension; retry-wrapper adoption affected a single migration class. The user directed "upstreams first, then one consumer pass" both times. Codifying as a dispatch-planning rule avoids per-audit rediscovery.

**Provenance**: 2026-04-20-l3-unifier-composition-discipline.md

---

## §[HANDOFF-018] Opt-Out Clauses Are Preferences, Not Permissions

**Rationale**: The 2026-04-20 Kernel.Error.Code predicates session hit this failure twice — once as test opt-out (skipped tests, reviewer corrected), once as `[PLAT-ARCH-008a]` exception (defended `#if os(Windows)` as permitted when the user's question was whether it was necessary). Both costs were one round-trip each; a mechanical intent-reading check closes them.

**Provenance**: 2026-04-20-kernel-error-code-predicates-handoff-premise-audit.md; 2026-04-20-file-name-nul-fix-execution-and-path-char-adoption.md

---

## §[HANDOFF-019] Commit-as-you-go for Multi-Phase Multi-Repo Refactors

**Rationale**: The 2026-04-20 `[PLAT-ARCH-008e]` flush-family landing accumulated edits across four repos over three phases without committing. A `git reset --hard HEAD` in the middle repo (user acknowledged as accidental) discarded the Phase A work; dependent Phase B/C edits then referenced non-existent renamed methods. Per-phase commits would have converted "lost work" into "local ref manipulation, nothing lost."

**Provenance**: 2026-04-20-kernel-file-flush-plat-arch-008e-execution.md

---

## §[HANDOFF-049] Stash-Edit-Commit-Pop Pattern for Cross-Session Contamination

**Worked example** (canonical 2026-05-05 origin incident): tier-2 + tier-3 verification-taxonomy dispatches both faced cross-session contamination (`Reflections/_index.json` modifications + 6-8 untracked Reflections from prior sessions; `Research/_index.json` carrying `wasm-ci-strategy-and-sdk-toolchain-coupling.md` + `skill-verification-taxonomy-pilot.md` entries from prior sessions). `git stash push -- _index.json [Reflections/_index.json]` isolated prior-session edits; main thread edited clean state; commits `bc8d682` (tier-2) and `0b725da` (tier-3) contained only the dispatch's edits; `git stash pop` cleanly auto-merged in both cases.

**Why selective stash, not blanket `git stash`**: the pattern targets specific shared files. Blanket `git stash` would also stash session-local untracked files and non-shared edits, leaving the working tree empty during edit-commit and requiring full pop afterward. Selective stash isolates only the contamination, preserving session-local context.

**Generalization**: any session that needs to commit a partial diff in the presence of pre-existing uncommitted working-tree changes from prior sessions can use this pattern. It complements [HANDOFF-019] commit-as-you-go (which addresses commit-frequency) by providing the file-level contamination-isolation primitive.

**Provenance**: Reflection `2026-05-05-skill-verification-taxonomy-tier-2-tier-3-and-ecosystem-closure.md` — used twice cleanly in the same session.

---

## §[HANDOFF-020] Correction-Cycle Handoffs (Sequential with Inherited Context)

**Rationale**: Correction cycles produce reusable *process* (phases, role templates, dialectic structure) and reusable *decisions* (protocol-split pattern, wave-0 safeguard tests) but only selectively reusable *artifacts*. Carrying forward decisions explicitly prevents the new cycle from re-deriving them; flagging expected divergences prevents the new cycle from blindly porting. The 2026-04-18 path-ecosystem cycle demonstrated the pattern works; writing it as a handoff template makes it reproducible.

**Provenance**: 2026-04-18-path-ecosystem-correction-cycle-and-process-distillation.md

---

## §[HANDOFF-016] Handoff Staleness Axes

**Common-loci catalogs** (evicted; the seven-axis table remains in-skill):

**Common loci of proposal staleness**:

- **Branch names**: a handoff prescribing `git checkout -b topic-branch` when `main` has moved 16+ commits ahead and is itself the working branch — the topic branch adds friction without value
- **API signatures**: a handoff prescribing `Result<T, E>` when the ecosystem has since converged on `() throws(E) -> T` thunks
- **Tool choices**: a handoff prescribing a helper that has since been deleted, renamed, or moved to a different package
- **Module layout**: a handoff prescribing a target/module that has since been split, merged, or relocated per modularization skill updates

**Common loci of premise staleness**:

- **Platform-compilation claims**: a handoff asserting *"package X compiles on platform Y only, therefore zero `#if os(...)` guards"* without verifying `Package.swift` actually carries a `.condition: .when(platforms:)` on the target
- **Relocation claims**: a handoff asserting *"type Z lives at `swift-foo/Sources/.../Z.swift`"* when an earlier refactor relocated it
- **Ecosystem-shape claims**: a handoff asserting *"no existing typed API covers this case"* without greping the canonical research doc
- **Aggregated-count-with-embedded-property claims**: *"N public packages"* aggregates items with mixed visibility. When the count's accuracy matters for downstream reasoning (leak scans, safe-reference assumptions, migration preconditions), verify the embedded property by enumeration (`for pkg in ...; do gh repo view ... --json visibility; done`) rather than trusting the aggregated count

**Common loci of scope-flag staleness**:

- **Out-of-scope type shape**: "X is out of scope" because the author believed X was correct; session work reveals X is the root cause (e.g., `File.Name.RawEncoding` excluded from a NUL-fix handoff, then surfaced as the real defect)
- **Deferred "broader unification"**: "D1 unification handled separately" — when the immediate task cannot be cleanly resolved without the broader unification, the deferral is stale
- **"Ecosystem-wide" exclusions**: when the task's symptom is ecosystem-wide but the handoff's scope was narrowed pre-investigation

**Example (defect)**:
```
Handoff says: "Change tick parameter to Result<T, E>"
Agent applies the edit without checking /implementation for current
conventions on callback outcome signatures.
User intervenes mid-edit: "we should use LANGUAGE SEMANTICS so throws
see /implementation. dont use Result."
Partial edit must be rolled back and redone with throws(E) thunk.
```

**Rationale**: [HANDOFF-010] Resume Protocol covers work staleness through state verification. Proposal staleness is a distinct failure mode: the listed state is correct, but the recommended approach is not. A prior-session author encoded their best understanding at the time; hours later, repo state, ecosystem conventions, or skill updates may have invalidated those specific prescriptions even though the overall task remains valid. Treating handoffs as inputs-to-a-current-state-check, not binding specifications, prevents compounding the first author's now-stale decisions into the resuming session's output.

**Provenance**: 2026-04-15-polling-tick-throws-thunk-over-result.md; premise-staleness axis added per 2026-04-20-kernel-error-code-predicates-handoff-premise-audit.md; scope-flag-staleness axis added per 2026-04-20-file-name-nul-fix-execution-and-path-char-adoption.md; live-revisions axis added per 2026-04-17-institute-repo-split-and-supervise-absentia-review.md; transcription-staleness axis and metric-freshness sub-axis added per 2026-04-22-body-org-tooling-extension-and-authorization-envelopes.md and 2026-04-22-category-a-bulk-scaffold-and-spm-umbrella-fallback.md; aggregated-count locus added per 2026-04-22-standards-org-migration-phases-1-5-execution.md.

---

## §[HANDOFF-013a] Writer-Side Prior-Research Grep

**Rationale**: [HANDOFF-013] covers the receiver's check; the writer's symmetric check is cheaper (the writer already has context loaded) and prevents the receiver from executing against a defective prescription. The 2026-04-20 File.Name session hit this failure mode: writer proposed a handoff without greping; sibling agent executing it caught the D1 violation; rework + user intervention followed. The discipline is ~30 seconds; the cost of skipping it is a re-written handoff plus a sibling agent's rolled-back WIP.

**Provenance**: 2026-04-20-swift-file-system-io-migration-and-l1-vocabulary-overreach.md

---

## §[HANDOFF-013b] Build-Level Visibility Pre-Flight for Deletion-Without-Adoption

**Worked example (the origin incident)**:

Cycle 4 P2.9 Phase 0.5 grep produced one consumer reference (`Linux.Kernel.IO.Uring.Entry+Prepare.swift` waitid `UnsafeMutablePointer<Kernel.Signal.Information>`) and stamped "drop-all." Phase 2 deletion built clean on `Linux Kernel System Standard` (the deleted type's containing target) but failed on `Linux Kernel IO Uring Standard` with `'Information' is not a member type of enum 'Kernel_Namespace.Kernel.Signal'`. Root cause: the deleted type's co-location in `Linux_Kernel_System_Standard` had been providing accidental transitive visibility for the type name; the io_uring file never explicitly `public import`ed `ISO_9945_Kernel_Signal`. The build-level pre-flight (a single `grep -l "public import ISO_9945_Kernel_Signal"` against the consumer file) would have caught this at handoff-write time.

**Rationale**: Pre-Swift-6 ecosystems had lax transitive visibility through umbrella re-exports that made grep-level consumer counts approximately correct for delete-public-type planning. Swift 6.3+ ecosystems using `InternalImportsByDefault` + `MemberImportVisibility` narrow transitive visibility; accidental visibility via co-location can mask missing-import defects until deletion exposes them. The handoff-writer is the right place to catch this — by handoff-write time, the writer has the type's declaring module + the consumer site list; the additional file-level grep takes seconds.

**Relationship to neighboring rules**: [HANDOFF-013a] is about prior-research grep (avoid prescribing already-decided shapes). [HANDOFF-013b] (this rule) is about post-deletion build-graph verification (avoid prescribing structurally-incomplete deletions). [SUPER-026] is the parallel rule on the principal-authorization side (the principal verifies the same property at dispatch-authorization time). Together the three close the writer + dispatcher + supervisor surface for delete-public-type defects.

**Provenance**: Reflection `2026-04-24-post-cycle-3-audit-and-p2-9-unify-cycle-4.md` (Phase 2 io_uring orphan-reference build-time failure).

---

## §[HANDOFF-021] Scope Enumeration at Write-Time

**Rationale**: "Apply X to every Y" handoffs are latently non-self-verifying: the writer's mental enumeration of Y is invisible to the reader, who cannot tell whether the listed instances are complete or whether the set has shifted. Attestation-by-enumeration without the generating command is an assertion the subordinate cannot check. Including the command moves enumeration from author-memory into a reproducible artifact. Parallels [HANDOFF-013a]'s writer-side grep discipline for research, extended to execution-scope enumeration.

**Example (defect)**: A handoff instructing "apply Phase B split to every Socket handoff" that enumerates 10 handoffs in § Relevant Files without citing the generating command. Mid-execution, the subordinate discovers two handoffs the writer missed. The writer's enumeration was memory-scoped; no command existed to rerun.

**Tracked-state pre-flight extension — origin incident** (provenance tail of the in-skill paragraph):

Provenance: Phase B-3 of the 2026-05-14 CI Review arc (commits `5ebcac5` → `1fb7604` amend) where validate-thin-callers.yml was listed as a SHA-uplift target without checking its tracked state; `git add` staged 152 untracked lines alongside a 1-line intended uplift.

**Provenance**: 2026-04-21-handoff-author-scope-enumeration-and-supervise-first-deployment.md; tracked-state pre-flight extension added 2026-05-15 per reflection `2026-05-14-ci-review-arc-phase-a-c-supervision-gaps.md` via `/reflections-processing`.

---

## §[HANDOFF-022] Do-Not-Touch vs Phase-Scope Conflict

**Provenance**: 2026-04-22-standards-org-migration-phases-1-5-execution.md; 2026-04-22-tri-agent-ci-rollout-execution-and-standards-migration.md

---

## §[HANDOFF-023] Bulk-Push Authorization Class

**Rationale**: Authorization for `git push` in a single repo does not scale linearly to a loop that pushes across an ecosystem. The blast radius (how many consumers notice, how many CI runs trigger, how hard it is to unwind if anything is wrong) is categorically different. Hooks enforce this mechanically; encoding it at the skill level makes the distinction visible to agents writing and reading handoffs before a hook fires.

**Provenance**: 2026-04-22-tri-agent-ci-rollout-execution-and-standards-migration.md

---

## §[HANDOFF-024] Empirical-Grep-First at Scope-Expansion Blockers

**Rationale**: Multi-phase migrations that expose unexpectedly-large downstream cascades invite architectural proposals scaled to the imputed size. When the imputation is wrong, the proposal is over- or under-scaled, and the iteration loop (propose → discover-more → revise) consumes many round-trips that a single grep would have closed. The 2026-04-21 descriptor-migration cycle iterated v2→v5 on imputed cascade sizes; v6's grep pass collapsed the Completion cascade to zero. Five iterations of proposal work were displaced by one grep.

**Example (defect)**: Phase-2 reports 30 affected files. Phase-3 proposal imputes "likely ~150 across three repos"; scopes for ecosystem-wide refactor. Phase-4 discovers the actual cascade is 15. Three rounds of scope revision result.

**Provenance**: 2026-04-21-descriptor-migration-supervisor-flipping-and-v6-convergence.md

---

## §[HANDOFF-025] Anti-Defer Rule for Cheap Verifications

**Rationale**: Defer-to-follow-up artifacts compound: the follow-up session re-reads the artifact, re-identifies the defer marker, and must redo the check the writer could have done in 30 seconds. On a multi-finding artifact, the round-trip cost grows linearly; on an enumeration with N cheap items, N deferred checks is a multiplicative defect. Running the checks at write-time converts discovery-before-decision into a fixed cost paid once.

**Provenance**: 2026-04-22-heritage-transfers-investigation-and-placeholder-verification-gap.md

---

## §[HANDOFF-026] Preserved-File Compile-Verification Sub-Requirement

**Rationale**: The `Preserved` label encodes a claim the writer cannot sustain without a mechanical check. `Preserved` asserts "no changes planned" — but a file that references a type being deleted IS changing by necessity (either the delete propagates to the file, or the delete is not actually happening). The asserted-but-unverified label lets a layer violation survive handoff-review and surface at execution time, where the subordinate must either reject the handoff or re-derive the plan.

**Provenance**: 2026-04-17-io-completions-cancel-target-bug-structural-fix.md

---

## §[HANDOFF-027] Dead-Ends / Next-Steps Writer-Side Cross-Check

**Rationale**: Dead Ends exist to prevent re-derivation. A structurally-equivalent prescription with renamed types still re-derives the refuted pattern; when execution discovers the same failure mode, the handoff has to be re-written under pressure. The 30-second writer-side shape comparison is strictly cheaper than the re-derivation cost. Parallels [HANDOFF-013a]'s writer-side grep (symmetric for prior research); this is the writer-side shape grep (symmetric for prior failures).

**Provenance**: 2026-04-24-ownership-primitives-timeless-completion-and-docc-patch-gap.md

---

## §[HANDOFF-028] (Reserved)

**Provenance**: Holistic skill-corpus review (`swift-institute/Research/skill-corpus-holistic-review.md`, 2026-04-30); the orphan slot was identified by mechanical numbering scan and preserved per minimal-revision discipline rather than by collapsing the sequence (which would invalidate any external citations against `[HANDOFF-029]`–`[HANDOFF-030]`).

---

## §[HANDOFF-029] Pre-Fire Precondition Re-Check for Bulk Operations

**Rationale**: Authorization is granted against a snapshot of state. Work that was authorized at t=0 may be executing at t=10min against a different state. The re-check cost is negligible (seconds); the cost of proceeding on stale authorization can include a correction commit, a revert, or an escalation to another principal to resolve what the subordinate shipped. Pre-fire re-check is the cheapest insurance against principal-subordinate staleness introduced by concurrent work.

**Provenance**: 2026-04-22-body-org-tooling-extension-and-authorization-envelopes.md

---

## §[HANDOFF-030] Cost-Calculus Base-Rate Requirement

**Rationale**: Cost calculus without base-rates is formally indistinguishable from advocacy. Reader and writer may each fill in plausible base-rates that differ by orders of magnitude; the argument then reads as dispositive to both, but for incompatible reasons. Explicit base-rates convert the argument from assertion to verifiable claim: the reader can agree or contest the frequency without disputing the per-event cost.

**Provenance**: 2026-04-23-ci-permission-architecture-path-b-execution.md (retraction of argument #1 after the unstated N-growth assumption was surfaced)

---

## §[HANDOFF-024a] Linux Baseline Pre-Flight — Mandatory-to-Run, Conditional-on-Fix

**Why conditionality matters**: a green pre-flight is itself useful information for the next sub-cycle's pre-flight planning. Documenting "ran clean — no prereq needed" in the cycle's close report tells the next dispatch whether to expect a prereq pattern (cross-package vestigial imports surfacing under Linux baseline) or not (target-internal imports).

**Worked example (the origin incident)**:

Path X Phase 1 sub-cycle 1.7 needed Linux baseline prereq (`f2959bc` / `6bb1402`) before its main work because the file family had cross-package vestigial imports (`shm_open` + `Thread.Key`). Sub-cycle 1.1 ran the same pre-flight discipline and needed nothing — the File family's typed forms are self-contained within iso-9945's `ISO 9945 Kernel File` target. The conditional outcome is the right model; the previous handoff's framing of "analog to 1.7 prereq" read ambiguously as if a prereq commit was always part of the deliverable.

**Rationale**: A pre-flight that runs clean is a successful pre-flight. The framing "analog to prior prereq" should be read as "run the same kind of check," not "produce the same kind of artifact." Codifying the conditionality prevents future sessions from hesitating on "do I need a prereq commit if pre-flight is clean?" The cost of running the pre-flight is the same regardless of outcome (one Docker build); only the post-pre-flight action differs.

**Provenance**: Reflection `2026-04-28-sub-cycle-1-1-inverted-pattern-a.md` (sub-cycle 1.1 pre-flight ran clean, no prereq needed; contrast with 1.7 prereq).

---

## §[HANDOFF-031] Syntactic-vs-Semantic Disclaimer for Regex Enumerations

**Worked example (the origin incident)**:

Path X Phase 2's brief used `grep -rln ": Kernel\.Descriptor\b"` to enumerate Pattern A surfaces in `swift-windows-standard`, producing a 22-file count. The semantic intent was "files containing functions whose parameters take `Kernel.Descriptor`." The regex matched both function parameters AND struct field declarations.

`Windows.Kernel.Pipe.swift` matched the regex via `Pair.read: Kernel.Descriptor` and `Pair.write: Kernel.Descriptor` STRUCT FIELD declarations — its `create(...)` factory functions return `Pair`, not take a descriptor parameter. Pipe.swift had ZERO Pattern A function sites. The 22-file count was syntactically correct on paper but semantically over-inclusive by one file.

The subordinate caught it in-action at Wave 4 per [SUPER-024] (in-action when preconditions are unmet); the handoff's syntactic-vs-semantic disclaimer would have surfaced the issue at handoff-write time and saved the in-action discovery cost.

**Rationale**: Regex enumerations are mechanically reproducible (good per [HANDOFF-021]) but syntactically scoped (potentially over-inclusive). The brief writer who runs the regex can't tell which matches are semantically out-of-scope without per-file inspection, and the inspection cost is borne by every subsequent reader. Surfacing the mismatch at write-time — either by narrowing the regex or by documenting the false-positive shapes — moves the inspection cost to the writer once instead of every downstream reader.

**Provenance**: Reflection `2026-04-29-path-x-phase-2-windows-mirror-execution.md` (Pipe.swift false-positive in 22-file Pattern A grep).

---

## §[HANDOFF-032] Extraction-Time Material Check (Writer-Side Prior-Research, Generalized)

**Why downgrade matters**: duplicating already-captured material has high downstream cost (review burden, drift between copies, future-auditor confusion when both copies exist). The check at extraction time is cheap (one or two greps + one read of the matched section). The asymmetry favors checking before extracting.

**Worked example (the origin incident)**:

The 2026-04-29 bulk-triage cycle had `HANDOFF-primitive-protocol-audit.md` classified extract-to-both (audit findings + cross-cutting patterns). Pre-extraction grep verified findings were already captured:

- System.Page #3 / Processor #4 RESOLVED 2026-04-26 in `swift-primitives-platform-code-inventory.md`
- Terminal.Mode.Raw.Token #19 + Loader.Section.Name #18 ACCEPTED under [PLAT-ARCH-008a]
- Type.Protocol pattern documented in [PLAT-ARCH-008c] skill rule + reflection `2026-04-01-path-protocol-architecture-and-platform-extension-principle.md`

Mechanical grep at execution sites confirmed no `Darwin/Glibc/Musl` imports remain in system-primitives; no `windowsHandle` in terminal-primitives. Extraction would have duplicated already-captured material. Reclassified to "delete"; saved an unnecessary audit-doc creation, commit, and index update at the cost of ~30 seconds of greps.

**Relationship to [HANDOFF-013a]**: [HANDOFF-013a] is the writer-side rule for new handoff authoring (avoid prescribing already-decided shapes). [HANDOFF-032] (this rule) is the writer-side rule for extracting material from an existing handoff at end-of-life (avoid duplicating already-captured material). Both are pre-write greps against canonical destinations; [HANDOFF-032] applies specifically at the extract-then-delete boundary.

**Rationale**: Extract-then-delete frameworks (like the 2026-04-29 bulk-triage cycle's six-phase pipeline) accumulate extraction commits at the end-of-life boundary. Without the extraction-time check, every extraction-classified handoff produces an audit doc; many of those duplicate already-captured material. Codifying the check generalizes [HANDOFF-013a]'s prior-research discipline to the symmetric extraction case and prevents the duplication cost from compounding across triage cycles.

**Provenance**: Reflection `2026-04-29-handoff-triage-cycle-and-d-to-a-reclassification.md` (D→A reclassification of `HANDOFF-primitive-protocol-audit.md` after pre-extraction grep showed material already captured at three canonical destinations).

---

## §[HANDOFF-033] L1-API-Change Cascade Disclosure

**Rationale**: A subordinate's [SUPER-005] class-(b) escalation reflex fires on apparent scope expansion. When the implementer encounters a consumer migration that the handoff did not name, they must either escalate (latency cost) or proceed silently (drift cost). Pre-disclosing the cascade in the handoff text eliminates both — the implementer treats the migration as expected scope, no escalation needed.

**Worked example (the origin incident)**: A 2026-04-16 supervised implementation of `Executor.Job.Deque` at L1 required a mechanical Worker.swift API migration at L3 (consumer of the new deque API). The handoff didn't list Worker.swift in Changed Files; the implementer modified it without escalation. The change was correct but the supervisor couldn't verify it until after the fact — a process gap caused by the missing pre-disclosure.

**Provenance**: Reflection `2026-04-16-executor-deque-peer-review-to-production.md`.

---

## §[HANDOFF-034] Consumer Migration Bundling Anti-Pattern

**The structural reason**:

Consumer-site retargeting from `POSIX.Kernel.X.method(...)` to `Kernel.X.method(...)` (or equivalent) can only land coherently after EVERY upstream change is in place. Bundling consumer migration into an upstream dispatch as "Commit 6" forces the consumer migration to either (a) land partially with stale references for upstreams that haven't landed yet, or (b) wait for all upstreams anyway, in which case the bundling provides no value and obscures the dependency.

**Worked example (the origin incident)**:

The 2026-04-20 L3 Composition audit's retry-wrapper bundle (5 commits closing #5–#16) was initially drafted with "Commit 6: consumer migration sweep across ecosystem" as a final step. User correction: consumer migration spans BOTH the L3 Composition audit AND the sibling Platform Compliance audit. Bundling it into the retry-wrapper dispatch fragmented the terminal pass across PRs (each upstream's "Commit 6" could only migrate consumers matching that upstream's scope). The Commit 6 was extracted into `swift-file-system/HANDOFF-platform-compliance-consumer-migration.md` — gated on ALL upstream handoffs across BOTH audits landing.

**Relationship to [HANDOFF-017]**: [HANDOFF-017] prescribes the positive form (terminal handoff for cross-audit consumer migration). [HANDOFF-034] (this rule) prohibits the inverse anti-pattern (bundling into upstream dispatches). Both rules cite the same structural fact: consumer migration is dependency-graph-terminal, not per-family-final.

**Provenance**: Reflection `2026-04-20-l3-composition-audit-plat-arch-008e.md`.

---

## §[HANDOFF-035] Cascade-Migration Termination Criteria

**Why per-sub-repo builds are insufficient**: When edits land one sub-repo at a time and each sub-repo's `swift build` passes independently, the subordinate's attention surface ends at the changed sub-repos. Transitive consumers in *parallel* org-level directories build only when they themselves become the working directory — they are invisible to per-sub-repo build cycles. The "all green" attestation derived from per-sub-repo builds is incomplete by construction.

**Worked example (the origin incident — Sources/Tests-only baseline)**:

A 2026-04-23 Ownership.Borrow.`Protocol` cascade attestation v1.2.0 was based on per-sub-repo isolated builds across 3 sub-repos. Post-execution principal audit found ~100 Sources + ~8 Tests residual sites across 6 packages outside the plan's grep scope (swift-iso-9945: 48, swift-kernel: 25, swift-posix: 10, swift-windows-standard: 8, swift-file-system: 6, swift-linux-standard: 3). Plan downgraded v1.2.0 IMPLEMENTED → v1.3.0 PARTIAL_IMPLEMENTED. Phase 9 recovery (7 commits across 7 sub-repos) under hardened ground rules (workspace-wide grep + ecosystem-wide build gate as termination criterion) restored completeness.

**Worked example (the 2026-05-14 Package.swift-residual incident)**:

The Coder/Serializer modeling arc (W1–W5) removed the `Serialization Primitives` product as part of a cascade rename. W4's end-of-phase workspace-wide grep on `Sources/` and `Tests/` returned empty across all consumer repos — apparent completeness. T1 then surfaced as a cascade gap: `swift-incits-4-1986/Package.swift` still referenced `.product(name: "Serialization Primitives", …)` in its `targets:` block, and the package failed to resolve when next built. Fix landed as commit `2450569` on swift-incits-4-1986. The W4 grep would have caught the residual had it included `Package.swift` declarations; the Sources/Tests-only scope produced a false-clean attestation. This amendment closes the gap.

The defect was not subordinate sloppiness — it was the original handoff's termination criteria being too weak. [SUPER-009]'s "attestation vs verification" principle applies: per-sub-repo build output is attestation-equivalent because it doesn't cover the space of things that can break.

**Provenance**: Reflection `2026-04-23-borrow-protocol-unification-full-cascade-and-iso-9899-tail.md` (Phase 1–7 v1.2.0 incomplete-sweep failure; Phase 9 recovery under hardened ground rules). 2026-05-14 amendment provenance: W4 of the Coder/Serializer modeling arc — `swift-incits-4-1986/Package.swift` stale `.product(name: "Serialization Primitives", …)` reference surfaced as T1 cascade gap; commit `2450569` on swift-incits-4-1986 fixed it.

---

## §[HANDOFF-036] Recipe-and-Path-Math Empirical Verification

**Worked example (the origin incident)**:

A 2026-04-23 superrepo-dismantle handoff prescribed `git config --file .git/config --unset core.worktree` for the gitdir-to-standalone conversion. After the gitdir copy step landed, the command failed because git resolves the now-broken worktree before unsetting. Alternative `sed -i.bak '/worktree =/d' .git/config` worked. The recipe was correct in isolation; under the recipe's specific post-state, it broke.

A 2026-04-24 layer-container-orphan-triage handoff Constraint 3 encoded a path-math claim about relative paths that turned out off-by-one. Verification via `python3 os.path.normpath` would have caught it before downstream sessions executed against the wrong math.

**Provenance**: Reflections `2026-04-23-superrepo-dismantle-and-phase-0-5-remediation.md` + `2026-04-24-layer-container-orphan-triage.md`.

---

## §[HANDOFF-037] Probe-List vs Do-Not-Touch Internal Contradiction (Sixth Staleness Axis)

**Why this is staleness**: An internal contradiction means the handoff's own self-claims are inconsistent. The author drafted the probe list with one mental model and the Do-Not-Touch list with a different one (or the lists were drafted at different times against different states). Either way, the contradiction predates the subordinate's session and cannot be silently resolved by following one side and ignoring the other.

**Worked example (the origin incident)**:

A 2026-04-23 v12 execution handoff prescribed probing 4 candidates including swift-property-primitives' `Property.View.Typed.base @_lifetime(borrow self) removal`. The same handoff's Do Not Touch listed swift-property-primitives entirely. The fresh subordinate correctly skipped candidate (3) per Do-Not-Touch, but the unrun probe became invisible to the report — handoff defect masked as scope discipline. Correct disposition: surface the contradiction, request the user/principal to resolve (either include swift-property-primitives in scope or remove the probe candidate).

**Provenance**: Reflection `2026-04-23-v12-execution-supervisor-cycle-and-ownership-release-handoff.md` (sixth axis to [HANDOFF-016]).

---

## §[HANDOFF-038] HANDOFF Staleness Threshold

**Rationale**: `[REFL-009]`'s bounded-cleanup-authority clause was added to prevent over-deletion (provenance: 2026-04-16 reflection). Its inverse failure mode — *under-deletion*, where every session declines to triage anything it didn't author — became dominant by 2026-04-30: 26 `HANDOFF-*.md` files accumulated at `/Users/coen/Developer/` despite the rule firing in every recent /reflect-session. The orphan zone forms because most files fail bounded-authority's three-clause test (wrote / actively worked / encountered completion signals) for most sessions. A staleness-threshold override gives some authorized party a path to triage the orphan zone without re-introducing the over-deletion failure mode: the threshold applies only to files whose authoring session is verifiably long gone.

**Compose with `[META-001]` / `[META-022]`**: this rule is the handoff analog of `[META-001]` (research staleness) and `[META-022]` (experiment staleness). The shorter threshold (14 days vs 21) reflects handoffs' more ephemeral nature — a handoff is task-context, not durable rationale; its useful lifetime is shorter than a research document's.

**Provenance**: `swift-institute/Research/handoff-lifecycle-and-retention.md` v1.0.0 (2026-04-30, RECOMMENDATION). The Q1 hypothesis-2 verdict (bounded-cleanup-authority orphan zone, CONFIRMED) is the empirical foundation; the Q3 recommendation composition B+F is implemented by this rule plus `[HANDOFF-039]` plus the `[REFL-009]` amendment.

---

## §[HANDOFF-039] Predecessor Retirement at Dispatch

**Worked example (correct)**:

The Apr-29 bulk-triage cycle's framework was a one-time response to accumulation. With `[HANDOFF-039]` in place, the Path X `HANDOFF-l1-kernel-primitives-removal-plan.md` (RECOMMENDATION) → `HANDOFF-path-x-bucket-b.md` / `bucket-c.md` / `completion.md` (execution) dispatch would have included:

```markdown
## Predecessors Retired
HANDOFF-cascade-cycle-a-execution.md — Annotated-superseded (Cascade pivoted to Path X 2026-04-27)
HANDOFF-l2-cascade-recommendation.md — Annotated-superseded (Cascade Research doc reached RECOMMENDATION; cascade itself superseded by Path X)
HANDOFF-l1-types-only-no-exceptions.md — Deleted (RECOMMENDATION landed; subsumed by Path X)
HANDOFF-kernel-primitives-phase-3.md — Annotated-superseded (Path X deletes kernel-primitives entirely; Phase 3 refactor subsumed)
```

The retroactive triage in the Apr-30 cycle is the work `[HANDOFF-039]` would have prevented if it had existed at dispatch time.

**Worked example (defect)**:

Without `[HANDOFF-039]`, a session that writes a successor HANDOFF leaves predecessors in place silently. The executor reads the successor and works from it; the predecessors persist at workspace root, eventually accumulating to the point that bulk-triage is needed. Each predecessor's authoring session is gone; each subsequent session classifies them as out-of-authority per `[REFL-009]`. The orphan zone grows.

**Why dispatcher, not executor**: the dispatcher has full context on the successor relationship — what work is being subsumed, what is being deferred, which prior handoff's RECOMMENDATION is being executed. The executor learns this only by reading the successor's body, which may not enumerate every predecessor explicitly. Authoring the retirement at dispatch time is strictly cheaper than re-deriving it at executor time, and the dispatcher's enumeration is authoritative.

**Compose with `[HANDOFF-013a]` / `[HANDOFF-021]` / `[HANDOFF-032]`**: this rule extends the writer-side discipline pattern to predecessor retirement. `[HANDOFF-013a]` is writer-side prior-research grep (avoid prescribing already-decided shapes); `[HANDOFF-021]` is writer-side scope enumeration; `[HANDOFF-032]` is writer-side extraction-time material check. `[HANDOFF-039]` (this rule) is writer-side predecessor retirement. All four close gaps where deferring discipline to the executor produces silent accumulation or duplication.

**Rationale**: The orphan-zone formation analyzed in `swift-institute/Research/handoff-lifecycle-and-retention.md` (Q1 hypotheses 3 and 4) shows that handoffs whose investigation is closed (explicit RECOMMENDATION landed; successor exists) do not auto-transition to archive. No rule defines who triggers the transition. `[HANDOFF-039]` assigns the trigger to the dispatcher of the successor — the party who has the cheapest access to the supersession context. Composition with `[HANDOFF-038]` (cadence-based stale-override) covers the residual case where no successor exists.

**Provenance**: `swift-institute/Research/handoff-lifecycle-and-retention.md` v1.0.0 (2026-04-30, RECOMMENDATION). The Q3 recommendation composition B+F is implemented by `[HANDOFF-038]` plus this rule plus the `[REFL-009]` amendment.

---

## §[HANDOFF-040] Generic-Instantiated Forms in Cascade-Migration Grep Patterns

**Worked example (the origin incident)**:

The 2026-05-05 Property family rename cascade (`Property.View → Property.Inout`, etc.) used a literal-only enumeration grep at handoff write time:

```bash
grep -rln "Property\.View\|Property\.Consuming\|Property_View_Primitives\|..."
```

This produced a 25-package scope. `swift-slab-primitives` returned zero literal matches and was NOT in the scope. During execution, the subordinate caught a build failure in slab-primitives caused by `Property<X, Y>.View(...)` references — generic-instantiated forms invisible to the literal grep. Slab-primitives was migrated and committed mid-cascade, raising the actual scope to 26 packages. The lesson: had the subordinate skipped the build verification, the cascade would have attested as complete with slab-primitives' generic-instantiated references silently broken on origin/main.

**Worked example (the character-class axis, 2026-06-04)**: an MSB W3 gate-grep for old-form `Buffer<X>.D` spellings carried an inner character class without `0-9` — every digit-bearing spelling (`Tree<Int>.N<2>.Node`, `UInt8`) was invisible to EVERY prior sweep that used the pattern. A digit-inclusive re-sweep across all mains then surfaced live code sites in one package (fixed pre-merge) and doc residuals in three others, after the gate had repeatedly fired EMPTY. The audit-time counterpart is [AUDIT-036] (width-check the gate-grep against its criterion before declaring EMPTY).

**Rationale**: Generic-instantiated forms are the dominant call-site shape for type-family wrappers, exactly the kind of types that motivate cascade migrations. A literal-only grep is mechanically reproducible (good per [HANDOFF-021]) but pattern-incomplete by construction. The fix is one extra regex at write-time, not a process change at execution-time. The cost asymmetry is decisive: the writer pays once; without the fix, every downstream reader pays via build-time discovery — or worse, post-attestation discovery in production.

**Provenance**: 2026-05-05 Phase 5 Property family rename cascade. Memory: `ecosystem_grep_generic_instantiations.md`. Slab-primitives near-miss documented in the v1.3.0 entry of `swift-institute/Research/nested-view-vs-borrowed-naming.md`. Character-class axis: Reflection `2026-06-04-msb-capability-tower-w3-endgame.md` (the G5 digit gap).

---

## §[HANDOFF-041] Acceptance-Criterion Grep Anchoring

**Worked example (the origin incident)**:

A 2026-05-07 D1' branching dispatch had Acceptance Criterion 2 phrased as "README contains no `## Single-file Lint.swift form` section" with verification `grep -c "Single-file" README.md → 0`. The verification was substring-anchored; the literal substring "Single-file" remained in the README's `## Two consumer shapes` section (item #2 honestly flagging the form as inert), which the subordinate deliberately preserved per the handoff's `ask:` ground rule. Resolved by surfacing as a Deviation in Implementation Notes — but the right fix was at handoff-write time: `grep -c "^## Single-file" README.md → 0` (heading-anchored) would have matched the criterion's prose intent without colliding with the carved-out exception.

**Worked example (the scope axis, 2026-06-04)**: an MSB W3 gate criterion read "no old-form spellings in code AND docs/comments"; the command was `grep --include="*.swift"` over `Sources/`. It fired EMPTY while six real residuals existed — four in `.docc` examples, one in a test comment, one in LIVE CODE additionally masked by an external-exception build hole. The canonical-width re-run (Sources+Tests, no include filter, `.docc`/`.md` included) found all six; the widened command was then recorded next to the gate as its canonical form.

**Rationale**: Acceptance Criterion verification is a discrete pass/fail gate at termination time per [SUPER-009]. A regex that doesn't match the criterion's prose intent forces every downstream subordinate to either (a) deviate and surface the gap, or (b) silently apply broader-than-intended changes to make the regex zero-match. Either outcome is a defect. The 30-second tightening at handoff-write time prevents both. Parallels [HANDOFF-031] (regex syntactic-vs-semantic disclaimer for scope enumeration) extended to the acceptance-criterion verification surface.

**Provenance**: Reflection `2026-05-07-d1-readme-and-driver-repair.md` (Criterion 2 substring/heading-anchor collision with `ask:` carve-out). Scope-width axis: Reflection `2026-06-04-msb-capability-tower-w3-endgame.md` (the G5 scope miss).

---

## §[HANDOFF-042] Pre-Existing Code in Scope Existence Verification

**Worked example (the origin incident)**:

A 2026-05-07 pre-publishable-polish handoff's `## Pre-Existing Code in Scope` table included `swift-foundations/swift-linter/Research/_index.json — Updated`. The "Updated" label presumed the file existed. The file did not exist (a pre-existing `[RES-003c]` gap). Mid-execution, the subordinate discovered the absence and bundled `_index.json` creation into the same commit as the new research-doc landing. The bundling was correct under continuation pressure but degraded the dispatch's per-item commit hierarchy. A `ls swift-foundations/swift-linter/Research/_index.json` at handoff-write time would have caught the absence; the writer would have re-labeled the row as `Created in this dispatch` and the bundling would have been intentional, not accidental.

**Rationale**: Generalizes [RES-023] (Empirical-Claim Verification for Dependent-Package State) to the handoff-authoring pre-write checklist. A `Pre-Existing Code in Scope` row IS an empirical claim about live state; the writer has near-zero-cost access to verify it via `ls` or equivalent. The downstream cost of an unverified claim — scope-creep at execution time, escalation round-trips, or silent absorption that erodes the per-item commit discipline — exceeds the verification cost by orders of magnitude.

**Provenance**: Reflection `2026-05-07-pre-publishable-polish-stream-2.md` (Item 3 `_index.json` row claimed Updated; file did not exist; bundled-creation patched the gap).

---

## §[HANDOFF-043] Multi-Cohort Orchestration Pattern

**Worked example (the origin incident)**:

The 2026-05-06 → 2026-05-07 swift-linter ecosystem 2-day sprint shipped 3 sequential cohorts (modularization → architecture → code-surface cleanup) plus 3 parallel Day-3 streams. 30+ commits across 8 repos with the R5 = 27-hit invariant on swift-tagged-primitives preserved end-to-end across 8+ verification gates. Each cohort had its own dispatching handoff, its own carry-forwards table, its own per-phase sign-off rhythm. Architecture pivots discovered mid-cohort (rules-as-first-class-plugin-packages, Lint/ nested-package shape) were captured in the modularization-cohort's terminal stamp and executed in the successor architecture cohort. The 4-of-5 README-non-compile pre-publishable defect surfaced in the inventory dispatch is the systemic gap codified separately at [RELEASE-007].

**Rationale**: Multi-cohort sequences fail catastrophically under monolithic-dispatch shapes — a 30+ commit single-handoff burns through context, loses verification traceability, and cannot accommodate mid-flight architecture pivots without rework. The pattern decomposes the work into bounded units each verifiable on its own terms, while the carry-forwards table preserves the orchestration thread across cohort boundaries. The R5-style invariant is the load-bearing structural gate that makes the pattern tractable; without a cheap deterministic check, per-phase sign-off latency dominates.

**Provenance**: Reflection `2026-05-07-supervisor-seat-swift-linter-cohort-orchestration.md` + `2026-05-07-swift-linter-modularization-cohort-completion.md` (modularization cohort) + `2026-05-07-swift-linter-architecture-cohort-execution.md` (architecture cohort) + `2026-05-07-swift-linter-code-surface-cleanup-cohort-and-mirror-config-unblock.md` (code-surface cleanup cohort).

---

## §[HANDOFF-045] Stale-Acceptance-Criterion in Re-Issued Briefs

**Rationale**: Re-issued briefs are written under context-loading pressure and tend to inherit literal text from prior templates. When the prior batch executed part of the work, the literal text becomes stale. Without this rule, the subordinate's natural disposition is to execute the brief literally — including destructive operations to "achieve" stale criteria. The cost asymmetry is severe: the cost of undoing real progress is days; the cost of surfacing the discrepancy is seconds.

**Provenance**: Reflection `2026-05-06-cross-ecosystem-ci-wrapper-rollout-org-hierarchy-mirror-and-d4-finalization.md` (L3 profile/README.md acceptance-criterion conflict).

---

## §[HANDOFF-046] Proactive Read-Before-Copy Content-Judgment Stop-Condition

**Rationale**: README files, schema files, ecosystem-position-dependent prose are the most common scope-tied artifacts. A "copy this to that" instruction looks mechanical but is actually a delegation of content judgment. Without explicit pre-marking by the brief, the subordinate's mechanical disposition would propagate the wrong content; the proactive read-before-copy stop-condition catches it at the moment of detection.

**Provenance**: Reflection `2026-05-06-cross-ecosystem-ci-wrapper-rollout-org-hierarchy-mirror-and-d4-finalization.md` (proactive content-judgment stop-condition; L3 README adaptation deferred via Option 2).

---

## §[HANDOFF-047] Writer-Side Primary-Source Sampling for All Paraphrased Technical Detail

**Worked examples (the origin incidents)**:

| Defect | Origin | Cost |
|--------|--------|------|
| Test-count miscalculation 41 vs 48 | Cascade-tail-prune dispatch extrapolated from prior-dispatch summary; primary source had 48 | Subordinate's report-back contradicted prior summary; orchestrator caught |
| Warning-fix REMOVE/KEEP direction inversion | Same dispatch — paraphrased fix direction; primary source said the opposite | Mid-cycle pivot |
| Property.View renamed citation | Detour-orchestration brief cited `copypropagation-nonescapable-fix.md` (2026-03-25) without verifying live source; Property.View had been renamed to Property.Inout/Borrow + ~Escapable already restored | Detour authorized then pruned within 24h once primary-source verified |
| Memory-cited prescription | Three writer-side staleness defects in escapable-cohort arc — all cited memory entries without primary-source verification | Detour cycle that wouldn't have started had primary source been sampled at write time |

**Relationship to [HANDOFF-013a]**: [HANDOFF-013a] requires writer-side prior-research grep. [HANDOFF-047] (this rule) generalizes from research docs to ALL paraphrased technical detail (memory entries, command shapes, line numbers, diagnostic text). Both fire at the same boundary (dispatch-write time) but [HANDOFF-047] is the more-aggressive form.

**Rationale**: Prior-dispatch summaries become summaries-of-summaries-of-summaries as cascades extend; each layer adds paraphrase risk. Sampling primary source at every authoring boundary keeps the citation chain short. The cost is one grep / cat per cited value at write time; the cost of skipping is the cascade of staleness-induced rework.

**Provenance**: Reflections `2026-05-09-cascade-tail-prune-execution-and-doc-amendment.md` (test-count miscalculation + warning-fix direction inversion; both writer-side proposal-staleness); `2026-05-09-escapable-cohort-property-detour-orchestration.md` (memory-entry-cited prescription staleness); `2026-05-09-escapable-property-tier-prune-supervision-arc.md` (Pattern 2 — extends discipline to all paraphrased technical detail).

---

## §[HANDOFF-048] Writer-Side Destination-Inspection Before Recommending a Target

**Worked examples (the origin incidents, 2026-05-10)**:

| Recommendation | Pre-prescription inspection skipped | Cost |
|----------------|-------------------------------------|------|
| "algebra-law-primitives is the home for Bifunctor laws" | Did not read any existing law file; assumed naming aligned with home | Premise wrong; algebra-law-primitives does NOT host categorical-structure laws — it hosts value-level algebra laws (associativity, identity, etc.) |
| "Bifunctor protocol matches existing converged research" | Did not read existing converged research before prescribing | Recommendation contradicted the research's existing decision; required reframe |

**Relationship to [HANDOFF-013a]**: [HANDOFF-013a] requires writer-side prior-research grep for the source domain. [HANDOFF-048] (this rule) extends to the destination domain — when the dispatch identifies WHERE work goes, the writer MUST inspect the destination with the same rigor. Both are necessary; one without the other leaves a structural blind spot at the recommendation boundary.

**Rationale**: Naming-aligned recommendations look authoritative because they read as if grounded in domain knowledge ("of course X belongs in Y, the names match"). When the names align but the actual content doesn't, the recommendation is a confident wrong answer. The inspection cost is one read per recommendation; the cost of skipping is recommendation-cycle rework when the destination's actual mission contradicts the prescription.

**Provenance**: Reflection `2026-05-10-bifunctor-home-framework-without-inspection.md` (twice-caught framework-without-inspection in same session: algebra-law-primitives premise wrong; Bifunctor-protocol-prescription against existing converged research).

---

## §[HANDOFF-044] Branch Prescriptions Are Advisory; Verify Live Repo State First

**Why**: branching when `main` is already the working branch creates two parallel histories that have to be merged later, often with conflicts that the handoff did not anticipate. The handoff was written before the live state was known; the live state takes precedence.

**Provenance**: 2026-04-15 polling-error-handling work — recipient proposed `git checkout -b polling-error-result` in both swift-foundations sub-repos per the handoff's `Branch:` section. User pushback: "why checkout?" — both repos were already ahead of origin on main; pre-existing uncommitted work had just been committed on main. The topic branch would have added friction without value.

---

## §[HANDOFF-050] Workspace-Wide Grep on Protocol API Changes

**Why**: Protocol API changes are cascade-shaped by definition (every conformance is a downstream coupling). Missing the workspace-wide grep means the cascade discovers consumers at build time, where the cost is high (broken builds across sibling repos) and the recovery is expensive (mid-cascade pivot or post-attestation fix-up). The grep is seconds; the recovery is hours-to-days.

**Provenance**: memory `feedback_cross_package_api_sweep.md` (recurring failure: protocol API changes that missed transitive consumers in sibling org-mirrors).

---

## Changelog-Provenance (Dated Amendment History)

Evicted verbatim from the SKILL.md frontmatter comment block (2026-06-04 state; entries after that
date live in git history of `Skills/handoff/SKILL.md`, which remains the authoritative record).
Every normative clause carried by these entries was verified present in the owning rule's body at
eviction time (2026-07-02); no clause was hoisted. Ordered as they appeared in the frontmatter.

- **2026-06-04**: [HANDOFF-040] amended with the character-class⊇value-domain axis (a class without `0-9` hides every digit-bearing spelling — the G5 digit gap: `Tree<Int>.N<2>.Node`/`UInt8` invisible to every prior sweep) + [HANDOFF-041] amended with the scope-width dual axis (under-inclusive file-set vs criterion text — `--include="*.swift"` over Sources/ cannot verify a "code AND docs/comments" criterion; six hidden residuals). Both clarifying-additive per [SKILL-LIFE-003]; audit-time counterpart [AUDIT-036]. Provenance: Reflections/2026-06-04-msb-capability-tower-w3-endgame.md.

- **2026-05-14**: [HANDOFF-035] amended with Package.swift declarations in the cascade-termination grep. The workspace-wide grep MUST include `.product(name:` references in consumer Package.swifts, not just Sources/Tests. Stale product references can survive a Sources-only grep and surface as build failures only when the consumer tries to resolve dependencies. Provenance: W4 (Coder/Serializer arc) 2026-05-14 — swift-incits-4-1986/Package.swift still referenced the removed `Serialization Primitives` product; T1 fixed it (commit `2450569` on swift-incits-4-1986). Clarifying per [SKILL-LIFE-003] (procedure extension, no statement change).

- **2026-05-10**: Cluster G reflection-processing — added [HANDOFF-049] stash-edit-commit-pop pattern for cross-session contamination; amended [HANDOFF-010] step 5 to generalize stamp-location to branching handoffs. Reflections/2026-05-05-skill-verification-taxonomy-tier-2-tier-3-and-ecosystem-closure.md and 2026-05-05-skill-verification-taxonomy-tier-1-extension-and-parallel-subagent-dispatch.md.

- **2026-05-10**: Cluster E reflection-processing — [HANDOFF-039] amended with topic-matched parallel-session sibling disposition (search-before-write preamble for /handoff invocation when a different session has authored HANDOFF-{topic}.md for the same task). Reflections/2026-05-05-property-cascade-closeout-tagged-surface-drift-and-sli-ergonomics.md.

- **2026-05-10**: [HANDOFF-048] Writer-Side Destination-Inspection Before Recommending a Target added per Reflections/2026-05-10-bifunctor-home-framework-without-inspection.md (Cluster L)

- **2026-05-10**: [HANDOFF-047] Writer-Side Primary-Source Sampling for All Paraphrased Technical Detail added per Reflections/{2026-05-09-cascade-tail-prune-execution-and-doc-amendment, 2026-05-09-escapable-cohort-property-detour-orchestration, 2026-05-09-escapable-property-tier-prune-supervision-arc}.md (Cluster J)

- **2026-05-10**: [HANDOFF-045] Stale-Acceptance-Criterion in Re-Issued Briefs + [HANDOFF-046] Proactive Read-Before-Copy Content-Judgment Stop-Condition added per Reflections/2026-05-06-cross-ecosystem-ci-wrapper-rollout-org-hierarchy-mirror-and-d4-finalization.md (Cluster F consolidation)

- **2026-05-10**: [HANDOFF-040] amended with form-position variants in conformance lists per Reflections/2026-05-08-two-l1-layer-reversals-system-and-iso.md (Cluster A)

- **2026-05-10**: [HANDOFF-007] Program-shape exception added per Reflections/2026-04-30-phase-1b-stale-triage-and-deferred-fixed-codification.md

---

## §D1 Eviction Pass 2026-07-05

Non-normative content evicted from `Skills/handoff/SKILL.md` to clear the skill-size gate (baseline 1496). One-line pointers remain in-skill.

### §[HANDOFF-013] Prior Research Check — Example (correct) (evicted 2026-07-05)

**Example (correct)**:
```
Step 1: Read HANDOFF-public-api-review.md
Step 2: ls Research/ — discover Research/tier-0-consumer-api-review.md
Step 3: Read the prior doc; it addresses half the questions in the brief
Step 4: Cite it and extend rather than draft parallel spec
```

### §[HANDOFF-016] Treat Handoffs as Inputs — Example (correct) (evicted 2026-07-05)

**Example (correct)**:
```
Handoff says: "Branch: polling-error-result in both repos"
Agent checks: main in swift-executors is 16 commits ahead of origin;
              user has been using main as working branch
Agent surfaces: "The handoff prescribes a topic branch, but main is
                already the working branch. Shall I continue on main?"
User confirms: "why checkout?"
Agent proceeds on main.
```

### §[HANDOFF-018] Intent-Reading of Opt-Outs — Example (defect) (evicted 2026-07-05)

**Example (defect)**: A handoff's Tests section read *"If no precedent tests exist, that's acceptable — note in the commit message."* The implementer read literally (no file named `Kernel.Error.Code Tests.swift` existed → take the opt-out). The reviewer's remembered intent: the opt-out covered *unusual test patterns* (e.g., wrappers over compiler-intrinsic types), not *first-of-kind coverage for 2-line mapping functions*. For mechanical 2-line wrappers, tests are cheapest and pin mapping against drift — the opt-out never fires.

### §[HANDOFF-013a] Writer-Side Grep — Example (defect) (evicted 2026-07-05)

**Example (defect)**: A handoff prescribing `Kernel.File.System.Name` as a new typed value at L1 to hide raw bytes, written without consulting `swift-institute/Research/string-type-ecosystem-model.md §D1`, which bans fourth parallel owning string types. The receiver grepped, caught the violation, and forced rework. The writer-side grep would have prevented the wrong-direction handoff at near-zero cost.

### §[HANDOFF-026] Preserved-Label Verification — Example (defect) (evicted 2026-07-05)

**Example (defect)**: A handoff listing `Driver.swift` as Preserved while simultaneously scheduling `IO.Completion` type relocation. `Driver.swift` imports and references `IO.Completion`; the Preserved label is false. The subordinate's state-verification on resume caught the layer-violation; the handoff required amendment mid-execution.

### §[HANDOFF-027] Refuted-Pattern Shape Comparison — Example (defect) (evicted 2026-07-05)

**Example (defect)**: A Phase-3 Next Steps prescribed `Outgoing<V>.Retained<T>` as an ownership shape. The handoff's Dead Ends enumerated a refuted `Box<V>.Unique<U>` pattern with the same double-tagged outer/inner structure. The prescription re-derived the refuted class under new names; execution discovery forced an escalation round-trip.

### §[HANDOFF-049] Commit-First — Comparison Prose + Reversal Note (evicted 2026-07-05)

Commit-first preserves session-attribution clarity (each commit contains one session's edits) without `git add -p` interactivity, risky JSON manipulation, or a stateful stash. It is strictly more reliable than the former stash-edit-commit-pop pattern: `git stash pop` produces merge conflicts when the prior WIP and this session's edits touch adjacent lines that git treats as one hunk, and the pop can silently drop work into the stash on failure. Committing the prior WIP first eliminates the conflict-resolution overhead entirely — this session then edits from a clean tree.

**Reversal note**: this rule previously prescribed `git stash push -- <file>` → edit → commit → `git stash pop`. That is now forbidden — the principal banned `git stash` outright ("do not stash, period"). This ID and its original problem statement (partial commit to a shared `_index.json`/`MEMORY.md` under prior-session WIP) are preserved; only the mechanism reversed. Rationale: *principal directive supersedes*.

**Rationale**: committing the prior WIP first isolates cross-session contamination so each commit carries one session's edits alone, without the stateful-stash failure modes (adjacent-hunk conflicts on `pop`, silent work-drop).

### §[HANDOFF-052] Closure Verification Commit-Landed Evidence — Rationale (evicted 2026-07-05)

**Rationale**: working-tree verification confirms content, not commitment. A session can leave working-tree-only artifacts (untracked files, unstaged edits) that the next subordinate has to reconcile. Composing `git log -1` + clean `git status` into the closure gate moves the check from "the file looks right" to "the file landed."
