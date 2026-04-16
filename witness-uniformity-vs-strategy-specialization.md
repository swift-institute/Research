---
title: Witness Uniformity vs Strategy Specialization in @Witness Macro Design
version: 0.1.0
status: IN_PROGRESS
tier: 3
created: 2026-04-16
last_updated: 2026-04-16
applies_to:
  - swift-witnesses
  - swift-io
  - swift-sockets
---

# Context

The IO witness pivot landed `IO` as a flat `@Witness` struct of five
`@Sendable` async closures (read, write, accept, close,
unownedExecutor). During review, two structural problems surfaced that
are *not* local to IO: (1) `accept` punts to runtime `ENOTSUP` when the
witness is not socket-backed — a runtime lie that breaks the
witness-uniformity contract; (2) different backends (blocking,
io_uring, IOCP) need different method signatures at the edges (e.g.,
io_uring's submit/cancel, IOCP's IO completion port handles). The
current `@Witness` macro optimizes for uniformity across backends — one
shape, one set of closures, interchangeable at the type level. But the
real-world backends diverge, and uniformity is paid for in runtime
lies or witness bloat. This tension is ecosystem-wide: any `@Witness`
type that composes heterogeneous backends will face it.

# Question

How should the `@Witness` macro and its consuming packages resolve the
witness-uniformity vs strategy-specialization tension? Candidate
directions:

1. **Split witnesses by capability** — `IO` for read/write/close,
   `IO.Socket` for accept; backends conform only to what they support.
   Forces consumers to know which witness they hold.
2. **Optional methods** — the witness can declare a method
   unimplemented, and consumers must check. Keeps one type but
   re-introduces runtime errors.
3. **Strategy-specialized generics** — `IO<Strategy>` where the
   strategy parameter selects which methods exist at compile time.
   Heavier type surface, but honest.
4. **Composition over inheritance** — drop `@Witness`'s flat shape;
   allow multiple small witnesses composed into a consumer's context.

# Prior Work

- `swift-foundations/swift-io/Research/io-architecture.md`
- `swift-foundations/swift-io/Research/io-witness-design-literature-study.md`
- `swift-foundations/swift-io/Research/io-witness-borrowing-async-tension.md`
- `swift-foundations/Research/io-driver-witness-composition.md`
- Source reflection: `swift-institute/Research/Reflections/2026-04-14-io-witness-pivot-review-convergence.md`

# Analysis

_Stub — to be filled in during investigation._

Key sub-questions to work through:

- Which direction does the existing `@Dual` + `@Defunctionalize` pair
  naturally support? The three macros are independent; do they suggest
  a decomposition?
- How does SwiftPM's `Product`/`Target` graph support or fight a
  "one witness per capability" approach?
- Can typed throws encode "not supported" without a runtime lie
  (e.g., `never` for unsupported methods via associated-type
  constraint)?

# Outcome

_Placeholder — to be filled when analysis completes._

# Provenance

Source: `swift-institute/Research/Reflections/2026-04-14-io-witness-pivot-review-convergence.md` action item.
