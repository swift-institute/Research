# Cross-Cutting IO Primitives Home

| Field | Value |
|-------|-------|
| Tier | 2 |
| Scope | ISO 9945 Kernel IO target layout |
| Status | OPEN |
| Provenance | 2026-04-22-supervisor-arc-investigation-through-cycle-two-dispatch.md |

## Context

`Kernel.IO.Vector.Segment` currently lives in the `ISO 9945 Kernel File` target. Consumers at File and Socket both need the typed segment; Socket's `public import` re-exports all of Kernel File to reach it. The consequence: Socket module's re-exported surface is wider than its responsibility domain — architecturally noisy but functionally correct.

## Question

Is there a better home for `Kernel.IO.Vector.Segment` that preserves type-identity across File and Socket without forcing Socket to widen its re-exported surface?

## Candidates

| Candidate | Trade-offs |
|-----------|------------|
| A. New `ISO 9945 Kernel IO` sibling target, File and Socket both depend on it | Adds a target; narrow re-export scope per target |
| B. Promotion to L1 `swift-io-primitives` | Adds an L1 package; strong reuse story if other L3 users materialize |
| C. Accept-and-document widening | Zero code change; narrow to a documentation action |

## Scope Constraints

- **[PLAT-ARCH-013] Shell+Values**: whichever target holds the segment must be a Shell-or-Values kind, not a Behaviors target.
- **[MOD-008] independent-consumer rule**: the target's consumers should be independent (File and Socket qualify).
- **[MOD-015] consumer-import precision**: the narrower the exported surface, the better.

## Decision Framework

- If only File and Socket are consumers: Option A is the least-change path.
- If a third consumer emerges (or is anticipated): Option B is worth the extra L1 package.
- If the widening is accepted as cost-of-doing-business: Option C is honest about the trade-off.

Recorded as a future-cycle candidate in the ISO 9945 tracker's Cycle 1 drift-cleanup section. This research note surfaces the decision criteria before any ecosystem-wide move.

## References

- Reflections: 2026-04-22-supervisor-arc-investigation-through-cycle-two-dispatch.md
- platform skill [PLAT-ARCH-013], [MOD-008], [MOD-015]
