---
title: Async.Mutex cross-platform state — 2026-04-24 premise correction
date: 2026-04-24
context: forums-review findings for swift-async-primitives, Open Question #2
status: draft — awaiting user direction before implementation
---

# Async.Mutex cross-platform state

## Summary

The forums-review simulation post 11 (@reviewer-c5) claimed `Async.Mutex` is Darwin-only. The handoff propagated this claim as Open Question #2. Reading the actual source: **`Async.Mutex` is available on all non-embedded platforms** via a fallback chain. The real finding is narrower — one optional API (`.locked.value` coroutine accessor) is Darwin-only — and has zero current callers.

## Source of truth

`Sources/Async Mutex Primitives/Async.Mutex.swift`:

```swift
#if !hasFeature(Embedded) && canImport(Darwin)
    // Primary: os_unfair_lock-based impl with @_rawLayout storage.
    // Exposes: withLock, withLockIfAvailable, locked (coroutine)
#elseif !hasFeature(Embedded) && canImport(Synchronization)
    public typealias Mutex = Synchronization.Mutex
    // Swift 6.0+ stdlib Mutex. Available on Linux and Windows where Swift supports them.
    // Exposes: withLock, withLockIfAvailable (stdlib)
#elseif !hasFeature(Embedded) && canImport(Kernel_Thread_Primitives)
    public typealias Mutex = Kernel.Thread.Mutex.Value
    // Pre-Synchronization-module fallback
#else
    // Embedded: no-op class
#endif
```

`Sources/Async Mutex Primitives/Async.Mutex+Ownership.swift` is gated `canImport(Synchronization)` — so the `withLock(consuming:)` / `withLock(deposit:)` extensions land on Linux/Windows alongside Darwin.

`Sources/Async Mutex Primitives/Async.Mutex.Locked.swift` is gated `canImport(Darwin)` — so the `Locked` struct and its `value` property are **Darwin-only**.

## API parity table

| API | Darwin | Linux | Windows | Embedded |
|---|---|---|---|---|
| `Async.Mutex<Value>` type | ✅ os_unfair_lock impl | ✅ stdlib Mutex typealias | ✅ stdlib Mutex typealias | ✅ no-op class |
| `withLock(_:)` | ✅ | ✅ | ✅ | ✅ |
| `withLockIfAvailable(_:)` | ✅ | ✅ | ✅ | ✅ |
| `withLock(consuming:body:)` | ✅ | ✅ | ✅ | ❌ |
| `withLock(deposit:body:)` | ✅ | ✅ | ✅ | ❌ |
| `locked.value` (coroutine) | ✅ | ❌ | ❌ | ❌ |

## Current-call-site audit

`grep -rn '\.locked\.value\|\.locked\.' Sources Tests`:

- `Async.Mutex.Locked.swift:25-26` — docstring examples only.
- `Async.Mutex.swift:38, :151` — docstring examples only.

Zero production callers, zero test callers. The `.locked.value` API is a published surface that no code currently uses.

## Consequence

A Linux or Windows build today:
- compiles (uses Synchronization.Mutex typealias);
- provides 4 of the 5 Mutex APIs;
- does NOT provide `.locked.value`.

The c5 reviewer's claim ("`Async.Mutex` does not exist on Linux, Windows, or embedded") is wrong as stated. The narrower claim ("`.locked.value` is Darwin-only") is correct and would matter if any future consumer reached for the coroutine API on a non-Darwin target.

## Decision space (for Q2)

Three realistic resolutions, framed with the corrected premise:

| Option | Action | Engineering cost | API surface change |
|---|---|---|---|
| **(a') Extend `.locked` to Linux/Windows** | Add a Synchronization.Mutex-wrapping `Locked` view OR a raw pthread/SRWLock impl matching Darwin. `Synchronization.Mutex.withLock` is closure-based; wrapping it as a coroutine yield/unyield may be awkward. Raw impls are cleaner but duplicate the storage pattern three times. | High | Additive (new impls on non-Darwin) |
| **(b) Document the split** | README / DocC note: `.locked.value` is Darwin-only; Linux/Windows use `withLock`. No code change. | Low | None |
| **(c) Remove `.locked` coroutine API** | Delete `Async.Mutex.Locked.swift` and the `locked` accessor. All callers use `withLock`. Zero current callers so no regression. | Low | Subtractive (one API removed) |

Option (a') is what the user authorized under the original (wrong) premise. With the corrected premise, (b) and (c) are also valid.

The c5 -1 deflates equivalently under (a') and (c) — both close the cross-platform gap. (b) preserves the gap but calls it out.

## Related forums-review findings unaffected by this correction

- Fairness disclaimer on `os_unfair_lock` (c3 post 6) — orthogonal; applies regardless of platform resolution.
- Typed-throws audit of the 12 untyped sites (c3 post 6) — orthogonal.
- The `@unchecked Sendable` on `_Lock` (currently in the Darwin impl) would be inherited by any (a') raw impl.

## Provenance

Produced by subordinate agent continuing HANDOFF.md for swift-async-primitives (forums-review addressing). Premise-correction surfaced per [HANDOFF-016] staleness-axis check (factual claim in handoff turned out to be imprecise relative to actual source state).
