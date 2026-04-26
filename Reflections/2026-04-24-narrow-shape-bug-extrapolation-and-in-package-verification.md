---
date: 2026-04-24
session_objective: Continue HANDOFF-ownership-borrow-release-miscompile — review parallel agent's integration work, sweep for sibling landmines, decide ship/hold for the miscompile-affected packages
packages:
  - swift-ownership-primitives
  - swift-property-primitives
  - swift-memory-primitives
  - swift-buffer-primitives
  - swift-async-primitives
  - swift-institute/Experiments
  - swift-institute/Audits
status: processed
processed_date: 2026-04-26
triage_outcomes:
  - type: skill_update
    target: issue-investigation
    description: "[ISSUE-025] In-Package Verification of Synthetic-Reproducer Claims — extends [ISSUE-013] variable-isolation discipline through to production-shape verification"
  - type: skill_update
    target: audit
    description: "[AUDIT-027] Shipping HOLD Evidence Bar — severity-graded evidence requirement; CRITICAL/HIGH HOLD on production code requires in-package failing release-mode test, not just synthetic reproducer"
  - type: no_action
    description: V13 deferred experiment paired with audit action A2 (upstream compiler-issue filing). A2 authorization gates V13 execution; the deferral is documented in the parent audit (borrow-pointer-storage-release-miscompile.md) and informs the new research doc (withUnsafe-borrowing-noncopyable-pattern-reach-survey.md).
---

# Narrow-shape bug extrapolation and in-package verification

## What Happened

Resumed `HANDOFF-ownership-borrow-release-miscompile.md` to continue the swift-ownership-primitives + swift-property-primitives 0.1.0 shipping arc. Session scope expanded beyond the original handoff.

1. **Reviewed the parallel agent's integration work** — the `@inlinable` removal from `Ownership.Borrow.init(borrowing: ~Copyable)` (commit `ece5d7e`) and the restore of `Property.View._storage` to `Tagged<Tag, Ownership.*<Base>>` (commit `a597340`). Spotted that `Property.View.@unsafe init(_ base: borrowing Base)` was still `@inlinable` with the same bug pattern; agent added the fix + a cross-module release test (`764db07`, 46/48 → 48/48).

2. **Swept sibling landmines**. Property.View.Typed family (3 variants + 2 Read variants) clean. Ecosystem grep across swift-primitives, swift-standards, swift-foundations identified one candidate: `Memory.Inline.pointer(at:)` in swift-memory-primitives, with ~20 cross-module consumer sites in swift-buffer-primitives and swift-async-primitives. False-positive detection caught Async.Mutex (`@usableFromInline` not `@inlinable`), Buffer.Arena iteration (pointer scope-bounded), Windows.Kernel.Glob (inout).

3. **Built a multi-target experiment** — `V10FieldOfSelfLib` library target + `V10`/`V11` variants in the experiment main (commit `cee7a7a`). V10 (`@inlinable` + `withUnsafePointer(to: self._storage)` + ~Copyable container) crashed SIGTRAP cross-module. V11 (same shape, non-`@inlinable`) reported divergent stack addresses (8 bytes apart) with garbage dereferences. Concluded the field-of-self shape is a real miscompile and the non-`@inlinable` workaround does not rescue it.

4. **Drafted Finding #12 as HIGH with shipping HOLD** on swift-memory-primitives + swift-buffer-primitives + swift-async-primitives. A2 upgraded to BLOCKING. Committed as `218ebcc`.

5. **User correction on methodology**: before any source change, write failing release tests in each affected package as regression guards (wrapped in `withKnownIssue` so CI stays green). The correction reordered: regression guard first, fix second.

6. **Wrote the in-package tests — all three PASSED in release**. Memory.Inline's production shape (`@_rawLayout`-backed `_storage`, generic over Element, stride-advance arithmetic) does NOT exhibit the V11 failure. The `withKnownIssue` wrappers reported "Known issue was not recorded" (expected failure, got pass). Production code empirically safe. Finding #12 was an overclaim extrapolating from a synthetic reproducer.

7. **Corrected the audit** (`64f8362`) — Finding #12 rewritten from HIGH/HOLD to LOW/watchflag; shipping scope reverted to NORMAL; A2 downgraded from BLOCKING to "worth filing on principle"; V13 flagged as deferred-paired-with-A2. The three tests were converted from `withKnownIssue` to positive-assertion regression guards and committed separately: swift-memory-primitives `e390d7a`, swift-buffer-primitives `92e53fe`, swift-async-primitives `26e76e1`.

**Session commits (6)**: `cee7a7a` (experiment V10/V11), `218ebcc` (audit upgrade — later corrected), `e390d7a` + `92e53fe` + `26e76e1` (regression guards), `64f8362` (audit correction). All local. Nothing pushed. No upstream filing.

**HANDOFF scan** (per [REFL-009]): one in-authority file — `HANDOFF-ownership-borrow-release-miscompile.md`. Status on remaining Next Steps changed during session (A2 downgraded, finding #12 inverted, regression guards landed); annotated in place and left for the next session. The 17 other HANDOFF-*.md files at Developer/ root are from parallel workstreams and out of this session's cleanup authority. Audit finding cleanup (per [REFL-010]) folded into the session's audit correction commit `64f8362` — no separate cleanup pass needed.

## What Worked and What Didn't

**Worked**:
- Rigorous review of the parallel agent's work caught a sibling landmine (Property.View's `@unsafe init` was still `@inlinable`). Didn't rubber-stamp the "integration complete" claim.
- Ecosystem-wide grep with correct false-positive classification — 25+ raw matches reduced to one genuine suspect.
- Commit-per-checkpoint discipline: experiment, regression guards, audit each as separate forward commits with clear scope. Made the correction trajectory visible in the log rather than amended away.
- Test-first methodology (once corrected by the user) produced an unambiguous binary signal. Tests pass or they don't; no room for extrapolation.

**Didn't work**:
- **Finding #12 overclaim**. V11 reproduced a bug in a synthetic shape. I jumped to "Memory.Inline.pointer(at:) is therefore broken in production" without running a production-shape test. The draft Finding #12 used "shipping on stale-bits luck" framing, recommended a HOLD on three packages, and upgraded A2 to BLOCKING — all on experimental extrapolation. Had to be reverted.
- V12 coroutine spike was launched without a compile check — triggered a distinct swift-frontend crash (`GenericSpecializationMangler`, separate upstream bug). Wasted ~10 minutes.
- Shell `cwd` drift during multi-repo work. Repeatedly ran `swift test` in the wrong package directory because shell sessions carry `cwd` across commands. Symptom: empty filter results, tests in the wrong repo. Cost minutes each time.
- Early confidence on "cross-module function-call boundary is the universal workaround." Correct for borrowing-parameter shape (finding #2, empirically validated via property-primitives). Wrong for field-of-self shape (V11). The audit initially framed it as a general rule; user's test-first correction exposed the gap.

## Patterns and Root Causes

**Synthetic-reproducer-to-production-extrapolation gap**. The canonical compiler-bug narrowing workflow reduces the failing shape to a minimum. Some stripped features are incidental (test harness, imports). Some are load-bearing discriminators (`@_rawLayout`, generic specialization, stride arithmetic). The reproducer proves the bug exists in the reduced shape; it does NOT prove the bug exists in shapes where the stripped features could be structural discriminators. Extrapolating from "V11 fails" to "production consumers fail" is a type error: the cascade must be verified, not assumed. `[ISSUE-013]` variable-isolation methodology was designed for this — but it stopped at "narrow the reproducer" and didn't push through to "verify in the production shape." The in-package release test is the missing step: running it either reveals the cascade (extrapolation was sound) or refutes it (discriminator was load-bearing and the narrow bug is narrow). Both outcomes are informative; skipping the step forecloses the distinction.

**Two-instance framing with different workaround responses**. Framing V1 and V11 as "same root class, different instances" was accurate at the `Builtin.addressOfBorrow` level but misleading in practice. The workaround response is structurally different: V1's borrowing-parameter shape is rescued by non-`@inlinable` (the cross-module ABI preserves `@in_guaranteed`), V11's field-of-self shape is not (per-call borrow-locals materialize inside the callee regardless of the boundary). When the workaround response differs, the instances should be classified separately for triage — even if they share a compiler-internal cause. This is adjacent to `[HANDOFF-016]` premise staleness: "same as earlier" drifts into false equivalence when the comparison is carried from one context to another without re-deriving the implications.

**Test-first methodology as epistemic discipline, not just ordering**. The user's correction read as procedural ("write tests before source changes") but was epistemic. A failing test in the production package forces the agent to construct the production shape — which exposes whether the extrapolation holds. Without that step, the agent writes an audit claim based on extrapolation, the claim ships as durable doctrine, and only a future session or reviewer challenges it. Test-first is a forcing function: it demands converting "this probably applies" into "this does apply — here is the failing test." If the failing test can't be written, the extrapolation is unverified. Generalizes beyond this session — any shipping decision grounded in "the bug we found in X must affect Y" needs the in-Y test before the decision lands.

**Commits as checkpoint ratchet in an evolving-understanding session**. Understanding of Finding #12 changed three times (HIGH/HOLD → LOW/watchflag after in-package tests → positive-assertion guards after the user's direction). Each state was a separate forward commit, not an amend. A future reader walking the log sees the actual trajectory including the overclaim and the correction. That's load-bearing history — the overclaim moment is exactly where a future agent might learn the methodology lesson. Amending would have erased it.

**Shell `cwd` drift as tool-hygiene tax**. Not deep, but costly across the session. In multi-repo work, bash sessions inherit `cwd` from the last `cd` in the last chain; subsequent tool calls land in whatever repo was current. Prefixing commands with `cd {absolute-path} && {cmd}` avoids the drift. Free micro-habit worth internalizing.

## Action Items

- [ ] **[skill]** `issue-investigation`: add requirement under `[ISSUE-013]` (Variable Isolation) — "synthetic-to-production extrapolation requires in-package verification." When reducing a compiler bug, structural features stripped away (generic specialization, `@_rawLayout`, stride arithmetic, etc.) may be load-bearing discriminators. Before concluding the reduced-shape bug cascades into production consumers, write an in-package test that exercises the production shape and observe the outcome. Without this step, the cascade claim is unverified — the reduced reproducer proves the bug exists in the reduced shape only. (Provenance: this session's Finding #12 inversion.)
- [ ] **[skill]** `audit`: add requirement — "shipping HOLD decisions require in-package empirical evidence, not experimental extrapolation." When an audit proposes holding a shipping package pending an upstream fix, the evidence MUST include a failing in-package release-mode test, not just a synthetic reproducer failure. Shipping-scope implications demand the higher evidence bar. (Provenance: Finding #12 proposed HOLD based on V10/V11 experiment; in-package tests inverted the finding.)
- [ ] **[experiment]** V13, deferred, paired with audit action A2. When A2 is authorized, run V13 first: extend `swift-institute/Experiments/borrow-pointer-storage-release-miscompile` with a variant that isolates which of `@_rawLayout` / generic-Element / stride-advance-arithmetic is the structural discriminator protecting `Memory.Inline.pointer(at:)` from the V11 failure mode. V13's output makes the upstream bug report shape-precise.
