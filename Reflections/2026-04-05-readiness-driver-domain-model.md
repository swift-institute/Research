---
date: 2026-04-05
session_objective: Port kqueue driver from swift-io to swift-kernel (Phase 3) and refine the readiness driver domain model
packages:
  - swift-kernel
  - swift-io
status: processed
---

# Readiness Driver Domain Model: From Handle + Closures to Recipe + Thing

## What Happened

Session started from HANDOFF.md at Phase 3: wire `IO.Event.Driver.kqueue()` to delegate to `Kernel.Readiness.Driver.kqueue()`. Initial implementation preserved the existing 8-closure witness pattern with Handle and error bridging. All 361 tests passed.

Critical review from the collaborating agent identified `create()` as mechanism, not intent — a [IMPL-000] violation. The 3-step ceremony (driver, handle, wakeup) was artificial: there's no valid state where you hold a driver without a handle. This triggered three architectural iterations:

1. **Make.Result bundle** — collapsed the 3-step ceremony into a single factory returning a ~Copyable bundle. Eliminated `create()` and `wakeup()` from the witness (8→6 closures). Worked but introduced a new type for what was semantically one concept.

2. **Single ~Copyable Driver** — merged Handle into Driver. One type owning fd + buffer + wakeup + closures. Methods borrow `self.descriptor` and pass to stored closures. Validated by experiment (`Experiments/noncopyable-driver-witness/`, 5 variants, all confirmed). Eliminated Handle and Make.Result entirely.

3. **Recipe + Thing split** — Driver becomes a pure Copyable Sendable witness (the recipe: 6 closures + drain + capabilities). `Kernel.Readiness` becomes a ~Copyable struct (the thing: owns fd, buffer, wakeup, holds a Driver). `close()` splits into `driver._drain(descriptor)` (driver-specific registry cleanup) + `buffer.deallocate()` (resource-level) + descriptor deinit (ownership-level).

Final state: `Kernel.Readiness.kqueue()` returns `Kernel.Readiness` directly. `IO.Event.Driver` wraps `let _kernel: Kernel.Readiness` with error bridging. Queue.Operations (550 lines) and Handle type deleted. 361 tests pass.

## What Worked and What Didn't

**Worked**: The experiment-first approach. [IMPL-077] says "verify constraints before workarounds." The assumed limitation — "closures can't borrow from self" — was about capture, not parameter passing. The 5-variant experiment proved the single-type pattern works in under 2 minutes, saving hours of workaround design. Every subsequent iteration was grounded in verified compiler behavior.

**Worked**: The collaborative review cadence. Each commit was reviewed, issues were caught before they compounded. The `create()` being mechanism was caught at commit 1, not after 5 commits of building on it.

**Didn't work**: My first instinct was to preserve the existing abstraction boundaries (Handle separate from Driver, Make.Result as handoff). This added two types for one concept. The user and collaborating agent had to push through three rounds before arriving at the correct domain model. I should have started from [IMPL-INTENT] — "what is the ideal expression?" — instead of from "how do I minimally modify the existing code?"

**Didn't work**: `do throws(E) { } catch { }` without explicit closure signatures. The catch block silently erased to `any Error`. Cost two build cycles before understanding that [API-ERR-004] applies to closure bodies, not just closure types.

## Patterns and Root Causes

**The "mechanism-first" trap**: Starting from existing code structure biases toward preserving its abstractions. The Handle/Driver split existed because of a *believed* compiler limitation, not because the domain required it. When the limitation turned out to be false, the abstraction had no reason to exist — but inertia kept it alive through two iterations. The antidote is [IMPL-000]: write the ideal expression first, then check if the compiler supports it.

**Recipe vs Thing is a general pattern**: Separating "what operations exist" (Copyable, shareable, comparable) from "what resource is being operated on" (~Copyable, single-owner, consuming close) may apply to other driver/resource pairs in the ecosystem. The Completion driver (io_uring/IOCP) should follow the same factoring.

**Name collision at namespace boundaries**: Inside `extension Kernel { }`, bare `Memory` resolves to `Kernel.Memory` (from kernel-primitives), not the top-level `Memory` from `Memory_Buffer_Primitives`. Required fully-qualified `Memory_Buffer_Primitives.Memory.Buffer.Mutable`. This is inherent to the namespace extension pattern [PLAT-ARCH-003] — every `Kernel.*` namespace creates a potential shadow for any type that shares a name with a `Kernel` child.

## Action Items

- [ ] **[skill]** implementation: Add guidance that [IMPL-000] applies to type design, not just expressions — "write the ideal type first, then check if the compiler supports it." The session's central mistake was designing around a believed limitation instead of testing it.
- [ ] **[skill]** platform: Document the `Memory` name collision pattern — inside `extension Kernel { }`, types from other modules that share names with `Kernel.*` children require module-qualified paths. This affects any file that extends the `Kernel` namespace and uses `Memory`, `Error`, or other common type names.
- [ ] **[experiment]** Verify that the Recipe + Thing pattern (Copyable witness + ~Copyable resource) works for `Kernel.Completion.Driver` (io_uring). The pattern should transfer but io_uring's submission queue ownership model may require a different closure signature shape.
