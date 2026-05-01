# External Upstream Fork Heritage

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

### Trigger

`swift-tagged-primitives` was authored as a from-scratch re-implementation
of the phantom-typed wrapper concept popularized by Point-Free's
[`swift-tagged`](https://github.com/pointfreeco/swift-tagged). The
package's own research doc
([`comparative-analysis-pointfree-swift-tagged.md`](../../swift-primitives/swift-tagged-primitives/Research/comparative-analysis-pointfree-swift-tagged.md))
explicitly states "Our implementation began as a fork of the same concept"
— but the *git*-level relationship is independent: tagged-primitives'
publication commit is an orphan, with no shared ancestry to
`pointfreeco/swift-tagged`. The conceptual debt is documented; the lineage
is invisible to consumers reading `git log` or browsing the GitHub repo.

The user (2026-04-30) raised the question: should the package be on a
*fork* of `pointfreeco/swift-tagged` so the heritage is encoded in git
ancestry, GitHub's "forked from" badge, and the consumer's first
impression of the repo? And — more generally — what is the right pattern
for *any* future Institute package whose design materially derives from
an external upstream we don't own?

### Scope

Ecosystem-wide [RES-002a]. Applicable to any Swift Institute package
whose design draws materially from an external (non-Institute, non-owned)
upstream Swift package, where heritage attribution is a value the package
should encode at the git/GitHub level rather than leaving entirely to
documentation prose.

The current concrete instance is `swift-tagged-primitives` ↔
`pointfreeco/swift-tagged`. Future candidates that may follow the same
pattern: any Institute package whose conceptual seed is an external
project (Swift Algorithms, Swift Collections, swift-async-algorithms,
Apollo, Vapor patterns, etc.) where the divergence is principled but
the lineage is real.

This rule does **not** apply to packages whose design originates
entirely within the Institute (`swift-carrier-primitives`,
`swift-ownership-primitives`, etc.), nor to packages migrated from an
*owned* upstream (e.g. `coenttb/*` → `swift-foundations/*`) — those are
covered by [`coenttb-ecosystem-heritage-transfer-plan.md`](./coenttb-ecosystem-heritage-transfer-plan.md)
and [`git-history-transfer-patterns.md`](./git-history-transfer-patterns.md).

### Precedent risk

Medium-high. The decision encodes a permanent git-ancestry relationship
to an external project we do not control. A wrong choice in either
direction is hard to reverse cleanly:

- **False-positive (fork when independent suffices)**: locks the
  Institute package into a public fork relationship with an upstream that
  may evolve, archive, or rename — and ties the package's GitHub
  identity to an unrelated third-party history that bears little
  resemblance to current code.
- **False-negative (independent when fork is warranted)**: discards
  legitimate heritage signal that consumers and the upstream community
  rely on for trust, attribution, and license compliance.

The recipe also touches GitHub-side state (fork creation, repo deletion,
rename) that is not reversible without coordination with the upstream
owner.

---

## Question

What procedure should the Swift Institute use when an Institute package's
design materially derives from a non-owned external upstream Swift
package, and the heritage should be encoded at the git / GitHub level
rather than only in research prose?

### Sub-questions

- **SQ1**: When does external-upstream heritage warrant a *git-level*
  fork relationship (vs documentation-only attribution)?
- **SQ2**: What git mechanic best preserves upstream lineage while
  letting the Institute publication be a clean single-commit publication
  (matching the carrier / tagged publication-squash discipline)?
- **SQ3**: How does this compose with the existing publication-squash
  workflow (`Initial publication: <pkg>` orphan commit pattern)?
- **SQ4**: What attribution + license obligations follow, and how are
  they discharged at the README / LICENSE / Research level?
- **SQ5**: How is divergence managed post-fork? Are upstream merges ever
  taken?

---

## Prior Art Survey [RES-021]

### Within the Swift Institute corpus

- [`coenttb-ecosystem-heritage-transfer-plan.md`](./coenttb-ecosystem-heritage-transfer-plan.md)
  (Tier 2 RECOMMENDATION, 2026-04-23) — codifies heritage preservation
  for *owned* upstream (coenttb/* → swift-institute orgs) via
  `gh api .../transfer`. Explicitly notes transfer-with-mechanics is
  unavailable when source is not owned: "fork-then-merge is a fallback
  only when the source repo must remain authoritative." This rule is
  what that fallback case looks like.
- [`git-history-transfer-patterns.md`](./git-history-transfer-patterns.md)
  (Tier 2 RECOMMENDATION, 2026-04-22) — Section A explicitly compares
  `gh api .../transfer` vs `gh repo fork` + merge. Concludes transfer
  dominates for owned repos. Does not codify the fork case as a
  first-class pattern; this rule fills that gap.
- [`comparative-analysis-pointfree-swift-tagged.md`](../../swift-primitives/swift-tagged-primitives/Research/comparative-analysis-pointfree-swift-tagged.md)
  (Tier 2 DECISION, 2026-02-26) — the per-package divergence analysis
  for tagged-primitives. Documents *what* differs from upstream and
  *why* every divergence is principled. The complement to this rule:
  divergence-content lives there; lineage-shape lives here.
- [`tagged-types-merits-completeness-and-naming.md`](../../swift-primitives/swift-tagged-primitives/Research/tagged-types-merits-completeness-and-naming.md)
  (Tier 2 RECOMMENDATION) — establishes that tagged-primitives'
  lineage is "inspired by Point-Free" and the divergences are
  load-bearing for the Institute primitives layer.

### External prior art

- [GitHub Forks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/about-forks)
  — fork creates an independent repository with a server-side
  parent-pointer ("forked from <upstream>") and shared object database
  (commits, blobs). The fork's history at creation time is the
  upstream's history at that instant. The fork can diverge, force-push,
  rename — the parent-pointer is decorative, not load-bearing on the
  fork's own git operations.
- [GitHub Fork Maintenance](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/syncing-a-fork)
  — forks may "sync" with upstream via merge or rebase. Optional, not
  required. Many divergent forks (LineageOS forks of AOSP, MariaDB
  forking MySQL) deliberately stop syncing once the divergence is
  large enough that merges become net-negative.
- [Linus Torvalds on forks vs reimplementation](https://lwn.net/Articles/838127/)
  (illustrative, not load-bearing) — codifies the Linux community's
  norm: when the divergence is large enough that you're "writing a
  different program," independence is honest; when the lineage is
  real, fork attribution is honest. The third option — "independent
  reimplementation that quietly tracks an inspiration" — is the worst
  of both worlds for community trust.
- License-attribution conventions: MIT (Point-Free's license; very
  permissive — requires inclusion of the LICENSE text + copyright
  notice in derived works), Apache 2.0 (the Institute's standard for
  primitives — compatible with MIT under the "include both" rule).

[Verified: 2026-04-30] — Point-Free's `pointfreeco/swift-tagged`
license confirmed as MIT via direct GitHub fetch:
`https://github.com/pointfreeco/swift-tagged/blob/main/LICENSE`.

---

## Analysis

### A. Options enumeration

| Option | Mechanic | Git lineage to upstream | GitHub "forked from" badge | Reversible | Attribution discipline |
|---|---|:---:|:---:|---|---|
| **1. Independent re-implementation** | Orphan publication commit, no shared ancestry. README + research docs cite upstream. | None | No | Trivially | Documentation only; consumers reading `git log` see no upstream signal |
| **2. Fork + squash on top** | `gh repo fork` upstream → apply Institute publication state on top of fork point as a single commit | Full upstream history below the publication squash | Yes | Reversible by deleting the fork (no upstream impact); locally-recoverable from the publication commit | README + LICENSE + research docs cite upstream; git lineage carries the receipts |
| **3. Fork + orphan-replace** | `gh repo fork` upstream → orphan branch replaces all files with Institute state → force-push | None (orphan replaces ancestry) | Yes | Same as Option 1 except for the badge | Same as Option 1; the fork badge is the only signal |
| **4. Mirror-and-sync** | Fork upstream + periodically merge upstream changes into Institute branch | Live, ongoing | Yes | Hard | Attribution embedded in every merge commit |
| **5. Transfer (`gh api .../transfer`)** | Move upstream repo into Institute org | Full | Lost (the repo IS the upstream now) | Reversible until 90-day window | Attribution required for license compliance only |

Option 5 is unavailable when the upstream is not owned by us — included
for completeness only. Options 1, 2, 3, 4 are the live alternatives.

### B. Evaluation criteria

For an Institute package with material external-upstream lineage, the
right shape encodes **all four** of the following at minimum:

| Criterion | Why it matters |
|---|---|
| **Heritage signal at first impression** | A consumer landing on the GitHub repo or `git log` should see the upstream relationship without reading the README or research docs. The Institute does not pretend independent re-implementation when the lineage is real. |
| **License-compliance discipline** | MIT and Apache 2.0 (and most permissive licenses) require attribution in derivative works. Git ancestry is a stronger attribution-receipts mechanism than README prose alone — the LICENSE history is part of the derivative's history. |
| **Divergence ergonomics** | The Institute package diverges substantially (Foundation-independence, `~Copyable` admission, primitives-layer constraints, etc.). Merging upstream changes is generally net-negative once divergence is established. The shape must accommodate this. |
| **Single-commit publication discipline** | The Institute publishes packages as a single "Initial publication" orphan commit (carrier-primitives `d54cf79`, tagged-primitives `9262f11`). The heritage shape must compose with this discipline, not break it. |

### C. Comparison

| Criterion | 1. Independent | 2. Fork + squash | 3. Fork + orphan | 4. Mirror-and-sync |
|---|:---:|:---:|:---:|:---:|
| Heritage signal at first impression | ✗ | ✓ | Half (badge yes, history no) | ✓ |
| License-compliance discipline | Manual (README only) | ✓ (LICENSE in history) | Manual (README only) | ✓ |
| Divergence ergonomics | ✓ | ✓ | ✓ | ✗ |
| Single-commit publication discipline | ✓ | ✓ (squash on top of fork point) | ✓ | ✗ (publication is one of many merges) |
| Fits "we are not the upstream" stance | ✓ | ✓ | ✓ | ✗ (implies tracking) |
| Reversibility | Trivial | Easy | Easy | Hard |

**Option 2 dominates** on every axis except triviality of reversal —
and reversal of Option 2 is "delete the fork and re-publish as Option 1"
which is no harder than the original Option 1 publish. Option 3 trades
heritage signal for surface simplicity but produces a confusing artifact
(GitHub badge says "forked from X" but `git log` shows no shared
ancestry — the worst of both worlds for a curious consumer). Option 4
is for mirror-style tracking forks, which is not what Institute
packages are.

### D. Recommended composition with publication-squash

Option 2 composes cleanly with the existing publication-squash workflow
(orphan publication commit on top of pre-publication arc):

```
[upstream commit history, intact]
    │
    │   (fork point — the upstream commit at fork-creation time)
    │
    ◇ ← Initial publication: <pkg> [Institute orphan-equivalent commit]
    │   (single commit replacing the entire post-fork tree with the
    │    Institute's publication state; parent is the fork point)
    │
    ◇ ← (subsequent Institute work, optional Phase 7a-style commits, etc.)
```

The Institute publication commit's *parent* is the upstream's fork
point, not orphan. The Institute's tree contents differ entirely from
the parent's tree (the publication squash replaces all source). But
`git log` traverses the parent pointer and surfaces the upstream
history; `git blame` on a publication commit's file shows the publication
commit (Institute author); `git log -- <upstream-only-file>` shows the
upstream history of that file (which the publication may have removed).

The receipts mechanism is the parent-pointer chain; the publication's
self-contained state is the publication commit's tree.

### E. Attribution + license obligations

For an Option-2 fork, the following discipline applies:

| Artifact | Obligation | Mechanism |
|---|---|---|
| **LICENSE file** | If upstream license requires preservation (MIT, BSD), the publication commit MUST include the upstream LICENSE text + copyright. Institute packages are Apache 2.0; the LICENSE for an MIT-derived package becomes a combined "Apache 2.0 (Institute) + MIT (upstream attribution)" file. | Append upstream LICENSE text + copyright notice into the Institute LICENSE.md; reference both in the README. |
| **README** | Explicit "Forked from <upstream-url>" line + link, plus citation of the comparative-analysis research doc. | Top of README, under the one-liner: `> Forked from [<upstream/repo>](url) — see [<comparative-analysis>](./Research/...) for divergence rationale.` |
| **Research/** | Comparative analysis doc establishing the divergence rationale (this is the "why we forked" record). | Pre-existing `comparative-analysis-<upstream>.md` per-package research doc. |
| **GitHub repo description** | Brief acknowledgement; "fork of X with Y divergences" or similar. | Set via `gh repo edit --description`. |
| **Package.swift** | No special obligation (license attribution is at the LICENSE level, not the manifest). | n/a |

### F. Divergence policy after fork

After the publication squash lands on top of the fork point, the
Institute package and its upstream **do not sync**. Specifically:

- **No `git merge upstream/main`**: divergence is principled and
  permanent.
- **No `git pull --rebase upstream/main`**: same.
- **Upstream releases / tags do not propagate**: the Institute tags its
  own releases (`0.1.0`, etc.); upstream tags remain visible in `git tag`
  but are not the Institute's release line.
- **Upstream commits remain in `git log` below the fork point**: this
  is the heritage record, not a live tracking mechanism.

If the upstream lands a change that the Institute wants, the Institute
authors an Institute commit that ports / re-implements the change,
optionally citing the upstream commit SHA in the commit message. The
fork relationship is heritage-only; substantive code flows are
re-authored, not merged.

### G. Concrete application: `swift-tagged-primitives`

The current state (post-2026-04-30 publication squash):

| Aspect | Current state | Target state (this rule's recommendation) |
|---|---|---|
| GitHub repo | `swift-primitives/swift-tagged-primitives` (PRIVATE) — orphan publication `9262f11` | Same repo, but parent-pointer chain to `pointfreeco/swift-tagged` via fork relationship |
| Git ancestry | Orphan (no parent) | Parent = upstream fork point (most recent upstream commit at fork time) |
| GitHub fork badge | Absent | "Forked from pointfreeco/swift-tagged" |
| README heritage line | Absent (Key Features bullets describe inspiration; no top-of-README citation) | Top-of-README line: `> Forked from [pointfreeco/swift-tagged](url) — see [comparative-analysis-pointfree-swift-tagged.md](./Research/...) for divergence rationale.` |
| LICENSE | `Apache 2.0` only | Apache 2.0 (Institute) + MIT attribution (upstream) — combined LICENSE.md or NOTICE-style append |
| Research doc | `comparative-analysis-pointfree-swift-tagged.md` exists (DECISION 2026-02-26) | Same; cited from README |

The transition workflow (each step a separate per-action authorization
per `feedback_no_public_or_tag_without_explicit_yes`):

1. **Verify license compatibility** — `pointfreeco/swift-tagged` LICENSE
   is MIT (verified 2026-04-30). MIT requires preservation of the
   copyright notice in derivative works. Compatible with Apache 2.0.
2. **Preserve current state locally** — note the current orphan
   publication commit `9262f11` SHA; tag-or-branch it locally as
   recovery anchor in case the fork operation needs to be unwound.
3. **Decide on naming**: the existing repo is `swift-primitives/swift-tagged-primitives`.
   The fork from `pointfreeco/swift-tagged` would create
   `swift-primitives/swift-tagged` (or be force-named via
   `--fork-name swift-tagged-primitives`). The rename-during-fork form
   is preferred to keep the existing name.
4. **Vacate destination** — the existing `swift-primitives/swift-tagged-primitives`
   must be deleted (or renamed to a temporary holding name) to allow
   the fork to take its place. Per Institute auth gates: this step is
   destructive, requires explicit `YES DO NOW DELETE` per
   `feedback_no_public_or_tag_without_explicit_yes`.
5. **Fork with rename** —
   `gh repo fork pointfreeco/swift-tagged --org swift-primitives --fork-name swift-tagged-primitives --clone=false`.
   This creates the fork; visibility inherits source (PUBLIC). The
   Institute repo will become PUBLIC at this step — the user has
   reserved public-flip authorization separately, so this step itself
   constitutes the public flip and requires the same authorization.
6. **Apply the publication state on top** — clone the new fork; apply
   the contents of `9262f11` (Institute publication tree state) as a
   single new commit on top of the fork's `main`. The recipe mirrors
   the rename-and-reconcile mechanic from the heritage-transfer plan
   ([`coenttb-ecosystem-heritage-transfer-plan.md`](./coenttb-ecosystem-heritage-transfer-plan.md)
   §"Apply-on-top recipe notes"):
   ```
   git rm -rf .
   git checkout <publication-commit> -- .
   git add -A
   git commit -m "Initial publication: swift-tagged-primitives (fork of pointfreeco/swift-tagged)"
   git push origin main
   ```
   (Plumbing variant via `commit-tree` + `update-ref` is the atomic
   alternative — see the heritage-transfer plan for the script.)
7. **Update README + LICENSE** — add the heritage line; combine
   licenses; commit as a follow-on commit.
8. **Verify external-build** — `swift package resolve` from a scratch
   consumer; CI green.

The transition is reversible at every step before step 5; after step 5,
the unwind is "delete the fork, restore from the local tag — repo
returns to PRIVATE Option-1 state." Reversibility is preserved as
long as no consumer has bound to the new URL.

---

## Outcome

**Status**: RECOMMENDATION.

**Primary recommendation**: For Institute packages whose design
materially derives from a non-owned external upstream Swift package,
adopt **Option 2 (Fork + publication-squash on top)** as the canonical
heritage shape. Apply the attribution discipline in §E and the
divergence policy in §F.

**Concrete application — swift-tagged-primitives**:
re-establish on top of `pointfreeco/swift-tagged` per §G's eight-step
workflow. Each destructive step (delete current repo, fork-with-rename,
public visibility flip) is a separate per-action authorization gate
per the existing Institute discipline; this research doc does not
authorize execution.

**Negative space — when NOT to fork**:

| Condition | Disposition |
|---|---|
| Institute package's design originates entirely within the Institute (no external lineage) | Independent (Option 1) |
| Upstream is owned by the Institute / by `coenttb/*` | Transfer per [`coenttb-ecosystem-heritage-transfer-plan.md`](./coenttb-ecosystem-heritage-transfer-plan.md) (Option 5 / transfer-rename-and-reconcile) |
| Upstream license is incompatible with Apache 2.0 (GPL, AGPL) | Independent (Option 1) — fork would create license-compliance burden the Institute is not equipped to carry |
| Upstream is abandoned / archived | Fork is permitted (Option 2) but the heritage signal is largely historical; pragmatically Option 1 with strong README attribution may be preferable since the upstream is not a live community |
| Lineage is "we read the README and got an idea" rather than "we re-implemented their type with our constraints" | Independent (Option 1); citation in README is sufficient |

The decision test for the rule firing: *the Institute package's
production code closely parallels the upstream's structure / API
shape / type signatures, AND the external community / consumer set
overlaps materially with the upstream's, AND the upstream license
permits derivative works with attribution.* All three required.

**Future work**:

- Codify this RECOMMENDATION into a `swift-package-heritage` skill
  (peer to `swift-package`) so the rules surface at write-time for
  any package author starting from external lineage.
- Maintain a per-package heritage roster within
  `swift-institute/Research/` listing each Institute package's heritage
  disposition (independent / forked / transferred) once the roster has
  more than one entry.
- Re-evaluate the negative-space cases when a real future candidate
  surfaces (Swift Algorithms-derived primitive, etc.) — this rule is
  drafted on the strength of one concrete case (tagged-primitives) and
  may need broadening once a second case lands.

## References

### Primary sources

- [GitHub — About forks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/about-forks)
- [GitHub — Syncing a fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/syncing-a-fork)
- [pointfreeco/swift-tagged LICENSE (MIT)](https://github.com/pointfreeco/swift-tagged/blob/main/LICENSE) — verified 2026-04-30
- [Apache License 2.0 — Section 4 (NOTICE / attribution)](https://www.apache.org/licenses/LICENSE-2.0#redistribution)

### Internal cross-references

- [`coenttb-ecosystem-heritage-transfer-plan.md`](./coenttb-ecosystem-heritage-transfer-plan.md) — owned-source heritage transfer (Tier 2 RECOMMENDATION); this rule's complement.
- [`git-history-transfer-patterns.md`](./git-history-transfer-patterns.md) — section A explicitly discusses transfer vs fork-then-merge; this rule formalizes the fork case as a first-class pattern, not a fallback.
- [`comparative-analysis-pointfree-swift-tagged.md`](../../swift-primitives/swift-tagged-primitives/Research/comparative-analysis-pointfree-swift-tagged.md) — the per-package divergence content.
- [`tagged-types-merits-completeness-and-naming.md`](../../swift-primitives/swift-tagged-primitives/Research/tagged-types-merits-completeness-and-naming.md) — "inspired by Point-Free" framing.

### Related skills

- `swift-package` skill `[PKG-NAME-*]` / `[PKG-DEP-*]` — package shape conventions; this rule governs the shape's *origin*, not its content.
- `release-readiness` skill — publication-squash discipline; this rule composes with it (the Institute publication is still a single commit on top of the fork point).

## Blog Potential

This research has been captured as a blog post:

- [BLOG-IDEA-075: Forked from: what heritage means at the Swift Institute](../Blog/Published/2026-04-30-forked-from.md) — Pattern Documentation, published 2026-04-30. The post translates this RECOMMENDATION into public-facing prose grounded in `swift-tagged-primitives` as the case study. Internal rule IDs (`[HERITAGE-001]` – `[HERITAGE-007]`) stay out of the published prose per `feedback_blog_voice`; the post cites this research doc as the public anchor.
