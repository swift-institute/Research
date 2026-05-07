---
date: 2026-05-07
session_objective: Validate result-builder ecosystem performance, ship architectural fix, then investigate residual "in-body .map" anomaly that was filed as a loose end in the prior session's research doc
packages:
  - swift-primitives/swift-standard-library-extensions
  - swift-primitives/swift-array-primitives
  - swift-primitives/swift-buffer-primitives
  - swift-primitives/swift-list-primitives
  - swift-primitives/swift-stack-primitives
  - swift-primitives/swift-queue-primitives
  - swift-primitives/swift-heap-primitives
  - swift-primitives/swift-set-primitives
  - swift-primitives/swift-bitset-primitives
  - swift-primitives/swift-dictionary-primitives
  - swift-primitives/swift-tree-primitives
  - swift-foundations/swift-linter
status: processed
processed_date: 2026-05-07
triage_outcomes:
  - type: skill_update
    target: research-process
    description: "[RES-027] Loose-End Follow-Up Requires Extant or Immediate Experiment Package added"
  - type: skill_update
    target: implementation
    description: "[IMPL-105] Overload Accepting Existing Protocol Over New Wrapper Type added to style.md"
  - type: informational
    target: blog
    description: "BLOG-IDEA-079 advance-through-review deferred to separate blog dispatch; Blog/_index.json notes field flags revision-pending state"
---

# Result-builder `.map` anomaly refuted: stdlib's, not the builder's

## What Happened

Session resumed post-compaction with the result-builder ecosystem rollout (Round-1 + Round-2 already shipped: 13 institute Builders + variant convenience inits) and the `/experiment-process` PARTIAL acceptance verdict on a 12-case acceptance suite (6/10 pass at ≤ 1.5× imperative; the 4 failing cases were all `for i in 0..<N { i }` builder bodies at 12–44× of imperative).

Work-arc:

1. **Research-process** authored `Research/result-builder-performance-optimization.md` v1.0.0 RECOMMENDATION proposing Option E (`Repeat<S, Element>` helper type). Validation experiment `result-builder-perf-repeat/` confirmed Repeat works (0.95× of imperative for direct sequences).
2. **User redirect**: "we'd prefer NOT adding a type in standard-library-extensions" + "we control all packages, can change all code." Forced a search for a non-type fix.
3. **Discovery**: bare `buildExpression<S: Sequence>(_:)` overload (Option G — an *overload*, not a *type*) measured at 0.13–0.17× of imperative for direct sequences — *strictly faster* than Repeat, with less code shipped. Combined with Option B (`consume buildPartialBlock`), shipped across 5 stdlib-extensions builders + 13 institute builders. 11 swift-primitives commits pushed in one wave.
4. **Documentation strategy**: principal-directed "linter rule primary, defer DocC." Built `Lint.Rule.ResultBuilderForLoop` SwiftSyntax rule + 28 tests; wired into Tier-1 canonical preset (`swift-institute/.github/Lint.swift`) — first rule graduating to Tier 1.
5. **Blog draft**: BLOG-IDEA-079 captured + drafted (`Blog/Draft/result-builder-for-loop-performance.md`).
6. **User pushback**: "lift outside defeats the purpose" — challenged the post's recommendation tree. Surfaced unresolved 21× in-body `.map` anomaly that the v1.0.0 research doc had filed as "separate investigation."
7. **Investigation experiment** `result-builder-map-investigation/` (16 variants V1–V16). Decisive comparisons (release mode, Swift 6.3.1, N=100, 50000 iters):

| Variant | ns/iter |
|---------|--------:|
| V14 same-module `@inlinable` map standalone | 211 |
| V8 stdlib `Collection.map` standalone | 4,083 (19× slower than V14) |
| V13 same-module map inside builder | 211 (builder adds **zero** measurable overhead) |
| V2 stdlib `.map` inside builder | 4,271 (matches V8) |
| V15 same-module map with `rethrows` | 210 (rules out `rethrows` hypothesis) |

**Outcome**: REFUTED. The slowdown is intrinsic to stdlib `Collection.map` (cross-module specialization gap) and applies inside or outside builder bodies. Builder adds zero measurable overhead. Research doc bumped to v2.1.0; blog draft revised to distinguish the 12–44× builder-specific cost from the ~10× stdlib `.map` cost. Branching `/handoff` written for follow-up literature study via `/research-process` against `/Users/coen/Developer/swiftlang/swift/`.

Also: pushed 4 batches (1 private, 3 public-after-explicit-YES). Local-only commits in `swift-institute/Experiments` (c8c502c) and `swift-institute/Research` (ac91b2f, e14b085) still awaiting per-action push authorization.

## What Worked and What Didn't

**Worked well**:

- **The constraint as forcing function**. The user's "no new type in standard-library-extensions" rule felt like a restriction, but it forced examining whether an *overload* could substitute. The bare-Sequence overload turned out strictly better than Repeat — shorter, no new vocabulary, faster. We'd have shipped a redundant type without the constraint.
- **The 1-hour empirical investigation**. The investigation that refuted the in-body `.map` framing took ~1 hour, dissolved a multi-week design question (whether to ship a `ForEach` type, where it should live, whether to engage `algebra-primitives`). Small empirical work has outsized leverage when it replaces architectural assumptions with data.
- **The blog draft as forcing function for honest synthesis**. Drafting forced the question "what does our recommendation tree actually look like for complex bodies?" The user's "defeats the purpose" pushback exposed muddled framing the experiments table had let pass.

**Didn't work**:

- **Filing a "loose end" without filing the experiment**. The v1.0.0 research doc said the in-body `.map` slowdown was "filed for separate investigation" — but no experiment package was created at v1.0.0 time. The unresolved framing then drove architectural conversations (ForEach question, primitive home selection, `algebra-primitives` consideration) for ~2 weeks before today's investigation refuted it. The cost was absorbed in design-deliberation cycles that an immediate small experiment would have prevented.
- **Initial misdiagnosis**. The investigation experiment took five hypotheses (overload-resolution / type-inference / `rethrows` / lazy-vs-eager / cross-module specialization) before V13's same-module `@inlinable` baseline isolated the cause. Earlier hypotheses were defensible but expensive — the structural test (compare same-module vs stdlib map at the same call site) is the one that should have been V2, not V13.
- **The "lift outside" recommendation in the first blog draft**. Sold as the perf-recovery escape hatch when in fact the imperative for-loop is the recovery; `.map` doesn't help. Honest framing required the investigation outcome.

## Patterns and Root Causes

The session is dominated by **two near-misses prevented by external pressure**.

**Near-miss 1: shipping a redundant type.** Without the user's no-new-type constraint, we'd have shipped `Repeat<S, Element>` as the canonical fix. The bare-Sequence overload is *strictly* better — no new vocabulary, faster, zero code per consumer. The general pattern: when a proposed type's value-add is *shape* (a wrapper deferring evaluation, a tagged struct over an existing protocol, etc.) rather than *novel semantics*, an overload accepting the existing protocol is usually the cleaner answer. Repeat's value-add was "I'm a thing that defers iteration" — but `Sequence` is already that vocabulary. The wrapper was a parallel name for an existing concept.

**Near-miss 2: architectural decisions on a faulty premise.** The "in-body `.map` is 21× slow" framing in v1.0.0 was a research-doc loose end without empirical follow-up. That single sentence in the Residual section drove: (a) the question of whether to ship a `ForEach`/`Repeat` helper type, (b) where it would live (algebra? sequence-primitives? a new package?), (c) whether the institute's `swift-render-primitives` ForEach was the right precedent. None of those questions needed answering — the premise was wrong. The investigation that refuted them took ~1 hour. The discipline gap is mechanical: when a research doc files "separate investigation," the close-out should either cite an extant experiment package or create one immediately. Otherwise the loose end becomes an architectural multiplier on every downstream conversation.

These two patterns rhyme. Both are about **the cost of unchecked assumptions in design conversations** — once: a presumed-necessary new type; once: a presumed-real anomaly. Both required external intervention (user constraint; user pushback) to be re-examined. The internal discipline that would have caught them earlier is the same: **at design-decision points, name what would falsify the premise, and check it cheaply**.

A third pattern, secondary: **the blog draft is a forcing function for honest synthesis**. The draft pulled the recommendation tree into one place; the user's "defeats the purpose" question exposed the muddle; the investigation cleaned it up. Drafting public-facing communication consistently surfaces unresolved framing that internal-facing artifacts (research docs, experiment headers) tolerate.

## Action Items

- [ ] **[skill]** research-process: When a research doc files a "loose end" or "separate investigation," the close-out MUST either (a) cite an extant experiment package, or (b) immediately create one with a minimal hypothesis variant that would refute or confirm the framing in ≤1 hour. Loose ends without empirical follow-up become architectural multipliers in subsequent conversations. Provenance: today's session (the v1.0.0 in-body .map loose end drove ~2 weeks of design conversation that v2.1.0's 1-hour investigation refuted).

- [ ] **[skill]** implementation: When proposing a new type whose value-add is *shape* (wrapper over an existing protocol, parallel name for an existing concept) rather than *novel semantics*, prefer adding an overload that accepts the existing protocol. Specifically: bare-`Sequence` overload subsumes `Repeat<S, Element>` (a wrapper around Source + transform); the overload is shorter, faster, and adds no vocabulary. Promote to an `[IMPL-*]` requirement with the result-builder Repeat-vs-bare-Sequence as the canonical example.

- [ ] **[blog]** BLOG-IDEA-079: Advance the `result-builder-for-loop-performance` draft through `[BLOG-006]` review (collaborative-discussion pass for framing, claim verification per `[BLOG-014]`, closing-material pass) and surface to user for go/no-go on publish. The draft is currently in `Blog/Draft/`; next move is move-to-`Review/` after the verification passes.

## Handoff Triage (per [REFL-009])

Scanned handoff files at workspace roots; triaged in-session-scope per bounded-cleanup-authority:

| File | Disposition | Why |
|------|-------------|-----|
| `/Users/coen/Developer/HANDOFF-result-builder-ecosystem-extensions.md` | Annotated-and-left | Substantive work complete (Round-1, Round-2, perf experiment, lint rule, blog draft) — but supervisor-block entries not systematically verified entry-by-entry per [SUPER-011]. Per [REFL-009]: handoff with unverified ground-rules entries MUST NOT be deleted. Annotated with session-end status section preserving accountability trail. |
| `/Users/coen/Developer/swift-institute/HANDOFF-stdlib-map-specialization-gap.md` | Left-in-place (fresh dispatch) | Written this session as the literature-study branching brief. No work yet. Per [REFL-009] fresh-dispatch rule: leave file. No supervisor block; standard branching investigation template. |
| ~22 other `HANDOFF-*.md` files at `/Users/coen/Developer/` and `/Users/coen/Developer/swift-institute/` (e.g., `HANDOFF-string-correction-cycle.md`, `HANDOFF-platform-audit-cycle-followup.md`, etc.) | Out-of-session-scope | Predate this session. Closure signals not determinable from session context. Per [REFL-009] bounded cleanup authority + [HANDOFF-038] stale-override conservative branch: leave in place. |

No audit findings touched this session (no `/audit` invocation). [REFL-010] does not apply.
