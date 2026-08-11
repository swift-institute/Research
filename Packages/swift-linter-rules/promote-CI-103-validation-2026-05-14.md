# Validation receipt: [CI-103]

Date: 2026-05-14
Rule: CI-103 (workflow-level `env:` MUST NOT be referenced from `runs-on:` or `container:` — Actions resolves these fields before workflow-level `env:` is bound, producing parse-time HTTP 422)
Detection target: `<repo>/.github/workflows/*.yml,yaml` — per-job inspection of `runs-on:` (string/list) and `container:` (string/dict)
Detection method: workflow validator (PyYAML per-job inspection; single-repo multi-file integrity check sub-shape)
Pilot: twenty-first pilot of `/promote-rule`

## Validator + reusable workflow

- Script: `swift-institute/.github/.github/scripts/validate-env-context.py` (~140 lines; new; `chmod +x` applied)
- Reusable workflow: `swift-institute/.github/.github/workflows/validate-env-context.yml` (new; self-firing `push:` / `pull_request:` triggers ACTIVE)
- Test harness: `swift-institute/.github/.github/scripts/tests/run.sh` registers `ci-103 → CI-103`

## Synthetic fixtures

| Kind | Scenario | Expected | Actual | Status |
|---|---|---:|---:|---|
| pass | swift-inputs-context | 0 | 0 | PASS |
| pass | swift-literal-and-other-contexts | 0 | 0 | PASS |
| fail | swift-env-in-container | ≥1 | 1 | PASS |
| fail | swift-env-in-runs-on | ≥1 | 1 | PASS |
| edge | swift-env-in-step-run | 0 | 0 | PASS |
| edge | swift-container-dict-image-literal | 0 | 0 | PASS |

6/6 fixtures pass. Full harness 132/132 pass (126 prior + 6 new).

## Ground-truth probe

Scope: 4 layer-wrapper-host repos.

| Target | CI-103 findings |
|---|---:|
| `swift-institute/.github` | 0 |
| `swift-primitives/.github` | 0 |
| `swift-standards/.github` | 0 |
| `swift-foundations/.github` | 0 |

**Baseline: 0/4 wrapper-host repos.**

Pre-validation inspection confirmed: live workflows use `inputs.*` parameterization (e.g., `container: swift:${{ inputs.swift-version }}` at `swift-ci.yml`, `lint-api-breakage.yml`, `lint-test-support-spine.yml`, `swift-docs.yml`) or literal (`container: swift:6.3` at `submit-dep-graph-weekly.yml`, `validate-github-metadata.yml`). Neither pattern matches the validator's `env.X` discriminator.

Pilot 21 is **regression-prevention**: the validator catches re-introduction of the 2026-05-05 incident class (commits `ecf36e6` + `91dd8db` broke 2 cron orchestrators with parse-time HTTP 422; fix `e9b468e` reverted within hours).

Self-firing triggers ACTIVE immediately (no batch-fix arc needed).

## Counts vs `[PROMOTE-004]` budget

| Level | Diagnostic count budget | Observed |
|---|---:|---:|
| Hard (default per `[PROMOTE-004]`) | 10 | 0 |

Well under budget. Regression-prevention pilot.

## Discrimination tightness

The validator's regex `\$\{\{\s*env\.\w+` is anchored to the Actions expression syntax with `env.` as the context discriminator. Other contexts (`inputs.`, `vars.`, `matrix.`, `github.`, `secrets.`) explicitly do NOT match.

The rule body's How-to-apply table doubles as the validator's allowlist: every permitted alternative (`inputs.*`, `vars.*`, literal, `matrix.*`) corresponds to a context name the regex doesn't capture. Validator discrimination is mechanical from the rule body's text — no natural-language judgment needed.

## Cross-references

- Outcome record: `swift-institute/Audits/PROMOTE-CI-103-2026-05-14.md`
- Predecessor receipts:
  - `promote-CI-105-validation-2026-05-14.md` (pilot 19 — adjacent context-availability rule on workflow_call'd jobs)
  - `promote-CI-080-validation-2026-05-14.md` (pilot 15 — first PyYAML-walk per-job validator)
- Skill rule: `swift-institute/Skills/ci-cd-workflows/SKILL.md` `[CI-103]` (compressed)
- Memory predecessor: `feedback_env_invalid_in_runs_on_container.md`
