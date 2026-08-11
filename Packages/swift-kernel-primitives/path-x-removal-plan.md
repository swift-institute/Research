# Path X removal plan: delete swift-kernel-primitives

<!--
---
version: 1.2.0
last_updated: 2026-04-27
status: RECOMMENDATION
parent: l1-types-only-no-exceptions.md
supersedes: l1-types-only-no-exceptions-l2-cascade.md
---
-->

<!--
Changelog:
- 1.2.0 (2026-04-27): Cycle 1 (namespace anchor relocation, v1.0.0 § 5.2)
  is structurally impossible mid-transition and ELIMINATED from the plan.
  The Kernel namespace declaration cannot relocate L1 → swift-kernel L3
  before L1 deletion: any "move and coexist" path creates two distinct
  `Kernel` types in different modules (collision when both are visible),
  and L1-imports-from-L3 violates layering. Empirical probe via the
  existing `Kernel.Failure` pattern (`swift-kernel/Sources/Kernel Core/
  Kernel.Failure.swift:12`'s `extension Kernel { public enum Failure
  { ... } }`) confirms swift-kernel L3 can extend the L1-declared
  Kernel namespace via the existing @_exported re-export chain — this
  is the pattern Cycles 1-N (renumbered) use without requiring namespace
  relocation. The Final cycle absorbs the `enum Kernel {}` declaration
  at swift-kernel L3 atomically with the L1 package deletion. Cycle
  numbering shifts: v1.1.0 Cycles 2-24 become v1.2.0 Cycles 1-23. No
  path change; phasing refinement only.
- 1.1.0 (2026-04-27): Cycle 0 reframed substrate-only per empirical L1
  visibility finding during Cycle 0 attempt. The typealias chain landing
  (originally § 5.1's deliverable) cannot precede L1 deletion because
  Kernel_File_Primitives' public API references L1 nested error types
  (e.g., `case handle(Kernel.Descriptor.Validity.Error)`), forcing
  `public import Kernel_Descriptor_Primitives` to remain on those files.
  That public import propagates L1 Kernel.Descriptor visibility to the
  swift-kernel umbrella, colliding with any new typealias declaration.
  Cycle 0 now scopes to transit-module decoupling only — preparing
  Cycle 20 (Descriptor target deletion) to land the typealias atomically
  with L1 deletion. § 5.1 + Final cycle (renamed Cycle 20 absorption)
  updated. No path change; phasing refinement only. swift-kernel-primitives
  commit `da8fc77` is the actual Cycle 0 deliverable.
- 1.0.0 (2026-04-27): RECOMMENDATION + cascade SUPERSEDED.
-->

## Abstract

User stamped Path X on 2026-04-27: **remove swift-kernel-primitives
entirely**. The kernel domain is structurally different from other L1
domains — every kernel concept has platform variation in shape (Descriptor,
Process.ID, Directory.Entry) or existence (Termios, Signal, CloseHandle,
io_uring). Hosting these as L1 "primitives" produced recurring architectural
friction: the [PLAT-ARCH-005] exception, the L1-types-only RECOMMENDATION,
the L2-cascade discovery, the Pattern A+B hybrid surfaces. L1 has been a
category error for this domain.

**End state**: swift-kernel-primitives deleted. The cross-platform `Kernel.*`
namespace declaration moves to swift-kernel (L3-unifier). Concrete
per-platform types live in swift-posix / swift-windows / swift-linux /
swift-darwin (L3-policy). Genuinely-uniform vocabulary relocates to
domain-specific primitives packages (most exist; two need creation).
Cross-platform names resolve via `#if`-guarded typealiases in
`swift-kernel/Sources/Kernel/Exports.swift`.

This RECOMMENDATION supersedes
`l1-types-only-no-exceptions-l2-cascade.md` (INVESTIGATION → RECOMMENDATION
v2.0.1) per [META-003]. The cascade investigation was correct under its
L1-stays premise; Path X invalidates that premise. The cascade doc remains
in place as historical context.

This RECOMMENDATION operates within the within-L3 sub-tier framework
stamped 2026-04-26 in
`swift-institute/Research/lateral-l3-to-l3-composition-options.md` (Hybrid
B+C; swift-posix L3-policy; swift-kernel L3-unifier). Path X clarifies L1's
role (it doesn't exist for kernel) without redefining L3.

## 1. Context

### 1.1 Decision chain

- `l1-types-only-no-exceptions.md` v1.1.1 RECOMMENDATION (`0666a59`):
  remove the L1 exception via L3 typealias chain.
- Skill cycle (`6cc4fde` + `d535ec4`): platform skill rules revised +
  transition notes added.
- `HANDOFF-l1-exception-removal-execution.md` deferred at Phase 2 close:
  L2 cascade discovered (Pattern A typed-parameter sites + Pattern B
  family extensions across 4 L2 repos).
- Cascade investigation INVESTIGATION → RECOMMENDATION v2.0.1
  (`05a2230` → `a660a80` → `3089a62`): Path 1 family-wide cascade
  selected.
- Cycle A (β-rescue scope, 2 L3-policy add commits at swift-posix
  `f5594a0` + swift-windows `653b50b`) executed; L2 deletes deferred.
- 2026-04-27: user reconsiders the L1 premise → Path X stamped.

### 1.2 Why Path X

The cascade investigation re-derived the cost of removing the L1
exception via the family-wide cycle pattern. Empirical census at v2.0.1
established: ~71 typed-parameter sites + ~14 Pattern B sites (6
standalone + 6 inline + 2 Linux deferred) + ~205 module imports across
4 L2 repos, plus ~71 new L3-policy wrapper files needed. Even after the
cascade resolves, the residual L1 surface (Kernel.Error, Kernel.IO.Error,
Kernel.Time.*, Kernel.Random, Kernel.Path, Kernel.String, Kernel.Glob,
etc.) is a heterogeneous bucket — no single domain anchor — held together
only by the `Kernel` namespace.

Path X observes that this heterogeneous bucket is itself the structural
defect. A primitive package has a domain anchor (Memory, Time, Buffer,
Path, String). swift-kernel-primitives' anchor is the kernel — but kernel
is not a primitive concern. Kernel is the L2/L3 platform-stack surface.
What looked like "kernel primitives" is actually three things:

1. Platform-divergent types (Descriptor, Process.ID, Termios, Socket.Descriptor,
   Directory.Entry) — these are L3-policy concerns per the cascade work,
   not L1 primitives at all.
2. Genuinely-uniform vocabulary borrowed for kernel use (Time, Random,
   Memory.Address, Path, String, Glob, Permission) — these are domain
   primitives belonging in their own domain packages, not under a kernel
   bucket.
3. The `Kernel` namespace anchor itself — a single empty `enum Kernel {}`
   declaration providing the cross-platform name.

Path X redistributes these three classes correctly: (1) → L3-policy,
(2) → domain primitives packages, (3) → swift-kernel L3-unifier.
swift-kernel-primitives ceases to exist.

## 2. Empirical Census

All counts verified 2026-04-27 across 24 L1 targets at
`/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/`.

### 2.1 Per-target type counts

| Target | Files | Public types | Public funcs/props | Platform-divergence indicators |
|---|---:|---:|---:|---|
| Kernel Clock Primitives | 6 | 4 | 11 | 0 `#if os` blocks |
| Kernel Completion Primitives | 17 | 16 | 36 | 0 `#if os` (but Linux-io_uring-flavored) |
| Kernel Descriptor Primitives | 11 | 9 | 18 | 5+ `#if os` in Descriptor.swift; 12 raw refs (Int32/HANDLE) |
| Kernel Environment Primitives | 5 | 3 | 8 | 0 |
| Kernel Error Primitives | 4 | 3 | 5 | 0 |
| Kernel Event Primitives | 9 | 7 | 24 | 2 `#if os` in Event.ID (eventfd vs kqueue) |
| Kernel File Primitives | 95 | 123 | 169 | 4 `#if os` in Directory.Entry; 1-3 `#if os` in 6+ files (File.Direct, File.Rename, File.System.Kind, File.Stats.Get, File.Seek) |
| Kernel Glob Primitives | 15 | 14 | 17 | 0 |
| Kernel IO Primitives | 3 | 2 | 1 | 0 |
| Kernel Memory Primitives | 18 | 20 | 31 | 1 `#if os` in Memory.Map.Region |
| Kernel Namespace | 1 | 1 | 0 | 0 (single line: `public enum Kernel {}`) |
| Kernel Outcome Primitives | 3 | 5 | 5 | 0 |
| Kernel Path Primitives | 3 | 2 | 2 | 0 (typealias to Path_Primitives.Path) |
| Kernel Permission Primitives | 3 | 2 | 1 | 0 |
| Kernel Primitives Core | 7 | 8 | 18 | 0 |
| Kernel Process Primitives | 5 | 9 | 6 | 1 `#if os` in Process.ID (UInt32 vs Int32) |
| Kernel Random Primitives | 2 | 2 | 1 | 0 |
| Kernel Socket Primitives | 11 | 10 | 25 | 7 `#if os` in Socket.Descriptor |
| Kernel String Primitives | 2 | 1 | 0 | 0 (typealias to String_Primitives.String) |
| Kernel Syscall Primitives | 2 | 2 | 7 | 0 |
| Kernel System Primitives | 7 | 9 | 9 | 0 |
| Kernel Terminal Primitives | 10 | 6 | 10 | 1+ `#if os` in Termios.Attributes (opaque storage) |
| Kernel Thread Primitives | 13 | 7 | 7 | 0 |
| Kernel Time Primitives | 2 | 1 | 1 | 0 (typealias to Instant) |
| **Total** | **264** | **266** | **422** | |

### 2.2 Enumeration commands (reproducible)

Per-target type declarations:

```bash
for tgt in /Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/*/; do
  name=$(basename "$tgt")
  echo "[$name]"
  grep -hE "^[[:space:]]*(public|@_spi.*public)[[:space:]]+(struct|enum|class|protocol|typealias|actor)[[:space:]]+[A-Z]" "$tgt"*.swift 2>/dev/null
done
```

Per-target Kernel.* extension namespaces:

```bash
for tgt in /Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/*/; do
  grep -hE "^extension Kernel\.[A-Za-z]" "$tgt"*.swift 2>/dev/null | sort -u
done
```

Platform-divergence indicators per file:

```bash
for f in /Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/*/*.swift; do
  ifs=$(grep -c "#if os" "$f")
  raws=$(grep -c "_rawValue\|HANDLE\|pid_t\|UnsafeMutableRawPointer" "$f")
  [ $ifs -gt 0 -o $raws -gt 0 ] && echo "$f: #if=$ifs raw=$raws"
done
```

### 2.3 Consumer-impact reference counts

Ecosystem-wide imports of the L1 modules (verified 2026-04-27 across
swift-foundations, swift-iso, swift-microsoft, swift-linux-foundation,
swift-standards):

| L1 module | Import count |
|---|---:|
| Kernel_File_Primitives | 256 |
| Kernel_Error_Primitives | 233 |
| Kernel_Primitives_Core | 146 |
| Kernel_Process_Primitives | 108 |
| Kernel_Memory_Primitives | 87 |
| Kernel_Socket_Primitives | 58 |
| Kernel_Namespace | 0 (consumers reach `Kernel` via re-export chains) |
| **Total (sampled)** | **888** |

Plus `Kernel.Descriptor` symbol references: 535 across the ecosystem
(per the cascade doc § 3.7 and re-verified). Other Kernel.* symbol
counts proportionally large for File / Error / Process families.

The blast radius is order-of-magnitude 1000+ import-line edits across the
ecosystem. Path X's mitigation is the swift-kernel re-export chain
(§ 4) — most consumers can switch from `import Kernel_X_Primitives` to
`import Kernel` (the L3-unifier) without further changes.

## 3. Classification (4 buckets)

Per supervisor MUST: every type at every L1 target lands in exactly one
bucket. Classifications below are at target granularity with edge cases
called out where types within a target span buckets.

### 3.1 Bucket A — L3-policy-bound (entire target relocates to per-platform L3-policy)

These targets contain types whose storage shape or existence diverges per
platform. They migrate to swift-posix / swift-windows / swift-linux /
swift-darwin per [PLAT-ARCH-005] revised + [PLAT-ARCH-008c].

| Target | Primary divergent types | Destination(s) | Cycle |
|---|---|---|:---:|
| Kernel Descriptor Primitives | `Kernel.Descriptor` (Int32 vs HANDLE), Validity.Error, Close, Duplicate | swift-posix (POSIX-shared) + swift-windows (HANDLE) | B.1/B.2 (substrate already at scaffolding `3357fb5`/`50e7019`/`71e1bbd`) |
| Kernel Process Primitives | `Kernel.Process.ID` (Int32 vs UInt32) | swift-posix (POSIX-shared) + swift-windows | B.3 |
| Kernel Socket Primitives | `Kernel.Socket.Descriptor` (Int32 vs SOCKET HANDLE) | swift-posix (POSIX-shared) + swift-windows | B.4 |
| Kernel Terminal Primitives | `Kernel.Termios.Attributes` (opaque per-platform layout) | swift-posix (POSIX-only — Windows does not expose termios; Windows.Console is a separate domain) | B.5 |
| Kernel Completion Primitives | `Kernel.Completion.*` (io_uring entry types — Linux-only existence) | swift-linux exclusively | B.6 |

Edge cases within Kernel File Primitives (Bucket A subset, see § 3.2 and § 3.3 for the rest):

| Type | Status | Destination |
|---|---|---|
| `Kernel.Directory.Entry` | Bucket A | swift-posix (`dirent`) + swift-windows (`WIN32_FIND_DATAW`) |
| `Kernel.File.Direct.*` (Linux O_DIRECT) | Bucket A | swift-linux exclusively |
| `Kernel.File.Rename.Options` (Linux renameat2) | Bucket A | swift-linux exclusively |
| `Kernel.File.System.Kind` (`#if os` filesystem-type encoding) | Bucket A | per-platform L3-policy |

**Bucket A subtotal**: 5 full targets + ~10-15 edge-case file types. Targets
to delete after migration: 5. Targets reduced (Kernel File Primitives) but
not deleted entirely until § 3.2 + § 3.3 work concludes.

### 3.2 Bucket B — swift-kernel L3-bound (uniform vocabulary swift-kernel itself owns)

Types in this bucket are genuinely uniform but specifically NEEDED by the
swift-kernel L3-unifier to declare cross-platform names and the unifier-level
abstractions. They migrate to swift-kernel itself (NOT to a domain primitives
package).

| Target | Primary types | Destination | Notes |
|---|---|---|---|
| Kernel Namespace | `enum Kernel {}` (single declaration, file:1) | swift-kernel `Sources/Kernel/Kernel.swift` | The namespace anchor. THE load-bearing first move. |
| Kernel Error Primitives | `Kernel.Error` (uniform error wrapper), `Kernel.Error.Code` (typealias to Error_Primitives.Error.Code), `Kernel.Error.Context` (typealias) | swift-kernel `Sources/Kernel/Kernel.Error.swift` | Cross-platform error envelope. Platform-specific `init(code:)` mappings live at L3-policy per [PLAT-ARCH-008c]. |
| Kernel IO Primitives | `Kernel.IO`, `Kernel.IO.Error` | swift-kernel `Sources/Kernel/Kernel.IO.swift` | Uniform IO error vocabulary; consumed by `Kernel.Close.Error.io` etc. across platforms. |
| Kernel Outcome Primitives | `Kernel.Outcome<Failure>`, `Kernel.Outcome.Value<Success>`, `Kernel.Interrupt`, `Kernel.Outcome.GetError` | swift-kernel | Uniform protocol-level construct used by syscall result types. |
| Kernel Syscall Primitives | `Kernel.Syscall`, `Kernel.Syscall.Rule<T>` | swift-kernel | Uniform syscall framework declaring rules across platforms. |
| Kernel Primitives Core | `Kernel.File.Offset`/`Size`/`Space`/`Delta` (uniform Coordinate types), `Kernel.Wakeup`, `Kernel.Memory` (namespace shell only) | swift-kernel | Uniform Tagged-/Coordinate-derived types. The `Kernel.Memory` namespace shell goes to swift-kernel; substantive Memory types in Bucket C. |

**Bucket B subtotal**: 6 targets, ~16-20 types. The genuinely-uniform set
*specific to swift-kernel L3* is the namespace anchor + a handful of
cross-platform error/outcome/syscall-framework types. This is small (per
supervisor MUST: empty/small set was the success criterion — 16-20 types is
small relative to the 266-type total).

### 3.3 Bucket C — Domain-package-bound (relocate to a more-specific package)

Types in this bucket are genuinely uniform but belong in a domain primitives
package, not the kernel bucket. Most destinations exist as packages already.

| Target | Primary types | Destination package | Status |
|---|---|---|---|
| Kernel Time Primitives | `Kernel.Time` (typealias to `Instant`) | swift-time-primitives | EXISTS — relocate as `Time.Instant` or under domain-specific facade |
| Kernel Random Primitives | `Kernel.Random`, `Kernel.Random.Error` | swift-random-primitives | EXISTS — relocate; rename namespace from `Kernel.Random` to `Random` |
| Kernel Memory Primitives | `Kernel.Memory.*` (Allocation, Lock, Map, Page, Shared) | swift-memory-primitives | EXISTS — relocate. The `Kernel.Memory.Address` typealias collapses to `Memory.Address` in destination |
| Kernel Path Primitives | `Kernel.Path` (typealias `Tagged<Kernel, Path_Primitives.Path>`) | swift-path-primitives or swift-paths (L3 unifier) | EXISTS — `Kernel.Path` collapses to `Path` (or `Paths.Path` via L3-unifier) |
| Kernel String Primitives | `Kernel.String` (typealias `Tagged<Kernel, String_Primitives.String>`) | swift-string-primitives or swift-strings (L3 unifier) | EXISTS — same shape as Path |
| Kernel Glob Primitives | `Kernel.Glob.*` (POSIX glob patterns) | swift-glob-primitives | NEEDS CREATION — POSIX glob is a self-contained pattern language |
| Kernel Permission Primitives | `Kernel.Permission.*` (POSIX file permissions) | swift-permission-primitives OR swift-file-system-primitives | NEEDS CREATION (or fold into File Primitives) |
| Kernel System Primitives | `Kernel.System.*` (Memory, Path, Processor sysinfo) | swift-system-primitives | EXISTS — relocate sysinfo queries |
| Kernel Environment Primitives | `Kernel.Environment.*` (env var access) | swift-environment-primitives (NEW) or absorbed into swift-environment L3 | DECISION needed |
| Kernel Clock Primitives | `Kernel.Clock.*` (Continuous, Suspending, Deadline) | swift-clock-primitives | EXISTS — relocate |
| Kernel Event Primitives | `Kernel.Event.*` (mostly uniform) | swift-event-primitives (NEW) or split: ID → L3-policy (Bucket A), namespace → swift-kernel | DECISION: Event.ID is platform-divergent (eventfd/kqueue) → L3-policy; rest is uniform → swift-kernel L3 (or new package). Hybrid target. |
| Kernel Thread Primitives | `Kernel.Thread`, `Kernel.Thread.Affinity.*` | swift-thread-primitives (NEW) or swift-threads (L3) | EXISTS partial — swift-threads L3 exists; thread-domain primitives may need a primitives package |
| Kernel File Primitives (residual) | Inode, File.Stats (struct), File.Permissions, File.Open.Options, File.Stats.Kind, File.Lock.*, File.System.Stats, etc. — uniform file vocabulary | swift-file-system-primitives | NEEDS CREATION (this is the largest residual; ~70-80 types after Bucket A extracts Directory.Entry + File.Direct + File.Rename + File.System.Kind) |

**Bucket C subtotal**: 13 targets (some partial), ~120-140 types. Two new
domain primitives packages need creation: swift-glob-primitives, swift-permission-primitives
(or absorbed). One large new package: swift-file-system-primitives. swift-environment-primitives
also needs creation (or absorbed into swift-environment L3 if the env-var
domain is L3-only).

**Genuinely-uniform set total (B + C)**: ~140-160 types across 19 targets.
This is well above the supervisor `ask:`'s ">5 types" threshold for
flagging Path Y as a possible alternative.

**Surfacing the threshold trigger** (per supervisor `ask:` #1): the
genuinely-uniform set is large. However, **Path X remains correct** because
the user's stamp explicitly authorized Bucket C's redistribution to
domain-specific primitive packages. The Path Y question would arise if
swift-kernel-primitives were the *only* viable home for these types — but
Bucket C's empirical destinations show that ~120 of ~140 uniform types
already have natural homes in existing packages (8 of 13 destinations
EXIST). The 3 packages needing creation (swift-glob-primitives,
swift-permission-primitives, swift-file-system-primitives) are
domain-coherent on their own — not reluctant fragments of the kernel
bucket. The kernel bucket's heterogeneity (containing Glob + Permission +
File.Stats + Path + String + Time + Random) was itself the defect; Path X
restores domain coherence.

### 3.4 Bucket D — Delete (redundant, unused, or absorbed-by-relocation)

Types whose presence in swift-kernel-primitives is residual; no relocation
needed.

| Type | Status | Reason |
|---|---|---|
| `Kernel.File.Descriptor` (typealias) at `Kernel.File.Descriptor.swift` | Delete | `public typealias Descriptor = Kernel.Descriptor` — pure alias, redundant once Descriptor moves to L3-policy |
| Empty namespace shells in targets that empty out | Delete | E.g., if Kernel.Path Primitives becomes empty (Kernel.Path → Path collapses), the target deletes |
| Possible: `Kernel.File.Open.Cache` etc. (if absorbed by L3-policy variants) | Delete pending verification | Per-target inspection in Cycle B |

**Bucket D subtotal**: small — ~5-15 types. Mostly emerges from Bucket A's
relocations (the typealias forwarders become redundant once the underlying
type moves).

### 3.5 Cycle 0 substrate verification (per supervisor MUST)

The 6 already-pushed scaffolding commits' end-state verified on-Path-X:

| Commit | Repo | Content | Path X status |
|---|---|---|---|
| `b5c0f5f` | swift-iso-9945 | L2 spec-literal raw close (`extension Kernel.Close { @_spi(Syscall) static func close(_ fd: Int32) -> Int32 }`) | ✓ on-path. L2 spec-wrapper pattern continues at L2 |
| `871d2c0` | swift-iso-9945 | `@inlinable` fixup on `b5c0f5f` | ✓ on-path |
| `3357fb5` | swift-foundations/swift-posix | `POSIX.Kernel.Descriptor` type at L3-policy | ✓ on-path. Path X canonical home |
| `50e7019` | swift-foundations/swift-posix | POSIX descriptor family migration (Validity.Error, Close, Duplicate) | ✓ on-path |
| `1be7df4` | swift-microsoft/swift-windows-standard | L2 split: raw `CloseHandle` retained, throwing wrapper relocated | ✓ on-path. The worked-example template continues |
| `71e1bbd` | swift-foundations/swift-windows | `Windows.Kernel.Descriptor` + family + Close at L3-policy | ✓ on-path |

Plus 2 Cycle A β-rescue commits at the boundary:

| Commit | Repo | Content | Path X status |
|---|---|---|---|
| `f5594a0` | swift-foundations/swift-posix | POSIX.Kernel.Close.Error+code + POSIX.Kernel.Descriptor.Validity.Error+code at L3-policy | ✓ on-path. Provides POSIX error-code mapping at the canonical home |
| `653b50b` | swift-foundations/swift-windows | Windows mirror | ✓ on-path |

**No rework needed on the 8 substrate commits.** Cycle 0 absorbs them as
the starting point. The L2 originals (4 files at swift-iso-9945 +
swift-windows-standard) remain in place — they continue to provide L1
inits for callers in transition during Cycles 1-N; their deletion happens
in the final cycle alongside L1 deletion.

## 4. Naming-collision survey + re-export chain end-state

### 4.1 Naming-collision survey

The `Kernel` namespace (`enum Kernel {}`) is currently declared at L1 in
`Kernel Namespace` target's `Kernel.swift`. After Path X, it lives at
swift-kernel L3.

**Direct-import collision check**:

```bash
grep -rln "import Kernel_Namespace" /Users/coen/Developer/{swift-foundations,swift-iso,swift-microsoft,swift-linux-foundation,swift-standards}/ 2>/dev/null
```

Result: **0 imports**. No package directly imports `Kernel_Namespace`.
Consumers reach the `Kernel` namespace through transitive re-exports
(via `Kernel_Primitives_Core`'s 146 imports, `Kernel_Error_Primitives`'s
233 imports, etc., each of which re-exports `Kernel_Namespace`).

**Re-export chain implication**: relocating `enum Kernel {}` from L1 to
swift-kernel requires the existing transitive re-exports to redirect.
For each L1 target that currently `@_exported public import Kernel_Namespace`,
the redirect strategy is one of:

- **(a)** L1 target dies entirely (Bucket A or C): no redirect needed; the
  target's consumers migrate to swift-kernel or the destination domain
  package, which re-exports Kernel directly.
- **(b)** L1 target is a Bucket B namespace shell awaiting relocation
  to swift-kernel: the namespace shell collapses (no redirect; it
  becomes part of swift-kernel itself).

So the namespace anchor relocation does NOT break the re-export chain
because the chain itself is redirected by the per-target migrations.

### 4.2 swift-kernel re-export chain end-state

Current `swift-kernel/Sources/Kernel/Exports.swift` re-exports L3 targets
within the swift-kernel package:

```swift
@_exported public import Kernel_Core
@_exported public import Kernel_Clock
@_exported public import Kernel_System
@_exported public import Kernel_Thread
@_exported public import Kernel_File
@_exported public import Kernel_Event
@_exported public import Kernel_Completion
```

Path X end-state at this file:

```swift
// swift-kernel/Sources/Kernel/Exports.swift (post-Path-X)

// The Kernel namespace anchor itself is declared in Kernel/Kernel.swift
// (relocated from kernel-primitives/Kernel Namespace).

// L3-policy re-exports (cross-platform unification per [PLAT-ARCH-008e])
#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
@_exported public import POSIX_Kernel
#endif
#if canImport(Glibc) || canImport(Musl)
@_exported public import Linux_Kernel
#endif
#if canImport(Darwin)
@_exported public import Darwin_Kernel
#endif
#if os(Windows)
@_exported public import Windows_Kernel
#endif

// L3-unifier sub-modules (kernel-internal facets)
@_exported public import Kernel_Core
@_exported public import Kernel_File
@_exported public import Kernel_Event
@_exported public import Kernel_Completion

// Cross-platform name typealiases per [PLAT-ARCH-005] / [PLAT-ARCH-008e]
#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
extension Kernel { public typealias Descriptor = POSIX.Kernel.Descriptor }
extension Kernel { public typealias Process = POSIX.Kernel.Process }
extension Kernel.Process { public typealias ID = POSIX.Kernel.Process.ID }
extension Kernel { public typealias Directory = POSIX.Kernel.Directory }
extension Kernel.Directory { public typealias Entry = POSIX.Kernel.Directory.Entry }
extension Kernel { public typealias Termios = POSIX.Kernel.Termios }
extension Kernel { public typealias Socket = POSIX.Kernel.Socket }
extension Kernel.Socket { public typealias Descriptor = POSIX.Kernel.Socket.Descriptor }
extension Kernel { public typealias Close = POSIX.Kernel.Close }
extension Kernel.Close { public typealias Error = POSIX.Kernel.Close.Error }
// ... family-error nested chains
#elseif os(Windows)
extension Kernel { public typealias Descriptor = Windows.Kernel.Descriptor }
// ... Windows mirrors
#endif

// Domain-package re-exports (Bucket C destinations swift-kernel surfaces)
@_exported public import Time_Primitives        // Kernel.Time → Instant
@_exported public import Memory_Primitives      // Kernel.Memory.Address → Memory.Address
@_exported public import Random_Primitives      // Kernel.Random → Random
// ... domain primitives that swift-kernel surfaces under cross-platform names
```

The compiler probe at swift-kernel-primitives `f14cf8f` / `acc42e5`
verified the typealias resolution mechanism GREEN 8/8. The same mechanism
extends per Path X to all five family heads (Descriptor, Process.ID,
Directory.Entry, Termios, Socket.Descriptor) plus their nested error
chains.

## 5. Phasing proposal

The migration decomposes into Cycle 0 (substrate hookup, smallest), per-target
cycles (Cycle 1-N), and a final cycle deleting swift-kernel-primitives.

### 5.1 Cycle 0 — Transit-module decoupling (substrate-only; v1.1.0 reframe)

**Scope (v1.1.0)**: Decouple the L1 Kernel_Descriptor_Primitives from the 4
transit modules that previously transitively re-exported it
(Kernel_Completion_Primitives, Kernel_Event_Primitives,
Kernel_File_Primitives, Kernel_Socket_Primitives). This prepares Cycle 20
to land the typealias chain atomically with L1 deletion. **No typealias
landing in Cycle 0** — see "v1.0.0 → v1.1.0 reframe" below.

**Actual deliverable** (committed at swift-kernel-primitives `da8fc77`,
pushed 2026-04-27):

| Action | Count | Files |
|---|---:|---|
| Drop `@_exported public import Kernel_Descriptor_Primitives` from 4 transit modules' exports.swift | 4 | Kernel Completion / Event / File / Socket Primitives |
| Restore Kernel_Error_Primitives + Kernel_IO_Primitives @_exported on Kernel_Event_Primitives + Kernel_Completion_Primitives (previously transit through Kernel_Descriptor_Primitives' own re-export chain) | 2 | Same files as above |
| Add explicit `public import Kernel_Descriptor_Primitives` to internal source files using L1 Kernel.Descriptor in public API | 22 | Across the 4 modules + Kernel.File.Handle.Error.swift |
| Add explicit `import Kernel_Descriptor_Primitives` (or `@_spi(Syscall) import` for SPI access) to test files | 13 | Across Tests/Kernel * Primitives Tests |
| **Total file changes** | **39** | |

**Cost**: actual. 1 commit (`da8fc77`). 1 session.

**Gate to Cycle 1**: swift-kernel-primitives builds green; the 4 transit
modules no longer propagate L1 Kernel.Descriptor visibility through their
re-export chain. (L1 visibility persists via these modules' source files'
own `public import Kernel_Descriptor_Primitives` for public API
references — necessarily, until Cycle 20 deletes the L1 type.)

**v1.0.0 → v1.1.0 reframe — empirical L1 visibility finding**

The original v1.0.0 § 5.1 specified Cycle 0 as "wire the swift-kernel
L3-unifier typealias chain for the Descriptor + Close families." Empirical
attempt during Cycle 0 execution surfaced that the typealias chain cannot
land before Cycle 20 (L1 deletion):

- The intended typealias `extension Kernel { public typealias Descriptor =
  POSIX.Kernel.Descriptor }` collides with the L1 `struct Kernel.Descriptor`
  that's still alive in swift-kernel-primitives.
- After decoupling the 4 transit modules' `@_exported public import
  Kernel_Descriptor_Primitives` (the apparent leak path), the collision
  persists via a deeper structural channel: L1 `Kernel_File_Primitives`
  has public APIs that **reference L1 nested error types** as associated
  values — e.g., `extension Kernel.File.Open { public enum Error { case
  handle(Kernel.Descriptor.Validity.Error) } }`.
- For these public-API references to compile, the source files must
  `public import Kernel_Descriptor_Primitives` (a non-public import is
  insufficient because the public Error case associated value type
  must be at least as public as the Error type itself).
- Under Swift 6.x's `MemberImportVisibility`, `public import X` in a
  source file referenced by a module's public API propagates X to
  consumers of that module — the leak path is structurally inseparable
  from the module's public API surface.
- Result: as long as Kernel_Descriptor_Primitives provides the
  authoritative Kernel.Descriptor.Validity.Error type referenced in
  Kernel_File_Primitives' public API cases, L1 Kernel.Descriptor
  reaches the swift-kernel umbrella unavoidably.

**Resolution**: defer the typealias chain landing to Cycle 20 (formerly
Cycle 20: "Kernel Descriptor Primitives" target deletion). At Cycle 20,
the L1 type is deleted in the same commit as the typealias chain lands
— the collision is impossible because L1 doesn't exist post-commit.
Cycle 0's role becomes preparing the ecosystem for that atomic swap:
the 4 transit-module decoupling reduces the surface where L1 must
remain visible until Cycle 20.

**The compiler probe at swift-kernel-primitives commits `f14cf8f` /
`acc42e5` already validated the typealias mechanism mechanically (GREEN
8/8 for ~Copyable typealias resolution).** Cycle 0's value was
production-validation; the production validation requires L1 deletion
to resolve the collision, so it cannot precede Cycle 20.

### 5.2 Cycle 1 — ELIMINATED (v1.2.0 reframe)

**Status (v1.2.0)**: ELIMINATED. The original v1.0.0 § 5.2 specified Cycle 1
as "move `enum Kernel {}` from swift-kernel-primitives to swift-kernel L3."
This is **structurally impossible** mid-transition:

- Two `enum Kernel {}` declarations in different modules (L1
  Kernel_Namespace and swift-kernel L3) would be **distinct types** —
  Swift's type identity is module-scoped. They would collide whenever
  both modules are visible to a single compilation unit (which the
  swift-kernel umbrella always is).
- L1 importing from swift-kernel L3 to typealias-redirect would violate
  [PLAT-ARCH-007] / [ARCH-LAYER-001] layering (L1 cannot depend on L3).
- There is no "move and coexist" path — the namespace anchor must live
  at exactly one module, and the transfer must be atomic with L1
  package deletion.

**Empirical probe**: the existing `Kernel.Failure` declaration at
`swift-kernel/Sources/Kernel Core/Kernel.Failure.swift:12`
(`extension Kernel { public enum Failure: Swift.Error, ... }`) IS in
production today. swift-kernel L3 extends the L1-declared `Kernel`
namespace via the existing `@_exported public import Kernel_Core` →
`@_exported public import Kernel_Primitives_Core` →
`@_exported public import Kernel_Namespace` chain. Per-target Bucket B/C
cycles use this pattern: declare `extension Kernel { public enum X { ... } }`
at the new home module while the Kernel namespace continues to come
from L1 via re-export. No namespace relocation needed for Cycles 1-N
to work.

**Resolution**: skip Cycle 1. The namespace anchor stays at L1 throughout
the migration. The Final cycle absorbs `enum Kernel {}` declaration at
swift-kernel L3 atomically with L1 package deletion (see § 5.4 expanded
scope).

**Numbering impact**: v1.1.0's Cycle 2 → v1.2.0's Cycle 1. All subsequent
v1.1.0 Cycles N → v1.2.0 Cycles N-1.

### 5.3 Cycles 1-N — Per-target relocation (v1.2.0 renumbering)

Each cycle relocates one L1 target to its destination, in priority order.
Order considerations: smallest blast radius first; targets blocking many
others first; substrate-already-done targets first.

**Recommended order** (with rationale):

| Cycle | Target | Bucket | Destination | Blast radius (consumers) | Rationale |
|---|---|:---:|---|:---:|---|
| 1 | Kernel Error Primitives | B | swift-kernel | 233 | High blast radius but uniform shape; fast to migrate. Provides Kernel.Error to all subsequent cycles. (Was Cycle 2 in v1.1.0.) |
| 2 | Kernel IO Primitives | B | swift-kernel | (subsumed under Error) | Tiny. Co-locates with Error. |
| 3 | Kernel Outcome Primitives | B | swift-kernel | Low | Tiny. Foundation type. |
| 4 | Kernel Syscall Primitives | B | swift-kernel | Low | Tiny. Foundation type. |
| 5 | Kernel Primitives Core | B | swift-kernel | 146 | High blast radius, uniform Coordinate types. The Kernel.Memory namespace shell goes to swift-kernel; Memory substantive types defer to Cycle 10. |
| 6 | Kernel Time Primitives | C | swift-time-primitives | Low | Tiny. Existing destination. |
| 7 | Kernel Random Primitives | C | swift-random-primitives | Low | Tiny. Existing destination. |
| 8 | Kernel Path Primitives | C | swift-path-primitives | Low | Tiny. Tagged typealias collapses. |
| 9 | Kernel String Primitives | C | swift-string-primitives | Low | Tiny. Same shape as Path. |
| 10 | Kernel Memory Primitives | C | swift-memory-primitives | 87 | Substantial. Uniform Memory family. Existing destination. |
| 11 | Kernel Clock Primitives | C | swift-clock-primitives | Low | Existing destination. |
| 12 | Kernel System Primitives | C | swift-system-primitives | Low | Existing destination. |
| 13 | Kernel Environment Primitives | C | swift-environment-primitives (NEW) | Low | Decision: new package or absorb into swift-environment L3. Recommend NEW (env vocabulary is primitive-class). |
| 14 | Kernel Glob Primitives | C | swift-glob-primitives (NEW) | Low | Create new package. POSIX glob is self-contained. |
| 15 | Kernel Permission Primitives | C | swift-permission-primitives (NEW) | Low | Create new package OR fold into Bucket C's swift-file-system-primitives. |
| 16 | Kernel Thread Primitives | C | swift-thread-primitives (NEW) or swift-threads L3 | Low | Decision: thread-domain primitives package or move uniform pieces to swift-threads L3. |
| 17 | Kernel Event Primitives | A+C hybrid | Event.ID → L3-policy; rest → swift-event-primitives (NEW) | Low | Hybrid: Event.ID is divergent (eventfd vs kqueue), Event namespace + Driver + Source uniform. |
| 18 | Kernel File Primitives | A+C+D hybrid | Directory.Entry / File.Direct / File.Rename / File.System.Kind → L3-policy; uniform residual → swift-file-system-primitives (NEW) | 256 | Largest cycle. Sub-divides into multiple sub-cycles by syscall family. |
| 19 | Kernel Descriptor Primitives | A | swift-posix + swift-windows | 535 | Substrate already at scaffolding (8 commits) + Cycle 0 transit-module decoupling (`da8fc77`). Per v1.1.0 reframe, this cycle ALSO lands the swift-kernel L3-unifier typealias chain atomically with L1 deletion (deferred from Cycle 0). The Descriptor + Close family typealiases (`extension Kernel { public typealias Descriptor = POSIX.Kernel.Descriptor }` and Windows mirror) land in the SAME commit as the L1 target deletion — the collision the v1.0.0 § 5.1 hit cannot recur because L1 Kernel.Descriptor doesn't exist post-commit. The 535 ecosystem consumers redirect from `import Kernel_Descriptor_Primitives` to `import Kernel` (which sees the typealias). See § 5.3.1 for the atomic-swap mechanic. (Was Cycle 20 in v1.1.0.) |
| 20 | Kernel Process Primitives | A | swift-posix + swift-windows | 108 | Per cascade B.5 design. |
| 21 | Kernel Socket Primitives | A | swift-posix + swift-windows | 58 | Same shape as Descriptor. |
| 22 | Kernel Terminal Primitives | A | swift-posix (POSIX-only — Windows console is separate) | Low | Termios is opaque storage, platform-specific. |
| 23 | Kernel Completion Primitives | A | swift-linux exclusively | Low | io_uring is Linux-only. |

**Cycle count**: 23 per-target cycles + Cycle 0 + final cycle = 25 cycles
total. v1.0.0 / v1.1.0's Cycle 1 (namespace anchor relocation) is
ELIMINATED per v1.2.0 § 5.2; the namespace anchor relocates atomically
with L1 deletion at the Final cycle. Estimated 25-40 commits across the
cycles (per [HANDOFF-019] commit-as-you-go). Sessions: 12-20 sessions
estimated.

**Per-target migration shape** (applies uniformly to Cycles 1-23):

Each cycle's target relocates by following pattern:

1. New home module (swift-kernel L3 for Bucket B; domain primitives
   package for Bucket C; swift-posix/swift-windows/swift-linux/swift-darwin
   for Bucket A) declares `extension Kernel { public enum X { ... } }`
   (or equivalent for the type being relocated). The `Kernel` namespace
   continues to come from L1 via the existing `@_exported public import
   Kernel_Core → ... → Kernel_Namespace` chain in swift-kernel L3.
   For domain-package destinations, the destination package adds
   swift-kernel as a target dep so Kernel namespace is reachable.
2. swift-kernel-primitives' L1 target for the migrated type either
   (a) deletes if the migration is complete and 0 consumers remain,
   or (b) stays in place transitionally as a forwarding shim until
   later cycles clear consumers. Default: stay in place; deletion
   batches at the Final cycle.
3. Consumer migration: ecosystem files redirect `import Kernel_X_Primitives`
   to `import Kernel` (or the new domain package's import). Per-package
   commits per [HANDOFF-019] commit-as-you-go.
4. Build-verify per [PLAT-ARCH-008f]; gate to next cycle on
   ecosystem-wide green.

The Kernel.Failure pattern at `swift-kernel/Sources/Kernel Core/Kernel.Failure.swift`
is the canonical worked-example template — `extension Kernel { public enum
Failure { ... } }` declared at swift-kernel L3, Kernel namespace coming from L1
via re-export. This is the SAME shape every Bucket B/C/A cycle uses.

### 5.3.1 Cycle 19 atomic-swap mechanic (v1.1.0 absorption, renumbered v1.2.0)

Per the v1.1.0 reframe (see § 5.1), Cycle 19 (was Cycle 20 in v1.1.0)
absorbs the typealias chain landing that v1.0.0 had assigned to Cycle 0.
Cycle 19's commit shape must be atomic — L1 deletion + typealias chain
land in the SAME commit (or commit pair across swift-kernel-primitives
+ swift-kernel) so no intermediate state exposes the collision.

**Atomic-swap commits** (single dispatch):

| Commit | Repo | Content |
|---|---|---|
| 19.A | swift-kernel-primitives | Delete `Sources/Kernel Descriptor Primitives/` directory entirely (and its `Tests/` mirror) |
| 19.B | swift-foundations/swift-kernel | Edit `Sources/Kernel/Exports.swift`: add `@_exported public import POSIX_Kernel_Descriptor` (POSIX gate) + `Windows_Kernel_Descriptor` (Windows gate) + the typealias chain for Descriptor + Close families. Edit `Sources/Kernel Core/exports.swift`: remove `@_exported public import Kernel_Descriptor_Primitives` (target dep can stay or drop with consumer-redirect commit). Edit `Package.swift`: add POSIX Kernel Descriptor + Windows Kernel Descriptor as Kernel umbrella target deps per [PATTERN-004]. Edit `Sources/Kernel Core/Kernel.Failure.swift`: drop the (now-stale) `internal import Kernel_Descriptor_Primitives` since L1 is gone — the Failure type's `.handle` case associated value redirects to the typealiased L3-policy type. |
| 19.C | swift-foundations/swift-kernel + swift-iso-9945 + 4 L2 standards + swift-posix + swift-windows + swift-linux + swift-darwin + swift-foundations consumers | Consumer migration: 535 ecosystem references to L1 `Kernel.Descriptor` (and nested types) redirect from `import Kernel_Descriptor_Primitives` to `import Kernel` (or `import POSIX_Kernel_Descriptor` / `import Windows_Kernel_Descriptor` for raw access). Per-package commits per [HANDOFF-019]. |

**Sequencing within Cycle 19**:

- 19.A and 19.B MUST land together (or in immediate succession with a
  hold gate). If 19.A lands without 19.B, the umbrella module loses
  Kernel.Descriptor entirely — every consumer breaks. If 19.B lands
  without 19.A, the typealias collides with L1 (the v1.0.0 § 5.1
  failure mode).
- 19.C is the consumer migration sweep. Per-package commits ride after
  19.A + 19.B. Each consumer package's update is mechanical (import
  redirect).

**Cycle 19 cost**: medium. ~3-5 commits in 19.A + 19.B (the atomic
swap); ~10-15 commits in 19.C (consumer migration sweep, per-package).
2-3 sessions total.

**Gate to Cycle 20+**: ecosystem-wide `swift build` green; cross-platform
`Kernel.Descriptor` resolves to POSIX.Kernel.Descriptor on POSIX, Windows
mirror on Windows; no `import Kernel_Descriptor_Primitives` remaining
in consumer code (the kernel-primitives package's Descriptor target is
deleted, so the import would fail-build anyway).

### 5.4 Final cycle — Delete swift-kernel-primitives + atomic namespace anchor declaration (v1.2.0 expanded scope)

**Scope (v1.2.0)**: After Cycles 0-23 land, swift-kernel-primitives' `Sources/`
directory is empty except for the `Kernel Namespace` target (containing
`enum Kernel {}`). The Final cycle absorbs three coordinated commits:

| Commit | Content |
|---|---|
| F.A | swift-foundations/swift-kernel: declare `public enum Kernel {}` at L3 (new file `swift-kernel/Sources/Kernel/Kernel.swift` or absorbed into existing Kernel Core target). Per the v1.2.0 reframe (§ 5.2), this declaration cannot land before L1 deletion; it lands here atomically. |
| F.B | swift-kernel-primitives: delete the entire `Sources/Kernel Namespace/` directory + any remaining stub targets. The `enum Kernel {}` declaration that swift-kernel-primitives owned is gone. The L3 declaration from F.A becomes the canonical home. |
| F.C | All consumer packages: remove `swift-kernel-primitives` package dependencies from every downstream `Package.swift` (10+ packages: swift-iso-9945, the four L2 standards, swift-posix, swift-windows, swift-linux, swift-darwin, swift-kernel, swift-foundations consumer packages, swift-strings, swift-paths, etc.). Any residual `import Kernel_Namespace` (or `import Kernel_X_Primitives` for L1 targets that should already be gone via prior cycles) redirects to `import Kernel` per the L3-unifier facade. |

**Atomic-swap requirement** (analogous to Cycle 19's mechanic):

- F.A and F.B MUST land together. If F.A lands without F.B, two `enum
  Kernel {}` declarations coexist (L1 + L3), creating the same collision
  v1.2.0 § 5.2 documented. If F.B lands without F.A, the L3 module
  has no Kernel namespace — consumers depending on it break.
- F.C rides after F.A + F.B. Per-package commits per [HANDOFF-019]
  commit-as-you-go.

**Cost**: medium. ~3-5 commits for F.A + F.B (atomic swap); ~10-15
commits for F.C (Package.swift cleanup sweep). 2-3 sessions.

**Gate**: ecosystem-wide `swift build` green on all consumer packages
with the updated Package.swifts. The swift-kernel-primitives repo
itself can be archived (kept on origin as historical artifact) or
deleted from the swift-primitives org.

**Why namespace anchor relocates here, not earlier** (per v1.2.0 § 5.2
elimination of v1.0.0's Cycle 1): the Kernel namespace declaration must
live at exactly one module. While L1 is alive (Cycles 0-23 active),
swift-kernel-primitives' `Kernel_Namespace` is the canonical home;
swift-kernel L3 reaches it via `@_exported public import Kernel_Core`
→ `Kernel_Primitives_Core` → `Kernel_Namespace`. When L1 deletion
becomes possible (all kernel-primitives targets migrated or empty),
the namespace anchor moves atomically with the package's deletion.

### 5.5 Total revised cost (Path X — v1.2.0)

| Cycle group | Files modified | Commits | Sessions |
|---|---:|---:|---:|
| Cycle 0 (transit-module decoupling — v1.1.0; LANDED at `da8fc77`) | 39 | 1 | 1 |
| ~~Cycle 1 (namespace anchor)~~ | — | — | — |
| Cycles 1-18 (Bucket B + C, 18 targets — was 2-19 in v1.1.0) | ~150 | ~18-25 | ~8-12 |
| Cycle 19 (Descriptor target deletion + atomic typealias-chain landing — was 20) | ~15 + 535 consumer redirects | ~13-20 | 2-3 |
| Cycles 20-23 (Bucket A remainder: Process / Socket / Terminal / Completion — was 21-24) | ~135 | ~8-12 | ~3-5 |
| Final cycle (delete kernel-primitives + namespace-anchor atomic swap + Package.swift cleanup) | ~15 + namespace declaration | ~6-10 | 1-2 |
| **Total** | **~890** | **~46-68** | **~16-24** |

v1.2.0 numbering: Cycle 1 (namespace anchor) is eliminated per § 5.2;
v1.1.0's Cycles 2-24 renumber down by 1 to v1.2.0's Cycles 1-23. The
Final cycle's scope expands to include the `enum Kernel {}` atomic
declaration at swift-kernel L3 (§ 5.4). Total file-modified count
unchanged from v1.1.0 (~890); commit count slightly reduced (Cycle 1's
1-2 commits eliminated, Final cycle's adds 1-2 — net wash).

The Cycle 19 (was Cycle 20 in v1.1.0) line absorbs the typealias-chain
landing that v1.0.0 had assigned to Cycle 0, plus the 535-site consumer
migration that v1.0.0 had assigned to the Final cycle. v1.1.0 kept the
Final cycle as the package deletion + Package.swift cleanup; v1.2.0
expands the Final cycle to also include the namespace anchor declaration.

This compares to the cascade RECOMMENDATION's ~158-file estimate. Path X is
**larger in scope** because it migrates ALL 24 L1 targets (not just the
Descriptor + Process + Directory.Entry cascade), but it produces a more
defensible end-state (no L1 kernel-primitives package; domain-coherent
primitive packages for uniform vocabulary).

## 6. Consumer-impact analysis (per [HANDOFF-013b])

### 6.1 Build-level visibility

After Path X completes, every consumer that currently imports any
`Kernel_X_Primitives` module will need its import statement redirected.
The redirect destination depends on the consumer's needs:

- **Most consumers** (per cascade [HANDOFF-l1-exception-removal-execution.md]
  Phase 4 inventory: ~183 consumers for descriptor migration alone):
  switch from `import Kernel_Descriptor_Primitives` to `import Kernel`
  (the L3-unifier).
- **Standards / spec packages** (swift-iso-9945, etc.) that need raw
  syscall access via `@_spi(Syscall)`: switch L1 imports for the
  spec-implementation modules they re-export through.

Per [HANDOFF-013b], the build-level visibility check at each consumer site
is the precondition for cascade-deletion safety. Path X's per-cycle
verification (each target's deletion is its own cycle, with build-green
gates between cycles) bounds the visibility-failure surface to one target
at a time.

### 6.2 Largest blast-radius targets

| Target | Imports | Cycle | Blast-radius mitigation |
|---|---:|:---:|---|
| Kernel.Descriptor (Kernel_Descriptor_Primitives) | 535 | 20 | swift-kernel L3-unifier typealias chain (Cycle 0 hookup; Cycle 20 deletion safe after typealias proves cross-platform routing) |
| Kernel_File_Primitives | 256 | 19 | Largest single-cycle migration. Sub-divides by syscall family; each sub-cycle is its own commit-as-you-go |
| Kernel_Error_Primitives | 233 | 2 | High but uniform-shape; consumers redirect `import Kernel_Error_Primitives` → `import Kernel` |
| Kernel_Primitives_Core | 146 | 6 | Same shape — uniform consumers redirect to `import Kernel` |
| Kernel_Process_Primitives | 108 | 21 | Per cascade B.5 design |
| Kernel_Memory_Primitives | 87 | 11 | Redirect to `import Memory_Primitives` (or via `import Kernel` if swift-kernel re-exports) |
| Kernel_Socket_Primitives | 58 | 22 | Same shape as Descriptor |

### 6.3 Foundations-layer impact

Per supervisor `ask:` #4: any L1 type referenced in swift-foundations L3+
domain packages in ways that break under Path X.

**swift-foundations consumers verified** (sampled):

- `swift-file-system` — heavy consumer of Kernel.File.* family. Cycle 19
  blast-radius peak. Mitigation: file-system primitives package emerges
  from this cycle (Bucket C destination); swift-file-system consumes it
  cleanly.
- `swift-io` — consumer of Kernel.Descriptor + Kernel.IO + Kernel.Event
  + Kernel.Completion. Multiple cycles affect it. Mitigation: each
  cycle's `import Kernel` redirect handles it; no breaking shape
  changes.
- `swift-kernel` (L3 itself) — its current re-export chain is the
  redirect target. Path X amends Exports.swift (per § 4.2) to
  re-route imports.
- `swift-darwin` / `swift-linux` / `swift-windows` — L3-policy
  packages that absorb Bucket A targets. They receive the migrated
  types (already started for Descriptor via scaffolding).

**No foundations-layer break surfaced** beyond the known import-redirect
pattern. The blast radius is import-line edits, not API shape changes.

## 7. Risk surface

### 7.1 Concurrent session collisions

The 6 already-pushed scaffolding commits + 2 Cycle A β-rescue commits are
on origin and visible to concurrent sessions. Path X doesn't conflict with
that substrate. The cascade investigation Research doc remains in place
(SUPERSEDED, not deleted) so concurrent sessions reading it find the
supersession marker.

### 7.2 Ecosystem rebuild surface

Path X's per-cycle commit-as-you-go cadence means no single rebuild surface
is the full 25-cycle scope. Each cycle's commit triggers rebuilds on
direct consumers; full ecosystem rebuilds happen at gate boundaries.

The largest single-cycle rebuild is Cycle 19 (Kernel File Primitives at
~256 imports). This is sub-divided per the per-syscall-family decomposition
within Cycle 19.

### 7.3 Naming collisions during transition

Per § 4.1: between Cycle 1 (namespace anchor relocation) and the per-target
cycles (which redirect their re-exports), the `Kernel` namespace exists at
both swift-kernel (Cycle 1) and swift-kernel-primitives (residual Kernel
Namespace target if not yet deleted). This double-declaration would break
the build.

**Mitigation**: Cycle 1's commit either deletes the kernel-primitives
Kernel Namespace target in the same commit OR gates it behind a
`#if !KERNEL_AVAILABLE` guard so it inactivates when the L3 declaration
appears. The simpler path is delete-in-same-commit; the kernel-primitives
target's value (single line `enum Kernel {}`) doesn't merit a deprecation
window.

### 7.4 Parallel session L3 sub-tier framing

The `lateral-l3-to-l3-composition-options.md` STAMPED 2026-04-26 design
(Hybrid B+C; swift-posix L3-policy; swift-kernel L3-unifier; swift-darwin
/ linux / windows L3-policy) holds unchanged under Path X. Path X
**clarifies** L1's role (no kernel-primitives bucket) without amending L3.
[PLAT-ARCH-008h] / [PLAT-ARCH-008i] sub-tier rules continue to apply.

### 7.5 Bucket C package creation surface

3 new domain-primitives packages need creation:

- swift-glob-primitives (POSIX glob)
- swift-permission-primitives (POSIX file permissions) — alternatively,
  fold into swift-file-system-primitives
- swift-file-system-primitives (the largest residual from Kernel File)

Plus possibly swift-environment-primitives (or absorb into swift-environment
L3) and swift-thread-primitives (or absorb into swift-threads L3).

Each new package requires its own naming + tier + scope decision. Per
[RES-018] (premature primitive anti-pattern), each new package needs a
"why not compose existing primitives" section + a "second consumer" check.
For the kernel-residual packages, the second-consumer is automatic (the
ecosystem currently uses these via kernel-primitives; the new packages
inherit those consumers).

### 7.6 Path Y consideration — addressed in § 3.3

Per supervisor `ask:` #1: the genuinely-uniform set is large (~140-160
types across 19 targets). The trigger fired. Per § 3.3's analysis,
**Path X remains correct**: the uniform set's empirical destinations are
mostly existing domain-primitive packages, NOT a single kernel-residual
bucket. Path Y (keep swift-kernel-primitives in some reduced form) would
re-create a heterogeneous bucket — the very defect Path X removes.

**Stamped recommendation**: proceed with Path X.

## 8. RECOMMENDATION

**Status**: RECOMMENDATION.

**Selected path**: **Path X — remove swift-kernel-primitives entirely**.

**Implementation summary**:

- Cycle 0: hookup swift-kernel typealias chain over already-pushed
  scaffolding (1 file edit, 1 cycle, 1 session).
- Cycle 1: relocate `enum Kernel {}` namespace anchor to swift-kernel.
- Cycles 2-24: per-target migration ordered by blast radius + dependency,
  Bucket B (swift-kernel) first, then Bucket C (domain primitives), then
  Bucket A (L3-policy) which has substrate already started.
- Final cycle: delete swift-kernel-primitives + Package.swift cleanup.

Total: ~25 cycles, ~35-52 commits, ~15-22 sessions.

**Audit closure**:

- `swift-institute/Audits/swift-primitives-platform-code-inventory.md`
  items 1, 2, 7 (currently `OPEN — IN MIGRATION` linked to cascade
  investigation): re-link to this Path X RECOMMENDATION; CLOSE on final
  cycle completion.
- The Path X migration likely affects additional audit items beyond 1, 2, 7
  (the entire kernel-primitives surface). A sweep is recommended at audit
  level after this RECOMMENDATION lands.

**Skill-text closure**:

- `swift-institute/Skills/platform/SKILL.md` — [PLAT-ARCH-005] /
  [PLAT-ARCH-008c] / [PLAT-ARCH-015] revised text continues to be
  correct under Path X. Transition notes (`d535ec4`) need updating to
  point at this Path X RECOMMENDATION instead of the (now SUPERSEDED)
  cascade investigation. The revisions retire on final cycle completion.

**Cascade investigation supersession**:

- `l1-types-only-no-exceptions-l2-cascade.md` v2.0.1 RECOMMENDATION
  marked SUPERSEDED per [META-003] in this RECOMMENDATION's commit.
  Document preserved as historical context per [HANDOFF-018] —
  question-answer chain showing the L1-stays premise's investigation
  arc.

## 9. Cross-references

- **Parent**: `l1-types-only-no-exceptions.md` v1.1.1 RECOMMENDATION
  (commit `0666a59`, this repo) — original L1 exception removal,
  authorized via L3 typealias chain.
- **Superseded predecessor**:
  `l1-types-only-no-exceptions-l2-cascade.md` v2.0.1 RECOMMENDATION
  (commit `3089a62`, this repo) — cascade investigation under L1-stays
  premise. SUPERSEDED 2026-04-27 by this Path X RECOMMENDATION per
  [META-003].
- **Within-L3 sub-tier framework** (load-bearing per supervisor MUST):
  `swift-institute/Research/lateral-l3-to-l3-composition-options.md`
  STAMPED 2026-04-26 — Hybrid B+C; swift-posix L3-policy; swift-kernel
  L3-unifier. Path X operates within this framework unchanged.
- **Migration handoff** (parent migration cycle):
  `HANDOFF-l1-exception-removal-execution.md` — Phase 0 findings +
  § Findings — DEFERRED close. Phase 4 inventory (183 import sites)
  carries forward to Path X's per-cycle consumer-redirect work.
- **Path X dispatch handoff** (this RECOMMENDATION's authoring brief):
  `HANDOFF-l1-kernel-primitives-removal-plan.md`.
- **Cycle A β-rescue handoff** (the cascade-era partial work):
  `HANDOFF-cascade-cycle-a-execution.md` § Cycle A close — 2 L3-policy
  add commits (swift-posix `f5594a0` + swift-windows `653b50b`) carry
  forward as Path X substrate.
- **Compiler probe** (typealias mechanism, GREEN 8/8):
  swift-kernel-primitives commits `f14cf8f` / `acc42e5`.
- **Substrate commits** (8 total, all pushed):
  - swift-iso-9945: `b5c0f5f` + `871d2c0` (L2 raw close)
  - swift-foundations/swift-posix: `3357fb5` + `50e7019` (L3-policy
    POSIX descriptor type + family)
  - swift-microsoft/swift-windows-standard: `1be7df4` (L2 split worked
    example)
  - swift-foundations/swift-windows: `71e1bbd` (L3-policy Windows
    descriptor + family)
  - swift-foundations/swift-posix: `f5594a0` (Cycle A β-rescue —
    POSIX error+code mappers)
  - swift-foundations/swift-windows: `653b50b` (Cycle A β-rescue —
    Windows error+code mappers)
- **Skill rules** (revised; correct under Path X):
  `swift-institute/Skills/platform/SKILL.md` — [PLAT-ARCH-005] revised,
  [PLAT-ARCH-008c] strengthened, [PLAT-ARCH-015] augmented. Transition
  notes (`d535ec4`) update to re-link from cascade investigation to
  this Path X RECOMMENDATION.
- **Audit items** (status: OPEN — IN MIGRATION):
  `swift-institute/Audits/swift-primitives-platform-code-inventory.md`
  items 1, 2, 7. CLOSE on Path X final cycle completion.
