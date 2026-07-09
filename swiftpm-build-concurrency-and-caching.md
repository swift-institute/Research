# SwiftPM Build Concurrency and Caching

<!--
---
version: 1.0.0
last_updated: 2026-07-09
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

**Trigger**: The overnight orchestration arcs (lint remediation, readiness gates) run
`swift build` / `swift test` verification gates for hundreds of packages on one machine,
under a standing policy of ≤2 concurrent SwiftPM invocations machine-wide plus
[PKG-BUILD-009] (no parallel builds). Two nights of observation produced symptoms the
policy does not explain: cold resolves of ~300-pin graphs taking 20–60+ minutes while
near-silent; per-package `.build` directories that appear to re-fetch everything with
nothing shared across siblings; machine crawl at 4 concurrent builds; one gate dead with
`BUILD_EXIT=143` and no attribution; and process-counting via `grep swift-build` that
undercounts test-phase work.

**Environment** [Verified: 2026-07-09, `sysctl`/`system_profiler` on the target machine]:
Apple M3 MacBook Air, 8 cores (4 performance + 4 efficiency), 24 GB RAM. Toolchain:
`TOOLCHAINS=org.swift.632202605101a` → "Apple Swift version 6.3.2 (swift-6.3.2-RELEASE)",
"Swift Package Manager - Swift 6.3.2". Ecosystem: ~400 per-repo SwiftPM packages
(423 entries in `~/Library/org.swift.swiftpm/configuration/mirrors.json`, each mapping a
GitHub URL to a local clone directory), dependencies declared as
`.package(url:, branch: "main")`, graphs up to ~300 pins, 330 `.build` directories on
disk across the three org directories. Multiple concurrent Claude Code agent sessions
drive the gates; interactive tool shells die at a 10-minute cap.

**Constraints**: No `swift build` / `swift test` / `swift package resolve` was run for
this research (build slots were reserved by the overnight arc); all dynamic claims are
therefore either (a) verified against primary sources — the `swiftlang/swift-package-manager`
codebase at `release/6.3` @ `5f6969f5` and tag `swift-6.3.2-RELEASE`, `swift-llbuild`,
`swift-driver`, `swift-testing`, swift-tools-support-core at `release/6.3` — plus local
read-only forensics, or (b) tagged PLAUSIBLE with an exact experiment spec in the
Residual section. Skills loaded per [RES-033]: research-process ([RES-*]),
swift-package-build ([PKG-BUILD-*]), deep-research (harness). Verification per
[RES-034]: five parallel research subagents against primary sources; nine load-bearing
source claims independently re-verified verbatim against a local `release/6.3` clone.

**Prior internal research** ([RES-019] step-0 grep): `benchmark-serial-execution.md`
(serial execution for benchmark suites — measurement isolation), 
`2026-05-07-clean-build-first-elevation.md` (stale-`.build` link failures), and
[PKG-BUILD-009]/[PKG-BUILD-011] in the swift-package-build skill. None analyzes SwiftPM's
concurrency or caching mechanics; this document is the first canonical treatment.

## Question

For ~400 interdependent branch-pinned SwiftPM packages built on one 8-core/24 GB
Apple-silicon machine by multiple concurrent agent sessions on Swift 6.3.2: what is the
actually-optimal concurrency and caching policy, and which SwiftPM mechanisms are we
failing to leverage?

## Analysis

### 1. Where the 20–60 minute cold resolve actually goes

The observed cost is a chain of four verified mechanisms. Clone I/O — the intuitive
suspect — is excluded first.

**1a. Clone I/O is negligible** [Verified: 2026-07-09, local measurement]. A
`git clone --mirror` of a local mirror takes 0.06 s and hardlinks objects (fresh clone
pack showed `nlink=206` — 206 `.build` directories share the mirror's physical pack
blocks; an existing `.build` pack showed `nlink=4`). The interrupted+resumed
swift-stripe-types resolve fetched ~165 bare repos in ~8 minutes of wall work total
(mtime histogram: ~85 repos 15:53–15:58, ~81 repos 22:10–22:12), under load average 6–10.
Fetching is minutes; the tens-of-minutes live elsewhere.

**1b. The serial revision walk is the structural bottleneck** [Verified: 2026-07-09,
release/6.3 source]. For an all-branch graph, PubGrub never actually solves versions —
branch deps become `overriddenPackages` fixed at a revision
([PubGrubDependencyResolver.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/PackageGraph/Resolution/PubGrub/PubGrubDependencyResolver.swift)
L413–421: "If there is a pin for this revision-based dependency, get the dependencies at
the pinned revision"). But the preprocessing loop `processInputs` (L375–457) consumes
revision-based constraints **one at a time** —
`while let constraint = constraints.first(where: { $0.requirement.isRevision })` — each
iteration doing an awaited container lookup and a manifest load at that revision. And in
a full solve every container lookup runs `git fetch` unconditionally:
[ContainerProvider.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/PackageGraph/Resolution/PubGrub/ContainerProvider.swift)
L86 `updateStrategy: self.skipUpdate ? .never : .always, // TODO: make this more elaborate`,
which becomes `git remote -v update -p` per repo
([GitRepository.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/SourceControl/GitRepository.swift)
L563–575). Prefetching (`--enable-prefetching`, default on) explicitly does **not**
help: "We avoid prefetching packages that are overridden" (PubGrubDependencyResolver
L218–225) — in a 100 %-branch-based graph the resolver's only parallel phase skips every
package. After the solve, checkouts are materialized in a plain sequential `for` loop
with a recursive chmod pass per package
([Workspace+Dependencies.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/Workspace/Workspace+Dependencies.swift)
`updateDependenciesCheckouts` L690–757). Net: ~300 × (fetch subprocess + `git rev-parse`
+ `git cat-file` manifest reads + manifest compile on cache miss), strictly serial, then
~300 serial checkouts. That is the 20–60 minute near-silent gate.

**1c. Manifest compilation is the per-iteration unit cost, and the cache that should
amortize it is being defeated twice** [Verified: 2026-07-09]. Every manifest cache miss
compiles `Package.swift` to an executable with `swiftc -lPackageDescription` and runs it
sandboxed
([ManifestLoader.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/PackageLoading/ManifestLoader.swift)
`evaluateManifest` L682–880; the exact compile command line is visible verbatim in
tonight's gate-url-form-coding.attempt2.log). The shared cache
(`~/Library/Caches/org.swift.swiftpm/manifests/manifest.db`, default
`--manifest-cache shared`) is keyed with no root-package component — different roots DO
share entries — but the key hashes `Environment.current.cachable`
(ManifestLoader.swift L484, L1058–1080), which is the **entire process environment minus
a small terminal denylist** (`TERM*`, `ITERM*`, `CLICOLOR`, `SSH_AUTH_SOCK`, … —
[EnvironmentKey.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/Basics/Environment/EnvironmentKey.swift)
L44–59). The gate environment carries `CLAUDE_CODE_SESSION_ID` and
`CLAUDE_CODE_BRIDGE_SESSION_ID` [Verified: 2026-07-09, `env` on this machine], which are
per-session unique and NOT in the denylist. **Every agent session therefore has its own
disjoint manifest-cache key-space**: manifests compiled by session A are cache misses
for session B even byte-identical. Second defeat: the cache is hardcoded to 100 MB with
`truncateWhenFull`
([SQLiteBackedCache.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/Basics/SQLiteBackedCache.swift)
L256–267), and on hitting the cap it executes `DELETE FROM MANIFEST_CACHE;` — **the
whole table** (L103–118) — then re-inserts one row. The live db measured 97 MB / 7,592
rows [Verified: 2026-07-09], i.e. sitting at the cap: session-forked duplicate entries
bloat it to 100 MB, truncation wipes even the current session's warm entries, and the
next gate pays ~300 manifest compiles again. This mechanism pair converts a
should-be-warm ecosystem into a permanently-cold one.

**1d. Mirrored-to-local-path deps bypass the shared repository cache — by design**
[Verified: 2026-07-09, source + local forensics]. A mirror that maps to a filesystem
path produces a `.localSourceControl` reference
([DependencyMapper.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/PackageModel/DependencyMapper.swift)
L68–80: "mapped to a path, we assume a local SCM location"), and
`RepositoryManager.fetchAndPopulateCache` skips the shared cache for local repos:
`let shouldCacheLocalPackages = Environment.current["SWIFTPM_TESTS_PACKAGECACHE"] == "1" || cacheLocalPackages`
([RepositoryManager.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/SourceControl/RepositoryManager.swift)
L314–316); `cacheLocalPackages` is init-only, documented "For testing purposes", and
`Workspace.swift` never passes it. Local confirmation: the shared cache holds 141 bare
clones, all with real GitHub origins; swift-stripe-types' `.build/repositories` holds
148, of which only 41 overlap with the cache — the ~107 institute mirrors are re-cloned
per consumer with `origin = /Users/coen/Developer/...`. This explains "nothing is shared
across sibling packages" for repositories. It is however the *cheap* part of the
problem: those per-package clones are 0.06 s hardlinked copies (1a), and checkouts are
`git clone --shared --no-checkout` from the local bare repo (GitRepository.swift L267).
The waste is subprocess churn and disk clutter, not wall-clock dominance. Enabling
`SWIFTPM_TESTS_PACKAGECACHE=1` would technically cache local repos but is an unsupported
test hook and would win ≈nothing (the mirror IS already local).

**What IS shared across packages and sessions** [Verified: 2026-07-09]: the repository
cache (remote deps only), the manifest cache (subject to 1c), and the prebuilts cache
(swift-syntax archives for macros — 101 MB observed; hardcoded to swift-syntax and
matching only `.remoteSourceControl` refs, so **inert for mirrored deps**,
[Workspace+Prebuilts.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/Workspace/Workspace+Prebuilts.swift)
L114, L167–184). **Not shared**: checkouts, build products, and the module cache —
`-module-cache-path` is `.build/<triple>/<config>/ModuleCache` per root package
([BuildPlan.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/Build/BuildPlan/BuildPlan.swift)
L40–50, overridable only by test hooks `SWIFTPM_TESTS_MODULECACHE`/`SWIFTPM_MODULECACHE_OVERRIDE`).

### 2. Per-invocation job control (`--jobs` / `-j`)

**Semantics** [Verified: 2026-07-09, tag swift-6.3.2-RELEASE]. `-j` defaults to
`ProcessInfo.processInfo.activeProcessorCount` — 8 on this machine, confirmed by the
local help text "(default: 8)" — and is documented in source as "The number of jobs for
llbuild to start (aka the number of schedulerLanes)"
([Options.swift](https://github.com/swiftlang/swift-package-manager/blob/swift-6.3.2-RELEASE/Sources/CoreCommands/Options.swift)
L529–531). It flows `workers` → llbuild `schedulerLanes`
([BuildOperation.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/Build/BuildOperation.swift)
L896); llbuild's `LaneBasedExecutionQueue` spawns exactly N lane threads, each running
one subprocess at a time
([LaneBasedExecutionQueue.cpp](https://github.com/swiftlang/swift-llbuild/blob/main/lib/Basic/LaneBasedExecutionQueue.cpp)).
So `-j N` bounds *llbuild-spawned* subprocesses to N — but not grandchildren:

- **Debug builds fan out N×N**: SwiftPM passes `-j\(workers)` to every `swiftc` driver it
  spawns ([SwiftModuleBuildDescription.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/Build/BuildDescription/SwiftModuleBuildDescription.swift)
  L512, with `-incremental -enable-batch-mode`), and each driver runs up to `-j`
  `swift-frontend` children. swift-driver's own source acknowledges this verbatim: "we
  might be creating up to $NCPU^2 worth of _memory pressure_ … NCONCUR := $NCPU *
  min($NCPU, $NTARGET). Empirically, a frontend uses about 512kb RAM per non-primary
  file and about 10mb per primary"
  ([Planning.swift](https://github.com/swiftlang/swift-driver/blob/main/Sources/SwiftDriver/Jobs/Planning.swift)
  `numberOfBatchPartitions`). For institute-sized modules (≤25 files → one batch) typical
  frontend RSS is ~100–300 MB [PLAUSIBLE, from the driver's model; experiment E3].
- **Release builds ignore `-j` inside the module**: WMO passes
  `-num-threads <activeProcessorCount>` hardcoded (SwiftModuleBuildDescription L497–499)
  — every concurrent release build assumes it owns all 8 cores.
- **No jobserver**: llbuild has no cross-invocation coordination (zero hits for
  "jobserver" in swift-llbuild); M concurrent builds with default `-j` are M
  independent schedulers each sized to the whole machine, arbitrated only by the OS.

**Why 4 concurrent default-jobs builds crawled** [mechanism VERIFIED, attribution
PLAUSIBLE]: 4 × 8 = 32 lanes plus per-driver frontend fan-out plus test runners on 8
cores / 24 GB. Upstream's own position is that moderate CPU oversubscription is benign
but memory oversubscription pages ("Oversubscribing CPU is typically no problem these
days, but oversubscribing memory can lead to paging", Planning.swift; also Jordan Rose:
SwiftPM "will try to spawn a swiftc for each target, so that can lead to … thrashing",
[forums 36613](https://forums.swift.org/t/should-j-1-be-used-for-swiftc-invocations/36613);
no global CPU allocation exists,
[forums 31802](https://forums.swift.org/t/globally-optimized-build-parallelism/31802)).

**`swift test` parallelism** [Verified: 2026-07-09]: `swift test` embeds the same
`BuildOptions`, so its build phase takes `-j` (default 8) exactly like `swift build`.
`--parallel` (default off) and `--num-workers` govern only the **XCTest run phase**
([SwiftTestCommand.swift](https://github.com/swiftlang/swift-package-manager/blob/swift-6.3.2-RELEASE/Sources/Commands/SwiftTestCommand.swift)
L154–163; `--num-workers` errors without `--parallel` and is XCTest-only). Swift Testing
suites run **parallel in-process by default regardless** — "Parallelization (on by
default)" ([EntryPoint.swift](https://github.com/swiftlang/swift-testing/blob/swift-6.3.2-RELEASE/Sources/Testing/ABI/EntryPoints/EntryPoint.swift)
L488–491), width ≈ the cooperative pool ≈ ncpu; SwiftPM's comment: "Since this option
does not affect swift-testing at this time, we can effectively ignore that it defaults
to enabling parallelization." Consequence: counting `swift-build` processes undercounts
load twice over — the honest machine-load gauge is `pgrep -x swift-frontend | wc -l`
plus live test-runner processes.

**Is "more concurrent builds, each with capped `--jobs`" better for many small gates?**
[PLAUSIBLE — mechanically derived, unbenchmarked; experiment E1]. For small packages the
ready-set rarely reaches 8 jobs (dependency chains, single link step), and each
invocation has long **serial** phases (the resolve walk of §1b, manifest compiles,
planning, linking) that leave all lanes idle; concurrent invocations overlap one gate's
serial phase with another's compile phase, and capping `-j` bounds the N² fan-out.
Caveat: `-j` also caps batch-mode parallelism inside the occasional large module
(partitions = `max(-j, ceil(files/25))`), so heavyweight builds still deserve a
dedicated default-`-j` window.

**Fetch concurrency is independent of `-j`** [Verified: 2026-07-09]: RepositoryManager
throttles git subprocesses to `max(1, 3 × Concurrency.maxOperations / 4)` — 6 on this
machine — where `maxOperations` = `SWIFTPM_MAX_CONCURRENT_OPERATIONS` env or
`activeProcessorCount`
([RepositoryManager.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/SourceControl/RepositoryManager.swift)
L82–84, [ConcurrencyHelpers.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/Basics/Concurrency/ConcurrencyHelpers.swift)
L22–27). Note this parallel pool only serves the phases that are parallel at all — the
resolved-file fast path and non-overridden prefetch — never §1b's serial walk.

### 3. Locking: what serializes, what is safe, what never happens

**Per-package workspace lock** [Verified: 2026-07-09, source + tonight's logs]. Each
invocation takes an exclusive `flock` keyed to the scratch directory. The actual lock
file lives in `$TMPDIR` (path-munged name; TSC
[Lock.swift](https://github.com/swiftlang/swift-tools-support-core/blob/release/6.3/Sources/TSCBasic/Lock.swift)
L194–235); `.build/.lock` is only a PID sidecar (observed containing `22735`). On
contention SwiftPM prints exactly the message observed four times in tonight's sibling
logs — "Another instance of SwiftPM (PID: 14024) is already running using
'/Users/coen/Developer/swift-standards/swift-pdf-standard/.build', waiting until that
process has finished execution..." — then blocks **forever** (no timeout;
[SwiftCommandState.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/CoreCommands/SwiftCommandState.swift)
L1143–1194). flock releases on process death, so stale PIDs cannot deadlock; a live
holder (including sourcekit-lsp, which takes the same lock) can (cf.
[forums 85713](https://forums.swift.org/t/swiftpm-stuck-in-unrecoverable-state/85713)).

**Shared-cache locks are concurrency-safe** [Verified: 2026-07-09]: the repository cache
takes a shared flock on the cache dir plus a per-repository exclusive flock around
clone/fetch/copy (RepositoryManager L319–341); errors degrade to "skipping cache due to
an error" and a direct fetch. The manifest db is SQLite WAL with a 1 s busy timeout;
a failed cache write is a swallowed warning, not corruption. N concurrent invocations
from different packages are safe by design; two invocations needing the same *remote*
repo serialize briefly on that repo's lock. No credible report of shared-cache
corruption under concurrency was found for 6.x — the reported failure mode is waiting,
not corruption.

**SwiftPM never kills competing instances** [Verified: 2026-07-09]: exhaustive grep of
outbound signals in `Sources/` finds only `AsyncProcess.signal` targeting **its own
children** (`kill(self.startNewProcessGroup ? -self.processID : self.processID, signal)`,
[AsyncProcess.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/Basics/Concurrency/AsyncProcess.swift)
L920–931); the lock-holder PID is read only to format the wait message. SwiftPM is
excluded as the source of the 143.

**Sharing one `--scratch-path` across different roots is anti-useful** [Verified:
2026-07-09]: the scratch dir embeds single-root state (`workspace-state.json`), and
switching roots prunes the other root's checkouts ("First remove the checkouts that are
no longer required", Workspace+Dependencies.swift L708–721) — pure thrash. The only
multi-root mechanism is the hidden Xcode `--multiroot-data-file`.

### 4. Resolution levers: the cheap regime the source actually supports

**The fast path exists and is fast** [Verified: 2026-07-09]. When (i) `Package.resolved`
exists, (ii) its `originHash` (sha256 over ROOT manifest bytes + root dep locations)
matches, and (iii) no deps are edited, `swift build` runs the resolved-file path:
container requests go out in a **parallel** task group with
`updateStrategy: .ifNeeded(revision:)` — for a branch pin whose revision is already in
the local bare repo this is a **no-fetch no-op** — followed by cache-served manifest
loads and a git-free precomputation ("is a re-resolve needed?") over already-loaded
state ([Workspace+Dependencies.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/Workspace/Workspace+Dependencies.swift)
`tryResolveBasedOnResolvedVersionsFile` L399–476,
[ResolverPrecomputationProvider.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/Workspace/ResolverPrecomputationProvider.swift)).
Result `.notRequired` → "Everything is already up-to-date" in seconds. A warm gate with
intact `.build` + `Package.resolved` costs seconds of resolution, minutes of compile —
consistent with tonight's warm gates (4–10 min end-to-end).

**Deleting `Package.resolved` is refuted as a re-gating tool** [Verified: 2026-07-09].
With `.build/workspace-state.json` alive, a missing resolved file is reconstructed FROM
workspace state — `.sourceControlCheckout(.branch(branch, revision))` maps back to the
**old** pin (`loadAndUpdateResolvedPackagesStore`, Workspace+Dependencies L914–943;
[ResolvedPackagesStore.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/PackageGraph/ResolvedPackagesStore.swift)
L203–205 returns an empty store that is then repopulated). The habit therefore does NOT
advance branch pins; it only "works" when `.build` is also gone — which is precisely the
maximally-expensive cold path of §1b. Current policy item (3) is both ineffective and,
when effective, pessimal.

**The designed pin-advance lever is `swift package update [names]`** [Verified:
2026-07-09]: with no arguments it ignores all pins and re-binds every branch dep to the
current fetched head; with package names it drops **only those pins**
(`_updateDependencies` L61–204, L112–124). Bare repos and unchanged checkouts are
reused; manifests come from the shared cache. It still pays the serial branch walk +
per-repo fetch, but never the re-clone/re-checkout/re-compile of the world.
`swift package resolve` does NOT advance branch pins.

**Gate-exact mode**: `--force-resolved-versions` (= `--disable-automatic-resolution` =
`--only-use-versions-from-resolved-file`) forces the resolved-file path and **errors
rather than re-solves** when root requirements drifted from pins ("an out-of-date
resolved file was detected at … which is not allowed when automatic dependency
resolution is disabled"). A moved branch head alone does not trip it — the pinned
revision still satisfies the branch-name requirement — so it gates against exactly the
pinned state [Verified: 2026-07-09, Options.swift L315–320, Workspace+Dependencies
L304–335].

**`--skip-update`** flips every lookup to `.never` — zero `git fetch` anywhere in
resolution; missing repos are still cloned. Deprecated with a warning since ~6.0
([PR #7229](https://github.com/swiftlang/swift-package-manager/pull/7229)) but fully
functional in 6.3 [Verified: 2026-07-09, SwiftCommandState L499–502]. For re-gates
against mirrors that haven't moved, it deletes ~300 fetch subprocesses from even the
full-solve path. Risk: silently-stale heads on a full solve — acceptable when the gate
intends "pinned state", wrong when the gate intends "current heads".

**Registry, prebuilts, `.package(path:)`** [Verified: 2026-07-09]: a package registry
serves version ranges only — no branch concept — so it cannot replace the branch
topology. Prebuilts are swift-syntax-only and remote-refs-only (§1d) — inert here.
`.package(path:)` deps are `.fileSystem` kind: processed as unversioned constraints with
no clone, no fetch, no checkout, no pin — near-zero resolution cost — at the price of
manifest changes (or a generated dev overlay); this is the mechanism the umbrella
pattern (§5) exploits.

### 5. Build-product reuse across packages

**On 6.3.2 there is none, and none can be configured** [Verified: 2026-07-09]. SwiftPM's
shared caches cover fetching/manifests/binary artifacts only; compiled products live per
root `.build`. The per-root module cache (§1d) means even `.pcm`/interface work repeats
per package. What exists elsewhere:

- **CAS compilation caching (the real fix, not yet landed)**: swift-driver has
  experimental `-cache-compile-job` / `-cas-path` (env `SWIFT_ENABLE_CACHING`), gated on
  explicit modules
  ([Driver.swift](https://github.com/swiftlang/swift-driver/blob/main/Sources/SwiftDriver/Driver/Driver.swift):
  "-cache-compile-job cannot be used without explicit module build"); productized only
  as Xcode 26's opt-in compilation cache; path-sensitivity across roots is the known
  blocker ([forums 81850](https://forums.swift.org/t/about-swift-shared-cache-across-machines/81850)).
  SwiftPM-native support is a **pitch dated 2026-07-06** — "Compilation Caching Support
  in SwiftPM" ([forums 88079](https://forums.swift.org/t/pitch-compilation-caching-support-in-swiftpm/88079),
  open [PR #10246](https://github.com/swiftlang/swift-package-manager/pull/10246)):
  machine-global CAS, prefix mapping, "68% faster" cached clean builds — exactly this
  workspace's shape, in 6.4+ at earliest. Track it; do not build policy on it.
- **`--build-system swiftbuild`**: preview in 6.3 ("The native build system remains the
  default", [6.3 release notes](https://github.com/swiftlang/swift-package-manager/blob/main/Sources/PackageManagerDocs/Documentation.docc/ReleaseNotes/6.3.md));
  default flips on main for 6.4
  ([forums 85548](https://forums.swift.org/t/swiftpm-development-update-default-build-system-change/85548)).
  Still one `.build` per root — no cross-root sharing today; it is the explicit-modules
  substrate the CAS work builds on.
- **Binary targets**: XCFrameworks (SE-0272) for Swift API require library evolution or
  exact compiler match; SE-0482 (Swift 6.2) covers C-interface static libraries. Not a
  practical substrate for 400 fast-moving main-pinned Swift repos.

**The umbrella / mega-manifest pattern — half-viable, with a live counterexample**:

- *Build gating works* [Verified: 2026-07-09]: one root `Package.swift` with
  `.package(path:)` deps on N sibling repos gives ONE resolve (near-zero per §4) and ONE
  build graph; `swift build --target <M>` addresses any non-test module in the whole
  graph ([BuildOperation.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/Build/BuildOperation.swift)
  `computeLLBuildTargetName`); shared deps compile exactly once.
- *Test gating does NOT work* [Verified: 2026-07-09]: dependencies load with
  `ProductFilter.specific` — test targets of dependencies never enter the graph
  ([Product.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/PackageModel/Product.swift)
  L136–139, [ModulesGraph+Loading.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/PackageGraph/ModulesGraph+Loading.swift)
  L59–79); maintainer confirmation "Running tests of remote dependencies is not directly
  possible" ([forums 62760](https://forums.swift.org/t/running-swiftpm-tests-inside-project/62760)).
  An umbrella can compile-verify everything; it cannot run sibling test suites.
- *The graph-wide name-uniqueness constraint already bites this ecosystem* [Verified:
  2026-07-09, tonight's build4.log]: "error: multiple packages ('swift-parsing',
  'swift-standards') declare targets with a conflicting name: 'Parsing'; target names
  need to be unique across the package graph" (diagnostic source:
  [PackageBuilder.swift](https://github.com/swiftlang/swift-package-manager/blob/release/6.3/Sources/PackageLoading/PackageBuilder.swift)
  L114; products likewise, ModulesGraph.swift L377). A 400-package umbrella requires a
  target/product-name collision inventory first; `moduleAliases` is the per-collision
  escape hatch.
- *Xcode workspace*: one workspace = one shared build directory with implicit
  dependency dedup ([Xcode Concepts: Workspace](https://developer.apple.com/library/archive/featuredarticles/XcodeConcepts/Concept-Workspace.html));
  per-package `<Name>-Package` schemes can run tests with shared derived data. Cost:
  Swift Build/xcodebuild semantics are not `swift build` semantics — a green xcodebuild
  is not the consumers' artifact — plus per-invocation xcodebuild overhead and known
  workspace-scale indexing pain ([forums 53739](https://forums.swift.org/t/monorepo-using-spm-packages/53739)).
  The existing `swift-primitives-dev.xcworkspace` (394 FileRefs) is this pattern.
- *Prior art*: pointfree's isowords chose "one package, many modules" (91 modules)
  precisely to get one shared graph; multi-package workspace support for SwiftPM has
  been pitched since 2017 and never landed; Tuist/Bazel solve it by replacing SwiftPM.

### 6. The 143 kills and the gate-runner pattern

**Attribution** [Verified: 2026-07-09]. 143 = 128+15 = SIGTERM (bash/zsh manuals).
Sources ruled OUT: SwiftPM (never signals non-children, §3); macOS jetsam (kills with
SIGKILL → exit 137, [Apple: SIGKILL](https://developer.apple.com/documentation/xcode/sigkill)).
Sources ruled IN:

1. **The agent harness**. The Bash tool kills with SIGTERM on timeout (live-reproduced
   during this research: a hung CLI call died at exactly 120 s with "Exit code 143");
   background tasks launched with `nohup … &` are tracked and SIGTERM'd at session
   end/compaction ([claude-code #25188](https://github.com/anthropics/claude-code/issues/25188));
   group-targeted kills reach nohup'd children because non-interactive shells run
   background jobs in the SAME process group (bash man: monitor mode off) and nohup only
   blocks SIGHUP (nohup(1)).
2. **Sibling sessions' contention `pkill`**. pkill's default signal is SIGTERM
   (pkill(1)), and the workspace Gotchas table currently instructs sessions to "pkill
   stale swift-* on contention" — a convention that kills healthy foreign gates. No
   detach technique defends against it.

Tonight's death is timing-attributed to (1) or (2), not a timeout: gate-mailgun-types.log
shows `GATE START 22:02:40` → `BUILD_EXIT=143` marker by 22:03:06 — dead ~26 s after
launch [Verified: 2026-07-09, log mtime].

**Robust gate-runner** [Verified mechanics; assembled recommendation]. macOS ships no
setsid(1) binary; `(cmd &)`, `disown`, and `&!` change neither session nor (in
non-interactive shells) process group. The correct detach is a double-fork +
`os.setsid()` daemonizer (stock `/usr/bin/python3`), which (a) returns to the tool shell
immediately — no tracked background task exists to clean up, (b) is immune to any
kill(-PGID) aimed at the shell's group, (c) writes log + PID + exit-code marker files:

```zsh
# gate-run <abs-pkg-path> <cmd...>   — detached, group-kill-immune, marker-emitting
/usr/bin/python3 -c '
import os, sys
pkg = sys.argv[1]; gate = os.path.join(pkg, ".gate"); os.makedirs(gate, exist_ok=True)
if os.fork() > 0: sys.exit(0)
os.setsid()
if os.fork() > 0: os._exit(0)
log = os.open(os.path.join(gate, "build.log"), os.O_WRONLY|os.O_CREAT|os.O_APPEND, 0o644)
os.dup2(log, 1); os.dup2(log, 2)
nul = os.open("/dev/null", os.O_RDONLY); os.dup2(nul, 0)
os.chdir(pkg)
open(os.path.join(gate, "supervisor.pid"), "w").write(str(os.getpid()))
pid = os.fork()
if pid == 0:
    os.execvp("taskpolicy", ["taskpolicy", "-c", "utility", "caffeinate", "-i"] + sys.argv[2:])
open(os.path.join(gate, "build.pid"), "w").write(str(pid))
_, status = os.waitpid(pid, 0)
rc = os.waitstatus_to_exitcode(status)
open(os.path.join(gate, "exit-code"), "w").write(str(rc if rc >= 0 else 128 - rc) + "\n")
' "$PKG" env -i HOME="$HOME" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
  TMPDIR="$TMPDIR" TOOLCHAINS=org.swift.632202605101a \
  swift build -j 4 --force-resolved-versions --skip-update
```

The `env -i` sanitization is load-bearing (§1c): it removes the session-unique
`CLAUDE_CODE_*` variables so every gate in every session shares ONE manifest-cache
key-space. `TMPDIR` must be passed through so all invocations resolve the same lock
directory (§3). `taskpolicy -c utility` caps QoS so user-interactive work preempts
builds while still allowing P-core use when idle; `-c background` would clamp to E-cores
at near-idle clock — roughly half the cores at a quarter of the frequency — even with
P-cores idle ([man taskpolicy]; Howard Oakley,
[What is Quality of Service?](https://eclecticlight.co/2025/05/09/what-is-quality-of-service-and-how-does-it-matter/),
[Why E cores make Apple silicon fast](https://eclecticlight.co/2026/02/08/last-week-on-my-mac-why-e-cores-make-apple-silicon-fast/)).
`nice -n 20` does not change core allocation on Apple silicon [PLAUSIBLE; experiment E5].

**Progress monitoring without a TTY** [Verified phase markers: 2026-07-09]: the
signal ladder is `ls .build/repositories | wc -l` growing (fetch) →
`.build/checkouts` populating (checkout) → `workspace-state.json` appears (resolution
complete) → `[n/m]` llbuild counter lines in the log (compile) →
`pgrep -x swift-frontend | wc -l` (live width). Add `-v` to gates: the resolve phase
becomes chatty (per-repo `Fetching`/`Updating`/`Creating working copy` lines) and the
log's mtime becomes a heartbeat. Stall heuristic: no exit marker + static log mtime +
static `du -sk .build` + zero swift-frontend/git children for >5 min → investigate;
anything else is progress, not a hang. `--enable-build-manifest-caching` (default on)
only skips llbuild-manifest regeneration ("Planning build") — keep the default; it is
not a progress signal.

## Comparison

| Criterion | Status quo (≤2 invocations, default `-j`, delete-resolved, nohup gates) | Recommended (3 slots × `-j 4`, sanitized env, pin-advance via update, daemonized gates) | Umbrella build-gate (path-dep root) | Xcode workspace test-gating | CAS caching (6.4+ pitch) |
|---|---|---|---|---|---|
| Cold-resolve cost per gate | 20–60 min (§1b–1c, self-inflicted cold) | Seconds–minutes (fast path preserved; env-stable manifest cache) | Near-zero resolution (path deps) | Xcode-managed | Unchanged (resolution ≠ compile cache) |
| Compile dedup across packages | None | None (per-root `.build` unchanged) | Full (one graph) | Full (shared derived data) | Full (content-addressed) |
| Test gating fidelity | `swift test` per package (correct) | `swift test` per package (correct) | **Cannot run sibling tests** | xcodebuild ≠ `swift build` semantics | `swift test` (correct) |
| Machine saturation with many small gates | Poor (serial phases idle the box; queueing at 2 slots) | Good (overlapped serial/compile phases; bounded fan-out) | Good for builds | Moderate | Good |
| Preconditions | — | Ratify policy; fix gotcha (pkill) | Name-collision inventory; generated manifest | Scheme generation; fidelity acceptance | Swift 6.4+; upstream landing |
| Risk | Slow, 143-prone, cache-thrashing | Low (all defaults-compatible, reversible) | Medium (graph co-resolution, collisions) | Medium (fidelity) | N/A yet |

## Outcome

**Status**: RECOMMENDATION

### Recommended machine policy (safe now on 6.3.2)

| Knob | Setting | Mechanism |
|---|---|---|
| Concurrent SwiftPM invocations, machine-wide | **3** (any mix of build/test), never 2 on the same package | §2 serial phases overlap across gates; §3 same-package invocations only queue on the workspace lock |
| `--jobs` per gate invocation | **`-j 4`** mandatory for gates; dedicated single-invocation window with default `-j 8` for heavyweight packages (large modules, release builds) | §2: 3×4=12 lanes ≈ 1.5× cores (benign CPU over-commit; bounded memory); caps N² frontend fan-out; WMO ignores `-j` per-module |
| Gate environment | **`env -i HOME PATH TMPDIR TOOLCHAINS`** — sanitized, canonical, identical across sessions | §1c: session-unique `CLAUDE_CODE_*` vars fork the shared manifest cache and drive the 100 MB truncate-wipe cycle |
| Resolve mode for gates | **`--force-resolved-versions --skip-update`** (gate = pinned state; loud error on manifest/pin drift) | §4: parallel `.ifNeeded` no-fetch path; zero fetch subprocesses |
| Advancing branch pins | **`swift package update [dep-names]`** — targeted where possible. **Never delete `Package.resolved`** (ineffective with live workspace-state; pessimal without) | §4 |
| `.build` hygiene | Preserve `.build` between gates (the fast path depends on it); `rm -rf .build` remains the *debugging* move per [PKG-BUILD-010], and the first post-clean gate runs in a dedicated slot | §1b, §4 |
| QoS | `taskpolicy -c utility` on every gate; **never** `-c background` for time-sensitive gates | §6 E-core clamp |
| Load accounting | Count **`pgrep -x swift-frontend`** (+ test runners), not `swift-build` processes | §2: `swift test` builds with `-j 8` by default and Swift Testing runs parallel regardless |
| Contention handling | **Blind `pkill swift-*` is forbidden.** Kill only PIDs registered in `*/.gate/build.pid`, and only by the owning session; amend the CLAUDE.md gotcha accordingly | §6 attribution |
| Gate launcher | The double-fork + setsid daemonizer of §6 with log/PID/exit-code markers | §6: immune to harness group-SIGTERM and background-task cleanup |
| Caching flags | Keep defaults (`--enable-dependency-cache`, `--manifest-cache shared`, `--enable-build-manifest-caching`, prebuilts) — all already optimal; no `--cache-path` change needed | §1, §3 |

### Needs a flag/experiment first (NOT ratified for general use)

| Item | Status | Gate |
|---|---|---|
| 3-slot × `-j 4` throughput claim | PLAUSIBLE | Experiment E1 |
| Umbrella build-gate over N repos | Feasibility verified; requires collision inventory + generated manifest; build-gates only | Experiment E2 |
| Manual CAS (`-Xswiftc -cache-compile-job -Xswiftc -cas-path`) | Experimental upstream; explicit-modules-gated | Experiment E4 |
| `--build-system swiftbuild` | Preview in 6.3 | Re-evaluate at the 6.4 flip |
| `SWIFTPM_MAX_CONCURRENT_OPERATIONS` down-tuning under concurrency | Plausible micro-win; changes env → one-time manifest-cache invalidation if adopted (bake into the canonical env from day one or not at all) | Experiment E1 (co-measure) |
| `SWIFTPM_TESTS_PACKAGECACHE=1` (cache local repos) | Rejected: unsupported test hook; wins ≈nothing (mirrors already local, clones hardlinked, 0.06 s) | — |

### Proposed [PKG-BUILD-009] amendment

Replace the blanket "Multiple `swift build` invocations MUST NOT run in parallel" with:

1. **Same package**: unchanged MUST NOT — a second invocation only blocks on the
   workspace lock (observed "Another instance of SwiftPM … waiting"), adds no progress,
   and reads as a hang.
2. **Cross-package**: up to **3** concurrent invocations machine-wide, each REQUIRED to
   run via the standard gate-runner (sanitized env, `-j 4`, `taskpolicy -c utility`,
   `.gate/` markers). Foreign sessions' gates count; slots are accounted by
   `.gate/build.pid` registry + `swift-frontend` count, not `swift-build` greps.
3. **Contention recovery**: killing is a last resort, targets only registered gate PIDs,
   and belongs to the owning session. The `.build` directory after a kill MAY be
   corrupted → [PKG-BUILD-010] applies. Blind `pkill swift-*` is forbidden.
4. **Resolve discipline**: gates run `--force-resolved-versions --skip-update`; pins
   advance only via `swift package update [names]`; `Package.resolved` deletion is not a
   re-gating tool.

The original rule's rationale ("cross-package parallelism still fights for CPU, memory,
and module-cache slots") was directionally right about default-`-j` invocations —
2 × `-j 8` = 16 lanes on 8 cores plus fan-out — and the fix is capping `-j`, not
serializing the machine. The "module-cache slots" clause is refuted: module caches are
per-package (§1d); the real shared contention points (repository cache, manifest db) are
lock-protected and safe (§3).

### Single highest-leverage change

**Standardize the sanitized gate environment + resolve-avoidance flags** (`env -i …
swift build -j 4 --force-resolved-versions --skip-update`, pins advanced via
`swift package update`, `Package.resolved` never deleted): it converts the dominant
observed cost — 20–60 min self-inflicted cold resolves, re-paid per session because
session-unique env vars fork and truncate-wipe the one cache that is shared — into a
seconds-scale fast path, with zero toolchain risk and full reversibility.

## Residual

Premise items (load-bearing, unverified locally — each with the exact experiment an
/experiment-process run would perform; immediate experiment-package creation was
precluded by the build-capacity freeze under which this research ran, per the dispatch
constraints — [RES-027] carve-out documented here):

- **E1 — Concurrency sweet spot** (premise: 3 × `-j 4` ≥ throughput of 2 × `-j 8` for
  small-package gate batches). Fixture: 12 representative gates (4 primitives, 4
  standards, 4 foundations), warm resolves. Matrix: {1×8, 2×8, 2×4, 3×3, 3×4, 4×2} ×
  {taskpolicy off, utility}. Measure wall-clock for the batch, peak
  `pgrep -x swift-frontend | wc -l`, `memory_pressure`, and foreground-session
  responsiveness probe. Decision rule: adopt the configuration minimizing batch
  wall-clock subject to responsiveness ≥ baseline.
- **E2 — Umbrella build-gate** (premise: one generated root with `.package(path:)` deps
  on N repos build-verifies them with ≥5× less total compile than N independent gates).
  Step 0: collision inventory (`swift build` of the generated manifest surfaces
  "conflicting name" errors; count and classify — tonight's logs already show 'Parsing'
  and 'similar targets' collisions). Then: umbrella over a 20-repo collision-free
  cluster; measure one `swift build --build-tests`-less full build vs 20 sequential
  gates; verify `swift build --target X` addressability; confirm sibling tests are
  unreachable (expected per §5).
- **E3 — Frontend RSS on this hardware** (premise: typical institute-module
  swift-frontend RSS 100–300 MB, so 12 lanes fit in 24 GB). During E1, sample
  `ps -o rss= -p $(pgrep -x swift-frontend)` at 1 Hz; report p50/p95/max.
- **E4 — Manual CAS spike** (premise: `-Xswiftc -explicit-module-build -Xswiftc
  -cache-compile-job -Xswiftc -cas-path <shared>` produces cross-package cache hits on
  6.3.2). Two dep-heavy siblings sharing ≥90% of their graph; build A then B against one
  CAS path; compare B's compile task count and wall-clock vs no-CAS; inspect
  `-cache-remarks`. Failure expected to be graceful (driver warning, caching off).
- **E5 — QoS clamp quantification** (premise: `-c background` ≈ 3–5× wall-clock
  inflation vs `-c utility` on M3 when the machine is otherwise idle). One fixed gate
  under {none, utility, background}; measure wall-clock + `powermetrics --samplers
  tasks` core residency.

Direction items (not load-bearing): track the SwiftPM CAS pitch
([forums 88079](https://forums.swift.org/t/pitch-compilation-caching-support-in-swiftpm/88079))
and the 6.4 swiftbuild default flip for the point where cross-package compile dedup
becomes configuration instead of architecture; revisit the Xcode-workspace test-gating
route only if per-package `swift test` remains the binding constraint after E1/E2.

## References

Primary source (all read at `release/6.3` @ `5f6969f5` or tag `swift-6.3.2-RELEASE` unless noted):

- [swiftlang/swift-package-manager](https://github.com/swiftlang/swift-package-manager) — RepositoryManager.swift (local-repo cache bypass L314–316; git-op throttle L82–84; cache locks L319–341), PubGrubDependencyResolver.swift (serial revision walk L375–457; prefetch-skips-overridden L218–225), ContainerProvider.swift (`.always` fetch L86), Workspace+Dependencies.swift (fast path L399–476; serial checkouts L690–757; pin reconstruction L914–943; out-of-date error L304–335), ManifestLoader.swift (manifest compile L682–880; cache key L484, L1058–1080), EnvironmentKey.swift (nonCachable L44–59), SQLiteBackedCache.swift (100 MB truncate-wipe L103–118, L256–267), DependencyMapper.swift (path mirror → localSourceControl L68–80), SwiftCommandState.swift (lock wait L1143–1194; skip-update deprecation L499–502), Options.swift (jobs default L529–531; flags), BuildOperation.swift (schedulerLanes L896; computeLLBuildTargetName), SwiftModuleBuildDescription.swift (`-j` passthrough L512; WMO `-num-threads` L497–499), BuildPlan.swift (per-root ModuleCache L40–50), PackageBuilder.swift (target-name uniqueness L114), ModulesGraph.swift (product-name uniqueness L377), Product.swift / ModulesGraph+Loading.swift (dependency test-target exclusion), Workspace+Prebuilts.swift (swift-syntax-only, remote-only), AsyncProcess.swift (signals own children only L920–931)
- [swiftlang/swift-llbuild — LaneBasedExecutionQueue.cpp](https://github.com/swiftlang/swift-llbuild/blob/main/lib/Basic/LaneBasedExecutionQueue.cpp); [swiftlang/swift-driver — Planning.swift](https://github.com/swiftlang/swift-driver/blob/main/Sources/SwiftDriver/Jobs/Planning.swift) (NCPU² comment, RSS model), [Driver.swift](https://github.com/swiftlang/swift-driver/blob/main/Sources/SwiftDriver/Driver/Driver.swift) (CAS gating)
- [swiftlang/swift-testing — EntryPoint.swift](https://github.com/swiftlang/swift-testing/blob/swift-6.3.2-RELEASE/Sources/Testing/ABI/EntryPoints/EntryPoint.swift), [Parallelization.md](https://github.com/swiftlang/swift-testing/blob/swift-6.3.2-RELEASE/Sources/Testing/Testing.docc/Parallelization.md)
- [swift-tools-support-core — Lock.swift](https://github.com/swiftlang/swift-tools-support-core/blob/release/6.3/Sources/TSCBasic/Lock.swift) ($TMPDIR flock)

Forums / evolution / upstream discussion:

- [Should `-j 1` be used for swiftc invocations? (36613)](https://forums.swift.org/t/should-j-1-be-used-for-swiftc-invocations/36613) · [Globally Optimized Build Parallelism? (31802)](https://forums.swift.org/t/globally-optimized-build-parallelism/31802) · [Why is fetching dependencies with SwiftPM so slow? (67191)](https://forums.swift.org/t/why-is-fetching-dependencies-with-swiftpm-so-slow/67191) · [SwiftPM stuck in unrecoverable state (85713)](https://forums.swift.org/t/swiftpm-stuck-in-unrecoverable-state/85713) · [Running SwiftPM tests inside project (62760)](https://forums.swift.org/t/running-swiftpm-tests-inside-project/62760) · [Monorepo using SPM packages (53739)](https://forums.swift.org/t/monorepo-using-spm-packages/53739) · [Preview: Swift-Syntax Prebuilts for Macros (80202)](https://forums.swift.org/t/preview-swift-syntax-prebuilts-for-macros/80202) · [Pitch: Compilation Caching Support in SwiftPM (88079)](https://forums.swift.org/t/pitch-compilation-caching-support-in-swiftpm/88079) · [About Swift shared cache across machines (81850)](https://forums.swift.org/t/about-swift-shared-cache-across-machines/81850) · [SwiftPM on Swift Build, October update (82889)](https://forums.swift.org/t/swiftpm-on-swift-build-october-update/82889) · [Default build system change (85548)](https://forums.swift.org/t/swiftpm-development-update-default-build-system-change/85548)
- PRs/issues: [#7229 skip-update deprecation](https://github.com/swiftlang/swift-package-manager/pull/7229) · [#8142 prebuilts](https://github.com/swiftlang/swift-package-manager/pull/8142) · [#10246 compilation caching (open)](https://github.com/swiftlang/swift-package-manager/pull/10246) · [#8528 lock-holder PID](https://github.com/swiftlang/swift-package-manager/issues/8528) · [#2835 system-wide cache design](https://github.com/swiftlang/swift-package-manager/pull/2835)
- [SE-0272 Binary Targets](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0272-swiftpm-binary-dependencies.md) · [SE-0482 Binary Static Library Dependencies](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0482-swiftpm-static-library-binary-target-non-apple-platforms.md) · [Swift Build open-sourcing](https://www.swift.org/blog/the-next-chapter-in-swift-build-technologies/)

Platform / harness:

- [claude-code #25188 background-task SIGTERM cleanup](https://github.com/anthropics/claude-code/issues/25188) · [#45717 timeout SIGTERM / 143](https://github.com/anthropics/claude-code/issues/45717) · [#16135 process-group kill](https://github.com/anthropics/claude-code/issues/16135) · [#25881 10-minute cap](https://github.com/anthropics/claude-code/issues/25881)
- [Apple: SIGKILL/jetsam](https://developer.apple.com/documentation/xcode/sigkill) · [Xcode Concepts: Workspace](https://developer.apple.com/library/archive/featuredarticles/XcodeConcepts/Concept-Workspace.html) · [Building Swift packages in CI](https://developer.apple.com/documentation/xcode/building-swift-packages-or-apps-that-use-them-in-continuous-integration-workflows)
- Howard Oakley: [What is Quality of Service?](https://eclecticlight.co/2025/05/09/what-is-quality-of-service-and-how-does-it-matter/) · [Why E cores make Apple silicon fast](https://eclecticlight.co/2026/02/08/last-week-on-my-mac-why-e-cores-make-apple-silicon-fast/)
- man pages (macOS 26.5): nohup(1), pkill(1), taskpolicy(8), bash(1), zshmisc(1), setsid(2)

Internal: [PKG-BUILD-009]/[PKG-BUILD-010]/[PKG-BUILD-011] (swift-package-build skill) · `Research/benchmark-serial-execution.md` · `Research/2026-05-07-clean-build-first-elevation.md` · local forensics ledger of 2026-07-09 (hardware, caches, hardlinks, fetch timeline, lock messages, gate logs) reproduced in §1 and Context.
