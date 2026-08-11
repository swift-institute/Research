---
date: 2026-04-15
session_objective: Close HANDOFF-executor-judgment-calls.md per user decision (execute #1 typed count adoption, decline #2 Polling Windows visibility)
packages:
  - swift-executors
  - swift-foundations
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Executor Judgment Calls — Handoff Closure via Inaction

## What Happened

The session inherited `HANDOFF-executor-judgment-calls.md`, which deferred two audit findings: (1) typed count adoption in swift-executors, (2) Polling Windows visibility. User decision up front: execute #1, decline #2; each as separate branch + separate commit; scope discipline per supervisor ground rules.

Execution of #1 did not proceed as planned. First diagnostic showed `swift-foundations` on branch `audit-cleanup` with submodule `swift-executors` flagged as `modified content, untracked content`. Inside swift-executors on `main`, `git diff` showed exactly the typed-count-adoption changes (Sharded and Stealing swapping `(0..<Int(options.count)).map` for `Array(count: options.count)`, and `Atomic<UInt64>` round-robin counters for `Atomic<Index<Kernel.Thread>>.advance(within:)`). I reported the mismatch to the user with four options rather than proceeding unilaterally.

User directed a modified Option 4: diagnose before acting, do not fix residual leaks, do not commit anything, document closure. Subsequent diagnostics revealed swift-executors HEAD was already `1529eea "Audit remediation: shutdown()/wake.all() naming, typed cursors, file splits"` — the entire handoff #1 scope was committed. Working tree was clean except for untracked `Research/`. swift-foundations `audit-cleanup` captured the L3 work in commits `5d0c71c` (phase 2b: typed count adoption) and `6b43a3b` (Atomic typed Index cursor).

Whether my earlier `git diff` output was stale (work got committed between my diagnostics), a misread of submodule state, or a genuine pre-commit snapshot that got committed mid-session, I cannot say with certainty. Supervisor flagged this epistemic uncertainty as appropriate humility — end-state verification at HEAD `1529eea` is what closes the handoff, not the narrative of how I got there.

Verified all four declared sites match expected typed infrastructure. Package.swift has both new deps (`swift-ordinal-primitives`, `swift-index-primitives`). Two residual `Int`-typed boundaries were found at HEAD but **not** in the original handoff scope: `Sharded.swift:76` (`executor(at index: Int)`) and `Stealing.swift:31` (`Worker(id: Int(bitPattern: position.ordinal))`). Both were flagged for follow-up, not fixed — each is a source-breaking public API signature change.

Updated `HANDOFF-executor-judgment-calls.md` to record closure. Presented to supervisor. Supervisor accepted and recommended running build/test to verify the unchecked acceptance criterion. User confirmed. `swift build`: clean (32.80s). `swift test`: 18 tests in 21 suites, all passed. Final acceptance box checked.

Handoff disposition per [REFL-009]: all items complete, all ground-rules entries verified or N/A (Decision #2 declined with rationale; Polling.Outcome interaction fact was moot). File qualifies for deletion.

## What Worked and What Didn't

**Worked.** Stopping when inherited state diverged from handoff assumption; not force-fitting an answer. Strict scope discipline — the two residual leaks (`Sharded.swift:76`, `Stealing.swift:31`) were explicitly flagged as out of scope and left untouched despite being one-grep away. Reporting used file:line throughout. Ground-rule compliance was preserved by inaction: "separate branch, separate commit" was satisfied by NOT committing an upstream bundle, rather than by cleaving one post-hoc. Running build/test after closure (supervisor's recommendation) was cheap insurance that turned out green.

**Didn't.** Initial diagnostic sequence was suboptimal. I ran `git status` → `git diff` → offered four action options to the user, all of which presumed uncommitted work. Running `git log --oneline -5` first would have immediately revealed commit `1529eea` at HEAD and the whole picture — saving a user round trip. Submodule state in a superrepo (`modified: swift-executors (modified content, untracked content)`) looks a lot like uncommitted work but is orthogonal to the submodule's own HEAD. The diagnostic ordering matters.

## Patterns and Root Causes

**Ground-rule compliance via inaction.** The supervisor's "MUST execute as separate branches and separate commits" rule was written presuming work would be done in this session. When the work turned out to be committed upstream, two paths existed: (a) non-execution of the commit step (honor the rule by refraining), (b) destructive reconstruction — `git reset` the submodule, cleave out just the typed-count-adoption subset, commit it, restore the other changes. Path (b) satisfies the letter of "separate branch, separate commit" but violates its spirit (scope discipline, reviewability). Path (a) honors both. The generalizable principle: when a MUST-execute ground rule's preconditions aren't met, non-execution IS the compliant path. The ground rule is *about* scope discipline — refraining from imperfect execution preserves that discipline, while forcing the prescribed action sacrifices it.

**Diagnostic anchoring before examination.** Working-tree state (`git status`, `git diff`) is the cheapest thing to read but the easiest to misread when inheriting cross-session context. Commit-log state (`git log --oneline -N`) is stable: commits don't move. When the two disagree — as they did here — the working-tree view is untrustworthy until the log anchor is established. This is a general rule, not executor-specific: for any session that inherits state, the first lookup should be commit log, not working tree.

**Handoff staleness is expected, not exceptional.** The handoff said "pending work." Reality at session start: work was at HEAD. This is not a failure of the prior session or a defect of the handoff — it is a property of how work flows across sessions. Handoff files describe intent at write time; between write and read, work can progress (including by the user committing in a terminal outside the agent's awareness). Verification MUST precede action regardless of handoff confidence. The ground-rule architecture already implies this (MUST NOT start without confirmation; fact: interactions), but the verification-first posture deserves to be explicit.

## Action Items

- [ ] **[skill]** handoff: Add to the verification procedure (extending [HANDOFF-009] or similar): "When inheriting state from a handoff, first diagnostic step MUST be `git log --oneline -N` on affected repos to establish a stable commit anchor. Examine `git status` / `git diff` only after the anchor is established. Working-tree state can shift under background commits or reflect submodule-superrepo mismatches that look like uncommitted work but are orthogonal to the submodule's own HEAD."
- [ ] **[skill]** supervise: Codify "ground-rule compliance via inaction" ([SUPER-XXX]). When a MUST-execute ground rule's prescribed action has unmet preconditions — e.g., the bundle to commit is already upstream, the file to edit no longer exists, the test to add was already added by a prior session — non-execution IS the compliant path. Do not reconstruct preconditions destructively. The rule's spirit (scope discipline, accountability) is preserved by refraining, not by force-fitting an imperfect execution.
- [ ] **[package]** swift-executors: Two residual `Int`-typed boundaries remain at HEAD `1529eea`; fix opportunistically when next revising Sharded/Stealing public API. (a) `Kernel.Thread.Executor.Sharded.swift:76` — `public func executor(at index: Int)` should accept `Index<Kernel.Thread>`. (b) `Kernel.Thread.Executor.Stealing.swift:31` — `Worker(id: Int(bitPattern: position.ordinal))`; type `Worker.id` from `Int` to `Index<Kernel.Thread>` and propagate through Worker's internal stealing logic at `Stealing.Worker.swift` (`(id + offset) % pool.workers.count`). Both are source-breaking signature changes, hence their deferral; they are known debt, not unknown debt.
