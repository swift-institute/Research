---
date: 2026-05-02
session_objective: Close multiple post-Path-X envelopes (Item 5 CPU L2 deps cleanup; Item 1.5 Memory.Lock.Token closure-capture redesign; Tier 5-Windows-Mirror Thread.{Handle,Error} structural-anchor tail; Wave 3.5-Corrective-2 Lock Helper SPI tail)
packages:
  - swift-cpu
  - swift-kernel
  - swift-memory-primitives
  - swift-memory
  - swift-iso-9945
  - swift-windows-32
  - swift-darwin
  - swift-linux
  - swift-foundations/swift-windows
status: pending
---

# Multi-envelope execution: research-doc layering blindspot + empirical classification corrections

## What Happened

Long session executing four distinct envelopes back-to-back. Each closed cleanly but two surfaced novel architectural lessons via mid-flight blockers; the other two were mechanical follow-ups whose only interesting finding was scope drift (1 file → 2 files).

**Item 5 — CPU L2 deps cleanup at swift-kernel** (4 phases, ~6 commits across 5 repos):
- Phase 1: created `swift-cpu` L3-policy package at `swift-foundations/swift-cpu/` (7 files: Package.swift + Sources/CPU/{exports.swift, CPU.swift} + Tests/CPU Tests/CPU.Sanity Tests.swift + LICENSE.md + README.md + .gitignore). Initial sanity test referenced `CPU.Atomic.Flag` (based on swift-kernel's `Tagged+CPU.Atomic.Flag.swift` extension file name); type doesn't exist at L1, substituted `CPU.Atomic.Load.Ordering`.
- Phase 2+3 bundled per principal disposition: swift-kernel `Package.swift` drops 3 deps (cpu-primitives + x86-standard + arm-standard) + adds `swift-cpu`; `Kernel Core/exports.swift` replaces `CPU_Primitives` import + arch-conditional X86/ARM with single `CPU` import. Originally planned as 2 split commits; principal correctly caught my Option (B) analysis was wrong (Phase-3-first leaves `import CPU` failing because Package.swift hadn't added the dep yet — symmetric RED state to Phase-2-first). Bundled to preserve GREEN.
- Phase 4: cascade verification swift-executors ✅ (89.98s) + swift-io ❌ initially. swift-io test-support consumed `Kernel.Thread.ID` post-flip and surfaced a Wave 3.5-Final-Atomic miss.
- Mid-flight Class B Completion: initial Class A attempt at swift-posix (`POSIX.Kernel.Thread.ID.swift` typealias to `ISO_9945.Kernel.Thread.ID`) **correctly failed to compile** — the underlying type is declared at L2 platform-specific modules (`Darwin_Kernel_Standard` + `Linux_Kernel_System_Standard`), not iso-9945 Core. swift-posix L3-policy has no visibility into platform-specific L2 per [PLAT-ARCH-008e]. Bridge typealiases placed at swift-darwin + swift-linux L3 instead — mirror of Wave 3.5-Final-Atomic IO.Uring + Kqueue precedent.

**Item 1.5 — Memory.Lock.Token Path δ closure-capture redesign** (6 phases, 6 commits across 5 repos including audit + research + experiments):
- Phase 1 verification: typed iso-9945 prerequisites (`Descriptor.Duplicate.duplicate(_ borrowing Descriptor)` + `Lock.{lock, unlock}(_ borrowing Descriptor, range:[, kind:])`) all pre-existed. NO-OP.
- Phase 2 BLOCKER: research doc's Option B shape (explicit `_descriptor: Kernel.Descriptor?` + `_range: Kernel.Lock.Range` fields at L1 swift-memory-primitives) is **structurally invalid at L1**. L1's Package.swift deps are exclusively other L1 primitives packages — no L2/L3 deps allowed. The research-then-dispatch deliverable did type-system analysis but did NOT verify Package.swift import constraints.
- Surfaced 5 candidate paths to principal (α/β/γ/δ/ε); principal directed Phase A empirical experiment for Path δ + Phase B scoping for Path β.
- Phase A experiment at `swift-institute/Experiments/memory-lock-token-noncopyable-closure-capture/` — CONFIRMED `var Optional<~Copyable>` capture in non-`@Sendable () -> Void` closure compiles + runs correctly with `.take()` semantics + RAII chain + idempotent double-release. Trade-off: Token loses `Sendable` conformance.
- Phase A clean confirmation collapsed disposition tree → Phase B (Path β consumer cascade scoping) skipped.
- Phase 2/3/4/5/6 executed: L1 Token redesign + L3 Acquire rewrite (typed `Kernel.Descriptor` capture via `var ownedFd + .take()`) + cascade verification + raw-form downgrade at iso-9945 (Lock.lock/unlock + Descriptor.Duplicate.duplicate from `@_spi(Syscall) public` → `package` per SE-0386) + audit doc + research doc addendum.

**Post-Tier-5-Windows-Mirror Thread.{Handle,Error} tail** (3 commits across 2 repos):
- Pre-existing structural-anchor gap from Wave 3.5 era. Phase 0 inventory surfaced 6 Thread.Handle reference sites + 2 Thread.Error sites (only `create()` throws). Mechanical declarations following existing precedents (RawRepresentable<UInt> Copyable struct for Handle; single-case enum for Error). No design ambiguity.

**Wave 3.5-Corrective-2 tail (Lock Helper SPI inaccessibility)** (2 commits across 2 repos):
- Pre-existing breakage flagged in Item 1.5 close-report. File.Open.open became `@_spi(Syscall) public` at Wave 3.5-Corrective-2; test fixtures missing matching `@_spi(Syscall) import ISO_9945_Kernel_File`. Phase 1 classification (i) — mechanical 1-line fix.
- Scope drift: after fixing Lock Helper, Kernel.IO.Test.Helpers.swift surfaced as a SECOND affected file. The build had stopped at the first error; second file was masked. Per ground rule #9 broader-scope discovery — applied same fix to both.

## What Worked and What Didn't

**Worked**:
- Mid-flight surfacing per ground rules. When Phase 2 of Item 1.5 hit the L1 layering structural conflict, halting + comprehensively framing 5 paths (α/β/γ/δ/ε) with empirical-vs-design distinction let the principal disposition cleanly. The principal's "report Phase A result before starting Phase B so I can dispose if a clean Path δ confirmation collapses the disposition tree" was a sharper directive than I would have written — it captured exactly the right "if X then skip Y" condition that compressed a 2-phase verification into Phase A only.
- Empirical experiments unblocking design questions. The Path δ experiment file (3 test cases, debug + release, ~150 LOC) took ~2 minutes to write + verify; it definitively answered the "does ~Copyable + non-@Sendable closure capture work?" question that would otherwise have required hours of design speculation.
- Class B classification correction at Item 5. Trying Class A at swift-posix and watching it fail to compile with "ID is not a member type of ISO_9945.Kernel.Thread" was the cheapest possible verification of "this type lives somewhere swift-posix can't reach"; the failure surfaced the right architectural placement (swift-darwin/swift-linux L3 bridge) without requiring me to pre-derive it.
- `package` access level (SE-0386) recognition during Item 1.5 Phase 5. Initial downgrade attempt to `internal` correctly broke iso-9945's same-package tests; recognizing that the test consumers needed cross-target visibility within the same Package.swift led to `package` as the correct access level.

**Didn't work as well**:
- Research doc oversight at Item 1.5 Phase 2. The "Option B" shape was drafted without checking L1's Package.swift import constraints — the research did type-system analysis (~Copyable + Sendable + closure-capture mechanics) but missed the layering constraint (which type identifiers are visible at which package). Principal explicitly framed the rescue as "research-doc oversight" + dispatch-stage verification + Phase A experiment. The fact that I had to STOP at Phase 2 and surface 5 options is itself the failure signal — the research doc should have surfaced this before dispatch.
- Initial Phase 4 cascade plan at Item 5 was incomplete. I built swift-executors + swift-io + intended to continue with a sample of others, but the swift-io failure cascaded into a sub-cycle (Class B Thread.ID) that took up most of Phase 4. The "if a downstream consumer surfaces a gap, the cascade IS the verification" pattern wasn't pre-anticipated — Phase 4 was framed as "build verification only" but became "build verification AND fill any gaps surfaced by build verification". Reasonable in hindsight; not pre-planned.
- Initial sanity test at Item 5 Phase 1 used `CPU.Atomic.Flag` (which doesn't exist at L1). I assumed the type existed because swift-kernel's `Tagged+CPU.Atomic.Flag.swift` extension file referenced it. The extension was probably dead code or referenced a Flag type at L2 that wasn't surfaced. Trivial in-flight fix (substituted `CPU.Atomic.Load.Ordering`), but it shows: filename-as-type-existence inference is unreliable when the file is an extension.

## Patterns and Root Causes

**Pattern 1 — Research-then-dispatch deliverables MUST verify Package.swift import constraints alongside type-system shape analysis.** This is the deepest lesson of the session. The Item 1.5 research doc did rigorous type-system analysis (`~Copyable` × `@Sendable` interaction, `var Optional + .take()` semantics, `consuming` ownership transfer) but missed that L1 swift-memory-primitives **cannot import** `Kernel.Descriptor` because L1's deps are exclusively L1 primitives. The shape of the proposed redesign was structurally invalid at the layer it was proposed for. The research-doc reviewer (me, then principal) treated the type-system analysis as exhaustive when in fact the layering check was a separate axis that wasn't covered.

The general form: research-then-dispatch protocols need at least three orthogonal verification axes for any L1 redesign:
1. Type-system shape (covered well)
2. Package.swift import constraints (the gap)
3. Consumer-cascade impact (covered well)

Adding (2) to research-then-dispatch quality gates closes the gap without changing the protocol's fundamental shape. The Phase A experiment was the cheapest possible recovery — the research-doc oversight was caught at Phase 2 (cheap), not Phase 5 or post-merge (expensive).

**Pattern 2 — Class A vs Class B classification is empirical, not nominal.** The Wave 3.5-Final-Atomic taxonomy distinguished Class A (cross-platform pure-error/value-type namespaces missing POSIX bridges) from Class B (platform-specific bridges). My initial classification of Thread.ID as Class A was nominal — "it's a cross-platform namespace, sub-type at L2 platform extension, looks like Class A pattern." The empirical reality (declaration site = platform-specific L2 modules) made it Class B. The compile error was the cheap empirical check that surfaced the true classification.

The lesson: when classifying via taxonomy, the architectural CLASSIFIER should be the type's declaration site (where it's declared), not the type's USAGE site (where it's referenced). Cross-platform usage of a type doesn't make the type cross-platform; the declaration site does. Future flip-style cycles can apply this discipline at pre-flight: for each candidate Class A bridge, run the empirical "where is this type ACTUALLY declared?" check before classifying.

**Pattern 3 — Iterative-error-surface phenomenon for fix cascades.** When fixing compile errors, the build typically stops at the first error per file (or per emit-module phase). Subsequent errors only surface after the first fix unblocks the build. The Wave 3.5-Corrective-2 tail's Lock Helper fix unblocked Kernel.IO.Test.Helpers.swift to surface the SAME root cause. Per ground rule #9 broader-scope discovery — but more generally, the fix protocol should iterate: fix → rebuild → check next error → repeat until green. A single "check-all-errors-at-once" grep at the start would have been wrong (the post-fix build state has different errors than the pre-fix build state).

**Pattern 4 — `package` access level (SE-0386) is the right downgrade target when in-package test consumers exist.** Item 1.5 Phase 5 raw-form downgrade initially used `internal` (per the principal's plan); the iso-9945 test target failed to compile because Tests are a separate target from the source target. SE-0386 `package` access provides cross-target visibility within the same Package.swift while denying cross-package consumption — exactly the semantic needed. Codifying this as a default for raw-form downgrades when same-package tests consume the raw form would prevent the empirical retry.

**Pattern 5 — Sendable absorption.** When a parent type is `@unchecked Sendable` for distinct safety reasons (Memory.Map carries raw mapping bytes that have data races the caller must synchronize), child types held inside it can drop `Sendable` without changing observable safety — the parent's existing escape hatch absorbs the invariant. Path δ's Token-loses-Sendable-but-Memory.Map-stays-Sendable arrangement is a clean example. May generalize to other witness-closure types or ~Copyable wrappers in the ecosystem.

## Action Items

- [ ] **[skill]** research-process: Add a research-then-dispatch quality gate requiring L1 redesign deliverables to verify Package.swift import constraints alongside type-system shape analysis. Item 1.5 Phase 2 was the canonical failure mode — the research doc was structurally invalid at L1 because its proposed field types couldn't be imported there. Three-axis verification (type-system + Package.swift deps + consumer cascade) closes the gap.

- [ ] **[skill]** platform: Codify "Class A vs Class B classification is empirical (declaration site), not nominal (usage site or naming intuition)" as guidance attached to [PLAT-ARCH-008e]. Future flip-style cycles applying the Wave 3.5-Final-Atomic taxonomy should run the "where is this type ACTUALLY declared?" check at pre-flight rather than classifying by intuition. Same lesson surfaced via Item 5 Thread.ID empirical correction (Class A attempt at swift-posix failed; Class B at platform L3 succeeded).

- [ ] **[research]** Sendable absorption pattern generalization: when a parent type is `@unchecked Sendable` for distinct safety reasons, child types held inside it can drop `Sendable` without observable safety change. Investigate the ecosystem for other instances (witness-closure types, ~Copyable wrappers held inside @unchecked Sendable parents). Item 1.5 Path δ may be the first deliberate application; mapping the broader applicability would let other holders of the same shape adopt it.
