# Native Networking Wave 3 Existing Ecosystem Utilization

<!--
---
version: 1.1.0
last_updated: 2026-07-22
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
changelog:
  - 1.1.0 (2026-07-22): Applied utilization-gate adjudication: scoped the
    sanctioned Apple Crypto backend outside Institute main-target rule enforcement,
    made its SwiftASN1 resolution implication explicit, selected truthful
    Foundation-free SwiftASN1 and swift-certificates adaptations, and retained
    CryptoExtras/RSA plus all repository operations behind later gates.
  - 1.0.0 (2026-07-22): Completed the read-only, declaration-level utilization
    gate for native networking Wave 3. Reconciles the live byte/buffer/parser,
    IO/kernel/event/executor/thread/time, socket, pool, URI/IP/TCP/UDP, DNS,
    TLS/crypto/certificate/trust, HTTP, and test-support substrate; records the
    sanctioned apple/swift-crypto ruling; rejects duplicate abstractions; and
    reduces the architecture to owner repairs plus the smallest remaining
    integration and runtime gaps. No runtime, manifest, repository, build graph,
    or external state was mutated.
---
-->

## Decision and gate status

Native networking Wave 3 must **reuse and improve the live Institute substrate**.
It must not introduce replacement buffers, parsers, streams, selectors, event
loops, executors, cancellation or timeout systems, socket resources, DNS wire
models, TLS record/handshake/SNI/ALPN models, HTTP messages, or a second generic
resource pool. The minimum Workspace HTTPS executor remains achievable, but the
smallest honest path is a sequence of owner repairs and narrowly classified
recipient-then-provider integrations, not the broader package set in the current
Wave-3 architecture draft.

This document is the standalone utilization gate required before the architecture
record can be finalized. It is a Tier 2 `RECOMMENDATION`; it authorizes no edit to
networking sources or manifests, package/repository creation, fork, rename,
transfer, visibility change, build graph, tag, release, Workspace, GitHub,
URLRouting, or B5-owned consumer. The architecture record remains non-final and
implementation remains blocked until the program lead approves this utilization
result.

### Principal crypto ruling

The Principal has sanctioned official `apple/swift-crypto` as the primitive and
backend dependency for this arc. The Institute must not copy, fork, or independently
implement cryptographic primitives. The Institute continues to own TLS 1.3
protocol models, state machine, transcript and key-schedule composition, record
lifecycle, alerts, SNI/ALPN integration, typed errors, IO/cancellation, and its
public semantic API. This ruling does **not** sanction direct Institute import or
API use of `SwiftASN1`, direct use of `apple/swift-certificates`, Foundation
transport, system TLS, NIO, or another third party. It necessarily sanctions
SwiftPM resolving/fetching the unmodified Apple Crypto 4.3.0 package graph,
including its unconditional `apple/swift-asn1` package declaration; only
`CryptoExtras` imports the SwiftASN1 product. The empty Institute `swift-crypto`
reservation must not coexist in a dependency graph under the same SwiftPM
identity; a separately authorized,
non-destructive collision disposition is required before landing the Apple edge.

Consequently the current architecture record's Institute `swift-crypto` fork and
`Cryptography` implementation package are deleted from the option set. The
required boundary is a narrow Institute-owned adapter from sanctioned Crypto APIs
to witness protocols owned by each recipient domain. The first concrete cut is an
L3 `swift-transport-layer-security-crypto` integration depending on
`swift-transport-layer-security` and the official Apple `Crypto` product. The
selected certificate runtime gets its own L3 `swift-certificates-crypto` adapter;
one mixed TLS/certificate integration package would violate the single-concern
rule.

## Method and evidence discipline

The review read `/Users/coen/Developer/AGENTS.md` and the canonical architecture,
platform, byte, memory-safety, implementation, code-surface, modularization,
existing-infrastructure, Swift-package/build/heritage, research, experiment,
testing, and release-readiness skills before evaluating live source. It then used
four independent read-only lanes: IO/events/sockets, DNS, TLS/crypto/trust, and
HTTP/pooling. Claims below derive from live manifests, declarations, tests,
histories, and known consumers rather than names or earlier census tables.

`sourcekit-lsp` exists, but these unbuilt, separate package checkouts do not have a
prepared common index. Projectless `cclsp` symbol/reference probes returned no
cross-package results, and the no-build/no-shared-graph gate prohibited creating
an index. Declaration and consumer claims were therefore cross-checked through
repository-local source, manifest, and test searches. This limitation is explicit:
absence of a language-server reference is not treated as absence of a capability.

After B5 reported filesystem contention, all Developer-root `find`, `rg`, and
equivalent scans stopped. The final pass used only captured evidence and bounded
reads in exact named repositories. No SwiftPM or Xcode process was started.

## Checkout, branch, remote, and reservation truth

All inspected repositories were clean when status was captured. All used their
canonical matching GitHub origin and tracked `main` except `swift-kernel`, which
was clean on `fable-448/swift-kernel-event-source` at `6d8e1c2e828a`, two
test/CI-only commits ahead of `origin/main` `41c7753fe172`. That active lane is not
available for casual mutation.

| Cluster | Repository / reviewed HEAD | Live status |
|---|---|---|
| Bytes and views | `swift-byte-primitives` `9a7077c3d603`; `swift-span-primitives` `c05fa2817c17`; `swift-byte-collection-primitives` `5ac2d0fa44fc` | Implemented; clean `main`. |
| Buffers/parsers | `swift-buffer-primitives` `181f17a3e208`; linear `263370569a59`; ring `54b4cbd2d463`; slab `5b99dd933b04`; binary parser `c1aed7b18385`; binary serializer `76beff8d0479`; parser machine `b0e8c23bd4c4` | Implemented; clean `main`. |
| IO/kernel/execution | `swift-io` `bc3ca527af3d`; `swift-kernel` `6d8e1c2e828a`; `swift-executors` `281ba5415efa`; `swift-threads` `9217b463c5d9`; `swift-io-primitives` `34ae79ca9f94`; `swift-executor-primitives` `2c70e446c204` | Implemented/partial; only kernel is on the clean active feature branch described above. |
| Time/cancellation | `swift-async` `7c1e7e3b3603`; `swift-synchronizers` `0ccb70dac816`; `swift-clocks` `cb50ef69d462`; `swift-time` `6c7e2770a1f6`; `swift-time-primitives` `155d3305bd9c` | Implemented; clean `main`. |
| Socket runtime/law | `swift-sockets` `51705159e5d1`; `swift-sockets-standard` `c96fbc5bd668`; `swift-iso-9945` `b306dbbd6136`; `swift-posix` `9ebfa2f71047` | Runtime and semantic models implemented; production event binding incomplete. |
| URI/IP/TCP/UDP | `swift-uri`; `swift-uri-standard`; RFC 3986/3987/4007/4291/5952/768/791/8200/9293 | Implemented semantic owners; no replacement model required. |
| Pool | `swift-pool-primitives` `f8400a9c7bc7`; `swift-pool-connections` `3c4702af8ae6` | Generic bounded pool implemented with repairable gaps; connection-pool repository is metadata-only. |
| DNS | RFC 1034/1035/3596/6891 plus `swift-domain-name-system` `517243da50a8` and `swift-dns-cache` `dd576b1b6bec` | Wire law implemented in RFC owners; runtime/cache reservations are empty. |
| TLS law/runtime | RFC 8446 `b35ec83a4ce8`; RFC 6066 `203a7b299e35`; RFC 7301 `47bb023d9662`; `swift-transport-layer-security` `a41a4c9c7aae` | Protocol values/vectors implemented; runtime repository is metadata-only. |
| Certificate/crypto | RFC 5280 `656a764f36eb`; Institute `swift-certificates` `c3ae2ec097d9`; Institute `swift-crypto` `1a4b60be566a` | All three Institute repositories are metadata-only; their names are not capability. |
| HTTP law/runtime | HTTP Standard `d5f39821ca05`; RFC 9110 `7f7907752612`; RFC 9111 `284392d91ddc`; RFC 9112 `3fb45a017da3`; `swift-http` `4db12c23334d` | Semantic HTTP is implemented; RFC 9112 is whole-buffer/partial; runtime drive is empty. |
| HTTP adjuncts | body `eb62e8c3ec91`; cookies `fd8af4b1de47`; redirect `0badc27cad6f`; host `6fd2ebc58c65`; session `26939dd68456`; compression `d5e615c6691e`; content-negotiation `38583fe2101e`; CORS `e1c61adc100e`; ETag `1b4e4d480f8f`; range `1414b9370cfe`; routing `7020059d60fb`; HTTP/2 `eea0eb2ad70f`; HTTP/3 `16490e272a6f` | Body/cookies/redirect/host/session contain domain values; the remaining named repositories are empty reservations. |
| Lifecycle reservations | `swift-graceful-shutdown` `b10e04383ddc` | Metadata-only; not a reason to extract owner lifecycle. |

`swift-components/swift-http-client` did not exist locally or remotely when the
architecture audit ran. Local `swift-components/swift-http-cache` and
`swift-http-middleware` directories have no repository, manifest, or source and
are not implemented evidence. Historical `coenttb/swift-tls` and
`coenttb/swift-networking` are namespace/umbrella shells, not production lineage.

Layer classification follows package essence, not target count or consumer demand:
Byte/buffer/parser/async/time/cache/pool/IO vocabulary is L1 capability law;
ISO/platform/RFC/standards packages are L2 external law; kernel/IO/executor/thread/
socket/resolver/TLS/certificate/HTTP execution packages are L3 reusable runtime;
and the concrete outbound HTTP client is L4 reusable composition with defaults.
Dedicated provider integrations remain the recipient's layer unless they select
L4 cross-domain defaults.

## Declaration-level reuse ledger

### Byte, borrowed memory, buffers, parser, and serializer substrate

| Capability | Declaration evidence and properties | Utilization verdict |
|---|---|---|
| Network octet | `Byte` is the canonical semantic `UInt8` wrapper, explicitly `Sendable`, and deliberately omits arithmetic (`swift-byte-primitives/Sources/Byte Primitive/Byte.swift:3`–`:17`, `:36`–`:48`). | Reuse everywhere; no `[UInt8]`, `Data`, or second network-byte type. |
| Borrowed bytes | The former nominal `Byte.Borrowed` is deleted; `Byte.Ownership.Borrow.Protocol.Borrowed` is `Swift.Span<Byte>` (`Sources/Byte Ownership Borrow Primitives/Byte+Ownership.Borrow.Protocol.swift:12`–`:20`, `:27`–`:45`). A stdlib span is `~Copyable`/`~Escapable`. | Delete any proposed HTTP/TLS borrowed-buffer nominal. Use lifetime-dependent `Span<Byte>`. |
| Buffer protocol | `Buffer.Protocol` is `~Copyable, ~Escapable` with `Element: ~Copyable` (`swift-buffer-primitives/Sources/Buffer Protocol Primitives/Buffer.Protocol.swift:17`–`:26`). | Reuse the generic buffer law. |
| Owned contiguous buffer | `Buffer.Linear` is a growable move-only owner, conditionally `@unchecked Sendable` (`swift-buffer-linear-primitives/Sources/Buffer Linear Primitive/Buffer.Linear.swift:9`–`:56`), exposes lifetime-dependent spans (`Buffer.Linear+Span.swift:7`–`:33`), and supports exact/bounded `OutputSpan` initialization (`Buffer.Linear+OutputSpan.swift:9`–`:97`). | Use actor-confined `Buffer.Linear<…Byte>` for owned record/body assembly. Do not invent a networking buffer. |
| Bounded ring | `Buffer.Ring.Bounded` owns finite FIFO storage, count/capacity/fullness, push/pop/peek/remove, and checkpoints (`swift-buffer-ring-primitives/Sources/Buffer Ring Bounded Primitive/Buffer.Ring.Bounded.swift:15`, `:48`; `Buffer.Ring.Bounded+Operations.swift:15`–`:33`, `:78`–`:118`). Its Sendable conformance is unsafe/unchecked. | Reuse as actor-confined receive storage if the decoder needs wraparound; never expose it as shared mutable state. |
| Raw syscall view | `Span.Raw` is Copyable/storable and `@unchecked Sendable`, but only a non-owning pointer descriptor; its safe projection is lifetime-dependent (`swift-span-primitives/Sources/Span Raw Primitives/Span.Raw.swift:30`–`:58`, `:117`–`:129`). | Pass only for the duration of socket operations while retaining the owner. Never store it as connection state. |
| Byte cursor | `Cursor` is the unified borrowed, lifetime-propagating `~Copyable & ~Escapable` cursor (`swift-cursor-primitives/Sources/Cursor Primitive/Cursor.swift:27`–`:53`, `:71`–`:112`); `Cursor<Byte>` operations already exist (`swift-byte-parser-primitives/Sources/Byte Parser Primitives/Cursor+Byte.swift:9`–`:56`). | Protocol parsers extend/reuse this cursor; no HTTP/TLS cursor. |
| Binary machine | `Binary.Machine` parses from borrowed `Cursor<Byte>` (`swift-binary-parser-primitives/Sources/Binary Machine Primitives/Binary.Machine.swift:6`–`:35`); `parsePrefix`/`parseWhole` interpret over spans (`Binary.parse.swift:54`–`:151`). | Reuse for record/message fields. |
| Parser “Incremental” | `Parser.Machine.Parse.Incremental` memoizes re-parsing after edits (`swift-parser-machine-primitives/Sources/Parser Machine Primitives/Parser.Machine.Parser.Parse.Incremental.swift:10`–`:40`, `:67`–`:126`); it is not append/need-more streaming. | A protocol-specific bounded incremental decoder remains a real RFC 9112/TLS gap, but must reuse existing cursor/buffer laws. |
| Test bytes/snapshots | `Test.Attachment` stores `[Byte]` (`swift-test-primitives/Sources/Test Primitives Core/Test.Attachment.swift:23`–`:56`); snapshot diffing owns `[Byte]` conversions (`Sources/Test Snapshot Primitives/Test.Snapshot.Diffing.swift:41`–`:67`). | Reuse for deterministic wire fixtures and failure attachments; no networking test-data model. |

No inspected main target in this cluster imports Foundation or platform C.
Linear and ring buffers already have extensive move-only tests (121 and 104
`@Test` declarations respectively); the utilization pass did not execute them.

### IO, kernel, events, executors, threads, cancellation, and time

| Capability | Declaration evidence and properties | Utilization verdict |
|---|---|---|
| IO witness | `IO<Capabilities>` separates domain operations from blocking/event/completion scheduling (`swift-io-primitives/Sources/IO Primitives/IO.swift:13`–`:36`, `:93`–`:116`). | Reuse; no transport/client IO protocol. |
| Runner/lifecycle hook | `IO.Runner` carries an executor and async shutdown hook, whose idempotence is a documented convention (`IO.Runner.swift:19`–`:35`, `:65`–`:91`). | Reuse the vocabulary; make concrete owned reactors honor deterministic shutdown. |
| File descriptor | `ISO_9945.Kernel.Descriptor` is `~Copyable, Sendable`, closes on deinit, and exposes raw access only through syscall SPI (`swift-iso-9945/Sources/ISO 9945 Core/ISO 9945.Kernel.Descriptor.swift:20`–`:50`, `:76`–`:89`); explicit close consumes it (`ISO 9945.Kernel.Close.swift:20`–`:61`). | Exact owner. No new fd/socket/syscall wrapper. Platform C stays here (`Descriptor.swift:12`–`:18`). |
| Event source | `Kernel.Event.Source` is a move-only polling resource transferred to its polling thread; it owns register/modify/deregister/arm/deadline poll/wakeup (`swift-kernel/Sources/Kernel Event/Kernel.Event.Source.swift:13`–`:80`). Platform selection is kqueue/epoll (`Kernel.Event.Source+Platform.swift:15`–`:25`, `:53`–`:63`). | Reuse; no selector/reactor/timer loop. |
| Polling executor | `Kernel.Thread.Executor.Polling` interleaves actor jobs and event polling, owns typed driver errors/wakeup/isolation/close+join (`swift-executors/Sources/Executors/Kernel.Thread.Executor.Polling.swift:12`–`:83`, `:102`–`:167`, `:255`–`:275`). | Reuse; L4 may own/inject one reactor, never a second event system. |
| Event actor | `Event.Actor` owns registration, typed waits, serial executor, fatal cleanup, and task-cancellation mapping (`swift-io/Sources/IO Events/Event.Actor.swift:1`–`:20`, `:34`–`:64`, `:271`–`:398`). Its failure composes `Async.Lifecycle.Error` and `Event.Error` (`Event.Failure.swift:16`–`:39`). | Repair in owner: remove cancelled senders, surface arm failure, add/compose explicit idempotent shutdown. |
| Cancellation taxonomy | `Async.Lifecycle.Error` already owns `.shutdown`, `.cancelled`, `.timeout` (`swift-async-primitives/Sources/Async Lifecycle Primitives/Async.Lifecycle.Error.swift:12`–`:36`). | Reuse/nest in typed domain errors; no generic networking cancellation enum. |
| Linux completions | `Kernel.Completion` is Linux `io_uring`; Darwin is unsupported (`swift-kernel/Sources/Kernel Completion/Kernel.Completion+Platform.swift:14`–`:29`). Its opcodes include read/write/accept/connect/send/receive/readiness/close/cancel (`Kernel.Completion.Submission.Opcode.swift:19`–`:102`); `Completion.Actor` implements two-CQE cancellation (`swift-io/Sources/IO Completions/Completion.Actor.swift:380`–`:474`). | Reuse later for Linux completion-backed sockets; portable first slice uses kqueue/epoll events. |
| Blocking workers | `Kernel.Thread.Pool` is a bounded sharded worker pool with admission and structured shutdown (`swift-threads/Sources/Thread Pool/Kernel.Thread.Pool.swift:8`–`:69`; options `Kernel.Thread.Pool.Options.swift:6`–`:24`). Typed `run` transfers a `sending` result (`Kernel.Thread.Pool+Run.swift:9`–`:88`). | Improve post-admission cancellation for getaddrinfo; no DNS worker pool. |
| Deadline | `Clock.Continuous.Deadline` is monotonic, saturating, expirable, and computes remaining duration (`swift-clock-primitives/Sources/Clock Primitives/Clock.Continuous.Deadline.swift:12`–`:46`, `:49`–`:137`). `Async.Semaphore` already has cancellable/deadline admission (`swift-async-primitives/Sources/Async Semaphore Primitives/Async.Semaphore+Wait.swift:19`–`:119`). | Compose phase deadlines with task cancellation and connection discard; no timer wheel or client timeout engine. |
| Bounded backpressure | `Async.Channel.Bounded` is move-only, capacity-limited, cancellation-aware, and sends `consuming sending` values (`swift-async-primitives/Sources/Async Channel Primitives/Async.Channel.Bounded.swift:16`–`:107`; sender `:131`–`:178`). | Reuse only when a real streaming body boundary lands. The minimum buffered executor does not need a public stream/channel. |

Material owner defects are precise. `Event.Actor.wait` retains cancelled sender
handles until readiness/deregister/shutdown (`Event.Actor.Registration.Senders.swift:15`–`:23`,
`:47`–`:107`), and `arm` discards driver failures (`Event.Actor.swift:336`–`:345`).
`Kernel.Thread.Pool.run` can cancel only before admission; once a blocking call is
admitted, the checked continuation resumes only when it returns
(`Kernel.Thread.Pool+Run.swift:25`–`:43`, `:59`–`:82`). For `getaddrinfo`, the
repair must actively resume the cancelled awaiter and discard the eventual result
while the uninterruptible OS work continues inside finite worker/admission bounds.
The permit remains internally owned until the OS call really returns. Shutdown
must state whether it drains, has a deadline, or returns while bounded workers
finish; it must never claim the OS call was interrupted.

### Sockets and address/protocol owners

| Capability | Declaration evidence and properties | Utilization verdict |
|---|---|---|
| Socket operations | `Sockets.Capabilities` owns typed read/write/consuming close/readiness/connect/datagram send+receive over borrowed `Span.Raw` and typed `Sockets.Error` (`swift-sockets/Sources/Sockets/Sockets.Capabilities.swift:9`–`:180`). | Reuse exact capability set; no transport wrapper. |
| TCP resource | `Sockets.TCP.Connection` is `~Copyable, Sendable`, owns `Kernel.Descriptor` plus its IO witness, has borrowing partial read/write/half-close and consuming async close (`Sockets.TCP.Connection.swift:12`–`:141`). | Use as the owned transport and pooled resource; no client-local connection type. |
| Outbound connect | IPv4/IPv6 factories return `sending Connection`; the existing nonblocking algorithm sets nonblocking, connects, waits for write readiness, and checks `SO_ERROR` (`Sockets.TCP.Connection+Connect.swift:15`–`:136`). | Reuse algorithm. Add a production events-backed factory/bindings in `swift-sockets`. |
| Current production strategy | Only blocking IO ships (`Sources/Sockets/IO+Blocking.swift:5`–`:83`); its shared executor has no owned shutdown. The “reactive” factory is test-only and uses blocking `poll(2)` (`Tests/Sockets Tests/Sockets.Tests.ReactiveIO.swift:5`–`:76`). | Honest gap is events/completions binding, not socket law. |
| Socket semantic standard | `swift-sockets-standard` owns RFC 768/791/9293 names and aliases (`Sources/Sockets Standard/Sockets.TCP.swift:15`–`:93`), not execution. | Keep semantic/runtime roles separate. |
| URI target | `URI Standard` aliases RFC 3986/3987 (`swift-uri-standard/Sources/URI Standard/URIType.swift:30`–`:72`); RFC 3986 `URI` is `Hashable, Sendable, Codable`, parses typed scheme/authority/host/port/path/query/fragment, and exposes `pathAndQuery` (`swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.swift:73`, `:442`–`:503`, `:577`–`:721`). | Reuse absolute HTTPS target/authority/origin-form construction. Do not introduce a URL type. |
| URI policy | `swift-uri` owns typed authority replacement and explicitly leaves redirects to HTTP (`swift-uri/Sources/URI/URI.Canonicalization.swift:14`–`:66`). | Reuse only for consumer canonicalization; client target validation uses RFC 3986 values and does not depend on Router. |

The only domain-level platform branch found in socket runtime is the Darwin/Linux
`EINPROGRESS` spelling in `Sockets.TCP.Connection+Connect.swift:138`–`:147`.
Move that distinction into a typed L2 platform owner; it is not approval for a
domain `#if`. Main IO/kernel/socket targets otherwise avoid Foundation, Dispatch,
NIO, and third-party networking imports. Apple/Linux common production should use
kqueue/epoll; Windows is outside the minimum slice.

### Pool and connection reuse

`Pool.Bounded<Resource: ~Copyable>` already owns finite capacity, eager/lazy
creation, FIFO acquisition, typed wait cancellation/shutdown, metrics, exclusive
`inout sending` checkout, and structured idempotent shutdown without requiring
`Resource: Sendable` (`swift-pool-primitives/Sources/Pool Bounded Primitives/Pool.Bounded.swift:25`–`:90`,
`:103`–`:173`; `Pool.Bounded.Acquire.swift:50`–`:125`;
`Pool.Bounded+Acquire.swift:157`–`:198`;
`Pool.Bounded.Shutdown.swift:63`–`:210`). This is the generic resource-pool law.

Two live gaps must be resolved before HTTP reuse:

1. the public `check` closure is stored but never invoked; its only references are
   declaration/initialization (`Pool.Bounded.swift:74`–`:80`, `:112`–`:122`,
   `:151`–`:162`); and
2. destruction is synchronous (`@Sendable (consuming Resource) -> Void` at
   `:113`–`:116`, `:152`–`:156`), while a TLS connection can require async
   best-effort close.

Repair validation/disposition in the pool owner. Adjudicate whether async
destruction is coherent generic pool law; otherwise the HTTP client must close or
discard while checked out and return an explicitly unusable resource. RFC/HTTP
framing decides protocol reuse eligibility in `swift-http`; origin, TLS identity,
idle/lifetime bounds, and pool policy belong in the L4 HTTP client. Keep
`swift-pool-connections` empty because no independent connection-domain law has
been established—not because of consumer count.

### DNS semantic and runtime substrate

The DNS lane establishes a strict split between existing L2 wire law and the
missing L3 resolver runtime. `swift-domain-name-system` currently has no manifest,
source, or tests; its metadata mission claiming DNS record/message ownership
(`swift-domain-name-system/.github/metadata.yaml:3`) conflicts with the implemented
RFC owners and must be corrected before the reservation is filled.

| Capability | Declaration evidence and properties | Utilization verdict |
|---|---|---|
| DNS name | `RFC_1035.Domain` is `Sendable, Codable`, case-insensitive, has a typed ASCII parser, and enforces 255-byte/127-label/63-byte-label limits (`swift-rfc-1035/Sources/RFC 1035/RFC_1035.Domain.swift:39`–`:82`, `:128`–`:179`; `RFC_1035.Domain.Limits.swift:8`–`:16`). | Reuse exact wire name. Do not introduce DNS Name/Label. |
| DNS message | `RFC_1035.Message` is `Sendable, Hashable`, owns typed header/section arrays, serializes, and parses with typed errors (`RFC_1035.Message.swift:20`–`:115`, `:128`–`:180`; `RFC_1035.Message.Error.swift:18`–`:95`). | Reuse complete-message law; provider must bound bytes and validate query/response correspondence. |
| Compression safety | Internal `Wire.Reader` bounds primitive reads and rejects invalid/backward/looping/excess compression work (`RFC_1035.Wire.Reader.swift:20`–`:176`). | Reuse; no DNS parser/cursor. It copies `[Byte]` and is not streaming. |
| RR/TTL | `ResourceRecord` is Sendable/Hashable with raw `UInt32` TTL (`RFC_1035.ResourceRecord.swift:41`–`:105`); RFC 1034 separately defines `Resource.TTL` and other overlapping law (`swift-rfc-1034/Sources/RFC 1034/RFC_1034.Resource.TTL.swift:18`–`:63`; `RFC_1034.Query.RecordType.swift:18`–`:95`). | Converge/bridge existing overlap before resolver public API; never create a third TTL/type family. Tighten unchecked `UInt16(rdata.count)` construction. |
| A | RFC 1035 A currently stores four bytes pending canonical bridge (`RFC_1035.ResourceRecord.A.swift:20`–`:71`). | Bridge to canonical RFC 791 address in an owner/integration; no new IPv4 value. |
| AAAA | `RFC_3596.AAAA` is `Sendable, Hashable, Codable`, wraps RFC 4291 address, and parses exactly 16 bytes (`swift-rfc-3596/Sources/RFC 3596/RFC_3596.AAAA.swift:29`–`:99`). RFC 1035 currently leaves TYPE 28 opaque. | Dispatch bounded opaque RDATA through this owner; no AAAA duplicate. |
| EDNS(0) | `RFC_6891.OPT` is Sendable/Hashable with payload/version/DO/options and serialization (`swift-rfc-6891/Sources/RFC 6891/RFC_6891.OPT.swift:20`–`:151`). | Parser/bridge is partial and unnecessary for system-resolver first slice. Improve before direct wire resolver. |
| Domain presentation | `Domain Standard.Domain` wraps RFC 1123 and optionally RFC 1035 (`swift-domain-standard/Sources/Domain Standard/Domain.swift:8`–`:75`, `:79`–`:250`). Arbitrary wire labels need not convert. | Keep presentation/IDNA/application semantics distinct from DNS wire identity. Its Error needs explicit Sendable review. |
| URI host | RFC 3986 Host distinguishes IPv4, IPv6, and registered name (`swift-rfc-3986/Sources/RFC 3986/RFC_3986.URI.Host.swift:9`–`:67`, `:251`–`:347`). Registered-name grammar is broader than DNS. | HTTPS target validation must convert/validate hostname/IDNA before DNS and trust. IP literals bypass DNS. |
| IP addresses | RFC 791 IPv4 is Copyable/Hashable/Sendable/Codable with typed byte parsing (`swift-rfc-791/Sources/RFC 791/RFC_791.IPv4.Address.swift:50`–`:167`); RFC 4291 IPv6 is Copyable/Sendable with typed binary parsing (`swift-rfc-4291/Sources/RFC 4291/RFC_4291.IPv6.Address.swift:76`–`:189`). | Reuse. A provider-neutral ordered IPv4-or-IPv6 sum is a real gap in `swift-ip-address`, not DNS/HTTP. |
| System resolver SDK | Exact platform-owner inspection found no typed `getaddrinfo`, `freeaddrinfo`, `gai_strerror`, or owned `addrinfo` chain. | Add typed ownership to ISO 9945/correct L2 platform owner; C imports and freeing stay there. |
| DNS cache storage | `Cache.Bounded` is a synchronized insertion-order finite map without compute/waiters (`swift-cache-primitives/Sources/Cache Primitives/Cache.Bounded.swift:12`–`:180`); generic `Cache` provides unbounded async compute-once/cancellation (`Cache.swift:60`–`:185`); `TTL<Instant>` is Sendable and checks expiration (`swift-time-to-live/Sources/Time To Live/TTL.swift:12`–`:30`). | Reuse storage/time. Do not create map/mutex/clock/continuations. DNS RRset/negative/CNAME law remains domain-specific. |

RFC 1035 has 65 deterministic tests, including captured Cloudflare message bytes
(`Tests/RFC 1035 Tests/Support/DNSWireVectors.swift:16`–`:19`, `:55`–`:80`),
exact parse/round-trip (`RFC_1035.Message.CapturedVectors.Tests.swift:24`–`:151`),
and pointer-loop/truncation attacks (`RFC_1035.Wire.Compression.Tests.swift:23`–`:130`).
These are strong fixtures but not official RFC vectors. RFC 3596 has exact binary
and reverse-name tests (`Tests/RFC_3596_Tests.swift:16`–`:134`); RFC 6891 currently
has serialization-focused tests (`Tests/RFC_6891_Tests.swift:16`–`:200`). Main
DNS/RFC/domain/URI/IP/cache/TTL sources have no Foundation or platform imports.

For the first slice, system resolution is the correct default because it preserves
hosts, NSS, search domains, and split-DNS policy. Add a minimal provider-neutral
resolver witness to `swift-domain-name-system` only after correcting its mission,
reusing `RFC_1035.Domain` and canonical IP values. A dedicated L3
`swift-domain-name-system-iso-9945` integration composes that witness with typed
ISO 9945 host resolution, `swift-ip-address`, and bounded `Kernel.Thread.Pool`.
It must not expose `addrinfo` or import C.

Two integration gaps need architecture adjudication:

- ISO 9945 socket addresses use raw network-order storage
  (`swift-iso-9945/Sources/ISO 9945 Kernel Socket Address/ISO 9945.Kernel.Socket.Address.IPv4.swift:9`–`:68`;
  IPv6 `:9`–`:62`), but no canonical RFC 791/4291 bridge exists. Prefer a dedicated
  recipient-provider integration such as `swift-sockets-ip-address`; do not
  hand-roll it in HTTP or hide a general bridge in DNS.
- address ordering belongs to the resolver result, while Happy Eyeballs/connect
  race/deadline policy belongs to the L4 client. The ordered IP-family sum should
  improve `swift-ip-address` rather than become a DNS/HTTP type.

Keep `swift-dns-cache` empty in the system-resolver first slice: `getaddrinfo`
does not provide trustworthy TTL and the OS already owns system cache policy.
Direct positive/negative caching needs coherent RRset and RFC 2308 law, which is
not currently implemented. A later explicit sockets resolver is independently
selectable—never a hidden fallback—and requires production cancellable socket IO,
explicit nameserver configuration, source/ID/QR/opcode/question/rcode validation,
TC-to-length-prefixed-TCP fallback, CNAME/A/AAAA handling, and bounded EDNS parsing.

### TLS 1.3, crypto, certificates, and system trust

The live RFC packages already own almost all TLS wire vocabulary:

| Capability | Declaration evidence and properties | Utilization verdict |
|---|---|---|
| TLS record | `RFC_8446.Record` is public `Sendable, Hashable`, bounds the fragment, stores `[Byte]`, and validates complete binary framing (`swift-rfc-8446/Sources/RFC 8446/RFC_8446.Record.swift:20`–`:71`, `:92`–`:161`). | Reuse and improve its owner for consumed-boundary/incremental framing. No second record header/value. |
| Key schedule | `RFC_8446.KeySchedule` and its `[Byte]` witness closures own early/handshake/master/application/update/resumption and key/IV derivation (`RFC_8446.KeySchedule.swift:18`–`:27`; `RFC_8446.KeySchedule.Witness.swift:20`–`:63`; `RFC_8446.KeySchedule.Stages.swift:24`–`:185`). Witness is currently non-Sendable and values are Copyable/Escapable. | Reuse law; bind sanctioned Crypto through a provider adapter and improve secret ownership rather than duplicate derivation. |
| Transcript | `RFC_8446.Transcript` is `Sendable, Hashable` but copies bytes (`RFC_8446.Transcript.swift:20`–`:56`). | Reuse semantics; improve storage/secret lifecycle only in owner. |
| Cipher suites | RFC identifiers classify AES-GCM, ChaCha20-Poly1305, and CCM (`RFC_8446.CipherSuite.swift:20`–`:108`). | Identifiers are not implementations. Configure only backend-supported suites; reject unsupported CCM rather than invent crypto. |
| Certificate handshake | Certificate entries and CertificateVerify are bounded typed wire values (`RFC_8446.Handshake.Certificate.swift:20`–`:112`; `RFC_8446.Certificate.Entry.swift:20`–`:71`; `RFC_8446.CertificateVerify.swift:20`–`:66`). | Reuse wire law; X.509 parsing/chain/signature/identity remain gaps. |
| Alerts | Public Sendable wire values (`RFC_8446.Alert.swift:20`–`:79`). | Reuse; runtime maps state failures to these values. |
| SNI | `RFC_6066.HostName` is bounded ASCII `[Byte]` (`swift-rfc-6066/Sources/RFC 6066/RFC_6066.HostName.swift:20`–`:83`); `ServerNameList` validates uniqueness and emits/parses RFC 8446 extensions (`RFC_6066.ServerNameList.swift:21`–`:164`). | Reuse. URI/host layer must reject IP literals because HostName records that limitation at `:35`–`:43`. |
| ALPN | `RFC_7301.ProtocolIdentifier` bounds `[Byte]` length (`swift-rfc-7301/Sources/RFC 7301/RFC_7301.ProtocolIdentifier.swift:21`–`:73`); extension validates/emits/parses and includes HTTP identifiers (`RFC_7301.Extension.swift:21`–`:223`). | Reuse exact model; minimum client offers/selects `http/1.1`. |
| Vectors | RFC 8448 message fixtures are tested (`Tests/RFC 8446 Tests/RFC_8446_RFC8448_Message_Tests.swift:18`–`:185`); key schedule/transcript/secret/write-key/Finished/resumption vectors are tested (`RFC_8446_RFC8448_KeySchedule_Tests.swift:23`–`:264`). | Extend these official vectors; no new fixture format. |

RFC 8446 core is intentionally crypto-neutral; Apple Crypto appears only in the
test target (`swift-rfc-8446/Package.swift:16`–`:20`, `:36`–`:79`). The test
witness imports Foundation `Data` and is not a production adapter
(`Tests/RFC 8446 Tests/RFC_8446_CryptoWitness.swift:13`–`:63`). Main RFC sources
have no Foundation/platform imports and generally expose Sendable semantic values,
but use Copyable/Escapable arrays rather than move-only secret owners.

The honest TLS/certificate gaps are incremental `TLSCiphertext`/
`TLSInnerPlaintext` consumption; AEAD record sequence/nonce lifecycle; client
handshake state; key-share/signature/backend witnesses; Foundation-free DER and
certificate profile law; chain construction and signature/policy validation;
serverAuth EKU/key usage; DNS hostname verification; system-anchor providers; and
structured cancellation/shutdown/secret destruction. They belong in RFC,
`swift-transport-layer-security`, certificate, platform, and dedicated integration
owners—not the HTTP client.

### Sanctioned Apple Crypto dependency utilization

The reviewed upstream release is official `apple/swift-crypto` **4.3.0**, commit
`fa308c07a6fa04a727212d793e761460e41049c3` dated 2026-03-02. Moving `main`
was observed at `47d3869…` on 2026-07-22 but is not the pin. The older local
`swiftlang/swift-crypto` checkout at 3.12.5 is stale and is not architecture
evidence.

| Capability / cost | Exact upstream evidence | Utilization verdict |
|---|---|---|
| Products/dependencies | Products are `Crypto`, legacy `_CryptoExtras`, and `CryptoExtras` (`/private/tmp/swift-crypto-4.3.0-wave3/Package.swift:88`–`:98`). The only package dependency is `apple/swift-asn1` from 1.2 (`:248`–`:256`). `CryptoExtras` always adds BoringSSL, Crypto, and SwiftASN1 (`:181`–`:202`). | Minimum TLS should depend on `Crypto`, adding `CryptoExtras` only if RSA certificate verification is required and adjudicated. |
| Backend/platforms | On Apple, `Crypto` delegates to CryptoKit; Linux/Android/Windows/WASI/OpenBSD build vendored BoringSSL/shims/wrapper/CXKCP (`Package.swift:43`–`:73`; BoringSSL commit `0226f304…` at `:16`–`:23`; README `:25`–`:37`). | Accept as the sanctioned backend/security-maintenance cost. Do not copy code. |
| Hash/HMAC/HKDF | `SHA256`/`SHA384` conform to Sendable `HashFunction` and accept raw buffers (`Sources/Crypto/Digests/HashFunctions.swift:57`–`:172`); HMAC is Sendable (`Sources/Crypto/Message Authentication Codes/HMAC/HMAC.swift:54`–`:178`); HKDF is Sendable (`Sources/Crypto/Key Derivation/HKDF.swift:44`–`:168`). | Required TLS key-schedule adapter APIs. Translate to/from Institute Byte/Span without exposing backend data/errors. |
| Symmetric/key agreement | `SymmetricKey` is `ContiguousBytes, Sendable` (`Sources/Crypto/Keys/Symmetric/SymmetricKeys.swift:69`–`:114`); X25519 keys are Sendable/ContiguousBytes and yield Sendable `SharedSecret` (`Sources/Crypto/Keys/EC/X25519Keys.swift:35`–`:129`; `Sources/Crypto/Key Agreement/DH.swift:44`–`:85`). | Use X25519 initially; keep private keys/secrets behind Institute move-only resource ownership. |
| AEAD | AES.GCM API/SealedBox is `Sources/Crypto/AEADs/AES/GCM/AES-GCM.swift:30`–`:211`; ChaChaPoly is `Sources/Crypto/AEADs/ChaChaPoly/ChaChaPoly.swift:25`–`:179`. | AES-GCM required; ChaCha optional. Backend has no AES-CCM public implementation, so remove CCM from initial supported-suite claims. |
| Certificate signatures | ECDSA/Ed25519 exist in Crypto; RSA-PSS/PKCS1 is in CryptoExtras `_RSA`. | Certificate algorithm set must follow separately adjudicated WebPKI fixtures, not enable every RFC identifier. |
| Tests/security | RFC 5869 HKDF vectors are in `Tests/CryptoTests/Key Derivation/HKDFTests.swift:25`, `:126`–`:142`; ECDSA Wycheproof at `Tests/CryptoTests/Signatures/ECDSA/ECDSASignatureTests.swift:51`–`:183`; the release carries broad AEAD/key-agreement/signature/Wycheproof resources. Security reporting and CryptoKit coordination are `SECURITY.md:5`–`:11`; test/security policy is README `:61`–`:71`, `:105`–`:137`. | Reuse upstream security evidence; Institute adapter still needs RFC 8448, record tamper, and interop gates. |

Boundary-scope finding: upstream Crypto is **not Foundation-free at its
source/API boundary** and contains direct platform C imports. AES-GCM and
ChaChaPoly import Foundation (`AES-GCM.swift:30`–`:32`;
`ChaChaPoly.swift:25`–`:32`), HMAC imports Darwin/Glibc/Musl directly
(`HMAC.swift:24`–`:28`), AEAD consumes `DataProtocol` and returns `Data`, and
non-Embedded `CryptoKitMetaError` is `typealias any Error`
(`Sources/Crypto/CryptoKitErrors.swift:93`–`:121`). Its types are Sendable but
Copyable/Escapable, with no `~Copyable`, `~Escapable`, or `sending` API.

Canonical [ARCH-LAYER-007] and [PLAT-ARCH-008j] govern Institute package main
targets and Institute platform-C import authority. They do not govern the source
internals of a sanctioned external backend. Every Institute main target—including
`swift-transport-layer-security-crypto`—imports no Foundation or platform C; the
adapter imports only `Crypto` plus Institute modules. No Foundation, `Data`,
`DataProtocol`, `[UInt8]`, Crypto key/error type, or untyped throw escapes its
public or domain surface. The accurate product claim is **Foundation-free Institute
main targets/API with a sanctioned Apple Crypto backend**. It carries no
product-level transitive-purity or Embedded-compatibility promise; that promise is
explicitly waived for this sanctioned backend without weakening the canonical
rules themselves.

Apple Crypto 4.3.0 declares `apple/swift-asn1` unconditionally in its package graph
(`Package.swift:248`–`:256`), although only `CryptoExtras` imports the SwiftASN1
product (`:181`–`:202`). Sanctioning the unmodified package therefore sanctions
resolution/fetching of that pinned transitive graph, not direct Institute import,
use, API authority, or certificate-architecture authority for SwiftASN1. A later
clean-room resolution gate may prove product pruning, but the architecture does
not assume it. `CryptoExtras` remains outside the first TLS slice and requires the
certificate/RSA gate.

This is not a reason to leak `Data`, `UInt8`, backend keys, or untyped errors.
The adapter copies only at the unavoidable backend boundary, translates into
typed Sendable Institute failures, and contains key/secret lifetimes behind
move-only wrappers. No direct Apple product import belongs in RFC 8446, TLS public
API, HTTP, or Workspace.

### Certificate and trust adaptation disposition

Direct use of neither Apple certificate package is sanctioned. Their material
Foundation-free adaptation is selected under truthful fork heritage; their current
products and repository cuts remain evidence, not dependency or API authority:

- `apple/swift-asn1` 1.6.0 (`9f542610…`) has a complete DER parser/serializer
  and Sendable tree (`SwiftASN1/DER.swift:563`–`:670`, `:921`–`:1017`;
  `ASN1.swift:399`–`:439`), but uses `[UInt8]`, whole-tree/COW allocation,
  implicit Copyable/Escapable values, untyped throws, and a PEM target importing
  Foundation. Direct dependency is rejected. A material Foundation-free L2
  ASN.1/DER adaptation is selected and requires truthful fork heritage after
  resolving every canonical identity collision.
- `apple/swift-certificates` 1.18.0 (`24ccdeee…`) has a strong Sendable certificate
  model and async verifier (`Sources/X509/Certificate.swift:22`–`:109`,
  `:360`–`:464`; `Sources/X509/Verifier/Verifier.swift:17`–`:33`), but exposes
  Foundation `Date`, imports Security/Darwin/Glibc/Musl in server identity policy
  (`ServerIdentityPolicy.swift:15`–`:29`, `:31`–`:86`, `:156`–`:179`), and its
  trust loader imports Foundation/Dispatch and hard-codes two Linux paths
  (`TrustRootLoading.swift:15`–`:106`). Its RFC 5280 policy deliberately does not
  police KeyUsage (`RFC5280Policy.swift:21`–`:43`) and it lacks a complete built-in
  TLS serverAuth EKU policy. Do not adopt this mixed L2/L3/platform package cut or
  claim it alone supplies HTTPS WebPKI. A material Foundation-free L3 certificate
  runtime adaptation is selected, with RFC 5280 law improved in its existing L2
  owner and platform trust plus Crypto bindings extracted.

Targeted platform-owner inspection found no existing Institute public
`SecTrust`/`SecCertificate`/system-root API. Darwin must first gain a typed
Security.framework surface in its L2 platform owner, followed by a dedicated L3
recipient-provider trust integration. Linux distribution root discovery belongs
in a dedicated L3 provider using Kernel/File/Path APIs, never L2 Linux law or raw
Glibc/Musl. Chain, signature, serverAuth/EKU/keyUsage, and DNS hostname policy stay
Foundation-free semantic/runtime ownership.

### HTTP semantic model, HTTP/1.1 framing, bodies, and adjuncts

| Capability | Declaration evidence and properties | Utilization verdict |
|---|---|---|
| Request | `HTTP.Request` is `Sendable, Equatable, Hashable, Codable`; it stores typed method/URI target/headers and `[Byte]?` body (`swift-rfc-9110/Sources/RFC 9110/HTTP.Request.swift:62`–`:104`) and constructs absolute URIs (`:132`–`:169`). | Exact provider seam. Do not create a client request or body-byte model. |
| Response | `HTTP.Response` is `Sendable, Equatable, Hashable, Codable` with typed status/headers and `[Byte]?` body (`HTTP.Response.swift:57`–`:92`). | Exact executor result. Preserve status/body without provider semantics. |
| Repeated fields | `HTTP.Headers` is Sendable, stores ordered first-seen names plus all values, and appends rather than replaces (`HTTP.Headers.swift:44`–`:69`, `:141`–`:147`); repeated access is `HTTP.Response.swift:101`–`:140`. | Sufficient for repeated `Link` values. Do not flatten to a dictionary. Note it preserves per-name values, not an arbitrary global `A,B,A` interleaving. |
| Umbrella | HTTP Standard aliases/reexports RFC 9110/9111/9112 (`swift-http-standard/Sources/HTTP Standard/HTTP.swift:13`–`:20`; `exports.swift:13`–`:15`; manifest `Package.swift:13`–`:52`). | Use published `HTTP` namespace and values. |
| Whole-buffer HTTP/1.1 | RFC 9112 deserializer accepts a complete `[Byte]` (`swift-rfc-9112/Sources/RFC 9112/HTTP.Message.Deserializer.swift:204`–`:269`), handles fixed/chunk/until-close at `:284`–`:315`, and has typed errors `:330`–`:339`. | Improve RFC 9112 with bounded incremental need-more/consumed framing. No client-local parser. |
| Parser defect | Message parser allocates `[Byte]` per line (`HTTP.Message.Parser.swift:20`–`:85`) and declares but does not enforce `lineTooLong` (`:126`–`:130`). Chunked consumed count uses all remaining data (`Deserializer.swift:296`–`:310`); until-close buffers all (`:312`–`:315`). | Owner defects block safe reuse; repair with cursor/span/buffer substrate and explicit line/head/body bounds. |
| Serializer | Serializer emits the entire request/body and preserves supplied target (`HTTP.Message.Serializer.swift:17`–`:69`); it does not convert absolute-form to origin-form or synthesize Host/framing. | Extend RFC 9112/HTTP drive according to semantic ownership; no GitHub/client serializer. |
| HTTP body coding | `swift-http-body` owns typed buffered body coder protocols/witnesses over `[Byte]` and request helpers; its manifest separates optional JSON (`Package.swift:14`–`:53`). | Reuse semantic coding names. It is not streaming/backpressure and the minimum executor need not import JSON. |
| Host package | `HTTP.Host.Allowlist` is server-side authorization. | Do not reuse for outbound authority or Host synthesis. |
| Redirect package | `swift-http-redirect` is server middleware. | Client defaults to no redirects. Later outbound redirect policy belongs in L4 client, not this server package. |
| Cookies/session | Implemented Sendable domain values; not required for public inventory GETs. | Do not pull into the first slice. |
| Compression/HTTP2/HTTP3 | Empty reservations. | Do not fill for the minimum HTTP/1.1 slice. |

The `swift-http` reservation remains the coherent L3 owner for incremental
request/response exchange, body backpressure, protocol reuse eligibility, and
orderly protocol shutdown over an injected byte duplex. Its emptiness is an
honest runtime gap; it does not justify duplicating RFC 9110/9112 semantic law.

### Known consumer and portability evidence

Narrow manifest/source evidence found `swift-file-system` as a production
`swift-io` consumer, but no production package outside `swift-sockets` importing
the Sockets product and no external live `Pool.Bounded` consumer. This is
compatibility evidence only; consumer count is not a decomposition criterion.
RFC 1035 is consumed by RFC 1034/1123/3596/6891, Domain Standard, RFC 3986 Host,
and internal aggregation. URI Standard has many production consumers. The public
GitHub HTTP package consumes HTTP Standard directly, which is why the executor
must preserve the published RFC 9110 values rather than adapt through a second
message family.

The common production IO substrate is Darwin kqueue plus Linux epoll; Linux also
has optional io_uring. Socket runtime and Institute semantic packages are
Foundation-free and portable across the required Apple/Linux first slice, subject
to the identified typed `EINPROGRESS` repair. Windows socket completion is future
scope. The sanctioned Apple Crypto backend supports Apple and Linux among its
broader platform set, but carries the explicit external Foundation/platform-C
boundary scope recorded above. Certificate trust-source parity remains unproved and is
therefore a blocking gap rather than an inferred portability claim.

## Upstream dependency, overlap, and heritage dispositions

| Upstream | Capability and overlap | Utilization / heritage disposition | Name-collision operation |
|---|---|---|---|
| `apple/swift-crypto` 4.3.0 `fa308c07…` | Sanctioned primitive backend; overlaps only the empty Institute reservation, not implemented source. | Direct official dependency. No production source copy/adaptation, so no fork-as-heritage trigger and no history merge. | Before publication, separately authorize a non-destructive rename of the unrelated empty Institute `swift-crypto` reservation to a non-conflicting identity, preserving redirects. Manifest URL remains `https://github.com/apple/swift-crypto.git`. |
| `apple/swift-asn1` 1.6.0 `9f542610…` | Strong DER implementation overlaps empty/proposed Institute ASN.1 and RFC 5280 work; current products do not match Byte/typed-throws/ownership rules directly. | Selected material Foundation-free adaptation into the L2 ASN.1/DER specification owner. Because Apple Crypto resolves identity `swift-asn1`, publish the renamed true fork as `swift-asn1-standard`; direct product use is rejected. | Audit local and remote `swift-asn1` and `swift-asn1-standard` identities, then resolve any reservation non-destructively before the true fork; never merge unrelated histories. |
| `apple/swift-certificates` 1.18.0 `24ccdeee…` | Strong certificate/verifier fixtures, but its repo cut mixes L2 model, L3 policy, platform imports, Foundation, and incomplete HTTPS policy; overlaps empty Institute certificate/RFC5280 reservations. | Selected material Foundation-free adaptation into an L3 certificate runtime, while existing `swift-rfc-5280` owns profile law and Crypto/trust integrations are extracted. Direct product use and clean-room rewrite are rejected. | Rename the unrelated empty Institute reservation before the true fork; preserve redirects; never merge histories. |

No fork, rename, transfer, archive, delete, publication, or manifest mutation is
authorized here. The Apple Crypto collision operation is required but remains a
separate external mutation gate.

## Existing-owner mapping for every proposed Wave-3 concept

| Proposed package/type/operation | Existing owner evidence | Disposition after utilization |
|---|---|---|
| Networking byte / body octet | `Byte`, `[Byte]?` HTTP bodies | **Delete proposal**; reuse exact values. |
| Borrowed buffer/body reader | `Swift.Span<Byte>`, Cursor, move-only Buffer owners | **Delete generic nominal**; extend only protocol-specific scoped operations if proved necessary. |
| Receive/transcript buffer | Buffer linear/ring + spans | **Delete networking buffer**; reuse actor-confined primitives. |
| Generic incremental parser | Cursor/Binary machine exist; parser-machine “Incremental” is edit memoization | **Delete generic parser package/type**; add bounded protocol-specific decoder operations to RFC owners. |
| Streaming/backpressure base | `Async.Channel.Bounded` | **Defer** until a streaming public body is required; no minimum-slice stream. |
| IO/duplex witness | `IO<Capabilities>` and socket partial reads/writes | **Delete new generic IO base**; TLS/HTTP may own narrow domain witnesses only when recipient-owned. |
| Selector/reactor/event loop | Kernel.Event.Source + Event.Actor + polling executor | **Delete**; repair cancellation/arm/shutdown in existing owners. |
| Proactor | Completion.Actor/io_uring | **Delete**; reuse later via socket factory. |
| Socket connection/connect/read/write/close | `Sockets.TCP.Connection`, existing nonblocking connect | **Delete**; fill production events binding in `swift-sockets`. |
| Deadline/timeout/cancellation model | Clock.Continuous.Deadline + Async.Lifecycle.Error + task cancellation | **Delete generic networking time system**; compose phase-specific typed errors. |
| getaddrinfo worker pool | Kernel.Thread.Pool | **Delete DNS pool**; improve post-admission cancellation and bounded discard. |
| DNS name/message/A/AAAA/EDNS | RFC 1035/3596/6891 | **Delete duplicates**; compose exact semantic owners. |
| DNS runtime interface/policy | Empty `swift-domain-name-system` | **Retain owner gap**, narrowed by DNS lane evidence. |
| DNS cache | Empty `swift-dns-cache` plus generic cache/time primitives | **Retain only coherent DNS TTL/coalescing law**, reusing generic storage/time. |
| TLS record/handshake/schedule/transcript/alert | RFC 8446 | **Delete duplicate models**; improve incremental/ownership seams in RFC owner. |
| SNI/ALPN | RFC 6066/7301 | **Delete duplicate types**; use exact extensions. |
| Crypto primitives/provider implementation | sanctioned `apple/swift-crypto` | **Delete Institute implementation/fork**; land one adapter boundary after identity resolution. |
| TLS-to-Crypto provider adapter | No existing Institute adapter | **Retain one L3 integration gap**: `swift-transport-layer-security-crypto` -> TLS recipient + official Apple Crypto provider. |
| ASN.1/DER and X.509 | Institute owners empty; material Apple adaptations selected | **Retain selected owner gaps**: truthful L2 ASN.1 fork, improve RFC 5280, truthful L3 certificate fork, and extracted Crypto/trust integrations after identity/heritage gates. |
| TLS runtime state/record protection | Empty `swift-transport-layer-security` | **Retain coherent L3 owner gap**. |
| System trust | Platform SDK surface and Linux file/path primitives are partial; certificate verifier absent | **Retain dedicated integrations**, exact package cut pending trust adjudication. |
| HTTP messages/headers/status/body bytes | RFC 9110 + HTTP Standard | **Delete duplicates**; exact GitHub closure types. |
| HTTP/1.1 incremental framing | RFC 9112 is partial | **Improve RFC 9112**; no client parser. |
| HTTP drive | Empty `swift-http` | **Retain coherent L3 owner gap** over injected duplex. |
| Generic connection pool | Pool.Bounded | **Delete `swift-pool-connections` fill**; repair check/disposition in generic owner. |
| HTTP pool policy | No existing L4 client | **Retain in L4 `swift-components/swift-http-client`**, using Pool.Bounded. |
| Graceful shutdown package | Empty reservation; IO/pool/socket own lifecycle | **Delete workaround**; explicit idempotent HTTP.Client shutdown composes owner shutdowns. |
| HTTP client executor/lifecycle | No existing generic outbound client | **Retain one L4 component**, product `HTTP Client`, module `HTTP_Client`, actor `HTTP.Client`. |
| Platform-specific HTTP client packages | No evidence yet that a separate package is needed beyond trust integrations | **Delete from initial plan pending proof**; let L4 client receive/inject trust integration without multiplying constructors. |

## Rejected duplication list

Wave 3 explicitly rejects:

- `Data`, `[UInt8]`, or a new octet in public/main networking APIs;
- a nominal borrowed-byte/body type that duplicates `Span<Byte>`;
- HTTP- or TLS-local generic linear/ring buffers, cursors, serializers, or parser
  machines;
- a public streaming body merely to serve the current bounded `[Byte]?` seam;
- another IO protocol, selector, event loop, custom executor, proactor, timer wheel,
  scheduler, cancellation taxonomy, deadline, blocking-worker pool, fd, syscall,
  socket address, or TCP connection;
- client-local DNS name/message/A/AAAA/EDNS, TLS record/handshake/schedule/SNI/ALPN,
  URI, HTTP request/response/header/body, or connection-pool models;
- `swift-pool-connections`, `swift-graceful-shutdown`, HTTP/2, HTTP/3, compression,
  cookies, session, or redirect dependencies in the first slice;
- an Institute fork/copy/reimplementation of cryptographic primitives;
- an application-local trust store, guessed root path in L2 platform law, disabled
  certificate/hostname validation, system-TLS shortcut, URLSession, Foundation,
  AsyncHTTPClient/NIO, curl/Process, Vapor, or Router dependency.

## Exact deletions and amendments required in the current architecture record

Before the architecture can be re-reviewed, amend
`native-networking-wave-3-implementation-heritage-dependency-record.md` as follows:

1. delete the Institute `swift-crypto` true-fork/provider plan, its `Cryptography`
   product, retained crypto-C implementation, and all corresponding heritage/DAG
   edges; replace them with the sanctioned direct Apple dependency through one
   `swift-transport-layer-security-crypto` recipient-then-provider adapter and an explicit empty-reservation identity
   disposition;
2. delete direct current Apple ASN.1/certificate dependencies and a clean-room
   DER/certificate security rewrite; retain selected truthful Foundation-free
   adaptations into separate L2 ASN.1 and L3 certificate owners, improving rather
   than duplicating existing `swift-rfc-5280`;
3. delete any new byte/body/borrowed-buffer, generic parser/serializer, stream,
   IO/duplex base, selector/reactor/event loop/executor, cancellation/timeout,
   DNS-worker, socket-connection, generic lifecycle, or generic connection-pool
   concept;
4. keep `swift-pool-connections` empty from independent semantic law, and route
   the concrete fixes to `Pool.Bounded` validation/disposition instead;
5. replace “socket async runtime gap” with the narrow production
   events-backed `Sockets.Capabilities` factory/binding, `Event.Actor` hygiene,
   and typed `EINPROGRESS` platform-owner repair;
6. replace “DNS worker implementation” with `Kernel.Thread.Pool` owner repair and
   the exact non-interruptible cancellation contract;
7. constrain RFC 9112 work to bounded incremental framing over existing
   Cursor/Span/Buffer and `swift-http` work to the transport-neutral HTTP drive;
8. constrain TLS work to incremental record boundaries, runtime state/record
   protection, backend witnesses, ownership, cancellation, and shutdown while
   reusing all RFC 8446/6066/7301 values and vectors;
9. delete separate Darwin/Linux HTTP-client constructor packages from the first
   plan unless later evidence proves a distinct cross-package integration beyond
   the trust provider itself;
10. preserve `swift-components/swift-http-client` as the only L4 assembly, but
    narrow it to concrete provider selection, origin/TLS identity/pool/deadline/
    bound policy, the published executor seam, and structured shutdown.

## Smallest remaining gap set

The minimum generic HTTPS GET executor requires only these unresolved owner
changes, in dependency order:

1. repair `Event.Actor` cancelled-waiter removal, arm-error propagation, and
   deterministic owned shutdown;
2. fill production event-backed `Sockets.Capabilities` bindings/factory and move
   the `EINPROGRESS` distinction to the typed platform owner;
3. repair `Kernel.Thread.Pool` so cancelled system-resolver awaiters resume while
   finite uninterruptible work safely completes and is discarded;
4. fill only the missing system DNS runtime/provider operations proved by the DNS
   lane, reusing RFC wire, IP, socket, time, and generic cache primitives; keep
   the DNS cache and direct sockets resolver out of the first slice;
5. improve RFC 8446 incremental record consumption/secret ownership and fill the
   TLS 1.3 client state/AEAD runtime in `swift-transport-layer-security`, binding
   only sanctioned Apple Crypto algorithms;
6. implement the selected truthful ASN.1/certificate adaptations, RFC 5280
   improvement, extracted certificate-Crypto integration, full TLS server policy,
   hostname verification, and independent Darwin/Linux system-trust integrations;
   repository/identity/heritage operations remain separately blocked;
7. improve RFC 9112 bounded incremental framing and fill the transport-neutral
   `swift-http` HTTP/1.1 drive;
8. repair `Pool.Bounded` validation/resource disposition;
9. compose one L4 `HTTP.Client` with absolute HTTPS target validation, DNS,
   socket/TLS/HTTP, phase deadlines, bounded response bytes, origin/TLS-aware
   pooling, no redirects by default, cancellation, and explicit idempotent
   shutdown.

The first vertical slice needs no public stream, compression, cookies, redirects,
HTTP/2, HTTP/3, provider knowledge, JSON, Router, or Workspace/GitHub dependency.

## Workspace seam pressure test

The retained public shape remains source-compatible with the published provider:

```swift
public actor HTTP.Client {
    public func execute(
        _ request: HTTP.Request
    ) async throws(HTTP.Client.Error) -> HTTP.Response

    public nonisolated var executor: HTTP.Client.Executor { get }
    public func shutdown() async
}

extension HTTP.Client {
    public struct Executor: Sendable {
        public let execute: @Sendable (
            HTTP.Request
        ) async throws(HTTP.Client.Error) -> HTTP.Response
    }
}
```

The provider-neutral L4 actor is `HTTP.Client`, its nested concrete execution
witness is `HTTP.Client.Executor`, and the provider adapter remains
`GitHub.HTTP.Client`. Provider-nested `HTTP.Client.GitHub`, generic
`HTTP.Client<GitHub>`, and an evidence-free `HTTP.Client.Protocol` are rejected:
they would respectively misplace provider semantics, mis-model provider policy
as a transport parameter, or duplicate the already-accurate `Executor` witness.
`GitHub.HTTP.Client` retains `HTTP` and has no `GitHub.Client` alias because HTTP
construction and decoding are the adapter's mission. A future root
`GitHub.Client` would be a separate transport-neutral aggregate, not an adapter
rename.

`Executor` has no lifecycle or shutdown authority. Its memory-safe closure may
strongly retain the actor. Explicit shutdown is idempotent, and every call through
any retained executor after shutdown throws `.shutdown`. It is not weak or
“non-owning.” The typed Sendable error surface uses nested single-concept cases:
`.target(Target.Error)`, `.request(Request.Error)`, `.timeout(Timeout.Phase)`,
`.limit(Limit)`, plus domain failures and `.shutdown`; there is no `withClient`.

The executor validates an absolute `https` URI, derives the origin and origin-form
request target, resolves the host, connects TCP, performs TLS 1.3 with SNI,
`http/1.1` ALPN, hostname verification and system trust, drives one bounded HTTP/1.1
exchange, preserves status/repeated fields/body bytes, and returns the exact
`HTTP.Response`. Cancellation actively resumes the caller, closes/discards the
connection, and prevents reuse. The response limit is checked during incremental
receipt, never after unbounded buffering. Redirects are disabled. Provider headers,
tokens, pagination, JSON, Link parsing, and 404 meaning remain outside networking.

This pressure test introduces only `HTTP.Client` and its nested configuration,
error, executor, and internal owned composition state. Every lower operation maps
to an existing owner or one of the explicit honest gaps above.

## Compact adjudication packet

### 1. Delete from the old plan

Delete proposed networking-owned byte/body/borrowed-buffer types, generic
incremental parser/serializer or stream bases, a second IO/duplex abstraction,
selector/reactor/event loop/executor/proactor, timer/timeout/cancellation system,
DNS worker pool, socket connection, generic lifecycle package, and generic
connection pool. Keep `swift-pool-connections`, `swift-graceful-shutdown`, the DNS
cache, direct sockets resolver, compression, HTTP/2, HTTP/3, cookies, sessions,
and redirects out of the first slice. Delete duplicate DNS names/messages/A/AAAA/
TTL, TLS records/handshakes/transcript/key schedule/alerts/SNI/ALPN, URI/IP, and
HTTP request/response/header/body values. Delete the Institute crypto primitive
implementation/fork, Apple ASN.1/certificate forks as decided architecture, and
separate Darwin/Linux HTTP-client constructor packages.

### 2. Repair exact existing owners

| Owner | Required repair before first slice |
|---|---|
| `swift-io` | Remove cancelled `Event.Actor` waiters, propagate arm failure, and provide/compose deterministic idempotent owned-reactor shutdown. |
| `swift-sockets` + typed platform owner | Ship the production event-backed `Sockets.Capabilities` binding/factory and move `EINPROGRESS` platform spelling out of domain `#if`. |
| `swift-iso-9945` | Add typed owned `getaddrinfo`/`addrinfo`/`freeaddrinfo`/`gai_strerror` surface; C and linked-list lifetime stay in L2. |
| `swift-threads` | Let a cancelled post-admission awaiter resume promptly while finite uninterruptible work continues, is drained, and its result is discarded/freed. |
| `swift-ip-address` | Add the ordered provider-neutral IPv4-or-IPv6 result value; preserve canonical RFC 791/4291 addresses. |
| `swift-pool-primitives` | Invoke the existing health check and add coherent resource disposition/invalidation; adjudicate generic async destruction. |
| `swift-rfc-8446` | Add bounded consumed-boundary record decoding and improve traffic-secret/transcript ownership without duplicating record or schedule law. |
| `swift-rfc-9112` | Add bounded incremental need-more/consumed parsing, enforce line/head/body limits, fix chunk consumption, and provide correct target/framing serialization law. |
| Darwin platform owner | Add typed Security.framework certificate/trust SDK surface; no raw Security import in certificate/TLS domains. |

### 3. Smallest remaining packages and integrations

| Repository / product | Layer | One-sentence mission and first-slice status |
|---|---:|---|
| existing `swift-domain-name-system` / `Domain Name System` | L3 | Resolve one validated DNS name through an injected provider while preserving ordered canonical IP results and typed resolver failures; correct the reservation's duplicate wire-model mission first. |
| new `swift-domain-name-system-iso-9945` / `Domain Name System ISO 9945` | L3 integration | Adapt the DNS recipient to typed ISO 9945 system resolution and bounded thread-pool execution without C imports or hidden wire fallback. |
| new `swift-sockets-ip-address` / `Sockets IP Address` | L3 integration | Convert canonical RFC 791/4291 addresses to/from typed kernel socket addresses without leaking sockaddr into DNS or HTTP; exact name remains an adjudication item. |
| existing `swift-transport-layer-security` / `Transport Layer Security` | L3 | Drive a cancellable TLS 1.3 client state machine and protected record lifecycle over an injected byte duplex using RFC-owned values and injected crypto/certificate witnesses. |
| new `swift-transport-layer-security-crypto` / `Transport Layer Security Crypto` | L3 integration | Bind TLS-owned hash/HKDF/key-agreement/AEAD/signature witnesses to the sanctioned official Apple Crypto product and translate all backend bytes, errors, and ownership. |
| new `swift-asn1-standard`, existing `swift-rfc-5280`, plus certificate owner(s) | L2 + L3, **blocked** | Express ASN.1 DER and X.509 profile law and perform Foundation-free chain, signature, serverAuth/EKU/keyUsage, and hostname verification under the selected truthful adaptation plan. |
| dedicated Darwin and Linux trust integrations | L3, **blocked** | Acquire Apple system anchors through typed Security SDK and discover Linux distribution anchors through Kernel/File/Path policy respectively, without cross-platform mixing or raw C imports. |
| existing `swift-http` / `HTTP` | L3 | Incrementally drive HTTP/1.1 exchange, body bounds/backpressure, reuse eligibility, and protocol shutdown over an injected byte duplex. |
| new `swift-components/swift-http-client` / `HTTP Client` | L4 | Compose URI, system DNS, sockets, TLS/WebPKI, HTTP, deadlines, bounds, pooling, cancellation, and lifecycle defaults into the published `HTTP.Request` to `HTTP.Response` executor. |

No other new package is justified by the utilization ledger. `swift-dns-cache` and
`swift-domain-name-system-sockets` are coherent possible later packages, not
first-slice dependencies.

### 4. Apple Crypto boundary scope and identity collision

Canonical purity rules govern Institute package main targets. Every Institute
target remains Foundation-free and platform-C-free; the TLS-Crypto adapter imports
only `Crypto` plus Institute modules, and no Institute public/domain API exposes
`Data`, `DataProtocol`, `[UInt8]`, backend key/error types, or untyped throws.
Official Apple Crypto 4.3.0 is sanctioned outside that enforcement scope despite
its internal imports. The exact claim is “Foundation-free Institute main targets/API
with a sanctioned Apple Crypto backend.” It carries no product-level transitive-
purity or Embedded-compatibility promise. That promise is waived for this backend;
the canonical rules are not weakened.

The unmodified manifest unconditionally declares `apple/swift-asn1`; sanctioning
Apple Crypto includes resolving/fetching its pinned package graph but does not
authorize Institute import/use of SwiftASN1. Product pruning must be proven in a
clean room, not assumed. `CryptoExtras` and its SwiftASN1/RSA product use remain
outside slice 1 pending the certificate/RSA gate.

Identity dispositions, all requiring separate external-operation authority:

1. **Recommended:** non-destructively rename the empty Institute reservation to a
   clearly noncanonical reservation identity such as `swift-crypto-reservation`,
   preserve the GitHub redirect, and depend only on
   `https://github.com/apple/swift-crypto.git` as package identity `swift-crypto`.
2. Rename and transfer the empty reservation under a noncanonical identity to a
   designated archival/reservation organization, again preserving redirects; this
   is more operational work with no dependency benefit.
3. Archive/delete the reservation or publish two `swift-crypto` identities is
   rejected here: archive/delete lacks authority and dual identity is invalid.

No history merge, Institute fork, copied source, or reconstructed provenance is
permitted.

### 5. Selected certificate/system-trust strategy

The selected strategy is truthful Foundation-free material adaptation, not direct
dependency or a clean-room security rewrite: adapt Apple SwiftASN1 into the L2
ASN.1/DER owner; improve existing `swift-rfc-5280`; adapt Apple certificates into
the L3 chain/policy runtime; extract certificate-to-Crypto and Darwin/Linux trust
integrations; and add the complete fail-closed TLS server authentication policy.
Per-package [HERITAGE-001], refreshed fork points, remote identity collision audit,
non-destructive reservation migrations, and one-publication-commit ancestry remain
preconditions to any external operation. Whether RSA/CryptoExtras is necessary is
still a certificate-fixture/algorithm gate, not part of slice 1.

No option may guess anchors, hard-code an incomplete Linux path list, disable
validation, merge unrelated histories, or import platform C in domain packages.

### 6. First executable vertical slice and gates

After adjudication, the narrow leaf-first slice is:

1. repair event cancellation/shutdown and ship event-backed TCP connect/read/write;
2. add typed system host resolution, ordered IP results, and the IP/socket bridge;
3. bind sanctioned Crypto, complete TLS 1.3 client record/state operation, and
   compose the chosen WebPKI/hostname/system-trust path;
4. land bounded incremental RFC 9112 plus the injected HTTP/1.1 drive and repaired
   `Pool.Bounded` disposition;
5. compose `HTTP.Client`, then execute only provider-neutral absolute HTTPS GETs;
6. hand the green executor closure to the parked Workspace/GitHub integration task.

Acceptance requires: strict-memory/typed-throws/Sendable/ownership compile gates;
zero Foundation or platform-C imports in Institute main networking targets (the
adapter imports only `Crypto` plus Institute modules); deterministic
cancel-before/during-connect/read/DNS tests; bounded worker/queue/body/head/line/
record tests; idempotent shutdown and use-after-shutdown tests; RFC 8448 schedule
and handshake vectors plus TLS record tamper/truncation/replay/sequence tests;
local root/intermediate/leaf fixtures covering good chain, unknown root, expired/
not-yet-valid, hostname/SAN/wildcard/IP, EKU/key usage, bad signature, and missing
intermediate; RFC 9112 framing/chunk/pipeline/EOF fixtures; repeated `Link`, 404,
body-limit, cancellation, and connection-discard tests; Apple/Linux local interop;
one separately authorized public read-only `api.github.com` GET; and anonymous
clean-room SwiftPM resolution/tests from canonical URLs with no mirrors,
credentials, Workspace, GitHub, Router, Foundation transport, NIO, curl, or
process fallback.

## Acceptance and next gate

No implementation may begin until the program lead approves this dossier and the
architecture record is amended and re-reviewed. Subsequent leaf-first work must
prove each owner repair with its existing tests plus focused cancellation,
boundedness, ownership, and shutdown cases; protocol formats with official RFC
vectors; Crypto bindings with the sanctioned backend's supported algorithm matrix;
certificate/trust with deterministic local fixtures and separately authorized
read-only public interoperability; and final packages through Foundation/import
audits, direct bottom-up tests, and anonymous clean rooms.

No live-mutating external test is permitted. No external repository mutation is
requested by this utilization record.
