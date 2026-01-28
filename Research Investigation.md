# Research Investigation

@Metadata {
    @TitleHeading("Swift Institute")
}

Reactive workflow for creating research documents when you encounter design questions, naming decisions, or architectural uncertainty during implementation.

## Overview

This document defines the *investigation workflow* for research documents—the process you follow when a design question arises during implementation that cannot be answered without systematic analysis.

**Entry point**: You hit a design question, naming decision, or architectural uncertainty during implementation.

**Prerequisite**: Read [Research](Research.md) for document structure, metadata, and documentation requirements.

**Applies to**: Design decisions blocking implementation, naming alternatives, pattern selection, trade-off resolution.

**Does not apply to**: Proactive design audits or systematic architecture review—see [Research Discovery](Research%20Discovery.md) instead.

---

## Quick Reference: When to Create an Investigation Research Document

**Scope**: Decision criteria for creating investigation research. See [RES-001] for the normative rule.

| Trigger | Example | See Also |
|---------|---------|----------|
| Naming decision with multiple valid options | "Should this be `Heap.Index` or `Index<Heap>`?" | [RES-010a] |
| Pattern selection uncertainty | "Should we use Property.View or direct methods?" | [RES-004] |
| Convention interpretation | "Does [API-NAME-001] apply to this case?" | [RES-004a] |
| Trade-off requiring explicit choice | "Performance vs API simplicity" | [RES-010c] |
| Architecture decision blocking progress | "How should storage variants be organized?" | [RES-010b] |
| Prior art contradicts intuition | "stdlib does X, but our conventions suggest Y" | [RES-011] |

**Cross-references**: [RES-001], [API-NAME-001], [API-DESIGN-004]

---

## [RES-001] Investigation Triggers

**Scope**: Conditions that warrant creating an investigation research document.

**Statement**: An investigation research document MUST be created when a design decision cannot be made without systematic analysis of alternatives. An investigation research document SHOULD NOT be created when existing documentation or conventions clearly answer the question.

**Correct**:
```text
Question: "Should we name this `Heap.Storage.Inline` or `Heap.Inline`?"
Action: Create Research/heap-storage-naming.md to analyze options
Result: Systematic comparison with documented rationale
```

**Incorrect**:
```text
Question: "Should we use CompoundName or Nest.Name?"
Action: Create research document
Result: Wasted effort—[API-NAME-001] already mandates Nest.Name  ❌
```

### Trigger Categories

| Category | Description | Action |
|----------|-------------|--------|
| Naming ambiguity | Multiple valid names, no clear winner | Create research |
| Pattern selection | Multiple patterns could apply | Create research |
| Trade-off resolution | Competing concerns need balancing | Create research |
| Architecture choice | Structural decision with implications | Create research |
| Convention clarity | Existing convention answers the question | Read documentation first |
| Implementation detail | Does not affect API or architecture | No research needed |

**Rationale**: Research documents require effort. Reserve them for questions where existing documentation is insufficient or where the decision has lasting impact.

**Cross-references**: [RES-001a], [RES-004], [API-DESIGN-004]

---

## [RES-001a] Research Granularity

**Scope**: Minimum threshold for creating research documents.

**Statement**: Research documents SHOULD NOT be created when:
1. Conventions clearly answer the question (see [RES-001]), OR
2. No meaningful alternatives were considered, OR
3. The rationale is implementation-specific rather than design-level

**Guidance**: If the decision affects only HOW code is written (implementation), use code comments. If it affects WHAT is built or WHY this approach was chosen over alternatives (design), use research.

**Correct**:
```text
Question: "Should we use phantom generics or associated types for Index?"
Alternatives: Two distinct approaches with different trade-offs
Action: Create research document to analyze
```

**Incorrect**:
```text
Question: "Should we use `let` or `var` for this property?"
Alternatives: None meaningful—semantics dictate the choice
Action: Create research document  ❌ No design decision to analyze
```

**Rationale**: Research documents analyze trade-offs. Without alternatives, there is nothing to analyze—only constraints to document.

**Cross-references**: [RES-001], [RES-004a]

---

## [RES-004] Investigation Methodology

**Scope**: Process for investigating design questions.

**Statement**: Design questions MUST be investigated by enumerating options, identifying evaluation criteria, and systematically comparing alternatives.

### Investigation Steps

| Step | Action | Output |
|------|--------|--------|
| 1 | State the question precisely | Clear question statement |
| 2 | Enumerate all viable options | Option list |
| 3 | Identify evaluation criteria | Criteria list |
| 4 | Analyze each option against criteria | Comparison table |
| 5 | Document constraints | Constraint list |
| 6 | Make recommendation or decision | Outcome |

**Correct**:
```markdown
## Question

How should Heap storage variants be named?

## Analysis

### Option 1: Nested under Storage
`Heap.Storage.Inline`, `Heap.Storage.Bounded`, `Heap.Storage.Unbounded`

### Option 2: Direct nesting
`Heap.Inline`, `Heap.Bounded`, `Heap.Unbounded`

### Comparison
| Criterion | Storage Nested | Direct |
|-----------|----------------|--------|
| Type depth | 3 levels | 2 levels |
| Discoverability | Lower | Higher |
| Consistency with Array | — | Matches Array.Inline |

## Outcome
**Choice**: Direct nesting (Option 2)
**Rationale**: Matches Array pattern, reduces type depth
```

**Incorrect**:
```text
Question: How should Heap storage variants be named?
Answer: Let's use Heap.Inline because it seems cleaner.  ❌ No analysis
```

**Rationale**: Systematic investigation ensures all options are considered and decisions can be justified to future maintainers.

**Cross-references**: [RES-005], [RES-006]

---

## [RES-004a] Convention Consultation

**Scope**: Checking existing conventions before creating research.

**Statement**: Before creating a research document, existing conventions MUST be consulted. Research SHOULD only be created when conventions do not clearly answer the question or when the question is about how to apply conventions.

### Convention Sources

| Source | Location | Coverage |
|--------|----------|----------|
| API Naming | [Naming](../Documentation.docc/Implementation/Naming.md) | Type, method, property naming |
| API Requirements | [Implementation](../Documentation.docc/Implementation/Index.md) | API design rules |
| API Design | [Design](../Documentation.docc/Implementation/Design.md) | Design patterns |
| Implementation Patterns | [Implementation](../Documentation.docc/Implementation/Index.md) | Implementation guidance |
| Package conventions | Package-specific docs | Package-specific patterns |

### Consultation Process

1. Identify the decision category (naming, structure, pattern, etc.)
2. Consult relevant convention document
 follow it, no research needed
 create research

**Correct**:
```text
Question: "Should this type be named `FileReader` or `File.Reader`?"

Step 1: This is a naming decision
Step 2: Consult API Naming.md
Step 3: [API-NAME-001] mandates Nest.Name pattern
Conclusion: Use `File.Reader`, no research needed
```

**Correct** (research warranted):
```text
Question: "Should Index be `Collection.Index` or a separate `Index<Collection>`?"

Step 1: This is a naming/structure decision
Step 2: Consult API Naming.md
Step 3: Both patterns could satisfy [API-NAME-001]
Conclusion: Create research to analyze trade-offs
```

**Incorrect**:
```text
Question: "Should this type be named `FileReader` or `File.Reader`?"

Action: Create research document to analyze both options
Result: Wasted effort—[API-NAME-001] already mandates Nest.Name  ❌
        Convention was not consulted first
```

**Rationale**: Conventions exist to prevent repeated analysis of solved problems. Research should focus on genuinely open questions.

**Cross-references**: [RES-001], [API-NAME-001]

---

## [RES-011] Research-First Design

**Scope**: Using research to resolve design uncertainty before implementation.

**Statement**: When implementation is blocked by a design question, a research document SHOULD be created to resolve the question BEFORE attempting multiple implementation approaches.

### The Research-First Sequence

| Step | Action | Outcome |
|------|--------|---------|
| 1 | Identify blocking question | Clear question statement |
| 2 | Create research document | Analysis framework |
| 3 | Enumerate options | Complete option set |
| 4 | Analyze trade-offs | Comparison table |
| 5 | Make decision | Clear direction |
| 6 | Implement chosen approach | Single implementation |

**Correct**:
```text
Implementation blocked: "How should we organize storage variants?"

Step 1: Create Research/storage-variant-organization.md
Step 2: Enumerate: nested types, generic parameter, separate types
Step 3: Analyze against criteria: discoverability, complexity, consistency
Step 4: Decision: nested types (Heap.Inline, Heap.Bounded)
Step 5: Implement the chosen approach
```

**Incorrect**:
```text
Implementation blocked: "How should we organize storage variants?"

Action: Implement Option A, see if it feels right
...later: Option A doesn't feel right, try Option B
...later: Option B has issues, try Option C
Result: Wasted effort, no documented rationale  ❌
```

### Why This Works

Research-first design:
- Prevents implementation thrashing
- Documents rationale for future reference
- Enables team input before commitment
- Creates institutional knowledge

**Rationale**: Implementation is expensive. Research is cheap. Resolve uncertainty through analysis before committing to code.

**Cross-references**: [RES-001], [RES-004]

---

## Case Study: Index Type Design

This case study demonstrates the methodology in action.

**Initial state**: Implementing swift-index-primitives, unclear how to structure the Index type hierarchy.

**Investigation sequence**:

| Step | Method | Question | Answer |
|------|--------|----------|--------|
| 1 | [RES-004a] | Does convention specify? | Partial—Nest.Name applies but doesn't resolve structure |
| 2 | [RES-001] | Is research warranted? | Yes—multiple valid structures |
| 3 | [RES-004] | What are the options? | Phantom generic, associated type, nested type |
| 4 | [RES-005] | What criteria matter? | Type safety, ergonomics, convention fit |
| 5 | [RES-006] | What's the outcome? | DECISION: Index<Element> phantom generic |

**Research document created**: `Research/index-type-hierarchy.md`

**Key insight**: The research process identified that phantom generics provide compile-time type safety without runtime overhead—an insight that might have been missed by trial-and-error implementation.

---

## Investigation Workflow Summary

```text
┌─────────────────────────────────────────────────────────────┐
│                  INVESTIGATION WORKFLOW                      │
└─────────────────────────────────────────────────────────────┘

1. TRIGGER IDENTIFICATION [RES-001]
   │
   ├─ Naming decision? ──────────────────────┐
   ├─ Pattern selection? ────────────────────┤
   ├─ Architecture choice? ──────────────────┤
   └─ Trade-off resolution? ─────────────────┘
                                             │
                                             ▼
2. CONVENTION CHECK [RES-004a]
   │
 Follow it, no research
 Continue to research
                                             │
                                             ▼
3. TRIAGE [RES-002a]
   │
 {package}/Research/
 swift-primitives/.../Research/
 swift-institute/.../Research/
                                             │
                                             ▼
4. DOCUMENT CREATION [RES-003]
   │
   ├─ Create file with metadata
   ├─ Document context and question
   └─ Begin analysis
                                             │
                                             ▼
5. ANALYSIS [RES-004]
   │
   ├─ Enumerate all viable options
   ├─ Identify evaluation criteria
   ├─ Compare options systematically
   └─ Document constraints
                                             │
                                             ▼
6. OUTCOME [RES-006]
   │
   ├─ Record decision/recommendation
   ├─ Document rationale
   └─ Note implementation guidance
                                             │
                                             ▼
7. PROMOTION [RES-006a]
   │
 Promote to authoritative docs
 Keep in Research only
```

---

## Topics

### Foundation Document

- [Research](Research.md) — Shared infrastructure for all research

### Related Workflow

- [Research Discovery](Research%20Discovery.md) — Proactive design audit workflow

### Related Documents

- [Experiment Investigation](../Experiments/Experiment%20Investigation.md) — Reactive workflow for code verification
- [Design](../Documentation.docc/Implementation/Design.md) — API design rules and patterns
- [Naming](../Documentation.docc/Implementation/Naming.md) — Naming conventions

### Cross-Reference Index

| ID | Title | Focus |
|----|-------|-------|
| RES-001 | Investigation Triggers | When to create investigation research |
| RES-001a | Research Granularity | Minimum threshold for research |
| RES-004 | Investigation Methodology | Systematic analysis process |
| RES-004a | Convention Consultation | Checking existing conventions |
| RES-011 | Research-First Design | Resolve uncertainty before implementing |

