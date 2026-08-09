# Owner Capability Matrix

**Gate:** 0A — pre-project repository and capability audit
**Date:** 2026-07-24
**Governing documents:** `WHY_WORKSPACE_EXISTS.md` (constitution), `WORKSPACE_LOCAL_RESOLUTION_IMPLEMENTATION_PLAN.md` (protocol)
**Path convention:** this repository is public; machine-specific path prefixes are rendered as `<developer-root>` deliberately (redacted 2026-07-26, per ADR-001).

> **Terminology correction (2026-07-27):** Workspace is process/application
> tooling above the three realised package layers, not part of a realised fourth
> or fifth package layer. The ownership conclusions in this matrix are unchanged.

**Method — two distinct passes, do not conflate them:**

| Pass | Date | What was done | What it can support |
|---|---|---|---|
| **A — initial read-only audit** | 2026-07-24 | Direct source inspection at the revisions recorded in `Repository Safety Inspection.md` §§1–4. **No build, test, or resolution command was executed.** | What a declaration *is*, where it lives, who owns it, what is absent |
| **B — coordinator-backed correction baseline** | 2026-07-24, 12:24–12:43 UTC | `swift-build package build` and `package test` executed against **nine** owner packages through the machine-wide coordinator. See §0.3 and `Baseline Build and Test Evidence.md`. | Whether a named test **ran and passed** |

Pass A establishes every *semantic* finding below. Pass B establishes every
`✓B` status marker. A row with no `✓B` has **not** been validated by execution.

---

## 0. How to read this document

`Status` uses only the allowed values: *implemented and tested*, *implemented
without adequate tests*, *partial*, *documented only*, *absent*, *ownership
conflict*, *unresolved*.

`Candidate owner-level action` uses only: *no change*, *extend existing owner*,
*replace Workspace-local use*, *investigate in empirical spike*, *architectural
adjudication required*. **It is a classification, not a design authorisation.**

A capability is recorded as existing only when a declaration was read. README
prose describing an intended capability is recorded as *documented only*.

Evidence is cited as `module › file:line › declaration` at the stated revision.

### 0.1 Owner locations, established by inspection

| Package | Layer or role | Established location | Revision |
|---|---:|---|---|
| `Workspace/Application` | process/tooling | `swift-institute/Workspace/Application` | read at `2c6787d47`+12 uncommitted; **committed mid-audit as `ef0579a8b`**, content verified identical |
| `swift-package-manager` | 3 | `swift-foundations/swift-package-manager` | `d3dd30904` |
| `swift-package-graph` | 3 | `swift-foundations/swift-package-graph` | `a76186a9b` (dirty) |
| `swift-xcode` | 3 | `swift-foundations/swift-xcode` | `83b6627d9` |
| `swift-git` | 3 | `swift-foundations/swift-git` | `a9955a9d9` |
| `swift-impact` | 3 | `swift-foundations/swift-impact` | `41e95a126` |
| `swift-manifests` | 3 | `swift-foundations/swift-manifests` | `5078007de` |
| `swift-file-system` | 3 | `swift-foundations/swift-file-system` | `bde096613` |
| `swift-paths` | 3 | `swift-foundations/swift-paths` | `f20b5315f` |
| `swift-process` | 3 | `swift-foundations/swift-process` | `c7b15b0d9` |
| `swift-json` | 3 | `swift-foundations/swift-json` | `c0d4a4b2e` |
| `swift-xml` | 3 | `swift-foundations/swift-xml` | `14e3776be` |
| `swift-spm-standard` | 2 | **`swift-standards/swift-spm-standard`** | `56f326cc5` |
| `swift-git-standard` | 2 | **`swift-standards/swift-git-standard`** | `ed8b3796c` |
| `swift-xcode-standard` | 2 (provisional) | `swift-standards/swift-xcode-standard` | `d336477d2` |
| `swift-github-standard` | 2 | `swift-standards/swift-github-standard` | `562fe2e05` |
| `swift-package-primitives` | 1 | `swift-primitives/swift-package-primitives` | `ac4cff34b` |
| `swift-graph-primitives` | 1 | `swift-primitives/swift-graph-primitives` | `ca5b9d699` |

`swift-spm-standard` and `swift-git-standard` are owned by **`swift-standards`**,
not by a per-authority sub-organization. `Workspace/ARCHITECTURE.md` describes
`swift-github-standard` as "2 planned"; it exists at `562fe2e05` with eight
targets, so that line of the architecture document is **stale**.

### 0.2 Test-surface baseline

Counted `@Test` attributes under each `Tests/` tree at the recorded revision.

| Package | Test files | `@Test` count |
|---|---:|---:|
| `swift-spm-standard` | 8 | 55 |
| `swift-package-graph` | 2 | 21 |
| `swift-git-standard` | 3 | 6 |
| `swift-git` | 1 | 3 |
| `swift-xcode` | 2 | 2 |
| `swift-xcode-standard` | 2 | 2 |
| `swift-package-manager` | 1 (+ nested `Fixture` package) | 1 |

> **Superseded — 2026-07-24, correction slice.** This table counts `@Test`
> attributes. **Counting attributes proves tests exist, not that they pass.** It is
> retained as the original record and is no longer the basis of any status in this
> document. Statuses now rest on the executed baseline in §0.3.

### 0.3 Executed baseline — what `implemented and tested` now means

Statuses were re-derived from an executed build and test baseline. Full evidence:
`Baseline Build and Test Evidence.md`.

**Label — `current machine resolution baseline`.** Every result was produced with
an active SwiftPM mirror configuration over warm `.build` directories. It is not
canonical-URL, remote-only, clean-consumer, or release-readiness validation, and
not clean-room compilation evidence.

**Command form** (the only two issued, per package):

```
<developer-root>/swift-institute/Scripts/swift-build package build --package-path <abs>
<developer-root>/swift-institute/Scripts/swift-build package test  --package-path <abs>
```

**Scope.** The correction baseline was reduced to nine decision-driving owner packages; all claims based on omitted packages were downgraded to `unresolved`.
All nine passed: build exit 0 and test exit 0, **142 tests, zero failures, zero
compiler warnings**.

| Package | Revision | Build | Test | Tests |
|---|---|---|---|---:|
| `Workspace/Application` | `ef0579a8b` | 0 / 127s | 0 / 41s | 27 |
| `swift-package-manager` | `d3dd30904` | 0 / 122s | 0 / 21s | 1 |
| `swift-spm-standard` | `56f326cc5` | 0 / 64s | 0 / 10s | 55 |
| `swift-package-graph` | `a76186a9b` + migration `31347669…` | 0 / 196s | 0 / 29s | 21 |
| `swift-git` | `a9955a9d9` | 0 / 48s | 0 / 11s | 3 |
| `swift-git-standard` | `ed8b3796c` | 0 / 1s | 0 / 1s | 6 |
| `swift-xcode` | `83b6627d9` | 0 / 74s | 0 / 16s | 2 |
| `swift-xcode-standard` | `d336477d2` | 0 / 2s | 0 / 1s | 2 |
| `swift-impact` | `41e95a126` | 0 / 30s | 0 / 28s | 25 |

**Status markers used below.**

| Marker | Meaning |
|---|---|
| `implemented and tested ✓B` | A named test exercising this capability **ran and passed** under the baseline command above. Citation in §0.4. |
| `implemented and tested ✓B*` | Same, except the **declaring** package was not itself baselined; the behaviour is covered by a passing test in a package that was. |
| `implemented without adequate tests ✓B` | The suite passed, but inspection of the passing tests shows this capability is not adequately covered. **Two rows were downgraded this way by baseline evidence** — see §0.4.1. |
| `unresolved` | Test declarations exist, but **no baseline was executed for that package**. Scope reduction, not a defect. |

**Fifteen packages were not baselined**, on the stated grounds that their matrix
rows carry `no change / no gap` dispositions and that no Gate 0A decision turns on
their build state.

> **Provenance of the scope reduction.** The reduction was directed by an instruction
> received in this working session, headed *"Principal ruling — Gate 0A baseline scope
> reduced from 23 to 8 packages"*, which enumerated the nine packages to baseline and
> prescribed the `unresolved` disposition and its exact wording for the remainder. That
> instruction's authority is **not independently verifiable from the relayed supervisory
> record**, so this document does not assert it as a principal ruling. It records the
> reduction as a scope decision taken on instruction, and the evidence stands on its own
> terms regardless of provenance. Eleven rows resting on them are now `unresolved`. The
list is in `Baseline Build and Test Evidence.md` §7 and in §0.5 below.

### 0.4 Baseline test citations

Each `✓B` row, the exact test declaration that covers it, and the command under
which it passed. All ran under
`swift-build package test --package-path <package>`; test names are quoted
verbatim from the passing run.

| Row (§) | Package | Exact passing test declaration |
|---|---|---|
| Package display name (§2) ✓B* | `swift-spm-standard` | *"Package.Manifest stores name, toolsVersion, dependencies"*; *"Package.Manifest minimal round-trips through JSON"* |
| Dependency requirement (§2) | `swift-spm-standard` | *"Package.Requirement.from round-trips through JSON"*; *".exact"*; *".range"*; *".branch"*; *".revision"* (five declarations) |
| Manifest dump representation (§2) | `swift-spm-standard` | *"Package.Manifest decodes a full dump-package output (products + targets + platforms)"*; *"Package.Manifest decode populates Dependency.products from target edges"*; *"swift package dump-package output decodes via Package.Manifest Codable"* |
| Node and edge representations (§4) | `swift-package-graph` | *"Empty graph: structural queries return empty results"*; *"Single package, no deps"* |
| Direct dependants (§4) | `swift-package-graph` | *"Linear chain A→B→C: reverse-dep queries"* (`Package.Graph.Tests.swift:73–75`); *"Diamond A→B, A→C, B→D, C→D: D's dependents collapse to wave 2"* (`:116`) |
| Transitive dependant closure (§4) | `swift-package-graph` | *"Linear chain A→B→C: reverse-dep queries"* (`:78–83`); *"Depth limit truncates wave list"* (`:143–150`) |
| Cycles (§4) | `swift-package-graph` | *"Cycles: two-node cycle is reported"*; *"Cycles: self-loop is reported"*; *"Cycles: acyclic graph returns empty"* |
| Strongly connected components (§4) | `swift-package-graph` | *"SCC: linear chain yields singleton components"*; *"SCC: two-cycle yields one component"* |
| Topological ordering (§4) | `swift-package-graph` | *"Topological order: linear chain returns dependencies first"*; *"…diamond honors dependency precedence"*; *"…cycle throws cycleDetected"* |
| Workspace discovery (§4) | `swift-package-graph` | *"minimal workspace yields one manifest"*; *"chain workspace yields three manifests with correct adjacency"*; *"diamond workspace yields four manifests, no cycles"*; *"nonexistent root throws .rootDoesNotExist"*; *"empty workspace throws .noPackagesFound"* |
| Affected-package calculation (§4) | `swift-impact` | *"clean dependent build classifies as passed"*; *"dependent build with planted compile error classifies as classA"*; *"baseline=.git: pre-existing failure classifies as classB"*; *"execute throws mirrorsNotConfigured when a URL dependency has no mirror"*; *"execute succeeds when a URL dependency has a mirror inside the workspace"* |
| Refs and branches (§5) | `swift-git-standard` | *"qualified reference is accepted"*; *"invalid reference is rejected"*; *"remote record is parsed"*; *"malformed record is rejected"* |
| Revisions and object identifiers (§5) | `swift-git-standard` | *"remote record is parsed"*; *"truncated entry is rejected"* |
| Working-tree status (§5) | `swift-git-standard` | *"ordinary and renamed entries are parsed without path decoding"* |
| `dump-package` operation (§3) | `swift-package-manager` | *"manifest invokes SwiftPM and decodes the standard model"* — the package's **only** test |
| Repository inventory (§8) | `Workspace/Application` | *"Render is byte-identical for schema version one"*; *"Render rejects unsupported schema duplicate names and noncanonical URLs"* |
| Eligibility and exclusion (§8) | `Workspace/Application` | *"Institute policy has the exact public organization roster and excludes meta"*; *"Discovery traverses pages and records every eligibility reason"* |
| Repository discovery (§8) | `Workspace/Application` | *"Discovery traverses pages and records every eligibility reason"*; *"Shuffled repository pages produce byte-identical merged inventory"*; *"Cancellation is not erased into a client failure"* |
| Planning and dry-run values (§8) | `Workspace/Application` | *"sync dry run selects nonmutating execution"*; *"Dry run preserves the existing inventory and successful run atomically replaces it"* |
| Synchronization operations (§8) | `Workspace/Application` | *"Dry run changes neither repository metadata nor files"*; *"Force pushed remote leaves local repository untouched"*; *"Proven descendant fast forwards local main"* |
| Safety diagnostics (§8) — **downgraded, see §0.4.2** | `Workspace/Application` | *"doctor selects diagnostic execution"*; *"doctor rejects dry run"* — these cover **CLI dispatch only**, not the diagnostic checks |
| Reporting and deterministic rendering (§8) | `Workspace/Application` | *"Render is byte-identical for schema version one"*; *"Content failure leaves the existing inventory byte-for-byte unchanged"*; *"Publication rejects an intervening byte change without replacing it"* |
| Xcode composition — reference rendering (§8) | `Workspace/Application` | *"render uses relative application and package references"* |
| Xcode composition — writing / current-state (§8) — **split, see §0.4.2** | `Workspace/Application` | **none** — no test exercises `write(_:at:)` or `current(_:at:)` |
| Layer model (§8) | `Workspace/Application` | *"Merge preserves exact-key annotations and sorts layer owner name"*; *"Owner change is an explicit transfer with annotation and default layers"* |
| Workspace representation / generation / references / atomic install (§6) | `swift-xcode`, `swift-xcode-standard` | *"workspace serialization uses XML escaping"*; *"workspace models observed locations"*; *"scheme serialization contains typed build and test entries"*; *"scheme models build and test references"* — four tests total across both packages; these rows remain `implemented without adequate tests` |

#### 0.4.1 Two rows downgraded by baseline evidence

The baseline did what counting `@Test` attributes could not: it exposed two
capabilities whose passing suite does not actually cover them.

| Row | Was | Now | Proof |
|---|---|---|---|
| Direct dependencies (§4) | implemented and tested | **implemented without adequate tests** | `directDependencies(of:)` is asserted **only at degenerate cases**: `.isEmpty` on an empty graph (`Package.Graph.Tests.swift:24`) and on a single dependency-free package (`:39`). No positive assertion on a non-trivial graph. |
| Transitive dependency closure (§4) | implemented and tested | **implemented without adequate tests** | `transitiveDependencies(of:)` appears in **no test** in the passing suite — zero occurrences across `Tests/Package Graph Tests/`. |

Both are in the *dependency* direction. The *dependants* direction — which
`swift-impact` consumes — is well covered. The direction this project needs for
local-closure selection is the untested one.

### 0.5 Rows downgraded to `unresolved` by scope reduction

Eleven rows, all in §7 Supporting foundations, whose evidence lives in a package
outside the nine-package baseline:

| Row | Package |
|---|---|
| Typed paths | `swift-paths` |
| Directory inspection | `swift-file-system` |
| Atomic writes | `swift-file-system` |
| Temporary sibling creation | `swift-file-system` |
| Process execution | `swift-process` |
| stdout / stderr / exit status | `swift-process` |
| JSON encoding and decoding | `swift-json` |
| XML composition and serialization | `swift-xml` |
| Command schema, parsing, help | `swift-arguments` |
| Process environment access | `swift-environment` |
| GitHub operations | `swift-github`, `swift-github-http`, `swift-github-standard` |

Their **semantic** capability findings — what exists, what is missing, who owns it
— are unchanged and were established by source inspection. Only the *tested*
claim is withdrawn.

---

## 1. Pre-existing machine state that governs every capability finding

Three facts were established from generated state on disk. They are not opinions
about the plan; they are constraints any capability assessment must be read
against.

### 1.1 A machine-wide SwiftPM mirror map is the ecosystem's active substitution layer

`~/.swiftpm/configuration/mirrors.json` — **1,256 entries** (≈628 unique
originals, each spelled with and without `.git`) mapping canonical GitHub URLs to
local directories under `<developer-root>/<org>/<repo>`.

- Mirror targets by directory: `swift-primitives` 410, `swift-foundations` 376,
  `swift-ietf` 272, `swift-standards` 70, `swift-iso` 44, `swift-w3c` 24,
  `swift-whatwg` 10, `swift-ieee` 8, `swift-iec` 8, `swift-microsoft` 6, and 4
  each for `swiftlang`, `swift-riscv`, `swift-linux-foundation`, `swift-intel`,
  `swift-incits`, `swift-ecma`, `swift-arm-ltd`.
- **312 entries are org-crossing** (largest: `swift-standards` → `swift-ietf` 122;
  `coenttb` → `swift-foundations` 92; `swift-web-standards` → `swift-ietf` 24).
- **18 entries are repository renames**, e.g. `swift-github-types` →
  `swift-github-standard`, `swift-github-live` → `swift-github-http`,
  `swift-domain-type` → `swift-domain-standard`, `swift-emailaddress-type` →
  `swift-emailaddress-standard`, `swift-html-rendering` → `swift-html-render`.

### 1.2 Mirrors resolve to a pinned clone, not to the mutable worktree

From `Workspace/Application/.build/workspace-state.json` (200 dependencies):
`"kind": "localSourceControl"`, `"location": "<developer-root>/…"`,
`"state": { "checkoutState": { "branch", "revision" }, "name": "sourceControlCheckout" }`.
In `.build/checkouts/swift-arguments`, `git remote -v` reports
`origin  …/Application/.build/repositories/swift-arguments-7619971a`.

The chain is: canonical worktree → `.build/repositories/<name>-<hash>` (bare
cache) → `.build/checkouts/<name>` (pinned working copy) → compiled. **192 of 200
dependencies are `localSourceControl`; 8 are `remoteSourceControl`.**

The eight non-mirrored packages are exactly the Workspace owner stack plus
`swift-syntax`:
`swift-file-system` (`file://` form), `swift-git`, `swift-git-standard`,
`swift-package-manager`, `swift-spm-standard` (`file://` form), `swift-syntax`,
`swift-xcode`, `swift-xcode-standard`.

### 1.3 SwiftPM package identity follows the mirror target's directory basename

Across all 200 resolved dependencies, `identity == packageRef.name == basename(location)`
with **zero** divergences. The resolved graph contains `swift-github-standard`,
`swift-github-http`, `swift-domain-standard` and `swift-emailaddress-standard` —
i.e. the **post-rename** identities — even though the mirror map keys those local
directories under the pre-rename URLs.

Corroborating adjudication: `swift-institute/Research/Reflections/2026-07-22-canonical-package-topology-and-workspace-resolve-gate.md`
— *"The local directory basename is part of SwiftPM package identity when a
package is overridden by path."*

**Liveness check.** No current `Package.swift` in `swift-primitives/*`,
`swift-standards/*`, or `swift-foundations/*` declares any of the six pre-rename
spellings (0 matches each). The rename aliases are **dormant** — they serve
historical tags and pins, not HEAD manifests. The identity-divergence hazard is
therefore latent, not currently firing.

---

## 2. SwiftPM representations

Owner: **`swift-spm-standard`** (L2), over `swift-package-primitives` (L1).

| Capability | Correct semantic owner | Existing API or implementation | Status | Observed gap | Candidate owner-level action | Evidence |
|---|---|---|---|---|---|---|
| Package identity | `swift-spm-standard` | `Package.Identity` — `struct { scope, name }`, registry `scope.name` composite only | partial | Models **only** SE-0292 registry identity. Does not model the source-control identity SwiftPM actually computes (the `identity` field in `workspace-state.json`, derived from the location basename). The two are distinct concepts sharing a name. | architectural adjudication required | `SPM Standard › Package.Identity.swift:23` @ `56f326cc5` |
| Package display name | `swift-package-primitives` | `Package.Name` (re-exported through `SPM Standard`); `Package.Manifest.name: Package.Name` | implemented and tested ✓B* | Declaring package `swift-package-primitives` was **not** baselined; the behaviour is nonetheless exercised by passing baselined tests in `swift-spm-standard`. | no change | `SPM Standard › Package.Manifest.swift:52`; `exports.swift` @ `56f326cc5` |
| Source-control location | `swift-spm-standard` | `Package.Dependency.Source.url(URI, Package.Requirement)` — typed RFC 3986 `URI` | partial | Cannot express the `file://` form observed in resolved state, nor a bare local path used *as* a source-control location. | extend existing owner | `SPM Standard › Package.Dependency.swift:41–58` @ `56f326cc5` |
| Local filesystem location | `swift-spm-standard` | `Package.Dependency.Source.path(Swift.String)` | partial | Raw `Swift.String`; not the typed `Paths.Path` / `File.Path` used elsewhere in the stack. Doc comment explicitly defers validation and rewriting to "an operational foundation". | extend existing owner | `SPM Standard › Package.Dependency.swift:46` @ `56f326cc5` |
| Dependency requirement | `swift-spm-standard` | `Package.Requirement` — `.from`, `.upToNextMajor`, `.upToNextMinor`, `.range`, `.exact`, `.branch(String)`, `.revision(String)` | implemented and tested ✓B | `branch` / `revision` carry raw `Swift.String` rather than `Git.Ref.Name` / `Git.Object.ID`, which **do** exist in `swift-git-standard`. | architectural adjudication required | `SPM Standard › Package.Requirement.swift:34–60` @ `56f326cc5` |
| Resolved dependency | `swift-spm-standard` | — | **absent** | Nothing models `workspace-state.json`: no `packageRef.kind` (`localSourceControl` / `remoteSourceControl` / `registry` / `fileSystem`), no `checkoutState { branch, revision }`, no `subpath`, no `basedOn`. This is the single most load-bearing missing representation for the whole project. | extend existing owner | absence verified across all 34 files of `SPM Standard` @ `56f326cc5` |
| Editable dependency state | `swift-spm-standard` | — | **absent** | No representation of an edited dependency. See §3.3 for why this may never be needed. | investigate in empirical spike | as above |
| Dependency graph / `show-dependencies` representation | `swift-package-graph` | `Package.Graph` (see §4) | partial | Graph is built from manifests, not from SwiftPM's own `show-dependencies` output; there is no representation of SwiftPM's resolved graph as distinct from the declared graph. | extend existing owner | `Package Graph › Package.Graph.swift:30` @ `a76186a9b` |
| Manifest dump representation | `swift-spm-standard` | `Package.Manifest` + `Codable` conformance decoding `name`, `toolsVersion`, `dependencies`, `products`, `targets`, `platforms`, with a documented second-pass back-fill of `Package.Dependency.products` from `targets[].dependencies[]` | implemented and tested ✓B | Wire shim `_SourceControlRecord._Location` declares **only** `let remote: [_Remote]`. It cannot decode `sourceControl.location.local`, which is the form `dump-package` emits once a mirror is active — i.e. for 192 of 200 dependencies on this machine. | extend existing owner | `SPM Standard › Package.Manifest._SourceControlRecord._Location.swift`; `Package.Manifest+Codable.swift:54–101` @ `56f326cc5`; 55 tests |
| Distinction between declared and effective source | — | — | **absent** | No type anywhere in the stack expresses "declared X, effective Y". This is the core value of `workspace resolution status` and nothing models it. | architectural adjudication required | absence verified across `SPM Standard`, `Package Graph`, `Package Manager`, `Workspace Application` |

### 2.1 The `location.local` gap is corroborated, not inferred

`swift-impact` records the empirical observation directly in source:

> "Verified empirically (2026-07-19, scratch fixture) that `swift package dump-package` reports a dependency's location as `sourceControl.location.local` (a resolved path) instead of `sourceControl.location.remote.urlString` once a mirror is already active for it — so the *decoded* URL on a `.url(...)`-form `Package.Dependency` cannot be trusted to still read as the original git URL."

> "This verification therefore sources the canonical upstream URL from the upstream repository's own `origin` remote … rather than from the already-resolved dependent-side manifest data."

Evidence: `Impact › Impact.Run.MirrorVerification.swift:16–41` @ `41e95a126`.

> **Note added 2026-07-28.** Both quotations are pinned to `41e95a126` and remain
> accurate *as of that revision*, but the file has since been rewritten
> (`f2105f99`, `e4a2ec5b`). The second quotation in particular describes behaviour
> that no longer exists: sourcing the canonical URL from the upstream's `origin`
> remote was **removed** along with the `get-mirror` prediction. **The
> `location.local` observation in the first quotation still stands** — it is the
> signal the replacement now reads as ground truth — with one refinement measured
> on 2026-07-25: the mirror *target's* spelling decides the reported shape, so a
> bare-path target yields `location.local` while a `file://` target yields
> `location.remote`. Locality cannot be read off the reported kind alone.

**Consequence.** The "DECLARED SOURCE" column of the plan's §3.2 report cannot be
produced from `dump-package` on this machine. The canonical URL must come from
the dependency repository's own `origin`, or from a Workspace-owned catalogue.

---

## 3. SwiftPM operations

Owner: **`swift-package-manager`** (L3).

**The package implements exactly one operation.** Its entire source is five files:
`Package.Manager.swift`, `Package.Manager+Manifest.swift`, `Package.Manager.Error.swift`,
`Package.Manager.Termination.swift`, `exports.swift`.

| Capability | Correct semantic owner | Existing API or implementation | Status | Observed gap | Candidate owner-level action | Evidence |
|---|---|---|---|---|---|---|
| Toolchain and capability inspection | `swift-package-manager` | — | **absent** | No toolchain version query, no capability probe. Workspace performs this itself (see Responsibility Audit W-24). | extend existing owner | verified across all 5 source files @ `d3dd30904` |
| Explicit package-path support | `swift-package-manager` | `manifest(at directory: Swift.String)` sets `Process.Spawn.Configuration.workingDirectory` | partial | Uses a working directory, not `--package-path`; parameter is raw `Swift.String`, flagged as debt in `Workspace/ARCHITECTURE.md` § "Semantic-type follow-up". | extend existing owner | `Package Manager › Package.Manager+Manifest.swift:8,20` @ `d3dd30904` |
| Explicit scratch-path support | `swift-package-manager` | — | **absent** | See §3.2 — the machine coordinator lists `--scratch-path` as a forbidden caller-supplied option, so this gap may be **correct** rather than a defect. | architectural adjudication required | `Scripts/swift-build:64–71` |
| Dependency resolution | `swift-package-manager` | — | **absent** | `resolve` is a coordinator action but has no library surface. | extend existing owner | `Scripts/swift-build:1391` |
| Dependency-state inspection | `swift-package-manager` | — | **absent** | Nothing reads `.build/workspace-state.json`. Verification of any materialization is impossible without it. | extend existing owner | verified @ `d3dd30904` |
| `dump-package` | `swift-package-manager` | `Package.Manager.manifest(at:) throws(Error) -> Package.Manifest` | implemented without adequate tests | Hand-rolled JSON walk builds only `Package.Manifest(name:toolsVersion:dependencies:)`. `products`, `targets`, `platforms` are left at their defaults and every `Package.Dependency.products` is `[]`. `swift-spm-standard`'s own `Codable` decoder handles all six fields **plus** the products back-fill. Two decoders for one wire format; the operational one is strictly weaker. Also: on an empty `location.remote` array it substitutes `""` and constructs a `URI` from it. 1 `@Test`. | architectural adjudication required | `Package Manager › Package.Manager+Manifest.swift:66–104,124–132` @ `d3dd30904` |
| Dependency display (`show-dependencies`) | `swift-package-manager` | — | **absent** | — | extend existing owner | verified @ `d3dd30904` |
| Build | `swift-package-manager` | — | **absent** | Owned operationally by `Scripts/swift-build` and by `swift-impact`, not by this package. | architectural adjudication required | `Scripts/swift-build:1391`; `Impact › Impact.Run.swift` |
| Test | `swift-package-manager` | — | **absent** | as above | architectural adjudication required | as above |
| Edit | `swift-package-manager` | — | **absent** | **Retired by machine policy** — see §3.2. | architectural adjudication required | `Scripts/swift-build:1255–1257` |
| Unedit | `swift-package-manager` | — | **absent** | as above | architectural adjudication required | as above |
| Command result and failure representation | `swift-package-manager` | `Package.Manager.Error` (`.execution`, `.command(termination:stderr:)`, `.output`, `.manifest`); `Package.Manager.Termination` (`.exited`/`.signaled`/`.stopped`) | implemented without adequate tests | Adequate shape; 1 `@Test` total in the package. | extend existing owner | `Package Manager › Package.Manager.Error.swift`, `Package.Manager.Termination.swift` @ `d3dd30904` |
| Mirror configuration inspection | `swift-package-manager` | — | **absent** | ⚠️ **Corrected 2026-07-28 — the delegation claim below lapsed on 2026-07-25.** `swift-impact` no longer consults `package config get-mirror` at all: `f2105f99` deleted the prediction and replaced it with `dump-package` ground truth (ADR-001 Finding 4, referral closed). *Superseded text: "`package config get-mirror` **is** an allowed coordinator action and `swift-impact` already delegates to it, but through the coordinator process rather than through this library."* The coordinator itself is also gone from this machine (no `Scripts/` directory, measured 2026-07-28), so both cited evidence paths are historical. | **no live consumer — reassess before extending** | `Impact › Impact.Run.MirrorVerification.swift` @ `e4a2ec5b`; superseded citations `Scripts/swift-build:533–534,1391`, `…MirrorVerification.swift:56–70` @ `41e95a126` |

### 3.1 Ownership conflict: three manifest-loading implementations

| Implementation | Location | Fields recovered | State |
|---|---|---|---|
| `Package.Manifest+Codable` | `swift-spm-standard` @ `56f326cc5` | name, toolsVersion, dependencies, products, targets, platforms, + dependency-products back-fill | committed, 55 tests |
| `Package.Manager.manifest(at:)` | `swift-package-manager` @ `d3dd30904` | name, toolsVersion, dependencies | committed, 1 test |
| `Package.Manifest.decode(jsonBytes:)` | `swift-package-graph`, `Package.Manifest.Decode.swift`, 217 lines | (removed) | **deleted in the uncommitted working tree** |

Status: **ownership conflict**, partially self-resolving. The in-flight
`swift-package-graph` change (Safety Inspection §4.2) removes the third
implementation by routing to the **second** — the one that recovers three of six
fields and cannot represent `location.local`.

Candidate owner-level action: **architectural adjudication required**. The
adjudication is narrow and answerable: should `Package.Manager` decode via
`swift-spm-standard`'s `Codable` conformance instead of its own JSON walk?

### 3.2 `edit` / `unedit` are retired, and scratch paths are not caller-supplied

> **⛔ The retirement recorded in this section LAPSED, 2026-07-28.** The principal
> named `swift package edit` as the mechanism for local development across the
> institute graph; ADR-001's retirement is superseded (see its header).
>
> The reason this is a lapse rather than a reversal is recorded in this section's
> own evidence: the prohibition lived **only** in
> `<developer-root>/swift-institute/Scripts/swift-build`, the machine-wide Python
> coordinator quoted below — and that coordinator was dissolved in Workspace
> commit `9441bcb`. A rule whose sole enforcement mechanism has been dismantled is
> a residue, not a rule. Nothing here ever argued that `edit` was technically
> unsuitable; it argued that the guard rejected it.
>
> **What survives, and is now load-bearing in the opposite direction:** this
> section's second observation — that the coordinator, not the caller, assigns
> scratch paths. `swift package edit` at Swift 6.4 **rejects `--scratch-path`**
> (exit 64; its options are `--revision`, `--branch`, `--path` only), so editable
> state can only ever live in the *default* `.build`. A build given a custom
> scratch path therefore cannot see an overlay, resolves canonical, and exits 0
> without comment. Measured 2026-07-28; see
> `DESIGN-Local-Overlay-2026-07-28.md` §4, where this turns out to compose
> *correctly* with the coordinator's `--fresh` mode rather than against it.
>
> §3.3's "residual editable state" is no longer unresolved — it is explained and
> closed. See `Repository Safety Inspection` §4.3.

`<developer-root>/swift-institute/Scripts/swift-build` is a 1,486-line
machine-wide coordinator that also installs as a `PreToolUse` guard.

```python
if arguments[0] == "package" and any(argument in {
    "resolve", "update", "clean", "reset", "dump-package", "edit", "unedit",
} for argument in arguments[1:]):
    return f"Route SwiftPM operations through {COORDINATOR}; edit/unedit are retired."
```

Its `package` action list is `build, test, run, resolve, update, clean, reset,
dump-package, get-mirror` — **no `edit`, no `unedit`**. And:

```python
FORBIDDEN_SWIFTPM_OPTIONS = frozenset({
    "--package-path", "--scratch-path", "--build-path",
    "--cache-path", "--config-path", "--security-path",
})
```

with `SCRATCH_PATH`, `SCRATCH_DIR`, and `MIRROR_CONFIG` among the rejected
environment tokens. The coordinator itself assigns scratch, DerivedData, and
result paths, holds per-package-root locks, and caps machine concurrency.

Evidence: `Scripts/swift-build:64–71,94,533–534,1255–1259,1391`.

**This is recorded as a fact about the environment, not as a recommendation.**
Its consequences for the implementation plan's §7.1, §7.5, §9, §10.6, §11.4,
Gate 2, Phase 1, Epic B and open questions Q1/Q2/Q10 are for the ADR, not for
this audit.

### 3.3 Residual editable state exists and disagrees with resolver state

`Workspace/Application/Packages/swift-git` is a symlink to
`<developer-root>/swift-foundations/swift-git` — the artifact of
`swift package edit … --path`. `Application/.build/workspace-state.json` contains
no `edited` entry and records `swift-git` as `remoteSourceControl` at its GitHub
URL. Status: **unresolved**; the divergence is real and preserved untouched.

Note also that SwiftPM's default editables directory is `<package-root>/Packages/`
— the same name as `Workspace/Packages/` (the synchronized clone store) and as the
plan's proposed `Packages/`. Recorded as a naming hazard.

### 3.4 A generated-composition materializer already exists, in a different domain

`swift-manifests` (`5078007de`) renders a complete eval project — a generated
`Package.swift` plus `Sources/<executable>/main.swift` — into a temporary root and
runs SwiftPM against it, including handling `.package(path:)` resolution "from the
eval `Package.swift`'s vantage".

Evidence: `Manifest Executable › Manifest.Executable.Materializer.swift:18,24,33,41,55,67,256–288`;
`Manifest Loader › Manifest.Load.swift:27,43,78,298–330` @ `5078007de`.

Its domain is **Swift-DSL configuration manifests** (`Lint.swift`, `Format.swift`)
compiled to a typed value — *not* SwiftPM package composition. It is therefore
**not** an ownership conflict for package-manifest loading. It is prior art for
the plan's §7.2 backend, and it spawns SwiftPM outside the coordinator.

---

## 4. Package graph

Owner: **`swift-package-graph`** (L3), over `swift-graph-primitives` (L1).

| Capability | Correct semantic owner | Existing API or implementation | Status | Observed gap | Candidate owner-level action | Evidence |
|---|---|---|---|---|---|---|
| Node and edge representations | `swift-package-graph` | `Package.Graph.NodeIdentity`; graph built on `Graph.Sequential` from `swift-graph-primitives` | implemented and tested ✓B | Node key is `Package.Name` (manifest display name), **not** SwiftPM package identity. | architectural adjudication required | `Package Graph › Package.Graph.NodeIdentity.swift`, `Package.Graph.swift:30` @ `a76186a9b` |
| Direct dependencies | `swift-package-graph` | `directDependencies(of: Package.Name) -> Swift.Set<Package.Name>` | **implemented without adequate tests** ✓B | Returns a `Set` — **unordered**. **Downgraded by baseline evidence**: the passing suite asserts `directDependencies` only at its degenerate cases — `.isEmpty` on an empty graph (`Package.Graph.Tests.swift:24`) and on a single dependency-free package (`:39`). There is **no positive assertion** that it returns the correct set on a non-trivial graph. | extend existing owner | `Package.Graph.swift:85` @ `a76186a9b` |
| Direct dependants | `swift-package-graph` | `directDependents(of:) -> Swift.Set<Package.Name>` | implemented and tested ✓B | Returns a `Set`. Note spelling: `Dependents`, while the plan says "dependants". | extend existing owner | `Package.Graph.swift:113` |
| Transitive dependency closure | `swift-package-graph` | `transitiveDependencies(of:) -> Swift.Set<Package.Name>` | **implemented without adequate tests** ✓B | Returns a `Set`; no depth parameter (unlike the dependants direction). **Downgraded by baseline evidence**: `transitiveDependencies` is referenced by **no test in the passing suite** — zero occurrences across `Tests/Package Graph Tests/`. This is the single query a context's local-closure selection depends on most. | extend existing owner | `Package.Graph.swift:92` |
| Transitive dependant closure | `swift-package-graph` | `transitiveDependents(of:depth: Swift.Int = .max) -> [Wave]` | implemented and tested ✓B | Ordered and depth-bounded — the strongest existing surface, and the best-covered. | no change | `Package.Graph.swift:123`; `Package.Graph.Wave.swift` |
| Multiple-root closure | `swift-package-graph` | — | **absent** | Every query takes exactly one `Package.Name`. Multi-root closure is precisely what a context needs. | extend existing owner | verified across `Package.Graph.swift` @ `a76186a9b` |
| Cycles | `swift-package-graph` | `cycles() -> [Cycle]` | implemented and tested ✓B | none | no change | `Package.Graph.swift:201`; `Package.Graph.Cycle.swift` |
| Strongly connected components | `swift-package-graph` | `stronglyConnectedComponents() -> [[Package.Name]]` | implemented and tested ✓B | none | no change | `Package.Graph.swift:258` |
| Topological ordering | `swift-package-graph` | `topologicalOrder() throws(Self.Error) -> [Package.Name]` | implemented and tested ✓B | none | no change | `Package.Graph.swift:230` |
| Deterministic ordering | `swift-package-graph` | — | **partial** | `directDependencies`, `transitiveDependencies`, `directDependents` and `packages` all return `Swift.Set<Package.Name>`. `Set` iteration order is not guaranteed stable, so any plan or report built directly on these is **not byte-deterministic** without a caller-side sort. | extend existing owner | `Package.Graph.swift:85,92,113,163` |
| Package-to-repository projection | `swift-package-graph` | — | **absent** | The graph knows nothing about repositories, organizations, or remotes. | extend existing owner | verified @ `a76186a9b` |
| Internal/external classification with injected metadata | `swift-package-graph` | — | **absent** | No mechanism to mark a node as Institute-internal. | extend existing owner | verified @ `a76186a9b` |
| Affected-package calculation | **`swift-impact`** | `Impact.Run` — reverse-dependency waves with dependency-order barriers, baseline comparison separating new from pre-existing failures, `--with-tests`, `--json`, and `Impact.Run.MirrorVerification` | implemented and tested ✓B | **Not a gap.** `swift-impact` owns this completely and submits every manifest query, mirror lookup, build, test and timeout to `Scripts/swift-build` as the single capacity owner. | no change | `Impact › Impact.Run.swift`, `Impact.Run.Wave.swift`, `Impact.Run.Baseline.swift`, `Impact.Run.MirrorVerification.swift`; `README.md:5–15` @ `41e95a126` |
| Workspace discovery | `swift-package-graph` | `Package.Workspace.discover(at: Paths.Path, configuration:) async throws(Self.Error) -> Self`; walks for `Package.swift` to `configuration.maxDepth`, loads manifests concurrently | implemented and tested ✓B | Spawns `dump-package` **directly**, outside the coordinator (being changed in the working tree — see §9.1). | architectural adjudication required | `Package Graph › Package.Workspace.swift:61–90,172–200` @ `a76186a9b` |

### 4.1 In-flight change materially affects this section

The uncommitted diff at `swift-foundations/swift-package-graph` replaces the local
subprocess + decoder with `swift-package-manager`. If committed as written, the
graph's manifests will carry **no products, no targets, and no platforms**,
because that is the limit of `Package.Manager.manifest(at:)` (§3.1). Consumers of
`Package.Graph.manifest(for:)` that read `.products` would silently receive `[]`.

> **Corrected by `Adjudication-001-Manifest-Decoding-Ownership.md` (2026-07-24).** The deleted graph decoder was **field-for-field identical** to `Package.Manager`'s: neither reads `products`, `targets`, `platforms`, or the back-fill. The migration is therefore **field-neutral, not a regression** — it consolidates two equally weak decoders. It is also **necessary**: the deleted decoder constructs `.path(Paths.Path)` against a standard whose case is `.path(Swift.String)` since `swift-spm-standard` `56f326c`, so it no longer type-checks. The real defect is older and separate — neither operational decoder uses `swift-spm-standard`'s `Codable` conformance, and both silently yield `URI("")` for mirror-transformed dependencies.


Status: **unresolved**. Candidate owner-level action: **architectural adjudication
required**, jointly with §3.1.

---

## 5. Git representations and operations

Owners: **`swift-git-standard`** (L2) and **`swift-git`** (L3).

| Capability | Correct semantic owner | Existing API or implementation | Status | Observed gap | Candidate owner-level action | Evidence |
|---|---|---|---|---|---|---|
| Repository identity and remote location | `swift-git-standard` | — | **absent** | `Git.Client.remote(_:at:) -> Swift.String` returns a raw string. `Workspace/ARCHITECTURE.md` § "Semantic-type follow-up" already names "Git remote-location type supporting URI, path, and scp-like syntax" as required and unowned. | extend existing owner | `Git Standard` file list @ `ed8b3796c`; `Git › Git.Client.Repository.swift:19` @ `a9955a9d9` |
| Refs and branches | `swift-git-standard` | `Git.Ref`, `Git.Ref.Name` (`RawRepresentable`, validating `init` throwing `Git.Ref.Name.Error`), `Git.Ref.Advertisement` | implemented and tested ✓B | none | no change | `Git Standard › Git.Ref.Name.swift:3`, `Git.Ref.Advertisement.swift:3`; 6 tests @ `ed8b3796c` |
| Revisions and object identifiers | `swift-git-standard` | `Git.Object`, `Git.Object.ID` (`RawRepresentable`, validating) | implemented and tested ✓B | No revision-**expression** or range type; `Git.Client.count(_ range: Swift.String, …)` takes a raw string. Named as debt in `ARCHITECTURE.md`. | extend existing owner | `Git Standard › Git.Object.ID.swift:3`; `Git › Git.Client.Repository.swift:42` |
| Working-tree status | `swift-git-standard` | `Git.Status`, `Git.Status.Code`, `Git.Status.Entry` | implemented and tested ✓B | Entry paths are `[UInt8]`; `ARCHITECTURE.md` names `[Byte]` or a typed Git path as the required direction. | extend existing owner | `Git Standard › Git.Status.Entry.swift:2`; `ARCHITECTURE.md:133` |
| Current branch and detached state | `swift-git` | `branch(at:) -> Swift.String`, `head(…)`, `upstream(_:at:)` | partial | Returns a branch **name string**; no typed detached-HEAD representation, so "detached" is indistinguishable from a branch literally named that. | extend existing owner | `Git › Git.Client.Repository.swift:23,31,27` @ `a9955a9d9` |
| Worktree porcelain representation | `swift-git-standard` | — | **absent** | No worktree type at all. | extend existing owner | `/usr/bin/grep -rl 'worktree\|Worktree'` over `swift-git-standard/Sources` → 0 files |
| List worktrees | `swift-git` | — | **absent** | — | extend existing owner | `/usr/bin/grep -rl 'worktree\|Worktree'` over `swift-git/Sources` → **0 files** |
| Add worktree | `swift-git` | — | **absent** | — | extend existing owner | as above |
| Remove worktree | `swift-git` | — | **absent** | — | extend existing owner | as above |
| Lock and unlock worktree | `swift-git` | — | **absent** | — | extend existing owner | as above |
| Branch occupancy | `swift-git` | — | **absent** | Cannot answer "is this branch checked out in another worktree?", which the plan makes a planning-time refusal condition. | extend existing owner | as above |
| Cleanliness and safe removal | `swift-git` | `status(at:) -> [Git.Status.Entry]` gives cleanliness; removal is not modelled | partial | Cleanliness yes, safe-removal policy no. | extend existing owner | `Git › Git.Client.Repository.swift:72` |
| Stale administrative state and pruning | `swift-git` | — | **absent** | — | extend existing owner | as above |
| Ancestry / base-revision inspection | `swift-git` | `ancestor(_:of:at:)`, `count(_:at:)`, `head(…)` | implemented without adequate tests | Present and used by `Workspace.Sync`; 3 `@Test` across the whole client. | extend existing owner | `Git › Git.Client.Repository.swift:31,42,50`; 3 tests @ `a9955a9d9` |
| Create branch from typed base revision | `swift-git` | `switch(_:at:)`, `track(…)` | partial | Can switch and set tracking; cannot create a branch at a given base revision. | extend existing owner | `Git › Git.Client.Mutation.swift:63,67` |
| Clone / fetch / merge / init | `swift-git` | `initialize(at:bare:)`, `fetch(…)` ×2, `merge(…)`, `clone(…)` | implemented without adequate tests | Working-directory parameters are raw `Swift.String`; named as debt in `ARCHITECTURE.md`. | extend existing owner | `Git › Git.Client.Mutation.swift:4,13,23,33,46` |

**Summary.** `swift-git` exposes 16 operations, **none** of them worktree-related.
Every worktree capability in the implementation plan's §6.6 is genuinely absent,
in both the L2 representation and the L3 client.

---

## 6. Xcode

Owners: **`swift-xcode-standard`** (L2, provisional) and **`swift-xcode`** (L3).

| Capability | Correct semantic owner | Existing API or implementation | Status | Observed gap | Candidate owner-level action | Evidence |
|---|---|---|---|---|---|---|
| Workspace representation | `swift-xcode-standard` | `Xcode.Workspace { var version: Swift.String = "1.0"; var references: [Reference] }` | implemented without adequate tests | Flat reference list only — no group nesting. 2 `@Test` in the package. | extend existing owner | `Xcode Workspace Standard › Xcode.Workspace.swift` @ `d336477d2` |
| Workspace generation | `swift-xcode` | `Xcode.Workspace.xml -> Swift.String` | implemented without adequate tests | 2 `@Test` across both targets. | extend existing owner | `Xcode Workspace › Xcode.Workspace+XML.swift:6` @ `83b6627d9` |
| Package references | `swift-xcode-standard` | `Xcode.Workspace.Reference { var location: Location }` | partial | `Reference` carries **only** a location. There is no distinction between a package reference and any other file reference, and no attached metadata (identity, expected package name) for later verification. | extend existing owner | `Xcode Workspace Standard › Xcode.Workspace.Reference.swift` |
| Local package references | `swift-xcode-standard` | `Location.group(String)` pointing at a package root | implemented without adequate tests | **A FileRef to a package root *is* the local-package mechanism** — see §6.1. No dedicated type is missing, but nothing names the concept. | architectural adjudication required | `Xcode.Workspace.Location.swift`; `Internal/INTEGRATION-WORKSPACE.md` |
| Relative references | `swift-xcode-standard` | `Location` = `.group(String)` \| `.absolute(String)` \| `.self`, with `rawValue` / `init?(rawValue:)` round-trip | implemented without adequate tests | Paths are raw `Swift.String`; nothing prevents an absolute path from being emitted, and nothing computes a relative path from a base. | extend existing owner | `Xcode.Workspace.Location.swift` |
| Deterministic serialization | `swift-xcode` | `.xml` is a pure function of the value | partial | Determinism holds by construction but is not asserted by a test in this package. It **is** asserted at ecosystem scale — see §6.1. | extend existing owner | `Xcode.Workspace+XML.swift`; `Internal/XCWORKSPACE-INTEGRATION-EVIDENCE-2026-07-16.md` |
| Atomic installation | `swift-xcode` | `write(to directory: Swift.String) throws(Error)` → `File.System.Create.Directory.create(createIntermediates:)` then `File(bundle / "contents.xcworkspacedata").write.atomic(xml)` | implemented without adequate tests | Correct composition over `swift-file-system`. Parameter is raw `Swift.String`. | extend existing owner | `Xcode Workspace › Xcode.Workspace+Write.swift` @ `83b6627d9` |
| Reference verification | `swift-xcode` | — | **absent** | Nothing reads an existing `contents.xcworkspacedata` back, and nothing checks that a referenced path exists or contains a package. Workspace does its own byte-equality check instead (Responsibility Audit W-31). | extend existing owner | verified across both targets @ `83b6627d9` |
| Multiple roots | `swift-xcode-standard` | `references: [Reference]` | implemented without adequate tests | Multiple roots are expressible; grouping them by logical hierarchy is not. | extend existing owner | `Xcode.Workspace.swift` |
| Generated-reference manifest / inspection surface | `swift-xcode` | — | **absent** | No typed record of what was generated is returned to the caller. | extend existing owner | verified @ `83b6627d9` |
| Scheme representation and generation | `swift-xcode-standard` / `swift-xcode` | `Xcode.Scheme`, `.Build`, `.Reference`, `.Test`; `+XML`, `+Write` | implemented without adequate tests | Exists. Relevant because the coordinator requires a concrete scheme for every workspace action. | no change | `Xcode Scheme Standard › *.swift`; `Xcode Scheme › Xcode.Scheme+XML.swift`, `+Write.swift` |

### 6.1 The Xcode local-package mechanism is already in production, with recorded evidence

This is not a spike question on this machine; it is settled operational practice.

`<developer-root>/swift-institute/Internal/institute.xcworkspace` contains
**457 FileRefs**, every one of the relative form `group:../../<org>/<repo>`.

`Internal/INTEGRATION-WORKSPACE.md` states:

> "Every listed root is a live working-tree package. URL dependencies not listed as FileRefs resolve through the configured SwiftPM mirrors and are not live-tree evidence."

> "The workspace membership file is explicit infrastructure. … There is no second generator or public workspace that authorizes local membership."

> "The former primitives, standards, and foundations workspaces and the synthetic `institute-all` package were removed: they created competing resolution/build surfaces without avoiding Xcode's whole-workspace graph-loading cost."

> "Workspace success is Darwin integration evidence only. It does not establish non-Darwin behavior, clean public-URL resolution, branch protection, CI status, or release readiness."

`Internal/XCWORKSPACE-INTEGRATION-EVIDENCE-2026-07-16.md` (127 lines) records:

- **Live-source control experiment.** A two-root workspace with the real
  `swift-byte-primitives` and a *copied* `swift-carrier-primitives` carrying one
  deliberate missing-type reference: the downstream `swift-byte-primitives-Package`
  build **failed in 15.64s**; removing only the sentinel made the identical
  workspace **pass in 4.60s**.
- **Byte determinism.** Two complete 447-member generations produced the identical
  aggregate SHA-256 `49820f900d3828b221fdbcacb2fe7d95f49a12544d80a15e24a80bf5458fa0aa`
  over all workspace XML, shared schemes, and `workspace-inventory.json`;
  `Package.resolved` excluded as resolution state. 11 generator tests passed.
- **Scale.** 1-root canary warm 13.80s; 16-root canary 83.09s; Primitives 203
  roots 200.76s; Standards 115 roots 384.69s; **Foundations 129 roots — bounded
  non-completion at 352.18s**; Foundations build `swift-async-Package` bounded
  non-completion at 313.79s.
- **Macros.** Without `-skipMacroValidation` the canary fails before compilation
  because Xcode requires the `Witnesses Macros Implementation` macro to be enabled.
  That macro target is declared in `swift-foundations/swift-witnesses` @ `8297968ac`
  — see the Representative Package Catalogue.
- **Lockfiles.** "Workspace-owned lockfile accepted; package-local URL-form
  lockfile was not."
- **Layer closure.** The Standards workspace pulled Foundations packages in as
  implicit dependencies, so a standards-only workspace is not proof of downward
  closure.

Status of the underlying capability: **implemented and tested** at the
*operational* level (the workspace exists, is generated deterministically, and is
proven to carry live source), while the *library* surface in `swift-xcode` that
would let Workspace verify it is **absent**.

> **Baseline qualification — 2026-07-24.** This paragraph's "tested" rests on the
> 2026-07-16 integration evidence document, **not** on the Gate 0A baseline. The
> Gate 0A baseline covered `swift-xcode` and `swift-xcode-standard` at the SwiftPM
> package level only — four tests total across both, none of which opens an Xcode
> workspace. No Xcode workspace was generated, opened, resolved, or built in this
> correction slice. The operational claim remains attributable solely to the
> 2026-07-16 document at its stated revisions.

---

## 7. Supporting foundations

| Capability | Correct semantic owner | Existing API or implementation | Status | Observed gap | Candidate owner-level action | Evidence |
|---|---|---|---|---|---|---|
| Typed paths | `swift-paths` (L3) | `Paths.Path`, `.Borrowed`, `.Component`, `.Components`, `.Extension`, `.Stem`, `.Error`; product `Paths` | unresolved | **`unresolved` (not baselined)** — test declarations exist but no baseline was executed for this package in the Gate 0A correction slice; scope was reduced to nine decision-driving owner packages. Not distinguishable from a passing baseline on current evidence. Two path vocabularies coexist: `Paths.Path` (used by `swift-package-graph`) and `File.Path` / `File.Directory` (used by `swift-file-system`, `swift-xcode`, Workspace). Conversion is not audited here. | architectural adjudication required | `swift-paths/Sources` @ `f20b5315f`; `Package Graph › Package.Workspace.swift:24` |
| Directory inspection | `swift-file-system` | `File.Directory`, `.Contents`, `.entries()`, `File.System.Stat.isFile(at:)`, `File.Metadata`, `File.Kind` | unresolved | **`unresolved` (not baselined)** — test declarations exist but no baseline was executed for this package in the Gate 0A correction slice; scope was reduced to nine decision-driving owner packages. Not distinguishable from a passing baseline on current evidence. none | no change | `File System Core`; used at `Package Graph › Package.Workspace.swift:200,213` |
| Atomic writes | `swift-file-system` | `File.System.Write.Atomic.write(…)` with `Options`, `Strategy`, `Ownership`, `Preservation`, `Durability`, `Commit.Phase`; plus `File.write.atomic(_:)` | unresolved | **`unresolved` (not baselined)** — test declarations exist but no baseline was executed for this package in the Gate 0A correction slice; scope was reduced to nine decision-driving owner packages. Not distinguishable from a passing baseline on current evidence. none — this is the most elaborated surface in the supporting set | no change | `File System Core › File.System.Write.Atomic*.swift:64,90`, `…Atomic+API.swift:73` @ `bde096613` |
| Temporary sibling creation | `swift-file-system` | `File.Path.Temporary.sibling(of:prefix:suffix:)` | unresolved | **`unresolved` (not baselined)** — test declarations exist but no baseline was executed for this package in the Gate 0A correction slice; scope was reduced to nine decision-driving owner packages. Not distinguishable from a passing baseline on current evidence. none — already used by `Workspace.Sync` for collision-resistant same-filesystem clone staging | no change | `File.Path.Temporary.swift`; `Workspace.Sync.swift:207,268` |
| Process execution | `swift-process` | `Process.Spawn.run(_ configuration:)`, `Process.Spawn.Configuration`, `Process.Output`, `Process.Status` (`.exited`/`.signaled`/`.stopped`), `Process.Handle`, `Process.Stream`, `Process.Error` | unresolved | **`unresolved` (not baselined)** — test declarations exist but no baseline was executed for this package in the Gate 0A correction slice; scope was reduced to nine decision-driving owner packages. Not distinguishable from a passing baseline on current evidence. none | no change | `swift-process/Sources` @ `c7b15b0d9` |
| stdout / stderr / exit status | `swift-process` | `Process.Output { stdout: [UInt8]?, stderr: [UInt8]?, status }` | unresolved | **`unresolved` (not baselined)** — test declarations exist but no baseline was executed for this package in the Gate 0A correction slice; scope was reduced to nine decision-driving owner packages. Not distinguishable from a passing baseline on current evidence. none | no change | as above |
| JSON encoding and decoding | `swift-json` | `JSON`, `JSON.Parse`, `JSON.Encode`, `JSON.Decode`, `JSON.Serializable`, `JSON.Coder`, `JSON.Located`, `JSON.EventStream`, `JSON.ND`, `JSON.Options`, `JSON.Span` | unresolved | **`unresolved` (not baselined)** — test declarations exist but no baseline was executed for this package in the Gate 0A correction slice; scope was reduced to nine decision-driving owner packages. Not distinguishable from a passing baseline on current evidence. none | no change | `swift-json/Sources` @ `c0d4a4b2e` |
| Deterministic JSON output | `swift-json` | `JSON.Options` | **unresolved** | Options type exists; whether it guarantees stable key ordering was not established without executing code. Workspace's byte-determinism currently rests on `Workspace.Configuration.serialize` building the object in a fixed literal order. | investigate in empirical spike | `swift-json/Sources/…/Options`; `Workspace.Configuration.swift:24` |
| XML composition and serialization | `swift-xml` | `XML.Document`, `.Element`, `.Attribute(s)`, `.Text`, `.Serialize`, `.Parse`, `XML.Serializable`, `.Located`, `.ND` | unresolved | **`unresolved` (not baselined)** — test declarations exist but no baseline was executed for this package in the Gate 0A correction slice; scope was reduced to nine decision-driving owner packages. Not distinguishable from a passing baseline on current evidence. none | no change | `swift-xml/Sources` @ `14e3776be` |
| Command schema, parsing, help | `swift-arguments` | `Command.Protocol`, `Command.Configuration`, `Command.Schema.Definition`, `Argument.Codable` | unresolved | **`unresolved` (not baselined)** — test declarations exist but no baseline was executed for this package in the Gate 0A correction slice; scope was reduced to nine decision-driving owner packages. Not distinguishable from a passing baseline on current evidence. Exit-code mapping surface not audited in this slice. | investigate in empirical spike | consumed at `Workspace.CLI.swift:6,15,22` |
| Process environment access | `swift-environment` | `Environment.read(_:) -> Swift.String?` | unresolved | **`unresolved` (not baselined)** — test declarations exist but no baseline was executed for this package in the Gate 0A correction slice; scope was reduced to nine decision-driving owner packages. Not distinguishable from a passing baseline on current evidence. Consumed at exactly one site: `Workspace.CLI.run()` reads `PWD` to establish the workspace root. Recorded because that makes the workspace root **dependent on an inherited environment variable** rather than on an explicit argument or an ancestor-marker search. | extend existing owner | `Workspace.CLI.swift:2,50` @ `ef0579a8b` |
| GitHub operations | `swift-github`, `swift-github-http`, `swift-github-standard` | `GitHub.Organization.Repositories.Client`, `GitHub.Repository.Content.Client`, `GitHub.Repository.Summary`, `.Visibility`, `.ID`, `GitHub.Organization.Name`, `GitHub.Repository.Name`, `GitHub.Traversal.Limit` | unresolved | **`unresolved` (not baselined)** — test declarations exist but no baseline was executed for this package in the Gate 0A correction slice; scope was reduced to nine decision-driving owner packages. Not distinguishable from a passing baseline on current evidence. `swift-github-standard` exists with 8 targets; `Workspace/ARCHITECTURE.md` still lists both it and `swift-github` as "planned" — **stale documentation**. | no change | `Workspace.Inventory.Client.swift:9–10`; `swift-github-standard/Sources` @ `562fe2e05` |

---

## 8. Workspace-owned policy

Full declaration-level classification is in `Workspace Responsibility Audit.md`.
Summarised here for capability completeness.

| Capability | Correct semantic owner | Existing API or implementation | Status | Observed gap | Candidate owner-level action | Evidence |
|---|---|---|---|---|---|---|
| Repository inventory | Workspace | `Workspace.Configuration` (+`Document`, `+validate`, `+render`), `Workspace.Repository`, `Workspace.Layer`, `Workspace.Inventory.*` (18 files) | implemented and tested ✓B | Scope is `"proof"` — 5 repositories against an ecosystem of ~628 mirrored and 457 workspace-member packages. | no change | `Workspace.json`; `Workspace.Inventory.*` @ `ef0579a8b` |
| Eligibility and exclusion | Workspace | `Inventory.Eligibility`, `.Reason` (7 cases), `.Exclusion`, `.Policy`, `.Policy.Error`, `.Organization` | implemented and tested ✓B | Correctly Workspace-owned Institute policy. | no change | `Workspace.Inventory.Eligibility*.swift`, `…Policy*.swift` |
| Repository discovery | Workspace | `Inventory.Client.discover(…)`, `Inventory.Application.run(…)`, `Inventory.Merge`, `Inventory.Writer` (+`.Plan`) | implemented and tested ✓B | Composes `swift-github` correctly; owns lost-update protection. | no change | `Workspace.Inventory.Client.swift:20`, `…Application.swift:23`, `…Writer.swift:11,20` |
| Context identity or equivalent | Workspace | — | **absent** | No context concept exists in any form. This is the project's entire new surface. | architectural adjudication required | verified across all 34 Workspace source files |
| Planning and dry-run values | Workspace | `Workspace.Action` (5 cases + `.text` + `.fatal`), `Workspace.Inspection`, `Inventory.Writer.Plan`, `Sync.run(dry:)` | implemented and tested ✓B | Sync-shaped only; no resolution plan, no materialization plan. | extend existing owner | `Workspace.Action.swift`, `Workspace.Inspection.swift`, `Workspace.Sync.swift:20` |
| Synchronization operations | Workspace | `Workspace.Sync` — inspect, clone via same-filesystem temporary sibling + atomic move, fast-forward only when clean/on-`main`/tracking/not-ahead | implemented and tested ✓B | Safety model matches the constitution §15 closely. | no change | `Workspace.Sync.swift:20,68,201,237,264` |
| Safety diagnostics | Workspace | `Workspace.Doctor.run()` — toolchain, checkout, remote, upstream, branch, divergence, manifest-name, workspace-reference checks; error/warning split | **implemented without adequate tests** ✓B | **Downgraded on review of the baseline citation.** The two passing tests (*"doctor selects diagnostic execution"*, *"doctor rejects dry run"*) exercise **CLI dispatch and argument validation only**. No test covers the checkout, remote, upstream, branch, divergence, toolchain, manifest-name, or workspace-reference diagnostics that constitute the capability. Compares **manifest display name** to **repository name** and labels the result "manifest identity" (see Responsibility Audit W-25). Spawns `swift --version` and `xcodebuild -version` directly (W-24). | replace Workspace-local use | `Workspace.Doctor.swift:25,29,33,88,104,112` |
| Reporting and deterministic rendering | Workspace | `Configuration.rendered()` with a round-trip decode check; `Inventory.Writer.plan(…)` returning `.current`/`.replace` | implemented and tested ✓B | Rendering is `print`-based; no machine-readable output mode. | extend existing owner | `Workspace.Configuration+render.swift:4`; `Workspace.Inventory.Writer.swift:11` |
| Xcode composition — reference rendering | Workspace | `Workspace.Xcode.document(_:)`, `.render(_:)` | implemented and tested ✓B | Emits a flat `group:Application` + `group:Packages/<name>` list by string interpolation; no grouping, no relative-path computation. | extend existing owner | `Workspace.Xcode.swift:6,18`; test *"render uses relative application and package references"* |
| Xcode composition — writing and current-state inspection | Workspace | `Workspace.Xcode.path(at:)`, `.current(_:at:)`, `.write(_:at:)` | **implemented without adequate tests** ✓B | **Split from the row above on review.** The only cited test proves reference *rendering*. Nothing exercises `write`, and `current(…)` is whole-file byte equality that cannot distinguish a missing reference from a whitespace change. No Xcode workspace was generated, opened, resolved, or built in this Gate 0A slice. | replace Workspace-local use | `Workspace.Xcode.swift:22,26,41` |
| Layer model | Workspace | `Workspace.Layer` — `primitives`/`standards`/`foundations`/`components`/`applications` with `order` | implemented and tested ✓B | Matches the five-layer architecture. No dependency-direction check is implemented against it. | extend existing owner | `Workspace.Layer.swift:4,11` |

---

## 9. Cross-cutting findings

### 9.1 Coordinator bypass is systemic, not isolated

Three L3 packages and Workspace itself spawn build-capable tools directly rather
than submitting to `Scripts/swift-build`:

| Site | What it spawns | Evidence |
|---|---|---|
| `Package Manager › Package.Manager+Manifest.swift:20` | `swift package dump-package` | @ `d3dd30904` |
| `Package Graph › Package.Workspace.swift:172–200` | `swift package dump-package` (per discovered package, concurrently) | @ `a76186a9b`, being replaced in the working tree |
| `Manifest Loader › Manifest.Load.swift:298–330` | SwiftPM against a generated eval project | @ `5078007de` |
| `Workspace Application › Workspace.Doctor.swift:112–133` | `swift --version` **and `xcodebuild -version`** | @ `ef0579a8b` |

`swift-impact` is the counter-example: its README states it "Submits every manifest
query, mirror lookup, build, test, and timeout to `swift-build`" as a **single
capacity owner**.

Status: **ownership conflict**. Candidate owner-level action: **architectural
adjudication required** — the question is whether coordinator delegation is a
machine-local operator concern or an invariant that belongs in the library layer.

### 9.2 Raw-`String` boundaries are pervasive and already catalogued

`Workspace/ARCHITECTURE.md` § "Semantic-type follow-up" lists eight raw values
awaiting owner-level adjudication. Every one was confirmed still present:

| Current value | Confirmed at |
|---|---|
| Git working directory `String` | `Git.Client.Repository.swift:4,15,19,23,27` |
| Git remote `String` | `Git.Client.Repository.swift:19` |
| Git revision-range `String` | `Git.Client.Repository.swift:42` |
| Git status `[UInt8]` paths | `Git Standard › Git.Status.Entry.swift` |
| SwiftPM operation directory `String` | `Package.Manager+Manifest.swift:8` |
| Workspace repository name `String` | `Workspace.Repository.swift:5` |
| Workspace repository URL `String` | `Workspace.Repository.swift:6` |
| Swift/Xcode version `String` | `Workspace.Configuration.swift:8,9` |

Add to that list, newly observed: `Xcode.Workspace.Location` path strings
(`Xcode.Workspace.Location.swift`) and `Xcode.Workspace.write(to directory: Swift.String)`.

### 9.3 Rejections already on record

`Workspace/ARCHITECTURE.md` § "Heritage and decomposition decisions" has already
rejected `swift-workspace-standard` ("`Workspace.json`, sync rules, and doctor
severity are Institute application policy, not external standards") and
`swift-git-process` ("Process execution is an implementation mechanism of the
single `swift-git` operational client, not an integration domain"). The
implementation plan's §6.9 new-package presumption has direct local precedent.

### 9.4 Capability areas whose answer requires execution

Recorded as **investigate in empirical spike**, not asserted:

1. Whether `swift-json`'s `JSON.Options` guarantees deterministic key ordering.
2. ~~Whether `swift package config get-mirror`, run through the coordinator from a
   given package directory, reports the substitution a build would actually use
   for an arbitrary dependency (`swift-impact` relies on this; the reliance is
   documented, the general property is not).~~
   **ANSWERED — NEGATIVE, and the reliance is gone.** It does not: `get-mirror`
   is an exact-string key match, so it answers "not found" for every URL spelling
   but the one the key was written under, while the resolver substitutes under
   whichever spelling *it* uses. Measured by the §8.5 spike (ADR-001 Finding 4)
   and independently re-reproduced by `swift-impact`, which **removed** the
   reliance on 2026-07-25 (`f2105f99`) in favour of `dump-package` ground truth.
   Referral closed and verified 2026-07-28 — see ADR-001 Finding 4.
3. Whether `Package.Manager.manifest(at:)` throws or silently yields an empty
   `URI` when `location.remote` is empty — the code path constructs `URI("")`.
4. The `swift-arguments` exit-code mapping surface.
5. Whether the coordinator's forbidden-option list has an approved escape for a
   caller that legitimately needs an isolated scratch path.

---

## 10. Ledger

Recounted after the executed baseline. `Implemented & tested` now means
**`✓B` — a named test ran and passed**, not "test declarations were counted".

| Area | Implemented & tested ✓B | Implemented, thin tests | Partial | Absent | Ownership conflict | Unresolved |
|---|---:|---:|---:|---:|---:|---:|
| SwiftPM representations | 3 | 0 | 5 | 3 | 0 | 0 |
| SwiftPM operations | 0 | 3 | 1 | 9 | 1 | 1 |
| Package graph | 6 | **2** | 2 | 3 | 0 | 1 |
| Git | 4 | 3 | 3 | 7 | 0 | 0 |
| Xcode | 1 | 7 | 3 | 3 | 0 | 0 |
| Supporting foundations | **0** | 0 | 0 | 0 | 0 | **11** |
| Workspace policy | 9 | 0 | 0 | 1 | 0 | 0 |

**Changes from the pre-baseline ledger:**

- Package graph `8 → 6` tested, `0 → 2` thin: `directDependencies` and
  `transitiveDependencies` were downgraded on baseline evidence (§0.4.1).
- Supporting foundations `9 → 0` tested, `1 → 11` unresolved: scope reduction
  (§0.5). Semantic findings unchanged; only the *tested* claim withdrawn.
- Workspace policy `8 → 9` and SwiftPM representations `2 → 3`: recount after the
  §0.4 citation pass, which attributed one previously uncounted row in each area.

**The three structurally largest absences**, in order of how much of the plan
depends on them:

1. **Resolved-dependency state** — nothing in the stack reads or models
   `workspace-state.json`. Without it no materialization can be verified, and
   "verify by inspecting the external system rather than trusting that apply
   returned successfully" is unimplementable.
2. **Git worktree domain** — completely absent from both L2 and L3, in every one
   of the eleven sub-capabilities.
3. **Declared-versus-effective source** — no type expresses it, and on this
   machine the declared side additionally cannot be read from `dump-package` for
   192 of 200 dependencies.
