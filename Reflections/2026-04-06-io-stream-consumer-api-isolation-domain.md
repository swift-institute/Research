---
date: 2026-04-06
session_objective: Audit and build the consumer-first Tier 0 IO Stream API with strict isolation domain correctness
packages:
  - swift-io
status: pending
---

# IO Stream Consumer API: Progressive Disclosure, Sendable Reduction, and Cooperative Pool Discovery

## What Happened

Session started as a compliance audit of the IO Stream module, pivoted to a fundamental API redesign. The user's direction: "IO.Stream should not be a type on its own — it's just IO.read {} write {} via closures." This led to a progressive disclosure API (Levels 0–3) where IO.Stream becomes an internal implementation detail.

9 commits on the implementation track:
- Audit remediation (unsafe placement, typed do/catch, named errno constants)
- Consumer API: IO.read, IO.write, IO.open (static + context methods)
- Language-level consuming parameter forwarding (replacing Transfer.Cell for IO.run boundary)
- @Sendable removal from Level 1 closures (direct withReader/withWriter path)
- Sequential bidirectional IO.open (single-closure, inout IO.Stream)
- Sendable constraint reduction (Apple HTTP API pattern: consuming sending on inputs, nothing on returns)
- Channel.Reader/Writer affine deinit (no trap on drop — Apple pattern)
- Interest-per-direction (IO.read registers .read only, not [.read, .write])
- mapError preconditionFailure fix (invalidDescriptor/writeClosed are reachable)

Two experiments created:
- `async-let-noncopyable-transfer/` — REFUTED: async let always captures, Transfer.Cell unavoidable
- `executor-preference-noncopyable/` — REFUTED for capture elimination, CONFIRMED for executor pinning

Two branch handoffs written:
- `HANDOFF-io-executor-thread.md` — Threading Kernel.Thread.Executor through IO Events stack
- `HANDOFF-unsafe-pointer-audit.md` — Push unsafe to kernel syscall boundary via Span

## What Worked and What Didn't

**Worked**: The consuming parameter forwarding pattern on IO.Run — a genuine language-level improvement over Transfer.Cell for the non-concurrent path. The Apple HTTP API proposal was the right reference throughout: `consuming sending` on inputs, no Sendable on returns, no deinit trap on resources.

**Worked**: Interest-per-direction. Registering .read only for IO.read prevents spurious errors when the descriptor doesn't support write. Found by the edge case test — the test drove the design improvement.

**Didn't work**: Attempting to eliminate Transfer.Cell from async let. Two experiments confirmed this is a Swift 6.3 language limitation — all concurrency primitives use escaping closures, ~Copyable values can't cross. The correct mitigation is withTaskExecutorPreference (change WHERE, accept Transfer.Cell for HOW).

**Low confidence**: The per-call executor approach in callAsFunction was caught before implementation. The user correctly identified it should be bottom-up (executor lives in Topology, flows through Selector → Context → Stream), not top-down patched at callAsFunction.

## Patterns and Root Causes

**Pattern: "Sendable is not sending."** The session repeatedly found that `T: Sendable` constraints were redundant when `sending` was already present. The Apple HTTP API proposal validated this: `Return: ~Copyable` (widest possible) with `consuming sending` on inputs. The `sending` keyword handles value-level transfer; `Sendable` is type-level and usually unnecessary at API boundaries when `sending` is used.

**Pattern: "The cooperative pool is the wrong executor for I/O."** The poll thread already runs its own event loop. I/O tasks should run there, not on the shared cooperative pool. The existing Kernel.Thread.Executor (SerialExecutor + TaskExecutor) is the building block. The gap is threading it through IO Events → Selector → Context → Stream.

**Root cause of Transfer.Cell**: Swift 6.3's escaping closure model. Every concurrency primitive (async let, TaskGroup.addTask, withTaskExecutorPreference) creates an escaping closure. ~Copyable values can't cross escaping closure boundaries. This is a language limitation, not a library design issue. Transfer.Cell (ARC box + Sendable token) is the designed mechanism until Swift adds consuming async let.

## Action Items

- [ ] **[research]** Investigate whether Swift Evolution has a pitch for consuming async let or non-escaping task creation — this would eliminate Transfer.Cell entirely
- [ ] **[skill]** memory-safety: Add [MEM-SEND-005] documenting the "sending replaces Sendable on return types" pattern validated by Apple HTTP API proposal and this session
- [ ] **[package]** swift-io: The IO Executor module name collision with Kernel.Thread.Executor is confusing — IO.Executor is actor-based resource management, completely unrelated to task execution. Consider renaming to IO.Registry or IO.Handle.Pool
