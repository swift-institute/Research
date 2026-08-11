# Local multi-package composition — ratified coordinate map and implementation plan

**Status:** RECOMMENDATION · **Tier:** 2 · **Scope:** `swift-institute/institute`,
`swift-institute/institute-application` · **Date:** 2026-08-11

Corrects and supersedes, for execution purposes, the architecture ruling + 13-task plan
authored 2026-08-11 ("Institute Application" end-state document). The ruling's *architecture*
survives essentially intact. Its *coordinates*, *commands*, and three of its task targets did
not survive contact with the source, and are corrected here.

Everything below marked **measured** was read from the working tree at
`swift-institute/institute` `db2c2d6` and `swift-institute/institute-application` `a35d053`.
Everything marked **UNMEASURED** was not executed and is not evidence.

---

## 0. Executive summary of the corrections

| # | Defect in the source plan | Correction |
|---|---|---|
| D1 | `institute verify` carries two incompatible meanings | Ruling **VERB-001**: the composition family collapses to one verb with modes. `verify` is retired as a top-level verb. |
| D2 | Tests prescribed at `Tests/Institute Development Tests/`, which does not exist | All new tests go in the existing single test target `Tests/Institute Tests/`. |
| D3 | Every task verifies with `institute verify --package-path … --jobs 8`, which is not a valid command | `institute package test --package-path … --jobs 8`. |
| D4 | T5 extends `Institute.Composition.Record` as "the receipt" | `Institute.Composition.Record` is the **pairwise ledger record**, not a receipt. The receipt owner is `Institute.Coherence.Receipt` (target `Institute Instruments`). T5 is retargeted. |
| D5 | T9/T10 create `Sources/Institute Application/Institute.Command.*.swift` | Those files do not exist and the CLI is not decomposed that way. Parsing lives in `Institute.Application.CLI.swift` + `.Operation` + `.Mode`. |
| D6 | T11–T13 make `institute compose --scope inventory` the canonical full-roster command | The full-roster composed build **already exists** as `institute coherence --build-path swiftpm-composed-root`. A second spelling is duplicate ownership. #81's command is unchanged. |
| D7 | Test files named `X.Tests.swift` | House spelling is `X Tests.swift` (space, no dot). |
| D8 | Plan treats identity divergence as a future risk | `Institute.Composed.Manifest.package` is **already** set from `repository.name` without evaluation (`Institute.Composed.swift`). It is a present defect and a T4 change site. |
| D9 | Plan is presented with a wave/concurrency table implying parallelism | Maximum concurrency is 2, reached in four of nine waves; five waves are strictly serial. Effective concurrency ≈ 1.4 editors, and **exactly one** SwiftPM process at any time. |

---

## 1. Ruling VERB-001 — the composition verb family

**Delegated to this session by the principal; breaking changes authorized.**

### The measured collision

The word "verif*" already has three distinct claimants in the shipped CLI:

| Surface | Meaning (measured) |
|---|---|
| `institute verify --consumer C --dependency D` | Report the effective compiled source of `D` in `C`, read from SwiftPM's resolved state plus the composition ledger. A **report**. (`Institute.Composition.verify`, `Institute.Composition.swift:168`.) |
| `institute verification seal \| check` | Produce/check the exact-head verification receipt. (`Institute Instruments/Institute.Verification.*`.) |
| `institute package test` | Execute one package's own tests through the build coordinator. |

The source plan adds a fourth meaning — *run package-owned tests for N explicit seeds under
one source assignment* — onto the same word. That is four meanings on one spelling, and a
near-collision between `verify` and `verification` that already existed.

### Ruling

**The composition family becomes one verb with modes. `verify` and `restore` are retired as
top-level verbs.**

```text
institute compose apply    …    # was: institute compose          (redirect sources)
institute compose restore  …    # was: institute restore
institute compose status   …    # was: institute verify           ← the collision, resolved
institute compose build    …    # the composed SwiftPM graph over one source assignment
institute compose test     …    # package-owned verification for the explicit seeds
```

Compatibility, until the deletion gate:

- bare `institute compose` (no mode) remains an alias of `compose apply`;
- `institute restore` remains a deprecated alias of `compose restore`;
- `institute verify` remains a deprecated alias of `compose status`;
- all three print a deprecation line to **stderr** (never stdout — `github token` precedent).

`apply`, `restore`, and `status` are new `Institute.Application.CLI.Mode` cases. `build` and
`test` already exist in `Mode` and are reused verbatim.

### Reasoning under the doctrine

- **Axiom 1 / §1.3.** A CLI verb is a public surface; a spelling that denotes four capabilities
  has no exact owner. The `compose` family is the exact owner of *"operate on one source
  assignment"*; `build` and `test` are the two executions over an assignment, and `status` is
  the report over it. One family, one owner, five lawful operations.
- **§10.4 (compatibility mistaken for ownership).** The old spellings survive as non-owning
  aliases with an explicit removal gate (T13), not as second owners.
- **§2.2 of the source ruling** (coherence and local development are two profiles over one
  engine) is *preserved*, not weakened: the coherence profile keeps its own verb.
  `institute coherence --build-path swiftpm-composed-root` remains #81's command. `compose
  build` is the local-subset profile. They share `Institute.Composition` / `Institute.Composed`
  underneath and must not fork it.

### What this ruling does **not** do

It does not rename `coherence`, `verification`, or `package test`. It does not introduce a
`materialization` sub-mode scheme — `materialization` is a new top-level verb with modes
(`create|register|list|status|forget`), of which `status` is now shared vocabulary with
`compose status`, which is intended.

---

## 2. Ratified coordinate map

Every path the source plan prescribes, mapped to a verified destination. `institute` =
`/Users/coen/Developer/coenttb/swift-institute/institute`, `application` =
`…/institute-application`. Repository-relative paths only below.

### 2.1 Confirmed as-is (measured, exists)

| Concept | Real path |
|---|---|
| `Institute.Composed.Root` (160 lines) | `institute/Sources/Institute Development/Institute.Composed.Root.swift` |
| `Institute.Composed` (150) | `institute/Sources/Institute Development/Institute.Composed.swift` |
| `Institute.Composition` (410) | `institute/Sources/Institute Development/Institute.Composition.swift` |
| `Institute.Composition.Record` (88) | `institute/Sources/Institute Development/Institute.Composition.Record.swift` |
| `Institute.Composition.State` (128) | `institute/Sources/Institute Development/Institute.Composition.State.swift` |
| `Institute.Layout` | `institute/Sources/Institute Model/Institute.Layout.swift` |
| `Institute.Root`, `preflight`, `materialization(for:)` | `institute/Sources/Institute Model/Institute.Root.swift`, `Institute.Root+preflight.swift` |
| `Institute.Sync` | `institute/Sources/Institute Development/Institute.Sync.swift` |

### 2.2 Corrected destinations

| Plan prescribed | Real destination | Why |
|---|---|---|
| `institute/Tests/Institute Development Tests/**` | `institute/Tests/Institute Tests/**` | The package declares **one** test target, `Institute Tests`, with an explicit `path:`, covering all ten library targets. |
| `Institute.Materialization.Tests.swift` etc. | `Institute.Materialization Tests.swift` etc. | House spelling: `Institute.Composition Tests.swift`, `Institute.Layout Tests.swift`, `Build.Coordinator Tests.swift`. |
| `application/Sources/Institute Application/Institute.Command.Materialization.swift` | `application/Sources/Institute Application/Institute.Application.CLI.Operation.swift` (verb case) + `Institute.Application.CLI.Mode.swift` (modes) + `Institute.Application.CLI.swift` (option declaration, `validate()`, `run()` arm) | No per-command files exist. `Institute Application CLI/main.swift` is three lines and is not a parsing site. |
| `application/Sources/Institute Application/Institute.Command.{Compose,Verify,BuildPath}.swift` | same three files as above | ditto |
| `application/Tests/Institute Application Tests/Institute.Command.*.Tests.swift` | `application/Tests/Institute Application Tests/Institute.Application.CLI Tests.swift` (extend) | The target has three test files, all CLI-shaped. |
| T5 target: `Institute.Composition.Record` | `institute/Sources/Institute Instruments/Institute.Coherence.{Receipt,Population,Stage,Instrument}` | See §3, G6. |
| T11/T12 canonical command `institute compose --scope inventory` | `institute coherence --build-path swiftpm-composed-root` | Already implemented and wired. See §3, G9. |
| `application/Documentation/Local Development Composition.md` | `application/Documentation/Local Development Composition.md` | Directory does not exist yet; creating it is lawful. Confirm against the documentation skill before adding a second docs root. |

### 2.3 New files — ratified (all under `institute/Sources/Institute Development/`)

`Institute.Materialization.swift`, `.ID.swift`, `.Ownership.swift`, `.Registry.swift`,
`.Registry.Error.swift`, `Institute.Composition.Scope.swift`,
`Institute.Composition.SourceMap.swift`, `.SourceMap.Error.swift`,
`Institute.Composition.BuildPlan.swift`, `Institute.Composition.Workspace.swift`,
`Institute.Development.VerificationPlan.swift`, `Institute.Development.ExecutionBudget.swift`.

Tests, all under `institute/Tests/Institute Tests/`, named `<Type> Tests.swift`.

---

## 3. Gate record — the eight principal-only items

### G1 — Composition source coordinates · **CLEARED**

All five files exist at the paths in §2.1, with the stated line counts. No move is required by
any task; every "modify" instruction resolves.

### G2 — CLI parsing target · **CLEARED WITH CORRECTION**

The target is `Sources/Institute Application` (the plan's assumption is right). Its *shape* is
not. Measured contents (5 files, 2243 lines):

- `Institute.Application.CLI.swift` (1972) — every `Command.Option` declaration, `validate()`,
  and one `run()` switch over `Operation`;
- `Institute.Application.CLI.Operation.swift` (102) — the 18 top-level verbs;
- `Institute.Application.CLI.Mode.swift` (107) — the 20 second-positional modes;
- `Institute.Application.CLI+architecture.swift` (41);
- `Institute.Application.swift` (21).

`Sources/Institute Application CLI/main.swift` is `await Command.main(…)` and nothing else.

**Consequence:** an executor creating `Institute.Command.Compose.swift` would author a second
argument parser. Prohibited. Every CLI change in this programme is an edit to the three files
named above.

### G3 — Package-graph authority · **CLEARED WITH CORRECTION**

The authority is `Package.Manager`, product `Package Manager` from
`swift-foundations/swift-package-manager`, with its model in `SPM Standard` from
`swift-standards/swift-spm-standard`. Both are **already** declared dependencies of
`Institute Development`. Relevant operations, measured:

- `Package.Manager.evaluation(at:) -> Package.Manifest.Evaluation` — `swift package
  dump-package`; preserves products, targets, platforms, per-dependency traits, and
  **evaluated dependency identity and source** (`Package.Dependency.Evaluation`). It reports a
  mirror-substituted dependency honestly as `sourceControl` with a `local` location rather
  than collapsing it.
- `Package.Manager.manifest(at:)` — name, tools version, dependency list.
- `Package.Manager.resolution(at:) -> Package.Resolution` and
  `Package.Manager.Materialized.source(of:at:)` — resolved state.

**Correction:** `Institute.Dependency` (target `Institute Dependency`) is **not** the graph
authority for this programme. It is a GitHub-facing audit of declared dependency *URLs* —
`Institute.Dependency.Edge` carries `declaredURL`/`canonicalURL` and resolution runs through
`GitHub` metadata fetches and an ownership policy. Using it for local forward closure would
put the network on the local development path.

**No forward-closure operation exists today.** Computing it is new work (T2) and must be
implemented by iterating `Package.Manager.evaluation(at:)` over the inventory. Writing a
manifest parser is prohibited (Axiom 9).

> **Trap, measured.** `Package.Manager.evaluation(at:)` spawns SwiftPM and takes an exclusive
> lock on the target directory's `.build`, waiting indefinitely. A test must never evaluate the
> package it is running from, and the composed-build path must never evaluate a package it is
> concurrently building.

### G4 — Process-execution authority · **CLEARED**

`Build.Coordinator` in target `Build Coordinator`
(`institute/Sources/Build Coordinator/`), invoked as
`coordinator.run(.build, at:fresh:arguments:capturingDiagnostics:) -> Build.Coordinator.Result`.
`Institute.Composed.Root.build(at:fresh:arguments:capturingDiagnostics:coordinator:)` already
routes through it. No task may construct `Process` to run `swift`.

### G5 — Repository-state authority for `Package.resolved` · **CLEARED**

`Package.Manager.resolution(at:)` → `Package.Resolution` (`.dependencies[].state` is
`sourceControlCheckout | fileSystem | edited`), plus
`Package.Manager.Materialized.source(of:at:)` for the compiled tree. Git working-tree facts
come from `Git` (`swift-git`) as used by `Institute.Sync` and `Institute.Doctor`.

Measured and important: **`Institute.Composition.compose` and `restore` never read or write
`Package.resolved`.** They rewrite exactly one clause of `Package.swift` through
`Package.Manifest.Redirection`. The plan's repeated "must leave `Package.resolved` unchanged"
constraint is therefore already structurally satisfied by the incumbent, and the task-level
`grep 'Package.resolved'` guards are a control, not a repair.

### G6 — Receipt schema / versioning owner · **CLEARED WITH CORRECTION (material)**

The plan asserts `Institute.Composition.Record` is the canonical receipt and instructs T5 to
add scope, population, manifest-load duration, peak memory and stage-failure coordinates to it.
**That is the wrong owner.** Measured:

- `Institute.Composition.Record` is one **ledger entry**: `{consumer, dependency, declared,
  planned}` — the two verbatim manifest clauses that cannot be re-derived after a rewrite. It
  is persisted by `Institute.Composition.State` at
  `<checkout>/.workspace/compositions.json`, git-ignored, per-machine, schema `version: 1`,
  refused on mismatch. It is not content-addressed and carries no population or timing fields.
- The composed-build receipt owner is `Institute.Coherence.Receipt`, in
  `institute/Sources/Institute Instruments/`, with `Instrument` (workspaceCommit,
  workspaceJsonBlob, selection, **buildPath**), `Environment` (platform, swift, xcode, runner,
  fresh, cachesUsed), `Population` (inventoryCount, materializedCount, builtTargetCount,
  expectedTargetCount), `Stage` (bootstrap, sync, doctor, graph, build, population),
  `Attribution`, `Verdict`, and a `digest`.

**Consequence:** T5 is retargeted (§5). The plan's "do not create a second receipt schema"
instruction is right; it was pointed at the wrong file. `Record.planned` does hold a
machine-local absolute path — lawfully, because the ledger is checkout-local and unaddressed —
and that is exactly why the *coherence* digest must not absorb it.

### G7 — CI workflow / control-plane owner · **CLEARED**

- Canonical reusable workflow: **`swift-institute/.github/.github/workflows/swift-ci.yml@main`**.
- The caller in the owning repository: `institute/.github/workflows/ci.yml` — a one-hop
  generated caller passing only `lint-bundle: institute`.
- Caller generation and repository policy are owned by
  `swift-institute/institute-continuous-integration`.

Measured from `swift-ci.yml`: `platform-support` is empty for `institute`, so the ordinary
build tier selects **Linux**, and the **full tier runs the complete platform contract
including `linux-release`**. Full tier is selected by tag refs, `workflow_dispatch`, or a
`[ci full]` head message.

**Consequence:** Ubuntu evidence for S8 is available today via a full-tier dispatch; no new
workflow is required for the *fixture* legs. A weak executor must not add a package-local
workflow file.

### G8 — Does an existing type already own the registry or source-map laws? · **CLEARED — plan's dispositions upheld**

Measured against all six named roots:

| Root | Owns | Does not own |
|---|---|---|
| `Institute.Root` | exactly two roots, `checkout` and `hierarchy`, where `hierarchy` is *derived* as `checkout.parent` and no initializer accepts them independently | enumeration, registration, lifecycle, collision, more than one root |
| `Institute.Layout` | placement under a **caller-supplied** root (`directory(for:at:)`, `parent(for:at:)`, `components`, `reference`) | which roots exist, or that a root is registered |
| `Institute.Root.preflight(_:under:)` | physical containment of every existing prefix under a supplied base, refusing symlinks and traversal, including a static form | anything root-set-shaped |
| `Institute.Composed` / `.Root` | manifest reading and synthetic-manifest rendering from `[Composed.Manifest]` | scope, assignment, workspace placement |
| `Institute.Composition` | the pairwise redirect/restore/report operations | multi-entry transactions, closure, scope |
| `Institute.Composition.State` | the pairwise ledger, versioned | root registration |
| `Institute.Composition.Record` | two verbatim manifest clauses | population, timing, scope |

No existing owner defines registry identity, lifecycle, or collision; none defines a
repository→checkout assignment across roots. The source plan's dispositions —
`Implement once` for `Institute.Materialization.Registry`, `Compose` for
`Institute.Composition.SourceMap` — are **upheld**.

Note that `Institute.Root.preflight(_:under:)` already takes the base as a parameter, so
multi-root containment needs no change to the containment predicate itself — only per-root
invocation. That is a genuine `Reuse`.

### G9 — Additional gate finding (not on the principal's list, material)

**The `swiftpm-composed-root` build path already exists end-to-end for inventory scope.**
Measured in `Institute.Coherence.Run`: `realComposedGraph(swift:)` calls
`Institute.Composed.manifests(…)` + `Institute.Composed.Root.write(…)`, and
`realComposedBuild` calls `Institute.Composed.Root.build(…)`; both are selected by
`BuildPath.swiftPMComposedRoot`. The CLI accepts
`institute coherence --build-path swiftpm-composed-root` today.

**Consequences:**
1. #81 needs *evidence*, not an implementation. Its command is unchanged.
2. T7 is not "build the executor" — it is "complete the existing executor with workspace
   isolation, an execution budget, and honest package identity".
3. The plan's `institute compose --scope inventory` is a **duplicate spelling of an existing
   command** and is removed from this plan (D6).

---

## 4. Stop-condition dispositions (S1–S9)

| ID | Disposition | Evidence / what would clear it |
|---|---|---|
| **S1** exact-owner search | **CLEARED** | G8. All six roots read in full. No existing owner of registry or source-map laws. |
| **S2** current source coordinates | **CLEARED** for the five composition files and the Model files; **CORRECTED** for CLI (G2), tests (D2) and receipt (G6). §2 is the ratified map. |
| **S3** package-graph authority | **CLEARED WITH CORRECTION** | G3. `Package.Manager` + `SPM Standard`, already declared. Forward closure is new work; a second parser is prohibited. |
| **S4** SwiftPM override semantics | **REMAINS — reassigned to T6** | Nothing in the tree measures whether a root `.package(path:)` and a transitive remote of the same evaluated identity converge on the local package. Clearing evidence: fixture `LocalOverride` compiling a symbol that exists **only** in the local copy, on macOS and Ubuntu, exit 0, plus `Package.Manager.resolution` reporting `.fileSystem` for that identity. A manifest text snapshot is inadmissible. |
| **S5** multi-root path semantics | **REMAINS — reassigned to T6** | Feasibility is cleared (`preflight` is base-parameterised; `Layout.directory(for:at:)` is root-parameterised). Evidence still required: fixture `MixedRoots` builds a graph naming packages under two registered roots, on macOS and Ubuntu. |
| **S6** package-verification redirection | **PARTLY CLEARED** | Cleared by reading: the incumbent never touches `Package.resolved`, and `restore` returns the declared clause byte-for-byte with a resolve-free structural check. **Remains, and is worse than the plan assumed:** the incumbent has **no failure or cancellation restoration at all** — `compose` writes the manifest and saves the ledger with no `defer`-equivalent unwind. Generalising to a multi-entry transaction must *add* that, not preserve it. Reassigned to T8. |
| **S7** receipt compatibility | **CLEARED WITH CORRECTION** | G6. One receipt owner exists (`Coherence.Receipt`) and is already `buildPath`-aware. Constraint restated: absolute paths and materialisation IDs must not enter the addressed digest. |
| **S8** scale | **REMAINS — reassigned to T11** | Full-inventory Ubuntu run at Swift 6.3.3 with manifest-load, graph-load, memory, population and target-count evidence. The full-tier `linux-release` leg exists (G7); the *receipt fields* do not yet (T5). |
| **S9** CI owner | **CLEARED** | G7. |

**No stop condition remains blocking for T1–T4.** S4/S5 gate everything from T7 onward, and
T6 is the measurement that clears them.

---

## 5. The corrected tasks

Execution policy is unchanged from the source plan (§F3.1) and is restated once here rather
than per task: one PR per task, targeting `main`; no tags; no long-lived branches; all SwiftPM
work through `institute`; local runs are preflight only; complete only when required CI checks
pass on the PR's exact head; `Package.resolved` untouched; dirty and untracked work preserved;
rollback is `git revert` of that PR.

**Standard verification block** — every task, unless it states otherwise:

```bash
institute package test --package-path swift-institute/institute --jobs 8

test -z "$(
  git -C swift-institute/institute status --short --untracked-files=all |
  grep 'Package.resolved' || true
)"
```

Substitute or add `--package-path swift-institute/institute-application` for
application-side tasks. **Do not use `institute verify --package-path`** — `--package-path` is
valid only with `package`, and `--jobs` only with `package build|test` (measured from
`institute --help`). That command has never existed.

---

### T1 — Materialisation model and registry

**Wave 1 · depends on: gate (cleared) · PR scope: lower model and local registry only**

**Create** (all under `institute/Sources/Institute Development/`):
`Institute.Materialization.swift`, `Institute.Materialization.ID.swift`,
`Institute.Materialization.Ownership.swift`, `Institute.Materialization.Registry.swift`,
`Institute.Materialization.Registry.Error.swift`.

**Create** (under `institute/Tests/Institute Tests/`):
`Institute.Materialization Tests.swift`, `Institute.Materialization.Registry Tests.swift`.

**Exact change.** Immutable validated `ID`; a root locator that is explicitly *not* identity;
`Ownership` with cases `managed` and `adopted`; schema-versioned persistence following the
`Institute.Composition.State` precedent exactly (a `version` integer, refused on mismatch,
written pretty + sorted-keys + trailing newline, absent file = empty); atomic `register`,
`resolve`, `list`, `status`, `forget`; physical-root collision detection via
`File.System.Canonical.resolve`; fail-closed on a missing root. No filesystem search. No
checkout deletion. No Git worktree creation or pruning. `forget` removes only the record.

Do not add branch, revision, package identity, or repository lists to a root record.

Store the registry beside the existing ledger: `<checkout>/.workspace/materializations.json`.

**Acceptance criteria**
- Duplicate IDs fail with a typed error.
- Two locators resolving to the same physical directory fail.
- A missing registered root reports missing/UNMEASURED, never valid.
- A registry operation cannot mutate an adopted root.
- `forget` on either ownership leaves filesystem content untouched.
- Serialization is deterministic and round-trips.
- One type per file; `throws(Institute.Error)` or a typed leaf error on every throwing member.

**Done.** Registry tests pass in exact-head CI; no CLI command exposes it yet.

**Weak-executor traps**
- *Trap:* treating the root path as the materialisation's identity. *Defusal:* a test must
  prove the ID survives a locator change, and that every use revalidates the current physical
  locator.
- *Trap (new):* copying `Institute.Root`'s initializer shape, which derives `hierarchy` from
  `checkout.parent`. *Defusal:* a registry root is supplied, never derived from a sibling
  relationship.
- *Trap (new):* writing the registry into the *hierarchy* root. *Defusal:* it is checkout-local
  state, exactly like `compositions.json`, and lives under `<checkout>/.workspace/`.

---

### T2 — Composition scope and source assignment

**Wave 2 · depends on: T1 · PR scope: pure normalization and validation model**

**Create:** `Institute.Composition.Scope.swift`, `Institute.Composition.SourceMap.swift`,
`Institute.Composition.SourceMap.Error.swift`, and
`Institute.Composition.Scope Tests.swift`, `Institute.Composition.SourceMap Tests.swift`.

**Exact change.** `Scope` supports exactly two forms: full inventory, and explicit seeds
normalized to their complete forward Institute dependency closure. `SourceMap` accepts one
default materialisation ID plus exact inventory-reference → materialisation-ID overrides.

Normalization must, in order: reject unknown seeds; reject unknown or out-of-scope overrides;
resolve each repository through the registry and `Institute.Layout.directory(for:at:)`;
run `Institute.Root.preflight(directory, under: registeredRoot)` per repository against **its
own** root; require `Package.swift`; evaluate identity through `Package.Manager.evaluation(at:)`;
reject duplicate physical paths; reject one evaluated identity at two paths; emit deterministic
inventory-reference ordering.

Forward closure is computed by evaluating each in-scope package and mapping its
`Package.Dependency.Evaluation` identities back to inventory repositories. No layer, family,
prefix, changed-file, or reverse-dependency selector is admitted.

**Acceptance criteria**
- Empty explicit seed selection fails.
- Full-inventory scope equals the inventory owner's roster exactly.
- Closure is produced only from evaluated manifests.
- A repository can be assigned to a second materialisation explicitly.
- A closure repository with no assignment fails.
- A symlink escape fails (`preflight` already refuses a symlinked prefix).
- Identity divergence reports **both** the inventory reference and the evaluated identity.
- No inventory name is used as a package identity without evaluation.

**Weak-executor traps**
- *Trap:* using a directory name or `Layout.reference(for:)` as SwiftPM package identity.
  *Defusal:* repository reference and evaluated identity are separate stored fields; setting
  one from the other without evaluation is rejected in review.
- *Trap (new):* reaching for `Institute.Dependency.Audit` because it is named "dependency".
  *Defusal:* that type fetches GitHub metadata over the network. The local closure authority is
  `Package.Manager.evaluation(at:)`. See G3.
- *Trap (new):* evaluating the package the test process is running from. *Defusal:* SwiftPM
  takes an indefinite `.build` lock. Fixtures evaluate only fixture packages in temporary
  directories.

---

### T3 — Parameterise the generated workspace

**Wave 1 · depends on: gate (cleared) · PR scope: generated-root location only**

**Create:** `Institute.Composition.Workspace.swift`, `Institute.Composition.Workspace Tests.swift`.
**Modify:** `Institute.Composed.Root.swift`.

**Exact change.** Add `Institute.Composed.Root.directory(in: Institute.Composition.Workspace)`.
Retain `directoryName == "institute-composed-root"`. The workspace owns the generated-root
directory, an isolated scratch directory, an exclusive same-workspace lock, and fresh-run
location selection. The existing `directory(at checkout:)` becomes a deprecated compatibility
wrapper delegating to the new API and owning no behaviour of its own. Do not alter
`Layout.reference(for:)`.

Use the existing `POSIX Kernel Lock` product (already a `Build Coordinator` dependency) for
the lock; do not invent a lockfile protocol.

**Acceptance criteria**
- Two workspaces produce two distinct generated-root directories.
- The generated root need not sit below any source materialisation.
- Concurrent acquisition of one workspace fails deterministically.
- Distinct workspaces share no scratch state.
- `--fresh` yields a fresh execution location and never deletes a source repository's
  resolution state.
- No generated root is committed. (`institute-composed-root` must be present in the ignore
  canon — check `institute-continuous-integration/canon/gitignore-institute.txt` and file
  against that owner if absent; do not hand-edit `.gitignore`.)

**Weak-executor trap.** *Trap:* assuming a relative `org/name` path is automatically relative
to the source root. *Defusal:* `Institute.Composed.Manifest.reference` is hard-coded to
`"../\(Layout.reference(for:))"` today, which is correct **only** while the generated root sits
directly under the checkout. Once the workspace moves, every generated dependency path must be
recomputed relative to the generated root. Tests must prove the emitted paths resolve to the
intended physical directories; no conclusion may be drawn from string prefixes.

---

### T4 — Build plan and reshaped rendering

**Wave 3 · depends on: T2, T3 · PR scope: canonical composed-graph representation**

**Create:** `Institute.Composition.BuildPlan.swift`, `Institute.Composition.BuildPlan Tests.swift`.
**Modify:** `Institute.Composed.Root.swift`, `Institute.Composed.swift`,
`Institute.Composed Tests.swift`.

**Exact change.** `BuildPlan` carries deterministic: explicit seeds; normalized closure;
source-map entries; path-dependency entries; package-qualified library-product dependencies;
path-dependency count; library-contributing count; explicit exclusion records with reason
codes; expected buildable-target count.

Rendering accepts only a validated `BuildPlan`; emits one `.package(path:)` per package in the
normalized closure; emits synthetic target dependencies only for library products;
package-qualifies every product dependency by **evaluated** identity; computes paths relative
to the generated root including traversal into another registered root; preserves deterministic
ordering.

`Institute.Composed.Manifest` gains an evaluated-identity field. **Today `package` is set from
`repository.name` with no evaluation** (`Institute.Composed.swift`) — that is the defect the
plan treats as a future risk, and this task is where it is fixed. `contributing(_:)` narrows to
selecting *synthetic target product dependencies only*; it must no longer decide which packages
appear as path dependencies or in population evidence.

The all-inventory entry point remains as a deprecated adapter constructing an inventory `Scope`
and a single-root default `SourceMap`, so `Institute.Coherence.Run` keeps compiling unchanged.

**Acceptance criteria**
- A library-less repository stays in path-dependency and population evidence and is explicitly
  excluded from synthetic target dependencies with a reason code.
- A product-name collision across two identities renders unambiguously.
- A mixed-root plan renders paths that resolve.
- Zero library-product contribution produces a typed non-success, never a green empty build.
- `expectedTargetCount` is computed from the exact plan.
- The same plan renders byte-identically.
- `Institute.Coherence.Run`'s inventory path produces the same receipt as before this PR.

**Weak-executor traps**
- *Trap:* keeping `contributing(_:)` as the filter for the *package dependency* list.
  *Defusal:* filter only target product dependencies; keep all normalized packages visible
  unless T6 proves unused path dependencies unlawful.
- *Trap:* renaming a materialised directory to match an inferred identity. *Defusal:* identity
  divergence is a graph-stage error. No repository, package, or directory rename is authorized
  anywhere in this programme.
- *Trap (new):* changing the coherence receipt's `expectedTargetCount` semantics in the same
  PR. *Defusal:* T4 must leave the inventory-scope receipt byte-identical; receipt change is T5.

---

### T5 — Extend the coherence receipt *(retargeted)*

**Wave 3 · depends on: T2, T3 · PR scope: evidence schema only**

**Modify** (under `institute/Sources/Institute Instruments/`):
`Institute.Coherence.Receipt.swift`, `Institute.Coherence.Population.swift`,
`Institute.Coherence.Stage.swift`.
**Modify** `institute/Tests/Institute Tests/Institute.Coherence Tests.swift`.

> This task previously targeted `Institute.Composition.Record`. That type is the pairwise
> ledger, not a receipt (G6). **Do not add population, timing, or scope fields to it.**

**Exact change.** Add additively and version explicitly: scope kind; explicit-seed count and
references; normalized-closure count; inventory digest/count for full scope; source-assignment
count; path-dependency count; library-contributor count; exclusion records with reason codes;
expected target count; generated-manifest digest; jobs; active SwiftPM process count;
manifest-load duration; graph-load duration; peak memory where the platform supplies it;
stage-specific failure coordinate.

`Instrument.buildPath` already exists and already records `"swiftpm-composed-root"`. Reuse it.

Absolute paths and materialisation IDs may appear only as non-addressed diagnostics, or be
omitted. They must never make semantically identical source content produce a different digest.

Do not create `DevelopmentReceipt`, `WorkspaceReceipt`, or any parallel schema.

**Acceptance criteria**
- Existing #80/#81-compatible fields remain decodable.
- New fields are deterministic.
- A missing required scope/population field yields UNMEASURED or failure, never green.
- A zero count without its measured population control is not green.
- Absolute paths do not enter the addressed digest — proved by a fixture that renders one
  receipt from two workspaces at different absolute paths and compares digests.
- Old records decode under the schema's explicit compatibility law.

**Weak-executor trap.** *Trap:* hashing the materialisation path or registry ID as source
identity. *Defusal:* reuse the receipt's existing content-addressing owner. If it cannot
represent dirty local source, **stop and report** — do not invent a second hash.

---

### T6 — SwiftPM semantic calibration fixtures · **GO/NO-GO GATE**

**Wave 4 · depends on: T4, T5 · PR scope: empirical proof only; no activation**

**Create** under `institute/Tests/Institute Tests/`:
`Fixtures/Composition/{LocalOverride,IdentityCollision,IdentityDivergence,MixedRoots,LibraryLess,SymlinkEscape}/`
and `Institute.Composed.Root.Integration Tests.swift`.

> Fixture resources live under the existing test target's directory. If SwiftPM excludes them
> from compilation, declare them via the test target's `resources:`/`exclude:` in
> `institute/Package.swift` — do **not** create a second test target for them (D2).

**Exact change.** Isolated fixture packages proving:

1. a root path dependency overrides or lawfully converges with a transitive **remote**
   dependency of the same evaluated identity — **clears S4**;
2. two paths with the same evaluated identity fail;
3. inventory/directory spelling divergence is reported, not silently accepted;
4. one generated graph may reference packages under two registered roots — **clears S5**;
5. a library-less package stays visible but is not a synthetic target dependency;
6. a physical path escape fails;
7. package-qualified duplicate product names are unambiguous;
8. an empty or non-enumerated population cannot produce a green result.

Every SwiftPM invocation runs through `Build.Coordinator` or `Package.Manager`. Never a shell
`swift build`.

**Acceptance.** All positive fixtures pass and all negative fixtures fail for the exact
expected reason code, on macOS **and** Ubuntu.

**If fixture 1 or 4 fails because SwiftPM semantics do not support the intended graph, STOP THE
PROGRAMME and return it to the principal.** The executor may not substitute mirrors, manifest
rewriting, or a different override strategy.

**Verification.** Standard block, plus a **full-tier** CI run so the `linux-release` leg
executes:

```bash
gh workflow run ci.yml --repo swift-institute/institute --ref <branch>
# or push the PR head with a `[ci full]` head message
gh run watch <run-id> --repo swift-institute/institute --exit-status
```

**Weak-executor trap.** *Trap:* asserting success because the generated manifest text contains
the desired path. *Defusal:* the positive fixture must **compile a symbol that exists only in
the local copy**, and `Package.Manager.resolution` must report `.fileSystem` for that identity.
A text snapshot is inadmissible (Axiom 8).

---

### T7 — Complete composed-root execution

**Wave 5 · depends on: T6 · PR scope: execute one validated build plan**

**Modify:** `Institute.Composed.swift`, `Institute.Composition.swift`.
**Create:** `Institute.Development.ExecutionBudget.swift`,
`Institute.Composed.Execution Tests.swift`, `Institute.Development.ExecutionBudget Tests.swift`.

> Scope correction: composed-root execution **already works** for inventory scope through
> `Institute.Coherence.Run.realComposedBuild` (G9). This task adds workspace locking, the
> execution budget, and build-plan input — it does not build a new executor.

**Exact change.** Execution acquires the workspace lock; generates a fresh manifest from the
build plan; invokes `Build.Coordinator`; starts exactly one SwiftPM process; sets jobs to
`min(requestedJobs, detectedHostCoreCount)` (eight on the primary machine); captures stage,
timing, memory where available, and process outcome; writes the canonical coherence receipt;
releases the lock on success, typed error, and cancellation; and confirms source-repository
resolution state is unchanged.

**Acceptance criteria**
- A second execution on the same workspace fails with a lock error.
- Distinct workspaces execute independently.
- `--jobs 9` becomes 8 on this host rather than starting nine.
- No path starts a second SwiftPM process.
- Failure records name the exact stage and, where available, the repository/package identity.
- Generated files are never committed; source `Package.resolved` state is unchanged.

**Weak-executor trap.** *Trap:* using `Process` directly to run `swift` because it is simpler.
*Defusal:* call `Build.Coordinator`. A new shell invocation is duplicate ownership and fails
review.

---

### T8 — Generalize package verification from a pair to a source map

**Wave 5 · depends on: T6 · PR scope: transactional source redirection and serial plan**

**Create:** `Institute.Development.VerificationPlan.swift`,
`Institute.Development.VerificationPlan Tests.swift`.
**Modify:** `Institute.Composition.State.swift`, `Institute.Composition.swift`,
`Institute.Composition.Record.swift`, `Institute.Composition Tests.swift`,
`Institute.Composition.State Tests.swift`.

**Exact change.** Replace the internal pair representation with an ordered source-map
transaction. For each explicit seed, in deterministic inventory-reference order: derive
dependency assignments from the source map; capture exact preimages of every file the mechanism
touches; refuse to begin if a touched file is already in an unsupported dirty state; apply the
full map atomically; invoke the existing package verification owner; **restore exact bytes on
success, typed error, signal/cancellation, and partial application**; record the child result;
move on only after complete restoration.

The pairwise API constructs a one-entry source map and delegates. One package verification
process at a time.

> **Measured, and larger than the source plan assumed.** The incumbent
> `Institute.Composition.compose` writes the manifest and saves the ledger with **no unwind
> path**: there is no `defer`, no cancellation handling, and no partial-application recovery.
> This task therefore *introduces* the transaction rather than generalising one. Budget for it.

**Acceptance criteria**
- Two local dependency overrides are simultaneously active for one consumer.
- An injected failure after the first mutation restores every preimage.
- Cancellation restores every preimage.
- Unsupported dirty state refuses **before** any mutation.
- Source `Package.resolved` is never modified, edited, or deleted.
- Order equals deterministic inventory-reference order.
- Forward-closure dependencies are not automatically verification subjects.
- Pairwise behaviour is observationally preserved through delegation, including
  `Institute.Composition.restore`'s byte-for-byte clause restoration and its resolve-free
  structural check.

**Weak-executor traps**
- *Trap:* deleting a `Package.resolved` to force the new source map. *Defusal:* immediate task
  failure; no fallback exists.
- *Trap:* broadening or deleting an explicit `throws(E)` while changing restoration flow.
  *Defusal:* preserve typed throws exactly; add a typed case rather than weakening a signature.
  (See also the known `Mutex.withLock` inference trap: never delete an explicit `throws(E)`
  there without compiling first.)
- *Trap:* restoring only on normal return. *Defusal:* tests must cover typed error,
  cancellation, and partial application.

---

### T9 — Expose materialisation management and sync

**Wave 2 · depends on: T1 · PR scope: application exposure only**

**Modify:** `application/Sources/Institute Application/Institute.Application.CLI.Operation.swift`
(add `materialization`), `Institute.Application.CLI.Mode.swift` (add `register`, `forget`;
`create` if not folded into `register`), `Institute.Application.CLI.swift` (option declarations,
`validate()` arms, `run()` arm), and `application/Tests/Institute Application Tests/Institute.Application.CLI Tests.swift`.
**Modify** `institute/Sources/Institute Development/Institute.Sync.swift` for the
`--materialization` route.

**Exact change.**

```text
institute materialization create   --id <id> --root <path>
institute materialization register --id <id> --root <path> --ownership adopted
institute materialization list
institute materialization status   --id <id>
institute materialization forget   --id <id>
institute sync --materialization <id>
```

`create` creates an empty managed root and registers it. `register` adopts an existing root.
`sync --materialization` may create missing clones only under a **managed** root; against an
adopted root it is validation-only and fails before mutation. `forget` never removes files. No
command creates or prunes Git worktrees. Sync's behaviour without `--materialization` is
unchanged.

**Acceptance criteria**
- Help states non-deletion and ownership semantics explicitly.
- Unknown IDs fail before any sync work.
- Adopted roots cannot be cloned into.
- Managed roots resolve through `Layout.directory(for:at:)`.
- Existing default sync behaviour is byte-identical.
- No macOS-only API is introduced.

**Weak-executor traps**
- *Trap:* reading "managed" as authority to delete or reset repositories. *Defusal:* managed
  means only that sync may create *missing* clones. Destructive cleanup is absent from the API,
  deliberately. `sync` also never resets, cleans, stashes, rebases, or switches a branch —
  preserve that.
- *Trap (new):* creating `Institute.Command.Materialization.swift`. *Defusal:* see G2.

---

### T10 — Expose the composition family *(rewritten under VERB-001)*

**Wave 6 · depends on: T7, T8, T9 · PR scope: CLI parsing, routing, documentation**

**Modify:** `Institute.Application.CLI.Operation.swift` (deprecate `restore`, `verify`),
`Institute.Application.CLI.Mode.swift` (add `apply`, `restore`, `status`),
`Institute.Application.CLI.swift`,
`application/Tests/Institute Application Tests/Institute.Application.CLI Tests.swift`.
**Create:** `application/Documentation/Local Development Composition.md`.
**Modify:** `application/CLAUDE.md` and `application/README.md` where they document
`compose|verify|restore`.

**Exact change.** Land the verb family from §1, and add:

```text
--scope repositories                                  (local subset; inventory scope is `coherence`'s)
--materialization <id>
--repository <inventory-reference>                    repeatable
--source <inventory-reference>=<materialization-id>   repeatable
--workspace-path <path>
--jobs <n>
--fresh
```

Rules:
- `--scope repositories` requires at least one `--repository`.
- An override for an unselected or out-of-closure repository fails.
- `compose build` executes only the composed build; `compose test` executes only the
  verification plan; `compose status` only reports.
- `--consumer` / `--dependency` remain accepted but deprecated and lower to a one-entry source
  map.
- **`--scope inventory` is not added to `compose`.** The full-roster profile is
  `institute coherence --build-path swiftpm-composed-root` (G9/D6).
- Documentation states plainly that a composed build does **not** run dependency package tests.

**Acceptance criteria**
- Help output documents every incompatibility and every deprecation.
- Repeated arguments behave deterministically regardless of command-line ordering.
- Pairwise command lines produce the same normalized source map as the new form.
- No parser code owns graph, containment, or identity rules — the parser constructs typed
  inputs only and all semantic validation stays in `institute`.
- Deprecation notices go to stderr.

**Weak-executor trap.** *Trap:* revalidating repository references, identities, or containment
in `validate()`. *Defusal:* `validate()` may reject *argument combinations* only.

---

### T11 — Ubuntu and full-roster evidence

**Wave 7 · depends on: T10 · PR scope: CI orchestration only**

**Coordinate — now ratified (G7).** The owner is
`swift-institute/.github/.github/workflows/swift-ci.yml@main`; the caller is the generated
`institute/.github/workflows/ci.yml`; generation and policy belong to
`swift-institute/institute-continuous-integration`. **An executor must not hand-author a
package-local workflow.** Any workflow change is filed against the control-plane owner.

**Exact change.** At the control-plane owner, ensure jobs run:

1. the T6 calibration fixtures on Ubuntu and macOS (already covered by the full tier's
   `linux-release` + `macos-release` legs — confirm, do not duplicate);
2. a representative local explicit scope including a mixed-root assignment;
3. the complete inventory profile on Ubuntu at Swift 6.3.3;
4. the complete inventory profile on the existing required platforms;
5. receipt comparison against the existing coherence schema;
6. source-repository `Package.resolved` state checks.

Canonical full-roster command — **unchanged from today**:

```bash
institute coherence --build-path swiftpm-composed-root
```

The run must publish the coherence receipt including enumerated inventory count and digest,
path-dependency count, library-contributing count, exclusions, expected target count,
manifest-load and graph-load duration, peak memory where measurable, exact commit, platform and
toolchain.

No numerical performance threshold is invented. The receipt supplies evidence for a later
threshold ruling.

**Acceptance criteria**
- Ubuntu 6.3.3 full inventory succeeds.
- Scope enumeration has a positive control.
- A missing receipt or incomplete population evidence fails the run.
- The mixed-root fixture succeeds; negative identity fixtures fail for the expected reason.
- The workflow contains no copied package-graph or path predicate.
- No source `Package.resolved` change is present.

**Verification.** The control plane's own dispatch mechanism. Closure requires the exact-head
run ID and every required check green — read from the run's own `conclusion`, never from a
lane's report.

**Weak-executor trap.** *Trap:* reducing the inventory to make the job green. *Defusal:* the
receipt's inventory digest and count are compared against the canonical inventory in the same
run; any mismatch is failure.

---

### T12 — Activate the canonical SwiftPM path

**Wave 8 · depends on: T11 · PR scope: one activation record and one default switch**

**Modify:** `Institute.Application.CLI.swift` (the `buildPath ?? .xcodebuildMerged` default at
the `.coherence` arm), `Institute.Coherence.BuildPath.swift` documentation,
`application/Documentation/Local Development Composition.md`, `application/CLAUDE.md`.
**Create:** `application/Documentation/Migrations/SwiftPM Composed Root Activation.md`.

**Exact change.** Make `swiftpm-composed-root` the default for `institute coherence`. Keep
`xcodebuild-merged` as an explicitly selected deprecated path. Record exact CI run IDs, commits,
receipt digests, and scoped limitations. Record that local composition supports explicit
multi-root source assignment, and that package tests remain separate verification actions.

Also in this PR's scope, as principal-controlled issue edits: correct #81's stale
`swift-institute/Workspace#80` reference, and confirm the separate local-composition issue
exists rather than widening #81's mission.

**Acceptance criteria**
- Default `coherence` selects SwiftPM.
- Explicit `--build-path xcodebuild-merged` still works during this stage.
- Documentation names the deletion gate.
- No receipt schema fork.
- Exact-head Ubuntu full-roster evidence is linked in the activation record.

**Weak-executor trap.** *Trap:* deleting the Xcode path in the activation PR. *Defusal:*
activation and deletion are separate lifecycle events (doctrine §10.10). T13 is blocked until
every deletion-gate item holds.

---

### T13 — Delete superseded paths

**Wave 9 · depends on: T12 and the full deletion gate · PR scope: removal only**

**Delete or modify:** the `xcodebuildMerged` case in `Institute.Coherence.BuildPath.swift` and
its `Run` arms; `Institute.Xcode.swift`, `Institute.Xcode.Build.swift`,
`Institute.Xcode.Scheme.swift` and their tests; the `Xcode Scheme` / `Xcode Workspace` product
dependencies in `institute/Package.swift`; the deprecated fixed-checkout composed-root wrapper;
the pairwise-only composition implementation; `--consumer` / `--dependency` parsing; the
deprecated `restore` and `verify` top-level verb aliases; stale documentation.

> Scope note beyond the source plan: `institute build` (the merged `xcodebuild` selection build)
> and `Institute.Xcode.Scheme` are separate capabilities from `coherence --build-path
> xcodebuild-merged`. **Do not delete `institute build` under this gate** unless a separate
> ruling retires it. The deletion gate below covers the coherence build path only.

**Deletion gate — all must already hold**
1. Ubuntu 6.3.3 full-inventory composed build passes on exact head.
2. macOS and Ubuntu calibration fixtures pass.
3. Mixed-root local composition passes.
4. The receipt schema is accepted and complete.
5. Pairwise compatibility fixtures prove equivalence to one-entry source maps.
6. Source, workflow, documentation, and issue searches show no required consumer of
   `xcodebuild-merged`.
7. The same for the pairwise-only flags and the `verify` / `restore` aliases.
8. No `Package.resolved` is added, modified, deleted, or committed.
9. The deletion PR's exact-head CI passes.

Textual absence alone is not the proof; it supplements build-level evidence (doctrine §3.3).

**Weak-executor traps**
- *Trap:* renaming repository directories while removing old path assumptions. *Defusal:* no
  rename is authorized anywhere in this programme.
- *Trap:* deleting authored typed-throws annotations because error cases disappeared.
  *Defusal:* remove obsolete cases only after checking every exact signature; never broaden.
- *Trap:* deleting local worktrees or registry roots as "cleanup". *Defusal:* T13 removes source
  and CLI compatibility code only. The workspace has worktrees across five roots, several
  `prunable`; every one of them is someone's live work.

---

## 6. Waves, dependencies, and honest concurrency

| Wave | Tasks | Depends on | Max concurrent editors | Why it serializes |
|---|---|---|---:|---|
| 1 | T1, T3 | gate (cleared) | 2 | disjoint files: new model vs. composed-root/workspace |
| 2 | T2, T9 | T1 | 2 | model vs. CLI exposure |
| 3 | T4, T5 | T2, T3 | 2 | build plan/rendering vs. receipt schema |
| 4 | **T6** | T4, T5 | 1 | **go/no-go gate**; SwiftPM semantics must settle first |
| 5 | T7, T8 | T6 | 2 | execution vs. verification transaction |
| 6 | T10 | T7, T8, T9 | 1 | one CLI file; help text and routing serialize |
| 7 | T11 | T10 | 1 | control-plane owner and full-roster evidence |
| 8 | T12 | T11 | 1 | single activation point |
| 9 | T13 | T12 + gate | 1 | removal |

**Read this honestly: the programme is largely serial.** Maximum concurrency is 2, reached in
four of nine waves; five waves admit exactly one editor. Assuming equal task cost, the
effective average is ≈1.4 concurrent editors over 13 tasks in 9 waves — a ~1.44× speedup at
best over pure serial execution. Two of the four "parallel" waves pair a model task with a CLI
task in a different repository, which is the only genuinely independent pairing.

Separately and absolutely: **at most one SwiftPM process runs at any time**, regardless of
editor concurrency. `--jobs` caps at `min(requested, hostCores)` = 8 on the primary machine.
The claim that "2–3 concurrent graphs" are useful is unmeasured and is not adopted.

---

## 7. Scope recommendation

**Recommendation: land T1–T4 and T6 as one increment, then stop and re-decide at the T6
result. Do not authorize T5 and T7–T13 yet.**

Reasoning:

1. **T6 is a genuine go/no-go.** S4 (transitive-remote override) and S5 (multi-root paths) are
   unmeasured, and the source ruling itself says the programme stops if they fail. Spending
   T7–T13 before that measurement risks the entire tail on an untested SwiftPM hypothesis. The
   increment is deliberately shaped to *end at the measurement*.
2. **The tail is #81's activation work, not local-development value.** G9 measured that the
   composed root already builds the full inventory. T11–T13 are Ubuntu evidence, default
   switching, and Xcode-path deletion — real work, but it delivers nothing to a developer
   working across two packages, and it is gated on a full-roster run that is independent of
   everything in T1–T4.
3. **T8 is the highest-risk task and delivers least early.** It must *introduce* a transaction
   the incumbent does not have (S6), across success, typed error, cancellation, and partial
   application. It is worth doing carefully once developers actually have multi-root
   composition to verify against — not before.
4. **T5 follows the measurement, not the model.** The receipt fields most worth adding
   (manifest-load duration, peak memory, exclusion reason codes) are the ones T6 and T11 will
   teach us the shape of.

The increment T1 → T3 → T2 → T4 → T6 is five PRs, three waves, and ends with a measured answer
to the one question the whole programme rests on. That is the right place to re-decide.

---

## 8. What remains genuinely blocking

Nothing blocks T1–T4.

| Blocked item | Blocking condition |
|---|---|
| T7 onward | S4 and S5 unmeasured until T6 runs on macOS **and** Ubuntu. |
| T11 onward | S8 unmeasured: no full-inventory Ubuntu receipt exists. |
| T13 | The nine-item deletion gate, none of which currently holds. |

Two items are referred to the principal as **ruling requests**, not resolved here:

- **RR-1 — documentation root.** `application/Documentation/` does not exist. Creating a second
  documentation root in the application repository is a boundary decision the documentation
  owner should make. Options: (a) create `Documentation/`; (b) publish as a `.docc` article in
  the existing catalogue; (c) publish to `swift-institute/Research`. Consequence of (a): a new
  docs surface with no generator and no CI check, which tends to go stale.
- **RR-2 — `institute build` and the Xcode surface.** T13 deletes the Xcode-backed *coherence*
  path. `institute build` (merged `xcodebuild` over the selection) and `Institute.Xcode.Scheme`
  are a separate capability with their own documented rationale. Retiring them needs its own
  ruling; this plan explicitly does not.
