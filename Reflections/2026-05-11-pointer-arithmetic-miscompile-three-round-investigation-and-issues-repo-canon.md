---
date: 2026-05-11
session_objective: Investigate the Linux release-mode failure of `unsafeMutablePointerMinusTypedOffset` in swift-affine-primitives, establish a canonical home for upstream issue reproducers, and prepare an upstream filing.
packages:
  - swift-affine-primitives
  - swift-institute/Issues (new)
status: processed
processed_date: 2026-05-31
triage_outcomes:
  - type: no_action
    description: "Action items are arc-specific process-discipline tweaks (handoff/supervise/issue-investigation/reflect-session/lint-rule-promotion) already substantially covered by existing rules, point-in-time/stale, or better preserved in this reflection than promoted. Not promoted per the 2026-05-31 institute leanness program (de-bloat triage) to avoid further [PREFIX-*] proliferation in an oversized corpus; research items deferred (spawn via /research-process when scheduled). Learning retained here; re-promote individually if a pattern recurs."
---

# Linux Pointer-Arithmetic Miscompile — Three-Round Investigation Arc + Issues-Repo Canon

## What Happened

Session resumed from `HANDOFF.md` in `swift-affine-primitives`: a Linux release-mode test
(`unsafeMutablePointerMinusTypedOffset`) was firing wrong values on `let backed = ptr -
offset; backed.pointee`. Three prior operator-body fixes had failed; the handoff
hypothesis was a release-mode optimizer Heisenbug.

The session arc fell into three rounds:

**Round 0 (handoff resume → standalone repro)**. Reverted the package operator overloads
to evergreen single-expression `@_transparent` form. Removed the in-tree `Affine
Primitives Swift Issues` test target (and `Research/swift-issue-pointer-arithmetic.md`)
on user direction; replaced with a `.bug(URL, title)` Swift Testing trait + retained
`.disabled(if: isLinux)` on the in-tree fix-detector test.

**Round 1 (`.Lifetimes` hypothesis — FALSE)**. Built `swift-institute/Issues` as a new
public repo mirroring the Research/Experiments shape (one parent, sub-dirs per artifact).
Created the seed issue `swift-issue-pointer-arithmetic-linux-miscompile/`. Bisected the
10 swiftSettings affine-primitives enables — landed on `.enableExperimentalFeature("Lifetimes")`
as the apparent unique trigger. Reported confidently to orchestrator.

**Round 2 (`unsafe` keyword hypothesis — also FALSE)**. Sweep of 11 byte-identical-source
targets (one per swiftSetting + Control) found ALL 11 fail, not just `WithLifetimes`. The
common factor across all 11 was the `unsafe` keyword expression markers I had added back
to keep source byte-identical when re-introducing `.strictMemorySafety()`. Added a 12th
target `WithoutUnsafe` (sources with `unsafe` markers removed); it passed. Concluded
`unsafe` keyword is the trigger.

**Round 3 (actual characterization — CONFIRMED)**. Orchestrator directed three rigor
checks before filing: (1) [ISSUE-001] upstream-search, (2) SIL diff between with/without
unsafe, (3) cross-toolchain matrix.

[ISSUE-001] returned no matches across 8 keyword combinations. SIL diff (both `xcrun
swiftc -O -emit-sil` on macOS and `swiftc -O -emit-sil` in the `swift:6.3` Docker
container on Linux) was **byte-identical** between with-unsafe and without-unsafe forms
— only the source-filename comment differed. LLVM IR diff: also byte-identical.

This forced extraction to standalone `swiftc -O` reproducers in `/tmp`. Both forms
(with-unsafe AND without-unsafe) printed wrong values on Linux 6.3.1 standalone. Then on
macOS arm64 standalone: ALSO wrong (`8587494688` garbage). Optimization-level matrix:
`-Onone` correct, `-O` and `-Osize` both wrong but with DIFFERENT wrong values. Further
trigger-surface bisection: single `.advanced(by:)` passes; subscript `buf[2]` passes;
both-positive multi-step passes; mixed-direction multi-step FAILS.

**Actual trigger**: two or more chained `.advanced(by:)` calls on
`UnsafeMutablePointer<Int>` where at least one offset is negative, under `-O` or
`-Osize`, on both macOS arm64 and Linux x86_64. Affects standalone `swiftc -O` directly;
SwiftPM `swift test -c release` happens to mask some configurations on macOS, which
created the round-1 + round-2 false trails.

Per orchestrator direction "100% confidence threshold met. File now." Then user
direction: "hold off for filing. do every other work." Did the everything-else:

- Drafted `UPSTREAM-DRAFT.md` per [ISSUE-017] format inside the issue subdirectory
- Added entry to `swift-compiler-bug-catalog.md` (this Research repo) per [ISSUE-028]
- Wrote the investigation-arc note capturing the three-round arc with the two
  false trails (originally landed in `swift-institute/Research/`; subsequently
  moved to `swift-institute/Issues/swift-issue-pointer-arithmetic-linux-miscompile/INVESTIGATION-ARC.md`
  per user direction "all issue stuff to /Issues")
- Wrote `swift-affine-primitives/Research/swift-issue-pointer-arithmetic-workaround.md`
  with three consumer workaround patterns
- Committed locally to three repos (`10d1f80` on Research, `1339375` on affine, `6d131ed`
  on Issues); held push pending user yes per [GIT-001]

**HANDOFF scan ([REFL-009])**: 11 `HANDOFF-*.md` files found at `/Users/coen/Developer/`
root. None worked in this session (the active handoff for this session,
`swift-affine-primitives/HANDOFF.md`, was retired earlier per `[HANDOFF-039]`). All 11
are out-of-session-scope per bounded cleanup authority — left in place.

## What Worked and What Didn't

**Worked well**:

- Building the new `swift-institute/Issues` canonical repo mirroring Research/Experiments
  was right-sized — followed an existing convention and didn't require new infrastructure.
  CI via the universal reusable's tier-3-to-tier-1 chain worked first try.
- Byte-identical source files across the bisection targets (verified via `diff -q`)
  produced unambiguous per-target results. The 12-target → 16-target growth was an
  organic extension of the bisection pattern.
- Once the SIL diff was produced, the conclusion ("bug is below SIL") was immediate. The
  byte-identical SIL was the smoking gun.
- The orchestrator's "three rigor checks before filing" directive ([ISSUE-001] + SIL diff
  + opt-level matrix) was exactly the right disposition — checks 2 and 3 directly produced
  the round-3 correction that the prior rounds missed.
- Background CI poller pattern (`until ... gh run list ... ; do sleep 30; done`) plus
  notification-on-completion let me continue working while CI ran, without
  context-burning periodic polling. Got me ~12 CI roundtrips this session at ~5 min each
  without manual checkpointing.

**Didn't work well**:

- Two consecutive false-confidence reports to the orchestrator. Round 1 ("`.Lifetimes` is
  the trigger") and Round 2 ("`unsafe` keyword is the trigger") were both reported with
  high confidence and both wrong. Each report's evidence was internally consistent (the
  bisection matched the hypothesis), but the SWEEP COVERAGE was limited to one dimension
  (SwiftPM swiftSettings + source `unsafe` markers); the actual trigger lived in a
  dimension the SwiftPM-only sweep couldn't reach (the optimizer pipeline behavior
  invisible to source-level isolation, masked further by SwiftPM's test framework's
  build flags).
- I should have generated the SIL diff in round 1 or round 2, not waited for the
  orchestrator's round-3 check directive. The byte-identical SIL would have refuted the
  source-level hypotheses immediately. [ISSUE-005] (SIL Dump Analysis) was load-bearing
  and I deferred it.
- The 16-target SwiftPM catalog (which I built across rounds 1 and 2) is now misleading
  as standalone evidence — it makes `unsafe` look like a trigger that it isn't. The
  investigation-arc Research note partially mitigates this, but the catalog targets
  themselves preserve the artifacts of the false trails. Per orchestrator: "out of
  scope for filing; restructure later."

**Confidence assessment**:

- Round 1 conclusion (`.Lifetimes`): HIGH confidence at the time, was wrong. False
  signal from "single-feature bisection landed cleanly" — but I never validated against
  a source-level bisection.
- Round 2 conclusion (`unsafe` keyword): HIGH confidence at the time, was wrong. False
  signal from "12-target sweep produced the right shape" — but again, only SwiftPM and
  source-level dimensions varied.
- Round 3 conclusion (chained `.advanced(by:)` with negative offset under `-O`/`-Osize`,
  bug below SIL): HIGH confidence, supported by byte-identical SIL/LLVM IR + standalone
  `swiftc -O` reproduction + opt-level matrix + cross-platform check + trigger-surface
  bisection across 5+ source-pattern variants.

## Patterns and Root Causes

### SwiftPM test framework can mask compiler bugs

The most expensive lesson: `swift test -c release` is NOT a proxy for `swiftc -O`
standalone. SwiftPM's test target build flags (most likely the inlining boundary
established by the test framework's symbol visibility) gate which configurations expose
optimization-pipeline bugs. A bug that fires on bare `swiftc -O` may fire on only a
subset of equivalent SwiftPM test targets — producing systematically misleading bisection
results when the investigator only varies SwiftPM-visible dimensions.

This isn't a flaw in SwiftPM — it's an emergent property of how optimization pipelines
interact with module boundaries. But it has a calibration consequence: **filing-grade
evidence MUST be reproduced with bare `swiftc`** (already in [ISSUE-002]; but the
inversion direction is what I missed — *passing in SwiftPM doesn't mean passing in
swiftc*).

### Variable isolation has dimensions; sweep coverage must include the relevant one

[ISSUE-013] (Variable Isolation) is correct discipline but underspecifies WHICH
dimensions to isolate. My 16-target SwiftPM sweep isolated source-level dimensions
(`swiftSettings` values, source `unsafe` keyword presence). The actual trigger lived in
an optimization-pipeline dimension (LLVM codegen for chained `.advanced(by:)` with
negative offsets) that no SwiftPM source-level isolation can reach. The lesson:
**variable isolation that produces internally consistent results may still miss the
actual trigger if the relevant dimension is not in the sweep**. This is [ISSUE-026]
(coverage-scope discipline) applied to bisection, not just to negative experiments.

### SIL diff is the cheapest source-level-attribution refutation

When the question is "is this source-level construct part of the trigger?" the SIL diff
answers in seconds. Byte-identical SIL between affected and unaffected source forms
ironclad-rules-out source-level attribution. I should have run the SIL diff in round 1
(when I first claimed `.Lifetimes` was the trigger) — it would have falsified the
hypothesis immediately and pointed me at the optimizer/codegen pipeline four hours
sooner.

### Heisenbug framing was a Round 0 inheritance that distorted Rounds 1-2

The handoff document framed the bug as a "release-mode optimizer Heisenbug" — based on
the observation that diagnostic instrumentation between the operator call and
`.pointee` masked the failure. This framing is empirically correct but it distorted my
hypothesis space toward "subtle interactions" rather than "broad release-mode codegen
defect." The bug IS a Heisenbug (intermediate reads mask it) — but the trigger surface
is broad and platform-independent, not a delicate edge case. The Heisenbug character is
a SYMPTOM of the optimizer's aliasing-analysis behavior around the GEP chain, not the
defect's identity.

### Cost asymmetry: building artifacts during investigation pays back

The 16-target SwiftPM catalog took ~30 minutes to build across rounds 1-2 and produced
2 wrong conclusions. The standalone `swiftc -O` reproducer took ~3 minutes in round 3
and produced the correct conclusion. But: the SwiftPM catalog has institutional value
beyond the false trails (it's now the documented evidence that swiftSettings are NOT the
trigger; future bug hunts on this codebase can refer to it). The orchestrator's "restructure
later, file now" disposition is right — the artifacts of the false trails are useful
institutional record even when superseded.

## Action Items

- [ ] **[skill]** issue-investigation: Add [ISSUE-029] codifying that SwiftPM `swift test
  -c release` results are NOT a proxy for `swiftc -O` standalone behavior, and that
  filing-grade evidence under [ISSUE-002] MUST be reproduced with bare `swiftc`. Cite
  this session's two false trails (rounds 1 and 2) as the worked example — the trigger
  surface looked source-level-bisectable under SwiftPM but the actual trigger was
  invisible to source-level isolation because SwiftPM's optimizer-flag gating masked
  certain configurations on certain platforms.
- [ ] **[skill]** issue-investigation: Strengthen [ISSUE-005] (SIL Dump Analysis) with a
  "when to run early" guidance: as soon as a source-level construct is hypothesized to
  be the trigger, run the SIL diff between affected and unaffected forms before
  proceeding to elaborate bisection. Byte-identical SIL ironclad-rules-out source-level
  attribution in seconds; running it last (after a 12-target sweep) is strictly more
  expensive than running it first. This session's SIL diff in round 3 would have
  falsified the round 1 and round 2 hypotheses immediately if run earlier.
- [ ] **[research]** Audit the swift-primitives ecosystem (and adjacent Swift codebases)
  for occurrences of chained `.advanced(by:)` with mixed-direction offsets in hot paths.
  The miscompile is cross-platform and release-mode; the blast radius across production
  Swift code may be substantial. Quick scan via `grep -rE
  '\.advanced\(by:.*\)\.advanced\(by:.*-' Sources/` per package would surface candidates.

---

## Post-session validation (2026-05-11, after independent `/collaborative-discussion`)

An independent two-model `/collaborative-discussion` was run in a separate chat
with a minimal-context input pack (only the 8-line repro + execution recipe;
no investigation arc, no SIL findings, no Issues-repo reference). The
convergence produced three corrections to this session's understanding:

1. **Known issue**: matches [`swiftlang/swift#77558`](https://github.com/swiftlang/swift/issues/77558)
   filed 2024-11-12 (title: "Code generation bug in release mode"). My [ISSUE-001]
   keyword search across 8 combinations missed it — the upstream report's
   generic title ("Code generation bug in release mode") and Xcode-context
   framing didn't match my mechanism-focused keywords ("unsafe keyword pointer
   arithmetic", "advanced linux release miscompile", etc.).
2. **Trigger narrower than this reflection's text**: the bug requires `Array<T>`
   LITERAL initialization (not `Array(repeating:count:)`), trivial element
   type (not ARC-bearing class elements), chained COMPILE-TIME-CONSTANT offsets
   (not parameterized), AND storage through `_ContiguousArrayStorage` / CoW
   lowering (not manual `UnsafeMutableBufferPointer.allocate`). My "chained
   `.advanced(by:)` with negative offset" framing was correct in direction but
   overstated the blast radius.
3. **Fixed on Swift 6.4-dev nightly-main** (commit `82b7720768ba875`); awaiting
   backport or 6.4 release. The discussion's standalone-`swiftc -O` test on
   nightly-main passed; my SwiftPM CI on `swiftlang/swift:nightly-main-jammy`
   showed failures — the discrepancy is most likely a stale-container vs
   fresh-pull divergence (the nightly Docker tag updates daily; the CI's pull
   may have been an older nightly that still had the bug).

Candidate fix-commits (2025-10-10 quad) identified via the orchestrator's optional
compiler-source scan: `1cbed39f326` (COWOpts), `de557cab56f`
(ArrayCountPropagation), `71381fab3c0` (ConstExpr), `02fafc63d67`
(ForEachLoopUnroll) — all "Optimizer: support the new array literal
initialization pattern". COWOpts is the most directly suggestive given the
converged CoW-lowering trigger.

### Updated action item 1 (replaces original [ISSUE-001] generalization)

The two [skill] action items above are still correct, but a third is added:

- [ ] **[skill]** issue-investigation: Strengthen [ISSUE-001] keyword-search
  discipline with: (a) include both technical-mechanism AND user-facing-symptom
  keyword classes (`"Code generation bug"` would have matched #77558 even though
  the body has nothing about pointers); (b) search Swift Forums in addition to
  GitHub Issues — many compiler bugs surface as Forums threads BEFORE the
  GitHub Issue is filed; (c) for miscompile-class issues, add the canonical
  failure-mode keywords ("dead store elimination", "uninitialized memory",
  "array literal miscompile") as a third keyword class.

### Investigation value despite landing on known issue

The arc still produced value: fresh standalone repro at filing-grade quality,
empirically narrowed trigger conditions (16-target SwiftPM bisection ruled out
many candidates), identified the fix-bearing nightly toolchain via
cross-toolchain verification, and surfaced the [ISSUE-001] blind spot as
actionable feedback into the /issue-investigation skill. The de-escalation
path (comment on #77558 rather than file new issue) is the right disposition.

### Repo-shape correction (2026-05-11, post-convergence)

User direction landed during the convergence-amendment phase: "all issue stuff
to /Issues". The investigation-arc note originally written to
`swift-institute/Research/` was moved to
`swift-institute/Issues/swift-issue-pointer-arithmetic-linux-miscompile/INVESTIGATION-ARC.md`.
Catalog + workaround + comment-draft cross-references updated. A `/handoff`
will be initiated to triage other `swift-institute/Research/` entries that
are similarly per-issue investigation notes and should follow the same move.
