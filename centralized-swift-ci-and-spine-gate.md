# Centralized Swift CI/CD and the Test Support Spine Gate

<!--
---
version: 1.3.0
last_updated: 2026-05-05
status: RECOMMENDATION
research_tier: 2
applies_to: [institute, primitives, standards, foundations, body-orgs]
normative: false
---
-->

## Changelog

- **v1.3.0 (2026-05-05)**: Implementation lessons appendix (§3.5) added after empirical Phase β + γ-1a + γ-1b + γ-1c + γ-2 + γ-2b + γ-3 + γ-4 rollout to swift-institute/.github + swift-primitives/.github layer wrapper. Seven runtime-correctness corrections to the v1.1.0/v1.2.0 spec, each backed by a specific failed CI run and a fix commit. The most consequential: `continue-on-error: true` at the calling site of a `workflow_call` job is INVALID YAML in GitHub Actions — only regular jobs and steps support it. The advisory/gating switch must live as an `advisory: bool` input on the called reusable, gated inside the run step's `exit 1` line. §1.4-§1.5 reference text is annotated with the correction; the canonical pattern lives in §3.5. Phase β + γ-1a/b/c + γ-2 + γ-4 all landed advisory and verified green on swift-carrier-primitives + swift-tagged-primitives canaries on 2026-05-05. γ-2b dep-graph submission DEFERRED again (different reason than v1.1.0): the called workflow's `permissions: contents: write` declaration causes `startup_failure` across the consumer→layer-wrapper→universal call chain when the outer levels don't grant it; resolution requires either (a) declaring `contents: write` at every call-chain level, OR (b) a non-reusable invocation pattern (per-package opt-in workflow). γ-3 Wasm SDK landed in the swift-primitives layer wrapper; SDK install succeeds, `swift build --swift-sdk swift-6.3-RELEASE_wasm-embedded` fails with "module compiled with Swift 6.3 cannot be imported by 6.3.1" — classified as B (toolchain) under the four-class soak. The advisory captures it correctly; mismatch resolves when the published Wasm SDK matches the container's Swift version.
- **v1.2.0 (2026-05-04)**: Principal-driven correction post-convergence. The v1.1.0 deferral of GH dependency-graph submission was over-calibrated against a static "private packages stay private" reading; the principal clarified that intra-Institute private packages will go public on a near-term timeline. Re-analysis decomposes the original privacy concern into three sub-concerns (Sub-1: name leakage of currently-private packages BEFORE they go public — time-bounded; Sub-2: relationship disclosure between two public packages — generally a feature, not a bug; Sub-3: pre-1.0 refactor churn — not specific to dep-graph submission). Only Sub-1 was load-bearing for the deferral; it dissolves on the publish-wave timeline. **Resolution**: GH dep-graph submission promoted from DEFERRED to **γ-2b** (advisory now, alongside γ-2 mechanical hygiene). New §3.4.5b documents the design (separate `submit-dep-graph.yml` reusable; SHA-pinned `vapor-community/swift-dependency-submission`; push-to-main only; `permissions: contents: write` at calling site per `[CI-026]` Path B; public-only via `[CI-032]`). §3.4.1 roadmap table updated; §3.4.8 retained but reframed as "what remains deferred" (now empty). §Outcome updated. §3.4.10 graduation table updated (judgment-based: monthly review of submission success rate + Dependabot signal-to-noise). The collaborative-discussion conclusion at v1.1.0 stays in the historical record — it represents what the 4-round Claude+ChatGPT conversation concluded under the framing it had; v1.2.0 represents the principal's post-discussion correction with the additional information about the publish wave.
- **v1.1.0 (2026-05-04)**: Converged plan after collaborative discussion (Claude + ChatGPT, 4 rounds, transcript at `/tmp/ci-improvements-catalog-transcript.md`, converged artifact at `/tmp/ci-improvements-catalog-converged.md`). User selected 8 capabilities from §3.1's catalog: Foundation-import, License-header, broken-symlink, YAML lint, commit-lint, Embedded Wasm SDK, Static SDK Linux musl. Discussion produced material refinements: γ-1 split into γ-1a (Foundation) / γ-1b (License-header three-step) / γ-1c (API-breakage advisory pilot, four-class tracking — promoted from P3 deferred); Foundation rule extended to family (`Foundation`, `FoundationEssentials`, `FoundationInternationalization`) with full attribute matrix including `@preconcurrency`; License-header surfaced as advisory→codemod→gate three-step (empirical: L1 source files currently lack Apache 2.0 headers); commit-lint reframed as PR-title lint at γ-4 (squash-merge alignment); Static SDK Linux musl lifted from "P5 unfit" to "γ-3b advisory if cheap" after the unlimited-public-minutes correction reframed cost calculus from minutes-constrained to signal-constrained; GH dep-graph submission DEFERRED — sharper, not weaker, given private-package leakage from public consumers' graphs (verified: `swift-property-primitives` is public and depends on private siblings); two-track audit model (public CI + principal-side periodic on-disk audit) bridges the public-only-CI ecosystem-coverage gap; graduation models formalized per check class (deterministic / pilot-classified / fidelity-classified / judgment-based). §3 fully rewritten; §Outcome updated. §1 and §2 unchanged from v1.0.0. **NOTE**: v1.1.0's GH dep-graph deferral SUPERSEDED by v1.2.0 per principal correction — see v1.2.0 changelog.
- **v1.0.0 (2026-05-04)**: Initial RECOMMENDATION. Phase β advisory CI gate design for `[MOD-024]`; literature survey of 9 Swift orgs at verified main-SHAs; improvements catalog (20 capabilities, 6 priority bands P0–P5).

## Context

### Trigger

Phase 2a of the Test Support spine rollout landed 2026-05-04 (51 commits across 49 swift-primitives repos, audit clean: 0 violations, 0 missing). Phase α — `[MOD-024]` Test Support Spine Discipline — is committed in the modularization skill. The next phase (β, advisory CI gate) needs a durable design that fits inside the broader centralization architecture, not as a one-off bolt-on.

This investigation answers three coupled questions in one place:

1. **Phase β** — design and place the advisory workflow that runs `preflight-test-support-spine.py` on PRs. Per the parent handoff Key Decision #4, the gate lives at `swift-institute/.github/.github/workflows/lint-test-support-spine.yml` (universal reusable). β→γ transition is two consecutive weeks of zero violations across all in-scope org-dirs.
2. **Literature survey** — what other Swift open-source ecosystems do for cross-repo CI/CD on GitHub. Capture: centralization model, enforcement, matrix shape, caching, secrets, version pinning, format/lint, link-checking, doc-build, release automation. Principle: don't recreate from first principles what the broader Swift community has already converged on.
3. **Improvements / additions catalog** — what could swift-primitives' centralized CI/CD adopt that it doesn't already have, ranked by priority.

### Scope

Ecosystem-wide [RES-002a]. Affects swift-primitives + swift-standards + swift-foundations + the per-authority sub-orgs (`swift-iso`, `swift-iec`, `swift-ietf`, `swift-ieee`, `swift-w3c`, `swift-whatwg`, `swift-ecma`, `swift-incits`, `swift-linux-foundation`, `swift-microsoft`, `swift-arm-ltd`, `swift-intel`, `swift-riscv`) and the `swift-institute` infra org. Out of scope: `coenttb/*`, external-compat packages, rule-law / legal sub-ecosystems.

### Prior research (carry-forward; cite-and-extend per [HANDOFF-013])

Two prior Tier-2 RECOMMENDATIONs constrain the design space:

- **[`ci-centralization-strategy.md`](ci-centralization-strategy.md) v1.1.0 (2026-04-22)** — established Option A (reusable workflows) as the foundational pattern + Option D (sync-script) for per-repo configs; rejected Option B (rulesets — Team+ plan gated) and Option C (subtree). Permission scoping landed Path B (per-caller). This doc EXTENDS — does not replace — that recommendation.
- **[`ci-cache-strategy-branch-pinned-dependencies.md`](ci-cache-strategy-branch-pinned-dependencies.md) v1.1.0 (2026-05-04)** — established no-`.build/`-cache as permanent under the gitignored-`Package.resolved` constraint, aligned with Apple's canonical `swiftlang/github-workflows/swift_package_test.yml` (995 lines, zero `actions/cache` uses). This doc treats no-cache as a SETTLED decision; cache is not in scope here.

The `ci-cd-workflows` skill ([CI-001]–[CI-060]) codifies the architecture in production: three-tier reusable chain ([CI-001]), universal-reusable-owns-matrix-and-quality-gates ([CI-002]), L1 invariants in layer wrappers ([CI-003], [CI-020]), absolute-minimum per-package callers ([CI-031]), visibility gate ([CI-032]), tracking-issue reporting per [README-167]. This doc cite-extends those rules — every Phase β design choice is grounded in an existing rule ID.

### Empirical state (verified 2026-05-04)

- Universal reusable: `swift-institute/.github/.github/workflows/swift-ci.yml` carries macos-release + linux-release + linux-nightly + windows-release + format + lint (6 jobs); 211 lines.
- Layer wrapper: `swift-primitives/.github/.github/workflows/swift-ci.yml` carries `matrix` (delegates to universal) + `embedded` (L1 invariant); 86 lines.
- Per-package caller: ~16 lines, two `uses:` jobs (`ci` + `docs`), `secrets: inherit` on both per [CI-059].
- Audit script: `swift-institute/Scripts/preflight-test-support-spine.py` (329 lines) — emits per-target `OK | VIOLATION | MISSING`, JSON output via `--json`. Currently keyed on hardcoded `ORG_DIRS` map (`/Users/coen/Developer/swift-{primitives,standards,foundations,iso}`); for CI use, needs per-package mode.
- Existing tracking-issue reusables (mimic patterns): `link-check.yml` + `link-check-weekly.yml` (per-repo report → cross-org cron); `lint-readme-presence.yml` + `lint-readme-presence-weekly.yml` (aggregated tracking issue); `sync-metadata.yml` + `sync-metadata-nightly.yml` (the canonical shape per [README-167]).

---

## Question

Three coupled questions:

1. What is the right shape for the Phase β advisory CI gate, given the existing three-tier architecture and the [README-167] tracking-issue convention?
2. What patterns have other Swift open-source ecosystems converged on for cross-repo CI/CD, and where does Swift Institute already match (or deliberately diverge from) those patterns?
3. What CI/CD capabilities present elsewhere are absent here — and which of those are worth adopting, in what order?

---

## Analysis

### Part 1 — Phase β advisory gate design

#### 1.1 Constraints inherited from prior decisions

| Source | Constraint |
|---|---|
| Parent handoff Key Decision #4 | File at `swift-institute/.github/.github/workflows/lint-test-support-spine.yml`; advisory mode (`continue-on-error: true` per [CI-021] precedent); reports via tracking-issue per [README-167]; β→γ flip requires two consecutive weeks of zero violations across all in-scope org-dirs |
| `[MOD-024]` skill rule (Phase α, landed) | TS deps ⊆ {TS-of-deps, own product}; corollary: every package with tests publishes a TS product |
| `[CI-002]` | Universal reusable owns ecosystem-wide quality gates (format, lint) — TS-spine fits this category (uniform across every consumer regardless of layer) |
| `[CI-031]` | Per-package `ci.yml` is the absolute minimum — adding a third `uses:` per consumer would violate the rule. Spine job MUST land transitively via the existing `swift-ci.yml` chain |
| `[CI-021]` | Advisory `continue-on-error: true` precedent (linux-nightly, embedded job) |
| `[CI-032]` | Public/private visibility gate — `if: ${{ !github.event.repository.private }}` on every job |
| `[README-167]` | Tracking-issue convention — single issue at `swift-institute/.github`, opened/updated idempotently, swift-institute-bot GitHub App auth, weekly cadence |
| `[HANDOFF-035]` | Cascade-migration termination criteria — workspace-wide grep at start AND end + ecosystem-wide build gate. The β→γ "two consecutive weeks of zero violations" is the spine-equivalent: cron sweep is the workspace-wide grep at end |

#### 1.2 Three architectural options

**Option α — Embed as a job in `swift-ci.yml` (alongside format + lint)**

Add `lint-test-support-spine` as a sixth job in the universal reusable, `continue-on-error: true`. Body inline (run `swift package dump-package | python audit`).

- **Pro**: Zero new files; lives in the same canonical location as format/lint per [CI-002].
- **Pro**: One commit lands and ripples to 132+ consumers transitively.
- **Con**: Mixing `continue-on-error: true` jobs with gating jobs in the same reusable invites accidental drift — a future edit could remove the flag from a gating job, or add it to one that should gate. The format/lint precedent is gating, not advisory; the spine breaks the pattern.
- **Con**: Inline audit logic (or inline shell + jq) duplicates the Python script's classification logic; drift between CI and on-disk audit is a real risk.
- **Con**: The β→γ flip ("drop `continue-on-error: true`") is a single-line edit — easy to miss in review, no deliberate file-level signal that the gate has flipped status.

**Option β — Separate reusable `lint-test-support-spine.yml`, called from `swift-ci.yml`**

New reusable file. Called from the universal `swift-ci.yml` as `lint-test-support-spine: uses: ./lint-test-support-spine.yml; continue-on-error: true`. The reusable runs the existing audit script (extended with `--package-dir`) and exits 1 on violations; the calling job's `continue-on-error` flag is the advisory gate.

- **Pro**: Advisory-vs-gating semantics live at one site (the calling job's `continue-on-error: true`). Flipping β→γ is a single-line edit at a deliberate, named location.
- **Pro**: Spine logic is encapsulated — future extensions (different audit families: Foundation-import per [CI-022] candidate, layer-violation, dep-graph diff) follow the same shape, one reusable per audit family.
- **Pro**: The reusable can be invoked directly via `workflow_dispatch` for ad-hoc audits, without forcing a full swift-ci.yml run.
- **Con**: Adds one file to `swift-institute/.github`. Marginal cost.
- **Con**: Composition is one level deeper (consumer → universal → spine reusable, three levels in the reusable graph; GitHub allows up to 4).

**Option γ — Per-package caller-level wiring**

Each consumer `ci.yml` adds a third `uses:` job pointing at `lint-test-support-spine.yml`.

- **Pro**: Most explicit per-consumer; each ci.yml literally lists the gate.
- **Con**: Violates [CI-031] (per-package ci.yml is the absolute minimum — only triggers, concurrency, ci + docs `uses:`).
- **Con**: 132+ caller edits to land the gate; another 132+ edits to flip β→γ.
- **Con**: Drift surface — sibling-org callers may not get updated in lockstep (the 2026-05-04 B5 incident discovered 155 sibling-org callers that lagged behind the swift-primitives wave).

#### 1.3 Recommended option: β (separate reusable)

Option β is the recommendation. Rationale, in order of weight:

1. **Failure-mode isolation**. Advisory-vs-gating semantics live at exactly one site (the calling job's `continue-on-error: true`). When β→γ flips, the diff is a single line at a single named location, reviewable and reversible. Option α's diff is in the middle of a 6-job workflow file; the file's state-during-flip is harder to scan.
2. **Audit-family extensibility**. The Phase β design should be a template, not a one-off. Foundation-import enforcement ([CI-022] candidate), layer-violation linting (cross-layer dep checks per `[ARCH-LAYER-*]`), and dep-graph parity checks all follow the same shape: parse Package.swift, classify, report. One reusable per audit family is the right structural unit.
3. **Skill-rule fit**. [CI-002] permits ecosystem-wide quality gates in the universal reusable; it does not require them to be inline jobs vs delegated reusables. The pattern of universal-reusable-calls-sub-reusable is consistent with [CI-001]'s three-tier architecture extended one layer.
4. **Migration ergonomics**. The script extension (`--package-dir`) is local to swift-institute/Scripts/. The workflow file is a single new file. The `swift-ci.yml` edit is two lines (one new job stanza). Total surface to land Phase β: ~3 files, ~50 lines.

Option α is the close runner-up. The decisive factor is the β→γ flip's reviewability — a separate file makes the state of the gate explicit; an inline `continue-on-error: true` flag mixed into a 6-job file is a footgun.

Option γ is rejected on [CI-031] grounds and on rollout cost (132+ caller edits).

#### 1.4 Workflow YAML draft (proposed; NOT to be created in this round)

```yaml
# lint-test-support-spine.yml — advisory CI gate for [MOD-024] Test Support
# Spine Discipline.
#
# Reusable workflow. For the checked-out package, runs the per-package audit
# (preflight-test-support-spine.py --package-dir .) and exits 1 on VIOLATION
# or MISSING findings. The advisory-vs-gating decision is made at the CALLING
# site via `continue-on-error: true` (Phase β) or omission (Phase γ).
#
# Phase β (current): called from swift-institute/.github/.github/workflows/
# swift-ci.yml with `continue-on-error: true`. Findings surface in the job
# log + step summary; the parent CI is not gated.
#
# Phase γ (future, after two consecutive weeks of ecosystem-wide zero
# violations confirmed by lint-test-support-spine-weekly.yml): drop the
# `continue-on-error: true` flag at the calling site. The audit becomes
# gating; drift recurrence fails the parent CI.
#
# Provenance: [MOD-024] (the rule); [CI-001]+[CI-002] (architecture);
# [CI-021] (continue-on-error precedent); [README-167] (tracking-issue
# reporting via the weekly orchestrator). Research:
# `swift-institute/Research/centralized-swift-ci-and-spine-gate.md`.

name: lint-test-support-spine

on:
  workflow_call:
    outputs:
      ok-count:
        description: 'Number of OK findings (TS targets that satisfy [MOD-024]).'
        value: ${{ jobs.audit.outputs.ok-count }}
      violation-count:
        description: 'Number of VIOLATION findings (TS targets with non-TS cross-package deps).'
        value: ${{ jobs.audit.outputs.violation-count }}
      missing-count:
        description: 'Number of MISSING findings (packages with tests but no TS target).'
        value: ${{ jobs.audit.outputs.missing-count }}

  workflow_dispatch: {}

jobs:
  audit:
    name: Test Support Spine audit
    if: ${{ !github.event.repository.private }}     # [CI-032]
    runs-on: ubuntu-latest
    container: swift:6.3                            # [CI-011] toolchain pin
    timeout-minutes: 10
    permissions:
      contents: read
    outputs:
      ok-count: ${{ steps.audit.outputs.ok-count }}
      violation-count: ${{ steps.audit.outputs.violation-count }}
      missing-count: ${{ steps.audit.outputs.missing-count }}
    steps:
      - uses: actions/checkout@v6

      # The audit script lives in swift-institute/Scripts/. We fetch it via
      # raw.githubusercontent.com to avoid a second checkout step. Pinning to
      # @main is consistent with [CI-030] active-dev-phase pinning.
      - name: Fetch audit script
        run: |
          set -euo pipefail
          curl -fsSL -o /tmp/preflight-test-support-spine.py \
            https://raw.githubusercontent.com/swift-institute/Scripts/main/preflight-test-support-spine.py
          chmod +x /tmp/preflight-test-support-spine.py

      - name: Run audit
        id: audit
        shell: bash
        run: |
          set -euo pipefail
          python3 /tmp/preflight-test-support-spine.py \
            --package-dir . \
            --json /tmp/audit.json \
            | tee /tmp/audit.log
          ok=$(jq -r '.totals.ok_findings' /tmp/audit.json)
          viol=$(jq -r '.totals.violation_findings' /tmp/audit.json)
          miss=$(jq -r '.totals.missing_findings' /tmp/audit.json)
          echo "ok-count=$ok"        >> "$GITHUB_OUTPUT"
          echo "violation-count=$viol" >> "$GITHUB_OUTPUT"
          echo "missing-count=$miss"   >> "$GITHUB_OUTPUT"
          {
            echo "## Test Support Spine — [MOD-024]"
            echo ""
            echo "- OK:        $ok"
            echo "- VIOLATION: $viol"
            echo "- MISSING:   $miss"
            echo ""
            if [[ "$viol" -gt 0 || "$miss" -gt 0 ]]; then
              echo "### Findings"
              echo ""
              echo '```'
              cat /tmp/audit.log
              echo '```'
            fi
          } >> "$GITHUB_STEP_SUMMARY"
          if [[ "$viol" -gt 0 || "$miss" -gt 0 ]]; then
            echo "::warning::[MOD-024] spine drift detected — $viol violations, $miss missing"
            exit 1
          fi
```

#### 1.5 Caller wiring (proposed inline addition to `swift-ci.yml`)

```yaml
# Append after the `lint:` job in swift-institute/.github/.github/workflows/swift-ci.yml:

  lint-test-support-spine:
    name: Test Support Spine ([MOD-024], advisory)
    if: ${{ !github.event.repository.private }}
    uses: ./.github/workflows/lint-test-support-spine.yml
    continue-on-error: true     # Phase β (advisory). Drop in Phase γ.
```

**β→γ flip**: a single-line edit — remove `continue-on-error: true`. The diff is reviewable, the named job in the workflow file makes the state explicit, and the flip is reversible with the same single-line edit if drift recurs.

**Per-package caller wiring**: NONE. Per [CI-031], no consumer `ci.yml` edits are required. Consumers receive the spine job transitively because their `ci:` job's `uses:` chains through the layer wrapper to the universal `swift-ci.yml`, which now contains the spine job.

#### 1.6 Audit script extension (proposed inline change to `preflight-test-support-spine.py`)

The current script keys on hardcoded `ORG_DIRS` paths. For per-package CI, add a `--package-dir <path>` flag. Sketch:

```python
ap.add_argument("--package-dir", type=Path,
                help="Audit a single package at this path (CI mode).")

# In main():
if args.package_dir:
    pkg_dir = args.package_dir.resolve()
    if not (pkg_dir / "Package.swift").is_file():
        print(f"error: {pkg_dir}/Package.swift not found", file=sys.stderr)
        return 2
    dump = dump_package(pkg_dir)
    if dump is None:
        print(f"error: swift package dump-package failed in {pkg_dir}", file=sys.stderr)
        return 2
    audited = audit_package(pkg_dir, dump)
    orgs = [{"org": "<single>", "dir": str(pkg_dir.parent),
             "packages": [audited], "parse_failures": []}]
    # ... (existing aggregate + print_report flow)
```

Backward compatible: existing `--org` and bare invocations continue to work.

#### 1.7 Cron orchestrator (proposed; mirrors `lint-readme-presence-weekly.yml`)

```yaml
# lint-test-support-spine-weekly.yml
#
# Weekly cross-org Test Support spine sweep. Mirrors lint-readme-presence-
# weekly.yml's shape: matrix-per-org → aggregate report → tracking issue at
# swift-institute/.github per [README-167].
#
# Cadence: weekly Monday 06:30 UTC (offset from link-check + readme-presence
# sweeps which run at 06:00). Pilot scope: swift-primitives only (where the
# spine has been rolled out — Phase 2a). Expansion candidates after pilot:
# swift-standards, swift-foundations, swift-iso. The matrix begins narrow and
# widens as Phases 2b/c/d land.
#
# β→γ flip trigger: this orchestrator's tracking issue MUST report zero
# violations across all in-scope orgs for two consecutive weeks before
# Phase γ flip is authorized (per parent handoff Key Decision #4 +
# [MOD-024] β→γ transition clause).

name: lint-test-support-spine-weekly

on:
  schedule:
    - cron: '30 6 * * 1'   # weekly Monday 06:30 UTC
  workflow_dispatch:
    inputs:
      dry-run:
        description: 'Run audit but skip aggregated issue create/update.'
        type: boolean
        required: false
        default: false

jobs:
  sweep:
    strategy:
      fail-fast: false
      matrix:
        org:
          - swift-primitives
          # Expansion candidates (after Phases 2b/c/d):
          # - swift-standards
          # - swift-foundations
          # - swift-iso
    runs-on: ubuntu-latest
    container: swift:6.3
    permissions:
      contents: read
    steps:
      - name: Mint installation token
        id: token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.SWIFT_INSTITUTE_BOT_APP_ID }}
          private-key: ${{ secrets.SWIFT_INSTITUTE_BOT_APP_PRIVATE_KEY }}
          owner: ${{ matrix.org }}
          repositories: ''  # all repos in the org installation

      - name: Fetch audit script
        run: |
          set -euo pipefail
          curl -fsSL -o /tmp/preflight-test-support-spine.py \
            https://raw.githubusercontent.com/swift-institute/Scripts/main/preflight-test-support-spine.py

      - name: Sweep org
        env:
          GH_TOKEN: ${{ steps.token.outputs.token }}
          ORG: ${{ matrix.org }}
        run: |
          set -euo pipefail
          mapfile -t targets < <(gh repo list "$ORG" --limit 2000 \
            --visibility public \
            --json nameWithOwner,isArchived \
            --jq '.[] | select(.isArchived==false) | .nameWithOwner')
          total_viol=0
          total_miss=0
          for target in "${targets[@]}"; do
            workdir=$(mktemp -d)
            git clone --depth 1 --quiet \
              "https://x-access-token:${GH_TOKEN}@github.com/${target}.git" \
              "$workdir" 2>/dev/null || { rm -rf "$workdir"; continue; }
            python3 /tmp/preflight-test-support-spine.py \
              --package-dir "$workdir" \
              --json "/tmp/${target//\//__}.json" 2>/dev/null || true
            v=$(jq -r '.aggregate.totals.violation_findings // 0' \
                "/tmp/${target//\//__}.json" 2>/dev/null || echo 0)
            m=$(jq -r '.aggregate.totals.missing_findings // 0' \
                "/tmp/${target//\//__}.json" 2>/dev/null || echo 0)
            total_viol=$((total_viol + v))
            total_miss=$((total_miss + m))
            rm -rf "$workdir"
          done
          echo "## Org $ORG — spine sweep" >> "$GITHUB_STEP_SUMMARY"
          echo "- VIOLATION total: $total_viol" >> "$GITHUB_STEP_SUMMARY"
          echo "- MISSING total:   $total_miss" >> "$GITHUB_STEP_SUMMARY"
          # Persist counts as artifacts for the report job
          echo "${total_viol},${total_miss}" > "/tmp/${ORG}-counts.txt"

      - uses: actions/upload-artifact@v4
        with:
          name: spine-counts-${{ matrix.org }}
          path: /tmp/${{ matrix.org }}-counts.txt

  report:
    needs: sweep
    runs-on: ubuntu-latest
    if: always() && needs.sweep.result != 'skipped'
    steps:
      - name: Mint installation token
        id: token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.SWIFT_INSTITUTE_BOT_APP_ID }}
          private-key: ${{ secrets.SWIFT_INSTITUTE_BOT_APP_PRIVATE_KEY }}
          owner: swift-institute
          repositories: .github
          permission-issues: write

      - uses: actions/download-artifact@v4
        with:
          path: /tmp/counts

      - name: Open or update tracking issue
        env:
          GH_TOKEN: ${{ steps.token.outputs.token }}
          DRY_RUN: ${{ inputs.dry-run || false }}
        run: |
          set -euo pipefail
          today=$(date -u '+%Y-%m-%d')
          total_viol=0
          total_miss=0
          per_org=()
          for f in /tmp/counts/*/*.txt; do
            org=$(basename "$(dirname "$f")" | sed 's/^spine-counts-//')
            IFS=',' read -r v m < "$f"
            total_viol=$((total_viol + v))
            total_miss=$((total_miss + m))
            per_org+=("- \`${org}\`: $v violations, $m missing")
          done
          if [[ "$total_viol" -eq 0 && "$total_miss" -eq 0 ]]; then
            echo "Spine clean across all orgs — no tracking issue needed."
            exit 0
          fi
          [[ "$DRY_RUN" == "true" ]] && { echo "(dry-run)"; exit 0; }
          title="Test Support spine sweep ${today}"
          body=$(cat <<EOF
          The weekly Test Support spine sweep at 06:30 UTC on ${today} found drift.

          ## Aggregate
          - VIOLATION total: ${total_viol}
          - MISSING total:   ${total_miss}

          ## Per-org

          $(printf '%s\n' "${per_org[@]}")

          See the per-org run summaries for the file-level breakdown.

          ## What this means

          One or more packages drifted from [MOD-024] Test Support Spine
          Discipline. A \`* Test Support\` target is either missing (the
          package has tests but no TS) or its dependencies include a non-TS
          cross-package product, breaking the SLI conformance chain under
          MemberImportVisibility.

          ## What to do

          - Run \`swift-institute/Scripts/preflight-test-support-spine.py\`
            locally to identify the drifted packages.
          - For VIOLATION: replace the non-TS cross-package dep with the
            corresponding \`* Test Support\` product. The spine-anchor
            algorithm (lowest-level TS in product deps) determines the
            target.
          - For MISSING: add an empty TS shell per the [MOD-024] template.
          - Close this issue when fixed; the next weekly sweep reopens it
            if drift recurs.

          Phase β→γ flip authorization requires two consecutive weeks of
          zero VIOLATION + MISSING across all in-scope orgs.

          *Idempotent: this issue is updated in place.*
          EOF
          )
          existing=$(gh issue list --repo swift-institute/.github \
            --state open --search "Test Support spine sweep in:title" \
            --json number --jq '.[0].number // ""')
          if [[ -n "$existing" ]]; then
            gh issue edit "$existing" --repo swift-institute/.github --title "$title" --body "$body"
          else
            gh issue create --repo swift-institute/.github --title "$title" --body "$body" --label "spine-audit"
          fi
```

#### 1.8 β→γ flip trigger — operationalized

The two-consecutive-weeks zero-violation criterion is interpreted as: the `lint-test-support-spine-weekly` workflow's tracking issue must NOT be opened (or must remain closed) for two consecutive Monday runs. Since the orchestrator only opens an issue on findings, "no issue" is the success signal. Cron-time evidence is sufficient — no per-PR aggregation is needed.

The flip itself is the single-line edit at the calling site (remove `continue-on-error: true`). The flip MUST be authorized per `feedback_no_public_or_tag_without_explicit_yes.md` style discipline — the central-infra push is its own per-action authorization.

#### 1.9 Failure-mode and rollback

| Failure | Detection | Rollback |
|---|---|---|
| Audit script regression breaks every PR (false-positive flood) | Phase β: `continue-on-error: true` insulates the parent CI from the breakage; advisory failures only show in the job log. | Revert the script commit at swift-institute/Scripts; the next CI run consumes the reverted version (the workflow fetches `@main`). |
| Phase γ accidentally flipped without two-week soak | The single-line `continue-on-error: true` removal is highly visible in the diff to the universal `swift-ci.yml` | Re-add the flag in the same file; effect propagates immediately. |
| Tracking issue spam (orchestrator regression) | Lychee + readme-presence patterns have the same risk; the idempotent issue-update pattern minimizes duplicate-issue noise | Disable the cron schedule (workflow file edit); the per-PR advisory job continues running. |

---

### Part 2 — Literature survey

Six Swift orgs surveyed, plus the existing comparative analysis from `ci-cache-strategy-branch-pinned-dependencies.md` (which already enumerates 8 Apple/swiftlang packages). Each entry cites the workflow file at a specific main-SHA; SHAs verified 2026-05-04 via `gh api repos/<org>/<repo>/commits/main`.

#### 2.1 Per-org snapshot

| Org / repo | Main SHA (2026-05-04) | Centralization | Reusable home |
|---|---|---|---|
| [`swiftlang/github-workflows`](https://github.com/swiftlang/github-workflows) | `a2de0e0b` | Authoritative reusable repo for the swiftlang umbrella | `swiftlang/github-workflows` (this repo IS the central) |
| [`apple/swift-nio`](https://github.com/apple/swift-nio) | `f71c8d2a` | Owns its own reusables; consumed by server-side ecosystem | `apple/swift-nio/.github/workflows/` (17 workflows) |
| [`vapor/ci`](https://github.com/vapor/ci) | `7b8df8b7` | Vapor org's centralized reusables | `vapor/ci` (4 workflows) |
| [`swift-server/async-http-client`](https://github.com/swift-server/async-http-client) | `8cfd301b` | Consumes apple/swift-nio reusables | none of own; depends on NIO |
| [`pointfreeco/swift-composable-architecture`](https://github.com/pointfreeco/swift-composable-architecture) | `7517cc32` | Per-repo inline (no centralization) | n/a |
| [`nicklockwood/SwiftFormat`](https://github.com/nicklockwood/SwiftFormat) | `a5fa7a6a` | Per-repo inline (no centralization) | n/a |
| [`realm/SwiftLint`](https://github.com/realm/SwiftLint) | `98b687f8` | Per-repo inline (no centralization) | n/a |
| [`groue/GRDB.swift`](https://github.com/groue/GRDB.swift) | `36e30a6f` | Per-repo single workflow | n/a |
| Apple/swiftlang packages (swift-syntax, swift-collections, swift-numerics, swift-system, swift-format, swift-package-manager, swift-async-algorithms) | (see ci-cache-strategy.md) | Consume `swiftlang/github-workflows` reusables, pinned by tag (`@0.0.7`–`@0.0.11`) | n/a |
| Swift Institute (this ecosystem) | (this workspace) | Three-tier reusable chain ([CI-001]); 280+ repos | `swift-institute/.github` + per-layer `.github` |

#### 2.2 Soundness check inventory — the swiftlang/github-workflows pattern

`swiftlang/github-workflows/soundness.yml` (~80 input variables, verified at `a2de0e0b`) is by far the richest single-file CI surface of any surveyed org. It bundles into one reusable:

| Check | Default | Notes |
|---|---|---|
| API breakage check | enabled | `swift package diagnose-api-breaking-changes`, baseline = PR base or named tag |
| Docs check (DocC build) | enabled | linux container (`swift:6.2-noble`); optional macOS docs check |
| Unacceptable language check | enabled | configurable word list (default: blacklist/whitelist/slave/master/etc.) |
| License header check | enabled | requires project name + optional `.license_header_template` |
| Broken symlink check | enabled | finds dangling symlinks |
| Format check (swift-format) | enabled | linux container |
| Shell check (shellcheck) | enabled | ubuntu:noble container |
| YAML lint | enabled | yamllint |
| Python lint | enabled | flake8/black-equivalent |
| Pre-build command | optional | escape hatch for setup |

This is a *one reusable, many opt-in jobs* shape. Every consumer adds a single `uses: swiftlang/github-workflows/.github/workflows/soundness.yml@VERSION` and tunes via inputs. The composition lets Apple project teams enforce 9+ structural disciplines with one caller stanza.

Swift Institute's universal `swift-ci.yml` is structurally similar (matrix + format + lint as separate jobs in one file) but covers 6 jobs, not 9+. The gap is real: API breakage, license header, unacceptable language, broken symlink, shell check, yamllint, python lint are all absent.

#### 2.3 Server-side ecosystem — apple/swift-nio + vapor/ci

The server-side Swift ecosystem operates a *parallel* set of reusables to swiftlang/github-workflows. Patterns:

- **apple/swift-nio publishes 17 workflows** including `unit_tests.yml`, `swift_matrix.yml`, `static_sdk.yml`, `release_builds.yml`, `cxx_interop.yml`, `cmake_tests.yml`, `wasm_swift_sdk.yml`, `android_swift_sdk.yml`, `swift_load_test_matrix.yml`, `macos_benchmarks.yml`, `swift_6_language_mode.yml`. The pattern is *one reusable per concern*, where soundness.yml is the *one reusable, many concerns* shape.
- **swift-server/async-http-client** consumes NIO's reusables at `@main` (no tag pinning), with input overrides like `linux_5_10_arguments_override: "--explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors"`. Comprehensive multi-toolchain matrix: 5.10, 6.0, 6.1, 6.2, nightly_next, nightly_main.
- **vapor/ci** has 4 workflows: `run-unit-tests.yml`, `run-benchmark.yml`, `submit-deps.yml`, `self-test.yml`. The `submit-deps.yml` is the GitHub dependency-graph submission (uses `vapor-community/swift-dependency-submission@b3073f8c` pinned by SHA — interesting precedent for SHA-pinned third-party actions).

Three different orgs running parallel reusable repos for adjacent concerns is the dominant pattern in mature server-side Swift ecosystems. Swift Institute's three-tier (consumer → layer wrapper → universal) sits between *one reusable many concerns* (swiftlang's soundness.yml) and *one reusable per concern* (NIO's 17 workflows).

#### 2.4 Per-repo inline ecosystems

- **pointfreeco/swift-composable-architecture** uses `actions/cache@v3` with `restore-keys: deriveddata-xcodebuild-IOS-16.4-test-` partial-prefix fallback — exactly the cache-staleness vulnerability that ci-cache-strategy.md identified and that [CI-042] forbids in Swift Institute. Point-Free has not migrated. (Verified at `7517cc32`.)
- **nicklockwood/SwiftFormat** is a single-author project; CI is one workflow file, no centralization, inlined Codecov token (acceptable for a public repo). Multi-toolchain matrix: Swift 5.7 + 6.0 + macOS Xcode 16.3.
- **realm/SwiftLint** has 9 separate workflows (`build`, `docker`, `docs`, `lint`, `plugins-sync`, `post-release`, `release`, `stale-issues`) — workflow-per-concern within a single repo. No reusables.
- **groue/GRDB.swift** is a single workflow file; canonical single-author Swift package CI shape.

These ecosystems are too small (1–2 repos) for centralization to pay off. Their patterns are a baseline for *what NOT to do* at 280+-repo scale (Point-Free's vulnerable cache shape would multiply across consumers; per-repo inline workflow at swift-primitives' scale would be 280× the maintenance surface).

#### 2.5 Caching strategies — convergence on no-cache

`ci-cache-strategy-branch-pinned-dependencies.md` already established that Apple's canonical reusables (`swiftlang/github-workflows/swift_package_test.yml`, 995 lines) contain ZERO `actions/cache` uses. Swift Institute aligned on this 2026-05-04 ([CI-040], [CI-041]).

Survey reinforces this finding:
- **Point-Free is the dominant outlier** — 8/8 surveyed Apple packages, swift-nio, vapor, async-http-client all run uncached or near-uncached. Point-Free's `actions/cache@v3` + `restore-keys` partial-prefix is the same vulnerable pattern Swift Institute removed.
- **No surveyed package uses dynamic dep-fingerprint caching** (Option B in the cache strategy doc). Apple's no-cache choice + Swift Institute's alignment is the ecosystem-wide canonical answer.

#### 2.6 Required-checks enforcement

- **Apple, swift-server, vapor**: paid plans likely (Team or Enterprise); rulesets / branch-protection unverified externally but would be standard practice. `ci-centralization-strategy.md` already established this is gated on plan upgrade for Swift Institute.
- **Swift Institute**: Free plan; rulesets unavailable; required-workflows deprecated. Enforcement is convention + reusable-workflow visibility ([CI-032] gates private-repo skipping). Documented gap; not currently a blocker because the swift-institute org has one operator.

#### 2.7 Comparison matrix — surveyed-orgs vs Swift Institute

| Capability | swiftlang | swift-nio | vapor | pointfreeco | Apple packages | Swift Institute |
|---|---|---|---|---|---|---|
| Centralized reusables | YES (1 repo, many concerns) | YES (own repo) | YES (vapor/ci) | NO | consume swiftlang | YES (institute + layer) |
| Three-tier reusable chain | NO (2-tier) | NO (2-tier) | NO (2-tier) | n/a | n/a | YES |
| Tag pinning of reusables | YES (own tags) | NO (`@main`) | NO (`@main`) | n/a | YES (`@0.0.7`–`@0.0.11`) | active dev: `@main`; deferred `@v1` |
| API-breakage check | YES (soundness.yml) | NO | NO | NO | YES (via swiftlang) | NO |
| License-header check | YES (soundness.yml) | NO | NO | NO | YES (via swiftlang) | NO |
| Unacceptable-language check | YES | NO | NO | NO | YES (via swiftlang) | NO |
| Broken-symlink check | YES | NO | NO | NO | YES (via swiftlang) | NO |
| YAML lint | YES | NO | NO | NO | YES (via swiftlang) | NO |
| Shell check | YES | NO | NO | NO | YES (via swiftlang) | NO |
| Python lint | YES | NO | NO | NO | YES (via swiftlang) | NO |
| Format check | YES (in soundness) | YES | YES (in CI) | YES (separate) | YES (via swiftlang) | YES ([CI-054]) |
| DocC build verification | YES (in soundness) | NO | NO | NO | YES (via swiftlang) | YES (`swift-docs.yml`) |
| Multi-toolchain matrix | 5.10, 6.0, 6.1, 6.2, nightly | 5.10, 6.0, 6.1, 6.2, nightly | 6.2 only | latest Xcode | 5.10..6.2 + nightly | 6.3 + 6.4-dev nightly |
| Per-platform matrix | macOS+Linux+Wasm+Win+iOS+Android+FreeBSD | macOS+Linux | Linux | iOS+macOS | per swiftlang | macOS+Linux+Win |
| Embedded matrix | YES (Wasm SDK) | NO | NO | NO | NO | YES (L1 layer wrapper, [CI-020]) |
| Submit-dependencies (GitHub graph) | NO | NO | YES (vapor/ci) | NO | NO | NO |
| Cron link-check sweeps | NO | NO | NO | NO | NO | YES |
| Cron tracking-issue reports | NO | NO | NO | NO | NO | YES (`link-check-weekly`, `lint-readme-presence-weekly`) |
| Cron metadata sync | NO | NO | NO | NO | NO | YES (`sync-metadata-nightly`) |
| Required-workflow rulesets | likely YES (paid plan) | likely YES | likely YES | n/a | likely YES | NO (Free plan) |
| Per-package size / dep-graph diff | NO | NO | NO | NO | NO | NO |
| Benchmark regression gate | NO | YES (`macos_benchmarks.yml`) | YES (`run-benchmark.yml`) | NO | NO | NO |
| Auto-PR on toolchain bumps | NO (manual) | NO | NO | NO | NO | NO |
| Release-tag automation | varies | YES (`release_builds.yml`) | YES (release.yml) | YES (release.yml) | varies | NO |
| Commit-lint (conventional commits) | NO | NO | NO | NO | NO | NO |

#### 2.8 What Swift Institute does that NOBODY ELSE surveyed does

Three Swift-Institute-specific patterns appear in NO surveyed Swift org and are worth highlighting because they are differentiating value, not gaps:

1. **Cron link-check sweeps with per-repo tracking issues** (lychee + GitHub App). Swiftlang/Apple/Vapor/Point-Free have no equivalent.
2. **README presence + structure linting with aggregated tracking issues**. Same — no equivalent surveyed.
3. **`sync-metadata-nightly` (centralized GitHub repo metadata)**. The GH-Repo `[GH-REPO-070]` pattern with its source-of-truth `.github/metadata.yaml` per-package + nightly autopilot is a Swift-Institute innovation. Apple/swiftlang manage repo metadata manually.

These three patterns plus the three-tier reusable chain are Swift Institute's distinctive CI/CD assets. The centralization architecture is, on this evidence, more deliberate than any single surveyed Swift org's.

---

### Part 3 — Improvements / additions catalog

> **v1.1.0 note**: §3.1 below preserves the original 20-capability priority survey (carried forward from v1.0.0 for traceability). §3.2 and §3.3 are REPLACED in v1.1.0 by §3.4 (the converged plan). The user-selected subset of §3.1 went through a four-round Claude+ChatGPT collaborative discussion; the converged design lives in §3.4 and supersedes the v1.0.0 priority bands and recommended bundle.

Capabilities present in surveyed ecosystems but absent in Swift Institute, ranked by priority. Priority criteria: (a) drift-prevention value, (b) cost-to-implement, (c) ecosystem-wide applicability vs niche, (d) reversibility.

#### 3.1 Recommendation matrix (v1.0.0 — historical; superseded by §3.4)

| # | Capability | What others do | What we have | Gap analysis | Priority |
|---|---|---|---|---|---|
| 1 | **Test Support spine gate** (the in-flight subject of this research) | none surveyed | Phase α landed (`[MOD-024]`); Phase β designed (this doc) | New ecosystem-specific structural rule with verified rollout (Phase 2a clean) | **P0 — in-flight** |
| 2 | **Foundation-import enforcement** | swiftlang/Apple's broader culture is Foundation-tolerant; check absent from surveyed reusables | `[CI-022]` candidate (specified, pending implementation); enforced by code review | Trivially implementable as an `lint-no-foundation-import` reusable mirroring spine shape; same advisory→gating phase model | **P1 — high-value** |
| 3 | **API-breakage check** | swiftlang/github-workflows soundness.yml (PR-time `swift package diagnose-api-breaking-changes`) | NONE | Nontrivial: swift-primitives has no published tags; baseline must be PR-base or last-merge SHA; library-package shape (no committed `Package.resolved`) constrains the analysis. Worth doing post-1.0; deferred until any package tags `v1.0.0` | **P3 — defer until first 1.0** |
| 4 | **License-header check** | swiftlang soundness | NONE | Trivial; one shell loop. License is Apache 2.0 ecosystem-wide for L1–L3. Catches drift at PR time | **P2 — easy win** |
| 5 | **Unacceptable-language check** | swiftlang soundness | NONE | Trivial; one grep loop. Cultural fit varies; default word list (blacklist/whitelist/slave/master) is not currently a documented Institute concern | **P4 — low-priority** |
| 6 | **Broken-symlink check** | swiftlang soundness | NONE | Trivial; `find -L . -type l ! -exec test -e {} \; -print`. No known incidents; adds value only on platforms that allow symlinks (most repos don't carry any) | **P4 — low-priority** |
| 7 | **YAML lint** | swiftlang soundness | NONE | Useful — `.github/workflows/*.yml` and `.github/metadata.yaml` are now load-bearing infrastructure. yamllint with a permissive config catches accidental syntax errors before they break a workflow | **P2 — easy win** |
| 8 | **Shell check (shellcheck)** | swiftlang soundness | NONE | The existing `swift-institute/.github` reusables and `swift-institute/Scripts/` use bash extensively (lychee + sync-metadata + sync-* scripts). Shellcheck on these scripts would catch shell defects before they fire in production cron. Higher value at swift-institute repos than at L1 consumers | **P2 — easy win on infra repos** |
| 9 | **Python lint (flake8 / ruff)** | swiftlang soundness | NONE | `swift-institute/Scripts/preflight-test-support-spine.py` and other Python scripts deserve linting. Ruff is fast and broadly accepted | **P2 — easy win on infra repos** |
| 10 | **Per-package size / dep-graph diff on PR** | NONE surveyed | NONE | Compute Sources/ LOC + Package.swift dep count delta vs PR base; surface in PR comment. No surveyed prior art to mimic; would be Institute-specific innovation. Risk: noisy. Defer | **P5 — research probe** |
| 11 | **Macro-build verification** | NONE surveyed (varies) | NONE | Currently no macros in swift-primitives. If the ecosystem adopts macros for testing or codegen, gate macro builds explicitly. Forward-looking | **P5 — defer until first macro lands** |
| 12 | **Benchmark regression gate** | swift-nio (macos_benchmarks.yml), vapor (run-benchmark.yml) | NONE | High-value but high-cost: needs benchmark baseline storage, statistically-significant comparison, machine-stable runners. swift-nio's pattern (release_builds + macos_benchmarks) is the mature template. Defer until specific consumers (heap, hash, cache) have benchmark suites | **P3 — defer; worth scoping** |
| 13 | **Commit-lint (conventional commits)** | NONE surveyed | NONE | The Skills' commit-message conventions are documented and human-enforced. Mechanical lint via commitlint or equivalent pinned to PR-time would close the drift gap. Low-cost; advisory mode initially | **P2 — easy win** |
| 14 | **Auto-PR on toolchain bumps** | NONE surveyed | Manual (Dependabot covers GitHub Actions versions; not Swift toolchain) | When Swift 6.4 ships stable, the `swift:6.3` container references in 132+ consumers' workflows need updating. Currently a manual sed + fan-out commit. Auto-PR via a scheduled workflow (cron, like sync-metadata-nightly) would file PRs to bump toolchain pins per [CI-011] | **P3 — useful when 6.4 ships** |
| 15 | **Release-tag automation** | swift-nio (release_builds.yml), realm (release.yml), pointfreeco (release.yml — homebrew) | NONE | Most surveyed orgs have *some* release automation. swift-primitives currently has no tags ecosystem-wide; release automation is meaningless until packages reach 1.0. Defer | **P3 — defer until first 1.0** |
| 16 | **GitHub dependency-graph submission** | vapor/ci (`submit-deps.yml`) | NONE | Submits SwiftPM dep graph to GitHub's dependency graph for security advisory matching. Useful when consuming third-party deps; less useful for an internally-pinned ecosystem. Risk: noise from internal-only deps. Defer | **P4 — low-priority** |
| 17 | **Embedded matrix expansion (Wasm SDK)** | swiftlang/swift-syntax (Embedded Wasm SDK + Android SDK) | Embedded build (L1 layer wrapper, no SDK) | The L1 embedded job currently only builds with `-enable-experimental-feature Embedded` against the nightly Linux container. swiftlang's pattern uses the actual Wasm SDK which is closer to a real embedded target. Higher-fidelity verification, more setup cost | **P3 — incremental** |
| 18 | **Cross-platform parity reports** | NONE surveyed (each org reports per-job) | NONE | A single PR comment summarizing pass/fail per platform would aid review. Not present in any surveyed org. Tooling effort for marginal value | **P5 — defer** |
| 19 | **Static SDK build (Linux musl)** | swift-nio (`static_sdk.yml`) | NONE | Useful for deployment to musl-only environments (alpine, distroless). Not currently a deployment target for L1 ecosystem | **P5 — defer until needed** |
| 20 | **CXX interop matrix** | swift-nio (`cxx_interop.yml`) | NONE | Verifies the package builds with `-cxx-interoperability-mode=default`. Currently no L1 package depends on C++; would matter for future foundation packages | **P5 — defer until needed** |

#### 3.2 Aggregate priority bands (v1.0.0 — historical; superseded by §3.4)

Original v1.0.0 priority bands retained here for traceability:

- **P0 (in-flight)**: TS-spine gate (#1). Phase β design above.
- **P1 (high-value, do next)**: Foundation-import enforcement (#2).
- **P2 (easy wins, batch)**: License-header (#4), YAML lint (#7), Shell check (#8), Python lint (#9), Commit-lint (#13).
- **P3 (deferred until prerequisites)**: API-breakage (#3), Benchmark regression (#12), Auto-PR toolchain bumps (#14), Release-tag automation (#15), Embedded matrix expansion (#17).
- **P4 (low-priority)**: Unacceptable-language (#5), broken-symlink (#6), GH dep-graph (#16).
- **P5 (research probes / unfit)**: Per-package size diff (#10), macro-build (#11), Cross-platform parity (#18), Static SDK Linux musl (#19), CXX interop (#20).

The collaborative discussion (§3.4) re-prioritized API-breakage (#3) up to γ-1, broken-symlink (#6) to γ-2, and Static SDK Linux musl (#19) to γ-3b after surfacing the unlimited-public-minutes affordance (compute is no longer the binding constraint; signal quality is).

#### 3.3 Recommended next-cycle bundle (v1.0.0 — historical; superseded by §3.4)

The original v1.0.0 bundle proposal (`lint-no-foundation-import.yml` + license + yaml + shell + python + commit-lint) is replaced by the v1.1.0 converged phase-by-phase plan in §3.4. The shape (per-concern reusables called from the universal swift-ci.yml; weekly tracking-issue orchestrators per `[README-167]`) carries forward; the per-phase composition is finalized in §3.4.

#### 3.4 Converged plan (v1.1.0 — authoritative)

Source: 4-round Claude+ChatGPT collaborative discussion, 2026-05-04. Transcript: `/tmp/ci-improvements-catalog-transcript.md`. Converged artifact: `/tmp/ci-improvements-catalog-converged.md`. Both parties marked CONVERGED at Round 4.

##### 3.4.1 Phased roadmap

| Phase | Items | Class | Graduation |
|---|---|---|---|
| **β** (in flight) | TS-spine gate | structural invariant | 2 consecutive clean weekly sweeps |
| **γ-1a** | Foundation-family import enforcement | L1 identity invariant — deterministic | zero violations (both tracks) for 2 weeks |
| **γ-1b** | License-header (Apache 2.0, `Sources/**/*.swift`) | L1 identity invariant — three-step | advisory → codemod → gate; 2 clean weeks post-codemod |
| **γ-1c** | API-breakage advisory pilot | L1 identity invariant — pilot-classified | no class-A failures for 4 weeks + B/C/D ratio understood |
| **γ-2** | YAML lint + broken-symlink (consolidated weekly) | mechanical hygiene — deterministic | zero violations for 2 weeks |
| **γ-2b** (v1.2.0) | GitHub dependency-graph submission | supply-chain — judgment-based | monthly review of submission success rate + Dependabot signal-to-noise |
| **γ-3** | Wasm SDK | target-fidelity laboratory | no package-actionable failures + no toolchain instability for 2 sweeps |
| **γ-3b** | Static Linux musl (advisory trial if cheap) | target-fidelity laboratory | same as γ-3, may stay advisory indefinitely |
| **γ-4** | PR-title lint (event-based) | cultural — judgment-based | monthly noise:value review |

##### 3.4.2 Foundation-family import rule (γ-1a)

Forbidden in `Sources/**` and `Tests/Support/**` (gating ERROR); warning in `Tests/**` outside `Tests/Support/`. Catches all attribute/access-modifier permutations:

```
import Foundation
public import Foundation
package import Foundation
internal import Foundation
@_exported import Foundation
@_exported public import Foundation
@_implementationOnly import Foundation
@preconcurrency import Foundation
@preconcurrency public import Foundation
```

Where `Foundation ∈ {Foundation, FoundationEssentials, FoundationInternationalization}`.

Bare `#if canImport(Foundation*)` is WARNING-only; the import inside the block is the gating violation.

Strict-uniform Test Support naming: target `* Test Support`, path `Tests/Support/` — user-confirmed convention. Other shapes are structural defects (raise via the existing spine audit, not the Foundation audit).

Implementation: textual scanner (regex), conservative syntactic gate. SwiftSyntax-based semantic analysis is out of scope for γ-1a and tracked as a future enhancement.

##### 3.4.3 License-header rule (γ-1b)

Apache 2.0 header on every `Sources/**/*.swift`. No exemptions needed for L1 (verified: no generated files; no `Sources/*Generated*` paths; no `*.generated.swift` files; no `// Generated by` markers). `Tests/**` and `Package.swift` excluded from the first version. Vendored code: not present in L1; if introduced in higher layers, address with a `Vendored/` directory convention.

**Empirical state (verified 2026-05-04)**: L1 source files currently have NO Apache 2.0 headers (sampled `swift-property-primitives`, `swift-tagged-primitives` — files start directly with `import`/`extension`). License-header check therefore mass-fails on day-1 advisory landing; that is the *intended* surfacing of the gap, not a regression.

Three-step graduation:

1. **γ-1b-advisory** — land the advisory `lint-license-header.yml` reusable; first weekly tracking issue summarizes the gap collapsed:
   ```
   Missing Apache 2.0 headers:
   - Packages affected: N
   - Files affected: M
   - Full machine-readable report: artifact
   - Next action: authorized codemod cleanup
   ```
2. **γ-1b-codemod** — separate per-action authorization (bulk-push class per `[HANDOFF-023]`); mass-apply Apache 2.0 header across all in-scope `Sources/**/*.swift`.
3. **γ-1b-gating** — after 2 consecutive clean public-CI sweeps + 2 clean principal-side audits, remove `continue-on-error: true`.

##### 3.4.4 API-breakage advisory pilot (γ-1c)

Run `swift package diagnose-api-breaking-changes` broadly across all public packages with public products. PR-only trigger; `continue-on-error: true`; baseline = PR base commit (no tag required — the v1.0.0 "wait until first 1.0" framing was wrong).

Four-class tracking on the weekly tracking issue:
```
A. Own public API change       (genuine drift; the rule's intended catch)
B. Dependency drift            (re-exported type from branch-pinned dep changed)
C. Toolchain/parser issue      (swift-api-digester regression, false positive)
D. Workflow/setup issue        (CI infra defect; baseline build failed; etc.)
```

After 4 weeks: review A:B:C:D ratio. If A is dominant, plan γ-1c → δ flip. If B/C dominate, the pilot has insufficient signal — either add dependency freezing (lock branch-pinned deps at PR-base time via worktree) or stay advisory longer.

**Branch-pinned-dep false-positive caveat**: both PR-base and PR-head builds resolve `branch: "main"` deps to the same current state. If Y's API changed between PR-base time and PR-head time, X's reported API may differ for reasons unrelated to X. Class-B tracking surfaces these; observation period decides whether dep-freezing is worth the complexity.

##### 3.4.5 YAML lint scope (γ-2) + broken-symlink (γ-2)

YAML lint scope (consolidated reusable):
```
.github/workflows/**/*.yml
.github/workflows/**/*.yaml
.github/dependabot.yml
.github/metadata.yaml
metadata.yaml
```

Exclude `.swiftlint.yml`, `.swift-format`, package-local tool configuration (per `[CI-057]` per-package autonomy).

Permissive starter config:
```yaml
extends: default
rules:
  document-start: disable
  line-length: { max: 200, level: warning }
  truthy: { allowed-values: ["true", "false"], check-keys: false }
  indentation: { spaces: 2 }
  comments: { require-starting-space: false }
```

Broken-symlink check: `find -L . -type l ! -exec test -e {} \; -print`. Single shell invocation. Advisory.

γ-2 uses a CONSOLIDATED weekly tracking issue (single "Mechanical hygiene sweep" issue covers both YAML and broken-symlink findings) — small mechanical checks; consolidating reduces notification surface.

##### 3.4.5b GitHub dependency-graph submission (γ-2b) — v1.2.0 addition

**Origin**: v1.1.0's collaborative-discussion concluded "DEFER" on the framing that public Swift Institute repos depend on private intra-Institute siblings, leaking private package names via the GitHub Dependents API. The principal subsequently clarified that those intra-Institute private packages will go public on a near-term timeline. Decomposing the deferral's privacy concern into three sub-concerns:

| Sub-concern | Time-bounded? | v1.2.0 reading |
|---|---|---|
| Sub-1. Currently-private package names leaked from public consumers' dep graphs BEFORE the named packages go public | YES — dissolves the moment each package goes public | The only sub-concern that was load-bearing for the deferral. Resolves on publish wave |
| Sub-2. Relationship disclosure ("Used by" stats; queryable Dependents API) between two public packages | Permanent | A feature once the ecosystem is public, not a bug — Dependabot security advisories + ecosystem-reach signal |
| Sub-3. Pre-1.0 refactor churn (e.g., `swift-rendering-primitives` → `swift-render-primitives` rename) makes submitted graphs noisy at each push | Until 1.0 | Not specific to dep-graph submission; same churn affects every state-disclosing tool |

Only Sub-1 motivated v1.1.0's deferral. Given the publish wave timeline, the leak duration per package is days/weeks, not permanent. **Land in advisory mode now** (Option A from the principal's three-option re-evaluation).

**Workflow shape**:

| Element | Decision |
|---|---|
| File | `swift-institute/.github/.github/workflows/submit-dep-graph.yml` (separate reusable per the per-concern pattern) |
| Trigger | `push` to `main` only (PRs don't update the GitHub dep graph) |
| Caller | The universal `swift-ci.yml` adds a `submit-dep-graph: uses: ./submit-dep-graph.yml` job, conditional on `if: ${{ github.event_name == 'push' && !github.event.repository.private }}`. No per-package `ci.yml` edits per `[CI-031]` |
| Action | `vapor-community/swift-dependency-submission@b3073f8c070033ab550b2e02d90d9ff1e426f123` (SHA-pinned per ChatGPT R1-P6 + my A7 + `feedback_latest_versions_only.md`'s hardening rule for third-party actions) |
| Permissions | `permissions: contents: write` at the calling job level per `[CI-026]` Path B (per-caller, not org-default). Other swift-ci.yml jobs stay at `contents: read` |
| Visibility | Public-only via `[CI-032]` (private repos skip; aligned with `[CI-060]` Free-plan org-secret-visibility model) |
| Forks | Skip — `if: ${{ github.event.repository.fork == false && ... }}`; forks have no business submitting dep graphs to upstream |
| Cache | Standard `[CI-040]` no-cache (the action does its own SwiftPM resolve in the runner) |
| Failure mode | Advisory (`continue-on-error: true` at the calling site initially); the submission failing means the dep graph is briefly stale, not a build break |

**Reference shape** (proposed; NOT to be created in this round):

```yaml
# swift-institute/.github/.github/workflows/submit-dep-graph.yml
name: Submit dependency graph

on:
  workflow_call: {}

jobs:
  submit:
    name: Submit GitHub dependency graph
    if: ${{ !github.event.repository.private && github.event.repository.fork == false }}
    runs-on: ubuntu-latest
    container: swift:6.3
    timeout-minutes: 15
    permissions:
      contents: write           # required by github-dependency-submission
    steps:
      - uses: actions/checkout@v6

      - if: ${{ env.PRIVATE_REPO_TOKEN != '' }}
        env:
          PRIVATE_REPO_TOKEN: ${{ secrets.PRIVATE_REPO_TOKEN }}
        name: Configure git for private repos
        run: |
          git config --global url."https://${PRIVATE_REPO_TOKEN}@github.com/".insteadOf "https://github.com/"

      - name: Submit dependency graph
        uses: vapor-community/swift-dependency-submission@b3073f8c070033ab550b2e02d90d9ff1e426f123  # v0.2.0
        with:
          path: ${{ github.workspace }}
```

```yaml
# Append after the format/lint block in swift-institute/.github/.github/workflows/swift-ci.yml:

  submit-dep-graph:
    name: Submit dependency graph (advisory)
    if: ${{ github.event_name == 'push' && !github.event.repository.private }}
    uses: ./.github/workflows/submit-dep-graph.yml
    secrets: inherit
    continue-on-error: true     # γ-2b advisory; review at month 1 + month 3
```

**Graduation criterion** (judgment-based, not deterministic):

- Month 1 review: submission-success rate (target: >95% across active public repos); Dependabot signal-to-noise on the resulting advisories (target: ≥1 actionable advisory per quarter to justify the cost; near-zero false-positive rate from internal-package matches).
- Month 3 review: same metrics + an audit of "what private package names appeared in submitted graphs and have they since gone public?" (target: each leaked-then-published package's GA milestone aligns with leak resolution).
- Flip from advisory to "established practice" (drop `continue-on-error: true`) at the month-3 mark IF success rate is high and the advisory load is healthy. There is no "gating" flip in the sense γ-1a/γ-1b have — the action either succeeds or doesn't; failures are infrastructure issues not contributor-correctable defects.

**Mitigation note** (Sub-1 leak-during-transition): the principal's publish-wave plan is the load-bearing mitigation for Sub-1. If the publish wave stalls (some packages stay private materially longer than expected), the v1.2.0 reading degrades back toward v1.1.0's. Tracking obligation: surface each currently-private package whose name appears in a submitted graph in the month-1/month-3 review reports.

**Cross-references**: ChatGPT R3-P5 (third-party action SHA-pinned + minimal perms + public-only + no forks); Vapor's `submit-deps.yml` at vapor/ci@`7b8df8b7` (the precedent action + permission shape); `[CI-026]` Path B per-caller permissions (from `ci-centralization-strategy.md` v1.1.0); `[CI-032]` visibility gate; `[CI-031]` per-package caller minimum.

##### 3.4.6 Wasm SDK (γ-3) + Static Linux musl (γ-3b)

**Wasm SDK** (γ-3): build with the Embedded Wasm SDK on stable Swift 6.3 first (per `swiftlang/swift-syntax` precedent), nightly only if SDK requires. New job at swift-primitives layer wrapper alongside existing `embedded` job. 4-week classified soak. Flip on "no package-actionable failures + no toolchain instability for 2 consecutive sweeps."

**Static Linux musl** (γ-3b): implement IF setup is ~30 minutes (SDK install via `swift sdk install <static-linux-bundle>` + one new job at L1 layer wrapper). Skip if SDK installer is brittle (custom container, custom auth, post-install fix-ups). Five-class failure classification:

```
A. package-actionable failure   (genuine glibc-ism, dynamic-only dep, etc.)
B. toolchain failure             (swift-api-digester regression, miscompile)
C. SDK installation failure       (network, version mismatch, container ABI)
D. workflow failure               (CI infra defect)
E. known unsupported target       (the package legitimately doesn't target static Linux)
```

After 4 weeks: if A:(B+C+D+E) ratio is reasonable (≥30% A), keep. Otherwise drop with rationale. May stay advisory indefinitely.

γ-3 framing: **target-fidelity laboratory**. Each fidelity job:
- Separately named (so failures point at the specific target).
- Separately classified.
- Independent flip schedule.
- Public-CI-only (per `[CI-032]`).

Unlimited public CI minutes mean γ-3 / γ-3b can run a broader advisory matrix than minutes-constrained orgs would tolerate. Compute is no longer the binding constraint; signal quality + classification discipline are.

##### 3.4.7 PR-title lint (γ-4)

Triggered on PR open/edit. NOT per-commit lint (squash-merge alignment: PR title becomes the commit-on-main).

Format: existing internal `<scope>: <imperative>` convention (NOT conventional-commits — keep PR-title lint about readable history, not release automation).

Behavioral cue in PR comment: "This title is expected to become the squash commit subject."

Advisory, never gating. Monthly noise:value review; drop if friction-theater.

##### 3.4.8 GitHub dependency-graph submission — RESOLVED in v1.2.0

**v1.1.0 reading (historical, superseded)**: Deferred under the privacy framing — public Swift Institute repos depend on private intra-Institute packages, leaking those names via the GitHub Dependents API.

**v1.2.0 resolution**: The principal clarified that intra-Institute private packages will go public on a near-term timeline. Decomposing the v1.1.0 privacy concern (Sub-1 / Sub-2 / Sub-3 in §3.4.5b above) shows only Sub-1 was load-bearing for the deferral, and Sub-1 dissolves on the publish-wave timeline. The capability is therefore promoted from DEFERRED to **γ-2b** (advisory now). See §3.4.5b for design.

**What remains deferred (v1.2.0 state)**: nothing from the eight selected capabilities. The deferred-list is empty.

##### 3.4.9 Two-track audit model (operational scaffolding)

Public CI runs the per-PR advisory checks across all public consumer repos. Principal runs the same `preflight-*.py` audit logic on-disk against the private subset on weekly Monday cadence.

Each weekly tracking issue at `swift-institute/.github` carries two summary blocks:

```
## Public CI sweep (automated)
- Repos scanned: N (public only)
- Findings: …

## Principal-side ecosystem audit (manual; on-disk)
- Repos scanned: M (M > N because it includes private)
- Findings: …
- Last run: YYYY-MM-DD
```

γ-1a / γ-1b / γ-1c flip criteria require BOTH:
- Public CI clean for 2+ consecutive sweeps;
- AND principal-side audit clean for the same window.

The principal already runs the spine audit ecosystem-wide via `preflight-test-support-spine.py`; the same pattern extends to Foundation, License-header, API-breakage with `--package-dir <path>` mode (per §1.6 of this doc) wrapped in a per-org enumeration loop.

##### 3.4.10 Graduation models per check class

| Phase | Class | Graduation criterion |
|---|---|---|
| γ-1a Foundation | deterministic | "zero violations across both tracks for 2 weeks" |
| γ-1b License-header | three-step deterministic | post-codemod, "zero missing-header findings for 2 weeks" |
| γ-1c API-breakage | pilot-classified | "no class-A failures for 4 weeks AND class-B/C/D ratio understood" |
| γ-2 YAML/symlink | deterministic | "zero violations for 2 weeks" |
| γ-2b GH dep-graph submission (v1.2.0) | judgment-based | month-1 + month-3 review of submission success rate (>95%) + Dependabot signal-to-noise (≥1 actionable advisory/quarter; near-zero false-positive); flip to "established practice" at month 3 if healthy. No gating flip. |
| γ-3 Wasm SDK | fidelity-classified | "no package-actionable failures for 2 consecutive weekly sweeps AND no unresolved recurring toolchain instability" |
| γ-3b Static Linux musl | fidelity-classified (may stay advisory) | same as γ-3; may stay advisory indefinitely if class-A signal is sparse |
| γ-4 PR-title lint | judgment-based | "monthly noise:value ratio acceptable" |

The distinction: deterministic checks have binary "violation/no-violation" outcomes; fidelity checks have "package-actionable / toolchain / etc." outcomes that require classification before graduation.

##### 3.4.11 Architectural shape

- All new audits as **separate reusable workflows** (per-concern), not folded into one large soundness-style file. Matches the three-tier `[CI-001]` chain and the Phase β template.
- Each reusable called from the universal `swift-ci.yml` (transitive ride; no per-package caller edits per `[CI-031]`).
- Advisory mode = ~~`continue-on-error: true` at the calling site~~ → **CORRECTED v1.3.0** to an `advisory: bool` input on the reusable; flip to gating = drop the `with:` block at the calling site. See §3.5 for why.
- Per-family weekly tracking issues for γ-1 (Foundation, License-header, API-breakage); consolidated weekly tracking issue for γ-2 (YAML + symlink); push-event-based with month-1 + month-3 review for γ-2b GH dep-graph; event-based with monthly review for γ-4 PR-title lint; classified-fidelity tracking for γ-3 / γ-3b.
- Public-CI-only via `[CI-032]` visibility gate.
- L1 layer wrapper hosts γ-3 / γ-3b target-fidelity jobs (alongside existing `embedded` job).

#### 3.5 Implementation lessons (v1.3.0 addendum, 2026-05-05)

Empirical rollout of Phase β + γ-1a/b/c + γ-2 + γ-4 + γ-3 across `swift-institute/.github` and `swift-primitives/.github` surfaced seven runtime-correctness corrections to the v1.1.0 / v1.2.0 spec. Each is backed by a specific failed CI run and a fix commit. Future spec authoring should encode these as preconditions, not lessons-from-incident.

##### 3.5.1 `continue-on-error` is invalid on `workflow_call` jobs

GitHub Actions YAML rejects `continue-on-error:` on a job that uses `uses: ./.github/workflows/X.yml`. The flag is supported only on regular jobs (those with `runs-on:` and `steps:`) and individual steps. Run `25359051812` on swift-tagged-primitives surfaced this with `(Line: 220, Col: 5): Unexpected value 'continue-on-error'` against universal `swift-ci.yml`'s spine caller.

**Pattern (canonical):** the called reusable declares an `advisory: bool` input (default `false` = gating). The caller passes `with: { advisory: true }` during the advisory phase. The reusable's run-step gates the `exit 1` on `${{ inputs.advisory }} != "true"`. Phase γ flip = drop the `with:` block at the caller (default `false` reasserts gating). Single-line edit, like the original `continue-on-error` flip would have been.

**Fix commit:** `swift-institute/.github` `b5d8445`. Applies to every `workflow_call`-routed advisory in the v1.1.0/v1.2.0 spec: §1.4, §1.5, §3.4.5b's calling-site snippet.

##### 3.5.2 `swift:6.3` container default shell is `sh -e`, not bash

The `swift:6.3` Docker image's default shell for `run:` blocks is dash/POSIX-`sh`, not bash. `set -o pipefail` is bash-only and dash rejects it: `Illegal option -o pipefail`, exit code 2. Run `25359050534` on swift-carrier-primitives surfaced this on the spine workflow's "Fetch audit script" step.

**Pattern:** every run-step inside a container that uses bash idioms (`set -euo pipefail`, `mapfile`, `[[`, `<<<`, process substitution `<( ... )`) MUST declare `shell: bash` explicitly. The existing `swift-ci.yml` SwiftLint install step already follows this pattern (line ~194).

**Fix commit:** `swift-institute/.github` `4756b74`.

##### 3.5.3 `swift:6.3` lacks `curl`, `python3`, and `gh`

The `swift:6.3` image is a minimal Swift toolchain on `ubuntu:jammy`. It does NOT ship `curl`, `python3`, or the GitHub CLI. Three runs (`25359142784` curl, `25359222877` python3, plus the spine cron's planned `gh` install) surfaced these gaps in sequence.

**Pattern:** containerized run-steps that use these tools must `apt-get update -qq && apt-get install -qq -y <tools>` first. For pure-Python audits without `swift package dump-package` needs (γ-1a Foundation-import, γ-1b License-header), prefer `runs-on: ubuntu-latest` no-container — it ships `curl` + `python3` + `gh` pre-installed and saves ~3-5 min per run on container pull + apt install.

**Fix commits:** `swift-institute/.github` `2c1b429` (curl), `bd52c33` (python3 + cron's gh), `1aafa89` (γ-1a/b switch off swift:6.3 to ubuntu-latest).

##### 3.5.4 Permissions chain: a called workflow's declared `permissions:` must be ≤ its caller's

A `workflow_call` reusable that declares `permissions: contents: write` at its job level CANNOT escalate above the caller's grant. If the consumer-→layer-wrapper-→universal chain doesn't grant `contents: write` at every level, the workflow chain fails parse with `startup_failure`, *before any job runs*, and the API returns `jobs: []`. Run `25359721818` on swift-carrier-primitives surfaced this with three consecutive startup_failures after `2480628` added the γ-2b `submit-dep-graph` calling job.

**Pattern:** for any reusable whose job needs elevated permissions (write/issues/etc.), the caller chain at every level must declare equivalent or greater. With `[CI-031]` minimum at consumer ci.yml (no permissions block by design), the only viable invocation is a NON-reusable pattern — a separate per-package workflow that takes its top-level `permissions:` directly. γ-2b dep-graph submission RE-DEFERRED in v1.3.0 pending this design choice.

**Fix commit:** `swift-institute/.github` `41e1815` (caller commented out).

##### 3.5.5 Pure-Python audits prefer ubuntu-latest no-container

When an audit's runtime needs are confined to Python stdlib (regex, json, pathlib) — no `swift package dump-package`, no `swift build` — `runs-on: ubuntu-latest` (no container) outperforms `container: swift:6.3` by ~3-5 min per run (saved on container pull + apt install). Run `25360357293` had γ-1a + γ-1b at 5m+ each in swift:6.3; the same audits switched to ubuntu-latest run in ~3s each.

**Pattern:** `container: swift:6.3` is justified ONLY when `swift` (or specific Swift toolchain tooling) is on the audit's hot path. Default to ubuntu-latest no-container otherwise.

**Fix commit:** `swift-institute/.github` `1aafa89`.

##### 3.5.6 Cron orchestrator scope is bounded by GitHub App installation

`actions/create-github-app-token@v1` mints an installation-scoped token. `gh repo list "$ORG"` against that token returns only the repos the app is installed on, not all repos in the org. Run `25361063976` on the license-header cron iterated only 4 of ~132 swift-primitives consumer repos because the `swift-institute-bot` GitHub App is installed on a 4-repo subset.

**Pattern (resolution options):** (a) install the GitHub App on the whole org (operational, not workflow-side); OR (b) rewrite cron orchestrators to use unauthenticated public-repo listing via `curl https://api.github.com/orgs/$ORG/repos?per_page=100` (rate-limited but adequate for weekly). v1.3.0 documents the constraint; the choice between (a) and (b) is principal-side.

**Reference:** spine cron ID `25360873926` runs against the apt-installed `gh` in swift:6.3 with the same App token; longer runtime (~10 min) suggests it iterates more repos, but per-installation rather than per-org.

##### 3.5.7 Wasm SDK ABI is pinned to a specific Swift version

The official `swift-6.3-RELEASE_wasm.artifactbundle` is built against Swift 6.3.0. The `swift:6.3` Docker image currently provides Swift 6.3.1. `swift build --swift-sdk swift-6.3-RELEASE_wasm-embedded` fails with `module compiled with Swift 6.3 cannot be imported by the Swift 6.3.1 compiler` — a class-B (toolchain) failure under the four-class soak per §3.4.6. Run `25361066201` on swift-carrier-primitives surfaced this; SDK install ✓, build ✗.

**Pattern:** the Wasm SDK and the container Swift toolchain MUST match exactly (down to the patch version). When swift.org publishes an updated SDK matching `swift:6.3.1` (or pin the container to `swift:6.3.0` via a deeper image tag), γ-3 will start passing. Until then, the advisory captures the failure correctly — this is exactly what the four-class soak is designed for.

**Fix commit:** none — advisory captures the mismatch; resolution is upstream (swift.org SDK release cadence) or container-pin discipline.

---

## Outcome

**Status**: RECOMMENDATION

### Phase β (the spine gate) — recommendation

Adopt **Option β** (separate reusable `lint-test-support-spine.yml` called from `swift-institute/.github/.github/workflows/swift-ci.yml`):

- New file: `swift-institute/.github/.github/workflows/lint-test-support-spine.yml` (sketch in §1.4).
- New file: `swift-institute/.github/.github/workflows/lint-test-support-spine-weekly.yml` (sketch in §1.7), mirroring `lint-readme-presence-weekly.yml`'s shape.
- Edit `swift-institute/.github/.github/workflows/swift-ci.yml` to add a `lint-test-support-spine` job per §1.5 with `continue-on-error: true`.
- Extend `swift-institute/Scripts/preflight-test-support-spine.py` with `--package-dir <path>` for per-package mode (§1.6).
- β→γ flip trigger: zero-violation tracking issue (i.e., orchestrator opens NO issue) for two consecutive weekly Monday runs. Flip is a single-line edit at the calling site (remove `continue-on-error: true`).

No per-package `ci.yml` edits — the spine job rides transitively through the universal reusable per [CI-031].

### Implementation surface

- **3 file changes** in `swift-institute/.github` (one new workflow, one new orchestrator, one universal-reusable edit).
- **1 file change** in `swift-institute/Scripts` (audit script extension).
- **0 file changes** in any consumer repo.

### β → γ authorization gates

Each downstream phase requires its own per-action authorization per `feedback_no_public_or_tag_without_explicit_yes.md`:

1. **Phase β land**: push the 3-file `swift-institute/.github` change + 1-file `swift-institute/Scripts` change.
2. **Phase β observation**: 2 consecutive weekly Mondays of clean tracking issue.
3. **Phase γ flip**: single-line edit removing `continue-on-error: true` at the calling site; per-action authorized push.
4. **Phase 2b/c/d** (out of this doc's scope): swift-standards / swift-foundations / swift-iso strict shells (per parent handoff).

### Improvements catalog — recommendation (v1.2.0)

The v1.0.0 priority bands (§3.2) and recommended bundle (§3.3) are SUPERSEDED by §3.4. The v1.1.0 deferral of GH dep-graph submission is SUPERSEDED by v1.2.0's promotion to γ-2b (see §3.4.5b). Final roadmap:

- **Phase β** (in flight): TS-spine gate.
- **Phase γ-1**: L1 identity invariants — γ-1a Foundation-family import (deterministic) + γ-1b License-header (advisory→codemod→gate three-step) + γ-1c API-breakage advisory pilot (pilot-classified).
- **Phase γ-2**: Mechanical hygiene — YAML lint + broken-symlink (consolidated weekly tracking issue, deterministic).
- **Phase γ-2b** (v1.2.0): GitHub dependency-graph submission (separate `submit-dep-graph.yml` reusable, push-to-main only, SHA-pinned third-party action, `contents: write` per `[CI-026]` Path B, public-only via `[CI-032]`, judgment-based graduation at month 1 + month 3).
- **Phase γ-3 / γ-3b**: Target-fidelity laboratory — Wasm SDK + Static Linux musl (fidelity-classified, advisory; γ-3b only if cheap to implement).
- **Phase γ-4**: Cultural — PR-title lint (event-based, judgment-based).
- **Deferred**: nothing from the eight selected capabilities; deferred list is empty in v1.2.0.

Two-track audit model (public CI + principal-side periodic on-disk) bridges the public-only-CI ecosystem-coverage gap for γ-1 deterministic checks. Graduation models formalized per check class (§3.4.10).

### What this doc does NOT decide

This is a research-only document. It does NOT:

- Create any of the proposed workflow files.
- Modify `swift-ci.yml`.
- Modify the audit script.
- Push or tag anything.

Each Phase β → γ → P1 → P2 step is an explicit user-authorized cycle.

---

## References

### Internal cross-references (verified 2026-05-04)

- [`ci-centralization-strategy.md`](ci-centralization-strategy.md) v1.1.0 (2026-04-22, RECOMMENDATION) — reusable-workflows-as-foundation pattern + sync-script for per-repo configs. Extended (not duplicated) by this doc per [HANDOFF-013].
- [`ci-cache-strategy-branch-pinned-dependencies.md`](ci-cache-strategy-branch-pinned-dependencies.md) v1.1.0 (2026-05-04, RECOMMENDATION) — no-cache decision, Apple-aligned. Treated as settled.
- [`gitignore-sync-strategy.md`](gitignore-sync-strategy.md) — sync-script precedent.
- [`github-metadata-harmonization.md`](github-metadata-harmonization.md) — `sync-metadata` pattern this doc cites for [README-167] reporting shape.
- `swift-institute/Skills/ci-cd-workflows/SKILL.md` — [CI-001]–[CI-060]. Every Phase β design choice cite-extends a rule here.
- `swift-institute/Skills/modularization/SKILL.md` — [MOD-024] (the rule the spine gate enforces).
- `swift-institute/Skills/readme/ci-automation.md` — [README-167] (tracking-issue reporting shape).
- `HANDOFF-test-support-spine-phase-2.md` (parent handoff) — Key Decisions #4 (the Phase β placement directive).
- `HANDOFF-centralized-swift-ci-research.md` (this investigation's brief).

### External / surveyed prior art (verified 2026-05-04 via `gh api commits/main`)

- [`swiftlang/github-workflows`](https://github.com/swiftlang/github-workflows) at SHA `a2de0e0b63aba05db30493c92fd1292df3110e2a` — soundness.yml authoritative reusable.
- [`swiftlang/github-workflows/.github/workflows/swift_package_test.yml`](https://github.com/swiftlang/github-workflows/blob/main/.github/workflows/swift_package_test.yml) — 995 lines, zero `actions/cache` (verified independently in ci-cache-strategy.md).
- [`apple/swift-nio`](https://github.com/apple/swift-nio) at SHA `f71c8d2a5e74a2c6d11a0fbe324774b5d6084237` — 17 own reusables (`unit_tests.yml`, `swift_matrix.yml`, `static_sdk.yml`, `release_builds.yml`, `cxx_interop.yml`, `cmake_tests.yml`, `wasm_swift_sdk.yml`, `android_swift_sdk.yml`, `swift_load_test_matrix.yml`, `macos_benchmarks.yml`, `swift_6_language_mode.yml`, `swift_test_matrix.yml`, `pull_request.yml`, `pull_request_label.yml`, `main.yml`, `benchmarks.yml`, `macos_tests.yml`).
- [`vapor/ci`](https://github.com/vapor/ci) at SHA `7b8df8b757afd1a9a900ce56fdb51f0e09dac164` — 4 reusables (`run-unit-tests.yml`, `run-benchmark.yml`, `submit-deps.yml`, `self-test.yml`).
- [`vapor/ci/.github/workflows/submit-deps.yml`](https://github.com/vapor/ci/blob/main/.github/workflows/submit-deps.yml) — uses `vapor-community/swift-dependency-submission@b3073f8c070033ab550b2e02d90d9ff1e426f123` (SHA-pinned).
- [`vapor/vapor`](https://github.com/vapor/vapor) at HEAD of branch — `test.yml` consumes `vapor/ci/.github/workflows/run-unit-tests.yml@main` and `vapor/ci/.github/workflows/submit-deps.yml@main` with `secrets: inherit`.
- [`swift-server/async-http-client`](https://github.com/swift-server/async-http-client) at SHA `8cfd301b4163e7009c1b6a2b35feaf6812c2157a` — `main.yml` consumes `apple/swift-nio/.github/workflows/unit_tests.yml@main` with multi-toolchain matrix overrides.
- [`pointfreeco/swift-composable-architecture`](https://github.com/pointfreeco/swift-composable-architecture) at SHA `7517cc32aa083773f096dc4724a0b83215bf3c55` — `ci.yml` carries `actions/cache@v3` + `restore-keys: deriveddata-xcodebuild-IOS-16.4-test-` partial-prefix (vulnerable shape, not adopted by Swift Institute).
- [`nicklockwood/SwiftFormat`](https://github.com/nicklockwood/SwiftFormat) at SHA `a5fa7a6a57abeb834df1b3fa43ea9133137d5ade` — single `build.yml`, per-repo inline.
- [`realm/SwiftLint`](https://github.com/realm/SwiftLint) at SHA `98b687f8727c9fa23756febb3f90ce75720a3ff5` — 9 separate workflows (`build`, `docker`, `docs`, `lint`, `plugins-sync`, `post-release`, `release`, `stale-issues`, `actor-credentials`, `copilot-setup-steps`).
- [`groue/GRDB.swift`](https://github.com/groue/GRDB.swift) at SHA `36e30a6f1ef10e4194f6af0cff90888526f0c115` — single `CI.yml`, per-repo inline.
- Apple packages consuming swiftlang reusables (verified in `ci-cache-strategy-branch-pinned-dependencies.md` references; tag pins `@0.0.7`–`@0.0.11`): swift-syntax, swift-collections, swift-numerics, swift-system, swift-format, swift-package-manager, swift-async-algorithms.

### GitHub Actions documentation

- [Reusing workflows](https://docs.github.com/en/actions/how-tos/sharing-automations/reusing-workflows) — 4-level call depth limit; `secrets: inherit` semantics.
- [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) — Team/Enterprise gate (re-cited from ci-centralization-strategy.md).
- [Required workflows deprecation](https://github.blog/2023-10-11-enforcing-code-reliability-by-requiring-workflows-with-github-repository-rules/) — January 2024 migration.
