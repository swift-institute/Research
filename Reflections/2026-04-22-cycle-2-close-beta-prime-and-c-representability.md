---
date: 2026-04-22
session_objective: Dispatch, supervise, and close Cycle 2 (Doc 3 P2.3 #3 Signal.Action.Handler siginfo_t L2 wrapper) through β' mid-cycle revision and termination stamp.
packages:
  - swift-iso-9945
  - swift-institute/Audits
  - swift-institute/Research
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Cycle 2 close — β' mid-cycle Decision revision and `@convention(c)` representability gap

Companion to `2026-04-22-supervisor-arc-investigation-through-cycle-two-dispatch.md` (which covered the arc through dispatch). This entry captures what happened *after* dispatch: the β' mid-cycle revision, the termination stamp, and two new empirical findings that invalidate part of Doc 3's pre-cycle analysis.

## What Happened

Cycle 2 dispatched under Pattern C (user-as-supervisor of a fresh subordinate; me-as-advisor-to-user) to implement Doc 3 Principal Decision #1 (Option 1 staged) — a retype of `Signal.Action.Handler.customInfo`'s case payload from `UnsafeMutablePointer<siginfo_t>?` to `UnsafeMutablePointer<Kernel.Signal.Information>?`, backed by a new `Kernel.Signal.Information` layout-compatible siginfo_t wrapper.

The subordinate executed through four intervention points cleanly, then hit a wall at IP5:

**IP5-first-failure**: `@convention(c)` signatures reject `UnsafeMutablePointer<Kernel.Signal.Information>` as a parameter type. Swift's `@convention(c)` function-pointer type imposes `@objc`-representability on all parameter types; a pure-Swift struct (even layout-compatible with a C type) is NOT `@objc`-representable. Advisor authorized Option A (`@convention(c, cType: "…")` annotation as fix).

**IP5-second-failure**: Subordinate re-inspected and found that `@convention(c, cType:)` is a Clang-importer-only construct — it does not relax Swift's semantic `@objc`-representability check on user-written function types. Plus a second empirical finding surfaced: importing `Kernel_Memory_Primitives` (needed for `.fault: Kernel.Memory.Address?` in Option 1) triggered synthesized `.caseName` accessors on Tagged-derived `Optic.Prism<Enum, Part>` types that collided with enum-case pattern matches at consumer sites (observed at `Configuration.swift:85`). Option 1 as specified was structurally unachievable under Swift 6.3.1.

Subordinate proposed **Option β'**: keep only the `Information` wrapper and its three typed accessors; revert the case-signature retype, the import demotion, and the Package.swift Memory dependency. Principal (via advisor draft) revised Doc 3 Principal Decision #1 in-line, stamping the β' shape as the working spec without aborting the cycle.

β' then executed through four tactical iteration rounds to reach CLEAN builds — all caused by Glibc/Darwin `si_code` constant type divergence (`FPE_*`/`ILL_*`/`CLD_*` import as `Int` on glibc, `Int32` on Darwin; uniform `Int32(…)` wrapping resolved it). All four rounds were correctly classified as tactical within β' scope; no structural re-escalations.

IP5 closed CLEAN: macOS `--build-tests` 3.59s, Docker Linux swift:6.3.1 `--build-tests` 10.60s, swift-posix downstream 2.79s. Cycle 2 shipped as a single new file (`Information.swift`) plus a tracker entry plus a handoff termination stamp — three commits total across two repos (`2a5e5fe`, `cd15bdd`, `891e935`). [SUPER-011] verification: 10/10 β'-revised acceptance criteria + 6/6 ground-rules entries (rules #1/#2 partially superseded by mid-cycle revision, β' spec honored exactly).

**Handoff scan**: 2 files found at `swift-institute/Audits/` root — `HANDOFF-platform-audit-remediation.md` (annotated-and-left: still tracks open Windows CI + P3 items outside the layer-perfection loop) and `HANDOFF-layer-perfection-implementation.md` (annotated-and-left: Cycle 3 trigger-ready; Cycles 1+2 stamped CLOSED inside the file). Zero deletions; both retained with accurate annotations per [REFL-009].

**Audit findings updated**: P2.3 #3 moved to PARTIAL CLOSE in `platform-compliance-2026-04-21.md` via commit `cd15bdd`; mirrors the P2.4 #8 PARTIAL precedent from Cycle 1. Two deferred halves recorded in-tracker: Handler.customInfo case-signature retype (blocked on Swift language evolution or Option 4 design cycle) + .fault upgrade from `UInt?` to `Kernel.Memory.Address?` (blocked on Optic.Prism cascade resolution).

## What Worked and What Didn't

**Worked**:
- Pattern C's 3-hop relay (subordinate → user → advisor → user → subordinate) did not decay across the full cycle. User filtered my side-ask ("authorize me to apply the stamp directly") out of the relay correctly — that filtration is the load-bearing step that keeps advisor scope clean.
- Mid-cycle Decision revision was clean: empirical discovery → rule-#6 escalation → advisor draft → principal stamp → subordinate re-execution against revised spec. No cycle abort, no fresh supervise block, no re-dispatch cost.
- Subordinate's tactical-fix discipline held across four Glibc iteration rounds. Each round caught one class of real issue (public-import promotion, unsafe-keyword redundancy, FPE constants, then ILL/CLD constants) and resolved mechanically within β' scope. Zero drift into structural re-escalation.
- [SUPER-011] stamp as collaborative deliverable: subordinate produced the acceptance-criteria + ground-rules tables in the IP6 report, advisor drafted section skeleton matching the Cycle 1 precedent, principal relayed, subordinate applied mechanically. Division of labor preserved authorship (subordinate authored data; advisor authored shape; principal approved).

**Didn't work initially**:
- Doc 3 Q7 analyzed layout-soundness thoroughly but never asked the `@objc`-representability question. Layout-compatibility is necessary but not sufficient for `@convention(c)` typed-pointer retypes. IP5-first-failure consumed one iteration round to surface this.
- My first fix suggestion at IP5-first-failure (`@convention(c, cType:)`) was wrong. I assumed the cType annotation would relax semantic representability; it does not. Subordinate's re-inspection caught it. This is a pattern: when the compiler rejects something and the advisor suggests a Swift-language construct as fix, the advisor should verify the construct's semantics before authorizing, not after.
- Optic.Prism namespace cascade surprised both advisor and subordinate. Nothing in Doc 3 predicted it because nothing in Doc 3 required importing `Kernel_Memory_Primitives`. It only materialized when Option 1's `.fault: Kernel.Memory.Address?` brought the import into scope.

## Patterns and Root Causes

**Representability is orthogonal to layout-compatibility.** The Doc-3-class investigation pattern (layout-compatible L2 wrapper retypes) has a silent assumption baked into Q7: *"if layout matches, the retype is sound."* This is false at `@convention(c)` boundaries. Swift's function-pointer representability rules are a distinct semantic check — they require every parameter type to be `@objc`-representable, and a user-written pure-Swift struct is not (even layout-compatibly so). Future Doc-3-class investigations need an explicit Q8-style "representability at consumer boundary" check that names the specific boundary (C function pointer, `@objc` protocol, C variadic, etc.) and verifies the retype doesn't cross a representability wall. The investigation-playbook weakness is captured in the tracker sub-entry; the canonical fix is a skill-level rule.

**Mid-cycle Decision revision is a distinct termination mode worth codifying.** [SUPER-010] currently names three termination modes: Success, Re-handoff, Escalation. It does not name "in-cycle revision" — yet Cycle 2 demonstrated a fourth pattern: the principal revises a previously-stamped Decision *without ending the cycle*, provided (a) the revised shape is a weakening of scope (β' reverts; doesn't add), (b) the revision is class-(b)-stamped in-line via the existing rule-#6 escalation channel, and (c) the subordinate re-applies acceptance criteria against the revised spec. The "re-handoff" alternative would have been strictly more expensive: new supervise block, new dispatch, re-verification of pre-existing WIP state. Codifying this as a pattern (with the three conditions named) lets future cycles use it without needing to invent the mechanics again.

**Advisor-separation's load-bearing filter is the user.** Pattern C (advisor-to-user-to-subordinate) introduces a 3-hop relay that *could* decay if each hop applied its own transformations. It did not decay in Cycle 2 because the user filtered advisor side-scope from principal-scope correctly — specifically, my "authorize me to apply the edits directly" recommendation was pruned from the relay because it was an advisor-to-user sidebar, not principal-to-subordinate direction. This filtration is the trust mechanism that keeps Pattern C viable. If users couldn't filter, advisor scope would pollute subordinate scope and the pattern would collapse into Pattern A' under a different name. The filter's operation is implicit right now; Pattern C documentation should name it explicitly so future sessions don't rediscover the requirement by accident.

**Tagged/Optic namespace pollution is a cross-cutting ecosystem issue.** The Optic.Prism cascade observation is larger than Cycle 2. Tagged is used pervasively across the ecosystem (I count ~20+ direct Tagged-bearing primitives). Every one of them synthesizes `.caseName` accessors on Prism types whose names are derived from the case names. Whenever a consumer imports the primitive transitively and has an enum case whose name matches one of the synthesized accessor names, the two collide in pattern-match contexts. Configuration.swift:85 surfaced one instance; a systematic audit is warranted before the next L2 wrapper investigation imports a Tagged-bearing primitive.

## Action Items

- [ ] **[skill]** platform: Add a Q8-style representability pre-check to L2-wrapper-retype investigations. When a retype touches a `@convention(c)` boundary (or any `@objc`-representability-requiring context), verify the target type is `@objc`-representable *before* authorizing the retype. Layout-compatibility is necessary but not sufficient. Provenance: Doc 3 Q7 analysis was insufficient; Cycle 2 IP5-first-failure consumed one iteration round to discover.

- [ ] **[skill]** supervise: Codify "mid-cycle Principal Decision revision" as a fourth termination-avoiding pattern under [SUPER-010], distinct from Success / Re-handoff / Escalation. Three conditions: (1) revised shape weakens scope rather than adds, (2) revision is class-(b)-stamped in-line via rule-#6 channel, (3) subordinate re-applies acceptance criteria against revised spec. Provenance: 2026-04-22 Cycle 2 β' revision at IP5-second-failure avoided a cycle abort without degrading supervision integrity.

- [ ] **[research]** Optic.Prism namespace cascade — ecosystem-wide audit. Tagged-derived synthesized `.caseName` accessors on `Optic.Prism<Enum, Part>` types collide with enum-case pattern matches at consumer sites whenever the consumer imports a Tagged-bearing primitive transitively. Observed at `iso-9945 Configuration.swift:85` during Cycle 2. Need: inventory of Tagged users in the ecosystem; assessment of whether naming discipline, access-level change, or macro-output adjustment is the correct fix; criterion for when a consumer is at risk.
