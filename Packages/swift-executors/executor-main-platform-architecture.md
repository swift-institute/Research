# Executor.Main Platform Architecture

<!--
---
version: 4.0.0
last_updated: 2026-04-16
status: DECISION
tier: 2
changelog:
  - 4.0.0 (2026-04-16): Locked Revision 4 — witness-struct dependency inversion, universal scope with `MainActor` coexistence, Apple frameworks as L2 spec-mirror per [PLAT-ARCH-012], `Executor.MainThread` nested global actor per [API-NAME-001]. Supersedes all prior revisions (preserved inline as historical analysis).
  - 3.0.0 (2026-04-15): Locked R3 — uniform L3 condvar pump, headless-only scope. Superseded 2026-04-16 because the headless-only scope excluded intended GUI consumers, and because the Apple-framework-encodable-at-L2 insight was not yet surfaced.
  - 2.0.0 (2026-04-15): Locked R2 — per-platform L2 variants with `internal import Dispatch` + `internal import CoreFoundation`. Superseded 2026-04-15 by the user's no-Apple-framework-imports constraint.
  - 1.0.0 (2026-04-15): Locked R1 — minimal `Kernel.Main.Dispatch.async` wrapper with retained `#if os(...)` in `Executor.Main`. Superseded 2026-04-15 by the platform-agnostic-`Executor.Main` constraint.
---
-->

## Question

How should `Executor.Main` — the executor-toolkit family member that pins jobs to the OS main thread — be architected so that:

1. **No Apple framework leaks**: no Swift-level `import Dispatch`, `import CoreFoundation`, or `import Foundation` in `swift-executors` (the L3 service-layer package) or in any non-platform-stack package in the ecosystem.
2. **Platform-agnostic consumer API**: `Executor.Main` itself has no `#if os(...)` conditionals; the same `Executor.Main` code compiles and runs on Darwin, Linux, and Windows.
3. **Universal scope coverage**: GUI consumers on Darwin, headless consumers on all platforms, and future Windows/Linux GUI framework consumers can all use `Executor.Main` (or compose around it) without the abstraction dictating which mechanism the underlying platform uses.
4. **Ecosystem layering discipline**: the architecture respects [PLAT-ARCH-012] (Vocabulary / Spec / Composition), [PLAT-ARCH-008] (platform-stack packages host platform-specific imports), [API-NAME-001] (Nest.Name), and the existing witness-struct pattern used elsewhere in the ecosystem.

This question took four architectural revisions to answer correctly. Each revision selected a different architecture; each was right given the constraints in force at the time; each was superseded when a new constraint was surfaced. The four-revision journey is documented here because the reasoning trail is more load-bearing than the final answer — future maintainers evaluating related designs need to see the analytical errors that produced R1, R2, and R3, not just the R4 outcome.

## Mission

`Executor.Main` is the "main-thread serial executor" member of the executor toolkit (`Executor.Cooperative` / `Executor.Main` / `Executor.Scheduled` / `Kernel.Thread.Executor.Polling` / etc.). It must cover every consumer context where "schedule this work on the OS main thread" is the right semantic — from CLI tools and daemons to Darwin GUI apps and Windows message-loop apps. It coexists with `MainActor` (Swift standard library's main-isolation actor) rather than replacing it; the two are both-and, not either-or.

## Context

### The presenting problem

`swift-foundations/swift-executors/Sources/Executors/Executor.Main.swift` (as of 2026-04-14) contained the last [PLAT-ARCH-008a] **hard-line violation** in the executor toolkit:

```swift
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import Dispatch
#endif

// ...later in the file:
DispatchQueue.main.async {
    unsafe unowned.runSynchronously(on: self.asUnownedSerialExecutor())
}
```

Per the platform skill:

> "Direct `import Darwin`/`Glibc`/`Musl`/`WinSDK` remains a violation in ALL non-platform-stack packages. If the platform stack doesn't expose the needed API, the fix is to extend the platform stack — not bypass it."

`Dispatch` (libdispatch) is an Apple-authored framework in the same category. `swift-executors` is an L3 service-layer package, not a platform-stack package. The fix: extend the platform stack with a main-thread dispatch abstraction, then have `Executor.Main` consume it via `import Kernel`.

### What the platform stack must provide

`Executor.Main` needs a uniform cross-platform API for three operations:

| Operation | Semantics | Darwin GUI | Darwin CLI | Linux | Windows |
|-----------|-----------|-----------|-----------|-------|---------|
| `enqueue(closure)` | schedule on main, async, non-blocking caller | `DispatchQueue.main.async` — drained by NSApplication/UIApplication/SwiftUI App | same, consumer drives `run()` | no OS equivalent — build from condvar | `PostThreadMessage` (native) or condvar |
| `run()` | block current thread running the main pump until shutdown | n/a — framework owns the pump | `CFRunLoopRun()` | condvar-based pump on main thread | `GetMessage` loop (native) or condvar |
| `shutdown()` | signal `run()` to return after draining | n/a | `CFRunLoopStop(CFRunLoopGetMain())` | set flag, broadcast condvar | `PostQuitMessage` (native) or condvar broadcast |

These are structurally asymmetric. Darwin has vendor-provided run-loop machinery; Windows has vendor-provided message-loop machinery; Linux provides kernel primitives but no OS-level policy for "main-thread dispatch" — the Linux userspace ecosystem is plural (GTK's `GMainLoop`, Qt's `QCoreApplication::exec`, systemd's `sd_event`, libuv's `uv_run`) and the kernel privileges none.

Reconciling this asymmetry into a single cross-platform Swift API was the core difficulty across all four revisions.

### Revision history summary

| Revision | Approach | Superseded by |
|----------|----------|---------------|
| R1 | `Kernel.Main.Dispatch.async` wrapper + retained `#if os(...)` in `Executor.Main` | platform-agnostic-`Executor.Main` constraint |
| R2 | Per-platform L2 variants, `internal import Dispatch` + `internal import CoreFoundation` in Darwin variant | no-Apple-framework-imports constraint |
| R3 | Uniform L3 condvar pump, headless-only scope, `MainActor` handles GUI | intended-GUI-consumers-in-scope + Apple-frameworks-encodable-at-L2 insights |
| **R4** | **Witness-struct dependency inversion; per-platform witnesses at their respective layers; universal scope** | **current decision** |

The long form of each prior revision is preserved in §Analysis below. The analytical errors in R1 and R2 (conflation + unexamined premise) are preserved in §Analytical-Error Trail — future maintainers evaluating related designs need to see the reasoning that produced the wrong answers, not just the current answer.

## Prior Art

### Apple's libdispatch and `MainActor`

`libdispatch` (Grand Central Dispatch, GCD) was created by Apple in 2009 and open-sourced in 2016 as [apple/swift-corelibs-libdispatch](https://github.com/apple/swift-corelibs-libdispatch). It ships with Swift on Linux and Windows via that open-source port. On Darwin it is the native concurrency primitive library; Apple's own frameworks (AppKit, UIKit, SwiftUI, Foundation) are built on top of it.

Swift's standard library `MainActor` is implemented via a default main executor that on Darwin is backed by `DispatchQueue.main`. This means `@MainActor func foo()` on a GUI app Just Works because the framework drains `DispatchQueue.main` on the main thread automatically via the CFRunLoop integration.

### Windows Win32 message loop

Windows has a vendor-provided main-thread dispatch mechanism for GUI apps: the Win32 message loop. `GetMessage` / `TranslateMessage` / `DispatchMessage` drive a per-thread message queue; `PostThreadMessage` / `PostMessage` post work. For console apps without `CreateWindow`, the message loop must be actively pumped by the consumer — parallel to Darwin CLI apps.

Reference: [MSDN — Using Messages and Message Queues](https://learn.microsoft.com/en-us/windows/win32/winmsg/using-messages-and-message-queues).

### Linux userspace frameworks

The Linux kernel provides primitives but no policy for main-thread dispatch. Userspace has provided several competing answers:

| Framework | Main-loop API | Cross-thread dispatch |
|-----------|--------------|----------------------|
| GLib / GTK | `GMainLoop` + `g_main_loop_run` | `g_idle_add`, `g_main_context_invoke` |
| Qt | `QCoreApplication::exec()` | `QMetaObject::invokeMethod` (Qt::QueuedConnection) |
| systemd | `sd_event_loop_run()` | `sd_event_add_defer` |
| libuv | `uv_run()` | `uv_async_send` |
| Xlib | hand-rolled `XNextEvent` loop | connection ownership convention |
| Wayland | `wl_display_dispatch` loop | connection ownership convention |

All build on top of kernel primitives (`poll(2)`/`epoll(7)`/`futex(2)`/`eventfd(2)`). No single userspace framework dominates. Integrating with any of them from our ecosystem would require picking winners and pulling heavy dependencies — contraindicated.

### Swift Institute witness-struct pattern

Several parts of the ecosystem use witness structs for dependency inversion:

- `Kernel.Event.Driver` (per handoff `project_driver_witness_roadmap.md`): protocol rewritten as witness struct at L1, with kqueue/epoll/Uring-specific implementations in the respective L2 platform packages.
- `Kernel.Completion.Driver`: same pattern (completion ports vs io_uring).
- Rendering protocol → witness migration (per `rendering-witness-migration.md`): same structural pattern.
- `swift-witnesses` (L1 package): provides generic machinery for hand-rolling witness structs with good ergonomics.

The pattern is well-established ecosystem infrastructure, not a bespoke invention for this handoff.

### PLAT-ARCH-012 Vocabulary / Spec / Composition

The `/platform` skill's [PLAT-ARCH-012] rule defines the layer test:

| Question | Answer | Layer |
|----------|--------|-------|
| Did **we** define this type? | Our vocabulary | **L1** |
| Did **they** define this type (external spec, documented ABI)? | External spec | **L2** |
| Do we **compose** both into a Swift-native API? | Composition | **L3** |

Applied to the Apple frameworks relevant here:

| Framework | Character | Spec? | Layer |
|-----------|-----------|-------|-------|
| Dispatch (libdispatch) | Apple-authored concurrency primitive library; open-sourced; ships with Swift cross-platform | Yes — documented API, stable ABI, versioned | **L2 spec-implementation** |
| CoreFoundation | Apple-authored C-level runtime primitives (`CFRunLoop`, etc.); partially open-sourced | Yes — documented API, stable ABI | **L2 spec-implementation** |
| Foundation | NSObject-based Cocoa framework with ObjC runtime bridging, archiving, localization, URL loading | No — a *framework* with opinions, not a primitive spec | **Banned ecosystem-wide** |

The distinction matters: Dispatch and CoreFoundation are narrow primitive specs that can be mirrored at L2 the same way POSIX is mirrored in `swift-iso-9945`; Foundation is an opinionated framework whose semantic opinions we do not adopt.

This analysis is load-bearing for Revisions 3 and 4 — the question "can we import Dispatch at L2?" changes the architectural possibilities significantly.

## Analysis

### Option R1 — Minimal `Kernel.Main.Dispatch.async` wrapper + retained `#if os(...)` in `Executor.Main`

*Initial revision, 2026-04-15 early. Superseded by the platform-agnostic-`Executor.Main` constraint.*

Structure:

- L1 `swift-kernel-main-primitives` (new package): declares `Kernel.Main` and `Kernel.Main.Dispatch` empty namespaces. No method declarations.
- L2 `swift-darwin-standard`: adds `Kernel.Main.Dispatch.async(_:)` static method, `internal import Dispatch`, wraps `DispatchQueue.main.async`.
- `Executor.Main` retains `#if os(...)` strategy selector: Darwin path calls `Kernel.Main.Dispatch.async`; Linux/Windows path uses an executor-layer condvar pump (`Executor.Wait.Condvar` + `Executor.Job.Queue` + `Executor.Shutdown.Flag`).

The retained conditional was justified via the four-criteria [PLAT-ARCH-008a] walkthrough:

1. Domain authority: `Executor.Main` is the canonical owner of main-thread executor strategy.
2. Kernel imports only: `Executor.Main.swift` contains no raw platform framework imports after migration.
3. Domain strategy, not syscall selection: conditional selects between executor strategies, not syscalls.
4. Irreducible: Linux/Windows pumping is executor-domain state (job queue, condvar, shutdown flag); pushing it to the platform stack would smuggle L3 executor types down the layers.

The four criteria passed. The conditional was accepted under the domain-authority exception.

**Why R1 was superseded**: the user subsequently stated `swift-executors` must be platform-agnostic — `Executor.Main` cannot contain any `#if os(...)`, even domain-authority ones. The R1 structure preserved the conditional by design; it cannot satisfy the platform-agnostic constraint.

### Option R2 — Per-platform L2 variants, Apple frameworks via `internal import` in Darwin variant

*Second revision, 2026-04-15 mid-session. Superseded by the no-Apple-framework-imports constraint.*

Structure:

- L1 `swift-kernel-primitives/Sources/Kernel Primitives Core/`: declares `Kernel.Main` namespace and `Kernel.Main.Loop` class (no method bodies).
- L2 `swift-darwin-standard`: Darwin variant adds `enqueue`/`run`/`shutdown` method bodies on `Kernel.Main.Loop` via cross-module extension. `internal import Dispatch` + `internal import CoreFoundation`. Darwin `enqueue` wraps `DispatchQueue.main.async`; `run` calls `CFRunLoopRun()`; `shutdown` calls `CFRunLoopStop(CFRunLoopGetMain())`.
- L2 `swift-linux-standard`: Linux variant adds method bodies using condvar pump via `Kernel.Thread.Mutex` + `Kernel.Thread.Condition`.
- L2 `swift-windows-standard`: Windows variant parallel to Linux.
- `Executor.Main` becomes fully unconditional — delegates to `Kernel.Main.Loop.shared`.

R2 corrected R1's analytical error: the abstraction's pump uses **generic primitives** (closure queue, mutex, condvar from L2 synchronization primitives) — NOT L3 executor types. Only `Executor.Main` (the consumer-facing adapter) translates between `ExecutorJob` and closures. R1's "smuggles executor types" rejection of the platform-stack-absorption architecture was a category error; see §Analytical-Error Trail.

**Why R2 was superseded**: the user subsequently stated no Apple framework may be imported anywhere in the ecosystem — including `internal import Dispatch` and `internal import CoreFoundation` at the platform-stack L2 layer. R2's Darwin variant file is the sole source of those imports ecosystem-wide; the constraint forbids them.

### Option R3 — Uniform L3 condvar pump, headless-only scope

*Third revision, 2026-04-15 late. Superseded by the intended-GUI-consumers and Apple-frameworks-encodable-at-L2 insights.*

Structure:

- Single L3 file at `swift-kernel/Sources/Kernel Thread/Kernel.Main.swift`.
- Declares `Kernel.Main` namespace + `Kernel.Main.Loop` class + all method bodies.
- Uses only `Kernel.Thread.Mutex` + `Kernel.Thread.Condition` from L1 primitives.
- No platform variants — one implementation, every platform.
- No Apple framework imports anywhere.
- Scope narrowed: `Executor.Main` is **headless-only**. Darwin GUI apps use `MainActor` (stdlib, Dispatch-backed). `Executor.Main` is for CLI tools, servers, daemons, embedded.

R3's insight: once scope narrows to headless, the Apple framework integration requirement dissolves — there's no OS-provided run loop to defer to in a headless process; the implementation drives its own pump; a condvar pump is identical on every platform.

**Why R3 was superseded**: two reasons, surfaced in sequence.

1. **GUI consumers were implicitly excluded.** The meta-reviewer flagged that "does any existing or intended consumer rely on `Executor.Main` auto-pumping via `DispatchQueue.main` on Darwin GUI apps?" is a gate question R3 hadn't asked. The user's answer (2026-04-16): **yes, GUI consumers are in scope**. R3's headless-only scope is unrecoverable if committed.
2. **Apple frameworks are encodable at L2.** The user asked whether libdispatch is "part of the spec" and thus encodable at L2. Applying [PLAT-ARCH-012]: libdispatch is Apple-authored, documented, stable, and even open-source (apple/swift-corelibs-libdispatch). It **is** a specification. The ecosystem's own layering model classifies it as L2 spec-implementation material — in the same category as POSIX (swift-iso-9945). The no-Apple-framework constraint was too coarse; the refined rule is:
    - **Dispatch, CoreFoundation**: L2 spec-mirroring imports are permitted in platform-stack packages (`swift-darwin-standard`).
    - **Foundation**: remains banned ecosystem-wide. Foundation is a framework-with-opinions (NSLocale, NSURLSession, NSObject runtime bridging), not a primitive spec.

With GUI scope restored and Apple frameworks encodable at L2, the R3 architecture is no longer viable: its "universal condvar pump" fails GUI consumers (would conflict with NSApplication's run loop), and its "no Apple frameworks anywhere" invariant was over-broad.

### Option R4 — Witness-struct dependency inversion

*Current revision, 2026-04-16. Decision locked.*

Structure:

- **L1 `swift-kernel-primitives/Sources/Kernel Primitives Core/Kernel.Main.swift`**: declares `Kernel.Main` namespace + `Kernel.Main.Loop` **witness struct** (three closure properties — `enqueue`, `run`, `shutdown` — plus initializer). Pure L1 vocabulary; no platform awareness; no method bodies.
- **L2 `swift-darwin-standard/Sources/Darwin Kernel Standard/Kernel.Main.Loop+Darwin.swift`**: declares `Kernel.Main.Loop.darwin` static witness — uses `DispatchQueue.main.async` for enqueue, `CFRunLoopRun()` for run, `CFRunLoopStop(CFRunLoopGetMain())` for shutdown. `internal import Dispatch` + `internal import CoreFoundation` — L2 spec-mirroring imports per [PLAT-ARCH-012]. No awareness of other platforms.
- **L2 `swift-windows-standard` (optional, deferrable)**: declares `Kernel.Main.Loop.windows` witness using `PostThreadMessage` + `GetMessage` loop (Win32 message loop spec). Deferrable — can use the condvar witness on Windows for this handoff and upgrade to native later without touching anything else.
- **L3 `swift-kernel/Sources/Kernel Thread/Kernel.Main.Loop+Condvar.swift`**: declares `Kernel.Main.Loop.condvar()` factory — condvar-pump witness built from `Kernel.Thread.Mutex` + `Kernel.Thread.Condition`. Available on every platform as an explicit choice; used as Linux default (no L2 Linux witness because no Linux spec exists to mirror).
- **L3 `swift-kernel/Sources/Kernel Thread/Kernel.Main.Loop+Default.swift`**: declares `Kernel.Main.Loop.default` — platform-default witness selector. The sole `#if canImport(...)` in the architecture; lives at swift-kernel (a platform-stack package where conditionals are sanctioned per [PLAT-ARCH-006] / [PLAT-ARCH-008]).
- **L3 `swift-executors/Sources/Executors/Executor.Main.swift`**: holds a `Kernel.Main.Loop` witness via DI. `shared` uses `.default`; tests construct `Executor.Main(loop: customWitness)`. Fully unconditional.
- **L3 `swift-executors/Sources/Executors/Executor.MainThread.swift`**: declares `extension Executor { @globalActor public actor MainThread }`. Consumer-facing pinning via `@Executor.MainThread func foo()`. Nested per [API-NAME-001].

This is dependency inversion: each platform contributes its own witness at its own spec/composition layer. `Kernel.Main.Loop` the type does not know about platforms; `Executor.Main` the consumer does not know about platforms; only the `default` factory at L3 does the platform selection, and that's the correct layer for that work.

### Comparison

| Criterion | R1 | R2 | R3 | **R4** |
|-----------|----|----|----|--------|
| `#if os(...)` in `Executor.Main` | Yes (retained strategy selector) | No | No | No |
| Apple framework imports anywhere | No (in Swift — C shim would have been needed for headless Darwin scope) | Yes (internal at L2) | No | Yes (internal at L2 — spec-mirror per [PLAT-ARCH-012]) |
| Scope | Universal | Universal | Headless only | Universal |
| GUI consumer support | Via MainActor (not `Executor.Main`) | Via `Executor.Main` (Dispatch-backed) | Via MainActor only | Via `Executor.Main` (Dispatch-backed) OR MainActor (both valid) |
| Linux implementation | Condvar pump inside Executor.Main | Condvar pump in L2 Linux variant | Condvar pump in L3 single file | Condvar pump in L3 witness factory |
| Storage handling | Conditional stored properties in Executor.Main | Cross-module class extension storage (three implementation strategies to choose from) | Plain stored properties in single-module class | Plain stored properties in closure-captured state class |
| Testability | Hard — one-shot singleton | Hard — same | Hard — same (noted R3 risk #11) | Easy — inject custom witness via DI |
| Composability | Low | Low | Low | High — wrap any witness with logging/metrics/etc. |
| Per-platform discoverability | Low — Executor.Main is conditional | High — each L2 variant self-contained | Low — single file with conditionals | **Highest** — each platform is first-class, contributes its own witness |
| New-platform cost | L1 namespace + L2 variant declaration + L3 adapter changes | L1 namespace + L2 per-platform class + storage strategy | L3 conditional branch + storage branch | **L2 or L3 witness file + one line in `.default` selector** |
| Layer cleanliness per [PLAT-ARCH-012] | Mixed | Clean (L1 namespace + L2 variants) | Violated (L3 absorbs spec-layer work because scope was narrowed) | **Clean** (L1 vocabulary, L2 spec-mirror, L3 composition) |
| Reversibility cost | Low (single file) | Medium (three L2 files + L1 declaration) | Low (single file) | **Lowest** (each witness file is independent) |

**R4 selected.** The witness pattern satisfies every constraint the prior revisions accumulated, leverages the ecosystem's established witness-struct infrastructure, and has lower reversibility cost than any prior option — because each witness is independent, future architectural evolution (e.g., adding a Windows native witness, adding an experimental glib-integrated Linux witness, swapping the Darwin CFRunLoop usage for CFRunLoopSource APIs) touches one file without cascading through the rest.

## Analytical-Error Trail

Revision 1 and Revision 2 each selected an architecture that was later superseded. The errors in those selections are documented here because the reasoning pattern matters — future maintainers evaluating related designs should recognize the same shapes and avoid them.

### R1 error — Conflating "what the current code uses" with "what the abstraction needs"

R1 selected Option B (minimal wrapper + retained conditional) and rejected Option A (full platform-stack absorption) on the following analysis:

> "The Linux condvar pump is executor-specific orchestration: it runs `ExecutorJob`s, tracks executor shutdown, uses executor-layer condvar and queue types. Moving it to the platform stack smuggles executor semantics into `Kernel.Main`."

This was wrong. The error: **treating the current `Executor.Main` implementation (`Executor.Wait.Condvar` + `Executor.Job.Queue` + `Executor.Shutdown.Flag`) as what the abstraction architecturally requires**, rather than what the current code happened to use.

A main-loop abstraction needs a **closure queue**, a **mutex**, a **condition variable**, and a **shutdown flag**. Every one of those is a generic primitive:

- Closures are a Swift language primitive.
- Mutex: `Kernel.Thread.Mutex` from L1 primitives (POSIX pthread_mutex_t on Darwin/Linux; Windows CRITICAL_SECTION on Windows).
- Condition variable: `Kernel.Thread.Condition` from L1 primitives.
- Shutdown flag: an atomic Bool or mutex-guarded flag — either form is a generic primitive.

None of these are L3 executor types. Only the translation `ExecutorJob` ↔ `() -> Void` is executor-domain work; that translation lives in `Executor.Main` (the consumer-facing adapter), not in `Kernel.Main.Loop`.

**The corrective test**: if rejecting an architecture requires claiming that an abstraction needs specific concrete types that currently exist elsewhere, ask first — does the abstraction need *those specific types*, or does it need *what those types provide*? If the latter, those needs are almost always generic primitives available below the layer where the conflation originated.

### R2 error — Treating an assumption as axiomatic

R2 selected Option A (full platform-stack absorption with Darwin Apple-framework integration) on the implicit premise that "`Executor.Main` on Darwin should integrate with `DispatchQueue.main` + `CFRunLoop`." This premise was unexamined — it was never surfaced as a scope decision, never considered against alternatives, never weighed against the cost (two Apple framework imports in the platform stack).

The R2 architecture was correct *given that premise*. But the premise itself depended on a scope decision (GUI-friendly, framework-integrated) that hadn't been made explicit. When the user subsequently imposed the no-Apple-framework-imports constraint, R2 became unviable — because its entire Darwin variant was built around those imports.

**The corrective test**: when an architecture leans heavily on a specific platform's native mechanism, explicitly surface the scope assumption. "We integrate with X because we target consumers of X" is a design decision, not an axiom; it needs the same scrutiny as any other decision. If R1/R2 had surfaced the GUI-scope question before locking architecture, R1 and R2 wouldn't have happened — R4 (or a witness-pattern equivalent) would have been selected at the outset.

### The general lesson

Both errors share a shape: **assuming some piece of the current state reflects an architectural requirement when it actually reflects a contingent choice**. R1 assumed `Executor.Wait.Condvar` was architectural; it was contingent. R2 assumed Darwin-framework-integration was architectural; it was contingent on an unstated scope goal. Revision 3's reframe came from asking the scope question explicitly. Revision 4 came from asking the layering question explicitly (is libdispatch an L2 spec?). Both were questions the prior revisions had not asked.

The supervisory lesson (retroactively applicable): ask scope-boundary and layering-boundary questions **before** locking architecture. A 30-minute scope conversation saves four revision cycles of churn.

## Scope — Universal Coverage with MainActor Coexistence

`Executor.Main` under R4 is scoped for universal use — any consumer, any platform, any context — but does not seek to replace `MainActor`. The two tools cover overlapping but not identical roles; consumers choose based on their context.

### The two tools, compared

| Tool | Identity | Backing mechanism | Best for |
|------|----------|-------------------|----------|
| `MainActor` (Swift stdlib) | Global actor pinned to main thread | Swift runtime's default main executor (Dispatch-backed on Darwin; runtime-internal elsewhere) | Concurrency-model integration: `@MainActor` annotations, `await MainActor.run { }`, existing GUI framework code using `@MainActor func foo()`. |
| `Executor.Main` | `SerialExecutor` + `TaskExecutor` class | Platform-appropriate `Kernel.Main.Loop` witness (Dispatch+CFRunLoop on Darwin; condvar pump on Linux; native-or-condvar on Windows) | Executor-toolkit integration: custom actors with `unownedExecutor` delegation to `Executor.Main.shared`, toolkit-family parity with `Executor.Cooperative` / `Executor.Polling` / etc., explicit run/shutdown lifecycle control. |

### How they interact

In a Darwin GUI app (SwiftUI/AppKit/UIKit):

- The framework's `main()` is `NSApplication.main()` / `UIApplication.main` / `App.main()`. These drive `CFRunLoop` on the main thread.
- `MainActor` jobs execute because the framework drains `DispatchQueue.main` via the run loop.
- `Executor.Main.shared.enqueue { ... }` **also** works, because the Darwin witness uses `DispatchQueue.main.async` under the hood, and the framework drains it the same way.
- Consumer does NOT call `Executor.Main.shared.run()` — the framework's run loop is already pumping. Calling `run()` would create a nested-run-loop bug.
- `@MainActor` and `@Executor.MainThread` annotations both resolve to executing on the main thread, through different Swift-runtime paths. Mixing them in the same process is supported (not efficient, but not incorrect).

In a Darwin CLI / server / daemon app:

- No framework drives `CFRunLoop`. Consumer explicitly calls `Executor.Main.shared.run()` from their own `main()`. That call maps to `CFRunLoopRun()` which blocks until `shutdown()` triggers `CFRunLoopStop`.
- `MainActor` works too — stdlib's runtime supports it without requiring the full framework — but with the stdlib's default backing mechanism, not ours.

In a Linux / Windows headless app:

- Consumer calls `Executor.Main.shared.run()` from `main()`. Condvar pump drives the main thread.
- `MainActor` works via stdlib's runtime-provided executor (not ours).

In a Linux app using GTK / Qt / Wayland / libuv:

- Those frameworks have their own main-loop mechanisms. They do NOT integrate with `Executor.Main`.
- Consumer uses the framework's dispatch API (`g_idle_add`, `QMetaObject::invokeMethod`, `uv_async_send`).
- `Executor.Main` is irrelevant to them; no conflict, no interference, just unused.

In a Windows GUI app (Win32, WinUI, etc.):

- If we ship the Win32 native witness at L2: `Executor.Main.shared.enqueue` posts a thread message to the framework's existing message loop. Consumer does NOT call `run()`.
- If we ship only the condvar witness: `Executor.Main` is unsuitable for Win32 GUI apps with their own message loop; consumer uses the framework's native dispatch.

### The scope principle

**`Executor.Main` aims for universal coverage where universal coverage is achievable.** On Darwin, universal coverage is achievable because libdispatch provides the canonical platform-level answer. On Windows, universal coverage is achievable in principle via the message loop (deferrable — see §Migration). On Linux, universal coverage is impossible because no canonical answer exists; we provide the minimal condvar pump and defer to other-framework consumers to use their framework's native dispatch.

**`MainActor` remains the primary tool for Swift Concurrency code**; `Executor.Main` exists alongside it for consumers who need an explicit SerialExecutor/TaskExecutor reference (actor executor delegation, toolkit family parity, explicit lifecycle control).

## Apple Framework L2 Spec-Mirroring

This section documents the ecosystem layering rule applied to Apple frameworks, because the rule is load-bearing for R4 and the distinction surfaces periodically in related handoffs.

### The distinction

| Framework | Character | Spec status | Ecosystem placement |
|-----------|-----------|-------------|---------------------|
| **Dispatch** (libdispatch / GCD) | Concurrency primitive library. Apple 2009. Open-sourced 2016 as `apple/swift-corelibs-libdispatch`. Ships with Swift on Linux + Windows. | Apple-authored specification. Documented API. Stable ABI. Versioned. | **L2 spec-implementation** (in `swift-darwin-standard` for the main-queue binding, which is Darwin-specific; could be in a standalone `swift-dispatch-standard` package if more of Dispatch were used ecosystem-wide). |
| **CoreFoundation** | C-level runtime primitives (`CFRunLoop`, `CFString`, etc.). Apple. Partially open-sourced. | Apple-authored specification. Documented. Stable. | **L2 spec-implementation** (in `swift-darwin-standard`). |
| **Foundation** | NSObject-based Cocoa framework. ObjC runtime bridging, archiving, NSLocale, NSURLSession, etc. Opinionated. | Not a primitive spec — a framework-with-opinions. | **Banned ecosystem-wide.** Adopting Foundation means adopting Foundation's opinions (localization semantics, URL parsing decisions, NSObject identity, NSDate calendar semantics), which the ecosystem declines. |

### The rule applied

Under [PLAT-ARCH-012]:

- Did Apple define libdispatch? Yes.
- Is there documentation? Yes.
- Is the API stable? Yes.
- **Conclusion: L2 spec-implementation layer.**

`internal import Dispatch` at L2 in `swift-darwin-standard` is **not a workaround** — it is correct ecosystem layering, in the same category as `swift-iso-9945` importing POSIX kernel headers, `swift-linux-standard` importing Linux-specific headers, or `swift-windows-standard` importing WinSDK.

### Why `internal`, not `public`

Consumers of `swift-darwin-standard` should see `Kernel.Main.Loop.darwin` (the witness value) — not `DispatchQueue` or `CFRunLoop` types. The Darwin witness file uses `internal import Dispatch` + `internal import CoreFoundation` so the underlying framework types do not leak through `@_exported public import` re-export chains.

Consumers of `swift-kernel` / `swift-executors` never see Dispatch or CoreFoundation types; they see `Kernel.Main.Loop` (the witness struct) and `Executor.Main` (the class). The `grep "import Dispatch|import CoreFoundation|import Foundation"` invariant is:

- Zero matches in `swift-executors` (the consumer-facing L3 package).
- Zero matches in `swift-kernel-primitives` (L1).
- Zero matches in `swift-kernel` (L3 unified) except possibly in the Linux condvar witness file, which uses `public import Kernel_Thread_Primitives` only — no Apple framework.
- Exactly one `import Dispatch` and one `import CoreFoundation` ecosystem-wide, both `internal`, both in `swift-darwin-standard/Sources/Darwin Kernel Standard/Kernel.Main.Loop+Darwin.swift`.

### Why Foundation remains banned

Foundation is different from Dispatch and CoreFoundation. It:

- Bundles ObjC-runtime bridging that has non-trivial semantic implications for Swift values.
- Makes opinionated decisions about localization, URL parsing, date math, JSON encoding, etc.
- Pulls in substantial dependencies (ICU on some platforms, various Cocoa frameworks on Apple).
- Has a history of platform-dependent behavioral divergence (NSURLSession on Linux historically lagged Darwin).

The ecosystem's stance: adopt primitive specs at L2 when they provide narrow, stable, documented APIs; do not adopt frameworks whose opinions we would inherit. Foundation falls in the latter category. This is a principled choice, not a blanket allergy to Apple code — `swift-darwin-standard` actively imports Dispatch and CoreFoundation under R4.

## Global Actor Naming — `@Executor.MainThread`, Nested

### The question

Swift global actors (like `@MainActor` in stdlib) are conventionally declared at module scope, making the annotation short: `@MainActor func foo()`. The ecosystem's `/code-surface` skill mandates [API-NAME-001] (Nest.Name pattern): "All types MUST use the `Nest.Name` pattern. Compound type names are FORBIDDEN." A top-level `MainThread` isn't a compound name, but is at module scope, which the rule's intent (every type under a namespace that narrows scope) disfavors.

### Options

| Option | Declaration | Annotation | Pros | Cons |
|--------|-------------|------------|------|------|
| **Nested** (selected) | `extension Executor { @globalActor public actor MainThread }` | `@Executor.MainThread func foo()` | Ecosystem-consistent per [API-NAME-001]; self-documenting (relationship to `Executor.Main` is obvious at the call site); no exception needed to the ecosystem naming rule | Nine extra characters at every call site; deviates from stdlib's `@MainActor` top-level convention; no existing ecosystem precedent for global actors (this is the first) |
| Top-level | `@globalActor public actor MainThread` at module scope | `@MainThread func foo()` | Ergonomic parity with `@MainActor`; matches stdlib's convention for global actors | Requires explicit [API-NAME-001] exception lock; sets precedent that "stdlib does it differently" is an acceptable reason to deviate; `MainThread` at module scope is less self-documenting (MainThread what? Where from?) |

### Decision

**Nested.** The user's rationale:

1. [API-NAME-001] is the ecosystem rule, not a guideline. Deviating for stdlib parity opens the door to further exceptions whenever "stdlib does it differently" arises. That's not a precedent to set.
2. `@Executor.MainThread` is self-documenting — the relationship to `Executor.Main` is obvious at the call site. `@MainThread` is not.
3. Nine extra characters at call sites is not a real ergonomic cost.
4. Future maintainers don't need to remember "`MainThread` is an [API-NAME-001] exception."

The stdlib's top-level `@MainActor` reflects stdlib's naming conventions, which are not binding on this ecosystem. Mirroring stdlib here would create a one-off exception without corresponding benefit.

### Future escape hatch

If the `@Executor.MainThread` vs `@MainActor` cognitive mismatch bites users in practice, a future handoff could add a consumer-opt-in typealias (`typealias MainThread = Executor.MainThread` in a namespace consumers explicitly import) that preserves ecosystem consistency at the declaration site while allowing ergonomic shortening at the opt-in point. **Do not do this preemptively** — wait for actual reported friction.

## Outcome

**Status**: DECISION (R4). Locked 2026-04-16.

### Final architecture

```
L1  swift-kernel-primitives / Sources / Kernel Primitives Core /
      Kernel.Main.swift                                (NEW — ~40 lines with docs)
        • extension Kernel { public enum Main: Sendable {} }
        • extension Kernel.Main {
            public struct Loop: Sendable {
              public let enqueue: @Sendable (@escaping @Sendable () -> Void) -> Void
              public let run: @Sendable () -> Void
              public let shutdown: @Sendable () -> Void
              public init(...)
            }
          }

L2  swift-darwin-standard / Sources / Darwin Kernel Standard /
      Kernel.Main.Loop+Darwin.swift                    (NEW — ~40 lines with docs)
        • internal import Dispatch           (L2 spec-mirror)
        • internal import CoreFoundation     (L2 spec-mirror)
        • extension Kernel.Main.Loop {
            public static let darwin: Kernel.Main.Loop = ...
          }

L2  swift-windows-standard / Sources / Windows Kernel Standard /   (OPTIONAL — deferrable)
      Kernel.Main.Loop+Windows.swift                   (NEW if native; absent if using condvar)
        • internal import WinSDK              (L2 spec-mirror, if adopted)
        • extension Kernel.Main.Loop {
            public static let windows: Kernel.Main.Loop = ...
          }

L3  swift-kernel / Sources / Kernel Thread /
      Kernel.Main.Loop+Condvar.swift                   (NEW — ~80 lines with docs)
        • public import Kernel_Thread_Primitives
        • extension Kernel.Main.Loop {
            public static func condvar() -> Kernel.Main.Loop { ... }
          }
        • private final class _CondvarState: @unsafe @unchecked Sendable { ... }

      Kernel.Main.Loop+Default.swift                   (NEW — ~20 lines with docs)
        • extension Kernel.Main.Loop {
            public static let `default`: Kernel.Main.Loop = {
              #if canImport(Darwin_Kernel_Standard)
              return .darwin
              #elseif canImport(Windows_Kernel_Standard)
              return .windows       // or .condvar() if not implemented
              #else
              return .condvar()
              #endif
            }()
          }

L3  swift-executors / Sources / Executors /
      Executor.Main.swift                              (MODIFIED — ~40 lines after migration)
        • public final class Main: SerialExecutor, TaskExecutor, @unsafe @unchecked Sendable {
            private let loop: Kernel.Main.Loop
            public init(loop: Kernel.Main.Loop = .default) { self.loop = loop }
            public static let shared: Executor.Main = Executor.Main()
            public func enqueue(_ job: consuming ExecutorJob) { loop.enqueue { ... } }
            public func asUnownedSerialExecutor() -> UnownedSerialExecutor { ... }
            public func asUnownedTaskExecutor() -> UnownedTaskExecutor { ... }
            public func run() { loop.run() }
            public func shutdown() { loop.shutdown() }
          }

      Executor.MainThread.swift                        (NEW — ~30 lines with docs)
        • extension Executor {
            @globalActor
            public actor MainThread {
              public static let shared: MainThread = MainThread()
              private init() {}
              public nonisolated var unownedExecutor: UnownedSerialExecutor {
                Executor.Main.shared.asUnownedSerialExecutor()
              }
            }
          }
```

### Key properties

- **No Apple framework imports in non-platform-stack packages.** `swift-executors` contains zero Apple framework imports; `swift-kernel` contains zero Apple framework imports. The sole `import Dispatch` and `import CoreFoundation` in the entire ecosystem are `internal` imports in one L2 file in `swift-darwin-standard`. Foundation is imported nowhere.
- **No `#if os(...)` in `Executor.Main`.** The consumer-facing class is fully unconditional.
- **One `#if canImport(...)` in the architecture, at L3.** `Kernel.Main.Loop.default`'s platform-selection conditional lives in the ecosystem's designated platform-selection layer per [PLAT-ARCH-006] / [PLAT-ARCH-008]. No exception required.
- **Witness-pattern first-class platform contribution.** Each platform adds its own witness at its own layer (L2 spec-mirror for Darwin/Windows-native; L3 composition for Linux-condvar). No platform is privileged in the abstraction; each is equal.
- **Universal scope.** GUI (Darwin framework-driven, Windows message-loop-driven if native witness adopted), CLI / server / daemon (any platform, consumer-driven run()), embedded (any platform, consumer-driven run()). `MainActor` coexists as the Swift Concurrency counterpart.
- **Trivial testability.** Tests construct `Executor.Main(loop: customWitness)` or `Kernel.Main.Loop(enqueue: ..., run: ..., shutdown: ...)` with sentinel closures. No `@_spi(Testing)` needed; no singleton-is-one-shot problem.
- **Composability.** Wrappers (logging, metrics, reentrance guards) are trivially expressible as witnesses that take a wrapped witness — `Kernel.Main.Loop.logged(wrapping: .darwin)` etc.
- **Low reversibility cost.** Each witness file is independent. Adding a Windows-native witness later: one new file + one line in `.default`. Swapping Darwin's CFRunLoopRun for a different mechanism: one file. Adding a FreeBSD witness: same.

### Migration — three commits on branch `executor-main-loop-adoption` (swift-foundations)

Per prior supervisor direction, Step 3 was split into three reviewable commits. R4 preserves this split:

| Commit | Scope | Message |
|--------|-------|---------|
| **Platform-stack setup** (precedes 3a) | Add `Kernel.Main.swift` (L1), `Kernel.Main.Loop+Darwin.swift` (L2 Darwin), `Kernel.Main.Loop+Condvar.swift` (L3), `Kernel.Main.Loop+Default.swift` (L3) | `Add Kernel.Main.Loop witness + platform witnesses` (across two repos: swift-primitives for L1, swift-foundations for L2/L3) |
| **3a — Core migration** | Strip `Executor.Main` to thin adapter over the injected witness; remove `#if os()` + `import Dispatch` + conditional stored properties | `Route Executor.Main through Kernel.Main.Loop witness; drop platform conditionals and Dispatch import` |
| **3b — β TaskExecutor** | Add `TaskExecutor` conformance + `asUnownedTaskExecutor()` | `Conform Executor.Main to TaskExecutor` |
| **3c — α Executor.MainThread** | Add `Executor.MainThread.swift` with `@globalActor` | `Add @Executor.MainThread global actor pinning to Executor.Main` |

### Pre-commit verifications

- **(a)** `git diff swift-executors/Package.swift`: zero dependency-list changes.
- **(b)** `rg "import Dispatch" /Users/coen/Developer/swift-foundations /Users/coen/Developer/swift-primitives /Users/coen/Developer/swift-standards`: exactly one match (in `swift-darwin-standard/Sources/Darwin Kernel Standard/Kernel.Main.Loop+Darwin.swift`).
- **(b)** `rg "import CoreFoundation"`: exactly one match (same file).
- **(b)** `rg "import Foundation"`: zero new matches introduced by this work.
- **(b)** `rg "public import (Dispatch|CoreFoundation|Foundation)"`: zero matches.
- **(c)** `rg "#if os" swift-executors/Sources/Executors/Executor.Main.swift`: zero matches.
- **(c)** `rg "#if canImport"`: the new `Kernel.Main.Loop.default` selector is the sole new site introduced by this work.

### Tests

Per `/testing` conventions ([TEST-005], [SWIFT-TEST-002], [SWIFT-TEST-005]):

```swift
// swift-kernel/Tests/Kernel Tests/Kernel.Main.Loop Tests.swift
import Kernel
import Kernel_Test_Support
import Synchronization
import Testing

extension Kernel.Main.Loop {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension Kernel.Main.Loop.Test.Integration {
    @Test
    func `condvar witness enqueue executes closure when run pumps the queue`() throws {
        let loop = Kernel.Main.Loop.condvar()
        let executed = Atomic<Bool>(false)

        let enqueueHandle = try Kernel.Thread.spawn {
            loop.enqueue {
                executed.store(true, ordering: .releasing)
            }
        }
        enqueueHandle.join()

        let shutdownHandle = try Kernel.Thread.spawn {
            // brief delay to let run() enter the wait, then shut down
            loop.shutdown()
        }

        loop.run()
        shutdownHandle.join()

        #expect(executed.load(ordering: .acquiring) == true)
    }
}
```

Tests for the Darwin witness are analogous but construct `Kernel.Main.Loop.darwin` and run on a worker that calls `CFRunLoopRun` / `CFRunLoopStop`. The Linux/Windows condvar witness tests reuse the same test structure because the witness API is platform-uniform.

The R3 singleton-one-shot testability problem does not exist under R4: each test constructs a fresh witness.

### Non-goals

Deliberately out of scope for this handoff:

- Implementing a Windows-native (Win32 message loop) witness. Deferrable — can ship condvar on Windows and upgrade to native later without touching anything else. If adopted in this handoff, add one L2 file in `swift-windows-standard`; decision flag to raise during implementation.
- Linux userspace framework integration (GTK/Qt/libuv/systemd). Out of scope permanently under the R4 architecture — the ecosystem does not pick winners among Linux userspace frameworks. Consumers using those frameworks use their native dispatch, not `Executor.Main`.
- `Kernel.Thread.isMain` main-thread sensor primitive. Separate handoff.
- Observability wrappers (logging witness, metrics witness, reentrance guard witness). Trivial follow-on work given the witness pattern, but not in scope for the initial landing.
- Changing `MainActor`'s backing (the γ option — installing `Executor.Main` as MainActor's executor). **Explicitly rejected**: would collapse the `MainActor` / `Executor.Main` coexistence and reintroduce scope questions Revision 3 already resolved. Any future PR attempting this must be rejected absent a new handoff formally revoking this decision.

## References

- `swift-foundations/swift-executors/Research/executor-package-design.md` — complete executor-toolkit taxonomy; establishes `Executor.Main` as a toolkit family member.
- `swift-foundations/swift-executors/Research/composable-executor-abstractions.md` — executor composability analysis; establishes the witness-pattern precedent used here.
- `swift-primitives/swift-witnesses/` — ecosystem-level witness-struct infrastructure.
- `swift-foundations/swift-kernel/Research/main-thread-dispatch-abstraction.md` — prior R1–R3 long-form analysis, superseded by this document. The old document will be reduced to a stub redirecting here.
- `HANDOFF-executor-main-platform-runloop.md` — operational handoff (ground rules, acceptance criteria); updated to reflect R4.
- [PLAT-ARCH-012] / [PLAT-ARCH-008] / [PLAT-ARCH-006] — layering rules in `/Users/coen/Developer/.claude/skills/platform/SKILL.md`.
- [API-NAME-001] — Nest.Name pattern in `/Users/coen/Developer/.claude/skills/code-surface/SKILL.md`.
- [TEST-005] / [SWIFT-TEST-002] / [SWIFT-TEST-005] — testing conventions in `/Users/coen/Developer/.claude/skills/testing/SKILL.md`.
- [apple/swift-corelibs-libdispatch](https://github.com/apple/swift-corelibs-libdispatch) — libdispatch open-source repo, cited for spec-status argument.
- Swift Forums thread / Swift Evolution SE-0417 (custom executor preference) — cited for `TaskExecutor` conformance context.
- MSDN [Using Messages and Message Queues](https://learn.microsoft.com/en-us/windows/win32/winmsg/using-messages-and-message-queues) — Win32 message loop reference.
