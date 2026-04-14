# Concrete Async Operator Types (Option C)

<!--
---
title: Concrete Async Operator Types
status: DEFERRED
tier: 2
created: 2026-03-31
last_updated: 2026-04-13
applies_to: [swift-async-primitives, swift-async]
---
-->

## Context

`Async.Stream` requires `Element: Sendable`, which prevents non-Sendable elements from flowing through async pipelines. Research document `async-stream-sendable-requirement.md` analyzed 4 options and recommended Option C: a two-tier architecture with concrete operator types.

## Question

When and whether to implement the ~20 concrete async operator types that would enable non-Sendable elements and isolation preservation in async pipelines?

## Analysis

**Option C**: Replace the generic `Async.Stream<Element: Sendable>` pipeline with concrete operator types (e.g., `Map<Upstream, Output>`, `Filter<Upstream>`, `FlatMap<Upstream, Output>`) that preserve the upstream's isolation and Sendable characteristics.

**Prior art**: The `stream-isolation-preservation` experiment (2026-02-25) proved that concrete types preserve isolation while `@Sendable` closures break it. 13 test variants confirmed.

**Trade-offs**:
- Pro: Enables non-Sendable elements, preserves isolation, type-safe composition
- Con: ~20 concrete types to implement, binary size increase, complexity for users

**Prerequisite**: `Async.Mutex` `sending` refactor (eliminate the Sendable constraint cascade first).

## Outcome

*Pending prioritization — the prerequisite Mutex refactor must complete first. The concrete types are a medium-term investment.*

### Deferred

- **Blocker**: Async.Mutex sending refactor must complete first
- **Resumption trigger**: Mutex refactor completion

## References

- `Research/async-stream-sendable-requirement.md` — full analysis of 4 options
- `Experiments/stream-isolation-preservation/` — 13-variant experiment confirming isolation behavior
- 2026-03-30-sending-sendable-migration-cascade.md — discovery session
