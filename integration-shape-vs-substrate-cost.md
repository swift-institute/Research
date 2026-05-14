# Integration-Shape vs Substrate Cost — Skill-Amendment Proposal

<!--
---
version: 1.0.0
last_updated: 2026-05-14
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

The streaming-deserialize regression arc (`swift-institute/Audits/streaming-deserialize-regression-profile.md`, commit `de3e3c8`) revealed a measurement-discipline gap in the institute's cost-model priors. The placement audit's Phase 1 defense of T-1's typed-primitive composition (`swift-institute/Audits/streaming-deserialize-placement-audit.md` §Candidate 3) cited `[INFRA-003]`'s zero-cost expectation:

> Per `[INFRA-003]`'s documented zero-cost guarantee for `UnsafePointer[O: Ordinal.Protocol]` and `Span` extensions, the typed forms compile through `@inlinable` to identical assembly. The `Int(bitPattern: cursor)` is structurally a `cursor.rawValue.rawValue` — Tagged + Ordinal both unwrap to UInt with no runtime work.

This claim is **structurally correct at the substrate level**. The profile investigation confirmed it empirically (cross-module inlining hypothesis REFUTED — Scanner methods inline; typed-Position arithmetic produces identical assembly).

But the arc still produced a +25% measured regression on the canonical 86 MB symbol-graph workload. The diagnosis: T-1 moved position work from the error path (rare) to the hot path (per-token / per-byte). The substrate's per-operation cost was identical to pre-T-1 — but the *integration shape* (where on the call graph the operation fires) was not.

Specifically:
- ~3.8 M `tracker.newline(at:)` calls per parse in `skipWhitespace` on a 4.2 %-newline workload (skipWhitespace ticks went from 3 pre-T-1 to 11,074 post-T-1).
- ~90 K `let startLocation = lexer.scanner.location` token-start captures across the four lexer entry points.

Both fire points pay `[INFRA-003]`-level zero-cost-per-operation — and that's exactly how 19 ms of compounded wall-clock cost accumulated. The substrate prior was satisfied; the integration prior was violated.

## Question

Should the institute formalise the substrate-vs-integration-shape distinction as a measurement-discipline rule? If so, where does it live?

Equivalently: how does a future audit prevent the same failure mode — accepting an `[INFRA-003]`-rooted zero-cost claim as sufficient evidence to ship a migration that relocates work between cold and hot paths?

## Proposed rule

**Statement** (draft):

> Typed-primitive substrate cost claims (e.g., `[INFRA-003]`'s "compiles to identical assembly," `[CONV-010]`'s "typed-arithmetic is zero-cost") apply at the *substrate level* — per-operation, in isolation. They do not bound *integration-shape cost* — where on the call graph the substrate operations fire.
>
> A migration arc that relocates work between cold paths (e.g., error reporting, infrequent introspection) and hot paths (e.g., per-byte cursor, per-token lex) MUST measure end-to-end at the hot-path entry point, NOT at the substrate. A substrate-only verification (e.g., "the new typed accessor compiles to the same assembly as the old raw accessor") is *necessary but not sufficient* evidence for a migration that changes call-graph shape.
>
> The substrate prior is preserved; the rule names its scope. The companion `[BENCH-011]` integration-probe rule fires for migrations that change call-graph shape, the same way it fires for storage swaps under Copyable wrappers.

## Skill home — options

The rule sits at the intersection of three skills:

| Skill | Fit | Why |
|---|---|---|
| **existing-infrastructure** (where `[INFRA-003]` lives) | Could amend `[INFRA-003]` body to add the substrate-vs-integration caveat | Lowest churn — the existing rule grows a clarifying note. Risk: the rule's body becomes catalog + measurement-discipline meta, two distinct concerns conflated. |
| **benchmark** (where `[BENCH-011]` lives) | Could add a new `[BENCH-012]` companion rule "Integration Probe Required for Call-Graph-Shape Migrations" | Cleanest separation — measurement discipline lives in benchmark. The new rule extends `[BENCH-011]`'s "integration probe required" coverage to a new trigger class (call-graph shape change, not just Copyable wrappers). |
| **audit** (where the case-analysis discipline lives) | Could add a checklist item to the audit skill: "when a Phase-1 candidate defense cites a zero-cost prior, additionally verify the integration shape hasn't shifted" | Catches the failure at audit-writing time, the cheapest point. Doesn't replace the substrate or benchmark rules; complements them at a different stage. |

**Recommendation**: all three. The amendments compose:

1. **existing-infrastructure**: amend `[INFRA-003]`'s body with a brief note pointing readers to the integration-shape constraint (one paragraph, ~5 lines).
2. **benchmark**: add `[BENCH-012]` (or `[BENCH-011a]`) extending the integration-probe trigger class to call-graph-shape migrations.
3. **audit**: add an explicit audit-Phase-1 check that "a substrate cost-model citation must be paired with a hot-path integration assertion when the candidate relocates work between paths."

Each is small. Together they cover the failure mode at three points: substrate citation site, measurement gate, audit gate.

## When the rule fires

| Migration shape | Rule fires? |
|---|---|
| Renaming a typed type (no call-graph change) | No |
| Replacing a raw `Int` with a typed `Text.Position` at the same call sites (no shift between cold/hot paths) | No |
| Adding incremental tracker maintenance to a per-byte hot-path inspector (T-1's exact shape) | **Yes** |
| Eager capture of an expensive accessor at token-start sites (pre-Option-A shape) | **Yes** |
| Wrapping a previously-direct storage access behind a Copyable wrapper at a hot-path read | **Yes** (already covered by `[BENCH-011]` — this rule generalises) |
| Moving an error-path computation onto the success path (e.g., always validating, not just on error) | **Yes** |

## Out of scope

- The actual skill text edits — Phase 2 of a future skill-lifecycle session.
- Renaming `[INFRA-003]` or restructuring `[BENCH-011]` — the proposal is additive, not refactor.
- Other `[INFRA-*]` rules that may carry similar zero-cost claims in their bodies — should be reviewed once the rule lands, but not pre-emptively.

## References

- `swift-institute/Audits/streaming-deserialize-regression-profile.md` (commit `de3e3c8`) — the failure mode in concrete form.
- `swift-institute/Audits/streaming-deserialize-placement-audit.md` (commit `e8a06b7`, amended 2026-05-14) — the site of the original substrate-only defense.
- `swift-institute/Skills/existing-infrastructure/SKILL.md` `[INFRA-003]` (line 743) — the cited zero-cost prior.
- `swift-institute/Skills/benchmark/SKILL.md` `[BENCH-011]` (line 363) — the integration-probe rule this proposal extends.
- `swift-foundations/swift-json/Research/parse-performance.md` v1.3.0 — closes the arc; documents the residual cost-model lesson.

## Provenance

Surfaced 2026-05-14 during Phase 2 doc-consequence work of the streaming-deserialize regression closing. Principal direction at Phase 1 close: "[INFRA-003] amendment candidate noted." The amendment turns out to compose better as a benchmark-skill addition + audit-skill addition + INFRA-003 clarifying note, rather than a single rewrite — recorded as a multi-skill RECOMMENDATION for the principal to action via skill-lifecycle.
