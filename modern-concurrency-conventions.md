# Modern Concurrency Conventions

<!--
---
version: 1.0.0
last_updated: 2026-03-30
status: RECOMMENDATION
tier: 2
workflow: Discovery [RES-012]
trigger: Ecosystem-wide concurrency strategy consolidation — synthesize PF isolation series (#356-#360), existing ecosystem research, and swift-io case study into a single normative reference
scope: All packages across swift-primitives, swift-standards, swift-foundations
---
-->

## Context

The Swift Institute ecosystem has accumulated significant concurrency research across 15+ documents, 9+ experiments, and 3 external reference sources (Point-Free videos #356, #357, #360). Each addresses a specific facet — `nonisolated(nonsending)` migration, `@unchecked Sendable` auditing, `~Sendable` semantic analysis, `sending` annotation expansion — but no single document establishes the **overarching concurrency philosophy** that should guide all new code and refactoring decisions.

Simultaneously, the Swift community is converging on a paradigm shift: **isolation-first concurrency**. Point-Free's "Beyond Basics" and "Isolation" series (Feb-Mar 2026) demonstrates that modern Swift concurrency — when used correctly — eliminates the need for most `Sendable` annotations, most locks, and most `@unchecked Sendable` escape hatches. Their TCA2 and SQLiteData libraries prove this at production scale.

This document centralizes these findings into an actionable concurrency convention for the Swift Institute ecosystem, with swift-io as the primary case study.

## Question

What is the correct concurrency model for the Swift Institute ecosystem, and how should each concurrency mechanism be ranked, applied, and audited?

---

## The Isolation Hierarchy

Modern Swift concurrency provides a hierarchy of mechanisms, ordered from most desirable to least. Each higher-ranked mechanism provides stronger compile-time guarantees with less ceremony.

### Rank 1: Isolation Domains (Actors + `nonisolated(nonsending)`)

**Principle**: Data lives inside an isolation domain. Access is serialized by the actor's executor. The compiler statically proves freedom from data races. No locks, no `Sendable` requirements on internal state, no ceremony.

**Key insight from PF #357**: "Isolation is a compile-time guarantee that when a particular line of code is executed it will be free from data races or data corruption. The most amazing part of this is that we don't have to take any special considerations into account when writing these lines of code."

**Key insight from PF #360**: "Actors allow us to go one step further where we just get complete, unfettered access to mutable state with no locks whatsoever, but the catch is that we must first prove to the Swift compiler that we are in the right isolation domain."

**When to use**:
- Any type that manages mutable state accessed from multiple concurrency domains
- Coordination types (channels, pools, schedulers) where serialized access is the primary contract
- Types currently using `@unchecked Sendable` + internal `Mutex` for thread safety

**How isolation inheritance works**: Under `NonisolatedNonsendingByDefault` (SE-0461, enabled across all 252 ecosystem packages), free functions and methods are implicitly `nonisolated(nonsending)` — they inherit the caller's isolation context. Values passed through these functions never cross isolation boundaries, so they never need to be `Sendable`.

**Ecosystem status**: The `nonisolated(nonsending)` default is universally enabled. The double-nonsending pattern (function + closure parameter) is used in stdlib's `withTaskCancellationHandler` and should be adopted for all operation-taking APIs (e.g., `withDependencies`, `withWitnesses`). See `nonsending-ecosystem-migration-audit.md` for the 14 migration candidates.

### Rank 2: Ownership Transfer (`~Copyable` + `Sendable`)

**Principle**: A `~Copyable` type has exactly one owner. The compiler enforces exclusive access at compile time. Adding `Sendable` enables moving the value to another thread — but `~Copyable` prevents sharing. This gives "transferable but not sharable" semantics without any runtime synchronization.

**Key insight from PF #356**: The SQLiteData `Reader` and `Writer` types are `~Copyable, ~Escapable` — ownership proves the database connection is used correctly, and non-escapability prevents the pointer from outliving its scope. "Thanks to Swift's ownership tools we have compile time proof that the user can never escape this value outside of contexts that we don't want them to."

**When to use**:
- File descriptors, driver handles, I/O tokens — resources with exactly-once lifecycle
- Values transferred from one thread to another exactly once (e.g., job payloads)
- Any type where the compile-time ownership proof is stronger than runtime locking

**Ecosystem status**: Aggressively adopted. The `~Sendable` semantic inventory (`tilde-sendable-semantic-inventory.md`) found that `~Copyable` already handles the majority of cases where `~Sendable` would otherwise be needed. 14 types across swift-kernel/swift-io/swift-file-system use the `~Copyable, Sendable` pattern correctly.

### Rank 3: Region-Based Transfer (`sending`)

**Principle**: The `sending` keyword transfers a value from one isolation region to another. The compiler verifies the caller does not retain access after the transfer. This works for both `Sendable` and non-`Sendable` values.

**Key insight from PF #360**: Mutex's `init(_ initialValue: consuming sending Value)` uses `sending` to transfer the value into the mutex's isolation region. Its `withLock` uses `sending` three times — the value is sent into the closure, the result is sent out, and the return is sent out of `withLock`. "This `sending` annotation is what tells Swift to transfer the value from one region to a new region."

**When to use**:
- Parameters that cross actor boundaries (actor method parameters)
- Values entering or exiting a `Mutex.withLock` closure
- Channel send operations (producer transfers to consumer)
- Any boundary crossing where the caller relinquishes ownership

**Ecosystem status**: Applied at ~24 sites, with 10 additional findings identified by `sending-expansion-audit.md`. High-priority gaps: channel `send` methods, `Async.Promise.fulfill`, `Async.Broadcast.send`. All channel/broadcast/promise transfer operations should annotate with `sending`.

### Rank 4: Synchronous Locking (`Mutex`)

**Principle**: `Mutex<Value>` protects state via mutual exclusion. The protected value is accessed only through `withLock`. Modern `Mutex` uses `sending` and `~Copyable` support internally — it is significantly more capable than `OSAllocatedUnfairLock`.

**Key insight from PF #360**: Mutex is the most modern locking primitive in Swift, but it has a **critical soundness bug**: non-sendable values can be escaped from `withLock` via `{ $0 }` return, then accessed from multiple threads — compiles but causes data races. "This is a really awful bug in Swift that is allowing us to compile this code. And for this reason we unfortunately need to be very careful with mutexes."

**When to use**:
- Synchronous-only access patterns where actor overhead is unacceptable (hot paths)
- Types that must be `Sendable` for API reasons (e.g., conforming to `SerialExecutor`)
- Bridging sync → async boundaries (e.g., `Async.Bridge`, sync test infrastructure)

**Cautions**:
1. **Mutex soundness bug**: Non-sendable state returned from `withLock` can be escaped. Be careful with what you return.
2. **Non-reentrant**: Calling a method from within `withLock` that also acquires the same lock will deadlock. This silently constrains refactoring.
3. **Ceremony**: Every mutable field must be inside the mutex's state struct. Adding state requires deciding "inner struct or outer class" for every field.
4. **Lock contention scales with complexity**: 10,000 accounts = 10,001 lock acquisitions for `totalDeposits`. Actors avoid this through isolation.

**Ecosystem status**: Used extensively in swift-tests (test reporter sinks), swift-witnesses (Recording, Cycle, Sequence), and swift-io (Blocking.Threads.Runtime). Many of these are candidates for refactoring to actors or isolation-based designs.

### Rank 5: `@unchecked Sendable`

**Principle**: The programmer asserts thread safety. The compiler trusts the assertion without verification. This is a last resort when no higher-ranked mechanism can express the safety invariant.

**When to use**:
- Thread-safe-by-construction types with internal synchronization that the compiler cannot verify (Rank 4 types wrapped in a class)
- `~Copyable` ownership transfer types that also need `Sendable` for API conformance (e.g., `SerialExecutor`)
- Rare: types whose Sendable safety depends on documented usage protocols that the type system cannot encode

**When NOT to use**:
- Thread-confined types that happen to need one boundary crossing (use `~Sendable` when stable, or `nonisolated(unsafe)` at the transfer site)
- Types where an actor or Mutex would work (use the higher-ranked mechanism instead)
- Types where the only reason is "the compiler is complaining" (address the root cause)

**Ecosystem status**: 16 instances across swift-kernel/swift-io/swift-file-system (originally 29; 3 migrated to plain `Sendable`, 2 thread-confined types made non-Sendable, others corrected in 2026-03-31 audit). The `~Sendable` inventory identified 2 remaining thread-confined types (now non-Sendable, awaiting SE-0518 for `~Sendable`).

### Anti-Pattern: Viral Sendability

**Principle (PF #360)**: "Sendability should be applied rarely and surgically, and there is actually a lot of power in keeping things non-sendable. It allows you to interact with those objects in a completely synchronous manner with no locking whatsoever, and Swift can have your back to make sure you never accidentally leak that object across threads."

**The viral problem**: Making type A `Sendable` requires all its stored properties to be `Sendable`. This forces type B (stored in A) to also be `Sendable`, which requires adding locks to B, which forces an inner `State` struct, which forces `withLock` on every method, which prevents calling helpers from within `withLock` (deadlock risk), which multiplies lock acquisitions across the object graph.

**The solution**: Keep types non-`Sendable` by default. Use isolation inheritance (`nonisolated(nonsending)`) to pass them through function chains without crossing boundaries. Only mark a type `Sendable` when it genuinely needs to cross an isolation boundary — and prefer `~Copyable` + `Sendable` (ownership transfer) over `@unchecked Sendable` (trust-me assertion).

---

## Ecosystem Assessment

### What We Do Well

| Practice | Evidence | Status |
|----------|----------|--------|
| `NonisolatedNonsendingByDefault` enabled | 252/252 packages | Universal |
| `~Copyable` for resource ownership | 14 types across IO/kernel/file-system | Mature |
| `@concurrent` limited to genuine executor crossings | 13 files, all in IO layer | Correct |
| Isolation-preserving async operators | `Async.Callback.operation` is `nonisolated(nonsending)` | Implemented |
| SE-0421 `next(isolation:)` conformances | 7/7 types | Complete |
| `@Sendable` on actor-stored closures | 38+ sites | Correct |

### Migration Surface

| Migration | Count | Priority | Source |
|-----------|-------|----------|--------|
| Deprecated `isolation:` parameter → `nonisolated(nonsending)` | 14 functions | High | `nonsending-ecosystem-migration-audit.md` |
| Missing `sending` on channel/promise/broadcast operations | 10 sites | High | `sending-expansion-audit.md` |
| Thread-confined `@unchecked Sendable` → `~Sendable` | 3 types | Medium (blocked on SE-0518 stability) | `tilde-sendable-semantic-inventory.md` |
| Mutex-based `@unchecked Sendable` classes → actors | TBD | Medium | This document (case study below) |
| `@Sendable` closures in non-crossing contexts → plain closures | TBD | Low | `non-sendable-strategy-isolation-design.md` |

---

## Case Study: swift-io

swift-io is the ecosystem's most concurrency-intensive package. It manages blocking thread pools, completion ports, event drivers, and I/O channels — all crossing thread and isolation boundaries. It is the ideal testbed for evaluating the isolation hierarchy.

### Current `@unchecked Sendable` Inventory

**Verified: 2026-03-30** (against current codebase)

#### Category A: Thread-Safe by Construction (Correct)

These types have internal synchronization mechanisms. `@unchecked Sendable` is semantically accurate.

| Type | File | Mechanism |
|------|------|-----------|
| `IO.Blocking.Threads.Runtime` | `IO.Blocking.Threads.Runtime.swift:22` | Internal mutex via `Synchronization<1>` |
| `IO.Completion.Waiter` | (various) | Atomic state + continuation |
| `IO.Event.Buffer.Pool` | (various) | Internal synchronization |
| `IO.Blocking.Lane.Sharded.Selector` | (various) | Atomic counter + immutable array |
| `IO.Blocking.Lane.Sharded.Snapshot.Storage` | (various) | All atomic fields |

**Assessment**: These are the correct use of `@unchecked Sendable`. They cannot be actors because they require synchronous, lock-free access on the poll thread. Rank 4 (Mutex/atomics) is appropriate here.

**Refactoring opportunity**: `IO.Blocking.Threads.Runtime` uses `Synchronization<1>` (mutex + condition variable) to protect a `State` struct. This is a classic Mutex pattern. Consider whether an actor could replace it — the runtime is initialized once and then coordinates thread lifecycle. If all access can tolerate async, an actor would remove the `@unchecked Sendable` annotation. However, the runtime is accessed from blocking threads that may not have an async context, so the Mutex is likely necessary. **Verdict: Keep as-is.**

#### Category B: Ownership Transfer (Correct)

These types are `~Copyable, Sendable` — single-owner transfer across threads.

| Type | File | Transfer Pattern |
|------|------|-----------------|
| `IO.Event.Driver.Handle` | (various) | Transferred to poll thread |
| `IO.Completion.Driver.Handle` | (various) | Transferred to poll thread |
| `IO.Event.Channel` | (various) | Wraps `@Sendable` closures |
| `IO.Completion.Channel` | `IO.Completion.Channel.swift:40` | `~Copyable, Sendable` — prevents duplicate channels on same descriptor |

**Assessment**: Rank 2 (ownership transfer) is the correct mechanism. `~Copyable` enforces single ownership; `Sendable` enables the one-time thread transfer.

#### Category C: Thread-Confined (Should Be `~Sendable`)

These types are used exclusively on a single thread but marked `@unchecked Sendable` to cross one initialization boundary.

| Type | File | Current | Should Be |
|------|------|---------|-----------|
| `IO.Completion.IOUring.Ring` | (various) | Non-Sendable (fixed 2026-03-31) | `~Sendable` (SE-0518) |
| `IO.Completion.IOCP.State` | (various) | Non-Sendable (fixed 2026-03-31) | `~Sendable` (SE-0518) |

**Assessment**: These types had `@unchecked Sendable` removed (2026-03-31 audit). They are not thread-safe — all access happens on the poll thread. The `@unchecked Sendable` was unnecessary because both types are transferred via `Unmanaged` raw pointers, not typed Sendable crossings. Build confirmed no downstream breakage. When SE-0518 stabilizes, apply `~Sendable` to make thread confinement type-level truth.

**Blocked on**: SE-0518 stability. Tracked in `tilde-sendable-semantic-inventory.md`.

#### Category D: The Key Design Principle

From `swift-io/Research/audit.md:546`:

> "`sending` annotation is designed for transferring non-Sendable values across isolation boundaries. In swift-io, all cross-boundary values are either Sendable (events, errors, pointers) or ~Copyable (buffers, resources, jobs). ~Copyable types don't need `sending` because they can only have one owner — the compiler already enforces exclusive access."

This is the ecosystem's most important concurrency design principle: **use `~Copyable` to eliminate the need for `sending`/`Sendable` entirely**. When a type can only have one owner, the compiler enforces exclusive access without any concurrency annotations.

### swift-foundations: Other `@unchecked Sendable` Patterns

**Verified: 2026-03-30** (against current codebase)

#### Test Infrastructure (Mutex-Protected Sinks)

| Type | File | Mechanism |
|------|------|-----------|
| `Test.Reporter.Terminal` | `Test.Reporter.Terminal.swift:36` | `Mutex` for counts |
| `Test.Reporter.Structured` | `Test.Reporter.Structured.swift:32` | `Mutex` for records |
| `Test.Reporter.JSON` | `Test.Reporter.JSON.swift:41` | `Mutex` for events |
| `Test.Snapshot.Inline.State` | `Test.Snapshot.Inline.State.swift:29` | `Mutex` for dictionary |
| `Test.Snapshot.Counter` | `Test.Snapshot.Counter.swift:26` | `Mutex` for counts |

**Assessment**: These are test infrastructure — performance is not critical. Each is a `final class: @unchecked Sendable` with a Mutex-protected inner collection. They follow the exact pattern PF #360 warned about: "every single method wrapped in a big ole `withLock`." Consider refactoring to actors if async access is acceptable in the test runner context. However, test reporters are called synchronously from the test harness, so Mutex may be necessary. **Verdict: Review on a case-by-case basis; reporters that are called from async contexts should become actors.**

#### Witness Infrastructure

| Type | File | Mechanism |
|------|------|-----------|
| `Witness.Recording` | `Witness.Recording.swift:46` | `Mutex` for call list |
| `Witness.Cycle` | `Witness.Cycle.swift:36` | `Mutex` for index |
| `Witness.Sequence` | `Witness.Sequence.swift:37` | `Mutex` for index |
| `Witness.Values._Storage` | `Witness.Values.swift:43` | Unprotected dictionary |
| `Witness.Preparation.Store` | `Witness.Preparation.Store.swift:37` | `Mutex` for store |

**Assessment**: Witness types are consumed in tests. Under the non-sendable strategy (`non-sendable-strategy-isolation-design.md`), many of these could potentially drop their `Sendable` requirement if test execution stays within a single isolation domain. However, witnesses may be captured in `@Sendable` effect closures (e.g., TCA effects), so `Sendable` may be a genuine requirement. **Verdict: Audit each witness type's call sites to determine if `Sendable` is actually required by consumers.**

#### Kernel Infrastructure

| Type | File | Mechanism |
|------|------|-----------|
| `Kernel.Thread.Executor` | `Kernel.Thread.Executor.swift:74` | Internal lock + job queue; `SerialExecutor` conformance |

**Assessment**: `SerialExecutor` requires `Sendable`. The executor has internal synchronization. This is a correct and necessary use of `@unchecked Sendable`. **Verdict: Keep as-is.**

---

## Conventions

Based on the analysis above, the following conventions are recommended for all new code and refactoring decisions across the ecosystem.

### Convention 1: Isolation by Default

**Statement**: New types that manage mutable state accessed from multiple concurrency domains SHOULD use actors (Rank 1) as the default mechanism. Lower-ranked mechanisms SHOULD only be used when actors cannot satisfy the access pattern.

**Decision tree**:

```
Is all access async-tolerant?
  YES → Use an actor
  NO  → Is access from a single thread with one initialization transfer?
    YES → Use ~Copyable (Rank 2) or ~Sendable (when stable)
    NO  → Does the value cross exactly one boundary?
      YES → Use `sending` (Rank 3)
      NO  → Is synchronous lock-protected access required?
        YES → Use Mutex (Rank 4), make the containing type @unchecked Sendable
        NO  → Re-examine the design; one of the above should apply
```

### Convention 2: Minimize Sendable Surface

**Statement**: Types SHOULD NOT conform to `Sendable` unless they genuinely cross isolation boundaries. Keeping types non-`Sendable` is preferred — it enables synchronous, lock-free access with compile-time data race safety via isolation inheritance.

**Test**: Before adding `Sendable` to a type, answer: "Where does this type cross an isolation boundary?" If the answer is "nowhere" or "it might someday," do not add `Sendable`.

### Convention 3: `@unchecked Sendable` Requires Justification

**Statement**: Every `@unchecked Sendable` annotation MUST have a comment documenting:
1. **What mechanism provides thread safety** (mutex, atomic, ownership transfer, thread confinement)
2. **Why a higher-ranked mechanism cannot be used** (e.g., "synchronous access required on poll thread," "SerialExecutor conformance requires Sendable")

**Format**:

```swift
/// Thread-safe: internal state protected by `Synchronization<1>` mutex.
/// Cannot use actor: blocking threads require synchronous access without async context.
package final class Runtime: @unchecked Sendable {
```

### Convention 4: `nonisolated(nonsending)` for Operation Closures

**Statement**: Functions that take an `operation` closure that should inherit the caller's isolation MUST use the double-nonsending pattern: both the function and the closure parameter are `nonisolated(nonsending)`.

**Canonical form** (from stdlib `withTaskCancellationHandler`):

```swift
public nonisolated(nonsending) func withFoo<T, E: Error>(
    operation: nonisolated(nonsending) () async throws(E) -> T
) async throws(E) -> T
```

**Migration**: The 14 functions identified in `nonsending-ecosystem-migration-audit.md` should adopt this pattern. The deprecated `isolation: isolated (any Actor)? = #isolation` parameter should not be used in new code.

### Convention 5: `sending` for Boundary Crossings

**Statement**: Parameters that transfer ownership across isolation boundaries MUST be annotated with `sending`. This applies even when the type is already `Sendable` — `sending` documents the ownership transfer contract.

**Priority targets**: Channel `send`, `Async.Promise.fulfill`, `Async.Broadcast.send`, `Async.Completion.complete`. See `sending-expansion-audit.md` for the full list.

### Convention 6: `~Copyable` Over `sending` When Possible

**Statement**: When a value has a single owner and is transferred exactly once, `~Copyable` (Rank 2) SHOULD be preferred over `sending` (Rank 3). `~Copyable` provides a stronger guarantee — the compiler enforces exclusive ownership at all times, not just at the transfer site.

**Ecosystem evidence**: swift-io's design principle — all cross-boundary values are either `Sendable` value types or `~Copyable` ownership types. `sending` is redundant for `~Copyable` types because single ownership already prevents data races.

### Convention 7: Mutex Soundness Awareness

**Statement**: Code using `Mutex.withLock` MUST NOT return non-`Sendable` reference types from the closure when the calling context may be concurrent. The Mutex soundness bug (PF #360) allows non-sendable values to be escaped and accessed from multiple threads.

**Safe pattern**:

```swift
// SAFE: returns Sendable value type
let count = mutex.withLock { $0.count }

// SAFE: returns newly constructed value
let snapshot = mutex.withLock { Snapshot(from: $0) }

// DANGEROUS: returns non-Sendable reference from mutex
let escaped = mutex.withLock { $0 }  // Compiles but unsound
```

### Convention 8: Layer-Appropriate Sendability

**Statement**: The appropriate Sendable strategy depends on the architectural layer.

| Layer | Sendable Philosophy |
|-------|-------------------|
| L1 (Primitives) | Mirror kernel semantics faithfully. Descriptors, addresses, PIDs are numbers — the kernel allows any thread to use them. `Sendable` is correct at L1. |
| L2 (Standards) | Specification-determined. If the spec says "thread-safe," type is Sendable. If not, it's not. |
| L3 (Foundations) | Types encode higher-level contracts. Operational contracts (sequential access, thread confinement) SHOULD be expressed in the type system. `~Sendable` and `~Copyable` encode these constraints. Prefer isolation over locking. |
| L4-L5 (Components/Apps) | Isolation-first. Actors for mutable state. Non-Sendable types with isolation inheritance for most domain types. |

---

## Actionable Migration Plan

### Phase 1: Low-Risk, High-Value (immediate)

| Action | Scope | Source |
|--------|-------|--------|
| Add `sending` to 10 channel/promise/broadcast operations | swift-async-primitives | `sending-expansion-audit.md` |
| Migrate 7 primitives functions from `isolation:` to `nonisolated(nonsending)` | swift-async-primitives | `nonsending-ecosystem-migration-audit.md` |
| Migrate 8 foundations functions from `isolation:` to `nonisolated(nonsending)` | swift-dependencies, swift-witnesses | `nonsending-ecosystem-migration-audit.md` |

### Phase 2: Convention Enforcement (next sprint)

| Action | Scope | Source |
|--------|-------|--------|
| Add justification comments to all 29 `@unchecked Sendable` types | swift-kernel, swift-io, swift-file-system | Convention 3 |
| Audit witness types for unnecessary `Sendable` | swift-witnesses | This document |
| Implement non-Sendable `Strategy` | swift-test-primitives | `non-sendable-strategy-isolation-design.md` |

### Phase 3: Structural Refactoring (when stable)

| Action | Scope | Blocked On |
|--------|-------|------------|
| Apply `~Sendable` to 3 thread-confined types | swift-io, swift-file-system | SE-0518 stability |
| Evaluate actor replacement for Mutex-based test reporters | swift-tests | Case-by-case analysis |
| Evaluate actor replacement for `IO.Blocking.Threads.Runtime` | swift-io | Performance benchmarking |

---

## Outcome

**Status**: RECOMMENDATION

### Summary

The ecosystem should adopt **isolation-first concurrency**: use actors and `nonisolated(nonsending)` as the default, `~Copyable` for ownership transfer, `sending` for explicit boundary crossings, `Mutex` only when synchronous access is required, and `@unchecked Sendable` only as a documented last resort.

The ecosystem is already in strong shape — universal `NonisolatedNonsendingByDefault`, aggressive `~Copyable` adoption, correct `@concurrent` placement. The remaining work is:

1. **Migrate 14 functions** from deprecated `isolation:` to `nonisolated(nonsending)` (the stdlib's canonical direction)
2. **Add `sending`** to 10 channel/promise/broadcast operations (documents ownership transfer)
3. **Apply `~Sendable`** to 3 thread-confined types (when SE-0518 is stable)
4. **Audit `@unchecked Sendable`** usage in test/witness infrastructure for potential actor replacement
5. **Enforce conventions** via justification comments and code review

### Key Principles (quick reference)

1. **Isolation over locking.** Actors give unfettered mutable access. Locks give withLock ceremony, deadlock risk, and lock contention.
2. **Non-Sendable over Sendable.** Keeping types non-Sendable enables synchronous, lock-free access. Sendable is viral — it forces locks on everything it touches.
3. **Ownership over annotation.** `~Copyable` enforces exclusive access at all times. `sending` enforces it only at the transfer site. Prefer the stronger guarantee.
4. **Express the truth.** `@unchecked Sendable` on a thread-confined type is a lie. `~Sendable` tells the truth. When the type system can express the invariant, use it.
5. **Isolation inheritance over boundary crossing.** `nonisolated(nonsending)` keeps values within the caller's isolation domain. No boundary = no Sendable requirement = no ceremony.

## References

### External Sources

- Point-Free Video #356: "Beyond Basics: Superpowers" (Mar 2, 2026) — SQLiteData with `~Copyable`, `~Escapable`, actor-based read/write pools, "avoiding sendability" philosophy
- Point-Free Video #357: "Isolation: What Is It?" (Mar 9, 2026) — isolation definition from SE-0306, Bank/Account example, data races with non-isolated code, locking limitations
- Point-Free Video #360: "Isolation: Mutex" (Mar 30, 2026) — Mutex vs OSAllocatedUnfairLock, `sending` region-based isolation, Mutex soundness bug, viral Sendability anti-pattern, actors as the solution

### Swift Evolution Proposals

- SE-0306: Actors
- SE-0390: Noncopyable structs and enums (`~Copyable`)
- SE-0430: `sending` parameter and result values
- SE-0431: `nonisolated(nonsending)` function types
- SE-0446: Nonescapable types (`~Escapable`)
- SE-0461: `NonisolatedNonsendingByDefault`
- SE-0518: `~Sendable` (experimental)

### Internal Research (Synthesized)

| Document | Topic | Verified |
|----------|-------|----------|
| `nonsending-ecosystem-migration-audit.md` | 14 `isolation:` → `nonisolated(nonsending)` candidates | 2026-03-22 |
| `tilde-sendable-semantic-inventory.md` | 555 types audited, 3 Tier 1 `~Sendable` candidates | 2026-03-25 |
| `non-sendable-strategy-isolation-design.md` | Non-Sendable Strategy via isolation inheritance | 2026-03-04 |
| `nonsending-compiler-patterns.md` | Stdlib canonical patterns, conversion lattice, deprecation | 2026-03-22 |
| `sending-expansion-audit.md` | 10 missing `sending` annotations | 2026-02-25 |
| `callback-isolated-nonsending-design.md` | Async.Callback nonsending design (v3.1) | Implemented |
| `concurrent-expansion-audit.md` | `@concurrent` placement validation | 2026-03-22 |
| `nonsending-adoption-audit.md` | Original `@Sendable` site inventory | 2026-02-25 |
| `swift-io/Research/audit.md` | IO layer memory safety, 22 `@unchecked Sendable` verified | 2026-03-25 |

### Internal Experiments

| Experiment | Topic |
|------------|-------|
| `stdlib-concurrency-isolation/` | Stdlib isolation patterns |
| `stream-isolation-preservation/` | Stream operator isolation propagation |
| `nonsending-clock-feasibility/` | Clock `nonisolated(nonsending)` sleep |
| `nonsending-generic-dispatch/` | Generic dispatch with nonsending |
| `nonsending-method-annotation/` | Method-level nonsending |
| `nonsending-closure-type-constraints/` | Closure type applicability |
| `nonsending-sendable-iterator/` | Sendable iterator with nonsending |
| `callback-isolated-prototype/` | Callback isolation prototype |
