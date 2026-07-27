# CI Cache Strategy for Branch-Pinned Swift Package Dependencies

<!--
---
version: 1.1.0
last_updated: 2026-05-04
status: RECOMMENDATION
research_tier: 2
applies_to: [institute, primitives, standards, foundations]
normative: false
---
-->

## Changelog

- **v1.1.0 (2026-05-04)**: Reframe Option D as STRUCTURALLY UNAVAILABLE
  rather than wrong-for-active-dev. The block is the permanent gitignore
  of `Package.resolved` ecosystem-wide via
  `swift-institute/Scripts/sync-gitignore.sh:47`, which is the canonical
  library convention and not under review. Remove Option E (depends on
  Option D being available). Collapse the trajectory to a single
  permanent phase: Option C is the default; Option B is the measured-pain
  upgrade; there is no third phase. Strengthen the Apple-parallel
  rationale: Apple operates under the same constraint set
  (no committed `Package.resolved`, no semver tags during active dev,
  multi-platform matrix, mandatory correctness), so Option C is direct
  alignment under identical constraints rather than coincidental
  convergence. Update the comparison table to drop Option E and to mark
  Option D's row as structurally unavailable. Bundled fixes: define the
  `[jimmya]` link reference (broken since v1.0.0); reword Implementation
  path step 5 from "Optional immediate unblock" to "Cache-prefix bump
  (rejected)" to fit the collapsed trajectory.
- **v1.0.0 (2026-05-04)**: Initial RECOMMENDATION. Identifies Option C
  (no `.build/` cache, Apple-canonical) as the recommendation; Option B
  reserved as the measured-pain upgrade; Option D framed as wrong-for-
  active-dev; Option E framed as long-term goal.

## Context

### Trigger

After the L1 layer-wrapper fan-out (2026-05-04) routed 127 swift-primitives
packages through `swift-primitives/.github/.github/workflows/swift-ci.yml`,
swift-tagged-primitives's CI run [25305485062][run-25305485062] failed across
**every job in the universal matrix** (macOS 6.3, Ubuntu 6.3 release, Ubuntu
6.4-dev nightly release, Windows 6.3, DocC) while the new wrapper-owned
embedded job *passed*. The failure mode:

```
Sources/Tagged Primitives/Tagged+Carrier.Protocol.swift:42:27: error:
'Protocol' is not a member type of protocol 'Carrier_Primitives.Carrier'
```

Diagnosis: `swift-tagged-primitives/Package.swift` declares
`swift-carrier-primitives` as `branch: "main"` (verified: file lines 19–21).
The CI cache restored a stale `.build/checkouts/swift-carrier-primitives/`
from before commit `99ad46e` ("Hoist Carrier to namespace + Carrying alias",
2026-05-03) — at that older commit, `Carrier` was a protocol directly, not a
namespace with a `Protocol` typealias. Embedded passed because its cache
key (`linux-embedded-…`) is a different namespace with no historical
entries, so it fetched fresh and got the post-hoist sources.

This is not a one-off: any branch-pinned dep with a recent breaking change
has the same failure mode. The L1 fan-out triggered 127 fresh runs in quick
succession, surfacing the latent staleness loudly.

### Empirical state (2026-05-04)

Verified for this document:

- `swift-institute/.github/.github/workflows/swift-ci.yml` cache step
  ([file lines 90–96][cache-step]):
  ```yaml
  key: linux-${{ inputs.cache-key-prefix }}-${{ hashFiles('Package.swift', 'Package@*.swift') }}
  restore-keys: linux-${{ inputs.cache-key-prefix }}-
  ```
  The bare-prefix `restore-keys` is the load-bearing defect: it allows
  ANY prior cache with the prefix to restore even when the
  `Package.swift` hash differs. With branch-pinned deps, Package.swift
  hash is stable across upstream changes, so the cache survives even
  when the dep graph has moved.
- `swift-tagged-primitives/Package.swift` declares the carrier-primitives
  dep as `branch: "main"` (lines 19–21).
- `Package.resolved` is gitignored ecosystem-wide
  (`grep -h 'Package.resolved' swift-tagged-primitives/.gitignore` → present;
  `git -C swift-tagged-primitives ls-files Package.resolved` → empty).
  Across the swift-primitives org clone-mirror, 35 packages have a local
  `Package.resolved` file but none are committed.
- swift-primitives ecosystem currently has NO published tags on any
  package — every consumer pins by `branch: "main"`. This is the
  active-development convention and not under near-term review.

### Scope

Ecosystem-wide [RES-002a] — every package in
`swift-{primitives,standards,foundations}` consuming the
`swift-institute/.github/.github/workflows/swift-ci.yml` reusable. The L2
and L3 layer wrappers (when introduced) will inherit the decision.

### Out of scope

- Eventual transition to semver-tagged deps (long-term ecosystem goal,
  cited in [`ci-centralization-strategy.md`][ci-cent]).
- Build-cache strategies for non-SwiftPM artifacts (DocC archive cache,
  Xcode `derivedData`, etc.).
- Caching policies for `swiftlint`/`swift-format` reusable workflows
  (separate workflow files, separate decision).

---

## Question

How should CI cache `.build/` when one or more dependencies are pinned to a
moving git ref (branch), given that:

1. The current `restore-keys` shape silently serves stale dependency
   checkouts and produces broken builds when upstream deps ship breaking
   changes;
2. Bumping the cache-key-prefix (`v1` → `v2`) is reactive, brittle, and
   needs to be redone every time it bites;
3. A blunt `swift package update` step would fix correctness but adds 30–60s
   to every CI run;
4. The ecosystem has no committed `Package.resolved` files and no tagged
   dependency versions to pin to.

The structurally correct answer must be:

- **Truthful**: cache validity matches actual dep-graph state
- **Maintainable**: no prefix bumps, no manual intervention
- **Affordable**: doesn't impose meaningful overhead on the common case
- **Defensible**: aligns with or has explicit reason to deviate from
  canonical Apple/swiftlang practice

---

## Analysis

### Option A — Status quo (prefix-fallback `restore-keys`)

Current shape. Cache key includes `hashFiles('Package.swift')` for exact
match; `restore-keys` is bare prefix `${prefix}-` for fallback.

**Mechanism**: When the exact key misses, restore-keys does prefix matching
and pulls the most recently-created cache with the matching prefix. With
branch-pinned deps, the Package.swift hash is stable across upstream
changes — so the cache survives upstream evolution and SwiftPM trusts the
stale `.build/checkouts/`.

**Failure mode (verified 2026-05-04)**: When upstream ships breaking changes
on `branch: "main"`, every consumer's CI fails until either (a) the
cache-key-prefix is bumped manually, (b) the cache naturally evicts after
GitHub's 7-day inactivity window, or (c) Package.swift content changes for
unrelated reasons.

**Pros**:
- Fastest cache hit (no per-job overhead)
- Zero implementation effort

**Cons**:
- Wrong-by-design when upstream branch deps move
- Forces manual cache-prefix bumps as remediation
- Each bump is a 130-package fan-out commit (workspace-scale change for
  a temporary unblock)
- Erodes trust: every "CI broken" report needs upstream-vs-cache triage
- Surfaces unpredictably: failure intensity depends on upstream commit
  cadence, which is high during active dev

### Option B — Dynamic dep-fingerprint cache key

Add one workflow step before the cache restore that computes a fingerprint
of all branch-pinned deps:

```yaml
- name: Compute branch-dep fingerprint
  id: dep-fp
  shell: bash
  run: |
    set -euo pipefail
    branch_deps=$(swift package dump-package 2>/dev/null | jq -r '
      .dependencies[]
      | select(.sourceControl)
      | .sourceControl[]
      | select(.requirement.branch)
      | "\(.location.remote[0]) \(.requirement.branch[0])"
    ')
    if [ -z "$branch_deps" ]; then
      fp="no-branch-deps"
    else
      fp=$(while IFS=' ' read -r url branch; do
        [ -n "$url" ] || continue
        sha=$(git ls-remote "$url" "$branch" 2>/dev/null | head -1 | cut -f1)
        echo "$url@$branch=${sha:-unresolved}"
      done <<< "$branch_deps" | sha256sum | head -c 16)
    fi
    echo "fingerprint=$fp" >> "$GITHUB_OUTPUT"

- name: Cache Swift packages
  uses: actions/cache@v5
  with:
    path: .build
    key: ${{ runner.os }}-${{ inputs.cache-key-prefix }}-${{ hashFiles('Package.swift', 'Package@*.swift') }}-${{ steps.dep-fp.outputs.fingerprint }}
    # No restore-keys: exact match required for correctness.
```

**Mechanism**: cache key is `(runner-os, cache-prefix, Package.swift-hash,
remote-HEAD-fingerprint)`. Any change to upstream branch HEADs invalidates
the cache. No restore-keys: exact match or full miss.

**Pros**:
- Captures actual cache-validity condition truthfully
- No manual cache-prefix bumps ever
- Cache miss only happens when something legitimately changed
- Implementation isolated to one workflow file (swift-institute reusable),
  no per-package change

**Cons**:
- Adds ~5–15s per cache job (one `git ls-remote` per branch-pinned dep)
- Needs Swift toolchain available before cache step (true for our matrix —
  toolchain comes from container or pre-installed runner)
- For private-repo deps, needs `PRIVATE_REPO_TOKEN` configured before this
  step (already done by the existing `enable-private-repos` flow)
- Adds bash + jq complexity to the workflow (~30 lines); novel pattern
  that no surveyed repo currently uses
- Cache-miss cost: full rebuild (~60–180s)

### Option C — No `.build/` cache (Apple/swiftlang canonical)

Drop the `actions/cache@v5` step entirely. Each CI run does a fresh
`swift package resolve` + clone + compile.

**Prior art (verified 2026-05-04)**:

`swiftlang/github-workflows/.github/workflows/swift_package_test.yml` is
995 lines and contains **zero** uses of `actions/cache`, `hashFiles`,
`restore-keys`, `Package.resolved`, or `swift package update`. The
sibling reusables (`soundness.yml`, `pull_request.yml`,
`pull_request_dependency_check.yml`) likewise have no cache steps.

This is the canonical CI used by:

| Apple/swiftlang package | Workflow ref | Verified |
|---|---|---|
| [apple/swift-syntax][r-syntax] | `swift_package_test.yml@0.0.9` | ✓ |
| [apple/swift-collections][r-coll] | `swift_package_test.yml@0.0.9` | ✓ |
| [apple/swift-numerics][r-num] | `swift_package_test.yml@main` | ✓ |
| [apple/swift-system][r-sys] | `swift_package_test.yml@0.0.7` | ✓ |
| [apple/swift-format][r-fmt] | `swift_package_test.yml@0.0.11` | ✓ |
| [apple/swift-package-manager][r-spm] | `swift_package_test.yml@0.0.11` | ✓ |
| [apple/swift-async-algorithms][r-async] | `swift_package_test.yml@main` | ✓ |
| [apple/swift-nio][r-nio] | `soundness.yml@0.0.10` + own custom `unit_tests.yml` | ✓ |

Apple's choice is a **deliberate decision**: they accept the per-run
fetch+build tax in exchange for guaranteed correctness across the entire
canonical Swift ecosystem. The ~995-line workflow has no cache exception
even for the most heavily-built repos.

**Pros**:
- Zero cache logic to maintain or reason about
- Cannot get stale-cache failures (because no cache)
- Aligns with canonical Apple/swiftlang practice
- Predictable: every run is identical to a fresh checkout
- Removes a workflow step (negative implementation cost)

**Cons**:
- Every CI run pays the full SwiftPM-resolve + clone + compile tax
- For Linux containers and Windows where SwiftPM resolution is slower,
  this is meaningful — measured ~60–180s per matrix job (8 deps,
  release config)
- Total CI time per consumer goes from ~3 min (cache hit) to ~6–10 min
  (no cache)
- Loses incremental compilation benefits between unrelated runs

### Option D — Cache by `Package.resolved` hash

**Status: STRUCTURALLY UNAVAILABLE.**

Pattern from [jimmya/SPM-Caching][jimmya] and similar community examples:
require `Package.resolved` to be committed to the repo, then use
`hashFiles('**/Package.resolved')` as the cache key.

**Why structurally unavailable (verified 2026-05-04)**:

`Package.resolved` is gitignored ecosystem-wide as a permanent library
convention. The canonical source is
`swift-institute/Scripts/sync-gitignore.sh:47`, which emits
`'Package.resolved'` into the `CANONICAL_LINES` array — the auto-synced
block landed in every repo's `.gitignore`. The convention is not
transitional or pending review; library packages do not commit
`Package.resolved` because the resolved-graph is the consumer's
responsibility, not the library's
([SwiftPM `Package.resolved` documentation][spm-resolved]).

Option D requires the reverse — `Package.resolved` committed
ecosystem-wide. That requires reversing the canonical convention, which
is not under consideration. Option D is therefore not "deferred" or
"wrong for our phase": it is **off the table at the constraint level**.

**Even if Option D were available**, it would still be wrong for active
dev because SwiftPM with branch-pinned deps does NOT auto-update
`Package.resolved` on each build. It only re-resolves when
`Package.swift` changes or when `swift package update` is explicitly
run. So if upstream `branch: "main"` moves, `Package.resolved` still
pins to the old SHA, the cache still hits, and consumers don't see the
upstream change at all. The structural unavailability makes this analysis
academic; we record it for completeness so future readers do not
re-litigate the option from the wrong premise.

**Pros (academic, gated on availability)**:
- Cache key matches deterministic resolution
- Reproducible builds

**Cons**:
- Structurally unavailable: `Package.resolved` is permanently gitignored
  via the canonical sync convention
- Even if available: hides upstream dep changes from CI until manual
  `swift package update`; defeats the purpose of `branch: "main"` deps
  in active dev

---

## Comparison

Option E (force tag-pinning + Option D) was present in v1.0.0; it is
removed in v1.1.0 because it depended on Option D being available, which
v1.1.0 establishes is not the case under the canonical gitignore
convention.

| Criterion | A: status quo | B: dep-fingerprint | C: no cache (Apple) | D: Package.resolved |
|---|---|---|---|---|
| Availability | available | available | available | **structurally unavailable** (canonical gitignore) |
| Correctness when upstream moves | ✗ wrong | ✓ exact | ✓ exact | n/a |
| Cache hit speed | fastest | fast | n/a | n/a |
| Cache miss / no-cache cost per job | n/a | ~60–180s | ~60–180s | n/a |
| Per-job overhead added | 0 | ~5–15s | 0 | n/a |
| First-run cold cost | full rebuild | full rebuild | full rebuild | n/a |
| Catches upstream breakage early | by accident | yes | yes | n/a |
| Manual ops required when deps move | bump prefix | none | none | n/a |
| Implementation effort | 0 | ~30 lines, one file | -28 lines, one file | n/a |
| Apple/swiftlang precedent | no | no | **yes (canonical)** | n/a |
| Workflow complexity | low | medium | lowest | n/a |
| Lifetime under active dev | bad | good | good | n/a |

---

## Outcome

**Status**: RECOMMENDATION

**Recommended approach**: **Option C (no `.build/` cache) for the
active-development phase.**

### Rationale

**Apple operates under the same constraints we do, and chose Option C
deliberately.** Apple's canonical Swift CI infrastructure
(`swiftlang/github-workflows/.github/workflows/swift_package_test.yml`,
995 lines) has zero `.build/` caching, no `restore-keys`, no
`Package.resolved`-keyed shapes, no `swift package update` step. This is
the workflow used by swift-syntax, swift-collections, swift-numerics,
swift-system, swift-format, swift-package-manager, swift-async-algorithms,
and the soundness portion of swift-nio.

Apple's choice and ours are **direct alignment under the same constraint
set**, not coincidental convergence:

| Constraint | Apple | Swift Institute | Same? |
|---|---|---|---|
| `Package.resolved` not committed (libraries) | yes | yes (gitignored, [`sync-gitignore.sh:47`][sync-gitignore]) | ✓ |
| Branch-pinned deps during active development | yes (pre-tag work) | yes (no published `v1.0.0` tags ecosystem-wide) | ✓ |
| Multi-platform matrix (macOS + Linux + Windows) | yes | yes | ✓ |
| Mandatory CI correctness (no flake-tolerated jobs) | yes | yes | ✓ |
| Frequent CI runs (high commit cadence on main) | yes | yes | ✓ |

Under this constraint set, Option D is unavailable to both ecosystems
(no committed `Package.resolved`); the v1.0.0 Option E is unavailable to
both (no semver tags during active dev); Option A produces stale-cache
failures in both; Option B is novel-bespoke in both. Option C is the
intersection of "available" and "correct" for this constraint set —
Apple chose it; we choose it for the same reasons.

Three observations confirm Option C is the right choice:

1. **Direct alignment beats novel-bespoke.** Option B is sound but no
   surveyed Swift package uses dynamic dep-fingerprinting. Adopting it
   puts our ecosystem ahead of Apple's canonical pattern with our own
   bespoke shape, accumulating maintenance debt for a problem Apple
   chose to solve by simplification under identical constraints.

2. **The cost is bounded and predictable.** Option C trades cached-build
   speedup (~3 min/job → ~6–10 min/job) for permanent correctness. With
   ~127 packages × ~6 jobs/run = ~760 job-minutes added per ecosystem-wide
   CI cycle, this is real but bounded cost. The cost of stale-cache
   failures (Option A) is unbounded: every time it fires, multiple
   packages need triage, the team loses trust in CI, and remediation is
   a 130-package fan-out commit.

3. **Option B remains the measured-pain upgrade.** When the per-run cost
   actually becomes painful — measured pain, not speculative — Option B's
   dep-fingerprint approach is the next step up. We do not need to
   pre-pay its complexity to capture its benefits today, because the
   marginal correctness improvement over Option C is zero (both are
   correct).

### What Option C does NOT solve

- **DocC archive cache**: separate workflow (`swift-docs.yml`), separate
  cache step. Not in scope here. The same analysis applies: the docs
  job currently has the same cache-key shape and the same vulnerability.
- **`swiftlint` and `swift-format` reusables**: separate files; the
  recommendation extends to them by analogy but the implementation is
  scoped per workflow.

### Implementation path

1. **Edit `swift-institute/.github/.github/workflows/swift-ci.yml`**: drop
   the `actions/cache@v5` step from the four matrix jobs (`macos-release`,
   `linux-release`, `linux-nightly`, `windows-release`). Removes ~28 lines
   total (~7 per job).
2. **Drop the `cache-key-prefix` input**: no longer used. Update the layer
   wrappers (currently `swift-primitives/.github/.github/workflows/swift-ci.yml`)
   to stop passing it.
3. **Update header documentation** in both reusables to record the
   no-cache decision and the Apple-precedent rationale (one paragraph).
4. **Delete `cache-key-prefix: swift63-spm-v1`** from all 127 L1 consumer
   `ci.yml` files (mechanical sed, same shape as today's @main → wrapper
   sweep).
5. **Cache-prefix bump (rejected).** Historically used to flush stale
   caches; under Option C the failure mode is structurally absent, so
   no unblock path is needed. Tracked under Dead Ends in
   [`ci-centralization-strategy.md`][ci-cent] when the invariants are
   codified there.

### Reversal path

If observed CI cost becomes meaningfully painful (measure, don't speculate),
the upgrade is to Option B:

1. Re-introduce the `actions/cache@v5` step
2. Add the dep-fingerprint pre-step from Option B above
3. Use the dep-fingerprint as the exact-match cache key
4. **No `restore-keys`** — exact match or full miss

This is a workflow-only change, isolated to the swift-institute reusable.
No per-package change required.

### Trajectory

Option C is the permanent default. Option B is the measured-pain
upgrade when (and only when) per-run CI cost becomes the binding
constraint — implemented as a workflow-only change in the
swift-institute reusable, no per-package edits.

There is no third phase. Even when the ecosystem ships semver-tagged
releases and consumers migrate from `branch: "main"` to `from: "1.0.0"`,
the constraint set that makes Option D unavailable remains intact:
`Package.resolved` is gitignored as a permanent library convention, not a
transitional one. Apple's tag-pinned packages run on the same canonical
no-cache workflow; the trajectory we land on is the trajectory they are
already on.

---

## References

### Verified primary sources

- [`swiftlang/github-workflows/.github/workflows/swift_package_test.yml`][stl-spt]
  — 995 lines, zero cache uses (verified 2026-05-04).
- [`swiftlang/github-workflows/.github/workflows/soundness.yml`][stl-snd]
  — zero cache uses (verified 2026-05-04).
- [`apple/swift-syntax/.github/workflows/pull_request.yml`][r-syntax],
  [`apple/swift-collections/.github/workflows/pull_request.yml`][r-coll],
  [`apple/swift-numerics/.github/workflows/pull_request.yml`][r-num],
  [`apple/swift-system/.github/workflows/pull_request.yml`][r-sys],
  [`apple/swift-format/.github/workflows/pull_request.yml`][r-fmt],
  [`apple/swift-package-manager/.github/workflows/pull_request.yml`][r-spm],
  [`apple/swift-async-algorithms/.github/workflows/pull_request.yml`][r-async],
  [`apple/swift-nio/.github/workflows/pull_request.yml`][r-nio]
  — all route through `swiftlang/github-workflows` (verified 2026-05-04).
- [GitHub Actions cache documentation][gh-cache] — confirms restore-keys
  partial-prefix matching behavior; no documented guidance for
  branch-pinned dep caching.
- [`pointfreeco/swift-composable-architecture/.github/workflows/ci.yml`][pf-tca]
  — caches Xcode `derivedData` keyed on `hashFiles('**/Sources/**/*.swift')`,
  not SwiftPM `.build`. Has the same vulnerable `restore-keys` shape;
  Point-Free has not addressed it (verified 2026-05-04).
- [`jimmya/SPM-Caching/.github/workflows/build.yml`][jimmya-yml] — community
  example of `Package.resolved`-keyed cache; only viable when
  `Package.resolved` is committed (verified 2026-05-04).

### Failing CI run (origin incident)

- swift-primitives/swift-tagged-primitives run
  [25305485062][run-25305485062] (2026-05-04 07:00:32 UTC) — five matrix
  jobs failed with `'Protocol' is not a member type of protocol
  'Carrier_Primitives.Carrier'`; embedded job passed because of fresh
  cache key.

### Internal cross-references

- [`ci-centralization-strategy.md`][ci-cent] — establishes the
  swift-institute reusable-workflow centralization pattern; this
  document extends with cache-strategy detail it did not address.

### Hoist commit (root cause)

- swift-primitives/swift-carrier-primitives commit
  [`99ad46e`][hoist] (2026-05-03) — "Hoist Carrier to namespace + Carrying
  alias; rename storage to underlying". Pre-hoist `Carrier` was the
  protocol directly; post-hoist it's a namespace with `Protocol`
  typealias. Stale CI cache served the pre-hoist sources to consumers
  built post-hoist.

[run-25305485062]: https://github.com/swift-primitives/swift-tagged-primitives/actions/runs/25305485062
[cache-step]: https://github.com/swift-institute/.github/blob/main/.github/workflows/swift-ci.yml
[ci-cent]: ci-centralization-strategy.md
[stl-spt]: https://github.com/swiftlang/github-workflows/blob/main/.github/workflows/swift_package_test.yml
[stl-snd]: https://github.com/swiftlang/github-workflows/blob/main/.github/workflows/soundness.yml
[r-syntax]: https://github.com/apple/swift-syntax/blob/main/.github/workflows/pull_request.yml
[r-coll]: https://github.com/apple/swift-collections/blob/main/.github/workflows/pull_request.yml
[r-num]: https://github.com/apple/swift-numerics/blob/main/.github/workflows/pull_request.yml
[r-sys]: https://github.com/apple/swift-system/blob/main/.github/workflows/pull_request.yml
[r-fmt]: https://github.com/apple/swift-format/blob/main/.github/workflows/pull_request.yml
[r-spm]: https://github.com/apple/swift-package-manager/blob/main/.github/workflows/pull_request.yml
[r-async]: https://github.com/apple/swift-async-algorithms/blob/main/.github/workflows/pull_request.yml
[r-nio]: https://github.com/apple/swift-nio/blob/main/.github/workflows/pull_request.yml
[gh-cache]: https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows
[pf-tca]: https://github.com/pointfreeco/swift-composable-architecture/blob/main/.github/workflows/ci.yml
[jimmya-yml]: https://github.com/jimmya/SPM-Caching/blob/main/.github/workflows/build.yml
[hoist]: https://github.com/swift-primitives/swift-carrier-primitives/commit/99ad46e
[jimmya]: https://github.com/jimmya/SPM-Caching
[sync-gitignore]: https://github.com/swift-institute/Scripts/blob/main/sync-gitignore.sh#L47
[spm-resolved]: https://docs.swift.org/swiftpm/documentation/packagedescription/package-resolved-file
