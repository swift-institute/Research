---
date: 2026-06-12
session_objective: Seat-side supervision and close-out of tower phase 3 — the weakness-sweep iteration (arcs 1–3, two fix legs, the engine-fix arc), policy codifications, and the phase-4 plan.
packages:
  - swift-shared-primitives
  - swift-hash-table-primitives
  - swift-dictionary-primitives
  - swift-dictionary-ordered-primitives
  - swift-storage-primitives
  - swift-async-primitives
  - swift-stack-primitives
  - swift-heap-primitives
  - swift-pool-primitives
  - swift-buffer-primitives
status: pending
---

# Tower Phase 3: the Seat's Close-Out — Verify → Measure → Fix in One Phase

## What Happened

One seat session supervised the entire phase-3 iteration: three principal-picked arcs
(Shared-concurrency verification · model-based randomized testing · family benchmarks), the
B7 issue-investigation lane, two ratified fix legs (the Sendable clause pass + async dep; the
CoW removeAll pair split), and the engine-fix arc (B-7 rank→bucket plane, B-8 span-first probe
loop, B-1′ out-of-line Box payload). Every leg was independently re-verified: clean rebuilds,
carved TSan legs with a seeded positive control, fresh-seed model soaks, and bench claims
checked by structure/ratio under load (loaded-window spot-runs reproduced every structural
claim, including the evict flip — 236 µs → ~90 ns — and the B-1′ pass criterion row-for-row).
Policy got codified along the way: the never-file-to-swiftlang standing policy landed in
[ISSUE-008] (+ the Issues README reframe), and a five-rule skills batch shipped
([MEM-COPY-019], [TEST-036/037/038], the [BENCH-003] executable-instrument variant). The
phase-4 plan (Round M mechanical+integrity → Round P publication public-no-tags → Round C
consumers) was derived via an explicit multi-angle framework and ratified; Round M's GOAL is
staged. Records were rebuilt (fresh-boot seat handoff; the 581-line accreted predecessor
archived; plain OVERVIEW rewritten); the Research bundle (baselines v1.0.0, catalog B7–B11)
was published with principal authorization.

HANDOFF scan per [REFL-009]: `.handoffs/` holds ~40 HANDOFF-*.md files; 3 are in this
session's authority — `HANDOFF-tower-SEAT.md` (live, rewritten as the phase-4 fresh-boot doc),
`HANDOFF-tower-SEAT-archive-2026-06-12.md` (deliberate history preserve), and
`HANDOFF-tower-flag-day-migration.md` (the W5 STATUS record, still referenced by the fresh-boot
doc) — all KEPT deliberately; zero deletions. The remainder pre-date this program slice and are
out of cleanup authority (left untouched, no annotations). The phase's GOAL-*/REPORT-* files
are the program's records corpus (indexed by OVERVIEW §8), not ephemeral handoffs. No /audit
ran this session ([REFL-010] n/a).

## What Worked and What Didn't

**Worked.** (1) Spike-first with falsifiable predictions: both mechanism rulings (V3
back-pointers; the B-1′ out-of-line payload) shipped with numeric predictions that the
implementation then hit row-for-row — "the theory was right" became a checkable gate, not a
narrative. (2) Seat-added gate conditions earned themselves disproportionately: the
maintenance-side condition added to the V3 ruling caught a real 7× init regression; the
fresh-seed protocol made every model green seed-independent; the TSan positive control made
quiet sanitizer gates mean something (and kept firing through the B-1′ pointer reshape — the
deepest check of that ruling's conditions). (3) Independent reproduction as the blessing
standard: the seat's own /tmp trap probe (CoW finding), its own bench runs (B-7/B-1′), and its
own immunity probes (B7-mangling) repeatedly converted executor claims into seat knowledge.
(4) The interlocked grant scheduling (package-disjoint waves, one-package-one-owner,
quiet-window coordination) let three arcs + fix legs run concurrently with zero file races.

**Didn't.** (1) The session-boot `/goal` stop-hooks fought the HALT protocol: arc-1's hook
overrode its W1/W2 gates (work ran ahead of rulings; absorbable only because
propose-don't-bake held), then bounced its terminal halt nine times until the principal
typed /goal clear. (2) The seat overstepped once — editing a one-line manifest fix itself —
and was principal-corrected mid-action; the verification model survives only if the verifier
never authors (codified to memory, and the inherited-diff handover worked cleanly). (3) The
seat's own tooling had blind spots: a ps-grep that missed test *binaries* hid a 3.5-hour
wedged pool run; two scripts failed on first run (mkdir-after-cat ordering; a find pattern) —
caught, but each cost a cycle. (4) Human-shuttled relays lost real hours once (the Phase-2
signal sat unpasted while everyone believed arc-1 was running).

## Patterns and Root Causes

The phase's central result is methodological: **the verify→measure→fix loop closed inside one
phase because the ordering was verify-before-optimize.** The harnesses built in arcs 1–2
caught the fixer's own bugs twice pre-commit (a dense/sparse contract violation; a silent OOB
grow-path write pinned by seed-replay) and unmasked a shipping trap the example tests had
masked for exactly the [TEST-035] reason. The baselines built in arc 3 first *found* the
dominant defect (B-7 — which no code reading had flagged) and then made its fix falsifiable.
Every fix landed into a net that already existed. The sweep's own re-rank also proved the
point in reverse: the SoA re-cut, ranked #5 on intuition, was measured into irrelevance
(sub-ns terms, 3–4 orders below B-7) and survives only as a design-integrity item.

Second pattern: **harness automation and supervision protocols are in tension wherever an
automated continuation signal can outrank a human gate.** The /goal stop-hook is a liveness
mechanism; HALT gates are a safety mechanism; when they collide, liveness won by default.
The durable fix was structural, not disciplinary: run executors instruction-driven with no
goal hook at all (now standing). The general form — "any auto-resume mechanism must be
subordinate to protocol gates" — likely applies beyond this program (cron wakeups, loop
pacing, CI auto-retries).

Third: **role boundaries erode through small, individually-harmless exceptions** — the seat's
one-line edit was objectively correct and still wrong, because author-verifies-self is a
structural property, not a per-change judgment. The cheapest correction was the principal's
immediate interrupt; the cheapest prevention is the now-codified rule plus the inherited-diff
pattern, which preserves both the work and the model.

## Action Items

- [ ] **[skill]** supervise: add the instruction-driven-executor rule (no `/goal` hooks on
  gated sessions — auto-resume must never outrank a HALT gate) and a relay-confirmation
  convention (multi-session relays carry an explicit paste-me block; the supervisor tracks
  un-acknowledged relays as open items, closing the lost-relay gap).
- [ ] **[blog]** "Verify before optimize, measured": the phase-3 story — harnesses that caught
  their own fixer's bugs, a benchmark arc that found what code-reading missed, and two
  mechanism rulings shipped against falsifiable predictions (publishable after Round P's
  public flip).
- [ ] **[package]** swift-pool-primitives: ledger the fill-lane liveness flake (1-in-3 wedge of
  the debug leg; lost-continuation signature, supervisor parked on asyncMainDrainQueue;
  evidence preserved at `.handoffs/probes-2026-06-11/seat-arc1-gates/pool-hang/`) — the chase
  candidate is a fill-lane adversarial test in the arc-1 rider style.
