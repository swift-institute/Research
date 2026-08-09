# Workspace Finalization Handoff

**Created 2026-07-24 by the Claude Code team-lead session**, on a supervisory relay transferring
this arc from a ChatGPT supervisory session into Claude Code. Operational handoff — not a research
report. Repository state below was **measured, not recalled**; every absence carries its positive
control.

> **SUPERSEDED 2026-07-26 (team lead).** The gate below was overtaken by events: this
> repository is published and this corpus is public. Machine-specific paths in the corpus
> were generalised to placeholder form on 2026-07-26 (`3bd804f8`), and
> `swift-foundations/swift-package-manager` has been **PUBLIC** since 2026-07-24. The
> original gate paragraph is retained below for the record; do not act on it.
>
> ⚠️ **PUBLICATION GATE — READ FIRST.** `swift-institute/Workspace` is a **PUBLIC** repository.
> `swift-foundations/swift-package-manager`, which this arc documents in detail, is **PRIVATE**.
> This file and the whole `Research/Local Resolution/` corpus are committed **locally only**;
> `Workspace` sits at `[ahead 1]` and **must not be pushed** without a principal decision.
> Machine paths and private-repo internals here are acceptable *because this is unpushed*.
> Pushing is publication and is outside the standing push grant.

---

## 1. Mission

Finalize the first useful Workspace local-development workflow:

- tracked production manifests remain canonical and URL-based;
- a selected dependency can be developed from a mutable local source;
- the dependant actually compiles that local source;
- the system can inspect and report what SwiftPM evaluated, resolved, and materialized;
- restoration returns to ordinary canonical resolution;
- the work is implemented through the correct lower-layer owners before Workspace policy is added.

## 2. Accepted architecture — settled, do not reopen

- Preserve independence at rest; provide composition during work.
- Canonical tracked manifests remain URL-based.
- `Package.Dependency.Source` represents declaration forms.
- `Package.Manifest.Evaluation` represents `dump-package` evaluation.
- **Declared source, evaluated location, resolved state, and materialized source are distinct.**
- **A mirror target is not automatically the source tree being compiled.**
- `swift-spm-standard` owns external SwiftPM representations and decoding.
- `swift-package-manager` owns SwiftPM invocation, state inspection, materialized-path derivation.
- `swift-package-graph` owns discovery and graph construction.
- Workspace owns planning, comparison, policy, safety, presentation, orchestration.
- No new package without compelling proof.
- Foundation must not enter the core lower-layer production path.
- Generated `.package(path:)` composition has priority for the first local-path proof.
- `swift package edit` / `unedit` remain **retired**.
- Git worktrees and broad Xcode work must not delay the first proof.

## 3. Actual repository state — measured 2026-07-24

> **Superseded 2026-07-26 by `workspace doctor`.** Repository state is now measured by running
> doctor (working-state census, commit `ee651f00`), not by reading a table dated the day it was
> written. The snapshot below stays as historical record; dated repo-state tables are retired as
> a genre — a handoff cites the tool instead.

| Repository | HEAD | Branch | Tracking | Visibility | Dirty | Scoped mirrors |
|---|---|---|---|---|---|---|
| `swift-institute/Workspace` | `b917a00` | main | **ahead 1** | **PUBLIC** | clean | absent |
| `swift-standards/swift-spm-standard` | `693e0d7d` | main | **ahead 1** | **PUBLIC** | clean | absent |
| `swift-foundations/swift-json` | `cb2e77dc` | main | **ahead 2** | **PUBLIC** | clean | absent |
| `swift-foundations/swift-package-manager` | `d3dd3090` | main | in sync | **PRIVATE** | **8 entries** | **PRESENT** |
| `swift-foundations/swift-package-graph` | `8fbcdb8e` | main | **ahead 1** | **PUBLIC** | clean | absent |
| `swift-foundations/swift-impact` | `41e95a12` | main | in sync | **PRIVATE** | clean | absent |

`Package.resolved` and `.build` are generated/ignored throughout. `Package.resolved` must never be
committed, staged, hand-edited, copied, or deleted to force advancement.

### Historical checkpoints — verified, not trusted

| Checkpoint | Exists | Ancestor of HEAD |
|---|---|---|
| `swift-spm-standard` evaluation `693e0d7d…` | ✅ | ✅ — **it *is* HEAD** |
| `swift-json` initial decoder `f692c2f2…` | ✅ | ✅ |
| `swift-json` corrective decoder `cb2e77dc…` | ✅ | ✅ — **it *is* HEAD** |
| `swift-package-manager` audited base `d3dd3090…` | ✅ | ✅ — **it *is* HEAD**; the slice below is uncommitted on top |
| `swift-package-graph` `f13f91f2…` | ✅ | ❌ **NOT an ancestor** |
| `swift-package-graph` `8fbcdb8e…` | ✅ | ✅ — **it *is* HEAD** |

**DISCREPANCY 1 — CLOSED, cause established.** `f13f91f2` is dangling because its author **amended
it**; `8fbcdb8e` is the same commit with a corrected message (the original wrongly claimed the
deleted decoder was field-identical to the one `swift-spm-standard` owns — it was field-identical to
the *manager's*). **`8fbcdb8e` is canonical**, `f13f91f2` historical. History deliberately **not**
rewritten.

**⚠️ DISCREPANCY 2 — AMENDED. One document is absent; the other EXISTS OUTSIDE THE REPO.**

- `Workspace/WHY_WORKSPACE_EXISTS.md` — **genuinely absent.** Not in the repo, not under `Developer`,
  not under `Downloads`.
- `WORKSPACE_LOCAL_RESOLUTION_IMPLEMENTATION_PLAN.md` — **EXISTS at
  `<downloads>/WORKSPACE_LOCAL_RESOLUTION_IMPLEMENTATION_PLAN.md`, 53,681 bytes.**
  It was supplied as an attachment and never lived in the repo, which is why a repo-scoped probe
  correctly returned nothing. **It is the founding document of this entire arc and has been read in
  full.** Do not treat it as non-existent.

The earlier claim that both were absent was a **true observation about the wrong search space** — a
repo-scoped probe answering a question that was not repo-scoped. Positive control was sound
(the same `find` locates `ARCHITECTURE.md`); the *scope* was the defect, not the probe.

**Consequence:** the actual governing record is `ARCHITECTURE.md` + the Downloads implementation plan
+ this file + the two Adjudications. Do not block on `WHY_WORKSPACE_EXISTS.md`; do not invent it.

## 4. Completed capabilities

- Foundation-free `JSON.decode<T: Decodable>()`.
- Corrected unkeyed cursor semantics and floating-range handling in `swift-json`.
- `Package.Manifest.Evaluation` and dependency evaluation types.
- Remote source control, mirror-local source control, filesystem, and registry distinctions.
- Products, targets, platforms, traits, and dependency-product back-fill.
- Package-graph delegation away from its deleted decoder (`8fbcdb8e`).
- Package-scoped mirror entries used for staged local development (`swift-package-manager` only).
- **The SwiftPM self-deadlock finding:** a test runner invoking SwiftPM against the package whose
  `.build` it currently holds **waits indefinitely rather than failing**. Cost 1002 seconds of a
  2-slot coordinator. If a gate hangs rather than fails, this is the first suspect.

## 5. Current uncommitted slice — verified present

In `swift-package-manager`, on top of `d3dd3090`, all eight entries confirmed on disk:

```
 M  Sources/Package Manager/Package.Manager+Manifest.swift
 M  Sources/Package Manager/Package.Manager.Error.swift
 ??  Sources/Package Manager/Package.Manager+Dump.swift
 ??  Sources/Package Manager/Package.Manager+Evaluation.swift
 ??  Tests/Fixtures/Broken/   Tests/Fixtures/Composed/   Tests/Fixtures/Dependency/
 ??  Tests/Package Manager Tests/Package.Manager.Evaluation Tests.swift
```

**Reported state (author's, to be re-verified by the new session, not assumed):** 15 tests pass,
0 lint violations across 92 rules / 11 files, 0 production and 0 test warnings, `git diff --check`
clean, 0 Foundation imports in `Sources/`.

Expected API:

```swift
Package.Manager.evaluation(
    at directory: Swift.String
) throws(Package.Manager.Error) -> Package.Manifest.Evaluation
```

sharing **one** `dump-package` invocation path with `manifest(at:)`.

**⚠️ It is uncommitted only because of a standing instruction: _do not commit before supervisory
review_. That instruction is still in force.** The review is the principal's; the team lead routes
it and does not substitute its own judgement.

**⚠️ REPRODUCIBILITY LIMIT ON THIS SLICE.** It required a second entry in
`swift-package-manager/.swiftpm/configuration/mirrors.json` (machine-local, gitignored) so the
package could resolve an unpushed `swift-json` commit. Until `swift-json` (**ahead 2**) and
`swift-spm-standard` (**ahead 1**) are pushed, **nobody on another machine can reproduce these
results.** Both are already PUBLIC repositories, so the gap is a *push*, not a visibility change.
A package-scoped `mirrors.json` **REPLACES** the global map rather than merging — a package with a
scoped file gets *only* those entries. **Do not delete this file.**

## 6. Immediate milestone

Not "finish all Workspace architecture." It is:

> **Prove that a dependant with an unchanged canonical URL manifest can be built against a selected
> mutable local dependency through generated path-based composition, and can be restored cleanly.**

## 7. Remaining dependency-ordered work

1. Finalize and commit `Package.Manager.evaluation(at:)`.
2. Model only the minimum `workspace-state.json` representation needed for the proof.
3. Add state inspection and materialized-path derivation to `swift-package-manager`.
4. Run a controlled generated-composition experiment using `.package(path:)`.
5. Prove a sentinel change in the selected local source is observed by the dependant.
6. Prove restoration to ordinary managed resolution.
7. Add the smallest Workspace-owned planning/reporting surface around the proven mechanism.
8. Only then decide which additional backend work is necessary.

## 8. Explicitly deferred

Broad Git-worktree implementation · broad Xcode workspace generation or verification · editable
dependency workflows · remote service/daemon architecture · context persistence beyond the first
useful CLI flow · whole-Institute materialization · release automation · UI work · unrelated lint
or warning debt.

## 9. Safety rules

- inspect → plan → apply → verify → report → repair/remove;
- no direct mutation of tracked manifests to path dependencies;
- no hand-editing `Package.resolved`;
- no global mirror edits; package-scoped ignored mirrors only when explicitly justified and recorded;
- the coordinator owns development build/test execution —
  `Scripts/swift-build package --package-path <p> <subcommand>`, **flag before subcommand**;
- **never invoke SwiftPM against a package whose `.build` is locked by the caller** (§4);
- **no pushes unless explicitly authorized** — and note the publication gate at the head of this file;
- do not destroy or overwrite concurrent work;
- preserve exact local commits and dirty states until reconciled.

### Fleet-wide protections in force (other lanes are live)

**No session may `clean`, `reset --hard`, checkout across, or branch-switch in:**
`swift-package-manager` (8 uncommitted files; **and its `.swiftpm/configuration/mirrors.json` must
not be deleted**) · `swift-spm-standard` (ahead 1) · `swift-json` (ahead 2) ·
`swift-package-graph` (ahead 1). A `reset --hard` destroys unpushed commits as surely as
`clean -fd` destroys untracked files.

**Toolchain: Xcode's bundled toolchain. No `TOOLCHAINS`, no carve-outs.** Any document specifying a
`TOOLCHAINS` identifier is stale.

**Coordinator capacity is 2 slots against a live multi-lane fleet.** Ask the team lead before taking
one.
