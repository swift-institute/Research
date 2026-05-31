---
date: 2026-05-11
session_objective: Land Wave 3 of the rule-corpus iteration — 6 rule-amendment threads, 3 queued policy decisions, and aggregate validation per HANDOFF.md dispatch.
packages:
  - swift-foundations/swift-linter-rules
  - swift-foundations/swift-institute-linter-rules
  - swift-foundations/swift-linter
  - swift-primitives/swift-ownership-primitives
  - swift-primitives/swift-standard-library-extensions
  - swift-institute
status: processed
processed_date: 2026-05-31
triage_outcomes:
  - type: no_action
    description: "Action items are arc-specific process-discipline tweaks (handoff/supervise/issue-investigation/reflect-session/lint-rule-promotion) already substantially covered by existing rules, point-in-time/stale, or better preserved in this reflection than promoted. Not promoted per the 2026-05-31 institute leanness program (de-bloat triage) to avoid further [PREFIX-*] proliferation in an oversized corpus; research items deferred (spawn via /research-process when scheduled). Learning retained here; re-promote individually if a pattern recurs."
---

# Wave 3 closure: rule amendments, research docs, aggregate — and the Thread 2 surface-enumeration gap

## What Happened

Wave 3 of the rule-corpus iteration. HANDOFF.md dispatched 13 items: 6 rule-amendment threads (#1–#6), 2 queued policy deliberations (#7 MEM-SAFE-025 reconciliation, #8 per-finding disable mechanism), aggregate validation (#9), and 4 deferred future-scope items (#10–#13).

**Pre-flight per [HANDOFF-010] + [HANDOFF-016]:** verified Wave 2 closeout commit `b475d6f` on tip of swift-ownership-primitives. Caught two path-citation premise-staleness defects in the handoff's Next Steps:
- Thread 5 cited "Lint.Rule.*BoxClass* in swift-linter-rules" — actual location was `swift-institute-linter-rules/.../Lint.Rule.Naming.BoxClass.swift` (different repo + rule name `BoxClass`, not `AdHocBoxClass`).
- Thread 6 cited `Sources/Linter Rule Patterns/Lint.Rule.Patterns.InlinableInternalAccess.swift` — actual location was `Linter Rule Structure/Lint.Rule.Structure.InlinableInternalAccess.swift` (different directory + naming family).

Both were corrected in-line and reported in the reading-the-handoff response.

**Rule amendments (5 commits across 2 private rule repos, all pushed):**
- swift-linter-rules: Thread #1 (nested-type-skip in `ExtensionNoncopyableConstraint`), Thread #2 (method-local-generic exemption), Thread #6 (init-specific message for `InlinableInternalAccess`).
- swift-institute-linter-rules: Thread #3 (SE-0517 `span`/`mutableSpan` exemption in `NamingCompound`), Thread #5 (canonical-CoW-backing exemption in `BoxClass`).

Each thread landed as a single ledger commit per [HANDOFF-019]. All amendments shipped with new tests (3 + 4 + 3 + 2 + 4 = 16 new tests; all green).

**Research docs (3 RECOMMENDATION docs at `swift-institute/Research/`, unpushed pending user review):**
- Thread #4: `api-name-002-private-surface-applicability.md` (3 options + comparison matrix; provisional lean Option B = exempt fileprivate+private).
- Thread #7: `mem-safe-025-reconciliation.md` (3 options + empirical catalogue of 6 live `@safe` decls ecosystem-wide; provisional lean Option B = two-rule replacement per partition-doc direction).
- Thread #8: `swift-linter-per-finding-disable-mechanism.md` (4 options + comparison matrix + ~150-LOC engine sketch; provisional lean Option D = hybrid line-comment + config).

Cross-session contamination on `_index.json` (prior-session edits adding `three-tier-linter-rules-partition.md` entry) handled twice via [HANDOFF-049] stash-edit-commit-pop. Pattern worked cleanly both times.

**Aggregate validation (Thread #9):** ran the lint executable across the 10 leaf packages with per-package `Lint/` sub-packages. First run hit a redirect-stream bug (findings go to stdout; my aggregate loop's `grep -c "^Sources"` was against stderr) — surfaced when "0 findings everywhere" contradicted the earlier smoke test. Re-tally from stdout gave 13 findings (down from 276 baseline, 9 cleanly-building packages). swift-standard-library-extensions had a pre-existing Lint sub-package build defect (missing `Linter_Rule_Naming` import for `MemberImportVisibility`).

**Mid-cycle correction:** I attempted to ask the user via AskUserQuestion about (a) push direction + Thread 9 timing and (b) Threads 7+8 policy stance. User rejected the question and gave a direct principal-tier directive: Option 1 for Q1 (push private + run Thread 9), Option 1 for Q2 (defer policy decisions), with reasoning ("orchestrator's job is to surface, not preempt") + specifics (the exact aggregate command shape + the wave-3-aggregate ledger filename).

**Per principal direction, two follow-up amendments landed:**
- Thread #2 extension (swift-linter-rules `ac40ca1`): closed the partial-gap surfaced by aggregate — `Erased.Incoming:57` with `consuming func consume<T>(_:T.Type)` (consuming-self modifier on a function with own generic params, on non-generic extended type). Pattern-based exemption: skip when consuming/borrowing self-modifier paired with own genericParameterClause. 3 new tests; 16 total in suite.
- swift-standard-library-extensions Lint sub-package build fix (`02ac34f`): added direct `swift-institute-linter-rules` package dep + `Linter Rule Naming` product dep + `internal import Linter_Rule_Naming` in `main.swift`. Build clean; lint runs to completion at 0 findings (down from 620 baseline).

**Aggregate v1.1.0** amended ledger with 11-package number: **896 → 12 (98.7% drop)**. 12 residuals = 8 held vs user-tier decisions on Threads 4/7/8 + 4 deferred API-rename (Open Q3 takeIfPresent/consumeIfStored).

**HANDOFF.md updated in place** per [HANDOFF-009] — title now "Wave 3 — substantially closed; user-tier decisions pending"; Threads 4/7/8 marked "awaiting user stamp" with closing distribution (2+4+2); implementation passes for each stamped decision enumerated.

Final state: 9 private-repo commits pushed across 3 repos; 3 public-Research commits held local pending user push authorization.

## What Worked and What Didn't

**Worked**:
- **[HANDOFF-016] proposal-staleness check on resume** caught both path-citation defects immediately. The pre-flight `find`/`ls` against cited paths is cheap and dispositive — turning two would-be 30-minute "wait, this file doesn't exist?" rabbit holes into 30-second corrections.
- **[HANDOFF-049] stash-edit-commit-pop pattern** for cross-session `_index.json` contamination worked cleanly twice. The auto-merge handled non-overlapping prior-session edits without manual intervention.
- **Per-thread ledger commits ([HANDOFF-019])** preserved bisect-ability and produced clean per-thread attribution. Each commit's message linked the thread to the original handoff dispatch line + cited the source-fix commit body.
- **Aggregate validation as honest broker**: the aggregate's surfacing of the Thread 2 partial-gap was the system working as designed. Tests pass on synthetic source → real source surfaces the gap → corrective amendment lands. Without the aggregate, the Thread 2 gap would have shipped as silent rule-incompleteness.
- **User's principal-tier directive style** unblocked the mid-cycle freeze. The reasoning + specifics (exact command, exact filename, exact disposition matrix) gave me everything to execute Tasks 1+2+3 without further questioning.

**Didn't work**:
- **Thread 2 test coverage was narrower than the handoff's framing.** The handoff said "exempt non-generic extended types when no generic parameter exists to constrain." I implemented "exempt when consuming/borrowing parameter type is a method-local generic" — narrower. My 4 new tests all covered the parameter-shape; none covered the `consuming-self func` modifier-shape on a non-generic extended type. The visitor has TWO ownership-signal entry points (parameter type via `FunctionParameterSyntax` AND function modifier via `FunctionDeclSyntax`); my Thread 2 amendment + tests only covered the first. The aggregate ran-against-real-code (Erased.Incoming:57) surfaced the gap; test-against-synthetic-code didn't.
- **Stream-redirection bug in the aggregate loop.** Smoke test used `2>&1 | tail -20` (combined stream). Aggregate loop used `> stdout 2> stderr` and grepped stderr — but findings emit to stdout, build noise to stderr. Cost: ~2 minutes false-alarm + re-tally. Root cause: I didn't verify the redirection contract before running the loop; switching from combined-stream-smoke to split-stream-loop changed the assumption silently.
- **AskUserQuestion rejected at the policy-fork.** I framed it as a multi-option choice between "push + run Thread 9 vs hold for review vs push everything," when the user had already given clear directives implicitly ("proceed from the Next Steps section" + collaboration-protocol clause "challenge implementations" implies action, not further forking). The user's rejection + directive showed me the right shape: surface comprehensive status, recommend an explicit next action, let the user redirect.
- **System reminders about TaskCreate persisted** through the session. TaskCreate's schema wasn't loaded (deferred tool); the reminders kept firing. Not a defect — the harness was correctly noting the tool is available — but I should have ToolSearch'd it once early to load the schema and silence the reminders (or explicitly note "TaskCreate schema not loaded; using inline progress tracking" once and move on).

## Patterns and Root Causes

**Pattern 1 — Amendment-test scope derives from the user-supplied example, not from the visitor's surface enumeration.**

This is the load-bearing learning. The Thread 2 partial-gap was not a logic error — the implementation worked correctly for the case it covered. It was a *coverage* gap: the visitor's ownership-signal surface has two entry points (parameter-type modifier vs function-decl modifier), but the handoff's example (`consume<T>(_ value: consuming T)`) used the first. I tested only the first.

The visitor's code was visible the whole time. Lines 161–172 of the rule file showed `visit(_ node: FunctionDeclSyntax)` with `for modifier in node.modifiers` — the second entry point. A pre-test enumeration of "what shapes does the visitor flag as ownership-signal?" would have surfaced both entry points and forced tests on each.

This generalizes: **when amending a lint rule (or any AST visitor), enumerate the visitor's processing surface before writing tests. Cover each entry point with at least one case the amendment is supposed to affect AND at least one case the amendment must NOT affect.** Test coverage derived from a single user example is structurally narrower than test coverage derived from the visitor's surface.

The aggregate IS the safety net for this class of gap — running against real code with diverse shapes catches what synthetic tests miss. But the cheap-version of the fix (enumerate-then-test) is strictly cheaper than the expensive-version (ship → aggregate surfaces gap → second amendment commit + tests). Per [REFL-006]'s re-verify-after-edit framing: re-grep the rule's surface for the amendment's signal class, then verify each signal-class instance is covered by a test.

**Pattern 2 — Redirection contract verification before bulk loops.**

The aggregate run was the first time in the session I redirected stdout and stderr separately (the smoke test used `2>&1`). The contract "findings go to stdout, build noise to stderr" was an assumption, not a verified fact. The 2-minute false-alarm cost was tiny, but the pattern generalizes: when a bulk loop's tally depends on stream redirection, ONE iteration with the redirection-as-intended + visual inspection of both streams' contents would have surfaced "findings live in stdout" before the 10-iteration loop ran.

This is a specific case of [REFL-006]'s re-verify-after-edit applied to *the verification mechanism itself*: when the verification command's output-shape changes (combined → split streams), re-verify the contract before relying on it.

**Pattern 3 — User-as-principal expects decision-ready summaries, not fork questions.**

The collaboration protocol's clauses ("challenge implementations" + "no drift" + "complete answers") combined with the user's explicit reject + directive teach: when the user has given directives (even implicit ones like "proceed from the Next Steps section"), further fork-questions are drift-creating. The right shape is:
- Surface comprehensive status (what's done, what's pending, what's blocked).
- Recommend the explicit next action (with reasoning).
- Make space for the user to redirect.

The user's rejection of AskUserQuestion + the directive that followed (Option 1 + Option 1 + reasoning + specifics) IS the canonical principal-tier response pattern. Internalizing that shape: when surfacing status to a user-as-principal, the format is "status / recommendation / await redirect," not "status / multi-option question."

This connects to [HANDOFF-018] (opt-out clauses are preferences, not permissions) — the AskUserQuestion tool is a *permitted mechanism* but its use should match the case-class the tool was designed for (genuinely ambiguous forks where the user hasn't already directed), not the case-class where directives exist.

**Pattern 4 — Honest reporting of partial-completion enables fast corrective dispatch.**

When the aggregate surfaced Thread 2's partial-gap, I had a choice: report it as a residual that "we'll fix next session" OR explicitly call it a Thread 2 amendment that didn't fully close its target. I chose the latter ("Thread 2 partial-gap surfaced by aggregate") and surfaced the follow-up amendment path with specific options. The user immediately authorized the fix.

The pattern: honest "this didn't fully close" reporting + concrete follow-up path with options + cost estimate (`~30 LOC + test`) enables the principal to authorize the fix without a separate dispatch cycle. This is the inverse of report-as-complete-and-hope-no-one-notices, which leaves the gap unaddressed indefinitely.

## Action Items

- [ ] **[memory]** `feedback_amendment_test_surface_enumeration.md` — when amending a lint rule or AST visitor, enumerate the visitor's processing surface (entry points + signal classes) before writing tests; cover each entry point. Provenance: Wave 3 Thread 2 partial-gap, where parameter-shape tests passed but consuming-self modifier-shape on non-generic extended type slipped through. Application: applies to all rule-amendment dispatches.

- [ ] **[memory]** `feedback_decision_ready_summary_over_fork_question.md` — when the user has given directives (explicit or implicit via "proceed from Next Steps"), surface comprehensive status + recommended next action, NOT a multi-option AskUserQuestion. Reserve AskUserQuestion for cases where the user has NOT directed AND the fork is genuinely ambiguous. Provenance: Wave 3 mid-cycle AskUserQuestion reject + principal-tier directive response.

- [ ] **[research]** Visibility-tagged lint pass — extend the lint engine to capture visibility per finding so the fileprivate/private slice can be measured ecosystem-wide. Informs the Thread 4 [API-NAME-002] private-surface decision (currently RECOMMENDATION pending user stamp; empirical follow-up named in the research doc). Target package: swift-foundations/swift-linter.
