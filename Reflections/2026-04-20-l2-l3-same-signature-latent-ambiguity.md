---
date: 2026-04-20
session_objective: Execute HANDOFF-kernel-retry-wrapper-unifiers.md — land swift-kernel L3 unifier delegates for [PLAT-ARCH-008e] Findings #5–#16
packages:
  - swift-kernel
  - swift-iso-9945
  - swift-posix
status: pending
---

# Same-signature L2/L3 extensions create latent ambiguity — Phase A was not optional

## What Happened

Session goal was to land the retry-wrapper unifier bundle per
`HANDOFF-kernel-retry-wrapper-unifiers.md` — five concept-families
(Kernel.IO.Read/Write and Kernel.Socket.Accept/Send/Receive), one commit
per family, each an L3 cross-platform delegate routing through
swift-posix's EINTR-retry wrappers per [PLAT-ARCH-008e].

Execution was mechanical and matched the Phase C Flush precedent
(`f541a08`) and Connect precedent (`6741b6a`):

| Commit | Family | Findings |
|--------|--------|----------|
| `24cf586` | Kernel.IO.Read | #5, #6 |
| `5b0ae3b` | Kernel.IO.Write | #7–#9 |
| `bfa092e` | Kernel.Socket.Accept | #10 |
| `6a6d527` | Kernel.Socket.Send | #11–#13 |
| `5bd87f3` | Kernel.Socket.Receive | #14–#16 |

Audit rows for Findings #5–#16 transitioned to RESOLVED in `2afb251`
(folded into the user's concurrent RFC-Connect work; my audit edits were
in the working tree at the time of that commit). Each intermediate build
reported "Build complete!" so the session concluded with the implementation
phase.

Post-hoc verification exposed the blocker. When I advised the user on
next steps I ranked "verify the delegation actually takes precedence at
call sites" as highest-value; the user said "do as advised." A clean
`rm -rf .build && swift build` produced **five ambiguity errors** in the
test support files — `Kernel.IO.Read.read` and `Kernel.IO.Write.write`
now have two visible candidates (`ISO_9945_Kernel_File` and `Kernel_File`)
with identical signatures. Swift's name resolution cannot disambiguate.

The same structural collision exists for my three Socket commits and for
the pre-existing Connect commit (`6741b6a`), which was presumed working
when my handoff cited it as precedent. Socket/Connect don't surface
the error because no test calls the unifiers yet — the bug is latent,
waiting for the first consumer.

A parallel session created
`swift-kernel/HANDOFF-io-read-write-l2-l3-ambiguity.md` for a future agent
to fix the Read/Write instance. That handoff recommends a `.Raw.`
sub-namespace on iso-9945 — which the user explicitly forbade in
conversation ("We forbid 'iso-9945 under Raw namespace'"). I added an
addendum to that handoff documenting the constraint, proposing the
user-preferred import-demotion alternative, and flagging the Socket
family's latent breakage (which that handoff had correctly scoped out
but mis-described as structurally distinct).

**Session-artifact cleanup ([REFL-009] / [REFL-010])**:
- Deleted `swift-kernel/HANDOFF-kernel-retry-wrapper-unifiers.md` — the five
  commits it dispatched all landed; no ground-rules block; the downstream
  ambiguity is tracked by a different handoff and cites commit SHAs, not
  the handoff filename.
- Annotated `swift-kernel/HANDOFF-kernel-socket-connect-unifier.md` STATUS
  block noting that 6741b6a landed but carries the same latent
  same-signature collision class. Left the file in place as the Socket
  fix path is not yet dispatched.
- Left `swift-kernel/HANDOFF-io-read-write-l2-l3-ambiguity.md` — active,
  addendum appended this session.
- Did not triage `HANDOFF.md`, `HANDOFF-completion.md`, or
  `HANDOFF-kernel-random-fill-typed-throws.md` — this session had no
  context on their items; future sessions with context should triage.
- Added a "Latent ambiguity caveat" block to
  `swift-kernel/Audits/audit.md` §`L3 Composition — 2026-04-20` Summary,
  noting that the RESOLVED status on Findings #5–#17 refers to the
  unifier delegates landing; the ambiguity follow-up is tracked without
  reopening the findings.

## What Worked and What Didn't

**What worked:**
- Mechanical execution of the five commits was clean. Each built in
  isolation, each followed the stated file-naming and body-shape
  conventions, each commit message cited the resolved Findings and linked
  to precedent SHAs.
- Post-hoc verification caught the issue before the fix was pushed to
  origin or any downstream consumer-migration work started. The cost
  horizon is six commits, reversible.
- Honest escalation to the user when the user's "I don't understand,
  please verify" pushback arrived. Rather than defending the revert
  recommendation or silently retreating, I dug back in, re-examined,
  and confirmed the diagnosis with the demangled symbol table and the
  full ambiguity error list.

**What didn't work:**
- I accepted the handoff's claim — *"L2 names are already spec-literal
  (`read`, `pread`, `write`, `pwrite`, ...) — no Phase-A-style rename
  needed"* — without empirically testing the compiler. The claim was a
  load-bearing premise; it turned out to be wrong for the exact reason
  Phase A existed: Phase A wasn't about making iso-9945's names
  spec-literal, it was about making them *different* from what the
  unifier would use. Conflating "spec-literal" with "no collision" is
  the handoff author's error; failing to test the claim was mine.
- I treated the Connect commit (`6741b6a`) as proof-of-pattern because
  it landed and its module compiles. "Module compiles in isolation" is
  a weak proof — same-signature extensions can coexist at the module
  definition level and fail only at consumer call sites. Connect's
  module had no internal callers of the new unifier, and no test ever
  exercised it, so the ambiguity stayed latent. Using it as precedent
  propagated the latent break to five more commits.
- The first "Build complete!" after Commit 1 was taken as proof of
  correctness. In reality that build only exercised `Kernel_File`
  itself, not the test-support target that transitively imports both
  `ISO_9945_Kernel_File` and `Kernel_File`. The test-support target is
  the canary for cross-module ambiguity; skipping it means skipping the
  test.

## Patterns and Root Causes

**Phase A was not optional; it was the prerequisite.** The Flush handoff
executed a three-phase plan: (A) rename iso-9945's methods to spec-literal
POSIX man-page names, (B) extend swift-posix with the new intent-level
surface, (C) add swift-kernel cross-platform delegates. The audit author
for the retry-wrapper bundle read Phase A as an accident of Flush's
specific naming (informal `flush` vs spec-literal `fsync`) and generalised
that the Read/Write family was already at spec-literal naming so Phase A
was redundant. That generalisation missed Phase A's structural role: it
made iso-9945's names *different from the unifier's chosen name*. For
Flush, "different" happened to coincide with "spec-literal" because the
unifier chose `flush`. For Read/Write, the unifier's chosen name *is* the
spec-literal name — so iso-9945 and swift-kernel now want the same slot
under `Kernel.IO.Read`, and the compiler can't tell them apart.

The implicit rule this reveals:

> **[PLAT-ARCH-008e] disambiguation invariant**: when the L2-raw method
> name equals the L3-unifier method name on the same type, the L3 unifier
> cannot land alongside the L2 raw without a disambiguation mechanism
> (rename one side, demote L2's module visibility, @_disfavoredOverload,
> or equivalent). The mechanism is not optional — the naming collision
> emerges at any consumer call site that sees both modules, and Swift's
> module system does not silently prefer one.

This is a generalization of the Flush precedent, not new architecture.
It should be codified before the next syscall-family remediation
(`Socket.*`, `File.Open`, `File.Close`, future eventing families) runs
into the same wall.

**"Compiles" and "works" are different propositions.** Same-signature
extensions from different modules pass module-local type-checking — each
module's declarations are coherent in isolation. The ambiguity emerges
only at a call site that can see both. Building the library target alone
(as `swift build` does by default in swift-kernel's layout) doesn't
exercise that call site. This means "build green" after landing an
[PLAT-ARCH-008e] remediation is not a correctness signal; "all build
products including tests compile" is. The ecosystem should treat
`swift build --build-tests` as the minimum verification bar for
cross-module refactorings.

**Trust-but-verify applies to handoffs, not just to code.** The handoff's
load-bearing claim ("no Phase-A-style rename needed") was textual, not
tested. When a handoff states that a precursor step is unnecessary, the
claim is a hypothesis about compiler behavior — it admits to an empirical
test (synthesize a call site that would be affected, build, observe).
Accepting the claim unexamined is accepting a proof obligation. The
Connect precedent I cited in my commit messages inherited the same
untested claim from the same audit — propagating it via commit messages
gave the pattern false weight.

## Action Items

- [ ] **[skill]** platform: Add [PLAT-ARCH-008e]-adjacent sub-rule
  codifying the disambiguation invariant. Statement: when the L2-raw
  method name equals the L3-unifier method name on the same type, the
  remediation MUST include a disambiguation step before the L3 unifier
  lands; "L2 names are already spec-literal" is not by itself sufficient,
  because the unifier's chosen name may also be spec-literal. Cite the
  Read/Write discovery (2026-04-20) and the Flush Phase A precedent.
  Include verification requirement: `swift build --build-tests` clean,
  not just `swift build`.
- [ ] **[research]** How does `MemberImportVisibility` interact with
  `@_exported public import` in the re-export chain? Specifically: does
  `@_exported` flag a re-exported module as "directly imported" for
  MemberImportVisibility purposes, bypassing the direct-import
  requirement? This determines whether the proposed import-demotion fix
  in `HANDOFF-io-read-write-l2-l3-ambiguity.md` Addendum §3 actually
  works, or whether `@_disfavoredOverload` is the real minimum. Blocks
  the ambiguity fix plan.
- [ ] **[skill]** handoff: Add requirement that a handoff's load-bearing
  premise claims (e.g., "step X is not needed", "names are already Y",
  "precedent Z validates the pattern") MUST be verified empirically by
  the executing agent before the first commit lands, not treated as
  established fact. "Precedent compiles" is insufficient when the
  precedent itself may be latently broken; require a representative
  consumer call site to exercise the pattern end-to-end.
