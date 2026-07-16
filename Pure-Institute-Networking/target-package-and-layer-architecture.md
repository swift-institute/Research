# Target package, layer, and dependency architecture

## Governing decisions

1. Platform C imports remain exclusive to L2 platform specification packages. Networking foundations consume their typed surfaces; no `Glibc`, `Darwin`, `Musl`, or `WinSDK` import migrates upward.
2. `swift-io` owns reactor/proactor strategy. `swift-sockets` owns socket-specific factories and error policy. HTTP, TLS, and PostgreSQL never reach around either package to syscalls.
3. Protocol law remains L2; connection/session/resource policy is L3; application-server and cross-domain composition is L4/L5.
4. Every cross-package adapter is a dedicated integration package. Core packages do not acquire optional foreign engines.
5. The graph is wide, shallow, and acyclic. Integration packages are leaves relative to their providers; providers never import an integration package.
6. A reservation name does not create an obligation to fill it.

These decisions apply canonical `[PLAT-ARCH-008h]`, `[PLAT-ARCH-008j]`, `[PLAT-ARCH-021]`, `[MOD-014]`, `[MOD-032]`, and `[MOD-041]`. In particular, `swift-sockets` remains a domain L3 unifier instead of turning `swift-kernel` into a networking aggregate.

## Proposed graph

An arrow means “depends on.” Integration packages are shown in brackets.

```text
L5 RepoTraffic executable
  -> [swift-server-http]
  -> [swift-url-routing-http]
  -> [swift-html-http]
  -> [swift-http-sockets]
  -> [swift-http-file-system]
  -> swift-http-cookies
  -> swift-http-cors
  -> swift-http-redirect
  -> swift-scheduler
  -> [swift-records-sql]
  -> [swift-sql-postgres]
  -> [swift-postgresql-sockets]
  -> [swift-postgresql-transport-layer-security]
  -> [swift-postgresql-crypto]
  -> [swift-dns-system]
  -> [swift-transport-layer-security-crypto]
  -> [swift-transport-layer-security-certificates]
  -> [swift-transport-layer-security-sockets]
  -> [swift-certificates-system-trust]

L4 composition/integration
  [swift-server-http] -> swift-server + swift-http
  [swift-url-routing-http] -> swift-url-routing + swift-http-standard
  [swift-html-http] -> swift-html + swift-http
  [swift-http-sockets] -> swift-http + swift-sockets
  [swift-http-file-system]
      -> swift-http + swift-file-system + swift-http-etag + swift-http-range
  [swift-records-sql] -> swift-records + swift-sql
  [swift-sql-postgres] -> swift-sql + swift-postgresql
  [swift-postgresql-sockets] -> swift-postgresql + swift-sockets + swift-dns
  [swift-postgresql-transport-layer-security]
      -> swift-postgresql + swift-transport-layer-security
  [swift-postgresql-crypto]
      -> swift-postgresql + selected crypto/random provider
  [swift-dns-system]
      -> swift-dns + typed platform host-resolution provider
  [swift-transport-layer-security-crypto]
      -> swift-transport-layer-security + selected crypto provider
  [swift-transport-layer-security-certificates]
      -> swift-transport-layer-security + selected X.509 provider
  [swift-transport-layer-security-sockets]
      -> swift-transport-layer-security + swift-sockets
  [swift-certificates-system-trust]
      -> selected X.509 provider + typed platform trust-store provider

L3 domain/runtime
  swift-server -> engine-free responder + middleware + lifecycle vocabulary
  swift-http -> swift-http-standard + swift-io
      (HTTP/1 server connection/body state over injected byte-duplex transport)
  swift-http-cookies/cors/etag/range/redirect -> swift-http-standard
  swift-dns -> provider-neutral host-resolution policy/interface
  swift-transport-layer-security -> RFC 8446 + swift-io
  swift-postgresql -> swift-postgresql-standard + swift-io
      (PostgreSQL session/client/pool over injected transport)
  swift-scheduler -> recurring-time runner (no Redis/backend selector)
  swift-records -> engine-neutral record/query conveniences
  swift-sql -> engine-neutral execution membrane

L3 unifiers
  swift-sockets -> swift-io + swift-kernel + socket/IP standards
  swift-io -> swift-kernel + executor/async primitives

L2 law/specification
  swift-postgresql-standard
      -> PostgreSQL SQL dialect target
      -> PostgreSQL Wire Standard target
  swift-http-standard -> RFC 9110 + RFC 9111 + RFC 9112
  RFC 8446 (+ RFC 6066) -> TLS protocol law and encodings
  RFC 5280 -> certificate/profile/path-validation law
  RFC 1035 -> DNS message law and encodings
  platform L2 -> ISO 9945 / Darwin / Linux / Windows typed syscall law

L1 mechanisms
  Byte + Span family + storage + async bounded channel/semaphore
  IO/executor primitives + clocks + typed errors
```

The diagram names future packages to make responsibilities reviewable; it is not authorization to create them in this generation.

## Package decisions

### Retain/refactor existing packages

| Package | Target role | Exact decision |
|---|---|---|
| `swift-kernel` | Domain-neutral typed kernel substrate | Retain; add IOCP only in correct platform packages, not HTTP/PostgreSQL concepts |
| `swift-io` | Event/completion scheduling | Retain; harden bounded registration/cancellation/fairness |
| `swift-sockets` | Cross-platform socket unifier | Retain; integrate L2 IP/socket vocabulary, add event/completion factories and legal strategy types |
| RFC 9110/9111/9112 | HTTP law | Retain; add incremental exact 9112 framing while preserving whole-message convenience |
| `swift-http-standard` | HTTP standards converger | Retain; no runtime policy |
| RFC 8446 | TLS law/formulas | Retain; add incremental record decoding, not socket/trust policy |
| `swift-url-routing` | URI parser-printer | Retain engine-free core; remove HTTP carrier's RFC 7230/7231/`Data` coupling into integration |
| `swift-server` | Responder/middleware/lifecycle vocabulary | Retain small membrane; remove Vapor, PostgreSQL, jobs, AHC and NIO implementations |
| `swift-postgresql-standard` | PostgreSQL specification encodings | Retain dialect; add separate wire target/product |
| `swift-sql` | Execution membrane | Retain/expand values, cursor, transactions, statement classification |
| `swift-sql-postgres` | Dedicated SQL x PostgreSQL integration | Retain package, replace PostgresNIO adapter with native client |
| `swift-records` | Record/query conveniences | Remove PostgresNIO and public engine leaks; make engine-neutral |
| `swift-sql-migrations` | SQL migration law | Retain and adopt for app/Identity migrations |
| `swift-scheduler` | Recurring-time law and runner | Remove `.redis`; add clock-driven runner, not a queue engine |

### Deliberate packages to fill/create

| Package | Why it exists | What it must not own |
|---|---|---|
| `swift-dns` (new) | Provider-neutral host-resolution policy: names/addresses, deadlines, ordered attempts, deterministic resolver witness | Raw platform C, HTTP, TLS, or an assumption that direct RFC 1035 traffic preserves NSS/search/split-DNS behavior |
| `swift-transport-layer-security` (reserved) | TLS session/record protection/alerts/key lifecycle over an injected duplex transport | Crypto algorithms, certificate store, sockets, HTTP |
| `swift-http` (reserved) | Incremental HTTP/1 server connection and bounded body over byte-duplex I/O; client target later | Routing, application middleware, TLS provider, jobs, database |
| `swift-http-{cookies,cors,etag,range,redirect}` (reserved) | Measured, focused HTTP policies now supplied by Vapor/Boiler | Socket I/O, Server lifecycle, file-system access |
| `swift-postgresql` (new) | PostgreSQL startup/auth/query/session/cancel/pool policy over injected transport and crypto/random witnesses | Crypto algorithms, SQL DSL, Records, SaaS persistence, generic cross-domain pooling |
| dedicated L4 integration packages named in the graph | Cross-package conformances/adapters required by `[MOD-014]`; they exchange core-owned witnesses through L5 and never import one another | New domain law or nested integration dependencies |

### Reservations intentionally left empty for the first cutover

- `swift-http2`, `swift-http3`, and `swift-websocket`: no product use and Heroku forwards HTTP/1.1.
- `swift-http-body`, `swift-http-compression`, and `swift-http-content-negotiation`: body framing stays inside `swift-http` initially; compression/content-negotiation have no measured configuration. By contrast, cookies, CORS, ETag, range, and redirect reservations are required because selected middleware uses them.
- the HTTP client target and DNS connector: not required for inbound Heroku cutover. Implement later only for an explicit outbound-HTTP/URLSession replacement goal.
- a direct RFC 1035 network resolver/cache: the first PostgreSQL connector uses a system host-resolution provider so `/etc/hosts`, NSS, search domains, and split-DNS policy remain intact. Add direct DNS transport only after a separate interoperability decision.
- Institute `swift-crypto` and `swift-certificates` reservations: do not fill them in the provider-backed base route because Apple packages with the same SwiftPM identities are already resolved. Naming/provider ownership must be decided first.
- `swift-redis` and L4 Redis cache/job reservations: no measured cutover need.
- `swift-pool-connections`: PostgreSQL pool lifecycle is engine-specific and has only one proven consumer. Keep it inside `swift-postgresql` as a separate target; extract only after a second client proves the common law.
- generic durable jobs packages: no dispatch consumer exists.

## Dedicated integrations and naming

The package names follow recipient-then-provider semantics:

- `swift-url-routing-http` replaces `swift-url-routing-vapor`.
- `swift-html-http` replaces `swift-html-vapor`.
- `swift-server-http` composes the Server membrane with the HTTP runtime.
- `swift-http-sockets` makes HTTP server listeners/connections from socket transports; it has no DNS dependency.
- `swift-http-file-system` owns bounded static-file streaming plus conditional/range integration over `swift-file-system`.
- `swift-postgresql-sockets` makes PostgreSQL connection transports from DNS/socket providers.
- `swift-transport-layer-security-{crypto,certificates,sockets}` isolate optional provider boundaries.
- `swift-postgresql-transport-layer-security` owns PostgreSQL's SSLRequest-to-TLS upgrade.
- `swift-postgresql-crypto` supplies SCRAM SHA-256/HMAC/PBKDF2 and secure-nonce witnesses without making TLS integration an accidental authentication dependency.
- `swift-dns-system` preserves platform host resolution; a future `swift-dns-rfc-1035` would be a separate provider.
- `swift-certificates-system-trust` supplies system roots to the selected X.509 provider.
- `swift-records-sql` keeps Records conveniences independent of SQL engines.
- existing `swift-sql-postgres` remains the SQL recipient / PostgreSQL provider adapter.

If canonical package naming adjudicates a different provider token, rename before implementation; do not silently repurpose the ambiguous empty `swift-http-routing` reservation.

All bracketed packages in the graph are placed at L4 by default and therefore belong in the Components layer/repository topology, not merely in a sibling Foundations checkout. This is deliberate: an extracted integration package that imports an L3-domain recipient plus another L3 package would otherwise become a new L3-domain peer and require the per-cluster adjudication in `[PLAT-ARCH-008h]`. L4 keeps the dependency direction strictly downward. In particular, existing `swift-sql-postgres` physically lives with Foundations today; its native-client end state requires an explicit layer/repository placement decision and may not silently preserve an L3 domain-to-domain edge.

HTTP cookie/CORS/redirect packages expose policy over HTTP values; they do not vend Server middleware or import Server. RepoTraffic L5 wraps/selects them through the generic `swift-server-http` middleware surface. This uses the `[MOD-014]` L5 composition exception and avoids turning `swift-server-http` into three additional cross-package bridges.

## Internal target boundaries

Packages may use multiple targets when the targets are parts of one release concern and introduce no optional foreign integration.

### `swift-http`

- `HTTP Body`: owned `Byte` chunks, bounded producer/consumer flow, collected convenience with explicit limit.
- `HTTP Connection`: incremental RFC 9112 decoder/encoder state, pipeline ordering, keep-alive, timeout/shutdown.
- `HTTP Server`: connection role/listener-agnostic request dispatch; no application middleware.
- `HTTP Client` (deferred target): request/response connection role and reusable connection policy; no DNS/socket/TLS construction. It is not part of the first Vapor server wave.

Body remains inside this package for the first implementation because it is HTTP framing state shared by HTTP roles; extracting the empty `swift-http-body` reservation would create a lateral dependency before an independent consumer exists.

`swift-html-http` depends on this runtime package, not only `swift-http-standard`, because it must produce the owned/streamed body representation. `swift-http-file-system` is separately responsible for file reads, ETag/range policy application, MIME selection, and backpressured body production; neither HTML nor Server acquires a hidden file-system import.

### `swift-postgresql-standard`

- current SQL dialect/macro targets remain isolated;
- `PostgreSQL Wire Standard` owns message tags, framing, protocol version, OIDs/formats, authentication messages, error fields, and encode/decode law;
- no sockets, TLS, pool, task, or SQL execution policy enters L2.

### `swift-postgresql`

- `PostgreSQL Client`: startup/authentication, ReadyForQuery state, simple/extended query, prepared statement/portal, cancel, errors/notices, shutdown.
- `PostgreSQL Pool`: bounded FIFO leasing, health, idle eviction, reconnect, metrics, structured shutdown.
- `PostgreSQL Test Support`: scripted server/transport and fixtures only, without leaking into production products.

Keeping pool and client targets in one package avoids an unprincipled L3 peer and reflects PostgreSQL-specific reset, health, cancellation, and lifecycle semantics.

## Server/application boundary

`swift-server` must stop being an omnibus engine package. Preserve:

- `Server.Responder` and middleware composition;
- request-scoped dependency installation;
- typed application/lifecycle errors;
- configuration vocabulary that is genuinely server-generic.

Move or remove:

- Vapor boot/execute/shutdown -> retired bridge during migration;
- HTTP request/response duplication -> RFC 9110 + `swift-http` body integration;
- AsyncHTTPClient -> outbound HTTP integration, not server core;
- PostgreSQL -> `swift-sql-postgres`;
- Queues -> `swift-scheduler` runner composed by the L5 executable;
- commands/signals -> L5; static-file behavior -> `swift-http-file-system`; CORS/cookie/redirect/error/timing/forwarded-header middleware -> focused HTTP policy plus `swift-server-http` integration.

`Boiler` is retired rather than taught a second engine. RepoTraffic, as an L5 application, may compose server, scheduler, database, logging, configuration, and signal handling directly.

## Layer and cycle audit

The proposed graph has no upward or reverse provider edge:

- L2 law imports only lower primitives/specifications.
- L3 unifiers compose platform policy/unifier packages, never L3 domains.
- HTTP, TLS, DNS, and PostgreSQL are L3-domain packages; their cores depend on L2 law and generic lower mechanisms, while all domain/provider or domain/domain bridges in this proposal are L4.
- each L4 integration package depends directly on its L3/L2 recipients/providers; neither side imports it, and no integration package imports another integration package;
- L5 owns the only multi-integration composition, passing core-owned transport/provider witnesses between separately selected adapters.

The only proposed cross-domain composition is isolated in dedicated integration packages as required by `[MOD-014]`. `swift-postgresql` does not depend on `swift-sql` or Records; `swift-http` does not depend on Server or URLRouting; TLS does not depend on HTTP/PostgreSQL. Those negative edges are the main cycle guards.

## Crypto/trust decision gate

The recommended first production route is a vetted crypto/X.509 provider behind dedicated Institute integration packages. Apple Swift Crypto is already a direct RepoTraffic dependency and is not one of the fixed forbidden networking families; using it behind Institute TLS and PostgreSQL-SCRAM interfaces avoids inventing cryptography inside a networking migration. The certificate path also needs an explicit system-root provider and hostname/signature verification owner; an X.509 parser alone is not a trust policy.

There is a concrete canary identity collision: the empty Institute reservations `swift-crypto` and `swift-certificates` have the same SwiftPM identities as the locked Apple providers (`swift-crypto` 4.5.0 and `swift-certificates` 1.19.3). Old/new lanes cannot resolve both repositories in one root. The provider spike must therefore choose one of: keep the Institute reservations unselected and integrate the Apple identities under differently named bridge packages; rename the Institute packages before filling them; or use separate non-coexisting build lanes. Silently attempting to depend on both is invalid.

This requires Principal confirmation. If “pure Institute” means that no external cryptographic implementation may remain transitively, `swift-crypto`, RFC 5280, certificate-path validation, root-store integration, and algorithm validation become a separate critical program. That additional program is not included in the base estimate and must not be hidden inside `swift-transport-layer-security`.
