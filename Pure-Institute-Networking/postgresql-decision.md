# PostgreSQL decision

## Decision

Implement PostgreSQL as an independent protocol/client program over the common socket/TLS substrate. Keep wire-protocol law, client/session policy, SQL adaptation, Records conveniences, migration policy, and SaaS composition in separate owners.

```text
PostgreSQL Wire Standard (L2)
        -> swift-postgresql client/session/pool (L3)
        -> swift-sql-postgres integration
        -> swift-records-sql integration
        -> RepoTraffic / Identity persistence (L5)
```

`swift-server` does not own a PostgreSQL adapter. The duplicate `Server PostgreSQL` target is removed after consumers converge on `swift-sql-postgres`.

## Current baseline

RepoTraffic's actual runtime path is `RepoTraffic -> Records -> PostgresNIO`. At the frozen launch snapshot, `Server PostgreSQL` was selected by 15 targets but had no source import; later manifest pruning reduced those rows to one without removing the app path. Records publicly leaks PostgresNIO configuration, owns `PostgresClient`, bridges bindings/rows/cursors/notifications, and supplies the pool.

The product configures:

- 30-second connect timeout;
- min/max pool of 5/20;
- 60-second idle timeout;
- startup parameters for statement/transaction-idle/lock timeouts and application name;
- required production TLS with full certificate verification/host name supplied by PostgresNIO; and
- Identity plus RepoTraffic migrations.

Those values become parity fixtures and defaults only at the application configuration boundary.

## Specification baseline

The primary reference is PostgreSQL 18's [frontend/backend protocol](https://www.postgresql.org/docs/current/protocol.html), including [overview/version negotiation](https://www.postgresql.org/docs/current/protocol-overview.html), [message flow](https://www.postgresql.org/docs/current/protocol-flow.html), and [message formats](https://www.postgresql.org/docs/current/protocol-message-formats.html).

The latest protocol is 3.2, introduced by PostgreSQL 18; libpq still defaults to 3.0 for old servers/middleware. Protocol 3.2 enlarges the cancellation secret and changes BackendKeyData/CancelRequest. Initial RepoTraffic compatibility therefore uses 3.0 by default while the codec/state model accepts 3.2 negotiation. Requesting 3.2 becomes a later canary after the actual Heroku endpoint/proxy path proves it.

## L2 wire-law scope

Add a separate `PostgreSQL Wire Standard` target/product to `swift-postgresql-standard`. It owns:

- startup, SSLRequest, CancelRequest, and protocol negotiation packets;
- typed frontend/backend message tags and exact length framing;
- authentication request/response messages;
- ReadyForQuery and transaction status;
- simple-query and extended Parse/Bind/Describe/Execute/Sync/Close flows;
- row/parameter descriptions, DataRow, command completion, empty/no-data states;
- error/notice field codes with unknown-field preservation;
- COPY and notification message values even when client policy is deferred;
- OID, text/binary format, NULL, and network byte order law; and
- incremental decoding with exact consumed bytes and configured maximum message size.

It owns no socket, TLS, task, pool, prepared-statement cache, retry, or SQL DSL execution.

## Client/session state

`swift-postgresql` owns one actor/state machine per connection. Required state includes:

- TCP established -> optional SSLRequest/TLS upgrade -> startup -> authentication -> parameter/backend-key collection -> ReadyForQuery;
- idle, simple-query cycle, extended-query cycle, copy/notification side messages, failed transaction, closing, closed;
- one active command cycle per connection for the first cutover; pool concurrency replaces protocol pipelining;
- unsolicited NoticeResponse/NotificationResponse handling at every legal state;
- typed protocol/desynchronization/transport/TLS/auth/server/cancellation errors; and
- deterministic terminal cleanup.

PostgreSQL recommends state-machine clients able to accept errors/notices whenever legal. A fixed “next message must be X” chain is rejected.

## Authentication

Required first cutover:

1. SCRAM-SHA-256.
2. Cleartext password only over a successfully verified TLS channel and only when the server asks.
3. AuthenticationOk/error and unsupported-method fail-closed behavior.

SCRAM is not supplied by the TLS integration. `swift-postgresql` defines injected witnesses for cryptographically secure nonce generation, SHA-256, HMAC-SHA-256, PBKDF2-HMAC-SHA-256, and constant-time proof comparison; the dedicated `swift-postgresql-crypto` integration binds them to the selected provider. It validates server nonce extension, salt/base64, iteration count under an explicit lower/upper policy (preventing weak work factors and CPU denial), SASL escaping/normalization compatibility, `AuthMessage`, client proof, and server signature against PostgreSQL/RFC vectors. Passwords, salted passwords, client/server keys, proofs, and nonces have bounded lifetimes and zeroization evidence where storage permits.

SCRAM-SHA-256 is PostgreSQL's strongest currently documented password method; MD5 is deprecated and scheduled for removal. MD5 is not implemented unless the staging handshake proves it is required. OAUTHBEARER, GSSAPI, SSPI, Kerberos, and client certificates are not RepoTraffic removal gates.

SCRAM-SHA-256-PLUS becomes required when the TLS provider exposes the `tls-server-end-point` channel binding. Until then, the client supports ordinary SCRAM only and records the missing hardening explicitly. Nonces, salted passwords, proofs, and intermediate secrets are never logged and are zeroized where storage permits.

## TLS

The PostgreSQL TLS integration owns the SSLRequest exchange and then hands the connection to the common TLS engine. Production policy is fail-closed verified TLS:

- require encryption;
- validate chain to configured/system roots;
- verify hostname/IP with explicit PostgreSQL compatibility policy;
- pass SNI for DNS hostnames;
- expose negotiated version/cipher and verification outcome only; and
- reject downgrade or plaintext fallback.

The current `.require(.makeClientConfiguration())` uses NIOSSL full verification and default roots. Merely encrypting without identity verification would be a regression. PostgreSQL's own documentation recommends `verify-full` in security-sensitive environments.

## Query semantics

### Simple query

Use for migration/control statements and interoperability. Preserve PostgreSQL's multi-statement implicit-transaction/error semantics; do not split a multi-statement string and pretend the behavior is equivalent.

### Extended query

Required for all parameterized application queries:

- Parse creates named/unnamed prepared statements;
- Bind creates portals with explicit parameter/result format codes;
- Describe provides row metadata;
- Execute supports a row limit and suspended portal;
- Sync restores a known ReadyForQuery boundary after error.

Prepared statement caching is bounded per connection and invalidated on connection replacement. The first implementation may use unnamed statements/portals to reduce cache complexity if benchmarks meet the gate. SQL values never interpolate into text as a shortcut.

### Rows/codecs

Parity set before RepoTraffic cutover:

- NULL, Bool, signed integer widths, Double;
- text/varchar/name;
- UUID;
- date/timestamp/timestamptz used by current records;
- bytea using canonical `Byte`;
- JSON/JSONB;
- decimal/numeric; and
- scalar arrays used by Records/Identity.

Unknown OIDs are preserved as opaque `(oid, format, bytes?)`, not coerced to NULL. Both text and binary formats have explicit codecs; text is the portability fallback. Decoder failure reports column/OID/format without secret value content.

## Transactions

- A transaction consumes one leased connection for its full lifetime.
- Commit/rollback is guaranteed in a structured scope; cancellation attempts rollback, then closes the connection if ReadyForQuery cannot be recovered.
- Nested transaction helpers use savepoints with deterministic generated names.
- Isolation and read-only/deferrable policy are explicit typed values.
- The pool never leases a connection whose transaction state is not idle.

This fixes the current Records mismatch in which a documented “serialized write” can merely lease any pooled connection and its migrator can autocommit DDL/bookkeeping separately.

## Cancellation

The client stores BackendKeyData. Query cancellation opens a separate short-lived connection and sends CancelRequest, accounting for 3.0 versus 3.2 secret shape. Cancellation is best effort and race-prone:

- task cancellation does not immediately return the main connection to the pool;
- wait for ErrorResponse/ReadyForQuery, or close if synchronization cannot be proven;
- a cancel that arrives after the query completed must not cancel the next query; and
- cancellation transport/auth data is never logged.

This behavior is tested against real PostgreSQL with delays and rapid query turnover.

## Pool

Keep `PostgreSQL Pool` as a target in `swift-postgresql` until a second protocol proves generic law. PostgreSQL-specific connection reset, ReadyForQuery, cancellation, startup parameters, and health make premature `swift-pool-connections` extraction unsafe.

Required pool semantics:

- bounded minimum/maximum and FIFO cancellable waiters;
- caller lease deadline distinct from connection-open deadline;
- min connection warm-up without arbitrary sleeps;
- idle eviction and optional keepalive/validation;
- reconnect with bounded exponential backoff and jitter;
- connection health reset before reuse;
- graceful drain/no new leases/shutdown deadline;
- leak detection and exact ownership of client/run tasks; and
- metrics: size, idle, leased, opening, waiter count/age, checkout latency, open failures, validation/reconnect/eviction/cancel.

RepoTraffic parity exercises min 5, max 20, connect 30 seconds, idle 60 seconds, then load tests tune them. These are not library constants.

## SQL and Records convergence

### `swift-sql`

Add before adapter parity:

- canonical `Byte` value instead of `[UInt8]`;
- decimal/array binding and row decoding;
- streamed row cursor with cancellation/backpressure;
- statement read/write classification;
- transaction isolation/savepoints;
- lifecycle/health seams required by the pool adapter; and
- typed error preservation rather than string flattening.

### `swift-sql-postgres`

Replace its PostgresNIO implementation with the native client. It is the only SQL/PostgreSQL executor. Delete `Server PostgreSQL` rather than maintaining two adapters.

### Records

Remove all production PostgresNIO imports and public type leaks. Keep Records' record/query conveniences engine-neutral. A dedicated `swift-records-sql` integration maps:

- bindings/queries to `SQL.Statement`;
- rows/decoding to Records models;
- cursor to SQL streaming;
- explicit transaction/savepoint helpers; and
- dependency installation.

LISTEN/NOTIFY exists in Records but has no RepoTraffic consumer. Native notification support is not the first app cutover gate; the Records package must either implement it on the native client or move it to a separately selected integration so PostgresNIO cannot remain a hidden production dependency.

## Migrations

Adopt `swift-sql-migrations` for ordered, tracked, transaction-scoped migrations. Port both:

- RepoTraffic's raw PostgreSQL DDL, including `uuid-ossp`; and
- Identity Backend's Records-based migrator and database dependency.

Dual-run migration is forbidden. In shadow mode, the native client may inspect schema/migration state read-only; one engine remains authoritative. Before cutover, run migrations on a disposable production-version database and prove failure rollback leaves tracking and schema consistent.

## Deferred protocol capabilities

Not initial removal gates unless a fresh source/production trace proves use:

- COPY streaming;
- LISTEN/NOTIFY delivery;
- protocol pipelining;
- GSS/SSPI/OAUTHBEARER/client certificates;
- logical replication; and
- generic distributed pool/proxy awareness.

Their message law should not be made impossible by the initial state machine.

## Removal gate

PostgresNIO and its NIO/NIOSSL closure can leave RepoTraffic only when:

1. native TLS/auth/query/transaction/cancel/pool interoperability passes the actual production PostgreSQL major/proxy topology;
2. every current scalar/JSONB/decimal/array Records case differentially matches the pinned PostgresNIO SHA;
3. Identity and RepoTraffic migrations pass fresh/upgrade/failure tests;
4. a shadow read/replay phase shows equivalent rows/errors/latency without issuing duplicate writes;
5. canary traffic shows no pool starvation, leak, transaction, timeout, or reconnect regression;
6. Records and SQL public APIs expose no PostgresNIO type;
7. all `Server PostgreSQL` product edges are removed; and
8. the exact release dependency graph, symbols, and container contain no `postgres-nio`, NIOSSL, or SwiftNIO path attributable to persistence.
