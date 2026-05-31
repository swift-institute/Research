---
date: 2026-05-11
session_objective: Final leaf in the per-leaf-package rule-source triage workflow — surface and disposition all linter findings on swift-standard-library-extensions (the 620-finding stress test) so the rule corpus reaches publishable v1 quality.
packages:
  - swift-standard-library-extensions
  - swift-linter-rules
  - swift-institute-linter-rules
status: processed
processed_date: 2026-05-31
triage_outcomes:
  - type: no_action
    description: "Action items are arc-specific process-discipline tweaks (handoff/supervise/issue-investigation/reflect-session/lint-rule-promotion) already substantially covered by existing rules, point-in-time/stale, or better preserved in this reflection than promoted. Not promoted per the 2026-05-31 institute leanness program (de-bloat triage) to avoid further [PREFIX-*] proliferation in an oversized corpus; research items deferred (spawn via /research-process when scheduled). Learning retained here; re-promote individually if a pattern recurs."
---

# swift-standard-library-extensions stress test and the Tier-0 boundary pattern

## What Happened

Final leaf of the 11-package leaf-triage workflow (HANDOFF.md, dispatched as the stress test — baseline 620 findings; post-prior-amendment 321). Session work:

1. **Scaffolded `Lint/`** at `swift-standard-library-extensions/Lint/` mirroring the template from prior leaves. Initial run failed on a dangling symlink in `Experiments/`; pointed the linter at `Sources/` only.

2. **Triaged 321 findings into 8 clusters** across 8 rules. Cluster anatomy:
   - 234 `[API-IMPL-008]` minimal type body — every hit on a `*.Builder.swift` file using `@resultBuilder`-marked enums (Bool/Result/String/Range/ContiguousArray/ArraySlice/Set/Dictionary/Array/Optional/CollectionOfOne builders, plus 2 on Set String.swift's nested `Swift` namespace struct)
   - 32 `[IMPL-010]` int public parameter — split into stdlib-shadow signatures, closure-builder accumulator, and institute extensions
   - 29 `[API-NAME-002]` compound identifier — 26 stdlib-shadow names (`withUnsafeBufferPointer` family + `Continuation` family + `mapError`/`flatMapError` + `mapKeys`/`compactMapKeys`), 3 institute compounds (`cartesianProduct`/`cartesianSquare`/`removingDuplicates`)
   - 20 `[API-ERR-004]` closure typed throws — all inside the Result-materialization pattern per [IMPL-109]
   - 12 `[IMPL-075]` do throws for typed catch — bare `do { try ... } catch let e as E { ... } catch { precondition }` workarounds
   - 5 `[PLAT-ARCH-022]` swift_qualification — bare `Sequence` in Array/ArraySlice/ContiguousArray/Dictionary/Set Builders
   - 2 `[MEM-COPY-004]` extension noncopyable constraint — extensions on Dictionary and Set with `consuming` parameters
   - 1 each `[IMPL-033]` (Set.subsets counter loop) and `[API-IMPL-003]` (Int.init(_:Bool) conversion init)

3. **Identified 5 new amendment threads** (#14, #15, #16, #17, #18) and 2 extensions to existing threads (#2-ext compound citation dict +18 entries, #3-ext memory inexpressible list +5 stdlib-Copyable types). The orchestrator landed #14, #16, #17, #18, #19 (a new thread for `extension Set { Swift.Sequence }` namespace shadow), plus the dict extensions.

4. **Architectural insight on `[IMPL-010]`**: swift-standard-library-extensions is at **Tier 0** with zero primitive dependencies. The typed wrappers IMPL-010 directs writers toward (`Index<T>`, `Ordinal`, `Cardinal`, `Count<T>`, `Offset<T>`) all live at higher tiers. The package categorically cannot import them. Int IS the right type at this boundary — it's the stdlib edge that other primitives wrap. The rule was correct *as written*; the violation is fundamental to the package's architectural position. Proposed Route 1 (leaf-side `Lint.Configuration.override(.\`int public parameter\`, severity: .none)` from the leaf's own `main.swift`) over Route 2 (rule-side tier detection). The orchestrator agreed (Route 1 keeps the rule pure of dependency-graph awareness; the architectural exception lives in the leaf that owns the constraint).

5. **Executed 22 SOURCE-WRONG fixes across two commits**:
   - `c68d088` (17 fixes): 12 `do throws(E)` clauses + 4 `Swift.Sequence` qualifications + 1 counter-loop refactor (`for index in elements[start...].indices`)
   - `d0f81bd` (5 fixes): `cartesianProduct`/`cartesianSquare` reshaped to nested `set.cartesian.product/square` accessor pattern (introduced `Set.Cartesian` view struct, Tier-0 compatible — no Property.View dependency); `removingDuplicates()` renamed to `uniqued()` per swift-algorithms precedent; `Set<String>.Swift`'s `keywords` static and `escape(_:)` method extracted to sibling extension

6. **Compile-time blocker encountered on Cluster F** (4 of 5 Swift.Sequence qualifications): `extension Set { @resultBuilder enum Builder { ... <S: Swift.Sequence> ... } }` fails because Swift's name resolution treats `Swift` as a member type of `Set<Element>` (the type's own member-lookup scope shadows the module name). Reverted Set.Builder.swift to unqualified `Sequence`; orchestrator landed amendment #19 (SwiftQualification stdlib-shadow exemption) which cleared the residual finding.

7. **Verification gap caught by user**: After the first commit I reported "Build complete" but not "tests pass." User asked "did you compile and test?" — I had compiled but not tested. Tests then ran clean (556 tests / 169 suites). Same verification pair ran after the second commit before reporting.

**Final state**: 620 baseline → 321 post-prior-amendments → 22 post-amendments #14/#16/#17/#18/#19 + dict extensions → 17 post-source-fixes → **0 after leaf-side Configuration.override landed**. 100% reduction at the leaf; ~95% session aggregate across 10 leaves.

**HANDOFF triage**: 18 files at `/Users/coen/Developer/` root. 1 in-scope (`HANDOFF.md` — the leaf-triage workflow, annotated in-place to mark all 10 leaves with triage status; 9 of 10 at 0 residual, swift-ownership at 19 SOURCE-WRONG pending, swift-property at 1 AMBIGUOUS); 17 out-of-session-scope. None deleted — workflow continues with the ownership-primitives SOURCE-WRONG queue.

## What Worked and What Didn't

**Worked**:
- **Cluster-anatomy-first triage**. Separating clusters by rule and then by sub-pattern (stdlib-shadow vs institute-defined vs result-builder-internal) before disposition meant the orchestrator's amendment design could target real categories. The 234 `[API-IMPL-008]` cluster all sharing one pattern (`@resultBuilder` enum body) meant one amendment unlocked 73% of the corpus.
- **Architectural reasoning catching IMPL-010**. Counting findings file-by-file would have produced 32 individual SOURCE-WRONG dispositions. Asking "what tier is this package at?" produced one architectural disposition that scales. The Tier-0 boundary insight is the highest-value finding of the session.
- **Cross-rule pattern recognition**. Three sibling rules (Naming.Compound, Naming.BoolParameter, Naming.IntParameter) already had the `@resultBuilder` exemption; the missing rule (Structure.MinimalTypeBody) was a structural gap, not a design question. Same with Result-materialization: `Lint.Rule.Throws.DoCatchTyped` already inspected the same shape that `[API-ERR-004]` needed to recognize.
- **The orchestrator's amendment-first approach**. Landing rules before source fixes meant the rename (`removingDuplicates → uniqued`) didn't trigger fresh findings — `uniqued` was added to the citation dict in the same amendment that the rename used as precedent.

**Didn't work**:
- **`swift build` without `swift test`**. Reported the first commit as verified after `Build complete!` only. The user asked "did you compile and test?" — caught the omission. The cluster of edits touched only deterministic transformations (do throws clauses, counter-loop rename), but a typed-throws clause CAN change error propagation behavior in test scenarios. Skipping the test run is a real verification gap.
- **First-pass Swift.Sequence on Set.Builder**. The qualification edit succeeded mechanically (same edit pattern as 4 sibling files), but compile-time failure on the Set extension surfaced a real Swift type-checker quirk that the rule didn't anticipate. Reverting + re-running the build cost ~2 minutes; the orchestrator's amendment #19 was the right structural fix.
- **Cluster B.2 design ambiguity**. The orchestrator and I converged on the nested `set.cartesian.product` form, but I had to ask whether to use Property.View or a bare struct — Property.View isn't available at Tier 0. The eventual `Set.Cartesian` struct works but is heavier than a single method. If this leaf had more `cartesian.X`-style operations, Property.View at Tier 0 would be worth promoting; today it's overkill.

## Patterns and Root Causes

**Pattern 1: Tier-0 boundary leaves are categorically different from interior leaves.** Three observations cluster around this:
- IMPL-010 fires harmlessly on stdlib-shadow signatures because typed wrappers don't exist yet
- PLAT-ARCH-022 fires harmlessly on `Sequence` in `extension Set { }` because the Swift module is shadowed
- The 234 `@resultBuilder` enums exist because this layer extends stdlib container types where Apple put their result-builder semantics

The root cause: **the leaf's purpose IS the boundary**. It is the bridge between stdlib types and the typed institute ecosystem. Rules designed for interior leaves (where typed wrappers are available, where `Swift` qualification is unambiguous, where institute conventions can be enforced without stdlib-shape constraints) misfire at the boundary. This generalizes beyond IMPL-010: any rule that says "push X to the edge" or "qualify Y" or "extract Z to extension" will produce structural noise at the Tier-0 boundary.

**Pattern 2: The post-edit verification gap is asymmetric in cost.** `swift build` proves type-correctness; `swift test` proves behavioral-correctness. For mechanical refactors (rename, extract, requalify), the build often suffices. For semantic refactors (typed-throws clauses changing error propagation, counter-loop replacements changing iteration order), the build does NOT suffice. The post-commit memory scan rule from [REFL-006] addresses one half of this asymmetry; the build-vs-test verification gap is the other half. The user's "did you compile and test?" intervention IS a mechanical check that should be unprompted.

**Pattern 3: Rules acquire `@resultBuilder` exemptions one at a time, lazily.** Compound (Wave 1), BoolParameter (Wave 2), IntParameter (Wave 2) all had `namingIsInsideResultBuilderType`. MinimalTypeBody was the structural gap that the stress-test leaf surfaced because earlier leaves didn't have `*.Builder.swift` files. The pattern: when a rule pack ships, audit all sibling rules for the same exemption surface. The result-builder informal-protocol is a Swift-native attribute; ANY rule that scrutinizes type-body shape, parameter shape, return shape, or naming shape needs to consider whether `@resultBuilder` exempts its trigger.

**Pattern 4: Source fixes and rule amendments compose as a single optimization.** Renaming `removingDuplicates → uniqued` would have introduced a fresh `[API-NAME-002]` finding had the citation dict not been extended first. The orchestrator's discipline of landing amendments BEFORE source fixes is the correct order: rules first define what "compliant" means; source then aligns. Reversing the order would have produced churn (rename triggers finding → rule retroactively forgives).

## Action Items

- [ ] **[skill]** reflect-session: Extend [REFL-006] (re-verify-after-edit) with an explicit `swift build` + `swift test` pairing requirement when the edits touch source. Running only `swift build` and reporting "verified" is a known gap that the user has had to catch verbally; the rule should make the pair mechanical. Cite the 2026-05-11 origin incident where the user asked "did you compile and test?" to surface the omission.

- [ ] **[skill]** primitives: Codify the Tier-0-boundary-package architectural exemption pattern. Currently [PRIM-FOUND-004] documents the principled-friction at L1 boundaries; the analog for Tier-0 boundary leaves is: "Tier-0 packages cannot import typed wrappers (`Index<T>`, `Cardinal`, etc.) because those live at higher tiers. Lint rules that direct toward typed wrappers (`[IMPL-010]`, similar 'push X to the edge' rules) MUST be opted out at Tier-0 boundary leaves via leaf-side `Lint.Configuration.override(.X, severity: .none)`." Generalizes beyond IMPL-010 to any "push X out" rule.

- [ ] **[research]** Document the `extension X { ... Swift.Sequence ... }` namespace-shadow class for swift-foundations/swift-linter-rules: any extension of a Swift-module type (Set, Array, Dictionary, String, …) triggers Swift's member-type lookup to shadow the `Swift` module name inside the extension body. This affects PLAT-ARCH-022 by structural necessity (amendment #19 handled it), but the underlying Swift type-checker behavior is worth a one-pager — `feedback_swift_namespace_shadow_in_stdlib_extensions.md` candidate or research note. Surfaces also affect: `Swift.Bool`, `Swift.Int`, `Swift.String` references inside `extension Bool/Int/String { }`.

## Session Artifact Cleanup

**HANDOFF scan**: 18 files at `/Users/coen/Developer/` root + 1 at `/Users/coen/Developer/swift-primitives/`.

| Disposition | Files | Notes |
|-------------|-------|-------|
| Annotated, left | 1 | `HANDOFF.md` — leaf-table updated with per-leaf triage status; workflow continues with ownership-primitives SOURCE-WRONG queue (19 pending) |
| Out-of-session-scope | 18 | Other handoffs cover unrelated topics (publication pipelines, mechanization arcs, etc.); bounded cleanup authority per [REFL-009] |
| Deleted | 0 | The leaf-triage workflow has follow-up Next Steps; HANDOFF.md remains active |

**Audit findings cleanup**: No `/audit` invocation this session; no audit-status updates.
