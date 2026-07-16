# Pure Institute Networking

## Decision summary

The fixed destination is feasible, but the Institute does not yet have a production HTTP/TLS/PostgreSQL runtime. It does have the correct low-level shape: typed platform packages, kernel event/completion sources, `IO` strategy actors, move-only sockets, bounded async channels, HTTP/TLS protocol values, URL routing, SQL/Records membranes, and migration interfaces. The plan is to complete and compose those units. It does **not** introduce an Institute equivalent of NIO's event-loop/channel-pipeline/`ByteBuffer` aggregate.

The critical path divides cleanly:

1. Vapor removal: socket reactor/proactor factories -> incremental HTTP/1.1 -> native `swift-http` server -> measured cookie/CORS/redirect and static-file/ETag/range integrations -> preserved `Server.Responder`/middleware membrane -> both RepoTraffic executables -> canary. Heroku terminates inbound TLS and forwards HTTP/1.1, so server-side TLS and HTTP/2 are not cutover prerequisites.
2. PostgresNIO removal: the same socket substrate + system host resolution -> TLS client/trust + independent SCRAM crypto/random witnesses -> PostgreSQL wire/client/pool -> `swift-sql-postgres` -> Records/Identity compatibility -> RepoTraffic canary.
3. Final closure removal: dissolve `swift-server-foundation`, Vapor bridges, unused Queues/Redis paths, and every remaining forbidden edge in the shipped products, release lock, container, and SBOM.

The corrected controlled import census found **48 live `import Vapor` lines plus one commented `//import Vapor` line**. Of the live imports, 32 are on the deployed app path (31 in its source directory plus shared `WaitingListLive`) and 16 belong to the marketing executable. One live import has a trailing inline comment; an interim end-anchored query incorrectly excluded it and reported 47. At the frozen launch snapshot, the direct first-party imports were one each of `PostgresNIO`, `NIOCore`, and `NIOPosix`; the manifest and lockfile audit proves a much wider production/resolution closure.

The evidence also rejects two tempting overbuilds:

- RepoTraffic does not require HTTP/2 or WebSockets for the first server cutover. Heroku terminates HTTP/2 at its router and forwards HTTP/1.1, and no live source uses WebSockets.
- RepoTraffic does not currently prove a need for a native Redis client or durable queue. Its declared worker command selects scheduled jobs; there are no live dispatch sites, and cache consumption is two five-minute token `getOrSet` calls. A native recurring scheduler plus the existing memory store is the minimal replacement, subject to confirming live worker scale and singleton policy.

Static HTTP behavior is not optional: Boiler's default middleware activates streamed files, MIME, ETag/304, Last-Modified, byte Range/206, CORS, error/timing, and host/redirect policies. Those capabilities are in the parity gate even though root application source does not name their Vapor APIs.

TLS remains the largest uncertainty. RFC 8446 is a substantial codec/key-schedule library, not a session, record-protection, certificate, or trust engine. A narrow production cryptography/X.509/system-trust provider behind dedicated Institute integration boundaries is the recommended first cutover; the spike must resolve the Apple/Institute `swift-crypto` and `swift-certificates` SwiftPM identity collisions. A zero-external-cryptography interpretation would be a separate, substantially larger security program.

This is an architecture recommendation for Principal review. It is not a claim of implementation completion or acceptance.

The acceptance scope is **release purity**, not a claim that comparison tools across the ecosystem can never resolve an old implementation. Differential oracles must live in a separate comparison package root with a separate lockfile; they may not appear in either release product, the release manifest/lock, the release container, or its SBOM.

## Artifacts

- [Provenance and scope](provenance-and-scope.md)
- [Current dependency and capability inventory](current-dependency-and-capability-inventory.md)
- [Institute capability and gap atlas](institute-capability-and-gap-atlas.md)
- [Target package and layer architecture](target-package-and-layer-architecture.md)
- [External-to-Institute replacement matrix](replacement-matrix.md)
- [Networking and concurrency decision](networking-and-concurrency-decision.md)
- [PostgreSQL decision](postgresql-decision.md)
- [Validation and benchmark program](validation-and-benchmark-program.md)
- [Migration waves, estimates, risks, and decisions](migration-waves.md)
- [Independent review and disposition](independent-review.md)

## Hard gates

No forbidden dependency is removable merely because imports have disappeared. A removal gate requires all of the following:

1. the replacement path passes its protocol, failure, resource, performance, and platform gates;
2. RepoTraffic passes shadow/replay and reversible production canaries;
3. the release build consumes a committed `Package.resolved` instead of deleting it;
4. a versioned target-aware closure tool seeded separately at `com_repotraffic_app` and the marketing executable contains no forbidden production-product path, and the release manifest/lock contains no forbidden comparison identity;
5. `swift package show-dependencies` is retained only as a resolved-package superset, while the exact release build's verbose build plan, link map/inputs, binary symbols, and container/SBOM independently agree with the target-aware closure;
6. source and manifest scans have known positives and agree with those artifact controls; and
7. the compatibility package and its product declarations are removed, not merely left unimported.
