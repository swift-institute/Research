---
date: 2026-06-26
session_objective: Drive the swift-linter closure bottom-up publication campaign (Waves 4–7), hand off to an autonomous overnight /goal run, then reconcile the morning state and wire the next blocker class.
packages:
  - swift-primitives (campaign-wide; ~46 packages flipped public this session)
  - swift-linter-primitives
  - swift-buffer-primitives
  - swift-cursor/list/loader/memory-iterator/memory-shared/memory-lock/memory-small/optic-primitives
status: processed
processed_date: 2026-07-02
triage_outcomes:
  - type: skill_update
    target: testing-institute
    description: "Proposal collected (recommend KEEP — highest-value item, campaign live): [INST-TEST-013] generic-namespace / no-own-type carve-out — @Suite cannot emit static stored properties inside a generic type; conforming shape is top-level single-word @Suite(\"Name\") struct Tests or an extension of a non-generic parent / @_exported namespace; swiftc -typecheck probe as verification. Verified absent from testing-institute."
  - type: skill_update
    target: handoff
    description: "Proposal collected (recommend KEEP): landing-barrier rule for autonomous successors — do not launch an autonomous successor chat until the predecessor's state is fully landed (squashes/force-pushes complete) AND recorded (baton/tracker written); extends feedback_no_duplicate_dispatch_shared_tree from same-task to different-task landing boundaries."
  - type: skill_update
    target: ci-cd-workflows
    description: "Proposal collected (recommend KEEP; merge with the 2026-06-02 release-readiness ci.yml item into one 'CI signal exists' vet): before flipping a package whose validation relies on CI, vet gh api repos/<org>/<pkg>/actions/permissions --jq .enabled; if false the flip ships unvalidated — run the local floor or skip."
---

# swift-linter Closure — the resolve-check cadence pivot, and the overnight-handoff race

## What Happened

Carried the swift-linter closure publication campaign across **Waves 4–7** (~46 swift-primitives packages flipped public, 33→116 over the campaign), then set up an autonomous overnight `/goal` run, then reconciled the morning state and wired the next blocker class.

- **Waves 4–5** ran the proven cadence (parallel prep Workflow → serial Docker floor → flip-before-push → ci-ok gate → squash); 9 + 13 packages, plus closing the serializer/input Windows-crash held-backs via a relay.
- **Wave 6** changed the cadence on principal direction: dropped the full local floor for **"resolve-check + CI"** — a fast clean-room `swift package resolve` + deps-public check pre-flip, then rely on CI's full Windows/Linux/sim matrix + fix-forward. New `resolve_check.sh` script.
- **Wave 7** flipped 11 (incl. `linter-primitives`, the first swift-linter *direct* dep to reach the frontier). Hit the new cadence's costs: storage-generational red on a buffer-primitives `getenv` Windows bug (Test Support, no `ucrt` import — fixed), `format`/`cpu` red because their repo **Actions were disabled** (no CI signal at all), and `linter-primitives` took THREE fix-forwards on a `[UInt8]`→`[Byte]` test mismatch.
- **Overnight `/goal` run** (separate chat, scoped to skip-all-blocked + no-squash): flipped 4 + reconfirmed linter-primitives, then declared "clean-frontier empty" and stopped.
- **Morning**: reconciled a squash-state discrepancy (below), squashed the 4 genuinely-unsquashed greens, computed the honest private breakdown, and **wired test targets into the 8 no-test-target frontier packages** (build-verified 8/8) — the highest-leverage remaining unblock — then wrote a RELAY-IN to the baton for the Main campaign.

HANDOFF scan: 2 files at `~/Developer/.handoffs/` root. `HANDOFF-swift-linter-closure-publication.md` — the active campaign baton, in-flight (Main campaign is executing it; I wrote the RELAY-IN this session) → **no-touch per [REFL-009a]**. `HANDOFF.md` (tower/cleave/msb program) — out of cleanup authority, untouched.

## What Worked and What Didn't

**Worked:**
- The parallel-prep + serial-gate cadence scaled cleanly to 13-package waves; subagents' structural review caught stubs a line-count vet missed (locale: 32 src but TODO-only).
- **Primary-source re-derivation ([REFL-011]) paid off decisively in the morning.** The overnight report said "squash 5 + 12 carryover (17)." I distrusted it and ran `git rev-list --count` per package → 11 of the 12 were ALREADY squashed (I'd done them the night before). Blindly running the report's command would have re-squashed 11 green packages + re-fired CI. The rule fired exactly where it should: a count driving an action, re-derived from git not the artifact.
- Wiring the 8 test targets: subagents probed deviations with `swiftc -typecheck` (allowed — not a package build) before committing to a non-canonical shape; all 8 build-verified.

**Didn't:**
- **`linter-primitives` cost three fix-forward cycles** (`Array(text.utf8)` [UInt8]≠[Byte] → `[Byte](text.utf8)` no-such-init → `text.utf8.map(Byte.init)` Byte-not-in-scope → finally + byte dep on the test target + import). Each cycle burned a ~15-min CI round. I guessed twice before reading source-primitives' own test for the canonical pattern. I should have read the authoritative pattern first.
- **Expectation-setting on the overnight run.** I framed the goal as "clean-frontier empty" without making clear that the clean frontier was only ~4 packages deep — so the user woke expecting "the remainder flipped" and got 4. The run wasn't lazy (it hit the bottom-up wall), but I set the wrong expectation.
- **The two chats raced on the shared tree.** The overnight chat started while my chat was still finishing Wave 7's squashes; its reconstruction of "Session 7" captured a mid-squash snapshot, producing the over-claimed carryover.

## Patterns and Root Causes

**1. The resolve-check pivot traded a pre-flip compile-gate for post-flip CI breadth — and the trade has a sharp, specific blind spot.** Dropping the local build/test floor was correct on the merits (CI is *more* complete: it runs Windows/Linux/sim/embedded the macOS floor never sees — the serializer/storage-generational Windows failures were CI-only catches). But the cadence assumes CI *runs*. For a package with **GitHub Actions disabled** (`actions/permissions {enabled:false}` — format, cpu), the flip produces neither a CI signal nor (under resolve-only) a local compile-verify: it ships public *unvalidated*. The blind spot is invisible until you check `actions/permissions`. The fix is a one-line vet gate before relying on CI. This is the general shape of [REFL-011]'s tool-reach extension: "rely on CI" is a state-claim whose scope is bounded by CI actually running, and Actions-disabled silently narrows that reach to zero.

**2. Bottom-up campaigns hit a wall the moment the frontier is all-blocked, and the wall arrives far earlier than the private-count suggests.** The "wasted overnight" reaction traced to a real structural fact: of 100 private packages, **71 are *deeper*** (have a private dep — structurally unflippable until the frontier advances) and the **29 on the frontier are *all* in a blocked class** (stub / no-test / heavy-doc / flaky). The clean frontier was ~4 deep. So an autonomous run scoped to "skip all blocked" *correctly* flips ~4 and stops — the remaining 96 are gated behind a small number of frontier blockers (the no-test-8, the heavy-doc fan-outs dimension/buffer-ring/path). The leverage is concentrated, not distributed: wiring the 8 no-test targets (this morning's work) unblocks more depth than any number of additional clean-only loops. The lesson for scoping autonomous runs: name the realistic flip count up front (= size of the *clean* frontier, not the private count), and recognize that "flip the remainder" is the *blocked* work, which needs judgment the autonomous run was told to skip.

**3. Concurrent agents on a shared filesystem must be sequenced at landing boundaries, not just task boundaries.** `feedback_no_duplicate_dispatch_shared_tree` says one-task-one-chat; this session shows the subtler failure — *different* tasks (my Wave-7 finish, the overnight Wave-8 start) on the *same* tree, overlapping in time, racing on shared mutable state (the squash form of 11 packages, `squash.py`'s MSG dict, `prep-workflow.js`'s BATCH). The successor read a mid-flight snapshot and recorded stale ground-truth. The root cause is a missing handoff *barrier*: the autonomous successor should not start until the predecessor's state is fully *landed* (squashed) and *recorded* (baton/tracker written), because the successor's first act is to rebuild ground-truth from that state. The barrier is cheap (the predecessor says "done + recorded, you may start"); the race is expensive (a morning of reconciliation).

**4. The institute test-pattern canon assumes a non-generic own-type — generic namespaces and no-own-type packages need a carve-out.** [INST-TEST-013]'s canonical `extension <SourceType> { @Suite struct Tests }` does not compile when `<SourceType>` is a generic namespace (`List<Element>`, `Memory.Small<let n: Int>`): the `@Suite` macro emits a `static let`, illegal in a generic type. And `memory-iterator` declares no own type at all (only a constrained `extension Span.Protocol`). Three of eight packages needed a deviation (top-level `@Suite("Name")`, or extend a non-generic parent / `@_exported` namespace). The canon was written from the common case and never met the generic-namespace L1 case. This is a clean skill gap, not a one-off.

## Action Items

- [ ] **[skill]** testing-institute: Add a generic-namespace / no-own-type carve-out to [INST-TEST-013]. When the source type is a generic namespace (`@Suite` can't emit static stored properties inside a generic type) or the package declares no own type, the conforming shape is a top-level single-word `@Suite("Name") struct Tests` (NOT a compound `FooTests`) or an extension of a non-generic parent / `@_exported` namespace; cite the `swiftc -typecheck` probe as the verification method. Verified against list / memory-iterator / memory-small.
- [ ] **[skill]** handoff: Add a landing-barrier rule for autonomous successors — do NOT launch an autonomous successor chat (e.g. overnight `/goal`) until the predecessor's state is fully landed (force-pushes/squashes complete) AND recorded (baton + tracker written), because the successor's first act is to rebuild ground-truth from that state; concurrent overlap races on the shared tree and produces stale reconstruction (this session: over-claimed squash carryover, a morning of reconciliation).
- [ ] **[skill]** ci-cd-workflows: Document the Actions-disabled blind spot of any "rely on CI" flip cadence — before flipping a package whose validation depends on CI, vet `gh api repos/<org>/<pkg>/actions/permissions --jq .enabled`; if `false`, the flip ships unvalidated (no CI signal, and resolve-only doesn't compile-verify) → run the local build/test floor or skip. Generalize as a tool-reach check ([REFL-011]): "CI will validate this" is false when Actions is disabled.
