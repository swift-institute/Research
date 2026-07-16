# Migration waves, canaries, estimates, risks, and unresolved decisions

## Estimation model

Estimates are engineering person-weeks for experienced Swift systems engineers, not calendar promises. Ranges include implementation and package-local verification; the cross-cutting shadow/benchmark/release work is shown separately and overlaps. They exclude a fully Institute-native cryptographic algorithm/X.509 program.

Confidence is low until the named spike completes.

## Dependency-ordered waves

### Wave 0 — freeze and make the graph observable

Effort: 1-2 person-weeks. Confidence: high.

- stop deleting `Package.resolved` in release builds;
- unignore, commit, and consume `Package.resolved`; archive its SHA, the resolved-package superset, a target-aware selected-product closure for each executable, verbose release build/link inputs, toolchain/container, and baseline SBOM;
- add the versioned `Scripts/selected-product-closure` tool and canonical JSON schema specified by the replacement matrix; invoke it separately for `com_repotraffic_app` and `com_repotraffic`, test it against production/conditional/trait/test-only fixture graphs, and fail closed on unknown manifest semantics or lock mismatch;
- move every pinned old-engine differential oracle to a separate comparison package root and lock so no forbidden identity remains in the release manifest/lock;
- add positive-control import/manifest/binary/container scanners;
- record current traffic/query/job/cache distributions and external baseline metrics;
- select and prove an executable Heroku canary topology. Recommended default is a separate native-engine canary app/hostname for controlled and mirrored idempotent traffic; a single app cannot bind old/new engines to one `$PORT` or assume Heroku will percentage-route a separate process type. If no upstream splitter is authorized, the production step is a boot-selected whole-release canary with immediate release rollback, not a fictional per-dyno percentage;
- confirm Heroku runtime generation, one scheduled worker count, PostgreSQL major/proxy/auth method, Redis/cache configuration, and io_uring availability without secrets.

Gate: a rebuilt baseline is reproducible and matches current behavior. Reversible: release-build configuration only.

### Wave 1A — early cache and scheduler exit

Effort: 2-4 person-weeks. Confidence: medium-high after worker-count check. Runs in parallel with substrate work.

- production flag selects existing bounded memory TTL cache; instrument decrypt/hit/miss/load;
- implement timed, validated, fake-clock recurring runner in `swift-scheduler`;
- remove Redis driver selection from scheduler law;
- port the two scheduled jobs; record shadow ticks first;
- make one scheduled job at a time native-authoritative; old timer disabled for that job;
- retire dormant on-demand registrations unless a caller is proven;
- remove root RediStack/QueuesRedisDriver/Queues products when Boiler/server dependencies no longer force them.

Cache rollback: select hybrid/Redis again while old dependency remains. Scheduler rollback: re-enable old scheduled command for a job and disable native occurrence; never run both authoritative schedules.

Gate: five-minute token behavior, bounded memory, acceptable decrypt/latency/load, no duplicate ticks, explicit missed-tick policy, graceful worker stop. If multiple workers or durable replay are required, defer final scheduler removal to an optional PostgreSQL occurrence/lease integration.

### Wave 1B — substrate experiments

Effort: 3-6 person-weeks of experiments, not production implementation. Confidence: low-to-medium.

- prove event/completion socket factory ownership and legal strategy type shape;
- probe io_uring opcodes/cancellation in the exact Linux runtime and epoll fallback;
- prove move-only connection/reader-writer custody across actors;
- prove a system host-resolution provider that preserves `/etc/hosts`, NSS, search, and split-DNS semantics; treat direct RFC 1035 transport as a separate optional provider;
- spike incremental RFC 9112 parser with exact consumption/limits;
- select crypto/X.509/system-trust providers, resolve the Apple/Institute `swift-crypto` and `swift-certificates` identity collisions, and prove a TLS 1.3 client handshake on Linux/macOS;
- prove PostgreSQL SSLRequest + SCRAM + simple/extended query against actual staging topology.

Each spike produces a bounded decision record and disposable code outside product paths. A failed spike changes the plan/estimate; it does not get papered over by an adapter.

### Wave 2 — asynchronous sockets

Effort: 6-10 person-weeks. Confidence: medium after Wave 1B.

- reconcile socket/IP vocabulary;
- implement production kqueue/epoll event factory and Linux io_uring completion factory;
- encode legal listener/descriptor/strategy construction;
- add socket options, deadlines, admission/supervision, partial-I/O loops, half-close, metrics;
- deterministic event/completion/cancellation/resource tests;
- Windows IOCP proceeds in parallel if required for initial package support; otherwise before stable release.

Canary: echo/proxy test service and shadow transport benchmarks; no RepoTraffic traffic yet. Gate: platform, leak, cancellation, fairness, and performance thresholds.

### Wave 3 — incremental HTTP/1 runtime

Effort: 10-16 person-weeks. Confidence: medium-low until parser spike.

- add incremental exact RFC 9112 decoder/encoder and RFC 9931 updates;
- implement bounded HTTP body, connection, and **server** roles over scripted then live transports; defer the HTTP client target because inbound Heroku cutover has no DNS/outbound requirement;
- add keep-alive, pipeline ordering, limits, timeouts, graceful close, observability;
- add server-only `swift-http-sockets` integration and focused cookie/CORS/ETag/range/redirect policy packages;
- run security corpora, fuzzing, failure injection, and macro benchmarks.

Canary: offline old/new replay, then idempotent shadow HTTP. Gate: no ambiguous framing, bounded memory, resource/performance gates.

### Wave 4 — Server/routing/HTML application cutover

Effort: 6-10 person-weeks. Confidence: medium after Wave 3.

- reduce `swift-server` to its engine-free membrane;
- create `swift-server-http`, `swift-url-routing-http`, `swift-html-http`, and `swift-http-file-system` integrations;
- preserve cookies/auth/request dependency scope, errors/redirects, JSON/CSV/HTML responses, body limits, commands, backpressured static streaming, MIME/ETag/range/Last-Modified, CORS, Host/canonical/forwarded/HTTPS/HSTS policy, logging, and signals;
- make RepoTraffic L5 own composition and retire Boiler;
- canary through the Wave-0-proven topology: separate app/hostname and controlled/mirrored traffic first, then either explicit upstream cohorts or a whole-release boot-selected engine with immediate release rollback. Never run two listeners against one dyno `$PORT` or assume a non-web process receives router traffic.

Heroku ingress remains plaintext HTTP/1.1 behind router TLS. Automatic rollback triggers on any correctness/security/resource-leak gate or on a statistically sufficient window breaching the HTTP performance/error budgets. Soak completes only after the representative route/static/middleware matrix, peak and idle behavior, restart/SIGTERM, and the benchmark program's required sample quality are covered. At the end, Vapor, AHC, WebSocketKit, RoutingKit, MultipartKit, ConsoleKit, AsyncKit, NIOHTTP2/Extras, and most NIO paths can disappear, but persistence/legacy shells may still keep NIO.

### Wave 5 — TLS client and trust

Effort: 10-20 person-weeks with vetted crypto/X.509 provider; confidence: low. A fully native crypto/X.509 implementation is an unestimated separate program, plausibly 30-60+ person-weeks before independent security review.

- incremental RFC 8446 records;
- client handshake, key schedule integration, AEAD record protection, sequence/key update, alerts/close;
- dedicated crypto/certificate/socket/system-trust integrations without selecting colliding Apple and Institute package identities in one graph;
- verified signature/path/hostname/SNI/ALPN, explicit system roots, key/secret handling;
- TLS 1.2 only if measured endpoints require it;
- RFC/algorithm vectors, NIOSSL differential, multi-server interoperability, security review.

Canary: outbound non-sensitive staging endpoints and PostgreSQL staging. Gate: fail-closed verification and all TLS validation/resource thresholds.

### Wave 6 — PostgreSQL wire/client/pool

Effort: 16-28 person-weeks. Confidence: low-to-medium after Wave 1B/5.

- add PostgreSQL Wire Standard target;
- add `swift-postgresql-sockets` with the system resolver and `swift-postgresql-crypto` with injected secure randomness/SHA-256/HMAC/PBKDF2;
- implement 3.0 session plus 3.2-aware negotiation/cancel shape;
- SCRAM, simple/extended query, rows/codecs, cancellation, transaction state, notices/errors;
- bounded fair client pool and operational metrics;
- interoperability across supported/actual PostgreSQL topology;
- no pipelining/COPY/notifications unless a cutover consumer is proven.

Canary: disposable DB, then shadow reads, then read-only repository cohort. Gate: correctness, pool/failure/resource/performance thresholds.

### Wave 7 — SQL/Records/Identity and persistence cutover

Effort: 8-14 person-weeks. Confidence: medium after native client.

- expand SQL value/cursor/transaction/lifecycle seams;
- replace `swift-sql-postgres` engine;
- create `swift-records-sql`, remove Records PostgresNIO leaks;
- port RepoTraffic and Identity migrations to SQL Migrations;
- remove duplicate `Server PostgreSQL` products;
- cut over reads then single-authority writes/transactions with feature rollback.

Gate: migration fresh/upgrade/failure proofs, full Records/Identity parity, production soak, zero PostgresNIO persistence edge.

### Wave 8 — compatibility retirement and final proof

Effort: 4-8 person-weeks. Confidence: high if earlier waves stay clean.

- remove ServerFoundation/ServerFoundationVapor, HTML/URLRouting Vapor, Boiler, old Server engine targets, dormant external comparison products from release manifests;
- remove every undeclared hidden import and make remaining dependencies explicit;
- run complete downstream workspace builds/tests/benchmarks/platform matrix;
- exact resolved superset, target-aware release-product closure, committed lock, build/link inputs, symbols, SBOM/container, and source scans;
- soak/restart/rollback drill; archive evidence.

Gate: every forbidden identity absent from both shipped executables' production closures with positive controls. This work then goes to independent/Principal acceptance; the arc does not declare itself done.

## Parallelism and critical paths

Can proceed in parallel after Wave 0:

- scheduler/cache exit;
- socket factory work;
- incremental RFC 9112 work;
- PostgreSQL wire-law/codecs;
- SQL/Records interface cleanup that does not require engine behavior;
- TLS provider spike.

Critical path to Vapor removal:

```text
socket factories -> incremental HTTP/1 server -> HTTP policies/static streaming
                 -> HTTP sockets + Server integrations -> both executables -> RepoTraffic canary
```

Critical path to PostgresNIO removal:

```text
socket factories + system host resolution -> TLS client/trust
                                         -> PostgreSQL transport + SCRAM crypto + client/pool
                                         -> SQL/Records/Identity -> RepoTraffic canary
```

Final SwiftNIO removal waits for both plus ServerFoundation and Redis/Queues retirement.

## Effort summary

With a vetted external crypto/X.509 provider behind Institute integrations, the listed wave-specific work sums to 66-118 person-weeks. Cross-cutting validation, security, performance, and release work adds 8-14 person-weeks, for a gross planning envelope of **74-132 person-weeks**. That cross-cutting work is scheduled through the waves rather than as a final phase; parallel staffing can shorten calendar time but cannot erase person-effort. Independent external security-review availability and remediation contingency are schedule blockers and are not assigned false precision here.

| Workstream | Person-weeks | Confidence |
|---|---:|---|
| graph/baseline/observability | 1-2 | high |
| scheduler/cache | 2-4 | medium-high |
| spikes | 3-6 | medium-low |
| sockets/platform | 6-10 | medium |
| HTTP law/runtime | 10-16 | medium-low |
| server/application integrations | 6-10 | medium |
| TLS client/trust | 10-20 | low |
| PostgreSQL client/pool | 16-28 | low-medium |
| SQL/Records/Identity | 8-14 | medium after client |
| final retirement/release proof | 4-8 | high late |
| cross-cutting validation/security/performance | 8-14, overlapping | medium |

## Risks

| Risk | Impact | Evidence/trigger | Mitigation |
|---|---|---|---|
| TLS scope underestimated | Blocks Postgres; security failure | RFC 8446 has no engine/trust | provider spike first; independent security review; no hand-rolled crypto hidden in schedule |
| crypto/certificate identity collision | old/new lane cannot resolve | Apple and Institute repositories share `swift-crypto`/`swift-certificates` identities | keep reservations unselected or rename; prove one-root canary graph in spike |
| SCRAM crypto hidden under TLS | auth failure/weakness | PG session needs nonce/SHA/HMAC/PBKDF2 independently | dedicated PG crypto integration, iteration bounds, vectors, secret lifecycle review |
| io_uring unavailable/partial on Heroku | Linux completion path fails | environment not yet probed | epoll fallback is first-class and benchmarked |
| HTTP parser ambiguity/smuggling | Critical security | whole-message approximate chunk accounting | incremental exact parser, RFC 9931, smuggling corpus, fail closed |
| static/middleware parity omitted | broken assets, CORS/Host/TLS-header regression | Boiler defaults activate streaming, ETag/range/CORS/redirect/HSTS | dedicated policies/file integration and explicit security fixtures/intended-change log |
| actor/channel design adds memory or unfairness | latency/outage | event actor current per-call channels; no product benchmark | hard byte/admission budgets, quotas, saturation/fairness tests |
| hidden transitive edge remains | target not achieved | undeclared imports and bridge umbrellas | lock+graph+symbol+SBOM scans with positives |
| deployment resolves moving branches | evidence invalid | Dockerfile deletes lock | Wave 0 reproducibility gate |
| canary topology cannot route old/new | rollout/rollback fiction | one dyno has one `$PORT`; process types are not automatic web cohorts | prove separate app/upstream splitter or use whole-release boot selection with rollback |
| Records semantic mismatch | data/migration corruption | writer is not transaction/serialization | SQL transaction scope, disposable migration failures, single-authority writes |
| TLS identity validation regresses | MITM risk | encryption alone is insufficient | full chain+hostname policy is hard gate |
| scheduler duplicates across workers | duplicate side effects | current process-local timers; worker count unknown | confirm singleton; otherwise occurrence/lease/fencing integration |
| per-process cache raises decrypt/load | latency/cost | shared Redis removed | instrument/canary; bounded coalescing cache; rollback |
| Windows support overclaimed | ecosystem break | no IOCP/current POSIX listener | explicit support matrix; no claim before live IOCP |
| package proliferation/cycles | maintenance failure | strict integration boundaries | dependency DAG lint; providers never import integrations; leave unjustified reservations empty |
| external baseline treated as spec | preserves bugs | differential mismatch | primary spec wins; document intentional differences |

## Policy decisions required before committing implementation

1. **Crypto/certificate provider**: recommended narrow vetted provider behind Institute packages, or fully Institute-native security program?
2. **Initial platform claim**: Linux+macOS production runtime first with Windows before stable release, or Windows required before RepoTraffic cutover?
3. **Scheduler parity**: is one worker, process-local non-durable schedule with skipped downtime ticks acceptable? If not, require PostgreSQL occurrence/lease work after native DB.
4. **Dormant on-demand jobs**: delete until a caller exists, or preserve an interface without an engine?
5. **Cache**: approve per-process five-minute decrypted-token cache after canary; PostgreSQL cache is explicitly rejected for sensitive/durability reasons.
6. **TLS versions**: TLS 1.3 only unless live endpoints prove TLS 1.2 demand?
7. **PostgreSQL protocol**: 3.0 default with 3.2-aware implementation/canary, or request 3.2 immediately?
8. **Deferred protocols**: confirm HTTP/2, WebSocket, compression, multipart, COPY, LISTEN/NOTIFY, and pipeline support are outside first removal gate absent measured use.
9. **Foundation networking breadth**: fixed forbidden-family removal only, or also replace current URLSession-based SaaS clients in this program?
10. **Heroku cutover topology**: authorize a separate canary app plus upstream traffic splitter, or accept whole-release boot-selected engine canaries with release rollback?
11. **HTTP edge policy**: preserve the current origin-reflecting CORS and forwarded-proto/HSTS behavior exactly, or approve a documented hardening policy for trusted proxies, allowed origins/hosts, symlink confinement, and preload?

## Completion evidence package

The eventual completion request must provide exact artifact commits, package/test/benchmark commits, platform/result matrices, canary/rollback dates and metrics, release dependency JSON/lock/SBOM, forbidden scans with positives, independent review findings/dispositions, remaining deferred decisions, and any blocked gate. Principal judgment is the acceptance oracle.
