---
date: 2026-06-02
session_objective: Execute the derive-for-free capability-composition Tier-3 research dispatch and serve as verify-and-adjudicate co-architect for its /goal-driven implementation
packages:
  - swift-storage-primitives
  - swift-buffer-primitives
  - swift-buffer-aligned-primitives
  - swift-buffer-unbounded-primitives
  - swift-buffer-slots-primitives
status: pending
---

# Derive-for-free via capability composition — and four verification misses that shared one root: checking a *model* of the ground truth instead of the ground truth

## What Happened

Two intertwined tracks across the session:

- **Track A (research)**: `/research-process` Tier-3 → produced `derive-for-free-capability-composition.md` (v1.0.0 → v1.4.0, committed `506ed08`; verified at Research HEAD this turn). Established the capability-protocol normal form (REQUIRES minimal primitives → PROVIDES derivations), the four-part warranted-refinement test (C1 identity / C2 conformer-set / C3 expressibility / C4 cross-package mechanics — refine only if ALL pass), the single sanctioned refinement edge in the whole model (`Collection.Protocol: Iterable`), and the specialization boundary (0 `witness_method` cross-module → compose-vs-refine is *free* → decided on semantics, not perf).

- **Track B (co-architect / verify-and-adjudicate)**: validated an executor's `/goal`-driven implementation against the principal's standing instruction "don't speculate and trust, but verify." Storage.Protocol de-pointer landed + merged (now `capacity` + `subscript{get set}` + `initialize/move` + Span, no `pointer(at:)` — verified on disk). Gaps J/K/L/A/M landed; N WONTFIX-as-posed (capacity-fold into Buffer.Protocol is vacuous for Buffer.Aligned/Unbounded where `count ≡ capacity`); O investigated + green-lit (relocate Aligned/Unbounded → Memory, Slots → Storage.Split; Linear/Ring/Slab/Arena/Linked stay; blast radius 0/1/1). Closed by writing a topic-named GAP-O handoff rather than overwriting a live parallel publication `HANDOFF.md`.

**Four of my own claims were wrong and caught** (three by re-verification, one by the executor):
1. **SKILL.md "phantom"**: measured the modularization description via YAML content-load (245 chars) and declared the report's "251-char sync blocker" a phantom. The *operative gate* `check-skill-descriptions.sh` runs `wc -c` on the awk-extracted block **including the 2-space YAML indent + newlines** → 251 > 250 ceiling → sync aborts. The blocker was real; the executor's trim (`4d29656`) fixed it; I owned the miss in the doc's v1.4.0 changelog.
2. **"Binary.Cursor uses Unbounded"** — propagated from a doc-comment citation; refuted on grep (Buffer.Unbounded has 0 concrete dependents).
3. **"24× isFull dedup"** — overstated; only Ring/Linear share `isFull = count==capacity`; Arena/Linked/Slab override with domain-specific fullness.
4. **"Deque/Queue.DoubleEnded doesn't exist"** — it does (`swift-deque-primitives`); fixed by grep, which sharpened §7's Array-vs-Deque contiguity contrast.

**HANDOFF triage ([REFL-009])**: `.handoffs/` scanned — 31 files. **In authority: 1** — `HANDOFF-derive-for-free-gap-o-relocation.md` (authored this session; Next Steps not yet executed → annotated-and-left). **Case-(c) verified-complete but conservatively left: 1** — `HANDOFF-storage-protocol-p6-depointer.md` (I verified the De-Pointer arc complete+merged on disk, but it is not-mine, recent, and cited by my new handoff → left, no annotation, per [REFL-009a] in-flight conservativism + no-interference). **Out of authority: 29** (incl. the live parallel publication `HANDOFF.md` — different lineage, recent mtime, real unfinished Next Steps → left untouched). 0 deleted.

## What Worked and What Didn't

**Worked:**
- The verify-don't-trust posture caught 3 of my own 4 misses before they reached the user or hardened in the doc; the framework doc's correctness improved on each pass.
- Surface-and-STOP held on the class-(c) GAP-O ecosystem question — I green-lit the relocation but did not auto-dispatch the architectural program ([feedback_class_c_ecosystem_stop_not_dispatch]).
- Proactive handoff-collision detection: recognized the canonical `HANDOFF.md` slot was held by a *live, unrelated, parallel* arc and chose topic-naming the newcomer over [HANDOFF-009]'s rename-and-displace; the user's "dont overwrite the existing handoff.md" confirmed the call.

**Didn't:**
- Four verification misses in one session. The *instinct* to verify was present every time; the *execution* of verification was wrong — I checked a reconstruction of the ground truth rather than the ground truth itself.
- The SKILL.md miss is the worst of the four: I had been explicitly told to verify, I *ran a check*, and the check still declared a real blocker a phantom. False confidence from a wrong check is worse than no check — it launders a wrong claim as a verified one.

## Patterns and Root Causes

All four misses share one root: **verifying a derived predicate by reconstructing the predicate, instead of running the actual evaluator against the actual inputs.**

| Miss | Predicate being verified | Operative evaluator (correct) | What I ran instead (proxy) |
|------|--------------------------|-------------------------------|----------------------------|
| SKILL.md | "Does the sync gate abort?" | `check-skill-descriptions.sh` = `wc -c` on the awk block, formatting included | YAML-load the description + `len()` of the content (dropped indent+newlines) |
| Binary.Cursor | "Does anything concrete depend on Unbounded?" | `grep` the dependent set → 0 | trusted a doc-comment's *claim* of usage |
| 24× dedup | "How many conformers share this derivation?" | enumerate the conformer set, check each | extrapolated from a couple |
| Deque | "Does this type exist?" | `grep` the symbol | trusted memory |

The deeper lesson: **"verify, don't trust" is necessary but not sufficient.** The failure mode that survives it is *verifying-the-wrong-thing* — running a check that *feels* like the check but measures a proxy. The fix is mechanical and domain-general: name the operative evaluator (the gate script, the dependency graph, the conformer set, the symbol table) and run *it* against the real inputs; never substitute a reconstruction of what you believe the evaluator computes. This is precisely why the principal's "verify" had to be paid four times — the first three corrections fixed *instances*; only naming the root (proxy-vs-operative-evaluator) generalizes.

This unifies a cluster already in my memory under per-domain framings — [feedback_check_package_resolved_before_compiler_bug_claim] (check Package.resolved, not assume), [feedback_verify_before_no_op_proposals], [feedback_convention_vs_typesystem_constraint] (probe with swiftc, don't assert impossibility). Each is the same meta-pattern wearing a different domain hat. The operative-evaluator abstraction is the unifying form, and per the CLAUDE.md memory-write guardrail it belongs as a first-class clause in [RES-023], not as yet another per-domain memory entry that displaces an index slot.

**Second pattern (process, lower-stakes)**: [HANDOFF-009]'s unrelated-prior-task collision branch prescribes rename-and-displace the incumbent `HANDOFF.md`. Its origin case was a *22-day-stale* incumbent — but the rule's text doesn't discriminate a stale incumbent from a *live-parallel-arc* incumbent (recent mtime + real unfinished Next Steps + different lineage). For the live case, renaming the incumbent breaks a parallel session's resume path; topic-naming the *newcomer* is the correct, non-interfering disposition. The rule needs an explicit liveness discriminator.

## Action Items

- [ ] **[skill] research-process**: extend `[RES-023]` with the *operative-evaluator* clause — when verifying whether a gate passes / a dependent set is empty / a conformer set shares a derivation / a symbol exists, run the operative evaluator (the gate script as the gate runs it; grep the dep graph; enumerate the conformer set; grep the symbol table) against real inputs. Never substitute a content-proxy or a reconstruction of what you believe the evaluator computes. Provenance: this session, the SKILL.md `wc -c`-includes-formatting miss + 3 siblings, paid 4×.
- [ ] **[skill] modularization**: add a `[MOD-*]` rule (positive sibling to `[MOD-027]`'s incompatibility framing and `[MOD-016]`'s per-file import discipline) — `@inlinable` / `@_alwaysEmitIntoClient` cross-module bodies MUST carry an explicit `public import` of every module whose symbols the body references; transitive re-export visibility is insufficient because the body is emitted into the consumer module (InternalImportsByDefault + MemberImportVisibility). `/reflections-processing` MUST reconcile against `[MOD-027]` (internal-vs-public access level of a present import) so the new rule states the distinct *transitive-insufficiency* property, not a restatement.
- [ ] **[skill] handoff**: refine `[HANDOFF-009]`'s collision branch with a liveness discriminator — if the incumbent `HANDOFF.md` is a *live parallel arc* (recent mtime + real unfinished Next Steps + different lineage), topic-name the *newcomer* and leave the incumbent untouched; reserve rename-and-displace for *stale/ended* incumbents. Provenance: this session (user: "dont overwrite the existing handoff.md"); the publication-arc incumbent was today-dated with open Next Steps.
