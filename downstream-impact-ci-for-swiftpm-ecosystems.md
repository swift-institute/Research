# Downstream-Impact CI for SwiftPM Ecosystems

<!--
---
version: 1.0.0
last_updated: 2026-05-14
status: RECOMMENDATION
research_tier: 2
applies_to: [primitives, standards, foundations, ecosystem-wide]
normative: false
---
-->

## Context

### Trigger

Direct user question (2026-05-14): swift-primitives is modularized into ~141 sibling repos across 9 tiers; changes at leaf packages propagate up. Today there's no in-CI signal for "what breaks downstream when I change this package." The user proposed a CI step that (a) discovers swift-primitives packages depending on the repo under change, (b) runs a quick debug build of each. Question: is such a thing already available off-the-shelf, and if not, what shape should we build?

### Scope

Ecosystem-wide per [RES-002a]. The CI mechanism applies across all five layers (swift-primitives, swift-standards, swift-foundations, components, applications) and the spec-authority sub-orgs. This doc focuses on the *mechanism* — discovery + override + build — not on per-package policy decisions (which packages to gate, which to advise on).

### Prior research (cite-and-extend per [HANDOFF-013])

- [`ci-cd-prior-art-and-pattern-survey.md`](ci-cd-prior-art-and-pattern-survey.md) v1.0.0 (2026-05-05) — surveyed CI/CD across 6 non-Swift ecosystems and classified "spine/canary discipline (downstream rebuild on upstream merge)" as a **universal absence**, citing that "even monorepos don't replay the full graph" (line 406). **This doc partially refutes that conclusion**: Rust's `crater`, Apple's `swift-source-compat-suite`, Haskell's Stackage, and GHC's `head.hackage` all do replay the graph — but at toolchain-level (compiler→ecosystem), not library-level (one package→its consumers). The prior survey's surveyed repos didn't include these (crater is at `rust-lang/crater`, not the four `rust-lang/{rust,cargo,clippy,rust-analyzer}` repos it surveyed). The library-level claim — "no surveyed ecosystem rebuilds downstream consumers from one library PR" — does hold modulo small hand-curated exceptions (tokio's `test-hyper`+`test-quinn`, Vapor's provider matrix).
- [`ci-centralization-strategy.md`](ci-centralization-strategy.md) v1.1.0 + [`ci-cd-cross-ecosystem-reuse.md`](ci-cd-cross-ecosystem-reuse.md) v1.1.1 — establish the three-tier reusable chain (per-package → layer wrapper → universal) and the GitHub Actions `workflow_call` 4-level depth limit as a hard constraint on new reusables. Any downstream-impact reusable must fit within this limit.
- `swift-institute/.github/.github/workflows/lint-api-breakage.yml` — already does **source-level** API-breakage detection via `swift package diagnose-api-breaking-changes <PR-base-SHA>`, comparing the package against its own PR-base commit. **Does NOT build downstream consumers**; that's the gap this doc addresses.

---

## Question

For a 9-tier, ~141-package SwiftPM ecosystem under one organization, the question decomposes:

1. **Off-the-shelf availability**: is there a packaged GitHub Action, SwiftPM-native feature, or reusable workflow that implements "build my downstream consumers on PR"?
2. **Architectural model**: what's the right scope (direct dependents only / full transitive closure) and trigger model (per-PR / nightly / on-merge)?
3. **Substitution mechanism**: how does a downstream consumer's build pick up the upstream PR's source without modifying the downstream's `Package.swift`?
4. **Discovery mechanism**: how does CI know which packages are reverse-dependents of the repo under change?
5. **Failure semantics**: hard fail / advisory? Class A/B/C/D classification like `lint-api-breakage.yml`?

---

## Analysis

### Q1 — Off-the-shelf availability

**Answer: No packaged solution.** Three classes of prior art exist but none drops in:

| Tool | Layer | Scale | Why it doesn't drop in |
|---|---|---|---|
| `rust-lang/crater` | Compiler→ecosystem | "Every crate on crates.io" (~150k crates, 3–6 day wall clock) | Toolchain-tier; server-queued HTTP agent fleet with Docker sandbox. Massively over-engineered for 141 packages in one org. [Verified 2026-05-14: `docs/agent-http-api.md` + `config.toml:25-30`] |
| `swiftlang/swift-source-compat-suite` | Compiler→ecosystem | 147 opted-in projects | Python+Jenkins, Darwin-only orchestrator (`run`: `if platform.system() != 'Darwin': raise UnsupportedPlatform`). Tests Swift compiler against the world, not library against consumers. Heavyweight integration. [Verified 2026-05-14: `runner.py` + `projects/*.json` directory listing] |
| `commercialhaskell/stackage` | Library curation | Curated LTS snapshot (~3000 packages) | Builds the snapshot atomically; failure = snapshot doesn't ship. Daily/weekly cron, not per-PR. [Verified 2026-05-14 via subagent reading `CURATORS.md`] |
| GitHub Marketplace | n/a | n/a | No action billed as "reverse-dependency build" or "downstream impact" surfaces under those keywords. |

**The library-tier prior art is hand-curated matrix jobs** in the upstream's own CI:

- **`tokio` (Rust)** — `.github/workflows/ci.yml:893-993` defines `test-hyper` + `test-quinn` jobs. Pattern: `git clone hyperium/hyper` → `git checkout $(git describe --abbrev=0 --tags)` (latest release tag, **not HEAD**; comment: "HEAD maybe contains breakage") → append `[patch.crates-io]` block substituting `tokio = { path = "../tokio" }` → `cargo test --features full`. Matrix: windows/ubuntu/macos × {hyper, quinn} = 2 consumers, hand-listed. [Verified 2026-05-14 via direct fetch of `tokio-rs/tokio` `master`.]
- **`vapor/vapor` (Swift)** — `.github/workflows/test.yml` job `test-providers` matrix over `provider: [vapor/jwt, vapor/fluent, vapor/leaf, vapor/queues, vapor/apns]`. Pattern: checkout vapor at `path: vapor` → checkout provider at `path: provider` → `swift package --package-path ./provider edit vapor --path ./vapor` → `swift test --package-path ./provider`. Hand-curated 5-caller list. [Verified 2026-05-14 via direct fetch of `vapor/vapor` `main`.]
- Hummingbird, swift-otel reportedly use the same Vapor pattern (subagent claim, not directly verified for this doc).
- **Counter-examples**: `serde`, `hyper`, `swift-syntax`, `swift-nio`, `pointfreeco/swift-snapshot-testing` do **not** have downstream-consumer jobs in their own CI; they rely on the toolchain-tier suite (crater / source-compat-suite) for that coverage. [Verified 2026-05-14 via subagent inspection of each repo's `.github/workflows/`.]

**Universal absence at scale**: outside crater + Stackage + head.hackage, no library ecosystem (Go, Python, JS, Java, Ruby, Elixir) systematically runs reverse-dep builds in upstream CI. Python's NumPy/SciPy explicitly invert the pattern via SPEC 4 — upstream publishes nightlies, downstream consumers run cron tests against them. [Verified 2026-05-14: `numpy.org/devdocs/dev/depending_on_numpy.html` + `scientific-python.org/specs/spec-0004/` via subagent.]

### Q2 — Architectural model (scope + trigger)

Four viable architectures emerge from the prior art:

| Architecture | Trigger | Scope per run | Cost | Latency | Coverage |
|---|---|---|---|---|---|
| (a) Per-PR matrix in upstream's CI (tokio + Vapor pattern) | Pull-request to upstream | Direct or 2-tier dependents | One matrix job × dependent count | Adds 1–5 min to PR latency | Catches direct-consumer breakage |
| (b) Per-PR matrix with full transitive closure | Pull-request to upstream | All transitive dependents | Linear in tier-depth × packages | Adds 5–30 min to PR latency | Catches everything |
| (c) Nightly cron full-ecosystem build (Stackage pattern) | Cron + on-tag | Full ecosystem | One sweep / 24h | None (out-of-band) | Catches everything but with up-to-1-day lag |
| (d) `repository_dispatch` fan-out (SPEC-4 inverted) | Upstream merge to main | Each downstream runs its own CI on receipt | Fanout overhead × dependent count | Bounded by slowest downstream CI | Distributes load |

For swift-primitives' 9-tier structure with the user's stated goal of "quick and easy overview of what breaks":

- **(a) is right for the default case**: scoped to direct dependents (tier+1), runs per-PR, catches the 80% of breakage. Bounded blast radius keeps PR latency tolerable. The user explicitly said "quick sanity debug build."
- **(c) is right for transitive coverage**: a nightly cron sweep against `main` catches the long tail without paying the cost per-PR.
- **(b) is gated behind a `full-impact` label** for cases where the author *does* want to see transitive breakage before merging (e.g., touching a tier-0 primitive with known-wide adoption).
- **(d) is rejected**: `repository_dispatch` requires PAT-with-`repo`-scope or App credential fan-out across ~141 repos, fires dispatched workflows on the default branch only, and decouples failure attribution from the upstream PR — the upstream author no longer sees "your PR broke X" in their own PR UI.

### Q3 — Substitution mechanism

Three SwiftPM-native substitution mechanisms exist; all verified:

| Mechanism | How it works | Suitability |
|---|---|---|
| `swift package config set-mirror --original <url> --mirror <url>` | Writes `~/.swiftpm/configuration/mirrors.json` or per-package config; SwiftPM substitutes URL at resolution time. | Works in CI; already used locally per `setup-mirrors.sh`. [Verified 2026-05-14: `PackageConfigSetMirror.md` in `swiftlang/swift-package-manager`] |
| **`swift package edit <name> --path <local>`** | Substitutes a dependency with a local checkout in the *consumer*'s SwiftPM state. The consumer's manifest is unchanged on disk. | **Canonical Swift pattern** (Vapor). Works without modifying downstream's `Package.swift`. Stateful (writes to `.swiftpm/`) but in CI the workspace is ephemeral. |
| `SWIFTCI_USE_LOCAL_DEPS=1` env var convention | Manifest branches on the env var: `.package(url: ...)` vs `.package(path: "../...")`. | Only works when the manifest cooperates. Used by `swiftlang/swift-package-manager` itself for sibling-checkout dev. Not applicable to arbitrary downstream consumers. [Verified 2026-05-14: `swift-package-manager/Package.swift`] |

**Recommendation: `swift package edit --path`**. It's the proven Swift pattern, requires zero changes to the downstream's manifest, and the workspace state lives only for the duration of the CI job. The existing `convert-to-local-paths.sh` (which rewrites manifests in-place) is **not the right primitive in CI** — it mutates the manifest, which conflicts with later steps and isn't reversible inside the run.

### Q4 — Discovery mechanism

For an in-org ecosystem, three discovery options:

| Option | Mechanism | Pros | Cons |
|---|---|---|---|
| (i) Dynamic via `gh` + grep | At job time: `gh repo list swift-primitives --json name` → clone each → grep `Package.swift` for the upstream URL | Always fresh; no manifest to maintain | ~141 clones per CI run; ~30–60s overhead even on cached runners |
| (ii) Cached manifest under `Scripts/dependency-graph.json` | Regenerated by `ecosystem-timeline.sh` (or similar) on cron + post-merge | Fast (single file read); auditable | Staleness window; regeneration trigger |
| (iii) GitHub Dependency Graph API | `GET /repos/{owner}/{repo}/dependency-graph/sbom` (forward) — but reverse is NOT exposed (`/dependents` REST endpoint returns 404) | Authoritative for forward graph | **No reverse-dep endpoint exists for SwiftPM** [Verified 2026-05-14 via subagent]; HTML-scrape only |

**Recommendation: (ii) cached manifest, regenerated on cron + on-merge to main**. The ~30–60s overhead of (i) is paid on every CI run across every repo — across 141 packages with daily commit volume that's hours/day of wasted compute. Staleness of (ii) is bounded by the regeneration cadence (recommend hourly cron + post-merge hook); the worst case is a new dependency edge added in the last hour that isn't yet in the manifest, which means "we miss one PR's downstream impact for one hour, then catch it on the next push" — acceptable.

The manifest schema:

```json
{
  "$schema": "https://swift-institute.org/schemas/dependency-graph-v1.json",
  "generatedAt": "2026-05-14T08:00:00Z",
  "edges": {
    "swift-buffer-primitives": {
      "directDependents": ["swift-array-primitives", "swift-storage-primitives", ...],
      "transitiveDependents": ["swift-array-primitives", "swift-storage-primitives", "swift-collection-primitives", ...]
    },
    ...
  }
}
```

Generation: scan every `Package.swift` in `swift-primitives/*/`, parse `dependencies: [.package(url: "https://github.com/swift-primitives/<name>.git", ...)]`, build the inverse adjacency map, compute transitive closure. The existing `detect-redundant-deps.sh` already does the forward scan; the inverse is one additional pass.

### Q5 — Failure semantics + classification

The existing `lint-api-breakage.yml` already establishes a four-class classification (A: own change / B: dep drift / C: toolchain / D: workflow). Extend the same shape:

| Class | Meaning | Action |
|---|---|---|
| A | Genuine downstream API break caused by this PR | Block merge (or gate via `advisory` input during pilot) |
| B | Downstream was already broken on `main` (baseline failure) | Surface separately; don't block PR |
| C | Toolchain / SwiftPM resolver issue | Triage on weekly tracking issue |
| D | CI infra issue (timeout, network) | Retry; if persistent, fix infra |

The **baseline-comparison discipline** (build the downstream first against `main` of the upstream, then against the PR head, and surface only the *delta*) is what separates an A-class signal from a B-class false alarm. Crater does this with two toolchains; we'd do it with two upstream SHAs.

### [RES-018] Premature Primitive check

A downstream-impact reusable workflow is a new CI *primitive*. Applying the rule:

1. **"Why not compose existing primitives?"** — `lint-api-breakage.yml` operates source-level only (swift-api-digester output), not by building consumers. The universal `swift-ci.yml` builds only the calling repo. No existing reusable composes into "build N downstream consumers with PR-head substitution." Composition would mean writing this reusable.
2. **"Is there a second consumer?"** — Two distinct consumers exist: (a) every per-package `ci.yml` (called from each layer wrapper or universal); (b) a cron orchestrator running nightly transitive sweeps. Plus a probable future third: the `release-readiness` pre-tag gate, which today has no automated downstream-impact check.

Both hurdles cleared. Not a premature primitive.

### 4-level workflow_call constraint

Per [`ci-cd-cross-ecosystem-reuse.md`](ci-cd-cross-ecosystem-reuse.md) v1.1.1, the GitHub Actions `workflow_call` chain is at the 4-level limit:

```
per-package ci.yml → layer wrapper → universal → advisory linter   (at limit)
```

A new `lint-downstream-impact.yml` would be invoked from the universal as a sibling to the existing 6 advisory linters — landing at the same level (3) as `lint-yaml`, `lint-api-breakage`, etc. **It does NOT add a chain level.** Constraint compatible.

---

## Outcome

**Status: RECOMMENDATION**

**Top-level answer to the user's question**: there is no off-the-shelf GitHub Action or SwiftPM-native feature that does this. The canonical Swift pattern is Vapor's hand-curated matrix using `swift package edit --path`; the canonical Rust analog is tokio's hand-curated matrix using `[patch.crates-io]`. Both scale to ~2–5 hand-listed consumers. Neither scales to 141 packages without automated discovery.

**Recommended shape** — a new advisory reusable `lint-downstream-impact.yml` invoked from the universal swift-ci.yml, with three components:

1. **A cached dependency-graph manifest** at `swift-institute/.github/.github/data/dependency-graph.json`, regenerated by a new cron + post-merge orchestrator. Schema as in Q4. One file, scanned by the new reusable.
2. **A matrix-job reusable** keyed on the manifest's `directDependents[currentRepo]`. For each dependent: checkout dependent at `./dependent`, checkout upstream PR at `./upstream`, run `swift package --package-path ./dependent edit <upstream-pkg-name> --path ./upstream`, run `swift build` (not test — keeps it "quick sanity build" per the user's framing). Default fan-out: direct dependents only (tier+1).
3. **Class-A/B/C/D classifier** mirroring `lint-api-breakage.yml`'s structure. Baseline build against upstream's `main` first; only delta-failures count as class A. Pilot in advisory mode for 4 weeks; flip to gating after observing the A:B:C:D ratio.

Two opt-in extensions:

- **`full-impact` label** on a PR runs the full transitive closure (Q2 option b). For tier-0-primitive changes.
- **Nightly cron sweep** runs the full ecosystem transitively against the previous day's `main` of every package (Q2 option c). Catches the long tail.

**Why not crater-class infrastructure**: 141 packages on the LAN is two orders of magnitude smaller than crater's corpus. The HTTP-agent + queue model is over-engineered. GitHub Actions matrix jobs are the right tool.

**Why not the Vapor pattern as-is**: Vapor's 5-caller hand-curated matrix doesn't scale to ~141 packages with churning dependency edges. The dynamic-discovery mechanism (Q4 manifest) is what bridges Vapor's mechanism to swift-primitives' scale.

**Why not source-compat-suite**: Python + Jenkins + Darwin-only orchestrator. Designed for compiler→world, not library→consumer. Adapting it would mean rewriting the orchestrator in GitHub Actions YAML anyway — which is what this proposal does, without inheriting Jenkins+Python.

## Open questions

1. **Manifest regeneration triggers**: cron-only, on-merge, or both? Trade-off: on-merge gives freshness within seconds (catches a PR that adds a new dep edge before the next PR builds against it); cron alone has up-to-1-hour staleness. Recommend both: cron hourly + a `repository_dispatch` to `swift-institute/.github` on each repo's merge-to-main, debounced 30s.

2. **Layer-crossing dependents**: a tier-3 swift-foundation package depends on a tier-1 primitive. Should the primitive's PR trigger a foundation-layer build? The recommendation says yes for direct dependents *regardless of layer*. Layer membership is a routing decision (which wrapper), not a dependency-graph decision.

3. **Private-repo gating**: per [CI-032], private repos skip CI. If a downstream dependent is private but the upstream-under-PR is public, what happens? The dependency-graph manifest should record visibility; the matrix skips private dependents when running on a public upstream PR.

4. **Re-export drift (class B vs class A)**: `lint-api-breakage.yml`'s docs already note that branch-pinned deps can surface as class-B false positives. Same risk here. If A's dep on B is `branch: "main"`, then a downstream build of C-which-imports-A captures *both* the A PR and any drift in B. The baseline-comparison discipline catches this only if the baseline includes both. Spec the baseline as "upstream's `main` HEAD + every other dep at the same SHA as in PR head."

5. **Resource cost**: 141 packages × ~5 direct dependents average × ~3min debug build = ~35min of CI compute per PR. Acceptable as advisory; needs sharding or matrix-parallelism if it grows. Crater's lesson: status classification + flake annotations + cluster-by-error reporting are essential at scale — bookmark for if/when the basic mechanism trips a load wall.

6. **swift-institute.org dashboard surface**: surface the per-package "what's my downstream-impact blast radius" view on the Research/Architecture dashboard. Reads the dependency-graph manifest; no new infrastructure.

7. **Cross-org token minting for the downstream build step** — surfaced 2026-05-14 during the status-quo review. The reusable needs to clone each downstream consumer's repo + run `swift package resolve` against the upstream PR substitution; both operations require `PRIVATE_REPO_TOKEN` for any private dependent. The standard `[CI-059]` `secrets: inherit` shape forwards the consumer-org's `PRIVATE_REPO_TOKEN` only — sufficient when the upstream and dependent live in the same org (e.g., one swift-primitives package depending on another), insufficient for cross-org (e.g., a swift-primitives PR triggering builds of swift-foundations consumers).

   Two viable approaches:

   - **(a) Reusable mints its own cross-org installation token** via `actions/create-github-app-token@v3` using the bot's central credentials (`SWIFT_INSTITUTE_BOT_APP_CLIENT_ID` + `SWIFT_INSTITUTE_BOT_APP_PRIVATE_KEY`), with the `owner:` parameter set per matrix-org. This is exactly how `cron-audit-base.yml:171-178` already does it. The reusable would declare the two bot secrets as required inputs (in addition to `PRIVATE_REPO_TOKEN`), and the consumer's `secrets: inherit` forwards them when those org-level secrets are configured. Cost: requires the bot's App + central credentials to be installed/configured on every org that contains a CI-running upstream (the current 17 in `orgs.yaml`), which is already a precondition of the cron orchestrators per `[CI-060]`.

   - **(b) Restrict downstream-impact scope to in-org dependents only**. A swift-primitives PR sees breakage only in its swift-primitives siblings; cross-org breakage is caught by the nightly transitive sweep instead. Cost: zero per-PR cross-org coverage; the long tail lives in the cron sweep.

   Approach (a) is structurally correct but loads more secret-distribution overhead onto provisioning. Approach (b) is simpler at PR time but reduces signal; the nightly catches what the per-PR doesn't, with up-to-24h lag. **Default recommendation: (a) for per-PR runs** (the bot credentials are already required infrastructure for the cron sweeps; the marginal cost is the consumer-side `secrets: inherit` forwarding pattern, which is already uniform per `[CI-059]`), with (b) as a fallback if bot-credential provisioning lags. Compose with the META verification service `lint-org-bot-coverage.yml` (per `ci-cd-cross-ecosystem-reuse.md` v1.1.1 §Q3) — if the coverage check passes for an org, the downstream-impact reusable is unblocked there.

## References

### Primary sources (verified 2026-05-14)

- `swift-institute/.github/.github/workflows/lint-api-breakage.yml` — existing source-level API-breakage detector (the four-class classification template).
- `swift-institute/Scripts/convert-to-local-paths.sh` + `swift-institute/Scripts/setup-mirrors.sh` — existing SwiftPM URL→path substitution primitives.
- [`vapor/vapor`](https://github.com/vapor/vapor/blob/main/.github/workflows/test.yml) `.github/workflows/test.yml` lines 10–38 — `test-providers` matrix job, `swift package edit --path` pattern.
- [`tokio-rs/tokio`](https://github.com/tokio-rs/tokio/blob/master/.github/workflows/ci.yml) `.github/workflows/ci.yml` lines 893–993 — `test-hyper` + `test-quinn` jobs, `[patch.crates-io]` + latest-release-tag pattern.
- [`rust-lang/crater`](https://github.com/rust-lang/crater) `docs/agent-http-api.md` + `docs/bot-usage.md` + `config.toml:25-30` — server-queue + stateless-agent architecture; `mode=check-only|build|build-and-test`; sandbox limits.
- [`swiftlang/swift-source-compat-suite`](https://github.com/swiftlang/swift-source-compat-suite) `runner.py` + `projects/*.json` + `run` (Darwin-only orchestrator).
- [`swiftlang/swift-package-manager`](https://github.com/swiftlang/swift-package-manager) `Sources/PackageManagerDocs/Documentation.docc/Package/PackageConfigSetMirror.md` + `PackageDiagnoseAPIBreakingChange.md` + `Package.swift` (`SWIFTCI_USE_LOCAL_DEPS` env var pattern).
- [`commercialhaskell/stackage`](https://github.com/commercialhaskell/stackage/blob/master/CURATORS.md) — Stackage curator workflow (subagent-verified, not independently spot-checked).
- [NumPy depending-on-numpy guidance](https://numpy.org/devdocs/dev/depending_on_numpy.html) + [Scientific Python SPEC 4](https://scientific-python.org/specs/spec-0004/) — explicit downstream-driven nightly-wheels pattern.
- [GitHub: dependency-graph SBOM endpoint changelog](https://github.blog/changelog/2023-06-19-dependency-graph-dependabot-alerts-and-advisory-database-now-support-swift-advisories/) — SBOM (forward) supported for SwiftPM since 2023; reverse-dep REST API does not exist (subagent verified `/dependents` returns 404).

### Internal cross-references

- [`ci-cd-prior-art-and-pattern-survey.md`](ci-cd-prior-art-and-pattern-survey.md) v1.0.0 — the prior 6-ecosystem survey whose "universal absence" finding this doc refines.
- [`ci-cd-cross-ecosystem-reuse.md`](ci-cd-cross-ecosystem-reuse.md) v1.1.1 — the 4-level `workflow_call` constraint.
- [`ci-centralization-strategy.md`](ci-centralization-strategy.md) v1.1.0 — the three-tier reusable chain.
- [`centralized-swift-ci-and-spine-gate.md`](centralized-swift-ci-and-spine-gate.md) v1.3.0 — advisory-gate design pattern (the γ-1c pilot shape applies here too).
- `swift-institute/Skills/ci-cd-workflows/SKILL.md` — [CI-001]–[CI-070].
- `swift-institute/Skills/research-process/SKILL.md` — [RES-018] premature-primitive (cleared in Analysis); [RES-020] parallel subagent verification (applied); [RES-021] prior-art survey (applied); [RES-026] citations (applied).

### Memory references

- `feedback_workspace_scope_l1_only.md` — current active scope is L1 only; this proposal's first rollout target should be swift-primitives even though the mechanism generalizes.
- `feedback_no_inter_launch_soak.md` — pilot rollout uses readiness gates, not calendar floors.

### Verification probes (2026-05-14)

- `curl https://raw.githubusercontent.com/vapor/vapor/main/.github/workflows/test.yml | grep -i "swift package"` → confirms line 36 `swift package --package-path ./provider edit vapor --path ./vapor`.
- `curl https://raw.githubusercontent.com/tokio-rs/tokio/master/.github/workflows/ci.yml | sed -n '880,945p'` → confirms `test-hyper` job structure with `git checkout $(git describe --abbrev=0 --tags)` and `[patch.crates-io]` block.
- `ls /Users/coen/Developer/swift-primitives/` → 141 directory entries (vs the user's stated "61" — discrepancy noted; the proposal scales to either count).
