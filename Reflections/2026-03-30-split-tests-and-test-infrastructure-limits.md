---
date: 2026-03-30
session_objective: Write targeted tests for Channel split() API and rename ReadResult/WriteResult per naming conventions
packages:
  - swift-io
  - swift-algebra-primitives
status: pending
---

# Split Tests, @Test Macro Symbol Limits, and ~Copyable Task Transfer Gaps

## What Happened

Continued from the split() implementation session. Three areas of work:

1. **ReadResult/WriteResult rename**: Renamed to `Read.Result`/`Write.Result` following the ecosystem `Operation.Result` pattern (`Register.Result`, `Kernel.IO.Completion.Port.Read.Result`). Case `.read(Int)` renamed to `.bytes(Int)` to avoid `Read.Result.read` tautology. 4 new files (Read/Write namespace enums + Result types), 4 use sites updated.

2. **Targeted split() tests**: Wrote 9 tests covering alive mask coordination, reverse close order, shutdown, half-close preservation, deinit fallback, cancellation, and selector shutdown. 5 pass, 4 disabled.

3. **Discovered two infrastructure limitations**:
   - `@Test` macro generates symbol names from the full type nesting path. Deeply nested suites (`IO.Event.Channel.Test.FullDuplex`) hit the `@section` attribute's compile-time constant limit when too many tests exist in one file. Fix: separate test file with shorter nesting.
   - `Task.detached` cancellation does not propagate through `Ownership.Transfer.Cell.take()`. A detached task that takes a ~Copyable value via Transfer.Cell, then suspends in an async operation, does not receive cancellation when `task.cancel()` is called. The cancellation tests hang indefinitely.

Also identified `Pair<First, Second>` in swift-algebra-primitives as the ecosystem's answer to ~Copyable tuples. Making `Pair` support `~Copyable` parameters would generalize the `Split` struct pattern and benefit the entire ecosystem. The main work is reworking the functor API (`map`, `bimap`, `swapped`) for consuming/borrowing overloads per [IMPL-025].

## What Worked and What Didn't

**Worked well**:
- The ecosystem `Operation.Result` pattern had strong precedent (5 examples across Kernel, IO, Test). The rename was mechanical.
- Separating tests into `IO.Event.Channel.Split.Tests.swift` solved the `@section` symbol limit cleanly. The shorter nesting path (`Test.Split` vs `Test.FullDuplex` inside the same file) kept symbols under the limit.
- The 5 passing tests (close order, shutdown, half-close preservation) validated the alive mask and lifecycle logic quickly.

**Didn't work**:
- The cancellation test pattern (`Transfer.Cell` → `Task.detached` → `cancel()`) silently hangs. No error, no timeout propagation. The `withTaskCancellationHandler` in `Async.Channel.Unbounded.Receiver.receive()` should fire, but the cancellation signal never arrives at the suspended task. This was unexpected — the same pattern works for the existing Channel tests that use `Task.detached` for the echo driver, but those tasks are never cancelled.
- Multiple zombie `swift-test` processes accumulated from repeated test runs hitting the hanging tests. Required `pkill -9` cleanup between runs.

## Patterns and Root Causes

**Pattern: `@Test` macro symbol length is a function of nesting depth × test count.**
The `@section` attribute requires compile-time constant global variables. The Swift testing framework generates one such variable per test, with a mangled name that includes the entire type nesting path. For `IO.Event.Channel.Test.FullDuplex.methodName`, the mangled symbol is ~180 characters. With 20+ tests in one file at this nesting depth, the aggregate exceeds some compiler threshold. The principled fix at the codebase level is: one test file per suite. The principled fix at the compiler level would be symbol hashing for `@section`-attributed globals.

**Pattern: Task cancellation requires cooperative propagation, and Transfer.Cell breaks the chain.**
Swift's structured concurrency propagates cancellation from parent to child. `Task.detached` creates an unstructured task — cancellation must be delivered via `task.cancel()` which sets the task's cancellation flag. The suspended `Async.Channel.Unbounded.Receiver.receive()` checks cancellation via `withTaskCancellationHandler`, which should fire when the flag is set. The question is whether `Transfer.Cell.take()` (which blocks until the cell is populated, then returns the value) introduces a synchronization barrier that prevents the cancellation handler from registering before the cell is populated. If `take()` suspends in a way that bypasses cooperative cancellation, the handler never fires.

This is a real gap in ~Copyable concurrency ergonomics: you can't capture ~Copyable values in @Sendable closures, so you use Transfer.Cell. But Transfer.Cell may break cancellation propagation. The root cause needs investigation at the Transfer.Cell implementation level.

**Ecosystem opportunity: Pair<First: ~Copyable, Second: ~Copyable>.**
The `Split` struct is an ad-hoc `Pair<Reader, Writer>`. Making `Pair` support `~Copyable` would eliminate the need for per-use-site bundle structs. The blocker is the functor API — `map`, `bimap`, `swapped` need consuming/borrowing overloads. `Product` (variadic) is blocked on `~Copyable` pack expansion support in the compiler.

## Action Items

- [ ] **[research]** Investigate why Task.detached cancellation does not propagate through Ownership.Transfer.Cell.take() — is it a Transfer.Cell issue, a Receiver.receive() issue, or a fundamental limitation of the ~Copyable task transfer pattern?
- [ ] **[package]** swift-algebra-primitives: Make Pair support ~Copyable parameters with Copyable conditional conformance and consuming/borrowing functor overloads per [IMPL-025]
- [ ] **[experiment]** Test whether the @Test macro symbol length limit scales with nesting depth, test count, or both — determine the threshold to document in testing skill
