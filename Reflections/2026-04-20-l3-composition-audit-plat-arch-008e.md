---
date: 2026-04-20
session_objective: Execute read-only compliance audit of swift-kernel against [PLAT-ARCH-008e] L3 Unifier Composition Discipline and dispatch follow-on remediation handoffs
packages:
  - swift-kernel
  - swift-posix
  - swift-iso-9945
  - swift-file-system
status: processed
processed_date: 2026-04-30
triage_outcomes:
  - type: skill_update
    target: audit
    description: "[AUDIT-031] Shadow-Elimination FALSE_POSITIVE Rule — when upstream fix eliminates an inheritance/alias pattern at source, classify FALSE_POSITIVE not RESOLVED or OPEN-partially-tracked. Origin: Findings #3/#4 reclassification."
  - type: skill_update
    target: handoff
    description: "[HANDOFF-034] Consumer Migration Bundling Anti-Pattern — consumer migration spanning multiple findings/audits MUST NOT be bundled as final commit in upstream dispatch; extract to standalone terminal handoff per [HANDOFF-017]."
  - type: no_action
    description: "Action item 3 ([doc] HANDOFF-kernel-file-flush-unifiers.md post-Phase-C ledger update) is a tracked future action conditional on Phase C commits landing; subsumed into the Flush handoff's normal completion workflow per [REFL-010]. No skill amendment needed."
---

# L3 Composition Audit: [PLAT-ARCH-008e] Read-Only Classification Sweep

## What Happened

The session dispatched from `swift-kernel/AUDIT-l3-composition.md` — a focused single-rule audit against [PLAT-ARCH-008e] (codified 2026-04-20 in `swift-institute/Skills/platform/SKILL.md:547`). Scope: enumerate L3 platform-policy wrappers across swift-posix / swift-darwin / swift-linux / swift-windows, apply the three-check decision test for each, report violations to `swift-kernel/Audits/audit.md` under a new "L3 Composition — 2026-04-20" section. Read-only classification. Do not fix.

**Read prior research first per [HANDOFF-013]**: `swift-posix/Research/l3-policy-design.md` (design rationale for L3 policy layer — EINTR wrappers), `swift-posix/Research/post-modularization-design-notes.md` (namespace depth, strerror layering, EINTR coverage prioritization), `swift-kernel/HANDOFF-kernel-file-flush-unifiers.md` (Finding #3 three-phase plan that codifies the remediation pattern).

**Enumeration** across four L3 platform packages (parallel greps):

| Package | Policy wrappers | Shadow of L2-raw? |
|---------|-----------------|-------------------|
| swift-posix | 25 methods (Flush ×4, IO.Read ×5, IO.Write ×6, Socket.Accept ×2, Send ×3, Receive ×3, Connect ×4) | 24 shadow (1 novel: `readAll`) |
| swift-darwin | 0 wrappers over L2 raw | — novel APIs only (`Darwin.Random.fill`, `System.Topology.NUMA.Discover`) |
| swift-linux | 0 wrappers over L2 raw | — novel APIs only (`Linux.Random.fill`, `Linux.Thread.Affinity.apply`) |
| swift-windows | 0 wrappers over L2 raw | — novel APIs only (Glob.Match, Thread.Affinity, NUMA, Random) |

**Mechanism verification**: `ISO_9945.Kernel = Kernel_Primitives_Core.Kernel` (typealias at `swift-iso-9945/Sources/ISO 9945 Core/ISO 9945.Kernel.swift:26`) — extensions on `ISO_9945.Kernel.T` add to the same `Kernel.T` consumers see. `Windows.Kernel` also a typealias (`windows-standard/Sources/Windows Kernel Standard Core/Windows.Kernel.swift:29`). But `POSIX.Kernel` is a SEPARATE `public enum` (`swift-posix/Sources/POSIX Core/POSIX.Kernel.swift:25-31`) per `l3-policy-design.md`'s "POSIX Enum vs Typealias" section — extensions on `POSIX.Kernel.T` do NOT flow to `Kernel.T`. This is what creates the shadow surface.

**swift-kernel grep**: zero explicit `Kernel.{File.Flush,IO.Read,IO.Write,Socket.*}` method definitions; zero references to `POSIX.Kernel.{File.Flush,IO,Socket}`. The `POSIX_Kernel` umbrella is `@_exported public import`-ed at `Kernel Core/exports.swift:47`, so `POSIX.Kernel.*` paths are visible to consumers, but only via explicit namespacing — exactly what [PLAT-ARCH-008e] targets.

**Initial classification**: 17 findings, all HIGH severity, all OPEN.

**User review — two corrections**:

1. **Findings #3/#4 (Darwin `full`/`barrier`)**: I classified "OPEN — partially tracked under Finding #3 handoff" on the reasoning that Phase C doesn't add cross-platform `Kernel.File.Flush.{full,barrier}` delegates. User corrected: these are FALSE_POSITIVE once Phase A lands. Reasoning: Phase A's rename eliminates the namespace-alias inheritance outright — after `full` → `fullFsync` at L2, there is no `Kernel.File.Flush.full(_:)` for a consumer to call at all. `full` and `barrier` are Darwin-specific syscalls without cross-platform siblings; `POSIX.Kernel.File.Flush.{full,barrier}` is the intended terminal surface. Absence of a cross-platform delegate is by design, not a gap.

2. **Commit 6 of the bundled retry-wrapper handoff**: I placed "consumer migration sweep across ecosystem" as Commit 6 of the `#5–#16` bundled upstream handoff. User corrected: consumer migration spans BOTH active audits (swift-file-system Platform Compliance audit + this L3 Composition audit); batching only the retry-wrapper consumer migration into Commit 6 splits consumer migration into two passes, violating the "all upstreams first, then one consumer pass" sequencing discipline. Pulled Commit 6 out into a separate terminal handoff `HANDOFF-platform-compliance-consumer-migration.md` in swift-file-system that waits for ALL upstream handoffs across both audits.

**Ledger updates**: transitioned #3/#4 to `FALSE_POSITIVE`; revised Summary counts (`17 findings: 0 critical, 17 high, 0 medium, 0 low. 0 resolved, 2 false positive, 15 open`); restructured Remediation shape section into four-step sequence (Flush → Connect → bundled retry-wrappers → terminal consumer migration) with explicit gating.

**Follow-on handoffs drafted by user** (3 files, ready for dispatch):
- `swift-kernel/HANDOFF-kernel-socket-connect-unifier.md` — Connect (#17), correctness fix, single concept-family, gates on Phase C landing
- `swift-kernel/HANDOFF-kernel-retry-wrapper-unifiers.md` — 5 commits (IO.Read, IO.Write, Socket.Accept, Socket.Send, Socket.Receive), gates on Connect landing
- `swift-file-system/HANDOFF-platform-compliance-consumer-migration.md` — 6 commits closing BOTH audits, gates on ALL upstreams landing

**Phase C gate verification**: checked all three Flush-handoff repos at end of session. **All three phases DRAFTED in working trees, none yet COMMITTED**. iso-9945 has rename + L2-unifier deletions staged (`fsync/fdatasync/fullFsync/barrierFsync` visible, old `full/data/barrier/flush` names gone, `Flush+DataOnly.*.swift` + `Flush+Directory.swift` scheduled for deletion). swift-posix has new `POSIX.Kernel.File.Flush+Data.Darwin.swift` + `POSIX.Kernel.File.Flush+Directory.swift` untracked. swift-kernel has `Kernel.File.Flush+CrossPlatform.{POSIX,Windows}.swift` untracked + tests. Rename validates Findings #3/#4 FALSE_POSITIVE against live code state.

**Final advice delivered**: strict serial gating — Flush commits (coordinated sweep across 3 repos, dependency-ordered) → Connect handoff → retry-wrapper bundle → terminal consumer migration. Multi-repo coordinated commits for Flush: iso-9945 before swift-posix before swift-kernel, all in quick succession (don't leave iso-9945 committed alone with swift-posix building against stale names).

## What Worked and What Didn't

### Worked

**Parallel enumeration across four L3 platform packages** collapsed the read-only classification phase into ~10 grep commands. The three-check decision test gave binary yes/no per method — no ambiguous cases. Each violation's evidence surfaced as file:line pairs on both sides (L2 inherited-via-alias source + L3 wrapper location) in a single pass.

**Cross-referencing existing Finding #3 handoff** prevented re-dispatching the Flush family. The audit's value was in enumerating the NEW violations (#5–#17) and surfacing the systemic pattern (24 methods, uniform retry-wrapper shape, all shadowed), not in re-litigating work already in flight.

**User refinement path worked fast**. Two corrections (FALSE_POSITIVE reclassification, Commit 6 split-out) were both 1-round fixes — user flagged the issue with reasoning; I applied the edit. No re-audit, no rework of the enumeration phase.

**Out-of-scope enumeration table** (novel L3 APIs that don't pattern-match the rule) was worth including for audit transparency. Makes the "rule does not apply" decision explicit for future auditors instead of implicit (they'd have to re-derive the classification for readAll, Glob, Random, Affinity, NUMA).

### Didn't work

**Initial "partially tracked" classification of Findings #3/#4** conflated "some work coverage via Phase A rename" with "some violation remaining." The diagnostic error: I was mentally applying the delegate-adding pattern (add `Kernel.File.Flush.*` in swift-kernel delegating to `POSIX.Kernel.File.Flush.*`) uniformly without checking whether the L2-rename path ELIMINATES the shadow at source. When the upstream fix removes the inheritance rather than adding a delegate, there's no violation to track — it's FALSE_POSITIVE by construction after Phase A. User caught this.

**Commit 6 bundling error** violated the sequencing discipline the Flush handoff itself already states ("batched with other findings' consumer migration"). I missed the cross-audit scope — consumer migration spans this audit AND the sibling Platform Compliance audit, and batching it into one upstream dispatch fragments that terminal pass across multiple PRs. Root cause: I was thinking "close the concept-family as a complete unit" when consumer migration is structurally terminal, not per-family.

**One wasted Edit call** when user had already updated the audit file themselves. The past-tense phrasing "the audit was updated for this" was ambiguous between "user updated it" and "please update it." Given auto mode's execute-don't-ask bias, I went with the second interpretation and hit a string-not-found error. Low cost but reflects that even with past-tense, an immediate state-check (Read current file) is cheaper than attempting the edit.

## Patterns and Root Causes

**Pattern 1 — Shadow-elimination via upstream rename is FALSE_POSITIVE, not OPEN.** [PLAT-ARCH-008e]'s three-check test presumes the L2-raw method remains at its original name. When the upstream fix RENAMES the L2 method to a spec-literal variant (Phase A pattern), the namespace-alias inheritance that caused the shadow simply disappears — `Kernel.File.Flush.full(_:)` no longer resolves at all post-rename. There is no longer a shadow to shadow. The finding is not "partially tracked" because there is no tracking to do: the violation ceases to exist, independent of whether a cross-platform delegate gets added.

The diagnostic question for a finding where upstream work is in flight: "After the planned upstream fix lands, does ANY consumer see the shadowed inheritance?" If no → FALSE_POSITIVE on Phase landing. If yes → OPEN, requiring a cross-platform delegate. The distinction matters because FALSE_POSITIVE findings don't generate downstream remediation work; "partially tracked" findings do, and tracking remediation that doesn't need to happen creates phantom work items.

**Pattern 2 — Consumer migration is structurally terminal.** Per-family upstream dispatches (Flush, Connect, retry-wrappers) each touch their own swift-kernel delegate surface; they do NOT touch consumer sites. Consumer migration is a separate concern with a different shape: it sweeps call sites across multiple packages (swift-file-system, swift-io, anywhere that hand-dispatched through `POSIX.Kernel.*`), and it closes MULTIPLE audits at once (Platform Compliance + L3 Composition share the same consumer surface). Batching consumer migration into an upstream handoff as a "final commit" splits the sweep into fragments, each fragment partial by construction (can only migrate the consumers that match THIS upstream's scope). The correct shape is: all upstreams first, then ONE terminal consumer pass that sees the full picture.

The sequencing rule is not just discipline — it's a consequence of the dependency graph. A consumer site calling `POSIX.Kernel.File.Flush.flush(fd)` can only migrate to `Kernel.File.Flush.flush(fd)` after Phase C of the Flush handoff lands. A consumer site calling `POSIX.Kernel.Socket.Send.send(…)` can only migrate after the retry-wrapper bundle lands. Fragmenting consumer migration into per-handoff commits forces per-consumer diffs to straddle multiple PRs as each upstream lands on its own timeline — the unified `Kernel.*` retargeting only becomes coherent AFTER all upstreams complete.

**Pattern 3 — Multi-repo Phase sweeps are coordinated commits, not sequential ones.** The Flush handoff's Phase A/B/C spans three repos (iso-9945, swift-posix, swift-kernel) with strict dependency ordering: B requires A's renamed symbols; C requires B's new methods. Committing A alone leaves B and C building against stale names. The "land" verb for a multi-repo handoff means "coordinated commit sweep in dependency order," not "commit and wait for CI between each." Working trees in this session show all three phases drafted simultaneously — the right pattern — and the next step is committing them in quick succession, not one-at-a-time with CI cycles in between.

**Meta-pattern: pattern-validation gating explains the execution order.** Why Flush before Connect before retry-wrappers? Each upstream validates a piece of the composition pattern for larger-surface applications:
- Flush validates the three-phase shape + file-level-guard discipline + cross-platform delegate pattern on 3 methods across 3 repos.
- Connect validates the same pattern on a semantic-correctness fix (awaitCompletion composition) — single method, different shape from retry, limited blast radius if the pattern needs adjustment.
- Retry-wrapper bundle applies the validated pattern at scale (12 methods, 5 concept-families) — mechanical if prior validations hold, risky if not.

Dispatching in a different order inverts the validation ladder: applying an un-validated pattern to 12 methods and then discovering the pattern needs revision means redoing 12 methods. Strict serial gating costs latency; skipping the gates costs rework at scale.

## Action Items

- [ ] **[skill]** audit: Codify the shadow-elimination FALSE_POSITIVE rule. When a finding depends on an inheritance pattern that a planned upstream fix ELIMINATES (via rename, type removal, namespace restructure), the correct classification is FALSE_POSITIVE upon upstream landing, not OPEN-partially-tracked. Add a decision prompt to [AUDIT-004] or a new [AUDIT-*] rule: "If the planned upstream fix removes the inheritance at source rather than adding a delegate, mark FALSE_POSITIVE with the upstream reference; otherwise OPEN."
- [ ] **[skill]** handoff: Add an anti-pattern rule that consumer migration MUST NOT be bundled as a final commit in an upstream dispatch when consumer migration spans multiple findings across multiple audits. The correct home is a standalone terminal handoff at the audit-closing scope (e.g., the package where the audit lives), gated on ALL upstream handoffs landing. The sequencing discipline ("all upstreams first, then one consumer pass") is structural, not stylistic — fragmenting consumer migration forces per-consumer diffs to straddle multiple PRs.
- [ ] **[doc]** HANDOFF-kernel-file-flush-unifiers.md: After the three Flush phases commit, update the handoff's Findings Destination section to record SHAs for Phase A, B, C commits AND to update `swift-kernel/Audits/audit.md` L3 Composition findings #1, #2 to `RESOLVED {SHA}` and confirm findings #3, #4 `FALSE_POSITIVE — Phase A eliminated inheritance (commit {SHA})`. Per [REFL-010] ledger-update discipline.
