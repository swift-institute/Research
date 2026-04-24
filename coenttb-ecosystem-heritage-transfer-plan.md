# Coenttb Ecosystem Heritage Transfer Plan

<!--
---
version: 1.3.0
last_updated: 2026-04-23
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

<!--
Changelog:
- v1.3.0 (2026-04-23, fourth same-day revision): supervisor-review absorption.
  - Critical: fixed apply-on-top recipe step (v) — `git rm -rf . && git checkout ecosystem/main -- . && git add -A` (replacement semantics; ensures deletions propagate) replaces the bare `git checkout ecosystem/main -- .` which produced UNION not REPLACEMENT (empirically reproduced in scratch repo). Plumbing variant (`commit-tree` + `update-ref`) documented as atomic-equivalent footnote.
  - Critical: path-dep hazard explicitly addressed via new Phase 4 — Phase-V URL-hygiene sweep (per `github-organization-migration-swift-file-system.md` precedent). Batched as one Rule-6 auth envelope, two categories: (i) path→URL rewrite in transferred Package.swifts; (ii) consumer URL-update for siblings still referencing coenttb URLs. Keeps transfer mechanic atomic; URL-hygiene gets its own auth envelope.
  - High: stale "two force-push points" line in Session Execution Record deleted — recipe post-v1.2.0 has ZERO force-push points.
  - Medium/Low: Context cosmetic fix (18-originally-named / 15-active); branch-state note preceding Per-Package Status table; primitives heritage Foundation-compat note for swift-renderable row.
  - Execution phases restructured from 4 to 5: Phase 1 (W7 ABSENT) / Phase 2 (primitives) / Phase 3 (foundations CONFLICTED clusters) / Phase 4 (URL-hygiene sweep) / Phase 5 (deferred: swift-html-to-pdf).
- v1.2.0 (2026-04-23, third same-day revision): user direction on recipe + posture.
  - CRITICAL: coenttb history is NEVER squashed. Full heritage preserved (pre-tag + tagged + post-tag). Only the newer ecosystem (swift-institute-org) history is squashed, applied as a single commit on top. The prior "git reset --soft <tag>" step on the coenttb side is retracted across the whole plan.
  - Visibility posture: A — accept PUBLIC on transfer. Caveat: private-to-public flip of swift-foundations dep-chain siblings (e.g., swift-foundations/swift-dependencies) requires a per-package launch process; cannot be ad-hoc flipped. Phased plan honors this.
  - swift-renderable destination resolved: swift-primitives/swift-render-primitives (rename-during-transfer into the existing primitives repo, which becomes the CONFLICTED destination).
  - swift-html-to-pdf likely destination: swift-foundations/swift-pdf (as heritage ancestor; requires in-depth major-version refactor); deferred.
  - 3 archived types leaves remain archived (separate class — superseded by body-org spec packages, not by swift-institute-org packages).
  - Archive disposition demoted from co-equal status to "rare": primary path is transfer across the board (user direction for this plan); archive reserved for superseded-by-body-org cases (already applied) and swift-renderable WIP disposition.
- v1.1.0 (2026-04-23, same-day revision): absorb-and-verify pass. swift-html-prism row corrected; swift-foundations Sibling Inventory added; deprecation-README pattern added to Archive disposition; verification stamps per [META-015]; cross-references added.
- v1.0.0 (2026-04-23): initial consolidation from HANDOFF-heritage-transfers-and-history-strategy.md + session findings.
-->

## Context

Phase II.5 of the Swift Institute ecosystem finalization: transferring (or otherwise consolidating) the originally-named 18-package coenttb/* cluster into the swift-institute ecosystem (3 packages archived this session as superseded; 15 active). The cluster is the `swift-html` tree — `swift-html` core, types siblings (html/css/svg), renderers (html/svg/markdown-html/css-html/pdf-html), domain siblings (svg, css, translating, renderable), and consumer integrations (chart, fontawesome, prism, css-pointfree, html-to-pdf).

Four competing concerns shape the plan:

1. **Heritage preservation** — coenttb repos carry tagged releases, star counts, and authorial history that external consumers can rely on; `gh api .../transfer` preserves all of this including URL redirects from the old canonical URL.
2. **Ecosystem work preservation** — for conflicted destinations, swift-foundations/* siblings already carry 14–49 commits of substantive development (ecosystem naming conventions adopted, protocol hoisting, new targets, tooling migrations). User constraint 2026-04-23: MUST NOT lose this work; ecosystem *history* compressibility is acceptable but *content* is not.
3. **Visibility discipline** — user constraint 2026-04-23: do not make things public yet. `gh api .../transfer` inherits source visibility, so PUBLIC coenttb/X → PUBLIC swift-foundations/X. Many swift-foundations siblings are currently PRIVATE with inter-path dependencies; a PUBLIC repo whose Package.swift path-deps a PRIVATE sibling is externally-unbuildable.
4. **Supersession reality** — some coenttb packages are already superseded by body-org specification packages (swift-whatwg, swift-w3c, etc.). Heritage transfer is not the right move for these; archival preserves the repo's history and metadata at its canonical URL without taking on ecosystem-integration cost.

The plan's job is to route each of the 18 packages through these concerns consistently, and to enumerate the preconditions that must hold before any destructive step executes.

## Question

For each of the 18 named coenttb/* packages, what is the correct disposition — and what are the start conditions (preconditions) that must hold before execution?

## Analysis

### Landscape

The named 18-package scope is locked per `HANDOFF.md` Rule 4 and the original investigation's §6 checklist. Session 2026-04-23 updated the picture: **3 packages archived** (superseded by body-org spec packages), **15 active**, of which **2 are deferred** pending destination/refactor decisions. The remaining **13 active candidates** are the primary content of this plan.

### Mechanics Available

Cross-reference for recipes (do not duplicate here):

- [`git-history-transfer-patterns.md`](./git-history-transfer-patterns.md) — transfer mechanics + 5 squash recipes + per-scenario composition (Scenario-1 transfer-into-foundations; Scenario-2 in-place finalization; Scenario-3 monorepo consumer migration).
- [`github-organization-migration-swift-file-system.md`](./github-organization-migration-swift-file-system.md) — prior migration precedent (81 packages swift-standards → body orgs, fully executed).
- [`package-namespace-noun-convention.md`](./package-namespace-noun-convention.md) — informs the locked `*-rendering` → `*-render` rename decision for 5 of the rendering-family transfers.

Four dispositions per package:

| Disposition | When | Recipe summary |
|---|---|---|
| **Archive** | Source is superseded by a body-org or primitives counterpart; OR heritage preservation via the canonical URL is sufficient and ecosystem-integration cost exceeds value. (Note: source having no git tag is NOT by itself a forced-archive signal — transfer-simple without squash is still possible; archive is a user-preference disposition.) | **Before archive** (recommended): commit a deprecation-README to the repo root pointing at the successor (body-org spec package, ecosystem counterpart, or this plan). Then `gh api repos/coenttb/X -X PATCH -f archived=true` — the README survives read-only and helps external consumers find the migration path. (Provenance: `HANDOFF-swift-testing-successor-migration.md` 2026-04-22 — "deprecation-README + archive" pattern.) Preserves heritage at coenttb URL (read-only, stars intact). No URL redirect to swift-foundations; ecosystem continues independently. |
| **Transfer-simple** | Destination ABSENT; `coenttb/X` transfers directly with full heritage intact. | Transfer via `gh api .../transfer` → update local origin → `git fetch origin && git merge --no-edit origin/main` (captures any divergence). **No history rewrite on the coenttb side. Full heritage preserved including post-tag commits.** No force-push needed. |
| **Transfer-rename-and-reconcile** | Destination has substantive ecosystem work (≥14 commits); heritage preservation AND ecosystem work preservation both required. | (i) rename ecosystem sibling: `<layer-org>/X` → `<layer-org>/X-ecosystem` (holding name); (ii) transfer `coenttb/X` → `<layer-org>/X` with optional rename-during-transfer (`*-rendering` → `*-render` per locked decisions) — **full coenttb history preserved, no squash**; (iii) update local origin + fetch + merge origin/main (coenttb's full history is now on the new URL); (iv) add ecosystem sibling as second remote; fetch; (v) apply ecosystem state on top via **`git rm -rf . && git checkout ecosystem/main -- . && git add -A`** — **replacement, not union**; ensures deletions propagate so the post-apply tree exactly matches ecosystem's tree (a bare `git checkout ecosystem/main -- .` alone leaves coenttb-only files in place, producing a union — verified empirically 2026-04-23); then commit as **a single squashed commit** titled `"Apply <layer-org>/X-ecosystem work on top of coenttb heritage"` — **only the ecosystem (newer) history is squashed; coenttb history is untouched**; (vi) regular `git push origin main` (no force needed — we're only adding commits); (vii) verify zero-diff against `-ecosystem`; (viii) archive `-ecosystem` sibling. User hard constraints: (a) **MUST NOT squash coenttb history** — full heritage preserved; (b) **MUST NOT LOSE ecosystem work** — applied as single commit on top; (c) minimize dual-state duration — don't leave `-ecosystem` siblings long-term. See "Apply-on-top recipe notes" below for plumbing alternative. |
| **Defer** | Destination name undecided; OR breaking API refactor is a prerequisite; OR dep-visibility chain unresolved and no current resolution path acceptable. | No execution; record blocker + resumption trigger. |

#### Apply-on-top recipe notes (v1.3.0)

The rename-and-reconcile row's step (v) uses **porcelain commands** (`git rm -rf . && git checkout ecosystem/main -- . && git add -A`) as the primary recipe. Rationale (per supervisor review 2026-04-23): porcelain is debuggable step-by-step via `git status`; intermediate states are inspectable; accessible for recipe readers.

- `git rm -rf .` stages deletion of all tracked files; working tree is cleared of tracked content (untracked files remain).
- `git checkout ecosystem/main -- .` copies ecosystem's tracked files into working tree and index.
- `git add -A` is a safety net; at this point the index already matches ecosystem, but `-A` ensures any untracked items are captured.
- Then `git commit -m "Apply <layer-org>/X-ecosystem work on top of coenttb heritage"` produces one commit whose tree exactly equals `ecosystem/main`'s tree.

**Plumbing alternative** (atomic; reserve for cases where transient states between `rm` and `checkout` are unacceptable):

```bash
TREE=$(git rev-parse ecosystem/main^{tree})
NEW=$(git commit-tree $TREE -p HEAD -m "Apply <layer-org>/X-ecosystem work on top of coenttb heritage")
git update-ref HEAD $NEW
git checkout -- .
```

Single atomic ref update. The new commit's tree equals `ecosystem/main`'s by construction. Working tree is updated to match the new HEAD in the final `git checkout -- .`. Both the porcelain and plumbing variants produce identical git results.

### Disposition Framework (decision order)

For each package, evaluate in sequence. First affirmative step sets the disposition:

1. **Supersession check** — is there a body-org specification package (swift-whatwg, swift-w3c, swift-ietf) or primitives counterpart that supersedes the coenttb functionality? → ARCHIVE.
2. **Source-tag check** — does `coenttb/X` have a tagged release? The squash recipe (`git reset --soft <tag>`) has no anchor without one, and Rule 1 forbids cutting one retrospectively. → ARCHIVE.
3. **Destination state** — is the swift-foundations/X (or renamed target) ABSENT, scaffold-only (≤10 commits, tooling-only), or substantive (≥14 commits)?
   - ABSENT → candidate for transfer-simple.
   - Scaffold-only → candidate for transfer-simple (vacate placeholder before transfer; requires per-repo auth).
   - Substantive → candidate for transfer-rename-and-reconcile.
4. **Dep-visibility audit** — enumerate the transitive Package.swift dep chain of the destination. Classify each dep:
   - URL deps to PUBLIC external packages (e.g., pointfreeco, apple) — safe.
   - Path deps to PUBLIC ecosystem siblings — safe.
   - Path deps to PRIVATE ecosystem siblings — hazard.

   If hazards exist and user constraint "do not make public yet" holds, the transfer dispositions cannot proceed (they all produce PUBLIC destinations). Options: (a) flip hazard deps PUBLIC (Phase IV micro); (b) URL-ify Package.swift to route around hazards (structural refactor); (c) pivot to ARCHIVE.
5. **Source state** — is `coenttb/X` working tree clean, branch `main`, origin synced, open PRs drainable?
   - Per Ground Rule 2: per-case WIP triage, default commit. Escalate if structurally risky.
   - Branch deviations (e.g., swift-html-to-pdf on `1.1`) require explicit alignment decision.
   - Open PRs: dependabot CI PRs are force-push-invalidate-acceptable; substantive PRs require drain.
6. **Final disposition** — archive / transfer-simple / transfer-rename-and-reconcile / defer. Default to archive when in doubt (Remediate-first per `feedback_destructive_workstream_escalation`).

### Hard Constraints (session-binding)

Binding for Phase II.5 execution; transcribed from `HANDOFF.md` Ground Rules + user directions 2026-04-23 (including the late-session recipe clarification):

- **No tags cut, moved, or deleted** (Rule 1). Tag operations require ritual-phrase per-repo auth. Squash recipes read tags; they do not write them. Major-version-bump tagging (to signal the ecosystem-merge landing) is deferred per this rule and requires separate auth.
- **NEVER squash coenttb history** (user 2026-04-23, explicit). Full coenttb heritage preserved: pre-tag + tagged + post-tag commits all intact through the transfer. The prior "git reset --soft <tag>" recipe step on coenttb is retracted.
- **MUST NOT LOSE ecosystem work** (user 2026-04-23, explicit). Ecosystem (newer, swift-institute-org) work lands on top of heritage. Ecosystem git *history* MAY be squashed (single commit), but ecosystem *content* MUST be preserved in full.
- **Scope is the named 18** (Rule 4). Broader coenttb → swift-institute migration is directional-ready only; requires explicit user approval before expansion. See Future Work.
- **Visibility posture A — accept PUBLIC on transfer** (user 2026-04-23). Each transfer produces a PUBLIC destination via visibility inheritance. No post-transfer flip-to-private.
- **Private-to-public flips for dep-chain siblings require launch processes** (user 2026-04-23). Siblings like `swift-foundations/swift-dependencies` can't be ad-hoc flipped public to unblock a transfer's dep chain. Each such sibling needs its own per-package launch process. The phased plan below orders transfers around this constraint.
- **Per-repo auth at each destructive step** (Rule 6). Transfer, rename, force-push (if any), delete/archive — each requires explicit user authorization for the specific repo.
- **coenttb/* structural changes** require explicit auth (HANDOFF.md Constraints); URL-hygiene for renamed deps is permitted.

### Per-Package Status

Post-2026-04-23 session. Rows in the original investigation's W1–W8 wave order. Archives shown at the top for record.

**Branch state**: all 15 active packages are on branch `main` except `swift-html-to-pdf` on branch `1.1` (transfer-groundwork; `main` → `1.1` fast-forward or merge is part of its Phase 5 start conditions per HANDOFF.md Rule 4).

| # | Package | Wave | Stars | Tag | Post-tag | Dirty | Destination state | Session disposition | Primary start-condition gap |
|---|---|---|---:|---|---:|---:|---|---|---|
| A1 | swift-html-types | W1 | 0 | 0.1.2 | — | — | — | **ARCHIVED 2026-04-23** | superseded by swift-whatwg/swift-whatwg-html (PUBLIC v0.1.6, ~30 spec-structured modules vs 6 coenttb umbrella modules) |
| A2 | swift-css-types | W1 | 4 | 0.1.2 | — | — | — | **ARCHIVED 2026-04-23** | superseded by swift-w3c/swift-w3c-css (PUBLIC v0.1.4) |
| A3 | swift-svg-types | W1 | 2 | 0.1.0 | — | — | — | **ARCHIVED 2026-04-23** | superseded by swift-w3c/swift-w3c-svg (PUBLIC v0.2.0) |
| 1 | swift-translating | W1 | 1 | 0.3.0 | 27 | 0 | CONFLICTED (20 commits at `swift-foundations/swift-translating`) | transfer-rename-and-reconcile OR archive | dep-visibility (swift-foundations/swift-dependencies is PRIVATE); user visibility posture |
| 2 | swift-renderable | W1 prereq | 7 | 3.2.2 | 1 | 8 (vestigial per user) | **destination: `swift-primitives/swift-render-primitives`** — CONFLICTED (existing ecosystem work); rename-during-transfer into this repo | transfer-rename-and-reconcile (primitives layer) | WIP disposition; primitives-layer dep-visibility audit |
| 3 | swift-html-rendering | W2 | 2 | 0.1.15 | 4 | 3 | CONFLICTED (45 commits at `swift-foundations/swift-html-render`) | transfer-rename-and-reconcile OR archive | dep-visibility; WIP triage; rename-during-transfer (`-rendering` → `-render`) |
| 4 | swift-svg-rendering | W2 | 1 | 0.3.1 | 3 | 0 | CONFLICTED (23 commits at `swift-foundations/swift-svg-render`) | transfer-rename-and-reconcile OR archive | dep-visibility; rename-during-transfer |
| 5 | swift-css-html-rendering | W3 | 1 | 0.2.1 | 1 | 2 | CONFLICTED (25 commits at `swift-foundations/swift-css-html-render`) | transfer-rename-and-reconcile OR archive | dep-visibility; WIP triage; rename-during-transfer |
| 6 | swift-svg | W3 | 4 | 0.3.0 | 2 | 1 | CONFLICTED (14 commits) | transfer-rename-and-reconcile OR archive | dep-visibility; WIP triage |
| 7 | swift-css | W4 | 0 | 0.6.1 | 0 | 1 | CONFLICTED (25 commits) | transfer-rename-and-reconcile OR archive | dep-visibility; WIP triage; **no coenttb-side squash needed** (0 post-tag) |
| 8 | swift-markdown-html-rendering | W5 | 1 | 0.1.3 | 2 | 3 | CONFLICTED (40 commits at `swift-foundations/swift-markdown-html-render`) | transfer-rename-and-reconcile OR archive | dep-visibility; WIP triage; rename-during-transfer |
| 9 | swift-html | W6 | **33** | 0.17.2 | 2 | 12 | CONFLICTED (20 commits); destination PRIVATE with many PRIVATE path-deps | transfer-rename-and-reconcile OR archive; **user's primary heritage concern** | dep-visibility audit (full chain; many candidates); WIP triage; visibility posture |
| 10 | swift-html-chart | W7 | 1 | 0.1.0 | 19 | 0 | ABSENT | transfer-simple OR archive | dep-visibility; PR drain (2 dependabot CI) |
| 11 | swift-html-fontawesome | W7 | 1 | 0.1.0 | 23 | 0 | ABSENT | transfer-simple OR archive | dep-visibility; PR drain (2 dependabot + 1 substantive swift-html version bump) |
| 12 | swift-html-prism | W7 | 1 | 0.1.0 | 21 | 0 | ABSENT | transfer-simple OR archive | dep-visibility; PR drain (2 dependabot CI) |
| 13 | swift-html-css-pointfree | W7 | 1 | 0.0.2 | 41 | 0 | ABSENT | transfer-simple OR archive | dep-visibility; PR drain (2 dependabot CI); largest post-tag drift |
| 14 | swift-pdf-html-rendering | W8 | 0 | 0.5.0 | 7 | 0 | CONFLICTED (49 commits, destination PRIVATE); source also PRIVATE | transfer-rename-and-reconcile OR archive | dep-visibility; source visibility preserved by transfer |
| 15 | swift-html-to-pdf | W8 LAST | **78** | 1.0.5 | 2 | 2 (branch=1.1) | **likely destination: `swift-foundations/swift-pdf`** (will be ancestor; requires in-depth major-version refactor to fit ecosystem PDF types) | **DEFER** — breaking API refactor prerequisite | refactor plan; branch alignment (main vs 1.1); WIP triage |

**Primitives heritage note for Row 2 (swift-renderable)** (supervisor review 2026-04-23): coenttb/swift-renderable's pre-tag heritage may contain Foundation imports (its primitives-layer destination `swift-primitives/swift-render-primitives` is Foundation-independent per `[PRIM-FOUND-001]`). Post-apply HEAD matches the existing primitives-compatible `swift-render-primitives` state, so CI on HEAD does not break. But `git log` / `git blame` on historical commits in the transferred repo may surface Foundation usage in the heritage tail. This is a documentation note — no recipe change required — and a known trade-off of preserving coenttb heritage at a primitives-layer URL.

### Per-Package Start Conditions (checklist template)

Applied uniformly per package; execution gated on all rows passing. The checklist is the entry gate for Stage 3 execution.

```
[ ] Disposition chosen (transfer-simple / transfer-rename-and-reconcile / defer; archive reserved for superseded-by-body-org cases)
[ ] Destination layer identified (primitives / standards / foundations) and target repo named
[ ] Source working tree clean OR WIP triaged per Rule 2 (each dirty file: commit / stash / discard with user ack)
[ ] Source branch = main OR branch alignment decision made (e.g., fast-forward main to 1.1 for swift-html-to-pdf)
[ ] Source origin sync state known; `git fetch origin && git merge --no-edit origin/main` planned if diverged (captures divergence into the transferred HEAD; no coenttb history rewrite)
[ ] Open PRs drain plan (dependabot CI PRs accept force-push invalidation if apply-on-top runs; no ecosystem PR drain needed because ecosystem sibling is archived post-apply)
[ ] Destination state confirmed (absent / scaffold-only / substantive-ecosystem)
[ ] For substantive-ecosystem: rename-and-reconcile plan authored; ecosystem-sibling name chosen (`-ecosystem` suffix per user 2026-04-23)
[ ] For rendering-family rename-during-transfer: `new_name` specified per locked `*-rendering` → `*-render` decision (swift-html-render, swift-svg-render, swift-css-html-render, swift-markdown-html-render, swift-pdf-html-render)
[ ] Dep-visibility audit complete for destination's Package.swift; each transitive dep classified (URL-public / path-public / path-PRIVATE-launch-needed)
[ ] Dep-visibility resolution: all-public OR phased-plan with dep-sibling launches ordered before this transfer (user constraint: each private-to-public flip is its own launch process)
[ ] Per-destructive-step user auth captured (transfer; rename ecosystem sibling if applicable; regular push after apply-on-top; archive ecosystem sibling)
[ ] Post-execution verification plan (ecosystem zero-diff vs `-ecosystem` sibling before its archive; coenttb history intact check via `git log --oneline <tag>..HEAD`; external-build spot check)
[ ] Major-version-bump tag: **deferred** per Rule 1 until explicit `YES DO NOW TAG <repo> <tagname>` auth
```

### Session Execution Record (2026-04-23)

Archives executed under explicit user auth:

| Package | Supersession target | Evidence |
|---|---|---|
| coenttb/swift-html-types | swift-whatwg/swift-whatwg-html (v0.1.6 PUBLIC) | ~30 spec-structured WHATWG modules vs 6 coenttb umbrella modules; spec-aligned successor |
| coenttb/swift-css-types | swift-w3c/swift-w3c-css (v0.1.4 PUBLIC) | Body-org spec package; released 2025-12-16 |
| coenttb/swift-svg-types | swift-w3c/swift-w3c-svg (v0.2.0 PUBLIC) | Body-org spec package; released 2025-12-15 |

All three: `gh api repos/coenttb/X -X PATCH -f archived=true`; verified `isArchived=true`, visibility preserved. Dependabot PRs naturally frozen by archive state.

Deferred:

- **swift-renderable**: destination revised per user 2026-04-23 from `swift-foundations/swift-renderable` → `swift-primitives/<TBD-name>` as heritage for the already-existing `swift-primitives/swift-render-primitives` (which solves the `Output` → `RenderOutput` naming concern that the coenttb WIP addressed). WIP classified vestigial by user; discard attempt blocked by Rule 2 strict reading; WIP left intact pending explicit disposition.
- **swift-html-to-pdf**: user flagged as requiring breaking API refactor; destination ambiguous (`swift-foundations/swift-pdf-html-render` vs `swift-foundations/swift-pdf`); local branch `1.1` not `main`; transfer deferred until refactor plan + destination decision.

System-level findings (not per-package):

- `gh api .../transfer` preserves source visibility (verified). PUBLIC coenttb/X transfers to PUBLIC swift-foundations/X. Combined with user constraint "no public yet" and the private-dep hazard, makes dep-visibility audit a universal precondition for any transfer disposition.
- gh token scope (`gist, read:org, repo, workflow`) lacks `delete_repo`. Placeholder deletes (e.g., for transfer-simple with scaffold-only destination) require user-handled via web UI, per swift-rfc-template precedent.
- The rename-and-reconcile recipe (post-v1.2.0) has **zero force-push points**: the transfer step preserves coenttb's full heritage (no coenttb-side rewrite); the apply-on-top step adds one commit on top of HEAD (regular `git push`, no force). Force-push was an artifact of the pre-v1.2.0 recipe that squashed coenttb's post-tag commits — that step was retracted per user direction.

### swift-foundations Sibling Inventory (Verified: 2026-04-23)

Dep-visibility gate evidence — every swift-foundations counterpart in the plan scope, inventoried directly via `gh repo view ... --json visibility`:

| swift-foundations sibling | Visibility | In-scope role |
|---|---|---|
| swift-dependencies | **PRIVATE** | Path-dep of swift-translating's ecosystem Package.swift (Row 1 hazard) |
| swift-html-render | **PRIVATE** | Conflicted destination (Row 3, rename-during-transfer target) |
| swift-markdown-html-render | **PRIVATE** | Conflicted destination (Row 8, rename-during-transfer target) |
| swift-css-html-render | **PRIVATE** | Conflicted destination (Row 5, rename-during-transfer target) |
| swift-pdf-html-render | **PRIVATE** | Conflicted destination (Row 14, rename-during-transfer target) |
| swift-css | **PRIVATE** | Conflicted destination (Row 7) |
| swift-svg | **PRIVATE** | Conflicted destination (Row 6) |
| swift-svg-render | **PRIVATE** | Conflicted destination (Row 4, rename-during-transfer target) |
| swift-translating | **PRIVATE** | Conflicted destination (Row 1) |
| swift-html | **PRIVATE** | Conflicted destination (Row 9, user's primary concern) |
| swift-color | **PRIVATE** | Path-dep of swift-html's ecosystem Package.swift (Row 9 hazard) |
| swift-pdf | **PRIVATE** | Candidate destination for swift-html-to-pdf (Row 15 option A) |
| swift-pdf-render | **PRIVATE** | Candidate destination for swift-html-to-pdf (Row 15 option B) |
| swift-html-to-pdf | MISSING | No swift-foundations counterpart yet (Row 15 destination TBD) |
| swift-renderable | MISSING | Destination revised to swift-primitives (Row 2; swift-foundations counterpart never created) |

**Implication**: Every in-scope counterpart is either PRIVATE or missing. No transfer can produce an externally-buildable PUBLIC artifact under the current state — Phase IV micro-flips (or URL-ification, or pivot-to-archive) are the only resolution paths consistent with user constraint "do not make things public yet."

**Phase IV micro-flip cost estimate**: flipping a swift-foundations/X to PUBLIC requires ritual `YES DO NOW PUBLIC` per the existing CLAUDE.md Constraint; flip is reversible (gh api PATCH). Cascade: swift-html's transitive public-exposure set includes (minimum) swift-html-render + swift-markdown-html-render + swift-css + swift-svg + swift-translating + swift-color, each of which carries its own transitive deps — full cascade analysis is Stage 1 work.

### Verification Stamp (2026-04-23 absorb-and-verify pass)

Re-verified this pass:

| Claim | Evidence source | Status |
|---|---|---|
| 3 archives still `isArchived=true`, visibility preserved | `gh repo view coenttb/{swift-html-types,swift-css-types,swift-svg-types} --json isArchived,visibility` | **Verified: 2026-04-23** |
| 3 body-org superseders still PUBLIC with tag in Research doc | `gh repo view swift-{whatwg,w3c}/... --json visibility,latestRelease` | **Verified: 2026-04-23** |
| 15 active packages' local state (branch, tag, post-tag, dirty) | `git describe --tags --abbrev=0 && git rev-list --count tag..HEAD && git status -s` each repo | **Verified: 2026-04-23** |
| swift-html-prism has git tag 0.1.0 (21 post-tag) — prior "no tag" claim was incorrect | `git describe --tags --abbrev=0` at coenttb/swift-html-prism returns 0.1.0 | **Resolved: 2026-04-23** (row corrected) |
| swift-foundations sibling inventory — all 13 in-scope counterparts PRIVATE + 2 MISSING | Inventory table above | **Verified: 2026-04-23** |
| `gh api .../transfer` preserves source visibility | Prior session evidence + handoff investigation §Q2 | Carried forward (unverified this pass; GitHub mechanic) |

Claims not directly re-verified this pass: transitive Package.swift dep chains per destination (Stage 1 audit still pending); open-PR counts per package (may have drifted since handoff table 2026-04-22); tag release history beyond latest tag.

### Execution Sequencing

User direction 2026-04-23: lowest stakes first, but mind the layers. Each private-to-public flip for an unreleased dep-chain sibling requires its own launch process (so they cannot be batch-flipped under this plan). The phased structure below respects both constraints.

**Phase 1 — ABSENT destinations, lowest stakes (foundations layer, no apply-on-top)**

The 4 W7 consumer siblings. All PUBLIC, 1★ each, ABSENT destination, no ecosystem work to reconcile. Dep chains resolve through URL deps to coenttb/swift-html (PUBLIC, still existing, will redirect when swift-html eventually transfers) or other external packages — no private-sibling launch prerequisite.

| Package | Destination | Stars | Notes |
|---|---|---:|---|
| swift-html-chart | `swift-foundations/swift-html-chart` | 1 | Recommended dry-run (lowest complexity) |
| swift-html-fontawesome | `swift-foundations/swift-html-fontawesome` | 1 | Has 1 substantive PR (swift-html bump) — drain or accept invalidation |
| swift-html-prism | `swift-foundations/swift-html-prism` | 1 | — |
| swift-html-css-pointfree | `swift-foundations/swift-html-css-pointfree` | 1 | Max post-tag drift (41) — preserved in full |

Mechanic: `gh api .../transfer` → update local origin → fetch + merge origin/main. No apply-on-top step, no force-push. Full coenttb history preserved.

**Phase 2 — primitives layer**

| Package | Destination | Recipe |
|---|---|---|
| swift-renderable | `swift-primitives/swift-render-primitives` (rename-during-transfer into the existing conflicted primitives repo) | rename-and-reconcile |

Preconditions before Phase 2:
- Stage 1 dep-visibility audit on `swift-primitives/swift-render-primitives` (identify which transitive deps are currently PRIVATE; sequence their launches first if any).
- swift-renderable's 8 dirty WIP files: user already classified "vestigial" (superseded by swift-render-primitives). Disposition pending explicit commit / stash / discard auth (default commit under Rule 2 was system-denied earlier).

**Phase 3 — foundations layer, CONFLICTED destinations**

The 9 CONFLICTED-destination foundations packages, each requiring rename-and-reconcile. Each has an ecosystem sibling Package.swift with path-deps to other swift-foundations siblings; those private siblings (e.g., `swift-foundations/swift-dependencies`, `swift-foundations/swift-color`) need their own launch processes before the transfer's post-apply Package.swift can build externally. User direction: launches cannot be ad-hoc flipped.

Order within Phase 3 is governed by shared-dep-chain grouping:

1. **Sub-phase 3a — identify dep clusters.** Group packages that share dep-sibling dependencies. Launch shared private siblings first (each sibling's launch is its own process).
2. **Sub-phase 3b — transfer each cluster.** Once a cluster's private siblings are launched, transfer the cluster's packages (rename-and-reconcile each). Start with the simplest package in the cluster as the cluster's dry-run.

Stage 1 dep-visibility audit is the immediate prerequisite; its output determines the clusters.

**Phase 4 — URL-hygiene sweep (Phase-V analog per `github-organization-migration-swift-file-system.md` precedent)**

After Phase 3 lands and before any major-version-bump tagging is revisited. Supervisor review 2026-04-23 identified the hazard: ecosystem Package.swifts carry `.package(path: "../../...")` deps that don't resolve for URL-consumers; posture A transfers produce PUBLIC-but-monorepo-buildable-only repos until path-deps are URL-ified. Phase 4 closes that gap.

Batched as a **single Rule-6 auth envelope** ("Phase-V URL-hygiene sweep across transferred repos") rather than per-repo, matching the 81-package swift-file-system migration precedent's ergonomics. Two categories in one pass (both share grep shape):

| Category | Content | Example |
|---|---|---|
| (i) **Path-dep URL-ification** | `.package(path: "../../...")` in transferred ecosystem Package.swifts → `.package(url: "https://github.com/<owner>/<name>")` | `swift-foundations/swift-html-render/Package.swift`: `.package(path: "../../swift-primitives/swift-render-primitives")` → `.package(url: "https://github.com/swift-primitives/swift-render-primitives")` |
| (ii) **Consumer URL-update** | `.package(url: "github.com/coenttb/X")` in transferred-alongside siblings still referencing coenttb URLs → new swift-institute-org URLs | Phase-1's `swift-html-chart` has URL dep on `coenttb/swift-html`; post-Phase-3, rewrite to `swift-foundations/swift-html` for clarity + future-proofing (GitHub redirect keeps pre-rewrite references working, so this is a cleanup not a blocker) |

**Why a sweep, not inline with each transfer**: keeps transfer mechanic atomic (one auth per repo); URL-hygiene gets its own auth envelope; matches the swift-file-system 81-package migration precedent; URL-hygiene's success is decoupled from the ecosystem-apply commit.

**Transition window**: between Phase 3 lands and Phase 4 completes, transferred PUBLIC repos are monorepo-buildable-only (path-deps unresolvable for URL-consumers). Expected and acceptable per the precedent.

**Phase 5 — deferred**

| Package | Destination | Blocker |
|---|---|---|
| swift-html-to-pdf | `swift-foundations/swift-pdf` (as heritage ancestor) | In-depth major-version refactor required to fit ecosystem PDF types |

Re-engage after Phase 3 + Phase 4 settle and the refactor plan is authored.

**Ordering note**: Phase 1 and Phase 2 can run in parallel or interleaved; they have no dep-chain coupling. Phase 3 gates on Stage-1 audit + private-sibling launches. Phase 4 gates on Phase 3 completion. Phase 5 is orthogonal.

### Open Questions (status post-user-direction 2026-04-23)

- ~~**swift-renderable destination name**~~ **RESOLVED 2026-04-23**: destination is `swift-primitives/swift-render-primitives` (rename-during-transfer into the existing conflicted primitives repo).
- ~~**swift-html-to-pdf destination**~~ **RESOLVED 2026-04-23** (likely, with refactor prerequisite): `swift-foundations/swift-pdf` as heritage ancestor; requires in-depth major-version refactor to fit ecosystem PDF types. Deferred.
- **swift-html-to-pdf branch alignment** — `1.1` content (transfer-groundwork) vs `main` content (coenttb local). Per HANDOFF.md Rule 4: `1.1` is canonical; fast-forward main to 1.1 (or merge / reset-hard if ff fails). Deferred along with refactor.
- ~~**Visibility posture**~~ **RESOLVED 2026-04-23**: Posture A — accept PUBLIC on transfer. Caveat: dep-chain sibling launches are their own processes; phased plan handles this.
- ~~**Ecosystem-sibling naming convention**~~ **RESOLVED**: `-ecosystem` suffix adopted uniformly.
- **Private-sibling launch ordering** — user direction: "each private-to-public flip for an unreleased package also requires a launch process". Which siblings need launching and in what order is the output of Stage 1 dep-visibility audit. Open pending that audit.
- **Phase 1 dry-run pick** — lowest-complexity candidate within Phase 1 is swift-html-chart (1★, 19 post-tag, ABSENT destination, only dependabot CI PRs, no substantive-PR drain). Recommended as Phase-1 first transfer to prove the mechanic. User concurrence requested.

## Future Work

Broader coenttb → swift-institute ambition (per `HANDOFF.md` Rule 4): most coenttb packages are expected to eventually move to swift-foundations. Candidate enumeration and disposition analysis for coenttb packages beyond the named 18 (e.g., swift-epub, swift-email, swift-date-parsing, swift-environment-variables, swift-document-templates, plus the 4 repos previously deferred for per-commit review: `swift-form-coding`, `swift-authenticating`, `pointfree-url-form-coding`, `swift-documents`) will be addressed in a separate research document when scope expansion is user-approved. The 4 deferred repos specifically carry pre-existing commits below URL-hygiene that require per-commit Rule 2 triage — handled in that future doc or ad hoc, not in this plan.

## Outcome

**Status**: RECOMMENDATION.

Primary path is **transfer-with-reconciliation** (user direction 2026-04-23, important for personal reasons): heritage lives at a new canonical swift-institute-org URL with full coenttb history intact and ecosystem work squashed on top as a single commit. Archive is no longer the default disposition — it is reserved for:
- Already-archived cases (3 types leaves, superseded by body-org spec packages — separate class).
- swift-renderable's vestigial WIP (not the repo itself; the repo transfers to primitives).
- Hypothetical future cases where a body-org spec package is the clear successor.

**Phased execution**: five phases, each gated on preconditions.

1. **Phase 1** — 4 ABSENT-destination foundations packages (W7 consumer siblings). Transfer only, no apply-on-top. Ready to execute; dry-run candidate: swift-html-chart.
2. **Phase 2** — swift-renderable → `swift-primitives/swift-render-primitives` (primitives layer, CONFLICTED). Ready pending WIP disposition auth + Stage 1 dep-visibility audit on the primitives destination.
3. **Phase 3** — 9 CONFLICTED foundations (swift-html is the primary heritage concern). Gated on Stage 1 dep-visibility audit + dep-chain sibling launches (each a separate user-gated launch process).
4. **Phase 4** — URL-hygiene sweep (Phase-V analog per `github-organization-migration-swift-file-system.md` precedent). Batched post-Phase-3; single Rule-6 auth envelope; two categories (path→URL rewrites in transferred Package.swifts; consumer URL-updates for siblings still referencing coenttb URLs). Closes the path-dep resolvability gap that Posture A alone doesn't address.
5. **Phase 5** — deferred: swift-html-to-pdf (refactor prerequisite + branch alignment).

**Hard constraints carried into execution**:
- Coenttb history NEVER squashed. Full heritage preserved through every transfer.
- Ecosystem work preserved as content (applied on top); ecosystem *history* may be squashed to one commit.
- No tags cut (Rule 1); major-version-bump tagging post-merge requires separate auth.
- Per-destructive-step user auth per Rule 6.
- Phase 3 dep-chain sibling launches cannot be batch-flipped; each is its own launch process.

## References

**Tier 2 research (cross-referenced, not absorbed)**:

- [`git-history-transfer-patterns.md`](./git-history-transfer-patterns.md) — squash + transfer mechanics (Tier 2, DECISION v1.0.0). Canonical source for recipes; this plan names dispositions but delegates mechanics here.
- [`github-organization-migration-swift-file-system.md`](./github-organization-migration-swift-file-system.md) — prior migration precedent, 81-package standards → body-orgs (Tier 2, DECISION v5.0.0). Shows the Phase-V URL-hygiene sweep pattern that follows transfer.
- [`package-namespace-noun-convention.md`](./package-namespace-noun-convention.md) — `*-rendering` → `*-render` rename rationale (Tier 2, RECOMMENDATION). Authority for the locked rename-during-transfer on 5 rendering-family packages.
- [`swift-translating-migration-plan.md`](./swift-translating-migration-plan.md) — converged ecosystem-work design for swift-translating (Tier 1, DECISION 2026-03-11): BCP 47 typealias, four-surface model, Translating-Platform module split, Foundation-independence invariants. Row 1's apply-on-top ecosystem work MUST preserve these invariants (reference for Stage 2 disposition confirmation).

**Parallel investigations (disposition precedent)**:

- `/Users/coen/Developer/HANDOFF-swift-testing-successor-migration.md` — parallel disposition analysis for `coenttb/swift-testing-performance` (PUBLIC, 6★, tag 0.3.1) superseded by `swift-foundations/swift-testing`. Recommended outcome: **deprecation-README + archive**, NOT transfer. Provenance for the Archive-disposition recipe refinement in this plan (commit deprecation-README before archive).

**Operational docs (binding)**:

- `/Users/coen/Developer/HANDOFF.md` — operational parent; Ground Rules 1–6 + Escalations binding for execution. Next-Steps #2 points at this plan as canonical strategy (updated 2026-04-23).
- `/Users/coen/Developer/HANDOFF-heritage-transfers-and-history-strategy.md` — **SUPERSEDED** by this document per [META-016] (consolidated 2026-04-23). Retained until `/reflect-session` triage removes it per [REFL-009]. SUPERSEDED header + pointer prepended.

**Meta-process**:

- [META-015] Findings Verification Sweep — applied in Verification Stamp subsection above.
- [META-016] Consolidation Protocol — applied across HANDOFF-heritage... supersession + this document's absorption of its Findings/Extension.
- [REFL-009] Reflection Triage — governs eventual removal of SUPERSEDED handoff docs after consolidation validated.
