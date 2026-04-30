# Research-Doc Recommendation vs Dispatch Override

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: IN_PROGRESS
tier: 2
---
-->

## Context

When a Research doc explicitly recommends an approach (e.g., timing X over timing Y) and the principal's subsequent dispatch overrides to the non-recommended path, the divergence is permitted (the principal authorizes; the doc recommends) but currently invisible during execution. The supervisor block typically does not carry a `fact:` entry naming the doc's preferred approach, so the dispatch's override is not visible to the subordinate or to any later reviewer. When the override's downside materializes, the rework cost is paid in full because the warning was not surfaced at execution time.

This Doc scopes the question of whether the override warrants a structural rule, what entry shape is appropriate, and how the rule composes with the existing pre-dispatch ecosystem-constraint scan ([SUPER-027]) and opt-out-clauses-as-preferences pattern ([HANDOFF-018]).

## Question

When a Research doc explicitly recommends approach X, and the dispatching principal overrides to approach Y, should the supervisor block carry a mandatory `fact:` entry naming the doc's preferred approach as the prior-art reference? If so, under what conditions, and what entry shape?

## Analysis

### Origin instance — the 2026-04-28 Phase 1.5 case

The Research doc `posix-descriptor-l2-vs-l3policy.md` v1.0.0 explicitly recommended *status-quo timing* (defer the relocation to post-Cycle-23 cleanup) over *pivot now*, with reasoning: "Phase 1 momentum is non-substitutable" and "reversibility is symmetric." The principal authorized "pivot now" in HANDOFF.md without surfacing the doc's preferred timing as a `fact:` entry.

The pivot ran the exact failure mode the Research doc warned against: mid-Phase-1 invalidation of just-reviewed-and-merged work. Net cost: 12 forward commits + 6 revert commits + 1 doc-cleanup, with zero net progress on type relocation. The Research-doc-recommendation-bypass cost was paid in full.

### Generalization

When a dispatch overrides a Research-doc recommendation, three structural patterns recur:

| Pattern | Visibility |
|---------|-----------|
| Dispatch text restates the doc's recommendation and explicitly authorizes the override | High — subordinate sees the divergence |
| Dispatch text references the doc but does not name the override | Medium — subordinate can read the doc; may or may not |
| Dispatch text proceeds without referencing the doc's recommendation | Low — subordinate has no signal that an override is in effect |

The third pattern is the failure mode. A `fact:` entry in the supervisor block at dispatch time forces visibility regardless of whether the dispatch text names the override.

### Option A — Mandatory `fact:` entry naming doc's preferred approach

Every dispatch that overrides a Research-doc recommendation MUST include a supervisor-block `fact:` entry of the form:

```
fact: Research doc {doc-path} v{version} recommends {X timing/approach};
      this dispatch overrides to {Y}. Subordinate may surface concerns
      if execution surfaces the doc's predicted downsides.
```

| Pro | Con |
|-----|-----|
| Forces visibility at dispatch time | Burden on principal at dispatch authoring time |
| Subordinate can flag matching execution issues | May grow noisy if many dispatches override doc recommendations |
| Reviewer of the dispatch can see the override | |

### Option B — Recommended (SHOULD) `fact:` entry, plus pre-dispatch grep

Less restrictive: the supervisor block SHOULD include the `fact:` entry. Additionally, the pre-dispatch ecosystem-constraint scan ([SUPER-027]) MUST grep the relevant Research doc(s) for explicit recommendations before authorizing the dispatch; surface any divergence to the principal.

| Pro | Con |
|-----|-----|
| Less authorial burden | Identifying "the relevant Research doc" requires knowing the doc exists |
| Relies on mechanical scan to catch divergences | Subordinate-side discovery (when the principal didn't grep) is harder |

### Option C — Absorb into [SUPER-002a] Scope-Lock Precedes Architecture-Lock

[SUPER-002a] already requires scope-boundary questions to be confirmed before architecture commitments. Extend it to also require: research-doc-recommendation review before architecture commitment.

| Pro | Con |
|-----|-----|
| One unified rule for "what to confirm before locking architecture" | Mixes two concerns (scope confirmation + prior-art consultation) that may want to evolve independently |

### Open analysis

| Question | Status |
|----------|--------|
| What threshold of doc-vs-dispatch divergence triggers the `fact:` entry? Every divergence, or only major ones? | TODO |
| How does this compose with [HANDOFF-018] Opt-Out-Clauses-Are-Preferences? | TODO — preferences expressed in prior artifacts deserve real-time visibility; structurally similar |
| Is there a corresponding writer-side rule (handoff author surfaces override when authoring HANDOFF.md)? | TODO |
| Does [SUPER-027]'s Research-doc dimension (added during this Doc's authoring) suffice, or does the `fact:` entry add meaningful visibility on top? | TODO |

## Outcome

**Status**: IN_PROGRESS

**Recommendation (preliminary)**: Option B — the supervisor block SHOULD include the `fact:` entry, plus extend [SUPER-027] (Pre-Dispatch Ecosystem-Constraint Scan) to grep relevant Research docs at dispatch authorization time. This balances the authorial burden against the visibility benefit. [SUPER-027] was already extended with a Research-doc dimension during this Doc's drafting, providing the mechanical-scan side of the recommendation; the open question is whether a SHOULD `fact:` entry on top adds meaningful visibility or is redundant.

**Tier classification**: Tier 2 per [RES-020] — cross-package, reversible precedent. The override-visibility question affects supervisor discipline ecosystem-wide but is not foundational; codifying it later or differently does not invalidate dispatches that proceeded without the visibility convention.

## References

- Reflection: [Research/Reflections/2026-04-28-phase-1-5-l2-pivot-attempt-and-namespace-correction.md](Reflections/2026-04-28-phase-1-5-l2-pivot-attempt-and-namespace-correction.md) — origin incident; 12-commit pivot reverted.
- Research: `swift-institute/Research/posix-descriptor-l2-vs-l3policy.md` v1.0.0 — the recommendation that was overridden.
- Skills: [SUPER-002], [SUPER-002a], [SUPER-005], [SUPER-027], [HANDOFF-018]
