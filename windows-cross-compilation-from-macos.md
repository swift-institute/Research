# macOS → Windows Cross-Compilation for Gated Swift: Feasibility Spike

**Status**: FINDING — NO-GO (high confidence)
**Date**: 2026-07-03
**Scope**: Local compile/type-check feedback on `#if os(Windows)` / `import WinSDK` code from a macOS host, targeting `swift-windows-standard` (L2 Win32 spec, namespace `Windows.\`32\`.Kernel`; on-disk `swift-microsoft/swift-windows-standard`, internal package name `swift-windows-32`)
**Drives**: The stack-quality remediation approach for Windows-gated packages — specifically whether the "compile errors are invisible until a ~20-min Windows CI round" pathology can be collapsed locally
**Extends** (cite-and-extend per [HANDOFF-013]): `wasm-ci-strategy-and-sdk-toolchain-coupling.md` v1.0.0 (SDK distribution model + SDK↔toolchain ABI patch-coupling); context from `windows-l2-l3-namespace-separation.md`
**Provenance**: This spike (2026-07-03); local prior art `swift-microsoft/swift-windows-standard/HANDOFF-windows-target-evergreen.md` (rounds 1–15 of CI-only error discovery)

<!--
---
version: 1.0.0
last_updated: 2026-07-03
status: FINDING
tier: 1
scope: ecosystem-wide
normative: false
applies_to:
  - swift-standards
  - swift-microsoft
  - swift-institute
---
-->

## Changelog

- **v1.0.0 (2026-07-03)**: Initial empirical feasibility spike. Verdict NO-GO for local type-check feedback on Windows-gated code from macOS. Wall proven by direct `swiftc` output on Swift 6.3.3 (swiftlang-6.3.3.1.3). Establishes the two stacked walls, the parse-vs-typecheck ceiling, the DIY-SDK effort estimate, and the build-only-CI-lane recommendation.

## 1. Question

`swift-windows-standard` is a 249-file L2 Win32 spec package. Its real code is entirely `#if os(Windows)`-gated and uses `import WinSDK` (87 files) plus a C shim (`CWindowsMemoryShim`) that `#include <windows.h>`/`<psapi.h>`. **None of it type-checks on macOS** because `os(Windows)` is false and the gated branch is compiled as empty. The `HANDOFF-windows-target-evergreen.md` records the cost: rounds 1–15 of compile-error discovery, one class per ~20-min Windows CI round (bare-type-refs, `@inlinable`-vs-`internal import`, package-type-in-public-signature). Constraint line 60: *"Windows-gated code is latent on macOS/Ubuntu -> validate via CI only."*

**Can macOS→Windows cross-compilation give local compile-error feedback that today only Windows CI provides?** Graduated bar: full win = `swift build --swift-sdk`; big win = `-typecheck` of the gated Swift; partial = works for a toy but not the real package; no-go = a hard wall.

## 2. Verdict

**NO-GO (high confidence)** for local type-check feedback on Windows-gated code from this macOS host. There is no turnkey path, and the only technically-open path (hand-assembling a Windows Swift SDK) is a multi-day, unsupported, licensing-encumbered build that this spike deliberately did not pursue (RELAY triggers: licensed MS artifact + >1 GB download + principal-only decision).

Two walls, stacked. The second is never even reached locally because the first stops a bare `let x = 1`.

## 3. Empirical state (verified 2026-07-03, Swift 6.3.3 / swiftlang-6.3.3.1.3, arm64-apple-macosx26.0)

| Fact | Command / source | Result |
|------|------------------|--------|
| No Windows Swift SDK installed; `swift sdk` is the current CLI | `swift sdk list` | Only `swift-6.3.2-RELEASE_wasm`, `swift-6.3.2-RELEASE_wasm-embedded`. No Windows. |
| macOS toolchain ships stdlibs for Apple platforms only | `ls <toolchain>/usr/lib/swift/` | `macosx, iphoneos, appletvos, watchos, xros, maccatalyst`, simulators — **no `windows`** |
| No WinSDK/ucrt/visualc modulemaps in the toolchain | `find <toolchain> -iname '*winsdk*' -o -iname 'ucrt.modulemap' -o -iname 'visualc.modulemap'` | (empty) |
| **Wall #1** — no Windows Swift stdlib | `swiftc -target x86_64-unknown-windows-msvc -typecheck empty.swift` (`empty.swift` = `let x = 1`) | `error: unable to load standard library for target 'x86_64-unknown-windows-msvc'` |
| Same wall hits the toy `import WinSDK` file | `swiftc -target x86_64-unknown-windows-msvc -typecheck toy.swift` | Same stdlib error — **fails before reaching `import WinSDK`** |
| Gated code is invisible under the default target | `swiftc -typecheck toy.swift` (macOS target) | exit 0, empty — `os(Windows)` false, gated branch compiled away (this IS the pathology) |
| `-parse` (syntax only) DOES work cross-target without a stdlib | `swiftc -target x86_64-unknown-windows-msvc -parse toy.swift` | exit 0 — but see §4 |
| `swift-sdk-generator` targets Linux/FreeBSD only | github.com/swiftlang/swift-sdk-generator | Host: macOS/Linux/FreeBSD. Target: **Linux/FreeBSD only. Windows unsupported, no roadmap.** |
| No official Windows Swift SDK bundle | swift.org/install/windows | Native Windows + Visual Studio 2022 only. No cross bundle, no `swift sdk install` flow. |
| Windows Workgroup (Jan 2026) charter | swift.org/blog/announcing-windows-workgroup | No cross-compilation-from-non-Windows priority. |
| Newest Windows SDK work is Windows-native | forums.swift.org/t/81313 "Upcoming changes to Windows Swift SDKs" (Jul–Aug 2025) | `WindowsExperimental.sdk` + static runtime; setup via `SDKROOT` env var. No cross-from-macOS story. |
| Community Windows snapshots are Windows-host only | github.com/readdle/swift-windows-gha | Requires Windows 10 + VS 2022 + Windows SDK. Not a cross SDK. |
| Authoritative blocker statement | compnerd (Saleem Abdulrasool, Swift Windows port owner), forums.swift.org/t/54485 | *"It is possible, though there are questions about the legal aspects (is copying the SDK permitted?). Without the Microsoft SDK content, it is not possible."* Recommends the inverse (build on Windows/CI). |
| Only documented macOS→Windows procedure | github.com/apple/swift `docs/WindowsCrossCompile.md` | Builds the compiler/runtime itself; ancient (VS 2017, Win10 SDK 10.10.586); needs licensed VS/Windows SDK + hand-deployed `ucrt.modulemap`/`visualc.modulemap` + from-source Swift build + `lld-link`. |

## 4. Why even the "big win / parse" fallback fails

`-parse` is the only thing that runs cross-target without a Windows SDK (verified: exit 0). It is **worthless for this loop**: the error classes that cost the 4 CI rounds are all *semantic / type-resolution* errors (bare-type-refs, `@inlinable` referencing an `internal import`, a `package` type in a `public` signature), not syntax errors. `-parse` does not resolve imports or types, so it catches none of them. Catching them requires `-typecheck`, which requires:

1. the Windows Swift stdlib for `x86_64-unknown-windows-msvc` (Wall #1 — absent), **and then**
2. the `WinSDK` clang overlay module + Windows SDK (ucrt/um/shared) + MSVC (vcruntime) headers + the winsdk/ucrt/visualc modulemaps to resolve the 87 `import WinSDK` sites and the `CWindowsMemoryShim` `#include <windows.h>` (Wall #2 — licensed MS artifacts, never reached locally).

Corollary: `os(Windows)` is bound to the target triple and cannot be forced on with `-D`. The gated branch is fundamentally invisible unless you target Windows — which requires the stdlib. There is no local shortcut.

## 5. The only technically-open path (DIY Windows Swift SDK) — and why it is out of scope here

To assemble a Windows Swift SDK artifactbundle on macOS — doing by hand what `swift-sdk-generator` refuses to do for Windows:

1. **Windows Swift stdlib/runtime + Swift-side modulemaps** (winsdk/ucrt/visualc): extract from an official Windows Swift toolchain download (~hundreds of MB).
2. **MS CRT + Windows SDK headers/libs**: run `xwin` on macOS (~1 GB; downloads Microsoft content under the Visual Studio license — *exactly* the redistribution question compnerd flagged as legally uncertain). `xwin` also fixes case-sensitivity issues so `#include <windows.h>` resolves on a case-sensitive FS, and its output feeds `clang-cl` via `-winsdkdir`/`-vctoolsdir`.
3. **`swift-sdk.json` artifactbundle**: stitch (1)+(2) with target triple, `-sdk`, `-resource-dir`, `-I`, and modulemap overlays.
4. `swift sdk install` it, then `swift build --swift-sdk <id>`.

**Effort & fragility**: multi-day one-time build; brittle per-toolchain-patch maintenance (cf. the Wasm SDK↔toolchain ABI patch-coupling already documented in `wasm-ci-strategy-and-sdk-toolchain-coupling.md` — a 6.3.0 SDK will not import into a 6.3.1 compiler; the same coupling applies here and is worse because nobody publishes the bundle); legal review required for step 2; delivers `-typecheck` only (no link/run); and drifts from the actual Windows CI environment. Per the spike's RELAY triggers this was not pursued — a clean NO-GO with the wall proven is the complete answer.

## 6. Recommendation: pivot to a build-only Windows CI lane

| Axis | DIY cross-SDK on macOS | Build-only Windows CI lane |
|------|------------------------|----------------------------|
| One-time setup | multi-day, unsupported, legal review | a few lines in `swift-ci.yml` |
| Per-use | fragile, breaks on toolchain bumps | zero maintenance |
| Feedback | `-typecheck` only, may drift from CI | real Windows env, no drift |
| Latency | on-laptop (offline) | ~5 min (compile-only) vs ~20 min (full test round) |
| Catches the 4 error classes? | yes (if it ever works) | yes |

The pathology in the HANDOFF is **compile** errors discovered one-per-round. A **compile-only** job (`swift build`, no `swift test`) on the existing Windows runner surfaces exactly those errors in ~5 min, needs zero local machinery, and runs in the real environment. Split the existing Windows job into a fast compile-gate that runs first + the full test job behind it, so every push gets one fast compile round instead of a 4-round batch-and-wait cycle.

**Concrete next step**: add a compile-only Windows job to the package's CI (or the centralized `swift-ci.yml`). Do not spike further on macOS→Windows cross-compilation until swift.org publishes an official Windows Swift SDK bundle (not on the Windows Workgroup's current charter). Revisit only if that changes.

## 7. Open follow-ups

- Watch for an official Windows Swift SDK artifactbundle from swift.org / the Windows Workgroup — that is the single event that would flip this to GO with near-zero effort (`swift sdk install <url>` + `swift build --swift-sdk`, mirroring the Wasm/Android SDK flow). Nothing published as of 2026-07-03.
- If a compile-only CI gate is adopted ecosystem-wide, fold the pattern into the `ci-cd-workflows` skill alongside the Wasm/embedded advisory-job patterns.
