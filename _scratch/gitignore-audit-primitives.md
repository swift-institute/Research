# .gitignore Audit: swift-primitives Ecosystem

**Date**: 2026-03-12
**Scope**: Parent `.gitignore` + all `swift-*/` sub-repo `.gitignore` files in `/Users/coen/Developer/swift-primitives/`

---

## Summary

| Category | Count |
|----------|-------|
| Total `swift-*/` sub-directories | 133 |
| Sub-repos WITH `.gitignore` | 126 |
| Sub-repos WITHOUT `.gitignore` | 7 |
| Unique `.gitignore` variants (sub-repos) | 4 |

---

## Parent .gitignore

**Path**: `/Users/coen/Developer/swift-primitives/.gitignore`

```gitignore
# ========== CANONICAL (auto-synced, do not edit) ==========
# Source: swift-institute
# Sync: Scripts/sync-gitignore.sh or manual

*~
.DS_Store

Package.resolved
DerivedData/
Thumbs.db

# Dot files/directories (opt-in only)
/.*
!/.github
!/.gitignore
!/.spi.yml
!/.swift-format
!/.swiftformat
!/.swiftlint.yml
!/.swiftlint/

# Top-level entries (opt-in only)
# First ignore all, then whitelist specific folders and files
/*
!/.claude/
/.claude/*
!/.claude/skills/
!/.gitmodules
!/Sources/
!/Tests/
!/Experiments/
!/Research/
!/.github/
!/Package.swift
!/LICENSE.md

# Documentation (opt-in for whitelisted .md files and .docc catalogs only)
# Blocks all .md files by default to prevent AI-generated content from being committed
*.md
!README.md
!LICENSE.md
!CHANGELOG.md
!CONTRIBUTING.md
!CODE_OF_CONDUCT.md
!SECURITY.md
!CLAUDE.md
!**/*.docc/**/*.md
!**/Research/**/*.md

*.pdf

# SwiftLint
**/.swiftlint/RemoteConfigCache

# Swift Package Manager
.build/
.swiftpm/

# ========== END CANONICAL ==========

# ========== LOCAL OVERRIDES ==========
# Package-specific rules below (preserved during sync)

# Scripts directory for tooling
!/Scripts/

# Documentation catalog
!/Documentation.docc/

# All swift-* primitive packages
!/swift-*/

# Skills directory for repo-specific skills
!/Skills/
!/Skills/**/*.md
```

**Notable parent-only rules**:
- `!/.gitmodules` — manages git submodules
- `!/.claude/` + `/.claude/*` + `!/.claude/skills/` — Claude config with selective whitelisting
- `!/Scripts/`, `!/Documentation.docc/`, `!/swift-*/`, `!/Skills/` — local overrides for monorepo structure
- `!CLAUDE.md` — whitelisted in canonical section

---

## Sub-repo .gitignore Variants

### Variant A: Standard (122 sub-repos)

**Hash**: `0267829ab734578755884788ae796f65`

This is the baseline canonical template with no local overrides. Used by the vast majority of sub-repos.

```gitignore
# ========== CANONICAL (auto-synced, do not edit) ==========
# Source: swift-institute
# Sync: Scripts/sync-gitignore.sh or manual

*~
.DS_Store

Package.resolved
DerivedData/
Thumbs.db

# Dot files/directories (opt-in only)
/.*
!/.github
!/.gitignore
!/.spi.yml
!/.swift-format
!/.swiftformat
!/.swiftlint.yml
!/.swiftlint/

# Top-level entries (opt-in only)
# First ignore all, then whitelist specific folders and files
/*
!/Sources/
!/Tests/
!/Experiments/
!/Research/
!/.github/
!/Package.swift
!/LICENSE.md

# Documentation (opt-in for whitelisted .md files and .docc catalogs only)
# Blocks all .md files by default to prevent AI-generated content from being committed
*.md
!README.md
!LICENSE.md
!CHANGELOG.md
!CONTRIBUTING.md
!CODE_OF_CONDUCT.md
!SECURITY.md
!**/*.docc/**/*.md
!**/Research/**/*.md

*.pdf

# SwiftLint
**/.swiftlint/RemoteConfigCache

# Swift Package Manager
.build/
.swiftpm/

# ========== END CANONICAL ==========

# ========== LOCAL OVERRIDES ==========
# Package-specific rules below (preserved during sync)

```

<details>
<summary>All 122 sub-repos using Variant A</summary>

swift-abi-primitives, swift-abstract-syntax-tree-primitives, swift-affine-geometry-primitives, swift-affine-primitives, swift-algebra-affine-primitives, swift-algebra-cardinal-primitives, swift-algebra-field-primitives, swift-algebra-group-primitives, swift-algebra-law-primitives, swift-algebra-linear-primitives, swift-algebra-magma-primitives, swift-algebra-modular-primitives, swift-algebra-module-primitives, swift-algebra-monoid-primitives, swift-algebra-primitives, swift-algebra-ring-primitives, swift-algebra-semiring-primitives, swift-arm-primitives, swift-array-primitives, swift-ascii-parser-primitives, swift-ascii-primitives, swift-ascii-serializer-primitives, swift-async-primitives, swift-backend-primitives, swift-binary-primitives, swift-bit-index-primitives, swift-bit-pack-primitives, swift-bit-primitives, swift-bit-vector-primitives, swift-bitset-primitives, swift-buffer-primitives, swift-cache-primitives, swift-cardinal-primitives, swift-clock-primitives, swift-coder-primitives, swift-collection-primitives, swift-comparison-primitives, swift-complex-primitives, swift-continuation-primitives, swift-cpu-primitives, swift-cyclic-index-primitives, swift-darwin-primitives, swift-decimal-primitives, swift-dependency-primitives, swift-diagnostic-primitives, swift-dictionary-primitives, swift-dimension-primitives, swift-driver-primitives, swift-effect-primitives, swift-endian-primitives, swift-equation-primitives, swift-error-primitives, swift-finite-primitives, swift-formatting-primitives, swift-geometry-primitives, swift-graph-primitives, swift-handle-primitives, swift-hash-primitives, swift-hash-table-primitives, swift-heap-primitives, swift-identity-primitives, swift-infinite-primitives, swift-input-primitives, swift-intermediate-representation-primitives, swift-kernel-primitives, swift-layout-primitives, swift-lexer-primitives, swift-lifetime-primitives, swift-linux-primitives, swift-list-primitives, swift-loader-primitives, swift-locale-primitives, swift-logic-primitives, swift-machine-primitives, swift-matrix-primitives, swift-module-primitives, swift-network-primitives, swift-numeric-primitives, swift-optic-primitives, swift-ordering-primitives, swift-ordinal-primitives, swift-outcome-primitives, swift-parser-primitives, swift-pool-primitives, swift-positioning-primitives, swift-predicate-primitives, swift-property-primitives, swift-queue-primitives, swift-random-primitives, swift-range-primitives, swift-reference-primitives, swift-region-primitives, swift-riscv-primitives, swift-sample-primitives, swift-scalar-primitives, swift-sequence-primitives, swift-serializer-primitives, swift-set-primitives, swift-slab-primitives, swift-slice-primitives, swift-source-primitives, swift-space-primitives, swift-stack-primitives, swift-standard-library-extensions, swift-state-primitives, swift-string-primitives, swift-symbol-primitives, swift-symmetry-primitives, swift-syntax-primitives, swift-system-primitives, swift-terminal-primitives, swift-test-primitives, swift-text-primitives, swift-time-primitives, swift-token-primitives, swift-transform-primitives, swift-tree-primitives, swift-type-primitives, swift-vector-primitives, swift-windows-primitives, swift-witness-primitives, swift-x86-primitives

</details>

---

### Variant B: Skills override (2 sub-repos)

**Hash**: `cedc8a840caece5b5043629e19fa4d9f`
**Sub-repos**: `swift-index-primitives`, `swift-memory-primitives`

Same canonical section as Variant A, but with a local override whitelisting a `Skills/` directory.

**Difference from Variant A** (local overrides section only):

```gitignore
# ========== LOCAL OVERRIDES ==========
# Package-specific rules below (preserved during sync)

# Skills directory for package-specific skills
!/Skills/
!/Skills/**/*.md
```

---

### Variant C: swift-institute sub-repo (1 sub-repo)

**Hash**: `1d611fab9c7aad1b58b6ecba38142c1d`
**Sub-repo**: `swift-institute`

This is the swift-institute nested inside swift-primitives. Has a significantly different canonical section with many additional whitelisted directories and markdown patterns, plus the same local overrides as the parent.

```gitignore
# ========== CANONICAL (auto-synced, do not edit) ==========
# Source: swift-institute
# Sync: Scripts/sync-gitignore.sh or manual

*~
.DS_Store

Package.resolved
DerivedData/
Thumbs.db

# Dot files/directories (opt-in only)
/.*
!/.github
!/.gitignore
!/.spi.yml
!/.swift-format
!/.swiftformat
!/.swiftlint.yml
!/.swiftlint/

# Top-level entries (opt-in only)
# First ignore all, then whitelist specific folders and files
/*
!/.claude/
/.claude/*
!/.claude/skills/
!/Blog/
!/Documentation.docc/
!/Experiments/
!/Implementation/
!/Research/
!/SE-Pitches/
!/Skills/
!/.github/
!/Package.swift
!/LICENSE.md

# Documentation (opt-in for whitelisted .md files and .docc catalogs only)
# Blocks all .md files by default to prevent AI-generated content from being committed
*.md
!README.md
!LICENSE.md
!CHANGELOG.md
!CONTRIBUTING.md
!CODE_OF_CONDUCT.md
!SECURITY.md
!CLAUDE.md
!**/*.docc/**/*.md
!**/Research/**/*.md
!**/Skills/**/*.md
!**/Implementation/**/*.md
!**/Blog/**/*.md
!**/Experiments/**/*.md
!**/SE-Pitches/**/*.md

*.pdf

# SwiftLint
**/.swiftlint/RemoteConfigCache

# Swift Package Manager
.build/
.swiftpm/

# ========== END CANONICAL ==========

# ========== LOCAL OVERRIDES ==========
# Package-specific rules below (preserved during sync)

# Scripts directory for tooling
!/Scripts/

# Documentation catalog
!/Documentation.docc/

# All swift-* primitive packages
!/swift-*/
```

**Differences from Variant A canonical section**:
- Has `!/.claude/` + `/.claude/*` + `!/.claude/skills/` (Claude config whitelisting)
- Has `!CLAUDE.md` in markdown whitelist
- Whitelists many additional top-level directories: `!/Blog/`, `!/Documentation.docc/`, `!/Implementation/`, `!/SE-Pitches/`, `!/Skills/`
- Does NOT whitelist `!/Sources/`, `!/Tests/` (different purpose — documentation home, not code package)
- Additional markdown whitelist patterns: `!**/Skills/**/*.md`, `!**/Implementation/**/*.md`, `!**/Blog/**/*.md`, `!**/Experiments/**/*.md`, `!**/SE-Pitches/**/*.md`
- Local overrides match the parent monorepo (Scripts, Documentation.docc, swift-*)

---

### Variant D: Experiments markdown override (1 sub-repo)

**Hash**: `d9aa2a4ee6ee6d98a1b39195881d349e`
**Sub-repo**: `swift-storage-primitives`

Same canonical section as Variant A, but with a local override whitelisting experiment markdown files.

**Difference from Variant A** (local overrides section only):

```gitignore
# ========== LOCAL OVERRIDES ==========
# Package-specific rules below (preserved during sync)

# Whitelist Experiments markdown (index and documentation)
!**/Experiments/**/*.md
```

---

## Sub-repos WITHOUT .gitignore (7)

These sub-directories have no `.gitignore` file at all:

1. `swift-binary-parser-primitives`
2. `swift-buffer-primitives-migration`
3. `swift-cyclic-primitives`
4. `swift-ownership-primitives`
5. `swift-parser-machine-primitives`
6. `swift-path-primitives`
7. `swift-rendering-primitives`

---

## Differences Between Canonical Sections

The canonical section exists in two forms:

### Form 1: Standard sub-repo canonical (Variants A, B, D — 125 sub-repos)

- Whitelists: `Sources/`, `Tests/`, `Experiments/`, `Research/`, `.github/`, `Package.swift`, `LICENSE.md`
- No `.claude/` whitelisting
- No `CLAUDE.md` whitelisting
- Basic markdown whitelist: `README.md`, `LICENSE.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `**/*.docc/**/*.md`, `**/Research/**/*.md`

### Form 2: Institute canonical (Variant C — 1 sub-repo + parent)

- Whitelists documentation-oriented directories instead of code directories
- Has `.claude/` selective whitelisting
- Has `CLAUDE.md` whitelisting
- Extended markdown whitelist covering Skills, Implementation, Blog, Experiments, SE-Pitches

### Parent vs Form 2 differences

The parent `.gitignore` differs from the `swift-institute` sub-repo's Variant C in the canonical section:
- Parent has `!/.gitmodules` — institute sub-repo does not
- Parent whitelists `!/Sources/`, `!/Tests/` — institute sub-repo does not (it has `!/Implementation/` instead)

---

## Observations

1. **Strong consistency**: 122 of 126 sub-repos (96.8%) use the identical standard `.gitignore`. The sync mechanism is working well.

2. **Missing .gitignore files**: 7 sub-repos lack a `.gitignore` entirely. These may be newer repos that were created after the last sync, or they may be deprecated/migration repos (e.g., `swift-buffer-primitives-migration`).

3. **Canonical section drift**: The standard sub-repo canonical (Form 1) is missing `!CLAUDE.md` which the parent and institute variants include. If sub-repos ever get their own `CLAUDE.md`, it would be git-ignored.

4. **Local override patterns**: Only 3 sub-repos have local overrides (Skills whitelisting for index/memory-primitives, Experiments markdown for storage-primitives). This suggests most sub-repos do not need package-specific rules.
