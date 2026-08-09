# W11 acceptance — the org-hierarchy layout, proven on a fresh scratch clone

**Date:** 2026-07-26 · **Lane:** W11 (issue #17) · **Change under test:** `48a39cf6`
*Adopt the org hierarchy as the single materialization layout* · **Ruling:** 146 (roots
inside the repository root).

This repository is public. Paths use `<scratch>` placeholder form deliberately. Every
build below ran through the machine-wide build coordinator, backgrounded, under a
liveness watch (the Stage 1 pilot's F7 discipline: log growth + `.build` writes +
child-process presence polled; no gate stalled). Figures are the coordinator's own log
lines and each command's own exit status.

## 1. A fresh clone syncs straight into the org hierarchy

A scratch clone of this repository at `48a39cf6`, its Application built by the
coordinator (GREEN, 4 259 fresh compile steps), then:

```
$ workspace sync
Workspace sync plan
  swift-primitives/swift-dimension-primitives: clone
  swift-standards/swift-color-standard: clone
  swift-foundations/swift-color: clone
  swift-foundations/swift-url-routing: clone
  swift-foundations/swift-http-body: clone
  institute.xcworkspace: current
Sync complete.
```

The plan names org-layout locations; the committed `institute.xcworkspace` was already
`current` (generated references match the inventory). Materialized tree:

```
swift-primitives/swift-dimension-primitives/
swift-standards/swift-color-standard/
swift-foundations/swift-color/
swift-foundations/swift-url-routing/
swift-foundations/swift-http-body/
```

## 2. Doctor is green on the fresh clone, populations stated

```
$ workspace doctor
toolchain: ok (population 4)
workspace-reference: ok (population 1)
materialization: ok (population 5)
layout-migration: ok (population 5)
working-state: ok (population 5)
resolved-pins: ok (population 0)
manifest-identity: ok (population 5)
inventory-currency: not run (institute-internal)
8 checks: 7 ok, 1 not run (institute-internal); measured populations: toolchain 4,
workspace-reference 1, materialization 5, layout-migration 5, working-state 5,
resolved-pins 0, manifest-identity 5
doctor: passed — 7 check(s) measured, 1 not run (institute-internal), 0 warning(s).
```

Exit 0. Every measured check states its population; nothing is an unmeasured pass.

## 3. The full compose loop on the org layout (Milestone Evidence procedure, re-run)

**Fixture.** Consumer `swift-standards/swift-color-standard`; dependency
`swift-primitives/swift-dimension-primitives` carrying local commit `5532a5d`, which
appends `#warning("WORKSPACE-LOCAL-SENTINEL-W11-ORG-LAYOUT-2026-07-26")` and exists on
**no remote branch** (`git branch -r --contains HEAD` → empty). Baseline manifest SHA-256:
`4a63442e…` (the canonical value the original Milestone Evidence also recorded).

| Step | Action | Coordinator verdict | Sentinel in build log |
|---|---|---|---|
| **A** baseline | canonical build | exit 0 · GREEN · 682 fresh compile steps | **absent** (0) |
| **B** compose | `workspace compose --consumer swift-color-standard --dependency swift-dimension-primitives` | exit 0 · manifest `url` → `path` at the **org-layout** checkout · machine-local-path warning printed | — |
| **C** composed build | build | exit 0 · GREEN · 34 fresh compile steps | **present, 33 lines** |
| **D** restore + build | `workspace restore …` then build | restore exit 0 · build exit 0 · GREEN · 34 fresh compile steps | **absent** (0) |

The verbatim step-C diagnostic (path elided):

```
<scratch>/Workspace/swift-primitives/swift-dimension-primitives/Sources/Dimension Primitives/Vertical.swift:101:10:
warning: WORKSPACE-LOCAL-SENTINEL-W11-ORG-LAYOUT-2026-07-26
```

`workspace verify` at each state, reading SwiftPM's own resolved state:

- **A:** `no active composition` · `source-control checkout @ 64483cc3…` · compiled tree under `.build/checkouts`
- **C:** `composed (local development source active)` · `local file-system source` · compiled tree = the org-layout checkout
- **D:** `no active composition` · `source-control checkout @ 64483cc3…` · compiled tree back under `.build/checkouts`

**Restore is byte-identical:** the manifest hashes back to `4a63442e…` exactly. **The
absence at D is not a cache artifact:** the step-D log recompiled `Dimension_Primitives`
from source (30 `Compiling Dimension_Primitives …` lines) and emitted no sentinel. **The
developer's work was preserved:** after the full cycle the dependency worktree is clean
and still at `5532a5d`; compile-in-place never mutated it.

This run doubles as the visible confirmation that local-path editing works on the org
layout: an unpushed local commit in the materialized dependency was compiled by the
dependant, and canonical resolution returned cleanly after restore.

## 4. The migration path, measured live on a flat checkout

A development checkout carrying the superseded flat `Packages/` tree, re-synced to the
org layout, reports (abridged to one of four identical warnings):

```
$ workspace doctor
…
materialization: ok (population 5)
layout-migration: warning findings (population 5)
  warning: swift-dimension-primitives: a flat checkout remains at
  Packages/swift-dimension-primitives, superseded by the org layout at
  swift-primitives/swift-dimension-primitives — re-run `workspace sync` to materialize it
  there, then remove the flat checkout manually once any local work in it is salvaged
  (tooling never deletes it)
…
doctor: passed — 7 check(s) measured, 1 not run (institute-internal), 4 warning(s).
```

Exit 0: a flat checkout is a warning naming both locations, and tooling never deletes it.

## 5. Population covered — limits, stated so they are not over-read

One consumer, one composed dependency, one transitive level, single machine, macOS,
Xcode's bundled toolchain. The clean-room remote-only resolve (Milestone Evidence step E)
was not repeated here — it proves a property of the path backend, unchanged by layout.
Uncomposed dependencies on this machine still resolve through the global mirror map
(pilot F4); resolution truthfulness remains a Stage 2 gate, not altered by this change.
