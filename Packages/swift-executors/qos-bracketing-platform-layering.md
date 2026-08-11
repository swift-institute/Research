# QoS Bracketing Platform Layering

<!--
---
version: 2.4.0
last_updated: 2026-04-29
status: RECOMMENDATION
tier: 2
---
-->

## Context

`priority-escalation-policy.md` v0.7.0 (DECISION, 2026-04-29) locked
the M3 mechanism — thread QoS bracketing — and delegated the
implementation layering to this document. v1.0.0 of this doc was
Darwin-only with Linux/Windows treated as no-op; the principal
directive on 2026-04-29 ("All our packages MUST support darwin,
linux, windows equally") plus the in-flight factoring of
swift-kernel-primitives invalidated v1.0.0's placements.

This v2.0.0 rewrite:

1. Treats all three platforms as equal first-class consumers.
2. Places the abstract typed Priority enum at the L3-unifier
   (`swift-kernel`) rather than at any L1 primitives package — the
   kernel-primitives factoring removes that home; consumer-domain L1
   would create cross-domain L3-policy → executor-primitives deps.
3. Defines per-platform native typed Priority taxonomies at L2
   (one per platform).
4. Defines per-platform L3-policy bracketing wrappers (one per
   platform), each consuming its native typed Priority — no cross-
   platform leak in L3-policy public API.
5. Names Linux's asymmetric semantics honestly: lowering succeeds
   unprivileged; upward bracketing silently no-ops without
   `CAP_SYS_NICE`. The flag is documented as best-effort, not no-op.
6. Cites the platform skill rules ([PLAT-ARCH-005], [PLAT-ARCH-008c],
   [PLAT-ARCH-008e], [PLAT-ARCH-008h], [PLAT-ARCH-015]) governing
   each placement.

## Question

Where in the platform stack does each piece of the M3 implementation
live, given (a) all three platforms must be supported equally, and
(b) swift-kernel-primitives is being factored out so its functionality
is absorbed by non-kernel primitives or L2 packages?

Six concrete sub-questions:

1. **Abstract typed Priority enum.** Where does the cross-platform
   QoS taxonomy live, given kernel-primitives is going away?
2. **Per-platform native typed Priority taxonomies.** Each platform's
   native vocabulary (Darwin's QoS classes, Linux's nice values,
   Windows's THREAD_PRIORITY_*) — where?
3. **Per-platform L3-policy bracketing wrappers.** Where are the
   `~Copyable` save-restore types?
4. **L3-unifier API.** What does `Kernel.Thread.Priority.Override`
   look like, and how does it dispatch?
5. **Linux semantics.** What is the honest contract given Linux has
   no unprivileged upward priority primitive?
6. **`PriorityOverride.swift` rename.** What replaces the
   compound-named, type-less file in swift-executors?

## Constraints

| Constraint | Source | Implication |
|------------|--------|-------------|
| All three platforms supported equally | Principal directive 2026-04-29 | No platform may be no-op; each gets a real L3-policy wrapper |
| swift-kernel-primitives is being factored out | Principal directive 2026-04-29 | Abstract Priority enum cannot live there |
| L3-policy → L3-unifier composition forbidden (upward) | [PLAT-ARCH-008h] composition matrix | Abstract Priority cannot live at L3-unifier swift-kernel if L3-policy needs to reference it |
| L3-policy → L1 (any L1) is permitted (downward) | [ARCH-LAYER-001] | An L1 home is permitted but creates cross-domain coupling if from a non-platform L1 |
| Per-L2 platform-native typed values is the canonical pattern for divergent reps | [PLAT-ARCH-015] | Native Priority taxonomies live at L2 |
| L3-unifier composes L3-policy | [PLAT-ARCH-008e] | L3-unifier's bracketing API delegates per-platform |
| No C types in public API | [PLAT-ARCH-005a] | Per-platform L3-policy must take typed Priority, not raw `qos_class_t`/`Int32` |
| L1 primitives unconditionally platform-agnostic | [PLAT-ARCH-008c] | Any L1 home (if used) must be uniform-shape, no `#if os(...)` |
| Darwin: `pthread_override_qos_class_*_np` unprivileged, nestable, ~853 ns/cycle | spike validation 2026-04-16 (`priority-escalation-policy.md`) | Real wrapper |
| Linux: only `setpriority(2)` is unprivileged for own thread, lowering only (`[0, 19]` on systemd default) | sched(7), getrlimit(2) | Best-effort, asymmetric |
| Windows: `SetThreadPriority` unprivileged for calling-process threads | processthreadsapi.h | Real wrapper, save/restore |
| Linux autogroup scopes nice to per-session CPU share | sched(7) | Document; do not fight |

## Analysis

### Sub-question 1: Abstract typed Priority enum location

| Option | Layer/Package | Disposition |
|--------|---------------|-------------|
| A. swift-kernel-primitives (L1) | L1 platform-stack | **Eliminated** — being factored out |
| B. swift-executor-primitives (L1) | L1 executor-domain | Cross-domain L3-policy → executor-primitives deps if L3-policy consumed it directly |
| C. New swift-thread-primitives (L1) | L1 platform-stack | New package; user said "absorbed by ACTUAL non-kernel primitives, or L2" — leans against new packages |
| D. swift-kernel (L3-unifier) | L3 platform-stack | Per-platform L3-policy doesn't reference it; L3-unifier hosts the abstraction; per-platform L3-policy uses its own native typed taxonomy |
| E. Per-L2 with no abstract enum at all | L2 only | Three identical-cases enums; consumer (swift-executors) picks one or the L3-unifier provides typealias |

**Recommend D.** The L3-unifier is the only layer that needs a
cross-platform abstract enum, because:

- L3-policy packages (`swift-darwin`, `swift-linux`, `swift-windows`)
  consume their own L2's native typed Priority — they don't need the
  abstract enum.
- L3-domain (swift-executors) consumes the L3-unifier's
  `Kernel.Thread.Priority.Override(_ priority: Kernel.Thread.Priority)`
  signature — that's where the abstract enum surfaces.
- The L3-unifier owns the cross-platform → per-platform mapping
  internally.

This avoids:
- The kernel-primitives placement (going away).
- Cross-domain L3-policy → executor-primitives deps (Option B's
  awkwardness).
- A new L1 package (Option C, against the user's factoring direction).
- Three identical enums (Option E's redundancy).

The shape:

```swift
// swift-kernel/Sources/Kernel Thread/Kernel.Thread.Priority.swift
extension Kernel.Thread {
    public enum Priority: UInt8, Sendable, Hashable, Comparable {
        case unspecified     = 0x00
        case background      = 0x09
        case utility         = 0x11
        case `default`       = 0x15
        case userInitiated   = 0x19
        case userInteractive = 0x21
    }
}

extension Kernel.Thread.Priority {
    /// Bridge from the stdlib's `UnownedJob.priority`. Lives in
    /// swift-executors as an extension since UnownedJob is the
    /// stdlib's executor-job type; we don't pull executor concepts
    /// up into swift-kernel.
}
```

Raw values mirror Darwin's `qos_class_t` numerically so the
L3-unifier's Darwin branch does a 1:1 cast; on Linux/Windows the
mapping happens via per-platform conversion functions (see
sub-question 4).

### Sub-question 2: Per-platform native typed Priority taxonomies

Per [PLAT-ARCH-015], per-L2 native typed values are the canonical
pattern when raw representations differ. Each platform's L2 hosts its
own typed taxonomy.

**Darwin** (`swift-darwin-standard/Sources/Darwin Kernel Standard/Darwin.Kernel.Thread.Priority.swift`):

```swift
extension Darwin.Kernel.Thread {
    public enum Priority: UInt32, Sendable, Hashable {
        case unspecified     = 0x00  // QOS_CLASS_UNSPECIFIED
        case background      = 0x09  // QOS_CLASS_BACKGROUND
        case utility         = 0x11  // QOS_CLASS_UTILITY
        case `default`       = 0x15  // QOS_CLASS_DEFAULT
        case userInitiated   = 0x19  // QOS_CLASS_USER_INITIATED
        case userInteractive = 0x21  // QOS_CLASS_USER_INTERACTIVE
    }
}
```

UInt32 raw matches `qos_class_t` 1:1 per [PLAT-ARCH-015] (Swift stdlib
type matching the C typedef width without leaking the typedef).

**Linux** (`swift-linux-standard/Sources/Linux Kernel System Standard/Linux.Kernel.Thread.Priority.swift`):

```swift
extension Linux.Kernel.Thread {
    /// POSIX nice value. Range: [-20, 19] on Linux. Higher = lower
    /// priority. Per sched(7), only SCHED_OTHER changes are
    /// unprivileged.
    public struct Priority: Sendable, Hashable, RawRepresentable {
        public let rawValue: Int32

        @inlinable
        public init(rawValue: Int32) { self.rawValue = rawValue }
    }
}

// Static instances live in an extension per [API-IMPL-008]
// (type body holds only stored properties + canonical init).
extension Linux.Kernel.Thread.Priority {
    public static let userInteractive: Self = .init(rawValue: -10)
    public static let userInitiated: Self   = .init(rawValue:  -5)
    public static let `default`: Self       = .init(rawValue:   0)
    public static let utility: Self         = .init(rawValue:  10)
    public static let background: Self      = .init(rawValue:  19)
}
```

Struct (not enum) because nice is a continuous Int32 range, not a
fixed set of cases. Static instances name the abstract levels but
arbitrary nice values remain expressible. Static members in an
extension per [API-IMPL-008].

**Windows** (`swift-windows-standard/Sources/Windows Kernel Thread Standard/Windows.Kernel.Thread.Priority.swift`):

```swift
extension Windows.Kernel.Thread {
    public enum Priority: Int32, Sendable, Hashable {
        case idle           = -15  // THREAD_PRIORITY_IDLE
        case lowest         =  -2  // THREAD_PRIORITY_LOWEST
        case belowNormal    =  -1  // THREAD_PRIORITY_BELOW_NORMAL
        case normal         =   0  // THREAD_PRIORITY_NORMAL
        case aboveNormal    =   1  // THREAD_PRIORITY_ABOVE_NORMAL
        case highest        =   2  // THREAD_PRIORITY_HIGHEST
        case timeCritical   =  15  // THREAD_PRIORITY_TIME_CRITICAL
    }
}
```

Each L2 also defines its raw syscall bindings if not already present:
`pthread_override_qos_class_*_np` (Darwin), `gettid` (Linux —
already at `Linux.Kernel.Thread.ID.current`), `SetThreadPriority` /
`GetThreadPriority` / `GetCurrentThread` (Windows). `setpriority` /
`getpriority` are POSIX (per Option A in sub-question 5b) and live
exclusively in iso-9945; the Linux per-thread interpretation is
encoded inline at the L3-policy use site, not as a separate
linux-standard binding.

### Sub-question 3: Per-platform bracketing wrappers — L2 vs L3-policy split

Strict /platform compliance applies the principle that **L2 owns the
modern Swift API encoding of the platform spec; L3-policy adds further
policy on top.** What "modern Swift encoding" means depends on the
shape of the underlying C API:

- **Stateless atomic operations (Linux's `setpriority`, Windows's
  `SetThreadPriority`)**: modern encoding = typed atomic methods.
  Save/restore lifecycle is additional policy → lives at L3-policy.
- **Paired-token APIs (Darwin's `pthread_override_qos_class_start_np`
  / `_end_np`)**: modern encoding = `~Copyable` resource (init wraps
  start_np, deinit wraps end_np). The lifecycle is provided by the
  platform's API shape itself; no further L3 policy is needed →
  L3-policy is empty per [PLAT-ARCH-008e] empty-tier exception, and
  the L3-unifier composes Darwin L2 directly.

This creates a principled asymmetry:

| Platform | L2 (modern Swift encoding) | L3-policy (further policy) |
|---|---|---|
| Darwin | `Darwin.Kernel.Thread.Priority.Override : ~Copyable` (the natural Swift form of pthread's start/end token pair) | **Empty** (no policy beyond what L2 already provides) |
| Linux | typed `Priority` struct + `Linux.Kernel.Thread.ID` (existing); iso-9945 owns POSIX `setpriority`/`getpriority` per Option A | `Linux.Kernel.Thread.Priority.Override : ~Copyable` (save/restore lifecycle) |
| Windows | typed `Priority` enum + `Windows.Kernel.Thread.Handle` + atomic `Priority.{set,get}` typed methods | `Windows.Kernel.Thread.Priority.Override : ~Copyable` (save/restore lifecycle) |

**Darwin L2** (`swift-darwin-standard/Sources/Darwin Kernel Standard/Darwin.Kernel.Thread.Priority.Override.swift`):

```swift
extension Darwin.Kernel.Thread.Priority {
    @safe
    public struct Override: ~Copyable {
        @usableFromInline
        internal let _rawValue: pthread_override_t

        @inlinable
        public init(_ priority: Darwin.Kernel.Thread.Priority) {
            self._rawValue = unsafe pthread_override_qos_class_start_np(
                pthread_self(),
                qos_class_t(priority.rawValue),
                0
            )
        }

        @inlinable
        deinit {
            unsafe _ = pthread_override_qos_class_end_np(_rawValue)
        }
    }
}
```

True override semantics: nestable, deinit-ends, ~853 ns/cycle. The
`~Copyable` lifecycle IS the modern Swift encoding of pthread's
paired token API — no additional L3-policy needed.

**Darwin L3-policy**: empty for priority. Per [PLAT-ARCH-008e]
empty-tier exception, the L3-unifier composes Darwin L2 directly.

**Linux L3-policy** (`swift-linux/Sources/Linux Kernel Thread/Linux.Kernel.Thread.Priority.Override.swift`):

The dedicated `Linux Kernel Thread` subtarget already exists at
swift-linux post-refactor.

```swift
import ISO_9945_Kernel_Process            // ISO_9945.Kernel.Process.Priority.{set,get}
import Linux_Kernel_System_Standard       // Linux.Kernel.Thread.ID.current
                                          // Linux.Kernel.Thread.Priority (typed nice struct)

extension Linux.Kernel.Thread.Priority {
    /// Best-effort thread-priority bracketing.
    ///
    /// - Lowering nice (utility / background): always succeeds unprivileged.
    /// - Raising nice (userInitiated / userInteractive): silently no-ops
    ///   without `CAP_SYS_NICE` per sched(7).
    /// - Restoration on deinit: only attempted if construction succeeded.
    ///
    /// Linux semantic note: `PRIO_PROCESS` with a tid (from `gettid`)
    /// operates per-thread on Linux — a Linux extension to POSIX
    /// `setpriority` semantics. Per Option A (qos-bracketing-platform-
    /// layering.md sub-question 5b), the POSIX binding lives in iso-9945
    /// and the Linux per-thread interpretation is encoded inline here.
    @safe
    public struct Override: ~Copyable {
        @usableFromInline internal let _savedNice: Int32
        @usableFromInline internal let _applied: Bool

        @inlinable
        public init(_ priority: Linux.Kernel.Thread.Priority) {
            let tid = Linux.Kernel.Thread.ID.current
            var savedNice: Int32 = 0
            var applied: Bool = false
            do throws(ISO_9945.Kernel.Process.Priority.Error) {
                savedNice = try ISO_9945.Kernel.Process.Priority.get(
                    .process, tid.rawValue
                )
                try ISO_9945.Kernel.Process.Priority.set(
                    .process, tid.rawValue, priority.rawValue
                )
                applied = true
            } catch {
                // EPERM (no CAP_SYS_NICE) or other failure → best-effort
                // no-op. savedNice stays 0; applied stays false.
            }
            self._savedNice = savedNice
            self._applied = applied
        }

        @inlinable
        deinit {
            guard _applied else { return }
            do throws(ISO_9945.Kernel.Process.Priority.Error) {
                try ISO_9945.Kernel.Process.Priority.set(
                    .process,
                    Linux.Kernel.Thread.ID.current.rawValue,
                    _savedNice
                )
            } catch {
                // Restoration failed during deinit — no recovery
                // possible from this context. Best-effort cleanup;
                // failure implies something already broken (process
                // exiting, capability dropped). Per
                // `feedback_prefer_typed_throws_over_try_optional`,
                // explicit do/catch is required here over `try?`.
            }
        }
    }
}
```

Asymmetric contract documented inline. The wrapper compiles and runs
on every Linux deployment; the `_applied` flag records whether the
priority was actually changed, so deinit-restore matches. Typed
throws via iso-9945 per [API-ERR-001] / [API-ERR-004]. Explicit
do/catch in deinit per `feedback_prefer_typed_throws_over_try_optional`.

Autogroup behaviour (per sched(7), nice scoped to per-session CPU
share when autogroup is enabled, default on systemd) is documented in
the L3-unifier's docs but not branched on — there is no userspace
autogroup probe that's both reliable and unprivileged, and the nice
adjustment is meaningful even within the autogroup scope.

**Windows L2** (`swift-windows-standard/Sources/Windows Kernel Thread Standard/`):

L2 owns the modern Swift API encoding of the Windows thread API:
- `Windows.Kernel.Thread.Priority` — typed enum (shown in sub-question 2)
- `Windows.Kernel.Thread.Handle` — typed wrapper around `HANDLE`
  (`UInt`-shaped) with `.current` static returning the wrapping of
  `GetCurrentThread()`. Required per [PLAT-ARCH-005a] (no C types in
  public API).
- `Windows.Kernel.Thread.Priority.set(_:on:) throws(Error)` — typed
  atomic wrapper around `SetThreadPriority`, returning `Void` and
  throwing on `BOOL` failure with `GetLastError`-typed error.
- `Windows.Kernel.Thread.Priority.get(_:) throws(Error)` — typed
  atomic wrapper around `GetThreadPriority`.
- `Windows.Kernel.Thread.Priority.Error` — typed error enum mapping
  `GetLastError` codes (e.g., `.invalidHandle`, `.accessDenied`).

These are spec-literal in the modern-Swift sense: faithful encoding
of the Win32 API surface with typed throws, typed handles, and no C
typedef leakage.

**Windows L3-policy** (`swift-windows/Sources/Windows Kernel Thread/Windows.Kernel.Thread.Priority.Override.swift`):

L3-policy adds the **save/restore lifecycle policy** that the Win32
API does not natively express — capture the current priority on
construction, set the new priority, restore the captured value on
deinit. This is the "further policy" beyond what L2 modern encoding
provides.

The implementation step adds a new `Windows Kernel Thread` subtarget
at swift-windows for symmetry with the new `Linux Kernel Thread`
subtarget at swift-linux. (Pre-refactor, swift-windows had only
`Windows Kernel`, `Windows Kernel Descriptor`, `Windows System` — no
Thread subtarget yet.)

```swift
import Windows_Kernel_Thread_Standard   // Windows.Kernel.Thread.Priority.{set,get},
                                        // Windows.Kernel.Thread.Handle.current,
                                        // Windows.Kernel.Thread.Priority.Error

extension Windows.Kernel.Thread.Priority {
    @safe
    public struct Override: ~Copyable {
        @usableFromInline internal let _saved: Windows.Kernel.Thread.Priority
        @usableFromInline internal let _applied: Bool

        @inlinable
        public init(_ priority: Windows.Kernel.Thread.Priority) {
            var saved: Windows.Kernel.Thread.Priority = .normal
            var applied: Bool = false
            do throws(Windows.Kernel.Thread.Priority.Error) {
                saved = try Windows.Kernel.Thread.Priority.get(.current)
                try Windows.Kernel.Thread.Priority.set(priority, on: .current)
                applied = true
            } catch {
                // SetThreadPriority FALSE return → best-effort no-op.
            }
            self._saved = saved
            self._applied = applied
        }

        @inlinable
        deinit {
            guard _applied else { return }
            do throws(Windows.Kernel.Thread.Priority.Error) {
                try Windows.Kernel.Thread.Priority.set(_saved, on: .current)
            } catch {
                // Restoration failed; best-effort, see Linux Override
                // deinit comment.
            }
        }
    }
}
```

Where `.current` is `Windows.Kernel.Thread.Handle.current` — a
typed wrapper around `GetCurrentThread()` defined at L2 in
`Windows Kernel Thread Standard` alongside the priority bindings.

Symmetric save-restore. Set/Get within the calling-process priority
class is unprivileged. Typed throws per [API-ERR-001]. The L3-policy
Override adds the save/restore lifecycle that the underlying
`SetThreadPriority` API does not natively express.

### Sub-question 4: L3-unifier API

The L3-unifier (`swift-kernel`) provides:

- The abstract enum `Kernel.Thread.Priority` (sub-question 1).
- A cross-platform `Kernel.Thread.Priority.Override : ~Copyable` that
  takes the abstract enum and dispatches per platform.

```swift
// swift-kernel/Sources/Kernel Thread/Kernel.Thread.Priority.Override.swift
extension Kernel.Thread.Priority {
    @safe
    public struct Override: ~Copyable {
        #if canImport(Darwin)
        @usableFromInline internal let _native: Darwin.Kernel.Thread.Priority.Override
        #elseif os(Linux)
        @usableFromInline internal let _native: Linux.Kernel.Thread.Priority.Override
        #elseif os(Windows)
        @usableFromInline internal let _native: Windows.Kernel.Thread.Priority.Override
        #endif

        @inlinable
        public init(_ priority: Kernel.Thread.Priority) {
            #if canImport(Darwin)
            self._native = .init(priority._darwin)
            #elseif os(Linux)
            self._native = .init(priority._linux)
            #elseif os(Windows)
            self._native = .init(priority._windows)
            #endif
        }
        // No explicit deinit: when `_native` (a ~Copyable per-platform
        // Override) goes out of scope, its own deinit ends the
        // platform's bracketing automatically.
    }
}
```

The per-platform mapping helpers `priority._darwin`,
`priority._linux`, `priority._windows` are L3-unifier-internal
extensions on `Kernel.Thread.Priority`, defined in per-platform
conditional files (e.g., `Kernel.Thread.Priority+Darwin.swift`,
`Kernel.Thread.Priority+Linux.swift`, `Kernel.Thread.Priority+Windows.swift`).
Each returns the platform-native typed Priority. Symmetric pattern
across platforms — no force-unwrap required because the mapping
helpers handle the type conversion explicitly per [IMPL-002] (write
the math, not the mechanism).

**Why a wrapper struct rather than a typealias to the per-platform
Override?** A pure typealias would require constructing the L3-unifier
`Override` from a platform-specific Priority value (`Darwin.Kernel.Thread.Priority`
on Darwin, etc.), since the per-platform Override's init takes its
native typed Priority. Cross-platform consumers (swift-executors)
only have access to the abstract `Kernel.Thread.Priority`. The
abstract→native mapping has to live SOMEWHERE — and per
[PLAT-ARCH-008h]'s composition matrix, the per-platform L3-policy
packages (swift-darwin / swift-linux / swift-windows) MUST NOT depend
on the L3-unifier (swift-kernel). So a convenience init like
`Darwin.Kernel.Thread.Priority.Override.init(_ abstract: Kernel.Thread.Priority)`
defined in swift-darwin would be an upward L3-policy → L3-unifier
dependency, forbidden. The L3-unifier wrapper carries the conversion
in its own init, satisfying the matrix.

**Why no inner `_Backing` indirection?** Earlier sketches (v2.0.0–v2.2.0)
nested a `_Backing` struct inside `Override` to "encapsulate" the
platform-conditional `_native` field. That indirection added no
invariant, no separate concern — it was a wrapper around a single
field. Per [IMPL-086] (deletion-first structural fix) and [IMPL-087]
(does the component need to exist?), `_Backing` deleted cleanly:
`Override` holds `_native` directly with the same `#if` discrimination.

### Sub-question 5: Linux semantics — honest contract

Linux's unprivileged ceiling is structurally asymmetric. Recall that
on the Linux nice scale, **higher nice = lower priority** (range
`[-20, +19]`):

- **Lowering thread priority** (nice value ↑): always succeeds
  unprivileged. `utility` (nice 10), `background` (nice 19) are
  reliably honored.
- **Raising thread priority** (nice value ↓): requires `CAP_SYS_NICE`.
  Without it, `setpriority(2)` returns `-1` with `EPERM`. iso-9945's
  typed wrapper translates this into a thrown
  `ISO_9945.Kernel.Process.Priority.Error.permission` (or equivalent)
  case; the L3-policy Override's `do throws(E) { } catch { }` block
  catches it and records `_applied = false` per the init body shown
  in sub-question 3.

The L3-unifier's docs state:

> On Linux, priority bracketing is best-effort. Lowering thread
> priority (utility, background) succeeds without privilege. Raising
> thread priority (default and above) requires `CAP_SYS_NICE` and
> silently no-ops without it. The flag's effect on systems without
> `CAP_SYS_NICE` is limited to backgrounding lower-priority work.

This is **not equivalent** to Darwin's full pthread override
semantics — but it is **not no-op**. Backgrounding work is a real M3
contribution: it frees CPU for higher-priority work elsewhere, which
is half of the priority-inversion mitigation story.

For deployments with `CAP_SYS_NICE` (typical for daemons / system
services), full Linux M3 semantics work transparently. The same code
runs on both privileged and unprivileged contexts.

`priority-escalation-policy.md`'s prior position that Linux thread-QoS
was "out of scope for v1, defer to v2" is superseded by this design:
Linux is **in scope** with documented best-effort semantics.

### Sub-question 5b: setpriority/getpriority placement (Option A vs B vs C)

`setpriority`/`getpriority` are POSIX-specified
(`<sys/resource.h>`, IEEE 1003.1) but Linux extends their
semantics: PRIO_PROCESS with a tid (from `gettid`) operates per-thread
on Linux, exploiting Linux's pid/tid conflation. Darwin/BSD honor
only the POSIX per-process semantics. Windows lacks the function
entirely.

Three placement options were considered:

| Option | Where setpriority lives | Where Linux per-thread semantic lives |
|---|---|---|
| A — Strict spec-authority | iso-9945 (POSIX bindings only) | Encoded inline at `Linux.Kernel.Thread.Priority.Override` use site, with comment documenting the extension |
| B — Linux helper at L3-policy | iso-9945 (POSIX) | `swift-linux` adds `Linux.Kernel.Thread.Priority.set(tid:nice:)` helper composing iso-9945's setpriority |
| C — Per-thread binding at linux-standard | iso-9945 (POSIX) | swift-linux-standard adds its own per-thread setpriority binding |

**Decision: Option A** (2026-04-29).

Rationale:
- Strict [PLAT-ARCH-007] compliance: setpriority IS POSIX, so iso-9945
  is the canonical home; no duplication anywhere else.
- The Linux-extension semantic is documented at the one site where it
  matters (`Linux.Kernel.Thread.Priority.Override`'s body), where any
  reader investigating Linux M3 behavior naturally looks.
- No new abstraction layer at v1. Per [RES-018], a Linux-thread-priority
  helper (Option B) would have only one consumer today (the Override);
  promotion is mechanical if a second consumer surfaces (e.g., a
  future Linux thread-spawn API that takes priority).
- Option C would borderline-duplicate the POSIX function in
  linux-standard, conflicting with [PLAT-ARCH-007]'s spirit even though
  it's not strictly the same binding.

**Promotion trigger** for Option A → B: when a second Linux per-thread
priority consumer arrives, lift the inline use-site call into a
`Linux.Kernel.Thread.Priority.set(tid:nice:)` helper at swift-linux.

### Sub-question 6: `PriorityOverride.swift` disposition in swift-executors

The current `Kernel.Thread.Executor.PriorityOverride.swift` becomes:

```swift
// File: Kernel.Thread.Executor+priority.swift (no #if, no import Darwin)

extension Kernel.Thread.Executor {
    internal static func run(
        _ job: UnownedJob,
        onSerial executor: UnownedSerialExecutor,
        priorityTracking: Bool
    ) {
        guard
            priorityTracking,
            let priority = Kernel.Thread.Priority(job.priority)
        else {
            unsafe job.runSynchronously(on: executor)
            return
        }
        let _override = Kernel.Thread.Priority.Override(priority)
        unsafe job.runSynchronously(on: executor)
        // _override deinit ends bracketing.
    }

    internal static func run(
        _ job: UnownedJob,
        onTask executor: UnownedTaskExecutor,
        priorityTracking: Bool
    ) {
        // Symmetric to onSerial.
    }
}
```

Method renamed `runJob` → `run` per [API-NAME-002] / [API-NAME-005]
(verb-noun compound forbidden; `run(_:onSerial:...)` is a single-form
labeled method per [API-NAME-008] decision rule). The two overloads
are disambiguated by the `onSerial:` / `onTask:` argument labels.

The `Kernel.Thread.Priority(_ jobPriority: UnownedJob.Priority)`
bridge initializer lives in swift-executors itself (confirmed
2026-04-29; the executor is the natural site for stdlib-job-type
interop and avoids pulling stdlib `_Concurrency` knowledge up into
the platform-stack L3-unifier), as an extension on
`Kernel.Thread.Priority`. It's a one-line `init?` mapping
rawvalue → rawvalue, since the abstract enum's raw values were
chosen to match `qos_class_t` (and therefore
`UnownedJob.Priority.rawValue`) numerically by design.

The compound name `PriorityOverride` disappears. New filename per
[API-IMPL-007]: `Kernel.Thread.Executor+priority.swift`.

## Outcome

**Status: RECOMMENDATION.**

Locked layering for the M3 mechanism with all three platforms as
first-class consumers, satisfying the platform skill ([PLAT-ARCH-005],
[PLAT-ARCH-005a], [PLAT-ARCH-008c], [PLAT-ARCH-008e], [PLAT-ARCH-008h],
[PLAT-ARCH-015]), the principal directive ("all platform-specific
code at L2; all packages support all three platforms equally"), and
the kernel-primitives factoring direction.

| Concern | Package / Target | Layer | Surface |
|---------|------------------|-------|---------|
| Darwin native typed taxonomy | swift-darwin-standard / `Darwin Kernel Standard` | L2 | `Darwin.Kernel.Thread.Priority` (UInt32 enum, qos_class_t mirror) |
| Darwin bracketing wrapper | swift-darwin-standard / `Darwin Kernel Standard` | **L2** (modern Swift encoding of pthread token API) | `Darwin.Kernel.Thread.Priority.Override : ~Copyable` (init = start_np, deinit = end_np) |
| Darwin further policy | swift-darwin / `Darwin Kernel` | L3-policy | **Empty** for priority — pthread token API IS the natural Swift encoding; per [PLAT-ARCH-008e] empty-tier exception, L3-unifier composes Darwin L2 directly |
| Linux native typed taxonomy | swift-linux-standard / `Linux Kernel System Standard` | L2 | `Linux.Kernel.Thread.Priority` (Int32 nice struct + named statics in extension) |
| Linux atomic operations | swift-iso-9945 / `ISO 9945 Kernel Process` | L2 (POSIX) | `ISO_9945.Kernel.Process.Priority.{set,get}` typed methods (Option A) |
| Linux bracketing wrapper | swift-linux / `Linux Kernel Thread` | L3-policy | `Linux.Kernel.Thread.Priority.Override : ~Copyable` (save/restore lifecycle composing iso-9945's atomic ops + Linux.Kernel.Thread.ID) |
| Windows native typed taxonomy | swift-windows-standard / `Windows Kernel Thread Standard` | L2 | `Windows.Kernel.Thread.Priority` (Int32 enum, THREAD_PRIORITY_* mirror) |
| Windows typed handle | swift-windows-standard / `Windows Kernel Thread Standard` | L2 | `Windows.Kernel.Thread.Handle` typed HANDLE wrapper + `.current` static |
| Windows atomic operations | swift-windows-standard / `Windows Kernel Thread Standard` | L2 | `Windows.Kernel.Thread.Priority.{set,get}` typed methods + `Priority.Error` |
| Windows bracketing wrapper | swift-windows / `Windows Kernel Thread` (NEW subtarget) | L3-policy | `Windows.Kernel.Thread.Priority.Override : ~Copyable` (save/restore lifecycle) |
| Abstract typed Priority enum | swift-kernel / `Kernel Thread` | L3-unifier | `Kernel.Thread.Priority` (UInt8 enum, 6 abstract cases) |
| Cross-platform bracketing API | swift-kernel / `Kernel Thread` | L3-unifier | `Kernel.Thread.Priority.Override(_ priority: Kernel.Thread.Priority)` dispatching per-platform; Darwin branch composes L2 directly, Linux/Windows branches compose L3-policy |
| Executor consumption | swift-executors / `Executors` | L3-domain | `Kernel.Thread.Executor.run` (renamed from `runJob` per [API-NAME-002]) constructs the unified Override; no `#if`, no `import Darwin/Glibc/WinSDK` |

**M3 substance preserved.** The Darwin-only opt-in flag becomes a
three-platform opt-in flag with documented per-platform semantics:

| Platform | priorityTracking=true behaviour |
|---|---|
| Darwin | Full pthread override start/end per job |
| Linux | Best-effort: lowering always works; raising works only with CAP_SYS_NICE |
| Windows | Full SetThreadPriority save/restore per job |

**Implementation order** (post-2026-04-29 upstream refactor; paths
reflect current target structure):

1. **L2 modern Swift encoding** (parallel, one PR per platform):
   - **swift-darwin-standard / `Darwin Kernel Standard`**:
     `Darwin.Kernel.Thread.Priority` enum +
     `Darwin.Kernel.Thread.Priority.Override : ~Copyable` (the modern
     Swift encoding of the pthread paired-token API, init/deinit
     wrapping start_np / end_np). pthread/qos.h declarations imported
     through `Darwin`; no C shim needed.
   - **swift-linux-standard / `Linux Kernel System Standard`**:
     `Linux.Kernel.Thread.Priority` struct + named statics in
     extension. (Linux.Kernel.Thread.ID with `.current` already
     exists in this same subtarget per
     `Linux.Kernel.Thread.ID.swift:52`.)
   - **swift-windows-standard / `Windows Kernel Thread Standard`**:
     `Windows.Kernel.Thread.Priority` enum +
     `Windows.Kernel.Thread.Handle` typed HANDLE wrapper + atomic
     `Windows.Kernel.Thread.Priority.{set,get}` typed methods +
     `Windows.Kernel.Thread.Priority.Error`. The dedicated
     `Windows Kernel Thread Standard` subtarget exists at
     swift-windows-standard post-refactor.
2. **POSIX `setpriority` / `getpriority` typed bindings** (one PR):
   - **swift-iso-9945 / `ISO 9945 Kernel Process`**: add
     `ISO_9945.Kernel.Process.Priority` namespace with `Which` enum
     (`.process` / `.processGroup` / `.user`) and `set(_:_:_:)` /
     `get(_:_:)` typed-throws static methods per [API-ERR-001]. Per
     Option A (sub-question 5b) — these are POSIX so they live
     exclusively in iso-9945. Linux's PRIO_PROCESS-with-tid
     per-thread semantic is a Linux extension encoded inline at the
     L3-policy Override use site, NOT a separate linux-standard
     binding.
3. **L3-policy bracketing wrappers** (parallel, two PRs):
   - **swift-linux / `Linux Kernel Thread`** (existing subtarget):
     `Linux.Kernel.Thread.Priority.Override : ~Copyable` with
     best-effort save/restore composing iso-9945's `Process.Priority.{set,get}`
     + linux-standard's `Linux.Kernel.Thread.ID.current` per
     [PLAT-ARCH-008i] POSIX-shared-base composition.
   - **swift-windows / `Windows Kernel Thread`** (NEW subtarget —
     swift-windows currently has only `Windows Kernel`,
     `Windows Kernel Descriptor`, `Windows System`; this PR adds the
     symmetric Thread subtarget):
     `Windows.Kernel.Thread.Priority.Override : ~Copyable` save/restore
     composing L2 atomic operations.
   - **swift-darwin: NO L3-policy needed** for priority. The L2
     `Darwin.Kernel.Thread.Priority.Override` IS the modern Swift
     encoding of the pthread token API; per [PLAT-ARCH-008e]
     empty-tier exception, the L3-unifier composes Darwin L2 directly.
4. **L3-unifier abstract enum + dispatch** (one PR):
   - **swift-kernel / `Kernel Thread`**: `Kernel.Thread.Priority` enum +
     `Kernel.Thread.Priority.Override` dispatching per-platform.
     Darwin branch composes Darwin L2 (`Darwin.Kernel.Thread.Priority.Override`)
     directly; Linux/Windows branches compose their respective
     L3-policy Overrides. Per-platform mapping helpers
     `Kernel.Thread.Priority.{_darwin,_linux,_windows}` in
     `+Darwin.swift`, `+Linux.swift`, `+Windows.swift` extension files.
5. **L3-domain executor refactor** (one PR):
   - **swift-executors**: refactor
     `Kernel.Thread.Executor.PriorityOverride.swift` →
     `Kernel.Thread.Executor+priority.swift`, consume the unified
     `Kernel.Thread.Priority.Override` from swift-kernel. Add the
     `Kernel.Thread.Priority(UnownedJob.Priority)` bridge initializer.
     Delete `import Darwin`, delete `_qosClass(for:)`, delete the
     direct `pthread_override_*` calls.
6. **Update `priority-escalation-policy.md`** Next Step #6: Linux is
   no longer deferred — it's in v1 scope as best-effort lower-only.
   (Already done in priority-escalation-policy.md v0.8.0.)

**Escalation note** per [RES-004b]: this analysis crosses seven
package boundaries (3× L2, 3× L3-policy, 1× L3-unifier) plus the
L3-domain consumer. Per [RES-002a] the doc lives in
swift-executors/Research because the consuming concern is
swift-executors-domain, but the implementation is genuinely seven
sequential PRs across the platform stack. Coordinate as such.

## Changelog

- **v2.4.0 (2026-04-29).** Reassessment after upstream refactor wave:
  (1) swift-kernel-primitives confirmed gone (factoring-out completed);
  references already cleaned up in v2.0.0.
  (2) File paths updated to current target structure: Linux L2 native
  taxonomy in `Linux Kernel System Standard` (alongside existing
  `Linux.Kernel.Thread.ID`); Windows L2 in the dedicated new
  `Windows Kernel Thread Standard` subtarget; Linux L3-policy Override
  in the dedicated new `Linux Kernel Thread` subtarget at swift-linux.
  (3) NEW `Windows Kernel Thread` subtarget added to swift-windows
  L3-policy for symmetry with the new Linux Thread subtarget
  (Option β chosen).
  (4) /platform strict compliance applied to the L2/L3 split per the
  principal directive "MODERN SWIFT API ENCODING goes into
  swift-windows-standard, and swift-windows adds further policy" —
  L2 owns the modern Swift typed encoding; L3 adds further policy.
  Concrete asymmetry across platforms: Darwin's pthread paired-token
  API IS naturally a `~Copyable` resource, so its modern Swift
  encoding (the Override) lives at L2 and L3-policy is empty per
  [PLAT-ARCH-008e] empty-tier exception. Linux/Windows have stateless
  atomic ops at L2; the save/restore lifecycle is additional policy
  at L3.
  (5) Outcome table reorganized to show the L2 vs L3-policy split per
  platform explicitly. Implementation order rewritten with the
  current target paths and the new Windows subtarget creation.
  Substance unchanged from v2.3.0 — only the layering shape across
  the L2/L3 boundary is sharpened to /platform strict compliance.
- **v2.3.0 (2026-04-29).** L3-unifier `Kernel.Thread.Priority.Override`
  internal `_Backing` indirection removed per [IMPL-086] / [IMPL-087]
  (deletion-first structural fix; the component had no invariant
  beyond what `Override` already enforces). `Override` now holds
  `_native` directly with `#if` discrimination on the field's type.
  No explicit `deinit` needed on the unifier wrapper — Swift's
  ~Copyable field cleanup invokes the per-platform `_native`'s deinit
  automatically. Verification pass also fixed three narrative
  staleness items in sub-question 5 and the L2 syscall-bindings
  bullet (line 211-215): clarified that setpriority lives exclusively
  in iso-9945 per Option A; corrected EPERM detection narrative to
  describe the typed-throws catch flow; clarified Linux nice-scale
  direction.
- **v2.2.0 (2026-04-29).** Code-sketch compliance audit against
  /code-surface and /implementation skills. Fixes:
  (1) `Linux.Kernel.Thread.Priority` static instances moved from type
  body to extension per [API-IMPL-008] (only stored properties + canonical
  init in body).
  (2) `Linux.Kernel.Thread.Priority.Override.init` rewritten to compose
  `ISO_9945.Kernel.Process.Priority.{set,get}` typed wrappers per
  Option A, using `do throws(E)` per [API-ERR-001] / [API-ERR-004]
  with `var` locals + final assignment to satisfy definite-init.
  (3) Linux + Windows Override `deinit` rewritten with explicit
  `do throws(E) { } catch { }` per `feedback_prefer_typed_throws_over_try_optional`
  (deinit cannot `try?`; failure is logged-by-comment as best-effort
  cleanup).
  (4) Windows Override updated to compose typed L2 wrappers
  (`Windows.Kernel.Thread.Priority.{set,get}` in swift-windows-standard,
  `Windows.Kernel.Thread.Handle.current`) parallel to the iso-9945
  pattern, instead of inline raw `SetThreadPriority`/`GetThreadPriority`.
  (5) L3-unifier `_Backing.init` Darwin branch switched from
  force-unwrap (`.init(rawValue: UInt32(priority.rawValue))!`) to
  `priority._darwin` mapping helper, symmetric with
  `priority._linux` / `priority._windows`, per [IMPL-002] (write the
  math).
  (6) `runJob(_:onSerial:priorityTracking:)` /
  `runJob(_:onTask:priorityTracking:)` renamed to `run(_:onSerial:...)`
  / `run(_:onTask:...)` per [API-NAME-002] / [API-NAME-005] (verb-noun
  compound forbidden) and [API-NAME-008] (single-form labeled method).
- **v2.1.0 (2026-04-29).** Sub-question 5b added: setpriority/getpriority
  placement decided as Option A (strict spec-authority — POSIX bindings
  in iso-9945, Linux per-thread semantic encoded inline at the
  `Linux.Kernel.Thread.Priority.Override` use site). Implementation
  step 2 made concrete with the iso-9945 namespace shape
  (`ISO_9945.Kernel.Process.Priority.{set,get}` with `Which` enum).
  Options B (L3-policy helper) and C (linux-standard per-thread binding)
  recorded as rejected with promotion trigger to B if a second
  Linux per-thread priority consumer surfaces.
- **v2.0.0 (2026-04-29).** Major architecture revision driven by:
  (a) principal directive "All our packages MUST support darwin,
  linux, windows equally" — Linux promoted from no-op to real L3-policy
  wrapper with best-effort semantics; Windows promoted from no-op to
  real L3-policy wrapper; (b) factoring out swift-kernel-primitives —
  abstract Priority enum relocated from L1 swift-executor-primitives
  (v1.0.0's placement) to L3-unifier swift-kernel; per-platform
  native typed taxonomies added at L2 per [PLAT-ARCH-015]; (c)
  application of [PLAT-ARCH-008e] L3-unifier-composes-L3-policy and
  [PLAT-ARCH-008h] composition matrix as the binding constraint that
  selected the L3-unifier home for the abstract enum.
- **v1.0.0 (2026-04-29).** Initial RECOMMENDATION. Darwin-only L2
  wrapper; Linux/Windows treated as no-op at L3-unifier; abstract
  Priority enum at L1 swift-executor-primitives. SUPERSEDED by v2.0.0
  within same day.

## References

### Internal
- `priority-escalation-policy.md` v0.7.0 (DECISION) — M3 mechanism decision; this doc supersedes its Next Step #6 (Linux deferral) and #8 (Darwin-only `#if canImport` implementation).
- `executor-job-deadline-naming.md` — frees the `Priority` name from the deadline-keyed queue.
- `cooperative-yield-policy-v2.md` — orthogonal axis (yield).
- `incoming-queue-concurrency-model.md` — orthogonal axis (queue concurrency).
- `swift-foundations/swift-executors/Sources/Executors/Kernel.Thread.Executor.PriorityOverride.swift` — current implementation [Verified: 2026-04-29].
- `swift-standards/swift-darwin-standard/Sources/Darwin Kernel Standard/` — L2 home for Darwin native taxonomy [Verified: 2026-04-29].
- `swift-foundations/swift-darwin/Sources/Darwin Kernel/` — L3-policy home for Darwin bracketing [Verified: 2026-04-29].
- `swift-foundations/swift-linux/Sources/` — L3-policy home for Linux bracketing [Verified: 2026-04-29].
- `swift-foundations/swift-windows/Sources/Windows Kernel/` — L3-policy home for Windows bracketing [Verified: 2026-04-29].
- `swift-foundations/swift-kernel/Sources/Kernel Thread/` — L3-unifier home; no Priority API present today [Verified: 2026-04-29].

### Platform skill rules
- [PLAT-ARCH-005] Cross-platform descriptor unification — same pattern, different concept.
- [PLAT-ARCH-005a] No platform C types in public API — drives "L3-policy takes typed Priority, not raw qos_class_t".
- [PLAT-ARCH-008a] Domain authority hard line — `import Darwin` forbidden in swift-executors.
- [PLAT-ARCH-008c] L1 unconditionally platform-agnostic — moot post-factoring; abstract enum lives at L3-unifier instead.
- [PLAT-ARCH-008d] Syscall-vs-policy test — pthread_override / setpriority / SetThreadPriority are syscalls, must be at L2.
- [PLAT-ARCH-008e] L3-unifier composition discipline — drives the unifier-dispatches-to-L3-policy pattern.
- [PLAT-ARCH-008h] Within-L3 sub-tier composition matrix — L3-policy → L3-unifier upward dep is forbidden, drove the abstract-enum-at-L3-unifier decision.
- [PLAT-ARCH-013] Shell + Values — considered for native taxonomies, rejected (Linux is continuous-Int32, not enum).
- [PLAT-ARCH-015] Per-L2 platform-native typed values — drives the per-L2 native taxonomies.

### External — Darwin
- `<pthread/qos.h>:213-293` — `pthread_override_qos_class_start_np` declaration [Verified in priority-escalation-policy.md].
- Apple QoS classes — `qos_class_t` constants UNSPECIFIED/BACKGROUND/UTILITY/DEFAULT/USER_INITIATED/USER_INTERACTIVE.

### External — Linux
- [sched(7)](https://man7.org/linux/man-pages/man7/sched.7.html) — only SCHED_OTHER changes are unprivileged; CAP_SYS_NICE required for real-time classes; autogroup scopes nice to per-session CPU share.
- [setpriority(2)](https://man7.org/linux/man-pages/man2/setpriority.2.html) — nice value adjustment; PRIO_PROCESS with tid is per-thread on Linux.
- [getrlimit(2)](https://man7.org/linux/man-pages/man2/getrlimit.2.html) — RLIMIT_NICE governs unprivileged ceiling.

### External — Windows
- `processthreadsapi.h` — `SetThreadPriority`, `GetThreadPriority`, `GetCurrentThread`.
- THREAD_PRIORITY_* constants: IDLE (-15), LOWEST (-2), BELOW_NORMAL (-1), NORMAL (0), ABOVE_NORMAL (+1), HIGHEST (+2), TIME_CRITICAL (+15).

### Runtime context
- Bartlett, J. — ["How Swift uses your hardware to guarantee actor isolation"](https://x.com/jacobtechtavern/status/2049489712209862750), 2026-04-29 — runtime context on the M3 concept.
- `swiftlang/swift` — [`stdlib/public/Concurrency/PartialAsyncTask.swift:228-236`](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/PartialAsyncTask.swift) — `UnownedJob.priority` accessor.
