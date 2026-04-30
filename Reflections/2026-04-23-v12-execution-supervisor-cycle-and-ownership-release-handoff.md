---
date: 2026-04-23
session_objective: Execute the property-view lifetime-escape investigation handoff; incorporate supervisor feedback; draft the ownership-primitives 0.1.0 release-readiness handoff.
packages:
  - swift-ownership-primitives
  - swift-property-primitives
  - swift-buffer-primitives
  - swift-queue-primitives
status: processed
processed_date: 2026-04-30
triage_outcomes:
  - type: skill_update
    target: experiment-process
    description: "[EXP-021] One-Factor-At-A-Time at the Reduction-to-Trigger-Narrowing Boundary — codifies that CAN'T-REPRODUCE → CAN-REPRODUCE variant transitions MUST add exactly one structural factor, not leap to the full dependency graph."
  - type: skill_update
    target: handoff
    description: "[HANDOFF-037] Probe-List vs Do-Not-Touch Internal Contradiction — sixth staleness axis to [HANDOFF-016]."
  - type: package_insight
    target: swift-primitives/_Package-Insights.md
    description: "Stale-cache linker errors note deferred — would need to identify which package's _Package-Insights.md is appropriate; the reflection lists swift-primitives the superrepo (not a single package). Captured as ecosystem-wide note here in triage_outcomes for searchability."
---

# V12 Execution, Supervisor Cycle, and Ownership Release-Readiness Handoff

## What Happened

Three-part session. (1) Executed the branching handoff
`HANDOFF-property-view-ownership-inout-lifetime-chain.md` (the investigation brief
the parent session authored). (2) Asked for independent supervisor review, folded
amendments in. (3) Drafted `AUDIT-0.1.0-release-readiness.md` for
swift-ownership-primitives at the user's request to reorder release sequence
(ownership → identity/tagged → property).

**Investigation execution (Part 1)**:
- V1 (inline minimal types) and V2 (parallel MyInner/MyOuter with real
  property/ownership primitives) both failed to reproduce on clean
  `rm -rf .build` builds
- V3 (MyDeque wrapping real `Buffer<Element>.Ring`) reproduced the exact
  `error: lifetime-dependent value escapes its scope` at the `.front`
  column (queue-primitives:169:47 + :261:47)
- V4–V9 call-site probes: all failed except V5 (free borrowing helper),
  which is structurally equivalent to the rejected `_peekFront()` /
  `_peekBack()` workaround
- V10/V11 primitive-level `@_lifetime(...)` annotations on
  `Ownership.Inout.value._read` rejected by compiler — "invalid lifetime
  dependence on an Escapable result"
- V12 landed: split `Ownership.Inout.value` into
  `where Value: Copyable { get + nonmutating _modify }` and
  `where Value: ~Copyable { _read + nonmutating _modify }`.
  Critical difference from the previously-rejected `get + set` split:
  `nonmutating _modify` preserves writeback for nested method-call
  mutations that `set` never re-fires for.
- Acceptance: queue lines 169/261 compile with the original
  `base.value._buffer.peek.front`/.back expressions; property (46/46),
  buffer (392/392), identity (54/54), ownership (24/24) tests pass

**Supervisor cycle (Part 2)** — independent agent reviewed with verdict
LAND WITH CHANGES and four amendments:
- (a) Test label `Buffer.Linear CoW` was wrong; actual test is
  `Buffer.Ring.Bounded Tests.swift:123` — verified via grep, corrected
- (b) Structural-trigger speculation ("class reference or
  conditional-Copyable-via-extension") was un-evidenced — ran V2.5a
  (parallel + class-reference field: REPRODUCES) and V2.5b
  (parallel + value-type header: does not) to empirically narrow;
  class reference in `_buffer` is the trigger
- (c) Candidate-3 from the handoff (remove `@_lifetime(borrow self)` from
  `Property.View.Typed.base`) was NOT probed; handoff listed
  property-primitives as Do Not Touch AND asked to try this file —
  self-contradicting. Not investigation gap.
- (d) Acceptance extended with heavy-consumer sweep: dictionary (128),
  heap (105), set (100), slab (18), vector (106), stack (94) all green
  post-V12; heap/vector/dictionary required `rm -rf .build` to clear
  endemic stale-cache linker errors unrelated to V12

**Ownership 0.1.0 handoff (Part 3)** — gap-diff vs property-primitives
at its pre-tag audit revealed ownership needs substantial release-prep
work before a final systematic audit: no README, single DocC article,
zero experiments, empty `Research/_index.json`, 24 tests across 20
source files, minimal `Audits/audit.md`. Authored a three-phase branching
brief (Phase 0 baseline stabilisation including V12 commit → Phase 1
release-prep gap closure → Phase 2 systematic audit → Phase 3 readiness
checks).

**HANDOFF scan** (per [REFL-009]): 16 files at `/Users/coen/Developer/`
enumerated; all 16 out-of-session-scope (parent-session work). The
handoff this session executed —
`HANDOFF-property-view-ownership-inout-lifetime-chain.md` — was deleted
between my first read and session end (parent cleanup, visible as
"file does not exist" on my second Read attempt). New authored:
`swift-ownership-primitives/AUDIT-0.1.0-release-readiness.md` — work
unstarted, left in place.

## What Worked and What Didn't

**Worked**: The variant-ladder discipline produced a clean signal at
V3, and once V12 compiled + all four test suites passed, confidence
was high. The supervisor's LAND WITH CHANGES verdict was catchable —
three of four amendments were factual (test label, empirical narrowing,
self-contradiction) and one was verification-extending
(heavy-consumer sweep). Re-verify-after-amendment per [REFL-006] caught
the stale-cache pattern supervisor flagged: heap and vector linker
errors on first try resolved after `rm -rf .build && swift test`. V2.5
narrowing took ~15 minutes and upgraded a speculative Findings line
into an empirically-anchored one.

**Didn't work**: V1→V2→V3 jump skipped the incremental-construction
step per [EXP-004a]. The handoff's Scope said "V1–V3: establish the
failure" but did not enforce "add one feature at a time"; I jumped
from parallel types directly to real `Buffer<Element>.Ring`, which
proved the bug reproducible but left the structural factor unidentified.
The supervisor had to prompt the reduction. Confidence in the Findings
section's speculative "something specific about class reference or
conditional-Copyable-via-extension" was LOW — I wrote it anyway without
flagging it as an Open Question, which is exactly the kind of shallow
analysis [REFL-006] warns against. V2.5 closed the gap retroactively.

Also didn't work: the handoff's probe list (remove `@_lifetime` from
`Property.View.Typed.base`) and Do-Not-Touch list
(property-primitives) self-contradicted on candidate-3. I followed
Do-Not-Touch (correct) but did not flag the contradiction in my
Findings. The supervisor caught it. A reader of just the Findings would
have concluded I missed the probe.

## Patterns and Root Causes

**Pattern A — reduction-ladder shortcuts trade time-now for evidence-depth-later**:
[EXP-004a] ("add complexity one feature at a time") is load-bearing for
isolating structural triggers. Jumping from V2 (parallel) to V3
(full real dependency graph) proves reproducibility but not
identity-of-cause. The cost is paid in the Findings section: either
the author speculates (my first draft) or flags an Open Question
(what I should have done). The supervisor's cost to catch this was
one grep + one question; my cost to fix it was ~15 minutes of V2.5
reduction. So the ladder shortcut costs ~15 minutes + one round-trip of
supervisor time. Not huge, but compounding across many investigations.
The empirical fix (V2.5a vs V2.5b) would have been obvious as a
distinct hypothesis at V2's non-reproduction — the framing "V2 didn't
reproduce, so something about V3's real type triggers it" IS a
hypothesis; the question "which factor?" has more discriminations than
one leap can test. This matches [EXP-011a] ("first clean signal is the
result; subsequent variants must test a different hypothesis") but
also its converse: when a variant's signal is "could-not-reproduce",
the *next* variant must incrementally add ONE factor, not many.

**Pattern B — self-contradicting handoffs need flagged, not silently
respected**: The parent's handoff said property-primitives = Do Not
Touch AND listed "remove `@_lifetime(borrow self)` from
`Property.View.Typed.base`" as a probe candidate. Following one list
meant violating the other. I picked Do-Not-Touch (correct call) but
did not flag the contradiction in Findings. A reader of just my
Findings would have thought I missed the probe; the supervisor caught
it and explicitly labeled it a handoff defect. The learning is not
"be more careful" but rather "when an instruction contradicts a
constraint, the flagged contradiction IS part of the output" — it
belongs in Findings with the same weight as probe results, not invisible.

**Pattern C — the endemic stale-cache linker error is a workspace
hazard, not a V12 regression**: heap, vector, and dictionary all
failed `swift test` on first run with `error: fatalError` at the
linker stage. Clean `rm -rf .build && swift test` fixed all three.
This is not a V12 side-effect — the supervisor hypothesized it; I
verified it; the 392 tests that did pass in buffer-primitives did so
without a clean rebuild, so the pattern is specific to the swift-test
runner's intermediate caches across some subset of packages. Worth
noting in package-insights so future investigators don't waste time
treating linker errors as signal.

## Action Items

- [ ] **[skill]** experiment-process: add a requirement that when a
  variant shows "could-not-reproduce" and the next variant is intended
  to find the trigger, the next variant MUST add exactly one new
  structural factor from the candidate set — not a leap to the full
  real dependency graph. Reinforces [EXP-004a] "add complexity one
  feature at a time" at the specific reduction-to-trigger-narrowing
  boundary, where the rule is most often violated.

- [ ] **[skill]** handoff: add a requirement that when a handoff's
  probe list or scope asks the subordinate to touch files that appear
  on its Do Not Touch list, the subordinate MUST flag the contradiction
  explicitly in Findings (labeled as a handoff defect), rather than
  silently following Do-Not-Touch and leaving the unrun probe absent.
  Cross-references the existing [HANDOFF-016] staleness axes — this is
  a sixth axis: internal-contradiction staleness.

- [ ] **[package]** swift-primitives: note in `Research/_Package-Insights.md`
  that `swift test` linker errors (`error: fatalError` at the link
  step) in heap/vector/dictionary are typically stale-cache artifacts,
  not regressions; `rm -rf .build && swift test` clears them.
  Prevents future investigations from mis-attributing such errors to
  recent primitive-level changes.
