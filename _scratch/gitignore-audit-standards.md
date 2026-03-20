# .gitignore Audit: swift-standards Ecosystem

**Date**: 2026-03-12

## Summary

| Location | Has .gitignore | MD5 |
|----------|---------------|-----|
| Parent (`swift-standards/`) | Yes | `5726a713a1504ef78aca2dea7bcf79b5` |
| All 111 sub-repos (`swift-*/`) | Yes (111/111) | `0267829ab734578755884788ae796f65` (identical) |

All 111 sub-repos have a `.gitignore` file. Every sub-repo `.gitignore` is byte-identical. The parent `.gitignore` differs from the sub-repos.

---

## Parent .gitignore

**Path**: `/Users/coen/Developer/swift-standards/.gitignore`

```gitignore
.build/
*.xcworkspace/
```

Minimal: only ignores `.build/` and `*.xcworkspace/`. No canonical header, no dotfile management, no documentation filtering.

---

## Sub-repo .gitignore (shared by all 111 sub-repos)

**Representative path**: `/Users/coen/Developer/swift-standards/swift-rfc-4122/.gitignore`

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

## Sub-repos with .gitignore (all 111)

swift-base62-primitives, swift-bcp-47, swift-color-standard, swift-css-standard, swift-w3c-cssom, swift-domain-standard, swift-ecma-48, swift-email-standard, swift-emailaddress-standard, swift-epub-standard, swift-html-standard, swift-iec-61966, swift-ieee-754, swift-incits-4-1986, swift-ipv4-standard, swift-ipv6-standard, swift-iso-14496-22, swift-iso-15924, swift-iso-21320, swift-iso-3166, swift-iso-32000, swift-iso-639, swift-iso-8601, swift-iso-9899, swift-iso-9945, swift-json-feed-standard, swift-locale-standard, swift-pdf-standard, swift-rfc-1034, swift-rfc-1035, swift-rfc-1123, swift-rfc-1950, swift-rfc-1951, swift-rfc-2045, swift-rfc-2046, swift-rfc-2183, swift-rfc-2369, swift-rfc-2387, swift-rfc-2388, swift-rfc-2822, swift-rfc-3339, swift-rfc-3492, swift-rfc-3596, swift-rfc-3986, swift-rfc-3987, swift-rfc-4007, swift-rfc-4122, swift-rfc-4287, swift-rfc-4291, swift-rfc-4648, swift-rfc-5234, swift-rfc-5280, swift-rfc-5321, swift-rfc-5322, swift-rfc-5646, swift-rfc-5890, swift-rfc-5952, swift-rfc-6068, swift-rfc-6238, swift-rfc-6265, swift-rfc-6455, swift-rfc-6531, swift-rfc-6570, swift-rfc-6585, swift-rfc-6749, swift-rfc-6750, swift-rfc-6891, swift-rfc-6902, swift-rfc-7301, swift-rfc-7396, swift-rfc-7405, swift-rfc-7515, swift-rfc-7516, swift-rfc-7517, swift-rfc-7519, swift-rfc-7578, swift-rfc-7616, swift-rfc-7617, swift-rfc-7636, swift-rfc-768, swift-rfc-791, swift-rfc-8030, swift-rfc-8058, swift-rfc-8200, swift-rfc-8259, swift-rfc-8288, swift-rfc-8446, swift-rfc-8949, swift-rfc-9000, swift-rfc-9110, swift-rfc-9111, swift-rfc-9112, swift-rfc-9113, swift-rfc-9114, swift-rfc-9293, swift-rfc-9457, swift-rfc-9557, swift-rfc-9562, swift-rfc-template, swift-rss-standard, swift-sockets-standard, swift-svg-standard, swift-time-standard, swift-uri-standard, swift-w3c-css, swift-w3c-epub, swift-w3c-png, swift-w3c-svg, swift-w3c-xml, swift-whatwg-html, swift-whatwg-url

## Sub-repos missing .gitignore

None. All 111 sub-repos have a .gitignore.

---

## Differences

| Aspect | Parent | Sub-repos |
|--------|--------|-----------|
| Canonical header | No | Yes (`auto-synced, do not edit`) |
| `.DS_Store` / `*~` / `Thumbs.db` | No | Yes |
| `Package.resolved` | No | Yes |
| `DerivedData/` | No | Yes |
| Dotfile opt-in (`/.*` + whitelist) | No | Yes |
| Top-level opt-in (`/*` + whitelist) | No | Yes |
| `.md` blocking + whitelist | No | Yes |
| `.pdf` blocking | No | Yes |
| SwiftLint cache | No | Yes |
| `.build/` | Yes | Yes |
| `*.xcworkspace/` | Yes | No |
| `.swiftpm/` | No | Yes |
| Local overrides section | No | Yes (empty) |

The parent `.gitignore` is a minimal 2-line file. The sub-repo canonical `.gitignore` is comprehensive (59 lines) with opt-in whitelisting for top-level entries, dotfiles, and documentation. No sub-repo has added any local overrides.
