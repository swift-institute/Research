# Audit Report: swift-async-primitives & swift-pool-primitives

<!--
---
date: 2026-02-24
status: active
packages: [swift-async-primitives, swift-pool-primitives]
---
-->

## Executive Summary

Both packages are architecturally sound — pure state machines, deferred resumption, ~Copyable ownership enforcement, typed throws, Nest.Name compliance. The core async infrastructure (channels, broadcast, waiters) and pool machinery are production-quality.

The highest-value refactor opportunities cluster in two areas:
1. **Timer.Wheel** (async-primitives) — entirely untyped, pre-dates the typed infrastructure
2. **Slot indexing** (pool-primitives) — `Tagged<Self, Int>` with `.rawValue` at 30+ call sites

---

## swift-async-primitives

### Current State

**50 source files, 6 test files.** Dependencies: buffer, dictionary, queue, handle, identity, kernel, ownership primitives.

**What's clean (no action needed):**
- Channels (Bounded/Unbounded): pure state machines, ~Copyable receivers, Copyable senders, typed throws, deferred resumption outside locks
- Broadcast: §5.3 cancellation-safe, token-matching, `Dictionary.Ordered` for subscribers
- Waiters: ~Copyable entries with consuming `resumption(with:)`, `Flag` with atomic CAS
- Waiter.Queue.Bounded/Unbounded: delegates to `Buffer.Ring` infrastructure
- Zero `.rawValue` chains in non-timer code
- Nested accessors: `.send.immediate()`, `.receive.immediate()`, `.front.take`, `.back.push`
- Platform conditioning for embedded Swift

### Findings

#### Finding 1: Timer.Wheel — Entirely Untyped (HIGH VALUE)

**Location:** `Async.Timer.Wheel.Storage.swift:37`

Storage uses raw `UInt32` indices, `[Node?]` stdlib arrays, a manual free-list with `UInt32.max` sentinel, and `Int(index)` conversions at 20+ call sites.

| Current | Violation | Should Be |
|---------|-----------|-----------|
| `nodes: [Node?]` | Raw stdlib array | `Buffer.Slab` or typed storage |
| `freeLinks: [UInt32]` | Manual free-list | `Buffer.Slab` manages this internally |
| `freeHead: UInt32` | Raw sentinel | Slab allocator API |
| `capacity: Int` | Raw count | `Index<Node>.Count` or `Cardinal` |
| `generation: UInt32` | Raw counter | `Tagged<Generation, UInt32>` |
| `nodes[Int(index)]` (20+ sites) | [IMPL-010] Int conversion at call site | Typed subscript |
| `for i in 0..<(capacity-1)` | [IMPL-033] Manual loop | Bulk initialization |

**Refactor target**: Replace Storage with `Buffer.Slab` from swift-slab-primitives. Slab is a free-list backed allocator with typed indices — it *is* the abstraction Timer.Wheel.Storage hand-rolls. The slab manages allocation, deallocation, generation tracking, and typed access. This would eliminate ~100 lines of manual infrastructure and 20+ `Int()` conversions.

If `Buffer.Slab` doesn't fit the generation/ABA pattern exactly, the minimum fix is:
- `Tagged<Node, UInt32>` for slot indices
- Typed subscript accepting that index
- Push `Int(index)` into one boundary overload

**Status:** [ ] Not started

---

#### Finding 2: Timer.Wheel.Tick — Raw Arithmetic

**Location:** `Async.Timer.Wheel.Tick.swift:51-52`

`Tick = UInt64` with raw bit-shift arithmetic. The arithmetic is inherently low-level (bit manipulation for hierarchical wheel indexing), so some rawness is principled. However:

- `currentSlot(level:) -> Int` and `slot(for:delta:) -> Int` return raw `Int`
- `level(for:) -> Int` returns raw `Int`
- `config.slots`, `config.slotShift`, `config.slotMask` are all raw `Int`

**Refactor target**: Introduce `Wheel.SlotIndex` and `Wheel.LevelIndex` typed wrappers. Keep the bit arithmetic inside those types' implementations. Moderate value — the Timer is internal infrastructure, not a public API consumed elsewhere.

**Status:** [ ] Not started

---

#### Finding 3: Test Coverage Gaps

No tests for: Timer.Wheel, Waiter.Queue variants, Bridge, Barrier, Completion, Promise, Lifecycle, Mutex+Deque utilities. Only channels and broadcast have dedicated tests.

**Status:** [ ] Not started

---

## swift-pool-primitives

### Current State

**31 source files, 7 test files (60+ tests).** Dependencies: async, buffer, stack, array, dimension, ownership, effect, index, collection primitives.

**What's clean (no action needed):**
- Nest.Name throughout (`Pool.Bounded`, `Pool.Acquire`, `Pool.Lifecycle.Precedence`)
- Nested accessors: `pool.acquire.try { }`, `pool.acquire.timeout(.seconds(5)) { }`, `pool.fill.batch { }`
- One type per file
- Typed throws: `throws(Pool.Lifecycle.Error)`, `throws(Pool.Error)`, `throws(Fill.Error)`
- ~Copyable resources: full support, `Ownership.Slot<Resource>` for storage
- Two-phase commits: decisions under lock, execution outside
- LIFO free-list via `Stack<Slot.Index>.Bounded` (from stack-primitives)
- FIFO waiter queue via `Async.Waiter.Queue.Unbounded`
- Effect/Action pattern with `perform(_:)` funnel
- No Foundation imports

### Findings

#### Finding 4: Slot.Index = Tagged<Self, Int> — rawValue at 30+ sites (HIGH VALUE)

**Location:** `Pool.Bounded.Slot.swift:9`

`Pool.Bounded.Slot.Index` is `Tagged<Self, Int>` — using raw `Int` as the raw value instead of `Ordinal`. This forces `.rawValue` at 30+ call sites:

```swift
slots[index.rawValue].state           // 2 sites in State
entries[slotIndex.rawValue].move.out   // 22+ sites across Acquire, Try, Timeout, Callback, Fill, Shutdown
slots[slotIndex.rawValue].state        // 8+ sites for state checks
```

Every one of these violates [PATTERN-017] (`.rawValue` confined to boundary overloads) and [IMPL-002] (typed operations at call sites).

**Refactor target**: Change `Slot.Index` to `Tagged<Self, Ordinal>` (or `Index<Slot>`). Then provide:
1. A typed subscript on `[Slot]` and `[Entry]` accepting `Slot.Index`
2. Use `Array[_ position: Ordinal]` from Ordinal Primitives Standard Library Integration [INFRA-003]

This eliminates 30+ `.rawValue` sites with a single subscript overload. Highest density improvement in either package.

**Status:** [ ] Not started

---

#### Finding 5: State Init — Conversion Chain

**Location:** `Pool.Bounded.State.swift:63-64`

```swift
let slotCapacity = Stack<Slot.Index>.Index.Count(
    __unchecked: (), Cardinal(UInt(capacity))
)
```

Three-deep conversion chain (`Int → UInt → Cardinal → Count`) at a call site. Violates [IMPL-002] and [PATTERN-021].

**Fix**: Use the `Int` → `Cardinal` bridge from [INFRA-002]: `try! Index<Slot.Index>.Count(capacity)`.

**Status:** [ ] Not started

---

#### Finding 6: Raw Counters in State

**Location:** `Pool.Bounded.State.swift:49-57`

```swift
var outstanding: Int
var creating: Int
var disposing: Int
```

And in Metrics: `checkedOut`, `available`, `waiters` are raw `Int` with `+= 1` / `-= 1`.

Per [IMPL-006], stored properties holding quantities should use typed wrappers. However, these are internal counters in a ~Copyable state struct — the blast radius is contained within `transition()`.

**Assessment**: Low-to-moderate value. Conscious technical debt — contained blast radius.

**Status:** [ ] Deferred (conscious debt)

---

#### Finding 7: Metrics uses mixed Int/UInt64

```swift
metrics.timeouts += UInt64(timeoutCount)
```

Inconsistent but contained.

**Status:** [ ] Deferred

---

## Refactor Priority Matrix

| # | Package | Finding | Value | Effort | Recommendation |
|---|---------|---------|-------|--------|----------------|
| 1 | pool | Slot.Index `.rawValue` at 30+ sites | **High** | Low | Add typed subscript on `[Slot]`/`[Entry]`. Single overload eliminates 30+ violations. |
| 2 | async | Timer.Wheel.Storage hand-rolls slab | **High** | Medium | Replace with `Buffer.Slab` from swift-slab-primitives, or type the indices. |
| 3 | async | Timer.Wheel 20+ `Int(index)` conversions | **High** | Low | Typed index + typed subscript. Falls out of Finding 2 naturally. |
| 4 | pool | State init conversion chain | **Low** | Trivial | Use `try! Index.Count(capacity)` bridge. |
| 5 | async | Timer types raw `Int` for level/slot | **Moderate** | Low | `Tagged<Level, Int>`, `Tagged<SlotIndex, Int>` wrappers. |
| 6 | pool | Raw counters in State | **Low** | Moderate | Conscious debt — contained blast radius. |
| 7 | async | Test coverage (Timer, Waiter, Bridge, etc.) | **Moderate** | High | Significant work but reduces regression risk. |

---

## Compliance Summary

| Rule | async-primitives | pool-primitives |
|------|-----------------|-----------------|
| [API-NAME-001] Nest.Name | Pass | Pass |
| [API-NAME-002] No compounds | Pass | Pass |
| [API-ERR-001] Typed throws | Pass | Pass |
| [API-IMPL-005] One type/file | Pass | Pass |
| [PRIM-FOUND-001] No Foundation | Pass | Pass |
| [IMPL-INTENT] Code reads as intent | Pass (except Timer) | Pass (except subscripts) |
| [IMPL-002] Typed arithmetic | **Fail** (Timer: 20+ raw) | Pass |
| [IMPL-010] Push Int to edge | **Fail** (Timer: 20+ sites) | **Fail** (30+ `.rawValue` sites) |
| [IMPL-033] Iteration intent | **Fail** (Timer: manual loops) | Pass |
| [PATTERN-017] rawValue confined | Pass (non-timer) | **Fail** (30+ sites) |
| [INFRA-106] Property accessors | Pass | Pass (nested accessor pattern) |
| [INFRA-109] Storage primitives | **Fail** (Timer hand-rolls) | Pass (uses Ownership.Slot) |
