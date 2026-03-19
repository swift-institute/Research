# Knowledge Encoding as the End-State of Software Development: Literature Review

<!--
---
version: 1.0.0
last_updated: 2026-03-18
status: IN_PROGRESS
tier: 2
---
-->

## Context

Software development has traditionally followed an **island approach**: build isolated software to solve a particular problem. An alternative vision reverses this: what if the goal were to **encode all knowledge as executable code**, following rigorous domain modeling? This would represent a fundamentally different paradigm — software development as knowledge encoding rather than problem-solving.

The Swift Institute and rule-law / swift-law ecosystems embody this latter approach: the five-layer architecture, typed primitives, specification-mirroring names, and statute encoding are all oriented toward **comprehensive domain encoding** rather than building applications. This document surveys the academic and industry literature that supports, explores, or contributes to this vision.

## Question

What intellectual traditions, academic literature, and industry movements support the concept of comprehensive knowledge encoding as executable code — and how do they relate to the Swift Institute approach?

## Analysis

### Tradition 1: Programming as Theory Building

The philosophical foundation comes from **Peter Naur (1985)**, who argued that the primary product of software development is not code but the programmer's *theory* — a complete mental model of how problems map to program execution. Code is merely a lossy written representation. When theory-holders leave, the program decays.

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Peter Naur, "Programming as Theory Building" | 1985 | Microprocessing and Microprogramming | Programs encode theories, not just solutions; the theory is the real product |

**Relevance**: The Swift Institute approach treats code as the *lossless* encoding of theory. Typed primitives, specification-mirroring names ([API-NAME-003]), and the five-layer architecture are all mechanisms for preserving theory in code itself, rather than in programmers' heads.

---

### Tradition 2: Domain-Driven Design & Knowledge Crunching

**Eric Evans (2003)** established that a domain model must be tightly coupled to implementation — it is not separate documentation but a living executable artifact. **Scott Wlaschin (2018)** took this further: use type systems to make illegal states unrepresentable, so business rules become compile-time constraints.

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Eric Evans, *Domain-Driven Design* | 2003 | Addison-Wesley | Ubiquitous language; model IS the implementation; knowledge crunching as iterative discovery |
| Scott Wlaschin, *Domain Modeling Made Functional* | 2018 | Pragmatic Programmers | Algebraic types encode domain rules; illegal states unrepresentable; code = readable documentation |
| Edwin Brady, *Type-Driven Development with Idris* | 2017 | Manning | Dependent types encode invariants in types; compiler verifies domain constraints |
| Debasish Ghosh, *Functional and Reactive Domain Modeling* | 2016 | Manning | Algebras over types as APIs; interpreters as implementations; DDD meets FP |

**Relevance**: The Swift Institute directly implements this tradition. `Property.View.Typed`, phantom-typed indices (`Index<T>`), and typed throws ([API-ERR-001]) are all mechanisms for encoding domain invariants in the type system. The [API-NAME-001] namespace structure (`File.Directory.Walk`) mirrors the domain ontology in the type hierarchy.

---

### Tradition 3: Denotational Design

**Conal Elliott (2009, 2014)** proposed denotational design: give each type a simple mathematical meaning (denotation), then define operations as if they work on meanings. This produced Functional Reactive Programming, where behaviors are functions of continuous time.

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Conal Elliott, "Denotational Design with Type Class Morphisms" | 2009 | Technical report | "The instance's meaning is the meaning's instance" — types have mathematical semantics |
| Conal Elliott, "Denotational Design: From Meanings to Programs" | 2014 | BayHac | Design from denotations is easier than from implementations; meanings capture essence |

**Relevance**: The primitives layer (Layer 1) answers "What must exist?" — this is denotational in spirit. Types like `Buffer`, `Geometry`, `Time` are defined by their mathematical meaning, not by any particular use case.

---

### Tradition 4: Formal Methods & Executable Specifications

A long tradition in formal methods seeks to make specifications *executable* — so the specification IS the program.

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Leslie Lamport, *Specifying Systems* (TLA+) | 2002 | Addison-Wesley | Complete specifications in pure mathematics; same language for "what" and "how" |
| Chris Newcombe et al., "Use of Formal Methods at AWS" | 2014 | Amazon | TLA+ found 10 critical bugs in production designs; formal spec of full behavior is industrially viable |
| J.M. Spivey, *The Z Notation* | 1992 | Prentice Hall | Set-theoretic specification using schemas; mathematical elegance for state modeling |
| C.B. Jones, *Systematic Software Development Using VDM* | 1990 | Prentice Hall | Vienna Development Method; extensive executable subset; spec → code via refinement |
| J.-R. Abrial, *The B-Method* | 1996 | Cambridge UP | Complete development from abstract spec to code via stepwise refinement in single formalism |
| Eric Hehner, *A Practical Theory of Programming* | 1993 | Springer | Specification = boolean expression; refinement = implication; unifies spec and program |

**Relevance**: The Swift Institute's typed primitives and standards layers function as executable specifications. An `RFC_4122.UUID` is simultaneously a specification reference, a type definition, and executable code — collapsing the specification/implementation divide.

---

### Tradition 5: Model-Driven Engineering

MDE envisions modeling a domain's full complexity, then transforming models into complete executable applications.

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| OMG Model-Driven Architecture (MDA) | 2001+ | OMG Standards | Platform-independent models → executable applications via automated transformation |
| Jean Bézivin, "On the Unification Power of Models" | 2005 | SoSyM | Models can unify software engineering as objects unified programming |
| Mellor & Balcer, *Executable UML* | 2002 | Addison-Wesley | Domain model IS the program; tested/validated through execution; generated 2M+ lines of C++ |
| Combemale et al., *Engineering Modeling Languages* | 2017 | CRC Press | End-to-end: domain knowledge → modeling languages → tools (editors, interpreters, generators) |
| Brambilla, Cabot & Wimmer, *Model-Driven Software Engineering in Practice* | 2017 | Springer | Comprehensive MDSE textbook; DSMLs, model transformations, process integration |

**Relevance**: While the Swift Institute doesn't use UML/MDA tooling, the five-layer architecture is structurally similar: each layer encodes domain knowledge at increasing levels of composition, and the type system provides the "transformation" guarantees that MDA sought through model transformations.

---

### Tradition 6: Domain-Specific Languages & Generative Programming

DSLs encode domain knowledge in actionable, executable form. Voelter explicitly notes: "once you have encoded knowledge in source code, execution is pretty much the only thing you can do with it" — DSLs enable analysis, transformation, and verification too.

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Markus Voelter, *DSL Engineering* | 2013 | Self-published | DSLs as knowledge management; seven design dimensions; reusable language paradigms |
| Martin Fowler, *Domain-Specific Languages* | 2010 | Addison-Wesley | Internal/external DSLs; semantic models; adaptive models (rules engines, state machines) |
| Czarnecki & Eisenecker, *Generative Programming* | 2000 | Addison-Wesley | Generative domain models capture concepts + configuration knowledge → manufacture software families |

**Relevance**: The Swift Institute's approach uses the *host language's type system* (Swift) as an internal DSL for domain encoding, rather than building separate external DSLs. The `@Splat` macro pattern, property views, and witness structs are all internal-DSL mechanisms.

---

### Tradition 7: Ontology-Driven Development

Ontologies formalize domain knowledge as categories, properties, and relations — enabling machine reasoning over complete domain models.

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Pan, Staab, Assmann et al. (eds.), *Ontology-Driven Software Development* | 2013 | Springer | Knowledge in ontologies separated from execution logic; dynamically executed specifications |
| Palantir, "Ontology-Oriented Software Development" | ~2023 | Blog | Code operates at domain level (Airplanes, Airports), not rows/columns; ontology centralizes knowledge |
| Gasevic, Djuric & Devedzic, *Model Driven Engineering and Ontology Development* | 2009 | Springer | Formal domain ontologies drive software generation with semantic completeness |

**Relevance**: The Swift Institute's namespace structure ([API-NAME-001]) effectively creates a type-system ontology: `File.Directory.Walk`, `IO.NonBlocking.Selector`, `RFC_4122.UUID` mirror the domain's categorical structure.

---

### Tradition 8: Knowledge-Level Systems

**Allen Newell (1982)** proposed a distinct "knowledge level" above the symbol level: behavior should be describable as a function of knowledge, not data structures.

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Allen Newell, "The Knowledge Level" | 1982 | Artificial Intelligence | Knowledge as a distinct level above symbols; behavior = f(knowledge) |
| Borgida, Mylopoulos & Reiter, "How KR Meets Software Engineering" | 2007 | Automated Software Engineering | KR techniques (description logics, ontological reasoning) for requirements and domain modeling |
| Fensel et al., "The Knowledge Acquisition and Representation Language (KARL)" | 1998 | IEEE TKDE | Human-readable AND machine-executable knowledge representation |

**Relevance**: The five-layer architecture can be read as a knowledge-level hierarchy: primitives encode atomic knowledge, standards encode specified knowledge, foundations encode composed knowledge, components encode opinionated knowledge, applications encode contextual knowledge.

---

### Tradition 9: Computational Law / Rules as Code

The most direct parallel to the Swift Institute's rule-law ecosystem: encoding entire statutory domains as executable specifications.

#### Foundational

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Sergot et al., "The British Nationality Act as a Logic Program" | 1986 | CACM | Seminal: legislation formalized as logic program for automated legal reasoning |
| Kowalski, "Legislation as Logic Programs" | 1995 | Springer | Extended logic-programming approach to systematic statute representation |
| Lawrence Lessig, *Code and Other Laws of Cyberspace* | 1999 | Basic Books | "Code is law" — software architecture regulates behavior as law does |
| Harry Surden, "Computable Contracts" | 2012 | UC Davis Law Review | Contractual obligations as computer data; automated monitoring and compliance |

#### Government Initiatives

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| NZ Service Innovation Lab, *Better Rules Discovery Report* | 2018 | NZ Digital Government | Co-drafting law + code with multidisciplinary teams; encoding reveals gaps in legislation |
| OECD OPSI, "Cracking the Code" | 2020 | OECD Working Papers No. 42 | International primer: machine-consumable versions of government rules alongside natural language |
| Matthew Waddington, "Rules As Code: Drawing Out the Logic of Legislation" | 2022 | SSRN | Legislative drafter encodes during drafting; improves quality without trespassing on interpretation |
| Rapson et al., "Rules as Code for a More Transparent and Efficient Global Economy" | 2025 | CIGI/T7 | G7-level policy brief calling for RaC standardization across jurisdictions |

#### Domain-Specific Languages for Law

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Merigoux, Chataing & Protzenko, "Catala: A Programming Language for the Law" | 2021 | ICFP (ACM PACMPL) | Literate legislative programming; prioritized default logic mirrors statute structure; found bug in French implementation |
| Wong Meng Weng et al., L4 DSL | 2020+ | SMU CCLaw (S$15M NRF) | Functional DSL for legal contracts/legislation; static analysis for consistency/completeness |
| Mowbray, Greenleaf & Chung, "Law as Code: AustLII's DataLex" | 2021 | UNSW Law Research | Quasi-natural-language "yscript" for declarative legal rule representation |
| Allen & Hunn (eds.), *Smart Legal Contracts* | 2022 | Oxford UP | How digital technologies change contract formation; code-based artefacts in legal structures |

#### Standards & Formalization

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Athan, Boley, Governatori et al., OASIS LegalRuleML | 2013/2021 | ICAIL / OASIS Standard | XML standard for normative legal rules; defeasibility, jurisdiction, temporal management |
| Governatori & Hashmi, "Normative Requirements for BPC" | 2013-2015 | Springer | Formal framework: how legal norms impose constraints on business processes |

**Relevance**: The rule-law/swift-law ecosystem is a direct implementation of this tradition, but using Swift's type system rather than logic programming or XML. The `@Splat` pattern, `Bool?` per condition, and `Bool?.any/all` composition implement computational law through algebraic types rather than Prolog-style inference. The statute encoding pattern (1057 Dutch statute packages, 820 NRS packages) demonstrates that comprehensive legislative encoding is feasible at scale.

---

### Tradition 10: Institutional Theory & Normative Positions

A philosophical bridge between law and computation: formalizing how institutional facts are constituted.

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| John Searle, *The Construction of Social Reality* | 1995 | Free Press | "X counts as Y in context C" — constitutive rules create institutional facts; amenable to encoding |
| Sergot & Jones, "A Computational Theory of Normative Positions" | 2001 | ACM TOCL | Hohfeld/Kanger normative positions (rights, duties, powers) formalized computationally |

**Relevance**: The legal encoding ecosystem's four-layer architecture (legislature → judiciary → composition → products) mirrors Searle's constitutive rules: statutes define what counts as what, judicial decisions apply those definitions, and the composition layer assembles institutional facts.

---

### Tradition 11: Category Theory & Compositionality

Category theory provides the mathematical foundation for composition — the core operation in knowledge-encoding systems.

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Bartosz Milewski, *Category Theory for Programmers* | 2019 | Self-published | Composition as essence of both categories and software; objects defined by interactions |
| Fong & Spivak, *Seven Sketches in Compositionality* | 2019 | Cambridge UP | Applied CT for real-world domains (databases, circuits, dynamical systems) |
| Diskin, Xiong & Czarnecki, "Category Theory and MDE" | 2012 | arXiv | Category-theoretic constructs (colimits, pushouts) formalize model composition |

**Relevance**: The five-layer architecture is a compositional hierarchy: each layer composes knowledge from below. Typed arithmetic, boundary overloads, and the `Index<T>` / `Offset` / `Count` system are all algebraic structures that compose according to categorical laws.

---

### Tradition 12: Literate Programming & Knowledge Preservation

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Donald Knuth, "Literate Programming" | 1984 | The Computer Journal | Programs as literature; code and explanation unified in one artifact; knowledge preservation |

**Relevance**: The Swift Institute's documentation skill ([DOC-*]) and the Catala-like literate quality of statute encoding (where article structure mirrors code structure) inherit this tradition.

---

### Tradition 13: Digital Twins & Comprehensive Simulation

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Michael Grieves, "Digital Twin" concept | 2003/2014 | White paper | Comprehensive virtual replica with bidirectional data flow; all models describe the physical object |
| "The Executable Digital Twin" | 2022 | arXiv | Self-contained executable model extracted from comprehensive twin for real-time simulation |

**Relevance**: The digital twin is the engineering-world equivalent of comprehensive knowledge encoding: model *everything* about a physical system, then derive applications from the model. The Swift Institute's approach is the software-world analog.

---

### Tradition 14: Simplicity & Composition

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Rich Hickey, "Simple Made Easy" | 2011 | Strange Loop | Simple ≠ easy; compose simple, known-to-work components; avoid intertwining |
| Rich Hickey, "Design, Composition, and Performance" | 2013 | QCon | Modular, composable, value-oriented design over complex hierarchies |

**Relevance**: The primitives layer embodies this — 61 atomic packages in 9 tiers, each simple and composable. The "no Foundation" rule ([PRIM-FOUND-001]) is a direct application of simplicity-as-independence.

---

### Tradition 15: Curry-Howard Correspondence

The theoretical foundation for treating types as knowledge: propositions correspond to types, proofs to programs.

| Source | Year | Venue | Key Contribution |
|--------|------|-------|-----------------|
| Philip Wadler, "Propositions as Types" | 2015 | CACM | Definitive survey: types = propositions, programs = proofs, evaluation = proof simplification |
| Pierce et al., *Software Foundations* | 2007+ | U. Penn | "Checking that an alleged proof is valid just amounts to type-checking the term" |

**Relevance**: The Swift Institute's type-driven approach implicitly relies on this correspondence: encoding domain invariants as types means the compiler *proves* they hold. Typed throws ([API-ERR-001]), phantom-typed indices, and ~Copyable ownership all leverage types-as-propositions.

---

## Synthesis: The Converging Vision

These 15 traditions converge on a single insight: **software development's end-state is not building applications but encoding knowledge**.

### The Traditional Model (Island Approach)

```
Problem → Requirements → Design → Code → Application
```

Each application is an island: built for a specific problem, with knowledge embedded implicitly in code that serves one purpose.

### The Knowledge-Encoding Model (End-State)

```
Domain → Executable Knowledge → Derived Applications
```

Knowledge is encoded once, completely, and applications are derived from the knowledge base. This is what the Swift Institute implements:

| Layer | Knowledge Function | Tradition |
|-------|-------------------|-----------|
| Primitives | "What must exist?" — atomic domain concepts | Denotational Design, Knowledge Level |
| Standards | "What is specified?" — external knowledge encoded | Formal Methods, Specification-as-Code |
| Foundations | "What composes?" — composed knowledge | Category Theory, Compositionality |
| Components | "What is opinionated?" — curated assemblies | Domain-Driven Design, Generative Programming |
| Applications | "What serves users?" — derived products | Traditional software development |

The legal encoding ecosystem makes this even more explicit:

| Layer | Knowledge Function | Tradition |
|-------|-------------------|-----------|
| Legislature encoding | Statute text → typed Swift code | Computational Law, Rules as Code |
| Judiciary encoding | Case law → typed Swift code | Normative Positions, Institutional Theory |
| Composition | Cross-statute integration | Ontology-Driven Development |
| Products | Legal applications | Traditional software development |

### Key Differentiators from Traditional Software

1. **Domain completeness over consumer counting** — Types exist because the domain requires them, not because an application needs them
2. **Specification-mirroring names** — Code structure mirrors the knowledge domain's structure, not the application's architecture
3. **Typed invariants** — Domain rules encoded as type constraints, verified by the compiler
4. **Layered composition** — Knowledge composes upward through well-defined algebraic boundaries
5. **Timeless infrastructure** — Each decision treated as permanent; knowledge persists across applications

---

## Outcome

**Status**: IN_PROGRESS

This literature review establishes that the Swift Institute's approach draws from at least 15 distinct intellectual traditions, all converging on the vision of software-as-knowledge-encoding. The approach is not unprecedented — it synthesizes decades of work in DDD, formal methods, computational law, type theory, and ontological engineering.

### Identified Gaps for Further Investigation

1. **No unified theory** — These traditions exist in silos. No single academic work synthesizes them into a coherent "end-state" theory of software development. This could be a contribution.
2. **Scale evidence** — The Swift Institute (61 primitives packages, 1057 statute packages) may be one of the largest real-world implementations of this vision. Documenting the practical challenges would be valuable.
3. **Composition theory** — How knowledge from different domains composes (e.g., legal + financial) is underexplored in the literature.
4. **LLM implications** — How comprehensive knowledge encoding interacts with AI-assisted development is an emerging area (cf. arXiv:2502.10708).

## References

### Philosophical Foundations
- Naur, P. (1985). "Programming as Theory Building." *Microprocessing and Microprogramming*, 15(5).
- Newell, A. (1982). "The Knowledge Level." *Artificial Intelligence*, 18(1).
- Searle, J. (1995). *The Construction of Social Reality*. Free Press.
- Wadler, P. (2015). "Propositions as Types." *Communications of the ACM*, 58(12), 75-84.

### Domain-Driven Design
- Evans, E. (2003). *Domain-Driven Design: Tackling Complexity in the Heart of Software*. Addison-Wesley.
- Wlaschin, S. (2018). *Domain Modeling Made Functional*. Pragmatic Programmers.
- Brady, E. (2017). *Type-Driven Development with Idris*. Manning.
- Ghosh, D. (2016). *Functional and Reactive Domain Modeling*. Manning.

### Denotational Design
- Elliott, C. (2009). "Denotational Design with Type Class Morphisms." Technical report.
- Elliott, C. (2014). "Denotational Design: From Meanings to Programs." BayHac 2014.

### Formal Methods
- Lamport, L. (2002). *Specifying Systems: The TLA+ Language*. Addison-Wesley.
- Newcombe, C. et al. (2014). "Use of Formal Methods at Amazon Web Services."
- Abrial, J.-R. (1996). *The B Book*. Cambridge University Press.
- Hehner, E.C.R. (1993). *A Practical Theory of Programming*. Springer.
- Spivey, J.M. (1992). *The Z Notation*. Prentice Hall.
- Jones, C.B. (1990). *Systematic Software Development Using VDM*. Prentice Hall.

### Model-Driven Engineering
- Bézivin, J. (2005). "On the Unification Power of Models." *SoSyM*, 4, 171-188.
- Mellor, S.J. & Balcer, M.J. (2002). *Executable UML*. Addison-Wesley.
- Combemale, B. et al. (2017). *Engineering Modeling Languages*. CRC Press.
- Brambilla, M., Cabot, J. & Wimmer, M. (2017). *MDSE in Practice*. Springer.

### DSLs & Generative Programming
- Voelter, M. (2013). *DSL Engineering*. Self-published.
- Fowler, M. (2010). *Domain-Specific Languages*. Addison-Wesley.
- Czarnecki, K. & Eisenecker, U.W. (2000). *Generative Programming*. Addison-Wesley.

### Ontology-Driven Development
- Pan, J.Z. et al. (eds.) (2013). *Ontology-Driven Software Development*. Springer.
- Gasevic, D. et al. (2009). *Model Driven Engineering and Ontology Development*. Springer.
- Borgida, A. et al. (2007). "How KR Meets Software Engineering." *Automated Software Engineering*.

### Computational Law
- Sergot, M. et al. (1986). "The British Nationality Act as a Logic Program." *CACM*, 29(5), 370-386.
- Kowalski, R. (1995). "Legislation as Logic Programs." Springer.
- Lessig, L. (1999). *Code and Other Laws of Cyberspace*. Basic Books.
- Merigoux, D. et al. (2021). "Catala: A Programming Language for the Law." *ICFP 2021*.
- Wong, M.W. et al. (2020+). L4: A Domain Specific Language for Legal. SMU CCLaw.
- Waddington, M. (2022). "Rules As Code: Drawing Out the Logic of Legislation." SSRN.
- OECD OPSI (2020). "Cracking the Code: Rulemaking for Humans and Machines." Working Paper No. 42.
- NZ Service Innovation Lab (2018). *Better Rules for Government Discovery Report*.
- Surden, H. (2012). "Computable Contracts." *UC Davis Law Review*, 46.
- Allen, J. & Hunn, P. (eds.) (2022). *Smart Legal Contracts*. Oxford UP.
- Athan, T. et al. (2013/2021). OASIS LegalRuleML Core Specification v1.0.
- Mowbray, A. et al. (2021). "Law as Code: AustLII's DataLex." UNSW Law Research.
- Sergot, M. & Jones, A.J.I. (2001). "A Computational Theory of Normative Positions." *ACM TOCL*.

### Category Theory & Compositionality
- Milewski, B. (2019). *Category Theory for Programmers*.
- Fong, B. & Spivak, D.I. (2019). *Seven Sketches in Compositionality*. Cambridge UP.
- Diskin, Z. et al. (2012). "Category Theory and Model-Driven Engineering." arXiv:1209.1433.

### Knowledge Representation
- Fensel, D. et al. (1998). "KARL." *IEEE TKDE*.
- Debenham, J. (1998). "Representing Software Engineering Knowledge." *Automated Software Engineering*.
- Barstow, D. (1987). "Knowledge-Based Software Development." Springer LNCS.

### Digital Twins
- Grieves, M. (2003/2014). "Digital Twin: Manufacturing Excellence through Virtual Factory Replication."
- "The Executable Digital Twin" (2022). arXiv:2210.17402.

### Literate Programming
- Knuth, D.E. (1984). "Literate Programming." *The Computer Journal*, 27(2).

### Simplicity & Composition
- Hickey, R. (2011). "Simple Made Easy." Strange Loop Conference.
- Hickey, R. (2013). "Design, Composition, and Performance." QCon.

### Software Foundations
- Pierce, B.C. et al. (2007+). *Software Foundations*. University of Pennsylvania.
