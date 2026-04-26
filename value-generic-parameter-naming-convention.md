# Value-Generic Parameter Naming Convention in the Primitives Ecosystem

Date: 2026-04-26
Scope: ecosystem-wide (all primitives packages using `<let X: Int>` value-generic parameters)
Tier: 2 (cross-package, naming convention, reversible precedent)
Status: IN_PROGRESS — inconsistency documented; convention selection pending principal review
Provenance: Reflection `2026-04-24-se-0527-outputspan-adoption-wave.md` action item (Pattern 2 — value-generic parameter naming creates shadowing hazards)

---

## Context

Swift's value generics (`<let X: Int>`) allow types to be parameterized by integer values at the type level. The swift-institute primitives ecosystem uses value generics across multiple packages, but with inconsistent naming conventions for the parameter:

| Type | Parameter name | Style |
|------|----------------|-------|
| `Array.Bounded<let N: Int>` | `N` | Single-letter (matches stdlib's `InlineArray<N, T>`) |
| `Array.Static<let capacity: Int>` | `capacity` | Semantic name |
| `Array.Small<let inlineCapacity: Int>` | `inlineCapacity` | Semantic name (scope-disambiguated) |
| `Buffer.Linear.Inline<let capacity: Int>` | `capacity` | Semantic name (matches Array.Static) |

The inconsistency is not just stylistic — it changes what APIs the type can expose. A type whose value-generic parameter is named `capacity` cannot then expose a public instance property `capacity` without shadowing the type-level parameter. The 2026-04-24 incident: `Array.Static.freeCapacity` would have computed from a runtime `capacity` property; the runtime `capacity` couldn't exist because the type-level `capacity` shadowed it. Workaround: compute from the type's own generic parameter directly via `Array.Index.Count(UInt(capacity))` rather than through a runtime accessor.

---

## Question

Should the swift-institute primitives ecosystem standardize value-generic parameter naming on:

| Option | Convention | Pros | Cons |
|--------|------------|------|------|
| A | Short single-letter (`N`) | Matches stdlib (`InlineArray<N, T>`); avoids shadowing hazards (no instance property would naturally be named `N`) | Less semantic; reader must look up what `N` means |
| B | Semantic name (`capacity`) | Self-documenting at the type-parameter site | Shadows runtime instance properties of the same name; surface API limited |
| C | Semantic name with scope-disambiguation prefix (`inlineCapacity`) | Self-documenting AND avoids shadowing (the runtime `capacity` is distinct from the type-level `inlineCapacity`) | Verbose; verbosity scales with the parameter list |
| D | Mixed — short for outer-facing types, semantic for internal types | Stdlib-aligned where consumers expect; clearer where they don't | Inconsistent at the convention level; principle hard to state |

---

## Analysis (stub)

### The shadowing hazard pattern

When a value-generic parameter shares a name with a runtime instance property, Swift's name resolution shadows the runtime property. Inside any extension on the type, bare `capacity` resolves to the type-level Int generic, not to a (hypothetical) runtime property. This means:

1. The type cannot expose a public instance property `capacity` (it would conflict with the generic parameter).
2. Workarounds (compute capacity from the type-level parameter via `Array.Index.Count(UInt(capacity))`) are awkward and unintuitive.
3. Future API additions that would naturally use the parameter name as a property name are blocked by the convention.

`Array.Bounded<let N: Int>` and `Array.Small<let inlineCapacity: Int>` avoid the hazard by construction; `Array.Static<let capacity: Int>` and `Buffer.Linear.Inline<let capacity: Int>` both hit it.

### Stdlib precedent

`InlineArray<N, T>` (stdlib) uses `N`. The choice signals a convention: stdlib's value-generics for capacity-like parameters are short single-letters. Aligning with stdlib has discoverability value (callers porting from stdlib see the same shape).

### Ecosystem-wide impact

A convention applied retroactively requires renames across the ecosystem. The cost depends on adoption breadth:

- `Array.Bounded<let N: Int>` — already conforming to Option A
- `Array.Small<let inlineCapacity: Int>` — already scope-disambiguated (no rename needed under any option)
- `Array.Static<let capacity: Int>` — would need rename under Option A (capacity → N), Option C (capacity → inlineCapacity)
- `Buffer.Linear.Inline<let capacity: Int>` — same as Array.Static

Renaming `capacity` to `N` (Option A) or `inlineCapacity` (Option C) is a breaking API change for any consumer that uses the generic parameter explicitly (e.g., `Array.Static<capacity: 4>`). Under [SKILL-LIFE-003] this is breaking and warrants explicit gate.

---

## Outcome (placeholder)

Pending principal review. Expected recommendation shape:

- **Adopt Option A (single-letter `N`)** for new types — matches stdlib, avoids shadowing hazards by construction.
- **Migrate `Array.Static<let capacity: Int>` and `Buffer.Linear.Inline<let capacity: Int>` to `<let N: Int>`** in a coordinated rename cycle — breaking for consumers using the explicit name, but the rename surface is bounded.
- **Document the convention in `swift-package` skill or `code-surface` skill** so future types adopt it from the start.

The migration cost is the load-bearing decision factor; if the consumer surface using explicit `capacity:` parameter labels is large, Option C (semantic + scope-disambiguation prefix) may be the lower-cost path.

---

## Cross-references

- Reflection: `2026-04-24-se-0527-outputspan-adoption-wave.md` (Pattern 2 — value-generic parameter naming creates shadowing hazards)
- Package insight (action item F3): `swift-array-primitives/Research/_Package-Insights.md` (value-generic name-shadow gotcha + workaround for `Array.Static.freeCapacity`)
- Stdlib precedent: `InlineArray<N, T>` (Swift 6.x; `N` convention)
- Related skill: `swift-package` ([PKG-NAME-*] naming conventions); `code-surface` ([API-NAME-*])
