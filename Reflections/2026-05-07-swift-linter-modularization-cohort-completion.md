---
date: 2026-05-07
session_objective: Execute the swift-linter post-Phase-2 modularization cohort end-to-end (Phase 3a Manifest.Resolver extraction → Phase 2.5b sanitize/tempPath ecosystem promotion → Phase 3 swift-linter-rules package extraction → Phase 4 wave-1 AI-harness rule encoding); stamp cohort terminal; close cleanly.
packages:
  - swift-foundations/swift-linter
  - swift-foundations/swift-linter-rules
  - swift-foundations/swift-manifests
  - swift-foundations/swift-file-system
  - swift-primitives/swift-manifest-primitives
  - swift-primitives/swift-path-primitives
status: pending
---

# swift-linter Modularization Cohort Completion — 4 Phases, 12 Commits, 6 Repos

## What Happened

Single-chat orchestrated cohort against the swift-linter post-Phase-2
maturation document (`HANDOFF-swift-linter-modularization-cohort.md`).
Four sequential execution phases, supervisor sign-off between each,
R5 27-hit invariant on swift-tagged-primitives as the load-bearing
observable preserved at every phase boundary.

**Phases executed**:

- **Phase 3a — Manifest.Resolver extraction (Option A)**: NEW L1
  `swift-manifest-primitives` (Manifest namespace + `Manifest.Configuration`
  + `Manifest.Dependency` + `Manifest.Parent.scan(in:)` parent-directive
  parser). RENAMED `swift-manifest` → `swift-manifests` with multi-module
  restructure (`Manifest Loader` + `Manifest Resolver` — generic
  `Manifest.Resolver<M: JSON.Serializable, C>` chain-resolution machinery).
  `Lint.Driver` thinned 676 → 250 lines. Brief had ADDENDUM superseding
  original Option C with Option A; user added strict /code-surface compliance
  directive mid-phase. R5 = 27 preserved.

- **Phase 2.5b — sanitize/tempPath ecosystem promotion**: 
  `Path.sanitized(from:)` lifted into `swift-path-primitives` (L1);
  `File.Path.Temporary.deterministic(prefix:key:suffix:)` lifted into
  `swift-file-system` (L3). Migrated BOTH consumer copies: Lint.Driver
  AND Manifest.Resolver (Phase 3a's Option A had inadvertently
  duplicated sanitize/tempPath helpers across both packages — the brief
  assumed ONE migration site, scope expansion caught + executed).
  `Lint.Driver` thinned 250 → 210 lines. R5 = 27 preserved.

- **Phase 3 — swift-linter-rules package extraction**: NEW L3
  package; 4 carry-forward rule targets lifted verbatim from swift-linter
  (Cardinal, RawValue, ResultBuilder, Unchecked); swift-linter consumes
  via local-path dep with re-routed product references. Cross-repo
  `mv` (history doesn't transfer natively across repos — known
  extraction cost, accepted per ground rule #4 pure-structural scope).
  103 tests in 45 suites pass. R5 = 27 preserved.

- **Phase 4 — Wave-1 AI-harness rule encoding**: 7 new rules
  (`try_optional`, `untyped_throws`, `existential_throws`,
  `var_named_impl`, `option_named_flags`, `compound_identifier`,
  `tag_suffix`), each citing skill-ID or feedback-memory in BOTH
  doc-comment header AND emitted diagnostic message text
  (`"[<rule_id>] <citation>: …"` format). One target per rule, ≥5
  positive + ≥3 negative tests per rule (82 new tests; 185 total in
  87 suites). Integration smoke fixture (`Tests/Fixtures/wave-1-violations.swift`)
  fires exactly 7 diagnostics, one per wave-1 rule. R5 = 27 preserved.

**Commits**: 12 across 6 repos.

| Repo | Cohort commits |
|---|---:|
| swift-foundations/swift-linter | 4 |
| swift-foundations/swift-linter-rules | 3 |
| swift-foundations/swift-manifests | 2 |
| swift-primitives/swift-manifest-primitives | 1 |
| swift-primitives/swift-path-primitives | 1 |
| swift-foundations/swift-file-system | 1 |

**Mid-cohort architecture pivot identified by parent-supervisor + user**
(NOT executed in this cohort, captured as next cohort's scope):
swift-linter NOT depending on swift-linter-rules (engine + sibling
rule packs); Lint.swift as a nested SwiftPM package (`Lint/Package.swift`);
Path B uniform tier model. The wave-1 rules will migrate
mechanically (not destructively) during the architecture cohort — rule
predicates are architecture-independent.

**Deferred per-action authorizations** (8a `gh repo create`, 8b
GitHub web UI rename `swift-manifest` → `swift-manifests`, 8c bundled
push wave) carry forward to the architecture cohort's terminal per
parent-supervisor direction. Local commits across 6 repos parked.

**HANDOFF scan**: 6 cohort-related files at workspace root + 32 unrelated.

| File | Disposition | Reason |
|---|---|---|
| `HANDOFF-swift-linter-modularization-cohort.md` | Annotated-and-left | Cohort terminal stamp added at session end (✓ all 4 phases verified + deferred-authorizations explicitly carried forward); reference document for the architecture cohort. |
| `HANDOFF-manifest-resolver-extraction.md` | Annotated-and-left | Phase 3a brief executed; verification record at `swift-foundations/swift-manifests/Research/2026-05-06-r5-27-hit-extraction.md`. Closure annotation added. |
| `HANDOFF-sanitize-temppath-ecosystem-promotion.md` | Annotated-and-left | Phase 2.5b brief executed; verification record at `swift-foundations/swift-linter/Research/2026-05-07-phase-2-5b-cohort-gate.md`. Closure annotation added. |
| `HANDOFF-swift-linter-rules-package-extraction.md` | Annotated-and-left | Phase 3 brief executed; verification record at `swift-foundations/swift-linter-rules/Research/2026-05-07-r5-27-hit-extraction.md`. Closure annotation added. |
| `HANDOFF-swift-linter-rules-wave-1-encoding.md` | Annotated-and-left | Phase 4 brief executed; verification record at `swift-foundations/swift-linter-rules/Research/2026-05-07-wave-1-encoding-verification.md`. Closure annotation added. |
| `HANDOFF-swift-linter-ai-harness-mission.md` | Out-of-session-scope (not retired) | Strategic mission frame; explicitly retained per the wave-1 brief ("Not retired. Parent strategic frame; remains authoritative."). Wave 2/3 future work depends on it. Not in this session's cleanup authority. |

The 32 unrelated handoffs are out-of-session-scope (not in this
session's cleanup authority per [REFL-009] bounded authority + not
encountered as a side effect of cohort work).

## What Worked and What Didn't

**Worked well**:

- **Sequential phase execution + per-phase supervisor sign-off**:
  the rhythm — execute → report → wait for sign-off → next phase —
  caught structural drift early (the Phase 2.5b scope expansion
  identifying the helper duplication in BOTH Lint.Driver and
  Manifest.Resolver) and let the user inject ADDENDUM corrections
  (Option C → Option A in Phase 3a) without forcing a re-handoff.
  Pattern works for cohorts where phases are genuinely sequential
  (each one depends on the previous one's outputs).
- **R5 27-hit invariant as the load-bearing gate**: a single,
  cheap, deterministic command (`grep -c "unchecked_call_site"`)
  preserved through 4+ phase boundaries. Made every refactor's
  acceptance check trivially verifiable. The invariant's stability
  across pure-structural phases (extraction, helper promotion, rule
  module split) confirmed the changes were genuinely structural.
- **Verification records as durable artifacts**: each phase wrote
  a verification record at `<package>/Research/YYYY-MM-DD-<slug>.md`
  capturing acceptance-criteria evidence + supervisor ground-rules
  status. The record outlives the HANDOFF brief (which is ephemeral).
- **Educational diagnostic discipline**: each wave-1 rule's
  doc-comment header AND emitted diagnostic message cite the source
  skill-ID or feedback-memory verbatim. Past-failure-mode context
  (e.g., `try_optional` cites the IO Notification.wait() Linux
  hot-spin incident from `feedback_prefer_typed_throws_over_try_optional`)
  threaded into messages — exactly the AI-harness mission's intent.
  Supervisor sign-off explicitly called out "Strong work" on this
  axis.
- **Internal-import-SwiftSyntax for new wave-1 rules**: cleaner
  pattern than the carry-forward `public import SwiftSyntax` — since
  SwiftSyntax types appear only inside the internal `Visitor` class
  body, never in public API. Picked this up by reading the build
  warnings on first compile and deciding to set the right precedent
  for the new rules rather than match the carry-forward warning.
- **One-rule-per-target shape from the brief**: each wave-1 rule
  in its own SPM target/library/test target. Future activation can
  be per-rule with narrow product imports (per
  `feedback_fine_grained_modularization`).

**Didn't work / required fixing mid-execution**:

- **Phase 3a hardcoded "Lint.swift" leak**: generic
  `Manifest.Resolver<M, C>.evalParent(...)` carried a hardcoded
  string `"Lint.swift"` as the manifest filename, leaking
  lint-specific knowledge into the supposedly generic resolver.
  Caught during AC#5 verification via
  `grep -rn "Lint\." swift-manifests/Sources/`. Fixed by threading
  `manifestFilename: Swift.String` through `walk(...)` + `evalParent(...)`.
  Lesson: when extracting a generic from a specific, the extraction
  must include parameterizing every concrete reference, not only
  the obvious type-level ones.
- **`rethrows` accidentally flagged by `Lint.Rule.UntypedThrows`**:
  initial encoding visited `ThrowsClauseSyntax` and emitted on
  `node.type == nil`. SwiftSyntax models `rethrows` as a
  `ThrowsClauseSyntax` with `throwsSpecifier.tokenKind ==
  .keyword(.rethrows)`. Fixed during isolation testing by guarding
  on `throwsSpecifier.tokenKind == .keyword(.throws)`. The
  `rethrows`-not-flagged invariant is now captured by a regression
  test in the rule's edge-case suite.
- **Compound-identifier rule fired twice on integration fixture**:
  initial fixture had `func bareThrows() throws -> Int { 0 }` for
  the `untyped_throws` test case, but `bareThrows` IS itself a
  compound identifier (`bare` + `Throws`) which `compound_identifier`
  also fires on. Smoke run produced 8 diagnostics where 7 were
  expected. Renamed to `func bare()` so each fixture function
  illustrates exactly one rule's violation. Lesson: integration
  fixtures need *minimum one violation per rule*, not arbitrary
  syntax that may incidentally trigger other rules.
- **The user reminder about [API-NAME-001a]**: when authoring
  `File.Path.Temporary.deterministic(...)`, I had to re-read
  [API-NAME-001a] carefully — the `Temporary` namespace contains
  only one method today, but `Temporary` IS the variant label
  ("Temporary kind of File.Path"). The Decision-test came out as
  "Temporary" being a real namespace (other temporary-related
  helpers may join later: `Temporary.directory`, `Temporary.unique`),
  not just a single-type variant. This kind of judgement call needs
  explicit decision-test scoring at authoring time to avoid drift
  later.

**Process friction**:

- **Cross-repo `git mv` history-loss tradeoff (Phase 3)**: cross-repo
  moves don't preserve git history natively (it's `mv` + `git add`
  in destination + `git rm` in source). The brief's "git mv" phrasing
  read as "move" rather than literal cross-repo history preservation.
  Rule predicate history remains queryable via `git log` on the
  original swift-linter repo's pre-extraction commits. Accepted
  cost per ground rule #4 (pure-structural scope, no edits to rule
  predicates).
- **MEMORY.md truncation warning**: the auto-memory MEMORY.md is
  221 lines / 36.6KB and only part loaded into context this session.
  Memory-discovery on the long tail required directory listing rather
  than purely index-driven recall. Index entries were under the
  ~150-char limit but the *count* of feedback memories has grown
  past comfortable load-into-context size.

## Patterns and Root Causes

**The cohort orchestration pattern was a single-chat-multi-phase
shape (Pattern B per [SUPER-023])**. It worked because:

1. **Phases were genuinely sequential by construction** — each
   phase's output (a refactored package shape, a thinned driver, a
   new package) was consumed by the next phase. There was no false
   serialization of independent work; the strict ordering reflected
   real dependencies.
2. **R5 27-hit gate amortized sign-off cost** — a one-line
   verification (`grep -c`) made each gate cheap. With a more
   expensive observable (e.g., a test suite that takes 30s), the
   per-phase round-trip would have been costly enough to push toward
   batched sign-off.
3. **Phase boundaries were where the user could reasonably inject
   corrections** — the Option-A ADDENDUM landed at the Phase 3a
   start, not mid-phase. Sign-off-between-phases gave the user a
   natural moment to adjust scope without re-handing-off mid-flight.
4. **The orchestration document was the durable spine** — phase
   briefs are ephemeral (consumed and closed), the orchestration
   doc captures the cohort's terminal stamp + carry-forward state
   (deferred authorizations).

**The architecture-pivot-deferred discipline is a critical lesson**.
Mid-cohort, the parent-supervisor and user identified an architecture
pivot that affects swift-linter's package coupling and the Lint.swift
mechanism. The pivot did NOT enter this cohort's execution scope.
Rationale: this cohort is committed to a defined architecture; pivoting
mid-cohort would have invalidated already-landed phase verifications
and forced re-work. Deferring the pivot to a separate "architecture
cohort" preserves the work landed here (mechanically migratable,
not destructively reworked) and isolates the pivot's risk to its own
cohort. This is **scope discipline at the cohort layer**, distinct
from per-phase scope discipline. The principle: when an architecture
insight surfaces mid-cohort, capture it in the cohort's terminal
stamp (carry-forward state) rather than execute it inline.

**Three reusable defect-detection patterns surfaced during the cohort**:

1. **Helper-duplication-after-extraction**: when a package extraction
   moves a generic component, helpers that were single-source in
   the pre-extraction package may end up duplicated across the
   extracted-and-original packages. Detection: grep for the helper
   function name across both packages after extraction. Phase 2.5b
   caught `sanitize` + `tempPath` existing in BOTH `Lint.Driver`
   AND `Manifest.Resolver` after Phase 3a; one ecosystem-promotion
   pass migrated both to the right L1/L3 home.
2. **Concrete-string-leak-in-generic**: when a generic is extracted
   from a specific, every concrete reference must be parameterized
   — not just the obvious type-level ones. The `"Lint.swift"`
   string in `Manifest.Resolver.evalParent(...)` was a generic
   leak caught only by `grep -rn "Lint\." swift-manifests/Sources/`.
   The detection pattern is "grep the destination package for any
   identifier that mentions the source package's domain."
3. **AST tokenKind discriminator under generic syntax types**:
   SwiftSyntax models multiple keyword-effects (`throws`, `rethrows`)
   under a single syntax type (`ThrowsClauseSyntax`). Rules that
   target one specific keyword must discriminate on
   `tokenKind == .keyword(.<specific>)`, not just visit the
   syntax type. The defect mode is silent — the rule appears to
   work but fires on the wrong keyword.

**The educational-diagnostic message format
(`"[<rule_id>] <citation>: <description>"`) is a wave-1 protocol
that's worth promoting to skill-level guidance**. It satisfies:
(a) the rule ID appears in the message text (independent of reporter
format envelope), so AI agents reading text-format output get the
identity even if the reporter changes; (b) the citation appears
adjacent to the description, so the institutional source is visible
at the diagnostic site, not just in the rule's source code; (c) the
description teaches the institutional reasoning, not just states
the predicate. This is the educational-diagnostic discipline applied
at the message-text layer — minimal AI-targeted hook before the P5
reporter format lands.

## Action Items

- [ ] **[skill]** code-surface: Add `[API-NAME-XXX]` "Educational
  diagnostic message format" — when a diagnostic-emitting rule cites
  an institutional source, the message text MUST follow
  `"[<rule_id>] <citation>: <description>"`. The rule ID + citation
  appear at the message-text layer (not just the reporter envelope)
  so AI agents and human readers see institutional identity at the
  diagnostic site regardless of reporter format. Provenance: this
  reflection's "What Worked" + "Patterns and Root Causes" sections.
- [ ] **[research]** Generalize the three defect-detection patterns
  from this cohort (helper-duplication-after-extraction;
  concrete-string-leak-in-generic; AST-tokenKind-discriminator-under-
  generic-syntax-type) into a "package-extraction defect catalog"
  research doc at `swift-institute/Research/`. Each pattern: detection
  procedure (grep recipe / test design), past instance(s), false-
  positive avoidance. Audience: future cohort orchestrators executing
  similar pure-structural extractions.
- [ ] **[package]** swift-foundations/swift-linter-rules: Document
  in `Research/_Package-Insights.md` (or a wave-2-prep note) the
  rule-target-naming tension between [API-NAME-001] (no compound type
  names) and the brief's "one target per rule" shape — the carry-
  forward pattern (`Linter Rule Cardinal` target with multiple
  `Cardinal.X` rules) and the wave-1 pattern (one target per flat-
  named rule like `Lint.Rule.TryOptional`) coexist; the architecture
  cohort may want to revisit the naming shape when rule packs become
  sibling packages.
