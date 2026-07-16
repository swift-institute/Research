# SaaS Vertical Substrate — Extraction and Canary Plan

<!--
---
version: 0.1.0
last_updated: 2026-07-16
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
changelog:
  - 0.1.0 (2026-07-16): Initial dependency-ordered extraction waves, compatibility controls, canaries, and Principal gates.
---
-->

## Context

The architecture artifacts prescribe seams but authorize no implementation. This plan orders future
work so each step is bounded, reversible, independently gated, and proven against RepoTraffic. It
also states where the SaaS-vertical proposal intentionally diverges from the launch assessment's
target-preserving end state.

## Question

How can the package graph be validated and extracted without a flag-day rewrite, silent public API
break, schema fork, deployable-service presumption, or loss of the currently green RepoTraffic
baseline?

## Analysis

The analysis reconciles the accepted launch checkpoint with the proposed semantic graph, then orders
reversible waves and fail-closed canaries around every unresolved seam.

## Reconciliation with the RepoTraffic launch assessment

The launch assessment at `0a24898` is accepted as primary evidence for current source, build, test,
manifest and deploy state. Its local decomposition proposal is not silently treated as a ratified
ecosystem architecture. Four differences require Principal judgment:

| Topic | Launch assessment proposal | SaaS-vertical proposal | Reason for challenge |
|---|---|---|---|
| Root engine imports | Keep roots importing Vapor-family engines (`Assessment/...md:160,176`) | Roots import logical L4 Server/adapters; engines remain quarantined | Ratified server-stack architecture makes `swift-server` the L4 engine boundary; direct engine retention would preserve the leakage the membrane exists to remove |
| Interface/Live pairs | Keep all 12 `XLive -> X` pairs (`:142-144,161`) | Split mixed Lives by semantic join: domain × SQL, domain × provider, component × provider; root composes | “Live” is implementation posture, not one coherent concern; current Lives combine unrelated providers, storage, routing and domains |
| Records home | Make `RepoTrafficRecords` the only records module (`:148-150`) | Dissolve the horizontal records grab-bag; narrow domain schema targets own tables/migrations and SQL adapters own queries | Current records target imports Account, Repositories and Cache, producing lateral coupling. Schema changes follow their semantic domain, while the root only aggregates migrations |
| WaitingListRemote | Keep as remote client (`:178`) | Optional/deferred until contract canary | It is not imported by a source target and its referral routes are not fully mounted; current existence is evidence for a seam, not a green default |

The proposals agree on exact dependency declarations, removal of stale rows, provider/server leakage
removal from neutral interfaces, route/presentation separation, no Live→Live edges, and composition
at executable roots.

One launch-assessment dependency finding has already aged: RT-019 records
`swift-identities-mailgun` as blocked (`Assessment/...md:238`), while the current local repository at
`fb023d2` vends `IdentitiesMailgun` and `IdentitiesMailgunLive` from a clean manifest. This makes it a
current direct-reuse candidate, not assumed-green consumer work; W1 still requires its own package
build and RepoTraffic behavior-parity gate.

No implementation should begin on the four disputed rows until Principal selects the controlling
end state.

## Wave plan

Effort is relative architecture-program effort: `S` bounded single seam, `M` multi-target/package,
`L` cross-repository/schema/public-API work. Each wave requires a new dispatch/edit zone.

### W0 — Ratification and immutable baseline (`S`, serial)

**Purpose:** prevent architecture and source work from racing.

1. Principal adjudicates the four assessment conflicts above and the asks at the end of this file.
   This includes the 38 exact cross-package lateral edges in `lateral-edge-asks.tsv`; [MOD-014]
   requires integration packages but does not erase [ARCH-LAYER-001] without an orchestrator
   disposition.
2. Record exact RepoTraffic manifest/source/test tree hashes, dependency pins, toolchain, build result,
   test result and protected dirty paths.
3. Freeze a package/target/edge manifest for the first wave; no package is created from working
   labels alone.
4. Record F1 for every affected target: Foundation imports and Foundation-defined types in API/state,
   the Institute primitive/standard replacement, or the exact opt-in Foundation Integration leaf.
5. Assign ownership per repository. Any change to a shared package and its RepoTraffic consumer is a
   coordinated pair with one integration gate.

**Go:** ratified seam table, authorized edit zones, green clean-input baseline.
**Stop:** source tree changes without re-census, unresolved package ownership, or any assumption that
a reserved L4 directory is implemented.

### W1 — Mechanical dependency honesty and direct reuse (`M`, mostly parallel)

**Purpose:** remove accidental transitive coupling before moving semantics.

Candidate tasks, only to the extent not already landed by the launch arc:

1. Finish exact root/target dependency declarations, then prune stale rows in the launch
   assessment's required order.
2. Route direct Vapor/Queues/PostgresNIO/ConsoleKit construction through current Server/L4 products
   where the ratified membrane already supports it.
3. Adapt GitHub polling and repository auto-track to Scheduler and Server Jobs behind temporary
   compatibility wrappers; keep their payload/cadence/effects unchanged. Treat CacheRefresh as a
   separate retirement decision: its refresh call is disabled at the pinned checkpoint, so J0 must
   prove the marker columns, scan and scheduled side effects are unconsumed. If they are required,
   design an explicit materialization policy + SQL projection before moving that job.
4. Replace app-local identity email closure assembly with the current
   `swift-identities-mailgun` products after an API/output parity check.
5. Move static product configuration out of `ProductsLive` into L5 configuration without changing
   catalog values.
6. Census Apple Foundation imports and Foundation-defined API/state per destination target. Do not
   create a new main target until its replacement vocabulary or exact opt-in integration leaf is
   named; core/main targets never depend on the leaf.

**Canaries:** M1 imports/dependencies, F1 Foundation boundary, J0 cache-refresh retirement, J1
retained-job parity, I1 identity-email parity.
**Go:** package-local and RepoTraffic build/tests green; no current URL, job payload, email, schema or
provider wire change.
**Rollback:** compatibility wrappers select the prior implementation; no schema change in this wave.

### W2 — Product-internal semantic seams (`L`, serial in RepoTraffic)

**Purpose:** prove the target graph before extracting shared packages.

1. Separate route types from response rendering and provider types.
2. Dissolve the current Account composition wrapper: it has no independent non-GitHub invariant or
   table at the pinned checkpoint. Move GitHub connection/provider/schema/SQL to their explicit
   seams and account-facing routes/views to Web. Split Repository/Traffic/Analytics/Ingestion/Access
   domains from SQL, GitHub, cache and Web joins. Cross-domain operation targets exchange stable
   identifiers/contracts, not another domain's Live implementation. Do not create RTAccount,
   RTAccountSchema or RTAccountSQL without new evidence and a fresh rent decision.
3. Canary a narrowly bounded `RTIdentifiers` target containing stable aggregate identifiers only.
   It must not acquire records, DTOs, clients, policy, provider types or schema merely to flatten
   depth; if it cannot remain identifier-only, use narrower domain identity targets and return the
   resulting depth/placement conflict for disposition.
4. Re-home all Live→Live assembly in roots.
5. Split RepoTraffic × GitHub by recipient concern: account connection/token, repository catalog,
   and traffic/stargazer ingestion. Within account connection, keep provider operations separate
   from `RTAccountGitHubCrypto`, `RTAccountGitHubSchema` and `RTAccountGitHubSQL`. The SQL target
   alone may name
   RTRepositorySchema, solely to preserve the atomic disconnect transaction that deletes repository
   memberships before the credential binding. The root injects key configuration into the Crypto
   adapter but implements no AES mapping. Post-connect bulk membership and ingestion triggers remain
   explicit L5 Web workflow edges.
6. If Principal selects domain-owned persistence, introduce narrow schema targets plus one domain
   SQL integration at a time. Analytics declares every GitHub-account, Repository and Traffic
   schema edge it joins. Access SQL declares only GitHub-account binding/Repository membership
   inputs and must not return or depend on traffic records; `repository_subscriptions` is repository
   membership, not a commerce SubscriptionSQL dependency.
7. Move product job bodies into `RTJobs`; roots only register them.
8. Replace the evidenced horizontal Cache/CacheLive token path with `RTAccountGitHubCache`, which
   owns protected-token lookup/eviction over the selected BoundedCache. Keep `RTAnalyticsCache` only
   if C2 first proves an actual Postgres-materialization read plus freshness/load budget. Roots
   contain construction only, never key/TTL/invalidation algorithms.
9. Put GitHub-ingestion sequencing in RTIngestion behind credential-resolver,
   repository-provider, traffic-provider/store and analytics-invalidation ports. Concrete
   GitHub/SQL/cache targets import those ports; the root selects conformances. Neither root nor Jobs
   owns the algorithm, and no base-domain → concrete-adapter edge is introduced.

Temporary forwarding clients/typealiases preserve source call sites for one migration wave. New
targets land additively; consumers move; old targets are removed only after reverse-reference and
downstream gates.

**Canaries:** P1 domain client parity, P2 route snapshot/round-trip parity, IDV1 identifier-only
cohesion, DB1 schema/query parity, G1 GitHub connect/disconnect/onboarding parity, A1 access-result
purity (decision/scope only; no traffic record type or TrafficSchema import), C2 cache-decorator
cohesion/parity, G2 credential protection, IG1 ingestion-port parity, F1 Foundation boundary.
**Go:** proposed edges exist at target level, no forbidden import, current functional tests pass, and
the longest-path/cycle report improves without a new shared grab-bag. Every new main target is
Foundation-free; any required Foundation Integration leaf points inward only.
**Stop:** any schema rename, route/status/cookie change, provider payload change, or domain target
that still requires its Live/provider module.

### W3 — Independent L3 foundation canaries (`M/L`, bounded parallel)

No package is created until its seam passes an in-repo canary using current behavior.

| Track | Dependency | Canary | Promotion condition | Effort |
|---|---|---|---|---|
| Pricing | none | Represent every current Stripe-derived amount/currency/cadence and round-trip provider fixtures without importing Stripe | One neutral value model preserves equality, encoding and display inputs; currency/decimal semantics ratified | M |
| Catalog | Pricing | Re-express current Catalog/Plan/SKU while keeping all RepoTraffic tiers/capabilities outside | Neutral catalog compiles with no RepoTraffic or Stripe token and current lookup/validation tests pass | M |
| Subscription | Catalog | Run current lifecycle/change/cancel/reactivate table against provider-neutral subject/catalog identifiers | State machine contains no Identity.ID, RepoTraffic tier/addon/SKU, Stripe, Records, Server or Foundation type; L5/product/provider mappings are lossless | L |
| Entitlement | none | Express RepoTraffic capabilities as a test-supplied generic capability type | Generic decision adds real invariant value and does not merely rename `Set<Capability>` | M |
| Message Delivery inbox | none | Reproduce Stripe receipt uniqueness, stale/duplicate/concurrent-claim/failure transitions | At-least-once handling contract and transaction behavior are explicit; no exactly-once claim | L |

Pricing → Catalog → Subscription is serial. Entitlement and Message Delivery can run in parallel in
separate repositories after API sketches are reviewed. RepoTraffic consumer edits remain serial.

**Go:** package-rent record, one coherent public concern, minimal dependency set, package contract
tests, exact-import audit, F1 pass and RepoTraffic adapter proof.
**Stop:** generic API contains RepoTraffic/provider/Foundation terms, requires an umbrella
dependency, or only moves code without a stable semantic law.

### W4 — Persistence and provider integrations (`L`, dependency-ordered)

Order:

1. `MessageDeliverySQL` inbox receipt/migration, preserving provider event IDs and status semantics.
2. `SubscriptionSQL`, preserving neutral state under neutral subject/catalog identifiers while
   removing Identity, RepoTraffic and Stripe columns from its final schema.
3. `CatalogStripe` provider mapping.
4. `SubscriptionStripe` for subscription client/payload mapping only.
5. `SubscriptionStripeSQL` for the provider-binding schema and exact customer/subscription/schedule
   ID lookups. Expand and backfill before removing old columns.
6. `MessageDeliveryStripe` for signature/envelope/idempotency mapping only.
7. `SubscriptionStripeDelivery` for pure delivery-to-transition mapping; it owns no catalog
   mapping, route, storage, or other Stripe event.
8. `SubscriptionStripeDeliverySQL` for the one atomic receipt + neutral state + provider-binding
   transaction.
9. Only after atomicity is proved, consider an outbox addition; do not bundle it into the initial
   inbox move.

Each adapter is a dedicated package; base packages never import it. Server PostgreSQL is selected by
the L5 root. Expand/backfill/contract preserves the three provider IDs, neutral subject/catalog IDs,
uniqueness, foreign keys and update/cancel/schedule lookups. A single database transaction covers
receipt claim, neutral subscription mutation and provider-binding mutation.

**Canaries:** D1 delivery replay, S1 neutral subscription SQL parity, SB1 Stripe-binding migration,
S2 Stripe sandbox mapping, TX1 injected failure before/after commit, F1 Foundation boundary.
**Go:** deterministic fake-provider contracts, sandbox probe, rollback/replay proof, downstream green.
**Stop:** dual authority, distributed transaction, provider type in neutral API, or lost idempotency.

### W5 — L4 component experiments (`M/L`, parallel after W3)

**Checkout (`M`):** introduce only a provider-neutral `Intent`/`Result`/client seam in a temporary
RepoTraffic target. Map the current Stripe flow through it. If Stripe session IDs, product routes,
analytics or Billing state remain necessary in the base surface, keep Checkout at L5 and do not
create `swift-checkout`.

**Waiting List (`L`):** isolate entry/confirmation/referral/admin invariants from routes, copy,
Mailgun and SQL. Run an embedded fake/SQL contract. A remote canary must mount every route and run
the same contract through HTTP before `WaitingListRemote` is retained.

These tracks can run in parallel because they share no proposed base package. Their RepoTraffic
manifest changes must still integrate serially.

**Go:** coherent L4 responsibility, contract parity, no product copy/provider/storage in base.
**Stop:** package is merely a folder extraction, or remote mode is used to manufacture service rent.

### W6 — Identity both-mode proof (`L`, independent upstream track)

1. Resolve the conversion-failability-direction ruling that keeps `Identity Standalone` red.
2. Separate or slim a provider-neutral `IdentityContract` seam from current Identity Shared's
   ServerFoundation/Vapor and Foundation dependencies; genuine Foundation interop goes in a
   dedicated integration leaf. The exact product/package disposition belongs to the identity
   architecture.
3. Put identity schema, queries, migrations and session invalidation behind an Identity × SQL
   integration; eliminate Backend/app raw persistence leakage without changing data authority.
4. Expose supported embedded assembly and session invalidation; eliminate app raw SQL.
5. Run one shared contract suite against embedded Backend/Provider and a local Standalone host with
   Consumer/Frontend.
6. Prove exactly one data authority per mode and a reversible embedded↔remote migration in disposable
   databases.
7. Re-run the service-rent test with measured multi-product/security evidence.

This track does not block RepoTraffic's embedded use or commerce/message-delivery extraction. It
blocks only approval of centralized identity deployment.

**Go for package parity:** Foundation-free IdentityContract main target, green Standalone, identical
observable contract, migration/rollback proof.
**Go for service:** every service-rent row passes plus Principal approval.
**Stop:** Foundation/Server/Records leakage in the proposed L3 contract, host-only domain behavior,
dual writes, synchronous remote dependency without SLO/fallback, or a service justified only by
reuse.

### W7 — L5 root thinning and deployment canaries (`L`, serial integration)

1. Build `RTWeb`, `RTMarketingWeb`, `RTJobs` and selected integration targets from prior waves.
2. Reduce both executables to the structural budget in the dependency artifact.
3. Aggregate migrations without defining schemas in roots.
4. Run web-only and web+worker modes using the same package contracts.
5. Apply the already-approved Redis removal: Postgres materialization plus bounded in-process cache;
   compose the evidenced `RTAccountGitHubCache` and only a C2-approved `RTAnalyticsCache` in the root
   without moving key, TTL or invalidation policy into the executable. Do not introduce a new cache
   package during cutover.
6. Add logging-field contracts first. Metrics/tracing get a bounded boundary canary only after a
   concrete operational question is named.

**Canaries:** R1 root responsibility audit, W1 worker split, C1 cache shadow-read, C2 decorator rent,
F1 Foundation boundary, O1 boundary telemetry.
**Go:** root gates pass; web/worker modes preserve jobs; cache parity meets freshness/load budgets;
observability failure never breaks product requests.
**Rollback:** one deployable mode, prior cache reader, and logging-only instrumentation remain
available until the next certification.

### W8 — Downstream certification and retirement (`M`, serial close)

1. Build/test every changed package at exact commits.
2. Run integration contract suites and explicit provider sandbox probes.
3. Build/test RepoTraffic with exact pins and a clean build directory.
4. Build/test a minimal second-SaaS fixture that uses identity, catalog, subscription, entitlement,
   message delivery, jobs and email without importing RepoTraffic or Stripe in neutral targets.
5. Re-run import, layer, cycle and longest-path diagnostics.
6. Record source/API compatibility, database migration/rollback, deploy smoke and known limitations.
7. Remove forwarding targets/typealiases only after zero reverse references and downstream proof.

Release or tag actions remain separate Principal-authorized work. Certification does not imply
release.

## Canary catalog

| ID | Scope | Success signal | Stop signal | Reversible fallback |
|---|---|---|---|---|
| M1 | Exact dependencies | Every direct import is declared; no dead row supplies a transitive import | Resolution drift or undeclarable internal module | Restore manifest row; no source/schema change |
| F1 | Apple Foundation boundary | Every proposed main target has zero Foundation import and zero Foundation-defined API/state; each genuine interop leaf is explicitly named and depends leaf → core | Any main/core target imports Foundation, exposes its types or depends on/re-exports a Foundation Integration leaf | Keep old target compiled while replacement vocabulary/leaf is proven |
| J0 | CacheRefresh disposition | Reverse-reference and operational evidence proves its scan, refresh-marker writes and schedule are obsolete, or a named materialization policy/SQL projection is approved | Removing it changes required freshness/materialization behavior, or moving it would retain raw cross-schema SQL in RTJobs/root | Keep the old job registered until the explicit replacement is canary-green |
| J1 | Scheduler/Server Jobs | Polling and auto-track retain registry, cadence, payload encoding, retry and observed effects | Duplicate/lost job or incompatible queued payload | Compatibility adapter and drained old queue |
| I1 | Identity Mailgun | Same nine operations, recipients, links and text/HTML semantics | Link/subject/delivery/error behavior differs | App-local closures remain selectable for canary only |
| P1 | Product domains | Old/new clients return equal domain results over recorded fixtures | Provider/SQL/UI type required by neutral target | Forwarding target routes back to old client |
| IDV1 | Product identifiers | Target contains stable identifiers only and all consumer edges remain semantic | Any record/DTO/client/policy/provider/schema is hoisted to flatten depth | Keep identifiers with their domains and reopen depth/placement disposition |
| P2 | Routes/Web | URL print/parse, methods, status, cookies and response semantics match | External route contract changes | Mount old router/handler |
| DB1 | Domain SQL split | Same schema names, migrations and query results; rollback test green | Rename/data loss/dual writer | Old record target remains compiled until cutover |
| G1 | GitHub account lifecycle | Connect validates/protects/upserts identically; post-commit onboarding fires; disconnect atomically removes memberships then binding | Plaintext persistence, lost onboarding, partial disconnect or provider/SQL leakage into base Account | Route old client through the compatibility target |
| G2 | GitHub credential protection | Pinned ciphertext decrypts; new values round-trip; key shape is validated; old-key read/new-key write rotation works; failed decrypt is typed; DB/logs contain no plaintext | Ciphertext incompatibility, silent fallback, unbounded external Crypto dependency or secret handling in root | Retain current AccountLive adapter behind compatibility until Crypto disposition and fixtures pass |
| IG1 | Ingestion ports | Pinned polling/onboarding fixtures preserve credential resolution, GitHub calls, traffic writes and invalidation order with root-selected conformances | Sequencing moves into root/Jobs, base imports a concrete adapter, or any effect/order is lost | Select the old SyncingLive client through the compatibility target |
| A1 | Access seam | Access result contains decision/scope only and loads only GitHub-account binding/Repository membership inputs | Traffic record type/result or TrafficSchema import reappears | Keep old projection behind an adapter while Web moves data fetches |
| C2 | L5 cache decorators | Protected-token shadow reads match; an Analytics decorator is retained only with an actual materialization read plus explicit freshness/load budget; policy stays in the evidenced/approved L5 decorator | Speculative Analytics cache, root-owned policy, secret boundary leak or changed results | Select the uncached/old bounded path; omit RTAnalyticsCache when unproved |
| PR1 | Pricing | All current prices/currencies/cadences round-trip without Stripe import | Precision/currency ambiguity or provider token leaks | Keep L5 Pricing |
| CA1 | Catalog | Current catalog validation/lookup parity with product policy injected above | RepoTraffic capability/tier enters base API | Keep L5 Products |
| SU1 | Subscription | Full transition table and scheduled changes match under neutral subject/catalog IDs | Identity.ID, RepoTraffic tier/addon/SKU, Stripe, Records, Server or Foundation type leaks; transition mismatch | Keep current Billing state path |
| S1 | Neutral Subscription SQL | Neutral subject/catalog/state round-trips with identical lifecycle queries and no provider/product/Identity column in the final schema | Data loss, dual writer, provider/product coupling or irreversible contraction | Keep old mixed table authoritative during expand/backfill |
| SB1 | Stripe binding SQL | Customer/subscription/schedule IDs backfill exactly; uniqueness/FKs and update/cancel/schedule lookups match; rollback works before contraction | Missing/duplicated ID, broken lookup, premature old-column removal or split authority | Read old columns through compatibility view/adapter until binding is certified |
| EN1 | Entitlement | Generic law adds tested decisions over supplied capability type | It is only a generic set alias or needs product cases | Keep entitlement policy in L5 |
| D1 | Delivery inbox | Duplicate/replay/stale/concurrent claims yield one committed domain effect | Lost receipt, double effect, exactly-once assumption | Keep current Stripe.Event.Record path |
| TX1 | Receipt + mutation | Failure injection proves one transaction covers receipt claim, neutral state and Stripe binding before commit | Any partial commit, dual authority or distributed transaction | Co-locate current transaction/table path |
| CO1 | Checkout | Fake and Stripe adapters share neutral intent/result contract | Stripe session/route/analytics leaks into core | Keep Checkout L5 |
| WL1 | Waiting List | Fake/SQL and embedded/remote contracts agree on every mounted route | Orphan route, product copy/provider in core | Keep current embedded L5 target |
| ID1 | Identity both mode | Embedded and hosted contract parity; one authority; reversible migration | Standalone red, dual writes or auth outage ambiguity | Embedded mode |
| C1 | Redis removal/cache | Shadow reads agree; freshness and DB load stay within explicit budget | Stale result or unacceptable DB load | Prior reader during bounded canary; no new writes split |
| O1 | Observability | Boundary fields/context visible; exporter failure is non-fatal | PII leak, request failure or uncontrolled cardinality | Logging-only path |
| R1 | Thin roots | Every root file fits an allowed category; forbidden declaration/import counts, including Foundation, are zero | Business/provider/storage/presentation/Foundation code remains in root | Do not remove old target until relocated |

## Compatibility strategy

1. **Add, route, retire.** Add the new package/target and compatibility surface, route one consumer,
   prove downstreams, then remove the old surface. Never move and delete in one opaque step.
2. **Source compatibility.** Use bounded forwarding clients or principal-approved aliases only where
   they make migration nil-cost. Give every bridge an owner and retirement gate.
3. **Route compatibility.** Preserve URL/method/status/cookie contracts; any intentional change is a
   separately ratified product/API migration.
4. **Database compatibility.** Expand/migrate/contract; preserve table/column/provider IDs; single
   writer per state; backup and rollback proof before destructive contraction.
5. **Event compatibility.** Preserve provider event IDs, raw evidence needed for replay, receipt
   states and ordering policy. Version domain payloads explicitly if they leave process/database.
6. **Job compatibility.** Version payloads; drain or support existing queued jobs before changing
   decoders/registries.
7. **Deployment compatibility.** New worker/remote modes start as optional canaries. Embedded/single
   process remains available until the new mode is certified.

## Parallelization boundaries

| Work | May run in parallel with | Must remain serial with |
|---|---|---|
| Scheduler/Server Jobs reuse | Identity Mailgun adoption; Entitlement/API research | RepoTraffic manifest/boot integration |
| Pricing → Catalog → Subscription | Message Delivery; Entitlement; Identity upstream | Each other, in that order |
| Message Delivery | Entitlement; Identity upstream; WaitingList seam research | SubscriptionStripe/SQL atomicity integration |
| Checkout component canary | WaitingList component canary; Identity upstream | Catalog/Pricing availability; RepoTraffic manifest merge |
| Identity Standalone repair | Commerce and product-domain work | Embedded/remote parity and any service decision |
| Domain SQL splits | Non-SQL provider/API research | Each schema migration and global migration registry |
| Provider integrations | Unrelated provider integrations after bases are fixed | Their base package API and RepoTraffic consumer cutover |

Parallel work must use disjoint repositories/edit zones. Shared RepoTraffic `Package.swift`, root
wiring, migrations and deploy definitions are serial integration points.

## Principal decisions and unresolved evidence

| Ask | Why it cannot be inferred | Blocks |
|---|---|---|
| Ratify semantic integrations vs preserving 12 interface/Live pairs | Conflicts with the launch assessment's proposed end state | W2 onward |
| Disposition all 38 proposed L3/L4 lateral package edges | [ARCH-LAYER-001] forbids lateral edges; MOD-014 bridges require explicit orchestrator authority or re-layer/merge | Any proposed package creation |
| Select domain-owned SQL integrations vs horizontal `RepoTrafficRecords` | Both are explicit proposals; schema ownership is architectural | Persistence part of W2/W4 |
| Enforce Server engine quarantine at L5 roots | Launch assessment says keep some direct engines; ratified server research says quarantine | W1 root dependency work |
| Approve working L3 seams and repository names/visibility | Repository creation/public API/release axes are Principal actions | W3 package creation |
| Accept identifier-only RTIdentifiers target or choose narrower identity targets | A generic Core would violate cohesion; the narrow target is only valid if it remains one identifier concern | W2 target graph |
| Resolve money/currency/decimal vocabulary | No existing generic package was found; wrong primitive would contaminate Pricing/Catalog | Pricing → Catalog → Subscription |
| Resolve Crypto mechanism for credential protection | RepoTraffic uses Apple swift-crypto; Institute swift-crypto at `58b32a11b8a9660075436b9d2146b6cd5aef16e0` is reserved/unimplemented, so the target cannot silently bless either | RTAccountGitHubCrypto extraction; current compatibility adapter may remain |
| Ratify neutral Subscription subject/catalog identifier law | Current table binds Identity.ID and RepoTraffic tier/addon/SKU directly; reusable persistence must not | Subscription/SubscriptionSQL public API and migration |
| Decide cache repository ownership/collision | Two implemented repositories overlap and L4 reservations are empty | Any generic cache evolution; not Redis removal |
| Confirm CacheRefresh retirement or name its materialization replacement | The pinned job's intended refresh is disabled, but its scan/marker writes may still have external operational meaning | Final RTJobs graph and old refresh-marker schema retirement |
| Ratify Identity Standalone conversion direction and service trigger | Target is red and service rent currently fails | Hosted identity only |
| Approve logical L4 physical home when packages are created | Current L4 reservations and server tenancy do not decide organization structure | Checkout/WaitingList package creation/rehome |
| Promote or reject Checkout and WaitingList after canaries | Current evidence is mixed and one consumer cannot settle semantic honesty without experiment | W5 promotion |
| Decide generic MessageDelivery outbox scope | Inbox/idempotency is evidenced; transactional producer outbox is not | Outbox only, not inbox extraction |

## Outcome

**Status**: RECOMMENDATION — pending Principal adjudication.

The safe route is additive and evidence-driven: clean dependencies and direct reuse, prove product
seams inside RepoTraffic, extract small foundations in dependency order, add dedicated integrations,
then test optional components and deployment modes. Identity service work is independent and gated;
no service blocks the reusable package graph. Conflicts with the launch assessment are explicit
Principal asks rather than silent drift.

## References

- [Provenance and architecture](provenance-and-architecture.md)
- [Capability atlas and target matrix](capability-atlas-and-current-to-target-matrix.md)
- [Dependency, layer, and golden path](dependency-layer-and-golden-path.md)
- [Service-rent decisions](service-rent-decisions.md)
- [Independent review record](independent-review-record.md)
- [RepoTraffic launch assessment](/Users/coen/Developer/repotraffic/repotraffic-com-server/Assessment/2026-07-16-substrate-assessment.md)
- [Institute server-stack architecture](/Users/coen/Developer/swift-institute/Research/institute-server-stack-architecture.md)
