# SaaS Vertical Substrate — Independent Review Record

<!--
---
version: 1.0.0
last_updated: 2026-07-16
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
changelog:
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

## References

- [Provenance and architecture](provenance-and-architecture.md)
- [Capability atlas and target matrix](capability-atlas-and-current-to-target-matrix.md)
- [Dependency, layer, and golden path](dependency-layer-and-golden-path.md)
- [Proposed edges](proposed-edges.tsv)
- [Lateral-edge asks](lateral-edge-asks.tsv)
- [Service-rent decisions](service-rent-decisions.md)
- [Extraction and canary plan](extraction-and-canary-plan.md)
- [Seat charter](/Users/coen/Developer/swift-institute/Workspace/charters/active/saas-vertical-substrate.md)
