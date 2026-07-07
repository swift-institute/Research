---
date: 2026-07-07
session_objective: Phase-0 rule adjudication for the fleet-wide lint remediation arc — freeze the three-engine ruleset, ratify the L2 standards-tier and rule-placement amendments, dispatch the overnight Opus execution arc
packages:
  - swift-standards-linter-rules
  - swift-institute-linter-rules
  - swift-primitives-linter-rules
  - swift-ieee-754
status: pending
---

# Phase-0 Ruleset Freeze, Standards Tier (A4), and Placement Audit (A5)

## What Happened

Fable session booted via `HANDOFF-fable-phase0-rule-review.md` to adjudicate the lint fleet's 47,136 findings before any remediation. Judged the top 18 rules from first principles: read each canonical skill statement, the AST rule's implementation (message, exemption sets, visitor heuristics — found in `swift-foundations/swift-institute-linter-rules`, not the packs first guessed), and live firing sites in top-emitter repos. Verdict: all 18 STABLE; one FP class (Codable witness signatures vs the §C3 `throwsConformanceForcedAllowlist`, which held only TestScoping). Resolved TEST-005 vs SWIFT-TEST-005 as distinct rules (SuiteCategories vs FunctionNaming). Output: `Workspace/handoffs/lint-arc-artifacts/endgame/PHASE0-frozen-ruleset.md` (Tables A/B/C).

The principal then made two calls that became amendments. **A4**: L2 Standards optimizes for 1:1 spec encodings — spec-token transliterations (CSSOM's own `animationName`/`timingFunction`, IEEE 754's camelCase operation names) are [API-NAME-003] spec-mirroring, so [API-NAME-001]/[API-NAME-002] don't apply at L2; mechanism = new `swift-standards-linter-rules` pack with subtractive `Lint.Rule.Bundle.standards` (institute − 2 naming rules), halving the naming remediation surface (13,341 → 6,724). **A5**: with tiers first-class, audited the primitives pack's 9 rules — 6 brand-consumer rules (RawValue + Cardinal modules) moved to institute tier (brands defined at L1, consumed at L2/L3); 3 Tower rules stay.

Implementation went to subagents (opus for code, sonnet for skills): standards pack built + tested + published; skills amended ([LINT-BUNDLE-001], code-surface exceptions, lint-rule-promotion placement); A5 modules relocated (1030 + 29 tests green; consumer updates verified no-op across 372 Lint.swift files). Pilot swift-ieee-754: 1,844 → 1,023 exact (two naming rules zeroed, 16 others unchanged), then 84 → 90 rules / 1,025 after A5 (+2 real `count minus one` L2 findings) — local and CI agree, and CI proved private-pack resolution works. Session closed with `HANDOFF-opus-remediation-arc.md` + a perfection pass (fixed a "Read ONLY" boot-prompt defect; pre-enumerated wave-0: 107 L2 repos, 106 to flip; `.trash` retirement-suffix convention applied to 4 stray files).

**HANDOFF scan**: 60 live files in `Workspace/handoffs/` (guard red at cap 40 — per the 2026-07-06 ruling this is red-by-documented-design; drain happens per-arc at close). 2 files in this session's authority: `HANDOFF-fable-phase0-rule-review.md` (consumed → retired to `.trash/` with `-retired-20260707` suffix, committed) and `HANDOFF-opus-remediation-arc.md` (fresh dispatch — left as the successor's boot document). Remaining 58 out-of-session-scope (the lint-cluster predecessors drain at the remediation arc's close). Memory guard: green (zero topic files; inbox within cadence; two new dated entries added for other-arc follow-ups).

## What Worked and What Didn't

**Worked**: Judgment-only Phase-0 on a tight budget — sampling 2 emitters per rule plus reading the rule *implementations* (not just skill text) is what surfaced the real story: the rules already carry extensive ratified precision machinery, so most "FP pressure" had designed outlets. The principal's two challenges both became amendments — the co-architect loop functioning as intended; notably the CSSOM evidence *reversed* my initial "hyphens are nesting seams" reading for members. Subagent split held the token discipline (Fable adjudicates, opus/sonnet execute); CI served as independent verification of subagent claims (90 rules · 1,025 confirmed the A5 pushes before the agent even reported). The pilot-before-fleet pattern caught the SwiftPM path-dep constraint cheaply.

**Didn't**: The boot prompt I first wrote said "Read ONLY the handoff" while the mission required the frozen spec — caught only in the principal-prompted perfection pass; that defect would have degraded the overnight arc. Disk-name repo resolution nearly sampled out-of-scope `coenttb/*` clones (same-named heritage upstreams of in-scope swift-foundations repos). Shell footguns cost turns: zsh word-splitting on spaced paths, BSD grep lacking `\|`. The mover agent twice stopped to "wait" on its own background monitor instead of reporting — needed two nudges; long-running subagents should be briefed to report at phase boundaries. Evidence caveat carried forward honestly: Table A rows 1/5's L1/L3 evidence base was L2-heavy; wave-start spot-check flagged in the frozen ruleset.

## Patterns and Root Causes

**Placement-blindness**: a rule that polices *consumer* behavior, placed in the *definer's* tier, never sees the surface it exists to protect. The adjudication test — author-discipline vs consumer-discipline — was decisive for all 9 rules, and the pack's module boundaries (Tower vs RawValue/Cardinal) already encoded the answer. This generalizes: whenever enforcement scope is tier-gated, ask whose behavior the rule polices, not where its vocabulary is defined. The pilot's +2 `count minus one` findings were immediate proof of what placement-blindness had been hiding.

**"Who chose the name?" resolves spec-mirroring vs house-style**: A4's core move was recognizing that the spec *community's own programmatic convention* (CSSOM camelCase, IEEE 754 operation names) is part of the spec surface. 1:1 fidelity therefore outranks house ergonomics at L2 — and the right mechanism was structural (a subtractive sibling bundle) rather than per-package exclusions or a parameterized vocabulary, accepting a precision trade-off with a named future complement (spec-citation rule). Subtractive bundles deliberately break the additive-composition invariant; documenting "sibling, not chain" in [LINT-BUNDLE-001] pre-empts a whole confusion class.

**Boot prompts must whitelist the spec chain**: "Read ONLY X" is wrong whenever X cites a spec the mission depends on; the correct shape is "Read FIRST X, then what it directs." Same failure class as [HANDOFF-037] (internal contradictions as handoff defects) — the contradiction was between the prompt and the handoff's own Goal section.

## Action Items

- [ ] **[skill]** handoff: [HANDOFF-011] — add the boot-prompt shape rule: resumption prompts MUST use "Read FIRST + let the handoff direct further reading," never "Read ONLY {handoff}" when the handoff cites dependent specs (origin: this session's perfection-pass catch of a Goal-vs-prompt contradiction).
- [ ] **[skill]** lint-rule-promotion: Phase 2 placement — codify the A5 adjudication test: a rule stays in a lower tier only if it polices that tier's *author* discipline; rules policing *consumer* behavior at a vocabulary boundary belong at the broadest consuming tier (precedents: PRIM-FOUND-001, A5's six movers).
- [ ] **[research]** Spec-clause-citation rule for L2 public surface (first standards-pack resident): design the doc-comment spec-reference convention and its AST check — it is A4's auditability complement (cited compound name = transliteration; uncited = invented) and the enforcement side of README/DOC spec-fidelity claims.
