# Repo-Shape Reduction, History Pruning, and Release-Squash Ruling Package

<!--
---
version: 1.0.0
last_updated: 2026-08-10
status: RULING-PACKAGE (awaiting principal ratification)
research_tier: 2
applies_to: [primitives, standards, standards-suborgs, foundations, institute]
normative: false
---
-->

## Context

Commissioned by the principal 2026-08-10 via the Launch coordinator. Four directives to
design for:

1. Primitives, standards (plus suborgs), and foundations each get a **uniform, maximally
   reduced repository shape** — only essential files.
2. `Research/` and `Experiments/` directories inside packages **transfer** to
   `swift-institute/Research` and `swift-institute/Experiments`.
3. The principal leans to **force-pruning each package's git history** to remove any file
   not in the final whitelist (exceptions apply, e.g. generator-based standards packages).
4. The **release-history squash** is to be explored (not yet ruled): max 3 commits —
   initial commit, initial public commit, initial tag commit — with specific attention to
   the issue corpus: what happens to issues/PRs/receipts that cite commit SHAs.

This is exploration and design only. History rewriting and pruning are
**principal-execution-only** operations; the never-force-push rule stands for everyone
else.

## Evidence boundary

- **Full tracked-file census** of every repository under the three layer checkout roots:
  L1 209/209, L2 114/114 (all suborg directories included: swift-ietf ~48, swift-iso 12,
  swift-w3c 6, swift-whatwg 2, swift-microsoft 2, swift-ieee 2, swift-iec 2,
  swift-arm-ltd, swift-ecma, swift-incits, swift-intel, swift-linux-foundation), L3
  155/155 — 478 repositories, plus the institute control-plane repos. Method:
  `git ls-files` per repo, aggregated on first path component. This census is a
  point-in-time snapshot; the mechanical successor is the whitelist-gitignore rule and
  census tracked at swift-foundations/swift-institute-linter-rules#68 (no census landed
  there as of 2026-08-10; when it lands, it supersedes §1's numbers).
- **Issue-corpus sample**: 20 full issue conversations (bodies + all comments) across
  swift-institute, swift-primitives, swift-standards, swift-foundations, swift-ietf,
  mixing receipt-style closed issues, open engineering issues, and coordinator issues.
  Positive controls confirmed search liveness in every org queried.
- **Empirical GitHub link-survival tests** (2026-08-10) against (a) the 2026-08-09
  fresh-history republication pair `swift-institute/institute-continuous-integration` and
  its history companion, and (b) squash-merged PR heads with deleted branches in three
  fleet repos. Every claim in §4 is backed by an executed API call, URL fetch, or
  `git fetch`; the one untested case is explicitly flagged there.
- **Not measured**: consumer manifests inside the swift-institute org (code search is
  blind on that org — positive control returned zero); the eventual #68 mechanical
  census; GC timing for ref-less orphans (GitHub does not expose it).

---

## 1. Essential-file manifest per repository class

### 1.1 What repositories carry today

The 10-path core is already near-universal across all three layers (≥92% each):

| Path | L1 (n=209) | L2 (n=114) | L3 (n=155) |
|---|---:|---:|---:|
| `.github/` (`metadata.yaml`, `workflows/ci.yml`) | 100% | 99% | 99% |
| `Package.swift`, `Sources/`, `Tests/` | 99% | 98% | 98–99% |
| `.gitignore` | 99.5% | 99% | 100% |
| `Lint.swift` | 99.5% | 98% | 92% |
| `.swiftlint.yml` | 99.5% | 98% | 99% |
| `.swift-format` | 98.6% | 95% | 94% |
| `README.md` | 98.6% | 97% | 98% |
| `LICENSE.md` | 98% | 96% | 94% |

Divergent carriage: `Research/` 91 L1 / 6 L2 / 49 L3 repos (146 total); `Experiments/`
48 / 3 / 8 (59 total, one casing violation: lowercase `experiments/` in
swift-order-primitives); `Benchmarks/` 15 L1 + 1 L3; `.spi.yml` 4% L1 / 75% L2 / 36% L3;
`dependabot.yml` 77–94%; `FUNDING.yml` 1% L1 / 66% L2 / 25% L3. `.spi.yml` and
`FUNDING.yml` track publication status, not layer policy.

Long tail (paths in <3 repos — the disposition candidates): stray root markdown
(`ARCHITECTURE.md`, `MIGRATION*.md`, `TESTING.md`, `HISTORY.md`, `TOMBSTONE.md`, …,
concentrated in L3), committed build artifacts (`build_output.txt` in
swift-stripe-standard, `output-*.png` in swift-image-magick), tooling drift
(`Makefile` ×2, `.editorconfig`, `.swiftformat`), one shell script, `Parked/` ×2,
`Example(s)/` ×2, `Documentation/` ×1, `Runner/` ×1, a quote-prefixed `"Sources/` path in
swift-bit-primitives (bad `git add`), fork-heritage license trios
(`LICENSE.txt`/`NOTICE.txt`/`CONTRIBUTORS.txt` in swift-iso-8824/-8825,
swift-certificate-verification), and one-off workflows and scripts inside `.github/`.

**Zero repos commit `Package.resolved`. Zero layer repos track `CLAUDE.md`/`AGENTS.md`.**
Both disciplines already hold fleet-wide.

### 1.2 The whitelist already defines the shape

430 of 478 repos carry one byte-identical canonical whitelist `.gitignore`
(ignore-everything-at-root, then explicit `!/…` opt-ins). The long tail exists only
because `.gitignore` does not untrack files committed before the whitelist landed. The
shape problem is therefore not a policy design problem — it is a **convergence** problem:
`git rm --cached` the residue, tighten the whitelist, and add the mechanical rule (#68).

### 1.3 Proposed uniform manifest

**Package class** (all of L1, L2 including suborgs, L3) — exactly:

```
Package.swift            required
Package@swift-*.swift    permitted where a version split exists
Sources/                 required
Tests/                   required
Benchmarks/              permitted (16 repos today)
Lint.swift               required
.gitignore               required (canonical whitelist)
.swift-format            required
.swiftlint.yml           required
README.md                required
LICENSE.md               required (single spelling; see disposition table)
.spi.yml                 permitted (publication-gated)
.github/metadata.yaml    required
.github/workflows/ci.yml required (the one-hop generated caller; no other workflows)
.github/dependabot.yml   required
.github/FUNDING.yml      permitted (publication-gated)
```

Nothing else. In particular **no** `Research/`, `Experiments/`, `Skills/`, `Scripts/`
(exception: §5), `Docs/`, root markdown beyond README/LICENSE, `CHANGELOG.md`,
`CODE_OF_CONDUCT.md`/`CONTRIBUTING.md`/`SECURITY.md` (those live in each org's `.github`
profile repo and apply org-wide), extra workflows, or `.github/scripts`.

**Org profile repos** (`<org>/.github`) keep their distinct shape: `profile/`,
community-health files, `metadata.yaml`; `swift-institute/.github` additionally owns the
control-plane workflows and issue forms.

**Control-plane and document repos** (institute, institute-application,
institute-continuous-integration, institute-pull-request-transaction, Research,
Experiments, Internal, Issues, Skills, Workspace) are **out of scope** for the uniform
package manifest; they get a per-repo shape ruling instead (§5). Notably
institute-pull-request-transaction today lacks README, LICENSE, `.gitignore`, and
`.github/` entirely, and institute-continuous-integration lacks LICENSE — the two least
conformant repos in the fleet and the first targets for a control-plane shape definition.

### 1.4 Disposition of everything else

| Today's content | Disposition |
|---|---|
| `Research/` in 146 repos | Transfer to swift-institute/Research (§2) |
| `Experiments/` in 59 repos (incl. lowercase variant) | Transfer to swift-institute/Experiments (§2) |
| `Skills/` in 3 L1 repos | Transfer to swift-institute/Skills (same mechanics as §2) |
| Stray root markdown, `Parked/`, `Examples/`, `Documentation/`, `Runner/` | Judgment pass per file: salvageable analysis → Research transfer; superseded → delete (history retains it until pruning; §3 decides final fate) |
| Build artifacts, scripts, `.editorconfig`, `Makefile`, `.swiftformat`, quote-prefixed path | Delete (untrack) |
| Fork-heritage `LICENSE.txt`/`NOTICE.txt`/`CONTRIBUTORS.txt` | **Exception — keep.** Attribution obligations are load-bearing; do not collapse into `LICENSE.md` |
| `LICENSE` extensionless (9 repos), license spelling drift | Normalize to `LICENSE.md` |
| Generator `Scripts/` + `Sources/**/Generated/` in the three ISO repos | **Exception — keep** (§5) |
| One-off workflows (`swift-docs.yml`, `windows-*-repro.yml`, …), `.github/repro/`, `.github/scripts` | Per-item: still-live capability → move to its owner (swift-institute/.github or the owning issue); dead → delete |
| `CHANGELOG.md` (4 repos) | Delete; release history is the tag/release record, not a hand file |

---

## 2. Research/Experiments transfer design

### 2.1 Destinations

Both destinations exist: swift-institute/Research (public, flat kebab-case documents plus
project subdirectories, `_index.json`) and swift-institute/Experiments (public, one
directory per standalone verification package, `_index.json`, created 2026-04-17). No
repository creation is needed.

### 2.2 Layout in the destination

Package-scoped material must keep its provenance after centralization:

- **Research**: `Packages/<source-repo-name>/<original-filename>.md` (e.g.
  `Packages/swift-heap-primitives/heap-storage-variants.md`). Cross-package documents
  already at root stay at root. `_index.json` gains the transferred entries with a
  `source` field naming the origin repo.
- **Experiments**: experiments are standalone Swift packages and the repo is already one
  directory per experiment; transferred experiments land as
  `<source-repo-name>--<experiment-name>/` to prevent collisions (the flat namespace
  already carries similarly-shaped names). Normalize the one lowercase `experiments/`
  during transfer.

### 2.3 With or without history?

**With history, preserved in the destination — this is the load-bearing choice.**
`git filter-repo --subdirectory-filter` (per source repo, onto a prefix, then fetched and
merged into the destination with `--allow-unrelated-histories`) carries each file's
commit history into the destination repo. A plain copy would rely on the *source* repo's
history for provenance — and directive 3 intends to erase exactly that history. Under
pruning, the destination is the **only** place the intellectual history of 146 Research
corpora can survive. Doing 146 + 59 subtree extractions is mechanical and scriptable; the
per-repo cost is minutes.

Pragmatic tiering is acceptable: full history extraction for `Research/` (the provenance
is the value); plain copy for `Experiments/` is defensible (an experiment's value is its
current reproducing source, and its outcome is recorded in the research doc or issue that
cites it) — but since the same script handles both, uniform with-history transfer is
recommended.

Sequencing constraint: **transfers must land and be verified before any source-repo
history pruning**, since pruning destroys the only other copy.

### 2.4 Consequences to record

- The 2026-03 decision in `documentation-research-experiments-integration.md` (Research/
  and Experiments/ stay at package root; .docc articles reference them by relative link)
  is **superseded** by directive 2. Its relative-link convention breaks: any
  `## Research` / `## Experiments` sections in .docc articles using relative paths must
  be rewritten to absolute URLs into the central repos. A fleet grep for such links is
  part of the transfer wave.
- The canonical `.gitignore` whitelists `!/Research/`, `!/Experiments/`, `!/Skills/`,
  `!/Scripts/`; after the transfer wave these opt-ins are **removed** from the canonical
  file (generator repos get a local-override block instead), so the shape cannot
  regress silently.

---

## 3. History-pruning design

### 3.1 Secrecy vs cleanliness — the distinction, now with evidence

The two goals demand different mechanisms and must never be conflated:

- **Pruning for cleanliness** (uniform shallow history, no dead files in checkouts,
  smaller clones): an in-place rewrite + force-push achieves the *visible* result. But it
  removes nothing from GitHub: §4's empirical tests show every commit that ever transited
  a PR remains permanently browsable, API-servable, and fetchable via the immortal
  advertised `refs/pull/N/head` refs. Residual fetchability is **acceptable** for this
  goal.
- **Pruning for secrecy** (a credential, machine path, or private internal in history):
  in-place rewrite is **insufficient by construction**. The only mechanism that actually
  removes objects from every public surface is the **fresh-repo republication** used
  2026-08-09 for institute-continuous-integration and
  swift-github-continuous-integration: build the intended tree as a new root in a new
  repository, swap names, retain the old repository privately as `<name>-history`.
  Empirically (§4), the republished repo serves nothing of the old history: API 422, web
  404, `git fetch` → `not our ref`. A pushed exposure additionally remains a
  credential-rotation event regardless of mechanism.

Default ruling proposal: the fleet-wide operation is **cleanliness-class** and uses
in-place rewrite. Any repo where the pre-rewrite scan (mandatory, per repo: history-wide
scan for credentials, machine paths, private internals) finds secrecy-class residue is
escalated to the republication mechanism individually.

### 3.2 Prune and squash are one rewrite

Directive 3 (drop non-whitelist files from history) and directive 4 (≤3 commits) compose
into a single history construction — and squash-to-3 makes per-file pruning **moot**: a
squashed history contains only the trees attached to its ≤3 commits, and those trees are
built from the final whitelisted checkout. There is no need to `git filter-repo` paths
out of a history that is being discarded wholesale. The operation per repo is:

```
new root  = commit(tree = whitelisted final tree)          "initial commit"
(public)  = optionally the same commit, or a second commit  "initial public commit"
(tag)     = the commit the first release tag points to      "initial tag commit"
```

`git filter-repo` path-pruning is only needed under the **alternative** where history is
kept but cleaned — which the squash lean makes unnecessary. This is a significant
simplification: no per-path rewrite fidelity questions, no author-rewrite questions.

### 3.3 The three-commit semantics

The three named commits are lifecycle events, not content phases:

1. **Initial commit** — the whitelisted tree at rewrite time. For repos already public,
   commits 1 and 2 collapse (the repo is born public); the minimum is then 1–2 commits
   pre-tag.
2. **Initial public commit** — meaningful only for repos flipping private→public at
   launch; it is the tree as first published.
3. **Initial tag commit** — **cannot exist yet**: tagging is vestigial and per-standing
   ruling never authorized; the main-only/no-tags posture stands. The squash therefore
   lands as 1–2 commits now, and the tag commit is appended at first authorized release.
   The "max 3" shape is the *post-launch* steady state, not a day-one requirement.

Post-squash commits accumulate as normal development; "max 3" describes the floor of the
released history, not a cap enforced forever (a cap would require perpetual rewriting,
which contradicts never-force-push for everyone but the principal).

---

## 4. Empirical link survival, and squash impact on the issue corpus

### 4.1 What GitHub actually does with rewritten-away commits (measured 2026-08-10)

**Fresh-repo republication** (tested on the 2026-08-09 pair; old head `57c84739`,
confirmed absent from the new repo's history and present in the history companion):

| Surface | Result |
|---|---|
| `GET /repos/…/commits/57c84739` | HTTP 422 "No commit found for SHA" |
| `/commit/57c84739` web page | 404 (positive control on a live SHA: 200) |
| `/compare/57c84739...<live>` | 404 |
| `git fetch origin 57c84739` | `fatal: remote error: upload-pack: not our ref` |

**In-place unreachability** (tested on three squash-merged PR heads with deleted
branches, confirmed non-ancestors of main, across two fleet repos):

| Surface | Result |
|---|---|
| API commit object | 200, full object |
| `/commit/<sha>` web page | 200 |
| PR files page, `/compare/main...<sha>` | 200 |
| `git fetch <sha>` | succeeds |
| Mechanism | `git ls-remote 'refs/pull/N/*'` advertises `refs/pull/N/head` **permanently**; reachable-SHA fetch honored from those refs |

So: **every commit that ever transited a PR is immortal on GitHub** — force-push cannot
orphan it in any observable sense. Commits pushed **directly to main** (common in the
fleet: mechanical-central direct pushes) have no `refs/pull` anchor; after a force-push
they become true orphans. Known GitHub behavior (documentation, not measured here — the
fleet's no-force-push history means no natural specimen exists) is that such objects stay
API/web-servable until an opaque, non-triggerable server-side GC, and are not fetchable
by SHA. Treat direct-pushed SHAs as **surviving short-term, unguaranteed long-term**.

### 4.2 What the issue corpus actually cites (20-conversation sample)

| Reference form | Prevalence | Post-squash (in-place) | Post-republication |
|---|---|---|---|
| Bare SHAs in prose/titles ("drained head `26ec0b4…`") | Dominant: 100+ occurrences, 15/20 conversations; one conversation cites 43 distinct SHAs | PR-transited: resolvable forever. Direct-pushed: servable until GC, unguaranteed | Dead |
| Actions run URLs (mandatory closure receipts) | 21 occurrences, 6+ conversations | URL survives (numeric ID); run's `head_sha` and commit link dangle per the SHA's class above | URL survives only if issues stay on the surviving repo; runs do not transfer to a fresh repo |
| `org/repo@SHA` auto-links | 5 | as bare SHAs | Dead |
| Blob/tree permalinks pinned to SHA | 2 (both in the public Issues repo — compiler reproducers, likely cited upstream) | survive (PR-transited or reachable) unless that repo is rewritten | Dead |
| Full `/commit/` URLs, `/compare/` links | **0** | — | — |
| PR number links | common | survive (PRs are API objects); their stored head/base SHAs resolve per the SHA's class | PRs exist only on the old repo |
| Bot approval records | every reviewed merged PR: API `commit_id` pins exact head; review bodies repeat "Reviewed head: <sha>" | resolvable for PR-transited heads (they all are — review heads are PR heads by construction) | Dead on the new repo |

### 4.3 Assessment

Under the recommended **in-place squash**, the issue corpus survives far better than
feared: the fleet's citation style (bare SHAs + run URLs, zero commit URLs) references
objects that GitHub retains indefinitely for anything that went through a PR — including
every exact-head approval record. The genuinely at-risk class is **direct-pushed SHAs**
cited in receipts. What is *lost* even for surviving SHAs is **context**: the SHA
resolves to a commit page, but that commit is no longer in main's history, so "green at
drained head X" can no longer be verified as an ancestor claim — the receipt becomes
frozen provenance rather than live navigation. Closed receipts are already frozen by
convention (closure-evidence rulings), so this is acceptable; open issues citing
pre-squash SHAs need a one-time annotation.

Under **republication**, the entire corpus of that repo's issues, PRs, runs, and
approvals is severed or left behind; that cost is justified only by secrecy.

### 4.4 Mitigations (proposed)

1. **SHA-map manifest**: at rewrite time, record per repo `old-main-tip → new-root`,
   plus the old tip's tree hash (provable equality with the new root's tree). One fleet
   manifest, kept in swift-institute/Internal (it references nothing secret but is
   operational; Internal is the natural home), written by the rewrite script.
2. **Receipts frozen as provenance**: a standing note (one line in the github skill /
   issue-conventions doc), not 100k issue edits: "SHAs cited before 2026-0X-XX reference
   the pre-squash history; resolve via the SHA-map manifest." Annotate **open** issues
   only, mechanically (bot comment on open issues citing pre-squash SHAs), and leave
   closed receipts untouched.
3. **Pre-squash tip preservation**: no tags (never authorized) and no 478 `-history`
   repos. The refs/pull immortality already preserves PR-transited history. For the
   direct-pushed residue, the SHA-map manifest plus one **bundle archive** per org
   (`git bundle` of each repo's pre-squash main, stored in the principal's archival
   location, not on GitHub) is a complete, cheap, offline-recoverable record.
4. **Reproducer permalinks**: the two SHA-pinned tree permalinks live in
   swift-institute/Issues; exempt that repo from rewriting (§5) and they stay valid.

### 4.5 Consumers and pins

- **No `revision:` pins** in any consumer `Package.swift` where code search is live
  (positive controls passed per org). Blind spot: swift-institute org manifests need a
  clone-side grep before execution (small population). One known `branch: "main"`
  dependency (flagged during TX-APP1Z) is safe: branch deps track the tip.
- **`Package.resolved`**: generated, never committed (0 violators) — consumers
  re-resolve; stale local resolveds reference dead SHAs and fail until refreshed with
  `workspace`-mediated re-resolution. Expected, self-healing, worth one line in the
  wave announcement.
- **Superrepo submodule pointers**: the layer checkout superrepos pin subrepo SHAs;
  every pointer dangles at rewrite and must be bumped in the same wave (known recipe in
  `git-history-transfer-patterns.md`).
- **Existing clones and lanes**: every checkout's local main diverges at rewrite. The
  one-lane-per-checkout discipline means the wave must land in a **quiet window**: no
  open PRs (force-push invalidates PR branches), no active lanes in the affected trees,
  re-clone/hard-resync instructions issued after. This is the strongest argument for
  scheduling the wave as one bounded, principal-executed convergence event.

---

## 5. Exception roster

| Repo(s) | Exception | Reason |
|---|---|---|
| swift-iso-3166, swift-iso-639, swift-iso-15924 | Keep `Scripts/` (generator) + `Sources/**/Generated/`; keep whitelist opt-in locally | Sources are generated from authoritative external data; the generator is the source of change. These are the only three repos where provenance headers, `Generated/` dirs, and tracked `Scripts/` all correlate. (Weaker "generated" prose matches elsewhere were inspected and are doc-comment prose, not provenance.) |
| swift-iso-8824, swift-iso-8825, swift-certificate-verification | Keep `LICENSE.txt`/`NOTICE.txt`/`CONTRIBUTORS.txt` | Fork-heritage attribution obligations |
| swift-institute/Issues | **No history rewrite** | Public compiler reproducers with SHA-pinned tree permalinks, likely cited in upstream reports; history is load-bearing |
| swift-institute/.github | **No history rewrite**; shape ruling separate | Control-plane workflows, issue forms, approval history; the fleet's audit spine |
| Research, Experiments, Skills, Internal | **No history rewrite** | Research/Experiments become the *destination* of transferred history — pruning them defeats §2.3; Internal holds operational records incl. the SHA-map |
| institute, institute-application, Workspace | Defer to the Application/Launch programme | Active TX-APP2A/Foundation baton; institute-application history includes the recent flatten/split epoch that receipts cite; rewrite here needs the Foundation coordinator's sign-off |
| institute-continuous-integration, institute-pull-request-transaction | Already fresh-rooted (08-09) or newly seeded | Nothing to prune; bring to control-plane shape instead (add LICENSE/README/.github) |
| Repos failing the secrecy scan | Republication instead of in-place rewrite | §3.1 |

---

## 6. Staged execution plan

Stages 1–3 are ordinary PR-flow work executable by lanes. Stages 4–6 are
**principal-execution-only** (marked ▲). The vendor window and the 09-09 ceiling
(pre-authorized slide to 09-20 if Swift 6.4 stable is absent 2026-09-05; NightlyException
recheck cliff 2026-09-14) bound the calendar: the rewrite wave must complete **before**
the launch-week freeze, and the principal's lean (uniform at launch) is achievable if
stages 1–3 start immediately.

1. **Ratify this package** (principal): manifest §1.3, dispositions §1.4, transfer
   design §2, cleanliness-default §3.1, squash shape §3.3, mitigations §4.4, exceptions
   §5.
2. **Transfer wave** (lanes, PRs): extract Research/Experiments/Skills with history into
   the central repos (§2), verify, then remove the directories from source repos;
   long-tail judgment pass (§1.4); fix .docc relative links; land the tightened
   canonical `.gitignore` + local overrides for exception repos. Order within the wave
   is per-repo independent.
3. **Mechanical rule** (#68): whitelist-manifest rule reaches blocking maturity so the
   shape cannot regress; census from #68 supersedes §1.1.
4. ▲ **Secrecy scan** across all 478 histories (scripted, principal-reviewed): classify
   each repo cleanliness vs republication. Produce the bundle archives and the SHA-map
   manifest skeleton.
5. ▲ **Rewrite wave** (one bounded convergence event, quiet window: PR drain, lane
   stand-down): per repo, construct the 1–2 commit history from the whitelisted tree
   (§3.2), force-push (`--force-with-lease`), write the SHA-map entry; republication
   path for escalated repos; superrepo submodule pointer bump; open-issue SHA
   annotations (bot); fleet re-clone/resync directive.
6. ▲ **Tag commit** (per repo, at first authorized release, post-launch): appends the
   third commit of the §3.3 shape. Explicitly outside this package's authorization.

Stop conditions: (a) principal ratification of §1.3/§3/§4.4 before stage 2 touches any
repo; (b) clone-side grep of swift-institute-org manifests before stage 5; (c) Foundation
coordinator sign-off for the institute/institute-application exception row; (d) the #68
census, if landed before stage 2, re-baselines §1.1.

## Related ecosystem research

- `git-history-transfer-patterns.md` — transfer/squash recipes, redirect persistence,
  submodule-pointer recovery.
- `documentation-research-experiments-integration.md` — superseded by §2.4.
- `gitignore-sync-strategy.md` — canonical-whitelist sync mechanism.
- swift-foundations/swift-institute-linter-rules#68 — mechanical whitelist rule + census.
