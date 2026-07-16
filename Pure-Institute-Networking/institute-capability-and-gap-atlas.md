# Institute capability and gap atlas

## Maturity scale

- **Shipped**: checked-in production implementation with tests relevant to the stated behavior.
- **Partial**: useful production code exists, but a required runtime path or correctness property is missing.
- **Interface**: useful engine-free API or vocabulary exists without a live engine.
- **Reservation**: repository metadata only; no manifest or source.
- **Unknown performance**: no directly relevant benchmark evidence was found. Source volume is not performance evidence.

No package was compiled in this audit. “Shipped” is therefore a source/maturity classification, not a green-build assertion.

## Substrate atlas

Counts are `production files/lines; test files/lines`.

| Package | Layer | Count | Capability and evidence | Maturity / platform | Performance evidence | Disposition |
|---|---:|---:|---|---|---|---|
| `swift-io-primitives` | L1 | 2/212; 8/822 | `IO<Capabilities>` couples domain capabilities to a scheduling runner; runner exposes serial executor and shutdown (`IO.swift:93-116`, `IO.Runner.swift:66-91`) | Shipped vocabulary | None specific to network workloads | Retain |
| `swift-async-primitives` | L1 | 91/7,791; 15/4,045 | Move-only bounded channel suspends full producers and wakes FIFO waiters; semaphore has admission/cancellation/timeout/shutdown | Shipped; cross-platform Swift | No HTTP-body benchmark | Retain; use for bounded bodies/admission |
| `swift-executor-primitives` | L1 | 14/553; 6/403 | Job, queue, wait, and shutdown vocabulary | Shipped | Not measured here | Retain |
| `swift-executors` | L3 unifier | 19/2,257; 8/524 | Pinned, polling, completion, and sharded executors | Partial cross-platform | Not measured here | Retain |
| `swift-threads` | L3 unifier | 27/1,520; 2/550 | Pinned actor and semaphore-bounded thread pool; default admission 256 | Shipped mechanism | No HTTP/Postgres benchmark | Retain; blocking oracle only for final networking |
| `swift-kernel` | L3 platform unifier | 63/4,524; 35/4,656 | Typed descriptor/socket/event/completion surfaces; kqueue/epoll event source; Linux io_uring accept/connect/send/receive | Darwin/Linux partial; Windows IOCP factory absent | Low-level experiments/tests, no product baseline | Retain; finish platform gaps |
| `swift-io` | L3 unifier | 20/1,822; 32/2,994 | One-thread event actor and completion actor; completion cancellation keeps buffer custody until original and cancel CQEs settle | Darwin/Linux event; Linux completion; Windows gap | No end-to-end server benchmark | Retain |
| `swift-sockets-standard` | L2 | 5/270; 1/107 | RFC 768/791/9293 aliases; only IPv4 exposed through `Sockets.IP` | Partial vocabulary | N/A | Retain/refactor with unified IP vocabulary |
| `swift-ip-address` | L3 unifier | 1/13; 1/20 | Reexports IPv4 and IPv6 standards | Interface/converger | N/A | Retain/integrate |
| `swift-sockets` | L3 domain unifier | 14/1,441; 9/1,216 | Move-only TCP/UDP, typed read/write/connect/ready/send/receive/close capabilities; only production `.blocking()` factory | Partial; POSIX-shaped, no Windows listener | Blocking/echo tests, no production-load comparison | Refactor, do not replace |

### Socket-specific gaps

The socket surface is real but not a production asynchronous server:

- no `.events()` or `.completions()` factory in production;
- a test-only reactive factory uses blocking `poll(2)`;
- illegal `Listener.reactive(..., io: .blocking())` pairing is representable and documented to hot-spin;
- no resolver, socket-option policy, deadlines, admission/supervision, or explicit reader/writer split;
- the listener calls POSIX directly, so Windows is not implemented;
- the L2 and L3 packages both define `Sockets` and the runtime uses `Kernel.Socket.Address` rather than the Institute IP/socket standard vocabulary; and
- `Span.Raw` buffer custody is documented but must be reconciled with the canonical Span-family requirement: owned `Byte` storage across suspension, raw view only at the syscall boundary.

Correct ownership is domain-local: `swift-io` keeps generic strategy actors; `swift-sockets` supplies socket factories and typed error mapping. Moving socket knowledge into `swift-io` would invert semantic ownership.

## HTTP and routing atlas

| Package | Count | Capability | Maturity / evidence | Missing for RepoTraffic | Disposition |
|---|---:|---|---|---|---|
| RFC 9110 | 48/5,916; 12/2,211 | Methods, targets, status, ordered/repeated headers, request/response values | Substantial L2 values/tests; bodies are `[Byte]?` | Streaming body separation and integration | Retain/refactor body ownership |
| RFC 9111 | 12/2,187; 8/1,697 | Cache directives and pure storage/reuse decisions | Substantial policy code | Not a store/eviction/origin engine | Retain; unrelated to RepoTraffic Redis replacement |
| RFC 9112 | 17/3,002; 13/2,923 | HTTP/1.1 parsing, serialization, chunked encoding, persistence vocabulary | Whole-array codecs; chunk consumption is explicitly approximate | Incremental exact framing, limits, chunk streaming, partial input/output | Retain whole-message utility; add incremental state machines |
| `swift-http-standard` | 2/35; 1/60 | `HTTP = RFC_9110` alias and reexports 9110/9111/9112 | Thin converger | Runtime behavior | Retain |
| `swift-url-routing` | 70/7,885; 19/4,070 | Mature bidirectional parser-printer over URI request data | Strong source/test footprint | HTTP carrier uses RFC 7230/7231 and `Foundation.Data` | Retain core; extract/update HTTP integration |
| `swift-server` | 50/2,442; 6/673 | Engine-free `Responder`/middleware/error intent; Vapor application and collected `[UInt8]` request/response implementation | Valuable membrane, external engine | Native lifecycle, streamed HTTP model, signals, limits, observability | Split/refactor |
| `swift-server-foundation` | 6/290; 3/512 | Compatibility exports, memory store, NIO event-loop dependency | Declares itself dissolved but still selected | Everything should move to semantic owners | Remove |
| `swift-server-foundation-vapor` | 21/1,622; 4/139 | Vapor integration umbrella/reexport | Legacy bridge | Native integration | Remove after canary |

RFC 9112's current parser takes a complete array and has no “need more input” state (`HTTP.Message.Parser.swift:16-85`). Request and response deserializers copy collected bodies; chunk accounting is approximate (`HTTP.Message.Deserializer.swift:15-36,93-121,204-226,284-315`). Serializers return complete arrays (`HTTP.Message.Serializer.swift:13-44,89-125`). These APIs are useful fixture or convenience oracles, not a socket protocol engine.

The HTTP runtime reservations—`swift-http`, body, compression, content negotiation, cookies, CORS, ETag, range, redirect, routing, HTTP/2, HTTP/3, and WebSocket—have no manifest and no Swift source. Their names are not evidence that each should become a package. Selected Boiler/Vapor middleware does, however, prove current cookies, CORS, ETag, range, redirect, MIME, and streamed static-file behavior. The target therefore fills those focused policies plus a dedicated HTTP/file-system integration; body remains in the runtime initially, while compression/content-negotiation/HTTP2/3/WebSocket remain deferred.

## TLS, certificate, and DNS atlas

| Package | Capability | Maturity | Critical gaps | Disposition |
|---|---|---|---|---|
| RFC 8446 | TLS records/handshake envelopes, ClientHello/ServerHello/extensions, Finished, tickets, transcript, key-schedule formulas with injected hash/HKDF witnesses | Substantial codec/formula library: 93/6,292; 10/1,458 | Incremental records, handshake session, AEAD protection, sequence/nonce, crypto provider, certificate/signature validation, trust roots/path, hostname, SNI/ALPN policy, alerts/shutdown | Retain L2; build L3 engine elsewhere |
| RFC 6066 | TLS extension vocabulary including server-name concepts | Real source (45 files) | No session integration | Retain/integrate as needed |
| RFC 5280 | X.509 profile reservation | 0 manifest/source | Entire certificate/path law | Implement or adopt behind dedicated boundary |
| `swift-certificates` (Institute) | Reservation | 0 manifest/source | Parsing, path validation, trust roots, hostname/revocation policy | Do not fill in provider-backed base route: identity collides with locked Apple swift-certificates |
| `swift-crypto` (Institute) | Reservation | 0 manifest/source | Production cryptographic algorithms/provider | Do not hand-roll or fill while locked Apple swift-crypto shares the identity |
| `swift-transport-layer-security` | Reservation | 0 manifest/source | Entire L3 TLS engine | Fill; this owns session/record policy |
| RFC 1035 | DNS messages/vocabulary: 28 source, 7 tests | Real L2 implementation | Resolver transport, search policy, timeouts/retries, caching, platform host resolution | Retain |
| `swift-dns-cache` | Reservation | 0 manifest/source | All runtime behavior | Do not fill before resolver design |

RFC 8446 uses Apple Swift Crypto only in its test target; production has no crypto implementation. Certificate and CertificateVerify values carry opaque payloads, not trust. The old lane already resolves Apple `swift-crypto` 4.5.0 and Apple `swift-certificates` 1.19.3, which cannot coexist with different-URL Institute packages under the same SwiftPM identities. A production TLS claim is invalid until provider naming, system roots, client handshake, record protection, verified signature/path/hostname, alerts, truncation defense, and shutdown all interoperate.

Inbound RepoTraffic on Heroku can cut over to plaintext HTTP/1.1 behind the router before TLS exists. Outbound HTTPS and production PostgreSQL cannot.

## PostgreSQL and SQL atlas

| Package | Shipped capability | Engine status | Disposition |
|---|---|---|---|
| `swift-postgresql-standard` | Rich PostgreSQL DSL/macros: functions, operators, arrays, JSONB, triggers, CTEs, typed fragments | Native dialect; PostgresNIO is resolution-only for selected main product and conditionally used by the `SQLValidation` Test Support product | Retain; add separate wire-law target/product |
| `swift-records` | Records macros, readers/writers, cursors, explicit transaction/savepoint helpers, migrations, full-text helpers, triggers, LISTEN/NOTIFY | Mixed package; production PostgresNIO client leaks through public configuration/rows/notifications | Split core from engine; bridge to SQL |
| `swift-sql` | Engine-neutral Database/Connection/Row/Statement/Query/Value/typed Error | Interface only; no wire engine | Retain/expand |
| `swift-sql-postgres` | `SQL.Database` adapter | Pure PostgresNIO adapter | Retain package boundary, replace engine |
| `swift-server / Server PostgreSQL` | Second `SQL.Database` adapter | Duplicate PostgresNIO/NIOSSL implementation | Remove duplicate |
| `swift-sql-migrations` | Ordered up-only migrations with tracking and transactional SQL scope | Native, engine-neutral | Retain/adopt |
| `swift-sql-dependencies` | Fail-loud ambient `SQL.Database` key | Native integration | Retain where needed |
| `swift-pool-connections` | Reservation | No manifest/source | Leave empty; do not generalize without second client |

The current Records engine is porous: `Database.Configuration` aliases `PostgresClient.Configuration`; the runner owns/starts a PostgresClient; binds, rows, cursor, and notifications use PostgresNIO types. Unsupported generic bindings may warn and become NULL. The newer SQL seam is cleaner but lacks decimal/array bindings, cursor streaming, statement read/write classification, isolation/savepoints, notifications, pool policy, and lifecycle. Those are migration work, not evidence for a third abstraction.

## Scheduler/cache atlas

| Package/surface | Capability | Maturity | Product fit | Disposition |
|---|---|---|---|---|
| `swift-scheduler` | Typed payload job, scheduled job, hourly/daily cadence, registry replay | Interface only: 9 production files, 1 shallow test; `.redis(url:)` leaks backend policy; no runner | Good vocabulary for two scheduled jobs | Retain/refactor; add native clock runner |
| `swift-server / Server Jobs` | Vapor/Queues adapter | External bridge; live adapter untested | Not selected by RepoTraffic; root selects Queues directly | Retire, do not make server own jobs |
| `swift-bounded-cache` | Bounded FIFO cache; separate async compute coalescing cache | Partial: 14 source, 4 test files; no TTL and bounded/coalescing are not combined | Useful lower substrate | Extend only if replacing app bridge merits it |
| RepoTraffic memory cache | Actor LRU, TTL, invalidation, stats | Live implementation already used in development | Exact near-term fit for two token entries | Use as reversible bridge |
| `swift-redis` | Reservation | No manifest/source/tests | No measured product need | Do not implement for this cutover |
| reserved L4 jobs/cache repos | Names only | Empty | No measured justification | Leave empty |

`swift-scheduler` needs validated cadence, explicit stable identity, injected clock, non-overlap, missed-tick policy, bounded concurrency, typed underlying errors, dependency-scope installation, metrics, cancellation, and graceful shutdown. Persistence, leases, retries, and dead letters are not current parity requirements because no live dispatch path exists.

`swift-bounded-cache` needs a timed + bounded + compute-coalescing surface and deterministic clock/concurrency tests before it can replace the application actor. The early cutover should not wait for that refactor.

## Supported-platform reality

| Capability | macOS | Linux | Windows |
|---|---|---|---|
| Kernel event I/O | kqueue present | epoll present | absent |
| Kernel completion I/O | absent | io_uring present | IOCP absent |
| Blocking sockets | present | present | listener path is POSIX-shaped |
| Native HTTP runtime | absent | absent | absent |
| Native TLS runtime | absent | absent | absent |
| Native PostgreSQL client | absent | absent | absent |

RepoTraffic's deployment gate is Linux x86_64 on Swift 6.3.3 Jammy; macOS is a development/interoperability gate. Canonical packages must not claim Windows runtime support until IOCP and Windows sockets pass live tests. Windows compile/deterministic tests remain a merge gate where sources are intended cross-platform; live IOCP is a stable-release gate, not a RepoTraffic-on-Linux cutover prerequisite.

## Atlas conclusion

Retain and finish the lower substrate. Refactor the whole-message protocol packages incrementally. Fill `swift-http` server runtime, measured cookie/CORS/ETag/range/redirect policies, HTTP/file-system integration, `swift-transport-layer-security`, provider-neutral/system DNS boundaries, and the PostgreSQL client boundary. Preserve Server/SQL/Records/Scheduler membranes after removing engine policy. Keep colliding Institute crypto/certificate reservations empty in the provider-backed route. Remove dissolved compatibility shells. Do not build HTTP/2, WebSocket, Redis, a universal buffer, a handler pipeline, or a generic durable queue without a measured consumer.
