# .gitignore Audit — swift-foundations

**Date**: 2026-03-12
**Scope**: Parent `.gitignore` + all `swift-*/` sub-repo `.gitignore` files in `/Users/coen/Developer/swift-foundations/`

---

## Summary

| Metric | Count |
|--------|-------|
| Total sub-repos (`swift-*/`) | 123 |
| Sub-repos WITH `.gitignore` | 119 |
| Sub-repos WITHOUT `.gitignore` | 4 |
| Unique `.gitignore` variants (by hash) | 6 |

---

## Sub-repos WITHOUT .gitignore

| Sub-repo | Status |
|----------|--------|
| `swift-identities` | MISSING |
| `swift-markdown-html-rendering` | MISSING |
| `swift-svg` | MISSING |
| `swift-svg-rendering` | MISSING |

---

## Parent .gitignore

**Path**: `/Users/coen/Developer/swift-foundations/.gitignore`

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

# All swift-* foundation packages
!/swift-*/
```

---

## Variant A — Standard (102 sub-repos)

The majority variant. Canonical section only, no local overrides. No `!/Experiments/`, no `!/Research/`, no `!CLAUDE.md`, no `!**/Research/**/*.md`.

**Hash**: `c7bd6530c5cdabba88b7923783f5eb3b`

**Representative**: `swift-io/.gitignore`

**Sub-repos using this variant** (102): swift-abstract-syntax-tree, swift-application-binary-interface, swift-ascii, swift-async, swift-backend, swift-basic-auth, swift-certificates, swift-command-line, swift-compiler, swift-concise-binary-object-representation, swift-config, swift-config-toml, swift-config-yaml, swift-console, swift-cross-site-request-forgery, swift-crypto, swift-css-html-rendering, swift-darwin, swift-decimals, swift-dependencies, swift-diagnostic, swift-diagnostics, swift-digest-auth, swift-dns-cache, swift-domain-name-system, swift-driver, swift-effects, swift-email, swift-environment, swift-feature-flags, swift-file-system, swift-graceful-shutdown, swift-health, swift-http, swift-http-body, swift-http-compression, swift-http-content-negotiation, swift-http-cookies, swift-http-cors, swift-http-etag, swift-http-headers, swift-http-range, swift-http-redirect, swift-http-routing, swift-http2, swift-http3, swift-intermediate-representation, swift-io, swift-json, swift-json-web-encryption, swift-json-web-key, swift-json-web-signature, swift-json-web-token, swift-kernel, swift-keyvalue, swift-least-recently-used, swift-lexer, swift-linux, swift-loader, swift-log, swift-log-json, swift-memory, swift-metrics, swift-migrations, swift-module, swift-msgpack, swift-numerics, swift-oauth, swift-oauth-pkce, swift-parsers, swift-password, swift-paths, swift-plist, swift-pool-connections, swift-pools, swift-posix, swift-process, swift-protobuf, swift-pubsub, swift-random, swift-redis, swift-runtime, swift-scheduler, swift-secrets, swift-signal, swift-sockets, swift-source, swift-sql, swift-sql-mysql, swift-sql-postgres, swift-sql-sqlite, swift-strings, swift-symbol, swift-syntax, swift-systems, swift-time, swift-time-based-one-time-password, swift-time-to-live, swift-toml, swift-tracing, swift-translating, swift-transport-layer-security, swift-type, swift-websocket, swift-windows, swift-witnesses, swift-xml, swift-yaml

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

---

## Variant B — With Experiments/Research (5 sub-repos)

Same canonical section as Variant A but whitelists `!/Experiments/`, `!/Research/`, `!CLAUDE.md`, and `!**/Research/**/*.md` in the canonical block. Empty local overrides.

**Hash**: `0267829ab734578755884788ae796f65`

**Sub-repos**: swift-copy-on-write, swift-html, swift-pdf, swift-pdf-html-rendering, swift-pdf-rendering

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

---

## Variant C — swift-institute (1 sub-repo)

Heavily customized for the institute monorepo. Whitelists Blog, Documentation.docc, Experiments, Implementation, Research, SE-Pitches, Skills, `.claude/skills/`, `!CLAUDE.md`, and multiple `!**/<dir>/**/*.md` patterns. Local overrides add Scripts, Documentation.docc, and `swift-*/`.

**Hash**: `1d611fab9c7aad1b58b6ecba38142c1d`

**Sub-repos**: swift-institute

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

---

## Variant D — Legacy/Partial (3 sub-repos)

Missing the canonical header, `.DS_Store`, `!/.swiftlint/`, top-level `/*` ignore-all pattern, `*.pdf`, `.build/`, `.swiftpm/`, and SwiftLint cache rule. Only has dot-file ignores and markdown whitelisting. This appears to be an older format that predates the sync script.

**Hash**: `392fb6180c9a11f9859d398830fb24b9`

**Sub-repos**: swift-clocks, swift-css, swift-html-rendering

```gitignore
*~

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
```

---

## Variant E — swift-testing (1 sub-repo)

Standard canonical section with local overrides whitelisting `!/Experiments/`, `!/Research/`, and markdown files within those directories. Uses non-rooted glob pattern `!Research/**/*.md` and `!Experiments/**/*.md` (no leading `**/`).

**Hash**: `a0884cf001dfd4a437510d9113ec6e17`

**Sub-repos**: swift-testing

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

*.pdf

# SwiftLint
**/.swiftlint/RemoteConfigCache

# Swift Package Manager
.build/
.swiftpm/

# ========== END CANONICAL ==========

# ========== LOCAL OVERRIDES ==========
# Package-specific rules below (preserved during sync)

!/Experiments/
!/Research/
!Research/**/*.md
!Experiments/**/*.md
```

---

## Variant F — swift-tests (1 sub-repo)

Standard canonical section with local overrides whitelisting `!/Research/` and `!Research/*.md` (single-level glob, not recursive).

**Hash**: `b25d32c557e98832081f1f049e5e5407`

**Sub-repos**: swift-tests

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

*.pdf

# SwiftLint
**/.swiftlint/RemoteConfigCache

# Swift Package Manager
.build/
.swiftpm/

# ========== END CANONICAL ==========

# ========== LOCAL OVERRIDES ==========
# Package-specific rules below (preserved during sync)
!/Research/
!Research/*.md
```

---

## Key Differences Between Variants

| Feature | Parent | A (102) | B (5) | C (institute) | D (3) | E (testing) | F (tests) |
|---------|--------|---------|-------|----------------|-------|-------------|-----------|
| Canonical header | Yes | Yes | Yes | Yes | **No** | Yes | Yes |
| `.DS_Store` | Yes | Yes | Yes | Yes | **No** | Yes | Yes |
| `!/.swiftlint/` | Yes | Yes | Yes | Yes | **No** | Yes | Yes |
| Top-level `/*` ignore-all | Yes | Yes | Yes | Yes | **No** | Yes | Yes |
| `!/Sources/` + `!/Tests/` | Yes | Yes | Yes | No (custom dirs) | **No** | Yes | Yes |
| `!/Experiments/` | Yes | No | **Yes (canonical)** | **Yes (canonical)** | No | **Yes (local)** | No |
| `!/Research/` | Yes | No | **Yes (canonical)** | **Yes (canonical)** | No | **Yes (local)** | **Yes (local)** |
| `!CLAUDE.md` | Yes | No | No | **Yes** | No | No | No |
| `!**/Research/**/*.md` | Yes | No | **Yes** | **Yes** | No | No (different glob) | No (different glob) |
| `*.pdf` | Yes | Yes | Yes | Yes | **No** | Yes | Yes |
| `.build/` + `.swiftpm/` | Yes | Yes | Yes | Yes | **No** | Yes | Yes |
| SwiftLint cache rule | Yes | Yes | Yes | Yes | **No** | Yes | Yes |
| `!/.claude/` + skills | Yes | No | No | **Yes** | No | No | No |
| `!/.gitmodules` | **Yes** | No | No | No | No | No | No |
| `!/swift-*/` (local) | **Yes** | No | No | **Yes** | No | No | No |

---

## Observations

1. **4 missing .gitignore files**: `swift-identities`, `swift-markdown-html-rendering`, `swift-svg`, `swift-svg-rendering` have no `.gitignore` at all. They rely solely on the parent `.gitignore`.

2. **3 stale/legacy files (Variant D)**: `swift-clocks`, `swift-css`, `swift-html-rendering` have a pre-sync-script format. They are missing `.DS_Store`, `!/.swiftlint/`, the top-level `/*` ignore-all pattern, `*.pdf`, `.build/`, `.swiftpm/`, and the SwiftLint cache rule. These should be re-synced.

3. **Inconsistent Experiments/Research whitelisting**: 5 sub-repos (Variant B) have `!/Experiments/` and `!/Research/` baked into the canonical section, while 2 others (Variants E, F) achieve it via local overrides. The canonical section should not vary between sub-repos if it is truly auto-synced — Variant B repos appear to have a different canonical template.

4. **`!CLAUDE.md` only in parent + institute**: The parent `.gitignore` and `swift-institute` whitelist `!CLAUDE.md`, but no other sub-repo does. If any sub-repo ever adds a `CLAUDE.md`, it will be ignored.

5. **Glob pattern inconsistency for Research markdown**: The parent and Variant B use `!**/Research/**/*.md` (recursive). Variant E uses `!Research/**/*.md` (anchored, recursive). Variant F uses `!Research/*.md` (anchored, single-level only — will not match subdirectories).

6. **`!/.gitmodules` only in parent**: Only the parent `.gitignore` whitelists `.gitmodules`, which is correct since sub-repos are not expected to have submodules themselves.
