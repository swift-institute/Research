# Workspace Lint Capability — Implementation Record

<!--
---
version: 1.0.0
last_updated: 2026-07-28
status: IMPLEMENTED
tier: 2
scope: ecosystem-wide
---
-->

Successor record to `workspace-lint-capability-state-of-the-question.md`. That document set the
design; this one records what was built, what was measured, what the starting position got wrong,
and which claims here are checked versus assumed. Companion:
`enforceability-taxonomy-and-honest-voice.md`, and §16 of the org convergence-discipline register,
which carries one lesson from this work in general form.

Implementation: `Workspace` branch `lint-capability`, commit `ce307e4`.

## What was built

Two entry points, one implementation.

- `workspace package lint` — one package. Takes no arguments: from anywhere inside a package it
  walks up for the package root and again for the installed binaries. Reads no inventory,
  enumerates no organisation.
- `workspace lint` — the ecosystem sweep, enumerating from the inventory, with `--changed` for
  packages carrying local work.
- `workspace lint install | check` — acquire, verify and pin the binaries; compare against the
  build CI consumes.
- `workspace doctor` gains a `linter` check.

Both modes call one measurement function. There is no second implementation for them to disagree
through, which is the parity requirement turned inward.

## Parity, and the limit of the claim

CI's invocation is reproduced argument for argument: the same binaries from the same rolling
`ci-binaries` release, verified against that release's own checksum file, invoked as
`swift-linter <package-root> --exit-policy strict` with the prebuilt standard runner provisioned
on the child environment. Workspace sets that environment variable itself on the spawned process;
a developer's shell profile is never written, because a per-developer environment variable is
machine-specific by construction.

**Demonstrated against a real CI run rather than inherited.** A CI run on a foundations package,
2026-07-27, installed composite digest `e837b75b…` and printed
`consumer · 93 active rules · 56 files linted · 10 violations`. A local run of that same digest
against that same package printed the same three counts. The leading label differs because it is
the last component of the path passed and CI checks out into a directory named `consumer`.

**Retire "byte-identical".** The starting position recorded a byte-identical summary line. The
measured fields are identical; the label cannot be, as long as CI checks out to `consumer/`.
Precisely stated beats impressively stated.

**The limit, which must not be compressed.** The release tag is rolling, and it moved within a
day: a run fifty minutes earlier used a different composite digest — same engine revision, a
different rule pack. So the capability establishes **"you are running what CI would install right
now"**, not **"what CI ran on a past run"**. For someone about to open a pull request that is the
right question, but it is weaker than "matches CI" sounds. Do not let it be shortened to that.

## Correction to the starting position

The state-of-the-question recorded that the prebuilt runner covers only bare-primitives consumers,
that the remaining 233 packages fall through to a per-invocation compile, and that this is the
dominant cost and the main efficiency lever. Its third open decision — whether to raise a
per-bundle runner issue upstream — rested entirely on that.

**It is not true of the release CI consumes.** Three checks:

1. At the **released engine revision named in the release's own build manifest** — not `main` —
   the baked-bundle vocabulary carries primitives, standards *and* institute, and the runner bakes
   all three.
2. A census of all 433 consumer configuration files against the classifier's actual admission rule
   (a bare baked-bundle expression, or an exclusion list over one, and no parent-inheritance
   directive): **431 take the prebuilt fast path.** The two exceptions are the universal rule
   pack's own self-lint, deliberately not baked, and one package that activates an inline rule.
3. Running the released binary with the runner provisioned: packages in all three bundles lint in
   seconds.

**Open decision 3 dissolves.** There is no upstream issue to raise; it is already implemented and
shipping.

*Labelled as a guess:* the earlier measurement most likely ran without the runner environment
variable set, which would also explain its 8.33 s figure for an institute package. That run was
not reproduced, and the explanation is offered as unverified.

The general lesson is the one the starting position itself recorded and this work then had to
apply to that document: **check a tool's behaviour against the tool, not against the prose
describing it** — including prose you were told not to rederive. A handoff can be careful and
still carry a stale measurement.

## A run cannot report clean without having measured something

The engine ships rule-pack-agnostic: without a reachable configuration, zero rules fire. Three
invocations exit zero having printed **nothing at all** — a directory holding source but no
consumer configuration, a *file* path rather than a package root, and an empty directory. Exit
status attests that a process ran, never that it was configured.

The engine's always-on summary line is therefore the only positive control available, and every
run is adjudicated against it. A missing line, zero active rules, or zero files scanned reports
UNMEASURED — never clean — per package inside the sweep as well as alone. A file path is resolved
to its enclosing package, which is linted whole with diagnostics narrowed afterwards, so the
silent-zero invocation is unreachable through the capability. A sweep that enumerates a populated
inventory and materializes nothing refuses, rather than reporting an empty ecosystem clean.

Exit vocabulary follows the existing doctor: 0 measured and passing, 1 measured with
error-severity findings, 2 something could not be measured. Two outranks one deliberately — a
violation is a fact about the code; an unmeasured package is the absence of any fact.

### Made to fail on purpose, through the real path

Fixtures were not treated as sufficient, because a family of validators in this fleet passed every
fixture and still scanned the wrong tree. Six probes through the built executable:

| Probe | Result |
|---|---|
| Inventory package with no consumer configuration, single-package mode | UNMEASURED, exit 2 |
| Invoked where no package manifest exists above | loud error, exit 1 |
| A **file** path | resolved to the package root and linted; real summary |
| Sweep against a hierarchy where a populated inventory materializes nothing | refuses, names the count and the root |
| Sweep over a mixed population (measurable / unconfigured / absent) | per-package UNMEASURED, absent packages named, exit 2 |
| Tampered binary, tampered manifest, asset missing from the checksum file | install refuses; nothing recorded |

The checksum and parity gates run end to end against a local origin in **both** directions — an
intact release installs, a release with one byte changed after publication is refused. A gate only
ever observed passing is an assertion about the code, not evidence about it.

## What was measured

All figures were taken on a shared machine under concurrent builds from other sessions. Per §13 of
the convergence-discipline register, the wall clocks are reported as a range with their conditions
and the decomposition is reported separately, because contention inflates parts and whole together
and therefore corrupts absolute figures while leaving ratios intact.

| | Figure | Conditions |
|---|---|---|
| Single package, no arguments | **2.6 s** | concurrent builds present |
| Install (download, verify, record) | **6.1 s** | — |
| Changed-scope sweep, 441 packages | **11.5 s** | selected 10 |
| Full sweep, 441 packages | **393 s** | steady state; load average 62–80 |
| Full sweep, first ever run | **935 s** | includes first-time dependency resolution for the eval-path packages; load average 71 rising to 118 |

Sweep content: 16,127 files scanned, 25 clean, 404 with violations, 12 UNMEASURED, exit 2. Engine
time summed across packages 2747 s against 393 s wall — 7× effective parallelism.

**Which end to trust:** 393 s is the steady-state figure and the one to plan against. 935 s
included one-time work that does not recur. **A genuinely quiet machine never materialised** —
five concurrent build sites plus desktop load persisted through the working period, and a
scheduled quiet window was released against a machine that had already been told to resume, so the
first attempt was contaminated. A third measurement was declined rather than taken at a higher
load than the existing ones, per §13's disposal rule: publish the range with its conditions rather
than letting one uncontrolled number harden into a citation.

**Load-robust decomposition.** Two packages accounted for 352 s of the 2747 s of engine time, and
the five slowest for roughly 22%. That decomposition survives contention even where the totals do
not, and it is what made the next finding legible.

**An estimate that was wrong by 3.3×, recorded as method rather than apology.** A
pre-implementation estimate of "roughly two minutes" for the full sweep was extrapolated from a
six-package sample taken on a quieter machine. Against the steady-state figure it was wrong by
**3.3×**; against the first-ever run, by **7.8×**. Two causes, and only the first was avoidable:
the sample was drawn from small packages and missed a long tail, and two packages spent minutes
each on a build doomed by an upstream break nobody knew about yet.

The correction was not to estimate better but to make estimation unnecessary — the sweep now
reports its own per-package durations and names its slowest packages, so the *next* figure is
checkable rather than trusted. **An extrapolation from a convenience sample is a guess wearing a
number's clothes**, and the tell was that the sample was chosen for being easy to run rather than
for being representative.

## The scope filter that cost more than the work it avoided

The changed-scope sweep first measured **61 seconds while linting zero files**. All of it went to
deciding *which* packages to lint — a Git interrogation per repository, run one at a time, roughly
two thousand subprocesses to avoid roughly four hundred lint invocations. Routing the
classification through the same bounded concurrency as the measurement took it to **11.5 seconds**,
on a busier machine.

Recorded in general form as §16 of the org convergence-discipline register. The short version: a
scope filter is work, it must be instrumented separately from the work it selects, and selectivity
is not cheapness — one is a property of the output and the other of the input, and the filter pays
for the input every time.

## Findings that belong to others

**An upstream break, found latent and then confirmed live.** The two packages that take the eval
fallback returned UNMEASURED rather than merely slow. The cause is a source-compatibility break on
`main`: a filesystem package collapsed a read operation's typed-throws form at 2026-07-28 12:45Z,
and a manifest package that consumes it has a head from the previous day and has not followed. The
eval path resolves both from `main` at invocation time, so it no longer builds. CI's last green run
on the affected package predated the break by 16 hours, so nothing had surfaced it. Only 2 of 441
packages take that path; the other 431 use the prebuilt runner and are unaffected.

This was first recorded here as a **prediction** — that the next CI run on an affected package
would fail its gating lint leg — because the local finding was a macOS observation and a finding
from one vantage point is not a finding about another. A CI run was then dispatched with
authorization, and **the prediction is now a fact**: the lint leg failed on Linux at the same
file, the same line, and the same diagnostic as locally, under the pinned Swift version. Ownership
of the repair was placed elsewhere.

**That run failed two substantive legs, not one, and the second is unrelated.** The nightly Linux
leg crashed independently — a `libdispatch` runtime crash (`_dispatch_event_loop_drain`, thread
`DispatchWorker`, bad pointer dereference) under a 6.5-dev toolchain with assertions. It is
neither the typed-throws break above nor the compiler abort tracked separately by the fleet. A
reader taking that run as confirmation of the typed-throws break alone would be reading it as
narrower than it is.

Two notes on how that was found, because the manner matters more than the fact:

- The first report of this run named **one** failed leg, because the query filtered job names for
  the one expected to fail. Enumerating the run's jobs unfiltered showed **four**: the two
  substantive legs plus the two `ci-ok` aggregates that failed as a consequence. This is §16's
  enumeration trap committed while writing §16 — a filter built from what you expect to find
  cannot report what you did not think of, and the omission was caught by a reviewer rather than
  by the instrument.
- **The nightly leg sits inside the gating aggregate**, so a Swift *nightly* regression can redden
  any repository in this fleet on a day nothing in the repository changed. It is not always
  scheduled — on at least one other package that leg was skipped — so the exposure is
  intermittent rather than constant. Whether a nightly toolchain should gate is a real question
  and belongs to whoever owns CI policy; recorded here only as an observation made in passing.

The sequence is the point. The local capability surfaced a break in CI's own path **before CI had
run into it**, and it did so by refusing to call an unmeasured package clean.

**This is the design working, not a shortfall.** A broken tool path surfacing as *nothing was
measured* rather than *no violations found* is the entire reason the capability was worth
building. Had the UNMEASURED guard not been there, two packages would have been reported clean on
the strength of a build that never ran.

### The packages reporting UNMEASURED, by name

The condition attached to decision 3 is that each ends up either carrying a consumer
configuration or explicitly recorded as out of scope. The list belongs in the record so that
shrinking it is the obvious thing to do with it, and so a tenth entry appearing is legible as an
alarm rather than as more of the same.

**Ten with no consumer configuration** — `swift-percent-primitives`;
`swift-certificate-verification`, `swift-image-magick`, `swift-money`, `swift-resource-pool`,
`swift-server-dependencies`, `swift-server-static`, `swift-sitemap`, `swift-splat`,
`swift-svg-printer`.

**Two whose configuration cannot currently be evaluated** — `swift-carrier-primitives` and
`swift-linter-rules`, both blocked by the upstream break above. These are expected to clear
without any change to either package once that break is repaired, and are not candidates for an
out-of-scope record.

**Nine packages dirty on an abandoned branch.** The changed-scope filter selected exactly nine
packages, and those were exactly the nine carrying no consumer configuration. Checked rather than
accepted as coincidence: all nine sit dirty on the same unfinished standardization branch with no
upstream. Two symptoms, one cause. Routed to the session owning that cohort.

## The sweep takes no coordinator lock, and that is a hazard as well as a feature

Every build routed through the Workspace coordinator serializes on a single machine-wide advisory
lock, so effective parallelism across *coordinated* work on one machine is 1.

**The lint sweep does not take that lock.** It spawns the linter binary directly, and where the
eval fallback shells out to the package manager it does so raw rather than through the
coordinator. Two consequences, and the second is easy to miss:

- A lint sweep does not queue behind a running build, which is what makes it usable at all while
  the machine is busy. Timing it is an ordinary contention problem, not a lock-waiting one.
- **A sweep therefore races every coordinated build on the machine, and neither side can tell.**
  The lock exists precisely to stop concurrent package-manager work from colliding, and the eval
  path performs exactly that kind of work outside it.

This matters for scheduling any measurement — a window arranged by pausing coordinated builds does
not quiet uncoordinated ones — and it is a third instance of work bypassing that lock. Recorded so
the next person does not have to rediscover which side of the lock this capability sits on.

## Decisions taken

Adjudicated by the Team Lead; recorded here because the reasoning is the transferable part.

1. **Digest divergence from the build CI consumes fails `lint check` and `doctor`, and never
   blocks a lint run.** The run prints the digest it used and neither checks nor contacts the
   network. Refusing to lint because of an upstream republish the developer did not cause and
   cannot fix produces no parity — it produces nothing. `check` and `doctor` are where a hard
   failure has somewhere to go. A lint result should carry the digest that produced it wherever it
   travels, because a result without its provenance becomes an unfalsifiable claim once it leaves
   the terminal.
2. **The sweep defaults to all packages**, with changed-scope as explicit opt-in. A default that
   silently narrows the population is indistinguishable from a sweep that found nothing, and that
   is the family of defect this fleet spent the surrounding days removing.
3. **Deliberate gaps are recorded rather than left red.** This one was adjudicated twice in
   opposite directions before settling, and the settled form is better than either starting
   position.

   A package with no consumer configuration measured nothing, and the sweep refuses to call that
   clean. Left alone that meant exiting non-zero on day one and every day after — the inert-gate
   family, where the signal survives and nobody reads it. **A gate that is always red gates
   nothing.**

   The resolution is a checked-in allowlist recording where the absence is deliberate: listed
   means reported and counted but not failing; unlisted still fails loudly. Chronic red goes, the
   alarm stays.

   The objection to an allowlist — that it becomes a second place a package's lint status is
   declared, alongside the configuration file that is already CI's activation signal, and two
   sources for one fact is how they drift — is answered mechanically rather than by discipline:
   **an entry for a package that does carry a configuration is an error**, as is an entry naming a
   package outside the inventory, or one listed twice. The configuration file stays the single
   authority; the allowlist records only its deliberate absence, and a stale record fails loudly
   instead of quietly excusing a package that no longer needs excusing. Every fault is reported at
   once, because a list corrected one error per run is a list nobody finishes correcting.

   The recorded state is its own verdict rather than either neighbour. Folding it into *clean*
   would overstate coverage; folding it into *unmeasured* would restore the permanent red. And the
   single-package path never reads the allowlist — asked to lint a package, "nothing here is
   configured" is a failure to deliver what was asked, whatever the ecosystem-level policy says.
   That also keeps the fast path free of inventory reads.

Two finer calls: an absent linter is a **warning** in doctor, so a bare clone that never installed
still passes, while divergence once installed is an **error**, because that one produces
authoritative-looking answers that disagree with the gate. And changed-scope means "unclean
worktree, or commits not in the tracked upstream", **per repository** — a single shared ref has no
meaning across hundreds of independent histories, so none was invented. A repository whose state
cannot be read is **included**, never skipped.

## A claim retracted

An early report stated that a lint run "writes nothing into any package worktree". That was
verified on one bare-bundle package and generalised to the whole tree. It is wrong: the engine
writes ignored generated state into some packages — an eval project for eval-path consumers, and a
short-lived selection manifest for consumers that exclude rules from a bundle. All affected
packages were checked: the state is ignored by version control and no worktree was dirtied, and
the multi-gigabyte eval trees created by the sweeps were removed afterwards. But the claim was
wrong before it was checked, and a successor inheriting "writes nothing" would have built on it.

Two smaller engine-side observations, reported rather than patched around, since Workspace should
not reach into another tool's state directory: the eval path leaves multi-gigabyte build caches
inside package worktrees, and selection manifests accumulate one per run with nothing removing
them.

## What is checked and what is assumed

**Checked, first-hand:** the CI invocation and asset provenance, read from the workflow; the
released engine revision's classifier and baked bundles, read at the released revision; the
fast-path census across all 433 consumer configurations; the three silent-zero invocations
reproduced on the released binary; parity against a named CI run at the same digest; all six
failure probes through the built executable; both directions of the checksum and parity gates; the
upstream break's two commit timestamps and CI's last green run; the nine packages' branch and
worktree state.

**Assumed, not checked:** that the earlier contradicting measurement ran without the runner
environment variable set; and that the steady-state sweep figure would improve materially on an
idle machine, which never existed to test against.
