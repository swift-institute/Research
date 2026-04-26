# When Stdlib Naming Beats Ecosystem Naming (and When It Doesn't)

Date: 2026-04-26
Scope: ecosystem-wide (all packages that shadow Swift stdlib types — Array, Set, Dictionary, Result, etc.)
Tier: 2 (cross-package, naming-convention research, reversible precedent)
Status: IN_PROGRESS — survey scope defined; principle-extraction pending case-study sweep
Provenance: Reflection `2026-04-24-post-hoc-api-name-compliance-swap-rename.md` action item; the 2026-04-24 `Array.swapAt → swap(at:with:)` post-ship rename surfaced the underlying tension.

---

## Context

The swift-institute ecosystem deliberately shadows Swift stdlib types (most prominently `Array`, but also `Set`, `Dictionary`, `Result` in some scopes). The shadow IS the choice — consumers writing `import Array_Primitives` get the ecosystem `Array`, not `Swift.Array`. The shadow exists because the ecosystem has its own naming conventions ([API-NAME-001] / [API-NAME-002] in particular) that the stdlib does not honor.

Yet stdlib API names exert gravitational pull during ecosystem-version authoring. The 2026-04-24 origin incident: `Array.swapAt(_:_:)` shipped despite [API-NAME-002] being pinned in CLAUDE.md, in auto-memory, and frequently invoked. The reason it shipped is that `Swift.Array.swapAt(_:_:)` is the stdlib idiom and SE-0527 uses the same name; under the gravitational pull of "match stdlib," the ecosystem's compound-identifier ban did not fire. User caught post-ship; renamed in `@c9c1083`.

The general question this incident surfaces: **are there cases where stdlib naming beats ecosystem naming?** If yes, what's the principle that distinguishes them from cases like `swapAt`? If no, the gravitational pull is purely a process defect and the answer is "always rename."

---

## Question

What's the principled answer to: "when does stdlib naming beat ecosystem naming, and when does it not?"

Sub-questions:

1. **Discoverability for migrating callers**: a developer porting from `Swift.Array` to `Array_Primitives.Array` benefits from name continuity. How much benefit? Quantitative or just intuition?
2. **Signal vs noise in shadowed-type renames**: does renaming `swapAt` → `swap(at:with:)` send a signal ("this isn't your stdlib API; pay attention") that's load-bearing, or is the rename pure noise that consumers route around without thinking?
3. **Cost of subtle differences**: when the ecosystem keeps `swapAt` (compound) but changes its semantics (e.g., adds bounds-checking), is the same name on different semantics worse than a different name on different semantics?
4. **Pattern-vs-instance**: is the answer per-API or ecosystem-wide? If `swapAt` should stay but `lazyMap` should rename, what distinguishes them?

---

## Analysis (stub)

### Hypothesis directions to investigate

| Direction | Hypothesis | How to test |
|-----------|------------|-------------|
| Stdlib name + matching semantics | Stdlib name preserves discoverability without ambiguity; rename is pure ecosystem-aesthetic noise | Survey shadowed APIs where ecosystem semantics match stdlib exactly; check whether rename is justified by [API-NAME-002] alone or also by semantics divergence |
| Stdlib name + diverging semantics | Stdlib name is now misleading; rename is signal that "this differs" | Survey shadowed APIs where ecosystem adds bounds-checking, typed throws, or ownership constraints; rename is justified to surface the divergence |
| Stdlib name + compound-identifier violation | [API-NAME-002] forbids compounds regardless of stdlib pedigree; rename is mandatory | Confirmed by the 2026-04-24 `swapAt` incident; this Doc proposes adopting this as the default rule |
| Stdlib name + non-compound | Stdlib name is acceptable when not in violation; signal-vs-noise question is moot | Survey shadowed APIs that are non-compound; check whether they're kept verbatim |

### Empirical sweep candidates

The case-study sweep should enumerate shadowed APIs across the ecosystem:

| Shadowed type | API surface | Compound identifiers? | Semantics divergence from stdlib? | Current name | Right name? |
|---------------|-------------|----------------------|------------------------------------|--------------|-------------|
| `Array_Primitives.Array` | (full surface) | TBD | typed throws, bounds-checking via Index | TBD | TBD |
| `Set_Primitives.Set` | (full surface) | TBD | TBD | TBD | TBD |
| `Dictionary_Primitives.Dictionary` | (full surface) | TBD | TBD | TBD | TBD |
| Other shadowed types | TBD | TBD | TBD | TBD | TBD |

The sweep produces a per-API table; the principle emerges (or doesn't) from the pattern.

---

## Outcome (placeholder)

To be authored once the empirical sweep completes. Expected shape:

- **Default rule**: ecosystem naming wins; stdlib name retained ONLY when it does not violate [API-NAME-002] AND the ecosystem semantics match stdlib semantics closely enough that rename would be misleading.
- **When stdlib name should be retained**: the API is non-compound AND semantics match stdlib AND the rename would actively confuse migrating callers.
- **When stdlib name should be renamed**: the stdlib name violates [API-NAME-002], OR the ecosystem semantics diverge in ways that the stdlib name no longer accurately describes, OR the rename produces a layer-consistency match (per [API-NAME-008]) that makes delegation through the layer cleaner.

The case-study sweep is the load-bearing artifact; the principle without empirical backing reads as preference.

---

## Cross-references

- Reflection: `2026-04-24-post-hoc-api-name-compliance-swap-rename.md` (origin incident)
- Skill rules: [API-NAME-002] (no compound identifiers), [API-NAME-007] (convention-known-convention-unapplied heuristic — fires on stdlib-pedigree names), [API-NAME-008] (Property.View vs labeled method decision rule)
- Related principle: layer-consistency soft tie-breaker in [API-NAME-008] (matching the name one layer down is a correctness signal)
