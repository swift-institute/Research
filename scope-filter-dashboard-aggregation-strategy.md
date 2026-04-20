# Scope-Filter Dashboard Aggregation Strategy

**Status**: IN_PROGRESS
**Tier**: 2
**Scope**: ecosystem-wide

## Context

The 2026-04-18 JSON-authoritative migration completed the Research + Experiments + Reflections + Audits + Blog indexes as canonical JSON served from sibling repos' `main` branches, with the swift-institute.org dashboard fetching `raw.githubusercontent.com` directly at runtime (CORS-verified, 5-minute cache TTL). The handoff for the ecosystem-wide per-package migration landed at `/Users/coen/Developer/HANDOFF.md` (since executed per reflection `2026-04-18-ecosystem-index-migration-completion-and-batch-git-edges.md`).

The dashboard currently displays two corpora (swift-institute's own Research + Experiments). Post-migration, ~150 additional `_index.json` files exist across `swift-primitives`, `swift-foundations`, `swift-standards` per-package repos. The question of *how* to expose those in the dashboard is unresolved.

## Question

**How does the swift-institute.org dashboard discover, aggregate, and filter across ~70+ per-package `_index.json` corpora with potentially varying schema shapes?**

Sub-questions:
- **Discovery**: manifest file committed to swift-institute.org? GitHub API enumeration (submodule list)? Hard-coded list in dashboard.js? Automated crawl?
- **Schema harmonization**: per-package indexes may carry slight shape variations (Research 4-col vs 5-col, experiments per-package vs top-level) — how does the dashboard normalize without forcing every per-package owner into lockstep?
- **Scope-pill UX**: some corpora are large (swift-memory-primitives/Research, 45 rows), others sparse — how does filtering present when corpus size varies by 10×?
- **Fetch strategy**: 70+ parallel `fetch()` calls from the browser is expensive on page load; batch via a CI-rolled-up aggregate JSON, or serve dashboard-side progressive loading?

## Analysis (stub)

Proposed investigation:

1. **Manifest discovery**: write the simplest viable manifest (`swift-institute.org/dashboard/corpora.json` listing URLs) and evaluate whether it's actually worse than GitHub API enumeration.
2. **Schema probe**: audit a sample of 10 per-package `_index.json` files against the canonical Research schema; enumerate divergences.
3. **UX prototype**: mock the scope-pill filter with fake data at the observed size ratios; iterate.
4. **Performance**: measure cold-load time for 70 parallel fetches against raw.githubusercontent.com; compare with a CI-rolled-up aggregate.

## Outcome (placeholder)

Pending. Expected artifacts: a manifest convention (if that's the chosen discovery mechanism), a dashboard aggregation layer with progressive loading, and a scope-pill UX iteration that handles the size-variance gracefully.

## Provenance

- `Research/Reflections/2026-04-18-json-authoritative-migration-sweep.md`
- `Research/Reflections/2026-04-18-two-homepages-mixed-chrome-dashboard.md`
- `Research/Reflections/2026-04-18-ecosystem-index-migration-completion-and-batch-git-edges.md`

## References

- `swift-institute.org/dashboard/` — current two-corpus implementation
- `Skills/research-process/SKILL.md` — `[RES-003c]` JSON-authoritative index schema
