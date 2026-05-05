# Async Primitives Layer Resolution

<!--
---
version: 1.1.0
last_updated: 2026-05-04
status: RECOMMENDATION
tier: 2
scope: cross-package
applies_to: [swift-async-primitives]
provenance: HANDOFF-async-primitives-l1-layer-violation.md (2026-05-04)
changelog:
  - 1.0.0 (2026-05-04): Initial RECOMMENDATION — Option 1 (delete vestigial fallback).
  - 1.1.0 (2026-05-04): Refined Evidence A framing after user-surfaced
    correction (L2 swift-iso-9945 / L3 swift-foundations/swift-threads
    DO have Thread modules; the precise module name
    Kernel_Thread_Primitives is what doesn't exist). Added Evidence D
    (cross-file Synchronization-import invariant within the package —
    every Async.Mutex consumer also directly imports Synchronization,
    so the fallback could never have served a Synchronization-less
    target even if it resolved). Added Option 5 (REJECTED) — retarget
    the fallback at swift-threads or ISO_9945_Kernel_Thread —
    rejected on layer + API-incompatibility grounds.
---
-->

## Context

`/Users/coen/Developer/swift-primitives/swift-async-primitives` is the
L1 launch in the coenttb-cohort total-order
(`swift-institute/Research/coenttb-stage-1-dep-visibility-audit.md`
v1.0.0; sequence #1; gates Phase-2 transfer of `swift-renderable` →
`swift-render-primitives`). Its 0.1.0 release-readiness brief
(`swift-async-primitives/AUDIT-0.1.0-release-readiness.md` Phase 1 §#4)
surfaced a README ↔ `Package.swift` dependency mismatch
(`README.md:41` lists `swift-kernel-primitives` as the 8th dep;
`Package.swift` declares 7 path-deps, none of them kernel). The
initial disposition ("add the missing dep") was **RETRACTED 2026-05-04**
after the principal observed that the only kernel-primitives reference
in the source is at L2-or-above ecosystem level: an L1 → L2 dependency
that `[ARCH-LAYER-001]` and `[PRIM-FOUND-001]` forbid.

The reference is at
`Sources/Async Mutex Primitives/Async.Mutex.swift:149–157`:

```swift
#elseif !hasFeature(Embedded) && canImport(Kernel_Thread_Primitives)
@_exported public import Kernel_Thread_Primitives

extension Async {
    /// A value-owning mutex for thread synchronization.
    ///
    /// Uses `Kernel.Thread.Mutex.Value` for platforms with a kernel
    /// but without the Synchronization module.
    public typealias Mutex = Kernel.Thread.Mutex.Value
}
```

The branch is the third in a four-way `#if/#elseif/#elseif/#else`
chain (Darwin os_unfair_lock → stdlib `Synchronization` →
`Kernel_Thread_Primitives` → embedded no-op). It compiles today only
because `canImport(Kernel_Thread_Primitives)` returns false in the
package's build graph (no dependency declared) and the Synchronization
branch above it satisfies the typealias for non-Apple targets.

The investigation handoff at
`/Users/coen/Developer/HANDOFF-async-primitives-l1-layer-violation.md`
asked four questions in priority order with an early-stop instruction:
**Q1 — Is the fallback even necessary?** If the answer is "vestigial,"
stop and recommend the minimal fix. Q2–Q4 (L1-pure alternatives,
layer-classification correctness, consumer-migration plan) are reserved
for the case where the fallback is genuinely load-bearing.

This document records the Q1 finding and the resulting recommendation.

## Question

Is the `Kernel_Thread_Primitives` fallback at
`Async.Mutex.swift:149–157` necessary, given:

- platform requirements `(.macOS(.v26), .iOS(.v26), .tvOS(.v26),
  .watchOS(.v26), .visionOS(.v26))` (Package.swift:7–13);
- toolchain floor `swift-tools-version: 6.3.1` and
  `swiftLanguageModes: [.v6]` (Package.swift:1, :227);
- the seven declared path-deps, none of which is
  `swift-kernel-primitives` (Package.swift:77–85);
- the current shape of `swift-primitives/swift-kernel-primitives` on
  GitHub (`gh repo view` 2026-05-04: PRIVATE, not archived,
  default branch `main`, last updated 2026-04-30).

If unnecessary, what is the minimal fix that closes the L1 layer
violation flagged in the brief's Phase 1 §#4?

## Analysis

### Q1 evidence — three independent lines converge on "vestigial"

#### Evidence A: the precise module name `Kernel_Thread_Primitives` does not exist anywhere in the ecosystem

Refined framing — thread-mutex functionality DOES exist at higher
layers, but under different module names. The fallback's
`canImport(Kernel_Thread_Primitives)` guard checks for a SPECIFIC
module identifier, and that identifier is absent.

| Layer | Package | Target | Module identifier | Mutex shape |
|-------|---------|--------|-------------------|-------------|
| L1 | swift-primitives/swift-kernel-primitives | (none — see below) | — | — |
| L2 | swift-iso/swift-iso-9945 | `ISO 9945 Kernel Thread` | `ISO_9945_Kernel_Thread` | `final class ISO_9945.Kernel.Thread.Mutex` w/ manual `lock()`/`unlock()` |
| L3 | swift-foundations/swift-threads | `Thread Synchronization` | `Thread_Synchronization` | `Kernel.Thread.Synchronization` (DualSync / SingleSync wrappers around an internal `Kernel.Thread.Mutex` from L3 swift-kernel) |
| L3 | swift-foundations/swift-kernel | `Kernel Thread` | `Kernel_Thread` | `Kernel.Thread.Mutex` (canonical L3 type used by swift-threads) |

The current `swift-primitives/swift-kernel-primitives` package on
GitHub (`gh api repos/swift-primitives/swift-kernel-primitives/contents/Package.swift`,
default branch `main`, last updated 2026-04-30, 2026-05-04 fetch) ships
**three library products**, none of them `Kernel Thread Primitives`:

```
.library(name: "Kernel Namespace",                 targets: ["Kernel Namespace"])
.library(name: "Kernel File Primitives",           targets: ["Kernel File Primitives"])
.library(name: "Kernel Primitives Test Support",   targets: [...])
```

A workspace-wide grep
(`grep -rn "Kernel_Thread_Primitives" /Users/coen/Developer/`,
2026-05-04, excluding `.build/`) returns the symbol only in
`Async.Mutex.swift` itself and the corresponding research note
`swift-async-primitives/Research/mutex-cross-platform-state-2026-04-24.md`.
**Zero other consumers, zero other producers.** The string
`Kernel_Thread_Primitives` exists nowhere in the ecosystem as a target,
product, library, or import statement other than the violating file
that flags it as a candidate import.

`canImport(Kernel_Thread_Primitives)` therefore returns false on every
host. The L2/L3 alternatives (`ISO_9945_Kernel_Thread`,
`Thread_Synchronization`, `Kernel_Thread`) are real modules with real
APIs — but they are NOT what the fallback names, and pointing the
fallback at any of them would be a fresh layer violation rather than a
resolution (see Option 5 below).

The local workspace has no
`/Users/coen/Developer/swift-primitives/swift-kernel-primitives` clone
(`ls /Users/coen/Developer/swift-primitives/`, 2026-05-04). The only
on-disk artifact named "swift-kernel-primitives" is an unrelated
coenttb fork at `/Users/coen/Developer/coenttb/swift-kernel-primitives`
(swift-tools-version 6.2, three C-shim targets, no
`Kernel Thread Primitives`). The fork is irrelevant to
swift-primitives-org dependency resolution and would not be picked up
by SwiftPM in any case.

#### Evidence B: `Synchronization` is unconditionally available on every supported toolchain

Apple's `Synchronization` module landed in Swift 6.0 (June 2024) as a
stdlib module. It is available on every host where Swift 6.0+ is
available — Apple platforms (macOS 15+, iOS 18+, etc.), Linux, and
Windows. The package declares:

- `swift-tools-version: 6.3.1` (Package.swift:1) — host toolchain
  floor;
- `swiftLanguageModes: [.v6]` (Package.swift:227) — Swift 6 language
  mode;
- platforms `(.v26)` for the five Apple OSes (Package.swift:7–13) —
  declared mins are far above the Synchronization-introduction floor.

`canImport(Synchronization)` therefore returns true on every host that
can build the package. The branch ordering at Async.Mutex.swift is:

```
1. canImport(Darwin)               → os_unfair_lock @_rawLayout impl
2. canImport(Synchronization)      → typealias to Synchronization.Mutex
3. canImport(Kernel_Thread_Primitives) → typealias to Kernel.Thread.Mutex.Value  ← Q1 target
4. else                            → embedded no-op class
```

Branch 2 satisfies every non-Darwin, non-embedded target. Branch 3
cannot fire on any toolchain that supports the package's declared
language mode and platform floor.

The package's own research note
`Research/mutex-cross-platform-state-2026-04-24.md` § "Source of truth"
labels branch 3 as "Pre-Synchronization-module fallback" — the
self-description already identifies the branch as obsolete relative to
the post-Swift-6.0 state. The DocC `Semantics.md` table
(`Sources/Async Primitives/Async Primitives.docc/Semantics.md`,
"Async/Mutex" row, "Fairness" column) documents the architecture
authoritatively as Darwin/`os_unfair_lock` + Linux-Windows/`Synchronization`
+ embedded — `Kernel_Thread_Primitives` is **not** part of the
documented contract.

#### Evidence D: every in-package consumer of `Async.Mutex` ALSO directly imports `Synchronization`

Beyond the fallback's structural unreachability, the package's source
tree carries an implicit invariant that makes the fallback redundant
even at the source level: every file that uses `Async.Mutex<T>` also
imports `Synchronization` directly, on its own, independent of the
typealias chain.

Inventory (`grep -rn "Async\.Mutex\|public import Synchronization\|import Synchronization"`,
2026-05-04, excluding `Async Mutex Primitives/exports.swift` and
`Async.Mutex.swift` itself):

| File | Direct Synchronization import | Async.Mutex use | Atomic use |
|------|-------------------------------|------------------|-------------|
| `Async Mutex Primitives/Async.Mutex+Deque.swift` (line 13) | `public import Synchronization` (gated `!hasFeature(Embedded)`) | extends Async.Mutex | — |
| `Async Mutex Primitives/Async.Mutex+Ownership.swift` (line 25) | `import Synchronization` (gated `canImport(Synchronization)`) | extends Async.Mutex | — |
| `Async Completion Primitives/Async.Completion.swift` (line 17) | `public import Synchronization` (whole file gated `!hasFeature(Embedded)`) | uses Async.Mutex | uses Atomic (state CAS) |
| `Async Completion Primitives/Async.Completion.State.swift` (line 14) | `public import Synchronization` | uses Async.Mutex | uses Atomic |
| `Async Promise Primitives/Async.Promise.swift` (line 13) | `import Synchronization` | uses Async.Mutex | — |
| `Async Broadcast Primitives/Async.Broadcast.swift` (line 17) | `import Synchronization` | uses Async.Mutex | — |
| `Async Channel Primitives/Async.Channel.Bounded.Storage.swift` (line 15) | `public import Synchronization` | uses Async.Mutex | — |
| `Async Channel Primitives/Async.Channel.Unbounded.Storage.swift` (line 15) | `public import Synchronization` | uses Async.Mutex | — |
| `Async Publication Primitives/Async.Publication.swift` (line 13) | `import Synchronization` | uses Async.Mutex | — |
| `Async Waiter Primitives/Async.Waiter.swift` (line 12) | `import Synchronization` | — | uses Atomic |
| `Async Waiter Primitives/Async.Waiter.Flag.swift` (line 12) | `public import Synchronization` | — | uses Atomic |

The single in-package exception is the **Semaphore** group
(`Async.Semaphore.swift:13`, `+Wait`, `+Signal`, `+Shutdown`), which
imports only `internal import Async_Mutex_Primitives` and uses
`Async.Mutex` indirectly through the umbrella module. But Semaphore's
backing storage is `Async.Mutex<State>`, so its execution still
requires whatever lock primitive `Async.Mutex` resolves to be present
on the target — which on every supported toolchain is either Darwin's
`os_unfair_lock` (branch 1) or stdlib `Synchronization.Mutex`
(branch 2).

This means the fallback at branch 3 could **never** have served a
target where `Synchronization` was unavailable, even if the
`Kernel_Thread_Primitives` module had existed: the rest of the package
already requires `Synchronization` for `Atomic<T>` (used in
Promise, Completion, Waiter, Broadcast state machines) and for direct
type references (`public import Synchronization` re-exports). A
hypothetical platform with `Kernel_Thread_Primitives` but without
`Synchronization` would compile `Async.Mutex.swift` (branch 3) and
then immediately fail to compile every other Async coordination type
in the package.

The fallback is not just unreachable — it is **architecturally
incoherent** with the rest of the package. Synchronization is a
non-optional precondition for swift-async-primitives at every
non-embedded target.

#### Evidence C: zero callers, zero tests

`grep -rn "import Kernel\|Kernel\.Thread\.Mutex"` across the package's
`Sources/` and `Tests/` (2026-05-04) returns matches only at:

- `Sources/Async Mutex Primitives/Async.Mutex.swift:150` — the
  `@_exported public import` itself;
- `Sources/Async Mutex Primitives/Async.Mutex.swift:155,157` — the
  doc-comment and typealias inside the dead branch;
- `Research/mutex-cross-platform-state-2026-04-24.md:27` — research
  prose quoting the source.

`grep -rn "Kernel" Tests/` returns no match. There is no test that
exercises the fallback path; there is no production consumer that
references `Kernel.Thread.Mutex.Value` through `Async.Mutex`. The
fallback is undocumented in the package's public DocC, untested in the
package's test suite, and unreferenced anywhere in the ecosystem.

The cosmetic doc-comment reference at
`Sources/Async Publication Primitives/Async.Publication.swift:63`
(`Unlike \`Kernel.Handoff.Cell\`, this slot:`) is the only other
mention of a `Kernel.*` symbol. It is a comparison sentence, not a
symbol use. Per `[PRIM-NAME-003]` "Names Describe Mechanism, Not
Origin" — `Kernel.Handoff` is itself cited in that rule as an
**incorrect** name pattern. The doc-comment is therefore both stale
(refers to a name that may not exist) and pedagogically inverted (cites
an anti-pattern). It belongs in the cleanup, but as a cosmetic edit
rather than a layer-violation closure.

### Decision criteria

| Criterion | Weight | Verdict on the fallback |
|-----------|--------|-------------------------|
| Reachable from the build graph | MUST | Fails — `Kernel_Thread_Primitives` is not a buildable target in any package |
| Required to satisfy the type contract on a supported platform | MUST | Fails — branch 2 (`Synchronization`) covers Linux/Windows; branch 1 (Darwin) covers Apple; branch 4 covers embedded |
| Exercised by the test suite | SHOULD | Fails — zero test coverage |
| Cited as part of the documented public API surface | SHOULD | Fails — DocC `Semantics.md` documents only branches 1, 2, and 4 |
| Compatible with `[ARCH-LAYER-001]` and `[PRIM-FOUND-001]` | MUST | Fails — L1 cannot depend on `Kernel_Thread_Primitives` regardless of which layer that target lives at, since the symbol does not currently exist at L1 |

The fallback fails every applicable criterion. There is no reading of
the brief's Phase 1 §#4 disposition under which the branch needs to
stay.

### Options considered (exhaustive)

#### Option 1 (RECOMMENDED): delete the dead branch + the cosmetic doc reference

Single commit. Two files touched, ~10 lines removed total.

`Sources/Async Mutex Primitives/Async.Mutex.swift` — remove lines
149–158 (the entire `#elseif !hasFeature(Embedded) &&
canImport(Kernel_Thread_Primitives)` branch including its body and
trailing blank line):

```swift
// REMOVE
#elseif !hasFeature(Embedded) && canImport(Kernel_Thread_Primitives)
@_exported public import Kernel_Thread_Primitives

extension Async {
    /// A value-owning mutex for thread synchronization.
    ///
    /// Uses `Kernel.Thread.Mutex.Value` for platforms with a kernel
    /// but without the Synchronization module.
    public typealias Mutex = Kernel.Thread.Mutex.Value
}

```

Result: the conditional chain reduces to three branches —
Darwin/`os_unfair_lock`, `Synchronization`, embedded no-op — which
matches the documented `Semantics.md` contract exactly.

`Sources/Async Publication Primitives/Async.Publication.swift:63` —
remove or rewrite the cosmetic doc-comment reference to
`Kernel.Handoff.Cell`. Suggested rewrite (preserves the comparative
shape without referencing a non-canonical name): drop the bullet that
references `Kernel.Handoff.Cell` and keep the three properties
(`May start empty / Supports overwrite via publish / Returns nil on
losing take()`) as direct properties of `Async.Publication` rather
than as deltas from a comparand. Alternatively, delete the entire
`Unlike Kernel.Handoff.Cell, this slot:` paragraph as cosmetic-only
and let the surrounding docstring stand.

The L1 brief Phase 1 §#4 row's "BLOCKED ON INVESTIGATION" disposition
becomes "RESOLVED — single-commit deletion at `<SHA>`" upon
principal-authorized execution. The README ↔ `Package.swift` mismatch
in §#4 (`README.md:41` 8th dep `swift-kernel-primitives`) closes via a
README single-line edit deleting the kernel-primitives entry from the
dependency list — independent of the source change but bundleable in
the same commit, since both edits express the same fact ("there is no
kernel-primitives dependency on this package").

**Trade-offs:**

- ✅ Closes the layer violation flagged in the handoff.
- ✅ Aligns source with documented `Semantics.md` contract.
- ✅ Removes ~10 lines of dead code, no surface change for any
  consumer.
- ✅ One commit, low blast radius. The 4 L1 consumers
  (`swift-cache-primitives`, `swift-pool-primitives`,
  `swift-render-primitives`, `swift-test-primitives`) continue to
  import `Async Mutex Primitives` and resolve to the Synchronization
  typealias on Linux/Windows or the os_unfair_lock impl on Apple
  platforms. Q4 (consumer migration plan) does not need to run.
- ⚠️ The surviving Darwin branch remains a separate, narrower
  potentially-platform-conditional concern under a strict reading of
  `[PLAT-ARCH-008c]` "L1 Primitives Are Unconditionally
  Platform-Agnostic". This is explicitly **out of scope** for the
  recommended fix per the handoff's "secondary concern" framing. See
  § "Secondary observation" below for a tracked follow-up.

#### Option 2 (REJECTED): wire `swift-kernel-primitives` as a real dep

This would mean adding `.package(path: "../swift-kernel-primitives")`
to `Package.swift`, adding the `Kernel Thread Primitives` product as a
target dependency, and resurrecting `Kernel.Thread.Mutex.Value` somewhere.

**Rejected because:**

- The target `Kernel Thread Primitives` does not exist in the current
  swift-primitives/swift-kernel-primitives package (verified via
  `gh api ... contents/Package.swift` 2026-05-04). There is nothing to
  depend on.
- Even if the target existed, `swift-async-primitives` would acquire a
  dependency it does not need on any supported toolchain
  (`Synchronization` already covers the gap branch 3 was designed for).
- Per `[ARCH-LAYER-001]` and the handoff's framing of
  `Kernel_Thread_Primitives` as L2 ecosystem, the dependency would
  introduce the very layer violation the brief is closing.

#### Option 3 (REJECTED): relocate the Mutex API to a non-`-primitives` package

This would mean splitting `Async Mutex Primitives` (or the entire
swift-async-primitives package) out of L1 and rebuilding consumers to
import from the new layer.

**Rejected because Q1 is vestigial.** The handoff's stop-condition is
explicit: "If Q1 answer is **vestigial**: recommendation is to delete
lines 149–157 (and any `Mutex` typealias scaffolding) plus the
`Kernel.Handoff.Cell` doc-comment reference. No layer-violation
remains. Brief #4 closes with a one-commit fix. STOP — no Q2/Q3/Q4
needed." A relocation analysis is the Q3/Q4 path; it is reserved for
the case where Q1 returns "load-bearing."

The async coordination primitives' tier placement (L1, primitives Tier
11 "Platform" per `[PRIM-ARCH-001]`) is not in question by this
investigation. If a future investigation revisits L1 vs L3 for
swift-async-primitives, it can do so on the merits of the package's
overall scope — channels, broadcasts, semaphores, barriers — not on
the basis of a vestigial mutex fallback.

#### Option 5 (REJECTED): retarget the fallback at `Thread_Synchronization` (swift-threads, L3) or `ISO_9945_Kernel_Thread` (swift-iso-9945, L2)

This option arises naturally from the Evidence A refinement: thread
mutex types DO exist in the ecosystem at higher layers, just under
different module names. Could the fallback be rewritten to point at
one of those?

```swift
// Hypothetical Option 5
#elseif !hasFeature(Embedded) && canImport(Thread_Synchronization)
@_exported public import Thread_Synchronization
extension Async {
    public typealias Mutex = Kernel.Thread.Mutex   // from swift-threads / swift-kernel
}
```

**Rejected on three independent grounds:**

1. **Layer violation persists.** Pointing at `Thread_Synchronization`
   (L3) or `ISO_9945_Kernel_Thread` (L2) makes the L1 → higher-layer
   dependency the very thing the brief #4 row was opened to close. A
   fresh layer violation in place of the existing one is not a
   resolution; it is a relabeling.

2. **API surface is incompatible.** `Synchronization.Mutex<Value>` (a
   stdlib struct with `@_rawLayout` storage and `withLock(_:)` /
   `withLockIfAvailable(_:)` closure-based access) is the type the
   `Async.Mutex` API contract is built around. The L2 type
   `ISO_9945.Kernel.Thread.Mutex` is a `final class` with manual
   `lock()`/`unlock()` semantics
   (`swift-iso-9945/Sources/ISO 9945 Kernel Thread/ISO 9945.Kernel.Thread.Mutex.swift:71`
   declares `public final class Mutex`); the L3 swift-threads type
   `Kernel.Thread.Synchronization` is a coordination wrapper
   (`Kernel.Thread.Synchronization.swift:13` "Mutex + N condition
   variable(s) wrapper") not an interchangeable Mutex type. Neither
   matches `Synchronization.Mutex`'s value-type / closure-based API.
   Substituting one as a typealias would break every consumer that
   depends on the `Mutex<T>` value-type-with-`withLock` shape (Promise,
   Completion, Broadcast, Channel, Publication — all of them use
   `Async.Mutex(State())` initialization and `withLock { ... }`
   closures, neither of which is provided by a class-with-manual-locking
   shape).

3. **Redundant given Evidence D.** Even if grounds 1 and 2 were
   waived, the substitution would be redundant: the rest of the
   package already imports `Synchronization` directly and requires
   `Atomic<T>` for state machines (Promise, Completion, Broadcast,
   Waiter). A target with `Thread_Synchronization` but without
   `Synchronization` would compile branch 3 and then fail at every
   other consumer file. The fallback can only be useful if
   `Synchronization` is unavailable; on such targets, the rest of the
   package is unbuildable regardless.

The L2/L3 thread-mutex types are real and useful — for L3 consumers
of those packages. They are not a substitute for the L1
`Async.Mutex` typealias on a Synchronization-less target, because
such a target cannot host the rest of the package.

#### Option 4 (REJECTED): leave it alone — the branch is harmless

This is the "no fix" path — the branch is dead code, why touch it?

**Rejected because:**

- The brief's Phase 1 §#4 row explicitly blocks on this resolution.
  Without a closure, the L1 0.1.0 tag cannot reach Phase 3 GO.
- The README claims an 8th dep that `Package.swift` does not declare.
  The README must change either to add the dep or to remove the
  claim; "leave it alone" is not a coherent disposition.
- The 0.1.0 tag cements the public API surface. Shipping a
  `@_exported public import Kernel_Thread_Primitives` in the source
  tree (even behind a `canImport` that returns false) creates an
  apparent dependency that contradicts the documented architecture.
  Future readers of the source — and any tooling that scans imports
  for layer-discipline checks — will flag the line as a violation.
  Cleanup is cheaper today than after 0.1.0 ships.

### Comparison

| Criterion | Option 1 (RECOMMENDED) | Option 2 (add dep) | Option 3 (relocate) | Option 4 (no fix) | Option 5 (retarget) |
|-----------|------------------------|--------------------|----------------------|-------------------|---------------------|
| Closes the layer violation | ✅ | ❌ (creates one) | ✅ | ❌ | ❌ (creates a different one) |
| Closes the README mismatch | ✅ (with the README single-line edit) | requires README rewrite + new dep | requires consumer-side rewrite | ❌ | requires README rewrite |
| Lines changed | ~10 | ~30+ | hundreds (4 consumers + new package layout) | 0 | ~10 (relocation only); breaks API consumers |
| Commits | 1 | 1+ | many (Phase 2 transfer-shaped) | 0 | 1 source + cascade for incompatible API |
| New layer violations | 0 | 1 (L1→L2) | 0 | 0 | 1 (L1→L2 or L1→L3) |
| Risk to consumers | none | recompile cascade | consumer rewrite | none, but blocks tag | API break (class-with-manual-locking ≠ struct-with-`withLock`) |
| API-surface preservation | ✅ (no change) | ✅ | requires consumer migration | ✅ | ❌ (Mutex shape changes) |
| Compatible with stop-condition | ✅ | n/a (Q2+ path) | n/a (Q3+ path) | ❌ (does not close §#4) | n/a (Q2+ path) |

Option 1 is dominant on every relevant axis.

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option 1 — delete the dead `Kernel_Thread_Primitives`
branch and the cosmetic `Kernel.Handoff.Cell` doc-comment reference.
Single commit. Bundleable with the README §#4 single-line edit (drop
the `swift-kernel-primitives` entry from the dependency list at
`README.md:41`).

Concrete edits, scoped tightly:

1. `Sources/Async Mutex Primitives/Async.Mutex.swift` — remove lines
   149–158 (the entire `#elseif ... canImport(Kernel_Thread_Primitives)`
   branch and its trailing blank line).
2. `Sources/Async Publication Primitives/Async.Publication.swift:63` —
   remove or rewrite the `Unlike \`Kernel.Handoff.Cell\`, this slot:`
   bullet block (cosmetic; principal preference between deletion and
   rewriting-without-comparand).
3. `README.md:41` (separate or bundled) — drop
   `swift-kernel-primitives` from the comma-separated dependency list,
   matching `Package.swift`'s declared 7-dep state.

Suggested commit message (per `[GH-REPO-*]` / `[AUDIT-*]` conventions
in the workspace; one-line summary + body):

```
fix(async-primitives): remove vestigial Kernel_Thread_Primitives fallback (L1 layer violation)

- Async.Mutex.swift: delete unreachable canImport(Kernel_Thread_Primitives)
  branch. Synchronization branch above covers Linux/Windows; Darwin branch
  covers Apple; embedded no-op covers embedded. The deleted branch never
  fired on any supported toolchain (Swift 6.0+ ships Synchronization stdlib),
  and Kernel_Thread_Primitives does not exist as a buildable target in the
  current swift-primitives/swift-kernel-primitives package.
- Async.Publication.swift: drop the cosmetic Kernel.Handoff.Cell doc reference
  (refers to a non-canonical name per [PRIM-NAME-003]).
- README.md: drop the spurious swift-kernel-primitives entry from the
  dependency list to match Package.swift's declared 7 deps.

Closes Phase 1 §#4 of AUDIT-0.1.0-release-readiness.md.
Per swift-institute/Research/async-primitives-layer-resolution.md.
```

**Authorization gates** (per
`feedback_no_public_or_tag_without_explicit_yes` and
`feedback_user_plan_is_roadmap_not_authorization`):

1. The execution of Option 1 requires explicit principal authorization
   ("YES, do it") before any source edit lands. The recommendation is
   staged here; it does not authorize itself.
2. The L1 brief's Phase 1 §#4 row gets amended **only after** the
   recommendation is accepted and the commit lands. The brief's
   "Principal Decisions" section is locked per the handoff's "Do Not
   Touch" boundary; the amendment is an addition, not a rewrite.
3. The 0.1.0 tag, the visibility flip PRIVATE→PUBLIC, the launch-blog
   publish, and the swift-institute.org deploy each remain separate
   per-action gates per `[RELEASE-004]`. Option 1's execution does not
   open any of those doors.

### Secondary observation (out of scope, tracked for follow-up)

Per `[PLAT-ARCH-008c]` "L1 Primitives Are Unconditionally
Platform-Agnostic" (strengthened 2026-04-26), the surviving Darwin
branch (`Async.Mutex.swift:12–137`, including
`public import Darwin.os.lock` at line 13 and the
`os_unfair_lock_s` `@_rawLayout` implementation) is itself
platform-conditional code at L1 and would be a separate, narrower
violation under a strict reading of the rule. The handoff explicitly
classifies this as a "secondary concern" outside Q1's scope.

The package's own research at
`swift-async-primitives/Research/mutex-cross-platform-state-2026-04-24.md`
§ "Decision space" already enumerates three options for the Darwin
branch:

- **(a')** extend the Darwin-only `.locked.value` coroutine accessor
  to Linux and Windows;
- **(b)** document the split in DocC and accept the platform
  divergence;
- **(c)** remove the `Async.Mutex.Locked` coroutine accessor entirely
  (zero current callers — the research note confirms zero production
  call sites and zero test call sites).

Option (c) would collapse the Darwin path into the Synchronization
path, eliminating the surviving platform conditional entirely and
bringing `Async.Mutex` into full `[PLAT-ARCH-008c]` compliance. This
is a **separable workstream** from the L1 brief #4 closure and is
**not bundled** into Option 1 above.

Recommendation for the secondary observation: track as a follow-up
research cycle scoped specifically to the Darwin-branch question, not
as an amendment to this document. The L1 0.1.0 tag does not need to
wait for it; `[PLAT-ARCH-008c]`'s strengthened reading was published
2026-04-26 with a named-types-only enforcement scope (`Kernel.Descriptor`,
`Kernel.Process.ID`, `Kernel.Directory.Entry` — see the rule's
transition note), and `Async.Mutex` is not on that list. The
strengthened rule is forward-looking for new types; existing
platform-conditional L1 code in `swift-async-primitives` is a known
ecosystem-wide cleanup item, not a 0.1.0 tag blocker.

### Stop-condition compliance

Per the handoff's `## Scope` and `### Supervisor Ground Rules`:

> If Q1 answer is **vestigial**: recommendation is to delete lines
> 149–157 (and any `Mutex` typealias scaffolding) plus the
> `Kernel.Handoff.Cell` doc-comment reference. No layer-violation
> remains. Brief #4 closes with a one-commit fix. STOP — no Q2/Q3/Q4
> needed.

This document complies. Q2 (L1-pure alternatives), Q3
(layer-classification correctness), and Q4 (consumer migration plan)
are explicitly **not investigated** — the principal's stop-condition
fires on the Q1 finding. The 4 L1 consumers
(`swift-cache-primitives`, `swift-pool-primitives`,
`swift-render-primitives`, `swift-test-primitives`) require no
migration work. The package's L1 placement is unchanged. The 0.1.0 tag
arc per the cohort plan continues forward unaltered.

## References

### Primary sources cited

- **Source code (read-only inspection, 2026-05-04)**:
  - `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Mutex Primitives/Async.Mutex.swift` (lines 12, 13, 139–157, 160–192)
  - `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Mutex Primitives/Async.Mutex+Ownership.swift` (line 23 — `canImport(Synchronization)` gating)
  - `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Mutex Primitives/Async.Mutex+Deque.swift` (lines 12–14)
  - `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Publication Primitives/Async.Publication.swift:63` (Kernel.Handoff.Cell doc reference)
  - `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async Primitives.docc/Semantics.md` (Async/Mutex row, Fairness column)
  - `/Users/coen/Developer/swift-primitives/swift-async-primitives/Package.swift` (lines 1, 7–13, 77–85, 99–103, 227)

- **Remote authoritative source**: `gh api repos/swift-primitives/swift-kernel-primitives/contents/Package.swift` (2026-05-04, default branch `main`, last updated 2026-04-30 per `gh repo view --json updatedAt`).

- **Repo state queries (2026-05-04)**:
  - `gh repo view swift-primitives/swift-kernel-primitives --json visibility,isArchived,nameWithOwner` → `{"isArchived":false,"nameWithOwner":"swift-primitives/swift-kernel-primitives","visibility":"PRIVATE"}`
  - `ls /Users/coen/Developer/swift-primitives/swift-kernel-primitives` → no such file or directory (confirms no local clone)

### Skills cited

- `swift-institute` — `[ARCH-LAYER-001]` Dependency Direction (L1 cannot depend on L2/L3).
- `primitives` — `[PRIM-FOUND-001]` No Foundation; `[PRIM-FOUND-002]` Embedded Compatibility; `[PRIM-NAME-003]` Names Describe Mechanism, Not Origin.
- `platform` — `[PLAT-ARCH-008c]` L1 Primitives Are Unconditionally Platform-Agnostic (secondary observation).
- `modularization` — `[MOD-DOMAIN]` Factor the Law, Not the Module (consulted; no operative requirement triggered by Option 1).
- `research-process` — `[RES-003]` Document Structure; `[RES-003a]` Metadata; `[RES-003c]` Research Index.

### Related research and audit artifacts

- `/Users/coen/Developer/HANDOFF-async-primitives-l1-layer-violation.md` — investigation handoff and Q1–Q4 dispatch.
- `/Users/coen/Developer/swift-primitives/swift-async-primitives/AUDIT-0.1.0-release-readiness.md` — L1 brief, Phase 1 §#4 (RETRACTED disposition).
- `/Users/coen/Developer/swift-primitives/swift-async-primitives/Research/mutex-cross-platform-state-2026-04-24.md` — package's own prior premise-correction on Mutex cross-platform state; identifies branch 3 as "Pre-Synchronization-module fallback" and enumerates the Darwin-branch decision space (a'/b/c) cited in this doc's secondary observation.
- `/Users/coen/Developer/swift-institute/Research/mutex-inventory.md` (2026-03-30) — cross-repo Mutex inventory; documents the typealias-only state of `Async.Mutex` prior to the os_unfair_lock @_rawLayout shift.
- `/Users/coen/Developer/swift-institute/Research/async-mutex-rawlayout-inline-storage.md` — DEFERRED Tier-2 research on the os_unfair_lock @_rawLayout pattern.
- `/Users/coen/Developer/AUDIT-coenttb-launch-cohort-readiness.md` — cohort handoff (parent workstream).
- `/Users/coen/Developer/swift-institute/Research/coenttb-stage-1-dep-visibility-audit.md` (v1.0.0, 2026-05-04) — cohort sequencing; Dest J context.
