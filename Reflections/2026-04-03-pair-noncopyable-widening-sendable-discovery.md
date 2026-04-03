---
date: 2026-04-03
session_objective: Widen Pair to ~Copyable and replace ad-hoc Descriptors types
packages:
  - swift-algebra-primitives
  - swift-iso-9945
status: pending
---

# Pair ~Copyable Widening — Sendable & ~Copyable Discovery

## What Happened

Resumed from a handoff to widen `Pair<First, Second>` to support `~Copyable` type parameters. Implemented the two-tier API: consuming statics for the ~Copyable tier, borrowing instance methods for the Copyable tier. Added `@frozen` for cross-module partial consumption. Guarded `Equatable`/`Hashable` with `#if compiler(>=6.4)` for `& ~Copyable` composition. Initially also guarded `Sendable` behind the same gate — this turned out to be wrong.

When replacing `Kernel.Socket.Pair.Descriptors` and `Kernel.Pipe.Descriptors` with `Pair`, the Sendable guard became a blocker: `Pair<Kernel.Descriptor, Kernel.Descriptor>` wasn't Sendable on 6.3 because the guarded fallback `where First: Sendable` added implicit Copyable.

Created an experiment (`sendable-noncopyable-conditional-conformance`) that refuted the hypothesis: `Sendable & ~Copyable` **compiles on 6.3**. The limitation is protocol-specific, not syntax-specific. `Equatable` requires Copyable (inherited), so `Equatable & ~Copyable` is a contradiction. `Sendable` opts out of Copyable (`protocol Sendable: ~Copyable`), so `Sendable & ~Copyable` is consistent. Moved Sendable out of the `#if` guard. Unblocked both replacements.

Also discovered: `var` computed properties returning `~Copyable` types from borrowed self fail — need `_read` coroutine accessors to yield borrowed references through `@frozen` nested storage.

Replaced `Kernel.Socket.Pair.Descriptors` with `Pair<Socket.Descriptor, Socket.Descriptor>` (drop-in, same field names). Replaced `Kernel.Pipe.Descriptors` with `Tagged<Kernel.Pipe, Pair<Descriptor, Descriptor>>` with `.read`/`.write` semantic accessors via `_read` — preserving call-site API while eliminating the ad-hoc struct.

## What Worked and What Didn't

**Worked**: The handoff captured enough context to resume efficiently. The two-tier API pattern (statics for ~Copyable, instance for Copyable) compiled on first try. The `Tagged<T, Pair<A, B>>` composition pattern worked cleanly — both types are `@frozen`, so the compiler sees through to the flat layout. The experiment validated a false assumption in under a minute.

**Didn't work**: Assumed `Sendable & ~Copyable` would fail on 6.3 based on the `Equatable & ~Copyable` dead end from the prior session. This assumption propagated through the handoff without being empirically tested. The handoff's dead end said "Equatable & ~Copyable doesn't compile on 6.3" — correct — but the generalization to "all Protocol & ~Copyable" was wrong.

Also: `consuming func swapped()` and `var swapped` coexist in overlapping extensions was a redeclaration error. The handoff planned both, but `~Copyable` is not the complement of `Copyable` — both extensions apply to Copyable types.

## Patterns and Root Causes

**The generalization trap**: A dead end for one protocol (`Equatable`) was silently generalized to all protocols. The root cause distinction — whether the *protocol itself* requires Copyable — was not captured. `Sendable: ~Copyable` opts out; `Equatable` does not. The handoff should have recorded WHY Equatable failed, not just THAT it failed. The "why" predicts which other protocols share the limitation.

**Experiment-first validation of assumptions**: The experiment took 2 minutes and saved what would have been a blocked replacement or an unnecessary `@unchecked Sendable` workaround. The existing research corpus had related findings (set-protocol-requirements, property-view-protocol-delegation) but none directly tested Sendable in conditional conformance where clauses. When research is inconclusive, a focused experiment is cheap and definitive.

**`_read` for ~Copyable computed properties**: Computed property getters returning `~Copyable` values from borrowed self fail because the getter tries to return (consume) the value. `_read` coroutines yield borrowed references without consumption. This is the standard pattern for ~Copyable stored-property forwarding through computed accessors on `@frozen` types.

## Action Items

- [ ] **[skill]** memory-safety: Add rule for `_read` coroutine requirement when computed properties return `~Copyable` from borrowed self on `@frozen` types
- [ ] **[skill]** memory-safety: Document which stdlib protocols opt out of Copyable (`Sendable`, `BitwiseCopyable`) vs which require it (`Equatable`, `Hashable`, `Codable`, `Error`) — determines `& ~Copyable` viability per protocol
- [ ] **[experiment]** Validate `Hashable & ~Copyable` fails on 6.3 the same way as Equatable (expected: same "composition cannot contain ~Copyable" error since Hashable refines Equatable)
