---
date: 2026-05-05
session_objective: Execute Track B Phase B-1 + B-2 — diagnostic-driven skill-quality refactor of composite-rule and reference-illustration findings from the verification-taxonomy classification sweep.
packages:
  - swift-institute/Skills
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: SkillUpdate
    target: skill-lifecycle/SKILL.md [SKILL-LIFE-028]
    description: Cluster G — new rule for ID-suffix scheme conflict-resolution policy when SPLIT lands on a rule whose natural sub-suffix is claimed. Resolution order: KEEP-with-Composite-annotation → renumber to next integer → topic split (rare). Hyphenated/dotted suffix forbidden. [EXP-004]/[EXP-004a] is the canonical worked example.
  - type: ResearchTopic
    target: Tier-3 Part 27 (illustration-pure) vs (illustration-supporting) sub-classification
    description: 9-of-10 SKIP rate empirically supports the distinction. Annotation-content vs annotation-prescription mismatch as the underlying pattern. Deferred to next taxonomy refresh — same-session annotation refinement would be premature without a 2nd refactor pass to confirm SKIP rate.
  - type: ResearchTopic
    target: EXP-004 / EXP-006 future-SPLIT readiness
    description: Deferred — KEEP-with-annotation captures structural distinction without breaking citations; SPLIT becomes warranted at CI-tooling time when independent workflows for build-verification (separate from reduction methodology) and revalidation-verdicts (separate from outcome documentation) materialize.
---

# Track B Phase B-1 + B-2 — diagnostic-driven skill-quality refactor execution

## What Happened

Session executed the dispatch in `HANDOFF-skills-quality-refactor-track-b.md`: a surgical, two-phase skill-text refactor against the verification-taxonomy diagnostic in `swift-institute/Research/skill-verification-taxonomy-extension-tier-3.md` Part 27. Two HIGH-materiality patterns were in scope — composite rules (~77 ecosystem-wide) and Reference (illustration) (~10 ecosystem-wide). MEDIUM/LOW patterns deliberately deferred.

**Phase B-1** (reference-skill validation): refactored `experiment-process` end-to-end. Identified 9 composite rules from tier-3 Part 8 (EXP-004, EXP-018, EXP-003e, EXP-006, EXP-006c, EXP-013, EXP-017, EXP-017a, EXP-020). For each, decided KEEP-with-`**Composite:**`-annotation rather than SPLIT — reasoning: cohesion-as-narrative + cross-reference preservation (74 citations to these IDs across the workspace) + ID-suffix scheme conflict (e.g., `[EXP-004a]` already taken for the unrelated "Incremental Construction Methodology"). Inserted 9 annotations + bumped `last_reviewed` to 2026-05-05 + verified diff (20 insertions, 1 deletion) + ran cross-reference grep (74 references all preserved by KEEP path). Committed as `d22479f`. No format issues warranted escalation.

**Phase B-2** (named-target expansion): proceeded after B-1 validated. Refactored 4 skills + 1 reference-illustration deletion across 5 commits:
- `5157558` supervise: 12 composite annotations (SUPER-006/009/010/011/012/014a/015/020/021/022/026/027).
- `3821f4e` reflections-processing: 6 composite annotations (REFL-PROC-002/004/005a/006/009/016).
- `d86b173` readme: 4 composite annotations across multi-file structure (SKILL.md hub + sub-package.md siblings README-004/008/021 + ci-automation.md sibling README-162). Bumped `last_reviewed` in all 3 frontmatters.
- `60ca239` research-process: 1 composite annotation (RES-020 2nd occurrence; the duplicate-ID is itself a corpus-health issue tracked separately).
- `cb43c3c` collaborative-discussion: 1 reference-illustration DELETE (COLLAB-012 — pure illustration, no enforceable predicate; cross-reference grep returned zero external citations).

**Reference-illustration cleanup** examined 10 candidates from tier-3. Per-rule examination found only COLLAB-012 fit the "pure illustration masquerading as rule" diagnostic. The other 9 (JUD-ENC-003, PROD-ENC-001, ISSUE-021, LEG-TEST-012, DOC-MARKUP-010/021/024, SWIFT-PR-002, SWIFT-TEST-013) each carry a real enforceable predicate with illustration as supporting material — not the diagnostic's target. Each SKIP documented per-rule with rationale.

**Track B results doc** committed as `a504c37`: `swift-institute/Research/skills-quality-refactor-track-b.md` (Status: RECOMMENDATION, 251 lines). Documents 32 composite annotations + 1 illustration deletion + 8 SKIPs + 2 `**ask:**` triggers handled inline (future-SPLIT candidates EXP-004 / EXP-006; reference-illustration sub-classification proposal `(illustration-pure)` vs `(illustration-supporting)`). Top-level `Research/_index.json` registration deferred — pre-existing cross-session contamination (entries for `workflow-construction-phase-1.md` + `wasm-ci-strategy-and-sdk-toolchain-coupling.md` from prior dispatches whose source files remain untracked) blocked clean staging; per the supervisor block's `MUST NOT stage cross-session contamination`, the registration entry should land in a follow-up commit when the contamination is resolved.

7 commits total, no remote pushed. Cross-session contamination in `Reflections/_index.json`, `_index.json`, untracked Reflections (8 files), `wasm-ci-strategy-and-sdk-toolchain-coupling.md`, `workflow-construction-phase-1.md`, and a `download-artifact-ladder-migration.md` working-tree mod (which surfaced during the session, not authored by this dispatch) — all preserved untouched.

HANDOFF scan: 1 file in this session's bounded cleanup authority (`HANDOFF-skills-quality-refactor-track-b.md` — actively worked, the dispatch brief itself); all items completed; all supervisor ground-rule entries verified per the Track B results doc's verification stamp; deleted at session end. The other ~40+ HANDOFF-*.md files at workspace root are out-of-authority — not touched, not annotated, left as the workspace-root orphan zone for `[HANDOFF-038]` lifecycle review in a future cycle.

## What Worked and What Didn't

**Worked**:

- **KEEP-with-annotation pattern** proved out cleanly across 32 rules in 5 skills. Markdown structure intact, annotations rendered consistently, no parser issues. The pattern's value-prop (per-mechanism CI viability visible without breaking narrative cohesion) held up under per-rule examination.

- **Cross-reference preservation budget** was zero across the dispatch — KEEP preserves every ID, so the 74 citations to experiment-process composite IDs alone (and the equivalent volume across other skills) didn't need any rewrite. The redirect-anchor pattern (heavy-machinery alternative) was avoided entirely.

- **Multi-file skill frontmatter-bump** discipline worked smoothly for readme. Three frontmatters (`SKILL.md`, `sub-package.md`, `ci-automation.md`) all bumped to 2026-05-05; per [SKILL-LIFE-004] the bump applies to every file edited under the multi-file skill structure.

- **Per-skill commit discipline** (one focused commit per refactored skill, brief filename in each commit message body) gave a clean audit trail. Six refactor commits + one results-doc commit, each independently revertable.

- **Cross-session contamination discipline** (preserved untouched per supervisor block) held throughout. Working tree modifications outside dispatch scope (Reflections/_index.json, top-level Research/_index.json with the wasm-ci + workflow-construction-phase-1 entries, untracked files, the surprise `download-artifact-ladder-migration.md` mod) all preserved; my staging was always per-file specific.

- **Auto Mode pacing** matched the dispatch's "stop-and-escalate-if-format-issues-surface" gate. Phase B-1 produced no format issues; proceeded to Phase B-2 without intermediate user check-in. The supervisor block's `**ask:**` triggers (composite-split ambiguity, reference-illustration reclassification) surfaced in the results doc as the brief specified — not as runtime escalations.

**Didn't work as anticipated**:

- **Reference-illustration cleanup pass yielded 1 of 10**, not 10 of 10. Only COLLAB-012 fit the "pure illustration masquerading as rule" diagnostic. The other 9 had real enforceable predicates with illustration as supporting material — a different shape than the brief's diagnostic targets. The brief listed them as targets expecting refactoring; per-rule examination revealed they don't need it. The `**ask:**` clause for "buried claim" reclassification was the right escape valve, but the pattern was 9-of-10 SKIP, not the 1-or-2 the clause anticipated.

- **`_index.json` registration step blocked** by pre-existing contamination. The supervisor block's `MUST NOT stage cross-session contamination` clause and [REFL-007]'s "MUST update the index" requirement collided. Resolution was to defer the registration to a follow-up commit; the results doc and reflection entry document the deferral. Not a defect — a known interaction between the brief's contamination-preservation rule and the standard skill-cycle requirements.

- **ID-suffix scheme conflict** for SPLIT candidates: `[EXP-004]` is the strongest SPLIT case (build-verification mechanically independent from reduction methodology) but `[EXP-004a]` is already taken for an unrelated sibling rule. Splitting would require either a hyphenated convention (`[EXP-004-a]`) or topic renumbering — both diverge from existing convention. KEEP-with-annotation sidestepped the constraint cleanly; future-SPLIT for this rule remains a deferred candidacy.

## Patterns and Root Causes

The 9-of-10 reference-illustration SKIP rate is the most material learning from this session. The diagnostic in tier-3 Part 27 classifies these IDs as Reference (illustration) based on the *content* (the rule body contains illustration). The brief's refactor targets the *defect* (ID wraps pure illustration with no enforceable claim). These are not the same thing. The classification is observationally inclusive: any rule with illustration content gets the (illustration) annotation. The defect is structurally narrow: only rules whose entire body is illustration with no predicate qualify for DELETE; rules with a predicate plus supporting illustration are healthy as-is.

The pattern this fits: **annotation-content vs annotation-prescription mismatch**. The taxonomy doc's `**Reference (illustration):**` annotation flags content shape; the refactor-pass treats it as a prescription for action. The mismatch produces false positives at the refactor stage. The fix isn't to refactor harder — it's to refine the annotation. The proposed sub-split `(illustration-pure)` (annotation = prescription, refactor target → DELETE) vs `(illustration-supporting)` (annotation = observation, refactor target → none) closes the gap. This generalizes a pattern likely present in other annotation-driven workflows: the annotation may flag a class of content, but only a subset of that class has the defect the workflow is supposed to fix.

A second pattern: **cohesion-as-narrative dominates SPLIT in voice/process skills**. Of 32 composite rules examined, zero had a clearly stronger SPLIT case than KEEP-with-annotation. Voice/process skills compose multiple sub-mechanisms into a single workflow / specification / policy / discipline whose value comes from the cohesion. The rule body is shaped to communicate the cohesion; SPLITting fragments the communication. This contrasts with a hypothetical code-shape composite (e.g., a rule that bundles "AST check A" + "AST check B" + "AST check C" with no narrative connecting them) where SPLIT is straightforward — independent checks deserve independent IDs. Voice/process composites rarely have that shape; their composites tend to be procedure-ordering or narrative-arc, not independent checks. The SPLIT path's heavy machinery (redirect-anchor + cross-reference rewrites + ID-suffix scheme) is justified only when the cohesion is absent.

A third pattern: **ID-suffix scheme conflict reveals a hidden constraint on SPLITs**. Existing skills use letter-suffix IDs (`[EXP-004]` / `[EXP-004a]`) as topic-extension, not as sub-rule. SPLITting `[EXP-004]` into sub-rules wants `[EXP-004a]` / `[EXP-004b]` — but those slots are claimed for other purposes. The redirect-anchor pattern from `[SKILL-LIFE-003]` addresses cross-reference preservation but does not address the naming question. A future-SPLIT dispatch will need a convention for sub-IDs when the natural slot is taken (hyphenated suffix? renumber and redirect? topic split?). This is not a Track B defect — Track B chose KEEP and didn't need to resolve it — but it's a constraint that should be named before any future Track B-2 SPLIT dispatch.

## Action Items

- [ ] **[research]** Tier-3 Part 27 sub-classification refinement: propose `(illustration-pure)` vs `(illustration-supporting)` sub-types for the Reference (illustration) annotation. The 9-of-10 SKIP rate empirically supports the distinction. If accepted, future refactor passes can target only `(illustration-pure)` and skip `(illustration-supporting)` mechanically; the SKIP rate drops to ~0%.

- [ ] **[skill]** skill-lifecycle: add a sub-rule documenting the ID-suffix scheme conflict-resolution policy when SPLIT lands on a rule whose natural sub-suffix (`[X-NNNa]`, `[X-NNNb]`) is already claimed for an unrelated topic. The redirect-anchor pattern from [SKILL-LIFE-003] handles cross-reference preservation; the new sub-rule would handle naming. Provenance: this dispatch's [EXP-004] future-split candidate analysis where `[EXP-004a]` was already taken for "Incremental Construction Methodology."

- [ ] **[research]** EXP-004 / EXP-006 future-SPLIT readiness: when independent CI workflows for build-verification (separate from reduction methodology) and revalidation-verdicts / FIXED-side-effects (separate from outcome documentation) materialize, exercise the SPLIT path as a Track B-2 dispatch. Current KEEP-with-annotation captures the structural distinction without breaking citations; future-SPLIT becomes warranted at CI-tooling time when independent workflows justify independent IDs.
