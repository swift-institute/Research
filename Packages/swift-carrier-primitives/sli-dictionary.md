# SLI — `Dictionary<Key, Value>`: Skip

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: DECISION
tier: 1
scope: swift-carrier-primitives SLI target
---
-->

## Context

`Swift.Dictionary<Key, Value>` is a two-parameter generic hash-map type. Should it conform to `Carrier`?

## Analysis

### Structural match

Trivial self-carriage (`Underlying = Dictionary<Key, Value>`) compiles. The default extension provides the requirements.

### Semantic fit

Same zero-payoff issue as Array and Set: trivial self-carriage adds no phantom dimension, no diagnostic value, no cross-type algorithm utility.

A parametric form would need to decide what to unwrap:

- Unwrap values: `extension Dictionary: Carrier where Value: Carrier` → `Underlying = [Key: Value.Underlying]`. Keys preserved, values unwrapped.
- Unwrap keys: `where Key: Carrier, Value: _` → `[Key.Underlying: Value]`. But hash-consistency of keys through the unwrap is the same problem as Set<Element>.
- Unwrap both: `where Key: Carrier, Value: Carrier` → double-parametric, worse key-hash issue.

### Two-parameter carrier shape

More fundamentally: `Dictionary<Key, Value>` is a TWO-parameter generic. Carrier has one primary associated type `Underlying`. Mapping from `Dictionary<K, V>` into a single Underlying requires picking one axis. None of the three choices above is an obvious default; each locks a specific semantic choice that can't be undone post-FINAL.

### Could-it-be-done verdict

| Form | Viable? | Cost |
|------|---------|------|
| Trivial self-carrier | Yes | No payoff |
| Parametric (value-unwrap) | Yes | Hash-consistency on Key preserved; but commits to "Dictionary = dict-over-unwrapped-values" semantics for all time |
| Parametric (key-unwrap) | Partially | Hash-consistency issue on keys |
| Parametric (both-unwrap) | No | Combines both problems |

## Outcome

**Status**: DECISION — skipped from 0.1.0 SLI.

**Rationale**: Two-parameter generics can't be mapped into a single-parameter Carrier without committing to one axis. No clear semantic default; each choice is a one-way lock with no downstream validation. Deferred to consumer packages where the specific use case will pick the right axis.

## References

- Swift stdlib `Dictionary<Key, Value>`.
- `sli-array.md`, `sli-set.md` for related parametric analysis.
