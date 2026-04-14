# Async.Mutex @_rawLayout Inline Storage

<!--
---
title: Async.Mutex @_rawLayout Inline Storage
status: DEFERRED
tier: 2
created: 2026-03-31
last_updated: 2026-04-13
applies_to: [swift-async-primitives]
---
-->

## Context

`Async.Mutex` currently wraps a class for its internal storage. Stdlib's `Synchronization.Mutex` uses `@_rawLayout` for inline storage, eliminating the class indirection entirely. This saves one heap allocation per Mutex instance.

## Question

Can `Async.Mutex` adopt stdlib's `@_rawLayout` pattern for inline storage, eliminating the class indirection? What are the constraints and trade-offs?

## Analysis

**Current architecture**: `Async.Mutex<Value>` stores a `_Storage` class with a lock + value. One allocation per Mutex.

**Stdlib's approach**: Uses `@_rawLayout` with platform-specific lock primitives inlined into the struct. No heap allocation.

**Constraints**:
- `@_rawLayout` is an experimental attribute — requires feature flag
- The ecosystem already uses `@_rawLayout` for `Buffer.Fixed` ([IMPL-071] validates the `nonmutating _modify` pattern)
- Async.Mutex may need to be `Sendable` without a class — requires the lock primitive itself to be safe for cross-thread access when inlined in a struct

## Outcome

*Pending investigation — depends on `@_rawLayout` stabilization timeline and whether the ecosystem's `nonmutating _modify` pattern ([IMPL-071]) transfers to Mutex.*

### Deferred

- **Blocker**: @_rawLayout stabilization + IMPL-071 validation
- **Resumption trigger**: Swift 6.2 release or IMPL-071 documented

## References

- [IMPL-070] — coroutine Mutex pattern
- [IMPL-071] — nonmutating _modify for interior mutability
- 2026-03-30-modern-concurrency-sendability-pass.md — discovery session
