# Provenance and scope

## Authority and boundary

This record answers the immutable `pure-institute-networking` generation-1 charter as reset by the Principal to direct, audit-only operation. The work is research and architecture only. Existing repositories, manifests, lockfiles, source, tests, scripts, skills, product configuration, and deployments remained read-only. New files are confined to:

`/Users/coen/Developer/swift-institute/Research/Pure-Institute-Networking/`

The Research repository already contained unrelated modified and untracked work. It was not staged, cleaned, amended, reset, stashed, or edited. The task-specific charter requires separately reviewable files in the directory above; therefore the general research-index workflow does not authorize editing the pre-existing root `_index.json`.

No peer charter, channel, receipt, or runtime data was read after the Principal's audit-only reset. No deployment, push, tag, release, dependency update, generated-lockfile change, or product mutation was performed.

## Evidence snapshot

Local source and manifests are the primary ecosystem evidence. Counts are snapshots, not claims that packages build or pass tests.

| Repository/package | HEAD inspected |
|---|---|
| RepoTraffic server launch baseline | `0a2489838e515405562c417a10647691442f9d20` |
| RepoTraffic manifest-census hardening observed after baseline | `c4814e35c4d13ee50a4fa346ba4776d066f8f4d4` |
| RepoTraffic stale-target-edge pruning observed after baseline | `e9aaa45d3e38ebcafaa3af1e732f8a0f2f538c8e` |
| RepoTraffic WaitingList test-suite restoration observed after baseline | `51e70c17f51c5747e1084f2408e8f3afa094c3ae` |
| Boiler | `683a53d7d98cd8e315b91019d6107ccdc545c57d` |
| `swift-html-vapor` | `da90f1e496d4fbb9a0b723db086a0da53b25dacc` |
| `swift-server-foundation` | `781565c82111579cf2748af82e0c08b400095019` |
| `swift-server-foundation-vapor` | `7fd69ede4a9a5dc172926c30e840e67766521f59` |
| `swift-url-routing-vapor` | `ceddd66544264af384b5bc1dc328ebc8130c8cf4` |
| `swift-server` | `1b3767fcf5682cf7ea3b2d8a9362d42e6217536f` |
| `swift-io-primitives` | `356ac992ea3278bd93dc157d75e584735e80b582` |
| `swift-async-primitives` | `6b6fff1289ff86c0a00398a508103372f44ad92c` |
| `swift-executor-primitives` | `eb8d6abc62f7ce1808b879a83d24ce0531512229` |
| `swift-executors` | `eab2ffea2a7ab0d69fba069225157bb97e1bdeb7` |
| `swift-threads` | `fb4e2a68be0422f1fd211b040088a1d09abdbefe` |
| `swift-kernel` | `f5be0f6bdf8d0de9e4d9054984a0b173585ef96f` |
| `swift-sockets` | `4cfb4eabe32c21e1692fab4b3d29db2f53cf4b25` |
| `swift-io` | `bcfe12adf938bd0fe10586a5de7de68c02c3c12e` |
| `swift-sockets-standard` | `dc284a9de217ba67f009f12ba7b7cf25f02eef02` |
| `swift-ip-address` | `e455261306ac1b9111b1785a63b66867048a5f7f` |
| `swift-http-standard` | `efffa2941e852f5638b0acb49bbe4e30f247ae7c` |
| RFC 9110 | `7f7907752612cead782560b7fdcca92677618fcb` |
| RFC 9111 | `284392d91ddc35b3d4e8c5cf52afd38964dd727a` |
| RFC 9112 | `3fb45a017da3ff4fc85e19eec83fb5e3ff118aad` |
| RFC 8446 | `808c493673e3e559e555555ec583e43d97184354` |
| RFC 6066 | `203a7b299e355964d3dbbd1c1dc98d56c9feca21` |
| RFC 5280 | `656a764f36eb85ca0d94e8cf304debc38657a102` |
| RFC 1035 | `413d8a828b0b1bd7418fadd827dcb71d8e328147` |
| `swift-url-routing` | `3b5d55451524dff4846746947c8eea7e84e5c67a` |
| `swift-postgresql-standard` | `c43973036f6446545d56503467753af877b8f77e` |
| `swift-records` | `679c17f2175f079a48dfd7129a81b63e3cff5421` |
| `swift-sql` | `f491dd3c4018f597bc20777e1cd42be689284018` |
| `swift-sql-postgres` | `83cb9b57dc681239a86e701bb5775e012efb646f` |
| `swift-sql-migrations` | `89e30d452f5cd038e5ab7e27dabb85511ff50f31` |
| `swift-sql-dependencies` | `482684e304318c24300ff5779f9869d65955ef1b` |
| `swift-scheduler` | `f3166dfa4f4b946e0c9a3a2d690fce819868248b` |
| `swift-bounded-cache` | `25825d9918de37ac5c2228e2e3f34bda45d2aea2` |
| `swift-redis` placeholder | `efe4d2d8681c9e518cadeaf779b848662fd846f1` |

The exact launch lockfile snapshot is `Package.resolved` SHA-256 `865db384ee9170773ab2b3e4efaee3f8d45d6b2d2243d7ef612ae3725fb03cc7`; `Package.swift` was `327b8783dce00ed43b2e754e97a48d3fb40175d632f5f905c9df654df1c981c3` before and after the initial inspection. Line-number citations use this frozen source/manifest snapshot.

Revalidation later in the same audit detected concurrent, out-of-scope RepoTraffic hardening. The worktree changed more than once. Its owner committed the direct-import census as `c4814e35c4d13ee50a4fa346ba4776d066f8f4d4`, then pruned proven-stale target-dependency rows as `e9aaa45d3e38ebcafaa3af1e732f8a0f2f538c8e`. At the latter committed recheck, hashes were `f01890c94a6be69d14b029cfda21b056895a346618a02e2c533ac8c1afa3ffa4` for `Package.swift` and `49618b75d49ab41f47911936644f2c796c7a43a7c3f1e5cd47018d5aef1dc678` for the still-ignored `Package.resolved`. The census hardening added explicit root/product declarations for SwiftNIO cache imports and the direct PostgresNIO import; it also gate-verified that PostgresNIO is load-bearing defining-module visibility for `.options`/`.tls` on Records' `Database.Configuration = PostgresClient.Configuration` alias. The pruning reduced frozen-launch `Server PostgreSQL` target rows from 15 to one, `PostgreSQL Standard` from 15 to two, `ServerFoundationVapor` from seven to six, and `Server` from fourteen to two. A repeated import census remained 48/1/1/1, and a repeated lock query returned the same versions and revisions for every forbidden identity; the core closure did not shrink.

During final review that test-only owner edit was committed as `51e70c17f51c5747e1084f2408e8f3afa094c3ae` (`test(waitinglist): restore the live DB-integration suite app-locally (H6, RT-029)`). Its committed `Package.swift` SHA-256 is `bd9190d333c82cbad7599b70bd0a7a8e9684d5f74804104103729f18c015ed67`. The commit re-enabled `WaitingListLive Tests`, added its direct test dependencies, and changed two test files; it did not change production source. A final controlled production import census remained 48/1/1/1. At that last sample the ignored `Package.resolved` file was absent, so `49618b75...` remains the last observed post-baseline lock hash rather than a claim about `51e70c17...`; the launch lock evidence remains the frozen `865db384...` snapshot. These changes were observed, not authored or staged here. Every RepoTraffic source/manifest line citation in the reports remains pinned to `0a248983...`, never symbolic `HEAD`; Institute/checkout citations use their separately recorded SHAs.

RepoTraffic `.gitignore:5` ignores `Package.resolved`; `git check-ignore -v Package.resolved` confirms it. Consequently, the initial scoped `git status` control could not reveal lockfile drift. Hashes and pin queries remain valid evidence, but Wave 0 must remove that ignore rule and commit the lockfile before status/diff controls become sufficient.

## Edge classifications

The reports use these terms consistently:

- **Source-live**: an uncommented production source import or symbol use.
- **Root-product edge**: a product explicitly attached to a RepoTraffic production target.
- **Transitive production-product edge**: a selected product target depends on the next product/target. It may be compiled even when RepoTraffic names none of its APIs.
- **Platform-conditional production edge**: selected by the product graph but compiled only on named platforms.
- **Resolution-only edge**: the package is present because a selected package manifest declares it, but no selected production target reaches its product under the proven path.
- **Test/example/benchmark edge**: reachable only from a non-production target.
- **Stale**: proven unreachable from all selected targets, not merely absent from source imports. No pin is called stale without that proof.

This distinction matters for AsyncHTTPClient: RepoTraffic has zero direct imports and zero `HTTPClient` tokens, but Vapor's production target depends on AsyncHTTPClient. The pin is therefore not stale in the current selected Vapor path.

## Reproducible commands

All aggregate counts in this research use the commands below or a command printed beside the table that it supports. Commands were run from `/Users/coen/Developer/repotraffic/repotraffic-com-server` unless an absolute path says otherwise.

### Snapshot and mutation controls

```sh
git status --short -- Package.swift Package.resolved Sources Tests
git rev-parse HEAD
git log -1 --format='%cI%x09%s'
shasum -a 256 Package.swift Package.resolved
```

The scoped status command returned no output at the launch snapshot. It does not claim the whole repository was clean, and the later concurrent drift is recorded above.

### Production/test source counts

```sh
rg --files Sources -g '*.swift' | wc -l
rg --files Tests -g '*.swift' | wc -l
```

Results: 346 production Swift files and 19 test Swift files.

### Controlled import census

```sh
rg -n --glob '*.swift' \
  '^[[:space:]]*(@preconcurrency[[:space:]]+)?import[[:space:]]+(Vapor|ServerFoundationVapor|HTML_Vapor|PostgresNIO|PostgreSQL_Standard|NIOCore|NIOPosix|AsyncHTTPClient|Queues|QueuesRedisDriver|RediStack)([[:space:]]*(//.*)?)$' \
  Sources
```

The attributed-import alternative is a positive control: `RediStack` is written as `@preconcurrency import RediStack`, which a strict `^import` search would falsely report as zero. Anchoring at optional whitespace excludes the commented `//import Vapor` line at `Sources/com_repotraffic_app/Repositories/Repository.View.response.swift:12`; permitting a trailing line comment includes the live `import Vapor // W-3 STUB ...` in `Sources/com_repotraffic_app/Application.swift:41`.

The corrected controlled command produced 48 live Vapor imports plus that one commented line. An interim version ended immediately after the module name and incorrectly reported 47 by excluding `Application.swift:41`; this report retains the correction instead of concealing it. The launch snapshot also contained one live `PostgresNIO`, one `NIOCore`, and one `NIOPosix` import.

This census regex is historical and matches the import forms observed in RepoTraffic. It is not the final forbidden scanner: the release scanner also recognizes arbitrary import attributes, access-level imports such as `public import`, and scoped imports, with a positive fixture for each syntax family.

After concurrent source drift, the frozen committed tree was rechecked without changing the worktree:

```sh
git grep -n -E \
  '^[[:space:]]*(@preconcurrency[[:space:]]+)?import[[:space:]]+(Vapor|PostgresNIO|NIOCore|NIOPosix)([[:space:]]|$)' \
  0a2489838e515405562c417a10647691442f9d20 -- Sources
```

Counting that output reproduced `Vapor=48`, `PostgresNIO=1`, `NIOCore=1`, and `NIOPosix=1`. A broad `git grep 'import Vapor'` produced 49 because it also includes the commented line.

The 48 live Vapor imports were partitioned without overlapping path prefixes:

```sh
git grep -n -E '^[[:space:]]*import[[:space:]]+Vapor([[:space:]]|$)' \
  0a2489838e515405562c417a10647691442f9d20 -- Sources/com_repotraffic_app | wc -l
git grep -n -E '^[[:space:]]*import[[:space:]]+Vapor([[:space:]]|$)' \
  0a2489838e515405562c417a10647691442f9d20 -- Sources/WaitingListLive | wc -l
git grep -n -E '^[[:space:]]*import[[:space:]]+Vapor([[:space:]]|$)' \
  0a2489838e515405562c417a10647691442f9d20 -- Sources/com_repotraffic | wc -l
```

Results were 31 app-directory, one shared app-selected WaitingListLive, and 16 marketing-executable imports: 32 app-path plus 16 marketing-only.

### Negative controls

```sh
rg -n --glob '*.swift' '\bHTTPClient\b' Sources Tests
rg -n --glob '*.swift' '^[[:space:]]*(@preconcurrency[[:space:]]+)?import[[:space:]]+AsyncHTTPClient$' Sources Tests
rg -n -i '\bFluent\b|fluent-(postgres|sqlite|mysql)' Package.swift Package.resolved Sources Tests
rg -n -i '\b(websocket|upgrade|http2|http/2|gzip|deflate|compression|multipart|body\.stream|chunked)\b' Sources Tests Package.swift Procfile Dockerfile
```

The first two searches returned zero while the lockfile query below returned a positive AsyncHTTPClient pin. The Fluent search returned zero in the root scope. The protocol-feature search proves only that RepoTraffic source does not directly name WebSocket/HTTP2/compression/streaming APIs; it is not a runtime-capability negative. Inspection of selected Boiler/Vapor code found the counterexample: Boiler's non-nil default file middleware invokes Vapor's asynchronous file stream and supplies ETag/304, byte Range/206, Last-Modified, content type, and streamed chunks. Boiler also installs default CORS, error, and request-timing middleware plus configurable host/canonical/HTTPS policies. The capability inventory and target plan therefore treat those behaviors as active parity scope.

### Root product and package edges

```sh
rg -n '\.product\(name: "(HTML Vapor|ServerFoundation|ServerFoundationVapor|PostgreSQL Standard|Server PostgreSQL|Queues|QueuesRedisDriver|RediStack)"' Package.swift
rg -n '\.package\(url: ".*(vapor/vapor|vapor/postgres-nio|apple/swift-nio|swift-server/async-http-client|vapor/queues|vapor/queues-redis-driver|swift-server/RediStack|vapor/redis)' Package.swift
```

### Exact lock pins

```sh
jq -r '.pins[]
  | select(.identity | test("^(async-http-client|async-kit|console-kit|multipart-kit|postgres-nio|queues|queues-redis-driver|redis|redistack|routing-kit|swift-nio|swift-nio-extras|swift-nio-http2|swift-nio-ssl|swift-nio-transport-services|vapor|websocket-kit)$"; "i"))
  | [.identity, (.state.version // ""), .state.revision]
  | @tsv' Package.resolved

jq -r '.pins[]
  | select(.identity | test("^(swift-algorithms|swift-asn1|swift-atomics|swift-certificates|swift-collections|swift-configuration|swift-crypto|swift-distributed-tracing|swift-log|swift-metrics|swift-service-context|swift-service-lifecycle)$"; "i"))
  | [.identity, (.state.version // ""), .state.revision]
  | @tsv' Package.resolved
```

### Institute package counts

For paths without spaces:

```sh
rg --files "$package/Sources" -g '*.swift' | wc -l
rg --files "$package/Sources" -g '*.swift' -0 | xargs -0 wc -l | tail -1
rg --files "$package/Tests" -g '*.swift' | wc -l
rg --files "$package/Tests" -g '*.swift' -0 | xargs -0 wc -l | tail -1
```

`-0` is required because target directories such as `Sockets Tests` contain spaces. Counts describe checked-in files/lines only.

Empty-placeholder control:

```sh
test -f "$package/Package.swift"
find "$package/Sources" -type f -name '*.swift' 2>/dev/null | wc -l
```

### Socket/TLS gap controls

```sh
rg -n 'static func (events|completions)|\.events\(|\.completions\(' \
  /Users/coen/Developer/swift-foundations/swift-sockets/Sources -g '*.swift'

rg -n -i '\b(AEAD|seal|open|encrypt|decrypt|verification|trust|root|hostname|TLSInnerPlaintext|TLSCiphertext)\b' \
  '/Users/coen/Developer/swift-ietf/swift-rfc-8446/Sources/RFC 8446' -g '*.swift'
```

The socket search returned no production event/completion factory. TLS hits were individually inspected: they are codecs/formulas or names, not a live session/record-protection/trust engine.

### Dependency graph attempt and fallback

`swift package show-dependencies --format json --output-path /tmp/repotraffic-dependencies.json` was attempted read-only. SwiftPM did not produce the file after 5 minutes 42 seconds, so the process was interrupted. `Package.swift` and `Package.resolved` hashes remained unchanged. Even if it had completed, the command's own help describes a resolved dependency graph and offers no product selector; it cannot distinguish `com_repotraffic_app` from test/resolution-only targets. The graph in this research is instead proven from frozen root product selections and exact resolved checkout manifests. The attempted command is not counted as graph evidence. Future release proof keeps it only as a resolved superset and adds a target-aware manifest traversal plus actual product build/link/container evidence.

## Primary external sources

Changing protocol and platform facts were checked against primary sources:

- [RFC 9112 — HTTP/1.1](https://www.rfc-editor.org/info/rfc9112/)
- [RFC 9931 — optimistic HTTP/1.1 protocol transitions](https://www.rfc-editor.org/info/rfc9931/), published in 2026 and updating RFC 9112
- [RFC 8446 — TLS 1.3](https://www.rfc-editor.org/info/rfc8446/)
- [RFC 8446 errata](https://www.rfc-editor.org/errata_search.php?rfc=8446)
- [PostgreSQL 18 frontend/backend protocol overview](https://www.postgresql.org/docs/current/protocol-overview.html)
- [PostgreSQL message flow](https://www.postgresql.org/docs/current/protocol-flow.html)
- [PostgreSQL message formats](https://www.postgresql.org/docs/current/protocol-message-formats.html)
- [PostgreSQL SASL authentication](https://www.postgresql.org/docs/current/sasl-authentication.html)
- [PostgreSQL password authentication](https://www.postgresql.org/docs/current/auth-password.html)
- [PostgreSQL SSL support](https://www.postgresql.org/docs/current/libpq-ssl.html)
- [Linux `io_uring_enter(2)`](https://man7.org/linux/man-pages/man2/io_uring_enter.2.html)
- [Microsoft I/O completion ports](https://learn.microsoft.com/en-us/windows/win32/fileio/i-o-completion-ports)
- [Heroku HTTP routing](https://devcenter.heroku.com/articles/http-routing), last updated 2026-06-19
- [Heroku dyno startup behavior](https://devcenter.heroku.com/articles/dyno-startup-behavior)

Third-party package implementations at the locked SHAs are comparison evidence and differential oracles, not architectural authority.
