# CI/CD Workflows Skill Rationale Archive

<!--
version: 1.0.0
last_updated: 2026-07-05
status: REFERENCE
-->

> Non-normative companion to `Skills/ci-cd-workflows/SKILL.md` (per Research/ecosystem-meta-setup-target-state.md §D1).
> This document holds evicted incident narratives, provenance notes, bookkeeping audit trails, and
> relationship-to-adjacent-rule essays. The skill file remains the CANONICAL source for all `[CI-*]`
> requirement statements; nothing in this archive is normative. Organized by rule ID.

---

## §[CI-044] Tool-Binary Cache — Known Non-Conformances (evicted 2026-07-05)

Bookkeeping audit trail evicted from the skill; both entries are resolved. The present-tense rule body in-skill is the canonical corpus; this is the translated live-state record.

### Known Non-Conformances

The following live workflow files did not satisfy the caching rules. Each is tracked for follow-up; entries are **not** deleted on resolution — the fix-commit SHA is appended and the row marked "Resolved" so the historical record survives.

| File | Violation | Rule(s) | Status |
|---|---|---|---|
| `swift-primitives/.github/.github/workflows/swift-ci.yml` (embedded job) | Carried `restore-keys: linux-embedded-${{ inputs.cache-key-prefix }}-` partial-prefix fallback alongside an otherwise-correct exact-match `key:`. | [CI-042] | **Resolved `44b5acb`** (2026-05-04) — single-line removal of `restore-keys:`; `key:` retained as exact-match per the [CI-040] carve-out. |
| `swift-institute/.github/.github/workflows/swift-docs.yml` (docs job) | Cached `.build/` with `key: macos-${{ inputs.cache-key-prefix }}-${{ hashFiles(...) }}` AND `restore-keys: macos-${{ inputs.cache-key-prefix }}-` partial-prefix. | [CI-040], [CI-042] | **Resolved `2d1f6b8`** (2026-05-04) — entire `actions/cache@v5` step removed (no carve-out applied: DocC traverses the same dependency graph as the universal matrix). |

**Resolution discipline**: when a fix lands, append the fix-commit SHA to the row's Status column (e.g., "Resolved `abc1234`") in the same commit-wave that lands the fix. The aspirational citation per [SKILL-LIFE-027] is satisfied by the present-tense rule body; this sub-section is the bookkeeping that translates "the rule corpus is correct" into "the live state matches the corpus."

---

## §[CI-110] Mixed-Trigger Null-Coerce — Provenance Notes (evicted 2026-07-05)

**Provenance note — the tab-then-anchor grep-trap in `validate-base.yml` (2026-07-03, non-normative)**: the same regex-tooling-trap class bit the `validate-base.yml` "Aggregate findings" step. It counted violations with `grep -cE "<TAB>${RULE_ID_REGEX}" /tmp/findings.tsv`, while every one of the 18 thin callers passes a `^`-anchored `rule-id-regex` (`^CI-032`, `^PATTERN-`, …). The effective pattern `<TAB>^CI-NNN` placed a line-start anchor mid-pattern and matched ZERO lines, so `violations` was structurally pinned to 0, the gate never fired, and (with the validator's own exit code separately swallowed by `|| true` at the Run-validator step) all 18 validate-base consumers were rendered inert and reported "Total violations: 0" false-green. Fixed by reusing the summary table renderer's field-match predicate (`awk -F'\t' '$2 ~ re'`) for the count so the count and the table share one predicate and can never disagree; a clone-failed sentinel gate was added in the same change. Fix: swift-institute/.github `12c9d5a`. This note records the incident; it makes no change to any Statement.

**Follow-up (2026-07-05, Phase-3 review, non-normative)**: the `|| true` exit-code swallow flagged above was itself a residual false-green — a validator that cloned cleanly then crashed (an uncaught exception, or `validate_lib.require_yaml()`'s import-time `sys.exit(2)` on missing PyYAML) wrote zero TSV rows, so the run reported "Total violations: 0" green with the validator never having produced usable output. Closed by a `validator-crashed` sentinel that mirrors the clone-failed mechanism exactly: the Run-validator step now captures the validator's exit code without tripping `set -e` (`python3 "$VALIDATOR" … >> /tmp/findings.tsv || rc=$?`) and appends a `<repo><TAB>validator-crashed<TAB>-` row on nonzero rc — genuine, because the validators are signal-via-TSV and return 0 even with findings, so nonzero means crash/abort, not violations. The aggregation counts those rows (kept out of the `RULE_ID_REGEX` violation count exactly as clone-failed is, since `validator-crashed` matches no `^`-anchored rule regex), surfaces a CAUTION block + an `::error::` annotation, and includes them in the exit-1 gate. Reproduced with the step's verbatim shell logic (pre-fix crash greens; post-fix exits 1). Fix: swift-institute/.github `0abdfa1`. This note records the incident; it makes no change to any Statement.

**Provenance note — validator fail-fixture backfill (2026-07-03, non-normative)**: distinct from the grep-trap above, a companion non-inertness gap surfaced in the same review — four validators (`docc-structure`, `readme`, `github-metadata`, `package-structure`) carried only PASS fixtures, with no FAIL fixture proving the validator actually fires on a known-bad input. A pass-only fixture set cannot distinguish a working validator from an inert one — exactly the false-green class the grep-trap produced. **Two of the four were fixtured this arc** (fail+pass, registered in `run.sh`): `validate-docc-structure` (fixture `doc-020`) and `validate-readme` (fixture `readme-017`). **The other two remain a residual harness-coverage gap within the per-repo-scan (`validate-base`/TSV) validator family**: `validate-github-metadata` and `validate-package-structure` do not fit `run.sh`'s uniform 2-arg dir-scan contract — github-metadata needs a 3-arg `<repo> <metadata-yaml> <schema-json>` invocation plus `jsonschema`/PyYAML, and package-structure consumes `swift package describe --type json`. Their non-inertness was confirmed out-of-band 2026-07-03: the seat positive-controlled `package-structure` directly (crafted fail JSON → `MOD-012-domain-undetectable`; pass JSON → 0 findings), and `github-metadata` — not locally runnable here (missing deps) — has a loud-error failure mode (not silent-pass) and runs in CI. Both are tracked as a successor item: extend `run.sh` to a per-validator invocation contract (plus a `swift package describe`-JSON fixture mode) to close automated regression coverage. **Out-of-family (2026-07-05, Phase-3 review)**: `validate-schema-workflow-keys.py` (post-arc `fa505a6`, [GH-REPO-063] domain; zero-arg, self-locating, non-TSV, embedded as a single step in `validate-github-metadata.yml` alongside — but distinct from — the `validate-github-metadata.py` TSV validator above) is NOT part of this residual gap: it isn't a per-repo-scan/TSV-family validator at all, so `run.sh`'s 2-arg contract doesn't apply to it. Its fixture tracking belongs under the **github-repository** skill charter, not here. This note records the provenance; it makes no change to any Statement.

---

## §[CI-111] Mass Mechanical Rewrite Scripts — Sub-Shapes, Provenance, Relationship (evicted 2026-07-05)

**Two failure sub-shapes the skip-check prevents**:

| Sub-shape | Example |
|-----------|---------|
| **Re-splitting** — the extraction regex treats both fresh targets AND already-transformed forms as input | `` `flatMap transforms and flattens` `` → `` `flat map transforms and flattens` `` (the API reference `flatMap` is split apart) |
| **Case-destruction** — stripping + re-splitting a backticked span lowercases sentence-start caps and splits symbols | `` `Int(bitPattern: x.rawValue) is flagged` `` → `` `int(bit pattern: x.rawvalue) is flagged` `` |

Both arise from an identifier-extraction regex of the form `` (`[^`]+`|[a-z][a-zA-Z0-9_]*) `` that matches pre-existing backticked names alongside fresh camelCase, then unconditionally strips backticks and re-splits.

**Provenance (full form)**: 2026-05-15 camelCase→backticked `@Test`-name rename across the data-structures cohort. The extraction regex matched both fresh camelCase and pre-existing backticked names; `transform_name` stripped backticks and re-split, producing 125 cosmetic regressions across sequence-primitives (37 backticked names destroyed), cyclic-primitives (41 destroyed, sentence-start caps lowercased), and primitives-linter-rules (47 destroyed, symbols split inside backticked names). Every case still passed the lint rule (the name still contained a space) — the regression was invisible to canary verification and surfaced only on diff inspection during the cascade commit; all three packages were reverted. Concurrent parallel-iteration churn (`feedback_parallel_workspace_no_build`) meant canary verification was already shaky, shifting additional regression-detection responsibility onto the author. Memory `feedback_rename_script_preserve_backticked`.

**Relationship to [CI-051]/[CI-056]**: [CI-051] covers surgical-commit + dirty-skip discipline; [CI-056] gates source-modifying rollouts on per-package build-verify. [CI-111] adds the transform-CORRECTNESS gate for mass mechanical rewrites — a build-green, lint-green rewrite can still be semantically wrong, so a sample diff-inspection (and pre-existing-form skip) is mandatory before commit.
