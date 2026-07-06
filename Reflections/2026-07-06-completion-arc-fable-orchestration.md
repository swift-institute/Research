---
date: 2026-07-06
session_objective: Take the post-tower ecosystem to CI completion (swift-pdf green incl. Windows) via Fable orchestration with sonnet/opus workers
packages:
  - swift-tests
  - swift-w3c-xml
  - swift-xml
  - swift-pdf
  - swift-async-primitives
  - swift-ownership-shared-primitives
  - swift-plist
  - swift-css-html-render
  - swift-markdown-html-render
  - swift-set-ordered-primitives
status: pending
---

# Completion Arc — Three Overturned Relay Claims, One Witness-Carrier Adjudication, swift-pdf Green on Windows

## What Happened

Booted from a three-relay context dump plus `HANDOFF-fable-review-post-tower-render-migration.md`
with a mandate: independent status assessment, then drive to completion. Verification-first
paid immediately — three load-bearing relay claims were overturned by primary-source
re-derivation: (1) "swift-async-primitives is the ecosystem root blocker" — clean-room fresh
clone of `8699564` built green; the all-red 09:33 CI run was stale evidence predating the
dep-stack pushes; (2) "swift-tests WIP: verify, commit, push" — the WIP did not build (83
errors; the earlier scoping audit's "likely WRONG" was correct against the later handoff's
optimism); (3) the ledger's "ownership-shared GH rename not executed / 404" — executed hours
before. Execution then ran four phases: P0 swift-tests amended-WIP land (`647a664`), P1 §A13
hoist in swift-w3c-xml (`da14353`+`235ac84`, CI-confirmed on the exact crashing Ubuntu-release
leg), P2 style/portability drain (5 repos landed green; 5 more prepped, handed to the overnight
arc after a usage outage killed the batch mid-build), plus a 468-repo origin-manifest drift
sweep (verbatim-stale: exactly swift-tests + swift-json-web-token). **swift-pdf ci-ok green
including Windows — first ever** (run `28810531411`). Close-out: completion record
`Audits/AUDIT-completion-arc-2026-07-06.md`, overnight dispatch brief authored, save-sweep
pushed 48 repos (flushing the tower's unpushed backlog), guards run.

HANDOFF scan ([REFL-009]): store carries 54 files (cap 40 — red by documented design per the
2026-07-06 cap ruling; drain-per-arc). In this session's authority: 3 files —
`HANDOFF-fable-review-post-tower-render-migration.md` consumed → retired to `.trash/` (findings
destination = the completion-arc audit); `HANDOFF-overnight-lint-quality-arc.md` fresh dispatch,
left (work not started); `HANDOFF-swift-pdf-windows.md` — completion signals encountered via
session work (its gates A/B/C all closed; swift-pdf ci-ok green is its terminal acceptance;
residuals re-homed to the audit + overnight brief) → annotated closed, left for per-arc drain.
Remaining ~51 files: other arcs' authority, untouched. Memory-corpus guard: OK (zero files,
inbox within cadence). No `/audit` findings to status-update ([REFL-010] n/a).

## What Worked and What Didn't

**Worked**: (a) Verify-before-trust as the boot posture — every overturned claim would have
cost hours if acted on (e.g. "fixing" async-primitives' already-healed conformance). (b) The
prep/build pipeline split under the serial-build constraint: batch B enumerated violations and
edited while batch A held the build slot — near-zero idle. (c) Supervisor sample-review caught
a worker's `exports_swift_strict_shape` "fix" that widened `public import` to `@_exported` —
the exact consumer-leak class that broke swift-ascii days earlier; the worker's "pure widening,
can't break the build" reasoning was locally sound and globally wrong (leakage manifests in
consumers, invisible to the repo's own build+test). (d) CI-log triage by subagent turned
"plist is compiler-crash red" into "plist has `import Darwin` in a test file" — cheap
re-classification that converted a scary item into a mechanical one.

**Didn't**: (a) Background-build watchers misfired twice (one stall, one outage casualty) —
foreground blocking builds proved strictly better for serial pipelines; late course-correction.
(b) The briefed markdown-html-render config claim (lineLength 200) was wrong (actual 100) —
a worker caught it via local oracle; brief-time facts about configs should be oracle-derived.
(c) I initially paused awaiting a background agent before delivering the assessment — the
user had to prompt; deliver-then-refine beats wait-for-complete.

## Patterns and Root Causes

**CI-run conclusions are timestamped claims about a SHA, not live state.** All three overturned
relay claims share one root: a CI verdict (or repo-state observation) captured at time T was
carried forward as if it described time T+n while the tree moved. The fix is mechanical:
before acting on any red/green, re-derive against current origin (fresh dispatch, clean-room
build, or `git log origin/main` timestamp comparison). This is [REFL-011] applied to CI
evidence specifically — the run's head SHA and createdAt are part of the claim.

**Front-door aliases can change semantics under migration, and the raw carrier is the escape
hatch.** `Set<X>.Ordered` silently changed meaning post-tower (X: storage → X: element with
`Hash.Protocol` bound), so the "restore the old spelling" fix was impossible — `Ownership.Shared`
lost element-position eligibility in the M8 re-home (no `Hash.Protocol` conformance). The
sanctioned consumer shape is the raw carrier with CoW `Shared` STORAGE
(`__SetOrdered<Ownership.Shared<E, Hash.Indexed<Column.Heap<E>>>>`), exactly mirroring the
render family's `__DictionaryOrdered` precedent. Two independent consumer pulls now exist —
the CoW front-door alias ([DS-026]/[DS-027] territory) has earned its place.

**Lint-rule conflicts resolve into a three-way taxonomy**: comply (real violation), shield
with documented reason (rule false-positive: `prefer_self` in conformance/where-clause
positions, `workaround_marker_present`'s regex blindness), escalate carve-out (rule design
defect: `exports_swift_strict_shape` type-position). The dangerous quadrant is "comply with a
rule whose fix leaks across package boundaries" — local verification cannot catch it; only
precedent knowledge (the ascii incident) did. The overnight brief encodes this taxonomy.

## Action Items

- [ ] **[skill]** quick-commit-and-push-all: [SAVE-001]'s swift-institute sibling list omits `Workspace/` and `Issues/` — both carried unpushed state this session that the scripted sweep would have stranded; add both rows.
- [ ] **[skill]** handoff: add a CI-evidence staleness axis to [HANDOFF-016] — a run verdict binds to its head SHA + createdAt; re-derive against current origin before treating it as live state (three relay claims overturned on this axis, 2026-07-06).
- [ ] **[package]** swift-set-ordered-primitives: the CoW `.Ordered` front door is now consumer-pulled by two live consumers (swift-tests `Test.Trait.Tag.Value`, render family's Dictionary analog) — land the alias, then retire the raw `__SetOrdered<Ownership.Shared<…>>` spellings; note `Ownership.Shared` lacks `Hash.Protocol` for element-position use.
