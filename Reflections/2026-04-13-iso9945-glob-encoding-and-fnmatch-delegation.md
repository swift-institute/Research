---
date: 2026-04-13
session_objective: Encode POSIX fnmatch(3) and glob(3) at L2 in swift-iso-9945, then refactor L3 POSIX_Kernel_Glob to delegate matching to L2
packages:
  - swift-kernel-primitives
  - swift-iso-9945
  - swift-posix
status: processed
---

# ISO 9945 Glob Encoding and fnmatch Delegation

## What Happened

Implemented three-layer change to encode POSIX fnmatch(3)/glob(3) at L2 and delegate L3 matching:

**L1 (swift-kernel-primitives)**: Added `nameView` property to `Kernel.Directory.Entry` using `@_lifetime(borrow self)` + `_overrideLifetime` — same pattern as `Paths.Path.kernelPath`. This required preserving the NUL terminator in `rawName` (L2 `readdir` wrapper changed from `count: length` to `count: length + 1`). Updated `isDotOrDotDot` and `name` for NUL-inclusive rawName.

**L2 (swift-iso-9945)**: Created `ISO 9945 Glob` target with 6 source files encoding `fnmatch(3)` and `glob(3)`. All C interop routed through `CISO9945Shim` — the Swift code has zero `#if canImport(Darwin)` / `Glibc` / `Musl` conditionals. The shim sets `_GNU_SOURCE` to expose `FNM_CASEFOLD` (POSIX Issue 8, 2024) on Glibc; on Musl where it's not yet implemented, the shim returns 0 so `.casefold` is a no-op OptionSet value.

**L3 (swift-posix)**: Replaced ~200 lines of pure-Swift pattern matching (`matchAtoms`, `matchBytesRecursive`, `utf8CharLength`, `decodeUTF8Scalar`) with delegation to `ISO_9945.Glob.fnmatch`. Entry names accessed via zero-allocation `entry.nameView` property; pattern segments bridged via `Kernel.Path.scope` (one allocation per segment).

All 20 existing L3 glob tests pass. 18 new L2 tests (fnmatch unit + edge cases, glob expand).

## What Worked and What Didn't

**Worked well**: The `@_lifetime(borrow self)` property pattern for `nameView` — proven by `Paths.Path.kernelPath`, applied cleanly. Zero-allocation access to entry names without closure-based scoping. The C shim approach for `FNM_CASEFOLD` eliminated all platform conditionals from Swift.

**Required course correction**: Three significant plan revisions during session:

1. **Initial plan proposed `@unsafe` raw pointer overloads** on the L2 API. User corrected: the entire purpose of L2 is to make C safe — unsafe stays inside the implementation body, never surfaces at any visibility level.

2. **Initial plan proposed removing L3 matching entirely** (L2 encoding only, no delegation). Then analysis revealed that with `nameView` plumbing, delegation is zero-allocation at the call site — so the L3 refactor IS worth doing.

3. **`FNM_CASEFOLD` placement went through three iterations**: first in `swift-iso-9945` (wrong: not POSIX pre-Issue-8), then in `swift-darwin-standard` / `swift-linux-standard` (wrong: authority vs. platform confusion), finally back in `swift-iso-9945` via C shim (correct: POSIX Issue 8, with graceful degradation via rawValue 0 on Musl).

## Patterns and Root Causes

**Authority vs. Platform is the key L2 packaging principle.** The `FNM_CASEFOLD` journey exposed a gap in understanding: L2 packages should be named after the *specification authority* that defines the API contract (IEEE 1003.1, BSD, GNU), not the *platform* where it compiles (Darwin, Linux). `swift-linux-standard` is the wrong home for `FNM_CASEFOLD` because it's not a Linux standard feature — it's a GNU/glibc extension. As of POSIX Issue 8 (2024), it's now POSIX proper, so `swift-iso-9945` is the correct home.

**C shim as universal translation boundary.** Routing all fnmatch/glob C interop through `CISO9945Shim` (with `_GNU_SOURCE`) is strictly better than per-file platform imports. The shim is the single place that knows about header visibility gaps. The `#ifdef FNM_CASEFOLD / return 0` fallback makes the OptionSet unconditional in Swift — graceful degradation through the OptionSet's own algebra (rawValue 0 = no-op).

**NUL preservation in rawName unlocked zero-allocation delegation.** The NUL byte from `dirent.d_name` was always there — we were discarding useful data. Preserving it enabled `nameView` as a property (not a closure), which in turn made the fnmatch call site allocation-free. Data plumbing decisions at L1/L2 cascade into API quality at L3.

## Action Items

- [ ] **[skill]** platform: Add guidance that `swift-iso-9945` tracks current POSIX baseline (Issue 8/2024) — constants newly standardized should go there, not in platform extension layers, with C shim `#ifdef / return 0` for implementations that lag behind
- [ ] **[skill]** platform: Add `CISO9945Shim` as the canonical pattern for bridging POSIX constants that need `_GNU_SOURCE` or are missing from some libc implementations
- [ ] **[package]** swift-iso-9945: `GLOB_BRACE` and `GLOB_TILDE` are BSD/GNU extensions (not POSIX Issue 8) — if encoded, they need the same authority analysis as FNM_CASEFOLD
