# Dual-Mode Package Publication

<!--
---
version: 2.0.0
last_updated: 2026-02-26
status: RECOMMENDATION
research_tier: 2
applies_to: [institute, primitives, standards, foundations]
normative: false
---
-->

## Context

### Trigger

Publication planning. The Swift Institute has 348 packages across three GitHub organizations (`swift-primitives`, `swift-standards`, `swift-foundations`), each package in its own git repo, aggregated via git submodules. Every `Package.swift` currently uses relative `path:` dependencies for development. For consumers to use these packages, each manifest needs versioned `url:` dependencies. The question is how to maintain both modes.

### Scope

Ecosystem-wide [RES-002a]. This decision affects every `Package.swift` in the ecosystem and the daily development workflow.

### Constraints

1. SPM has no built-in dual-mode dependency declaration (unlike Rust's `path + version`)
2. Each package is its own GitHub repo — independently taggable
3. Deep interdependencies within and across layers (a foundations package may transitively depend on 20+ primitives)
4. Development uses Xcode workspaces (which auto-override URL deps with local packages) and CLI `swift build` (which does not)
5. CI must validate the published form — the exact manifest consumers will resolve

### Related Research

- [spm-nested-package-publication.md](spm-nested-package-publication.md) — Confirmed three-layer model as architecturally correct
- [git-subtree-publication-pattern.md](git-subtree-publication-pattern.md) — Confirmed repos are already separate; identified manifest transformation as the core problem

---

## Question

How should 348 interdependent Swift packages maintain both development-mode (`path:`) and published-mode (`url:` + version) dependency declarations, and how should version releases be coordinated?

### Sub-questions

- SQ1: What dual-mode mechanisms does SPM support?
- SQ2: How do other ecosystems solve this?
- SQ3: What version coordination strategy fits 348 packages across 3 layers?
- SQ4: What is the concrete developer workflow for develop → publish → continue?

---

## Prior Art Survey [RES-021]

### Cross-Ecosystem Comparison

| Ecosystem | Mechanism | Dual-Mode Built-In? | Publish Transformation |
|---|---|---|---|
| **Rust/Cargo** | `path + version` in one declaration | **Yes** — first-class | `path` stripped at publish; `version` remains |
| **pnpm** | `workspace:*` protocol | **Yes** — first-class | `workspace:^` → `^1.5.0` at publish |
| **Go** | `go.work` (not committed) + `go.mod` (committed) | **Yes** — separate files | `go.work` is dev-only; `go.mod` is the published form |
| **Haskell/Cabal** | `cabal.project` (dev) + `.cabal` (published) | **Yes** — separate files | `.cabal` never references local paths |
| **SPM** | No built-in mechanism | **No** | Manual or tooling workaround |

**Key insight**: Every mature ecosystem except SPM has a first-class answer. Rust's is the most elegant (single declaration). Go's is the most analogous to what SPM could support (separate workspace file, not committed). SPM's gap is explicitly acknowledged by the community as a missing feature.

**Key pattern across ecosystems**: Rust, pnpm, and Go all share the same principle — **development manifests are never manually modified for publication**. The transformation happens automatically at publish time, either by stripping fields (Rust), rewriting protocols (pnpm), or using a separate non-committed file (Go). This principle directly informs the recommended approach.

### SPM Mechanisms Investigated

| Mechanism | Viable? | Details |
|---|---|---|
| `swift package edit --path` (SE-0082/SE-0149) | Partial | Officially designed for this. Overrides URL deps with local paths. Per-workspace, not committed. Requires per-dependency setup command. |
| Environment variable conditional (`SWIFTCI_USE_LOCAL_DEPS`) | Partial | Used by Apple's own toolchain packages (SwiftPM, swift-markdown). Package.swift switches path ↔ URL based on env var. Invasive at scale — requires modifying every manifest. |
| `getenv()` from Darwin.C/Glibc | Partial | Foundation-free variant of above. Same invasiveness concern. |
| Dependency mirroring (`set-mirror`, SE-0219) | **No** | See detailed analysis below. Mirrors are **git-based**: SPM still clones/checks out specific revisions. Uncommitted changes are invisible. Not suitable for active development. |
| Filesystem auto-detection (`access()`) | Fragile | Check if `../swift-storage-primitives` exists. Breaks reproducibility, discouraged by SPM team. |
| `Package@swift-X.Y.swift` | No | Selects manifest by toolchain version, not by dev/publish mode. |
| SE-0450 Package Traits | No | Controls target-level features, cannot switch package-level dependency URLs. |
| Xcode workspace override | Xcode only | Workspace containing local packages auto-overrides URL deps. Does not work with CLI `swift build`. |

### Dependency Mirroring: Detailed Analysis (SE-0219)

Mirrors (`swift package config set-mirror`) redirect a URL dependency to an alternate location — including local filesystem paths. This appears promising: Package.swift stays clean with URL deps, and mirrors redirect to local repos without modifying the manifest.

**However, mirrors are git-based, not filesystem-based.** Source code analysis of SPM's `DependencyMapper.swift` confirms: when a mirror points to a local path, SPM creates a `.localSourceControl` dependency (not `.fileSystem`). The entire git resolution pipeline runs — `git tag` enumeration, version matching, revision checkout into `.build/checkouts/`. At no point does SPM read the working directory state.

| Property | Mirror (`.localSourceControl`) | Path dep (`.fileSystem`) |
|---|---|---|
| Container type | `SourceControlPackageContainer` | `FileSystemPackageContainer` |
| Git operations | Full (tag, checkout, clone) | None |
| Uncommitted changes | Invisible | Visible |
| Version constraints | Enforced (tags required) | Bypassed entirely |
| Needs `git commit` | Yes | No |
| Needs `git tag` | Yes (for `from:` deps) | No |

**The `SWIFTPM_MIRROR_CONFIG` env var** does exist and can point to a shared mirrors JSON file, enabling per-machine or per-CI-environment mirror configs. But the git-based resolution behavior makes this irrelevant for active development — committing and tagging every change to see it in a dependent package is untenable.

**Mirrors solve a different problem**: corporate mirrors, CI caches, internal forks. They redirect traffic to a different git server. They do not provide the "use my working directory" behavior needed for development.

---

## Analysis

### Option A: Environment Variable Conditional (The Apple Pattern)

Each `Package.swift` contains a conditional that switches between path and URL dependencies based on an environment variable:

```swift
#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

let useLocalDeps = getenv("SWIFT_INSTITUTE_LOCAL") != nil

let package = Package(
    name: "swift-buffer-primitives",
    // ...
    dependencies: [
        useLocalDeps
            ? .package(path: "../swift-storage-primitives")
            : .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git",
                       from: "1.0.0"),
        useLocalDeps
            ? .package(path: "../swift-memory-primitives")
            : .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git",
                       from: "1.0.0"),
    ],
    // ... targets unchanged
)
```

| Criterion | Assessment |
|---|---|
| Package.swift modification | **Every manifest** gains ~5 lines of boilerplate (import + let) plus ternary per dependency |
| Developer setup | One-time env var export in shell profile |
| CI validation | Automatic — CI has no env var, so it validates published deps |
| Xcode compatibility | Works if env var is set in scheme or shell |
| Foundation-free | Yes — uses `getenv` from Darwin.C/Glibc |
| Precedent | Apple's own `SWIFTCI_USE_LOCAL_DEPS` in SwiftPM, swift-markdown |
| Scale (348 packages) | **Invasive** — 348 Package.swift files must be modified |
| Transitive deps | Automatic — every package in the graph switches simultaneously |

### Option B: URL-First Manifests + `swift package edit`

Each `Package.swift` declares only URL dependencies (the published form). Developers use `swift package edit --path` to override with local paths:

```swift
// Package.swift — always the published form
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git",
             from: "1.0.0"),
]
```

```bash
# Developer setup (per package they're working in):
cd swift-buffer-primitives
swift package edit swift-storage-primitives --path ../swift-storage-primitives
swift package edit swift-memory-primitives --path ../swift-memory-primitives
# ... for each transitive dependency
```

| Criterion | Assessment |
|---|---|
| Package.swift modification | None — manifests are always clean URL deps |
| Developer setup | Per-package: `swift package edit` for each dependency |
| CI validation | Automatic — Package.swift is already the published form |
| Xcode compatibility | Xcode has separate local package override mechanism |
| Foundation-free | N/A — no conditional logic in manifest |
| Precedent | SE-0082/SE-0149 designed for this use case |
| Scale (348 packages) | Requires editing 20+ transitive deps per working package |
| Transitive deps | Must explicitly edit each transitive dep; edit is per-workspace |

**The transitive dependency problem**: If swift-io depends on swift-buffer-primitives (URL), which depends on swift-storage-primitives (URL), developing swift-io locally requires editing BOTH swift-buffer-primitives AND swift-storage-primitives. For a foundations package with 20+ transitive primitive dependencies, this means 20+ `swift package edit` commands — and the edit state is stored in `.build/workspace-state.json`, lost whenever `.build/` is cleaned.

### Option C: Release Branch with Publish Tool

Development manifests (`main` branch) always use `path:` dependencies and are **never modified**. At publish time, a tool creates a release branch, transforms `path:` → `url:` deps, validates, tags, and pushes. Developers never touch release branches.

**Principle**: Development manifests are the source of truth. The published form is a derived artifact, like a compiled binary.

```
main branch (development):
  Package.swift → path: "../swift-storage-primitives"

release/1.4.0 branch (publication):
  Package.swift → url: "https://github.com/swift-primitives/swift-storage-primitives.git", from: "1.4.0"
  Tagged: 1.4.0
```

**The path→URL mapping is deterministic**. Three patterns cover all 348 packages:

| Path Pattern | Context | Published URL |
|---|---|---|
| `../swift-{name}` | Intra-layer dep | `https://github.com/{current-org}/swift-{name}.git` |
| `../../swift-primitives/swift-{name}` | Cross-layer → primitives | `https://github.com/swift-primitives/swift-{name}.git` |
| `../../swift-standards/swift-{name}` | Cross-layer → standards | `https://github.com/swift-standards/swift-{name}.git` |

The publish tool:

```bash
#!/bin/bash
# publish-layer.sh <layer-org> <version>
# Example: publish-layer.sh swift-primitives 1.4.0
ORG=$1
VERSION=$2
LAYER_DIR="$HOME/Developer/$ORG"

for repo in "$LAYER_DIR"/swift-*/; do
    cd "$repo"

    # Create release branch from main
    git checkout main
    git checkout -b "release/$VERSION"

    # Transform Package.swift: path → url
    # Intra-layer: ../swift-foo → github.com/{ORG}/swift-foo.git
    sed -i '' -E "s|\.package\(path: \"\.\./([^\"]+)\"\)|.package(url: \"https://github.com/$ORG/\1.git\", from: \"$VERSION\")|g" Package.swift

    # Cross-layer → primitives
    sed -i '' -E "s|\.package\(path: \"\.\./\.\./swift-primitives/([^\"]+)\"\)|.package(url: \"https://github.com/swift-primitives/\1.git\", from: \"$PRIM_VERSION\")|g" Package.swift

    # Cross-layer → standards
    sed -i '' -E "s|\.package\(path: \"\.\./\.\./swift-standards/([^\"]+)\"\)|.package(url: \"https://github.com/swift-standards/\1.git\", from: \"$STD_VERSION\")|g" Package.swift

    # Validate
    swift package resolve
    if [ $? -ne 0 ]; then
        echo "FAILED: $(basename $repo)"
        exit 1
    fi

    # Commit, tag, push
    git add Package.swift
    git commit -m "Release $VERSION"
    git tag "$VERSION"
    git push origin "release/$VERSION" --tags

    # Return to main
    git checkout main
    cd ..
done
```

| Criterion | Assessment |
|---|---|
| Package.swift modification | **None** — development manifests are never touched |
| Developer setup | **None** — `path:` deps work as-is on `main` |
| CI validation | Release branch validated by `swift package resolve` before tagging |
| Manifest divergence | `main` has path deps; release branch has URL deps. This is intentional and auditable. |
| Xcode compatibility | Works — `main` has path deps, Xcode resolves them naturally |
| Precedent | pnpm's `workspace:^` → `^1.5.0` transformation; Rust's `path` stripping at publish |
| Scale (348 packages) | One script per layer — no per-package modifications |
| Auditability | Release branches are committed, diffable, and reviewable |
| Error detection | `swift package resolve` validates every transformed manifest before tagging |

### Option D: Dual Package.swift Files

Maintain two manifest files — one for development, one for publication:

```
swift-buffer-primitives/
  Package.swift           → path deps (used by developers)
  Package.published.swift → url deps (used by CI for tagging)
```

| Criterion | Assessment |
|---|---|
| Developer setup | None — Package.swift has path deps |
| CI validation | CI copies `.published.swift` → `Package.swift`, builds, tags |
| Drift risk | High — two files must stay synchronized |
| SPM support | SPM doesn't recognize `.published.swift`; CI must swap files |

---

## Comparison

| Criterion | A: Env Var | B: Edit | C: Release Branch | D: Dual Files | E: Mirror |
|---|---|---|---|---|---|
| Development manifest changes | **348 files modified** | None | **None** | None | None |
| Developer friction | One env var | High (20+ edits/pkg) | **None** | None | High (commit+tag) |
| Uncommitted changes visible | Yes | Yes | Yes (on main) | Yes | **No** |
| CI validates published form | Automatic (no env var) | Automatic (URL form) | `swift package resolve` on release branch | Must swap files | Automatic |
| Transitive dep handling | Automatic (whole graph) | Manual (per dep) | **Automatic** | Automatic | Automatic |
| State lost on clean | No | Yes (.build/) | No | No | No |
| Auditability | Inline conditionals | N/A | **Full** (release branches diffable) | Poor (drift risk) | N/A |
| Precedent | Apple toolchain | SE-0082 | Rust/pnpm publish | Uncommon | SE-0219 |
| Scale to 348 packages | Invasive | Poor | **One script per layer** | Poor (drift) | Poor |

---

## Version Coordination

### Layer-Level Lockstep: Recommended

All packages within a layer share one version number. Three versions to coordinate, not 348.

```
swift-primitives org:   all repos tagged 1.4.0
swift-standards org:    all repos tagged 1.2.0
swift-foundations org:  all repos tagged 1.1.0
```

**Why lockstep within a layer**:

1. **No ecosystem has successfully managed 300+ independently versioned packages.** Projects at this scale use lockstep (AWS SDK 300+ clients, Firebase 31+ products, Babel 200+ plugins) or abandon versioning entirely (Google monorepo).

2. **Packages within a layer are co-developed, co-tested, co-released.** A consumer using `Buffer Primitives 1.4.0` and `Storage Primitives 1.4.0` knows they were tested together.

3. **Cross-layer deps become simple ranges.** `swift-foundations` depends on `swift-primitives >= 1.4.0, < 2.0.0`. Three dependency ranges total.

4. **Layer architecture constrains version cascades.** A breaking change in Layer 1 can only cascade upward. The five-layer architecture is already designed to minimize this.

**Trade-offs accepted**:
- Version inflation: unchanged packages get new tags. Firebase and AWS SDK accept this.
- A breaking change in one primitive forces a major bump on all primitives. Mitigated by: primitives should be extremely stable post-1.0.

### Release Ordering

Release order follows the layer dependency graph — the same topological order as the architecture:

```
1. Primitives (no dependencies on other layers)
2. Standards  (depends on primitives — needs primitives tags to exist)
3. Foundations (depends on primitives + standards — needs both tagged)
```

---

## Outcome

**Status**: RECOMMENDATION

### Dual-Mode Mechanism: Release Branch with Publish Tool (Option C)

Adopt the release-branch model: development manifests on `main` always use `path:` dependencies and are **never modified for publication**. A publish tool creates release branches with transformed `url:` dependencies, validates them, and tags.

**Principle**: Like Rust and pnpm, the published form is a derived artifact — not a hand-maintained parallel manifest.

**Rationale**:

- **Zero development friction**: Developers never touch Package.swift for publication. `main` always has `path:` deps, `swift build` works, Xcode workspaces work — no env vars, no setup scripts, no per-dependency edit commands.
- **Zero manifest invasiveness**: Unlike the env-var approach (which requires modifying all 348 Package.swift files with conditional logic), no development manifest is ever modified.
- **Deterministic transformation**: Three regex patterns cover all 348 packages. The mapping from path to URL is mechanical — no judgment calls, no per-package customization.
- **Auditable release artifacts**: Every release branch commit is a real git commit with a diffable Package.swift. You can `git diff main..release/1.4.0 -- Package.swift` to see exactly what changed.
- **Validated before tagging**: `swift package resolve` runs on the transformed manifest before any tag is created. Invalid transformations fail fast.
- **Aligns with ecosystem precedent**: Rust strips `path` at `cargo publish`. pnpm rewrites `workspace:^` to `^1.5.0`. Both treat the local-dev form as primary and derive the published form.

**Why not Option A (env var conditional)**: Invasive — requires modifying all 348 Package.swift files with conditional logic (import + env var check + ternary per dependency). While battle-tested by Apple's own repos (which have ~10 packages, not 348), the boilerplate-to-package ratio is prohibitive at this scale. Also permanently complicates every manifest with publication concerns that only matter at release time.

**Why not Option E (mirrors)**: Mirrors are git-based — SPM still clones and checks out specific revisions from the local repo. Uncommitted changes are invisible. Every edit requires `git commit` + `git tag` before the dependent package sees it. Mirrors solve a different problem (corporate mirrors, CI caches), not development-time path overriding.

**Why not Option B (`swift package edit`)**: The transitive dependency problem makes it impractical at this scale. A foundations package may need 20+ edit commands, all lost on `.build/` clean. Designed for "I need to temporarily modify one dependency" — not for "my entire workspace is local."

**Why not Option D (dual files)**: Drift risk. Two files that must stay synchronized across 348 repos, with no tooling to detect divergence.

### Version Strategy: Layer-Level Lockstep

All packages in a layer share one version:

| Layer | Org | Example Version |
|---|---|---|
| Primitives | `swift-primitives` | 1.4.0 |
| Standards | `swift-standards` | 1.2.0 |
| Foundations | `swift-foundations` | 1.1.0 |

**Rationale**: No ecosystem successfully manages 300+ independently versioned packages. Layer lockstep aligns with the co-development, co-testing model and reduces cross-layer coordination to three version numbers.

### Implementation Sequence

1. **Build the publish tool** — a shell script (or Swift script) that:
   - Takes a layer org and version as arguments
   - Iterates all repos in the layer
   - Creates `release/{version}` branch from `main`
   - Applies the three deterministic `sed` transformations (intra-layer, cross-layer→primitives, cross-layer→standards)
   - Runs `swift package resolve` on the transformed manifest
   - Commits, tags, pushes
   - Returns to `main`

2. **Validate on one flagship package** (e.g., swift-buffer-primitives). Manually run the publish tool, verify the transformed Package.swift is correct, verify `swift package resolve` succeeds, verify a fresh `swift package init` consumer can depend on the URL + tag.

3. **Dry-run all primitives repos**. Run the publish tool with tagging disabled to verify all 127 transformations produce valid manifests.

4. **Tag all primitives repos** with an initial version (e.g., 0.1.0 or 1.0.0). These tags must exist before standards can be published (standards depend on primitives URLs).

5. **Repeat for standards**, then foundations — following topological release order.

6. **Add CI validation**: On the release branch, CI runs `swift build` with the URL deps to verify the published form compiles. This catches any transformation errors before consumers encounter them.

### Developer Workflow

```
Develop:
  main branch, path: deps, swift build / Xcode — just works

Publish:
  ./publish-layer.sh swift-primitives 1.4.0
  ./publish-layer.sh swift-standards 1.2.0    # after primitives tags exist
  ./publish-layer.sh swift-foundations 1.1.0   # after both exist

Continue developing:
  Still on main, nothing changed — path: deps still work
```

### Deterministic Path→URL Mapping

The publish tool's transformation rules, covering all dependency patterns in the ecosystem:

| Development Path (main) | Published URL (release branch) |
|---|---|
| `path: "../swift-storage-primitives"` | `url: "https://github.com/swift-primitives/swift-storage-primitives.git", from: "1.4.0"` |
| `path: "../../swift-primitives/swift-buffer-primitives"` | `url: "https://github.com/swift-primitives/swift-buffer-primitives.git", from: "1.4.0"` |
| `path: "../../swift-standards/swift-iso-8601"` | `url: "https://github.com/swift-standards/swift-iso-8601.git", from: "1.2.0"` |
| `path: "../swift-kernel"` | `url: "https://github.com/swift-foundations/swift-kernel.git", from: "1.1.0"` |

The org is determined by the path structure:
- `../` (intra-layer) → current layer's org
- `../../swift-primitives/` → `swift-primitives` org
- `../../swift-standards/` → `swift-standards` org

---

## Changelog

### v2.0.0 (2026-02-26)

- **Changed recommendation** from Option A (env var conditional) to Option C (release branch with publish tool)
- Rationale: env var approach requires modifying all 348 Package.swift files — too invasive for an operation that only matters at release time
- Added deterministic path→URL mapping table
- Added concrete publish tool script
- Added developer workflow section
- Expanded cross-ecosystem insight: all ecosystems treat published form as derived artifact

### v1.1.0 (2026-02-26)

- Added detailed SE-0219 mirror analysis (source code tracing)
- Confirmed mirrors are git-based, not filesystem-based
- Added mirror to comparison table as Option E

### v1.0.0 (2026-02-26)

- Initial research: cross-ecosystem survey, 5 SPM mechanisms, 4 options compared

---

## References

### Ecosystem Prior Art
- [Cargo: Specifying Dependencies (path + version)](https://doc.rust-lang.org/cargo/reference/specifying-dependencies.html)
- [Cargo: Workspaces (workspace.dependencies)](https://doc.rust-lang.org/cargo/reference/workspaces.html)
- [pnpm: Workspaces (workspace: protocol)](https://pnpm.io/workspaces)
- [Go Workspaces (go.work)](https://go.dev/doc/tutorial/workspaces)
- [Cabal: Project Files](https://cabal.readthedocs.io/en/3.4/cabal-project.html)

### SPM Mechanisms
- [SE-0082: Package Manager Edit Command](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0082-swiftpm-package-edit.md)
- [SE-0149: Package Manager Top of Tree Development](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0149-package-manager-top-of-tree.md)
- [SE-0201: Package Manager Local Dependencies](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0201-package-manager-local-dependencies.md)
- [SE-0219: Package Manager Dependency Mirroring](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0219-package-manager-dependency-mirroring.md)
- [SE-0450: Package Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md)
- [SwiftPM Package.swift (SWIFTCI_USE_LOCAL_DEPS)](https://github.com/swiftlang/swift-package-manager/blob/main/Package.swift)
- [Environment variables in Package.swift (Swift Forums)](https://forums.swift.org/t/environment-variables-in-package-swift/80900)

### Version Coordination
- [Firebase Versioning Policy](https://firebase.google.com/policies/changes-to-firebase/versioning-and-maintenance)
- [AWS SDK Java v2 Versioning](https://github.com/aws/aws-sdk-java-v2/blob/master/VERSIONING.md)
- [Changesets (monorepo version coordination)](https://github.com/changesets/changesets)
- [cargo-semver-checks (API breakage detection)](https://github.com/obi1kenobi/cargo-semver-checks)
- [release-plz (automated Rust releases)](https://release-plz.dev/)

### Related Research
- [spm-nested-package-publication.md](spm-nested-package-publication.md)
- [git-subtree-publication-pattern.md](git-subtree-publication-pattern.md)
