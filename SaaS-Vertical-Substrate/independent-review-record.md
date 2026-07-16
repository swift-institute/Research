# SaaS Vertical Substrate — Independent Review Record

<!--
---
version: 1.1.0
last_updated: 2026-07-16
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
changelog:
  - 1.1.0 (2026-07-16): Recorded the fresh R2 reconciliation review and clean-accept disposition.
  - 1.0.0 (2026-07-16): Recorded the read-only independent architecture review and conditional-accept disposition.
---
-->

## Context

The SaaS vertical-substrate charter requires review independent from the authoring pass before the
recommendation can be presented for Principal judgment. The reviewer `/root/architecture_review`
worked strictly read-only, edited no artifact, and evaluated the commit-pinned evidence, complete
target matrix, package/layer claims, machine-readable graph, service-rent analysis and extraction
gates as they changed during remediation.

## Question

Are the evidence, package/service adjudications, target destinations, dependency graph and canaries
complete and internally coherent enough for Principal review, with every unresolved authority or
evidence condition explicit rather than silently treated as approved?

## Analysis

### Findings and dispositions

| Finding | Severity at discovery | Resolution verified by reviewer |
|---|---|---|
| Cross-domain SQL projections omitted exact schema dependencies | Blocking | Analytics, Access and ingestion projections now name their exact provider-binding/Repository/Traffic schemas; Access no longer imports TrafficSchema. |
| Proposed L5 target graph exceeded the shallow-DAG budget and risked a generic Core target | Blocking | `RTIdentifiers` is identifier-only behind IDV1; the final L5 intra-package depth is 3 with no generic DTO/client/policy/schema grab-bag. |
| A no-upward check was incorrectly presented as full layer approval | Blocking | Layer wording is fail-closed; 38 same-layer L3/L4 package edges exactly match 38 OPEN entries in `lateral-edge-asks.tsv`. |
| Stripe and GitHub integrations grouped unrelated recipient/storage/delivery concerns | Blocking | Stripe catalog, subscription, delivery, binding SQL and atomic SQL roles are separate; RepoTraffic GitHub joins are split by account, repository and traffic recipient. |
| Identity Shared was treated too optimistically as an L3 contract | Blocking | The record includes ServerFoundation/Vapor and 17/22 Foundation-import evidence; IdentityContract is a future Foundation-free seam, not a current purity claim. |
| GitHub account connection lacked provider-specific credential schema/SQL and atomic membership cleanup | Blocking | `RTAccountGitHubSchema` and `RTAccountGitHubSQL` are explicit; the latter names RTRepositorySchema only for the single disconnect transaction. |
| GitHub credential encryption had no semantic owner or Crypto prerequisite | Blocking | `RTAccountGitHubCrypto` owns the protection conformance and G2; root injects configuration only. Apple Crypto vs the unimplemented Institute reservation is an explicit Principal prerequisite. |
| Access SQL preserved the mixed access-plus-traffic result under a new name | Blocking | RTAccess owns decision/scope; RTAccessSQL loads only binding/membership inputs; Web fetches Traffic/Analytics after allow and A1 fails on regression. |
| Post-connect repository subscription and ingestion onboarding had no behavior home | Blocking | RTWeb has explicit Repository/Ingestion workflow edges; root remains wiring-only and G1 covers the effects. |
| Ingestion sequencing existed only in current SyncingLive, not the target graph | Blocking | RTIngestion owns the algorithm and abstract ports; provider, SQL, credential-cache and invalidation adapters depend inward; root selects conformances and IG1 proves ordering/effects. |
| Cache key/TTL/invalidation policy could fall into the root | Blocking | Evidenced protected-token caching lives in RTAccountGitHubCache. RTAnalyticsCache is explicitly conditional on C2 because no pinned Analytics cache call site exists. |
| RTJobs claimed all jobs without Repository and cross-schema behavior | Blocking | Polling and auto-track are retained through RTIngestion/RTRepository. CacheRefresh is a J0-gated retirement or named materialization replacement, never raw SQL in Jobs/root. |
| Generic RTAccount/RTAccountSchema/RTAccountSQL had no independent source law/table/query | Blocking | Those nodes were removed; the Account wrapper is dissolved into GitHub connection, Web and exact projection seams. |
| Neutral subscription persistence still mixed Stripe, Identity and RepoTraffic identifiers | Blocking | Subscription uses neutral subject/catalog identifiers; RTCommercePolicy maps Identity/tier/addon/SKU; SubscriptionStripeSQL owns the three provider IDs. |
| Receipt, neutral subscription and provider-binding updates had no explicit atomic owner | Blocking | SubscriptionStripeDeliverySQL owns one transaction across MessageDeliverySQL, SubscriptionSQL and SubscriptionStripeSQL; SB1/TX1 cover migration and failure atomicity. |
| Foundation-free enforcement covered Identity only | Blocking | F1 now applies [ARCH-LAYER-007]/[ARCH-LAYER-013] to every L1–L5 main target; only explicit opt-in leaf integrations may use Foundation, with leaf → core direction. |
| RTAnalyticsSQL duplicated commerce policy below RTAccess | Blocking | The RTCommercePolicy edge was removed; AnalyticsSQL receives already-authorized neutral scope and owns query projection only. |
| Records-home wording contradicted separate schema targets | Minor | The reconciliation now assigns tables/migrations to schema targets and queries to SQL adapters. |
| Negative ecosystem package claims lacked exact roots and positive controls | Traceability | Provenance now records the 470/26/196/0 manifest census, exact query, Stripe Billing/Entitlements positives and the non-domain Audit linter hit. |
| Initial provenance total mistyped 470 as 47 | Blocking until corrected | Corrected and independently reproduced as 470 + 26 + 196 + 0 = 692 manifests. |

### Final independent verification

- current-to-target matrix: **31/31** pinned non-test targets;
- proposed graph: **186 edges, 70 nodes, acyclic, zero upward edges**;
- maximum global edge depth: **6**;
- L5 target graph: **28 nodes, 66 intra-L5 edges, depth 3**;
- lateral authority ledger: **38/38 exact matches, all OPEN**;
- ecosystem manifest census: **470 / 26 / 196 / 0 = 692**, with recorded positive controls;
- post-review live RepoTraffic advancement: segregated as status-only observational evidence; all
  four recorded Git identities reproduced, with `0a24898` remaining the sole conclusion checkpoint;
- review mutations: **none**.

### Remaining conditions

The remaining conditions are declared architecture decisions or canary gates, not hidden review
defects. They include exact lateral-edge authority, Crypto mechanism disposition, RTIdentifiers
cohesion, neutral Subscription identifier law, money/currency vocabulary, CacheRefresh disposition,
conditional RTAnalyticsCache rent, IdentityContract/Standalone work, L4 physical home and component
promotion. The authoritative complete list is the Principal-decision table in the extraction plan.

## Outcome

**Status**: RECOMMENDATION — **CONDITIONAL ACCEPT for Principal review**.

No independent-review defect remains. The evidence and recommendation set are coherent enough for
Principal adjudication. Conditional acceptance does not authorize package creation, implementation,
release, service deployment or any of the 38 lateral edges; those actions remain behind the recorded
Principal dispositions, edit zones and canaries.

## R2 fresh independent review

The reviewer `/root/r2_fresh_review` performed a new read-only pass after the immutable RepoTraffic
hardening and networking reconciliation. The review covered the complete R2 packet, exact delta
ledger, all 38 amended lateral rows, R1 conditional projection, ServerFoundation dissolution,
network sequencing, Control Plane implications, and the nominated immediate implementation batch.
It read no uncommitted RepoTraffic content and modified no repository.

### Findings and dispositions

| Finding | Severity | Disposition |
|---|---|---|
| Initial `ENV-R2-1` moved public URL/projectRoot/live-file APIs while claiming no consumer edits | Blocking | Replaced with an additive three-target migration: Foundation-free Core, explicit Foundation Integration leaf, and a behavior-free deprecated compatibility facade. New consumers select Core/leaf directly; complete consumer census, compile fixture, exact retirement gate, and separately versioned breaking removal are explicit. |
| Environment split could hide process-only live reading, Foundation-backed string helpers, or an unused test-support import | Blocking until bounded | Process-only `Environment.read.all()`, the EnvVars dependency key, exact `allowedInsecureHosts` parity, and `EnvVars.TestSupport` import disposition are explicit. Acceptance checks public/re-exported/typealiased/signature API, not import text alone, and validates canonical target/product names and Core←leaf direction. |
| Restored WaitingList test import wording said ten | Minor | Corrected to nine restored-test non-toolchain imports plus Account's one type-only import, matching the exact +10 delta (`reconciliation-r2-principal-decision-packet.md:176-177`). |
| Import-count method named only Foundation/Testing exclusions | Minor | Corrected to include the single unchanged SwiftUI platform edge, reproducing 404/412 (`reconciliation-r2-principal-decision-packet.md:131-137`). |
| Root-quarantine policy row also requested a boot-canary execution authorization | Minor | Separated: Principal ratifies quarantine; the future two-executable boot canary is a distinct execution action (`reconciliation-r2-principal-decision-packet.md:193-200`). |

### R2 final verification

- immutable recensus: 31 products; 45→46 targets; 31→37 root dependencies; 497→434
  declared rows; 163→162 internal edges; depth 11→9;
- exact delta ledger: 182 data rows, comprising +1 target, +6 roots, +50/-113 declared rows,
  and +10/-2 active non-toolchain import edges;
- R1/R2 proposal arithmetic: 70 nodes/186 edges → 69/181 after omitting conditional
  `RTAnalyticsCache` and its five incident edges;
- lateral classifications: 38/38, with 3 policy-blocked, 4 probe-blocked and 31 superseded
  candidates; no automatic disposition;
- Ask A and ServerFoundation: recommendations, compatibility, migration, probes, and policy
  authority remain distinct;
- networking and Control Plane: committed design evidence only, with no inferred implementation
  authority or migration machinery;
- immediate batch: additive, clean-zone, policy-independent, source-compatible in its extraction
  commit, and bounded away from consumer migration;
- generic SaaS, billing, identity-service, and service-fleet proposals: rejected for lack of rent;
- `git diff --check`: pass; reviewer mutations: none.

### R2 outcome

**Status: CLEAN / ACCEPT for Principal review.** No blocker or minor finding remains. This review
disposition does not decide the three Principal bundles or broaden implementation authority.
`ENV-R2-1` may begin under the controller's separately stated clean-zone authorization because its
Foundation boundary is already canonical; all other work remains behind the packet's decisions,
probes, and concurrency guards.

## References

- [Provenance and architecture](provenance-and-architecture.md)
- [Capability atlas and target matrix](capability-atlas-and-current-to-target-matrix.md)
- [Dependency, layer, and golden path](dependency-layer-and-golden-path.md)
- [Proposed edges](proposed-edges.tsv)
- [Lateral-edge asks](lateral-edge-asks.tsv)
- [Service-rent decisions](service-rent-decisions.md)
- [Extraction and canary plan](extraction-and-canary-plan.md)
- [Seat charter](/Users/coen/Developer/swift-institute/Workspace/charters/active/saas-vertical-substrate.md)
