# ~Copyable Closure Capture Consumption Relaxation

<!--
---
title: ~Copyable Closure Capture Consumption Relaxation
status: IN_PROGRESS
tier: 2
created: 2026-03-31
applies_to: [swift-async-primitives, swift-io, swift-ownership-primitives]
---
-->

## Context

Non-escaping closures in Swift cannot consume a `~Copyable` capture without reinitializing it, even when the callee guarantees total consumption. This forces an `Ownership.Slot` heap allocation per closure invocation in patterns like `withLock { state in state.send(consuming element) }`.

## Question

Can the closure capture reinitialization rule be relaxed for non-escaping closures where the consuming callee guarantees total consumption? If so, would a Swift Evolution pitch eliminate the Slot-per-send overhead?

## Analysis

**Current behavior**: The compiler sees a captured `~Copyable` value passed to a `consuming` parameter inside a closure body. It requires the capture to be reinitialized after the consuming call, regardless of:
- Whether the closure is `@escaping` or non-escaping
- Whether the consuming function is total (guaranteed to consume on all paths)
- Whether the capture is consumed exactly once on all lexical paths

**The workaround**: Stage through `Ownership.Slot` (a `@unchecked Sendable` class wrapper). The Slot is `Copyable`, so closure capture is unaffected. The `~Copyable` element is stored in the Slot before the closure, then `.take()`'d inside.

**Cost of workaround**: One class allocation + two atomic CAS operations per send on the fast path (Slot init + take). For high-throughput channels, this is measurable.

**Possible relaxation**: If the compiler could verify that a non-escaping closure consumes a capture exactly once on all paths (no reinitializing, no skipping), the capture could be allowed to move through without Slot wrapping. This would require:
1. Extending the move checker to track closure captures through non-escaping calls
2. Possibly a new attribute or inference rule for "totally consuming" closures

## Outcome

*Pending investigation — requires compiler expertise to assess feasibility.*

## References

- [MEM-COPY-006] Category 6 — documents the limitation and workaround
- [MEM-OWN-010] — ecosystem pattern that works around this
- [IMPL-070] — end-state coroutine pattern that avoids closures entirely
- 2026-03-27-async-channel-noncopyable-restructure.md — discovery session

## Update: Apple HTTP API Proposal (2026-04-02)

Apple's codebase uses the `Optional`-take trick as a production pattern in `AsyncWriter.swift` (lines 123-140):

```swift
public mutating func write(_ element: consuming WriteElement) async throws(WriteFailure) {
    // Since the element is ~Copyable but we don't have call-once closures
    // we need to move it into an Optional and then take it out once. This
    // also makes the below force unwrap safe
    var opt = Optional(element)
    do {
        try await self.write { outputSpan in
            outputSpan.append(opt.take()!)
        }
    } catch { ... }
}
```

This is now the accepted industry workaround, not just a temporary measure. Apple's own comment explicitly names the root cause ("we don't have call-once closures") and the pattern (`Optional` + `take()`). The Swift Institute's `Ownership.Slot` serves the same purpose but with `@unchecked Sendable` for cross-isolation transfer; Apple's variant is simpler because the closure is non-escaping and isolation transfer is not needed at this call site.

The relaxation pitch remains worthwhile — the `Optional` wrapper adds a branch and a byte of storage — but the urgency is reduced given that Apple has normalized this pattern in their reference implementation.

**Source**: `/Users/coen/Developer/apple/swift-http-api-proposal/Sources/AsyncStreaming/Writer/AsyncWriter.swift:123-140`
