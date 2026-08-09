# Local-resolution milestone — evidence of completion

**Date:** 2026-07-26 · **Lane:** Lane B of the Workspace-first restart ·
**Closes:** the *Workspace Finalization Handoff* §7 work list, items 1–7.

This repository is **public**. Paths below use `<placeholder>` form deliberately,
and no figure here was copied forward — every one was re-measured on 2026-07-26.

---

## 0. The handoff's own state table was stale in four of six rows

The handoff (§3) is dated 2026-07-24 and carries a warning that it must be
verified rather than trusted. It must: re-measuring on 2026-07-26 found four of
its six repository rows had moved, and **two of its facts had inverted**.

| Repository | Handoff (2026-07-24) | Measured 2026-07-26 |
|---|---|---|
| `swift-institute/Workspace` | `b917a00`, **ahead 1, must not push** | `619ecf67`, **in sync — published** |
| `swift-standards/swift-spm-standard` | `693e0d7d`, ahead 1 | `4a1c2a06`, in sync |
| `swift-foundations/swift-json` | `cb2e77dc`, ahead 2 | `5e1dd42c`, in sync |
| `swift-foundations/swift-package-manager` | `d3dd3090`, **8 uncommitted entries**, **PRIVATE** | `a7790d8b`, **clean**, **PUBLIC** |
| `swift-foundations/swift-package-graph` | `8fbcdb8e`, ahead 1 | `c881a97d`, in sync |
| `swift-foundations/swift-impact` | `41e95a12` | `e4a2ec5b`, PRIVATE (unchanged in kind) |

Two consequences that change what this lane was asked to do:

1. **§7 item 1 — "finalize and commit `Package.Manager.evaluation(at:)`" — was
   already done and pushed.** The eight-entry uncommitted slice is now commit
   `8ec03e2c`, *Evaluate SwiftPM manifests through the shared invocation*, with
   `a7790d8b` on top. There was nothing to commit. What this lane could still
   contribute was **independent re-verification**, which is §1 below.
2. **`swift-package-manager` is PUBLIC, not private.** Resolved with
   `gh repo view` rather than inferred. The handoff's publication gate was
   written on the opposite premise — see §5.

## 1. Gate re-verification — fresh, all four axes, both packages

Run through the machine-wide coordinator only, Xcode's bundled toolchain, no
`TOOLCHAINS`, gates backgrounded. Both test runs used the coordinator's
`--fresh`, which re-resolves inside the same slot acquisition before testing —
so these are greens over freshly moved branch pins, not over stale ones.

| Axis | `swift-package-manager` @ `a7790d8b` | `Workspace/Application` @ `9a7bcd1e` |
|---|---|---|
| `package test --fresh` | **exit 0** · `Test run with 19 tests in 6 suites passed` | **exit 0** · `Test run with 54 tests in 33 suites passed` |
| coordinator cross-check | `GREEN — every instrument agrees (1102 compile step(s), freshly compiled)` | `GREEN — every instrument agrees (549 compile step(s), freshly compiled)` |
| `swift-build lint` | **exit 0** · `93 active rules · 14 files linted · 0 violations` | **exit 0** · `93 active rules · 55 files linted · 45 violations` |
| `swift-format lint --strict` | **exit 0** · 0 findings | **exit 0** · 0 findings |

**Both test logs were read in both directions**, per the standing rule that
which line is authoritative is package-dependent. Each log carries XCTest's
`Executed 0 tests, with 0 failures` *and* the swift-testing line; in both
packages the swift-testing line is the real count and the XCTest line is the
empty bridge. Grepping for either alone inverts one of the two results.

**The linter's zero is a measured zero, not an unconfigured one.** Both runs
report `93 active rules` over a non-zero file count, which is the control
against swift-linter's documented zero-rules fallback. A run that had fallen
back would print the same exit 0 having loaded nothing.

**`swift-format`'s zeros carry a positive control and a corrected population.**
A synthetic 250-column file checked against the institute's 200-column
configuration reports `error: [LineLength] line is too long` — so the instrument
does fire. The first run of this axis reported a false red: it flagged
`Tests/Fixtures/Broken/Package.swift`, a manifest that is *deliberately*
unparseable, because the probe omitted `--ignore-unparsable-files`. The real CI
job passes that flag and excludes three fixture paths; re-run against the CI's
own file selection, both packages are clean.

⚠️ **This axis is a floor, not the CI gate.** It ran on macOS, where
`BeginDocumentationCommentWithOneLineSummary` is silent; the same swift-format
reports findings for that rule on Linux. Only the `swift:6.3` container job is
authoritative for it.

### The 45 Workspace/Application linter findings, stated rather than buried

Exit 0 because these rules are advisory at their current severity, and severity
is the lead's to adjudicate. The distribution: `API-ERR-001` 21, `API-ERR-006`
13, `API-NAME-002` 8, `API-IMPL-014` 3, `API-IMPL-003` 3, `API-IMPL-008` 1 —
26 in test code, 19 in production. Five sit on the composition surface this lane
owns (four `API-NAME-002` on `Clause`'s `declaredURL`/`declaredPath` accessors,
one `API-IMPL-014` on `Composition`'s initialiser). They are pre-existing, they
predate this lane, and the handoff defers unrelated lint debt explicitly (§8).
**Recorded, not silently cleared, and not ratcheted.**

## 2. Steps 4–6 proven end to end **through the shipped surface**

The `.package(path:)` backend was measured by the 2026-07-25 spike, but that
spike drove the mechanism by hand and validated the Layer-3 instrument by
*applying its documented derivation* to a real `workspace-state.json` rather
than by compiling it. It named the compiled instrument run as an owed follow-up.
**This run discharges it**: every action below was taken by the committed
`workspace` executable, and every observation below is the committed
`Package.Manager.resolution` / `materialized.source` reporting through it.

### Fixture — real packages, isolated tree, no user checkout touched

Two real institute repositories, freshly cloned into a scratch workspace root
with its own `Workspace.json`; the developer's own checkouts were never read
from or written to.

- **Consumer:** `swift-color-standard`, which declares the dependency by
  canonical `https://github.com/…` URL and additionally depends on
  `swift-iec-61966`, `swift-iso-9899` and `swift-ecma-48` — three siblings that
  stay source-control-resolved throughout and must be left undisturbed.
- **Dependency:** `swift-dimension-primitives`, carrying a local commit
  (`9f6c0bc`) that adds `#warning("WORKSPACE-LOCAL-SENTINEL-…")` and **exists on
  no remote branch** (`git branch -r --contains` empty).

The sentinel is a compiler diagnostic rather than a value, so it proves the
*dependant's compiler read that exact file* without the consumer needing to
reference anything.

**Three distinct locations are in play, which is what makes the measurement
discriminating.** The machine's global mirror map redirects this URL to the
developer's own checkout; the composition points at the scratch clone; and the
compiled tree is a third path again. A tool that reported the mirror target as
the compiled source would be wrong at every step and would still look plausible.

### The cycle, with the instrument's own words

| Step | Action | `workspace verify` reported | Sentinel in build log |
|---|---|---|---|
| **A** canonical baseline | coordinator build, exit 0, `675`/`678` fresh compile steps, cross-check GREEN | `no active composition` · `source-control checkout @ f123b8b8…` · compiled tree `<consumer>/.build/checkouts/swift-dimension-primitives` | **absent** (0) |
| **B** `workspace compose` | exit 0; manifest rewritten `url` → `path`; machine-local-path warning printed | — | — |
| **C** composed build | coordinator build, exit 0, `34` fresh compile steps, cross-check GREEN | `composed (local development source active)` · `local file-system source` · compiled tree = **the local clone** | **present, 33 lines** |
| **D** `workspace restore` + build | restore exit 0; coordinator build exit 0, cross-check GREEN | `no active composition` · `source-control checkout @ f123b8b8…` · compiled tree back under `.build/checkouts` | **absent** (0) |
| **E** clean room | coordinator build, exit 0, `675` fresh compile steps, cross-check GREEN | resolved `f123b8b8…`, 27 dependencies | **absent** (0) |

The verbatim step-C diagnostic, path elided:

```
…/Packages/swift-dimension-primitives/Sources/Dimension Primitives/Chirality.swift:79:10:
warning: WORKSPACE-LOCAL-SENTINEL-…
```

### What each step establishes

**Step 5 — a sentinel change in the selected local source is observed by the
dependant: PROVEN.** The dependant compiled a marker present only in a commit
that exists on no remote, while its `Package.resolved` siblings
(`918c2ec8`, `06b696a1`, `9b0d9d5a`) stayed byte-identical to baseline and the
composed dependency left the pin set entirely as a `fileSystem` entry. This is
the mixed-pin *rewrite* path, not the delete path.

**Step 6 — restoration to ordinary canonical resolution: PROVEN, and the
absence is not a cache artifact.** The restored manifest hashes back to the
canonical value byte-for-byte (`4a63442e…` → composed `8e965e7c…` → restored
`4a63442e…`), `git status` on it is empty, and the ledger is emptied. The
subsequent build **recompiled `Dimension_Primitives` from source — 23 steps,
`Compiling Dimension_Primitives Angle.swift` and siblings — and emitted no
sentinel.** A cache that merely hid the warning would not have recompiled; this
distinguishes real restoration from the mirror backend's stickiness, which is
the failure ADR-001 Finding 1 exists to prevent.

**Nothing was purged between C and D.** Restoration needed only the manifest
rewrite, confirming the spike's finding that the path backend relaxes the
mirror backend's cache-aware-removal requirement.

**ADR-001's required clean-room check: PERFORMED and green.** A copy of the
restored consumer with no `.build` and no pins resolved and built from remotes
alone — 675 fresh compile steps, canonical revision, 27 dependencies, no
sentinel. This is the check ADR-001 calls the only thing that detects Finding 1,
and it is the one the shipped `restore` deliberately does *not* run itself.

**The developer's work was preserved.** After the full cycle the dependency
worktree is clean and still at `9f6c0bc`. Compile-in-place never mutated it.

## 3. Status of the §7 work list

| # | Item | Status |
|---|---|---|
| 1 | Finalize and commit `Package.Manager.evaluation(at:)` | **Landed** `8ec03e2c`, pushed; re-verified green here |
| 2 | Minimum `workspace-state.json` representation | **Landed** as `Package.Resolution` in `swift-spm-standard` `4a1c2a06`, pushed |
| 3 | State inspection + materialized-path derivation | **Landed** `a7790d8b`, pushed; exercised live in §2 |
| 4 | Controlled generated-composition experiment | **Proven** — spike 2026-07-25 (two passes), and re-run here through the shipped CLI |
| 5 | Sentinel change observed by the dependant | **Proven** — §2, through the shipped CLI, on real packages |
| 6 | Restoration to ordinary canonical resolution | **Proven** — §2, including the clean-room check |
| 7 | Smallest Workspace-owned planning/reporting surface | **Landed** `b54c8904` (`compose`/`restore`/`verify`); now exercised end to end rather than only unit-tested |

The milestone as stated in the handoff §6 — *prove that a dependant with an
unchanged canonical URL manifest can be built against a selected mutable local
dependency through generated path-based composition, and can be restored
cleanly* — **is met**, with the one wording correction that for this backend the
manifest is deliberately rewritten and restored byte-identically rather than
left untouched.

## 4. Population covered — the limits, stated so they are not over-read

- **One consumer, one composed dependency, 27 resolved dependencies, one
  transitive level.** Nothing here speaks to multiple roots, deeper closures, or
  nested composition (a composed worktree that itself path-composes an unpushed
  source) — the residual the spike named and this run did not exercise either.
- **Single machine, single toolchain, macOS.** Nothing about Xcode's own
  resolver, Git worktrees, plugins, macros, resources, or traits.
- **"Canonical" here means this machine's canonical resolution.** The global
  mirror map redirects both fixture URLs to local checkouts, so step A resolved
  through a mirror rather than over the network. That makes the mirror-target /
  compiled-tree distinction *sharper*, not weaker — but a true off-machine
  canonical resolve remains unmeasured by this run.
- **The composed manifest carries a machine-local absolute path.** Off-machine
  it fails loudly at resolution rather than resolving to something wrong. That
  is a deliberate design property, and `compose` prints the warning; it is not
  reproduced under this single-machine population.

## 5. Two findings for the lead, neither of them this lane's to resolve

**1. The handoff's publication gate rests on a premise that no longer holds.**
It states that `Workspace` sits at *ahead 1* and must not be pushed, and that
machine paths in `Research/Local Resolution/` are acceptable *because the corpus
is unpushed*. `Workspace` is now in sync with its remote, so the corpus is
published: 44 machine-path occurrences across 8 files in that directory alone,
and 123 files repository-wide. This is the disclosure debt ADR-001 already
records — **noted, not acted on**: a pushed exposure is not undone by deletion,
history rewriting is a hard stop, and these are paths and a username rather than
credentials. The forward remedy is to stop adding, which this document observes.

**2. The same handoff describes `swift-package-manager` as PRIVATE, and it is
PUBLIC.** Any reasoning that treated it as a safe place for internal detail
needs re-checking against the resolved value rather than the table.

## 6. Evidence provenance

Every figure above is the coordinator's own log line and the command's own exit
status, captured immediately after the command under test. Nothing is read from
a wrapper, a notification, or a truncated pipe. Build logs, `workspace-state.json`
snapshots at each step, pin ledgers, and the `verify` transcripts are session
scratch and are **not** intended to survive; the durable claims are the ones
written here.
