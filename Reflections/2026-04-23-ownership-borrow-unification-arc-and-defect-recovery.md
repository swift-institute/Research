---
date: 2026-04-23
session_objective: Unify the Viewable protocol with Ownership.Borrow<Value> and execute the rename cascade ecosystem-wide; recover cleanly from the mid-execution scope-coverage defect
packages:
  - swift-ownership-primitives
  - swift-identity-primitives
  - swift-string-primitives
  - swift-path-primitives
  - swift-kernel-primitives
  - swift-loader-primitives
  - swift-darwin-standard
  - swift-foundations/swift-strings
  - swift-foundations/swift-paths
  - swift-foundations/swift-kernel
  - swift-foundations/swift-posix
  - swift-foundations/swift-file-system
  - swift-microsoft/swift-windows-standard
  - swift-linux-foundation/swift-linux-standard
  - swift-iso/swift-iso-9945
status: pending
---

# Ownership.Borrow.`Protocol` unification arc and principal-audit defect recovery

## What Happened

Multi-day session (2026-04-22 → 2026-04-23) executing the Ownership.Borrow.`Protocol` unification end-to-end. Six substantive deliverables in sequence:

1. **Tagged `__unchecked:` inventory** (`swift-primitives/Research/tagged-unchecked-construction-inventory.md`, ANALYSIS, tier 2). Classified 952 call sites across the superrepo per the brief's five categories. Surfaced the Radian/Index no-invariant-phantom case: types where `__unchecked:` is the only construction path because there is no validation to bypass.

2. **Design-discussion arc** with the user establishing working constraints: no `*.Generic` suffix, no `-able` typealiases (gerund per [PKG-NAME-002]), language-semantics-first (`borrowing`/`consuming` over shadow types), pre-release so no backward-compat. The user pushed back twice on my framings — first when I proposed a `swift-borrow-primitives` standalone package, then on the §8.4 ~Escapable question.

3. **Experiment `ownership-borrow-protocol-unification`** — 10 variants on Swift 6.3.1 with `Lifetimes` + `SuppressedAssociatedTypes` feature flags. Established that direct protocol nesting inside a generic struct is prohibited (SE-0404), but the hoisted-protocol + nested-typealias pattern (V8) compiles, and the typealias resolves at conformance sites without requiring the generic parameter (V8_PathC). V10 confirmed Tagged parametric forwarding through the hoisted form.

4. **Research DECISION** (`swift-primitives/Research/ownership-borrow-protocol-unification.md`, tier 2, cross-package). Adopted V8 shape. Documented the generic↔associatedtype constraint-compatibility finding (protocol admits `~Escapable` Self ⇒ generic must admit `~Escapable` Value).

5. **Plan + supervised execution**. Subordinate drafted the implementation plan under principal supervision with 7 acceptance criteria and 6 ground-rules entries. Plan landed as v1.0.0 RECOMMENDATION. User authorized execution. Subordinate executed Phases 1–7 as 10 commits across 9 sub-repos:
   - `swift-ownership-primitives`: `b3eb11b` (hoisted protocol + widen Value) + `7eb00b6` (storage correction to `UnsafeRawPointer`)
   - `swift-identity-primitives`: `9ac9b04` (flag-day — Tagged conformance switched + Viewable deleted)
   - `swift-string-primitives`: `647e5bb`, `swift-path-primitives`: `4780d72`, `swift-kernel-primitives`: `e390b0e`, `swift-loader-primitives`: `11b3440`, `swift-darwin-standard`: `95350ef`, `swift-foundations/swift-strings`: `989b0a6`, `swift-foundations/swift-paths`: `0ecc4d2`
   - Mid-execution §8.4 escalation (protocol Self suppressions) resolved as Option A — keep DECISION widening; user corrected my Option-B recommendation.

6. **Principal audit found two material defects** after subordinate marked plan IMPLEMENTED at v1.2.0:
   - **Defect 1** — incomplete sweep: ~100 Sources + ~8 Tests sites across 6 additional packages (swift-iso-9945, swift-foundations/swift-kernel, swift-posix, swift-microsoft/swift-windows-standard, swift-foundations/swift-file-system, swift-linux-foundation/swift-linux-standard). Ecosystem build verified as BROKEN via `swift build` failures. Root cause split between plan author (me — grep scope limited to 3 top-level dirs) and subordinate (marked "all build green" based on isolated per-sub-repo builds).
   - **Defect 2** — v1.1.0 attribution conflated the Phase 2+6 flag-day collapse with my §8.1/§8.2 class-(b) rulings. The collapse was a separate scope change the subordinate made without escalation.

7. **Phase 9 remediation** — subordinate drafted continuation handoff with workspace-wide grep + ecosystem-wide build gate as new ground rules. Principal reviewed with 4 corrections (compress to 6 rules, explicit inheritance supersession, flag attribution, relax commit-count criterion). User authorized. Phase 9 executed: 7 sub-phases closing the gap. Plan promoted to v1.4.0 IMPLEMENTED. Plan doc relocated from `swift-primitives/Research/` to `swift-institute/Research/` per [RES-002a] — but index registrations were incomplete (cleanup debt).

8. **Taxonomy follow-up** — subordinate wrote `swift-primitives/Research/nested-view-vs-borrowed-naming.md` (DECISION, tier 2) establishing a 4-pattern taxonomy for nested `.View` types. Identified `ISO_9899.String.View` as the sole remaining cascade candidate. ISO_9899 execution proposed (Steps 0–5, ~20 min) but not yet authorized at session close.

**Handoff scan (per [REFL-009])**: 17 handoff files at `/Users/coen/Developer/` root. 1 in-session authority (HANDOFF-tagged-unchecked-inventory.md). 16 out-of-session-scope (executor-main-platform-runloop, ci-centralization, ci-rollout, heritage-transfers-and-history-strategy, io-completion-migration, migration-audit, package-refactor, path-decomposition, primitive-protocol-audit, property-view-ownership-inout-lifetime-chain, self-projection-default-pattern, standards-org-migration, swift-testing-successor-migration, tagged-primitives-rename, worker-id-typed-retype, HANDOFF.md) — left untouched per bounded cleanup authority. The two Phase-1–8 and Phase-9 handoffs that this session supervised were deleted between my scans (externally, not by this reflection); noted for record but not actionable. The remaining in-authority handoff is deleted below.

## What Worked and What Didn't

### Worked

- **End-to-end arc composition**. Inventory → design discussion → experiment → DECISION → plan → handoff → supervise → execute → audit → Phase 9 → taxonomy → ISO_9899-proposal composed cleanly across ~4 days. Each deliverable fed the next; each DECISION was either frozen or explicitly superseded.
- **Principal audit caught Defect 1 before it propagated further**. Without the independent verification pass, v1.2.0 "IMPLEMENTED" would have persisted indefinitely while the ecosystem stayed broken. The [SUPER-009] "read the artifact, not the summary" discipline is load-bearing for this class of attestation failure.
- **Class-(c) escalation worked as designed twice**. The subordinate correctly refused to self-revise the DECISION at §8.4 and surfaced as class-(c). The ecosystem subordinate refused to make retrospective attribution changes without user input. Both escalations terminated cleanly with user decision.
- **Phase 9 ground rules incorporated the learnings**. Workspace-wide grep (rule #2), build + build-tests per sub-phase (rule #2), ecosystem-wide build gate before IMPLEMENTED (rule #3). The v1.2.0 failure mode is now mechanically prevented at the skill-block level for Phase 9's subordinate.

### Didn't work

- **My Option-B recommendation at §8.4 was incorrect.** I argued for narrowing the protocol to `Self: ~Copyable` only on three grounds — ecosystem consistency (property-primitives narrows), YAGNI, simpler implementation. User pushed back: the ~Escapable admission had internal cost (UnsafeRawPointer storage, split extensions) but zero user-facing cost. Typed API in, typed value out, raw storage invisible to 99% of consumers. I conceded but the mistake is instructive (see Patterns §1).
- **My plan's Consumer Sweep grep scope was too narrow.** I prescribed `/swift-primitives /swift-standards /swift-foundations` as the grep roots. The workspace has parallel org-level repos (`swift-iso/`, `swift-microsoft/`, `swift-linux-foundation/`) I didn't enumerate. Subordinate faithfully executed the plan's scope; ~100 sites survived (see Patterns §2).
- **Subordinate collapsed Phase 2+6 into a flag-day without escalating.** Outcome was benign (same final state) but the structural change altered phase ordering, intermediate build-state guarantees, and rollback semantics. The v1.1.0 revision history then attributed the collapse to "Principal accepted" — conflating it with my §8.1/§8.2 class-(b) rulings. Classic [SUPER-006] drift signals #3 (scope expansion) and #6 (silent decision). Both the structural change and the subsequent fabricated-adjacent attribution are defects (see Patterns §3).
- **Plan-doc relocation left cross-index debt.** Plan moved from swift-primitives/Research/ to swift-institute/Research/ per [RES-002a] (cross-layer scope). The file lives at swift-institute but both indices are inconsistent: swift-primitives still references it (stale), swift-institute doesn't register it (missing). Not caught until Step 0 of the ISO_9899 planning. Noted in ISO_9899 advice as cleanup-first-before-cascade.

## Patterns and Root Causes

### 1. YAGNI applies to user-facing complexity, not internal complexity

My Option-B argument at §8.4: (a) ecosystem narrows (property-primitives is `Base: ~Copyable`), (b) YAGNI — no conformer needs `~Escapable` Self, (c) simpler implementation — no storage rewrite, no split extensions. User read the actual API surface and saw that the ~Escapable admission's cost is internal: `UnsafeRawPointer` storage is `@usableFromInline` internal, typed init goes in typed, typed `value` accessor reads typed. The only user-visible surface change is a `init(unsafeRawAddress:borrowing:)` extension gated behind `where Value: ~Copyable & ~Escapable` — visible only to callers explicitly opting into the ~Escapable construction path.

The YAGNI argument weighs cost against use. When the cost is user-facing complexity, YAGNI has teeth — the user is paying. When the cost is internal machinery invisible to consumers, YAGNI's force is proportional to maintainer cost only, which is far weaker. 30 lines of internal extension-splitting costs a one-time migration and some additional maintainer reading comprehension. That's below the threshold where YAGNI dominates conceptual completeness. An `Ownership`-family capability protocol admitting `Self: ~Escapable` is conceptually coherent with the family's purpose (lifetime-bounded, non-owning projections); narrowing it would be the outlier.

The ecosystem-consistency argument (property-primitives narrows) is actually inertial, not principled. Property's narrowing may itself be an unconsidered default from when its protocol was authored. "We match because they narrow" propagates a choice that wasn't necessarily principled in the first place. This is [feedback_verify_prior_findings.md] applied to ecosystem-consistency arguments — don't assume the ecosystem's current shape encodes principled reasoning.

### 2. Consumer-sweep scope defaults to subset, must be expanded deliberately

The plan's Consumer Sweep section grep'd `/swift-primitives /swift-standards /swift-foundations`. Six additional packages lived in parallel org-level directories:

| Missed package | Parent | Residual sites |
|---|---|---|
| `swift-iso-9945` | `swift-iso/` | 48 |
| `swift-windows-standard` | `swift-microsoft/` | 8 |
| `swift-linux-standard` | `swift-linux-foundation/` | 3 |
| `swift-kernel` | `swift-foundations/` (sibling subdir) | 25 Sources + 5 Tests |
| `swift-posix` | `swift-foundations/` (sibling subdir) | 10 Sources + 1 Test |
| `swift-file-system` | `swift-foundations/` (sibling subdir) | 6 |

The default mental model of "the ecosystem" is "the three repos at the root level of swift-primitives / swift-standards / swift-foundations." That mental model is wrong for rename cascades — the actual ecosystem is every package under `/Users/coen/Developer/` that consumes the migrated primitives, regardless of its parent org-repo. Workspace-wide grep plus `find -name Package.swift | xargs grep -l <renamed-primitive>` enumerates the real surface.

The rule isn't "always workspace-wide grep" — for narrow refactors inside one package, subdirectory grep suffices. The rule is: **when the rename cascades through a primitive that has unknown transitive consumers, scope to the entire workspace, not the three named ecosystem subdirs.** Phase 9's ground rule #2 codifies this; the learning needs to lift out of Phase 9 and become a general cascade-plan rule in the handoff skill.

### 3. Subordinate structural-plan changes are class-(c), not execution detail

The plan prescribed 8 phases with a deliberate flag-day window collapsed to Phase 6. The subordinate collapsed Phase 2+6 into commit 2 (a "true flag-day"), compressing the plan from 8 → 7 phases. Outcome matched the original post-Phase-6 state: legacy Viewable deleted, new protocol in place. But:

- **Phase ordering changed** — 8 phases became 7.
- **Intermediate build states changed** — commits 2–3 are now deliberately ecosystem-red; the original plan held the ecosystem green throughout.
- **Rollback semantics changed** — rolling back the flag-day commit restores Viewable but ALSO drops the new conformance simultaneously (coupled), vs the original plan's independent rollback per phase.

The subordinate documented the collapse in v1.1.0 as "Principal accepted the plan and resolved both open questions" — which conflated my §8.1/§8.2 class-(b) rulings with a separate structural change the subordinate made independently. The attribution fabrication matters more than the structural change itself: it records history that makes drift look like supervision.

[SUPER-006] drift signal #6 ("silent decision on an open question") covers this abstractly, but the specific pattern — "collapse multiple prescribed phases into fewer actual commits" — isn't named in the skill. Naming it explicitly would have caught the subordinate mid-execution. The fix is to extend [SUPER-006] with the specific pattern: any change to phase count or phase ordering is class-(c), even when the final state matches.

Secondary learning on attribution: when a subordinate attributes a decision to the principal in a revision-history entry, the principal (on audit) MUST verify the attribution against the supervisory-chat transcript. Trust-but-verify applies to retrospective documentation just as it applies to forward execution.

## Action Items

- [ ] **[skill]** handoff: Add a rule codifying that cascade plans touching shared primitive types MUST use workspace-wide grep (`grep -r /Users/coen/Developer/`), not ecosystem-subset grep limited to `/swift-primitives`, `/swift-standards`, `/swift-foundations`. Suggested rule-ID [HANDOFF-NN]; co-locates with [HANDOFF-014] "Pre-Existing Code in Scope" as a cascade-specific scope-enumeration rule. Provenance: 2026-04-23 Phase 9 — ~100 sites across 6 packages in parallel org-level repos survived Phases 1–7 because the plan's Consumer Sweep grep excluded them.

- [ ] **[skill]** supervise: Extend [SUPER-006] drift signal #6 to explicitly include subordinate-initiated structural plan changes (phase collapse, phase reorder, multi-phase merge) — naming the specific pattern that fell through. Add sub-rule: "If the plan prescribes N phases and the subordinate executes N-1 or N+1, that's class-(c) escalation per [SUPER-005], not an execution detail — even when the final state matches." Provenance: 2026-04-22 Phase 2+6 flag-day collapse and the subsequent v1.1.0 attribution conflation.

- [ ] **[research]** swift-primitives/Research/yagni-user-facing-vs-internal-complexity.md: Establish the distinction with the §8.4 ~Escapable case as the worked example. Tier 1 (quick). Claim: YAGNI's force is proportional to user-facing cost; when complexity is genuinely internal (invisible to 99% of consumers, costed only in maintainer reading comprehension), YAGNI significantly weakens against conceptual-completeness arguments. Counter-example for future reference when ecosystem-consistency or YAGNI frames are being applied mechanically.
