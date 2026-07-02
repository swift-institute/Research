# Ecosystem Meta-Setup Target State

<!--
---
version: 1.2.0
last_updated: 2026-07-02
status: RECOMMENDATION
research_tier: 2
scope: ecosystem-wide
changelog:
  - 1.2.0 (2026-07-02): R4 spike residual resolved with measured lint timings; per-push per-package CI lint rejected, M-phase re-scoped to local sweep + burndown report; release-binary path blocked on Swift 6.3.3 FunctionSignatureOpts SIL crash (dossier handoff filed).
  - 1.1.0 (2026-07-02): §D3 SUPERSEDED handling corrected — [META-005] (rewritten 2026-04-24) FORBIDS _archived/ relocation; docs stay in place, filtered via _index.json. v1.0.0 carried a stale cross-reference from the research-process skill's [RES-002] subdirectory table (which still lists _archived/ "per [META-005]"); that table needs a skill fix. Caught by the 2026-07-02 corpus-meta-analysis sweep — an instance of this doc's own [RES-013a] discipline.
---
-->

## Context

Phase 2 of a three-phase program directed 2026-07-02: (1) inventory the ecosystem meta-setup, (2) re-derive the ideal setup from first principles, (3) realign. Phase 1 shipped as `Audits/REPORT-meta-setup-inventory-2026-07-02.md` (all inventory figures below: Verified 2026-07-02 against that sweep, which read live state).

The principal's stated irritants: the `.handoffs/` backlog (247 live files) and ever-increasing skill size (~3.0 MB corpus, top 8 skills ≥ 130 KB), plus the known-but-unmeasured lint-greening gap (91 rules, 304 wired consumers, 0 CI enforcement).

**Trigger**: principal directive. **Constraints**: the four harness bets ([BET-HOOK], [BET-EVAL], [BET-COMPACT], [BET-REWRITE]) are standing decisions; enforcement may live only at the four sanctioned layers (lint/validators, audit skill, supervisor blocks, skill-rule-as-spec), with the single Stop→`/reflect-session` cadence exception. **Tier**: 2 per [RES-020] — ecosystem-wide but reversible process design, no long-lived semantic API contract.

## Question

What is the structurally correct steady-state for the ecosystem's meta-layer — skills, handoffs, documentation corpora, CI meta-automation, and lint enforcement — such that it stays lean and lifecycle-compliant *without recurring manual heroics*?

## The empirical law this doc is built on

The Phase 1 inventory shows one law holding across all five dimensions [Verified: 2026-07-02]:

| Invariant class | Compliance |
|---|---|
| Mechanically validated (33 CI validators, reusable-chain shape, metadata.yaml) | ~100% |
| Prose-only MUST with a cadence hook (reflection triage) | ~94% |
| Prose-only MUST with an unwired backstop script (handoff retirement [HANDOFF-008a]) | ~14% |
| Prose-only cadence with no hook (corpus-meta-analysis monthly) | 0 for 7.5 weeks |

**A lifecycle rule is real to the extent it is mechanically checked or cadence-hooked. Prose alone decays.** This replicates the industry finding (Sadowski et al., Tricorder/ICSE 2015; policy-as-code) and the ecosystem's own [BET-HOOK] framing — enforcement belongs at the lint/CI layer. The realignment therefore adds *no new prose-only MUSTs*: every rule proposed below ships with its mechanical check or names the cadence that runs it.

## Prior art

### Internal ([RES-019]; governs unless explicitly overridden)

- **`skill-shape-and-growth-evaluation.md` (v1.1.0, DECISION)** [Verified: 2026-07-02 — status + thresholds grepped at source]: single-file-first; multi-file navigation-hub permitted at ≥ 40 rules with ≥ 3 semantic clusters ([SKILL-CREATE-005a]); platform's split was DEFERred with an explicit revisit trigger "if it exceeds ~1800 lines". Platform is now 2,325 lines [Verified: 2026-07-02] — **the DECISION's own revisit condition has fired.** This doc does not contradict the DECISION; it executes its revisit clause and adds the missing lever (eviction, §D1).
- **`handoff-lifecycle-and-retention.md` (v1.0.0, RECOMMENDATION)** — Option G (staleness sweep + dispatch-side retirement) was ratified into the handoff skill as [HANDOFF-038]/[HANDOFF-039] [Verified: 2026-07-02 — present in SKILL.md]. Compliance nonetheless collapsed (~14%). The diagnosis below (§D2): the rules lack a *mechanical counter*; `Scripts/check-handoffs.sh` exists [Verified: 2026-07-02] but nothing runs it.
- **`agent-harness-engineering-comparative-analysis.md` (v1.5.0, RECOMMENDATION; [BET-*] source)** — Q3: enforcement at four layers, not hooks; Q4: no eval-driven auto-mutation, error-analysis-only on the reflections corpus. All proposals below cohere with these bets.
- **`lint-rule-promotion` skill [PROMOTE-009]** [Verified: 2026-07-02 — grepped at source]: rules ship at `.warning`; escalation to `.error` is a separate amendment "after one cohort cycle clean". The greening plan (§D5) is the corpus-scale generalization of this per-rule discipline.
- **`corpus-drift-taxonomy.md` (v0.1.0, IN_PROGRESS)** — 12 drift classes with detection mechanisms; built on, not ratified.
- **Leanness program (P0–P4, 2026-05-31)** — memory-sourced only; the phase table is not recoverable from any on-disk artifact (Carried forward, unverified). Its direction ("P3 mechanical enforcement is the real lever") is independently re-derived here from the empirical law above, so nothing below depends on the unverified phase table.

### External ([RES-021]; fetched and quote-verified 2026-07-02 unless marked)

1. **Anthropic skill authoring guidance**: "Keep SKILL.md body under 500 lines"; description ≤ 1024 chars; SKILL.md as "a table of contents" with one-level-deep reference files loaded on demand; "context … must be treated as a finite resource"; "context rot" degrades recall as tokens grow. ([platform.claude.com skill best-practices]; [anthropic.com effective-context-engineering].) *Contextualization*: top institute skills exceed the vendor ceiling ~10–15×; the port is normative-core SKILL.md + on-demand companions — cost is a one-time restructuring and a two-hop lookup for rationale.
2. **ADR lifecycle (Nygard 2011, primary)**: superseded records are *kept in place*, marked, and cross-linked to their replacement; the index stays current. *Contextualization*: the 85 SUPERSEDED research docs are conventional, not defects; the defect is the 443/596 index lag and absent freshness automation.
3. **WIP control (Anderson, Kanban 2010; Reinertsen 2009 — book-level citations)**: unbounded in-progress artifact piles are queue waste; the remedy is a hard WIP cap plus cleanup-inside-definition-of-done. *Contextualization*: a counted cap on `.handoffs/` enforced by `check-handoffs.sh`, with retirement a close-out step of every arc.
4. **Static-analysis-at-scale (Tricorder, ICSE 2015, quote-verified)**: < 10% effective false positives per check or the check is disabled; results delivered inside the core workflow; two-tier severity (blocking correctness vs advisory style). **Legacy-greening playbook** (ESLint bulk-suppressions, official; Betterer; SonarQube Clean-as-You-Code; clippy category tiers): snapshot existing violations into a checked-in baseline → rule becomes error-on-new-code immediately → baseline shrinks monotonically (prune-only) → per-rule global flip at zero. *Contextualization*: §D5; requires a baseline-file feature swift-linter does not yet have [Verified: 2026-07-02 — engine has inline `// swift-linter:disable` suppression (`Lint.Suppression`) but no checked-in baseline mechanism].
5. **Goodhart (Strathern 1997)**: "When a measure becomes a target, it ceases to be a good measure." *Contextualization*: ratchet counts must be prune-only with full re-report on regression, and suppression-comment gaming must be auditable (REASON prose is already scaffolded in `Lint.Suppression`).

## Analysis — first-principles derivation

Three axioms, all already latent in ratified ecosystem positions:

- **A1 (context is the scarce resource)**: this ecosystem is operated by LLM agents; every always-loaded byte taxes every session. The canonical-sources table (Skills=WHAT, Research=WHY, docc=HOW) is therefore not just an organizational nicety — it is the context-budget allocator. Rationale/changelog mass inside skills is WHY-tier content billed to the WHAT-tier budget.
- **A2 (prose decays, mechanics hold)**: the empirical law above.
- **A3 (bets constrain the fix)**: no hooks, no auto-mutation, filesystem as state machine. So the enforcement vocabulary is exactly: CI validators (for git-tracked corpora), the cadenced reflect-session step (for the untracked `.handoffs/`), the audit skill, and lint.

From these, the target state per dimension. Each is a single recommendation, not an option menu; alternatives considered are noted inline with rejection reasons.

### D1 — Skills: normative-core with evicted rationale, budget-linted

**Target shape**: a SKILL.md contains frontmatter, the rule statements (`[PREFIX-NNN]` + Statement + minimal correct/incorrect example + cross-refs), and gotchas. Three content classes are **evicted**:

1. **Changelog/provenance lines** (235 dated entries corpus-wide) → git history carries them already; where the narrative matters, it moves to a Research doc. Zero information loss: the skill repo is git-tracked.
2. **Multi-paragraph `**Rationale**` blocks** (871 corpus-wide) → compressed to one sentence in the skill + `Rationale: Research/<doc>.md` link for the full argument. New rationale of substance is *authored* in Research/ and cited, never inlined.
3. **Redundant worked examples** → one correct/incorrect pair per rule stays; long incident narratives move to the provenance reflection (already the durable record per [HANDOFF-008a]).

**Budget**: adopt the vendor-aligned ceiling as a lintable number — SKILL.md body ≤ 1,000 lines (with [SKILL-CREATE-005a] navigation-hub restructuring at ≥ 40 rules, per the existing DECISION), companion files one level deep. The 1,000 figure honors the internal DECISION's "~1000 lines" threshold rather than Anthropic's 500 (institute skills carry requirement-ID registries that vendor skills don't); packages already past the navigation-hub bar split rather than truncate.

**Mechanical check**: extend the existing `lint-skill-descriptions.yml` muscle with a `lint-skill-size` validator in the Skills repo CI: fails on body > 1,000 lines, on dated changelog lines in skill bodies, and on `last_reviewed` older than a declared cadence. Also brings the 9 Engagement skills into review-tracking.

**Expected effect** (estimate, not a target-metric per [BET-EVAL]): the eight ≥ 130 KB skills carry a majority of non-normative mass; eviction should roughly halve the corpus without deleting a single rule.

*Rejected alternative*: byte-budget-by-deletion of rules — contradicts the corpus's total-taxonomy character ([RES-020a] analog); rules are the WHAT and stay.

### D2 — Handoffs: WIP-capped scratch space with defined artifact classes

**Diagnosis**: two independent failures. (a) Retirement rules exist but nothing counts; (b) the directory accreted artifact classes the skill never defined (76 `REPORT-`, 20 `GOAL-`, ~35 others) because program-scale orchestration needed durable-ish records and had nowhere sanctioned to put them.

**Target shape**:
- `.handoffs/` is a **scratch space with a hard WIP cap** (proposed: 40 live .md files — headroom above the ~25–60 genuinely-open estimate, small enough to force triage). `check-handoffs.sh` is extended to count live files, flag terminal-marked residents ("consumed/landed/✅/STANDDOWN/terminal"), flag root-level strays, and **fail loudly over cap**. It runs as a mandatory step of `/reflect-session` (the sanctioned cadence layer; [BET-HOOK]-compatible) and of `/quick-commit-and-push-all`.
- **Artifact classes get defined homes**: `HANDOFF-`/`GOAL-`/`RELAY-`/`RULING-` are *scaffolding* → retire on consumption (existing [HANDOFF-008a]). `REPORT-`/`CHARTER-` that close an arc are *records* → they belong in `Audits/` (git-tracked, already hosts REPORT-*), moved at arc close as part of the close-out definition-of-done. The handoff skill's naming table is amended to say exactly this, replacing the current undefined-prefix drift.
- The `.trash/` TTL sweep stays as-is (it works when invoked).

*Rejected alternatives*: git-tracking `.handoffs/` (contradicts its ephemeral-by-design README and would bloat a repo with scaffolding); a Stop-hook enforcement (violates [BET-HOOK]; also already rejected by `handoff-lifecycle-and-retention.md` Option A).

### D3 — Documentation corpora: generated indexes, archived supersession, restored cadence

- **Index drift**: `_index.json` regeneration becomes scripted-and-validated — a `validate-research-index` check (same validator muscle) fails when docs-on-disk ≠ index entries. An index that can drift silently is not an index.
- **SUPERSEDED docs**: keep **in place** per [META-005] (rewritten 2026-04-24: relocation to `_archived/` is FORBIDDEN — with `_index.json` as the canonical catalog, status is a first-class filter dimension and physical relocation would only add path churn). The realignment work is `supersededBy` backfill in the index, not moves. *(v1.1.0 correction; v1.0.0 recommended relocation off a stale [RES-002] cross-reference — the research-process skill's subdirectory table still cites the pre-rewrite [META-005] and needs a fix.)*
- **Reflections**: drain the 25 pending (oldest 2026-04-23) via `reflections-processing`; the cadence hook already performs — no structural change.
- **corpus-meta-analysis**: the monthly sweep gets a visible cadence anchor (a dated entry the validator can check, e.g. a `META-run: YYYY-MM-DD` marker file or Audits/ record freshness check) instead of relying on memory.
- **Blog/deferred branches**: no structural defect found; excluded from realignment scope.

### D4 — CI meta-automation: extend the proven pattern to the meta-corpus

CI is the model, not a patient. The only additions are the validators named in D1–D3 (skill-size, research-index-drift, meta-analysis-freshness) plus the lint wiring in D5 — all inside the existing three-tier/validator architecture. No new enforcement primitive is introduced ([BET-HOOK] holds).

### D5 — Lint greening: measure → baseline → ratchet → flip, per rule

The γ-flip as currently framed (advisory → gating, corpus-wide) is a big-bang; prior art is unanimous that the staged path dominates:

1. **Measure now (M)**: wire the existing reusable `lint.yml` into the org layer wrappers as a non-blocking job for all 304 consumers. Output: per-package, per-rule violation counts (SARIF already supported). This converts "not green, unmeasured" into a burndown surface in one step. No package is blocked.
2. **Tier the 91 rules (T)**: clippy/Tricorder-style — correctness-grade rules eligible for `.error`; style/discipline-grade stay `.warning`. This is [PROMOTE-009]'s existing vocabulary applied corpus-wide. The `excluding(rules:)` signal (RawValue-family rules excluded by brand-owner packages) feeds the existing three-class triage — some exclusions become codified [RULE-EXEMPT-*] shapes rather than per-package stopgaps.
3. **Baseline (B)**: add a checked-in baseline mechanism to swift-linter (feature gap, verified): a generated per-package suppression snapshot, **prune-only** (regenerating may only shrink it; regressions re-report in full — the ESLint bulk-suppressions semantics). Inline `// swift-linter:disable` + REASON stays for deliberate, reviewed exemptions; the baseline covers legacy mass.
4. **Ratchet + flip (R)**: CI fails on new violations (error-on-new-code from day one of B); per rule × per package, when the baseline entry hits zero the rule flips to `.error` there ([PROMOTE-009]'s escalation clause, executed at scale). Corpus green = all baselines empty; no stop-the-world cleanup ever scheduled.

Goodhart guards: counts are burndown *surfaces*, not targets with deadlines; baseline files are prune-only and diff-reviewed; a per-rule "not useful" channel (the existing lint-triage three-class discipline) with a Tricorder-style effective-FP disable threshold protects rule quality.

## Comparison — why this composition

| Criterion | Status quo | Big-bang cleanup sprints | **Recommended: mechanize lifecycles + evict + ratchet** |
|---|---|---|---|
| Honors [BET-*] | yes | yes | yes |
| Steady-state without heroics | no (proven) | no (decays again) | yes — every rule has a counter or cadence |
| Context-budget recovery | none | partial | ~50% of skill bytes, browsing-clean Research/ |
| Lint path to green | indefinite | blocking freeze | incremental, error-on-new-code immediately |
| One-time cost | — | very high | moderate (eviction pass, drain, 3 validators, 1 linter feature) |

## Outcome

**Status**: RECOMMENDATION (Phase 3 execution requires principal ratification).

The ideal meta-setup is the current architecture — harness-as-corpus, filesystem-as-state-machine, three-tier CI — with its **lifecycle rules moved from prose to counters**, its **WHY-mass moved from skills to Research/**, and its **lint corpus moved from unmeasured-advisory to baseline-ratcheted**. Nothing structural is replaced; the realignment is: evict, drain, wire, ratchet.

**Phase 3 arc plan** (ordered; each independently shippable and gated):

| Arc | Work | Gate |
|---|---|---|
| R1 Handoff drain | One-time triage of 247 files (retire consumed, move terminal REPORTs to Audits/, keep open); relocate 7 root strays; extend + wire `check-handoffs.sh`; amend handoff skill naming table | principal go; skill amendment via skill-lifecycle |
| R2 Skill eviction | Top-8 skills first: evict changelog/rationale/example mass per D1 (each eviction lands the Research/ destination doc in the same wave); add `lint-skill-size` validator; bring Engagement skills into review metadata | principal go; per-skill review |
| R3 Corpus hygiene | Regenerate + validate `_index.json`; backfill `supersededBy` on SUPERSEDED entries (in place per [META-005]); drain 25 reflections; run overdue corpus-meta-analysis | principal go |
| R4 Lint M+T | Wire advisory lint job into org wrappers; tier the 91 rules; publish first burndown | principal go (touches 3 org wrapper workflows) |
| R5 Lint B+R | Build baseline feature in swift-linter; generate baselines; enable error-on-new-code; per-rule flips thereafter | R4 data in hand; feature review |

R1 and R3 are pure debt-drain (no design risk); R2 touches canonical skills (per-skill review discipline applies); R4/R5 are the lint program proper. Estimated end-state: `.handoffs/` ≤ 40 live files enforced, skills corpus ≈ 1.5 MB and capped, indexes validator-fresh, every package measurably burning toward green with new code gated today.

## Residuals ([RES-027])

- **Premise (verified)**: swift-linter lacks a baseline-file mechanism — confirmed by source inspection 2026-07-02 (`Lint.Suppression` is inline-comment only). R5 builds it; no further spike needed before R4, which uses counts only.
- **Premise — RESOLVED by spike (2026-07-02, v1.2.0)**: measured on Apple Swift 6.3.3 / arm64, debug binary (the `swift run` path lint.yml uses): linter build 114 s; lint wall-clock 131 s (20-file package, first-run overhead), 43 s (37 files), 351 s (149 files); violation output magnitude ~70 → ~2,080 lines across those three. Two consequences: (a) **per-push per-package lint jobs are rejected** — linter-build-per-job plus minutes-per-run across 304 packages is infeasible on free-tier CI; the M-phase becomes a **local sweep script emitting a burndown report to Audits/** (BET-compatible, zero CI cost), with an optional weekly-cron sharded sweep on public repos later; (b) **release binaries are blocked** by a Swift 6.3.3 SIL crash (`FunctionSignatureOpts`, `!type.hasTypeParameter()`, RFC_3986 typed-throws generic — see `.handoffs/HANDOFF-swift-linter-release-sil-crash.md`), so prebuilt-binary distribution waits on that dossier. The wall≫user gap (351 s wall / 51 s user on the large run) suggests per-run overhead worth linter-side investigation.
- **Direction (no follow-up required)**: whether evicted-rationale Research docs should be one-per-skill or one-per-rule-family; decide during R2's first skill.
- **Direction**: whether `GOAL-`/`RELAY-` scaffolding deserves its own skill-defined template or folds into handoff forms; decide during R1.

## References

- `Audits/REPORT-meta-setup-inventory-2026-07-02.md` (Phase 1 inventory — all internal state figures)
- `Research/skill-shape-and-growth-evaluation.md` v1.1.0 (DECISION); `Research/handoff-lifecycle-and-retention.md` v1.0.0; `Research/agent-harness-engineering-comparative-analysis.md` v1.5.0; `Research/corpus-drift-taxonomy.md` v0.1.0; `Research/agent-harness-engineering-state-of-the-art.md` v1.0.0
- Anthropic, *Skill authoring best practices* — https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices (quote-verified 2026-07-02)
- Anthropic, *Effective context engineering for AI agents* — https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents (quote-verified 2026-07-02)
- Anthropic, *Lessons from building Claude Code: how we use skills* — https://claude.com/blog/lessons-from-building-claude-code-how-we-use-skills (quote-verified 2026-07-02)
- M. Nygard, *Documenting Architecture Decisions* (2011) — https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions (quote-verified 2026-07-02)
- C. Sadowski et al., *Tricorder: Building a Program Analysis Ecosystem*, ICSE 2015 — https://research.google.com/pubs/archive/43322.pdf; and SWE-book ch. 20 — https://abseil.io/resources/swe-book/html/ch20.html (quote-verified 2026-07-02)
- ESLint, *Introducing bulk suppressions* (2025) — https://eslint.org/blog/2025/04/introducing-bulk-suppressions/ (quote-verified 2026-07-02)
- SonarSource, *Clean as You Code* — https://docs.sonarsource.com/sonarqube-server/10.6/user-guide/clean-as-you-code (search-level verification)
- Rust Clippy lint categories — https://doc.rust-lang.org/clippy/index.html (quote-verified 2026-07-02)
- D. Anderson, *Kanban* (2010); D. Reinertsen, *The Principles of Product Development Flow* (2009) (book-level citations)
- M. Strathern, "'Improving ratings': audit in the British University system", *European Review* 5(3), 1997 (Goodhart phrasing)
