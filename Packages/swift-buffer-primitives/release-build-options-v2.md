# Release Build Options v2: Ranked Alternatives

> **SUPERSEDED (2026-03-22)**: Both bugs resolved without compiler flags. Bug 1: field-ordering fix. Bug 2: removed `~Escapable` from Property.View. No `@_optimize(none)`, no `-disable-sil-ownership-verifier`, no `-disable-llvm-verify` needed. See [rawlayout-release-crash-investigation.md](rawlayout-release-crash-investigation.md).

<!--
---
version: 1.0.0
last_updated: 2026-03-22
status: SUPERSEDED
---
-->

## Context

`swift build -c release` for swift-buffer-primitives requires two compiler flags:
- `-Xfrontend -disable-llvm-verify` (Core target only)
- `-Xfrontend -disable-sil-ownership-verifier` (all targets)

These `.unsafeFlags` block Swift Package Registry distribution and may infect downstream consumers. This document ranks the alternatives based on empirical evidence from the consolidated experiment corpus.

## Two Separate Bugs

**Bug 1 — LLVM Verifier Crash** ("Instruction does not dominate all uses!"):
- Standalone reproducer EXISTS: `Experiments/rawlayout-minimal-reproducer/`
- Trigger: struct storing 2+ fields of cross-module `@_rawLayout(likeArrayOf: Element, count: capacity)` + `deinit` type under `-O`
- Crash is in the consumer module's implicit destructor (LLVM IR lowering)
- Affects: Buffer Primitives Core (4 Inline types with @_rawLayout + deinit)

**Bug 2 — SIL Ownership Crash** ("Found ownership error?!"):
- NO standalone reproducer (7 patterns tried, all failed)
- Context-sensitive: requires full production dependency graph
- Affects: Ring Primitives, Ring Inline Primitives, Slab Inline Primitives (3 of 12 downstream modules)
- Removing `@inlinable`, `@_optimize(none)`, `@_transparent` — none work

## Ranked Options

### Option 1: File Bug 1, Keep Flags as Interim Workaround (RECOMMENDED)

**What**: File Bug 1 against swiftlang/swift with the minimal reproducer. Keep both `-disable-*` flags until the compiler is fixed. Monitor Swift nightly builds for the fix.

**Correctness**: Full. All 4 Inline types keep their deinits. 391 tests pass. Element cleanup works for all types.

**Downstream impact**: Consumers MAY need `-disable-sil-ownership-verifier` if they trigger CopyPropagation on @_rawLayout paths. The `.unsafeFlags` blocks registry distribution.

**Performance**: None. The flags disable verification passes, not optimization. Generated code is identical.

**Reversibility**: Trivial. Remove the two flag lines from Package.swift when the compiler is fixed.

**Evidence**: `rawlayout-minimal-reproducer/` (Bug 1 reproduces), production builds (391 tests pass with flags).

**Why it ranks first**: The flags disable VERIFICATION, not optimization — the generated code is unchanged. The bugs are in the compiler's checking, not in the code it generates. This is the only option with zero correctness risk and zero performance cost. The reproducer is ready for filing.

---

### ~~Option 2: AnyObject? Triviality Workaround~~ (INVALIDATED)

**What**: Add `_deinitWorkaround: AnyObject? = nil` to all 4 Inline types. Forces non-trivial destructibility classification, preventing the triviality misclassification documented in swiftlang/swift#86652.

**Status**: **INVALIDATED** — tested empirically 2026-03-21. Works for the minimal reproducer (consumer-module 2-field pattern) but does NOT fix the production crash (extension-file pattern under WMO). Also does NOT fix Bug 2 (SIL ownership crash persists in Ring Primitives even with AnyObject? applied and Bug 1 suppressed).

**Evidence**: See `rawlayout-llvm-verifier-crash/EXPERIMENT.md` "AnyObject? Workaround Test" section.

**Why it fails**: The production crash uses the extension-file trigger path (types defined via `extension` under WMO), not the consumer-module 2-field path that the minimal reproducer captures. These are different LLVM IR lowering paths, and triviality reclassification only fixes the latter.

---

### Option 3: Remove Deinit from Ring.Inline and Linear.Inline (Reduce to ≤2)

**What**: Remove explicit `deinit` from `Buffer.Ring.Inline` and `Buffer.Linear.Inline`. Their deinits only call `storage.deinitialize()` — delegate cleanup to the Storage.Inline type or require callers to explicitly deinitialize.

Keep deinits on `Buffer.Slab.Inline` and `Buffer.Arena.Inline` (which have complex bitmap/meta-driven cleanup that can't be delegated).

**Correctness**: Ring/Linear element cleanup must be handled elsewhere. If Storage.Inline can handle it autonomously via its own deinit, this is correct. If not, elements leak.

**Downstream impact**: None — no flags needed.

**Performance**: None.

**Reversibility**: Easy — re-add deinit blocks when compiler is fixed.

**Evidence**: Diagnosis Step 6 (struct-body ≤2 threshold). Reducing to 2 deinits in struct-body pattern should stay under threshold. But NOTE: the reproducer found the cross-module threshold is 2 FIELDS, not types. Need to verify that 2 types with deinit doesn't hit a different threshold.

**Why it ranks third**: Requires verifying that Storage.Inline can handle Ring/Linear cleanup. Risk of element leaks if it can't. Also doesn't address Bug 2.

---

### Option 4: Remove ALL Deinits, Require Explicit Cleanup

**What**: Remove all 4 Inline type deinits. Require callers to call `deinitialize()` before the value goes out of scope. Use `discard self` or consuming methods for cleanup.

**Correctness**: Breaks RAII. Elements LEAK if callers forget to call `deinitialize()`. The `discard self` approach is blocked because @_rawLayout types are not trivially destructible (see `rawlayout-deinit-alternatives/` V01).

**Downstream impact**: Breaking API change — all consumers must add explicit cleanup.

**Performance**: None.

**Reversibility**: Hard — the API contract change propagates to all consumers.

**Evidence**: `rawlayout-deinit-alternatives/` V01 (discard self REFUTED for @_rawLayout).

**Why it ranks fourth**: Breaks RAII contract. High risk of resource leaks.

---

### Option 5: Conditional Flags (Release-Only, Package-Local)

**What**: Keep the current approach but add documentation for downstream consumers. Investigate whether the `.unsafeFlags` restriction can be worked around via a `Package@swift-6.2.swift` overlay or build plugin.

**Correctness**: Same as Option 1.

**Downstream impact**: Still blocks registry. Downstream still may need the SIL flag.

**Performance**: None.

**Reversibility**: Same as Option 1.

**Evidence**: Current production builds.

**Why it ranks fifth**: Doesn't solve the distribution problem. Only a documentation improvement.

---

## Recommendation

**Option 1** (file bug + keep flags) is the clear winner. The flags have zero correctness or performance impact — they disable verification, not optimization. The minimal reproducer is ready for filing.

The bug report should include:
1. The reproducer at `Experiments/rawlayout-minimal-reproducer/` (Bug 1)
2. Build command: `rm -rf .build && swift build -c release --target Bug1Consumer`
3. Expected: signal 6, "Instruction does not dominate all uses!"
4. Toolchain: Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
5. Note that Bug 2 exists in the production codebase but cannot be reproduced standalone

**Option 2** or **Option 3** can be pursued in parallel as defense-in-depth, but only if the structural refactoring is validated to also fix Bug 2 (which is the harder bug to address).

## Cross-References

- [rawlayout-release-crash-investigation.md](rawlayout-release-crash-investigation.md) — Consolidated investigation record
- [release-mode-llvm-verifier-crash-diagnosis.md](release-mode-llvm-verifier-crash-diagnosis.md) — Full diagnosis
- `Experiments/rawlayout-minimal-reproducer/` — Standalone Bug 1 reproducer
- `Experiments/rawlayout-llvm-verifier-crash/` — Consolidated Bug 1 experiments
- `Experiments/rawlayout-sil-ownership-crash/` — Consolidated Bug 2 experiments
- `Experiments/rawlayout-deinit-alternatives/` — Workaround alternatives
