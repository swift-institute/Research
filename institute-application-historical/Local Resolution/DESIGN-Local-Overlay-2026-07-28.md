# Design — the local overlay

**Status:** proposed, not implemented · **Date:** 2026-07-28
**Objective (principal, verbatim):** *"capability to do local development on single,
multiple, or all swift-institute packages as if each `Package.swift` had local path
based dependencies instead of URL based ones"* — without ever committing a
path-based manifest.

**Standing:** the principal's override of 2026-07-28 **overturns all prior research
and decisions on this topic**, including ADR-001's choice of generated
`.package(path:)` composition and its retirement of `swift package edit`. This
document is written from first principles and does not inherit those decisions.
Prior *measurements* are treated as evidence rather than authority; every fact
load-bearing for this design was re-measured today against the pinned toolchain.

**Standing rule this document asserts, at the Team Lead's direction:** *prior
measurements survive; conclusions built on them lapse.* Discarding evidence and
discarding conclusions are different acts, and an override does only the second.
ADR-001's executed spike findings are therefore carried forward as facts even
though its Decision is superseded.

**Vantage.** Everything below was measured on one macOS 27.0 machine, Swift 6.4
(`swiftlang-6.4.0.27.1`), Xcode 27.0 at `/Applications/Xcode-beta.app`,
`~/.swiftpm/configuration/` empty. Mechanism experiments ran on throwaway fixtures
in a session scratchpad with `file://` remotes; census and latency figures come
from the real checkout and from `github.com`. **No institute package worktree or
`.build` directory was written to.** Nothing here is a claim about CI, about Linux,
or about Xcode — the Xcode gap is called out explicitly as untested.

**Build system and manifest floor, stated because both moved recently.** At Swift
6.4 `--build-system` **defaults to `swiftbuild`**; `native` and `xcode` are
deprecated. The whole prior `Research/Local Resolution` corpus was measured on
Swift 6.3.3 under the *old* default, so none of it is inherited here. The
load-bearing results below were taken **on both build systems** and at
**`swift-tools-version: 6.3.3`** — the floor the ecosystem actually sits on, which
cannot move to 6.4 until a Linux container exists. Where a result is
build-system-specific or tools-version-specific this document says so; the
overlay's behaviour was identical on both.

**This document discharges the spike the founding implementation plan owed.**
`WORKSPACE_LOCAL_RESOLUTION_IMPLEMENTATION_PLAN.md` §7.1 already names
`swift package edit --path` as *Backend A, the first implementation candidate*,
and lists nine open questions no production architecture may assume past. Seven are
answered below; §7 records the two that are not, and §4 records the one whose
answer contradicts the plan's own required behaviour.

---

## 1. Summary of the recommendation

Build the overlay on **`swift package edit --path`**, owned end-to-end by the
Workspace CLI, with the roster and the hierarchy root as its only inputs.

The principal's proposed distinction — *local state is acceptable when generated,
unacceptable when authored* — **holds for SPM edit, and I could not break it.** The
editable state is a symlink and a JSON entry, both produced by a command, both
derived from committed inputs (`Workspace.json` + "the root is the parent of the
`Workspace` checkout"), both gitignored in 433 of 441 packages. A contributor
configures nothing. A fresh clone plus `workspace sync` plus one overlay command
yields the same graph on any machine.

That is the good news. Four things stand between it and a shippable capability, and
they are the substance of this document:

1. A **quiet-degradation path** that is real, reproducible, and already present in
   this tree today (§4).
2. A **velocity claim that is now measured** — and it holds, but not for the
   reason the framing assumed (§3, §3a).
3. A **cost at scale that is quadratic in graph size but bounded in practice** —
   median closure 36, so 49 s to overlay entirely; the ~18-minute figure is the
   flagship consumer, not the typical one. **No second mechanism is needed**
   (§6, §6a, §6b).
4. **Eight packages that would let the overlay's own artifact be committed**, and
   **eight more that the overlay structurally cannot reach** (§7).

---

## 2. What `swift package edit` actually does — measured, not described

Fixture: consumer declaring a dependency by URL; dependency worktree carrying an
**uncommitted** marker so that "local source was compiled" is decidable.

| Question | Result |
|---|---|
| Is `Package.swift` modified? | **No** — byte-identical throughout |
| Is `Package.resolved` modified? | **No**, unless the local manifest itself changes the graph (see below) |
| Where does the state live? | `<root>/.build/workspace-state.json`: `state.name = "edited"`, `state.path = <absolute>`, with `basedOn` retaining the prior `sourceControlCheckout` |
| What lands in the worktree? | one symlink, `<root>/Packages/<identity> -> <absolute path>` |
| `git status` afterwards | `?? Packages/` — untracked, and **not ignored by default** |
| Is local source really compiled? | **Yes** — positive control: uncommitted marker present in compiled products; negative control: canonical marker absent from `.build` entirely |
| Does it work on a **transitive** dependency? | **Yes** — a root package can redirect a dependency it does not declare, and the whole graph recompiles |
| Does it work under `branch:` requirements? | **Yes** — which matters, because **2,137 of 2,188** institute edges are branch-based |
| Does it bypass version solving? | **No.** `edit` first requires the package to be *placeable*. Against an unsatisfiable requirement it exits **1** with the resolver's own error |
| Does the edited manifest drive resolution? | **Yes** — a dependency added only in local source is fetched and compiled, and `Package.resolved` gains its pin |
| Does `unedit` restore? | **Yes, completely** — see §5 |
| Local checkout declares a different package/target name? | **Fails loudly** — exit **1**, *"target 'Dep' referenced in product 'Elsewhere' could not be found"* |
| Edited package drops out of the graph entirely? | **Overlay lingers** — build green, `edited` entry retained, `Packages/` residue kept. Stale, not wrong, but `status` must surface it (§7) |
| Honoured under `--build-system native`? | **Yes** — verified in a clean room, marker in `arm64-apple-macosx/debug/Dep.build/Dep.swift.o` |
| Honoured at `swift-tools-version: 6.3.3`? | **Yes** — the manifest floor, not just 6.4 |
| Accepts `--scratch-path`? | **No** — exit **64**. This is consequential; see §4a |

Two consequences worth stating separately.

**The version requirement is still enforced; the *content* is not.** `edit` swaps
the source tree for an already-resolved slot. So the overlay cannot manufacture a
graph that could not exist — but it can and does compile source that corresponds to
no commit anywhere. That residual is the entire point of the feature, and it is
what §5's parity report exists to make visible rather than to prevent.

**Under a full overlay, a build contacts no remote at all.** Sixty packages, every
one edited, remote repositories physically removed from disk: build green, all
sixty local markers in compiled products. The negative control fires — `unedit` one
package and `swift package update` exits **1** on the missing remote — so the green
is a measurement and not an absence.

---

## 3. Baseline first — the rebuild saving is small; the re-resolution saving is not

The brief is right to demand this, and the honest answer is uncomfortable.

Measured, same fixture, marker-verified in compiled products every round:

| Loop | Round time |
|---|---|
| **Today:** change → commit → push → `swift package update` → build | 4.65 s / 6.07 s / 5.57 s |
| **Overlay:** change → build | 3.67 s / 3.42 s / 3.37 s |
| One-time `edit` | 0.70 s |

**~1.9 s per round.** Against a `file://` remote, one dependency, no review, no CI.
On this evidence alone the capability would not be worth building.

The measurement is not the claim, though, and the gap between them is where the
real cost lives. What the fixture excludes:

- **Remote round-trips.** Median `git ls-remote` to `github.com` over a random
  sample of 20 roster packages: **0.48 s** (max 0.56 s, 20/20 succeeded). Under
  branch-based dependencies `swift package update` must ask every branch-pinned
  remote for its tip. The flagship consumer, `Workspace/Application`, carries
  **200 pins**. Sequentially that is **~96 s of pure ref round-trips per
  cross-package change**; SwiftPM parallelises fetching, so treat 96 s as an upper
  bound on that component, not a measurement of it.
- **Commit, push, review, and CI**, which I did not measure and which dominate any
  seconds-level figure.

So the defensible statement is: **the overlay removes commit, push, and
re-resolution from the inner loop entirely, and with them a term that scales with
the number of branch-pinned remotes in the closure.** It does not make an
individual rebuild meaningfully faster.

### 3a. The deciding measurement — taken, and it is the whole case

The gate on implementation was one number: a real warm `swift package update` at
`Workspace/Application`'s 200 pins. Taken 2026-07-28, from a copy of that
package's `Package.swift` and `Package.resolved` in a scratchpad — no institute
`.build` touched — against a warm shared repository cache (321 entries), warmed
further by a full `resolve` first (**73.9 s**, 200 pins).

> ## **`swift package update`, warm, 200 pins: 148 s and 329 s.**

**Two runs of one command, and they disagree by 2.2×.** That spread is the first
thing to report, because the single number I first wrote down was the higher one,
and quoting it alone would have put a measured-looking constant into the record
that the very next run refutes.

**The cause is contention, and it was mine to control and I did not.** Enumerating
live build processes afterwards found four `swift-frontend`/`swift-build`
processes belonging to other sessions on this machine throughout, and run 1
additionally began immediately after my own 200-pin `resolve`. The script that took
the measurement even labelled the machine "otherwise quiet" while it demonstrably
was not — an assertion in a comment is not a measurement of the thing it asserts.

**What survives, stated at the precision the evidence supports:**

| Claim | Status |
|---|---|
| `update` at 200 warm pins costs **~2.5–5.5 minutes**, contended | defensible |
| The **148 s floor** is the more trustworthy end — less contention, not more | defensible |
| A specific figure such as "329 s" | **not defensible** — do not quote it |

**The decomposition is unaffected, because it is not a wall clock.** It sums the
per-repository timings the tool prints itself, so contention inflates the parts
and the whole together and the *ratio* survives:

| Phase | Cost | Against projection |
|---|---|---|
| 200 remote fetches | **106.5 s**, median **0.52 s** each | projected 96 s from `ls-remote` — **accurate to 11%** |
| version solving over the branch-pinned graph | the majority of the remainder | **not modelled at all** |

So the `ls-remote` projection was right about the component it modelled and wrong
about which component dominates: **the tax is mostly the resolver, not the
network.** I had told the fleet the opposite. Worth recording rather than quietly
replacing, because the conclusion strengthened while the reasoning behind it did
not survive.

**The gate still clears, and comfortably.** The question was whether this comes
back at a few seconds. It does not: the floor is ~150 s. Every cross-package change
under the current scheme pays **at least two and a half minutes** of re-resolution
before a consumer sees it, on top of commit, push, review and CI — per *change*,
not per session. The ~1.9 s per-round figure above remains the honest statement
about rebuild speed, and both are true: **the overlay is not a faster compiler; it
is the removal of a multi-minute round trip from every cross-package edit.**

Vantage: one machine, warm cache (321 shared repository-cache entries), under
uncontrolled concurrent load from other sessions. A cold cache would be worse, not
better. Version-solving cost is a property of this pin set and would differ for a
smaller consumer. **Any re-measurement should record the concurrent build-process
count beside each timing** — contention here is a variable to record, not one that
can be assumed away on a shared machine.

---

## 4. The failure mode to design against, reproduced

The brief names it exactly: *a developer believing they are testing local source
when they are not.* It exists, it is deterministic, and this tree already contains
one instance of it.

**Delete `.build` under an active edit and the overlay silently disappears while
looking applied.**

```
edit applied      → Packages/dep -> …/dep      state: edited
rm -rf .build     → Packages/dep -> …/dep      state: (gone)
swift build       → Packages/dep -> …/dep      state: sourceControlCheckout
                    exit 0 · canonical source compiled · local marker absent
```

The symlink survives, because it lives in the worktree. The `edited` entry does
not, because it lives in `.build`. The next build resolves canonical, succeeds, and
says nothing. `swift package unedit` in that state exits **1** with *"dependency
not in edit mode"* — SwiftPM is not confused, but nothing consults it.

This explains a finding recorded as *unresolved* in
`Repository Safety Inspection` §4.3 and `Owner Capability Matrix` §3.3:
`Application/Packages/swift-git` is a live edit symlink while `workspace-state.json`
records `remoteSourceControl`. That was not a mystery. It is what deleting `.build`
under an edit leaves behind, and it is sitting in the checkout now.

Reproduced on **both** build systems — `swiftbuild` and `native` — so this is a
property of workspace state, not of a build engine. It is also not
tools-version-specific: reproduced at `6.3.3`.

A second, adjacent path: a `workspace-state.json` SwiftPM cannot decode is
**discarded whole** — including valid entries — with a single
`warning: unable to restore workspace state: …` and **exit 0**. I hit this by
writing a malformed file: sixty edits vanished and the build went green against
canonical. A warning inside a thousand-line build log is not a gate.

### 4a. The scratch-path finding — and why it lands the right way up

The founding plan's Backend A requires, as step 1 of its required behaviour,
*"assign an isolated context-specific scratch path."* **That is not achievable
with `swift package edit` at Swift 6.4, and the plan could not have known it.**

`swift package edit` **rejects `--scratch-path`** — exit **64**, usage error; its
entire option set is `--revision`, `--branch`, `--path`. Editable state can
therefore only ever be written to the *default* `.build`. But `swift build`,
`resolve` and friends **do** accept `--scratch-path`. The two halves disagree, and
the consequence is measured:

| Apply overlay to | Build with | Result |
|---|---|---|
| default `.build` | default `.build` | overlay live — local marker compiled |
| default `.build` | `--scratch-path <ctx>` | **overlay invisible** — canonical compiled, state records `sourceControlCheckout`, **exit 0, no comment**, while `Packages/` still claims the overlay |

That kills two of the founding plan's ambitions outright: **isolated per-context
scratch paths are not available to this backend**, and **two contexts for one root
cannot coexist** by that means (plan §7.1 open questions 1 and 6, answered
negative).

**And then it lands the right way up, which I did not expect.** The Workspace build
coordinator assigns a scratch path in exactly one case:
`Build.Coordinator.freshScratch` returns `nil` unless `fresh: true`
(`Build.Coordinator.swift:158–176`). So:

- **an ordinary coordinator build uses the default `.build` — the overlay is
  honoured**, which is what the inner loop needs;
- **a `--fresh` coordinator build or test gets a unique scratch directory — the
  overlay is bypassed by construction**, which is what a pre-PR gate needs.

`--fresh` is already the institute's documented pre-PR gate (*"the package passes a
fresh coordinator test from its own repository"*). It therefore **already is** the
clean-room check that ADR-001 Consequence 2 made mandatory and that the founding
plan §4.5 demanded alongside local validation — and it is overlay-free without
anyone remembering to make it so. The mechanism and the discipline compose.

**The one change required is a sentence, not a mechanism.** Today that divergence
is silent: a developer running `--fresh` under an active overlay gets canonical
source with nothing said. The coordinator must **state** that it bypassed an
active overlay, and `status` must name `--fresh` as the way to check remote
reproducibility. A correct bypass that looks identical to a forgotten overlay is
the same failure as §4 wearing better clothes.

**Design consequence — and this is the argument for Workspace owning
reconciliation rather than trusting SwiftPM's state.** The whole-file discard is
the sharp version: SwiftPM's response to state it cannot parse is to drop *all* of
it, including entries that were valid, and continue green. Sixty edits vanished
that way in one command. A capability whose correctness rests on SwiftPM reporting
its own state faithfully has no recourse when SwiftPM's own answer is *"I have
discarded the question."* The overlay's state is *two* facts that can disagree,
SwiftPM will not reconcile them, and under one common failure it silently forgets
both. Workspace must own that reconciliation:

- `workspace overlay status` compares the symlink set against SwiftPM's own
  `edited` entries and **exits non-zero on any disagreement**, naming each package
  and which half is missing.
- Every overlay-mode build goes through a Workspace command that runs that check
  **first** and refuses to proceed on a mismatch. Half-applied is an error, never a
  fallback.
- Repair is `workspace overlay apply` re-run — verified idempotent: re-editing over
  a stale symlink succeeds and restores the `edited` entry.

---

## 4b. The capstone acceptance test — principal's, and it passes

Adopted from the principal verbatim: *"if the SPM/Workspace session is successful
in meeting its objective, likely we'll be able to build without needing any local
`Package.resolved` — perhaps that is a useful capstone test."*

It is a better criterion than anything in §9 because it tests the objective in one
observable rather than the mechanism piecewise: **if every dependency is
materialised locally there is nothing left to resolve.** Run strictly — every
cache cleared, so a pass cannot come from warm state:

| Step | Result |
|---|---|
| Apply overlay to the full closure (`mid`, `low`), cold `.build` | applied |
| Delete `Package.resolved`, delete `.build/checkouts`, **remove the remotes from disk** | — |
| `swift build` | **rc 0** |
| Local uncommitted markers in compiled products | `LOW-OVERLAY` **2**, `MID-OVERLAY` **2** |
| Canonical marker in compiled products | `LOW-CANON` **0** |
| `Package.resolved` recreated? | **No — there was nothing to resolve** |

**Both negative controls fire**, which is what makes the green evidence:

- **`--fresh`-equivalent** (`--scratch-path`) under the same conditions: **rc 1**,
  *"repository does not exist"*, zero overlay markers in that scratch. The bypass
  of §4a is confirmed from the other direction — a `--fresh` build **must not**
  pass this test, and it does not.
- **Overlay removed**, cold `.build`, same missing resolved file and remotes:
  **rc 1**. So the capstone's pass is attributable to the overlay and not to the
  fixture.

**A weak first control, recorded because the correction is the finding.** My first
attempt at the second control returned **rc 0** where I expected failure. The cause
was not the capstone: `swift package unedit` restores working copies from
`.build/checkouts`, which survives both `unedit` and the removal of the remotes, so
the build succeeded from a warm canonical cache — compiling `LOW-CANON`, which is
how I caught it. **`.build/checkouts` is a second cache that can make a build
succeed offline against canonical source with no overlay at all.** Any claim that a
green build proves local source was used must clear it, exactly as any claim about
the overlay must clear `.build`.

### The limit this test exposes: the overlay can be *used* offline but not *applied* offline

Applying the overlay to a cold `.build` with the remotes absent **fails, rc 1** —
`swift package edit` requires the package to be resolvable before it can redirect
it (§2). So the capstone claim must be stated with its precondition:

> **Once applied, the overlay needs neither `Package.resolved` nor any remote.
> Applying it needs a resolvable graph — network, or warm caches.**

That is a genuine constraint on the capability, not a caveat about the test. First
overlay application on a fresh machine is online; everything after it is not.

---

## 5. Reversibility and parity

**Off is a command, and it is complete.** `swift package unedit` removes
`Packages/` entirely, restores `sourceControlCheckout`, re-creates the canonical
working copy, and the next build compiles canonical source with the local marker
gone from products — verified with both controls. **The developer's uncommitted
work in the dependency worktree survives**, which was the invariant ADR-001's
Finding 3 demanded of any removal.

This is the sharpest difference from the mirror mechanism ADR-001 measured. That
mechanism was *sticky*: deleting its configuration left local source compiled and
recorded a pin pairing a canonical location with a revision absent from it —
green locally, impossible remotely. **`unedit` has no such behaviour.** I looked
for it and it is not there.

**Parity is decidable, not merely assertable.** A build under the overlay agrees
with a build without it exactly when every overlaid checkout is clean and sits at
the revision its pin names. Both halves are cheap to compute, per package:

```
git status --porcelain      → empty?
git rev-parse HEAD          → equals the pin's revision?
```

So `workspace overlay status` should report, per overlaid package, one of:
**identical to pin** (parity holds), **clean but ahead/behind** (reproducible once
pushed and re-resolved), or **dirty** (this build is reproducible nowhere). The
third is not an error — it is the feature — but it must be *stated*, and it is the
answer to "which mode am I in".

Mode visibility must be read from SwiftPM's resolved state, never inferred from a
ledger. The existing `Workspace.Composition.verify` already does exactly this and
is the one piece of the current surface worth carrying forward.

---

## 6. Scale

Census of the real tree, enumerated rather than sampled:

| Fact | Value |
|---|---|
| Roster packages | **441** — all 441 materialized with a `.git` |
| Declared `url:` dependency edges | **2,188** |
| …resolving to a roster package | **2,054** |
| Requirement kinds | branch **2,137** · from **32** · range **19** |
| Highest in-degree | `swift-index-primitives` 64 · `swift-byte-primitives` 63 · `swift-standard-library-extensions` 62 |
| Largest manifests | `swift-kernel` 31 deps · `swift-tests` 28 · `swift-authentication` 26 |
| Pins in the flagship consumer | **200** (`Workspace/Application`) |

**The overlay is per-root and linear in that root's closure.** "All packages" is not
one global act; it is "every institute package in *this* root's closure", repeated
per root a developer builds.

Cost of applying it, measured at three graph sizes — see §6a for the series and
the fit. Per-edit cost is **linear in graph size**, so applying the overlay across
a closure of size N is **quadratic**: ~18 minutes at the flagship consumer's 200
pins.

### 6a. The third point — and the distribution that reframes it

**Read §6b before acting on this section.** The per-edit cost below is correct;
the conclusion originally drawn from it was not, because it generalised from the
flagship consumer without measuring the distribution.

Measured at N=120, seven positions across the graph (`leaf1` … `leaf120`), each a
separate `swift package edit` invocation:

```
3.94  4.17  3.27  3.31  3.20  3.42  3.64      median 3.42 s
```

**Position in the graph does not matter; graph size does.** Editing the first
dependency costs the same as the hundred-and-twentieth. Three points now:

| Graph size | Per-edit cost |
|---|---|
| 1 | 0.47 s |
| 60 | ~1.80 s |
| 120 | **3.42 s** |

That is a clean straight line — roughly `0.45 + 0.025 N` seconds — and it fits the
N=60 point to within 0.13 s. The mechanism is exactly what the shape implies: each
invocation reloads the whole workspace, so applying the overlay to a graph of size
N costs `N × f(N)`, quadratic in the graph.

**Extrapolated to the flagship consumer at 200 pins: ~5.4 s per edit, ~18 minutes
to apply the overlay to the full closure.** The 6–20 minute range I refused to
narrow from two points resolves to **the top of it**. Eighteen minutes is not a
slow command; it is a command nobody will run, and a capability nobody runs is not
a capability.

**So the batch write is required, not a contingency.** Recorded honestly: this
extrapolates one linear fit two-thirds beyond its largest measured point, and all
three points carry uncontrolled machine load (four concurrent builds from other
sessions during the N=120 series). But the conclusion is robust to being generously
wrong — halve every number and it is still nine minutes.

There is a measured alternative: **a single well-formed write of
`workspace-state.json` is honoured.** Sixty edited entries
written in one pass, build green, all sixty local markers in compiled products,
canonical markers absent from products (present only as dormant `.build/checkouts`
clones — I checked, rather than assuming the grep hits were compiled output). One
write replaces N invocations.

**That alternative is recorded but NOT adopted — see §6b.** An earlier revision of
this section promoted it to the primary path. That was wrong, and the correction
is §6b's.

**Had it been adopted, that dependency would have had to be declared rather than
buried**, with a canary asserting a semantic fixed-point plus a live read-back —
not byte-identity, for the reason below. That machinery is moot under §6b, and the
paragraph is kept only so a future reader reaching for the batch write knows what
it would cost.

**Not byte-identity, and that is a measured correction rather than a relaxation.**
An earlier draft of this section, and the adjudication that approved it, specified
the canary as reproducing *"the byte-shape SwiftPM itself just produced."* Against
the 26 `workspace-state.json` files present in the tree — **all 26 at version 7**,
no other value — **0 of 26** survive a naive re-encode byte-identically: SwiftPM
writes through Foundation's pretty-printer, with `"object" : {` spaced around the
colon and empty arrays as `[\n\n    ]`. Matching that means reimplementing a
formatting quirk and pinning to it.

And byte-identity is not what SwiftPM requires. §6's batch-write evidence is direct:
the 60 entries SwiftPM honoured were written in a **different** byte shape
entirely, and all 60 persisted and compiled. A byte-identity canary would fail on
cosmetic drift, which is how a canary gets disabled. **(b) is the gate that
actually detects a shape SwiftPM will not accept.**

**The gate is not optional, and §4 is the argument for it.** The cost of getting
that file's shape wrong is not a rejected write — it is a *whole-state discard*
behind one warning, at exit 0, with the `Packages/` symlinks left in place
implying an overlay that is no longer there. A writer that trusts its own write is
exactly the failure this design exists to prevent, one layer down. So: **write,
then read the state back through SwiftPM's own view, and confirm every intended
package reports `edited` before reporting success.** Never trust the write.

### 6b. The distribution — and why the batch write is withdrawn

§6a's per-edit cost is correct. The conclusion drawn from it was not, because it
generalised from `Workspace/Application`'s 200 pins without measuring what a
*typical* consumer's closure looks like. Measured across all 441 roster packages'
manifests:

| | closure | whole-closure apply at `0.45 + 0.025N` |
|---|---|---|
| min | 0 | — |
| **median** | **36** | **49 s** |
| mean | 53 | ~2 min |
| p90 | 122 | 7.1 min |
| max — `swift-identities-mailgun` | 250 | 27.9 min |

Distribution: **37** packages have no institute dependencies, **46** have 1–9,
**167** have 10–49, **118** have 50–99, **69** have 100–199, **4** have 200+.

**250 of 441 packages have closures under 50** — under ninety seconds to overlay
entirely. The eighteen-minute figure was the flagship consumer, not the typical
one, and §6a presented a worst case as the operating case.

**But the distribution is not the main argument. This is:** *overlaying a whole
closure inside a consumer is not what a developer wants.* The inner loop is
"change package X, test the consumers of X" — **one** edit per consumer, not two
hundred. A developer changing `swift-byte-primitives` and testing `swift-stripe`
needs that one package local and everything else canonical, which is exactly the
parity property §5 exists to preserve. Wanting *everything* local is a different
job, and §6c gives it to a different mechanism.

The one genuine closure-scale case is **running a package's own tests against an
entirely local graph** — `swift build` never compiles member test targets, umbrella
or not. That case is rare, largely covered by the umbrella proving the graph
compiles, and tolerable when it happens: 49 s at the median, 7 min at p90, ~28 min
only for the four packages above 200.

**So the batch `workspace-state.json` write is withdrawn**, and with it the
`swift-spm-standard` encoder that would have carried it. That package's decoder
holds an explicit prohibition — *"SwiftPM owns that file exclusively; nothing in
this ecosystem may synthesise it, and offering an encoder would invite exactly the
hand-editing of resolver state that is forbidden"* — whose stated reason is the
precise hazard this mechanism creates. **It stands unoverridden.** The capability
rests entirely on the supported interface.

Three of the four gates lapse with it: fail-closed-on-version at write, read-back
verification, and the loud fallback all exist only to make a write safe. The
decoder already fail-closes on version, which is where that belonged. The toolchain
canary lapses too, there being no encoder to canary. **What survives is the
lock-aware precondition**, which is needed wherever `swift package edit` is invoked
at all.

**These figures are a floor, not an estimate, and the floor is about to rise.**
Closures count only roster-resolvable dependencies, so they exclude the eight
off-roster packages — and the principal has since ruled institute-owned forks
*into* the roster, which admits `swift-tagged-primitives` (78 dependents) among
others. Every closure grows slightly when that lands. The conclusion is not
sensitive to it: a median of 36 would have to grow several-fold before
whole-closure apply became the operating problem, and §6b's decisive argument is
not the number anyway.

**The instrument behind these figures was checked, because a sibling measurement
was caught by exactly this.** The full-tree session found **241 library products
across 42 packages declared with symbolic constants rather than string literals**
— 1,609 raw `.library(` occurrences against 1,368 parseable — invisible to any
manifest grep. I re-ran my own extraction against that failure mode: of **2,188**
raw `.package(` occurrences across the 441 manifests, **2,188** are
`url: "literal"` and **zero** are unaccounted for, in zero packages. **The
symbolic-declaration hole affects product declarations, not dependency
declarations**, so the closure figures stand.

That distinction also bounds where the warning applies. **The overlay never
enumerates products**: `swift package edit` takes a package *identity*, the
identities come from the generated roster and from SwiftPM's own resolved state,
and neither is parsed out of a manifest. The 241-product trap is decisive for the
umbrella — which must depend on products to compile anything — and inert for the
overlay. A future reader should not inherit the warning as applying to both.

### 6c. The widened purpose — "all" serves whole-graph builds

Ruled 2026-07-28: the principal intends **both** *"build the whole graph with
`Package.resolved` deleted and the remotes gone"* **and** fast local development.
So "all packages" mode is not a convenience for large selections — **it is how the
ecosystem gets built.**

Applying the overlay across every dependency of one root means that root's build
compiles the whole graph into **one** `.build`, each module once, instead of 113
separate builds each recompiling the shared primitives and standards layers. §4b's
capstone is therefore not only an acceptance test; it is the shape of the build.

**Nothing today depends on all 441.** The roster has 113 top-level packages —
packages nothing depends on — and since a package nothing depends on cannot be
reached transitively, every possible cover must contain all 113. That is a hard
floor, and it is why the sweep is 113 builds. **A synthetic umbrella root has no
such constraint**: one generated manifest naming those 113 by path yields a single
graph over the whole ecosystem.

**And that is where generated `.package(path:)` composition earns its place back —
which §9's disposition failed to distinguish.** Retiring `compose`/`restore` was
about rewriting a **committed** manifest with a machine-local absolute path, and
that rejection stands entirely. Generating a **synthetic root nobody commits** is a
different act: nothing tracked is modified, no consumer is affected, and the
machine-local paths live in a file that exists only to be thrown away. *"Composition
retired"* must not be read as covering it.

The umbrella is not built here, and at time of writing the full-tree session is
testing whether a shared `--scratch-path` achieves module reuse across roots with
no new machinery at all — which, if it works, may make the umbrella unnecessary too.

**Three constraints any umbrella must clear**, measured by that session and
recorded here so this document does not read as endorsing something unqualified:

1. **Depending on N packages is not building N packages.** SwiftPM compiles only
   the products actually depended upon, so a root naming 113 packages but
   importing a handful of umbrella products compiles a fraction of the tree and
   *looks* like a whole-graph build. Genuine coverage needs all **1,609**
   products. Verify by counting distinct `-module-name` values in the build log
   against the roster's **2,916** declared targets (2,085 library, 813 test, 9
   executable, 9 macro); ~2,100 non-test modules means it is real, a few hundred
   means it is a shortcut wearing the label.
2. **241 of those products cannot be found by reading manifests** (above). An
   umbrella built by grepping omits 42 packages' surface and reports success.
   Evaluate with `dump-package`.
3. **28% of the tree is out of reach either way.** `swift build` never compiles
   test targets — 813 of 2,916 — umbrella or overlay. That is permanent, and it is
   why §6b keeps per-consumer `edit` for the test workflow rather than folding
   everything into one graph.

### The architecture, stated as two jobs with two answers

The design ends with **two mechanisms, both on supported interfaces**, and a
future reader should see that rather than one mechanism that lost:

| Job | Mechanism | Scale |
|---|---|---|
| **Developer inner loop** — change a package, test its consumers | `swift package edit --path`, per consumer | small N: one edit, or a working set |
| **Whole graph** — build everything from local source | a synthetic umbrella root nobody commits, plain `.package(path:)` | one root, 113 members |

Neither writes SwiftPM's private state. Neither modifies a committed manifest.
`compose`/`restore` are retired for rewriting a **committed** manifest with a
machine-local path — a rejection that stands, and that says nothing about a
synthetic root.

---

## 7. Limits, and two defects found on the way

**Eight packages do not gitignore `Packages/`.** In these, the overlay's own symlink
is committable by a routine `git add -A`:

`swift-percent-primitives` · `swift-authentication` · `swift-image-magick` ·
`swift-money` · `swift-resource-pool` · `swift-server-dependencies` ·
`swift-sitemap` · `swift-svg-printer`

The other 433 ignore it. `Package.resolved` is ignored and untracked in **all 441**.

**Adjudicated 2026-07-28: this is a precondition for *shipping*, not for
*implementing*.** Build against the assumption the eight are fixed; do not ship an
overlay whose own artifact is committable by `git add -A`. The cohort is owned
elsewhere — six of the eight also carry standalone `swiftlint.yml` /
`swift-format.yml` files the `ci-cd` skill forbids in per-package repositories,
which reads as one missed standardization pass rather than two findings.

**Eight institute-org packages are depended on 86 times but are absent from the
roster, so the overlay cannot reach them.** Cause, checked against the GitHub API
rather than guessed:

| Package | Dependents | Why excluded |
|---|---|---|
| `swift-primitives/swift-tagged-primitives` | **78** | `fork: true` |
| `swift-foundations/swift-url-routing` | 13 | `fork: true` |
| `swift-foundations/swift-ip-address` | 2 | not eligible |
| `swift-webpage`, `swift-structured-queries-postgres`, `swift-domain-name-system`, `swift-email-html`, `swift-entitlement` | 1 each | `swift-entitlement` is `private`; others as above |

**Population and method, because three different counts for this package are in
circulation.** The 78 is: **465** top-level `Package.swift` files — the 441 roster
packages plus the on-disk non-roster ones — counting **distinct dependents**, with
`.build`, `.git` and `checkouts` excluded and nothing nested deeper than two levels
from the hierarchy root. An earlier figure of **66** in this document counted URL
occurrences over the **441** roster manifests only; the 441→465 population
difference is most of the gap. A count of **84** is also in circulation elsewhere
with its method unstated. **A bare dependent count for this package should not be
quoted without its population** — and the conclusion is unaffected either way:
whichever denominator is used, it is the most-depended-on package in the tree by a
wide margin.

The exclusion is `Workspace.Inventory.Eligibility.Reason.fork` working as
designed, and the roster is generated, so this is not drift.

**Ruled 2026-07-28, principal:** *"admit institute-owned forks to the roster. All
swift-institute packages regardless of whether they're forks."* So
`Eligibility.Reason.fork` stops excluding institute-owned repositories, and
`swift-tagged-primitives` (78 dependents, population above) and `swift-url-routing`
(13) come into scope with the rest of the fork-excluded set.

**Two of that set have since left it:** `fork-swift-parsing` and
`pointfree-url-form-coding` were made private and archived on the principal's
instruction as vestigial `coenttb` → `swift-foundations` migration leftovers, with
zero in-tree references verified first. Three load-bearing forks remain public:
`swift-tagged-primitives`, `swift-url-routing`, `swift-structured-queries-postgres`.

**Read narrowly, and do not write the future state as though it were current.** He
ruled on **forks**. He did not rule on **private** repositories, and
`swift-entitlement` is excluded for being private, not for being a fork. **Until
the eligibility rule actually ships, the honest coverage statement remains *all
roster packages*** — with a note that the roster is about to widen by ruling.

Coverage must therefore name **three** sets, not two:

| Set | Status |
|---|---|
| **In scope** | roster packages — widening to include institute-owned forks |
| **Excluded as private** | e.g. `swift-entitlement`. Not ruled on; keep visible |
| **Excluded for other reasons** | third-party (apple, swiftlang, vapor, pointfreeco) |

Private repositories deserve their own line rather than being folded into
"excluded", because they are the fleet's blind spot twice over: they run no CI (the
universal reusable guards on visibility), and they are invisible to tree-local
search and to unauthenticated GitHub search.

**This enlarges the scale problem rather than easing it.** §6a measures closure
application as quadratic in graph size; admitting the fork-excluded set makes every
closure larger, so whatever mechanism ships gets slower. That is a reason the §8a
comparison mattered more, not less — and it is a number to re-take once the roster
widens.

**A third limit, structural rather than incidental: the overlay is root-scoped, and
it can outlive its reason.** An `edited` entry survives the dependency leaving the
graph — build green, entry retained, `Packages/` residue kept. Nothing compiles it,
so it is stale rather than wrong; but if that dependency is later re-added, the
developer inherits a live overlay they did not apply in this session. `status` must
report edited entries with no corresponding graph edge, and `remove` must sweep
them.

Also out of scope until measured, stated rather than glossed:

- **Xcode.** `institute.xcworkspace` is a committed artifact and I did not test the
  overlay under Xcode at all. Xcode does not inherit a shell environment, and it
  drives SwiftPM through its own workspace machinery. Untested — and it is the
  founding plan's §7.1 open question 7, still open.
- **CI.** Every statement here is about a local checkout. The overlay must be
  provably absent in CI, which is a check to write, not a property to assume.
- **Linux and any second toolchain.**
- **Two of the founding plan's nine spike questions are answered negative rather
  than unanswered** — isolated context scratch paths, and two coexisting contexts
  for one root (§4a). Any design inheriting that plan's context model must be told
  so, because it assumed both were available.

---

## 8. The alternative I tested and am rejecting **on a premise that could change**

> **⚠️ Superseded by §8a, 2026-07-28.** The premise did move — the principal ruled
> *"SwiftPM is primary concern, with Xcode secondary"* — and §8 was re-argued on
> the new premise the same day. **It is still rejected, but for a different and
> better reason**, and two of the three objections below are overstated. **Read
> §8a, not this section, for the live argument.** This is kept for the costs it
> prices and the mechanism it describes, both of which remain accurate.

Since the objective is phrased as *"as if each `Package.swift` had local path based
dependencies"*, the literal reading deserved a real test: make the manifests
conditional. A `Package.swift` is Swift code; it can derive the hierarchy root from
`#filePath` — no configured path, no machine-specific input — and emit
`.package(path:)` or `.package(url:)` depending on an environment variable.

**It works, and it works better than SPM edit on the two axes that matter most:**

- One environment variable switches **the entire transitive closure** in a single
  build. Verified: with two levels of manifest conditional, both dependencies
  became `fileSystem` and local worktree source compiled. **O(1) at any scale** —
  no per-package command, no per-package state, no `N × f(N)`.
- **Zero local state.** Nothing to half-apply, nothing to leave behind, nothing to
  reconcile. §4's failure mode cannot occur.
- The manifest cache does not stale: flipping the variable re-evaluates.
- `Package.resolved`'s `originHash` was identical in both modes.

I am not recommending it, for reasons that are about the institute rather than
about the mechanism:

1. It requires **editing and committing all 441 manifests**, and every future one.
2. It makes every public manifest **evaluate differently by environment** — an
   external consumer reading these manifests now finds a second resolution mode
   that exists for our convenience. That is a permanent change to a public
   interface, in service of a local workflow.
3. **Xcode is unresolved and probably hostile.** Xcode does not inherit the shell
   environment; switching modes would need a scheme setting or a
   `launchctl setenv` — which is precisely the hand-configured, machine-specific
   state the constraint forbids. SPM edit has no such dependency: its state is
   files on disk that Xcode reads through SwiftPM like anything else.
4. The switch is an environment variable, so **"which mode am I in" becomes a
   property of the invoking shell** rather than of the checkout — the hardest kind
   of mode confusion to diagnose.

If the fleet later concludes the per-root cost of SPM edit is intolerable at 200+
pins and Xcode is dropped as a first-class consumer, this becomes the better
design. It is recorded here so that conclusion does not have to be rediscovered.

---

## 8a. Decision memo — §8 re-argued after "Xcode is secondary", and still rejected

Requested 2026-07-28 after the principal ruled *"SwiftPM is primary concern, with
Xcode secondary"*, which demoted the premise §8's rejection rested on. Re-argued
rather than inherited. **The conclusion holds, but almost none of the original
reasoning survives** — the Xcode objection is now weak, the manifest-edit objection
is weaker than I claimed, and a new measured objection replaces both.

### The two costs I over-stated

**The manifest edit is small and mechanical, not invasive.** Measured across the
real corpus rather than estimated:

| Fact | Value |
|---|---|
| URL-basename vs roster-name mismatches, all 2,188 edges | **0** |
| Single-line `.package(url:…)` clauses | **2,167** (99.0%) |
| Multi-line clauses needing judgement | **21** |

Zero mismatches is the important one: a package's identity under `.package(path:)`
is its directory basename, which is exactly its roster name, which is exactly its
URL basename. **So `.product(name:…, package:…)` lines never change** — only the
`dependencies:` array does. My fixture suggested otherwise, and my fixture was
wrong: it used `mid-remote.git` for a directory named `mid`, an artefact I
introduced. The real edit is a per-manifest helper of roughly eight lines plus a
one-for-one rewrite of dependency clauses, generatable for 99% of them.

**And "Xcode cannot see it" is now a cost, not a disqualifier** — correctly, per
the principal's ruling.

### The objection that replaces them, and it is measured

I tried to remove the Xcode objection entirely with a trigger Xcode *can* see: a
generated sentinel file at the hierarchy root, discovered from `#filePath`, no
environment variable anywhere. It would have cleared the standing constraint as
generated-not-authored, and it would have worked identically under SwiftPM, Xcode
and CI.

**It does not work, and it fails silently in the dangerous direction.**

| Trigger | Mode ON | Mode OFF |
|---|---|---|
| Environment variable | `fileSystem`, local source compiled | **reverts correctly** — `localSourceControl`, canonical compiled |
| Generated sentinel file | `fileSystem`, local source compiled | **does not revert** — still `fileSystem`, still compiling local source |

Removing the sentinel, touching the manifest, and running an explicit
`swift package resolve` all failed to revert it. The cause is SwiftPM's **shared
manifest cache** (`~/Library/Caches/org.swift.swiftpm/manifests`, 144 MB here):
it is keyed on manifest *content*, so a manifest whose evaluation depends on
ambient filesystem state is served from cache and the mode change is invisible.
`--manifest-cache none` reverts it immediately, which is what identifies the cause.

**Three things follow, and together they decide it.**

1. **§8's headline advantage is false as stated.** "Zero local state, so the §4
   failure mode cannot occur" — §8 *does* have local state: a 144 MB shared
   manifest cache. And under the filesystem trigger it produces exactly §4's
   failure, in its worse direction: the developer turns the overlay **off** and
   keeps compiling local source, believing they are on canonical.
2. **The only trigger that is sound is the one Xcode cannot see.** The environment
   variable reverts correctly because SwiftPM's cache key accounts for it; the
   filesystem sentinel does not. So "Xcode is secondary" does not rescue §8 —
   the workaround that would have served Xcode is precisely the broken one.
3. **§8's correctness would rest on an undocumented cache-key detail.** That is the
   same class of risk as the batch write's `"version": 7` dependency — but where
   the batch write's failure is *loud and gated* (§6, four gates), this one is
   *silent and ungated*, and it governs correctness rather than speed.

### Recommendation

**Stay with the batch `workspace-state.json` write.** Not because §8's costs are
large — two of the three I originally gave were overstated — but because §8 trades
a bounded, loud, gated dependency on SwiftPM private state for an unbounded, silent
one, and buys Xcode nothing.

Stated against my own prior: I went into this re-argument expecting §8 to win on
the new premise, and built the sentinel variant specifically to make it win. The
measurement killed it. Recorded because a rejection that survives an honest attempt
to overturn it is worth more than the original.

**What would reopen it:** a trigger that is both visible to Xcode and part of the
manifest cache key. If SwiftPM gains an explicit local-override facility, this
whole section is moot and that facility should be preferred over both mechanisms.

---

## 9. Proposed surface

Full Swift, in `Workspace Application`, no new shell or Python.

**Vocabulary reconciled with the founding plan rather than minted fresh.** Its §12
already specifies `workspace resolution plan | apply | status | verify | remote`
and a `workspace context` family. I proposed `workspace overlay …` before reading
it. **Adopt `workspace resolution`** — it is the adjudicated name for exactly this
concept, and a second vocabulary for one thing is the confusion this design is
otherwise trying to remove:

```sh
workspace resolution plan   [--package <name>]…   # inspectable, changes nothing
workspace resolution apply  [--package <name>]…   # single, multiple, or all
workspace resolution status                       # mode, parity, half-applied, stale entries
workspace resolution remove [--package <name>]…
```

I am **not** adopting the plan's `context` family. Its contexts assume isolated
per-context scratch paths and multiple coexisting contexts per root; §4a shows
`swift package edit` provides neither. A persisted context model built on a
mechanism that cannot isolate would be a name for something that does not exist.
One overlay per root, discovered rather than named, is what the mechanism actually
supports — and it is enough for *single, multiple, or all*.

The plan's §4.6 discipline applies unchanged and is why `plan` is a verb here:
formulate an inspectable plan, support dry-run, identify affected paths, refuse
unsafe states by default, be idempotent, and verify the postcondition.

### Ownership: this cannot be built in Workspace alone

Established against the lower layers' source before writing any code, because
founding-plan §4.3 forbids Workspace implementing SwiftPM mechanics itself and
requires a missing capability to be added to its semantic owner.

| Capability required | Owner | Present today |
|---|---|---|
| **Encode** `Package.Resolution` — the batch write | `swift-spm-standard` (L2) | **No.** Deliberately decode-only; no `Encodable` or `JSON.Serializable` in `Sources/` |
| **Invoke** `swift package edit` / `unedit` — the mandated fallback, and the canary's oracle | `swift-package-manager` (L3) | **No.** Public surface is `resolution`, `manifest`, `evaluation`, `dump`, `materialized` — all read-only |

The decode-only choice is deliberate and argued in that package's own source:
version 7 is *"a precondition, not a fact worth carrying"*, and unrecognised
states fail loudly rather than being mis-decoded. Adding a writer is a real Layer-2
design change, not a mechanical addition — and it is **where the fail-closed
version gate belongs**, since `Package.Resolution.supportedVersion` already lives
there rather than in Workspace.

**Consequence for sequencing:** the core of `apply` cannot land until those two
owners gain their capabilities. Putting either in Workspace would satisfy the
schedule and violate the invariant.

### The lock hazard the fallback must be built around

`swift-package-manager`'s own source documents it: **SwiftPM takes an exclusive
lock on the target package's `.build` and waits indefinitely rather than failing.**
A caller pointed at a package something else is building **hangs**; it does not
error.

The mandated fallback shells out to `swift package edit` per package, so on a
machine running a full-tree sweep it would hang rather than degrade loudly — worse
than the failure it exists to replace. **The fallback needs a lock-aware
precondition with a timeout**, and the §4b capstone cannot be run against real
institute packages while any sweep is live.

Satisfaction of the founding plan's §4 invariants, which remain binding: **4.1**
committed manifests are never touched — measured, byte-identical throughout;
**4.2** explicit, inspectable, regenerable, removable, deterministically
reversible — `unedit` verified complete; **4.3** Workspace decides policy and
`swift-package-manager` executes the mechanics; **4.4** external consumers see
URL declarations unchanged, because nothing is committed; **4.5** satisfied by
`--fresh` (§4a), which is overlay-free by construction; **4.6** the `plan` verb.

- `apply` with no `--package` covers **every roster package in the closure** of the
  root it is run against. With `--package` it covers exactly those and their
  roster-resolvable dependencies. Single, multiple, and all are the same code path
  with a different selection.
- Inputs are only `Workspace.json` and `Workspace.Root` (checkout resolved
  physically, hierarchy = its parent). **No new configuration file, no new
  durable path.** `Workspace.Layout` already derives every checkout location; the
  overlay adds no second derivation.
- Refuses, naming the package, when: the checkout is absent; the package is
  off-roster; SwiftPM's own `edit` exits non-zero (unsatisfiable requirement). No
  quiet fallback to the resolved graph, ever.
- `status` exits non-zero on half-applied state and prints the parity table of §5.
- `remove` is `unedit` per package plus a symlink-residue sweep, and it verifies
  the resulting state reports `sourceControlCheckout` before claiming success.

**Acceptance criterion, principal's, and it is the one to build against (§4b):**
with the overlay applied across the closure, **a build succeeds with no
`Package.resolved` and no remote reachable**, with local markers in compiled
products — and the same build **fails** with the overlay removed, and **fails**
under `--fresh`. All three legs are required; the first alone is passed by a warm
`.build/checkouts` and proves nothing.

**On the existing `compose` / `verify` / `restore`:** its mechanism — rewriting the
committed manifest with a machine-local absolute path, per dependency pair — is the
thing the objective rules out. It also fails the *"nothing machine-specific"*
constraint on its own terms, independently of the new objective: a manifest
carrying an absolute path is machine-specific state in a tracked file, and
`compose`'s own warning says so. That constraint is ruling 143, standing since
2026-07-26, so this is not a new judgement being applied retroactively. I recommend retiring `compose` and `restore` once
`overlay` lands, and **keeping `verify`'s approach**: reading effective source from
SwiftPM's resolved state rather than from a ledger is right, and it is the honest
core of `status`. I have not touched that code.

---

## 10. What I checked, and what I assumed

**Checked, by running it today:** everything in §2 (both controls, every row);
the `.build`-deletion degradation and the malformed-state discard in §4; `unedit`'s
completeness and the preservation of uncommitted dependency work in §5; transitive
edit; edit under `branch:`; edit's refusal on an unsatisfiable requirement; the
offline full-overlay build and its negative control; the batch state write and the
disambiguation of its grep hits; the conditional-manifest alternative including
transitive propagation and manifest-cache freshness; both loops in §3, with the
marker verified in compiled products every round; the full 441-package census, the
gitignore audit, the requirement-kind census, and the eight off-roster packages'
GitHub attributes.

**Assumed, and flagged:** that the eight `Packages/`-unignored packages are the
complete set for `Packages/` specifically — I did not audit every ignore pattern
for other overlay artifacts.

**Assumed, then measured, then withdrawn — recorded because the error is the
useful part:** that SwiftPM parallelises branch-tip fetches, making the 96 s
`ls-remote` projection an upper bound on `update`. It is not an upper bound; the
measured fetch total is 106.5 s and the *fetches are not the dominant cost*.
And that per-edit cost extrapolates from two points — §6 says measure it, and
§6a does.

**Checked in the §8a re-argument:** that URL basename equals roster name across all
2,188 edges, so identity is preserved and no target line changes; the single-line
versus multi-line clause split; and both conditional-manifest triggers in **both
directions** — the environment variable reverts correctly, the generated sentinel
file does not, with `--manifest-cache none` identifying the shared manifest cache
as the cause.

**Checked last, and it is the acceptance criterion:** the principal's capstone —
a build with no `Package.resolved`, no `.build/checkouts`, and the remotes removed
from disk — with both negative controls firing (§4b). Also the limit it exposed:
the overlay can be used offline but not applied offline.

**Also checked, after the first draft, because the earlier corpus was measured
under a different default:** the overlay under `--build-system native` as well as
the 6.4 default `swiftbuild`, in a clean room with the hit locations disambiguated;
the overlay at `swift-tools-version: 6.3.3`, the real manifest floor; `edit`'s
rejection of `--scratch-path`; the divergence between an overlay applied to the
default `.build` and a build given a custom scratch path; `Build.Coordinator`'s
scratch policy read from source (`freshScratch` returns `nil` unless `fresh`);
identity mismatch in the local checkout; and an edited package dropping out of the
graph.

**Not checked at all, and not to be read as safe:** Xcode under the overlay; CI
absence of the overlay; Linux; any toolchain other than Swift 6.4; and the real
`swift package update` cost at 200 pins, which §3 says decides whether this is worth
building.

**A second zero I refused, in the re-measurement pass.** The first
`--build-system native` run reported the local marker absent from `.build/debug`
— which would have been a headline finding: *the overlay does not work on the
deprecated build system.* It was the instrument. `.build/debug` is a symlink into
`arm64-apple-macosx/debug`, and neither `find` nor `grep -r` descended it. A
positive control — *can this probe find any known string in native's output at
all?* — returned empty too, which is what exposed it. Grepping the real path shows
the marker present. **The probe that reports "not found" and the probe that reports
"nothing to search" are the same output**, and one of them was about to become a
design conclusion.

**One instrument trap hit and corrected, recorded because it nearly entered this
document:** I first read exit statuses through `… | tail -5`, which reports `tail`'s
status. `swift package unedit` appeared to exit 0 on an error. Re-run unpiped it
exits **1**. Same class as the false green in `FIRST-RESOLVE-2026-07-28.md`, one day
later, in a session that had read that document.

**A zero I refused twice.** The §3 baseline loop reported the marker absent from
compiled products in three consecutive rounds. Both times the cause was the fixture,
not the finding — first a missing `origin`, then manifests copied with absolute URLs
still pointing at the original fixture. Had the instrument reported a clean pass
instead of a visible zero, a broken baseline would have been the headline number.
