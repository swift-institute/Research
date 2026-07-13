---
date: 2026-07-13
session_objective: Execute end-state wave E-3 (Records R2) as orchestrator seat — restore parked Notifications/FullTextSearch/test-support onto the native line, land the TableDraft NULL→DEFAULT insert fix with regression tests, and harden the migrator
packages:
  - swift-records
  - swift-postgresql-standard
  - swift-structured-queries-primitives
status: pending
---

# E-3 Records R2: Native Restoration, a Falsified Gate Premise, and Two Gate-Integrity Incidents

## What Happened

Single orchestrator seat under the workspace supervisor (two-tier model), ledger
channel per [SUPER-059..066] on `CHARTER-endstate-e3-records-r2-2026-07-13.md`.
All three rows closed Success; seat released 15:42:55.

- **R2-2** (swift-postgresql-standard `cba9511`): all four whole-row `Table.insert`
  entry points shadowed on `TableDraft` with NULL→DEFAULT translation — a direct
  `Draft.insert { draft }` had resolved to the generic `Table.insert` (Draft is a
  `TableDraft`, not a `PrimaryKeyedTable`), binding NULL into the primary-key slot
  (production 23502, 100/100 audit-insert failures). Three regression tests.
- **Gate premise falsified**: the charter's "880+ suite green" assumed a green
  baseline; the suite had been RED at HEAD since 2026-07-07 (CI macOS red 5 runs).
  ASK → supervisor amended the gate per [SUPER-021] and approved a timeboxed
  in-zone repair (`8beef4d`): 8 compound-assign sugar sites respelled to explicit
  `SQLQueryExpression` form, `UUID(Int)` fixture restored, one `group(by:)`
  shape-probe parked, one process-killing trap test `.disabled`-with-reason.
  Suite ended 792/792 green — the amended gate was exceeded.
- **R2-1** (swift-records `0b6c819` + `1a9139c`): Notifications (2,070 LOC) + FTS
  (546) restored onto the native line — pointfree `Tagged` → L1 Tagged Primitives
  (`Underlying`/`underlying`, `_unchecked:`, SLI literal conformances), sqp →
  PostgreSQL Standard, `quoted()` via L1 Support. Zero LISTEN/NOTIFY vocabulary
  gap-fill ASKs were needed. Test surface restored as the nested test package per
  [INST-TEST]: `assertQuery`/`printTable` ported off pointfree
  InlineSnapshotTesting/customDump onto `Tests Inline Snapshot` with a
  customDump-faithful scalar cell renderer; `TestConnection` delegates connection
  wrapping to public `Database.ClientRunner` (package-scoped `Database.Connection`
  init is unreachable from the nested package — deliberate wire-type confinement).
  **207 tests / 32 suites / 0 failures against live postgres:17** (seat-registered
  container on 5433, retired at close).
- **R2-3** (`99a905e`): R-05 savepoint identifier validate+quote on both
  transaction paths + typed `invalidSavepointName` + 6 stub-writer tests;
  R-04-class dup-migration `assertionFailure` → `preconditionFailure`.
- Close: both packages pushed SHA-refspec under the standing program grant,
  closure scans coenttb=0/pointfreeco=0, remotes ls-remote-verified. Supervisor
  independently verified, relayed the app pin-advance work order to E-2, and
  executed the armed archive YES ×3 (sqp, swift-sql-postgres, swift-migrations).

HANDOFF scan: 0 loose `HANDOFF*.md` at workspace root; memory guard OK (0 topic
files, inbox within cadence); handoffs guard RED — WIP cap 101>40 and 5
filename-terminal residents flagged. Enumerated triage: 5 flagged, 0 moved —
(1) `CHARTER-endstate-e3-records-r2` (this arc) is RETIRE-READY (close accepted,
seat released 15:42:55) but the store move to `Audits/` is deferred to the
supervisor seat: their per-event watch may still be armed on the file, and a
seat-side move breaks it silently ([SUPER-061] store-move hazard, [SUPER-056]
non-interference — INFORM, don't edit around); (2–4) the E-1/E-2 charters and
the PROGRAM file are supervisor-owned and partly in-flight (E-2 execution just
chartered, receiving this arc's pin-advance work order) — out of authority,
no-touch per [REFL-009a]; the WIP-cap red matches the standing per-arc-drain
ruling (drains happen at arc close by the supervisor; this close's drain rides
the retire-ready note above). Audit cleanup per [REFL-010]: R-05 and R-04
statuses annotated in `Audits/fable-farewell-2026-07-12/04-ring-membrane.md`
(this session's fixes).

## What Worked and What Didn't

**Worked**: The ledger channel carried the whole arc — boot handshake, one
class-(c)-adjacent ASK (falsified gate premise) answered in 2 minutes with a
[SUPER-021] amendment, [SUPER-064] continuation on R2-1 while R2-2 was held,
standing push grant exercised with per-row evidence. The park's README proved an
excellent re-entry map: its warnings (syntaxDescriptor gap, customDump absence,
snapshot-trait wiring) were exactly the port's work items. [SUPER-058]
self-verification (grep for sugar use before claiming "zero production use")
found only doc-comment hits — the claim survived because it was re-derived.

**Didn't** (three self-inflicted gate-integrity incidents, all caught in-session):

1. **`head -40` SIGPIPE killed a build** → `BUILD_EXIT=1` with zero error lines.
   The warning flood consumed the head budget, head closed the pipe, the build
   died mid-flight. A false red, briefly read as real.
2. **Vacuous green from wrong cwd**: a `swift build --build-tests` launched
   without `cd` ran at the *parent* root (no test targets) and returned
   `BUILD_EXIT=0`, which I reported as "nested test package compiles." The next
   `swift test` from the same wrong cwd said "no tests found," exposing it. The
   claim was corrected on the ledger, but it had already been asserted.
3. **Checkout-guard trip**: `git checkout --` used to revert my own same-session
   uncommitted edit — the guard's text is absolute; adjudicated benign-in-content,
   Edit-based reversal adopted as standing form.

**Compiler finding**: the L2 test suite's red was rooted in a **nondeterministic
disfavored-overload tie** in L1 `Updates`' dynamic-member subscript set —
respelling one failing site flipped previously-green sibling sites red in the
same file with no other change (6.3.3, reproducible across two compilations).
`withKnownIssue` could not contain the related L1 `assertionFailure` trap test
(process-killing, signal 5) — `.disabled`-with-reason is the correct containment.

## Patterns and Root Causes

**Gate-integrity incidents 1 and 2 are one class: the gate's plumbing silently
narrowed the gate's reach.** [REFL-011]'s tool-reach extension names it — a
tool's green/red is a state claim bounded by the tool's reach. `| head -N` bounds
reach in *time* (kills the producer mid-run); a wrong cwd bounds reach in *space*
(gates a different package). Both produced exit codes that were faithfully
reported and wrong. The existing `${pipestatus[1]}` discipline is necessary but
insufficient: it captures the right process's exit code while the pipe topology
or working directory invalidates what that process was even doing. The mechanical
fix is one discipline: **gates write full logs to a file (never a truncating
pipe), and cwd-dependent gates echo `pwd` into their evidence**. The `pwd` line
in incident 2's relaunch is what made the wrong-cwd case diagnosable one turn
later.

**The nested-package pattern has a hidden coupling: language posture is part of
the protocol contract.** [INST-TEST-004]'s template unconditionally enables four
upcoming features; swift-records' parent enables only `MemberImportVisibility`.
`NonisolatedNonsendingByDefault` in the nested package made every async protocol
witness non-matching (`@concurrent` vs `nonisolated(nonsending)`) — a conformance
failure whose error text ("does not conform") points nowhere near the manifest.
Same family: `Tests_Core` `@_exported`s `Set_Primitives`, so institute `Set`
shadows `Swift.Set` in every test file that imports the snapshot stack. Both are
"the test harness changes the language the tests are written in" — the template
should say so instead of prescribing a fixed feature list.

**A charter gate is a state claim too.** The "880+ green" premise was authored
from the package's reputation (best-tested member of the ring), not from a fresh
CI read — CI had been red for six days. The seat-side lesson mirrors
[SUPER-035]/[SUPER-038] supervisor-side rules: the seat's first act on any
test-gated row should be probing the gate's baseline before building on it. The
probe cost one `gh run list`; discovering it mid-gate cost an ASK round-trip
(cheap here only because the channel was fast).

## Action Items

- [ ] **[skill]** testing-institute: [INST-TEST-004] — nested `Tests/Package.swift`
  MUST match the PARENT's language-mode/upcoming-feature posture when its targets
  conform to parent protocols (NonisolatedNonsendingByDefault mismatch makes every
  async witness non-matching); add a note that `Tests_Core`'s re-exported
  `Set_Primitives` shadows stdlib `Set`/`Dictionary` in test files (qualify
  `Swift.*`). Evidence: swift-records nested package, this session.
- [ ] **[skill]** swift-package-build: gate-output integrity rule — never cap a
  gate's output with a truncating pipe (`| head -N` SIGPIPE-kills the build →
  false red; write full log to file, grep afterward), and cwd-dependent gates
  echo `pwd` into evidence (vacuous-green-from-wrong-cwd incident). Candidate
  extension to [PKG-BUILD-016]-adjacent territory.
- [ ] **[doc]** Research/swift-compiler-bug-catalog.md: candidate entry —
  nondeterministic disfavored-overload resolution on L1 `Updates`' dynamic-member
  subscript set (6.3.3): one-site respell flips sibling compound-assign sites
  red/green across compilations; minimal evidence in postgresql-standard
  `8beef4d` commit message and `OperatorsTests.swift` history.
