# Institute Server-Stack Architecture

<!--
---
version: 1.1.0
last_updated: 2026-07-06
status: DECISION
tier: 2
scope: ecosystem-wide
changelog:
  - 1.1.0 (2026-07-06): Principal RATIFIED (same day) → status DECISION. W0 re-assessed
    after the tower/rename wave landed; torn-mains section and W0 gate updated to the
    post-heal state (RFC family builds green; windows tear moved into the swift-windows
    consumer). W1 execution begun (swift-http-standard created; swift-http-headers
    retired-archived; swift-server slim dispatched).
  - 1.0.0 (2026-07-06): Initial finalized design.
---
-->

## Context

**Trigger**: the repotraffic commercial revival (principal rulings 2026-07-06). The scoping
session produced a working membrane prototype (`swift-foundations/swift-server` @ `2af9dee`),
three maturity sweeps, a dep-health probe, and a port workbook
(`coenttb/repotraffic-com-server/PORT-WORKBOOK.md` @ `713dc01`) — then the principal reframed
all of it as **pre-research** and paused execution (`PROMPT-repotraffic-rebuild-phase-1.md`)
behind this design. Handoff: `Workspace/handoffs/HANDOFF-institute-server-stack-design.md`.

**Deliverable**: the Institute's native server/persistence/HTTP layering — ecosystem-level,
with repotraffic as the forcing consumer — resolving the handoff's eight open questions into
one coherent layering that execution can be dispatched against without re-litigating
boundaries. This document changes no code; it prescribes.

**Skills loaded** ([RES-033]): swift-institute-core, swift-institute ([ARCH-LAYER-*]),
swift-institute-ecosystem ([ECO-*]), swift-package ([PKG-NAME-*]/[PKG-DEP-*]),
research-process ([RES-*]), handoff, supervise.

**Fixed inputs (principal rulings, 2026-07-06 — not re-opened here)**:

1. Commercial revival YES; app stays at `coenttb/repotraffic-com-server` (rebuild in place).
2. Membrane is institute-side: `swift-foundations/swift-server`, PRIVATE non-L3 tenant
   (L4 chassis), metadata-marked, re-home at the future L4/L5 org decision.
3. Move OFF PostgresNIO/Vapor plumbing toward institute-native engines eventually, not now.
4. swift-records: supersede-and-split (DSL→L2, plumbing→L3); NOT convert-whole, NOT
   fold-into-postgresql-standard.
5. Phase-2 Redis drop approved (cache → Postgres tables + in-proc LRU/TTL).
6. Stub-fill arcs (scheduler → sql-postgres → http server) green-lit post-Phase-1.
7. No tags this phase; new-ecosystem platform floor macOS/iOS v26.

## Question

Where does every server/persistence concern live in the five-layer model, and what is the
engine-quarantine boundary — such that external engines (Vapor, PostgresNIO, NIO,
AsyncHTTPClient, vapor/queues) sit *behind* institute L2/L3 interfaces rather than leaking
through, and can be swapped for institute-native engines later without touching consumers?

## Verified Current State (2026-07-06)

All claims re-verified against live source this session per [RES-013a]/[RES-037]; the two
pre-research corrections below are load-bearing.

### Correction 1 — the L2 HTTP/network model already exists

The handoff's re-derivation table proposed "L2 — populate empty `swift-http-headers` /
`swift-http`". Both framings are wrong against live source: those two repos live in the
**swift-foundations (L3) org** and are reservation stubs, while the L2 spec-direct model is
already substantially implemented in **swift-ietf** (enumeration:
`find <pkg>/Sources -name '*.swift' | wc -l` + LOC via `cat | wc -l`, run 2026-07-06):

| L2 package | Content | State |
|---|---|---|
| `swift-rfc-9110` (HTTP Semantics) | `RFC_9110` namespace + `public typealias HTTP`; `HTTP.Method` (open-set struct w/ isSafe/isIdempotent/isCacheable), `HTTP.Status`, `HTTP.Headers` (ordered, case-insensitive), `HTTP.Header.Field`, `HTTP.Request`/`.Response`, content negotiation, authentication, preconditions, media types; built over L1 parser/ascii/byte primitives + RFC 3986/4648/5322; **zero Foundation imports** | REAL — 48 files, 5,835 LOC. **Builds green on 6.3.2** (`TOOLCHAINS=org.swift.632202605101a swift build`, 2,531 files, after the tower-wave heal + a `swift package update` cache refresh) `[Verified: 2026-07-06, post-heal]` |
| `swift-rfc-9112` (HTTP/1.1 syntax) | message framing/parse/serialize | REAL — 17 files, 2,910 LOC |
| `swift-rfc-9111` (HTTP caching) | cache semantics | REAL — 12 files, 2,150 LOC |
| `swift-rfc-8446` (TLS 1.3) | wire model | REAL — 20 files, 1,565 LOC |
| `swift-rfc-9293` / `768` / `791` (TCP/UDP/IP) | wire models | REAL — 2,325 / 1,188 / 3,326 LOC |
| `swift-sockets-standard` (L2 converger) | `Sockets.TCP/UDP/IP` typealias convergence over the three RFCs | REAL — thin, 270 LOC |
| `swift-rfc-6455` (WebSocket) | frame model | REAL — 925 LOC |
| `swift-rfc-3986` (URI) + `swift-uri-standard` + `swift-whatwg-url` | URI/URL | REAL — 5,645 / 241 / 3,506 LOC |
| `swift-rfc-6265` (Cookies) | placeholder | 14 LOC |
| `swift-rfc-7230`–`7235` (obsoleted HTTP/1.1 family) | 7230 has 1,371 LOC legacy; 7231 248 LOC; 7232–7235 ~10-LOC placeholders | superseded by 9110/9111/9112 |
| `swift-rfc-9113` / `9114` / `9000` (HTTP/2, HTTP/3, QUIC) | reservation stubs | no Package.swift |

### Correction 2 — swift-postgresql-standard's Foundation exposure is ~5× the pre-research claim

`import Foundation` appears in **~72 of 132 main-target files** (macro target: 0), not "~15"
(`grep -rl '^import Foundation' Sources/`, 2026-07-06). Everything else about the package
confirmed: ~21,806 LOC StructuredQueries DSL + macros; **no wire client** — postgres-nio is
declared but consumed only by the `PostgreSQL Standard Test Support` target, trait-gated
behind `SQLValidation` (Package.swift:25–30, 72–73). `[Verified: 2026-07-06]`

### Confirmed as handed off

- **L3 server/persistence repos are reservation stubs** (LICENSE + lint config, no
  Package.swift): `swift-http` and the entire `swift-http-*` family, `swift-websocket`,
  `swift-transport-layer-security`, `swift-sql`/`-postgres`/`-sqlite`/`-mysql`,
  `swift-migrations`, `swift-redis`, `swift-keyvalue`, `swift-pool-connections`,
  `swift-scheduler`, `swift-graceful-shutdown`, `swift-log`. `[Verified: 2026-07-06]`
- **`swift-sockets`** (L3): 802 LOC, IPv4 TCP **listener/server-only**, no client connect, no
  TLS; institute-pure deps (swift-io/kernel/threads/executors). `[Verified: 2026-07-06]`
- **Mature L3 substrate is real**: swift-io (1,818 LOC), swift-json (4,102), swift-html
  (1,042 + render tree), swift-dependencies (876, TaskLocal `@Dependency`), swift-environment
  (480, institute-pure), swift-json-web-token (782, HS/ES only). `[Verified: 2026-07-06]`
- **Prototype `swift-server` @ `2af9dee`**: clean tree; 4 products (`Server`,
  `Server PostgreSQL`, `Server Jobs`, `Server HTTP Client`); 9 external deps (vapor,
  postgres-nio, queues(+redis-driver), async-http-client, swift-nio(+ssl), swift-log);
  **zero institute package deps**; every engine import is `internal import` with
  `InternalImportsByDefault` enforced package-wide; 31 unit tests green. The re-declared
  HTTP vocabulary lives in the engine-free `Server Shared` target: `Server.Headers`,
  `Server.Headers.Field`, `Server.Method` (closed 7-case enum), `Server.Status`.
  Foundation leaks into the surface at `Server.Environment` and
  `Server.PostgreSQL.Row`/`.Value`. `[Verified: 2026-07-06]`
- **`coenttb/swift-networking` is a GitHub-flagged QUIC fork** (excluded as owned heritage) —
  the name is not free. Source: `Research/coenttb-heritage-inventory-beyond-18.md` v1.1.0
  (GitHub-reconciled). `[Verified: 2026-07-06]`
- **Torn mains block execution, not design**: `Shared Primitive`→`Ownership Shared Primitive`
  (6 foundations consumers; transitively blocks institute swift-html and — via swift-tests —
  swift-postgresql-standard resolution), `RFC_7519`→`RFC 7519` (blocks swift-json-web-token),
  `swift-windows-standard`→`swift-windows-32` half-rename. Owned by the rename wave; this
  arc MUST NOT touch that tree. (`Workspace/inbox.md`, TORN-MAINS entry, two-source verified.)
  **Post-heal re-assessment (same day, after the tower/rename wave landed)**: the
  ownership-shared tear is **healed end-to-end** — `swift-array-primitives` main now
  references `"Ownership Shared Primitive"` (Package.swift:79,129), all six foundations
  consumers reference the new product name, and `swift-rfc-9110` builds green on 6.3.2
  (stale SwiftPM caches must be refreshed with `swift package update`; a stale cached clone
  reproduces the old failure after the manifests heal). The rfc-7519 tear is
  manifest-healed (`swift-json-web-token` now asks `"RFC 7519"`). The **windows tear moved
  rather than healed**: `swift-windows-standard`'s manifest is internally consistent as
  `swift-windows-32`, but consumer `swift-foundations/swift-windows` targets reference
  `package: "swift-windows-32"` while the dep still resolves under identity
  `swift-windows-standard` ([PKG-DEP-008] — repo not renamed), so `swift-postgresql-standard`
  remains resolution-blocked via swift-tests → swift-kernel → swift-windows. Residual tower
  tear: `swift-async-primitives` main `8699564` still torn vs published buffer mains
  (39-file dirty local tree — arc in flight); not on this design's W1 path.
  `[Verified: 2026-07-06, post-heal]`

## The Layering (normative spine)

The five-layer placement of every server-stack concern. This table is the design; everything
after it is rationale and mapping.

| Concern | Layer | Package | State → action | Engine today (quarantined at L4) | Institute-native path |
|---|---|---|---|---|---|
| HTTP message vocabulary (method, status, headers, request/response semantics, negotiation, auth, preconditions) | L2 | `swift-ietf/swift-rfc-9110` | REAL → **adopt** | none | done |
| HTTP/1.1 syntax + framing | L2 | `swift-rfc-9112` | REAL → adopt (native server arc) | none | done |
| HTTP caching | L2 | `swift-rfc-9111` | REAL → adopt as needed | none | done |
| Cookies | L2 | `swift-rfc-6265` | placeholder → stub-fill when jar needed | none | fill |
| Stable HTTP consumer import | L2 | `swift-standards/swift-http-standard` | **NEW (thin converger)** — W1 | none | — |
| URI | L2 | `swift-rfc-3986` → `swift-uri-standard` | REAL → adopt | none | done |
| TCP/UDP/IP wire model | L2 | `rfc-9293`/`768`/`791` → `swift-sockets-standard` | REAL | none | done |
| TLS 1.3 model | L2 | `swift-rfc-8446` | REAL | none | done |
| WebSocket model | L2 | `swift-rfc-6455` | REAL → deferred consumer | none | done |
| SQL/Postgres query encoding (DSL) | L2 | `swift-postgresql-standard` | REAL → adopt; Foundation-purity workstream (Q7) | none | done |
| SQL execution interface (`SQL.Database`, read/write, statement, row, value) | L3 | `swift-sql` | stub → **fill now, engine-free** (W2) | Live backing at L4 | native driver replaces backing |
| Schema migrations | L3 | `swift-migrations` | stub → **fill now** (W2; extends `SQL`) | runs over `SQL.Database` | — |
| Postgres wire driver | L3 | `swift-sql-postgres` | stub → deferred stub-fill arc | **never hosts postgres-nio** | wire protocol v3 + SCRAM over sockets client |
| Socket transport | L3 | `swift-sockets` | partial → stub-fill (client connect, IPv6) | NIO stays at L4 | fill |
| TLS transport | L3 | `swift-transport-layer-security` | stub → deferred behind TLS-strategy gate ([BET-REWRITE] tactical) | NIOSSL at L4 | rfc-8446 + strategy ruling |
| Composed HTTP capability (client, server) | L3 | `swift-http` | stub → deferred stub-fill arc | AsyncHTTPClient / Vapor at L4 | over sockets + TLS + 9110/9112 |
| Connection pooling | L3 | `swift-pool-connections` | stub → deferred (with native driver) | engine-internal pooling at L4 | fill |
| Job + schedule model | L3 | `swift-scheduler` | stub → **fill interface now** (W3) | vapor/queues at L4 | in-proc executor + Postgres-backed state (Phase 2) |
| Web assembly (bootstrap, lifecycle, routing seam, middleware, request/response app view) **+ all engine Live backings** | L4 | `swift-server` (PRIVATE tenant in swift-foundations org, per ruling) | REAL → **slim** (W1–W3) | Vapor, NIO(+SSL), postgres-nio, queues(+redis driver), AsyncHTTPClient, swift-log | shrinks as L3 natives land |
| Application | L5 | `coenttb/repotraffic-com-server` (per ruling) | port waves per `PROMPT-repotraffic-rebuild-phase-1.md`, resumed against this design | none directly | — |

Out of the institute stack entirely (scoping "ring 3", unchanged): coenttb
GitHub/Stripe/Mailgun typed clients + L4 identities service.

## The Engine-Quarantine Rule (Q4)

The exact per-layer rule. "External engine" = any non-institute runtime dependency (Vapor,
swift-nio family, PostgresNIO, vapor/queues, RediStack, AsyncHTTPClient, swift-log, Apple
Foundation-as-runtime).

1. **L1/L2 — forbidden.** Spec and vocabulary layers import no engines and no Foundation
   ([PRIM-FOUND-001], [ARCH-LAYER-013]). Already true of the RFC family; postgresql-standard's
   Foundation exposure is the one violation (Q7).
2. **L3 — forbidden.** Foundations are institute-native composition only ([ARCH-LAYER-011]:
   improve the institute, never adopt a third-party engine at the foundations layer). L3
   server-stack packages are either engine-free *interfaces* (swift-sql, swift-migrations,
   swift-scheduler — buildable now) or engine-free *implementations* (swift-sockets,
   swift-sql-postgres, swift-http — fill natively, later). **PostgresNIO does not go behind
   `swift-sql` at L3, and `swift-sql-postgres` never wraps PostgresNIO** — this corrects the
   pre-research table, which placed engines behind L3 interfaces. An L3 package that imports
   an engine has poisoned the layer's timelessness and made the eventual native swap an
   in-place package rewrite instead of a backing swap.
3. **L4 — the single quarantine zone.** `swift-server` is the ONLY package in the ecosystem
   permitted to import external engines, and only as `internal import` under
   `InternalImportsByDefault` (already enforced at `2af9dee` — keep). No engine type appears
   in any public signature. Each engine binding is a *Live conformance of an L3 interface*
   (or, where no L3 interface exists yet, a chassis-owned surface). Apple Foundation counts:
   the L4 public surface MUST be Foundation-free per [ARCH-LAYER-007] (current leaks:
   `Server.Environment` — replace with L3 swift-environment; `Server.PostgreSQL.Row`/`.Value`
   — these types move to swift-sql, Foundation-free).
4. **L5 — forbidden (institute stack).** The app imports the L2 DSL + vocabulary, L3
   interfaces, and the L4 chassis; it never imports an engine for institute-stack concerns.
   (Ring-3 vendor clients are outside the stack and keep their own deps.)

**Swap corollary** (the point of the whole design): consumers hold L2/L3 types only. Moving
from an external engine to an institute-native engine = adding the L3-native conformance and
deleting the L4 Live backing. Zero consumer-visible change.

## Resolutions

### Q1 — HTTP model home + shape: adopt the RFC 9110 family; add a thin `swift-http-standard` converger; dissolve `Server Shared`

**Decision**:

1. The HTTP message model's home is the **existing** L2 spec-direct family:
   `swift-rfc-9110` (semantics), `swift-rfc-9112` (HTTP/1.1 syntax), `swift-rfc-9111`
   (caching), `swift-rfc-6265` (cookies, fill later). Nothing is re-invented; the
   pre-research "populate empty L2 repos" premise is refuted by verified state.
2. Create **`swift-standards/swift-http-standard`** — a thin convergence package per
   [ECO-005], shape-precedented by `swift-sockets-standard` (270 LOC): `@_exported` re-export
   of the 9110/9111/9112 surfaces (9113/9114/6265 join as they fill). Consumers import
   `HTTP Standard` and never track RFC renumbering (the 7230→9110 transition is exactly the
   churn this pattern absorbs).
3. The friendly **`HTTP` typealias moves** from swift-rfc-9110 to swift-http-standard: the
   spec-direct package exports spec-mirroring `RFC_9110` ([API-NAME-003]); the converger owns
   the stable vocabulary name. (Breaking only within the pre-tag ecosystem; no-tags phase
   makes this a mechanical follow-up in the RFC repo + its consumers.)
4. The prototype's `Server Shared` target **dissolves**. Type mapping:

| Prototype (`Server Shared`, @ `2af9dee`) | Replacement (L2) | Delta |
|---|---|---|
| `Server.Method` (closed 7-case enum) | `HTTP.Method` | open method set (RawRepresentable) + isSafe/isIdempotent/isCacheable — spec-correct; CONNECT/TRACE/PATCH come free |
| `Server.Status` (code + reason struct) | `HTTP.Status` | supersedes the 18 hand-rolled presets |
| `Server.Headers` (ordered, case-insensitive) | `HTTP.Headers` | same semantics, spec-owned |
| `Server.Headers.Field` | `HTTP.Header.Field` | + typed `Name`/`Value` with field-syntax validation |
| `Server` (namespace) | stays — L4 chassis namespace | |

5. The 7230-family repos are **not filled**: 9110/9111/9112 obsolete them. README-mark
   7230/7231's legacy content historical; the 7232–7235 placeholders stay dormant
   reservations under the authority-org completeness pattern.
6. `swift-foundations/swift-http-headers` is **retired** ([ARCH-LAYER-009]: committed empty
   reservation, trivially git-recoverable, verified dead — no Package.swift, no consumers).
   Its would-be mission (header vocabulary, typed field values) is owned by RFC 9110/9111 at
   L2. Repo deletion is an outward action → execution needs the principal's YES; the design
   prescribes it.

**Why**: [ECO-002] first question — HTTP is externally specified → L2. The verified state
shows the L2 work is largely done and institute-pure (zero Foundation, L1-primitives-based,
builds green on 6.3.2). Extracting the prototype's four value types into new packages would
re-invent a worse (closed-set, spec-blind) version of what exists ([RES-019] source-shape
sweep; [ARCH-LAYER-011]).

### Q2 — DB plumbing topology: `swift-sql` (interface) + `swift-migrations` (extension) now; `swift-sql-postgres` (native driver) later

**Decision**: confirm the reserved three-package topology, with the corrected engine
placement (engines at L4, not behind L3 — Q4 rule 2):

- **`swift-sql`** (L3, fill now, engine-free): namespace `SQL` ([PKG-NAME-001] noun).
  Owns the agnostic execution interface derived call-site-first from the app's 27 `*Live`
  files (`swift-server/Research/consumer-call-site-inventory.md` §4):
  - `SQL.Database` — the handle: `read { }` / `write { }` (reader/writer split), transaction
    scoping; typed throws (`SQL.Error`) per [API-ERR-001].
  - `SQL.Statement` — the structural seam: `(sql: String, bindings: [SQL.Value])`. This is
    the prototype's validated `Server.PostgreSQL.Statement` shape, promoted to L3.
  - `SQL.Row`, `SQL.Value` — Foundation-free (fixes the prototype's `Row`/`Value` leaks).
  - Execution verbs: `execute`, `fetchOne`, `fetchAll` over `SQL.Statement`.
  - **`SQL Test Support`**: `withRollback` (mirrors the swift-records affordance the app's
    test suites assume).
  - **`SQL Dependencies Integration`** (opt-in product): declares the `defaultDatabase`
    dependency key over L3 swift-dependencies (L3→L3 composition, precedented by
    swift-sockets→swift-io/kernel/threads).
  - **`SQL PostgreSQL Standard Integration`** (opt-in product): bridges the L2 DSL's built
    statements → `SQL.Statement` (L3→L2, downward, legal). Opt-in so the core `SQL` product
    resolves even while the postgresql-standard graph is torn (see gates).
- **`swift-migrations`** (L3, fill now): extends the recipient namespace —
  `SQL.Migration` (named, ordered) + `SQL.Migrator` (`registerMigration(_:){db}`,
  `migrate(db)`, applied-table bookkeeping). Depends on swift-sql only. The prototype's
  `Server.PostgreSQL.Migration`/`.Migrator` logic relocates here, de-Postgres-ified.
- **`swift-sql-postgres`** (L3, deferred to its green-lit stub-fill arc): the
  institute-native Postgres driver — wire protocol v3 + SCRAM over swift-sockets
  client-connect — conforming to `SQL.Database`. It never hosts PostgresNIO; the PostgresNIO
  fallback the scoping doc mentions lives in the L4 membrane and *retires* when this lands.
- `swift-sql-sqlite` / `swift-sql-mysql`: dormant reservations; same driver pattern when
  their arcs open.

**App call-site mapping** (from the workbook + inventory — the complete `Records` surface):

| App call site | Final home |
|---|---|
| `@Table` / `@Selection` / `@Column(as:)` / `#sql` / `.insert{}.onConflict{}.doUpdate{}` / `.returning` / `.select/.where/.update/.delete` / `.join/.leftJoin` / `.group/.having` / aggregates / `With{}` CTEs | L2 `swift-postgresql-standard` (near-verbatim; `X.PostgresJSONB.self` → `X.JSONB.self`) |
| `@Dependency(\.defaultDatabase)` | `SQL Dependencies Integration` key → `SQL.Database` |
| `db.read { }` / `db.write { }` | `SQL.Database.read` / `.write` |
| `.fetchOne(db)` / `.fetchAll(db)` / `.execute(db)`; `db.execute("CREATE …")` | `SQL` execution verbs via the `SQL.Statement` seam |
| `Records.Database.Migrator()` / `.registerMigration("name"){db}` / `.migrate(db)` | `SQL.Migrator` / `SQL.Migration` (swift-migrations) |
| `withRollback` (tests) | `SQL Test Support` |
| `Database.pool(configuration:minConnections:maxConnections:)` | L4 Live constructor (pooling stays engine-side until swift-pool-connections/native driver) |
| `any Records.Database.Reader` / `Writer` | `SQL.Database` reader/writer split |

**Why not the alternatives**: a single `swift-database` fuses three missions
([ARCH-LAYER-010]) — agnostic execution, per-DBMS drivers, schema evolution — and the name
falsely spans non-SQL stores (redis/keyvalue are sibling reservations); it is also an
ask-gated colliding name per the handoff's ground rules. An institute `swift-records`
(convert-whole) is foreclosed by the fixed ruling. The reserved sibling topology already
encodes the correct decomposition; this design ratifies it.

### Q3 — swift-server: L4 chassis, slimmed to assembly + quarantine; tenancy per standing ruling

**Decision**: `swift-server` is the **L4 Components** package (the Boiler successor —
"opinionated assembly"). After slimming it owns exactly:

1. **Bootstrap + lifecycle**: `Server.Application` (configure → run → shutdown),
   `Server.Configuration`; environment via L3 **swift-environment** (drops the
   Foundation-importing `Server.Environment`).
2. **Routing seam + middleware**: `Server.Route`, `Server.Responder`, `Server.Middleware`
   (the decoded-route → response seam the app plugs URLRouting into during Phase 1).
3. **App-facing request/response views**: `Server.Request` / `Server.Response` whose
   vocabulary is the L2 types (`HTTP.Method`, `HTTP.Status`, `HTTP.Headers`) — convenience
   builders (`.json`/`.html`/`.redirect(to:)`/bare status), body decode, `Server.Error`
   carrying `HTTP.Status`.
4. **The engine Live backings** (Q4 rule 3): `Server PostgreSQL` becomes the PostgresNIO
   conformance of `SQL.Database` (its interface types migrate to swift-sql/swift-migrations);
   `Server Jobs` becomes the vapor/queues conformance of the swift-scheduler interface;
   `Server HTTP Client` stays a chassis-owned outbound surface (see Q8 — zero direct app
   call sites, so no L3 interface is fabricated for it yet).

Product set stays four; `Server Shared` dissolves (Q1). Layer designation: **L4**, private,
metadata-marked non-L3 tenant of the swift-foundations org **per the standing 2026-07-06
ruling** — re-homing happens at the future L4/L5 org decision, which is an org-creation
action outside this design's authority. What this design adds: the L4 designation is now
*load-bearing* (it is the only engine-quarantine zone), so the eventual re-home must move
the package unchanged, not re-layer it.

### Q4 — Engine quarantine

Resolved as the normative rule above (see *The Engine-Quarantine Rule*). The prototype's
defect is thereby named precisely: it quarantined engines correctly (internal imports,
membrane-honest) but **re-declared institute vocabulary instead of importing it** — the fix
is Q1 (dissolve Server Shared) + Q2/Q3 (interfaces to L3), not more wrapping.

### Q5 — No `swift-networking`; the L3 transport story is the existing reserved decomposition

**Decision**: there is **no swift-networking package** in the layering.

- The endgame transport decomposition already exists as missions: **`swift-sockets`** (socket
  transport — fill client-connect + IPv6 + nonblocking in its stub-fill arc),
  **`swift-transport-layer-security`** (TLS transport over rfc-8446 — deferred behind the
  TLS-strategy ruling, the [BET-REWRITE] tactical gate), **`swift-http`** (composed
  client/server capability over both + 9110/9112). L2 wire models (sockets-standard, 9293,
  768, 791, 8446) are done.
- The name `swift-networking` is rejected: (a) `coenttb/swift-networking` is a GitHub-flagged
  QUIC fork — the name is heritage-encumbered and collision-prone ([Verified: 2026-07-06],
  heritage inventory v1.1.0); (b) a networking umbrella is a kitchen-sink mission over
  already-well-decomposed sibling missions ([ARCH-LAYER-010]). No new name is chosen, so the
  handoff's ask-gate (name collisions require a principal ask) is satisfied by construction.
  If a convenience umbrella *product* over sockets+TLS is ever wanted, that is a separate
  principal ask at that time.
- **In scope now: nothing.** Repotraffic needs no institute transport in Phases 1–2 (inbound
  TLS terminates at the reverse proxy; outbound HTTPS stays on the quarantined
  AsyncHTTPClient backing until the TLS gate clears — never gate the product on it).

### Q6 — swift-records: supersede-and-split (ratifying the fixed ruling, with the complete map)

The DSL half is `swift-postgresql-standard` (L2, exists — the port workbook confirms
near-verbatim source compatibility). The plumbing half is `swift-sql` + `swift-migrations`
(L3 interfaces, Q2) with the L4 PostgresNIO Live backing carrying execution until
`swift-sql-postgres` lands. The complete per-call-site map is the Q2 table; no `Records`
usage lacks a destination. swift-records itself is neither transferred nor converted — the
heritage record (Group-G, heritage Assignment 2) notes supersession as its terminal
disposition, per the scoping doc's cross-arc note.

### Q7 — L2 Foundation purity of swift-postgresql-standard: fix by scheduled workstream, not accepted debt

**Decision**: the violation ([ARCH-LAYER-013]/[PRIM-FOUND-001]) is **not accepted as
permanent debt** — but the fix is a **dedicated post-Phase-1 workstream**, not a Phase-1
gate. The corrected measurement (72 of 132 main-target files, ~5× the pre-research estimate)
cuts both ways: too large to fold silently into the port (it would derail the revenue arc),
too large to wave off (it poisons Foundation-freedom for every downstream consumer of the
institute's flagship L2 DSL and breaks [CI-022] ecosystem enforcement).

Workstream shape (dispatched as its own arc after Phase 1):

1. Inventory the 72 files' actual Foundation surface (expected dominant classes: `Date`,
   `Data`, `UUID`, `Decimal`, Codable-driven encodings for column bindings).
2. Map to institute equivalents (swift-time / byte primitives / swift-uuids / decimals).
3. Genuinely Foundation-adjacent interop (Foundation-type column bindings for consumers that
   hold Foundation values) moves to a **`PostgreSQL Standard Foundation Integration`**
   opt-in subtarget per the [CI-022]/[ARCH-LAYER-007] pattern — the main target goes clean.
4. Until the workstream lands, the violation is a *documented, dated* known-violation (this
   doc is the record); Phase-1 app consumption is unaffected (source-level DSL use).

### Q8 — Revenue-vs-architecture line: buy interfaces now, engines later

**The line**: everything that determines *what consumers import* is built now; everything
that determines *what executes underneath* is deferred to the green-lit stub-fill arcs.
Rationale: the interfaces are small, cheap, and permanent (timeless-infrastructure grade);
the engines are large, replaceable, and already ruled "eventually, not now". The app never
waits on a native engine, and no consumer ever migrates twice.

Built now (execution waves, below): `swift-http-standard` (thin), the swift-server slim
(adopt L2 vocabulary, shed Foundation), `swift-sql` + `swift-migrations` +
`swift-scheduler` interfaces + L4 conformances, then the app port. Interface shapes are
call-site-derived (the inventory's 12 capabilities), so they are sized by evidence, not
speculation. Call-site evidence also draws the line *within* the interface set: SQL has 27
Live files of app call sites and jobs has a 3-job registry — both get L3 interfaces now;
outbound HTTP has **zero** direct app call sites — no L3 interface is fabricated for it
(chassis-owned until `swift-http`'s arc).

Deferred (in the already-green-lit order — scheduler-native, sql-postgres, http server —
plus their gates): native drivers and transports (sockets client-connect/IPv6, TLS behind
the strategy ruling, sql-postgres wire v3 + SCRAM, native swift-http, websocket), Postgres-
backed job state + in-proc LRU/TTL cache (Phase 2, Redis dropped per ruling), rfc-6265 fill,
9113/9114/9000, the http middleware family, connection pooling, the Q7 Foundation
workstream.

## Execution Consequences

To be dispatched only after the principal ratifies this design ([SUPER-057]: authoring this
doc is in-scope; dispatching the program is not).

- **W0 (external gate, owned by the rename wave — not this arc)**: **PARTIALLY CLEARED
  2026-07-06 post-ratification** — ownership-shared healed end-to-end (RFC family builds
  green; W1 unblocked), rfc-7519 manifest-healed. STILL OPEN: the windows tear moved into
  consumer `swift-foundations/swift-windows` (`package: "swift-windows-32"` refs against
  resolution identity `swift-windows-standard`), keeping `swift-postgresql-standard`
  resolution-blocked — this gates W4's postgres swap and postgresql-standard's own
  builds, NOT W1–W3.
- **W1 — vocabulary**: create `swift-http-standard` (thin converger; `HTTP` typealias moves
  here from rfc-9110, mechanical consumer follow-up in the RFC repo). Slim `swift-server`:
  dissolve `Server Shared`, adopt `HTTP.Method`/`.Status`/`.Headers`/`.Header.Field`, swap
  `Server.Environment` for L3 swift-environment, purge Foundation from the public surface.
- **W2 — persistence interfaces**: fill `swift-sql` (core + Test Support + Dependencies
  Integration + PostgreSQL Standard Integration) and `swift-migrations`; relocate the
  prototype's interface types out of `Server PostgreSQL`, leaving it as the PostgresNIO
  Live conformance.
- **W3 — jobs interface**: fill `swift-scheduler` (Job / Schedule (`.hourly(minute:)` /
  `.daily(at:)`) / Registry, Codable payloads); `Server Jobs` becomes the vapor/queues Live
  conformance with `.redis(url:)` / `.inProcess` drivers.
- **W4 — the port**: resume `PROMPT-repotraffic-rebuild-phase-1.md` against this design
  (five swaps + wave order per the port workbook). W1–W3 land first so app call sites
  migrate once.
- **Then**: the stub-fill arcs and the Q7 workstream, per the Q8 line. Retirement of
  `swift-http-headers` and the 7230-family README-marking ride the first HTTP-adjacent arc
  (repo deletion needs a principal YES).
- **Standing constraints**: no tags; serial per-package builds on 6.3.2; private repos stay
  private; public pushes ask first; `coenttb/*` untouched except repotraffic-com-server.

**Cross-arc conflict to surface (heritage arc)**: the coenttb heritage inventory (v1.1.0)
routes the pointfree FORK `swift-structured-queries-postgres` into
`swift-foundations/swift-sql-postgres` (inventory lines 179, 347). That conflicts with this
design's mission for the repo (institute-native wire driver; never hosts engines or forks —
Q2/Q4). Recommended reconciliation, to be adjudicated in the heritage arc: the fork's
DSL-binding lineage belongs to the L2 DSL story (postgresql-standard already carries the
StructuredQueries heritage) or the `SQL PostgreSQL Standard Integration` bridge target — not
to the driver repo. The inventory's `swift-http`/`swift-http-routing` port targets (local-only
coenttb packages → the L3 reservations) are compatible with this design and become inputs to
those stub-fill arcs.

## Rejected Alternatives

| Alternative | Rejection |
|---|---|
| Populate `swift-http`/`swift-http-headers` as the L2 HTTP model home (pre-research table) | Refuted by verified state: the model exists at L2 in swift-ietf (11k+ LOC across 9110/9111/9112); those repos are L3-org reservations. Re-inventing violates [ARCH-LAYER-011]/[RES-019]. |
| Engines behind L3 interfaces now (pre-research: "swift-sql … PostgresNIO behind the interface"; "swift-sql-postgres wraps PostgresNIO now") | Poisons L3 timelessness; makes the native swap an in-package rewrite instead of an L4-backing swap; multiplies quarantine zones. Structural correctness outranks the smaller diff ([RES-036]). |
| Single `swift-database` | Fuses three missions ([ARCH-LAYER-010]); name spans non-SQL stores; collides with an ask-gated heritage name; reserved topology already correct. |
| Institute `swift-records` (convert-whole) or fold-DSL-into-standard | Foreclosed by the fixed principal ruling (supersede-and-split). |
| New `swift-networking` (sockets+TLS+transport umbrella) | Name collision with the coenttb QUIC fork; kitchen-sink mission over an already-decomposed reservation set; nothing in scope needs it. |
| Fill the RFC 7230-family | Obsoleted by 9110/9111/9112; placeholders stay dormant, marked historical. |
| Accept the postgresql-standard Foundation violation as permanent debt | Violates [ARCH-LAYER-013]; breaks [CI-022] and Foundation-freedom for every downstream consumer. Scheduled workstream instead (Q7). |
| Fabricate an L3 HTTP-client interface package now | Zero direct app call sites (inventory §6); interface shape would be speculative, not call-site-derived. Chassis-owned until swift-http's arc. |

## Residual ([RES-027])

**Premises (load-bearing, each backed by evidence)**: the RFC-9110 family is real,
institute-pure source (48-file/5,835-LOC enumeration + zero-Foundation grep this session)
and **builds green on 6.3.2** (verified post-heal, same day); the `(sql, bindings)`
statement seam suffices for the app's DSL usage (validated by the prototype's
`Server.PostgreSQL.Statement` + the workbook's near-verbatim DSL port finding);
postgres-nio absence from postgresql-standard's main target (manifest lines quoted above).

**Directions (not constraints)**: whether `swift-http-standard` should eventually also
converge 9113/9114; whether the http middleware family repos (cors/etag/range/redirect/
compression/content-negotiation/cookies/body/routing) each retain distinct L3 middleware
missions or partially fold — decided per-repo at their stub-fill arcs (default: retain,
mission = the concern as Middleware over L2 semantics); the L4/L5 org shape (standing
ruling's decision point).

## References

- `Workspace/handoffs/HANDOFF-institute-server-stack-design.md` (the consumed handoff)
- `Workspace/handoffs/SCOPING-repotraffic-rebuild.md` (three-ring architecture, phases)
- `Workspace/inbox.md` 2026-07-06 entries (rulings; torn-mains, two-source verified)
- `swift-foundations/swift-server` @ `2af9dee` — prototype; `Research/consumer-call-site-inventory.md` (call-site derivation, 12 capabilities, CONTINGENCY note)
- `coenttb/repotraffic-com-server/PORT-WORKBOOK.md` @ `713dc01` (five swaps, Records map, wave order)
- `swift-institute/Research/coenttb-heritage-inventory-beyond-18.md` v1.1.0 (swift-networking fork status)
- `swift-institute/Research/claude-code-swift-rewrite-feasibility.md` v1.2.0 §6 (TLS-strategy gate; HTTP gap analysis)
- Prior art: `apple-http-api-proposal-patterns.md`, `apple-http-middleware-chain-isolation.md`, `apple-http-withclient-scoped-pattern.md`, `apple-http-outputspan-writer-pattern.md` (2026-04-02 cluster — the ownership-transfer middleware model and `consuming sending` streaming surfaces are the design language for the *native* swift-http arc, not required of the L4 membrane)
- Live-source verification, this session: swift-ietf RFC family enumeration; `swift-rfc-9110` build attempt on `TOOLCHAINS=org.swift.632202605101a` (resolution-blocked by the torn ownership-shared main — reproduction recorded above); swift-postgresql-standard Package.swift trait gating + Foundation grep; swift-server target/dep/type inventory; foundations stub sweep
