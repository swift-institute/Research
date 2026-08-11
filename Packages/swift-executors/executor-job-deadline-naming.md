# Executor Job Deadline Naming

<!--
---
version: 1.0.0
last_updated: 2026-04-29
status: RECOMMENDATION
tier: 1
---
-->

## Context

Bartlett's 2026-04-29 walkthrough of `DefaultActorImpl::defaultActorDrain`
([X post](https://x.com/jacobtechtavern/status/2049489712209862750)) made
explicit what the Swift runtime calls a "priority queue": jobs bucketed by
`JobPriority` (QoS class), drained highest-priority-first. The runtime's
own `Actor.cpp:1632, 1638, 1723` describe scheduling extra
`ProcessOutOfLineJob` at elevated `JobPriority` to drive the actor's
drain at a higher priority level — the queue's organizing key is the
priority bucket.

Our `Executor.Job.Priority`
(`swift-primitives/swift-executor-primitives/Sources/Executor Job Priority Primitives/Executor.Job.Priority.swift`
[Verified: 2026-04-29]) is a min-heap keyed by `Clock.Continuous.Instant`
deadline. The methods are `schedule(_:at:)`, `peek` (returns earliest
deadline), `pop(now:)` (deadline-elapsed dequeue), and
`drain(now:_:)` (drain all elapsed). The type is semantically a
*deadline-scheduled* queue, not a priority-bucketed queue.

The mismatch was already noted in `priority-escalation-policy.md`
v0.6.0 (DECISION, 2026-04-16) Constraint table line 119:

> `Executor.Job.Priority` keyed by deadline, not priority — Cannot reuse
> as a `TaskPriority`-ordered queue without repurposing or duplicating

That note observed the conflict but did not propose a rename: the
DECISION's recommendation was to NOT add a TaskPriority-bucketed queue
for v1 (M1/M2 rejected; M3 thread-QoS bump only). The result is that
`Executor.Job.Priority` remains a name that conflicts with established
runtime terminology, while serving no priority-ordered consumer and
blocking the natural name for any future TaskPriority-bucketed queue.

This note locks the rename.

## Question

What is the correct name for the deadline-keyed min-heap currently
called `Executor.Job.Priority`?

## Analysis

### Options

| Option | Name | Reading |
|--------|------|---------|
| A | `Executor.Job.Deadline` | "the queue keyed by deadline" — names the organizing key |
| B | `Executor.Job.Scheduled` | "the queue of scheduled jobs" — verb form |
| C | `Executor.Job.Priority` (status quo) | conflicts with runtime terminology |

### Comparison

| Criterion | A: Deadline | B: Scheduled | C: Priority (status quo) |
|-----------|:-----------:|:------------:|:------------------------:|
| Names the organizing key correctly | ✓ | ~ | ✗ |
| Symmetric with future QoS-bucketed queue (frees `Priority`) | ✓ | ✓ | ✗ |
| No collision with `Executor.Scheduled` wrapper executor | ✓ | ✗ | ✓ |
| Conforms to runtime terminology | ✓ | ✓ | ✗ |
| Migration cost | mechanical rename | mechanical rename | zero |

**Option B collision:**
`Executor.Scheduled.swift` already exists in swift-executors
([Verified: 2026-04-29]) as a wrapper-executor type that drives a
deadline-aware base via a min-heap. Naming the L1 heap also `Scheduled`
overloads the term across two layers — the wrapper executor and the
underlying queue would share a name despite being distinct concepts.
The verb form is also one step removed from the queue's identity (the
queue ORDERS BY deadline; the *jobs* in it are scheduled).

**Option A advantages:**
- Names exactly what the queue does: orders by deadline.
- Parallel structure with future `Executor.Job.Priority` (the QoS
  variant) — `.Deadline` for time-based, `.Priority` for QoS-based.
- The verb "schedule" remains free for the call-site API
  (`schedule(_:at:)` on the deadline queue, `enqueue(_:after:)` on the
  `Cooperative` wrapper) without name conflict.

### Constraints

- File location: `swift-primitives/swift-executor-primitives/Sources/Executor Job Priority Primitives/Executor.Job.Priority.swift` [Verified: 2026-04-29].
- Library product: `Executor Job Priority Primitives` (Package.swift line 30-33) [Verified: 2026-04-29].
- Direct consumers in swift-executors: `Executor.Cooperative.swift:70`
  (`scheduled: Executor.Job.Priority`), `Executor.Cooperative.swift:120-128`
  (`enqueue(_:after:)`).
- Indirect consumers via tests / DocC: not enumerated; mechanical
  grep is sufficient.
- The methods (`schedule(_:at:)`, `peek`, `pop(now:)`, `drain(now:_:)`)
  describe behavior, not key — they retain their names.

## Outcome

**Status: RECOMMENDATION.**

Rename `Executor.Job.Priority` → `Executor.Job.Deadline`.

**Mechanical change set:**

| Site | Current | After rename |
|------|---------|--------------|
| Type name | `Executor.Job.Priority` | `Executor.Job.Deadline` |
| Source file | `Executor.Job.Priority.swift` | `Executor.Job.Deadline.swift` |
| Companion file | `Executor.Job.Priority.Entry.swift` | `Executor.Job.Deadline.Entry.swift` |
| Source dir | `Sources/Executor Job Priority Primitives/` | `Sources/Executor Job Deadline Primitives/` |
| Library product | `Executor Job Priority Primitives` | `Executor Job Deadline Primitives` |
| Internal consumer | `private var scheduled: Executor.Job.Priority` (`Executor.Cooperative.swift:70`) | `private var scheduled: Executor.Job.Deadline` |

**Why now:** The rename is independent of any other work. It does not
change behaviour, dependencies, or platform layering. It frees the
`Priority` name for the future QoS-bucketed queue without committing
to building one. After the rename, `priority-escalation-policy.md`
Constraint line 119 should also be updated to reference
`Executor.Job.Deadline` (the constraint that priority-keyed queue
construction would require a new type still holds — only the existing
type's name changes).

**Coordination:** The rename touches one L1 package and one L3
consumer. The L3 consumer's only call sites are `Executor.Cooperative`
(2 references) and tests; the rename window is small. Coordinate with
`qos-bracketing-platform-layering.md` (which introduces a typed
`Executor.Job.Priority` enum at L1) to avoid the namespace being
re-occupied between the deadline rename and the typed-Priority
introduction.

## References

### Internal
- `priority-escalation-policy.md` v0.6.0 (DECISION, 2026-04-16) — first noted the name/key mismatch in the Constraint table (line 119).
- `qos-bracketing-platform-layering.md` (this set) — introduces the typed `Executor.Job.Priority` enum that would re-occupy the freed name.
- `swift-primitives/swift-executor-primitives/Sources/Executor Job Priority Primitives/Executor.Job.Priority.swift` — current implementation.
- `swift-foundations/swift-executors/Sources/Executors/Executor.Cooperative.swift:70, :120` — primary consumer.

### External
- Bartlett, J. — ["How Swift uses your hardware to guarantee actor isolation"](https://x.com/jacobtechtavern/status/2049489712209862750), 2026-04-29 — clarifies the runtime's "priority queue" terminology (QoS-bucketed, not deadline-keyed).
- `swiftlang/swift` — [`stdlib/public/Concurrency/Actor.cpp:1632, 1638, 1723`](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/Actor.cpp) — the runtime's priority queue is QoS-bucketed.
