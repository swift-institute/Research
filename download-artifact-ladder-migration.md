---
title: download-artifact v4 → v8 ladder migration
type: investigation
status: RECOMMENDATION
date: 2026-05-05
applies_to:
  - swift-institute/.github/.github/workflows/cron-audit-base.yml
  - swift-institute/.github/.github/workflows/submit-dep-graph-weekly.yml
deadline: 2026-06-02 (Node 20 forced-off on GitHub Actions)
---

# download-artifact v4 → v8 ladder migration

## Recommendation

**Migrate `actions/download-artifact@v4` → `@v8` directly across both
sites with no caller-side changes.** No version-ladder walk needed; no
`merge-multiple: true` adaptation needed; no `find`-vs-glob rewrite
needed.

Empirical run: [`research-download-artifact-ladder` run 25377059431](https://github.com/swift-institute/.github/actions/runs/25377059431)
(SHA `6502afe`, branch `research/download-artifact-ladder`, 2026-05-05).

## Empirical Evidence

A scratch workflow uploaded two artifacts (`test-counts-org1`,
`test-counts-org2`) each carrying `org{N}-counts.txt` + `org{N}-failures.txt`,
mirroring the production cron-audit-base + submit-dep-graph upload shape.
The same artifact set was downloaded by `actions/download-artifact@v4`
through `@v8` into separate paths, then `find -ls` and shell-glob
expansion captured each layout.

### Result — layout is identical across v4..v8

| Version | On-disk layout | `*/*-counts.txt` glob matches |
|---------|----------------|-------------------------------|
| `@v4`   | `/tmp/v4-counts/test-counts-org{1,2}/org{1,2}-{counts,failures}.txt` | 2 matches ✓ |
| `@v5`   | `/tmp/v5-counts/test-counts-org{1,2}/org{1,2}-{counts,failures}.txt` | 2 matches ✓ |
| `@v6`   | `/tmp/v6-counts/test-counts-org{1,2}/org{1,2}-{counts,failures}.txt` | 2 matches ✓ |
| `@v7`   | `/tmp/v7-counts/test-counts-org{1,2}/org{1,2}-{counts,failures}.txt` | 2 matches ✓ |
| `@v8`   | `/tmp/v8-counts/test-counts-org{1,2}/org{1,2}-{counts,failures}.txt` | 2 matches ✓ |

Every version produces an `<artifact-name>/` subdirectory under `path:`,
with files extracted directly inside (no residual `.zip` files, no
flattening). The default behavior is preserved across all five major
versions.

### Side observation — `merge-multiple: true` flattens (v8)

| Variant | On-disk layout |
|---------|----------------|
| `@v8` + `merge-multiple: true` | `/tmp/v8-merge-counts/org{1,2}-{counts,failures}.txt` (flat) |

The flat-flatten variant is documented and works at v8 — useful if a
future caller needs flat layout (none today).

## Why the Prior Session's Diagnosis Was Wrong

A prior session (commits `25e479a` v8 → `6738fe6` v7-pin → `5bdef3f`
v4-revert, all 2026-05-05 ~12:21–12:41 CEST) attempted the v4→v8 bump,
observed CI failures, and reverted with the explanation:

> Both v7 (6738fe6) and v8 (25e479a) produced an on-disk layout where
> the report jobs' `/tmp/counts/*/*.txt` globs find nothing, despite
> the release notes attributing decompression behavior changes only
> to v8. v7 was supposed to retain v4's auto-decompress; canary
> disproved that.

This diagnosis is empirically false. The actual failure mode of the
v7+v8 attempts is independently confirmed: run 25371719434 (post-revert,
SHA `e9b468e`, `download-artifact@v4`) failed with the SAME error:

```
report  Open or update tracking issue  could not add label: 'dep-graph' not found
report  Open or update tracking issue  ##[error]Process completed with exit code 1.
```

The download-artifact step succeeded; the report job failed at the
`gh issue create --label dep-graph` call because the org didn't have
the `dep-graph` label yet. That bug was independently fixed by commit
`ddf3b59` (label-missing fallback). Subsequent v4 runs at `ddf3b59`
and beyond (run 25372048153, run 25372174394) passed.

The prior session attributed three failures (v8 attempt, v7 attempt,
v4 revert) to download-artifact when the only common cause was the
unrelated label-missing bug.

## Why Source Code and Release Notes Both Predicted Layout Parity

| Source | Evidence |
|--------|----------|
| [`actions/download-artifact@v4` source](https://github.com/actions/download-artifact/blob/v4/src/download-artifact.ts) | Path resolution: `path.join(resolvedPath, artifact.name)` for multi-artifact-no-name case |
| [`actions/download-artifact@v8` source](https://github.com/actions/download-artifact/blob/v8/src/download-artifact.ts) | Same path resolution: `path.join(resolvedPath, artifact.name)` for multi-artifact-no-name case |
| v5 release notes | Single-artifact-by-id path nesting fix only; multi-artifact-no-name unchanged |
| v6 release notes | `@actions/artifact` package bump to v4.0.0; no path-resolution changes |
| v7 release notes | Node.js 24 runtime requirement (min runner 2.327.1+); no path-resolution changes |
| v8 release notes | Hash-mismatch errors default; ESM module migration; Content-Type-aware decompression. The "no longer attempt to unzip all" phrase refers to non-zip artifacts; zip artifacts (default `archive: true` from `actions/upload-artifact@v7`) decompress as before |

The empirical capture confirms the source-code prediction: layout is
preserved end-to-end.

## Migration Mechanics

### Scope

```bash
grep -rln "actions/download-artifact@v4" \
  /Users/coen/Developer/swift-institute/.github/.github/workflows/
# 2 files:
#   .github/workflows/cron-audit-base.yml
#   .github/workflows/submit-dep-graph-weekly.yml
```

### Diff

For each file, single-line bump:

```diff
-      - uses: actions/download-artifact@v4
+      - uses: actions/download-artifact@v8
         with:
           path: /tmp/counts
```

No caller-side changes (`merge-multiple` not introduced; consumer
shell scripts unchanged; `/tmp/counts/*/*-counts.txt` glob unchanged).

### Canary

Both workflows are scheduled-only with `workflow_dispatch`. Per [CI-050]
mass-rollout discipline + [CI-052] gate, each push to `main` requires
explicit per-action authorization. After each push:

```bash
gh workflow run submit-dep-graph-weekly.yml --ref main --repo swift-institute/.github -f dry-run=true
gh run watch <run-id> --exit-status
# Verify report job exits 0 with v8 download
```

For `cron-audit-base.yml` (a `workflow_call` reusable, not directly
invocable), the canary fires on any `lint-*-weekly.yml` consumer:

```bash
gh workflow run lint-license-header-weekly.yml --ref main --repo swift-institute/.github
```

## Schedule

- **Today (2026-05-05)**: research complete, recommendation ready.
- **Migration push window**: any time before 2026-05-26 (gives 1 week
  slack for canary observation before 2026-06-02 Node 20 forced-off).
- **Step 1c migration**: one push per file, per-action auth, canary
  per file.

## Cleanup

The scratch workflow `research-download-artifact-ladder.yml` lives on
branch `research/download-artifact-ladder` only. Branch deleted after
this research note is committed; no main-branch trace.

## Cross-References

- [`HANDOFF-ci-action-version-tail.md`](../../HANDOFF-ci-action-version-tail.md) Step 1 (this work)
- `feedback_no_public_or_tag_without_explicit_yes.md` (per-push auth)
- [CI-050], [CI-051] (mass-rollout discipline; this is 2 surgical commits)
- [CI-031] reusable-consumption pattern
