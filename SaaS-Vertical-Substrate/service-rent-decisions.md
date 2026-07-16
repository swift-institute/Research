# SaaS Vertical Substrate — Service-Rent Decisions

<!--
---
version: 0.1.0
last_updated: 2026-07-16
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
changelog:
  - 0.1.0 (2026-07-16): Initial identity deployment-mode analysis and six-capability service-rent test.
---
-->

## Context

A reusable package and an independently deployed service solve different problems. Reuse removes
semantic duplication; a service introduces a network and operational boundary. This artifact tests
identity, billing, events, jobs, notifications, and observability without assuming that “vertical”
means “microservices.”

## Question

Which capabilities have enough measured operational or product value to pay the full cost of
independent deployment, and which should remain packages or optional process modes?

## Analysis

The analysis applies one fail-closed cost test to identity and five adjacent capabilities, then
separates code reuse, process topology and independent service ownership.

## Fail-closed service-rent test

A candidate is approved as a service only when both conditions hold:

1. At least one measured hard driver requires independent security/data ownership, availability,
   scaling, release cadence, or organizational ownership. “Could be reused” is not a hard driver.
2. Every cost row below has a specified contract, owner, test and failure posture. An unknown cost
   fails closed; it is not balanced away by speculative benefit.

| Dimension | Required evidence before approval |
|---|---|
| Network | Latency budget; timeout/retry/idempotency semantics; overload/backpressure behavior; behavior when unreachable |
| Availability | Service SLO; dependency effect on each caller's SLO; degraded/fail-open/fail-closed behavior; recovery proof |
| Versioning | Versioned protocol; additive/breaking-change policy; compatibility window; consumer-driven contract tests |
| Security | Trust boundary; authentication/authorization; secret ownership; PII/payment classification; incident/rotation procedure |
| Data ownership | One system of record; transaction boundary; migration/backup/deletion responsibility; no implicit dual write |
| Deployment | Independent scale/release/rollback reason; topology; capacity model; rollout and rollback runbook |
| Operational cost | Named on-call owner; dashboards/alerts/runbooks; provider and infrastructure cost; local/test environment story |

Passing package rent is necessary but not sufficient. A separately deployed worker using the same
packages is not automatically a new business service; it may be only an execution topology.

## Identity: three deployment modes

### Mode A — embedded

The application imports Identity Shared/Backend/Provider/Views as needed, owns the identity tables in
its database, and constructs the identity witness in its root.

| Property | Assessment |
|---|---|
| Current feasibility | **Real but incomplete ergonomically.** RepoTraffic does this today using active subproducts and app-side assembly. |
| Data authority | The application database is the single identity source of truth. |
| Failure boundary | Identity fails with the app; no network hop for authentication/session checks. |
| Strength | Lowest latency and operational cost; local transactions; simplest first product. |
| Cost | Each product operates migrations, keys, email and identity upgrades; app-side assembly currently duplicates upstream logic. |
| Required repair | Expose supported assembly/session-invalidation APIs and reuse `swift-identities-mailgun`; remove raw-SQL/app-local identity glue. |

### Mode B — centralized identity service

One independently deployed host owns identity data and exposes a versioned provider/consumer
protocol. SaaS applications hold no writable identity copy.

| Property | Assessment |
|---|---|
| Current feasibility | **Not ready.** `Identity Standalone` is explicitly disabled/unvended and red; current app-side code is not a supported service host. |
| Data authority | Service must be the sole identity source of truth; product databases store stable foreign IDs only. |
| Failure boundary | Login, refresh and possibly request authentication depend on network/service availability. Token validation may reduce per-request coupling but revocation semantics must be explicit. |
| Strength | Can centralize security controls, SSO, key rotation, identity deletion and multi-product lifecycle. |
| Cost | Highest availability/security burden, protocol evolution, incident blast radius, network failure modes and migration complexity. |
| Approval trigger | Multiple real products requiring one identity authority, or a measured security/compliance/ownership need that cannot be met embedded. |

### Mode C — shared domain with both deployment postures

The same Identity domain/backend/provider contracts support either embedded construction or a remote
consumer. Each product deployment selects exactly one authority; “both” means portable packaging,
not two writable identity stores.

| Property | Assessment |
|---|---|
| Current feasibility | **Partially real.** Shared/Backend/Provider/Consumer/Frontend products exist; embedded works. The provider-neutral L3 contract seam is not clean because Identity Shared imports ServerFoundation/Vapor and Foundation in 17/22 files; the standalone host and parity suite also do not exist green. |
| Data authority | Exactly one per deployment: local when embedded, service when remote. |
| Strength | Preserves package reuse now and keeps a later service reversible; avoids forcing every SaaS through a premature network boundary. |
| Cost | Requires embedded/remote contract parity and disciplined avoidance of host-only behavior in the domain API. |
| Decision | **RECOMMENDED architecture.** RepoTraffic remains embedded initially. Central service remains a gated deployment option, not the default. |

### Identity service-rent result

| Dimension | Current finding | Pass now? |
|---|---|---|
| Network | No measured latency/failure budget; authentication would gain a hard dependency; token revocation/cache behavior unspecified | No |
| Availability | No identity-service SLO, degraded mode or recovery proof | No |
| Versioning | Consumer/Frontend products exist, but no green Standalone host or embedded/remote parity suite | No |
| Security | Centralized keys/PII could be a hard future driver; no current compliance/ownership requirement was supplied | Conditional benefit, not evidence |
| Data ownership | A clean service-owned model is possible; no migration/cutover/backup/delete plan exists | No |
| Deployment | No independent scaling/release evidence; host target is red | No |
| Operational cost | No on-call owner, runbook, dashboards or cost model | No |

**Decision:** identity passes package rent and the both-mode architecture, but **does not pass service
rent now**. Do not centralize RepoTraffic identity before Standalone is green, contract parity is
proved, and a hard driver is measured.

## Cross-capability service-rent matrix

| Candidate | Network | Availability | Versioning | Security | Data ownership | Deployment | Operational cost | Decision |
|---|---|---|---|---|---|---|---|---|
| Billing/subscriptions | Would put account/entitlement checks and lifecycle mutations behind timeouts/retries; no latency budget | No SLO/fallback; access decisions may fail closed | No neutral remote protocol or compatibility plan | Stripe limits raw payment handling, but local neutral state and provider bindings still contain commercial/subject data; no separate compliance owner | Receipt, neutral SubscriptionSQL state and SubscriptionStripeSQL binding need one local transaction through SubscriptionStripeDeliverySQL; a service split risks distributed transactions | No independent scale/release/finance-team need measured | No on-call/runbook/cost model | **NO SERVICE.** L3 Subscription plus neutral SQL, Stripe binding/provider and atomic delivery SQL integrations; external Stripe remains the provider service. Re-test only for multiple products or independent finance/compliance ownership. |
| Events/message delivery | Broker/service hop adds publish/consume failure, backpressure and replay semantics; not measured | No event-service SLO or product degradation model | Event schema/version/retention compatibility not defined | No cross-trust requirement; Stripe signature validation belongs provider adapter | Inbox receipt and state mutation need one transaction; a central bus would not own domain truth | Current volume/fan-out/independent scaling not measured | Broker, storage, relay and on-call costs unowned | **NO SERVICE.** MessageDelivery + SQL packages in-process; an optional relay worker later. Re-test on measured fan-out/throughput/backpressure. |
| Jobs | A business-service API is unnecessary; queue transport is already quarantined by Server Jobs | Worker failure can be isolated with existing execution modes; no new service SLO needed | Scheduler job payload contracts already define the boundary; versioning remains producer/worker concern | No independent trust boundary shown | Owning domains retain state; jobs carry IDs/payloads rather than own data | Separate worker process is useful for load/isolation but can use the same app packages and release | Existing server/queue operations already cost enough; a new service adds no owner/value | **NO JOB SERVICE.** Reuse Scheduler + Server Jobs; permit web/worker deployables from one composition. |
| Notifications | A new hop would precede Mailgun, creating two remote dependencies; no latency/retry budget | No notification SLO or fallback; only email is demonstrated | No multi-channel message/preferences protocol | Central consent/preferences could matter later; no current requirement | Identity and WaitingList own recipient/purpose; no neutral notification source of truth | No independent volume/scaling/team evidence | Mailgun already externalizes delivery; another service needs queues, storage, on-call and cost | **NO SERVICE / NO GENERIC NOTIFICATION PACKAGE.** Reuse Email/Mailgun and domain integrations. Re-test for shared preferences, compliance, multi-channel delivery or measured volume. |
| Observability | Telemetry export is naturally remote/asynchronous, but application request paths must not depend synchronously on it | Backend outage must degrade by dropping/buffering telemetry; no Institute backend SLO needed | Open ecosystem protocols can supply compatibility; no custom protocol justified | Telemetry redaction/access is important, but not evidence to build a service | Observability backend owns telemetry copies, never product source-of-truth data | External collector/backend can deploy independently; no Institute implementation exists or is needed | Building/operating metrics/log/tracing storage is a large undemonstrated cost | **NO INSTITUTE SERVICE.** Instrument through libraries/adapters and select an external backend/collector at L5. |

Billing, events, jobs, notifications and observability all fail at least one mandatory cost row; most
fail all seven. None is proposed as an independently owned Institute service.

## Deployment postures that do not create new service seams

| Posture | Package ownership | Data authority | When useful |
|---|---|---|---|
| One web process | Same L3/L4/L5 graph | Product database + external providers | Initial RepoTraffic path |
| Web + worker processes | Same code graph; roots select Scheduler execution/registries | Same product database | Isolate long-running GitHub ingestion or webhook relay load |
| Embedded identity | Identity packages loaded into app root | Product database | Default until service rent passes |
| Remote identity | Same Identity contracts plus green host/consumer | Identity service only | Conditional future multi-product/security mode |
| External observability collector | Logging/metrics/tracing adapters export asynchronously | Collector/backend owns telemetry copy | Once instrumentation canary is justified |

Process separation can be independently scaled and rolled back without moving semantic ownership to
a new service API. This distinction keeps the architecture reversible.

## Stop/go gates for any future service

A future proposal must provide, before implementation:

1. named hard driver and production measurement;
2. protocol and compatibility contract;
3. data authority and transaction diagram;
4. network/availability failure matrix;
5. security threat/trust-boundary review;
6. deployment, migration, rollback and disaster-recovery plan;
7. operating owner, SLO, dashboards, alerts, runbooks and cost estimate;
8. embedded-to-remote or monolith-to-service reversible canary;
9. Principal approval of the service boundary.

Absent all nine, package/process mode remains the decision.

## Outcome

**Status**: RECOMMENDATION — pending Principal adjudication.

Identity should be deployment-neutral at the package/API level and embedded for RepoTraffic now.
Billing, events, jobs, notifications, and observability remain package/integration concerns; jobs may
run in a separate worker, and observability may export to an external backend, without inventing
Institute business services. No candidate passes current service rent.

## References

- [Provenance and architecture](provenance-and-architecture.md)
- [Dependency, layer, and golden path](dependency-layer-and-golden-path.md)
- [Extraction and canary plan](extraction-and-canary-plan.md)
- [Independent review record](independent-review-record.md)
- [swift-authentication Package.swift](/Users/coen/Developer/swift-foundations/swift-authentication/Package.swift)
- [swift-scheduler Package.swift](/Users/coen/Developer/swift-foundations/swift-scheduler/Package.swift)
- [swift-server Package.swift](/Users/coen/Developer/swift-foundations/swift-server/Package.swift)
- [RepoTraffic Billing sources](/Users/coen/Developer/repotraffic/repotraffic-com-server/Sources/Billing/)
- [RepoTraffic job sources](/Users/coen/Developer/repotraffic/repotraffic-com-server/Sources/com_repotraffic_app/Jobs/)
