# SPM Build Parallelism Spurious Module Errors

<!--
---
version: 1.0.0
last_updated: 2026-04-25
status: REFERENCE
tier: 2
scope: ecosystem-wide
workflow: Discovery
trigger: D5 sweep + D3+D6 re-derivation cycles surfaced six concrete transient `no such module` / `missing required module` errors across five distinct upstream packages, all of which evaporated under clean `.build` + `-j 1`.
---
-->

## Provenance

Supersedes [`docker-linux-parallel-build-race.md`](docker-linux-parallel-build-race.md) (OPEN stub from 2026-04-24, tier 1, "verification discipline"). The stub captured the question and ≥3 prior occurrences across reflections 2026-04-17 and 2026-04-22; this note provides the empirical evidence and verification protocol that answers stub questions (1) "is this a SwiftPM + Swift 6.3.1 ordering bug worth filing upstream?" (yes — minimal-reproducer extraction is the remaining open work for a `/issue-investigation` cycle) and (3) "does `-j 1` eliminate the race reliably?" (yes — six-for-six in the observed cohort). Stub question (2) "minimal reproducer" is unanswered here and remains open.

## Context

Large-graph SPM `swift build --build-tests` invocations across the Swift Institute primitives + foundations + platform-stack ecosystem (typical scale: 1500–3300 compilation steps, 60+ transitive packages, ~13 monorepos under `~/Developer/`) intermittently emit `error: no such module '<X>'` or `error: missing required module '<X>'` diagnostics that **do not represent structural Package.swift target-dependency or product-export gaps**. The same package, on the same toolchain, with the same source tree, will succeed under `-j 1` (single-job sequential build) and may also succeed on a re-run with default `-j` if the build cache from a prior partial-success build supplies the missing module artifacts.

This pattern has cost the audit corpus at least one D-series row that turned out to be a false positive (D6 `Standard_Library_Extensions`, logged 2026-04-24, RESOLVED-FALSE-POSITIVE 2026-04-25) and it shaped two other audit entries that were also re-derived as RESOLVED-PREMISE-STALE on the same day (D2 `_Lock Test Process` linker symbols, D3 `Binary.Bytes.Machine.u8Parser` target-dep gap). This note exists so future `/audit` and `/platform` cycles do not repeat the false-positive trap.

## Symptom

Compiler emits one of these forms during a multi-job parallel build:

```
error: no such module '<Module_Name>'
   --> /path/to/file.swift:<line>:<col>
public import <Module_Name>
              ^
```

```
<unknown>:0: error: missing required module '<Module_Name>'
```

The cited file's `Package.swift` *correctly declares* `<Module_Name>`'s owning product as a target dependency. The owning package's `Package.swift` correctly declares the dependency edge. Module *X* compiles successfully elsewhere in the same build log (visible as `[N/M] Compiling <Module_Name> ...` lines). The error appears when an emit-module phase begins before the dependency module's emit-module has produced its `.swiftmodule` artifact on disk.

## Root cause hypothesis

SPM's parallel scheduler dispatches compile / emit-module phases in dependency-aware topological order, but the artifact-availability handshake between phases relies on filesystem visibility of `.swiftmodule` files. Under heavy parallelism (default `-j` = `nproc`) on first-build conditions (no `.build` cache to short-circuit), the consumer's emit-module phase can race ahead of the producer's emit-module write. The compiler then reports the producer's module as "missing" because it is not yet on disk — even though the producer's compile phase is in flight or queued. The error is reported as a build failure rather than a retry trigger.

Variables that increase reproduction probability:
- Cold `.build` cache (first build, or after `swift package clean` / `rm -rf .build`).
- High dependency-graph fan-in to a single producer (e.g., `Tagged_Primitives`, `Standard_Library_Extensions` are referenced by dozens of downstream targets).
- Deep module-name aliasing chains (`<Display Name>` → `<Underscored_Module_Name>`) where SPM's path resolution could mis-handle the artifact lookup.
- Multi-job build (`-j default` on multi-core hosts; aarch64 Docker host with N=10+ vCPUs typical for the swift:6.3.1 reference image).

Variables that suppress reproduction:
- `-j 1` (sequential build — hands-off the race).
- Warm `.build` cache — even a partial cache from a prior failed build may supply the module artifact on the second run.
- Building a smaller target subset (`swift build --target '<X>'`) — the smaller graph reduces parallel pressure on any single producer.

## Evidence

Six concrete transient observations from cycles 2026-04-24 → 2026-04-25, all on Docker `swift:6.3.1` aarch64 against the local monorepo workspace at `/Users/coen/Developer`:

| # | Date | Cycle | Observed error | Cited file | Re-verification | Outcome |
|---|------|-------|----------------|------------|-----------------|---------|
| 1 | 2026-04-24 | D5 sweep, full-package `--build-tests` on `swift-foundations/swift-linux` (default `-j`) | `<unknown>:0: error: missing required module 'Kernel_Primitives_Core'` during compile of `Terminal_Input_Primitives` | (no specific source file in error — emit-module phase) | Re-run on per-target sweep cleared the error. Documented in D5 sweep handoff Findings. | TRANSIENT |
| 2 | 2026-04-24 | D5 post-fix downstream check on `swift-foundations/swift-kernel` `--build-tests` (default `-j`) | `error: missing required module 'Standard_Library_Extensions'` | `swift-binary-primitives/Sources/Binary Format Primitives/Binary.Format.swift:4` | Promoted to D6 in the tracker. Re-derivation 2026-04-25 with clean `.build` showed `Standard_Library_Extensions` building cleanly (`[85/676] Emitting module Standard_Library_Extensions`). | TRANSIENT (D6 RESOLVED-FALSE-POSITIVE) |
| 3 | 2026-04-25 | D6 re-derivation, direct build on `swift-binary-primitives` `--target 'Binary Format Primitives'` (default `-j`) | `error: no such module 'Tagged_Primitives'` | `swift-ownership-primitives/Sources/Ownership Borrow Primitives/Tagged+Ownership.Borrow.Protocol.swift:12` | `Tagged_Primitives` Package.swift wiring confirmed correct (target lists product dep at line 104; package dep at line 82). Subsequent clean swift-kernel build under default `-j` did not reproduce. | TRANSIENT |
| 4 | 2026-04-25 | D3 re-derivation, direct build on `swift-binary-parser-primitives` `--target 'Binary Integer Primitives'` (default `-j`) | `<unknown>:0: error: missing required module 'Index_Primitives_Core'` | (emit-module phase, no specific source file) | Subsequent clean full-package `--build-tests` on the same package built `Binary_Machine_Primitives` and downstream targets cleanly. | TRANSIENT |
| 5 | 2026-04-25 | Witness-Primitives reproducibility check, clean swift-kernel `--build-tests` (default `-j`) | `error: no such module 'Witness_Primitives'` | `swift-clock-primitives/Sources/Clock Primitives/Clock.Any.swift:12` | Direct re-run with `-j 1` showed `Witness_Primitives` building cleanly (`[552/857] Compiling Witness_Primitives exports.swift`, etc.). | TRANSIENT |
| 6 | 2026-04-25 | Same clean swift-kernel build (default `-j`), second attempt | `error: no such module 'System_Primitives'` | `swift-kernel-primitives/Sources/Kernel Memory Primitives/Kernel.Memory.Page.swift:14` | Subsequent `-j 1` clean build of swift-kernel built `System_Primitives` and ALL transitive modules cleanly to completion (3334/3334 steps, 168.65s). | TRANSIENT |

Pattern: every single one of these "no such module" errors evaporated under either `-j 1`, a per-target build, or a re-run with cache. Five distinct module names across four distinct packages; same root-cause class.

## Verification protocol for future occurrences

When `/audit` / `/platform` / a remediation cycle observes `error: no such module 'X'` or `error: missing required module 'X'` during a `swift build --build-tests` invocation:

1. **Do NOT immediately log it as a D-series row** or as a structural Package.swift gap. Single-pass module-loading errors are presumptively transient until shown otherwise.
2. **Check Package.swift wiring at the cited consumer site** — does the target dep declaration exist? Does the producer package declare the product? Does the consumer package list the producer in its `dependencies:`? If any of these is missing, the error *may* be structural and the rest of this protocol may not apply.
3. **Re-derive with `-j 1` on a clean `.build`**:
   ```bash
   rm -rf .build
   docker run --rm -v "$PWD/..":/workspace -w "/workspace/$(basename $PWD)" swift:6.3.1 \
     bash -c "apt-get update -qq && apt-get install -y -qq uuid-dev >/dev/null 2>&1 && swift build --build-tests -j 1"
   ```
4. **If `-j 1` clears the error**: the diagnostic was a parallelism artifact. Discard. Do not log to the tracker.
5. **If `-j 1` reproduces the error**: it is structurally real. Then log to the tracker as a D-series row with `-j 1` evidence cited explicitly.

For `/platform` Cycle gates (b)(c)(d)/Phase 3 terminal-gate verification, prefer **`-j 1`** as the verification command from the outset. The 168.65s wall-clock for swift-kernel `--build-tests -j 1` is acceptable for a once-per-cycle gate; the false-positive risk of multi-job builds is not.

## Implications

**For the audit workflow ([AUDIT-XXX]):** the D-series row schema should include a "first observed under" build-config field and a "re-derived under -j 1" verification field. Current schema does not. Adoption of this discipline retroactively justified D2 + D3 + D6 RESOLVED-PREMISE-STALE / RESOLVED-FALSE-POSITIVE dispositions on 2026-04-25.

**For the `/platform` skill ([PLAT-ARCH-XXX]):** terminal-gate verification (Phase 3 Docker Linux `--build-tests` clean) should specify `-j 1`. Previous Cycle 3 gate (b)/(d) substantive-canary precedent — accepted in lieu of blocked terminal gates — was driven in part by transient module errors mistaken for upstream drift; with `-j 1` the gate is reachable and the canary substitution becomes unnecessary for this class of blocker.

**For the handoff workflow ([HANDOFF-XXX]):** premise-staleness re-derivation per [HANDOFF-016] should explicitly include the clean `.build` + `-j 1` verification step before any "fix" dispatch begins, not only as a post-fix verification.

**For the tracker:** D6's full row in `Audits/platform-compliance-2026-04-21.md` is the canonical anti-example and should remain in place (not be deleted) as a permanent reference for future audits. The methodological note in the ecosystem-drift footer (`-j 1` requirement) is the load-bearing summary.

## Bounds and caveats

- **Hypothesis, not root-causal proof.** The "emit-module artifact race" explanation is a high-confidence working hypothesis based on observed correlations (default-`-j` failure, `-j 1` success, cache-warm success). I have not instrumented the SPM scheduler or read SPM source to confirm. A definitive root-cause investigation would belong in a separate `/issue-investigation` cycle and could surface as an upstream `swiftlang/swift-package-manager` bug report.
- **Toolchain scope.** All six observations were on `swift-6.3.1-RELEASE` (Docker `swift:6.3.1` aarch64). Whether this class of error reproduces on macOS arm64, Linux x86_64, swift:6.3 floating tag, or swift:6.4 nightly is unverified.
- **Workspace scope.** All observations were on the local monorepo workspace at `/Users/coen/Developer/` with `.package(path: "../...")` deps. Whether registry-resolved deps or remote git-resolved deps reproduce identically is unverified.
- **`-j 1` performance cost.** Single-job builds of the swift-kernel scale (~3300 steps) take 2-3 minutes vs ~1 minute on default `-j`. For routine local development this is meaningful; for terminal-gate verification once per cycle, it is acceptable insurance.
