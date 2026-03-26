<!--
---
title: ~Copyable Types with Unnecessary Synchronization — Ecosystem Audit
version: 1.0.0
status: IN_PROGRESS
created: 2026-03-26
last_updated: 2026-03-26
tier: 2
scope: ecosystem-wide
applies_to: [swift-io, swift-primitives, swift-foundations]
normative: false
---
-->

# ~Copyable Types with Unnecessary Synchronization — Ecosystem Audit

## Context

The swift-io Channel refactoring (2026-03-26) demonstrated that `~Copyable` types with `mutating` methods need no synchronization for stored state — ownership guarantees exclusive access. Replacing an `actor Lifecycle` with a plain stored property yielded a 3x write throughput improvement.

**Source**: Reflection `2026-03-26-channel-lifecycle-actor-removal-ownership-as-synchronization.md`, codified as [IMPL-063].

## Question

How many other `~Copyable` types in the ecosystem use actors, atomics, or locks to protect internal state that ownership already guards? Each instance is a candidate for the same simplification: replace the synchronization primitive with a plain stored property.

## Method

1. Grep all three superrepos for `~Copyable` type declarations
2. For each, check for contained actors, `Atomic<>`, `Mutex<>`, `OSAllocatedUnfairLock`, or similar synchronization types
3. Verify that the access pattern is `mutating`/`consuming` (not `borrowing` with shared access)
4. For confirmed candidates, estimate the performance impact based on usage frequency (hot path vs. cold path)

## Analysis

*Stub — to be completed during a dedicated audit session.*

## Outcome

*Pending investigation.*
