# [MEM-SAFE-025] Reconciliation — `nonisolated(unsafe)` + `@safe` Policy

<!--
---
version: 1.1.0
last_updated: 2026-05-11
status: DECISION
---
-->

## Context

The current `[MEM-SAFE-025]` rule
(`swift-institute/Skills/memory-safety/safety-isolation.md:229`)
states:

> `nonisolated(unsafe)` globals that are safely encapsulated
> (allocated once, never mutated after initialization, used only
> as sentinels or constants) MUST be annotated with `@safe`.

This is enforced by `Lint.Rule.Memory.NonisolatedUnsafeSafe`
(`swift-foundations/swift-linter-rules/Sources/Linter Rule Memory/`),
which flags any `nonisolated(unsafe)` declaration missing the `@safe`
attribute.

The conflict, surfaced in
`swift-institute/Research/three-tier-linter-rules-partition.md`
§Out-of-scope follow-ups #2:

> Institute policy is to forbid `@safe` entirely. The current rule
> requires `@safe` next to every `nonisolated(unsafe)` — directly
> contradictory.

The partition doc proposes a two-rule replacement:
- (i) `nonisolated(unsafe)` needs an invariant comment;
- (ii) `@safe` is forbidden in Sources except via explicit override.

This research doc catalogues current usage, frames the options, and
recommends a direction. The decision feeds back into the
`memory-safety` skill ([MEM-SAFE-025]) and the
`swift-linter-rules` engine.

## Question

**Should `[MEM-SAFE-025]` retain its current "require `@safe` adjacent
to `nonisolated(unsafe)`" rule, or pivot to "forbid `@safe` in Sources
+ require invariant comment on `nonisolated(unsafe)`"?**

Sub-questions:
1. If pivoting: should existing `@safe` annotations in Sources be
   stripped, or only forbidden going forward (with a transition
   clause)?
2. What does the "invariant comment" requirement look like
   procedurally — free-form, structured (`// SAFETY: ...`), or
   skill-citation-anchored (`// [MEM-SAFE-XXX]: ...`)?

## Empirical Footprint

Live grep across `swift-primitives/`, `swift-standards/`,
`swift-foundations/` Sources (excluding `.build/` and `/Tests/`)
on 2026-05-11:

### `@safe` usage (13 sites total)

| Site | Shape |
|------|-------|
| `swift-memory-primitives/.../Memory.Arena.swift:130` | DocC reference (`@safe struct ~Copyable`) |
| `swift-memory-primitives/.../Memory.Contiguous.swift:35` | DocC reference (`@frozen @safe struct ~Copyable`) |
| `swift-memory-primitives/.../Memory.Pool.swift:375` | DocC reference (`@safe struct ~Copyable`) |
| `swift-cpu-primitives/.../CPU.Cache.Padded.swift:47` | `// WHY: @safe —` comment justification |
| `swift-render-primitives/.../Render.Thunk.swift:2` | `@safe @usableFromInline` decl |
| `swift-render-primitives/.../Render.Work.swift:2` | `@safe @usableFromInline` decl |
| `swift-machine-primitives/.../Machine.Value.swift:47` | `@safe final class _Storage: @unchecked Sendable` |
| `swift-machine-primitives/.../Machine.Value.swift:72` | `@safe struct _Table: Sendable` |
| `swift-machine-primitives/.../Machine.Capture.Slot.swift:33` | `@safe final class _Storage: @unchecked Sendable` |
| `swift-witnesses/.../Witness.Values.swift:49` | `@safe @usableFromInline` decl |
| `swift-binary-primitives/Research/*.md` | 6 mentions in Research docs (Strict Memory Safety Audit) |

Live decl sites: 6 — three `@safe @usableFromInline` decls, two
`@safe final class _Storage`, one `@safe struct _Table`. DocC strings
add 4 references; comments add 1. **The ecosystem-wide `@safe`
adoption is minimal** — six live decls, all on Category-A patterns
(per [MEM-SAFE-024]).

### `nonisolated(unsafe)` usage

The current rule fires on `nonisolated(unsafe)` declarations missing
`@safe`. In swift-ownership-primitives specifically, three sites
trigger the AMBIGUOUS-held findings per HANDOFF Open Q1.

Ecosystem-wide count not enumerated in this doc — out of scope; the
follow-up empirical pass per [RES-023] would extend the lint pass to
capture `nonisolated(unsafe)` site count + `@safe` adjacency rate.

### `@unchecked Sendable` (Category A pattern)

247 sites ecosystem-wide. The pattern is widely adopted; the
`@unchecked_sendable_categorized` rule ([MEM-SAFE-024]) addresses
classification of these sites.

## Analysis

### Option A — Retain status quo (require `@safe` adjacent to `nonisolated(unsafe)`)

The current rule continues to require `@safe`. Existing `@safe`
annotations stay; new `nonisolated(unsafe)` declarations must add
one.

**Pros**:
- No migration cost. The rule's existing 6 live decls + the 3
  ownership-primitives AMBIGUOUS findings + 1 swift-property-primitives
  AMBIGUOUS finding resolve by adding `@safe`.
- `@safe` provides a *positive declaration* of "this is encapsulated-
  safe", which has signal beyond a comment. The compiler treats `@safe`
  as a marker; future tooling may consume it (linters, audit tools,
  IDE callouts).
- Consistent with SE-0458's strict-memory-safety direction —
  `@safe`/`@unsafe` are first-class language attributes for safety
  encapsulation.

**Cons**:
- Directly contradicts the stated institute policy ("forbid `@safe`
  entirely"). The contradiction is durable: every new
  `nonisolated(unsafe)` decl reproduces it.
- `@safe`-on-declarations is verbose; pairs with `@unsafe` /
  `@usableFromInline` / `nonisolated(unsafe)` to produce
  declaration-headers that are mostly attributes (the
  `swift-render-primitives` Render.Thunk/Render.Work shape is the
  exemplar).
- The institute already prefers stating encapsulation invariants in
  comments tied to skill rules, not in attribute decoration. See the
  CPU.Cache.Padded.swift:47 `// WHY: @safe —` comment, which already
  uses prose to explain the invariant.

### Option B — Pivot to two-rule replacement (partition-doc proposal)

Replace `[MEM-SAFE-025]` with two rules:

- **[MEM-SAFE-025a]** `nonisolated(unsafe)` requires invariant
  comment. The comment MUST cite the encapsulation invariant in
  prose (free-form or structured `// SAFETY: ...`); the comment is
  immediately adjacent to the declaration.
- **[MEM-SAFE-025b]** `@safe` attribute is forbidden in Sources/.
  Existing `@safe` sites either migrate (replace with invariant
  comment) or carry an explicit override marker
  (e.g., `// swiftlint:disable:next safe-forbidden` or institute
  equivalent).

The corresponding `Lint.Rule.Memory.NonisolatedUnsafeSafe` is
replaced by two rules: `nonisolated unsafe needs invariant` (T2
institute) + `safe forbidden in sources` (T2 institute).

**Pros**:
- Aligns with institute policy. The two-rule replacement is the
  partition doc's authored proposal; this is the path of least drift.
- Comments are more flexible than attributes — the invariant can be
  multi-line, can cite skill rules, can name specific cross-thread
  reads/writes that establish the invariant.
- Migration cost is bounded: 6 live `@safe` decls + ~4 AMBIGUOUS
  findings = ~10 sites total touched.
- The comment form maps naturally to the institute's existing
  `// WHY:` and `// SAFETY:` patterns elsewhere (e.g., the
  Executor.Job.Deque `// WHY: @unchecked Sendable —` comments).

**Cons**:
- Comments are not consumed by the compiler. Future tooling that
  wants to query encapsulation safety would have no machine-readable
  signal. (This may not matter — the existing `@safe` ecosystem is
  6 decls; "future tooling" is speculative.)
- Two rules where there was one. The split is principled (different
  attributes, different motivations) but increases the rule count
  and the cognitive load on consumers.
- Requires migration of 6 live `@safe` sites — small but non-zero.

### Option C — Hybrid (require `@safe` OR invariant comment)

Loosen `[MEM-SAFE-025]` to accept EITHER `@safe` OR an invariant
comment adjacent to `nonisolated(unsafe)`. `@safe` is permitted but
not required.

**Pros**:
- Backward-compatible: existing `@safe` sites continue to satisfy
  the rule.
- New sites can adopt the comment form (aligned with institute
  policy direction).
- No migration cost.

**Cons**:
- Two ways to satisfy the rule split adoption — some sites use
  `@safe`, some use comments, the codebase becomes inconsistent.
- The policy direction (forbid `@safe`) becomes aspirational rather
  than enforced; ecosystem drift in the wrong direction is
  unobserved.
- The partition doc's articulated direction is "forbid `@safe`" — a
  hybrid undermines that articulation without explicit rationale.

### Comparison Matrix

| Criterion | A: status quo | B: two-rule replacement | C: hybrid |
|-----------|---------------|-------------------------|-----------|
| Aligned with institute policy | No | Yes | Partial |
| Migration cost | Zero | ~10 sites | Zero |
| Rule count | 1 | 2 | 1 |
| Compiler-consumable safety marker | Yes | No | Yes (when used) |
| Codebase consistency over time | High | High | Low |
| Resolves AMBIGUOUS findings | Yes (require @safe) | Yes (require comment) | Yes (either) |
| Aligned with `// WHY:` comment convention | No | Yes | Partial |
| Partition doc's articulated direction | Contradicts | Matches | Soft contradicts |

## Outcome

**Status**: DECISION (2026-05-11) — **Option B** selected (two-rule replacement per partition doc).

The argument is policy-coherence: the partition doc's articulated
institute direction is to forbid `@safe` entirely; Option B is the
direct expression. Migration cost is bounded (~10 sites) and the
ecosystem already prefers comment-based justification (the
`// WHY:` convention is widespread in the swift-executor-primitives
and CPU.Cache.Padded patterns). Option C trades off short-term
zero-cost for long-term drift; Option A preserves the policy
contradiction.

If Option B is approved, the implementation plan is:

1. **Skill update** (`swift-institute/Skills/memory-safety/safety-isolation.md`):
   - Mark current `[MEM-SAFE-025]` as superseded with a forwarding
     pointer to `[MEM-SAFE-025a]` / `[MEM-SAFE-025b]`.
   - Author `[MEM-SAFE-025a]` (invariant-comment rule) with structured
     examples.
   - Author `[MEM-SAFE-025b]` (`@safe` forbidden in Sources) with
     transition clause for existing sites.

2. **Lint rule update** (swift-foundations/swift-linter-rules):
   - Replace `Lint.Rule.Memory.NonisolatedUnsafeSafe` with
     `Lint.Rule.Memory.NonisolatedUnsafeInvariant` (checks for
     adjacent `// SAFETY:` or `// WHY:` comment).
   - Add `Lint.Rule.Memory.SafeForbidden` (flags `@safe` attribute
     in Sources/).

3. **Source migration** (per-package commits, one per package):
   - swift-render-primitives: 2 `@safe @usableFromInline` decls →
     comment form.
   - swift-machine-primitives: 3 `@safe` decls on `_Storage` /
     `_Table` → comment form.
   - swift-witnesses: 1 `@safe @usableFromInline` decl → comment form.
   - swift-cpu-primitives: 1 `@safe` already in comment form; no
     change.
   - swift-memory-primitives: 3 DocC mentions → update DocC strings.
   - swift-ownership-primitives + swift-property-primitives: 4
     AMBIGUOUS findings — add invariant comments.

The migration unblocks 1 AMBIGUOUS (swift-property-primitives) + 3
held findings (swift-ownership-primitives) per HANDOFF Wave 3 §7.

If Option A or C is approved, simpler paths apply (just add `@safe`
to the held sites; no migration of existing `@safe` sites).

## Empirical Follow-Up Recommendations

Per [RES-023]:

1. Re-run the aggregate lint pass with visibility-tagged + rule-id-
   tagged findings to enumerate the `nonisolated(unsafe)` sites
   ecosystem-wide. The current finding-count is implicit;
   explicit enumeration would inform the migration plan's scope
   (size of the held-findings group).

2. Verify that no other ecosystem packages have higher `@safe`
   adoption than primitives (the swift-foundations and swift-standards
   layers may have additional sites the primitives-only grep missed).

## References

- HANDOFF.md Wave 3 §7 + Open Q1 (the surfacing dispatch)
- `swift-institute/Research/three-tier-linter-rules-partition.md` §Out-of-scope follow-ups (the proposal source)
- `swift-institute/Skills/memory-safety/safety-isolation.md` [MEM-SAFE-025] (the rule under question)
- `swift-foundations/swift-linter-rules/Sources/Linter Rule Memory/Lint.Rule.Memory.NonisolatedUnsafeSafe.swift` (the current implementation)
- SE-0458 Strict Memory Safety (the upstream `@safe`/`@unsafe` source)
- `swift-primitives/swift-binary-primitives/Research/SE-0458 Strict Memory Safety.md` (institute-side reference)
- `swift-primitives/swift-binary-primitives/Research/SE-0458 Audit Methodology.md` (broader Category-A context)
