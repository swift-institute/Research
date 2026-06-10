# Deque / Ring / Bounded-Queue Archaeology

<!--
---
version: 1.0.0
last_updated: 2026-06-10
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

R5 of the post-archaeology research arc: ring-buffer and bounded-queue prior art (swift-collections
`Deque` + its move-only twins; swift-nio `CircularBuffer`; stdlib absence), mapped onto the tower's
shipped `Buffer.Ring` (W3b `6bb2685`) and the queue family the ADT executor landed mid-arc
(`Queue<S: Store.Protocol & Buffer.Protocol & ~Copyable>: ~Copyable`, `Queue.swift:46`;
`Deque = Queue.DoubleEnded` in swift-deque-primitives). Because the family already shipped, R5 lands as
**validation + gap analysis** rather than pre-design. Pins: swift-collections @
`af174fe4476842b2558069e64feae8ddc2e665ff` (main HEAD, unmoved); swift-nio @ `7586225b`; stdlib
worktrees 632/64x/main as in the parent doc. [RES-020] verification: 8/8 web claims re-derived; local
claims spot-checked first-hand.

## Question

How do the production Swift rings represent wrap-around, tear down two segments, and handle
append-at-capacity — and does the tower's ring/queue family match, diverge deliberately, or miss
anything?

## Headline findings

1. **Layout consensus, three ways.** Both swift-collections generations share one layout: header
   `{capacity, count, startSlot}` + wrap-around materialized lazily as **≤2 segments**
   (`_DequeBufferHeader.swift:14–23`; `segments()` split). No power-of-two constraint, no `Optional`
   boxing. The tower's `Buffer.Ring` is the same family — `Header { head, count, capacity }`
   (`Buffer.Ring.Header.swift:18–26`) with the two linearized runs carried in the **typed initialization
   ledger** (`.one(range)` / `.two(first:second:)`, `Store.Initialization.swift:20–34`) rather than
   ad-hoc segment math. swift-nio's `CircularBuffer` is the divergent third design: power-of-two mask
   wrapping over `ContiguousArray<Element?>` (`CircularBuffer.swift:19–20,54–56`) — teardown delegated
   to ARC by nil-ing slots, CoW inherited from the array. That is the tombstone/`Optional` form the
   occupancy-encoding panel already characterized: simplicity bought with per-slot niche/boxing and
   Copyable-only elements. [Verified: 2026-06-10]

2. **Teardown converges on ledger-driven, two-region, exactly-once — at three different owners.**
   s-c CoW `Deque`: the storage **class** deinit drains one-or-two regions explicitly
   (`_DequeBuffer.swift:17–34` — and `_DequeBuffer` is literally a `ManagedBuffer<_DequeBufferHeader,
   Element>` subclass: R-5's drain-box at the deque substrate). Move-only `RigidDeque`: **struct**
   deinit → `consuming dispose()` = `mutableSegments().deinitialize(); _buffer.deallocate()`
   (`RigidDeque.swift:135–137`; `_UnsafeDequeHandle.swift:46–51`). The tower goes one step further per
   the occupancy law: the ring itself carries **no element deinit** — drains run through the seam with
   the header's run-arithmetic, and the leaf oracle backstops (the seven
   `storage.initialization = header.initialization` sync sites are the ring ledger rule in source form).
   All three agree on the invariant the family docs should state: *teardown is segment/ledger-driven and
   two-region-aware; nothing scans capacity.* [Verified: 2026-06-10]

3. **The bounded-policy census — and the tower's deliberate inversion.** Append-at-capacity across the
   surveyed rings: s-c `Deque` grows (CoW, 1.5× — `(3 &* capacity &+ 1) &>> 1`,
   `Deque._Storage.swift:165`); `UniqueDeque` grows (move, 1.5×); NIO grows (2×,
   `_doubleCapacity()` when head==tail); `RigidDeque` **traps** on `append`
   (`precondition(!isFull, "RigidDeque capacity overflow")`) and offers **rejection** as the secondary
   surface (`pushLast(_:) -> Element?` — "returns the given item without appending it", carrying a
   `// FIXME: Remove this in favor of a standard algorithm`). The tower's `Buffer.Ring.Bounded` inverts
   that hierarchy: **rejection-first at the public surface** (typed
   `Error.capacityExceeded`, `Buffer.Ring.Bounded.Error.swift:5`; push-returns-element), with the seam's
   `initialize` trapping at capacity as the unchecked lane ("growth is the column's affair",
   `Buffer.Ring.Bounded+Store.Protocol.swift:26–27`). That is a deliberate [API-ERR-001]-driven
   divergence, now documented against the upstream contrast rather than silently. [Verified: 2026-06-10]

4. **Drop-oldest is an open niche — everywhere.** No surveyed Swift ring ships overwrite/evict-oldest
   semantics (the classic bounded telemetry/sliding-window ring): grep + code-search absence across s-c
   DequeModule, NIO, and the tower's ring package. Every full-state behavior in the ecosystem is grow,
   trap, or reject. Recorded as an open variant cell (lattice-position note per [RES-020a]) — a
   future `Ring`-column policy variant if a real consumer (telemetry, bounded logs, sampling windows)
   materializes; not proposed now.

5. **Stdlib ships nothing here, and the trajectory is the s-c twins.** No deque/ring container exists on
   any pinned ref (the only grep hit is a `// FIXME: <rdar://21885650> Create reusable RingBuffer<T>`
   local-variable comment in `Sequence.suffix`, main `Sequence.swift:1042–1046`); SE-0527's future
   directions names `RigidDeque`/`UniqueDeque` as potential stdlib additions. No naming collision with
   the tower's nested spellings (no bare `UniqueArray`/`RigidArray`/deque identifiers in institute code
   — grep-verified).

## Validation of the shipped family (what R5 confirms)

- **The split is upstream-convergent.** Growable-vs-bounded as separate columns + CoW via the explicit
  `Shared` column mirrors the upstream split (growable CoW `Deque` / move-only `Unique`/`Rigid` pair) —
  with the tower's improvement that one generic `Queue<S>`/`Queue.DoubleEnded<S>` covers all four cells
  via the column (s-c needs three concrete types per discipline).
- **`_DequeBuffer` is the fusion existence proof for rings.** The upstream CoW deque is exactly the
  single-allocation shape the deferred fusion option contemplates: `ManagedBuffer` subclass + header
  `{capacity, count, startSlot}` + class-deinit two-segment drain. Cited into the fusion scoping rider
  (R-arc) as the ring-column template, alongside `_ContiguousArrayStorage` for linear.
- **Growth factor**: s-c standardized 1.5×, NIO 2×. The tower's growable ring delegates growth to the
  column; when the family docs state a factor, the 1.5× precedent (with s-c's overflow-safe spelling) is
  the referenced prior art.

## Gaps / follow-ups surfaced

1. **A deferred decision's resumption trigger has fired.**
   `swift-buffer-primitives/Research/buffer-ring-consumer-api-boundary.md` (DEFERRED; Option A — ~15–20
   public methods per ring variant) states its resumption trigger as "when queue-primitives migration to
   Buffer.Ring resumes." The queue family now composes `Buffer.Ring`. The decision should be **revisited
   as a delta pass**, not wholesale: part of Option A's surface is plausibly subsumed by the family's
   seam-generic ops (peek-both-ends, drain, logical subscript) — the revisit should diff Option A's
   ledger against the shipped family surface. Flagged for the seat at the family's verification moment.
2. **A stale package insight to retire.** `swift-queue-primitives/Research/_Package-Insights.md` carries
   the pre-reshape claim that `~Copyable` storage cannot be shared across container types (forcing
   nested-storage duplication). The shipped column-generic `Queue<S>` over `Buffer.Ring` disproves it
   under the current toolchain/flag posture (SuppressedAssociatedTypes + the seam). The insights file
   should be amended by its owner at the next touch (not edited from this research arc).
3. **The drop-oldest cell** (finding 4): record in the family docs as explicitly out-of-scope-with-a-name
   so the next consumer request lands on a documented decision rather than an accident.

## Tower impact

| # | Finding | Tower element | Verdict |
|---|---|---|---|
| 1 | Header+≤2-segments layout consensus; ledger-carried runs | `Buffer.Ring` | **CONFIRMED convergent**; NIO's `Element?` form = the known tombstone trade, correctly not taken |
| 2 | Two-region exactly-once teardown at class/struct/leaf | Ring drain + occupancy law + R-5 | **CONFIRMED**; the tower's no-deinit-at-the-buffer is the strictest of the three |
| 3 | {grow, trap, reject} census; rejection-first + typed throws is ours alone | `Buffer.Ring.Bounded` + queue family | Deliberate divergence, now documented with upstream contrast |
| 4 | `_DequeBuffer` = ManagedBuffer subclass + header + drain deinit | Fusion scoping rider | Ring-column fusion template identified |
| 5 | Drop-oldest absent ecosystem-wide | Variant catalog | Open cell; consumer-gated direction |
| 6 | SE-0527 FD names the deque twins for stdlib | Naming/collision watch | No collision; watch rides the SE-0527 re-land rider |

## Outcome

**Status: RECOMMENDATION** (research only).

1. Family docs: state the teardown invariant (finding 2), the bounded-policy contrast (finding 3), and
   the named-out-of-scope drop-oldest cell (finding 4).
2. Seat, at the family verification moment: trigger the `buffer-ring-consumer-api-boundary.md` delta
   revisit (its DEFERRED trigger has fired); queue the `_Package-Insights` stale-claim amendment for the
   package's next touch.
3. Fusion rider: add `_DequeBuffer` as the ring-column fusion template (with `_ContiguousArrayStorage`
   for linear, `_DictionaryStorage` for hashed — the upstream single-allocation trio is now complete).
4. Growth factor: reference the s-c 1.5× spelling when the growable ring's policy is documented.

## Residual (per [RES-027])

| Item | Class | Disposition |
|---|---|---|
| Upstream layout/teardown/policy claims | premises | [RES-020]-verified 2026-06-10 (8/8, permalinked); local spot-checks first-hand |
| Drop-oldest ring variant | direction | Consumer-gated; named cell |
| Consumer-API-boundary delta revisit | direction (trigger fired) | Seat's call at family verification |
| Growable ring growth-factor documentation | direction | Family-docs item |

## References

- **swift-collections @ `af174fe`**: `DequeModule/Deque/{Deque.swift:84–90, Deque._Storage.swift:140–188,
  _DequeBuffer.swift:14–34, _DequeBufferHeader.swift:14–23, Deque._UnsafeHandle.swift:169–184,276–354}`;
  `_UnsafeDequeSegments.swift:21–26,190–192`; `RigidDeque/{RigidDeque.swift:63–67,115–137,
  RigidDeque+Append.swift:25–55}`; `UniqueDeque/{UniqueDeque.swift:102–107,237–241}`;
  `_UnsafeDequeHandle.swift:21–51`; releases 1.4.0 (source-stable twins; trait-gated Container).
- **swift-nio @ `7586225b`**: `NIOCore/CircularBuffer.swift:15–31,54–56,336–340,350–386`;
  `MarkedCircularBuffer.swift` (flush-marking wrapper, not bounded).
- **stdlib (pinned)**: absence greps; `Sequence.swift:1042–1046` (the RingBuffer FIXME); SE-0527 future
  directions (deque twins sentence).
- **Local**: `swift-buffer-ring-primitives` `Buffer.Ring.swift:18–40`, `Buffer.Ring.Header.swift:18–26`,
  `Store.Initialization.swift:20–34`, `Buffer.Ring.Bounded.swift:9–30`,
  `Buffer.Ring.Bounded.Error.swift:5`, `Buffer.Ring.Bounded+Store.Protocol.swift:26–27`, 7 ledger-sync
  sites; `swift-queue-primitives` `Queue.swift:46` + `Queue+Columns.swift`; `swift-deque-primitives`
  (`Queue.DoubleEnded`); STATUS `6bb2685` (the ring ledger rule), the family entries;
  `buffer-ring-consumer-api-boundary.md` (DEFERRED; trigger now fired); `_Package-Insights.md`
  (stale nested-type claim); `occupancy-encoding-1-adt-cell-layout.md` (the `Optional`-slot trade);
  parent docs `stdlib-array-family-source-archaeology.md` (linear template),
  `hashed-container-substrate-archaeology.md` (hashed template).

### Verification

[RES-020] 2026-06-10: 8/8 upstream claims re-derived from the pinned sources (permalinks in the
verification record); local claims (Queue decl, Bounded error + policy comments, ledger-sync count,
deque spelling) re-checked first-hand via grep.
