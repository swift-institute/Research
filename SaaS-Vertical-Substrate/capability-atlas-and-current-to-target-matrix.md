# SaaS Vertical Substrate — Capability Atlas and Current-to-Target Matrix

<!--
---
version: 0.1.0
last_updated: 2026-07-16
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
changelog:
  - 0.1.0 (2026-07-16): Initial capability atlas and complete 31-target RepoTraffic disposition.
---
-->

## Context

RepoTraffic's 29 library targets are useful evidence, but they are not presumed package or domain
boundaries. This artifact first classifies capabilities by semantic role, then gives every current
non-test target exactly one explicit disposition. `RETAIN`, `SPLIT`, `MERGE`, `DISSOLVE`, and
`DEFER` describe target-to-target architecture outcomes; none authorize implementation.

## Question

Which SaaS capabilities are present, absent, mixed, or already reusable, and where should each
material RepoTraffic target land in a package-first architecture?

## Analysis

The analysis classifies semantic roles first, then applies one explicit destination to every pinned
non-test target and tests the mixed seams for honest package rent.

## Classification vocabulary

| Class | Meaning |
|---|---|
| `mechanism/invariant` | Flexible law or protocol independent of one product/provider; candidate L3 |
| `component` | Opinionated reusable assembly with defaults; candidate L4 |
| `provider integration` | Dedicated join between a domain/component and Stripe, Mailgun, GitHub, SQL, etc. |
| `product policy` | RepoTraffic-specific commercial or behavioral choice; L5 only |
| `presentation` | Product routes, views, copy, branding, or assets; L5 unless a separate theory is proved |
| `deployment composition` | Executable boot, environment, lifecycle, migration registry, and adapter selection; L5 root |

Every proposed main target in every class is subject to F1: zero Apple Foundation imports and zero
Foundation-defined API/state. Genuine interop may exist only in a separately named opt-in
Foundation Integration leaf whose dependency points toward the main target.

## Capability atlas

| Capability | Current evidence | Classification | Proposed reusable disposition | L5 residue / explicit absence |
|---|---|---|---|---|
| Identity identifiers | `swift-identities`; Identity IDs also flow through RepoTraffic Account/Billing records | mechanism/invariant | Directly reuse `swift-identities` | Product account ID and GitHub account binding remain RepoTraffic |
| Accounts | `Account` is a composition wrapper around `Account.GitHub`; its other files are routes/views/cache keys, and the only Account table is `github_accounts` | provider-specific connection + presentation, not an independent account domain | Do not create a generic SaaS-account package or generic RTAccount/RTAccountSQL target from this evidence | Dissolve the wrapper: GitHub connection/provider/schema/SQL get explicit L5 seams; routes/views move to Web; generic Identity remains external |
| Organizations | No organization model, invariant, membership graph, or source target found | absent | Defer; do not fabricate a package | A later product must provide ownership/lifecycle evidence |
| Tenancy | No tenant boundary, tenant-scoped storage rule, or tenant routing evidence found | absent | Defer | Current identity/account relationship is not silently renamed tenancy |
| Membership | No membership role/state lifecycle found | absent | Defer | Product access decisions are subscription/repository-specific |
| Authentication | `swift-authentication` vends Shared, Backend, Provider, Views, Consumer, Frontend; app assembles Backend/Provider. Identity Shared still imports ServerFoundation/Vapor, so it is not a clean L3 contract | mixed mechanism/invariant + logical L4 component surfaces | Directly reuse current products, but make the provider-neutral L3 contract an explicit identity-architecture seam; restore Standalone only through its conversion ruling | Root selects embedded vs remote mode and product redirects |
| Sessions | Tokens/session versions in Identity Backend; app performs raw-SQL invalidation workaround | mechanism/invariant + persistence integration | Keep session law in identity packages; remove app workaround when public identity API exists | Cookie settings and origin policy remain deployment configuration |
| Authorization | `AccessControl` currently combines an access decision with fetching RepoTraffic traffic records | mixed product policy + cross-domain projection | No generic authorization package from this target; narrow the retained policy to decision/scope and move record fetching to an explicit L5 projection | A future general policy algebra needs independent evidence |
| Audit | Stripe event receipts and structured logs exist; no durable cross-domain audit model | mixed delivery mechanism + operational record | Durable delivery receipts belong to message delivery; generic audit package deferred | Product/support audit semantics are absent, not inferred |
| Product catalog | `Products` has catalog, plan, SKU plus RepoTraffic tiers/capabilities | mixed mechanism + product policy | Extract neutral catalog invariants to candidate L3 `swift-catalog` | RepoTraffic catalog contents, tier names, GitHub freshness and analytics packs stay L5 |
| Pricing | `Pricing` is small but directly aliases Stripe currency and depends on Products | mixed mechanism + provider leakage | Candidate L3 `swift-pricing`; first resolve money/currency representation | Display copy, price selection, promotions, and launch pricing stay L5 |
| Checkout | `Checkout`/`CheckoutLive` mix intent, routes/views, Stripe session IDs, analytics and billing | mixed component + provider + presentation | Candidate L4 `swift-checkout` only after neutral intent/result canary; Stripe join separate | Success/cancel pages and product conversion analytics stay L5 |
| Billing | `Billing` names payment, pricing, subscription and Stripe in one target | mixed umbrella | Do not create an umbrella `swift-billing`; decompose by catalog, subscription, checkout, delivery | Finance/support workflows and product-specific decisions stay L5 |
| Subscriptions | Provider-neutral state/change operations coexist with Identity.ID, RepoTraffic tier/addon/SKU types, three Stripe IDs, Records and routes | mechanism/invariant + product/provider/persistence joins | Candidate L3 `swift-subscription` with neutral subject/catalog identifiers; neutral SQL, Stripe binding SQL, provider and atomic delivery/SQL joins are distinct | Identity-to-subject and RepoTraffic tier/addon/SKU/entitlement mapping stay in RTCommercePolicy |
| Entitlements | Product capability enums and subscription-derived flags appear in Products, Billing and AccessControl | mixed invariant + product policy | Candidate generic L3 `swift-entitlement` parameterized over product capability; canary required | Actual capabilities and rules remain RepoTraffic types and policy |
| Webhooks | Stripe route, signature validation, durable receipt and subscription state update live across app/BillingLive | several provider integrations + presentation boundary | Split MessageDelivery × Stripe, Subscription × Stripe, and the durable three-way subscription handler; route mounting stays L5 | Endpoint path, secrets and deployment exposure remain root configuration |
| Events | `Stripe.Event.Record` persists receipt/status/provider payload; no generic event package | mechanism hidden inside provider target | Candidate L3 `swift-message-delivery` for envelope/receipt/handler semantics | Domain events are defined by their owning domains, not a central event grab-bag |
| Outbox | No generic producer outbox or relay found | absent but adjacent to delivery | Include outbox only if the delivery canary proves transactional publication semantics | Do not claim exactly-once delivery; no broker is selected |
| Idempotency | Stripe receipt uniqueness/state transitions and webhook replay handling are concrete evidence | mechanism/invariant | Move generic key/receipt/state-machine semantics to message delivery | Provider event decoding remains Stripe-specific |
| Jobs | Three product jobs exist; GitHub polling and repository auto-track have real domain effects, while `CacheRefreshJob` has its refresh call disabled and only scans policy/schema state, updates refresh markers and logs | reusable mechanism already exists + two retained L5 jobs + one conditional retirement | Directly reuse Scheduler + Server Jobs; retain polling/auto-track in RTJobs. Retire CacheRefresh only after J0, or replace it with an explicitly named materialization policy/SQL projection if its marker effects remain required | Job bodies, payload choices and cadence policy stay RepoTraffic; no new `swift-jobs` package |
| Scheduling | `Syncing.Schedule` and product frequencies coexist with Scheduler capability | mixed reusable mechanism + product policy | Reuse Scheduler schedule/registry/driver APIs | Sync priority, GitHub rate-limit policy and freshness tiers stay L5 |
| Retries | Job engine/provider clients and delivery states have separate retry behavior | cross-cutting but owner-specific | Retry policy stays with Scheduler, message delivery, or provider adapter that owns the failure | No universal retry package; product escalation thresholds stay L5 |
| Notifications | Email is the only demonstrated channel; Identity and WaitingList send through Mailgun | mechanism + provider integrations | Reuse `swift-emailaddress`, `swift-email`, `swift-mailgun`, and `swift-identities-mailgun`; no generic notification domain | Product copy/templates and recipient policy stay Identity/WaitingList/L5 |
| Records/storage | Account/Billing/Syncing interfaces and `RepoTrafficRecords` import Records; Lives use PostgreSQL | mixed domain schema + engine | Follow ratified SQL/Migrations direction; narrow domain schema targets expose exact tables to domain and cross-domain query integrations | Root composes the database and migration registry; `repository_subscriptions` is repository membership, not commerce subscription state |
| Migrations | App root owns a global migrator; identity and product schemas contribute registrations | deployment composition over reusable mechanism | Reuse Migrations; integration packages vend migrations with their schema | Root orders and runs selected migrations |
| Cache | `Cache.Store` mechanics mix with `repotraffic:` keys/tier TTLs and Redis/Memory/Hybrid lives; only SyncingLive's protected-token path has a checkpoint cache read/write call site | mixed mechanism + product policy + provider | Reuse existing bounded in-process cache where semantics match; retain `RTAccountGitHubCache`; make `RTAnalyticsCache` conditional on C2 proving the planned materialization read | RepoTraffic keys, freshness/TTL, token eviction and invalidation stay in the evidenced/approved L5 decorator; Redis is removed per fixed ruling and roots own no cache algorithm |
| Configuration | EnvVars and EnvironmentVariables live in app; `swift-environment`/Server exist | mechanism already exists + composition | Reuse Environment/Server configuration; typed domain config lives with each package | Required values, defaults, URLs and mode selection remain root-owned |
| Secrets | Environment supplies Stripe, GitHub, identity, database and Mailgun secrets; current GitHub-token AES-GCM adapter directly imports Apple Crypto | deployment composition + product credential-protection integration | No secrets service. Add `RTAccountGitHubCrypto` behind a protection contract; root injects key configuration only. Institute crypto is an unimplemented reservation, so bounded external use vs capability implementation needs disposition | Acquisition, key shape/rotation and backward-read policy remain explicit operational/integration policy; plaintext never enters storage/log APIs |
| Flags | No feature-flag model, evaluation engine or call-site census found | absent | Defer | Boolean environment switches are not enough evidence for a flag platform |
| Logging | 31 source files import Logging; 294 logger calls | observability mechanism already present | Reuse swift-log/LoggingExtras; define package-owned structured fields at boundaries | Logger construction, level and exporter selection stay root-owned |
| Metrics | Zero `Metrics` imports; positive control found 253 Foundation imports | absent instrumentation | Add only through measured canaries; use existing metrics ecosystem if selected | No Institute metrics service is justified |
| Tracing | Zero Tracing/Instrumentation imports; tracing dependencies only occur transitively | absent instrumentation | Add context propagation at HTTP/job/delivery boundaries only after experiment | No tracing backend or service is selected |
| Operations | Server lifecycle, database, cache and jobs are built in `Application.swift`; deploy surface exists | deployment composition | Reuse Server chassis and package health contracts | Readiness, migrations, worker mode, deploy and rollback remain L5 operational composition |
| Admin/support | WaitingList admin routes and billing portal/cancel flows exist; no general admin domain | product policy + presentation | Do not create an admin/support framework | Keep support authorization, screens and actions in L5/product components |
| UI/application shell | `RepoTrafficUI`, app view files, marketing target, identity views and HTML stack | mixed presentation | Reuse identity/HTML primitives; no generic SaaS shell package | Branding, navigation, dashboards, pricing pages and copy stay L5 |
| GitHub connection | Account target imports GitHub client/types; AccountLive validates tokens, performs Apple-Crypto AES-GCM protection, stores `github_accounts`, and atomically deletes repository memberships on disconnect | product-specific provider + credential protection + persistence + cross-schema integration | Split provider-only `RTAccountGitHub`, `RTAccountGitHubCrypto`, provider-specific schema, and `RTAccountGitHubSQL`; the SQL integration names RTRepositorySchema for atomic cleanup | OAuth scopes, key/rotation policy, repository selection, onboarding and account setup remain product policy; Crypto mechanism disposition is open |
| GitHub ingestion | `Syncing`, `SyncingLive`, three jobs, traffic/stargazer clients and records | product-specific integration + policy | Retain as RepoTraffic ingestion domain; reuse Scheduler and GitHub clients | Poll cadence, priority, freshness and error policy stay L5 |
| Repository analytics | Analytics/Live, RepoTrafficRecords, cache and app views | product domain + persistence + presentation | Retain product analytics domain; split SQL and views | Metric definitions, ranges, chart behavior and paid access remain RepoTraffic |
| Growth | Growth/Live orchestrate Account, Billing, Products, Repositories and records | product workflow | Merge into owning L5 workflows unless an independent state machine is proved | Never export generic “growth” infrastructure |
| Waiting list | WaitingList has entry/referral/admin/routes; Live and Remote add SQL/Mailgun/HTTP | reusable opinionated component + integrations | Candidate L4 `swift-waiting-list`; separate SQL/Mailgun/remote joins after seam canary | Product copy, page design, launch rules and service deployment choice remain L5 |

## Complete current-to-target disposition

The table has one row for every current non-test target in `dump-package` (31/31).

| # | Current target | Current semantic mix | Disposition | Proposed home and boundary |
|---:|---|---|---|---|
| 1 | `com_repotraffic_app` | deployment composition + views + jobs + identity/Stripe/Mailgun/DB/cache wiring | **SPLIT, RETAIN root** | Keep one thin authenticated executable root. Move feature handlers/views/job bodies into L5 feature targets; select reusable integrations here. |
| 2 | `com_repotraffic` | marketing deployment + presentation + catalog/waitlist composition | **SPLIT, RETAIN root** | Keep one thin marketing executable root. Marketing copy/views remain L5; import only the product policy and component clients it uses. |
| 3 | `RepoTrafficRouter` | product route tree + URL generation + HTML/Favicon + Stripe types | **SPLIT** | Keep a types/URLRouting-only L5 route tree; move response rendering to Web and Stripe knowledge to commerce integration. |
| 4 | `RepoTrafficRouterLive` | concrete route construction | **MERGE** | Construct/register routers in executable composition roots; no independently reusable live package. |
| 5 | `RepoTrafficUI` | RepoTraffic views/assets plus generic-looking controls over HTML/SVG/Server | **SPLIT, RETAIN product UI** | Keep product shell and controls in L5 Web. Reuse existing HTML/SVG/Favicon packages; extract nothing without a separate UI theory. |
| 6 | `Products` | catalog/plan/SKU invariants + RepoTraffic tiers/capabilities | **SPLIT** | Neutral catalog to candidate `swift-catalog`; pricing/entitlement concepts to their owners; concrete RepoTraffic catalog and capabilities to L5 Commerce Policy. |
| 7 | `ProductsLive` | static defaults coupled to Billing | **MERGE** | Static product configuration belongs in L5 Commerce Policy/root configuration; no “Live” service for constants. |
| 8 | `Pricing` | price/client shape + direct Stripe currency coupling + Products dependency | **SPLIT** | Neutral money/price/cadence to candidate `swift-pricing`; Stripe mapping to Catalog × Stripe integration; product display rules to L5. |
| 9 | `PricingLive` | Stripe product/price lookup and product configuration | **SPLIT** | Provider mapping to candidate `swift-catalog-stripe`; deployment credentials and selected catalog to L5 root. |
| 10 | `Billing` | subscription lifecycle + Identity/product/Stripe identifiers + Records + server routes + product capability derivation | **SPLIT, DISSOLVE umbrella** | Neutral Subscription subject/catalog/state to `swift-subscription`; Identity/tier/addon/SKU mapping to RTCommercePolicy; provider, binding SQL, neutral SQL, delivery, and route joins separate. No generic Billing umbrella. |
| 11 | `BillingLive` | Stripe clients/webhooks + mixed neutral/provider persistence + routes + repository/router joins | **SPLIT** | Subscription × Stripe, MessageDelivery × Stripe, pure delivery mapping, neutral SubscriptionSQL, SubscriptionStripeSQL binding, MessageDeliverySQL and atomic SubscriptionStripeDeliverySQL; no monolithic Live target. |
| 12 | `Checkout` | checkout request/session plus routes/views and Stripe ID leakage | **SPLIT, CANARY** | Candidate L4 Checkout owns provider-neutral intent/result only if experiment succeeds; all pages/routes remain L5. |
| 13 | `CheckoutLive` | Stripe session creation + Billing/Analytics/Records/Router composition | **SPLIT** | Checkout × Stripe adapter plus L5 conversion telemetry and route composition. Base Checkout must not import Stripe. |
| 14 | `AccessControl` | account/tier/repository decision fused with traffic-record output | **SPLIT, RETAIN POLICY** | L5 `RepoTraffic.Access` owns decision/scope only; product policy, not generic authorization. Traffic results move to the explicit projection/Web path. |
| 15 | `AccessControlLive` | cross-domain decision-input lookup fused with traffic retrieval | **SPLIT** | L5 Access × SQL loads only GitHub-account binding/Repository membership inputs. After allow, Web calls Traffic/Analytics SQL paths; Access returns no traffic records and has no TrafficSchema edge. |
| 16 | `Account` | composition wrapper around Account.GitHub plus account-facing routes/views/cache keys; no independent non-GitHub account invariant or table | **DISSOLVE/SPLIT** | GitHub contract/provider work to RTAccountGitHub; account-facing routes/views to RTWeb; cache keys to the owning decorator. Do not fabricate RTAccount, RTAccountSchema or RTAccountSQL. Generic Identity remains external and lower. |
| 17 | `AccountLive` | GitHub validation/AES-GCM token protection/credential SQL + account overview projection + cross-schema disconnect + live composition | **SPLIT** | Provider-only Account × GitHub; `RTAccountGitHubCrypto`; provider-specific GitHub-account schema/SQL with an explicit RepositorySchema cleanup edge; overview projection/presentation in Analytics/Web; onboarding in the L5 Web workflow; root wiring only. |
| 18 | `Analytics` | traffic analytics + cache/records/repositories + UI/server concerns | **SPLIT, RETAIN domain** | L5 RepoTraffic Analytics owns query/aggregation semantics; SQL/cache and views are separate adapters/presentation. |
| 19 | `AnalyticsLive` | concrete analytics queries over account/repository records; no checkpoint cache read/write call site | **SPLIT** | L5 Analytics × SQL. `RTAnalyticsCache` is conditional on C2 proving a planned Postgres-materialization read plus freshness/load budget; omit it otherwise. |
| 20 | `Repositories` | tracked-repository product domain | **RETAIN** | L5 RepoTraffic Repository domain with minimal IDs/state/client contracts. |
| 21 | `RepositoriesLive` | persistence + GitHub + SyncingLive bridge | **SPLIT** | Repository schema/SQL and Repository × GitHub catalog integration; compose synchronization in root, not Live→Live. |
| 22 | `RepoTrafficRecords` | shared records grab-bag importing Account, Repositories and Cache | **DISSOLVE** | Narrow provider-specific GitHub-account plus Repository/Traffic/Ingestion schema targets own tables/migrations; domain and cross-domain SQL adapters name exact schema edges. Root aggregates migrations; no horizontal records home. |
| 23 | `Syncing` | product ingestion policy + schedule + GitHub traffic/stargazers + Records/cache | **SPLIT, RETAIN domain** | L5 RepoTraffic Ingestion owns prioritization/state; reuse Scheduler; GitHub and SQL joins separate. |
| 24 | `SyncingLive` | ingestion sequencing + provider/persistence/cache implementations + AccountLive/CacheLive bridges | **SPLIT** | Sequencing and abstract ports to RTIngestion; provider/store/credential-cache/invalidation conformances in dedicated targets; Server Jobs registration and root selection only. |
| 25 | `Growth` | cross-domain signup/activation/commercial workflow | **MERGE by owner** | Keep behavior in the L5 account/onboarding/marketing workflows that own it; retain a target only if a distinct state machine is proved. |
| 26 | `GrowthLive` | persistence-backed cross-domain workflow | **MERGE/SPLIT by owner** | Put queries in the relevant L5 SQL integration and orchestration in Web/root; no reusable “Growth Live.” |
| 27 | `Cache` | key/value store mechanics + `repotraffic:` namespace + tier TTL/product policy | **SPLIT, DEFER generic extraction** | Evidenced protected-token keys/TTL/eviction move into `RTAccountGitHubCache`; `RTAnalyticsCache` exists only if C2 proves a materialization call site. Reuse bounded cache when compatible; resolve duplicate ownership first. |
| 28 | `CacheLive` | memory/noop/hybrid/Redis implementations | **RETIRE for RepoTraffic** | Apply fixed Phase-2 Redis drop: Postgres materialization + bounded in-process cache selected by the root and wrapped only by the narrow L5 decorators. A future Redis component needs independent justification. |
| 29 | `WaitingList` | entry/referral/admin domain + API/routes | **SPLIT, CANARY** | Candidate L4 Waiting List core; product pages/copy remain L5; keep core transport- and provider-neutral. |
| 30 | `WaitingListLive` | SQL/Mailgun/router concrete behavior | **SPLIT** | Waiting List × SQL and Waiting List × Mailgun integrations plus L5 route mounting. |
| 31 | `WaitingListRemote` | HTTP client and environment wiring; currently not imported by source targets | **DEFER/OPTIONAL** | Candidate remote integration only if a separate waiting-list deployment is chosen. Current incomplete referral mount and orphan status block default inclusion. |

## Mixed-target seam findings

The target matrix is intentionally stricter than an interface/Live rename:

1. **`Billing` is not one domain.** It contains catalog/pricing references, provider-neutral
   subscription behavior, Stripe provider handling, persistence, route transport, durable delivery,
   and RepoTraffic capability policy. Renaming it cannot repair the boundary.
2. **`RepoTrafficRecords` is horizontal coupling.** Records should follow the domain schema and its
   persistence integration; a shared records target causes unrelated domains to import one another.
3. **`Live` is not a semantic owner.** Current Lives combine provider, database, cache, route, and
   cross-domain integrations. Each join needs its own package/target; roots select them.
4. **`AccessControl` contains honest product policy but is still mixed.** Its decision uses
   repository/tier concepts, while its output fetches traffic records. Retain the decision at L5 and
   move the multi-schema projection; generalizing the name would hide rather than remove policy.
5. **Identity is reused but incompletely productized.** The app constructs the embedded witness from
   public subclients because Standalone is disabled, and it duplicates Identity × Mailgun behavior
   despite an existing integration package. These are extraction/upstream gates, not evidence that
   Identity must be a service.
6. **Cache is both semantically and physically unsettled.** RepoTraffic policy is separable, but the
   ecosystem already has overlapping cache repositories plus empty L4 reservations. Direct reuse and
   ownership resolution precede invention.

## Outcome

**Status**: RECOMMENDATION — pending Principal adjudication.

The reusable vertical is a capability graph. It does not include organizations, tenancy,
membership, general authorization, audit, feature flags, multi-channel notifications, or an
observability service merely because those are common SaaS words; current evidence is absent or
product-specific. The graph does include strong seams for catalog, pricing, subscriptions,
entitlements, and durable message delivery, subject to the canaries in the extraction plan.

All 31 current RepoTraffic source targets have an explicit disposition. The proposed package and
edge details are in `dependency-layer-and-golden-path.md`.

## References

- [Provenance and architecture](provenance-and-architecture.md)
- [Dependency, layer, and golden path](dependency-layer-and-golden-path.md)
- [Service-rent decisions](service-rent-decisions.md)
- [Extraction and canary plan](extraction-and-canary-plan.md)
- [Independent review record](independent-review-record.md)
- [RepoTraffic Package.swift](/Users/coen/Developer/repotraffic/repotraffic-com-server/Package.swift)
- [RepoTraffic Sources](/Users/coen/Developer/repotraffic/repotraffic-com-server/Sources/)
