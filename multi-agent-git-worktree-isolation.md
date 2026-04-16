---
title: Git Worktree Isolation for Multi-Agent Concurrent Editing
version: 0.1.0
status: IN_PROGRESS
tier: 2
created: 2026-04-16
last_updated: 2026-04-16
applies_to:
  - swift-institute
  - all superrepos with concurrent agent activity
---

# Context

Phase 3's perfection-audit fix pass contaminated a commit with
unrelated changes from a concurrent agent's in-flight work: the
`supervise`-skill additions in `swift-institute-core/SKILL.md` and
`skill-lifecycle/SKILL.md` were already in the working tree when this
session's fix pass began. The `git add` staged both this session's
edits and the parent's unstaged changes. The contamination was caught
by manual `git status` inspection, but detection was accidental — no
tooling or process prevented it. As multi-agent workflows become the
norm (supervisor + subordinate, parallel research agents, branching
investigations), shared-working-tree contamination risk is recurring.
A similar friction appeared in the polling-tick-throws session, where
an untracked file from a concurrent agent broke the build.

# Question

Should git worktree isolation be the default for sessions that share a
working tree with other concurrent agents? Specifically:

- What's the cost of per-agent worktrees (disk, build-cache
  duplication, SourceKit-LSP re-indexing, cclsp configuration)?
- Can the setup cost be automated such that spawning a sub-agent
  creates a worktree transparently?
- How do worktree-isolated edits merge back to the parent's branch —
  cherry-pick, merge, replay?
- What does the supervisor skill need to know about worktree
  boundaries to coordinate termination?

# Prior Work

- `swift-institute/Skills/supervise/SKILL.md` — ground-rules block
- `swift-institute/Skills/handoff/SKILL.md` — branching handoff
- `swift-institute/Research/agent-supervision-patterns.md`
- Source reflection: `swift-institute/Research/Reflections/2026-04-15-phase3-perfection-audit-and-fix-cycle.md`

# Analysis

_Stub — to be filled in during investigation._

Key sub-questions to work through:

- Does `.claude/worktrees/` already exist as a convention? (Acceptance
  gate audit found `.claude/worktrees/` entries in grep output.)
- What does `git worktree add` cost when the working tree has
  submodules (swift-foundations nests swift-io, etc.)?
- Can SwiftPM's `.build` directory be symlinked across worktrees
  safely, or does it need to be per-worktree?

# Outcome

_Placeholder — to be filled when analysis completes._

# Provenance

Source: `swift-institute/Research/Reflections/2026-04-15-phase3-perfection-audit-and-fix-cycle.md` action item.
