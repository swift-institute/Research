# Memory.Cursor Generic-Witness Demangle — Bridge-Revival Feasibility

<!--
---
version: 1.0.0
last_updated: 2026-05-31
status: RECOMMENDATION
tier: 2
scope: cross-package
supersedes_note: "Extends swift-institute/Research/memory-cursor-generic-witness-demangle-reshape.md (v1.0.0, 2026-05-28) and swift-compiler-bug-catalog.md §A12 with a current-toolchain (6.3.2 / 6.4-dev / 6.5-dev) re-reproduction. Does not supersede either; it resolves the toolchain-currency half of the open /issue-investigation."
changelog:
  - "1.0.0 (2026-05-31): Re-investigation on current toolchains via a detached git worktree of swift-buffer-linear-primitives (real package never modified). NOT FIXED through 6.5-dev 2026-05-12-a. New finding: on +assertions nightlies the defect manifests as a COMPILE-TIME mangler round-trip abort (Mangler.cpp:176), earlier than 6.3.2's runtime SIGABRT — same defect class, caught earlier. Controls A/B/C clean; E inconclusive (unrelated infra block). Diverges from sibling §A9 (fixed by 6.4-dev). Disentangled from swiftlang/swift#86652 via the -disable-llvm-verify double-dissociation control. Verdict: revival of the lazy Memory.Cursor bridge is NOT feasible on any current toolchain; keep the per-type scalar workaround; the snapshot reshape is the available demangle-safe dedup path."
---
-->

> **Status**: RECOMMENDATION. Re-investigation of whether the dormant
> `Memory.Cursor → Sequenceable` bridge can be revived on current Swift. Verdict:
> **not feasible on any toolchain through 6.5-dev `2026-05-12-a`** — keep the workaround.
> No production code was changed; the reproduction ran entirely in a throwaway git
> worktree (since removed). Nothing committed, nothing filed upstream.

## TL;DR

- The bug that made the bridge dormant is **still present on every current toolchain**:
  Swift 6.3.2 (Xcode default), 6.4-dev `2026-03-16-a`, 6.4-dev `2026-05-07-a`, and the
  latest 6.5-dev `2026-05-12-a`. **It is not fixed.**
- **New manifestation**: on the `+assertions` dev nightlies the defect now surfaces as a
  **compile-time** abort in the compiler's own name mangler (`Abort: function verify at
  Mangler.cpp:176` → `Can't demangle: …`), *earlier* than the 6.3.2 release-runtime
  SIGABRT. The compiler's round-trip self-check rejects the name it just emitted — direct,
  on-its-face evidence that the locus is **compiler emission**, not the runtime demangler.
- **Root cause re-confirmed**: IRGen emits a malformed associated-type-witness mangled name
  for the **deep generic instantiation** `Memory.Cursor<Buffer<A>.Linear.Inline<capacity>>`
  used as the `Sequenceable.Iterator` witness. Controls show neither `Memory.Cursor`,
  genericity, nor the bridge is the trigger — only the deep value-generic nested
  instantiation is.
- **Divergence from the sibling §A9 bug**: §A9 (`Atomic<Tagged<…>>`, the same emission
  *class*) was fixed by 6.4-dev; §A12 was **not** — it still aborts on `2026-03-16-a`, the
  very nightly that fixed §A9.
- **Verdict**: lazy-`Memory.Cursor` revival is **not feasible** (case b/d). The
  demangle-safe **snapshot reshape** (`Memory.Snapshot.Cursor`, already committed to HEAD)
  is the available generic dedup path if the ecosystem ever wants to retire the per-type
  scalar iterators (case c) — at one eager `[Element]` allocation each.

## Context

The memory→`Sequenceable` bridge (`swift-memory-sequence-primitives`) is the consuming dual
of the active memory→`Iterable` bridge. The `Iterable` bridge vends `makeIterator()` for
free because its iterator (`Iterator.Chunk`) is a **concrete** span struct. The
`Sequenceable` bridge's consuming iterator is the **generic** `Memory.Cursor<Self>`, which
crashes at runtime for the contiguous inline conformer — so the bridge was left **dormant**
and production dodges it with hand-written per-type concrete scalar iterators
(`Buffer.Linear.Inline.Scalar`, etc.).

The prior investigation (2026-05-28) reproduced the crash on the literal
`Buffer.Linear.Inline` and found a working reshape, but tested only on Swift 6.3.2. The
cataloged dev-toolchain status (`2026-03-16-a`) was ~2.5 months stale and *inherited* from a
synthetic-only pass, never a fresh literal-type run. This re-investigation answers: **is the
emission fixed on a current nightly, such that the bridge could be revived?** (Trigger: the
user's "seems weird it doesn't work.")

**Prior art** (read first per [RES-019]/[HANDOFF-013a]; verified against current source 2026-05-31):

- `swift-institute/Research/swift-compiler-bug-catalog.md` §A12 (this bug) and §A9 (sibling
  emission class — `Atomic<Tagged<…>>`, with the 2026-05-28 correction establishing the locus
  is *emission*, not the runtime demangler, and that the PR #87066/`bc44d42f11` demangler-fix
  theory was a wrong, untested code-search heuristic).
- `swift-institute/Research/memory-cursor-generic-witness-demangle-reshape.md` (v1.0.0).
- `swift-institute/Experiments/memory-cursor-generic-witness-demangle` (targets A–F).

## Question

Can the lazy `Memory.Cursor → Sequenceable` bridge be revived — i.e., has the malformed-name
emission for `Memory.Cursor<Buffer<A>.Linear.Inline<capacity>>` been fixed on a current Swift
toolchain (latest 6.4-dev / 6.5-dev nightly, plus 6.3.2)?

## Method

Because the crash reproduces **only on the literal `Buffer.Linear.Inline`** (all ~10 prior
synthetic reconstructions pass), a crashing baseline requires the literal type carrying the
`Memory.Cursor<Self>` witness. To avoid touching the production package, the repro ran in a
**detached git worktree** of `swift-buffer-linear-primitives` (`git worktree add --detach`),
where the dormant witness was transiently restored:

```swift
// (worktree only) Buffer.Linear.Inline+Sequence.Protocol.swift
extension Buffer.Linear.Inline: Sequenceable where Element: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Memory.Cursor<Buffer<Element>.Linear.Inline<capacity>>
    // makeIterator() witness = the bridge default in swift-memory-sequence-primitives
}
```

Experiment target `F-literal-buffer-linear-exe` drives
`Buffer<Int>.Linear.Inline<8>([10,20,30]).collect()`. All builds are **debug** (`-Onone`) to
avoid the release-mode `swiftlang/swift#86652` confound. Each toolchain switch used a clean
`.build`. The worktree and all scratch were removed afterward; the real packages are at their
original HEADs.

**Toolchains** (versions verified via `swift --version`, per snapshot-label discipline):

| Snapshot | Bundle ID | `swift --version` |
|---|---|---|
| Xcode default | `swiftlang-6.3.2.1.108` | Apple Swift 6.3.2 |
| `2026-03-16-a` | `org.swift.64202603161a` | 6.4-dev (Swift `d13cbbfd336f246`) — *the §A9-fix nightly* |
| `2026-05-07-a` | `org.swift.64202605071a` | 6.4-dev (Swift `82b7720768ba875`) |
| `2026-05-12-a` | `org.swift.64202605121a` | 6.5-dev (Swift `6da4da7153e8252`) — *latest* |

## Findings

### Result matrix (target F, literal `Memory.Cursor<Self>` witness)

| Toolchain | Config | Result |
|---|---|---|
| 6.3.2 (default) | release, no-assert | builds OK → **runtime SIGABRT (exit 134)** in `Sequenceable.collect()` |
| 6.4-dev `2026-03-16-a` | +assertions | **compile-time abort** `Mangler.cpp:176` |
| 6.4-dev `2026-05-07-a` | +assertions | **compile-time abort** `Mangler.cpp:176` |
| 6.5-dev `2026-05-12-a` | +assertions | **compile-time abort** `Mangler.cpp:176` |

6.3.2 runtime signature:

```
failed to demangle witness for associated type 'Iterator' in conformance
'…Buffer<A>.Linear.Inline<8>: Sequenceable' from mangled name '<garbage>' - unknown error
```

Nightly compile-time signature (byte-identical across all three nightlies):

```
4. While emitting IR ... protocol witness thunk for Sequenceable.makeIterator
5. While mangling type for debugger type 'Memory.Cursor<Buffer<τ_0_0>.Linear.Inline<τ_1_0>>'
6. Abort: function verify at Mangler.cpp:176
   Can't demangle: $s16Memory_Primitive0A0O0A18_Cursor_PrimitivesE0C0Vy_07Buffer_B0
   0E0O0e8_Linear_B0Ri_zrlE0F0V0e1_f8_Inline_B0Ri_zrlE0G0Vyx__qd__GApC0a12_Contiguous
   _D0E0H8Protocol0e1_f1_g1_D0_HCg_GD
```

### Mechanism: compiler emission, not the runtime demangler

Two independent confirmations on current toolchains:

1. The emitted name is fed to `swift-demangle` from **all four** toolchains (6.3.2, 6.4-dev
   `2026-03-16-a`, 6.4-dev `2026-05-07-a`, 6.5-dev `2026-05-12-a`). **Every one fails**
   (returns the raw string / `<<NULL>>` at the root). A newer demangler is no help — the
   *name itself* is malformed.
2. On the `+assertions` nightlies the compiler's own mangler round-trip self-check
   (`Mangler::verify`, the mangle→demangle invariant gate) aborts at compile time: **the
   compiler cannot demangle its own freshly-emitted output.** Since the mangler and demangler
   in a single toolchain are a matched pair (exact inverses of the grammar), own-demangler-
   fails-on-own-output means the output violates the toolchain's own grammar — malformed
   emission by definition, not a missing demangler case.

This matches §A9's 2026-05-28 conclusion ("a malformed name no demangler version can
resolve") and is the associated-type-witness (`swift_getAssociatedTypeWitness`) surface of
the same class.

### Root cause isolated by controls (6.4-dev `2026-03-16-a`, debug)

| Control target | Shape | Result |
|---|---|---|
| `B-handrolled-bare-generic` | hand-rolled generic owned-cursor witness, **zero** institute deps | **clean** (also clean on 6.5-dev) |
| `A-institute-bridge-generic` | institute `Memory.Cursor` over a **simple** generic `Region<Element>` | **clean** |
| `C-institute-bridge-concrete` | institute `Memory.Cursor` over a **concrete** conformer | **clean** |
| `E-…-3module` (faithful synthetic recon) | type/ops/bridge split + value-generic `@_rawLayout` + dual `@_implements` | **inconclusive** — blocked by an unrelated `unable to resolve module dependency: 'Finite_Primitives_Core'` on 6.5-dev (per [ISSUE-001] blocked-by-unrelated is not evidence) |

Neither `Memory.Cursor`, genericity, nor the bridge is the trigger. The trigger is
specifically the **deep value-generic nested instantiation** — `Memory.Cursor` parameterized
by the 3-level-nested, dual-generic (type `A` + value `capacity`), per-level-`~Copyable`,
`@_rawLayout`-backed `Buffer<A>.Linear.Inline<capacity>` carrying a `Span.Protocol`
associated conformance. In the malformed name the corruption sits in the tail
(`…0H8Protocol0e1_f1_g1_D0_HCg_GD`), where the symbolic associated-conformance reference
(`HCg`) interleaves with the nested word-substitutions (`_B0`/`_D0`) and the two `Ri_zrl`
suppressed-requirement signatures — the same corruption *class* §A9 described (a malformed
combination around the `HC…`/symbolic-reference encoding).

### Divergence from sibling §A9

§A9 (`Atomic<Tagged<…>>`) was empirically **FIXED on 6.4-dev** (a 6.4-dev-built binary runs
clean even on the 6.3.2 runtime). §A12 **still aborts on `2026-03-16-a`** — the same nightly.
The two "same-class" bugs therefore did **not** get fixed together; the `Memory.Cursor`-witness
instantiation remains malformed through 6.5-dev `2026-05-12-a`.

### Disentanglement from `swiftlang/swift#86652`

`#86652` is a **release-mode LLVM "Broken module found" verifier ICE** (the `@_rawLayout`
element-destruction issue), which fires in buffer-linear release even with the production
scalar iterator (no `Memory.Cursor`). What was observed here is categorically distinct: a
**Swift name-mangler/demangler** abort (`Mangler.cpp:176`; runtime `swift_getAssociatedTypeWitness`
"failed to demangle"), in **debug** builds. The decisive control: in the prior pass'
`-disable-llvm-verify` release run, with `#86652`'s LLVM verifier silenced, the same
`Memory.Cursor<Self>` baseline still aborts at runtime with the demangle failure while the
snapshot reshape runs correctly — a clean double-dissociation. The two are independent.

### Reducer status

No standalone (`swiftc`-only) reducer was cracked. B (zero-dep), A (simple generic), and C
(concrete) all emit **well-formed** names even under the stricter `+assertions` mangler
verify; only the literal type reproduces. The faithful 3-module synthetic (E) was blocked by
unrelated infra and is inconclusive. So [ISSUE-002]/[ISSUE-017] standalone-reducer bar
remains unmet. **However**, the upstream-filing artifact is materially improved: the
`+assertions` nightlies turn the runtime crash into a **deterministic compile-time mangler
abort** with the exact malformed name and a clean 5-frame backtrace — a far stronger report
than the prior runtime-only crash (still requires the literal buffer-linear type, so not yet
bare-`swiftc`).

### Required caveats (from adversarial verification of this verdict)

1. The 6.3.2-runtime manifestation (a short garbage name, runtime SIGABRT) and the
   `+assertions`-nightly manifestation (the long `$s16Memory_Primitive…HCg_GD` name,
   compile-time abort) are **not byte-identical names**. They are the same defect **class** —
   same trigger type, same `swift_getAssociatedTypeWitness` surface, same emission locus —
   differing by build config (no-assertions emits silently then crashes at runtime;
   `+assertions` self-verify catches it at compile). Do **not** equate the two byte strings.
2. "Not fixed through 6.5-dev" rests on the **persistence of the byte-identical compile
   abort** across three nightlies, **not** on a §A9-style positive fix-disproof (a clean
   6.5-dev-built binary). That disproof is structurally impossible here: the nightlies never
   emit a §A12 binary at all (they abort at compile).
3. §A12's emission localization is **inferential**, not directly swap-proven for §A12 itself.
   The §A9-style compiler/runtime swap cannot be run for §A12 (no fixed compiler exists to
   swap in). The locus claim rests on three mutually reinforcing inferences: (a)
   `Mangler::verify` is a producer-side round-trip gate, so own-demangler-fails-on-own-output
   ⇒ malformed; (b) no demangler version parses the name; (c) inheritance from the
   directly-swap-tested §A9 sibling.
4. The **runtime path on a no-assertions nightly was never observed** — every installed
   nightly is `+assertions` and aborts at compile, never producing a runnable binary
   (`-gnone` and `-disable-round-trip-debug-types` both still abort; the verify is the
   unconditional `+assertions` round-trip check, not a debug-info-only path). "Same defect as
   6.3.2's runtime crash" is therefore a sound **inference** from the shared emission locus,
   not a demonstration.
5. No standalone reducer; the E synthetic-recon reducer probe is inconclusive (infra-blocked).

## Outcome

**Status**: RECOMMENDATION. Mapping to the four feasibility options:

| Option | Verdict |
|---|---|
| **(a)** Fixed on a current nightly → revive, gated on a toolchain floor | **NO** — not fixed on any toolchain through 6.5-dev `2026-05-12-a`; on `+assertions` builds it now blocks compilation outright. |
| **(b)** Still broken → file upstream (separate authorization) + keep workaround | **YES, primary.** The new compile-time mangler abort is a stronger upstream artifact than before; filing is **gated on explicit authorization** (and ideally a bare-`swiftc` reducer, still uncracked). Keep the workaround meanwhile. |
| **(c)** Revive via `Memory.Snapshot.Cursor` (demangle-safe flatten) | **AVAILABLE NOW.** The element-only-generic snapshot reshape (`makeSnapshotIterator()` + `Memory.Snapshot.Cursor<Element>`) is already committed to `swift-memory-cursor-primitives` and `swift-memory-sequence-primitives` HEAD; its witness mangled name (`Memory.Snapshot.Cursor<A>`) never embeds the conforming type, so it dodges the corrupt emission. It is the **generic, reusable** dedup path for the ~16 per-type scalar iterators, at the cost of one eager `[Element]` allocation + bulk copy per iteration (vs the lazy cursor's zero-alloc per-`next()` re-derivation). Adoption is a principal decision, not made here. |
| **(d)** Not feasible → keep the per-type hand-written scalar | **CURRENT STATE.** `Buffer.Linear.Inline+Sequence.Protocol.swift:31-39` binds the concrete `Buffer<Element>.Linear.Inline<capacity>.Scalar` witness (zero-alloc) and stays. |

**Net**: lazy-`Memory.Cursor` bridge revival is **not feasible** on any current toolchain.
The dedup payoff that revival would have unlocked is **already available** via the snapshot
reshape (case c) if desired; otherwise the per-type scalar (case d) remains correct and is
the status quo.

### Verified source state (2026-05-31)

| Claim | Location |
|---|---|
| Production `Sequenceable` witness = concrete `…Inline.Scalar` (the dodge) | `swift-buffer-linear-primitives/.../Buffer.Linear.Inline+Sequence.Protocol.swift:31-39` |
| Dormant lazy bridge default `makeIterator() -> Memory.Cursor<Self>` present | `swift-memory-sequence-primitives/.../Storage.Contiguous+Sequenceable.swift:44-50` |
| Reshape bridge `makeSnapshotIterator() -> Memory.Snapshot.Cursor<Element>` committed | `swift-memory-sequence-primitives/.../Storage.Contiguous+Sequenceable.swift:60-67` |
| `Memory.Cursor` (lazy) and `Memory.Snapshot.Cursor` (reshape) both present | `swift-memory-cursor-primitives/Sources/Memory Cursor Primitives/{Memory.Cursor,Memory.Snapshot.Cursor}.swift` |

### Reproduction recipe

```bash
git -C swift-buffer-linear-primitives worktree add --detach \
    ../buffer-linear-crash-wt HEAD
# In the worktree: (1) add path-deps swift-memory-cursor-primitives +
# swift-memory-sequence-primitives to Package.swift (top-level + the
# "Buffer Linear Inline Primitives" target); (2) in
# Buffer.Linear.Inline+Sequence.Protocol.swift bind
# SequenceableIterator = Memory.Cursor<Buffer<Element>.Linear.Inline<capacity>>
# + import Memory_Cursor_Primitives / Memory_Sequence_Primitives.
# Point Experiments/memory-cursor-generic-witness-demangle target F at the worktree.
TOOLCHAINS=org.swift.64202605121a swift run F-literal-buffer-linear-exe   # 6.5-dev: Mangler.cpp:176 abort
swift run F-literal-buffer-linear-exe                                      # 6.3.2: runtime SIGABRT 134
git -C swift-buffer-linear-primitives worktree remove --force ../buffer-linear-crash-wt
```

## References

- `swift-institute/Research/swift-compiler-bug-catalog.md` — §A12 (this bug), §A9 (sibling
  emission class + 2026-05-28 emission-locus correction), master fix-status table.
- `swift-institute/Research/memory-cursor-generic-witness-demangle-reshape.md` — the 2026-05-28
  reshape analysis (v1.0.0); this doc extends it with the current-toolchain matrix.
- `swift-institute/Research/unified-iteration-design.md` — Outcome OQ-2 (the DORMANT verdict).
- `swift-institute/Experiments/memory-cursor-generic-witness-demangle` — targets A–F, EXPERIMENT.md.
- [`swiftlang/swift#86652`](https://github.com/swiftlang/swift/issues/86652) — the DISTINCT
  release-mode `@_rawLayout` LLVM-verifier ICE confound.
- Skills: [ISSUE-001], [ISSUE-002], [ISSUE-013], [ISSUE-025], [ISSUE-026], [ISSUE-028],
  [EXP-006], [EXP-020], [RES-019], [RES-023], [API-NAME-001].
