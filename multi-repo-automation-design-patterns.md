# Multi-Repo Automation Design Patterns

**Status**: IN_PROGRESS
**Tier**: 2
**Scope**: ecosystem-wide

## Context

The 2026-04-18 `_index.md → _index.json` migration touched 153 files across ~70+ independent git repos (`swift-primitives`, `swift-foundations`, `swift-standards` superrepos and their per-package submodules). The batch produced three silent `git add` failures that shipped commits with the MD deletion but without the JSON addition — caught only by a post-loop `git ls-files --error-unmatch` cross-check, not by first-pass automation (reflection `2026-04-18-ecosystem-index-migration-completion-and-batch-git-edges.md`).

Root cause analysis surfaced that per-repo state is non-uniform in ways a naive batch harness does not handle:

- Detached HEAD (1 repo hit)
- Diverged from origin (1)
- Feature branch checked out (4)
- No origin remote (3)
- Pre-existing uncommitted mods (1)
- Pre-existing gitignore blocking the new file path (1)
- `git status --porcelain` aggregation at directory level (root cause of the 3 silent `git add` failures)

## Question

**What is the reusable design for multi-repo batch automation that handles the full state-axis enumeration — branch state, remote state, working-tree state, gitignore interactions, divergence — without silent failures?**

Sub-questions:
- What is the minimum pre-flight check list a batch harness MUST run before touching any repo?
- How should the harness route per-repo state (fail-fast vs. adapt vs. skip)?
- Where should the harness live — `swift-institute/Scripts/` as shared tooling, or per-migration throwaway?
- What post-loop audit pattern catches silent failures at full scope per `[REFL-006]`'s multi-item extension?

## Analysis (stub)

Proposed investigation:

1. **Enumerate the state-axes observed** and classify each as fail-fast, adapt-and-continue, or skip-with-report.
2. **Design a pre-flight phase** that asserts per-repo state before mutation (e.g., `git branch --show-current == main` assertion).
3. **Design a post-loop audit phase** that cross-checks expected outputs against git-tracked state (`git ls-files --error-unmatch`).
4. **Decide tooling home**: if ≥2 future migrations are anticipated, the abstraction earns its keep in `swift-institute/Scripts/`; otherwise per-migration throwaway remains the right shape per [Pattern 3 — per-shape throwaway scripts] from the source reflection.

## Outcome (placeholder)

Pending. Expected artifact shape: a `swift-institute/Scripts/` helper module or reusable Python harness documenting the state-axis routing, with the 2026-04-18 migration retrospectively replayed against it as the validation case.

## Provenance

- `Research/Reflections/2026-04-18-ecosystem-index-migration-completion-and-batch-git-edges.md`
- `Research/Reflections/2026-04-18-json-authoritative-migration-sweep.md`
- `Scripts/migrate-index.py` — current single-migration tool

## References

- `Skills/reflect-session/SKILL.md` — `[REFL-006]` multi-item scope extension
- `swift-institute/Scripts/` — workspace-wide tooling home
