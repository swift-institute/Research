# Repository Safety Inspection

**Gate:** 0A — pre-project repository and capability audit
**Date:** 2026-07-24
**Method:** read-only. `git rev-parse`, `git status --porcelain`, `git remote get-url`, `git rev-list --left-right --count`, `git symbolic-ref refs/remotes/origin/HEAD`, and `head -1 Package.swift`.
**Mutation performed:** none. No checkout, switch, reset, clean, stash, pull, merge, rebase, fetch, or build was executed against any inspected repository.
**Path convention:** this repository is public; machine-specific path prefixes are rendered as `<developer-root>` deliberately (redacted 2026-07-26, per ADR-001).

---

## 1. Inspection scope

Twenty-three owner and supporting repositories, plus seven representative-catalogue
repositories. Locations were **established by inspection**, not inferred from
organization naming: each path below was confirmed to contain a `.git` directory
and its `origin` remote read with `git remote get-url origin`.

> **Correction — 2026-07-24, supervisory review.** The original wording of this
> paragraph claimed the `origin` remote was "quoted verbatim". **It was not.** The
> column in §2 held a *normalized* `organization/repository` projection with the
> scheme, host, and `.git` suffix stripped. That column is relabelled below to say
> what it actually contains, and the exact strings are recorded in §5, where the
> two fields are kept separate. No exact remote was ever lost — only unrecorded.

## 2. Owner and supporting repositories (original inspection record)

The `origin` column below is a **normalized repository key**, not the exact remote.
See §5.2 for exact `git remote get-url origin` output.

| Repository path | Normalized repository key | Branch | HEAD | Upstream | Ahead/Behind | Working tree | Tools version | Checkout state |
|---|---|---|---|---|---|---|---|---|
| `swift-institute/Workspace` | `swift-institute/Workspace` | `main` | `2c6787d47` → **`ef0579a8b`** | `origin/main` | 0/0 | **12 modified at read time; committed mid-audit** | n/a (root has no manifest) | default branch, see §4.1 |
| `swift-foundations/swift-package-manager` | `swift-foundations/swift-package-manager` | `main` | `d3dd30904` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-foundations/swift-package-graph` | `swift-foundations/swift-package-graph` | `main` | `a76186a9b` | `origin/main` | 0/0 | **4 modified/deleted** | 6.3.3 | default branch, **dirty — in-flight migration** |
| `swift-foundations/swift-xcode` | `swift-foundations/swift-xcode` | `main` | `83b6627d9` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-foundations/swift-git` | `swift-foundations/swift-git` | `main` | `a9955a9d9` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-standards/swift-spm-standard` | `swift-standards/swift-spm-standard` | `main` | `56f326cc5` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-standards/swift-git-standard` | `swift-standards/swift-git-standard` | `main` | `ed8b3796c` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-standards/swift-xcode-standard` | `swift-standards/swift-xcode-standard` | `main` | `d336477d2` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-foundations/swift-file-system` | `swift-foundations/swift-file-system` | `main` | `bde096613` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-foundations/swift-process` | `swift-foundations/swift-process` | `main` | `c7b15b0d9` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-foundations/swift-paths` | `swift-foundations/swift-paths` | `main` | `f20b5315f` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-foundations/swift-json` | `swift-foundations/swift-json` | `main` | `c0d4a4b2e` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-foundations/swift-xml` | `swift-foundations/swift-xml` | `main` | `14e3776be` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-foundations/swift-arguments` | `swift-foundations/swift-arguments` | `main` | `6afc83013` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-foundations/swift-environment` | `swift-foundations/swift-environment` | `main` | `419c83e84` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-foundations/swift-github` | `swift-foundations/swift-github` | `main` | `a46deed46` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-foundations/swift-github-http` | `swift-foundations/swift-github-http` | `main` | `b3cd6d504` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-standards/swift-github-standard` | `swift-standards/swift-github-standard` | `main` | `562fe2e05` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-foundations/swift-manifests` | `swift-foundations/swift-manifests` | `main` | `5078007de` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-foundations/swift-impact` | `swift-foundations/swift-impact` | `main` | `41e95a126` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-primitives/swift-package-primitives` | `swift-primitives/swift-package-primitives` | `main` | `ac4cff34b` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-primitives/swift-graph-primitives` | `swift-primitives/swift-graph-primitives` | `main` | `ca5b9d699` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |
| `swift-primitives/swift-path-primitives` | `swift-primitives/swift-path-primitives` | `main` | `5d5d182ea` | `origin/main` | 0/0 | clean | 6.3.3 | default branch, clean |

All paths are relative to `<developer-root>/`.

> **Correction — 2026-07-24, supervisory review.** Five rows above report
> `Ahead/Behind` as `0/0` that were **never measured** in the original inspection:
> `swift-arguments`, `swift-environment`, `swift-github`, `swift-github-http`, and
> `swift-github-standard`. The original ahead/behind pass covered seventeen
> repositories and those five were not among them; `0/0` was filled in by mistake.
> Three of them are in fact **ahead of origin/main**. The measured values are in
> §5.2. Treat §2's Ahead/Behind column as authoritative only for the eighteen rows
> not named here.

**`origin/HEAD` availability.** Nine repositories have a resolvable
`refs/remotes/origin/HEAD` pointing at `origin/main`. Fourteen do not have the
symbolic ref set locally (`swift-package-manager`, `swift-xcode`, `swift-git`,
`swift-git-standard`, `swift-xcode-standard`, and others). For those, "default
branch" is asserted from upstream tracking (`@{u} = origin/main`, 0 ahead / 0
behind) rather than from a locally recorded default-branch pointer. Recorded as a
**weaker basis**, not an equivalent one.

## 3. Representative-catalogue repositories

| Repository path | Branch | HEAD | Working tree | Tools version |
|---|---|---|---|---|
| `swift-primitives/swift-dimension-primitives` | `main` | `f123b8b8a` | clean | 6.3.3 |
| `swift-standards/swift-color-standard` | `main` | `ba61bd79b` | clean | 6.3.3 |
| `swift-foundations/swift-color` | `main` | `0799a5711` | clean | 6.3.3 |
| `swift-foundations/swift-url-routing` | `main` | `45548aaa5` | clean | 6.3.3 |
| `swift-foundations/swift-http-body` | `main` | `eb62e8c3e` | clean | 6.3.3 |
| `swift-foundations/swift-witnesses` | `main` | `8297968ac` | clean | 6.3.3 |
| `swift-foundations/swift-html` | `main` | `d76cb8a99` | clean | 6.3.3 |

## 4. Dirty repositories — preserved, not altered

### 4.1 `swift-institute/Workspace` @ `2c6787d47` — 12 modified files, **committed mid-audit as `ef0579a8b`**

> **Revision correction.** The twelve files below were uncommitted when read. Before
> this audit finished, the maintainer committed them as
> `ef0579a8 "Migrate Workspace Application GitHub-family sites to the Tagged API"`
> (12 files, +82/−70). The committed content was verified to match what was audited
> (spot-check: `Workspace.Repository.Key.swift` retains the hard-coded
> `"https://github.com/"` / `".git"` parser recorded as W-04). **The audited content
> is therefore the content now committed at `ef0579a8b`**, and every ⚠ marker in the
> Workspace Responsibility Audit should be read as "was uncommitted when read, now
> committed at `ef0579a8b`" rather than "may still move". No file was altered by
> this audit.

```
 M Application/Sources/Workspace Application/Workspace.Inventory.Error.swift
 M Application/Sources/Workspace Application/Workspace.Inventory.Merge.Error.swift
 M Application/Sources/Workspace Application/Workspace.Inventory.Merge.swift
 M Application/Sources/Workspace Application/Workspace.Inventory.Organization.swift
 M Application/Sources/Workspace Application/Workspace.Inventory.Policy.Error.swift
 M Application/Sources/Workspace Application/Workspace.Inventory.Policy.swift
 M Application/Sources/Workspace Application/Workspace.Inventory.Repository.swift
 M Application/Sources/Workspace Application/Workspace.Repository.Key.swift
 M Application/Tests/…/GitHub.Repository.Summary+fixture.swift
 M Application/Tests/…/Workspace.Inventory.Client Tests.swift
 M Application/Tests/…/Workspace.Inventory.Merge Tests.swift
 M Application/Tests/…/Workspace.Inventory.Writer Tests.swift
```

This is **live, in-progress user work on the inventory subsystem**. The count grew
from 7 to 12 files during this inspection session, i.e. the tree was being edited
concurrently. The Workspace Responsibility Audit therefore classifies the
**working-tree state**, and every inventory-related row is marked as reflecting
uncommitted content that may move.

### 4.2 `swift-foundations/swift-package-graph` @ `a76186a9b` — 4 changes, in-flight migration

```
 M Package.swift
 D Sources/Package Graph/Package.Manifest.Decode.swift      (−217 lines)
 M Sources/Package Graph/Package.Workspace.Error.Kind.swift
 M Sources/Package Graph/Package.Workspace.swift            (−72/+20)
```

The uncommitted diff removes `swift-package-graph`'s own manifest decoder and
subprocess spawn, and replaces them with a dependency on `swift-package-manager`:

- removed dependencies: `swift-byte-primitives`, `swift-process`, `swift-json`
- added dependency: `swift-package-manager` (product `Package Manager`)
- `Package.Workspace.swift` drops `Process.Spawn.Configuration` construction for
  `dump-package` and delegates to `Package_Manager`

**This is a de-duplication of exactly one of the ownership conflicts this audit was
commissioned to find, already underway and unpublished.** It materially changes the
capability matrix and is recorded there as `unresolved` rather than as either the
committed or the intended state. See Owner Capability Matrix §4.1 and §9.1.

### 4.3 Untracked local-only state — `Workspace/Application/Packages/swift-git`

```
Application/Packages/swift-git -> <developer-root>/swift-foundations/swift-git
```

A symlink, ignored by `.gitignore` (`Packages/`). It is the on-disk artifact left
by `swift package edit … --path`. `Application/.build/workspace-state.json`
contains **zero** entries whose state name is `edited`, and records `swift-git` as
`remoteSourceControl` at `https://github.com/swift-foundations/swift-git.git`.

The symlink and the resolver state therefore **disagree**. Preserved untouched and
recorded as evidence in Owner Capability Matrix §3.

> **✅ CLOSED 2026-07-28 — explained, not merely observed.**
>
> This disagreement is not a mystery and not corruption. It is the deterministic
> result of **deleting `.build` while a `swift package edit` overlay is active**,
> reproduced from a clean fixture:
>
> ```
> edit applied    → Packages/dep -> …/dep    state: edited
> rm -rf .build   → Packages/dep -> …/dep    state: (gone)
> swift build     → Packages/dep -> …/dep    state: sourceControlCheckout
>                   exit 0 · canonical source compiled · no warning
> ```
>
> The symlink survives because it lives in the worktree; the `edited` entry does
> not because it lives in `.build`. The next build resolves canonical, succeeds,
> and says nothing. `swift package unedit` in that state exits **1** with
> *"dependency not in edit mode"* — SwiftPM is not confused, but nothing consults
> it. Reproduced on **both** build systems (`swiftbuild` and `native`), so it is a
> workspace-state property rather than a build-engine one.
>
> Two things follow, and they are why this is worth closing rather than deleting.
> The state is **two facts that can disagree and that SwiftPM will not
> reconcile** — which makes half-applied detection a first-class requirement of
> any edit-based capability, not a nicety. And re-running `edit` over a stale
> symlink **repairs** it, so the condition is recoverable by command.
>
> Full reproduction, controls, and the design response:
> `DESIGN-Local-Overlay-2026-07-28.md` §4.

## 5. Conditions that would have required a build

None. Every finding in this Gate-0A slice was established from repository content,
Git plumbing, and pre-existing generated state (`.build/workspace-state.json`,
`~/.swiftpm/configuration/mirrors.json`). No SwiftPM or Xcode command was run, so
no scratch, checkout, resolution, or DerivedData state was created or mutated.

Where a capability could only be settled by execution, it is marked
`investigate in empirical spike` in the capability matrix rather than asserted.

---

# Gate 0A completion snapshot — 2026-07-24, 12:24 UTC

Captured **immediately before** the first baseline build command was issued. This
section does not replace §§1–4; it records the state the baseline was executed
against, and supplies the exact remote strings §2 omitted.

Baseline evidence is in `Baseline Build and Test Evidence.md`.

## 5.1 Remote-location field definitions

Two distinct fields, never substituted for one another:

- **Exact origin** — the byte-for-byte output of `git remote get-url origin`,
  preserving scheme, host, path, and `.git` suffix.
- **Normalized repository key** — an `organization/repository` projection, derived
  for convenience only.

**Redaction:** none was necessary. No remote contains a userinfo component,
credential, or token: `git remote get-url origin` output contains no `@` character
in any of the 23 repositories.

**Remote-form survey.** All 23 remotes are HTTPS with an explicit `.git` suffix.
**Zero** scp-like (`git@host:org/repo.git`), `ssh://`, `file://`, or plain
filesystem remotes are present. Every repository has **exactly one** remote, named
`origin`, and its push URL is identical to its fetch URL — verified with
`git remote` and `git remote get-url --push origin`.

Note the contrast with resolver state: `Workspace/Application/.build/workspace-state.json`
records `swift-file-system` and `swift-spm-standard` at `file://<developer-root>/…`.
Those are **SwiftPM dependency locations**, not Git remotes, and they are unaffected
by this correction.

## 5.2 Snapshot table

Full 40-hex HEAD revisions. `A/B` is ahead/behind `@{u}`. `Dirty` counts
`git status --porcelain` lines, untracked included.

| Repository path | Exact origin | Normalized repository key | Branch | HEAD | Upstream | A/B | Dirty |
|---|---|---|---|---|---|---|---|
| `swift-institute/Workspace` | `https://github.com/swift-institute/Workspace.git` | `swift-institute/Workspace` | `main` | `ef0579a8b1e9a1c67ede5f68a83eed82d01da217` | `origin/main` | **1/0** | 1 |
| `swift-foundations/swift-package-manager` | `https://github.com/swift-foundations/swift-package-manager.git` | `swift-foundations/swift-package-manager` | `main` | `d3dd30904d2645a8a124e989494ef4edab2457af` | `origin/main` | 0/0 | 0 |
| `swift-foundations/swift-package-graph` | `https://github.com/swift-foundations/swift-package-graph.git` | `swift-foundations/swift-package-graph` | `main` | `a76186a9b08c8aaab943c40dbb801076678a99a4` | `origin/main` | 0/0 | **4** |
| `swift-foundations/swift-xcode` | `https://github.com/swift-foundations/swift-xcode.git` | `swift-foundations/swift-xcode` | `main` | `83b6627d999f48ae1db14cf8ab591bb4e742d537` | `origin/main` | 0/0 | 0 |
| `swift-foundations/swift-git` | `https://github.com/swift-foundations/swift-git.git` | `swift-foundations/swift-git` | `main` | `a9955a9d910b82d6d9fb9a28b6602e4ffc7c57ec` | `origin/main` | 0/0 | 0 |
| `swift-foundations/swift-impact` | `https://github.com/swift-foundations/swift-impact.git` | `swift-foundations/swift-impact` | `main` | `41e95a126bb21cda1de31e74e517c0d430338b7d` | `origin/main` | 0/0 | 0 |
| `swift-foundations/swift-manifests` | `https://github.com/swift-foundations/swift-manifests.git` | `swift-foundations/swift-manifests` | `main` | `5078007de72c23a7e699f8addab588cf9ae7ed0c` | `origin/main` | 0/0 | 0 |
| `swift-foundations/swift-file-system` | `https://github.com/swift-foundations/swift-file-system.git` | `swift-foundations/swift-file-system` | `main` | `bde096613792be98aed1635d315d781dee2fdfd0` | `origin/main` | 0/0 | 0 |
| `swift-foundations/swift-paths` | `https://github.com/swift-foundations/swift-paths.git` | `swift-foundations/swift-paths` | `main` | `f20b5315f4b77d5aa6d196786fee1d1d02659b00` | `origin/main` | 0/0 | 0 |
| `swift-foundations/swift-process` | `https://github.com/swift-foundations/swift-process.git` | `swift-foundations/swift-process` | `main` | `c7b15b0d9b875d519e758d0dc744f6a14ca8bfee` | `origin/main` | 0/0 | 0 |
| `swift-foundations/swift-json` | `https://github.com/swift-foundations/swift-json.git` | `swift-foundations/swift-json` | `main` | `c0d4a4b2e3f8e43e6362d07ab0ebd8397cd2d0a1` | `origin/main` | 0/0 | 0 |
| `swift-foundations/swift-xml` | `https://github.com/swift-foundations/swift-xml.git` | `swift-foundations/swift-xml` | `main` | `14e3776be7673e86f84a148372a5454e6c1676f7` | `origin/main` | 0/0 | 0 |
| `swift-foundations/swift-arguments` | `https://github.com/swift-foundations/swift-arguments.git` | `swift-foundations/swift-arguments` | `main` | `6afc830138d07115336f215e63cdb44784977ef6` | `origin/main` | 0/0 ✎ | 0 |
| `swift-foundations/swift-environment` | `https://github.com/swift-foundations/swift-environment.git` | `swift-foundations/swift-environment` | `main` | `419c83e84b40408e0f7c5e0a7271c4c63973d5c7` | `origin/main` | 0/0 ✎ | 0 |
| `swift-foundations/swift-github` | `https://github.com/swift-foundations/swift-github.git` | `swift-foundations/swift-github` | `main` | `a46deed467e5c730fb46a3e124dbac60c7cde055` | `origin/main` | **1/0** ✎ | 0 |
| `swift-foundations/swift-github-http` | `https://github.com/swift-foundations/swift-github-http.git` | `swift-foundations/swift-github-http` | `main` | `b3cd6d5047bbcb25dcc64c128477e5555d9a67eb` | `origin/main` | **2/0** ✎ | 0 |
| `swift-standards/swift-spm-standard` | `https://github.com/swift-standards/swift-spm-standard.git` | `swift-standards/swift-spm-standard` | `main` | `56f326cc5fe65046ff31f1112f38302fc25133b0` | `origin/main` | 0/0 | 0 |
| `swift-standards/swift-git-standard` | `https://github.com/swift-standards/swift-git-standard.git` | `swift-standards/swift-git-standard` | `main` | `ed8b3796c729c3eac07ff32a41c7cfa6d8f7e208` | `origin/main` | 0/0 | 0 |
| `swift-standards/swift-xcode-standard` | `https://github.com/swift-standards/swift-xcode-standard.git` | `swift-standards/swift-xcode-standard` | `main` | `d336477d250498f30408dacd1feb0025f003bef5` | `origin/main` | 0/0 | 0 |
| `swift-standards/swift-github-standard` | `https://github.com/swift-standards/swift-github-standard.git` | `swift-standards/swift-github-standard` | `main` | `562fe2e058759a15b4aa54647473b47445e77390` | `origin/main` | **3/0** ✎ | 0 |
| `swift-primitives/swift-package-primitives` | `https://github.com/swift-primitives/swift-package-primitives.git` | `swift-primitives/swift-package-primitives` | `main` | `ac4cff34ba73fc3315a9e97bb8e8a042ea6de136` | `origin/main` | 0/0 | 0 |
| `swift-primitives/swift-graph-primitives` | `https://github.com/swift-primitives/swift-graph-primitives.git` | `swift-primitives/swift-graph-primitives` | `main` | `ca5b9d69980d92fe129575b69945182cd3e6d04d` | `origin/main` | 0/0 | 0 |
| `swift-primitives/swift-path-primitives` | `https://github.com/swift-primitives/swift-path-primitives.git` | `swift-primitives/swift-path-primitives` | `main` | `5d5d182eadd783d76ab525b606175cb86f00fe84` | `origin/main` | 0/0 | 0 |

✎ = value measured for the first time in this snapshot; §2 reported `0/0`
without measurement.

**Four repositories hold unpushed commits**: `Workspace` (1),
`swift-github` (1), `swift-github-http` (2), `swift-github-standard` (3). No
attempt was made to push, fetch, or otherwise reconcile them.

## 5.3 Workspace — production revision versus research artifacts

| Component | State |
|---|---|
| Production revision | `ef0579a8b1e9a1c67ede5f68a83eed82d01da217`, **1 ahead of `origin/main`, unpushed** |
| Tracked working-tree changes | **none** — `git status --porcelain` shows no `M`, `A`, `D`, or `R` entry |
| Untracked research artifacts | `?? Research/` — the five Gate 0A documents, uncommitted and unstaged |

The Application package built and tested in this baseline is therefore exactly
`ef0579a8b`. The research artifacts are untracked Markdown and JSON under
`Research/Local Resolution/`; they are not part of any SwiftPM target and cannot
affect a build.

## 5.4 `swift-package-graph` — preserved dirty state and fingerprint

The in-flight migration described in §4.2 is **unchanged and uncommitted**. It was
fingerprinted immediately before the baseline so the build result can be tied to
the exact dirty state.

| Field | Value |
|---|---|
| Base revision | `a76186a9b08c8aaab943c40dbb801076678a99a4` |
| Fingerprint command | `git diff --binary` |
| Patch size | 15,477 bytes |
| **SHA-256 of `git diff --binary`** | `3134766944144ab819a5311dc162f79a5fcb36790af4839a4d40159a240a3b84` |
| Untracked files | none |

```
M	Package.swift
D	Sources/Package Graph/Package.Manifest.Decode.swift
M	Sources/Package Graph/Package.Workspace.Error.Kind.swift
M	Sources/Package Graph/Package.Workspace.swift
```

The fingerprint is re-verified after the baseline in
`Baseline Build and Test Evidence.md` §5. Any change to it invalidates the
`swift-package-graph` baseline row.

## 5.5 Coordinator state at snapshot time

```json
{
  "slots": 2,
  "occupied": 0,
  "available": 2,
  "jobs_per_swiftpm_build": 3,
  "state_root": "/private/tmp/swift-institute-build-coordinator-v1"
}
```

## 5.6 Pre-flight safety check

`Package.resolved` was confirmed **untracked in every one of the 23 repositories**
(`git ls-files --error-unmatch Package.resolved` and `git ls-files '*Package.resolved'`
both empty everywhere). A baseline build therefore cannot modify a tracked file by
regenerating it — the condition that would otherwise have been a stop condition.
