# Coenttb Stage 1 Dep-Visibility Audit

<!--
---
version: 1.0.0
last_updated: 2026-05-04
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide (Phase II.5 transfer execution)
---
-->

<!--
Changelog:
- v1.0.0 (2026-05-04): initial Stage 1 audit per
  `coenttb-ecosystem-heritage-transfer-plan.md` v1.3.0 §Per-Package Start
  Conditions row "Dep-visibility audit complete for destination's
  Package.swift". Covers Phase 2 (1 destination) + Phase 3 (9 destinations).
  Output: per-destination dep classification, master launch list,
  topological execution order.
-->

## Context

`coenttb-ecosystem-heritage-transfer-plan.md` v1.3.0 names the **Stage 1
dep-visibility audit** as the immediate prerequisite for Phase 2 + Phase 3
execution: *"Stage 1 dep-visibility audit is the immediate prerequisite;
its output determines the clusters."*

This document is that audit. It enumerates each of the 10 in-scope
destinations' direct `Package.swift` dependencies, classifies each
dependency by visibility, identifies the private ecosystem siblings whose
own launch processes must complete before each transfer can produce an
externally-buildable PUBLIC artifact, and proposes a topological execution
order honoring those constraints.

The audit is **read-only with respect to source code and GitHub
state** — pure analysis, no destructive operations.

## Question

For each of the 10 in-scope destinations (Phase 2 swift-render-primitives
+ 9 Phase 3 foundations packages), what does its `Package.swift`
depend on, what is the visibility state of each dependency, what
private-sibling launches must complete before its transfer can land
cleanly, and in what topological order can the 10 destinations be
processed?

## Analysis

### Methodology

1. Read each destination's `Package.swift` directly (10 manifests,
   2026-05-04). Enumerate direct dependencies (`.package(path:)` and
   `.package(url:)`).
2. For each ecosystem path-dep, query GitHub via `gh repo view ... --json
   visibility,isArchived` to confirm current visibility state
   (2026-05-04).
3. Classify each dep into one of five categories (below).
4. Identify the directed graph of in-scope-to-in-scope dependencies and
   produce a topological order.
5. Identify the master launch list (private siblings that need their
   own user-gated launch processes per
   `feedback_no_public_or_tag_without_explicit_yes`).

### Classification Categories

| Code | Category | Action required |
|---|---|---|
| **EXT-PUB** | URL dep to external public package (e.g., apple, swiftlang, pointfreeco) | None |
| **ECO-PUB** | Path dep (or URL dep) to PUBLIC ecosystem sibling | None |
| **ECO-PRIV** | Path dep to PRIVATE ecosystem sibling | **Launch process required before destination can be PUBLIC** |
| **IN-SCOPE** | Path dep to another in-scope destination (handled by topological order) | Order destinations so dependency transfers first |
| **MISSING** | Path target does not resolve | Investigate before transfer |

### Per-Destination Dep Tables

Notation: each row is a direct dep of the destination's `Package.swift`.
`EOL` column is current visibility (URL/PUBLIC/PRIVATE/in-scope).

#### Phase 2 — Primitives Layer

##### **Dest J — `swift-primitives/swift-render-primitives`**

| Dep | Path/URL | Class | Visibility |
|---|---|---|---|
| swift-ownership-primitives | path: ../swift-ownership-primitives | ECO-PUB | PUBLIC |
| swift-async-primitives | path: ../swift-async-primitives | **ECO-PRIV** | **PRIVATE** |

**Required launches before J transfer**: 1 (swift-async-primitives).
**In-scope deps**: none.

#### Phase 3 — Foundations Layer

##### **Dest A — `swift-foundations/swift-translating`**

| Dep | Path/URL | Class | Visibility |
|---|---|---|---|
| swift-bcp-47 | path: ../../swift-ietf/swift-bcp-47 | ECO-PUB | PUBLIC |
| swift-dependencies | path: ../swift-dependencies | **ECO-PRIV** | **PRIVATE** |

**Required launches before A transfer**: 1 (swift-dependencies).
**In-scope deps**: none.

##### **Dest B — `swift-foundations/swift-html-render`**

| Dep | Path/URL | Class | Visibility |
|---|---|---|---|
| swift-render-primitives | path: ../../swift-primitives/swift-render-primitives | **IN-SCOPE** | (Dest J) |
| swift-ascii | path: ../swift-ascii | **ECO-PRIV** | **PRIVATE** |
| swift-html-standard | path: ../../swift-standards/swift-html-standard | ECO-PUB | PUBLIC |
| swift-w3c-css | path: ../../swift-w3c/swift-w3c-css | ECO-PUB | PUBLIC |
| swift-dictionary-primitives | path: ../../swift-primitives/swift-dictionary-primitives | **ECO-PRIV** | **PRIVATE** |

**Required launches before B transfer**: 2 (swift-ascii,
swift-dictionary-primitives).
**In-scope deps**: J (must transfer first).

##### **Dest C — `swift-foundations/swift-svg-render`**

| Dep | Path/URL | Class | Visibility |
|---|---|---|---|
| swift-render-primitives | path: ../../swift-primitives/swift-render-primitives | **IN-SCOPE** | (Dest J) |
| swift-svg-standard | path: ../../swift-standards/swift-svg-standard | ECO-PUB | PUBLIC |
| swift-format-primitives | path: ../../swift-primitives/swift-format-primitives | **ECO-PRIV** | **PRIVATE** |
| swift-dimension-primitives | path: ../../swift-primitives/swift-dimension-primitives | **ECO-PRIV** | **PRIVATE** |
| swift-ascii-primitives | path: ../../swift-primitives/swift-ascii-primitives | **ECO-PRIV** | **PRIVATE** |
| swift-dictionary-primitives | path: ../../swift-primitives/swift-dictionary-primitives | **ECO-PRIV** | **PRIVATE** |

**Required launches before C transfer**: 4 (swift-format-primitives,
swift-dimension-primitives, swift-ascii-primitives,
swift-dictionary-primitives — last shared with B).
**In-scope deps**: J.

##### **Dest D — `swift-foundations/swift-css-html-render`**

| Dep | Path/URL | Class | Visibility |
|---|---|---|---|
| swift-html-render | path: ../swift-html-render | **IN-SCOPE** | (Dest B) |
| swift-css-standard | path: ../../swift-standards/swift-css-standard | ECO-PUB | PUBLIC |
| swift-layout-primitives | path: ../../swift-primitives/swift-layout-primitives | **ECO-PRIV** | **PRIVATE** |

**Required launches before D transfer**: 1 (swift-layout-primitives).
**In-scope deps**: B (transitively J).

##### **Dest E — `swift-foundations/swift-svg`**

| Dep | Path/URL | Class | Visibility |
|---|---|---|---|
| swift-svg-render | path: ../swift-svg-render | **IN-SCOPE** | (Dest C) |
| swift-dimension-primitives | path: ../../swift-primitives/swift-dimension-primitives | **ECO-PRIV** | **PRIVATE** |

**Required launches before E transfer**: 1 (swift-dimension-primitives —
shared with C).
**In-scope deps**: C (transitively J).

##### **Dest F — `swift-foundations/swift-css`**

| Dep | Path/URL | Class | Visibility |
|---|---|---|---|
| swift-css-html-render | path: ../swift-css-html-render | **IN-SCOPE** | (Dest D) |
| swift-html-render | path: ../swift-html-render | **IN-SCOPE** | (Dest B) |
| swift-css-standard | path: ../../swift-standards/swift-css-standard | ECO-PUB | PUBLIC |

**Required launches before F transfer**: 0 (none direct).
**In-scope deps**: D, B (transitively J).

##### **Dest G — `swift-foundations/swift-markdown-html-render`**

| Dep | Path/URL | Class | Visibility |
|---|---|---|---|
| swift-html-render | path: ../swift-html-render | **IN-SCOPE** | (Dest B) |
| swift-css | path: ../swift-css | **IN-SCOPE** | (Dest F) |
| swiftlang/swift-markdown | url: github.com/swiftlang/swift-markdown | EXT-PUB | PUBLIC |
| apple/swift-collections | url: github.com/apple/swift-collections | EXT-PUB | PUBLIC |

**Required launches before G transfer**: 0.
**In-scope deps**: B, F (transitively D, J).

##### **Dest H — `swift-foundations/swift-html`** *(33★, primary heritage concern)*

| Dep | Path/URL | Class | Visibility |
|---|---|---|---|
| swift-html-render | path: ../swift-html-render | **IN-SCOPE** | (Dest B) |
| swift-markdown-html-render | path: ../swift-markdown-html-render | **IN-SCOPE** | (Dest G) |
| swift-css | path: ../swift-css | **IN-SCOPE** | (Dest F) |
| swift-svg | path: ../swift-svg | **IN-SCOPE** | (Dest E) |
| swift-rfc-4648 | path: ../../swift-ietf/swift-rfc-4648 | ECO-PUB | PUBLIC |
| swift-whatwg-url | path: ../../swift-whatwg/swift-whatwg-url | ECO-PUB | PUBLIC |
| swift-color | path: ../swift-color | **ECO-PRIV** | **PRIVATE** |

**Required launches before H transfer**: 1 (swift-color).
**In-scope deps**: B, G, F, E (transitively all Phase-3 chain — H is
the deepest leaf).

##### **Dest I — `swift-foundations/swift-pdf-html-render`**

| Dep | Path/URL | Class | Visibility |
|---|---|---|---|
| swift-html-render | path: ../swift-html-render | **IN-SCOPE** | (Dest B) |
| swift-pdf-render | path: ../swift-pdf-render | **ECO-PRIV** | **PRIVATE** |
| swift-copy-on-write | path: ../swift-copy-on-write | **ECO-PRIV** | **PRIVATE** |
| swift-css | path: ../swift-css | **IN-SCOPE** | (Dest F) |
| swift-html-standard | path: ../../swift-standards/swift-html-standard | ECO-PUB | PUBLIC |
| swift-rfc-4648 | path: ../../swift-ietf/swift-rfc-4648 | ECO-PUB | PUBLIC |
| swift-layout-primitives | path: ../../swift-primitives/swift-layout-primitives | **ECO-PRIV** | **PRIVATE** |
| swift-dictionary-primitives | path: ../../swift-primitives/swift-dictionary-primitives | **ECO-PRIV** | **PRIVATE** |
| swift-stack-primitives | path: ../../swift-primitives/swift-stack-primitives | **ECO-PRIV** | **PRIVATE** |
| swift-property-primitives | path: ../../swift-primitives/swift-property-primitives | ECO-PUB | PUBLIC |

**Required launches before I transfer**: 5 (swift-pdf-render,
swift-copy-on-write, swift-layout-primitives — shared with D,
swift-dictionary-primitives — shared with B+C, swift-stack-primitives).
**In-scope deps**: B, F (transitively D, J).

### Master Launch List

Each entry is **its own user-gated launch process** per
`feedback_no_public_or_tag_without_explicit_yes`. None can be
batch-flipped under this plan.

| # | Private sibling | Owner-org | Used by destinations | Sharing |
|---|---|---|---|---|
| L1 | swift-async-primitives | swift-primitives | J | unique to J |
| L2 | swift-dependencies | swift-foundations | A | unique to A |
| L3 | swift-ascii | swift-foundations | B | unique to B |
| L4 | swift-dictionary-primitives | swift-primitives | B, C, I | **3-way** |
| L5 | swift-format-primitives | swift-primitives | C | unique to C |
| L6 | swift-dimension-primitives | swift-primitives | C, E | **2-way** |
| L7 | swift-ascii-primitives | swift-primitives | C | unique to C |
| L8 | swift-layout-primitives | swift-primitives | D, I | **2-way** |
| L9 | swift-color | swift-foundations | H | unique to H |
| L10 | swift-pdf-render | swift-foundations | I | unique to I |
| L11 | swift-copy-on-write | swift-foundations | I | unique to I |
| L12 | swift-stack-primitives | swift-primitives | I | unique to I |

**Total launches required**: 12.
**Sharing observations**: three launches (L4, L6, L8) unblock multiple
destinations — any cluster-grouping that shares them is therefore
launch-efficient.

### In-Scope Dependency Graph (Topological)

```
J (swift-render-primitives, Phase 2)
├─→ B (swift-html-render)
│    ├─→ D (swift-css-html-render)
│    │    └─→ F (swift-css)
│    │         ├─→ G (swift-markdown-html-render)
│    │         │    └─→ H (swift-html, 33★)
│    │         └─→ I (swift-pdf-html-render)
│    └─→ F (also)
└─→ C (swift-svg-render)
     └─→ E (swift-svg)
          └─→ H (also depends on E)

A (swift-translating) — no in-scope deps; independent.
```

H is the deepest leaf (depends on B, G, F, E — the entire Phase-3
chain except A and I). I depends on B, F. A is fully independent.

### Cluster Analysis

Three sensible clusters by shared launches and dependency proximity:

| Cluster | Members | Required launches (cumulative) | Notes |
|---|---|---|---|
| **α — Independent** | A | L2 | Standalone. Can run in parallel with any other cluster. |
| **β — Phase 2 prerequisite** | J | L1 | Must complete before β-dependent γ-cluster transfers. |
| **γ — HTML rendering chain** | B, C, D, E, F, G, H, I | L3, L4, L5, L6, L7, L8, L9, L10, L11, L12 (10 launches) | All depend on J transitively. Within γ, internal topological order applies. |

**Observation**: γ-cluster's 10 launches can be split into two waves:
- **γ-prelaunch** (before B can transfer): L3, L4
- **γ-midlaunch** (before D, C, E, etc. can transfer): L5, L6, L7, L8
- **γ-latelaunch** (before H, I can transfer): L9, L10, L11, L12

This sequencing keeps each launch tight to the destination it unblocks.

### Proposed Total Order (22 ordered work items)

Each line is one user-gated step. Each "Launch" is a separate launch
process; each "Transfer" is a per-action authorization per Rule 6.

```
 1. Launch L1   swift-primitives/swift-async-primitives  → PUBLIC
 2. Transfer J  swift-renderable → swift-primitives/swift-render-primitives    [Phase 2]
 — — Phase 2 done; Phase 3 begins — —
 3. Launch L2   swift-foundations/swift-dependencies      → PUBLIC
 4. Transfer A  swift-translating → swift-foundations/swift-translating        [Phase 3 cluster α]
 5. Launch L3   swift-foundations/swift-ascii             → PUBLIC
 6. Launch L4   swift-primitives/swift-dictionary-primitives → PUBLIC          (unblocks B, C, I)
 7. Transfer B  swift-html-rendering → swift-foundations/swift-html-render
 8. Launch L5   swift-primitives/swift-format-primitives  → PUBLIC
 9. Launch L6   swift-primitives/swift-dimension-primitives → PUBLIC           (unblocks C, E)
10. Launch L7   swift-primitives/swift-ascii-primitives   → PUBLIC
11. Transfer C  swift-svg-rendering → swift-foundations/swift-svg-render
12. Launch L8   swift-primitives/swift-layout-primitives  → PUBLIC             (unblocks D, I)
13. Transfer D  swift-css-html-rendering → swift-foundations/swift-css-html-render
14. Transfer E  swift-svg → swift-foundations/swift-svg
15. Transfer F  swift-css → swift-foundations/swift-css
16. Transfer G  swift-markdown-html-rendering → swift-foundations/swift-markdown-html-render
17. Launch L10  swift-foundations/swift-pdf-render        → PUBLIC
18. Launch L11  swift-foundations/swift-copy-on-write     → PUBLIC
19. Launch L12  swift-primitives/swift-stack-primitives   → PUBLIC
20. Transfer I  swift-pdf-html-rendering → swift-foundations/swift-pdf-html-render
21. Launch L9   swift-foundations/swift-color             → PUBLIC
22. Transfer H  swift-html → swift-foundations/swift-html  [33★, primary heritage]
 — — Phase 3 done; Phase 4 begins — —
23. Phase 4 URL-hygiene sweep (single Rule-6 envelope)
24. Phase 5 swift-html-to-pdf (deferred; refactor + branch alignment first)
```

**Validation**: every transfer step has all its required launches
completed; all in-scope deps transferred. Order honors the constraint
that no PUBLIC repo's `Package.swift` references a PRIVATE sibling at
any point (verified by walking the order against the per-destination
launch sets).

### Out-of-Scope (per-launch readiness)

This audit identifies *which* private siblings must launch. It does **not**
audit each sibling's own internal readiness (its own Package.swift, its
own deps, tests, README, etc.). Each L1–L12 launch is its own user-gated
process and will need its own pre-launch readiness audit before firing.

For first-order risk visibility:

- **L1 swift-async-primitives** — primitives leaf, low risk.
- **L2 swift-dependencies** — likely an institute-internal `Dependencies`
  package; readiness depends on whether it carries unfinished work.
- **L3 swift-ascii** — foundations-layer; check for transitive private
  deps.
- **L4 swift-dictionary-primitives** — primitives leaf, but high blast
  radius (3 destinations depend on it).
- **L5–L8, L12** — primitives leaves, generally low risk individually.
- **L9 swift-color** — foundations-layer; only blocks H; can sequence
  late.
- **L10 swift-pdf-render** — foundations-layer with possible deep
  primitives chain (PDF rendering tends toward many deps). Highest
  per-launch readiness risk.
- **L11 swift-copy-on-write** — likely small foundations utility, low
  risk.

### Open Questions

1. **L2 swift-dependencies** — is this institute-owned or a fork of
   pointfree's `swift-dependencies`? If a fork, `swift-package-heritage`
   skill applies (`[HERITAGE-001]` test). Resolve before scheduling L2.
2. **Per-launch readiness audits** — each L1–L12 needs its own audit
   before firing. Schedule these as separate research deliverables OR
   as part of each launch's own pre-flight checklist.
3. **Order flexibility** — the 22-step order above is *one valid*
   topological order. Steps without strict dependencies (e.g., A vs.
   J; D vs. E; F vs. G ordering) can swap based on readiness or risk
   appetite. Cluster α (A) can run any time after L2 completes.
4. **Phase 1 transferred siblings (`swift-html-chart`, etc.) URL deps**
   — these reference `coenttb/swift-html` URLs that will redirect once
   H transfers. Phase 4 URL-hygiene rewrites these. No action in Phase 3.

### Verification Stamp (2026-05-04)

| Claim | Evidence | Status |
|---|---|---|
| 10 destinations have local Package.swift | `ls` / `Read` 2026-05-04 | **Verified** |
| 21 unique non-in-scope path-deps enumerated | Manual extraction from manifests | **Verified** |
| Visibility of each path-dep | `gh repo view --json visibility,isArchived` 2026-05-04 | **Verified** |
| 9 PUBLIC ecosystem-sibling deps (no launch) | gh queries | **Verified** |
| 12 PRIVATE ecosystem-sibling deps (each requires launch) | gh queries | **Verified** |
| Topological order satisfies all in-scope dep edges | Manual graph walk | **Verified** |
| Order satisfies all launch precedence constraints | Manual order walk | **Verified** |

Claims **not** verified this pass:
- Transitive Package.swift content of L1–L12 (each launch process audits
  its own readiness; this audit covers only first-level deps of the 10
  destinations).
- Whether any L-target carries WIP / dirty working tree / branch state
  preventing launch (per-launch preflight).
- Open-PR drain status of the 10 destinations themselves (handled by
  per-destination start-condition checklist in
  `coenttb-ecosystem-heritage-transfer-plan.md`).

## Outcome

**Status**: RECOMMENDATION.

The 22-step total order above is a valid, complete sequential plan for
Phase 2 + Phase 3 + the bridge into Phase 4. Every transfer step has
its launch prerequisites satisfied; every PUBLIC repo at every point in
the order has only PUBLIC dependencies.

**Key facts for management decision**:

- **12 separate launch processes** must complete before the cluster
  can fully drain, each its own user-gated step.
- **10 transfers** in topological order; H (`swift-html`, 33★) is last
  in the chain.
- **Cluster α (A: swift-translating)** is decoupled and can run early
  or late.
- **Phase 5 (swift-html-to-pdf)** remains separate and orthogonal.

**Most natural next decisions** for the user:

1. Approve the audit (sanity-check the order; flag any L-target whose
   pre-launch readiness is known to be problematic — particularly
   L2 swift-dependencies and L10 swift-pdf-render).
2. Decide whether to begin with cluster α (transfer A after L2 launch)
   or with cluster β (Phase 2 transfer J after L1 launch). Both are
   smaller decisive units that prove the recipe further before tackling
   the γ-cluster main batch.
3. Schedule the per-launch readiness audits (one per L1–L12) as their
   own work items.

## References

**Tier 2 research (cross-referenced, not absorbed)**:

- [`coenttb-ecosystem-heritage-transfer-plan.md`](./coenttb-ecosystem-heritage-transfer-plan.md)
  — canonical strategy v1.3.0; this audit is the deliverable named in
  its §Per-Package Start Conditions row "Dep-visibility audit".
- [`git-history-transfer-patterns.md`](./git-history-transfer-patterns.md)
  — recipes for the transfer/apply-on-top mechanics.
- [`github-organization-migration-swift-file-system.md`](./github-organization-migration-swift-file-system.md)
  — 81-package precedent with same sweep-pattern.

**Operational docs**:

- `/Users/coen/Developer/HANDOFF.md` — currently dispatches the Property
  rename cascade (unrelated). When this audit's order resumes, parent
  HANDOFF.md may need re-stamping with the coenttb plan as anchor.
- `feedback_no_public_or_tag_without_explicit_yes` (memory) — load-bearing
  for every L1–L12 launch.
- `feedback_user_plan_is_roadmap_not_authorization` (memory) — the 22-step
  order is roadmap; "proceed" only authorizes the next step.

**Skills**:

- `swift-package` `[PKG-NAME-*]` `[PKG-DEP-*]` — package shape rules;
  L-target launches will invoke these for readiness audits.
- `release-readiness` `[RELEASE-*]` — composes with each launch's
  publication-squash discipline.
- `github-repository` — visibility-flip mechanics for L1–L12.

**Meta-process**:

- `[META-015]` Findings Verification Sweep — applied in the Verification
  Stamp subsection above.
- `[META-016]` Consolidation Protocol — this audit absorbs the
  `coenttb-ecosystem-heritage-transfer-plan.md` v1.3.0 §Per-Package
  Status row "dep-visibility" sub-claims and supersedes them with
  empirical results.
