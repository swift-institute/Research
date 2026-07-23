# Native Networking Wave 3 Implementation, Heritage, and Dependency Record

<!--
---
version: 1.2.0
last_updated: 2026-07-23
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
changelog:
  - 1.2.0 (2026-07-23): DNS system-resolver shape AMENDED per the final
    adjudication in dns-system-resolver-package-shape-adjudication.md
    (principal-delegated): swift-domain-name-system-iso-9945 is renamed
    swift-domain-name-system-kernel and composes the new unified
    Kernel.Socket.Address.Info surface (swift-kernel; POSIX policy slot
    reserved in swift-posix) instead of a direct swift-iso-9945 edge. The
    package-table row for the adapter, the DAG lines "Domain Name System
    ISO 9945 -> ...", and the same-layer-edge bullet for it are SUPERSEDED
    accordingly. N3 remains COMPLETE; this is a shape correction, not a
    milestone reopen. Also: N4 (pool disposition) COMPLETED 2026-07-23
    (swift-pool-primitives 2d48559 — ratified patch items + three
    lost-wakeup windows closed). GATE A/GATE B of the certificates packet
    ADJUDICATED (see certificates-n5-decision-packet.md v1.0.0): N5 may
    proceed once the pre-execution checklist passes.
  - 1.1.0 (2026-07-22): Applied supervisor adjudication: moved HTTP Client to
    swift-components; incorporated the approved existing-owner reduction; selected
    direct sanctioned apple/swift-crypto plus separate TLS/Certificate adapters;
    selected truthful Foundation-free ASN.1/certificate adaptations; extracted
    DNS, IP/socket, Crypto, and trust integrations; narrowed slice 1 to system DNS
    and HTTP/1.1; corrected Pool.Bounded disposition, bounded non-interruptible
    system resolution, heritage/identity preconditions, and the Workspace API seam.
  - 1.0.0 (2026-07-22): Reconciled the ratified networking roadmap with live
    source, canonical layering, the later pure-networking architecture, the
    URL-routing boundary, the Workspace/GitHub execution seam, and Apple's
    experimental HTTP API proposal. Defines the Wave-3 package missions,
    dependency graph, heritage dispositions, security gates, and leaf-first
    implementation plan. No runtime package mutation is authorized by this
    record.
---
-->

## Context and status

Workspace public-repository discovery is blocked on one ecosystem capability: a
executor with Foundation-free Institute main targets/API that accepts the published
`HTTP.Request`, performs an absolute HTTPS request, and returns the published
`HTTP.Response` using the sanctioned Apple Crypto backend. The provider
already owns GitHub headers, authentication policy, JSON, pagination, and 404
semantics. Networking must therefore supply a general Institute capability rather
than a GitHub- or Workspace-local transport.

The provider side is final and public at `GitHub Standard` `368f548deac1`,
`GitHub Core` `a248823bf423`, and `GitHub HTTP` `0bdcd4577411`. Anonymous isolated
clean rooms passed their respective 6-test/7-suite, 6-test/7-suite, and
9-test/6-suite gates with canonical URLs and no mirrors or credentials. Workspace
remains parked and clean at `566fe96`. The prepared local blocker/contract evidence,
pending tracked publication, is
`external-service-package-architecture.md:1207`–`:1374`; its exact injected seam
is `@Sendable (HTTP.Request) async throws(ExecutionFailure) -> HTTP.Response`
(`:1367`–`:1373`). This record preserves that contract.

This record is the mandatory design gate before broad Wave-3 mutation. It is a
**Tier 2 RECOMMENDATION**. It authorizes no source edit outside Research, repository
creation, push, rename, transfer, visibility change, tag, or release. Implementation
starts only after the program lead re-reviews this amended package, layer, and
heritage plan and explicitly releases the gate in “Remaining gates.”

The review was performed on 2026-07-22. It reconciles, in order:

1. `Internal/handoffs/DECISIONS-pass2/networking-stack-roadmap.md`;
2. `Research/institute-server-stack-architecture.md`;
3. `Research/url-routing-stack-first-principles-review.md`;
4. `Research/url-routing-stack-migration-plan.md`;
5. the networking/Workspace blocker in
   `Research/external-service-package-architecture.md`;
6. `Internal/handoffs/REPORT-overnight-2026-07-14.md`;
7. the later `Research/Pure-Institute-Networking/target-package-and-layer-architecture.md`;
8. live repository source and history; and
9. Apple’s experimental HTTP API proposal as comparative evidence only.

### Governance loaded

The following canonical skills were read completely in dependency order where
the hub routed to companions: `swift-institute-core`, `swift-institute`,
`platform`, `byte-discipline`, `memory-safety`, `implementation`, `code-surface`,
`modularization` and its applicable companions, `existing-infrastructure`,
`swift-package`, `swift-package-build`, `swift-package-heritage`,
`research-process`, `experiment-process`, `testing`, and `release-readiness`.
`skill-lifecycle` was not loaded because this record proposes no skill promotion.

The controlling rules are: platform C imports in Institute packages stop at typed
L2 owners; every Institute main target remains Foundation-free; L2 owns protocol law; L3 owns one
domain’s runtime policy; cross-domain execution composition is L4; same-layer
edges must be essential and explicit; public octets are `Byte`; fallible APIs use
typed throws; resource ownership is explicit and preferably move-only; source
heritage is preserved rather than reconstructed; and a reserved repository name
does not oblige the Institute to fill it.

## Live-source baseline and roadmap corrections

All repositories in this table were clean at review except `swift-kernel`, which
was clean on the active non-main branch shown below. No build or source mutation
was used to establish this baseline.

| Capability | Repository / reviewed commit | Live finding |
|---|---|---|
| HTTP drive | `swift-foundations/swift-http` `4db12c23334d` | Empty reservation; its metadata’s “core HTTP types” mission is obsolete because RFC 9110 and HTTP Standard own the model. |
| HTTP client | proposed `swift-components/swift-http-client` | No local checkout and no GitHub repository existed on 2026-07-22. This is a new L4 repository using the roadmap’s trigger name, not a reserved-repository fill. |
| TLS engine | `swift-foundations/swift-transport-layer-security` `a41a4c9c7aae` | Empty reservation. |
| Certificates / crypto | Institute `swift-certificates` `c3ae2ec097d9`; `swift-crypto` `1a4b60be566a` | Empty, original Institute reservations; they are not Apple forks. |
| DNS runtime / cache | `swift-domain-name-system` `517243da50a8`; `swift-dns-cache` `dd576b1b6bec` | Empty reservations. DNS wire ownership already belongs to the RFC packages. |
| Socket runtime | `swift-sockets` `51705159e5d1` | IPv4/IPv6 TCP connect, UDP, listener, read, and write exist; only the blocking production composition ships. Public TCP factories are in `Sources/Sockets/Sockets.TCP.Connection+Connect.swift:38` and `:57`; `Sources/Sockets/IO+Blocking.swift:12` records the missing event/completion composition. |
| IO / kernel | `swift-io` `bc3ca527af3d`; `swift-kernel` `6d8e1c2e828a` on `fable-448/swift-kernel-event-source` | Event/proactor substrates exist. The kernel checkout is an active lane and must not be casually mutated. |
| Generic pool | `swift-pool-primitives` `f8400a9c7bc7` | `Pool.Bounded<Resource: ~Copyable>` already owns bounded acquisition, cancellation, health, metrics, and shutdown (`Sources/Pool Bounded Primitives/Pool.Bounded.swift:44`; `Pool.Bounded.Acquire.swift:17`). |
| Connection pool reservation | `swift-pool-connections` `3c4702af8ae6` | Empty. Its roadmap mission duplicates the shipped generic pool unless narrowed to reusable-connection law. |
| TLS 1.3 law | RFC 8446 `b35ec83a4ce8`; RFC 6066 `203a7b299e35`; RFC 7301 `47bb023d9662` | Typed handshake/record/key-schedule models, RFC 8448 vectors, SNI, and ALPN exist. No TLS state machine, ECDHE/AEAD record protection, CertificateVerify binding, trust, or socket connection exists. RFC 8446’s crypto edge is test-only (`swift-rfc-8446/Package.swift:16`). |
| DNS law | RFC 1035 `5835e11166c8`; RFC 3596 `66d4eda8b0b1`; RFC 6891 `36427cbaa6e3` | Message compression, A/AAAA, and EDNS(0) wire capabilities exist. Resolver transport, policy, search behavior, cancellation, and cache do not. |
| HTTP law | HTTP Standard `d5f39821ca05`; RFC 9110 `7f7907752612`; RFC 9111 `284392d91ddc`; RFC 9112 `3fb45a017da3` | `HTTP.Request`/`Response` are `Sendable`, use `[Byte]?`, and preserve repeated field values. RFC 9112 is whole-buffer only and is not safe as a bounded reusable socket drive. |

Official `apple/swift-crypto` 4.3.0 at
`fa308c07a6fa04a727212d793e761460e41049c3` is the sanctioned external
primitive backend. It is not an Institute fork; its external source is outside
Institute main-target rule enforcement, and the product makes no transitive-purity
promise. `apple/swift-asn1` 1.6.0 at `9f542610…` and
`apple/swift-certificates` 1.18.0 at `24ccdeee…` are selected only as material
adaptation lineages under true-fork heritage, not as direct Institute products.

The July 14 roadmap is therefore stale where it calls sockets, RFC 1035, RFC
8446, or RFC 6066 merely absent/partial. Its central runtime gaps remain correct:
there is no cancellable socket composition, typed system-resolver integration,
TLS engine/system trust, bounded incremental HTTP drive, or outbound HTTP client.

Two specific RFC 9112 defects prevent a client-local wrapper. The response
deserializer requires a complete `[Byte]` (`Sources/RFC 9112/HTTP.Message.Deserializer.swift:204`),
the chunked path reports all remaining bytes consumed (`:296`–`:310`), and the
until-close path buffers everything (`:312`–`:315`). The parser has no enforced
line/head limits. The serializer neither changes an absolute target to origin-form
nor synthesizes `Host`/framing (`HTTP.Message.Serializer.swift:17`–`:69`). These
are owner defects: bounded incremental parsing/framing belongs in RFC 9112 and
connection driving belongs in `swift-http`, never in Workspace or GitHub.

## Reconciled package architecture

### One-sentence missions, layers, and products

| Repository | Layer | One-sentence mission | Wave-3 product / target |
|---|---:|---|---|
| `swift-io` | L3 | Provide reusable event/completion actors and runners over typed kernel drivers with cancellation-safe waits and deterministic owned shutdown. | Repair existing `IO Events`; no new reactor/event-loop package. |
| `swift-sockets` | L3 | Adapt typed kernel sockets to cancellable asynchronous byte/datagram operations over the existing IO event/completion strategies. | Extend existing product/target `Sockets`; do not mint a second socket engine. |
| `swift-iso-9945` | L2 | Express typed POSIX host-resolution calls and owned `addrinfo` lifetime while remaining the exclusive platform-C import owner. | Extend existing ISO 9945 products/targets with `getaddrinfo`, `freeaddrinfo`, and `gai_strerror`. |
| `swift-threads` | L3 | Execute bounded blocking work while allowing abandoned awaiters to resume promptly and retaining unavoidable OS work until safe disposal. | Repair existing `Kernel.Thread.Pool`; no DNS-local worker pool. |
| `swift-ip-address` | L3 | Compose canonical IPv4/IPv6 standard values into an ordered provider-neutral address result without defining new address law. | Extend existing `IP Address` with the family sum/order value. |
| `swift-sockets-ip-address` | L3 integration | Adapt canonical IP addresses to typed kernel socket addresses without leaking socket representation into DNS or HTTP. | New product/target `Sockets IP Address`. |
| `swift-pool-primitives` | L1 | Own generic bounded resource acquisition, validation, terminal disposition, asynchronous consuming destruction, and shutdown. | Repair existing `Pool Bounded Primitives`; keep `swift-pool-connections` empty. |
| `swift-rfc-9112` | L2 | Express HTTP/1.1 wire grammar, validation, and bounded incremental framing independent of transport. | Extend existing `RFC 9112` with an incremental decoder/encoder target surface; retain semantic messages in RFC 9110. |
| `swift-domain-name-system` | L3 | Resolve a validated DNS name through an injected provider while preserving ordered canonical IP results and typed resolver failures. | Product/target `Domain Name System`; correct the stale duplicate-wire-model reservation mission first. |
| `swift-domain-name-system-iso-9945` | L3 integration | Adapt the DNS resolver interface to typed ISO 9945 host resolution without importing platform C or replacing OS resolver policy. | New product/target `Domain Name System ISO 9945`. |
| `swift-transport-layer-security` | L3 | Drive a TLS 1.3 connection state machine over an injected byte duplex using injected cryptographic, certificate, identity, and trust witnesses. | Product/target `Transport Layer Security`; no socket, HTTP, or platform trust import. |
| `swift-transport-layer-security-crypto` | L3 integration | Bind TLS-owned hash/HKDF/key-agreement/AEAD/signature witnesses to official Apple Crypto while translating all bytes, errors, and ownership into Institute surfaces. | New product/target `Transport Layer Security Crypto`; imports only `Crypto` plus Institute modules. |
| provisional ASN.1 authority owner(s) | L2 | Express ITU-T X.680 / ISO/IEC 8824-1 notation law and ITU-T X.690 / ISO/IEC 8825-1 BER/CER/DER encoding law without PEM, crypto, files, or certificate policy. | **Provisional:** one cohesive authority-bearing standards-family fork with separate notation/encoding products is preferred; exact package/product/module spellings await the isolated SwiftPM normalization probe and user confirmation below. |
| `swift-rfc-5280` | L2 | Express X.509 certificate/profile wire and validation law without chain search, system anchors, or concrete cryptography. | Improve existing product/target `RFC 5280`; do not duplicate its law in Certificates. |
| `swift-certificates` | L3 | Build and verify X.509 chains and TLS server identity using RFC 5280/ASN.1 law plus injected concrete cryptography, without acquiring system roots. | Proposed product/target `Certificates`; true upstream-derived verifier adaptation. |
| `swift-certificates-crypto` | L3 integration | Bind certificate-owned signature/hash witnesses to official Apple Crypto without exposing backend or platform types. | New product/target `Certificates Crypto`; separate from the TLS-Crypto integration. |
| `swift-certificates-darwin-standard` | L3 integration | Adapt `Certificates` system-anchor acquisition to the typed Security.framework surface in `swift-darwin-standard`. | New product/target `Certificates Darwin Standard`; no raw Darwin/Security import. |
| `swift-certificates-linux` | L3 provider/integration | Discover bounded Linux distribution trust stores through typed Kernel/File APIs and present anchors to `Certificates`. | New product/target `Certificates Linux`; no Glibc/Musl import and no claim that distro path policy is kernel/spec law. |
| `swift-certificates-system` | L3 integration/unifier | Select the typed Darwin or Linux certificate trust integration behind one `Certificates` system-trust witness without importing platform C or leaking provider selection to L4/L5. | New product/target `Certificates System`; **provisional [PLAT-ARCH-008a] exception requiring user confirmation.** |
| `swift-http` | L3 | Incrementally drive HTTP/1.1 request/response exchange, framing, body backpressure, reuse eligibility, and protocol shutdown over an injected byte duplex. | Product/target `HTTP`; it depends on HTTP Standard/RFC 9112 and IO vocabulary, never DNS/TLS/sockets/routing. |
| `swift-components/swift-http-client` | L4 component | Compose URI authority, system DNS, socket/TLS/certificate/HTTP providers, bounds, pooling, cancellation, defaults, and structured lifecycle into outbound HTTPS execution. | New product `HTTP Client`, target/module `HTTP Client` / `HTTP_Client`, exposing `HTTP.Client`; trust is an injected L3 witness. |
| `swift-pool-connections` | none in this wave | Reserved only for coherent reusable connection-domain law that exists independently of HTTP framing and HTTP client origin/TLS/lifetime policy. | **Do not fill now.** |
| `swift-domain-name-system-sockets`, `swift-dns-cache` | later, not slice 1 | Own an independently selectable RFC wire resolver and coherent DNS TTL/negative-cache law only after their separate prerequisites exist. | **Do not fill or depend on in slice 1.** |

Layer and dependency obligations are assigned at package level. The concrete
client belongs in `swift-components` at L4 because it selects a reusable assembly
with URI-to-DNS-to-socket-to-TLS/trust-to-HTTP/pool defaults. The extracted DNS
and certificate providers remain L3: an adapter between essential L3/L2 services
does not become L4 merely because it composes packages. Every distinct integration
concern has its own recipient-then-provider package per [MOD-014].

### Exact narrowed dependency DAG

An arrow means “depends on.” Transitive primitive dependencies already declared
by the live packages are omitted; every new direct edge is shown.

```text
L2 protocol/platform law
  RFC 3596 -> RFC 1035 + RFC 4291 + RFC 5952
  RFC 6891 -> RFC 1035
  RFC 6066 -> RFC 8446
  RFC 7301 -> RFC 8446
  RFC 9112 -> RFC 9110 + Byte Primitives
  HTTP Standard -> RFC 9110 + RFC 9111 + RFC 9112
  URI Standard -> RFC 3986 + RFC 3987
  typed POSIX host resolution -> ISO 9945 Kernel/System (new L2 surface)
  typed Darwin trust -> Darwin Security platform target (new L2 surface)
  ASN.1 authority owner(s) [PROVISIONAL]
    -> Byte/Binary/Span primitives
    -> separate X.680 notation + X.690 BER/CER/DER products
  RFC 5280 -> X.680/X.690 surfaces + Byte/Binary/Time primitives

L3 domain runtime
  IO -> Kernel Event/Completion + Executors + Async/IO Primitives
  Sockets -> IO + Kernel + Thread Actor + Executors + Span Raw Primitives
  IP Address -> IPv4 Standard + IPv6 Standard
  Sockets IP Address -> Sockets + IP Address
  Domain Name System
    -> RFC 1035 + IP Address + Time primitives
  Domain Name System ISO 9945
    -> Domain Name System + typed ISO 9945 host resolution
    -> Threads + IP Address
  Transport Layer Security
    -> RFC 8446 + RFC 6066 + RFC 7301 + IO + Byte/Time primitives
  Transport Layer Security Crypto
    -> Transport Layer Security + official apple/swift-crypto::Crypto
    -> Byte/Span primitives
  Certificates -> RFC 5280 + ASN.1 + Byte/Time primitives
  Certificates Crypto
    -> Certificates + official apple/swift-crypto::Crypto
    -> Byte/Span primitives
  Certificates Darwin Standard
    -> Certificates + typed Darwin Security
  Certificates Linux
    -> Certificates + Kernel File/Path APIs
  Certificates System [PROVISIONAL conditional integration]
    -> Certificates + Certificates Darwin Standard + Certificates Linux
  HTTP -> HTTP Standard + RFC 9112 + IO + Byte/Time primitives

L4 component/composition packages
  HTTP Client
    -> HTTP + HTTP Standard + URI Standard
    -> Domain Name System + Domain Name System ISO 9945
    -> Sockets + Sockets IP Address
    -> Transport Layer Security + Transport Layer Security Crypto
    -> Certificates + Certificates Crypto + Certificates System
    -> Pool Bounded Primitives + Time Primitives

Test/configuration composition
  HTTP Client.Configuration -> explicit injected Certificates trust witness
```

The graph is exact for slice 1, but every new edge is **blocked from manifest
landing** until this record is re-approved and its owner milestone is released.
ASN.1/certificate forks, Apple Crypto, and trust edges have additional heritage,
identity, and security gates below.
`Transport Layer Security` owns the witness protocols it needs and therefore has
no package edge to Apple Crypto, `Certificates`, sockets, or HTTP. The two
recipient-provider packages bind Crypto separately. `HTTP Client` receives a
typed system-trust witness created by exactly one L3 trust integration; no
platform-specific HTTP-client package or domain-level `#if` is introduced.

`apple/swift-crypto` 4.3.0 unconditionally declares `apple/swift-asn1` in its
SwiftPM graph even though only `CryptoExtras` imports the product. The exact
resolved graph therefore includes/fetches that dependency unless a clean-room
resolution proves pruning. This does not create a direct Institute `SwiftASN1`
import or make it architecture/API authority. `CryptoExtras` is absent from slice
1 and requires the certificate/RSA gate. The adapted Institute fork must use an
authority-bearing identity distinct from Apple Crypto's `swift-asn1`; identity
avoidance alone cannot select that L2 name. The exact cut is provisional below.
No edge from GitHub, Workspace, Router,
Foundation, URLSession, AsyncHTTPClient, NIO, curl, Process, or Vapor is permitted.

### Same-layer edges and why they are essential

- `Sockets IP Address -> Sockets + IP Address` is an essential L3 integration:
  neither semantic owner should absorb the other's representation bridge.
- `Domain Name System ISO 9945 -> Domain Name System + ISO 9945 + Threads + IP
  Address` is an essential L3 provider edge; it preserves OS resolver policy while
  keeping C and worker mechanics out of the DNS owner.
- `Transport Layer Security Crypto -> TLS + Crypto` and `Certificates Crypto ->
  Certificates + Crypto` are distinct essential recipient-provider edges. Combining
  them would mix integration concerns.
- `Certificates Darwin Standard` and `Certificates Linux` are dedicated L3
  integration/provider packages. Typed Security SDK access stops in Darwin L2;
  Linux distribution-root discovery is L3 file/path policy over Kernel APIs.
- `Certificates System` is a provisional L3 integration unifier. It is the
  certificate domain's platform-strategy selection point and exposes one typed
  witness to L4 while preserving explicit injection for tests.
- `HTTP Client` is intentionally L4. Every L3 edge it crosses is the package’s
  defining composition mission; none may be smuggled into `swift-http`.

### Provisional [PLAT-ARCH-008a] confirmation: `Certificates System`

The cross-platform system-trust unifier requires a domain-level platform strategy
conditional. It remains provisional and N5/N8 remain blocked until the user
confirms all four [PLAT-ARCH-008a] criteria verbatim:

1. **(a)** Certificates is domain authority for trust-provider selection;
2. **(b)** only typed Institute certificate/platform-integration modules are
   imported, never platform C;
3. **(c)** the conditional selects trust domain strategy, not a syscall;
4. **(d)** pushing it into Kernel would contaminate Kernel with certificate
   semantics.

If confirmed, `swift-certificates-system` is the sole production-default selector
and exports one typed system-trust witness. `HTTP.Client` depends on that L3
surface for its default while retaining explicit witness injection for tests and
configuration. Workspace and other L5 consumers do not choose Darwin versus Linux.
If any criterion is rejected, the package/DAG returns to architecture review; no
platform selection leaks upward as a workaround.

## Heritage dispositions

| Repository/source | Disposition |
|---|---|
| `swift-sockets`, RFC packages, IO/kernel, pool primitives | Improve in place with ordinary Institute history. No source transfer. Preserve the active `swift-kernel` branch lane. |
| Empty `swift-http`, `swift-transport-layer-security`, `swift-domain-name-system` reservations | Fill in place from new Institute-authored implementations after review; update stale repository missions first. No claim of inherited source. |
| Empty `swift-dns-cache` reservation | Keep empty in slice 1. No system-resolver TTL can be inferred and no RFC 2308 owner is present. |
| Empty `swift-rfc-5280` reservation | Improve independently from RFC 5280 and Institute ASN.1 law. Do not move Apple certificate-runtime source into this L2 owner; verifier lineage stays solely in the true `swift-certificates` fork. |
| `swift-components/swift-http-client` and independent integration packages | Create only after review as independent Institute implementations. No prior repository or external source lineage exists. |
| Empty `swift-pool-connections` | Leave reserved. Do not duplicate `Pool.Bounded`. Reconsider only with independently demonstrated connection-specific reuse law. |
| Institute `swift-crypto` / `swift-certificates` reservations and any remote ASN.1 collision | Preserve unrelated Institute history under non-canonical reservation names if migration is authorized. Never merge Apple history into them or label reservations as forks. |
| `apple/swift-crypto` | Use official 4.3.0 directly as sanctioned backend. No copied/adapted production lineage, Institute fork, or heritage merge. |
| `apple/swift-certificates`, `apple/swift-asn1` | [HERITAGE-001] fires separately as shown below. Each derived publication must preserve true upstream fork ancestry with one Institute publication commit directly atop the verified upstream fork point per [HERITAGE-002]; the exact ASN.1 authority-bearing package cut remains provisional. |
| `apple/swift-http-api-proposal` | Comparative prior art only: no dependency, copied source, compatibility target, or reconstructed history. |

Old local `coenttb/swift-http` and `coenttb/swift-tls` checkouts have only a
namespace shell and local-path manifests, with no useful implementation history;
they are not heritage inputs.

### [HERITAGE-001] four-condition verification

These tests decide origin/ancestry, not whether every upstream package boundary or
API survives. The exact fork point must be refreshed from the official repository
and pinned immediately before an authorized operation; the local release pins
below are the 2026-07-22 content-review evidence, not permission to fork.

#### `apple/swift-crypto` -> direct sanctioned backend

| Condition | Evidence | Result |
|---|---|---|
| Material lineage | Institute production source does not copy or adapt Apple Crypto; a dedicated adapter imports the unmodified official `Crypto` product. | **FAIL — no adapted lineage** |
| Community / consumer overlap | Swift consumers needing cross-platform hashing, HKDF, key agreement, AEAD, signature, and RSA-PSS are material candidates for both packages. | PASS |
| License compatibility | Apache-2.0 permits derivative publication with attribution/NOTICE compliance. | PASS |
| Upstream is non-owned | `apple/swift-crypto` is Apple-owned; Institute has no transfer/admin authority. | PASS |

Condition 1 fails, so fork-as-heritage does not fire. Use the official upstream
package URL and version; do not create an Institute crypto implementation or fork.
The TLS/Certificate adapter packages contain only Institute-authored boundary code,
import `Crypto` plus Institute modules, and expose no Foundation/backend type.

#### `apple/swift-certificates` -> Institute certificate verifier

| Condition | Evidence | Result |
|---|---|---|
| Material lineage | The selected L3 verifier retains recognizable upstream chain construction, signature verification, and policy lineage from reviewed 1.18.0 `24ccdeee…`, adapted to Institute RFC 5280/ASN.1/Byte surfaces and stricter TLS server policy. | PASS |
| Community / consumer overlap | Swift consumers needing X.509 chain and server-identity verification materially overlap. | PASS |
| License compatibility | Apache-2.0 permits derivative publication with attribution/NOTICE compliance. | PASS |
| Upstream is non-owned | `apple/swift-certificates` is Apple-owned; Institute has no transfer/admin authority. | PASS |

All four pass: true fork heritage is mandatory if this material verifier lineage
remains. The package’s sole L3 essence is certificate verification. RFC 5280 wire /
profile law moves to the independent L2 RFC owner; system-root acquisition moves to
dedicated integration packages.

#### `apple/swift-asn1` -> Institute ASN.1 standard

| Condition | Evidence | Result |
|---|---|---|
| Material lineage | The selected L2 package retains bounded DER model/codec structure and recognizable API lineage from reviewed 1.6.0 `9f542610…`; Foundation/PEM surfaces are excluded. | PASS |
| Community / consumer overlap | Swift consumers needing ASN.1 DER parsing/serialization are material candidates for both packages. | PASS |
| License compatibility | Apache-2.0 permits derivative publication with attribution/NOTICE compliance. | PASS |
| Upstream is non-owned | `apple/swift-asn1` is Apple-owned; Institute has no transfer/admin authority. | PASS |

All four pass: true fork heritage is mandatory if this material codec lineage
remains. The package’s sole L2 essence is ASN.1 external specification law. PEM,
certificate policy, crypto, files, and system trust are excluded rather than
inheriting Apple’s package cut uncritically.

### Non-destructive fork / rename / transfer plan

No operation in this table is authorized by this record. Before execution, recheck
remotes, default branches, releases/tags, dependency references, forks, visibility,
and official upstream HEADs; any material consumer of an empty reservation stops
the plan for a replacement/redirect review.

| Desired canonical repository / dependency | Collision / rename | Fork/dependency and publication sequence | Transfer | Preservation / stop condition |
|---|---|---|---|---|
| official `https://github.com/apple/swift-crypto.git` | Rename unrelated empty Institute reservation to `swift-crypto-reservation-2026` or another approved noncanonical identity. | Depend directly on official 4.3.0. Create no Institute fork/publication. Audit its complete resolved graph, including `swift-asn1`, for local and remote SwiftPM identity collisions. | None. | Reservation history remains public/reachable and redirect behavior is verified. Stop on any unresolved identity collision or if a consumer depends on the reservation. Never publish two `swift-crypto` identities. |
| `swift-foundations/swift-certificates` | Rename unrelated empty reservation to `swift-certificates-reservation-2026`. | Same true-fork shape from official `apple/swift-certificates`, with one Institute publication commit directly atop the pinned fork point. | None. | Same preservation and stop rules. |
| provisional ITU-T X.680/X.690 authority-bearing owner(s) | Apple Crypto already resolves package identity `swift-asn1`, so the Institute adaptation must use distinct authority-bearing identity/identities. Audit remote candidates and consumers; local absence proves nothing. | **Preferred proposal pending probe/user confirmation:** one cohesive renamed true fork of official `apple/swift-asn1`, one publication commit atop the refreshed fork point, with separate X.680 notation and X.690 BER/CER/DER products. The decomposed two-repository alternative remains rejected until it proves mechanically truthful heritage for one upstream repository split across two owners. | None. | Preserve ancestry/license/NOTICE. STOP on unresolved authority naming, module normalization, remote identity, consumer, redirect, visibility, [MOD-041] cohesion, or [HERITAGE-002] mechanics. No ASN.1 repository operation is authorized. |

For both derived packages, the fork point, publication-tree source commit, path mapping, deleted upstream
surfaces, attribution files, and exact `git log --first-parent` shape are acceptance
artifacts. Fork/rename/repository creation/publication require a separate explicit
authorization after this architecture is re-approved. The Apple Crypto dependency
also requires a clean-room resolved-graph artifact proving the exact identities
fetched; product pruning of SwiftASN1 may be recorded only if that gate proves it.

## Runtime contracts

### DNS

`Domain Name System` owns a typed, cancellable resolver protocol and policy. A
query has a validated DNS name, address-family preference, monotonic deadline,
and resolver configuration. A result preserves an ordered provider-neutral family
sum of canonical RFC 791/4291 addresses. System results expose no invented TTL.

The first public provider is the system resolver, but only after the missing
`getaddrinfo`/`freeaddrinfo`/`gai_strerror` surface is added to the correct typed L2
ISO/POSIX owner. This preserves `/etc/hosts`, NSS, search domains, split DNS, and
enterprise configuration; the client must never hard-code a public resolver.
System resolution receives an externally/shared-owned bounded
`Kernel.Thread.Pool`, repaired for abandoned post-admission awaiters; neither the
DNS provider nor `HTTP.Client` owns that pool. Cancellation, resolver shutdown, or
client shutdown actively resumes each logical request, marks it abandoned, and
returns promptly. An admitted worker job independently owns its `addrinfo` chain
and later frees that result whether delivery succeeds or the logical request was
abandoned; cancellation does **not** claim to interrupt the OS call. Queue
admission fails with a typed capacity error rather than creating another thread.

Only the pool's actual application/process owner may invoke pool shutdown. That
shutdown rejects queued work, resumes queued waiters with `.shutdown`, drains the
finite admitted workers, frees every late result, and may await the uninterruptible
OS calls before joining. `HTTP.Client.shutdown()` never shuts down or waits for the
shared pool. This separates prompt logical lifecycle from safe finite worker
lifetime and bounds repeated-cancellation exposure.

Neither a wire resolver nor DNS cache is part of slice 1. A later independently
selectable sockets provider may add RFC 1035/3596/6891 UDP, EDNS(0), TC-to-TCP,
compression/ID/question bounds, retries, and explicit nameserver policy. A later
cache requires coherent RRset/RFC 2308 law and composes existing cache/TTL
primitives; it never infers TTL from `getaddrinfo` or silently replaces OS policy.

### TLS 1.3, certificates, and system trust

`Transport Layer Security` owns the client handshake and record state machine:
ClientHello with SNI and `http/1.1` ALPN, TLS 1.3 version negotiation, supported
groups/signatures, ECDHE, transcript/key schedule, encrypted handshake, server
Certificate/CertificateVerify/Finished, application traffic keys, record sequence
nonces, `TLSInnerPlaintext`, AEAD seal/open, alerts, close-notify, key update policy,
and explicit rejection of renegotiation/downgrade/unexpected messages. It consumes
the existing RFC 8446/6066/7301 models; it does not add Crypto to an RFC target.

Certificate verification is mandatory before application bytes are accepted:
parse DER; build a chain to a system anchor; verify every signature and validity
interval; enforce basic constraints, path length, critical extensions, key usage,
and TLS server EKU; apply RFC hostname/IP identity rules to the original URI host;
reject NUL/encoding ambiguity and wildcard overreach; and bind CertificateVerify
to the TLS 1.3 transcript and negotiated signature scheme. SNI uses the same
normalized DNS name. ALPN must be absent or exactly `http/1.1` for this slice;
negotiated HTTP/2 is not silently accepted.

System trust is not guessed. Darwin requires a typed Security.framework L2 owner;
Linux requires an explicit typed trust-source provider plus the same certificate
policy. Missing/empty roots are fatal typed errors. Test-only custom roots are
explicit configuration unavailable from the public production convenience.

#### Exact Crypto, ASN.1, certificate, and trust strategy

The reviewed upstream evidence is official `apple/swift-crypto` 4.3.0 at
`fa308c07a6fa04a727212d793e761460e41049c3`, `apple/swift-certificates`
1.18.0 at `24ccdeee…`, and `apple/swift-asn1` 1.6.0 at `9f542610…`.
They contain needed algorithms, DER, chain construction, and policy evidence, but
their roles differ:

- Apple Crypto is the sanctioned unmodified external primitive backend. Its source
  internally imports Foundation and platform C, but canonical Institute purity
  rules govern Institute package main targets, not this sanctioned external source.
- X509 has Foundation/FoundationEssentials and direct Darwin/Glibc/Musl imports.
- `CertificateStore.systemTrustRoots` is Linux-only, probes two paths through
  Foundation/Dispatch, can reduce failure to an empty store, and directs Darwin
  to Security.framework (`X509/Verifier/TrustRootLoading.swift:23`–`:41`).
- the generic RFC 5280 policy does not itself enforce TLS server key usage/EKU,
  and identity policy retains common-name fallback; a TLS WebPKI policy is still
  required.

The approved direction is **Foundation-free Institute main targets/API with a
sanctioned Apple Crypto backend**, plus truthful Foundation-free ASN.1 and
certificate adaptations:

1. depend directly on official Apple Crypto 4.3.0; create no Institute crypto fork
   or implementation;
2. keep `swift-transport-layer-security-crypto` and `swift-certificates-crypto`
   separate; each imports only `Crypto` plus Institute modules, translates at the
   boundary, and exposes only `Byte`/Span, typed errors, Sendable witnesses, and
   Institute-owned move-only secret/resource values;
3. expose no Foundation, `Data`, `DataProtocol`, `[UInt8]`, Crypto key/error type,
   or untyped throw from any Institute public or domain surface;
4. describe the artifact accurately as Foundation-free Institute main targets/API
   with a sanctioned Apple Crypto backend, with no product-level transitive-purity
   or Embedded-compatibility promise;
5. adapt Apple SwiftASN1 materially into one L2 ASN.1/DER owner and Apple
   certificates materially into one L3 certificate runtime, each as a truthful
   fork with one publication commit directly atop the refreshed fork point;
6. improve existing `swift-rfc-5280` for X.509 profile law; do not duplicate that
   law in the certificate runtime;
7. replace Foundation/PEM/backend byte surfaces with Institute Byte/Span/Binary/
   Base64 and typed throws, and extract certificate-to-Crypto independently;
8. route Darwin Security access through typed L2 platform surfaces and Linux
   distribution-root discovery through an L3 Kernel/File/Path provider; and
9. enforce fail-closed TLS server authentication: chain, signatures, time,
   constraints/path length, unknown critical extensions, key usage, serverAuth
   EKU, SAN DNS/IP matching, wildcard/encoding rejection, and system anchors.

Apple Crypto's manifest unconditionally declares `apple/swift-asn1` at
`Package.swift:248`–`:256`, although only `CryptoExtras` imports the product at
`:181`–`:202`. Sanctioning the unmodified package necessarily sanctions resolving
and fetching that pinned graph; it does not sanction direct Institute import/use
of `SwiftASN1` or make it architecture/API authority. Clean-room resolution must
record the actual graph and any pruning instead of assuming it. `CryptoExtras`
and RSA are outside slice 1 until certificate fixtures prove the algorithm need
and the lead releases that gate.

Direct current Apple ASN.1/certificate product dependencies and a clean-room
DER/certificate security rewrite are rejected. The selected fork adaptations and
every name migration remain separately gated. OpenSSL/system TLS, guessed trust,
or disabled validation remain prohibited.

### HTTP/1.1 incremental drive

RFC 9112 first gains a bounded incremental state machine with exact consumed-byte
accounting and states for start line, fields, fixed body, chunks/extensions,
trailers, until-close, complete, and failed. It must:

- distinguish need-more-input from EOF and malformed input;
- enforce per-line, total-head, field-count, chunk-line, trailer, and body bounds
  before retaining bytes beyond a limit;
- validate Transfer-Encoding ordering, duplicate/conflicting Content-Length,
  no-body status/method rules, informational responses, and obsolete folding;
- preserve repeated fields and trailers;
- retain bytes after one response for the next exchange; and
- return exact consumed/produced counts over `Byte`/Span buffers.

`HTTP` composes that law with an injected duplex. For a client exchange it writes
an origin-form target, derives `Host` including a non-default port, rejects a
conflicting caller `Host`, selects legal body framing, handles all 1xx responses,
incrementally returns head/body/trailers, and marks a connection reusable only
after unambiguous complete framing. Until-close, protocol errors, cancellation,
timeouts, over-limit responses, and unread streaming bodies close rather than
return the connection to the pool.

### Pooling, cancellation, timeouts, bounds, and redirects

The client uses `Pool.Bounded` per origin; it does not fill `swift-pool-connections`.
An internal `~Copyable` connection and lease own exactly one transport. Checkout is
FIFO/bounded; health/reuse policy checks origin, TLS identity/ALPN, idle age,
lifetime, server close, and framing terminal state. Shutdown rejects new work,
cancels/awaits in-flight work, closes idle resources, and destroys returned leases.

The approved pool disposition is an owner repair in `Pool.Bounded`: invoking the
existing health check and adding a general asynchronous consuming destruction
closure is coherent generic resource-pool law because database, file, process, and
network resources can all require asynchronous teardown. The acquisition surface
also needs an explicit terminal disposition/invalidation path so a checked-out
resource can be consumed into destruction rather than implicitly returned. The
pool awaits destruction during eviction and shutdown under finite lifecycle rules.
This API shape requires Pool owner consumer-view and cancellation probes before
landing, but the architecture decision is fixed: prefer the generic async consuming
disposition, never a connection-only pool.

The HTTP client returns a connection to reusable storage only after RFC framing,
TLS state, origin identity, and health all say reusable. Cancellation, timeout,
protocol/trust failure, over-limit receipt, server close, or failed validation
select terminal disposition and asynchronously close-notify/close as appropriate.
A live ambiguously reusable connection is never returned. If the Pool owner proves
the general async-consuming API mechanically impossible under supported toolchains,
that milestone stops for re-adjudication; only then may the fallback close and
invalidate fully while checked out before returning a terminal unusable value.

This is a first-principles ownership decision, not a demand count. Generic bounded
resource acquisition/lifecycle already belongs to `Pool.Bounded`. RFC/HTTP framing
completion and reuse eligibility belong to `swift-http`. Origin, TLS identity,
idle/lifetime, and pool-default policy belong to the L4 HTTP client. No coherent
residual connection-domain law remains for `swift-pool-connections`; fill it only
if such law is later derived independently of HTTP, never because a second consumer
appears or has not yet appeared.

Cancellation is active, not observational: a task cancellation handler aborts the
current resolver/connect/handshake/write/read operation and closes/discards the
transport so a suspended operation resumes. The public failure is typed
`.cancelled`; internal underlying diagnostics may be retained without changing
that semantic. Deadline phases are DNS, connect, TLS, write, response-head,
response-body, and overall. Configuration requires finite defaults and rejects
non-positive or internally inconsistent bounds.

Bounds cover request-body bytes, response line/head/field count, response body,
chunk metadata, trailers, pool origins/connections/waiters, and total deadline. The buffered
compatibility executor fails before appending beyond the configured body limit.
It either safely drains within an independent drain cap or closes; an over-limit
connection is never ambiguously reused.

Redirect following is absent from slice 1. The executor returns 3xx responses
unchanged. Any later opt-in policy requires a separate architecture gate and never
imports the existing server-side `swift-http-redirect` package.

### Typed error ownership

Lower owners define lower failures (`Sockets.Error`, `DNS.Resolver.Error`,
`TLS.Connection.Error`, RFC 9112 decode errors). `HTTP.Client.Error` owns only
cross-domain execution semantics and wraps typed lower failures without converting
them to strings:

```swift
extension HTTP.Client {
    public enum Error: Swift.Error, Sendable {
        case target(Target.Error)
        case request(Request.Error)
        case dns(DNS.Resolver.Error)
        case connect(Sockets.Error)
        case tls(TLS.Connection.Error)
        case http(HTTP.Connection.Error)
        case timeout(Timeout.Phase)
        case limit(Limit)
        case cancelled
        case shutdown
    }
}
```

Hostname, chain, system-trust, ALPN, and alert failures remain distinguishable
inside `TLS.Connection.Error`. The client never returns a response after a trust
failure, and an HTTP status (including 404) is not an execution error.

## Public executor and lifecycle seam

The recommended public product is **HTTP Client**, module `HTTP_Client`, type
`HTTP.Client`. The first compatibility surface is deliberately buffered because
the published HTTP model and the GitHub injection closure use `[Byte]?`:

```swift
extension HTTP {
    public actor Client {
        public init(configuration: Configuration) async throws(Error)

        public func execute(
            _ request: HTTP.Request
        ) async throws(Error) -> HTTP.Response

        public nonisolated var executor: Executor { get }

        public func shutdown() async
    }
}

extension HTTP.Client {
    public struct Executor: Sendable {
        public let execute: @Sendable (HTTP.Request) async throws(Error) -> HTTP.Response
    }
}
```

The provider-neutral L4 actor remains `HTTP.Client`, its concrete nested
execution witness remains `HTTP.Client.Executor`, and the provider adapter
remains `GitHub.HTTP.Client`. `HTTP.Client.GitHub` is rejected because it would
place provider semantics under the transport owner; `HTTP.Client<GitHub>` is
rejected because provider policy is not a generic transport parameter;
`HTTP.Client.Protocol` is rejected because the concrete injected capability is
already represented by `Executor`, and no independent multiple-implementation
evidence requires a protocol.

`GitHub.HTTP.Client` retains the `HTTP` namespace and has no `GitHub.Client`
alias: constructing and decoding GitHub HTTP is the adapter's actual mission.
Any future root `GitHub.Client` would be a distinct transport-neutral core
aggregate, not a rename or alias of the HTTP adapter.

`Executor` is lifecycle-non-authoritative: it exposes execution but neither
exposes nor initiates shutdown. Its closure may strongly retain `HTTP.Client`; the
client remains the only lifecycle authority. `shutdown()` is explicit and
idempotent. It stops acquisition, cancels and awaits client-owned work, closes its
connection pool, resolver logical requests, event, and connection resources, and
causes every later call through
the client or any retained executor to throw `.shutdown`. No scoped convenience
is proposed in this wave; a later API needs its own legal semantic nesting and
borrow/lifetime review.

The system resolver's injected `Kernel.Thread.Pool` is explicitly excluded from
client ownership and shutdown. Abandoned `getaddrinfo` jobs retain/finalize their
own result lifetime independently as specified in the DNS contract above.

The exact GitHub seam is therefore:

```swift
let github = GitHub.HTTP.Client(execute: httpClient.executor.execute)
```

No GitHub, Workspace, or Router module is imported. The same `Executor.execute`
closure is the future B5 routing execution boundary; routing continues to print
and resolve requests and does not acquire transport ownership.

The public executor accepts only an absolute `https` target in this slice. It
rejects missing host, userinfo, fragment, unsupported method/body combinations,
and non-HTTPS schemes; defaults port 443; resolves the URI host; verifies that
same host through TLS; sends an origin-form target; and returns status, repeated
headers, trailers folded only according to RFC law, and a bounded `[Byte]?` body.

## Apple HTTP API proposal: Adopt / Adapt / Reject

The official repository was reviewed at commit
[`10db597e0adaeba2b84fd23688cd1b02d7644793`](https://github.com/apple/swift-http-api-proposal/commit/10db597e0adaeba2b84fd23688cd1b02d7644793),
authored 2026-07-21 and reviewed 2026-07-22. Upstream calls itself experimental
and requires a Swift 6.4-aligned toolchain
([README:3–15](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/README.md#L3-L15)).

| Decision | Evidence and Institute disposition |
|---|---|
| **Adopt** semantic/execution separation | Upstream separates `HTTPAPIs`/HTTP types from concrete URLSession/AHC clients ([Package.swift:25–32](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Package.swift#L25-L32), [60–108](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Package.swift#L60-L108)). Institute semantics remain HTTP Standard/RFC 9110; `swift-http` drives; `swift-http-client` composes. |
| **Adopt / adapt** move-only ownership | Client, reader, and writer protocols use `~Copyable`/`~Escapable`, and bodies are consumed ([HTTPClient.swift:16–38](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Sources/HTTPAPIs/Client/HTTPClient.swift#L16-L38)). Institute internal connections/leases/readers should be `~Copyable`, with `Byte`, typed errors, and one terminal disposition. |
| **Adapt cautiously** region transfer | Upstream uses `sending` at the server handler boundary ([HTTPServerRequestHandler.swift:85–90](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Sources/HTTPAPIs/Server/HTTPServerRequestHandler.swift#L85-L90)) but test support needs `nonisolated(unsafe)` ([Disconnected.swift:14–36](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Tests/HTTPAPIsTests/Helpers/Disconnected.swift#L14-L36)). Adopt explicit transfer, reject the unsafe bridge, and probe every public annotation. |
| **Adapt** `~Escapable` / borrowed buffers | Reads lend `inout` storage only through a callback ([AsyncReader+CollectInto.swift:18–49](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Sources/HTTPAPIs/AsyncReader%2BCollectInto.swift#L18-L49)), but upstream itself has TODOs about non-escapable readers ([HTTPClient.swift:29–37](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Sources/HTTPAPIs/Client/HTTPClient.swift#L29-L37)). Use Institute Span/Byte and stronger lifetime dependence only after consumer-view probes. |
| **Adopt / adapt** streaming and backpressure | Bidirectional reader/writer streaming and trailers are first-class ([README:42–52](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/README.md#L42-L52)). Keep this internal foundation and later expose a streaming API; adapt bounds to fail before retention. Reject helpers that discard surplus or check after append ([collect:23–50](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Sources/HTTPAPIs/AsyncReader%2BCollectInto.swift#L23-L50), [convenience:215–250](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Sources/HTTPAPIs/Client/HTTPClient%2BConveniences.swift#L215-L250)). |
| **Adopt** scoped lease semantics | Upstream requires the response reader be drained or its scope end before cleanup ([HTTPClient.swift:43–67](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Sources/HTTPAPIs/Client/HTTPClient.swift#L43-L67)). Adapt as an internal move-only lease for the buffered slice and a consuming reader for later streaming. |
| **Adopt** cancellation conformance | Tests require cancellation before headers and during an incomplete body to terminate ([HTTPClientConformance.swift:754–839](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Sources/HTTPClientConformance/HTTPClientConformance.swift#L754-L839)). Institute adds typed cancellation and deterministic socket/lease disposition. |
| **Adopt / reject** lifecycle | Upstream’s scoped factory cleanup is good evidence ([DefaultHTTPClient.swift:92–130](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Sources/HTTPClient/DefaultHTTPClient.swift#L92-L130)); reject the shared singleton/detached maintenance-task pattern ([87–90](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Sources/HTTPClient/DefaultHTTPClient.swift#L87-L90)). Wave 3 has an explicit owner and shutdown. |
| **Reject** dependencies/API compatibility | Upstream’s default is URLSession on Darwin and AsyncHTTPClient/NIO on Linux ([DefaultHTTPClient.swift:18–38](https://github.com/apple/swift-http-api-proposal/blob/10db597e0adaeba2b84fd23688cd1b02d7644793/Sources/HTTPClient/DefaultHTTPClient.swift#L18-L38)); it uses `UInt8` and untyped errors. None is an Institute dependency or compatibility target. |

### Ownership annotation compile probe

An isolated 2026-07-22 typecheck used Apple Swift 6.3.3
(`swiftlang-6.3.3.1.3`) with `-swift-version 6`, `-strict-memory-safety`, and
`-enable-experimental-feature Lifetimes`. A minimal `~Copyable` value with a
`sending` transfer and a `~Copyable, ~Escapable` resource protocol compiled.
A deliberately concrete `~Escapable` initializer failed until lifetime dependence
was specified, proving the compiler enforces—not merely parses—the feature.

This is a feasibility result, not permission to publish annotations. Each public
connection/lease/reader API still requires consumer-view compile-pass/compile-fail
tests, emitted-interface inspection, supported-toolchain confirmation, and no
`nonisolated(unsafe)` escape hatch.

## Leaf-first implementation plan

Each phase is a stop/go milestone reported to the lead. Builds are direct SwiftPM
or isolated validation vehicles; Xcode is used only if a package gate requires it
and only after coordinating the shared one-Xcode lane.

1. **G0 — architecture/repository gate.** Re-review this record, then separately
   authorize any new repository, reservation rename, fork, or publication. Refresh
   official upstream points and audit the complete Apple Crypto resolved graph for
   every local/remote SwiftPM identity collision, including `swift-asn1`.
   **STOP** on an unapproved operation, unresolved identity/consumer/redirect, or
   ancestry shape; **GO** only with line-cited lead approval.
2. **N1 — event lifecycle repair.** In `swift-io`, remove cancelled waiters,
   propagate arm failure, and add deterministic idempotent owned shutdown over the
   existing Kernel event source/polling executor. **STOP** on retained waiter growth,
   swallowed driver error, leaked thread/descriptor, or active kernel-lane conflict;
   **GO** when cancellation/shutdown races and ownership tests pass.
3. **N2 — event-backed sockets and address integration.** Fill production
   event-backed `Sockets.Capabilities`, move `EINPROGRESS` to the typed platform
   owner, improve `swift-ip-address` with the ordered family sum, and add the
   reviewed IP/socket adapter. **STOP** on blocking fallback, domain platform `#if`,
   duplicate address type, partial-write loss, or cancellation leak; **GO** on
   IPv4/IPv6 connect/read/write/EOF/refused/timeout/close gates.
4. **N3 — system DNS only.** Add typed owned ISO 9945 host resolution, repair
   `Kernel.Thread.Pool` post-admission abandonment, correct the DNS reservation
   mission, and fill the ISO provider. **STOP** if cancellation waits for
   `getaddrinfo`, work/queue growth is unbounded, a late result is not freed, TTL is
   invented, or a wire/cache path appears; **GO** on hosts/NSS/system-policy,
   ordering, bounded cancellation, and shutdown tests.
5. **N4 — generic pool disposition (independent leaf).** Invoke `Pool.Bounded`
   validation and add explicit terminal disposition plus async consuming
   destruction. **STOP** if live resources can be ambiguously returned, shutdown
   does not await disposal, or toolchain ownership makes the generic law unsound;
   **GO** on reusable/invalid/cancelled/evicted/shutdown resource tests. A mechanical
   impossibility returns to the lead before the checked-out-close fallback.
6. **N5 — certificate heritage and semantic leaves.** After G0 external authority,
   publish truthful ASN.1 and certificate forks, improve RFC 5280, add separate
   certificate-Crypto and Darwin/Linux trust integrations, and enforce full TLS
   server policy. **STOP** on wrong ancestry, direct current Apple product use,
   Foundation/platform-C import in an Institute main target, missing typed errors,
   incomplete system roots, or any failing chain/hostname/policy fixture;
   **GO** only after heritage, import, fixture, and Apple/Linux trust gates. RSA/
   `CryptoExtras` remains a separate STOP/GO triggered by fixture evidence.
7. **N6 — TLS Crypto adapter and TLS 1.3 engine.** Land the direct Apple Crypto
   edge and TLS adapter, improve bounded RFC 8446 record consumption/secret
   ownership, and fill handshake/AEAD/SNI/ALPN/alert/close over witnesses. **STOP**
   on backend type/error leakage, untyped throws, wrong transcript/nonce, trust
   before application-data failure, cancellation leak, or unsupported suite;
   **GO** on RFC 8448, tamper/truncation/sequence, local interop, and lifecycle gates.
8. **N7 — HTTP/1.1 law and drive.** Add bounded incremental RFC 9112 framing, then
   fill `swift-http` over an injected duplex. **STOP** on smuggling ambiguity,
   inexact consumed count, post-limit append, byte loss, incorrect Host/target form,
   or ambiguous reuse; **GO** on split-at-every-byte, 1xx/chunk/trailer/pipeline/EOF,
   partial IO, cancellation, and terminal-disposition gates.
9. **N8 — L4 HTTP client.** Create `swift-components/swift-http-client`; compose
   absolute HTTPS URI, system DNS, sockets, TLS/WebPKI, HTTP, deadlines,
   `Pool.Bounded`, typed errors, finite bounds, the injected trust witness, and
   structured shutdown. **STOP** on a Router/provider dependency, redirect/stream/
   cache/wire-DNS scope creep, lifecycle authority leak, or API seam deviation;
   **GO** on the accepted executor contract and all local deterministic gates.
10. **N9 — narrow read-only interoperability and handoff.** Run local fixtures
    first, then one separately authorized bounded GET to `api.github.com`; preserve
    status, repeated `Link`, 404, and bounded `[Byte]?`. **STOP** on a credential,
    mutation, trust bypass, unbounded response, or non-clean-room resolution;
    **GO** by handing the unchanged `HTTP.Client.Executor` closure to Workspace.
    Workspace alone edits its composition; B5 retains routing ownership.

## Acceptance gates

### Format and deterministic fixtures

- System DNS fixtures cover ordered IPv4/IPv6 results, hosts/NSS behavior through
  controlled seams, cancellation before/during uninterruptible work, late-result
  freeing, queue bounds, and shutdown. RFC wire/cache fixtures are later-wave gates.
- RFC 8448 transcript/key-schedule vectors plus deterministic AEAD, record nonce,
  Finished, CertificateVerify, alert, and close-notify fixtures.
- RFC 5280 chain fixtures covering roots/intermediates, expiry/not-yet-valid,
  signature mismatch, constraints/path length, unknown critical extension,
  keyUsage/serverAuth EKU, SAN DNS/IP, encoding/NUL rejection, IDNA policy,
  wildcard boundaries, and CN fallback rejection.
- RFC 9112 official examples and adversarial framing corpus: split-at-every-byte,
  duplicate/conflicting length, TE+CL, chunk overflow/extensions/trailers, 1xx,
  HEAD/204/304, pipelining, premature EOF, and limit-at-minus/at/plus-one.

### Interoperability and security

- Local in-process/loopback fixture server with a private test root proves success,
  cancellation at each phase, shutdown, connection reuse, server close, and failure
  disposition without public network dependence.
- Cross-implementation TLS checks use a fixture oracle or read-only local peer;
  any public probe is GET-only, bounded, and carries no secret unless the owning
  application task explicitly supplies one.
- Apple and Linux gates verify their actual system trust sources. Empty/unavailable
  trust fails closed. Hostname verification cannot be disabled in the production
  initializer.
- Memory/sendability gates include strict memory safety, concurrency warnings as
  errors where supported, move-only consumer tests, lifetime compile-fail tests,
  leak/descriptor counts, cancellation races, and bounded-retention measurements.
- Every Institute main-target grep/import gate rejects `Foundation`,
  `FoundationEssentials`, `Darwin`, `Glibc`, `Musl`, `WinSDK`, URLSession, NIO/AHC,
  curl/Process, and provider modules in semantic owners, except typed L2 platform
  targets explicitly listed in the graph. The two Crypto adapters may import only
  `Crypto` plus Institute modules. The external Apple source is outside this rule's
  enforcement scope; the artifact makes no product-level transitive-purity or
  Embedded-compatibility promise.

### Clean-room and release readiness

- Fresh temporary clones resolve anonymously from canonical public remotes and
  build/test bottom-up with URL manifests; no developer-local paths, mirrors,
  credentials, or untracked fixtures are required.
- The clean room records Apple Crypto's exact resolved package identities,
  revisions, and fetched products, including SwiftASN1 unless pruning is actually
  proved. It fails on every duplicate SwiftPM identity.
- Every imported upstream source file has followable history, license, NOTICE/
  attribution, source/revision mapping, and modification record.
- Products/modules match the approved spellings; manifests contain used-only
  dependencies; DocC explains lifecycle, bounds, trust, cancellation, and failure
  semantics; API and ABI changes are reviewed before tags.
- Repository creation/push/rename/transfer/publication uses the separately granted
  authority only after these gates. No archive/delete, force-push, history rewrite,
  or release/tag is implied.

## Narrow GitHub discovery slice

The first vertical slice is deliberately general but sufficient for the consumer:

- absolute `https://api.github.com/...` GET only;
- system resolver and IPv4/IPv6 connect;
- TLS 1.3 with SNI `api.github.com`, ALPN `http/1.1`, hostname verification, and
  system trust;
- origin-form HTTP/1.1 request with derived Host;
- preserve status and repeated headers, especially `Link`;
- buffer no more than the caller-configured finite body limit;
- return 404 unchanged;
- propagate cancellation and phase timeouts by aborting the transport;
- reuse only fully consumed, unambiguous healthy connections; and
- explicit `shutdown()` by the resource owner.

The executor does not know GitHub endpoints, Accept versions, User-Agent,
authorization, pagination, JSON, repository policy, token choice, or Workspace.

## Remaining gates before package mutation

The supervisor has approved the utilization reduction, exact existing-owner
repairs, L3/L4 package cuts, direct sanctioned Apple Crypto boundary, truthful
ASN.1/certificate adaptation strategy, system-resolver-only first slice, and the
accepted Workspace executor seam. This content approval permits only this Research
amendment; it does not release package mutation.

The remaining gates are:

1. re-review this v1.1.0 amendment’s narrowed package DAG, boundary-scoped Crypto
   wording, SwiftASN1 resolution distinction, selected certificate decomposition,
   Pool disposition, leaf sequence, and STOP/GO gates;
2. separately authorize any fork, reservation rename, repository creation, or
   publication after exact upstream fork points, Apple Crypto resolved graph, and
   local/remote collision/consumer/redirect probes are refreshed;
3. release `CryptoExtras`/RSA only if the certificate algorithm fixture gate proves
   it necessary; and
4. coordinate the active `swift-kernel` lane before any lower-owner change and the
   one-Xcode lane before any Xcode gate.

Both Research records remain untracked and `_index.json` contains unrelated
overlapping edits. Their index entries are prepared local state, not durable
publication. No commit or push is authorized.

## Outcome

The roadmap’s named trigger has occurred: after this record is re-approved,
`swift-components/swift-http-client` is the generic outbound executor owner. The
Institute already has most protocol law; Wave 3 is owner repair, truthful security
adaptation, runtime composition, and bounded lifecycle—not a new semantic HTTP
model or application workaround. No mutation is safe until the lead releases G0;
the first released runtime milestone will be the existing `Event.Actor` lifecycle
repair, followed by event-backed sockets.
