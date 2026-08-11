# Architecture Cohort — Day 1 Progress

**Date**: 2026-05-07
**Cohort**: `HANDOFF-swift-linter-architecture-cohort.md`
**Pace**: Round-the-clock, 2-day target / 3-day deadline.

---

## Day 1 Outcome

All Day 1 phases landed. Architecture is feature-complete for the
MVP slice:

- **swift-linter** — engine-only; zero rule deps; the CLI is a
  coordinator that dispatches lint runs to the consumer's `Lint/`
  executable when present, or falls back to the (post-decouple inert)
  single-file `Lint.swift` path.
- **swift-linter-rules** — 11 rule modules (4 carry-forward + 7
  wave-1) consumed directly by consumers' `Lint/Package.swift`.
- **swift-tagged-primitives** — `Lint/` nested package activates all
  11 institute-canonical rules + 1 domain-aware custom rule
  (`Lint.Rule.TaggedDomainAudit`) via CLI dispatch.
- **GH Actions reusable workflow** — drafted at
  `swift-foundations/swift-linter/.github/workflows/lint.yml`;
  committed locally; pushes Day 2 with the rest of the cohort.

---

## Phase Stamps

| Phase | Verification record | Status |
|---|---|---|
| Phase A — PoC of Lint/ nested-package mechanism | `Research/2026-05-07-poc-lint-nested-package.md` | Signed off |
| Phase B.1 — Decouple swift-linter from swift-linter-rules | `Research/2026-05-07-phase-b1-decouple.md` | Signed off |
| Phase B.4 — Migrate wave-1 + ResultBuilder into post-architecture shape | `Research/2026-05-07-phase-b4-wave-1-migration.md` | Signed off |
| GH Actions reusable workflow draft | `.github/workflows/lint.yml` | Shape approved; commit `ada5ff3` |

---

## Per-Rule Baseline on swift-tagged-primitives (CLI dispatch path)

239 findings total. Distribution:

| Rule | Hits | Distribution |
|---|---:|---|
| `unchecked_call_site` (R5) | 27 | 27 Experiments — INVARIANT preserved across PoC + B.1 + B.4 |
| `cardinal_count_minus_one` (R1) | 1 | Experiments |
| `cardinal_zero_one_constructor` (R2) | 0 | Healthy zero |
| `chained_rawvalue_access` (R3) | 7 | Experiments |
| `bitpattern_rawvalue_chain` (R4) | 0 | Healthy zero |
| `result_builder_for_loop` | 0 | tagged-primitives ships no `@resultBuilder` code |
| `try_optional` | 0 | Consistent with `feedback_prefer_typed_throws_over_try_optional.md` |
| `untyped_throws` | 0 | Consistent with [API-ERR-001] |
| `existential_throws` | 0 | No existential throws |
| `var_named_impl` | 0 | Naming discipline observed |
| `option_named_flags` | 0 | No `OptionSet` in surface |
| `compound_identifier` | 175 | 149 Experiments / 22 Tests / 3 Lint / **1 Sources** (see flag below) |
| `tag_suffix` | 10 | 9 Experiments / 1 Tests; Sources/ clean |
| `tagged_unchecked_with_typed_alternative` (custom) | 19 | INVARIANT preserved across PoC + B.1 + B.4 |

**R5 = 27 ✓** and **custom = 19 ✓** preserved end-to-end.

### Flag for cleanup cohort

`compound_identifier` violation at
`Sources/Tagged Primitives Standard Library Integration/Tagged+Sequence.swift:27:17`
— added as Flag 5 in
`/Users/coen/Developer/HANDOFF-swift-linter-code-surface-cleanup.md`.
NOT fixed in this cohort (out of scope per supervisor); fires after the
architecture cohort closes.

---

## Local-Repo Uncommitted State

Per the cohort's no-push-during-execution rule and the supervisor's
"all architecture-cohort commits parked locally" framing, the
following files are accumulated uncommitted in `swift-linter` and
`swift-tagged-primitives` working trees, awaiting per-phase commits
during the Day 2 push-wave:

**swift-linter** (Day 1 source/test edits):
- `Package.swift` — drop swift-linter-rules dep + 11 rule products
- `Sources/Linter Core/Lint.Driver.swift` — empty `defaultConfiguration`; threaded inheritance; doc-comment update
- `Sources/Linter Core/Lint.Rule.BuiltIn.swift` — DELETED
- `Sources/Linter/exports.swift` — drop 11 rule re-exports; keep engine
- `Sources/Linter CLI/Linter CLI.swift` — Lint/-detection branch (Phase A)
- `Tests/Linter Core Tests/Lint.Driver Tests.swift` — 2 tests rewritten + 1 added for post-decouple semantics
- `Research/2026-05-07-poc-lint-nested-package.md` — Phase A record
- `Research/2026-05-07-phase-b1-decouple.md` — Phase B.1 record
- `Research/2026-05-07-phase-b4-wave-1-migration.md` — Phase B.4 record
- `Research/2026-05-07-day-1-progress.md` — this file

**swift-linter** (Day 1 committed):
- `.github/workflows/lint.yml` — `ada5ff3` (workflow draft, supervisor-approved)

**swift-foundations/swift-manifests** (Phase A edits):
- `Sources/Manifest Resolver/Manifest.NestedPackage.swift` — new
- `Tests/Manifest Resolver Tests/Manifest.NestedPackage.Tests.swift` — new

**swift-primitives/swift-tagged-primitives** (Phase A + B.1 + B.4 edits):
- `.gitignore` — `!/Lint/` whitelist
- `Lint/` — entire nested package (Package.swift, Sources/, Tests/)

**swift-institute/Scripts** (Phase A canonical-sync edit):
- `sync-gitignore.sh` — `!/Lint/` whitelist line in canonical block

---

## Day 2 Anticipated Sequence (per supervisor)

1. Morning: supervisor authors Phase B.3 brief (canonical Tier 2 + consumer Lint/ conversion); subordinate executes.
2. Mid-day: Phase B.3 sign-off + Lint/Package.swift URL-based-deps switch + tagged-primitives' `.github/workflows/lint.yml` authoring.
3. Late afternoon: subordinate surfaces push wave authorization moment with all 4 per-action signals (2 `gh repo create`, 1 rename, 1 push wave).
4. Evening: user authorizes; push wave fires; CI runs live on tagged-primitives; verify SARIF surfacing.
5. Day 2 close: cohort terminal stamp; `/reflect-session`.

## Day 3 Buffer

- Phase B.3 partial (carrier-primitives' own Lint/ package + workflow).
- Code-surface cleanup flags (defer if time tight; covered by `HANDOFF-swift-linter-code-surface-cleanup.md`).

## Explicitly Deferred Past Deadline

- **Phase B.2** — full productionization (engine-side plugin
  registration mechanism for restoring single-file `Lint.swift`
  fallback findings). The PoC + B.1 + B.4 demonstrate the mechanism
  end-to-end; full polish is post-deadline.

---

## Status

Day 1 closed. Awaiting Day 2 push-wave authorization moment +
Phase B.3 brief from supervisor.
