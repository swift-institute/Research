# Versioning and Release Strategy

<!--
---
version: 1.0.0
last_updated: 2026-06-02
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
---
-->

## Context

**Trigger.** The ecosystem just completed the path→URL dependency conversion
(every cross-repo dep is now a `.package(url:…)` reference resolved locally
through the global mirror and on CI through an injected token). A modularization
rewrite of the L1 primitives is in flight (disjoint). With deps now URL-form and
a publish-capable shape in reach, the institute needs a settled answer to: *what
is the versioning + release strategy, and what is the concrete path from today's
state to genuine, outsider-buildable public releases?*

This is a **Tier 3** investigation per [RES-020]: ecosystem-wide, precedent-
setting, hard to undo, and establishing a normative contract that ~400 packages
and every future package will depend on. The output is a **RECOMMENDATION** — no
tagging, no visibility flips, no pin changes are executed by this doc.

**The principal's working assumption** (to evaluate, not adopt blindly): go
public *first* on `main`; keep everything `branch:"main"` until primitives +
foundations are stable; then tag a *universal* first release (0.1.0 / 0.0.1) much
later. The alternative the principal wants weighed: per-package semver, tagged off
a rolling `main` as each package is ready, no synchronized universal version.

**Prior research.** A dedicated versioning-strategy doc did not previously exist.
Adjacent docs do; several predate the path→URL conversion + modularization rewrite
and are **stale on their core mechanism** — they are reconciled and partly
superseded in [Prior Art](#prior-art) per [META-004]. Current state +
external best practice govern; prior docs are consulted only to avoid duplication
and contradiction.

---

## Question

1. **Synchronized vs independent versioning** — Model A (one coordinated
   universal first tag across all packages) vs Model B (per-package semver tagged
   off a rolling `main`). Trade-offs for ~400 layered packages and the
   `from:`-cascade churn.
2. **First tag: 0.1.0 vs 0.0.1** — including SwiftPM 0.x.y resolution semantics
   and what each signals.
3. **Sequencing of visibility-flip × tagging × pin-form switch**, bottom-up, with
   the **one-form-per-package invariant** (never `branch:` + version for the same
   package) kept atomic.
4. **The rolling-on-`main` public phase** — reproducibility for public consumers
   tracking HEAD; mirror + CI-token interaction; what proves public-consumability.
5. **Reconcile the existing standards-layer tags** — kept, superseded, or re-cut?
6. **Prior art** — SwiftPM norms, monorepo release trains, the SemVer pre-1.0 /
   ZeroVer debate.

---

## Current State (verified 2026-06-02)

All figures below were measured read-only against the local org-clone mirrors on
2026-06-02 and are tagged `[Verified: 2026-06-02]` per [RES-023].

### Pin-form census `[Verified: 2026-06-02]`

`url`-form cross-repo dependency declarations across the layer + standards orgs:

| Org group | Manifests | `branch:"main"` | `from:`/`upToNext` | `path:` |
|-----------|-----------|-----------------|--------------------|---------|
| swift-primitives | 204 | 825 | 0 | **0** |
| swift-foundations | 88 | 433 | 13 | **0** |
| swift-standards (meta) | 21 | 70 | 2 | **0** |
| standards sub-orgs (ietf/iso/w3c/whatwg/ecma/incits/ieee/iec) | 81 | 294 | 6 | **0** |
| **Total measured** | **394** | **1622** | **21** | **0** |

Two facts are dispositive:

- **The path→URL conversion is complete.** Zero `path:` deps remain anywhere in
  the measured surface. (Matches the handoff's "all infra deps URL-form.")
- **The pin reality is ~99% `branch:"main"`.** 1622 `branch:"main"` references vs
  21 `from:` references. The handful of `from:` deps are legacy pins from
  already-tagged packages. (Matches the handoff's "~1651 `branch:"main"` vs 19
  `from:`.")

The implication: **`main` is the rolling line and `branch:"main"` is already the
de-facto pre-tag pin form** — there is no path-on-main + release-branch-transform
model to preserve (see [Prior Art](#prior-art): this supersedes
`dual-mode-package-publication.md`).

### Visibility distribution `[Verified: 2026-06-02]`

| Org | Public | Total | % private |
|-----|--------|-------|-----------|
| swift-primitives (L1) | 22 | 232 | ~91% |
| swift-foundations (L3) | 6 | 158 | ~96% |
| swift-standards (meta) | 21 | 25 | ~16% |
| swift-ietf (L2) | 45 | 79 | ~43% |
| swift-iso (L2) | 8 | 10 | ~20% |
| swift-w3c (L2) | 5 | 7 | ~29% |

### Tag landscape `[Verified: 2026-06-02]`

| Org | Repos with ≥1 tag | Local git-repos |
|-----|-------------------|-----------------|
| swift-primitives (L1) | 9 | 205 |
| swift-foundations (L3) | 6 | 153 |
| swift-standards (meta) | 17 | 22 |
| swift-ietf (L2) | 53 | 78 |
| swift-iso (L2) | 8 | 9 |
| swift-w3c (L2) | 5 | 6 |
| swift-whatwg (L2) | 2 | 2 |

### The inverted publication frontier (key diagnosis)

The three tables above describe a single structural fact that governs the entire
strategy:

> **The L2 specification layer is mostly *public + tagged*, but the L1 primitives
> it depends on are mostly *private + untagged* — and the modularization rewrite
> re-pointed the L2 specs' `main` branches onto those private L1 packages.**

Worked example, fully verified `[Verified: 2026-06-02]`:

- `swift-ietf/swift-rfc-3986` is **PUBLIC**, git-tagged through **`0.3.6`** (13
  tags: `0.1.0 … 0.3.6`). Its *GitHub Release* is only `0.1.0` — a textbook
  [PKG-NAME-010] Release-≠-tag divergence; the handoff's "0.3.6" is the **git
  tag**, confirmed.
- At the **`0.3.6` tag**, `Package.swift` depends entirely by `from:` on public
  `swift-standards/*` URLs (`swift-standards` from `0.10.0`, `swift-incits-4-1986`
  from `0.6.3`, `swift-ipv4-standard`/`swift-ipv6-standard` from `0.1.3`). The tag
  is a **genuine, internally-consistent, outsider-buildable release.** (Confirms
  the handoff's "standards-layer tags ARE genuine reproducible releases.")
- The **current `main`** has been re-architected by the modularization rewrite to
  depend on `swift-primitives/swift-parser-primitives` and
  `swift-ascii-serializer-primitives` via `branch:"main"` — and
  `swift-parser-primitives` is **PRIVATE**. So `rfc-3986`'s `main` is **not
  outsider-buildable** even though its tag is.

This is not a pin-form drift; it is a **dependency-graph re-architecture**. The
already-public/tagged top of the stack now rests on a still-private,
post-modularization bottom. The whole strategy below is, at root, the disciplined
way to **re-close the foundation under the parts that already went public** —
bottom-up — and then resume tagging on each package's own line.

### Mirror + CI-token resolution model

Three resolution surfaces exist, and **they do not agree about
public-consumability**:

| Surface | How `url`-deps resolve | What it proves |
|---------|------------------------|----------------|
| Local dev | global mirror rewrites every `url` → local clone path | nothing about public state (mirror hides private/missing repos and makes version requirements inert) |
| CI | injected token resolves private org repos | nothing about *outsider* state (the token an outsider does not have) |
| Outsider (no token, no mirror) | GitHub resolves `url` directly | **the only surface that proves public-consumability** |

Therefore: **neither local-green nor CI-green proves a package is publicly
consumable.** Only a no-token, mirror-bypassed "clean-room" resolve does. This is
the verification gate for every visibility flip (see Q4) and is consistent with
memory `feedback_clean_room_resolve_not_redundant` and [CI-094]/[CI-095].

---

## Prior Art

### Internal corpus (disposition)

Per [RES-019], the existing research corpus was surveyed before drafting. None of
the prior docs is an ecosystem-wide versioning-strategy doc; the relevant ones and
their disposition:

| Doc | Status | Bearing | Disposition |
|-----|--------|---------|-------------|
| `dual-mode-package-publication.md` v2.0.0 (2026-02-26) | RECOMMENDATION | Recommends **layer-lockstep versioning** (all primitives share one version) + **release-branch** path→URL transformation (dev `main` keeps `path:` deps, a publish tool creates `release/{v}` branches with `url:` deps). | **SUPERSEDED on both points** per [META-004]. (a) Lockstep is rejected in Q1. (b) The release-branch transform is obviated: `main` already carries `url:`+`branch:"main"` (0 `path:` deps), so there is nothing to transform — the only change at tag time is `branch:"main"` → `from:` for one package. |
| `git-subtree-publication-pattern.md` v2.0.0 (2026-02-26) | DECISION | Path→URL via `sed` on a release branch; explicitly **defers** the version-strategy decision. | **Mechanism SUPERSEDED** (path→URL already done in-place on `main`); the "version strategy is a separate decision" note is **answered by this doc**. |
| `release-roadmap-swift-file-system.md` v1.0.0 (2026-03-30) | RECOMMENDATION | "Each package is an independent release; dependencies released before dependents," topological (L1→L2→L3) order. | **AFFIRMED + generalized** to the ecosystem here. Its per-package transformation-at-tag-time checklist is updated to the post-conversion reality (no `path:`→`url:` step; only `branch:"main"`→`from:`). |
| `spm-nested-package-publication.md` v1.0.0 (2026-02-26) | DECISION | SPM cannot publish nested `Package.swift`; the separate-repo-per-package shape is forced. | **VALID, cited** — confirms the repo shape every versioning scheme must work within (no monorepo escape hatch). |
| `2026-05-12-swift-package-and-version-primitives-design.md` v1.0.0 | RECOMMENDATION | Designs the `Version.Semantic` *type* (typed SemVer 2.0.0 values). | **Orthogonal, cited** — about *typing* version values, not *release* strategy. No conflict. |
| `launch-flow-assessment-2026-05-08.md` v1.2.0 | DECISION | Launch *pacing* ("per-package readiness drives cadence; no fixed weekly floor"). | **VALID, cited** — the pacing principle composes with the per-package tagging cadence here. |
| `coenttb-stage-1-dep-visibility-audit.md` v1.0.0 | RECOMMENDATION | Topological launch order honoring closure visibility. | **VALID pattern, snapshot stale** — the bottom-up closure-completeness discipline generalizes; specific package states predate modularization. |

The critical prior conflict — `dual-mode` (lockstep) vs `release-roadmap`
(independent) — is resolved in favor of **independent** (Q1), and `dual-mode`'s
lockstep + release-branch mechanism is explicitly superseded by current state.

### External prior art

**SwiftPM ecosystem norm: independent per-package versioning.** Every Swift
package carries its own version line; there is no synchronized-version primitive in
SwiftPM and no precedent for one. First-tag conventions `[Verified: 2026-06-02 via
`gh api`]`:

| Package | First tag | |
|---------|-----------|--|
| apple/swift-collections | `0.0.1` | Apple convention: start `0.0.x`, graduate to `1.0.0` when API-stable |
| apple/swift-numerics | `0.0.0` | |
| apple/swift-algorithms | `0.0.1` | |
| apple/swift-system | `0.0.1` | |
| apple/swift-argument-parser | `0.0.1` | |
| pointfreeco/swift-composable-architecture | `0.1.0` | PointFree convention: start `0.1.0` |
| pointfreeco/swift-dependencies | `0.1.0` | |

Both families version **independently** per package. The split is on the *first
number*: Apple starts at `0.0.x` for genuinely-incubating packages with no
stability promise; PointFree starts at `0.1.0` for a shaped first surface.

**SwiftPM 0.x resolution semantics (empirically verified — the crux of Q2).**
Run on Swift 6.3.2 against a scratch package tagged `0.1.0 0.1.1 0.2.0 0.9.0`
`[Verified: 2026-06-02]`:

| Consumer requirement | Resolved version | Effective range |
|----------------------|------------------|-----------------|
| `from: "0.1.0"` | **0.9.0** | `0.1.0 ..< 1.0.0` |
| `.upToNextMajor(from: "0.1.0")` | **0.9.0** | `0.1.0 ..< 1.0.0` |
| `.upToNextMinor(from: "0.1.0")` | **0.1.1** | `0.1.0 ..< 0.2.0` |
| `from: "0.0.1"` | **0.9.0** | `0.0.1 ..< 1.0.0` |
| `.upToNextMinor(from: "0.0.1")` | **RESOLVE FAILS** | `0.0.1 ..< 0.1.0` (empty band) |
| `exact: "0.1.0"` | 0.1.0 | `{0.1.0}` |

SE-0158 (the manifest-API proposal) defines `from:` as shorthand for
`.upToNextMajor`, and `.upToNextMajor(from:)` as "a range … going up to next major
version" — all its examples are 1.x → next major (e.g. `from: "1.0.0"` →
`1.0.0 ..< 2.0.0`). It frames this as "caret (`^`) semantics."

The empirical result establishes a fact SE-0158's 1.x examples obscure, and which
is the single most consequential pin-form fact in the ecosystem:

> **SwiftPM's `from:` / `.upToNextMajor` is NOT a true 0.x caret.** Unlike npm and
> Cargo — where `^0.1.0` means `0.1.0 ..< 0.2.0` (the 0.x *minor* is treated as
> the breaking axis) — SwiftPM takes "next major" literally: `from: "0.1.0"` spans
> the **entire** 0.x line up to `1.0.0`. A consumer who writes `from: "0.<minor>.0"`
> on a pre-1.0 dependency silently auto-adopts every later 0.x minor — including
> the breaking ones SemVer 0.x explicitly permits.

The disciplined pre-1.0 consumer pin is therefore **`.upToNextMinor(from:
"0.Y.0")`**, which restores the npm/Cargo 0.x-caret behaviour explicitly.

**Monorepo release trains do not apply.** Lerna *fixed/locked mode*, Nx, and
Cargo *workspaces* synchronize versions across packages — but only within a
**single repository** with tooling that tags all members together. The institute
is explicitly **not a monorepo**: every package is its own GitHub repo (per
`CLAUDE.md` Package Resolution; confirmed by `spm-nested-package-publication.md`).
A "version train" across ~400 separate repos has no tooling, no atomic tag, and no
precedent. The monorepo train is a solution to a problem the institute's topology
does not have, and cannot adopt the mechanism even if it wanted the outcome.

**SemVer §4 and the ZeroVer debate.** SemVer 2.0.0 §4: "Major version zero
(0.y.z) is for initial development. Anything MAY change at any time. The public API
SHOULD NOT be considered stable." The "ZeroVer" critique (0ver.org; "Say No to
ZeroVer"; semver/semver#221; and the empirical study *Lost in Zero Space*,
arXiv:2101.00836) is that staying on 0.x indefinitely throws away SemVer's
core guarantee — consumers cannot safely "stay put," because 0.x minors may break
and the common `from:` range auto-adopts them. The institute's exposure to this
critique is **exactly the SwiftPM 0.x `from:` trap above**, and the mitigation is
twofold: (a) consumers pin `.upToNextMinor` on 0.x deps; (b) packages graduate to
`1.0.0` when their API stops churning rather than living on 0.x forever.

---

## Analysis

### Q1 — Synchronized (Model A) vs Independent (Model B) versioning

**Criteria:** semantic honesty (does the version number mean what SemVer says?),
tooling support, coordination cost at ~400 repos, `from:`-cascade behaviour,
consistency with current reality, external precedent.

| Criterion | Model A — synchronized / lockstep | Model B — independent per-package |
|-----------|-----------------------------------|-----------------------------------|
| Semantic honesty | **Poor** — a package's version bumps when a *sibling* changes; the number stops meaning "this package changed" | **Good** — version reflects that package's own changes |
| SwiftPM tooling | **None** — no synchronized-version primitive; 400 repos, no atomic tag | **Native** — every `url`+`from:` reference already names one package's version |
| Coordination cost | **O(400) per release** — every package re-tagged each cycle, manually, across 400 repos | **O(changed-set)** — only changed packages tag |
| `from:`-cascade | **Globalized** — one L1 change forces a version bump that must cascade `from:` updates through *all* manifests | **Localized** — a primitive bump churns only its *actual* dependents, only when they adopt |
| Consistency w/ reality | **Contradicted** — see below | **Already the de-facto state** — ~68 independent tag lines exist |
| External precedent | None in SwiftPM; monorepo-train mechanism inapplicable to separate repos | Universal SwiftPM norm (Apple, PointFree, all of crates.io/npm/Go) |

**The dispositive evidence: Model A is already contradicted by reality.** The
standards layer alone carries **dozens of fully independent, divergent version
lines** `[Verified: 2026-06-02]`:

```
swift-rfc-3986:  0.1.0 … 0.3.6        swift-rfc-5322:  0.0.1 … 0.7.4
swift-rfc-1035:  0.0.1 … 0.4.5        swift-rfc-5234:  0.1.0 0.1.1 0.4.2 0.4.3 0.4.4
swift-rfc-1123:  0.0.1 … 0.5.4        swift-rfc-6455:  0.0.1   (single tag)
swift-rfc-4648:  0.1.0 … 0.6.0        swift-rfc-3596:  0.0.1   (single tag)
```

These lines have different lengths, different cadences, and gaps. A "universal
first tag of 0.1.0" cannot be applied without **regressing or abandoning** the
existing `rfc-3986@0.3.6`, `rfc-5322@0.7.4`, etc. — you cannot meaningfully tag
`0.1.0` on a package that is already at `0.3.6`. Lockstep is not merely
sub-optimal; it is **unreachable from the current state** without destroying real
releases that real (internal and external) consumers may already pin.

`dual-mode-package-publication.md`'s rationale for lockstep — "no ecosystem
successfully manages 300+ independently versioned packages" — is **empirically
false**: crates.io (>150k crates), npm, and Go modules each manage *orders of
magnitude* more independently-versioned packages; that *is* the norm. The claim
conflates "packages a human re-tags in lockstep" (which nobody does at scale) with
"packages a resolver versions independently" (which every package manager does).

> **Recommendation (Q1): Model B — independent per-package semver.** Each package
> versions on its own line, tagged off the rolling `main` as its API stabilizes.

**Reconciling the principal's "universal first tag."** The principal's instinct is
not wrong about *coordination* — it is wrong about *synchronizing version
numbers*. Decouple the two:

- The **launch is a coordinated event** — a bottom-up tagging *campaign* over a
  bounded window (Q3). That satisfies the desire for a deliberate "the ecosystem
  is now released" moment.
- The **version numbers stay independent** — each package gets its *own* first tag
  (`0.1.0` for new packages; a *continuation* of the existing line for
  already-tagged packages like `rfc-3986`).

The "universal" belongs to the **timing**, not the **number**. This preserves the
principal's coordinated-launch intent while rejecting the one structural error.

### Q2 — First tag: `0.1.0` vs `0.0.1`

The empirical 0.x table above settles this on consumer-contract grounds, not
aesthetics:

- **`0.0.1` is a poor first tag.** `.upToNextMinor(from: "0.0.1")` produces the
  degenerate band `0.0.1 ..< 0.1.0`, which matches **only** `0.0.x` patches and
  **fails to resolve** the moment the package moves to `0.1.0` `[Verified:
  2026-06-02]`. The only non-degenerate pin a `0.0.1` consumer can write is
  `from: "0.0.1"` → `0.0.1 ..< 1.0.0`, i.e. *no protection at all*. A first tag of
  `0.0.1` gives consumers a choice between a band that breaks immediately and a
  band that protects nothing.
- **`0.1.0` is the better first tag.** `.upToNextMinor(from: "0.1.0")` →
  `0.1.0 ..< 0.2.0` is a *meaningful* "patches on the 0.1 line" contract — the
  disciplined pre-1.0 pin. It also gives the package room to express breaking
  pre-1.0 change as a minor bump (`0.1 → 0.2`) on an axis consumers can actually
  pin to.

Three further reasons favor `0.1.0`:

1. **Institute first tags are readiness-gated.** Apple's `0.0.x` signals *raw
   incubation, no promises*. An institute first tag is cut only **after** the full
   `release-readiness` gate ([RELEASE-001]/[RELEASE-002]: audit, forums-review,
   feature-complete, locked decisions). That is materially more mature than
   incubation; `0.1.0`'s "first shaped surface" signal (PointFree convention) is
   the honest one.
2. **It resolves the institute's own inconsistency.** The existing tags are split
   `0.0.1`-start (`rfc-5322`, `rfc-1035`, `rfc-2822`, …) vs `0.1.0`-start
   (`rfc-3986`, `rfc-2045`, …) `[Verified: 2026-06-02]`. Standardizing new first
   tags on `0.1.0` ends the coin-flip.
3. **It still honors SemVer §4.** `0.1.0` is squarely 0.x — "anything may change"
   still holds; the institute is not over-promising. `0.1.0` is the *first
   shaped-but-unstable* surface, not a stability claim.

> **Recommendation (Q2):** new packages' **first tag is `0.1.0`**. Already-tagged
> packages **continue their existing line** (do not reset — see Q5). Couple this
> with a **consumer-pin discipline**: pre-1.0 deps are pinned `.upToNextMinor(from:
> "0.Y.0")`, never bare `from:` (which on 0.x silently auto-adopts breaking
> minors). Graduate a package to `1.0.0` when its API stops churning; that is the
> answer to the ZeroVer critique.

### Q3 — Sequencing: visibility-flip × tag × pin-form, bottom-up

**The one-form-per-package invariant.** At any instant, **every** reference to a
given package `P` across the ecosystem uses the **same** requirement form — all
`branch:"main"` (pre-tag) **or** all `from:"X.Y.Z"` (post-tag), never a mix, and
never `branch:` + version for the same package. This is not stylistic — it is a
**reproducibility** constraint, and the failure mode is *silent*, not loud
`[Verified: 2026-06-02, Swift 6.3.2]`: when `P` is referenced by `branch:"main"`
in one part of a resolution closure and by `from:"X.Y.Z"` in another, **the branch
requirement wins** — SwiftPM resolves `P` to `main` HEAD (exit 0, no error, no
warning), and every `from:` consumer in that closure silently gets bleeding-edge
`main` instead of the tagged version it pinned. (This is distinct from
[PKG-DEP-002]'s same-name-different-*source* identity-collision stall, which the
now-universal `url`-form plus the one-source discipline already avoid — the
branch-wins override is a separate, verified hazard.) Because the defeat is silent,
a half-switched state is *worse* than a crash: it does not announce itself, so the
switch wave below MUST run to completion per `P`.

**Decouple visibility from tagging — two bottom-up passes.** The visibility flip
and the tag answer different readiness questions hit at different times:

- A **visibility flip** requires only **closure-completeness** (every dep already
  public). It does *not* require API stability. And it is the *only* way to get
  real CI + outsider signal ([CI-094]: private repos get no CI; the flip is itself
  the CI-activation step).
- A **tag** requires **API stability** + the `release-readiness` gate.

Coupling them forces tagging before any public soak — premature, and it maximizes
the `from:`-cascade churn from post-tag breaks. So:

> **Pass 1 — Visibility (bottom-up).** Flip packages private→public in dependency
> order (L1 primitives → L2 specs' new deps → L3 foundations), leaving everything
> on `branch:"main"`. This **back-fills the inverted frontier**: the already-public
> L2 specs become outsider-buildable again as their (currently private) L1 closure
> goes public underneath them. After each flip, verify with a **clean-room resolve**
> (Q4).
>
> **Pass 2 — Tagging (bottom-up, later, per-package).** As each package's API
> stabilizes, tag it (`0.1.0` for new packages; continuation for tagged ones), then
> run the **atomic pin-form switch** for that package.

**The per-package atomic pin-form switch** (the `branch:"main"` → `from:` flip),
performed when package `P` receives a tag:

1. **Precondition:** `P`'s entire closure is public, and `P`'s own deps are in
   their final form (`branch:"main"` for still-untagged-public deps, `from:` for
   tagged deps). `P`'s `main` resolves clean-room.
2. **Tag** `P@version` ([CI-052]: explicit per-action authorization).
3. **Enumerate** every consumer of `P` ecosystem-wide: `grep -rl
   'url:.*<P>\.git' */Package.swift` (analogous to the [PKG-NAME-007]/[PKG-NAME-013]
   pre-rename enumeration greps — transitive references included).
4. **Switch wave** ([CI-050] authorization, [CI-051] surgical commits, [CI-056]
   per-package build-verify): in one bounded wave, rewrite **every** consumer's
   reference to `P` from `.package(url: "…/<P>.git", branch: "main")` to
   `.package(url: "…/<P>.git", .upToNextMinor(from: "version"))`. Run the wave to
   completion — do **not** leave `P` referenced by `branch:` in some consumers and
   `from:` in others (that is the silent branch-wins-override window verified in the
   invariant above: `from:` consumers sharing a closure with a `branch:` reference
   to `P` get `main` HEAD, not the tag).

The invariant is preserved because the switch is **per dependency `P`, atomic
across all of `P`'s consumers**: `P` is `branch:`-everywhere until step 4, then
`from:`-everywhere after. A consumer `C` can itself still be untagged-public on
`branch:"main"` while referencing `P` by `from:` — the invariant is about how `P`
is referenced, not about `C`'s own state.

This single model **subsumes** [PKG-DEP-001] (path-form was the *old* pre-publish
default; URL-form is now universal, so the live axis is `branch:` vs `from:`) and
[RELEASE-015]'s "switch to url-form at publish" (already done — the residual
switch is `branch:` → `from:`). It is the post-path→URL-conversion successor to
both.

### Q4 — The rolling-on-`main` public phase

During Pass 1, packages are public but untagged, consumed via `branch:"main"`. The
properties of this phase:

- **No reproducibility for HEAD-trackers.** `branch:"main"` resolves to whatever
  HEAD is *now*; and `Package.resolved` is gitignored ecosystem-wide ([CI-041] —
  libraries don't pin consumer graphs), so a consumer's `swift package update`
  pulls bleeding-edge `main` each time. This is the standard "unreleased package"
  experience and is **acceptable for a pre-tag phase if communicated** (the README
  states the package is pre-release; outsiders track `main` at their own risk).
- **Minimize the window per package.** The rolling-public phase is a *means* (CI
  activation + outsider smoke-testing), not an end. Tag each package as soon as its
  API is stable; do not hold a stable lower package on `branch:` waiting for an
  unstable higher one. *(This refines the principal's "keep everything `branch:`
  until primitives + foundations are stable": tag bottom-up as each package
  stabilizes — don't gate the whole ecosystem on the last package.)*
- **The clean-room resolve is the gate.** Because the mirror makes version
  requirements inert locally and CI resolves via an injected token, **neither
  local-green nor CI-green proves public-consumability** (see [Current
  State](#mirror--ci-token-resolution-model)). Before declaring any package
  publicly consumable, run a **no-token, mirror-bypassed resolve** (per memory
  `feedback_clean_room_resolve_not_redundant`: a real session with the mirror
  moved aside + ambient auth removed — *not* an injected token, *not* a temp-HOME
  hack). A public package whose closure still holds one private dep 404s for
  outsiders; only the clean-room resolve catches it.

### Q5 — Reconcile the existing standards-layer tags

The existing tags (`rfc-3986@0.3.6`, `rfc-5322@0.7.4`, … — ~68 tagged repos across
the standards orgs) are **real, immutable, internally-consistent releases**:
verified, `rfc-3986@0.3.6` pins its deps by `from:` on public `swift-standards/*`
URLs. Disposition:

- **KEEP them.** Do not delete, orphan, or re-cut. Tags are immutable references
  outsiders may pin to ([CI-052]); deleting them breaks any such consumer and
  destroys real release history. Resetting `rfc-3986` to a "universal 0.1.0" is a
  **version regression** and is rejected with Model A.
- **Continue each line forward.** When a standards spec is re-tagged after its new
  (post-modularization) closure goes public, the next tag *continues* its line
  (`rfc-3986 → 0.3.7` or `0.4.0`), cut from the reconciled `main`. Because the
  dependency graph changed structurally, a **minor** bump (`0.4.0`) is the honest
  signal, but in 0.x this is author discretion (SemVer §4).
- **Reconcile `main`'s drift bottom-up, not by re-cutting tags.** The drift
  (`main` pulling private `parser-primitives`/`ascii-serializer-primitives` via
  `branch:"main"`) is fixed by Pass 1: flip those L1 primitives public, then `main`
  resolves clean-room again; later, when they tag, the per-package switch (Q3) puts
  them on `from:`. The tag was never broken; the *foundation under main* was, and
  that is what gets re-closed.
- **Bitrot caveat `[Verified: 2026-06-02]`.** Some existing tags pin dep URLs that
  may since have moved org — e.g. `rfc-3986@0.3.6` references
  `swift-standards/swift-incits-4-1986`, but INCITS specs now live under the
  `swift-incits` authority org. GitHub repo-move redirects *may* keep these
  resolving; this is **not verified** and is flagged as a residual (see
  [Residual](#residual--open-questions)). It does not change the "keep the tags"
  disposition — an old tag that no longer resolves is a historical artifact, not a
  reason to rewrite history.

---

## Outcome

**Status: RECOMMENDATION.** The principal decides; nothing here is executed.

### Recommended strategy (the one-paragraph form)

Adopt **independent per-package semantic versioning** (Model B), not a synchronized
universal version. Run **two bottom-up passes**: first flip visibility
private→public in dependency order, leaving everything on a rolling `branch:"main"`
(this back-fills the inverted frontier so the already-public L2 specs become
outsider-buildable again); then, later and per-package, **tag each package as its
API stabilizes** and atomically switch all of that package's consumers from
`branch:"main"` to `.upToNextMinor(from: "X.Y.Z")`. New packages' first tag is
**`0.1.0`**; already-tagged packages **continue their existing line**. Keep the
existing standards tags. The principal's "coordinated launch" is preserved as a
**bottom-up tagging campaign** (a timing event), with **independent version
numbers** (not a synchronized number).

### How this scores the principal's working assumption

| Principal's assumption | Verdict | Why |
|------------------------|---------|-----|
| Go public *first* on `main` | **Affirmed** | Forced by [CI-094] — the flip is the CI-activation step; you cannot get real signal while private |
| Keep `branch:"main"` through a rolling pre-tag phase | **Affirmed, refined** | Correct as a *phase*; but tag **bottom-up per package** as each stabilizes — don't gate the whole ecosystem on "primitives + foundations all stable" |
| Tag *much later* (after soak) | **Affirmed** | Long pre-tag soak on `branch:"main"` lets the worst 0.x churn happen *before* any version contract exists |
| **One *universal* first tag** | **Rejected** | The only structural error. ~68 independent tag lines already exist; SwiftPM has no lockstep primitive; lockstep is unreachable without regressing real releases. Replace "universal *version*" with "coordinated *campaign* of independent tags" |

### Concrete phase model (recommendation — staged, not executed)

> Each `git tag`, each `gh repo edit --visibility public`, and each switch-wave
> push is a **per-action authorization** gate ([RELEASE-004], [CI-050], [CI-052]).
> This doc stages the sequence; it does not run it.

- **Phase 0 — Pin-form invariant guard (continuous).** One form per package; the
  live axis is `branch:"main"` (pre-tag) vs `.upToNextMinor(from:)` (post-tag). 0
  `path:` deps (already true). No bare `from:` on 0.x deps.
- **Phase 1 — Bottom-up visibility back-fill.** Flip L1 primitives (and the L3
  foundations / L1 packages the public L2 specs now depend on) private→public, in
  dependency order, on `branch:"main"`. Gate each flip on a **clean-room resolve**.
  Outcome: the inverted frontier is closed — every public package's `main` is
  outsider-buildable.
- **Phase 2 — Rolling-public soak.** All-public on `branch:"main"`; CI now real;
  outsiders can smoke-test HEAD (README marks pre-release). Per-package readiness
  drives pacing (`launch-flow-assessment`); no global gate.
- **Phase 3 — Bottom-up tagging campaign.** As each package's API stabilizes, tag
  it (`0.1.0` new / continuation tagged), then run its **atomic switch wave**
  (`branch:"main"` → `.upToNextMinor(from:)` across all consumers). Bottom-up so a
  package is tagged only after its deps are.
- **Phase 4 — Graduation.** Packages whose API has stopped churning bump to
  `1.0.0` — the exit from 0.x and the answer to the ZeroVer critique.

### What this supersedes ([META-004])

- `dual-mode-package-publication.md` v2.0.0 — **layer-lockstep versioning**
  (→ independent, Q1) and the **release-branch path→URL transform** (→ obviated by
  the completed in-place path→URL conversion; the residual switch is `branch:"main"`
  → `from:`).
- `git-subtree-publication-pattern.md` v2.0.0 — the path→URL **release-branch
  mechanism** (already done in-place on `main`); its deferred version-strategy
  question is answered here.

A follow-up [SKILL-LIFE] pass should annotate those two docs' `_index.json`
entries `SUPERSEDED` (by this doc) and update [PKG-DEP-001]/[RELEASE-015] cross-
references to point at this strategy as the post-conversion successor. Per the
handoff's "Do Not Touch," that annotation is **not** performed by this doc.

### Residual — open questions

These are flagged per [RES-027] (premise vs direction). The premises that future
work will rely on carry an explicit verification cost:

1. **Old-tag URL bitrot (premise, unverified).** Some existing tags pin dep URLs
   at pre-reorg org locations (e.g. `rfc-3986@0.3.6` → `swift-standards/swift-incits-4-1986`,
   now under `swift-incits`). Whether GitHub repo-move redirects keep them
   resolving is **unverified**. A ≤1-hour clean-room resolve of two or three old
   tags would confirm or refute before any claim that "the existing tags are
   outsider-resolvable today" is relied upon. (Distinct from "the tags are
   internally consistent," which *is* verified.)
2. **Switch-wave tooling (direction).** The per-package atomic switch (Q3) wants a
   script: enumerate consumers of `P`, rewrite `branch:"main"` → `.upToNextMinor`,
   per-package build-verify, surgical-commit, push wave. This is the natural
   automation target once Phase 3 begins; out of scope for this recommendation.
3. **`Version.Semantic` consumption (direction).** When the institute tags via
   tooling, that tooling is the second consumer of `swift-version-primitives`
   (`2026-05-12-swift-package-and-version-primitives-design.md`) — a clean way to
   close that doc's second-consumer hurdle. Noted, not required by this doc.

---

## References

Internal (this corpus):
- `release-roadmap-swift-file-system.md` — per-package independent release ordering (affirmed).
- `dual-mode-package-publication.md` — lockstep + release-branch (superseded here).
- `git-subtree-publication-pattern.md` — path→URL mechanism (mechanism superseded).
- `spm-nested-package-publication.md` — separate-repo-per-package is forced by SPM.
- `2026-05-12-swift-package-and-version-primitives-design.md` — typed `Version.Semantic` (orthogonal).
- `launch-flow-assessment-2026-05-08.md` — per-package readiness pacing.
- Skills: `swift-package` [PKG-DEP-001], [PKG-NAME-010]; `release-readiness`
  [RELEASE-004], [RELEASE-015]; `ci-cd-workflows` [CI-041], [CI-050], [CI-052],
  [CI-094], [CI-095]; `swift-package` [PKG-DEP-002].
- Memory: `feedback_clean_room_resolve_not_redundant`,
  `feedback_algebra_consolidation_and_tagged_deps`,
  `project_no_path_deps_in_public_packages`.

External (verified to exist / read 2026-06-02):
- Semantic Versioning 2.0.0, §4 (major version zero) — https://semver.org/
- SE-0158, Package Manager Manifest API Redesign (version requirement API) —
  https://github.com/swiftlang/swift-evolution/blob/main/proposals/0158-package-manager-manifest-api-redesign.md
- `upToNextMajor(from:)` — Apple Developer Documentation —
  https://developer.apple.com/documentation/packagedescription/package/dependency/requirement-swift.enum/uptonextmajor(from:)
- Package — Swift Package Manager — https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html
- "Say No to ZeroVer: Start with 1.0.0" — https://blog.nytsoi.net/2026/04/03/say-no-to-zero-ver/
- "Problems with the Magic Zero" (semver/semver#221) — https://github.com/semver/semver/issues/221
- *Lost in Zero Space — An Empirical Comparison of 0.y.z Releases in Software Package Distributions* — https://arxiv.org/pdf/2101.00836

Empirical primary source (run 2026-06-02, Swift 6.3.2): scratch-package
resolution test of `from:` / `.upToNextMajor` / `.upToNextMinor` against 0.x tags
(`0.1.0 0.1.1 0.2.0 0.9.0`) — results in [Prior Art](#external-prior-art) and Q2.
