---
title: Sendable conformance inventory — swift-async-primitives
date: 2026-04-24
scope: Sources/ (Experiments/ and Tests/ excluded)
context: forums-review addressing — post 8 (@reviewer-c2) asked for this inventory
status: draft
---

# Sendable conformance inventory — swift-async-primitives

## Summary

The forums-review @reviewer-c2 post cited "116 Sendable conformances" as an
aggregate count. Disaggregated against actual `Sources/`:

| Category | Count |
|---|---|
| Public final classes with checked `Sendable` | 8 |
| Internal/`@usableFromInline` types with checked `Sendable` | ~30 |
| Public structs with checked `Sendable` (accessor wrappers) | ~10 |
| Conditional `Sendable where …` (checked, constrained) | several |
| **Unconditional `@unchecked Sendable`** | **5** |
| Generic constraints `<T: Sendable>` (constraints, not conformances) | many |

The c2 "116" figure conflates conformances, constraints, and mention-in-docs.
The load-bearing number for audit purposes is the **5 `@unchecked Sendable`
conformances**, each enumerated below.

## `@unchecked Sendable` sites (Sources/)

### 1. `Async.Mutex._Lock` — `Sources/Async Mutex Primitives/Async.Mutex.swift:53`

```swift
@safe
@_rawLayout(like: os_unfair_lock_s)
@usableFromInline
struct _Lock: ~Copyable, @unchecked Sendable {
    @inlinable init() {}
}
```

**Justification**: `@_rawLayout(like: os_unfair_lock_s)` wraps a raw-storage
slot matching the byte layout of `os_unfair_lock_s`. Swift cannot verify
`Sendable` automatically for raw-layout storage because the compiler doesn't
see the underlying semantics. The actual thread safety is guaranteed by
`os_unfair_lock_lock` / `os_unfair_lock_unlock`, which are defined to be
thread-safe synchronization primitives. `@unchecked` here is correct and
cannot be upgraded without losing raw-layout efficiency.

### 2. `Async.Mutex` (Darwin branch) — `Sources/Async Mutex Primitives/Async.Mutex.swift:75`

```swift
extension Async.Mutex: @unchecked Sendable where Value: ~Copyable {}
```

**Justification**: The Mutex's Sendability is conditional on `Value: ~Copyable`
(which includes both `Copyable` and `~Copyable` values). Swift cannot check
Sendability across the `@_rawLayout` boundary for `_Value`. The Mutex
serializes all `Value` access through `_lock()` / `_unlock()`, so the
effective Sendability is equivalent to the `Value`'s own Sendability plus
the lock serialization. Ecosystem convention is to mark the container
`@unchecked` and rely on the documented lock invariant.

### 3. `Async.Mutex._Value` (Darwin branch) — `Sources/Async Mutex Primitives/Async.Mutex.swift:77`

```swift
extension Async.Mutex._Value: @unchecked Sendable where Value: ~Copyable {}
```

**Justification**: The `_Value` raw-layout storage is the byte-level home of
the protected `Value`. It is never accessed outside the mutex's lock-held
regions, so its Sendability is guaranteed by the access discipline imposed
by the enclosing Mutex. `@unchecked` is correct per the same reasoning as #2.

### 4. `Async.Mutex` (embedded no-op class) — `Sources/Async Mutex Primitives/Async.Mutex.swift:167`

```swift
public final class Mutex<Value: ~Copyable>: @unchecked Sendable {
    @usableFromInline var _value: Value
    ...
}
```

**Justification**: This is the `#else` fallback for embedded environments
without OS kernel support. In single-threaded embedded contexts there is no
concurrent access to worry about; `@unchecked Sendable` is a compile-time
nominal conformance that compiles to no-op operations. Safety follows from
the absence of threading, not from synchronization.

### 5. `Async.Timer.Wheel.Storage` — `Sources/Async Timer Primitives/Async.Timer.Wheel.Storage.swift:36`

```swift
@usableFromInline
struct Storage: ~Copyable, @unchecked Sendable {
    @usableFromInline var arena: Buffer<Storage<Node>.Arena>.Arena.Bounded
    @usableFromInline let sentinel: Index<Node>
    ...
}
```

**Justification** (preserved from existing docstring at
`Async.Timer.Wheel.Storage.swift:23-26`): *"Storage contains mutable state.
Safety is guaranteed by the wheel's design: the wheel is `~Copyable` and
intended for single-actor use. All mutations are serialized by the owning
actor."* The single-actor ownership model is the serialization mechanism;
`@unchecked` is a consequence of `Buffer<Storage<Node>.Arena>.Arena.Bounded` not being
auto-Sendable (it holds mutable arena state).

## Classification

| Site | Safety source | Upgradable to checked? |
|---|---|---|
| #1 `_Lock` | `os_unfair_lock` primitive | No — `@_rawLayout` erases structure |
| #2 `Async.Mutex` (Darwin) | Internal lock serialization | No — wraps `@_rawLayout` storage |
| #3 `_Value` (Darwin) | Mutex's lock-held access discipline | No — `@_rawLayout` boundary |
| #4 `Async.Mutex` (embedded) | No threading in target environment | No — only `@unchecked` composes with `~Copyable` + no-op semantics |
| #5 `Timer.Wheel.Storage` | Single-actor ownership | Possible if `Buffer<Storage<Node>.Arena>.Arena.Bounded` becomes Sendable-verifiable |

None of the five `@unchecked` sites are currently upgradable to checked
`Sendable` without a substantial refactor. All five have clear safety
stories documented either in the file or below.

Site #5 is the only candidate for future revisit: if
`swift-buffer-primitives` introduces a checked-Sendable variant of
`Buffer.Arena.Bounded`, the Timer wheel storage could adopt it and drop
`@unchecked`.

## Policy for future Sendable conformances

1. Prefer checked `Sendable` where the compiler can verify.
2. Use `@unchecked Sendable` only when one of:
   - The type wraps `@_rawLayout` storage whose Sendability is
     opaque to the compiler.
   - The type's safety is guaranteed by a non-expressible invariant
     (actor isolation, external lock, single-threaded target).
   - The type is `~Copyable` and holds interior mutability that
     the compiler can't analyze.
3. Every `@unchecked Sendable` MUST carry a two-line justification in its
   containing file (docstring or adjacent comment), so a future reviewer
   can audit without greenfield analysis.

## Relation to forums-review finding

This document resolves the ask from simulation post 8 (@reviewer-c2):

> My ask: a pre-1.0 audit pass, and a Research note that enumerates every
> `@unchecked Sendable` with a two-line justification.

Disposition: addressed. Each of the 5 sites has a two-line+ justification.
None can be cheaply upgraded to checked. Site #5 is flagged for future
revisit if upstream infrastructure changes.
