# Wave 4 Policy Lean: `@safe` Absorber-Pattern Disposition

<!--
---
version: 1.2.0
last_updated: 2026-05-12
status: SUPERSEDED
---
-->

## Changelog

- **v1.2.0 (2026-05-12)** — **SUPERSEDED** by [`swift-institute/Research/safe-attribute-absorber-pattern-fundamentals.md`](../../../../swift-institute/Research/safe-attribute-absorber-pattern-fundamentals.md) v1.1.0 DECISION. The Tier 2 fundamentals re-examination found that the carve-out stamped at v1.1.0 was tool-capability-bound rather than structurally principled: the "type-level vs method-level" cut and the "direct vs transitive unsafe storage" cut were artifacts of AST-only linter capability, not principled design boundaries. SE-0458 designs `@safe` as the language-level absorber mechanism; the institute's "forbid `@safe`" policy contradicts both SE-0458's intent and the institute's own Tier 2 canonical reference (`swift-safety-model-reference.md` 2026-03-25). The replacement direction inverts `[MEM-SAFE-025b]` to admit `@safe` per SE-0458 while requiring an accompanying invariant disclosure (`[MEM-SAFE-025c]` new). The Wave 4 carve-out logic in `Lint.Rule.Memory.SafeForbidden.swift` is replaced by an inverted predicate in `Lint.Rule.Memory.SafeAttributeUndocumented.swift`. See the fundamentals doc for full structural rationale, prior-art survey, and migration plan. Historical commits `e4d66dd` (Skills carve-out) and `cbf4922` (rule predicate) remain in git history but are functionally replaced.
- **v1.1.0 (2026-05-12)** — Stamped **DECISION** (Option a). Two defect-fixes applied per orchestrator audit:
  1. **Strike "Category E"** from condition (2a). `[MEM-SAFE-024]` defines Categories A/B/C/D only and explicitly forbids silent extension (the rule body states *"A fifth category requires explicit conversation per Wave 2b Decision 8 — do not silently extend the allowlist"*). If a genuine Category-E site surfaces during the per-site verification pass (Step 2 below), it becomes the trigger for a deliberate `[MEM-SAFE-024]` amendment surfaced individually — not smuggled into the carve-out.
  2. **Drop condition (1d)** (*"An invocation of an `@unsafe`-marked function inside an inline method"*). The AST-only linter cannot resolve which functions carry the `@unsafe` declaration attribute across file boundaries — that's a SourceKit / compiler-level question. Conditions (1a)/(1b)/(1c) cover type-level absorption (the carve-out's stated intent). Method-level absorption (the type's interface looks safe but methods use unsafe ops) is out of the carve-out's principled scope — those sites should use `[MEM-SAFE-025a]` invariant comments instead.

  Corrected carve-out text appears in §"Proposed Amendment Shape" below.

- **v1.0.0 (2026-05-12)** — Initial RECOMMENDATION (Options a/b/c surfaced; lean: Option a). Carry-forward from `wave-3-aggregate-2026-05-11.md` v1.2.0 Wave 4 emergence + v1.3.0 scope refinement (~128 sites, not ~80).

## Context

[wave-3-aggregate-2026-05-11.md](wave-3-aggregate-2026-05-11.md) v1.2.0 surfaced
Wave 4 as a carry-forward: Thread 7's new `SafeForbidden` rule (per [MEM-SAFE-025b])
fires on `@safe`-annotated declarations in `Sources/`. The v1.3.0 ledger entry
refined the scope to **~128 absorber-pattern sites** (the initial ~80 estimate was
60% low).

Wave 4 dispatch has been queued since Wave 3 closure with three explicit options:

| Option | Description | Cost | Coherence |
|---|---|---|---|
| (a) | Extend [MEM-SAFE-025b] with an absorber-pattern carve-out | One rule amendment + carve-out predicate logic | Admits the absorber as a deliberate idiom (RULE-WRONG-class disposition) |
| (b) | Migrate all ~128 sites to invariant-comment form ([MEM-SAFE-025a]) | ~128 source-fix commits across 15+ packages | Treats every site as SOURCE-WRONG; uniform invariant-comment surface |
| (c) | Per-site `// swift-linter:disable:next safe attribute forbidden` + `// REASON:` | ~128 disable directives, one per site | Per-site deviation surface; treats every site as a deliberate exception |

HANDOFF.md Open Q1: "before dispatching the ~80-site triage, pick a default disposition."
This document is that pick.

## Empirical Signal

Per Phase 1.4 enumeration (v1.3.0 ledger entry):

**Top packages by absorber-pattern density** (representative subset):

| Package | Count | Shape |
|---|---:|---|
| swift-bit-vector-primitives | 17 | `@safe public struct Inline / Bounded / Static / Ones / Zeros / View / Iterator` — typed-storage-size wrappers with unsafe pointer arithmetic + `// WHY: Category D — structural Sendable workaround (SP-5)` invariant lines |
| swift-ownership-primitives | 14 | `@safe public struct Latch / Slot / Shared / Inout / Borrow / Transfer.Erased.* / Transfer.Retained.*` — single-owner / single-consumer state-machine types with `@unsafe @unchecked Sendable` |
| swift-machine-primitives | 9 | `@safe public struct/enum Erased / Throwing / Node / Frame / Value` — type-erased machine forms |
| swift-buffer-primitives | 8 | `@safe public struct Mutable / Buffer / View` — typed pointer wrappers |
| swift-queue-primitives | 7 | `@safe public class / struct` — queue state-machine types |
| swift-property-primitives | 7 | `@safe public struct Inout / Borrow / Get / Set / etc.` — typed property accessors |
| swift-memory-primitives | 6 | `@safe public struct Address / Buffer / etc.` — typed memory primitives |

Observable signal:
- **Pattern uniformity**: every site applies `@safe` to a typed declaration
  (struct/class/enum/actor), often paired with `@unsafe @unchecked Sendable`
  and frequently followed by a `// WHY:` line citing a Category-A/B/C/D
  Memory-Safety taxonomy entry.
- **Distribution**: 15+ packages, none with >17 sites — broad-and-shallow, not
  concentrated in one design corner.
- **Direct vs absorber split** (per v1.3.0 ledger): ~128 absorber-pattern,
  ~22 direct (on individual funcs/vars). The absorber form is the dominant
  shape by ~6:1.

## Decision: Option (a) — Rule Carve-Out (stamped 2026-05-12)

**RULE-WRONG.** The `@safe` absorber-pattern is a deliberate institute idiom for
type-level invariant absorption: when a type encapsulates unsafe storage / pointer
arithmetic / concurrency-unsafe state behind a typed API, the `@safe` attribute
declares "the compiler can't prove this, but the type's invariants make it safe."
This is structurally distinct from `@safe` on individual function bodies or
property accessors (where the absorption is at finer granularity).

Treating the absorber pattern as SOURCE-WRONG (option b) would require ~128
migrations to the [MEM-SAFE-025a] invariant-comment form. The invariant-comment
form expresses the same idea LESS economically: every type-scoped invariant
becomes a per-decl comment. For type families like the bit-vector-primitives
Iterator/Inline/Bounded/Static cross-product (17 types), this is structural noise.

Treating it as per-site deviation (option c) would scatter ~128 disable directives
across the ecosystem with each citing the same Category-D / SP-5 / etc. reason.
The disable directive is the right mechanism for one-off exceptions, not for a
recurring deliberate pattern.

### Proposed Amendment Shape

Extend [MEM-SAFE-025b] with a carve-out predicate. The rule continues to forbid
`@safe` on individual function bodies, property accessors, etc., but admits the
absorber-pattern form gated on TWO conditions:

```
Carve-out: @safe absorber pattern on type declarations

The @safe attribute MAY appear on a type declaration (struct, class, enum, actor)
when BOTH of the following hold:

  1. The type's body contains at least one of:
     a) An `@unsafe` or `@unchecked Sendable` clause on the type itself.
     b) A `nonisolated(unsafe)` stored property.
     c) An internal storage of `Unsafe*Pointer<...>` / `OpaquePointer` / raw bytes.

  2. The type declaration is accompanied by EITHER:
     a) An adjacent `// WHY: Category <A|B|C|D> — <reason>` line citing a
        [MEM-SAFE-021]/[MEM-SAFE-022]/[MEM-SAFE-023]/[MEM-SAFE-024] taxonomy entry, OR
     b) A `## Safety Invariant` doc-comment section per [MEM-SAFE-025a].

Direct @safe on funcs, vars, lets, inits, subscripts remains forbidden — the
[MEM-SAFE-025a] invariant-comment form is the canonical mechanism for those.
```

**Note on dropped condition (1d)** (per v1.1.0 defect-fix): an earlier draft included
*"An invocation of an `@unsafe`-marked function inside an inline method"* as a fourth
qualifier under condition (1). The AST-only linter cannot resolve cross-file `@unsafe`
declaration markings; the condition was unenforceable. More importantly, method-level
absorption sits outside the carve-out's principled scope — it should use
`[MEM-SAFE-025a]` invariant comments instead of the type-decl carve-out.

The two conditions together prevent the carve-out from degenerating into a free
escape hatch: condition (1) demands evidence that the type genuinely absorbs
unsafe internals; condition (2) demands structured invariant disclosure (the
same disclosure that [MEM-SAFE-025a] requires of any unsafe surface).

## Dispatch Plan (Carry-Forward)

Per the policy lean above, Wave 4 dispatch becomes a **two-step amendment thread**:

1. **Rule amendment**: extend [MEM-SAFE-025b] per the carve-out shape above.
   Implementation: one Skill commit (`swift-institute/Skills/`) + one rule-pack
   commit (`swift-foundations/swift-linter-rules/Sources/Linter Rule Memory/Lint.Rule.Memory.SafeForbidden.swift`)
   to add the absorber-pattern predicate. Expected ~15 new tests.

2. **Per-site verification pass**: with the carve-out in place, re-run lint
   across the ecosystem. Sites that DON'T satisfy condition (1) or (2) above
   surface as SOURCE-WRONG residuals (estimated <10 based on the v1.3.0
   inspection). Those can be triaged individually — typically by adding a
   missing `// WHY:` invariant line.

The ~22 direct `@safe`-on-individual-decl sites are **not covered** by the
carve-out — they remain SOURCE-WRONG and need migration to [MEM-SAFE-025a]
invariant-comment form OR per-site disable directive. These are a separate
sub-thread within Wave 4.

## Alternative: If Option (b) Is Preferred

If the design intent is to require the [MEM-SAFE-025a] invariant-comment form
uniformly (regardless of attachment point), the absorber-pattern sites would
need migration. The migration shape:

```swift
// Before (absorber):
@safe
public struct Inline<let wordCount: Int>: Copyable, Sendable {
    // unsafe storage
}

// After (invariant comment):
// SAFETY: Category D structural Sendable workaround (SP-5).
// The unsafe pointer arithmetic in init / iterator is bounded by
// `wordCount` (compile-time generic parameter) which guarantees
// in-range access at every call site.
public struct Inline<let wordCount: Int>: Copyable, Sendable {
    // unsafe storage
}
```

The cost is ~128 migrations across 15+ packages — substantial but mechanical
once the per-pattern template is established. Trade-off: uniform invariant-
disclosure surface vs. structural noise on type-family cross-products.

## Cross-references

- [wave-3-aggregate-2026-05-11.md](wave-3-aggregate-2026-05-11.md) v1.2.0 +
  v1.3.0 (Wave 4 emergence + scope enumeration)
- `swift-institute/Skills/memory-safety/SKILL.md` [MEM-SAFE-021]/[MEM-SAFE-022]/[MEM-SAFE-023]/[MEM-SAFE-025a]/[MEM-SAFE-025b]
- `swift-foundations/swift-linter-rules/Sources/Linter Rule Memory/Lint.Rule.Memory.SafeForbidden.swift` (the rule whose amendment this proposes)
