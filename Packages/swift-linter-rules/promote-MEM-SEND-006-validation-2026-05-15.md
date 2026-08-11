# Validation receipt: [MEM-SEND-006]

Date: 2026-05-15
Rule: `unchecked sendable revalidation anchor`
Placement tier: universal
Pack: Linter Rule Memory
Source: `swift-foundations/swift-linter-rules/Sources/Linter Rule Memory/Lint.Rule.Memory.UncheckedSendableRevalidationAnchor.swift`

## Detection method

Test-target validation harness. Temporary file at
`Tests/Linter Rule Memory Tests/UncheckedSendableRevalidationAnchor.Validation.swift`
walks each package's `Sources/` via `FileManager.default.enumerator`,
parses each `.swift` file with `SwiftParser`, runs the rule's visitor,
and prints per-package finding counts. Deleted post-receipt per
Phase 6 default.

Test-target harness chosen over regex pre-scan because the rule's
detection is genuinely AST-shaped (leading-trivia walking) and the
ground-truth probe across 33 broader packages would over-count via
regex (the rule's compiler-limitation-indicator + missing-marker
combination isn't regex-approximable).

## Validation ladder

| Level | Package | Source files | Diagnostic count | Notes |
|-------|---------|--------------|------------------|-------|
| Simple | swift-tagged-primitives | 10 | 0 | clean |
| Simple | swift-carrier-primitives | 44 | 0 | clean |
| Simple | swift-pair-primitives | 5 | 0 | clean |
| Medium | swift-property-primitives | 23 | 0 | clean |
| Medium | swift-cardinal-primitives | 27 | 0 | clean |
| Hard | swift-affine-primitives | 23 | 0 | clean |
| Hard | swift-ordinal-primitives | 45 | 0 | clean |

**Ladder total: 0 findings.** All 7 ladder packages clean per literal-rule reading. Within-budget (hard-level default is 10).

The ladder's lone `@unchecked Sendable` (`swift-property-primitives/.../Property.Consume.State.swift`) does not fire: the file's anchor block is on a different declaration (the inner `class State` at line 24) than the actual `@unchecked Sendable` extension (line 54). Per the literal-validator principle (pilot 11 `[TEST-005]`), the rule inspects the declaration's own leading trivia; the file's anchor placement is consistent with the rule's out-of-scope branch (no compiler-limitation indicators adjacent to the conformance → rule doesn't fire). The anchor placement is a file-author choice that the rule does not police.

## Ground-truth probe (separate budget — surfaces live work)

Per Phase 6's optional negative-ground-truth-probe sub-step (canonical `[GH-REPO-074]` pilot pattern), the rule was run against all 33 swift-primitives packages with non-zero `@unchecked Sendable` counts.

### Pre-iteration (broad Category A/B/C/D keyword set)

| Package | Findings | Notes |
|---------|----------|-------|
| swift-ownership-primitives | 6 | All Category A (synchronized) — FALSE POSITIVES |
| swift-buffer-primitives | 10 | Category D, real |
| swift-memory-primitives | 2 | @_rawLayout context, real |
| swift-list-primitives | 2 | real |
| swift-stack-primitives | 1 | real |
| swift-storage-primitives | 1 | real |
| swift-heap-primitives | 1 | real |
| swift-reference-primitives | 1 | real |

**Pre-iteration total: 24 findings on 8 packages.** 6 false positives identified in swift-ownership-primitives — the visitor's `Category [A-D]` keyword set was triggering on Category A `Ownership.Transfer.*` annotations that are documented via `## Safety Invariant` doc sections (per `[MEM-SAFE-024]`'s categorization) rather than `WHY:`/`WHEN TO REMOVE:`/`TRACKING:` markers. Category A is semantic-responsibility (synchronized), NOT compiler-limitation — out of scope for this rule.

### Iteration (Phase 6 branch 2 — tighten match)

Per `[MEM-SAFE-024]`'s categorization scheme, only **Category D** tags structural Sendable workarounds (compiler-limitation justification). The keyword set was tightened from `category a|b|c|d` to `category d` exclusively. Source diff:

```diff
- if lower.contains("category a")
-     || lower.contains("category b")
-     || lower.contains("category c")
-     || lower.contains("category d") {
+ if lower.contains("category d") {
```

### Post-iteration

| Package | Findings | Status |
|---------|----------|--------|
| swift-buffer-primitives | 10 | real |
| swift-memory-primitives | 2 | real |
| swift-list-primitives | 2 | real |
| swift-stack-primitives | 1 | real |
| swift-storage-primitives | 1 | real |
| swift-heap-primitives | 1 | real |
| swift-reference-primitives | 1 | real |

**Post-iteration total: 18 findings on 7 packages.** All Category A false positives in swift-ownership-primitives eliminated (6 → 0).

## Iteration branch decision

**Branch 1 — batch-fix.** Three findings sampled for verification:

- `swift-buffer-primitives/.../Buffer.Ring.Small+Span.swift:13` — Category D (SP-5) cited in `WHY:` lines; missing `WHEN TO REMOVE:` and `TRACKING:`. Real fire.
- `swift-memory-primitives/.../Memory.Inline ~Copyable.swift:93` — `@_rawLayout` context (doc-comment justification); no structured markers present. Real fire per literal reading (rule mechanizes institute markers; doc-comment justifications without structured markers are in-scope FAILs).
- `swift-heap-primitives/.../Heap.Static.swift:72` — sampled in pre-iteration; remained in post-iteration set.

Findings spread across 7 packages, all match the rule's intent (compiler-limitation-justified `@unchecked Sendable` lacking structured revalidation markers). Branch 1 applies: file the fixes as separate per-package PRs against each consumer, document in outcome record, proceed to Phase 7.

## Deferred batch-fix queue (18 findings)

```
swift-buffer-primitives:
  Buffer Aligned Primitives Core/Buffer.Aligned.swift:67
  Buffer Arena Primitives Core/Buffer.Arena.swift:231
  Buffer Linear Inline Primitives/Buffer.Linear.Inline Copyable.swift:57
  Buffer Linear Primitives/Buffer.Linear+Span.swift:10
  Buffer Linear Primitives/Buffer.Linear+Span.swift:71
  Buffer Ring Inline Primitives/Buffer.Ring.Small+Span.swift:13
  Buffer Ring Primitives/Buffer.Ring+Span.swift:13
  Buffer Ring Primitives/Buffer.Ring+Span.swift:132
  Buffer Slab Primitives/Buffer.Slab.Bounded+Consume.swift:13
  Buffer Slab Primitives/Buffer.Slab+Consume.swift:13

swift-memory-primitives:
  Memory Primitives Core/Memory.Inline ~Copyable.swift:93
  Memory Primitives Core/Memory.Inline ~Copyable.swift:115

swift-list-primitives:
  List Primitives Core/List.Linked.swift:275
  List Primitives Core/List.Linked.swift:314

swift-heap-primitives:
  Heap Primitives Core/Heap.Static.swift:72

swift-stack-primitives:
  Stack Static Primitives/Stack.Static ~Copyable.swift:157

swift-storage-primitives:
  Storage Inline Primitives/Storage.Inline ~Copyable.swift:156

swift-reference-primitives:
  Reference Primitives/Reference.Sendability.Unchecked.swift:50
```

Each fix is mechanical: add the missing markers (typically `WHEN TO REMOVE:` and `TRACKING:` — the institute pattern is to land a single audit-findings link plus a "until Swift X.Y" or "until compiler gains structural Sendable through Z" remove condition). The fixes land as separate per-package PRs; the rule landing on `main` is not blocked on them (warning severity per `[PROMOTE-009]`).

## Decision

**Phase 6 PASS.** Ladder clean (0 within-budget); ground-truth probe surfaces real ecosystem work (18 findings on 7 packages). Iteration loop branch 1 taken; batch-fix queue deferred for separate per-package PRs. Proceed to Phase 7 atomic landing.

## Phase 6 lessons (recorded for Phase 8 methodology section)

1. **Tightening discrimination keyword sets is a Phase 6 iteration, not a Phase 1 mistake.** The initial keyword set (`Category [A-D]`) was reasonable a priori; the ground-truth probe revealed that `[MEM-SAFE-024]`'s categorization scheme reserves only Category D for compiler-limitation, with Categories A/B/C carrying different documentation discipline (`## Safety Invariant` doc sections). The iteration tightened in 5 minutes; pre-iteration triage couldn't have known this without seeing the firing pattern.

2. **Ground-truth probe budget separation is load-bearing.** The validation ladder (0 findings) and ground-truth probe (18 findings) have separate budgets. Conflating them would have either masked the ladder's cleanness or panicked at "18 findings exceed 10-budget" when the budget only applies to the ladder.

3. **Literal-validator principle handles author-anchor-placement bugs cleanly.** Property.Consume.State.swift's anchor is on a different declaration than the actual `@unchecked Sendable`; the rule correctly doesn't fire because adjacency is part of the literal rule, and the file-author's anchor-placement choice is a separate concern (recorded in the file's own discipline, not policed by this rule).
