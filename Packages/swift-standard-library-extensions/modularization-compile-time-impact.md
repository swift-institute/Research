# Modularization Compile-Time Impact

<!--
---
version: 1.2.0
last_updated: 2026-04-22
status: RECOMMENDATION
tier: 2
scope: package
-->

## Changelog

- 1.3.0 (2026-04-22): Applied @inlinable sweep (49 additions / 19 files). Reverted speculative String.Case.Insensitive → String.CaseInsensitive rename after it was identified as an [API-NAME-002] violation. Final endpoint: N=1 clean debug 1.37 s median, N=77 clean debug 3.88 s median, ratio 2.83× (mid-band). StringProtocol folded into String target pending format-subsystem extraction to swift-format-primitives — flagged as out-of-place content, not a blocker.
- 1.2.0 (2026-04-22): Initial self-containment refactor (Bool.swift, Array.Builder.swift split, formatted-scope experiment). Strict N=78 builds but ratio 4.13× at upper edge — see @inlinable sweep in 1.3.0 for the follow-up.
- 1.1.0 (2026-04-22): MVP experiment run. Baseline N=1 measured. N=max blocked by four source-level coupling classes, decisively including leaf-to-leaf extension-method dependencies.
- 1.0.0 (2026-04-22): Initial scoping with experiment handoff.

## Context

`swift-standard-library-extensions` currently ships a single SwiftPM target containing 87 source files. Each source file extends exactly one Swift standard-library type or free-function surface (see *Current Shape*, below). The package question under active design is whether to decompose into fine-grained per-type targets — approximately 83 targets, one per extended stdlib type after correcting source-level [API-IMPL-005] violations — with an umbrella target re-exporting the set.

The principled argument for per-type modularization was accepted prior to this research (per [MOD-DOMAIN], each extended stdlib type is its own semantic domain; clustering by taxonomic similarity was considered and rejected as non-structural). The argument against it is that the ecosystem has no precedent for a package with ≈83 targets, so the cost curve of fixed per-target overhead versus the parallelism and incremental-locality benefits is unmeasured at this scale.

This document scopes the research question, enumerates options, surveys theoretical bounds and ecosystem precedent, and hands off to `experiment-process` for empirical measurement.

### Current Shape

| Measurement | Value | Source |
|---|---|---|
| `.swift` source files in `Sources/Standard Library Extensions/` | 87 | `find Sources -name "*.swift" \| wc -l`, 2026-04-22 |
| Files declaring `@inlinable` at least once | 21 (24%) | `grep -l @inlinable`, 2026-04-22 |
| Targets in `Package.swift` | 1 (+ 1 testTarget in nested package) | `Package.swift:20-32`, 2026-04-22 |
| Multi-type-per-file violations of [API-IMPL-005] observed | ≥ 1 (`Array.Builder.swift` defines three `.Builder` types) | `Sources/.../Array.Builder.swift:14-176`, 2026-04-22 |

### Triggering Discussion

Investigation triggered by a design question of category "Architecture choice" per [RES-001]. The question was not answered by conventions alone: `modularization` skill [MOD-003] prescribes variant decomposition but does not specify how far to carry it when variants are near-totally independent; [MOD-007] bounds depth ≤ 3 but sets no breadth cap; [MOD-008] offers split-decision criteria that each leaf passes but does not quantify the fixed-overhead tax.

## Question

**Primary**: For a package structured as disjoint per-type Swift standard-library extensions, what is the compile-time cost of fine-grained (N ≈ 83) modularization relative to single-target (N = 1), across clean-build, incremental-build, and consumer-side scenarios? At what N does fixed per-target overhead offset parallelism and incremental-locality gains?

**Secondary**: How much of the cross-target cost is recoverable by `@inlinable` annotations, and what fraction of the current extensions need it to close the performance gap?

**Out of scope**: source-level cleanup of `[API-IMPL-005]` violations (done as a prerequisite, not a variable); decisions about the umbrella target's deprecation trajectory (addressed separately after the data returns).

## Analysis

### Options

| Option | N | Rationale | Principal concern |
|---|---|---|---|
| A. Single target (baseline) | 1 | Zero modularization overhead; current state | Consumer-side bloat: 87 files compiled to use 1 type's extensions (contradicts [MOD-015]) |
| B. Arbitrary clustering | ~23 | Halves the target count vs. C | Rejected pre-research: clusters are taxonomic, not structural, and fail [MOD-DOMAIN]. Retained here only as an experimental *control* to separate "N matters" from "cluster-design matters" |
| C. Strict per-type | ~83 | Matches each extended stdlib type as its own domain; only structural deps (e.g., `ArraySlice.Builder`→`Array.Builder` delegation) form inter-target edges | Untested at this breadth in ecosystem |
| D. Strict per-type + compat umbrella | ~84 | C plus umbrella re-export | Umbrella preserves the anti-pattern documented in `feedback_no_umbrella_imports.md`; requires explicit mitigation |

**Decomposition type per [MOD-015]**: primary. Each variant (extensions to one type) is independently useful; Core is empty — there is no shared code, not even namespace declarations (stdlib types already own their namespace). Consumer import rule: narrow-variant per [MOD-015], not umbrella.

### Evaluation Criteria

| Criterion | Why it matters | Units |
|---|---|---|
| Clean-build wall time | CI cost, first-time developer cost | seconds |
| Incremental-build wall time (single-file edit) | Day-to-day development cost | seconds |
| Consumer clean-build wall time for `only-Array` consumer | [MOD-015] payoff proxy | seconds |
| Consumer clean-build wall time for umbrella consumer | Worst-case narrow-import loss | seconds |
| Binary size (release) | Code-size impact of @inlinable footprint | bytes |
| Frontend CPU-seconds | Compiler work independent of parallelism | seconds |
| Driver invocation count | Approximation of fixed per-target overhead | count |
| @inlinable annotation count required for parity | Ongoing maintenance cost of C | count |

### Theoretical Grounding

#### Parallelism Bound (Brent's Theorem)

For a DAG of compilation work with total work *W*, critical-path span *S*, and *P* processors, total time *T_p* satisfies

```
T_p ≥ max(W / P, S)
```

For this package under option C, inter-target dependencies follow only real delegation (e.g., `ArraySlice.Builder`→`Array.Builder`); the graph's longest chain is *S* = 2 (possibly 1 for all targets without delegating Builders). With *W* ≈ total file-level compile work held constant across N and *S* ≈ 1–2, the bound is *W* / *P* — i.e., perfect parallelism up to core count. Modularization enables this; a single target serializes *W*. This is the upper-bound case for modularization's parallelism benefit. Reference: Brent, R. P. (1974). "The parallel evaluation of general arithmetic expressions." *J. ACM* 21(2).

#### Amortized Overhead (Amdahl's Law)

Each target carries a fixed overhead *k*: driver invocation, Swift module emission, linker contribution, indexing manifest. Total time observed is approximately

```
T_p ≈ W / P + N · k / P + sequential_tail
```

where *sequential_tail* is the umbrella target's re-export pass plus final link. As *N* grows, *N · k* grows linearly while *W* / *P* stays constant. The break-even point, where modularization stops helping clean builds, is roughly when *N · k* ≈ *W*. The experiment's job is to locate this point empirically. Reference: Amdahl, G. (1967). "Validity of the single processor approach to achieving large scale computing capabilities." *AFIPS Spring Joint Computer Conference*.

#### Whole-Module Optimization Boundary

Swift's optimizer operates within module scope by default. Within a module, the compiler can inline freely, specialize generics across files, and eliminate dead code jointly. Across modules, only symbols marked `@inlinable` (serialized SIL into the `.swiftmodule`) can be inlined or specialized at the call site; opaque symbols are compiled to a concrete entry point and called through the module boundary.

For extensions like `Array.removing(at:)` — generic over `Element`, non-`@inlinable` today — a cross-module call forces the concrete entry point (generic over `Element`) rather than a specialized instance for the caller's `Element`. This converts potential inlined code into a function call + generic indirection per invocation. For trivial leaf methods in hot loops this is measurable; for one-shot use it is not. Reference: SE-0193 "Cross-module inlining and specialization."

The 24% current `@inlinable` coverage (21/87 files) suggests that **option C implicitly requires a decision** about whether to `@inlinable`-annotate most surfaces (preserving current codegen) or accept de-specialization (documenting it as a known option-C cost). The experiment must measure both states.

#### Incremental Build Locality

SwiftPM tracks dependencies at the target granularity. Under option A, touching any file in `Standard Library Extensions` invalidates the entire module (87-file rebuild). Under option C, touching `Array.swift` invalidates only `Standard Library Array Extensions` (a 1-file rebuild) and — transitively — the umbrella re-export and any dependent targets. Where (A) is *O*(87) per edit, (C) is *O*(1) + umbrella overhead. This is the single largest day-to-day cost asymmetry and is the strongest a-priori argument for C.

### Ecosystem Precedent

The modularization skill cites three reference packages. Measurements from their `Package.swift` manifests (2026-04-22):

| Package | Package.swift lines | `name:` occurrences | Skill-claimed target count | Delta to option C (~83) |
|---|---|---|---|---|
| `swift-parser-primitives` | 633 | 106 | 34 (per MOD-006) | C is 2.4× broader |
| `swift-buffer-primitives` | 430 | 111 | variant-per-storage-strategy | — |
| `swift-memory-primitives` | 191 | 48 | flat star, 3–4 targets | C is ≈20× broader |

Observations:
- Parser at N=34 is the current ecosystem-wide upper bound on target count in a primitives package. Option C at ~83 would more than double the largest precedent.
- Parser achieves 1.2 mean sibling deps per target ([MOD-006] benchmark). This package under C would achieve ≈0–0.1 mean sibling deps (only Builder-delegation edges). It would set a new ecosystem minimum for intra-package coupling.
- Neither parser nor buffer has a variant graph this flat. Flatness favors modularization (Brent's bound, above) but amplifies per-target overhead because there's no single long-running target masking the fixed-cost tail.

### Prior Art Survey (External)

- **SE-0193 Cross-module inlining and specialization.** Establishes the `@inlinable` attribute and its resilience semantics. Cited above. [Proposal](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0193-cross-module-inlining-and-specialization.md).
- **Rust crate granularity debate**. The Rust ecosystem has a running discussion over "thin crates" vs. "fat crates" with analogous trade-offs (parallelism + incrementality on one side, fixed per-crate overhead + `rustc` startup on the other). Empirical reports on large workspaces (e.g., rust-analyzer, 200+ crates) note measurable fixed overhead dominant on clean builds but negligible on incremental. Not directly transferable (Rust's incremental model differs from Swift's), but directionally corroborating.
- **Bazel build-graph scaling research**. Demonstrates empirically that in well-parallelized build graphs, per-action fixed overhead dominates once total work drops below a threshold proportional to the action count. The threshold is toolchain-specific and must be measured locally, not imported.
- **SwiftPM --print-manifest-graph** (experimental) and frontend stats infrastructure (`-Xfrontend -print-stats`, `-Xfrontend -stats-output-dir`) are the available instrumentation. No ecosystem-wide benchmark corpus exists; this research would be the first measurement at this N.

### Toolchain Measurement Surface

The following instrumentation is available in Swift 6.3.1 and will be used by the experiment:

| Tool | Flag | Output | Use |
|---|---|---|---|
| Driver timing | `swift build -v` | stdout command log + timing | Per-target invocation wall time |
| Frontend stats (text) | `-Xfrontend -print-stats` | stdout | Per-invocation phase breakdown (parse, typecheck, SILgen, IRgen) |
| Frontend stats (JSON) | `-Xfrontend -stats-output-dir <dir>` | one JSON per frontend invocation | Aggregatable across targets |
| Driver compilation timing | `-driver-time-compilation` | stdout | End-to-end driver wall time |
| Build graph | `swift package describe --type json` | JSON | Target count, dependency edges |
| Binary size | `stat -f %z .build/release/**/*` | bytes | Codegen size under different @inlinable regimes |

All measurements are to be median-of-5 with `rm -rf .build` between clean-build samples. Background load, thermals, and toolchain version must be controlled or recorded.

### Constraints

| Constraint | Note |
|---|---|
| Swift toolchain | 6.3.1 (per `feedback_toolchain_versions`); 6.4-dev nightly acceptable as secondary data point |
| Machine | Single Mac, core count & CPU model to be recorded in experiment metadata |
| Noise floor | Median-of-5 at minimum; outliers flagged; background load noted |
| Source drift | Source tree must be identical across N levels — only `Package.swift` and `Sources/` *directory partitioning* changes |
| File-level cleanup prerequisite | `Array.Builder.swift` and any other multi-type files must be split per [API-IMPL-005] *before* Option C is materialized, or the partition is ill-defined |

## Outcome

**Status**: RECOMMENDATION — primary hypothesis measured (4.13× clean-debug-build cost at strict N=78), decision pending secondary scenarios (incremental, release, consumer-side).

### Endpoint Measurement (after self-containment refactor, 2026-04-22)

| N | Partition | Median wall | Min | Max | Samples |
|---|---|---|---|---|---|
| 1 | single target (baseline) | 1.41 s | 1.37 | 3.30 | 5 |
| 78 | strict per extended type, no Core, zero intra-deps | 5.82 s | 4.91 | 6.33 | 5 |

Ratio: **4.13×**. Research-doc prediction was 1.5–4× slower debug clean; observed is at the upper edge.

The refactor (see below) eliminated all cross-file references enumerated in the earlier blocker analysis. Strict modularization is now achievable without a Core target and without inter-variant dependencies. The generated `Package.swift` contains exactly one `dependencies:` edge (the umbrella). Canonical package: 561/561 tests pass; build time unchanged (1.14 s clean debug).

### Refactoring Applied

| Change | Scope | Rationale |
|---|---|---|
| `Bool.swift`: `.init(self)` → `self ? 1 : 0` | Internal (no API change) | Removes Bool→Int extension-method cross-ref |
| `Array.Builder.swift` split into three files; delegation inlined | Internal ([API-IMPL-005] improvement) | Three Builders no longer share a file; each is self-contained |
| `formatted(as: String.Case)` moved from `StringProtocol.swift` to `String.swift` | Minor API change — `Substring.formatted(as:)` removed | `String.Case` is declared in `String.swift`; co-locating the method eliminates the cross-file ref. Substring users fall back to `String(substring).formatted(as:)` or stdlib `.uppercased()` |

These changes stand as a standalone improvement independent of modularization: they enforce the self-containment principle (every extension file expresses its API in stdlib terms alone). If modularization is not adopted, the refactor still has value.

### Experiment Outcome (MVP run 2026-04-22) — original blocker analysis (archived for context)

The experiment's MVP measured N=1 debug/clean cleanly (median 1.20s, 5 samples) and attempted N=max (76 targets = 12 type-declaring files in Core + 75 per-file targets depending on Core). N=max did not build, producing a progression of four source-level error classes:

| Class | Error | Nature | Remediation |
|---|---|---|---|
| 1 | Nested extension types not visible across module boundary (`String.Case` unreachable from sibling target) | Swift's per-file extension-member visibility rule | Prepend `public import Core` to every consuming file (mechanical but mutates source) |
| 2 | `internal` members of Core inaccessible from sibling targets (`String.Case.transform`) | Default access level is `internal`; needs cross-target reach | Promote relevant members to `package` (Swift 5.9+) — **narrower than `public`, preserves API surface** |
| 3 | Package-owned `Result` shadows stdlib `Swift.Result`; unqualified references ambiguous across modules | Name collision surfaces only at module boundary | Module-qualify references (`Standard_Library_Extensions_Core.Result.Builder`) or rename |
| 4 | Sibling-target extension methods not visible (`Bool.int` uses `Int.init(Bool)` declared in another would-be sibling target) | Cross-file extension-method dependency graph is dense | Requires full dep inference: sibling-target `.dependencies` in Package.swift plus `public import` in every consuming file |

Classes 1–3 are bounded and mechanically remediable once inventoried. **Class 4 is the decisive finding**: the package's 87 files have an entangled graph of extension-method uses that doesn't collapse into a clean Core + variants shape. Solving Class 4 requires either source-level untangling (move shared methods into Core or restructure into a smaller number of coherent families) or a SwiftSyntax-based dep-inference tool. Either is a non-trivial author-time investment that must precede any meaningful compile-time measurement.

See `Experiments/modularization-compile-time/Outputs/report.md` for the full diagnostic.

### Refactoring Prerequisites

Before re-running this experiment with measurable outcomes:

1. **Cross-file reference inventory** — static analysis of every `X.Y` or sibling-method call where `Y` or the method is declared in a different file. The output is the minimum inter-target dependency graph and the list of files needing added imports.
2. **Access-level audit** — catalog every cross-file use of implicit `internal`. Promote to `package` (not `public` unless API-bound). The `package` preference is load-bearing: it expresses implementation-internal-to-the-SwiftPM-package without expanding downstream API surface, and matches the user's stated default.
3. **Shadow-type policy** — decide whether `Result` (and any other package-owned types shadowing stdlib) stay shadowed or get renamed to avoid cross-module ambiguity.

With 1–3 done, the experiment harness is ready to run without changes: regenerate variant-max, run the full matrix.

### Open Questions Returning to Design

These were implicit in the original research scope; the experiment surfaces them as explicit decisions:

- **Is modularization worth the refactoring cost?** Author-time refactoring + ongoing maintenance of the dep graph must be weighed against the anticipated consumer-side compile-time benefit. The benefit is only confirmed by running consumer-side scenarios (deferred in the MVP), which themselves require the refactoring to proceed.
- **Is the leaf-to-leaf coupling a signal to restructure the source, not just the targets?** Example: Bool→Int dep is one edge; if there are dozens, the "flat extensions" design may itself be the issue. A smaller number of coherent units (e.g., Numeric family, Collection family) might carry fewer cross-file edges and modularize better — but requires revisiting decomposition principles.
- **Retained hypotheses** (still to be tested once unblocked):
  - Clean build, debug: N=max 1.5–4× slower than N=1.
  - Incremental build: N=max ≥ 10× faster than N=1.
  - Consumer-only-type builds: materially faster under N=max.
  - `@inlinable` parity cost: likely favors selective annotation, not blanket.

## Experiment Handoff

### Scope

Produce empirical data on `swift build` wall time, CPU time, driver invocations, and binary size under varying modularization granularities of `swift-standard-library-extensions`, controlling for source content.

### Location

`/Users/coen/Developer/swift-primitives/swift-standard-library-extensions/Experiments/modularization-compile-time/`

Mirrors the layout of the existing `typed-throws-overload-resolution` experiment in the same directory.

### Variables

**Independent**:

| Variable | Levels | Notes |
|---|---|---|
| N (target count) | {1, 10, 40, 83} | 1 = baseline (current). 10 = arbitrary alphabetical partition (control for "N matters, cluster-design doesn't"). 40 = midpoint. 83 = strict per-type (Option C). |
| @inlinable regime | {as-is, fully-annotated} | Measured only at N=83, since @inlinable is a no-op at N=1 |
| Build mode | {debug, release} | |
| Scenario | {clean, incremental, consumer-only-Array, consumer-four-types, consumer-umbrella} | |

**Controlled**:

| Variable | Value |
|---|---|
| Source file contents | Identical across N (only Package.swift and directory layout change) |
| Swift toolchain | 6.3.1 |
| Machine | [record in experiment metadata] |
| Warm-caches protocol | `rm -rf .build` between samples for clean-build; controlled touch for incremental |

### Samples

5 samples per (N, regime, mode, scenario) cell, median reported, min/max noted. 5 × 4 × 2 × 2 × 5 = 400 measurements (some cells collapse — e.g., incremental doesn't vary with consumer shape), call it ~200 effective cells.

### Metrics (per sample)

| Metric | Source |
|---|---|
| Wall-clock build time | `/usr/bin/time swift build` |
| User CPU-seconds | `/usr/bin/time` |
| Driver invocations | `swift build -v \| grep -c <frontend pattern>` |
| Per-frontend stats | `-Xfrontend -stats-output-dir` aggregated |
| Binary size (release only) | `stat` on `.build/release/*.o` and final library |

### Mechanics

The experiment harness generates the N=10, N=40, N=83 partitions **mechanically** from a partition descriptor file (e.g., `partition-83.txt` listing `Array → target "Standard Library Array Extensions"`, etc.). It rewrites `Package.swift` and symlinks/copies sources into per-target `Sources/<target>/` directories. No hand-edits per partition; all partitions derive from the same master source tree.

The consumer scenarios are separate SwiftPM packages under `Experiments/modularization-compile-time/consumers/`, each importing the experiment's build output.

### Out-of-Scope for the Experiment

- Choice of `@inlinable` on a per-method basis. Experiment tests "all" vs "as-is"; the granular question is downstream.
- Non-clean-build cache-warmed scenarios beyond single-file incremental.
- Release-mode link-time optimization (LTO) — test under default settings.
- Non-Mac platforms. Linux / CI-runner measurement is follow-on.

### Deliverables

The experiment produces:

1. `Experiments/modularization-compile-time/README.md` — methodology, how to re-run.
2. `Experiments/modularization-compile-time/results.json` — raw per-sample data.
3. `Experiments/modularization-compile-time/report.md` — summary tables, plots (if markdown-embeddable), answers to the 6 provisional expectations above.
4. Update to this research document: status IN_PROGRESS → DECISION, referencing `report.md`.

## References

- [Brent, R. P. (1974). "The parallel evaluation of general arithmetic expressions." *Journal of the ACM* 21(2): 201–206.](https://dl.acm.org/doi/10.1145/321812.321815)
- [Amdahl, G. M. (1967). "Validity of the single processor approach to achieving large scale computing capabilities." *AFIPS Spring Joint Computer Conference*.](https://dl.acm.org/doi/10.1145/1465482.1465560)
- [SE-0193: Cross-module inlining and specialization.](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0193-cross-module-inlining-and-specialization.md)
- `modularization` skill: `/Users/coen/Developer/.claude/skills/modularization/SKILL.md` — [MOD-DOMAIN], [MOD-003], [MOD-006], [MOD-007], [MOD-008], [MOD-015].
- `feedback_no_umbrella_imports` (user memory) — consumer-side narrow-import preference.
- `feedback_fine_grained_modularization` (user memory) — one-target-per-type-family default.
- Existing package state: `Package.swift:1-54`, `Sources/Standard Library Extensions/*.swift` (87 files), 2026-04-22.
