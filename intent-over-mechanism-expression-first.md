# Intent Over Mechanism: Expression-First Code Style

<!--
---
version: 1.0.0
last_updated: 2026-02-11
status: DECISION
tier: 3
---
-->

## Context

The implementation skill ([IMPL-000], [IMPL-002], [IMPL-030]) already mentions that code should "read like intent, not mechanism" and that inline construction is preferred over intermediate variables. However, these principles are distributed across several requirements rather than established as the foundational axiom of all implementation code. During ongoing implementation work, we observe recurring patterns where contributors write mechanistic code — separate `let` bindings that decompose an operation into visible steps — when a single expression would communicate the same intent more directly.

This research formalizes the principle, grounds it in 50+ years of language design and empirical research, and recommends elevating it to the governing axiom of the implementation skill.

**Trigger**: Design philosophy question affecting all implementation code across the ecosystem.

**Scope**: Ecosystem-wide (Tier 3). This decision establishes a normative coding standard that future APIs, implementations, and reviews depend on.

## Question

Should "code reads as intent, not mechanism" be elevated from a mentioned pattern to the foundational principle of all implementation code? Should single-line expressions be normatively preferred over separate variable/let declarations?

## Prior Art Survey

### 1. Language Design Lineage

Expression-oriented programming has a continuous lineage spanning seven decades:

| Year | Contribution | Key Insight |
|------|-------------|-------------|
| 1930s | Church's λ-calculus | Computation as expression evaluation, not state mutation |
| 1958 | Lisp (McCarthy) | First practical expression-oriented language |
| 1966 | ISWIM (Landin, "The Next 700 Programming Languages") | Expression-oriented core as universal programming substrate |
| 1968 | Dijkstra, "Go To Statement Considered Harmful" | Code structure should match human reasoning, not machine execution |
| 1973 | Hoare, "Hints on Programming Language Design" | Source code is the primary medium for expressing intent |
| 1978 | Backus, "Can Programming Be Liberated from the von Neumann Style?" | Imperative style forces description of mechanism; functional composition expresses intent |
| 1991 | Felleisen, "On the Expressive Power of Programming Languages" | Formal framework for when expression-oriented constructs are genuinely more expressive |
| 2004 | Scala | Expression-oriented JVM language |
| 2010 | Rust | Everything is an expression; implicit return |
| 2016 | Kotlin | Expression body functions as idiomatic style; IDE inspection enforces it |
| 2019 | Swift SE-0255 | Implicit returns from single-expression functions |
| 2023 | Swift SE-0380 | `if` and `switch` as expressions |

The trajectory is unambiguous: modern language design converges toward making more constructs expressions. Each step reduces the gap between what the programmer means and what the notation forces them to write.

### 2. Practitioner Consensus

| Author | Work | Year | Position |
|--------|------|------|----------|
| Kent Beck | *Smalltalk Best Practice Patterns* | 1996 | **Intention Revealing Selector**: method names communicate what, not how |
| Kent Beck | *Implementation Patterns* | 2007 | "What do I want to tell a reader about this code?" — code is communication |
| Martin Fowler | *Refactoring* (2nd ed.) | 2018 | **Inline Variable**: remove variables when the expression communicates equally well. **Replace Temp with Query**: when a name is needed, use a function, not a variable |
| Robert C. Martin | *Clean Code* | 2008 | "Intention-revealing names" as first principle; code should speak for itself |
| Matthias Endler | "Thinking in Expressions" | 2024 | Expression-oriented Rust reduces mutability and intermediate variables |

Fowler's refactoring catalog is particularly precise: **Inline Variable** applies when "the name of the variable doesn't communicate more than the expression itself." The inverse (**Extract Variable**) applies only when the expression genuinely benefits from a name. The default direction is inline.

### 3. Empirical Evidence

**Cates, Yunik, & Feitelson (2021).** "Does Code Structure Affect Comprehension? On Using and Naming Intermediate Variables." *ICPC 2021.* [arXiv:2103.11008](https://arxiv.org/abs/2103.11008)

113 subjects read mathematical functions in three formats:
1. Compound expressions (fully inlined)
2. Intermediate variables with meaningless names
3. Intermediate variables with meaningful names

Results:
- Meaningful names showed significant comprehension benefit in only **one** case (the hardest function).
- Intermediate variables with poor names **decreased** comprehension in two cases.
- In all other cases, code structure made no significant difference.

**Conclusion**: Intermediate variables are beneficial only when they carry genuinely informative names. Otherwise, they add cognitive overhead without aiding comprehension. The default should be expression-first.

### 4. Theoretical Grounding

#### 4.1 Cognitive Dimensions of Notations

Green (1989), Green & Petre (1996), and Blackwell & Green (2001) provide the Cognitive Dimensions framework — the standard analytical vocabulary for evaluating programming notations.

Two dimensions directly support expression-first style:

**Closeness of mapping**: "How closely related the notation is to the result it is describing." An expression that directly computes a value maps closely to the value. A sequence of `let` bindings that decompose the computation into named steps introduces indirection — the reader must mentally reconstruct the final value from the parts.

**Role expressiveness**: "The extent to which a notation exposes meaningful structure." An expression `pointer(at: range.lowerBound)` reveals its role (access a pointer at a position). The equivalent `let offset = Offset(fromZero: range.lowerBound); let ptr = base + offset` exposes mechanism (offset computation, pointer arithmetic) that the reader must reassemble into intent.

One dimension provides the boundary condition:

**Viscosity**: "Resistance to change." If the same expression appears in multiple locations, inlining it increases viscosity (changing the logic requires changing every copy). This establishes when extraction is justified — but the correct extraction target is a *named function*, not a local variable.

#### 4.2 Expression Semantics

An expression denotes a value. A statement performs an effect. When code is organized as expressions:

1. **Referential transparency is visible**: The reader can see what a sub-expression computes without knowing when it executes.
2. **Data flow is explicit**: Values flow through composition, not through named intermediate storage.
3. **The scope of each value is minimal**: An inline expression exists only at its point of use. A `let` binding extends the value's scope to the remainder of the block, creating cognitive load even after the value has been consumed.

Formally, let `e₁` and `e₂` be expressions, and let `x` be a fresh variable. The transformation:

```
let x = e₁      →      f(e₁)
f(x)
```

preserves semantics when `e₁` is pure (referentially transparent) and used exactly once. In this case, the `let` binding is semantically vacuous — it introduces a name without adding information. The expression form is strictly more concise and equally clear.

When `e₁` is used more than once, or when its name carries genuine explanatory value not present in the expression itself, the binding is justified.

#### 4.3 Soundness Argument

**Claim**: For single-use, pure sub-expressions, inline expression form is equivalent to or better than `let`-binding form along all relevant cognitive dimensions.

| Dimension | Expression form | Let-binding form |
|-----------|----------------|------------------|
| Closeness of mapping | Higher (direct value construction) | Lower (indirection through name) |
| Role expressiveness | Equal or higher (expression is the role) | Equal or lower (depends on name quality) |
| Viscosity | Equal (single use) | Equal (single use) |
| Diffuseness | Lower (fewer lines, fewer tokens) | Higher (extra line, extra name) |
| Hidden dependencies | Equal | Equal |
| Error-proneness | Equal | Equal |

The let-binding form can only equal or underperform the expression form unless the name carries information not present in the expression. Since Cates et al. (2021) showed empirically that uninformative names can *decrease* comprehension, the default should be expression-first. □

## Analysis

### Option A: Status Quo — Intent-over-mechanism as one of many patterns

**Description**: Keep [IMPL-000], [IMPL-002], and [IMPL-030] as they are. Intent-over-mechanism is mentioned but not privileged.

**Advantages**: No change required. Flexible.

**Disadvantages**: Contributors treat it as optional. Mechanism-heavy code passes review because no single rule clearly prohibits it. The principle is diluted by being peer-ranked with typed arithmetic rules and accessor patterns.

### Option B: Elevate to Foundational Axiom

**Description**: Make "code reads as intent, not mechanism" the governing axiom. All other implementation rules are corollaries. Add a new requirement [IMPL-INTENT-001] that normatively prefers single-line expressions over separate declarations.

**Advantages**:
- Clear hierarchy: intent is the *why*, typed arithmetic and boundary overloads are the *how*.
- Every code review has a single top-level question: "Does this read as intent?"
- Directly supported by 50+ years of language design convergence, practitioner consensus, and empirical evidence.
- Matches Swift's own trajectory (SE-0255, SE-0380).

**Disadvantages**:
- Could be misapplied as "write everything on one line" without understanding the boundary conditions.
- Requires clear documentation of when intermediate variables *are* justified.

**Mitigation**: The research identifies three clear boundary conditions:
1. The sub-expression is used more than once → extract (as function if possible, variable if necessary).
2. The intermediate name carries genuine explanatory value not present in the expression → extract.
3. The expression exceeds a complexity threshold where composition obscures rather than reveals → extract (but the correct extraction is a named function per Fowler's "Replace Temp with Query").

### Comparison

| Criterion | Option A (Status Quo) | Option B (Foundational Axiom) |
|-----------|----------------------|------------------------------|
| Clarity of hierarchy | Low — peer-ranked | High — governing principle |
| Review guidance | Scattered | Single top-level question |
| Risk of misapplication | Low | Medium (mitigated by boundary conditions) |
| Alignment with prior art | Partial | Complete |
| Alignment with Swift trajectory | Implicit | Explicit |

## Outcome

**Status**: DECISION

**Choice**: Option B — Elevate "code reads as intent, not mechanism" to the foundational axiom of the implementation skill. Add normative preference for single-line expressions over separate variable declarations.

**Rationale**:
1. The principle has 50+ years of convergent support from language designers (Landin, Backus, Dijkstra), practitioners (Beck, Fowler, Martin), and empirical research (Cates et al. 2021).
2. Swift's own evolution (SE-0255, SE-0380) is moving toward expression-oriented style.
3. The Cognitive Dimensions framework formally validates that expression-first style improves closeness-of-mapping and role-expressiveness.
4. The existing implementation skill already states the principle — it just doesn't privilege it.
5. Clear boundary conditions prevent misapplication.

**Implementation path**:
1. Add a new preamble section to the implementation skill establishing intent-over-mechanism as the foundational axiom.
2. Add [IMPL-EXPR-001]: normative preference for single-line expressions.
3. Strengthen [IMPL-030] from SHOULD to MUST (with documented exceptions).
4. Ensure all existing examples in the skill demonstrate the principle.

**Boundary conditions** (must be documented in the skill):
- **Multi-use**: When a sub-expression is used more than once, extraction is justified. Prefer a named function over a local variable.
- **Explanatory name**: When the intermediate name communicates domain knowledge not visible in the expression, the binding is justified.
- **Complexity ceiling**: When expression composition exceeds the point where it reveals intent and begins to obscure it, extract. The correct extraction target is a named function (Fowler's "Replace Temp with Query"), not a local variable.

## References

1. Landin, P.J. (1966). "The Next 700 Programming Languages." *Communications of the ACM*, 9(3), 157-166.
2. Dijkstra, E.W. (1968). "Go To Statement Considered Harmful." *Communications of the ACM*, 11(3), 147-148.
3. Hoare, C.A.R. (1973). "Hints on Programming Language Design." *Keynote, SIGACT/SIGPLAN Symposium on Principles of Programming Languages*.
4. Backus, J. (1978). "Can Programming Be Liberated from the von Neumann Style?" *Communications of the ACM*, 21(8), 613-641.
5. Green, T.R.G. (1989). "Cognitive Dimensions of Notations." *In People and Computers V*, Cambridge University Press, 443-460.
6. Felleisen, M. (1991). "On the Expressive Power of Programming Languages." *Science of Computer Programming*, 17(1-3), 35-75.
7. Beck, K. (1996). *Smalltalk Best Practice Patterns*. Prentice Hall.
8. Green, T.R.G. & Petre, M. (1996). "Usability Analysis of Visual Programming Environments." *JVLC*, 7, 131-174.
9. Blackwell, A.F. & Green, T.R.G. (2001). "Cognitive Dimensions of Notations: Design Tools for Cognitive Technology." *CT 2001*, Springer LNCS.
10. Beck, K. (2007). *Implementation Patterns*. Addison-Wesley.
11. Martin, R.C. (2008). *Clean Code*. Prentice Hall.
12. Fowler, M. (2018). *Refactoring* (2nd ed.). Addison-Wesley.
13. Cates, R., Yunik, N., & Feitelson, D.G. (2021). "Does Code Structure Affect Comprehension?" *ICPC 2021*. arXiv:2103.11008.
14. Endler, M. (2024). "Thinking in Expressions." corrode.dev.
15. Swift Evolution SE-0255 (2019). "Implicit Returns from Single-Expression Functions."
16. Swift Evolution SE-0380 (2023). "if and switch Expressions."
