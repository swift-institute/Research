# L1 types-only with no kernel-primitives exception

<!--
---
version: 1.1.1
last_updated: 2026-04-26
status: RECOMMENDATION
---
-->

## Abstract

`swift-kernel-primitives` (L1) currently hosts three types whose storage
shape diverges per platform: `Kernel.Descriptor` (`Int32` POSIX, `UInt`
Windows), `Kernel.Process.ID` (`Int32` POSIX, `UInt32` Windows), and
`Kernel.Directory.Entry` (`[UInt8]` POSIX, `[UInt16]` Windows). Each is
implemented with inner `#if os(...)` blocks at L1, in tension with
[PLAT-ARCH-008c] (no platform code at L1) and [PLAT-ARCH-015] (per-L2
platform-native typed values). [PLAT-ARCH-005] explicitly carves
`Kernel.Descriptor` as an L1 exception. This document recommends
**eliminating the kernel-primitives exception** by relocating the three
divergent-shape types out of L1 and unifying them via L3 typealiases
in `swift-kernel`. The chain endpoint is **L3-policy** (`swift-posix` /
`swift-windows`), not L2 — `deinit`-closing RAII is policy in the same
sense that EINTR retry is policy.

## 1. Motivation

The `[PLAT-ARCH-005]` exception has been in place because removing it
appeared to require either (a) per-L2 type definitions that break
ecosystem-wide consumer code (`Kernel.Descriptor` is referenced in
hundreds of call sites), or (b) lossy uniform L1 storage that
misrepresents platform reality. Both are unacceptable, so the exception
was retained.

The exception nonetheless creates ongoing tension:

- Every audit cycle re-flags the L1 conditionals.
- New platform-divergent types (Process.ID, Directory.Entry, future
  ones) re-litigate the question case-by-case.
- The `[PLAT-ARCH-008c]` rule documents the principle but contradicts
  itself with `[PLAT-ARCH-005]` — the platform skill carries an
  internal inconsistency.

The proposal here is that the exception was solving the wrong problem.
The cross-platform *name* and the cross-platform *type* don't have to
live in the same package. Splitting them — name in L3 (typealias),
type in L3-policy or L2 (concrete per-platform) — eliminates the L1
exception without breaking consumers.

## 2. Background

### 2.1 Existing precedent: `Process.Group.ID`

`ISO_9945.Kernel.Process.Group.ID` already lives in `swift-iso-9945`
(L2) as `Tagged<ISO_9945.Kernel.Process.Group, Int32>`. Cross-platform
consumers reach it via the iso-9945 namespace. There is no L3 typealias
at `Kernel.Process.Group.ID` — consumers use the platform-namespaced
form.

### 2.2 Re-export chain ([PLAT-ARCH-006])

`swift-kernel`'s `Sources/Kernel/Exports.swift` already conditionally
re-exports per-platform L3 packages:

```swift
@_exported public import Kernel_Primitives
#if canImport(Darwin)
    @_exported public import Darwin_Kernel
#elseif canImport(Glibc) || canImport(Musl)
    @_exported public import Linux_Kernel
#elseif os(Windows)
    @_exported public import Windows_Kernel
#endif
```

Adding a per-platform typealias to this file extends the existing
pattern; it is not a new mechanism.

### 2.3 Within-L3 sub-tiering (parallel session)

Concurrent work at
`swift-institute/Research/lateral-l3-to-l3-composition-options.md`
stamps three L3 sub-tiers:

- **L3-policy** (swift-posix, swift-darwin, swift-linux, swift-windows):
  per-platform wrappers over L2 raw, ADD policy.
- **L3-unifier** (swift-kernel base + swift-strings, swift-paths,
  swift-ascii, swift-systems, swift-environment, swift-io,
  swift-threads): cross-platform unification.
- **L3-domain** (swift-file-system; under reconsideration).

This investigation's chain endpoint sits in this model. The decision
on where the per-platform descriptor type lives — L3-policy or L2 —
is shared with the parallel session and gates both.

## 3. Problem Statement

Three L1 types host inner `#if os(...)` blocks because their storage
shape genuinely differs per platform:

| Type | POSIX shape | Windows shape | Audit item |
|---|---|---|---|
| `Kernel.Descriptor` | `Int32` raw + `close()` deinit | `UInt` raw + `CloseHandle` deinit | 7 |
| `Kernel.Process.ID` | `Int32` rawValue (`pid_t`) | `UInt32` rawValue (`DWORD`) | 12 |
| `Kernel.Directory.Entry` | `[UInt8]` rawName (POSIX bytes) | `[UInt16]` rawName (UTF-16 code units) | 9 |

Status quo: `[PLAT-ARCH-005]` exception for Descriptor, ad-hoc
`#if os(...)` for the other two pending decision.

## 4. Hypothesis

The unification point should live at L3, not L1. Each per-platform
type is defined once with platform-native storage in its
platform-appropriate package; `swift-kernel` provides a typealias
that resolves to the right type per platform. Cross-platform
consumers using `import Kernel; Kernel.Descriptor` see no change.

## 5. The Load-Bearing Sub-Decision: deinit-close = policy or raw?

The chain endpoint depends on a conceptual call about what
`deinit`-closing RAII counts as in the L2/L3-policy framing.

### Branch (i) — deinit-close is POLICY → endpoint is L3-policy

`POSIX_Kernel_Descriptor` lives in `swift-posix` (L3-policy) with
`Int32` raw + POSIX deinit-close. `Windows_Kernel_Descriptor` lives
in `swift-windows` (L3-policy) with `UInt` raw + `CloseHandle`
deinit. `swift-kernel` typealias resolves cross-platform.

L2 (iso-9945, windows-standard) keeps its current "raw spec encoding
only" framing — no carve-out needed. Cleanly covered by
[PLAT-ARCH-008e] (L3-unifier composes L3-policy).

### Branch (ii) — deinit-close is RAW Swift encoding → endpoint is L2

`POSIX.Kernel.Descriptor` lives in `iso-9945` (L2) with deinit-close
embedded. Requires explicit carve-out: "RAII / `~Copyable` deinit
counts as raw Swift idiom, not policy."

### Recommendation: (i)

Both branches are coherent. (i) is structurally preferable because:

1. **No principled (raw-Swift-idiom) vs (policy-Swift-idiom)
   distinction exists.** RAII auto-close and EINTR retry are both
   deliberate decisions about how to handle concerns the raw spec
   leaves to the caller. Splitting them as "raw" vs "policy" requires
   a line drawn by stipulation, not principle.
2. **Symmetry.** An EINTR-retrying `read()` wrapper in swift-posix is
   policy. A close-on-deinit wrapper around Int32 is the same kind of
   policy: choosing a Swift-idiomatic handling for a concern not
   forced by the spec.
3. **L2 stays minimal.** "Raw spec encoding, nothing else" is a
   stronger and more auditable framing than "raw spec encoding plus
   RAII but not other Swift idioms."
4. **swift-posix is the natural home.** swift-posix already exists as
   a per-domain-variant package ("POSIX Kernel File", "POSIX Kernel
   Process", etc.). `POSIX_Kernel_Descriptor` is a "POSIX Kernel
   Descriptor" target — drops in.

## 6. Migration Sketch (Branch (i))

### 6.1 `Kernel.Descriptor`

| Layer | Before | After |
|---|---|---|
| L1 swift-kernel-primitives | `extension Kernel { struct Descriptor: ~Copyable {…} }` with 5 inner `#if os` | DELETED. `Kernel.Descriptor` no longer exists at L1. |
| L2 swift-iso-9945 | (no Descriptor) | (no Descriptor) — L2 stays raw spec only |
| L2 swift-windows-standard | (no Descriptor) | (no Descriptor) |
| L3-policy swift-posix | (no Descriptor) | NEW: `POSIX_Kernel_Descriptor` target with `Int32` raw + close-on-deinit |
| L3-policy swift-windows | (no Descriptor) | NEW: `Windows_Kernel_Descriptor` target with `UInt` raw + `CloseHandle` deinit |
| L3-unifier swift-kernel | (re-exports primitives' Descriptor) | NEW: `Kernel/Exports.swift` adds `#if`-guarded `typealias Kernel.Descriptor = POSIX_Kernel_Descriptor.POSIX.Kernel.Descriptor` (POSIX) / `= Windows_Kernel_Descriptor.Windows.Kernel.Descriptor` (Windows) |

Cross-platform consumers writing `import Kernel; Kernel.Descriptor`
see no change. Per-platform extensions defined in swift-posix or
swift-windows are visible via the L3 re-export chain.

### 6.2 Extension methods on `Kernel.Descriptor`

A `typealias Kernel.Descriptor = X` does not introduce a new type —
`Kernel.Descriptor` and `X` are the same type. Extensions on
`Kernel.Descriptor` are extensions on the underlying per-platform
type. On POSIX they extend `POSIX_Kernel_Descriptor`; on Windows
they extend `Windows_Kernel_Descriptor`. Per-platform compilation
resolves correctly.

The Swift 6.3 question: do `~Copyable` typealiases of distinct
`~Copyable` types compose cleanly with extension methods defined
once via the typealias name? **This requires compiler verification
before commit.** A trivial probe:

```swift
public struct A: ~Copyable { ... }
public struct B: ~Copyable { ... }
#if os(Linux)
public typealias C = A
#else
public typealias C = B
#endif
extension C { public func ping() {} }
```

If this compiles and `c.ping()` resolves on both platforms, branch (i)
is mechanically clean. If not, the migration must define extensions
per-platform inside swift-kernel using the same `#if os` boundary as
the typealias.

### 6.2.1 §6.2 Probe Result

**Status**: GREEN — verified Apple Swift 6.3.1 on 2026-04-26.

**Setup**: Throwaway sandbox `/tmp/typealias-probe`, swift-tools-version
6.3, macOS 26 host. Two distinct `~Copyable` structs (`A` with stored
`Int` + `deinit`, `B` with stored `Int` + `deinit`), `#if`-gated
typealias `C = A` on `os(macOS) || os(Linux)` else `C = B`, and a
single `extension C { public func ping() -> Int { value } }` declared
once on the typealias name.

**Findings** (matrix fully covered: A-leg × B-leg × single-module ×
cross-module × debug × release = 8/8 passes):

| Variant | Build | Output |
|---|---|---|
| Single-module, A-leg (literal `#if os(macOS) \|\| os(Linux)`) | debug + release | `C.ping() = 42` |
| Single-module, B-leg (else branch forced via inverted `#if`) | debug + release | `C.ping() = 42` |
| Cross-module, A-leg — A in `ProbeA`, B in `ProbeB`, typealias + extension in `ProbeUnifier` (re-exporting both via `@_exported public import`), consumer imports `ProbeUnifier` only; literal `#if` resolves to `C = A` on macOS | debug + release | `xmod C.ping() = 42` |
| Cross-module, B-leg — same shape, `ProbeUnifier`'s `#if` inverted to force `C = B` on macOS | debug + release | `xmod C.ping() = 42` |

The B-leg was verified on macOS by inverting the `#if` predicate to
force the else branch in both single-module and cross-module forms;
the compiler resolved `c.ping()` cleanly in both directions,
demonstrating that the typealias name participates in extension
method dispatch identically regardless of which underlying
`~Copyable` type the typealias resolves to. The cross-module variant
mirrors the production shape (A in `POSIX_Kernel_Descriptor`, B in
`Windows_Kernel_Descriptor`, typealias + extension in `swift-kernel`,
consumers writing `import Kernel`); both debug and release passes on
both legs confirm SIL-level behavior under optimization, satisfying
[EXP-017]'s release-mode + cross-module gating for adoption-grade
probes.

**Implication for §6.2**: The migration is mechanically clean.
Extensions on `Kernel.Descriptor` declared once at the typealias name
in `swift-kernel` resolve correctly per-platform without requiring
per-platform `#if`-gated extension declarations. The fallback path
(per-platform extension blocks under the same `#if` as the typealias)
is NOT required.

**Implementation cost**: unchanged. The migration sketches in §§ 6.1,
6.3, 6.4 stand as written; no per-platform extension duplication is
needed.

**Toolchain**: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2
clang-2100.0.123.102), macOS 26 (arm64), Darwin 25.2.0.

**Probe artifacts**: `/tmp/typealias-probe/` (throwaway sandbox; not
git-tracked). Build and run output in `/tmp/typealias-probe/Outputs/`.

### 6.3 `Kernel.Process.ID`

Same shape: define `POSIX_Kernel_Process.POSIX.Kernel.Process.ID` as
`Tagged<…, Int32>` (analogue to existing `Process.Group.ID` in
iso-9945, but moved to swift-posix per the policy framing — a `pid_t`
acquisition wrapper IS policy by the same argument). Define
`Windows_Kernel_Process.Windows.Kernel.Process.ID` as
`Tagged<…, UInt32>`. swift-kernel typealias unifies.

Note: this also recommends moving `ISO_9945.Kernel.Process.Group.ID`
out of iso-9945 to swift-posix to maintain the L2/L3-policy
discipline. That's a follow-on; not in this migration's first cut.

### 6.4 `Kernel.Directory.Entry`

The `[UInt8]` vs `[UInt16]` storage and per-platform UTF decoding
are policy (decode strategy is a deliberate choice). Move the type
to swift-posix (`POSIX_Kernel_Directory_Entry`) and swift-windows
(`Windows_Kernel_Directory_Entry`); swift-kernel typealias unifies.

## 7. Consumer Impact

The typealias preserves source compatibility for consumers writing
`import Kernel; Kernel.Descriptor`. Consumers writing
`@_spi(Syscall) import Kernel_Descriptor_Primitives` and reaching
`_rawValue` will need to update their import to
`import POSIX_Kernel_Descriptor` (POSIX) / `import Windows_Kernel_Descriptor`
(Windows) — that's a known set of platform-stack call sites
(swift-iso-9945, swift-windows-standard, swift-darwin-standard
extensions; ~80 files per
`spi-and-path-cleanup.md`). The import update is mechanical.

Verification step before commit: grep cross-package consumers and
confirm the migration's call-site impact is bounded as estimated.

## 8. Skill Changes

### 8.1 [PLAT-ARCH-005] revised

Current text:
> `Kernel.Descriptor` MUST be the single file descriptor / handle
> type across all platforms.

Revised text (proposed):
> `Kernel.Descriptor` MUST be the single cross-platform name for the
> file descriptor / handle type. The name is unified at L3
> (`swift-kernel`) via a per-platform typealias resolving to
> `POSIX_Kernel_Descriptor` (swift-posix) or
> `Windows_Kernel_Descriptor` (swift-windows). L1 swift-kernel-primitives
> MUST NOT define a `Kernel.Descriptor` type itself.

### 8.2 [PLAT-ARCH-008c] strengthened

Reaffirm "L1 has no platform-conditional type definitions" without the
implicit Descriptor exception. Cross-reference [PLAT-ARCH-005]
revised.

### 8.3 [PLAT-ARCH-015] augmented

Add a corollary: "When per-L2 platform-native typed values benefit
from cross-platform name unification, the unification SHOULD use an
L3-typealias-via-`#if-os` pattern rather than introducing an L1
exception."

### 8.4 [PLAT-ARCH-008e] reinforced

The L3-unifier-composes-L3-policy pattern carries the descriptor
type relocation cleanly — no new rule needed; this is a new
application of an existing rule.

## 9. Open Questions

1. **Compiler verification** of `~Copyable` typealias + extension
   resolution (§ 6.2). Critical before commit.
2. **Migration of existing `Process.Group.ID`** out of iso-9945 to
   swift-posix per the policy framing (§ 6.3). Follow-on work,
   tracked separately.
3. **L3-domain collapse** (per parallel session): if swift-file-system
   collapses into L3-unifier, this investigation is unaffected — the
   typealias chain is L1↔L3 vertical, not within-L3 horizontal.

## 10. Recommendation Summary

- **Eliminate the kernel-primitives exception.** L1 hosts only
  platform-uniform types.
- **Branch (i): deinit-close is policy.** Per-platform descriptor
  types live in L3-policy (swift-posix, swift-windows).
- **L3 typealias unification** in swift-kernel preserves source
  compatibility for cross-platform consumers.
- **Three skill rules updated** ([PLAT-ARCH-005] revised,
  [PLAT-ARCH-008c] strengthened, [PLAT-ARCH-015] augmented). No new
  rule introduced.
- **Migration is a separate handoff.** This document is a decision
  artifact; execution is bounded by compiler verification and
  consumer-impact grep.

## 11. Cross-references

- [PLAT-ARCH-005] (current): `Kernel.Descriptor` as single
  cross-platform type — to be revised per § 8.1.
- [PLAT-ARCH-006]: re-export chain — extension point for the
  typealias.
- [PLAT-ARCH-008c]: L1 platform-conditional type definitions
  forbidden — to be strengthened per § 8.2.
- [PLAT-ARCH-008e]: L3-unifier composes L3-policy — pattern reused.
- [PLAT-ARCH-015]: per-L2 platform-native typed values — augmented
  per § 8.3.
- `Principled Syscall Layering.md` (this repo, 2026-01-15,
  DECISION) — strategic background; this doc applies the principle
  to the residual L1 exception.
- `swift-institute/Research/lateral-l3-to-l3-composition-options.md`
  (parallel session, 2026-04-26) — within-L3 sub-tiering model;
  shared chain-endpoint decision.
- `spi-and-path-cleanup.md` (this repo, 2026-04-10) — SPI surface
  inventory; informs § 7 consumer-impact estimate.
