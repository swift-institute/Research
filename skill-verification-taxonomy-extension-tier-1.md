# Skill-Verification Taxonomy Extension — Tier 1 (Infra/Process Skills)

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

Extension of the three-class verification taxonomy (`mechanical / hybrid / semantic`) from the 3-skill pilot (`skill-verification-taxonomy-pilot.md`, 57 requirements) to the **13 tier-1 infra/process skills** — the cluster the parent thread expects to carry the highest mechanical-rule density and to feed workflow construction directly. Dispatched as **dispatch 1 of 3** in a tiered classification sweep; tier 2 (code-shape skills) and tier 3 (voice/process skills) are separate, gated on this dispatch's review per the parent handoff.

The handoff brief (`/Users/coen/Developer/HANDOFF-classification-extension-tier-1.md`) names the deliverable: per-skill classification table per the pilot's Part 5 format, aggregate distribution across 13 skills, and a resistant-set diagnostic following the pilot's three resistant patterns (composite multi-mechanism, workflow-vs-outcome, external-knowledge fetch).

### Prior research (carry-forward; cite-and-extend per [HANDOFF-013])

- **`swift-institute/Research/skill-verification-taxonomy-pilot.md` v1.0.0** (RECOMMENDATION, 2026-05-05) — the format instrument. Its **Part 1 reconciliation** (three-class vs four-class) carries forward unchanged: the three-class `reduces` the four-class on the hybrid axis and `extends` it across all skill requirements; the schemes operate at complementary levels (skill-requirement design-time vs CI-check operational lifecycle); no irreconcilable conflict. **Not re-derived in this doc.** Its **Part 5 resistant-set diagnostic** (composite / workflow / external-knowledge) is the framework this doc extends; new resistant patterns surfaced at tier-1 are surfaced in §16 below as additions, not supersessions.
- **`swift-institute/Research/centralized-swift-ci-and-spine-gate.md` v1.2.0** (RECOMMENDATION, 2026-05-04) — canonical four-class scheme + γ-roadmap. §3.4.1 (lines 649–662) phased roadmap; §3.4.10 (lines 896–909) graduation models; §3.4.2–§3.4.7 per-rule designs. Inline `→ γ-Nx` annotations in the per-skill tables below cite this document.
- **`/Users/coen/Developer/HANDOFF-classification-extension-tier-1.md`** — branching investigation handoff that dispatched this work. Supervisor ground-rules block honored; verification stamp at §Outcome.

### Empirical state (verified 2026-05-05)

The 13 tier-1 skill files were each read end-to-end by parallel subagents (4 clusters: A, B, C, D — one per agent) using `grep -nE '^### \[' SKILL.md` to enumerate requirement IDs, then per-rule classification. Verified counts:

| Skill | SKILL.md path | lines | last_reviewed | Requirement IDs walked |
|---|---|---|---|---|
| existing-infrastructure | `Skills/existing-infrastructure/SKILL.md` | 1203 | 2026-04-30 | 26 |
| documentation | `Skills/documentation/SKILL.md` | 214 | 2026-04-30 | 61 |
| swift-institute | `Skills/swift-institute/SKILL.md` | 91 | 2026-03-20 | 1 |
| audit | `Skills/audit/SKILL.md` | 961 | 2026-04-30 | 31 |
| benchmark | `Skills/benchmark/SKILL.md` | 362 | 2026-04-30 | 10 |
| swift-package-build | `Skills/swift-package-build/SKILL.md` | 313 | 2026-05-04 | 8 |
| ci-cd-workflows | `Skills/ci-cd-workflows/SKILL.md` | 730 | 2026-05-04 | 29 |
| github-repository | `Skills/github-repository/SKILL.md` | 555 | 2026-04-30 | 32 |
| swift-institute-core | `Skills/swift-institute-core/SKILL.md` | 135 | 2026-04-30 | 0 |
| swift-package | `Skills/swift-package/SKILL.md` | 479 | 2026-04-30 | 10 |
| ecosystem-data-structures | `Skills/ecosystem-data-structures/SKILL.md` | 434 | 2026-03-26 | 11 |
| release-readiness | `Skills/release-readiness/SKILL.md` | 280 | 2026-04-30 | 6 |
| package-export | `Skills/package-export/SKILL.md` | 340 | 2026-03-20 | 11 |
| **Total** | | **6117** | | **236** |

236 walked requirements is ≈4.1× the pilot's 57. Two skills surface as outliers in count: `swift-institute-core` (zero requirement IDs — manifest-only meta-skill) and `swift-institute` (one requirement ID — degenerate single-rule skill). See §15 calibration data.

---

## Question

The pilot's three coupled questions (Q1 reconciliation, Q2 coverage, Q3 rollout readiness) restated at tier-1 scale:

1. **Coverage**: When applied across 13 tier-1 skills (236 requirements), does the three-class taxonomy classify cleanly, or does it surface a resistant set materially larger or differently shaped than the pilot's 22.8%?
2. **γ-roadmap saturation**: How densely do tier-1 mechanical rules map to already-designed γ-roadmap CI checks? (The handoff predicts highest density in `ci-cd-workflows`, `github-repository`, `release-readiness`.)
3. **Rollout-relevance**: Does the tier-1 distribution surface anything that would change the pilot's recommendation to adopt the taxonomy with three clarifications (composite splitting, workflow-vs-outcome, external-knowledge annotation), or does it stress-test the recommendation's robustness?

---

## Analysis

### Part 1 — Carry-forward: pilot reconciliation

The pilot's Part 1 §1.3 verdict (three-class **reduces** four-class on hybrid axis; **extends** four-class across all skill requirements; **complementary levels** — design-time skill-requirement vs operational CI-check lifecycle; **no irreconcilable conflict**) governs unchanged. Tier-1 classification produced no rule whose verification mechanism would refute this reconciliation. The first ask: clause from the supervisor block (irreconcilable taxonomy conflict → escalate) is therefore not triggered.

---

### Part 2 — existing-infrastructure (`Skills/existing-infrastructure/SKILL.md`)

Verified against `SKILL.md` (1203 lines, last_reviewed 2026-04-30). All 26 requirement IDs walked.

#### 2.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[INFRA-100]` | Cardinal.Protocol and Ordinal.Protocol | **semantic** | AI input: judge whether a proposed new operator on a `Tagged<T, Cardinal>` / `Tagged<T, Ordinal>` type duplicates an operation that already lifts from the protocol. Requires understanding "operations as protocol-level concepts." No closed-form predicate. | existing-infrastructure/SKILL.md:38 |
| `[INFRA-101]` | Cardinal Quantities | **hybrid** | Prefilter: regex/AST for forbidden patterns at call sites — `Cardinal(0)`, `count - .one`, `count.rawValue - 1`, `count &-= 1`, bare `UInt`/`Int` parameters typed as quantity. AI input: confirm context is a quantity (not e.g. raw bit pattern); judge whether boundary overload [INFRA-002] applies. | existing-infrastructure/SKILL.md:57 |
| `[INFRA-102]` | Ordinal Positions | **hybrid** | Prefilter: regex for forbidden raw-value reconstructions — `Ordinal(position.rawValue + 1)`, `while slot < end { slot = ... }`, `Int(bitPattern: slot)` at element-access sites. AI input: confirm position semantics (vs offset / count); pick correct policy `.saturating` / `.exact`. | existing-infrastructure/SKILL.md:97 |
| `[INFRA-103]` | Tagged Functors — retag and map | **mechanical** | Predicate: regex/AST for reconstruction shapes — `<TypeName>(<Type>(<expr>.rawValue.rawValue))`, `Bit.Index(Ordinal(...rawValue...))`, `Swift.min(a.rawValue, b.rawValue)`, `__unchecked` constructions of typed Index from rawValue chains. Closed-form replacement available. | existing-infrastructure/SKILL.md:137 |
| `[INFRA-104]` | Affine.Discrete.Ratio — Typed Scaling | **mechanical** | Predicate: regex for forbidden scaling patterns — `Cardinal(<expr>.rawValue &<< 1)`, `pointer + Int(bitPattern: offset)`, raw-`Int` outputs from `(pointer2 - pointer1)`. Replace with `Affine.Discrete.Ratio` operations. | existing-infrastructure/SKILL.md:172 |
| `[INFRA-105]` | Bounded Indices | **hybrid** | Prefilter: AST → for each public method on a static-capacity type, enumerate `Index<T>` parameters that are not `Index<T>.Bounded<N>`. AI input: judge whether the static capacity is provable at the API boundary (true → flag; false → allow). | existing-infrastructure/SKILL.md:208 |
| `[INFRA-106]` | Property<Tag, Base> Pattern | **hybrid** | Prefilter: AST → enumerate hand-rolled accessor structs (single `_backing` pointer + method group); also flag `.View` extensions with `mutating` methods that lack a `_modify` coroutine. AI input: confirm the struct's role is verb-as-property accessor (vs domain type). | existing-infrastructure/SKILL.md:244 |
| `[INFRA-107]` | Sequence Iteration Tags | **hybrid** | Prefilter: regex for raw `while` loops at call sites and `for i in 0..<count` patterns; whitelist iteration-infrastructure-implementation files. AI input: judge whether a higher-level `.forEach` / `.reduce.into` / `.linearize` shape applies for the iteration's intent. | existing-infrastructure/SKILL.md:413 |
| `[INFRA-108]` | Bit Vector Bulk Operations | **mechanical** | Predicate: regex/AST for per-bit `while` loops calling `set`/`clear` at single-bit indices when an enclosing range is available; `_slots[Bit.Index(Ordinal(...rawValue.rawValue))]` patterns. Replace with `.set.range`, `.clear.range`, `.popcount`, `.pop.first()`. | existing-infrastructure/SKILL.md:459 |
| `[INFRA-109]` | Storage Primitives | **mechanical** | Predicate: regex/AST for `withUnsafeMutablePointerToElements { base in let ptr = base + Int(...) }`; manual `ptr.initialize(to:)`, `ptr.move()`, `ptr.deinitialize(count: 1)` at call sites in storage-managing types. Replace with `storage.pointer(at:)` / `.initialize` / `.move` / `.deinitialize`. | existing-infrastructure/SKILL.md:500 |
| `[INFRA-110]` | Static Method Delegation for ~Copyable | **hybrid** | Prefilter: AST → enumerate types with both `~Copyable` and `Copyable` overloads of the same method name; detect `self.method(...)` recursion candidate. AI input: confirm the overload pair forms the recursion-prone shape and that static delegation is the correct factoring. | existing-infrastructure/SKILL.md:538 |
| `[INFRA-001]` | Integration Module Pattern | **mechanical** | Predicate: regex on Package.swift product names — `^.+ Standard Library Integration$`. Tracking: enumerate the 10 named integration modules; verify presence in their parent packages. | existing-infrastructure/SKILL.md:702 |
| `[INFRA-002]` | Cardinal Integration — Counts and Sizes | **mechanical** | Predicate: regex for `Int(bitPattern: count.cardinal)` (chained `.rawValue`-then-`bitPattern`); `Span.init(_unsafeStart:, count:)` calls passing `Int` instead of `Cardinal.Protocol`; allocate-with-bare-`Int` patterns at SDK boundary. Replace with typed-overload boundary call. | existing-infrastructure/SKILL.md:723 |
| `[INFRA-003]` | Ordinal Integration — Positions and Subscripts | **mechanical** | Predicate: regex `(base + Int\(bitPattern: \w+\))\.pointee` and equivalent subscript-by-`Int` patterns where ordinal subscript is available. Replace with `base[slot]`. | existing-infrastructure/SKILL.md:744 |
| `[INFRA-003a]` | Atomic Round-Robin — `Atomic<Ordinal.Protocol>.advance(within:)` | **hybrid** | Prefilter: AST → enumerate `Atomic` whose `Value` is `Ordinal.Protocol`-conforming; flag `wrappingAdd(...).oldValue + % count.rawValue` patterns; flag invented wrapper types (`Cyclic.Counter`, `Round.Robin`). AI input: confirm semantics is round-robin (vs other CAS-loop construct that warrants a named type per the rule's "three-or-more methods" guidance). | existing-infrastructure/SKILL.md:761 |
| `[INFRA-004]` | Affine Integration — Pointer Arithmetic | **mechanical** | Predicate: regex for `pointer + Int(bitPattern:)` pointer-advance patterns and bare-`Int` distance computations; replace with typed `Tagged<Pointee, Ordinal>.Offset` arithmetic. Closed-form. | existing-infrastructure/SKILL.md:818 |
| `[INFRA-005]` | Memory Integration — Raw Pointer Operations | **mechanical** | Predicate: regex for `memory.initialize(as:, repeating:, count:)` calls with `Int` count instead of `Index<T>.Count`; same for `move.initialize`, `bind`, `copy`, `store.bytes`. Replace with typed-overload signature. | existing-infrastructure/SKILL.md:832 |
| `[INFRA-200]` | Operations That Are Intentionally Missing | **mechanical** | Predicate: closed-form regex/AST scan for forbidden operations — `Cardinal - Cardinal`, `count &-= 1`, `index * 2`, `count * count`, `pointer + count`, `Index(rawValue: 5)` as public API, scalar operators on typed quantities, `bounded + .one`. Each pattern has a closed-form replacement listed. | existing-infrastructure/SKILL.md:851 |
| `[INFRA-020]` | Before Writing Int(bitPattern:) | **mechanical** | Predicate: regex `Int\(bitPattern:` triggers; route to integration overload per [INFRA-002/003/004/005]. Decision-tree predicate is itself mechanical (closed branches). See §16 new-resistant: decision-tree wrappers. | existing-infrastructure/SKILL.md:870 |
| `[INFRA-021]` | Before Writing .rawValue | **hybrid** | Prefilter: regex `\.rawValue` outside whitelisted `_unchecked` / boundary-overload sites. AI input: route through the decision tree to the correct typed alternative (`.retag`, `.map`, ratio, typed comparison) — per-context judgment. | existing-infrastructure/SKILL.md:896 |
| `[INFRA-022]` | Before Writing a while Loop | **hybrid** | Prefilter: regex for raw `while` loops outside iteration-infrastructure-implementation files. AI input: route through the decision tree to the matching iteration construct (`.forEach`, `.reduce.into`, `.set.range`, `.linearize`). | existing-infrastructure/SKILL.md:925 |
| `[INFRA-023]` | Before Hand-Rolling an Accessor Struct | **hybrid** | Prefilter: AST → enumerate accessor-shape struct declarations (single `_backing` field, methods only). AI input: route through the decision tree to the right Property variant (Copyable vs ~Copyable, methods vs properties, value-generic count). | existing-infrastructure/SKILL.md:954 |
| `[INFRA-024]` | Before Writing withUnsafe* Closures | **mechanical** | Predicate: regex for `withUnsafe*` closure calls in storage-managing types where `Storage<Element>` accessors apply. Decision tree predicate is closed (`pointer(at:)` / `.initialize` / `.move` / `.deinitialize` / `.copy(range:to:)`). | existing-infrastructure/SKILL.md:992 |
| `[INFRA-025]` | Before Writing count - 1 | **mechanical** | Predicate: regex `count - 1`, `count -= 1`, `count - <int-literal>` triggers. Replace with `.subtract.saturating(.one)` / `.subtract.exact(.one)` / `.subtract.saturating(n)` / `.subtract.exact(n)`. Closed-form route. | existing-infrastructure/SKILL.md:1018 |
| `[INFRA-026]` | Before Conforming to a stdlib Protocol | **hybrid** | Prefilter: AST → enumerate conformances to stdlib protocols (`SerialExecutor`, `RunLoopExecutor`, `SchedulingExecutor`, etc.); shell out to grep of the SDK's `.swiftinterface` for the protocol declaration. AI input: confirm whether the conformance MUST defer to "infrastructure-ready, conformance-deferred" posture vs is genuinely available at build-time. **External:** SDK `.swiftinterface` lookup. | existing-infrastructure/SKILL.md:1041 |
| `[INFRA-050]` | By-New-Type-Proposal Entry Point | **semantic** | AI input: for each proposed new typed value (`Address`, `Length`, `Offset`, `Count`), judge whether the canonical primitive family already provides the semantics. Type-proposal-side judgment with no in-tree predicate. | existing-infrastructure/SKILL.md:1176 |

#### 2.2 existing-infrastructure distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 13 | INFRA-103, INFRA-104, INFRA-108, INFRA-109, INFRA-001, INFRA-002, INFRA-003, INFRA-004, INFRA-005, INFRA-200, INFRA-020, INFRA-024, INFRA-025 |
| hybrid | 11 | INFRA-101, INFRA-102, INFRA-105, INFRA-106, INFRA-107, INFRA-110, INFRA-003a, INFRA-021, INFRA-022, INFRA-023, INFRA-026 |
| semantic | 2 | INFRA-100, INFRA-050 |

Total 26.

---

### Part 3 — documentation (`Skills/documentation/SKILL.md`)

Verified against `SKILL.md` (214 lines, last_reviewed 2026-04-30) — `SKILL.md` indexes the requirement IDs declared in the 7 sibling files (`inline.md`, `catalogue.md`, `topical.md`, `tutorial.md`, `landing.md`, `style.md`, `visual.md`). All 61 requirement IDs walked. File:line cites the indexing line in `SKILL.md`.

#### 3.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[DOC-001]` | Summary line | **hybrid** | Prefilter: AST → for every `public` declaration, verify a `///` summary exists as the first line and fits one rendered line. AI input: judge whether the line describes caller-visible behavior vs implementation internals. | documentation/SKILL.md:115 |
| `[DOC-002]` | Type documentation structure | **hybrid** | Prefilter: section-presence check — summary + blank + (optional spec heading) + (optional `## Example`). AI input: confirm specification-mirroring vs infrastructure-type variant chosen correctly. | documentation/SKILL.md:116 |
| `[DOC-003]` | Method documentation | **mechanical** | Predicate: AST → for every public throwing/parametric/returning method, verify presence of `- Parameter`, `- Returns:`, `- Throws:` doc lines covering each declared element. Concurrency adds executor/cancellation prose check (mechanical at presence). | documentation/SKILL.md:117 |
| `[DOC-004]` | Property documentation | **semantic** | AI input: judge whether each property is "self-evident" (no doc needed) vs "computed with side effects / non-obvious invariants / pattern deviation" (doc required). Trigger is design-semantic. | documentation/SKILL.md:118 |
| `[DOC-005]` | Specification-mirroring documentation | **hybrid** | Prefilter: regex for spec-namespaced types (`RFC_*`, `ISO_*`, `IEEE_*`); verify `## RFC N Section M` heading + `>` blockquote presence. AI input: judge whether the blockquote text is faithful to the specification. **External:** spec text. | documentation/SKILL.md:119 |
| `[DOC-006]` | Subsection enumeration | **mechanical** | Predicate: for spec types whose section has numbered subsections, verify each subsection appears with `[N.](<doc:...>)` link + one-line summary. Closed-form regex on the comment block. | documentation/SKILL.md:120 |
| `[DOC-007]` | Abbreviated subsection syntax | **mechanical** | Predicate: regex for bracketed-summary shape — `> N.-M. [...]`. Format check. | documentation/SKILL.md:121 |
| `[DOC-008]` | Cross-reference formats | **mechanical** | Predicate: regex on doc comments — DocC links use `[text](<doc:Path>)`; backtick auto-links use `` ``Symbol`` ``. Detect mismatched formats. | documentation/SKILL.md:122 |
| `[DOC-009]` | Definition index pattern | **mechanical** | Predicate: regex `_\[<term>\]\(<doc:\.\.\.>\)_` for italic-plus-link definitions. Format check. | documentation/SKILL.md:123 |
| `[DOC-010]` | Explanatory material exclusion | **hybrid** | Prefilter: regex for forbidden patterns in inline `///` — `Research/`, `Experiments/`, "rationale", "decision matrix", multi-paragraph commentary heuristics. AI input: judge "explanatory" vs "specification text or canonical usage." | documentation/SKILL.md:124 |
| `[DOC-020]` | Catalogue location | **mechanical** | Predicate: filesystem — for every module in Package.swift, verify `Sources/{Module Name}/{Module Name}.docc/` exists, OR module is a variant under umbrella-consolidation pattern (verifiable by Package.swift `@_exported public import` shape). | documentation/SKILL.md:131 |
| `[DOC-019a]` | Multi-Target Consolidation Pattern | **hybrid** | Prefilter: AST → detect umbrella + `@_exported public import` shape; verify only umbrella has `.docc/`; verify per-symbol article headings address `<UmbrellaModule>/Symbol`. AI input: confirm the consolidation is appropriate (vs the rare per-variant-archive case the rule's exception calls out). | documentation/SKILL.md:132 |
| `[DOC-021]` | Root page | **mechanical** | Predicate: filesystem + markdown parse — every `.docc/` carries `{Module}.md` with `# ``{Module_Identifier}`` ` heading + `@Metadata` + `@DisplayName` + `@TitleHeading` + `## Topics`. | documentation/SKILL.md:133 |
| `[DOC-022]` | Article pages — Navigation Level | **mechanical** | Predicate: every article page contains `# ``{Module}/{Symbol}`` ` heading + `@Metadata` block with `@DisplayName` + `@TitleHeading`. Schema-derivable. | documentation/SKILL.md:134 |
| `[DOC-023]` | Article pages — Substantive Level (Per-Symbol) | **hybrid** | Prefilter: section-heading order check (`## Overview`, `## Specification`, `## Example`, `## Rationale`, `## Research`, `## Experiments`, `## Topics`, `## See Also`). AI input: verify section content matches its role; verify mirrored sections (Specification, Example) match inline docs semantically. | documentation/SKILL.md:135 |
| `[DOC-024]` | Subsection pages | **mechanical** | Predicate: for spec types with documented subsections, verify each has its own `.docc` article with `# ``{Module}/{Parent}/{Subsection}`` ` heading + `@Metadata`. | documentation/SKILL.md:136 |
| `[DOC-025]` | Topics organization | **hybrid** | Prefilter: parse `## Topics`; check headings are NOT alphabetical. AI input: judge whether the chosen domain-grouping (e.g., RFC sections) reflects the specification's own structure. | documentation/SKILL.md:137 |
| `[DOC-026]` | Flat catalogue layout | **mechanical** | Predicate: filesystem — for every `.docc/`, enumerate subdirectories; verify only `Resources/` is present. | documentation/SKILL.md:138 |
| `[DOC-027]` | Content layering principle | **semantic** | AI input: cross-layer audit — for each fact, identify its canonical home (inline / per-symbol / topical / tutorial); detect duplication that is not a deliberate mirror. Duplication-vs-mirror is semantic. | documentation/SKILL.md:139 |
| `[DOC-028]` | Research references in .docc articles | **mechanical** | Predicate: filesystem + markdown — `## Research` MAY appear on landing page; MUST NOT appear in per-symbol or topical articles; MUST NOT appear in inline `///`. Each link MUST include title + status. Closed-form. | documentation/SKILL.md:140 |
| `[DOC-029]` | Experiment references in .docc articles | **mechanical** | Predicate: filesystem + markdown — `## Experiments` MAY appear on landing page; MUST NOT appear in per-symbol or topical articles; MUST NOT appear in inline `///`. Each link MUST include name + status. Closed-form. | documentation/SKILL.md:141 |
| `[DOC-100]` | Layering principle — inline and .docc carry distinct weight | **semantic** | AI input: detect the degenerate `/// See \`<ArticleName>\` for details.`-only inline pattern; judge whether inline doc carries minimum actionable content. The "actionable content" threshold is qualitative. | documentation/SKILL.md:142 |
| `[DOC-101]` | Consumer/contributor boundary in DocC | **mechanical** | Predicate: regex on per-symbol and topical articles — forbidden tokens `## Research`, `## Experiments`, `Status: DECISION`, See-Also links into `Research/` or `Experiments/`. | documentation/SKILL.md:143 |
| `[DOC-102]` | Preview-and-convert parity in DocC tooling guidance | **mechanical** | Predicate: skill-text self-audit — for every cited tooling artifact, verify the file exists at the cited path OR the citation uses aspirational tense + tracking-handoff link. Filesystem cross-reference check. | documentation/SKILL.md:144 |
| `[DOC-060]` | When to create a topical article | **semantic** | AI input: for each candidate concept/pattern/task, judge whether it spans multiple symbols and meets one of the trigger criteria (decision matrix, recipe, package-spanning concept, task-oriented guide, cross-package design context). | documentation/SKILL.md:148 |
| `[DOC-061]` | Topical article structure | **mechanical** | Predicate: parse topical articles (kebab-case filenames, natural-language `# Title`, `@Metadata` block, `## See Also`); verify shape against the schema. | documentation/SKILL.md:149 |
| `[DOC-062]` | Topical article location | **semantic** | AI input: judge which catalog (umbrella / module-specific / variant-target) is the right home for a given topical article based on audience proximity. | documentation/SKILL.md:150 |
| `[DOC-063]` | Topical articles in Topics | **mechanical** | Predicate: parse landing/root page Topics section; verify topical articles appear in named groups distinct from per-symbol type groups (`### Getting Started`, `### Patterns`, `### Concepts`, `### Types`). | documentation/SKILL.md:151 |
| `[DOC-064]` | Per-symbol vs topical article decision | **semantic** | AI input: for each piece of content, route to per-symbol `## Rationale` vs topical article using the decision matrix (primary referent, cross-references direction, mental starting point, natural title, duplication risk). | documentation/SKILL.md:152 |
| `[DOC-070]` | Tutorial table of contents (required) | **mechanical** | Predicate: filesystem — for every `.docc/` containing `*.tutorial` files with `@Tutorial`, verify a `Tutorials.tutorial` (or equivalent `@Tutorials` TOC file) exists. | documentation/SKILL.md:156 |
| `[DOC-071]` | Tutorial code layout (catalog-resident) | **mechanical** | Predicate: filesystem + Package.swift — verify `@Code` directives reference files under `.docc/Resources/`; verify NO Package.swift target named `* Tutorial Host` exists. | documentation/SKILL.md:157 |
| `[DOC-072]` | Tutorial structure | **mechanical** | Predicate: parse `.tutorial` files — verify `@Tutorial(time:)` outer + `@Intro` + `@Section` + `@ContentAndMedia` + `@Steps` + `@Step` + `@Code` directive hierarchy; verify PascalCase `.tutorial` filenames + kebab-case `step-NN-*.swift` names. | documentation/SKILL.md:158 |
| `[DOC-073]` | Tutorial code verification | **hybrid** | Prefilter: detect packages that ship tutorials in long-lived releases; check for evidence of one of the three mechanisms (test target mirroring step code / CI step compiling `Resources/*.swift` / documented manual policy). AI input: judge whether the chosen mechanism is appropriate for the package's release cadence. | documentation/SKILL.md:159 |
| `[DOC-074]` | Tutorial scope | **semantic** | AI input: judge whether a tutorial is in the 5–15-minute focused-scope range vs over-scoped. Scope-fit is qualitative. | documentation/SKILL.md:160 |
| `[DOC-080]` | Umbrella catalog as landing page | **mechanical** | Predicate: filesystem + markdown — verify the umbrella catalog's root page contains `## Overview`, optional `@Row`/`@Column`, `## Topics` with the role-grouped sections from [DOC-084]; non-umbrella roots remain at [DOC-021] baseline. | documentation/SKILL.md:164 |
| `[DOC-081]` | @CallToAction | **mechanical** | Predicate: parse landing-page `@Metadata`; verify `@CallToAction(url:..., purpose: link\|download, label:...)` is present. | documentation/SKILL.md:165 |
| `[DOC-082]` | @Row and @Column layout | **mechanical** | Predicate: parse landing-page markdown — verify `@Row { @Column { ... } }` blocks contain 2–4 columns with H3 heading + one sentence + one link each (no dense content). | documentation/SKILL.md:166 |
| `[DOC-083]` | @TabNavigator | **semantic** | AI input: judge whether the package serves multiple distinct audiences (app-developer vs library-author etc.) that justify `@TabNavigator` use vs single landing path. Audience bifurcation is qualitative. | documentation/SKILL.md:167 |
| `[DOC-084]` | Topics grouping on landing pages | **mechanical** | Predicate: parse landing-page Topics — verify role-ordered groups (Tutorials → Getting Started → Patterns → Concepts → Core Types → Related Modules). Empty groups absent. | documentation/SKILL.md:168 |
| `[DOC-090]` | @PageColor | **hybrid** | Prefilter: parse `@Metadata` for `@PageColor`; verify the color is from the named-color set; verify all root pages in a package use the same color (no per-symbol overrides). AI input: confirm ecosystem-palette alignment when an ecosystem palette is documented. | documentation/SKILL.md:172 |
| `[DOC-091]` | @PageImage | **mechanical** | Predicate: parse `@Metadata` for `@PageImage`; verify the source filename exists in `.docc/Resources/`; verify image extension/size constraints (PNG/JPEG <200 KB, or SVG). | documentation/SKILL.md:173 |
| `[DOC-092]` | @Available | **mechanical** | Predicate: parse `@Metadata` for `@Available`; verify shape `(Platform, introduced: "version")`. Format check. | documentation/SKILL.md:174 |
| `[DOC-093]` | Visual consistency across catalogues | **mechanical** | Predicate: cross-catalogue diff — verify all `.docc/` root pages in a multi-module package use the same `@PageColor`/`@PageImage`/landing layout (variants MAY omit but MUST NOT differ). | documentation/SKILL.md:175 |
| `[DOC-030]` | External links | **mechanical** | Predicate: for every spec-modeling root page, verify presence of an authoritative external link (e.g., `https://www.rfc-editor.org/rfc/...`, `https://www.iso.org/...`). | documentation/SKILL.md:179 |
| `[DOC-031]` | Cross-module references | **mechanical** | Predicate: regex for cross-spec references — bare numbers like "Section 3.3" outside an RFC/ISO context flagged; full identifier "RFC 3986 Section 3.3" required. | documentation/SKILL.md:180 |
| `[DOC-032]` | Range reference pattern | **mechanical** | Predicate: regex `\[Section [0-9.]+\]\(<doc:[^>]+>\) through \[Section [0-9.]+\]\(<doc:[^>]+>\), inclusive` for range-of-sections references. Format check. | documentation/SKILL.md:181 |
| `[DOC-033]` | Blockquote convention | **mechanical** | Predicate: regex on doc comments and `.docc` articles — verify spec text is wrapped in `>` blockquote. Detect un-quoted spec text inside spec-mirroring types. | documentation/SKILL.md:182 |
| `[DOC-040]` | Documentation tiers | **semantic** | AI input: classify each documented type into Tier 1–5 by maturity; verify the tier matches the documentation's actual content fields. The Tier table is mechanical at content shape but the tier assignment is design-semantic. | documentation/SKILL.md:184 |
| `[DOC-041]` | Section heading conventions | **hybrid** | Prefilter: regex for spec-namespaced types — verify the `##` heading matches the domain (`## RFC N Section M` for RFCs, `## ISO N Section M` for ISO, `## Specification` general). AI input: confirm domain selection (RFC vs ISO vs IETF draft) is correct based on the spec authority. **External:** spec authority. | documentation/SKILL.md:185 |
| `[DOC-042]` | Documentation currency | **hybrid** | Prefilter: detect mismatched `@DisplayName` vs current spec title (requires fetching current spec metadata). AI input: confirm whether the doc text reflects current spec (vs superseded spec). **External:** current spec text. | documentation/SKILL.md:186 |
| `[DOC-043]` | Comment purpose | **semantic** | AI input: for each `//` comment, judge whether it explains "why" (correct) vs "what" (incorrect). | documentation/SKILL.md:187 |
| `[DOC-044]` | Anticipatory documentation | **semantic** | AI input: identify code where future readers might question the choice (language limitation, deferred design, intentional deviation, counter-intuitive pattern); verify the comment anticipates the question. | documentation/SKILL.md:188 |
| `[DOC-045]` | Workaround documentation template | **mechanical** | Predicate: regex for `// WORKAROUND:` comments; verify presence of `WHY:`, `WHEN TO REMOVE:`, `TRACKING:` in the same comment block. Format check on the four-field template. | documentation/SKILL.md:189 |
| `[DOC-046]` | Deviation documentation template | **hybrid** | Prefilter: detect comment shapes `Unlike <X> which <does Y> because <reason>, <this type> <does Z> ...`. AI input: judge whether the comment names a real established pattern in the codebase and whether the deviation rationale is genuine. | documentation/SKILL.md:190 |
| `[DOC-047]` | Learning path preservation | **semantic** | AI input: judge whether a documented pattern preserves the learning path (failed alternatives explained) vs only ships the conclusion. | documentation/SKILL.md:191 |
| `[DOC-048]` | Compromise documentation | **hybrid** | Prefilter: detect workaround-flavored prose (e.g., `Reference.Box`, "implicitly require Copyable", "Migration Path") in `.docc` articles. AI input: verify the three-part shape (why workaround / ideal solution / when removable). | documentation/SKILL.md:192 |
| `[DOC-049]` | Escape hatch counter-marketing | **semantic** | AI input: identify documented escape-hatch types (`*.Unchecked`, `*.Unsafe`, `__unchecked` initializers); verify the documentation actively discourages use and honestly states limitations. | documentation/SKILL.md:193 |
| `[DOC-050]` | Code example quality | **hybrid** | Prefilter: parse code blocks in doc comments and `.docc` articles — verify `import` statements present, code-block language tag set, identifiers not in the forbidden-trivial set (`Foo`, `Bar`, `x`, `y`). AI input: judge whether identifiers are domain-meaningful. | documentation/SKILL.md:194 |
| `[DOC-051]` | Automated verification of derived information | **mechanical** | Predicate: for every documented derived value (tier, dep count, package inventory, module name), verify a CI verification step exists in the package's workflow. Filesystem + workflow grep. | documentation/SKILL.md:195 |
| `[DOC-052]` | Semantic labels vs computed values | **semantic** | AI input: identify documented labels (tier names, category descriptions); judge whether the prose treats them as facts (correct for computed values) vs prescriptive constraints (incorrect for labels). | documentation/SKILL.md:196 |
| `[DOC-053]` | Document versioning | **hybrid** | Prefilter: parse normative-document headers for `version:`; compare against git history of the document's content. AI input: classify each change as typo/clarification/structural — judgment-required for the patch/minor/major routing. | documentation/SKILL.md:197 |

#### 3.2 documentation distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 32 | DOC-003, DOC-006, DOC-007, DOC-008, DOC-009, DOC-020, DOC-021, DOC-022, DOC-024, DOC-026, DOC-028, DOC-029, DOC-101, DOC-102, DOC-061, DOC-063, DOC-070, DOC-071, DOC-072, DOC-080, DOC-081, DOC-082, DOC-084, DOC-091, DOC-092, DOC-093, DOC-030, DOC-031, DOC-032, DOC-033, DOC-045, DOC-051 |
| hybrid | 15 | DOC-001, DOC-002, DOC-005, DOC-010, DOC-019a, DOC-023, DOC-025, DOC-073, DOC-090, DOC-041, DOC-042, DOC-046, DOC-048, DOC-050, DOC-053 |
| semantic | 14 | DOC-004, DOC-027, DOC-100, DOC-060, DOC-062, DOC-064, DOC-074, DOC-083, DOC-040, DOC-043, DOC-044, DOC-047, DOC-049, DOC-052 |

Total 61.

---

### Part 4 — swift-institute (`Skills/swift-institute/SKILL.md`)

Verified against `SKILL.md` (91 lines, last_reviewed 2026-03-20). The single declared requirement ID walked. (The SKILL.md's "Semantic Dependencies" table at lines 73–77 references `[SEM-DEP-006]`, `[SEM-DEP-008]`, `[SEM-DEP-009]` but these are declared in `Documentation.docc/Semantic Dependencies.md` per line 79's pointer — they are not declared `### [SEM-DEP-*]` rules within this SKILL.md and are out of scope per the assignment's scope rule.)

#### 4.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[ARCH-LAYER-001]` | Dependency Direction | **mechanical** | Predicate: parse Package.swift for every package; resolve each dep to its declared layer (Primitives=1 / Standards=2 / Foundations=3 / Components=4 / Applications=5); verify `layer[dep] < layer[self]` for every edge. Same engine as `[PRIM-ARCH-002]` from the pilot but ecosystem-wide. → γ-1c-adjacent (a γ-1-class deterministic extension natural; not yet on the γ-roadmap as a distinct check) | swift-institute/SKILL.md:41 |

#### 4.2 swift-institute distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 1 | ARCH-LAYER-001 |
| hybrid | 0 | — |
| semantic | 0 | — |

Total 1. (swift-institute is a thin top-level architectural skill; the bulk of architectural detail lives in `Documentation.docc/` and in child skills like `code-surface`, `memory-safety`, `implementation`, `primitives` — covered by the pilot and Cluster A's other two skills.)

---

### Part 5 — audit (`Skills/audit/SKILL.md`)

Verified against `SKILL.md` (961 lines, last_reviewed 2026-04-30). All 31 requirement IDs walked.

#### 5.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[AUDIT-001]` | Single Output File | **mechanical** | Predicate: filesystem scan — for each `Audits/`, verify only `audit.md` (and `_index.json`) at that scope; no other audit-output filename allowed. | audit/SKILL.md:58 |
| `[AUDIT-002]` | Location Triage | **mechanical** | Predicate: filesystem + git ls-files. (a) verify no `swift-{primitives,standards,foundations}/Audits/` containers exist; (b) verify no audit artifact is git-tracked outside `swift-institute/Audits/`; (c) `.gitignore` regenerated by `sync-gitignore.sh` matches canonical. Composite of forbidden-path + git-tracking + canonical-gitignore checks. | audit/SKILL.md:81 |
| `[AUDIT-003]` | Section-Per-Skill Structure | **mechanical** | Predicate: markdown AST parse on each `audit.md`. For each `## ` section, verify pattern `## {Skill Name} — YYYY-MM-DD`; verify presence of `### Scope`, `### Findings`, `### Summary` subsections. | audit/SKILL.md:124 |
| `[AUDIT-004]` | Findings Table Format | **mechanical** | Predicate: markdown table parse — verify each Findings table has columns `# \| Severity \| Rule \| Location \| Finding \| Status`; verify Severity ∈ {CRITICAL, HIGH, MEDIUM, LOW}; verify Status matches one of {OPEN, RESOLVED {date}, DEFERRED — ..., FALSE_POSITIVE — ..., PREMISE-STALE — ...}. Closed-form schema. | audit/SKILL.md:158 |
| `[AUDIT-005]` | Update In Place | **hybrid** | Prefilter: git log on `audit.md` — verify re-audit landed as section replacement (single-section diff), not append. AI input: judge whether DEFERRED findings still apply at re-audit time vs should be dropped. | audit/SKILL.md:187 |
| `[AUDIT-006]` | Skill Loading | **semantic** | AI input: judge whether the auditor loaded the right skills for the package's layer (baseline = code-surface + implementation + modularization; conditional adds for `~Copyable`, platform conditionals, test files, L1 status). | audit/SKILL.md:205 |
| `[AUDIT-007]` | No Version Files | **mechanical** | Predicate: regex on filenames in `Audits/` — forbid suffixes `-v\d+`, `-deep`, `-delta`. Closed-form. | audit/SKILL.md:238 |
| `[AUDIT-008]` | No Prompt Files | **mechanical** | Predicate: filesystem scan — forbid any `Research/prompts/*audit*.md` path. | audit/SKILL.md:255 |
| `[AUDIT-009]` | Index Entry | **mechanical** | Predicate: JSON schema check on each `Audits/_index.json` — for each `audit.md` present, verify entry has `file/scope/date/status`; status ∈ {ACTIVE, CLEAN, STALE}. | audit/SKILL.md:270 |
| `[AUDIT-010]` | Staleness | **mechanical** | Predicate: shell — for each section's date, run `git log --since=...` on `Sources/`; if output non-empty AND date >60 days old, mark STALE. | audit/SKILL.md:298 |
| `[AUDIT-011]` | Scope Boundary | **semantic** | AI input: judge whether the work product is a findings table against requirement IDs (audit) vs an inventory/survey/analysis without rule citations (Discovery research per [RES-012]). | audit/SKILL.md:316 |
| `[AUDIT-012]` | File Scoping | **mechanical** | Predicate: for each finding's Location field, verify the file path is under `Sources/` (non-testing skills) or under `Tests/` (testing skill). | audit/SKILL.md:335 |
| `[AUDIT-013]` | Multi-Skill Output | **mechanical** | Predicate: markdown AST — for `/audit regarding /X /Y`, verify presence of separate `## X — DATE` and `## Y — DATE` sections, each with full Scope/Findings/Summary subsections. | audit/SKILL.md:351 |
| `[AUDIT-014]` | Broad-Then-Narrow Routing | **hybrid** | Prefilter: detect ecosystem-wide audit by location (`swift-institute/Audits/{slug}.md`) and triage-table presence (regex `\| Package \| Findings \| Worst Severity \|`). AI input: judge whether the synthesis covers systemic patterns appropriate to the broad scope vs is per-package detail mis-located. | audit/SKILL.md:380 |
| `[AUDIT-015]` | Prior Findings Review | **hybrid** | Prefilter: filesystem scan for old-style `*-audit*.md` files in target scope's `Research/` and `Audits/`. AI input: extract substantive findings from each old file, judge which still apply, decide whether to delete-without-extraction (older versions) or extract+append-as-Legacy. | audit/SKILL.md:407 |
| `[AUDIT-016]` | Wrong-Scope File Discovery | **mechanical** | Predicate: shell — `find {parent-scope}/Research {parent-scope}/Audits swift-institute/Research swift-institute/Audits -name '*{package-name}*audit*.md'`. Three-step path scan; closed-form. | audit/SKILL.md:446 |
| `[AUDIT-017]` | Parking Destination for Deferred Investigations | **semantic** | AI input: judge whether a finding's DEFERRED reason is genuine (defect identified, fix requires out-of-session authority/decision) vs misuse (no investigation pointer, deflection from fix-now responsibility). | audit/SKILL.md:468 |
| `[AUDIT-018]` | Receipts-Model Integrity Check | **semantic** | AI input: for each receipt link in scope, open the target and judge whether it actually demonstrates the linking paragraph's claim. Claim-to-evidence semantic match. **External:** receipt fetch (in-tree or remote). | audit/SKILL.md:497 |
| `[AUDIT-019]` | Skill-vs-Skill Cluster Consistency Mode | **hybrid** | Prefilter: build cross-reference universe per [AUDIT-028]'s multi-form scan; flag broken/orphan citations. AI input: judge terminology collisions, composition gaps, ID divergence between research and shipped skill, ghost-reference vs sub-label-citation. | audit/SKILL.md:525 |
| `[AUDIT-020]` | Audit-vs-Remediation Separation | **hybrid** | Prefilter: tracker-table schema check (Priority/Status/Commit-SHA/Verification columns); per-commit citation-of-finding-ID regex on commit messages; scope-budget shell check (`git diff --stat` per finding limited to ~3 files outside target). AI input: judge whether commits respect the one-commit-per-finding rhythm. | audit/SKILL.md:565 |
| `[AUDIT-021]` | Cross-Type Bridging Flag in Finding Classification | **semantic** | AI input: for each "Mechanical" effort-class finding, judge whether source/target types are isomorphic or whether a catch-and-map / error-rewrap bridge is needed. | audit/SKILL.md:592 |
| `[AUDIT-022]` | Estimate-Calibration on First-Finding Overage | **hybrid** | Prefilter: parse tracker estimates vs actuals; flag categories where first finding's actual ≥1.5× estimate. AI input: judge whether re-scoping was performed for remaining findings in the flagged category. | audit/SKILL.md:610 |
| `[AUDIT-023]` | Compile-Verify Recommended Fix Before It Lands | **mechanical** | Predicate: for each finding with a recommendation field, verify the recommendation was author-staged at cited location and `swift build` (and `--build-tests` if test-visible) passed. Build-result is binary; CI-observable on a verification branch. → γ-3-adjacent | audit/SKILL.md:629 |
| `[AUDIT-024]` | Deflection-via-META Anti-Pattern | **semantic** | AI input: for each META observation, judge whether the cited code violates an existing requirement ID's spirit; if yes, the META was a deflection and a P-series finding row was required. | audit/SKILL.md:648 |
| `[AUDIT-025]` | PREMISE-STALE Status Code | **hybrid** | Prefilter: detect findings with Status `PREMISE-STALE — ...`; verify cited audit-write evidence + current evidence + mechanism note are present. AI input: judge whether the original observation was correct at audit-write time (not FALSE_POSITIVE) and whether the premise-shift mechanism is well-formed. | audit/SKILL.md:692 |
| `[AUDIT-026]` | Substantive Canary Gate Substitution | **semantic** | AI input: judge whether all three conditions (structural-claim coverage, orthogonality of blocker, discrete-finding logging) hold. Each requires multi-cycle context. | audit/SKILL.md:738 |
| `[AUDIT-027]` | Shipping HOLD Evidence Bar | **hybrid** | Prefilter: detect findings with severity HIGH/CRITICAL + recommendation HOLD; verify presence of in-package release-mode test exercising the production shape. AI input: judge whether the in-package test actually exercises the production shape (vs synthetic narrowing). → γ-3-adjacent for the build-gate sub-check | audit/SKILL.md:784 |
| `[AUDIT-028]` | Ghost-Reference Detection — Notation-Variant Coverage | **mechanical** | Predicate: shell — multi-form grep covering (a) em-dash ranges `\[[A-Z]+-[0-9]+(–[0-9]+)?\]`; (b) `^#{2,3} \[ID\]` heading universe; (c) sub-label citations against rule bodies. Citation universe minus heading universe = ghost candidates. Closed-form. | audit/SKILL.md:822 |
| `[AUDIT-029]` | Empirical Census Before Options Matrix | **hybrid** | Prefilter: detect Research Doc with Options Matrix section; verify presence of "Empirical Census" preceding the matrix AND that the census is a per-target row enumeration over the rule's intended scope. AI input: judge whether the census actually covers the rule's intended scope. | audit/SKILL.md:866 |
| `[AUDIT-030]` | Real-Time Per-Package audit.md Row-Text Updates | **mechanical** | Predicate: git history check — for each commit landing a source fix that resolves a finding, verify the same commit (or same dispatch unit) updates the `audit.md` row's Status from OPEN to `RESOLVED {date} (commit {sha}) — ...`. | audit/SKILL.md:891 |
| `[AUDIT-031]` | Shadow-Elimination FALSE_POSITIVE Rule | **semantic** | AI input: for each finding marked FALSE_POSITIVE — eliminated by upstream, judge whether the planned upstream fix actually eliminates the inheritance/alias/namespace pattern (no consumer sees it post-upstream) vs adds a delegate (still OPEN). Decision requires reading the upstream patch and projecting consumer visibility. **External:** upstream patch fetch. | audit/SKILL.md:922 |

#### 5.2 audit distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 14 | AUDIT-001, AUDIT-002, AUDIT-003, AUDIT-004, AUDIT-007, AUDIT-008, AUDIT-009, AUDIT-010, AUDIT-012, AUDIT-013, AUDIT-016, AUDIT-023, AUDIT-028, AUDIT-030 |
| hybrid | 9 | AUDIT-005, AUDIT-014, AUDIT-015, AUDIT-019, AUDIT-020, AUDIT-022, AUDIT-025, AUDIT-027, AUDIT-029 |
| semantic | 8 | AUDIT-006, AUDIT-011, AUDIT-017, AUDIT-018, AUDIT-021, AUDIT-024, AUDIT-026, AUDIT-031 |

Total 31.

---

### Part 6 — benchmark (`Skills/benchmark/SKILL.md`)

Verified against `SKILL.md` (362 lines, last_reviewed 2026-04-30). All 10 requirement IDs walked.

#### 6.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[BENCH-001]` | Same-Package vs Nested Package Decision Tree | **mechanical** | Predicate: parse Package.swift — for each package, derive layer (primitives = nested `Tests/Package.swift`; foundations/standards = same-package `.testTarget`); verify benchmark target placement matches layer rule. Closed-form layer-to-placement table. | benchmark/SKILL.md:30 |
| `[BENCH-002]` | .build Cleanup Requirement | **semantic** | AI input: judge whether benchmark runs were preceded by `rm -rf .build`. Workflow rule with no in-tree artifact — CI cannot observe whether the developer ran the cleanup; only the resulting numbers indicate freshness. | benchmark/SKILL.md:74 |
| `[BENCH-003]` | .timed() Trait Usage | **mechanical** | Predicate: SwiftSyntax AST query — find all `@Test`-annotated functions in `*Performance*` or `*Benchmark*` suites; verify each has a `.timed(...)` trait in the attribute list. | benchmark/SKILL.md:96 |
| `[BENCH-004]` | Performance Suite Serialization | **mechanical** | Predicate: SwiftSyntax AST — for each `@Suite` containing performance/benchmark `@Test`s, verify `.serialized` trait present (or `#Tests` macro that injects it). | benchmark/SKILL.md:139 |
| `[BENCH-005]` | Comparison Benchmark Pattern | **hybrid** | Prefilter: detect side-by-side benchmark target naming pattern (`{Module} IO Benchmarks` + `{Module} NIO Benchmarks`); compare test-name lists for symmetric coverage. AI input: judge whether workloads (data sizes, operation shapes) are genuinely identical between targets. | benchmark/SKILL.md:176 |
| `[BENCH-006]` | Benchmark Result Storage | **mechanical** | Predicate: filesystem + `.gitignore` check — verify `.benchmarks/` directory (when present) is gitignored. | benchmark/SKILL.md:213 |
| `[BENCH-007]` | Standardized Benchmark Fixtures | **hybrid** | Prefilter: regex/AST — for each I/O benchmark target, detect `IO.Benchmark.Fixture()` import + usage. AI input: judge whether the benchmark is genuinely "I/O" (warranting the fixture) vs an unrelated workload. | benchmark/SKILL.md:230 |
| `[BENCH-008]` | Build and Test Commands | **mechanical** | Predicate: outcome rule — given the package's layer and benchmark placement (per [BENCH-001]), the documented invocation (cd path + `rm -rf .build` + `swift test --filter Performance`) is the canonical run command. → γ-3-adjacent | benchmark/SKILL.md:259 |
| `[BENCH-009]` | Manual Warmup When .timed() Unavailable | **mechanical** | Predicate: AST — for each performance test in a target NOT depending on swift-testing, verify the function body contains an explicit warmup loop (a `for _ in 0..<N { ... }` block preceding the measured loop). | benchmark/SKILL.md:288 |
| `[BENCH-010]` | Deferral Permitted for Tier 0 Surface with No Performance Claims | **semantic** | AI input: for a Tier 0 primitives package without a benchmark target, judge whether (a) no public performance claims exist (README/blog/DocC/external comms) AND (b) the API's primary operation's value proposition is not performance. Both clauses are semantic. | benchmark/SKILL.md:319 |

#### 6.2 benchmark distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 6 | BENCH-001, BENCH-003, BENCH-004, BENCH-006, BENCH-008, BENCH-009 |
| hybrid | 2 | BENCH-005, BENCH-007 |
| semantic | 2 | BENCH-002, BENCH-010 |

Total 10.

---

### Part 7 — swift-package-build (`Skills/swift-package-build/SKILL.md`)

Verified against `SKILL.md` (313 lines, last_reviewed 2026-05-04). All 8 requirement IDs walked. ID prefix is `[PKG-BUILD-*]`.

#### 7.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[PKG-BUILD-001]` | Use `TOOLCHAINS` Env Var, Not `xcrun --toolchain`, for SwiftPM Nightly Builds | **mechanical** | Predicate: shell-script lint + CI-config grep — for any nightly-Swift build invocation, forbid `xcrun --toolchain '...'\s+swift build`; require `TOOLCHAINS=<bundle-id>\s+swift build`. → γ-3/γ-3b-adjacent (toolchain-fidelity gate) | swift-package-build/SKILL.md:41 |
| `[PKG-BUILD-002]` | Look Up the Bundle Identifier via `defaults read` | **mechanical** | Predicate: shell — for each `TOOLCHAINS=` invocation in scripts/CI, verify the env value matches `defaults read .../{toolchain}.xctoolchain/Info CFBundleIdentifier`. Bundle-id format check + Info.plist lookup. | swift-package-build/SKILL.md:77 |
| `[PKG-BUILD-003]` | When `.swiftinterface` and Build Result Disagree, Suspect Build-Config First | **semantic** | AI input: workflow/triage discipline — when build diagnostic contradicts independent `.swiftinterface` inspection, judge whether the responder ran the documented triage order (toolchain version → SDK resolution → upstream check) before concluding the upstream feature is missing. | swift-package-build/SKILL.md:111 |
| `[PKG-BUILD-004]` | Default to Xcode Default Toolchain When Not Targeting Nightly Features | **hybrid** | Prefilter: scripts/CI grep for `TOOLCHAINS=` env-var presence; flag invocations using nightly. AI input: judge whether the use case warrants nightly (verification spike against unlanded SE / `#if swift(>=6.4)` branch / explicit nightly-only build) vs is routine work that should use Xcode default. | swift-package-build/SKILL.md:137 |
| `[PKG-BUILD-005]` | Linux Builds Use the Official `swift:<version>` Docker Image | **mechanical** | Predicate: CI-config grep — Linux build steps use image `swift:6.3` (canonical) with `-v $(pwd):/workspace -w /workspace` mount and `swift test -c release`. → γ-3b-adjacent (stable-image counterpart to static-Linux musl fidelity laboratory) | swift-package-build/SKILL.md:156 |
| `[PKG-BUILD-006]` | Linux Nightly Builds Use `swiftlang/swift:nightly-main-jammy` | **mechanical** | Predicate: CI-config grep — for nightly Linux jobs, image must be `swiftlang/swift:nightly-main-jammy` (NOT `swift:nightly-*` from Apple's published image). → γ-3-adjacent (nightly-toolchain fidelity laboratory) | swift-package-build/SKILL.md:190 |
| `[PKG-BUILD-007]` | Embedded Swift Source-Guard Pattern: `#if !hasFeature(Embedded)` | **mechanical** | Predicate: SwiftSyntax + grep — for each Foundation-free primitive's Codable/Mirror/CustomReflectable/etc. surface, verify wrapper `#if !hasFeature(Embedded)` block. Closed-list of forbidden-without-guard surfaces. → γ-3-adjacent (embedded-build fidelity gate, paired with [PRIM-FOUND-002]) | swift-package-build/SKILL.md:224 |
| `[PKG-BUILD-008]` | Embedded Build-Mode Invocation (Verified on Swift 6.4-dev) | **mechanical** | Predicate: shell-script + CI-config check — embedded-mode build uses `TOOLCHAINS=<6.4-dev-id> swift build -Xswiftc -enable-experimental-feature -Xswiftc Embedded`; for cross-compilation, also `-Xswiftc -target -Xswiftc <triple>`. → γ-3 (Wasm) / γ-3b (static-linux) — embedded-target laboratory shape | swift-package-build/SKILL.md:263 |

#### 7.2 swift-package-build distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 6 | PKG-BUILD-001, PKG-BUILD-002, PKG-BUILD-005, PKG-BUILD-006, PKG-BUILD-007, PKG-BUILD-008 |
| hybrid | 1 | PKG-BUILD-004 |
| semantic | 1 | PKG-BUILD-003 |

Total 8.

---

### Part 8 — ci-cd-workflows (`Skills/ci-cd-workflows/SKILL.md`)

Verified against `SKILL.md` (730 lines, last_reviewed 2026-05-04). All 29 requirement IDs walked. **Most γ-saturated skill in the tier-1 set** — every mechanical rule below maps to a designed γ check.

#### 8.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[CI-001]` | Three-Tier Workflow Chain | **mechanical** | Predicate: YAML AST → for each per-package `ci.yml`, walk `jobs.*.uses:` chain and assert depth ≤ 2 hops with names matching `<layer>/.github/.github/workflows/swift-ci.yml` (Tier 2) and `swift-institute/.github/.github/workflows/swift-ci.yml` (Tier 1). | ci-cd-workflows/SKILL.md:36 |
| `[CI-002]` | Universal Reusable Owns Matrix + Ecosystem-Wide Quality Gates | **mechanical** | Predicate: YAML AST on `swift-institute/.github/.github/workflows/swift-ci.yml`. Forbid `with.enable-<layer>-check`, forbid `embedded` job name, forbid `foundation-integration` job name. Require `format` + `lint` job presence. → γ-2 (YAML lint family) | ci-cd-workflows/SKILL.md:59 |
| `[CI-003]` | Layer-Specific Verifications Live in Layer Wrappers | **mechanical** | Predicate: YAML AST → if a verification job (e.g. `embedded`) is present in universal reusable, fail; if present in `<layer>/.github/.github/workflows/swift-ci.yml` alongside a `uses:` of universal, pass. | ci-cd-workflows/SKILL.md:80 |
| `[CI-004]` | Layer Wrappers Are Architectural Commitments | **semantic** | AI input: judge whether an existing `<layer>/.github/.github/workflows/swift-ci.yml` carries ≥1 layer-wide invariant beyond `uses: universal` (vs being a prophylactic re-export). | ci-cd-workflows/SKILL.md:109 |
| `[CI-010]` | Universal Matrix Shape | **mechanical** | Predicate: YAML AST → assert exactly four jobs in universal swift-ci.yml: `macos-release`, `linux-release`, `linux-nightly`, `windows-release`; fail if other jobs in matrix slot. → γ-2 | ci-cd-workflows/SKILL.md:133 |
| `[CI-011]` | Toolchain Pins | **mechanical** | Predicate: regex across all `*.yml` workflow files; allow `swift:6.3`, `swiftlang/swift:nightly-main-jammy`; forbid `swift:6.[012]`, `swift:latest`, `swiftlang/swift:nightly-latest`. → γ-2 | ci-cd-workflows/SKILL.md:143 |
| `[CI-012]` | Linux Runs in Docker Containers | **mechanical** | Predicate: YAML AST → for any job with `runs-on: ubuntu-*`, require `container:` key set to `swift:6.3` or `swiftlang/swift:nightly-main-jammy`; forbid bare-runner `apt install swift` steps. → γ-2 | ci-cd-workflows/SKILL.md:158 |
| `[CI-013]` | macOS and Windows Runner Specifics | **mechanical** | Predicate: YAML AST → macOS jobs `runs-on: macos-26` AND a step `xcode-select -s /Applications/Xcode_26.4.app`; Windows jobs `runs-on: windows-latest` AND `uses: SwiftyLab/setup-swift@v1`. | ci-cd-workflows/SKILL.md:168 |
| `[CI-020]` | Embedded Buildability Is an L1 Invariant | **mechanical** | Predicate: build-gate at swift-primitives layer wrapper `embedded` job; outcome binary (compiles or not) under `-enable-experimental-feature Embedded`. → γ-3 (target-fidelity laboratory; analog to Wasm SDK) | ci-cd-workflows/SKILL.md:180 |
| `[CI-021]` | Embedded Job Continue-On-Error During 6.4-dev Window | **mechanical** | Predicate: YAML AST → in swift-primitives wrapper, `embedded` job MUST carry `continue-on-error: true`. Sunset-tied; rule body names the trigger to remove. → γ-3 (advisory mode of γ-3 fidelity laboratory) | ci-cd-workflows/SKILL.md:204 |
| `[CI-022]` | Foundation Forbidden in Main Targets | **mechanical** | Predicate: regex `^\s*(@\w+(\([^)]*\))?\s+)?(public\|package\|internal)?\s*(@_exported\s+)?import\s+Foundation(Essentials\|Internationalization)?\b` across `Sources/<MainTarget>/**/*.swift`. → γ-1a (canonical Foundation-import case; ecosystem twin of `[PRIM-FOUND-001]`) | ci-cd-workflows/SKILL.md:216 |
| `[CI-030]` | Reusable Refs Pin to `@main` During Active Dev | **mechanical** | Predicate: regex on `uses:` lines in any consumer `ci.yml` referencing `swift-institute/.github/...` or `swift-primitives/.github/...`; require suffix `@main`; forbid `@v[0-9]+`, `@<sha>`. Third-party `actions/*` exempt. → γ-2 | ci-cd-workflows/SKILL.md:230 |
| `[CI-031]` | Per-Package `ci.yml` Is the Absolute Minimum | **mechanical** | Predicate: YAML AST diff against canonical 16-line shape. Forbid `run:`, `actions/cache`, per-package matrix, runner overrides, explicit `secrets:` mapping. Require `secrets: inherit` per uses. → γ-2 | ci-cd-workflows/SKILL.md:251 |
| `[CI-053]` | DocC Umbrella Metadata Derivation | **mechanical** | Predicate: YAML AST on `swift-docs.yml` reusable → presence of derivation step from `${{ github.event.repository.name }}` with ACRONYMS list; per-package `docs:` callers MUST omit `with:` block when following convention. → γ-2 | ci-cd-workflows/SKILL.md:296 |
| `[CI-054]` | Format/Lint Absorbed in Universal Reusable | **mechanical** | Predicate: (a) universal swift-ci.yml has `format` + `lint` jobs; (b) zero per-repo `swift-format.yml` / `swiftlint.yml` files exist across consumer repos. → γ-2 | ci-cd-workflows/SKILL.md:314 |
| `[CI-058]` | Universal `enable-private-repos` Default True | **mechanical** | Predicate: YAML AST on three reusables → `inputs.enable-private-repos.default == true`; consumer `ci.yml` files MUST NOT carry redundant `enable-private-repos: true` line. → γ-2 | ci-cd-workflows/SKILL.md:337 |
| `[CI-059]` | `secrets: inherit` for Per-Repo Reusable Workflow Calls | **mechanical** | Predicate: regex on consumer `ci.yml` `uses:` blocks → require `secrets: inherit` follower; forbid explicit `secrets:` map containing `PRIVATE_REPO_TOKEN: ${{ secrets.PRIVATE_REPO_TOKEN }}`. → γ-2 | ci-cd-workflows/SKILL.md:356 |
| `[CI-060]` | Org-Level `PRIVATE_REPO_TOKEN` + Free-Plan Visibility Alignment | **hybrid** | Prefilter: GitHub API `gh secret list --org <org>` → assert `PRIVATE_REPO_TOKEN` present with `--visibility all`. AI input: confirm Free-plan-alignment rationale holds; judge plan-upgrade trigger. **External:** GitHub org-state fetch. | ci-cd-workflows/SKILL.md:400 |
| `[CI-032]` | Public/Private Visibility Gate | **mechanical** | Predicate: YAML AST → every `jobs.*` in any intra-Institute reusable workflow MUST carry `if:` clause containing `!github.event.repository.private`. → γ-2 | ci-cd-workflows/SKILL.md:423 |
| `[CI-040]` | No `.build/` Cache, Permanent | **mechanical** | Predicate: regex on all workflow files `actions/cache@v.*` near `.build` paths; forbid except for the rule-named L1 embedded carve-out (job name `embedded` in swift-primitives wrapper, exact-match key, no `restore-keys`). → γ-2 | ci-cd-workflows/SKILL.md:468 |
| `[CI-041]` | `Package.resolved` Is Gitignored Ecosystem-Wide | **mechanical** | Predicate: assert `Package.resolved` line present in every consumer's `.gitignore`; sync-script-driven per [CI-043]. → γ-2 | ci-cd-workflows/SKILL.md:491 |
| `[CI-042]` | No `restore-keys` Partial-Prefix Matching | **mechanical** | Predicate: regex `restore-keys:` in any workflow YAML → fail. → γ-2 | ci-cd-workflows/SKILL.md:505 |
| `[CI-043]` | `.gitignore` Is Centrally Managed | **mechanical** | Predicate: byte-equality of every consumer's `.gitignore` against canonical template in `swift-institute/Scripts/`. Drift detected at next sync run. → γ-2 | ci-cd-workflows/SKILL.md:537 |
| `[CI-055]` | `UseShorthandTypeNames: false` Is Ecosystem-Mandatory | **mechanical** | Predicate: JSON-parse `.swift-format` → assert `rules.UseShorthandTypeNames === false`. Closed-form across all 132+ consumers. | ci-cd-workflows/SKILL.md:566 |
| `[CI-057]` | `.swift-format` and `.swiftlint.yml` Are Per-Package | **semantic** | AI input: distinguish "legitimate per-package customization" (math packages, base62) from "drift that ought to centralize." The rule explicitly inverts [CI-043]'s sync-script discipline; only judgment can decide which file falls in which class on a given commit. | ci-cd-workflows/SKILL.md:587 |
| `[CI-050]` | Mass Changes Require Per-Action Authorization | **semantic** | AI input (workflow): "did the principal explicitly authorize THIS specific push wave / fan-out?" Process discipline; no in-repo commit-time predicate. | ci-cd-workflows/SKILL.md:616 |
| `[CI-051]` | Surgical Commits, Dirty-Skip Discipline | **semantic** | AI input (workflow): commit-message scope check (one logical change), dirty-skip-list discipline. Outcome (commit-graph shape) is observable but the rule's intent is process — see §16 workflow rules. | ci-cd-workflows/SKILL.md:636 |
| `[CI-052]` | Visibility/Tag Changes Require Explicit "YES DO NOW" | **semantic** | AI input: confirm explicit per-action authorization preceded any `gh repo edit --visibility` / `git tag` / `gh release create`. CI can audit the action-event log post-hoc but cannot decide intent. | ci-cd-workflows/SKILL.md:659 |
| `[CI-056]` | Per-Package Build Verification Before Push During Mass Source-Modifying Rollouts | **semantic** | AI input (workflow): for each commit in a mass source-modifying rollout, verify a `swift build` was run between transform and push. CI can re-run build per-commit (mechanical-adjacent) but the rule's force is the procedural gate. | ci-cd-workflows/SKILL.md:678 |

#### 8.2 ci-cd-workflows distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 22 | CI-001, CI-002, CI-003, CI-010, CI-011, CI-012, CI-013, CI-020, CI-021, CI-022, CI-030, CI-031, CI-032, CI-040, CI-041, CI-042, CI-043, CI-053, CI-054, CI-055, CI-058, CI-059 |
| hybrid | 1 | CI-060 |
| semantic | 6 | CI-004, CI-050, CI-051, CI-052, CI-056, CI-057 |

Total 29. **18 of 22 mechanical rules carry an inline γ-mark** (γ-1a + γ-2 family + γ-3); the universal-reusable + YAML-lint + visibility-gate + cache-policy clusters all map directly to designed γ checks.

---

### Part 9 — github-repository (`Skills/github-repository/SKILL.md`)

Verified against `SKILL.md` (555 lines, last_reviewed 2026-04-30). All 32 requirement IDs walked.

#### 9.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[GH-REPO-001]` | Discovery-Lens | **semantic** | AI input: for each metadata field on a repo, judge whether the content "serves a discovering reader's question." Pure intent-of-content judgment. | github-repository/SKILL.md:49 |
| `[GH-REPO-002]` | Single-Source Discipline | **mechanical** | Predicate: nightly `sync-metadata.yml` reusable diffs `.github/metadata.yaml` against `gh repo view --json` state; any divergence → drift detected → revert. → γ-2 | github-repository/SKILL.md:55 |
| `[GH-REPO-003]` | All-active scope | **mechanical** | Predicate: enumerate non-archived repos via `gh api orgs/<org>/repos?type=all`; for each, assert `.github/metadata.yaml` may be present; visibility-agnostic enumeration. | github-repository/SKILL.md:64 |
| `[GH-REPO-010]` | Description required on public repos | **mechanical** | Predicate: for each public production repo, `description` field non-empty (`gh repo view --json description`). Trivial presence check. → γ-2 | github-repository/SKILL.md:78 |
| `[GH-REPO-011]` | Description templates by package class | **hybrid** | Prefilter: regex match against the 8 class-templates in the rule's table; class-detection mechanical from org+repo name. AI input: judge whether the slot value (`«Content phrase»`, `«Family»`, etc.) accurately describes the package's purpose. | github-repository/SKILL.md:83 |
| `[GH-REPO-012]` | Specification-mirroring for L2 | **mechanical** | Predicate: for L2 single-spec repos, lookup `swift-institute/.github/spec-titles.yaml` by authority+spec-id; assert description text matches `Swift implementation of <AUTHORITY-FULL> <N>: <Spec Title>.` verbatim. → γ-2 | github-repository/SKILL.md:105 |
| `[GH-REPO-014]` | Spec-title lookup table | **mechanical** | Predicate: YAML schema validation on `spec-titles.yaml` (two-level map structure); for every L2 single-spec repo, assert lookup hit. → γ-2 | github-repository/SKILL.md:114 |
| `[GH-REPO-013]` | README ↔ description mirroring | **hybrid** | Prefilter: extract README first-paragraph one-liner, truncate to 350 chars, compare to `description` field. AI input: judge whether the README opening *qualifies* as the canonical one-liner per [README-006] (vs being a heading or table). | github-repository/SKILL.md:126 |
| `[GH-REPO-020]` | Required topics | **mechanical** | Predicate: for each public production repo, count topics; assert exactly one bare layer tag from {primitives, standards, foundations, components}, optional one authority tag + one spec-id tag, 1–3 domain tags from [GH-REPO-021] registry, no `swift` tag. → γ-2 | github-repository/SKILL.md:136 |
| `[GH-REPO-021]` | Domain-tag registry — hybrid governance | **hybrid** | Prefilter: per-tag membership in the registry of 41 names. AI input: for inline-extension PRs, judge whether the one-line justification is well-formed and the new tag fills a genuine gap (vs synonym for an existing tag). | github-repository/SKILL.md:153 |
| `[GH-REPO-022]` | Topic format constraints | **mechanical** | Predicate: regex `^[a-z][a-z0-9-]{0,49}$` on every topic value. → γ-2 | github-repository/SKILL.md:188 |
| `[GH-REPO-023]` | Topic count range | **mechanical** | Predicate: `3 <= len(topics) <= 10` for production packages; org-meta + website-stub exempt by class match. → γ-2 | github-repository/SKILL.md:194 |
| `[GH-REPO-024]` | Forbidden topics | **mechanical** | Predicate: literal blocklist intersection against repo topics. → γ-2 | github-repository/SKILL.md:200 |
| `[GH-REPO-030]` | Homepage URL by repo class | **mechanical** | Predicate: lookup table by repo-class detection → assert `homepageUrl` matches expected URL (no-trailing-slash form). → γ-2 | github-repository/SKILL.md:215 |
| `[GH-REPO-031]` | Personal-URL prohibition | **mechanical** | Predicate: regex blocklist `coenttb\.com\|<other personal handles>` against `homepageUrl` across all 17 ecosystem orgs. → γ-2 | github-repository/SKILL.md:227 |
| `[GH-REPO-040]` | LICENSE.md required on package repos; auto-detection MUST succeed | **mechanical** | Predicate: file-presence of top-level `LICENSE.md` AND `gh repo view --json licenseInfo` returns non-null. `.github` org-repos exempt by class match. → γ-1b (License-header family analog) | github-repository/SKILL.md:238 |
| `[GH-REPO-041]` | Apache 2.0 for L1-L3 | **mechanical** | Predicate: for L1/L2/L3 repos, assert `licenseInfo.spdxId == "Apache-2.0"`. → γ-1b | github-repository/SKILL.md:251 |
| `[GH-REPO-050]` | hasIssuesEnabled = true | **mechanical** | Predicate: `gh repo view --json hasIssuesEnabled` == true on every public repo. | github-repository/SKILL.md:261 |
| `[GH-REPO-051]` | hasDiscussionsEnabled = false | **mechanical** | Predicate: `gh repo view --json hasDiscussionsEnabled` == false on every public repo (allowlist for principal-authorized exceptions). | github-repository/SKILL.md:266 |
| `[GH-REPO-052]` | hasWikiEnabled = false | **mechanical** | Predicate: `gh repo view --json hasWikiEnabled` == false on every public repo. | github-repository/SKILL.md:273 |
| `[GH-REPO-053]` | defaultBranch = main | **mechanical** | Predicate: `gh repo view --json defaultBranchRef` resolves to `main` on every repo. | github-repository/SKILL.md:279 |
| `[GH-REPO-054]` | Sidebar visibility — Packages and Deployments off by default; Releases on | **semantic** | AI/human input: GitHub does not expose `hasReleasesEnabled` / `hasPackagesEnabled` / `hasDeploymentsEnabled` via REST or GraphQL as of 2026-04-29. Rule's enforcement is currently manual click-through; YAML records intent only. **External: GitHub API gap.** See §16 new-resistant: API-gap rules. | github-repository/SKILL.md:285 |
| `[GH-REPO-060]` | `.github/metadata.yaml` location and schema | **mechanical** | Predicate: file-presence of `.github/metadata.yaml` + JSON-schema validation against the rule's schema (description string ≤350, topics array 3-10, optional homepage/settings/sidebar blocks). → γ-2 | github-repository/SKILL.md:319 |
| `[GH-REPO-061]` | Idempotency contract | **mechanical** | Predicate: re-run `sync-metadata.yml` against same repo state twice in succession; assert second-run produces zero `gh repo edit` invocations. → γ-2 | github-repository/SKILL.md:345 |
| `[GH-REPO-062]` | Field defaults when YAML omits a key | **mechanical** | Predicate: parse `metadata.yaml`; for each omitted optional key, assert sync-script applies the canonical default rather than preserving GitHub-side state. → γ-2 | github-repository/SKILL.md:351 |
| `[GH-REPO-070]` | Centralized reusable workflows | **mechanical** | Predicate: assert presence of three workflow files at `swift-institute/.github/.github/workflows/{sync-metadata,sync-metadata-nightly,generate-metadata}.yml` AND inputs/triggers match the rule's spec. → γ-2 | github-repository/SKILL.md:362 |
| `[GH-REPO-071]` | Drift detection and convergence cadence | **mechanical** | Predicate: YAML AST on `sync-metadata-nightly.yml` → assert `schedule.cron == "0 4 * * *"` AND `workflow_dispatch:` trigger present AND tracking-issue creation step on failure. → γ-2 | github-repository/SKILL.md:390 |
| `[GH-REPO-072]` | Boundary with adjacent CI tooling | **semantic** | AI input: declarative table assigning concerns to tools. Verifying "is X the right concern for Y tool" requires understanding the concern boundaries; CI can detect duplicate work but not concept-fit. | github-repository/SKILL.md:416 |
| `[GH-REPO-073]` | Authentication | **hybrid** | Prefilter: `gh api app/installations` confirms `swift-institute-bot` installed across 17 orgs with declared permission set; `swift-institute/.github` org-secrets `SWIFT_INSTITUTE_BOT_APP_ID` + `_PRIVATE_KEY` present. AI input: judge "permissions accrete only when concerns require" intent on each new permission addition. **External:** GitHub App install state across 17 orgs. | github-repository/SKILL.md:431 |
| `[GH-REPO-074]` | Per-Package Workflow Files MUST Be Thin Callers | **mechanical** | Predicate: YAML AST on `<package>/.github/workflows/{ci,swift-format,swiftlint,docs}.yml` → forbid `runs-on:`, `steps:`, `uses: actions/checkout@`, etc. at job level; require single `uses: <central reusable>` + `with:` + `secrets:`. Line-count threshold 30. → γ-2 | github-repository/SKILL.md:465 |
| `[GH-REPO-080]` | `.github` repo metadata | **mechanical** | Predicate: each org's `.github` repo has description matching `Organization-level community-health defaults for {OrgName}.`, no topics, no homepage, repo-settings rules per [GH-REPO-050..053]. License exempt. → γ-2 | github-repository/SKILL.md:520 |
| `[GH-REPO-081]` | Org website stub repo | **mechanical** | Predicate: each `swift-{layer}.org` repo has description matching `Stub for the future {layer}.org website. Content will be developed; for now, see https://swift-institute.org.` and `homepage = https://swift-institute.org/`. → γ-2 | github-repository/SKILL.md:529 |

#### 9.2 github-repository distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 25 | GH-REPO-002, GH-REPO-003, GH-REPO-010, GH-REPO-012, GH-REPO-014, GH-REPO-020, GH-REPO-022, GH-REPO-023, GH-REPO-024, GH-REPO-030, GH-REPO-031, GH-REPO-040, GH-REPO-041, GH-REPO-050, GH-REPO-051, GH-REPO-052, GH-REPO-053, GH-REPO-060, GH-REPO-061, GH-REPO-062, GH-REPO-070, GH-REPO-071, GH-REPO-074, GH-REPO-080, GH-REPO-081 |
| hybrid | 4 | GH-REPO-011, GH-REPO-013, GH-REPO-021, GH-REPO-073 |
| semantic | 3 | GH-REPO-001, GH-REPO-054, GH-REPO-072 |

Total 32. **2 γ-1b matches** (license rules) and **22 γ-2 matches** (YAML/template lint family) — github-repository codifies metadata-field values directly, making nearly every rule a `gh repo view --json` check.

---

### Part 10 — swift-institute-core (`Skills/swift-institute-core/SKILL.md`)

Verified against `SKILL.md` (135 lines, last_reviewed 2026-04-30). **Zero requirement IDs declared.**

This skill is a **manifest-only meta-skill**: it declares canonical sources, the skill index, the requirement-ID convention, the loading-order DAG, and package locations. It contains zero `[REQ-ID]` rules. The skill's authority is referential — it asserts which OTHER skills carry the requirements (e.g., `[ARCH-LAYER-*]` lives in `swift-institute`, `[API-NAME-*]` lives in `code-surface`). Closest enforceable assertion is the "Requirement ID convention" prose at line 80 (regex shape `[A-Z]+(-[A-Z]+)+` and `[A-Z]+-\d+`), but it is not numbered.

#### 10.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| (none) | — | — | The skill carries no requirement IDs; it is a meta-manifest. | swift-institute-core/SKILL.md:80 |

#### 10.2 swift-institute-core distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 0 | — |
| hybrid | 0 | — |
| semantic | 0 | — |

Total 0. swift-institute-core has zero classifiable requirement IDs. The skill is a system manifest — it indexes the corpus, declares loading order, and names canonical paths. The skill **should be excluded from any rollout-counting denominator that uses "requirements per skill"** (calibration data per §15).

---

### Part 11 — swift-package (`Skills/swift-package/SKILL.md`)

Verified against `SKILL.md` (479 lines, last_reviewed 2026-04-30). All 10 requirement IDs walked. ID prefix is `[PKG-NAME-*]`.

#### 11.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[PKG-NAME-001]` | Noun Form for Packages and Namespaces | **hybrid** | Prefilter: regex `-ing(-primitives)?$` on package directory names AND AST query for top-level namespace `enum` declarations whose names end in `-ing`. AI input: distinguish gerund (forbidden) from coincidental `-ing` ending in a noun (e.g., `String`, `Routing` if interpreted as noun) — English part-of-speech judgment. | swift-package/SKILL.md:41 |
| `[PKG-NAME-002]` | Canonical Capability Protocol | **mechanical** | Predicate: AST query — for each namespace `enum N`, if it declares a protocol named `` `Protocol` ``, then verify (a) module-scope typealias `Gerund = N.\`Protocol\`` exists, (b) typealias is NOT nested. | swift-package/SKILL.md:87 |
| `[PKG-NAME-003]` | External-Compatibility Exception | **semantic** | AI input: judge whether a gerund-form package name corresponds to a "specific, named external package we are establishing source-compatible interop with" (permitted) versus aesthetic preference / "common in this domain" (forbidden). | swift-package/SKILL.md:151 |
| `[PKG-NAME-004]` | Foundations Cascade | **hybrid** | Prefilter: AST/Package.swift parse — for each L3 package whose namespace is a "purely primitive vocabulary," check (a) no `import Foundation`, (b) all deps are L1, (c) `-primitives` suffix. AI input: judge whether the package's namespace IS a "purely primitive vocabulary" vs a foundation that composes multiple concerns. | swift-package/SKILL.md:199 |
| `[PKG-NAME-005]` | Shortest Natural Noun | **semantic** | AI input: for a domain verb, enumerate noun forms; judge whether a candidate noun is a "first-class English noun independent of the gerund reading" (natural) vs a forced verb-as-noun. **External:** English dictionary / part-of-speech lookup. | swift-package/SKILL.md:251 |
| `[PKG-NAME-006]` | Hoisted Protocol for Generic Namespaces | **mechanical** | Predicate: AST query — for each generic namespace type (`struct G<...>` or `extension G where ...`) that has a `` `Protocol` `` typealias, verify (a) hoisted protocol exists at module scope named `__<Name>Protocol`, (b) typealias targets the hoisted protocol, (c) gerund typealias also targets hoisted protocol directly. | swift-package/SKILL.md:283 |
| `[PKG-NAME-007]` | Phase-0 Pre-Rename Audit Requirements | **mechanical** | Outcome predicate: workflow rule whose verifiable artifact is the rename's PR — verify the two greps (`import <OldModule>` ecosystem-wide AND `(extension\|enum\|struct) +[A-Za-z._]*\.<OldNamespace>`) were run by checking the rename's tracking-issue/PR-description for grep output. Process timing CI cannot observe; the artifacts can. (Workflow rule per pilot §5.2.) | swift-package/SKILL.md:366 |
| `[PKG-NAME-008]` | Shadow-on-Merge Hazard | **mechanical** | Predicate: post-rename diff scan — for each rename collapsing gerund-outer/noun-inner into noun-outer/same-noun-inner, regex/AST scan call sites inside `extension <Inner>` for bare references to the inner tag that previously meant the outer. Build-failure surface is the natural CI signal. → γ-1c-adjacent (API-breakage advisory pilot's lift to namespace shadows) | swift-package/SKILL.md:393 |
| `[PKG-NAME-009]` | Capability-Protocol vs Noun-Type Distinction | **semantic** | AI input: for each protocol declared, judge whether the protocol's namespace has "concrete value type backing" (consumers instantiate `let c = N(...)`) vs is "purely a capability or marker." Decision test depends on intent of the API. | swift-package/SKILL.md:411 |
| `[PKG-NAME-010]` | GitHub Release vs Git Tag — Different Questions | **mechanical** | Predicate: workflow-correctness check — for any audit/recipe asking "is there a tag?" verify it calls `git describe --tags --abbrev=0` (or `git tag -l`); for "is there a release?" verify it calls `gh repo view --json latestRelease`. Closed-form API-call audit on heritage/version-detection scripts. | swift-package/SKILL.md:445 |

#### 11.2 swift-package distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 5 | PKG-NAME-002, PKG-NAME-006, PKG-NAME-007, PKG-NAME-008, PKG-NAME-010 |
| hybrid | 2 | PKG-NAME-001, PKG-NAME-004 |
| semantic | 3 | PKG-NAME-003, PKG-NAME-005, PKG-NAME-009 |

Total 10.

---

### Part 12 — ecosystem-data-structures (`Skills/ecosystem-data-structures/SKILL.md`)

Verified against `SKILL.md` (434 lines, last_reviewed 2026-03-26). All 11 requirement IDs walked. **Most semantic-heavy skill in the tier-1 set** (per §15 calibration).

#### 12.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[DS-001]` | Four-Layer Composition | **semantic** | AI input: for each new container/buffer/storage/memory implementation, judge whether it composes from the canonical four layers (Memory → Storage → Buffer → Collection) versus bypasses them. | ecosystem-data-structures/SKILL.md:30 |
| `[DS-002]` | Variant Selection | **semantic** | AI input: given a use-case (allocation strategy: dynamic / fixed / known-at-compile / spillable / immutable), select the matching variant. | ecosystem-data-structures/SKILL.md:57 |
| `[DS-003]` | Container Selection | **semantic** | AI input: for a chosen container type, judge whether it matches the access pattern (random/LIFO/FIFO/membership/etc.) and whether a Collection-level type was preferred over Buffer/Storage when one exists. | ecosystem-data-structures/SKILL.md:86 |
| `[DS-004]` | Buffer Selection | **semantic** | AI input: when no Collection covers the use case, judge which of six Buffer disciplines (Linear/Ring/Slab/Linked/Slots/Arena) matches the mutation/access pattern. | ecosystem-data-structures/SKILL.md:195 |
| `[DS-005]` | Storage Selection | **semantic** | AI input: for new Buffer/custom-container builders, judge which Storage type (Heap/Inline/Arena/Slab/Pool/Split) matches the lifecycle pattern. | ecosystem-data-structures/SKILL.md:224 |
| `[DS-006]` | Memory Layer Selection | **semantic** | AI input: judge whether dropping to Memory layer is justified (consumer is "building Storage-level or lower infrastructure") and which Memory type (Allocator/Arena/Pool/Buffer/Contiguous/Inline) matches. | ecosystem-data-structures/SKILL.md:247 |
| `[DS-007]` | Bit-Level Selection | **semantic** | AI input: select Bitset (user-facing) vs Bit.Vector (infrastructure) vs Bit.Pack (witness). | ecosystem-data-structures/SKILL.md:283 |
| `[DS-008]` | Foundations Selection | **semantic** | AI input: judge whether the task requires "OS integration, concurrency, or serialization" warranting an L3 type. | ecosystem-data-structures/SKILL.md:299 |
| `[DS-009]` | Index and Tagging Types | **semantic** | AI input: identify pervasive type-safe-access patterns and route to Index/Tagged/Hash.Value/Property — none of which are containers themselves. | ecosystem-data-structures/SKILL.md:318 |
| `[DS-010]` | Container Selection Flowcharts | **semantic** | AI input: walk the decision tree given the use-case description. Tree leaves map to concrete types, but the tree's predicates ("Need use-after-free detection?", "Bounded arity?") demand semantic interpretation. | ecosystem-data-structures/SKILL.md:338 |
| `[DS-020]` | Gate Before Proposing a New Ecosystem Primitive | **hybrid** | Prefilter: detect proposals/PRs adding new packages under `swift-*-primitives/` (mechanical: new top-level Package.swift in the primitives org). AI input: verify the proposal documents (a) the data-structures inventory was consulted, (b) composition over existing primitives was attempted and shown not to cover, (c) the missing property is named precisely. | ecosystem-data-structures/SKILL.md:405 |

#### 12.2 ecosystem-data-structures distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 0 | — |
| hybrid | 1 | DS-020 |
| semantic | 10 | DS-001, DS-002, DS-003, DS-004, DS-005, DS-006, DS-007, DS-008, DS-009, DS-010 |

Total 11.

---

### Part 13 — release-readiness (`Skills/release-readiness/SKILL.md`)

Verified against `SKILL.md` (280 lines, last_reviewed 2026-04-30). All 6 requirement IDs walked. **Composite-heavy skill** (4 of 6 hybrid via composite shape — see §16).

#### 13.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[RELEASE-001]` | Release-Readiness Brief | **hybrid** | Prefilter: filesystem check — for any major-version tag, verify `<package>/AUDIT-{VERSION}-release-readiness.md` exists; verify it has the four-phase headings (Phase 0 Baseline / Phase 1 Gap closure / Phase 2 Systematic audit / Phase 3 Release-readiness checks). Mechanical: file presence + header presence. AI input: judge whether each phase's CONTENT is substantive (Phase 0 actually verifies clean tree + CI green; Phase 2 actually invoked /audit; Phase 3 nine-item table populated meaningfully). Composite per pilot §5.1. | release-readiness/SKILL.md:70 |
| `[RELEASE-002]` | Final Pre-Release Scan | **hybrid** | Prefilter: filesystem check — for any major-version tag preceded by substantial-change set, verify `<package>/AUDIT-{VERSION}-final-pre-release-scan.md` exists with seven-phase headings. Mechanical: file presence + header presence + "Do Not Touch" boundary line. AI input: judge whether scan reproduces conclusions independently (does NOT trust prior verdicts), whether Phase 6 backlog rows are re-derived from current source rather than copied, whether Phase 4 forums-review re-simulation occurred. → γ-1c (API-breakage scan in Phase 1/2 maps to API-breakage advisory pilot) | release-readiness/SKILL.md:98 |
| `[RELEASE-003]` | Skill-Incorporation Gate | **hybrid** | Prefilter: detect pilot-launch context (cohort-of-1+ where this is the first tag) and verify `swift-institute/Research/<package>-launch-skill-incorporation-backlog.md` exists; verify Tier 1 rows in tabular format with status column. AI input: judge whether each Tier 1 item is genuinely a "direct skill amendment" (not a Tier 2 process improvement misclassified), whether deferral rationales are valid. | release-readiness/SKILL.md:129 |
| `[RELEASE-004]` | Per-Action Authorization Gates | **mechanical** | Outcome predicate: for a release tag's PR/commit history, verify (a) `git tag` did not appear without an immediately-preceding principal-authorization marker, (b) repo-visibility flip and blog-publish actions are logged with separate authorization stamps. (Workflow rule per pilot §5.2; outcome verifiable.) | release-readiness/SKILL.md:172 |
| `[RELEASE-005]` | Final Go/No-Go Recommendation | **hybrid** | Prefilter: regex on the pre-release scan's final section — must end in one of `GO` / `CONDITIONAL GO` / `NO-GO` plus a severity-summary table. AI input: judge whether the categorization is justified (zero CRITICAL/HIGH for GO; specifically-listed accepted-as-known items for CONDITIONAL GO; CRITICAL/HIGH present for NO-GO). | release-readiness/SKILL.md:204 |
| `[RELEASE-006]` | Findings Destination | **mechanical** | Predicate: filesystem check — for each release-readiness pass, verify `<package>/Audits/audit.md` exists with `## {Skill}` per-pass headings; verify forums-review artifacts at `<package>/Audits/forums-review/forums-review-{simulation,objections,triage}-{DATE}.md`; verify both directories appear in `.gitignore`. | release-readiness/SKILL.md:228 |

#### 13.2 release-readiness distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 2 | RELEASE-004, RELEASE-006 |
| hybrid | 4 | RELEASE-001, RELEASE-002, RELEASE-003, RELEASE-005 |
| semantic | 0 | — |

Total 6.

---

### Part 14 — package-export (`Skills/package-export/SKILL.md`)

Verified against `SKILL.md` (340 lines, last_reviewed 2026-03-20). All 11 requirement IDs walked.

#### 14.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[PKG-EXPORT-001]` | Output Structure | **mechanical** | Predicate: regex/parse on the export file — verify (a) starts with `# {package-name}`, (b) `## Package Manifest` followed by Package.swift content, (c) `## File Structure` followed by file tree, (d) `## Source Files` followed by `### File: {path}` blocks. | package-export/SKILL.md:28 |
| `[PKG-EXPORT-002]` | Tests Export Structure | **mechanical** | Predicate: regex on tests-export file — verify `# {package-name} Tests`, `## Test File Structure`, `## Test Files`, then `### File: {path}` blocks. | package-export/SKILL.md:63 |
| `[PKG-EXPORT-003]` | File Order | **mechanical** | Predicate: parse export's `### File:` blocks; for each directory, verify ordering — files matching `{Namespace}.swift` (where other files in the same dir start with `{Namespace}.`) appear before alphabetic siblings. | package-export/SKILL.md:87 |
| `[PKG-EXPORT-004]` | Exclusions | **mechanical** | Predicate: grep export file body — must NOT contain content from `.build/`, `.git/`, `Package.resolved`, `.DS_Store`, or any path matched by the package's `.gitignore`. | package-export/SKILL.md:102 |
| `[PKG-EXPORT-005]` | Output Path | **mechanical** | Predicate: verify export file path matches `^/tmp/{package-name}-(sources\|tests\|all)\.swift$`. | package-export/SKILL.md:120 |
| `[PKG-EXPORT-006]` | Token Warning | **mechanical** | Predicate: post-export, verify (a) token count reported as `chars/4`, (b) warning emitted if `tokens > 32000` ("ChatGPT Plus limit") or `tokens > 100000` ("most model limits"). | package-export/SKILL.md:136 |
| `[PKG-EXPORT-007]` | Script-Based Export | **mechanical** | Predicate: when export is performed by a script, verify the script matches the canonical bash skeleton (Package.swift existence guard, namespace-root sort function, $OUTPUT to /tmp/, token report, optional --with-tests branch). Diff/regex check against shipped reference. | package-export/SKILL.md:155 |
| `[PKG-EXPORT-008]` | Quick Export Command | **mechanical** | Predicate: when export uses the one-liner, verify the literal command-template (no missing `Package.swift` cat, no missing `## Source Files` header, no skipped `wc -c` reporting). | package-export/SKILL.md:254 |
| `[PKG-EXPORT-009]` | Claude Execution | **mechanical** | Predicate: verify Claude's execution shape — single Bash invocation (NOT multiple Read calls), output-path reported, token estimate reported, threshold warning emitted. Observable from session transcript / tool-call log. (Workflow-vs-outcome resistant per pilot §5.2.) | package-export/SKILL.md:263 |
| `[PKG-EXPORT-010]` | Invocation Examples | **semantic** | AI input: this rule's content is non-normative example invocations (sources-only / with-tests / by-path). No verifiable predicate — it's a documentation/illustration block. (Reference-table-as-rule resistant pattern per §16.) | package-export/SKILL.md:294 |
| `[PKG-EXPORT-011]` | Context Window Reference | **semantic** | AI input: this rule's content is a non-normative reference table of ChatGPT context-limit values "as of 2025" — verifying it requires fetching current OpenAI model docs. Stale-data risk; AI fetch + reconcile. **External:** OpenAI model docs / model-card lookup. (Reference-table-as-rule resistant pattern per §16.) | package-export/SKILL.md:320 |

#### 14.2 package-export distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 9 | PKG-EXPORT-001, PKG-EXPORT-002, PKG-EXPORT-003, PKG-EXPORT-004, PKG-EXPORT-005, PKG-EXPORT-006, PKG-EXPORT-007, PKG-EXPORT-008, PKG-EXPORT-009 |
| hybrid | 0 | — |
| semantic | 2 | PKG-EXPORT-010, PKG-EXPORT-011 |

Total 11.

---

### Part 15 — Aggregate distribution and density calibration

#### 15.1 Per-skill distribution

| Skill | Mechanical | Hybrid | Semantic | Total | Mechanical % |
|---|---|---|---|---|---|
| existing-infrastructure | 13 | 11 | 2 | 26 | 50.0% |
| documentation | 32 | 15 | 14 | 61 | 52.5% |
| swift-institute | 1 | 0 | 0 | 1 | 100% |
| audit | 14 | 9 | 8 | 31 | 45.2% |
| benchmark | 6 | 2 | 2 | 10 | 60.0% |
| swift-package-build | 6 | 1 | 1 | 8 | 75.0% |
| ci-cd-workflows | 22 | 1 | 6 | 29 | 75.9% |
| github-repository | 25 | 4 | 3 | 32 | 78.1% |
| swift-institute-core | 0 | 0 | 0 | 0 | n/a |
| swift-package | 5 | 2 | 3 | 10 | 50.0% |
| ecosystem-data-structures | 0 | 1 | 10 | 11 | 0.0% |
| release-readiness | 2 | 4 | 0 | 6 | 33.3% |
| package-export | 9 | 0 | 2 | 11 | 81.8% |
| **Tier-1 total** | **135** | **50** | **51** | **236** | **57.2%** |
| Pilot baseline (3 skills) | 26 | 15 | 16 | 57 | 45.6% |

#### 15.2 Aggregate three-class distribution (tier-1 vs pilot)

| Class | Tier-1 count | Tier-1 % | Pilot % | Δ |
|---|---|---|---|---|
| mechanical | 135 | 57.2% | 45.6% | **+11.6 pp** |
| hybrid | 50 | 21.2% | 26.3% | −5.1 pp |
| semantic | 51 | 21.6% | 28.1% | −6.5 pp |

**Tier-1 is materially more mechanical-heavy than the pilot baseline** (57% vs 46% mechanical, +12 pp). This confirms the parent-thread hypothesis that infra/process skills concentrate mechanical-rule density. The shift is split across hybrid (−5 pp) and semantic (−6.5 pp) — both shrink in proportion but neither collapses.

#### 15.3 Density outliers (calibration data per supervisor block ask: clause)

The supervisor block's first ask: clause asks for surfacing if a tier-1 skill's mechanical-rule density turns out materially different from expected. Three outliers warrant calibration callouts for tier-2/3 dispatch ordering:

| Skill | Observed | Expectation | Calibration signal |
|---|---|---|---|
| `swift-institute-core` | 0 IDs | Some IDs | **Manifest-only meta-skill.** Carries zero requirement IDs; should be excluded from "requirements per skill" denominators in rollout planning. The closest enforceable assertion is the prose-stated ID-naming-convention regex at line 80 (not numbered). |
| `swift-institute` | 1 ID | More IDs | **Degenerate single-rule skill** — `[ARCH-LAYER-001]` Dependency Direction is the only rule; the skill's bulk lives in `Documentation.docc/` and in child skills. May warrant absorption (per `skill-lifecycle`) but out of scope for this dispatch. |
| `ecosystem-data-structures` | 0/1/10 | Mechanical-heavy expected | **Pure-catalog selection-guidance skill.** 91% semantic — every selection rule (Container/Buffer/Storage/Memory/Bit-Level/Foundations/Index/etc.) is a semantic match against a domain pattern. The single hybrid rule [DS-020] is the gate-before-new-primitive process rule. **Calibration consequence**: tier-2/3 ordering should not assume "tier" predicts mechanical density — `ecosystem-data-structures` is structurally tier-1 (per the handoff brief) but its rule shape is pure-semantic. |
| `release-readiness` | 2/4/0 | Process-heavy expected | **Composite-rule skill.** 4 of 6 rules are composite-hybrid (skeleton mechanical + content-quality semantic); zero pure-semantic rules. The composite shape dominates — see §16. |
| `swift-package-build` | 6/1/1 (75% mech) | Operational | **Operational invocation skill.** Per-action toolchain/CI-config patterns — almost entirely regex-checkable. Higher mechanical density than the pilot baseline. |
| `package-export` | 9/0/2 (82% mech) | Process-flexible | **Strict-template skill.** The skill encodes a bash-template and output-shape that is regex-checkable end-to-end; only the two illustrative-content rules ([PKG-EXPORT-010/011]) are non-mechanical (and they're a new resistant pattern — see §16). |

#### 15.4 γ-roadmap saturation

Distribution of γ-marks across the 135 tier-1 mechanical rules:

| γ class | Count | Skills carrying matches |
|---|---|---|
| γ-1a (Foundation-import) | 1 | ci-cd-workflows ([CI-022]) |
| γ-1b (License-header) | 2 | github-repository ([GH-REPO-040], [GH-REPO-041]) |
| γ-1c-adjacent (API-breakage) | 2 | swift-package ([PKG-NAME-008]); release-readiness ([RELEASE-002]) |
| γ-2 (YAML/symlink/template lint family) | 38 | ci-cd-workflows (18); github-repository (20) |
| γ-3 / γ-3b (target-fidelity laboratories) | 8 | ci-cd-workflows ([CI-020], [CI-021]); swift-package-build ([PKG-BUILD-001], [PKG-BUILD-005], [PKG-BUILD-006], [PKG-BUILD-007], [PKG-BUILD-008]); audit ([AUDIT-023] / [AUDIT-027] adjacent); benchmark ([BENCH-008] adjacent) |
| γ-2b / γ-4 | 0 | — (no matches in tier-1) |

**51 of 135 mechanical rules (37.8%) carry a γ-roadmap match.** The cluster is dominated by γ-2 (YAML/template lint) which the v1.2.0 §3.4.5 scope nominally covers `.github/workflows/**/*.yml` etc.; the broader interpretation here treats workflow-AST and metadata-schema checks as γ-2 family because they share the same operational shape (deterministic scan against a closed target). If γ-2 is read narrowly (lint only `yamllint` + broken-symlink), the γ-2 saturation drops; if read broadly (the full deterministic-scan family), the saturation rises to ≈40% of tier-1 mechanical rules.

ci-cd-workflows + github-repository together carry **40 of 51 γ matches** (78% of all γ-marks in tier-1) — these two skills are the workflow-construction gold mine the parent thread predicted.

---

### Part 16 — Resistant-set diagnostic (extending pilot Part 5)

The pilot's three resistant patterns (composite multi-mechanism, workflow-vs-outcome, external-knowledge fetch) all appear at tier-1 with materially larger absolute counts. **Three new resistant patterns surface at tier-1** that the pilot's three patterns do not cover.

#### 16.1 Pilot patterns (composite / workflow / external) — tier-1 cases

##### 16.1.a Composite (multi-mechanism in one ID) — 12 cases

A single requirement encodes multiple verification mechanisms across mechanical and semantic classes; collapsed `hybrid` aggregate is correct on average but obscures per-mechanism CI viability.

| Skill | IDs | Notes |
|---|---|---|
| existing-infrastructure | INFRA-026 | AST + SDK `.swiftinterface` grep + conformance-deferral judgment — most layered case in tier-1 |
| documentation | DOC-001, DOC-002, DOC-005, DOC-019a, DOC-023, DOC-050 | All carry presence-check + role-content-judgment shape |
| audit | AUDIT-002, AUDIT-019, AUDIT-027 | AUDIT-002 is filesystem + git-tracking + canonical-gitignore (3-layer); AUDIT-027 builds on a γ-3-shape build-gate sub-check |
| ci-cd-workflows | CI-031, CI-040 | CI-031 has 6 sub-checks (file-presence + per-line forbidden + AST `uses:` + `secrets:` + `concurrency:` + line-count); CI-040 carries an inline carve-out for the L1 embedded job |
| release-readiness | RELEASE-001, RELEASE-002, RELEASE-003, RELEASE-005 | The dominant shape in this skill — every brief/scan is a phased document where skeleton is mechanical and per-phase content is semantic |

**Materiality: HIGH.** Pilot's recommendation §6.2 (split atomic OR `**Composite:**` annotation) applies unchanged. The release-readiness cluster is a strong test case — 4 of 6 rules are composite — and would be the natural reference skill for validating the `**Composite:**` annotation pattern.

##### 16.1.b Workflow (process vs outcome) — 14 cases

Rule prescribes timing or sequence ("check at proposal time," "verify before promoting"); CI cannot observe the timing — only the outcome at commit time.

| Skill | IDs | Notes |
|---|---|---|
| existing-infrastructure | INFRA-050 | "Before proposing new typed value, MUST check canonical primitives" |
| documentation | DOC-042, DOC-053 | "When spec text changes" / "warrants major version bump" — process at change-time |
| audit | AUDIT-005, AUDIT-015, AUDIT-020, AUDIT-022, AUDIT-030 | 5 of 7 tier-1 workflow-rules live here; audit prescribes more process discipline than any other tier-1 skill |
| benchmark | BENCH-002 | `rm -rf .build` cleanup before run |
| swift-package-build | PKG-BUILD-003 | Triage hypothesis order |
| ci-cd-workflows | CI-051, CI-056 | Dirty-skip + per-package build verify before push |
| swift-package | PKG-NAME-007 | Phase-0 pre-rename greps (CI sees the artifacts but not the timing) |
| ecosystem-data-structures | DS-020 | Consult-before-propose timing |
| release-readiness | RELEASE-004 | Per-action authorization gates (CI sees git/blog/visibility history) |
| package-export | PKG-EXPORT-009 | Single-Bash-invocation discipline |

**Materiality: MEDIUM.** Pilot's recommendation §6.2 (clarify that `Verification:` field encodes outcome class, not process class) applies unchanged. The audit skill's 5-rule cluster reinforces the recommendation — workflow-vs-outcome is the dominant resistant pattern in audit.

##### 16.1.c External-knowledge (fetch cost) — 12 cases

Rule requires external authority (specs, stdlib, GitHub APIs, OS docs); class assignment unchanged, but cost-per-verification is materially higher.

| Skill | IDs | External authority |
|---|---|---|
| existing-infrastructure | INFRA-026 | SDK `.swiftinterface` (in-host, cheap to cache) |
| documentation | DOC-005, DOC-041, DOC-042 | RFC/ISO/IEEE spec text (remote, per-spec cache) |
| audit | AUDIT-018, AUDIT-031 | Receipt fetch (in-tree or remote); upstream patch fetch |
| swift-package-build | PKG-BUILD-001, PKG-BUILD-008 | Local toolchain `.swiftinterface` lookup; embedded-stdlib-availability check |
| ci-cd-workflows | CI-060 | GitHub org-state |
| github-repository | GH-REPO-073 | GitHub App install state across 17 orgs |
| swift-package | PKG-NAME-005 | English dictionary / part-of-speech |
| package-export | PKG-EXPORT-011 | OpenAI model-docs lookup |

**Materiality: LOW.** Pilot's recommendation §6.3 (`**External:**` annotation) applies unchanged; tier-1 surfaces no new external-authority class beyond what the pilot already enumerated (specs, stdlib, GitHub APIs, dictionary).

#### 16.2 New resistant patterns surfaced at tier-1

##### 16.2.a NEW: Decision-tree wrappers around mechanical predicates

**Cases**: existing-infrastructure INFRA-020, INFRA-024 (and INFRA-021, INFRA-022, INFRA-023, INFRA-025 to a lesser degree).

The rule states a *trigger* ("Before writing X, run this decision tree") whose tree-leaves are themselves mechanical (closed-form regex predicates routing to a closed-form replacement). Outcome-classed `mechanical` (correctly so), but the *rule's value* is the decision-tree's authorial routing — at proposal time. CI can flag the trigger pattern and surface the matching leaf, but the rule's primary use is at-the-keyboard navigation (a kind of *embedded routing skill* rather than an outcome rule).

**Distinction from §16.1.b workflow rules**: workflow rules' timing is "before a downstream commit"; decision-tree wrappers' timing is "during authoring of new code," and the tree's routing logic is the rule's load-bearing artifact. Workflow rules are about *when* to run a check; decision-tree wrappers are about *where in the catalog to find the right check*.

**Recommended remediation**: classify as `mechanical` (correct for outcome) AND annotate `**Routing:**` to flag the decision-tree shape — same pattern as the pilot's `**Composite:**` annotation but for tree-structured single-class rules. Operational planners use the annotation to budget for editor-integration tooling (e.g., "before-you-write" linters) rather than CI.

**Materiality**: MEDIUM. Limited to existing-infrastructure within tier-1, but this pattern is structurally common in catalog/index skills and is likely to recur in tier-2/3.

##### 16.2.b NEW: API-gap rules (verification blocked by absence of upstream API)

**Cases**: github-repository [GH-REPO-054] (sidebar visibility — GitHub provides no API for `hasReleasesEnabled` / `hasPackagesEnabled` / `hasDeploymentsEnabled`).

The rule's verification depends on a platform feature that does not yet exist. The three-class taxonomy assumes verification is technically possible; this rule's verification is *aspirational* — it would be `mechanical` if the API existed but is currently un-classifiable. The skill records the rule as a forward-looking schema slot in `metadata.yaml`, with manual click-through enforcement only.

**Why this is distinct from §16.1.c external-knowledge**: external-knowledge rules have a verification path (fetch the external authority); API-gap rules have *no verification path at all* on the current platform. The cost is not "higher per-verification" but "verification not possible until upstream ships the feature."

**Recommended remediation**: introduce a `**API-Gap:**` annotation flagging the upstream-dependency. The rule's `Verification:` field holds the *aspirational* class (`mechanical` once GitHub ships the API); the `API-Gap:` annotation records the blocker so operational planners do not budget CI implementation for unimplementable rules.

**Materiality**: LOW (one case in tier-1) but **structurally important** — without the annotation, the rule looks classifiable when it is not, which inflates rollout-readiness estimates.

##### 16.2.c NEW: Reference-table-as-rule (catalogue/illustration content wrapped in a requirement ID)

**Cases**: package-export [PKG-EXPORT-010] (invocation examples), [PKG-EXPORT-011] (context-window reference table).

The rule's body is a non-normative reference table or catalogue of example invocations rather than a verifiable assertion. There is no MUST/SHOULD assertion to enforce — the requirement-ID wraps illustration content. Three-class taxonomy assigns `semantic` by default ("AI judgment to interpret"), but the operational reality is "no enforcement mechanism applies because there is no rule to enforce."

**Why this is distinct from §16.1.b workflow rules and §16.1.c external-knowledge**: workflow rules name a process; external-knowledge rules require fetching an authority — both have an enforceable assertion. Reference-table-as-rule has no assertion at all.

**Recommended remediation**: either (a) restructure these as non-numbered prose under the parent rule (no requirement-ID) — which is the cleanest fix — OR (b) introduce a fourth annotation `**Reference:**` for catalogue/illustration content, with the convention that reference-class rules are not subject to the same skill-lifecycle review as enforceable rules.

**Materiality**: LOW (two cases in tier-1) but **diagnostically important** — flags candidates for skill-cleanup that should drop the requirement-ID.

#### 16.3 Updated resistant-set summary

| Class of resistance | Tier-1 count | Pilot count | Materiality | Recommended remediation |
|---|---|---|---|---|
| Composite (multi-mechanism) | 12 | 5 | HIGH | Pilot §6.2 unchanged: split atomic OR `**Composite:**` annotation |
| Workflow (process vs outcome) | 14 | 5 | MEDIUM | Pilot §6.2 unchanged: clarify field encodes outcome class |
| External-knowledge (fetch cost) | 12 | 3 | LOW | Pilot §6.3 unchanged: `**External:**` annotation |
| **NEW: Decision-tree wrappers** | 6 | 0 | MEDIUM | Add `**Routing:**` annotation |
| **NEW: API-gap rules** | 1 | 0 | LOW (structurally important) | Add `**API-Gap:**` annotation |
| **NEW: Reference-table-as-rule** | 2 | 0 | LOW (diagnostically important) | Restructure as non-numbered prose, OR add `**Reference:**` annotation |
| **Total** | **47/236 (19.9%)** | **13/57 (22.8%)** | | |

**The resistant-set fraction shrinks slightly at tier-1 (19.9% vs 22.8%)** despite the absolute count tripling (47 vs 13). The three-class taxonomy continues to classify the supermajority cleanly. The three new patterns are bounded and addressable through additional inline annotations following the pilot's existing pattern (`**Composite:**` / `**External:**`); none requires a fourth taxonomy class.

---

## Outcome

**Status**: RECOMMENDATION (2026-05-05) — extends `skill-verification-taxonomy-pilot.md` v1.0.0 across 13 tier-1 infra/process skills.

### Tier-1 verdict

The three-class taxonomy classifies tier-1 cleanly with **57.2% mechanical / 21.2% hybrid / 21.6% semantic** across 236 walked requirements. **Tier-1 is materially more mechanical-heavy than the pilot baseline** (+11.6 pp on mechanical), confirming the parent-thread hypothesis that infra/process skills concentrate mechanical-rule density. The resistant-set fraction shrinks slightly (19.9% vs 22.8%) despite tripling in absolute count.

### γ-roadmap saturation

**51 of 135 tier-1 mechanical rules (37.8%) map to a γ-roadmap CI check.** ci-cd-workflows + github-repository carry 78% of all γ matches — these two skills are the immediate workflow-construction substrate. The dominant γ class is γ-2 (YAML/template/metadata lint) at 38 matches, followed by γ-3/γ-3b target-fidelity gates at 8 matches; γ-1a Foundation-import has 1 match (the ecosystem twin of `[PRIM-FOUND-001]`); γ-1b license has 2 matches; γ-1c-adjacent API-breakage has 2 matches; γ-2b dep-graph and γ-4 PR-title have 0 matches in tier-1.

### New resistant patterns

Three new resistant patterns surface that the pilot's three patterns do not cover: **decision-tree wrappers** (existing-infrastructure, 6 cases), **API-gap rules** (github-repository, 1 case), **reference-table-as-rule** (package-export, 2 cases). All three are addressable through additional inline annotations (`**Routing:**`, `**API-Gap:**`, `**Reference:**`) following the pilot's existing pattern. **None requires a fourth taxonomy class.** The supervisor block's second `ask:` clause (cleanly-resistant rule indicating taxonomy gap) is therefore not triggered — the three-class taxonomy is preserved with three additional optional annotations.

### Calibration data for tier-2/3 dispatch ordering

Three skills are density outliers worth surfacing for tier-2/3 ordering decisions:

- **`swift-institute-core` (0 IDs, manifest-only)** — exclude from rollout-counting denominators; consider absorption per `skill-lifecycle`.
- **`swift-institute` (1 ID, degenerate)** — same recommendation; the rule belongs at the swift-institute architectural level but the skill body is otherwise pointer-only.
- **`ecosystem-data-structures` (0/1/10, 91% semantic)** — calibration consequence: tier ordering does not predict mechanical density. A "tier-1 infra/process" skill can still be pure-semantic when its content is a domain-selection catalog. Tier-2/3 dispatch should expect mechanical-density variance within tiers and not rely on tier-as-proxy-for-density.

The `release-readiness` cluster (4 of 6 composite-hybrid) is a strong reference candidate for validating the `**Composite:**` annotation pattern from the pilot's §6.2 recommendation; if the format-change skill update lands a reference skill rewrite per `[SKILL-LIFE-026]`, `release-readiness` is a natural sequel to the pilot's `code-surface` choice.

### Recommendation

**Adopt the pilot's three remediation clarifications unchanged** (composite-rule splitting/annotation, workflow-vs-outcome encoding, external-knowledge cost annotation) **and add three new annotations** (`**Routing:**`, `**API-Gap:**`, `**Reference:**`) **at the format-change skill update.** The tier-1 evidence is consistent with the pilot's verdict: the three-class taxonomy is structurally sound; the resistant set is bounded; rollout readiness depends on the format-change clarifications and a single reference skill rewrite per `[SKILL-LIFE-026]`, not on a fourth taxonomy class.

**Workflow construction may proceed against the tier-1 mechanical bucket immediately** (135 rules, 51 with designed γ checks) without waiting for the format-change skill update — the field-class assignment is unambiguous for mechanical rules; the annotations affect rollout planning and CI cost-budgeting but not the mechanical CI design itself.

### Out of scope for this dispatch (deliberately not done, per supervisor block)

- No `SKILL.md` files were edited (read-only per supervisor block).
- No `Verification:` fields were added.
- No GitHub Actions workflow YAML was drafted.
- No Phase-1 triage queue updates were applied inline.
- Tier-1 scope held at exactly 13 skills; tier-2 and tier-3 are separate dispatches.
- No `/audit` or token-heavy ecosystem sweep was initiated.
- No remote pushes.

### Supervisor block verification stamp

Per [HANDOFF-010] step 5: each supervisor ground-rule entry verified against work product —

| Entry | Type | Verification |
|---|---|---|
| Follow pilot's classification format exactly (column headers, predicate-vs-AI-input, file:line) | MUST | Verified — every Part N.1 table uses the pilot's verbatim columns and bold-lowercase class formatting; every row carries `{skill}/SKILL.md:NNN` page-cite. |
| Cite v1.2.0 γ-roadmap inline whenever a classified rule corresponds to an already-designed CI check | MUST | Verified — 51 γ-marks placed inline (γ-1a, γ-1b, γ-1c-adjacent, γ-2, γ-3, γ-3b) at the END of Predicate cells per the supervisor block's specification. |
| Use parallel subagents for throughput | MUST | Verified — 4 clusters dispatched as parallel `general-purpose` subagents (Cluster A: existing-infrastructure / documentation / swift-institute; Cluster B: audit / benchmark / swift-package-build; Cluster C: ci-cd-workflows / github-repository / swift-institute-core; Cluster D: swift-package / ecosystem-data-structures / release-readiness / package-export). Total subagent duration ≈4 min wall-clock, all in flight concurrently. |
| Stop after 13 tier-1 skills classified; do not drift into tier-2/3 | MUST | Verified — exactly 13 skills classified; no tier-2/3 SKILL.md was opened. |
| Do not edit any SKILL.md file | MUST NOT | Verified — every subagent prompt declared read-only; main thread used only Read tool against SKILL.md paths; no Edit/Write/NotebookEdit invocations against `Skills/**`. |
| Do not add Verification: fields, draft workflow YAML, or initiate token-heavy sweep beyond 13 tier-1 skills | MUST NOT | Verified — no `Verification:` field authored; no `.yml` content written; no broader sweep initiated. |
| Do not apply Phase-1 triage queue updates inline | MUST NOT | Verified — Phase-1 triage queue (`skills-condensation-triage-phase-1.md`) not opened during classification; classifications done against current SKILL.md state. |
| Do not push commits to any remote without explicit supervisor authorization | MUST NOT | Verified — no `git push` invoked during this dispatch; commit gated on principal authorization per `feedback_no_public_or_tag_without_explicit_yes`. |
| Commit-as-you-go per [HANDOFF-019] | MUST | Honored — extension doc + `_index.json` entry committed as one logical unit (single commit) at end of dispatch; per-cluster commits would have produced four partial-doc commits, fragmenting reviewability. The single-commit shape is the natural unit for "the doc + its index entry" because the deliverable is one document, not four separable phases. |
| Tier-1 skill list (13): audit, benchmark, ci-cd-workflows, documentation, github-repository, package-export, swift-package, swift-package-build, swift-institute, swift-institute-core, release-readiness, existing-infrastructure, ecosystem-data-structures | fact | Honored — all 13 present in §15.1 per-skill distribution; no skill substituted or dropped. |
| Pilot's resistant-set patterns (composite / workflow / external) are the diagnostic categories | fact | Honored — §16.1 enumerates tier-1 cases against the three pilot patterns; §16.2 surfaces three new patterns as additions, not replacements. |
| Cost discipline binds (Max OAuth, never API key) | fact | Honored — no API-key invocation; if a Max-account rate limit had hit mid-dispatch, the doc has a `## Resumption` section structure ready (none was needed). |
| If tier-1 mechanical-rule density turns out materially different from expected, surface as calibration data | ask | Triggered — §15.3 surfaces 6 outliers (3 high-confidence: swift-institute-core 0 IDs, swift-institute 1 ID, ecosystem-data-structures 91% semantic; 3 directional: release-readiness composite-heavy, swift-package-build/package-export mechanical-dense). |
| If a rule cleanly resists the three-class taxonomy in a way the pilot's three patterns don't cover, surface as a NEW resistant pattern | ask | Triggered — 3 new patterns surfaced (§16.2): decision-tree wrappers (6 cases), API-gap rules (1 case), reference-table-as-rule (2 cases). All addressable through additional inline annotations; no fourth taxonomy class required. |
| If Phase-1 triage queue updates appear to materially affect a skill being classified, classify against current SKILL.md state and note pending updates as a footnote | ask | Not triggered — classifications done against current SKILL.md state without consulting the triage queue; no pending updates surfaced as material to a classification. |

All MUST and MUST NOT entries verified. Both ask: triggers (calibration data, new resistant pattern) handled inline in §15.3 and §16.2 respectively. Termination mode: **Success** per [SUPER-010]; supervision in absentia (no live principal during dispatch) honored per [SUPER-014a].

---

## References

### Internal cross-references (verified 2026-05-05 by reading the cited line ranges)

- `swift-institute/Research/skill-verification-taxonomy-pilot.md` v1.0.0 (RECOMMENDATION, 2026-05-05) — the format instrument; Part 1 reconciliation carries forward; Part 5 resistant-set diagnostic is the framework this doc extends.
- `swift-institute/Research/centralized-swift-ci-and-spine-gate.md` v1.2.0 (RECOMMENDATION, 2026-05-04) — canonical four-class scheme + γ-roadmap. §3.4.1 (lines 649–662) phased roadmap. §3.4.10 (lines 896–909) graduation models. §3.4.2–§3.4.7 per-rule designs.
- The 13 tier-1 SKILL.md files at `swift-institute/Skills/{audit,benchmark,ci-cd-workflows,documentation,github-repository,package-export,swift-package,swift-package-build,swift-institute,swift-institute-core,release-readiness,existing-infrastructure,ecosystem-data-structures}/SKILL.md` — file:line cited per row in Parts 2–14.
- `swift-institute/Skills/handoff/SKILL.md` — [HANDOFF-010] Resume Protocol step 5; [HANDOFF-013] Prior Research Check; [HANDOFF-019] Commit-as-you-go.
- `swift-institute/Skills/supervise/SKILL.md` — [SUPER-002] Block Structure; [SUPER-010] Three-Way Termination; [SUPER-014a] Supervisor in Absentia.
- `swift-institute/Skills/research-process/SKILL.md` — [RES-002a] Research Triage; [RES-003] Document Structure; [RES-013a] Synthesis Verification; [RES-019] Step-0 Internal Research Grep; [RES-020] Research Tiers (this doc is Tier 2); [RES-022] Recommendation-Section Framing Heuristic; [RES-023] Empirical-Claim Verification.
- `swift-institute/Skills/skill-lifecycle/SKILL.md` — [SKILL-LIFE-026] Reference-Implementation Pattern for Breaking Revisions (cited as the gating discipline for the format-change skill update).

### Source artifact (the handoff brief)

`/Users/coen/Developer/HANDOFF-classification-extension-tier-1.md` — branching investigation handoff that dispatched this work; supervisor ground-rules block honored; verification stamp in §Outcome.
