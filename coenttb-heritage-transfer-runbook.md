# Coenttb Heritage Transfer Runbook (Beyond-18) — Safety-First

<!--
---
version: 1.0.0
last_updated: 2026-07-01
status: RECOMMENDATION (execution runbook; nothing executed)
tier: 2
scope: coenttb → swift-institute owned-source heritage transfer, high-confidence set
---
-->

<!--
Changelog:
- v1.0.0 (2026-07-01): Assignment-2 runbook. Consumes the tiered inventory in
  `coenttb-heritage-inventory-beyond-18.md` v1.1.0 and applies four user rulings
  (2026-07-01): (1) transfer ONLY packages with an existing institute counterpart;
  (2) archive the -ecosystem holder after zero-diff, human deletes at the end;
  (3) coenttb-PRIVATE packages excluded; (4) pilot = swift-copy-on-write.
  User directive: "safety is nr 1." Adds the mirror-backup safety architecture,
  the GitHub-verified wave partition, and the fully-worked pilot.
-->

## Governing decisions (user, 2026-07-01)

1. **Scope** — transfer ONLY coenttb packages that have an **existing institute
   counterpart** (a repo to reconcile against). Packages with no counterpart
   (kernel-primitives class — *deliberately* excluded from the institute) **remain in
   coenttb**; we do not seed new institute repos for them.
2. **Holder disposition** — after zero-diff verification, **archive** the `-ecosystem`
   holder. Deletion is **manual by the user** at the very end, from a reviewed list.
3. **Visibility** — coenttb-**PRIVATE** packages are **excluded/ignored**.
4. **Pilot** — `swift-copy-on-write`.
5. **SAFETY IS #1** — every irreversible action is backed by a full mirror backup, is
   reversible, and is human-authorized. Nothing fires automatically.

This runbook **stages** work; it authorizes **nothing**. Every rename / transfer / archive
is its own explicit per-repo `YES` (Rule 6).

---

## 1. Safety architecture (applies to EVERY package, before anything else)

The core safety invariant: **before a single GitHub-side mutation, both repos are
mirror-backed up locally, and the automation is structurally incapable of destroying
anything** (the token lacks `delete_repo`; only the human deletes, last, from a list).

### S0 — Pre-flight token check (once, before the wave)
```
gh auth status                       # confirm authenticated as the account owning coenttb + institute orgs
gh api user -q .login                # sanity
# Expected scopes: repo (rename+archive+transfer), read:org. MUST LACK delete_repo.
```
If the token has `delete_repo`, **stop** and reduce scope — we want deletion to be
impossible for the automation.

### S1 — Immutable mirror backups (per package, before any mutation)
```
BK=~/heritage-backups/2026-07-01
mkdir -p "$BK"
git clone --mirror https://github.com/coenttb/X.git            "$BK/coenttb--X.git"
git clone --mirror https://github.com/<institute-org>/X.git    "$BK/<institute-org>--X.git"
git -C "$BK/coenttb--X.git" fsck --full
git -C "$BK/<institute-org>--X.git" fsck --full
```
A `--mirror` clone captures **all branches, tags, and refs + full history**. Ultimate
rollback: `git push --mirror` recreates either repo exactly. **Keep backups until the
whole wave is verified and the holders are deleted.**

### S2 — Metadata snapshot (per package)
Record to a manifest before touching GitHub: both repos' HEAD SHAs, visibility, star
count, open-PR list, tags, default branch, description/topics. This is the "known-good"
baseline every verification checks against.

### S3 — Local rehearsal of the apply-on-top (per package, zero GitHub risk)
Rehearse step 4 (the `git rm -rf . && checkout && add -A`) in a throwaway clone from the
**backups**, confirm the resulting tree equals the institute tree (`git diff` empty), and
only then run it for real. Proves the replacement semantics on *this* repo before it
matters.

### S4 — Structural safety guarantees (hold for the entire program)
- **coenttb history is NEVER rewritten** — transfer preserves it; apply-on-top only *adds*
  one commit on top of coenttb HEAD.
- **ZERO force-push points** — the transfer preserves history; the apply-on-top is a
  fast-forward. If any step seems to want `--force`, **stop** — the recipe is wrong.
- **Archive, never delete** (automation). The token can't delete; the human deletes last.
- **No `git checkout <file>` / `reset --hard` / `stash`** against uncommitted state (house rules).

### S5 — Verify-before-advance gates (per package)
No step proceeds until the prior step's gate passes (§4 recipe embeds them). No package's
holder is archived until its zero-diff + build/test gate passes.

### S6 — One pilot, fully validated, THEN small batches
The pilot (`swift-copy-on-write`) runs completely — through build/test + holder-archive —
and is reviewed before any second package. Then the clean wave proceeds in small batches,
each package individually authorized.

### Recovery procedures (documented up front)
| Situation | Unwind |
|---|---|
| Before step 4.1 (rename) | Do nothing — no GitHub state changed. |
| After 4.1 rename, before 4.2 transfer | `gh api -X PATCH repos/<org>/X-ecosystem -f name=X` (rename back). |
| After 4.2 transfer | Transfer back: `gh api -X POST repos/<org>/X/transfer -f new_owner=coenttb`; rename holder back. |
| Apply-on-top wrong | `git reset --hard <coenttb-HEAD>` (pre-apply, recorded in S2), redo step 4. coenttb history untouched. |
| Catastrophe | `git push --mirror` from the S1 backup recreates the repo exactly. |
| Consumer already bound to new URL | Coordinate consumer-side; GitHub redirect covers old-URL refs meanwhile. |

---

## 2. GitHub-verified scope (2026-07-01)

All institute counterparts **exist on GitHub** → every case is a genuine collision (uniform
recipe, no shortcuts). Visibility verified via `gh repo list`.

### WAVE 1 — Clean (coenttb PUBLIC **and** institute counterpart PUBLIC, owned, no ruling)

| # | coenttb (repo) | → institute destination | Collision shape |
|---|---|---|---|
| **P** | **swift-copy-on-write** (PUB 1★) | swift-foundations/swift-copy-on-write (PUB) | **same-name** ← PILOT |
| 1 | swift-file-system (PUB 22★) | swift-foundations/swift-file-system (PUB) | same-name |
| 2 | swift-io (PUB 18★) | swift-foundations/swift-io (PUB) | same-name |
| 3 | swift-environment-variables (PUB 7★) | swift-foundations/swift-environment (PUB) | rename |
| 4 | swift-linux (PUB 5★) | swift-foundations/swift-linux (PUB) | same-name |
| 5 | swift-windows (PUB 4★) | swift-foundations/swift-windows (PUB) | same-name |
| 6 | swift-builders (PUB 4★) | swift-primitives/swift-builder-primitives (PUB) | rename |
| 7 | swift-memory-allocation (PUB 2★) | swift-primitives/swift-memory-allocation-primitives (PUB) | rename |
| 8 | swift-logic-operators (PUB 2★) | swift-primitives/swift-logic-primitives (PUB) | rename |
| 9 | swift-bounded-cache (PUB 1★) | swift-primitives/swift-cache-primitives (PUB) | rename |

10 packages total (pilot + 9). **This is the highest-confidence, lowest-risk set — the focus.**

### WAVE 2 — Both public, but needs a ruling first
| coenttb | → destination | Ruling needed |
|---|---|---|
| swift-posix (PUB 2★) | swift-ieee-1003 (PUB, L2) + swift-posix (PUB, L3) | spec↔behavior **split** |
| swift-darwin (PUB 1★) | swift-darwin-standard (PUB, L2) + swift-darwin (PUB, L3) | spec↔behavior **split** |

### HELD — coenttb PUBLIC but institute counterpart **PRIVATE** (transfer would publish institute WIP)
| coenttb | institute counterpart | Why held |
|---|---|---|
| swift-email (PUB 2★) | swift-foundations/swift-email (**PRIV**) | apply-on-top would publish unreleased institute code |
| swift-password-validation (PUB 2★) | swift-foundations/swift-password (**PRIV**) | same |
| swift-jwt (PUB 1★) | swift-foundations/swift-json-web-token (**PRIV**) | same |
| swift-one-time-password (PUB 1★) | swift-foundations/swift-time-based-one-time-password (**PRIV**) | same |

Each needs an explicit "publish the institute counterpart" decision (its own launch) before
it can join a wave. Until then, held.

### DE-CONFLICT — likely belongs to the named-18 program, not this one
| coenttb | Issue |
|---|---|
| swift-svg-printer (PUB 1★) | maps to swift-foundations/swift-svg-render, which the **named-18 plan already assigns to `coenttb/swift-svg-rendering`**. Two sources → one destination is impossible; resolve ownership before scheduling. Excluded from Wave 1/2. |

### EXCLUDED — coenttb PRIVATE (per user rule)
swift-buffer, swift-kernel, swift-pdf, swift-epub (Tier 1) · swift-memory, swift-pdf-rendering (Tier 2).

### REMAIN in coenttb — no institute counterpart (deliberate exclusion)
swift-kernel-primitives + all other Tier-3 ABSENT candidates. Not transferred.

---

## 3. Per-package precondition gate (must all pass before step 4)

```
[ ] S0 token check done (has repo, LACKS delete_repo)
[ ] S1 mirror backups of BOTH repos taken + fsck-clean
[ ] S2 metadata snapshot recorded (SHAs, visibility, stars, PRs, tags)
[ ] coenttb/X is PUBLIC (else excluded)
[ ] institute/X is PUBLIC (else HELD — do not publish WIP)
[ ] coenttb/X working tree clean, on main, origin synced
[ ] Dep-visibility: institute/X's Package.swift deps are all PUBLIC (no PRIVATE sibling) → PUBLIC result builds externally
[ ] Open PRs on coenttb/X noted (dependabot: accept staleness; substantive: drain first)
[ ] S3 local rehearsal of apply-on-top produced zero-diff vs institute tree
[ ] Per-action YES captured for: rename, transfer, archive
```

---

## 4. The transfer recipe (per package; embeds the gates)

`SRC=coenttb/X`, `DST=<institute-org>`, target name `X` (same-name) or `Y` (rename).

```
# 4.0  (safety) S1 backups + S2 snapshot + S3 rehearsal already done; gates green.

# 4.1  VACATE the destination name            [YES #1]
gh api -X PATCH repos/$DST/<X|Y> -f name=<X|Y>-ecosystem
#   → frees the target name; institute content now lives at <X|Y>-ecosystem. Reversible.

# 4.2  TRANSFER coenttb repo into the freed name   [YES #2]
gh api -X POST repos/coenttb/X/transfer -f new_owner=$DST $([ rename ] && echo -f new_name=Y)
#   → coenttb's FULL history + tags + stars land at $DST/<X|Y>; coenttb/X URL redirects.
#   → GATE: confirm $DST/<X|Y> exists; `git ls-remote` shows coenttb tags; coenttb/X 301-redirects.

# 4.3  SYNC local
git clone https://github.com/$DST/<X|Y>.git && cd <X|Y>
git fetch origin && git merge --no-edit origin/main    # capture any divergence (no rewrite)

# 4.4  APPLY institute content ON TOP (one commit; replacement, not union)
git remote add eco https://github.com/$DST/<X|Y>-ecosystem.git && git fetch eco
git rm -rf .
git checkout eco/main -- .
git add -A
git commit -m "Apply $DST/<X|Y> ecosystem work on top of coenttb heritage"
#   parent = coenttb HEAD ; tree = institute content exactly.

# 4.5  PUSH (fast-forward — NEVER --force)
git push origin main
#   → GATE: this must be a fast-forward. If it demands --force, STOP (recipe is wrong).

# 4.6  VERIFY (all must pass before 4.7)
git diff --stat eco/main HEAD            # MUST be empty (tree == institute content)
swift build && swift test                # HEAD builds/tests as the institute version
git log --oneline | tail                 # coenttb heritage tail visible below the apply commit
git ls-remote --tags origin              # coenttb tags preserved
#   confirm coenttb/X URL redirects; star count preserved (S2 baseline).

# 4.7  ARCHIVE the holder (NOT delete)     [YES #3]
gh api -X PATCH repos/$DST/<X|Y>-ecosystem -f archived=true
#   → recorded for the human-deletion list (§5).
```

> **Foundation-in-heritage note (L1 targets):** for primitives-layer transfers (builders,
> memory-allocation, logic-operators, bounded-cache), coenttb's *historical* commits may
> contain Foundation imports even though the L1 destination is Foundation-free. HEAD is the
> institute tree (Foundation-free → CI passes); only `git blame`/`git log` on the heritage
> tail shows Foundation. Cosmetic/historical; no recipe change.

---

## 5. Packages for the user to DELETE at the end (holders)

The automation **archives** each holder; it cannot delete (no `delete_repo` scope). After
the whole wave is verified and stable, delete these `-ecosystem` holders manually via the
GitHub web UI. The final list will be produced at wave-end; for Wave 1 it will be:

```
swift-foundations/swift-copy-on-write-ecosystem
swift-foundations/swift-file-system-ecosystem
swift-foundations/swift-io-ecosystem
swift-foundations/swift-environment-ecosystem
swift-foundations/swift-linux-ecosystem
swift-foundations/swift-windows-ecosystem
swift-primitives/swift-builder-primitives-ecosystem
swift-primitives/swift-memory-allocation-primitives-ecosystem
swift-primitives/swift-logic-primitives-ecosystem
swift-primitives/swift-cache-primitives-ecosystem
```
(Only after their transferred repos are confirmed good. Deleting a holder is the one
irreversible step — hence human-only, last, from a verified list, with mirror backups still
in hand.)

---

## 6. The pilot, fully worked — `swift-copy-on-write`

Both public; exact-name collision; small; exercises the full same-name recipe.

**Pre-flight:** S0 token check · S1 mirror-backup `coenttb/swift-copy-on-write` +
`swift-foundations/swift-copy-on-write` · S2 snapshot · dep-check the foundations
Package.swift is all-public · S3 rehearse apply-on-top → zero-diff.

**Execute (each its own YES):**
1. `gh api -X PATCH repos/swift-foundations/swift-copy-on-write -f name=swift-copy-on-write-ecosystem`
2. `gh api -X POST repos/coenttb/swift-copy-on-write/transfer -f new_owner=swift-foundations`
3. clone `swift-foundations/swift-copy-on-write`; `git fetch && git merge --no-edit origin/main`
4. `git remote add eco …swift-copy-on-write-ecosystem.git && git fetch eco && git rm -rf . && git checkout eco/main -- . && git add -A && git commit -m "Apply swift-foundations/swift-copy-on-write ecosystem work on top of coenttb heritage"`
5. `git push origin main` (fast-forward)
6. verify: `git diff --stat eco/main HEAD` empty · `swift build && swift test` · coenttb tail in `git log` · tags preserved · coenttb URL redirects · 1★ preserved
7. `gh api -X PATCH repos/swift-foundations/swift-copy-on-write-ecosystem -f archived=true`

**Review the pilot result together before Wave-1 batch.**

## Outcome

**Status: RECOMMENDATION — staged, nothing executed.**

- Highest-confidence transfer set = **Wave 1 (10 pkgs, pilot-first)** — coenttb-public,
  institute-counterpart-public, owned, no ruling.
- Wave 2 (posix, darwin) gated on split rulings.
- 4 packages **held** (institute counterpart private — would publish WIP).
- 6 **excluded** (coenttb private).
- svg-printer **de-conflict** vs the named-18 program.
- Safety is structural: mirror backups + zero-force-push + archive-not-delete +
  can't-delete-token + per-action auth + verify-gates + human-only final deletion.

**Next action requires your `YES`** to run the pilot's step 4.1 (nothing before that touches
GitHub). Recommend: authorize the pilot end-to-end, review, then batch Wave 1.

## References
- [`coenttb-heritage-inventory-beyond-18.md`](./coenttb-heritage-inventory-beyond-18.md) — the tiered inventory this consumes.
- [`coenttb-ecosystem-heritage-transfer-plan.md`](./coenttb-ecosystem-heritage-transfer-plan.md) — named-18 plan; same transfer-rename-and-reconcile recipe (no drift).
- [`git-history-transfer-patterns.md`](./git-history-transfer-patterns.md) — transfer/apply-on-top mechanics (empirically-verified replacement recipe).
- `swift-package-heritage` skill `[HERITAGE-005]` — owned-source (`gh api .../transfer`) vs external-fork distinction.
