# SaaS Vertical Substrate — R2 Reconciliation and Principal Decision Packet

<!--
---
version: 1.0.0
last_updated: 2026-07-16
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
changelog:
  - 1.0.0 (2026-07-16): Reconciled R1 with immutable RepoTraffic hardening and committed networking evidence.
---
-->

## Outcome

RepoTraffic can remain a thin L5 assembly, but the accepted hardening does not by itself ratify the
R1 package graph. At immutable checkpoint `890c5e6`, hardening made the manifest honest, restored a
test target, proved one interface-purity seam, and reduced accidental graph depth. It did **not**
prove that syntactic `X`/`XLive` pairs are semantic packages, that horizontal
`RepoTrafficRecords` should survive, or that current Vapor/PostgresNIO/NIO exposure belongs in the
end-state roots.

The recommended end state is:

1. RepoTraffic's roots compose logical L4 integrations and product policy; external engines remain
   temporary, explicitly owned dependencies until their Institute successors pass canaries.
2. Preserve coherent interfaces, but replace `XLive` as an architectural rule with semantic join
   targets and a one-wave compatibility aggregate where necessary.
3. Dissolve horizontal `RepoTrafficRecords` into domain-owned schema and SQL integrations, with an
   explicit compatibility facade and expand/backfill/cutover sequence.
4. Keep `WaitingListRemote` dormant only if a real remote route/deployment contract is approved;
   do not extract it or infer a service from its name.
5. Place cross-domain/provider integrations at L4 unless Principal explicitly ratifies a narrower
   same-layer cluster. Do not silently implement the 38 R1 lateral edges.
6. Create no generic `swift-saas` umbrella, generic billing package, identity service, or service
   fleet. Current evidence proves none of their operating rent.

One clean, policy-independent implementation batch can begin immediately: add a Foundation-free
core and an explicitly named Foundation integration leaf to `swift-environment-dependencies`, while
retaining the current module temporarily as a deprecated compatibility wrapper. That is a focused
ServerFoundation-dissolution improvement controlled by already ratified
`[ARCH-LAYER-007]`/`[ARCH-LAYER-013]`; it does not touch RepoTraffic, networking, Control Plane, or
any concurrent worktree.

## Evidence boundary

### Commit-pinned inputs

| Input | Commit | Tree/subtree or load-bearing objects |
|---|---|---|
| Accepted SaaS R1 | `d7f34cf392d5b2f3db03900cf5d0cae4c91573eb` | tree `30a04e698bda4099aa26d3baf53e60fc5cf50ea6`; SaaS subtree `02352f4f7849152466d8ecbaf8123cd82b9c48bf` |
| RepoTraffic hardening report | `1bc6a1a816d5e2f1024c4fff4589d7258b1ade4e` | tree `c6594d85e2372c2e2b2a6345886a614bb3f4b75f` |
| RepoTraffic immutable checkpoint | `890c5e684e55ba22f072637a987b9ac9b08475d5` | tree `13a5816df80e4c3fc3fd0c24531c20bbd3d8784e` |
| RepoTraffic manifest | `890c5e6:Package.swift` | blob `bdf88fbae38daf62636e63f52dba5779accd408e` |
| RepoTraffic lock | `890c5e6:Package.resolved` | blob `af79586546e5d56497baf5e98b5086d3e5dadd0a` |
| RepoTraffic source/tests | `890c5e6` | Sources tree `f6043584868f9d95119b7c2dacb4dc8182791014`; Tests tree `4bfeee8fe673fd6f3f67333279c28d6529677661` |
| RepoTraffic durable census | `890c5e6:Assessment/census` | tree `5cff664c0f895c9c8a102eb9621a675e772c3d9f` |
| Pure Institute Networking | `601f9309055098611c3459b1fd284dd0442a9136` | tree `7846005afd151e5add6be20577427337b5ee0acb`; subtree `722bec822b1db57e4c1f08e7c6da707494abf280` |
| Control Plane committed Research | `ee49cab9177b6d3ed7e245017a0eb9cedcc65017` | subtree `e955644edb8ab6983cf0b6f2fdfb3575e59c3fdb` |
| Immediate-batch package | `7651367d1e2b75091928a076cb5e072e8650cf49` | clean tree `e4525a12f08813cd1f20d2fe1b5086a79cd60885` |

Focused successor inventory was read at these local immutable identities:

| Package | Commit | Tree |
|---|---|---|
| `swift-server-foundation` | `781565c82111579cf2748af82e0c08b400095019` | `3d26c89c035336888b3cc6d721a61245f88e6639` |
| `swift-server-foundation-vapor` | `7fd69ede4a9a5dc172926c30e840e67766521f59` | `97ea91905a9cf65d7debc6baa19cbdd45e18da8a` |
| `swift-urlrequest-handler` | `881c6f7cbbb321b3b17ba00a1ae2a5edafab73b4` | `24ca0975128fbdda3ab78626f076d9f792da7f58` |
| `swift-environment` | `0a2e99840d6f449c9e12af641f2469988b399ce4` | `57e02527add409b9a09e791ea02b6b3f5485b293` |
| `swift-environment-dependencies` | `7651367d1e2b75091928a076cb5e072e8650cf49` | `e4525a12f08813cd1f20d2fe1b5086a79cd60885` |
| `swift-logging-extras` | `04aa6e97242f56ac36745d6f05b05f0c6382c785` | `3d4daf34f80b4438589544c74abcf9a1f59ec91d` |
| `swift-types-foundation` | `2d6bf1b1fc6ab35105a371508421be51d03c075a` | `ae66016377075d3ea017ae8c7fd7759f0f5f66b0` |
| `swift-server` | `1b3767fcf5682cf7ea3b2d8a9362d42e6217536f` | `bf36dc9d3d024818ebb86d5081d19d25d8bbf108` |

RepoTraffic `890c5e6` includes the hardening gate `e478a9b`, reproducible lock `726f53d`,
and durable receipt. The receipt remains valid evidence for its instrument and positive controls,
but its final JSON represents the 45-target `e9aaa45` stage, not the exact 46-target `890c5e6`
manifest. The R2 numbers below therefore come from independent immutable archives and a separately
controlled scope. The receipt itself warns that token-free imports can be load-bearing under
MemberImportVisibility and require compile gates (`Assessment/census/RECEIPT.md:27-30`).

### Excluded concurrent state

The live RepoTraffic worktree belongs to another owner. A path-only status observation found
concurrent modifications to `Package.swift`, `Package.resolved`, Analytics, WaitingList, one Billing
file, and WaitingList tests, plus untracked product/operations documentation. Their contents were
not read and are not canonical evidence. No R2 command edited, staged, restored, stashed, reset,
rebased, cleaned, formatted, resolved, built, or tested that repository.

Exact excluded RepoTraffic paths at that observation:

```text
Package.resolved
Package.swift
Sources/Analytics/Analytics.Owner.Route.swift
Sources/Analytics/Analytics.Owner.View.swift
Sources/Analytics/Analytics.Repository.Route.swift
Sources/Analytics/Analytics.Route.swift
Sources/Analytics/Analytics.User.Route.swift
Sources/Analytics/Analytics.User.swift
Sources/Analytics/Analytics.View.swift
Sources/Billing/Billing.Subscription.Cancel.swift
Sources/WaitingList/WaitingList.Router.swift
Tests/WaitingList Tests/WaitingList.RouterTests.swift
CLAUDE BUSINESS MODEL.md
CLAUDE MODULE ASSETS.md
CLAUDE-GO-TO-MARKET.md
DOMAIN_ARCHITECTURE.md
ENVIRONMENT_SETUP.md
STRIPE_WEEKLY_SETUP.md
docs/LOG_IMPROVEMENTS.md
```

A final read-only `rev-parse` after review observed that the external arc had advanced live HEAD to
`4d6e4beaacffe2e5fcdcbaf0abcdee60b7c5c83f`, tree
`72211ff8bba20eff74f5a4c23b8bea38186e7548`. R2 did not inspect that commit or rebase its evidence
onto it. It is a post-checkpoint concurrent identity, excluded from every census and conclusion;
future adoption requires a separate immutable recensus. The advance is consistent with the stated
external ownership and does not alter the R2 source pin at `890c5e6`.

Control Plane V3 source and its dirty Research file are separately owned and were not edited.
Unrelated Research dirt in `Control-Plane-V3`, `Reflections`, `_index.json`, and three untracked
Research documents is also excluded. The R2 edit zone is only `Research/SaaS-Vertical-Substrate`.

Exact unrelated Research exclusions:

```text
Control-Plane-V3/design-slice-2a-backend-process.md
Reflections/.cadence.log
_index.json
skill-corpus-holistic-review.md
Reflections/2026-07-15-workspace-seat-control-plane-and-cold-start-boundary.md
layout-render-decomposition.md
sendable-requirement-to-sending-region-isolation-parsing-stack.md
```

## Exact RepoTraffic recensus

Both checkpoints were exported from Git objects into temporary directories. `swift package
dump-package` ran only against those immutable exports; imports were scanned only for manifest-active
targets, and Foundation, Testing, and the single unchanged SwiftUI platform edge were excluded from
the non-toolchain/module-graph count. The complete changed-row ledger is
`repotraffic-r2-delta.tsv`.

| Measure | R1 baseline `0a24898` | R2 checkpoint `890c5e6` | Exact delta |
|---|---:|---:|---:|
| Products | 31 | 31 | 0 |
| Source targets | 31 | 31 | 0 |
| Test targets | 14 | 15 | +1 |
| All targets | 45 | 46 | +1 |
| Root package dependencies | 31 | 37 | +6 |
| Declared dependency rows | 497 | 434 | +50 / -113 = -63 |
| Internal edges, all targets | 163 | 162 | +8 / -9 = -1 |
| Internal edges, source targets | 138 | 131 | +1 / -8 = -7 |
| Unique active non-toolchain import edges | 404 | 412 | +10 / -2 = +8 |
| All active import statements | 2,040 | 2,053 | +13 |
| Internal cycles | 0 | 0 | 0 |
| Maximum internal depth, all/source | 11 / 11 | 9 / 9 | -2 / -2 |

The target addition is `WaitingListLive Tests`. Root additions are `postgres-nio`,
`swift-collections`, `swift-emailaddress`, `swift-log`, `swift-nio`, and `swift-svg-render`; there are
no root removals. The six additions are dependency-honesty work, not endorsement of external
engines (`Package.swift:139-162` at `890c5e6`).

The exact internal-edge changes are:

- Added: `Checkout Tests -> Products`; `RepoTrafficRouter Tests -> Account`; the router tests to
  `Analytics`; four restored WaitingListLive-test edges to `RepoTrafficRouter`,
  `RepoTrafficRouterLive`, `WaitingList`, and `WaitingListLive`; and
  `com_repotraffic_app -> GrowthLive`.
- Removed: `AccessControl -> Billing`; three `AccountLive` edges to `BillingLive`, `Growth`, and
  `GrowthLive`; `Analytics -> RepoTrafficUI`; `Growth -> Billing`; `Products Tests -> ProductsLive`;
  and `Syncing -> Cache`.

The exact active non-toolchain import changes are one source seam, one root cleanup, and restored
test activation:

- `Account`: `GitHub` removed; `GitHub_Repositories_Types` added. This is the proven interface-purity
  canary, with public signature text and the full suite unchanged
  (`Assessment/2026-07-16-hardening-report.md:14`).
- `com_repotraffic_app`: unused `ConsoleKit` removed.
- `WaitingListLive Tests`: nine non-toolchain modules become active with the restored test target.
  Together with Account's new type-only import, this produces the exact +10 active-import delta.

Therefore the reduced depth is primarily stale-row and coupling cleanup, not evidence that the R1
semantic decomposition has landed. The new longest source path is:

```text
com_repotraffic_app -> RepositoriesLive -> SyncingLive -> AccountLive -> Syncing
  -> RepoTrafficRecords -> Account -> Billing -> Pricing -> Products
```

R1's proposed graph remains a historical ledger of **70 nodes / 186 edges**. The R2 executable
projection is **69 nodes / 181 edges** because the C2 condition is now mechanically resolved:
committed Analytics owns cache-key/invalidation definitions but has no cache materialization
read/write call, so conditional `RTAnalyticsCache` and its five incident edges are omitted. This is
not permission to rewrite the R1 graph or auto-dispose its open asks.

## Ask A end-state adjudication

| Ask | Recommended end state | Committed evidence | Migration boundary | Compatibility implication | Principal choice still required |
|---|---|---|---|---|---|
| Root engines vs L4 quarantine | Roots import logical L4 integration products and own L5 wiring; Vapor, PostgresNIO, SwiftNIO, Redis/Queues, and bridge products are transitional only. | Six runtime-linkage anchors remain intentionally unimported (`hardening-report.md:23`); direct `swift-log`/`swift-nio`/`postgres-nio` rows have named removal owners (`Package.swift:139-150`). | Do not remove engines before focused successors and boot/release-closure canaries. Preserve current rows meanwhile; never widen engine imports. | Root package rows and boot construction change wave-by-wave; route/domain APIs should remain stable behind adapters. | Ratify quarantine as the controlling end state. Boot-canary authorization is a separate execution action, not part of this policy choice. |
| `X`/`XLive` vs semantic joins | Retain a coherent interface target where it has independent law; replace `Live` as a universal boundary with named provider/persistence/transport joins. | The exact manifest has **13**, not 12, syntactic pairs: 12 domain pairs plus `RepoTrafficRouter`/`RepoTrafficRouterLive`. Only three Live-to-Live source edges remain at 890. Account purity succeeded; Analytics and Billing have much broader lattices (`hardening-report.md:14`). | Split one domain at a time after contract tests. Keep an aggregate compatibility product for one migration wave where downstream import churn would otherwise be atomic. | Imports and dependency keys can remain temporarily re-exported; remove the aggregate only after all consumers name semantic joins. | Choose semantic joins as the rule, or explicitly preserve pair topology. |
| Horizontal `RepoTrafficRecords` vs domain SQL | Tables/migrations belong to domain schema targets; queries and transactions belong to dedicated domain SQL integrations. No horizontal records umbrella. | `RepoTrafficRecords` is consumed by 14 source targets and depends on Account, Cache, and Repositories: breadth without one domain theory. Hardening removed 112 stale rows but did not dissolve this semantic coupling. | Introduce one schema/SQL owner at a time; expand/backfill; shadow reads; single-authority writes; then a temporary compatibility facade until all imports retire. | Database names and transaction semantics must remain stable through the facade; rollback restores the old reader/writer, not duplicate authorities. | Ratify domain-owned persistence and exact transaction ownership before W2 persistence work. |
| `WaitingListRemote` retention | Do not extract, deploy, or treat it as default. Retain dormant only if product owners affirm a remote route contract and real deployment consumer. | It has zero committed source consumers at 890; only its own tests depend on it. The future Institute HTTP client is deliberately deferred (`target-package-and-layer-architecture.md:133-136`). | First prove `/signup` vs `/api/signup`, caller, auth/error semantics, and deployment. Otherwise remove in a bounded product cleanup after caller-negative verification. | Removal is source/API breaking only for presently unobserved external consumers; a release-note/deprecation check is still required. | Affirm the product need or authorize retirement; architecture cannot infer it. |

## ServerFoundation dissolution

The committed demand census finds 25 source files and one test file importing plain
`ServerFoundation`, 29 source files and one test importing `ServerFoundationVapor`, and seven source
files importing `ServerFoundationEnvVars`. The grab-bag itself exposes four local utilities and 13
re-exported concerns (`hardening-report.md:39-53`). Import counts prove demand, not correct package
placement.

| Classification | Exact R2 disposition |
|---|---|
| Imports proven dead by committed evidence | **None** among the remaining plain `ServerFoundation` imports. Zero distinctive tokens are insufficient under MemberImportVisibility; the receipt's two negative controls prove this. `ConsoleKit` is the separate import proven dead and already removed. |
| Imports requiring compile probes | All seven Analytics imports and Billing's one import first. Four token-free root files also require import-drop compilation followed by the two-executable boot canary; root conformance/linkage cannot be settled by text. |
| Focused existing successors | `swift-environment` and `swift-environment-dependencies` for environment values/dependency keys; `swift-urlrequest-handler` for current outbound URLRequest behavior; direct `swift-log`; `swift-logging-extras` where its behavior is genuinely required; existing focused Crypto/JWT/password/throttling packages. These are successor candidates, not blanket purity claims. |
| Existing successor defects | `Environment Dependencies`, URLRequestHandler, and LoggingExtras currently expose/import Foundation in main targets. They need core/explicit Foundation-integration separation before they are canonical final destinations. |
| Missing successor capabilities | An honestly isolated Foundation leaf for dotenv/file/projectRoot behavior; Foundation-free outbound HTTP client/request handler; logging sinks/integrations if direct `swift-log` is insufficient; native Server HTTP/routing/HTML/static policy; native DNS/TLS/PostgreSQL; disposition for MainEventLoopGroup and URL canonical helpers. Process-only environment reading itself can remain in core through `Environment.read.all()`. |
| Temporary direct external dependencies | `swift-log` on six Live targets; `NIOCore`/`NIOPosix` on CacheLive; `PostgresNIO` on the app root; Vapor/ServerFoundation bridge products; current Redis/Queues family. Keep explicit with removal owners and no widening. |

`WaitingListRemote` supplies the clearest measured plain-grab-bag demand: URLRequestHandler and
EnvVars. The two roots use EnvVars/Logger/JWT. Analytics and Billing are the first compile-probe
candidates, but no R2 conclusion labels those imports dead without the gate.

## R1 decisions and 38 lateral edges

Only the five required classifications are used below.

| R1 decision/condition | R2 classification | R2 disposition |
|---|---|---|
| Semantic joins vs `XLive` pairs | recommendation ready for Principal | Select semantic joins with temporary compatibility aggregates; exact manifest count is 13 pairs. |
| All 38 lateral edges | blocked on canonical layer/lateral-edge policy | Use the per-edge amended ledger; no edge is silently approved. |
| Records ownership | recommendation ready for Principal | Select domain-owned schema/SQL with controlled compatibility migration. |
| Root engine quarantine | recommendation ready for Principal | Select L4 logical integrations as the final root boundary; current external engines remain transitional. |
| Working L3 seams and repository creation | blocked on canonical layer/lateral-edge policy | Ratify/merge/re-layer domain clusters before repository creation. |
| Identifier-only `RTIdentifiers` | blocked on runtime/compile probe | Run IDV1 to prove one cohesive identifier concern; otherwise keep narrower owners. |
| Money/currency/decimal vocabulary | recommendation ready for Principal | Choose a narrow existing/explicit vocabulary before Pricing/Catalog/Subscription; do not create a generic billing umbrella. |
| Credential Crypto mechanism | recommendation ready for Principal | Use a vetted provider behind a bounded integration and resolve the Apple/Institute identity collision before extraction. |
| Provider-neutral Subscription identifiers | recommendation ready for Principal | Neutral types may name subject/catalog identifiers, never Identity, RepoTraffic tier, or Stripe identifiers. |
| Cache package ownership collision | superseded candidate | Do not evolve a generic cache package now; canary existing bounded-memory behavior and keep product TTL/key policy high. |
| CacheRefresh disposition | blocked on runtime/compile probe | Prove marker columns, scheduled side effects, worker count, and scale before delete/replace. |
| Identity Standalone / service posture | blocked on runtime/compile probe | Run parity and Standalone gates; keep identity an in-process package. No service rent is proven. |
| L4 physical home | recommendation ready for Principal | Adopt Components/L4 for cross-domain/provider integrations, following committed networking precedent. Exact names remain a decision. |
| Checkout and WaitingList promotion | blocked on runtime/compile probe | Run CO1/WL1; restored tests improve evidence but do not prove independent package rent. |
| MessageDelivery outbox | superseded candidate | Keep inbox/receipt atomicity only; no durable generic outbox consumer is proven. Never auto-create it. |
| Conditional `RTAnalyticsCache` | mechanically resolved | Omit at 890: no committed Analytics materialization read/write call. R2 projection becomes 69 nodes/181 edges. |

The amended `lateral-edge-asks.tsv` classifies every one of the 38 rows:

| Classification | Count | Exact set |
|---|---:|---|
| mechanically resolved | 0 | none |
| recommendation ready for Principal | 0 | none; these are edge-level rows, not the aggregate placement policy |
| blocked on runtime/compile probe | 4 | IdentityMailgun; CheckoutStripe; WaitingListSQL; WaitingListMailgun |
| blocked on canonical layer/lateral-edge policy | 3 | Catalog→Pricing; Subscription→Catalog; IdentityContract→IdentityCore |
| superseded candidate | 31 | 29 R1 L3 integration rows now candidate L4 placements; two WaitingListRemote rows lack consumer/client proof |

“Superseded candidate” is never automatic disposition. It means the R1 edge should not enter the
executable R2 graph without replacement review.

## Networking reconciliation and removal sequence

Pure Institute Networking is design evidence only. It authorizes no implementation here. Its
package graph places all domain/provider bridges at L4 specifically to avoid unratified L3 peer
edges (`target-package-and-layer-architecture.md:144-162,215-225`).

| External exposure | Proposed eventual Institute boundary | Required sequence and canary |
|---|---|---|
| Vapor and ServerFoundationVapor | `swift-http` plus `swift-server-http`, `swift-url-routing-http`, `swift-html-http`, `swift-http-sockets`, `swift-http-file-system`, focused HTTP policies | Socket factories → incremental HTTP/1 server → policy/static integrations → both executables. Offline replay, idempotent shadow traffic, then the Wave-0-proven separate-app or whole-release canary. |
| PostgresNIO / Server PostgreSQL | PostgreSQL wire law, `swift-postgresql`, `swift-postgresql-sockets`, TLS/crypto joins, `swift-sql-postgres`, `swift-records-sql` | Socket/system-resolution + TLS/SCRAM → native client/pool → shadow reads → read-only cohort → single-authority writes/migrations. |
| SwiftNIO | `swift-io` + `swift-sockets`, with HTTP and PostgreSQL using injected transports | Removal waits for both HTTP and PostgreSQL paths plus Redis/Queues and ServerFoundation retirement. Transport echo/proxy and cancellation/resource gates precede product traffic. |
| Async HTTP / URLSession-based SaaS clients | Deferred `swift-http` client plus explicit DNS/socket/TLS composition | Not part of initial inbound Vapor cutover. Start only with a named outbound consumer and interoperability contract. |

RepoTraffic has landed only part of networking Wave 0: a durable lock and census receipt. It still
needs target-aware selected-product closure, executable-specific release closure, and a real canary
topology before an engine migration. Networking's critical paths remain unchanged
(`migration-waves.md:156-171`).

## Dependency-ordered next work

### Immediate bounded batch — `ENV-R2-1`

**Objective:** create a valid focused environment successor without breaking current consumers in
the extraction commit or carrying Foundation-defined behavior into the new core.

- Start: clean `swift-environment-dependencies` commit
  `7651367d1e2b75091928a076cb5e072e8650cf49`.
- Exclusive edit zone: that repository's `Package.swift`, existing
  `Sources/Environment Dependencies/**`, new `Sources/Environment Dependencies Core/**`, new
  `Sources/Environment Dependencies Foundation Integration/**`, and corresponding package tests
  and a consumer compile fixture.
- Additive three-target boundary:
  - `Environment Dependencies Core` owns the `EnvVars` dictionary, errors, Foundation-free scalar
    accessors, process-only `live()` implemented through `Environment.read.all()`, the `EnvVars`
    dependency key, and `Dependency.Values.envVars`.
  - `Environment Dependencies Foundation Integration` depends on Core and alone owns
    `Foundation.URL`, `Data`/file reads, project-root URL derivation, environment-file selection,
    and dotenv overlay. Core has no reverse edge.
  - the existing `Environment Dependencies` target/product remains temporarily as a deprecated
    compatibility wrapper re-exporting Core and the leaf. It contains no behavior. It is recorded
    as pre-existing migration debt under `[ARCH-LAYER-013]`, not a canonical final target and not a
    precedent for new wrappers. Every new consumer selects Core or Foundation Integration directly.
- `EnvVars.allowedInsecureHosts` is not automatically “scalar.” Preserve its exact comma-split and
  whitespace-trim semantics with a Foundation-free implementation and parity tests in Core; if
  exact parity cannot be shown, move the whole accessor honestly to the leaf.
- `EnvVars.TestSupport.swift` has an apparently unused `import Foundation`. The batch must prove it
  unused through compilation, remove it, and keep the Foundation-free fixtures with Core; it may
  not ride the compatibility wrapper unnoticed.
- Compatibility: a fixture importing only the existing `Environment Dependencies` product must
  compile the current public `EnvVars`, URL/live-file, and `projectRoot` call shapes. The extraction
  commit adds deprecation/migration guidance and records a complete repository-consumer census, but
  performs no consumer migration. Wrapper retirement is permitted only after every repository
  consumer has migrated to explicit Core/leaf products, the graph proves no reverse/Core-to-leaf
  edge, the compatibility compile fixture remains green, and the legacy product has zero selected-
  product consumers. Facade removal is a separate, versioned breaking release.
- Acceptance: `swift build`; `swift test`; canonical package/modularization naming validation;
  core←leaf dependency direction; source and symbol/public-API inspection proving no direct,
  re-exported, typealiased, or signature-level Foundation-defined API in Core; exact
  `allowedInsecureHosts` parity; process-only `Environment.read.all()` and dependency-key tests;
  leaf URL/file/projectRoot/dotenv tests; and the legacy consumer compile fixture. An import-text
  grep alone is not sufficient.
- Exclusions: no RepoTraffic, ServerFoundation, networking, Control Plane, lockfile, deployment, or
  consumer edits in this batch. The census is read-only; repointing consumers is a later,
  separately owned batch.
- Concurrency safety: the pinned package is clean and outside all listed concurrent edit zones.
  If its status changes before start, stop and re-establish a clean worktree rather than absorbing
  live changes.

This batch needs no new Principal policy: the Foundation boundary and focused-package dissolution
are already canonical. It yields a landed reusable substrate improvement even while Ask A remains
open.

### Work after `ENV-R2-1`

1. **RepoTraffic W1 probes:** in a dedicated clean RepoTraffic worktree, and only after its current
   owner releases overlapping Analytics/Billing paths, run import-drop compile probes for the eight
   ServerFoundation candidates. Commit only proven deletions. Separately run the two-root linkage
   boot canary; do not conflate compilation with runtime conformance discovery.
2. **Decisions before W2:** Principal rules the four Ask A rows, three same-layer domain edges, L4
   physical topology, money/identifier vocabulary, and crypto provider identity. No W2 package
   creation precedes these.
3. **Focused extraction/creation:** repoint EnvVars consumers after `ENV-R2-1`; then address an
   outbound HTTP successor only with a named consumer. Keep ServerFoundationVapor until native HTTP
   integrations land. Do not create generic umbrellas.
4. **Networking:** complete Wave 0 closure/canary evidence; run Wave 1B experiments; then follow
   sockets → HTTP → Server cutover and sockets/resolution → TLS → PostgreSQL → SQL/Records.
5. **Service-rent gates:** revisit deployment only after independent scaling, failure-isolation,
   ownership, security, and operational evidence. Identity, WaitingListRemote, billing, jobs, and
   message delivery remain in-process by default.
6. **Control Plane reuse:** consume future Foundation-free environment, HTTP/Server, SQL/PostgreSQL,
   scheduler, identity-contract, and provider integrations. Keep its authorization kernel, event
   billing projection, and store product-specific. Its committed dashboard reference to
   `swift-server-foundation` requires later owner revalidation; R2 does not edit it. The current
   prototype already proves no Vapor/NIO/PostgresNIO dependency, so migration machinery must not be
   imported merely for symmetry.

## Principal decision packet, ordered by blocking power

The smallest current decision set is three bundles. Probe-gated candidates are deliberately not
escalated as policy questions yet.

1. **RepoTraffic end-state seams — blocks W2.** Decide the four Ask A rows independently:
   L4 root engine quarantine; semantic joins instead of universal `XLive`; domain-owned SQL instead
   of horizontal records; and retain-vs-retire `WaitingListRemote`. R2 recommends yes/yes/yes and
   retire-unless-product-proof.
2. **Layer authority — blocks every proposed package edge/repository.** Ratify L4 Components as the
   default home for cross-domain/provider integrations. For the three remaining L3 domain-peer
   edges, select merge, re-layer, or exact cluster authorization. Do not blanket-authorize all 38.
3. **Foundational vocabulary/provider choices — blocks only affected seams.** Select the
   money/currency/decimal vocabulary, provider-neutral subscription identifier law, and the vetted
   crypto/X.509 provider strategy including the Apple/Institute SwiftPM identity collision.

No Principal decision is needed for `ENV-R2-1`. Future credentialed Mailgun, application-boot,
deployment, or Heroku actions remain separate explicit authorizations; none is performed by R2.

## Checks and review state

Completed before authoring:

- immutable `dump-package` recensus at `0a24898` and `890c5e6`;
- exact target, product, root dependency, declared-row, active-import, internal-edge, cycle, and
  longest-path comparisons;
- exact 13-pair `X`/`XLive`, `RepoTrafficRecords` consumer, `WaitingListRemote` consumer, and
  ServerFoundation import-demand reconciliations;
- committed networking and Control Plane evidence review;
- dirty ownership/exclusion verification without reading excluded uncommitted content.

No live package build was appropriate: R2 is commit-pinned and prohibited from mutating package
worktrees. A fresh independent architecture review must verify arithmetic, all 38 classifications,
the policy/probe separation, the immediate batch's safety, and the no-umbrella/no-service conclusion
before the R2 Research commit.

## References

- [R2 exact delta](repotraffic-r2-delta.tsv)
- [R2 lateral-edge ledger](lateral-edge-asks.tsv)
- [R1 provenance and architecture](provenance-and-architecture.md)
- [R1 extraction and canary plan](extraction-and-canary-plan.md)
- [R1 independent review](independent-review-record.md)
- [Pure Institute Networking target architecture](../Pure-Institute-Networking/target-package-and-layer-architecture.md)
- [Pure Institute Networking migration waves](../Pure-Institute-Networking/migration-waves.md)
