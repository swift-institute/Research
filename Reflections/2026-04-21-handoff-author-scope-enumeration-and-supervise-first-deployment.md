---
date: 2026-04-21
session_objective: Resolve the Kernel.IO.Read/Write L2/L3 overload ambiguity surfaced during the swift-file-system typed-path migration; address a parallel [PLAT-ARCH-002] violation (Darwin/Linux code hosted in swift-posix); prepare the Socket family follow-on handoff and dispatch it under explicit /supervise ground rules.
packages:
  - swift-kernel
  - swift-iso-9945
  - swift-posix
  - swift-darwin
  - swift-linux
  - swift-file-system
  - swift-sockets
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Handoff-author scope enumeration as attestation; /supervise first deployment

## What Happened

Session started with a live compile failure: `Kernel_Test_Support` target
emitting `ambiguous use of 'read(_:into:)'` / `'write(_:from:)'` blocking
`swift test` across swift-kernel, swift-iso-9945, swift-posix,
swift-file-system, swift-io. Root cause already diagnosed in
`HANDOFF-io-read-write-l2-l3-ambiguity.md`: iso-9945's `ISO_9945.Kernel`
typealiased to `Kernel_Primitives.Kernel`, so `extension
ISO_9945.Kernel.IO.{Read,Write}` and swift-kernel's L3 unifier
`extension Kernel.IO.{Read,Write}` land identical `public static func`
signatures on the same underlying type. Swift's name lookup cannot
disambiguate.

Session progressed through four connected pieces of work:

**1. Read/Write ambiguity fix** (swift-iso-9945 `9aa06e6`). Handoff's
"Option A" (Raw sub-namespace) was user-forbidden per Addendum §1.
Addendum §3 recommended import-demotion (internal import of
`ISO_9945_Kernel_File` in swift-posix, relying on
`InternalImportsByDefault` + `MemberImportVisibility` to confine iso-9945
visibility). Attempted — failed immediately: every
`POSIX.Kernel.IO.{Read,Write}` retry wrapper is `@inlinable`, and
`@inlinable` bodies cannot reference symbols from internally-imported
modules (compiler emits "property/method is internal and cannot be
referenced from an '@inlinable' function" for every call into
`Kernel.IO.Read.read`, `isInterrupted`, `ISO_9945.Kernel.*`). Reverted
immediately. Pivoted to Addendum §3's named fallback: `@_disfavoredOverload`
on all 10 iso-9945 L2 Read/Write `public static func` declarations. One
line per method; no body change; L3 unifier wins resolution cleanly;
raw L2 access remains reachable via qualified `ISO_9945.Kernel.IO.*`
path. 90/90 swift-kernel tests pass on Darwin.

**2. Collateral test-baseline cleanup** (swift-iso-9945 part of
`9aa06e6`; swift-file-system `adffc10`). Two pre-existing
duplicate-`@Test`-name defects surfaced once the ambiguity cleared:
`ISO 9945.Kernel.Thread.Handle Tests.swift:57` had two `\`Handle type
exists\`()` siblings in the same `@Suite Unit` (macro expansion emitted
"invalid redeclaration of '$s...Handletypeexists...'"); renamed the
second to `\`Handle is @unchecked Sendable\`()` matching its section
intent. `File.System.Stat Tests.swift:207` had two identical
`\`info(followSymlinks: false) returns symbolicLink type for symlink\`()`
siblings; renamed the second with a `(Handle API)` suffix to reflect
its distinct File.Handle-based creation path. Separately, the parent
session's typed-path migration (`41e1458`, `8f19d65`) had not updated
the error tests — `let path: Swift.String = "/…"` was still passed to
error cases whose associated values had become `File.Path`. Migrated
across `Write.Atomic Tests`, `Write.Atomic.Error Tests`, `Write.Streaming
Tests`, `Write.Streaming.Error Tests`: `let path: Swift.String = "/…"`
→ `let path: File.Path = "/…"` (via `ExpressibleByStringLiteral`);
wrapped `error.description.contains(path)` call sites in
`Swift.String(path)`; removed the obsolete `path:` argument from
`Write.Streaming.Error.writeFailed(path:, bytesWritten:, …)` sites (the
current signature has no `path:`). Restored 712/712 swift-file-system
test baseline.

**3. `[PLAT-ARCH-002]` violation in swift-posix** (swift-darwin
`1d57f80`, swift-linux `43a43e0`, swift-posix `30c1152`, swift-kernel
`e9bafc5`, swift-file-system `ce0a511`). User flagged
`POSIX.Kernel.File.Flush+Data.Darwin.swift` — a Darwin-only policy
wrapper hosted in swift-posix (the POSIX-SHARED L3 policy tier).
Investigation surfaced three violations total:
`POSIX.Kernel.File.Flush.swift` had a `#if os(Linux)` block with `.data`
via `fdatasync` (Linux-only; doesn't run on Darwin because Darwin
doesn't implement fdatasync), a `#if canImport(Darwin)` block with
`.full` via `F_FULLFSYNC` and `.barrier` via `F_BARRIERFSYNC` (both
Darwin-only fcntl commands), and the whole `+Data.Darwin.swift` file
with a second `.data` variant via barrierFsync. Relocated: Darwin
policy → `Darwin.Kernel.File.Flush.{data, full, barrier}` in
swift-darwin; Linux policy → `Linux.Kernel.File.Flush.data` in
swift-linux (with a new `swift-iso-9945` package dep added to
swift-linux's Package.swift); POSIX-shared `flush(_:)` (fsync) stayed in
swift-posix; POSIX-shared `directory(path:)` (open+fsync composition)
stayed in swift-posix. Discovered mid-implementation: because
`Darwin.Kernel == Kernel_Primitives.Kernel` via typealias (same for
`Linux.Kernel`), `extension Darwin.Kernel.File.Flush { public static
func data(_:) }` IS `extension Kernel.File.Flush { public static func
data(_:) }`. A swift-kernel unifier that delegated `Kernel.File.Flush.data
→ Darwin.Kernel.File.Flush.data` would be redeclaring the same method on
the same type — compile error, not composition. Removed the
`Kernel.File.Flush.data` delegate from swift-kernel's cross-platform
file; platform packages own the unified name directly on their target
platform. swift-file-system's consumer `#if` in
`File.System.Write+Shared.swift` collapsed from a three-branch selector
into a single `Kernel.File.Flush.data(fd)` call (closing a parallel
`[PLAT-ARCH-008d]` syscall-vs-policy violation).

**4. Socket family handoff dispatched under /supervise** (swift-kernel
`2bca73f` for handoff + audit amendments, `64c207f` for supervisor
block, `688574a` for scope extension). Wrote
`HANDOFF-socket-family-l2-l3-ambiguity.md` as a preventative twin of
the Read/Write fix — 10 iso-9945 Socket L2 declarations (Accept ×2,
Connect ×4, Send ×2, Receive ×2) get `@_disfavoredOverload` under the
same mechanical rule. Latent today because no tests exercise the
Kernel-namespace Socket unifiers yet AND swift-sockets main is blocked
by an unrelated Phase-2 IO refactor (`Sockets.Error.swift` importing a
removed `IO_Core`). Audit.md Findings #10–#17 paths amended to point
at the post-migration swift-sockets locations (the unifier files moved
from swift-kernel to swift-sockets in commits `2c63378` + `9a83433`).

Invoked `/supervise` per the user's direction; embedded a ground-rules
block in the handoff's new `## Supervisor Ground Rules` section with 6
typed entries (1 scope fact, 2 MUST, 3 MUST NOT, 1 ask), 7 acceptance
criteria each naming its [SUPER-009] positive verification source, and
handoff-specific drift signals. Provided a copy-pastable dispatch
instruction.

**Subordinate caught a drafting error on first run.** The ground-rules
block's scope fact (#1) said 10 declarations; the MUST NOT (#4)
explicitly forbade tagging iso-9945's `Send.to(_:…)` and
`Receive.from(_:…)` with rationale "no matching swift-sockets unifier
today." Subordinate ran the `[HANDOFF-016]` staleness check (`grep -nE
"public static func (connect|accept|send|receive|message)"` across
both packages) before starting work, discovered the rationale was
false: `Kernel.Socket.Send+CrossPlatform.POSIX.swift:70` and
`Kernel.Socket.Receive+CrossPlatform.POSIX.swift:70` BOTH carried live
collisions with signatures bit-for-bit identical to the iso-9945
declarations. Halted at the file-write boundary, surfaced the finding
with a three-options table, recommended Option 2 (extend to 12) but
deferred the decision to the principal (me) per [SUPER-005] class (b).

Verified independently with my own grep (not trusting subordinate
attestation per [SUPER-009]). Confirmed. Classified as class (b) —
factual within principal's authority, no user escalation needed because
the user's scope (preventative fix for all Socket-family ambiguities)
didn't change; only my drafting-time enumeration of that scope was
wrong. Extended ground rules per [SUPER-015]: entry #1 scope fact
updated from 10 to 12 with a revision annotation; entry #4 formally
retired (strikethrough + replacement guidance), `(merges into #1)`
notation. § Relevant Files collision map gained two rows; the "NOT
part of this fix" subsection was replaced with a drafting-note block
retaining the original false claim for traceability. Commit template
and Appendix C counts updated 10→12. Committed as `688574a`.

**Memory entries authored**: `feedback_inlinable_blocks_internal_import`
(capturing the `@inlinable` + `internal import` incompatibility for
future sessions to avoid re-attempting the Read/Write import-demotion
route), `feedback_typealiased_namespace_unifier_collapse` (capturing
the Darwin/Linux typealias collapse for future platform-policy
decisions). Both indexed in MEMORY.md.

**Handoff scan per [REFL-009]**: 5 files found at
`swift-foundations/swift-kernel/`; 0 deleted, 0 annotated, 3
out-of-session-scope, 2 left active.

| File | Session authority | Disposition |
|---|---|---|
| `HANDOFF.md` | Out of authority (not touched, items not worked) | No action |
| `HANDOFF-completion.md` | Out of authority | No action |
| `HANDOFF-io-read-write-l2-l3-ambiguity.md` | In authority (Findings section authored this session; primary scope landed) | Left active — Addendum §4 cross-reference pointer to the Socket handoff's landing SHA is an acceptance criterion on the live Socket handoff (#7), not complete in-session; file will close when the Socket dispatch lands and stamps §4 |
| `HANDOFF-kernel-random-fill-typed-throws.md` | Out of authority | No action |
| `HANDOFF-socket-family-l2-l3-ambiguity.md` | In authority (authored, amended, and dispatched this session; subordinate actively running) | Left active — supervisor ground-rules block embedded per [SUPER-014]; [SUPER-011] verification line will be stamped when the subordinate reports success termination; cannot delete while supervision is in-flight |

**Audit status transitions per [REFL-010]**: None. Path amendments to
`swift-kernel/Audits/audit.md` §L3 Composition Findings #10–#17 were
editorial (post-`2c63378`+`9a83433` migration path fixes plus
cross-references to handoffs); each row stayed `RESOLVED` at its
existing unifier-landing SHA. Findings #5–#9 (Read/Write) similarly
stayed RESOLVED; the `@_disfavoredOverload` landing is a follow-on
correctness fix, not a separate finding. No `OPEN → RESOLVED` /
`OPEN → FALSE_POSITIVE` / `OPEN → DEFERRED` transitions to record.

## What Worked and What Didn't

**Worked**:

- **The Read/Write handoff's Addendum §3 named its own fallback.** The
  import-demotion route failed within minutes of attempting it; because
  Addendum §3 had already written out `@_disfavoredOverload` as the
  fallback ("fall back to @_disfavoredOverload on iso-9945's Read/Write
  public static func declarations — a one-line-per-method change that is
  narrow and reversible"), the pivot cost was near-zero. A handoff that
  pre-stages its plan-B eliminates the most expensive failure mode of
  plan-A: the investigator re-deriving the fallback from cold state.
- **Three failure modes caught at the `[PLAT-ARCH-002]` violation
  discovery.** User flagged one file; grep for `#if os` patterns
  surfaced three violations total (one file plus two blocks inside
  another file). Scoping to "the file the user named" would have missed
  two of them. Mechanical scope expansion via pattern detection after a
  user flag is worth making routine.
- **Supervise ground-rules block produced the correct subordinate
  behavior on first deployment.** The subordinate halted at a
  file-write boundary (drift-signal-adjacent: expanding scope without
  asking is signal #3; silent decision on open question is #6), ran the
  `[HANDOFF-016]` staleness check, reported a three-options table with
  a recommendation, and explicitly deferred the scope decision to the
  principal. No silent rewrite. No scope creep. No re-proposed rejected
  alternative. The block worked exactly as designed.
- **[SUPER-015] progressive refinement composed cleanly.** Retiring
  entry #4 with strikethrough + replacement guidance and annotating
  "(merges into #1)" preserved the constraint-history audit trail. A
  future principal reading the supervisor block can reconstruct why
  entry #4 was authored, why it was wrong, and what replaced it.
- **`internal import` + `@inlinable` lesson captured twice in one
  session without re-investigation.** First failure during Read/Write
  import-demotion attempt; second anticipation when drafting the
  Socket handoff's § Rejected alternatives. The rule held cleanly on
  application. The memory entry written at session end exists
  specifically so the third encounter (whoever picks up a future
  similar handoff) doesn't re-derive it.

**Didn't work**:

- **Handoff author attested to a scope count without verifying it.**
  When I drafted the Socket handoff's § Relevant Files, I enumerated
  10 iso-9945 declarations that collide with swift-sockets unifiers.
  That count was wrong — there were 12. The error was author-side
  incomplete verification, not upstream drift: both `to(_:…)` and
  `from(_:…)` landed in swift-sockets commit `9a83433`, the SAME
  migration commit the handoff already cites. My enumeration missed
  two rows of the collision map by not running the same grep the
  subordinate ran on day 0. The `[HANDOFF-016]` "Assumes: iso-9945
  Socket method signatures listed in § Relevant Files match what's in
  swift-sockets' unifiers today. Re-verify via `grep -nE …`" section I
  authored explicitly listed the command the subordinate should run
  — I just didn't run it myself before writing "10 matching pairs."
- **Ground-rules entry #4 was grounded in a false premise.** The MUST
  NOT "don't preemptively tag `to`/`from`" was correct in intent
  (don't disfavor uncompeted overloads) but used a factually wrong
  justification ("no matching swift-sockets unifier today"). The wrong
  justification is strictly worse than a right justification plus the
  wrong conclusion: a subordinate who checks the justification
  empirically (as this one did) immediately discovers the rule is
  inverted. The supervise skill's [SUPER-004] demands rationales
  precisely because a rule without one is wallpaper; a rule with a
  false rationale is a trap.
- **Cleanup of swift-posix Flush violations was discovered reactively,
  not through proactive `[PLAT-ARCH-002]` scan.** The user had to
  flag `+Data.Darwin.swift` for me to notice the broader pattern. A
  session earlier in the ecosystem's evolution would have run a
  `grep -rn '#if os\|canImport' swift-posix/Sources` before accepting
  any handoff involving swift-posix — as standing discipline. The
  violation class is structurally discoverable by grep.

## Patterns and Root Causes

**Pattern 1: The handoff author's scope enumeration is attestation,
not verification.** [REFL-006]'s "Read the artifact, not the summary"
rule applies to document review; the same anti-pattern appears in a
different form during handoff authoring. When I wrote "10 collisions"
in the Socket handoff, I was summarizing my own mental model of the
collision surface — not verifying by re-running grep. The subordinate's
first action was to run grep; it caught the error immediately. The
asymmetry is load-bearing: *the handoff author has the fullest context
to produce the scope enumeration and the least incentive to verify it*
(they believe they know the answer). The subordinate has the least
context and the highest incentive to verify (their acceptance criteria
depend on the enumeration being right). The fix is mechanical: for any
handoff whose scope is "apply X to every Y," the handoff MUST include
the exact command that produces the set Y, AND the handoff author
MUST run it before declaring the enumeration. The subordinate re-runs
the same command on dispatch as step 0 of `[HANDOFF-016]` staleness
check; any mismatch between their output and the handoff's enumerated
list halts-and-reports. This is strictly stronger than "verify
assumptions" — it names the specific verification command and puts it
in the handoff.

**Pattern 2: Typealiased namespace + `public static func` extension =
same-method-on-same-type, full stop.** Three separate composition
shapes arose in this session that all reduce to this single fact:

| Layers | Typealias? | Composition shape |
|---|---|---|
| iso-9945 (L2) + swift-sockets (L3) on `Kernel.Socket.*` | Yes: `ISO_9945.Kernel = Kernel_Primitives.Kernel` | Same-signature extensions = overload collision, resolved via `@_disfavoredOverload` on L2 |
| swift-posix (L3 policy) + swift-kernel (L3 unifier) on `POSIX.Kernel.*` → `Kernel.*` | No: `POSIX.Kernel` is its own empty enum | Swift-kernel unifier explicitly delegates `POSIX.Kernel.X.y(…)` via qualified name; two distinct methods on two distinct types |
| swift-darwin (L3 policy) + swift-kernel (L3 unifier) on `Darwin.Kernel.*` → `Kernel.*` | Yes: `Darwin.Kernel = Kernel_Primitives.Kernel` | Platform package extension IS the Kernel extension; a swift-kernel delegate with matching signature is redeclaration; platform package owns the unified name directly |

The decision procedure is: *is the L3 policy namespace typealiased to
the primitives namespace?* If yes → composition-via-delegation in
swift-kernel is impossible (redeclaration) → platform package owns the
name. If no → composition-via-delegation in swift-kernel is feasible
and preferred. swift-posix deliberately avoided the typealias by
declaring `POSIX.Kernel` as its own enum; that design choice enabled
the explicit-delegation pattern `[PLAT-ARCH-008e]` codifies. The
platform packages (swift-darwin, swift-linux, swift-windows) took the
other design choice for reasons adjacent to cross-platform parity;
that choice forces the platform-package-owns-the-unified-name pattern.
Neither design is wrong; they just require different composition shapes.

**Pattern 3: Supervise worked as a load-bearing artifact, not ceremony.**
The ground-rules block's role was not to tell the subordinate what to
do (the copy-pastable instruction did that); it was to *raise the cost
of silent scope deviation*. When the subordinate discovered the
10→12 mismatch, the options in front of them were: (a) decide
unilaterally (drift signal #6), (b) extend scope without asking (#3),
or (c) halt and surface. The block made option (c) the dominant
strategy: entry #1 named the exact count as a scope fact, entry #4
named the `to`/`from` exclusion with rationale, and the ask: entry #6
enumerated triggers for halting. When an unanticipated finding didn't
match any ask: trigger precisely, the subordinate still inferred the
halt-and-report posture from the block's overall shape. The
[SUPER-015] compression notation — `(merges into #1)` — then preserved
the constraint-history audit trail across the revision. The block's
value was in making silent-rewrite the expensive option; correction
cost less than deviation.

**Pattern 4: `[PLAT-ARCH-002]` violations are grep-discoverable.** The
swift-posix Flush violations surfaced only because the user flagged
one file; a proactive `grep -rn '#if os\|canImport' <L3-policy-pkg>/`
would have caught all three. This generalizes: swift-posix is the
POSIX-shared L3 policy tier; ANY `#if os` or `#if canImport` in its
sources is either (a) a legitimate file-level build guard that should
still be rare, (b) a platform-specific wrapper that belongs in the
platform-specific L3 package, or (c) technical debt. Running the grep
periodically is cheap; classifying each hit is the principled work.
The reverse is also true: `grep -rn '#if os\|canImport' swift-darwin/
swift-linux/ swift-windows/` inside platform-specific L3 packages
should yield MANY matches — absence there would suggest the package
isn't carrying the platform specificity it's supposed to.

## Action Items

- [ ] **[skill]** handoff: When a handoff's scope is "apply X to every
      Y", the handoff author MUST (a) include the exact grep / detection
      command that enumerates Y inside the handoff body (not just name it
      in the `[HANDOFF-016]` Assumes block), (b) run the command and
      paste its output into § Relevant Files, and (c) flag the
      enumeration explicitly as "produced by the following command at
      handoff-drafting time; re-run before starting work." Subordinates
      then re-run the same command as step 0 of staleness check. This
      prevents the author-attestation failure mode that fired on the
      Socket handoff 10→12 scope error. Candidate IDs: extend
      `[HANDOFF-016]` with a scope-enumeration subsection, or new
      `[HANDOFF-021]` if a dedicated ID reads cleaner.

- [ ] **[skill]** platform: Codify the typealiased-namespace composition
      decision as a rule ID, extending the Darwin/Linux/Windows
      platform-package guidance. Proposed shape: *"When the L3 policy
      tier's namespace is typealiased to Kernel_Primitives.Kernel (the
      Darwin/Linux/Windows pattern), the platform package's extension
      methods land directly on the shared Kernel.X namespace; a
      swift-kernel unifier with matching signature is redeclaration.
      Platform packages own the unified name directly on their target
      platform. Contrast swift-posix, where POSIX.Kernel is a distinct
      enum and `[PLAT-ARCH-008e]` explicit delegation applies."* Prior
      art: this session's Flush relocation landing (swift-darwin
      1d57f80, swift-linux 43a43e0, swift-kernel e9bafc5) plus
      memory entry `feedback_typealiased_namespace_unifier_collapse`.

- [ ] **[skill]** supervise: Add a worked example to [SUPER-015]
      progressive refinement using this session's entry #4 retirement
      — the strikethrough + replacement-guidance + `(merges into #1)`
      pattern applied cleanly and preserved audit trail. The existing
      [SUPER-015] text describes the mechanism abstractly; a concrete
      example grounds it. Session provenance:
      `swift-kernel/HANDOFF-socket-family-l2-l3-ambiguity.md` at
      commit `688574a`.
