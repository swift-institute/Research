# Near-Instant swift-linter Runs with External Rule Loading

<!--
---
version: 1.0.0
last_updated: 2026-06-24
status: RECOMMENDATION
research_tier: 2
applies_to:
  - swift-foundations/swift-linter
  - swift-foundations/swift-linter-rules
  - swift-foundations/swift-institute-linter-rules
  - swift-foundations/swift-manifests
  - swift-primitives/swift-linter-primitives
  - swift-primitives/swift-primitives-linter-rules
  - swift-institute/.github (swift-ci.yml swift-linter job)
  - all consumer packages adopting swift-linter
extends: 2026-05-12-swift-linter-unified-consumer-manifest.md
supersedes-partial: .handoffs/REPORT-swift-linter-binary-product-synthesis.md (the eval-cache §4 recommendation)
normative: false
---
-->

## Context

### Trigger

Running swift-linter against a consumer today (`swift run swift-linter <consumer>`)
costs **≈605s per consumer per CI run** — two independent from-source builds. The
dispatch is a `/research-process` request (`.handoffs/HANDOFF-swift-linter-instant-lint-architecture.md`)
to design an architecture that makes warm runs **near-instant — ideally
~instantaneous — WHILE retaining external, consumer-declared rule loading**. The
brief states the two goals are "in tension and must be reconciled, not traded
off," and constrains the win to come from "caching / precompiling /
resident-process strategies that keep rule selection fully dynamic and
consumer-owned."

This doc supersedes the eval-cache recommendation (§4) of the prior binary-product
synthesis (`.handoffs/REPORT-swift-linter-binary-product-synthesis.md`), whose
open blocking question ("can a standalone binary resolve the engine dependency
without a `SWIFT_LINTER_PATH` source checkout?") this doc answers and builds on.

### How swift-linter dispatches (the mechanism being optimized)

`Verified: 2026-06-24` against source.

A Shape-γ consumer ships a single-file `Lint.swift` (magic comment
`// swift-linter-tools-version: 0.1`) declaring (a) the SwiftPM rule-pack
dependencies the linter must fetch and (b) the rule activations to apply. The
`swift-linter` CLI is a **coordinator**: it does not lint directly. Per
`Sources/Linter Core/Lint.File.Single.swift:227-336` it parses `Lint.swift` via
SwiftSyntax to extract the `.package(...)` declarations, then materializes a
throwaway SwiftPM "eval" project at `<consumer>/.swift-lint/eval/`, copies
`Lint.swift` in as `main.swift`, and runs `swift run --package-path <eval> Lint`
(`swift-manifests/Sources/Manifest Executable/Manifest.Executable.swift:68-95`).
"The dispatched executable IS the linter binary for the consumer."

The engine is wired into the eval as a **local path dependency on the `Linter`
LIBRARY product** (`Lint.File.Single.swift:283-288`):

```swift
let linterDependency = Package.Dependency(
    source: .path(linterPathTyped),   // requires SWIFT_LINTER_PATH (engine SOURCE tree)
    name: "swift-linter",
    products: ["Linter"])             // eval links the Linter LIBRARY ⇒ engine recompiles inside every eval
```

The architecture is deliberate: the engine ships **zero built-in rules** (Phase
B.1 decouple, `2026-05-07-phase-b1-decouple.md`); the consumer's compiled eval
*is* the linter; rules — including **inline custom rules authored directly in
`Lint.swift`** — are Swift code using SwiftSyntax AST visitors, type-checked
against resolved deps (the Shape-γ two-phase eval,
`2026-05-12-swift-linter-unified-consumer-manifest.md`, Tier 3).

### The cost structure (verified, not re-derived)

| Cost | Compiles | ~time | Verification |
|---|---|---|---|
| Engine CLI build | `Linter CLI` + `Linter Core` + reporters + **SwiftSyntax** | ~270s | `Carried forward` (handoff, Linux CI 2026-06-24); corroborated by `phase-b1-decouple.md` (234s local) |
| **Eval build** | engine `Linter` LIBRARY + **SwiftSyntax** + consumer's rule packs + ~156 transitive `branch:"main"` deps + `Lint.swift` | **~335s** | `Carried forward` (handoff; `Build of product 'Lint' complete! (335.38s)`); corroborated by `phase-b1-decouple.md` (308s local) |
| **Total** | | **≈605s** | |

Two facts dominate everything below, both **empirically verified for this doc**:

1. **SwiftSyntax-from-source is the floor, and it is ≈155s on Linux.**
   `Verified: 2026-06-24` — a minimal, near-empty program importing
   `SwiftSyntax`/`SwiftParser`/`SwiftOperators` builds in **154.52s** on Linux
   (`swift:6.3`, release) and 161s on macOS, compiling 76 SwiftSyntax object
   files from source (probe package + Docker timing, scratch experiment). Every
   rule pack imports SwiftSyntax directly (`swift-linter-primitives/Package.swift:31,44`;
   every target in `swift-institute-linter-rules/Package.swift`), as does any
   inline custom rule. SwiftSyntax is pulled by the engine, by every rule pack,
   AND by the consumer's `Lint.swift`.

2. **SwiftSyntax compiles redundantly — twice per run.** The ~270s engine CLI
   build and the ~335s eval build *each* compile SwiftSyntax + `Linter Core`. The
   CLI is only a dispatcher; the eval rebuilds the whole engine library anyway.
   At minimum one full ~155s SwiftSyntax compile per run is pure redundancy.

### The consumer population (verified census)

`Verified: 2026-06-24` — of **78 consumer `Lint.swift` files** across
swift-primitives/foundations/standards, **77 are pure-bundle** (declare standard
rule packs + a `Lint.Rule.Bundle.X` + `excluding(rules:)`/`enable(...)` of
*known* rule IDs) and **exactly 1** (swift-carrier-primitives) authors an inline
custom rule (`sli public carrier import`) and imports SwiftSyntax in its
`Lint.swift`. **98.7% of consumers exercise rule *selection*, not rule
*authoring*** — their rule set is fully known ahead of time and therefore
prebuildable.

## Question

How can a swift-linter run become near-instant on warm runs while keeping rule
selection external and consumer-declared — given that (a) rules are SwiftSyntax
visitors that must be compiled, (b) SwiftSyntax-from-source (~155s) cannot be
avoided on Linux by any supported tooling, and (c) the ecosystem's verified CI
posture is *no `.build` cache* with `branch:"main"` deps?

## The reconciliation principle

The two goals are reconcilable once the conflated concern is split:

> **Rule *selection* (which packs, which bundle, which rules on/off, plus any
> inline rules) stays dynamic and consumer-owned in `Lint.swift`. Rule
> *compilation* is lifted out of the per-run hot path by prebuilding the standard
> rule packs as selectable artifacts. The eval-compile path remains as the
> fully-general fallback for inline / custom rules.**

Near-instant comes from *not recompiling per run*; external loading is preserved
because selection still lives in `Lint.swift` and custom-rule authoring keeps the
compile path. This is exactly the "precompiling strategy that keeps rule
selection fully dynamic and consumer-owned" the brief invites — not the
out-of-scope "bake a fixed rule set into a binary."

The rest of this doc establishes *why* the obvious alternatives (binary engine,
eval caching, dynamic loading, daemon) cannot carry the reconciliation alone,
and what phased path delivers it.

## Analysis

Each direction is evaluated on **feasibility**, **latency**, and
**constraint-fit**. Load-bearing claims carry verification tags; primary sources
are listed in References.

### Direction 1 — Engine as a published, versioned SwiftPM dependency

**What it is.** Change the eval generation so the engine is referenced via
`.package(url: <pinned release>, products:["Linter"])` (with `.path(...)` retained
only as a local-dev fallback when `SWIFT_LINTER_PATH` is set).

**Feasibility: yes, and it is the precursor to everything.** It resolves the prior
synthesis's open blocker: a standalone CLI binary has no engine *source tree*, so
the eval's `.path(SWIFT_LINTER_PATH)` dependency cannot resolve; a URL/registry
pin lets the eval reference the engine without a checkout.

**Latency: zero direct saving.** `Verified` (SE-0272; SwiftPM PackageDescription
docs) — a URL *source* dependency is compiled identically to a path dependency.
URL-vs-path changes only *how source is obtained* and *whether it participates in
version resolution*; the `Linter` library + SwiftSyntax still recompile in the
eval. **Direction 1 is an enabler, not a speedup.** It unlocks (a) a prebuilt CLI
(Direction → Phase 1) and (b) stable, cacheable eval resolution.

**Constraint-fit: clean.** Rule loading is untouched.

**Ask-principal:** the eval's engine-reference form is internal to the
dispatcher; the consumer-facing `Lint.swift` contract is unchanged. No ratify
needed for Direction 1 itself.

### Direction 2 — Eval `.build` caching

**Feasibility/latency split sharply between LOCAL and CI.**

**Local: a real win, already mostly free.** `Verified` — the dispatch never
cleans `<consumer>/.swift-lint/eval/.build` (no removal in `Lint.File.Single.swift`
or the Materializer); it persists between invocations. Estimated local warm run
**~10–40s** vs ~335s cold. One subtlety: the Materializer writes `main.swift` via
atomic temp-file+rename (`File.System.Write.Atomic`), changing its inode/mtime
every run; llbuild change-detection is stat-based, so the single `Lint` target
recompiles each warm run even when bytes are identical — but the ~156-package
dependency graph does **not** (the regenerated `Package.swift` is byte-identical,
and SwiftPM's `ManifestLoader` is content-hash cached, so no re-resolution).
`Verified: swiftlang/swift-llbuild FileInfo.h; SwiftPM ManifestLoader.swift; SwiftPM issue #4651`.

**CI: collapses against three independent constraints.**

1. **Correctness vs the ecosystem no-cache decision.** `Verified:
   swift-institute/Research/ci-cache-strategy-branch-pinned-dependencies.md (v1.1.0)`
   — the ecosystem deliberately runs CI with **no `.build` cache** (Option C,
   Apple/swiftlang-canonical) *because* `branch:"main"` deps cause stale-cache
   correctness failures (a documented incident). A naive
   `hashFiles('Lint.swift')`-keyed eval cache reintroduces exactly that failure
   at a **156-dependency blast radius**: `Verified: 2026-06-24` the eval resolves
   **158 packages, 156 of them `branch:"main"`**, whose floating HEADs are
   invisible to `Lint.swift` (which declares only ~1 top-level rule pack). A
   cached eval would lint against stale rule-pack checkouts.
2. **The hash input does not exist pre-build.** The eval's `Package.resolved` is
   generated *during* first materialization and sits inside the gitignored
   `.swift-lint/` tree (`Verified: git check-ignore`), so the report's
   `hashFiles('…/Package.resolved')` key component is unavailable on a cold
   runner. `Package.resolved` is also permanently gitignored ecosystem-wide
   (`sync-gitignore.sh:47`).
3. **Cache size.** `Verified: 2026-06-24` — each eval `.build` is **1.3–2.6 GB**
   (37 GB across 29 sampled consumers). GitHub Actions caps caches at 10 GB/repo
   with 7-day eviction; matrix-multiplied entries approach the ceiling and evict
   each other.

A **correct** CI eval cache is possible only via the sanctioned Option-B
dep-fingerprint — `git ls-remote` of *every* branch-pinned dep in the
**transitive** eval graph (156 of them) + the engine pin, as an exact-match key
with no `restore-keys`:

```yaml
key: ${{ runner.os }}-lint-eval-${{ env.SWIFT_LINTER_VERSION }}-${{ steps.eval-fp.outputs.fingerprint }}
# fingerprint = sha256( sort("<url>@<branch>=<sha>" for all transitive branch deps)
#                       + "engine=<SWIFT_LINTER_VERSION>" + sha256(Lint.swift) )
# NO restore-keys — exact match or full miss.
```

But while the ecosystem floats on `main`, this key changes on essentially every
upstream commit → **hit rate ≈ 0 during active development** (the very reason
Option C beats Option B today).

**Constraint-fit:** caching is rule-agnostic, so it honors external rule loading
cleanly; but a naive CI eval cache does **not** honor the no-cache correctness
decision. **Verdict: pursue LOCAL warmth (free); do NOT add a CI eval cache as
the primary lever.** A correct CI eval cache is gated on version-pinning rule
packs (ask-principal, below) and even then is marginal until the ecosystem tags.

### Direction 3 — Prebuilt / binary rule packs + ABI-stable rule interface

This direction splits into "SwiftPM binary library" and "dynamic loading," both
**verified infeasible or non-saving on Linux**.

**3a — Engine/rule packs/SwiftSyntax as a SwiftPM `.binaryTarget`: NOT SUPPORTED
on Linux.** `Verified` (SE-0272, SE-0305, SE-0482):
- SE-0272 binary deps = Apple-only XCFramework.
- SE-0305 `.artifactbundle` = **executables only**, not importable libraries.
- SE-0482 (Swift 6.2) = static library binary targets but **C-interface only**;
  shipping a *Swift* library is an explicit, **unimplemented** future direction
  ("we would extend the … manifest to provide a `.swiftinterface`").
- A compiled `.swiftmodule` is toolchain-version-locked; SwiftSyntax ships no
  library-evolution, and on Linux cross-compiler-version linking is "not
  guaranteed to … behave correctly at runtime" (`Verified: swift.org/blog/library-evolution`).

  ⟹ There is **no supported way to ship a non-recompiled Swift engine or
  SwiftSyntax library that a non-macro target imports, on Linux.**

**The official prebuilt SwiftSyntax does not help.** `Verified: SwiftPM 6.3
release notes:57-58` — Apple ships a signed, prebuilt `MacroSupport` SwiftSyntax
bundle (and it *does* ship Linux variants: ubuntu/debian/amazonlinux/rhel,
x86_64+aarch64), but **SwiftPM auto-disables it the moment a non-macro target may
import swift-syntax** ("disabled because mixing of swift-syntax prebuilts and
swift-syntax built from source at link time has caused a number of issues").
External rule loading *requires* non-macro SwiftSyntax imports (rule packs,
`Lint.swift`), so the prebuilt is structurally unreachable. This is confirmed
empirically: `Verified: 2026-06-24` — the prebuilt bundle is downloaded into the
linter's `.build/prebuilts/` yet 76+ SwiftSyntax `.o` files compile from source
on both macOS and Linux.

**3b — Dynamic loading (dlopen Swift `.so` rule plugins): feasible but
non-saving and constraint-hostile.** `Verified` (swiftlang/swift-syntax
`_SwiftLibraryPluginProvider`; forums.swift.org/t/20319; Swift ABI blog):
- It works only **in-process, same-toolchain** (no stable ABI on Linux);
  SwiftSyntax-typed values cannot cross a dylib boundary safely. Swift's own
  macro system avoids this via (a) same-toolchain in-process load
  (`_SwiftLibraryPluginProvider`, which is private `@_spi`) or (b) out-of-process
  JSON with source re-parse (`SwiftCompilerPluginMessageHandling`).
- Building a rule `.so` **still compiles SwiftSyntax** (~155s) unless it links a
  shared SwiftSyntax `.so`, which SwiftPM does not emit and which re-imposes the
  toolchain lock.
- **Inline custom rules cannot be prebuilt** — they are consumer source and must
  compile (the full eval cost) regardless.

**Out-of-process plugin executables** (the ABI-safe variant) are distributable as
executables (SE-0305) and let engine + packs use *different* toolchains, but
still compile SwiftSyntax to build, add IPC + re-parse overhead, and leave inline
rules compiling.

**Verdict on Direction 3 as literally framed (binary/dynamic *libraries*):
reject.** BUT its *intent* — prebuild the rule packs so they are not recompiled
per consumer — is achievable through the supported **executable** artifact path,
which is the heart of the recommendation below (prebuilt rule-pack *runners*, not
binary *libraries*).

### Direction 4 — Resident / daemon linter

**Feasibility: real, but solves a different problem than CI's.** `Verified`
(sourcekit-lsp editor-integration docs; SwiftLint/swift-format have no
daemon/server mode — SwiftLint uses an mtime cache; prior
`lsp-sourcekit-integration.md`).

A daemon avoids *repeated* process-startup, SwiftSyntax-library load, and
rule-registration **across many files in one warm session** — it does **not**
avoid the one-time ~335s cold compile, which is its precondition.

- **CI: no help.** Ephemeral runners have no persistent process; each consumer is
  linted **once** per run (and the institute has no monorepos, so no
  many-packages-in-one-job amortization). The first invocation pays full cold
  cost; there is no second invocation to amortize.
- **Local: shines, but over an already-cheap baseline.** It must beat the free
  ~10–40s `.build` reuse. Its marginal win (sub-second per-save editor linting)
  is real but narrow, and its thin form is simply running the already-compiled
  eval executable in a `--watch`/serve loop — no bespoke daemon needed.

**Verdict: defer. Future local/editor DX, orthogonal to the CI cold-start
problem this brief exists to solve.** (An LSP front-end is already sketched as
`swift-institute-lsp` in `lsp-sourcekit-integration.md`, gated on explicit
authorization.)

### Direction 5 — Hybrid end-state

The recommendation (next section) is a hybrid: Direction 1 (URL dep) + prebuilt
CLI + the *executable* realization of Direction 3's intent (prebuilt rule-pack
runners) + Direction 4 deferred to local DX, with Direction 2 confined to local.

## Outcome

**Status: RECOMMENDATION.**

### Recommended architecture

Apply the reconciliation principle through a four-phase path. Phases 0–1 are
unconditional and low-risk; Phase 2 is free local DX; Phase 3 is the structural
end-state and carries the one design-change decision for the principal.

#### Phase 0 — Engine as a versioned SwiftPM dependency *(precursor; unlocks the binary)*

Change `Lint.File.Single` eval generation to reference the engine via
`.package(url: <pinned swift-linter release>, products:["Linter"])`, keeping
`.path(SWIFT_LINTER_PATH)` only as the local-dev fallback. Tag swift-linter
releases. No consumer-facing change. **No latency change** — this is the enabler
for Phase 1 and for stable eval resolution.

#### Phase 1 — Prebuilt CLI binary *(removes the ~270s engine build; everyone benefits)*

Ship the `swift-linter` CLI as a Linux amd64 release binary (executables **are**
distributable via SE-0305 artifactbundle / GitHub Release — `Verified`). The CI
`swift-linter` job installs the cached, `sha256`-pinned binary (mirroring the
existing SwiftLint job per [CI-082]) with a source-build fallback during
rollout. Requires Phase 0 (the binary has no engine source tree, so the eval must
reference the engine by URL). Build with `--static-swift-stdlib` (glibc+libuuid
stay dynamic per [CI-092]) per the prior synthesis §1.

**This is the easy, safe, correctness-neutral win.** It does **not** touch the
eval — the eval still compiles the engine library + SwiftSyntax + rule packs.

#### Phase 2 — Local warm-run DX *(free; optional `--watch`)*

Document and rely on the persisted eval `.build` for local warmth (~10–40s).
Optionally add a `--watch`/serve mode on the eval executable for editor-grade
per-save linting (this is the "daemon" in its thin, warranted form). **Local
only; no CI effect.**

#### Phase 3 — Prebuilt rule-pack runner artifacts *(the reconciliation; near-instant CI for 77/78 consumers)*

**This is the structural answer to near-instant runs.** Publish, per pinned
toolchain (swift:6.3, swift:6.4-dev) and platform, prebuilt **executable** runner
artifacts containing the engine + SwiftSyntax + the standard rule packs
(compiled once, in swift-linter's own release CI — not per consumer). The CLI,
given a consumer's `Lint.swift`:

1. parses it (it already does, for dep extraction);
2. if the consumer uses **only standard packs + a bundle + enable/disable of
   known rule IDs, with no inline rules and no non-standard packs** (77/78
   consumers), routes to the matching prebuilt runner, passing the
   enable/disable selection as **runtime config** — **no per-consumer compile**;
3. otherwise (inline rules / custom packs — carrier-primitives today) falls back
   to the existing eval-materialize-compile-run path.

Because executables are the one binary form SwiftPM distributes on Linux, and
because the runner's rules are selected at runtime by ID, this delivers
near-instant CI for the pure-bundle majority **without baking a fixed rule set
into the linter**: selection stays in `Lint.swift`, and custom authoring keeps
the compile path. Toolchain-locking (Agent-verified) is absorbed by building one
runner set per pinned toolchain in swift-linter's release CI — a once-per-release
cost, not a per-consumer one.

**Realization variants** (the design-change decision — see ask-principal):
- *(3-i) One combined "standard" runner* — engine + all standard packs in one
  binary; `Lint.swift` bundle/enable/disable becomes runtime config. Simplest;
  closest to the constraint line (full standard catalog in one binary, but
  dynamically selected + custom still via fallback).
- *(3-ii) Per-bundle runners* — one runner per published bundle
  (`primitives`, `institute`); CLI selects/combines. More modular; matches the
  external-pack mental model more literally; mild combinatorics for
  multi-bundle consumers.

For the **inline-rule minority** (carrier-primitives), Phase 3 offers no compile
saving (SwiftSyntax-from-source is unavoidable for consumer-authored rule code);
options are (a) keep the eval path, (b) the gated Option-B eval cache from
Direction 2, or (c) promote the inline rule into a published rule pack (then it
joins the prebuilt-runner fast path). Option (c) aligns with the ecosystem's own
modularization preference and would bring carrier onto the fast path too — a
separate, small call.

### Realistic warm-run latency per phase (Linux CI, per consumer)

| State | Pure-bundle consumer (77/78) | Inline-rule consumer (carrier) | Local (any) |
|---|---|---|---|
| **Today** | ~605s | ~605s | cold ~605s · warm ~10–40s |
| **+ Phase 1** (prebuilt CLI) | ~335s (eval only) | ~335s | cold ~335s · warm ~10–40s |
| **+ Phase 2** (`--watch`) | ~335s CI | ~335s CI | warm → sub-second per save |
| **+ Phase 3** (prebuilt runner) | **~0.65s warm** (cached runner exec + AST walk; ~310–560s one-time prebuild on cache miss) | ~335s eval fallback *(or ~20–60s if Phase-3a eval cache + version-pinning)* | unchanged |

`Verified` numbers: SwiftSyntax-from-source 154.52s (Linux); eval 335s, engine
270s (handoff, same-day Linux CI); local warm 10–40s (reasoned from persisted
`.build` + single-target recompile); eval `.build` 1.3–2.6 GB; eval graph 158
pkgs/156 branch.

**Phase-3 figure now MEASURED (`Verified: 2026-06-25`, replacing the prior
`~5–30s` estimate).** A debug full-bake runner (engine + SwiftSyntax + the
standard primitives rule packs) was built and timed on Linux (`swift:6.3`,
aarch64, debug, `-j 2`):

- **Warm lint of carrier (48 files): ~0.58–0.65s** on container-local disk
  (5-run median ~0.57s; the runner walks the package + applies the baked
  `Lint.Rule.Bundle.primitives` with no recompile). An initial reading of
  ~1.1s was traced to Docker gRPC-fuse `:ro` mount cold-cache overhead, not the
  runner; native CI disk lands at ~0.65s. This is **~500–900× faster** than the
  ~335–605s eval and **~10× better** than the doc's prior estimate.
- **One-time prebuild: ~310–560s** (environment-sensitive: 309.96s on the
  original spike, 555.69s on the 2026-06-25 reproduction; the spread is fuse
  I/O + host load + the from-source SwiftSyntax floor). It is paid ONCE per
  composite-cache-key value **per consumer repo**: GitHub Actions caches are
  repo-scoped, so a keyed-HEAD change triggers one runner rebuild on EACH active
  consumer repo's next CI run (verified 2026-06-25 — pair-primitives and
  ordinal-primitives each rebuilt their own runner, ~360s/~464s), NOT one
  ecosystem-wide rebuild; the runner is warm within that repo thereafter. Cost
  model under A-dynamic: ≈ N(active repos) × one rebuild per keyed change,
  parallel across repos — input to the A-pinned trade-off (pinning lowers key
  churn frequency). Matches the existing per-repo Phase-1 dispatcher cache.
- **Functionally verified:** the runner caught `[PRIM-FOUND-001]` on a known
  `import Foundation` violation (26ms) and fires the 7 `int public parameter`
  findings on carrier's `Fixture` conformers that carrier's own config excludes
  — proving the runner is not a silent no-op and concretely showing why
  excludes-bearing consumers need the runtime-selection overlay (below).

**Debug, not release (`Verified: 2026-06-25`, `swiftlang/swift#89617`).** The
runner ships **debug** because the A13/#89617 SIL crash (`FunctionSignatureOpts`)
is `-O`/release-only — debug is clean, so the multi-package SIL-crash fix-wave is
**NOT a Phase-3 prerequisite**; it is parked as a separate release-only arc.
Runtime is already sub-second in debug, so release only shrinks the binary (a
debug runner is ~134 MB — which also rules out orphan-branch central hosting and
selects the per-consumer [CI-044] cache).

### Phase 3 — implemented (2026-06-25): the "A-dynamic" standard runner

The Phase-3 fast path is built (debug, behind an opt-in env var; HOLDING for the
principal's rebuild-cadence ratification before the CI change goes live). Three
pieces:

1. **The runner** — a nested SwiftPM package `Runner/` in the swift-linter repo
   (`Runner/Package.swift` + `Sources/runner/main.swift`) whose 10-line body is
   `Lint.run(bundle: Lint.Rule.Bundle.primitives)`. It bakes the engine +
   SwiftSyntax + the standard primitives rule packs once; the compiled `runner`
   binary reads a target directory from argv and lints it warm.

2. **CLI routing** — `Lint.File.Single.Classifier.classify(source:)` (Linter
   Core, purely syntactic, **failure-safe**) returns `.fastPathStandardBundle`
   IFF the consumer declares no `// parent:` chain AND its `Lint.run(...)` rule
   closure is exactly the single bare expression `Lint.Rule.Bundle.primitives`.
   `Lint.File.Single.dispatch` takes the fast path (execs the runner via
   `Process.Spawn`) only when `SWIFT_LINTER_RUNNER` names a provisioned binary
   AND the classifier says so; otherwise it falls through to the unchanged eval
   pipeline. **External, consumer-declared rule loading is preserved on BOTH
   paths**: the runner bundles the published standard rule packs, and inline/
   custom-rule consumers compile their declared packs in the eval exactly as
   before. Default behaviour is unchanged (unset `SWIFT_LINTER_RUNNER` ⇒ eval).

3. **The A-dynamic composite cache key** — `swift-ci.yml`'s `swift-linter` job
   caches the runner binary ([CI-044] tool-binary carve-out: a single binary,
   **no `.build` cache** so [CI-040] holds, **exact-match with no
   `restore-keys`** per [CI-042]). The key is a `sha256` COMPOSITE over the
   engine `main` HEAD (which carries `Runner/`) **and** the `main` HEADs of the
   standard rule-source repos — `swift-primitives-linter-rules`,
   `swift-institute-linter-rules`, `swift-linter-rules`, `swift-linter-primitives`.
   Effect: **rules always equal latest-committed `main`** (no tag, no version
   pin — the `branch:"main"` convention is preserved, so the deferred pinning
   decision is NOT tripped); a commit to the engine or any keyed rule pack busts
   the key → one shared ~310–560s rebuild → instant ~0.65s warm thereafter.

   *Composite-key scope (a deliberate correctness-vs-hit-rate knob):* only the
   engine + the four rule-source repos are keyed, NOT the ~150 transitive
   primitive support libraries the rule packs pull. Those do not define rules,
   and keying them would reintroduce the ≈0 warm-hit-rate the no-cache decision
   exists to avoid (Direction 2). A rule whose *behaviour* changes because an
   underlying primitive changed (rare) would not bust the key until the rule
   pack itself is re-committed. Surfaced for principal awareness.

**Coverage (verified census 2026-06-25, classifier-accurate).** Of 77 consumer
`Lint.swift` files: **63** activate bare `Lint.Rule.Bundle.primitives` and **8**
activate `Bundle.primitives.excluding(rules:)`. With the v1.1 selection overlay
(below) BOTH route to the fast path → **71/77 (92%)**. The remaining 6 take the
eval fallback: **5 bare-`institute`/`universal`** (a different baked bundle than
the primitives runner — would over-report, so they fall back) and **1 inline-
rule** consumer (carrier). 0 consumers use `// parent:`. The classifier is
correct for all 77 (every fallback still lints via the unchanged eval path).
The 5 non-primitives bare consumers would need the overlay generalized to any
bundle, or per-bundle runners (variant 3-ii).

**Runtime-selection overlay — v1.1, BUILT (`Verified: 2026-06-25`; on branch,
unpushed, holding for principal ratification).** Brings the 8 excludes-only
consumers onto the fast path (63 → 71/77). The CLI classifier extracts each
consumer's `.excluding(rules: [...])` IDs — both forms: bare string literals
(`"raw value access"`) and typed `.id` accessors (`Lint.Rule.`raw value access`.id`,
whose backtick name == its `id:` string, verified 97/97 across the rule packs) —
into a `Lint.Manifest`, written to `.swift-lint/selection-manifest.json` and
passed to the runner via `SWIFT_LINTER_SELECTION_MANIFEST`. The runner's
`Lint.run(bundle:)` overlays it on its baked registry via the **existing**
`Lint.Configuration.lift(manifest:registry:inheriting:)` (the same mechanism the
`// parent:` chain uses), linting `Bundle.primitives` MINUS the consumer's
exclusions. **Correctness gate (the whole risk):** extraction is exact or the
consumer drops to the eval fallback — a single unreadable array element fails
the *entire* extraction (`bakedBundleExclusions` returns `nil`), so a dropped
exclusion can never silently fire an excluded rule. Covered by per-form unit
tests (exact disabled-set assertions; mis-extraction fails the test) plus an
unreadable-element → fallback test. Default behaviour unchanged for the 63 bare
consumers (no selection env var ⇒ full baked bundle).

### What each sub-question resolves to

- **What unlocks the binary:** Phase 0 (engine as URL dep). Without it a prebuilt
  CLI cannot dispatch the eval.
- **What the eval cache needs:** version-pinned rule packs **and** a transitive
  Option-B dep-fingerprint key; even then it is marginal during active dev and
  fights the no-cache decision + 10 GB limit. **Recommend NOT pursuing CI eval
  caching as primary; prefer prebuilt runners. Keep eval caching local.**
- **Is rule-pack prebuilding warranted:** **Yes** — as prebuilt *executable
  runners* (not binary libraries, which Linux does not support). It is the only
  supported path to near-instant CI for the 98.7% pure-bundle majority and is the
  reconciliation's core.
- **Is daemonization warranted:** **No for CI** (ephemeral, single invocation);
  **future local/editor DX** only.

### Constraint-fit summary

| Direction | Near-instant? | Retains external rule loading? | Linux-feasible (supported)? |
|---|---|---|---|
| 1 URL engine dep | no (enabler) | yes | yes |
| 2 eval cache — local | yes (~10–40s) | yes (rule-agnostic) | yes (free) |
| 2 eval cache — CI | marginal | yes | gated (version-pin + Option-B; ≈0 hit rate now) |
| 3a binary engine/SwiftSyntax lib | n/a | n/a | **no** (no Swift binary lib on Linux) |
| 3b dlopen rule plugins | no (still compiles) | partial (breaks inline) | fragile (`@_spi`, same-toolchain) |
| **3 prebuilt runner executables** | **yes (77/78)** | **yes (selection in Lint.swift; custom via fallback)** | **yes (executables distributable)** |
| 4 daemon — CI | no | yes | n/a |
| 4 daemon — local | yes (sub-second) | yes | yes (defer) |

### Ask-principal items

1. **Rebuild cadence — A-dynamic (default) vs A-pinned.** The implemented design
   is **A-dynamic**: the runner's [CI-044] cache key is a composite over the
   engine + standard-rule-pack `main` HEADs, so rules always track latest
   `main` and a rule-pack commit triggers one shared ~310–560s rebuild. This
   **preserves `branch:"main"`** (no pinning, so the deferred convention is not
   reversed). The alternative, **A-pinned**, pins rule-pack versions to collapse
   the key to one stable coordinate (higher warm-hit rate, but reverses the
   `branch:"main"` convention and changes what consumers write in `Lint.swift`).
   *This is the standing HOLD:* the build ships A-dynamic; switching to A-pinned
   is the principal's call, informed by rule-pack commit frequency / warm-hit
   telemetry. Variant **3-i (one combined runner)** is the implemented choice.
2. **Runtime-selection overlay (v1.1) — BUILT, on branch, unpushed.** Broadens
   the fast path from the 63 bare-bundle consumers to the 8 excludes-only
   consumers (→ 71/77) via the existing `Lint.Manifest` + `lift`/`inheriting:`
   machinery (see Phase-3-implemented §). Failure-safe; exact extraction or eval
   fallback. Verified end-to-end (bare carrier = 7 `int public parameter`
   findings; overlay disabling it = 0; a different rule still fires). Ratify to
   push (it bumps the engine HEAD → the composite key busts → the runner
   rebuilds once with the overlay-aware `run(bundle:)`, then warm).
3. **carrier-primitives' inline rule** — keep on the eval path, or promote to a
   published pack so it joins the fast path? (Recommended: promote; small,
   aligns with modularization. Until then carrier correctly takes the eval
   fallback — the classifier routes it there.)

### Risks

- **Toolchain-locking** of prebuilt runners (rebuild per Swift toolchain; matrix
  is swift:6.3 + 6.4-dev) — absorbed by swift-linter release CI, once per release.
- **glibc floor** for the static-stdlib binaries (build on swift:6.3 Jammy) —
  document; runners must not be consumed under an older image.
- **`uuid-dev` runtime dep persists** ([CI-092]).
- **Phase-3 recognition logic** (deciding fast-path vs fallback from `Lint.swift`)
  must be conservative: any unrecognized pack / inline rule → eval fallback, so
  correctness never depends on the fast path.

## References

### Verified primary sources (external)

- SE-0272 SwiftPM binary dependencies (Apple-only XCFramework) — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0272-swiftpm-binary-dependencies.md
- SE-0305 artifactbundle (executables only) — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0305-swiftpm-binary-target-improvements.md
- SE-0482 static library binary target, non-Apple (C-only; Swift = unimplemented future direction; Swift 6.2) — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0482-swiftpm-static-library-binary-target-non-apple-platforms.md
- SwiftPM 6.3 release notes (prebuilt swift-syntax auto-disabled for non-macro targets) — https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/ReleaseNotes/6.3.md (lines 52-58)
- SwiftPM prebuilts source `Workspace+Prebuilts.swift` / `BuildPrebuilts.swift` ("only supports swift-syntax for macros"; `MacroSupport`; versions 600/601/602) — https://github.com/swiftlang/swift-package-manager
- Prebuilt swift-syntax manifest (Linux x86_64+aarch64 variants) — https://download.swift.org/prebuilts/swift-syntax/601.0.1/6.1-manifest.json
- Swift Forums "Swift-Syntax Prebuilts for Macros" (scope, opt-in, rationale) — https://forums.swift.org/t/preview-swift-syntax-prebuilts-for-macros/80202
- Swift ABI stability (Apple platforms only; Linux unevaluated) — https://www.swift.org/blog/abi-stability-and-more/
- Library Evolution (`.swiftmodule` not stable cross-version; Linux cross-version linking not guaranteed) — https://www.swift.org/blog/library-evolution/ ; https://forums.swift.org/t/update-on-module-stability-and-module-interface-files/23337
- Swift shared libraries as plugins (`@_cdecl`/`@convention(c)` only across dlopen) — https://forums.swift.org/t/swift-shared-libraries-as-plugins/20319
- swiftlang/swift-syntax `_SwiftLibraryPluginProvider` (dlopen + `_typeByName`; `@_spi`) and `SwiftCompilerPlugin` / `StandardIOMessageConnection` (out-of-process JSON) — https://github.com/swiftlang/swift-syntax
- sourcekit-lsp editor integration (resident process; no background build) — https://github.com/swiftlang/sourcekit-lsp/blob/main/Documentation/Editor%20Integration.md
- SwiftLint commands (no daemon; mtime cache) — https://github.com/realm/SwiftLint ; swift-format (no daemon; provides SourceKit-LSP formatting) — https://github.com/swiftlang/swift-format
- GitHub Actions cache limits (10 GB/repo, LRU, 7-day) — https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows
- swiftlang/swift-llbuild `FileInfo.h` (stat-based change detection) — https://github.com/swiftlang/swift-llbuild ; SwiftPM issue #4651 (atomic-write inode churn → rebuild)

### Verified local sources

- `swift-foundations/swift-linter/Sources/Linter Core/Lint.File.Single.swift:227-336` (dispatch; engine `.path` dep at :283-288)
- `swift-foundations/swift-manifests/Sources/Manifest Executable/Manifest.Executable.swift:68-95` and `…/Manifest.Executable.Materializer.swift` (eval render + `swift run`; "always overwrites")
- `swift-foundations/swift-linter/Package.swift`; `swift-primitives/swift-linter-primitives/Package.swift:31,44`; `swift-foundations/swift-institute-linter-rules/Package.swift` (SwiftSyntax pulled by engine + every rule pack)
- `swift-primitives/swift-carrier-primitives/Lint.swift` (the 1/78 inline-rule consumer)
- `swift-institute/Research/ci-cache-strategy-branch-pinned-dependencies.md` (v1.1.0 — no-cache decision; Option B; gitignored Package.resolved)
- `swift-foundations/swift-linter/Research/2026-05-07-phase-b1-decouple.md` (engine ships zero rules; ~234s/308s build corroboration)
- `swift-foundations/swift-linter/Research/2026-05-12-swift-linter-unified-consumer-manifest.md` (Shape-γ two-phase eval, Tier 3)
- `swift-foundations/swift-linter/Research/lsp-sourcekit-integration.md` (resident/LSP prior art; `swift-institute-lsp` concept)
- `.handoffs/REPORT-swift-linter-binary-product-synthesis.md` (prior binary-product synthesis; this doc supersedes its §4 eval-cache recommendation)

### Empirical measurements (this doc, 2026-06-24)

- SwiftSyntax-from-source: **154.52s** Linux (`swift:6.3` Docker), 161s macOS — minimal non-macro `SwiftSyntax`/`SwiftParser`/`SwiftOperators` consumer; prebuilt downloaded but 76 `.o` files compiled from source (prebuilt disabled for non-macro). Scratch probe packages.
- Consumer census: 78 `Lint.swift`; 77 pure-bundle; 1 inline-rule (carrier).
- Eval graph: 158 packages, 156 `branch:"main"` (sampled eval `Package.resolved`); eval `.build` 1.3–2.6 GB each.
