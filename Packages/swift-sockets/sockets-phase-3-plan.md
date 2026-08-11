# swift-sockets Phase 3 Plan

<!--
---
version: 1.0.0
created: 2026-04-15
status: IN PROGRESS — Phase 3A kickoff
tier: 3
related:
  - swift-io/Research/io-architecture.md (v1.3)
  - swift-io/HANDOFF.md (Phase 3 handoff)
---
-->

## Scope

Phase 3 lifts `swift-sockets` from Phase 2A blocking-only baseline to a full
multi-strategy consumer of swift-io's `IO` witness:

- **3A** Listener events-strategy accept + parameterized integration test
  over all four `IO` factories.
- **3B** Connection events/completions verification + half-close via
  `Kernel.Socket.Shutdown.shutdown(_:how:)`.
- **3C** Echo benchmark matrix, producing
  `Research/sockets-performance-baseline.md`.

This document records decisions as they are made. Each section below is
load-bearing for the implementation.

## Decision 3A-1 — Listener fd typing: Path A (store `Kernel.Descriptor`)

### Problem

`Sockets.TCP.Listener.accept()` needs to compose, *on the same fd*:

- `io.ready(from: _fd, interest: .read)` — the witness closure takes
  `borrowing Kernel.Descriptor`.
- `POSIX.Kernel.Socket.Accept.accept(_fd)` — iso-9945 currently only
  takes `borrowing Kernel.Socket.Descriptor`.

Listener today stores `_fd: Kernel.Socket.Descriptor` (Phase 2A
baseline, `Sockets.TCP.Listener.swift:43`). Its stored-property borrow
yields `borrowing Kernel.Socket.Descriptor` — the compiler cannot also
produce a `borrowing Kernel.Descriptor` view of the same fd.

### Options considered

- **(a) Store `_fd: Kernel.Descriptor`**, add `borrowing Kernel.Descriptor`
  overloads to iso-9945's socket ops (bind, listen, accept, name.local,
  name.peer) and swift-posix's EINTR-retrying accept wrapper. The fd flows:
  `Kernel.Socket.Create.create → Kernel.Socket.Descriptor` used transiently
  for bind+listen, then `Kernel.Descriptor(consume socket)` at the end of
  init. All subsequent operations (accept, name.local, io.ready) use the
  `Kernel.Descriptor` overloads.
- **(b) Keep `_fd: Kernel.Socket.Descriptor`**, restructure the accept-loop
  to avoid needing both borrowing views simultaneously. Not feasible: each
  call independently requires a borrow of the shared stored fd in its
  required type.
- **(c) Add `Kernel.Socket.Descriptor.kernelDescriptor` borrowing view** as
  a cross-type bridge. Forbidden by memory
  `feedback_language_features_over_custom_types` — "never invent
  Raw/Borrow shadow types"; also explicitly called out as prohibited in the
  handoff.

### Decision: (a)

Three load-bearing reasons:

1. **Symmetry with `Sockets.TCP.Connection` and the existing accept
   boundary.** Connection already stores `Kernel.Descriptor`
   (`Sockets.TCP.Connection.swift:35`) — the codebase has converged on the
   rule "keep socket typing at the syscall entry where socket semantics
   matter; switch to the generic `Kernel.Descriptor` at ownership
   boundaries where it will compose with swift-io." The events-accept
   requirement surfaces the same rule for Listener. Path A makes Listener
   and Connection symmetric rather than divergent.

2. **No shadow views.** The only alternative compatible with language
   semantics is to teach iso-9945's socket ops to accept *either* typed
   descriptor. That is a one-time additive change to iso-9945 (overloads
   sharing identical bodies via `_rawValue`); it respects
   `feedback_language_features_over_custom_types`; and it unblocks every
   future socket consumer (swift-sockets UDP, Unix-domain, UDS) that wants
   to integrate with swift-io, not just this phase.

3. **Minimal blast radius.** The new overloads are trivial — each one
   reads `descriptor._rawValue` via `@_spi(Syscall)` exactly like the
   `Kernel.Socket.Descriptor` overloads already do (see
   `ISO 9945.Kernel.Socket.Accept.swift:49` for the existing pattern).
   Kernel.Descriptor has the matching SPI accessor at
   `Kernel.Descriptor.swift:131`. No public surface change, no behavioral
   change, purely additive. `Kernel.Socket.Descriptor` overloads stay —
   consumers creating a fresh socket via `Kernel.Socket.Create.create` and
   using it transiently before consuming into `Kernel.Descriptor` continue
   to work unchanged (this is exactly what Listener.init will do).

### Scope of iso-9945 / swift-posix changes

Additions required by Path A (purely additive — existing
`Kernel.Socket.Descriptor` overloads stay):

| Package | File | Addition |
|---------|------|----------|
| iso-9945 | `ISO 9945.Kernel.Socket.Bind.swift` | `bind(_ descriptor: borrowing Kernel.Descriptor, address: Storage, length: UInt32)` + IPv4 / IPv6 / Unix convenience overloads |
| iso-9945 | `ISO 9945.Kernel.Socket.Listen.swift` | `listen(_ descriptor: borrowing Kernel.Descriptor, backlog:)` |
| iso-9945 | `ISO 9945.Kernel.Socket.Accept.swift` | `accept(_ descriptor: borrowing Kernel.Descriptor) -> Result` |
| iso-9945 | `ISO 9945.Kernel.Socket.Name.swift` | `local(_: borrowing Kernel.Descriptor)`, `peer(_: borrowing Kernel.Descriptor)` |
| swift-posix | `POSIX.Kernel.Socket.Accept.swift` | EINTR-retrying `accept(_: borrowing Kernel.Descriptor) -> Result` |

Each new overload delegates to its `Kernel.Socket.Descriptor`-typed sibling
via `descriptor._rawValue` or calls the same underlying C function directly;
they do not introduce new error shapes or behavior.

### Listener refactor

```swift
public actor Listener {
    internal let _fd: Kernel.Descriptor    // was: Kernel.Socket.Descriptor
    internal let _io: IO
    // ...
}
```

`Listener.init(address:io:backlog:)` flow:

1. `let socket = try Kernel.Socket.Create.create(domain: .inet, kind: .stream)`
   — still `Kernel.Socket.Descriptor`.
2. `try Kernel.Socket.Bind.bind(socket, address: address)` — existing
   `Socket.Descriptor` overload; transient typed use.
3. `try Kernel.Socket.Listen.listen(socket, backlog: backlog)` — existing
   `Socket.Descriptor` overload.
4. `self.init(fd: Kernel.Descriptor(consume socket), io: io)` — boundary
   conversion. After this point, `_fd` is `Kernel.Descriptor` and all
   subsequent syscalls (accept, port() via Name.local) use the new
   `Kernel.Descriptor` overloads.

`accept()` can then call both `io.ready(from: _fd, interest: .read)` and
`POSIX.Kernel.Socket.Accept.accept(_fd)` on the same stored fd without any
cross-type bridging.

## Decision 3A-2 — Listener fd blocking mode: factory split

### Problem

The fd's blocking mode must match the `IO` strategy's `_ready` semantics.
`IO.swift`'s `_ready` docstring (added Phase 2D) is load-bearing on this:

> **Blocking** — no-op. The subsequent syscall is the actual block; the
> executor thread waits there. Ready-then-syscall composes correctly
> with a no-op ready.

The correctness pairing matrix:

| fd mode | IO strategy | `_ready` | accept(2) | Result |
|---------|-------------|----------|-----------|--------|
| blocking | `IO.blocking()` | no-op | blocks in kernel on empty queue | ✓ correct, 0% CPU idle |
| blocking | `IO.events()` | real wait | returns immediately on ready; can re-block on spurious wakeup | partial — rare hang risk |
| blocking | `IO.completions()` | real wait | same | partial — rare hang risk |
| non-blocking | `IO.blocking()` | no-op | returns EAGAIN immediately on empty queue | ✗ **hot-spin, 100% CPU** |
| non-blocking | `IO.events()` | real wait | returns immediately on ready | ✓ correct |
| non-blocking | `IO.completions()` | real wait | same | ✓ correct |

The "always non-blocking + EAGAIN-retry" sketch I proposed in the prior
revision of this doc is a correctness regression: it moves the
blocking-strategy path out of the "sleep in kernel" row and into the
"hot-spin 100% CPU" row. That is an unacceptable regression vs Phase 2A,
which inherits the blocking-in-kernel behavior implicitly because the fd
has never been set non-blocking.

### Options considered

- **(i) `nonBlocking: Bool` init param** (default `false`). One ctor,
  consumer chooses. Minimally disruptive to Phase 2A. The mismatch risk
  (consumer picks `nonBlocking: true` but passes `IO.blocking()`, or
  vice-versa) is visible only in the docstring — compiler cannot
  enforce the pairing.

- **(ii) Factory split** — `Sockets.TCP.Listener.blocking(...)` and
  `Sockets.TCP.Listener.reactive(...)`. Each factory sets the fd mode
  that matches the strategy it's named after; the existing
  `init(address:io:backlog:)` is removed in favor of the two named
  factories. Still cannot compiler-enforce the io-to-factory pairing
  (a consumer can pass `IO.blocking()` to `.reactive(...)` and recreate
  the hot-spin), but the factory name makes the intent explicit at the
  call site, matches the pattern set by `IO.blocking()` /
  `IO.events()` / `IO.completions()`, and is discoverable via
  autocomplete.

- **(iii) Unify `_ready` on the blocking strategy** so its actor does
  `poll(2)` (or equivalent) on the fd and returns when the fd is ready.
  Then the fd can stay in blocking mode under every strategy, the
  witness contract becomes uniform ("ready always really waits"), and
  there is no pairing problem to solve. Cost: reworks `IO.Blocking.Actor`,
  supersedes the Phase 2D `_ready` docstring, and re-gates swift-io tests
  on both platforms. This is Phase 2E scope — a clean architectural
  resolution that does not belong inside Phase 3A.

### Decision: (ii) factory split. Flag (iii) as Phase 2E future work.

The blocking-strategy contract from `IO.swift` rules out "always
non-blocking + retry" without compensating work in swift-io itself. Of
the remaining options, (ii) gives the best call-site legibility for a
pairing the compiler cannot enforce: `.blocking(...)` reads as "this
listener sleeps in the kernel" and `.reactive(...)` reads as "this
listener waits on readiness events"; the consumer is one autocomplete
away from picking the right one. (i) is acceptable but inferior — a
Bool parameter does not communicate fd-mode intent as clearly as a
factory name, and the default (`false`) risks consumers adopting
`IO.events()` without remembering to set `nonBlocking: true`.

Option (iii) is the correct long-term resolution: it eliminates the
pairing problem entirely by making the witness contract uniform. But
it touches `IO.Blocking.Actor`, the Phase 2D `_ready` docstring, and
swift-io's test gate on both platforms — cleanly Phase 2E, not Phase
3A. The factory split is the right local fix; (iii) can retire the
factory split in a follow-up by collapsing both factories back to a
single init once fd-mode is irrelevant.

### Listener factory shape

```swift
extension Sockets.TCP.Listener {

    /// Creates a listener whose socket remains in blocking mode.
    ///
    /// The listening fd inherits the kernel's default blocking mode —
    /// `accept(2)` sleeps inside the kernel until a connection arrives.
    /// Intended for `io: IO.blocking()`, where `io.ready(...)` is a no-op
    /// and the subsequent `accept(2)` is the actual wait point.
    ///
    /// ## Strategy pairing
    ///
    /// The factory name communicates the intended pairing; the compiler
    /// cannot verify it. Passing a reactor-backed `IO` (`IO.events()`,
    /// `IO.completions()`, `IO.default()` on a reactor host) is permitted
    /// but semantically off — `io.ready(...)` will wait on kernel
    /// readiness, but the subsequent `accept(2)` on a blocking fd may
    /// re-block on a spurious wakeup (rare; possible under RST-before-accept
    /// and similar edge cases). Use `.reactive(...)` with those strategies.
    public static func blocking(
        address: Kernel.Socket.Address.IPv4,
        io: IO,
        backlog: Kernel.Socket.Backlog = .max
    ) throws(Sockets.Error) -> Sockets.TCP.Listener

    /// Creates a listener whose socket is set to non-blocking mode.
    ///
    /// The listening fd is switched to `O_NONBLOCK` at init time;
    /// `accept(2)` returns `EAGAIN` immediately on an empty queue, and
    /// the accept loop awaits `io.ready(from: _fd, interest: .read)` before
    /// retrying. Intended for reactor-backed `io` — `IO.events()`,
    /// `IO.completions()` (Linux), or `IO.default()` on a reactor host.
    ///
    /// ## Strategy pairing
    ///
    /// Passing `IO.blocking()` causes a hot-spin: `io.ready(...)` is a
    /// no-op under the blocking strategy, so the retry loop burns CPU
    /// until a connection arrives. The factory name exists to make the
    /// pairing legible at the call site; the compiler cannot enforce it.
    /// Use `.blocking(...)` with `IO.blocking()`.
    public static func reactive(
        address: Kernel.Socket.Address.IPv4,
        io: IO,
        backlog: Kernel.Socket.Backlog = .max
    ) throws(Sockets.Error) -> Sockets.TCP.Listener
}
```

The existing `public init(address:io:backlog:)` is **removed** in Phase
3A and replaced by `.blocking(...)` (which has the same body as the
current init, preserving Phase 2A behavior). Existing tests migrate to
`.blocking(...)` at the same time the parameterized cells are added
(see Decision 3A-3).

### Future work (Phase 2E)

`_ready` on the blocking strategy becomes a real primitive (e.g.,
`poll(2)` on the fd until ready, with EINTR retry). After that change:

- The listener's fd can stay in blocking mode under every strategy.
- The factory split collapses back to a single init.
- The witness contract becomes uniform: `_ready` always really waits.

Phase 2E is tracked as a separate deliverable, not a subtask of Phase 3.

## Decision 3A-2a — Test assertion for no blocking-strategy hot-spin

The `.blocking(io: IO.blocking())` cell of the parameterized test matrix
**must** prove that an idle accept does not burn CPU. Wall-clock latency
alone cannot distinguish a thread sleeping in the kernel from a thread
spinning on EAGAIN — both consume identical wall time from "server
calls accept" to "client connects."

Assertion approach: measure process CPU time
(`clock_gettime(CLOCK_PROCESS_CPUTIME_ID)` on POSIX) across a known-idle
window in which the server is waiting in `accept()` and no client has
yet connected. If the blocking path is correct, process CPU delta is
near zero (threads sleep in kernel). If the path regresses to
hot-spinning, process CPU delta approaches wall-clock delta.

Concrete test shape for the `.blocking` + `IO.blocking()` cell:

```swift
async let server = listener.accept()        // enters accept(2); should sleep
let cpuBefore = Kernel.Clock.CPU.Process.now()
try await Task.sleep(for: .milliseconds(50))
let cpuAfter = Kernel.Clock.CPU.Process.now()

// connect the client, let server accept return, complete the echo
// ...

let cpuDelta = cpuAfter - cpuBefore
// Threshold is heuristic — 10% of window is comfortably above normal
// baseline CPU noise (fork/thread startup, test scaffolding). Tighten
// if 3C benchmarks surface a tighter blocking-strategy idle budget. A
// hot-spinning thread alone would burn ~50ms CPU in this window.
#expect(cpuDelta < 5_000_000)   // nanoseconds — 5 ms
```

### Primitive availability (pre-implementation check)

Searched swift-primitives / swift-standards / swift-foundations for
`Kernel.Clock.CPU` and `CLOCK_PROCESS_CPUTIME_ID`: no ecosystem hits
(the matches are all in upstream LLVM / wasi-libc third-party sources).
The existing Clock primitives cover wall-clock (`Kernel.Clock.Continuous`
— `CLOCK_MONOTONIC_RAW` / `CLOCK_BOOTTIME`) and uptime
(`Kernel.Clock.Suspending` — `CLOCK_UPTIME_RAW` / `CLOCK_MONOTONIC`),
neither of which isolates CPU consumption.

Adding a minimal `Kernel.Clock.CPU.Process.now()` wrapper in iso-9945
is in scope for Phase 3A — one file, one function, POSIX-authoritative
(`CLOCK_PROCESS_CPUTIME_ID` is IEEE 1003.1-2001). Available on all
Darwin versions this ecosystem targets and all glibc versions shipped
in Ubuntu jammy/noble (the Linux Docker base images used by swift-io's
gate), so the assertion does not become environment-sensitive. No
L1 shell added — if Windows support is later needed,
`GetProcessTimes`-backed equivalent is promoted to L1 at that point.

### Consumers of the existing Listener init (pre-removal check)

Grep across the full workspace for `Sockets.TCP.Listener(`: only three
hits inside swift-sockets itself — the two Phase 2A integration tests
(`TCP.Listener.Tests.Echo.swift`, `TCP.Listener.Tests.MultipleConnections.swift`)
and a self-reference in the Listener docstring. No external or downstream
consumers. The Phase 3A commit removes the init and migrates those
three sites to `.blocking(address:io:backlog:)` atomically.

## Decision 3A-3 — Test parameterization shape

The existing `Sockets.TCP.Listener.Tests.Echo` and `.MultipleConnections`
hard-code `IO.blocking()` for both server and client. Phase 3A parameterizes
over the four factories:

| Cell | Factory | Platform guard |
|------|---------|----------------|
| `.blocking` | `IO.blocking()` | unconditional |
| `.events` | `try await IO.events()` | unconditional (kqueue on Darwin, epoll on Linux) |
| `.completions` | `try await IO.completions()` | `#if os(Linux)` |
| `.default` | `try await IO.default()` | unconditional |

Parameterized via swift-testing `@Test(arguments:)`. Each cell runs the
full echo round-trip; completions cell is Linux-only per swift-io
constraint #3.

## Known Limitations Surfaced

### Concurrent `io.ready` on the same fd crashes under events/completions

**Discovered**: Phase 3A test parameterization of `MultipleConnections`.
Three concurrent `listener.accept()` calls on one listener fd each
call `io.ready(from: _fd, interest: .read)`. Under the events
strategy, each `io.ready` registers a receiver on the per-fd
`Async.Channel.Unbounded`. The channel enforces a single-suspended-
receiver invariant (`Async_Channel_Primitives/Async.Channel.Unbounded.State.swift:186`);
the second concurrent receiver triggers a precondition failure.

**Not a Phase 3A regression.** The contract was always single-receiver.
Phase 2A's blocking-strategy tests never hit it because the blocking
`_ready` is a no-op and the actor serializes accept calls. The
limitation exists for any consumer that concurrently awaits readiness
on the same fd under events/completions strategies.

**Impact**: A production TCP listener under `IO.events()` or
`IO.completions()` that spawns N accept tasks concurrently will crash.
Single-accept-at-a-time (sequential accept loop) works correctly.

**Resolution**: `IO.Events.Actor` and `IO.Completions.Actor` need
per-operation (not per-fd) channel routing to support concurrent
operations on the same fd. Scope: Phase 2E or Phase 3B, not 3A.

**Phase 3A mitigation**: `MultipleConnections` test stays blocking-only.
Echo parameterization (single accept per cell) covers all four
strategies.

## Changes Required (Phase 3A)

- **iso-9945**: Kernel.Descriptor overloads on Bind / Listen / Accept /
  Name (per table above). `@frozen` on `Kernel.Socket.Accept.Result`
  (user-authorized mid-session).
- **swift-posix**: Kernel.Descriptor overload on POSIX.Kernel.Socket.Accept.accept.
- **swift-sockets**: Listener refactor; `.blocking` / `.reactive` factory
  split; EAGAIN-retry accept loop; parameterized Echo test (4 cells);
  BlockingIdleCPU no-hot-spin CPU assertion; MultipleConnections
  blocking-only.
