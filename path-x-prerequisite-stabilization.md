# Path X prerequisite stabilization

<!--
---
version: 1.0.0
last_updated: 2026-04-27
status: RECOMMENDATION
parent: ../../swift-primitives/swift-kernel-primitives/Research/path-x-removal-plan.md
gates: ../../swift-primitives/swift-kernel-primitives/Research/path-x-removal-plan.md
---
-->

## Abstract

Path X (`swift-primitives/swift-kernel-primitives/Research/path-x-removal-plan.md`
v1.2.0 RECOMMENDATION at commit `4a49837`) commits to removing
swift-kernel-primitives entirely. Per-target migration cycles (Cycles 1-23)
each face the same boundary issue in different shapes: L2 spec packages
take typed L1 primitives (`borrowing Kernel.Descriptor`,
`Kernel.Process.ID`, etc.) in their public API. While L1 hosts the typed
primitive AND L2 references it, individual L1 target deletion is
gated on coordinated L2 + L3-policy changes per target.

The cascade investigation
(`swift-primitives/swift-kernel-primitives/Research/l1-types-only-no-exceptions-l2-cascade.md`
v2.0.2 SUPERSEDED) was the right diagnosis of this boundary issue but
framed as alternative-to-Path-X. **It is actually
prerequisite-to-Path-X**: the same L2-spec-wrapper refactor cascade
the investigation scoped is the work that must land before Path X
per-target cycles can dispatch mechanically.

This RECOMMENDATION coordinates that prerequisite stabilization as one
investigation:

1. **Sub-task A (per-cycle hygiene, not separate phase)** — L1
   ergonomic transit re-export cleanup. Cycle 0's `da8fc77` already
   covered the 4 transit modules forced by the Descriptor cascade.
   Remaining L1 module transit re-exports are mostly
   API-necessary (the imported module's types appear in the importing
   module's public API, e.g., Kernel_File_Primitives' Error cases
   reference Kernel.IO.Error). Per-cycle hygiene during Path X Cycles
   1-23 absorbs this work; no separate phase needed.
2. **Sub-task B — iso-9945 L2 self-sufficiency**. Refactor 31 Pattern
   A files in iso-9945 to take raw `Int32` (POSIX fd) instead of
   `borrowing Kernel.Descriptor`. Add corresponding L3-policy throwing
   wrappers in swift-posix that take typed POSIX.Kernel.Descriptor and
   compose the L2 raw call.
3. **Sub-task C — windows-standard L2 self-sufficiency**. Mirror
   shape with raw `UInt` (HANDLE). Refactor 13 Pattern A files in
   windows-standard. Add Windows L3-policy wrappers in swift-windows.
4. **Bonus — Linux + Darwin extras**. The Linux dup3 (deferred from
   Cycle A as Pattern A+B hybrid) plus Darwin Event.Queue (kqueue)
   plus linux-standard's 11 Pattern A files plus darwin-standard's 3
   Pattern A files all relocate similarly. Adds ~14 sites to the
   total scope.

After sub-tasks B + C (+ bonus) land cleanly, Path X Cycles 1-23
execute mechanically because L2 no longer references L1 typed
primitives. Cycle 19 (Descriptor target deletion + atomic typealias
landing per Path X v1.2.0 § 5.3.1) becomes trivial — no L2
references to redirect.

## 1. Context

### 1.1 Why prerequisite, not alternative

Path X v1.2.0 commits to deleting swift-kernel-primitives entirely.
The cascade investigation v2.0.2 SUPERSEDED scoped a similar refactor
(L2-takes-raw + L3-policy-wraps) but framed it as Path 1 of an
alternative resolution to the L1 exception. Path X's stamp on
2026-04-27 redirected: not "resolve the L1 exception via cascade" but
"delete L1 entirely; the cascade refactor is one of the prerequisites."

The cascade investigation's empirical work (Pattern A enumeration,
Cycle B sub-cycle decomposition, worked-example template at
`1be7df4` / `50e7019` / `71e1bbd`) carries forward unchanged. This
RECOMMENDATION re-cites it as the diagnosis pointing at Path X
prerequisite work, then absorbs the execution dispatch shape per
[HANDOFF-019] commit-as-you-go.

### 1.2 The recurring under-scoping pattern

The "boundary issue" between L1 and L2 has surfaced four times under
different framings:

| Framing | Where | Failure mode |
|---|---|---|
| Original migration § 7 | `l1-types-only-no-exceptions.md` | Framed migration as 146 mechanical SPI updates; under-counted L2 typed-parameter sites |
| Cascade investigation | `l1-types-only-no-exceptions-l2-cascade.md` | Re-derived as 200+-file cascade; further refined to 71 typed-parameter sites in v2.0.2 § 3.7 |
| Path X Cycle 0 attempt | `path-x-removal-plan.md` v1.0.0 § 5.1 | Typealias collision via Kernel_File_Primitives' public API references — discovered at execution time |
| Path X Cycle 1 attempt | `path-x-removal-plan.md` v1.0.0 § 5.2 | Namespace-anchor relocation structurally impossible mid-transition |

Each surface re-discovers that L1 / L2 / L3-policy boundaries are not
independent — work at any one boundary forces coordination at the
other two. Dispatching architectural work without acknowledging the
coupling produces an under-scoped plan that fails at execution time.

This RECOMMENDATION's value: stabilize the boundaries first so Path X
per-target cycles dispatch from a clean baseline.

## 2. Empirical Census (re-verified 2026-04-27 per [HANDOFF-024])

### 2.1 Sub-task A — L1 transit re-export inventory

**Enumeration** (across 24 L1 modules in
`swift-kernel-primitives/Sources/`):

```bash
for f in /Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/*/exports.swift; do
  tgt=$(basename "$(dirname "$f")")
  echo "[$tgt]"
  grep "^@_exported" "$f" 2>/dev/null
done
```

**Per-module cross-Kernel transit re-exports** (excluding
`Kernel_Primitives_Core` which is universal — every L1 module needs
the namespace anchor + foundational primitives):

| L1 Module | Cross-Kernel transits | Notes |
|---|---:|---|
| Kernel Clock Primitives | 0 | Just Primitives_Core |
| Kernel Completion Primitives | 2 | Error + IO (Cycle 0 cleared Kernel_Descriptor; these remain) |
| Kernel Descriptor Primitives | 2 | Error + IO (foundational descriptor → error API surface) |
| Kernel Environment Primitives | 3 | Error + Memory + Permission |
| Kernel Error Primitives | 0 | Just Primitives_Core |
| Kernel Event Primitives | 4 | Error + IO + Clock + Time (Cycle 0 cleared Kernel_Descriptor) |
| Kernel File Primitives | 8 | Error + IO + Memory + Permission + Process + Time + System + Path (Cycle 0 cleared Kernel_Descriptor) |
| Kernel Glob Primitives | 0 | Just Primitives_Core |
| Kernel IO Primitives | 1 | Error |
| Kernel Memory Primitives | 1 | Error (+ non-Kernel System_Primitives) |
| Kernel Outcome Primitives | 0 | Just Primitives_Core |
| Kernel Path Primitives | 2 | Error + Permission (+ non-Kernel Path_Primitives) |
| Kernel Permission Primitives | 1 | Error |
| Kernel Primitives Core | 0 (foundational) | Re-exports Kernel_Namespace + non-Kernel primitives only |
| Kernel Process Primitives | 0 | Just Primitives_Core |
| Kernel Random Primitives | 1 | Error |
| Kernel Socket Primitives | 2 | Error + IO (Cycle 0 cleared Kernel_Descriptor) |
| Kernel String Primitives | 0 | Just Primitives_Core |
| Kernel Syscall Primitives | 0 | Just Primitives_Core |
| Kernel System Primitives | 0 | Just Primitives_Core (+ non-Kernel System_Primitives) |
| Kernel Terminal Primitives | 0 | Just Primitives_Core |
| Kernel Thread Primitives | 1 | Error |
| Kernel Time Primitives | 0 | Just Primitives_Core |
| **Total cross-Kernel transits** | **27** | (after Cycle 0's removal of 4 Kernel_Descriptor re-exports) |

**API-necessity audit**:

The 27 cross-Kernel transits split between two classes:

- **API-necessary** (the importing module's public API references the
  imported module's types). Examples:
  - Kernel_File_Primitives → Kernel_Error_Primitives: file errors
    contain `case io(Kernel.IO.Error)`, `case handle(Kernel.Descriptor.Validity.Error)`
    etc. The imported module's types appear in case associated values.
  - Kernel_IO_Primitives → Kernel_Error_Primitives:
    `Kernel.IO.Error` cases reference Kernel.Error.Code.
  - Kernel_Permission_Primitives → Kernel_Error_Primitives:
    `Kernel.Permission.Error` cases.
- **Ergonomic** (no public API reference; re-export was for
  consumer-side import convenience):
  - Kernel_Event_Primitives → Kernel_Clock_Primitives: Event types
    don't structurally need Clock; the re-export was for consumer
    ergonomics ("import Event_Primitives gets Clock too").
  - Kernel_File_Primitives → Kernel_Time_Primitives: File doesn't
    return Time; the re-export was ergonomic.

Per [HANDOFF-013b]'s methodology, distinguishing API-necessary from
ergonomic requires inspecting each module's public API against each
re-export. Empirical attempt (a sample of 5 modules) suggests
~70-80% of the 27 transits are API-necessary. The truly ergonomic
re-exports (~6-8 of 27) are the candidates for removal.

**Sub-task A scope**: ~6-8 ergonomic transit removals + corresponding
internal-file explicit imports. Estimated ~15-25 file edits across 5-7
exports.swift files + their internal source files.

**Per-cycle absorption**: rather than dispatching Sub-task A as a
separate phase, each Path X Cycle 1-23 includes pre-flight hygiene
that drops the deleting target's transit re-exports from sibling
modules. Cycle 0's `da8fc77` was the prototype; Cycles 1-23 each
include a small "drop our @_exported re-export from N sibling modules"
step. **This avoids treating Sub-task A as a separate big-bang
dispatch** and aligns the cleanup with the exact moment each target
becomes individually-deletable.

### 2.2 Sub-task B — iso-9945 L2 self-sufficiency

Cascade investigation v2.0.2 § 3.2 numbers re-verified 2026-04-27
(swift-iso-9945 unchanged since cascade): **31 Pattern A files** —
typed-parameter usage of `Kernel.Descriptor` in iso-9945's L2 spec
wrappers.

**Of which return-direction**: 4 files (`File.Open`, `Pipe`,
`Pipe.Close`, `Memory.Shared`, `Descriptor.Duplicate`). The L2 spec
wrappers currently RETURN a typed `Kernel.Descriptor` constructed from
the syscall's raw fd — Path X requires this construction to move to
L3-policy.

**Per-syscall-family breakdown**:

| Family | Files |
|---|---:|
| File | 17 |
| Socket | 6 |
| Terminal | 2 |
| Memory | 2 |
| Lock | 2 |
| Poll | 1 |
| Directory | 1 |
| **Total** | **31** |

**Refactor pattern** (worked example at `1be7df4` for close;
generalized in cascade investigation v2.0.2 § 5):

For each Pattern A file at iso-9945:
1. Change function signature from `borrowing Kernel.Descriptor` /
   `-> Kernel.Descriptor` to raw `Int32` parameter / `Int32` return.
2. Mark with `@_spi(Syscall)` to gate it as raw spec-literal access.
3. Body simplifies — no error mapping, no descriptor construction.
4. Add corresponding L3-policy throwing wrapper at swift-posix that:
   takes typed `POSIX.Kernel.Descriptor`, unwraps `_rawValue`, calls
   the L2 raw, maps errno to `POSIX.Kernel.X.Error`, optionally wraps
   return into typed `POSIX.Kernel.Descriptor`.

**Sub-task B scope**: 31 L2 file edits in iso-9945 + ~31 NEW
L3-policy wrapper files at swift-posix. Plus the Linux extras (11
files in linux-standard) and Darwin extras (3 files in darwin-standard)
absorb here as bonus scope (POSIX-shared base in swift-posix; Linux /
Darwin platform-specific extras in swift-linux / swift-darwin
respectively).

**Estimated cost**: ~50-70 file changes across 5 packages
(swift-iso-9945, swift-posix, swift-linux-standard, swift-linux,
swift-standards/swift-darwin-standard, swift-foundations/swift-darwin).
Per-syscall-family commits per [HANDOFF-019]; estimated 8-12 commits.
1-2 sessions.

### 2.3 Sub-task C — windows-standard L2 self-sufficiency

Cascade investigation v2.0.2 § 3.2 numbers re-verified: **13 Pattern A
files** — typed-parameter usage of `Kernel.Descriptor` in windows-standard.

**Of which return-direction**: 4 files (`File.Open`, `Pipe.Named`,
`IO.Completion.Port`, `Descriptor.Duplicate`).

**Per-syscall-family breakdown**:

| Family | Files |
|---|---:|
| File | 7 |
| IO Completion | 5 |
| Memory Map | 1 |
| **Total** | **13** |

**Refactor pattern** (mirror of Sub-task B with `UInt` instead of
`Int32`):

For each Pattern A file at windows-standard:
1. Change function signature from `borrowing Kernel.Descriptor` to
   `_ handle: UInt` (matching Win32 HANDLE bit pattern).
2. Mark `@_spi(Syscall)`. Body simplifies.
3. Add corresponding L3-policy throwing wrapper at swift-windows that:
   takes typed `Windows.Kernel.Descriptor`, unwraps `_raw`, calls L2
   raw, maps `GetLastError` to `Windows.Kernel.X.Error`.

**Sub-task C scope**: 13 L2 file edits in windows-standard + ~13 NEW
L3-policy wrapper files at swift-windows.

**Estimated cost**: ~26-30 file changes across 2 packages
(swift-windows-standard, swift-windows). Per-family commits;
estimated 4-6 commits. 1 session.

### 2.4 Total prerequisite stabilization scope

| Sub-task | Files modified | New L3-policy files | Commits | Sessions |
|---|---:|---:|---:|---:|
| A — L1 transit cleanup | (per-cycle hygiene; no separate phase) | — | (absorbed in Cycles 1-23) | (absorbed) |
| B — iso-9945 + linux-standard + darwin-standard L2 self-sufficiency + L3-policy wrappers | ~45 (31 iso-9945 + 11 linux-standard + 3 darwin-standard) | ~45 (swift-posix + swift-linux + swift-darwin) | 8-12 | 1-2 |
| C — windows-standard L2 self-sufficiency + Windows L3-policy wrappers | 13 | ~13 | 4-6 | 1 |
| **Total** | **~58 modified** | **~58 new** | **12-18** | **2-3** |

This is the scope of cascade investigation v2.0.2 Cycle B (sub-cycles
B.1-B.6) executed as Path X prerequisite. Cycle 0's β-rescue
substrate at swift-posix `f5594a0` + swift-windows `653b50b` (POSIX +
Windows Close.Error and Validity.Error code-mapping inits at
L3-policy) is on-Path-X and carries forward as the foundation for
sub-tasks B + C's L3-policy wrappers.

## 3. Phasing proposal

### 3.1 Phase 1 — POSIX (sub-task B) + Linux/Darwin extras

**Scope**: 45 file modifications + 45 new L3-policy wrappers.

**Sub-cycles** (per syscall family within iso-9945):

| Sub-cycle | Family | Files (L2 modify) | New L3-policy files |
|---|---|---:|---:|
| 1.1 | iso-9945 File (largest cluster) | 17 | ~17 |
| 1.2 | iso-9945 Socket | 6 | ~6 |
| 1.3 | iso-9945 Terminal | 2 | ~2 |
| 1.4 | iso-9945 Memory | 2 | ~2 |
| 1.5 | iso-9945 Lock | 2 | ~2 |
| 1.6 | iso-9945 Poll + Directory | 2 | ~2 |
| 1.7 | linux-standard extras (dup3 + io_uring + eventfd) | 11 | ~11 |
| 1.8 | darwin-standard extras (kqueue + Stats) | 3 | ~3 |

**Cross-platform consumer impact**: cross-platform code at swift-kernel
L3 currently consumes the iso-9945 typed-parameter wrappers. After
Phase 1, those L3 consumers redirect to swift-posix's L3-policy
typed wrappers (the L3-policy throwing wrapper IS the new public
API). The redirection is per-syscall-family; commits per
[HANDOFF-019] commit-as-you-go.

**Gate to Phase 2**: ecosystem-wide `swift build` green; cross-platform
descriptor-using code at swift-kernel L3 reaches the typed surface
via swift-posix's new wrappers.

### 3.2 Phase 2 — Windows (sub-task C)

**Scope**: 13 file modifications + 13 new L3-policy wrappers.

**Sub-cycles**:

| Sub-cycle | Family | Files | New L3-policy files |
|---|---|---:|---:|
| 2.1 | windows-standard File | 7 | ~7 |
| 2.2 | windows-standard IO Completion | 5 | ~5 |
| 2.3 | windows-standard Memory Map | 1 | ~1 |

**Gate to Path X Cycles 1-23**: ecosystem-wide build green;
swift-kernel L3 sees typed Descriptor APIs via both swift-posix and
swift-windows L3-policy.

### 3.3 Phase 3 — Path X Cycles 1-23 dispatch

After Phases 1 + 2 land:

- L2 spec wrappers across iso-9945 / windows-standard /
  linux-standard / darwin-standard contain ZERO typed L1 Kernel.Descriptor
  references in public APIs. They take raw Int32 / UInt at the syscall
  boundary.
- L3-policy at swift-posix / swift-windows / swift-linux / swift-darwin
  hosts the typed-descriptor throwing wrappers. The cross-platform name
  resolution awaits Cycle 19's atomic typealias swap.
- Path X Cycles 1-23 dispatch mechanically per
  `path-x-removal-plan.md` v1.2.0 § 5.3 (renumbered cycles).

**Cycle 19 simplifies**: no L2 references to redirect at Cycle 19's
atomic-swap moment. The L2 surface already speaks raw types; the L3-policy
typed wrappers are the canonical home. The atomic swap (delete L1
Kernel_Descriptor_Primitives + add typealias chain at swift-kernel L3)
becomes a clean atomic transaction without ecosystem rebuild churn.

## 4. Risk surface

### 4.1 The recurring under-scoping pattern recurring at Phase 1/2 dispatch

The exact failure mode this RECOMMENDATION exists to prevent:
dispatching Phase 1 or Phase 2 without empirical pre-scoping
re-verification. Mitigation: each phase's executor handoff per
[HANDOFF-024] re-runs the enumeration commands from § 2 fresh; no
trust in stale numbers.

### 4.2 Per-syscall-family scope variance

iso-9945 File family is 17 files — 55% of Phase 1's L2-modify scope
in one sub-cycle. Sub-cycle 1.1 dominates Phase 1; if it surfaces an
unexpected complication, cascading delays Phase 2. Mitigation:
sub-cycle 1.1's executor can split it further by syscall-class
(open, read/write, stat, control, etc.) per [HANDOFF-019] commit-as-you-go.

### 4.3 Cycle A β-rescue substrate compatibility

Cycle A β-rescue (swift-posix `f5594a0` + swift-windows `653b50b`)
landed POSIX/Windows Close.Error and Validity.Error code-mapping
inits at L3-policy. These are on-Path-X. Phase 1's swift-posix
L3-policy wrappers compose over these inits. **Verification needed
at Phase 1 dispatch**: confirm `POSIX.Kernel.Close.Error.init(code:)`
(landed at `f5594a0`) and `POSIX.Kernel.Descriptor.Validity.Error.init?(code:)`
(also `f5594a0`) are reachable from swift-posix's new L3-policy
wrappers without cross-target visibility issues.

### 4.4 Concurrent session collisions

The 6 cascade scaffolding commits + 2 Cycle A β-rescue commits +
Cycle 0's `da8fc77` are all on origin. No concurrent session
collisions expected. Phase 1 / Phase 2 dispatches add to the
cascade-substrate body of work; no commits to revert.

### 4.5 Linux dup3 hybrid (deferred from Cycle A)

The 2 Linux dup3 files (Pattern A+B hybrid; deferred per Option β)
absorb cleanly into Phase 1 sub-cycle 1.7. No special mechanism
needed — Phase 1's design (iso-9945 takes raw → swift-posix L3-policy
wraps; Linux extras add to swift-linux L3-policy) is the design Cycle
A β was waiting for. CLinuxKernelShim exposure question (whether to
make it a public library product) resolves naturally: swift-linux's
L3-policy module dep on `Linux Kernel Descriptor Standard` (L2)
provides the shim transitively for the L3-policy wrapper's needs.

## 5. RECOMMENDATION

**Status**: RECOMMENDATION.

**Selected path**: bundle Phase 1 + Phase 2 as the single
prerequisite-stabilization arc. Sub-task A (L1 transit cleanup)
absorbs into per-cycle hygiene during Path X Cycles 1-23; no separate
phase needed.

**Dispatch order**:

1. **Phase 1 — POSIX + Linux/Darwin extras** (sub-task B + bonus).
   Single dispatch, sub-cycles 1.1-1.8 per [HANDOFF-019] commit-as-you-go.
   Empirical pre-scoping per [HANDOFF-024] at dispatch time. 1-2
   sessions, 8-12 commits, ~90 file changes.
2. **Phase 2 — Windows** (sub-task C). Single dispatch, sub-cycles
   2.1-2.3. 1 session, 4-6 commits, ~26 file changes.
3. **Path X Cycles 1-23 dispatch** per `path-x-removal-plan.md` v1.2.0
   § 5.3 from the post-stabilization baseline.

**Coupling acknowledged**:

- Phase 1's iso-9945 refactor and swift-posix L3-policy wrapper
  additions MUST land together (or in immediate succession with hold
  gate). Iso-9945 raw-only signatures with no L3-policy to consume
  them break cross-platform consumers.
- Phase 2 mirrors with swift-windows.
- Phase 1 and Phase 2 are independent enough that Phase 2 can run in
  parallel with Phase 1's later sub-cycles if separate executor
  sessions take them.

**Path X RECOMMENDATION at swift-kernel-primitives `4a49837` (v1.2.0)**
stays committed as the destination plan. This RECOMMENDATION gates
Path X Cycles 1-23 on Phase 1 + Phase 2 completion.

## 6. Cross-references

- **Path X destination plan**:
  `/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Research/path-x-removal-plan.md`
  v1.2.0 RECOMMENDATION (commit `4a49837`).
- **Cascade investigation (SUPERSEDED, re-cited as diagnosis)**:
  `/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Research/l1-types-only-no-exceptions-l2-cascade.md`
  v2.0.2 SUPERSEDED. The cascade's empirical Pattern A enumeration
  (§ 3.2) and Cycle B sub-cycle decomposition (§ 4.2) carry forward
  to Phase 1 / Phase 2 sub-cycle structure here.
- **Within-L3 sub-tier framework**:
  `/Users/coen/Developer/swift-institute/Research/lateral-l3-to-l3-composition-options.md`
  STAMPED 2026-04-26. Path X prerequisite stabilization operates
  within this framework (Hybrid B+C; swift-posix L3-policy;
  swift-kernel L3-unifier).
- **Cycle 0 (LANDED)**:
  swift-kernel-primitives commit `da8fc77` — transit-module decoupling
  for the 4 Descriptor-cascade transit modules. Sub-task A's prototype.
- **Cycle A β-rescue substrate (LANDED)**:
  swift-foundations/swift-posix `f5594a0` + swift-foundations/swift-windows
  `653b50b` — POSIX + Windows Close.Error and Validity.Error
  code-mapping inits at L3-policy. Phase 1 / Phase 2 wrappers
  compose over these.
- **Worked-example template**: swift-microsoft/swift-windows-standard
  commit `1be7df4` — L2-takes-raw + L3-policy-wraps for Windows
  CloseHandle. Generalized to all Phase 1 / Phase 2 sub-cycles.
- **Compiler probe**: swift-kernel-primitives commits `f14cf8f` /
  `acc42e5` — typealias mechanism GREEN 8/8.
- **Skill rules**: `swift-institute/Skills/platform/SKILL.md` —
  [PLAT-ARCH-005] revised, [PLAT-ARCH-008c] strengthened,
  [PLAT-ARCH-008e] L3-unifier composition, [PLAT-ARCH-008i] POSIX-shared
  base composition. All correct under Path X; transition notes
  retire on final cycle completion.
- **Audit items** (status: OPEN — IN MIGRATION → CLOSED on Path X
  final cycle):
  `swift-institute/Audits/swift-primitives-platform-code-inventory.md`
  items 1, 2, 7. Re-linked to path-x-removal-plan.md per audit relink
  commit `428c3b5`.
