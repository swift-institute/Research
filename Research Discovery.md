# Research Discovery

<!--
---
title: Research Discovery
version: 1.0.0
last_updated: 2026-01-22
applies_to: [swift-primitives, swift-institute, swift-standards, swift-foundations]
normative: true
llm_optimized: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Proactive workflow for systematically auditing design decisions, reviewing architectural patterns, and documenting design rationale across packages.

## Overview

This document defines the *discovery workflow* for research documents—the process you follow when you want to proactively audit a package's design decisions, review naming consistency, or document architectural rationale without an immediate implementation question prompting the analysis.

**Entry point**: You want to audit design decisions, verify convention compliance, or document architectural rationale.

**Prerequisite**: Read <doc:Research> for document structure, metadata, and documentation requirements.

**Applies to**: Design audits, convention compliance reviews, architectural documentation, pattern consistency verification.

**Does not apply to**: Resolving immediate design questions blocking implementation—see <doc:Research-Investigation> instead.

---

## Quick Reference: When to Create a Discovery Research Document

**Scope**: Decision criteria for creating discovery research. See [RES-012] for the normative rule.

| Trigger | Example | See Also |
|---------|---------|----------|
| Package reaching milestone | "swift-heap-primitives v1.0 design review" | [RES-013] |
| Convention compliance audit | "Do all primitives follow [API-NAME-001]?" | [RES-015] |
| Cross-package consistency | "Are storage variants named consistently?" | [RES-014] |
| Architectural documentation | "Document why we chose phantom generics" | [RES-016] |
| Pattern extraction | "Extract common patterns from implementations" | [RES-017] |
| Post-implementation review | "Was the chosen design correct?" | [RES-015] |

**Cross-references**: [RES-012], [RES-002a]

---

## [RES-012] Discovery Triggers

**Scope**: Conditions that warrant creating a discovery research document.

**Statement**: A discovery research document SHOULD be created when proactive design analysis would improve consistency, document rationale, or identify improvement opportunities.

### Trigger Categories

| Category | Description | Priority |
|----------|-------------|----------|
| Package milestone | Package reaches v1.0 or major release | High |
| Cross-package review | Consistency audit across related packages | High |
| Convention evolution | New convention needs documentation | Medium |
| Rationale documentation | Important decision lacks documented reasoning | Medium |
| Pattern extraction | Common pattern emerging across implementations | Medium |
| Retrospective | Post-implementation design evaluation | Low |

### Discovery vs Investigation

| Aspect | Investigation | Discovery |
|--------|---------------|-----------|
| Trigger | Question blocking implementation | Proactive audit |
| Starting point | Uncertainty | Working design |
| Goal | Make a decision | Document/verify decisions |
| Outcome | DECISION enabling implementation | Documentation or improvements |
| Urgency | Usually blocking | Usually scheduled |

**Correct**:
```text
Context: swift-primitives has 20+ packages with storage variants
Action: Create discovery research on storage variant naming consistency
Result: Documented patterns, identified inconsistencies, proposed standardization
```

**Incorrect**:
```text
Context: swift-primitives has 20+ packages with storage variants
Action: "They're probably fine, don't need to check"
Result: Inconsistencies accumulate, debt grows  ❌
```

**Rationale**: Proactive design review catches inconsistencies before they become entrenched.

**Cross-references**: [RES-001], [RES-002a]

---

## [RES-013] Design Audit Methodology

**Scope**: Systematic process for auditing design decisions across a package or package family.

**Statement**: Design audits MUST follow a systematic methodology that identifies all design decisions and evaluates them against conventions and consistency criteria.

### Audit Process

| Phase | Action | Output |
|-------|--------|--------|
| 1. Scope | Define audit boundaries | Package list, decision types |
| 2. Inventory | Catalog design decisions | Decision list |
| 3. Criteria | Define evaluation dimensions | Criteria list |
| 4. Evaluate | Assess each decision | Findings table |
| 5. Synthesize | Identify patterns and issues | Summary |
| 6. Recommend | Propose actions | Recommendations |

### Phase 1: Scope Definition

Define what is being audited:

```markdown
## Audit Scope

**Packages**: swift-heap-primitives, swift-stack-primitives, swift-queue-primitives
**Decision types**: Storage variant naming, Index type design, Error handling patterns
**Conventions**: [API-NAME-001], [API-ERR-001]
```

### Phase 2: Decision Inventory

Catalog design decisions:

```markdown
## Design Decisions Inventory

| Package | Decision | Current Choice |
|---------|----------|----------------|
| swift-heap-primitives | Storage naming | Heap.Inline, Heap.Bounded |
| swift-stack-primitives | Storage naming | Stack.Inline, Stack.Bounded |
| swift-queue-primitives | Storage naming | Queue.Inline, Queue.Bounded |
| swift-heap-primitives | Index type | Index<Element> |
| swift-stack-primitives | Index type | Int (no typed index) |
```

### Phase 3: Evaluation Criteria

Define how decisions will be evaluated:

```markdown
## Evaluation Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Convention compliance | High | Matches [API-NAME-001], [API-ERR-001] |
| Cross-package consistency | High | Same patterns across similar packages |
| API ergonomics | Medium | Easy to discover and use |
| Implementation complexity | Low | Manageable implementation burden |
```

### Phase 4-6: Evaluate, Synthesize, Recommend

```markdown
## Findings

| Package | Decision | Compliant | Consistent | Issues |
|---------|----------|-----------|------------|--------|
| swift-heap-primitives | Storage naming | ✓ | ✓ | None |
| swift-stack-primitives | Index type | ✓ | ✗ | Inconsistent with Heap |

## Recommendations

1. **Standardize Index types**: Add typed Index<Element> to Stack and Queue
2. **Document pattern**: Add storage variant pattern to Implementation Patterns.md
```

**Rationale**: Systematic audits ensure nothing is missed. Ad-hoc reviews leave gaps.

**Cross-references**: [RES-014], [RES-015]

---

## [RES-014] Consistency Analysis

**Scope**: Analyzing consistency across related packages or components.

**Statement**: Consistency analysis MUST compare related design decisions across packages, identifying deviations and evaluating whether deviations are justified.

### Consistency Categories

| Category | What to Compare | Example |
|----------|-----------------|---------|
| Naming patterns | Type, method, property names | Storage variant naming |
| Structural patterns | Type hierarchies, nesting | Index type organization |
| API patterns | Method signatures, return types | Iterator patterns |
| Error patterns | Error types, throwing behavior | Typed throws usage |
| Convention compliance | Adherence to documented rules | [API-NAME-001] compliance |

### Consistency Analysis Template

```markdown
# {Pattern} Consistency Analysis

## Scope
{What packages/components are being compared}

## Pattern Definition
{What the consistent pattern should be}

## Current State

| Package | Implementation | Matches Pattern |
|---------|----------------|-----------------|
| Package A | {current} | ✓ / ✗ |
| Package B | {current} | ✓ / ✗ |

## Deviations

### {Package with deviation}
**Current**: {what it does}
**Expected**: {what pattern requires}
**Justified**: {Yes/No - reason}

## Recommendations
{What should be changed to achieve consistency}
```

**Correct**:
```markdown
# Storage Variant Naming Consistency

## Scope
All primitives packages with storage variants

## Pattern Definition
Storage variants use `{Type}.Inline`, `{Type}.Bounded`, `{Type}.Unbounded`

## Current State

| Package | Implementation | Matches Pattern |
|---------|----------------|-----------------|
| swift-heap-primitives | Heap.Inline, Heap.Bounded | ✓ |
| swift-array-primitives | Array.Inline, Array.Bounded | ✓ |
| swift-buffer-primitives | Buffer.Inline, Buffer.Bounded | ✓ |

## Deviations
None identified.

## Recommendations
Pattern is consistent. Document in Implementation Patterns.md.
```

**Incorrect**:
```markdown
# Storage Variant Naming

Heap uses Heap.Inline and Heap.Bounded.
Stack uses Stack.Inline and Stack.Bounded.
They're consistent.  ❌ No pattern definition, no structured comparison
```

**Rationale**: Consistency reduces cognitive load for users. Documented deviations enable justified exceptions.

**Cross-references**: [RES-013], [RES-015]

---

## [RES-015] Convention Compliance Verification

**Scope**: Verifying design decisions comply with established conventions.

**Statement**: Convention compliance verification MUST check design decisions against relevant convention rules, documenting compliance and any justified exceptions.

### Convention Sources

| Convention | Document | Key Rules |
|------------|----------|-----------|
| Naming | <doc:Naming> | [API-NAME-001], [API-NAME-002], [API-NAME-003] |
| Errors | <doc:Errors> | [API-ERR-001] |
| Design | <doc:Design> | [API-DESIGN-*] |
| Implementation | <doc:Code-Organization> | [API-IMPL-005] |

### Compliance Verification Template

```markdown
# {Convention} Compliance: {Package}

## Convention Reference
{Rule ID and statement}

## Items Checked

| Item | Compliant | Notes |
|------|-----------|-------|
| Type A | ✓ | |
| Type B | ✗ | Uses CompoundName |
| Method C | ✓ | |

## Non-Compliant Items

### {Item}
**Current**: {what it does}
**Required**: {what convention requires}
**Resolution**: {fix or justify exception}

## Summary
{X of Y items compliant. Resolutions proposed for non-compliant items.}
```

**Correct**:
```text
Audit: [API-NAME-001] compliance for swift-heap-primitives
Items: 12 public types checked
 should be Heap.Element)
Resolution: Rename in next release
```

**Incorrect**:
```text
Audit: Naming compliance
Result: "Looks good"  ❌ No specific convention referenced
                      ❌ No items enumerated
                      ❌ No compliance status per item
```

**Rationale**: Conventions lose value if not enforced. Verification ensures conventions are applied consistently.

**Cross-references**: [RES-013], [RES-014]

---

## [RES-016] Rationale Documentation

**Scope**: Documenting the reasoning behind significant design decisions.

**Statement**: Significant design decisions SHOULD have documented rationale. Discovery research MAY be created to retroactively document rationale for decisions that lack it.

### When to Document Rationale

| Criterion | Document Rationale |
|-----------|-------------------|
| Decision affects multiple packages | SHOULD |
| Decision establishes precedent | MUST |
| Decision deviates from convention | MUST |
| Decision has non-obvious trade-offs | SHOULD |
| Decision is frequently questioned | SHOULD |

### Rationale Documentation Template

```markdown
# {Decision} Rationale

## Decision
{What was decided}

## Context
{When and why this decision was made}

## Alternatives Considered

### {Alternative 1}
**Description**: {what it would have been}
**Why rejected**: {reason}

### {Alternative 2}
**Description**: {what it would have been}
**Why rejected**: {reason}

## Chosen Approach
**Description**: {what was chosen}
**Key reasons**: {why it was chosen}

## Implications
{What this decision means for future work}

## References
{Related documents, discussions, experiments}
```

**Correct**:
```markdown
# Phantom Generic Index Rationale

## Decision
Index types use phantom generics: `Index<Element>` where Element is not stored.

## Context
Implementing swift-index-primitives, needed to decide how to provide type safety
for index values without runtime overhead.

## Alternatives Considered

### Associated type in protocol
**Description**: `protocol Indexed { associatedtype Index }`
**Why rejected**: Requires protocol, adds complexity

### Wrapper struct per collection
**Description**: `HeapIndex`, `StackIndex`, `ArrayIndex`
**Why rejected**: Proliferation of types, [API-NAME-001] concerns

## Chosen Approach
**Description**: `Index<Element>` phantom generic
**Key reasons**:
- Compile-time type safety without runtime overhead
- Single type serves all collections
- Consistent with Swift's type-safe philosophy

## Implications
All collection types can use `Index<Element>` for their index type.
```

**Incorrect**:
```markdown
# Index Design

We use phantom generics because they're better.  ❌ No alternatives documented
                                                  ❌ No context for decision
                                                  ❌ No implications stated
```

**Rationale**: Documented rationale enables future maintainers to understand decisions and make informed changes.

**Cross-references**: [RES-006], [RES-013]

---

## [RES-017] Pattern Extraction

**Scope**: Identifying and documenting common patterns across implementations.

**Statement**: When similar solutions appear across multiple packages, the pattern SHOULD be extracted and documented for consistent future application.

### Pattern Extraction Process

| Step | Action | Output |
|------|--------|--------|
| 1 | Identify recurring solution | Pattern candidate |
| 2 | Collect instances | Instance list |
| 3 | Abstract common elements | Pattern definition |
| 4 | Document variations | Variation catalog |
| 5 | Propose standardization | Pattern document |

### Pattern Documentation Template

```markdown
# {Pattern Name} Pattern

## Pattern Definition
{Abstract description of the pattern}

## Instances Found

| Package | Implementation | Variations |
|---------|----------------|------------|
| Package A | {how it's implemented} | {any deviations} |
| Package B | {how it's implemented} | {any deviations} |

## Common Elements
{What all instances share}

## Variations
{Justified variations and their reasons}

## Standardized Pattern
{The canonical form going forward}

## Application Guidance
{When and how to apply this pattern}
```

**Correct**:
```markdown
# Storage Variant Pattern

## Pattern Definition
Collections offer multiple storage strategies as nested types: Inline (fixed capacity,
stack allocated), Bounded (maximum capacity, heap allocated), Unbounded (growable).

## Instances Found

| Package | Implementation | Variations |
|---------|----------------|------------|
| swift-heap-primitives | Heap.Inline, Heap.Bounded | No Unbounded yet |
| swift-array-primitives | Array.Inline, Array.Bounded, Array.Unbounded | Full set |
| swift-stack-primitives | Stack.Inline, Stack.Bounded | No Unbounded yet |

## Common Elements
- Nested type naming: `{Collection}.{Variant}`
- Inline uses value generics for capacity
- Bounded uses runtime capacity check
- All support ~Copyable elements

## Standardized Pattern
1. Name variants as `{Collection}.Inline`, `{Collection}.Bounded`, `{Collection}.Unbounded`
2. Inline MUST use value generics: `struct Inline<let capacity: Int>`
3. All variants MUST support ~Copyable elements

## Application Guidance
Apply to any collection type offering multiple storage strategies.
```

**Incorrect**:
```markdown
# Storage Pattern

We use Inline and Bounded storage in our collections.  ❌ No instances cataloged
Just follow what Heap does.                             ❌ No standardized definition
                                                        ❌ No application guidance
```

**Rationale**: Extracted patterns prevent reinvention and ensure consistency.

**Cross-references**: [RES-014], [RES-006a]

---

## Discovery Workflow Summary

```text
┌─────────────────────────────────────────────────────────────┐
│                    DISCOVERY WORKFLOW                        │
└─────────────────────────────────────────────────────────────┘

1. TRIGGER IDENTIFICATION [RES-012]
   │
   ├─ Package milestone? ───────────────────┐
   ├─ Consistency concern? ─────────────────┤
   ├─ Convention verification? ─────────────┤
   └─ Pattern emerging? ────────────────────┘
                                            │
                                            ▼
2. SCOPE DEFINITION [RES-013]
   │
   ├─ Define package boundaries
   ├─ Identify decision types
   └─ Select relevant conventions
                                            │
                                            ▼
3. TRIAGE [RES-002a]
   │
 {package}/Research/
 swift-primitives/.../Research/
 swift-institute/.../Research/
                                            │
                                            ▼
4. ANALYSIS TYPE SELECTION
   │
   ├─ Consistency analysis [RES-014]
   ├─ Convention compliance [RES-015]
   ├─ Rationale documentation [RES-016]
   └─ Pattern extraction [RES-017]
                                            │
                                            ▼
5. EXECUTE ANALYSIS
   │
   ├─ Inventory decisions
   ├─ Evaluate against criteria
   ├─ Identify issues/patterns
   └─ Synthesize findings
                                            │
                                            ▼
6. DOCUMENT OUTCOME [RES-006]
   │
   ├─ Record findings
   ├─ Propose recommendations
   └─ Note implementation guidance
                                            │
                                            ▼
7. PROMOTION [RES-006a]
   │
 Add to Implementation Patterns
 Update relevant docs
 Keep in package Research
```

---

## Topics

### Foundation Document

- <doc:Research> — Shared infrastructure for all research

### Related Workflow

- <doc:Research-Investigation> — Reactive workflow for design questions

### Related Documents

- <doc:Experiment-Discovery> — Proactive workflow for code verification
- <doc:Design> — API design rules and patterns
- <doc:Naming> — Naming conventions

### Cross-Reference Index

| ID | Title | Focus |
|----|-------|-------|
| RES-012 | Discovery Triggers | When to create discovery research |
| RES-013 | Design Audit Methodology | Systematic package verification |
| RES-014 | Consistency Analysis | Cross-package consistency |
| RES-015 | Convention Compliance Verification | Convention adherence |
| RES-016 | Rationale Documentation | Documenting decision reasoning |
| RES-017 | Pattern Extraction | Identifying common patterns |

