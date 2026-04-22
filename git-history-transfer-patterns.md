# Git History + Repo Transfer Patterns

<!--
---
version: 1.0.0
last_updated: 2026-04-22
status: RECOMMENDATION
research_tier: 2
applies_to: [institute, primitives, standards, foundations]
normative: false
---
-->

## Context

### Trigger

The Swift Institute ecosystem-finalization push (Phase III in
workspace `HANDOFF.md`) and the
`HANDOFF-heritage-transfers-and-history-strategy.md` investigation
surfaced two overlapping needs:

1. Move authored packages (e.g., the `coenttb/swift-html` tree)
   into their canonical ecosystem homes (`swift-foundations/*`)
   while preserving upstream authorial heritage — the tagged-
   release history external users know and consumers reference
   via `.package(url:)`.
2. Finalize each repo by squashing the post-tag "AI-muddied"
   development window into a single ecosystem-work commit, without
   touching the pre-tag history.

The prior org-migration work
(`github-organization-migration-swift-file-system.md`) answered
"how do I move a repo between GitHub orgs" but did not address
"how do I collapse post-tag work while keeping the pre-tag
lineage intact." This doc fills that gap and records the
composition patterns when transfer + squash combine.

### Scope

Ecosystem-wide [RES-002a]. Applicable whenever a Swift Institute
package is (a) transferred between GitHub orgs, (b) finalized
with a post-tag history squash, or (c) both. Expected to be used
during the Phase III push wave (~400–500 ecosystem commits) and
any future org-heritage consolidation.

### Precedent risk

High. The decisions codified here determine whether external
consumers' `Package.resolved` files continue to resolve, whether
`gh api transfer` redirects set up correctly, and whether force-
pushes land on repos with heritage signals (stars, forks,
subscribers) the ecosystem depends on for consumer trust.

---

## Question

What procedures should the Swift Institute use to (1) transfer a
GitHub repo between orgs while preserving history/stars/redirects,
(2) squash the post-tag window of a repo's history into a single
commit while preserving pre-tag heritage, and (3) combine the two
when a transfer + finalization happens in sequence?

### Sub-questions

- SQ1: What exactly does `gh api repos/X/Y/transfer` preserve?
  How does it compare to fork-then-merge for heritage preservation?
- SQ2: Which git primitive best implements the
  "preserve-pre-tag, collapse-post-tag" requirement, across
  authorship, force-push, tag safety, and complexity?
- SQ3: How do the transfer and squash compose when both are
  needed (transfer then squash, or squash then transfer)?
- SQ4: What side-effects (submodule pointers, open PRs, url
  redirects) must be handled outside the core recipe?

---

## Prior Art Survey [RES-021]

### Within the Swift Institute ecosystem

- `github-organization-migration-swift-file-system.md` (Tier 2) —
  Codifies the 81-package standards-body org transfer. Confirms
  `gh api repos/X/Y/transfer` preserves commit history, tags,
  branches, repo settings, and sets up 90-day URL redirects.
  Does not address post-tag history squashing.
- `git-subtree-publication-pattern.md` (Tier 2) — Confirms the
  ecosystem is submodule-aggregation, not monorepo-with-subtrees.
  Relevant here because post-transfer submodule pointer
  behaviour is a downstream concern of this doc.
- `spm-nested-package-publication.md` — Historical context.

### External prior art

- [Pro Git, ch. 7.6 "Rewriting History"][1] — canonical reference
  on `git rebase -i`, `git reset`, and `git filter-branch`/
  `filter-repo`.
- [git-filter-repo][2] — recommended over filter-branch; used for
  path-based rewrites, not for simple squash.
- [GitHub "Transferring a repository" docs][3] — behaviour of
  `POST /repos/{owner}/{repo}/transfer`: preserves git data,
  installs redirects, requires target-name availability, supports
  `new_name` rename-during-transfer.
- GitHub blog 2013-10-31 "Repository redirects" (historical) —
  introduced repo redirects; redirects persist until a new repo
  claims the old name.

[1]: https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History
[2]: https://github.com/newren/git-filter-repo
[3]: https://docs.github.com/en/rest/repos/repos#transfer-a-repository

---

## Analysis

### A. Transfer vs fork-then-merge

| Property | `gh api repos/X/Y/transfer` | `gh repo fork` + merge |
|---|---|---|
| Full git history preserved | ✓ | ✓ (on the fork) |
| Tags preserved | ✓ | ✓ |
| Stars move with the canonical repo | ✓ | ✗ (fork starts at 0) |
| Open issues / PRs move | ✓ | ✗ |
| Subscribers / watchers move | ✓ | ✗ |
| Old URL redirects to new | ✓ (persistent server-side) | ✗ |
| Target-name availability required | Yes (or `new_name=…`) | No |
| Reversible | Yes (transfer back) | N/A |
| `Package.resolved` files keep resolving | Yes (via redirect) | Only if consumers re-point explicitly |

For the Institute's goal of preserving authorial heritage —
stars, issues, PRs, external `Package.resolved` resolution —
`gh api .../transfer` dominates fork-then-merge across every
axis that matters. Fork-then-merge is a fallback only when the
source repo must remain authoritative, which is not the Institute's
case when consolidating under the ecosystem's canonical orgs.

### B. Post-tag squash options

| Recipe | Pre-tag preserved | Post-tag → 1 | Authorship | Force-push | Complexity |
|---|:---:|:---:|---|:---:|---|
| A — `git rebase -i <tag>` | ✓ | ✓ | First commit's author kept; messages concatenated | yes | medium |
| B — `git reset --soft <tag> && git commit` | ✓ | ✓ | Current committer | yes | **low** |
| C — Orphan branch (drop all history) | ✗ | N/A | New | yes | low |
| D — Clone-from-tag + re-apply diff | ✓ | ✓ | Current committer | no (fresh repo) | medium |
| E — `git filter-repo` | ✓ | ✓ | Configurable | yes | high |
| F — `git commit-tree` (plumbing) | ✓ | ✓ | Current committer | yes | medium |

**B wins** on simplicity + determinism. A is equivalent with more
ceremony. C drops pre-tag history (wrong goal). D is useful only
when operating on a fresh clone (e.g., under heavy CI automation).
E is overkill unless a separate history-rewrite goal (path
filtering, author rewrites) is in scope. F offers no advantage
over B for pure squash.

### C. Composition: transfer + squash

The only order that is robust for public repos is **transfer
first, then squash**. Rationale:

1. Transferring a post-squash repo is fine, but squashing first
   means any in-flight PRs or watchers on the old org see a
   force-pushed history *before* the repo moves. This produces
   confusing audit trails for external observers.
2. Transferring first keeps heritage signals (stars, redirects,
   PRs) attached to the canonical new home, so the squash
   happens on the repo where the heritage is already
   consolidated.
3. The open-PR drain (see §D below) happens once, at the
   transfer boundary; squashing on the transferred repo is then
   just a mechanical step.

### D. Out-of-band concerns

- **Open PRs**: force-pushing `main` invalidates PR branches
  that descend from rewritten commits. Recipe requires a
  `gh pr list` check + merge/close/rebase drain before the
  squash step.
- **Submodule pointers**: a superrepo (`swift-primitives/`,
  `swift-standards/`, `swift-foundations/`) tracks each
  subrepo's commit SHA. Post-transfer: pointer resolves via the
  redirect until a new repo claims the old name.
  Post-squash: SHA becomes orphan (no longer exists on remote).
  Recipe: `git submodule update --remote <name> && git add
  <name> && git commit -m "chore: bump submodule pointer"` in
  the superrepo.
- **Redirect persistence**: GitHub redirects persist indefinitely
  unless a new repo claims the old name. No expiry on the
  90-day horizon (a common misconception — that window applies
  to *certain redirect types* only, not repo-level redirects).
- **`--force-with-lease` vs `--force`**: always `--force-with-
  lease`. Bare `--force` is prohibited ecosystem-wide (CLAUDE.md
  Git Safety Protocol).
- **Authorship collapse**: Option B credits the squash to the
  current committer. For single-author post-tag windows
  (common in the Institute), this is transparent. For
  multi-author windows, document the collapse in the commit
  message.

---

## Outcome

**Status**: RECOMMENDATION.

### Canonical recipes

#### Recipe 1 — Transfer only (no history change)

```bash
gh api "repos/<src-owner>/<repo>/transfer" \
  -X POST -f new_owner=<dst-owner>
# Optional rename during transfer:
# -f new_name=<new-repo-name>

# Per-repo verification (transfer is async):
for i in 1 2 3 5 10; do
  sleep "$i"
  gh repo view "<dst-owner>/<repo>" --json name,defaultBranch 2>/dev/null && break
done

# Update local clone's origin:
cd /path/to/clone
git remote set-url origin "https://github.com/<dst-owner>/<repo>.git"
```

#### Recipe 2 — Post-tag squash only (repo stays in place)

```bash
cd /path/to/repo
LAST_TAG=$(git describe --tags --abbrev=0)
git status -s                                  # verify clean
git reset --soft "$LAST_TAG"                   # HEAD back to tag, index unchanged
git commit -m "Ecosystem work on top of $LAST_TAG heritage"
git log --oneline --decorate -5                # verify
git push --force-with-lease origin main
```

#### Recipe 3 — Transfer + post-tag squash (composition)

```bash
# 0. Drain open PRs on the source repo:
gh pr list --repo <src-owner>/<repo>            # resolve each before proceeding

# 1. Vacate destination if it is a placeholder:
#    (only for orgs with prior scaffolding work)
gh repo delete <dst-owner>/<repo> --yes

# 2. Transfer (preserves all history, tags, stars, redirects):
gh api "repos/<src-owner>/<repo>/transfer" \
  -X POST -f new_owner=<dst-owner>

# 3. Update local clone's origin:
cd /path/to/clone
git remote set-url origin "https://github.com/<dst-owner>/<repo>.git"

# 4. Squash post-tag commits (heritage preserved):
LAST_TAG=$(git describe --tags --abbrev=0)
git reset --soft "$LAST_TAG"
git commit -m "Ecosystem work on top of $LAST_TAG heritage"

# 5. Force-push the squash to the new home:
git push --force-with-lease origin main

# 6. In the parent superrepo (if this repo is a submodule):
cd /path/to/superrepo
git submodule update --remote <repo>
git add <repo>
git commit -m "chore: bump submodule pointer after post-tag squash"
```

### Scenario matrix

| Scenario | Recipe | Notes |
|---|---|---|
| Internal refactor, repo stays at current org | 2 | Most common; per-repo discipline |
| Move from personal org → ecosystem org, keep heritage | 1 | No history change; preserves consumer resolution |
| Consolidate personal org → ecosystem org + finalize | 3 | Canonical "transfer + squash" composition |
| Monorepo product → per-package split (consumer-facing) | N/A | Consumer-side Package.swift edits only; no history rewrite on old monorepo required |
| Cold-start a new ecosystem repo from an authored tag | D (clone-from-tag) | Fresh repo; no force-push needed |

### What NOT to do

- **Don't** run `git reset --hard` as part of the squash — stage
  the tree first (`--soft`), commit, then force-push. Mistakes
  are unrecoverable with `--hard`.
- **Don't** force-push bare — always `--force-with-lease`.
- **Don't** drop pre-tag history (Option C orphan branch) — the
  user's explicit intent is that pre-tag commits are the
  authorial heritage and must remain browsable.
- **Don't** use fork-then-merge when transfer is available —
  stars, issues, PRs, and redirects are lost in forks.
- **Don't** transfer before draining open PRs — the force-push
  in step 4 will invalidate PR branches and surprise external
  contributors.
- **Don't** rely on `sed` to rewrite history — use git primitives.
  Manifest rewrites in `Package.swift` at consumer sites
  (`.package(url:)`) are appropriate for `sed`; git history
  rewrites are not.

### Scope notes

- These recipes assume a single `main` branch with linear
  post-tag history. For repos with merge commits in the
  post-tag window, Option A (interactive rebase) may refuse to
  linearize without `--rebase-merges`; Option B handles this
  transparently (the tree at HEAD is committed regardless of
  the shape of intermediate commits).
- Tag safety is automatic: these recipes only rewrite commits
  after the anchor tag; pre-tag tags continue pointing to their
  original commits. A post-tag tag (if any — rare in the
  Institute's tagging discipline) would orphan and must be
  explicitly deleted.

---

## References

### Primary sources

- [Git Pro — Rewriting History](https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History)
- [git-filter-repo](https://github.com/newren/git-filter-repo)
- [GitHub REST API — Transfer a repository](https://docs.github.com/en/rest/repos/repos#transfer-a-repository)
- [GitHub Docs — Transferring a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/transferring-a-repository)

### Related ecosystem research

- [github-organization-migration-swift-file-system.md](github-organization-migration-swift-file-system.md) — Transfer mechanics for the 81-package standards-body migration (Tier 2, DECISION).
- [git-subtree-publication-pattern.md](git-subtree-publication-pattern.md) — Submodule-aggregation structure of ecosystem superrepos.
- [domain-first-repository-organization.md](domain-first-repository-organization.md) — Underlying organizational model driving the transfer workflows.

### Handoffs

- `HANDOFF-heritage-transfers-and-history-strategy.md` (workspace
  root) — investigation that produced this doc; includes the
  specific enumeration of the swift-html tree and the
  swift-standards monorepo split cheat sheet.
- `HANDOFF-standards-org-migration.md` (workspace root) — Phase
  5 of the consumer-URL-rewrite pattern referenced here.
