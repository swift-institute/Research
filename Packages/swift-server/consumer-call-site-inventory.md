# Consumer Call-Site Inventory — `swift-server` v0

Working design record. The required public surface of `swift-server` is derived
**call-site-first** from the first consumer, `coenttb/repotraffic-com-server`
(`Sources/`), swept 2026-07-06. This document catalogs what the app *actually*
calls against the external server engines (Vapor, PostgresNIO, vapor/queues,
AsyncHTTPClient) and the `swift-records` execution shapes. It is the contract the
membrane must satisfy — not Boiler's shape (Boiler is deliberately out of scope).

The consumer reaches the engines through several seams: `Boiler.execute`
(bootstrap), `Vapor.Application.configure` (lifecycle/config), `Response` /
`AsyncResponseEncodable` (HTTP responses), `@Dependency(\.defaultDatabase)` +
`swift-records` (`Records`) statement execution, and `app.queues` (jobs).

## 1. Bootstrap & lifecycle (→ product **Server**)

Observed (`com_repotraffic_app/Application.swift`, `Vapor.Application.configure.swift`):

| Call site | Capability required |
|-----------|---------------------|
| `Boiler.execute(router:use:configure:)` | Application entry point: take a router, a `(Route) async throws -> Response` handler, and a `configure(app)` hook; run the server. |
| `Vapor.Application.configure(_ app)` async throws | A configure hook run once at boot, before serving. |
| `app.routes.defaultMaxBodySize = "10mb"` | Configure max request body size. |
| `app.directory.publicDirectory` | Resolve the public/static asset directory. |
| `prepareDependencies { … }` (pointfree) | App wires `@Dependency` values at boot — orthogonal to the membrane; the membrane must not fight it. |
| `PostgresClient.Configuration.fromEnvironment()`, `.tls`, `.options.*` | DB configuration from environment (see §2). |

Derived surface: `Server.Application` (lifecycle: configure → run → graceful
shutdown), `Server.Configuration` (host/port/max-body-size/environment),
a route-decode seam + a `(Route) -> Server.Response` respond seam.

## 2. Environment / configuration access (→ **Server**)

Observed (`Dependencies/EnvVars.swift`, `EnvironmentVariables.swift`, `Router.swift`):

| Call site | Capability |
|-----------|------------|
| `envVars["DATABASE_HOST"]`, `self["ENV"]` | String subscript over environment. |
| `self.int("DATABASE_PORT")` | Int accessor. |
| `envVars.url("APP_BASE_URL")` | URL accessor (Foundation `URL`). |
| `envVars.redisUrl` | Domain-specific derived accessors (app extends the base type). |
| `Vapor.Environment.detect()` + `--env` flag | Detect environment name (development/production). |

Derived surface: `Server.Environment` — subscript + `string`/`int`/`bool`/`url`
accessors, `.detect()` from the process environment, and value-init for tests.
The app extends the base type with its own typed accessors, so the membrane type
must be open to extension and carry an untyped `subscript`.

## 3. Route dispatch & request/response bridging (→ **Server**)

Observed (`Route.response.swift`, `Webhook/*`, `Setup/Setup.response.swift`,
`Repositories/*.response.swift`):

| Call site | Capability |
|-----------|------------|
| `func response(route:) async throws -> any AsyncResponseEncodable` | Handler: decoded route value → response. The generic seam. |
| `@Dependency(\.request) var request` | Access the current request inside a handler. |
| `request.redirect(for:)` / `request.redirect(to:)` | Redirect responses (by app route or by URL/string). |
| `Response(status:.ok, headers:…, body:.init(string:…))` | Build a response from status + headers + string/bytes body. |
| `Response(status:.notFound, body:.init(string:…))` | Status-only / text responses. |
| `Response(status:.noContent)` | Bare status response. |
| `Response(status:.seeOther, headers:["Location":…])` | Redirect via explicit header. |
| `Response.json(success:data:)` / `Response.json(success:message:)` | JSON envelope responses. |
| `Vapor.Response { HTMLDocument … } head: { … }` | HTML-document response (body rendered by swift-html; membrane only needs a bytes+content-type seam). |
| Status values used: `.ok`(11) `.internalServerError`(9) `.notFound`(6) `.badRequest`(4) `.unauthorized`(3) `.noContent`(1) `.seeOther` `.found` | Status vocabulary. |
| `catch let error as AbortError where error.status == .unauthorized` | Errors carry an HTTP status; `.unauthorized` special-cased to a login redirect. |
| `throw Abort(.unauthorized)` / `Abort.requestUnavailable` | Throw an HTTP-status error. |

Derived surface: `Server.Request` (typed context: method, path, query, headers,
body bytes), `Server.Response` (status + headers + body; builders `.html`,
`.json`, `.text`, `.redirect(to:)`, `.status`), `Server.Status` (status vocabulary
with `.ok`/`.notFound`/`.badRequest`/`.unauthorized`/`.noContent`/`.seeOther`/
`.found`/`.internalServerError`), `Server.Method`, `Server.Error` (typed, carries a
status), and a `Server.Middleware` hook.

## 4. Database execution (→ product **Server PostgreSQL**)

Observed (`Vapor.Application.configure.swift`, `RepositoriesLive/*`, `Jobs/CacheRefreshJob.swift`,
27 `*Live.swift` files, `Records.Database.Migrator.repotraffic.swift`). The app
executes `swift-records` statements built on the Structured Queries DSL:

| Call site | Capability |
|-----------|------------|
| `@Dependency(\.defaultDatabase) var db` | A shared database handle. |
| `try await db.read { db in … }` | Read transaction / connection scope. |
| `try await db.write { db in … }` | Write transaction / connection scope. |
| `.fetchOne(db)` / `.fetchAll(db)` | Fetch decoded rows (one / many). |
| `.execute(db)` | Execute a statement, discard rows. |
| `db.execute("CREATE TABLE …")` | Execute raw SQL (migrations). |
| `Record.insert{…}.returning{…}.fetchOne(db)!` | INSERT … RETURNING → decoded row. |
| `Record.where{…}.update{…}.execute(db)` / `.delete().execute(db)` | UPDATE / DELETE execution. |
| `Record.all.join(…).where{…}.select{…}.order{…}.fetchAll(db)` | SELECT with joins → decoded rows. |
| `any Records.Database.Reader` / `any Records.Database.Writer` | Reader/Writer role types passed around. |
| `Records.Database.Migrator()`, `.registerMigration("name"){ db in … }`, `.migrate(db)` | Ordered named migrations + a runner. |
| `Database.pool(configuration:minConnections:maxConnections:)` | Build a pooled database from `PostgresClient.Configuration`. |

`db.withRollback` was **not** found in the consumer today; it is a documented
`swift-records` test-support affordance the mission asks the membrane to mirror.

Derived surface: `Server.PostgreSQL.Executor` (`execute` / `fetchAll` / `fetchOne`
/ `transaction` / `withRollback`) over `PostgresNIO`, plus
`Server.PostgreSQL.Migration` / `Server.PostgreSQL.Migrator` (ordered named
migrations, applied-migrations table), matching the `Records.Database.Migrator`
shape. The Structured-Queries DSL coupling is behind a protocol seam
(`Server.PostgreSQL.Statement` producing `(sql, [Server.PostgreSQL.Value])`) — see
the CONTINGENCY note below.

## 5. Background jobs (→ product **Server Jobs**)

Observed (`Vapor.Application.configure.swift` `configureQueues`/`schedulePollingJob`,
`Jobs/GitHubPollingJob.swift`, `CacheRefreshJob.swift`, `AutoTrackAllReposJob.swift`):

| Call site | Capability |
|-----------|------------|
| `app.queues.use(.redis(url:))` | Redis driver selection. |
| `app.queues.startInProcessJobs()` / `startScheduledJobs()` | In-process / dev execution of workers. |
| `app.queues.add(Job())` | Register an on-demand queued job. |
| `app.queues.schedule(Job()).hourly().at(0)` / `.at(5)` | Register a scheduled job with a cron-ish schedule. |
| `struct … : AsyncJob { struct Payload: Codable; func dequeue(_ ctx, _ payload) }` | On-demand job with a Codable payload (AutoTrackAllReposJob, GitHubPollingJob). |
| `struct … : AsyncScheduledJob { func run(context:) }` | Scheduled job (GitHubPollingJob, CacheRefreshJob). |

The app's three jobs: **hourly scheduled polling** (`GitHubPollingJob`, scheduled
+ manual), **scheduled cache refresh** (`CacheRefreshJob`, hourly at :05),
**on-demand queued bulk work** (`AutoTrackAllReposJob`, dispatched with a payload).

Derived surface: `Server.Jobs.Job` (Codable payload, on-demand), `Server.Jobs.Scheduled`
(+ `Server.Jobs.Schedule`: `.hourly(minute:)`/`.daily(at:)`), `Server.Jobs.Registry`
(register + schedule), `Server.Jobs.Driver` (`.redis(url:)` / `.inProcess`), and
`Server.Application.register(_ registry:)` install hook onto the running app.

## 6. Outbound HTTP (→ product **Server HTTP Client**)

The consumer reaches vendor APIs (GitHub, Stripe, Mailgun) through their own typed
client packages; those `*Live` targets are the future migration target named by the
mission ("enough for vendor-API Live targets to migrate onto later"). No direct
`AsyncHTTPClient` call sites exist in the app itself. The surface is therefore
derived from the mission brief, not the app: `Server.HTTP.Client`
(`send`/`get`/`post`, JSON body + JSON decode convenience), `Server.HTTP.Request`,
`Server.HTTP.Response`, `Server.HTTP.Error` (typed) over `swift-server/async-http-client`.

## The 12 capabilities the app actually needs

1. Bootstrap: router + `(Route) -> Response` handler + `configure(app)` hook → run.
2. A once-at-boot async configure hook; set max body size; resolve public dir.
3. Environment access: string/int/bool/url + `.detect()`, open to extension.
4. Handler shape: decoded route value → `any Response`.
5. Response building: status + headers + string/bytes body.
6. Response conveniences: `.json`, HTML document body, `.redirect(to:)`/by-route, bare status.
7. A status vocabulary carried by both responses and thrown errors.
8. Shared DB handle with `read {}` / `write {}` transaction scopes.
9. Statement execution: `execute` / `fetchOne` / `fetchAll` (+ INSERT…RETURNING).
10. Migrations: ordered named migrations + a `migrate(db)` runner (raw SQL `execute`).
11. Jobs: register on-demand (Codable payload) + scheduled (hourly/at-minute) jobs; Redis + in-process drivers.
12. Outbound HTTP client with typed errors + JSON convenience (for Live targets to adopt).

## CONTINGENCY (2026-07-06): the Structured Queries DSL is unresolvable today

`swift-postgresql-standard` — the package the mission names for the executor's DSL
— **fails SwiftPM resolution** on the 6.3.2 toolchain today. Root cause (traced):

```
swift-postgresql-standard
  └─ (dep) swift-tests                         # test-support product dependency
       └─ swift-kernel → … → swift-windows-standard
            └─ Package.swift declares  name: "swift-windows-32"
               but a target depends on package "swift-windows-32" that no longer
               resolves ⇒ "unknown package 'swift-windows-32'"
```

This is a torn rename in the `swift-microsoft/swift-windows-standard` main (the
"parallel arc has torn some published mains" hazard). Because SwiftPM loads the
*whole* manifest graph eagerly, depending on `swift-postgresql-standard` would make
`swift-server` itself unresolvable.

Mitigation, per the mission's fallback clause: the DSL coupling is quarantined
behind a small protocol seam — `Server.PostgreSQL.Statement` yields
`(sql: String, bindings: [Server.PostgreSQL.Value])`, and the executor runs that
over PostgresNIO with **no** dependency on `swift-postgresql-standard`. The pure
DSL package `swift-structured-queries-primitives` (which `swift-postgresql-standard`
re-exports, and whose `Statement` protocol the app's statements conform to) has a
clean graph and MAY be bridged as a thin, removable adapter file
(`Server.PostgreSQL.Statement+StructuredQueries.swift`) — included only if it
resolves cleanly alongside the engines. The seam builds regardless.
