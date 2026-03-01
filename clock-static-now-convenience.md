# Clock Static Now Convenience

<!--
---
version: 2.0.0
last_updated: 2026-03-01
status: RECOMMENDATION
tier: 2
trigger: ContinuousClock audit across swift-foundations found 16 files using stdlib ContinuousClock.now instead of Clock.Continuous
---
-->

## Context

An audit of `ContinuousClock` usage across swift-foundations identified 16 source files using the Swift stdlib's `ContinuousClock.now` static property instead of our `Clock.Continuous` from `Clock_Primitives`. The stdlib provides `static var now: ContinuousClock.Instant` as a concrete type property (confirmed via Swift stdlib source at `ContinuousClock.swift`). Our `Clock.Continuous` only provides an instance `var now: Instant` via platform extensions in ISO 9945 (POSIX) and Windows Kernel Primitives.

### Usage Categories

The audit revealed two distinct categories of `ContinuousClock.now` usage:

**Category A — Non-injectable infrastructure** (should use `static var now`):
Benchmarking, deadline calculation, elapsed-time tracking, timestamps. These are contexts where clock injection is irrelevant — the code genuinely needs wall-clock time. 13 files across swift-tests, swift-pools, swift-memory, swift-io, swift-parsers, swift-effects.

**Category B — Temporal operators** (should use injected `clock.now`):
Stream operators that hardcode `ContinuousClock.now` when they should accept a clock parameter. 3 files in swift-async (throttle, buffer.time, buffer.countOrTime). These are addressed by the clock parameterization work in `temporal-operator-determinism.md` (Phase 1) — NOT by static access.

### Prior Research

- **temporal-operator-determinism.md** (IN_PROGRESS): Establishes that temporal operators should use injected clock instances, not static access. Finding B1d: "`nonisolated(nonsending)` cannot be applied to synchronous function types. This means `ContinuousClock.now` comparisons in throttle (which are sync) do not benefit from nonsending." This research is orthogonal — it addresses Category B. Static `now` addresses Category A.

- **clock-dependency-key-placement.md** (IN_PROGRESS): Analyzes where `@Dependency(\.clock)` should live. Recommends Option F (integration sub-package in swift-dependencies). This provides the injected clock path for code that SHOULD be parameterized. Again orthogonal — dependency injection serves temporal operators, static `now` serves infrastructure.

## Question

Should `Clock.Continuous` and `Clock.Suspending` provide `static var now: Instant` as a convenience alongside the existing instance `var now`?

## Analysis

### Option A: Add `static var now` in platform packages

Add `static var now: Instant` to `Clock.Continuous` and `Clock.Suspending` in the platform extension files where instance `var now` already lives.

In `ISO 9945.Clock.Continuous.swift`:
```swift
extension Clock.Continuous {
    public static var now: Instant { Self().now }
}

extension Clock.Suspending {
    public static var now: Instant { Self().now }
}
```

Identical additions in `Windows.Clock.Continuous.swift`.

**Advantages**:
- Drop-in replacement: `ContinuousClock.now` → `Clock.Continuous.now` (mechanical migration)
- Mirrors stdlib convention — `ContinuousClock` provides both static and instance `now`
- No async, no `nonisolated(nonsending)` needed — purely synchronous computed property
- `Self().now` delegates to the existing instance implementation — zero code duplication
- Co-located with instance `var now` in the same platform extension files
- Does not affect temporal operator design (those should use injected `clock.now`)

**Disadvantages**:
- Two access paths for the same value (`Clock.Continuous.now` vs `Clock.Continuous().now`)
- Could be misused in temporal operators where clock injection is the correct pattern
- Slight API surface expansion

### Option B: Instance-only, no static convenience

Keep the current design. Require `Clock.Continuous().now` everywhere.

**Advantages**:
- Single access pattern — instance only
- Discourages hardcoded clock access (forces visible instance creation)

**Disadvantages**:
- Ergonomic gap vs stdlib (`ContinuousClock.now` vs `Clock.Continuous().now`)
- Every migration site needs `.now` on a throwaway instance
- `Clock.Continuous()` is a zero-state struct — the instance creation is purely ceremonial
- Doesn't prevent misuse (someone will just write `Clock.Continuous().now` in a temporal operator anyway)

### Option C: Typealias to stdlib ContinuousClock

```swift
public typealias ContinuousClock = Clock.Continuous
```

**Advantages**:
- Zero migration effort for existing code

**Disadvantages**:
- Name collision with stdlib `ContinuousClock`
- Violates [API-NAME-001] (compound name, no namespace)
- Confusing — which `ContinuousClock` is in scope?
- Does not solve the missing `static var now` problem

### Comparison

| Criterion | A: Static + Instance | B: Instance-only | C: Typealias |
|-----------|:---:|:---:|:---:|
| Ergonomic parity with stdlib | Yes | No | Partial |
| Mechanical migration | Yes | No | Yes |
| Single access pattern | No | Yes | No |
| Follows stdlib convention | Yes | — | — |
| Follows [API-NAME-001] | Yes | Yes | No |
| Prevents temporal-operator misuse | No | No | No |
| Platform-package only | Yes | Yes | N/A |

### Async and nonisolated(nonsending)

The user asked whether `static var now` requires async or `nonisolated(nonsending)`. It does not.

- `now` reads a hardware clock register via a synchronous syscall (`clock_gettime` on POSIX, `QueryPerformanceCounter` on Windows)
- `nonisolated(nonsending)` is async-only — the compiler rejects it on synchronous function types (confirmed in experiment B1d, `temporal-operator-determinism.md` line 55)
- `static var now: Instant` is a synchronous computed property returning a value. No suspension, no isolation concerns

### Platform-package constraint

Per project convention, only platform packages may perform syscalls and platform conditionals. `static var now` calls `Self().now`, which calls `Kernel.Clock.Continuous.now()` (a syscall). The call chain is:

```
Clock.Continuous.now (static)     — proposed, in platform package
  → Clock.Continuous().now        — existing instance property, in platform package
    → Kernel.Clock.Continuous.now()  — syscall wrapper, in platform package
      → clock_gettime(...)         — POSIX syscall / vDSO
```

Since `Self().now` delegates to the instance property that already lives in the platform package, the static property must live in the same file. It cannot live in `Clock_Primitives` (L1) because the instance `now` is not available there.

Locations:
- POSIX: `/Users/coen/Developer/swift-standards/swift-iso-9945/Sources/ISO 9945 Kernel/ISO 9945.Clock.Continuous.swift`
- Windows: `/Users/coen/Developer/swift-primitives/swift-windows-primitives/Sources/Windows Kernel Primitives/Windows.Clock.Continuous.swift`

### Performance analysis: `Self().now` vs stdlib

The stdlib inverts the delegation direction — `static var now` is primary, instance delegates to it:

```swift
// stdlib ContinuousClock
public static var now: ContinuousClock.Instant {
    // calls _getTime() directly — primary implementation
}
public var now: ContinuousClock.Instant {
    ContinuousClock.now  // delegates to static
}
```

Our proposed `Self().now` has static delegate to instance. Within the same module, the optimizer eliminates the zero-size `Self()` init and inlines the instance property. The resulting machine code is identical — a direct call to the kernel syscall wrapper.

Cross-module, neither approach benefits from inlining: the stdlib's `static var now` is also not `@inlinable`. Both resolve to a single non-inlined function call at the module boundary.

**Measurement pattern cost comparison** (2 reads + 1 subtract):

| Step | Ours | Stdlib |
|------|------|--------|
| Read clock | `clock_gettime()` → timespec | `swift_get_time()` → (seconds, nanoseconds) |
| Convert | `UInt64(tv_sec) * 1e9 + UInt64(tv_nsec)` (1 mul + 1 add) | `Duration(_seconds:nanoseconds:)` (2 mul + 1 add, seconds→attoseconds + nanoseconds→attoseconds) |
| Store | `Instant(nanoseconds: UInt64)` | `Instant(_value: Duration)` |
| Subtract | `UInt64 &-` → `.nanoseconds()` → Duration | Duration subtract (128-bit) |

Our representation (flat `UInt64` nanoseconds) is **fewer arithmetic operations** for the measurement pattern. The syscall/vDSO read dominates (~20–50ns), making the arithmetic difference (~1–5ns) negligible.

**Verdict**: `Self().now` is as performant as the stdlib for the static convenience. No optimization needed.

### Accuracy analysis: Clock source discrepancy (CRITICAL)

Comparing the POSIX clock sources used by our implementation vs the Swift stdlib:

| Clock | Platform | Ours | Stdlib | Match? |
|-------|----------|------|--------|--------|
| Continuous | Darwin | `CLOCK_MONOTONIC` | `CLOCK_MONOTONIC_RAW` | **NO** |
| Continuous | Linux | `CLOCK_BOOTTIME` | `CLOCK_BOOTTIME` | Yes |
| Suspending | Darwin | `CLOCK_UPTIME_RAW` | `CLOCK_UPTIME_RAW` | Yes |
| Suspending | Linux | `CLOCK_MONOTONIC` | `CLOCK_MONOTONIC` | Yes |

**`CLOCK_MONOTONIC` vs `CLOCK_MONOTONIC_RAW` on Darwin:**

- `CLOCK_MONOTONIC` — subject to NTP frequency adjustments (slewing). On Darwin, [documented as buggy](https://discussions.apple.com/thread/253778121): can jump backwards when system time is changed, violating the fundamental monotonic guarantee.
- `CLOCK_MONOTONIC_RAW` — raw hardware clock, NOT subject to NTP adjustments. Truly monotonic. Both continue to advance during system sleep.

The Swift stdlib (`Clock.cpp`: `swift_get_time`) and [Rust's `Instant`](https://github.com/rust-lang/rust/issues/77807) both use `CLOCK_MONOTONIC_RAW` on Darwin specifically because `CLOCK_MONOTONIC` can violate monotonicity. This is a correctness issue, not just a performance concern.

**Our `Kernel.Clock.Continuous.now()` on Darwin uses `CLOCK_MONOTONIC` — this must be changed to `CLOCK_MONOTONIC_RAW`.**

The fix is in `ISO 9945.Kernel.Clock.swift`:

```swift
// BEFORE (line 34):
clock_gettime(CLOCK_MONOTONIC, &ts)

// AFTER:
clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
```

This also requires updating the documentation in:
- `Clock.Continuous.swift` (Clock_Primitives, line 16): "Darwin: Uses `CLOCK_MONOTONIC`" → "Darwin: Uses `CLOCK_MONOTONIC_RAW`"
- `ISO 9945.Kernel.Clock.swift` (line 28): Same doc update

### Darwin-specific optimization opportunity

Darwin provides `clock_gettime_nsec_np()` which returns nanoseconds directly as `UInt64`, eliminating the timespec → nanoseconds conversion:

```swift
// Current:
var ts = Darwin.timespec()
clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
return UInt64(ts.tv_sec) * 1_000_000_000 + UInt64(ts.tv_nsec)

// Optimized:
return clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
```

This eliminates: 1 stack allocation (timespec), 1 multiply, 1 add. The `_nsec_np` ("nanoseconds, non-portable") suffix indicates it's Darwin-only, which is fine inside our `#if canImport(Darwin)` branch.

**However**: `clock_gettime_nsec_np` needs verification that it's available in Swift's Darwin module. This is a minor optimization — the multiply+add is ~1ns vs ~20–50ns for the clock read itself. The clock source fix (`CLOCK_MONOTONIC` → `CLOCK_MONOTONIC_RAW`) is far more important.

## Constraints

- `Clock_Primitives` (L1) defines `Clock.Continuous` and `Clock.Suspending` as structs but does NOT provide `var now` — that requires platform-specific syscalls
- Instance `var now` is added via `_Concurrency.Clock` conformance in ISO 9945 (POSIX) and Windows Kernel Primitives
- `static var now` must live in the same platform extensions because `Self().now` depends on the instance property
- `nonisolated(nonsending)` is irrelevant — `.now` is synchronous
- This does NOT address temporal operator clock injection (separate concern, see `temporal-operator-determinism.md`)

## Outcome

**Status**: RECOMMENDATION

### Recommendation 1: Fix Darwin clock source (CRITICAL)

Change `Kernel.Clock.Continuous.now()` on Darwin from `CLOCK_MONOTONIC` to `CLOCK_MONOTONIC_RAW`.

**Rationale**: `CLOCK_MONOTONIC` on Darwin can violate monotonicity (jump backwards on system time change). The Swift stdlib and Rust both use `CLOCK_MONOTONIC_RAW`. This is a correctness fix.

**Files**:
- `swift-iso-9945/.../ISO 9945.Kernel.Clock.swift:34` — change `CLOCK_MONOTONIC` → `CLOCK_MONOTONIC_RAW`
- `swift-clock-primitives/.../Clock.Continuous.swift:16` — update doc comment
- `swift-iso-9945/.../ISO 9945.Kernel.Clock.swift:28` — update doc comment

### Recommendation 2: Add `static var now` (ergonomic)

Add `static var now: Instant` to both `Clock.Continuous` and `Clock.Suspending` in the platform extension files (ISO 9945 and Windows).

**Rationale**:
1. Mirrors stdlib convention — `ContinuousClock` provides exactly this
2. Enables mechanical migration: `ContinuousClock.now` → `Clock.Continuous.now`
3. `Clock.Continuous` is a zero-state struct; `Self().now` is trivially equivalent to instance access
4. The "discourages hardcoded access" argument (Option B) doesn't hold — `Clock.Continuous().now` is equally hardcoded, just more verbose
5. Category A usage (benchmarking, deadlines, timestamps) is the dominant use case and genuinely non-injectable

**Implementation**: `public static var now: Instant { Self().now }` — 4 additions (2 types × 2 platforms).

### Recommendation 3: Darwin `clock_gettime_nsec_np` optimization (minor)

If available in Swift's Darwin module, replace `clock_gettime` + manual conversion with `clock_gettime_nsec_np` for both Continuous and Suspending on Darwin. Eliminates timespec stack allocation and multiply+add.

**Priority**: Low. The clock read dominates; this saves ~1ns per call.

### Migration scope

16 files in swift-foundations replace `ContinuousClock.now` → `Clock.Continuous.now` and `ContinuousClock.Instant` → `Clock.Continuous.Instant`. Category B files (3 async stream operators) should migrate to injected `clock.now` per temporal-operator-determinism Phase 1 instead.

## References

- temporal-operator-determinism.md — Clock parameterization for temporal operators
- clock-dependency-key-placement.md — @Dependency(\.clock) integration
- Swift stdlib [`ContinuousClock.swift`](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/ContinuousClock.swift) — `static var now` as concrete type property, instance `now` delegates to static
- Swift stdlib [`Clock.cpp`](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/Clock.cpp) — `swift_get_time` uses `CLOCK_MONOTONIC_RAW` on Darwin
- [SE-0329](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0329-clock-instant-duration.md) — Clock, Instant, and Duration
- [Darwin CLOCK_MONOTONIC bug](https://discussions.apple.com/thread/253778121) — `CLOCK_MONOTONIC` can jump backwards on Darwin
- [Rust issue #77807](https://github.com/rust-lang/rust/issues/77807) — Rust switched to `CLOCK_MONOTONIC_RAW` on Darwin for the same reason
