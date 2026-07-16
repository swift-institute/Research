# Networking and concurrency decision

## Decision

Use direct Swift structured concurrency over the existing Institute `IO` event/completion actors and move-only sockets. Do not reproduce NIO's `EventLoopGroup`, future graph, channel pipeline, handler chain, universal `ByteBuffer`, or transport-services abstraction.

The runtime unit is protocol-specific:

- one socket-domain `IO<Sockets.Capabilities>` per selected strategy/shard;
- a listener supervisor with explicit admission;
- one connection state machine per accepted socket;
- an incremental protocol codec owned by that connection;
- owned `Byte` chunks across suspension;
- bounded async channels/credit at application body boundaries; and
- typed cancellation, timeout, shutdown, and resource errors.

This follows the canonical isolation hierarchy: actor isolation first, move-only `Sendable` ownership second, `sending` at region transfers, locks only for measured constraints, and no blanket `@unchecked Sendable`.

## Strategy selection

| Platform | Primary | Fallback | RepoTraffic gate |
|---|---|---|---|
| Linux | io_uring completion | epoll event | Probe both in the exact Jammy/Heroku container; fall back automatically if io_uring setup/opcodes are unavailable |
| macOS | kqueue event | blocking only as diagnostic oracle | Live server/client integration on arm64 and x86_64 |
| Windows | IOCP completion | none claimed | Implement and live-test before the generic packages claim Windows runtime support; not a Linux product cutover prerequisite |

Blocking sockets remain a correctness oracle and emergency development mode. They are not an acceptable high-concurrency production endpoint because one blocked operation consumes a pinned thread.

Socket strategy and descriptor mode become a single construction choice. The current representable `reactive listener + blocking IO` hot-spin combination must be impossible to express.

## Connection ownership

1. A listener supervisor consumes the move-only listener and runs on the socket runner's serial executor.
2. Each accepted connection is consumed exactly once into a connection supervisor. The supervisor is responsible for descriptor close, input/output task cancellation, protocol state, and final metrics.
3. No public API hands out the descriptor. A close is idempotent at the policy surface and exactly-once at the resource owner.
4. Full duplex is implemented by the connection state machine/strategy, not by copying a handle. Reactor mode interleaves readiness-driven read/write work; completion mode may have one read and one write in flight while the completion actor retains buffer custody.
5. Values crossing actors/channels are `sending`. A borrowed Span never becomes an escaping message.

If a split reader/writer surface is required, both halves are move-only capabilities backed by one internal lifetime owner; neither half independently closes the descriptor. This design needs an ownership experiment before API commitment.

## Buffer and byte model

- `Byte` is canonical in new protocol and body APIs. `[UInt8]`, Foundation `Data`, and NIO `ByteBuffer` exist only at compatibility integrations.
- Owned chunks remain alive across `await`. Read access uses `Span<Byte>`, initialized mutation uses `MutableSpan<Byte>`, and syscall fill uses `OutputSpan<Byte>` where the platform boundary permits.
- `Span.Raw` or an unsafe pointer is confined to the immediate typed syscall adapter with a custody/lifetime comment. It is never a stored body, queued message, or public primary API.
- Parser state records exact consumed byte counts and never discards unconsumed input.
- Collected-body convenience has an explicit caller/configuration limit. The first RepoTraffic adapter preserves its measured 10 MiB app and 1 MiB marketing limits.

The existing whole-array RFC 9112 APIs remain fixture/convenience oracles. The live decoder produces results such as `needMoreInput`, `head`, `bodyChunk`, `trailers`, and `messageComplete`, with exact consumed ranges and typed framing failure.

## Backpressure

Backpressure is a byte-budget invariant, not a vague “async stream” property.

1. Network reads fill fixed-maximum owned chunks. Channel capacity times maximum chunk size gives a hard upper byte bound, or a weighted credit counter is used when chunk sizes vary.
2. When body credit is exhausted, reactor mode stops requesting readiness/reading; completion mode does not submit the next receive. Kernel events may coalesce, but application memory cannot grow without bound.
3. Response production uses the same bounded credit. A slow peer suspends the producer and cannot accumulate an unbounded response array.
4. HTTP/1 pipelining has a bounded pending-request/response count. Responses remain ordered. The first implementation may execute one request at a time per connection; concurrency comes from multiple connections.
5. The listener uses `Async.Semaphore` or equivalent bounded admission for active connections. Accepted sockets beyond policy are rejected/closed promptly rather than queued without limit.
6. Header line, total header, field count, request-target, body, trailer, and pipeline limits are independently configurable and tested.

Heroku itself streams chunked request bodies and only buffers 1 MiB of response per connection. A fully collected transport would transfer slow-client pressure into dyno memory and is therefore rejected even though current handlers collect their small request bodies.

## Fairness

- One connection may parse/write only a configurable byte/message quota before yielding to its runner.
- Accept work, read work, write work, timers, and cancellation receive separate bounded budgets so an accept storm or large export cannot starve all other connections.
- Pool/connection waiters are FIFO unless a documented protocol priority exists.
- Per-connection actor creation is allowed; one thread or event loop per connection is not.
- The implementation records queue depth, oldest wait, bytes per yield, active/in-flight counts, and starvation alarms. Fairness is tested with elephants and mice, not inferred from average throughput.

No numeric quota is frozen by this research. The benchmark program selects it from p99 fairness and throughput curves; making an unmeasured constant normative would be false precision.

## Partial I/O and framing

Read and write operations must explicitly handle:

- short reads/writes;
- would-block/readiness races;
- EINTR at the policy layer;
- zero-byte read as peer EOF;
- half-close;
- connection reset/broken pipe;
- a cancellation racing a readiness or completion result;
- a peer closing in the middle of a framed message; and
- surplus bytes containing the next pipelined message.

Write retries advance a subspan by the exact completed count. Read parsers never assume one syscall equals one protocol unit. A communications failure during a PostgreSQL message or TLS record abandons that connection because framing synchronization cannot be trusted.

## Cancellation and timeout law

Event strategy:

1. register interest;
2. wait;
3. on cancellation, deregister/acknowledge ownership before releasing any captured buffer or closing/reusing the descriptor;
4. ignore stale generation-tagged events.

Completion strategy uses the existing two-CQE cancellation handshake: buffer storage remains alive until both the original operation and its cancel completion resolve. No task cancellation alone proves kernel custody ended.

Timeouts use an injected `Clock` and typed errors. Separate deadlines exist for DNS, connect, TLS handshake, request head/body progress, response first byte, idle keep-alive, PostgreSQL command, pool lease, and graceful shutdown. Cancellation classification distinguishes caller cancellation, deadline, peer close, protocol failure, and shutdown.

If an HTTP handler abandons a request body, the engine either drains it within an explicit byte/time budget or closes the connection. It must not reuse a connection whose next message boundary is unknown.

## Shutdown and signals

On SIGTERM:

1. stop accepting;
2. mark all keep-alive connections draining and send/force `Connection: close` on the next response;
3. stop scheduling new recurring work;
4. let in-flight handlers/queries finish within a configured deadline;
5. cancel remaining operations with the custody handshakes above;
6. close sockets/pools and join runner tasks; and
7. assert no descriptor, waiter, task, or buffer remains.

RepoTraffic's Heroku budget is 30 seconds before forced termination. The proposed default drain budget is 25 seconds, leaving five seconds for final cancellation/close and process exit. This value is a product configuration, not protocol law.

Keep-alive idle timeout defaults to at least 90 seconds on Heroku or keep-alive is explicitly disabled. A lower silent server timeout creates the router race documented by Heroku.

## HTTP/1 security requirements

The incremental RFC 9112 work must cover, before any shadow traffic:

- conflicting Transfer-Encoding/Content-Length and duplicate Content-Length rules;
- line endings, whitespace, obs-fold rejection/normalization law, and invalid request targets;
- exact chunk size/extensions/trailers and integer overflow;
- head/no-body status semantics and close-delimited responses;
- bounded headers/body/trailers and slowloris progress deadlines;
- CONNECT/Upgrade boundaries including RFC 9931's 2026 updates; and
- request-smuggling differential corpora against the Heroku edge contract;
- public-root confinement after percent decoding and symlink resolution, bounded static-file streaming, conditional/range correctness, and HEAD semantics; and
- explicit CORS, Host/canonical redirect, and trusted-forwarded-header policy. `X-Forwarded-Proto` affects HTTPS redirect/HSTS only when the selected Heroku ingress trust rule is satisfied.

The RepoTraffic cutover can reject unsupported upgrades. It may not parse them ambiguously.

## DNS

A new `swift-dns` runtime boundary owns provider-neutral host-resolution policy and deterministic injection. The first production provider is `swift-dns-system`, backed only by typed platform host-resolution surfaces so `/etc/hosts`, NSS, search domains, and split-DNS policy are preserved. Initial scope:

- A/AAAA lookup and ordered address attempts;
- IPv4/IPv6 result vocabulary using Institute IP types;
- per-attempt and overall deadlines;
- injected resolver for deterministic tests; and
- explicit address/result provenance and bounded connection-attempt policy.

Platform C imports remain in typed L2 packages. If system resolution is blocking, its provider uses bounded thread admission and makes clear that task cancellation stops the waiter but cannot pretend the underlying resolver call was canceled; results are discarded safely when they return. A separate future `swift-dns-rfc-1035` provider would own wire retries, truncation/TCP fallback, and TTL caches. It is not the default until it proves equivalence for local/enterprise resolver policy. Happy Eyeballs is a separate measured enhancement; sequential fallback is sufficient only if latency tests pass. Inbound HTTP server cutover needs no DNS connector; PostgreSQL does.

## TLS decision boundary

`swift-transport-layer-security` owns:

- client handshake state first; server handshake later unless a non-Heroku consumer proves need;
- incremental record decode/encode and AEAD open/seal;
- transcript/key/sequence lifecycle;
- alerts, close_notify, truncation handling, SNI, ALPN, and session resumption policy; and
- a generic byte-duplex interface.

It does not own cryptographic algorithms, trust roots/path building, sockets, HTTP, or PostgreSQL. Dedicated integration packages compose those providers.

Minimum production client gate: TLS 1.3 interoperability, verified certificate signature/path/hostname, explicit system roots, SNI, full record/alert shutdown, session-key zeroization evidence, and failure parity across Linux/macOS. TLS 1.2 is included only if the measured PostgreSQL/HTTP endpoints require it; silently falling back is forbidden. The provider spike must also resolve the SwiftPM identity collisions between the empty Institute `swift-crypto`/`swift-certificates` reservations and the Apple packages already selected by the old lane; both identities cannot coexist from different URLs in one canary graph.

## Observability

Every connection and operation carries stable, non-secret context:

- connection ID, local/remote endpoint, selected backend, protocol version;
- accept/connect/DNS/TLS/first-byte/total durations;
- bytes in/out, partial-I/O count, body-credit stalls;
- active/pending connections and tasks;
- cancellation/timeout/peer/protocol/shutdown reason; and
- TLS version/cipher/trust outcome without keys, passwords, tokens, or full database query values.

Metrics interfaces are domain-owned and logger/tracer integrations are separate packages. Logging cannot be required for correctness.

## Deterministic test architecture

Build scripted transports and fake clocks before live sockets:

- arbitrary read chunk boundaries and partial writes;
- would-block/spurious readiness/stale generation events;
- completion/cancel order permutations;
- EOF/reset at every protocol byte;
- bounded-channel saturation and stalled consumer;
- accept floods and fairness schedules; and
- shutdown at every connection state.

The same HTTP/PostgreSQL/TLS state machines run over scripted and live transports. Tests must not need sleeps; a sleep-dependent scheduler or pool test is a design defect.

## Rejected alternatives

- **NIO clone**: conflates scheduling, buffering, framing, handlers, and protocols; recreates the dependency being removed.
- **Blocking thread per connection**: easy prototype but unbounded threads and poor cancellation/resource custody.
- **Foundation URLSession/server as the new engine**: does not deliver Institute ownership or a server path and obscures platform/resource behavior.
- **One universal `ByteBuffer`**: byte semantics and ownership become implicit; canonical Byte/Span/storage already exist.
- **Unbounded `AsyncStream` bodies**: no memory bound/backpressure proof.
- **HTTP/2/WebSocket first**: no measured RepoTraffic requirement and no need behind the Heroku edge.
