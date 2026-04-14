# Gitignore Sync Strategy

<!--
---
version: 1.0.0
last_updated: 2026-03-12
status: DECISION
---
-->

## Context

The Swift Institute ecosystem spans ~370 git repositories across four directories:
- **swift-primitives**: 1 parent + 133 sub-repos (126 have .gitignore)
- **swift-standards**: 1 parent + 111 sub-repos (all have .gitignore)
- **swift-foundations**: 1 parent + 123 sub-repos (119 have .gitignore)
- **swift-institute**: 1 standalone repo

A canonical/local-override `.gitignore` convention already exists (header markers, sync reference), but drift has occurred. The html-rendering incident (`.build/` committed, 118 MB binary blocked push) exposed that some repos still use a legacy format missing critical rules.

## Question

How should the canonical `.gitignore` template be defined, and what sync mechanism should keep all ~370 repos consistent while preserving per-repo local overrides?

## Current State Inventory

### Templates in the wild

| Template | Repos | Key characteristics |
|----------|-------|---------------------|
| **Primitives canonical** (full) | 122 primitives sub-repos | Has `!/Experiments/`, `!/Research/`, `!**/Research/**/*.md` |
| **Foundations canonical** (reduced) | 102 foundations sub-repos | Missing `!/Experiments/`, `!/Research/`, `!**/Research/**/*.md` |
| **Foundations canonical** (full) | 5 foundations sub-repos | Matches primitives canonical |
| **Institute canonical** | swift-institute + nested copies | Extended dirs (Blog, Skills, Swift Evolution, Implementation) |
| **Legacy** (no header) | 3 foundations sub-repos | Missing `.build/`, `.swiftpm/`, `/*` opt-in, `.DS_Store` |
| **Minimal** | standards parent | 2 lines: `.build/`, `*.xcworkspace/` |
| **Missing** | 11 repos (7 primitives, 4 foundations) | No `.gitignore` at all |

### Drift points

| Issue | Count | Risk |
|-------|-------|------|
| Missing `.build/` ignore | 3 legacy + 11 missing = 14 repos | **HIGH** — binary artifacts committed |
| Missing `!/Experiments/` + `!/Research/` in canonical | 102 foundations sub-repos | MEDIUM — dirs silently ignored |
| Missing `!CLAUDE.md` whitelist | All sub-repos except institute | LOW — no sub-repos have CLAUDE.md yet |
| Missing `!**/Research/**/*.md` | 102 foundations sub-repos | MEDIUM — research markdown ignored |
| Standards parent uses legacy 2-line format | 1 repo | LOW — sub-repos are fine |
| No `.gitignore` at all | 11 repos | **HIGH** — no protection |

## Analysis

### Option A: Single canonical template for all sub-repos

One template used by every sub-repo across all three monorepos. Monorepo parents and swift-institute get their own template (they need `!/.gitmodules`, `!/.claude/`, `!/swift-*/`, etc.).

**Template: sub-repo canonical**

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
!**/Experiments/**/*.md

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

**Advantages**:
- One template to maintain
- Every sub-repo gets `!/Experiments/` and `!/Research/` — safe by default even if they don't use them yet
- Eliminates the foundations Variant A / Variant B split
- `!**/Experiments/**/*.md` added (currently missing everywhere)

**Disadvantages**:
- Sub-repos that don't have Experiments/ or Research/ carry unused rules (harmless)

### Option B: Two canonical templates (code-repo vs documentation-repo)

Separate templates for code sub-repos (Sources/Tests) and documentation repos (swift-institute with Blog/Skills/etc.).

**Advantages**:
- More precise — each template only whitelists what that repo type uses

**Disadvantages**:
- Two templates to maintain and keep in sync
- The only repo that needs the documentation template is swift-institute (and its nested copies)
- Adds complexity to the sync script (must classify each repo)

### Option C: Layered templates (base + role extension)

A base template with all common rules, plus role-specific extensions appended.

**Advantages**:
- Maximum reuse
- Easy to add new roles

**Disadvantages**:
- Over-engineered for the current need (only two roles exist)
- More complex sync script
- Harder to read the resulting .gitignore

### Comparison

| Criterion | A: Single | B: Two templates | C: Layered |
|-----------|-----------|------------------|------------|
| Simplicity | Best | Good | Worst |
| Maintenance cost | 1 template | 2 templates | 1 base + N extensions |
| Coverage | Complete | Complete | Complete |
| Unused rules | A few harmless lines | None | None |
| Sync script complexity | Simple | Medium | High |
| Current repo count needing special template | 1 (institute) + 4 parents | Same | Same |

### Sync mechanism

The script must:

1. **Source of truth**: A single file in `swift-institute/` (e.g., `Scripts/gitignore-canonical.txt`)
2. **Preserve local overrides**: Replace everything between `CANONICAL` markers, keep everything after `LOCAL OVERRIDES`
3. **Handle missing .gitignore**: Create new file with canonical template + empty local overrides section
4. **Handle legacy format** (no markers): Treat entire file as local overrides, prepend canonical section
5. **Iterate**: Process all `swift-*/` sub-directories in each monorepo, then the parent repos
6. **Dry-run mode**: Show what would change without writing
7. **Monorepo parent handling**: Parents use the same canonical but need local overrides for `!/swift-*/`, `!/.gitmodules`, `!/.claude/`, etc. — these are in the LOCAL OVERRIDES section and preserved.

Script location: `swift-institute/Scripts/sync-gitignore.sh`

### Monorepo parents and swift-institute

These repos have the **same canonical section** as sub-repos, plus **local overrides** for their specific needs:

| Repo | Local overrides needed |
|------|----------------------|
| swift-primitives parent | `!/swift-*/`, `!/Scripts/`, `!/Documentation.docc/`, `!/Skills/`, `!/.gitmodules`, `!/.claude/` + skills, `!CLAUDE.md` |
| swift-standards parent | `!/swift-*/`, `!/Scripts/`, `!/Documentation.docc/` (upgrade from 2-line legacy) |
| swift-foundations parent | `!/swift-*/`, `!/Scripts/`, `!/Documentation.docc/`, `!/.gitmodules`, `!/.claude/` + skills, `!CLAUDE.md` |
| swift-institute | `!/Blog/`, `!/Documentation.docc/`, `!/Implementation/`, `!/Swift Evolution/`, `!/Skills/`, `!/Scripts/`, `!/.claude/` + skills, `!CLAUDE.md`, `!**/Skills/**/*.md`, `!**/Implementation/**/*.md`, `!**/Blog/**/*.md`, `!**/Swift Evolution/**/*.md` |

This means swift-institute does NOT need a separate canonical template — its unique directories are local overrides.

### Open question: `!CLAUDE.md` and `!**/Research/**/*.md` in canonical vs local

Two reasonable positions:

**Position 1**: Put `!CLAUDE.md` in the canonical section. Every repo *could* have a CLAUDE.md, and blocking it by default is a footgun.

**Position 2**: Keep it in local overrides. Only repos that actually have a CLAUDE.md need it.

**Recommendation**: Put `!CLAUDE.md` in canonical. The cost of an unused rule is zero; the cost of a missing rule is silent data loss. Same reasoning applies to `!**/Research/**/*.md` and `!**/Experiments/**/*.md`.

## Outcome

**Status**: RECOMMENDATION

### Decision

**Option A** (single canonical template) with `!CLAUDE.md` included in the canonical section.

Rationale:
- The only repo that needs a truly different canonical section is swift-institute — but we can achieve this through local overrides instead of a separate template
- One template eliminates drift by construction
- Unused whitelist rules (`!/Experiments/` in repos without experiments) are harmless
- The `.build/` incident proves that under-protection is the real risk

### Implementation plan

1. Create canonical template at `swift-institute/Scripts/gitignore-canonical.txt`
2. Create `swift-institute/Scripts/sync-gitignore.sh` with:
   - `--dry-run` flag
   - Marker-based replacement (preserve local overrides)
   - Legacy detection (no markers → treat entire file as local overrides)
   - Missing file creation
3. Run with `--dry-run` first across all repos
4. Apply, commit, push

### Remaining question for discussion

The new html-rendering `.gitignore` you wrote puts `!/Sources/`, `!/Tests/`, `!/Experiments/`, `!/Research/` etc. in the canonical section. But `README.md` at root is ignored by `/*` (line 24) and only un-ignored by `!README.md` in the markdown section (line 19). Git's re-inclusion rules mean `!README.md` **does not** override `/*` because the parent directory match takes precedence for files.

We need `!/README.md` in the top-level whitelist section (alongside `!/LICENSE.md`), or restructure to avoid the conflict. This applies to all repos using the `/*` pattern. Deferring per your request, but flagging it as a required fix before the sync roll-out.

## References

- Audit data: `Research/_scratch/gitignore-audit-{primitives,standards,foundations}.md`
- `.gitignore` pattern documentation: `git help gitignore`
- Incident trigger: html-rendering `.build/` (118 MB binary) blocked push on 2026-03-12
