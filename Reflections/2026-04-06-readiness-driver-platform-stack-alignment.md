---
date: 2026-04-06
session_objective: Move readiness driver implementation from swift-io to swift-kernel (platform stack alignment refactor Phases 0-3)
packages:
  - swift-io
  - swift-kernel
  - swift-memory-primitives
status: pending
---

# Readiness Driver Platform Stack Alignment — ~Copyable Witness Design Discovery

## What Happened

Multi-session refactor (2026-04-04 through 2026-04-06) moving event notification policy from swift-io to swift-kernel. Started from a converged Claude+ChatGPT architecture plan.

Phase 0: Architecture spec with 7 policy invariants (INV-1 through INV-7), "inert driver" definition. Phase 1: 24 behavioral tests encoding the invariants as black-box contract. Phase 2: `Kernel.Readiness.Driver` type + kqueue implementation in swift-kernel. Phase 3: IO.Event.Driver wraps Kernel.Readiness.

The critical discovery came during review: the initial design used 3 types for 1 concept (Driver + Handle + Make.Result). An experiment (`Experiments/noncopyable-driver-witness/`) proved that a ~Copyable struct CAN own a resource AND hold closures that receive it via borrowing parameter — the method bridges the gap. This collapsed the design to: `Kernel.Readiness` (~Copyable resource owner) + `Kernel.Readiness.Driver` (Copyable witness recipe). Also extracted `Memory Buffer Primitives` target from the umbrella per [MOD-005] — an unrelated fix needed to unblock the dependency.

## What Worked and What Didn't

**Worked well**: Behavioral tests as migration gate — 24 tests caught nothing because the port was faithful, but they provided confidence throughout. The experiment-first debugging approach ([IMPL-077]) was the session's highest-value moment: a 5-minute experiment disproved a constraint that had shaped 3 types and 2 refactoring rounds.

**Didn't work**: Initial assumption that closures can't interact with ~Copyable stored properties led to the Handle/Make.Result split. This assumption was treated as fact through two iterations before being challenged. The first review session caught the `Memory.Buffer.Mutable` access-level issue (actually `InternalImportsByDefault`, not the type's access level) — but the diagnosis was wrong, leading to the UnsafeMutableRawBufferPointer downgrade, which was later corrected.

**Low confidence**: The `IO.Event.Driver` wrapping layer adds error bridging overhead on every operation. Whether this should eventually become a typealias (eliminating the bridge) vs remain a separate type (for the IO-specific Capabilities.model field) is unresolved.

## Patterns and Root Causes

**Pattern: Assumed limitation → multi-type workaround → experiment disproves → collapse.** The Handle type existed because "closures can't borrow from self." True for CAPTURE, false for PARAMETER PASSING. The distinction is subtle: a closure can't close over a ~Copyable value, but a method can borrow self's ~Copyable field and pass it as a borrowing parameter to a stored closure. Three types collapsed to one concept once this was verified.

This is the same class of error as the `UnsafeMutableRawBufferPointer` choice: an access-level error was misdiagnosed as "Memory.Buffer.Mutable is internal" when the actual cause was `InternalImportsByDefault` in swift-kernel. The fix was `public import`, not type substitution. Both cases: wrong diagnosis of root cause → workaround that was itself wrong → review caught it.

**Pattern: Name collision in nested extensions.** Inside `extension Kernel { }`, bare `Memory` resolves to `Kernel.Memory`, not the top-level `Memory` from `Memory_Buffer_Primitives`. Required fully-qualified module path. This is a general risk when extending namespace enums that have sub-namespaces matching external type names.

## Action Items

- [ ] **[skill]** implementation: Add rule about verifying ~Copyable closure interaction capabilities via experiment before designing multi-type workarounds. The distinction between closure CAPTURE (cannot capture ~Copyable) and parameter PASSING (method can borrow self.field and pass to closure) is non-obvious and led to two unnecessary refactoring rounds.
- [ ] **[experiment]** Verify whether `IO.Event.Driver` can become `typealias IO.Event.Driver = Kernel.Readiness` on Darwin, eliminating the error-bridging wrapper entirely. The `Capabilities.model` field is the main blocker — assess whether it's used downstream.
- [ ] **[skill]** modularization: Document the `InternalImportsByDefault` interaction with cross-package type visibility — `public import` is required for types used in package-visible API, and this is easy to misdiagnose as the type itself being internal.
