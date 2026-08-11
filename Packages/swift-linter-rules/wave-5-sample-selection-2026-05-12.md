# Wave 5 Sample Selection — 10-Package Proposal

<!--
---
version: 1.0.0
last_updated: 2026-05-12
status: PROPOSAL
---
-->

## Context

Companion to [wave-5-l2-l3-leaf-triage-scope-2026-05-12.md](wave-5-l2-l3-leaf-triage-scope-2026-05-12.md)
(SCOPE). The scope doc enumerated 257 L2 + L3 leaves and recommended a 5+5
representative-sample-first dispatch. This document IS the 10-package proposal,
ready for orchestrator review.

Selection criteria (per Batch A.3 brief):
- Cover the **L2 spec-mirroring band** (RFC, ISO, WHATWG, platform-standard).
- Cover the **L3 composition-heavy band** (foundations that compose 5+ primitives).
- Pick **high-traffic packages over edge cases** for first lint passes.

## L2 Sample (5 packages)

| # | Package | One-line rationale |
|---|---|---|
| 1 | `swift-ietf/swift-rfc-3986` | URI parsing — canonical RFC spec-mirroring with deep consumer graph (auth, http, file-url) |
| 2 | `swift-iso/swift-iso-9945` | POSIX kernel surface — densest `@unsafe` / `nonisolated(unsafe)` band in L2; stress-tests MEM-SAFE rules |
| 3 | `swift-ietf/swift-rfc-4122` | UUID — RawValue / BitPattern initializers; tests raw-encoding idiom for [API-NAME-*] |
| 4 | `swift-standards/swift-darwin-standard` | Platform-mirroring — exercises [API-NAME-003] spec-mirroring on Darwin types (Mach, sysctl, kqueue) |
| 5 | `swift-standards/swift-html-standard` | Markup spec — result-builder-shaped DOM; tests [RULE-001-008 result-builder] family |

## L3 Sample (5 packages)

| # | Package | One-line rationale |
|---|---|---|
| 6 | `swift-foundations/swift-io` | Workspace anchor — broadest L3 dep graph (~30 primitives); composition stress at the top |
| 7 | `swift-foundations/swift-linter-rules` | Self-referential — running rules on rules surfaces meta-amendment opportunities and rule-pack-internal patterns |
| 8 | `swift-foundations/swift-executors` | Concurrency-heavy — many `Atomic<...>` / `nonisolated(unsafe)` / actor boundaries; stress for Wave 4 carve-out |
| 9 | `swift-foundations/swift-file-system` | Cross-cutting L3 — composes path / glob / file primitives; high-traffic by transitive consumption |
| 10 | `swift-foundations/swift-html-render` | Render DSL — result-builder + throws-typed + async-density combined; tests builder rules at L3 scale |

## Coverage Check

**L2 spec-mirroring band**: RFC × 2 (3986, 4122), ISO × 1 (9945), platform-standard × 1
(darwin-standard), WHATWG-shape × 1 (html-standard) → 5 picks cover the four
predominant spec lineages.

**L3 composition-heavy band**: workspace anchor × 1 (io), self-reflexive × 1
(linter-rules), concurrency × 1 (executors), cross-cutting × 1 (file-system),
DSL × 1 (html-render) → 5 picks cover the five predominant L3 composition shapes.

**High-traffic vs edge**: every pick is a canonical consumer or producer in its
band. No picks are experiments, sandboxes, or one-off niches.

## Not Selected (and why)

Representative subset, not exhaustive. Explicit non-picks worth noting:
- `swift-ietf/swift-rfc-*` (many) — covered by 3986 + 4122 as representative RFC parsing / encoding shapes; extend after first-pass patterns surface.
- `swift-foundations/swift-clocks` / `swift-foundations/swift-async` / `swift-foundations/swift-crypto` — substantive but more focused than the picks above; queue for second-pass after pattern catalog grows.
- `swift-microsoft/swift-windows-32` / `swift-linux-foundation/swift-linux-standard` — platform-standard band already covered by darwin-standard; defer until darwin's pattern set surfaces.
- `swift-whatwg/swift-whatwg-url` — overlaps with rfc-3986's URI surface; one URL/URI pick is enough for first pass.

## Next Step

Orchestrator review of the 10-package selection. After approval, the Wave 5
dispatch begins per the scope doc's per-leaf ledger shape (`Research/lint-pass-2026-05-12-{leaf}.md`
mirroring Wave 2's per-leaf ledger format).

## Cross-references

- [wave-5-l2-l3-leaf-triage-scope-2026-05-12.md](wave-5-l2-l3-leaf-triage-scope-2026-05-12.md) (SCOPE — this is the SELECTION companion)
- [wave-2-rule-amendments-2026-05-11.md](wave-2-rule-amendments-2026-05-11.md) (L1 template — what each Wave 5 leaf-ledger will mirror)
