---
date: 2026-07-03
session_objective: Drive swift-file-system's Windows CI job to green (rounds 16–31 of the campaign), then run Phase 1 of the stack quality pass and hand the execution arc to a fresh session
packages:
  - swift-file-system
  - swift-windows-standard
  - swift-windows
  - swift-kernel
  - swift-executors
  - swift-async
  - swift-iso-9945
  - swift-linux-standard
status: pending
---

# file-system Windows Green + Quality-Pass Phase 1

## What Happened

The campaign closed: swift-file-system's Windows (Swift 6.3) job went GREEN on
main (527 tests / 314 suites, run 28635284784, re-confirmed next run), after 16
further rounds on top of the 15-round windows-standard evergreen arc. The
frontier moved through swift-kernel (sibling-lookup qualification, Completion
gating), swift-windows (L3 aliases; one self-inflicted duplicate-Close
collision), a large ISO-parity surface in windows-standard, swift-executors,
swift-async (isolated-closure SILGen assert), two asserts-toolchain crash
classes needing structural kills (§A23 borrowed-Optional projections;
multiple-isolated-parameters), file-system's own platform gaps, its
never-compiled +Windows test files, and nine runtime semantic gaps (O_APPEND,
directory symlinks, readTarget, rename-replace, temp root, permission
synthesis). Terminal record: swift-file-system/HANDOFF.md.

Immediately after, a quality pass opened: skills loaded (platform,
code-surface, swift-linter), a charter with three-tier rule triage, four
read-only sweeps (naming/file-shape; C-type leaks + import authority;
typed-throws/qualification; ISO↔Windows convergence), all adjudicated into
QP-001…QP-022 in swift-file-system/REVIEW-windows-quality-pass.md. Phase 2/3
were NOT executed here — per user direction the execution arc goes to a fresh
session with a purpose-built prompt (swift-file-system/PROMPT-quality-arc.md,
non-fable subagent routing, Windows-blind CI gates, lint-triage lockstep).

HANDOFF scan (file-system root): 6 files found; 1 deleted
(HANDOFF-windows-ci-green-relay.md — sole objective verifiably complete),
1 annotated-superseded (HANDOFF-ci-remediation.md), 1 stale-annotated
(HANDOFF-platform-compliance-consumer-migration.md, closure indeterminate),
3 left as live successor inputs (HANDOFF.md, REVIEW ledger, PROMPT).
Workspace guard: .handoffs/ WIP cap VIOLATION (111 > 40) — owned by the tower
program, out of this session's authority; flagged for its seat.

## What Worked and What Didn't

Worked: fix-at-root discipline across 10 repos held for 31 rounds; the
error-frontier loop (dedupe log → root-cause → one push → one run → one
watcher) converged monotonically; pre-empting same-class sites after a first
crash instance (Atomic TempFile after Streaming Context; Sample.State after
Latest.From) saved 45-minute CI rounds; macOS baselines (719 tests) never
broke. The quality-pass sweep→Fable-adjudication split worked well: agents
over-flag by design; the adjudication layer killed churn (29 "one type per
file" findings dissolved against the actual mechanized rule + ISO's own
canonical layout).

Didn't: two of my own audit failures became findings. (1) The Close-alias
collision — my pre-dispatch surface audit checked only the base L3 target,
missing the Descriptor target's existing policy enum ([PLAT-ARCH-020]'s
shadow grep must span ALL targets). (2) The Descriptor visibility change was
justified as "ISO parity" without reading the attribute lines above the ISO
declaration — ISO gates raw access behind @_spi(Syscall); my change made
Windows plain-public (QP-017). Both were caught by the pass, not by me at
authoring time. Also: an earlier §A23 "structural fix" comment claimed
whole-self @guaranteed had no shortenable scope; round 25 falsified it —
workaround comments asserting compiler behavior need [Verified:] discipline.

## Patterns and Root Causes

1. **Parity is multi-axis; signature convergence is the weakest axis.** The
convergence audit found signatures 14/16 converged while ERROR CASE SETS
(Move.Error +2 cases), VISIBILITY/SPI gating (Descriptor), and OWNERSHIP shape
(Thread.Handle Copyable vs ~Copyable) diverged. "Mirror the ISO signature" is
the reflex the campaign trained; the -standard convergence rule actually
quantifies over shape = signatures ∧ case sets ∧ access gating ∧ copyability.
Each divergence class was invisible at the axis where verification happened.
This belongs in the platform skill as an explicit checklist, not tribal memory.

2. **Asserts-toolchain crash classes demand class kills, not site fixes.** §A23
moved INTO the borrowing-method "fix" because the fix targeted the site, not
the trigger (borrowed-Optional force-unwrap of a ~Copyable field). Only the
trigger-level analysis (make storage non-optional / extract to a plain local)
terminated the whack-a-mole. Same shape for the isolated-parameters assert
(hoist implicit-self member captures). Under 45-min/round feedback, the
economics force trigger-level diagnosis after the FIRST instance.

3. **Verification tools' reach ≠ claim scope ([REFL-011] tool-reach, again).**
My target-scoped shadow grep read as "no collision"; the claim's scope was the
whole package. The sweep agents' mechanical rule-readings read as "violation";
the mechanized rule's actual scope said otherwise. Both directions of the same
epistemic failure — align the check's reach with the claim before acting.

## Action Items

- [ ] **[skill]** platform: amend [PLAT-ARCH-020] — the shadow pre-flight grep
  must span ALL targets of the L3 policy package (and its Descriptor-style
  satellite targets), not the base target; provenance: the swift-windows
  Close-alias collision (a889b92→2476182).
- [ ] **[skill]** platform: add an L2 platform-parity checklist rule — parity
  = signatures + error case sets + visibility/SPI gating + ownership shape
  (~Copyable) + defaults; provenance QP-016/017/018/020 in the file-system
  quality ledger.
- [ ] **[skill]** memory-safety: document the Windows 6.3.3+Asserts
  ownership-verifier crash class — trigger (borrowed-Optional force-unwrap of
  ~Copyable field projected into a throwing call) and the two kill patterns
  (non-optional storage; take() into a plain local once), plus the
  falsified whole-self-@guaranteed assumption; provenance c0b6393/967305f.
