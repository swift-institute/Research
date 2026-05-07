---
date: 2026-05-07
session_objective: Close pre-publishable defects across 4 swift-linter ecosystem repos (README + Lint.Driver workspace-path + stale namespace docs).
packages:
  - swift-foundations/swift-linter
  - swift-primitives/swift-linter-primitives
  - swift-foundations/swift-manifests
  - swift-primitives/swift-manifest-primitives
status: processed
processed_date: 2026-05-07
triage_outcomes:
  - type: skill_update
    target: readme
    description: "[README-170] Composed-Example Empirical Validation added to ci-automation.md"
  - type: skill_update
    target: handoff
    description: "[HANDOFF-041] Acceptance-Criterion Grep Anchoring added"
  - type: research_update
    target: single-file-lint-swift-deprecation-decision
    description: "Research/2026-05-07-single-file-lint-swift-deprecation-decision.md authored as IN_PROGRESS"
---

# D1' — README Repair + Driver Workspace-Path Removal

## What Happened

Branching dispatch `HANDOFF-d1-readme-and-driver-repair.md` (parallel to D4' on `swift-linter-rules`) closed the pre-publishable bundle for 4 of 5 swift-linter cohort repos. Six scope items executed in roughly the listed order, all in autonomous mode, gated by a 6-entry supervisor ground-rules block.

Per-repo deliverables:
- `swift-linter` (`ba02932`) — fixed compound-import (`Linter Rule X` → `Linter_Rule_X`) and namespace+accessor (`.ruleID` → `Lint.Rule.X.id`) in the `Lint/Sources/Lint/main.swift` example; stripped the inert-but-documented-as-functional `## Single-file Lint.swift form` section per Decision 1=B; preserved the `## Inheritance via // parent: directive` section per Decision 2=B; removed the hardcoded `/Users/coen/Developer/swift-foundations/swift-linter` workspace fallback in `Lint.Driver.swift` (now emits an explicit error and returns the empty default Configuration when `SWIFT_LINTER_PATH` is unset); replaced the stale "Phase 1 ships R5" / "CLI activates all built-in rules" CLI discussion text.
- `swift-linter-primitives` (`49a6287`) — authored a new README from scratch following the Family E sub-package structure (5 sections), motivated Quick Start by authoring a `Lint.Rule.\`Protocol\`` conformer (`ForceTry`); refreshed the Lint/Lint.Rule/Lint.Configuration/Lint.Configuration.Error namespace doc-comments (drop "Lint.Rule.Unchecked at L3" stale framing, drop ".swift-linter.yml" YAML reference, replace `SwiftPrimitivesLintCanonical.tier2` example with real `Lint.Rule.X.self` types).
- `swift-manifests` (`a219346`) — `packageName:` → `name:` in the Quick Start; replaced `Lint.Configuration()` zero-arg + `Lint.Configuration(layered:on:)` with the real `Lint.Configuration(inheriting:rules:excluded:)` shape using `.empty` for default.
- `swift-manifest-primitives` (`9437b10`) — text-only `packageName` → `name` in the namespace table.

Empirical validation: 7 README code examples extracted to `/tmp/handoff-d1-readme-extracts/` and `swiftc -parse`'d, all status 0. Clean-build all 4 repos serial (per `feedback_no_parallel_swift_builds`), all green: manifest-primitives 69.50s, linter-primitives 44.26s, manifests 278.02s, linter 237.39s. Pre-existing unused-import warnings in dep packages noted but orthogonal. `swift-linter-rules` zero edits — D4' ran in parallel and committed independently (`04a8ef3`).

HANDOFF scan: 1 file found at workspace root for this dispatch (`HANDOFF-d1-readme-and-driver-repair.md`), annotated with `## Implementation Notes` per the Findings Destination + supervisor verification stamp. Principal subsequently authorized `YES PUSH WAVE D1'`; all 4 commits pushed (ba02932/49a6287/a219346/9437b10), `ahead==0` per repo, in-sync with origin/main. Verification stamp updated to record entry #6 deviation as "resolved by acceptance" (principal authorized push without addressing the deviation). HANDOFF file left in place with final annotations for parent supervisor's audit-trail roll-up. Other root handoffs (D2', D3', D4', etc.) are out of this session's cleanup authority per [REFL-009] bounded-cleanup; they remain for the parent supervisor's roll-up.

## What Worked and What Didn't

What worked:
- Pre-execution verification per [HANDOFF-010] caught no staleness in the 6 line-ref citations across the 4 repos. The handoff was authored close enough in time that nothing had drifted.
- The supervisor ground-rules block's typed entries (4 MUST / MUST NOT / fact + 2 ask) gave clean execution boundaries. Entry #4 (no edits to swift-linter-rules) and entry #5 (no remote push) were never tempted because the work's grep-set never crossed those boundaries.
- Cross-checking the real API surface before writing the swift-linter-primitives Quick Start caught a `Source.Location(file:line:column:)` signature defect — the actual init is `(fileID:filePath:line:column:)`. `swiftc -parse` alone would NOT have caught this (parse validates syntax, not type resolution); reading `Source.Location.swift` directly is what surfaced it. The supervisor MUST 2 specifies parse OR full build; the latter would have caught it but at much higher cost.
- Modeling the new README on `swift-tagged-primitives/README.md` (a Tier-1 sibling) gave a concrete style anchor instead of authoring against the readme-skill rules from cold.

What didn't:
- Acceptance Criterion 2 (`grep -c "Single-file" README.md` → 0) collided with supervisor entry #6 (`ask:` Surface dangling references; escalate before deleting wider scope). The literal grep substring "Single-file" remained in the `## Two consumer shapes` section (item #2 honestly flags the form as inert), which I deliberately preserved per entry #6. Resolved by surfacing as a Deviation in Implementation Notes; the principal will decide. The cost: one criterion that does not strictly verify on paper, plus the audit trail of surfaced reasoning.

## Patterns and Root Causes

The criterion-vs-entry collision is a recurring shape: a verification gate (grep returns 0) and a behavioral rule (ask before deleting wider scope) that overlap on a specific case neither explicitly carved out. This is a milder relative of `[HANDOFF-018]` (opt-out clauses are preferences, not permissions) — when an acceptance criterion's verification is a string-substring grep, the criterion is over-inclusive of the specific carve-out the behavioral rule expected. The fix is at handoff-write time, not execution time: the criterion grep should be `grep -c "## Single-file"` (heading-anchored) not `grep -c "Single-file"` (substring-anchored). The substring grep is a [SUPER-022] verification mechanism that doesn't match its own criterion text ("README contains no `## Single-file Lint.swift form` section" — heading-bounded, not substring-bounded). Codifying the lesson: when a verification grep targets a section heading, anchor the regex to the heading shape (`## Section`, not bare keywords).

The Source.Location signature catch is a related shape on the API side: `swiftc -parse` validates that the example is grammatically Swift; it does not validate that the example uses real APIs in their real shapes. This matters for README examples that compose multiple ecosystem types (Source.Location + Diagnostic.Record + Lint.Rule.Protocol + SwiftSyntax). The supervisor MUST 2 chose parse-or-build; for examples like the Quick Start that compose 4+ typed APIs, parse-only is structurally insufficient. Reading the underlying `.swift` source for each composed type (one Read per signature) is faster than waiting for a full `swift build` and catches signature defects directly. Recommended pattern when authoring composed examples: grep the call-site shape against an existing real call-site in the ecosystem (here: `swift-linter-rules/Sources/Linter Rule Try Optional/Lint.Rule.TryOptional.swift` provided the exact `Source.Location(fileID:filePath:line:column:)` shape verbatim).

## Action Items

- [ ] **[skill]** readme: extend [README-009] / [README-022] with the lesson that `swiftc -parse` validates parse only — for README examples that compose multiple ecosystem types, the empirical-validation discipline should additionally cite (a) a real call-site of each composed type, or (b) a full `swift build` against a scratch SwiftPM package. Citation form: each composed type gets a one-line "real call-site" reference in the validation report.
- [ ] **[skill]** handoff: add a note to [HANDOFF-021] (Scope Enumeration at Write-Time) that when an Acceptance Criterion's verification is a grep, the regex SHOULD be anchored to whatever the criterion text describes (heading-anchored if the text says "section", line-anchored if it says "line"). Substring-anchored greps are over-inclusive when the criterion text references a structural element. Provenance: this dispatch's Criterion 2.
- [ ] **[research]** Is a fully-typed-DSL `Lint.swift` consumer experience needed? The current single-file form is inert; the `Lint/` nested-package shape works. Is the single-file form worth preserving as a future-facing sugar form, or should it be deprecated entirely? The "Two consumer shapes" section currently presents it as a forward-looking option; if it's never going to ship, the right move is to remove the dual-shape framing across the linter docs and present `Lint/` as the only consumer shape.
