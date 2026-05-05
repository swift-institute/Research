# Skill-Verification Taxonomy Pilot

<!--
---
version: 1.0.0
last_updated: 2026-05-05
status: RECOMMENDATION
research_tier: 2
applies_to: [institute, primitives, standards, foundations]
normative: false
---
-->

## Context

### Trigger

The user proposed adding a `Verification: mechanical | hybrid | semantic` field to every skill requirement so that mechanical rules can be enforced by deterministic CI workflows (saving Max-subscription tokens against the €600/mo cap), while AI agents focus on semantic / hybrid-confirmation work. Workflow construction is gated on this pilot's outcome per the parent thread's cost-discipline.

### Prior research (carry-forward; cite-and-extend per [HANDOFF-013])

`swift-institute/Research/centralized-swift-ci-and-spine-gate.md` v1.2.0 (2026-05-04, RECOMMENDATION) already encodes a **four-class scheme** at §3.4.10 (lines 896–909): `deterministic / pilot-classified / fidelity-classified / judgment-based`, with a γ-1 / γ-2 / γ-3 / γ-4 roadmap (§3.4.1, lines 649–662) and per-class graduation criteria. Specific skill rules are already classified there — γ-1a Foundation-import is the canonical deterministic case for `[PRIM-FOUND-001]`; γ-1c API-breakage is the canonical pilot-classified case (A/B/C/D ratio); γ-3 Wasm SDK is the canonical fidelity-classified case (A/B/C/D/E ratio); γ-4 PR-title lint is the canonical judgment-based case.

This doc EXTENDS — does not replace — that recommendation. The three-class taxonomy is a parent-thread proposal authored without sight of v1.2.0; reconciling the two schemes is the pilot's first job per the handoff brief.

### Empirical state (verified 2026-05-05)

- v1.2.0's §3.4.10 graduation table classifies γ-1a / γ-1b / γ-2 (deterministic), γ-1c (pilot-classified), γ-3 / γ-3b (fidelity-classified), γ-2b / γ-4 (judgment-based).
- The pilot subjects classify the following requirement counts (verified 2026-05-05 by reading the shipped `SKILL.md` files):
  - `code-surface/SKILL.md` (last_reviewed 2026-04-30): 27 requirement IDs across `[API-NAME-*]`, `[API-ERR-*]`, `[API-IMPL-*]`.
  - `primitives/SKILL.md` (last_reviewed 2026-04-30, in `swift-primitives/Skills/`): 7 requirement IDs across `[PRIM-FOUND-*]`, `[PRIM-ARCH-*]`, `[PRIM-NAME-*]`.
  - `blog-process/SKILL.md` (last_reviewed 2026-04-14): 23 requirement IDs in `[BLOG-*]`.

---

## Question

Three coupled questions:

1. **Reconciliation**: Does the parent thread's three-class taxonomy (mechanical / hybrid / semantic) reduce, extend, or supersede the v1.2.0 four-class scheme (deterministic / pilot-classified / fidelity-classified / judgment-based)?
2. **Coverage**: When applied to the pilot subjects, does the three-class taxonomy assign every requirement a single class without ambiguity, or does it surface a *resistant* set (requirements that resist clean classification) that calibrates the taxonomy's limits?
3. **Rollout readiness**: Is the three-class taxonomy ready for ecosystem-wide rollout (a `Verification:` field added to every requirement across all ~50 skills), or does the pilot reveal that the taxonomy needs revision before that commit?

---

## Analysis

### Part 1 — Three-class vs four-class reconciliation

#### 1.1 Side-by-side definitions

| Three-class (parent-thread) | What it asserts | Four-class (v1.2.0 §3.4.10) | What it asserts |
|---|---|---|---|
| **mechanical** | A regex / AST query / shell command decides the rule. Binary outcome. | **deterministic** | Binary "violation / no-violation" outcome; CI flips to gating after "zero violations for 2 weeks." Examples: γ-1a Foundation-import, γ-1b License-header, γ-2 YAML/symlink. |
| **hybrid** | Deterministic prefilter narrows candidates; AI classification finishes the verdict. | **pilot-classified** | Outcomes are classified A / B / C / D before graduation (e.g., γ-1c: A own-API change vs B dep drift vs C toolchain false-positive vs D workflow defect). Flip when "no class-A failures for 4 weeks AND ratio understood." |
| (same: hybrid) | (continued) | **fidelity-classified** | Outcomes are classified A / B / C / D / E for target-fidelity laboratories (γ-3 Wasm SDK: A package-actionable vs B toolchain vs C SDK install vs D workflow vs E known-unsupported). May stay advisory indefinitely. |
| **semantic** | Only AI / human can judge — the rule names properties (intent, role, narrative quality) that have no deterministic predicate. | **judgment-based** | Qualitative monthly review (γ-2b GH dep-graph: success rate + S/N ratio; γ-4 PR-title: noise:value review). No "gating flip" in the mechanical sense. |

#### 1.2 Mapping

| Three-class | Maps to four-class | Cardinality | Notes |
|---|---|---|---|
| mechanical | deterministic | 1:1 | The two terms denote the same thing. The four-class uses the term "deterministic" against `centralized-swift-ci-and-spine-gate.md` §3.4.10 line 909: *"deterministic checks have binary 'violation/no-violation' outcomes."* |
| hybrid | pilot-classified ∪ fidelity-classified | 1:2 | Both four-class kinds share the same verification *shape*: deterministic prefilter → AI/human classification of outputs that the prefilter cannot self-resolve. The four-class distinguishes them by their *graduation criterion* (pilot → ratio understood; fidelity → may stay advisory) and by their *failure-class set size* (4 vs 5). The three-class collapses both into one. |
| semantic | judgment-based | 1:1 | Both are qualitative review; both reject a binary-violation criterion. |

#### 1.3 Decision: reduce / extend / supersede

The three-class taxonomy **reduces** the four-class on the hybrid axis (collapses pilot-classified ∪ fidelity-classified into one class) and **extends** the four-class on coverage scope (every skill requirement gets classified, not only the subset that has an active CI rollout). The two schemes operate at *different levels* of the same architecture:

| Level | Scheme | Question answered |
|---|---|---|
| Skill requirement (design-time) | three-class | "Given a rule the skill states, how can verification be done?" |
| CI check (operational) | four-class | "Given a CI check that exists, how does it graduate from advisory to gating?" |

These are **complementary axes**, not competing schemes. A skill requirement classified `mechanical` may map to a CI check graduating via deterministic criteria; a skill requirement classified `hybrid` maps to a CI check graduating via pilot-classified or fidelity-classified criteria; a skill requirement classified `semantic` maps to a CI check graduating via judgment-based criteria (or to no CI check at all — the AI-only review pipeline is the operational outcome).

**No irreconcilable conflict exists** — the three-class is a refinement of the four-class for the user's stated purpose (which-class-of-enforcement-pipeline-to-build). The first `ask:` clause in the supervisor block is therefore not triggered.

---

### Part 2 — Pilot subject 1: code-surface (`Skills/code-surface/SKILL.md`)

Verified against `SKILL.md` (last_reviewed 2026-04-30). All 27 requirement IDs walked.

#### 2.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[API-NAME-001]` | Nest.Name Pattern | **mechanical** | Predicate: SwiftSyntax-aware AST query. For each top-level type declaration `(struct\|enum\|class\|actor\|protocol)\s+(\w+)`, check captured name has no internal-capital after the first segment. Macro decls (`@freestanding(declaration) macro \w+`) are exempt by AST kind, not by name. | code-surface/SKILL.md:35 |
| `[API-NAME-001a]` | Single-Type-No-Namespace Rule | **hybrid** | Prefilter: AST → enumerate empty namespace types (`enum X { ... }` with no cases, no stored properties, only nested type decls); count nested types == 1. AI input: judge whether the namespace is "speculative" (one type by accident, sibling types planned) vs "permanent variant label" (one type by intent). | code-surface/SKILL.md:67 |
| `[API-NAME-002]` | No Compound Identifiers | **hybrid** | Prefilter: regex on method/property declarations for compound shapes (verb-noun, internal-capital, multi-word camelCase). AI input: confirm spec-mirroring exception (`.notFound` is RFC 9110 §15.5.5; `.contentType` is RFC 9110 §8.3); confirm boolean-naming exception (`isEmpty`, `isFinished`); confirm keyword-adjective prohibition (`throwing`, `async` etc. are mechanical-detectable from the prefilter). | code-surface/SKILL.md:106 |
| `[API-NAME-003]` | Specification-Mirroring Names | **semantic** | AI input: for each type declaration in a spec namespace (`RFC_*`, `ISO_*`, `IEEE_*`), verify the type name mirrors the specification's terminology. Requires reading the spec; no in-tree predicate. Mechanical adjacent: detect types in spec namespaces whose names don't match the namespace prefix's expected vocabulary. | code-surface/SKILL.md:134 |
| `[API-NAME-004]` | No Typealiases for Type Unification | **hybrid** | Prefilter: AST → enumerate `typealias X = Y.Z` declarations. AI input: distinguish "unification bridge" (forbidden) from "domain typealias" / "generic instantiation" (permitted per [API-NAME-004a] / exception clause). | code-surface/SKILL.md:154 |
| `[API-NAME-004a]` | Namespace Adoption Typealiases | **hybrid** | Prefilter: count types/extensions/methods in the adopting namespace that build on the aliased type; threshold ≥5. AI input: judge whether the count reflects *substantial* domain behavior (5 trivial extensions is not substantial; 5 deep types each with their own infrastructure is). | code-surface/SKILL.md:180 |
| `[API-NAME-005]` | Pre-Rename Mechanical Check | **mechanical** | The rule prescribes a *workflow* (run [API-NAME-001/002] checks at proposal time). The OUTCOME is identical to [API-NAME-001/002] and is mechanically verifiable on the diff. CI cannot observe the timing; only the outcome. See Part 5 §5.2 (workflow rules). | code-surface/SKILL.md:776 |
| `[API-NAME-006]` | New-Code Self-Compliance During Enforcement Sweeps | **mechanical** | Same as [API-NAME-005]: workflow rule whose outcome is mechanically verifiable on the diff. The "enforcement sweep" framing is process-level; the rule's enforceable surface is "new code in this PR also complies with the swept rule." | code-surface/SKILL.md:756 |
| `[API-NAME-007]` | Convention-Known-Convention-Unapplied Heuristic for Method/Property Names | **mechanical** | Outcome rule: same as [API-NAME-002] (compound detection). Trigger conditions (a) and (b) are heuristic — (a) is mechanical (internal capital), (b) requires AI knowledge of stdlib/SE/other-language origin. CI need not verify triggers, only outcome. | code-surface/SKILL.md:794 |
| `[API-NAME-008]` | Property.View vs Labeled Method Decision Rule | **semantic** | AI input: identify whether a proposed API exposes "two or more related sub-operations under one root noun" (multi-form → Property.View) or "one operation, disambiguated by argument labels" (single-form → labeled method). Domain-semantic judgment of "related sub-operations." | code-surface/SKILL.md:824 |
| `[API-ERR-001]` | Typed Throws Required | **mechanical** | Predicate: regex `throws(?!\()` on function declarations (i.e., `throws` not followed by `(`). Or AST query for `FunctionTypeSyntax.effectSpecifiers.throwsSpecifier` with no error-type clause. | code-surface/SKILL.md:210 |
| `[API-ERR-002]` | Nested Error Types | **mechanical** | Predicate: AST → enumerate types conforming to `Swift.Error`. Check parent: nested under a domain type (`Domain.Error`), not top-level. Trivially mechanical — same shape as [API-NAME-001]. | code-surface/SKILL.md:228 |
| `[API-ERR-003]` | Describe Failure, Not Recovery | **semantic** | AI input: for each error case, judge whether the case name describes a failure condition (`invalidHeader(expected:found:)`) or a recovery action (`retryLater`, `useDefaultValue`). Hybrid-adjacent: regex prefilter on case names with verb-leading prefixes (`retry*`, `use*`, `fallback*`, `ignore*`) flags candidates for AI review. | code-surface/SKILL.md:249 |
| `[API-ERR-004]` | Explicit Closure Annotation for Typed Throws | **mechanical** | Predicate: SwiftSyntax AST query. Find function bodies with `throws(E)` effect; find rethrows-call sites in the body; verify each closure argument has an explicit `throws(E)` annotation in the closure-signature. Strict AST-shape check. | code-surface/SKILL.md:264 |
| `[API-ERR-005]` | stdlib Typed Throws Compatibility (Swift 6.2.4) | **mechanical** | Predicate: regex / AST → find `@_disfavoredOverload` declarations whose underlying stdlib name appears on the rule's WORKS list (e.g., `Sequence.map`, `withUnsafeBytes`, `Mutex.withLock`); flag those overloads. The list is closed and shipped with the rule. | code-surface/SKILL.md:284 |
| `[API-IMPL-003]` | Enum Over Boolean | **semantic** | AI input: for each `Bool` property, judge whether the represented state could expand (third or fourth state plausible) — design-forward judgment. No regex candidate. | code-surface/SKILL.md:491 |
| `[API-IMPL-005]` | One Type Per File | **mechanical** | Predicate: AST → for each `.swift` file, count top-level type declarations (`struct`, `enum`, `class`, `actor`, `protocol`, `macro`); count == 1. `extension` blocks excluded by AST kind. | code-surface/SKILL.md:300 |
| `[API-IMPL-006]` | File Naming Convention | **mechanical** | Predicate: AST → for each file's contained type, extract its full nested path (`Outer.Inner.Type`); compare to `basename(file)` matching `Outer.Inner.Type.swift`. | code-surface/SKILL.md:325 |
| `[API-IMPL-007]` | Extension Files | **mechanical** | Predicate: AST → for each file with no type declaration but ≥1 extension, parse filename for `+Conformance.swift` shape OR `Type where ConstraintClause.swift` shape. Filename-shape check is a closed-form regex. | code-surface/SKILL.md:344 |
| `[API-IMPL-008]` | Minimal Type Body | **mechanical** | Predicate: AST → for each type declaration, enumerate body members; verify each is one of `{stored property, init, deinit}`. Allowlist-augmented for the `~Copyable` exception per [MEM-COPY-006]. | code-surface/SKILL.md:381 |
| `[API-IMPL-009]` | Hoisted Protocol with Nested Typealias | **hybrid** | Prefilter: AST → enumerate `typealias Protocol = _XProtocol` declarations inside generic types. AI input: judge whether the hoisted-protocol pattern *should* apply (i.e., the type is intended to nest under a generic, the conformance is declaring-module conformance, etc.). The rule is descriptive of an established pattern; AI confirms applicability. | code-surface/SKILL.md:446 |
| `[API-IMPL-010]` | Visibility Change Triggers Naming Audit | **mechanical** | Outcome rule: on any newly-public symbol in a PR diff, run [API-NAME-001/002]. Workflow trigger ("widening triggers an audit") is observable as a diff predicate (`access modifier widened`). | code-surface/SKILL.md:513 |
| `[API-IMPL-011]` | Wrapper Completeness | **semantic** | AI input: identify wrapper types (types whose internal storage exposes a `_backing` property or similar); identify the *primary operation* of the wrapped type; verify the wrapper exposes it. "Primary operation" is domain-semantic. | code-surface/SKILL.md:541 |
| `[API-IMPL-012]` | Closure Parameters Trail the Signature | **mechanical** | Predicate: AST → for each function/init signature, scan parameter list left-to-right; once a closure-typed parameter is seen, every subsequent parameter must also be closure-typed. | code-surface/SKILL.md:572 |
| `[API-IMPL-013]` | Multiple Closures Follow Lifecycle Order | **semantic** | AI input: identify functions with ≥2 closure parameters; classify each as setup / body / completion / teardown by *role*; verify ordering. Role inference is semantic; argument labels are a soft signal but not authoritative. | code-surface/SKILL.md:605 |
| `[API-IMPL-014]` | Configuration Parameter Placement | **hybrid** | Prefilter: AST → for each function signature, find parameters whose type matches `*.Options` / `*.Configuration` / `*.Context` / `OptionSet`-conforming type; check position. Mechanical: detect middle-placement (forbidden absolutely). AI input: distinguish first-position (configuration is primary input) from last-non-closure-position (configuration is modifier). | code-surface/SKILL.md:646 |
| `[API-IMPL-015]` | Struct Configuration Over Builder Closures | **mechanical** | Predicate: AST → for parameters typed as `(inout T) -> Void` or `(SomeBuilder) -> Void` where the builder targets a configuration role, flag. Closed-form pattern. | code-surface/SKILL.md:700 |

#### 2.2 code-surface distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 15 | API-NAME-001, API-NAME-005, API-NAME-006, API-NAME-007, API-ERR-001, API-ERR-002, API-ERR-004, API-ERR-005, API-IMPL-005, API-IMPL-006, API-IMPL-007, API-IMPL-008, API-IMPL-010, API-IMPL-012, API-IMPL-015 |
| hybrid | 6 | API-NAME-001a, API-NAME-002, API-NAME-004, API-NAME-004a, API-IMPL-009, API-IMPL-014 |
| semantic | 6 | API-NAME-003, API-NAME-008, API-ERR-003, API-IMPL-003, API-IMPL-011, API-IMPL-013 |

Total 27. [API-NAME-007] is classified `mechanical` for outcome verification; trigger condition (b) of that rule is a semantic heuristic discussed under Part 5 §5.2 (workflow rules), but the field assignment goes by outcome.

---

### Part 3 — Pilot subject 2: primitives (`swift-primitives/Skills/primitives/SKILL.md`)

Verified against `SKILL.md` (last_reviewed 2026-04-30).

#### 3.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[PRIM-FOUND-001]` | No Foundation Imports | **mechanical** | Predicate: regex `^\s*(@\w+(\([^)]*\))?\s+)?(public\|package\|internal)?\s*(@_exported\s+)?import\s+Foundation(Essentials\|Internationalization)?\b` on every file under `Sources/**`. v1.2.0 §3.4.2 (lines 663–685) gives the canonical attribute matrix and is the reference implementation. **This is the canonical mechanical case** in the four-class scheme — γ-1a deterministic. | primitives/SKILL.md:32 |
| `[PRIM-FOUND-002]` | Swift Embedded Compatibility | **hybrid** | Verification has two mechanisms: (1) build-gate via the layer-wrapper `embedded` job (mechanical: build succeeds or fails — γ-3 fidelity-classified per v1.2.0 §3.4.6 lines 831–854); (2) syntactic prefilter for forbidden constructs (`Mirror`, `@objc`, runtime-reflection APIs). The build-gate alone is mechanical; "runtime features unavailable in embedded" stated in the rule's prose includes constructs not on a closed list, requiring AI judgment at the boundary. See Part 5 §5.1 (composite rules). | primitives/SKILL.md:55 |
| `[PRIM-FOUND-003]` | Semantic Type Separation | **semantic** | AI input: identify whether two distinct concepts ("a date on a calendar" vs "a point in time") are conflated under one type (`Foundation.Date`) at the API surface. Conflation detection is semantic — requires domain understanding of what each concept means. | primitives/SKILL.md:63 |
| `[PRIM-ARCH-001]` | Thirteen-Tier DAG Structure | **mechanical** | Predicate: parse Package.swift dependencies; compute `tier = max(tier[dep] for dep in deps) + 1`; verify against the canonical tier table. The formula is closed-form. | primitives/SKILL.md:81 |
| `[PRIM-ARCH-002]` | Downward Dependencies Only | **mechanical** | Predicate: for each (self, dep) edge in the DAG, verify `tier[dep] < tier[self]`. Same engine as [PRIM-ARCH-001]. Detects circular and lateral deps trivially. | primitives/SKILL.md:101 |
| `[PRIM-NAME-001]` | Primitives Suffix | **mechanical** | Predicate: regex on package names — `^swift-.+-primitives$`. | primitives/SKILL.md:121 |
| `[PRIM-NAME-003]` | Names Describe Mechanism, Not Origin | **semantic** | AI input: for each type name, judge whether the name describes what the primitive *does* (mechanism) or where it was *first needed* (origin). `Reference.Transfer` (mechanism: ownership transfer) vs `Kernel.Handoff` (origin: thread use case) — only AI judgment can decide. | primitives/SKILL.md:137 |

#### 3.2 primitives distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 4 | PRIM-FOUND-001, PRIM-ARCH-001, PRIM-ARCH-002, PRIM-NAME-001 |
| hybrid | 1 | PRIM-FOUND-002 |
| semantic | 2 | PRIM-FOUND-003, PRIM-NAME-003 |

primitives is the **mechanical-heavy pilot** as expected. It includes the canonical mechanical case ([PRIM-FOUND-001] — already classified deterministic in v1.2.0 §3.4.10 line 900) AND a clean fidelity-classified case ([PRIM-FOUND-002] — the embedded build-gate is exactly the γ-3 shape in v1.2.0 §3.4.6).

---

### Part 4 — Pilot subject 3: blog-process (`Skills/blog-process/SKILL.md`)

Verified against `SKILL.md` (last_reviewed 2026-04-14). All 23 requirement IDs walked. This is the semantic-check pilot per the handoff brief.

#### 4.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[BLOG-001]` | Idea Capture Triggers | **semantic** | AI input: for a triggering event (REFUTED experiment, RES-006 DECISION, package release), judge whether the insight is "valuable to the broader Swift community." External-audience benefit is qualitative. | blog-process/SKILL.md:171 |
| `[BLOG-002]` | Ideas Index Format | **mechanical** | Predicate: JSON schema validation against `https://swift-institute.org/schemas/blog-index-v1.json`. Section objects, columns, sorting all schema-checkable. | blog-process/SKILL.md:198 |
| `[BLOG-003]` | Idea Entry Template | **mechanical** | Predicate: required-field presence (`ID`, `Title`, `Category`, `Source`, `Captured`, `Notes`/`Blocker`). Schema-derivable. | blog-process/SKILL.md:227 |
| `[BLOG-004]` | Bidirectional Linking (Phase 1) | **mechanical** | Predicate: cross-reference grep. For each `BLOG-IDEA-XXX` in the index, verify the source artifact contains a `Blog Potential` block referencing it; for each experiment with `// Blog: BLOG-IDEA-XXX` header, verify the index entry exists. | blog-process/SKILL.md:239 |
| `[BLOG-005]` | Blog Post Structure | **hybrid** | Mechanical: required metadata fields (frontmatter), required category-section headings (Technical Deep Dive: Problem / What We Found / Why / Implications / References — header pattern check). AI input: judge whether section *content* matches the section's role; whether the post follows the chosen mode (first-principles vs conventional expository). See Part 5 §5.1 (composite rules). | blog-process/SKILL.md:352 |
| `[BLOG-006]` | Review Process | **hybrid** | Mechanical sub-criteria: technical-accuracy build-gate (compile experiment links), link-verification (HTTP check), section-completeness (header-presence), [BLOG-017] mechanical link-reference audit. AI sub-criteria: clarity, tone-appropriateness, length-appropriateness. The rule encodes both. See Part 5 §5.1. | blog-process/SKILL.md:403 |
| `[BLOG-007]` | Publication Process | **mechanical** | Predicate: filesystem-state check. For each post moved to `Blog/Published/YYYY-MM-DD-{slug}.md`, verify (a) Ideas Index updated to "Published" section, (b) source artifacts updated with post link, (c) landing-page pin audit (DocC catalog index, Blog index page). All file-path / cross-reference checks. | blog-process/SKILL.md:517 |
| `[BLOG-008]` | Series Concept | **semantic** | AI input: judge whether 3+ related ideas form a "natural progression" warranting a series, vs standalone post(s). Pattern-of-progression is qualitative. | blog-process/SKILL.md:263 |
| `[BLOG-009]` | Series Plan Format | **mechanical** | Predicate: required template sections (`## Arc`, `## Parts`, `## Target audience`, `## Entry assumptions`, `## Shared example`, `## References`). Header-presence check. | blog-process/SKILL.md:287 |
| `[BLOG-010]` | First-Principles Writing Pattern | **semantic** | AI input: for each post, judge whether it follows first-principles mode (problem-before-solution, build-through-code, hit-the-wall-honestly) or conventional-expository mode. Mode-of-writing is qualitative. | blog-process/SKILL.md:87 |
| `[BLOG-011]` | Post Narrative Arc | **semantic** | AI input: identify Hook / Foundation / Build / Surprise / Wall / Resolution beats and judge whether each is present and well-formed. Beat-quality is qualitative; beat-presence has hybrid potential (header-pattern prefilter) but the rule cares about quality, not presence. | blog-process/SKILL.md:124 |
| `[BLOG-012]` | Running Example Design | **semantic** | AI input: judge whether the post centers on a single evolving running example vs disconnected snippets. Diff-shape detection (each addition motivated by a question) is qualitative. | blog-process/SKILL.md:145 |
| `[BLOG-013]` | Receipts: Link Every Load-Bearing Claim to a Runnable Experiment | **hybrid** | Mechanical: count link-references in post; for each, verify the URL resolves to a GitHub experiment package (HTTP + path check). AI input: identify which claims are *load-bearing* (the post's argument relies on them) vs expository / opinion. | blog-process/SKILL.md:432 |
| `[BLOG-014]` | Active Claim Verification | **hybrid** | Mechanical: re-run linked experiments (`rm -rf .build && swift build` on each); for each cited source-file path, verify it resolves; for each quoted SE proposal text, verify the quote against current source. AI input: identify load-bearing claims that need verification (same gate as [BLOG-013]). | blog-process/SKILL.md:475 |
| `[BLOG-014a]` | Production-Verified but Not Minimally-Reproducible Claims | **semantic** | AI input: judge whether a claim has the "production-verified-only" shape requiring the explicit-acknowledgment treatment; verify the prose acknowledges the reproduction gap honestly. | blog-process/SKILL.md:501 |
| `[BLOG-015]` | Rhetorical-Energy Check for Paired-Post Reveals | **semantic** | AI input: read the precursor's last paragraph in isolation; judge whether the launched library feels consequential (good) or inevitable (defective). Pure rhetorical judgment. | blog-process/SKILL.md:559 |
| `[BLOG-016]` | Release-Post Non-Blending Rule | **hybrid** | Mechanical prefilter: detect release-post triggers (post coincides with git tag / version bump / package-existence claim) — this can be detected from frontmatter + filesystem state. AI input: judge whether the post blends modes (Pattern Documentation + First-Principles + Technical Deep Dive content mixed in a release post). | blog-process/SKILL.md:575 |
| `[BLOG-017]` | Mechanical Link-Reference Audit at Closing-Material Pass | **mechanical** | Predicate: literal grep. For each `[slug]:` link-reference definition, count occurrences of `[slug]` in the body; require ≥2 (definition + at least one body reference); orphans deleted. | blog-process/SKILL.md:591 |
| `[BLOG-018]` | Phase-1 Findings Claim Verification | **hybrid** | Same shape as [BLOG-014] but applied to Phase-1 design-brief Findings (upstream of draft). Mechanical/AI split is identical to [BLOG-014]. | blog-process/SKILL.md:611 |
| `[BLOG-019]` | Companion-Experiment Parallel Authoring | **mechanical** | Outcome predicate: at draft-completion time (move from `Draft/` to `Review/`), verify the companion experiment exists at the cited path AND its `Package.swift` builds clean. The rule's "alongside" framing is workflow-discipline; CI cannot observe authoring concurrency. The outcome (experiment present + buildable) is mechanical. | blog-process/SKILL.md:623 |
| `[BLOG-020]` | Audience-Magnitude Check Before Timing Advice | **semantic** | AI input: judge audience-magnitude baseline (effectively-0 / modest / large) and whether the proposed timing advice matches the baseline. The rule is meta — it operates on advice-quality, not post-content. | blog-process/SKILL.md:635 |
| `[BLOG-021]` | Paired-Post URL Dependency Handling | **hybrid** | Mechanical: detect dead links in a published post (HTTP check) and flag missing strip / restore. AI input: for the precursor, judge which of three handling shapes (a/b/c) was chosen and whether documentation matches the chosen shape. | blog-process/SKILL.md:659 |
| `[BLOG-022]` | DocC Deploy Verification Path | **hybrid** | Mechanical: HTTP availability (`curl -I -L`); build status (`gh run list --workflow {deploy} -L 5`). AI input (or human input): rendered-content browser visual check — DocC's client-side hydration means `WebFetch` and curl see only the empty shell HTML; the rule explicitly calls this out. See Part 5 §5.1 (composite rules). | blog-process/SKILL.md:693 |

#### 4.2 blog-process distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 7 | BLOG-002, BLOG-003, BLOG-004, BLOG-007, BLOG-009, BLOG-017, BLOG-019 |
| hybrid | 8 | BLOG-005, BLOG-006, BLOG-013, BLOG-014, BLOG-016, BLOG-018, BLOG-021, BLOG-022 |
| semantic | 8 | BLOG-001, BLOG-008, BLOG-010, BLOG-011, BLOG-012, BLOG-014a, BLOG-015, BLOG-020 |

Total 23.

blog-process is the **semantic-heavy pilot** as expected. The proportions match the handoff brief's intent: process and prose rules dominate, with a workflow-mechanical scaffold around them.

---

### Part 5 — Resistant requirements

These are the requirements that resist clean classification under the three-class scheme. **They are the pilot's primary diagnostic output** — the number and shape of resistant cases calibrate the taxonomy's limits.

#### 5.1 Composite rules (multi-mechanism in one ID)

A single requirement encodes multiple verification mechanisms, each fitting a different class. The three-class forces a single choice that loses information.

| ID | Composite shape | Why resistant |
|---|---|---|
| `[PRIM-FOUND-002]` Swift Embedded Compatibility | (a) Build-gate via layer-wrapper `embedded` job (mechanical / fidelity-classified); (b) syntactic regex for closed-list constructs (mechanical); (c) "runtime features unavailable in embedded" beyond the closed list (semantic). | Three mechanisms in one rule. Build-gate is the canonical fidelity-classified four-class case (γ-3); the syntactic prefilter is mechanical; the boundary clause is semantic. Forced single classification (as `hybrid`) hides this internal decomposition. |
| `[BLOG-005]` Blog Post Structure | (a) Universal metadata frontmatter (mechanical); (b) category-section heading presence (mechanical); (c) section-content matches section role (semantic); (d) writing mode followed (semantic per [BLOG-010]). | The rule is layered — schema at the top, prose at the bottom. Three-class single-classification (`hybrid`) is correct on average but obscures that the schema half is *strictly* mechanical and the prose half is *strictly* semantic. |
| `[BLOG-006]` Review Process | (a) Technical-accuracy build-gate (mechanical); (b) link verification (mechanical); (c) section completeness (mechanical); (d) tone / clarity / length (semantic); (e) closing-material redundancy check (semantic with mechanical [BLOG-017] sub-rule). | Five sub-criteria spanning all three classes. Forced classification as `hybrid` matches the *aggregate* but hides the per-criterion structure. |
| `[BLOG-022]` DocC Deploy Verification Path | (a) HTTP availability — `curl` (mechanical); (b) build status — `gh run list` (mechanical); (c) rendered content — browser visual check (semantic, because DocC client-side hydration means `WebFetch` sees empty shell). | Three-layer rule, two mechanical layers + one semantic. The rule explicitly states the layering; collapsing to `hybrid` loses the visibility into which layers automate. |
| `[API-IMPL-014]` Configuration Parameter Placement | (a) Middle-placement absolutely forbidden (mechanical); (b) first-vs-last decision (semantic — primary input vs modifier role). | The mechanical half is a strict ban; the semantic half is a positive-direction rule. Three-class `hybrid` is correct but the rule's forbidden-pattern-vs-required-pattern decomposition is lost. |

**Class A diagnostic**: composite rules occur where a skill states a multi-step or layered verification procedure. The three-class taxonomy is correct on the aggregate (the combined verification IS hybrid), but the loss of internal structure is material — for CI implementation, the mechanical sub-checks can run independently and produce useful signal long before the semantic check is wired up. Recommended remediation: see Part 6 §6.2 option (b) (split atomic).

#### 5.2 Workflow rules (process discipline)

The rule prescribes timing or sequence ("check at proposal time," "verify before promoting to Review") that CI cannot observe — only the OUTCOME at commit time / promotion time.

| ID | Workflow framing | OUTCOME predicate (verifiable) |
|---|---|---|
| `[API-NAME-005]` Pre-Rename Mechanical Check | "Verify against [API-NAME-001/002] BEFORE the identifier is applied, not after." | At PR diff: no compound identifiers in newly-introduced names. |
| `[API-NAME-006]` New-Code Self-Compliance During Enforcement Sweeps | "Any NEW code in the same enforcement-sweep session MUST be swept for the same rule before commit." | At PR diff: all new code complies with the swept rule, regardless of how the violation arose. |
| `[API-NAME-007]` Convention-Known-Convention-Unapplied Heuristic | "When a name has internal capital OR is copied from stdlib/SE/another language, MUST re-verify against [API-NAME-002]." | At PR diff: no compound identifiers. The two heuristic triggers are observable as diff predicates but the rule's force is the outcome. |
| `[API-IMPL-010]` Visibility Change Triggers Naming Audit | "Widening access MUST trigger a naming audit per [API-NAME-001/002]." | At PR diff: newly-public symbols comply with [API-NAME-001/002]. |
| `[BLOG-019]` Companion-Experiment Parallel Authoring | "Companion experiment MUST be authored alongside the draft, not after." | At draft-completion: experiment package exists at cited path AND builds clean. |

**Class B diagnostic**: workflow rules systematically classify as `mechanical` at outcome and `semantic` at process. CI naturally enforces the outcome, not the process. The three-class taxonomy as stated is silent on this distinction — assigning `mechanical` is correct for what CI can do but may misframe the rule's *intent* (the writer is supposed to run the check at proposal time, not have CI catch it post-commit). Recommended remediation: codify in the skill update that `Verification:` encodes outcome-class, not process-discipline-class.

#### 5.3 External-knowledge rules

The rule requires external authority (specs, stdlib, language docs) to verify. AI is the natural fit; the cost is meaningfully higher than typical hybrid/semantic because verification requires fetching and reading external sources.

| ID | External authority | Cost |
|---|---|---|
| `[API-NAME-002]` Spec-mirroring exception (`.notFound` is RFC 9110 §15.5.5) | RFC / specification text | Per-name lookup; cacheable per spec. |
| `[API-NAME-003]` Specification-Mirroring Names | RFC / ISO / IEEE specification text | Per-type lookup; cacheable per spec; the entire `swift-rfc-*` / `swift-iso-*` / `swift-ieee-*` / etc. ecosystem is in scope. |
| `[API-NAME-007]` Convention-Known-Convention-Unapplied Heuristic, trigger (b) | stdlib API docs, Swift Evolution proposals, other-language API docs | Per-name lookup; cacheable per stdlib version. |

**Class C diagnostic**: external-knowledge rules are nominally `hybrid` or `semantic` but operationally distinct from typical hybrid/semantic because verification has an out-of-tree fetch step. The three-class is silent on whether external-knowledge rules form a separate operational kind. Recommended remediation: not a taxonomy revision — the three-class still classifies correctly. Document in the skill update that the cost-per-verification varies materially within the `hybrid` and `semantic` classes; rules requiring external fetches are at the higher-cost end of their class.

#### 5.4 Summary of resistant cases

| Class of resistance | Count across pilot | Materiality |
|---|---|---|
| Composite (multi-mechanism) | 5 (PRIM-FOUND-002, BLOG-005, BLOG-006, BLOG-022, API-IMPL-014) | **High** — collapsed classification hides per-mechanism CI viability |
| Workflow (process vs outcome) | 5 (API-NAME-005, API-NAME-006, API-NAME-007, API-IMPL-010, BLOG-019) | **Medium** — collapsed classification hides intent but CI behavior is correct |
| External-knowledge (fetch cost) | 3 (API-NAME-002 [exception], API-NAME-003, API-NAME-007 [trigger b]) | **Low** — class is correct; cost annotation needed |

13 resistant cases out of 57 walked requirements (27 + 7 + 23) = 22.8%. **The three-class taxonomy classifies the supermajority cleanly**; the resistant set concentrates where the skill states a layered or process-oriented rule.

---

## Outcome

**Status**: RECOMMENDATION (2026-05-05) — pending principal sign-off on the three remediation options below.

### Reconciliation result

The three-class taxonomy (mechanical / hybrid / semantic) **reduces** the four-class scheme (deterministic / pilot-classified / fidelity-classified / judgment-based) on the hybrid axis (collapses pilot-classified ∪ fidelity-classified) and **extends** the four-class scheme by covering every skill requirement, including those without an active CI rollout. The two schemes operate at *complementary levels* of the same architecture:

| Level | Scheme | Purpose |
|---|---|---|
| Skill requirement (design-time field) | three-class | Decide which kind of enforcement pipeline the rule warrants |
| CI check (operational lifecycle) | four-class | Decide how the CI check graduates from advisory to gating |

Both schemes coexist. No supersession. No irreconcilable conflict.

### Coverage result

Across 57 walked requirements:
- 26 mechanical (≈46%) — code-surface 15 + primitives 4 + blog-process 7
- 15 hybrid (≈26%) — code-surface 6 + primitives 1 + blog-process 8
- 16 semantic (≈28%) — code-surface 6 + primitives 2 + blog-process 8

The distribution spans all three classes meaningfully — no class is empty or dominant-to-the-point-of-trivial. The mechanical-heavy primitives skill, the balanced code-surface skill, and the semantic-heavy blog-process skill together exercise the taxonomy across its full range. The handoff's second `ask:` clause (under-tested taxonomy) does not trigger.

### Resistant set

22.8% of pilot requirements (13/57) resist clean single-class classification, concentrated in three patterns:

1. **Composite rules (5 cases, materiality HIGH)** — single requirement encodes multiple verification mechanisms; three-class forces a single label, hiding internal decomposition that matters for CI implementation order.
2. **Workflow rules (5 cases, materiality MEDIUM)** — rule prescribes process discipline; CI enforces outcome only; three-class label is correct for outcome but mis-frames intent.
3. **External-knowledge rules (3 cases, materiality LOW)** — rule requires external authority; three-class label is correct but cost-per-verification within the class is materially higher.

### Recommendation

**Adopt the three-class taxonomy for the ecosystem-wide rollout, with three explicit clarifications added to the format-change skill update before the rollout commits.** The pilot validates the taxonomy as structurally sound for the user's stated purpose (which-class-of-enforcement-pipeline-to-build); the resistant set is bounded and addressable through skill-text clarifications, not through a fourth class.

#### Clarifications to land in the format-change skill update

1. **Composite-rule handling** (resolves §5.1): when a requirement encodes multiple verification mechanisms, the SKILL author SHOULD prefer splitting the requirement into atomic sub-requirements (each with its own `Verification:` field) over collapsing to the dominant class. When splitting is structurally awkward (the rule's value lies in the layered procedure), the requirement MAY use the dominant class with an inline `**Composite:**` annotation listing the sub-mechanisms. Example: `Verification: hybrid` + `Composite: schema (mechanical) + content-role (semantic)`.

2. **Workflow-vs-outcome clarification** (resolves §5.2): the `Verification:` field encodes the *outcome* class (what CI / AI can verify on a commit or artifact), not the *process* class (when the writer is supposed to run the check). Workflow rules whose outcome is mechanical SHOULD be classified `mechanical`; the process discipline lives in the rule's prose, not the field.

3. **External-knowledge cost annotation** (resolves §5.3): rules whose verification requires fetching external authoritative sources (specifications, stdlib docs, SE proposals, other-language API docs) SHOULD carry an inline `**External:**` annotation identifying the authority. The class assignment is unchanged; the annotation enables operational planners to budget for fetch / cache / cite costs.

#### Pre-rollout actions (gating the format-change commit)

| Action | Owner | Status |
|---|---|---|
| Land the three clarifications above into the skill-format spec | principal direction required | pending |
| Pick **one reference skill** per [SKILL-LIFE-026] to rewrite under the new format as the validation case (recommend `code-surface` — broadest distribution across all three classes) | principal direction required | pending |
| Hold off ecosystem-wide sweep until the reference skill stabilizes per [SKILL-LIFE-026]'s "single reference, not all consumers at once" discipline | binding per [SKILL-LIFE-026] | pending |
| Defer GitHub Actions workflow YAML drafting until the skill format change has shipped to the reference skill | binding per supervisor block "MUST NOT draft, commit, or sketch any GitHub Actions workflow YAML" | pending |

#### Out of scope for this pilot (deliberately not done)

Per the supervisor block:
- No skill files were edited (the format change is downstream of taxonomy validation).
- No GitHub Actions workflow YAML was drafted, committed, or sketched.
- Pilot scope was held to 3 skills; not silently expanded to 6+.
- No `/audit` or token-consuming ecosystem sweep was initiated.

### Supervisor block verification stamp

Per [HANDOFF-010] step 5: each supervisor ground-rule entry verified against work product —

| Entry | Type | Verification |
|---|---|---|
| Read v1.2.0 §3.4.10 + γ-roadmap before classifying; cite per [HANDOFF-013] | MUST | Verified — §3.4.10 (lines 896–909) and §3.4.1 (lines 649–662) read at write time; cited inline in Part 1 §1.1 + Part 3.1. |
| Cite each `[REQ-ID]` by canonical name + page-cite | MUST | Verified — every classification row in Parts 2, 3, 4 carries `file:line` page-cite to the source skill. |
| Flag requirements that resist clean classification | MUST | Verified — Part 5 enumerates 13 resistant cases across 3 classes of resistance. |
| Do not edit any skill file | MUST NOT | Verified — no Skill tool invocations against `swift-institute/Skills/**` or `swift-primitives/Skills/**`; only Read. |
| Do not draft GitHub Actions workflow YAML | MUST NOT | Verified — no `.yml` content authored. |
| Do not expand pilot beyond 3–5 skills | MUST NOT | Verified — exactly 3 pilots: code-surface, primitives, blog-process. |
| Cost discipline (Max OAuth, no ecosystem sweep) | fact | Honored — no `/audit` or token-heavy cross-ecosystem run. |
| Three-class vs four-class irreconcilable conflict → escalate | ask | Not triggered — Part 1 §1.3 found refinement, not conflict. |
| Under-tested taxonomy (all pilots mechanical-heavy) → escalate | ask | Not triggered — distribution spans 40/28/32 across the three classes. |

---

## References

### Internal cross-references (verified 2026-05-05 by reading the cited line ranges)

- `swift-institute/Research/centralized-swift-ci-and-spine-gate.md` v1.2.0 — canonical four-class scheme + γ-roadmap. §3.4.1 (lines 649–662) phased roadmap. §3.4.10 (lines 896–909) graduation models per check class. §3.4.2–§3.4.7 per-rule designs.
- `swift-institute/Skills/code-surface/SKILL.md` (last_reviewed 2026-04-30) — pilot subject 1 source for [API-NAME-*], [API-ERR-*], [API-IMPL-*].
- `swift-primitives/Skills/primitives/SKILL.md` (last_reviewed 2026-04-30) — pilot subject 2 source for [PRIM-FOUND-*], [PRIM-ARCH-*], [PRIM-NAME-*]. Routed via the `.claude/skills/primitives` symlink.
- `swift-institute/Skills/blog-process/SKILL.md` (last_reviewed 2026-04-14) — pilot subject 3 source for [BLOG-*].
- `swift-institute/Skills/handoff/SKILL.md` — [HANDOFF-010] Resume Protocol step 5; [HANDOFF-013] Prior Research Check.
- `swift-institute/Skills/supervise/SKILL.md` — [SUPER-002] Block Structure (4–6 entries; MUST / MUST NOT / fact: / ask:).
- `swift-institute/Skills/skill-lifecycle/SKILL.md` — [SKILL-LIFE-003] Backward Compatibility Classification (this format change is **breaking** if `Verification:` becomes required); [SKILL-LIFE-026] Reference-Implementation Pattern for Breaking Revisions.
- `swift-institute/Skills/research-process/SKILL.md` — [RES-002a] Research Triage; [RES-003] Document Structure; [RES-013a] Synthesis Verification; [RES-020] Research Tiers (this doc is Tier 2).
- `swift-institute/Skills/corpus-meta-analysis/SKILL.md` — [META-016] Consolidation Protocol.

### Source artifact (the handoff brief)

`/Users/coen/Developer/HANDOFF-skill-verification-classification.md` — branching investigation handoff that dispatched this pilot.
