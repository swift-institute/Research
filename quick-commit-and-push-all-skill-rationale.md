# Quick Commit and Push All — Skill Rationale Archive

Extended rationale, provenance, and worked examples for `quick-commit-and-push-all` skill rules. The `SKILL.md` carries lean rule bodies; this file carries the incidents and full reasoning. Non-normative — NOT the canonical source for requirement IDs.

---

## [SAVE-005] (promoted 2026-07-05)

**Rule**: [SAVE-005] Branch Guard Before Commit; Verify HEAD == origin/main After Push.

**Provenance**: memory `feedback_verify_push_landed_on_main` (2026-06-02, ecosystem path→URL aux pass). Promoted by the 2026-07-05 memory-drain (D1 cluster).

**Origin incident**: `swift-institute/Experiments` was checked out on a local-only feature branch (`experiment/storage-protocol-specialization`, 14 commits of unmerged work). A convert-and-push loop committed the path→URL conversion onto THAT branch, and `git push origin main` falsely reported "Everything up-to-date" / exit 0 — `origin/main` never received it. The production loop over ~180 repos DID verify (a `branches: {'main': 167}` precheck plus a final "in sync with origin/main" audit); only the aux loop skipped the branch guard. A comprehensive `branch != main` + `HEAD != origin/main` audit across all repos caught exactly this one repo; it was resolved by `git branch -f main HEAD` (clean fast-forward — main was an ancestor) + `git push origin main`.

**Mechanism (why the false success)**: `git push origin main` while HEAD is on a non-main branch pushes the local `main` ref (which is unchanged), reports success, and leaves the new commit stranded on the feature branch. A naive `if push.returncode == 0: ok` loop records a landing that never happened. The two-sided guard — branch == intended BEFORE commit, `git rev-parse HEAD == git rev-parse origin/main` AFTER push — closes both the wrong-branch-commit and the false-success-push failure modes.

**Cross-references**: supervise [SUPER-052] (push-set membership is set-membership against the enumerated window, never `ahead>0`), [SUPER-054] (the seat's own gate artifacts are state claims), memory `feedback_clean_room_resolve_not_redundant`.
