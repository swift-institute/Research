---
date: 2026-06-05
session_objective: Close the storage/memory-split arc as Cleave-2 — W-D held-cell resolution, W-E paper closes + termination sweep, merge brief, then the authorized merge + push windows to arc termination
packages:
  - swift-storage-primitives
  - swift-store-primitives
  - swift-memory-heap-primitives
  - swift-buffer-linear-primitives
  - swift-buffer-ring-primitives
  - swift-hash-table-primitives
  - swift-array-primitives
  - swift-storage-split-primitives
  - swift-set-ordered-primitives
  - swift-async
status: pending
---

# Storage/Memory Split — Cleave-2 Termination (the close tail through merge + push)

## What Happened

Session 2 of the split arc ("Cleave-2"), dispatched at session-1's context-limit rollover with
GO pre-granted. Verified the snapshot first-hand (26 worktrees on-branch/unpushed; the held
async cell's evidence gap confirmed; buffer-ring atop `9a37bd6`), then ran the tail: item 0
resolved the held cell definitively (async-primitives cold in-mesh **204/41 FULL GREEN**,
BroadcastStressTests passed — the raw receipt row's `+F2sweep` was a mis-annotation, zero F2
edits needed); item 1 was principal-SKIPPED mid-flight ([SUPER-021] weakening — L3 swift-async
deferred to main; the in-flight resolve killed clean, zero orphans); item 2 landed the paper
closes (RECEIPT.txt honest-record supersession block; packet v1.1.1 `625ee12` with the C6
zero→2 correction, the 7b27219=8-files reconciliation, appendix §1 [re-authored, flagged] + §2
[the five gaps, verbatim from #27]); item 3 ran the termination sweep EMPTY at proven width (10
classes × 26 worktrees × 78 paths, 5 positive tool-reach controls per [AUDIT-036]); item 4
delivered the merge brief (9 source-delta repos, 3 NO-FF absorptions enumerated, mirror-first
reversion sequencing). set-ordered's evidenced-but-uncommitted F2 was committed as `5d26d2c`.

The merge window then executed on "YES MERGE + YES CREATE": the one authorized create
(memory-heap PRIVATE+empty + mirror entry), 6 FF merges at exact tips, and a **STOP fired** on
the storage NO-FF (2-file conflict: the Polish format commit `f74d7da` vs the split's
rename+rewrite). Aborted clean, surfaced; the seat's written OPTION A ruling resumed the
window; the resolution applied the ratified absorption rule (take-branch-side on
design-deleted text; resolution diff vs both parents banked). hash-table/array NO-FF absorbed
the pushed Porter CI commits clean. Reversions + ZERO-path-dep post-assert 9/9; riders landed
(CLCPM v1.5.0 `ef59cea` · #28 dedup `b6e7a87` · packet v1.1.2 §1b verbatim `53551cb`).

The final relay ran step 0 (L3 on-main: library build GREEN; test target blocked at EXACTLY
the #22 class — compile-form, `Isolation Tests.swift:111` Sendable; no other diagnostic), the
private push window (9 repos, 1:1 windows exact, all `HEAD==origin/main` verified; memory-heap
first-push `-u`), the principal-authorized Research push (exactly 4 commits), and cleanup
(26/26 worktrees removed, branch refs kept, 11 receipt files banked).

**HANDOFF scan** ([REFL-009]): 4 in-scope files — `HANDOFF-storage-memory-split.md` +
`storage-memory-split-PROGRESS.md` annotated with termination stanzas, retirement PENDS the
seat's [SUPER-011] stamp (relay-explicit) · `split-packet-s1b-content.md` consumed + deleted
([HANDOFF-008a]) · `HANDOFF.md` seat-owned, untouched. Other `HANDOFF-*` files
out-of-session-scope, untouched.

## What Worked and What Didn't

**Worked**: the operational corrective set from session-1's post-mortem ran clean end-to-end —
ONE build in flight ever, notification-driven waits (no polling chains), PID-explicit kills
(TaskStop + ps sweep, zero orphans twice), `set -o pipefail` on every piped build, ps-first
before the first build. First-hand snapshot verification caught two things the brief didn't
carry: set-ordered's uncommitted F2 edits and the missing on-disk test logs behind seven
seat-accepted verdicts. The STOP discipline held under pressure: the named gate fired, the
halt was clean (abort + 0-dirty verify), the surface carried decisive evidence (f74d7da's
full diff on the conflicted files proved take-branch-side lossless), and resumption waited for
the declarer's ruling. Set-membership push discipline ([SUPER-052]): every window 1:1-checked
before fire, every push HEAD==origin verified after.

**Didn't (or wobbled)**: the seat's §1 relay text never reached this session (it lived in
session-1's chat) — the §1 re-authoring + flag was the recovery, and the s1b scaffold file was
the seat's fix for §1b. The step-0 gate's phrasing ("green minus exactly the one #22 failure")
was unrealizable as written — #22 is a test-target COMPILE error, so the suite cannot run at
all; classification had to fall back to "exactly one distinct diagnostic, of exactly the known
class, at exactly the known line." The Stop-hook/permission-classifier standoff after the STOP
consumed two round-trips reconciling three authorities (the goal's own STOP clause, the hook's
completion pressure, the classifier's denial) — correct outcome, but the deadlock pattern is
worth naming.

## Patterns and Root Causes

**The mesh-vs-mirror cost structure** (the principal-directed slowness analysis, seat-confirmed
suspects): the `.split-wt` path-dep mesh defeats every shared-artifact mechanism SwiftPM has —
each cell resolved the full graph and compiled the ENTIRE tower closure into its own `.build`
(measured: 1991 modules / ~230s for the async cell; ~99% of wall-clock is closure compilation,
the suite itself 1.3%). 26 serial cells ≥2h per cold pass, and the cold bar makes every
re-attempt pay full price. The identity-warning storm is the mesh's signature ([PKG-BUILD-014]
path-vs-path override). Post-merge, the SAME verification runs through normal mirror
resolution: no warnings, shared checkouts, per-package warm `.build`. The structural lesson:
worktree meshes are a CORRECTNESS instrument (identity unification pre-merge), not a
throughput instrument — budget accordingly, and dissolve them at the earliest gate. The
ratified two-tier bar (warm mid-wave, cold at receipts) is the right mitigation inside the
mesh's lifetime.

**The touch-time resolution precedent**: a NO-FF that absorbs a format/move commit whose hunks
target text the branch deleted resolves take-branch-side BY RULE, not by judgment — "the
resolution authors nothing; it applies the ratified absorption rule" (seat). Two sub-lessons:
(1) the decisive surface-evidence was `git diff base..absorbed-commit -- <conflicted files>` —
proving every absorbed-commit hunk targeted design-deleted text made the ruling one-line; (2)
**the rename+move 3-way blind spot**: auto-merge silently KEPT main's relocated
`Storage_Flat_Primitives` import because the branch's deletion happened at the line's OLD
position — a dead import of a deleted module that marker-only conflict resolution would have
shipped. Post-merge residual greps of design-deleted identifiers on the MERGE RESULT (not just
the branch) are the closing check; the resolution-diff-vs-both-parents is the verification
artifact that makes seat review tractable.

**The ledger-vs-relay boundary**: this arc's recurring epistemic class. Chat-side numbers
without disk evidence got correctly REJECTED (the held cell's "204/41 in-mesh" — later proven
true, but only the definitive run made it evidence); annotation errors rode the ledger until
reconciled (three spurious `+F2sweep`s, the 8-vs-9 miscount in two places); relay content that
existed only in a dead session's chat was unrecoverable (§1) until the seat moved it to disk
(the s1b scaffold — consumption-scaffolding with an explicit delete-after lifecycle); and the
seat's on-disk ruling legitimately UNBLOCKED execution before its in-chat relay arrived. The
boundary rule that falls out: **the ledger (receipts, commits, on-disk rulings) is the
authority; relays are transport** — write rulings and relay-content to disk first, treat chat
as notification. The s1b scaffold pattern (disk file + land-verbatim + delete-after) is the
reusable transport for successor-session relay content.

**#22's true form**: the accepted-red is a compile-class diagnostic in the test target, so
every "suite minus one" phrasing of the L3 gate is structurally unrealizable until #22 is
fixed — the honest gate is "library build green + exactly the one known diagnostic, nothing
else" ([SUPER-009a] verifies/does-NOT-verify framing). The async-domain arc inherits this.

## Action Items

- [ ] **[skill]** handoff: add a relay-content transport rule — paste-ready content intended
  for a successor session MUST land as an on-disk scaffold file (the `split-packet-s1b`
  pattern: explicit target, land-verbatim, delete-after per [HANDOFF-008a]), never only in the
  predecessor's chat; extends [HANDOFF-016]'s transcription axis with the §1-relay-gap incident.
- [ ] **[skill]** audit: post-NO-FF-merge residual check — when a merge absorbs a format/move
  commit, grep the MERGE RESULT for identifiers the branch deleted (the rename+move 3-way
  silent-keep class, the `exports.swift` dead-import incident); pairs with the
  resolution-diff-vs-both-parents receipt form.
- [ ] **[package]** swift-async: #22 is compile-form (test target blocked at
  `Isolation Tests.swift:111`, Map/Filter non-Sendable vs Stream.init Sendable) — no suite run
  is possible until fixed; the "green minus one test" gate phrasing in arc records is
  unrealizable as written. Stays with the async-domain arc (carry-forward).
