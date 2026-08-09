# Baseline Build and Test Evidence

**Gate:** 0A — correction slice
**Executed:** 2026-07-24, 12:24–12:43 UTC
**Scope:** nine decision-driving owner packages, reduced from twenty-three
**Coordinator:** `<developer-root>/swift-institute/Scripts/swift-build`
**Path convention:** this repository is public; machine-specific path prefixes are rendered as `<developer-root>` deliberately (redacted 2026-07-26, per ADR-001).

---

## 0. Evidence label — read this before citing any result below

> ### `current machine resolution baseline`
>
> Every result in this document was produced on a machine with an **active SwiftPM
> mirror configuration** (`~/.swiftpm/configuration/mirrors.json`, 1,256 entries
> redirecting canonical GitHub URLs to local directories under
> `<developer-root>/`), against **pre-existing warm `.build` directories**.
>
> These results are **not**:
> - canonical URL validation;
> - remote-only validation;
> - clean-consumer validation;
> - proof of release readiness;
> - clean-room compilation evidence.
>
> A pass here means: *this package compiles and its tests pass, on this machine,
> with these mirrors, over this incremental build state.* Nothing more.

## 1. Scope reduction

The correction brief originally required twenty-three repositories. The correction baseline was reduced to nine decision-driving owner packages; all claims based on omitted packages were downgraded to `unresolved`. The nine retained are those whose Owner Capability Matrix rows drive Gate 0A
adjudication; the stated grounds for omitting the other fifteen were that they all
carry `no change / no gap` dispositions and that no Gate 0A decision turns on their
build state.

> **Provenance of the scope reduction.** The reduction was directed by an instruction
> received in this working session, headed *"Principal ruling — Gate 0A baseline scope
> reduced from 23 to 8 packages"*, which enumerated the nine packages to baseline and
> prescribed the `unresolved` disposition and its exact wording for the remainder. That
> instruction's authority is **not independently verifiable from the relayed supervisory
> record**, so this document does not assert it as a principal ruling. It records the
> reduction as a scope decision taken on instruction, and the evidence stands on its own
> terms regardless of provenance.

This document records the reduction as a **deliberate decision**, not an omission.
The consequence for the matrix — fifteen packages' rows downgraded to
`unresolved` — is applied in `Owner Capability Matrix.md` §0.3 and listed in §7
below.

## 2. Execution environment

| Field | Value | Source |
|---|---|---|
| Swift toolchain | `Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)` | coordinator-written stamp `.build/coordinator-compiler-version` |
| Target triple | `arm64-apple-macosx26.0` | same stamp |
| Xcode | `26.6 (17F113)` | `version.plist` under `xcode-select -p`. **`xcodebuild` was not invoked** — the coordinator guard forbids direct invocation and provides no version-report action. |
| Declared requirement | Swift `6.3.3`, Xcode `26.6` | `Workspace.json` |
| Coordinator slots | 2 | `swift-build status` |
| Jobs per SwiftPM build | 3 | `swift-build status` |
| Coordinator state root | `/private/tmp/swift-institute-build-coordinator-v1` | `swift-build status` |

Toolchain and declared requirement agree.

## 3. Commands

Exactly two command forms were issued, per package:

```
<developer-root>/swift-institute/Scripts/swift-build package build --package-path <abs>
<developer-root>/swift-institute/Scripts/swift-build package test  --package-path <abs>
```

`--package-path` here is the **coordinator's own** argument, not a pass-through
SwiftPM option; the coordinator's `FORBIDDEN_SWIFTPM_OPTIONS` set rejects
caller-supplied `--package-path` in the SwiftPM argument tail only. No pass-through
argument was supplied. `swift build`, `swift test`, `swift package`, and
`xcodebuild` were never invoked directly.

Working directory for each invocation was the repository's package directory,
identical to the `--package-path` value.

**No coordinator refusal occurred.** Every one of the eighteen invocations was
accepted and executed.

## 4. Results

All nine packages: **build exit 0, test exit 0.** 142 tests, zero failures, zero
compiler warnings.

| Repository | Revision / dirty fingerprint | Build command | Build result | Test command | Test result | Tests executed | Resolution mode | Generated state | Notes |
|---|---|---|---|---|---|---:|---|---|---|
| `swift-institute/Workspace/Application` | `ef0579a8b1e9a1c67ede5f68a83eed82d01da217` | `swift-build package build --package-path …/Workspace/Application` | **exit 0**, 127s | `swift-build package test --package-path …` | **exit 0**, 41s | 27 in 21 suites | cache only | `.build/` (ignored) | Longest build in the set |
| `swift-foundations/swift-package-manager` | `d3dd30904d2645a8a124e989494ef4edab2457af` | `… package build --package-path …/swift-package-manager` | **exit 0**, 122s | `… package test --package-path …` | **exit 0**, 21s | 1 in 0 suites | cache only | `.build/` (ignored) | Single test for the package's single operation |
| `swift-standards/swift-spm-standard` | `56f326cc5fe65046ff31f1112f38302fc25133b0` | `… package build --package-path …/swift-spm-standard` | **exit 0**, 64s | `… package test --package-path …` | **exit 0**, 10s | 55 in 4 suites | cache only | `.build/` (ignored) | Densest test surface in the set |
| `swift-foundations/swift-package-graph` | `a76186a9b08c8aaab943c40dbb801076678a99a4` **+ uncommitted migration**, diff SHA-256 `31347669…40a3b84` | `… package build --package-path …/swift-package-graph` | **exit 0**, 196s | `… package test --package-path …` | **exit 0**, 29s | 21 in 2 suites | cache only, incl. one **un-mirrored URL-form** dependency | `.build/` (ignored) | **See §6 — passes; manifest-content preservation is untested** |
| `swift-foundations/swift-git` | `a9955a9d910b82d6d9fb9a28b6602e4ffc7c57ec` | `… package build --package-path …/swift-git` | **exit 0**, 48s | `… package test --package-path …` | **exit 0**, 11s | 3 in 3 suites | cache only | `.build/` (ignored) | 3 tests for 16 client operations |
| `swift-standards/swift-git-standard` | `ed8b3796c729c3eac07ff32a41c7cfa6d8f7e208` | `… package build --package-path …/swift-git-standard` | **exit 0**, 1s | `… package test --package-path …` | **exit 0**, 1s | 6 in 8 suites | none | `.build/` (ignored) | Fully warm; no dependencies |
| `swift-foundations/swift-xcode` | `83b6627d999f48ae1db14cf8ab591bb4e742d537` | `… package build --package-path …/swift-xcode` | **exit 0**, 74s | `… package test --package-path …` | **exit 0**, 16s | 2 in 0 suites | cache only | `.build/` (ignored) | 2 tests across 2 products |
| `swift-standards/swift-xcode-standard` | `d336477d250498f30408dacd1feb0025f003bef5` | `… package build --package-path …/swift-xcode-standard` | **exit 0**, 2s | `… package test --package-path …` | **exit 0**, 1s | 2 in 0 suites | none | `.build/` (ignored) | Fully warm; no dependencies |
| `swift-foundations/swift-impact` | `41e95a126bb21cda1de31e74e517c0d430338b7d` | `… package build --package-path …/swift-impact` | **exit 0**, 30s | `… package test --package-path …` | **exit 0**, 28s | 25 in 10 suites | cache only | `.build/` (ignored) | Includes live mirror-verification and lock-concurrency tests |

**Totals:** build 662s, test 158s, **142 tests, 0 failures**.

### 4.1 Out-of-scope package completed in flight

`swift-foundations/swift-manifests` @ `5078007de72c23a7e699f8addab588cf9ae7ed0c`
was already executing when the scope reduction landed. It was allowed to finish
rather than be killed mid-build:

- build **exit 0**, 25s
- test **exit 0**, `Test run with 21 tests in 13 suites passed after 305.585 seconds`

Its slowest test — `driver shim round-trips Int through swift run subprocess`
(305.58s) — exercises the generated-eval-project materializer described in Owner
Capability Matrix §3.4. Recorded as a bonus data point; **`swift-manifests` is not
in the nine-package baseline scope** and its matrix rows are not upgraded on the
strength of it.

## 5. Resolution mode and network access

**No network transfer occurred in any invocation.** Every `Fetching` line across
all logs is either a local mirror-target path or carries the `from cache` suffix.

Two lines lack `from cache`:

```
Fetching <developer-root>/swift-foundations/swift-process
Fetching <developer-root>/swift-foundations/swift-dependencies
```

Both are **local filesystem paths** — a first population of the local SwiftPM
repository cache from a mirror target, not a remote fetch.

Two lines carry an `https://` URL, and both are cache-served:

```
Fetching https://github.com/swift-foundations/swift-package-manager.git from cache
Fetching https://github.com/swiftlang/swift-syntax.git from cache
```

> **Correction to the driver's own labelling.** The collection script classified
> `swift-package-graph`'s build as `resolution=network` on a heuristic that
> matched `Fetching https://`. That is a **false positive**. The line carries
> `from cache`; no bytes crossed the network. The corrected label for that row is
> **"cache only, including one un-mirrored URL-form dependency"**.
>
> The underlying observation is nonetheless meaningful: `swift-package-manager` is
> one of the eight packages **absent from the mirror map**, so the in-flight
> `swift-package-graph` migration introduces a dependency that resolves by
> canonical URL rather than by mirror substitution. On a cold cache that edge
> *would* require network access.

## 6. `swift-package-graph` — dirty-state result, reported separately

### 6.1 The migration builds and its tests pass

> **Framing corrected 2026-07-24** (`Adjudication-001`). Earlier drafts of this
> section called the migration a *regression* or *regression risk*. That is
> inaccurate. The deleted decoder recovered **exactly the same fields** as the
> `Package.Manager` decoder it delegates to — neither reads `products`, `targets`,
> `platforms`, or the dependency-product back-fill. The migration is therefore
> **field-neutral**, and the weakness it inherits **predates it**. What remains true,
> and is the evidence this section exists to record, is that **manifest-content
> preservation is untested** at every layer of the graph's suite.

| Question | Answer |
|---|---|
| Does the current dirty state **build**? | **Yes** — exit 0 in 196s |
| Does it **pass tests**? | **Yes** — 21 tests in 2 suites, exit 0 in 29s |
| Does it **fail because of the decoder migration**? | **No** |
| Does it **pass without covering manifest-content preservation**? | **Yes — no test asserts products, targets, platforms, or back-fill** |

### 6.2 Dirty state verified unchanged across execution

| Field | Before baseline | After baseline |
|---|---|---|
| HEAD | `a76186a9b08c8aaab943c40dbb801076678a99a4` | `a76186a9b08c8aaab943c40dbb801076678a99a4` |
| `git diff --binary` size | 15,477 bytes | 15,477 bytes |
| `git diff --binary` SHA-256 | `3134766944144ab819a5311dc162f79a5fcb36790af4839a4d40159a240a3b84` | `3134766944144ab819a5311dc162f79a5fcb36790af4839a4d40159a240a3b84` |
| Changed paths | `M Package.swift`, `D Sources/Package Graph/Package.Manifest.Decode.swift`, `M …/Package.Workspace.Error.Kind.swift`, `M …/Package.Workspace.swift` | identical |

`cmp` reports the two patches byte-identical. **The baseline is validly tied to
this exact dirty state.**

### 6.3 A passing suite does not dispose of the manifest-content question — proven, not asserted

The brief requires that a passing suite dispose of the manifest-content question
only if a test proves `Package.Graph.manifest(for:)` preserves products, targets,
platforms, and the dependency-product back-fill. **No such test exists** — before
or after the migration.

Evidence, from the test sources at `a76186a9b` + migration:

```
grep -n '\.products\|\.targets\|\.platforms\|Dependency.products\|backfill\|back-fill'
      Tests/*/*.swift
→ NO MATCHES
```

Two independent reasons the suite cannot detect manifest-content loss:

1. **`Package.Graph.Tests.swift` never decodes anything.** It constructs
   `Package.Manifest(...)` values directly in memory
   (`Package.Graph.Tests.swift:29,69,112,128,186,216,245`) and feeds them to
   `Package.Workspace(root:manifests:)`. The decoder is not on the path at all.
   Its only manifest-content assertion is a nil-check:
   `#expect(graph.manifest(for: "swift-leaf") != nil)` (`Package.Graph.Tests.swift:40`).
2. **`Package.Workspace.Discover.Tests.swift` does decode, but asserts only counts
   and adjacency.** Its three passing tests are *"minimal workspace yields one
   manifest"*, *"chain workspace yields three manifests with correct adjacency"*,
   and *"diamond workspace yields four manifests, no cycles"*. A decoder that
   returned every manifest with empty `products`, empty `targets`, and nil
   `platforms` would pass all three.

By contrast, `swift-spm-standard`'s suite **does** cover exactly this behaviour —
*"Package.Manifest decodes a full dump-package output (products + targets +
platforms)"* and *"Package.Manifest decode populates Dependency.products from
target edges"*. That is coverage the graph does not inherit.

> **Corrected by `Adjudication-001-Manifest-Decoding-Ownership.md` (2026-07-24).** The deleted graph decoder was **field-for-field identical** to `Package.Manager`'s: neither reads `products`, `targets`, `platforms`, or the back-fill. The migration is therefore **field-neutral, not a regression** — it consolidates two equally weak decoders. It is also **necessary**: the deleted decoder constructs `.path(Paths.Path)` against a standard whose case is `.path(Swift.String)` since `swift-spm-standard` `56f326c`, so it no longer type-checks. The real defect is older and separate — neither operational decoder uses `swift-spm-standard`'s `Codable` conformance, and both silently yield `URI("")` for mirror-transformed dependencies.


### 6.4 Next adjudication input — recorded, not written

> **Missing test.** A `swift-package-graph` test that loads a real fixture package
> through the discovery path and asserts that `Package.Graph.manifest(for:)`
> returns non-empty `products`, non-empty `targets`, a non-nil `platforms`, and a
> populated `Package.Dependency.products` back-fill.
>
> Per the correction brief this test was **not written** and the migration was
> **not modified**. It became the input to `Adjudication-001`, which concluded that
> `Package.Manager.manifest(at:)` should invoke SwiftPM and delegate decoding to
> `swift-spm-standard` — and to `Adjudication-002`, which resolves the source
> representation that delegation depends on.

## 7. Repositories that remain untested, and why

Fourteen supporting packages were in the original twenty-three-package scope and
were **not** baselined. `swift-manifests` was executing when the ruling landed and
completed (§4.1), so it is untested-by-scope but has an incidental passing result.

| Package | Matrix disposition | Reason not baselined |
|---|---|---|
| `swift-foundations/swift-file-system` | no change / no gap | scope reduction |
| `swift-foundations/swift-paths` | architectural adjudication required (path-vocabulary split) | scope reduction |
| `swift-foundations/swift-process` | no change / no gap | scope reduction |
| `swift-foundations/swift-json` | no change; one `investigate in empirical spike` row | scope reduction |
| `swift-foundations/swift-xml` | no change / no gap | scope reduction |
| `swift-foundations/swift-arguments` | one `investigate in empirical spike` row | scope reduction |
| `swift-foundations/swift-environment` | extend existing owner | scope reduction |
| `swift-foundations/swift-github` | no change / no gap | scope reduction |
| `swift-foundations/swift-github-http` | no change / no gap | scope reduction |
| `swift-standards/swift-github-standard` | no change / no gap | scope reduction |
| `swift-primitives/swift-package-primitives` | no change / no gap | scope reduction |
| `swift-primitives/swift-graph-primitives` | no change / no gap | scope reduction |
| `swift-primitives/swift-path-primitives` | not cited by any matrix row | scope reduction |
| `swift-foundations/swift-manifests` | architectural adjudication (coordinator bypass) | out of scope; completed in flight, §4.1 |

None was refused by the coordinator. None failed. **They were not attempted.**

## 8. Mutation audit

**No tracked file was modified by any baseline command.** Verified per invocation
by comparing `git status --porcelain` minus untracked entries, before and after,
and by comparing HEAD before and after.

| Repository | HEAD moved | Tracked changes before → after | Untracked created |
|---|---|---|---|
| `swift-institute/Workspace` | no | none → none | none (the pre-existing `?? Research/` is this audit's own artifacts) |
| `swift-foundations/swift-package-manager` | no | none → none | none |
| `swift-standards/swift-spm-standard` | no | none → none | none |
| `swift-foundations/swift-package-graph` | no | 4 (migration) → 4 (identical) | none |
| `swift-foundations/swift-git` | no | none → none | none |
| `swift-standards/swift-git-standard` | no | none → none | none |
| `swift-foundations/swift-xcode` | no | none → none | none |
| `swift-standards/swift-xcode-standard` | no | none → none | none |
| `swift-foundations/swift-impact` | no | none → none | none |

**Generated state.** Each invocation wrote into that package's `.build/` directory
— object files, module caches, `workspace-state.json`, `checkouts/`,
`repositories/`, and the coordinator's `coordinator-compiler-version` stamp. Some
also regenerated `Package.resolved`. **Both `.build/` and `Package.resolved` are
recursively ignored in every repository**, verified pre-flight with
`git ls-files --error-unmatch Package.resolved` and `git ls-files '*Package.resolved'`,
both empty in all 23 repositories. No `Package.resolved` was read, committed,
staged, hand-edited, copied, or deleted.

**Nothing was cleaned, reset, updated, edited, unedited, checked out, switched,
stashed, or committed. Mirror configuration and scratch-path policy were not
touched.**

## 9. Execution-integrity notes

Two process-level issues arose and are recorded because they affect how this
evidence should be read.

### 9.1 The first run was reported orphaned; it was not

Supervisory review reported the first background run as orphaned with no
completion record. **Inspection showed it was still alive** — driver PID 86669,
mid-`swift-manifests test`, with 13 result rows already written. The harness had
marked its shell task and monitor stopped while the underlying process continued.

Remediation: partial results were copied aside
(`baseline-results.partial.tsv`, `progress.partial.log`) **before** anything else,
then the two driver shells were terminated with `SIGTERM` while the in-flight
coordinator child was left to finish cleanly. No result was lost and no build was
interrupted mid-compile.

The `exit code 144` reported for that background task is `128 + 15` — the SIGTERM
this slice sent deliberately. It is not a build failure.

### 9.2 The driver truncated its own result file on startup

`baseline.sh` opened `baseline-results.tsv` with `>`, so a naive re-run would have
discarded the thirteen completed rows. Fixed before resuming:

- the header is written **only when the file does not exist**;
- an `already_recorded` guard skips any `(repository, phase)` pair already present.

The guard was **verified before use**: re-running `swift-foundations/swift-git`,
already recorded, emitted two `SKIP (already recorded)` lines and left the file at
fourteen lines unchanged.

### 9.3 Builds are incremental, not clean

Every package had a warm `.build` directory. `swift-git-standard` (1s) and
`swift-xcode-standard` (2s) were essentially no-ops. Per
`<developer-root>/CLAUDE.md`, *"a cached build is not fresh compilation
evidence"* — so these results attest that **nothing has regressed since each
package was last built**, not that each compiles from scratch. A clean-room
baseline would be a separate, and much longer, exercise.

## 10. Artifact locations

Raw logs, one per repository-phase, with a header block recording repository, git
root, working directory, HEAD before, exact command, start time, and a footer
recording finish time, exit status, elapsed seconds, HEAD after, and tracked-mutation
verdict:

```
<session scratchpad>/logs/<repo-slug>.{build,test}.log
<session scratchpad>/baseline-results.tsv
<session scratchpad>/baseline-results.partial.tsv   (pre-reduction snapshot)
<session scratchpad>/package-graph-dirty.patch      (pre-baseline)
<session scratchpad>/package-graph-dirty-post.patch (post-baseline, byte-identical)
```

These are session-scoped. The evidence they support is reproduced in full above so
this document stands alone for supervisory review.
