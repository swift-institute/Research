# Validation and benchmark program

## Principle

Removal follows evidence, not API resemblance. Each layer first passes deterministic law tests, then live interoperability, then differential product replay, then reversible production canaries. A third-party implementation is a comparison oracle; the primary specification decides disagreements.

## Frozen baselines

Before implementation:

1. commit and consume the root `Package.resolved`; stop deleting it in the release container;
2. add and version `Scripts/selected-product-closure`, run its exact replacement-matrix invocations for both release executables, and archive its canonical JSON beside `swift package show-dependencies --format json` as a resolved-package **superset** and the exact verbose release build/link inputs; SwiftPM's show-dependencies command has no `--product` selector and is not production-path proof;
3. pin comparison SHAs from the frozen launch lockfile, reconfirmed unchanged for these identities at the latest recheck, including Vapor `748ae843…`, PostgresNIO `f2188e05…`, SwiftNIO `0b18836b…`, NIOSSL `d930168b…`, AsyncHTTPClient `4603a803…`, Queues `4fa1ef91…`, and RediStack `8c4ce108…`;
4. record Swift toolchain, OS/kernel, CPU, PostgreSQL server/proxy major, Heroku runtime generation, dyno type/count, and feature flags; and
5. capture sanitized representative request/query/job/cache traces with payload size distributions and secrets removed.

No benchmark comparison is valid if dependency revisions or environment change between lanes.

## Protocol fixtures

### HTTP/1.1

- RFC 9110/9112 examples and ABNF-derived valid/invalid cases.
- RFC 9931 optimistic transition requirements.
- every byte boundary between reads, including one byte per read.
- Content-Length duplicates/conflicts, Transfer-Encoding ordering/conflict, chunk extensions/trailers, overflows, premature EOF, close-delimited responses, HEAD/no-body statuses, 100 Continue, CONNECT/Upgrade, pipelining, repeated headers, and configured limits.
- a request-smuggling corpus tested against the native parser, pinned Vapor/NIOHTTP1, and the documented Heroku edge behavior. Specification-compliant rejection wins over differential parity.
- static-file fixtures for percent decoding, traversal and symlink escape confinement, missing/default files, directory redirects, MIME selection, HEAD, and backpressured multi-chunk delivery. The native path must resolve beneath the configured public root; an unsafe legacy symlink escape is rejected as an intentional hardening, not preserved for byte parity.
- conditional/range fixtures for generated ETag, matching/nonmatching `If-None-Match`, 304 headers, Last-Modified, valid/open/suffix/unsatisfiable/malformed/multiple Range requests, 206/Content-Range/Accept-Ranges, and exact streamed byte counts.
- CORS simple/preflight/denied-origin/credentials/header/method/`Vary` cases; Host allow/deny and canonical redirect; proxy-trust, `X-Forwarded-Proto`, HTTPS redirect, and HSTS cases. Forwarded headers are trusted only under an explicit Heroku ingress policy—blind legacy trust is not a parity requirement.

### TLS

- RFC 8446 plus errata and RFC 8448 handshake traces.
- supported cipher/hash/HKDF/AEAD vectors from authoritative algorithm sources.
- handshake fragmentation/coalescing at every record boundary; key update; tickets; alerts; close_notify/truncation; bad MAC/tag; sequence limits; invalid certificates/hostname/time/path.
- client interoperability against multiple current servers and pinned NIOSSL; packet/key logs only in isolated tests and never production.

### PostgreSQL

- PostgreSQL 18 message formats and state transitions for protocol 3.0 and 3.2 negotiation.
- server majors 14 through current, plus the actual production version/proxy topology.
- startup parameters; SCRAM success/failure plus nonce/salt/base64/iteration-bound/client-proof/server-signature vectors; unsupported auth; TLS required/rejected; simple/extended query; named/unnamed statements; portals; errors/notices; cancellation; transaction status; connection close.
- text/binary/NULL/OID fixtures for every parity type and malformed length/encoding cases.

## Property, fuzz, and model tests

- decoder never reads beyond input, allocates beyond configured bounds, or loses surplus bytes;
- encode/decode round trips for canonical values;
- incremental decoding is invariant under arbitrary chunk partition;
- parser state plus consumed count is equivalent to whole-message fixture result;
- connection/pool/scheduler state transitions satisfy a small executable model;
- cancellation and shutdown permutations end with zero live resource;
- malformed input never traps or loops without consuming/requesting input; and
- fuzz corpora retain every regression seed.

Use structure-aware generators in addition to raw bytes. Run sanitizers where supported and strict-memory-safety compilation on every new target.

## Failure injection

Scripted transports must inject:

- partial read/write, would-block, EINTR, spurious/stale readiness, zero read, reset, broken pipe, half-close;
- completion before/after cancel CQE and timeout/cancel/shutdown races;
- system DNS `/etc/hosts`/NSS/search/split-policy fixtures where controllable, timeout/empty/multiple addresses and first-address failure, plus cancellation while a bounded blocking resolver call remains in flight;
- TLS alert/bad certificate/truncation/key update during application data;
- PostgreSQL error/notice at every legal state, dropped connection mid-query/transaction, cancel race, pool saturation, failed warm-up/reconnect;
- handler that never reads its body, body producer/consumer stall, slowloris, response larger than edge buffer;
- scheduler restart during tick and overlapping long-running job; and
- cache expiration, concurrent same-key miss, capacity pressure, and process restart.

Tests use fake clocks and acknowledgements, not sleeps.

## Resource and lifecycle tests

Measure before/after steady state and after shutdown:

- file descriptors/handles, threads, tasks, registered events/completions;
- outstanding buffers/bytes and channel waiters;
- connection/pool/scheduler/cache objects;
- RSS and allocator high-water mark; and
- idle CPU.

Hard correctness gate: all counts attributable to a completed test return to baseline; no sanitizer finding; no unbounded monotonic growth in a long soak. Idle server CPU target is below 1% of one core after measurement noise is established.

## Benchmarks

### Micro

- socket accept/connect/read/write for blocking, event, and completion strategies;
- RFC 9112 head/chunk encode/decode across sizes/chunk partitions;
- TLS handshake, record open/seal, resumed session;
- PostgreSQL message codec, bind/decode types, simple/extended/prepared queries;
- bounded channel body throughput and contention; and
- pool lease/release under saturation/cancellation.

### Product-like macro

- RepoTraffic route mix: small HTML/JSON, 1/10 MiB request bounds, large CSV/JSON export, authenticated cookie flow, static assets;
- static/middleware mix: cold/warm/conditional/range/HEAD files, slow download, CORS/preflight, bad/canonical Host, HTTP-forwarded redirect/HSTS, error mapping, and timing instrumentation;
- concurrency sweep including keep-alive, slow clients, elephants/mice, connection churn, overload, and graceful restart;
- database read/write/transaction/migration mix at pool sizes around 5/20;
- scheduled job durations/failures; and
- memory-cache hit/miss/decrypt workload.

Record throughput, p50/p95/p99 latency, error/timeout rate, CPU, RSS, allocations/bytes, descriptor/thread/task counts, pool wait, body-credit stalls, and fairness by request size.

### Statistical protocol

- dedicated or controlled host; thermal/cache warm-up documented;
- at least five independent measured runs per comparison;
- report raw samples, median, dispersion/confidence interval, toolchain/commit/config;
- do not claim regression/improvement inside the established noise band; and
- preserve benchmark source and result artifacts with the implementation commit.

## Performance gates

These are initial product cutover thresholds relative to the frozen external baseline at identical correctness, hardware, configuration, and workload:

| Metric | Gate |
|---|---|
| steady-state HTTP throughput | at least 90% of baseline |
| HTTP p95/p99 at supported load | no more than 110% of baseline |
| overload p99 / starvation | no more than 120% of baseline and no starvation |
| steady-state RSS | no more than 110% of baseline; no unbounded growth |
| PostgreSQL throughput | at least 90% of baseline |
| PostgreSQL query/pool-wait p99 | no more than 115% of baseline |
| TLS handshake p95 | no more than 120% of baseline unless connection reuse makes product p99 neutral and Principal accepts |
| scheduler timing | no duplicate tick; start delay within explicit cadence tolerance |
| correctness/error rate | no regression; protocol/resource failures are zero-tolerance |

If a threshold fails, investigate/tune or seek an explicit decision. Correctness and resource safety are never traded for performance.

## Platform matrix

| Stage | macOS arm64/x86_64 | Linux x86_64 | Linux arm64 | Windows x86_64 |
|---|---|---|---|---|
| compile/unit/property | required | required | required where runner exists | required for intended cross-platform targets |
| live sockets | kqueue required | epoll + io_uring/fallback required | epoll + runtime-selected completion where supported | IOCP required before support claim |
| HTTP interoperability | required | required | required before stable release | required before support claim |
| TLS trust/interoperability | required | required | required before stable release | required before support claim |
| PostgreSQL interoperability | required | production gate | required before stable release | required before support claim |
| RepoTraffic release | development oracle | Swift 6.3.3 Jammy production gate | not currently deployed | not currently deployed |

The generic package CI follows the canonical macOS/Linux/Windows matrix. RepoTraffic cutover may precede the Windows runtime only if manifests/documentation do not falsely advertise Windows support for unfinished targets.

## Shadow/replay program

### HTTP

1. replay sanitized captured requests offline through old/new responders;
2. compare status, normalized headers/cookies, body hash or streamed chunk hash/count, static conditional/range semantics, CORS/Host/redirect/HSTS policy, logs/metrics, and side-effect intent; record every intentional security hardening separately;
3. shadow only idempotent GET/HEAD traffic in staging/production, suppressing native side effects;
4. use the Wave-0-proven topology: a separate canary app/hostname by default, with percentage/cohort routing only if an explicit upstream splitter exists; otherwise use a boot-selected whole-release canary;
5. roll back on any correctness/security/resource failure or a statistically sufficient breach of the stated performance/error gates; and
6. retain immediate release/config rollback until representative routes, static/middleware cases, peak/idle load, and restart/SIGTERM have all passed soak evidence.

### PostgreSQL

1. compare codecs/queries against disposable DBs;
2. issue shadow reads and compare decoded rows/errors; never dual-run writes;
3. cut over a read-only repository/operation cohort;
4. cut over one idempotent write path with a single authoritative driver and feature rollback;
5. expand through transactions/migrations only after soak.

### Scheduler/cache

- memory cache first runs behind a flag; compare correctness, decrypt count, latency, DB load, and per-dyno hit rate;
- native scheduler first records would-fire ticks without running handlers; then one job at a time becomes authoritative while the old schedule is disabled for that job.

## Downstream and release gates

For every wave:

- build/test changed packages and direct dependents;
- build RepoTraffic debug and release in the exact container;
- run migration/boot/serve/worker commands and graceful SIGTERM;
- verify `$PORT`, IPv4/IPv6 bind policy, 60-second boot, 30-second first-byte and shutdown budgets;
- produce the resolved-package superset, target-aware selected-product closure, committed lockfile, verbose release build/link inputs, binary symbols, and SBOM/container inventory; and
- scan for forbidden products/imports with positive controls.

Import controls include bare, attributed (`@preconcurrency`, `@_exported`), access-level (`public`, `internal`, `package`), and scoped-import syntax; a simple `^import` scanner is forbidden because it can false-zero on legal Swift source.

Final proof requires no Vapor, PostgresNIO, SwiftNIO (including `_NIOFileSystem`), NIOSSL/HTTP2/Extras/TransportServices, AsyncHTTPClient, WebSocketKit, RoutingKit, MultipartKit, ConsoleKit, AsyncKit, Queues, Vapor Redis, RediStack, Boiler, ServerFoundation, or Vapor bridge identity on either shipped executable's production path **or in the release manifest/lock, container, and SBOM**. Differential fixtures must use a separate comparison package root and lock, remain outside release products/artifacts, and be visibly classified. The versioned target-aware traversal is tested on fixtures containing known production, conditional, trait-gated, and test-only edges; actual build/link/container evidence is the backstop against traversal defects.
