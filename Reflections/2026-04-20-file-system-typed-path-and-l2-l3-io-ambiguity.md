---
date: 2026-04-20
session_objective: Execute swift-paths HANDOFF-path-view-separator-unifiers dispatching swift-file-system Platform Compliance Finding #4 + Implementation Finding #1; extend per user direction to typed-path plumbing and error-payload upgrade; diagnose a blocking ecosystem test-build failure
packages:
  - swift-file-system
  - swift-windows-standard
  - swift-iso-9945
  - swift-posix
  - swift-kernel
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# swift-file-system typed-path migration, error-payload upgrade, and the L2/L3 IO.Read/Write namespace-alias collision

## What Happened

Started on the dispatched handoff (`HANDOFF-path-view-separator-unifiers.md`
in swift-paths) to migrate four `#if os(...)` path-arithmetic sites in
swift-file-system. Phase A verification showed existing L3 `File.Path` APIs
(`parent`, `components.last`, `appending(Component)`) covered Phase B needs,
so Phase B's proposed new L2 extensions were correctly skipped. Phase C
landed the four sites plus Implementation 2026-03-24 Finding #1
(`createIntermediates` `lastIndex(of: "/")` scan) — 712/712 tests green.
Committed as 41e1458 after user directed "avoid `Swift.String`, prefer path
types" mid-execution, which expanded scope beyond the four handoff sites
into the shared plumbing:

- `resolvePaths` / `fileName` / `fileExists` / `atomicRename` /
  `atomicRenameNoClobber` / `syncDirectory` / `statIfExists` all upgraded
  to take `File.Path` and call `.kernelPath` directly (no more
  `Kernel.Path.scope` wrappers).
- `Streaming.Context` fields renamed and retyped:
  `tempPathString` / `resolvedPathString` / `parentPathString` →
  `tempPath` / `resolvedPath` / `parentPath` : `File.Path`.
- `TempFile.path: File.Path`. Temp-path generators return `File.Path`.
- `applyMetadata`'s unused `destPath: Swift.String` parameter removed.
- `randomToken` collapsed the stale Darwin `#if` (Finding #5 partial) and
  surfaced typed-throws via `.random("CSPRNG syscall failed: \(error)")`
  instead of the `return ""` + `isEmpty` guard.

User then directed error-case associated values to also migrate off
`Swift.String`. Landed as 8f19d65: `from:`/`to:`/`path:`/`directory:`
on `Write.Error`, `Streaming.Error`, `Atomic.Error` all now `File.Path`.
Added `case invalidPath(Paths.Path.Error)` — raised once at the
`Kernel.Path.View → String → File.Path` boundary; message text dropped
because `Paths.Path.Error` already has `CustomStringConvertible`. User
pushed back on my first draft that proposed
`case invalidPath(rawValue: String, message: String)` — "count on the
Path initializer's Error, which will be thrown", with a pointer to
`Either`. I chose the wrapping form over `throws(Either<E, Path.Error>)`
because the Either form cascades typed-throws changes through six+
public overloads; wrapping is local.

Added L2 Windows `Path.View` Decomposition + Modification conformances
in swift-windows-standard (a3fefbf), mirroring iso-9945 with dual-separator
scan (`\` primary, `/` alt). `#if os(Windows)` guarded because
swift-windows-standard's `Package.swift` lists Darwin/iOS platforms too
(the POSIX conformance already owns the same extension slot there).

Then `swift test` failed — not from my changes but from an ecosystem-wide
`Kernel.IO.Read.read` / `Kernel.IO.Write.write` ambiguity. Diagnosis: today's
swift-kernel commit 5b0ae3b added an L3 cross-platform unifier
`Kernel.IO.Write.write` that conflicts with iso-9945's pre-existing
extension via the `ISO_9945.Kernel = Kernel_Primitives.Kernel` typealias —
both land methods with identical signatures on the same type. Swift's
name lookup reports ambiguity at every call site (swift-posix internal,
Kernel test support, swift-kernel tests, swift-io tests,
swift-file-system internal writeAll loop, swift-kernel Completion
Notification wait).

Attempted `@_spi(Syscall)` on iso-9945's L2 methods + `@_spi(Syscall)
public import ISO_9945_Kernel_File` in swift-posix. Two blockers surfaced:
(a) swift-posix's L3 wrappers are `@inlinable` — Swift rejects
`@inlinable` function bodies referencing SPI symbols from another module;
(b) many consumers (`Kernel.Completion.Notification+Wait`, test support,
integration tests) rely on iso-9945's raw being visible through the
`Kernel → Kernel_Core → POSIX_Kernel → ISO_9945_Kernel_File` re-export
chain — SPI-gating broke all of them. Reverted.

Instead, wrote a branching handoff
(`swift-kernel/HANDOFF-io-read-write-l2-l3-ambiguity.md`) recommending
Option A (`Raw` sub-namespace on L2: `Kernel.IO.Write.Raw.write`). The
originating session (which committed 5b0ae3b and its Read sibling,
24cf586, plus three Socket-family L3 unifiers that are latently broken
the same way) appended an addendum to the handoff with three corrections:

1. The user **forbade** the `.Raw.` namespace: "We forbid 'iso-9945
   under Raw namespace'." Option A is off the table.
2. Option D (strip `public import ISO_9945_Kernel_File` from swift-posix)
   — which I listed as rejected — is actually clean for Read/Write
   specifically, because Read/Write error types live at L1 and swift-posix's
   Read/Write public signatures reference zero iso-9945 types. I missed
   that asymmetry; I had implicitly treated Socket (which does reference
   iso-9945-located types) as the general case.
3. Socket.Accept (bfa092e), Socket.Send (6a6d527), Socket.Receive
   (5bd87f3), and the pre-existing Socket.Connect (6741b6a) have the
   same ambiguity shape, currently latent because no consumer tests them
   yet. They need a separate handoff.

A parallel reflection
(`2026-04-20-l2-l3-same-signature-latent-ambiguity.md`) owns the
originating-session angle — the "Phase A was not optional" framing and
the empirical-verification-of-handoff-premises action items. This
reflection captures the swift-file-system typed-path work and the
diagnosis/revert angle from the consuming end.

## What Worked and What Didn't

**Worked:**

- Phase A→B→C decomposition with the early-skip of Phase B. The handoff
  explicitly permitted skipping when existing APIs cover; I verified that
  `File.Path.parent` + `.components.last` + `.appending(Component)` did,
  and went straight to consumer migration.
- Splitting the user's "avoid `Swift.String`, prefer path types" directive
  across the three refactor axes (function signatures → Context storage →
  error-case associated values). Each axis landed as its own commit with
  clear scope.
- The branching handoff as termination strategy when the L2/L3 collision
  proved to be architectural scope beyond the current session.
- Using the Flush precedent (639a428 renamed L2 raw to `fsync`/`fdatasync`
  etc.) to reason about Write — and correctly concluding that the Flush-
  style rename *doesn't* apply here because the POSIX name literally is
  `write`.

**Didn't work:**

- First draft of error-payload upgrade left `case invalidPath(rawValue:
  String, message: String)`. User flagged: "count on the Path
  initializer's Error, which will be thrown." Ran the rewrite twice — the
  second draft wrapped `Paths.Path.Error` directly, which is what the user
  wanted. The first draft re-described what `Path.Error` already describes.
- `Streaming.Error.writeFailed(path: Swift.String, ...)` carried a `path:
  ""` placeholder hack when mapping from the shared `Write.Error.write`
  case (where path context isn't available at the `writeAll` boundary).
  Caught only by build error; should have caught during the initial read.
  Dropped the `path:` field from `writeFailed` to match `Atomic.Error`'s
  shape and eliminate the hack.
- `replace_all` passes for `.string` conversions at throw sites left two
  stragglers (`Atomic+API.swift:262` and `Atomic.swift:114`) that only
  surfaced via subsequent build errors. The replace_all pattern I used
  matched `directory: parent.string,` but not the semantically equivalent
  `path: parent.string,` — replace_all's literal-match semantics cost
  iteration cycles that a regex-aware sweep would have avoided.
- `@_spi(Syscall)` attempt on L2 ate ~30 minutes before reverting.
  Incompatibility with `@inlinable` was not in my working memory; the
  first sign was a `static method 'write(_:from:)' cannot be used in an
  '@inlinable' function` error from swift-posix. Compounded by the
  transitive re-export breakage in `Kernel.Completion.Notification+Wait`.
  A ~1-minute pre-attempt check ("does iso-9945's L2 get called from
  `@inlinable` functions?") would have ruled it out before edits.
- Reading the handoff's "Phase B recommend (ii) for symmetry" as optional
  let me close Phase B without the Windows L2 conformances — then user
  direction expanded scope to add them (a3fefbf). Would have been cleaner
  to do the symmetric L2 split as part of the original close-out rather
  than as a scope-expansion later.
- Left 712/712 tests as the reported baseline after commit 41e1458. When
  the ambiguity surfaced post-commits, I had to re-verify that the
  failure wasn't mine — the per-repo clean build experiment took
  explicit wall-clock time that a pre-collision build snapshot would have
  saved.

## Patterns and Root Causes

**Pattern 1 — L2/L3 namespace-alias collisions are a recurring class.**
The `ISO_9945.Kernel = Kernel_Primitives.Kernel` typealias, combined with
`[PLAT-ARCH-003]`'s rule that L2 extends the shared `Kernel` namespace,
means any method iso-9945 adds to `ISO_9945.Kernel.X.Y.z` literally is a
method on `Kernel.X.Y.z`. When `[PLAT-ARCH-008e]` later prescribes an L3
unifier `Kernel.X.Y.z` with identical semantics, they collide at the
same extension slot. Flush dodged this by renaming L2 to the POSIX
man-page names (`fsync`, `fdatasync`, …) which happen to differ from
L3's abstract `flush` / `data`. Read and Write can't — the POSIX name
literally equals the L3 unifier name. The pattern will recur for every
syscall family with name-equality across tiers. The `[platform]` skill
should document both the pattern and the standard mitigation (Raw
sub-namespace) so future L3 unifier additions surface the collision at
design time instead of at compile time.

**Pattern 2 — "Avoid `Swift.String`" is a layered directive.** First
interpretation: "don't pass raw strings as paths *inside my new code*."
Second (user-driven, after pushback on `.string` conversions at Context
construction): "extend the typed-path push to adjacent plumbing too
(Context fields, shared helpers)." Third: "error-case associated values
also." Each layer replaced `Swift.String` in *control flow* but left it
in *terminal diagnostic text* (`message:`, error descriptions). The
directive reads coherently only after recognizing that "in our
implementation" means control-flow, not every literal `Swift.String`.
A single sentence can encode a policy whose full scope surfaces only
through iteration; anticipating the layered interpretation up front
saves round-trips.

**Pattern 3 — `@_spi` + `@inlinable` is a hidden incompatibility.**
`@_spi(Syscall)` looked like a clean solution for the L2/L3 ambiguity
because it promises "opt-in visibility without renaming." But Swift's
semantic model rejects `@inlinable` function bodies referencing SPI from
another module: `@inlinable` commits the body text to the client ABI,
and SPI is explicitly not client ABI. swift-posix's L3 wrappers are
all `@inlinable` for the expected-inlining-across-modules perf story,
which made the SPI hide fundamentally incompatible. The lesson is that
`@_spi` isn't a free abstraction — it's a visibility modifier with an
ABI-layer interaction. Before picking `@_spi` as a fix, check whether
the module that needs SPI access also has `@inlinable` boundaries that
would require `@_alwaysEmitIntoClient` (which has its own trade-offs)
or removing `@inlinable` entirely.

**Pattern 4 — Scope boundaries in handoffs are permission, not obligation.**
The original handoff said "Phase B (L2 extensions) is acceptable to skip
if existing APIs cover." I read this as "skip unless needed" and closed
Phase B without adding the L2 Windows conformance — the existing L3
`File.Path.parent` covered the consumer migration, so the L2 gap
didn't block. But the L2 extensions had value beyond my consumer
migration (symmetry with iso-9945's POSIX conformance; availability for
any future L3 unifier refactor per `[PLAT-ARCH-008e]`). User direction
later expanded scope to add them. The `[HANDOFF-018]` rule says opt-out
clauses are preferences, not permissions — I took the opt-out too early.
Would have been cleaner to ask "is the symmetric L2 split desired even
though my consumer migration doesn't need it?" than to make the
unilateral skip.

## Action Items

- [ ] **[skill]** handoff: Add a note under `[HANDOFF-018]` (opt-out-as-
  preference) that the opt-out reading applies especially when the
  skipped work has value the current task doesn't consume — symmetry,
  future-refactor enablement, audit closure. Provenance: this session
  skipped Phase B's L2 Windows `Path.View` conformance based on the
  handoff's "acceptable to skip" clause, then user direction expanded
  scope to require it (a3fefbf). The opt-out was permission for the
  unusual case; the symmetric L2 split was the expected case here
  because the ecosystem was about to benefit from the L2 primitive
  independently of my consumer migration.
- [ ] **[research]** `@_spi(X)` + `@inlinable` incompatibility
  ecosystem survey: which modules have `@inlinable public` functions
  whose bodies reference symbols from another module that could
  plausibly be `@_spi`-gated in the future? swift-posix's Read/Write
  wrappers are one site; swift-posix's Flush, Socket wrappers are
  likely siblings; more broadly, any L3 platform-policy layer that
  delegates to an L2 raw. Classifies whether `@_spi(Syscall)` is a
  usable tool for L2/L3 disambiguation (ruled out here by this
  incompatibility) or fundamentally limited to non-inlinable boundaries.
- [ ] **[package]** swift-file-system: Record the Option D import-
  demotion as the in-scope mechanism for the next wave of
  `[PLAT-ARCH-008e]` follow-ons within the package's own domain —
  specifically, any future case where swift-file-system imports an L2
  whose surface could be hidden from downstream without losing the
  types the domain layer actually uses. The asymmetry-per-family
  principle (Read/Write's error types are L1; Socket's are L2) should
  be documented in the package's research notes so the Option-D test
  is reapplied per-family rather than blanketed.
