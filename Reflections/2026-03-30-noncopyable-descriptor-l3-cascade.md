---
date: 2026-03-30
session_objective: Complete Phase 3 of Kernel.Descriptor ~Copyable migration (L3 swift-foundations cascade)
packages:
  - swift-io
  - swift-posix
  - swift-kernel
  - swift-memory
  - swift-iso-9945
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Add [IMPL-077] verify constraints before workarounds
  - type: skill_update
    target: platform
    description: Add [PATTERN-009] typed-throws-safe catch patterns
  - type: no_action
    description: "Extend noncopyable-throwing-init experiment — deferred to next implementation session touching Memory.Map; experiment exists, extension is incremental work"
---

# ~Copyable Descriptor L3 Cascade: Workaround Resistance and Experiment-Driven Correction

## What Happened

Session objective was Phase 3 of the Kernel.Descriptor ~Copyable migration — cascading the L1 change through L3 swift-foundations, starting with IO Events. The handoff prescribed raw Int32 workarounds for the Registration.Request (Deque can't hold ~Copyable) and Selector.Registration (stdlib Dictionary can't hold ~Copyable).

Initial implementation followed the handoff's workaround design: raw Int32 for descriptors in Request and Registration, dup in processRequests. The user rejected this ("I am disappointed to see so many workarounds"). Investigation confirmed the ecosystem Deque supports ~Copyable elements natively — the handoff's claim was stale or never verified.

Corrected design: Kernel.Descriptor flows as proper ~Copyable everywhere. Request is a ~Copyable enum. Dup happens at the selector actor level (natural ownership boundary). Selector.Registration's descriptor field was removed entirely (never read after storage — dead data).

The cascade then expanded beyond IO Events into swift-posix (borrowing annotations), swift-kernel (File.Write subsystem: TempFile struct, Context ~Copyable, syncDirectory restructure), and swift-memory (Lock.Token class→struct, Map init phases). Each package revealed 2-6 files needing ~Copyable adaptation.

A critical moment: the Memory.Map init appeared to fail with "conditional initialization of noncopyable types." I was about to commit a factory method workaround. The user asked me to verify via experiment first. The experiment (6 variants) proved the pattern works — the factory was unnecessary. The plain init compiled when actually tried.

## What Worked and What Didn't

**Worked well:**
- User challenge on raw Int32 workarounds forced verification of Deque ~Copyable support — eliminated all workarounds
- Experiment-first debugging ([EXP-011]) prevented a wrong abstraction (factory method) from being committed
- `catch where error.isInterrupted` pattern — cleaner than the guard-throw alternative, preserves typed throws
- Phased init pattern (all stored properties set before optional lock) — clean and compiles

**Didn't work well:**
- Accepted handoff claims without verification. The "Deque can't hold ~Copyable" claim was wrong. The "Mutex.withLock can't capture ~Copyable" claim conflated @Sendable closures with sending closures.
- First instinct on compiler errors was to add workarounds (factory, raw Int32) rather than question assumptions. The experiment proved the workarounds were solving phantom problems.
- Cascade scope was severely underestimated. The handoff scoped Phase 3 to IO Events (swift-io). The actual cascade touched 5 packages and 24 files.

## Patterns and Root Causes

**Stale handoff claims propagate wrong designs.** The handoff was written during L1/L2 work, before the L3 code was actually modified. Claims about Deque and Mutex limitations were hypotheses, not verified facts. They became design axioms that shaped the Phase 3 plan. The user's challenge ("why can't you write the code as it should be") was the necessary corrective — it forced empirical verification of the constraints.

**Workaround-first instinct is the wrong default for infrastructure code.** Three times in this session, the first response to a compiler error was a workaround: raw Int32, factory method, Result side-channel. In two cases (raw Int32, factory), the workaround was unnecessary — the "limitation" didn't exist. The experiment process is the antidote: verify the constraint exists before working around it.

**~Copyable cascade scope is multiplicative, not additive.** Each L3 package that stores or passes Kernel.Descriptor needs the same treatment: borrowing annotations, tuple→struct, Result elimination, typed throws fixes. The cascade pattern repeats identically across packages. A sweep tool (grep for `Kernel.Descriptor` parameters missing ownership) would have revealed the full scope immediately.

**`catch let error where` vs `catch where` is a typed throws footgun.** The `let` binding erases the concrete type to `any Error`. The implicit `error` binding in `catch where` preserves it. This distinction isn't documented in any skill and caused errors across multiple files.

## Action Items

- [ ] **[skill]** implementation: Add rule: verify constraints via experiment before implementing workarounds. Stale handoff claims and compiler error messages are hypotheses, not facts. Reference this session's Deque and factory examples.
- [ ] **[skill]** platform: Document `catch where error.X` as the typed-throws-safe pattern (vs `catch let error where error.X` which erases to `any Error`). Add to typed throws pitfalls.
- [ ] **[experiment]** Extend `noncopyable-throwing-init` to reproduce the Memory.Map "conditional initialization" error by incrementally adding Map's actual stored property types per [EXP-004a].
