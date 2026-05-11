# Investigation Arc: Linux Release Pointer-Arithmetic Miscompile

**Status**: Bug confirmed, characterized, reproducer minimal. Upstream filing
held pending user authorization.

**Tracking artifact**: `swift-institute/Issues/swift-issue-pointer-arithmetic-linux-miscompile/`

This note captures the **investigation arc**, including the false trails. The
test-target catalog in the Issues repo still carries the artifacts of those
false trails (16 SwiftPM test targets), preserved as institutional record. The
final filing-ready 8-line reproducer is in
`Issues/.../UPSTREAM-DRAFT.md`.

## Why this note exists

The bug's surface is non-obvious. The investigation visited three sequential
hypotheses, each refuted by the next experiment, before landing on the actual
characterization. Future bug hunts on this codebase will benefit from the
correction trail; the 16-target SwiftPM structure in the Issues repo looks
overengineered without this context.

## Confirmed bug shape (current understanding)

- **Where**: LLVM optimization or backend codegen (SIL and LLVM IR are byte-identical between affected and unaffected source forms).
- **Affected**: Swift 6.3.1 release + 6.4-dev nightly, `-O` and `-Osize`, both macOS arm64 and Linux x86_64 (cross-platform, not Linux-only).
- **Unaffected**: `-Onone` on any platform.
- **Trigger**: at least two chained `.advanced(by:)` calls on `UnsafeMutablePointer<Int>` where at least one offset is negative.
- **Does NOT depend on**: any SwiftPM `swiftSettings`, the `unsafe` keyword (SE-0466), user-authored operator overloads, any of `.strictMemorySafety`, `.Lifetimes`, `.LifetimeDependence`, or any other experimental/upcoming feature.

## Investigation arc — chronological

### Round 0 — original failure surface (2026-05-11 morning)

`swift-affine-primitives` Linux 6.3 release CI red on `unsafeMutablePointerMinusTypedOffset` test. Test used a user-authored `-` operator wrapping `.advanced(by: -Int(bitPattern: rhs))`. Three operator-body fixes attempted, all failed (explicit local `let`, `@inlinable` swap, `withExtendedLifetime` wrapping). Concluded the miscompile is at the call-site `.pointee` read, not in the operator body.

### Round 1 — `.Lifetimes` hypothesis (FALSE)

After moving the reproducer to a standalone repo and bisecting the 10 swiftSettings affine-primitives enabled, the single setting `.enableExperimentalFeature("Lifetimes")` appeared to be the unique trigger. The 11-target sweep confirmed all 11 With\*-feature targets failed equally, and only the WithoutUnsafe target (with no `unsafe` keyword markers) passed.

**False conclusion**: `.Lifetimes` is the trigger.
**Refutation**: when source files received `unsafe` markers in the byte-identical sweep, ALL 11 targets failed — including the Control target with zero swiftSettings.

### Round 2 — `unsafe` keyword hypothesis (FALSE)

Adding a `WithoutUnsafe` disambiguator target proved that the `unsafe` keyword marker (not `.Lifetimes`) was the common factor across all failing configurations in the prior round. Reported as the trigger.

**False conclusion**: the Swift 6.3 `unsafe` keyword expression (SE-0466) is the trigger.
**Refutation**: standalone `swiftc -O` on the 8-line reproducer fires the bug regardless of `unsafe` markers — on macOS AND Linux. SIL and LLVM IR are byte-identical between with-unsafe and without-unsafe forms. The `unsafe` attribution was an artifact of SwiftPM test-framework build flags happening to gate which configurations expose the optimizer bug under `swift test -c release`.

### Round 3 — actual characterization (CONFIRMED)

Standalone reproducer extraction. SIL diff (byte-identical) + LLVM IR diff (byte-identical) + optimization-level matrix (-O / -Osize fail, -Onone passes) + cross-platform check (macOS arm64 + Linux x86_64 both fail at standalone -O). Reduction by trigger-surface variation:

- Single `.advanced(by:)` step: passes.
- Subscript `buf[2]`: passes.
- Two `.advanced(by:)` calls, both positive: passes.
- Two `.advanced(by:)` calls, at least one negative: **FAILS**.

**Confirmed**: chained mixed-direction pointer arithmetic on `UnsafeMutablePointer<Int>` miscompiles at `-O` / `-Osize`.

## Why the false trails are valuable

Each false trail produced reusable artifacts:

- **Round 1 (`.Lifetimes` bisection)**: the 10-setting individual-feature sweep is a reusable template for bisecting any future swiftSettings-related compiler bug.
- **Round 2 (`unsafe` attribution)**: led to the realization that SwiftPM `swift test -c release` has different optimizer behavior than standalone `swiftc -O`. This is a calibration fact for future investigations — never trust SwiftPM-test-only behavior as a proxy for the bare compiler.
- **Round 3 (standalone extraction)**: produced the filing-ready 8-line reproducer that meets [ISSUE-002] gold standard.

## Methodology lessons (codified)

- `[ISSUE-005]` SIL Dump Analysis: should have happened earlier. The byte-identical SIL between with/without unsafe was the smoking gun that ruled out source-level attribution.
- `[ISSUE-013]` Variable Isolation: the SwiftPM 16-target sweep WAS variable isolation, but limited to `swiftSettings` and `unsafe`-keyword presence — both source-level. The actual trigger (chained `.advanced(by:)` with negative offset) was a SOURCE-PATTERN dimension that the SwiftPM sweep didn't vary.
- `[ISSUE-025]` In-Package Verification of Synthetic-Reproducer Claims: the cascade-claim discipline applies in reverse here — the SwiftPM test-target sweep made the bug LOOK narrower than it is. Standalone extraction broadened the trigger surface from "unsafe-bearing tests" to "any release-mode -O code with mixed-direction `.advanced(by:)`".

## Cross-References

- `swift-institute/Issues/swift-issue-pointer-arithmetic-linux-miscompile/UPSTREAM-DRAFT.md` — filing-ready issue body
- `swift-institute/Issues/swift-issue-pointer-arithmetic-linux-miscompile/README.md` — 16-target catalog (artifacts of false trails)
- `swift-institute/Research/swift-compiler-bug-catalog.md` — entry to be added post-filing
- `swift-affine-primitives/Tests/Affine Primitives Tests/AffineSLITests.swift::unsafeMutablePointerMinusTypedOffset` — in-tree fix detector (gated off via `.disabled(if: isLinux)` + `.bug(URL, ...)`)
- Skill: `[ISSUE-001]`, `[ISSUE-005]`, `[ISSUE-013]`, `[ISSUE-025]`, `[ISSUE-026]`
- Skill: `[ISSUE-028]` — compiler bug catalog consultation
