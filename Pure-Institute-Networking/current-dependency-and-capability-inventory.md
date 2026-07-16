# Current dependency and capability inventory

## Executive census

The root contains 346 production Swift files and 19 test Swift files. The controlled production import census is:

| Module | Live imports | Meaning |
|---|---:|---|
| `Vapor` | 48 repo-wide | 32 on the app path and 16 in the marketing executable; one additional commented import is excluded |
| `ServerFoundationVapor` | 29 | Direct Institute-to-Vapor bridge use |
| `HTML_Vapor` | 2 | Direct HTML response bridge use |
| `PostgresNIO` | 1 | Load-bearing defining-module visibility for the Records configuration alias; operational use is through Records |
| `PostgreSQL_Standard` | 1 | Record/table DSL visibility |
| `NIOCore` | 1 | Redis cache adapter |
| `NIOPosix` | 1 | Redis cache adapter |
| `Queues` | 4 | Job declarations/registration |
| `QueuesRedisDriver` | 1 | Queue configuration |
| `RediStack` | 1 | Attributed import in cache adapter |
| `AsyncHTTPClient` | 0 | Still active transitively through Vapor's production target |

The only relevant test import is `ServerFoundationVapor` in `Tests/WaitingListLive Tests/WaitingListLiveTests.swift:17`. Its test target is commented out at frozen-snapshot `Package.swift:949-965`, so it is dormant source rather than an active target.

All RepoTraffic line-number references in this inventory identify the frozen `0a2489838e515405562c417a10647691442f9d20` source/manifest snapshot. Later owner commits `c4814e35...` and `e9aaa45d...` shifted line numbers and pruned stale target rows without changing the forbidden lock pins at the last lock recheck. Commit `51e70c17...` subsequently restored a test suite only; the ignored lockfile was absent at that final sample, so no newer lock claim is made.

## Root production product origins

At the frozen launch snapshot, RepoTraffic declares Queues, Queues Redis driver, and RediStack directly at `Package.swift:139-141`; HTML Vapor at line 148; Swift Server, PostgreSQL Standard, Server Foundation, Server Foundation Vapor, and Records at lines 158-162.

Selected production edges include:

- `HTML Vapor` on both executables (`Package.swift:195`, `:240`).
- `ServerFoundation` on five production targets (`:190`, `:279`, `:451`, `:502`, `:935`). This is an independent SwiftNIO origin: its production target selects `NIOCore`, `NIOEmbedded`, and `NIOPosix` at `/Users/coen/Developer/swift-foundations/swift-server-foundation/Package.swift:65,81-83`.
- `ServerFoundationVapor` on app, AnalyticsLive, Billing, BillingLive, CheckoutLive, PricingLive, and WaitingListLive (`Package.swift:203,475,500,532,607,726,916`).
- `PostgreSQL Standard` plus `Server PostgreSQL` on 15 production targets at frozen `Package.swift:274-275,360-361,389-390,431-432,484-485,508-509,551-552,623-624,672-673,757-758,789-790,809-810,829-830,878-879,921-922`.
- Queues and QueuesRedisDriver on the application at `Package.swift:276-277`.
- RediStack on CacheLive at `Package.swift:582`.

The frozen snapshot's 15 `Server PostgreSQL` declarations do not correspond to source imports: RepoTraffic source has no `Server_PostgreSQL`, `SQL`, `SQL_Postgres`, or `Migrations` import. Commit `e9aaa45d...` subsequently pruned 14 of those rows, validating the stale classification while leaving one selected app path. The final edge is removable only after the Records path has a native engine and a product-specific release graph proves it unnecessary.

## Exact resolved runtime family snapshot

| Identity | Version | Revision |
|---|---:|---|
| async-http-client | 1.35.0 | `4603a8036d921ea999fadb742931546c341f4bd7` |
| async-kit | 1.22.0 | `6bbb83cbf9d886623a967a965c8fb1b73e6566f9` |
| console-kit | 4.16.0 | `32ad16dfc7677b927b225595ed18f3debb32f577` |
| multipart-kit | 4.7.1 | `3498e60218e6003894ff95192d756e238c01f44e` |
| postgres-nio | 1.33.0 | `f2188e05ba3546a76e61a5193c071b82c4d69a45` |
| queues | 1.18.0 | `4fa1ef91821fee04cce1982ba053ab37b88abfb9` |
| queues-redis-driver | 1.1.2 | `a3dac0d311cead67917ad4221feb061e3609b145` |
| redis (Vapor) | 4.14.0 | `bc960cc856ef9fd5da760d6a3afedb93fc92aa00` |
| RediStack | 1.6.3 | `8c4ce10883e405cdbde52855f97f1ec9468c889b` |
| routing-kit | 4.9.3 | `1a10ccea61e4248effd23b6e814999ce7bdf0ee0` |
| swift-nio | 2.101.3 | `0b18836bd8b0162e7e17a995a3fbee20ed8f3b2b` |
| swift-nio-extras | 1.34.3 | `88a51340f59cf181ebde888bd1b749296b3ec029` |
| swift-nio-http2 | 1.44.0 | `61d1b44f6e4e118792be1cff88ee2bc0267c6f9a` |
| swift-nio-ssl | 2.37.2 | `d930168b86f46ca51a4bc09c5ca45c1833db8067` |
| swift-nio-transport-services | 1.28.0 | `67787bb645a5e67d2edcdfbe48a216cc549222d5` |
| Vapor | 4.122.0 | `748ae8432a33e0965bbf0351fedd4e915e7f460c` |
| WebSocketKit | 2.16.2 | `90bbbdab3ede12c803cfbe91646f291c092517a3` |

Immediate supporting products selected by Vapor/AHC/PostgresNIO are also part of the measured product path even when they are not fixed removal targets:

| Identity | Version | Revision | Disposition class |
|---|---:|---|---|
| swift-algorithms | 1.2.1 | `87e50f483c54e6efd60e885f7f5aa946cee68023` | Reclassify after old parents; retain only for an independent consumer |
| swift-asn1 | 1.7.1 | `a9a5efd40eaf558a2bcd48d64b1d1646be686008` | X.509 provider support; provider decision |
| swift-atomics | 1.3.1 | `0442cb5a3f98ab802acb777929fdb446bda11a34` | Reclassify after old parents; not itself a networking engine |
| swift-certificates (Apple) | 1.19.3 | `89fbc3714264cce8db8e4ec51b64e01c3e28c6c5` | Possible vetted X.509 provider; identity collision with Institute reservation |
| swift-collections | 1.6.0 | `a0cb0954ecb21e4e31b0070e6ed5674e8556685a` | Postgres pool/support; reclassify after native pool |
| swift-configuration | 1.2.0 | `be76c4ad929eb6c4bcaf3351799f2adf9e6848a9` | AHC support; remove with AHC absent independent use |
| swift-crypto (Apple) | 4.5.0 | `1b6b2e274e85105bfa155183145a1dcfd63331f1` | Direct root dependency and candidate TLS/SCRAM provider; Principal decision |
| swift-distributed-tracing | 1.4.1 | `dc4030184203ffafbb2ec614352487235d747fe0` | Observability support; explicit retain/replace decision |
| swift-log | 1.14.0 | `a878e7f8f46cfc0e1125e565b5c08e7d5272dc9a` | Direct application logging after hardening; not silently removed with Vapor |
| swift-metrics | 2.11.0 | `087e8074afa97040c3b870c8664fe5482fb87cc4` | Observability support; explicit retain/replace decision |
| swift-service-context | 1.3.0 | `d0997351b0c7779017f88e7a93bc30a1878d7f29` | Context propagation; explicit retain/replace decision |
| swift-service-lifecycle | 2.11.0 | `9829955b385e5bb88128b73f1b8389e9b9c3191a` | Postgres lifecycle support; native structured lifecycle replaces this path |

This is the exact local lock snapshot, not the deployed closure. `Dockerfile:12` deletes `Package.resolved`, deletes `.build`, and runs `swift package update` before the release build at line 17. A production build can therefore resolve revisions newer than every SHA above.

## Proven package paths

The following paths are proven from selected root products and exact resolved checkout manifests. “Selected” means a production-product edge; it does not mean RepoTraffic invokes every exposed API.

### Vapor and its active server family

```text
RepoTraffic executable
  -> Boiler
     -> ServerFoundationVapor -> Vapor
     -> URLRoutingVapor       -> Vapor
     -> Queues                -> Vapor
  -> HTML Vapor               -> Vapor
  -> ServerFoundationVapor    -> Vapor
  -> Server                   -> Vapor
  -> Queues                   -> Vapor
  -> QueuesRedisDriver        -> Vapor + Vapor Redis
```

Vapor's production target in turn selects the forbidden-family subset AsyncHTTPClient, AsyncKit, ConsoleKit, RoutingKit, NIO, NIOSSL, NIOHTTP2, NIOExtras, WebSocketKit, and MultipartKit. It also selects supporting Logging/Metrics/Tracing/ServiceContext, Crypto, Algorithms, Atomics, `_NIOFileSystem`, X509, and ASN.1 products. Therefore zero direct AsyncHTTPClient/WebSocket/HTTP2/multipart source use does not make those pins stale, and removal planning must classify rather than silently omit the supporting closure.

### PostgreSQL

```text
RepoTraffic -> Records -> PostgresNIO
RepoTraffic -> Server PostgreSQL -> PostgresNIO + NIOSSL
RepoTraffic -> PostgreSQL Standard --test-validation only--> PostgresNIO
```

The Records path is the actual runtime abstraction used by approximately 70 source imports. `Server PostgreSQL` has root product edges but no live source import; it is still a selected production product until the manifest is corrected. PostgreSQL Standard's PostgresNIO edge is conditional test support and should not be called a production engine.

PostgresNIO selects SwiftNIO, NIOSSL, and the NIOTransportServices product unconditionally in its target graph. NIOTransportServices' Network.framework implementation is Apple-platform-specific and is not the Linux socket backend; AsyncHTTPClient adds a separate Apple-conditional route to the same product.

### Direct SwiftNIO origins independent of Vapor

```text
RepoTraffic -> ServerFoundation -> NIOCore + NIOEmbedded + NIOPosix
RepoTraffic -> RediStack        -> NIOCore + NIOPosix + NIOSSL
RepoTraffic -> Server PostgreSQL -> PostgresNIO -> NIO family
```

Removing Vapor alone therefore cannot remove SwiftNIO.

### Queues and Redis

```text
RepoTraffic -> Queues -> Vapor + NIO
RepoTraffic -> QueuesRedisDriver -> Queues + Vapor Redis
RepoTraffic -> RediStack -> NIO + NIOSSL
Vapor Redis -> Vapor + RediStack
```

The root also selects RediStack directly for CacheLive.

## Consumed behavior

### Inbound HTTP/server

The product uses Vapor for:

- application configuration, public-directory generation, 10 MiB app and 1 MiB marketing body limits, middleware, command registration, and server lifecycle (`Sources/com_repotraffic_app/Vapor.Application.configure.swift:28-100`; `Sources/com_repotraffic/Vapor.Application.configure.swift:13-33`; `Application.swift:281-363`);
- route dispatch, `AsyncResponseEncodable`, typed status, headers, redirect, raw response construction, JSON request decoding, and JSON/CSV response bodies (`Route.response.swift:45-224`; `Repository.Traffic.API.response.swift:145-190`; `WaitingList.API.response.swift:39-64`);
- cookie parsing/writing and request authentication middleware (`CookieSessionAuthenticator.swift:35-94`; `CookieSession.swift:52-113`);
- ConsoleKit command registration (`Migrate.Command.swift:23-40`);
- HTML-to-response bridges;
- Boiler's default CORS, error, request-timing, and file middleware, plus configured host/canonical/HTTPS redirect policy; and
- Vapor's selected static-file path: streamed file chunks, MIME/content type, ETag/304, Last-Modified, single byte Range/206, and directory redirect behavior (`boiler` `Boiler.execute.swift:174-178,192-224`; `Boiler.Middleware.swift:27-34`; Vapor `FileMiddleware.swift:60-114`; `FileIO.swift:485-590`).

No live code proves WebSocket, HTTP/2, multipart, or response-compression configuration. Streaming **is** live through default static-file middleware, while Heroku also streams request bodies and applies response backpressure above 1 MiB. The native engine and file integration must therefore preserve bounded streaming; collected-body convenience is allowed only behind the existing explicit limits.

The middleware parity has security content, not just API shape. Vapor's default CORS reflects the request Origin, handles OPTIONS preflight, allows GET/POST/PUT/OPTIONS/DELETE/PATCH plus its fixed header set, emits `Vary: origin`, and defaults credentials off. The HTTPS middleware trusts `X-Forwarded-Proto`, redirects otherwise, and on HTTPS adds one-year `includeSubDomains; preload` HSTS. Host validation rejects missing/unapproved Host; canonical-host middleware redirects. Native cutover must either reproduce each configured behavior or document an intentional hardening—especially which Heroku-forwarded headers are trusted.

### Outbound HTTP

RepoTraffic has no direct AsyncHTTPClient use. SaaS API clients are Institute packages and Foundation `URLSession`/`URLRequest` surfaces; one direct call is `Sources/Syncing/Syncing.swift:142-149`. The native outbound HTTP client is therefore not a prerequisite for the first Vapor server cutover. It is required before AsyncHTTPClient can leave Vapor's transitive closure and before “Institute networking” can replace Foundation networking by policy, if the Principal chooses that broader end state.

### PostgreSQL

The single direct PostgresNIO import is `Sources/com_repotraffic_app/Vapor.Application.configure.swift:1` in the frozen snapshot. It is load-bearing even though the file spells no `Postgres*` type: Records declares `Database.Configuration` as a public alias of `PostgresClient.Configuration`, and the application mutates that defining module's `.options` and `.tls` members. A concurrent hardening gate confirmed that deleting the import produces member-visibility failures and then declared the direct package/product edge explicitly. Runtime requirements are therefore concrete:

- environment connection configuration;
- 30-second connect timeout;
- pool minimum 5, maximum 20, and 60-second idle timeout;
- `statement_timeout`, transaction-idle timeout, lock timeout, and application-name startup parameters;
- production TLS with NIOSSL's full-verification client default;
- migration of Identity and RepoTraffic schemas; and
- Records reads, writes, transactions, JSONB, arrays/decimals used by dependent packages, and typed record decoding.

The boot path is `Vapor.Application.configure.swift:208-247`. `Database.Configuration` is publicly a PostgresNIO configuration alias and `ClientRunner` owns `PostgresClient`, so the engine boundary leaks through Records even when RepoTraffic source does not spell its types.

### Jobs

RepoTraffic registers two queue job types (`AutoTrackAllReposJob` and `GitHubPollingJob`) and schedules `GitHubPollingJob` plus `CacheRefreshJob`. The declared production worker command is `com_repotraffic_app queues --scheduled` (`Procfile:2`); local configuration does not prove that any Heroku worker dyno is currently scaled, so live count is a Wave-0 confirmation. The Queues command's scheduled-only branch drives scheduled jobs directly from timer callbacks rather than pushing/popping Redis jobs. The source tree contains no queue-dispatch call site, so both manual registrations are dormant.

This proves the product currently needs recurring execution, job registration, lifecycle, logging, and failure handling. It does **not** prove demand for a durable on-demand queue, Redis lease semantics, retries, or dead-letter storage. Those capabilities remain future policy, not cutover scope.

### Cache/Redis

`Cache.Store+Redis.swift:68-373` implements a broad Redis adapter—connection/event-loop ownership, GET/SET/DEL/SCAN/EXISTS/TTL/DBSIZE/INFO and RESP/ByteBuffer conversion. Live cache consumption is much narrower: two five-minute `cache.store.getOrSet` calls cache decrypted GitHub tokens. The existing CacheLive package already has an actor-based memory LRU with TTL, invalidation, stats, and a production no-op option.

The cache is a performance layer, not authoritative data. A memory-only canary can therefore remove RediStack without inventing a Redis replacement, provided correctness, decrypt cost, database load, hit rate, and multi-dyno stale-value behavior pass the stated gate.

## Deployment and operational contract

- `Procfile:1` declares `com_repotraffic_app serve --hostname 0.0.0.0 --port $PORT`; line 2 declares the scheduled worker command. Live dyno formation/scale is not proven locally.
- `Dockerfile:1,19` uses Swift 6.3.3 Jammy for build/runtime and builds the release executable at line 17.
- Heroku terminates inbound TLS and HTTP/2 at the router, forwarding HTTP/1.1 to the dyno. The server must still handle concurrent keep-alive connections, streamed request bodies, chunking, and slow clients.
- Heroku recommends a server idle timeout of at least 90 seconds to avoid a keep-alive close race, requires `$PORT` binding within 60 seconds, requires initial response data within 30 seconds, and gives a dyno 30 seconds after SIGTERM before forced exit.
- RepoTraffic's final release proof must run in the exact Linux container and cannot rely only on macOS tests.

## Immediate defects exposed by the audit

1. **Unpinned deployment resolution**: `.gitignore:5` ignores `Package.resolved`, and Dockerfile deletes it before `swift package update`; status cannot expose drift and deployment can change the forbidden closure without source change.
2. **Hidden import visibility**: RepoTraffic compiles imports for packages it does not declare directly. The target graph must make ownership explicit.
3. **Selected-but-unused products at launch**: 15 `Server PostgreSQL` rows and multiple bridge products enlarged the surface; `e9aaa45d...` pruned 14 of those PostgreSQL rows, but selected compatibility edges remain.
4. **Dissolved compatibility package still live**: `swift-server-foundation` declares itself dissolved but remains selected and directly imports NIO.
5. **Blocking cache bridge**: RediStack code calls future `.wait()`/`.get()` and owns a dedicated event-loop group, crossing structured-concurrency and lifecycle boundaries.
6. **Records transaction mismatch**: the production runner's `write` leases a pooled connection rather than guaranteeing serialization/transactionality; the Records migrator can autocommit DDL and bookkeeping independently.
