# ADR-001 — Materialization Backends

> ## ⛔ SUPERSEDED 2026-07-28 — both halves of the decision
>
> **Basis:** a direct principal override, delivered twice and independently
> confirmed: *"I want this issue researched and approached from first principles
> … the objective is capability to do local development on single, multiple, or
> all swift-institute packages as if each `Package.swift` had local path based
> dependencies instead of URL based ones"*, and *"this also overturns ALL prior
> research and decisions on this topic."* Adjudicated and ruled superseded by the
> Team Lead, 2026-07-28.
>
> **What lapses:** the Decision section entire — `.package(path:)` generated
> composition as the production backend, **and** the retirement of editable
> dependencies. `swift package edit` is now the named mechanism, not a rejected
> one. The corresponding retirement in `Owner Capability Matrix` §3.2 lapses with
> it; see the note there.
>
> **What survives:** every *measurement* in this document. Findings 1–4 were
> executed, and executed evidence is not overturned by a decision changing. The
> mirror path's stickiness, the local-green/remote-impossible state, and
> `get-mirror`'s failure to predict substitution all still stand as facts about
> the mirror mechanism. **The rule, which the Team Lead has asked be stated
> generally: prior measurements survive; conclusions built on them lapse.**
>
> Two of this document's Consequences transfer to the successor design intact and
> are carried there: a clean-room resolution check is a required step rather than
> a recommendation, and a warm build directory can ignore an overlay — so any
> experiment must start cold or it will lie.
>
> **Successor:** `DESIGN-Local-Overlay-2026-07-28.md`, which is also the
> generated-composition spike this document's Limits section recorded as owed —
> discharged against `swift package edit` rather than against `.package(path:)`,
> because the override changed which backend needed proving.
>
> This document is retained, not deleted: two live answers with no way to tell
> which won is the failure mode the retention exists to prevent.

**Status:** ~~Accepted~~ **Superseded** · **Date:** 2026-07-25
**Closes:** implementation plan Gate 0 (§8.6), whose stop condition was
*"do not proceed to broad Workspace integration without this decision."*
**Evidence base:** the §8.5 spike, executed 2026-07-24/25 as Slice 3.

This repository is public. Paths below use `<placeholder>` form deliberately.

---

## Decision

**Generated `.package(path:)` composition is the production backend.**
**Mirror-based composition is proven but sharp, and is admitted only as a
deliberate, recorded exception.** Editable dependencies (`swift package edit`)
remain retired.

The settled architecture already said this. What changed is that it now rests on
evidence rather than on argument — and the evidence is stronger than the
argument was, because it is the mirror path's *failure modes* that make the case,
not its unavailability.

## What the spike actually did

A dependant whose manifest declares its dependency by **canonical URL** was
built against a **mutable local source** and then restored. Two purpose-built
throwaway repositories, one with a bare repository standing in for its canonical
remote. The dependant's manifest was verified **byte-identical to canonical at
every step** — never edited, not once.

| Step | Result |
|---|---|
| A — canonical baseline | resolved and compiled the canonical revision |
| B — local composition via package-scoped mirror | applied |
| C — sentinel | compiled a marker existing **only** in the local worktree, at a revision **never pushed** |
| D — naive removal (delete the config) | ❌ **did not restore** |
| E — clean-consumer reproduction | ❌ **failed to resolve at all** |
| F — cache-aware removal | ✅ restored, developer's local commit preserved |

## The four findings, in the order they matter

### 1. Removing a local composition does not restore canonical resolution

The composition is **sticky**. After deleting the mirror configuration and
running update and build, the location, the revision, and the compiled sentinel
were all still local.

Worse than stickiness: the resolved pins then recorded a state that **cannot
exist** — the *canonical* location paired with a revision **absent from that
repository** — while local builds kept succeeding by serving the object from the
generated repository cache.

> **Any `remove` or `restore` that only deletes configuration is a no-op that
> looks like success.**

This is a defect in the feature this arc exists to build, found before it
shipped. It is the acceptance criterion for the Workspace surface: a removal
that does not purge generated caches is not a removal.

### 2. The resulting state is not reproducible, and only a clean consumer reveals it

A fresh consumer — same manifest, same pins, no caches — fails outright:
`Couldn't check out revision …: fatal: unable to read tree`, and the canonical
remote confirms the object is simply absent.

**Local green, remote impossible, no warning anywhere.** This is implementation
plan §4.5 — *"a green local context is not sufficient evidence that an external
consumer can build"* — reproduced concretely instead of asserted.

Finding 2 is what makes Finding 1 dangerous rather than merely untidy: nothing
observable from inside the developing machine distinguishes a correctly restored
context from a broken one.

⇒ **A clean-room resolution check is a REQUIRED step of any local-composition
removal, not a recommendation.** It is the only thing that detects Finding 1.

### 3. Removal must be cache-aware — and must not destroy the developer's work

The procedure that works: remove the composition **and** purge the generated
caches, then re-resolve. Verified to return the dependant to the canonical
revision.

The property that makes it acceptable: **the developer's local commit was
preserved.** A restoration that also discarded their work would not be a fix,
and any implementation must keep this invariant.

### 4. `get-mirror` does not predict what a build will substitute — *routed, and closed*

`swift package config get-mirror` reported a mapping for the bare-path spelling
and **"not found"** for the `file://` spelling, while the resolver required the
`file://` entry. The two disagree about which key matches.

This answers Owner Capability Matrix §9.4 item 2 in the **negative**.

> ⚠️ **Routed beyond this arc: `swift-impact` relies on `get-mirror` to predict
> the substitution a build would use.** That reliance is documented in its own
> source. Its blast radius is outside Workspace and it should be reviewed by
> that package's owner.

> ## ✅ REFERRAL CLOSED — verified 2026-07-28
>
> **The reliance no longer exists.** It was removed by `swift-impact`'s own owner
> on **2026-07-25**, the same day this ADR routed it, and this document was never
> updated to say so. Verified by reading the package at `origin/main`, not by
> asking whether anyone had acted.
>
> **Where it was.** `swift-foundations/swift-impact` — a **private** repository,
> absent from `Workspace.json` and not materialized in the checkout, which is why
> a tree-local search finds nothing. Call site:
> `Sources/Impact/Impact.Run.MirrorVerification.swift`, invoked from
> `Impact.Run.swift:90` before any dependent build.
>
> **What closed it.** `f2105f99` *"Fix mirror verification: verify substitution by
> ground truth, not get-mirror"* (2026-07-25 06:26 +0200), refined by `e4a2ec5b`
> *"Honour a `file://` mirror target as a substitution, not a missing mirror"*
> (12:48 +0200). Both are on `origin/main`. The commit message cites the same
> spelling-family evidence recorded here, reached through the
> workspace-local-resolution handoff §3 finding 3 — so this is the referral being
> received and acted on, not an unrelated coincidence.
>
> **What replaced it.** `get-mirror` prediction is **deleted**, not merely
> bypassed — `gitOriginURL` and `swiftPackageConfigGetMirror` are gone from the
> source. The check now reads the substituted location off SwiftPM's own
> `dump-package` evaluation, which is spelling-agnostic *because it constructs no
> key at all*. `e4a2ec5b` then fixed a second spelling bug in the replacement: a
> mirror target spelled `file://` is reported as `location.remote`, not
> `location.local`, so honouring only `.local` would have false-aborted a
> correctly mirrored pair — the same class of defect one layer in.
>
> **The regression guard is real, and it carries its own positive control.** The
> test asserts `!log.contains("get-mirror")` against a fake coordinator's
> invocation log — and asserts `dumpCount == 3` on that *same* log in the same
> test. An empty log therefore fails the test rather than passing it vacuously.
>
> ### Dead code, or broken code? **Neither — and the distinction the brief asked
> for does not survive contact with the evidence.**
>
> The referral's defect is not dead code and not broken code: it is **absent**.
> Nothing predicts mirror behaviour from `get-mirror` anywhere in the package.
> The surviving `get-mirror` strings are comments explaining why it is *not* used,
> plus a deliberate fake-coordinator leaf in the tests that implements
> `get-mirror`'s exact-match semantics **as a negative control**.
>
> The *replacement* is live code on the executed path, and it is correct. But its
> surrounding premise has been dismantled beneath it, which is a different finding
> and is recorded here rather than in the referral's name:
>
> | Premise `swift-impact` requires | State, measured 2026-07-28 |
> |---|---|
> | A configured SwiftPM mirror map | **Gone** — `~/.swiftpm/configuration/` and the legacy `~/Library/org.swift.swiftpm/configuration/` are both empty |
> | The `Scripts/swift-build` coordinator it spawns | **Gone** — no such path, and no `Scripts/` directory |
>
> So `swift-impact` cannot currently execute a run. **It fails closed and loudly**
> — `.mirrorsNotConfigured`, thrown before any dependent build — which is the
> correct direction and is exactly what the check was built to do: refuse rather
> than emit false-negative impact results against canonical sources. The mirror
> map's removal is the standing *"nothing machine-specific"* constraint working as
> intended; the coordinator's is a separate change this document does not own.
> Recorded as a fact about the package's runtime premise, **not** as a defect
> referred onward — the code behaves correctly given inputs that no longer exist.
>
> **Read from source and git history at `e4a2ec5b`; the run itself was not
> executed**, because the coordinator binary it requires does not exist on this
> machine. That is a limit of this verification, stated rather than glossed.
>
> **One remnant, left with its owner and not fixed here.** `swift-impact`'s own
> `Research/design.md:103` still asserts the tool *"verifies the premise through
> the coordinator's machine-readable `package get-mirror` leaf"* — stale since
> `f2105f99` and contradicted by the source beside it. It is a doc line in a
> private repository outside this arc; it is named here so the next reader of that
> package finds it rather than trusting it.

## Preconditions for mirror-based composition

None of these were previously written down. All three were found the hard way,
and any implementation that uses this mechanism must encode them.

1. **The `original` key must match the spelling the resolver uses** — the
   `file://` form for a dependency declared with a `file://` URL. A bare-path
   entry alone did not apply.
   ⚠️ **This is a function of how the dependency is declared, not a global
   rule.** The institute mirror map is bare-path throughout and correctly so.
   Do not "fix" that map to match this finding.
2. **A cold build directory is required.** A warm one ignored the mirror
   entirely.
3. **Pins advance only under `update`** — never `resolve` or `build`. The
   resolved-pins file lives at the package root and survives deleting the build
   directory, so a stale pin otherwise wins.

## Answers to the questions Gate 0 requires

| Question (§8.6) | Answer |
|---|---|
| Initial production backend | Generated `.package(path:)` composition |
| Does Xcode need a distinct backend | **Unresolved — not exercised.** The spike covered the command-line path only. Treat as open. |
| Generated composition accepted, deferred, or rejected | **Accepted as the production backend**, on the strength of the mirror path's failure modes rather than on a direct comparison — see Limits |
| How effective state is inspected | `Package.Resolution` (Layer 2) decoded from SwiftPM's resolved state; read and derived by `Package.Manager` (Layer 3) |
| What is persisted | Only what cannot be re-derived: the declared source and Workspace's own planned source. Everything SwiftPM owns is re-inspected |
| How isolation is achieved | Package-scoped configuration and per-package generated state; no global mirror edits |
| Which lower-layer packages require changes | `swift-spm-standard` (resolved-state model) and `swift-package-manager` (state inspection, materialized-path derivation) — **both already landed** |

## Limits of this decision

Stated plainly, because a decision recorded as broader than its evidence is the
failure mode this document exists to avoid.

- **The spike exercised the mirror mechanism, not `.package(path:)` generated
  composition.** The production backend is chosen on the basis of the mirror
  path's demonstrated sharpness and on the settled architecture, **not** on a
  head-to-head measurement. A generated-composition spike remains owed.
- **Scale is one dependant and one dependency.** Nothing here speaks to
  multi-root contexts, transitive closures, or the ecosystem.
- **Nothing about Xcode, Git worktrees, plugins, macros, resources, or traits.**
- **Single toolchain, single machine.**

## Consequences

1. The Workspace surface must not ship a `restore` that only deletes
   configuration. Finding 1 is its acceptance criterion; Finding 2 is its test.
2. Clean-room verification is a required step, not an optional one.
3. Mirror-based composition, where used, must record why, and carries the three
   preconditions above.
4. A generated-composition spike is owed before the production backend can be
   said to be measured rather than reasoned.

## A correction carried into this record

An earlier instruction to this lane held that unconfigured packages inherit a
*permissive* ancestor config, making their `--strict` greens suspect. **That
direction was backwards.** Two of the three packages in this slice declare no
`.swift-format` and fall through to built-in defaults whose line budget is
**half** the institute canonical — so those greens are **stricter** than
canonical, and the live exposure is **false reds**.

> ⛔ **The trap is on the fix.** Adding the canonical configuration to such a
> package **relaxes** it. Anyone "closing the gap" as tidy-up silently widens the
> budget across every such package at once. Do not.

The underlying mechanism is nonetheless real: `swift-format` discovers
configuration by walking **up** the directory tree, so validating extracted
content inside a scratch directory can silently pick up an unrelated package's
rules. Verify the extraction target's ancestry before trusting such a check.

## Disclosure debt, recorded not fixed

Sibling public repositories carry machine paths in tracked content, on the order
of a four-figure count across the `Research` corpus. **A pushed exposure is not
undone by deletion** — commits stay reachable by identifier. These are paths and
a username, not credentials, so the remedy is to stop adding and clean forward.
**History rewriting is a hard stop.**
