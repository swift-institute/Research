---
date: 2026-03-31
session_objective: Convention 3 audit of @unchecked Sendable in swift-io
packages:
  - swift-io
status: processed
processed_date: 2026-03-31
triage_outcomes:
  - type: skill_update
    target: memory-safety
    description: Added [MEM-SEND-004] ~Copyable structs can use plain Sendable when all fields are Sendable
  - type: doc_improvement
    target: modern-concurrency-conventions.md
    description: Updated swift-io inventory (29→16), removed phantom IO.Event.Waiter, updated Category C status
  - type: package_insight
    target: swift-io
    description: SE-0518 ~Sendable deferred for IOCP.State and IOUring.Ring
---

# Convention 3 Audit — @unchecked Sendable Truth-Telling

## What Happened

Audited all 16 `@unchecked Sendable` types in swift-io/Sources/ against Convention 3 (every `@unchecked Sendable` must document what mechanism provides thread safety and why a higher-ranked mechanism can't be used). Categorized each type, verified existing comments, added missing comments, and made three kinds of changes:

1. **Removed `@unchecked Sendable` from 2 thread-confined types** (`IOCP.State`, `IOUring.Ring`) — made them non-Sendable rather than keeping the type-level lie. Build confirmed no downstream breakage because both are transferred via `Unmanaged` raw pointers, not typed Sendable crossings.

2. **Dropped `@unchecked` → plain `Sendable` on 3 ~Copyable structs** (`Channel.Reader`, `Channel.Writer`, `Channel.Split`) — all stored properties were already Sendable. Same pattern that eliminated 19 annotations in swift-async-primitives.

3. **Added/improved Convention 3 justification comments on 6 types** that lacked them or had incomplete documentation.

Also discovered the conventions document's inventory was stale — 3 types it listed as `@unchecked Sendable` had already been migrated to plain `Sendable` in prior sessions, and one type name was wrong (`IO.Event.Waiter` doesn't exist; it's `IO.Completion.Waiter`).

## What Worked and What Didn't

**Worked well**: The categorization framework from `modern-concurrency-conventions.md` (A: thread-safe, B: ownership transfer, C: thread-confined, D: can drop) made triage mechanical. Reading each type's stored properties and checking Sendability of each was straightforward.

**Key decision point**: Initial plan was to keep `@unchecked Sendable` on thread-confined types with a `~Sendable when SE-0518 ships` comment. User pushed back — correctly — that keeping a type-level lie is worse than removing it. The build proved the `@unchecked Sendable` was unnecessary for both types because they're transferred via `Unmanaged` pointer recovery, not typed Sendable crossings. The annotation was cargo-culted, not load-bearing.

**Confidence was low on**: Whether `~Copyable` structs can use plain `Sendable` (not `@unchecked`). Confirmed: yes, the compiler synthesizes/checks Sendable for `~Copyable` structs when all stored properties are Sendable. This was already established in the async-primitives migration but worth re-confirming.

## Patterns and Root Causes

**Pattern: Cargo-culted `@unchecked Sendable`**. Both thread-confined types had `@unchecked Sendable` because they cross one initialization boundary. But the actual transfer mechanism (`Unmanaged` pointer → `UnsafeMutableRawPointer` in Handle) doesn't check Sendable at all. The annotation was added "because the compiler complained" at some earlier point, then never re-evaluated when the transfer was refactored to use raw pointers. This is exactly the anti-pattern Convention 3 exists to prevent — without a justification comment, nobody questions whether the annotation is still necessary.

**Pattern: Stale inventories**. The conventions document listed 26 types; the actual count was 16 (3 already fixed, several never existed or were miscounted). Inventories that aren't verified against current code drift silently. The audit process itself is the verification — the document is a snapshot, not a source of truth.

**Pattern: `~Copyable` + plain `Sendable` is underused**. Three types had `@unchecked` purely because they were `~Copyable` and the original author assumed `~Copyable` types couldn't get plain Sendable. This was disproven in the async-primitives pass but the knowledge hadn't propagated to the IO layer. The dead-end from `HANDOFF-async-mutex-sending-refactor.md` ("Assumed `~Copyable` requires `@unchecked Sendable` — wrong") keeps recurring.

## Action Items

- [ ] **[skill]** memory-safety: Add explicit guidance that `~Copyable` structs CAN use plain `Sendable` when all stored properties are Sendable — `@unchecked` is not required just because the type is `~Copyable`
- [ ] **[doc]** modern-concurrency-conventions.md: Update swift-io inventory from 26 → 16 types, mark 3 already-migrated, correct `IO.Event.Waiter` → `IO.Completion.Waiter`
- [ ] **[package]** swift-io: When SE-0518 ships (Swift 6.4), apply `~Sendable` to `IOCP.State` and `IOUring.Ring` to make thread confinement type-level truth
