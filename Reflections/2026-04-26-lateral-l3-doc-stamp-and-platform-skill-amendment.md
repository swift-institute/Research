---
date: 2026-04-26
session_objective: Author + stamp the lateral-L3 design Doc; codify [PLAT-ARCH-008h] + [PLAT-ARCH-008i] in the platform skill; refactor swift-windows.Thread.Affinity to drop swift-systems dep (P3.5); produce next-session handoff.
packages:
  - swift-institute/Research
  - swift-institute/Audits
  - swift-institute/Skills
  - swift-foundations/swift-windows
status: processed
processed_date: 2026-04-30
triage_outcomes:
  - type: skill_update
    target: audit
    description: "[AUDIT-029] Empirical Census Before Options Matrix — when codifying a layering/composition/classification rule from audit findings, an empirical census across the rule's scope MUST precede the options matrix. Findings are samples; the census is the population."
  - type: skill_update
    target: audit
    description: "[AUDIT-030] Real-Time Per-Package audit.md Row-Text Updates — distinct from [AUDIT-005] re-audit cycle; remediation sessions MUST update the per-package audit.md row text in-session alongside the source change, not deferred to a hygiene-sweep dispatch."
  - type: research_topic
    target: cross-platform-sibling-as-refactor-template.md
    description: "Tier 2 IN_PROGRESS Research Doc scoping when sibling per-platform packages' working analogs are valid refactor templates (cross-platform-shared concerns) vs when they are not (genuinely platform-divergent subsystems). Origin: 2026-04-26 swift-windows.Thread.Affinity refactor mirrored swift-linux.Thread.Affinity."
---

# Lateral-L3 Doc stamp + platform skill amendment + P3.5 refactor — 2026-04-26

## What Happened

Sequential continuation of yesterday's audit dispatch arc. Yesterday closed with the lateral-L3 design Doc in OPTIONS_MATRIX status (decision pending). Today closed: stamping → codification → refactor → handoff. Six commits across 4 repos.

**Phase sequence**:

1. **Doc framing alignment** (early session): user picked Hybrid B+C with structural twist — explicit 3-sub-tier enumeration (L3-policy / L3-unifier / L3-domain), no L2.5 introduction. swift-posix stays L3-policy. Empirical census of within-L3 imports across the 13 audit packages was conducted FIRST per principal direction; surfaced Pattern 3 (swift-windows → swift-systems via Windows.Thread.Affinity:16) as a previously un-flagged violation. swift-systems re-classified L3-unifier (not L3-domain) after Package.swift inspection showed it composes swift-darwin/linux/windows directly per [PLAT-ARCH-008e] pattern with no swift-kernel dep — same role-shape as swift-kernel itself, peer rather than consumer.

2. **Doc stamping** (commit `4a29c36` swift-institute/Research): appended `## Stamped Decision (2026-04-26)` section with codification candidates. Status transitioned OPTIONS_MATRIX → STAMPED in `_index.json`.

3. **Skill amendment** (commit `8ccd1e9` swift-institute/Skills): added `[PLAT-ARCH-008h]` (Within-L3 sub-tiering matrix) + `[PLAT-ARCH-008i]` (POSIX-shared base composition carve-out) to platform skill. Originally proposed 008f/008g but those IDs were already taken (Naming-Parity-Collision Pre-Check + Pre-Flight Memory Consultation Before Cross-L2 Dependencies); next available was 008h/008i. Cross-references updated in Doc + tracker via `sed -i ''` (commits `aacad4f` Audits, `76c074d` Research). Hard-link verified: `swift-institute/Skills/platform/SKILL.md` ↔ `/Users/coen/Developer/.claude/skills/platform/SKILL.md` (same inode 657104116) — no sync-skills.sh run needed.

4. **P3.5 refactor** (commit `6503806` swift-foundations/swift-windows): single-file refactor + Package.swift cleanup. Removed `public import Systems`; replaced with `public import System_Primitives` (L1, downward). Replaced `let topology = System.topology()` (calls swift-systems unifier) with `let numa = System.Topology.NUMA.discover()` (same-package call to swift-windows's own Windows-NUMA implementation). Mirrors swift-linux.Thread.Affinity pattern exactly. Build clean (`swift build` 2.80s for full package; swift-systems downstream 64.08s). Tracker stamp at commit `551305a`.

5. **Handoff produced**: `HANDOFF-platform-audit-cycle-followup.md` (sequential template, topic-suffixed filename per existing HANDOFF-* convention to avoid collision with the active Property Primitives `HANDOFF.md`). Documents 3 queued tasks (per-package audit.md hygiene sweep, Windows mechanical batch, /reflections-processing) + state across 8+ repos with unpushed commits + gated work.

**Final scoreboard**: 55/6/36 of 97 (was 52/6/38 of 96 yesterday-close). +3 RESOLVED (P2.11 + P2.12 via codification, P3.5 via refactor); +1 NEW finding (P3.5 logged + resolved same-day); -2 OPEN net.

**Handoff scan per [REFL-009]**: 6 files at `swift-institute/` root scanned —
- HANDOFF.md (Property Primitives launch, out-of-session-scope, unchanged)
- HANDOFF-platform-audit-cycle-followup.md (NEW this session, work not yet started — leave in place)
- HANDOFF-string-correction-cycle.md, HANDOFF-typed-time-clock-cleanup.md, HANDOFF-windows-kernel-string-parity.md, STATUS-string-fix-for-file-system-agent.md (all out-of-session-scope, unchanged)

Triage outcome: 6 files scanned; 0 deleted; 1 newly-created; 5 out-of-session-scope.

**Audit cleanup per [REFL-010]**: synthesis tracker updated across 3 commits (lateral-L3 stamp, [PLAT-ARCH-008h+i] codification, P3.5 RESOLVED). Per-package audit.md row text updated in-session for the relevant findings: user just updated `swift-foundations/swift-windows/Audits/audit.md` Findings #4 (P2.5 RESOLVED), #5 (RESOLVED), #6 (RESOLVED) inline with the source changes — observed via system reminder mid-session. The "per-package audit.md hygiene sweep" task queued in the handoff is being partly done in real-time by the user.

## What Worked and What Didn't

**What worked**:

- **Empirical census before options matrix**: principal's instruction to "do the census first" surfaced Pattern 3 (swift-windows → swift-systems) which would not have surfaced from P2.11 + P2.12 alone. Without the census, the codification would have addressed only the audit-flagged patterns and Pattern 3 would have remained un-flagged.
- **Verifying via Package.swift dep-graph inspection**: my initial classification put swift-systems in L3-domain. The principal's "(right? I'm not sure this applies correctly for all these)" caveat was the prompt to verify. Package.swift inspection showed swift-systems depends on swift-darwin/swift-linux/swift-windows directly with no swift-kernel dep — same shape as swift-kernel itself per [PLAT-ARCH-008e], so it's L3-unifier not L3-domain. Empirical inspection flipped the classification.
- **swift-linux as template for swift-windows refactor**: the P3.5 refactor needed a structural decision about how to drop the upward dep. Looking at swift-linux.Thread.Affinity (the working analog) gave the answer: same-package `System.Topology.NUMA.discover()` call + downward `System_Primitives` import. The fix was "make Windows match Linux's structural shape." Cross-platform symmetry as a refactor heuristic.
- **Same-day-cycle execution**: stamp → skill amendment → refactor → tracker update → handoff in one session. Each phase took ~15-30 min. The principal's stamp was the only real decision moment; the rest was mechanical execution against the stamped matrix.
- **Hard-link verification**: ran `stat -f "%i %N"` to confirm `Skills/platform/SKILL.md` and `.claude/skills/platform/SKILL.md` share the same inode before assuming the edit propagated. Saved a potential confusion about whether to run sync-skills.sh.

**What didn't work**:

- **Rule-ID collision on first attempt**: I proposed `[PLAT-ARCH-008f]` + `[PLAT-ARCH-008g]` for the new rules without checking the existing ID space. Both IDs were already taken (different rules). Required a follow-up `sed -i ''` rename pass across the Doc + tracker after discovering the collision. Cost was ~5 min of friction; preventable by `grep` on existing IDs before proposing new ones.
- **Initial classification of swift-systems as L3-domain was wrong**: my first synthesis put swift-io / swift-threads / swift-environment / swift-systems all in L3-domain because they live in `swift-foundations/`. That's a directory-based classification heuristic. The actual classification (L3-unifier for all four — they're cross-platform unifiers) emerges from role inspection (what they EXPORT) + dep direction (what they DEPEND on), not from filesystem location. The principal's caveat caught the error before it shipped.

## Patterns and Root Causes

**Pattern 1 — Empirical census before rule design**

The lateral-L3 Doc was strengthened materially by running the within-L3 import grep BEFORE writing the options matrix. The grep surfaced 6 distinct composition patterns where I had been thinking about 2 (P2.11 + P2.12). Pattern 3 (swift-windows → swift-systems) and Pattern 4 (swift-file-system → unifier, assumed-authorized) and Pattern 6 (test-scope laxer) were all material to the rule shape. Without the census, the rule would have been narrowly tailored to two findings and missed the broader matrix.

This generalizes: when codifying a layering / composition / classification rule based on audit findings, the empirical census across the affected scope MUST come before the options matrix. Findings are samples; the census is the population. Rules written from samples are under-fit; rules written from populations capture the full pattern space.

The principal's [HANDOFF-021] empirical-package-list re-derivation discipline is structurally identical: don't trust the agent's recall; re-derive from source. Today's lesson extends that to "don't trust the audit's finding set alone; re-derive the pattern population from source." Both are forms of "verify before reasoning."

**Pattern 2 — Cross-platform sibling as refactor template**

The P3.5 refactor needed to drop swift-windows.Thread.Affinity's swift-systems dep. The fix shape wasn't obvious from the violation alone — there are several ways to drop an upward dep (replace with a downward call, restructure the consuming function, eliminate the case entirely, etc.). The fast path was: read swift-linux.Thread.Affinity (the working sibling for the same syscall family) and match its structural shape.

This generalizes: when fixing a layering or structural violation in one per-platform package, the sibling per-platform packages' working analogs are the refactor template. Cross-platform symmetry is a heuristic for "what's the right shape?" because if Linux and Darwin both work the same way, Windows working the same way is structurally consistent.

The pattern doesn't always apply — sometimes platforms genuinely differ (Windows isn't POSIX, Darwin has Mach-specific extensions, etc.). But for cross-platform-shared concerns (NUMA discovery, thread affinity, file IO retry policy), the working sibling IS the template, and "make X match Y's shape" is a faster fix than reasoning from first principles.

**Pattern 3 — Rule pairing for matrix + carve-out composition**

The new [PLAT-ARCH-008h] is a 3×3 matrix codifying within-L3 composition. [PLAT-ARCH-008i] is a specific permitted exception (POSIX-platform → POSIX-shared base). Two rules, paired by cross-reference, where one rule is the general matrix and the other is the specific exception.

Compare this to the alternative — a single rule with embedded exceptions ("L3-policy peer composition is forbidden EXCEPT when one peer provides spec-shared semantics, AND the other extends, AND..."). The single-rule shape buries the exception in the rule body; the paired-rule shape makes the exception a first-class rule that can be cross-referenced, replaced, or extended independently.

Generalizable: when codifying a composition / classification rule with sanctioned exceptions, prefer pairing (general rule + specific exception rule) over embedding (single rule with caveats). The paired shape:
- Makes the matrix structure visible at the skill-table-of-contents level
- Allows the exception to evolve (add new sanctioned cases) without re-editing the general rule
- Surfaces the exception as a first-class concept consumers can search for

The platform skill already has a parallel pattern: [PLAT-ARCH-008] is the general consumer-import rule; [PLAT-ARCH-008a-d] are specific exceptions / refinements. Today's 008h + 008i extends this convention.

**Pattern 4 — Real-time per-package audit.md updates by the principal**

The system reminder mid-session showed the user updating `swift-foundations/swift-windows/Audits/audit.md` Findings #4/#5/#6 statuses inline as the session ran. This is a real-time per-package audit.md hygiene update — the principal is doing the hygiene work alongside the source-and-tracker changes, not waiting for a separate dispatch.

This refines the audit skill's [AUDIT-005] (Update In Place). [AUDIT-005] is about re-audit cycles ("re-running the audit overwrites the section"). The real-time per-finding update during a remediation session is a different concern — the row-text annotations (RESOLVED 2026-04-25 (commit X) — fix description) belong with the source changes for next-dispatch enumeration accuracy.

The handoff I wrote queued "per-package audit.md hygiene sweep" as a separate dispatch. The user demonstrated by example that real-time updates are the better workflow. Generalizable: when a remediation session resolves an audit finding, the per-package audit.md row text update belongs in the session, not as a queued cleanup.

The platform skill amendment cycle today partly demonstrated this — when [PLAT-ARCH-008h+008i] landed, the synthesis tracker was updated in the same session. But the per-package audit.md files were not (they're gitignored, and I had assumed local edits weren't worth it; the user's update shows otherwise — local edits ARE worth it for next-dispatch enumeration accuracy even though they don't propagate to other clones).

## Action Items

- [ ] **[skill]** audit: codify the empirical-census-before-options-matrix discipline. When a Research Doc seeks to codify a composition / layering / classification rule based on audit findings, the empirical census across the affected scope MUST precede the options matrix. Anchor: 2026-04-26 lateral-L3 Doc census surfaced Pattern 3 that wasn't on the audit's P-series radar. Cross-reference [HANDOFF-021] empirical-package-list re-derivation as parallel discipline.
- [ ] **[skill]** audit: document the real-time per-package audit.md row-text update pattern. Distinct from [AUDIT-005] re-audit-cycle update-in-place. When a remediation session resolves an audit finding, the per-package audit.md row text update SHOULD happen in-session (alongside the source change + synthesis-tracker update), not deferred to a separate hygiene-sweep dispatch. Anchor: 2026-04-26 user's real-time swift-windows audit.md update during P3.5 refactor session.
- [ ] **[research]** swift-institute/Research/cross-platform-sibling-as-refactor-template.md: document the heuristic. When fixing a layering / structural violation in one per-platform package, the sibling per-platform packages' working analogs are the refactor template. Anchors: 2026-04-26 swift-windows.Thread.Affinity refactor used swift-linux.Thread.Affinity as the structural template (NUMA discovery via same-package System.Topology.NUMA.discover() + downward System_Primitives import). Generalize: when does the heuristic apply (cross-platform-shared concerns) vs when does it not (genuinely platform-differing concerns like Mach-specific extensions)?
