# swift-impact — Design

<!--
---
version: 1.1.0
last_updated: 2026-07-22
status: DECISION
research_tier: 2
applies_to: [swift-impact]
normative: true
---
-->

## Context

### Trigger

A developer refactoring a primitive (e.g., `swift-sequence-primitives`) needs a fast inner-loop signal of "what downstream packages did I just break?" Today's workflow is manual: change → `swift build` in the upstream → commit → manually identify dependents → `swift build` each → repeat. The grandparent arc (`downstream-impact-ci-for-swiftpm-ecosystems.md` v1.0.0) initially framed this as a CI problem, but the principal reframed it 2026-05-14 as a **local-development-velocity** problem: most Institute packages are still private (no CI runs per `[CI-032]`), but every package is on the developer's filesystem, and the SwiftPM mirrors mechanism already substitutes URL deps to local checkouts globally. The bottleneck is *discovery + orchestration*, not substitution.

### Scope

This document specifies `swift-foundations/swift-impact` — an L3 Foundation providing a CLI and library for "build downstream dependents of a package against its current working copy and report classified results". The library composes `swift-package-graph` for the dependency graph and uses `swift-process` to submit leaf operations to the machine-wide `swift-build` coordinator; the executable is launched by that coordinator.

Out of scope:

- Graph queries (those are `swift-package-graph`'s mandate).
- Source-level API delta (existing `lint-api-breakage.yml` covers it).
- CI integration (future Phase 1 — a reusable workflow can be added once the local CLI is proven and public packages accumulate).

### Prior research

- `swift-institute/Research/downstream-impact-ci-for-swiftpm-ecosystems.md` v1.0.0 (2026-05-14) — the grandparent arc; established the library-tier prior art (tokio's `test-hyper`/`test-quinn`, Vapor's `test-providers` matrix) and the universal absence of automated reverse-dep build orchestration outside Rust's crater + Haskell's Stackage + Apple's swift-source-compat-suite.
- **`swift-institute/Research/swift-package-domain-l1-l2-split.md` v1.0.0 (2026-05-14)** — the L1/L2/L3 layering for the SwiftPM domain. swift-impact consumes the L3 substrate (`swift-package-graph`) which in turn consumes L2 (`swift-spm-standard`) for the typed manifest.
- `swift-foundations/swift-package-graph/Research/design.md` v1.1.0 (2026-05-14) — the immediate substrate this package depends on.
- `swift-institute/Skills/research-process/SKILL.md` — `[RES-018]` premature primitive (cleared in Q8 below), `[RES-026]` citations.

---

## Question

How should the Institute provide a developer-facing CLI + library for "what downstream packages does my current working copy of package X break?" — such that:

1. The inner loop is fast (seconds per dependent in debug builds);
2. Errors are surfaced as actionable file:line:col diagnostics, not just pass/fail;
3. The tool works on the full 141-package workspace regardless of public/private visibility (local execution, no GitHub dependency);
4. The library is reusable by future CI integration, editor tooling, and audit pipelines without locking the CLI into one entry point.

Decomposes into:

1. **Domain mandate**: what does swift-impact own; what does it not own?
2. **Orchestration model**: parallel build fan-out; baseline comparison; wave traversal.
3. **Substitution mechanism**: why local mirrors + working-copy state make this work without `swift package edit`.
4. **Diagnostic parsing**: how to surface compiler output as file:line errors.
5. **Result classification**: A/B/C/D classes mirroring `lint-api-breakage.yml`.
6. **Public API surface**: what `Impact` types are defined here vs imported.
7. **CLI surface**: `swift-impact` executable design.
8. **Layer placement**: L3.

---

## Analysis

### Q1 — Domain mandate

**Owns**:

- The orchestration logic: given an upstream package + a workspace, submit dependent-package leaves (discovered via swift-package-graph) and aggregate results.
- Wave-by-wave execution (BFS over the reverse-dep graph at increasing depths).
- Baseline comparison: build dependents twice — once against the upstream's `main` (or HEAD before the change) and once against the working copy — and surface the *delta*.
- Result aggregation + classification (A/B/C/D mirroring `lint-api-breakage.yml`'s pilot taxonomy).
- Diagnostic extraction from compiler stdout/stderr into structured `Diagnostic.Record` values (using `swift-diagnostic-primitives` at L1).
- The CLI binary `swift-impact` exposing the above.

**Does not own**:

- The dep graph (→ `swift-package-graph`).
- The manifest model (→ `swift-spm-standard`).
- Generic name typing (→ `swift-package-primitives`).
- Build capacity, root locking, deadlines, process groups, and cleanup (→ machine-wide `swift-build`).
- Generic subprocess execution mechanics for coordinator and git invocations (→ `swift-process`).
- The compiler-output text format itself (→ the Swift compiler; swift-impact parses what swiftc emits).
- Graph visualization (→ `swift-package-graph`'s `dot()`).

### Q2 — Orchestration model

The core inner loop:

```
1. From swift-package-graph: directDependents(of: upstream) — set of N package names
2. (Optional) From swift-package-graph: dependents at depth K → list of N waves
3. For each wave (in depth order):
     Submit every package in the wave through one TaskGroup:
       a. Spawn `swift-build package build` for that package root
          with the coordinator-owned timeout
       b. Capture stdout + stderr
       c. Parse for Diagnostic.Record values
       d. Record (package, status, duration, diagnostics) → Impact.Run.PackageResult
     Wait for the complete wave before submitting the next wave
4. Aggregate all results → Impact.Run.Result
5. Apply baseline comparison: subtract results that also failed in baseline run → Impact.Run.ClassifiedResult
```

**Why this works without `swift package edit --path`**: the principal-configured SwiftPM mirrors already substitute Institute package URLs to local checkouts. When a coordinator leaf builds a dependent, SwiftPM resolves its dependencies through those mirrors and picks up the upstream's working copy automatically. **No edit/unedit dance and no Package.swift mutation.** swift-impact verifies the premise through the coordinator's machine-readable `package get-mirror` leaf.

For workspaces where a required mirror is not configured, swift-impact reports an actionable setup error before dependent builds begin. It does not fall back to `swift package edit`.

**Single scheduler**: swift-impact owns no capacity bound. Its TaskGroup may submit a complete independent wave, but every child waits on `swift-build`'s package-root lock and global slot. The top-level `swift-build impact` launcher completes swift-impact's self-build and releases both the swift-impact root lock and its slot before executing the orchestrator. Baseline and working-copy passes remain sequential.

**Timeout boundary**: `Impact.Run.Configuration.timeout` is forwarded to each coordinator leaf. The deadline starts only after that leaf owns its root lock and global slot. swift-process's timeout is nil; the coordinator returns 124 only after TERM, grace, KILL when required, direct-child reap, and proof that the owned process group is absent.

**Baseline comparison**: optional `--baseline` flag. When set:

```
1. git stash (or git worktree checkout main) in upstream package
2. Run the full orchestration → baseline_result
3. git stash pop (or worktree cleanup) — restore working copy
4. Run the full orchestration → head_result
5. Diff: package failures in head but not baseline → CLASS A (real)
        package failures in baseline AND head → CLASS B (pre-existing)
```

v0.1 baseline implementation: uses `git stash` (simpler than worktrees); v0.2 considers worktree variant for cleaner semantics.

**Wave traversal**: `--wave N` flag exposes depth-N transitive dependents. Default N=1 (direct only); N=∞ for the full transitive closure. Each wave runs sequentially (wait for wave K to finish before starting wave K+1), but packages within a wave run in parallel.

### Q3 — Substitution mechanism

Verified 2026-05-14 from `/Users/coen/Developer/swift-institute/Scripts/setup-mirrors.sh`: the Institute's mirror file generates entries like:

```json
{
  "mirror": "/Users/coen/Developer/swift-primitives/swift-buffer-primitives",
  "original": "https://github.com/swift-primitives/swift-buffer-primitives.git"
}
```

SwiftPM's resolver consults this file at every `swift build` / `swift test` / `swift package resolve`. Any local checkout listed in the mirror file is what SwiftPM uses to satisfy that dependency. The working copy of the upstream is therefore the source of truth for every dependent build automatically.

swift-impact's substitution mechanism is **trust the mirrors**. v0.1 verifies the mirror file exists and contains an entry for the upstream package; surfaces an actionable error otherwise.

### Q4 — Diagnostic parsing

The Swift compiler emits diagnostics in a recognizable text format:

```
/path/to/Sources/Foo/Bar.swift:42:8: error: cannot find 'SequenceOfOne' in scope
    let x = SequenceOfOne()
            ^
/path/to/Sources/Foo/Baz.swift:88:14: warning: missing argument label
```

Format: `<path>:<line>:<col>: <severity>: <message>` followed by optional source-snippet lines.

swift-impact's diagnostic path:

- Reads coordinator-leaf stdout + stderr line-by-line.
- Delegates compiler-text parsing to `Diagnostics.Parser` from `swift-diagnostics`.
- Emits one `Diagnostic.Record` per recognized diagnostic (using the L1 type from `swift-diagnostic-primitives`: file path, line, column, severity, message).
- Ignores diagnostic source-snippets (they're not part of the structured signal).

### Q5 — Result classification

Mirrors `lint-api-breakage.yml`'s A/B/C/D taxonomy:

| Class | Meaning in swift-impact context | Action |
|---|---|---|
| **A** | Dependent failed against working copy, passed against baseline | Real breakage caused by upstream change. Surface prominently. |
| **B** | Dependent failed against both baseline and working copy | Pre-existing breakage; not on this refactor's tab. Mention but de-emphasize. |
| **C** | Toolchain / SwiftPM resolver issue (e.g., manifest decode failed, dump-package nonzero exit) | Surface as infrastructure error; not a code-correctness signal. |
| **D** | Local environment issue (e.g., mirror not configured, swift binary not found) | Surface as setup error; user fixes locally. |

Per-package result carries one of these four classes plus the optional diagnostic list (empty for D-class).

### Q6 — Public API surface

**Types defined here** (the thin slice):

```swift
public enum Impact {}

extension Impact {
  /// One execution of swift-impact: build the dependents of `upstream` in `workspace`,
  /// optionally with a baseline comparison.
  public struct Run: Sendable {
    public init(
      upstream: Package.Name,
      workspace: Paths.Path,
      configuration: Impact.Run.Configuration
    )

    public func execute() async throws(Impact.Error) -> Impact.Run.Result
  }
}

extension Impact.Run {
  public struct Configuration: Sendable {
    public let coordinator: Paths.Path             // machine-wide swift-build
    public var depth: Int                          // wave depth; default 1
    public var baseline: Baseline                  // .none | .git(ref: String)
    public var buildConfiguration: BuildConfiguration // .debug | .release
    public var timeout: Duration                   // coordinator leaf timeout
    public var withTests: Bool                     // test after successful build
  }

  public enum Baseline: Sendable {
    case none
    case git(ref: String)  // typically "main" or "HEAD"; uses `git stash`/worktree internally
  }

  public enum BuildConfiguration: Sendable {
    case debug
    case release
  }

  public struct Result: Sendable {
    public var waves: [Impact.Run.Wave]
    public var elapsed: Duration
    public var totalPassed: Int
    public var totalFailedClassA: Int
    public var totalFailedClassB: Int
    public var totalFailedOther: Int   // class C or D
  }

  public struct Wave: Sendable {
    public var depth: Int
    public var packages: [Impact.Run.PackageResult]
  }

  public struct PackageResult: Sendable {
    public var package: Package.Name
    public var status: Status
    public var classification: Classification
    public var diagnostics: [Diagnostic.Record]   // from swift-diagnostic-primitives
    public var elapsed: Duration
  }

  public enum Status: Sendable {
    case passed
    case failed
    case toolchainError(String)
    case environmentError(String)
  }

  public enum Classification: Sendable {
    case classA   // real breakage
    case classB   // pre-existing
    case classC   // toolchain
    case classD   // environment
    case passed   // not failed at all
  }
}

extension Impact {
  public struct Error: Swift.Error, Sendable, Hashable {
    case workspaceLoadFailed(reason: String)
    case mirrorsNotConfigured(expected: File.Path)
    case upstreamNotFound(Package.Name)
    case baselineCheckoutFailed(reason: String)
    case buildOrchestrationFailed(reason: String)
  }
}
```

**Types imported from other layers**:

| Type | From | Layer |
|---|---|---|
| `Package.Name` | swift-package-primitives | L1 |
| `Package.Manifest`, `Package.Workspace` (only if needed by Configuration) | swift-spm-standard | L2 |
| `Package.Graph` (used internally to compute dependents) | swift-package-graph | L3 |
| `Diagnostic.Record`, `Diagnostic.Severity` | swift-diagnostic-primitives | L1 |
| `Process.Spawn.Configuration`, `Process.Status` | swift-process | L3 |
| `Paths.Path` | swift-paths | L3 |
| `Duration` | swift-time-primitives | L1 |
| Coordinator / git subprocesses | swift-process | L3 |

**Types newly defined**: `Impact` namespace, `Impact.Run`, `Impact.Run.Configuration`, `Impact.Run.Baseline`, `Impact.Run.BuildConfiguration`, `Impact.Run.Result`, `Impact.Run.Wave`, `Impact.Run.PackageResult`, `Impact.Run.Status`, `Impact.Run.Classification`, `Impact.Error`. Eleven types — the entire orchestration model, but no primitives.

### Q7 — CLI surface

The `swift-impact` executable wraps the library with `swift-argument-parser`. Operational runs begin at the top-level `swift-build impact` launcher, which injects the canonical coordinator path after releasing its self-build lock and slot.

| Invocation | Behavior |
|---|---|
| `swift-build impact -- --upstream <name> --workspace <dir>` | Direct dependents only, debug build, no baseline. Human-readable report. |
| `swift-impact --depth N` | Wave traversal to depth N (N=∞ for full transitive). |
| `swift-impact --workspace <dir>` | Explicit package-set root. |
| `swift-impact --upstream <package-name>` | Explicit upstream package name. |
| `swift-impact --coordinator <path>` | Injected by `swift-build impact`; not selected independently in operational use. |
| `swift-impact --json` | Machine-readable structured output. |
| `swift-impact --with-tests` | Run the coordinator's test leaf after a successful build leaf. |
| `swift-impact --help` | Usage. |

Human-readable output uses deterministic plain text. `--json` uses swift-json with stable key ordering for machine consumers.

### Q8 — `[RES-018]` Premature Primitive check

1. **"Why not compose existing primitives?"** — The orchestration logic (coordinator submission + diagnostic parsing + wave traversal + baseline comparison + result aggregation) is non-trivial. Composing without an L3 owner forces every consumer to re-implement the same policy while risking a second build scheduler.

2. **"Is there a second consumer?"** — Three named consumers, one immediate (the CLI itself):

   | Consumer | Use of swift-impact library |
   |---|---|
   | `swift-impact` CLI (immediate) | The full Run API |
   | Future CI reusable workflow (Phase 1) | Same Run API; emit results to GitHub Actions step summary |
   | Future editor plugin / LSP integration | Watch-mode Run + structured Result stream |
   | Future release-readiness pre-tag gate | Run with `baseline = .git("main")`, gating on class A failures |

Hurdle cleared (just barely — three near-term consumers, one immediate).

### Q9 — Layer placement: L3

L3 fits because:

- Composes L1 (diagnostic-primitives, time-primitives, package-primitives) + L2 (spm-standard) + sibling L3s (package-graph, process, diagnostics, file-system).
- Does I/O (coordinator/git subprocesses and baseline working-tree transitions).
- Provides a library + executable in one package per Institute convention.

---

## Outcome

**Status: DECISION**

The implemented architecture is:

- **Products**: `Impact` (library), `swift-impact` (executable)
- **Build boundary**: every SwiftPM manifest, mirror, build, test, and timeout operation routes through `swift-build`
- **Public surface**: as sketched in Q6 (11 newly-defined types)
- **CLI**: coordinator-launched, with required upstream/workspace inputs and injected coordinator path
- **Visibility**: public from day 1 (`[CI-032]`)
- **CI**: thin caller `ci.yml` calling `swift-foundations/.github/.../swift-ci.yml@main`

## Documented temporary states (migration targets)

1. **`git stash` for baseline** → consider a worktree for cleaner semantics in a future revision; not blocking.

## Open questions

1. **Test discovery**: `--with-tests` runs the coordinator's test leaf per dependent. Some dependents have no test target. Behavior: skip silently (test target absent ≠ failure).

2. **Exit code semantics**: 0 if all class A failures are absent (i.e., the refactor didn't break anything new); non-zero otherwise. Class B/C/D do NOT contribute to exit code. Confirmed reasonable for git pre-push hooks and CI integration.

3. **JSON output schema versioning**: `--json` emits structured output. Schema version pinned at `1`; bump on breaking changes.

4. **Performance: full transitive sweep**: measure wall time under the coordinator's fixed machine-wide capacity budget; recommend depth 1 for the inner loop until measurements justify otherwise.

5. **Mirror verification at startup**: verification covers the upstream package required for this impact run. A future revision might validate every workspace manifest URL claim. Defer.

6. **Result persistence**: decide whether results need durable caching beyond the current JSON output.

## Changelog

- **1.1.0 (2026-07-22)** — Records the implemented single-scheduler decision: `swift-build impact` releases its self-build lock and slot before orchestration; swift-impact submits whole waves without owning capacity; manifest/mirror/build/test work and timeout cleanup are coordinator leaves.
- **1.0.0 (2026-05-14)** — Initial recommendation.

## References

### Verified primary sources

- `/Users/coen/Developer/swift-institute/Scripts/setup-mirrors.sh` — confirms the mirror substitution mechanism that swift-impact relies on.
- `/Users/coen/Developer/swift-institute/Scripts/swift-build` (2026-07-22) — canonical launcher, capacity owner, root locking, leaf deadlines, and process-group cleanup.
- `/Users/coen/Developer/swift-foundations/swift-package-graph/Sources/Package Graph/Package.Workspace.Configuration.swift` (2026-07-22) — existing executable-injection seam used for coordinator-owned manifest leaves.
- `/Users/coen/Developer/swift-foundations/swift-process/Sources/` (verified 2026-07-22) — `Process.Spawn.Configuration`, `Process.Stream`, and `Process.Status`; coordinator children use `timeout: nil`.
- `/Users/coen/Developer/swift-primitives/swift-diagnostic-primitives/Sources/` — `Diagnostic.Record` + `Diagnostic.Severity` confirmed.

### Internal cross-references

- `swift-institute/Research/downstream-impact-ci-for-swiftpm-ecosystems.md` v1.0.0 — grandparent arc.
- `swift-institute/Research/swift-package-domain-l1-l2-split.md` v1.0.0 — L1/L2/L3 layering.
- `swift-foundations/swift-package-graph/Research/design.md` v1.1.0 — direct substrate.
- `swift-institute/Skills/research-process/SKILL.md` — `[RES-018]`, `[RES-026]`.
- `swift-institute/Skills/code-surface/SKILL.md` — `[API-NAME-001]`, `[API-NAME-002]`, `[API-ERR-001]`.
- `swift-institute/.github/.github/workflows/lint-api-breakage.yml` — the A/B/C/D classification model swift-impact mirrors.

### Memory references

- `feedback_workspace_scope_l1_only.md` — current focus is L1 (swift-primitives); swift-impact's first dogfooding target is therefore swift-primitives' sequence-primitives refactor, but the design generalizes to all five layers and any sibling-package workspace.
- `feedback_no_inter_launch_soak.md` — pre-1.0 pacing.
