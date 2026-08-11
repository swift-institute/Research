---
date: 2026-04-17
session_objective: Run /audit on the v1-execution session commits in swift-executors against /code-surface, /implementation, /modularization; remediate landed findings.
packages:
  - swift-executors
  - swift-executor-primitives
  - swift-cpu-primitives
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Audit, Remediation, and the Borrowing-Self Chained-`&&` Discovery

## What Happened

The session was dispatched as a subordinate audit per `/Users/coen/Developer/AUDIT-swift-executors-compliance.md` — a `/supervise`-style brief covering the seven session commits that landed v1 execution decisions (priorityTracking wiring, `CPU.Cache.Padded` adoption for `Sharded.cursor`, FIFO sequencer at L1, XorShift32 random victim selection) plus three benchmark passes. The brief enumerated 9 swift-executors source files, 3 swift-primitives source files, and four test files, with six supervisor ground rules and three named target skills.

I ran the audit per `[AUDIT-006]`, producing three new dated sections in `swift-foundations/swift-executors/Audits/audit.md`:

- **Code Surface — 2026-04-17**: 1 MEDIUM `[API-IMPL-008]` — `Stealing.Worker.swift` class body holds seven methods (`nextRandom`, `start`, `enqueue`, `wake`, `join`, `runLoop`, `trySteal`) instead of placing them in extensions; sibling executor classes (`Sharded`, `Stealing`, `Polling`) all keep methods in extensions. The session commit `7ca7240` added `nextRandom()` to the body, perpetuating a pre-existing pattern that the file-split commit `1529eea` did not normalize when extracting Worker from `Stealing.swift`.
- **Implementation — 2026-04-17**: 1 MEDIUM `[IMPL-002]` — random-victim steal loop in `Worker.runLoop` adds new raw-`Int` arithmetic (`for _ in 0..<(n-1)`, `Int(nextRandom() % UInt32(n))`, `(victim+1) % n`); deferred as a downstream symptom of prior 2026-04-16 finding #4 (Worker.id raw `Int` cascade). 1 LOW `[IMPL-EXPR-001]` — `Executor.Job.Priority.Entry`'s `==` and `<` operators use four single-use intermediate `let` bindings each; the audit recommended replacing with direct `lhs.deadline == rhs.deadline && lhs.sequence == rhs.sequence`.
- **Modularization — 2026-04-17**: 0 findings — the new `swift-cpu-primitives` dependency is well-formed.

Each section was stamped with a `[SUPER-011]` verification line confirming all six supervisor ground rules were respected.

The user then asked to fix the `[API-IMPL-008]` and `[IMPL-EXPR-001]` findings. The Worker refactor moved methods to four grouped extensions (PRNG, Lifecycle, Job Queue, Run Loop) in the same file, preserving `private`/`fileprivate` access through Swift's same-file extension scope. 32/32 swift-executors tests passed.

The Entry simplification did not compile. The naive `lhs.deadline == rhs.deadline && lhs.sequence == rhs.sequence` form was rejected by the Swift 6.3 borrow checker:

```
error: 'rhs' is borrowed and cannot be consumed
   public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
                                                    ^- error
       lhs.deadline == rhs.deadline && lhs.sequence == rhs.sequence
                                       ^- note: consumed here
```

The fix that compiled was tuple comparison: `(lhs.deadline, lhs.sequence) == (rhs.deadline, rhs.sequence)` and the equivalent for `<`. Both swift-executors (32/32) and swift-executor-primitives (6/6 JobPriorityTests) passed after the fix.

I corrected the `[IMPL-EXPR-001]` finding entry in `audit.md` to RESOLVED 2026-04-17 with a note explaining that the audit's stated rationale ("borrowed-self access does not require the bindings; borrowing parameters permit direct property access for Copyable fields") was incorrect for the `&&` form, and that tuple comparison is the form that satisfies both `[IMPL-EXPR-001]` and the borrow checker.

The `[API-IMPL-008]` Worker finding was marked RESOLVED 2026-04-17. The `[IMPL-002]` raw-Int arithmetic finding remains OPEN (deferred pending Chase-Lev redesign per the prior 2026-04-16 reflection).

**Session-artifact triage** (per `[REFL-009]`, `[REFL-010]`):

- `Audits/audit.md` — three new dated sections appended (Code Surface, Implementation, Modularization). Two findings updated to `RESOLVED 2026-04-17` per `[REFL-010]`. One remains OPEN. Pre-existing dated sections unchanged by this session (the working-tree hunks at lines 7, 44, 89 in `git diff` predate the session — `git log Audits/audit.md` shows the file's last commit `1529eea` does not include the four 2026-04-15/04-16 dated sections, so those are uncommitted work from a parent session).
- `/Users/coen/Developer/HANDOFF.md`, `HANDOFF-executor-main-platform-runloop.md`, `HANDOFF-io-completion-migration.md`, `HANDOFF-migration-audit.md`, `HANDOFF-path-decomposition.md`, `HANDOFF-primitive-protocol-audit.md` — none belong to this session; left untouched. They describe parent-session work (e.g., HANDOFF.md is "Advance 4 remaining IN_PROGRESS research notes toward DECISION"). This session has no information about their completion state, so the per-`[REFL-009]` triage outcome is "ambiguous — leave with no annotation."
- `/Users/coen/Developer/AUDIT-swift-executors-compliance.md` — the brief that dispatched this session. All Relevant Files audited, all three skills checked, findings appended with `[SUPER-011]` verification stamps, all six supervisor ground rules respected, no revert-class escalation. The brief has served its purpose; its disposition (delete vs. leave) is a user decision since it functions as the supervisor-in-absentia accountability trail per `[SUPER-014a]` rather than a `HANDOFF-*.md`.

## What Worked and What Didn't

**What worked**:

- The audit itself was sound — it correctly identified the three findings against the right rule IDs and cross-referenced four prior dated sections without duplication.
- The `[SUPER-011]` verification stamps and the brief's six ground rules created a clean accountability trail. No drift; no scope creep into the pre-existing uncommitted modifications I noticed in the file's hunks #1–#3 (those were not my changes — `git log Audits/audit.md` shows the file's last commit `1529eea` predates the four prior dated sections).
- The Worker refactor was uneventful. Swift's same-file extension scope handled `private` `nextRandom`, `private` `runLoop`, and `fileprivate` `trySteal` exactly as the language guarantees. 32/32 tests passed on first build.
- Catching the Entry compile failure happened in the build immediately after the edit, not later — the cost was one extra Edit call.

**What didn't work**:

- The audit's `[IMPL-EXPR-001]` recommendation was wrong about the failure mode. I asserted that direct property access on `borrowing` parameters would compile, justified it with a confident sentence in the finding's "Finding" column, and only discovered the constraint when I applied the fix and built. The audit reader had no signal that the recommended form was unverified.
- I did not test the recommended simplification before landing the audit. The audit is a *recommendation* artifact, but the recommendation is for a 6-line two-method change that takes seconds to compile-test. The cost of validation was negligible relative to the cost of a wrong recommendation reaching the next agent who tries to apply it cold.
- The original verbose form was protective code, not gratuitous mechanism. The four `let` bindings each triggered an isolated borrow-and-copy that the compiler could discharge independently — making the comparison operate on local copies, not on borrowed access. The session author had likely already discovered this (or the form would not exist), but no `// WHY:` comment captured the constraint, so the audit had no signal that the verbose form was intentional. The audit's job is to enforce rules; without provenance comments, it cannot distinguish ceremony from compiler-driven necessity.

## Patterns and Root Causes

**The borrow checker treats chained property access via `&&` as consumption of the second comparand**. Empirically observed today on Swift 6.3 with `borrowing Self` parameters and Copyable stored properties (`ContinuousClock.Instant`, `UInt64`):

| Form | Status | Why |
|------|--------|-----|
| `let l = lhs.deadline; let r = rhs.deadline; ...; return l == r && ...` | Compiles | Each `let` is a discrete borrow-and-copy; the borrow is released after the assignment. The comparison operates on local copies. |
| `lhs.deadline == rhs.deadline && lhs.sequence == rhs.sequence` | Rejected | Chained property access through the short-circuit `&&` requires the borrows on `lhs` and `rhs` to stay live across the boundary. The compiler reports the second access as "consumed here." |
| `(lhs.deadline, lhs.sequence) == (rhs.deadline, rhs.sequence)` | Compiles | Each side collects both fields into a single tuple expression. No short-circuit boundary; the borrows discharge after the tuple is materialized. |

The shape of the rule appears to be: **borrow scopes do not span short-circuit operators when the operator's operands re-access the borrowed value's properties**. Whether this is a hard language semantic or a borrow-checker limitation specific to the `&&` lowering is not yet clear — the Swift 6.4 nightlies might behave differently.

**Pattern**: this is the second time in recent session history that a stylistic simplification on a `borrowing` parameter ran into a non-obvious compiler constraint. The first was `[feedback_noncopyable_sendable_capture]` (`~Copyable` types cannot be captured in `@Sendable` closures). Both belong to the same class — **ownership-discipline rules that look like style violations until you try to fix them**.

**Root cause for the audit miss**: I treated `[IMPL-EXPR-001]` as a pure-style rule and reasoned about the recommended form's correctness from style principles alone. I did not load the constraint that `borrowing Self` parameters interact with expression structure in ways that style rules cannot model. The audit skill ([AUDIT-006] step 5) requires verifying findings against source — but I verified that the *violation* existed in the source (the let bindings were indeed there), not that the *recommended fix* compiled. Verifying the fix is a stronger requirement than the skill currently states.

**Connection to `[REFL-006]` "Re-verify after edit"**: that rule addresses incomplete cleanup passes (grep-then-edit-some). The pattern here is the inverse — the *recommendation* needed verification before the audit landed, not after the edits. Same family of failure (insufficient verification at the right moment) but different sub-pattern.

## Action Items

- [ ] **[skill]** implementation: Add a caveat to `[IMPL-EXPR-001]` noting that on operator overloads with `borrowing Self` parameters, simplifications must keep the borrow scope coherent. Chained property access via short-circuit operators (`&&`, `||`) on borrowing parameters is rejected by Swift 6.3 — recommend tuple comparison `(lhs.a, lhs.b) ⊕ (rhs.a, rhs.b)` or local `let`-bindings as the two compiler-accepted alternatives. Cite the 2026-04-17 `Executor.Job.Priority.Entry` reproduction.
- [ ] **[skill]** audit: Strengthen `[AUDIT-006]` step 5 ("Verify findings against source") with a sub-requirement: when the finding includes a *recommended fix* (not just identification of a violation), the recommended form MUST be compile-verified against the actual source before the finding lands. The cost is one build; the cost of a wrong recommendation is propagating misinformation to the next session.
- [ ] **[research]** Empirically map which Swift 6.3 expression shapes accept chained property access on `borrowing` parameters. Boundary cases to test: (a) `&&` and `||`; (b) ternary `cond ? lhs.a : rhs.a`; (c) tuple comparison; (d) explicit `_borrow lhs` (if available); (e) `consume`-only at the call site. Output: a small table that the implementation skill can cite.
