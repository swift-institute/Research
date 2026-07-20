# Tiered CI Verification — Measurements, Rulings, and Design

**Status**: Tier 2 RECOMMENDATION — IMPLEMENTED and verified 2026-07-20.
**Version**: 1.0.0 (2026-07-20)
**Rules established**: [CI-115] (tiered scheduling), [CI-116] (prebuilt linter binaries); amendments to [CI-091] (shape vs scheduling), [CI-096] (concurrency is a speed-axis budget).
**Rulings**: R1 and R2, principal-approved 2026-07-20 (this session's Phase 1 → Phase 2 protocol).

## 1. Problem

Development happens on one machine; CI carries the verification load. The mass
swift-linter compliance phase pushes streams of small mechanical commits to
main across dozens of repos, while many packages are red under the existing
full matrix. Per-push full-matrix breadth did not scale in minutes, queue
time, or feedback latency.

## 2. Measurements (2026-07-20; 29 runs / 663 jobs across 4 representative repos)

- **Queue dominates compute.** Small-package legs ran 36–144s but queued
  1.8–6h; macOS-leg queue tails reached 7–12.5h (max observed 45,161s).
- **Cause**: every push scheduled 5 macOS-runner jobs (macos-release + 4
  simulator legs, 4 of 5 advisory) against a free-plan org's **5 concurrent
  macOS runners** — one push saturated an org's entire macOS pool.
- ~8,038s compute per push across ~22–26 jobs; macOS runners absorbed 39% of
  compute seconds; Windows 8%.
- **Red baseline**: 57% of ci-ok conclusions failing/cancelled; matrix legs
  36–64% — most matrix minutes re-verified known-red state.
- **swift-linter**: heaviest gating job, median 502s, bimodal (37–63s
  "warm" floor vs 393–1,450s cold; 18 of 28 runs cold). Two structural causes:
  (a) `actions/cache` is repository-scoped, so the "one shared runner bake"
  premise was false — ~450 repos each rebaked after every engine/rule-pack
  commit; (b) `--exit-policy strict` (gating ruling 2026-07-19) force-routed
  EVERY run to the eval path, so the baked runner was never used in CI at
  all — and the eval executable did not enforce strict either (silently
  inert policy).
- Windows "1-hour legs" did not reproduce (max ~24min + 45-min-timeout
  cancellations); org concurrency limits assumed from documented free-plan
  values (5 macOS / 20 total), consistent with observed serialization.

## 3. Premises re-examined

- **[CI-096] "cost is not an axis"** — holds for dollars/minutes; was wrongly
  extended to runner concurrency, which is a hard capacity budget whose
  exhaustion is queue latency, i.e. the speed axis CI-096 itself ranks.
  AMENDED 2026-07-20.
- **[CI-091] uniform matrix / M4 REJECT of matrix collapse** — the SHAPE
  doctrine survives fully (no platform dropped, no simulator sampling). The
  rejection had conflated shape with per-push SCHEDULING; the R1/R2 rulings
  split them. AMENDED (scheduling clause → [CI-115]).
- **[CI-040] no `.build` cache** — SURVIVES. The staleness incident was real,
  the Apple-canonical argument holds, and compute was not the bottleneck.
  Option B (exact-key dep-fingerprint) remains the recorded upgrade if Linux
  compute ever binds.
- **[CI-041] gitignored `Package.resolved`** — SURVIVES (library convention).
  The `ci-binaries` MANIFEST records baked HEADs; no lockfile needed.
- **Per-push advisory legs** — did not survive: they consumed the scarcest
  resource (macOS concurrency) while gating nothing. Moved to the sweep (R2).

## 4. Design (as implemented)

- **[CI-115] tiers** in the universal `swift-ci.yml`: a `plan` job classifies
  each run (forced `tier` input > tag ref > `[ci full]`/`[ci lint]`/`[ci build]`
  token > consumer dispatch > docs-only diff auto-lint > build default) and
  emits a `legs` CSV; every leg guard composes `!cancelled()` + job-selector +
  `contains(legs)`. lint ≈ format+lint+swift-linter; build adds linux-release;
  full = everything. `plan` sits in ci-ok's needs (plan failure → red);
  tier-skipped legs pass via pre-existing skipped-as-passing; ci-ok attests
  the SELECTED tier. The identity fast-check runs once in `plan` (was ~10×).
- **`ci-sweep.yml`** (nightly 02:11 UTC, swift-institute/.github): name-hash
  rotation over the public fleet (default 7 slices → weekly full coverage),
  matrix `uses:` of the universal with `tier: full`, per-repo failure
  aggregation into a rolling tracking issue. Runs under swift-institute's own
  quota, never competing with consumer pushes.
- **[CI-116] prebuilt linter binaries**: swift-linter's
  `publish-ci-binaries.yml` builds dispatcher + standard runner once per
  engine/rule-pack movement inside `swift:6.3` and publishes them on the
  rolling non-semver `ci-binaries` release (tag created once, never moved;
  provenance in MANIFEST.txt). Consumer CI downloads + `sha256sum -c`
  verifies; legacy source-build kept as fallback.
- **swift-linter exit-policy channel** (swift-linter `0f61c4e`): the CLI
  exports `SWIFT_LINTER_EXIT_POLICY`; `Lint.run(configuration:)` — the shared
  terminal of the prebuilt runner and the eval executable — escalates strict
  exits (non-zero iff any `.error` finding; fail-loud on unknown channel
  value). Routing now gates on format only, so strict CI runs take the fast
  path. This also closed the correctness gap: strict was previously
  unenforced for every Shape-γ consumer.

## 5. Verified results (2026-07-20)

| Surface | Before | After |
|---|---|---|
| Lint-tier push, small package (wall-clock) | ~24min (matrix + cold linter) | **97s**, ci-ok green |
| swift-linter job | median 502s; tails 1,450s+ | **61–77s** all-in |
| macOS jobs per ordinary push | 5 | **0** (full tier/tags/sweep only) |
| Strict exit policy | silently inert (Shape-γ) | enforced on both dispatch paths |
| Full-contract coverage | every push (queue-starved) | tags unconditional + nightly rotation ≤ weekly per repo + on demand |

Canaries: sweep run 29739924925 (branch), lint-tier pushes 29741397095 /
29749926962, dispatch 29749778426 (bool-algebra), publish 29748522008.

## 6. Follow-ups (recorded, not yet done)

- Add `tags: ['*']` to consumer thin-caller `on.push` (mass rollout per
  [CI-050]/[CI-113]) so tag pushes actually trigger the full tier; today tags
  reach CI only where callers already fire on tags.
- L1 wrapper extras (embedded/wasm/android/musl) and `docs` still run
  per-push (Linux-cheap); candidate for tier-gating via a forwarded input.
- Advisory nested linters run in the full tier only; their weekly crons
  remain the primary surface. Fold `advisory-summary` reporting into the
  sweep if the run-summary duplication annoys.
- swift-standards-linter-rules (A4) is still not baked into the runner —
  `Bundle.standards` consumers take the eval path (pre-existing).
- If the ~30–60s per-job setup floor (harden-runner, checkout, credential
  config) becomes the next latency target: merge format+lint into one job.
