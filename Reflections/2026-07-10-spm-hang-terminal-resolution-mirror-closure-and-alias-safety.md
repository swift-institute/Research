---
date: 2026-07-10
session_objective: Fully and terminally solve the SwiftPM identity-conflict path-enumeration hang (dossier §A26) — patch, mirror closure, fleet enforcement, CI fencing
packages:
  - swift-package-manager (upstream clone, local patch)
  - swift-dependencies
  - swift-authentication
  - swift-server-foundation
  - swift-types-foundation
  - swift-records
  - swift-linter-rules
status: pending
---

# SPM Hang Terminal Resolution: Mirror Closure, Alias-Safety Laws, and the Patched Tool as Instrument

## What Happened

Dedicated resolution session executing the five-point definition of done from
`HANDOFF-spm-hang-resolution-2026-07-10.md`, plus a mid-session principal order (swap
`pointfreeco/swift-dependencies` consumers to the institute package, resolving-first) and a
post-review relay (CI circuit breaker, record correction, guard hygiene, staged fail-fast).

Delivered: (1) patched SwiftPM at the 6.3.2 release commit — visited-set shortest-chain BFS in
`findAllTransitiveDependencies` — validated A/B (stock spins/killed vs patched 130s synthetic,
333s on the real authentication graph, diagnostics preserved); principal ruled NO upstream PR,
patch archived as dossier evidence. (2) The mirror table became a generated artifact:
`sync-mirrors.py` + alias ledger + `--check` drift guard + `--probe [--scan]` GitHub-redirect
enumeration (~80 aliases discovered mechanically, incl. renamed identities); legacy
single-spelling `setup-mirrors.sh` defused into a shim; table 1,327 → 1,398 verified IN SYNC.
(3) Fleet enforcement: `scan-identity-conflicts.py` (516 repos, HEAD+tags+pins+checkouts, dual
mirror contexts), 21-repo spelling sweep pushed, [PKG-DEP-009] + `validate-dependency-spelling`
org-sweep guard, 10-repo dependency swap (8 pushed, 2 held on master's unpushed state).
(4) Relay items: `timeout-minutes` on all 25 uncovered runs-on jobs across four org `.github`
repos; "duplicate stale clones" record CORRECTED (phantoms — path-deps in old-tag manifests,
not disk state); html-prism known-exception in all three guards; fail-fast pre-resolve check
staged. Final scan: local HARD 17 → 4 (all documented classes), local TAIL 8 → 0.

HANDOFF scan ([REFL-009]): no loose root handoffs; store guard reports 68 > 40 WIP — the
documented per-arc-drain overage (2026-07-06 cap ruling; no forced re-triage). 3 files in
session scope: `HANDOFF-spm-hang-resolution-2026-07-10.md` — annotated-and-left (fully
status-folded incl. FINAL RETURN; master session resumes on it; arc not closed until the
source phase lands); `REPORT-spm-hang-resolution-2026-07-10.md` — left (supervisor-reviewed
terminal record; migrates to `Audits/` at arc close per the guard's REPORT- rule);
`HANDOFF-overday-2026-07-10.md` — out-of-authority (master's, in-flight, no touch per
[REFL-009a]). Memory guard: OK (zero topic files). No `/audit` ran; [REFL-010] n/a.

## What Worked and What Didn't

**Worked.** The dossier's quality made the patch leg nearly mechanical — root cause, function,
and fix shape were pre-adjudicated, so the 100%-Fable leg was mostly build-and-validate. The
probe→scan→probe closure loop (scanner output feeding redirect-probe candidates) terminated in
two passes with every observed historical spelling either aliased or adjudicated — hand-lists
had provably missed entries (web-standards/rfc-{6238,7519}) that mechanical enumeration found.
My own gates caught my own regression twice: the sweep's dump-package gate exposed the alias
poisoning 16 minutes after I installed it, and the A/B discipline (cache-bust + project-local
old table) isolated it to the table rather than the edit. Confidence was high exactly where
verification was mechanical.

**Didn't.** Three self-inflicted incidents, all caught in-session: the renamed synthetic
lattice silently resolving against its successor directory (gen-synthetic bakes absolute
paths — the first "patched" validation was worthless); the 1,402-entry table shipping two
poisonous renamed-identity aliases (window bounded by backups, ~16 min); and the supervisor
report asserting "duplicate stale clones" that do not exist — a scanner artifact (path-dep
resolution against repo dirs) transcribed as disk state without an `ls` at authorship time.
That last one is a textbook [REFL-011] first-assertion violation: the rule existed, I did not
consult it, and the relay's execution phase caught it. Also: running three cold gates in
parallel with sweep gating produced shared-cache contention that first read as "transient
failures" — a prior that nearly masked the real (alias-poisoning) defect among them.

## Patterns and Root Causes

**Every mirror entry is an identity-equivalence assertion, and every failure class this arc
hit was one unverified equivalence dimension.** apple/swift-numerics failed on the *tags*
dimension (genuine upstream, institute fork untagged); pointfreeco/swift-dependencies and
swift-clocks failed on *history* (rewrites — alien SHAs break pin fetches, missing tags break
version solve); coenttb/swift-emailaddress and swift-identities failed on the *identity-name*
dimension (renamed-identity alias whose OLD name is still a live package poisons every
consumer of that identity via SwiftPM's identity-keyed lookup). The stable law:
redirect-verified ⇒ safe by construction (same repo, same refs); fork-heritage ⇒ safe only
with tag-lineage proof; renamed-identity ⇒ safe only if the old name is unclaimed. Each class
is now mechanically refused (probe collision handling, hard exclusions, the
`generate()` identity-claim guard) — but the law itself lives only in script comments and the
ledger, not in a skill rule.

**Fixing the bug was the cheapest observability investment.** The hang hid its own cause —
infinite spin, zero output. The patched binary converted it into a *printing* diagnostic, and
from then on it was the session's best instrument: it NAMED the residual introducers
(password-validation, environment-variables) that no static analysis had isolated, and
verified the swap (3 → 2 conflicts) in minutes. Sequence tool-fix before exhaustive static
analysis whenever the defect suppresses its own evidence.

**Tool-reach failures recurred at every altitude.** The phantom-clones claim (extractor reach ≠
disk-state claim), the "transient" dump failures (contention prior masking a real defect), and
dump-package's nondeterministic emission (comparison noise vs true mismatch) are all the
[REFL-011] tool-reach class: reading a tool's output as a claim wider than the tool's reach.
The correction is always one comparison at authorship time — `ls` the dirs, A/B the table,
canonicalize the ordering.

## Action Items

- [ ] **[skill]** swift-package: add the alias-safety law to the [PKG-DEP-*] family (companion
      to [PKG-DEP-009]): a mirror alias requires identity-equivalence proof per class —
      redirect-verified (safe by construction) / fork-heritage (tag-lineage proof required) /
      renamed-identity (old name must be unclaimed by any live clone). Currently encoded only
      in `Scripts/sync-mirrors.py` guards and the ledger.
- [ ] **[skill]** ci-cd-workflows: new [CI-*] invariant — every `runs-on` job in a reusable
      workflow MUST declare `timeout-minutes` (circuit breaker; GitHub's 360-min default burns
      per matrix leg on any hang class). Enforcement candidate: a validate-timeout-presence
      sweep on the validate-continue-on-error.yml pattern.
- [ ] **[research]** Locate the exact SwiftPM source path of the identity-keyed mirror lookup
      that made the renamed-identity aliases poisonous (empirically confirmed via the
      swift-emailaddress manifest-validation failure; mechanism inferred, never source-located).
      Knowing the code path bounds which alias shapes are safe under future SwiftPM versions.
