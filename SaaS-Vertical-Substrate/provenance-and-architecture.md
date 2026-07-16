# SaaS Vertical Substrate — Provenance and Architecture Record

<!--
---
version: 0.2.0
last_updated: 2026-07-16
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
changelog:
  - 0.2.0 (2026-07-16): Separated the accepted RepoTraffic checkpoint from a concurrent launch-hardening worktree delta.
  - 0.1.0 (2026-07-16): Initial evidence record and architecture premises for Principal review.
---
-->

## Context

RepoTraffic is the forcing application for an ecosystem question: which capabilities belong in
reusable Swift Institute foundations and components, which are provider integrations, which remain
RepoTraffic product policy, and which—if any—earn independent deployment. This record fixes the
evidence scope and the architectural premises used by the companion artifacts. It changes no code
and does not authorize extraction.

This is a proposal, not a ratified decision. The acceptance oracle remains Principal judgment after
independent review.

## Question

What evidence and canonical rules are sufficient to derive a reusable SaaS vertical without
treating RepoTraffic's current targets as package boundaries, inventing a mega-framework, or
presuming that a reusable capability must be a service?

## Analysis

The analysis fixes canonical premises and commit-pinned evidence before drawing any package,
component or deployment conclusion; mutable post-checkpoint observations remain segregated.

## Canonical architecture premises

The following are applications of existing skills and ratified research, not new rules:

1. **Layer by semantic purpose.** L3 foundations provide flexible mechanisms and invariants; L4
   components are opinionated assemblies; L5 applications own product policy, presentation, and
   deployment composition. A provider adapter is an integration package at the highest layer of
   the units it joins. A service is a deployment posture, not a sixth code layer.
2. **Package seams precede service seams.** A coherent capability with an independent theory can
   earn a package. Independent deployment additionally must pay network, availability, versioning,
   security, data-ownership, deployment, and operating costs.
3. **One coherent concern per package.** Cross-package joins belong in dedicated integration
   packages. L5 may compose many packages but must not vend the join back downward.
4. **Wide, shallow, acyclic graphs.** Base domains do not import provider integrations, persistence
   backings, presentation, or application roots. Integration packages depend inward on both sides
   of a join. Composition roots select conformances.
5. **Reuse before invention.** Existing Institute capabilities are the first candidate. A reserved
   directory, disabled target, or source-only target is not an available product.
6. **Product policy stays high.** RepoTraffic tier names, GitHub traffic freshness, analytics packs,
   branding, support behavior, and route/view composition cannot leak into generic catalog,
   subscription, entitlement, cache, or identity packages.
7. **Every main target remains Apple-Foundation-free at every layer.** [ARCH-LAYER-007] applies to
   L1 through L5, including executable and product targets. Genuine interoperability belongs only in
   an explicitly named opt-in `* Foundation Integration` leaf under [ARCH-LAYER-013], with the leaf
   depending on the core and never the reverse. RepoTraffic's 253 current Foundation-importing files
   measure migration work; they do not create an exception.

The ratified server-stack record is also a fixed input: `swift-server` is a logical L4 chassis;
`swift-scheduler` is the L3 engine-free job interface; `Server Jobs` is its L4 Queues backing;
`swift-records` is to be superseded and split; and RepoTraffic's Phase-2 Redis removal is already
approved. This proposal does not reopen those decisions.

## Evidence scope

### RepoTraffic

The source and manifest census was reverified at:

- repository: `/Users/coen/Developer/repotraffic/repotraffic-com-server`
- branch state: `main` at `0a2489838e515405562c417a10647691442f9d20`, 12 commits ahead of
  `origin/main`
- `Package.swift` blob: `6ce95f37f7177ff0472adf7693ab4f13952c5d21`
- `Sources` tree: `253db170a6cd4f29be64cb783edb33d1a18a5b91`
- `Tests` tree: `5fa67d8d745d153a64b889263923547ecf07b1e6`

`0a24898` is a documentation-only correction after the source assessment at `f820eac`; `git diff
f820eac..0a24898 -- Package.swift Sources Tests` is empty. The architecture census therefore
describes the same manifest and source tree at both revisions.

Measured shape:

| Claim | Result | Evidence method |
|---|---:|---|
| Products | 31: 2 executables and 29 libraries | `swift package dump-package` |
| Targets | 45: 31 source and 14 test | `swift package dump-package` |
| Root package dependencies | 31 | `swift package dump-package` |
| Internal source-target edges | 138 | dump-package dependency projection |
| Internal source-target cycles | 0 | adjacency traversal; current validation |
| Maximum current internal edge depth | 11 | longest path over the projected DAG |
| Source files / lines | 346 / 40,948 | `find` + `wc -l` |
| Test files / lines | 19 / 1,910 | `find` + `wc -l` |
| Files importing `Logging` | 31 | anchored `rg` import census |
| Logger call sites | 294 | positive verb-pattern census |
| Files importing `Metrics` | 0 | anchored `rg` import census |
| Files importing tracing/instrumentation | 0 | anchored `rg` import census |
| Positive control: files importing `Foundation` | 253 | anchored `rg` import census |

The longest current path is:

```text
com_repotraffic_app
  -> RepositoriesLive -> SyncingLive -> AccountLive -> BillingLive
  -> RepoTrafficRouter -> Analytics -> RepoTrafficRecords -> Account
  -> Billing -> Pricing -> Products
```

This path is evidence of accumulated target coupling, not a proposed semantic hierarchy.

At the accepted census, the source worktree had seven pre-existing untracked, protected
documentation paths. They were not read or modified. A later, separately owned concurrent delta is
recorded below and remains excluded from this checkpoint-pinned evidence. No package, product,
skill, script, or existing Research file was changed by this work.

### Post-checkpoint concurrent delta — excluded observational evidence

The RepoTraffic implementation arc `repotraffic-launch-hardening-20260716` owns the live worktree.
This research remained strictly read-only there. One permitted diff inspection after the accepted
census observed four tracked paths:

- `Package.swift`
- `Sources/com_repotraffic_app/Commands/Migrate.Command.swift`
- `Sources/com_repotraffic_app/Vapor.Application.configure.swift`
- `Tests/RepoTrafficRouter Tests/RouterTests.swift`

That observation was a 100-insertion/5-deletion worktree delta. The manifest portion declared
previously direct/transitive imports explicitly—including the same-package
`com_repotraffic_app -> GrowthLive` edge—and added no product or target declaration. The other
tracked paths are root migration/configuration and a router test, not domain targets. Therefore the
observed delta does not change the package/service seam conclusions, but it can change a *live*
root-dependency count and internal-edge count. Those live counts are deliberately neither absorbed
nor reported as canonical here.

The concurrent worktree continued moving after that one diff inspection. A later non-diff hash
snapshot recorded these exact live blobs (SHA-1), solely to distinguish them from the pinned trees:

| Path | Observed live blob |
|---|---|
| `Package.swift` | `f67ef727d383aea428476e08ed3514316ee59792` |
| `Sources/com_repotraffic_app/Commands/Migrate.Command.swift` | `38efe74e2eda6c9eb41f6c94ffc3800adf55fcbd` |
| `Sources/com_repotraffic_app/Vapor.Application.configure.swift` | `bdf8a9d75a26c932f81b8510e077d1309e4dd177` |
| `Tests/RepoTrafficRouter Tests/RouterTests.swift` | `7dea24b2ebe64e60dd4de322eef0351a8ba6b0da` |

After that implementation arc commits, revalidation must pin its new commit, recompute
Package/Sources/Tests identities, products, targets, root dependencies, exact imports, internal
edges/cycles/depth, and compare the target dispositions. Until then only the mutable live numerical
census is held; every conclusion in this proposal remains stated against `0a24898`.

A final status-only check (no second diff inspection) observed that the external arc had advanced
the live branch again:

| Observation | Final live value, excluded from this evidence |
|---|---|
| HEAD | `e9aaa45d3e38ebcafaa3af1e732f8a0f2f538c8e` |
| `HEAD:Package.swift` | `f8032f5c766d36469d4a752ff6c05d43f37aa632` |
| `HEAD:Sources` | `69814198cb7f0f317a3bf0cdfa2cdd89e366e8d4` |
| `HEAD:Tests` | `5e7842500d3a1f9eb0622ab3beceb52dc4f7e0bb` |
| Tracked worktree delta | `Package.swift`; `Tests/WaitingListLive Tests/WaitingListLiveTests.swift` |
| Additional untracked test path | `Tests/WaitingListLive Tests/Database.TestDatabase.swift` |

The protected untracked documentation paths also remained present and unread. Because the new
committed Source/Test trees were not part of the accepted checkpoint or the one permitted diff
inspection, this record makes no architecture claim about them. A future adoption of
`e9aaa45`—or its successor—requires the full recensus above; it does not retroactively change the
conditional recommendation stated against `0a24898`.

### Existing ecosystem capability census

The following current local commits anchor material reuse findings:

| Repository | Commit | Material fact |
|---|---|---|
| `swift-foundations/swift-identities` | `57509c6c4630ba93ddfd7da08f58c87b5d3b403f` | Small identity identifier/UUID core |
| `swift-foundations/swift-identities-types` | `56f879cadfd4485923d1a0cd61d5717fb3cf4c26` | Large single-target identity/API/client aggregate; decomposition risk |
| `swift-foundations/swift-authentication` | `2dbe7f22f1bc066abfcf86e1e755604d52cd252f` | Shared, Backend, Provider, Views, Consumer, and Frontend products available; Standalone disabled and red |
| `swift-foundations/swift-identities-mailgun` | `fb023d234c11fa60f5c063c364197afde9c47757` | Vends identity/Mailgun integration products |
| `swift-foundations/swift-scheduler` | `f3166dfa4f4b946e0c9a3a2d690fce819868248b` | Engine-free `Scheduler` product |
| `swift-foundations/swift-server` | `1b3767fcf5682cf7ea3b2d8a9362d42e6217536f` | Vends `Server Jobs`, the Queues backing of Scheduler |
| `swift-foundations/swift-email` | `bf39c7b31c088e1ed09ab46e0c08274392133d43` | Reusable email capability |
| `swift-foundations/swift-emailaddress` | `02a2ab0810980d075ba8a75efd53fc211c56b631` | Reusable `EmailAddress` value over the L2 standard package |
| `swift-foundations/swift-mailgun` | `29fb2eb658a3b809cf3ef2a9b61629c81e4889e9` | Mailgun provider products |
| `swift-foundations/swift-crypto` | `58b32a11b8a9660075436b9d2146b6cd5aef16e0` | Reserved repository only: no Package.swift or Sources; not an implemented substitute for RepoTraffic's current Apple swift-crypto dependency |
| `swift-standards/swift-stripe-types` | `fdb024b9b440bc3b0677f6a579350d04e2597606` | L2 Stripe wire/specification types |
| `swift-foundations/swift-stripe` | `d4b0d07371a82048dbfdfef2c0a8369ad58c131f` | L3 Stripe provider clients; no provider-neutral commerce domain |
| `swift-foundations/swift-stripe-live` | `2c5e62bdbd32a7faf4a06551a8ee70e8f9a6c99c` | Provider-specific live conformances, including Stripe Billing/Entitlements positive-control products |
| `swift-standards/swift-github-types` | `7055b52273d9c74ab138ff1fb36580b2228c5843` | L2 GitHub wire/specification types |
| `swift-foundations/swift-github` | `735a6458f88fbdf13f9335f5f1b4986fdcc934c7` | L3 GitHub provider clients |
| `swift-foundations/swift-bounded-cache` | `25825d9918de37ac5c2228e2e3f34bda45d2aea2` | In-process bounded compute-once cache |
| `swift-primitives/swift-cache-primitives` | `b775c853ccf44e58b71797a22ea4356c15e64ffc` | Conflicting/duplicated cache package identity requiring disposition |

Additional direct inspection found current `SQL`, `Migrations`, `Environment`,
`LoggingExtras`, routing/authentication, HTML, GitHub, Stripe, Email, and Mailgun products. No
implemented **provider-neutral** commerce, durable message-delivery, notification, feature-flag, or
audit package was found in the bounded census below.

The negative package claim is bounded to a manifest/product-name census over four exact roots on
2026-07-16: 470 `Package.swift` files under `swift-primitives`, 26 under `swift-standards`, 196 under
`swift-foundations`, and zero under `swift-components` (692 total). A case-insensitive search for
`commerce|billing|subscription|entitlement|message delivery|notification|feature flag|audit`
returned provider-specific positive controls `Stripe Billing*` and `Stripe Entitlements*` in
`swift-stripe-types`, `swift-stripe`, and `swift-stripe-live`; it also returned a tagged-domain
linter target containing “Audit,” which is not an audit-domain package. It returned no neutral
package/product name for the claimed gaps. This supports “no implemented/vended package found”; it
does not claim that no source file or future reservation could express an adjacent concept.

`/Users/coen/Developer/swift-components/` contains 25 reserved component directories, including
cache, jobs, metrics, tracing, worker, and mail names, but no `Package.swift` anywhere beneath that
root. Those directories are design reservations, not reusable implementations. They do not
supersede the implemented Scheduler/Server Jobs products or establish package boundaries.

### Source evidence that controls key seams

- `swift-authentication/Package.swift:64-99,155-238`: current identity product availability and
  the explicitly disabled Standalone target.
- `swift-authentication/Package.swift:137-144` plus `Sources/Identity Shared/`: Identity Shared
  imports ServerFoundation/Vapor, and 17 of its 22 Swift files import Foundation. This is measured
  counter-evidence to treating the current target as a clean L3 contract; the positive file-count
  control is the 22-file target census.
- `swift-identities-mailgun/Package.swift:32-78`: current identity/Mailgun integration products.
- `swift-scheduler/Package.swift:5-29`: the engine-free Scheduler product.
- `swift-server/Package.swift:10-44,92-104`: `Server Jobs` and its Scheduler/Queues join.
- `institute-server-stack-architecture.md:38-48,351-376,406-414,444-482`: fixed server,
  persistence, jobs, and Redis decisions.
- `repotraffic-com-server/Package.swift:87-164,199-939`: current products, root dependencies, and
  target graph.
- `Sources/com_repotraffic_app/Application.swift:132-194`: database, cache, and embedded identity
  construction in the current composition root.
- `Sources/com_repotraffic_app/Dependencies/Identity+Live.swift:40-182`: app-side reconstruction of
  the disabled Identity Standalone assembly and raw-SQL session invalidation workaround.
- `Sources/com_repotraffic_app/Dependencies/Identity.Backend.Configuration.Email+RepoTraffic.swift:5-30,110-161`:
  app-side identity/Mailgun integration that now has an ecosystem package candidate.
- `Sources/Cache/Cache.swift:6-114` and `Sources/Cache/Cache.Store.swift:6-120`: generic-looking
  store mechanics mixed with RepoTraffic tier/TTL policy.
- `Sources/Account/Account.swift:11-18`, `Sources/Account/GitHub/Account.GitHub.Record.swift:7-20`,
  and `Sources/AccountLive/Account.View.Client+Live.swift:14-63`: Account is a wrapper around the
  GitHub connection; its only table is provider-specific, while its other DB behavior is a
  cross-domain view projection. This is negative evidence for generic RTAccount/RTAccountSQL rent.
- `Sources/AccountLive/Account.GitHub+Live.swift:28-122` and
  `Sources/AccountLive/Account.GitHub.Token+Live.swift:8-77`: GitHub validation, credential
  persistence, atomic repository-membership cleanup and Apple Crypto AES-GCM protection are four
  separable responsibilities. The current Crypto dependency remains bounded pending Institute
  capability disposition.
- `Sources/Billing/Billing.Subscription.State.swift:16-123`,
  `Sources/Billing/Billing.Stripe.Webhook.swift:16-123`, and
  `Sources/Billing/Stripe.Event.Record.swift:13-131`: provider-neutral lifecycle, product-specific
  entitlements, Stripe handling, durable receipt, idempotency, and persistence mixed together.
- `Sources/Billing/Billing.Subscription.Record.swift:9-53`: the current subscription row mixes
  neutral state with Stripe customer/subscription/schedule identifiers, requiring separate neutral
  and provider-binding SQL ownership plus a compatibility migration.
- `Sources/Billing/Identity.Context+Subscription.swift:25-63`: an Identity × Billing join residing
  in the Billing target rather than a dedicated integration.
- `Sources/Products/Product.Catalog.swift:5-70` and
  `Sources/Products/Product.Entitlements.swift:3-70`: reusable catalog shape mixed with
  RepoTraffic policy.
- `Sources/AccessControl/AccessControl.swift:9-75`: product-specific repository-traffic access
  projection, not evidence for a generic authorization system.
- `Sources/com_repotraffic_app/Jobs/AutoTrackAllReposJob.swift:15-33`,
  `Jobs/GitHubPollingJob.swift:25-81`, and `Jobs/CacheRefreshJob.swift:24-180`: two retained jobs
  invoke Repository/Ingestion domains; CacheRefresh's actual refresh call is disabled while its
  cross-schema scan, tier decision and marker writes remain, so retirement needs an explicit gate.
- `Sources/SyncingLive/Syncing+Composable+Live.swift:164-235,489-525`: the ingestion algorithm
  resolves/decrypts/caches credentials, calls GitHub, persists traffic and drives onboarding. The
  algorithm belongs RTIngestion behind ports; adapters depend on those ports and roots only select
  conformances.

Line references name the inspected local revision; exact paths are listed in References.

## Evidence commands

The object identities can be reproduced from any checkout. The `dump-package`, import and line
censuses must run from a clean checkout of the accepted commit—not the concurrently edited live
worktree—and do not require reading protected user documents:

```sh
cd /Users/coen/Developer/repotraffic/repotraffic-com-server
git rev-parse 0a2489838e515405562c417a10647691442f9d20 \
  0a2489838e515405562c417a10647691442f9d20:Package.swift \
  0a2489838e515405562c417a10647691442f9d20:Sources \
  0a2489838e515405562c417a10647691442f9d20:Tests
git diff --numstat f820eac..0a2489838e515405562c417a10647691442f9d20 -- Package.swift Sources Tests
# The commands below require a clean checkout at 0a2489838e515405562c417a10647691442f9d20.
swift package dump-package | jq '{
  name,
  productCount:(.products|length),
  targetCount:(.targets|length),
  sourceTargets:([.targets[]|select(.type != "test")]|length),
  testTargets:([.targets[]|select(.type == "test")]|length),
  dependencyCount:(.dependencies|length)
}'
find Sources -type f -name '*.swift' | wc -l
find Sources -type f -name '*.swift' -print0 | xargs -0 wc -l | tail -1
find Tests -type f -name '*.swift' | wc -l
find Tests -type f -name '*.swift' -print0 | xargs -0 wc -l | tail -1
rg -l '^import Logging$' Sources --glob '*.swift' | wc -l
rg -o 'logger\.(trace|debug|info|notice|warning|error|critical)\b' Sources --glob '*.swift' | wc -l
rg -l '^import Metrics$' Sources --glob '*.swift' | wc -l
rg -l '^import (Tracing|Instrumentation)$' Sources --glob '*.swift' | wc -l
rg -l '^import Foundation$' Sources --glob '*.swift' | wc -l

# Bounded ecosystem package/product-name census and positive controls.
rg --files /Users/coen/Developer/swift-primitives -g 'Package.swift' | wc -l
rg --files /Users/coen/Developer/swift-standards -g 'Package.swift' | wc -l
rg --files /Users/coen/Developer/swift-foundations -g 'Package.swift' | wc -l
rg --files /Users/coen/Developer/swift-components -g 'Package.swift' | wc -l
rg -n -i --glob 'Package.swift' \
  'commerce|billing|subscription|entitlement|message[ _-]?delivery|notification|feature[ _-]?flag|audit' \
  /Users/coen/Developer/swift-primitives \
  /Users/coen/Developer/swift-standards \
  /Users/coen/Developer/swift-foundations \
  /Users/coen/Developer/swift-components
```

Internal edges were projected from `dump-package` by retaining dependencies whose names are in the
31-node non-test target set. The proposed graph is separately recorded as TSV and checked in the
dependency/layer artifact.

## Limits and uncertainties

1. This is a source/manifests architecture census, not production telemetry. Logging counts do not
   prove observability quality; zero metrics/tracing imports are controlled absence, not proof that
   the product has no operational need.
2. No second SaaS codebase was supplied. Package rent is therefore justified by capability and
   semantic theory, never by invented consumer demand. Checkout and waiting-list extraction retain
   explicit canary gates.
3. Identity's embedded composition is real; its clean L3 contract seam is not. Identity Shared
   imports ServerFoundation/Vapor and Foundation in 17/22 files. A future main L3 contract must be
   Foundation-free, with genuine interop isolated in a dedicated integration leaf. Independent-
   service packaging is also not currently buildable because `Identity Standalone` is unvended and
   explicitly red.
4. The current app uses `swift-records`, while the ratified architecture supersedes and splits it.
   Proposed persistence integrations name the final `SQL`/`Migrations` surfaces, not a new
   commitment to Records.
5. Cache ownership is unresolved: two repositories overlap and the logical L4 cache reservations
   are empty. This proposal therefore does not create a third cache abstraction.
6. Package names in the proposal are working architecture labels. Final repository creation,
   physical L4 organization, public API naming, visibility, and release policy require Principal
   disposition and normal package-creation workflows.
7. GitHub credential protection currently uses Apple swift-crypto. The similarly named Institute
   repository is unimplemented, so the target graph's `Crypto` anchor is conditional: retain the
   current compatibility adapter until bounded external use is approved or an Institute capability
   is implemented through its normal workflow.

## Outcome

**Status**: RECOMMENDATION — pending Principal adjudication.

The evidence supports a package graph, not a `swift-saas` mega-package and not a fleet of default
microservices. Existing identity, scheduling, jobs, email, Mailgun, SQL/migrations, server, logging,
HTML, GitHub, and Stripe mechanisms should be reused. The strongest new foundation seams are
provider-neutral catalog/pricing/subscription/entitlement invariants and durable message delivery.
Checkout and waiting-list are candidate L4 components behind explicit experiments. RepoTraffic's
GitHub ingestion, analytics, access policy, branding, and deployment remain L5.

The concrete atlas, graph, service-rent decisions, thin-app budget, extraction waves, and review
record live in the companion artifacts.

## References

- [Swift Institute architecture skill](/Users/coen/Developer/swift-institute/Skills/swift-institute/SKILL.md)
- [Swift Institute ecosystem skill](/Users/coen/Developer/swift-institute/Skills/swift-institute-ecosystem/SKILL.md)
- [Modularization skill](/Users/coen/Developer/swift-institute/Skills/modularization/SKILL.md)
- [Layer placement](/Users/coen/Developer/swift-institute/Skills/modularization/layer-placement.md)
- [Package decomposition](/Users/coen/Developer/swift-institute/Skills/modularization/package-decomposition.md)
- [Cross-package integration](/Users/coen/Developer/swift-institute/Skills/modularization/cross-package.md)
- [Swift package skill](/Users/coen/Developer/swift-institute/Skills/swift-package/SKILL.md)
- [Research-process skill](/Users/coen/Developer/swift-institute/Skills/research-process/SKILL.md)
- [Institute server-stack architecture](/Users/coen/Developer/swift-institute/Research/institute-server-stack-architecture.md)
- [RepoTraffic Package.swift](/Users/coen/Developer/repotraffic/repotraffic-com-server/Package.swift)
- [RepoTraffic launch assessment](/Users/coen/Developer/repotraffic/repotraffic-com-server/Assessment/2026-07-16-substrate-assessment.md)
- [RepoTraffic Sources](/Users/coen/Developer/repotraffic/repotraffic-com-server/Sources/)
- [Local ecosystem repositories](/Users/coen/Developer/)
- [Independent review record](independent-review-record.md)
