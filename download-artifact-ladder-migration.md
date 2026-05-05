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

## Recommendation (v2.0.0)

**Migrate `actions/download-artifact@v4` → `@v8` AND bundle a
layout-agnostic `find`-based rewrite of the consumer scripts (Path A)
in the same per-file commit.** Single-line bumps without the
caller-side rewrite are the falsified v1.0.0 shape; do not repeat.

For each consumer:

```diff
-      - uses: actions/download-artifact@v4
+      - uses: actions/download-artifact@v8
         with:
           path: /tmp/counts
```

Plus, in each consumer's report-job aggregation script:

```diff
-          for f in /tmp/counts/*/*-counts.txt; do
-            [[ -e "$f" ]] || continue
-            artifact_dir=$(basename "$(dirname "$f")")
-            org="${artifact_dir#<consumer-prefix>-}"
+          while IFS= read -r f; do
+            [[ -z "$f" ]] && continue
+            org=$(basename "$f" | sed 's/-counts\.txt$//')
             ...
-          done
+          done < <(find /tmp/counts -type f -name '*-counts.txt')
```

The same shape applies to `*-failures.txt` / `*-extra.txt` loops.
Per-consumer prefix-strip on `dirname` is replaced with suffix-strip
on `basename`, preserving org-name recovery regardless of layout.

## Validation Evidence — Redesigned Research Run 25378551607

[`research-download-artifact-redesign` run 25378551607](https://github.com/swift-institute/.github/actions/runs/25378551607)
(SHA `99a4f3d`, branch `research/download-artifact-redesign`,
2026-05-05) exercises BOTH single-artifact and multi-artifact cases
against `download-artifact@v8`, with v4 single-artifact as control.

| Case | Layout produced by v8 | Original glob `<path>/*/*-counts.txt` | Path A `find -name '*-counts.txt'` | Path A === v4-original? |
|------|----------------------|---------------------------------------|------------------------------------|-------------------------|
| Single artifact (production matrix-leg shape) | **flat:** `/tmp/counts/<file>` | **0 matches (miss)** | 1 match ✓ | ✓ matches v4-control's 1-match |
| Multi-artifact (N=2; future expansion shape) | nested: `/tmp/counts/<artifact-name>/<file>` | 2 matches ✓ | 2 matches ✓ | ✓ matches v4 |
| **Control** v4 single-artifact | nested: `/tmp/counts/<artifact-name>/<file>` | 1 match ✓ | 1 match ✓ | ✓ baseline |

Per-file org extraction sanity-check (Path A → basename + suffix-strip):
in the v8 single-artifact case, the file at `/tmp/counts/swift-primitives-counts.txt`
yields `org=swift-primitives` correctly. In the multi-artifact case,
files at `/tmp/counts/depgraph-counts-multi-swift-{standards,foundations}/swift-{standards,foundations}-counts.txt`
yield `org=swift-{standards,foundations}` correctly. The basename/suffix
shape is layout-independent.

## Falsification of v1.0.0 (preserved as record)

The v1.0.0 RECOMMENDATION (direct v4→v8 with no caller-side changes)
was applied at commits `198b4b2` (cron-audit-base.yml) + `363208d`
(submit-dep-graph-weekly.yml) on swift-institute/.github main. Both
canaries against the post-bump SHA revealed regressions invisible to
the original 2-artifact research workflow:

| Canary | Run ID | Conclusion | Failure mode |
|--------|--------|-----------|--------------|
| `submit-dep-graph-weekly.yml` (dry-run) | [25377628270](https://github.com/swift-institute/.github/actions/runs/25377628270) | **failure** | `report` job: `/tmp/counts/*/*-counts.txt: No such file or directory`, exit 1 |
| `lint-license-header-weekly.yml` (calls cron-audit-base.yml) | [25377635397](https://github.com/swift-institute/.github/actions/runs/25377635397) | success | **silent false-positive**: `[[ -e "$f" ]] \|\| continue` guard absorbed the empty glob; report job emitted "All counts zero across orgs — no tracking issue needed." despite the actual sweep finding violations |

Both commits were reverted at `1092349` + `d2c7e3d`. Post-revert
canaries (`25378241367` + `25378247875`) confirmed v4 production
behavior is restored.

The `lint-license-header-weekly` silent-success path is the more
dangerous regression: a workflow that returns green while never
actually reading the artifact data would mask drift across all 5
weekly orchestrators that route through `cron-audit-base.yml`. Path A
eliminates this failure mode by making layout drift visible (find
returns empty → loop body runs zero times → no spurious matches), but
also actually MATCHES the data when present (which the original glob
fails to do under v8 single-artifact-flatten).

## Falsification (2026-05-05)

The v4→v8 migration was applied at commits `198b4b2`
(cron-audit-base.yml) + `363208d` (submit-dep-graph-weekly.yml) on
swift-institute/.github main. Both canaries against the post-bump SHA
revealed regressions invisible to the original research workflow:

| Canary | Run ID | Conclusion | Failure mode |
|--------|--------|-----------|--------------|
| `submit-dep-graph-weekly.yml` (dry-run) | [25377628270](https://github.com/swift-institute/.github/actions/runs/25377628270) | **failure** | `report` job: `/tmp/counts/*/*-counts.txt: No such file or directory`, exit 1 |
| `lint-license-header-weekly.yml` (calls cron-audit-base.yml) | [25377635397](https://github.com/swift-institute/.github/actions/runs/25377635397) | success | **silent false-positive**: `[[ -e "$f" ]] \|\| continue` guard absorbed the empty glob; report job emitted "All counts zero across orgs — no tracking issue needed." despite the actual sweep finding violations |

Both commits were reverted at `1092349` + `d2c7e3d`. Post-revert
canaries (`25378241367` + `25378247875`) confirmed v4 production
behavior is restored.

The `lint-license-header-weekly` silent-success path is the more
dangerous regression: a workflow that returns green while never
actually reading the artifact data would mask drift across all 5
weekly orchestrators that route through `cron-audit-base.yml`.

## Why the v1.0.0 Research Missed This (Premise-Staleness Defect, Layer 2)

The research workflow (run [25377059431](https://github.com/swift-institute/.github/actions/runs/25377059431))
uploaded **two** artifacts (`test-counts-org1`, `test-counts-org2`) and
exercised v4..v8 download into separate paths. All five versions
produced identical nested layouts. The conclusion — "layout is
identical across v4..v8, no caller-side changes needed" — was correct
**for that fixture**.

The fixture diverged from production. Production matrix legs in both
target workflows are currently:

```yaml
matrix:
  org:
    - swift-primitives
```

— a **single-org matrix**, producing a **single artifact per matrix
leg** at the report-job aggregation step. v8 introduces a path-resolution
branch that v4 lacks specifically for this case:

| Version | Multi-artifact (`artifacts.length > 1`) | Single-artifact (`artifacts.length === 1`) |
|---------|------------------------------------------|--------------------------------------------|
| `@v4`   | nested: `<path>/<artifact-name>/<file>` | nested: `<path>/<artifact-name>/<file>` |
| `@v8`   | nested: `<path>/<artifact-name>/<file>` | **flat: `<path>/<file>`** |

Source-of-truth diff:

| File | v4 condition | v8 condition |
|------|--------------|--------------|
| `actions/download-artifact/src/download-artifact.ts` (multi-artifact branch) | `isSingleArtifactDownload \|\| inputs.mergeMultiple` | `isSingleArtifactDownload \|\| inputs.mergeMultiple \|\| artifacts.length === 1` |

The `artifacts.length === 1` branch in v8 — flatten when only one
artifact matched — was never exercised by the 2-artifact research
fixture. Production exercises it on every matrix leg.

This is the second layer of premise-staleness in this work
(the first was the inherited handoff's "v7+v8 layout broken"
attribution to layout when the actual cause was an unrelated
label-missing bug). Both layers compound: a research workflow
correct-for-its-fixture but inapplicable to production produces
RECOMMENDATIONs that empirically falsify in production.

## Why Path A Is the Right Shape

`find` walks the tree at any depth, matching `*-counts.txt` regardless
of whether files sit at `<path>/<artifact-name>/<file>` (nested) or
`<path>/<file>` (flat). The org name is parsed from the filename's
`<org>-counts.txt` suffix-strip rather than from the artifact-directory
name's prefix-strip — moving the org extraction off the layout-coupled
dirname onto the layout-stable basename.

This is uniformly correct under:
- v4 always (nested)
- v8 multi-artifact (nested)
- v8 single-artifact (flat — the regression case)
- `merge-multiple: true` (flat — future use)
- Any future v9+ that adds further branches

The single behavioral difference Path A introduces vs. the original:
when v8 single-artifact-flattens, Path A FINDS the data, whereas the
original glob silently misses it. That is the entire point.

### Side observation — `merge-multiple: true` flattens (v8)

| Variant | On-disk layout |
|---------|----------------|
| `@v8` + `merge-multiple: true` | `/tmp/<path>/<file>` (flat) |

This was captured in the v1.0.0 research run (25377059431). It is
NOT the chosen migration target because it would force flat layout
even for the multi-artifact case where the consumer prefix
(`cron-audit-counts-` vs `depgraph-counts-`) currently distinguishes
artifacts. Path A avoids this by adapting the consumer to the layout
v8 produces, rather than forcing the layout.

## Cross-References

- [`HANDOFF-ci-action-version-tail.md`](../../HANDOFF-ci-action-version-tail.md)
  Step 1 (this work; updated with Premise-Falsification subsection)
- `feedback_no_public_or_tag_without_explicit_yes.md` (per-push auth)
- [CI-050], [CI-051] (mass-rollout discipline)
- Memory candidate: `feedback_research_workflow_must_mirror_production_shape.md`
  (research fixtures must mirror production shape; 2-artifact fixture
  for 1-artifact production produced a recommendation that empirically
  falsified)

## Run Manifest

| Run ID | SHA | What it tested | Outcome |
|--------|-----|----------------|---------|
| [25377059431](https://github.com/swift-institute/.github/actions/runs/25377059431) | 6502afe | v1.0.0 research: 2-artifact fixture, v4..v8 ladder | "layout identical" finding (correct for fixture, inapplicable to production) |
| [25377628270](https://github.com/swift-institute/.github/actions/runs/25377628270) | 363208d | Production canary: submit-dep-graph-weekly with v8 + 1-org matrix | **failure** — glob no-match, exit 1 |
| [25377635397](https://github.com/swift-institute/.github/actions/runs/25377635397) | 363208d | Production canary: lint-license-header-weekly with v8 + 1-org matrix | success but **silent false-positive** (guard-skipped, "all counts zero") |
| [25378241367](https://github.com/swift-institute/.github/actions/runs/25378241367) | 1092349 | Post-revert canary: submit-dep-graph-weekly | success — confirms v4 restoration |
| [25378247875](https://github.com/swift-institute/.github/actions/runs/25378247875) | 1092349 | Post-revert canary: lint-license-header-weekly | success — real data path, updated tracking issue #9 |
| [25378551607](https://github.com/swift-institute/.github/actions/runs/25378551607) | 99a4f3d | v2.0.0 research: redesigned single + multi-artifact + v4-control fixtures, glob vs Path A match-set capture | **gate passed** — Path A recovers file in v8 single-artifact-flatten case where original glob misses; identical behavior for nested cases |
