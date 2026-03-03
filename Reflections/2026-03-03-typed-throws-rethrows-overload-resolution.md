---
date: 2026-03-03
session_objective: Convert all rethrows and existential throws usage across swift-primitives and swift-foundations to typed throws
packages:
  - swift-standard-library-extensions
  - swift-geometry-primitives
  - swift-kernel-primitives
  - swift-algebra-primitives
  - swift-async-primitives
  - swift-cache-primitives
  - swift-dictionary-primitives
  - swift-ownership-primitives
status: pending
---

# Typed Throws Conversion — rethrows Overload Resolution and E Inference

## What Happened

Session objective was to inventory and convert all `rethrows` to `<E: Swift.Error> throws(E)` and all existential `throws` to concrete typed throws across swift-primitives and swift-foundations.

**Phase 1: Inventory** — Found 36 production `rethrows` signatures and 20 untyped `throws` across both repos. 11 SwiftSyntax macro signatures were exempt (protocol constraint).

**Phase 2: Mechanical conversion** — Successfully converted 7 packages (algebra, geometry, ownership, kernel-terminal, cache, async-channel, dictionary). The `rethrows` → `throws(E)` conversion pattern is straightforward at the signature level.

**Phase 3: Build failures** — 3 packages failed because their `throws(E)` implementations internally call stdlib `rethrows` functions (`Array.map`, `withUnsafeBytes(of:)`, `withUnsafeMutableBytes(of:)`). The error: `thrown expression type 'any Error' cannot be converted to error type 'E'`.

**Phase 4: Wrong fix — `@_disfavoredOverload` overloads** — Added typed throws overloads for 10 Sequence methods to standard-library-extensions with `@_disfavoredOverload`. These couldn't be selected by the compiler: `@_disfavoredOverload` causes rethrows to win; removing it causes ambiguity. This was a dead end.

**Phase 5: Experiment** — Created `typed-throws-overload-resolution` experiment at `swift-standard-library-extensions/Experiments/`. Tested 10+ variants. Confirmed two independent Swift 6.2 limitations: (1) E inference from closure body doesn't work, (2) same-name throws(E) overloads can't beat rethrows.

**Phase 6: Compiler research** — Investigated `FullTypedThrows` experimental feature flag in Swift compiler source. Found it exists but is gated to non-production compilers. Tested with dev snapshot (6.3-dev) — it doesn't fix the issues we care about.

**Phase 7: Critical discovery** — Tested stdlib functions individually and found that Swift 6.2.4's stdlib `map`, `withUnsafeBytes(of:)`, `withUnsafeMutableBytes(of:)`, and `Mutex.withLock` **already support typed throws natively**. The only requirement is explicit `throws(E)` annotation on the closure. The earlier failures were caused by our own `@_disfavoredOverload` overloads interfering with the stdlib's working typed throws support.

**Phase 8: Successful builds** — Removed standard-library-extensions dependency from geometry and kernel. Added explicit `throws(E)` closure annotations. All previously-failing packages now build cleanly.

## What Worked and What Didn't

**What worked**:
- The experiment-first approach was invaluable. Each hypothesis was testable in isolation, and the systematic MARK-based variant testing caught the concrete-vs-generic E distinction.
- The minimal reduction methodology (EXP-004) quickly isolated the root cause.
- The stdlib audit approach — testing each function individually — revealed the non-obvious fact that some stdlib functions support typed throws while others don't.

**What didn't work**:
- The initial instinct to add `@_disfavoredOverload` overloads was wrong and actively harmful. The overloads made things worse by causing the rethrows version to be selected instead of the stdlib's native typed throws support.
- The `FullTypedThrows` investigation consumed time but produced negative results — the flag exists but doesn't solve the problems we needed solved.
- The original experiment's D1 variant was claimed "REFUTED" but was inside `#if false` and may never have been tested. Untested hypotheses marked as refuted are dangerous.

**Confidence**: High confidence in the final findings — every claim is backed by a successful build. Low confidence that the stdlib typed throws support situation won't change between Swift versions.

## Patterns and Root Causes

**Pattern: "Helpful" overloads can be anti-helpful**. The `@_disfavoredOverload` typed throws overloads on Sequence.map were strictly worse than having no overloads at all. When the stdlib already supports a feature (even partially), adding a disfavored overload for the same name causes the compiler to select the stdlib version (which may work!) while routing through the disfavored path that erases the type. The fix was removing the overload, not improving it.

This is a general pattern: before adding infrastructure, verify the problem exists without the infrastructure. The experiment should have started with NO overloads — just direct calls to stdlib.

**Pattern: stdlib typed throws support is incremental and undocumented**. Swift 6.2.4's stdlib has silently updated `map`, `withUnsafeBytes`, `withUnsafeMutableBytes`, and `Mutex.withLock` to support typed throws. But `filter`, `reduce`, `compactMap`, `flatMap`, `forEach`, `contains(where:)`, `allSatisfy`, `first(where:)`, `sorted(by:)`, `min(by:)`, `max(by:)`, `drop(while:)`, `prefix(while:)`, and `withContiguousStorageIfAvailable` have NOT been updated. This partial support is not documented anywhere — it was discovered only through systematic experimentation.

**Pattern: E inference vs E annotation are different problems**. The compiler cannot infer `throws(E)` from a closure body (`{ try f($0) }` infers `any Error`). But it CAN propagate `throws(E)` when explicitly annotated (`{ (x: T) throws(E) -> U in try f(x) }`). The annotation requirement is the consumer cost of typed throws. This is a language limitation tracked at https://github.com/swiftlang/swift/issues/68734.

## Action Items

- [ ] **[skill]** errors: Add guidance for explicit closure annotation requirement when calling stdlib rethrows functions from throws(E) contexts. Document which stdlib functions support typed throws on Swift 6.2.4 vs which don't.
- [ ] **[package]** swift-standard-library-extensions: The 10 `@_disfavoredOverload` typed throws overloads on Sequence are dead code — they cannot be selected by the compiler. The `map` overload actively interferes with stdlib's native typed throws support. Decision needed: remove `map` overload, keep others as documentation/future-proofing, or remove all.
- [ ] **[experiment]** Track which Swift version updates more stdlib functions to typed throws. Re-run the stdlib audit experiment after each toolchain update to maintain the compatibility matrix.
