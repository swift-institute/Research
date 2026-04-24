---
date: 2026-04-22
session_objective: Apply aggressive one-target-per-type modularization to swift-standard-library-extensions; understand benefits/cons and empirical compile-time impact
packages:
  - swift-standard-library-extensions
  - swift-format-primitives
  - swift-rfc-2045
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Strict per-type modularization experiment and case-formatting relocation

## What Happened

**Objective**: The user asked whether aggressive modularization (one SwiftPM target per stdlib type, ≈83 targets, zero intra-package deps) should be applied to `swift-standard-library-extensions`, and wanted (a) a principled answer on benefits/cons, (b) research on compile-time impact.

**Progression**:

1. **Design framing**. Initial proposal bundled the 87 source files into ~23 "clusters" by taxonomy (Numeric family, Lazy family, etc.). User pushed back: "clusters still are arbitrary." Agreed; corrected to strict per-extended-type following `[MOD-DOMAIN]`.

2. **Research → experiment handoff**. Invoked `/research-process` to scope the compile-time question (Tier 2 doc in `swift-standard-library-extensions/Research/modularization-compile-time-impact.md`). Invoked `/experiment-process` to materialize a harness in `swift-standard-library-extensions/Experiments/modularization-compile-time/`: generator mechanically produces SwiftPM variant packages from partition descriptors, `run-mvp.sh` does median-of-5 per cell.

3. **MVP first run**: baseline N=1 measured at 1.41s median clean debug. Variant N=max **failed to build** with four classes of source-level blockers:
   - Class 1: nested-type cross-file ref (`StringProtocol.swift` uses `String.Case` declared in `String.swift`).
   - Class 2: cross-module access to implicit-`internal` members (`String.Case.transform`).
   - Class 3: shadow-type ambiguity (package-owned `Result` vs `Swift.Result`).
   - Class 4: leaf-to-leaf extension-method dep (`Bool.swift` uses `Int.init(Bool)` from `Int.swift`).

   Wrote this up as the experiment result — at the time framing Class 4 as "decisive, open-ended coupling-density cost requiring SwiftSyntax-based tooling."

4. **User asked "package access?"** Correctly answered that `package` fixes Class 2 but not Classes 1/3/4. User then asked how to best proceed, noting "ideally no intra-dependencies." Agreed; articulated the **self-containment principle**: every extension file should express its API in stdlib terms alone, never in terms of sibling-file APIs.

5. **Inventory tool**. Built `Audits/cross-file-inventory/inventory.sh` (grep-based static scan for nested-type declarations + cross-file method refs + custom init refs). Output: exactly **two** real cross-file references in the 87-file package. `String.Case` in `StringProtocol.swift` (Class 1) and `Int(Bool)` in `Bool.swift` (Class 4). Class 2 becomes moot once those are eliminated; Class 3 never surfaced in practice.

6. **Refactor pass**. (a) `Bool.swift`: `.init(self)` → `self ? 1 : 0`. (b) Split `Array.Builder.swift` into three files; inlined Builder-to-Builder delegation. (c) `@inlinable` sweep: 49 additions across 19 files via `Audits/cross-file-inventory/add-inlinable.py`. All 561 tests continue to pass. Variant N=max now builds; ratio 4.13× → 3.07× after @inlinable sweep.

7. **Speculative rename misstep**. To decouple `String.Case` (transformation) from `Case.Insensitive` (hashing) so each could live in a different target, renamed `String.Case.Insensitive` → `String.CaseInsensitive`. User caught it: "this violates /code-surface." Correct — `CaseInsensitive` is compound per [API-NAME-002]. Reverted. User also suggested the right long-term placement: "this does look like format-primitives stuff."

8. **Case-formatting relocation**. Wrote `swift-format-primitives/Research/case-formatting-placement.md` scoping the move. Implemented:
   - `Format.Case` conforming to `Format.Style<String, String>` with `.upper`/`.lower`/`.title`/`.sentence` presets.
   - `Format.Case.Insensitive` nested (proper three-level `Nest.Name`, no compound).
   - `StringProtocol.formatted(_:)` (concrete + generic overloads) + `String.caseInsensitive`.
   - Migrated 5 tests; added ~25 new Format.Case tests.
   - Deleted the relocated content from `swift-standard-library-extensions`.
   - API change: `formatted(as: .upper)` → `formatted(.upper)` (matches existing `42.formatted(.binary)` precedent).

9. **Downstream consumer migration**. `swift-ietf/swift-rfc-2045` was the only ecosystem consumer of `String.Case.Insensitive` (in `RFC_2045.Parameter.Name`). Added `swift-format-primitives` dep, changed 4 type-path references, added one `import Format_Primitives` to a second file to satisfy Swift's per-file nested-type visibility rule.

10. **Generator cleanup**. Removed the `StringProtocol → String` folding special case from the experiment generator. Strict per-file partitioning now produces 79 independent targets with zero special cases. Final measurement: ~3.07× ratio (mid-band of predicted 1.5–4×).

11. **Commits**. Four commits across three repos: production refactor + research/experiment infrastructure in `swift-standard-library-extensions`, format-primitives absorption in `swift-format-primitives`, consumer migration in `swift-rfc-2045`. Nothing pushed.

**HANDOFF scan** per [REFL-009]: 18 HANDOFF files found across `/Users/coen/Developer/` and `/Users/coen/Developer/swift-primitives/`; 0 in-session-scope (none written, none actively worked, no completion signals encountered). All 18 left in place, no annotation.

## What Worked and What Didn't

**Worked**:
- **Inventory tool before refactor commit**. A ~30-minute grep + triage pass turned the Class 4 finding from "open-ended coupling-density cost" into "2 real cross-file references." This single step saved ≥1 day of speculation or SwiftSyntax tooling.
- **User pushbacks at decision points**. Two were load-bearing: (a) "clusters are arbitrary" → forced principled per-type thinking; (b) "CaseInsensitive violates /code-surface. why was this chosen?" → caught the naming violation AND triggered the architectural move to format-primitives, which was the right fix all along.
- **Staged progression**: research → experiment → findings → refactor → re-measure. Each stage resolved specific uncertainty before the next began. `/research-process` and `/experiment-process` skills handled the process scaffolding cleanly.
- **End-to-end implementation + commit**. From "explore what that should look like" to committed refactor took one focused session with a clean commit history (4 commits, logically separable).

**Didn't work**:
- **Extrapolation from a small-N error sample**. Hitting 1 Class 1 + 1 Class 4 error in the first build attempt was enough to declare "dense coupling" and propose "SwiftSyntax-based dep inference tooling" as future work. The inventory later showed the coupling was small and mechanical. I should have built the inventory FIRST, not extrapolated from two data points.
- **Speculative rename without convention check**. The `CaseInsensitive` rename optimized for a structural goal (put `Case` in one target, `Insensitive` in another) without consulting [API-NAME-002]. The naming rule was in my context (a user memory explicitly cites it), but I didn't scan before applying.
- **Initial taxonomy clustering**. The 23-cluster proposal (Numeric family, Lazy family, etc.) was taxonomic, not structural. User correctly identified this. Clusters by name-similarity aren't the same as clusters by coupling.

## Patterns and Root Causes

**1. Extrapolation bias from small error samples**. For "how much coupling is there?" questions, hitting N errors and extrapolating is unreliable. The actual count was 2, but after seeing 2 errors I was already writing "this requires a SwiftSyntax-based dep inferer" in the report. The inventory tool produced a bounded answer in 30 minutes. Rule I should internalize: when facing open-ended-looking source-level obstacles, build the mechanical scanner before writing prose about the scope.

**2. Memory-consultation gap on naming rules.** The `CaseInsensitive` rename is the textbook case for the post-commit memory scan that [REFL-006] formalizes. The rule existed; I didn't consult it. The user caught what I would have caught myself with a 10-second grep over `~/.claude/projects/-Users-coen-Developer/memory/feedback_*.md` (or the skill). This pattern repeats: rules for naming, access-level, convention compliance live in well-known skills/memories, and auto-mode speculation bypasses them. The post-commit-memory-scan practice needs explicit pre-edit invocation for any action that introduces a new public identifier.

**3. Package placement as the right question when mechanical fixes get ugly.** The moment I was proposing nested-type renames to decouple targets, the right question was "is this content in the right package?" The user reached that conclusion immediately; I was inside the constraints that had been imposed by the wrong placement. Lesson: when a refactor requires repeated rename/unnest/restructure moves to satisfy modularization, suspect the enclosing package boundary before committing to the rename.

**4. The self-containment principle has empirical teeth.** For `swift-standard-library-extensions`, "each file uses stdlib only" required changing exactly two lines (`Bool.swift:15` and moving the `formatted(as:)` subsystem). The rest of the 87-file package already satisfied it. This is the kind of principle that would benefit from explicit documentation — it generalizes beyond this one package.

**5. Auto-mode produces faster progress but requires convention-rule scanning as a harness.** In auto mode the session moved efficiently from question → research → experiment → refactor → commit without interruption for routine decisions. But the two corrections that mattered (clustering, naming) came from the user. A pre-edit checkpoint for convention compliance ([API-NAME-*], [MOD-*]) would let auto-mode keep its velocity without ceding correctness to human review at arbitrary points.

## Action Items

- [ ] **[skill]** code-surface: Add a pre-rename checkpoint — any new type identifier introduced during refactoring MUST be verified against [API-NAME-001] (Nest.Name pattern) and [API-NAME-002] (no compound identifiers) BEFORE being applied, not after. The `CaseInsensitive` violation would have been caught by a mechanical check against the naming rules. Codify this as a rule the refactoring workflow scans against.
- [ ] **[skill]** modularization: Add a rule — before declaring cross-file coupling "open-ended" or "dense," run a mechanical inventory (grep for declared nested types + custom-init patterns + declared extension methods, cross-reference across files). Hitting N errors in a partial build and extrapolating is unreliable; the actual coupling count is the actionable number. Include the 30-minute-scan expectation as part of the skill's scope-estimation guidance.
- [ ] **[blog]** Self-containment principle for stdlib-extension packages, with the swift-standard-library-extensions empirical case study (87 files, 2 cross-file refs after audit, strict per-type modularization achievable in one session after the two fixes). The takeaway is architectural, not technical: when extensions reference sibling files, the content is probably in the wrong package — not a technical modularization problem.
