# Clock / Kernel.Time Unification

| Field | Value |
|-------|-------|
| **Date** | 2026-03-19 |
| **Status** | IMPLEMENTED |
| **Tier** | 2 (cross-package design decision) |
| **Trigger** | `CLOCK_MONOTONIC` vs `CLOCK_MONOTONIC_RAW` mismatch caused 5.5-second deadline bug in swift-io |

## Context

Two parallel "monotonic nanoseconds" APIs exist with different underlying clocks:

| API | Darwin | Linux | Windows | Defined At |
|-----|--------|-------|---------|------------|
| `Kernel.Clock.Continuous.now()` | `CLOCK_MONOTONIC_RAW` | `CLOCK_BOOTTIME` | `QueryPerformanceCounter` | L2 (iso-9945, windows-primitives) |
| `Kernel.Time.monotonicNanoseconds()` | `CLOCK_MONOTONIC` | `CLOCK_MONOTONIC` | N/A (not implemented) | L2 (iso-9945) |

Deadlines created with one and evaluated with the other drift apart. On the development machine, NTP frequency discipline caused ~5.5 seconds of drift. The swift-io poll paths have already been migrated to `Kernel.Clock.Continuous.now()`.

## Q1: Should `Kernel.Time.monotonicNanoseconds()` be removed?

### Analysis

`CLOCK_MONOTONIC` on Darwin is NTP-frequency-disciplined. It can drift relative to `CLOCK_MONOTONIC_RAW` and, in rare cases, violate strict monotonicity on system time changes. The Swift stdlib and Rust both chose `CLOCK_MONOTONIC_RAW` for exactly this reason.

On Linux, `CLOCK_MONOTONIC` pauses during sleep — it is the *suspending* clock, not the continuous clock. `Kernel.Time.monotonicNanoseconds()` uses `CLOCK_MONOTONIC` on both platforms, which means:

- **Darwin**: Wrong clock (NTP-disciplined, not hardware)
- **Linux**: Suspending clock mislabeled as "monotonic" — callers expecting continuous behavior get suspending behavior

There is no valid use case for `CLOCK_MONOTONIC` specifically. Any caller wanting elapsed-time measurement should use either:
- `Kernel.Clock.Continuous.now()` — advances during sleep, immune to NTP (CLOCK_MONOTONIC_RAW / CLOCK_BOOTTIME)
- `Kernel.Clock.Suspending.now()` — pauses during sleep (CLOCK_UPTIME_RAW / CLOCK_MONOTONIC)

These two typed APIs cover all monotonic time needs with correct, documented semantics.

### Remaining consumers

| Consumer | Location | Migration |
|----------|----------|-----------|
| Windows glob test | `swift-windows/Tests/Windows Kernel Tests/Windows.Kernel.Glob Tests.swift:117` | Replace with `Kernel.Clock.Continuous.now()` — used only for unique directory name generation |
| IO Completions fake driver | `swift-io/Tests/IO Completions Tests/IO.Completion.Driver.Fake.swift:149` | **Private reimplementation** — does not call the ISO 9945 function. Uses `CLOCK_UPTIME_RAW` on Darwin (suspending clock). Should be renamed to `suspendingNanoseconds()` for clarity, but no functional change needed. |

### Decision

**Delete `Kernel.Time.monotonicNanoseconds()`** from iso-9945. Only 1 real consumer remains (glob test), trivially migrated. The API is a trap: its name implies it returns "the" monotonic time, but it returns the wrong clock on Darwin and the wrong semantic (suspending) on Linux.

The fake driver's private reimplementation is not affected — it's a separate function that happens to share the name.

## Q2: Should `Kernel.Time.realtimeEpochSeconds()` be removed or relocated?

### Analysis

Wall-clock time is a legitimate concern, distinct from monotonic time. The question is where it should live.

Current state: `Kernel.Time.realtimeEpochSeconds()` is defined in iso-9945, returns `Double` from `gettimeofday()`. Single consumer: test performance timestamp infrastructure (`swift-tests/Sources/Tests Performance/Test.Trait.Scope.Provider.timed.swift:202`).

Options:
1. **Delete it** — only 1 consumer, in test infrastructure
2. **Move to `Kernel.Clock.Realtime`** — new clock namespace, parallel to Continuous/Suspending
3. **Keep in `Kernel.Time`** — separate concern from monotonic clocks

Option 2 (new `Kernel.Clock.Realtime` namespace) is tempting but premature. Realtime/wall-clock is fundamentally different from monotonic clocks: it can jump backwards, is subject to NTP step adjustments, and should never be used for elapsed-time measurement. Placing it alongside `Continuous` and `Suspending` in `Kernel.Clock` could invite misuse by association.

Option 3 keeps the status quo but perpetuates the confusion between `Kernel.Time` (file timestamps) and `Kernel.Time.realtimeEpochSeconds()` (wall-clock time). `Kernel.Time` is a typealias to `Instant` (seconds + nanoseconds since Unix epoch) — it *is* wall-clock time for file timestamps. Adding `realtimeEpochSeconds()` as a static method on this typealias is actually coherent: both represent wall-clock time, just in different formats.

### Decision

**Keep `Kernel.Time.realtimeEpochSeconds()` where it is.** The single consumer is in test infrastructure (performance timestamps), which is a valid use of wall-clock time. The API is correctly named, correctly documented ("NOT suitable for elapsed time measurement"), and coherently placed on `Kernel.Time` which already represents wall-clock time via its `Instant` typealias.

No action needed. If additional wall-clock APIs are needed in the future, they naturally belong on `Kernel.Time` as well.

### Update 2026-04-18 — typed-return axis revisit

The 2026-03-19 decision "keep `realtimeEpochSeconds() -> Double` as-is" is **superseded** by the typed-return work in Phase 1 (Q3, commits `baf1789`–`c6e1bad`). Once `Kernel.Clock.*.now()` started returning fully-typed `Clock.*.Instant`, the raw `Double` return from `realtimeEpochSeconds()` became the sole raw-int time API on `Kernel.Time`, and the ecosystem audit (`swift-institute/Audits/typed-time-clock-adoption.md`, finding #9) flagged it under [IMPL-006] (Typed Stored Properties) and [IMPL-INTENT].

Current state:

- `ISO_9945.Kernel.Time.realtime() -> Kernel.Time` (typed) — uses `clock_gettime(CLOCK_REALTIME, …)` for nanosecond precision.
- `Windows.Kernel.Time.realtime() -> Kernel.Time` (typed) — mirrors POSIX; uses `GetSystemTimeAsFileTime` and decomposes internally.
- `Kernel.Time.realtimeEpochSeconds() -> Double` — **deleted**.
- `Windows.Kernel.Time.unixTime() -> Int64` and `unixTimeNanoseconds() -> Int64` — **deleted** (subsumed by `realtime()`).
- Consumer at `swift-tests/Tests Performance/Test.Trait.Scope.Provider.timed.swift` migrated to `Kernel.Time.realtime()`; `Tests.History.Record.timestamp` widened from `Double` to `Instant`.

The shift from Q2's conclusion happened because the audit ran the same site through the `/implementation` axioms (intent-over-mechanism, typed stored properties) that Q2's analysis predates. Q2's justification for keeping the raw API — "test infrastructure is a valid wall-clock consumer" — is still correct on the consumer side, but the API **shape** (raw `Double`) is what the audit flagged. The typed replacement honors both the original "keep wall-clock time on `Kernel.Time`" conclusion and the typed-return axis.

Q3's update-note pattern applies here — same revisit mechanism.

## Q3: Should `Kernel.Clock.*` and `Clock.*` be unified?

### Analysis

Two parallel clock namespaces exist for structural reasons:

| Namespace | Layer | Type | Returns | Purpose |
|-----------|-------|------|---------|---------|
| `Kernel.Clock.{Continuous,Suspending}` | L1 enum (kernel-primitives), L2 impl (iso-9945, windows) | Empty enum | `UInt64` nanoseconds | Raw syscall wrapper for kernel/IO code |
| `Clock.{Continuous,Suspending}` | L1 struct (clock-primitives), L2 `_Concurrency.Clock` conformance | Struct | `Tagged<_, Clock.Nanoseconds>` (typed `Instant`) | Application-level typed clock |

The relationship is already clean: `Clock.Continuous.now` delegates to `Kernel.Clock.Continuous.now()` and wraps the result in a typed `Instant`:

```swift
// In iso-9945 (L2):
extension Clock.Continuous: _Concurrency.Clock {
    public var now: Instant {
        Instant(nanoseconds: Kernel.Clock.Continuous.now())
    }
}
```

#### Option 1: Status quo — Two namespaces coexist

**Pros**: Clean separation of concerns. `Kernel.Clock.*` is the raw syscall for IO/kernel code that needs `UInt64`. `Clock.*` is the typed API for application code.

**Cons**: Two "now" functions that return the same underlying value in different types. Discoverability cost.

#### Option 2: Merge into `Clock` — `Clock.Continuous.now() -> UInt64` at L1

**Rejected**. Violates L1 constraints — clock implementations require platform modules. Also pollutes the typed `Clock` namespace with raw `UInt64` APIs.

#### Option 3: Merge into `Kernel.Clock` — Make `Kernel.Clock.Continuous` the canonical source

**Rejected**. `Kernel.Clock.Continuous` is an empty enum at L1 — it cannot hold the struct fields needed for `_Concurrency.Clock` conformance. Would require restructuring both packages.

#### Option 4: Bridge — typed accessor on `Kernel.Clock.Continuous`

**Rejected**. Requires cross-package dependency from kernel-primitives to clock-primitives, creating a lateral dependency at L1.

### Decision

**Status quo (Option 1).** The two-namespace design is intentional and structurally sound:

- `Kernel.Clock.Continuous.now() -> UInt64` — for code that operates at the syscall boundary (IO event loops, deadline arithmetic with raw nanoseconds)
- `Clock.Continuous.now -> Clock.Continuous.Instant` — for application code that wants type safety and `_Concurrency.Clock` conformance

The delegation is one-directional (`Clock.*` → `Kernel.Clock.*`), the types are distinct, and the purposes don't overlap. Document the relationship in `Kernel.Clock`'s doc comments.

## Q4: What should happen to `Kernel.Time.Deadline`?

### Analysis

`Kernel.Time.Deadline` takes `monotonicNanoseconds: UInt64` in all its factory/query methods. The doc comments already reference `Kernel.Clock.Continuous.now()` as the intended source. The parameter name `monotonicNanoseconds` is technically correct but misleading — it doesn't distinguish *which* monotonic clock, and on Linux `CLOCK_MONOTONIC` is the suspending clock, not the continuous one.

#### Q4a: Rename parameter to `continuousNanoseconds`?

**Breaking change** for all call sites. But the parameter name `monotonicNanoseconds` is the root cause of the confusion that led to the 5.5-second bug — callers see "monotonic" and reach for `Kernel.Time.monotonicNanoseconds()`, not `Kernel.Clock.Continuous.now()`.

After deleting `Kernel.Time.monotonicNanoseconds()` (Q1), the misleading name is still a documentation smell, but there's no longer a wrong API to accidentally reach for. The parameter could be renamed, but the benefit is marginal against the migration cost.

#### Q4b: Move to `Clock.Continuous.Deadline`?

**Rejected.** `Kernel.Time.Deadline` lives at L1 (kernel-primitives) and is used by IO code that operates on raw `UInt64`. Moving it to `Clock.Continuous` would require either:
- Making it depend on clock-primitives (lateral L1 dependency), or
- Placing it at L2 where IO code can't reach it without pulling in Clock

The current placement is correct: deadline is a kernel-level concept that takes raw nanoseconds.

#### Q4c: Factory method taking `Clock.Continuous.Instant`?

This would require clock-primitives to depend on kernel-primitives (for the `Deadline` type) or vice versa. Neither direction is clean. Better to add this as an extension in a package that imports both — iso-9945 or a consumer package.

### Decision

**Keep `Kernel.Time.Deadline` where it is, with current parameter names.** After removing `Kernel.Time.monotonicNanoseconds()`, the trap is eliminated. The doc comments already direct callers to `Kernel.Clock.Continuous.now()`. Rename is not worth the breaking change.

**Optional enhancement**: Add a convenience extension in iso-9945 (L2) that bridges `Clock.Continuous.Instant` to `Kernel.Time.Deadline`:

```swift
extension Kernel.Time.Deadline {
    public static func now(at instant: Clock.Continuous.Instant) -> Deadline {
        Deadline(nanoseconds: instant.nanoseconds)
    }

    public func hasExpired(at instant: Clock.Continuous.Instant) -> Bool {
        hasExpired(at: instant.nanoseconds)
    }
}
```

This is additive, non-breaking, and lives at L2 where both types are available. **Deferred** — implement when a consumer needs it.

### Update 2026-04-18 — Q4b revisit (type-path axis)

The 2026-03-19 rejection of Q4b is **superseded**. Both rationales it cited are now stale:

- *"Uses raw UInt64"* — Phase 1 of `clock-time-unification` (Q3 revisit, commits
  `baf1789`–`c6e1bad`) migrated `Deadline`'s internal representation to typed
  `Clock.Continuous.Instant`. The raw-UInt64 API surface no longer exists.
- *"Lateral L1 dependency"* — `Kernel Time Primitives` already depends on
  `Clock Primitives` (via `public import Clock_Primitives`) to hold the typed
  `Instant`. The dependency the rejection was avoiding is already in place.

With those constraints gone, the type's location no longer reflects its semantics:
`Kernel.Time.Deadline` stores a `Clock.Continuous.Instant` and is only meaningful
against continuous-clock readings. `Kernel.Clock.Continuous.Deadline` puts the
clock identity in the type path, turning "mix a continuous-clock deadline with a
suspending-clock reading" into a compile-error rather than a documentation smell.

Current state:

- `Kernel.Clock.Continuous.Deadline` and its `.Next` atomic cell live in
  `Kernel Clock Primitives` (which now carries the `Clock_Primitives` dep).
- `Kernel Event Primitives` depends on `Kernel Clock Primitives` and imports it
  via `exports.swift`; consumer APIs (`poll`, `Driver`) take
  `Kernel.Clock.Continuous.Deadline?`.
- `Kernel Time Primitives/Kernel.Time.Deadline.swift` and `Kernel.Time.Deadline.Next.swift`
  are **deleted**; `Kernel.Time` reverts to the `Instant` typealias plus
  package-scope accessors.
- Callers migrated across `swift-executor-primitives`, `swift-foundations/swift-kernel`,
  and `swift-foundations/swift-io` tests.

Same update-note mechanism as Q2/Q3's axis revisits.

## Q5: What is the `Kernel.Time` typealias for?

### Analysis

`Kernel.Time = Instant` where `Instant` is from time-primitives (seconds + nanosecond fraction since Unix epoch). Used for:

- File timestamps: `Kernel.File.Stats.{accessTime, modificationTime, changeTime}: Kernel.Time`
- Static utilities: `Kernel.Time.milliseconds(from:)` (Duration → CInt for epoll/poll)
- Monotonic/realtime accessors added at L2 (the problematic `monotonicNanoseconds()` and the fine `realtimeEpochSeconds()`)

The confusion arises because `Kernel.Time` does double duty:
1. **Calendar time** — file timestamps (its primary purpose via `Instant`)
2. **Clock operations** — monotonic/realtime static methods bolted on at L2

After removing `monotonicNanoseconds()` (Q1), the only remaining L2 method is `realtimeEpochSeconds()`, which is coherent with the calendar-time purpose. The `milliseconds(from:)` utility is a pure conversion function for Duration, not a clock operation.

### Decision

**Keep `Kernel.Time` as-is.** After removing `monotonicNanoseconds()`, the remaining surface is coherent:

- `Kernel.Time` (typealias) → file timestamps, calendar time
- `Kernel.Time.Deadline` → monotonic deadline (takes raw `UInt64`, clock-agnostic)
- `Kernel.Time.Deadline.Next` → atomic deadline storage
- `Kernel.Time.milliseconds(from:)` → pure Duration conversion
- `Kernel.Time.realtimeEpochSeconds()` → wall-clock time (coherent with calendar-time purpose)

No rename needed. The monotonic clock operations are properly in `Kernel.Clock.*`.

## Q6: Platform completeness

### Darwin

| Clock | API | Status |
|-------|-----|--------|
| Continuous | `clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)` | Correct |
| Suspending | `clock_gettime_nsec_np(CLOCK_UPTIME_RAW)` | Correct |

No mismatch risk after removing `monotonicNanoseconds()`.

### Linux (Glibc + Musl)

| Clock | API | Status |
|-------|-----|--------|
| Continuous | `clock_gettime(CLOCK_BOOTTIME)` | Correct |
| Suspending | `clock_gettime(CLOCK_MONOTONIC)` | Correct |

No mismatch risk. `CLOCK_BOOTTIME` advances during sleep; `CLOCK_MONOTONIC` pauses.

### Windows

| Clock | API | Status |
|-------|-----|--------|
| Continuous | `QueryPerformanceCounter` | Correct |
| Suspending | `QueryUnbiasedInterruptTime` | Correct |

No `monotonicNanoseconds()` implementation exists on Windows — no mismatch risk. `QueryPerformanceCounter` is the hardware timer (always advances, immune to NTP). `QueryUnbiasedInterruptTime` subtracts sleep time.

**Note**: `QueryPerformanceCounter` calls `QueryPerformanceFrequency` on every invocation. This is safe (the frequency is constant and cached by the kernel) but could be optimized by caching the frequency value. Not a correctness issue — deferred.

### WASI / OpenBSD / Embedded

No dedicated clock primitives exist for these platforms. The `#if` guards in kernel-primitives include `os(OpenBSD)` but no implementation exists in iso-9945 (which doesn't compile for OpenBSD). No WASI or embedded implementations exist.

**Assessment**: Not a gap that needs filling now. These platforms can be added when there's a consumer. The architecture supports it — add a new L2 package (e.g., `swift-wasi-primitives`) with extensions on `Kernel.Clock.Continuous` and `Kernel.Clock.Suspending`.

### Fake driver note

The IO completions fake driver (`IO.Completion.Driver.Fake.swift`) had a private `monotonicNanoseconds()` that used `CLOCK_UPTIME_RAW` on Darwin — the **suspending** clock, not the continuous clock. **Replaced** with `Kernel.Clock.Continuous.now()` to match production IO code. The private reimplementation and platform-specific imports (Darwin/Glibc/WinSDK) were removed entirely.

## Migration Plan

### Phase 1: Delete `Kernel.Time.monotonicNanoseconds()` — COMPLETE (2026-03-19)

1. **Migrated glob test** (`swift-windows/Tests/Windows Kernel Tests/Windows.Kernel.Glob Tests.swift:117`):
   `Kernel.Time.monotonicNanoseconds()` → `Kernel.Clock.Continuous.now()`

2. **Deleted** `monotonicNanoseconds()` from `swift-iso-9945/Sources/ISO 9945 Kernel/ISO 9945.Kernel.Time.swift`

3. **Replaced** fake driver's private `monotonicNanoseconds()` reimplementation (`swift-io/Tests/IO Completions Tests/IO.Completion.Driver.Fake.swift`) with `Kernel.Clock.Continuous.now()`. Removed platform-specific imports (Darwin/Glibc/WinSDK), added `import Kernel`.

4. **Verified** zero remaining consumers via workspace-wide grep (only research documents reference the deleted API).

### Phase 2: Documentation (optional)

1. Add cross-reference doc comment on `Kernel.Clock` pointing to `Clock.*` for typed instants

### Phase 3: Convenience bridge (deferred)

Add `Kernel.Time.Deadline` extension in iso-9945 accepting `Clock.Continuous.Instant` — implement when a consumer needs it.

## Decision Summary

| Question | Decision | Status |
|----------|----------|--------|
| Q1: Remove `monotonicNanoseconds()`? | **Yes, delete** | DONE — deleted from iso-9945, all consumers migrated |
| Q2: Remove/relocate `realtimeEpochSeconds()`? | **Keep as-is** | No action needed |
| Q3: Unify `Kernel.Clock.*` and `Clock.*`? | **Status quo** | No action needed |
| Q4: Rename/move `Kernel.Time.Deadline`? | **Keep as-is** | Optional bridge deferred |
| Q5: Rename `Kernel.Time`? | **Keep as-is** | No action needed |
| Q6: Platform completeness? | **Complete for supported platforms** | WASI/OpenBSD deferred |

## Cross-References

| Package | Affected Files | Status |
|---------|---------------|--------|
| swift-iso-9945 | `Sources/ISO 9945 Kernel/ISO 9945.Kernel.Time.swift` | `monotonicNanoseconds()` deleted |
| swift-iso-9945 | `Sources/ISO 9945 Kernel/ISO 9945.Kernel.Clock.swift` | No changes — canonical implementation |
| swift-windows (in swift-foundations) | `Tests/Windows Kernel Tests/Windows.Kernel.Glob Tests.swift:117` | Migrated to `Kernel.Clock.Continuous.now()` |
| swift-io (in swift-foundations) | `Tests/IO Completions Tests/IO.Completion.Driver.Fake.swift` | Replaced private reimpl with `Kernel.Clock.Continuous.now()` |
| swift-tests (in swift-foundations) | `Sources/Tests Performance/Test.Trait.Scope.Provider.timed.swift:202` | No changes — uses `realtimeEpochSeconds()` |
| swift-kernel-primitives | `Sources/Kernel Time Primitives/Kernel.Time.Deadline.swift` | No changes |
| swift-clock-primitives | `Sources/Clock Primitives/Clock.Continuous.swift` | No changes |

## Typed-Return Revisit (2026-04-18)

**Status of prior decisions**: Q1, Q2, Q4, Q5, Q6 unchanged. Q3's
*Option 1 status-quo* conclusion is **revised** — Option 4 (typed return
at the kernel boundary) is adopted, with the rejection reasoning
corrected below. Namespace unification between `Clock.*` and
`Kernel.Clock.*` remains out of scope; the two stacks still coexist.

### Correction to the 2026-03-19 Q3 Option 4 rejection

Q3 Option 4 was rejected on the stated grounds that a kernel-primitives
→ clock-primitives dep would be a "lateral L1 dependency." This framing
is factually incorrect on two counts:

1. **Tier reality** (per `swift-primitives/Documentation.docc/Primitives Tiers.md:45–68, 169–171`):
   `swift-clock-primitives` is tier 0 (leaf; depends only on
   identity-primitives, standard-library-extensions, witness-primitives).
   `swift-kernel-primitives` is tier 17. A dep from tier 17 → tier 0 is
   **downward**, which is exactly the shape the tier DAG rule
   `tier(P) = max(tier(dep)) + 1` requires. It is not lateral in any
   meaningful sense.
2. **The dep already exists, and is already used**. The package-level
   dep `swift-kernel-primitives → swift-clock-primitives` was added in
   commit `fa34f43` on **2026-03-03** — 16 days before the Q3 decision.
   It is consumed at the target level by Kernel File Primitives:
   `Sources/Kernel File Primitives/Kernel.Lock.Acquire.swift:14` imports
   `Clock_Primitives`, and `Kernel.Lock.Acquire.deadline(Clock.Continuous.Instant)`
   (same file, line 28) already uses the tagged instant type inside
   swift-kernel-primitives. The "structural" argument against using
   `Clock.Continuous.Instant` from within kernel-primitives has therefore
   been moot since 2026-03-03.

The real question Q3 Option 4 should have asked is *whether the typed
coupling is semantically desired*. Under this investigation the answer
is yes — see **Rationale** below.

### Candidates evaluated

Four return-type candidates were considered. Winner marked **✅**;
rejected candidates carry the reason tied to the stated trigger
(unit-confusion class of bug per `[IMPL-002]`/`[IMPL-006]`, and the
cross-clock-swap bug class from Q1's original trigger).

| # | Candidate | Verdict | Reason |
|---|-----------|:-------:|--------|
| 1 | `Clock.Nanoseconds` (untagged, L1 tier 0) | ❌ | Provides typed *storage* but **not cross-clock distinction** — `Kernel.Clock.Continuous.now()` and `Kernel.Clock.Suspending.now()` would still return the same type, leaving the Q1-class swap bug reachable through the type system. |
| 2 | `Swift.Duration` (stdlib) | ❌ | `Duration` is a delta type, not an instant. Swift stdlib separates `InstantProtocol` from `DurationProtocol` by design; using `Duration` for absolute time conflates them. Also: 128-bit attosecond internals add per-syscall decomposition cost for a ns-resolution hardware source. |
| 3 | New `Kernel.Time.Nanoseconds` (duplicate of `Clock.Nanoseconds`, inside kernel-primitives) | ❌ | Same storage, same arithmetic, same semantic as existing `Clock.Nanoseconds`. L2 bridge sites would one-to-one convert between identical types — pure ceremony. Violates existing-infrastructure principle when `Clock.Nanoseconds` already exists at L1 tier 0. |
| 4 | Keep `UInt64` at kernel boundary, typed accessor at L2 only | ❌ | Does not address the problem. The kernel-internal consumers (`Kernel.Time.Deadline`, epoll/kqueue poll loops) still operate on raw `UInt64`; the cross-clock-swap bug is reachable at every UInt64 boundary inside and across L2. Preserves the very class of bug the typed-return change is meant to eliminate. |
| 5 | **`Tagged<ClockTag, Clock.Nanoseconds>` — return the existing `Clock.{Continuous,Suspending}.Instant`** | ✅ | See below. |

### Decision

| API | Return type |
|-----|-------------|
| `Kernel.Clock.Continuous.now()` | `Clock.Continuous.Instant` (existing L1 typealias = `Tagged<Clock.Continuous, Clock.Nanoseconds>`) |
| `Kernel.Clock.Suspending.now()` | `Clock.Suspending.Instant` (existing L1 typealias) |
| `Kernel.Clock.CPU.Process.now()` | `Kernel.Clock.CPU.Process.Instant` (new L2 typealias = `Tagged<Kernel.Clock.CPU.Process, Clock.Nanoseconds>`) — declared in swift-iso-9945 next to the `now()` impl, since `Kernel.Clock.CPU.Process` is POSIX-only |

The `Kernel.Clock.*.now()` functions *are* the typed accessor —
Q3 Option 4's "bridge" collapses into the existing method rather than
being added alongside it. This is a stronger move than Option 4 as
originally framed: the kernel clock's native return type becomes the
typed instant, and the L2 `Clock.X.now` bridge
(`Instant(nanoseconds: Kernel.Clock.X.now())`) simplifies to a
pass-through (`Kernel.Clock.X.now()`).

### Rationale

1. **Cross-clock type safety** — `Clock.Continuous.Instant` and
   `Clock.Suspending.Instant` are phantom-tagged by their Clock struct
   (see `swift-clock-primitives/Sources/Clock Primitives/Clock.Continuous.swift:41`,
   `Clock.Suspending.swift:41`). Mixing them is a compile error. This
   is exactly the type-level guard missing at the time of the Q1
   5.5-second drift bug.
2. **Zero duplication** — `Clock.Nanoseconds` is documented (same file,
   lines 14–19) as the "Base storage type for hardware clocks
   (Continuous, Suspending)." The change puts that type to the use it
   was designed for.
3. **Bridge collapse** — both the POSIX bridge
   (`swift-iso-9945/Sources/ISO 9945 Kernel Clock/ISO 9945.Clock.Continuous.swift:24–26, 61–63`)
   and the Windows bridge
   (`swift-microsoft/swift-windows-standard/Sources/Windows Kernel Clock Standard/Windows.Clock.Continuous.swift:21–23, 46–48`)
   lose the `Instant(nanoseconds:)` wrap. One fewer layer of indirection
   at the exact spot the two stacks meet.
4. **Zero runtime cost** — `Tagged` + `Clock.Nanoseconds` are both
   one-UInt64-field, `@inlinable`-callable structs. Optimized builds
   erase to the same `UInt64` the current API returns. No per-call
   overhead.
5. **Arithmetic already supported** —
   `swift-clock-primitives/Sources/Clock Primitives/Tagged+InstantProtocol.swift`
   provides `+(Instant, Duration)`, `-(Instant, Duration)`,
   `-(Instant, Instant) -> Duration`, `<`, `advanced(by:)`,
   `duration(to:)` on every `Tagged<X, Clock.Nanoseconds>`. The sleep
   loop's `while now() < target` keeps working; `cpuAfter - cpuBefore`
   keeps working (now yielding `Duration` instead of `UInt64`, which is
   the correct delta type).
6. **Precedent inside kernel-primitives** —
   `Kernel.Lock.Acquire.deadline(Clock.Continuous.Instant)`
   (`swift-kernel-primitives/Sources/Kernel File Primitives/Kernel.Lock.Acquire.swift:28`)
   is already the established shape. Extending it to `Kernel.Clock.now()`
   is consistency, not novelty.

### Impact catalog

**Three syscall impl sites** — return type changes from `UInt64` to
the tagged Instant; bodies wrap the computed nanosecond count once at
the return statement:

| File | Lines | Clock |
|------|-------|-------|
| `swift-iso-9945/Sources/ISO 9945 Kernel Clock/ISO 9945.Kernel.Clock.swift` | 31, 52 | Continuous + Suspending |
| `swift-iso-9945/Sources/ISO 9945 Kernel Clock/ISO 9945.Kernel.Clock.CPU.Process.swift` | 52 | CPU.Process |
| `swift-microsoft/swift-windows-standard/Sources/Windows Kernel Clock Standard/Windows.Kernel.Clock.swift` | 23, 48 | Continuous + Suspending |

**Two bridge sites** — `Instant(nanoseconds: Kernel.Clock.X.now())`
collapses to `Kernel.Clock.X.now()`; sleep-loop comparisons switch from
`< target: UInt64` to `< deadline: Instant`:

| File | Lines |
|------|-------|
| `swift-iso-9945/Sources/ISO 9945 Kernel Clock/ISO 9945.Clock.Continuous.swift` | 24, 40, 61, 77 |
| `swift-microsoft/swift-windows-standard/Sources/Windows Kernel Clock Standard/Windows.Clock.Continuous.swift` | 22, 32, 47, 57 |

**Package.swift edit** — add `Clock Primitives` to the target's
dependency list (package-level dep already exists):

- `swift-kernel-primitives/Package.swift` line 152–157 (`Kernel Clock Primitives` target): add `.product(name: "Clock Primitives", package: "swift-clock-primitives")`.
- `swift-kernel-primitives/Package.swift` line 232–237 (`Kernel Time Primitives` target): add the same dep. **Required**, not optional — the Deadline public API is rewritten to take `Clock.Continuous.Instant` (see below).

**New L2 typealias** — one new declaration next to `Kernel.Clock.CPU.Process`:

```swift
// swift-iso-9945/Sources/ISO 9945 Kernel Clock/ISO 9945.Kernel.Clock.CPU.Process.swift
extension Kernel.Clock.CPU.Process {
    public typealias Instant = Tagged<Kernel.Clock.CPU.Process, Clock.Nanoseconds>
}
```

**`Kernel.Time.Deadline` public API rewrite** — per `[IMPL-002]` /
`[IMPL-006]` (intent-over-mechanism, compiler-enforced strictness),
the typed instant is the *only* boundary type on the public surface.
Raw integers are dropped; `Swift.Duration` subsumes `Int64`
nanosecond/millisecond offsets.

```swift
// Removed
public let nanoseconds: UInt64
public init(nanoseconds: UInt64)
public static func now(monotonicNanoseconds: UInt64) -> Deadline
public static func after(nanoseconds: Int64, from monotonicNanoseconds: UInt64) -> Deadline
public static func after(milliseconds: Int64, from monotonicNanoseconds: UInt64) -> Deadline
public func hasExpired(at monotonicNanoseconds: UInt64) -> Bool
public func remainingNanoseconds(at monotonicNanoseconds: UInt64) -> Int64
public func remaining(at monotonicNanoseconds: UInt64) -> Duration

// Replaced with
public let instant: Clock.Continuous.Instant
public init(_ instant: Clock.Continuous.Instant)
public static func now(at instant: Clock.Continuous.Instant) -> Deadline
public static func after(_ duration: Duration, from instant: Clock.Continuous.Instant) -> Deadline
public func hasExpired(at instant: Clock.Continuous.Instant) -> Bool
public func remaining(at instant: Clock.Continuous.Instant) -> Duration

// Preserved
public static var never: Deadline
// Comparable, Sendable, Hashable conformances
```

Drops rationale:
- `remainingNanoseconds(at:) -> Int64` — raw-integer return is a
  mechanism leak; callers needing ns decompose `Duration.components`.
- `after(milliseconds:)` — `Duration.milliseconds(100)` covers the use
  case without a dedicated factory.

Storage: store `Clock.Continuous.Instant` directly. Tagged erases to
UInt64 under `@inlinable`, so codegen is identical to the current
UInt64 storage. This keeps the mechanism (nanoseconds) hidden behind
the typed surface.

**Implicit design decision baked in**: `Kernel.Time.Deadline` is now
compile-time continuous-clock-typed. Passing a
`Clock.Suspending.Instant` to `hasExpired(at:)` is a type error. The
Q1 5.5-second drift bug class cannot recur across the Deadline
boundary. Renaming the type to `Kernel.Clock.Continuous.Deadline` for
explicit namespacing is a separate mechanical pass — kept out of
scope here.

**Consumers to migrate**:

| Consumer | Current | After |
|----------|---------|-------|
| `swift-foundations/swift-kernel/Sources/Kernel Event/Kernel.Event.Source+Epoll.swift:220` | `deadline.remaining(at: Kernel.Clock.Continuous.now())` — UInt64 boundary | `deadline.remaining(at: Kernel.Clock.Continuous.now())` — typed through (same call, types line up) |
| `swift-foundations/swift-kernel/Sources/Kernel Event/Kernel.Event.Source+Kqueue.swift:179` | same | same |
| `swift-foundations/swift-sockets/Tests/Sockets Tests/Sockets.TCP.Listener.Tests.BlockingIdleCPU.swift:96, 98, 100` | `let cpuDelta = cpuAfter - cpuBefore` → `UInt64` (ns) | Unchanged call site; `cpuDelta` is now `Duration`. Update the downstream threshold comparison from raw ns to `.milliseconds(...)`. |
| `swift-foundations/swift-windows/Tests/Windows Kernel Tests/Windows.Kernel.Glob Tests.swift:119` | `let nanos = Kernel.Clock.Continuous.now()` (UInt64, interpolated into dir name) | `let nanos = Kernel.Clock.Continuous.now().nanoseconds` — the UInt64 accessor comes from `Tagged+Clock.Nanoseconds.nanoseconds` (`swift-clock-primitives/Sources/Clock Primitives/Tagged+Clock.Nanoseconds.swift:15`). |
| Any direct constructor call of `Kernel.Time.Deadline.init(nanoseconds:)`, `.now(monotonicNanoseconds:)`, `.after(nanoseconds:from:)`, `.after(milliseconds:from:)`, or `.remainingNanoseconds(at:)` | raw-integer API | Rewrite to the typed equivalents. `.remainingNanoseconds(at:)` callers switch to `.remaining(at:).components` when raw ns are genuinely needed. |

### Complete fallout inventory (Institute ecosystem, excl. `/coenttb/`)

Verified 2026-04-18 via workspace grep. The
`swift-foundations/swift-io/Research/ecosystem-refactor-opportunities.md:110`
"28 files" figure counts every reference including type-parameter
mentions; the actual API-migration surface is much smaller.

**A. Type-definition rewrites (swift-kernel-primitives)** — 2 files:

- `Sources/Kernel Time Primitives/Kernel.Time.Deadline.swift` — full
  public API rewrite per the table above. Add
  `public import Clock_Primitives` at top (`InternalImportsByDefault`
  is on).
- `Sources/Kernel Time Primitives/Kernel.Time.Deadline.Next.swift` —
  `.value: Kernel.Time.Deadline?` reconstruction updates to
  `Deadline(Clock.Continuous.Instant(nanoseconds: ns))`. Internal
  atomic storage stays `Atomic<UInt64>` (implementation detail). The
  public `.store(_ UInt64)` / `.nanoseconds: UInt64` getters have
  **zero external consumers** in the Institute ecosystem (only the
  self-referential doc example in the same file); recommendation is to
  rewrite them to `.store(_ Kernel.Time.Deadline)` / `.value: Deadline?`,
  keeping the sentinel (`UInt64.max` ↔ `nil`) internal.

**B. Syscall impl sites** — 3 files (return-type flip from UInt64 to
tagged Instant; bodies wrap the computed ns once at the return):

- `swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel Clock/ISO 9945.Kernel.Clock.swift` — lines 31, 52.
- `swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel Clock/ISO 9945.Kernel.Clock.CPU.Process.swift` — line 52. Add `public typealias Instant = Tagged<Kernel.Clock.CPU.Process, Clock.Nanoseconds>` in the same file.
- `swift-microsoft/swift-windows-standard/Sources/Windows Kernel Clock Standard/Windows.Kernel.Clock.swift` — lines 23, 48.

**C. Bridge collapses** — 2 files:

- `swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel Clock/ISO 9945.Clock.Continuous.swift` — 4 edits (lines 24–26, 39–40, 61–63, 76–77). `Instant(nanoseconds: Kernel.Clock.X.now())` → `Kernel.Clock.X.now()`. Sleep-loop `while Kernel.Clock.X.now() < target: UInt64` → `while Kernel.Clock.X.now() < deadline: Instant` (remove the `let target = deadline.nanoseconds` line).
- `swift-microsoft/swift-windows-standard/Sources/Windows Kernel Clock Standard/Windows.Clock.Continuous.swift` — same shape, 4 edits.

**D. External callers of `Kernel.Clock.*.now()`** — 4 files (all in
swift-foundations):

| # | Consumer | Current | After |
|---|----------|---------|-------|
| D1 | `swift-foundations/swift-kernel/Sources/Kernel Event/Kernel.Event.Source+Epoll.swift:220` | `deadline.remaining(at: Kernel.Clock.Continuous.now())` — UInt64 boundary | Same call site — types line up cleanly under the new typed Deadline API. No textual change. |
| D2 | `swift-foundations/swift-kernel/Sources/Kernel Event/Kernel.Event.Source+Kqueue.swift:179` | same | same |
| D3 | `swift-foundations/swift-sockets/Tests/Sockets Tests/Sockets.TCP.Listener.Tests.BlockingIdleCPU.swift:96, 98` | `let cpuDelta = cpuAfter - cpuBefore` yields `UInt64` ns | Unchanged call site; `cpuDelta` is now `Duration`. Threshold comparison downstream changes from raw ns to `.milliseconds(...)`. |
| D4 | `swift-foundations/swift-windows/Tests/Windows Kernel Tests/Windows.Kernel.Glob Tests.swift:119` | `let nanos = Kernel.Clock.Continuous.now()` (UInt64, interpolated into dir name) | `let nanos = Kernel.Clock.Continuous.now().nanoseconds` — accessor from `Tagged+Clock.Nanoseconds.nanoseconds` (`swift-clock-primitives/Sources/Clock Primitives/Tagged+Clock.Nanoseconds.swift:15`). |

**E. `Kernel.Time.Deadline` public-API consumers** — **0 files** outside
the two definition files above. Grep for `.after(`, `.now(monotonicNanoseconds:)`,
`Deadline(nanoseconds:)`, `.hasExpired(`, `.remainingNanoseconds(`
across the Institute ecosystem returns only self-references inside
`Kernel.Time.Deadline.swift` itself. The only **external** call of any
Deadline method is `.remaining(at:)` at D1 and D2 above — and those
migrations are textually trivial under the typed API.

**F. Files that `reference Kernel.Time.Deadline` as a parameter or field
type** (UNAFFECTED — type name unchanged):

- `swift-primitives/swift-kernel-primitives/Sources/Kernel Event Primitives/Kernel.Event.Source.swift:69`
- `swift-primitives/swift-kernel-primitives/Sources/Kernel Event Primitives/Kernel.Event.Driver.swift:61, 72, 96, 171`
- `swift-primitives/swift-executor-primitives/Sources/Executor Wait Event Source Primitives/Executor.Wait.Event.Source.swift:58`
- `swift-foundations/swift-kernel/Sources/Kernel Event/Kernel.Event.Source+Epoll.swift:218` (lambda param)
- `swift-foundations/swift-kernel/Sources/Kernel Event/Kernel.Event.Source+Kqueue.swift:177` (lambda param)
- `swift-foundations/swift-io/Tests/IO Events Tests/IO.Event.Fake.swift:42` (lambda param)

All 6 files keep the `Kernel.Time.Deadline?` type reference untouched —
it's the construction/accessor API that changes, not the type name.

**G. Package.swift dep edits** — 1 file:

- `swift-primitives/swift-kernel-primitives/Package.swift` lines
  232–237 (`Kernel Time Primitives` target) — add
  `.product(name: "Clock Primitives", package: "swift-clock-primitives")`.
  Package-level dep already exists (line 127). `Kernel Clock Primitives`
  target is **not** touched — its L1 namespaces stay pure empty enums;
  Clock.Nanoseconds enters the picture only at L2 impl sites where
  their targets already depend on Clock Primitives
  (`swift-iso-9945/Package.swift:290`,
  `swift-windows-standard/Package.swift:127`).

**H. Doc-comment updates** — within files already listed in A–D; no
additional files. Update the Usage examples in Deadline.swift (`let
deadline = Kernel.Time.Deadline.after(milliseconds: 100, from: now)`
→ `let deadline = Kernel.Time.Deadline.after(.milliseconds(100), from: .now)`
or similar) and the `let nanos = Kernel.Clock.Continuous.now()` line
in `Kernel.Clock.swift:29`.

**I. Research / memory updates**:

- `swift-clock-primitives/Research/clock-time-unification.md` — this
  document (add section).
- `swift-foundations/swift-io/Research/ecosystem-refactor-opportunities.md:101–110`
  (A4 "Kernel.Time.Deadline" deferred → RESOLVED with link to this
  revisit).
- Memory `project_clock_primitives_typed_time_revisit.md` — mark Phase 1
  complete once landed; retain a separate deferred item for the
  clock-tagged-Deadline rename (future Phase 2).

### Blast radius summary

| Category | File count | Repos |
|----------|:---:|-------|
| Source rewrites (A) | 2 | swift-primitives |
| Impl sites (B) | 3 | swift-iso, swift-microsoft |
| Bridges (C) | 2 | swift-iso, swift-microsoft |
| Consumer migrations (D) | 4 | swift-foundations |
| Unaffected type-references (F) | 6 | swift-primitives, swift-foundations |
| Package.swift (G) | 1 | swift-primitives |
| Research + memory (I) | 2 docs + 1 memory | swift-primitives, swift-foundations |
| **Total source touches** | **11** | **4 repos** |

Zero consumers outside the enumerated list (no Experiments, no Blog,
no legal-domain packages, no `/coenttb/` paths).

### Deliberate out-of-scope narrowings

1. **Renaming `Kernel.Time.Deadline` → `Kernel.Clock.Continuous.Deadline`** —
   the typed signature already enforces continuous-clock semantics;
   the rename makes the namespace explicit. Mechanical pass, deferred.
2. **Promoting `Kernel.Clock.CPU` / `Kernel.Clock.CPU.Process` to L1** —
   not done. CPU.Process is POSIX-only today (no Windows
   implementation); pulling the namespace up to L1 would create a
   cross-platform empty shell that can't be called on Windows. Keep the
   empty-enum declarations and the `Instant` typealias at L2 alongside
   the `now()` impl. Reconsider *only* if/when Windows gets a
   `GetProcessTimes`-based implementation.
3. **Windows `Kernel.Clock.CPU.Process` impl via `GetProcessTimes`** —
   separate task.
4. **Q3 namespace unification** (`Clock.*` ≡ `Kernel.Clock.*`) — still
   rejected for the structural reasons Q3 cited (Options 2 and 3
   remain correctly refused: L1 can't hold `_Concurrency.Clock`
   conformance; empty enums can't hold struct fields). The two stacks
   remain distinct.

### Phasing

Phase 1 (this investigation, land as a coordinated set across 4 repos):

1. **swift-primitives** (foundational, lands first):
   a. `Package.swift` — add `Clock Primitives` dep to `Kernel Time Primitives` target.
   b. Rewrite `Kernel.Time.Deadline.swift` public API per the table.
   c. Update `Kernel.Time.Deadline.Next.swift` — rewrite `.value`
      reconstruction; convert `.store(_:)` / `.nanoseconds` to typed
      surface (no external callers, safe to change shape).
   d. Add `public import Clock_Primitives` at top of the two files.
   e. Update doc examples in `Kernel.Clock.swift` (L1 namespace).
2. **swift-iso-9945** (POSIX impl sites + bridge):
   a. Change return types in `ISO 9945.Kernel.Clock.swift` (Continuous + Suspending) and `ISO 9945.Kernel.Clock.CPU.Process.swift`.
   b. Add `Kernel.Clock.CPU.Process.Instant` typealias.
   c. Collapse `ISO 9945.Clock.Continuous.swift` bridges + sleep loops.
3. **swift-windows-standard** (Windows impl sites + bridge) —
   coordinate with the parallel agent before touching
   `Windows.Kernel.Clock.swift`; the Clock target is already split
   out so collision risk is low.
4. **swift-foundations** (consumers):
   a. epoll/kqueue — compile check; no text change expected.
   b. sockets CPU test — adjust threshold expression from ns to
      `Duration`.
   c. windows glob test — add `.nanoseconds` on the interpolation.
5. **Research / memory sweep**:
   a. Resolve A4 in `ecosystem-refactor-opportunities.md`.
   b. Update memory `project_clock_primitives_typed_time_revisit.md`.

Phase 2 (deferred, separate investigations):

- Rename `Kernel.Time.Deadline` → `Kernel.Clock.Continuous.Deadline`
  (mechanical namespace move; the type is already continuous-typed
  at the API surface after Phase 1).
- Windows `Kernel.Clock.CPU.Process.now()` via `GetProcessTimes`.
- Promote `Kernel.Clock.CPU` namespace to L1 when cross-platform
  coverage exists.

### Updated Decision Summary row

| Question | Revised Decision | Status |
|----------|------------------|--------|
| Q3 (revised): Typed return at the kernel boundary? | **Adopt Option 4 (folded into `now()`)** — return `Clock.Continuous.Instant` / `Clock.Suspending.Instant` / `Kernel.Clock.CPU.Process.Instant`. | 2026-04-18 decision; implementation pending Phase 1. Q3's Option 1 "status quo" conclusion is superseded **only on the typed-return axis** — namespace unification remains rejected. |
