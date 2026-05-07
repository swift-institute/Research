---
date: 2026-05-07
session_objective: Execute the swift-linter architecture cohort end-to-end (Phase A PoC + Phase B.1 decouple + Phase B.4 wave-1 migration + GH Actions reusable workflow + push wave)
packages:
  - swift-foundations/swift-linter
  - swift-foundations/swift-linter-rules
  - swift-foundations/swift-manifests
  - swift-foundations/swift-file-system
  - swift-primitives/swift-tagged-primitives
  - swift-primitives/swift-manifest-primitives
  - swift-primitives/swift-path-primitives
  - swift-institute/Scripts
status: processed
processed_date: 2026-05-07
triage_outcomes:
  - type: informational
    target: swift-package
    description: "[PKG-DEP-001] path-form-as-safe-default already-captured during cohort (commit bf63961)"
  - type: package_insight
    target: swift-foundations/swift-linter
    description: "Inert single-file fallback documentation gap recorded in Research/_Package-Insights.md"
  - type: informational
    target: swift-foundations/swift-linter/Research
    description: "canonical-tier-rule-activation-design.md already-captured during cohort"
---

# Swift-linter architecture cohort: PoC + decouple + wave-1 migration + push wave

## What Happened

Single extended session (originally 2-day target / 3-day deadline) closed
the architecture cohort end-to-end in ~1 calendar day. Concretely:

**Phase A — PoC of Lint/ nested-package mechanism** (signed off
pre-compaction; verification record at
`swift-foundations/swift-linter/Research/2026-05-07-poc-lint-nested-package.md`):

- Authored `swift-tagged-primitives/Lint/` SwiftPM package with one
  domain-aware custom rule (`Lint.Rule.TaggedDomainAudit`)
  importing `Tagged_Primitives` to validate the load-bearing
  domain-dep mechanism.
- Added `Manifest.NestedPackage.detect(at:) → Bool` and
  `dispatch(at:arguments:) → Int32` in
  `swift-foundations/swift-manifests/Sources/Manifest Resolver/`.
- Added `Lint.Driver.dispatchNestedIfPresent(...)` plus a
  Lint/-detection branch in `Linter CLI/Linter CLI.swift` so
  swift-linter (CLI) dispatches the run to the consumer's Lint/
  executable when present, falling back to the single-file
  `Lint.swift` chain-resolution flow otherwise.
- Mid-execution I escalated a constraint refinement
  (`Option 1 dispatch architecture: CLI = coordinator; Lint/ exec
  = linter binary for the consumer`) that the supervisor approved.
- Pre-compaction also: `327-repo .gitignore over-propagation`
  caught and reverted (only swift-tagged-primitives kept the
  `!/Lint/` whitelist; canonical-sync edit landed in
  `swift-institute/Scripts/sync-gitignore.sh` for future
  ecosystem-wide propagation as its own dispatch).

**Phase B.1 — decouple swift-linter from swift-linter-rules**
(verification record at
`swift-foundations/swift-linter/Research/2026-05-07-phase-b1-decouple.md`):

- Dropped `swift-linter-rules` package dep + 11 `Linter Rule X`
  product references from swift-linter's `Linter Core` and `Linter`
  umbrella targets.
- Removed `Sources/Linter Core/Lint.Rule.BuiltIn.swift` (the
  `Lint.Rule.builtIn` static array was the engine's last
  rule-knowledge; engine ships zero rules now).
- Simplified `Lint.Driver.defaultConfiguration()` and
  `configuration(from:parent:)` to thread inheritance + excluded
  paths only.
- Rewrote 2 tests in `Lint.Driver Tests.swift` that assumed
  engine-side rule registration; added 1 for `disabledRuleIDs`
  symmetry. 6/6 pass.

**Phase B.4 — wave-1 + ResultBuilder migration** (verification
record at `swift-foundations/swift-linter/Research/2026-05-07-phase-b4-wave-1-migration.md`):

- Updated `swift-tagged-primitives/Lint/Package.swift` and
  `Lint/Sources/Lint/main.swift` to wire 8 rule packs (the missing
  carry-forward `ResultBuilder` plus 7 wave-1 rules) explicitly.
  All 11 institute rules + 1 custom rule now activate via the Lint/
  shape.
- Per-rule baseline on tagged-primitives: 239 findings total. R5 = 27
  (invariant preserved), custom = 19 (invariant preserved), R3 = 7,
  R1 = 1, `compound_identifier` = 175 (149 Experiments + 22 Tests +
  3 Lint + **1 production source hit** at
  `Sources/Tagged Primitives Standard Library Integration/Tagged+Sequence.swift:27:17`),
  `tag_suffix` = 10, all other wave-1 = 0.
- The 1 production `compound_identifier` hit became Flag 5 in
  `HANDOFF-swift-linter-code-surface-cleanup.md`.

**GH Actions infrastructure**:

- Drafted reusable workflow at
  `swift-foundations/swift-linter/.github/workflows/lint.yml`
  (workflow_call with 4 inputs; harden-runner audit-mode;
  per-job permissions; `if: !github.event.repository.private`).
- Drafted consumer workflow at
  `swift-tagged-primitives/.github/workflows/lint.yml`.

**URL-vs-path-deps decision reversal**:

- Day 2 supervisor brief initially specified URL-based deps in
  Lint/Package.swift to enable runner clone-and-build resolution.
- I committed the URL-form (`f4968e6`) before the user surfaced the
  visibility correction: NEW repos ship PRIVATE not PUBLIC.
  URL-form deps cannot resolve at CI runtime against private repos
  without auth tokens.
- Reset the commit (`git reset HEAD~1` — local-only, not pushed),
  reverted Lint/Package.swift to path-based deps, re-committed as
  `f3b8b27` with corrected message documenting the deferral.

**Push wave — 8 repos in dep order**:

| # | Repo | Visibility | origin/main HEAD |
|---|---|---|---|
| 1 | `swift-primitives/swift-manifest-primitives` | PRIVATE (newly created) | `2073da6` |
| 2 | `swift-foundations/swift-linter-rules` | PRIVATE (newly created) | `41c3b78` |
| 3 | `swift-foundations/swift-manifests` | (web-UI rename from `swift-manifest`) | `d07fdc2` |
| 4 | `swift-foundations/swift-linter` | unchanged | `7691f0f` |
| 5 | `swift-primitives/swift-path-primitives` | unchanged | `f6d1ecb` |
| 6 | `swift-foundations/swift-file-system` | unchanged | `98667da` |
| 7 | `swift-primitives/swift-tagged-primitives` | unchanged | `f3b8b27` |
| 8 | `swift-institute/Scripts` | unchanged | `fe4733c` |

Per-push verification: HEAD == origin/main on each. No tags
created. Pre-existing dirty `.swift-format` file in path-primitives
left untouched (outside cohort scope).

**Cohort terminal stamp** landed in
`/Users/coen/Developer/HANDOFF-swift-linter-architecture-cohort.md`
documenting: phases A/B.1/B.4 complete; B.3 + B.2 deferred with
rationale; GH Actions live-test deferred with three concrete
resolution paths; carry-forward to subsequent dispatches (5 cleanup
flags, B.2 productionization, wave-2 encoding, etc.).

**HANDOFF triage** — workspace-root scan: 41 HANDOFF-*.md files
present.

| File | Authority | Disposition |
|---|---|---|
| `HANDOFF-swift-linter-architecture-cohort.md` | this-session (terminal stamped) | DELETE — all phases complete or deferred-with-rationale; cohort closed |
| `HANDOFF-architecture-poc-lint-nested-package.md` | this-session (Phase A predecessor of architecture cohort) | DELETE — Phase A signed off; verification record at swift-linter/Research/ supersedes |
| `HANDOFF-swift-linter-code-surface-cleanup.md` | this-session (Flag 5 added) | ANNOTATE-AND-LEAVE — STAGED for post-cohort dispatch; cohort just closed; file is now ready-to-fire |
| `HANDOFF-swift-linter-modularization-cohort.md` | encountered as predecessor (out of authority) | leave unchanged |
| `HANDOFF-swift-linter-ai-harness-mission.md` | strategic mission frame (reference, not worked) | leave unchanged |
| 36 other handoffs at workspace root | out of cohort authority | leave unchanged |

## What Worked and What Didn't

**Worked**:

- Round-the-clock pace landed Phase A + B.1 + B.4 + GH Actions in a
  single arc. Each phase had a focused verification record; the
  baseline R5=27 + custom=19 invariants held end-to-end across the
  three engine-touching phases. Acceptance gates were named clearly
  and verified at each phase boundary.
- The Option 1 dispatch refinement (escalated mid-Phase-A and
  approved by supervisor) made the rest of the cohort coherent. The
  architectural endpoint — engine = engine, rules = rule packs,
  consumer = orchestrates both via Lint/ — was clean enough that
  Phase B.1 dropped 11 product deps + the entire `Lint.Rule.builtIn`
  static array without tortured migration code.
- Push-wave execution: 4-signal explicit per-action authorization
  pattern (2 gh repo create, 1 web-UI rename, 1 push wave) made
  every irreversible action explicitly authorized. No accidents.
  Per-push HEAD verification gave fast confirmation of success.

**Didn't work / friction**:

- **URL-vs-path-deps decision came late.** I committed `f4968e6`
  with URL-based deps before the visibility correction surfaced.
  The reset+revert+recommit cycle cost a commit and a few minutes
  of subordinate-supervisor chat. The visibility decision (public
  vs private) determines whether URL-form deps can resolve at CI
  runtime; it should be locked in BEFORE switching to URL form.
  Default-to-path-based until visibility is finalized would have
  prevented the cycle.
- **Multi-repo commit batching.** I bundled multiple phases (A +
  B.1 + B.4 + Day 1 progress) into a single commit per repo. The
  swift-linter history convention is one commit per phase; I chose
  bundled commits because Lint.Driver.swift's edits straddle Phase
  A and B.1 and splitting via `git add -p` was felt to be more
  error-prone than a structured commit message enumerating each
  phase's contribution. The bundled commits are clear in retrospect
  but the per-phase convention is sharper for `git log` archaeology.
- **Pre-compaction context loss.** This session continued from a
  pre-compaction context where Phase A was already signed off.
  Some intermediate artifacts (the 327-repo over-propagation revert
  and the constraint refinement escalation) were lost from
  conversation but recoverable from the verification record.

## Patterns and Root Causes

**Path-form-as-safe-default for cross-repo SwiftPM deps.** The
URL-vs-path decision is two questions wearing one hat: "what does
local development resolve against?" and "what does CI resolve
against?". Path-form is the safe default until cross-repo visibility
is locked in. URL-form bakes in three assumptions — public-or-CI-
auth-token, branch-or-tag pinning policy, and willingness to live
with a separate clone in `.build/checkouts/`. Committing URL-form
before any of those is finalized invites the reset cycle I executed.
The pattern: **prove the deployment story before authoring the
deployment-shape commit.** Path-based commit + workflow draft +
visibility decision converging in that order is the right shape.

**Architectural-endpoint-first phasing.** The cohort's strength was
that the endpoint (CLI = coordinator; consumer's Lint/ = linter
binary) was clear before any phase fired. Phase A demonstrated the
mechanism; Phase B.1 reduced the engine to the mechanism's needs;
Phase B.4 broadened the consumer's activation surface. Each phase
was a no-op-or-strict-reduction at the engine layer (B.1 dropped
deps; B.4 was tagged-primitives only). The R5=27 invariant held
end-to-end because no phase touched the engine's rule-evaluation
machinery — they only changed who registered rules and where.

**Inert single-file fallback as documented behavior change.** Phase
B.1 left the single-file `Lint.swift` path inert (zero findings)
until consumer-side rule registration is restored. This is a real
behavior change for any consumer using the single-file form; the
migration path (Lint/Package.swift shape) is documented but not
self-evident from the code. Future single-file consumers will see
unexpected zero findings and need a doc breadcrumb pointing them at
the migration. The README + Documentation.docc don't yet cover this.

**Multi-signal cohort-terminal authorization.** The 4-signal
authorization pattern (2 gh repo create + 1 web-UI rename + 1 push
wave) handles the case where a single bundled push includes
irreversible cross-repo state changes (visibility flips,
admin-class operations, multi-repo branch updates). Each signal
maps to one orchestrator step; the user authorizes per-step rather
than per-bundle. The pattern generalizes the per-action
`feedback_no_public_or_tag_without_explicit_yes` discipline to
multi-step cohort-terminal moments.

**Predecessor handoff hygiene.** The `HANDOFF-architecture-poc-lint-nested-package.md`
file (Phase A brief) survived through cohort execution despite
the architecture-cohort orchestrator's "Phase A signed off"
documentation. The cohort dispatch metadata listed it as predecessor
but didn't trigger its deletion. [REFL-009] in-session triage at
cohort-terminal time catches this — the handoff is now scheduled for
deletion. Generalization: cohort orchestrators should explicitly
list their predecessor briefs as deletion targets at cohort terminal,
not just as historical references.

## Action Items

- [ ] **[skill]** swift-package or platform: Add a rule for cross-repo SwiftPM dep visibility. Default to **path-based** deps until cross-repo visibility is finalized; URL-based deps assume CI-resolvable (public, OR private + auth tokens in runner, OR workflow refactor to multi-repo checkout). Committing URL-form before visibility is locked invites reset+revert. Per 2026-05-07 architecture cohort Day 2 reset of `f4968e6`.

- [ ] **[package]** swift-linter: Document the post-Phase-B.1 inert single-file `Lint.swift` fallback path in README and `Documentation.docc/`. Migration path is `Lint/Package.swift` shape (consumer enumerates rule TYPES + activates per manifest enabledRuleIDs). Without this breadcrumb, future single-file consumers will see unexpected zero findings.

- [ ] **[research]** Canonical-tier rule activation cascade: when Tier 1 (`swift-institute/.github/Lint.swift`) and Tier 2 (`swift-primitives/.github/Lint.swift`) eventually activate rules, what's the shape — single-file with default rule-pack umbrella import, OR Lint/ packages with their own enabledRuleIDs, OR delegate to a shared `Lint.Rule.Configuration.defaults` factory? The Phase B.4 consumer pattern works at the leaf; the canonical chain needs its own design (currently deferred per Phase B.3).
