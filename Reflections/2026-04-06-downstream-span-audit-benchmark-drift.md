---
date: 2026-04-06
session_objective: Audit downstream Channel consumers for raw pointer usage after Span migration
packages:
  - swift-io
status: processed
---

# Downstream Span Audit — Benchmark Drift as Predictable Gap

## What Happened

Picked up HANDOFF-downstream-span-audit.md, which asked for a systematic audit of all
downstream consumers of `IO.Event.Channel.read/write` after the Span migration (commit
6a691f88). The audit covered four scope items:

1. **Call sites within swift-io outside IO Stream** — all Tier 0 consumers (IO.Stream,
   IO.Reader, IO.Writer) already migrated. All test files already migrated.
2. **Imports of IO_Events outside swift-io** — none exist. All 41 files referencing
   IO_Events are inside swift-io.
3. **Per-consumer Span assessment** — one gap: `Benchmarks/io-bench/IO Performance
   Tests/Channel.swift` had 4 call sites still using `UnsafeMutableRawBufferPointer` /
   `UnsafeRawBufferPointer`.
4. **IO Completions path** — confirmed completely separate (`Buffer<UInt8>.Aligned`,
   completion queue submission, no interaction with event-based Channel).

Fixed the 4 benchmark call sites: replaced raw pointer allocations with `[UInt8]` arrays
using `.mutableSpan` / `.span` accessors. Same pattern the tests already use.

## What Worked and What Didn't

The parallel search strategy worked well — launching grep for call sites, imports, and
raw pointer patterns simultaneously surfaced all relevant code in one round. High
confidence in completeness because the audit used multiple search axes (call pattern,
import graph, pointer type names).

Nothing went wrong. This was a clean investigation with a mechanical fix.

## Patterns and Root Causes

Benchmark code drifts from the API it exercises. The benchmarks were written with raw
pointers for performance reasons (manual allocation, no ARC). When the Channel API
migrated to Span, the production code path (IO.Stream) and tests were updated together,
but benchmarks were missed — likely because they live in a separate `Benchmarks/`
directory outside the main `Sources/` and `Tests/` trees, and may not be compiled in the
default `swift build` / `swift test` workflow.

This is a known drift pattern: code that exercises an API but isn't required for the
build or test pass accumulates API staleness silently. The fix is mechanical once found,
but the finding requires intentional audit.

## Action Items

- [ ] **[package]** swift-io: Verify benchmarks compile after Span migration fix (they may need a `swift build` from the Benchmarks/ directory)
