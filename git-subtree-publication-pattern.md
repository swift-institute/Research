# Git Subtree Publication Pattern

<!--
---
version: 2.0.0
last_updated: 2026-02-26
status: DECISION
research_tier: 2
applies_to: [institute, primitives, standards, foundations]
normative: false
---
-->

## Context

### Trigger

Publication planning. The previous research ([spm-nested-package-publication.md](spm-nested-package-publication.md)) confirmed the three-layer-repo model as architecturally correct but deferred evaluation of the Apollo-pattern git subtrees as a potential development or publication mechanism.

### Scope

Ecosystem-wide [RES-002a]. This decision affects how all Swift Institute packages are published and consumed.

### Actual Repository Structure

Investigation revealed the repos use **git submodules**, not a flat monorepo:

```
swift-primitives/                    (parent repo with .gitmodules)
  swift-buffer-primitives/           → github.com/swift-primitives/swift-buffer-primitives (submodule)
  swift-storage-primitives/          → github.com/swift-primitives/swift-storage-primitives (submodule)
  swift-time-primitives/             → github.com/swift-primitives/swift-time-primitives (submodule)
  ... (127 submodules)

swift-standards/                     (parent repo with .gitmodules)
  swift-iso-8601/                    → github.com/swift-standards/swift-iso-8601 (submodule)
  ... (111 submodules)

swift-foundations/                   (parent repo with .gitmodules)
  swift-io/                          → github.com/swift-foundations/swift-io (submodule)
  swift-json/                        → github.com/swift-foundations/swift-json (submodule)
  ... (110 submodules)
```

Each package is **already its own GitHub repository** under layer-specific GitHub organizations (`swift-primitives`, `swift-standards`, `swift-foundations`). The parent repos aggregate submodules for development convenience.

**Implication**: The git subtree question is moot — there is nothing to split. The 348 distribution repos already exist.

### The Actual Publication Problem

Each `Package.swift` uses relative path dependencies for development:

```swift
// swift-buffer-primitives/Package.swift (development)
.package(path: "../swift-storage-primitives")
.package(path: "../swift-memory-primitives")

// swift-io/Package.swift (development)
.package(path: "../swift-kernel")
.package(path: "../../swift-primitives/swift-buffer-primitives")
```

These `path:` dependencies only work because all submodules are checked out side-by-side. SPM rejects `path:` dependencies in versioned packages. For publication, they must become versioned URL dependencies:

```swift
// swift-buffer-primitives/Package.swift (published)
.package(url: "https://github.com/swift-primitives/swift-storage-primitives", from: "1.0.0")
.package(url: "https://github.com/swift-primitives/swift-memory-primitives", from: "1.0.0")
```

The publication problem is: **how to manage the path → URL transformation and version coordination across 348 interdependent repos.**

---

## Question

How should the Swift Institute transform development-mode `Package.swift` files (path dependencies) into publication-mode manifests (URL dependencies) and coordinate version tagging across 348 interdependent repos?

### Sub-questions

- SQ1: Is the Apollo git subtree pattern relevant given the existing repo structure?
- SQ2: What mechanisms exist for dual-mode Package.swift (path for dev, URL for publish)?
- SQ3: How should version tags be coordinated across interdependent repos?
- SQ4: What CI/CD automation is needed for the publication workflow?

---

## Prior Art Survey [RES-021]

### Apollo GraphQL

Apollo uses a true monorepo (`apollo-ios-dev`) with git subtrees splitting to 3 distribution repos. Their `Package.swift` files are **identical** in dev and distribution because their subtree packages have zero inter-dependencies.

**Relevance**: Not applicable. The Institute's repos are already split. Apollo solves repo-splitting; the Institute needs manifest transformation.

### Symfony PHP (splitsh-lite)

Uses `splitsh-lite` to split 50+ components from a monorepo to read-only distribution repos.

**Relevance**: Not applicable. Same reason — solves repo-splitting, which the Institute doesn't need.

### SPM Package Traits (SE-0450, Swift 6.1)

Enables conditional dependencies via feature flags. Does not address path-vs-URL dependency modes.

### SPM `Package@swift-X.Y.swift` Toolchain-Specific Manifests

SPM supports alternate manifests keyed by Swift toolchain version (e.g., `Package@swift-6.0.swift`). These are version-keyed, not mode-keyed — they cannot distinguish "development" from "publication" context.

### Common Industry Patterns for Dual-Mode Manifests

| Pattern | Mechanism | Used By |
|---|---|---|
| Environment variable in Package.swift | `ProcessInfo.processInfo.environment["CI"]` to switch path ↔ URL | Various internal projects |
| CI manifest rewriting | Script replaces path deps with URL deps before tagging | Firebase (partial) |
| Separate branches | `main` has path deps, `release/*` branches have URL deps | Common in multi-repo projects |
| Generated manifests | Template generates Package.swift for both modes | Tuist-based projects |

---

## Analysis

### Option A: Environment-Variable Switching in Package.swift

```swift
import Foundation
import PackageDescription

let useLocal = ProcessInfo.processInfo.environment["SWIFT_INSTITUTE_LOCAL"] != nil

let package = Package(
    name: "swift-buffer-primitives",
    dependencies: useLocal
        ? [.package(path: "../swift-storage-primitives")]
        : [.package(url: "https://github.com/swift-primitives/swift-storage-primitives", from: "1.0.0")],
    ...
)
```

| Criterion | Assessment |
|---|---|
| Developer experience | Set env var once, develop normally |
| Publication | Unset env var, tag, push |
| Manifest count | 1 per package |
| Drift risk | None — single source of truth |
| SPM compatibility | Works today — Package.swift is executable Swift |
| Foundation import | Requires `import Foundation` for ProcessInfo |

**Concern**: Using `Foundation` in Package.swift is unconventional but not prohibited. SPM itself uses `ProcessInfo` in some contexts.

### Option B: CI Manifest Rewriting

A CI script rewrites `Package.swift` before tagging:

```bash
# publish.sh
sed -i '' 's|.package(path: "../swift-\(.*\)")|.package(url: "https://github.com/swift-primitives/swift-\1", from: "VERSION")|g' Package.swift
git add Package.swift
git tag $VERSION
git push --tags
```

| Criterion | Assessment |
|---|---|
| Developer experience | No change to workflow |
| Publication | Script-driven, automated |
| Manifest count | 1 per package (modified in-place for release) |
| Drift risk | Low — script is deterministic |
| SPM compatibility | Standard Package.swift |
| Reversibility | Tag points to transformed commit; dev branch remains untouched |

**Concern**: The tagged commit has a different `Package.swift` than the development branch. This is normal practice (release branches often diverge) but requires discipline.

### Option C: Release Branch with URL Dependencies

Development on `main` with path deps. Release automation creates a `release/X.Y.Z` branch, transforms manifests, tags, and pushes.

```
main:           path: "../swift-storage-primitives"
release/1.0.0:  url: "https://github.com/swift-primitives/swift-storage-primitives", from: "1.0.0"
```

| Criterion | Assessment |
|---|---|
| Developer experience | No change |
| Publication | Branch + transform + tag |
| Manifest count | 1 per package (different on different branches) |
| Drift risk | Low — automated transformation |
| SPM compatibility | Standard |
| Auditability | Release branch shows exact published state |

### Option D: Layer-Level Version Coordination

All packages within a layer share one version number. When any package in `swift-primitives` changes, all 127 packages are tagged with the new version.

```
swift-buffer-primitives  → 1.3.0
swift-storage-primitives → 1.3.0
swift-time-primitives    → 1.3.0
... (all 127 at 1.3.0)
```

Cross-layer deps use the layer version:

```swift
.package(url: "https://github.com/swift-primitives/swift-storage-primitives", from: "1.0.0")
```

Any primitives 1.x.y is compatible with any other primitives 1.x.y because they were tested together.

| Criterion | Assessment |
|---|---|
| Version coordination | Simple — one version per layer |
| Consumer reasoning | Easy — "I'm on primitives v1.3" |
| Tagging overhead | 127 repos tagged per release (scriptable) |
| Unnecessary releases | Yes — unchanged packages get new tags |
| Semantic versioning | Technically violates "no changes = no version bump" |

**Alternative**: Independent versioning per package. Each package has its own version. Dependencies specify minimum versions. This is more correct semantically but creates a combinatorial compatibility matrix across 127+ packages.

---

## Comparison

| Criterion | A: Env Var | B: CI Rewrite | C: Release Branch | D: Layer Version |
|---|---|---|---|---|
| Developer friction | Minimal (set env var) | None | None | None |
| Manifest complexity | Moderate (conditional logic) | Simple | Simple | Simple |
| CI complexity | Low | Medium | Medium | Medium |
| Auditability | Good (one manifest) | Good (script is traceable) | Best (branch shows published state) | Good |
| Foundation dep in manifest | Yes | No | No | No |
| Orthogonal (works with any versioning) | Yes | Yes | Yes | Specific strategy |

---

## Outcome

**Status**: DECISION

### Git Subtree Pattern: Not Applicable

The Apollo-pattern git subtrees solve repository splitting — extracting subdirectories from a monorepo into separate distribution repos. The Swift Institute already has separate repos per package (via git submodules). There is nothing to split. The investigation is concluded as **not applicable** to the Institute's architecture.

### Publication Mechanism: CI Manifest Rewriting (Option B) or Release Branch (Option C)

Both are viable. The choice between them is an implementation detail, not an architectural decision. Either way:

1. Development uses `path:` dependencies (current state, no change)
2. A publication step transforms `path:` → `url:` with version numbers
3. The transformed manifest is tagged and pushed
4. Consumers depend on the tagged repos via standard SPM `.package(url:, from:)`

**Option C (release branch) is slightly preferred** for auditability — the release branch preserves the exact published state alongside the development state.

### Version Strategy: Deferred

Whether to use layer-level versioning (all primitives share one version) or per-package versioning (each package independently versioned) is a separate decision that should be made during publication planning. Both work with the manifest transformation approach.

**Trade-off summary**:
- Layer-level: simpler coordination, easier consumer reasoning, some unnecessary version bumps
- Per-package: semantically correct, complex coordination across 348 interdependent packages

### Previous Recommendation Corrected

The v1.0 of this document recommended "Root Package.swift per layer" based on the incorrect assumption that the layer repos were flat monorepos. They are submodule aggregations of independent repos. The root Package.swift approach is not applicable.

---

## References

### Primary Sources
- [How Apollo Manages Swift Packages in a Monorepo with Git Subtrees](https://www.apollographql.com/blog/how-apollo-manages-swift-packages-in-a-monorepo-with-git-subtrees)
- [Apollo iOS Dev Repository](https://github.com/apollographql/apollo-ios-dev)
- [splitsh/lite](https://github.com/splitsh/lite)

### SPM and Swift Evolution
- [SE-0292: Package Registry Service](https://forums.swift.org/t/se-0292-package-registry-service/42623)
- [SE-0391: Package Registry Publish](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0391-package-registry-publish.md)
- [SPM Multi-Package Repositories pitch (2021)](https://forums.swift.org/t/spm-multi-package-repositories/43193)

### Related Research
- [spm-nested-package-publication.md](spm-nested-package-publication.md) — Nested Package.swift rejected; current layer-first model confirmed
- [domain-first-repository-organization.md](domain-first-repository-organization.md) — Repository organization analysis
