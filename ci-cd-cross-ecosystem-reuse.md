# CI/CD Cross-Ecosystem Re-use: Standards, Foundations, Sub-Orgs, Third-Party

<!--
---
version: 1.1.1
last_updated: 2026-05-06
status: RECOMMENDATION
research_tier: 2
applies_to: [institute, primitives, standards, foundations, body-orgs]
normative: false
---
-->

## Changelog

- **v1.1.1 (2026-05-06)**: Reviewer pass corrections, six items, no
  framing change:

  1. **Migration count corrected** from "~280" to **262** (verified
     empirically via disk grep): L2 swift-standards proper 20 + L3
     swift-foundations proper 139 + L2 spec-authority sub-orgs 101
     (swift-ietf 77 + swift-iso 9 + swift-w3c 6 + swift-whatwg 2 +
     swift-ieee/iec/ecma/incits/arm-ltd/intel/riscv 1 each) + L3
     vendor sub-orgs 2 (swift-linux-foundation 1 + swift-microsoft 1).
     The 262 figure is "packages on disk," not "packages currently
     routing through universal" — the actual migration scope is
     ≤262 with construction-vs-migration distinction (item 4 below).
  2. **4-level cap granularity** added to Q2: the limit binds the 6
     advisory-linter dispatches in the universal (`lint-yaml`,
     `lint-broken-symlink`, `lint-license-header`,
     `lint-test-support-spine`, `lint-api-breakage`, `lint-pr-title`)
     because those are `uses:`-routed sub-reusables. Matrix /
     build / test / format / SwiftLint jobs in the universal are
     INLINE jobs (steps run directly), so they survive a 4-tier
     chain at level 3. A future per-authority wrapper would BREAK
     the linter sub-dispatches but NOT the matrix/build/test
     surface — granular blocking, not total. v1.1.0's "structurally
     blocked" framing remains correct (linters ARE the value-add)
     but the granularity is worth noting.
  3. **[RES-018] tension explicit** in Q1: layer wrappers as no-op
     delegations on day 1 would normally fail [RES-018]'s
     premature-primitive check (no concrete L2 invariant analog to
     L1's embedded-build job exists today). Principal accepts the
     present-day cost (~30–90 s of Actions setup overhead per run
     per published GitHub benchmarks; one extra workflow-call hop
     per CI run × 262 packages × ~daily push frequency ≈ measurable
     but not gating). The cost is the price of structural
     anchoring; without the wrappers, the future inflection point
     ("do we add a wrapper now?") incurs a one-time mass-migration
     of every consumer caller. Wrapper-up-front trades steady-state
     setup overhead for zero migration cost when invariants land.
  4. **L3 sub-orgs construction vs migration** distinguished in Q6:
     swift-linux-foundation and swift-microsoft each have 1 ci.yml
     in their single repo but 0 currently route to universal —
     they're in CONSTRUCTION (authoring fresh ci.yml), not
     MIGRATION (rewriting an existing route). v1.1.0 treated them
     uniformly with L2 sub-orgs (most of which DO route already);
     v1.1.1 splits Phase 9 into 9a (swift-foundations migration,
     ~139 callers, mostly already-routing) and 9b (L3 vendor
     sub-orgs construction-with-pre-routing, 2 fresh ci.yml files
     pointing at the new swift-foundations wrapper).
  5. **`lint-org-bot-coverage.yml` auth-path design** added to Q5:
     cross-org App-install verification (axis 1) requires either
     (a) an admin:org-scoped token (operator-held) running the
     check from swift-institute/.github, OR (b) the bot itself
     installed in each target org reading its own installation
     metadata from inside (chicken-and-egg for unprovisioned
     orgs). Recommend (a) — operator runs an out-of-band token
     refresh + the workflow consumes it as a secret. Org-secret
     coverage (axis 2) needs `read:org` scope on the actions
     secrets endpoint — same operator-token shape. Wrapper-file
     presence (axis 3) is anonymous-public-API readable (a `gh
     api /repos/<org>/.github/contents/.github/workflows/swift-ci.yml`
     200 vs 404 check), no auth required.
  6. **Phase 12+ inline-linters trade-off** clarified in Q6: the 6
     advisory linters are also invoked DIRECTLY (not transitively)
     from cron orchestrators — `lint-license-header.yml` is
     dispatched by `cron-audit-base.yml` for periodic sweeps;
     `lint-test-support-spine.yml` is dispatched by
     `lint-test-support-spine-weekly.yml`; etc. Inlining them as
     steps in the universal swift-ci.yml LOSES the direct-dispatch
     capability — the cron orchestrators would need to re-implement
     each linter inline OR accept the linter-only sweep going
     through the universal's full matrix surface (over-doing it for
     a periodic sweep). The trade-off is real and not free: Phase
     12+ requires a costed analysis if/when per-authority wrappers
     become live work, not a mechanical inline-everything refactor.
- **v1.1.0 (2026-05-06)**: Principal correction post-write. v1.0.0
  recommended Option B (3-tier direct to universal) for L2 and the 11
  L2 spec-authority sub-orgs based on a strict reading of [CI-004]'s
  invariant-justification test. Principal corrected: **the CI hierarchy
  SHOULD mirror the ORG hierarchy.** L1 is 3-tier (`repo → swift-primitives
  → swift-institute`) because the L1 org-chain is 3-deep (no sub-orgs
  under swift-primitives). L2 is conceptually 4-deep (`swift-institute
  → swift-standards → swift-ietf (or other authority) → repo`); the CI
  chain should mirror that. The principal explicitly does not want
  "direct to universal" for L2.

  Constraint surfaced during revision: GitHub Actions `workflow_call`
  has a **4-level depth limit** (top-level caller + up to 3 called
  workflows; cited in `ci-centralization-strategy.md:100`). The
  current L1 chain is already AT the limit:

  ```
  per-package ci.yml (caller)
    └── swift-primitives/.../swift-ci.yml@main         level 1
        └── swift-institute/.../swift-ci.yml@main      level 2
            └── ./.github/workflows/lint-yaml.yml      level 3   ← at limit
  ```

  Adding a sub-org wrapper between per-package and the layer wrapper
  would push to 5 levels, exceeding the limit. Therefore full 4-tier
  (`repo → sub-org wrapper → layer wrapper → universal`) is **NOT
  viable today** without first refactoring the universal's advisory
  linter calls (which today use `uses:` for `lint-yaml`,
  `lint-broken-symlink`, `lint-license-header`, `lint-test-support-spine`,
  `lint-api-breakage`, `lint-pr-title`).

  v1.1.0 revises Q1, Q2, Q5, Q6 to reflect this principal correction +
  the empirical limit. Net change:
  - **Q1**: L2 + L3 layer wrappers ARE introduced (mirroring
    swift-primitives/.github at L1) — reverses v1.0.0's "no wrapper"
    verdict.
  - **Q2**: Sub-org repos (swift-ietf, swift-iso, …) route through
    the LAYER wrapper (`swift-standards/.github` or
    `swift-foundations/.github`), NOT through a per-authority
    sub-org wrapper. Per-authority wrappers are DEFERRED pending
    either (a) GitHub raising the 4-level limit or (b) the universal
    being refactored to inline its advisory linters.
  - **Q5**: The new META service (`lint-org-bot-coverage.yml`) ALSO
    verifies wrapper-file presence at swift-standards/.github and
    swift-foundations/.github (in addition to org-secret + bot-app
    coverage).
  - **Q6**: Migration plan substantially restructured — phases now
    include creating swift-standards/.github + swift-foundations/.github
    org repos with their wrapper files, then migrating ~280 sub-org
    consumer per-package callers to route through layer wrappers.

  The codified sub-rules ([CI-004a]/[CI-004b]) are inverted from
  v1.0.0: rather than codifying the absence of wrappers, they codify
  the requirement that layer wrappers exist (mirroring org hierarchy)
  and that sub-org wrappers are future work.

- **v1.0.0 (2026-05-06)**: Initial RECOMMENDATION. Six-question
  analysis answering `HANDOFF-ci-cd-cross-ecosystem-reuse.md` based
  on a strict reading of [CI-004]'s invariant-justification test.
  Superseded by v1.1.0; the v1.0.0 framing is preserved in the
  changelog as the basis for the principal correction.

## Context

### Trigger

`HANDOFF-ci-cd-cross-ecosystem-reuse.md` (2026-05-06) — a focused
investigation brief authored as the parent CI/CD security cohort closed
its 2026-05-06 wave. The brief asks how the CI/CD corpus that landed
ecosystem-wide on the L1 surface (per `ci-centralization-strategy.md`
v1.1.0 + `ci-cache-strategy-branch-pinned-dependencies.md` v1.1.0 +
`centralized-swift-ci-and-spine-gate.md` v1.3.0) extends to the L2 and
L3 surfaces, the 11 L2 spec-authority sub-orgs, the 2 L3 vendor
sub-orgs, and (possibly) third-party Swift package authors outside the
ecosystem — plus what role `swift-institute-bot` plays in each.

### Scope

Ecosystem-wide [RES-002a]. Out of scope per the brief: cosign
attestation (Cohort C), concrete YAML edits, and the parallel
security-only handoff (separate dispatch, queued per
`project_pending_cicd_security_handoff.md`).

### Empirical state (verified 2026-05-06)

Per-org repo counts (`gh repo list <org> --limit 200 --json name | jq length`):

| Org | Layer | Repos | Visibility sample |
|---|---|---|---|
| swift-primitives | L1 | 132 (per `feedback_workspace_scope_l1_only.md`) | Mostly private, 4 public |
| swift-standards | L2 | 23 | Mixed; `swift-color-standard` PUBLIC, `swift-darwin-standard` PRIVATE |
| swift-foundations | L3 | 146 | Mostly private from sample (5/5 PRIVATE) |
| swift-ietf | L2 spec | 79 | Mixed; `swift-rfc-9111` PUBLIC, `swift-rfc-9562` PRIVATE |
| swift-iso | L2 spec | 10 | (not enumerated for visibility) |
| swift-ieee | L2 spec | 2 | |
| swift-iec | L2 spec | 2 | |
| swift-w3c | L2 spec | 7 | |
| swift-whatwg | L2 spec | 3 | |
| swift-ecma | L2 spec | 2 | |
| swift-incits | L2 spec | 2 | |
| swift-arm-ltd | L2 spec | 1 | |
| swift-intel | L2 spec | 1 | |
| swift-riscv | L2 spec | 1 | |
| swift-linux-foundation | L3 vendor | 1 | |
| swift-microsoft | L3 vendor | 1 | |
| swift-institute | meta | (n/a) | |

Total non-meta consumer surface: ~413 repos across 16 orgs.

**Live workflow shape verified (2026-05-06):**
- `swift-color-standard/.github/workflows/ci.yml` — public L2 — calls
  `swift-institute/.github/.github/workflows/swift-ci.yml@main`
  DIRECTLY (no L2 wrapper). Per-package caller carries the legacy
  `cache-key-prefix` input + explicit `secrets:` forwarding (pre-uniformity-sweep
  shape per [CI-058] / [CI-059]).
- `swift-rfc-9111/.github/workflows/ci.yml` — public L2 sub-org — same shape.
- `swift-primitives/<consumer>/.github/workflows/ci.yml` — calls the L1
  layer wrapper (`swift-primitives/.github/.github/workflows/swift-ci.yml@main`).

**The L1 layer wrapper carries 5 jobs beyond the universal matrix:**
`embedded` (gating L1 invariant per [CI-020]), `embedded-wasm-sdk`
(advisory γ-3), `android-build` (advisory), `static-linux-musl-build`
(advisory γ-3b), `apple-simulator-build` (advisory matrix:[iOS, tvOS,
watchOS, visionOS]). These are clearly L1-shaped: embedded is
[PRIM-FOUND-001] + [PKG-BUILD-007]/[008], the SDK builds verify
freestanding-buildability across platform variants.

**The universal reusable** carries macos-release, linux-release,
linux-nightly, windows-release, format, lint, and 6 advisory linters
(yaml, broken-symlink, license-header, test-support-spine, api-breakage,
pr-title) plus a `ci-ok` aggregator. All ecosystem-wide.

**Cross-org orchestrators** (8 cron jobs in `swift-institute/.github`):
- `sync-metadata-nightly` (daily 04:00) — sweeps ALL orgs via
  `read-orgs@main` composite reading `orgs.yaml`. Already cross-ecosystem.
- 7 weekly orchestrators (link-check-weekly,
  lint-readme-presence-weekly, lint-license-header-weekly,
  lint-test-support-spine-weekly, lint-mechanical-hygiene-weekly,
  submit-dep-graph-weekly, lint-readme-structure) — most currently sweep
  L1 only (`matrix-orgs: '["swift-primitives"]'`) per `feedback_workspace_scope_l1_only.md`.

**Bot infrastructure verified:**
- `swift-institute-bot` GitHub App + central credentials at
  `swift-institute/.github` org level: `SWIFT_INSTITUTE_BOT_APP_CLIENT_ID`,
  `SWIFT_INSTITUTE_BOT_APP_PRIVATE_KEY`. Per-org installation tokens
  minted via `actions/create-github-app-token@v3`.
- Org-level `PRIVATE_REPO_TOKEN` configured on swift-primitives per
  [CI-060] (`gh secret set --org swift-primitives --visibility all`).
  Inferred operationally configured on swift-standards + swift-ietf
  (their public consumers run CI green); explicit verification
  requires `admin:org` scope.

### Prior research (cite-and-extend per [HANDOFF-013])

This document EXTENDS — does not replace — three prior Tier 2
RECOMMENDATIONs:

- [`ci-centralization-strategy.md`](ci-centralization-strategy.md) v1.1.0
  (2026-04-22) — established Option A (reusable workflows) + Option D
  (sync-script). Permission scoping landed Path B (per-caller).
- [`ci-cache-strategy-branch-pinned-dependencies.md`](ci-cache-strategy-branch-pinned-dependencies.md)
  v1.1.0 (2026-05-04) — no-`.build/`-cache permanent.
- [`centralized-swift-ci-and-spine-gate.md`](centralized-swift-ci-and-spine-gate.md)
  v1.3.0 (2026-05-05) — Phase β advisory gate design + 8-capability
  catalog rolled out 2026-05-05.
- [`ci-cd-prior-art-and-pattern-survey.md`](ci-cd-prior-art-and-pattern-survey.md)
  v1.0.0 (2026-05-05) — comparative survey across 6 non-Swift ecosystems;
  notes the three-tier reusable chain + cron orchestrators have NO prior
  art (swift-institute-original).

The `ci-cd-workflows` skill ([CI-001]–[CI-070]) codifies the production
architecture this document extends.

---

## Question

The brief decomposes into six independently-answerable questions:

1. **L2/L3 wrapper justification under [CI-004]** — what layer-wide
   invariants justify `swift-standards/.github` and `swift-foundations/.github`
   wrappers?
2. **11 L2 spec-authority sub-orgs** — own wrapper tier (4-tier) or route
   directly through standards (3-tier)?
3. **Cross-org bot installation + secret distribution** — operational
   shape for the bot across 14+ additional orgs.
4. **Third-party (outside-ecosystem) re-use** — intended /
   unintended-but-permitted / actively-unwanted?
5. **Bot's expanded role** — which current services scale to 17 orgs?
   Are L2- or L3-specific services worth inventing per [RES-018]?
6. **Migration shape** — phased rollout from L1-only operational scope
   to fully centralized.

The brief mandates [RES-018] (Premature Primitive Anti-Pattern) +
[RES-020a] (Total-Taxonomy Justification) for any new infrastructure
recommendation.

---

## Analysis

### Q1 — L2/L3 wrapper justification

#### Two competing principles

**Principle A — [CI-004]'s invariant-justification test** (the v1.0.0
framing): a layer wrapper exists iff the layer carries ≥1
universally-applicable invariant beyond the universal matrix that is
non-overridable per-package and implementable as a CI check. Under
this test, neither L2 nor L3 has a documented invariant today
(Foundation-import is handled by SwiftLint custom rules; spec-version
pinning is hypothetical). v1.0.0 concluded: no wrappers.

**Principle B — Org-hierarchy mirroring** (the v1.1.0 framing, per
principal correction): the CI hierarchy mirrors the org hierarchy.
The org hierarchy is a fact of the ecosystem's structure independent
of whether each layer org has accumulated layer-specific invariants
yet. CI hierarchy mirroring it gives consumers a single anchor per
layer org; layer-specific concerns can accumulate naturally over time.

Principle B WINS for layer orgs. Reasoning:

1. **The org hierarchy is the architectural primitive.** Layer orgs
   exist as named entities in the ecosystem (swift-primitives,
   swift-standards, swift-foundations). A consumer in swift-standards
   has a structural relationship with swift-standards that's
   independent of whether swift-standards happens to have a
   layer-specific job today.
2. **Wrapper as anchor, not just gate.** The L1 wrapper today carries
   5 jobs (embedded + 4 advisory cross-compile). This shape didn't
   spring fully-formed; it accreted incrementally. A thin pass-through
   wrapper at write-time is the right home for layer-specific
   accumulation later.
3. **Eliminates the "where do I add this layer-specific thing?"
   inflection point.** Without a layer wrapper, a future L2-specific
   concern faces the question "do we add a wrapper now?" with the
   attendant migration of every consumer caller. With the wrapper
   pre-existing, the future change is one new job declaration in an
   existing file.

#### L1 wrapper precedent (verified empirically)

`swift-primitives/.github/.github/workflows/swift-ci.yml` carries 5
jobs beyond `matrix:` (embedded, embedded-wasm-sdk, android-build,
static-linux-musl-build, apple-simulator-build). These together encode
[PRIM-FOUND-001]'s freestanding-buildability invariant + [PKG-BUILD-007]/[008]
across platform variants. The wrapper has been THE place to land
layer-specific advisory cross-compile jobs since the 2026-05-04 wave;
the existence of the wrapper file enabled that accumulation.

#### Q1 verdict (revised)

**Both L2 and L3 layer wrappers are justified — by org-hierarchy
mirroring (Principle B), not by current invariants.**

- `swift-standards/.github/.github/workflows/swift-ci.yml` — L2 layer
  wrapper. Initially a thin pass-through delegating to the universal
  via `uses: swift-institute/.github/.../swift-ci.yml@main` plus the
  consumer's input forwarding. Layer-specific jobs accumulate as L2
  concerns are identified.
- `swift-foundations/.github/.github/workflows/swift-ci.yml` — L3
  layer wrapper. Same shape.

**Note (revised v1.1.1 during rollout)**: the L1 wrapper precedent
carries `swift-ci.yml` ONLY — there is no `swift-docs.yml` at the L1
layer, and consumer `docs:` jobs call `swift-institute/.github/.../swift-docs.yml@main`
directly. The org-hierarchy-mirroring requirement therefore applies to
the build/test/CI surface, NOT to the DocC documentation surface. L2
and L3 layer wrappers similarly do NOT need a sibling `swift-docs.yml`
unless a layer-specific docs concern emerges. This is codified as
sub-rule [CI-004a] in the ci-cd-workflows skill.

The codification (replacing v1.0.0's [CI-004a]):

> **[CI-004a] Layer Wrappers Mirror Layer Orgs**
>
> Each layer org (swift-primitives, swift-standards, swift-foundations)
> MUST have a `<layer-org>/.github/.github/workflows/swift-ci.yml`
> reusable workflow file. The wrapper exists as a structural anchor
> for the layer; it MAY be a thin pass-through to the universal
> reusable initially, and SHOULD accumulate layer-specific jobs as
> they are identified.
>
> The justification for the wrapper is the org hierarchy itself, not
> a current layer-specific invariant. A wrapper at a layer org with no
> layer-specific jobs today is correct under this rule; it
> pre-positions the layer for future accretion.
>
> An additional `swift-docs.yml` reusable mirroring the L1 pattern
> SHOULD also exist at each layer org for DocC pipeline consumers.

This is the inverse of v1.0.0's [CI-004a] (which codified the absence
of wrappers). v1.1.0 codifies their required presence.

### Q2 — 11 L2 spec-authority sub-orgs routing

#### The 4-level workflow_call constraint

Before evaluating routing options, the GitHub Actions
`workflow_call` 4-level depth limit (cited in
`ci-centralization-strategy.md:100` per GitHub docs) is the binding
constraint. Counting the per-package caller as level 0 and each
called reusable as a successive level:

```
level 0 (caller): per-package ci.yml
level 1: <layer or sub-org wrapper>
level 2: <next reusable in chain>
level 3: <next>
                  ← maximum 3 called levels per GitHub
```

The current L1 chain is exactly at the limit:

```
level 0: per-package ci.yml
level 1: swift-primitives/.../swift-ci.yml@main          (L1 wrapper)
level 2: swift-institute/.../swift-ci.yml@main           (universal)
level 3: ./.github/workflows/lint-yaml.yml               (advisory linter, called by universal)
                                                          ← at limit
```

The universal reusable invokes 6+ advisory linter reusables today
(`lint-yaml`, `lint-broken-symlink`, `lint-license-header`,
`lint-test-support-spine`, `lint-api-breakage`, `lint-pr-title`).
Adding any wrapper layer between per-package and L1/L2/L3 wrapper
would push the advisory-linter call to level 4 — exceeding the limit.
**Full 4-tier (`repo → sub-org wrapper → layer wrapper → universal`)
is not viable today.**

#### Three options under the limit

| Option | Tiers | Sub-org wrapper? | Layer wrapper? | Viable today? |
|---|---|---|---|---|
| A | 3-tier through layer wrapper | No (sub-org repos route directly through layer wrapper) | Yes | YES |
| B | 3-tier direct to universal (v1.0.0) | No | No | YES, but rejected by Q1 (org-hierarchy mirror) |
| C | 4-tier through per-authority wrapper | Yes | Yes | NO — exceeds 4-level limit when universal calls advisory linters |

Option C is structurally blocked. Option B is rejected by the org-hierarchy
mirroring principle (Q1 verdict). **Option A is the only viable
routing today.**

#### Q2 verdict (revised)

**Option A — 3-tier through the layer wrapper, including for sub-org
repos.** Concretely:

```
swift-rfc-9111 (in swift-ietf):
  per-package ci.yml
    └── uses: swift-standards/.github/.../swift-ci.yml@main      (L2 layer wrapper)
        └── uses: swift-institute/.github/.../swift-ci.yml@main  (universal)
            └── uses: ./.github/workflows/lint-yaml.yml          (advisory linter)
                                                                  ← at limit
```

The chain is identical for swift-color-standard (in swift-standards
proper) and swift-rfc-9111 (in swift-ietf); BOTH route through
swift-standards/.github wrapper. Per-authority sub-orgs (swift-ietf,
swift-iso, …) do NOT have their own wrapper today; their repos point
at swift-standards/.github directly.

The same holds for L3: swift-foundations repos AND repos in
swift-linux-foundation / swift-microsoft all route through
swift-foundations/.github wrapper.

**Per-authority wrappers are deferred** pending one of:
- (a) GitHub raising the workflow_call 4-level limit
- (b) Refactoring the universal to inline its advisory linters as
  steps rather than `uses:` calls (a significant universal-reusable
  refactor; cost estimated medium-high)

If/when (a) or (b) lands, per-authority wrappers can be introduced
incrementally as authority-specific concerns emerge. Until then, the
layer wrapper IS the home for any standards-wide convention; an
authority-specific concern (e.g., IETF Trust attribution lint) lands
as a new advisory job in the universal swift-ci.yml filtered by
repo-name pattern, NOT as a per-authority wrapper.

The codification (replacing v1.0.0's [CI-004b]):

> **[CI-004b] Sub-Org Wrappers Are Future Work**
>
> Per-authority sub-org wrappers (`swift-ietf/.github/.../swift-ci.yml`,
> `swift-iso/.github/.../swift-ci.yml`, …) and per-vendor sub-org
> wrappers (`swift-linux-foundation/.github/...`, `swift-microsoft/.github/...`)
> MUST NOT be created today. Sub-org repos route through their
> parent layer wrapper (`swift-standards/.github` or
> `swift-foundations/.github`).
>
> Reason: GitHub Actions `workflow_call` is limited to 4 connected
> levels (top-level caller + up to 3 called workflows). The current
> L1 chain (per-package → layer wrapper → universal → advisory
> linter) is already at the limit; inserting a sub-org wrapper would
> exceed it.
>
> Per-authority concerns (e.g., authority-specific license-header
> attribution) MUST be encoded as advisory jobs in the universal
> `swift-ci.yml` filtered by repo-name pattern (e.g., `if:
> startsWith(github.repository, 'swift-ietf/')`).
>
> This rule SUNSETS when GitHub raises the 4-level limit OR the
> universal is refactored to inline its advisory linters. Re-evaluate
> at that time.

#### Empirical population scale (verified 2026-05-06)

| Sub-org | Repos | Routes through |
|---|---|---|
| swift-ietf | 79 | swift-standards wrapper |
| swift-iso | 10 | swift-standards wrapper |
| swift-w3c | 7 | swift-standards wrapper |
| swift-whatwg | 3 | swift-standards wrapper |
| swift-ieee, swift-iec, swift-ecma, swift-incits | 2 each | swift-standards wrapper |
| swift-arm-ltd, swift-intel, swift-riscv | 1 each | swift-standards wrapper |
| **L2 sub-org total** | **~110** | swift-standards wrapper |
| swift-linux-foundation, swift-microsoft | 1 each | swift-foundations wrapper |
| **L3 sub-org total** | **~2** | swift-foundations wrapper |

### Q3 — Cross-org bot + secret distribution

Two distinct distribution surfaces, often conflated:

#### Surface 1: GitHub App installation per-org

The `swift-institute-bot` App must be installed at each org for the
central client-id pair to mint scoped installation tokens for that
org. App installation is a one-time admin:org operation. Per the
empirical state, the App is installed on at least swift-primitives,
swift-standards, swift-ietf (inferred from operational sync-metadata-nightly
runs that touch those orgs).

Per-org install ≠ per-org credentials: the App's central credentials
(`SWIFT_INSTITUTE_BOT_APP_CLIENT_ID` + `SWIFT_INSTITUTE_BOT_APP_PRIVATE_KEY`)
live ONCE at `swift-institute/.github`. Token minting via
`actions/create-github-app-token@v3` accepts an `owner:` parameter that
selects the target org's installation. **The cross-org token-minting
mechanism is the existing pattern; no change needed.**

#### Surface 2: Org-level `PRIVATE_REPO_TOKEN` per consumer-hosting org

Per [CI-060], `PRIVATE_REPO_TOKEN` MUST live as an org-level GHA
secret on each org that hosts CI-running consumer repos, configured
with `--visibility all`. The free-plan visibility constraint (org
secrets visible to public repos only) aligns with [CI-032]'s
private-repo skip gate at zero billing risk.

Inferred state: configured on swift-primitives, swift-standards,
swift-ietf (otherwise their public consumers' CI would fail). Unverified
on the remaining 13 orgs (1 L3 + 11 L2 spec-authority + 2 L3 vendor).

#### Composing with `read-orgs` / `orgs.yaml`

The `orgs.yaml` manifest at `swift-institute/.github/.github/actions/read-orgs/orgs.yaml`
already classifies all 17 orgs by layer. A schema extension:

```yaml
- name: swift-iso
  layer: L2
  status: active
  ci-secrets-required: [PRIVATE_REPO_TOKEN]   # NEW field
  bot-app-installed: true                      # NEW field, or per-org check
```

allows a verification linter to detect gaps. Read by a new sweep
workflow `lint-org-bot-coverage.yml` that:

1. For each org in `orgs.yaml`, queries `gh api orgs/<org>/actions/secrets`
   (requires `read:org` PAT or App permission) and confirms each
   `ci-secrets-required` entry is present.
2. For each org, queries `gh api orgs/<org>/installations` against the
   App's installation list and confirms presence.
3. Emits a tracking issue per [README-167] when gaps exist.

The bot's central App permissions must include reading org secrets
metadata (NOT secret values; existence + last-updated only) and
installation listing. Provisioning is admin out-of-band.

#### Q3 verdict

Keep the existing distribution mechanism (per-org App install + central
client-id pair + per-org `PRIVATE_REPO_TOKEN`). The architecture is
correct; the gap is **bookkeeping**, not architecture. Add:

- Schema extension to `orgs.yaml` declaring required org-level secrets
  and inferred bot-installation expectation.
- New advisory linter `lint-org-bot-coverage.yml` enumerating gaps and
  emitting tracking issues per [README-167].
- Manual admin operations (gh secret set, GitHub App install) by the
  org-admin operator to close any gaps surfaced. Per [CI-052], visibility
  / token / org-secret operations require explicit authorization.

### Q4 — Third-party (outside-ecosystem) re-use

The reusables at `swift-institute/.github/.github/workflows/*.yml` are
public; technically callable from any GitHub repo. Three distinct
branches, with security and support implications differing per branch.

#### Security-axis analysis (per `feedback_ci_priority_axes.md`)

When a third-party caller invokes our reusable with `secrets: inherit`,
THEIR secrets pass into our reusable. If we are compromised (malicious
push to `@main` between their pin and the next sync), the attacker has
a path to their secrets. **The third-party's threat model is shaped by
our `@main`-pinning discipline.**

Reverse direction: no swift-institute secrets flow to the third party.
The reusable runs on the third party's runner; bot tokens, org
secrets, etc. are not passed. **Our threat model is unchanged.**

Cost is not an axis (per `feedback_ci_priority_axes.md`); third-party
billing is on their account.

#### Comparative-ecosystem precedents (per `ci-cd-prior-art-and-pattern-survey.md` §1.5)

- **HashiCorp** publishes ecosystem actions (`hashicorp/setup-terraform`,
  `hashicorp/actions-go-build`) consumed by ~thousands of provider
  repos. Composable-action surface, not workflow-level reuse. Treats
  third-party callers as intended.
- **Apache Arrow** keeps cross-language conformance internal
  (`integration.yml`); no external reuse pattern.
- **Apple's `swiftlang/github-workflows`** is public; consumers
  reference `swift_package_test.yml@<ref>`. Apple does not actively
  prevent third-party consumption; they SHA/tag-pin and accept the
  pattern as community good.

The HashiCorp pattern is closest to swift-institute in shape but at
composable-action level. Apple's reusable-workflow level is the direct
analog and treats third parties as unintended-but-permitted.

#### Three-branch evaluation

| Branch | Implications | Verdict |
|---|---|---|
| (a) Intended | `@v1` rolling-tag stability per [CI-030] becomes a real contract. Breaking changes require `@v2`. Today's `@main` discipline is incompatible. | Premature — no evidence of demand. |
| (b) Unintended-but-permitted | Third party self-pins to a SHA (immutable). Disclaimer in the universal reusable header documents the lack of compatibility commitment. No code change. | **Adopt.** |
| (c) Actively unwanted | Caller-allowlist via workflow-level `if: github.repository_owner == 'swift-institute' || ...`. Implementation overhead + ongoing maintenance + hostile-OSS-signal cost. | Reject — not justified absent abuse. |

#### Q4 verdict

**Adopt branch (b) — unintended-but-permitted.** Mechanical action:

- Add a top-of-file disclaimer to `swift-institute/.github/.github/workflows/swift-ci.yml`
  (and `swift-docs.yml`):

  > These reusable workflows are designed for swift-institute ecosystem
  > packages. Outside callers consume at their own risk and should pin
  > to an immutable SHA (`@<sha>`) rather than `@main`. The input/output
  > surface and behavior may change without notice; the
  > `swift-institute/.github` repo offers no compatibility guarantee
  > to outside consumers.
- Same disclaimer in `swift-institute/.github` repo README.
- Re-evaluate to (a) intended ONLY if a real third-party consumer
  emerges and asks for stability commitments.

No code changes today.

### Q5 — Bot's expanded role

#### Inventory of current services (verified 2026-05-06)

| Service | Reusable + orchestrator | Cross-org? Today | Cross-org? L1→17 orgs viable? |
|---|---|---|---|
| Repo metadata sync | `sync-metadata.yml` + `sync-metadata-nightly.yml` | YES — already iterates `orgs.yaml` | YES |
| Link rot detection | `link-check.yml` + `link-check-weekly.yml` | YES (per-org reusable; orchestrator currently filters L1) | YES — flip filter to all |
| README presence | `lint-readme-presence.yml` + `-weekly` | Likely L1 today | YES |
| README structure | `lint-readme-structure.yml` (per-PR + weekly?) | Likely L1 today | YES |
| License-header advisory | `lint-license-header.yml` + `lint-license-header-weekly.yml` | L1 today (cron-audit-base) | YES |
| Mechanical hygiene (yaml + symlink) | `lint-mechanical-hygiene-weekly.yml` | L1 today | YES |
| Test Support Spine ([MOD-024]) | `lint-test-support-spine.yml` + `-weekly` | L1 today | **PARTIAL** — [MOD-024] convention is L1-scoped today; L2/L3 may not have the convention codified |
| YAML lint | `lint-yaml.yml` (per-repo via universal swift-ci.yml) | Universal already | n/a |
| Dep-graph submission | `submit-dep-graph-weekly.yml` | Per-org public-only sweep | YES |
| Tracking-issue upsert | `upsert-tracking-issue` composite | Universal mechanism | n/a |

Most current services scale as-is via the existing
`read-orgs@main` + `orgs.yaml` mechanism — the only change is filter
expansion in the orchestrator's `matrix-orgs:` input.

The exception is Test Support Spine: [MOD-024] is L1-defined; whether
L2/L3 packages MUST publish a `*Tests` Test_Support sibling target is
a separate convention question. That cross-layer applicability is an
input to the convention's authors (the `modularization` skill), not to
this CI/CD investigation. If [MOD-024] is determined L2/L3-applicable,
the audit script + reusable scale automatically.

#### L2-specific candidate services (per [RES-018])

| Candidate | Why-not-compose? | Second-consumer? | Verdict |
|---|---|---|---|
| Spec-version drift linter (verify `*.docc/spec-version.txt` against an authority registry) | Composes with nothing existing — would require new metadata convention. | None today. Symmetric-completeness reasoning ("L2 is spec-bound, therefore needs spec-version tracking"). | **Reject** per [RES-018]. |
| Authority-attribution linter (verify spec citation format) | The `swift-package` naming convention already encodes this (`swift-rfc-9111` ↔ RFC 9111); CI lint is redundant with skill-review enforcement. | n/a — composes with existing. | **Reject**; defer until naming-convention drift is observed. |
| Foundation-import (extending [CI-022]) | Already enforced ecosystem-wide via SwiftLint custom rules. | n/a — already done. | **Reject** (already addressed). |

#### L3-specific candidate services (per [RES-018])

| Candidate | Why-not-compose? | Second-consumer? | Verdict |
|---|---|---|---|
| Stricter Foundation-import for L3 (`* Foundation Integration` subtarget only) | Composes with the existing SwiftLint Foundation-import rule via per-package config (the rule disable per-target is already supported). | n/a — composes. | **Reject** (composable). |
| Multi-vendor compatibility lint (verify L3 vendor packages build against the right vendor toolchain) | Composes with the universal matrix's Linux + macOS + Windows; vendor specificity is per-package `Package.swift platforms:` declarations. | Each L3 vendor sub-org has 1 repo today. | **Reject** per [RES-018] — no second consumer. |

#### One new META service worth inventing (per [RES-018])

`lint-org-bot-coverage.yml` (per Q3) — verify, for each org in
`orgs.yaml`, three coverage axes:

1. The bot App is installed at the org.
2. The org-level `PRIVATE_REPO_TOKEN` secret is configured (only
   relevant for orgs hosting public consumer repos).
3. **(NEW in v1.1.0)** Layer orgs (swift-primitives, swift-standards,
   swift-foundations) have the expected wrapper file at
   `<org>/.github/.github/workflows/swift-ci.yml` (and `swift-docs.yml`
   per Q1's [CI-004a]). Sub-orgs do NOT have wrapper files (per
   [CI-004b]).

Tracking issue per [README-167].

- **Why-not-compose?** No existing reusable inventories org-level
  secret coverage; no existing reusable inventories App installation
  coverage; no existing reusable inventories layer-wrapper-file
  presence. All three are operational invariants the architecture
  depends on but doesn't currently verify.
- **Second consumer?** YES — coverage checks apply to every org
  (axis 1: 17 orgs; axis 2: ~16 consumer-hosting orgs; axis 3: 3
  layer orgs + 13 sub-orgs to verify wrapper-file ABSENCE).

**Q5 verdict:** scale current services to all 17 orgs via filter
expansion in orchestrators (no new reusable needed); invent ONE new
META service (`lint-org-bot-coverage.yml`) for the Q3 verification gap.
No L2-specific or L3-specific service clears [RES-018] today.

### Q6 — Migration shape (revised)

The "L1-only active workspace scope" framing per
`feedback_workspace_scope_l1_only.md` is about RULE-ACTIVATION TIMING,
not the centralization mechanism's reach. But under v1.1.0's
org-hierarchy-mirroring principle, the centralization mechanism's
SHAPE is incomplete: layer wrappers exist only at L1; L2 and L3
consumers currently bypass to universal directly. Migration is
therefore **three-axis**, not two-axis as in v1.0.0.

#### Three-axis migration

| Axis | Action | Scope | Risk |
|---|---|---|---|
| A — Layer wrapper introduction | Create swift-standards/.github + swift-foundations/.github org repos with wrapper files (swift-ci.yml + swift-docs.yml mirroring swift-primitives/.github). | 2 new GitHub org repos (the `.github` repo in each layer org), each with 2 wrapper files. | Low — additive. Wrapper files are thin pass-throughs initially. |
| B — Consumer caller migration | Update each consumer per-package `ci.yml` to call `<layer-org>/.github/.../swift-ci.yml@main` instead of universal directly. | ~280 consumer repos across L2, L2 sub-orgs, L3, L3 sub-orgs. | Per-package mass rollout per [CI-050]; must canary first. |
| C — Operational coverage extension | Phased orchestrator-filter expansion to all 17 orgs (the v1.0.0 plan). | Per-orchestrator filter edits in swift-institute/.github. | Per-phase: degraded sweep on a non-conformant org. Mitigated by canary + 2-week clean-cron gate. |

Axes A and B are SEQUENTIAL — the layer wrapper must exist before
consumers can be migrated to it. Axis C composes additively with both.
All axes require per-phase principal authorization per [CI-050]
mass-rollout discipline.

#### Phased plan (revised)

Per `feedback_user_plan_is_roadmap_not_authorization.md`, the plan
below is a roadmap; each phase needs explicit go-ahead.

| Phase | Action | Per-phase gate | Rollback |
|---|---|---|---|
| 0 | Codify revised [CI-004a] (layer wrappers MUST exist) + [CI-004b] (sub-org wrappers are future work, blocked by 4-level limit) in `ci-cd-workflows` skill. Codify Q4 disclaimer in universal `swift-ci.yml` header. | Skill PR review. | Revert skill commit. |
| 1 | **Axis A — swift-standards/.github**: create the GitHub org repo + commit `swift-ci.yml` + `swift-docs.yml` thin pass-throughs mirroring swift-primitives/.github. No consumer migration yet. | Manual `gh workflow_dispatch` on the wrapper passes against a synthetic test consumer. | Delete the org repo (reversible if no consumers route through it yet). |
| 2 | **Axis A — swift-foundations/.github**: same shape as Phase 1 for L3. | Same gate. | Same. |
| 3 | **Axis C — Phase 0 deliverable**: add `lint-org-bot-coverage.yml` reusable (Q3+Q5 META service: bot-app + secret + wrapper-file coverage across all 17 orgs). Sweep currently swift-primitives only. | Reusable runs cleanly on swift-primitives + swift-institute layer set. | Revert reusable + orchestrator caller. |
| 4 | **Axis A+C provisioning**: verify (and configure if missing) bot App install + `PRIVATE_REPO_TOKEN` on swift-standards + swift-foundations. | `lint-org-bot-coverage.yml` clean for both new layer orgs. | n/a — provisioning is additive. |
| 5 | **Axis B canary** — migrate 1–2 swift-standards public-repo consumer `ci.yml` files (e.g., swift-color-standard) to call `swift-standards/.github/.../swift-ci.yml@main` instead of universal direct. | Canary repos' next CI run all-green. | Revert per-repo `ci.yml` to universal-direct (single-line edit). |
| 6 | **Axis B fan-out — swift-standards proper**: migrate remaining ~22 consumers in swift-standards. | 2 consecutive weekly clean sweeps + all canaries green. | Per-repo revert. |
| 7 | **Axis B fan-out — 11 L2 spec-authority sub-orgs**: migrate ~110 consumer `ci.yml` files to call `swift-standards/.github/.../swift-ci.yml@main`. Canary on largest (swift-ietf, 79 repos) first. | 2 consecutive weekly clean sweeps + canaries green. Per [CI-050] each sub-org wave needs explicit auth. | Per-repo or per-sub-org revert. |
| 8 | **Axis B canary — swift-foundations** (mirror Phase 5 for L3). | Canary green. | Per-repo revert. |
| 9 | **Axis B fan-out — swift-foundations + 2 L3 vendor sub-orgs**: migrate ~146 + 2 consumer `ci.yml` files. | 2 consecutive weekly clean sweeps. | Per-repo revert. |
| 10 | **Axis C operational coverage**: expand orchestrator `matrix-orgs:` filters to include all 17 orgs. Per-org canary then full filter. | 2 consecutive weekly clean sweeps per sub-org wave. | Per-org `status: degraded` flag in `orgs.yaml`. |
| 11 | Steady state: matrix-orgs filter = `.name` (all 17 orgs). | n/a | n/a |

Total package-level edits across Phases 5–9: **262** per-package
`ci.yml` files (verified 2026-05-06 by disk grep: L2 20 + L3 139 +
L2 sub-orgs 101 + L3 sub-orgs 2). Each `ci.yml` change is a one-line
edit (replace `swift-institute/.github/...` with
`swift-standards/.github/...` or `swift-foundations/.github/...`)
plus `secrets: inherit` per [CI-059]. Mechanical and reversible.

**Construction vs migration distinction** (v1.1.1): Phase 9 is split:

- **Phase 9a — swift-foundations proper (139 packages)**: most
  consumers already route to universal directly; this is a
  one-line caller-rewrite per consumer. Migration class.
- **Phase 9b — L3 vendor sub-orgs (2 packages)**: swift-linux-foundation
  and swift-microsoft each have 1 ci.yml in their single repo but
  0 currently route to universal — they're in construction, not
  migration. Phase 9b is "author fresh ci.yml pointing at the new
  swift-foundations wrapper from the start," not "rewrite a pointer."

Within Phase 7 (L2 sub-orgs), most repos similarly already route to
universal (~80 of ~101 do; the remainder is mixed); the migration is
predominantly rewrite, not construction.

#### Future option (post-rule-sunset)

If GitHub raises the workflow_call 4-level limit (or the universal is
refactored to inline its advisory linters as steps), per-authority
sub-org wrappers become viable. At that point a Phase 12+ would:

12. Inline advisory linters in universal (or wait for GitHub's 4-level limit relief).
13. Create per-authority sub-org `.github` repos + wrapper files for the 11 L2 spec-authority sub-orgs and 2 L3 vendor sub-orgs.
14. Migrate sub-org consumer `ci.yml` files from `swift-standards/.github/...` (or `swift-foundations/.github/...`) to `<authority>/.github/...`.

This future option is documented but NOT recommended today.

#### Composition with the pending security-only handoff

Per `project_pending_cicd_security_handoff.md` the security-only review
is queued as a separate dispatch. It is orthogonal to this rollout:

- This rollout (axes A + B + C) covers WHO consumes the universal
  reusable through what chain.
- The security review covers WHAT THREATS pass through the chain
  (supply chain, secret handling, egress).

Both can land in parallel. Phase 4's provisioning surfaces gaps the
security review consumes as input. The two cohorts compose additively;
neither blocks the other.

Phase 3's `lint-org-bot-coverage.yml` is mechanically the cheapest
piece; recommend landing it in advance of either rollout to give the
security review a verified provisioning-state input.

#### Composition with the pending security-only handoff

Per `project_pending_cicd_security_handoff.md` the security-only review
is queued as a separate dispatch. It is orthogonal to this rollout:

- This rollout covers WHO consumes the universal reusable (cross-org reach).
- The security review covers WHAT THREATS pass through it (supply
  chain, secret handling, egress).

Both can land in parallel. Phase 1's provisioning surfaces gaps the
security review consumes as input (orgs missing the bot App or org
secret are also security-relevant gaps). The two cohorts compose
additively; neither blocks the other.

Phase 0's `lint-org-bot-coverage.yml` is mechanically the cheapest
piece; recommend landing it in advance of either rollout to give the
security review a verified provisioning-state input.

---

## Cross-question summary (revised)

| Question | Verdict |
|---|---|
| Q1 — L2/L3 wrappers | **MUST exist** (mirror org hierarchy). Create `swift-standards/.github` + `swift-foundations/.github` wrapper files; thin pass-throughs initially. Codify as [CI-004a]. |
| Q2 — Sub-org routing | **3-tier through layer wrapper** (Option A). Sub-org repos route through swift-standards or swift-foundations; per-authority sub-org wrappers DEFERRED (4-level workflow_call limit). Codify as [CI-004b]. |
| Q3 — Bot + secrets | **Existing mechanism is correct.** Add `lint-org-bot-coverage.yml` for 3-axis verification (App install + org secret + wrapper-file presence). Provision per-org out-of-band. |
| Q4 — Third-party | **Unintended-but-permitted** (branch b). Disclaimer in universal reusable header + repo README. |
| Q5 — Bot expanded role | Current services **scale via filter expansion**; no L2/L3-specific service clears [RES-018]; invent ONE meta service (`lint-org-bot-coverage.yml`). |
| Q6 — Migration | **Three-axis**: (A) create L2+L3 layer wrappers, (B) migrate ~280 consumer callers to route through them, (C) phased orchestrator-filter expansion. 11 phases plus future option for per-authority wrappers post-limit-relief. |

## Options matrix (revised)

| Axis | Option | Cost | Reversibility | Verdict |
|---|---|---|---|---|
| L2 wrapper | None | Zero | n/a | Reject (org-hierarchy mirror principle) |
| L2 wrapper | swift-standards/.github layer wrapper (thin pass-through, accumulating) | Medium (org repo + 2 wrapper files + 23 caller migrations) | Low after caller migration | **ADOPT** |
| L3 wrapper | None | Zero | n/a | Reject (same) |
| L3 wrapper | swift-foundations/.github layer wrapper | Medium (org repo + 2 wrapper files + 146 caller migrations) | Low after caller migration | **ADOPT** |
| Sub-org routing | 3-tier direct to universal (sub-org repos bypass layer) | Zero | n/a | Reject (org-hierarchy mirror) |
| Sub-org routing | 3-tier through layer wrapper (sub-org repos route via swift-standards or swift-foundations) | Medium (110 + 2 caller migrations) | Low | **ADOPT** |
| Sub-org routing | 4-tier through per-authority wrapper | High AND blocked by 4-level workflow_call limit | n/a | **REJECT (structurally blocked)** |
| Bot pattern | Per-org App install + central credentials (current) | Provisioning only | Medium | **ADOPT** |
| Bot pattern | Per-org credentials | High (15 orgs × secret rotation) | Low | Reject |
| Third-party | Unintended-but-permitted (disclaimer) | Zero | High | **ADOPT** |
| Third-party | Caller-allowlist | Medium (workflow `if:` + maintenance) | Medium | Reject |
| Third-party | Intended consumers | High (`@v1` rolling-tag discipline + breaking-change protocol) | Low | Reject (no demand) |
| Bot scope | Filter expansion to 17 orgs | Low (per-orchestrator one-liner) | High (revert filter) | **ADOPT** |
| Bot scope | New L2/L3-specific services | High (per-service [RES-018] gate) | n/a | Reject — no second consumer today |
| Bot scope | One META verification service (3-axis) | Low (single new reusable) | High | **ADOPT** |
| Migration | All-at-once | Low setup, high blast radius | Low | Reject |
| Migration | Phased layer-wrapper-then-callers-then-coverage | Per-phase auth + 2-week gate | Per-phase revert | **ADOPT** |

---

## Outcome

**Status: RECOMMENDATION (v1.1.0)**

The CI/CD architecture's three-tier shape ([CI-001]) is correct as a
TYPE: consumer → layer wrapper → universal reusable. Under v1.1.0's
**org-hierarchy mirroring** principle (the principal correction
super­seding v1.0.0's invariant-justification reading of [CI-004]),
each layer org MUST host a wrapper as a structural anchor — independent
of whether the layer has accumulated layer-specific jobs yet. L1's
swift-primitives wrapper is the existence-proof; L2 and L3 follow.

**Per-authority sub-org wrappers (swift-ietf, swift-iso, …,
swift-microsoft) are NOT viable today** under the GitHub Actions
`workflow_call` 4-level depth limit. The current L1 chain
(per-package → layer wrapper → universal → advisory linter) is at the
limit. Sub-org repos therefore route through the parent layer wrapper
(swift-standards or swift-foundations); per-authority wrappers are
deferred pending either (a) GitHub raising the limit OR (b) refactoring
the universal to inline its advisory linters.

The remaining work is **ARCHITECTURAL + BOOKKEEPING + CONVENTION**:

- **Architectural** (new in v1.1.0): create swift-standards/.github
  and swift-foundations/.github org repos with wrapper files mirroring
  swift-primitives/.github. Migrate ~280 consumer per-package `ci.yml`
  files to route through layer wrappers instead of the universal
  directly.
- **Bookkeeping**: verify and provision bot App install + org-level
  `PRIVATE_REPO_TOKEN` + wrapper-file presence across all 17 orgs via
  a new advisory linter `lint-org-bot-coverage.yml` (3-axis
  verification). Expand orchestrator matrices via the existing
  `orgs.yaml` filter mechanism gated on weekly-sweep cleanliness.
- **Convention**: skill-rule extensions [CI-004a] (layer wrappers
  MUST mirror layer orgs) and [CI-004b] (sub-org wrappers are future
  work, blocked by 4-level limit). Both rules invert v1.0.0's
  formulations.

**Third-party (outside-ecosystem) Swift package authors**: permit but
don't support. Add disclaimer to the universal reusable header + repo
README. Re-evaluate if a real third-party consumer asks for stability
commitments.

**Bot's expanded role**: existing services scale to 17 orgs as-is via
filter expansion; no L2- or L3-specific service clears [RES-018]; one
META verification service (`lint-org-bot-coverage.yml`, with a third
axis added in v1.1.0) is justified.

## Open questions

1. **[MOD-024] cross-layer applicability**: is the Test Support Spine
   convention L1-only or ecosystem-wide? If L2/L3, the existing
   `lint-test-support-spine-weekly.yml` extends mechanically; if L1-only,
   the orchestrator's filter stays L1 even at Phase 11. Resolution
   belongs to `modularization` skill authors, not CI/CD.

2. **Bot App permission floor**: does the central App's permission set
   include `read:org` actions secrets metadata? If not, `lint-org-bot-coverage.yml`'s
   secret-coverage check fails at provisioning time, not at runtime.
   Verify before Phase 3.

3. **Tag stabilization timing**: per `ci-centralization-strategy.md`'s
   "Eventual end state", callers move to `@v1` rolling-tag pinning when
   the reusable surface stabilizes. The 2026-05-05 audit landed
   substantial new advisory linters; the surface is still iterating.
   Tag stabilization is a separate cohort, not blocking this rollout.

4. **`orgs.yaml` schema extension**: adding `ci-secrets-required`,
   `bot-app-installed`, and `wrapper-file-required` fields requires a
   one-time edit to `read-orgs@main`'s filter handling. Verify the
   composite tolerates extra fields without altering its filter
   semantics (it should — `select(...)` filters by field equality).

5. **NEW (v1.1.0): does the L2 layer wrapper consume the same set of
   inputs as L1?** swift-primitives/.github's wrapper exposes
   `cache-key-prefix`, `swift-version`, `enable-private-repos`,
   `macos-runner` inputs. swift-standards' and swift-foundations'
   wrappers should match this surface for consumer caller uniformity
   per [CI-031]. Confirm during Phase 1+2 wrapper authoring.

6. **NEW (v1.1.0): when does the 4-level limit relief unblock
   per-authority wrappers?** GitHub has historically raised
   workflow_call limits in response to community pressure (the limit
   was 1 → 2 → 4 over time). If a 5th level becomes possible, the
   per-authority wrapper option (Phase 12+ in Q6) becomes viable.
   Track GitHub Actions changelog for this.

7. **NEW (v1.1.0): refactoring the universal to inline advisory
   linters as steps**: would unblock per-authority wrappers without
   waiting on GitHub. Cost: each advisory linter (`lint-yaml`,
   `lint-broken-symlink`, …) becomes inline shell + setup in the
   universal swift-ci.yml; the called-reusable form is removed. Loses
   the per-linter direct-dispatch capability (workflow_dispatch on
   each linter individually) but gains chain-depth headroom. Open
   question whether the trade-off is worthwhile; not recommended
   today, but worth costing if per-authority concerns emerge.

## References

Verified during this investigation (citations per [RES-026]):

### Primary sources (workflow files inspected)

- `swift-institute/.github/.github/workflows/swift-ci.yml` (400 lines, verified 2026-05-06 — universal reusable)
- `swift-primitives/.github/.github/workflows/swift-ci.yml` (356 lines, verified 2026-05-06 — L1 wrapper)
- `swift-institute/.github/.github/actions/read-orgs/action.yml` + `orgs.yaml` (17 orgs, verified 2026-05-06)
- `swift-institute/.github/.github/workflows/sync-metadata-nightly.yml` (cross-org orchestrator, verified 2026-05-06)
- `swift-institute/.github/.github/workflows/cron-audit-base.yml` (orchestrator template, verified 2026-05-06)
- `swift-color-standard/.github/workflows/ci.yml` (verified 2026-05-06 via `gh api` — L2 consumer routes directly to universal)
- `swift-rfc-9111/.github/workflows/ci.yml` (verified 2026-05-06 via `gh api` — L2 sub-org consumer routes directly to universal)

### Internal cross-references

- [`ci-centralization-strategy.md`](ci-centralization-strategy.md) v1.1.0
- [`ci-cache-strategy-branch-pinned-dependencies.md`](ci-cache-strategy-branch-pinned-dependencies.md) v1.1.0
- [`centralized-swift-ci-and-spine-gate.md`](centralized-swift-ci-and-spine-gate.md) v1.3.0
- [`ci-cd-prior-art-and-pattern-survey.md`](ci-cd-prior-art-and-pattern-survey.md) v1.0.0
- `swift-institute/Skills/ci-cd-workflows/SKILL.md` ([CI-001]–[CI-070])
- `swift-institute/Skills/research-process/SKILL.md` ([RES-018], [RES-020a], [RES-026])
- `swift-institute/Skills/handoff/SKILL.md` ([HANDOFF-013])

### Memory references

- `feedback_workspace_scope_l1_only.md` (verified 2026-05-05)
- `feedback_ci_priority_axes.md` (correctness > security > speed; cost not an axis)
- `feedback_top_level_permissions_on_reusables.md`
- `feedback_private_repos_no_ci_runs.md`
- `project_per_repo_vs_centralized_ci.md`
- `project_pending_cicd_security_handoff.md` (queued separate dispatch)
- `feedback_user_plan_is_roadmap_not_authorization.md`

### Empirical probes (2026-05-06)

- `gh repo list <org> --limit 200 --json name | jq length` per all 16
  non-meta orgs (counts in §Empirical state).
- `gh api repos/swift-standards/swift-color-standard/contents/.github/workflows/ci.yml`
  → confirms direct route to `swift-institute/.github/.../swift-ci.yml@main`
  (no L2 wrapper).
- `gh api repos/swift-ietf/swift-rfc-9111/contents/.github/workflows/ci.yml`
  → confirms direct route from L2 spec sub-org.
