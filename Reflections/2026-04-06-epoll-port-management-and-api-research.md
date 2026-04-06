---
date: 2026-04-06
session_objective: Manage the epoll-to-Kernel.Readiness port and commission IO Events public API research
packages:
  - swift-kernel
  - swift-kernel-primitives
  - swift-linux-primitives
  - swift-io
status: pending
---

# Epoll Port Management and IO Events API Research Review

## What Happened

Acted as manager/reviewer for another agent porting the epoll driver from
`IO.Event.Poll.Operations` (swift-io) to `Kernel.Readiness.Driver+Epoll.swift`
(swift-kernel), completing the platform stack alignment. Also commissioned and
reviewed a Tier 2 research document for the perfect IO Events public API.

**Epoll port (3 repos)**:
- Layer 1: `Kernel.Event.Descriptor` changed from empty enum to `~Copyable` struct
  owning the eventfd. New syscall wrappers in swift-linux-primitives (create, read,
  write, signal, close). Flags type with `.cloexec`, `.nonblock`, `.semaphore`.
- Layer 3: `Driver+Epoll.swift` (429 lines) implementing all 7 invariants.
  `Backend.platformDefault()` and `IO.Event.Driver.epoll()` wired. Dead IO code
  deleted (`Poll.Operations.swift`, `Registry.swift`).
- 361 Darwin tests pass. Linux verification pending (Docker CI).

**Two review cycles**:
1. First review caught three issues: eventfd ownership via raw Int32 (blocking),
   missing `.priority` mapping (bug), and the stale `swift-iso-9945` doc comment.
2. Second review confirmed all three fixed. The `take()` method was removed,
   `Epoll.State` now stores `var eventfd: Kernel.Event.Descriptor?` with
   nil-assignment in drain. Type was restructured to `Kernel.Readiness.Epoll.State`.

**IO Events API research**: Commissioned via branching handoff
(`HANDOFF-io-events-perfect-api.md`). The resulting research document introduces
a 5-tier progressive disclosure (Tier 0: `IO.run` + `IO.Stream` + `IO.Buffer`)
above the existing reactor machinery. Reviewed with 10 findings: Sendable
justification needed strengthening (addTask requires @Sendable, not just sending),
swift-sockets composition path missing, Buffer read semantics unspecified, and
Channel.Writer missing `write(all:)`.

## What Worked and What Didn't

**Worked well**: The management pattern — loading all context upfront (HANDOFF.md,
kqueue reference, IO source of truth, primitives), then reviewing against the 7
invariants and skill conventions. Catching the raw-Int32 ownership violation before
it shipped saved a design precedent that would have propagated.

**Worked well**: The branching handoff format for commissioning research. The 9
design tensions (T1-T9) gave the research agent clear scope. The result was
substantially complete on first delivery.

**Didn't work**: The initial naming discussion (`Kernel.Eventfd` vs
`Kernel.Event.Descriptor`) consumed time. The agent ultimately chose the name
I would have challenged toward — but the existing Error/Flags types already nested
under `Kernel.Event.Descriptor` made the decision path-dependent. This is fine;
the lesson is that naming discussions resolve faster when existing type neighbors
are cited early.

## Patterns and Root Causes

**Pattern: raw values as lifecycle workaround**. The agent's first instinct was
`take() -> Int32` — strip the ~Copyable type and manage the fd manually. This is
the Go/C pattern: extract the raw value, juggle it, reconstruct for cleanup. The
Swift pattern is the opposite: keep the typed owner alive and use raw values ONLY
for operations that structurally can't hold ~Copyable (Sendable closures). The
distinction between "raw value as lifecycle authority" (wrong) and "raw value as
signal path while typed owner lives elsewhere" (acceptable) should be captured as
a skill rule. This is a corollary of [IMPL-064] but more specific.

**Pattern: `addTask` as Sendable forcing function**. The IO Events API review
revealed that `sending` CANNOT replace `Sendable` for task group captures because
`addTask` requires `@Sendable` closures. This means any ~Copyable type that needs
to be moved into a child task MUST be Sendable — `sending` is insufficient. This
is a concrete limitation of the current concurrency model that [IMPL-068]'s
guidance doesn't cover.

**Pattern: poll() allocation asymmetry**. The kqueue driver uses scratch buffer
rebound; the epoll driver allocates a fresh array every poll cycle because
`Kernel.Event.Poll.wait` takes `inout [Event]`. This is a primitives API gap,
not a driver bug — the epoll primitives need a buffer-pointer overload.

## Action Items

- [ ] **[skill]** memory-safety: Add rule for raw values in ~Copyable contexts — raw fd/Int32 MUST NOT be the lifecycle authority. Acceptable only as a signal/operation path when the ~Copyable owner lives in typed storage (class property, state struct). Cite the eventfd pattern as canonical example.
- [ ] **[skill]** implementation: Strengthen [IMPL-068] with the `addTask` forcing function — `sending` cannot replace `Sendable` for structured concurrency captures (`addTask`, `async let`). ~Copyable types moved to child tasks MUST be Sendable.
- [ ] **[package]** swift-linux-primitives: Add buffer-pointer overload to `Kernel.Event.Poll.wait` for scratch buffer rebound in poll(), matching kqueue's zero-allocation hot path.
