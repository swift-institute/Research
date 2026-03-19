# swift-io: Typed Lane Index Migration

## Context

swift-io's sharded lane subsystem uses raw `Int` for lane indices throughout its API. This forces `Int → UInt → Ordinal → Tagged<T, Ordinal>` conversion chains at every array subscript site. Per [IMPL-010], the `Int` boundary should not exist — the API should use typed indices end-to-end.

The goal: `threads[lane]` — not `threads[.init(Ordinal(UInt(lane)))]`.

## Current State

The `thread(at: Int)` accessor was added as a stopgap (concentrates the conversion chain in one place). The real fix is to eliminate `Int` from the lane API entirely.

## Package Locations

- swift-io: `/Users/coen/Developer/swift-foundations/swift-io/`
- swift-array-primitives: `/Users/coen/Developer/swift-primitives/swift-array-primitives/`
- swift-kernel: `/Users/coen/Developer/swift-foundations/swift-kernel/`

## Skills to Load

Load these skills before any implementation work:
1. `/Users/coen/Developer/.claude/skills/implementation.md` — [IMPL-002], [IMPL-010], [IMPL-INTENT]
2. `/Users/coen/Developer/.claude/skills/naming.md` — [API-NAME-001], [API-NAME-002]
3. `/Users/coen/Developer/.claude/skills/existing-infrastructure.md` — [INFRA-003], [INFRA-100], [INFRA-103]

## Task

**Inventorize** — no fixes yet — every location in swift-io (and its upstream dependencies if relevant) where `Int` is used for a lane index, thread index, shard index, or similar positional concept that should be a typed `Index` or `Ordinal`.

For each location, report:
- File path and line number
- Current expression
- What typed index it should use
- Whether it's a definition site (parameter, return type, stored property) or a consumption site (subscript, comparison, arithmetic)

## The Int Chain to Trace

Start from these entry points and trace every `Int` that flows through the lane/shard system:

### 1. `IO.Blocking.Lane.Sharded.Selection`
- `Selection.custom((Snapshot) -> Int)` — the custom closure returns `Int`
- `Snapshot.laneCount` returns `Int` (used in `0..<snapshot.laneCount`)
- `Snapshot.queueDepth(_ lane: Int)` takes `Int`
- All other `Snapshot` query methods take `Int`

### 2. `IO.Blocking.Lane.Sharded.Selector`
- `select() -> Int` returns `Int`
- `lane(_ index: Int)` takes `Int`
- `selectLeastLoaded() -> Int` returns `Int`
- Round-robin: `counter: Atomic<UInt64>` → modulo → `Int`
- The `thread(at: Int)` stopgap accessor

### 3. `IO.Blocking.Lane.Sharded.Snapshot.Storage`
- `queueDepth(_ lane: Int)`, `inFlight(_ lane: Int)`, `acceptanceDepth(_ lane: Int)`, `sleepers(_ lane: Int)` — all take `Int`
- `laneCount: IO.Blocking.Lane.Count` — already typed! But used as `Int` downstream
- The `thread(at: Int)` stopgap accessor

### 4. `IO.Blocking.Lane.Sharded+Threads.swift`
- Factory: `make: @Sendable (Int) -> IO.Blocking.Threads` — closure takes `Int`
- `selector.select()` returns `Int`, passed to `selector.lane(Int)`
- NUMA factory: `make: @Sendable (System.Topology.NUMA.Node) -> IO.Blocking.Threads` — this one is fine (uses Node, not Int)

### 5. Upstream: `Array_Primitives_Core.Array<T>.Fixed`
- Subscript takes `Array<T>.Index` = `Tagged<T, Ordinal>`
- `count` returns `Tagged<T, Cardinal>`
- Init closure receives `Array<T>.Index` (already typed!)
- Check: does the Fixed array have a subscript accepting `Ordinal.Protocol`? If not, that's an infrastructure gap in swift-array-primitives.

## Key Design Questions

1. **What should the lane index type be?** Options:
   - `IO.Blocking.Lane.Index` (a typealias for `Tagged<IO.Blocking.Lane, Ordinal>`)
   - `Array<IO.Blocking.Threads>.Index` (same as the array's index type — `Tagged<IO.Blocking.Threads, Ordinal>`)
   - A dedicated `IO.Blocking.Lane.Sharded.Index`

2. **Should `Snapshot` queries accept typed indices?** If so, `Selection.custom` closures must work with typed indices too. The custom closure signature changes from `(Snapshot) -> Int` to `(Snapshot) -> LaneIndex`.

3. **Where does `Int` remain as a genuine boundary?** The `Atomic<UInt64>` round-robin counter is inherently untyped. The conversion from `UInt64 → typed index` happens once in `select()`. The `make:` factory closure currently takes `Int` — should it take a typed index instead?

4. **Does `Array.Fixed` need an `Ordinal.Protocol` subscript?** Currently its subscript requires the full `Tagged<Element, Ordinal>`. If it accepted `Ordinal.Protocol`, any ordinal (bare or tagged) could subscript. This would be an infrastructure addition in swift-array-primitives per [INFRA-003]. Check if `Ordinal Primitives Standard Library Integration` already provides this for stdlib Array but not for the primitives Array.

## Expected Output

A table:

| File:Line | Kind | Current Type | Proposed Type | Notes |
|-----------|------|-------------|---------------|-------|
| ... | parameter | `Int` | `Lane.Index` | ... |
| ... | return | `Int` | `Lane.Index` | ... |
| ... | stored property | `Atomic<UInt64>` | keep (genuine boundary) | ... |

Plus answers to the 4 design questions above, with recommendations.

## Constraints

- Do NOT fix anything — inventory only
- Read every file in the sharded lane subsystem completely
- Trace `Int` usage through call chains — if `select()` returns `Int`, find every caller
- Check swift-array-primitives for infrastructure gaps
- Report per [IMPL-INTENT]: "does this read as intent or mechanism?"
