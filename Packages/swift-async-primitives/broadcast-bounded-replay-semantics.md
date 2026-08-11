# Bounded Broadcast/Replay Semantics for Async.Broadcast

<!--
---
version: 1.1.0
last_updated: 2026-07-20
status: DECISION
tier: 2
scope: package
package: swift-async-primitives
---
-->

## Context

`Async.Broadcast<Element>` is the ecosystem's single-producer / multi-consumer fan-out
primitive (`swift-async-primitives`, tier below `AsyncSequence`). It publishes a synchronous,
never-blocking `send(_:)` to one producer and a cancellation-safe `subscribe()` / `next()`
async iterator to many consumers, retaining a bounded window of recent elements so that a
subscriber which is momentarily behind can still replay them.

**Trigger — defect F-002.** Before commit `3e27e44`, `send(_:)` trimmed the replay buffer only
of entries older than the *slowest* subscriber's cursor (the min cursor across all subscribers).
A subscriber that never calls `next()` pins that minimum forever, so the trim guard never fires
and the buffer grows without bound — directly contradicting the type's own published
"Delivery Guarantees" ("slow subscribers may miss events if they fall behind the replay window";
"`buffer.limit` defines the replay window").

**Interim contract landed — option (a).** Tonight `3e27e44` landed as the interim fix:
`send(_:)` now trims to `bufferLimit` unconditionally on every call, and any subscriber whose
cursor falls behind the new floor has its cursor advanced past the dropped entries, so it
observes loss (skips to the oldest surviving entry). Git-verified state (2026-07-20): `3e27e44`
is the tip of `main` and is an ancestor of `origin/main` (`git branch --contains` → `main`;
`git merge-base --is-ancestor 3e27e44 origin/main` → true). The commit body describes itself as
a "CANDIDATE … accepted_work=false", reflecting authoring-time intent; it has since been
included on `main`. The commit body explicitly leaves the long-term (a)-vs-(b) contract choice to
the Principal, and asked whether "a best-of-all-worlds solution" exists. This document is that
IMPARTIAL design study; it does **not** privilege option (a) because it landed.

**Constraints (this type, this ecosystem):**

- **Published producer contract**: `send(_:)` is "synchronous, never blocks" (class doc,
  `Async.Broadcast.swift:39`). Changing this to a suspending/async send is a semantic break,
  not a tuning knob.
- **Layer discipline**: primitives layer — no Foundation; typed throws (`throws(E)`) on all
  fallible operations; `~Copyable`-friendly; `Sendable` via internal `Async.Mutex`.
- **Naming/surface discipline** (code-surface): `Nest.Name` only, no compound identifiers
  ([API-NAME-001]); a single-type namespace is a variant label, not a namespace
  ([API-NAME-001a]); nested typed errors ([API-ERR-001]/[API-ERR-002]).
- **Container/variant discipline** (ecosystem-data-structures): "bounded" is a capacity axis
  expressed as **type variants**, not a runtime policy flag ([DS-002], [DS-028]); the free
  variant axes are allocation / capacity / ownership; a member with *distinct observable laws*
  is a **sibling**, not a variant ([DS-027].2).

**Skills loaded ([RES-033])**: `research-process`, `ecosystem-data-structures`, `code-surface`
(the territory: `[DS-*]` container/variant conventions, `[API-NAME-*]`/`[API-ERR-*]` surface
conventions). Internal governing research: `bounded-discipline-algebra.md`,
`deque-ring-bounded-queue-archaeology.md` (both `swift-institute/Research/`, [RES-019]).

## Question

For the long term, what overflow/replay semantics should `Async.Broadcast` publish when a
subscriber falls behind a bounded replay window — and is there a "best-of-all-worlds" design
that improves on the landed drop-oldest contract without reintroducing F-002's unbounded growth?

## Current mechanism (verified against source, 2026-07-20)

- **State** (`Async.Broadcast.State.swift:31-46`): `buffer: Deque<Column.Ring<(index, element)>>`
  (a growable deque ADT over a ring column — the bound is *not* structural; it is enforced by
  `send`), a monotonic `next.index`, and `subscribers: Dictionary<UInt64, Subscriber>.Ordered`
  each holding a `cursor: UInt64` and an optional continuation.
- **send** (`Async.Broadcast.swift:138-202`): assigns the element `index`, pushes `(index,
  element)` to the back, then `while state.buffer.count > bufferLimit { take(from: .front) }`
  (drop-oldest), records `droppedThroughIndex`, and for every subscriber with `cursor < floor`
  (`floor = droppedThroughIndex + 1`) sets `cursor = floor`. Waiters at `cursor == index` are
  resumed with `.element`.
- **next** (`Async.Broadcast.Subscription.AsyncIterator.swift:44-138`): looks for a buffered
  entry with `entry.index == cursor`; if found, returns it and advances `cursor`; else suspends
  or returns `.finished`.
- **Loss is silent.** Because `send` advances a lagging cursor straight to `floor`, the next
  `next()` finds `entry.index == floor` and resumes at the oldest survivor. The subscriber
  receives **no signal** that a gap occurred — the dropped indices simply never appear. The
  `Next.Outcome` enum (`Async.Broadcast.Next.Outcome.swift`) has only `.element` / `.finished` /
  `.cancelled`; there is no `.dropped`/`.lagged` case. The existing tests either size
  `bufferCapacity >= elementCount` to avoid loss entirely (`Async.Broadcast Tests.swift:178`,
  `:260`, `:311`) or (the F-002 regression) assert the subscriber silently "received exactly the
  surviving last N" — no test asserts a subscriber *learns* it lost data, because the API gives
  it no way to.

## Theoretical grounding — the impossibility that answers "best of all worlds" ([RES-022])

Three properties a bounded fan-out might want are, together, unsatisfiable in the presence of a
subscriber that stops consuming:

1. **Bounded memory** — retained state is O(capacity), independent of subscriber behaviour.
2. **Lossless delivery** — every subscriber eventually observes every element sent after it
   subscribed.
3. **Non-blocking synchronous producer** — `send(_:)` completes without suspending, whatever the
   subscribers are doing.

A subscriber that never calls `next()` while the producer keeps sending forces a choice: either
retained state grows without bound (drop **#1** — this is exactly F-002, and option (b)), or the
window is capped and the stalled subscriber loses the overrun (drop **#2** — option (a)), or the
producer is made to wait for the laggard (drop **#3** — the back-pressure family: Disruptor,
Reactive Streams, Kotlin `SUSPEND`). **There is no design that keeps all three.** This is the
precise sense in which there is no "best of all worlds": the intuition runs into a genuine
trilemma, and the engineering question is *which corner the type publishes*, plus whether the
sacrifice is made **observable**.

Given the published contract fixes #3 (synchronous non-blocking `send`), the only corners
reachable *without a semantic break* are #1-vs-#2 — i.e. exactly the (b)-vs-(a) axis. Reaching
the back-pressure corner (keep #1 and #2, drop #3) requires an `async` / suspending `send`,
which is a different type, not a variant of this one (see Options (c)/(e) and Compose-First).

## Prior Art Survey ([RES-021])

Every runtime-behaviour claim below is tagged `[Verified: 2026-07-20]` against the cited primary
source (parallel subagent verification per [RES-034]); a claim that could not be pinned to
primary text is marked `(unverified)` with what is known.

### Kotlin `MutableSharedFlow` (kotlinx.coroutines) — the closest analog

`MutableSharedFlow(replay: Int = 0, extraBufferCapacity: Int = 0, onBufferOverflow: BufferOverflow = BufferOverflow.SUSPEND)`
is a hot, multi-subscriber flow with a replay cache — structurally the same shape as
`Async.Broadcast`. The overflow policy is a **constructor enum**, `BufferOverflow`:

- `SUSPEND` — "Suspend until free space appears in the buffer." **This is the default.**
  [Verified: 2026-07-20]
- `DROP_OLDEST` — "Drop the oldest value in the buffer on overflow, add the new value to the
  buffer, do not suspend." [Verified: 2026-07-20]
- `DROP_LATEST` — "Leave the buffer unchanged on overflow, dropping the value that we were going
  to add, do not suspend." [Verified: 2026-07-20]

Non-`SUSPEND` policies are "supported only when `replay > 0` or `extraBufferCapacity > 0`"
[Verified: 2026-07-20], and "the behavior in the absence of subscribers is always similar to
`BufferOverflow.DROP_OLDEST`, but the buffer is just of replay size" [Verified: 2026-07-20].
Whether `DROP_OLDEST` also evicts from the replay-held portion when `replay>0` **with**
subscribers is implied but not stated verbatim in the API docs (unverified — treated as
consistent-with but not proven). Loss under `DROP_OLDEST`/`DROP_LATEST` is **silent** — there is
no gap signal to collectors.

*Mapping*: landed option (a) ≙ `SharedFlow(replay = bufferCapacity, onBufferOverflow = DROP_OLDEST)`;
option (b) ≙ unbounded buffer (not expressible in `SharedFlow`, which requires a cap for
non-SUSPEND); the back-pressure corner ≙ the **default** `SUSPEND`. Kotlin thus ships all three
trilemma corners behind one runtime enum — but its `emit` is a `suspend fun`, so `SUSPEND` costs
nothing structurally there.

### Apple Combine — buffering and fan-out are *orthogonal*

`Publisher.buffer(size:prefetch:whenFull:)` takes a `Publishers.BufferingStrategy<Failure>` with
exactly three cases: `.dropNewest` ("When the buffer is full, discard the newly received
element."), `.dropOldest` ("…discard the oldest element in the buffer."), and
`.customError(() -> Failure)` ("…execute the closure to provide a custom error.")
[Verified: 2026-07-20]. Fan-out is a *separate* concern: `multicast(_:)` / `makeConnectable()`
and `share()` ("Shares the output of an upstream publisher with multiple subscribers … Share is a
class rather than a structure … reference semantics") [Verified: 2026-07-20]. Combine has **no
single operator** that is "bounded replay with drop-oldest to late subscribers" — buffering
(overflow) and replay/fan-out compose but are not fused (affirmative evidence; exhaustive
non-existence is (unverified)). Notably, `.customError` is Combine's way to make overflow an
**observable typed failure** rather than a silent drop.

### RxJava `ReplaySubject` — size- and time-bounded eviction

- `createWithSize(int maxSize)`: "holds at most `size` items in its internal buffer and discards
  the oldest item." [Verified: 2026-07-20] (drop-oldest, count-bounded)
- `createWithTime(maxAge, unit, scheduler)`: evicts items older than `maxAge`.
  [Verified: 2026-07-20] (time-bounded window — a dimension `Async.Broadcast` does not have)
- `createWithTimeAndSize(…)`: both bounds. [Verified: 2026-07-20]
- `create()`: "unbounded … caches all items … as the number of items grows, this causes frequent
  array reallocation … may hurt performance and latency." [Verified: 2026-07-20] — this **is**
  option (b), and RxJava documents the memory cost as a caveat rather than a feature.

### Reactive Streams (JVM specification) — back-pressure is mandatory, buffers are bounded

Publisher Rule 1.1: "The total number of `onNext`´s signalled by a `Publisher` to a `Subscriber`
MUST be less than or equal to the total number of elements requested by that `Subscriber`´s
`Subscription` at all times." [Verified: 2026-07-20] Demand is signalled additively via
`Subscription.request(long n)` (Rule 2.1 / 3.8) [Verified: 2026-07-20]. Design principle
("Subscriber controlled queue bounds"): "all buffer sizes are to be bounded and these bounds must
be known and controlled by the subscribers … Since back-pressure is mandatory the use of
unbounded buffers can be avoided." [Verified: 2026-07-20] This is the trilemma resolved by
dropping #3 (non-blocking producer) — the producer's rate is bounded by consumer demand. It also
presumes a *per-subscriber* demand channel, which a broadcast's shared window does not have.

### LMAX Disruptor — ring + gating sequences (lossless back-pressure, the #3 corner)

A pre-allocated, fixed, power-of-two ring: "At the heart of the disruptor mechanism sits a
pre-allocated bounded data structure in the form of a ring-buffer." [Verified: 2026-07-20] The
producer is prevented from overwriting un-consumed slots by *gating on the slowest consumer*:
"Consumer sequences allow the producers to track consumers to prevent the ring from wrapping"
[Verified: 2026-07-20]; the API exposes `addGatingSequences(…)` / `getMinimumGatingSequence()`,
and the default claim call blocks (the non-blocking `tryNext()` instead "throw[s] an
`InsufficientCapacityException`") [Verified: 2026-07-20]. So the Disruptor is **lossless with
producer back-pressure** — it drops the trilemma's #3 (it stalls the producer), never #2. It is
the archetype of the corner `Async.Broadcast` cannot reach without an `async` `send`.

### Apache Kafka — retention decoupled from consumers; laggards observe loss (the #1/#2 model)

Kafka retains by policy, not by consumption: "events are not deleted after consumption. Instead,
you define for how long Kafka should retain your events … after which old events will be
discarded" (`log.retention.ms` / `retention.bytes`) [Verified: 2026-07-20]. Producers are never
gated on consumers: "producers and consumers are fully decoupled … producers never need to wait
for consumers." [Verified: 2026-07-20] A consumer that lags past the retained window observes
loss and must reset — `auto.offset.reset` is "What to do when … the current offset does not exist
any more on the server (e.g. because that data has been deleted): earliest … latest … none: throw
exception" [Verified: 2026-07-20]. This is *exactly* the landed `Async.Broadcast` shape — bounded
window (#1) + non-blocking producer (#3), laggard loses the overrun (#2) — with one difference:
Kafka makes the loss **observable** (the offset goes out of range; `none` even throws), where
`Async.Broadcast` silently advances the cursor. (The often-quoted "durably persists all published
records—whether or not they have been consumed" sentence could not be located in the current v4.x
docs (PARTIALLY VERIFIED) — the substance is confirmed by the introduction + retention-config text
quoted above.)

### Swift Async Algorithms — broadcast shipped, replay deliberately excluded

This is the most directly relevant external point, and it corrects a common assumption:
`swift-async-algorithms` **does** ship a broadcast/fan-out operator — `AsyncSequence.share(bufferingPolicy:)`
(SE-style proposal `Evolution/0016-share.md`): "broadcast elements from a single source to
multiple consumers … Each element from the source sequence is delivered to all active iterators."
[Verified: 2026-07-20] But **replay is explicitly out of scope**: "new sides that are started
post initial start up will not have a 'replay' effect; that is a similar but distinct algorithm
and is not addressed by this proposal." [Verified: 2026-07-20] `.share` does carry a
per-consumer `bufferingPolicy` (an `AsyncStream`-style `bufferingOldest`/`bufferingNewest`/
`unbounded` enum) — a drop-oldest/drop-newest *policy-as-enum*, but at the `AsyncSequence` layer,
not the primitives layer.

Two consequences: (1) `Async.Broadcast`'s defining capability — a **bounded replay window** — is
precisely the "similar but distinct algorithm" Apple's `AsyncSequence`-layer `.share` chose not
to build; this primitive is legitimately distinct, and its replay/overflow tension is real, not
incidental. (2) Policy-as-enum is familiar in the *Swift concurrency* ecosystem
(`SharedFlow.BufferOverflow`, `AsyncStream.Continuation.BufferingPolicy`, `.share`'s
`bufferingPolicy`) — which is why option (c) reads as idiomatic — yet it remains absent from the
`swift-primitives` layer specifically (family sweep, below), where bounded-ness is a type.

`AsyncChannel` (the same repo's back-pressure primitive) confirms the trilemma's third corner:
"the back pressure applied by `send(_:)` via the suspension/resume ensures that the production of
values does not exceed the consumption … This method suspends after enqueuing the event and is
resumed when the next call to `next()` on the `Iterator` is made." [Verified: 2026-07-20] It also
delivers each element to *one* awaiting iteration ("Sends an element to an awaiting iteration") —
the deliberate opposite of `.share`'s fan-out. [Verified: 2026-07-20]

### Go / Erlang idioms (brief)

- **Go** channels resolve the trilemma by dropping #3 (blocking producer): "Communication blocks
  until the send can proceed. A send on an unbuffered channel can proceed if a receiver is ready.
  A send on a buffered channel can proceed if there is room in the buffer." [Verified: 2026-07-20]
  A Go channel is point-to-point — one send is consumed by exactly one receiver (FIFO queue
  semantics) [Verified: 2026-07-20]; broadcast is an *idiom* (closing a channel, or `sync.Cond`),
  not a channel capability (idiom is outside the language spec — (unverified) as spec text).
- **Erlang/OTP** process mailboxes are *unbounded* by default — the classic option-(b) shape, and
  the classic slow-consumer memory-growth hazard (mitigated operationally by `max_heap_size` /
  back-pressure patterns, not by a bounded mailbox primitive). Noted as background; not
  load-bearing.

### Contextualization step ([RES-021]) — the universally-adopted pattern absent here, and its cost

The pattern present in *every* surveyed system except this one is a **selectable overflow policy**
(SharedFlow `BufferOverflow`, Combine `BufferingStrategy`, RxJava's create-variants, Reactive
Streams' mandatory back-pressure). In *this* type system, reifying that selection as a **runtime
enum on `Async.Broadcast`** costs the following, concretely:

- **It contradicts the ecosystem's "bounded = type variant" law.** `bounded-discipline-algebra.md`
  establishes bounded-ness as the `+Overflow` summand on the mutating operation, realized as
  *distinct types* along the capacity axis, never a runtime flag; [DS-002]/[DS-028] make capacity
  a **free variant axis** expressed as front-door aliases. A runtime `overflowPolicy:` parameter
  is a foreign shape — there is **no policy-as-enum precedent anywhere in the primitives** (source
  sweep: the only enums in this space are *error* enums and `Cache.Evict.Reason`, a *cause* enum,
  never a strategy-as-value).
- **One of the three policies cannot be a variant of this type at all.** `suspendProducer`
  requires `send` to become `async`/suspending — it changes the *signature and the published
  contract*, so it is a **sibling type** (distinct observable law, [DS-027].2), not a case of an
  enum on the synchronous `Broadcast`. A runtime enum whose third case silently is "and now `send`
  suspends" is not typeable without either making every `send` `async` (breaking #3 for everyone)
  or trapping at runtime when the suspend case is selected.
- **`DROP_LATEST` (drop-newest) is the wrong semantics for a recency window.** A replay window
  exists so late/lagging subscribers see the *most recent* N. Dropping the newest on overflow
  keeps the *oldest* N and refuses new history — the opposite of the type's purpose. So of the
  three canonical policies, only two are even coherent here (drop-oldest, suspend), and only one
  (drop-oldest) fits the synchronous contract.

So the "gap" (no selectable policy) is, on inspection, largely a *deliberate* consequence of the
layer's type discipline plus the published synchronous contract — not a missing feature. What the
survey *does* surface as a genuine, transferable improvement is orthogonal to policy selection:
several systems make the sacrifice **observable** (Combine `.customError`, Kafka offset-out-of-range,
the ecosystem's own `Cache.Evict` effect), whereas the landed design drops **silently**.

## Options Analysis ([RES-005], [RES-009])

### Option (a) — unconditional drop-oldest (as landed, `3e27e44`)

Trim to `bufferLimit` on every `send`; advance lagging cursors to the floor; loss is silent.

- **Pros**: preserves the published synchronous non-blocking `send`; O(capacity) memory
  regardless of subscriber behaviour (fixes F-002); matches `SharedFlow(DROP_OLDEST)` and RxJava
  `createWithSize`; drop-oldest is the correct *recency* policy for a replay window; smallest diff
  (already landed).
- **Cons**: silent loss — a lagging subscriber cannot distinguish "no events yet" from "I missed
  events"; this is a footgun in a substrate primitive (cognitive-dimensions §). The `O(n)`
  lagging-cursor scan runs on every trimming `send` (documented; acceptable at typical subscriber
  counts).

### Option (b) — documented lossless-until-slowest-subscriber

Publish the pre-F-002 behaviour as the intended contract: the buffer grows to hold everything the
slowest live subscriber has not yet consumed; nothing is dropped while any subscriber is behind.

- **Pros**: no subscriber ever misses an element (property #2); trivially "correct" from a
  consumer's naive viewpoint; matches RxJava unbounded `create()`.
- **Cons**: **this is F-002 re-labelled as a feature** — unbounded memory under a single stalled
  or crashed-without-cancel subscriber (property #1 lost); a denial-of-service surface in a
  shared substrate; contradicts the ecosystem's mandatory-bound posture (Reactive Streams:
  "unbounded buffers can be avoided"; the primitives layer has *no* unbounded-by-design container
  in this family). `bufferCapacity:` becomes a meaningless parameter. Rejected on structural
  grounds unless paired with an explicit, separately-named unbounded type.

### Option (c) — per-instance overflow policy enum (`dropOldest` / `dropNewest` / `suspendProducer`)

A `BufferOverflow`-style enum passed at `init`, à la SharedFlow.

- **Pros**: one type covers the trilemma corners; familiar to Kotlin/Combine users; maximal
  configurability.
- **Cons**: **against the grain of the layer** — no policy-as-enum precedent in the primitives;
  bounded-ness is a type variant here, not a runtime flag ([DS-002]/[DS-028],
  `bounded-discipline-algebra.md`). `suspendProducer` is untypeable as a case (it changes `send`'s
  signature to `async` — a sibling, not a variant; [DS-027].2). `dropNewest` is semantically wrong
  for a recency window. So the enum's honest cardinality in this type is **one** coherent case
  (drop-oldest), which is not an enum. Reifies a foreign configuration shape to gain nothing the
  single coherent case does not already give.

### Option (d) — policy via separate types (`Broadcast` vs `Broadcast.Lossless`, …)

Model each policy as its own type in the `Broadcast` namespace, per Nest.Name.

- **Pros**: idiomatic surface shape (types, not flags); each type has one observable law; matches
  the sibling discipline ([DS-027].2).
- **Cons**: the axis on which these differ is *not* one of the free variant axes
  (allocation/capacity/ownership) — drop-oldest vs lossless vs back-pressured are **distinct
  observable laws**, i.e. siblings, and back-pressured additionally changes `send` to `async`. So
  "`Broadcast.Lossless`" is not a capacity *variant* of `Broadcast`; it is a *sibling family
  member*. Building the sibling(s) *now*, absent a consumer, is speculative (compose-first §,
  [RES-018]/[DS-020]) and would ship `Broadcast.Lossless` = the F-002 defect under a friendly
  name. The correct disposition is to **name the sibling cells as out-of-scope** (matching
  `deque-ring-bounded-queue-archaeology.md` finding #4's "named out-of-scope cell" recommendation)
  and grow one only when a real consumer materialises.

### Option (e) — drop-oldest **with observable loss** (RECOMMENDED refinement of (a))

Keep option (a)'s memory and producer guarantees, but make the sacrifice **observable**: when a
subscriber's cursor is advanced past dropped entries, the next delivery surfaces a typed loss
signal instead of silently resuming. Two concrete shapes:

- **(e1) Additive outcome**: extend the *internal* `Next.Outcome` and the public `next()` so a
  lagging read yields, once, a `.dropped(through: Index)` / count before resuming normal delivery
  — e.g. `next()` returns the element but the subscription exposes a `lagged` observation, or a
  dedicated typed throw `Error.lagged(droppedThrough:)` surfaced once (typed-throws idiomatic,
  [API-ERR-001]/[API-ERR-002]).
- **(e2) Eviction effect**, mirroring the ecosystem's own `Cache.Evict` prior art: a broadcast-level
  observable that fires on drop with a reason, decoupled from the per-subscriber `next()`.

- **Pros**: same #1/#3 guarantees as (a); removes the silent-loss footgun (a lagging subscriber
  *learns* it lost N and can resync — the Kafka offset-out-of-range / Combine `.customError`
  behaviour, and consistent with `Cache.Evict`); typed-throws-native; no `async` `send`; no
  runtime policy flag.
- **Cons**: it is an API change to a §5.3-compliant cancellation-tokened iterator (the outcome
  surface widens); it imposes a signal on *every* consumer, including the many (UI state, latest-
  value observers) that legitimately do not care which events they missed — and the closest analog,
  `SharedFlow.DROP_OLDEST`, deliberately drops **silently**. So the burden/benefit trade is real
  and is the main open question for the Principal (see Recommendation and the strongest counter).

### Comparison

| Criterion | (a) drop-oldest (landed) | (b) lossless-slowest | (c) runtime policy enum | (d) sibling types now | (e) drop-oldest + observable loss |
|---|---|---|---|---|---|
| Bounded memory (#1) | ✅ O(capacity) | ❌ unbounded (=F-002) | ✅ per case | ✅ (drop cases) | ✅ O(capacity) |
| Lossless (#2) | ❌ bounded loss | ✅ | ⚖ per case | ⚖ per type | ❌ bounded loss |
| Non-blocking sync `send` (#3) | ✅ | ✅ | ❌ if suspend case | ❌ for lossless/BP sibling | ✅ |
| Loss observable | ❌ silent | n/a | ❌ silent (drop cases) | ❌ silent | ✅ typed signal |
| Fits ecosystem "bounded = type" | ✅ (one law) | ❌ (no unbounded family) | ❌ (no policy-enum precedent) | ✅ but siblings, speculative | ✅ (one law) |
| `send` contract preserved | ✅ | ✅ | ❌ | partial | ✅ |
| Diff size | none (landed) | small | medium | large | small–medium |
| Structural correctness ([RES-036]) | good | poor | poor | premature | best |

## Family-consistency evaluation

The ecosystem already has an implicit, verified "bounded means X" convention — and it is *not*
uniform across families, which is itself instructive:

| Family member | Full-buffer law | Shape |
|---|---|---|
| `Buffer.Ring.Bounded` | **reject / drop-newest** (`return element`; queue surface throws `Error.full`) | type variant + return-rejected/typed-throw |
| `Async.Channel.Bounded` | **suspend producer** (`send` is `async`); opt-in `send.immediate` throws `.full` | sibling (async send) + reject variant |
| `Cache.Bounded` | **drop-oldest** (FIFO by insertion; `order.removeFirst()`) | type; eviction surfaced as `Cache.Evict` **effect** with `.Reason` |
| `Queue.Bounded` / `Deque.Bounded` | reject / drop-newest (`throw Error.full`) | type variant |
| `Async.Broadcast` (this type) | drop-oldest (landed) | application-enforced bound over a growable deque |

Two findings bear directly on the decision:

1. **Drop-oldest is not absent from the ecosystem — it lives in `Cache.Bounded`.**
   `deque-ring-bounded-queue-archaeology.md` finding #4 ("drop-oldest is an open niche —
   everywhere … recorded as an open variant cell") is precise to the *ring/queue* families; the
   *cache* family already ships drop-oldest, because a cache — like a replay window — is a
   *recency* structure. `Async.Broadcast`'s drop-oldest is therefore consistent with the one
   ecosystem family whose purpose matches it (recency), and correctly *inconsistent* with the
   ring/queue families (whose purpose is lossless FIFO handoff, hence reject/suspend).
2. **The ecosystem already models loss as an observable effect** — `Cache.Bounded` fires
   `Cache.Evict` (carrying key/value + a `.Reason` of `.capacityLimit` etc.) on eviction. This is
   direct in-ecosystem precedent for option (e): the sibling recency structure makes its drops
   observable rather than silent. That `Async.Broadcast` drops silently is the one place it
   diverges from its closest ecosystem kin.

## Why not compose existing primitives? ([RES-018] / [DS-020] compose-first)

This study proposes **no new cross-cutting primitive**. The classification is unambiguous: the
subject is one package's own type (`Async.Broadcast`) and its published law — **case (b)
domain-owned vocabulary** in [RES-018] terms (governed by `[MOD-DOMAIN]`, no consumer-count gate),
not a case-(a) cross-cutting proposal. The recommended option (e) is an *observability refinement
of an existing type*, not a new type.

For completeness, the composition check on the rejected options:

- The **back-pressure corner** (lossless + bounded, `async` `send`) is *already available by
  composition*: `Async.Channel.Bounded` is exactly a bounded, suspend-on-full, single-consumer
  channel; a lossless back-pressured fan-out is "one bounded channel per subscriber, producer
  awaits the slowest" — composable from shipped primitives without a new broadcast type. This is
  why option (c)'s `suspendProducer` case and option (d)'s back-pressured sibling are not just
  against-the-grain but *unnecessary to build into `Broadcast`*: the capability exists one
  composition away, with the correct `async` shape, for the consumer who needs it.
- The **unbounded corner** (option b) is `Async.Channel.Unbounded` fanned out — again composable,
  and again correctly a *different type* whose name advertises the unbounded law, rather than a
  silent property of `Broadcast`.

Composition covers the non-recommended corners; the one thing composition does *not* give is
observable loss on the drop-oldest recency window itself — which is why option (e) lives on the
type.

## Cognitive-dimensions pass ([RES-025])

| Dimension | (a) landed silent drop | (e) observable loss | Note |
|---|---|---|---|
| **Error-proneness** | High — silent loss reads identically to "quiescent"; a consumer that assumes losslessness is wrong with no diagnostic. In a *substrate* primitive this propagates: every higher layer inherits the silent gap. | Low — the gap is a typed signal; mis-assumption fails loudly at the boundary. | The central axis. |
| **Visibility** | Loss is invisible in the type's surface; only `bufferCapacity` hints at it. | Loss is a first-class outcome. | |
| **Role-expressiveness** | `next() -> Element?` says "stream of elements or end" — it does not express "…or a gap." | The signal makes the gap part of the role. | |
| **Consistency** | Diverges from `Cache.Evict` (the sibling recency structure that *does* surface eviction). | Consistent with `Cache.Evict`. | |
| **Viscosity** | Low now (landed); but a later move to observable loss is a breaking surface change — cost rises the longer silent-drop is published. | Pay once, now. | Argues for deciding (e) before adoption widens. |
| **Abstraction** | Fewer concepts (element/finish/cancel). | One more concept (dropped). | The counter-argument: some consumers genuinely want the smaller abstraction (see below). |

Counter-reading (honest): for *latest-value / state-broadcast* consumers, silent drop-oldest is
precisely the desired abstraction — they want the newest state and do not care about missed
intermediate states. `SharedFlow.DROP_OLDEST`, the closest analog, drops silently by design. So
"silent loss is a footgun" is strongest for *event-stream* consumers and weakest for
*state-broadcast* consumers, and the type serves both.

## Outcome

**Status: DECISION** (Principal ruling, 2026-07-20): option (e) — bounded drop-oldest with
observable loss — is adopted as the type's law. The observable-loss refinement is implemented
and landed on `main` as `3e27e44..0b71caa`. The original recommendation analysis is preserved
unchanged below.

**Recommendation.** Keep option (a)'s corner — bounded, drop-**oldest**, synchronous non-blocking
`send` — as the type's law; it is the only trilemma corner reachable without breaking the
published `send` contract, drop-oldest (not drop-newest) is the correct *recency* policy for a
replay window, and it matches both the closest external analog (`SharedFlow(DROP_OLDEST)`) and the
one ecosystem family whose purpose matches (`Cache.Bounded`). Do **not** adopt option (b) (it is
F-002 as a feature), option (c) (a runtime policy enum is foreign to the layer and its honest
cardinality here is one coherent case), or build option (d)'s siblings speculatively. **The
recommended long-term improvement is option (e): make the loss observable** — surface a typed
loss signal when a lagging subscriber's cursor is advanced past dropped entries, mirroring the
ecosystem's own `Cache.Evict` effect and the Kafka/Combine "you fell off the window" behaviour.
This keeps every guarantee option (a) already provides, costs no `async` `send` and no runtime
flag, and removes the one place `Async.Broadcast` diverges from its closest ecosystem kin: silent
loss. Per [RES-036], this is the structurally-correct choice (correctness of the published law +
observability of its sacrifice), not the minimum-diff choice; option (a)-as-is is the minimum-diff
choice and is a proper subset of (e).

If the Principal prefers to defer the surface change, the fallback is: **retain (a) as-is but
publish the silent-loss law explicitly** in the type doc (it already half-does), and record the
observable-loss refinement (e) and the back-pressured/lossless *siblings* as named out-of-scope
cells — so the next consumer request lands on a documented decision rather than an accident.

**Strongest argument against the recommendation.** The closest and most battle-tested analog,
Kotlin `SharedFlow.DROP_OLDEST`, makes drop-oldest **silent on purpose**, and a large class of
broadcast consumers (UI/state observers) genuinely do not want to handle a loss signal — for them
"give me the latest, forget the rest" is the whole point, and a mandatory `.dropped` outcome is
ceremony that every such call site must dismiss. Under that reading, option (e) over-serves the
event-stream consumer at the expense of the state-broadcast consumer, and the minimal, already-
landed option (a) — silent drop-oldest, with the loss law documented — is the honest, YAGNI-correct
resting point until a concrete consumer demands observable loss. (If that argument prevails, the
refinement should still be *reserved by name* per the fallback, so it remains a non-breaking
additive move later — see Residual.)

## Residual ([RES-027])

| Item | Class | Disposition |
|---|---|---|
| Does a real consumer need observable loss (e) vs silent drop (a)? | **premise** (load-bearing for the recommendation) | Not yet backed by an experiment. The refutation-shaped spike is cheap: a consumer-facing test that a lagging `Async.Broadcast` subscriber cannot currently distinguish "quiescent" from "lost N" — it already holds by construction (the `Next.Outcome` has no gap case), so the *premise that silent loss is unobservable* is verified by source, but *whether that matters to a downstream consumer* is a direction, not a settled premise. Recommend a ≤1h spike in `Experiments/` if the Principal leans toward (e). |
| Back-pressured / lossless fan-out as a **sibling** (`async` send) | direction | Composable today from `Async.Channel.Bounded`; build only on real consumer demand; name the cell out-of-scope now. |
| Time-bounded replay window (RxJava `createWithTime`) | direction | `Async.Broadcast` has no time axis; out of scope; note as an open cell. |
| Whether `DROP_OLDEST` evicts the replay-held portion with subscribers present in SharedFlow | external fact (unverified) | Non-load-bearing for this decision; noted for completeness. |

## References

Internal (governing — [RES-019]):
- `swift-institute/Research/bounded-discipline-algebra.md` — bounded = the `+Overflow` summand,
  realized as type variants (the "bounded is a type, not a flag" law).
- `swift-institute/Research/deque-ring-bounded-queue-archaeology.md` — finding #4: drop-oldest is
  an open cell in the ring/queue families; "named out-of-scope cell" recommendation.
- Skills: `ecosystem-data-structures` ([DS-002] variant selection, [DS-027].2 sibling-vs-variant,
  [DS-028] variant algebra, [DS-020] compose-first gate), `code-surface` ([API-NAME-001/001a],
  [API-ERR-001/002]).

Source (verified 2026-07-20, this package unless noted):
- `Sources/Async Broadcast Primitives/Async.Broadcast.swift:39` (synchronous non-blocking `send`
  contract), `:138-202` (drop-oldest trim + lagging-cursor advance), `:43-48` (published Delivery
  Guarantees).
- `…/Async.Broadcast.State.swift:31-46` (growable `Deque<Column.Ring<…>>` + cursors).
- `…/Async.Broadcast.Subscription.AsyncIterator.swift:44-138` (exact-match `entry.index == cursor`
  read → silent skip to floor), `…/Async.Broadcast.Next.Outcome.swift` (no `.dropped` case).
- `Sources/Async Channel Primitives/Async.Channel.Bounded.Sender.swift:142-198` (suspending
  `async send`), `…/Async.Channel.Bounded.Sender.Send.swift:45,67-68` (`immediate` throws `.full`).
- `swift-buffer-ring-primitives/…/Buffer.Ring.Bounded+Operations.swift:41-45` (`if header.isFull
  { return element }` — reject/drop-newest).
- `swift-cache-primitives/…/Cache.Bounded.swift:74-88` (FIFO drop-oldest, `order.removeFirst()`),
  `…/Cache.Evict.swift:41-97` (eviction-as-effect + `.Reason` cause enum).
- Git: `3e27e44` on `main` / ancestor of `origin/main` (2026-07-20).

External (primary, [Verified: 2026-07-20] per [RES-034] — full quotes in Verification Record):
- Kotlin `MutableSharedFlow` / `BufferOverflow` — kotlinlang.org API docs.
- Apple Combine `Publishers.BufferingStrategy`, `PrefetchStrategy`, `share()` / `multicast(_:)` —
  developer.apple.com/documentation/combine.
- RxJava 3 `ReplaySubject` — official 3.1.12 javadoc.
- Reactive Streams JVM specification (Rules 1.1, 2.1, 3.8; "Subscriber controlled queue bounds") —
  github.com/reactive-streams/reactive-streams-jvm.
- LMAX Disruptor — technical paper (`Disruptor-1.0.pdf`) + User Guide + `RingBuffer` Javadoc,
  lmax-exchange.github.io/disruptor.
- Apache Kafka documentation — kafka.apache.org (v4.x: introduction, design, broker/topic/consumer
  configs).
- Swift Async Algorithms — `AsyncSequence.share(bufferingPolicy:)` (`Evolution/0016-share.md`,
  `Guides/Share.md` — broadcast ships, replay explicitly excluded), `AsyncChannel`
  (`Guides/Channel.md` — back-pressure rendezvous), github.com/apple/swift-async-algorithms.
- Go language specification — go.dev/ref/spec (Send statements, Channel types).

### Verification Record ([RES-034])

Load-bearing external claims were verified by five parallel subagents against the primary sources
named above. Verdicts were MATCHES except:
- SharedFlow "`DROP_OLDEST` evicts the replay-held portion when `replay>0` **with** subscribers"
  — COULD-NOT-VERIFY on primary text (implied, not stated); marked unverified above.
- Combine "no fused bounded-replay-with-drop operator" — affirmative evidence; exhaustive
  non-existence COULD-NOT-VERIFY.
- Kafka "durably persists all published records—whether or not they have been consumed" (the
  classic sentence) — COULD-NOT-VERIFY in the current v4.x docs; the substance is confirmed by the
  introduction + `log.retention.*` config text (PARTIALLY VERIFIED).
- **Correction surfaced by verification**: an initial assumption that `swift-async-algorithms`
  ships *no* broadcast/share was refuted — `.share(bufferingPolicy:)` **does** ship; only *replay*
  is excluded. The doc reflects the corrected finding.
- Sourcing note: the RxJava 3.x reactivex.io path now serves 4.x-alpha content; the official
  3.1.12 generated javadoc (javadoc.io mirror) was used as the primary source and the substitution
  recorded.

## Changelog ([RES-008])

- **1.1.0 (2026-07-20)** — Promoted RECOMMENDATION → DECISION per Principal ruling
  (fable-448 residuals session): option (e) adopted; observable-loss refinement landed
  as `3e27e44..0b71caa`. Analysis content unchanged.
- **1.0.0 (2026-07-20)** — Initial study; status RECOMMENDATION.
