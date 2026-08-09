# Adjudication 002 — Dependency Source Semantics and Declared-versus-Effective State

**Phase:** 0 — focused architectural adjudications
**Date:** 2026-07-24
**Blocks:** manifest-decoder consolidation (`Adjudication-001` slices 2–3)
**Method:** read-only inspection of Institute repositories, pre-existing generated state, and **authoritative SwiftPM source at `swift-6.3.3-RELEASE` (`5f6969f5b`)** — the exact tag of the installed toolchain — plus two coordinator-approved `dump-package` observations. No production source modified. Dirty graph migration preserved byte-for-byte.
**Path convention:** this repository is public; machine-specific path prefixes are rendered as `<developer-root>` deliberately (redacted 2026-07-26, per ADR-001).

> **Terminology correction (2026-07-27):** Workspace is process/application
> tooling above the three realised package layers, not part of a realised fourth
> or fifth package layer. The ownership conclusions in this adjudication are unchanged.

---

## Capability

Distinguishing, naming, and assigning ownership for the **four lifecycle-distinct
facts** about a package dependency that the current type system collapses into one
`Package.Dependency.Source` enum, and determining which of them SwiftPM can
actually report.

## Correct semantic owner

| Fact | Layer or role | Owner | Obtained from |
|---|---|---|---|
| Declared dependency source | 2 | `swift-spm-standard` | the portable `Package.swift` — **not** reliably from SwiftPM (see Q3/Q4) |
| SwiftPM-reported dependency location (**evaluated location**) | 2 | `swift-spm-standard` | `dump-package` |
| Resolved package state | 2 representation / 3 inspection | `swift-spm-standard` / `swift-package-manager` | `workspace-state.json` |
| Materialized source tree | 3 | `swift-package-manager` | scratch path + `subpath`, or the state's own absolute path |
| Comparison of all four | process/tooling | Workspace | composition |

## Current implementation or API

`Package.Dependency.Source` (`swift-spm-standard` `56f326cc5`,
`Package.Dependency.swift:41–58`) has three cases:

```swift
case path(Swift.String)                          // ".package(path:) for sibling-disk dependencies"
case url(URI, Package.Requirement)               // ".package(url:) with a typed version constraint"
case registry(Package.Identity, Package.Requirement)
```

Its doc comments describe **declaration** forms — *"the three SwiftPM
`Package.swift` dependency forms"*. `Package.Manifest`'s own doc comment
(`Package.Manifest.swift:20–21`) reinforces this: consumers *"read
`Package.Manifest` values instead of re-parsing `Package.swift` themselves."*

**But the only thing that ever populates it is `dump-package` output**, which is
not the declaration. That mismatch is the whole subject of this adjudication.

### Every production use of `Package.Dependency.Source`, classified

Exhaustive across the five inspected repositories.

| Site | Expression | Semantics the caller expects | Breaks under a declared/observed split? |
|---|---|---|---|
| `swift-spm-standard` › `Package.Dependency.Source+Codable.swift:29,48,50,64,74,77,81` | `Codable` round-trip over all three cases | **Wire round-trip only** — no semantic commitment | No. It is the thing being changed. |
| `swift-package-graph` › `Package.Graph.swift:61` | `for dependency in manifest.dependencies` → reads `$0.name` | **Identity only.** Never touches `.source` | **No.** Proven: `git grep '\.source' -- Sources` returns nothing in this package |
| `swift-package-graph` › `Package.Graph.swift:188` | `manifest.dependencies.compactMap { nodeByName[$0.name] }` | **Identity only** | No |
| `swift-impact` › `Impact.Run.MirrorVerification.swift:147` | `if case .url = dependency.source` | **Declaration truth** — *"does a dependent reference `upstream` by source-control rather than by path?"* | **No, but only by accident** — see below |
| `swift-package-manager` | — | Constructs `Source`; never reads it | No |
| `Workspace/Application` | — | **Zero uses.** Consumes only `Package.Manifest.name` (`Workspace.Doctor.swift:104`) | No |

`swift-impact` › `Impact.Run.PackageResult+JSON.swift:104` uses a type also spelled
`Source.Location`, but it is a **diagnostic** file/line/column location, unrelated
to `Package.Dependency.Source`. Excluded.

**Exactly one production call site reads `Package.Dependency.source`.** It survives
today only because it matches on the **case tag**, not the payload — and its own
source comments say it deliberately distrusts the payload:

> *"the **decoded** URL on a `.url(...)`-form `Package.Dependency` cannot be
> trusted to still read as the original git URL once the fix below is doing its
> job. This verification therefore sources the canonical upstream URL from the
> upstream repository's own `origin` remote … rather than from the
> already-resolved dependent-side manifest data."*
> — `Impact.Run.MirrorVerification.swift:31–41`

`swift-impact` has already independently discovered and worked around the defect
this adjudication is chartered to model. **That is corroboration from a second
package, not an assumption.**

## Observed gap

### The five concepts, defined and kept separate

#### 1. Declared dependency source

What the portable manifest expresses: canonical source-control URL + requirement,
registry identity + requirement, or a local filesystem dependency.

`Package.Dependency.Source` **does intend** to model this — its doc comments say
so explicitly. It is nonetheless **never populated from a declaration**, only from
`dump-package`.

#### 2. SwiftPM-reported dependency location — the correct name is **evaluated location**

Determined from authoritative source, not from key names.
`DefaultDependencyMapper.mappedDependency` (`Sources/PackageModel/DependencyMapper.swift:32–79` @ `swift-6.3.3-RELEASE`):

```swift
let dependencyLocationString = try self.normalizeDependencyLocation(…)      // 1. normalize
let mappedLocationString = self.identityResolver.mappedLocation(for: dependencyLocationString)  // 2. apply mirrors

if mappedLocationString == dependencyLocationString {
    return try .init(dependency, newLocationString: mappedLocationString)   // unmapped
} else if PackageIdentity.plain(mappedLocationString).isRegistry {
    return .registry(…)
} else if parseScheme(mappedLocationString) != nil {
    // mapped to a URL, we assume a remote SCM location
    return .remoteSourceControl(…)
} else {
    // mapped to a path, we assume a local SCM location
    let localPath = try AbsolutePath(validating: mappedLocationString)
    return .localSourceControl(…)
}
```

So `sourceControl.location.local` is produced **exactly when a mirror maps a
source-control location to a filesystem path**. It is therefore:

- **not a declaration** — the declaration was a URL;
- **not merely a fetch location** — it also determines the package's *identity*
  (see Q9);
- **precisely: a manifest-evaluation observation, after normalization and mirror
  substitution, under this machine's configuration.**

Proposed name: **evaluated location**. `effective source` is rejected as a name
here because it is not what the build compiles (concept 4).

Upstream acknowledges the modelling gap in the same file:

> *"SwiftPM can't handle file locations with `file://` scheme so we need to strip
> that. **We need to design a Location data structure for SwiftPM.**"*
> — `DependencyMapper.swift:111–112`

#### 3. Resolved package state

`workspace-state.json`, modelled upstream by `Workspace.ManagedDependency`
(`Sources/Workspace/ManagedDependency.swift` @ `swift-6.3.3-RELEASE`) as an
orthogonal pair:

`packageRef.kind` — `PackageReference.Kind` (`Sources/PackageModel/PackageReference.swift:21`):

| Case | Upstream doc |
|---|---|
| `.root(AbsolutePath)` | "A root package." |
| `.fileSystem(AbsolutePath)` | "A non-root local package." |
| `.localSourceControl(AbsolutePath)` | "A local source package." |
| `.remoteSourceControl(SourceControlURL)` | "A remote source package." |
| `.registry(PackageIdentity)` | "A package from a registry." |

`state` — `ManagedDependency.State`:

| Case | Upstream doc |
|---|---|
| `.fileSystem(AbsolutePath)` | "The dependency is a local package on the file system." |
| `.sourceControlCheckout(CheckoutState)` | "The dependency is a managed source control checkout." |
| `.registryDownload(version:scmUrl:)` | "…If the scmUrl is non-nil, the dependency has been mapped from a source control dependency." |
| `.edited(basedOn:unmanagedPath:)` | "…this dependency is being used for top of the tree style development." |
| `.custom(version:path:)` | — |

plus `subpath` — *"The checked out path of the dependency on disk, **relative to
the workspace checkouts path**."*

**Kind and state are orthogonal.** `localSourceControl` describes *where SwiftPM
fetches from*; `sourceControlCheckout` describes *what SwiftPM produced*.

#### 4. Materialized source used by the build — **proven, not inferred**

For `state == .sourceControlCheckout`, the compiled tree is
`<scratch>/checkouts/<subpath>`, **not** the reference location.

Evidence chain for `swift-paths` as a dependency of `swift-package-graph`, every
link observed:

| Stage | Value |
|---|---|
| 1. Declaration | `.package(url: "https://github.com/swift-foundations/swift-paths.git", branch: "main")` |
| 2. Mirror entry | `https://github.com/swift-foundations/swift-paths[.git]` → `<developer-root>/swift-foundations/swift-paths` (bare path, 2 spellings) |
| 3. `dump-package` | `sourceControl` · `location.local = ["<developer-root>/swift-foundations/swift-paths"]` · `requirement.branch = ["main"]` · `identity = swift-paths` |
| 4. `workspace-state.json` | `kind = localSourceControl`, `location = <developer-root>/…/swift-paths`, `state = sourceControlCheckout{branch: main, revision: 9bbec4478}`, `subpath = swift-paths` |
| 5. Materialized tree | `.build/checkouts/swift-paths`, HEAD **`9bbec44787745de50bc80ed8191d055ba51ed2b5`**, `origin → .build/repositories/swift-paths-ba386da9` (a bare cache clone) |
| 6. Mutable worktree HEAD | **`f20b5315f`** — **DIVERGED** |

Two further dependencies confirm it is not a one-off:

| Dependency | Compiled revision | Mutable worktree HEAD | |
|---|---|---|---|
| `swift-paths` | `9bbec4478` | `f20b5315f` | **diverged** |
| `swift-arguments` | `70a7ee69d` | `6afc83013` | **diverged** |
| `swift-file-system` | `fc6ca173e` | `bde096613` | **diverged** |

> **Item 6 of the required evidence is answered without modifying anything:
> editing the mirror-target worktree does NOT alter the source compiled by the
> existing root.** SwiftPM compiles a pinned clone, three revisions behind in this
> sample. This confirms — and does not contradict — the implementation plan §7.4.

**A mirror target must never be classified as the compiled source tree.**

#### 5. Workspace comparison

Four values, none collapsible:

```
declared source          — from the portable manifest
planned source           — what a Workspace context intends
evaluated location       — what dump-package reports on this machine
materialized source      — the tree the compiler reads
```

A context is *correct* when planned == materialized. A distribution is *portable*
when declared resolves cleanly with no mirrors. Those are different assertions
over different values, and the current single `Source` enum can express neither.

### `.package(path:)` versus mirror-transformed source control — **distinguishable**

Obtained from a genuine static fixture: `swift-foundations/swift-css/Tests`
declares `.package(path: "..")` alongside URL dependencies. One
coordinator-approved `dump-package` produced both shapes side by side:

```json
{ "fileSystem": [ {
    "identity": "swift-css",
    "path": "/fixture/checkouts/swift-css",
    "productFilter": null,
    "traits": [ { "name": "default" } ]
} ] }
```

```json
{ "sourceControl": [ {
    "identity": "swift-paths",
    "location": { "local": [ "/fixture/checkouts/swift-paths" ] },
    "productFilter": null,
    "requirement": { "branch": [ "main" ] },
    "traits": [ { "name": "default" } ]
} ] }
```

| | `.package(path:)` | mirror-transformed |
|---|---|---|
| Discriminator | `fileSystem` | `sourceControl` |
| Path field | `path` — **bare String** | `location.local` — **`[String]`** |
| **`requirement`** | **absent** | **present** |
| Resolved `kind` | `.fileSystem(AbsolutePath)` | `.localSourceControl(AbsolutePath)` |
| Resolved `state` | `.fileSystem(path)` — no checkout | `.sourceControlCheckout` — checkout at a pinned revision |
| Compiled tree | the declared path itself | `<scratch>/checkouts/<subpath>` |

**They are not equivalent, and the difference is exactly the requirement.** This
is why `Source.path(Swift.String)` cannot absorb `location.local`: it has nowhere
to put `branch: "main"`.

### Observed resolved-state census

Across **1,403** dependency records in 11 `workspace-state.json` files:

| `packageRef.kind` | count |
|---|---:|
| `localSourceControl` | 1,245 |
| `remoteSourceControl` | 158 |
| `fileSystem` / `registry` / `root` | **0** |

| `state.name` | count |
|---|---:|
| `sourceControlCheckout` | 1,403 |
| `fileSystem` / `edited` / `registryDownload` / `custom` | **0** |

Every observable dependency on this machine is a managed source-control checkout.

### A third location form — explained: package-scoped mirror precedence

> **Correction (2026-07-24).** This section previously attributed the form to
> stale-pin drift and recorded the mechanism as unproven. That hypothesis is
> **withdrawn**; the mechanism is now established, and it is not drift.

`swift-file-system` and `swift-spm-standard` resolve as
`kind = remoteSourceControl` with `location = file://<developer-root>/…`.
The **global** mirror map does map them to bare paths (all 1,256 targets are
bare paths; zero are `file://`), which would yield `localSourceControl` — but
the global map is not the one in force. A **package-scoped**
`.swiftpm/configuration/mirrors.json` in the consuming package takes
precedence, and its target is spelled `file:///…`. Per `DependencyMapper.swift:54`
a scheme-bearing mirror target yields `remoteSourceControl`.

The load-bearing semantic consequence:

| Mirror target spelling | Resolved `PackageReference.Kind` |
|---|---|
| bare path (`<developer-root>/…`) | `localSourceControl` |
| `file://<developer-root>/…` | `remoteSourceControl`, location `file://…` |

**`PackageReference.Kind` therefore cannot be read as "local versus remote
machine storage."** Both rows above are the same directory on the same disk;
only the mirror target's spelling differs. Any verification story that infers
locality from `kind` alone is unsound — it must read the location too.

## Proposed change

**Alternative B + C**: a lossless wire model inside `swift-spm-standard`,
projected into separate declared and observed values. No new package; both are
additive to the existing owner.

1. **Lossless wire layer.** A nested observation type inside `swift-spm-standard`
   that preserves the `dump-package` shape exactly — the `fileSystem` /
   `sourceControl` / `registry` discriminator, `location.remote` versus
   `location.local` including its array-of-string spelling, `requirement`,
   `identity`, `productFilter`, and per-dependency `traits`. Decoding is total: no
   fallback, no fabricated URL, no silent default.
2. **Projection, not replacement.** `Package.Dependency.Source` keeps its declared
   meaning. The evaluated location becomes a **separate value**, obtained only
   where an evaluation actually happened.
3. **Resolved state gains a representation.** `packageRef.kind` × `state` ×
   `subpath`, mirroring the upstream `ManagedDependency` model, in
   `swift-spm-standard`; inspection of the file in `swift-package-manager`.
4. **Materialized path is derived, never assumed.** From scratch path + `subpath`
   for checkouts; from the state's own absolute path for `fileSystem` and
   `edited(unmanagedPath:)`.

Exact Swift spellings are **not** fixed here. Repository convention
(`Nest.Name`, one type per file, typed throws) constrains the shape but not the
names, and naming should follow the slice that implements it.

## Why Workspace must not own it

All four facts are properties of an externally defined tool and its on-disk state.
Workspace's legitimate interest begins only at the **comparison** — which is
process/application policy and which it should own exclusively. If Workspace owned the
representations, every other consumer of the graph would depend on an application
to read a toolchain format, and `swift-impact` — which already needs exactly the
declared/observed distinction — would have to depend upward on Workspace to get
it. That is the cycle the layer rule exists to prevent.

## Dependency-layer impact

Unchanged from `Adjudication-001`, and no new edge:

```
swift-package-primitives (L1)
  → swift-spm-standard    (L2)   declared source, evaluated location, resolved state
    → swift-package-manager (L3) invocation, failure reporting, state inspection, path derivation
      → swift-package-graph (L3) discovery and graph construction — identity only
        → Workspace         (process/tooling) comparison and policy
      → swift-impact        (L3) already consumes graph + manager
```

`swift-package-graph` reads only `dependency.name`, so **none of this changes the
graph's API or behaviour**. `swift-impact`'s single `if case .url` site continues
to work and can later be tightened to ask its real question directly.

**No upward dependency. No cycle. No new package.**

## Tests proving the boundary

Specified, **not written**.

| # | Owner | Asserts |
|---|---|---|
| T-2 | `swift-spm-standard` | `location.remote` decodes to the canonical URL + requirement |
| T-3 | `swift-spm-standard` | `location.local` decodes losslessly: path **and** `branch:"main"` preserved; **never** yields `URI("")` |
| T-5 | `swift-spm-standard` | Genuine `fileSystem` record decodes to a path-form dependency **with no requirement**, distinct from T-3's value |
| T-6 | `swift-spm-standard` | A declared URL and an evaluated local location for the same identity are **not equal** and are separately retrievable |
| T-7 | `swift-spm-standard` | `products`, `targets`, `platforms`, and dependency-product back-fill survive a full dump (extends the existing passing tests to the new decode path) |
| T-8 | `swift-spm-standard` | `workspace-state.json` decodes across all five `kind` cases and all five `state` cases from minimized fixtures |
| T-4 | `swift-package-manager` | Delegation: invokes SwiftPM, returns the standard type; fixture must declare **at least one dependency** — the current fixture declares none |
| T-9 | `swift-package-manager` | Materialized path derivation: `sourceControlCheckout` → scratch + `subpath`; `fileSystem` → the declared path; `edited(unmanagedPath:)` → that path |
| T-1 | `swift-package-graph` | Real discovery preserves products, targets, platforms, back-fill |
| T-10 | `swift-package-graph` | Graph construction is unaffected by evaluated-location variation — same edges whether a dependency reports `remote` or `local` |
| T-11 | *deferred* | Identity differences across URL / mirror target / managed checkout / path dependency / editable — **cannot be written until an editable instance is observable** (see stop conditions) |

## Alternatives considered

| | Alternative | Verdict |
|---|---|---|
| **A** | Extend `Package.Dependency.Source` with local-source-control cases | **Rejected.** The type's documented meaning is *declared* source — the three `Package.swift` forms. A mirror-substituted location is not a declaration and does not appear in any manifest. Adding it makes the type mean "declared, or observed, depending on how it was populated", which is the ambiguity being resolved |
| **B** | Lossless `dump-package` wire model inside `swift-spm-standard` | **Accepted, in part.** Preserves the local/remote/fileSystem distinction exactly and is a type addition inside the existing owner |
| **C** | Split declared and observed values | **Accepted, in part.** Declared comes from the portable manifest; observed only from an evaluation. **Either can be absent**: observed is absent when no evaluation ran; declared is absent when only `dump-package` output is available (Q4) — so both must be optional at their boundaries |
| **D** | One dependency value with identity, requirement, declared source, reported location, and resolved state as separate fields | **Rejected as the primary model.** It mixes lifecycle phases in one value, so every consumer must know which fields are populated. Comprehensiveness is not the test. It may be right for a Workspace-owned *report* row — process/tooling, not Layer 2 |
| **E** | Fabricate a `file://` projection for `location.local` | **Rejected as authoritative.** It invents wire content and erases declared-versus-observed. Narrowly permissible only as an explicitly named, lossy, one-way convenience — never the decode result. Note SwiftPM itself *strips* `file://` on input (`DependencyMapper.swift:113–122`), so round-tripping through it is not even faithful to the tool |

## Migration impact

**The supervisory correction to the implementation order is confirmed by the
evidence, and I would have had to make it.**

`Adjudication-001` proposed representation last. That order contains a state where
`Package.Manager` delegates to a decoder that throws `keyNotFound("remote")` on
`location.local` — which is **1,245 of 1,403** observed dependency records.
Manifest loading would fail for essentially every package graph on this machine.

### Revised sequence

| # | Slice | Owner | Why it must precede the next |
|---|---|---|---|
| 1 | **Representation** — lossless wire + evaluated location + resolved state | `swift-spm-standard` | Nothing can decode losslessly until a lossless target type exists |
| 2 | **Lossless decoding** onto it, incl. `location.local`, with T-2/T-3/T-5/T-6/T-7/T-8 | `swift-spm-standard` | Delegation must have something correct to delegate to |
| 3 | **Operational delegation** — `Package.Manager` invokes and delegates; its hand walk deleted; T-4 | `swift-package-manager` | The graph consumes this |
| 4 | **Graph integration test** T-1, T-10 against the dirty tree | `swift-package-graph` | Proves composition before the commit is blessed |
| 5 | **Commit the graph migration** unchanged | `swift-package-graph` | Its upstream is now correct |

**No intermediate state in this sequence** has `Package.Manager` failing on
mirrored graphs, silently producing `URI("")`, reporting a mirror target as
compiled source, losing manifest content, or committing the migration before its
upstream is available.

One tension worth naming: `swift-package-graph` **does not compile at HEAD**
(`Adjudication-001` G-1), so the migration is load-bearing today and slices 1–3
gate it. That is tolerable because the migration remains in the working tree and
the graph builds there — verified, exit 0. If slices 1–3 stall, the graph's HEAD
stays broken; that is a schedule risk, not a correctness one.

Slice 3 also **fixes** a latent defect rather than introducing one: after it,
`Package.Manager` no longer yields empty URIs.

## Stop condition or unresolved evidence

### Met, qualified — canonical declared source is not recoverable *from SwiftPM*

`mappedDependency` discards `dependencyLocationString` and returns only
`mappedLocationString`. **No field of `dump-package` output retains the canonical
URL after mirror substitution** (Q3: no). The full 12,079-byte dump was searched;
the mapped identity and location are all that survive.

Recovery is possible, but **only outside SwiftPM**, by one of:

1. the dependency repository's own `origin` remote — what `swift-impact` does, and
   what works **only because of an ecosystem convention** ([PKG-DEP-009], the
   dependency-spelling guard) that every manifest declares Institute packages by
   their GitHub `origin` URL. It is a convention, not a SwiftPM guarantee;
2. parsing `Package.swift` source — explicitly out of scope;
3. inverting the mirror map — many-to-one, and 18 entries are renames;
4. disabling mirrors — forbidden.

**This is reported rather than worked around.** The consequence for the model:
*declared source cannot be a required field of a value decoded from
`dump-package`.* It must be absent-able and separately sourced. That is
Alternative C, and it is why A and D fail.

### Unresolved — editable state cannot be distinguished from stale artifacts

**Zero** `edited` states exist in 1,403 observed records, while
`Workspace/Application/Packages/swift-git` is a live `swift package edit --path`
symlink whose resolver state says `remoteSourceControl` (Gate 0A §3.3). The model
distinguishes them — `.edited(basedOn:unmanagedPath:)` versus a stray directory —
but **no empirical instance exists to test against**, and `edit`/`unedit` are
retired by the coordinator, so one cannot be created within policy.

T-11 and any editable-state verification are **blocked on evidence**, not on
design. Recorded as the next evidence gap.

### Mildly met — incompatible documented semantics

`Package.Manifest` and `Package.Dependency.Source` document themselves as
representing the developer's declaration, while being populated exclusively from
`dump-package`. The proposed change resolves this by making the intent true and
sourcing the observation separately.

### Checked and NOT triggered

| Condition | Result |
|---|---|
| Actual compiled source cannot be identified | **No.** `<scratch>/checkouts/<subpath>`, verified against a real checkout's HEAD |
| `.package(path:)` and mirror-transformed indistinguishable | **No.** Distinct discriminator, distinct path spelling, and only one carries a requirement |
| Correct model requires an upward dependency | **No** |
| A new package appears necessary | **No.** Both additions land in `swift-spm-standard` |
| Authoritative SwiftPM behaviour contradicts the implementation plan | **No — it confirms it.** Plan §7.4's claim that mirrors do not cause SwiftPM to compile the mutable worktree is verified at source and by three diverged revisions |

### Single-version evidence

All observations are Apple Swift 6.3.3 (`swiftlang-6.3.3.1.3`),
`arm64-apple-macosx26.0`, against SwiftPM source at `swift-6.3.3-RELEASE`
(`5f6969f5b`). Behaviour on other toolchains is untested. The upstream FIXME at
`DependencyMapper.swift:112` suggests this area is expected to change, which is an
argument for a lossless wire layer that can absorb a shape change without
disturbing the semantic types above it.

---

## Answers to the critical questions

1. **Is `Package.Manifest` intended to represent the declared manifest or `dump-package` output?** Its documentation says the declaration; its only population path is `dump-package`. Today it is ambiguous, and that ambiguity is the blocker.
2. **Can it truthfully represent both without separating declared and observed source?** **No.** On this machine 1,245 of 1,403 records carry a location the declaration never contained.
3. **Does `dump-package` retain the canonical URL anywhere after mirror substitution?** **No.** Proven at `DependencyMapper.swift:41–45`; the original string is discarded.
4. **Can the canonical declaration be recovered without parsing `Package.swift` or disabling mirrors?** **Only via ecosystem convention** — the dependency repository's own `origin`. Not from SwiftPM.
5. **Is `workspace-state.json` authoritative for effective resolution?** Authoritative for *managed dependency state*; **not self-sufficient** for the compiled path.
6. **Does it identify the actual compiled checkout path?** **No.** `subpath` is relative to the checkouts directory; a second step supplies the scratch path.
7. **Is `localSourceControl` a local mutable dependency, a local fetch source, or a managed-checkout category?** **A local fetch source.** It is a `PackageReference.Kind` — where SwiftPM fetches from. What it produced is the orthogonal `state`, here always `sourceControlCheckout`. It is emphatically **not** a mutable local dependency: the compiled tree diverged from the worktree in all three sampled cases.
8. **How are `.package(path:)`, mirrors, and editable represented differently?** `fileSystem` kind + `fileSystem` state + no requirement + compiles the path directly; `localSourceControl` kind + `sourceControlCheckout` state + a requirement + compiles a pinned clone; `edited` state with `basedOn` and optional `unmanagedPath` — modelled upstream, **unobserved here**.
9. **Which identity is attached to each stage?** One identity throughout, and it is computed **from the mapped location**: `DefaultIdentityResolver.resolveIdentity(for url:)` maps the URL, and if the result validates as an `AbsolutePath` returns `PackageIdentity(path:)` — i.e. **the directory basename** (`IdentityResolver.swift:52–59`). This is the authoritative confirmation of the empirical finding in Gate 0A §1.3.
10. **What must be persisted versus re-inspected?** Persist only what cannot be re-derived: the declared source (unavailable from SwiftPM) and Workspace's own planned source. Re-inspect everything SwiftPM owns — evaluated location, resolved state, materialized path — because `Package.resolved` demonstrably drifts from what current configuration would produce.

---

## Recommendation

> # Approve with specified conditions
>
> Approve the **B + C** model: a lossless `dump-package` wire representation inside
> `swift-spm-standard`, projected into **separate** declared and observed values,
> with resolved state modelled at Layer 2 and inspected at Layer 3. Reject
> Alternative A (corrupts the declared meaning of `Package.Dependency.Source`),
> Alternative D as the primary model (mixes lifecycle phases), and Alternative E as
> an authoritative decode result.
>
> **Conditions:**
>
> 1. Implementation follows the revised order — representation → lossless decoding
>    → operational delegation → graph integration test → graph migration commit.
>    The prior order is confirmed unsafe.
> 2. Declared source is modelled as **absent-able**, because it is not recoverable
>    from SwiftPM under active mirrors.
> 3. No decode path may produce `URI("")`, a fabricated `file://` URL, or any
>    silent default.
> 4. The materialized source path is always **derived and verified**, never
>    equated with a mirror target.
> 5. Editable-state verification (T-11) is deferred until an editable instance is
>    observable within policy. This is an evidence gap, and it should be recorded
>    as the next one to close.
>
> No production implementation is authorized by this adjudication.
