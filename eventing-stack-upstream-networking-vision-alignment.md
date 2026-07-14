# Eventing Stack and Upstream Networking Vision Alignment

<!--
---
version: 1.0.0
last_updated: 2026-07-14
status: RECOMMENDATION
---
-->

## Context

Swift's Ecosystem Steering Group published a [Prospective Vision: Networking](https://forums.swift.org/t/prospective-vision-networking/85235)
(Franz Busch, on behalf of the ESG; not yet ESG-reviewed) proposing a decomposed
networking stack built directly on Swift Concurrency ("async/await, structured
concurrency, actors, Sendable, and non-copyable types … open new possibilities for
networking APIs"), including "currency types such as IPAddress". The stated long-range
goal of that direction is native support for eventing in Swift Concurrency, so that
I/O APIs (including file-system APIs) can be built on the Concurrency executors
directly rather than on separate event-loop runtimes. As of 2026-07, the enabling
custom main/global executor work remains pitch-stage (three pitches, none accepted;
staging ground: [swiftlang/swift-platform-executors](https://github.com/swiftlang/swift-platform-executors)),
and the [Standard Network Address types pitch](https://forums.swift.org/t/pitch-standard-network-address-types/82288)
(MahdiBM) has produced the swift-endpoint package with Networking Workgroup interest.

The institute ships a package-level implementation of substantially the same
architecture. This document is a verified alignment inventory and gap register:
where the shipped stack already embodies the upstream direction, where it does not,
and what must be true before the stack serves as public evidence in that conversation.

Trigger: a 2026-07-14 validation pass over the eventing/IO/networking packages
against the published upstream vision. Skills loaded per [RES-033]: research-process.
Internal prior research consulted per [RES-019]: the io_uring suite
(`io-uring-swift-feature-inventory.md`, `linux-io-uring-api-reference.md`, four
implementation studies), `witness-uniformity-vs-strategy-specialization.md`,
`stream-isolation-preserving-operators.md`, and
`swift-executors/Research/executor-package-design.md` (per-package corpus).

## Question

Where does the institute's shipped eventing/IO/networking stack align with, exceed,
or fall short of the upstream networking vision — and which gaps gate presenting the
stack publicly as evidence for that direction?

## Analysis

### A. Verified alignment inventory

All findings `Verified: 2026-07-14` against live source.

| Asset | What it is | Evidence |
|---|---|---|
| `Kernel.Thread.Executor.Polling` | Serial executor whose **wait primitive is a kernel event source** (epoll/kqueue); run loop interleaves job drain with blocking poll; typed-throws error delivery to a consumer tick | `swift-executors/Sources/Executors/Kernel.Thread.Executor.Polling.swift:14` |
| `Kernel.Thread.Executor.Completion` | Proactor sibling owning a `Kernel.Completion` resource (io_uring) | `swift-executors/Sources/Executors/Kernel.Thread.Executor.Completion.swift` |
| `Event.Actor` | "The actor IS the event loop": pinned via `unownedExecutor` to the Polling executor; tick uses `assumeIsolated`, validated by `isIsolatingCurrentContext()`; consumers pin their own actors for zero-hop I/O | `swift-io/Sources/IO Events/Event.Actor.swift:5-13` |
| `Completion.Actor` | "The actor IS the proactor": io_uring submissions with a both-CQE cancellation handshake (`IORING_OP_ASYNC_CANCEL`) preserving buffer ownership | `swift-io/Sources/IO Completions/Completion.Actor.swift:5-23` |
| `IO<Capabilities>` strategy witness | One capability surface; blocking / readiness / completion as swappable strategies; domain policy decides validity per domain | `swift-io/Sources/IO`, `swift-file-system/Sources/File System/IO+File.System+Default.swift:6-9` |
| File-system domain policy | Readiness is structurally invalid for regular files (always epoll/kqueue-ready); chain is completions → blocking | `IO+File.System+Default.swift:6-9` |
| `swift-sockets` | TCP listener actor (executor-forwarding), `~Copyable` connections (consuming `close()`, borrowing half-close), UDP endpoints; strategy-parametric over `IO<Sockets.Capabilities>` | `swift-sockets/Sources/Sockets/Sockets.TCP.Connection.swift:47` |
| `Executor.Cooperative` | Caller-thread run loop for deterministic tests/simulation | `swift-executors/Sources/Executors/Executor.Cooperative.swift` |
| Address/DNS vocabulary | `swift-rfc-791` (full IPv4 header vocabulary, per-field typed errors, Standard Library Integration leaf), `swift-rfc-4291`/`swift-rfc-8200` (IPv6), `swift-ipv4-standard`/`swift-ipv6-standard` composition packages, `swift-rfc-1034/1035` + `swift-domain-name-system` (DNS lane) | `swift-ietf/swift-rfc-791/Sources/RFC 791/` |

The stack demonstrates, on today's Swift (SE-0417 task executors, SE-0424
`isIsolatingCurrentContext`), the model the vision targets: actor isolation and the
event loop as the same compiler-verified thread, with I/O built on executors
directly. It is a package-level existence proof of the upstream direction — built
*on top of* the language, where the vision wants the capability *in* the language.

### B. Gap register

| # | Gap | Class | Evidence (`Verified: 2026-07-14`) |
|---|---|---|---|
| G1 | **No Darwin completion backend** — `Kernel.Completion.platform()` is io_uring-on-Linux or `throw .unsupportedPlatform`; file-system eventing is therefore Linux-only, Darwin falls back to the blocking pool | platform | `swift-kernel/Sources/Kernel Completion/Kernel.Completion+Platform.swift:24-31` |
| G2 | **No Windows eventing at all** — `Polling`, `Completion`, `Event.Actor`, `Completion.Actor` are `#if !os(Windows)`-gated; the `Kernel.Thread.Executor.IOCP` sibling is planned (executor-package-design.md Decision #6) but unbuilt | platform | `Kernel.Thread.Executor.Polling.swift:5-9` |
| G3 | **Sockets readiness strategy unwired** — `IO+Blocking.swift` is the sole strategy factory for `Sockets.Capabilities`; readiness is designed-for but not shipped | integration | `swift-sockets/Sources/Sockets/IO+Blocking.swift:33,46` |
| G4 | **Timer executor quarantined** — `Executor.Scheduled` (deadline-scheduled enqueue) wholly carved out since 2026-06-12 pending the priority-queue/heap round; the eventing story currently has no timer leg | integration | `swift-executors/Sources/Executors/Executor.Scheduled.swift:6-13` |
| G5 | **io_uring path-ops fallback** — `open`/`stat`/`close` run on the blocking executor even under the completions strategy; `Submission.Opcode` lacks `.openat`/`.statx` | integration | `IO+File.System+Default.swift:26-29` |
| G6 | **CI hygiene bifurcated on the eventing set** — red: swift-io (Windows leg since 2025-12-30), swift-sockets (4 legs since 2026-01-28), swift-kernel (since 06-30), swift-executors (since 07-09, upstream one-file dependency break); green: swift-file-system, swift-rfc-791, swift-ipv4/6-standard. Red badges undercut the stack's use as public evidence | hygiene | internal CI census 2026-07-14; publicly visible per-repo Actions |
| G7 | **Two sources of truth for IP addresses in-house** — `iso-9945`'s `Kernel.Socket.Address.IPv4/IPv6` vs `swift-ipv4-standard`/`swift-ipv6-standard`; reconciliation already tracked internally. `swift-ip-address` (L3) is a thin exports-only composition | architecture | internal backlog row "IPv4/IPv6 L2 reconciliation" |
| G8 | **Address-types lane has an incumbent** — swift-endpoint (SIMD/SWAR-optimized, Workgroup interest). The institute's differentiated contribution there is the per-RFC spec-mirroring architecture (per-field typed errors, Foundation-free, integration-leaf pattern) as design input, not a competing currency type | positioning | pitch thread 82288 |

### C. Vision component ↔ institute state

| Vision component | Institute state | Gaps |
|---|---|---|
| Eventing in Concurrency executors | Shipped (readiness + completion executors, actor pinning) | G1, G2 (platforms), G4 (timers) |
| File-system APIs on executors | Shipped on Linux/io_uring; blocking-pool elsewhere | G1, G2, G5 |
| Networking on Concurrency | TCP/UDP shipped on blocking strategy; readiness seam built | G3, G6 |
| Currency types (IPAddress etc.) | Full per-RFC vocabularies + composition standards | G7, G8 |
| Non-copyable types in I/O APIs | Shipped throughout (`~Copyable` connections, descriptors, ring ownership) | — |

## Outcome

**Status**: RECOMMENDATION

1. The stack is presentable as a working, strict-concurrency-clean existence proof of
   the vision's eventing direction — with the platform honesty that evented file I/O
   is Linux-only today and Windows eventing is absent. Claims should be framed as
   "built your target architecture as packages; here are the learnings," never as
   "already does what the vision wants" (venue and platform coverage differ).
2. Forum engagement belongs on the two live threads (vision 85235; address types
   82288). On address types, contribute spec-mirroring architecture learnings and
   review input rather than positioning institute IP types against swift-endpoint.
3. Remediation order (tracked internally): G6 hygiene on the showcase set first
   (gates everything public), then G3 (sockets readiness — the natural next slice and
   the strongest demo), then G5/G4; G1/G2 are platform programs, with G2 (IOCP)
   having independent demand from downstream Windows consumers.
4. Residual — directions, not premises ([RES-027]): (a) evaluate Darwin completion
   backend options (POSIX AIO / dispatch-I/O / pool-emulated completion) before
   committing G1's remediation shape; (b) IOCP executor design (G2) should reuse the
   `Executor.Wait` primitive seam per executor-package-design.md. The one
   load-bearing premise used above — readiness eventing is invalid for regular
   files — is backed by shipped domain policy (`IO+File.System+Default.swift:6-9`).

## References

- [Prospective Vision: Networking](https://forums.swift.org/t/prospective-vision-networking/85235) — forums 85235
- [[Pitch] Standard Network Address types](https://forums.swift.org/t/pitch-standard-network-address-types/82288) — forums 82288
- [Announcing the Networking Workgroup](https://www.swift.org/blog/announcing-networking-workgroup/) · [Networking Workgroup charter](https://www.swift.org/networking-workgroup/)
- [swiftlang/swift-platform-executors](https://github.com/swiftlang/swift-platform-executors)
- Internal: `io-uring-swift-feature-inventory.md`, `linux-io-uring-api-reference.md`,
  `witness-uniformity-vs-strategy-specialization.md`,
  `stream-isolation-preserving-operators.md`,
  `swift-executors/Research/executor-package-design.md`
