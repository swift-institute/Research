---
date: 2026-04-03
session_objective: Investigate and resolve Mutex.withLock sending composition issues with Property.View coroutines and rebound pointer captures
packages:
  - swift-io
  - swift-property-primitives
  - swift-queue-primitives
status: pending
---

# Sending-Mutex Composition — Nesting Flip Eliminates Hot-Path Allocation

## What Happened

Investigated why `Mutex.withLock`'s `(inout sending State)` parameter doesn't compose with Property.View coroutine accessors (Site 1) or rebound pointer captures (Site 2) in swift-io's kqueue poll path.

Site 1 (Deque mutation via `.back.push()`) was already resolved — uses `deque.push(element, to: .back)` directly, bypassing the coroutine accessor.

Site 2 (rebound pointer capture) was the remaining issue. The original code nested `withLock` inside `withRebound`, requiring a `rawCopy: [Kernel.Kqueue.Event]` Array allocation per poll cycle to avoid capturing the rebound closure parameter across the `sending` boundary. Verified the workaround is still required on Swift 6.3 — exact error: `'inout sending' parameter 'outer' cannot be task-isolated at end of function`.

Fix: flipped the nesting — `withRebound` inside `withLock` instead of around it. The scratch buffer memory retains polled data between `withRebound` calls, so the poll and conversion are split into two sequential rebounds. No cross-scope capture, no heap allocation.

Also corrected the research document's `_read` vs `_modify` analysis and added Swift 6.3 reproduction findings.

## What Worked and What Didn't

**Worked**: The nesting flip was the right decomposition. Once identified, it was a clean edit that compiled on the first try (after fixing the typed throws boundary). The underlying insight — buffer memory persists between `withRebound` calls — was the key.

**Didn't work**: The minimal reproduction compiled on Swift 6.3 even though the actual code still fails. The reproduction used a simplified `ViewTyped` type and lacked the nested `outer.withValue(forKey:_:)` call chain that triggers the real region conflict. This means [IMPL-077] (verify constraints before workarounds) must include a "verify against actual codebase" step — simplified reproductions can be false negatives.

**Confidence assessment**: High confidence in the fix — it's a structural change (nesting order) verified by the compiler. The buffer memory persistence between `withRebound` calls is guaranteed by the memory model (same physical allocation, no zeroing on scope exit).

## Patterns and Root Causes

**Pattern: Scoped resource composition via nesting inversion.** When two scoped resources (closures with `@noescape` parameters) can't nest in one direction due to region isolation, inverting the nesting may eliminate the capture that causes the conflict. This works when: (a) the underlying resource persists between scope activations, and (b) the inner scope doesn't need to outlive the outer scope.

The general form:
```
// Problematic: inner captures from outer
outer { a in inner { b in /* uses a and b */ } }  // a captured → taints b's sending region

// Fixed: flip nesting, access enclosing scope directly
inner { b in outer { a in /* uses a and b */ } }   // a is enclosing scope, not capture
```

This only works when `a`'s underlying state persists across the outer scope boundary. In this case, the poll buffer's memory is owned by the Handle, not by the `withRebound` scope.

**Root cause of the original workaround**: The code was structured as "rebound the buffer, then do everything inside" — a natural top-down decomposition. But `sending` region isolation penalizes nesting depth. The fix decomposes into sequential steps (poll, then lock+convert) rather than nested scopes. This aligns with [IMPL-023] (static/decomposed architecture over nested closures).

## Action Items

- [ ] **[skill]** implementation: Add guidance under [IMPL-066] or new ID for scoped resource composition with `sending` — when two `@noescape` closure scopes conflict with `sending`, consider nesting inversion
- [ ] **[skill]** implementation: Strengthen [IMPL-077] — simplified reproductions can be false negatives; always verify against actual codebase before concluding a constraint is resolved
- [ ] **[package]** swift-io: Audit finding #2 (triple-handling in kqueue poll) is partially addressed by this fix but the `events` Array inside the lock remains — could write directly into the caller's buffer
