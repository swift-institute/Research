# Cardinal / Ordinal / Vector Enforcement Rule Design

<!--
---
version: 1.0.0
last_updated: 2026-05-05
status: RECOMMENDATION
research_tier: 2
applies_to: [swift-primitives]
normative: false
---
-->

## Context

User directive 2026-05-05 during Phase 1.5 / Tier-A linter rollout:

> *"Move away from bitPattern and unchecked inits, and stay high typed and only do conversions where necessary (and then prefer map and retag). Optimize for clean/elegance. The rules / harness should assist us with this."*

The directive sits on top of an existing canonical preference hierarchy ([CONV-016] in `swift-institute/Skills/conversions/SKILL.md`):

> 1. **retag** — change tag, preserve value
> 2. **map** — transform value, preserve tag
> 3. **typed arithmetic** — composed operations
> 4. **typed initializer** — system boundary
> 5. **rawValue / `__unchecked`** — last resort, same-package only

And on the existing-infrastructure rule set ([INFRA-101] / [INFRA-102] / [INFRA-103] / [INFRA-104] / [INFRA-200] in `swift-institute/Skills/existing-infrastructure/SKILL.md`) that defines what "high-typed" means:
- All quantities use `Cardinal` or `Tagged<T, Cardinal>` (never bare `UInt`/`Int`)
- All positions use `Ordinal` or `Tagged<T, Ordinal>`
- All scaling uses `Affine.Discrete.Ratio`
- `Cardinal - Cardinal` does not compile by design
- `count - 1`, `count &-= 1`, `pointer + count`, `Index(rawValue: 5)` public API, scalar operators on typed quantities — all forbidden

The user's directive instructs me to **take prior research and skills with a grain of salt** because **the current source can be substantially improved**. The research below grounds rule design in an empirical survey of *current* swift-primitives source rather than assuming compliance.

### Prior research consulted ([RES-019] internal grep complete)

- `affine-operator-unification-completeness.md` (DEFERRED) — Tagged+Affine operator unification pending; no immediate rule constraints.
- `ai-context-reduction-via-type-system-tooling.md` (RECOMMENDATION) — Symbol-graph-driven detection of bitPattern / unchecked / reconstruction is the prime mechanism for ecosystem-scale enforcement; signature shapes reveal patterns without reading bodies. Phase 2-4 of that work pending.
- `operator-ergonomics-and-carrier-migration.md` (RECOMMENDATION, Option G) — Per-type protocols WITH associatedtypes (e.g., `Ordinal.Protocol` with per-conformer `Count`) serve operator-ergonomics that Carrier alone cannot replicate; rules MUST NOT discourage `Self + Self.Count → Self` patterns.
- `bounded-index-precondition-elimination.md` (SUPERSEDED by [IMPL-050..053]) — `Index<Element>.Bounded<N>` = `Tagged<Element, Ordinal.Finite<N>>` validated empirically; `.map()` / `.retag()` compose correctly on double-Tagged. Encourages eliminating Category D non-negativity checks.

---

## Question

Which rules can be added to the SwiftLint Tier 1 / Tier 2 canonical configs **immediately** to enforce the canonical preference hierarchy and discourage `bitPattern` / `__unchecked` patterns, given:

(a) SwiftLint custom-rule regex constraints (per Phase 1.5 findings: no per-rule path scoping for built-in rules, no file-context-aware logic, lookbehind is unreliable in NSRegularExpression),

(b) the empirical state of swift-primitives source (which patterns are dominant, which are absent),

(c) the cost/benefit trade-off (add a rule that catches genuine drift vs. add a rule that mostly produces false positives or already-clean baselines)?

A **secondary** question: which patterns require SwiftSyntax-based tooling (the deferred Symbol-graph pipeline mentioned in `ai-context-reduction-via-type-system-tooling.md`) rather than regex-based SwiftLint custom rules?

---

## Analysis

### Empirical baseline (verified 2026-05-05)

Survey of all swift-primitives sub-package `Sources/` directories (excluding `.build/`, `.docc/Resources/`, `Tests/`). Methodology: parallel-subagent grep against canonical-pattern regexes; counts are file-level (number of `.swift` files containing at least one match).

| Pattern | Files | Top 3 packages | Status |
|---|---|---|---|
| `Int(bitPattern:` (any form) | 180 | swift-buffer-primitives 19, swift-ordinal-primitives 16, swift-hash-table-primitives 12 | Mixed: bare form is the legitimate `[INFRA-002]` integration overload; chained `.rawValue` form is the anti-pattern |
| `__unchecked:` | 41 | swift-parser-primitives 8, swift-vector-primitives 7, swift-cyclic-primitives 4 | Mixed: legitimate at extension-init declaration sites per `[CONV-001]`; anti-pattern at call sites |
| `\.rawValue\.` (chained access) | 12 | swift-buffer-primitives 3, swift-cardinal-primitives 2, swift-algebra-modular-primitives 2 | Anti-pattern per `[INFRA-103]`: use `.retag()` / `.map()` / `Type.min(a, b)` |
| `Swift\.min(.*\.rawValue` | **0** | — | **Already clean.** `Type.min(a, b)` discipline is universal. |
| `count - 1` | 34 | swift-tree-primitives 6, swift-buffer-primitives 4, swift-sample-primitives 3 | Anti-pattern per `[INFRA-025]` / `[INFRA-200]`: use `.subtract.saturating(.one)` |
| `count -= 1` | **0** | — | **Already clean.** |
| `count &-= 1` | **0** | — | **Already clean.** |
| `Cardinal(0)` or `Cardinal(1)` | 2 | swift-cardinal-primitives 1, swift-sequence-primitives 1 | Anti-pattern per `[INFRA-101]`: use `.zero` / `.one`. **Almost clean.** |
| `position\.rawValue\s*\+` (manual position arithmetic) | **0** | — | **Already clean.** Use `.successor` / `.advance`. |

### Read of the baseline

**Already-clean surfaces don't need rules** — they have demonstrated the discipline holds. Adding a rule for a never-violated pattern only adds catalog noise.

**Small-cleanup surfaces** (`.rawValue.` chains: 12, `Cardinal(0)/(1)`: 2) are good candidates for advisory rules: small fixable count + clear anti-pattern + low false-positive risk.

**Medium-cleanup surface** (`count - 1`: 34) is the canonical demonstration that the rule's spirit (`Cardinal - Cardinal` doesn't compile, so any `count - 1` site means `count: Int` not `count: Cardinal`) maps cleanly to a regex. High-value rule.

**Large mixed surfaces** (`Int(bitPattern:` 180, `__unchecked:` 41) need careful regex design to flag only the anti-pattern variant, not the legitimate integration-overload / extension-init use:
- `Int(bitPattern: cardinal_value)` — legitimate (the integration overload itself per `[INFRA-002]`); should NOT fire
- `Int(bitPattern: foo.rawValue)` — anti-pattern (chains through `.rawValue`); SHOULD fire
- `init(__unchecked _: ()) { ... }` declaration — legitimate (extension init machinery); should NOT fire
- `Foo(__unchecked: (), bar.rawValue)` call site — anti-pattern; SHOULD fire

The legitimate forms outnumber the anti-pattern forms in the 180-file `Int(bitPattern:` surface. A naive regex `Int\(bitPattern:` would have 180 hits with most being false positives.

### Canonical preference hierarchy (from `[CONV-016]`)

| Tier | Mechanism | When | Example |
|---|---|---|---|
| 1 | `.retag()` | tag changes, value unchanged | `index.retag(Byte.self)` |
| 2 | `.map()` | value transforms, tag preserved | `count.map { Ordinal($0) }` |
| 3 | typed arithmetic | composed/chained operations | `.zero + count`, `index + .one` |
| 4 | typed initializer | system boundary entry | `try Index(int)`, `Ordinal(uint)` |
| 5 | `rawValue` / `__unchecked` | last resort, no typed path | same-package internals only |

The decision rule the user wants enforced: *"Can I retag? Can I map?"* Before any conversion. If both no, proceed to tier 3. If tier 3 doesn't apply, tier 4. Tier 5 requires justification.

### Rule-by-rule design

For each candidate rule, the design notes: regex, false-positive analysis, severity, expected violation count from baseline, decision (LAND / DEFER / SKIP).

#### R1. `count - 1` and family

**Pattern**: bare `count - 1` (and the existing-clean variants `count -= 1`, `count &-= 1` for completeness).

**Regex**: `\bcount\s*-\s*1\b` (MAY also include `\bcount\s*-=\s*1\b`, `\bcount\s*&-=\s*1\b` though both currently zero).

**False-positive analysis**:
- `count - 1` where `count: Cardinal` — won't compile per `[INFRA-200]`, so this case is impossible
- `count - 1` where `count: Index<T>.Count` — same, won't compile
- `count - 1` where `count: Int` — anti-pattern, exactly what we want to flag
- Comments/strings containing `count - 1` — false positive (excluded via `match_kinds: [identifier]`)

**Severity**: warning (consistent with other typed-arithmetic encouragements)

**Expected hits**: 34 → goes to ~50-100+ at the rule level (each file may have multiple instances).

**Decision**: **LAND.** High value, clear anti-pattern, easy regex.

**Caveat**: the rule fires on the surface form. The actual remediation per `[INFRA-025]` is context-aware (saturating vs exact subtraction depending on the desired behaviour on zero); the rule message MUST cite `[INFRA-025]` so the fixer can pick the right replacement.

#### R2. `Cardinal(0)` and `Cardinal(1)`

**Pattern**: `Cardinal(0)` or `Cardinal(1)` constructor calls.

**Regex**: `\bCardinal\(\s*[01]\s*\)`

**False-positive analysis**:
- Legitimate use cases for `Cardinal(0)` / `Cardinal(1)` are rare to nonexistent — `.zero` / `.one` are the canonical accessors per `[INFRA-101]`
- Could fire inside generic type parameters where `Cardinal(0)` is interpreted differently — unlikely

**Severity**: warning

**Expected hits**: 2 (almost clean already; landing the rule prevents regression).

**Decision**: **LAND.** Trivial cost, prevents regression on a near-clean surface.

#### R3. `.rawValue.` chains

**Pattern**: `.rawValue` followed by another `.` member access (e.g., `count.rawValue.something`, `position.rawValue.foo`).

**Regex**: `\.rawValue\.\w+`

**False-positive analysis**:
- Bare `.rawValue` (terminal access) is sometimes legitimate — e.g., extension-init internals, last-resort interop. Excluded by requiring `\.\w+` after.
- `.rawValue` inside a string literal — excluded via `match_kinds: [identifier]`.
- Chains in tests — already covered by `[CONV-001a]`; should fire ecosystem-wide.

**Severity**: warning

**Expected hits**: 12 (small cleanup surface).

**Decision**: **LAND.** Direct evidence of the canonical anti-pattern.

#### R4. `Int(bitPattern: <something>.rawValue ...)` chains

**Pattern**: `Int(bitPattern:` argument that contains `.rawValue` (the chain that `[INFRA-002]`/`[INFRA-021]` forbids).

**Regex**: `Int\(bitPattern:\s*[^)]*\.rawValue` — flag if any `.rawValue` appears between `Int(bitPattern:` and the closing `)`.

**False-positive analysis**:
- Bare `Int(bitPattern: cardinal)` — does not contain `.rawValue` → NOT flagged ✓
- `Int(bitPattern: foo.bar)` (any non-`.rawValue` member access) — NOT flagged ✓
- `Int(bitPattern: foo.rawValue)` — flagged ✓ (the canonical anti-pattern)
- `Int(bitPattern: foo.rawValue.bar)` — flagged ✓
- Multi-line `Int(bitPattern:\n    foo.rawValue\n)` — depends on regex engine behaviour; SwiftLint's NSRegularExpression handles `[^)]*` greedily but stops at `)` and may handle newlines depending on `match_kinds:` and `dot_matches_newlines:` flags. May need a multi-line-friendly alternative.
- `Int(bitPattern: arr[i].rawValue)` — flagged ✓ (still the chain)

**Severity**: warning

**Expected hits**: subset of 180. Without re-grepping with the chain regex, hard to estimate; conservatively maybe 30-80 of the 180 are chain-form.

**Decision**: **LAND** with the chain-only regex (not the bare form). The chain regex is the rule's actual semantic intent; the bare form is the legitimate integration overload.

#### R5. `__unchecked:` use at call sites

**Pattern**: `__unchecked:` argument label appearing at a call site (NOT at a parameter declaration).

**Regex**: `__unchecked:` matches both call sites AND declaration sites.

**False-positive analysis**:
- Declaration site `init(__unchecked _: (), ...)` — necessary infrastructure; legitimate
- Call site `Foo(__unchecked: (), ...)` — Tier 5 use; anti-pattern in most cases per `[CONV-001]`/`[CONV-002]`
- SwiftLint's regex cannot reliably distinguish the two without SwiftSyntax-level context

**Workarounds considered**:
- `match_kinds: [argument]` — may scope to call-site argument labels; needs empirical verification (Phase 1.5 hit a case where `match_kinds: [keyword]` didn't behave as expected for `throws` token).
- File-path scoping — declaration sites cluster in `Sources/.../Tagged.swift`, `Index.swift`, etc. (the typed-primitive declarations); excluding those paths could reduce false positives.

**Decision**: **DEFER.** The 41-file surface has a substantial fraction of legitimate declaration-site uses. A SwiftLint regex rule has high false-positive risk. Implementation belongs in the SwiftSyntax-based tooling Phase (per `ai-context-reduction-via-type-system-tooling.md` Option D Symbol-graph pipeline) where call-site vs. declaration-site is a structural property the AST exposes directly.

#### R6. Bare `Int(bitPattern:` (without `.rawValue` chain)

**Pattern**: `Int(bitPattern:` followed by anything that isn't a `.rawValue` chain.

**False-positive analysis**:
- `Int(bitPattern: cardinal)` — IS the legitimate `[INFRA-002]` integration overload. Not a violation.
- `Int(bitPattern: ordinal)` — IS the legitimate `[INFRA-003]` integration overload.

**Decision**: **SKIP.** This pattern is the canonical integration-overload use that `[INFRA-002]`/`[INFRA-003]` explicitly endorse. Flagging it would oppose the canonical recommendation.

#### R7. `Swift.min(...rawValue ...)` and `Swift.max`

**Pattern**: `Swift.min(` or `Swift.max(` where any argument is a `.rawValue` access — should be `Type.min(a, b)` per `[INFRA-103]`.

**Empirical**: 0 hits.

**Decision**: **SKIP for now** — already clean. Prevention rule could be added if regression occurs, but the discipline is universal so unlikely.

#### R8. `position.rawValue + ...` and other manual-arithmetic-on-rawValue

**Pattern**: `\w+\.rawValue\s*[+\-*/]` — arithmetic immediately after `.rawValue`.

**Empirical**: 0 hits for `position.rawValue +`. Not surveyed for other variants but likely also zero given the universal `.successor` / `.advance` discipline.

**Decision**: **SKIP for now** — already clean.

### Encouragement rules: can SwiftLint enforce the *positive* preference?

The user's directive is *"prefer map and retag"*. SwiftLint custom rules can flag forbidden patterns but cannot easily flag *absence* of preferred patterns. To enforce *"this conversion site should use `.retag()`"*, the rule would need to know:

1. Which sites are conversions (cross-tag, cross-rawValue, etc.)
2. Whether the canonical mechanism applies (Tier 1 vs Tier 2 vs Tier 3 vs Tier 4 vs Tier 5)
3. The current implementation's tier
4. Whether a higher tier is achievable

This is fundamentally a SwiftSyntax / Symbol-graph problem — pattern recognition on the AST, not text-regex. Per `ai-context-reduction-via-type-system-tooling.md` Option D, the Symbol-graph pipeline can detect signature-level patterns (untyped throws, ~Copyable consistency, conversion-tier signatures) at ecosystem scale.

The negative rules above (R1-R4) catch *drift away* from the hierarchy — they encourage the canonical patterns indirectly by making non-canonical patterns visible. The positive enforcement (R0: "this should use `.retag()`") requires AST tooling beyond SwiftLint's regex reach.

### Summary table

| Rule | Pattern | Files | Cost | Decision | Tier |
|---|---|---|---|---|---|
| R1 | `count - 1` | 34 | one-liner regex | **LAND** | Tier 2 (primitives-specific) |
| R2 | `Cardinal(0)` / `(1)` | 2 | one-liner regex | **LAND** | Tier 2 |
| R3 | `.rawValue.` chains | 12 | one-liner regex | **LAND** | Tier 2 |
| R4 | `Int(bitPattern: foo.rawValue)` chains | ~30-80 (subset of 180) | regex | **LAND** | Tier 2 |
| R5 | `__unchecked:` at call sites | subset of 41 | requires AST | **DEFER to SwiftSyntax tooling** | — |
| R6 | bare `Int(bitPattern:)` | 180 (legitimate) | — | **SKIP** (the canonical integration overload) | — |
| R7 | `Swift.min(rawValue ...)` | 0 | — | **SKIP** (already clean) | — |
| R8 | `position.rawValue +` arithmetic | 0 | — | **SKIP** (already clean) | — |
| R0 | encouragement: "this should use `.retag()`" | n/a | requires AST + tier-classification | **DEFER to SwiftSyntax tooling** | — |

---

## Outcome

**Status**: RECOMMENDATION (2026-05-05).

### Recommended near-term cohort (4 rules, all Tier 2 swift-primitives canonical)

Land R1-R4 as Tier 2 SwiftLint custom rules in `swift-primitives/.github/.swiftlint.yml`:

| ID | Name | Regex | Severity |
|---|---|---|---|
| R1 | `cardinal_count_minus_one_anti_pattern` | `\bcount\s*-\s*1\b` | warning |
| R2 | `cardinal_zero_one_constructor_anti_pattern` | `\bCardinal\(\s*[01]\s*\)` | warning |
| R3 | `chained_rawvalue_access_anti_pattern` | `\.rawValue\.\w+` | warning |
| R4 | `bitpattern_rawvalue_chain_anti_pattern` | `Int\(bitPattern:\s*[^)]*\.rawValue` | warning |

Each rule is severity:warning to allow gradual cleanup; the existing `--strict` mode in CI gates them effectively as errors. Each carries a message that cites the canonical replacement: `[INFRA-025]` for R1, `[INFRA-101]` for R2, `[INFRA-103]` for R3, `[INFRA-002]` / `[CONV-016]` for R4.

**Why Tier 2 (not Tier 1)**: these rules reference primitives-specific types (`Cardinal`, `.rawValue` on Tagged-types) that do not exist in other ecosystems. Placing them at Tier 1 would force-apply them to swift-foundations / swift-standards / etc., which haven't yet converged on the high-typed convention. Tier 2 = swift-primitives-specific is the correct architectural placement (matches `[PLAT-ARCH-008c]` and `no_foundation_import_*` precedent in the existing Tier 2 config).

**Expected diagnostic surface on landing**: ~80-130 violations across swift-primitives sources, concentrated in:
- swift-buffer-primitives (multiple categories)
- swift-tree-primitives (count - 1)
- swift-ordinal-primitives (Int(bitPattern:) chains)
- swift-hash-table-primitives (Int(bitPattern:) chains)

These are real cleanup targets; failing CI is the intended diagnostic per the user's earlier-stated posture.

### Deferred to SwiftSyntax-based tooling phase

Two classes of rule cannot be reliably implemented in SwiftLint regex:

1. **R5: `__unchecked:` at call sites only** — requires call-site-vs-declaration-site distinction. Belongs in the Symbol-graph pipeline (`ai-context-reduction-via-type-system-tooling.md` Option D Phase 2-4).
2. **R0: positive enforcement of preferred patterns** — requires conversion-tier classification on the AST (which sites are conversions; what tier their current implementation occupies; whether a higher tier is achievable). Same Symbol-graph pipeline.

Both depend on the `ai-context-reduction-via-type-system-tooling.md` Phase 2 work landing first. Tracked as future Phase: name TBD (perhaps "Phase 3: AST-driven enforcement").

### Rules deliberately NOT recommended

- **Bare `Int(bitPattern:)`**: this IS the `[INFRA-002]` integration overload. Flagging it would oppose canonical guidance.
- **`Swift.min(rawValue ...)`**, **`count -= 1`**, **`count &-= 1`**, **`position.rawValue +` arithmetic**: zero current hits; rules would add catalog noise without catching anything. If regression occurs, can be added then.

### Cross-cohort note: composability with prior Phase 1.5 / Tier-A landings

The cohort composes cleanly with the existing Tier 2 rules:

| Existing Tier 2 (primitives-specific) | Phase | What it enforces |
|---|---|---|
| `no_foundation_import_error` / `no_foundation_import_warning` | 1.5 (γ-1a migration) | Foundation-family imports forbidden |
| `l1_no_platform_conditionals` | 1.5 ([PLAT-ARCH-008c]) | L1 primitives unconditionally platform-agnostic |
| R1-R4 (this cohort) | next | high-typed Cardinal/Ordinal/Vector enforcement |

All five primitives-specific rules share Tier 2's reach (the 132 swift-primitives sub-packages) and severity model (warning, gated to error via `--strict`).

### Next-step proposal

Subject to your approval, the next dispatch lands R1-R4 as a single Tier 2 update commit, fans out to no consumer code (rules-only), and re-canaries the 4 publics to observe the ~80-130 expected violations. Source-cleanup of the surfaced violations is a separate Phase (analogous to how Phase 1.5 deferred source-cleanup of [DOC-003] / [PRIM-FOUND-001] / [API-IMPL-005] / etc.).

---

## References

### Internal

- **[CONV-016] Master Preference Hierarchy** — `swift-institute/Skills/conversions/SKILL.md`
- **[CONV-017] retag — Domain Change** — same file
- **[CONV-018] map — Value Transformation** — same file
- **[CONV-001] / [CONV-002] / [CONV-001a] rawValue Location** — same file
- **[CONV-010] Prefer Typed Arithmetic** — same file
- **[CONV-011] Count Chain for Cross-Domain Index Conversion** — same file
- **[INFRA-002] Cardinal Integration**, **[INFRA-003] Ordinal Integration**, **[INFRA-004] Affine Integration** — `swift-institute/Skills/existing-infrastructure/SKILL.md`
- **[INFRA-020] Before Writing Int(bitPattern:)**, **[INFRA-021] Before Writing .rawValue**, **[INFRA-025] Before Writing count - 1** — same file
- **[INFRA-101] Cardinal Quantities**, **[INFRA-102] Ordinal Positions**, **[INFRA-103] Tagged Functors — retag and map**, **[INFRA-104] Affine.Discrete.Ratio**, **[INFRA-200] Operations Intentionally Missing** — same file

### Prior research

- `swift-institute/Research/affine-operator-unification-completeness.md` (DEFERRED)
- `swift-institute/Research/ai-context-reduction-via-type-system-tooling.md` (RECOMMENDATION)
- `swift-institute/Research/operator-ergonomics-and-carrier-migration.md` (RECOMMENDATION, Option G)
- `swift-institute/Research/bounded-index-precondition-elimination.md` (SUPERSEDED by [IMPL-050..053])
- `swift-institute/Research/mechanical-rule-tool-classification-swift-primitives.md` v1.0.0 — bucket classification of [INFRA-020], [INFRA-024], [INFRA-025] and other relevant rules
- `swift-institute/Research/rollout-phase-1-results.md` v1.1.0 — Phase 1.5 / Tier-A landing baseline this cohort builds on

### Cross-skill rule references

- `swift-institute/Skills/handoff/SKILL.md` — [HANDOFF-013a] writer-side prior-research grep (informed the Step 0 internal grep here)
- `swift-institute/Skills/research-process/SKILL.md` — [RES-019], [RES-020], [RES-022], [RES-023] (informed methodology)
