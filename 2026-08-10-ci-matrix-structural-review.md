# CI matrix structural review: is the NightlyException regime a symptom?

**Date:** 2026-08-10
**Author:** CI-matrix research session (commissioned by the principal via Launch coordinator 8830f961)
**Question:** Is the recurring nightly-exception regime (swift-institute/.github#488 — Ubuntu Swift main-nightly failing on upstream toolchain defects, advisory exception with a recheck cliff currently 2026-09-14, launch day) a symptom of a structural deficit in the fleet CI matrix?
**Subject revision:** `swift-institute/.github` @ `4e214fb8b56982fec7bf99a565b9ea92cb3b2755` (`.github/workflows/swift-ci.yml`, `Tools/institute-ci`).

## Verdict

Partly, and not where the symptom points. The advisory posture of the nightly legs is
**sound** — it is a deliberate, defensible divergence from upstream practice, correctly
matched to the Institute's standing no-upstream-filings ruling. The structural deficits are
three, all orthogonal to "should nightly gate":

1. **The expiry of an advisory-leg exception fails the fleet's required check.** That is the
   mechanism that manufactures the exception → extension → cliff pattern, and it is a
   category error: fail-closed semantics are being applied to paperwork for a leg that
   cannot affect any verdict.
2. **Nightly image identity is inconsistent.** One nightly leg is digest-pinned (the ruled
   discipline); two others ride mutable `swiftlang/swift:nightly-*` tags, violating the
   identity-pinned class and making green→red-with-no-commit routine.
3. **Main-nightly signal is fleet-shaped when it is upstream-shaped.** Measured data shows
   the signal is dominated by a handful of packages; running it per-repository across ~470
   repositories re-measures the same upstream fact hundreds of times.

The recommended #488 disposition is a structural change that makes the cliff disappear, not
a date move (see §7).

## 1. The current universal matrix

From `swift-ci.yml` at the subject revision. Tiering (R1/R2 ruling 2026-07-20): ordinary
push/PR runs the **build** tier (quality gates + primary release leg + `linux-6-4`); the
**full** tier (everything) runs on `workflow_dispatch`, `[ci full]`, and the nightly
`ci-sweep.yml` rotation.

| Leg | Image / toolchain | Config | Gating | Tier | Evidence of |
|---|---|---|---|---|---|
| `plan` | `ubuntu-latest`, `institute-ci` (Swift owner) | — | yes (in `ci-ok` needs) | all | Tier/leg selection; typed-exception validation; subject resolution; identity-conflict + branch-pin guards |
| `macos-release` | `xcode-27` preview label, Xcode 27.0 pin (Swift 6.4 beta 6.4.0.25.4) | debug test | yes | full | Darwin correctness; the only Apple-host leg. Note: Swift version comes from the Xcode pin, not `swift-version` (name-vs-toolchain trap documented in-file) |
| `linux-release` | plan-resolved `linux-image` — currently the release-floor exception digest `swiftlang/swift@sha256:8d61…` (`nightly-6.4.x-noble`, because `swift:6.4` stable does not exist; #491/#494) | release build (build tier) / release test (full) | yes; primary build-tier leg | build+full | Linux correctness **and the fleet's only release-mode optimizer gate** (`-O`, CMO class) |
| `linux-nightly` | **digest-pinned** `swiftlang/swift@sha256:f577f9…` (main nightly = 6.5-dev) | release test | advisory (`continue-on-error`) | full only | Early warning of upstream main breakage. Classified by the typed `NightlyException` (upstream swiftlang/swift#90275, OPEN; recheck 2026-09-14) |
| `linux-6-4` | **mutable tag** `swiftlang/swift:nightly-6.4.x-jammy` | release build (build tier) / test (full) | advisory | build+full | Upcoming-release (6.4) signal; graduates to gating `swift:6.4` at GA |
| `windows-release` | `windows-latest`, SwiftyLab setup-swift 6.4, native build system (#498) | debug test | yes | full | **The fleet's only assertions-enabled compiler ⇒ only SIL-validity gate**; Windows portability |
| `apple-simulator-build` | `xcode-27`, iOS/tvOS/watchOS/visionOS generic destinations | xcodebuild build | advisory (soak) | full | The only leg running the resource-bundle CodeSign phase |
| `embedded` | **mutable tag** `swiftlang/swift:nightly-main-jammy` | Embedded mode, host triple | advisory (permanent) | full, primitives bundle | Embedded-Swift compilability of L1 primitives |
| `embedded-wasm-sdk` / `android-build` / `static-linux-musl-build` | plan-resolved `linux-image` + SDK install | build | advisory (soak; musl may stay advisory) | full, primitives bundle | Wasm / Android / musl static-SDK cross-compilability |
| `format` / `lint` / `swift-linter` | plan-resolved `linux-image` | — | yes | build+full | swift-format, SwiftLint (pinned + sha256), swift-linter bundle |
| `docs` | nested `swift-docs.yml` | DocC | per swift-docs | full | Documentation builds |
| advisory linters (`lint-yaml`, symlinks, license, spine, api-breakage, pr-title) | various | — | advisory | — | Hygiene |
| `advisory-summary`, `ci-ok` | `ubuntu-latest` | — | `ci-ok` is THE required check | all | Aggregation: every gating leg named in plan's `legs` must have succeeded |

Two typed calendar exceptions live in workflow `env` and are validated by `plan`
(`institute-ci`) on every run:

- **`NightlyException`** (`SWIFT_MAIN_NIGHTLY_*`): binds the main-nightly digest, upstream
  issue #90275, recheck 2026-09-14. `validate(today:)` throws `.expired` when
  `today > recheck` ⇒ **plan fails ⇒ all legs skip ⇒ `ci-ok` red, fleet-wide** (#488's
  "deliberate fail-closed cliff").
- **`ReleaseFloorException`** (`SWIFT_RELEASE_FLOOR_*`): substitutes a pinned 6.4-nightly
  digest for the nonexistent `swift:6.4` stable image on the **gating** Linux legs; recheck
  2026-09-09, refused beyond the typed RC/stable boundary. Same fail-closed expiry.

History note: the typed regime is young — #485/#487 landed 2026-08-09, replacing an untyped
`continue-on-error` era in which `linux-nightly` floated on the mutable `nightly-main-jammy`
tag. The "recurring regime" is therefore not literally repeated extensions of one recheck
field yet; it is the standing pattern across eras: upstream defect → advisory classification
→ time-bound exception → cliff, with the cliff now typed and fleet-fatal.

## 2. What apple/swiftlang and the ecosystem do

(Web survey 2026-08-10; sources inline.)

**swiftlang/swift itself** (swift.org/documentation/continuous-integration, ci.swift.org):
Jenkins swift-ci, human-triggered per-PR (`@swift-ci Please test`), platform-selectable
presets over macOS + Ubuntu 18.04/20.04/22.04 + CentOS 7 + Amazon Linux 2 (+ Apple
simulators). No nightly axis — they *are* the nightly. Windows is community/external-node
territory, not in the documented PR set.

**swiftlang/github-workflows `swift_package_test.yml`** (the canonical package-test
reusable): Linux defaults **5.9–6.3 + nightly-main + nightly-6.4.x** on jammy
(`ubuntu-24.04`, optional arm); Windows defaults **5.9, 6.0–6.3 + nightly-main +
nightly-6.4.x** on `windows-2022` Docker LTSC2022 images; opt-in musl static SDK, Wasm SDK,
Android SDK (each at 6.3 + nightly-6.4.x + nightly-main), macOS/Xcode, FreeBSD
(nightly-main). **No `continue-on-error` anywhere: nightly legs are ordinary blocking PR
checks.** The only escape hatch is version-exclusion inputs.

**apple/swift-nio**: own reusable matrix, Linux 6.0–6.3 + nightly-next + nightly-main,
Windows 6.3 + both nightlies, plus musl/Wasm/Android/benchmarks/cxx-interop — all blocking
on PR; the single softening is dropping `-warnings-as-errors` on nightly-main. Twice-daily
scheduled runs repeat the matrix plus Apple-platform Xcode tests.

**apple/swift-foundation**: gates PRs on **nightly-main only** (it tracks the compiler).
**apple/swift-openapi-generator**: NIO-style, blocking nightlies, but excludes nightly-main
from integration/example matrices. **vapor/vapor**: currently a single mutable
`swiftlang/swift:nightly-6.4.x-bookworm` image, Linux-only, blocking.

**Swift.org platform support**: "Deployment and Development" = macOS, Ubuntu, Debian,
Fedora, Amazon Linux, RHEL UBI, Windows; "Deployment-only" = iOS/watchOS/tvOS/visionOS,
Android.

### Reading the comparison honestly

Upstream's convention is *gate on nightlies*. It would be wrong to copy it. Those projects
can and do fix the compiler when nightly breaks them — the toolchain is their product or
sits one team away. The Institute has a standing ruling that toolchain defects stay internal
(no swiftlang filings), so a red gating nightly here is **permanently unactionable**: it
could only be cleared by waiting or by working around upstream inside product packages,
which is exactly the corruption the platform-support input exists to prevent. The 2026-07-28
measurement quantifies it: gating main-nightly would have turned 62 green repositories red,
5 of them on an unfixable upstream compiler-abort class, 1 on a Docker registry hiccup.
Advisory nightly + gating stable floor is the correct posture for this fleet and should be
recorded as a deliberate divergence, not drift toward upstream's default.

Where upstream comparison *does* bite:

- Everyone in the survey treats a nightly as **one axis value with one identity source**.
  We run main-nightly under two different identities (a pinned digest in `linux-nightly`, a
  floating tag in `embedded`).
- The ecosystem distro floor is moving to noble/bookworm; our mutable `-jammy` tags already
  produced the glibc-skew class (#494: jammy glibc 2.35 vs linter binaries needing 2.38).
- Our musl/Wasm/Android coverage matches the upstream opt-in set — that part of the matrix
  is at parity and needs no change.
- Nobody upstream has an equivalent of a calendar expiry that fails every consumer's
  required check. That mechanism is ours alone.

## 3. Finding 1 — the cliff is a category error (structural)

The matrix distinguishes gating legs (evidence the fleet relies on) from advisory legs
(observation). The exception machinery does not: both `NightlyException` and
`ReleaseFloorException` fail `plan` — and therefore `ci-ok`, fleet-wide — on expiry.

For the **release-floor** exception, fail-closed is right: it substitutes the image under
*gating* legs, so an expired exception means the fleet's required evidence is running on an
unratified toolchain identity. Expiry must stop the line.

For the **nightly** exception, the leg it classifies is `continue-on-error`, excluded from
`ci-ok` needs, full-tier only. Its failure cannot change any verdict. When its paperwork
lapses, the safe degraded state is *the leg does not run* — no unclassified advisory result
can then exist. Failing `plan` instead converts an observation lane's expired classification
into a fleet-wide outage on a calendar date, and because the date is bounded by upstream's
schedule (an OPEN upstream defect, #90275, that we by ruling do not push on), each recheck
predictably arrives with the defect unresolved — hence exception → extension → cliff, with
the current cliff on launch day. The regime is not a symptom of testing the wrong images;
it is a symptom of one wrong coupling: **advisory-class exception expiry ⇒ gating-class
consequence.**

Structural fix (one semantic change in `institute-ci`, no matrix change):
`CI.Contract.NightlyException` expiry stops throwing in `plan` and instead (a) removes
`linux-nightly` from `legs`, (b) emits a typed `expired` marker into the plan JSON, step
summary, and `advisory-summary`, and (c) is surfaced by the existing scheduled control plane
(the `alert-scheduled-workflow-failure` / weekly-sweep family) as a loud, single-channel
alarm. The recheck date keeps its full force — an expired exception still deschedules the
leg and pages the coordinator — but the failure domain matches the leg's evidence class.
`ReleaseFloorException` keeps fail-closed expiry unchanged.

## 4. Finding 2 — nightly identity discipline is inconsistent

Per the ci-cd skill, containers are **identity-pinned, no exception**. Current state:

- `linux-nightly`: digest-pinned via the exception. Compliant — and note this *is*
  alternative (iii) from the commission ("pinned nightly snapshots advanced deliberately"),
  already realized. Advancing the digest is a ruling-shaped edit with `pin-advance.yml`
  as the existing advance surface.
- `linux-6-4`: mutable `swiftlang/swift:nightly-6.4.x-jammy`. Non-compliant; runs on
  **every push** (build tier), so a nightly republish changes the fleet's most frequently
  executed advisory leg's toolchain with no commit and no record. Also on the jammy side of
  the #494 glibc skew class.
- `embedded`: mutable `swiftlang/swift:nightly-main-jammy`. Non-compliant, and a **second,
  unpinned identity for main-nightly** — the exception's digest claims to be "the sole
  main-nightly exception" while `embedded` floats free of it. Two identities for one axis
  value is exactly the label-vs-identity conflation the commission asked about.

Fix: both legs move to digests advanced deliberately (the `linux-6-4` digest can live
beside the release-floor values with the same validated shape; `embedded` binds the
NightlyException digest so main-nightly has exactly one identity in the file).

## 5. Finding 3 — main-nightly is fleet-shaped signal for an upstream-shaped question

The question `linux-nightly` answers — "does the upcoming Swift main break us?" — is a
property of upstream plus a small set of closure-critical packages, not of 470 repositories
independently. The 2026-07-28 measurement: of 62 would-be-new reds, 42 were one package
(swift-linux-standard io_uring) reached transitively. Running the leg per-repository in the
full-tier rotation re-measures the same upstream facts hundreds of times per week, spending
the binding runner budget on redundant confirmation.

Proposal: retire `linux-nightly` from the per-repository universal matrix and replace it
with a **scheduled canary sweep** — a dedicated scheduled workflow in
`swift-institute/.github` that dispatches the main-nightly leg (via the existing
`ci-dispatch.yml` single-job surface) over a ruled canary set: the transitive-closure
choke points (swift-linux-standard and peers), one deep representative per layer, and any
package with a live upstream-sensitivity record. It reports to its own channel (a standing
issue or the advisory-summary of the sweep run), never to per-package checks. `linux-6-4`
— the upcoming-*release* signal, which graduates to gating at GA — stays per-push, as today.
This removes the only leg the NightlyException classifies from every consumer's run, which
is the second, independent way the #488 cliff class disappears from the fleet's required
check path.

## 6. Finding 4 — image identity recording gaps (minor)

Runner images are "unpinnable, recorded only" — record the resolved image version, never
trust the label. Current recording:

- Linux container legs: `swift --version` + `job.container.image` — sufficient where the
  image is a digest; for the mutable-tag legs (Finding 2) the tag is recorded but the
  resolved digest is not, so the run's environment is unrecoverable.
- `macos-release` / `apple-simulator-build` / `windows-release`: print `runner.os` + the
  label (`xcode-27`, implicit `windows-latest`) + `swift --version`, but **not the resolved
  runner image version** (the `ImageVersion`/`ImageOS` runner environment variables). Two
  runs on the "same" label are being implicitly treated as the same environment; the
  file's own Xcode-pin commentary shows why that is not safe on a preview label.

Fix: extend each leg's "Print toolchain info" step to emit `ImageVersion`/`ImageOS` (bare
runners) and the resolved image digest (container legs), feeding the existing effective-
runtime receipt line (#485 already commissions "runtime toolchain/image identity in the
existing run evidence" — this completes it for the bare-runner legs).

## 7. Proposed matrix and #488 disposition

### Matrix proposal (per-leg)

| Leg | Disposition | Rationale |
|---|---|---|
| `macos-release`, `linux-release`, `windows-release` | **Keep, gating, unchanged shape** | Darwin correctness / only optimizer gate / only SIL-asserts gate. Windows never relaxed (ruled). |
| quality gates (`format`, `lint`, `swift-linter`) | Keep, gating | Unchanged. |
| `linux-6-4` | Keep per-push advisory; **digest-pin, advanced deliberately**; graduate to gating `swift:6.4` at GA as planned | Upcoming-release signal earns per-push frequency; identity must stop floating. |
| `linux-nightly` (main) | **Move from per-repository full tier to a scheduled canary sweep** over a ruled canary set; keep digest-pinned | Upstream-shaped signal; removes the exception from every consumer's plan path. |
| `embedded` | Keep advisory; **bind the main-nightly digest** (one main-nightly identity) | Ends the second floating identity. |
| `embedded-wasm-sdk`, `android-build`, `static-linux-musl-build` | Keep advisory per existing soak criteria | At parity with upstream's opt-in set. |
| `apple-simulator-build` | Keep advisory per soak protocol | Only CodeSign-phase gate. |
| Exception semantics | **Advisory-class exception expiry ⇒ deschedule + typed alert; gating-class (release floor) expiry stays fail-closed** | Finding 1 — the structural fix. |
| Recording | Emit resolved `ImageVersion`/`ImageOS`/digest per leg | Finding 4. |

### #488 disposition

Do **not** move the recheck to 2026-09-20. A date move preserves the mechanism that
manufactures cliffs and merely relocates this one past launch day; the next upstream defect
re-creates it. Instead:

1. Land the Finding-1 semantic change in `institute-ci` (+ the Finding-5 canary sweep if
   ratified) **before 2026-09-01**. The 09-14 date then stays where it is and becomes an
   alert threshold, not an outage; the cliff disappears entirely.
2. `ReleaseFloorException`'s 2026-09-09 cliff is the genuinely load-bearing one (it guards
   gating-leg identity and is typed-bounded to the RC/stable boundary) and is *earlier*
   than #488's. Any launch-window CI freeze planning should key on 09-09, not 09-14.
3. #488's two mechanical residues (stale `linux-nightly` dispatch enum entry; three
   hardcoded 'Swift 6.3' advisory job names) are unaffected and remain a small follow-up
   PR; the canary-sweep proposal, if ratified, retires the enum-entry question by removing
   the leg from the universal.

All changes are proposal-only pending a principal ruling; no workflow was modified by this
research session.

## 8. Postscript — principal corrections (2026-08-10, same day)

Two findings above are recalibrated by principal feedback received after the initial draft;
where they conflict, this section supersedes §4 and §5.

**§4 (nightly identity) narrowed.** Launch is keyed to Swift 6.4 GA, and no official
`swift:6.4` image exists yet — targeting nightlies is the point, not a defect. For
*advisory* legs whose purpose is tracking the approaching release (`linux-6-4`, `embedded`),
auto-advancing mutable tags may be the desired semantics; the requirement drops from
"digest-pinned, advanced deliberately" to **"tracked and recorded"**: each run records the
digest its tag resolved to, so the environment is recoverable even though it floats. Gating
legs are unaffected — they already ride the digest-pinned release-floor exception. The
`embedded`-vs-exception dual-identity observation stands as a recording concern, not a
pinning demand.

**§5 (canary sweep) withdrawn.** Public repositories have unlimited Actions minutes, and
the main-nightly leg is Linux-only, full-tier only, and scheduled off-peak — it does not
contend with the binding macOS concurrency budget. Full-fleet coverage also answers *which*
packages break, not merely *that* upstream broke. Full-fleet nightly sweeps stay.

Findings 1 (exception-expiry semantics — the #488 fix), the upstream-posture conclusion,
Finding 4 (image-version recording), and the §7 disposition (no date move; land the
semantic change before 2026-09-01; freeze keys on 2026-09-09) are unchanged.
