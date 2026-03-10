<!--
---
version: 1.1.0
last_updated: 2026-03-10
status: SUPERSEDED
---
-->

# Academic Research Methodology

## Context

The current Research system provides a solid foundation for documenting design decisions, but lacks the rigor of academic research. To produce "timeless infrastructure," we need PhD-level analysis that draws on:

- Systematic literature review methodologies
- Category theory and type theory foundations
- Formal semantics and verification
- Empirical API usability research
- Cross-disciplinary comparative analysis

This document proposes enhancements to elevate research quality.

## Question

How should we enhance the Research system to produce PhD-level, academically rigorous design analysis?

---

## Analysis

### Current State Assessment

| Aspect | Current | Academic Standard |
|--------|---------|-------------------|
| Prior art review | Ad-hoc | Systematic Literature Review (SLR) |
| Theoretical foundation | Implicit | Explicit (category theory, type theory) |
| Evidence basis | Intuition | Empirical studies, formal proofs |
| External sources | None | Web search, academic papers, standards |
| Cross-reference | Internal only | Academic citations, Swift Evolution |
| Reproducibility | Not addressed | Verification experiments |

### Option 1: Systematic Literature Review (SLR) Integration

Based on [Kitchenham & Charters (2007)](https://www.researchgate.net/publication/302924724_Guidelines_for_performing_Systematic_Literature_Reviews_in_Software_Engineering), the gold standard for software engineering research.

**Three Phases**:

1. **Planning**: Define research questions, search strategy, inclusion/exclusion criteria
2. **Conducting**: Execute searches, screen results, extract data, synthesize
3. **Reporting**: Document findings with full traceability

**Adapted for Swift Institute**:

```markdown
## Prior Art Survey

### Search Strategy
- **Databases**: Swift Evolution, Swift Forums, arXiv, ACM DL, IEEE Xplore
- **Keywords**: {specific terms}
- **Date range**: {scope}

### Inclusion Criteria
- Directly addresses the design question
- From authoritative source (SE proposal, peer-reviewed, core team)

### Exclusion Criteria
- Opinion without evidence
- Superseded by later work

### Results

| Source | Relevance | Key Finding |
|--------|-----------|-------------|
| SE-0390 | High | Noncopyable types use affine semantics |
| [Paper] | Medium | Linear types enable session types |
```

**Advantages**:
- Reproducible, auditable methodology
- Prevents cherry-picking evidence
- Identifies research gaps

**Disadvantages**:
- Time-intensive for simple decisions
- Overkill for package-specific choices

### Option 2: Theoretical Foundations Framework

Ground design decisions in mathematical and type-theoretic foundations.

**Category Theory Lens**:

| Concept | Application to Swift Institute |
|---------|--------------------------------|
| Functors | Type transformations (map, flatMap) |
| Natural transformations | Protocol conformance preservation |
| Monads | Effect composition (async, throws) |
| Adjoint functors | Free/forgetful constructions |
| Initial/terminal objects | Never, Void semantics |

**Type Theory Lens**:

| Concept | Application |
|---------|-------------|
| Linear types | Exactly-once semantics (~Copyable) |
| Affine types | At-most-once semantics (ownership) |
| Dependent types | Value generics (`let capacity: Int`) |
| Session types | Protocol state machines |
| Substructural types | Resource management |

**Example Analysis**:

```markdown
## Theoretical Foundation

### Category-Theoretic View

The storage variant pattern forms a **coproduct** in the category of Swift types:

```
Storage = Inline + Bounded + Unbounded
```

Each variant is an **injection** into the coproduct. The `switch` statement
is the **universal property** of the coproduct—any function from Storage
must handle all cases.

### Type-Theoretic View

Storage variants with value generics form a **dependent sum type**:

```
Inline : (n : Nat) → Storage n
```

The capacity `n` is a **type index** that the type system tracks statically.
```

**Advantages**:
- Reveals deep structure
- Connects to established mathematics
- Enables formal verification

**Disadvantages**:
- Requires mathematical background
- May not affect implementation choice

### Option 3: Empirical Validation Framework

Based on [API usability research](https://www.semanticscholar.org/paper/An-Empirical-Study-of-API-Usability-Piccioni-Furia/693932c48cb315c373e48fed8ba4e2725fb492a4) methodologies.

**Cognitive Dimensions Framework**:

| Dimension | Question |
|-----------|----------|
| Visibility | Can users find the API they need? |
| Consistency | Do similar things work similarly? |
| Viscosity | How hard is it to make changes? |
| Role-expressiveness | Is the purpose of each element clear? |
| Error-proneness | Does the API guide correct usage? |
| Abstraction | Is the level of abstraction appropriate? |

**Validation Methods**:

| Method | When to Use | Output |
|--------|-------------|--------|
| Heuristic evaluation | Early design | Issue list |
| Cognitive walkthrough | Before finalization | Usage scenarios |
| Comparative usability | Multiple options | Preference ranking |
| Corpus analysis | Post-release | Usage patterns |

**Example**:

```markdown
## Empirical Evaluation

### Cognitive Dimensions Analysis

| Dimension | Option A (Nested) | Option B (Flat) |
|-----------|-------------------|-----------------|
| Visibility | High (autocomplete shows all) | Medium |
| Consistency | High (matches stdlib) | Low |
| Role-expressiveness | High (hierarchy shows relation) | Medium |

### Comparative Assessment

Option A scores higher on 4/6 cognitive dimensions relevant to this context.
```

**Advantages**:
- Evidence-based decisions
- User-centered design
- Measurable outcomes

**Disadvantages**:
- Requires user studies for full rigor
- Proxy methods less reliable

### Option 4: Cross-Domain Research Protocol

Systematically consult related domains for insights.

**Domain Matrix**:

| Domain | Relevance | Key Sources |
|--------|-----------|-------------|
| Swift Evolution | Direct | SE proposals, forum discussions |
| Rust | High (ownership) | RFCs, Rustonomicon |
| Haskell | High (type system) | GHC proposals, papers |
| OCaml | Medium (modules) | Jane Street blog, papers |
| Academic PL | High | POPL, ICFP, OOPSLA proceedings |
| Category Theory | Foundational | nLab, Milewski's blog |
| Type Theory | Foundational | HoTT book, PFPL |

**Cross-Reference Protocol**:

```markdown
## Cross-Domain Analysis

### Swift Evolution
- **SE-0390**: Noncopyable types — establishes affine semantics
- **SE-0377**: `borrowing` and `consuming` — ownership annotations

### Rust Prior Art
- **RFC 2094**: Non-lexical lifetimes — relevant to borrow scopes
- **Rustonomicon**: Drop check — deinit ordering semantics

### Academic Literature
- [Wadler 1990](https://homepages.inf.ed.ac.uk/wadler/papers/linear/linear.ps) — Linear types original paper
- [Tov & Pucella 2011](https://dl.acm.org/doi/10.1145/1925844.1926436) — Practical affine types

### Category Theory
- Linear logic as symmetric monoidal closed category
- Affine types as weakening without contraction
```

**Advantages**:
- Avoids reinventing the wheel
- Leverages decades of research
- Builds credibility

**Disadvantages**:
- Time-intensive
- Risk of over-engineering

---

## Proposed Enhancement: Tiered Research Rigor

Not all decisions warrant PhD-level analysis. Propose a **tiered system** distinguished by **precedent risk**, not scope alone.

### Tier Distinction Criteria

| Criterion | Tier 1: Quick | Tier 2: Standard | Tier 3: Deep |
|-----------|---------------|------------------|--------------|
| **Scope** | Package-specific | Cross-package or cross-domain | Ecosystem-wide |
| **Precedent-setting** | No | No or reversible | Yes, hard to undo |
| **Semantic commitment** | None | Informal / descriptive | Normative / foundational |
| **Cost of error** | Low | Medium | Very high |
| **Expected lifetime** | Single release | Several releases | "Timeless infrastructure" |
| **Formalization** | Not required | Optional | Mandatory |

### Normative Rule: Tier 3 Threshold

> **Tier 3 research MUST be used when a decision establishes a long-lived semantic contract or conceptual foundation that future APIs, conventions, or language-facing abstractions will depend on.**
>
> Ecosystem-wide scope alone does not mandate Tier 3 unless the decision materially constrains future design space.
>
> **Tier 3 research is exceptional.** The default assumption is that a decision does not require Tier 3 unless explicitly justified. Expect very few Tier 3 decisions per year.

### Tier Examples

| Decision | Tier | Rationale |
|----------|------|-----------|
| "Which storage variant name?" | 1 | Package-specific, easily changed |
| "Index type design across collections" | 2 | Cross-package, but not foundational |
| "Naming consistency audit" | 2 | Cross-package verification |
| "Error taxonomy philosophy" | 3 | Establishes precedent for all error types |
| "Ownership / move-only mental model" | 3 | Foundational, constrains all future APIs |

### Tier Summary

| Tier | Methodology | Example |
|------|-------------|---------|
| **Tier 1: Quick** | Current RES-* process | "Which storage name?" |
| **Tier 2: Standard** | + Prior art survey, + Theoretical grounding | "Index type design" |
| **Tier 3: Deep** | + Full SLR, + Formal semantics, + Empirical validation | "Ownership model" |

### Tier 2: Standard Research Template

```markdown
# {Topic}

## Metadata
<!--
version: 1.0.0
status: IN_PROGRESS
tier: 2
-->

## Context
{Trigger and constraints}

## Question
{Precise question}

## Prior Art Survey

### Swift Ecosystem
| Source | Finding |
|--------|---------|

### Related Languages
| Language | Approach | Relevance |
|----------|----------|-----------|

### Academic Literature
| Paper | Key Contribution |
|-------|------------------|

## Theoretical Foundation

### Type-Theoretic Analysis
{Formal characterization}

### Category-Theoretic View (if applicable)
{Categorical structure}

## Analysis

### Option Comparison
{Structured comparison}

### Cognitive Dimensions (if API-facing)
{Usability analysis}

## Outcome

**Decision**: {choice}
**Rationale**: {grounded in prior art + theory}
**Verification**: {how to confirm correctness}
```

### Tier 3: Deep Research Template

Adds:

```markdown
## Systematic Literature Review

### Protocol
- **Research questions**: RQ1, RQ2, ...
- **Search strategy**: {databases, keywords, date range}
- **Inclusion/exclusion criteria**: {specified}

### Search Results
| Database | Hits | After Screening |
|----------|------|-----------------|

### Data Extraction
| Paper | RQ1 | RQ2 | Quality |
|-------|-----|-----|---------|

### Synthesis
{Meta-analysis of findings}

## Formal Semantics

### Typing Rules
{Inference rules in notation}

### Operational Semantics
{Reduction rules}

### Soundness Argument
{Why the design is correct}

## Empirical Validation Plan

### Hypotheses
- H1: {testable claim}
- H2: {testable claim}

### Method
{Study design}

### Metrics
{Measurable outcomes}
```

---

## Implementation Recommendations

### 1. New Requirements to Add

| ID | Title | Summary |
|----|-------|---------|
| RES-020 | Research Tiers | Three-tier rigor system |
| RES-021 | Prior Art Survey | Required for Tier 2+ |
| RES-022 | Theoretical Grounding | Category/type theory for Tier 2+ |
| RES-023 | Systematic Literature Review | Full SLR for Tier 3 |
| RES-024 | Formal Semantics | Typing rules for Tier 3 |
| RES-025 | Empirical Validation | Usability analysis for API decisions |
| RES-026 | Cross-Domain Protocol | Consulting related languages/domains |

### 2. Tool Integration

| Tool | Purpose | Integration |
|------|---------|-------------|
| Web search | Prior art discovery | During analysis phase |
| arXiv/ACM DL | Academic papers | Tier 2+, automated search |
| Swift Forums | Community consensus | All tiers |
| GitHub | SE proposals, RFCs | All tiers |

### 3. Reference Library

Maintain a curated bibliography with discipline-based partitioning:

```
swift-institute/
└── References/
    ├── swift-evolution.bib       # SE proposals, forum discussions
    ├── programming-languages.bib # Rust RFCs, Haskell GHC, OCaml
    ├── type-theory.bib           # Linear types, dependent types, etc.
    ├── category-theory.bib       # Categorical semantics
    ├── api-usability.bib         # Usability studies, cognitive dimensions
    └── methodology.bib           # SLR guidelines, empirical methods
```

**Normative Rules**:

> - Tier 2+ research SHOULD reference entries from `References/`
> - Tier 3 research MUST include a References section traceable to `.bib` entries
> - Citations may be informal Markdown links, but canonical metadata lives in `.bib`

### 4. Notation Standards

Adopt standard notation for formal content:

| Domain | Notation | Example |
|--------|----------|---------|
| Type theory | Inference rules | `Γ ⊢ e : τ` |
| Category theory | Diagrams | Commutative squares |
| Linear logic | Connectives | `A ⊸ B` (linear implication) |
| Operational semantics | Reduction | `e → e'` |

### 5. Notation Policy (Tier-Gated)

| Tier | Main Body | Appendices |
|------|-----------|------------|
| Tier 1 | Prose only | None |
| Tier 2 | Light formalism, explained | Optional |
| Tier 3 | Formal definitions inline | Extended proofs in appendices |

**Normative Rule**:

> Formal notation MAY be used in Tier 2 research when it improves precision.
>
> Formal notation MUST be used in Tier 3 research, with primary definitions in the main text and extended derivations or proofs in appendices.

---

## References

### Methodology
- [Kitchenham & Charters (2007)](https://legacyfileshare.elsevier.com/promis_misc/525444systematicreviewsguide.pdf) — SLR Guidelines for SE
- [Piccioni et al. (2013)](https://se.inf.ethz.ch/~meyer/publications/empirical/API_usability.pdf) — API Usability Empirical Study
- [Cognitive Dimensions](http://www.cs.cmu.edu/~NatProg/apiusability.html) — CMU API Usability

### Type Theory
- [Wadler (1990)](https://homepages.inf.ed.ac.uk/wadler/papers/linear/linear.ps) — Linear Types Can Change the World
- [Tov & Pucella (2011)](https://dl.acm.org/doi/10.1145/1925844.1926436) — Practical Affine Types
- [Microsoft Research (2017)](https://www.microsoft.com/en-us/research/wp-content/uploads/2017/03/haskell-linear-submitted.pdf) — Retrofitting Linear Types

### Category Theory
- [Milewski](https://bartoszmilewski.com/2014/10/28/category-theory-for-programmers-the-preface/) — Category Theory for Programmers
- [MIT 18.S097](http://brendanfong.com/programmingcats.html) — Programming with Categories
- [nLab](https://ncatlab.org/) — Category theory reference

### Swift-Specific
- [Swift Evolution](https://github.com/swiftlang/swift-evolution) — SE Proposals
- [Formal Swift Value Semantics](https://www.researchgate.net/publication/346265512_A_Formal_Definition_of_Swift's_Value_Semantics) — Academic formalization

---

## Outcome

**Status**: SUPERSEDED (2026-03-10)
**Superseded by**: **research-process** skill [RES-020-026]
Content absorbed into the research-process skill as tiered research requirements. This research designed the tiered system that is now codified. It remains as historical rationale.

**Previous Status**: DECISION

**Recommendation**: Implement tiered research system as an **extension** to existing Research.md infrastructure.

### Resolved Decisions

| Question | Resolution |
|----------|------------|
| Tier thresholds | Precedent-based, not scope-alone |
| Formal notation | Hybrid model, tier-gated |
| Reference library | Yes, discipline-partitioned `.bib` files |
| Integration approach | Extension-only, no refactoring of existing rules |

### Integration Path

**Phase 1: Ratification** (current)
- This document status: RECOMMENDATION
- Pending: Final approval

**Phase 2: Minimal Integration**
- Add RES-020 through RES-026 to Research.md as new section
- Create `References/` directory with initial `.bib` files
- Do NOT rewrite existing RES-001 through RES-017

### Compatibility

| Document | Compatibility |
|----------|---------------|
| Research.md | Extension-only, no conflicts |
| Research Investigation | Tier 1 maps directly to existing workflow |
| Research Discovery | Tier 2 and Tier 3 align naturally with proactive audits |

### Key Properties

1. **Tier 3 is exceptional** — few decisions per year
2. **Extends, does not replace** — existing system remains stable
3. **Scope escalation preserved** — Discovery can trigger Tier 2/3 when patterns emerge
4. **Formalism is tier-gated** — avoids over-engineering simple decisions

### Next Steps

1. Approve this proposal (move to DECISION)
2. Add RES-020–026 section to Research.md
3. Create `References/` directory structure
4. Pilot Tier 2 methodology on next cross-package decision
5. Reserve Tier 3 for foundational decisions only
