# Declarative Frameworks for Continuous Render Targets

<!--
---
version: 1.0.0
last_updated: 2026-07-24
status: RECOMMENDATION
tier: 2
scope: cross-package
skills_loaded: swift-institute-core, swift-institute, code-surface, platform, research-process
---
-->

## Context

The `swift-user-interface` planning chain to date (`danceui-architectural-analysis.md`,
`swift-user-interface-primitive-audit.md`) has studied declarative frameworks whose
render target is a **discrete** surface: a document that is laid out once, or a widget
tree that is re-rendered when state changes. Both assume that rendering is *event-driven*
— something changes, so the framework recomputes.

A different class of framework exists: one whose render target is a **continuous** surface,
re-rendered on a fixed cadence (a frame clock) whether or not anything changed, where each
frame must be produced within a hard deadline, and where the output is composited from
sub-images rather than emitted as a token stream.

That class imposes design constraints the discrete case never surfaces. This document
records those constraints as design findings for `swift-user-interface`, independent of
any particular implementation.

**Trigger**: a scoping study of what the institute would need in order to host a
declarative framework targeting continuously-rendered output.

**Constraints**:
- Findings must be expressible without reference to any specific external implementation.
- Any recommendation must respect `[ARCH-LAYER-001]` (downward dependencies),
  `[ARCH-LAYER-007]` (no-Foundation at every layer), and `[ARCH-LAYER-014]`
  (layer follows essence).
- Skills loaded per `[RES-033]`: swift-institute-core, swift-institute, code-surface,
  platform, research-process.

**Relation to prior research** (per `[RES-019]`): this document does **not** re-derive the
render-vocabulary decomposition. That was derived in `swift-user-interface-primitive-audit.md`
(2026-04-21) and decided in `render-machine-dissolution.md` (2026-07-24). See
*Prior-chain reconciliation* below, which is the most consequential section here.

## Question

What does a declarative framework require when its render target is a continuously
re-rendered frame rather than a discrete document, and which of those requirements are
gaps in the current L1 substrate?

## Analysis

### Finding 1 — Animation is a pure function of time, not a mutation schedule

The discrete model treats an animation as a scheduled mutation: a driver ticks, each tick
writes a new value, the tree re-renders. This requires an animation runloop, per-animation
tick state, and a subscription lifecycle.

The continuous model does not need any of that, because a frame clock already exists. An
animatable value can be represented as:

```
value(at: t) = base + Σ delta_i.interpolated(at: t)
```

where each `delta_i` is a running animation carrying a start time, duration, curve, and a
vector delta. Rendering at time *t* evaluates the sum; nothing schedules anything.

Two properties follow that the mutation-schedule model does not have:

- **Overlapping animations compose additively rather than clobbering.** A second animation
  started mid-flight on the same property contributes its own delta; it does not cancel or
  replace the first. This is the correct behaviour for interrupted transitions and is
  usually approximated with velocity hand-off in the mutation model.
- **Animation state is not lifecycle state.** There is no subscription to leak and no tick
  to miss. Completion is a predicate on *t*, not an event.

*Gap*: no L1 package owns this. The vector algebra it needs (an additive, scalar-multiplicable
value with a zero) and the unit-curve vocabulary are both absent.
*Verified 2026-07-24*: no `swift-animation-primitives` in the primitives root.

### Finding 2 — Time must be an explicit parameter, and this is the load-bearing finding

Every stage of a continuous pipeline — resolution, reconciliation, layout, compositing —
must take the frame time as an explicit parameter rather than reading an ambient clock.

This looks like a plumbing detail and is not. It is what makes the entire pipeline a pure
function, and therefore:

- **Deterministically testable.** A test renders at *t* = 0, 100 ms, 200 ms and asserts on
  exact output. No sleeping, no flake, no clock injection at the leaves.
- **Seekable.** Rendering at an arbitrary *t* costs the same as rendering at the next *t*;
  scrubbing backwards is not a special case.
- **Reproducible under failure.** A frame that renders wrongly renders wrongly again.

The discrete model tolerates an ambient "now" because its output is asserted structurally
rather than temporally. The continuous model cannot: an ambient clock makes every animated
assertion a race.

*Relation to existing substrate*: `swift-clock-primitives` already ships `Clock.Test` and
`Clock.Immediate` (*Verified 2026-07-24*: `Clock.Test.swift`, `Clock.Immediate.swift` in the
Clock Primitives target), which is the same discipline expressed for schedulers. The finding
is that a continuous render pipeline needs it threaded through the *render* path, not only
the concurrency path.

### Finding 3 — Identity is a dense integer assigned from structural position

A continuous pipeline re-resolves its view tree on a cadence and must match this frame's
nodes to last frame's nodes cheaply. Structural identity — `(parent, key) → dense Int`,
assigned once and memoized — supports this well, with four satellite facts stored beside it:

| Fact | Purpose |
|---|---|
| depth | bounding traversals |
| sibling order | deterministic compositing order |
| human label | addressability (see Finding 4) |
| parent | upward walks without a back-pointer in the node |

The load-bearing detail is the **lexicographic sort key**: the path from root to node,
mapped through sibling order. Compositing is order-sensitive, and a dictionary-backed graph
has no inherent order, so sibling order must be *derivable from identity* rather than stored
in the traversal. Without it, output ordering varies between frames that are structurally
identical.

*Anti-pattern to avoid*: exposing the dense integer as a public type alias. It is an index
and should be `Tagged`-branded per `[IDX-001]`; a bare `Int` in the public surface admits
arithmetic that is meaningless on identities.

### Finding 4 — Rendered output needs to be addressable from outside

When a framework renders offscreen — to a frame rather than to a live view hierarchy —
the host has no hit-testing, no responder chain, and no view to query. It still needs to
know *where a given piece of content landed* in the output, in order to attach interaction
regions, overlays, or annotations in host coordinates.

The shape that solves this: a label modifier that names a subtree, plus a query that
resolves a label to the frame that subtree occupied in the rendered output, scaled to an
arbitrary container size.

This has no analogue in the discrete document case (where output positions are not
queried) or in the live-widget case (where the view hierarchy answers it). It is specific
to offscreen rendering and is worth designing in rather than bolting on — the query needs
identity, layout, and the label to be available together, which constrains where the label
is stored.

### Finding 5 — Exit requires a four-phase node model with animation-gated pruning

The hard case in any declarative framework is *removal*: a node that has left the tree must
remain renderable until its exit animation completes.

Four phases are sufficient and each is load-bearing:

| Phase | Meaning |
|---|---|
| entering | in the tree, exit not begun, enter animation may be running |
| updating | steady state |
| exiting | out of the tree, animating out, still rendered |
| awaiting-parent-exit | out of the tree, but an ancestor is also exiting |

The fourth is the one that is discovered late. When a subtree is removed, only the
*roots* of that subtree should run their own exit animation; descendants must not
independently animate out underneath an ancestor that is itself animating. Marking
descendants distinctly from `exiting` is what prevents the doubled animation.

Pruning is then gated on animation completion rather than on tree membership: a node
leaves the graph when it is `exiting` **and** its animations have completed at time *t*.

### Finding 6 — Failure catalogue: the shapes that recur

Recorded as anonymous shapes, because each is a design hazard rather than an incident:

1. **"This node is not really a node."** A framework accumulates several independent
   notions of structural transparency — a node that collapses into its parent for layout,
   one that is flattened by its container, one that contributes children but no output.
   These are discovered separately and end up as three unrelated marker protocols. They
   are worth unifying deliberately at design time; retrofitting is expensive because each
   is consulted at a different pipeline stage.

2. **Reflection in the hot path.** Variadic builder output (a tuple of heterogeneous
   children) is tempting to traverse reflectively. On a discrete render this is a one-time
   cost; on a continuous render it is a per-frame cost, and it defeats the type system
   exactly where the framework most needs it. `Machine.Node`-style defunctionalization is
   the institute-shaped alternative.

3. **String comparison as change detection.** When a heterogeneous node's equality is not
   available, comparing debug descriptions is an available shortcut. It is wrong in both
   directions — distinct states with equal descriptions compare equal, and equal states
   with unstable descriptions compare unequal — and it converts a correctness property
   into a formatting property.

4. **Crash-as-error-handling.** A continuous pipeline has many invariants that hold "unless
   something upstream is wrong". Terminating on violation makes them undebuggable in the
   field. `[API-ERR-001]` typed throws is the institute answer; the count of such sites is
   a good proxy for how many invariants a design has not yet expressed in types.

## Prior-chain reconciliation

Per `[RES-019]`, the internal corpus was swept before writing. It surfaced a defect larger
than the findings above, and this section is the operative part of this document.

**The `swift-user-interface` planning chain rests on package names that do not resolve.**
*Verified 2026-07-24* by direct enumeration of the primitives root:

| Cited by | Name | Actual state |
|---|---|---|
| both docs | `swift-state-primitives` | **absent** |
| both docs | `swift-driver-primitives` | **absent** |
| both docs | `swift-rendering-primitives` | **absent** (the package is `swift-render-primitives`) |
| audit | `swift-positioning-primitives` | **absent** (the package is `swift-position-primitives`) |
| audit | `swift-lifetime-primitives` | **absent** |

`swift-user-interface-primitive-audit.md` assigns two of these — `swift-state-primitives`
("currently namespace-only") and `swift-driver-primitives` ("currently minimal") — a
`NEEDS EXTENSION` verdict describing their present contents, and lists both in its
*"What needs thin in-package extension"* outcome table. Those extensions cannot be
performed. The document carries `Verified: 2026-04-21`, which is precisely the shelf-life
failure `[RES-013a]` describes: the tag conferred confidence that outlasted the check.

**Three cited decision documents are also absent** from the corpus
(*Verified 2026-07-24*): `swift-user-interface-graph-transactions.md`,
`swift-user-interface-tree-traversal.md`, `swift-user-interface-package-decomposition.md`.
The audit's *Reconciliation note* defers the attribute-graph placement decision to the
first of these — "the focused investigation wins ... decision recorded in" — so a decision
the audit treats as settled has no recoverable record. Its *Next actions* 2, 3 and 4 each
point at one of the three.

**The render decomposition was derived twice, three months apart, without cross-reference.**
The audit (2026-04-21) recommended splitting the document-specific action vocabulary out of
the render core into a sibling L1, plus a second sibling carrying a graphics vocabulary.
`render-machine-dissolution.md` (2026-07-24) reached a compatible conclusion by an
independent route — shared composition stays under `Render`, document concepts move under
`Render.Document` — and cites the audit nowhere. The two differ materially: the audit
recommends a **package** split, the dissolution decision a **target** split.

Both cannot stand as written. `render-machine-dissolution.md` is `status: DECISION` and
more recent, so it governs; the audit's rendering rows should be marked SUPERSEDED and its
graphics-vocabulary recommendation — which the dissolution decision does not address —
re-homed rather than lost.

## Outcome

**Status**: RECOMMENDATION.

### Design findings for `swift-user-interface`

Findings 1–6 above are offered as design input. Finding 2 (explicit time) is the one to
adopt unconditionally: it is cheap at design time, effectively impossible to retrofit, and
it is what makes the pipeline testable at all. Findings 1, 3 and 5 are concrete enough to
implement from. Finding 4 is specific to offscreen rendering and can be deferred until an
offscreen target is real.

### Substrate gaps confirmed against live source

| Gap | State *(Verified 2026-07-24)* |
|---|---|
| Additive time-indexed animation algebra | No owning package exists |
| Layout proposal ↔ measure solver | `Layout.Stack` declares the *shape* (`Layout.Stack.swift:33`); no proposal-resolution surface exists in the target |
| Environment scoping | **Covered** — `Dependency.Values` (`Dependency.Values.swift:35`) with key-typed subscript (`:63`) |
| Deterministic clocks | **Covered** — `Clock.Test`, `Clock.Immediate` |

The layout finding matches the audit's `NEEDS EXTENSION` verdict and is re-confirmed here
against current source rather than carried forward.

### Recommended corpus actions

1. Correct or supersede `danceui-architectural-analysis.md` and
   `swift-user-interface-primitive-audit.md` on the five non-resolving package names.
   Both are being used as planning inputs; neither is safe to plan from today.
2. Determine whether the three absent decision documents were lost, never written, or
   written to a different corpus. The attribute-graph placement decision in particular is
   cited as settled and is not recoverable.
3. Mark the audit's rendering rows SUPERSEDED by `render-machine-dissolution.md`, and
   re-home its graphics-vocabulary recommendation, which the dissolution decision leaves
   unaddressed.
4. Adopt as method: a research document that names a package MUST resolve the name against
   the live root at write time. Both defects in this chain are name-resolution failures,
   and both survived a verification tag.

### What this document does not decide

The placement of a continuous/graphics render vocabulary, the raster and compositing
substrate beneath it, and whether a platform-quarantined backend is admissible under
`[ARCH-LAYER-007]` are all out of scope here and are tracked separately.

## References

- `swift-user-interface-primitive-audit.md` — prior per-primitive audit (2026-04-21)
- `danceui-architectural-analysis.md` — parent research; see corpus action 1
- `render-machine-dissolution.md` — governing render decision (2026-07-24)
- `[RES-013a]` — synthesis verification and verification-tag shelf life
- `[RES-019]` — step-0 internal research grep
- `[RES-037]` — empirical-claim verification for dependent-package state
