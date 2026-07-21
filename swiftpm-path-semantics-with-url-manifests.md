# SwiftPM Path Semantics with URL Manifests

<!--
---
version: 1.0.1
last_updated: 2026-07-21
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
changelog:
  - 1.0.1 (2026-07-21): adversarial verification round (steering session). Two omitted
    candidates fixture-refuted and recorded (§E4): env-conditional manifests (mesh-fatal
    remote-path-dep error; the suspected manifest-cache staleness did NOT reproduce —
    evaluation is env-keyed on 6.3.3) and checkout-symlink tampering (works on one build;
    lifecycle-less, excluded). The Package.resolved-untracked premise verified against all
    9 stack repos. Ranking unchanged; recommendation CONFIRMED.
  - 1.0.0 (2026-07-21): initial empirical study. Fixture-verified mechanism inventory
    (6.3.3 release + 6.4.x 2026-07-17 snapshot), marker-test evidence per candidate,
    ranked recommendation (edit-mode, hardened), routers-arc mid-flight verdict (no switch).
---
-->

## Context

The workspace is ~30 independent repos whose committed manifests declare canonical
URL dependencies (`https://github.com/<org>/<repo>.git`, `branch: "main"`) per
[PKG-DEP-009]; a global mirror table (`~/.swiftpm/configuration/mirrors.json`,
1,232 entries at write time) redirects every URL to the sibling local checkout.
The established finding — re-verified here, not assumed — is that mirrors localize
FETCHING but not REVISION SELECTION: a consumer builds the commit pinned in its
`Package.resolved`, so every upstream change costs a `swift package update` per
consumer. The currently ruled workaround is per-consumer, per-dep
`swift package edit <dep> --path <local>` ("edit-mode"), adopted by the live
url-routing migration plan (v1.5.0, "edit-mode build posture").

This study asks whether anything beats edit-mode under the workspace's hard
constraints, and hardens the winner with an exact runbook.

**Skills loaded** (per [RES-033]): swift-institute-core, swift-institute,
swift-package, swift-package-build, existing-infrastructure, research-process.

**Hard constraints** (violations disqualify):

1. `Package.resolved` is generated-only — never hand-edited, never deleted to force
   advancement ([PKG-BUILD-013] pin discipline).
2. No committed path dependencies; no mixed URL spellings ([PKG-DEP-009], catalog §A26).
3. One manifest per package ([PKG-DEP-011]); no tools-version bumps; canon toolchain
   Swift 6.3.3 (`TOOLCHAINS=org.swift.633202606251a`, asserted per [PKG-BUILD-022]).
4. Evidence fidelity: plain per-package `swift build` / `swift test` from the
   package's own checkout remains the gate vehicle. (An Xcode workspace was already
   REJECTED for gates on evidence-divergence grounds; nothing found here contradicts
   that rejection — see §Root workspace package, which fails on the same axis.)

## Question

How do we get path-based dependency semantics — every consumer builds and tests
against the live local working trees of its dependencies — across the multi-repo
workspace, while every `Package.swift` keeps its normal URL dependencies and no
`Package.resolved` is hand-edited? Rank the mechanisms; recommend one with a runbook.

## Method

Empirical, fixture-based; no real workspace repo was built, resolved, edited, or
modified (a live migration held several of them). All probes ran on throwaway
packages under the session scratchpad with an **isolated** SwiftPM scope:
`--config-path <fixture>/config` (fixture `mirrors.json`) and
`--cache-path <fixture>/cache` on every command. The real global mirror table was
never touched.

**Toolchains** (asserted, not assumed): `TOOLCHAINS=org.swift.633202606251a` →
`Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)`; snapshot probes under
`TOOLCHAINS=org.swift.64202607171a` → `Apple Swift version 6.4-dev` (+assertions).
[Verified: 2026-07-21]

**Fixture**: three local git repos wired like the workspace —

- `fix-a` — leaf; `public enum FixA { public static let marker = "A-v1" }`.
- `fix-b` — URL dep on `https://github.com/fixture-org/fix-a.git`, `branch: "main"`;
  exposes `FixB.marker` and `FixB.aSeenByB` (returns `FixA.marker` — the transitive probe).
- `fix-c` — URL deps on both; an executable printing all three markers and a
  swift-testing test target printing the same.

Fixture `mirrors.json` maps both URL spellings of each dep to the local repo path
(absolute path, same shape as the real global table).

**Marker technique**: change the string constant in a dependency's WORKING TREE
(uncommitted), rebuild the consumer, and read which value the binary/tests print.
That is the decisive test for path semantics.

## Mechanism inventory (what exists, verified on the installed toolchains)

Enumerated from `swift package --help` + subcommand help on both toolchains,
`SWIFTPM_*` strings in the `swift-package` binaries, the SwiftPM CHANGELOG, and a
forums sweep. [Verified: 2026-07-21]

| Mechanism | Surface | Revision selection | Candidate? |
|---|---|---|---|
| Mirrors | `config set-mirror`, shared/local `mirrors.json`, `SWIFTPM_MIRROR_CONFIG` env var | Pin from `Package.resolved` (fetch-only localization) | Baseline (iii) |
| Edit-mode | `swift package edit <id> [--path]` / `unedit` | Live working tree (with `--path`) | Ruled baseline (i) |
| Root workspace package | uncommitted local package with `path:` deps; root-local identity override | Live working trees, whole graph | Candidate (ii) |
| Per-dep update | `swift package update <id>` | Moves pin to branch HEAD; re-resolves whole graph | Part of (iii) |
| Registry redirection | `--default-registry-url`, `--replace-scm-with-registry` | Published versions only | Analysis-only |
| Pin enforcement | `--force-resolved-versions`, `--skip-update` | Pins (opposite direction) | No |
| Traits / toolsets / SBOM etc. | — | Unrelated to revision selection | No |

**Nothing newer than edit/mirrors exists or is imminent.** The 6.4.x snapshot's CLI
delta vs 6.3.3 is: `swiftbuild` becomes the default build system (native/xcode
deprecated), `add-target-plugin`, `generate-sbom`, code-size profiling flags — no
dependency-override flag, no workspace feature. The binary's env-var surface adds
only SBOM/test-runner vars. The CHANGELOG lists nothing in the override class since
mirrors (5.6). Forums pitches in this space ([multi-package repositories][mpr],
[manual dependency management][mdm], [resolve-packages productivity][rpp]) are old
and unlanded. `SWIFTPM_MIRROR_CONFIG` was fixture-verified as a working per-process
mirror scope (a resolve with a fresh cache and no matching global entries succeeded
purely via the env var) — useful for hermetic experiments and per-session mirror
tables, but it is still fetch-localization, not revision selection.

Excluded up front by the hard constraints: hand-editing or deleting
`Package.resolved` (constraint 1), committed `path:` deps (constraint 2 and
[PKG-BUILD-015] — a url-resolved package cannot even carry them), Xcode workspaces
(constraint 4, previously rejected), suffixed-basename worktree meshes
([PKG-BUILD-014] — identity is the directory basename).

## Fixture evidence

Commands abridged to the operative parts; `FLAGS` = `--cache-path <fixture>/cache
--config-path <fixture>/config`; all under `TOOLCHAINS=org.swift.633202606251a`
unless stated. Full transcript reproducible from the commands shown.

### E0 — Mirrors baseline (candidate iii): fetch localized, revision pinned

```console
$ cd fix-c && swift run $FLAGS fixc-cli
C sees: FixA.marker=A-v1 FixB.marker=B-v1 aSeenByB=A-v1
# Package.resolved: fix-a @ 218fa7e (= fix-a main HEAD), kind "localSourceControl",
# location still the canonical URL.
```

1. **Uncommitted working-tree change in A** (`A-v1` → `A-v2-UNCOMMITTED`), plain
   rebuild of C: `C sees: FixA.marker=A-v1` — **invisible**. [Verified: 2026-07-21]
2. **Committed in A** (HEAD → `999d3a3`), no update in C, plain rebuild:
   `C sees: FixA.marker=A-v1`; pin still `218fa7e` — **invisible**. The established
   finding is CONFIRMED: mirrors localize fetching, not revision selection.
   [Verified: 2026-07-21]
3. **`swift package update fix-a` in C**: pin → `999d3a3`, marker now the committed
   content. Wall time 3.9 s on a 2-dep fixture graph — and the "scoped" update
   still walked and updated `fix-b` too: **per-dep update re-resolves the whole
   graph**, which is exactly why this is unacceptably slow at the institute's
   ~300-package graph scale (manifest toll per [PKG-BUILD-017]/[PKG-BUILD-018]),
   per consumer, per upstream change. [Verified: 2026-07-21]

### E1 — Edit-mode (candidate i): true path semantics through the consumer's graph

```console
$ swift package $FLAGS edit fix-a --path <repos>/fix-a     # 0.3 s (fixture scale)
$ sed … marker → "A-v3-EDITMODE-UNCOMMITTED" (uncommitted in A's tree)
$ swift run $FLAGS fixc-cli
C sees: FixA.marker=A-v3-EDITMODE-UNCOMMITTED FixB.marker=B-v1 aSeenByB=A-v3-EDITMODE-UNCOMMITTED
$ swift test $FLAGS
TEST sees: FixA.marker=A-v3-EDITMODE-UNCOMMITTED … — 1 test passed
```

- **(a) Uncommitted visibility: YES**, in both `swift run` and `swift test`, and
  **transitively within the consumer's graph**: `aSeenByB` shows the edited A
  through B's URL-declared dep (one `fix-a` node in C's graph). [Verified: 2026-07-21]
- **(d) Per-package `swift test` works unchanged** — the gate vehicle is intact.
- **(e) State left behind**: `Packages/<dep>` symlink → the live working tree;
  `edited` entry in `.build/workspace-state.json`; `Package.resolved` is
  REGENERATED by SwiftPM minus the edited dep's pin (generated-only lifecycle
  preserved — `Package.resolved` is untracked in all 9 routers-stack repos
  [Verified: 2026-07-21, `git ls-files` per repo], so the regeneration produces
  zero tracked diff).
  With ALL deps edited, SwiftPM deletes `Package.resolved` entirely (SwiftPM's own
  action, not a hand deletion). [Verified: 2026-07-21]
- **Teardown**: `swift package unedit fix-a` removes the symlink, PRESERVES the
  (dirty) working tree, regenerates the pin, and leaves an empty `Packages/` dir.
  No silent pin advance: with A's `main` advanced to `db218aa` during the edit,
  unedit restored `999d3a3` (resolution served from the un-refreshed local clone
  state — a later explicit `update` is still what moves pins). [Verified: 2026-07-21]
- **(f) Transitive limitation**: an intermediate package built from its OWN
  checkout is blind to the consumer's edit state. `fix-b` built standalone
  resolved its own `Package.resolved` (fresh resolve → branch HEAD) and its
  `.build/checkouts/fix-a` held committed content only. Each consumer that must
  see live upstreams needs its own edits. [Verified: 2026-07-21]

**Footgun 1 — `edit` without `--path` is a trap.** It creates a REAL CHECKOUT COPY
under `Packages/<dep>` at the pinned revision (probe: copy contained the committed
marker while the live tree held `A-v5-INCR`; `test -L` = not a symlink). Changes
made there diverge from the sibling repo. `--path` is mandatory for path
semantics. [Verified: 2026-07-21]

**Footgun 2 — `rm -rf .build` silently drops edit-mode.** Edit state lives in
`.build/workspace-state.json`. After `rm -rf .build` (the [PKG-BUILD-010] clean
reflex), the next build re-resolved from pins: markers reverted to committed
content (A's live `A-v5-INCR` and B's uncommitted change both vanished from the
output), `workspace-state.json` showed both deps back at `sourceControlCheckout`,
and the stale `Packages/` symlinks REMAINED on disk, misleadingly suggesting the
edits were still active. Modern SwiftPM does NOT auto-detect `Packages/` contents
as edit state. Worse: because the all-edited state had (legitimately) removed
`Package.resolved`, the post-clean fresh resolve pinned branch HEADs — a silent
pin advance relative to the pre-edit state. [Verified: 2026-07-21]

**6.4 forward-compat**: edit + build green under the 2026-07-17 6.4.x snapshot.
[Verified: 2026-07-21]

### E2 — Uncommitted root workspace package (candidate ii): full path semantics, wrong vehicle

An uncommitted directory outside all repos, `wsroot/Package.swift` declaring
`.package(path:)` on `fix-a`, `fix-b`, `fix-c` plus one probe executable importing
FixA/FixB. Uncommitted markers planted in A's and B's trees.

```console
$ cd wsroot && swift run --config-path <EMPTY> --cache-path <fresh> wsroot-cli
warning: 'fix-b': Conflicting identity for fix-a: dependency
  'github.com/fixture-org/fix-a' and dependency '<abs-path>/repos/fix-a' both point
  to the same package identity 'fix-a'. … This will be escalated to an error in
  future versions of SwiftPM.
ROOT sees: FixA.marker=A-v3-EDITMODE-UNCOMMITTED FixB.marker=B-v2-ROOT-UNCOMMITTED aSeenByB=A-v3-EDITMODE-UNCOMMITTED
```

- **(a) Uncommitted visibility: YES, whole graph**, including transitively through
  B's URL-declared dep — root-local path deps override same-identity transitive
  URL deps. Strikingly, this worked with an **EMPTY config** (no mirrors at all)
  and no network: the override preempts fetching entirely. No `Package.resolved`
  is created (path-only graph — nothing to pin). [Verified: 2026-07-21]
- **(d) Gate vehicle: FAILS.** `swift test` from the root builds only the root's
  (empty) test set — `error: no tests found`. Dependency executables are not
  runnable either: `error: no executable product named 'fixc-cli'`
  (`show-executables` lists only root products). SwiftPM has no "run a
  dependency's tests" concept. Per-package `swift test` from each repo's own
  checkout remains pin-based (E0), so gates through the root are a DIFFERENT
  vehicle than the per-package gates — the same evidence-divergence class for
  which the Xcode workspace was rejected. [Verified: 2026-07-21]
- **(g) Forward-compat liability**: the conflicting-identity diagnostic says
  outright it "will be escalated to an error in future versions of SwiftPM". Still
  a warning on the 6.4.x 2026-07-17 snapshot, but this mechanism sits on a
  deprecation path. [Verified: 2026-07-21]
- **(e) State**: nothing in any consumer repo (the root dir is wholly external) —
  the cleanest footprint of all candidates.

### E3 — Registry redirection (candidate iv, analysis-only)

A local registry (`--default-registry-url` + `--replace-scm-with-registry`) serves
PUBLISHED VERSIONS; revision selection is version resolution against published
artifacts, so uncommitted working trees are structurally invisible — it fails (a)
before any infrastructure cost (registry server, publish step per change) is
counted. Not fixture-tested; disqualified analytically. (Direction, not premise,
per [RES-027] — see Residual.)

### E4 — Adversarial verification round (steering session, 2026-07-21): two omitted candidates, both refuted

Run after v1.0.0 on a fresh A→B→C fixture under the same isolation discipline
(scratchpad repos, `--config-path`/`--cache-path` scope, asserted 6.3.3, no real
repo or global config touched). [Verified: 2026-07-21]

**E4a — Env-conditional manifest** (`Package.swift` reads an environment variable
and declares `path:` deps when set, URL deps otherwise — the widespread folk
technique this study originally omitted):

- **Works as a single ROOT**: with the var set, the consumer sees uncommitted
  working-tree content directly AND transitively (root path deps override
  same-identity transitive URL deps), and `swift test` works — for one root
  package this TIES edit-mode's semantics.
- **The suspected killer did not reproduce**: manifest evaluation IS
  environment-keyed on 6.3.3. Every var flip freshly re-evaluated (no
  `swift package reset` needed) — at the cost of a full re-resolve + dep
  recompile + `Package.resolved` churn per flip (deleted in live mode,
  regenerated pinned otherwise).
- **MESH-FATAL, the actual disqualifier**: once an INTERMEDIATE package's
  manifest goes conditional and that package is consumed by URL, resolution with
  the var set hard-fails: `error: package 'fix-b' is required using a
  revision-based requirement and it depends on local package 'fix-a', which is
  not supported` (exit 1). Liveness is all-or-nothing along any dependency
  chain; any mixed remote-with-var state fails. Extra trap: before the branch
  pin advances past the conditional-manifest commit, the var appears to work
  while silently building the stale pinned manifest.
- Also violates constraint 2 textually (committed `path:` spellings, however
  gated). **Refuted for mesh use; edit-mode strictly dominates.**

**E4b — Checkout-symlink tampering** (replace `.build/checkouts/<dep>` with a
symlink to the live working tree): a rebuild DOES compile the symlinked tree's
uncommitted content, transitively, exit 0, symlink left intact. Refuted anyway:
it is out-of-band mutation of SwiftPM-owned state with no registration anywhere
(`workspace-state.json` still says `sourceControlCheckout`), no teardown story,
and unknown durability across re-resolutions — a strictly worse version of
Footgun 2's invisible-state class. Recorded so it is not rediscovered as a
"trick"; excluded under constraint 1's spirit (generated state is SwiftPM's).

## Scored comparison

Criteria: (a) consumer sees uncommitted working-tree changes; (b) setup+teardown
cost across ~10 repos; (c) per-change incremental cost; (d) per-package
`swift test` unchanged; (e) state left behind / git hygiene; (f) transitive
behavior; (g) failure modes.

| Criterion | (iii) Mirrors + update | (i) Edit-mode (`--path`) | (ii) Root workspace pkg | (iv) Registry |
|---|---|---|---|---|
| (a) Uncommitted visible | ✗ (pin-based; re-verified) | ✓ (run + test) | ✓ (whole graph) | ✗ structural |
| (b) Setup / teardown | none / none | 1 cmd per dep per consumer (~0.3–2 s fixture; graph-resolution toll at scale) + unedit each | one external dir, once | registry server + publish pipeline |
| (c) Per-change cost | `update` per consumer = whole-graph re-resolution (3.9 s fixture; minutes at workspace scale) | plain incremental build only | plain incremental build only | publish + update per change |
| (d) Per-package `swift test` gate | ✓ but against pins | ✓ against live trees | ✗ — cannot run dependency tests/executables | ✓ but against versions |
| (e) State left behind | none | `Packages/` symlinks, workspace-state, regenerated (gitignored) `Package.resolved` | none in any repo | registry data |
| (f) Transitive | n/a | ✓ within each edited consumer's graph; standalone intermediates need own edits | ✓ fully | n/a |
| (g) Footguns | staleness invisible by design | no-`--path` trap; `rm -rf .build` silently drops edits + stale symlinks + possible pin advance | deprecation-marked identity override; not a gate vehicle | heavy, slow |
| **Hard constraints** | passes but fails the mission (no path semantics) | **passes all** | fails constraint 4 (gate vehicle) | fails mission |

## Outcome

**Status**: RECOMMENDATION

**Ranking**:

1. **Edit-mode with `--path`, hardened (RECOMMENDED)** — the only mechanism that
   delivers working-tree semantics while keeping per-package `swift build` /
   `swift test` from each package's own checkout as the gate vehicle, with all
   hard constraints intact. The current ruling stands; what was missing is the
   hardening below (two verified footguns).
2. **Root workspace package** — strictly better path semantics (whole graph, zero
   consumer-repo state, no mirror dependence) but disqualified as a gate vehicle:
   dependency tests cannot run through it, and the identity override it relies on
   is deprecation-marked. Legitimate only as an OPTIONAL whole-stack compile
   smoke (fast "does the whole stack still compile against live trees" signal),
   never as evidence.
3. **Mirrors + per-consumer `update`** — the correct steady-state for NON-live
   work (pins are reproducibility), but not path semantics; per-change cost is a
   whole-graph re-resolution per consumer.
4. **Registry redirection** — structurally incapable of working-tree semantics.
5. **Env-conditional manifests / checkout-symlink tampering** — refuted in the
   E4 adversarial round: the former is mesh-fatal (remote packages cannot carry
   path deps) and textually violates constraint 2; the latter is lifecycle-less
   tampering with SwiftPM-owned state. Neither changes the ranking.

### Runbook (edit-mode, hardened)

All commands run from the CONSUMER package's own checkout, under the asserted
canon toolchain (`TOOLCHAINS=org.swift.633202606251a`; assert
`swift-6.3.3-RELEASE` per [PKG-BUILD-022]).

**Setup — once per consumer, per live-tracked upstream** (repeat per consumer in
the stack; `<org-root>` per the workspace resolution table):

```bash
# ALWAYS pass --path; without it SwiftPM makes a divergent checkout COPY.
swift package edit <dep-identity> --path <org-root>/<dep-repo>
```

Scripted form for a consumer tracking several upstreams:

```bash
# edit-live.sh <dep-repo>... — run from the consumer's checkout
for dep in "$@"; do
  swift package edit "$(basename "$dep")" --path "$dep"
done
```

**Per-day use**:

- Edit upstream working trees freely (uncommitted included); plain `swift build` /
  `swift test` in the consumer picks them up — no `update`, no re-resolution.
- **After ANY `rm -rf .build`** ([PKG-BUILD-010] clean reflex): edit state is GONE
  even though `Packages/` symlinks remain. Re-run the edit commands before
  trusting the next build. Detection probe (empty output = healthy; any line =
  stale symlink or missing edit):

```bash
# edit-status.sh — compare live edit state vs Packages/ symlinks
comm -3 \
  <(python3 -c "import json;print('\n'.join(sorted(d['packageRef']['identity'] for d in json.load(open('.build/workspace-state.json'))['object']['dependencies'] if d['state']['name']=='edited')))" 2>/dev/null) \
  <(ls Packages 2>/dev/null | sort)
```

- Gate evidence remains: per-package `swift build` / `swift test` from each
  package's own checkout. A consumer whose gate must run against PINNED deps
  (publication gates, pin-assert clean-rooms per [PKG-BUILD-013]) must unedit
  first — edit-mode greens are live-tree greens by design; label them as such.

**Teardown — per consumer**:

```bash
swift package unedit <dep-identity>    # per edited dep; preserves the working tree
rmdir Packages 2>/dev/null || true     # unedit leaves an empty Packages/ dir
# Verify: Package.resolved regenerated; pins unchanged unless you ran `update`.
```

Then, to actually ADVANCE a consumer onto committed upstream work (the normal
end-of-arc step): `swift package update <dep>` (accepting the whole-graph
re-resolution cost, once, deliberately).

**Invariants the runbook preserves**: manifests untouched (URL form, one manifest);
`Package.resolved` only ever written by SwiftPM; no committed path deps; per-package
gates unchanged in vehicle; teardown leaves zero diff in tracked files.

### Should the live routers arc switch mid-flight?

**No — there is nothing to switch to.** The bar was "only if strictly better than
edit-mode AND switchable in under ~30 minutes." No mechanism is strictly better:
the only candidate with superior path semantics (root workspace package) fails the
gate-vehicle constraint outright and rides a deprecation-marked override. The arc's
ruled edit-mode posture is CONFIRMED as optimal under the constraints.

Two additive adoptions are recommended for the arc — they harden, not switch, and
cost minutes: (1) the **post-clean re-edit guard** (`rm -rf .build` silently drops
edit state; re-run edits + `edit-status.sh` probe) — adopt IMMEDIATELY, since the
arc combines edit-mode with clean-build discipline and is exposed to Footgun 2
today; (2) the optional root-package whole-stack compile smoke — defer to post-B8;
it is auxiliary signal, not evidence, and adds a second vehicle mid-arc for no
gate value.

## Residual

**Premises (verified here, none outstanding).** All load-bearing claims above were
fixture-verified this session on both installed toolchains.

**Directions (not load-bearing; no experiment owed per [RES-027])**:

- The conflicting-identity warning's promised escalation to an error (affects only
  the auxiliary root-smoke pattern and [PKG-BUILD-014]-class overrides; re-check at
  the 6.4 release gate).
- SwiftPM workspace/override pitches remain unlanded; if a first-class dependency
  override ships, re-run E0/E1 probes against it.
- Registry-based local development was disqualified analytically, not empirically;
  only worth revisiting if the institute ever operates a package registry.

## References

- Fixture + transcripts: session scratchpad (throwaway; commands reproduced inline above).
- [PKG-BUILD-010] / [PKG-BUILD-013] / [PKG-BUILD-014] / [PKG-BUILD-015] /
  [PKG-BUILD-017] / [PKG-BUILD-018] / [PKG-BUILD-022] — swift-package-build skill.
- [PKG-DEP-009] / [PKG-DEP-011] — swift-package skill; catalog §A26 (identity-conflict hang).
- `versioning-and-release-strategy.md` — governing doc for the URL-form pin model this study leaves untouched.
- `url-routing-stack-migration-plan.md` v1.5.0 — the live arc's edit-mode build posture.
- [SwiftPM CHANGELOG](https://github.com/swiftlang/swift-package-manager/blob/main/CHANGELOG.md) — no override-class feature since mirrors (5.6). [Verified: 2026-07-21]
- [mpr]: https://forums.swift.org/t/spm-multi-package-repositories/43193 — unlanded pitch.
- [mdm]: https://forums.swift.org/t/swiftpm-manual-dependency-management/6362 — historical thread.
- [rpp]: https://forums.swift.org/t/swiftpm-how-to-prevent-resolve-packages-from-stymying-developer-productivity-local-packages/63363 — historical thread.
