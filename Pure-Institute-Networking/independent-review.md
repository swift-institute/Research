# Independent review and disposition

## Review boundary and method

Two fresh read-only reviewers examined the complete research set on 2026-07-16. Neither reviewer edited files.

- The evidence reviewer independently reran the frozen RepoTraffic import census, pin/checkout comparisons, manifest-path classification, Docker/Procfile controls, scheduled-job/cache census, and current-state drift checks.
- The architecture reviewer read every report and tested the proposal against `[PLAT-ARCH-008h]`, `[MOD-014]`, the charter's fixed removals, product-closure proof, static/security parity, TLS/X.509 trust, PostgreSQL SCRAM, server/client/DNS scope, canary topology, and estimate arithmetic.
- The primary agent dispositioned findings and reran focused controls. Principal review remains the acceptance oracle; reviewer closure is not a `DONE` claim.

The reports were uncommitted candidates while review occurred. Their later Research commit does not turn observed RepoTraffic or package state into authored evidence.

## Evidence classes

**Committed evidence** is reproducible from the frozen RepoTraffic launch commit `0a2489838e515405562c417a10647691442f9d20`, its captured lockfile SHA-256 `865db384...`, the exact package/check-out SHAs in `provenance-and-scope.md:17-57`, and the later owner commits `c4814e35...`, `e9aaa45d...`, and `51e70c17...` recorded at `provenance-and-scope.md:19-22`.

**Observed state** includes the ignored post-baseline lock hash `49618b75...` last seen at `e9aaa45d...` and its later absence at the final `51e70c17...` sample. It is explicitly not presented as deployed closure or as evidence authored by this task (`provenance-and-scope.md:60-64`). Existing unrelated Research changes and RepoTraffic owner work remain excluded.

## Finding dispositions

| Severity | Finding | Disposition |
|---|---|---|
| P1 | Static middleware behavior was understated by a direct-import-only reading. | Added streamed files, MIME, confinement, ETag/304, Last-Modified, ranges/206, CORS, Host/canonicalization, forwarded-header trust, HTTPS redirect, HSTS, error, and timing parity to the inventory and deterministic/replay gates (`README.md:20`; `validation-and-benchmark-program.md:27-29,151-157`). |
| P1 | SwiftPM's resolved graph was being treated as if it proved a selected production product. | Demoted `show-dependencies` to a resolved superset. Wave 0 now delivers a fail-closed, versioned `Scripts/selected-product-closure` with exact commands for both executables, canonical edge/revision/reachability JSON, fixture validation, and independent build/link/container/SBOM reconciliation (`replacement-matrix.md:51-66`; `migration-waves.md:15-19`). |
| P1 | “Zero forbidden” alternated between production-path purity and whole-ecosystem resolution. | Chose release purity: no forbidden identity in either shipped product or the release manifest/lock, container, and SBOM. Differential oracles move to a separate comparison root and lock (`README.md:26,48`; `validation-and-benchmark-program.md:184`). |
| P1 | TLS planning lacked a complete provider-identity and trust-store decision. | Added the Apple/Institute SwiftPM identity collision, non-coexisting lane options, explicit system-root provider, certificate signature/path/hostname ownership, and Linux/macOS handshake gates (`target-package-and-layer-architecture.md:229-233`; `networking-and-concurrency-decision.md:161`). |
| P1 | PostgreSQL authentication could accidentally hide cryptography under TLS. | Added independent secure-random, SHA-256, HMAC, PBKDF2, constant-time comparison witnesses, iteration bounds, server-proof validation, vectors, and secret-lifetime/zeroization gates behind `swift-postgresql-crypto` (`postgresql-decision.md:72-80`). |
| P1 | A per-dyno/percentage canary was not executable under one Heroku `$PORT`. | Defaulted to a separate canary app/hostname; percentage cohorts require an explicit upstream splitter, otherwise use a boot-selected whole-release canary with immediate release rollback (`migration-waves.md:19-23`; `validation-and-benchmark-program.md:154`). |
| P2 | The first import query undercounted Vapor because one live import has a trailing comment. | Corrected the frozen result to 48 live Vapor imports plus one commented import, retained the 47-count error as audit history, and expanded release-scanner syntax/positive controls (`provenance-and-scope.md:96-116`; `replacement-matrix.md:59-66`). |
| P2 | “48 Vapor imports” obscured two executable paths. | Partitioned the non-overlapping count into 31 app-directory imports, one shared app-selected import, and 16 marketing-executable imports; both executables are explicit closure/build gates (`README.md:13`; `provenance-and-scope.md:128-136`). |
| P2 | The transitive table omitted supporting closure and some NIO bridge consumers. | Added AsyncKit plus logging/metrics/tracing/context, crypto/X.509/ASN.1, algorithms/atomics/collections/configuration and corrected NIOConcurrencyHelpers/NIOTLS consumers (`current-dependency-and-capability-inventory.md:62-77,100`). |
| P2 | The initial target graph created ambiguous L3 domain peers and nested integrations. | Classified every bracketed bridge as L4/Components, removed L4-to-L4 dependencies, left L5 as the sole multi-integration composer, and made `swift-sql-postgres` relocation explicit (`target-package-and-layer-architecture.md:40-63,162-166,217-225`). |
| P2 | HTTP client/DNS and HTML body ownership were blurred into the first server cutover. | Kept the first HTTP wave server-only, deferred the client, used system host resolution for PostgreSQL, and made `swift-html-http` depend on the runtime body owner (`target-package-and-layer-architecture.md:173-179`). |
| P2 | Current-state prose lagged concurrent RepoTraffic owner commits. | Preserved `0a248983...` as the only line-number baseline, recorded `c4814e35...`, `e9aaa45d...`, and final test-only `51e70c17...` separately, and kept all such changes outside this task's ownership (`provenance-and-scope.md:57-64`). |
| P3 | “Current lockfile” implied a live/deployed closure. | Reworded it as the frozen launch lock snapshot, reconfirmed only where actually rechecked; recorded that Docker deletes it and the final current-state sample had no lockfile (`validation-and-benchmark-program.md:9-17`; `provenance-and-scope.md:62-64`). |

## Independent pass results

- Census: **pass** — frozen 346 production Swift files and 19 tests; 48 live Vapor imports plus one commented import; one each PostgresNIO, NIOCore, and NIOPosix. The final production-source recheck after `51e70c17...` remained 48/1/1/1.
- Locked forbidden pins: **pass for the frozen lock** — all 17 reported versions/revisions matched the captured lock and local checkout/tag evidence. The ignored live lock is deliberately not claimed at `51e70c17...` because it was absent.
- Layer/cycle audit: **pass** — no proposed L4-to-L4 edge and no L3-domain-to-L3-domain edge; L5 owns composition.
- Closure design: **pass after disposition** — both products, `_NIOFileSystem`, bridge modules, attributed/access-level/scoped imports, conditions, traits, tests, link inputs, symbols, container, and SBOM now have explicit proof roles.
- Static/security parity: **pass as a plan** — testable HTTP static/middleware, TLS identity/trust, and PostgreSQL SCRAM requirements are present. This does not claim those implementations exist.
- Canary topology: **pass as an executable plan** — every route names a realizable topology and rollback.
- Estimate arithmetic: **pass** — wave minima/maxima sum to 66-118; cross-cutting 8-14 yields 74-132 person-weeks. A fully native crypto/X.509 program and external-review remediation remain outside the base envelope (`migration-waves.md:175`).

After the final dispositions, the architecture reviewer reported no remaining P1 or P2 finding and confirmed that the final provenance-only update introduced no material architecture contradiction. No package builds, product tests, benchmarks, or canaries were run: this charter authorizes an audit and plan, not implementation, and the reports define those future gates rather than pretending they have passed.
