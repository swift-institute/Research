---
date: 2026-03-20
session_objective: Execute Pass 4 compound type renames across swift-primitives, starting at Tier 20 and working upward
packages:
  - swift-pool-primitives
  - swift-cache-primitives
  - swift-parser-primitives
  - swift-effect-primitives
status: processed
processed_date: 2026-03-22
triage_outcomes:
  - type: experiment_topic
    description: "generic-nested-typealias: add variant testing _Value capture for Effect.Protocol.Value"
  - type: skill_update
    target: platform
    description: "Add [PLAT-ARCH-011] Swift.Error qualification in .Error namespaces"
  - type: skill_update
    target: code-surface
    description: "Add [API-IMPL-009] hoisted-protocol-with-nested-typealias pattern"
---

# Pass 4: Compound Type Renames — Generic Nesting Discoveries

## What Happened

Session executed the Pass 4 compound type rename plan from the implementation naming audit. Work progressed through two tiers:

**Tier 20 (pool, cache)** — completed:
- **Pool**: 9 compound types renamed. `TryAcquire` → `Acquire.Try`, `CallbackAcquire` → `Acquire.Callback`, `TimeoutAcquire` → `Acquire.Timeout` (public structs moved from `extension Pool.Bounded` to `extension Pool.Bounded.Acquire`). `AcquireAction` → `Acquire.Action`, `TryAcquireAction` → `Acquire.Try.Action`, `CallbackAcquireAction` → `Acquire.Callback.Action` (internal action enums moved into their operation namespaces). `ReleaseAction` → `Release.Action` (new `Release` namespace enum created). `CommitAction` → `Fill.Commit`, `DrainAction` → `Shutdown.Drain`. All 62 tests pass.
- **Cache**: Attempted to nest `__CacheEvict` and `__CacheCompute` inside `Cache<Key, Value>`. Both failed: `Effect.Protocol` requires `associatedtype Value` which can't be satisfied from the outer generic parameter across a nesting boundary. The user then found a workaround using a `_Value` typealias on `Cache` to capture the outer generic before shadowing, enabling both types to be properly nested. `__CacheEvict` → `Cache.Evict`, `__CacheCompute` → `Cache.Compute<E>`. All 11 tests pass.

**Tier 17 (parser)** — in progress:
- Analyzed 6 proposed renames. `ParserPrinter` → `Bidirectional` is clear. `LocatedError` rename surfaced a deep question: can a protocol typealias named `` `Protocol` `` be nested inside a generic struct and accessed without specifying the generic parameter?
- Created experiment `generic-nested-typealias` to empirically test this.

**Experiment finding**: `Parser.Error.Located.Protocol` (typealias to hoisted protocol, nested inside generic `Located<E>`) IS accessible without specifying `E`. Three requirements discovered:
1. The struct must use `Swift.Error` (fully qualified), not bare `Error`, when nested inside a namespace also named `Error` — bare `Error` creates a circular reference during type resolution.
2. The conformance declaration in the declaring module must use the hoisted name directly, not the typealias path — self-referential conformance (`Located: Located.Protocol`) creates a cycle.
3. Consumers CAN use the typealias path for conformance, constraints, and existentials — all three patterns confirmed.

## What Worked and What Didn't

**Worked well**:
- The Tier 20 pool renames were mechanical and clean. The `Slot.Index` resolution failure on first build (bare `Slot.Index` not accessible from `extension Pool.Bounded.Acquire`) was caught immediately and fixed with full qualification. The two-phase approach (rename → build → fix → test → commit) was effective.
- The experiment process for the generic nesting question was high-value. Three iterations narrowed the circular reference from "Protocol keyword issue" to "bare Error resolution ambiguity" — each experiment eliminated one hypothesis.

**Didn't work well**:
- I was too confident that `Protocol` on generic types was impossible and nearly committed to `Locating` as the name without testing. The user pushed back correctly — the assumption was wrong.
- The cache nesting attempt wasted time before the user found the `_Value` workaround. I tested 8 mental approaches but didn't think of the simplest one (capturing the outer generic via a typealias on the parent type before the shadow takes effect).

## Patterns and Root Causes

**Pattern: "Can't nest X inside generic Y" is often wrong.** Both cache effect types and the parser `Located.Protocol` were initially assessed as impossible to nest. In both cases, a workaround existed. The root cause is that Swift's generic type system has more flexibility than its error messages suggest — circular references and "cannot find type" errors often have resolution-order fixes rather than being fundamental limitations.

**Pattern: Bare `Error` in `Error`-named namespaces.** When a type is nested inside a namespace called `Error` (like `Parser.Error.Located`), bare `Error` in conformance/inheritance clauses resolves to the namespace, not `Swift.Error`. This creates cycles. The fix is always `Swift.Error` qualification. This likely affects other types in the ecosystem nested inside `.Error` namespaces.

**Pattern: Self-referential conformance creates cycles.** `extension T: T.Alias` forces the compiler to resolve `T.Alias` while computing `T`'s conformances, which requires resolving `T`, creating a cycle. The fix is using the underlying protocol name for the declaring module's conformance while exposing the typealias for consumers.

## Action Items

- [ ] **[experiment]** generic-nested-typealias: Add variant testing whether the `_Value` capture pattern (used in Cache) also enables `Effect.Protocol.Value` resolution for nested types — this could eliminate hoisting entirely for future effect types
- [ ] **[skill]** platform: Add guidance that types nested inside `.Error` namespaces MUST use `Swift.Error` (not bare `Error`) in conformance/inheritance to avoid circular references
- [ ] **[skill]** code-surface: Document the hoisted-protocol-with-nested-typealias pattern as the canonical way to achieve `Outer.Inner.Protocol` on generic types — conformance uses hoisted name, consumers use typealias
