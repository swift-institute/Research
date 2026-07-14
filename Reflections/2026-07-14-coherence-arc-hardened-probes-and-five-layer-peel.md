---
date: 2026-07-14
session_objective: Run the ecosystem-coherence arc as orchestrator seat — harden the probe instruments, sweep spec-identity and CI-declaration coherence, land the named quick wins
packages:
  - swift-comparison-primitives
  - swift-hash-primitives
  - swift-product-primitives
  - swift-either-primitives
  - swift-windows
  - swift-iso-9945
  - swift-ieee-1003
status: pending
---

# Coherence Arc: Hardened Probes and the Five-Layer Peel

## What Happened

Seat session for CHARTER-ecosystem-coherence-2026-07-14, closed TERMINATION: SUCCESS
(supervisor-stamped 14:01:49). Four waves: W1 landed `Scripts/eco-probe.sh` — six
positive-controlled probe primitives that abort loudly on unproven zeros (selftest 11/11
including deliberate-failure demonstrations). W2 swept spec-identity coherence over 451
packages via a new `spec-claims` primitive; headline: the POSIX pair's mutual silence
verified worse than charted (iso-9945's README literally titled "POSIX Primitives", zero
volume statement), plus an obsoletes-lineage silence class (rfc-4122↔9562 both README-less)
and a controls-backed proven zero (no same-namespace double declarations). W3 audited every
package's [CI-114] platform declaration against live job-level conclusions: 442 warranted-no,
9 adjudicated, zero green legs retired. W4a re-derived and fixed the Equation_Primitives
[MOD-038] edges (4 commits, pushed on green clean-graph gates; swift-witnesses unmasking
verified; the old audit's "nothing blocks in CI" deferral refuted in writing). W4b took
swift-windows' Windows leg from never-green to GREEN (run 29329874654, 21 tests passed)
through a five-layer peel: missing type → 21 stale String call sites → wrong bridge
organization (supervisor REDO per [TEST-032]) → parallel-fixture name race → a UTF-16-read-
as-CChar decode fossil in production. Every layer was attributed from its own CI job log.

Channel: 12+ ledger ASK/ANSWER rounds at minutes-latency, one standing class grant
([MOD-038] additive edges), one health-check ACK, explicit release at close. One misrouted
principal relay (an L2-orchestrator directive) was declined rather than executed — ACKing
another seat's channel would have falsely certified its dead watch.

Artifact cleanup: root HANDOFF scan clean (0 files at ~/Developer root). check-handoffs.sh
reports the known red-by-design WIP overage (57>40) plus one out-of-authority resident
(PROGRAM-repotraffic-endstate — other program, in flight); this arc's records
(CHARTER-ecosystem-coherence + INVENTORY-coherence) are drain-eligible per the per-arc-close
cap ruling but the charter is the supervisor's artifact with the R5 disposition still open —
left for the store owner's drain. Memory guard OK (target-zero holds).

## What Worked and What Didn't

**Worked.** Positive-control discipline caught THREE instrument defects in-session before
they became findings: the spec-claims decl-regex counting `@_exported public import enum`
re-exports as declarations (false RFC_1123 double-declaration — fixed with an import guard +
negative synthetic control); case-insensitive short-token README greps matching `iso` inside
`isOptionShaped` (false "states it" on the exact pair under audit); and a heuristic per-target
checker false-negativing 8 of 11 [MOD-038] flags including an edge fixed minutes earlier
(lazy body-capture regex). Per-log attribution ([SUPER-031]) separated all five W4b layers
cleanly — including proof-by-disappearance (the Glob error count going to zero while the leg
stayed red) and distinguishing a fixture's own guard-throw from an implementation failure by
matching the error's path string shape. The interim "failed" CI run had more information
value than a green one would have.

**Didn't.** I fell into the charter's own trap table twice while HUNTING those traps: zsh
command-substitution word-split on institute paths in ad-hoc recon (`$(find …)` splits even
though `$var` doesn't), and my own decl-regex import false-positive. Both were caught by
verification, not avoided by knowledge — the traps beat recall and lose to controls,
which is the arc's thesis restated. The W4b bridge iteration was a genuine process failure:
I authored test fixtures without loading the testing skill ([TEST-032] forbids exactly the
free-function shape I wrote, and my wrappers shadowed the production entry point's name),
costing a supervisor REDO and a CI round-trip — this after the charter's boot instruction
said "load every skill you cite" and after I had done so diligently for CI/MOD/PLAT rules.
The charter itself carried two factual errors I had to correct against primary sources
(module `Equation_Primitive` vs the real racing module `Equation_Primitives`; "Shell &
Utilities" vs the real Base Definitions XBD Ch.12 volume) — the second propagated into my
first README commit because I treated charter text as verified fact; the supervisor's REDO
caught it against the research seat's DECISION doc.

## Patterns and Root Causes

**The signature generalizes from probes to every belief-producing artifact.** The charter
named it for search probes ("cannot distinguish nothing-there from didn't-look"), but the
session found the same shape in: skipped CI matrix jobs carrying unrendered `${{ }}` names
(rendered-name matching silently misses them), single-line greps on line-wrapped Swift calls
(the supervisor's own sibling sweep returned zero on `String(cString` for a package
containing exactly that call), a heuristic checker's flags (state claims needing
re-derivation), and background-task output files read before flush. The general rule: any
tool's empty/green output is a state claim bounded by the tool's reach, and the reach must be
checked against the claim's scope — which is [REFL-011]'s tool-reach extension observed live,
four times, in one session.

**Layers mask layers; a never-green leg carries zero information below its first failure.**
swift-windows' suite had BOTH a compile error and a runtime production bug for the file's
entire life — the type error kept the suite from ever running, so the decode fossil was
unobservable on every platform including Windows. Each of the five fixes revealed the next
defect. Corollary for estimation and for termination criteria: "fix the reported error" is
not "green the leg"; the honest unit of work is the peel, not the layer. This is the
emit-module lesson (a build that dies early proves nothing about what is behind it) extended
to its limit case.

**Relocation fossils are a defect class.** Two independent production bugs today trace to
dependency relocations that moved the import but not the assumption: the Glob CChar readout
(correct for its UTF-8 POSIX-named ancestor, wrong after the L2→L1 move to UTF-16 paths) and
iso-9945's CRT emulation (§7f, reverted). When a platform/encoding boundary moves, every
unsafe readout and every `#if` chain inherited across the move needs re-derivation — the
compiler cannot see that the assumption changed when the types happen to still line up
through unsafe pointer casts.

**Skill-loading discipline decays under momentum, and the decay is predictable.** I loaded
rules diligently when the charter told me to (SUPER, CI, MOD, PLAT) and skipped exactly once —
authoring "trivial" test helpers mid-iteration under CI-latency pressure — and that one skip
produced the arc's only REDO. The failure wasn't ignorance of the discipline; it was that
fixture-authoring didn't register as "citing a skill" because no rule ID was in view. The
trigger needs to be the ARTIFACT CLASS (writing test support code → load testing skills),
not the presence of a rule ID in what I'm about to write.

## Action Items

- [ ] **[skill]** testing: [TEST-032] — document the scoped borrowing-fixture shape
  (`static func with*(_ body: (borrowing T, …) throws -> Void)` on the suite namespace) and
  the discovered language constraint that motivates its error-handling guidance: a borrowing
  `~Escapable` parameter cannot be captured in an `#expect(throws:)` closure — the sanctioned
  alternative is typed do/catch where reaching the catch IS the pass condition (swift-windows
  Glob suite, b1c0eaa).
- [ ] **[skill]** modularization: [MOD-038] — add the masking mechanism to the failure-shape
  text: undeclared edges on umbrella targets fail NONDETERMINISTICALLY on clean graphs and
  read as "the fix didn't take"/"flaky CI" in unrelated consumers, which is how the class
  survives audits that ask only "does anything block in CI" (refutation recorded in
  INVENTORY-coherence-2026-07-14 R2).
- [ ] **[blog]** "The test suite that never ran": the five-layer peel as a story about
  verification reach — two bugs coexisting invisibly for a file's whole life because the
  outer one kept the inner one from ever executing; per-log attribution and
  proof-by-disappearance as the method; first green in the suite's existence as the payoff.
