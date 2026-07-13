---
date: 2026-07-13
session_objective: E-4 orchestrator seat — dissolve the Product_Primitives @_exported re-export (R1), run the pf-import vestige sweep (R2), and script-generate the [MOD-040] @_exported inventory with chain analysis (R3), overnight under ledger supervision
packages:
  - swift-parser-primitives
  - swift-stripe
  - swift-stripe-live
  - swift-product-primitives
status: pending
---

# E-4 re-export dissolution: masked-residue onions, active-zone carve-outs, and inherited session watches

## What Happened

Overnight orchestrator seat under the workspace supervisor (charter:
`Workspace/handoffs/CHARTER-endstate-e4-reexport-dissolution-2026-07-13.md`; close
accepted **Success**, seat released 21:41:57). Three rows, all terminal in ~85 minutes:

- **R1** — removed `@_exported public import Product_Primitives` from Parser Error
  Primitives (`exports.swift:3`). The [HANDOFF-035]/[HANDOFF-040] cascade grep over 19
  org roots produced 188 raw `Product`/`swapped` hits; classification reduced them to
  exactly two genuine consumers, both in-package (`Parser.OneOf.Two/Three` — public
  typealias positions). Fix: explicit `public import Product_Primitives` + manifest dep
  moved Error→OneOf ([MOD-006]/[MOD-038]). Pushed `c3d75cf1…` after package 0/0/0 (170
  tests) + four consumer greens.
- **R2** — fleet enumeration of pf-module imports (Parsing, IssueReporting,
  DependenciesTestSupport, CasePaths, DependenciesMacros) → 9 disposition clusters, 2
  mechanical. swift-stripe pushed `fe74498a…`: `Dependencies_Test_Support` respell ×5,
  dead `import IssueReporting` ×5, dead `.dependency(\.continuousClock, …)` suite
  traits ×5 — net −20/+10, owning targets serially green. stripe-live's instances
  landed inside the W1 seat's own commit (`7d3fc2e`); my re-gate was its second clean
  compile. Non-mechanical clusters recorded: swift-uri-routing carries a **coenttb
  path-dep on pf swift-parsing inside swift-foundations** (top sweep finding);
  swift-authentication needs the @Witness swap lane; structured-queries-postgres is a
  live pf fork; boiler examples are pf-era demos; date-parsing archived-skip.
- **R3** — scratchpad Python scanner emitted
  `Workspace/handoffs/DECISIONS-pass2/exported-reexport-inventory.md`: 3,799 sites /
  1,430 files / 393 packages; buckets per-target-exports 2,891 · tests-support 427 ·
  stdlib-integration 59 · ad-hoc 422 (fully enumerated); chains 1,109 sources / 3,200
  edges / max depth 33 with ~300-module closures at platform roots; one genuine cycle
  (URLRouting↔URLFormCoding), whose death via W1's donor thin was empirically
  confirmed the same night by an unrelated gate error.

Cross-seat events, all resolved through the ledger channel at minutes-latency: a donor
resolution red (W1's Clocks extraction landed mid-gate), and a collision with W1's
uncommitted consumer-sweep hunks in swift-stripe-live (my 7 edits reverted on
supervisor order (b); W1's commit then carried equivalent deletions independently).

**HANDOFF scan ([REFL-009])**: guard red — `.handoffs/` at 108 > 40 cap, 6
filename-terminal residents (the four E-charters, the W1-adjacent charter set, and the
PROGRAM file). All 6 are the live overnight program's records: mine closed tonight but
remains the supervisor's watched channel file until the morning report drains the arc;
the rest belong to seats still in flight. Disposition per [REFL-009a] in-flight
conservativism: **no-touch on all 6**; the per-arc drain at the program close boundary
is the supervisor's, and moving a watched ledger file breaks the armed watch
([SUPER-061]). No loose root handoffs; memory guard OK (target-zero holds); no /audit
this session.

## What Worked and What Didn't

**Worked.** (1) Verify-then-act ([SUPER-058]) fired correctly four times and each one
paid: the missing-GO boot discrepancy (countersigned, not improvised past); the "re-apply
your hunks" order that turned out to be a no-op (W1's commit already carried the
deletions — [SUPER-024] inaction); the supervisor-approved Clocks fix shape that source
contact refuted (the mint vends `\.clock` only; no stripe test uses any clock; the
mechanical fix was deletion, and all interim wiring was reverted to a byte-identical
manifest before commit); and the closure-scan "1 hit" that was commit-author metadata,
not content. (2) The ledger channel carried 3 ASKs and 2 collisions at minutes-latency
with zero improvisation past a boundary. (3) Textual classification of the 188-hit grep
was fast and correct — the sharpened generic/call-form pass ([HANDOFF-040]) reduced it
to 2 real consumers without building anything.

**Didn't.** (1) I ran sed into swift-stripe-live without a `git status` pre-check and
only discovered W1's uncommitted cascade in the same tree from the post-edit diff — the
edits were separable and the recovery clean, but the pre-edit dirty-tree check
([REFL-016] step 1) existed and I skipped it. (2) My first per-target gate used guessed
target names (4 of 5 wrong — SwiftPM test targets don't necessarily match nested test
dir names) and burned a gate cycle; the manifest was one `dump-package` away. (3) Two
stale monitors inherited from this session's pre-/clear occupant (the SYNC-DEDUP seat)
fired mid-arc with other-arc events; I triaged them correctly but only after they
interrupted twice — nothing at boot enumerates inherited watches. (4) My gate logging
piped through `tail -12`, so when the full-package build red arrived, the complete
error inventory was already lost to the pipe — scoping had to be re-derived from
targeted builds ([PKG-BUILD-020] would have said: capture per-target from the start).

## Patterns and Root Causes

**The masked-residue onion.** swift-stripe's test tree failed in LAYERS, each fix
unmasking the next: dead `DependenciesTestSupport` spelling → dead `IssueReporting`
imports → dead `continuousClock` traits → (still unfixed) orphaned test dirs that NO
target compiles and a fully-commented-out test file. Five of tonight's six vestige
shapes were invisible until the layer above them compiled. The pattern generalizes:
in a never-green tree, a grep-derived work inventory is a **lower bound by
construction** — only gate-driven unmasking (serial per-target compiles after each
layer) converges on the true set. This is [PKG-BUILD-020]'s inventory logic extended
across TIME (layers) rather than across targets. Corollary discovered: "green" for a
package whose manifest silently orphans test dirs is structurally overstated — the
gate never even sees those files.

**Carve-outs must enumerate active zones, not repo lists.** The charter froze W1's
four donor packages; the collision happened in swift-stripe-live — not a donor, but
W1's in-flight consumer sweep. A seat's interference zone is its primary targets PLUS
every repo its current cascade is touching, and the latter is invisible in a
repo-list carve-out. The supervisor took the near-miss against charter authoring and
extended the carve-out mid-arc; the durable fix belongs in [SUPER-036]'s edit-zone
enumeration language.

**An approved fix shape is itself a state claim.** The supervisor granted "manifest +
import" for the Clocks layer; the mint's actual surface refuted it. Approval encodes
the approver's model, not the source. [REFL-011]'s primary-source rule already covers
this — the transferable point is that it applies to authorization content too, and
tonight it fired twice across the channel in both directions (my 12-vs-13 line count
was corrected by the supervisor's source read; their fix shape by mine).

**Inherited session state outlives /clear.** Monitors armed by a session's previous
occupant persist across /clear and fire into the new seat's context, indistinguishable
from own-arc events until inspected. Same family as [SUPER-061]'s watch-identity
clauses, but on the seat side: boot should include a monitor inventory (list, adopt or
stop each) exactly as [SUPER-068] does for registered processes.

## Action Items

- [ ] **[skill]** supervise: extend [SUPER-036] (parallel.md) — edit-zone carve-outs in
  charters MUST enumerate each concurrent seat's ACTIVE ZONE (in-flight cascade/
  consumer-sweep repos), not only its primary package list; provenance: the 20:32
  swift-stripe-live collision + supervisor's 20:33:50 mid-arc carve-out extension.
- [ ] **[skill]** supervise: extend [SUPER-060] (channel.md) boot-handshake — a seat
  booting into a reused session (post-/clear handover) SHOULD inventory inherited
  monitors/background tasks and explicitly adopt or stop each, mirroring [SUPER-068]
  process-adoption semantics; provenance: two stale SYNC-DEDUP-era watches firing
  mid-arc into the E-4 seat.
- [ ] **[package]** swift-stripe: record in the package's insights that ≥4 test dirs
  (`Stripe Checkout Sessions Tests`, `Stripe Core Resources Tests`, `Stripe Models
  Tests`, `Stripe Live Tests`) are claimed by NO testTarget (never compiled by any
  gate) and `Stripe Payment Link Tests`' sole file is fully commented out — the
  package's test-green is structurally overstated until the morning row adopts or
  removes them.
