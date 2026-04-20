---
date: 2026-04-17
session_objective: Re-run the experiment corpus against Swift 6.3.1 to identify regressions or fixes vs documented prior state, and update the canonical fix-status memory.
packages:
  - swift-institute
  - swift-parser-primitives
  - swift-io
status: processed
processed_date: 2026-04-20
triage_outcomes:
  - type: skill_update
    target: experiment-process
    description: [EXP-007a] header anchor requirement; [EXP-002c] placement rule (merged with corpus-completion)
  - type: research_topic
    target: compiler
    description: Upstream status of fix for #85743 CopyPropagation on ~Copyable enum switch consume (deferred to compiler-tracking)
---

# Swift 6.3.1 Experiment Re-Run — Memory Drift, Repo Splits, and the Experiment-Header Convention That Saved Time

## What Happened

Xcode 26.4.1 ships Swift 6.3.1 (`swiftlang-6.3.1.1.2`) as the default toolchain. 6.3.1 is a focused point release: ~30 of its 43 commits are John McCall's stack-nesting work for async runtime builtins (`async-let`, task locals, cancellation/priority-escalation handlers, `swift_task_alloc/dealloc`), introducing a `[non_nested]` SIL flag and teaching the optimizer/IRGen/verifier to honor it. Two AutoDiff cherry-picks (#87959 + #87961) and OpenBSD unversioned triples round it out.

I re-ran ~50 experiments across the swift-institute corpus, picked because they touch what 6.3.1 actually changed: async/concurrency, ~Copyable, CopyPropagation, escapable/lifetime, typed-throws, phantom-type/tagged, witness, and protocol-diamond clusters. Result: zero new regressions, zero new fixes, but several memory claims got falsified.

Concrete actions:
- **Memory rewrite**: `swift-6.3-fix-status.md` rewritten to reflect 6.3.1 empirical state. Three previous claims falsified: (1) #85743 "fix in compiler, waiting on Xcode" — wrong, still crashes on 6.3.1, the upstream fix wasn't in the cherry-pick set; (2) `@_lifetime` rejection on Escapable targets framed as 6.4-dev-only regression — actually present in 6.3.1 too, the tightening landed somewhere in the 6.2.3 → 6.3.0 window; (3) "Xcode still on 6.3" — Xcode is now 6.3.1.
- **3 experiments moved into convention**: `actor-state-{inline-fallback-repro,cross-thread-inline}` from `swift-io/Experiments/` (they test general compiler behavior, not swift-io specifics) and `copytoborrow-actor-state-mutex-miscompile` from a loose `/Users/coen/Developer/swift-copytoborrow-bug-standalone/` directory (now removed). All three landed in `swift-institute/Experiments/`.
- **1 experiment moved out of institute**: `declarative-parser-typed-throws` relocated to `swift-primitives/swift-parser-primitives/Experiments/` because it depends on parser-primitives (not standalone).
- **60 experiments now carry `// Revalidated: Swift 6.3.1 (2026-04-17)` lines**: PASSES / STILL PRESENT / STILL CRASHES as appropriate, anchored after the existing `// Toolchain:` / `// Status:` / `// Revalidation:` lines via awk batch insertion.
- **5 commits across 3 repos**: 2 in `swift-institute/Experiments` (now its own repo post-split), 1 in `swift-foundations/swift-io`, 1 in `swift-primitives/swift-parser-primitives`. Plus an in-place fix to `/Users/coen/Developer/swift-copytoborrow-bug/HANDOFF.md` whose paths I broke when removing the standalone directory.

Mid-session surprise: `swift-institute` was split from a single repo into per-folder repos (`Experiments/`, `Research/`, `Audits/`, etc. each with their own `.git`). My first commit (`82aec17`) survived the split and now lives as `a3fcc7a` in the new `Experiments` repo — discovered when a second `git commit` reported "fatal: not a git repository" until I cd'd one level deeper.

The standalone bug-reproducer directory (`/Users/coen/Developer/swift-copytoborrow-bug-standalone/`) was removed at user request after its content moved into the institute convention. Its 5+ commits of reduction history were local-only (never pushed); the final reduced state is preserved as the experiment.

## What Worked and What Didn't

**Worked**:
- Batch parallel runs via multiple `Bash` tool calls in single messages — covered ~8 experiments per round, completed the high-signal sweep in three batches.
- Awk anchoring on `// Toolchain:` lines for the revalidation-line insertion — clean, idempotent, skipped files where `Swift 6.3.1 (2026-04-17)` already appeared.
- Reading experiment headers BEFORE classifying a build error as a regression. Several experiments are *designed* to fail to compile (`throws-overloading-limitation`, `noncopyable-storage-poisoning`, the conditional-Copyable-Sequence pattern in 4 experiments) and their headers say so explicitly: "Status: CONFIRMED FAILS" or "Revalidated: Swift 6.3 (2026-03-26) — STILL PRESENT". Without reading those, I'd have misreported all of them as regressions.
- Verifying the one candidate regression (`escapable-lazy-sequence-borrowing`) against 6.4-dev before claiming it. 6.4-dev rejected it identically, the experiment header said last validated on 6.2.3 — so the change predates 6.3.1, not a 6.3.1 regression. Saved a misleading bug report.

**Didn't work**:
- First instinct on the CopyToBorrow bug was to rebuild the full swift-io repo in release to test it. User correctly redirected: "if its testing a general thing, and just using swift-io as example, refactor the experiment to be standalone." The experiment infrastructure exists precisely so individual hypotheses can be tested in isolation; building the whole consumer is wasted compute and conflates "consumer code works" with "compiler bug fixed."
- Briefly chased a swiftpm test-runner failure (`dlopen` on the `.xctest` bundle) before realizing it was a swiftpm/test-helper issue unrelated to 6.3.1.
- Initial shell loop using `for exp in $EXPS; do` failed silently in zsh (no word splitting on bare expansion). Cost one round of "0 updated" before switching to the literal list inline.

**Confidence calibration**: I was nearly over-eager to call `escapable-lazy-sequence-borrowing` a 6.3.1 regression. The compiler error matched a memory entry that said "6.4-dev only." My instinct was to write up the regression. The 6.4-dev cross-check was the right discipline — but I almost skipped it.

## Patterns and Root Causes

**Memory drift after compiler releases.** The `swift-6.3-fix-status.md` memory was 2 days old at session start with a system-reminder warning "verify against current code before asserting as fact." Three of its claims were wrong by the time I tested: a fix-status, a regression-classification, and an Xcode-version note. The pattern: status memories about "what's fixed/broken in compiler version X" do not age gracefully across compiler releases — but there is no automated trigger that says "compiler version changed, revisit X." The memory's age-warning fires on individual access, not on context-shift events like "Xcode just updated." This is a known limitation but it bit measurably this session: I would have made wrong recommendations if I'd trusted the memory without the empirical re-run.

**Experiment-header convention as time multiplier.** The experiments that had `// Revalidated: Swift 6.3 (2026-03-26) — STILL PRESENT` headers were trivial to triage (matched expected output → append a 6.3.1 line). The experiments without such headers (e.g., `escapable-protocol-cross-module`, `tagged-string-crossmodule`) required reading the body to understand intent, and the awk insertion had no anchor to bind to. The pattern: the header IS the experiment's interface to future revalidation. An experiment without a Toolchain/Status/Result line is opaque to anyone but its author, and even then only briefly. Corollary: the next iteration of `experiment-process` should *require* a header anchor on every experiment.

**Co-location follows dependency, not topic.** `actor-state-inline-fallback-repro` lived under `swift-io/Experiments/` because it was created during a swift-io investigation, but it tests general behavior (custom executor + actor state visibility). Moving it to `swift-institute/Experiments/` made it discoverable to future re-runs. Conversely `declarative-parser-typed-throws` lived under `swift-institute/Experiments/` but depends on `swift-parser-primitives`, so it had to move to that package's Experiments dir. The rule isn't "what topic does this test?" — it's "what does this depend on?" Standalone (compiler-only) → institute. Depends on package P → P/Experiments.

**The repo split caught me out.** `swift-institute` was reorganized mid-session into per-folder repos. The system-reminder about CLAUDE.md modification was the only signal, and it was easy to miss the implication. I made a `git commit` against the wrong directory level and got "fatal: not a git repository" before I noticed. Pattern: workspace structure changes are infrequent enough that I don't proactively re-discover layout each session; when they happen, they cost a confused minute. This isn't fixable by skill changes — it's just a thing to watch when CLAUDE.md changes mid-session.

## Action Items

- [ ] **[skill]** experiment-process: Require a header anchor on every experiment with one of `// Toolchain:`, `// Status:`, or `// Revalidated:` so compiler-version revalidation sweeps can mechanically append `// Revalidated: Swift X.Y.Z (date) — STATUS` lines without per-file inspection. ~15 experiments hit this session lacked any anchor and had to be inspected individually or skipped.
- [ ] **[skill]** experiment-process: Codify the placement rule — experiments depending on a package P MUST live in `P/Experiments/`, not in `swift-institute/Experiments/`. The latter is reserved for experiments testing general compiler/runtime behavior with no package dependencies. Cite the swift-io and parser-primitives moves from this session as concrete examples.
- [ ] **[research]** Verify whether the upstream fix for #85743 (CopyPropagation MoveOnlyChecker crash on ~Copyable enum switch consume) actually exists in `swiftlang/swift` main, and if so why it was excluded from the 6.3.1 cherry-pick set. The previous memory's claim that the fix was "in compiler, waiting on Xcode" was empirically false on 6.3.1; either the fix never landed, or it landed but wasn't deemed cherry-pickable. The answer determines whether to expect a fix in 6.3.2 / 6.4 or whether the bug report needs renewed attention.
