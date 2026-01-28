# Research

<!--
---
title: Research
version: 1.1.0
last_updated: 2026-01-22
applies_to: [swift-primitives, swift-institute, swift-standards, swift-foundations]
normative: true
llm_optimized: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Foundation infrastructure for creating research documents—Markdown files that analyze design decisions, explore architectural trade-offs, and document reasoning for future reference.

## Overview

This document defines the shared infrastructure for *research documents*—Markdown files in dedicated `Research/` directories that analyze design questions, explore trade-offs, and document architectural reasoning. Research is git-tracked, preserving institutional knowledge for collaboration and historical reference.

### Document Family

This is the **foundation document** for research documents. Two companion documents define specific workflows:

| Document | Purpose | Entry Point |
|----------|---------|-------------|
| Research.md | Shared infrastructure (this document) | — |
| [Research Investigation](Research%20Investigation.md) | Reactive workflow | Design question arose during implementation |
| [Research Discovery](Research%20Discovery.md) | Proactive workflow | Audit design decisions, explore alternatives |

**Routing guidance**:
 Start with [Research Investigation](Research%20Investigation.md)
 Start with [Research Discovery](Research%20Discovery.md)
- Both workflows use the infrastructure defined here

### Normative Precedence

Research.md is canonical for shared infrastructure. The workflow documents (Investigation, Discovery) may restate rules for context but MUST NOT diverge. If conflict exists, this document governs.

### Rule Numbering Scheme

Rule IDs are partitioned across the document family:

| Document | Reserved Range | Focus |
|----------|---------------|-------|
| Research (this document) | RES-002 – RES-010 | Shared infrastructure |
| Research Investigation | RES-001, RES-004, RES-011 | Reactive triggers and methodology |
| Research Discovery | RES-012 – RES-017 | Proactive triggers and methodology |

Future rules MUST use IDs from the appropriate range. Do not reassign existing IDs.

### Research vs Experiment

Before creating a research document, determine whether an experiment is more appropriate. Use experiments for verifying Swift compiler/language capabilities. Use research for analyzing design decisions and trade-offs.

**Decision tree**:

```text
What are you analyzing?
 Experiment
 Experiment
 Experiment
 Research
 Research
 Research
 Research
```

**Examples**:

| Scenario | Choice | Reason |
|----------|--------|--------|
| "Does ~Copyable work with typed throws?" | Experiment | Verifying compiler behavior |
| "Should we use Nest.Name or CompoundName?" | Research | Analyzing naming conventions |
| "Is O(log n) acceptable for this operation?" | Research | Analyzing design trade-offs |
| "Does InlineArray have less overhead?" | Experiment | Measuring runtime behavior |
| "Which error handling pattern fits best?" | Research | Analyzing patterns |
| "Can we use value generics here?" | Experiment | Verifying compiler support |

**Key differences**:

| Aspect | Research | Experiment |
|--------|----------|------------|
| Format | Markdown document | Swift package |
| Subject | Design decisions | Compiler/runtime behavior |
| Output | Analysis and recommendations | Empirical results |
| Execution | Reading and reasoning | Code compilation/execution |
| Outcome | DECISION / RECOMMENDATION / DEFERRED | CONFIRMED / REFUTED |
| Lifecycle | Living document, updated as context changes | Point-in-time verification |

See [Experiment](../Experiments/Experiment.md) for experiment infrastructure.

---

## [RES-002] Document Location Convention

**Scope**: File system location for research documents.

**Statement**: Research documents MUST be created in a `Research/` directory with a descriptive, kebab-case filename indicating the topic being analyzed. The location depends on the research's scope (see [RES-002a]).

### Research Directory Locations

| Scope | Location Pattern | Example |
|-------|------------------|---------|
| Package-specific | `{package-repo}/Research/` | `swift-heap-primitives/Research/` |
| Primitives-wide | `swift-primitives/.../docc/Research/` | Cross-package primitives design |
| Ecosystem-wide | `swift-institute/.../docc/Research/` | Cross-layer design analysis |

**Correct**:
```text
swift-heap-primitives/Research/heap-storage-variants.md
swift-primitives/.../Research/index-type-hierarchy.md
swift-institute/.../Research/noncopyable-api-patterns.md
```

**Incorrect**:
```text
/tmp/design-notes.md               ❌ Ephemeral—lost on reboot
~/Developer/notes/                 ❌ Not in Research/—pollutes workspace
Research/notes.md                  ❌ Non-descriptive—cannot identify later
Research/MyAnalysis.md             ❌ Not kebab-case—inconsistent naming
```

**Rationale**: Research documents have lasting value. Placing them in dedicated `Research/` directories preserves this value while keeping them organized.

**Cross-references**: [RES-002a], [RES-008]

---

## [RES-002a] Research Triage

**Scope**: Deciding where to place a research document.

**Statement**: Before creating a research document, determine whether it is package-specific, primitives-wide, or ecosystem-wide. This decision determines the document's location.

### Triage Decision Tree

```text
Is this research about design decisions specific to one package?
 Place in {package-repo}/Research/
│        Examples:
│        • Analyzing swift-heap-primitives' storage strategy
│        • Deciding swift-rfc-4122's error type hierarchy
│
 Is it about primitives-wide patterns?
 Place in swift-primitives/.../Research/
        │        Examples:
        │        • Index type design across all collections
        │        • Storage variant naming conventions
        │
 Place in swift-institute/.../Research/
                Examples:
                • Cross-layer API consistency
                • Naming convention analysis
                • Design philosophy documentation
```

### Decision Criteria

| Criterion | Package-Specific | Primitives-Wide | Ecosystem-Wide |
|-----------|------------------|-----------------|----------------|
| Involves one package's types | ✓ | | |
| Affects multiple primitives packages | | ✓ | |
| Affects packages across layers | | | ✓ |
| General design philosophy | | | ✓ |
| Implementation strategy for one API | ✓ | | |
| Pattern applicable to all collections | | ✓ | |

**Correct**:
```text
Question: "How should Heap storage variants be named?"
Decision: Affects only swift-heap-primitives
Location: swift-heap-primitives/Research/heap-storage-naming.md
```

**Incorrect**:
```text
Question: "How should Heap storage variants be named?"
Decision: Put in swift-institute  ❌ Package-specific decision in ecosystem location
```

**Rationale**: Proper triage ensures research is discoverable by developers working in the relevant context.

**Cross-references**: [RES-002], [RES-006a]

---

## [RES-003] Document Structure

**Scope**: Required sections and format for research documents.

**Statement**: Research documents MUST contain the minimum structure required to analyze the design question and SHOULD follow a consistent format.

### Required Sections

| Section | Purpose | Required |
|---------|---------|----------|
| Title | Document name matching filename | MUST |
| Metadata | Version, date, status | MUST |
| Context | Why this research exists | MUST |
| Question | The specific design question | MUST |
| Analysis | Trade-off exploration | MUST |
| Outcome | Decision or recommendation | MUST |
| References | Related documents, experiments | SHOULD |

### Document Template

```markdown
# {Topic Title}

<!--
---
version: 1.0.0
last_updated: YYYY-MM-DD
status: DECISION | RECOMMENDATION | DEFERRED | IN_PROGRESS
---
-->

## Context

{Why this research is needed. What prompted the question.}

## Question

{The specific design question being analyzed.}

## Analysis

### Option A: {Name}

{Description, pros, cons}

### Option B: {Name}

{Description, pros, cons}

### Comparison

| Criterion | Option A | Option B |
|-----------|----------|----------|
| ... | ... | ... |

## Outcome

**Status**: {DECISION | RECOMMENDATION | DEFERRED}

{The conclusion and rationale}

## References

- {Related documents}
- {Related experiments}
```

Research documents MAY reference other research documents in the References section. When conclusions build upon prior research, the dependency SHOULD be stated explicitly in the Context section.

**Rationale**: Structured documents enable systematic analysis and future reference.

**Cross-references**: [RES-003a], [RES-003b]

---

## [RES-003a] Metadata Requirements

**Scope**: Required metadata for research documents.

**Statement**: Research documents MUST include metadata specifying version, last update date, and current status.

### Status Values

| Status | Meaning |
|--------|---------|
| IN_PROGRESS | Analysis ongoing, not yet concluded |
| DECISION | Analysis complete, decision made and implemented |
| RECOMMENDATION | Analysis complete, recommendation made but not yet implemented |
| DEFERRED | Analysis complete, decision deferred pending future information |
| SUPERSEDED | Document obsolete, replaced by newer research |

**Correct**:
```markdown
<!--
---
version: 1.0.0
last_updated: 2026-01-22
status: DECISION
---
-->
```

**Incorrect**:
```markdown
<!-- Last updated sometime in January -->  ❌ No version, no status
<!-- Updated recently -->                   ❌ Vague date
```

**Rationale**: Metadata enables tracking of research status and identifying stale analysis.

**Cross-references**: [RES-003], [RES-008]

---

## [RES-003b] Naming Alignment

**Scope**: Consistency between filename and document title.

**Statement**: The research document filename and title MUST be aligned. The filename uses kebab-case; the title uses natural language.

**Correct**:
```text
Filename: heap-storage-variants.md
Title: # Heap Storage Variants
```

**Incorrect**:
```text
Filename: heap-storage-variants.md
Title: # Some Design Notes  ❌ Doesn't match filename
```

**Rationale**: Naming alignment eliminates confusion when navigating research directories.

**Cross-references**: [RES-002], [RES-003]

---

## [RES-003c] Research Index

**Scope**: Discoverability of research within a repository.

**Statement**: If `Research/` contains two or more research documents, `Research/_index.md` MUST exist. If `Research/` contains exactly one document, `_index.md` SHOULD exist. `_index.md` is the only allowed non-research file under `Research/`.

### Index Format

The index MUST contain a table with these minimum fields:

| Field | Description |
|-------|-------------|
| Document | Research document filename |
| Topic | One-line description |
| Date | Date last updated |
| Status | DECISION / RECOMMENDATION / DEFERRED / IN_PROGRESS / SUPERSEDED |

**Correct**:
```markdown
# Research Index

| Document | Topic | Date | Status |
|----------|-------|------|--------|
| heap-storage-variants.md | Storage strategy analysis | 2026-01-20 | DECISION |
| heap-error-handling.md | Error type hierarchy design | 2026-01-22 | IN_PROGRESS |
```

**Incorrect**:
```text
Research/
├── README.md                      ❌ Wrong filename—use _index.md
├── heap-storage-variants.md
└── heap-error-handling.md
```

```markdown
# Research

- Some docs about stuff           ❌ No table, no status tracking
```

**Rationale**: As research accumulates, discoverability degrades without an index.

**Cross-references**: [RES-002], [RES-008]

---

## [RES-004b] Scope Escalation

**Scope**: Handling scope changes discovered during research.

**Statement**: If analysis reveals implications beyond the original scope:
 MUST recommend or transition to Discovery
 MAY spawn a targeted Investigation

The originating document MUST record the escalation with explicit cross-reference to any spawned or superseding research.

**Correct**:
```text
Original: Research/heap-storage-naming.md (Investigation)
Finding: Storage naming inconsistency affects all collection primitives
Action: Recommend Discovery research, link created
Note in Outcome: "Escalated to Discovery: Research/storage-variant-consistency.md"
```

**Incorrect**:
```text
Original: Research/heap-storage-naming.md (Investigation)
Finding: This affects Stack and Queue too
Action: Silently expand scope without recording  ❌
```

**Rationale**: Explicit escalation preserves traceability and prevents silent scope drift.

**Cross-references**: [RES-002a], [RES-012]

---

## [RES-005] Analysis Methodology

**Scope**: Process for analyzing design questions.

**Statement**: Research analysis MUST be systematic, documenting options, trade-offs, and criteria for evaluation.

### Analysis Components

| Component | Purpose | Required |
|-----------|---------|----------|
| Options enumeration | List all viable alternatives | MUST |
| Criteria identification | Define evaluation dimensions | MUST |
| Trade-off analysis | Compare options against criteria | MUST |
| Constraints documentation | Note any limiting factors | SHOULD |
| Prior art review | Reference existing patterns | SHOULD |

### Option Documentation Template

```markdown
### Option {N}: {Name}

**Description**: {What this option entails}

**Advantages**:
- {Pro 1}
- {Pro 2}

**Disadvantages**:
- {Con 1}
- {Con 2}

**Constraints**: {Any limitations or requirements}
```

### Comparison Table Template

```markdown
### Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Consistency with conventions | ✓ | ✗ | ✓ |
| Implementation complexity | Low | High | Medium |
| API ergonomics | Good | Poor | Good |
| Performance implications | None | Regression | None |
```

**Rationale**: Systematic analysis ensures all options are considered and decisions are justified.

**Cross-references**: [RES-006]

---

## [RES-006] Outcome Documentation

**Scope**: Recording research conclusions.

**Statement**: Research outcomes MUST be documented with clear status, rationale, and any implementation notes.

### Outcome Categories

| Outcome | Action |
|---------|--------|
| DECISION | Document choice, rationale, and implementation path |
| RECOMMENDATION | Document recommendation with caveats, await implementation |
| DEFERRED | Document why deferred, what would resolve it |
| IN_PROGRESS | Document current state, next steps |

### Outcome Documentation Template

```markdown
## Outcome

**Status**: DECISION

**Choice**: Option B

**Rationale**:
{Why this option was selected over alternatives}

**Implementation Notes**:
{Any guidance for implementing the decision}

**Date**: 2026-01-22
```

**Rationale**: Clear outcome documentation enables future reference and ensures decisions are actionable.

**Cross-references**: [RES-006a], [RES-003]

---

## [RES-006a] Documentation Promotion

**Scope**: Elevating significant findings to authoritative documentation.

**Statement**: When research results establish conventions or patterns, findings SHOULD be promoted to the relevant authoritative documentation.

### Promotion Criteria

| Criterion | Action |
|----------|--------|
| Establishes new convention | Promote to API Naming.md or similar |
| Documents pattern | Promote to Implementation Patterns.md |
| Reveals constraint | Promote to relevant requirements doc |
| One-time decision | Keep in Research only |

**Correct**:
```text
Research outcome: "Nest.Name pattern applies to all primitives"
Action: Add to API Naming.md [API-NAME-001]

Research outcome: "Heap should use array storage"
Action: Keep in heap-storage-variants.md only (package-specific)
```

### Promotion Recording

When findings are promoted to authoritative documentation, the originating research document SHOULD be updated:

**Correct**:
```markdown
## Outcome

**Status**: DECISION

**Choice**: Phantom generic Index<Element>

**Promoted**: Findings incorporated into API Design.md [API-DESIGN-XXX] on 2026-01-22.
This document remains the authoritative source for alternatives considered.
```

The outcome status (DECISION, RECOMMENDATION) remains unchanged. Promotion is elevation, not invalidation.

**Rationale**: Research that establishes patterns should be discoverable through authoritative docs.

**Cross-references**: [RES-006], [API-NAME-001]

---

## [RES-007] Context Documentation

**Scope**: Recording the context that prompted research.

**Statement**: Research documents MUST record the context that prompted the analysis, including what triggered the question and any constraints.

### Context Components

| Component | Purpose |
|-----------|---------|
| Trigger | What prompted this research |
| Constraints | Any fixed requirements or limitations |
| Timeline | Any deadlines or dependencies |
| Stakeholders | Who is affected by this decision |

**Correct**:
```markdown
## Context

While implementing `swift-heap-primitives`, the question arose of how to organize
storage variants (Inline, Bounded, Unbounded). This affects API surface,
documentation structure, and user mental model.

**Trigger**: PR #42 discussion on storage naming
**Constraints**: Must maintain backward compatibility with v1.0 API
```

**Incorrect**:
```markdown
## Context

We need to decide something about storage.  ❌ No trigger, no constraints, no specifics
```

**Rationale**: Context enables future readers to understand why the research was conducted.

**Cross-references**: [RES-003]

---

## [RES-008] Research Document Lifecycle

**Scope**: Managing research documents over time.

**Statement**: Research documents are persistent and git-tracked. They serve as a living reference for design rationale.

### Lifecycle Stages

| Stage | Duration | Action |
|-------|----------|--------|
| Active | During analysis | Iterate on analysis, gather input |
| Concluded | After decision | Finalize with outcome, commit |
| Referenced | Ongoing | Available for future reference |
| Updated | When context changes | Revise analysis, increment version |
| Superseded | When replaced | Add SUPERSEDED status, link to replacement |

### Version Management

When updating concluded research:

1. Increment version number
2. Update `last_updated` date
3. Add changelog entry if significant
4. Preserve original analysis (annotate as outdated if needed)

**Correct**:
```markdown
<!--
---
version: 2.0.0
last_updated: 2026-01-22
status: DECISION
---
-->

## Changelog

- v2.0.0 (2026-01-22): Revised analysis based on Swift 6.2 capabilities
- v1.0.0 (2026-01-10): Initial analysis
```

**Incorrect**:
```markdown
<!--
---
version: 1.0.0
last_updated: 2026-01-10
status: DECISION
---
-->

<!-- Content completely rewritten but version not updated -->  ❌ Stale metadata
```

**Rationale**: Research documents capture decision-making context. Preserving history enables understanding why decisions were made.

**Cross-references**: [RES-002], [RES-003a]

---

## [RES-009] Multi-Option Analysis

**Scope**: Analyzing multiple related design options.

**Statement**: When analyzing multiple related options, all viable alternatives MUST be documented with consistent structure enabling comparison.

**Correct**:
```markdown
## Analysis

### Option 1: Nested Types

**Approach**: `Heap.Inline`, `Heap.Bounded`, `Heap.Unbounded`

**Advantages**:
- Clear namespace hierarchy
- Matches Swift Institute conventions

**Disadvantages**:
- Longer type names

### Option 2: Suffix Convention

**Approach**: `InlineHeap`, `BoundedHeap`, `UnboundedHeap`

**Advantages**:
- Shorter names

**Disadvantages**:
- Violates [API-NAME-001] compound name prohibition

### Comparison

| Criterion | Nested Types | Suffix |
|-----------|--------------|--------|
| Convention compliance | ✓ | ✗ |
| Discoverability | High | Medium |
```

**Incorrect**:
```markdown
## Analysis

We should use nested types because they're better.  ❌ No options enumerated
Option 2 is bad.                                     ❌ No structured comparison
```

**Rationale**: Consistent structure for all options enables fair comparison and documents why alternatives were rejected.

**Cross-references**: [RES-005], [RES-006]

---

## [RES-010] Common Research Patterns

**Scope**: Templates for frequently needed research types.

**Statement**: Research documents SHOULD follow established templates for common analysis types.

**Cross-references**: [RES-003], [RES-005]

---

### [RES-010a] Naming Analysis

**Scope**: Analyzing naming alternatives for types, methods, or properties.

**Template**:
```markdown
# {Type/Method/Property} Naming

## Context
{What needs to be named and why this is non-obvious}

## Question
What should {thing} be named?

## Analysis

### Option A: {CandidateName}
**Rationale**: {Why this name might be appropriate}
**Precedent**: {Existing usage in Swift ecosystem}
**Conflicts**: {Any naming conflicts}

### Option B: {CandidateName}
...

### Comparison
| Criterion | Option A | Option B |
|-----------|----------|----------|
| Matches specification terminology | | |
| Consistent with existing APIs | | |
| Avoids Foundation conflicts | | |

## Outcome
**Choice**: {Selected name}
**Rationale**: {Why this name was selected}
```

---

### [RES-010b] Architecture Analysis

**Scope**: Analyzing architectural alternatives.

**Template**:
```markdown
# {Component} Architecture

## Context
{What architectural decision needs to be made}

## Question
How should {component} be architected?

## Analysis

### Option A: {Architecture Name}
**Structure**: {Description}
**Complexity**: {Low/Medium/High}
**Performance**: {Analysis}
**Maintainability**: {Analysis}

### Option B: {Architecture Name}
...

### Comparison
| Criterion | Option A | Option B |
|-----------|----------|----------|
| Complexity | | |
| Performance | | |
| Extensibility | | |

## Outcome
**Choice**: {Selected architecture}
**Rationale**: {Why selected}
```

---

### [RES-010c] Trade-off Analysis

**Scope**: Analyzing trade-offs between competing concerns.

**Template**:
```markdown
# {Trade-off Topic}

## Context
{What competing concerns exist}

## Question
How should we balance {concern A} against {concern B}?

## Analysis

### Concern A: {Name}
**Importance**: {Critical/High/Medium/Low}
**Impact of prioritizing**: {What happens}

### Concern B: {Name}
**Importance**: {Critical/High/Medium/Low}
**Impact of prioritizing**: {What happens}

### Trade-off Matrix
| Approach | Concern A | Concern B | Overall |
|----------|-----------|-----------|---------|
| Prioritize A | ✓✓ | ✗ | |
| Prioritize B | ✗ | ✓✓ | |
| Balance | ✓ | ✓ | |

## Outcome
**Approach**: {Selected balance point}
**Rationale**: {Why selected}
```

---

## Research Rigor Extensions (Tiered)

**Scope**: Academic-level research methodology for high-impact decisions.

**Statement**: Research rigor scales with decision impact. Three tiers distinguish quick package decisions from foundational ecosystem commitments.

**Full specification**: See `Research/academic-research-methodology.md`

---

### [RES-020] Research Tiers

**Scope**: Classifying research by required rigor.

**Statement**: Research MUST be classified into one of three tiers based on precedent risk, not scope alone.

| Criterion | Tier 1: Quick | Tier 2: Standard | Tier 3: Deep |
|-----------|---------------|------------------|--------------|
| Scope | Package-specific | Cross-package | Ecosystem-wide |
| Precedent-setting | No | No or reversible | Yes, hard to undo |
| Semantic commitment | None | Informal | Normative / foundational |
| Cost of error | Low | Medium | Very high |
| Expected lifetime | Single release | Several releases | "Timeless infrastructure" |
| Formalization | Not required | Optional | Mandatory |

**Tier 3 threshold**: Tier 3 research MUST be used when a decision establishes a long-lived semantic contract or conceptual foundation that future APIs, conventions, or language-facing abstractions will depend on. Ecosystem-wide scope alone does not mandate Tier 3.

**Tier 3 is exceptional**: The default assumption is that a decision does not require Tier 3 unless explicitly justified. Expect very few Tier 3 decisions per year.

**Cross-references**: [RES-002a], [RES-004b]

---

### [RES-021] Prior Art Survey

**Scope**: Required external research for Tier 2+ decisions.

**Statement**: Tier 2+ research MUST include a Prior Art Survey section documenting relevant work from Swift Evolution, related languages, and academic literature.

**Required sources**:

| Source | Coverage |
|--------|----------|
| Swift Evolution | SE proposals, forum discussions |
| Related languages | Rust RFCs, Haskell GHC proposals, OCaml |
| Academic literature | arXiv, ACM DL, POPL/ICFP/OOPSLA |

**Cross-references**: [RES-005], [RES-022]

---

### [RES-022] Theoretical Grounding

**Scope**: Formal foundations for Tier 2+ decisions.

**Statement**: Tier 2+ research SHOULD include theoretical grounding in type theory, category theory, or other relevant formal frameworks when it improves precision.

**Applicable frameworks**:

| Framework | Application |
|-----------|-------------|
| Type theory | Linear/affine types, dependent types, session types |
| Category theory | Functors, monads, adjunctions, universal properties |
| Operational semantics | Reduction rules, evaluation order |
| Denotational semantics | Mathematical meaning of programs |

**Cross-references**: [RES-023], [RES-024]

---

### [RES-023] Systematic Literature Review

**Scope**: Full SLR methodology for Tier 3 decisions.

**Statement**: Tier 3 research MUST include a Systematic Literature Review following Kitchenham methodology: defined research questions, explicit search strategy, inclusion/exclusion criteria, and synthesized findings.

**Required sections**:

1. Research questions (RQ1, RQ2, ...)
2. Search strategy (databases, keywords, date range)
3. Inclusion/exclusion criteria
4. Search results with screening
5. Data extraction table
6. Synthesis of findings

**Cross-references**: [RES-021], [RES-024]

---

### [RES-024] Formal Semantics

**Scope**: Mandatory formalization for Tier 3 decisions.

**Statement**: Tier 3 research MUST include formal semantics with typing rules, operational semantics, and soundness arguments as appropriate.

**Notation policy**:

| Tier | Main body | Appendices |
|------|-----------|------------|
| Tier 1 | Prose only | None |
| Tier 2 | Light formalism, explained | Optional |
| Tier 3 | Formal definitions inline | Extended proofs |

Formal notation MAY be used in Tier 2 research when it improves precision. Formal notation MUST be used in Tier 3 research, with primary definitions in the main text and extended derivations or proofs in appendices.

**Cross-references**: [RES-022], [RES-023]

---

### [RES-025] Empirical Validation

**Scope**: Evidence-based evaluation for API decisions.

**Statement**: Tier 2+ research for API-facing decisions SHOULD include empirical validation using the Cognitive Dimensions Framework or comparable methodology.

**Cognitive Dimensions**:

| Dimension | Question |
|-----------|----------|
| Visibility | Can users find the API they need? |
| Consistency | Do similar things work similarly? |
| Viscosity | How hard is it to make changes? |
| Role-expressiveness | Is the purpose of each element clear? |
| Error-proneness | Does the API guide correct usage? |
| Abstraction | Is the level of abstraction appropriate? |

**Cross-references**: [RES-005], [RES-009]

---

### [RES-026] Reference Library

**Scope**: Centralized bibliography for academic traceability.

**Statement**: The `References/` directory MUST contain discipline-partitioned `.bib` files for canonical citation metadata.

**Structure**:

```
swift-institute/References/
├── swift-evolution.bib
├── programming-languages.bib
├── type-theory.bib
├── category-theory.bib
├── api-usability.bib
└── methodology.bib
```

**Rules**:
- Tier 2+ research SHOULD reference entries from `References/`
- Tier 3 research MUST include a References section traceable to `.bib` entries
- Citations may be informal Markdown links, but canonical metadata lives in `.bib`

**Cross-references**: [RES-003], [RES-021]

---

## Topics

### Workflow Documents

- [Research Investigation](Research%20Investigation.md) — Reactive workflow for design questions
- [Research Discovery](Research%20Discovery.md) — Proactive workflow for design audits

### Related Documents

- [Experiment](../Experiments/Experiment.md) — Infrastructure for code verification experiments
- [Design](../Documentation.docc/Implementation/Design.md) — API design rules and patterns
- [Documentation Standards](../Documentation.docc/Documentation%20Standards.md) — Documentation standards

### Cross-Reference Index

| ID | Title | Focus |
|----|-------|-------|
| RES-002 | Document Location Convention | Where to create |
| RES-002a | Research Triage | Package vs primitives vs ecosystem scope |
| RES-003 | Document Structure | Required sections |
| RES-003a | Metadata Requirements | Version, date, status |
| RES-003b | Naming Alignment | Filename and title consistency |
| RES-003c | Research Index | Discoverability via _index.md |
| RES-004b | Scope Escalation | Handling scope changes |
| RES-005 | Analysis Methodology | Systematic analysis |
| RES-006 | Outcome Documentation | Recording conclusions |
| RES-006a | Documentation Promotion | Elevating findings |
| RES-007 | Context Documentation | Recording triggers |
| RES-008 | Research Document Lifecycle | Document management |
| RES-009 | Multi-Option Analysis | Comparing alternatives |
| RES-010 | Common Research Patterns | Templates |
| RES-010a | Naming Analysis | Naming decisions |
| RES-010b | Architecture Analysis | Architecture decisions |
| RES-010c | Trade-off Analysis | Balancing concerns |
| RES-020 | Research Tiers | Three-tier rigor system |
| RES-021 | Prior Art Survey | External research for Tier 2+ |
| RES-022 | Theoretical Grounding | Formal foundations |
| RES-023 | Systematic Literature Review | Full SLR for Tier 3 |
| RES-024 | Formal Semantics | Typing rules, soundness |
| RES-025 | Empirical Validation | Cognitive dimensions |
| RES-026 | Reference Library | Centralized bibliography |

