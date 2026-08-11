# L1-types-only-no-exceptions: L2 spec-wrapper cascade RECOMMENDATION

<!--
---
version: 2.0.2
last_updated: 2026-04-27
status: SUPERSEDED
parent: l1-types-only-no-exceptions.md
superseded_by: path-x-removal-plan.md
---
-->

> **Status: SUPERSEDED (2026-04-27)** by `path-x-removal-plan.md` per
> [META-003]. The user reconsidered the L1-stays premise this cascade
> investigation rests on and stamped Path X (remove
> swift-kernel-primitives entirely) on 2026-04-27. The cascade's
> empirical census, classification framework, and worked-example
> patterns remain useful as historical input to Path X — the L2-takes-raw
> + L3-policy-wraps shape transfers cleanly to Path X's per-platform
> L3-policy migration of Bucket A targets (Descriptor / Process / Socket
> / Termios / Directory.Entry).
>
> This document is preserved in place per [META-005] (no archival; status
> is the canonical filter). Path X subsumes this investigation's scope
> and replaces its Path 1 family-wide commitment with a broader
> "delete swift-kernel-primitives entirely" commitment. Cycle A's 2
> already-pushed β-rescue commits (swift-posix `f5594a0` + swift-windows
> `653b50b`) carry forward as Path X substrate per `path-x-removal-plan.md`
> § 3.5.

<!--
Changelog:
- 2.0.2 (2026-04-27): SUPERSEDED by path-x-removal-plan.md per [META-003].
  Status transition only; content preserved as historical rationale.
- 2.0.1 (2026-04-27): § 3.3.1 + § 3.5.1 + § 3.6.1 enumeration refinements.
  Pre-Cycle-A grep-pass per supervisor `ask:` #6 surfaced 2 inline Pattern B
  sites in Descriptor family that the original `^extension Kernel\.…\.` grep
  missed (anchored at column 0; missed indented `#if os(...)`-wrapped
  extensions and direct-namespace forms without trailing dot). Same anchor
  issue had hidden 6 Pattern B sites in the Directory family. Corrected
  grep + corrected enumerations recorded; original grep preserved per
  [HANDOFF-016] proposal-staleness with annotation. Cycle A scope unchanged
  (the 6 standalone Pattern B files); inline sites defer to their natural
  Cycle B sub-cycles per [HANDOFF-014] / [HANDOFF-026].
- 2.0.0 (2026-04-27): INVESTIGATION → RECOMMENDATION; Path 1 family-wide
  selected; empirical census re-derived; cycle decomposition committed.
-->

## Abstract

The descriptor migration authorized by `l1-types-only-no-exceptions.md`
(RECOMMENDATION, commit `0666a59`) was deferred at Phase 2 close per
`HANDOFF-l1-exception-removal-execution.md` Escalation B: a substantial
set of L2 spec-wrapper sites accept `borrowing Kernel.Descriptor` /
return `Kernel.Descriptor` / extend `Kernel.Descriptor.Validity.Error` /
`Kernel.Close.Error` family types. Deletion of the L1 types breaks
those L2 sites; L2 cannot reach L3-policy under [PLAT-ARCH-007] /
[ARCH-LAYER-001].

This document is the RECOMMENDATION that resolves that cascade. It
supersedes v1.0.0 INVESTIGATION (commit `05a2230`).

**Selected path**: Path 1 — **family-wide cascade refactor**. The
cascade resolves `Kernel.Descriptor`, `Kernel.Process.ID`, and
`Kernel.Directory.Entry` together. Per the empirical census in § 3,
the family-wide cascade is materially smaller than the preliminary
v1.0.0 § 4.4 framing implied (~71 L2 typed-parameter sites total
across all three types, against the preliminary "200+ files"
estimate). The decomposition into shippable cycles is in § 4.

**Pattern**: L2 spec-wrappers accept raw `Int32` (POSIX) / `UInt`
(Windows) / raw C struct (`stat`, `dirent`, `WIN32_FIND_DATAW`) at the
syscall boundary. Typed descriptors / process IDs / directory entries
live at L3-policy. Cross-platform consumers see unified names
(`Kernel.Descriptor`, `Kernel.Process.ID`, `Kernel.Directory.Entry`)
via the L3-unifier typealias chain at `swift-kernel`. The
windows-standard L2-split commit `1be7df4` is the canonical
worked-example template for the parameter-direction class; the same
shape applies symmetrically (return-direction) to struct-returning
syscalls.

The RECOMMENDATION operates within the within-L3 sub-tier framework
stamped 2026-04-26 in
`swift-institute/Research/lateral-l3-to-l3-composition-options.md`
(Hybrid B+C, swift-posix L3-policy, swift-kernel L3-unifier).

## 1. Motivation

### 1.1 The cascade discovery

Phase 1.5 (POSIX family migration) and Phase 2 (Windows family +
windows-standard L2 split) landed cleanly as scaffolding (commits
`50e7019` swift-posix, `1be7df4` windows-standard, `71e1bbd`
swift-windows). Phase 3 (typealias chain in swift-kernel) failed to
land cleanly:

- **Escalation A** (Phase 3 ordering): `extension Kernel { typealias
  Descriptor = POSIX.Kernel.Descriptor }` collides with surviving L1
  `struct Kernel.Descriptor`. Reorderable: Phase 5 (L1 deletion)
  must precede Phase 3.
- **Escalation B** (this RECOMMENDATION's target): L1 deletion breaks
  L2 callers that take typed `Kernel.Descriptor` parameters or extend
  family types (Validity.Error, Close.Error). L2 cannot reach
  L3-policy under [PLAT-ARCH-007] / [ARCH-LAYER-001].

### 1.2 Why the parent doc's § 7 estimate understated

The parent doc's § 7 wrote: *"consumers writing `@_spi(Syscall) import
Kernel_Descriptor_Primitives` and reaching `_rawValue` will need to
update their import."* That captures the SPI surface — call sites
that reach raw fd to make syscalls. The framing missed two patterns:

1. **L2 spec wrappers using `Kernel.Descriptor` as a typed
   parameter** (Pattern A). E.g.,
   `ISO_9945.Kernel.Termios.Attributes.get(_ descriptor: borrowing
   Kernel.Descriptor) throws(Kernel.Error) -> Self` at
   `/Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel Terminal/ISO 9945.Kernel.Termios.swift:42`.
   The descriptor is a typed parameter; the function never reaches
   `_rawValue` directly through the SPI initializer — the descriptor
   is just passed through internally.

2. **L2 extending L1 family error types or family namespaces**
   (Pattern B). E.g., `extension Kernel.Close.Error { public init(code:
   Kernel.Error.Code) }` at
   `/Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Core/ISO 9945.Kernel.Close.Error+code.swift:14`.
   The family types move to L3-policy in Phases 1.5 / 2; their L2
   extensions become orphans because L2 cannot import L3-policy.

The § 7 estimate's mechanical-import-update framing was correct for
SPI consumer surface. It does not generalize to typed-parameter or
family-extension surfaces.

### 1.3 Empirical scope generalization (post-census)

The cascade does NOT apply only to `Kernel.Descriptor`. It applies
identically to `Kernel.Process.ID` (same handle-class storage —
`pid_t` / `Int32` on POSIX, `DWORD` / `UInt` on Windows) and applies
in the symmetric (return-direction) form to `Kernel.Directory.Entry`
(C-struct return: `dirent` on POSIX, `WIN32_FIND_DATAW` on Windows).

Per § 3's census, the total typed-parameter cascade scope is:

- `Kernel.Descriptor`: 58 L2 sites (Pattern A)
- `Kernel.Process.ID`: 11 L2 sites
- `Kernel.Directory.Entry`: 2 L2 sites (parameter-direction; return-direction is the dominant usage)

The cascade is materially smaller than the v1.0.0 INVESTIGATION
abstract's "200+ files touched" framing. Per [HANDOFF-024]
empirical-grep-first, this RECOMMENDATION re-derived the numbers and
the design fits to actual scope.

## 2. Investigation Scope (fulfilled)

What this RECOMMENDATION produces, mapped to the original v1.0.0 § 2
inventory:

1. **Empirical census** of L2 typed-parameter usage and family-extension
   usage across iso-9945, windows-standard, linux-standard, darwin-standard.
   Per-pattern, per-repo counts with reproducible grep commands. → § 3 below.
2. **Decomposition** of the L2 refactor into shippable cycles. → § 4 below.
3. **Decision** — RECOMMENDATION → ACCEPTED on Path 1 family-wide. → § 6 below.

L3+ consumers (`swift-foundations/swift-file-system`, `swift-io`,
`swift-darwin`, `swift-linux`, `swift-windows`, etc.) are NOT cascade
scope: they consume `Kernel.Descriptor` via the L3-unifier typealias
chain and resolve transparently per [PLAT-ARCH-005] revised. The
compiler probe at swift-kernel-primitives commits `f14cf8f` /
`acc42e5` verified this typealias resolution mechanism GREEN 8/8 for
L3 consumer code. The cascade is specifically the L2 → L3-policy
upward-dep wall.

## 3. Empirical Census (per [HANDOFF-021] / [HANDOFF-024])

All counts in this section were derived 2026-04-27 by running the
grep commands cited inline. Future agents resuming this work re-run
the same commands to verify the census still holds.

### 3.1 Cascade scope across the 4 L2 repos

The cascade lives in 4 L2 repos:

| Repo | Path |
|---|---|
| swift-iso-9945 | `/Users/coen/Developer/swift-iso/swift-iso-9945` |
| swift-windows-standard | `/Users/coen/Developer/swift-microsoft/swift-windows-standard` |
| swift-linux-standard | `/Users/coen/Developer/swift-linux-foundation/swift-linux-standard` |
| swift-darwin-standard | `/Users/coen/Developer/swift-standards/swift-darwin-standard` |

### 3.2 Pattern A — L2 typed-parameter usage of `Kernel.Descriptor`

**Definition**: files declaring functions whose public/SPI signature
takes `borrowing Kernel.Descriptor` / `consuming Kernel.Descriptor` /
`inout Kernel.Descriptor` / `: Kernel.Descriptor` / returns
`Kernel.Descriptor`.

**Enumeration command** (run from each repo's root, parameterized by
`$REPO`):

```bash
grep -rl --include="*.swift" -E \
  "(borrowing|consuming|inout)?[[:space:]]+Kernel\.Descriptor[^A-Za-z_.]|: Kernel\.Descriptor[^A-Za-z_.]|-> Kernel\.Descriptor[^A-Za-z_.]|Kernel\.Descriptor\(_rawValue" \
  "$REPO/Sources" 2>/dev/null | sort -u
```

For multi-line return signatures (Swift function declarations span
multiple lines):

```bash
find "$REPO/Sources" -name "*.swift" -exec perl -0777 -ne \
  'if (/throws\(.*?\)\s*->\s*Kernel\.Descriptor[^A-Za-z_.]/s) { print "$ARGV\n" }' \
  {} \; 2>/dev/null | sort -u
```

**Per-repo counts** (verified 2026-04-27):

| Repo | Pattern A files | Of which return-direction |
|---|---:|---:|
| swift-iso-9945 | 31 | 4 (`File.Open`, `Pipe`, `Pipe.Close`, `Memory.Shared`, `Descriptor.Duplicate`) |
| swift-windows-standard | 13 | 4 (`File.Open`, `Pipe.Named`, `IO.Completion.Port`, `Descriptor.Duplicate`) |
| swift-linux-standard | 11 | 2 (`Event.Poll`, `IO.Uring`) |
| swift-darwin-standard | 3 | 1 (`Event.Queue`) |
| **Total** | **58** | **11** |

**Per-syscall-family breakdown** (by directory grouping per repo):

| Repo | Family | Files |
|---|---|---:|
| swift-iso-9945 | File | 17 |
| | Socket | 6 |
| | Terminal | 2 |
| | Memory | 2 |
| | Lock | 2 |
| | Poll | 1 |
| | Directory | 1 |
| swift-windows-standard | File | 7 |
| | IO Completion | 5 |
| | Memory Map | 1 |
| swift-linux-standard | IO Uring | 4 |
| | File | 3 |
| | Event | 2 |
| | Pipe | 1 |
| | Descriptor | 1 |
| swift-darwin-standard | (Standard) | 2 |
| | Event | 1 |

The two largest single-family clusters are iso-9945 File (17 files)
and iso-9945 Socket (6 files). These two account for 23/58 ≈ 40% of
the Descriptor cascade scope.

**Representative file paths**:

- iso-9945 worked example for parameter-direction: `/Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel Terminal/ISO 9945.Kernel.Termios.swift:42` (`extension ISO_9945.Kernel.Termios.Attributes { static func get(_ descriptor: borrowing Kernel.Descriptor) throws(Kernel.Error) -> Self }`)
- iso-9945 worked example for return-direction: `/Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.File.Open.swift:60` (`extension ISO_9945.Kernel.File.Open { static func open(...) throws(...) -> Kernel.Descriptor }`)
- windows-standard worked example post-1be7df4 (template for the cascade): `/Users/coen/Developer/swift-microsoft/swift-windows-standard/Sources/Windows Kernel File Standard/Windows.Kernel.Close.swift:33` (`extension Kernel.Close { @_spi(Syscall) public static func close(_ handle: UInt) -> Bool }`)
- linux-standard worked example: `/Users/coen/Developer/swift-linux-foundation/swift-linux-standard/Sources/Linux Kernel IO Uring Standard/Linux.Kernel.IO.Uring.Submission.Queue.Entry+Prepare.swift:1`

### 3.3 Pattern B — L2 extending L1 family types

**Definition**: files extending L1 family types under `Kernel.Close`,
`Kernel.Descriptor`, `Kernel.Descriptor.Validity`,
`Kernel.Descriptor.Duplicate`, etc. — types that move to L3-policy
under the cascade.

**Enumeration command**:

```bash
grep -rln --include="*.swift" "^extension Kernel\.\(Close\|Descriptor\)\." "$REPO/Sources"
```

**Per-repo counts** (verified 2026-04-27):

| Repo | Files | Notes |
|---|---:|---|
| swift-iso-9945 | 2 | `ISO 9945.Kernel.Close.Error+code.swift`, `ISO 9945.Kernel.Descriptor.Validity.Error+code.swift` (both at `Sources/ISO 9945 Core/`) |
| swift-windows-standard | 2 | `Windows.Kernel.Close.Error+code.swift`, `Windows.Kernel.Descriptor.Validity.Error+code.swift` (both at `Sources/Windows Kernel Standard Core/`) |
| swift-linux-standard | 2 | `Linux.Kernel.Descriptor.Duplicate.swift`, `Linux.Kernel.Descriptor.Duplicate.Options.swift` (both extend `Kernel.Descriptor.Duplicate` namespace, not error type — pattern variant) |
| swift-darwin-standard | 0 | (none) |
| **Total** | **6** | |

**Sub-categorization**:

- **B-error** (extending L1 family error types like
  `Kernel.Close.Error`, `Kernel.Descriptor.Validity.Error`):
  4 files — iso-9945's `Close.Error+code` + `Descriptor.Validity.Error+code`,
  windows-standard's `Close.Error+code` + `Descriptor.Validity.Error+code`.

- **B-namespace** (extending L1 family non-error namespaces like
  `Kernel.Descriptor.Duplicate`):
  2 files — Linux's `Descriptor.Duplicate.swift` (Linux's `dup3(2)`
  extension) + `Descriptor.Duplicate.Options.swift` (the
  `O_CLOEXEC`-bearing options struct nested under
  `Kernel.Descriptor.Duplicate`).

**Pre-existing scaffolding cleared the foundation**: `POSIX.Kernel.Close.Error`
and `Windows.Kernel.Close.Error` already exist at L3-policy via
scaffolding commits `50e7019` (swift-posix) and `71e1bbd`
(swift-windows). The Pattern B cleanup relocates the L2 extension
files alongside their target family types.

This is dramatically smaller than v1.0.0 § 3.2's preliminary "~12
files in iso-9945, parallel sets in linux-standard / windows-standard
expected." The actual count is 6 files total across all 4 repos.

### 3.3.1 Enumeration refinement — corrected grep + inline Pattern B sites (v2.0.1)

The § 3.3 grep above is **STALE** per [HANDOFF-016] proposal-staleness
axis: it anchors on `^extension` (column 0) and requires a trailing
`\.` after `(Close|Descriptor)`. Two failure modes:

1. Indented extensions inside `#if os(Linux)` blocks (4-space indent
   convention) don't match the column-0 anchor.
2. Direct-namespace extensions on the bare type (e.g.,
   `extension Kernel.Descriptor {`) don't match the trailing-dot
   requirement.

**Corrected enumeration command** (tolerates indentation, captures
both trailing-dot sub-element forms and direct-namespace forms):

```bash
grep -rn --include="*.swift" -E \
  "^[[:space:]]*extension Kernel\.(Close|Descriptor)([.[:space:]{]|$)" \
  "$REPO/Sources" 2>/dev/null | sort
```

**Stale-grep supersession** (per [HANDOFF-016]): the original grep is
preserved above as the historical command; the corrected grep is the
authoritative enumeration command from v2.0.1 forward.

**Pre-Cycle-A re-enumeration** (verified 2026-04-27 via the corrected
grep): the 6 standalone Pattern B files in § 3.3 above are confirmed.
Two **additional** inline Pattern B sites surface in mostly-Pattern-A
hosting files. These sites do NOT relocate in Cycle A — the hosting
file's main content is Pattern A scope (Cycle B sub-cycles). Cycle A
remains the 6-file relocation per § 4.1; the inline sites defer to
their natural sub-cycles per the table below.

| Inline site | Hosting file primary content | Cycle B absorption |
|---|---|---|
| `swift-microsoft/swift-windows-standard/Sources/Windows Kernel File Standard/Windows.Kernel.Descriptor.Duplicate.swift:80` (`extension Kernel.Descriptor.Duplicate.Error { @usableFromInline internal static func current() -> Self }`) | Pattern A: `extension Windows.Kernel.Descriptor.Duplicate { static func duplicate(_ descriptor: Kernel.Descriptor) throws -> Kernel.Descriptor }` (Win32 `DuplicateHandle` syscall wrapper) | **Cycle B.2** (Windows Descriptor sub-cycle) |
| `swift-linux-foundation/swift-linux-standard/Sources/Linux Kernel Event Standard/Linux.Kernel.Event.Descriptor.swift:158` (`extension Kernel.Descriptor { init(_ eventDescriptor: consuming Kernel.Event.Descriptor) }`) | Pattern A: type definition for `Kernel.Event.Descriptor` (Linux `eventfd(2)` typed descriptor) + lifecycle methods | **Cycle B.3** (Linux Descriptor sub-cycle) |

**Sub-cycle handoff requirement** (per [HANDOFF-014] /
[HANDOFF-026]): the Cycle B.2 and Cycle B.3 sub-cycle handoffs MUST
list these inline Pattern B sites explicitly in their
`## Pre-Existing Code in Scope` sections, with disposition note
*"Refactored alongside hosting Pattern A file in this cycle (inline
extension; carries forward from cascade doc § 3.3.1)."* Without the
explicit annotation, the sub-cycle executor may read the hosting file
as Pattern A only and silently drop the inline extension at Cycle C
deletion time, producing an orphan-reference build break. The
30-second annotation cost prevents the eventual Cycle C compounded
correction.

**False-positive note**: the corrected grep also matches L2 spec-wrapper
files at `iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.Close.swift:24`
(`extension Kernel.Close { @_spi(Syscall) public static func close(_ fd: Int32) -> Int32 }`)
and `windows-standard/Sources/Windows Kernel File Standard/Windows.Kernel.Close.swift:20`
(the post-`1be7df4` worked-example template). These are **NOT Pattern
B** — they're the L2 spec wrappers themselves, namespacing the raw
syscall function under `Kernel.Close`. Per the cascade architecture
endorsed by this RECOMMENDATION, they STAY at L2 unchanged through
all three cycles. They appear in the corrected grep because the grep
shape is "any extension on the Kernel.Close namespace"; semantic
classification (function-on-namespace vs init-on-error-type) is the
distinguishing axis. Future Cycle B sub-cycle handoffs reading this
section MUST recognize these L2 spec-wrapper extensions as
out-of-scope for relocation.

### 3.4 Pattern C — L2 module imports of `Kernel_Descriptor_Primitives`

**Definition**: files importing `Kernel_Descriptor_Primitives` at any
access level (`@_spi(Syscall) import` / `public import` /
`internal import`).

**Enumeration command**:

```bash
grep -rl --include="*.swift" "import Kernel_Descriptor_Primitives" "$REPO/Sources"
```

**Per-repo counts** (verified 2026-04-27):

| Repo | Files |
|---|---:|
| swift-iso-9945 | 118 |
| swift-windows-standard | 29 |
| swift-linux-standard | 35 |
| swift-darwin-standard | 3 |
| **Total** | **185** |

**Interpretation**: Pattern C is broader than Pattern A — it includes
files that import `Kernel_Descriptor_Primitives` to USE
`Kernel.Descriptor` as a parameter (Pattern A overlap), but ALSO
files that import it solely to surface the type via
`@_exported import` chains, error-mapping initializers (`init(code:)`),
and similar uses where the descriptor type itself does not appear in
a public signature. Most of these files lose the import in Cycle B
when their referencing code switches from typed `Kernel.Descriptor`
to raw `Int32` / `UInt`. Post-Cycle-C, the
`Kernel_Descriptor_Primitives` module is deleted; remaining imports
in L2 are themselves the residual to clean up.

### 3.5 Generalization census — `Kernel.Process.ID`

**Pattern A (typed-parameter usage)**:

```bash
grep -rl --include="*.swift" -E \
  "(borrowing|consuming|inout)?[[:space:]]+Kernel\.Process\.ID[^A-Za-z_.]|: Kernel\.Process\.ID[^A-Za-z_.]|-> Kernel\.Process\.ID[^A-Za-z_.]" \
  "$REPO/Sources"
```

| Repo | Files | Of which return-direction |
|---|---:|---:|
| swift-iso-9945 | 9 | 1 (`Process.Spawn` returns Process.ID) |
| swift-windows-standard | 0 | 0 |
| swift-linux-standard | 2 | 0 (used in IO Uring submission queue entry) |
| swift-darwin-standard | 0 | 0 |
| **Total** | **11** | **1** |

**Pattern C (module imports)** of `Kernel_Process_Primitives`:

| Repo | Files |
|---|---:|
| swift-iso-9945 | 15 |
| swift-windows-standard | 2 |
| swift-linux-standard | 3 |
| swift-darwin-standard | 0 |
| **Total** | **20** |

### 3.5.1 Pattern B for Process.ID family — confirmed empty (v2.0.1)

**Corrected enumeration command** (mirrors § 3.3.1):

```bash
grep -rn --include="*.swift" -E \
  "^[[:space:]]*extension Kernel\.Process(\.ID)?([.[:space:]{]|$)" \
  "$REPO/Sources" 2>/dev/null | sort
```

**Result** (verified 2026-04-27): zero Pattern B sites for
`Kernel.Process` or `Kernel.Process.ID` family across all 4 L2 repos.
Cycle B.5 (Process.ID sub-cycle) carries Pattern A only; no
Pattern B family-extension relocation is needed. Recorded explicitly
to close the failure mode that hid the Descriptor and Directory
inline sites — Process.ID's anchor-correctness is now positively
verified rather than assumed.

### 3.6 Generalization census — `Kernel.Directory.Entry`

**Pattern A (typed-parameter / return usage)**:

```bash
grep -rl --include="*.swift" -E \
  "(borrowing|consuming|inout)?[[:space:]]+Kernel\.Directory\.Entry[^A-Za-z_.]|: Kernel\.Directory\.Entry[^A-Za-z_.]|-> Kernel\.Directory\.Entry[^A-Za-z_.]" \
  "$REPO/Sources"
```

| Repo | Files | Notes |
|---|---:|---|
| swift-iso-9945 | 1 | `ISO 9945.Kernel.Directory.swift:92` (`func next() throws -> Kernel.Directory.Entry?` — return-direction; struct constructed from `dirent` at file:133) |
| swift-windows-standard | 1 | `Windows.Kernel.Directory.swift` (return-direction; struct constructed from `WIN32_FIND_DATAW`) |
| swift-linux-standard | 0 | (no Linux-specific dir extension) |
| swift-darwin-standard | 0 | (no Darwin-specific dir extension) |
| **Total** | **2** | dominant usage is return-direction |

`Kernel.Directory.Entry` is structurally distinct from
`Kernel.Descriptor` and `Kernel.Process.ID`: it is a struct (entry
name + inode + type), not an integer handle. The "raw" form at the
syscall boundary is the C struct (`dirent` on POSIX,
`WIN32_FIND_DATAW` on Windows). The pattern still applies but
operates symmetrically (return-direction): L2 returns the raw
C-struct (or struct-from-C-struct), L3-policy wraps into typed
`Kernel.Directory.Entry`. See § 5 of the design draft.

### 3.6.1 Pattern B for Directory family — full inventory (v2.0.1)

The original § 3.6 above enumerated only Pattern A for
`Kernel.Directory.Entry`. The same anchor failure documented in
§ 3.3.1 had hidden a substantial Pattern B inventory for the broader
Directory family. The corrected enumeration command:

```bash
grep -rn --include="*.swift" -E \
  "^[[:space:]]*extension Kernel\.Directory(\.Entry)?([.[:space:]{]|$)" \
  "$REPO/Sources" 2>/dev/null | sort
```

**Per-repo Pattern B inventory** (verified 2026-04-27):

| Repo | Site | Hosting file content | Cycle B.6 disposition |
|---|---|---|---|
| swift-iso-9945 | `Sources/ISO 9945 Core/ISO 9945.Kernel.Directory.Working.Error+code.swift:14` | Standalone Pattern B-error file (`extension Kernel.Directory.Working.Error { init(code:) }`) | Standalone relocation in B.6 (mirror of Cycle A's standalone `Close.Error+code` / `Descriptor.Validity.Error+code` shape) |
| swift-windows-standard | `Sources/Windows Kernel Standard Core/Windows.Kernel.Directory.Working.Error+code.swift:16` | Standalone Pattern B-error file (Windows mirror of iso-9945's) | Standalone relocation in B.6 |
| swift-windows-standard | `Sources/Windows Kernel Directory Standard/Windows.Kernel.Directory.Create.swift:52` | Inline Pattern B-error in mostly-Pattern-A file (`extension Windows.Kernel.Directory.Create { static func create(...) }`) | Refactored alongside hosting Pattern A in B.6 |
| swift-windows-standard | `Sources/Windows Kernel Directory Standard/Windows.Kernel.Directory.Remove.swift:46` | Inline Pattern B-error (Pattern A host: `extension Windows.Kernel.Directory.Remove { ... remove ... }`) | Refactored alongside hosting Pattern A in B.6 |
| swift-windows-standard | `Sources/Windows Kernel Directory Standard/Windows.Kernel.Directory.Working.swift:89` | Inline Pattern B-error (Pattern A host: working-directory get/set syscalls) | Refactored alongside hosting Pattern A in B.6 |
| swift-windows-standard | `Sources/Windows Kernel Directory Standard/Windows.Kernel.Directory.swift:177` | Inline Pattern B-error (Pattern A host: `Windows.Kernel.Directory` namespace + readdir-equivalent operations) | Refactored alongside hosting Pattern A in B.6 |
| swift-linux-standard | (none) | (no Linux-specific Directory extensions in current source) | n/a |
| swift-darwin-standard | (none) | (no Darwin-specific Directory extensions in current source) | n/a |
| **Total** | **6** | **2 standalone + 4 inline** | |

**Sub-cycle handoff requirement** (per [HANDOFF-014] /
[HANDOFF-026]): the Cycle B.6 sub-cycle handoff MUST list the 4
inline Pattern B sites in its `## Pre-Existing Code in Scope` section
with disposition note *"Refactored alongside hosting Pattern A file
in this cycle (inline extension; carries forward from cascade doc
§ 3.6.1)."* The 2 standalone files relocate similarly to Cycle A's
standalone files, with destination `swift-posix/Sources/POSIX Kernel
Directory/` (POSIX-shared) and `swift-windows/Sources/Windows Kernel
Directory/` (Windows-specific) respectively.

**§ 3.7 implication**: the cascade scope summary's "Pattern B files"
column for `Kernel.Directory.Entry` should be read as 6 (not 0); the
cascade's family-wide commitment carries 6 + 6 + 0 = 12 Pattern B
sites total across the three types, not the previously-recorded 6.
The total typed-parameter site count (71) is unchanged — it covers
only Pattern A.

### 3.7 Cascade scope summary

| Type | Pattern A files | Pattern B standalone files | Pattern B inline sites | Pattern C imports |
|---|---:|---:|---:|---:|
| `Kernel.Descriptor` | 58 | 6 | 2 (per § 3.3.1) | 185 |
| `Kernel.Process.ID` | 11 | 0 (confirmed § 3.5.1) | 0 | 20 |
| `Kernel.Directory.Entry` / Directory family | 2 | 2 (per § 3.6.1) | 4 (per § 3.6.1) | (subsumed) |
| **Total** | **71** | **8** | **6** | **205** (with overlap) |

**Standalone vs inline Pattern B**: standalone files have Pattern B as
their primary purpose and relocate as whole files (Cycle A's 6-file
scope for Descriptor family; Cycle B.6's 2 standalone Directory
family files). Inline sites are Pattern B paragraphs embedded inside
mostly-Pattern-A files; they relocate or refactor alongside their
hosting file in the natural Cycle B sub-cycle for that hosting file
(B.2 / B.3 / B.6). § 3.3.1 and § 3.6.1 enumerate the inline sites
with hosting file disposition.

**Materially smaller than v1.0.0 § 4.4**: The preliminary § 4.4 framed
total cycle scope as 350-400 files. The actual modification scope
(Pattern A + Pattern B standalone + Pattern B inline = 71 + 8 + 6 =
85 files) plus new L3-policy wrapper additions (~71 files mirroring
Pattern A + ~2 files for the standalone Directory Pattern B-error
files) is approximately 158 files modified or added. The
preliminary estimate over-stated by ~2×. The v2.0.1 amendments
(§ 3.3.1, § 3.5.1, § 3.6.1) tighten the v2.0.0 count from 148 to 158
without changing the structural cycle decomposition.

The cascade is **not** below the supervisor's
"materially smaller (e.g., < 20 L2 typed-parameter files total)"
threshold (per supervisor `ask:` in
`HANDOFF-l2-cascade-recommendation.md`); 71 typed-parameter sites is
between the surface estimate and a trivial cycle. Path 1 family-wide
remains the right recommendation, with Cycle B sized to the
empirically-derived 71-file scope.

## 4. Cycle Decomposition

The cascade decomposes into three sequential cycles with explicit
gates between them. Cycle A is the smallest dispatchable unit and is
the immediate next dispatch (per § 6 RECOMMENDATION).

### 4.1 Cycle A — Family-extension relocation (small, dispatch-ready)

**Scope**: Relocate the 6 Pattern B files from L2 to L3-policy.

| File | Current location | Destination |
|---|---|---|
| `ISO 9945.Kernel.Close.Error+code.swift` | `swift-iso-9945/Sources/ISO 9945 Core/` | `swift-posix/Sources/POSIX Kernel Descriptor/POSIX.Kernel.Close.Error+code.swift` |
| `ISO 9945.Kernel.Descriptor.Validity.Error+code.swift` | `swift-iso-9945/Sources/ISO 9945 Core/` | `swift-posix/Sources/POSIX Kernel Descriptor/POSIX.Kernel.Descriptor.Validity.Error+code.swift` |
| `Windows.Kernel.Close.Error+code.swift` | `swift-windows-standard/Sources/Windows Kernel Standard Core/` | `swift-windows/Sources/Windows Kernel/Windows.Kernel.Close.Error+code.swift` |
| `Windows.Kernel.Descriptor.Validity.Error+code.swift` | `swift-windows-standard/Sources/Windows Kernel Standard Core/` | `swift-windows/Sources/Windows Kernel/Windows.Kernel.Descriptor.Validity.Error+code.swift` |
| `Linux.Kernel.Descriptor.Duplicate.swift` | `swift-linux-standard/Sources/Linux Kernel Descriptor Standard/` | `swift-linux/Sources/Linux Kernel/Linux.Kernel.Descriptor.Duplicate.swift` (L3-policy) |
| `Linux.Kernel.Descriptor.Duplicate.Options.swift` | `swift-linux-standard/Sources/Linux Kernel Descriptor Standard/` | `swift-linux/Sources/Linux Kernel/Linux.Kernel.Descriptor.Duplicate.Options.swift` (L3-policy) |

Each file is renamed to swap the L2 namespace prefix
(`extension Kernel.Close.Error` / `extension Kernel.Descriptor.Validity.Error` /
`extension Kernel.Descriptor.Duplicate`) for the L3-policy prefix
(`extension POSIX.Kernel.Close.Error` etc.). The body content
(error-code mapping logic, `Options` definition, `dup3` syscall
wrapper) ports verbatim modulo the type prefix.

**Dependencies**: Phase 1.5 + 2 already landed (the family types now
exist at L3-policy in swift-posix / swift-windows / pending-swift-linux).
For swift-linux specifically, Cycle A creates the `Linux.Kernel.Descriptor.Duplicate`
namespace at L3-policy if it does not yet exist.

**Cost**: small. ~6 files relocated + L2 deletion + import path
updates in any consumer. Single-agent dispatch. ~3-4 commits per
[HANDOFF-019] commit-as-you-go cadence (one per L3-policy package
receiving relocations: swift-posix, swift-windows, swift-linux; plus
one cleanup commit per L2 package the files left).

**Closes**: Pattern B orphans. Pattern A still exists; L1 family
types not yet deleted.

**Gate to Cycle B**: Cycle A's commits land + push + green build on
all three L3-policy packages + green build on the three L2 source
packages (post-deletion, no orphan symbols). Empirical evidence on
relocation friction (any cross-import surprises, any per-platform
header issues) feeds into Cycle B's scope-sizing review.

### 4.2 Cycle B — L2 spec-wrapper signature refactor (large, multi-sub-cycle)

**Scope**: Refactor 71 L2 typed-parameter sites to accept raw
integer / C-struct types at the syscall boundary, and add ~71 NEW
L3-policy wrapper files in swift-posix / swift-darwin / swift-linux /
swift-windows providing the typed-descriptor surface.

**Sub-cycle decomposition** (each sub-cycle is independently
dispatchable):

| Sub-cycle | Scope | L2 sites | New L3-policy files |
|---|---|---:|---:|
| B.1 — Descriptor (POSIX) | 31 iso-9945 sites + corresponding swift-posix wrappers | 31 | ~31 |
| B.2 — Descriptor (Windows) | 13 windows-standard sites + corresponding swift-windows wrappers | 13 | ~13 |
| B.3 — Descriptor (Linux) | 11 linux-standard sites + corresponding swift-linux wrappers | 11 | ~11 |
| B.4 — Descriptor (Darwin) | 3 darwin-standard sites + corresponding swift-darwin wrappers | 3 | ~3 |
| B.5 — Process.ID | 11 sites across iso-9945 (9) + linux-standard (2) + corresponding swift-posix / swift-linux wrappers | 11 | ~11 |
| B.6 — Directory.Entry | 2 sites (iso-9945, windows-standard) + corresponding L3-policy wrappers | 2 | ~2 |

**Sub-cycle ordering**: B.1 before B.2/B.3/B.4 (POSIX-shared base
provides wrapper template). B.5 + B.6 after the Descriptor sub-cycles
land (their L3-policy wrappers reuse the swift-posix / swift-windows
wrapper conventions established by B.1-B.4).

**Cost per sub-cycle**: medium-to-large. Each L2 site refactor +
matching L3-policy wrapper is ~2 file changes. Per [HANDOFF-019]
commit-as-you-go, expect 1-3 commits per sub-cycle (one per syscall
family within the sub-cycle, or one per repo pair). Total estimated
commits: ~12-18 across the 6 sub-cycles.

**Pattern uniformity**: Per § 5 below, the pattern is uniform across
parameter-direction syscalls (close, dup, fcntl, fstat). The
bifurcation between handle-returning (close, dup → integer raw) and
struct-returning (fstat → C-struct raw, readdir → dirent) is a raw
shape difference, not a structural difference; both fit the
L2-takes-raw + L3-policy-wraps pattern with the raw form adjusted to
the syscall's actual C-level signature.

**Closes**: Pattern A (Descriptor + Process.ID + Directory.Entry).
After Cycle B, no L2 file references the L1 types as parameters or
returns. The L3-policy wrappers in swift-posix / swift-darwin /
swift-linux / swift-windows provide the typed surface.

**Gate to Cycle C**: All B-sub-cycles' commits land + push + green
build on all 4 L2 repos + green build on all 4 L3-policy repos. The
swift-kernel typealias chain mechanism (already verified GREEN 8/8
via `f14cf8f` / `acc42e5`) is the next-cycle infrastructure.

### 4.3 Cycle C — Typealias chain + L1 deletion + consumer migration + push (medium, gated)

**Scope**: The original `HANDOFF-l1-exception-removal-execution.md`
Phase 3 (typealias) + Phase 5 (L1 deletion) + Phase 4 (consumer
migration: 183 import sites already enumerated in the handoff's
Findings) + Phase 6 (push + audit close), now mechanically tractable
because Cycle B has freed L2 of typed-descriptor dependencies.

**Steps**:

1. swift-kernel `Kernel/Exports.swift` adds `#if os(...)`-guarded
   typealias chain: `extension Kernel { typealias Descriptor =
   POSIX.Kernel.Descriptor }` (Darwin/Linux) /
   `extension Kernel { typealias Descriptor = Windows.Kernel.Descriptor }`
   (Windows). Same for `Kernel.Process.ID`,
   `Kernel.Directory.Entry`. Mechanism is the canonical
   [PLAT-ARCH-005] / [PLAT-ARCH-008e] pattern.

2. swift-kernel-primitives deletes:
   - `Sources/Kernel Descriptor Primitives/` (Descriptor + Close + family at L1)
   - `Sources/Kernel Process Primitives/Kernel.Process.ID.swift` (Process.ID at L1)
   - L1 `Kernel.Directory.Entry` definition (currently in `Kernel File Primitives/Kernel.Directory.swift`)
   - Other family types (`Kernel.Descriptor.Validity`, `Kernel.Descriptor.Duplicate`, etc.)

3. Ecosystem consumer migration: 183 import sites updated from
   `import Kernel_Descriptor_Primitives` (etc.) to
   `import Kernel` (the L3-unifier facade). Mechanical: per
   `HANDOFF-l1-exception-removal-execution.md` Phase 4 inventory.

4. Audit close: `swift-institute/Audits/swift-primitives-platform-code-inventory.md`
   items 1, 2, 7 → CLOSED.

**Cost**: medium. The 183-site consumer migration is mechanical
import update; the typealias chain is one swift-kernel commit per
type; the L1 deletion is one swift-kernel-primitives commit;
ecosystem build sweep + push.

**Closes**: original audit items 1, 2, 7. Skill text and code
converge. The L1-types-only invariant per [PLAT-ARCH-008c] holds
without carve-out.

### 4.4 Total revised cost (Path 1 family-wide)

| Cycle | Modification scope | New files | Commits | Sessions |
|---|---:|---:|---:|---:|
| A: family-extension relocation | 6 | (relocations, not new) | 3-4 | 1 |
| B: L2 spec-wrapper refactor + L3-policy wrappers | 71 (L2 modify) | ~71 (L3-policy add) | 12-18 | 4-6 |
| C: typealias chain + L1 deletion + consumer migration + push | ~190 (mechanical imports) | (typealias only) | 5-8 | 1-2 |
| **Total** | **~267** | **~71** | **~20-30** | **6-9** |

This compares to v1.0.0 § 4.4's preliminary "350-400 files / 4-6
cycles / 6-12 sessions". The modification scope is materially
smaller (~268 vs 350-400) and the cycles count slightly lower (~3
cycles vs 4-6). v1.0.0's bands were appropriate for the preliminary
census it was working from; the empirical-grep-first census in § 3
above tightens the estimate.

## 5. Design Draft (per supervisor MUST sub-task B)

The L2-takes-raw + L3-policy-wraps pattern is uniform across
parameter-direction syscalls (close, dup, fcntl, fstat). The
windows-standard L2-split commit `1be7df4` is the canonical
worked-example template; this section walks the pattern through 3
additional families to show uniformity and surfaces the one
bifurcation (raw shape: integer vs C struct).

This § operates within the within-L3 sub-tier framework stamped
2026-04-26 in
`swift-institute/Research/lateral-l3-to-l3-composition-options.md`
(Hybrid B+C; swift-posix L3-policy; swift-kernel L3-unifier).

### 5.1 Family — `close` (worked example, already landed via `1be7df4`)

**L2 signature** (`/Users/coen/Developer/swift-microsoft/swift-windows-standard/Sources/Windows Kernel File Standard/Windows.Kernel.Close.swift:33`):

```swift
extension Kernel.Close {
    @_spi(Syscall)
    public static func close(_ handle: UInt) -> Bool {
        #if os(Windows)
        guard let pointer = UnsafeMutableRawPointer(bitPattern: handle) else {
            return false
        }
        return CloseHandle(pointer)
        #else
        return false
        #endif
    }
}
```

**L3-policy wrapper** (`/Users/coen/Developer/swift-foundations/swift-windows/Sources/Windows Kernel/Windows.Kernel.Close.swift`):

```swift
extension Windows.Kernel.Close {
    public static func close(_ descriptor: consuming Windows.Kernel.Descriptor) throws(Error) {
        guard descriptor.isValid else { throw .handle(.invalid) }
        let raw = descriptor._raw
        descriptor._raw = ~0  // disarm deinit
        let success = Kernel.Close.close(raw)
        if !success { throw .platform(...) }
    }
}
```

**Pattern**: L2 takes raw `UInt`, returns `Bool` (the C-level result).
Spec-literal: NO `GetLastError` read, NO error mapping, NO throwing.
L3-policy unwraps the typed descriptor's `_raw`, calls L2, maps the
last-error to `Windows.Kernel.Close.Error`. This is the canonical
shape.

POSIX equivalent (`/Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.Close.swift`):

```swift
extension Kernel.Close {
    @_spi(Syscall)
    public static func close(_ fd: Int32) -> Int32 {
        #if canImport(Darwin)
        return Darwin.close(fd)
        #elseif canImport(Glibc)
        return unsafe Glibc.close(fd)
        // ...
    }
}
```

**Cross-platform L3-unifier** (per [PLAT-ARCH-005] / [PLAT-ARCH-008e]):
swift-kernel's `Kernel/Exports.swift` provides
`extension Kernel.Close { static func close(_ d: consuming Kernel.Descriptor) throws(Error) }`
via the L3-policy `#if os(...)` typealias resolution. Cross-platform
consumers see one name regardless of platform.

### 5.2 Family — `dup` (handle-returning, parameter-direction)

**Current L2 (iso-9945)** (`/Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.Descriptor.Duplicate.swift:36`):

```swift
extension ISO_9945.Kernel.Descriptor.Duplicate {
    public static func duplicate(_ descriptor: borrowing Kernel.Descriptor)
        throws(Error) -> Kernel.Descriptor {
        // ... Darwin.dup(descriptor._rawValue) ...
        return Kernel.Descriptor(_rawValue: result)
    }
}
```

**Cycle B refactored L2**:

```swift
extension ISO_9945.Kernel.Descriptor.Duplicate {
    @_spi(Syscall)
    public static func duplicate(_ fd: Int32) -> Int32 {
        #if canImport(Darwin)
        return Darwin.dup(fd)
        #elseif canImport(Glibc)
        return unsafe Glibc.dup(fd)
        #elseif canImport(Musl)
        return unsafe Musl.dup(fd)
        #endif
    }
}
```

L2 takes raw `Int32`, returns raw `Int32` (or `-1` on failure with
`errno` set). Spec-literal: NO error mapping, NO throwing.

**Cycle B new L3-policy wrapper** (`swift-posix/Sources/POSIX Kernel Descriptor/POSIX.Kernel.Descriptor.Duplicate.swift`):

```swift
extension POSIX.Kernel.Descriptor.Duplicate {
    public static func duplicate(_ descriptor: borrowing POSIX.Kernel.Descriptor)
        throws(Error) -> POSIX.Kernel.Descriptor {
        let result = ISO_9945.Kernel.Descriptor.Duplicate.duplicate(descriptor._rawValue)
        guard result >= 0 else { throw Error.current() }
        return POSIX.Kernel.Descriptor(_rawValue: result)
    }
}
```

**Pattern uniformity confirmed**: same shape as `close`. The
return-direction (constructing a new typed descriptor from the raw
fd) lives at L3-policy, not L2.

The `dup2`/`dup3` variant with `inout` `newDescriptor` (slot
replacement) follows the same pattern: L2 takes two raw `Int32`s and
returns `Int32`; L3-policy takes `borrowing` source +
`inout POSIX.Kernel.Descriptor` target, unwraps both, calls L2 raw,
maps error.

### 5.3 Family — `fcntl` (parameter-only, integer return)

**Current L2** (`/Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.File.Control.swift`):

`fcntl(2)` is a multi-operation syscall (F_GETFL, F_SETFL, F_DUPFD,
F_SETFD, etc.). Currently, the iso-9945 file declares one entry per
operation, each taking `borrowing Kernel.Descriptor`.

**Cycle B refactored L2**:

```swift
extension ISO_9945.Kernel.File.Control {
    @_spi(Syscall)
    public static func getFlags(_ fd: Int32) -> Int32 {
        #if canImport(Darwin)
        return Darwin.fcntl(fd, F_GETFL)
        // ...
    }

    @_spi(Syscall)
    public static func setFlags(_ fd: Int32, _ flags: Int32) -> Int32 {
        #if canImport(Darwin)
        return Darwin.fcntl(fd, F_SETFL, flags)
        // ...
    }
    // ... similar for F_GETFD / F_SETFD / F_DUPFD ...
}
```

L2 takes raw `Int32`, returns the raw `Int32` result. Each
sub-operation is a separate function (per the file's existing
breakdown).

**Cycle B new L3-policy wrapper** (`swift-posix/Sources/POSIX Kernel File/POSIX.Kernel.File.Control.swift`):

```swift
extension POSIX.Kernel.File.Control {
    public static func getFlags(_ descriptor: borrowing POSIX.Kernel.Descriptor)
        throws(Error) -> Kernel.File.Open.Flags {
        let result = ISO_9945.Kernel.File.Control.getFlags(descriptor._rawValue)
        guard result >= 0 else { throw Error.current() }
        return Kernel.File.Open.Flags(rawValue: result)
    }
    // ... similar for setFlags, getDescriptorFlags, etc.
}
```

**Pattern uniformity confirmed**: same shape, integer return. The
multi-operation aspect (F_GETFL vs F_SETFL vs F_DUPFD) just produces
multiple L2/L3-policy function pairs within the same family file.

### 5.4 Family — `fstat` (struct-returning — the bifurcation case)

**Current L2** (`/Users/coen/Developer/swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.File.Stats.Get.swift:60`):

```swift
extension ISO_9945.Kernel.File.Stats {
    public static func get(descriptor: borrowing Kernel.Descriptor)
        throws(Kernel.File.Stats.Error) -> Kernel.File.Stats {
        var sb = Darwin.stat()
        guard unsafe (Darwin.fstat(descriptor._rawValue, &sb) == 0) else {
            throw Error(posixErrno: errno)
        }
        return Kernel.File.Stats(from: sb)
    }
}
```

**Cycle B refactored L2** (the bifurcation: raw form is the C `stat`
struct, not an integer):

```swift
extension ISO_9945.Kernel.File.Stats {
    @_spi(Syscall)
    public static func get(fd: Int32, into sb: inout stat) -> Int32 {
        #if canImport(Darwin)
        return unsafe Darwin.fstat(fd, &sb)
        #elseif canImport(Glibc)
        return unsafe Glibc.fstat(fd, &sb)
        // ...
    }
}
```

L2 takes raw `Int32` for the descriptor + an `inout` C `stat` struct
(the kernel writes the result through this pointer); returns `Int32`
(0 on success, -1 with errno on failure). Spec-literal: matches the
C signature `int fstat(int fd, struct stat *sb)`.

**Cycle B new L3-policy wrapper** (`swift-posix/Sources/POSIX Kernel File/POSIX.Kernel.File.Stats.Get.swift`):

```swift
extension POSIX.Kernel.File.Stats {
    public static func get(descriptor: borrowing POSIX.Kernel.Descriptor)
        throws(Kernel.File.Stats.Error) -> Kernel.File.Stats {
        var sb = stat()
        let result = ISO_9945.Kernel.File.Stats.get(fd: descriptor._rawValue, into: &sb)
        guard result == 0 else { throw Error(posixErrno: errno) }
        return Kernel.File.Stats(from: sb)
    }
}
```

**Bifurcation acknowledged but resolved**: the L2-takes-raw pattern
applies, but the "raw" is a C struct (`stat`) rather than an
integer. The L2 wrapper exposes the C struct via an `inout`
parameter (or an `UnsafeMutablePointer`); the L3-policy wrapper
constructs the struct, calls L2, and converts to the typed
`Kernel.File.Stats`. The architectural commitment (typed lives at
L3-policy, raw at L2) is identical; only the raw shape changes.

**`Kernel.Directory.Entry` follows the same bifurcation**: L2's
`readdir` wrapper returns a raw `dirent` (or constructs a struct
mirroring it); L3-policy wraps into typed
`POSIX.Kernel.Directory.Entry` (or `Windows.Kernel.Directory.Entry`).
The 2 typed-parameter sites in iso-9945 + windows-standard's
`Directory.swift` files are dominated by the return-direction usage
(iterating `readdir` to produce typed entries); the refactor moves
the typed-construction step to L3-policy.

### 5.5 Cross-platform consumer surface (the L3-unifier typealias chain)

For every L3-policy type introduced in Cycle B (POSIX wrappers,
Windows wrappers, Linux extras, Darwin extras), the L3-unifier
swift-kernel adds a `#if os(...)`-guarded typealias chain in
`Kernel/Exports.swift`:

```swift
// In swift-kernel/Sources/Kernel/Exports.swift
#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
extension Kernel { public typealias Descriptor = POSIX.Kernel.Descriptor }
extension Kernel.Descriptor { public typealias Validity = POSIX.Kernel.Descriptor.Validity }
extension Kernel.Descriptor.Validity { public typealias Error = POSIX.Kernel.Descriptor.Validity.Error }
extension Kernel.Descriptor { public typealias Duplicate = POSIX.Kernel.Descriptor.Duplicate }
extension Kernel.Descriptor.Duplicate { public typealias Error = POSIX.Kernel.Descriptor.Duplicate.Error }
extension Kernel { public typealias Close = POSIX.Kernel.Close }
extension Kernel.Close { public typealias Error = POSIX.Kernel.Close.Error }
// ... similar for File.Stats, File.Control, Termios, etc.

extension Kernel { public typealias Process = POSIX.Kernel.Process }
extension Kernel.Process { public typealias ID = POSIX.Kernel.Process.ID }
// ... process families

extension Kernel { public typealias Directory = POSIX.Kernel.Directory }
extension Kernel.Directory { public typealias Entry = POSIX.Kernel.Directory.Entry }
#elseif os(Windows)
extension Kernel { public typealias Descriptor = Windows.Kernel.Descriptor }
// ... Windows mirror chains
#endif
```

The typealias chain for nested error types (e.g.,
`Kernel.Descriptor.Validity.Error`) mirrors the L1 nesting through
the L3-unifier. Cross-platform consumers continue to see the same
nested name. The probe at swift-kernel-primitives `f14cf8f` /
`acc42e5` verified this mechanism GREEN 8/8.

### 5.6 Pattern bifurcation summary

| Raw shape at syscall boundary | Examples | L2 signature shape |
|---|---|---|
| Integer (handle / pid / fd) | `close`, `dup`, `dup2`, `dup3`, `fcntl`, sub-cases of `socket`, `pipe` | `(_ fd: Int32) -> Int32` (POSIX) / `(_ handle: UInt) -> Bool` (Windows) |
| C struct (return-via-`inout`) | `fstat`, `lstat`, `readdir` | `(_ fd: Int32, into sb: inout stat) -> Int32` (POSIX) / `(_ data: inout WIN32_FIND_DATAW) -> Bool` (Windows) |
| Pointer-typed handle (no integer cast) | `opendir` returning `DIR*` | `(_ path: UnsafePointer<CChar>) -> OpaquePointer?` (current iso-9945 already exposes the raw `DIR*`) |

All three shapes follow the same architectural commitment: typed at
L3-policy, raw at L2. The bifurcation is a per-syscall raw shape
detail; it does not break the pattern.

### 5.7 Family error type relocation

Pattern B's family error types relocate to L3-policy (Cycle A).
Their nested error types (e.g.,
`Kernel.Descriptor.Validity.Error.Limit`) travel with their
parents — the entire family error tree lives at L3-policy after
Cycle A. The L3-unifier typealias chain (Cycle C) preserves the
cross-platform nested names. From the consumer's perspective,
`Kernel.Descriptor.Validity.Error.Limit` continues to exist and
resolve correctly; only the underlying definition moves.

## 6. RECOMMENDATION

**Status**: RECOMMENDATION (this revision) — Path 1 family-wide.

**Selected variant**: **family-wide cascade** resolving
`Kernel.Descriptor`, `Kernel.Process.ID`, and
`Kernel.Directory.Entry` together via the cycle decomposition in § 4.

**Why family-wide and not descriptor-only**: The generalization check
in § 3.5 + § 3.6 confirmed that `Kernel.Process.ID` follows the
identical L2-takes-raw + L3-policy-wrapper pattern (handle-class
storage, parameter-direction usage, raw `Int32` / `DWORD` at the
syscall boundary). `Kernel.Directory.Entry` follows the bifurcated
form of the same pattern (struct-direction, raw C struct at the
syscall boundary, L3-policy wraps into typed). All three types are
co-located at L1 in `swift-kernel-primitives` as the same
[PLAT-ARCH-005] exception class; they share one architectural
commitment under [PLAT-ARCH-008c]'s "no L1 exceptions" invariant.

Descriptor-only would defer Process.ID + Directory.Entry to
follow-on Research docs, requiring two future cascades that
re-derive the same scope-and-decomposition analysis. Family-wide
collapses three deferred cycles into one, with the per-type sub-cycle
boundaries (B.1-B.6 in § 4.2) preserving the dispatch-granularity
benefit of separate cycles without the overhead of repeated Research
docs.

**Why Path 1 and not Path 2 (DEFER)**: Per the parent direction
captured in `HANDOFF-l2-cascade-recommendation.md` ("Path 1 selected
... Path 2 (DEFER permanently with transition notes) was explicitly
ruled out — user wants momentum"), this RECOMMENDATION operates
within the Path 1 commitment. Path 2's transition-note documentation
(skill cycle `6cc4fde` / `d535ec4`) remains valid as transient
documentation while Cycles A/B/C land; once Cycle C closes, the
transition notes retire per [PLAT-ARCH-008c]'s "no L1 exceptions"
invariant.

**Materially-smaller-than-preliminary acknowledgement**: The v1.0.0
INVESTIGATION abstract framed the cascade as 200+ files / 350-400
total. The empirical census in § 3 establishes the actual scope at
~71 typed-parameter sites + ~6 family-extension files + ~71 new
L3-policy wrappers ≈ ~148 file changes. This is materially smaller
but does not trigger the supervisor's "< 20 L2 typed-parameter
files" threshold for absorbing more scope into Cycle A; Cycle A
remains scoped to the Pattern B relocations, and Cycle B carries the
cascade body.

**Pattern-bifurcation acknowledgement** (per supervisor `ask:`): the
windows-standard L2-split pattern (`1be7df4`) generalizes to
non-`close` syscalls. The bifurcation between handle-returning
(integer raw) and struct-returning (C-struct raw via `inout`) is a
per-syscall raw shape detail (§ 5.6); both shapes fit the same
architectural commitment. The RECOMMENDATION does NOT need to
bifurcate Path 1 itself; it bifurcates only the per-syscall L2
signature shape inside the unified pattern.

**Immediate next dispatch**: Cycle A — see § 4.1 + the companion
`HANDOFF-cascade-cycle-a-execution.md` (drafted alongside this
RECOMMENDATION).

**Subsequent dispatch order**: Cycle B sub-cycles B.1 → B.2 → B.3 →
B.4 → B.5 → B.6, each as its own Cycle B sub-handoff. Cycle C as one
final dispatch after all B-sub-cycles land.

**Audit closure**:
`swift-institute/Audits/swift-primitives-platform-code-inventory.md`
items 1, 2, 7 remain `OPEN — IN MIGRATION` → CLOSED on Cycle C
completion. The audit row text references this RECOMMENDATION as
the dispatching authority.

**Skill-text closure**:
`swift-institute/Skills/platform/SKILL.md` transition notes on
[PLAT-ARCH-005] / [PLAT-ARCH-008c] / [PLAT-ARCH-015] retire on
Cycle C completion (canonical end-state per `6cc4fde`).

## 7. Alternative paths (preserved as historical context, superseded by § 6)

The v1.0.0 INVESTIGATION enumerated two alternatives. Both are
preserved here for historical traceability of the decision; § 6
above commits to Path 1 family-wide and supersedes the v1.0.0 § 6
preliminary recommendation.

### 7.1 Status quo — DEFER indefinitely (handoff Findings Path 2) — SUPERSEDED

Keep `Kernel.Descriptor` (and family) at L1 indefinitely. Skill text
revisions (`6cc4fde`) describe the canonical end state with a
transition note acknowledging the current ecosystem state retains
the L1 type. Audit items 1, 2, 7 stay OPEN — IN MIGRATION pending
this RECOMMENDATION.

**Cost**: zero additional code changes. Skills + audit + this
investigation absorb the documentation burden.

**Risk**: the transitional state persists. Audit cycles re-flag the
L1 conditional types each pass. New L1 types facing the same tension
(future Process.ID, Directory.Entry follow-on cycles) re-litigate
the question case-by-case.

**Why superseded**: per the parent direction in
`HANDOFF-l2-cascade-recommendation.md`, Path 2 was explicitly ruled
out; the user wants momentum on the cascade resolution rather than a
durable transition state.

### 7.2 Inverted — revert `6cc4fde` — SUPERSEDED

Roll back the skill cycle's revisions to [PLAT-ARCH-005] /
[PLAT-ARCH-008c] / [PLAT-ARCH-015]. The L1 exception stays valid per
the original [PLAT-ARCH-005].

**Cost**: revert + new skill cycle. Cycles' worth of recent reflection
and the parallel session's [PLAT-ARCH-008h] / [PLAT-ARCH-008i]
sub-tier framework reference the revised text.

**Risk**: undoes work that completed cleanly. The L1 exception
re-becomes architectural policy rather than residual debt.

**Why superseded**: the skill revision landed cleanly with broad
ecosystem consequence (the within-L3 sub-tier framework anchors on
it); reverting it would re-fragment the architectural framing this
RECOMMENDATION operates within.

## 8. Cross-references

- **Parent**: `l1-types-only-no-exceptions.md` (RECOMMENDATION,
  commit `0666a59`, this repo) — the descriptor migration this
  cascade RECOMMENDATION un-blocks.
- **Within-L3 sub-tier framework** (load-bearing per supervisor
  MUST): `swift-institute/Research/lateral-l3-to-l3-composition-options.md`
  STAMPED 2026-04-26 — Hybrid B+C; swift-posix L3-policy; swift-kernel
  L3-unifier. The cascade design operates within this framework.
- **Skill cycle**: `swift-institute/Skills` `6cc4fde` —
  [PLAT-ARCH-005] / [PLAT-ARCH-008c] / [PLAT-ARCH-015] revised per
  the parent RECOMMENDATION. Subsequent `d535ec4` added transition
  notes.
- **Migration handoff**: `HANDOFF-l1-exception-removal-execution.md`
  — Phase 0 findings + § Findings — DEFERRED close (subordinate
  executor, 2026-04-27) document the cascade discovery. Carries the
  Cycle C consumer-migration inventory (183 import sites).
- **Recommendation handoff**: `HANDOFF-l2-cascade-recommendation.md`
  — supervisor ground-rules block authorizing this RECOMMENDATION
  authoring cycle. Path 1 commitment + family-wide directive
  originate there.
- **Cycle A handoff**: `HANDOFF-cascade-cycle-a-execution.md` —
  drafted alongside this RECOMMENDATION; dispatches the family-extension
  relocation per § 4.1.
- **Compiler probe** (typealias mechanism verification, GREEN 8/8):
  swift-kernel-primitives commits `f14cf8f` / `acc42e5`.
- **Scaffolding commits** (landed, pushed 2026-04-27):
  - `swift-iso-9945`: `b5c0f5f` (L2 raw close), `871d2c0`
    (`@inlinable` fixup)
  - `swift-foundations/swift-posix`: `3357fb5` (POSIX.Kernel.Descriptor
    type), `50e7019` (POSIX family migration)
  - `swift-microsoft/swift-windows-standard`: `1be7df4` (L2 split:
    raw `CloseHandle` retained, throwing wrapper relocated) — the
    canonical worked-example template for the cascade
  - `swift-foundations/swift-windows`: `71e1bbd` (Windows family +
    Close in L3-policy)
- **Skill rules** (revised + transition-noted as of 2026-04-27):
  [PLAT-ARCH-005] (revised), [PLAT-ARCH-008c] (strengthened),
  [PLAT-ARCH-015] (augmented). Transition notes added in skill
  commit `d535ec4`; retire on Cycle C completion.
- **Audit items** (status: OPEN — IN MIGRATION → CLOSED on Cycle C):
  `swift-institute/Audits/swift-primitives-platform-code-inventory.md`
  items 1, 2, 7. Linked back to this doc.
