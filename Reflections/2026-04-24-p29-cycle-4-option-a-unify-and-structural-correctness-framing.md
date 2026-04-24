---
date: 2026-04-24
session_objective: Supervise post-Cycle-3 /audit dispatch; what began as a read-only compliance re-verification expanded into Cycle 4 remediation of P2.9 (Kernel.Signal.Information dual-declaration) via principal-redirected Option A unify
packages:
  - swift-iso-9945
  - swift-linux-standard
  - swift-institute/Audits
  - swift-institute/Research
status: pending
---

# P2.9 Cycle 4 Close — Option A Unify and "Structurally Correct vs Lowest-Risk" Framing

## What Happened

**Session arc**: principal supervision of a fresh `/audit` dispatch (AUDIT-post-cycle-3-fresh-pass.md) that turned into a full remediation cycle when the audit surfaced P2.9 as a HIGH-severity OPEN finding with a dispatch-ready Doc 4 at `swift-institute/Research/kernel-signal-information-dual-declaration-resolution.md`. Sub-agent produced Doc 4 with Option B (sibling-rename, "lowest-risk") as the default recommendation; principal redirected to Option A (unify) on structurally-correct-over-minimum-diff grounds.

**Cycle 4 four-commit graph** (P2.9 RESOLVED 2026-04-24):

| # | Phase | Repo | SHA | Subject |
|---|-------|------|-----|---------|
| 1 | Phase 1 | swift-iso/swift-iso-9945 | `6cdb3f7` | add `init()` + `Code` type to unified `Kernel.Signal.Information` |
| 2 | Phase 2 | swift-linux-foundation/swift-linux-standard | `565d9ac` | delete `Linux.Kernel.Signal.Information` + `.Code`; add `ISO_9945_Kernel_Signal` import in io_uring Prepare |
| 3 | Phase 4 (tracker) | swift-institute/Audits | `c0cbe87` | P2.9 RESOLVED; new D5 swift-linux MemberImportVisibility drift logged |
| 4 | Phase 4 (Doc 4) | swift-institute/Research | `a72c23d` | Doc 4 amendments: Phase 3 canary substitution + Supervision scope-relaxations record |

**Key events**:

1. **Doc 4 redirect**: principal message "we want the structurally correct solution, not the easy way out" overrode Doc 4's Option B recommendation. Doc 4's Cons of Option A were dismantled — #1 "merges two accessor styles" IS the fix not a con; #2 "coupling to P2.3 #3 `.fault → Memory.Address?` upgrade" is spurious (B has no `.fault` accessor, unifying doesn't touch it); #3 "async-signal-safety re-verification" is real but bounded-mechanical (cross-reference POSIX.1-2017 siginfo_t per si_code class). Doc 4 re-authored with Principal Decisions stamped + draft Option B preserved under strikethrough as investigation record.

2. **Phase 0.5 grep-only methodology failure**: grep for type references surfaced one consumer (io_uring waitid `UnsafeMutablePointer<Kernel.Signal.Information>` param). "Drop-all" disposition proceeded. Post Phase-2 deletion, build failed on `Linux Kernel IO Uring Standard` target — the consumer file did not `public import ISO_9945_Kernel_Signal`; B's deleted declaration had been providing accidental transitive visibility through `Linux_Kernel_System_Standard`. Subordinate correctly escalated per `ask:`; principal authorized one-line `public import ISO_9945_Kernel_Signal` addition.

3. **Substantive canary gate substitution**: Phase 3 terminal gate on Docker Linux swift-kernel `"Kernel File"` target failed — but not on P2.9-related ambiguity. Blocked by unrelated upstream drift in `swift-foundations/swift-linux/Sources/Linux Kernel Random/Linux.Random.swift:54` (missing `public import Kernel_Random_Primitives` under Swift 6.3 MemberImportVisibility). Principal-accepted Phase 2's Docker Linux `--build-tests` on swift-linux-standard (21.01s clean, both unified A + post-deletion linux-standard in scope together, zero ambiguity diagnostic) as substantive canary. New D5 drift observation logged for standalone swift-linux import-visibility sweep.

4. **Three principal-authorized ask:-based scope relaxations** recorded as `[SUPER-015]` observations: (i) io_uring 1-line `public import` addition (ground-rule #4 relaxed); (ii) `unsafe(self.cValue = siginfo_t())` expression-level wrap on new `init()` body per [MEM-SAFE-002] (ground-rule "non-@unsafe init declaration" clarified to mean attribute not body); (iii) substantive-canary gate substitution per Cycle 3 gate (b)/(d) precedent.

**HANDOFF scan (per [REFL-009])**: 4 files found at `/Users/coen/Developer/swift-institute/Audits/`:

- `HANDOFF-cycle-3-file-handle-writeall.md` — Cycle 3 SUCCESS-stamped (6/6 ground rules verified, 10/10 acceptance criteria verified, no pending escalation). Subject of this session's parent cleanup directive. → **DELETED**.
- `HANDOFF-layer-perfection-implementation.md` — three-cycle layer-perfection arc complete (Cycle 1 + 2 + 3 all SUCCESS-closed). Cycle 3 trigger annotated RESOLVED by parent session. No live work. → **DELETED**.
- `AUDIT-post-cycle-3-fresh-pass.md` — this session's own audit-dispatch brief. Findings landed at `platform-compliance-2026-04-21.md` in `c0cbe87`; Cycle 4 spawned from it closed SUCCESS in Phase 4. → **DELETED**.
- `HANDOFF-platform-audit-remediation.md` — self-annotated "STATUS 2026-04-22: STALE ... retained for historical context only" by prior author; not this session's authorship; explicit historical retention choice. → **LEFT (out-of-session-scope per bounded cleanup authority)**.

## What Worked and What Didn't

**What worked**:

- **Supervisor-in-chat + subordinate-in-fresh-chat pattern via user-mediated relay**: principal retained context continuity across Cycle 3 + Cycle 4 while each subordinate started fresh. User relay added manual overhead but the intervention-point discipline held cleanly. [SUPER-009] "read the artifact, not the summary" was honored at SUCCESS termination — principal verified 8/8 acceptance criteria against actual commit bodies + file contents, not subordinate attestation.
- **`ask:`-based scope relaxations with structural justification**: all three scope deviations (ground-rule #4 relaxation + `unsafe()` wrap + canary substitution) came via correct escalation, each with structural grounding in the `[SUPER-015]` commit-body record. Zero silent structural decisions observed.
- **Principal-override vs Doc recommendation + preserve draft under strikethrough**: Doc 4's Option B was preserved as investigation record rather than deleted, with the redirect paragraph prepended and framing-critique paragraph recorded. This pattern maintains provenance without leaving the document self-contradictory.
- **Phase 2 ambiguity-canary satisfies P2.9 structural claim**: Phase 2 Docker Linux `--build-tests` clean on swift-linux-standard proves "there is only one `Kernel.Signal.Information` declaration anywhere in scope together" — which IS the P2.9 resolution. The swift-kernel downstream gate would have added no P2.9-specific information given B is structurally gone. Substantive canary is semantically correct, not just precedent-justified.

**What didn't work, or needed correction**:

- **Doc 4's initial recommendation framed the optimization target as "lowest-risk diff"**, not "structurally correct shape". The draft's Cons of Option A were overstated (spurious P2.3 #3 coupling; "merges styles" was the fix not a con). Required explicit principal redirect. Symptom of a broader pattern: when a Doc authors multiple options, the default recommendation heuristic leans toward minimum churn even when the structural answer is clear.
- **Phase 0.5 grep-only methodology missed import-graph visibility**: the "drop-all" disposition derived from reference-count finding was technically sound but insufficient. Swift 6.3 `MemberImportVisibility` means a type reference in a public function signature requires an explicit `public import` of the defining module at the file level, not just type visibility via any transitive import chain. Pre-deletion, B's declaration masked the io_uring consumer's missing-import defect. Post-deletion surfaced it as a build failure. A proper "delete a public type" disposition audit must include an import-graph check, not just a reference-count check.
- **One ground-rule ambiguity surfaced mid-Phase-1**: "init() non-@unsafe" was interpreted by subordinate as covering both declaration-attribute AND body-expression levels when StrictMemorySafety flagged siginfo_t assignment. Body-expression `unsafe(...)` wrap is the correct per [MEM-SAFE-002] treatment; non-@unsafe attribute preserves caller-facing safety. The rule could have been clearer upfront.

**Confidence assessment**:

- HIGH confidence in the structural outcome (type-with-two-initializers unification is POSIX-correct per [PLAT-ARCH-007]; single canonical declaration eliminates the re-declaration class; no consumer migration needed).
- MEDIUM confidence pre-Phase-2 that drop-all would be clean — Phase 0.5 grep-derived zero-consumer finding was correct but import-visibility verification was not performed. Caught at Phase 2 build time (low cost; bounded fix) rather than left latent.
- LOW confidence in the swift-kernel "Kernel File" terminal gate reachability — D5 swift-linux Random drift blocks it on any cycle touching Linux code-paths until a dedicated sweep cycle lands. Substantive canary is a satisfactory interim substitution but future cycles want the full terminal gate back.

## Patterns and Root Causes

**Pattern 1: "Structurally correct vs lowest-risk" as a recurring Recommendation-section defect in investigation Docs.** Doc 4's framing treated "fewest moving parts" as the optimization target and loaded Option A's Cons with overstated or spurious items. This is not a one-off — the same framing skew would produce similar recommendations on any future Doc where the structural answer requires more coordinated edits than a sibling-rename. Doc 1 (Cycle 3) had the inverse discipline: it recommended Option 5 (method-level split, more coordinated) over the narrower do-nothing alternatives because the structural answer was clear. Doc 4's drift from that discipline suggests research-process skill guidance on Recommendation-section framing is worth explicit capture: when multiple options are compared, the default heuristic should be structural correctness (long-run shape) unless the user explicitly opts for velocity or the structural option is gated on unresolved ecosystem dependencies.

**Pattern 2: Grep-only reference audits miss Swift 6.3 MemberImportVisibility gaps.** The Phase 0.5 methodology was "find all references to the type, count consumers, decide disposition". That methodology is correct for pre-Swift-6.3 semantics. Under `MemberImportVisibility`, a reference-count of zero is necessary but not sufficient for "safe to delete a public type"; the file-level import graph at each reference site also matters. The Cycle 4 defect was latent because B's declaration in a transitively-imported module was shadowing the missing `public import ISO_9945_Kernel_Signal` at the io_uring consumer. This pattern will recur on any future "delete a public type" cycle under Swift 6.3 semantics. A supervise-skill rule (or an audit-skill rule) codifying "delete-public-type disposition requires import-graph verification in addition to reference-count zero" would close the gap mechanically.

**Pattern 3: Substantive-canary gate substitution — cross-cycle generalization.** Cycle 3 established the precedent: when a terminal gate is blocked by unrelated upstream drift, accept a tighter in-scope gate that proves the same structural property AND log the drift as a discrete OPEN finding. Cycle 3 gate (b) (Docker Linux swift-posix `--build-tests` clean) was accepted in lieu of gate (d) (Docker Linux swift-kernel `Kernel File` clean) when gate (d) was blocked by cross-cycle Signal.Information ambiguity — which became P2.9 itself. Cycle 4 Phase 3 repeated the pattern: Phase 2 substantive canary (Docker Linux swift-linux-standard `--build-tests` clean) accepted in lieu of full swift-kernel `Kernel File` terminal gate when terminal gate was blocked by unrelated D5 swift-linux Random MemberImportVisibility drift. The pattern generalizes: gate substitution is valid when (i) the substantive canary proves the structural claim being tested, (ii) the blocking drift is orthogonal to the cycle's scope, and (iii) the blocking drift is logged as a new finding. Codifying this as an audit-skill rule would save future cycles from re-deriving the framework each time.

**Pattern 4: Supervisor context continuity vs subordinate fresh-chat** — operationally stable via user-mediated relay. Across Cycle 3 (3 intervention points) + Cycle 4 (6 intervention points), the principal-in-chat + subordinate-in-fresh-chat with user-mediated relay proved robust: principal retained cumulative context (prior Option decisions, scope-lock facts, precedent patterns), subordinates started fresh each cycle (clean cache, no carryover bias, forced to re-read Doc + HANDOFF for [HANDOFF-010] verification). User relay latency adds manual overhead but prevented drift at every intervention point. This is the right pattern for future multi-cycle arcs: principal sessions last longer than subordinate sessions by design; user acts as the transport layer.

## Action Items

- [ ] **[skill]** supervise: Add a rule for "delete-public-type" disposition dispatches: reference-count-zero from a grep audit is necessary but not sufficient under Swift 6.3 `MemberImportVisibility`; import-graph verification at each consumer site MUST accompany the reference-count check before stamping drop-all. Reason: Phase 0.5 methodology was grep-only; caught the io_uring orphan only at build time. Provenance: Cycle 4 P2.9 Phase 2 build-time failure.

- [ ] **[skill]** research-process: Add a Recommendation-section framing rule — when an investigation Doc authors multiple options with trade-offs, the Recommendation section's default heuristic MUST prioritize structural correctness (long-run shape) over minimum-diff lowest-risk unless (a) the user has explicitly opted for velocity OR (b) the structural option is gated on unresolved ecosystem dependencies explicitly enumerated as current-state blockers. Reason: Doc 4's Option B recommendation required principal redirect on "structurally correct, not easy way out" grounds; Option A's draft Cons were overstated (spurious P2.3 #3 coupling + "merges styles"-as-con framing error). Provenance: Cycle 4 P2.9 Doc 4 framing critique, principal-recorded.

- [ ] **[skill]** audit: Codify "substantive canary" gate-substitution pattern — when a terminal gate is blocked by drift orthogonal to the cycle's scope, a tighter in-scope gate MAY be accepted as substantive canary IFF (i) it proves the structural claim being tested, (ii) the blocking drift is orthogonal to the cycle's finding class, and (iii) the blocking drift is logged as a discrete OPEN finding with evidence cite in the tracker. Reason: Cycle 3 gate (b)/(d) + Cycle 4 Phase 3 both re-derived the pattern from first principles; codification prevents future cycles from re-deriving it and standardizes the evidence-cite discipline. Provenance: 2026-04-24 Cycle 3 gate (b)/(d) accepted-in-lieu-of (d) pattern + Cycle 4 Phase 3 substantive-canary substitution.
