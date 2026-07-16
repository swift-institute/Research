# SaaS Vertical Substrate — Dependency, Layer, and Golden-Path Map

<!--
---
version: 0.1.0
last_updated: 2026-07-16
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
changelog:
  - 0.1.0 (2026-07-16): Initial package/component matrix, checked edge graph, thin-app budget, and golden path.
---
-->

## Context

The reusable vertical is not one package. It is a composition recipe over small existing and
candidate packages, dedicated integration packages, and L5 product targets. Working labels below
make seams reviewable; they do not authorize repositories, organization changes, APIs, or releases.

## Question

What is the smallest coherent layered graph that lets RepoTraffic and a second SaaS compose
identity, commerce, delivery, jobs, email, storage, and operations without a mega-framework or
provider leakage?

## Analysis

The analysis maps current and candidate units into layers, enumerates their direct edges, then tests
the resulting graph, thin-root budget, runtime composition and release proof obligations.

## Proposed shape

```text
L5  RepoTraffic roots, Web, product domains/policy, product SQL/GitHub joins, product jobs
     -------------------------------------------------------------------------------
L4  Identity components / Mailgun join   Checkout        Waiting List
     Server / Server Jobs / Server PostgreSQL            + provider/SQL/HTTP joins
     -------------------------------------------------------------------------------
L3  Subscription -> Catalog -> Pricing      Entitlement      Message Delivery
     Stripe/SQL integration packages         Identity contract/core     Scheduler
     Email/Mailgun   SQL/Migrations           Cache/Crypto     Environment/Logging
     -------------------------------------------------------------------------------
L2  Stripe/GitHub specification types and other existing standards
```

Arrows in prose point from a consumer to a dependency. The actual machine-readable graph is
`proposed-edges.tsv`.

Compact identifiers such as `MessageDelivery`, `CatalogStripe`, and `RTAccountGitHubSQL` are graph node
IDs only. They are not proposed Swift type identifiers. Any later public API must be designed under
the canonical `Nest.Name` and package/product/module naming rules (for example, a message-delivery
domain would use a nested semantic namespace rather than a compound type name).

Existing-anchor node mapping:

| Graph node | Current package/product meaning |
|---|---|
| `IdentityCore` | current identifier/value core in `swift-identities` |
| `IdentityContract` | target provider-neutral authentication/session contract seam; current Identity Shared is evidence but still imports server products |
| `IdentitySQL` | target IdentityContract × SQL/Migrations integration seam; current Backend still binds Records internally |
| `IdentityComponent` | active Backend/Provider/Views/Consumer/Frontend products in `swift-authentication` |
| `IdentityMailgun` | products in `swift-identities-mailgun` |
| `EmailAddress`, `Email`, `Mailgun` | `swift-emailaddress`, `swift-email`, `swift-mailgun` |
| `Scheduler` | `Scheduler` product in `swift-scheduler` |
| `SQL`, `Migrations` | products in `swift-sql` and `swift-sql-migrations` |
| `StripeTypes`, `StripeClient` | `swift-stripe-types` (L2) and `swift-stripe` (L3) |
| `GitHubTypes`, `GitHubClient` | `swift-github-types` (L2) and `swift-github` (L3) |
| `BoundedCache` | the compatible process-local capability, pending cache-repository ownership ruling |
| `Crypto` | current bounded Apple `swift-crypto` mechanism; the Institute `swift-crypto` repository is reserved and unimplemented, so this anchor requires explicit disposition |
| `Environment`, `Logging` | `swift-environment` and swift-log/LoggingExtras surfaces |
| `Server`, `ServerJobs`, `ServerPostgreSQL`, `ServerHTTPClient` | corresponding logical L4 products in `swift-server` |

## Reusable package/component decision matrix

### Existing units to retain and reuse

| Unit | Layer | Semantic owner and API responsibility | Allowed dependencies / integrations | Deployment posture | Evidence, hazard, decision |
|---|---|---|---|---|---|
| `swift-identities` | L3 | Identity identifier/value invariants | Lower identity/UUID primitives only | In-process library | Current small core; **RETAIN** |
| `swift-authentication` active products | Mixed current package with a desired L3 contract seam and logical L4 backend/provider/view components; package is L4 at its highest responsibility | Authentication/session behavior and its opinionated server, persistence, consumer and presentation assemblies | Target state puts server/persistence/HTML only in component products; current Identity Shared still imports ServerFoundation/Vapor | Embedded component or hosted behind a protocol | Six active products; Standalone remains red; Shared is not currently a clean L3 contract. **RETAIN current products, require identity-architecture seam work before claiming L3 purity** |
| `swift-identities-mailgun` | Logical L4 integration | Identity component email operations mapped to Mailgun delivery | Identity component + Email/HTML + Mailgun; never imported by base Identity contracts | In-process adapter | Vends two products and supersedes app-local closure assembly. **REUSE** |
| `swift-scheduler` | L3 | Engine-free job, schedule, registry, driver and execution contracts | Time/encoding primitives; no Queues engine | In-process interface | Implemented and ratified. **REUSE** |
| `swift-server` / `Server Jobs` | logical L4 | Server lifecycle and the Queues conformance of Scheduler | Server, Scheduler, Queues inside L4 quarantine | Web process or worker process | Current products and ratified role. **REUSE; do not invent `swift-jobs`** |
| `SQL` + `Migrations` | L3 | Engine-free database execution and schema migration contracts | SQL vocabulary and lower primitives | In-process interfaces | Implemented direction from ratified server-stack architecture. **REUSE** |
| `Server PostgreSQL` | logical L4 integration | PostgresNIO conformance of SQL/Migrations | SQL/Migrations + quarantined engine | Same deployment as consumer | Current server product. **REUSE during engine transition** |
| `swift-emailaddress` + `swift-email` | L3 | Email-address value semantics and email message mechanism | EmailAddress Standard and lower encoding/network-neutral types | In-process libraries | Current distinct capabilities; Waiting List uses EmailAddress directly. **REUSE with exact direct products** |
| `swift-mailgun` | L3 provider | Mailgun request/response client surfaces | Email/HTTP/provider types | In-process adapter to external Mailgun service | Current products. **REUSE** |
| `swift-stripe-types` / `swift-stripe` | L2 provider specification types / L3 provider client | Stripe wire vocabulary / executable clients | L2 types remain Foundation-free per their own rules; clients depend downward on types and HTTP mechanisms | In-process adapter to external Stripe service | Broad provider implementation; not a neutral commerce domain. **REUSE both only in dedicated integrations** |
| `swift-github-types` / `swift-github` | L2 provider specification types / L3 provider client | GitHub wire vocabulary / executable clients | Same L2-types/L3-client split | In-process adapter to external GitHub service | Current RepoTraffic dependency. **REUSE both only in RepoTraffic × GitHub join** |
| Apple `swift-crypto` / reserved Institute `swift-crypto` | Current external L3-shaped mechanism / unimplemented Institute reservation | Cryptographic primitives only; product key shape, ciphertext format and rotation policy stay in the owning integration | In-process | RepoTraffic currently imports Apple Crypto, while the Institute repository at `58b32a11b8a9660075436b9d2146b6cd5aef16e0` has no Package.swift/Sources. **ASK: implement/improve the Institute seam through its workflow or approve bounded external use; do not silently ratify either** |
| `swift-bounded-cache` / cache primitive | L3, ownership unresolved | In-process bounded compute-once caching | Concurrency/time primitives | Process-local | Useful semantics exist, but two repositories overlap. **REUSE compatible behavior; ASK before ownership change** |
| `Environment`, Logging/LoggingExtras, HTML/SVG/Favicon stack | L3 mechanisms | Typed environment access, logs, and rendering mechanisms | Their existing lower dependencies | In-process | Current capabilities. **REUSE; keep product config/branding at L5** |

The edge graph represents the provider-neutral identity contract as `IdentityContract` (L3) and the active
Backend/Provider/Views/Consumer/Frontend assembly as `IdentityComponent` (L4). More precisely, the
current `swift-identities` value core is `IdentityCore`, while `IdentityContract` is a target seam
that current Identity Shared does not yet satisfy because it imports ServerFoundation/Vapor. This is
a logical layer boundary, not an authorization to split `swift-authentication`. The physical
`swift-foundations` home of logical L4 identity/server products is current topology (and a ratified
temporary tenancy for Server); this proposal does not silently decide the future L4 organization.

### Candidate L3 foundations and integrations

| Working unit | Semantic owner and API responsibility | Direct dependencies | Integration packages | Deployment posture | Reuse evidence and extraction hazard | Decision |
|---|---|---|---|---|---|---|
| Identity contract seam (`IdentityContract`) | Provider-neutral authentication/session client and context contracts, below server/persistence/views | `IdentityCore` and lower identity/token vocabulary only | Identity component, Foundation interop and Mailgun joins remain above/in dedicated leaves | Library contract used embedded or remote | Current Identity Shared supplies behavior evidence but imports ServerFoundation/Vapor and Foundation in 17/22 files; `swift-identities-types` is also a large aggregate. Physical package/product placement needs identity-architecture review. | **PROPOSE Foundation-free seam; do not claim current L3 purity or create a package here** |
| Identity × SQL seam (`IdentitySQL`) | Identity record/session persistence and migrations behind the provider-neutral contract | IdentityContract + SQL + Migrations | Server PostgreSQL selected above it | In-process adapter for embedded/hosted modes | Current Backend binds Records internally and RepoTraffic uses raw SQL for invalidation. Exact schema/API move belongs to identity architecture. | **PROPOSE dedicated join; physical product/package deferred** |
| `swift-pricing` (`Pricing`) | Money/price/currency/cadence value semantics; no catalog or provider client | Lower numeric/time/currency vocabulary only | `swift-catalog-stripe` maps provider prices | Library | Current Pricing surface is small but Stripe-coupled; no existing generic money/currency package was found. Currency/decimal representation must be proven first. | **PROPOSE after value-semantics experiment** |
| `swift-catalog` (`Catalog`) | Product/SKU/offer catalog invariants and provider-neutral lookup contract | `Pricing` | Catalog × Stripe | Library | Current Products has catalog/SKU/plan shape but mixes RepoTraffic tiers/capabilities. | **PROPOSE; extract neutral law only** |
| `swift-subscription` (`Subscription`) | Subscription lifecycle, period, scheduled change, cancellation/reactivation and provider-neutral client contract | `Catalog` | Subscription × Stripe; Subscription × SQL | Library | Current Billing exposes a coherent lifecycle but mixes records, routes, Stripe and product capability flags. | **PROPOSE** |
| `swift-entitlement` (`Entitlement`) | Parameterized grant/requirement/decision semantics; no product capability enum | Lower identifier/collection primitives | L5 product policy composes Subscription → Entitlement; no provider adapter | Library | Same decision concept recurs in Products/Billing/AccessControl, but current capabilities are product-specific. Generic parameterization must be tested for honesty. | **PROPOSE behind API canary** |
| `swift-message-delivery` (`MessageDelivery`) | Message envelope, idempotency key, inbox receipt, handling state, retry classification, optional outbox contract | Lower time/identity/encoding primitives | Delivery × SQL; provider handlers depend on it | Library; relay may run in worker | Stripe event records prove durable receipt/idempotency. Do not promise exactly-once; transactional outbox remains conditional. | **PROPOSE** |
| `swift-catalog-stripe` (`CatalogStripe`) | Maps provider products/prices to Catalog/Pricing without leaking Stripe types downward | Catalog + Pricing + Stripe provider | None beneath it | In-process provider adapter | PricingLive/ProductsLive and Stripe catalog code are concrete evidence. | **PROPOSE dedicated join** |
| `swift-subscription-stripe` (`SubscriptionStripe`) | Stripe subscription IDs/payloads/client calls mapped to the neutral lifecycle; no catalog mapping or receipt ownership | Subscription + Stripe types/client | Catalog × Stripe and durable delivery are selected separately | In-process provider adapter | Current BillingLive/Billing.Stripe proves the seam. Keeping delivery/catalog out prevents a smaller BillingLive grab-bag. | **PROPOSE dedicated two-party join** |
| `swift-message-delivery-stripe` (`MessageDeliveryStripe`) | Stripe signature/event-envelope/idempotency evidence mapped to Message Delivery | MessageDelivery + Stripe types/client | Domain handlers supplied above | In-process webhook adapter | Current Stripe.Event.Record/signature validation proves the provider-delivery seam independent of subscriptions. | **PROPOSE dedicated two-party join** |
| Subscription × Stripe × Message Delivery (`SubscriptionStripeDelivery`, working name only) | Maps verified Stripe subscription events into provider-neutral delivery/transition commands | Subscription + MessageDelivery + SubscriptionStripe + MessageDeliveryStripe | The SQL-specific atomic handler is separate | Web or worker process | The three-way mapping is distinct; it owns no route, catalog mapping, receipt table, subscription table or provider-binding storage. Final package name/layer authority requires Principal review. | **PROPOSE dedicated integration** |
| `swift-subscription-sql` (`SubscriptionSQL`) | Provider-neutral subscription state persistence, queries and migrations | Subscription + SQL + Migrations | Server PostgreSQL selected above it | In-process adapter | Current Subscription.Record mixes neutral state with three Stripe IDs. Only neutral state moves here. | **PROPOSE** |
| Subscription × Stripe × SQL (`SubscriptionStripeSQL`, working name only) | Provider-binding schema and lookups for Stripe customer/subscription/schedule IDs keyed to neutral subscription identity | Subscription + SubscriptionStripe + SQL + Migrations | Server PostgreSQL selected above it | In-process adapter | Exact provider IDs are required for update/cancel/schedule operations but must not leak into SubscriptionSQL. Expand/backfill/contract migration and uniqueness/FK proof are mandatory. | **PROPOSE dedicated provider-binding integration** |
| `swift-message-delivery-sql` (`MessageDeliverySQL`) | Durable inbox/outbox records, claiming and migrations | MessageDelivery + SQL + Migrations | Server PostgreSQL selected above it | In-process adapter; relay can be worker | Current Stripe.Event.Record proves inbox state; generic outbox is unproved. | **PROPOSE inbox first; outbox conditional** |
| Subscription × Stripe × Delivery × SQL (`SubscriptionStripeDeliverySQL`, working name only) | One concrete transaction coordinator for receipt claim, neutral subscription mutation and Stripe-binding update | SubscriptionStripeDelivery + SubscriptionSQL + SubscriptionStripeSQL + MessageDeliverySQL + SQL | Server PostgreSQL selected above it | Web or worker process | Makes the current atomic boundary explicit without teaching pure handler or root about tables. It owns transaction coordination only. | **PROPOSE dedicated atomic integration; TX1 required** |

There is deliberately no `swift-saas`, `swift-commerce`, or generic `swift-billing` umbrella.
Catalog, pricing, subscription, entitlement and delivery have separate laws and release axes.

### Candidate L4 components and integrations

| Working unit | Semantic owner and API responsibility | Direct dependencies | Integration packages | Deployment posture | Reuse evidence and extraction hazard | Decision |
|---|---|---|---|---|---|---|
| `swift-checkout` (`Checkout`) | Opinionated provider-neutral checkout intent/result/session workflow | Catalog + Pricing | Checkout × Stripe | Embedded component | Current Checkout has a plausible client seam, but session types leak Stripe and routes/views dominate. | **CANARY before package creation** |
| `swift-checkout-stripe` (`CheckoutStripe`) | Stripe checkout-session creation/mapping | Checkout + Catalog + Pricing + Stripe | None beneath it | In-process adapter to Stripe | Current CheckoutLive is mixed with analytics/Billing/Router. Those L5 concerns must not move with it. | **PROPOSE only if Checkout canary passes** |
| `swift-waiting-list` (`WaitingList`) | Entry/confirmation/referral/admin invariants and provider-neutral clients; no product copy/views | `EmailAddress` value vocabulary | SQL, Mailgun and Remote joins | Embedded by default | Current domain is coherent but mixes routes and product behavior. | **CANARY before package creation** |
| `swift-waiting-list-sql` (`WaitingListSQL`) | Waiting-list persistence and migrations | WaitingList + SQL + Migrations | Server PostgreSQL selected above it | In-process adapter | Current WaitingListLive supplies evidence. | **PROPOSE if core canary passes** |
| `swift-waiting-list-mailgun` (`WaitingListMailgun`) | Waiting-list email delivery/content hooks over Mailgun | WaitingList + Email + Mailgun | Product templates injected from L5 where necessary | In-process adapter | Current WaitingListLive supplies evidence; avoid baking RepoTraffic copy into package. | **PROPOSE if core canary passes** |
| `swift-waiting-list-remote` (`WaitingListRemote`) | Remote HTTP conformance of WaitingList clients | WaitingList + Server HTTP Client | Service host selected by L5 | Optional remote client | Current target is orphaned and its referral endpoints are not fully mounted. | **DEFER until protocol contract is green** |

Logical L4 names are working labels. The empty `/swift-components` reservations do not make these
packages implemented and do not resolve their future repository home.

## L5 RepoTraffic node matrix

These are targets or coherent clusters inside the RepoTraffic application package, not reusable
Institute packages.

| Node | Semantic owner / responsibility | Allowed dependencies and integrations | Deployment posture | Current sources feeding it |
|---|---|---|---|---|
| `RTIdentifiers` | Stable RepoTraffic aggregate identifiers only; no records, DTOs, operations, policy, provider or schema | IdentityCore and lower identifier vocabulary | Narrow package-internal value target | Identifier declarations currently scattered across GitHub connection/Repository/Traffic/Ingestion; package-rent/core-bloat canary required |
| `RTCommercePolicy` | Concrete RepoTraffic catalog, tier, capability and Subscription → Entitlement mapping | Catalog, Pricing, Subscription, Entitlement | Library target | Products, Billing capability projection |
| `RTRepository`, `RTTraffic`, `RTAnalytics` | One bounded product concern each, owning its own values/client contracts rather than importing another domain's operations | RTIdentifiers | Library targets | Repositories, traffic-record and Analytics cores |
| `RTIngestion` | GitHub-ingestion sequencing algorithm plus narrow credential-resolver, repository-provider, traffic-provider/store and analytics-invalidation ports | RTIdentifiers + Scheduler; no concrete GitHub/SQL/cache adapter | Library target | Syncing core and `Syncing+Composable+Live`; adapters import these ports and the root selects conformances |
| `RTAccess` | Access decision/scope only, not returned traffic records; cross-domain fetching occurs in Web/SQL projection | RTIdentifiers + RTCommercePolicy | Library target | AccessControl, narrowed from its current traffic-record projection |
| `RTRepositorySchema`, `RTTrafficSchema`, `RTIngestionSchema` | Domain-owned SQL table vocabulary and migrations, separated so cross-domain projections can name exact schema dependencies | RTIdentifiers + SQL + Migrations | Package-internal schema targets | Current RepoTrafficRecords and domain records. No generic Account schema is proposed: the only Account table is provider-specific. |
| `RTAccountGitHubSchema` | Provider-specific GitHub credential/binding table vocabulary and migration; ciphertext and scopes are not generic Account state | RTIdentifiers + IdentityCore + SQL + Migrations | Package-internal integration schema | Current `Account.GitHub.Record` (`github_accounts`) |
| `RTRepositorySQL`, `RTTrafficSQL`, `RTIngestionSQL` | One domain client/query implementation each | Owning L5 domain + owning schema target + SQL | In-process adapters | Current Lives + RepoTrafficRecords |
| `RTAnalyticsSQL` | Product-specific analytics read projection | RTAnalytics + exact GitHub-account/Repository/Traffic schema targets + SQL | In-process adapter | Analytics queries over traffic and repository membership. It receives an already-authorized neutral scope; it does not import or repeat RTCommercePolicy. |
| `RTAccessSQL` | Access-decision input lookup only; it never returns traffic records | RTAccess + exact GitHub-account binding/Repository membership schema targets + SQL | In-process adapter | Narrowed from AccessControlLive; `repository_subscriptions` is account↔repository membership in RTRepositorySchema, not commerce subscription state |
| `RTAccountGitHub`, `RTRepositoryGitHub`, `RTTrafficGitHub` | Three distinct RepoTraffic × GitHub joins: account connection/provider operations, repository catalog, traffic/stargazer ingestion | The narrow owning identifier/domain contract + GitHub types/client | In-process provider adapters | AccountLive, RepositoriesLive, SyncingLive respectively |
| `RTAccountGitHubSQL` | Persisted GitHub-account connection lifecycle: upsert/read and atomic disconnect cleanup using an injected credential protector | RTAccountGitHub + RTAccountGitHubSchema + RTRepositorySchema + SQL | In-process integration | The `RTRepositorySchema` edge is deliberate: disconnect deletes repository memberships before the GitHub-account binding in one transaction. It must not leak into a fabricated generic Account SQL target or the provider-only adapter. |
| `RTAccountGitHubCrypto` | Concrete credential-protection conformance: AES mapping, ciphertext envelope and key-selection/rotation behavior | RTAccountGitHub protection contract + conditionally approved Crypto mechanism; key/config injected at construction | In-process integration | Current `Account.GitHub.Token+Live`. Root supplies secret material but implements no crypto. RepoTraffic retains compatibility until the Crypto capability disposition is resolved. |
| `RTAccountGitHubCache` | Protected GitHub-token lookup/eviction decorator implementing the RTIngestion credential-resolver port | RTAccountGitHub + RTIngestion + BoundedCache | In-process decorator selected by root | Directly evidenced by SyncingLive decrypted-token caching. Keys, TTL and secret-safe invalidation stay here, never the executable or generic cache. |
| `RTAnalyticsCache` | Conditional analytics materialization read/invalidation decorator implementing the RTIngestion invalidation port | RTAnalytics + RTCommercePolicy + RTIngestion + BoundedCache | Optional in-process decorator selected by root | No current Analytics cache call site exists at the checkpoint. Retain this node only if C2 proves the planned Postgres-materialization read and explicit freshness/load budget; otherwise omit it. |
| `RTJobs` | Retained Scheduler job payloads/bodies/registrations for GitHub polling and repository auto-track | RTIngestion + RTRepository + Scheduler | Web or worker process | `GitHubPollingJob`, `AutoTrackAllReposJob`. `CacheRefreshJob` is a conditional retirement under the fixed Redis/materialization ruling, not silently represented by this node. |
| `RTWeb` | Authenticated routes, handlers, views and product presentation | Product domains/policy + Identity + Checkout/WaitingList interfaces | Web process | Router, UI, app handler/view files |
| `RTMarketingWeb` | Marketing routes, pages, pricing/waitlist presentation | RTCommercePolicy + WaitingList interface | Marketing process | marketing executable source/UI |
| `RTApp` | Authenticated executable composition root | L5 targets plus selected integration/L4 products | Web and optional worker modes | `com_repotraffic_app` boot/configure/migrate |
| `RTMarketing` | Marketing executable composition root | RTMarketingWeb, optional WaitingListRemote, Server, Environment, Logging | Separate web process | `com_repotraffic` boot/configure |

No product node is allowed to be re-exported from an Institute foundation/component. A later SaaS
can replace all `RT*` nodes while reusing the lower graph.

## Graph-wide Apple Foundation boundary

[ARCH-LAYER-007] applies to every proposed main target at L1–L5, not only IdentityContract. A main
target passes only when it has both zero `import Foundation` and zero Foundation-defined types in
its API or internal state. This covers values commonly hidden behind unqualified spelling—`Date`,
`UUID`, `Data`, `URL`, `Decimal`, Foundation coders and similar types. Institute
primitives/standards or target-owned neutral values must carry the semantics instead.

If genuine interoperability remains necessary, [ARCH-LAYER-013] permits only an opt-in leaf named
`<Concern> Foundation Integration`. Its dependency points **leaf → core**; no core/main target may
depend on or re-export the leaf. The proposed graph does not invent speculative Foundation leaves.
Any leaf discovered by F1 must be added as an exact graph node and revalidated before extraction.
RepoTraffic's measured 253 Foundation-importing source files make F1 a blocking migration gate, not
an exception to the architecture.

## Enumerated dependency graph and verification

`proposed-edges.tsv` enumerates every direct edge among the architecture-significant nodes in the
proposed reference graph, including existing anchors, candidate packages/components, integration
packages, and L5 target clusters. It distinguishes L2 provider types from L3 provider clients. It
does not restate the complete transitive closure inside existing lower-layer packages.
The reference counts include conditional `RTAnalyticsCache`; if C2 rejects that node, the TSV and
metrics must be regenerated rather than leaving a speculative target in implementation scope.
Verification on 2026-07-16 produced:

```text
edges=186 nodes=70 cycles=0 longest_edges=6
example_longest_path=RTApp -> RTAccessSQL -> RTAccess -> RTCommercePolicy -> Subscription -> Catalog -> Pricing
l5_nodes=28 l5_intra_edges=66 l5_depth=3
example_l5_longest=RTApp -> RTAccessSQL -> RTAccountGitHubSchema -> RTIdentifiers
no_upward_edges=PASS
```

The topological and depth checks prove acyclicity and the target-level shape; they do **not** by
themselves prove full layer authority. The current classification is:

- upward edges: **0**;
- same-layer edges: **106**;
- of those, 66 are target edges inside the one L5 application package and pass [MOD-007] at exact
  intra-package edge-depth 3;
- two are existing target edges inside `swift-server` (`ServerJobs`/`ServerPostgreSQL -> Server`);
- the remaining **38 are proposed cross-package L3/L4 lateral edges**.

[ARCH-LAYER-001] forbids lateral package dependencies. [MOD-014] requires distinct integration
packages, and the canonical test-layer example describes lateral L3 integration only with an
orchestrator disposition. Therefore the 38 rows in `lateral-edge-asks.tsv` are **OPEN**, not silently
approved. Principal/orchestrator must authorize the exact lateral bridge, or choose re-layering or
merging, before those packages can be created. This includes the three non-integration domain edges
`IdentityContract -> IdentityCore`, `Catalog -> Pricing`, and `Subscription -> Catalog`; their
semantic ordering does not itself override [ARCH-LAYER-001].

No base node depends back on an integration node, no `Live -> Live` edge remains, and the proposed
global maximum path is six edges, down from the measured current eleven. The graph is
**acyclic/no-upward/intra-L5-depth checked, lateral-authority pending**.

The L5 depth result is conditional on `RTIdentifiers` remaining one narrow concern: stable aggregate
identifiers only. It is not a resurrection of a generic Core target and may not absorb shared DTOs,
clients, records, policy, provider types or schema. The IDV1 canary fails closed; if domain
identifiers cannot share that one law, they stay with their domains and the resulting depth/placement
returns for Principal disposition rather than padding a grab-bag to satisfy the metric.

Reproduction:

```sh
cd /Users/coen/Developer/swift-institute/Research/SaaS-Vertical-Substrate
tail -n +2 proposed-edges.tsv | cut -f1,2 | tsort >/dev/null
awk -F '\t' 'NR==1{next} {
  a=$3; b=$4; sub(/^L/,"",a); sub(/^L/,"",b)
  if (a+0 < b+0) {print "UPWARD", NR, $0; bad=1}
} END{if (!bad) print "no_upward_edges=PASS"}' proposed-edges.tsv
awk -F '\t' 'NR>1 && $3==$4 {count++} END{print "same_layer_edges=" count+0}' proposed-edges.tsv
```

The longest-path diagnostic used the same TSV and a memoized traversal after the topological check.
It is a review aid, not a new maximum-depth rule.

## Thin-application budget

“Thin” is a responsibility budget, not an arbitrary line-count target. A large generated router or
explicit dependency registration can be honest composition; a ten-line business rule in the root
is still misplaced.

### What an L5 SaaS may own

1. Product identity: brand, copy, assets, URLs, navigation, routes and views.
2. Commercial policy: concrete catalog entries, tier names, prices selected for the product,
   capability enums, promotions, entitlement mapping and support policy.
3. Product domains: RepoTraffic repository selection, GitHub ingestion, traffic retention,
   analytics definitions, onboarding, admin and support workflows.
4. Product-specific provider joins, such as RepoTraffic Account/Repository/Traffic × GitHub, where
   the join itself encodes product behavior rather than a reusable provider conformance.
5. Deployment composition: environment decoding, secret lookup, selected adapters, server/worker
   mode, route mounting, lifecycle, health/readiness and migration ordering.

### What must not remain in an executable root

- Reusable domain models or client witnesses.
- SQL statements, table/record declarations, migrations themselves, or provider request/response
  mapping.
- Product decision logic, route handlers, rendered feature pages, job bodies, retry algorithms, or
  cache algorithms.
- Stripe/GitHub/Mailgun wire types except values passed directly into a selected integration
  constructor; the root must not become the adapter.
- A cross-domain integration that other code imports from the executable.

### Executable-root structural gates

For both `RTApp` and `RTMarketing`:

| Gate | Budget |
|---|---|
| Executable products | Exactly the intended executable roots; no reusable library product vended by a root |
| Root file categories | Entry point, environment-to-configuration mapping, adapter construction/registration, route/lifecycle mounting, migration aggregation, health/deploy commands only |
| Business/storage/provider declarations | Zero domain invariants, SQL/table declarations, provider payload mappers, feature views, and job bodies |
| Apple Foundation | Zero `import Foundation` and zero Foundation-defined type use in every main target; opt-in leaf integrations only, with leaf → core direction |
| Engine leakage | Import logical Server/L4 adapters, not Vapor, Queues, PostgresNIO, Redis, or transport engines directly |
| Provider leakage | Neutral domains import zero Stripe/GitHub/Mailgun modules; only dedicated integration targets do |
| Cross-domain joins | Dedicated integration target or root-only composition; never hidden in a base domain target |
| New file review | Every root file maps to one allowed category; otherwise extraction or an explicit Principal exception is required |

### Product-policy non-leakage examples

- `weekly`, `daily`, `hourly`, “analytics pack,” and GitHub traffic freshness are RepoTraffic policy,
  not Catalog/Pricing/Subscription/Entitlement API cases.
- `repotraffic:` cache prefixes and tier-derived TTLs stay L5.
- Analytics and protected GitHub-token caching live in narrow L5 decorators; the executable only
  constructs the selected BoundedCache and decorator chain.
- Stripe IDs may exist only in SubscriptionStripeSQL provider-binding storage, not
  `Subscription.State`, SubscriptionSQL or `Checkout.Session`; neutral subject/catalog IDs stay in
  Subscription while RepoTraffic tier/addon/SKU mapping stays in RTCommercePolicy.
- GitHub scopes, polling cadence and repository rules stay in the three product-specific GitHub
  integrations and `RTIngestion`.
- Mail subject/body/branding can be injected into reusable identity/waitlist delivery hooks; the
  reusable packages must not name RepoTraffic.

## Golden-path reference composition

### Build-time composition

1. Select active package products, not source-only/disabled/reserved names.
2. Pass F1 for every main target; select a named Foundation Integration leaf only when genuine
   interop cannot be expressed with Institute primitives/standards.
3. Define product domains and policy only in L5 targets.
4. Depend on neutral L3 domains from L5 policy; depend on provider/SQL integrations only from L5
   adapter targets and roots.
5. Register every domain's migrations with the L5 migration aggregator.
6. Register identity, subscription, delivery, jobs, email and provider conformances in the root.
7. Mount product routes/views in Web targets; roots mount the resulting router into Server.

### Runtime paths

**Authenticated request**

```text
Server request -> RTWeb route -> IdentityComponent -> Identity context -> RTAccess decision
  -> RTRepository/RTTraffic/RTAnalytics client -> domain SQL adapter -> SQL -> Server PostgreSQL
```

`RTAccessSQL` may load only the GitHub-account binding/Repository membership inputs required for the decision.
Traffic rows are fetched after an allow decision through `RTTrafficSQL` or `RTAnalyticsSQL`; putting
them back in the access result fails the access-seam canary.

**GitHub account connection lifecycle**

```text
RTWeb -> RTAccountGitHub contract
  connect/read/list -> root-selected RTAccountGitHub provider + RTAccountGitHubCrypto protector
    + RTAccountGitHubSQL -> RTAccountGitHubSchema -> SQL
  post-commit onboarding -> RTRepository membership operation + RTIngestion trigger
  disconnect -> RTAccountGitHubSQL -> one SQL transaction
    (RTRepositorySchema membership delete, then RTAccountGitHubSchema binding delete)
```

Token validation occurs through the provider integration. The root injects secret/key configuration
into RTAccountGitHubCrypto but implements no cryptographic mapping; only protected token material
reaches the provider-specific schema. Post-connect repository subscription and ingestion are
explicit L5 Web workflow edges, not hidden root or Live→Live behavior. Disconnect is intentionally
a dedicated cross-schema operation because the foreign-key cleanup and account binding deletion
must remain atomic.

**Checkout and subscription update**

```text
RTWeb -> Checkout intent -> CheckoutStripe -> external Stripe
Stripe webhook -> MessageDeliveryStripe -> MessageDelivery receipt
  -> SubscriptionStripeDelivery -> provider-neutral transition command
  -> SubscriptionStripeDeliverySQL opens one SQL transaction:
       MessageDeliverySQL receipt claim
       SubscriptionSQL neutral subject/catalog/state mutation
       SubscriptionStripeSQL customer/subscription/schedule binding mutation
  -> commit -> RTCommercePolicy entitlement projection
```

The provider-binding table is keyed to neutral Subscription identity. Expand/backfill/contract must
preserve all three Stripe IDs, uniqueness and lookup behavior while removing Identity.ID and
RepoTraffic tier/addon/SKU types from the neutral schema. Receipt, neutral state and binding mutation
share one database transaction; a future outbox relay publishes only after commit.

**Scheduled ingestion**

```text
Scheduler registry -> Server Jobs -> RTJobs -> RTIngestion algorithm and abstract ports
root-selected port conformances:
  credential resolver -> RTAccountGitHubCache -> RTAccountGitHubSQL/RTAccountGitHubCrypto
  repository/traffic provider -> RTRepositoryGitHub / RTTrafficGitHub -> external GitHub
  selection/store -> RTIngestionSQL / RTTrafficSQL
  analytics invalidation -> conditional RTAnalyticsCache (or no-op when C2 rejects it)
Scheduler registry -> Server Jobs -> RTJobs -> RTRepository bulk-membership operation
```

The sequencing algorithm lives in RTIngestion; concrete adapter targets depend inward on its ports,
and the root only selects conformances. No `RTIngestion -> concrete adapter` target edge or direct
`RTTrafficSQL -> RTAnalyticsCache` edge is claimed. The same registry can run in-process or in a
separately deployed worker without changing the job domain API. `CacheRefreshJob` is not carried
into `RTJobs`: at the pinned checkpoint its actual
refresh/aggregation call is disabled and it only scans cross-domain tables, evaluates tier policy,
updates refresh-marker columns and logs. Its removal is conditional on J0 proving those markers and
scheduled effects are unconsumed. If J0 fails, the target graph must gain a deliberately named
materialization policy and SQL projection before that job can move; raw SQL cannot remain in
`RTJobs` or the root.

**Marketing waitlist**

```text
RTMarketingWeb -> WaitingList client
  embedded: root selects WaitingListSQL + WaitingListMailgun
  remote: root selects WaitingListRemote against the authenticated app host
```

Remote mode is optional and must pass the protocol canary; it does not imply a standalone
waiting-list microservice.

## Contracts, CI, downstream proof, and release certification

Each reusable base package owns deterministic contract tests for its laws. Each integration package
runs the same contracts against its conformance plus provider-specific error mapping tests:

- Foundation boundary: every main target has zero Foundation import/type reference; every opt-in
  Foundation Integration leaf has leaf → core direction and no re-export.
- Identity: embedded and remote consumer parity, token/session invalidation, redirects and mail
  hooks.
- Catalog/Pricing: stable identifiers, currency/amount round trips, provider mapping, unknown SKU.
- Subscription: state-transition table, scheduled change, cancellation/reactivation, provider event
  reordering, neutral subject/catalog IDs, exact Stripe-binding migration and lookup parity.
- Entitlement: grant/deny/expiry/override decisions with product capability types supplied by tests.
- Message Delivery: duplicate, replay, stale, concurrent claim, retryable/permanent failure,
  transaction rollback and optional outbox publication.
- GitHub credential/ingestion: ciphertext compatibility/rotation/failure safety and port-conformance
  parity for provider calls, writes and invalidation order.
- Scheduler/Jobs: retained-job registry parity, payload encoding, in-process/worker driver contract,
  retry/cancel; separate proof for the CacheRefresh retirement or replacement.
- Waiting List/Checkout canaries: embedded/remote or fake/Stripe conformance parity before promotion.

Shared CI should run, in dependency order:

1. manifest resolution, exact-import/dependency validation and graph-wide Foundation import/type
   audit;
2. layer and cycle validation over the package graph;
3. package build and test on the supported toolchain/platform matrix;
4. integration contract suites with deterministic local fakes, then explicitly credentialed provider
   probes outside ordinary PR CI;
5. downstream builds/tests for RepoTraffic and a minimal reference SaaS fixture at exact commits;
6. public-API/source-compatibility review and migration-note validation before release.

Release certification is a recorded tuple: source commit, dependency commits/versions, toolchain,
platforms, package-local test result, integration-contract result, graph/import audit, RepoTraffic
downstream result, reference-fixture result, known limitations, rollback/migration notes, and
Principal release disposition. A green package in isolation is insufficient.

## Outcome

**Status**: RECOMMENDATION — pending Principal adjudication.

This graph supplies a reusable SaaS route without a mega-framework. Small domain seams, dedicated
provider/persistence/delivery integrations, and up to two canary-gated L4 components keep providers
out of neutral APIs. Existing identity, jobs, email, SQL, server, provider, cache, environment and
logging capabilities are reused. RepoTraffic remains the owner of all product policy and GitHub
analytics behavior. Package creation remains blocked on the explicit lateral-layer dispositions.

## References

- [Provenance and architecture](provenance-and-architecture.md)
- [Capability atlas and target matrix](capability-atlas-and-current-to-target-matrix.md)
- [Proposed edges](proposed-edges.tsv)
- [Lateral-edge asks](lateral-edge-asks.tsv)
- [Service-rent decisions](service-rent-decisions.md)
- [Extraction and canary plan](extraction-and-canary-plan.md)
- [Independent review record](independent-review-record.md)
