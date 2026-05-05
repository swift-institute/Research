# CI/CD Prior Art and Pattern Survey

<!--
---
version: 1.0.0
last_updated: 2026-05-05
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## How to Use This Document

This document is a **comparative prior-art survey** of CI/CD patterns across
non-Swift ecosystems, produced as the proactive Discovery counterpart to the
three CI-specific Tier 2 RECOMMENDATIONs already in this corpus
(`ci-centralization-strategy.md`, `ci-cache-strategy-branch-pinned-dependencies.md`,
`centralized-swift-ci-and-spine-gate.md`). Those docs establish *what we have
and why*; this doc surveys *what other mature ecosystems do* and identifies
patterns absent from our current setup.

It has three parts:

- **Part I** — Survey of N representative non-Swift ecosystems on a fixed
  dimension list (architecture, caching, cross-repo orchestration, matrix,
  security, observability, etc.).
- **Part II** — Cross-ecosystem synthesis: which patterns are universal,
  which are common, which are idiosyncratic.
- **Part III** — Application to Swift Institute: where a Part-II pattern
  surfaces a candidate-for-adoption (with [RES-021] contextualization step),
  and where the absence is a deliberate design.

## Context

Swift Institute's CI/CD corpus closed three substantive cohorts on
2026-05-05: a perfecting pass, a deduplication cohort, and an
action-version-tail cleanup. A subsequent fresh-eyes audit
(`AUDIT-centralized-ci-quality-and-refactor-inventory.md`) executed three
PM cohorts on top — composite-action extractions for org enumeration,
tracking-issue upserts, and an orgs-manifest data file. The corpus is
mature enough to benefit from outside-in review: not "is the Swift
canonical reference correctly applied?" (that's covered by
`ci-cache-strategy-branch-pinned-dependencies.md` against
`swiftlang/github-workflows`) but "what patterns from non-Swift
ecosystems are absent from our setup, and which of those absences are
gaps vs deliberate design?"

**Trigger**: [RES-012] Discovery — proactive design audit driven by the
principal's request after the 2026-05-05 audit cohort closed:
*"I'd be interested in /research-process to do a literature study of
non-swift CI/CD / github workflow setups."*

**Tier**: 2 (Standard) per [RES-020]. Scope is cross-package
(ecosystem-wide); precedent-setting but reversible; medium cost of
error. Output is RECOMMENDATION, not DECISION — synthesis identifies
candidates for future cohort proposals; it does not commit to
implementation.

**Scope**: GitHub Actions workflow patterns (the platform Swift
Institute uses). Other CI platforms (CircleCI, Jenkins, Buildkite,
GitLab CI) are out of scope EXCEPT where a non-Swift ecosystem's
GitHub Actions setup deliberately re-implements a pattern from another
platform — in which case the cross-platform attribution is noted.

**Out of scope**:
- Non-CI/CD GitHub workflows (release automation, issue triage bots, etc.)
- Build-system internals (Bazel rules, cargo manifest formats, etc.)
- IDE / local-dev tooling parity (covered by a separate pending item)

## Question

1. What patterns appear in **3+ non-Swift ecosystems** for each of:
   architecture (reusable / composite), caching, cross-repo orchestration,
   matrix shape, security posture, observability, scheduled-cron sweeps,
   and tooling-install?
2. Which of those patterns are **absent from Swift Institute's current
   setup**?
3. For each absent pattern, applying [RES-021] contextualization step:
   what would adopting it look like in Swift Institute's type system /
   architecture / billing-tier constraints, and what would it cost?
4. Which absences are **gaps worth closing** (candidate cohort) vs
   **deliberate design** (do not adopt)?
5. **Central question**: where should the next CI/CD cohort proposal
   focus? Beyond the 6 areas already proposed in the post-audit
   exploration (composite-action rule, tool-binary cache,
   org-policies-sync, perf regression, SHA pinning, observability,
   local/CI parity), are there 2-3 patterns from other ecosystems that
   warrant their own cohort?

---

## Part I — Per-Ecosystem Survey

### Survey Dimensions

Each ecosystem's brief covers the same fixed 12-dimension list, enabling
clean cross-ecosystem comparison in Part II.

### Surveyed Ecosystems

| Ecosystem | Anchor repos | Brief |
|---|---|---|
| Rust | rust-lang/rust, rust-lang/cargo, rust-lang/clippy, rust-lang/rust-analyzer | §1.1 |
| Go | golang/go, kubernetes/* org galaxy, grpc/grpc-go | §1.2 |
| Python | python/cpython, pypa/pip, numpy/numpy, scipy/scipy, pre-commit/pre-commit | §1.3 |
| JS/TS | nodejs/node, denoland/deno, microsoft/TypeScript, vercel/turborepo, changesets/changesets | §1.4 |
| Multi-lang large-OSS | hashicorp/terraform (+aws), llvm/llvm-project, bazelbuild/bazel, apache/arrow | §1.5 |
| Apple's Swift reference | swiftlang/github-workflows (canonical Apple template, summarized) | §1.6 |

---

### §1.1 Rust ecosystem

Surveyed repos: `rust-lang/rust`, `rust-lang/cargo`, `rust-lang/rust-clippy`, `rust-lang/rust-analyzer`. Workflow files inspected: `rust/.github/workflows/{ci.yml, dependencies.yml, post-merge.yml, ghcr.yml}`, `cargo/.github/workflows/{main.yml, audit.yml, contrib.yml}`, `rust-clippy/.github/workflows/{clippy_pr.yml, clippy_dev.yml, clippy_changelog.yml, lintcheck.yml, lintcheck_summary.yml, deploy.yml}`, `rust-analyzer/.github/workflows/{ci.yaml, release.yaml, autopublish.yaml, metrics.yaml, rustc-pull.yml, fuzz.yml}`.

1. **Repo topology** — Polyrepo within the `rust-lang/` GitHub org. The four surveyed repos are independent, each carrying its own `.github/workflows/`; `rust-lang/rust` is itself a large repo containing the compiler, stdlib, and many in-tree tools but is not a "monorepo of repos." No workspace-level superrepo.

2. **Reusable workflows** — Almost entirely absent. Notable exception: `rust-analyzer/.github/workflows/rustc-pull.yml` calls an external reusable from a sibling org repo: `uses: rust-lang/josh-sync/.github/workflows/rustc-pull.yml@main`. No `workflow_call` definitions found in `rust/ci.yml`, `cargo/main.yml`, `rust-analyzer/ci.yaml`, or `rust-clippy/clippy_pr.yml`.

3. **Composite actions** — None found in the four repos' workflows. Repos lean on third-party marketplace actions (`taiki-e/install-action`, `EmbarkStudios/cargo-deny-action`, `Swatinem/rust-cache`, `dorny/paths-filter`, `crate-ci/typos`) rather than authoring local composites. `rust-lang/rust` instead embeds matrix logic inside an in-tree Rust crate (`citool` reading `src/ci/github-actions/jobs.yml`).

4. **Caching** — Strikingly inconsistent. `rust-lang/rust/ci.yml` has no `actions/cache`; uses S3 via `CACHES_AWS_*` and `ARTIFACTS_AWS_*` secrets. `cargo/main.yml` has no cache action. `rust-analyzer/ci.yaml` references `Swatinem/rust-cache@9d47c6ad…` but commented out. `rust-clippy/lintcheck.yml` uses `actions/cache@v5` with two key shapes: `lintcheck-bin-${{ hashFiles('lintcheck/**') }}` (binary) and `lintcheck-base-${{ hashFiles('lintcheck/**') }}-$(git rev-parse HEAD)` (results); the `diff` job uses `actions/cache/restore@v5` with `fail-on-cache-miss: true`. No `restore-keys:` fallbacks observed.

5. **Cross-repo orchestration** — Three patterns observed. (a) External reusable: `rust-analyzer/rustc-pull.yml` delegates rustc→rust-analyzer subtree sync to `rust-lang/josh-sync`. (b) Cross-workflow trigger: `rust-clippy/lintcheck_summary.yml` uses `workflow_run: workflows: [Lintcheck], types: [completed]` to post a comment after a separate workflow finishes, with explicit untrusted-data validation. (c) Out-of-band publish: `rust-analyzer/metrics.yaml` writes to a separate metrics repo via `secrets.METRICS_DEPLOY_KEY` SSH key. **No central orchestrator workflow sweeps multiple repos.**

6. **Matrix shape** — `rust-lang/rust/ci.yml` computes its matrix dynamically: a `calculate_matrix` job emits JSON consumed via `include: ${{ fromJSON(needs.calculate_matrix.outputs.jobs) }}` with rich include fields. `cargo/main.yml` `test` job has 12 hand-listed entries spanning `ubuntu-latest`, `ubuntu-24.04-arm`, `macos-14`, `windows-latest`, `windows-11-arm` across stable/beta/nightly. `rust-analyzer/ci.yaml`: `os: [ubuntu-latest, windows-latest, macos-latest]` plus a `rust-cross` job with `target: [powerpc-unknown-linux-gnu, x86_64-unknown-linux-musl, wasm32-unknown-unknown]`. `rust-analyzer/release.yaml` distributes 9 targets including `aarch64-pc-windows-msvc`, `arm-unknown-linux-gnueabihf` (cross-compiled via Zig 0.13.0).

7. **Security posture** — Mixed within the org. `cargo/main.yml` SHA-pins all third-party actions (`actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2`, `taiki-e/install-action@97a5807a604e12de3a13b52d868ebecaeeea757c # v2.75.4`). `rust-clippy` and `rust-analyzer` use major-version tags (`actions/checkout@v6`). `rust/ci.yml` uses `@v5`/`@v7` major tags. **No `id-token: write` / OIDC observed in any surveyed CI file.** `clippy/deploy.yml` uses an SSH `DEPLOY_KEY`, `rust-analyzer/autopublish.yaml` uses `CARGO_REGISTRY_TOKEN`. `clippy/deploy.yml` and `clippy_dev.yml` set `persist-credentials: false` on `actions/checkout` with explicit comments warning about malicious-dep token theft. **No SLSA / supply-chain attestation steps found.**

8. **Observability** — `rust/ci.yml` ships test results to Datadog (`secrets.DATADOG_API_KEY`). `rust/post-merge.yml` runs on `push` to `main`, locates the parent bors merge, and posts a `citool`-generated test-outcome diff comment to the merged PR. `rust-analyzer/metrics.yaml` collects build metrics on every push to `master` against five external projects (ripgrep, WebRender, Diesel, Hyper, etc.) and pushes JSON to a separate metrics repo. `rust-analyzer/rustc-pull.yml` posts to Zulip stream `185405`. `clippy/lintcheck_summary.yml` posts a markdown diff table as a PR comment after the lintcheck workflow completes.

9. **Scheduled-cron sweeps** — `rust/dependencies.yml`: `cron: '0 0 * * Sun'` (weekly cargo update + auto-PR titled "Weekly cargo update"). `rust/ghcr.yml`: `cron: '0 0 * * *'` daily DockerHub→ghcr.io mirror of pinned base images (`ubuntu:22.04`, `ubuntu:24.04`, `moby/buildkit:buildx-stable-1`, `alpine:3.4`, `centos:7`). `rust-analyzer/release.yaml`: `cron: '0 0 * * *'` daily release. `rust-analyzer/rustc-pull.yml`: `cron: '0 4 * * 1,4'` (Mon and Thu 04:00 UTC subtree sync). `rust-analyzer/fuzz.yml`: `cron: '0 0 * * 0'` weekly nightly fuzz build.

10. **Tool-binary install** — Predominant pattern is `taiki-e/install-action` for prebuilt binaries (`@nextest`, `@cargo-machete`; SHA-pinned in cargo). Toolchain itself: `rustup update stable && rustup default stable` (cargo), `rustup-toolchain-install-master@1.11.0` (rust-analyzer). Some tools fetched via raw `curl` (cargo-semver-checks, mdBook, `typos v1.38.1`). **No tool-binary cache observed.**

11. **Test layers** — `cargo/main.yml` separates `rustfmt`, `clippy`, `lint-docs`, `lockfile`, `check-version-bump`, `test`, `schema`, `resolver`, `test_gitoxide`, `build_std`, `docs`, `msrv`, `spellcheck` into independent jobs gated by a `conclusion` aggregator job (`runs-on: ubuntu-latest`, `contents: none`). `rust-analyzer/ci.yaml` separates `proc-macro-srv`, `rust`, `analysis-stats`, `rustfmt`, `clippy`, `miri`, `rust-cross`, `typescript`, `typo-check` and gates with `conclusion` + `cancel-if-matrix-failed`. Performance: `rust-analyzer/metrics.yaml` is push-on-master only (not PR-gating). Fuzz is scheduled weekly, not gating.

12. **Quality gates** — Format/lint/typo are gating via the **conclusion-aggregator pattern**: `cargo/main.yml` and `rust-analyzer/ci.yaml` both define a final `conclusion` job that fails if any dependency failed, used as the single required-status check. `cargo/audit.yml` runs `EmbarkStudios/cargo-deny-action` with `continue-on-error: ${{ matrix.checks == 'advisories' }}` — advisories are advisory, license/bans/sources are gating. `rust-analyzer/ci.yaml` sets `RUSTFLAGS: -D warnings` globally to make warnings gating.

**Patterns to flag**:

- **Conclusion-aggregator job pattern** (`cargo/main.yml`, `rust-analyzer/ci.yaml`): a final job with `needs: [all-other-jobs]` and `runs-on: ubuntu-latest`, set as the single required status check, decouples branch-protection config from workflow refactors. Cleanest replacement for "list every job in branch-protection settings."
- **Dynamic-matrix calculation** (`rust/ci.yml`): a `calculate_matrix` job emits JSON consumed via `fromJSON(needs.calculate_matrix.outputs.jobs)`. Matrix logic lives in versioned source (`src/ci/github-actions/jobs.yml` + an in-tree `citool` Rust crate), not in workflow YAML.
- **Cross-workflow PR-comment via `workflow_run`** (`clippy/lintcheck_summary.yml`): heavy work runs in PR context with restricted permissions; a separate `workflow_run`-triggered workflow has `pull-requests: write` and posts the comment, with explicit untrusted-data validation.
- **Post-merge analysis with bors-parent diff** (`rust/post-merge.yml`): on push to main, walk back to the parent merge, run a tool that diffs test outcomes, post the diff to the merged PR.
- **Daily DockerHub→ghcr.io mirror of pinned base images** (`rust/ghcr.yml`): inverts rate-limit risk — instead of pulling `ubuntu:24.04` from DockerHub at every CI run, pull from ghcr.io which has no pull rate limit. One cron job removes a class of flakes.

**Patterns deliberately absent**:

- **No SHA-pinning in `rust-lang/rust`, `rust-clippy`, or `rust-analyzer`** despite `cargo` doing it consistently. Major-version tags (`@v6`, `@v7`) are used throughout. Suggests no org-wide enforced policy.
- **No `id-token: write` / OIDC** in any surveyed workflow. Publishing uses long-lived secrets (`CARGO_REGISTRY_TOKEN`, SSH `DEPLOY_KEY`).
- **No SLSA provenance or attestation** steps observed in `rust-analyzer/release.yaml` (which ships binaries to 9 targets) or `rust-analyzer/autopublish.yaml` (crates.io publish).
- **No local composite actions.** Repetition is tolerated rather than abstracted into `.github/actions/*/action.yml`.
- **`actions/cache` largely avoided** in `rust`/`cargo`/`rust-analyzer` CI. Only `rust-clippy/lintcheck.yml` uses it actively.

---

### §1.2 Go ecosystem

Repos surveyed: `golang/go` (the language), `kubernetes/kubernetes` + `kubernetes/test-infra` + `kubernetes/release` + `kubernetes-sigs/kubebuilder` + `kubernetes-sigs/release-actions` + `kubernetes/website` (large multi-repo Go OSS user), `grpc/grpc-go` (well-engineered single-repo Go project).

1. **Repo topology** — `golang/go` is a single repo whose canonical history lives on Gerrit (`go-review.googlesource.com`); GitHub is a read-only mirror plus issue tracker. `.github/` contains only `CODE_OF_CONDUCT.md`, `ISSUE_TEMPLATE/`, `PULL_REQUEST_TEMPLATE`, `SUPPORT.md` — **no `.github/workflows/` directory**. Kubernetes is a polyrepo galaxy across `kubernetes/`, `kubernetes-sigs/`, and `kubernetes-csi/` orgs; `kubernetes/kubernetes` itself **also has no `.github/workflows/`**. GH Actions is concentrated in auxiliary repos: `kubernetes/release`, `kubernetes/website`, `kubernetes-sigs/kubebuilder`, `kubernetes-sigs/release-actions`. `grpc/grpc-go` is a conventional single Go module with eight workflow files.

2. **Reusable workflows / Prow's relationship to GH Actions** — **`golang/go` does not use GitHub Actions for primary CI** — it uses **LUCI** (Google's open-source Chromium CI), reached via `luci-token-server.appspot.com` / `chromium-swarm.appspot.com` / `cr-buildbucket.appspot.com`, with builders defined in `golang.org/x/build` (`dashboard/builders.go`) and developer access via the `gomote` tool. The legacy "Coordinator" at `farmer.golang.org` was migrated to LUCI. **Kubernetes does not use GitHub Actions for primary CI either** — it uses **Prow** (`prow.k8s.io`), a Kubernetes-based microservice CI system whose source lives at `kubernetes-sigs/prow` (formerly `kubernetes/test-infra`). Prow defines presubmit/postsubmit/periodic jobs declaratively in `kubernetes/test-infra/config/jobs/**/*.yaml` and reacts to PR chat-ops (`/test`, `/lgtm`, `/approve`); the **Tide** component handles batch merge with re-test. **`workflow_call` reusable workflows are essentially absent across surveyed repos** — the reuse mechanism is composite actions, not callable workflows.

3. **Composite actions** — The clearest example is `kubernetes-sigs/release-actions`, a deliberately factored repo of composite actions (`setup-bom/`, `setup-tejolote/`, `setup-zeitgeist/`, `setup-release-notes/`, `publish-release/`) consumed by sibling release pipelines. `kubernetes/release/.github/workflows/release.yml` calls `kubernetes-sigs/release-actions/setup-bom@8753ea6bdadb814d779c6ec34eaca689dbfb492b # v0.4.3`. Each `action.yml` has `runs: using: "composite"` and ships SHA-pinned dependencies. `grpc/grpc-go` ships zero composite actions.

4. **Caching** — Caching is delegated to `actions/setup-go`, which since v4 caches `~/go/pkg/mod` and the build cache automatically keyed by OS + hash of `cache-dependency-path`. `grpc/grpc-go/.github/workflows/testing.yml`: `cache-dependency-path: "**/*go.sum"`. `kubernetes/release/.github/workflows/release.yml` instead pins `go-version-file: go.mod` and explicitly sets `cache: false` because the goreleaser job needs reproducibility and signed builds, not speed. **No bespoke `actions/cache` invocations** observed in surveyed Go workflows.

5. **Cross-repo orchestration** — For Kubernetes this is **Prow's central job, not GH-Actions'**: a single Prow control plane in a service cluster dispatches builds across one or more build clusters, reads job configs from `kubernetes/test-infra/config/jobs/`, posts statuses back to ~hundreds of GitHub repos, and merges via Tide. **Boskos** brokers cloud-resource leases, **ghproxy** caches GitHub API calls across the fleet, **kettle** ships test results into BigQuery, and **gubernator** / **triage** cluster failures. For golang/go the analogous coordinator is LUCI; cross-repo coordination across `golang/go` ↔ `golang/build` ↔ `golang/tools` happens via Gerrit + `x/build/cmd/relui`, not GitHub.

6. **Matrix shape** — `grpc/grpc-go/.github/workflows/testing.yml` uses an explicit `include:`-list matrix rather than a Cartesian product: `Go 1.25 + Go 1.26` (latest-1 / latest), with axes for `vet` / `extras` / `tests`, plus race detector, `GOARCH=386`, and `arm64` on `ubuntu-24.04-arm`. macOS and Windows are absent from primary tests — per-OS coverage is pushed into the release stage. `grpc/grpc-go/.github/workflows/release.yml` Cartesian-multiplies `goos: [linux, darwin, windows]` × `goarch: [386, amd64, arm64]` minus `darwin/386` on a single ubuntu runner via `GOOS`/`GOARCH` env. **Convention is "latest and latest-1"**, matching the Go release-policy two-version support window.

7. **Security posture** — `kubernetes/release` is the strongest exemplar: **every action is pinned to a 40-char commit SHA** with the human-readable version in a trailing comment (`actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2`, `step-security/harden-runner@a5ad31d6a139d249332a2605b85202e8c0b78450 # v2.19.1`, `goreleaser/goreleaser-action@1a80836c5c9d9e5755a25cb59ec6f45a3b5f41a8 # v7.2.1`). **Top-level `permissions: {}` (deny-all) with per-job least-privilege grants is universal** — every k8s-org workflow opens with `permissions: {}`. **OIDC** is used for keyless signing: `release.yml` declares `permissions: { id-token: write, contents: write }` and runs `sigstore/cosign-installer` + `tejolote attest --sign`. `step-security/harden-runner` is invoked at the top of every job with `egress-policy: audit` (PR/push) or `egress-policy: block` + an `allowed-endpoints:` list (CodeQL, dependency-review). `actions/dependency-review-action` and `ossf/scorecard-action` provide supply-chain gating; SARIF is uploaded to code-scanning. `grpc/grpc-go` is markedly less hardened: actions pinned only to floating major tags, no harden-runner, no OIDC. Branch-protection on `kubernetes/kubernetes` is enforced by Prow + Tide, not GitHub native rules.

8. **Observability** — **TestGrid** (`testgrid.k8s.io`) is the public dashboard — it consumes test results that Prow uploads to GCS (under `gs://kubernetes-jenkins/`), and surfaces them as historical grids per dashboard (e.g. `sig-release-1.36-blocking`, `provider-aws-ebs-csi-driver`). It is **not tied to GH Actions runs**. **Triage** (`go.k8s.io/triage`) clusters similar test failures across all jobs. **Kettle** ships results into BigQuery; **gubernator** offers per-build inspection. golang/go's analog: the build dashboard at `farmer.golang.org` (Coordinator era) and now LUCI Milo (`ci.chromium.org/p/golang`). **The pattern: serious Go projects build dashboards external to the CI system — they don't rely on GitHub Actions' default UI.**

9. **Scheduled-cron sweeps** — `grpc/grpc-go/.github/workflows/testing.yml` runs nightly (`cron: 0 0 * * *`) over the same matrix as PR runs. `codeql-analysis.yml`: weekly CodeQL sweep (`cron: '24 20 * * 3'`). `lock.yml` (`'22 1 * * *'`) auto-locks 180-day-inactive issues/PRs via `dessant/lock-threads@v5`. `stale.yml` (`"44 */2 * * *"` every 2 h) flags stale "needs-info" issues. `kubernetes/release/.github/workflows/scorecards-analysis.yml` runs weekly. `kubernetes/website/netlify-periodic-build.yml` triggers Netlify rebuilds twice daily. Prow runs an enormous fleet of "periodic" jobs (separate from GH Actions).

10. **Tool-binary install** — `actions/setup-go` is the universal entry point. Two version-pin styles coexist: explicit (`grpc-go/testing.yml`: `go-version: '1.26'`) and **file-based** (`kubernetes/release/release.yml`: `go-version-file: go.mod`, `check-latest: true`). The file-based form binds CI to the Go version declared in `go.mod` — dominant idiom in the Kubernetes ecosystem. Beyond Go itself: `cosign`, `bom`, `tejolote`, `kind` are installed via composite actions or by direct `curl`. `golangci-lint` via `golangci/golangci-lint-action@…` SHA-pinned with `version: v2.10`.

11. **Test layers** — `grpc-go/testing.yml` separates `vet` (static checks via `./scripts/vet.sh`), `tests` (`go test -cpu 1,4 -timeout 7m ./...` over every nested `go.mod`), and `extras` (`examples/examples_test.sh`, `interop/interop_test.sh`, `internal/xds/test/e2e/run.sh`) — explicit per-layer scripts under `scripts/`. Race detection is a separate matrix entry, not a global flag. `kubebuilder/test-e2e-samples.yml` provisions a real `kind` cluster and runs `make test-e2e` against generated scaffold projects. **Conformance testing for Kubernetes itself** is the canonical example of "external CI as a fleet": `kubetest2` provisions clusters across providers, `sig-release-*-blocking` TestGrid dashboards gate releases.

12. **Quality gates** — `golangci-lint` is the de-facto umbrella linter. `kubernetes/release/.github/workflows/lint.yml` and `kubernetes-sigs/kubebuilder/.github/workflows/verify-all.yml` both call `golangci/golangci-lint-action@…` with a pinned `version:`, configured by `.golangci.yml` at repo root. `gofmt`/`go vet`/`staticcheck` are subsumed by golangci-lint. CodeQL covers SAST, scorecards covers OpenSSF supply-chain posture, dependency-review covers PR-time dependency diff.

**Patterns to flag**:

- **External CI for serious projects.** Both golang/go (LUCI) and kubernetes (Prow) chose to run their primary CI **outside GitHub Actions**, treating GH Actions as a peripheral for release/lint/triage. Validates the architectural choice that GH Actions need not dictate test topology.
- **Composite-action library as ecosystem unit.** `kubernetes-sigs/release-actions` is a small, pure repo of composite actions consumed by every release pipeline in the org — analog to swift-institute's `swift-institute/.github` reusable-workflow tier, but at the composite-action layer.
- **Strict SHA-pinning + harden-runner + OIDC as a uniform pattern** across `kubernetes/release`. Every action is `@<40-char-sha> # vX.Y.Z`; every job opens with `step-security/harden-runner` egress-policy.
- **`go-version-file: go.mod` over hard-coded versions.** Ties CI to a single source of truth in the source tree; Swift's `Package.swift` `// swift-tools-version:` could play the same role.
- **External dashboards (TestGrid) decoupled from CI.** Prow uploads to GCS; TestGrid reads GCS. CI and observability are independently versioned.

**Patterns deliberately absent**:

- **No `workflow_call` reusable workflows in surveyed Go repos.** Reuse is via composite actions, not callable workflows.
- **No "test-everything matrix" maximalism.** `grpc-go` covers exactly Go latest + latest-1, not 3+ versions; macOS/Windows pushed to release builds, not PR matrix.
- **No bespoke `actions/cache` invocations.** Trust `setup-go`'s built-in cache; don't hand-tune cache keys.
- **No GitHub-native branch-protection-only gating** at the kubernetes/kubernetes scale — Tide owns the merge queue.

---

### §1.3 Python ecosystem

Surveyed: `python/cpython`, `pypa/pip`, `pypa/cibuildwheel`, `numpy/numpy`, `scipy/scipy`, `pre-commit/pre-commit`.

1. **Repo topology** — CPython is a single canonical reference-implementation repo (language + stdlib + build system in one tree). Surrounding it: a galaxy of independent PEP-aware packaging repos. **No monorepo binding them — the coupling is via PEPs (517/518/621/660) and PyPI metadata, not shared CI scaffolding.** Workflow-file counts: 2 (`pre-commit/pre-commit`) → ~25 (CPython) → ~16 (scipy/scipy).

2. **Reusable workflows** — CPython is the canonical example of `workflow_call` reuse: `python/cpython/.github/workflows/build.yml` is a thin orchestrator dispatching to `reusable-context.yml`, `reusable-ubuntu.yml`, `reusable-macos.yml`, `reusable-windows.yml`, `reusable-windows-msi.yml`, `reusable-emscripten.yml`, `reusable-wasi.yml`, `reusable-san.yml`, `reusable-cifuzz.yml`, `reusable-docs.yml`, `reusable-check-c-api-docs.yml`. Reuse is **intra-repo only**, not cross-repo. By contrast, `pre-commit/pre-commit/.github/workflows/main.yml` calls `asottile/workflows/.github/workflows/tox.yml@v1.8.1` — a true cross-repo reusable owned by a maintainer's personal workflow library.

3. **Composite actions** — Canonical input is `actions/setup-python` (used in essentially every workflow surveyed). For wheel-building, `pypa/cibuildwheel` is itself published as a third-party action (`scipy/scipy/.github/workflows/wheels.yml` uses `pypa/cibuildwheel@298ed2fb… # v3.3.1`). For PyPI publishing, `pypa/gh-action-pypi-publish`. SciPy has an in-repo composite at `./.github/ccache` for ccache wiring.

4. **Caching** — `actions/setup-python` has built-in `cache: pip` with `cache-dependency-path` (`python/cpython/.github/workflows/mypy.yml` keyed on `Tools/requirements-dev.txt`). Build caches: CPython caches compiled OpenSSL/AWS-LC at `./multissl/openssl/${{ env.OPENSSL_VER }}` and a Hypothesis property-based-test database. SciPy uses ccache with `CCACHE_MAXSIZE: 250M` and `--evict-older-than 1d`. NumPy and SciPy `wheels.yml` files do **not** cache wheel artifacts — they rely on cibuildwheel's own internal Docker layer caching and rebuild from scratch per matrix cell.

5. **Cross-repo orchestration** — **pre-commit.ci** is the standout pattern: a hosted service that runs the consumer repo's `.pre-commit-config.yaml` on every PR, auto-fixes where possible, and **opens scheduled `pre-commit autoupdate` PRs (default weekly) that bump every hook's `rev:` pin across every repo using the service**. The fan-out is the consumer base, not the maintainer's CI. PyPI publishing fans out the other way: hundreds of repos invoke `pypa/gh-action-pypi-publish` against the same trusted-publisher registry on PyPI.

6. **Matrix shape** — `pypa/pip/.github/workflows/ci.yml` matrices Python 3.10–3.15 × {Ubuntu, macOS, Windows} with Windows pruned to {3.10, 3.14, 3.15} and a `3.14t` free-threaded variant via `PYTHON_GIL=0`. CPython's `reusable-windows.yml` runs 3 archs × 2 threading modes × interpreter variants; `reusable-ubuntu.yml` runs 2 OS × 2 threading × 2 BOLT options. NumPy uses **QEMU-driven matrices for `riscv64` and `loongarch64`** (`numpy/numpy/.github/workflows/linux_qemu.yml`), separate workflows for IBM (`linux-ibm.yml`), SIMD (`linux_simd.yml`), and BLAS variants (`linux_blas.yml`). cibuildwheel itself fans out CPython 3.8–3.14 × PyPy × GraalPy × {manylinux, musllinux, macOS, Windows, Android, iOS, Pyodide} × {x86_64, i686, aarch64, ppc64le, s390x, armv7l, arm64}.

7. **Security posture** — SHA pinning is dominant in pypa-adjacent repos but inconsistently applied within CPython itself: `python/cpython/.github/workflows/build.yml` pins `actions/checkout@de0fac2e… # v6.0.2` (SHA) but `actions/setup-python@v6.2.0` (tag) — mixed. SciPy and pip pin every action by SHA. **PyPI Trusted Publishers (OIDC)** is the headline pattern: `pypa/pip/.github/workflows/release.yml` declares `permissions: id-token: write` and calls `pypa/gh-action-pypi-publish@cef221092ed1bacb1cc03d23a2d87d1d172e277b # v1.14.0` **with no API token** — PyPI exchanges the GitHub OIDC token for a 15-minute scoped publish credential. pip also uses `zizmor` as a pre-commit hook (workflow security linter).

8. **Observability** — Read the Docs is the de facto build-status surface for documentation. NumPy publishes Scorecards results and runs `mypy_primer` + `mypy_primer_comment` to detect typechecker regressions across the ecosystem and post results on PRs. SciPy and NumPy use CodeQL. CircleCI artifacts are stitched in via dedicated workflows. **No shared release-status dashboard across the ecosystem** — each repo publishes its own.

9. **Scheduled-cron sweeps** — Dependabot is universal but tuned conservatively. **CPython tracks `github-actions` and `pip` quarterly with a 14-day cooldown**, groups all Actions under a single `actions` group, and ignores minor/patch GH-Action updates (only major bumps file PRs). NumPy runs daily with a 7-day cooldown, groups all Python deps under `python-deps`, prefixes commits `MAINT`. The pre-commit.ci `autoupdate` cron is the cross-repo equivalent — runs weekly per consumer repo. Custom cron is rare; CPython's `stale.yml` and `new-bugs-announce-notifier.yml` are the few examples.

10. **Tool-binary install** — Pattern is `actions/setup-python` then `pip install <tool>` per job — **no system-wide tool cache**. ruff, mypy, codespell, zizmor pulled in via `.pre-commit-config.yaml` rev pins. pre-commit caches its hook environments per-repo under `~/.cache/pre-commit/`, and pre-commit.ci caches them globally across users. `uv` is **not yet visible in any of the surveyed CI workflows** despite uv's rising profile in local-dev.

11. **Test layers** — Three to four layers per project. (a) **Lint/format**: ruff via `j178/prek-action`; ruff+black+mypy via pre-commit. (b) **Unit/integration**: pytest with xdist parallelization. (c) **Arch-specific** (NumPy's prime example): separate workflows for QEMU-emulated `riscv64`/`loongarch64`, `linux_simd.yml`, `linux_blas.yml`, `linux-ibm.yml`, `compiler_sanitizers.yml`, `emscripten.yml`. (d) **Type-check**: `python/cpython/.github/workflows/mypy.yml` shards across 9 directory targets with their own `mypy.ini`; NumPy runs `stubtest.yml` to verify type stubs against runtime.

12. **Quality gates** — ruff is dominant on the lint axis (CPython, pip), with black still co-resident as formatter in pip. mypy is the type-check standard. flake8 has been displaced by ruff. **pre-commit is the unifying gate**: same `.pre-commit-config.yaml` is consumed locally, in CI, and by the hosted pre-commit.ci service, with hook revs auto-bumped by the service. SciPy adds `commit_message.yml` (commit-message linting) and `array_api.yml` (Array API standard compliance check) as project-specific gates.

**Patterns to flag**:

- **PyPI Trusted Publishers (OIDC)**: GitHub OIDC token → PyPI exchange → 15-min scoped credential, no stored secret. Replaces long-lived API tokens. Directly transferable to a swift-institute "trusted publisher" model for the SwiftPM registry once that flow exists.
- **pre-commit.ci hosted-service auto-update**: Cross-repo bump-PR fan-out keyed on a single config file in each consumer. Same shape swift-institute could apply for swift-format / swiftlint / actions-version sweeps.
- **`reusable-<platform>.yml` decomposition** (CPython): one reusable per OS/arch dimension, called from a thin orchestrator. Maps cleanly onto the three-tier reusable chain in `ci-cd-workflows`.
- **cibuildwheel as a single canonical matrix-expander action**: one action consumes a config and explodes Python × platform × arch.
- **Dependabot grouping + cooldown** (CPython quarterly+14d, NumPy daily+7d): supply-chain risk-mitigation; cooldown gives 1–2 weeks of post-release vulnerability discovery before adoption.

**Patterns deliberately absent**:

- No monorepo or umbrella CI binding pip/cibuildwheel/numpy/scipy together — coupling is by spec (PEPs) not by shared workflow plumbing.
- No shared `permissions:` policy file across the ecosystem; each repo declares its own.
- No build-artifact caching of compiled wheels across runs (cibuildwheel matrices rebuild every cell from clean) — caching is restricted to dependencies (pip cache, ccache, OpenSSL) not outputs.
- No cross-repo orchestrator workflow analogous to the `swift-institute-bot` pattern; the closest analogue (pre-commit.ci) is a third-party hosted service, not maintainer-operated.
- No `uv` adoption in the surveyed CI files despite uv's rising profile in local-dev — CI lags by one tool-cycle.

---

### §1.4 JS/TS ecosystem

Subjects surveyed: `nodejs/node` (the runtime, vendored monolith), `denoland/deno` (Rust monolith with TS test surface), `microsoft/TypeScript` (the compiler, yarn-based), `vercel/turborepo` (the canonical pnpm/turbo monorepo), `changesets/changesets` (the canonical multi-package release tool).

1. **Repo topology** — Node is a single repo with vendored deps (V8, OpenSSL, WPT) updated by dedicated workflows (`update-v8.yml`, `update-openssl.yml`, `update-wpt.yml`). Deno is a single repo (Rust + TS test surface) but its workflows are **generated** from TS source — `.github/workflows/ci.generated.yml` has a sibling `ci.ts`; the directory listing shows 11 `*.generated.yml` files, each paired with a TS author. TypeScript is a single yarn-managed repo with a custom `hereby` task runner. Turborepo is itself a pnpm monorepo (its workflow filters `--filter={./packages/*}` over a workspace graph). Changesets is a small pnpm-managed monorepo with only `ci.yml` and `publish.yml`. The widely-cited "JS monorepo" pattern (pnpm + turbo + changesets) is precisely what `vercel/turborepo`'s own `.github/workflows/test-js-packages.yml` demonstrates on itself.

2. **Reusable workflows** — Almost none in the surveyed set. `nodejs/node` has `test-shared.yml` reused by `test-linux.yml`/`test-macos.yml` (a `workflow_call` shape), and a coverage triplet. The dominant reuse mechanism in JS/TS is **composite actions, not reusable workflows**.

3. **Composite actions** — Heavy use. Turborepo's `.github/actions/` contains 8 composite actions: `setup-environment`, `setup-node`, `setup-rust`, `install-global-turbo`, `setup-protoc`, `setup-capnproto`, `find-rust-changes`, `check-release-pr`. Changesets uses `./.github/actions/ci-setup`. Third-party canon: `actions/setup-node` (TypeScript pins `actions/setup-node@53b83947… # v6.3.0`) plus `pnpm/action-setup`. For Bun, turborepo pins `oven-sh/setup-bun@0c5077e51419868618aeaa5fe8019c62421857d6 # v2`.

4. **Caching** — Three patterns coexist. (a) **`actions/setup-node` built-in cache** — TypeScript uses `actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7 # v5.0.4` with custom key for `~/.cache/dprint` keyed on `package-lock.json + .dprint.jsonc`. (b) **Rust/cargo target cache for native bits** — Deno's `ci.generated.yml` keys multiple caches: `111-cargo-home-{os}-{arch}-{job-type}-main-{sha}` and `111-cargo-target-{os}-{arch}-{build-type}-{job-type}-main-{sha}`, plus a Playwright browser cache; Node uses `Mozilla-Actions/sccache-action@9e7fa8a… # v0.0.10`. (c) **Turbo remote cache** — turborepo *itself* explicitly disables remote cache in self-CI (`TURBO_API=` and `TURBO_CACHE: local:rw`), a deliberate dogfooding choice.

5. **Cross-repo orchestration** — Dominant pattern is the **changesets release flow**: `changesets/action@6a0a831f…` v1, used by `changesets/changesets/.github/workflows/publish.yml`. The action either opens a "Version Packages" PR (when changesets pending) or runs `publish` (when none pending) — single workflow handles both bookkeeping and release. Cross-repo coordination is thin: each repo runs its own changesets cycle. Turborepo's release workflow is hand-rolled with a "staging-X.Y.Z" lock branch instead of changesets.

6. **Matrix shape** — TypeScript's `ci.yml` matrix: Node `{14, 16, 18, 20, 22, 24, lts/*}` × OS `{ubuntu-latest, windows-latest, macos-latest}`, with a `--no-bundle` variant pinned to `lts/*` on ubuntu, and **PR-time selective execution** (Node 24 ubuntu+windows, Node 16 macos). Turborepo: `{ubuntu-latest, macos-latest}` × Node `{18, 20, 22, 24}` = 8 combinations. Node's `test-linux.yml`: `{ubuntu-24.04, ubuntu-24.04-arm}`. Deno's matrix runs across `macos-15-intel`, `macos-14` (arm), `ubuntu-24.04`, plus Windows, with debug+release builds and **test sharding** (integration ×2, node-compat ×3, specs ×2).

7. **Security posture** — SHA-pinning is uneven across the corpus. Node pins everything: e.g. `actions/checkout@de0fac2e… # v6.0.2`, `step-security/harden-runner@8d3c67de… # v2.19.0` (in `scorecard.yml`, audit-mode egress). TypeScript pins. Turborepo pins. Deno pins. **Changesets does *not*** — its `publish.yml` uses bare `actions/checkout@v4`. **OIDC for npm** is the marquee pattern: changesets' `publish.yml` declares `permissions: id-token: write` + `contents: write` and relies on **npm trusted publishing (no `NPM_TOKEN`)**. Turborepo's `turborepo-release.yml` declares `id-token: write` and sets `NPM_CONFIG_PROVENANCE: "true"` — the explicit env-var spelling rather than `--provenance` flag. Counter-example: TypeScript's `nightly.yaml` uses legacy `NODE_AUTH_TOKEN` with `permissions: contents: read` only — no OIDC, no provenance — for `npm publish --tag next`. Per npm docs, provenance requires npm ≥ 9.5.0, a public `repository` field, GitHub-hosted runner, and either `--provenance` or trusted publishing.

8. **Observability** — TypeScript's `ci.yml` uploads to Codecov via `codecov/codecov-action@57e3a136… # v6.0.0`; changesets uses Codecov. TypeScript writes coverage on a self-hosted Microsoft 1ES pool. Node uploads SARIF to GitHub code-scanning via `github/codeql-action/upload-sarif@e46ed2cb…`. Turbo dashboards exist as a product but the turborepo repo itself disables them in self-CI.

9. **Scheduled-cron sweeps** — TypeScript runs `nightly.yaml` at `0 7 * * *` and `twoslash-repros.yaml` at `0 8 * * *` (auto-bisect of issue repros — an unusual pattern). Node runs `daily.yml`, `daily-wpt-fyi.yml`, `stale.yml`, `find-inactive-collaborators.yml`, `find-inactive-tsc.yml`, `update-openssl.yml`, `update-v8.yml`, `update-wpt.yml`, `timezone-update.yml` — i.e. dependency syncs are scheduled workflows, **not Renovate/Dependabot bots**. Node's `scorecard.yml` runs Mondays 21:16 UTC.

10. **Tool-binary install** — Multiple patterns: native (`actions/setup-node`), language-runtime composite (`oven-sh/setup-bun@0c5077e5… # v2`, `denoland/setup-deno@667a34cd…`), build-tool (`Mozilla-Actions/sccache-action@9e7fa8a…`), Rust toolchain via `dsherret/rust-toolchain-file@3551321a…` (deno) which reads `rust-toolchain.toml`. TypeScript invokes `npx dprint check` and `npx hereby ...` — `npx`-on-demand rather than separate setup steps.

11. **Test layers** — TypeScript runs unit + integration + browser + types as separate `npx hereby` invocations. Changesets runs `yarn jest --ci --runInBand --coverage` plus `yarn types:check`, `yarn lint`, `yarn format`. Deno shards integration tests ×2 and node-compat tests ×3 and specs ×2. Playwright browser binaries are cached. **Type-check is consistently a separate job/step from unit tests**, gating CI alongside lint.

12. **Quality gates** — TypeScript: `npm run lint` + `npx dprint check` + `npm run knip` (unused-export check) + `npx hereby build-src` (tsc) — all gating in `ci.yml`'s `ci-ok` job. Changesets: `yarn lint` + `yarn format` + `yarn types:check` — gating. Turborepo: separate `lint.yml` + `lint-pr-title.yml` workflows. **The "advisory" pattern (continue-on-error or report-only) was not observed in the surveyed gates** — JS/TS leans heavily on hard gating.

**Patterns to flag**:

- **npm provenance + OIDC trusted publishing** is the single highest-signal pattern — eliminates `NPM_TOKEN` entirely (changesets `publish.yml`) or attaches cryptographic attestations (turborepo's `NPM_CONFIG_PROVENANCE: "true"`). Direct analog for Swift would be sigstore/cosign attestations on tagged commits.
- **Changesets as a release-bookkeeping action** — single workflow toggles between "open Version Packages PR" and "publish" based on changeset presence. No direct Swift analog; closest is hand-rolled tag workflows.
- **Turbo remote cache as a class of pattern** — content-addressed remote build cache keyed on input graph. Even turborepo dogfoods only the local half (`TURBO_CACHE: local:rw`).
- **Generated workflows from a typed source** — Deno's `ci.ts` → `ci.generated.yml` pattern eliminates YAML drift across 11 sibling workflows.
- **Selective matrix expansion by trigger** — TypeScript's PR-time matrix is a 3-cell subset of the 21-cell push-to-main matrix. Cost control without losing coverage on protected branches.

**Patterns deliberately absent**:

- **No reusable workflows in the swiftlang/github-workflows sense.** JS/TS reuse via composite actions instead. The two-tier "consumer → universal reusable" pattern is essentially Swift-specific in this corpus.
- **No version-matrix in the language sense.** TypeScript-the-compiler has no "TypeScript version" matrix axis — it *is* the version.
- **No spine/canary discipline.** No "downstream consumer rebuilds on upstream merge" pattern observed.
- **No layered package-tier organization.** Even turborepo's monorepo treats packages as a flat workspace graph filtered by `--filter={./packages/*}`.

---

### §1.5 Multi-language exemplar projects

Survey of four large multi-language / large-OSS projects: hashicorp/terraform (+ terraform-provider-aws), llvm/llvm-project, bazelbuild/bazel, apache/arrow.

1. **Repo topology** — Terraform CLI lives in `hashicorp/terraform/`; the provider ecosystem is hundreds of independent repos under `hashicorp/terraform-provider-*`, each with its own `.github/workflows/` tree — terraform-provider-aws alone ships ~40 workflow files. LLVM is a single monorepo with ~50 workflow files in `llvm/llvm-project/.github/workflows/` covering libc, libcxx, MLIR, SPIR-V, SYCL, HLSL as sub-projects. Bazel is a Java/Starlark monorepo whose `.github/workflows/` holds only 9 lightweight files — heavy CI is offloaded to `bazelbuild/continuous-integration` (BuildKite). Arrow is a single `apache/arrow/` repo with 27 workflow files **partitioned by language**: `cpp.yml`, `python.yml`, `r.yml`, `ruby.yml`, `matlab.yml`, plus `integration.yml` for cross-language conformance.

2. **Reusable workflows** — Terraform CLI uses `workflow_call` for the build pipeline: `build.yml` calls `./.github/workflows/build-terraform-cli.yml` with parameters `goarch, goos, go-version, package-name, product-version, ld-flags, cgo-enabled, runson`. LLVM extends `workflow_call` further: `release-tasks.yml` invokes `./.github/workflows/release-binaries-all.yml`; helper workflows `./.github/workflows/get-llvm-version`, `./require-release-manager`, `./upload-release-artifact` are reused across release jobs. **Arrow has no `workflow_call` reuse** — language workflows are independent files duplicating Docker/ccache scaffolding. Bazel has no `workflow_call` either; reuse vector is the external `bazelbuild/continuous-integration` action repo.

3. **Composite actions** — LLVM ships local composite actions in `.github/actions/` (`build-container/`, `push-container/`) consumed by `build-ci-container.yml`. Terraform CLI uses `./.github/actions/go-version` to centralize Go-version selection across workflows. Arrow uses third-party composites (`r-lib/actions/setup-r@v2`, `msys2/setup-msys2@v2`, `ruby/setup-ruby@v1`) rather than authoring its own.

4. **Caching** — This is where the projects diverge most. **Bazel's signature pattern is remote action cache + CAS over HTTP/1.1** with action-hash → action-result keying and content-addressable output blobs at `/ac/` and `/cas/` paths; backends include `bazel-remote`, BuildBuddy, BuildBarn, NativeLink. LLVM premerge uses **sccache** via a self-hosted server with logs uploaded as artifacts; macOS jobs use `hendrikmuhs/ccache-action@33522472… # v1.2.22` with `max-size: 2000M`. Arrow uses three layers: (a) Docker-volume cache `actions/cache@v5` keyed on `${{ matrix.image }}-${{ hashFiles('cpp/**') }}`, (b) ccache for macOS/Windows, (c) cache restore-keys for fallback hits. Terraform caches only Go modules via `cache-dependency-path: go.sum` plus a hand-rolled protobuf-tools cache.

5. **Cross-repo orchestration** — No project replicates a centralized orchestrator. **Terraform's "fan-out": each provider repo has its own CI; HashiCorp publishes shared *actions*** (`hashicorp/setup-terraform`, `hashicorp/actions-go-build`, `hashicorp/actions-packaging-linux`, `hashicorp/actions-set-product-version`) that providers consume independently — the org-level reuse is action-level, not workflow-level. There is no public "provider-template" workflow repo; convergence comes from the shared action surface and Go module conventions. Bazel offloads heavy CI cross-repo to `bazelbuild/continuous-integration`. LLVM and Arrow are single-repo and have no cross-repo orchestration concern.

6. **Matrix shape** — Largest matrices observed: LLVM `libcxx-build-and-test.yaml` declares Stage 1 (5×2) + Stage 2 (8 × multiple compilers: clang-23/22/21, gcc-15) + **Stage 3 (27 configs all clang-23) + macOS (5 on macos-26) + Windows (10 MSVC/MinGW variants), spanning C++03–C++26, asan/tsan/ubsan/msan, generic-no-{exceptions,filesystem,modules}; Stage 3 sets `fail-fast: false`**. Arrow `cpp.yml`: Ubuntu 22.04/24.04 × {AMD64, ARM64} × Clang18 + macOS 14/15 × {ARM64, AMD64} + Windows 2022 × {MSVC, MinGW64, Clang64}. Terraform `build.yml` uses 15-element `include:` matrix across {freebsd, linux, openbsd, solaris, windows, darwin} × {386, amd64, arm, arm64}. Provider-aws shards Go tests via `matrix: { shard: [0,1,2,3], total-shards: [4] }`.

7. **Security posture** — LLVM and Bazel pin to **40-char commit SHAs with version comments**: `actions/checkout@de0fac2e… # v6.0.2`, `tj-actions/changed-files@9426d409… # v47.0.6`, `step-security/harden-runner@fe104658… # v2.16.1`. Terraform CLI also pins to SHAs. **Arrow pins to major-version tags only** (`actions/checkout@v6`, `actions/cache@v5`) — looser supply-chain posture. HashiCorp signing uses `hashicorp/actions-packaging-linux` to generate signed `.deb`/`.rpm`. Bazel uses `step-security/harden-runner` for runtime egress lockdown.

8. **Observability** — No GH-Actions-internal dashboards. Bazel's BuildBarn/BuildBuddy ecosystem provides remote-execution dashboards out-of-band. LLVM has a dedicated `check-ci.yml` that runs `pytest` against `.ci/` scripts plus a `metrics-container` build path indicating an internal metrics pipeline. Terraform-provider-aws has `firewatch.yml` and `report_ci.yml` for CI status monitoring. Arrow uses `report_ci.yml` similarly. Scorecard SARIF uploads to GitHub code scanning give all four supply-chain visibility.

9. **Scheduled-cron sweeps** — LLVM `libcxx-build-and-test.yaml` runs nightly: `cron: '0 8 * * *'`; LLVM `scorecard.yml` runs daily at `'38 20 * * *'`. Bazel `scorecard.yml` runs weekly. Arrow `r_nightly.yml` runs `cron: '0 14 * * *'` to mirror Crossbow nightly binaries to nightlies.apache.org. Terraform CLI `checks.yml`/`build.yml` have **no scheduled triggers** — purely event-driven.

10. **Tool-binary install** — **Bazelisk pattern**: a small launcher (`bazelisk`) selects the Bazel binary version per-repo via `.bazelversion` — analogous to rustup/`asdf`. LLVM avoids in-workflow toolchain install by **baking compilers into containers** (`image: 'ghcr.io/llvm/ci-ubuntu-24.04-format'`). Arrow uses imperative install scripts (`ci/scripts/install_minio.sh latest ${ARROW_HOME}`, `brew bundle --file=cpp/Brewfile`). Terraform uses `actions/setup-go@<sha>` with `go-version-file: go.mod`.

11. **Test layers** — **LLVM's three-stage layering is the most articulated**: Stage 1 fast smoke (5×2 fail-fast), Stage 2 broad (multi-compiler), Stage 3 wide (`fail-fast: false`, 27 configs accepting flake noise). Arrow layers `_extra` workflows (`cpp_extra.yml`, `r_extra.yml`, `cuda_extra.yml`) for less-common configs separated from the hot-path `cpp.yml`/`r.yml`/`python.yml`; **`integration.yml` is the cross-language conformance gate** via `ARCHERY_INTEGRATION_WITH_{DOTNET,GO,JAVA,JS,NANOARROW,RUST}=1` env flags. Terraform-provider-aws shards 4-way for Go tests.

12. **Quality gates** — LLVM `pr-code-format.yml` runs `python ./llvm/utils/git/code-format-helper.py` (clang-format wrapper) inside `ghcr.io/llvm/ci-ubuntu-24.04-format` container. Arrow `dev.yml` runs `pre-commit run --all-files --color=always --show-diff-on-failure` covering "Lint C++, Python, R, Docker, RAT" with **RAT (Apache Release Audit Tool) integrated through pre-commit**. Terraform-provider-aws layers six distinct lint workflows. Bazel uses `buildifier` (Starlark formatter) externally. All gates appear gating; LLVM Stage 3's `fail-fast: false` is the closest to a soft-advisory pattern.

**Patterns to flag**:

- **Bazel remote action+CAS cache (HTTP/1.1, `/ac/` + `/cas/`).** A class of caching unlike `actions/cache@v5`: keyed on action hash not file hash, content-addressable not key-addressable, shareable across machines/orgs. Backends: `bazel-remote`, BuildBuddy, BuildBarn, NativeLink.
- **HashiCorp's action-level (not workflow-level) cross-repo reuse.** No "provider template workflow" exists; convergence is via published actions consumed by ~thousands of provider repos. Composable-action surface beats centralized-workflow superrepo when consumer count is large.
- **LLVM's three-stage matrix (fast → broad → wide-noisy with `fail-fast: false`).** Acknowledges that wide matrices have flake floors and structures around it.
- **Arrow's `_extra` split (`cpp_extra.yml`, `r_extra.yml`).** Hot-path vs cold-path workflow files keep PR latency low while preserving wide coverage in scheduled/extra workflows.
- **Tool-binary install via container image (LLVM) vs imperative scripts (Arrow) vs actions (Terraform).** Three distinct strategies with different cache/security/maintenance trade-offs.

**Patterns deliberately absent**:

- **Workflow-level superrepo reuse for providers.** Terraform consciously avoids it; provider repos don't `uses: hashicorp/foo/.github/workflows/X.yml@v1`. Tag-coordinating a workflow across thousands of providers exceeds the duplication cost.
- **Foundation-style umbrella workflow.** Bazel with 9 GH-Actions files (heavy CI elsewhere) is a near-zero example.
- **Universal SHA pinning across all four projects.** Arrow stops at major-version tags; LLVM/Bazel/Terraform pin to 40-char SHAs.
- **Cross-language conformance via reusable workflows.** Arrow's cross-language integration is a single non-reusable `integration.yml` keyed on env flags.

---

### §1.6 Apple's Swift reference (`swiftlang/github-workflows`)

Per `ci-cache-strategy-branch-pinned-dependencies.md` v1.1.0 (already in this corpus), Apple's `swiftlang/github-workflows` repository hosts the canonical published Swift CI template. Key patterns relevant to this survey, summarized for completeness:

- **`swift_package_test.yml`** — 995-line reusable workflow for Swift package CI. Zero `actions/cache` uses across the file. The no-cache stance is the empirical baseline that motivated [CI-040].
- **Matrix shape** — covers the swift.org-supported toolchain × OS × arch grid; macOS via runner image, Linux via container, Windows via setup-swift.
- **Reuse pattern** — single reusable workflow consumed by per-package callers; no composite actions in the repo.
- **No tool-binary cache, no SHA pinning of third-party actions, no OIDC.** The reference sets a minimal-policy floor; opinions like SHA-pinning are left to consumers.
- **Visibility** — the repo is public; consumers reference workflows via `swiftlang/github-workflows/.github/workflows/swift_package_test.yml@<ref>`. swift-institute deliberately forks the architecture (own three-tier reusable chain) rather than consuming Apple's directly because it embeds layer-specific invariants Apple's template doesn't.

The swift-institute corpus aligns with Apple's no-cache-`.build/` stance (per [CI-040]), diverges by adopting ecosystem-specific layer invariants (per [CI-001]–[CI-004]), and now extends Apple's posture with tool-binary caching (per [CI-044], post-2026-05-05) and composite-action constraints (per [CI-070], post-2026-05-05).

---

## Part II — Cross-Ecosystem Synthesis

### Universal patterns (≥4 of 6 ecosystems)

These patterns appear in 4+ surveyed ecosystems with consistent implementation:

| Pattern | Ecosystems | Swift Institute status |
|---|---|---|
| **`setup-<lang>` action as entry point** | Rust (rustup), Go (`actions/setup-go`), Python (`actions/setup-python`), JS (`actions/setup-node`/`setup-bun`/`setup-deno`), multi-lang (varied) | Partial — `SwiftyLab/setup-swift@v1` for Windows; macOS/Linux use Xcode-select / container image |
| **Composite actions for setup recipes** | Go (`kubernetes-sigs/release-actions`), Python (`pypa/cibuildwheel`, in-repo composites), JS (turborepo's 8 composites), multi-lang (LLVM's container builders, Terraform's `go-version`) | **Adopted** post-2026-05-05 — 5 composites: `configure-private-repos`, `install-swift-sdk`, `enumerate-org-public-repos`, `upsert-tracking-issue`, `read-orgs` |
| **Scheduled-cron sweeps for dependency updates / drift** | Rust (cargo update, ghcr mirror), Go (testing nightly, scorecard), Python (Dependabot grouping+cooldown, pre-commit.ci autoupdate), JS (Node's update-* workflows), multi-lang (Arrow nightly, LLVM scorecard) | **Adopted** — 8 cron orchestrators (sync-metadata-nightly + 7 weekly) |
| **`step-security/harden-runner` for egress lockdown** | Go (`kubernetes/release` universal), JS (Node `scorecard.yml`), multi-lang (Bazel, LLVM `pr-code-format.yml`) | **Absent** |
| **OSSF Scorecard** | Go (k8s/release), Python (numpy), JS (Node), multi-lang (Bazel, LLVM) | **Absent** |
| **Major-version tag pinning at minimum, with SHA pinning aspirational** | All 6 surveyed ecosystems mix the two; consensus is "SHA-pin sensitive workflows; major-tag the rest" | Major-tag uniform; SHA pinning declined per principal direction (upgrade ergonomics) |

### Common patterns (2–3 ecosystems)

| Pattern | Ecosystems | Swift Institute status |
|---|---|---|
| **OIDC keyless publishing** | Python (PyPI Trusted Publishers), JS (npm provenance via `id-token: write`), Go (sigstore/cosign in k8s/release) | **Absent** — no SwiftPM Trusted Publisher equivalent exists yet, but git-tag attestation via cosign is a feasible analog |
| **External CI for primary tests** | Go (LUCI for golang/go, Prow for k8s), some Bazel offload to BuildKite | Not applicable at our scale |
| **External dashboards (TestGrid-style)** | Go (TestGrid), Bazel (BuildBuddy / BuildBarn) | **Absent** — relies on GH Actions UI + tracking issues |
| **`workflow_call` reusable workflows for orchestration** | Python (CPython `reusable-<platform>.yml`), multi-lang (LLVM `release-binaries-all.yml`, Terraform `build-terraform-cli.yml`), Apple's reference (`swift_package_test.yml`) | **Adopted** — three-tier reusable chain per [CI-001] |
| **Conclusion-aggregator job pattern** | Rust (cargo `conclusion`, rust-analyzer `conclusion`), Python (CPython `check_source` synthesis) | **Absent** |
| **Hot-path / cold-path workflow split** | Multi-lang (Arrow `_extra.yml`, LLVM 3-stage) | Partial — advisory linters split into separate reusables called from universal swift-ci.yml; not in the workflow-file split sense |
| **Sharded testing for matrix scale** | JS (Deno integration ×2 / node-compat ×3 / specs ×2), Multi-lang (Provider AWS `shard: [0,1,2,3]`) | Not applicable at our scale |
| **Generated workflows from typed source** | JS (Deno's `ci.ts` → `ci.generated.yml`), Rust (`citool` reading `jobs.yml` for dynamic matrix) | **Absent** |
| **`go-version-file: go.mod` (single source of truth for toolchain)** | Go (kubernetes/release dominant), Python (`go-version-file` analog: `python-version-file`) | **Absent** — Swift toolchain pinned in workflow inputs, not derived from `Package.swift`'s `swift-tools-version:` |
| **Cross-workflow PR comment via `workflow_run`** | Rust (clippy `lintcheck_summary.yml`) | **Absent** |
| **DockerHub→ghcr.io mirror for rate-limit immunity** | Rust (`rust/ghcr.yml` daily mirror) | **Absent** — uses `swift:6.3` directly from DockerHub |
| **`deny-all` top-level permissions with per-job least-privilege** | Go (`kubernetes/release` universal), JS (Node), multi-lang (LLVM) | Partial — most jobs declare `permissions: contents: read`; not universally `permissions: {}` at workflow top |

### Idiosyncratic but high-signal patterns (1 ecosystem)

| Pattern | Origin | Swift Institute applicability |
|---|---|---|
| **Bazel remote action+CAS cache** | Bazel | High — but requires Bazel infrastructure; not directly applicable to SwiftPM build graph |
| **changesets-style release bookkeeping** | JS | Medium — would fit if swift-institute publishes coordinated multi-package version bumps |
| **pre-commit.ci hosted-service auto-update** | Python | High-signal — directly maps onto a hypothetical "swift-format-bump-bot" pattern |
| **Post-merge analysis with bors-parent diff** (`rust/post-merge.yml`) | Rust | Medium — fits if test-result aggregation across PRs is a future need |
| **TypeScript's auto-bisect of issue repros** (`twoslash-repros.yaml`) | JS/TS | Low — niche |
| **HashiCorp's action-level cross-repo reuse** (instead of workflow-level) | Multi-lang | Informative but not adoption — swift-institute's workflow-level reuse is correct for our scale |
| **LLVM's container-baked compiler image** (`ghcr.io/llvm/ci-ubuntu-24.04-format`) | Multi-lang | Medium — could replace swift:6.3 with a custom-baked image including pre-installed yq/jq/lychee |

### Convergent absences across multiple ecosystems

Patterns that **none of the 6 surveyed ecosystems use**, suggesting they're swift-institute-specific (or genuine universal absences):

| Pattern | Status |
|---|---|
| **Layered package-tier organization** ([CI-001]–[CI-004], five-layer architecture) | Swift-institute idiosyncratic — no surveyed ecosystem has this |
| **Maintainer-operated cross-repo cron orchestrator with idempotent tracking issues** | Swift-institute idiosyncratic — closest analog is pre-commit.ci (third-party hosted) |
| **Spine/canary discipline (downstream rebuild on upstream merge)** | Universal absence — even monorepos don't replay the full graph |
| **Public/private visibility gate** ([CI-032]) | Swift-institute idiosyncratic — no surveyed ecosystem uses GitHub Free-tier billing constraints to gate workflow execution |

---

## Part III — Application to Swift Institute

For each pattern surfaced in Part II that's absent or partial in our setup, applying [RES-021]'s contextualization step before classifying as a gap.

### High-value candidates (recommend cohort)

**1. `step-security/harden-runner` egress lockdown.**
- **What it does**: at job start, captures and optionally blocks all network egress; allowlist-mode requires explicit `allowed-endpoints:`.
- **Contextualization**: workflows would need `allowed-endpoints:` lists per-runner (apt mirrors, github.com, raw.githubusercontent.com, swift.org, lychee/yq/jq release URLs, npm if any). Our cron orchestrators already enumerate these dependencies.
- **Cost**: medium — requires per-workflow allowlist authoring + an audit phase to discover legitimate endpoints. Easy to deploy in `audit` mode first (logs egress without blocking).
- **Benefit**: high — closes the supply-chain gap that the SHA-pinning declination (Recommendation #5 from the prior exploration) leaves open. Universal across hardened OSS projects (Go k8s/release, JS Node, multi-lang Bazel + LLVM).
- **Verdict**: **PROCEED** as a candidate cohort. Audit-mode-first deployment is low-risk.

**2. Conclusion-aggregator job ([Rust pattern]).**
- **What it does**: a final job with `needs: [all-other-jobs]` set as the single required status check on branch protection.
- **Contextualization**: swift-institute's universal `swift-ci.yml` has 6 always-on jobs (4 matrix + format + lint) + 8 advisory linters. Branch protection currently requires each job individually. A `conclusion` aggregator collapses to one required check.
- **Cost**: low — single job addition + branch-protection update.
- **Benefit**: medium-high — decouples branch-protection config from workflow refactors. When [CI-070] composites or new advisory linters land, no per-repo branch-protection updates needed.
- **Verdict**: **PROCEED** as a candidate cohort.

**3. OIDC keyless attestation for tagged releases (sigstore/cosign).**
- **What it does**: at tag time, sign the tagged commit with a sigstore-issued certificate via OIDC; verifiable via `cosign verify`.
- **Contextualization**: swift-institute has no release automation today (per the prior exploration). Tags are manual `git tag`. Adding cosign attestation requires (a) a release workflow, (b) `permissions: id-token: write`, (c) `sigstore/cosign-installer` in a release job. The signing target would be the git tag itself (commit attestation) rather than published artifacts (no SwiftPM-publishable artifacts exist).
- **Cost**: medium — release workflow design + cosign integration. ~1-2 cohorts.
- **Benefit**: medium-high — establishes signing infrastructure now, before SwiftPM Trusted Publishers (or equivalent) lands. Direct OIDC analog to npm provenance / PyPI Trusted Publishers.
- **Verdict**: **PROCEED** as a candidate cohort, sequenced after release automation gets attention.

### Medium-value candidates (consider but not urgent)

**4. Hot-path / cold-path workflow split** (Arrow `_extra.yml` pattern).
- **What it does**: split the matrix into `swift-ci.yml` (matrix + format + lint, fast) and `swift-ci-extra.yml` (apple-simulator, embedded-wasm-sdk, android-build, static-linux-musl-build, advisory linters), with `extra` running on schedule or PR-time only.
- **Contextualization**: our universal `swift-ci.yml` already runs the matrix + format + lint hot-path. Layer wrapper adds embedded + 3 SDK-install jobs + apple-simulator. PR latency is dominated by the slowest job, not aggregate runtime — but cold-path jobs *are* `continue-on-error: true` already, so they don't gate PR merge. The split adds maintenance surface without changing the gating contract.
- **Verdict**: **OBSERVE** — minimal benefit given existing `continue-on-error` gating shape.

**5. `swift-tools-version:`-derived toolchain pinning** (Go's `go-version-file: go.mod` analog).
- **What it does**: derive the CI toolchain version from `Package.swift`'s `// swift-tools-version: X.Y` line.
- **Contextualization**: `swift-tools-version:` declares the *minimum* tools version the package requires, not the specific version it targets. Multiple consumers across the ecosystem will declare different minimum versions; the CI matrix is currently uniform across the entire ecosystem (Swift 6.3 + 6.4-dev nightly). Deriving from `swift-tools-version:` would either ignore it (status quo) or splinter the matrix per-package.
- **Verdict**: **OBSERVE** — analogy holds for Go because `go.mod` declares the *exact* version, not minimum. The Swift analog doesn't fit cleanly.

**6. DockerHub→ghcr.io daily mirror** (Rust pattern).
- **What it does**: cron job pulls `swift:6.3`, `swiftlang/swift:nightly-main-jammy`, etc. from DockerHub and pushes to ghcr.io; CI consumes from ghcr.io.
- **Contextualization**: DockerHub has a rate limit of 100 anonymous pulls / 6h per IP. GitHub-hosted runners share egress IPs. Our cron orchestrators (7 weekly + 1 daily, each pulling `swift:6.3` for some jobs) approach but don't yet exceed this. A mirror is forward-protection.
- **Cost**: low — one cron workflow + ghcr.io target setup.
- **Benefit**: low today, medium when cron sweep count grows.
- **Verdict**: **DEFER** unless we see DockerHub rate-limit failures.

### Low-value candidates (not adopting)

**7. Generated workflows from typed source** (Deno's `ci.ts` → `ci.generated.yml`).
- **What it does**: TypeScript / similar generates YAML workflow files; YAML is a build artifact.
- **Contextualization**: our workflow file count is ~25, well below the threshold where Deno (with 11 generated files) found this useful. The `cron-audit-base.yml` parameterization already handles much of the would-be duplication.
- **Verdict**: **DEFER** until workflow count exceeds ~50 with high duplication.

**8. External CI / external dashboards (Prow + TestGrid).**
- **What it does**: shift primary CI off GH Actions to a self-hosted control plane.
- **Contextualization**: appropriate at Kubernetes-scale (hundreds of repos, thousands of test runs/day). Swift-institute is not at this scale and has no signs of approaching it.
- **Verdict**: **DEFER** indefinitely.

### Genuine universal absences (do not adopt)

Three patterns from the prior exploration's #3 (cross-org metadata drift / org-policies-sync) and #6 (cost observability) align with **convergent absences** in Part II — no surveyed ecosystem maintains an org-policies sync workflow analogous to what was proposed. The contextualization step explains why: most ecosystems (Go's k8s, Python's PyPA, JS's pnpm-monorepo) either DON'T have many small repos (monorepo-like) or coordinate via spec/PEP rather than tooling. Swift-institute's three-tier-org structure (top-level org / org-of-orgs / leaf orgs) is genuinely without prior art. The absence is therefore **swift-institute-specific design decision territory**, not a gap to close from prior art.

---

## Outcome

**Status**: RECOMMENDATION

The cross-ecosystem survey identifies **3 high-value candidate cohorts** absent from swift-institute's current CI/CD setup:

1. **`step-security/harden-runner` egress lockdown** (universal pattern; closes the supply-chain gap left by SHA-pinning declination).
2. **Conclusion-aggregator job** (Rust pattern; decouples branch protection from workflow refactors).
3. **OIDC keyless attestation for tagged releases** (cosign / sigstore; establishes signing infrastructure ahead of SwiftPM Trusted Publishers).

Three additional candidates are **DEFERRED** (hot-path/cold-path split, swift-tools-version derivation, DockerHub→ghcr.io mirror) because the contextualization step shows the analog doesn't fit cleanly (toolchain derivation), the existing shape already covers the use case (continue-on-error gating substitutes for hot/cold split), or the trigger condition isn't yet present (DockerHub rate-limit incidents).

Three additional candidates were **declined** (generated workflows from typed source, external CI, external dashboards) — appropriate at scales swift-institute hasn't reached.

The **three high-value candidates compose well**: harden-runner can deploy in audit mode immediately; conclusion-aggregator is a single-commit refactor on the universal `swift-ci.yml`; cosign attestation extends release tooling that doesn't yet exist (release automation can be designed with cosign in scope from the start).

The survey's most informative non-adoption finding: swift-institute's **three-tier reusable workflow chain + maintainer-operated cross-repo cron orchestrators with idempotent tracking issues** have no prior art across the 6 surveyed ecosystems. This is a swift-institute-original design pattern — Python's CPython has the closest reusable-workflow shape but no cross-repo dimension; Go's Prow has the cross-repo orchestration but at a fundamentally different (external-CI) layer. The implication: this design isn't validated by external precedent, but it's also not contraindicated by a known-better pattern. Continued investment in the corpus is supported.

## References

Primary sources cited inline by §. All workflow file references are to `.github/workflows/<file>` paths within the cited repository on the default branch as of 2026-05-05.

External documentation:
- [PyPI Trusted Publishers](https://docs.pypi.org/trusted-publishers/)
- [npm provenance](https://docs.npmjs.com/generating-provenance-statements)
- [Bazel remote caching](https://bazel.build/remote/caching)
- [Prow overview](https://docs.prow.k8s.io/docs/overview/)
- [Go DashboardBuilders / LUCI migration](https://go.dev/wiki/DashboardBuilders)
- [TestGrid](https://testgrid.k8s.io/)
- [Apple's swift-package-test reusable workflow (analyzed in prior corpus doc)](https://github.com/swiftlang/github-workflows)

Internal cross-references:
- `swift-institute/Research/centralized-swift-ci-and-spine-gate.md`
- `swift-institute/Research/ci-centralization-strategy.md`
- `swift-institute/Research/ci-cache-strategy-branch-pinned-dependencies.md`
- `swift-institute/Research/github-metadata-harmonization.md`
- `swift-institute/Skills/ci-cd-workflows/SKILL.md` ([CI-001]–[CI-070])
- Reflection `swift-institute/Research/Reflections/2026-05-05-ci-audit-and-pm-cohort-rollout.md`
