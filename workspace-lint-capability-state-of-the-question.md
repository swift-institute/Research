# Workspace Lint Capability — State of the Question

<!--
---
version: 1.0.0
last_updated: 2026-07-28
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

Starting position for work on a Workspace-owned lint capability. Everything below was verified by
looking rather than inferred, except where explicitly marked unverified. Companion:
`enforceability-taxonomy-and-honest-voice.md`.

## Objective

**A Workspace capability that lints the whole ecosystem efficiently, and easily and quickly lints
single packages.**

This is *not* the earlier objective, which was "make agents follow and use swift-linter." That
framing assumed enforcement had to be built. It does not — see below. The obligation question is
now a consequence of having a capability worth running, not the thing being designed toward.

## The distinction that changed the objective

An earlier finding held that swift-linter had **no runnable entry point**: no `lint` action in the
build coordinator, no binary on `PATH`, absent from the workspace inventory, and committed
`Lint.swift` files that nothing in the checkout could execute.

**Every part of that is true of the local checkout, and none of it was ever a finding about CI.**
The finding was generalised across vantage points without being re-checked, and a programme status
was built on it. Do not rediscover this: the local gap and the enforcement gap are different
questions, and only the first one is real.

## What CI actually does — verified

**It runs swift-linter, and it is gating.** A `swift-linter` job in the universal reusable
workflow sits in the `ci-ok` aggregate alongside format, lint, and the release legs, so it is a
required check. The workflow states the Phase-1 "advisory" label is retired by principal ruling.
All three verification tiers include the leg.

**It is file-gated on a root `Lint.swift`.** Present → run; absent → cheap no-op. The workflow's
own words: the file *is* the activation signal, so coverage grows as packages add one.

**Binaries come from a rolling release.** The dispatcher and a prebuilt "standard runner" are
downloaded from a non-semver `ci-binaries` release tag, verified with a checksum file, and
installed. On any download or verification failure the job falls back to a source build at the
resolved engine `main` HEAD — deliberately never red on a missing release.

**The version is not pinned; it floats.** The release is rebuilt from `main` of the engine and
five rule packs. Each build publishes a manifest recording the exact revisions, and a **composite
`digest` over those revisions**. That digest is the parity token — see below.

**Rules are live and the gate is currently slack.** A real run on a foundations package reported
`93 active rules · 46 files linted · 181 violations` — and passed. The exit policy fails the run
only on error-severity findings; warnings are emitted and never fail. Error-severity rules do
exist (seven in the institute rule pack alone), so the gate *can* close. Across two dozen recent
runs on three repositories it has never been observed closing.

**`Lint.swift` is load-bearing three ways** — activation signal, rule configuration, and an input
to CI's tier classifier, which downgrades a push touching only lint-config files to the lint tier.
It is not a vestige.

## What was measured

**Parity is achievable and provable.** The macOS binary from the same release, run locally against
the same package, produced a summary line **byte-identical to CI's**. Both platform manifests carry
the **same composite digest**; only build time and toolchain differ. The macOS asset publishes on a
slower cadence than Linux, so drift is expected over time and must be surfaced rather than
discovered as a local/CI disagreement.

**The silent-zero is real and worse than documented.** Three invocations produce **exit zero with
no output at all** — not a zero-count summary, nothing:

- a directory containing violating Swift source but no `Lint.swift`
- a **file path** rather than a package root
- an empty directory

The engine's own help says it: without an explicit configuration, zero rules fire. **CI is
protected only by its own file-detect step, not by the binary**, so any new caller inherits the
hole. The second case matters most for a developer tool — "lint the file I am editing" is the most
natural inner-loop invocation and it silently does nothing.

**Timing**, macOS, eight cores, wall clock:

| Bundle | Source files | Wall |
|---|---|---|
| primitives | 4 | 0.10s |
| primitives | 28 | 1.41s |
| standards | 24 | 2.49s |
| institute | 46 | 8.33s |

**Scale.** 442 repository package roots; 432 carry a root `Lint.swift`. Bundle distribution: 199
primitives, 124 institute, 108 standards, 1 universal.

**The prebuilt runner covers only bare-primitives consumers.** The other 233 packages fall through
to an eval path that compiles the declared rule packs per invocation. That is the dominant cost and
the main efficiency lever, and it is paid by CI too — the same seconds on every consumer run.

## Requirements

- **Two modes**, single-package and whole-ecosystem.
- **Parity with CI is hard, not aspirational.** Same binary, same rule configuration, same
  severities, same scope. A capability that can disagree with CI teaches people to trust whichever
  signal is convenient. If parity proves impossible, say so loudly rather than approximating.
- **The single-package path must not pay ecosystem-scale costs.** A fast path that is the slow path
  with a filter applied is not fast. It must need no arguments and no ceremony from inside a
  package directory.
- **One capability, two entry points — not two implementations.** Linting a package alone must not
  be able to disagree with that package's result inside the sweep.
- **UNMEASURED when nothing was measured.** A run that loaded no rules, or matched no files, must
  not be able to report clean — separately in both modes, and per-package within the sweep so one
  skipped package cannot hide in an aggregate. **Prove it by making it happen**, through the whole
  path it will actually run in.
- No numeric limits anywhere.

## Proposed design (awaiting adjudication)

**Entry points.** `workspace package lint` for a single package, mirroring the existing build and
test verbs. `workspace lint` for the sweep. One implementation behind both.

**Parity, enforced.** An install step fetches the platform-matched asset, verifies its checksum,
and records the manifest. A check step compares the local composite digest against the Linux
manifest CI consumes and reports divergence. The digest already exists for exactly this purpose;
nothing needs inventing.

**UNMEASURED guard.** Workspace parses the summary line and treats *absence of the line*, zero
active rules, or zero files linted as UNMEASURED — never clean. This is the only defence against a
binary that reports nothing at all.

**File paths are resolved, never passed through.** Walk up to the enclosing package root, lint
that, filter output to the requested file. Passing a file directly to the binary is a silent-zero
and must be unreachable through the capability.

**Fast path pays no sweep costs.** Single-package resolution walks up from the working directory
for a manifest plus a lint configuration. No inventory read, no organisation enumeration, no
roster.

**Sweep.** Parallel across packages bounded by cores, plus a changed-scope mode covering only
packages whose tracked files differ from a ref. Report measured wall clock for both modes rather
than an extrapolation.

## Open decisions

1. Does the parity check **fail** or merely **warn** when the local digest diverges from the one CI
   consumes?
2. Is the sweep's default scope **all packages** or **changed-since-a-ref**?
3. Should the **per-bundle prebuilt runner** be raised as an issue on the linter repository now? It
   is the dominant efficiency lever, it benefits CI identically, and it is not a Workspace change —
   so absorbing it locally would be solving someone else's problem in the wrong place.

## Adjacent open items

**Whether a separate linting skill should exist.** The rule-authoring material currently lives in
the workspace skill, whose description advertises running builds, tests and probes — so the
material's actual audience has no reason to load it. That routing argument is the surviving one;
two earlier arguments did not survive contact (an anchor-content argument, when the rulings it
depended on were deleted as already-stated; and a context-budget argument, when the mechanical
limits it appealed to were retired).

**Where it is weakest**, stated plainly: if the corpus is organised as hubs plus on-demand
companions, the material can live as a workspace companion reached by a pointer from the Swift
skill, and no separate skill is needed. The corpus has since been reorganised that way. **The test
that settles it: can a companion be routed to from a *different* skill, or only from its own hub?**
If only from its own hub, an agent must still load the wrong skill to discover it and the routing
defect survives. Apply the test to what exists; do not re-argue it.

**The rethrows list needs re-probing.** The Swift conventions enumerate which standard-library
`rethrows` functions preserve typed throws. At least one entry is wrong in the direction that costs
authors work — it drives them to materialise a result inside the closure and unwrap outside, for a
function that does not need it. Only that one entry was probed. **A list wrong in one entry earns
suspicion of the others**; probe the whole list under a negative control.

## Method note

Four habits produced every correction recorded here, and they are cheaper than the errors they
prevent.

**Check a tool's behaviour against the tool, not against the prose describing it.** A confident,
mechanism-level claim about a failable initializer was wrong for the corpus's entire life because
it sounded authoritative and nobody had cause to look.

**A finding from one vantage point is not a finding about another.** Name the vantage in the
finding itself. The local-versus-CI conflation above cost a programme status and an objective.

**A zero needs a positive control.** Exit status attests that a process ran, never that it was
configured. Where a summary line exists, it *is* the control — assert it.

**Re-check counts that surprise you.** A coverage figure here was nearly reported inverted because
search-depth flags were relative to each search root rather than to the tree; the corrected figure
was 97 percent where the first read suggested 21. If a number implies a dramatic finding, the
first hypothesis is that the measurement is wrong.

And state, in the report itself, which claims were checked and which were assumed. That separation
is what makes a handoff usable.
