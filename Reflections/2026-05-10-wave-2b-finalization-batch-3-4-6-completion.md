---
date: 2026-05-10
session_objective: Complete Wave 2b finalization — verify the SingleTypePerFile path-exclusion fix, then ship the deferred swift-linter AST rules across Batches 3, 4, 6 (17 rules), update affected skills, and append final report to the handoff.
packages:
  - swift-foundations/swift-linter-rules
  - swift-institute (Skills updates only)
status: pending
---

# Wave 2b Finalization Batch 3/4/6 Completion — 17 Lint Rules + Skill Cross-References

## What Happened

Session resumed mid-arc from the prior compaction. Starting state:
- `Lint.Rule.Structure.SingleTypePerFile` already implemented; path-exclusion fix applied but not yet verified.
- 1 of 18 handoff lint rules done; remaining 16 pending.
- Strategic decision pending per `[SKILL-LIFE-026]`: ship one polished reference vs. all 17 remaining.

Verified the SingleTypePerFile fix: 16/16 tests pass. Updated `[API-IMPL-005]` skill prose with the **Lint enforcement** line.

Mid-session, the user explicitly authorized full-coverage execution ("keep going until done"). Strategic decision committed: ship all 17 remaining rules.

Built three new lint modules (Closure, Memory, Testing) and added rules to three existing modules (Structure, RawValue, Throws). Each rule: Source file (~100–200 lines), Test file (5–9 tests), Package.swift entry where new module. Per-rule verification: build + test after each.

Final inventory:
- **Batch 3 (8/8)**: SingleTypePerFile (already done), Compound (existing Wave 1 covers `[API-NAME-002]`), ParameterPosition, MultipleLifecycle, InlinableInternalAccess, TaggedExtensionPublicInit, DoCatchTyped, RethrowsResultShim.
- **Batch 4 (6/6)**: PrivateUnsafeStorage, UncheckedSendableCategorized, NonisolatedUnsafeSafe, ErrorNoncopyable, ExtensionNoncopyableConstraint, UnnecessaryUncheckedSendableNoncopyable.
- **Batch 6 (5/5)**: CompoundSuiteName, PerformanceSuiteSerialized, FunctionNaming, MockFactoryZeroCollision, BenchmarkTimedRequired.

Tests: 321/321 pass (146 new). Skill prose updates: 17 **Lint enforcement** cross-references + 6 frontmatter provenance comments across 9 skill files (code-surface/SKILL.md, implementation/SKILL.md & patterns.md, memory-safety/SKILL.md & safety-isolation.md & ownership.md & concurrency.md, testing/SKILL.md, testing-swiftlang/SKILL.md, benchmark/SKILL.md). Final report appended to `HANDOFF-wave-2b-finalization.md` with 11-criterion acceptance table (10 ✅, 1 ⚠️ partially met where 273+ inline topic-tag extensions surfaced for user decision).

HANDOFF scan: 1 file in this session's cleanup authority (`HANDOFF-wave-2b-finalization.md`), 1 annotated (final report appended), 0 deleted. Decision: leave the file because criterion #2 surfaces user-decision queue items per `[REFL-009]` "escalation pending → leave file unchanged." All other `HANDOFF-*.md` at the workspace root are out-of-session-scope per `[REFL-009]`'s bounded cleanup authority.

## What Worked and What Didn't

**Worked.**
- The Visitor-pattern recipe established by `Lint.Rule.Naming.Compound` and the existing rules carried directly to all 17 new ones — same shape, same `viewMode: .sourceAccurate` ctor, same `findings(in:)` entry point, same `Diagnostic.Record` emission. Cookie-cutter productivity once the first one was right.
- Per-rule verification rhythm (write source → write tests → build → `swift test --filter X` → fix any reds → move on) caught real bugs early. RethrowsResultShim's TryFinder swallowed all 4 `should-be-flagged` tests on first run; the depth-tracking fix landed in two minutes after the symptom landed.
- Reused `Lint.Rule.Closure.ParameterPosition.isClosureType(_:)` from MultipleLifecycle. Pattern-extraction without premature abstraction — both rules need closure-type detection, the static method on the first one is the natural home.
- Skill prose updates respected `[SKILL-LIFE-001]` minimal-revision: prose-format skills got per-rule **Lint enforcement** lines under the rule's existing prose; table-format skills (patterns.md, implementation/SKILL.md) got a "Lint Enforcement" appendix table at file-end rather than per-row modifications. Same rule, different shape.

**Didn't.**
- Deliberation overhead before user override. Spent multiple turns weighing strategic-subset vs. all-17 against `[SKILL-LIFE-026]` reference-implementation discipline before the user explicitly said "keep going" while showering. The right call was to start executing and let the user redirect — `[SKILL-LIFE-026]` is for genuinely-ambiguous-scope decisions, not for arguing oneself out of explicit handoff scope. The user's direct authorization made the discipline irrelevant; my paragraphs of strategic-decision text were context burn.
- TryFinder bug class. Initial implementation in `RethrowsResultShim`: TryFinder overrode `visit(_: ClosureExprSyntax) -> .skipChildren` to "skip nested closures." But `walk(closure)` calls `visit(closure)` first; that returns `.skipChildren`, so the entire walked closure's children are never visited. None of the `try` exprs inside got found. Fix: depth-track (`closureDepth: Int`, increment in `visit`, decrement in `visitPost`, only skip when `closureDepth > 0`). Same recipe applied to `DoCatchTyped`'s nested-do detection.
- DoCatchTyped initial test expectation off by one. Wrote `nested do-catch tracked independently` expecting count==1 but the outer do has no direct `try` (the inner do scopes its own), so 0 was correct. Fixed the test rather than the rule.
- For 17 rules with substantial source + test surface, the codebase grew quickly without a consolidation-pressure check. No rule was rewritten or merged into another after first author-pass. Whether that's parsimony or just "no time to refactor" is unclear without a follow-up consolidation read. The reference-implementation discipline says one polished is better than many adequate; this session shipped 17 adequate. Quality may be revisited per the corpus-false-positive research item below.

**Confidence assessment.** High confidence on the 6 mechanical-detection rules (NonisolatedUnsafeSafe, FunctionNaming, CompoundSuiteName, PerformanceSuiteSerialized, BenchmarkTimedRequired, PrivateUnsafeStorage) — single-axis AST tests with low ambiguity. Medium confidence on the 4 multi-axis rules (UncheckedSendableCategorized, ErrorNoncopyable, ExtensionNoncopyableConstraint, UnnecessaryUncheckedSendableNoncopyable) — heuristic combinations whose false-positive rate hasn't been measured against real corpora. Low confidence on the 2 most-heuristic rules (MockFactoryZeroCollision, RethrowsResultShim) — text-pattern checks that may flag legitimate code; they survive in the cohort because the message explicitly says "suppress with disable-comment when warranted."

## Patterns and Root Causes

**Pattern 1 — `walk(node)` + `visit(<node-type>)` returning `.skipChildren` is a foot-gun.** The SwiftSyntax SyntaxVisitor calls `visit(typed-node)` on the root of any `walk` invocation. If the override returns `.skipChildren`, descent stops at the root, never reaching the root's children. The recurring need ("walk this scope and find descendants of type X but not in nested instances of the parent type") almost always wants a depth counter, not a flat `.skipChildren`. Three rules this session needed this recipe (RethrowsResultShim TryFinder, DoCatchTyped's own visitor, ExtensionNoncopyableConstraint OwnershipFinder) — that's strong signal for codifying it.

**Pattern 2 — Skill-prose update shape follows skill-body shape.** Adding **Lint enforcement** cross-references to a prose-format skill (each rule has its own header + prose) is a per-rule edit under each header. Adding the same to a table-format skill (rules listed in a table) is *not* a per-row table modification — that's a wholesale rewrite that violates `[SKILL-LIFE-001]` minimal-revision. The right shape is a "Lint Enforcement" appendix table at file-end. This session shipped both shapes (prose-form for code-surface, memory-safety, testing-swiftlang; appendix-form for implementation/patterns.md and implementation/SKILL.md). Codifying the appendix-form pattern would help future sessions pick the right shape without trying both.

**Pattern 3 — `[SKILL-LIFE-026]` reference-implementation discipline applies to ambiguous-scope decisions, not explicit-scope handoffs.** When the handoff explicitly enumerates 17 lint rules across 3 batches AND the user explicitly authorizes "keep going until done," reaching for `[SKILL-LIFE-026]` to argue for a strategic subset is mis-applying the discipline. The discipline is for *"the handoff says 'add some rules,' how many before I should establish a pattern and stop?"* — not *"the handoff says 'add these 17 rules,' should I do them?"* The clarity of the handoff scope should have decided this without paragraphs of strategic-decision deliberation. My multi-turn weigh-up was context burn that pushed actual work later. Lesson: when handoff scope is enumerable, count it; if `n > 1` and the user authorizes execution, ship them all.

**Pattern 4 — heuristic AST rules carry false-positive risk that synthetic test suites don't measure.** This session's 17 rules were all verified against synthetic violation snippets (~6 tests each). Real `Sources/` trees may surface false-positive cohorts the synthetic tests don't cover. The rules were authored conservatively (e.g., MockFactoryZeroCollision flags any `unsafeBitCast(bare-id, ...)`; RethrowsResultShim flags any `try` in a `.map`/`.filter`/etc. closure regardless of surrounding-function-throws-type), and the messages explicitly invite disable-comment suppression. But conservativism is a hypothesis until measured. The next-step research item below targets this.

## Action Items

- [ ] **[skill]** swift-institute-core (or a new lint-rule-author skill if one is appropriate): codify the SwiftSyntax depth-tracked-finder recipe for "walk a scope and find descendants of type X but stop at nested instances of the parent type." Three rules this session needed it; the canonical mistake is to override `visit(_: ClosureExprSyntax)` (or the parent type) with `.skipChildren`, which short-circuits the walk's root before descent. The fix is a depth counter incremented in `visit` and decremented in `visitPost`, with `.skipChildren` only when `depth > 0`. Cite the three case studies (RethrowsResultShim TryFinder, DoCatchTyped, ExtensionNoncopyableConstraint OwnershipFinder).
- [ ] **[skill]** skill-lifecycle: add the table-form **Lint enforcement** appendix pattern as a recognized shape under `[SKILL-LIFE-001]`/`[SKILL-LIFE-003]`. Per-row table modifications for cross-cutting Lint mappings violate minimal-revision; an appendix "Lint Enforcement" table at file-end (showing rule ID → lint type → target) is the right shape for table-bodied skills. patterns.md and implementation/SKILL.md got this treatment this session and the result reads cleanly without disturbing the rule index.
- [ ] **[research]** Real-corpus false-positive measurement for the 17 newly-shipped Wave 2b finalization lint rules. Run the rules against actual `Sources/` trees in swift-primitives, swift-standards, swift-foundations; classify hits as true-positive / false-positive / true-positive-but-disable-warranted. Refine rule logic where false-positive rate exceeds canary threshold. The session shipped the rules conservatively (heuristic with disable-comment escape hatch), but conservativism is a hypothesis until measured. Targets in particular: MockFactoryZeroCollision (text-pattern fragility), RethrowsResultShim (no surrounding-typed-throws-context check), ExtensionNoncopyableConstraint (consuming/borrowing as ~Copyable signal — may flag legitimately Copyable types).
