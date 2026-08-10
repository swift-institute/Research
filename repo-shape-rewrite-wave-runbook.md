# Rewrite-Wave Runbook — 2026-08-22→23 Quiet Window

<!--
---
version: 1.0.0
last_updated: 2026-08-10
status: RUNBOOK (companion to repo-shape-reduction-history-pruning-release-squash.md)
research_tier: 2
applies_to: [primitives, standards, standards-suborgs, foundations]
normative: false
---
-->

Companion to `repo-shape-reduction-history-pruning-release-squash.md` (the ruling
package, ratified 2026-08-10; ruling recorded on swift-institute/.github#527). This
runbook is the stage-5 execution procedure. **Every command in §3–§6 is
principal-execution-only.** The window is 2026-08-22 → 2026-08-23 (UTC), chosen to sit
after the D4–D7 gate and before the vendor window opens 08-24; fallback 2026-09-06.

## 0. Window discipline: close unconditionally

The window closes at its scheduled end **regardless of completion**. Unfinished repos are
recorded on #527 and roll to the 09-06 fallback; the window is never extended — an
overrun collides with the vendor window, and a half-rewritten fleet with a recorded
remainder is a safe state (each repo is rewritten atomically; there is no cross-repo
partial state other than superrepo pointers, handled in §5).

Corollary: process order is chosen so an early stop is maximally clean — exceptions
verified first, then layer repos leaf-first, superrepo pointer bumps at each org's
completion, not at the very end.

## 1. Preconditions (all must hold before the window opens)

Verified in the days before 08-22, re-verified at window open:

1. **Transfer gate (hard)**: stage-2 transfer wave complete and verified for every repo
   carrying `Research/`, `Experiments/`, `Skills/` — the transferred history is merged
   and visible in the central repos. A repo whose transfer is unverified is **excluded**
   from the wave, not rewritten anyway.
2. **Shape gate**: every in-scope repo's `git ls-files` conforms to the §1.3 manifest
   (long-tail untrack landed). Non-conformant repos are excluded and recorded.
3. **#68 rule** at blocking maturity, so the post-wave shape cannot regress.
4. **Secrecy scan** complete; the classification list (in-place vs republication) is
   frozen and attached to #527. New pushes after the scan re-open the repo's
   classification.
5. **Bundle archives** (`git bundle create <repo>.bundle --all` per repo, per org,
   stored offline in the principal's archival location — never on GitHub) and the
   SHA-map manifest skeleton exist.
6. **Manifest grep** of the code-search-blind swift-institute org done (clone-side, for
   `revision:` pins) — result recorded on #527.
7. **PR drain** (§2) complete.
8. **Lane stand-down**: coordinator confirms no active lanes in any in-scope checkout;
   scheduled workflows that push (sweeps, sync crons) identified; the 04:00 UTC
   metadata-sync cron is accounted for in §3's protection handling.
9. **Announcement** posted (org discussion + #527): window times, expected breakage
   (stale clones, stale `Package.resolved`), resync instructions.

## 2. PR-drain checklist

For each in-scope repo (scripted enumeration, human disposition):

- `gh pr list --state open` — every open PR is merged, closed-with-comment, or its repo
  is excluded from the wave. A force-push under an open PR corrupts its diff and its
  reviewability; there is no third option.
- Draft PRs count as open.
- PR branches themselves need no preservation (refs/pull survives rewrite — measured,
  ruling package §4.1).
- Freeze rule: from drain completion to window close, no non-principal pushes to
  in-scope repos. Any push that lands anyway re-opens that repo's drain check.

## 3. Per-repo in-place rewrite (cleanliness class)

Operate on a fresh clone farm (`git clone --bare` per repo), never on shared workspace
checkouts — no working-tree state, no local-work risk, trivially parallelizable.

```sh
repo=<org>/<name>
git clone --bare "git@github.com:$repo.git" "$name.git" && cd "$name.git"

old=$(git rev-parse main)
tree=$(git rev-parse 'main^{tree}')

# 1–2 commit shape per ruling §3.3: born-public repos get ONE commit;
# repos that will flip private→public at launch also get ONE commit now
# (the flip adds no commit; the tag commit appends post-launch).
new=$(git commit-tree "$tree" -m "Initial commit")

# Branch protection: allow the push for exactly this window, per repo.
gh api "repos/$repo/branches/main/protection" -X GET   # record prior state
# temporarily permit force push (exact call depends on the live protection shape;
# use the bot's canonical mutation path, not hand gh repo edit, where one exists)
git push --force-with-lease=main:"$old" origin "$new:refs/heads/main"
# restore protection immediately; the 04:00 UTC metadata-sync cron re-applying
# rule defaults is the backup, not the mechanism.

# Verify remote tip and tree identity — the whole safety argument is tree equality:
[ "$(git ls-remote origin main | cut -f1)" = "$new" ]
[ "$(git rev-parse "$new^{tree}")" = "$tree" ]

# SHA-map entry (append-only TSV; committed to swift-institute/Internal after the wave):
printf '%s\t%s\t%s\t%s\n' "$repo" "$old" "$new" "$tree" >> ../sha-map.tsv
```

Notes:

- `--force-with-lease=main:"$old"` pins the lease to the recorded old tip: if anything
  pushed since the drain, the push is refused instead of silently clobbering.
- `git commit-tree` writes no reflog and touches no worktree; the new root's tree is
  **by construction** identical to the old tip's tree — the rewrite provably changes
  history only, never content. Tree-hash equality is the per-repo receipt.
- Author/committer identity: the human identity configured in git, per standing rules.
- Dirty or divergent state discovered anywhere: skip the repo, record on #527, move on
  (close-window discipline; residue is the coordinator's to disposition).

## 4. Republication path (secrecy-escalated repos)

For each repo on the frozen escalation list, follow the 2026-08-09 precedent instead of
§3 (in-place rewrite is insufficient by construction — ruling §3.1):

1. Create `<name>-new` in the owning org; push a single `git commit-tree` root built
   from the old repo's current main tree **minus** the secrecy findings (which also means
   the tree-equality receipt does not apply — record the intended diff instead).
2. Rename old repo → `<name>-history`, flip it private; rename `<name>-new` → `<name>`.
3. Re-point the workspace checkout's origin; record both SHAs in the SHA-map with a
   `republished` marker.
4. Rotate any exposed credential (a pushed exposure is a rotation event regardless).
5. Note: issues/PRs/runs stay on the `-history` repo; the new repo starts with an empty
   corpus. Metadata sync (`metadata.yaml`) must be re-run for both names.

## 5. Superrepo pointer bumps

The layer superrepos (`swift-primitives`, `swift-standards` incl. suborg trees,
`swift-foundations`) pin every subrepo SHA; all pointers dangle as their repos are
rewritten. Per org, **after** that org's repos are done (not at wave end — early-stop
cleanliness):

```sh
cd <superrepo>
git submodule foreach 'git fetch origin && git checkout -q $(git ls-remote origin main | cut -f1)'
git add -A -- <submodule paths only>   # explicit pathspecs; verify staged set
git diff --cached --name-only          # must list only submodule pointers
git commit -m "Bump all submodule pointers to post-rewrite roots"
git push origin main                   # normal push; superrepos are not themselves rewritten
```

If a superrepo is itself in-scope for rewrite, rewrite it **after** its pointer bump so
the new root pins the new subrepo SHAs.

## 6. Verification pass (before window close)

Scripted sweep over the wave's repo list; results posted on #527 as the wave receipt:

1. `git ls-remote origin main` tip matches the SHA-map `new` column — every row.
2. History length: `gh api repos/$repo/commits --paginate` count ≤ 2 (1 expected).
3. Tree equality: SHA-map `tree` column matches `new^{tree}` — every in-place row.
4. CI probe: dispatch the caller on a sample (≥1 repo per org) — same tree must build
   the same result; a red here is infra/pin breakage (e.g. stale cross-repo SHA pins in
   workflow resolution), not code.
5. Shape: `git ls-files` of the new root conforms to the manifest (spot sample + #68
   rule run).
6. Residue list: every skipped/unfinished repo enumerated with its reason.

## 7. Post-window (coordinator + lanes, not window-bound)

- Commit `sha-map.tsv` to swift-institute/Internal; link from #527.
- Bot annotation run over **open** issues citing pre-wave SHAs (closed receipts stay
  frozen — ruling §4.4).
- Fleet resync directive: every checkout `git fetch origin && git reset --hard
  origin/main` **only on clean trees** — dirty trees go to the coordinator (residue
  ownership), never reset over.
- `Package.resolved` regeneration note in the announcement thread.
- Re-verify the three generator-exception repos' local `.gitignore` override blocks
  survived the wave.
- 09-06 fallback window pre-brief for any residue.
