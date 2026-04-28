# POSIX.Kernel.Descriptor — L2 (iso-9945) vs L3-policy (swift-posix)

<!--
---
version: 1.0.0
last_updated: 2026-04-28
status: RECOMMENDATION
tier: 2
scope: cross-package
parent: ../../swift-primitives/swift-kernel-primitives/Research/l1-types-only-no-exceptions.md
gates: ../../swift-primitives/swift-kernel-primitives/Research/path-x-removal-plan.md
---
-->

## Abstract

The cascade investigation `l1-types-only-no-exceptions.md` v1.1.1 § 5
(2026-04-26) chose L3-policy placement for `POSIX.Kernel.Descriptor`
(in `swift-posix`) under a stipulated framing: close-on-deinit RAII is
the same kind of policy as EINTR retry. This doc audits that choice's
rationale, classifies each cited argument as load-bearing or
pattern-inherited, scrutinizes the empirical-policy depth of
close-on-deinit, evaluates the L2 (iso-9945) alternative against the
4 sub-questions in the principal's investigation brief, and arrives
at a RECOMMENDATION suitable for stamping the post-Path-X cleanup
target without re-litigation.

**Stamped destination**: `POSIX.Kernel.Descriptor` belongs at L2
(iso-9945), not L3-policy. The l1-types-only-no-exceptions § 5
rationale is dominantly pattern-inherited; the symmetry argument
elides the type-level vs function-level policy distinction that
makes the structural call.

**Pivot timing**: status quo (sub-cycle 1.1 continues at the L3-policy
Pattern A shape). Defer the L2 retroactive-re-typing to a Phase 4 /
post-Cycle-23 cleanup cycle. The pivot cost is real (~25 already-landed
commits across 4 repos + 3 platform-skill rule re-revisions) and Phase
1 momentum is the cheaper resource to preserve. The destination stamp
in this doc is the deliverable's primary value — the principal-time
decision was about WHERE the type lives end-state, not WHEN the move
happens.

## Context

Path X Phase 1 mid-execution. Sub-cycle 1.7 just completed; sub-cycle
1.1 (File, 17 files, largest cluster) is queued next but PAUSED pending
this investigation. Across 7 landed sub-cycles + 2 typed-socklen
follow-up trios + the lateral-L3 sub-tier framework stamp + the
L1-types-only-no-exceptions skill cycle, the L3-policy descriptor
placement has been the canonical assumption since 2026-04-26. The
user's Wave D dup3 escalation (2026-04-28) surfaced a long-standing
architectural concern about raw `Int32` at L2:

> *"my instinct tells me the srcFd: Int32 and destFd: Int32, and ANY
> such Int32 use at L2 should be avoided. This is not policy to me,
> this is providing a modern swift API wrapping layer at L2, which IS
> what we want."*

The principal explicitly framed the investigation question as **L2 vs
L3-policy** for `POSIX.Kernel.Descriptor` and rejected the per-L2 split
(separate `Linux.Kernel.Descriptor` + `Darwin.Kernel.Descriptor`)
strawman. The deliverable's job is to make the rationale for the
chosen direction load-bearing so the post-Path-X cleanup cycle does
not re-derive it.

## Question

Where should `POSIX.Kernel.Descriptor` ultimately live?

(a) **L2** (`swift-iso/swift-iso-9945` ISO 9945 Core target) — the
spec-mirroring layer. iso-9945 hosts the type with platform-native
`Int32` storage and POSIX `close()`-on-deinit policy. swift-posix
becomes thinner: hosts only function-level genuine policy
(EINTR-retry wrappers, partial-IO-loop, error normalization).

(b) **L3-policy** (`swift-foundations/swift-posix` POSIX Kernel
Descriptor target) — status quo per
`l1-types-only-no-exceptions.md` § 5 Branch (i). swift-posix hosts
the type AND the typed-Descriptor wrappers around iso-9945's raw
`Int32` SPI forms.

The user's per-L2 split (separate `Linux.Kernel.Descriptor` +
`Darwin.Kernel.Descriptor`) was rejected by the principal in scope
item 4 and is documented in § Per-L2 Split Rejection below.

## Analysis

### Rationale Audit — `l1-types-only-no-exceptions.md` § 5 (verbatim)

The doc explicitly enumerates two branches and recommends Branch (i)
[Verified: 2026-04-28 against `l1-types-only-no-exceptions.md` v1.1.1
§ 5 lines 119-160]:

> ## 5. The Load-Bearing Sub-Decision: deinit-close = policy or raw?
>
> The chain endpoint depends on a conceptual call about what
> `deinit`-closing RAII counts as in the L2/L3-policy framing.
>
> ### Branch (i) — deinit-close is POLICY → endpoint is L3-policy
>
> `POSIX_Kernel_Descriptor` lives in `swift-posix` (L3-policy) with
> `Int32` raw + POSIX deinit-close. `Windows_Kernel_Descriptor` lives
> in `swift-windows` (L3-policy) with `UInt` raw + `CloseHandle`
> deinit. `swift-kernel` typealias resolves cross-platform.
>
> L2 (iso-9945, windows-standard) keeps its current "raw spec encoding
> only" framing — no carve-out needed. Cleanly covered by
> [PLAT-ARCH-008e] (L3-unifier composes L3-policy).
>
> ### Branch (ii) — deinit-close is RAW Swift encoding → endpoint is L2
>
> `POSIX.Kernel.Descriptor` lives in `iso-9945` (L2) with deinit-close
> embedded. Requires explicit carve-out: "RAII / `~Copyable` deinit
> counts as raw Swift idiom, not policy."
>
> ### Recommendation: (i)
>
> Both branches are coherent. (i) is structurally preferable because:
>
> 1. **No principled (raw-Swift-idiom) vs (policy-Swift-idiom)
>    distinction exists.** RAII auto-close and EINTR retry are both
>    deliberate decisions about how to handle concerns the raw spec
>    leaves to the caller. Splitting them as "raw" vs "policy" requires
>    a line drawn by stipulation, not principle.
> 2. **Symmetry.** An EINTR-retrying `read()` wrapper in swift-posix is
>    policy. A close-on-deinit wrapper around Int32 is the same kind of
>    policy: choosing a Swift-idiomatic handling for a concern not
>    forced by the spec.
> 3. **L2 stays minimal.** "Raw spec encoding, nothing else" is a
>    stronger and more auditable framing than "raw spec encoding plus
>    RAII but not other Swift idioms."
> 4. **swift-posix is the natural home.** swift-posix already exists as
>    a per-domain-variant package ("POSIX Kernel File", "POSIX Kernel
>    Process", etc.). `POSIX_Kernel_Descriptor` is a "POSIX Kernel
>    Descriptor" target — drops in.

The cascade investigation `l1-types-only-no-exceptions-l2-cascade.md`
v2.0.2 (now SUPERSEDED by `path-x-removal-plan.md`) inherited this
choice and applied it uniformly to the close / dup / fcntl / fstat
families [Verified: 2026-04-28 against cascade doc § 5.1-5.7]. The
cascade doc adds NO new rationale for L3-policy; it operationalizes
the parent's choice.

### Classification of the four arguments per [HANDOFF-018] / [FREVIEW-012]

| # | Argument | Classification | Reasoning |
|---|----------|----------------|-----------|
| 1 | "No principled distinction between raw-Swift-idiom and policy-Swift-idiom" | **Meta — pattern-inherited** | The argument is *"the boundary is stipulated, not principled"*. Logically symmetric — it argues equally well for either direction. Cuts both ways; not a selector. |
| 2 | "Symmetry: EINTR retry = close-on-deinit = same kind of policy" | **Plausibly load-bearing IF accepted as stated; ELIDES a structural distinction** | EINTR retry is *function-level* policy (wraps a single syscall site); close-on-deinit is *type-level* commitment (defines lifetime semantics of the type). Function-level policy can be added at any layer above the syscall; type-level policy can ONLY be defined where the type is defined. The argument elides this distinction. (See § Empirical Scrutiny below.) |
| 3 | "L2 stays minimal" | **Aesthetic / pattern-inherited** | The framing "L2 = raw spec encoding, nothing else" is itself the rule the doc proposes. iso-9945 today already hosts typed `Kernel.Path.Borrowed`, `Kernel.File.Permissions`, `Kernel.File.Size`, `Kernel.Termios.Attributes`, and many other typed surfaces; the "minimal L2" framing is contradicted by current ecosystem state. |
| 4 | "swift-posix is the natural home" (already a per-domain-variant package) | **Convenience / pattern-inherited** | An argument from convenience: the package exists, so dropping descriptor in is easy. Same logic could argue iso-9945 is the natural home (POSIX = ISO 9945 — the spec the package mirrors). Pattern-inherited from the existing swift-posix structure, not derived from descriptor's own properties. |

**One of four arguments** is potentially load-bearing (Argument 2). The
other three are meta / aesthetic / convenience. § Empirical Scrutiny
demonstrates that Argument 2 elides a structural distinction that
flips the conclusion.

### Empirical Scrutiny — How much policy IS in close-on-deinit?

**The actual deinit body** [Verified: 2026-04-28 against
`swift-foundations/swift-posix/Sources/POSIX Kernel Descriptor/POSIX.Kernel.Descriptor.swift:59-65`]:

```swift
deinit {
    guard isValid else { return }
    // L3-policy → L2 raw: spec-literal close. deinit can't throw, so
    // ignore the result. Application code wanting close-with-error
    // reporting calls POSIX.Kernel.Close.close(_:) explicitly.
    _ = Kernel.Close.close(_raw)
}
```

Three lines. The "policy content" decomposes as:

| Line | Content | Forced or chosen? |
|------|---------|-------------------|
| `guard isValid else { return }` | Skip close on already-invalid sentinel (`-1`) | Forced — closing `-1` would set errno but does no useful work |
| `_ = Kernel.Close.close(_raw)` | Call `close(2)` via L2 raw SPI | Forced once RAII is committed — there is no other meaningful action |
| `_ = ...` (drop result) | Ignore close-failure | Forced — deinit cannot throw in Swift |

The "policy choice" reduces to a single bit: **commit to RAII close**
or **don't**. Once committed, the implementation is mechanical.
Compare to `POSIX.Kernel.IO.Read.swift` [Verified: 2026-04-28]:

> *"These are policy-aware wrappers around the raw POSIX syscalls in
> `Kernel.IO.Read`. They automatically retry on EINTR (signal
> interruption), which is the expected behavior for most applications."*

The EINTR retry is genuine policy: the syscall semantic forces the
caller to choose retry-vs-fail-fast; the wrapper picks retry; the
implementation is a `while true { do {...} catch where ...EINTR
{ continue } }` loop with substantive state. Multiple alternative
implementations exist (give-up-on-first-EINTR, retry-with-bounded-
attempts, retry-with-exponential-backoff). The wrapper makes a real
choice.

Compare also to `POSIX.Kernel.Lock.swift` [Verified: 2026-04-28
against
`swift-foundations/swift-posix/Sources/POSIX Kernel Lock/POSIX.Kernel.Lock.swift:53-59`]:

```swift
public static func lock(
    _ descriptor: borrowing POSIX.Kernel.Descriptor,
    range: Range,
    kind: Kind
) throws(Error) {
    try ISO_9945.Kernel.Lock.lock(fd: descriptor._rawValue, range: range, kind: kind)
}
```

The L3-policy `POSIX.Kernel.Lock.lock` is a one-line typed-Descriptor
unwrap — NO retry, NO backoff, NO normalization. The principal's
investigation brief mentioned "POSIX.Kernel.Lock with its
acquireWithDeadline deadline-polling backoff loop" — that backoff loop
DOES NOT EXIST in the current swift-posix code. The Lock wrapper at
L3-policy is purely a typed-Descriptor adapter.

**Empirical thresholds for "is this enough policy to require L3-policy
hosting?"**:

| Pattern | Site | Policy depth | L3-policy belongs here? |
|---------|------|--------------|-------------------------|
| EINTR retry | `POSIX.Kernel.IO.Read.read(_:into:)` | Substantive — explicit retry loop, EINTR-handling, alternative-implementation choice space | **Yes** — function-level policy added at the wrapping layer |
| Partial-IO loop | `POSIX.Kernel.File.Handle.writeAll` (similar shape) | Substantive — write-loop-until-fully-written | **Yes** — function-level policy |
| Error normalization | (cross-layer error mapping) | Substantive — POSIX-specific error catalog | **Yes** — function-level policy |
| Typed-Descriptor unwrap | `POSIX.Kernel.Lock.lock` (current shape) | Trivial — single line `_rawValue` extraction | **Borderline** — could equally live at L2 if iso-9945 takes typed Descriptor |
| `~Copyable` close-on-deinit | `POSIX.Kernel.Descriptor.deinit` | Trivial — RAII commitment + 3 mechanical lines | **No** — type-level commitment belongs with type definition |

The threshold sits between rows 3 and 4. Rows 1-3 (function-level)
are unambiguously L3-policy. Rows 4-5 (type-level + trivial unwrap)
are not policy in the same sense.

### The Type-Level vs Function-Level Distinction (the elision)

`l1-types-only-no-exceptions.md` § 5's Argument 2 ("symmetry") asserts
EINTR retry and close-on-deinit are "the same kind of policy." The
empirical reading reveals they are different kinds:

| Property | EINTR retry | close-on-deinit RAII |
|----------|-------------|----------------------|
| Where defined | Function body of the wrapping `read(_:into:)` static | `deinit` of the `~Copyable` type |
| Layered re-definition | A higher layer can wrap with different retry policy | The owning type's `deinit` is the only deinit; cannot be re-defined |
| Decision space | Multiple meaningful alternatives (no-retry, bounded-retry, exponential-backoff) | One bit (commit to RAII or don't) |
| Implementation depth | Substantive (loop + state) | Trivial (one syscall + ignore-result) |
| Locus | Function call site | Type lifetime |

Function-level policy is COMPOSITIONAL — added at any layer above the
syscall by wrapping. Type-level commitment is OWNERSHIP-DEFINED — the
type's owner declares it once; consumers receive it.

**Implication for layer placement**: type-level commitments belong
WITH the type definition. If the descriptor's deinit is part of the
descriptor's contract, then the layer that defines the descriptor IS
the layer that commits to RAII close. There is no meaningful
"raw-without-RAII descriptor" that swift-posix could compose into a
"with-RAII descriptor" — RAII is structural to the type, not a
function applied to it.

The corollary: **the layer that wants to host RAII must host the type
definition**. iso-9945 (L2) and swift-posix (L3-policy) are both
candidates. The choice between them is not "where does policy live"
(both could host the deinit); it is "where does the type live" (the
type can only have one home).

The argument-2 symmetry framing obscured this: it argued by analogy
to function-level policy without noting that the analogy fails for
type-level commitments.

### L2 Placement Alternative

#### (3a) Mechanical feasibility

Per Package.swift inspection [Verified: 2026-04-28 against
`swift-iso/swift-iso-9945/Package.swift` ISO 9945 Core target deps]:

```swift
.target(
    name: "ISO 9945 Core",
    dependencies: [
        .product(name: "Kernel Primitives Core", package: "swift-kernel-primitives"),
        .product(name: "Kernel Descriptor Primitives", package: "swift-kernel-primitives"),
        .product(name: "Kernel Error Primitives", package: "swift-kernel-primitives"),
        // ... + Kernel File / IO / Memory / Path / Permission / Process / Socket / Tagged
    ]
)
```

iso-9945 ISO 9945 Core has all dependencies needed for L2 placement:
- `Kernel_Descriptor_Primitives` — for the `Kernel` namespace (post-Path-X-Cycle-19 the `Descriptor` type itself moves; namespace shell stays)
- `Kernel_Error_Primitives` — for `Kernel.Error.Code`
- `Kernel_File_Primitives` — for `Kernel.Close` namespace
- internal `import Glibc` / `Musl` / `Darwin` for errno
- `Sendable` from stdlib

The target ALREADY hosts policy-bearing typed surfaces:
- `ISO_9945.Kernel.Descriptor.Validity.Error.init?(code:)` — error mapping logic
- `ISO_9945.Kernel.Process.Group.ID = Tagged<...>` — typed phantom value
- `ISO_9945.Kernel.Termios.Attributes.get(_ descriptor: borrowing Kernel.Descriptor)` — currently typed-parameter (pre-Pattern-A)

Adding `POSIX.Kernel.Descriptor` (or extending the iso-9945 namespace
to host it) is mechanically a thin extension of existing patterns, not
a new architecture.

#### (3b) Transitive resolution via [PLAT-ARCH-007]

Per [PLAT-ARCH-007] (POSIX Code Belongs in ISO 9945) [Verified:
2026-04-28 against `platform` skill rule body], iso-9945 IS the shared
POSIX layer that swift-darwin and swift-linux both depend on. Both
platform packages already import iso-9945 transitively; placing
`POSIX.Kernel.Descriptor` at iso-9945 makes it visible to both
platforms via the existing dep chain — same visibility as the current
swift-posix placement, but at L2 instead of L3-policy.

windows-standard is correctly excluded — Windows is not POSIX. The
proposed placement leaves `Windows.Kernel.Descriptor` in
windows-standard (L2) or swift-windows (L3-policy) per a separate
decision; this investigation scopes to the POSIX side only.

#### (3c) Cycle 19 typealias compatibility

Per `l1-types-only-no-exceptions.md` § 6.2.1 the typealias mechanism
was probe-verified GREEN 8/8 (`f14cf8f` / `acc42e5`):

```swift
// swift-kernel/Sources/Kernel/Exports.swift
@_exported public import Kernel_Primitives
#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    @_exported public import POSIX_Kernel_Descriptor
    public typealias Kernel_Descriptor = POSIX.Kernel.Descriptor   // Cycle 19 target
#elseif os(Windows)
    @_exported public import Windows_Kernel_Descriptor
    public typealias Kernel_Descriptor = Windows.Kernel.Descriptor
#endif
```

The typealias resolves to whatever module-and-type the right-hand
side names. Whether `POSIX.Kernel.Descriptor` lives in
`POSIX_Kernel_Descriptor` (current — swift-posix) or in `ISO_9945_Core`
(L2-proposed — swift-iso-9945), the typealias mechanism works
identically: import the module that defines the type, alias it. The
8/8 GREEN matrix did not depend on which layer the type lived at;
it depended on the typealias-on-`~Copyable` mechanism.

L3-unifier swift-kernel already depends on iso-9945 via the
import chain (swift-kernel imports Linux/Darwin Kernel which import
swift-iso-9945). No new dependency required.

**Mechanical verdict**: L2 placement works. The typealias chain at
swift-kernel collapses cleanly to the L2-resident type.

### Per-L2 Split Rejection

The user's brief flagged this for explicit rejection:

> Per-L2 typed-descriptor split (the [PLAT-ARCH-015] direction I
> floated earlier as a strawman): explicitly REJECTED because
> Linux/Darwin/POSIX descriptors are semantically identical (unlike
> Thread.IDs which differ genuinely). Cite this rejection in the doc
> to prevent future rediscovery.

Per [PLAT-ARCH-015] (Per-L2 Platform-Native Typed Values) [Verified:
2026-04-28 against `platform` skill rule body], per-L2 split applies
when the type's *raw representation genuinely differs per platform* —
e.g., `Kernel.Thread.ID` is `mach_port_t` (Mach kernel) on Darwin vs
`pid_t` (Linux tid namespace) on Linux. The bit pattern means
different things; per-L2 typed values preserve domain identity.

Descriptors do NOT have this property on POSIX:

| Property | POSIX Darwin | POSIX Linux | Same? |
|----------|--------------|-------------|-------|
| Type | `int` | `int` | Yes |
| Width | 32-bit | 32-bit | Yes |
| Sentinel | `-1` | `-1` | Yes |
| Allocator | kernel | kernel | Yes |
| Close primitive | `close(2)` | `close(2)` | Yes |
| Spec authority | POSIX 1003.1 | POSIX 1003.1 | Yes |

Linux IS POSIX-compliant. The descriptor allocation, lifetime, and
close semantics are identical on both platforms. There is no domain
identity to preserve via per-L2 split.

**Rejection rationale**: Per-L2 split (`Linux.Kernel.Descriptor` +
`Darwin.Kernel.Descriptor`) would be redundant — both types would be
identical `Tagged<…, Int32>` with identical `close()`-on-deinit. The
split would add namespace surface without adding semantic content.
[PLAT-ARCH-015]'s threshold (genuinely-different raw shape) is not
met.

The investigation question is binary: L2 (single shared
`POSIX.Kernel.Descriptor` in iso-9945) vs L3-policy (single shared
`POSIX.Kernel.Descriptor` in swift-posix). The split-into-three is
not a candidate.

### Cost Analysis

#### Empirical scope of the L3-policy → L2 retroactive re-typing

Per [HANDOFF-024] empirical-grep-first against the 7 landed sub-cycles
+ follow-ups [Verified: 2026-04-28 against
`HANDOFF-path-x-phase-1.md` Findings table + `HANDOFF.md` Current
State]:

| Sub-cycle | iso-9945 commits | swift-posix commits | Sites |
|-----------|------------------|---------------------|-------|
| 1.6 Poll + Directory | `e4d45fd` + `94499d0` | `613c9da` + `b722760` | 2 |
| 1.3 Terminal | `3dd5e3b` | `e76e045` | 2 |
| 1.5 Lock | `2109ccf` | `1d0f660` + `b2c1801` | 2 |
| 1.4 Memory | `f2473fc` + `14bfe6d` | `b2c1801` | 2 |
| 1.8 Darwin | `b5e14b4` | `44b74ed` | 3 |
| 1.2 Socket | `293c6ba` | `3d68a49` | 6 |
| 1.2 socklen follow-up | `5bd0937` | `bf08689` + sockets `703d0b1` | 13 |
| 1.7 prereq + waves | linux-standard `f2959bc` + `1105811` + `b0f1db0` | linux `cfc6508` | 11 |
| **Total** | **12 commits across 3 repos** | **9 commits across 2 repos** | **41 sites** |

Plus 2 platform-skill-rule revisions ([PLAT-ARCH-005] revised,
[PLAT-ARCH-008c] strengthened, [PLAT-ARCH-015] augmented in commit
`6cc4fde`) that pinned the L3-policy choice in skill text.

#### Pivot-now (option b) cost

Retro-re-typing across 21 commits in 5 repos:
- iso-9945: re-introduce typed `Kernel.Descriptor` parameters at the
  41 sites; un-strip the Pattern A raw fd SPI forms (or keep both
  with `@_disfavoredOverload`).
- swift-posix: delete the L3-policy compat wrappers that were the
  Pattern A's L3-policy half (their job is preserving typed call shape
  — if iso-9945 takes typed, no wrapper needed). ~21 wrapper sites to
  delete.
- swift-linux-standard: re-introduce typed `Kernel.Descriptor` at the
  ~11 sites stripped in 1.7.
- swift-linux: delete the 5 compat wrappers added in 1.7 swift-linux
  side.
- swift-darwin-standard, swift-darwin: similar (1.8 sub-cycle).
- swift-sockets: revert to typed Length consumers if applicable.
- Platform skill rules ([PLAT-ARCH-005] / [008c] / [015]): re-revise
  to authorize L2 placement; current text mandates L3-policy.

Bounded ~30 commits worth of retroactive churn.

Plus sub-cycle 1.1 (17 files, queued) lands at L2 typed shape —
ZERO Pattern A strip needed. Saves ~14 commits worth of work that
status-quo would require.

Plus all future Path X cycles 2-23 (Process.ID + Directory.Entry
families + further L1 type relocations) land at L2 directly —
saves the Pattern A detour for each cycle.

**Net pivot cost**: ~30 retroactive commits. Saves ~14 commits in 1.1
+ unbounded savings in cycles 2-23 (assuming similar Pattern A scope
per cycle). Plausibly net-zero or net-positive over Path X
completion.

#### Status-quo (option a) cost

Sub-cycle 1.1 lands at L3-policy Pattern A shape. ~17 files +
companion swift-posix wrappers. Estimated ~4-6 commits.

Cycles 2-23 continue the L3-policy pattern. Estimated ~30-50
additional sub-cycles + companion commits across Path X completion.

Post-Cycle-23 cleanup pass: delete all L3-policy compat wrappers,
re-type all iso-9945 surfaces to take typed `POSIX.Kernel.Descriptor`,
re-revise skill rules. Estimated ~50-80 commits as one big sweep.

**Net status-quo cost**: ongoing per-sub-cycle Pattern A overhead +
big sweep at end. Total similar to pivot-now but spread differently.

#### Cost-difference summary

The work-volume difference between the two paths is **small** —
likely within one standard deviation of estimation noise. The TIMING
differs:

- **Pivot now**: front-loads ~30 commits of churn; saves per-cycle
  Pattern A overhead going forward; smaller cleanup at end.
- **Keep status quo**: amortizes per-cycle Pattern A overhead; one
  large cleanup sweep at end.

The real differentiator is not work-volume but *Phase 1 momentum
risk*. Pivoting mid-Phase-1 invalidates 7 sub-cycles' worth of just-
reviewed-and-merged work; the principal commended sub-cycle 1.7 as
"solid work" earlier this session. Re-litigating that work has a
non-zero psychological / review-trust cost beyond the mechanical
churn.

## Outcome

**Status**: RECOMMENDATION

### Stamped destination: L2 (iso-9945)

`POSIX.Kernel.Descriptor` belongs at **L2 (iso-9945)** end-state.

**Load-bearing rationale**:

1. **Type-level commitment vs function-level policy** (the elision in
   l1-types-only-no-exceptions.md § 5 Argument 2). RAII close-on-deinit
   is type-level — defined ONCE by the type's owner, cannot be re-
   defined by composers. The layer that owns the type owns the deinit.
   iso-9945 owns the spec-mirroring `Kernel.Descriptor` namespace and
   IS the canonical home for POSIX-spec types.
2. **iso-9945's existing typed surface is already substantial**.
   `Kernel.Path.Borrowed`, `Kernel.File.Permissions`, `Kernel.File.Size`,
   `Kernel.Termios.Attributes`, `Kernel.Process.Group.ID =
   Tagged<…, Int32>`, and the `ISO_9945.Kernel.Descriptor.Validity.Error.init?(code:)`
   policy mapping all live at L2 today. "L2 stays minimal" (Argument
   3) is contradicted by current ecosystem state. Adding
   `POSIX.Kernel.Descriptor` at L2 is consistent with the substantial
   typed surface already there.
3. **swift-posix's natural-home argument (Argument 4) reverses
   under-spec-mirroring naming**. POSIX = ISO 9945. The
   "POSIX Kernel Descriptor" target name in swift-posix is a copy of
   "ISO 9945 Kernel Descriptor" (the namespace already in iso-9945).
   The natural home is wherever the spec lives.
4. **Mechanical feasibility verified**: ISO 9945 Core has all required
   deps; Cycle 19 typealias chain works identically against L2-resident
   type per the 8/8 GREEN probe.

### Rejected: L3-policy as long-term home

The l1-types-only-no-exceptions § 5 rationale catalogs as:
- 3 of 4 arguments (Arguments 1, 3, 4) are pattern-inherited / aesthetic
  / convenience.
- 1 of 4 arguments (Argument 2 "symmetry") is plausibly load-bearing
  but elides the type-level vs function-level distinction; once the
  distinction is named, the symmetry argument inverts (type-level
  commitments do NOT compose like function-level policies).

The L3-policy choice was correct for v1.1.1's framing (deinit-close as
analogous to retry policy), but the analogy is structurally flawed.

### Pivot timing: status quo (defer to post-Cycle-23 cleanup)

Sub-cycle 1.1 SHOULD continue at the current L3-policy Pattern A
direction. Reasons:

1. **Cost-analysis is roughly symmetric**: the work-volume between
   pivot-now and status-quo + post-Cycle-23 cleanup is within one
   estimation standard deviation. The structural-correctness argument
   is necessary and sufficient to STAMP the destination; it does not
   uniquely determine timing.
2. **Phase 1 momentum is non-substitutable**: 7 sub-cycles + 1.7 just
   landed cleanly with positive principal review. Pivoting mid-Phase-1
   invalidates that reviewed work and adds review-trust friction
   beyond the mechanical churn. Per [RES-022], structural correctness
   over diff-size in selecting the destination — but timing is a
   separate axis where momentum is a legitimate input.
3. **Reversibility is symmetric**: post-Cycle-23 cleanup re-types L2
   in one mechanical sweep. The cleanup work is already on the
   roadmap (HANDOFF.md Open Question 3). Stamping the L2 destination
   in this doc means the cleanup proceeds to the agreed target without
   re-litigation — which is the deliverable's primary value.
4. **The user's prior framing** (HANDOFF.md Open Question 3, written
   pre-investigation) preferred deferral: *"a coherent architectural
   pivot worth doing as a piece, post-Cycle-23."* This investigation
   surfaces no NEW evidence overturning that preference; it provides
   the load-bearing rationale for the L2 destination that the prior
   framing assumed.

**Pivot-now (option b) is acceptable** if the principal weighs Phase
1.5 cleanup as cheaper than post-Cycle-23 cleanup. The two options
land at the same end-state; this investigation does not block either.

### Implications

If the principal authorizes (a) status-quo:
- Sub-cycle 1.1 dispatches at L3-policy Pattern A shape per current
  HANDOFF.md plan.
- Post-Cycle-23 cleanup cycle dispatches against the L2 destination
  stamped here. No re-litigation of the placement question.
- Open Question 3 in HANDOFF.md updated to cite this RECOMMENDATION
  as the load-bearing destination stamp.

If the principal authorizes (b) Phase 1.5 retroactive re-typing:
- Sub-cycle 1.1 PAUSED until Phase 1.5 lands.
- Phase 1.5 dispatches a new investigation handoff with empirical
  scope (~30 commits across 5 repos).
- Skill rules ([PLAT-ARCH-005], [PLAT-ARCH-008c], [PLAT-ARCH-015])
  re-revised to authorize L2 placement.
- Sub-cycle 1.1 + Cycles 2-23 land at L2-typed shape going forward.

### What does NOT change either way

- Path X plan (`path-x-removal-plan.md` v1.2.0) still mandates L1
  swift-kernel-primitives deletion at Cycle 23. The L2 vs L3-policy
  question is orthogonal to the L1 deletion timeline.
- Cycle 19 typealias swap target (the `extension Kernel { typealias
  Descriptor = ... }` mechanism) is mechanically identical against
  either placement. The 8/8 GREEN probe stands.
- The lateral-L3 sub-tier framework
  (`lateral-l3-to-l3-composition-options.md` STAMPED 2026-04-26)
  remains valid. swift-posix L3-policy hosts the function-level genuine
  policy (EINTR retry, partial-IO loop, error normalization) regardless
  of where descriptor types live. Moving descriptor types out of
  swift-posix DOES NOT destabilize the sub-tier framework.

## References

- `swift-primitives/swift-kernel-primitives/Research/l1-types-only-no-exceptions.md`
  v1.1.1 RECOMMENDATION (parent doc; § 5 Branch (i) chosen — this
  RECOMMENDATION re-evaluates that choice).
- `swift-primitives/swift-kernel-primitives/Research/l1-types-only-no-exceptions-l2-cascade.md`
  v2.0.2 SUPERSEDED (cascade investigation — inherited the L3-policy
  choice; § 5.1-5.7 worked examples).
- `swift-primitives/swift-kernel-primitives/Research/path-x-removal-plan.md`
  v1.2.0 RECOMMENDATION (the Path X destination plan; supersedes the
  cascade investigation).
- `swift-institute/Research/lateral-l3-to-l3-composition-options.md`
  STAMPED 2026-04-26 (codifies L3-policy / L3-unifier sub-tier
  framework — independent of the L2 vs L3-policy descriptor question).
- `swift-institute/Research/path-x-prerequisite-stabilization.md`
  v1.0.0 RECOMMENDATION (Path X gating doc; descriptor migration's
  cascade is "Sub-task B" / "Sub-task C").
- `swift-institute/Research/Reflections/2026-04-26-l1-exception-removal-skill-cycle.md`
  (the skill cycle that codified [PLAT-ARCH-005] revised /
  [PLAT-ARCH-008c] strengthened / [PLAT-ARCH-015] augmented per the
  parent doc's § 8).
- `HANDOFF-path-x-phase-1.md` Findings (record of 6 + 1 sub-cycles +
  follow-ups landed at L3-policy shape).
- `HANDOFF.md` Open Question 3 (user's prior transitional flag —
  "post-Cycle-23 architectural cleanup cycle"; this RECOMMENDATION
  provides the load-bearing destination stamp).
- `HANDOFF-posix-descriptor-l2-vs-l3policy.md` (this investigation's
  branching brief).
- Live source verified inline via `[Verified: 2026-04-28]` tags above.
