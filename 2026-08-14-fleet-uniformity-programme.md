> Commissioned exploratory research, delivered 2026-08-14. Committed to Research by the CI programme coordinator. Ratification and sequence: https://github.com/swift-institute/institute-continuous-integration/issues/35#issuecomment-5293015006

# Swift Institute Fleet-Uniformity Programme  
## Read-only design and inventory report

**Evidence cutoff:** 14 August 2026  
**Mutation verdict:** **NO-GO**  
**Design verdict:** **Owner-first architecture decided; fleet inventory not yet transaction-complete**

### Evidence notation

- **PROVED** — established from an exact repository revision or live GitHub state.
- **INFERENCE** — conclusion drawn from cited facts.
- **PROPOSAL** — recommended terminal design.
- **UNMEASURED** — required evidence could not be obtained and must not be treated as success.

### Inspection limitation

The requested workspace, the local workspace, was not mounted in this execution environment. I therefore could not:

- read the workspace-local `AGENTS.md`;
- execute the local Institute coordinator or `institute doctor`;
- inspect local dirty, untracked, or ignored state;
- freeze and inspect all 453 package checkouts locally;
- produce the mandatory complete current-head, repository-by-repository matrix.

I did inspect the committed Institute architecture, composition, decomposition, CI/CD, GitHub, Institute, and instrument-trap skills at `swift-institute/Skills@85d4d129e6b7b87dbf98bffbc9f06bdd8efa5538`, together with SHA-pinned repository content and authenticated live GitHub facts.       

That limitation does not prevent deciding the terminal architecture. It does prevent issuing the implementation green light.

---

# 1. Executive verdict

## 1.1 Overall verdict

**The programme is not safe to implement yet.**

Four independent blockers remain:

1. **The active terminal-caller cutover has not issued its terminal closure receipt.** Issue `swift-institute/.github#574` remains open. The reusable runtime and broad `.github` reduction have landed, but package-head convergence is still an active transaction.   
2. **The current fleet matrix is incomplete.** The authoritative manifest identifies 453 package coordinates, but current visibility, archival state, exact default-branch SHA, hosted-CI participation, nested configurations, and tracked-ignore findings have not been recensed for every coordinate.
3. **The landed Gitignore canon has the correct semantic owner but the wrong policy shape.** Its package policy is a repository allowlist beginning with `*`, whereas this programme expressly requires a conservative denylist.    
4. **Typed centralized SwiftLint/swift-format rendering is not yet landed.** The relevant ICI PR remains open and its profile bytes are deliberately unavailable/fail-closed. Explicit universal invocation is also still open.   

## 1.2 Decided terminal direction

The smallest coherent end state is:

```text
institute-continuous-integration
    owns:
        canonical Gitignore policy
        canonical SwiftLint profile
        canonical swift-format profile
        typed repository-class deltas
        rendering
        checkout validation
        drift findings

swift-institute/.github
    owns:
        GitHub triggers
        permissions
        verified ICI acquisition
        invocation of those operations
        existing ci-ok aggregation

package repositories
    contain:
        one exact generated root .gitignore
        no package-local SwiftLint configuration
        no package-local swift-format configuration
        the already-ratified one-hop ci.yml caller
```

The implementation should be **owner-first, followed by one bounded mechanical package wave**. It should not be implemented as a monolithic transaction that changes central policy and 453 package heads simultaneously.

## 1.3 Decisive rulings

- **`.gitignore`:** generated into each package and validated byte-for-byte, because Git itself requires repository-local ignore policy for normal developer operation.
- **SwiftLint and swift-format:** consumed from generated, digest-bound transient paths by explicit command-line arguments; no package-root copies.
- **CI gate:** implemented in the existing ICI-backed reusable workflow, without introducing another required check.
- **`swift-linter`:** not the owner of Gitignore or tool-configuration validation. Those are repository/index/configuration semantics, not Swift syntax semantics.
- **Tracked cleanup:** exact, adjudicated per-path removal only. Never `git clean`, never “delete everything ignored,” and never infer obsolescence from a path name alone.
- **Exceptions:** typed central policy deltas only. No free-form local suffix in `.gitignore` and no local SwiftLint/swift-format override files.

---

# 2. Authoritative population and population digest

## 2.1 Manifest authority

**PROVED:** The canonical package inventory inspected was:

```text
repository: swift-institute/institute-application
commit:     e7b52d10d9b770c92dcd95a0b70119cecdadac97
file:       Institute.json
git blob:   f6e96466d16ba26a1ec4dbe7937b9118e0cfc88a
```

The manifest records repository organization, name, URL, and layer.  

The most recent positive-controlled Institute assessment records **453 committed inventory records**. I could not independently recount the complete JSON in the unavailable local workspace, so `453` is treated as a cited authoritative count rather than a newly reproduced count. 

### Manifest authority digest

```text
git-blob-sha1:f6e96466d16ba26a1ec4dbe7937b9118e0cfc88a
```

This identifies the exact manifest bytes inspected. It is not yet the transaction population digest because `Institute.json` does not contain live default-branch SHAs, visibility, archival status, or hosted-CI classification.

## 2.2 Layer classification

The current central fleet policy identifies:

- **L1:** `swift-primitives`
- **L2:** `swift-standards` and assigned standards organizations, including `swift-ietf`, `swift-iso`, `swift-w3c`, `swift-whatwg`, `swift-ieee`, `swift-iec`, `swift-ecma`, `swift-incits`, `swift-arm-ltd`, `swift-intel`, `swift-riscv`, `swift-linux-foundation`, and `swift-microsoft`
- **L3:** `swift-foundations`
- **Control:** `swift-institute`

It also carries typed platform and embedded-package overrides. 

## 2.3 Required transaction population digest

**PROPOSAL:** At implementation preflight, generate a canonical UTF-8/LF row for every original manifest coordinate:

```text
coordinate<TAB>
layer<TAB>
default-branch<TAB>
head-sha<TAB>
visibility<TAB>
archived<TAB>
disabled<TAB>
repository-class<TAB>
hosted-ci-scope<TAB>
caller-blob-sha
```

Sort by repository coordinate and calculate:

```text
SHA-256(all canonical rows joined with "\n", including final newline)
```

The resulting digest must appear in:

- the zero-mutation preflight receipt;
- the apply receipt;
- the independent cleanup receipt;
- the original-population recensus receipt;
- the terminal closure receipt.

### Current state

```text
manifest authority digest:     PROVED
manifest coordinate count:     453, cited but not locally reproduced
live transaction digest:       UNMEASURED
active-public-package subset:  UNMEASURED
private subset:                UNMEASURED
archived subset:               UNMEASURED
outside-hosted-CI subset:      UNMEASURED
```

A filesystem census of 478 repositories exists historically, but it included repositories outside the committed package manifest and is not a lawful population authority. 

---

# 3. Repository-by-repository current-state matrix

## 3.1 Completeness disposition

A complete 453-row current-head matrix was not obtainable in this environment. The matrix below contains exact live rows for three representative package repositories and exact heads for the principal central owners.

For the other **450 manifest coordinates**, every requested per-repository field remains **UNMEASURED** and requires the post-cutover recensus. That is a blocking inventory defect, not an inferred clean state.

## 3.2 Central-owner and control repositories

These repositories are not automatically members of the eventual mechanical package wave merely because they are related to the programme. Their classification must be resolved against the manifest and hosted-CI census.

| Coordinate | Exact inspected default-branch SHA | Programme role |
|---|---:|---|
| `swift-institute/.github` | `96542247d07e16f15b5f18285cff621af344f842` | GitHub host and reusable workflow |
| `swift-institute/institute-application` | `e7b52d10d9b770c92dcd95a0b70119cecdadac97` | Canonical package inventory |
| `swift-institute/institute` | `fd9931cff09901b15d3af8ef60ae59735ecb57a4` | Institute coordinator/domain |
| `swift-institute/Skills` | `85d4d129e6b7b87dbf98bffbc9f06bdd8efa5538` | Governing skills |
| `swift-institute/institute-continuous-integration` | `35600bb883f42c55a3e96033c4cf31911ff2a722` | Canonical policy and validation owner |
| `swift-institute/institute-continuous-integration-control` | `153dc8beaccab25914e47318b8786ec9259d844c` | Trusted control/effects owner |
| `swift-institute/Research` | `b41bbe8d53feaf9ce9e9557c432c6de54cd70375` | Historical research evidence |

      

## 3.3 Exact package probes

### L1 — `swift-primitives/swift-affine-algebra-primitives`

| Field | Current fact |
|---|---|
| Visibility/lifecycle | Public, non-archived, active |
| Default branch | `main` |
| Exact SHA | `1c5f6de4a3fe1270b62ce969274730899ed0fe26` |
| Layer | L1 / primitives |
| `.gitignore` | Root present; blob `8a2a0cad7d825058c0277c4669ee05283c857cd9`; old repository-allowlist policy with empty local-overrides tail |
| `.swift-format` | Root present; blob `bd0451edb4a4a6303092732f227e4f0e5ccf7381`; line length 200, four-space indentation, documentation and safety rules enabled |
| `.swiftlint.yml` | Root present; blob `4823a920df14b248944cdc526777964703840898`; remote `parent_config`; local `function_parameter_count` disable |
| Nested equivalents | UNMEASURED |
| Workflow consumer | Exact one-hop caller to `swift-institute/.github/.github/workflows/swift-ci.yml@main`; `lint-bundle: primitives` |
| Current required status | `ci / matrix / ci-ok` |
| Ruleset | Active, strict, no bypass in inspected ruleset |
| Tracked files matching candidate denylist | UNMEASURED |
| Local untracked/ignored state | UNMEASURED |
| Removal contract | Root style files are ignored by current hosted central-style materialization, but may still affect local/editor behavior |

       

### L2 — `swift-iso/swift-iso-639`

| Field | Current fact |
|---|---|
| Visibility/lifecycle | Public, non-archived, active |
| Default branch | `main` |
| Exact SHA | `efdb22171fcc8eed46f7604cb10c4c7adc2851a6` |
| Layer | L2 / standards |
| `.gitignore` | Root present; same blob `8a2a0cad7d825058c0277c4669ee05283c857cd9` |
| `.swift-format` | Root present; blob `602119ba7a5d71a90e307424b7282425be328a4f`; line length 120, four-space indentation, substantially more permissive documentation/safety toggles |
| `.swiftlint.yml` | Root present; blob `0e722b45244b3df2b18a90749e78c732a62b146f`; remote standards parent, no operative local override; comment names an unrelated `swift-incits-4-1986` package |
| Nested equivalents | UNMEASURED |
| Workflow/action references | Requires recensus at exact implementation head |
| Tracked files matching candidate denylist | UNMEASURED |
| Local untracked/ignored state | UNMEASURED |
| Removal contract | SwiftLint file appears copied/stale; formatter profile is materially different and cannot be dismissed as a byte-only variant without local-use adjudication |

The historical coordinate `swift-iso/swift-iso-639-standard` is no longer the live repository coordinate; the current repository is `swift-iso/swift-iso-639`.     

### L3 — `swift-foundations/swift-institute-linter-rules`

| Field | Current fact |
|---|---|
| Visibility/lifecycle | Public, non-archived, active |
| Default branch | `main` |
| Exact SHA | `4ae4c70e543d2848bceec4095bb7a2cd3b10a568` |
| Layer | L3 / foundations |
| `.gitignore` | Root present; same blob `8a2a0cad7d825058c0277c4669ee05283c857cd9` |
| `.swift-format` | Absent from the complete inspected tree |
| `.swiftlint.yml` | Root present; blob `93533515076e4bfcd2ee25f53dbb21436e224f12` |
| Nested equivalents | No corresponding nested config was established from the complete tree |
| Package-specific concern | Repository owns intentionally failing and positive/negative lint fixtures |
| Tracked files matching candidate denylist | UNMEASURED against the proposed policy |
| Local untracked/ignored state | UNMEASURED |
| Removal contract | Fixture-corpus behavior may justify a typed central scope delta, not a package-local configuration file |

   

## 3.4 Remaining manifest coordinates

For every other coordinate in `Institute.json`, the following fields require a fresh SHA-pinned recensus:

```text
visibility
archived/disabled state
default branch
exact default-branch SHA
hosted-CI scope
caller blob and semantics
root .gitignore path/blob/digest
root .swift-format/.swift-format.yml/.swiftformat paths and blobs
root .swiftlint.yml path/blob
nested Package.swift locations
nested ignore/style configurations
workflow/action configuration consumers
tracked paths matching the ratified denylist
tracked generated-residue classification
local ignored/untracked categories, without publishing machine-local paths
external-contract disposition
```

No uninspected coordinate should receive an inferred `clean`, `canonical`, `safe-to-delete`, or `not-applicable` value.

---

# 4. Meaningful configuration variants and proposed dispositions

## 4.1 `.gitignore`

### Proved variants

The three current probes share blob:

```text
8a2a0cad7d825058c0277c4669ee05283c857cd9
```

That file is an allowlist-style policy. It begins by ignoring nearly all root entries, then selectively re-includes approved paths. It also contains a nominal local-overrides section.   

The landed ICI package canon is a different allowlist. It starts with `*` and admits a closed set of files and directories. 

### Disposition

**DO NOT PRESERVE either allowlist as the terminal policy.**

Allowlist Gitignore policy can silently hide unfamiliar but legitimate source, fixture, research, generator, legal, or configuration files from `git status`. That is incompatible with the stated rule that `.gitignore` is a denylist rather than a repository allowlist.

The local-overrides tail must also disappear. A single canonical policy and byte-for-byte validation are incompatible with arbitrary local suffixes.

## 4.2 swift-format

### Proved current variants

- Current hosted central profile: line length 100. 
- L1 probe: line length 200 and stricter documentation/safety rules. 
- L2 probe: line length 120 and materially different rule toggles. 
- L3 probe: root file absent. 
- Historical positive-controlled census found 21 formatter blob classes. 

The current hosted action deletes a package’s root formatter configuration and installs the central copy before invoking the formatter. Thus these package-root variants do not currently define hosted-CI behavior, even though they may still influence local command or editor discovery. 

### Disposition

1. Preserve the **current hosted semantic baseline** during ownership transfer.
2. Do not convert historical line-width variants into typed exceptions merely because they exist.
3. Test each variant class against the current hosted profile in check-only mode.
4. Admit a typed delta only where there is an independently justified semantic contract.
5. Remove root copies only after the canonical local command and editor path use the same generated central profile as CI.

## 4.3 SwiftLint

### Proved current variants

- L1 has a local `function_parameter_count` disable. 
- L2 contains a copied remote-parent configuration with a stale package-name comment and no operative local override. 
- L3 has a root configuration and owns fixture behavior. 
- The central host configuration is a large shared policy and still contains commentary describing a three-tier `parent_config` model. 
- Historical positive-controlled census found 160 SwiftLint blob classes. 

The current hosted action deletes package-root `.swiftlint.yml` before installing the central profile, so package-local overrides are not part of present hosted-CI semantics. 

### Disposition

- Remove remote `parent_config` use from the terminal architecture.
- Treat the L2 stale file as presumptively obsolete, subject to current-head confirmation.
- Treat the L1 disabled rule as an **unratified candidate delta**, not as automatically valid or automatically obsolete.
- Express fixture or frozen-evidence scope through a closed typed central profile declaration.
- Fail closed on unknown repository class, unknown delta, missing profile, empty profile, or digest mismatch.

---

# 5. Recommended canonical owners and delivery mechanisms

| Concern | Canonical owner | Delivery | Why |
|---|---|---|---|
| Gitignore policy semantics | `institute-continuous-integration` | Exact generated root `.gitignore` committed in every package | Git needs repository-local policy for ordinary local use |
| Gitignore rendering and validation | `institute-continuous-integration` | Portable Swift operation and CLI | Existing landed semantic owner; no shell/Python policy |
| Gitignore fleet mutation | `institute-continuous-integration-control` plus thin `.github` host | Bounded transaction with exact-head CAS and receipts | Privileged multi-repository effect |
| SwiftLint profile | `institute-continuous-integration` | Generated into ignored build state; passed with explicit config argument | No package dependency or root copy |
| swift-format profile | `institute-continuous-integration` | Generated into ignored build state; passed with explicit configuration argument | Same local and hosted bytes |
| Tool version and artifact identity | ICI policy; `.github` supplies verified host acquisition | Exact version plus SHA-256/checksum evidence | Prevents tool/profile ambiguity |
| Swift AST and Institute source conventions | `swift-linter` and canonical rule packs | Existing lint bundle selection | It owns Swift syntax semantics, not Git index policy |
| GitHub workflow/check publication | `swift-institute/.github` | Existing reusable workflow and `ci-ok` | Thin GitHub-native host |
| Local bootstrap/diagnostics | Institute coordinator composing ICI | `institute doctor` or equivalent non-mutating diagnostic | Same owner operations, no copied logic |

The existing ICI Gitignore renderer, validator, NUL-safe tracked-file inspection, fixture harness, and CLI establish the correct ownership seam.    

The existing `central-style` action is transitional. It implements policy materialization with shell operations and root-file copying. It should be removed after explicit ICI rendering and invocation are live; it should not become the terminal owner. 

---

# 6. Exact proposed canonical end state

## 6.1 Root `.gitignore`

### Delivery decision

**PROPOSAL:** Every active hosted Swift package contains one byte-identical generated root `.gitignore`.

- It is generated by ICI.
- It has no local override section.
- It is validated byte-for-byte.
- No tracked nested `.gitignore` is admitted unless a typed exception is separately ratified.
- Root rules are recursive where the generated-state class is recursive.
- Replacement of the file and cleanup of tracked residue are separate operations.

### Candidate policy v1

This is the recommended conservative starting policy. It requires ratification after the current tracked-file recensus.

```gitignore
# Generated by instituteci. Do not edit.
# Canonical Swift package ignore policy: 1

.build/
Package.resolved
DerivedData/
.docc-build/
.benchmarks/
**/.swiftlint/RemoteConfigCache
.DS_Store
Thumbs.db
*~
*.swp
*.swo
```

Exact candidate identity:

```text
UTF-8 byte count: 216
SHA-256:          763c4689a2c9b7ad73d4cd82a48bdae623305ba1dd11b8ddd4dafc59f1e20dfd
Git blob SHA-1:   ee4d86d3f783baaf6b9ea3760d92dd8c40af66b7
```

### Deliberate exclusions

The candidate does **not** ignore:

```text
Sources/
Tests/
Benchmarks/
.snapshots/
Research/
Experiments/
Scripts/
Generated/
Package@swift-*.swift
.spi.yml
.swiftpm/
.vscode/
.mise.toml
.xcode-version
Dockerfile
AGENTS.md
CLAUDE.md
*.md
*.pdf
.env*
```

Those names may identify durable source, fixtures, shared manifests, publication assets, developer contracts, or owner-specific machinery. They cannot lawfully be hidden fleet-wide without separate evidence.

## 6.2 Gitignore validation contract

ICI should emit typed findings for at least:

```text
missing root .gitignore
root byte drift
unexpected nested .gitignore
tracked file matching canonical denylist
unreadable repository/index state
unknown repository class
```

Validation should use the Git index, not filesystem familiarity:

```text
git ls-files -z
    → git check-ignore --stdin -z --no-index
```

The tracked-match set must be empty after approved cleanup. The validator must never delete a path.

## 6.3 Centralized style configuration

**PROPOSAL:** ICI owns closed, versioned profiles:

```text
SwiftFormatProfile.package.v1
SwiftLintProfile.package.v1
```

The initial profile semantics should match the configurations already imposed by hosted CI, avoiding a style-policy change during ownership migration. The current central host files are therefore evidence for the initial semantic baseline, not the terminal owner.  

At runtime, ICI renders exact bytes to:

```text
.build/institute/configuration/<configuration-contract-digest>/.swift-format
.build/institute/configuration/<configuration-contract-digest>/.swiftlint.yml
```

The unmerged implementation currently proposes `.institute/configuration`; placing generated configuration beneath `.build` is preferable because `.build` is already recognized as generated Swift package state and does not introduce another repository-root state directory. The unmerged code already establishes closed tool identities, repository classes, deltas, generated filenames, and fail-closed profile selection. 

Every invocation must name the generated path explicitly:

```text
swift-format ... --configuration <generated-path>
swiftlint ... --config <generated-path>
```

The exact option ordering must be proven against the pinned tool releases in owner fixtures.

## 6.4 Developer-local behavior

A canonical local entry point should compose the same renderer and tools:

```text
instituteci style prepare
instituteci format check
instituteci lint
```

or equivalent Institute coordinator commands.

Required properties:

- same profile identity as hosted CI;
- same generated bytes and digest;
- same exact tool version where the tool is Institute-managed;
- no network-loaded `parent_config`;
- no root discovery;
- no fallback to tool defaults;
- editor adapters call the canonical command or resolve the generated path;
- missing preparation fails with a specific diagnostic rather than silently selecting defaults.

The exact editor integration remains a green-light prerequisite because the local coordinator could not be inspected here.

## 6.5 CI gate

The reusable workflow already verifies and invokes the ICI binary in `plan`, and its `ci-ok` job aggregates the plan, build, test, format, lint, and platform outcomes.  

**PROPOSAL:**

1. Add checkout-uniformity validation as a fail-closed step in `plan`.
2. Let `plan` fail for Gitignore drift, forbidden root style files, unknown typed deltas, or tracked generated residue.
3. Render style profiles in the existing format/lint paths.
4. Invoke both tools with explicit generated configuration paths.
5. Preserve the external required check:

```text
ci / matrix / ci-ok
```

No new required status context is needed. An inspected active L1 ruleset requires exactly that context. 

## 6.6 Terminal package shape

For an ordinary package:

```text
.gitignore                         exact generated policy
.github/workflows/ci.yml           existing exact one-hop caller
Package.swift
Sources/
Tests/
other package-owned durable files
```

Forbidden after terminal closure:

```text
.swift-format
.swift-format.yml
.swiftformat
.swiftlint.yml
nested equivalents of those files
free-form .gitignore local override tails
unapproved nested .gitignore files
tracked files matching the canonical denylist
```

Generated configuration exists only in ignored transient state.

---

# 7. Explicit proposed deletion inventory and exclusions

## 7.1 Tracked generated residue safe to delete

### Current proved inventory

```text
EMPTY
```

No current tracked path is approved for deletion by this report because a complete exact-head census and owner adjudication were not available.

### Conditional deletion classes

After current-head proof, these classes are presumptively removable:

```text
Package.resolved at package or nested-package locations
.DS_Store
Thumbs.db
editor swap/backup files
tracked SwiftLint RemoteConfigCache
tracked .build contents
tracked DerivedData
tracked .docc-build output
tracked .benchmarks tool state
```

A path enters the deletion allowlist only if all of the following are proved:

1. it is tracked at the frozen default-branch SHA;
2. the ratified canonical denylist matches it;
3. its semantic owner classifies it as generated/local state;
4. it is not consumed by release, tests, fixtures, benchmarks, documentation, generation, or an external integration;
5. its exact path and expected blob/tree identity are in the transaction plan.

## 7.2 Obsolete package-local configuration

These exact current probe files are **conditional deletion candidates**, not yet approved deletions:

```text
swift-primitives/swift-affine-algebra-primitives
    .swift-format
        blob bd0451edb4a4a6303092732f227e4f0e5ccf7381
    .swiftlint.yml
        blob 4823a920df14b248944cdc526777964703840898

swift-iso/swift-iso-639
    .swift-format
        blob 602119ba7a5d71a90e307424b7282425be328a4f
    .swiftlint.yml
        blob 0e722b45244b3df2b18a90749e78c732a62b146f

swift-foundations/swift-institute-linter-rules
    .swiftlint.yml
        blob 93533515076e4bfcd2ee25f53dbb21436e224f12
```

They may be removed only after:

- typed central profiles have landed;
- explicit hosted invocation has landed;
- the canonical local command/editor path is usable;
- meaningful deltas have been adjudicated;
- missing root files do not cause tool-default fallback.

The old root `.gitignore` is not deleted; it is replaced with exact canonical bytes.

## 7.3 Ignored local/build state that must not be deleted by the transaction

The fleet transaction must leave local-only state untouched, including:

```text
.build/
DerivedData/
.docc-build/
.benchmarks/
SwiftLint caches
untracked Package.resolved files
editor swap/backup files
machine-specific IDE state
local credentials
local mirrors or checkout configuration
other already-untracked developer work
```

The transaction may ensure these paths remain untracked. It must not remove them from local machines.

Forbidden commands and strategies include:

```text
git clean
git clean -x
git clean -X
recursive rm of ignored paths
deleting every git check-ignore result
reset --hard
checkout/restore over dirty work
stash as an implicit safety mechanism
```

## 7.4 Ambiguous or independently live files requiring owner adjudication

A historical census identified 39 repositories with 1,024 paths matching the then-candidate policy. These are **recensus candidates only**:

```text
swift-primitives/swift-c-interop-primitives — 1
swift-primitives/swift-github-actions-primitives — 15
swift-primitives/swift-initialize-primitives — 1
swift-primitives/swift-object-storage-primitives — 1
swift-primitives/swift-static-link-primitives — 2
swift-primitives/swift-stripe-primitives — 1
swift-primitives/swift-xml-primitives — 1

swift-ietf/swift-dns-standard — 9
swift-ietf/swift-multipart-form-data-standard — 1
swift-iso/swift-iso-639-standard — 1

swift-arm-ltd/swift-arm-standard — 15
swift-arm-ltd/swift-aarch64-standard — 202
swift-arm-ltd/swift-trace-standard — 34
swift-arm-ltd/swift-profiling-standard — 49
swift-arm-ltd/swift-generic-interrupt-controller-standard — 1

swift-foundations/swift-application-account — 2
swift-foundations/swift-bit — 1
swift-foundations/swift-composable-architecture — 2
swift-foundations/swift-cross-ui — 2
swift-foundations/swift-csv — 1
swift-foundations/swift-debounce — 2
swift-foundations/swift-documentation — 324
swift-foundations/swift-dynamic-library — 1
swift-foundations/swift-event-source — 6
swift-foundations/swift-http-endpoint — 2
swift-foundations/swift-institute-linter-rules — 25
swift-foundations/swift-institute-linter-rules-tests — 2
swift-foundations/swift-java-script-core — 1
swift-foundations/swift-jwt — 2
swift-foundations/swift-key-path-iterate — 4
swift-foundations/swift-lexical — 73
swift-foundations/swift-metric — 18
swift-foundations/swift-naming-convention — 11
swift-foundations/swift-open-api — 5
swift-foundations/swift-open-api-client-generation — 12
swift-foundations/swift-standard-library — 8
swift-foundations/swift-swift-testing — 2
swift-foundations/swift-symbolic — 192
swift-foundations/swift-syntax-components — 7
```

The same research established that **207 benchmark/snapshot files across 16 repositories had initially been misclassified as disposable tool state but were committed baselines that must be protected**. 

Specific historical paths requiring fresh owner adjudication include:

```text
swift-stripe-standard/build_output.txt
swift-image-magick-standard/output-*.png
swift-bit-primitives/"Sources/
swift-institute/IETF/RFCs.swift
swift-institute/.swiftpm/xcode/package.xcworkspace/xcshareddata/swiftpm/Package.resolved
swift-institute/Sources/.../Repositories+Outdated.swift
swift-standard-library/Package@swift-5.10.swift
swift-standard-library/Package@swift-6.0.swift
```

They must not be carried forward as automatic deletions.

## 7.5 Files and directories that must remain

Absent contrary owner evidence, the transaction must protect:

```text
Sources/
Tests/
Benchmarks/
.snapshots/
Research/
Experiments/
Skills/
Scripts/
Generated/
Package.swift
nested Tests/**/Package.swift
Package@swift-*.swift
README and other intentional documentation
LICENSE
NOTICE
CONTRIBUTORS
generator inputs and scripts
generated source that is part of a public package contract
fixture corpora, including intentionally invalid fixtures
release and publication assets
Dockerfile
.spi.yml
.mise.toml
.xcode-version
AGENTS.md
CLAUDE.md
```

The historical principal adjudication expressly protected research/experiment trees, fork notices, generator machinery, package namespace layouts, nested test packages, and committed benchmark/snapshot baselines. 

---

# 8. Typed exception inventory

## 8.1 Target state

| Contract | Target exception count |
|---|---:|
| Root `.gitignore` bytes | 0 |
| Free-form `.gitignore` override tails | 0 |
| Nested `.gitignore` files | Preferably 0 |
| Package-local SwiftLint files | 0 |
| Package-local swift-format files | 0 |
| Arbitrary repository-name-specific profiles | 0 |

## 8.2 Potential typed central deltas

The unmerged ICI design already identifies two bounded semantic candidates:

```text
frozen-evidence
fixture-corpus
```

It also closes repository classification to:

```text
package
institute
tool
```

Unknown classes and unratified deltas fail closed. 

### Recommended disposition

- `fixture-corpus` may be justified for repositories whose tests intentionally contain invalid Swift or configuration fixtures.
- `frozen-evidence` may be justified where immutable evidence trees are intentionally excluded from ordinary style scope.
- Neither delta should create or preserve a package-local configuration file.
- The current L1 `function_parameter_count` disable is not yet a typed exception. It requires owner evidence showing that it is intended policy rather than historical local drift.
- Formatter line lengths 120, 200, and 999 are not exceptions merely because historical files used them.

**Current ratified package-fleet exception inventory: empty.**

---

# 9. Positive and negative controls

All controls should live in the ICI owner repository or a dedicated non-production fixture corpus. They must not be created by temporarily corrupting live package repositories.

| Contract | Positive control | Negative control | Required outcome |
|---|---|---|---|
| Gitignore rendering | Exact candidate bytes | One-byte change | Drift detected |
| Missing policy | Root file present | Root file absent | Missing-file finding |
| Policy shape | Conservative denylist | File beginning with `*` allowlist | Policy rejected |
| Nested policy | No nested file | `Tests/Example/.gitignore` | Unexpected nested-policy finding |
| Tracked generated state | No tracked denylist match | Tracked `Package.resolved` | Tracked-ignore finding |
| Durable fixtures | `.snapshots` tracked | Broad rule that ignores `.snapshots` | Negative fixture rejects policy |
| Source safety | New unfamiliar `Sources/New.swift` visible to Git | Allowlist silently ignores it | Negative fixture rejects policy |
| Style rendering | Known class produces non-empty exact profiles | Missing profile bytes | Fail closed |
| Typed delta | Ratified `fixture-corpus` | Arbitrary repository-name delta | Unknown-delta failure |
| Profile integrity | Expected digest | One-byte tamper | Digest failure |
| SwiftLint invocation | Explicit `--config` | Invocation without config | Invocation-contract failure |
| Formatter invocation | Explicit configuration path | Root discovery/default config | Invocation-contract failure |
| Network independence | Local generated profile | Remote `parent_config` | Rejected |
| CI topology | Existing caller and `ci-ok` | Renamed/new required status | Topology failure |
| Fleet transaction | Exact frozen head | Head advanced before apply | Force-with-lease/CAS refusal |
| Cleanup | Explicit tracked path allowlist | Untracked local sentinel | Sentinel remains untouched |

The existing ICI work already supplies fixture ownership, machine-readable findings, and tracked-file validation seams.   

---

# 10. L1/L2/L3 verification plan

## 10.1 Probe classes

### L1

Use:

```text
ordinary:
    swift-primitives/swift-affine-algebra-primitives

embedded-package policy:
    swift-primitives/swift-coproduct-derivation
    swift-primitives/swift-pool-primitives
```

The two embedded-package overrides are already represented in central fleet policy and therefore test a genuine typed seam rather than an invented special case. 

### L2

Use:

```text
ordinary standards:
    swift-iso/swift-iso-639

generator/nested-package candidate:
    selected from the current recensus of ISO/IETF/ARM repositories

platform override:
    swift-standards/swift-darwin-standard
```

The platform override is already represented in fleet policy. 

### L3

Use:

```text
ordinary foundations package:
    one current package with no local semantic delta

fixture corpus:
    swift-foundations/swift-institute-linter-rules

committed benchmark/snapshot baseline:
    one currently verified member of the protected baseline class

platform override:
    swift-foundations/swift-application-swiftui
```

## 10.2 Per-probe procedure

For every probe:

1. Record exact repository coordinate, visibility, archival state, default branch, and head SHA.
2. Verify the exact terminal one-hop caller.
3. Enumerate root and nested `.gitignore`, `.swift-format*`, `.swiftformat`, and `.swiftlint.yml`.
4. Classify each configuration semantically.
5. Enumerate tracked files matching the proposed denylist.
6. Prove that `Sources`, `Tests`, fixtures, snapshots, benchmarks, research, generators, and package manifests remain visible/tracked.
7. Render both style profiles from the exact ICI artifact.
8. Verify profile digests and explicit command invocation.
9. Run check-only formatting and linting.
10. Run the corresponding negative fixture in an isolated ICI test fixture.
11. Prove the required status remains `ci / matrix / ci-ok`.
12. Produce a signed or immutable probe receipt.

No probe should write to the package repository merely to demonstrate a negative condition.

---

# 11. Owner-first and fleet-wave implementation sequence

## Phase 0 — Serialization gate

Do not mutate any package or central owner until the principal CI migration agent issues the terminal caller transaction’s closure receipt.

A merged runtime PR is insufficient. An apparently converged sample is insufficient. The exact original-population terminal receipt is required.

## Phase 1 — Fresh read-only recensus

After the caller cutover closes:

1. Re-read workspace `AGENTS.md` and all applicable skills.
2. Run the non-mutating Institute diagnostics.
3. Pin the current `Institute.json` commit and blob.
4. Enumerate all manifest coordinates.
5. Fetch live visibility, archive/disabled state, default branch, exact head, and hosted-CI classification.
6. Produce the complete current-state matrix.
7. Calculate the transaction population digest.
8. Freeze the original population and heads.

Any unmeasured row blocks progression.

## Phase 2 — Canonical owner completion

In `institute-continuous-integration`:

1. Replace the package allowlist canon with the ratified conservative denylist.
2. Separate:
   - rendering;
   - validation;
   - tracked-residue classification;
   - mutation planning.
3. Ensure no semantic deletion operation exists in the portable validator.
4. Complete typed SwiftLint and swift-format profiles.
5. Move generated profile output beneath `.build`.
6. Add exact profile and tool-contract digests.
7. Add positive/negative fixtures for every rule and typed exception.
8. Publish a verified ICI artifact.

Do not add a new package dependency merely to distribute configuration.

## Phase 3 — GitHub-host activation

In `swift-institute/.github`:

1. Acquire the verified ICI artifact using existing checksum machinery.
2. Add uniformity validation to the existing `plan` path.
3. Render and explicitly pass style configuration in existing format/lint paths.
4. Preserve all external job and required-check names.
5. Remove `central-style` only when its final consumer has been replaced.
6. Do not restore deleted Gitignore sync workflows or shell maintenance scripts.
7. Do not preserve remote-parent compatibility.

## Phase 4 — Owner proof

Before package mutation:

1. Run the complete ICI fixture suite.
2. Run L1/L2/L3 representative probes.
3. Verify positive and negative controls.
4. Verify missing/tampered profiles fail closed.
5. Verify local and hosted profile digests are identical.
6. Verify `ci / matrix / ci-ok` remains the ruleset contract.
7. Produce an owner-readiness receipt.

## Phase 5 — Zero-mutation package preflight

For each frozen original-population member:

1. Confirm current head equals frozen head.
2. Confirm no dirty tracked work.
3. Record untracked and ignored category counts without exposing local paths.
4. Confirm the exact planned path operations.
5. Confirm every deletion is in the adjudicated allowlist.
6. Confirm no untracked path will be touched.
7. Confirm no caller file mutation is planned.
8. Recalculate and compare the population digest.

Abort the entire wave on any mismatch.

## Phase 6 — One bounded mechanical package wave

For each eligible active public hosted package:

```text
replace root .gitignore with exact canonical bytes
remove approved root/nested style configuration files
remove only exact adjudicated tracked generated-residue paths
leave all other tracked paths unchanged
leave every untracked/ignored path untouched
commit
push with exact-head/force-with-lease protection
observe existing CI
record receipt
```

Private, archived, disabled, tooling/application, nested-package, or outside-hosted-CI repositories must follow their explicitly classified disposition; they must not be swept in by filesystem presence.

## Phase 7 — Independent closure

1. Close temporary mutation grants and privileges.
2. Aggregate all per-repository receipts.
3. Re-enumerate the exact original population.
4. Verify every eligible member’s new head and canonical state.
5. Verify excluded members remained unchanged.
6. Verify no unexpected population member was mutated.
7. Verify every expected `ci / matrix / ci-ok` completed successfully.
8. Issue the terminal uniformity closure receipt.

---

# 12. Interference and serialization analysis

## 12.1 Active overlap

The current CI migration owns:

- package default-branch heads;
- package `.github/workflows/ci.yml`;
- central reusable workflow behavior;
- caller population enumeration;
- required-check convergence;
- transaction receipts and privilege closure.

This uniformity programme would modify the same package heads even though its intended package files differ. Therefore the transactions conflict at the Git reference/CAS boundary even where file paths do not overlap.

Issue `#574` remains the explicit outstanding convergence task. 

## 12.2 File-level overlap

| File/surface | Current CI cutover | Uniformity programme | Disposition |
|---|---|---|---|
| Package `.github/workflows/ci.yml` | Directly owned | Must remain unchanged | Never include in uniformity mutation |
| Package default-branch ref | Directly owned | Needed for any uniformity commit | Serialization required |
| Package `.gitignore` | Not the intended caller artifact | Directly changed | Wait for terminal receipt |
| Package style configs | Not caller artifact | Removed | Wait for terminal receipt |
| `.github/workflows/swift-ci.yml` | Active runtime owner | Uniformity gate integration | Activate only after cutover closure |
| `.github/actions/central-style` | Existing transitional style path | Replaced/deleted | Remove only after explicit ICI invocation |
| ICI source/release | Runtime dependency | Canonical policy owner | May be prepared only when repository-head ownership is clear |

## 12.3 What may be prepared without package mutation

Architecturally, the following can be prepared owner-first:

```text
ICI denylist policy types
ICI rendering and validation
typed style profile model
fixture corpus
machine-readable findings
receipt schemas
dry-run transaction planner
```

However, if `institute-continuous-integration` itself is a member of the active package population, its default branch is also externally owned by the caller transaction. No central owner mutation is authorized merely because it avoids the other 452 package heads.

## 12.4 Safe activation milestone

Implementation becomes eligible only after the principal CI migration agent has reported all of:

```text
zero-mutation preflight
bounded apply
independent cleanup and privilege closure
receipt aggregation
exact original-population recensus
terminal closure receipt
```

No earlier milestone is sufficient.

## 12.5 Required-check and ruleset implications

The inspected L1 ruleset requires:

```text
ci / matrix / ci-ok
```

and uses strict status checking with no bypass. 

The proposed gate should therefore be absorbed into the existing reusable workflow and existing aggregator. It should not create a new fleet-wide required context or require simultaneous ruleset mutation.

Before rollout, a full live fleet ruleset census must nevertheless prove that all eligible repositories use the same context and that no legacy contexts remain required.

## 12.6 Compatibility prohibition

Do not add or restore:

```text
sync-gitignore.sh
per-organization Gitignore copy jobs
package-local parent_config shims
root config aliases retained for indefinite discovery
new package callers
new required check names
Python or shell policy implementations
compatibility for deleted workflow machinery
```

The current central-style copy action is transitional evidence, not architecture to preserve. 

---

# 13. Exact prerequisites for implementation green light

The future mutation agent may begin only when every item below is proved:

1. **CI cutover closure:** the principal has issued the exact terminal closure receipt containing all six required milestones.
2. **Workspace governance:** current workspace `AGENTS.md` and all applicable skills have been read.
3. **Institute diagnostics:** the non-mutating coordinator/doctor reports a valid inventory and environment.
4. **Current manifest authority:** exact `Institute.json` commit and blob are frozen.
5. **Complete live population:** all manifest coordinates have current visibility, archive/disabled state, default branch, head, class, and hosted-CI disposition.
6. **Population digest:** the exact live original-population digest has been calculated and stored.
7. **No unmeasured matrix cells:** every in-scope repository has root/nested config, consumer, tracked-match, and external-contract dispositions.
8. **Gitignore ratification:** the denylist policy is approved, tested, and identified by exact bytes and digest.
9. **Style-owner completion:** typed formatter and SwiftLint profiles are merged and contain ratified non-empty profile bytes.
10. **Explicit invocation:** hosted and local invocations name generated paths and fail on missing/tampered configuration.
11. **Verified artifact:** the exact ICI executable release and checksum are pinned.
12. **CI integration:** the existing reusable workflow executes the gate without changing `ci / matrix / ci-ok`.
13. **Ruleset census:** all affected repositories’ required contexts are proven compatible.
14. **Controls:** every positive and negative fixture passes at the exact owner revision.
15. **L1/L2/L3 probes:** all representative probes pass and produce receipts.
16. **Deletion allowlist:** every tracked deletion has exact path, expected object identity, owner disposition, and no external-contract effect.
17. **Ambiguity closure:** every historical residue candidate is either approved, excluded, or separately adjudicated.
18. **Dirty-state safety:** every mutation checkout passes zero-mutation preflight; no dirty or untracked path is endangered.
19. **Exact-head safety:** every planned update uses frozen-head CAS/force-with-lease semantics.
20. **Privilege plan:** temporary grants are bounded and an independent cleanup step is ready.
21. **Recensus plan:** exact original-population terminal recensus and closure-receipt generation are ready before apply starts.

**Current result:** prerequisites 1, 2, 3, 5–21 are not all proved. The green light is therefore withheld.

---

# 14. Open questions not resolvable from the available authoritative state

## Blocking inventory questions

1. What is the exact current active-public subset of the 453 manifest coordinates?
2. Which manifest repositories are private, archived, disabled, tooling/application repositories, or outside hosted package CI?
3. What is every repository’s exact implementation-time default-branch SHA?
4. Which repositories contain nested packages and nested ignore/style configuration?
5. What are the current fleet-wide blob classes for `.gitignore`, `.swift-format*`, and `.swiftlint.yml` after the CI cutover?
6. Which current tracked paths match the ratified denylist?
7. Which local untracked/ignored categories are present, without exposing machine-local path data?
8. Which historical residue candidates still exist at current heads?
9. Which current rulesets require contexts other than `ci / matrix / ci-ok`?

## Blocking policy questions

10. Should `.swiftpm/` be ignored as a whole, or only specifically adjudicated generated descendants? The conservative candidate leaves it visible pending proof.
11. Is the L1 `function_parameter_count` disable a real policy requirement or obsolete local drift?
12. Which repositories genuinely require `fixture-corpus` or `frozen-evidence` typed deltas?
13. Are any package-local formatter profile differences intended developer contracts despite being bypassed in hosted CI?
14. What exact local editor integrations are supported, and how will they resolve the generated profile without root discovery?
15. What is the ratified stable generated configuration path and contract-digest format?
16. Does the Institute coordinator already expose an installation/context operation that should compose the ICI style command, rather than adding another entry point?

## Blocking governance questions

17. What additional requirements are imposed by the unavailable workspace `AGENTS.md`?
18. Does the current `institute doctor` output identify inventory or repository-class discrepancies?
19. Is `institute-continuous-integration` itself inside the active caller transaction’s frozen population?
20. Which owner is authorized to adjudicate each ambiguous generated/source/fixture path?

These questions do not reopen the terminal ownership decision. They determine exact population, profile deltas, and lawful deletions.

---

# 15. Implementation handoff prompt

```text
Act as the mutation agent for the Swift Institute fleet-uniformity transaction.

Do not begin until the principal CI migration agent has issued the terminal
caller transaction closure receipt proving:

- zero-mutation preflight;
- bounded apply;
- independent cleanup and privilege closure;
- receipt aggregation;
- exact original-population recensus;
- terminal closure receipt.

Re-read the workspace AGENTS.md and the architecture, composition,
decomposition, ci-cd, github, and institute skills.

Use the current SHA-pinned
swift-institute/institute-application/Institute.json as the sole package
population authority. Enumerate every manifest coordinate and obtain live
visibility, archive/disabled state, default branch, exact head SHA,
repository class, hosted-CI scope, caller blob, configuration blobs, nested
packages/configuration, and rulesets. Produce a canonical sorted population
digest. Abort if any row is unmeasured.

Implement owner-first:

1. Complete the canonical denylist Gitignore policy in
   swift-institute/institute-continuous-integration.
2. Keep rendering, validation, tracked-residue classification, and mutation
   planning separate.
3. Complete typed, non-empty SwiftLint and swift-format profiles.
4. Render generated style configuration beneath ignored .build state.
5. Require explicit configuration arguments; reject default/root discovery,
   remote parent_config, unknown classes, unknown deltas, missing profiles,
   empty profiles, and digest mismatch.
6. Add complete positive and negative owner fixtures.
7. Publish and checksum-bind the exact ICI artifact.
8. Wire the verified artifact into the existing universal reusable workflow.
   Preserve caller job id `ci`, caller job name `ci / matrix`, and required
   check `ci / matrix / ci-ok`. Do not create another required status.
9. Remove central-style only after its final consumer is replaced. Do not
   restore deleted Gitignore sync machinery or add shell/Python policy.

Before package mutation, complete L1/L2/L3 probes and produce an exact
per-repository mutation plan. Every deletion must name an exact tracked path,
expected object identity, semantic classification, and owner adjudication.
A path is not deletable merely because Gitignore matches it.

Run one bounded package wave over the frozen eligible population:

- replace root .gitignore with the exact ratified bytes;
- remove only approved root/nested SwiftLint and swift-format files;
- remove only exact adjudicated tracked generated-residue paths;
- do not modify .github/workflows/ci.yml;
- do not run git clean;
- do not delete or overwrite dirty, untracked, ignored, or local-only work;
- use exact-head CAS/force-with-lease;
- run existing CI immediately;
- record before/after heads, path operations, policy/config/tool digests,
  workflow evidence, and result in each receipt.

After apply, independently close temporary privileges, aggregate receipts,
recense the exact original population, prove all eligible repositories have
the canonical state, prove exclusions were unchanged, verify every expected
`ci / matrix / ci-ok`, and issue the terminal uniformity closure receipt.

Abort rather than infer success from missing evidence.
```

---

**Read-only boundary maintained:** no repository file, branch, commit, pull request, issue, workflow, ruleset, secret, environment, package head, or local worktree state was changed. Awaiting further instruction.
