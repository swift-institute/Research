---
title: download-artifact v4 → v8 ladder migration
type: investigation
status: INVESTIGATING
date: 2026-05-05
applies_to:
  - swift-institute/.github/.github/workflows/cron-audit-base.yml
  - swift-institute/.github/.github/workflows/submit-dep-graph-weekly.yml
deadline: 2026-06-02 (Node 20 forced-off on GitHub Actions)
---

# download-artifact v4 → v8 ladder migration

## Status: INVESTIGATING (downgraded 2026-05-05)

The original v1.0.0 RECOMMENDATION (direct v4→v8 with no caller-side
changes) was **falsified in production** within hours of being authored.
This document is now the empirical record of what went wrong, what the
actual v4..v8 behavior is for our matrix shape, and what the redesign
target (Path A — layout-agnostic `find` rewrite) needs to satisfy
before re-promotion to RECOMMENDATION.

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

## Why the Original Research Missed This (Premise-Staleness Defect, Layer 2)

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

## Forward Path — Path A (layout-agnostic `find` rewrite)

The redesign target is to make the consumer scripts **layout-agnostic**
so they work uniformly under both nested (v4 always; v8 multi-artifact)
and flat (v8 single-artifact; future versions; `merge-multiple: true`)
layouts. The org name is recoverable from the **filename** (`<org>-counts.txt`),
so the dependency on artifact-directory names can be eliminated.

### Sketch

```bash
# Original (couples to nested layout):
for f in /tmp/counts/*/*-counts.txt; do
  artifact_dir=$(basename "$(dirname "$f")")
  org="${artifact_dir#cron-audit-counts-}"
  ...
done

# Path A (layout-agnostic):
while IFS= read -r f; do
  filename=$(basename "$f")
  org="${filename%-counts.txt}"
  ...
done < <(find /tmp/counts -type f -name '*-counts.txt')
```

`find` walks the tree at any depth, matching `*-counts.txt` regardless
of whether files sit at `<path>/<artifact-name>/<file>` or `<path>/<file>`.
The org name is parsed from the filename's `<org>-counts.txt` suffix
strip, which is stable across layouts.

The same shape applies to the `*-failures.txt` and `*-extra.txt` loops
in submit-dep-graph-weekly.yml and cron-audit-base.yml respectively.

### Validation Gate (before re-promotion to RECOMMENDATION)

The redesigned research workflow MUST exercise BOTH:
- Single-artifact case (mirrors current production matrix shape)
- Multi-artifact case (mirrors future N-org matrix expansion)

For each case, BOTH the original glob `/tmp/counts/*/*-counts.txt`
AND the proposed Path A `find /tmp/counts -name '*-counts.txt'` are
captured against actual download output, against `download-artifact@v8`.

Path A is the migration target only if it matches the same files in
both cases against v8. If it breaks in either case, halt; do not
improvise.

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
| [25377059431](https://github.com/swift-institute/.github/actions/runs/25377059431) | 6502afe | Original research: 2-artifact fixture, v4..v8 ladder | "layout identical" finding (correct for fixture, inapplicable to production) |
| [25377628270](https://github.com/swift-institute/.github/actions/runs/25377628270) | 363208d | Production canary: submit-dep-graph-weekly with v8 + 1-org matrix | **failure** — glob no-match, exit 1 |
| [25377635397](https://github.com/swift-institute/.github/actions/runs/25377635397) | 363208d | Production canary: lint-license-header-weekly with v8 + 1-org matrix | success but **silent false-positive** (guard-skipped, "all counts zero") |
| [25378241367](https://github.com/swift-institute/.github/actions/runs/25378241367) | 1092349 | Post-revert canary: submit-dep-graph-weekly | success — confirms v4 restoration |
| [25378247875](https://github.com/swift-institute/.github/actions/runs/25378247875) | 1092349 | Post-revert canary: lint-license-header-weekly | success — real data path, updated tracking issue #9 |
