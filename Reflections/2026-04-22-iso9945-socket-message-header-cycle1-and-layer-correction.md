---
date: 2026-04-22
session_objective: Execute Doc 2 Cycle 1 implementation (P2.4 #8 Socket.Message.Header typed pointer-field wrappers) per HANDOFF-layer-perfection-implementation.md
packages:
  - swift-iso-9945
  - swift-institute
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# ISO 9945 Cycle 1 — Socket.Message.Header typed pointer-field partial close + user-caught layering correction

## What Happened

This session was Cycle 1 of the layer-perfection implementation handoff (`swift-institute/Audits/HANDOFF-layer-perfection-implementation.md`), dispatched to close P2.4 #8 — `Socket.Message.Header.{Name, Vectors, Control}` typed pointer-field wrappers in swift-iso-9945 — per Doc 2's Refined Option 1' principal-ratified shape.

Structure was three-layer supervise-governed throughout (user → supervisor → subordinate):

- Pre-flight verification of working trees, WIP branch SHAs (`descriptor-migration-wip` at `2ad7bd1` / `820d267` / `6c14505` / `b593538` across 4 repos), and Docker `swift:6.3.1` image presence. All green.
- Skills loaded per handoff: `/platform`, `/implementation`, `/code-surface`, `/modularization`, `/supervise`.
- 4 pre-edit structural ambiguities escalated and resolved (A — `Vectors.count` retention; B — convenience-init shapes on Name/Vectors/Control; C — `@unsafe` init declaration-level placement vs expression-level; D — `.flags` accessor confirmation). Supervisor acknowledged each with principal decisions.
- IP1 implementation: Package.swift (Socket target → `ISO 9945 Kernel File` dep) + Vectors.swift (retype `pointer` to `UnsafeMutablePointer<Kernel.IO.Vector.Segment>?`, add `@unsafe public init`, `public import ISO_9945_Kernel_File`) + Header.swift (`.vectors` accessor retyped via raw-pointer bridging, `public import ISO_9945_Kernel_File`).
- 2 mid-IP1 rule-#6 escalations: (i) `Kernel.IO.Vector.Segment` not visible from Socket target → Package.swift scope expansion (cross-target dep + `public import` visibility upgrade); (ii) IP1 sequencing constraint — Vectors.swift retype and Header.swift `.vectors` accessor body are coupled; landing them in separate commits leaves an intermediate broken build. Supervisor authorized expanded IP1 scope.
- Docker Linux `--build-tests` on IP1 candidate surfaced a **cascade of 3 pre-existing Linux test-target drift failures**:
  1. `import CLinuxShim` in `ISO 9945.Kernel.File.Open.Options Tests.swift:31` — vestigial reference to a module renamed to `CISO9945Shim` by modularization commit `5eb1481`.
  2. `Kernel.File.Open.Options.direct` references (lines 86, 187, 230) — the symbol lives in `Linux_Kernel_File_Standard`, not visible from iso-9945.
  3. `ISO 9945.Kernel.Copy.Clone Tests.swift:59` — typealias parameters of type `Kernel.Descriptor` missing ownership annotations (Swift 6.3 noncopyable-parameter rules tightened).
- Attempted Path A for drift: add `swift-linux-standard` as a package dep to iso-9945 + conditional test-target product + `public import Linux_Kernel_File_Standard` in the test file. Supervisor authorized this path.
- **User intervened with architectural correction**: swift-iso-9945 (L2 POSIX) CANNOT depend on swift-linux-standard (L2 Linux); per [PLAT-ARCH-007] the dependency direction is `linux-standard → iso-9945`, so adding the reverse creates a cycle. Saved `feedback_iso9945_no_platform_standard_dep.md` to memory capturing the rule + related swift-posix invariant.
- Path B (revised): delete the 3 `.direct` test sites from iso-9945 (they belong in swift-linux-standard's own test suite) + keep the CLinuxShim deletion + keep the `borrowing` annotations for Copy.Clone. Grep confirmed zero `.direct` / `O_DIRECT` coverage in `swift-linux-foundation/swift-linux-standard/Tests/` — coverage-gap follow-up ticket recorded.
- 5 commits landed across 2 repos:
  - `swift-iso/swift-iso-9945`: `69e942c` (drift cleanup atomic), `819af1c` (IP1 Vectors typing), `abbdde7` (IP2 Control collapse + Name/Control `@unsafe` init + Header `.control` accessor).
  - `swift-institute/Audits`: `3f7de0f` (tracker P2.4 #8 PARTIAL CLOSE + "Linux test-target ecosystem drift cleanup (2026-04-22)" sub-section).
- 10/10 acceptance criteria verified end-to-end. All 6 ground-rules-block entries verified per [SUPER-011]. Cycle 1 terminated in Success per [SUPER-010]. Cycles 2 (Doc 3 — P2.3 #3) and 3 (Doc 1 — P2.2 #1/#11) remain deferred per the handoff's no-bundling rule.

**HANDOFF scan** (per [REFL-009]): 16 handoff files found across scope (4 at `/Users/coen/Developer/swift-institute/`, 3 at `/Users/coen/Developer/swift-institute/Audits/`, 12 at `/Users/coen/Developer/`). Only one in this session's bounded cleanup authority: `HANDOFF-layer-perfection-implementation.md`. Cycles 2 and 3 remain open; annotated with Cycle 1 Success closure + supervisor-constraints verification line per [SUPER-011]; file retained (not deleted). The other 15 are out-of-session-scope — not triaged.

**Audit finding cleanup** (per [REFL-010]): P2.4 #8 status updated to PARTIAL CLOSE in `platform-compliance-2026-04-21.md` as part of commit `3f7de0f`. No other findings touched this session; no additional status updates needed.

## What Worked and What Didn't

### Worked

- **Pre-flight verification discipline**: WIP branch SHAs checked against handoff-stated values before any source edit; prevented unknowing drift into deferred P0.1 descriptor-migration work.
- **Supervise escalation discipline**: 6 rule-#6 escalations raised and resolved cleanly (4 pre-edit + 2 mid-IP1). Every escalation was structurally legitimate, not drift-avoidance. Supervisor affirmed each with minor refinements.
- **Cache-resume pattern documentation**: Docker Linux parallel-build race characterized across 3 occurrences, documented in commit bodies and the tracker note so future cycles don't re-investigate the same quirk.
- **Memory record creation mid-flight**: After the user caught the cyclic-dep mistake, writing `feedback_iso9945_no_platform_standard_dep.md` before resuming the fix should prevent recurrence in future cycles (including cycles where the subordinate runs in absentia).
- **Tracker entry format mirroring**: The P2.4 #8 PARTIAL CLOSE entry was built exactly to match the P3.3 #10 precedent (Half / Fix / Commit / Verification table + explicit deferred halves + scope map). Auditability preserved.
- **Atomic drift-cleanup commit**: bundling A+B+C (CLinuxShim deletion + `.direct` deletion + `borrowing` annotations) into one commit rather than three preserves commit-graph legibility — none of A, B, or C individually flips Linux `--build-tests` green, only the set does.

### Didn't work — memory-consultation gap on layering

- **Biggest miss**: I proposed adding a cross-package dep from swift-iso-9945 → swift-linux-standard to make Linux-specific tests compile. [PLAT-ARCH-007] was in the platform skill I had loaded; the layering direction rule (Linux/Darwin depend on iso-9945, not the reverse) was stated. But I didn't consult it at the decision point. Pattern-matched "add the missing dep" instead of "check the dep direction first."
- **Two-layer oversight failure**: the supervisor ALSO authorized this expansion without catching it. Only the user (above-supervisor) saw the cycle and forced the correction. This is a feedback-memory gap at the supervise layer too — supervisor held the same knowledge and made the same miss.

### Didn't work — Linux test-target drift discovery cascade

- Three pre-existing drift failures surfaced sequentially on Docker Linux `--build-tests`. First run surfaced CLinuxShim; deleting it unblocked the next error (`.direct`); then Copy.Clone noncopyable. Each error required its own fix characterization before the next was visible.
- Previous implementation cycles in this ecosystem must have either skipped Docker Linux verification or skipped `--build-tests` (only `--target`), since these errors had been latent since modularization commit `5eb1481`. Implies CI or per-cycle Linux test-suite verification is missing at the ecosystem level.

### Didn't work — parallel-build race noise

- Docker Linux cold-start `--build-tests` fires transient `missing required module X` errors (observed as `Property_Primitives_Core`, `Witness_Primitives`, `Kernel_Primitives_Core` depending on schedule) that resolve on cache-resume. I misdiagnosed the first occurrence as a real failure and investigated for several minutes. By the second occurrence I recognized the pattern; by the third I was using the two-invocation pattern mechanically. Three total occurrences this cycle — enough to name the pattern and document it.

## Patterns and Root Causes

### Memory-consultation gap: the rule was loaded, neither layer checked it

The most structurally important failure was the almost-committed cyclic dep. I had `[PLAT-ARCH-007]` in the platform skill (loaded). The supervisor had it too (same skill context). Neither of us consulted it at the decision point. The user caught it.

Per REFL-006's "post-commit memory scan" guidance (added 2026-04-20 from a similar-shape failure), a pre-decision scan of `feedback_*` memory entries would have surfaced the layer rule. I didn't run that scan.

**The pattern**: memory-consultation is still not automatic. Skills are loaded, rules stated in their content, but the subordinate (and the supervisor) don't systematically check them before taking actions those rules should govern. This is the dominant class of defect across reflections — rules exist, implementations miss them, reviewers catch them. A mechanical-scan-before-acting habit would eliminate this, but it requires triggering automatically, not as an afterthought.

**Why it didn't trigger here**: the decision wasn't framed as "should I add a cross-package dep?" in a way that invoked the layer-direction rule. It was framed as "how do I make the test visible to the Segment symbol?" — a mechanical / logistics framing. The layer rule applies to the category of "any cross-L2-package dep"; the subordinate's decision frame was one level below the category boundary. Fix: memory-scan-before-cross-package-dep should be an explicit pre-flight check, not a post-hoc review.

This is the second independent occurrence of this pattern in this ecosystem (first: 2026-04-20 `feedback_no_unsafe_api_surface` consultation gap). Strong signal that the memory-consultation habit needs to be systematized at the skill level, not left as informal practice.

### Handoff-authorized scope still widens on discovery

The handoff pre-authorized "the 4 Socket Message Header source files + tracker". In practice, Cycle 1 touched 4 commits across 2 repos with 7 files:
- 4 Socket Message Header files (as planned).
- Package.swift in swift-iso-9945 (supervisor-authorized mid-cycle under rule #1's "implementation includes necessary cross-target deps").
- 2 test files in iso-9945 (supervisor-authorized under Option 3-extended-with-caps for pre-existing drift cleanup).
- Tracker file in swift-institute/Audits (expected Cycle 1 close-out).

Every scope expansion was escalated and authorized — escalation discipline worked. But it did happen: 3 of 7 files were scope expansions beyond the literal 4-file handoff scope. This is not drift (each expansion was authorized), but it signals that the investigation phase under-characterized the implementation consequences.

**Pattern**: when implementation requires cross-target or cross-file mechanical fixes (dep additions, import lines, ownership-annotation updates), the handoff investigation phase should pre-enumerate these rather than discover them mid-implementation. Doc 2 could have pre-characterized the `Kernel.IO.Vector.Segment` visibility gap (the Socket target's dep graph is auditable from Package.swift without any source-edit). Doc 2 could also have pre-characterized the Linux test-target drift (a `swift build --build-tests` on Docker at investigation time would have surfaced the same cascade).

### Verification discipline catches pre-existing drift — and exposes ecosystem CI gap

Ground rule #2 (Docker Linux `--build-tests` clean) caught 3 pre-existing drift failures that had been latent for weeks. If previous cycles had this discipline, they would have caught them earlier. The discipline is load-bearing; the cost (~3-5 minutes of Docker build + cache-resume per cycle) is worth it for the signal.

**The deeper pattern**: the ecosystem doesn't have per-commit Linux CI verification. The only way drift gets caught is when a cycle's ground rules mandate Linux `--build-tests` at verification time. This puts the verification burden on individual cycles instead of on automated CI. An ecosystem-health action is to add a CI pipeline that runs `swift build --build-tests` on Linux for every commit to every repo.

## Action Items

- [ ] **[skill]** platform: add a pre-flight memory-consultation checklist under [PLAT-ARCH-007] that fires BEFORE proposing any new cross-L2-package dep (code or test). Specifically: when a fix candidate involves `.package(path: ...)` addition, grep `~/.claude/projects/-Users-coen-Developer/memory/feedback_*.md` for layering-direction entries matching the two packages' layer positions. Cross-reference `feedback_iso9945_no_platform_standard_dep.md`. This is the skill-level systematization of the pattern the user corrected this cycle.

- [ ] **[research]** Docker Linux cold-build parallel-build race — catalog occurrences (≥3 this cycle, plus prior scattered sightings), characterize the SwiftPM + Swift 6.3.1 ordering pattern, search for an upstream bug report, test whether `-j 1` or pre-warming kernel-primitives builds eliminates the race. Affects verification discipline across all cycles that include Linux `--build-tests`.

- [ ] **[research]** Cross-package test-target residue systematic audit — the `.direct`/O_DIRECT residue in iso-9945 was one instance of a class: tests for platform-standard extensions living in a layer-incompatible package. Are there similar sites for other Linux-specific flags (`.async`, `.path`, `.tmpfile`, etc.) or Darwin-specific extensions that would fail the same iso-9945 → linux-standard cyclic-dep test? A grep over all test files for `#if os(...)`-guarded references to symbols that don't resolve in the POSIX namespace would systematize the search.
