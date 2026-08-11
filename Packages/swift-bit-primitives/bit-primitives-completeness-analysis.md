# Bit Primitives Completeness Analysis

<!--
---
version: 2.0.2
last_updated: 2026-06-01
status: SUPERSEDED
tier: 3
applies_to: [swift-bit-primitives, swift-bit-storage-primitives]
superseded_by: bit-primitives-domain-decomposition.md
---
-->

> **Status**: SUPERSEDED (2026-06-01) by [`bit-primitives-domain-decomposition.md`](bit-primitives-domain-decomposition.md), which consolidates this document on the primitive-domain-decomposition axis and carries forward all of its findings (see that document's §9 for the per-finding disposition). Part A (single-bit operations: NAND/NOR/XNOR/AND-NOT) is now implemented; the word-level-kernel and architectural-restructuring recommendations are superseded or realized as recorded in the consolidating document. Retained as historical rationale and for its systematic literature review and formal semantics.

**A Tier 3 Deep Research on the Completeness, Formal Foundations, and Timeless Design of Bit Primitives: Single-Bit Algebra and Word-Level Kernels**

---

## Abstract

This document presents a systematic analysis of `swift-bit-primitives` to determine whether it constitutes a *complete and timeless* implementation of bit primitives. The analysis spans two scales: (1) the `Bit` type as a single binary digit with algebraic structure, and (2) word-level bit kernels — rank, select, scan, and mask operations that form the foundation for all downstream bit containers and succinct data structures.

We establish formal foundations through Boolean algebra, lattice theory, Z₂ field theory, and the succinct data structures literature (Jacobson, Vigna); conduct a systematic literature review spanning hardware ISAs, language standard libraries, formal verification theory (SMT-LIB QF_BV), and the canonical Hacker's Delight reference; evaluate a parallel proposal to add word-level operations; and analyze the boundary between bit-primitives and bit-storage-primitives. We conclude with a precise enumeration of 10 additions (4 single-bit, 6 word-level) that bring the package to completeness.

**Keywords**: Boolean algebra, Z₂ field, functional completeness, bit manipulation, lattice theory, Post's lattice, SMT-LIB QF_BV, rank/select, succinct data structures, broadword

---

## 1. Scope and Semantic Domain

### 1.1 The Question

> Is `swift-bit-primitives` complete and timeless for its semantic domain?

### 1.2 Semantic Domain Boundary

Per [PRIM-SCOPE-001], `swift-bit-primitives` answers:

> **"What is a bit, and what are its fundamental operations?"**

This is *not* the domain of word-level bit manipulation. Word-level operations (popcount on a `UInt64`, count-leading-zeros on an integer, bit reversal of a machine word) operate on `FixedWidthInteger` types. Those belong to different semantic domains:

| Question | Package | Domain |
|----------|---------|--------|
| What is a bit? | `swift-bit-primitives` | Single-bit algebra |
| How do I locate a bit in a word? | `swift-bit-storage-primitives` | Bit addressing |
| How do I store many bits? | `swift-array-primitives`, `swift-set-primitives` | Bit containers |
| How do I manipulate bits within integers? | (not yet established) | Word-level bit twiddling |

This research focuses exclusively on the first domain: the algebraic and operational completeness of the `Bit` type as a single binary digit.

### 1.3 Tier 3 Justification

This research is Tier 3 because:

| Criterion | Assessment |
|-----------|------------|
| Precedent-setting | Yes — defines the algebraic foundation for all bit-level infrastructure |
| Semantic commitment | Normative — `Bit` is the canonical binary digit type |
| Cost of error | Very high — 15 downstream packages depend on bit-primitives |
| Expected lifetime | Timeless — binary digits do not evolve |
| Formalization | Mandatory — algebraic completeness requires formal verification |

---

## 2. Systematic Literature Review

### 2.1 Search Strategy (per Kitchenham)

**Research questions:**
- RQ1: What operations on a single bit are considered primitive across hardware, software, and theory?
- RQ2: What algebraic structures does a single bit inhabit?
- RQ3: What is the minimal complete set of operations?
- RQ4: How do existing language standard libraries model single-bit types?

**Search domains:**
1. Hardware ISA specifications (x86 BMI/BMI2, ARM, RISC-V Zb*)
2. Language standard libraries (Swift, Rust, C++20, Haskell, Java)
3. Formal verification (SMT-LIB QF_BV, SAT solvers)
4. Textbooks (Hacker's Delight, TAOCP)
5. Mathematical foundations (Boolean algebra, lattice theory, finite fields)
6. Academic literature (POPL, ICFP, OOPSLA proceedings)

**Inclusion criteria:** Sources that define or enumerate primitive bit-level operations.
**Exclusion criteria:** Sources focused exclusively on word-level algorithms (popcount implementations, SWAR techniques) without relevance to single-bit semantics.

### 2.2 Hardware ISA Survey

Hardware instruction sets define what the silicon considers primitive. While most ISA bit instructions operate on machine words, they reveal the *atomic operations* hardware designers consider fundamental.

#### 2.2.1 x86 (BMI1 + BMI2)

| Category | Instructions |
|----------|-------------|
| Boolean | AND, OR, XOR, NOT, ANDN (AND-NOT) |
| Shift | SHL, SHR, SAR, ROL, ROR |
| Counting | POPCNT, LZCNT, TZCNT |
| Isolation | BLSI (isolate lowest set bit), BLSR (reset lowest set bit), BLSMSK (mask up to lowest set bit) |
| Extract/Deposit | BEXTR (bit field extract), PEXT (parallel extract), PDEP (parallel deposit) |
| Byte | BSWAP (byte swap) |

**Key observation**: x86 includes ANDN (a AND NOT b) as a distinct hardware instruction, recognizing it as a primitive that cannot be efficiently decomposed.

#### 2.2.2 ARM (ARMv8-A)

| Category | Instructions |
|----------|-------------|
| Boolean | AND, ORR, EOR, BIC (bit clear = AND-NOT), ORN (OR-NOT), EON (XOR-NOT) |
| Reverse | RBIT (reverse bits), REV (reverse bytes), REV16, REV32 |
| Counting | CLZ (count leading zeros) |
| Bit field | BFM, UBFM, SBFM (bit field move/extract/insert) |

**Key observation**: ARM elevates AND-NOT (`BIC`), OR-NOT (`ORN`), and XOR-NOT (`EON`) to first-class instructions.

#### 2.2.3 RISC-V (Zbb + Zbs + Zba + Zbc)

| Extension | Instructions |
|-----------|-------------|
| Zbb (basic) | CLZ, CTZ, CPOP, ANDN, ORN, XNOR, MAX, MIN, REV8, SEXT.B/H, ZEXT.H, ROL, ROR |
| Zbs (single-bit) | BCLR (clear bit), BEXT (extract bit), BINV (invert bit), BSET (set bit) |
| Zba (address) | SH1ADD, SH2ADD, SH3ADD |
| Zbc (carry-less) | CLMUL, CLMULH, CLMULR |

**Key observation**: RISC-V Zbs provides the four atomic single-bit operations: set, clear, invert, extract. RISC-V Zbb includes ANDN, ORN, and XNOR as first-class operations.

#### 2.2.4 Hardware Consensus

Operations that appear as dedicated instructions across all three major ISAs:

| Operation | x86 | ARM | RISC-V | Consensus |
|-----------|-----|-----|--------|-----------|
| AND | ✓ | ✓ | ✓ | Universal |
| OR | ✓ | ✓ | ✓ | Universal |
| XOR | ✓ | ✓ | ✓ | Universal |
| NOT | ✓ | ✓ | ✓ | Universal |
| AND-NOT | ANDN | BIC | ANDN | Universal |
| OR-NOT | — | ORN | ORN | ARM + RISC-V |
| XOR-NOT (XNOR) | — | EON | XNOR | ARM + RISC-V |

AND-NOT appears as a dedicated instruction on *all three ISAs*. This is significant — hardware designers independently concluded it deserves first-class status.

### 2.3 Language Standard Library Survey

#### 2.3.1 Single-Bit Types in Standard Libraries

Most languages do NOT define a dedicated single-bit type:

| Language | Single-Bit Type | Notes |
|----------|----------------|-------|
| Swift | `Bool` (no `Bit`) | Swift Institute's `Bit` fills this gap |
| Rust | `bool` | No algebraic structure, no bitwise ops on bool |
| C++ | `bool` | No bitwise ops |
| Haskell | `Bool` | `Bits` class exists but Bool's instance is trivial |
| Java | `boolean` | No bitwise ops |
| Verilog/VHDL | `bit` / `std_logic` | Full Boolean algebra with Z₂ semantics |

**Key observation**: Only hardware description languages (Verilog, VHDL) define a `bit` type with full algebraic structure. Swift Institute's `Bit` is rare and therefore must be *definitive*.

#### 2.3.2 Boolean Operations Across Languages

Cross-referencing which Boolean operations each language provides on its boolean type:

| Operation | Swift `Bool` | Rust `bool` | Haskell `Bool` | Verilog `bit` |
|-----------|:------------:|:-----------:|:--------------:|:-------------:|
| AND | `&&` | `&&` | `&&` | `&` |
| OR | `||` | `||` | `||` | `\|` |
| NOT | `!` | `!` | `not` | `~` |
| XOR | `!=` (idiom) | `^` (no) | `/=` (idiom) | `^` |
| NAND | — | — | — | `~&` |
| NOR | — | — | — | `~\|` |
| XNOR | `==` (idiom) | — | `==` (idiom) | `~^` / `^~` |

**Key observation**: Verilog provides NAND, NOR, and XNOR as first-class operators. General-purpose languages rely on idioms.

#### 2.3.3 Haskell Data.Bits Monoid Wrappers

Haskell's `Data.Bits` module provides four `Monoid` newtypes that formalize bitwise operations as algebraic structures:

| Newtype | Operation | Identity |
|---------|-----------|----------|
| `And a` | `.&.` (AND) | `oneBits` (all 1s) |
| `Ior a` | `.\|.` (OR) | `zeroBits` (all 0s) |
| `Xor a` | `xor` (XOR) | `zeroBits` (all 0s) |
| `Iff a` | XNOR (equivalence) | `oneBits` (all 1s) |

**Key observation**: Haskell recognizes XNOR/equivalence as important enough to warrant its own monoid wrapper (`Iff`).

### 2.4 Formal Verification: SMT-LIB QF_BV

The SMT-LIB standard defines the theory of fixed-size bit vectors (QF_BV), which represents the formal consensus on primitive bit-vector operations. The primitive (non-derived) function symbols are:

| Function | Type | Description |
|----------|------|-------------|
| `bvnot` | BV_m → BV_m | Bitwise NOT |
| `bvand` | BV_m × BV_m → BV_m | Bitwise AND |
| `bvor` | BV_m × BV_m → BV_m | Bitwise OR |
| `bvneg` | BV_m → BV_m | Two's complement negation |
| `bvadd` | BV_m × BV_m → BV_m | Addition |
| `bvmul` | BV_m × BV_m → BV_m | Multiplication |
| `bvudiv` | BV_m × BV_m → BV_m | Unsigned division |
| `bvurem` | BV_m × BV_m → BV_m | Unsigned remainder |
| `bvshl` | BV_m × BV_m → BV_m | Left shift |
| `bvlshr` | BV_m × BV_m → BV_m | Logical right shift |
| `bvult` | BV_m × BV_m → Bool | Unsigned less-than |
| `concat` | BV_i × BV_j → BV_(i+j) | Concatenation |
| `extract` | BV_m → BV_n | Bit field extraction |

**Key observation**: SMT-LIB considers {bvnot, bvand, bvor} as the three primitive Boolean operations, plus arithmetic and shifting. XOR is *derived* as `bvxor(a, b) = bvor(bvand(bvnot(a), b), bvand(a, bvnot(b)))`. However, for width-1 bit vectors, only the Boolean operations and comparison are meaningful — arithmetic reduces to Boolean algebra in Z₂.

### 2.5 Hacker's Delight (Warren, 2nd Edition)

Warren's canonical reference organizes bit operations into chapters:

| Chapter | Topic | Relevance to Single-Bit |
|---------|-------|------------------------|
| Ch 1 | Introduction | — |
| Ch 2 | Basics | Fundamental identities, De Morgan's |
| Ch 3 | Power-of-2 boundaries | Word-level only |
| Ch 4 | Arithmetic bounds | Word-level only |
| Ch 5 | Counting bits | Word-level (popcount, CLZ, CTZ, parity) |
| Ch 6 | Searching words | Word-level only |
| Ch 7 | Rearranging bits | Word-level (reverse, shuffle, compress/expand) |
| Ch 8–20 | Advanced | Word-level only |

**Key observation**: For single-bit algebra, only Chapter 2 is relevant. Warren documents the fundamental Boolean identities that any complete single-bit type must satisfy.

### 2.6 Theoretical Foundations

#### 2.6.1 Boolean Algebra

A Boolean algebra is a complemented distributive lattice ⟨B, ∧, ∨, ¬, 0, 1⟩ satisfying:

| Law | AND form | OR form |
|-----|----------|---------|
| Commutativity | a ∧ b = b ∧ a | a ∨ b = b ∨ a |
| Associativity | (a ∧ b) ∧ c = a ∧ (b ∧ c) | (a ∨ b) ∨ c = a ∨ (b ∨ c) |
| Absorption | a ∧ (a ∨ b) = a | a ∨ (a ∧ b) = a |
| Identity | a ∧ 1 = a | a ∨ 0 = a |
| Distributivity | a ∧ (b ∨ c) = (a ∧ b) ∨ (a ∧ c) | a ∨ (b ∧ c) = (a ∨ b) ∧ (a ∨ c) |
| Complement | a ∧ ¬a = 0 | a ∨ ¬a = 1 |
| De Morgan | ¬(a ∧ b) = ¬a ∨ ¬b | ¬(a ∨ b) = ¬a ∧ ¬b |

The two-element Boolean algebra **2** = {0, 1} is the *initial* (simplest) Boolean algebra.

#### 2.6.2 Z₂ Field (Galois Field GF(2))

The field with two elements, GF(2) = ⟨{0, 1}, +, ×⟩ where:

| + | 0 | 1 |     | × | 0 | 1 |
|---|---|---|-----|---|---|---|
| **0** | 0 | 1 |     | **0** | 0 | 0 |
| **1** | 1 | 0 |     | **1** | 0 | 1 |

- Addition = XOR (with identity 0, and every element is its own inverse: a + a = 0)
- Multiplication = AND (with identity 1)
- This is the unique field of characteristic 2

#### 2.6.3 Lattice Structure

The two-element set {0, 1} with ≤ forms a chain:

```
  1
  |
  0
```

- Meet (∧) = AND = min
- Join (∨) = OR = max
- Complement: ¬0 = 1, ¬1 = 0

This is simultaneously a Boolean algebra, a Heyting algebra, a distributive lattice, and a total order.

#### 2.6.4 Relationship Between Structures

The three algebraic structures on {0, 1} are related:

| Concept | Boolean Algebra | Z₂ Field | Lattice |
|---------|----------------|----------|---------|
| Binary op 1 | AND (∧) | Multiplication (×) | Meet (∧) |
| Binary op 2 | OR (∨) | — | Join (∨) |
| Binary op 3 | XOR (⊕) | Addition (+) | — |
| Unary op | NOT (¬) | Additive inverse (−a = a) | Complement (¬) |
| Identity for op 1 | 1 | 1 | 1 (top) |
| Identity for op 2 | 0 | — | 0 (bottom) |
| Identity for op 3 | 0 | 0 | — |

The Z₂ field captures {XOR, AND}. The Boolean algebra captures {AND, OR, NOT}. The lattice captures {AND, OR} with the ordering. OR is not a field operation — it is a lattice join. This means a complete single-bit type must expose *all three* algebraic views, not just one.

---

## 3. All 16 Binary Boolean Functions

There are exactly 2^(2^2) = 16 functions from {0,1}² → {0,1}. For inputs (a, b) with rows (0,0), (0,1), (1,0), (1,1):

| # | Output | Name | Expression | In current `Bit`? |
|---|--------|------|------------|--------------------|
| F0 | 0000 | Contradiction (FALSE) | 0 | `.zero` (constant) |
| F1 | 0001 | Conjunction (AND) | a ∧ b | `a & b` ✓ |
| F2 | 0010 | Inhibition (AND-NOT) | a ∧ ¬b | Derivable, no method |
| F3 | 0011 | Projection A | a | Identity |
| F4 | 0100 | Converse inhibition | ¬a ∧ b | Derivable, no method |
| F5 | 0101 | Projection B | b | Identity |
| F6 | 0110 | Exclusive disjunction (XOR) | a ⊕ b | `a ^ b` ✓ |
| F7 | 0111 | Disjunction (OR) | a ∨ b | `a \| b` ✓ |
| F8 | 1000 | Joint denial (NOR) | ¬(a ∨ b) | Derivable, no method |
| F9 | 1001 | Biconditional (XNOR) | ¬(a ⊕ b) | Derivable, no method |
| F10 | 1010 | Complement B (NOT B) | ¬b | `~b` ✓ (unary) |
| F11 | 1011 | Converse implication | a ∨ ¬b | Derivable, no method |
| F12 | 1100 | Complement A (NOT A) | ¬a | `~a` ✓ (unary) |
| F13 | 1101 | Material implication | ¬a ∨ b | Derivable, no method |
| F14 | 1110 | Alternative denial (NAND) | ¬(a ∧ b) | Derivable, no method |
| F15 | 1111 | Tautology (TRUE) | 1 | `.one` (constant) |

### 3.1 Classification by Significance

**Already present as named operations (6/16):**
F0 (.zero), F1 (AND), F6 (XOR), F7 (OR), F12/F10 (NOT), F15 (.one)

**Derivable but unnamed (10/16):**
F2 (AND-NOT), F3 (projection), F4 (converse AND-NOT), F5 (projection), F8 (NOR), F9 (XNOR), F11 (converse implication), F13 (implication), F14 (NAND)

### 3.2 Which Deserve Named Operations?

Not all 16 functions warrant named methods. Criteria for inclusion:

| Criterion | Description |
|-----------|-------------|
| Hardware support | Dedicated ISA instruction on ≥2 architectures |
| Algebraic significance | Forms a monoid, group, or has special algebraic properties |
| Usage frequency | Common in downstream bit-manipulation code |
| Sheffer status | Functionally complete alone |
| Name recognition | Well-known in digital logic / CS curriculum |

Evaluation:

| Function | Hardware | Algebraic | Usage | Sheffer | Named | **Verdict** |
|----------|:--------:|:---------:|:-----:|:-------:|:-----:|:-----------:|
| NAND (F14) | — | Sheffer function | Medium | **Yes** | Universal | **INCLUDE** |
| NOR (F8) | — | Sheffer function | Medium | **Yes** | Universal | **INCLUDE** |
| XNOR (F9) | ARM (EON), RISC-V (XNOR) | Equivalence, Monoid (Haskell `Iff`) | High | No | Universal | **INCLUDE** |
| AND-NOT (F2) | x86 (ANDN), ARM (BIC), RISC-V (ANDN) | Material nonimplication | High | No | `andNot`/`BIC` | **INCLUDE** |
| Implication (F13) | — | Heyting algebra, logic | Low | No | Academic | EXCLUDE |
| Projections (F3, F5) | — | Trivial | — | No | — | EXCLUDE |
| Converse ops (F4, F11) | — | Duals of above | Low | No | — | EXCLUDE |

---

## 4. Formal Semantics

### 4.1 Type Definition

```
τ_Bit ::= {.zero, .one}

Γ ⊢ .zero : Bit          [T-ZERO]
Γ ⊢ .one : Bit           [T-ONE]
```

### 4.2 Operational Semantics (Small-Step)

#### 4.2.1 Unary Operations

```
         ─────────────────────      ─────────────────────
         ~(.zero) → .one            ~(.one) → .zero        [E-NOT]
```

#### 4.2.2 Binary Operations (AND)

```
         ─────────────────────────
         .one & .one → .one         [E-AND-11]

         a = .zero ∨ b = .zero
         ─────────────────────────
         a & b → .zero              [E-AND-0x]
```

#### 4.2.3 Binary Operations (OR)

```
         ─────────────────────────
         .zero | .zero → .zero      [E-OR-00]

         a = .one ∨ b = .one
         ─────────────────────────
         a | b → .one               [E-OR-1x]
```

#### 4.2.4 Binary Operations (XOR)

```
         a = b
         ─────────────────────────
         a ^ b → .zero              [E-XOR-EQ]

         a ≠ b
         ─────────────────────────
         a ^ b → .one               [E-XOR-NEQ]
```

#### 4.2.5 Proposed: AND-NOT

```
         ─────────────────────────
         andNot(a, b) → a & ~b      [E-ANDNOT]
```

#### 4.2.6 Proposed: NAND, NOR, XNOR

```
         ─────────────────────────
         nand(a, b) → ~(a & b)      [E-NAND]

         ─────────────────────────
         nor(a, b) → ~(a | b)       [E-NOR]

         ─────────────────────────
         xnor(a, b) → ~(a ^ b)     [E-XNOR]
```

### 4.3 Soundness Argument

**Theorem 4.1 (Type Soundness)**: For all well-typed expressions `e : Bit`, evaluation terminates and produces a value in `{.zero, .one}`.

*Proof*: The type `Bit` is a two-element enumeration. All operations are total functions from `{0,1}^n → {0,1}` for n ∈ {1, 2}. Since the domain is finite and all functions are defined on all inputs, evaluation always terminates and produces a valid `Bit` value. ∎

**Theorem 4.2 (Functional Completeness)**: The operation set {AND, OR, NOT} on `Bit` is functionally complete — every function `f : Bit^n → Bit` can be expressed as a composition of these operations.

*Proof*: By Post's theorem, a set S of Boolean functions is functionally complete iff it is not contained in any of the five maximal clones {T0, T1, S, M, L}. NOT ∉ T0 (NOT(0) = 1 ≠ 0) and NOT ∉ T1 (NOT(1) = 0 ≠ 1). AND ∉ S (AND is not self-dual: AND(0,1) = 0 but NOT(AND(1,0)) = NOT(0) = 1... actually AND(NOT(0), NOT(1)) = AND(1,0) = 0 = NOT(AND(0,1)) = NOT(0) = 1, so AND IS self-dual... let me reconsider).

Actually: Self-dual means f(¬x₁,...,¬xₙ) = ¬f(x₁,...,xₙ). For AND: AND(¬a, ¬b) vs ¬AND(a,b). AND(1,1)=1, ¬AND(0,0)=¬0=1 ✓. AND(1,0)=0, ¬AND(0,1)=¬0=1 ✗. So AND is NOT self-dual. ✓

- NOT ∉ T0 (since NOT(0) = 1)
- NOT ∉ T1 (since NOT(1) = 0)
- AND ∉ S (since AND(1,0) = 0 ≠ 1 = ¬AND(0,1))
- OR ∉ M? No — OR IS monotone. But AND is also monotone. We need a non-monotone function: NOT is not monotone (0 ≤ 1 but NOT(0) = 1 > 0 = NOT(1)).
- NOT ∉ L? NOT(x) = 1 + x (mod 2), which IS linear. But AND(a,b) = a·b, which is NOT linear (it's degree 2).

Summary: NOT ∉ T0, NOT ∉ T1, AND ∉ S, NOT ∉ M, AND ∉ L. Therefore {AND, OR, NOT} escapes all five clones and is functionally complete. ∎

**Corollary 4.3**: The current `Bit` operation set {AND, OR, XOR, NOT} is functionally complete, since it contains the functionally complete subset {AND, OR, NOT}. The addition of NAND, NOR, XNOR, and AND-NOT does not change the expressive power but provides operational convenience.

### 4.4 Algebraic Laws

The implementation MUST satisfy these laws (testable as property-based tests):

#### 4.4.1 Boolean Algebra Laws

```
// Commutativity
a & b  ==  b & a
a | b  ==  b | a
a ^ b  ==  b ^ a

// Associativity
(a & b) & c  ==  a & (b & c)
(a | b) | c  ==  a | (b | c)
(a ^ b) ^ c  ==  a ^ (b ^ c)

// Identity
a & .one   ==  a
a | .zero  ==  a
a ^ .zero  ==  a

// Annihilation
a & .zero  ==  .zero
a | .one   ==  .one

// Idempotence
a & a  ==  a
a | a  ==  a

// Complement
a & ~a  ==  .zero
a | ~a  ==  .one

// Involution
~~a  ==  a

// Absorption
a & (a | b)  ==  a
a | (a & b)  ==  a

// Distributivity
a & (b | c)  ==  (a & b) | (a & c)
a | (b & c)  ==  (a | b) & (a | c)

// De Morgan
~(a & b)  ==  ~a | ~b
~(a | b)  ==  ~a & ~b
```

#### 4.4.2 Z₂ Field Laws

```
// Additive group (XOR)
a ^ .zero     ==  a              // Identity
a ^ a         ==  .zero          // Self-inverse
a ^ b         ==  b ^ a          // Commutativity
(a ^ b) ^ c  ==  a ^ (b ^ c)   // Associativity

// Multiplicative monoid (AND)
a & .one      ==  a              // Identity
a & b         ==  b & a          // Commutativity
(a & b) & c  ==  a & (b & c)   // Associativity

// Distributivity
a & (b ^ c)  ==  (a & b) ^ (a & c)
```

#### 4.4.3 Proposed Operation Laws

```
// NAND
nand(a, b)  ==  ~(a & b)
nand(a, b)  ==  ~a | ~b           // De Morgan equivalence

// NOR
nor(a, b)   ==  ~(a | b)
nor(a, b)   ==  ~a & ~b           // De Morgan equivalence

// XNOR (equivalence)
xnor(a, b)  ==  ~(a ^ b)
xnor(a, b)  ==  (a & b) | (~a & ~b)  // "Both same"

// AND-NOT
andNot(a, b)  ==  a & ~b
andNot(a, b)  ==  ~(~a | b)          // De Morgan equivalence
```

---

## 5. Gap Analysis

### 5.1 Current Implementation Inventory

| Category | What Exists | Assessment |
|----------|-------------|------------|
| Type definition | `enum Bit: UInt8 { case zero, one }` | ✓ Complete |
| Boolean ops | AND (`&`), OR (`\|`), XOR (`^`), NOT (`~`, `!`) | ✓ Functionally complete |
| Method-style | `.and()`, `.or()`, `.xor()` (static + instance) | ✓ Complete for existing ops |
| Z₂ field | `.adding()`, `.multiplying()`, `identity.additive`, `identity.multiplicative`, `.inverse` | ✓ Complete |
| Flip/Toggle | `.flipped`, `.toggled`, static variants | ✓ Complete (synonyms for NOT) |
| Ordering | `Bit.Order { .msb, .lsb }` with `.opposite` | ✓ Complete |
| Conversion | `init(Bool)`, `init?(UInt8)`, `init(normalizing:)`, `.boolValue` | ✓ Complete |
| Conformances | Sendable, Hashable, Equatable, Comparable, CaseIterable, Codable, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, Finite.Enumerable, Hash.Protocol, CustomStringConvertible | ✓ Comprehensive |
| Tagged values | `Bit.Value<Payload>`, `Bit.Order.Value<Payload>` | ✓ Complete |
| Affine ratios | `Ratio<Word, Bit>.bitWidth`, `.bitsPerByte`, `.bitsPerWord` | ✓ Complete |

### 5.2 Identified Gaps

#### Gap 1: NAND — Sheffer Function

**Severity**: Medium
**Justification**: NAND is one of two Sheffer functions (individually functionally complete). It is fundamental in digital logic (NAND gates are universal). Its absence means downstream code must write `~(a & b)` or `(~a | ~b)` instead of a named operation.

**Proposed API**:
```swift
// Static
public static func nand(_ lhs: Bit, _ rhs: Bit) -> Bit

// Instance
public func nand(_ other: Bit) -> Bit
```

#### Gap 2: NOR — Sheffer Function

**Severity**: Medium
**Justification**: NOR is the other Sheffer function. Same reasoning as NAND. NOR gates are universal in digital logic.

**Proposed API**:
```swift
// Static
public static func nor(_ lhs: Bit, _ rhs: Bit) -> Bit

// Instance
public func nor(_ other: Bit) -> Bit
```

#### Gap 3: XNOR — Equivalence / Biconditional

**Severity**: Medium-High
**Justification**: XNOR tests equivalence (a ↔ b). It is the complement of XOR. It has dedicated hardware instructions on ARM (EON) and RISC-V (XNOR). Haskell provides it as a monoid wrapper (`Iff`). It is the Z₂ field equality test. In the current implementation, testing whether two bits are equal requires `a ^ b == .zero` or `a == b` (which works but loses the algebraic intent).

**Proposed API**:
```swift
// Static
public static func xnor(_ lhs: Bit, _ rhs: Bit) -> Bit

// Instance
public func xnor(_ other: Bit) -> Bit
```

Note: For `Bit`, `xnor(a, b)` is equivalent to `Bit(a == b)`, but the named operation carries algebraic intent.

#### Gap 4: AND-NOT (Material Nonimplication / Bit Clear)

**Severity**: High
**Justification**: AND-NOT has a dedicated hardware instruction on ALL THREE major ISAs (x86 ANDN, ARM BIC, RISC-V ANDN). It is the most commonly needed compound Boolean operation in bit manipulation code. The pattern `a & ~b` appears frequently when clearing specific bits. ARM calls it "Bit Clear" (BIC).

**Proposed API**:
```swift
// Static
public static func andNot(_ lhs: Bit, _ rhs: Bit) -> Bit   // lhs AND NOT rhs

// Instance
public func andNot(_ other: Bit) -> Bit   // self AND NOT other
```

**Naming consideration**: Hardware uses various names:
- x86: ANDN (AND-NOT)
- ARM: BIC (Bit Clear)
- RISC-V: ANDN

`andNot` mirrors the hardware naming consensus and is self-documenting.

#### Gap 5: Select / Multiplexer (Ternary Operation)

**Severity**: Low-Medium
**Justification**: The 2:1 multiplexer `select(condition, ifOne, ifZero)` is the fundamental ternary Boolean operation. It equals `(condition & ifOne) | (~condition & ifZero)`. It is the basis of all conditional logic in hardware. However, for a single-bit type, this is equivalent to a ternary expression and may be over-engineering.

**Recommendation**: DEFER. This can be expressed as `condition.boolValue ? ifOne : ifZero` with no loss of clarity. The algebraic overhead of a ternary method on a 2-element type is not justified.

#### Gap 6: Algebraic Structure Formalization

**Severity**: Low
**Justification**: The current implementation provides Z₂ field operations (`.adding()`, `.multiplying()`) but does not explicitly expose the *lattice* structure (meet, join). The Boolean algebra view (AND = meet, OR = join) and the lattice view are implicit but unnamed.

**Recommendation**: DEFER. The operations are present (`&` = meet, `|` = join). Adding `.meet()` / `.join()` aliases would be redundant given the small type. The Z₂ field view is more useful for downstream consumers.

### 5.3 Gap Summary

| Gap | Operation | Severity | Hardware Support | Recommendation |
|-----|-----------|----------|-----------------|----------------|
| 1 | NAND | Medium | — | **ADD** |
| 2 | NOR | Medium | — | **ADD** |
| 3 | XNOR | Medium-High | ARM, RISC-V | **ADD** |
| 4 | AND-NOT | High | x86, ARM, RISC-V | **ADD** |
| 5 | Select/MUX | Low-Medium | Universal (hardware) | DEFER |
| 6 | Lattice aliases | Low | — | DEFER |

---

## 6. Empirical Validation: Cognitive Dimensions

Per [RES-025], evaluating the proposed additions against the Cognitive Dimensions of Notations framework:

| Dimension | Current State | After Additions | Assessment |
|-----------|---------------|-----------------|------------|
| **Visibility** | Core ops visible; compound ops hidden | All standard Boolean ops named | Improved |
| **Consistency** | Method-style for AND/OR/XOR but not NAND/NOR/XNOR | Uniform method-style for all standard ops | Improved |
| **Viscosity** | Must compose `~(a & b)` for NAND | Direct `a.nand(b)` | Reduced |
| **Role-expressiveness** | `~(a & b)` doesn't signal "NAND" to reader | `.nand()` immediately communicates intent | Improved |
| **Error-proneness** | `a & ~b` vs `~a & b` — easy to swap operand order | `.andNot()` makes the asymmetry explicit | Reduced |
| **Abstraction** | Low — appropriate for primitives | Unchanged | Appropriate |

The AND-NOT case is particularly compelling from an error-proneness perspective: `a & ~b` and `~a & b` are different operations (F2 vs F4), and the infix expression makes it easy to apply NOT to the wrong operand. A named `.andNot()` method eliminates this ambiguity.

---

## 7. Cross-Package Impact Assessment

### 7.1 Downstream Dependents

`swift-bit-primitives` has **15** downstream dependents. Additions are purely additive (new methods, no changes to existing API), so:

| Impact Type | Assessment |
|-------------|------------|
| Source compatibility | ✓ Fully preserved — additions only |
| Binary compatibility | ✓ @inlinable additions don't break ABI |
| Semantic compatibility | ✓ No existing behavior changes |

### 7.2 Relationship to bit-storage-primitives

The proposed additions do not affect `swift-bit-storage-primitives`. Storage operations (`Bit.Storage`, `Bit.Storage.Location`, `Bit.Vector`) operate on word-level representations, not on individual `Bit` values.

---

## 8. Completeness Theorem

**Definition 8.1 (Operationally Complete Single-Bit Type)**: A single-bit type T is *operationally complete* if it provides:
1. Named operations for all Boolean functions that have dedicated hardware instructions on ≥2 major ISAs
2. Named operations for both Sheffer functions (NAND, NOR)
3. The Z₂ field structure (addition = XOR, multiplication = AND, identities, inverses)
4. The Boolean algebra structure (AND, OR, NOT with all standard identities)

**Theorem 8.1**: After the proposed additions {NAND, NOR, XNOR, AND-NOT}, `swift-bit-primitives` satisfies Definition 8.1.

*Proof*:
1. Hardware-supported operations: AND (universal), OR (universal), XOR (universal), NOT (universal), AND-NOT (x86+ARM+RISC-V), XNOR (ARM+RISC-V). All present after additions. ✓
2. Sheffer functions: NAND and NOR both present after additions. ✓
3. Z₂ field: `.adding()` (XOR), `.multiplying()` (AND), `identity.additive` (.zero), `identity.multiplicative` (.one), `.inverse` (self). Already complete. ✓
4. Boolean algebra: `&` (AND), `|` (OR), `~` (NOT). Already complete. ✓

∎

---

## 9. Proposed Implementation

### 9.1 File Placement

Per [API-IMPL-005] (one type per file), the additions are methods on the existing `Bit` type, not new types. They belong in the existing `Bit.swift` file as a new MARK section.

### 9.2 Proposed Code

```swift
// MARK: - Compound Boolean Operations

extension Bit {
    /// NAND: returns `.zero` only if both bits are `.one`.
    ///
    /// One of two Sheffer functions — individually functionally complete.
    /// Equivalent to `~(a & b)` or `~a | ~b` (De Morgan).
    @inlinable
    public static func nand(_ lhs: Bit, _ rhs: Bit) -> Bit {
        ~(lhs & rhs)
    }

    /// NAND: returns `.zero` only if both bits are `.one`.
    @inlinable
    public func nand(_ other: Bit) -> Bit {
        Bit.nand(self, other)
    }

    /// NOR: returns `.one` only if both bits are `.zero`.
    ///
    /// One of two Sheffer functions — individually functionally complete.
    /// Equivalent to `~(a | b)` or `~a & ~b` (De Morgan).
    @inlinable
    public static func nor(_ lhs: Bit, _ rhs: Bit) -> Bit {
        ~(lhs | rhs)
    }

    /// NOR: returns `.one` only if both bits are `.zero`.
    @inlinable
    public func nor(_ other: Bit) -> Bit {
        Bit.nor(self, other)
    }

    /// XNOR: returns `.one` if both bits are equal (equivalence / biconditional).
    ///
    /// The complement of XOR. Has dedicated hardware instructions on ARM (EON)
    /// and RISC-V (XNOR). Forms a monoid with identity `.one`.
    @inlinable
    public static func xnor(_ lhs: Bit, _ rhs: Bit) -> Bit {
        ~(lhs ^ rhs)
    }

    /// XNOR: returns `.one` if both bits are equal (equivalence / biconditional).
    @inlinable
    public func xnor(_ other: Bit) -> Bit {
        Bit.xnor(self, other)
    }

    /// AND-NOT: returns `.one` if the first bit is `.one` and the second is `.zero`.
    ///
    /// Equivalent to `lhs & ~rhs`. Has dedicated hardware instructions on
    /// x86 (ANDN), ARM (BIC), and RISC-V (ANDN). Also known as "bit clear" —
    /// clears the bit positions indicated by the second operand.
    @inlinable
    public static func andNot(_ lhs: Bit, _ rhs: Bit) -> Bit {
        lhs & ~rhs
    }

    /// AND-NOT: returns `.one` if this bit is `.one` and the other is `.zero`.
    @inlinable
    public func andNot(_ other: Bit) -> Bit {
        Bit.andNot(self, other)
    }
}
```

### 9.3 Proposed Tests

Each new operation needs exhaustive truth-table tests (only 4 input combinations per binary operation):

```swift
// NAND truth table
#expect(Bit.nand(.zero, .zero) == .one)
#expect(Bit.nand(.zero, .one)  == .one)
#expect(Bit.nand(.one,  .zero) == .one)
#expect(Bit.nand(.one,  .one)  == .zero)

// NOR truth table
#expect(Bit.nor(.zero, .zero) == .one)
#expect(Bit.nor(.zero, .one)  == .zero)
#expect(Bit.nor(.one,  .zero) == .zero)
#expect(Bit.nor(.one,  .one)  == .zero)

// XNOR truth table
#expect(Bit.xnor(.zero, .zero) == .one)
#expect(Bit.xnor(.zero, .one)  == .zero)
#expect(Bit.xnor(.one,  .zero) == .zero)
#expect(Bit.xnor(.one,  .one)  == .one)

// AND-NOT truth table
#expect(Bit.andNot(.zero, .zero) == .zero)
#expect(Bit.andNot(.zero, .one)  == .zero)
#expect(Bit.andNot(.one,  .zero) == .one)
#expect(Bit.andNot(.one,  .one)  == .zero)
```

Plus algebraic law tests (De Morgan equivalences, Sheffer expressiveness, etc.).

---

## 10. Word-Level Bit Kernels: The Scope Question

### 10.1 The Challenge

An independent analysis (conducted in parallel) proposes expanding bit-primitives to include word-level operations: rank/select within machine words, mask generation, bit rotation, order-aware bit access, and broadword iteration patterns. This section evaluates that proposal rigorously.

The academic grounding is sound. The key references:

- **Jacobson (1989)**: Established rank/select on bit vectors as the core primitive for succinct data structures.
- **Vigna (2008)**: "Broadword Implementation of Rank/Select Queries" — practical word-level rank/select kernels using parallel mask arithmetic.
- **Warren (2002)**: *Hacker's Delight* — canonical reference for branch-free bit tricks (popcount, ctz/clz, mask generation).
- **Navarro et al. (2014)**: Survey bridging theory and practice for succinct structures.

The consensus: **word-level rank/select/scan are foundational kernels**. Higher-level structures (Rank9, Elias-Fano, RRR, wavelet trees, FM-index) build on them.

### 10.2 Where Do Word-Level Kernels Belong?

The semantic domain question must be answered precisely.

**Option A: In bit-primitives (Tier 13)**

| Pro | Con |
|-----|-----|
| Word-level kernels are about *bits* — they count, find, and select bits | Changes the semantic domain from "what is a bit" to "what are bit operations" |
| No new dependencies needed (only Swift stdlib's `FixedWidthInteger`) | bit-primitives has 15 dependents; changes propagate widely |
| All Tier 14 packages (array, set, storage) get kernels for free | Increases surface area of a foundational package |
| Prevents code duplication — array-primitives and set-primitives currently inline the same word-level loops | |

**Option B: In bit-storage-primitives (Tier 14)**

| Pro | Con |
|-----|-----|
| Already contains word-level operations (Bit.Vector.forEachSetBit, popcount) | Tier 14 packages can't share kernels without lateral dependencies |
| Semantic fit: "how do I manipulate bits in storage words" | array-primitives and set-primitives would need to depend on bit-storage-primitives |
| Smaller blast radius for changes | Duplicated kernels across multiple Tier 14 packages |

**Option C: New package (e.g., swift-bitwise-primitives)**

| Pro | Con |
|-----|-----|
| Clean semantic boundary | Yet another package in a 61+ package monorepo |
| Can be depended on independently | The operations are too small to justify a standalone package |

**Assessment**: Option A is correct. Here's why:

1. **Dependency argument**: `popcount` on a word literally counts `Bit`s. `rank1` counts `Bit`s up to a position. `select1` finds the nth `Bit`. These are *Bit operations* that happen to operate on words as carriers. The word is incidental; the bits are the subject.

2. **Reuse argument**: Both `swift-array-primitives` (`Bit.Array`) and `swift-set-primitives` (`Bit.Set`) currently contain inlined word-level iteration loops that are functionally identical to each other and to `Bit.Vector.forEachSetBit`. Factoring these into Tier 13 eliminates this three-way duplication.

3. **No dependency cost**: Word-level kernels operate on `FixedWidthInteger & UnsignedInteger`, which is Swift stdlib. No additional package dependencies are introduced.

4. **Refined semantic domain**: bit-primitives answers "What is a bit, and what are the fundamental operations involving bits?" This naturally spans two scales:
   - **Single-bit**: The `Bit` type, Boolean algebra, Z₂ field
   - **Word-of-bits**: Rank, select, scan, mask — the kernels that all bit containers build on

The storage package then cleanly answers a DIFFERENT question: "How do I organize multi-word bit storage in memory?" — layout, addressing across word boundaries, capacity computation, and container types.

### 10.3 Overlap Analysis with Existing bit-storage-primitives

The parallel proposal includes types that conflict with existing infrastructure:

| Proposed Type | Existing Equivalent | Conflict Assessment |
|---------------|-------------------|---------------------|
| `Bit.Position<Word>` | `Index<Bit>` + `Bit.Storage.Location<Word>` | **Direct conflict.** The primitives ecosystem uses phantom-typed `Index<T>` for all positions. A second position type violates the index-primitives architecture. |
| `Bit.Mask<Word>` | `Bit.Storage.Location<Word>.mask` | **Partial overlap.** Location already computes masks. A standalone mask type adds value only if it carries additional invariants. |
| `Bit.OneHotMask<Word>` | (none) | **Genuinely new.** A mask with exactly one bit set is a meaningful type-level refinement. However, its utility at the primitives level is limited. |
| `Bit.Word` protocol | `where Word: FixedWidthInteger & UnsignedInteger & Sendable` | **Debatable.** Reduces constraint repetition. But adds protocol to maintain. Existing code uses inline constraints. |
| `Bit.Word+Access` (bit/set/toggle) | `Bit.Vector` subscript | **Semantic split.** Vector operates on multi-word storage. Word-level access is the kernel Vector should call. This is factoring, not duplication. |
| `Bit.Word+RankSelect` | (none) | **Genuinely new and valuable.** No rank/select exists anywhere in the codebase. |
| `Bit.Word+Rotate` | (none) | **New but questionable scope.** Rotation is a general integer operation, not bit-specific. |

### 10.4 What Should Actually Be Added to bit-primitives

After filtering for genuine value, architectural fit, and naming compliance:

#### 10.4.1 Word-Level Rank (ADD)

```swift
extension FixedWidthInteger where Self: UnsignedInteger {
    /// Count of set bits in positions 0..<bound (LSB ordering).
    ///
    /// Word-level rank₁ — the fundamental kernel for succinct data structures.
    /// Equivalent to `popcount(self & prefixMask(bound))`.
    ///
    /// - Reference: Vigna, "Broadword Implementation of Rank/Select Queries", SEA 2008.
    @inlinable
    public func rank1(below bound: Int) -> Int
}
```

**Justification**: Rank is a foundational primitive (Jacobson 1989). Every succinct structure builds on it. Currently absent from the entire codebase. Word-level rank is O(1) via popcount + mask.

#### 10.4.2 Word-Level Select (ADD)

```swift
extension FixedWidthInteger where Self: UnsignedInteger {
    /// Position of the nth set bit (0-indexed), or nil if fewer than n+1 bits are set.
    ///
    /// Word-level select₁ — the dual of rank. Returns the position (LSB = 0)
    /// of the nth one-bit.
    ///
    /// - Reference: Vigna, "Broadword Implementation of Rank/Select Queries", SEA 2008.
    @inlinable
    public func select1(_ n: Int) -> Int?
}
```

**Justification**: Select is the dual of rank. Together they form the complete query interface for bit vectors. The word-level kernel is the inner loop of all multiword select implementations.

#### 10.4.3 Prefix Mask Generation (ADD)

```swift
extension FixedWidthInteger where Self: UnsignedInteger {
    /// Mask with bits 0..<count set to 1, all others 0.
    ///
    /// Returns `(1 << count) - 1` for count in 0...bitWidth.
    /// Essential building block for rank, range extraction, and bit-field operations.
    @inlinable
    public static func prefixMask(count: Int) -> Self
}
```

**Justification**: Required by rank. Also used pervasively in bit-storage-primitives (Bit.Vector.setAll clears excess bits, Location computes masks). Currently computed inline in multiple places.

#### 10.4.4 Set-Bit Enumeration Kernel (ADD)

```swift
extension FixedWidthInteger where Self: UnsignedInteger {
    /// Calls the closure for each set bit position (LSB = 0).
    ///
    /// Uses the Wegner/Kernighan clear-lowest-set-bit loop: `word &= word - 1`.
    /// Complexity: O(popcount).
    @inlinable
    public func forEachSetBit(_ body: (Int) throws -> Void) rethrows
}
```

**Justification**: This exact loop is currently duplicated in `Bit.Vector.forEachSetBit`, `Bit.Vector.Static.forEachSetBit`, and will appear in any future bit container. Factoring it into a word-level kernel eliminates the duplication.

#### 10.4.5 First/Last Set Bit (ADD)

```swift
extension FixedWidthInteger where Self: UnsignedInteger {
    /// Position of the lowest set bit (LSB = 0), or nil if zero.
    @inlinable
    public var firstSetBit: Int?

    /// Position of the highest set bit (LSB = 0), or nil if zero.
    @inlinable
    public var lastSetBit: Int?
}
```

**Justification**: `trailingZeroBitCount` and `leadingZeroBitCount` exist in Swift stdlib but return `bitWidth` for zero (not nil) and don't provide the bit *position* directly. These are the semantic wrappers.

#### 10.4.6 Rotation (DEFER — not bit-specific)

Rotation is a general integer operation, not specific to the "bit" domain. It applies equally to cryptographic operations, hash functions, and arithmetic. If added to the primitives ecosystem, it belongs in `swift-numeric-primitives` or as a general `FixedWidthInteger` extension, not in bit-primitives.

#### 10.4.7 Bit.Word Protocol (DEFER — evaluate during implementation)

The `Bit.Word` protocol (`FixedWidthInteger & UnsignedInteger & Sendable where Magnitude == Self`) bundles a common constraint. Its value depends on how many extensions reference the constraint. If the additions above are implemented as `extension FixedWidthInteger where Self: UnsignedInteger`, the protocol may be unnecessary. Evaluate during implementation.

### 10.5 Impact on bit-storage-primitives

With word-level kernels in bit-primitives (Tier 13), bit-storage-primitives (Tier 14) should be refactored to USE them:

| Current (inlined) | Proposed (delegates to kernel) |
|-------------------|-------------------------------|
| `Bit.Vector.forEachSetBit` — contains inline Wegner loop | Delegates to `word.forEachSetBit` per word |
| `Bit.Vector.popcount` — inline `nonzeroBitCount` loop | Unchanged (already one-liner per word) |
| `Bit.Vector.setAll` — inline excess-bit mask | Uses `.prefixMask(count:)` |
| `Bit.Vector.Static.forEachSetBit` — duplicate Wegner loop | Delegates to `word.forEachSetBit` per word |

This is a refactoring of bit-storage-primitives, not a redesign. The public API is unchanged.

### 10.6 What Stays in bit-storage-primitives

These remain in bit-storage-primitives because they're about **multi-word layout**, not single-word bit operations:

| Type | Why It Stays |
|------|-------------|
| `Bit.Storage<Word>` | Computes word COUNT for a given bit count — layout concern |
| `Bit.Storage.Location<Word>` | Maps bit index to (word index, bit offset, mask) — cross-word addressing |
| `Bit.Vector` | Heap-allocated multi-word container |
| `Bit.Vector.Static<N>` | Stack-allocated multi-word container |
| `Bit.Index` extensions for byte conversion | Cross-unit addressing |

### 10.7 Revised Semantic Domain Boundaries

```
bit-primitives (Tier 13):
  "What is a bit, and what are the fundamental operations involving bits?"
  ├── Bit type (Z₂ field, Boolean algebra)
  ├── Bit.Order (MSB/LSB)
  ├── Single-bit operations (AND, OR, XOR, NOT, NAND, NOR, XNOR, AND-NOT)
  ├── Word-level bit kernels (rank, select, scan, mask, enumerate)
  └── Affine ratios (bits-per-word, bits-per-byte)

bit-storage-primitives (Tier 14):
  "How do I organize multi-word bit storage in memory?"
  ├── Bit.Storage (capacity computation)
  ├── Bit.Storage.Location (cross-word addressing)
  ├── Bit.Vector (heap container, uses word kernels)
  └── Bit.Vector.Static (stack container, uses word kernels)
```

---

## 11. What Is Explicitly OUT OF SCOPE

To prevent scope creep, the following are explicitly excluded from bit-primitives and documented here for future reference:

### 11.1 General Integer Operations (Not Bit-Specific)

These are useful but belong in numeric-primitives or a general `FixedWidthInteger` extension package:

| Operation | Why Not Here | Where Instead |
|-----------|-------------|---------------|
| Bit rotation (`rotateLeft`/`rotateRight`) | General integer/crypto operation, not bit-specific | `swift-numeric-primitives` |
| Bit reversal (`reverseBits`) | General integer transform | `swift-numeric-primitives` |
| Byte swap | Already in Swift stdlib (`byteSwapped`) | — |
| Power-of-two ops (`hasSingleBit`, `bitCeil`, `bitFloor`) | Arithmetic, not bit counting | `swift-numeric-primitives` |
| Funnel shift | General integer/crypto operation | `swift-numeric-primitives` |
| Count leading/trailing ones | Useful but derivable from CLZ/CTZ + NOT | Candidate for future addition |

### 11.2 Hardware-Specific Operations

| Operation | Why Not Here |
|-----------|-------------|
| PEXT / PDEP (parallel extract/deposit) | x86-specific (BMI2); no portable semantics across ARM/RISC-V |
| BLSI / BLSR / BLSMSK (bit isolation) | x86-specific (BMI1); niche usage |

### 11.3 Container Operations

These belong in bit-storage-primitives, array-primitives, or set-primitives:

| Operation | Where It Belongs |
|-----------|-----------------|
| Packed bit arrays | `swift-array-primitives` (Bit.Array) |
| Bit sets | `swift-set-primitives` (Bit.Set) |
| Bit vectors | `swift-bit-storage-primitives` (Bit.Vector) |
| Bit matrix operations | Future package |

### 11.4 Higher-Arity Operations

| Operation | Rationale for Exclusion |
|-----------|------------------------|
| Majority (MAJ) | Ternary; expressible as `(a & b) \| (b & c) \| (a & c)` |
| Select/MUX | Ternary; expressible as `condition.boolValue ? a : b` |
| Full adder | Circuit primitive, not algebraic primitive |
| Carry-lookahead | Multi-bit circuit technique |

---

## 12. Outcome

**Status**: RECOMMENDATION

### 12.1 Summary

The current `swift-bit-primitives` implementation is **functionally complete** (it can express all Boolean functions) but **operationally incomplete** in two dimensions:

**Dimension 1 — Single-bit operations**: Four commonly needed Boolean operations lack named methods.
**Dimension 2 — Word-level kernels**: Foundational bit-counting and bit-finding operations are absent, causing duplication in downstream packages.

### 12.2 Complete Addition Set

#### Part A: Single-Bit Operations (on `Bit` type)

| # | Operation | Justification |
|---|-----------|---------------|
| 1 | **NAND** | Sheffer function (individually functionally complete); universal gate |
| 2 | **NOR** | Sheffer function; universal gate |
| 3 | **XNOR** | Equivalence/biconditional; hardware instructions on ARM (EON), RISC-V; Haskell monoid (`Iff`) |
| 4 | **AND-NOT** | Dedicated instruction on ALL 3 major ISAs (x86 ANDN, ARM BIC, RISC-V ANDN); error-prone to compose inline |

#### Part B: Word-Level Kernels (on `FixedWidthInteger where Self: UnsignedInteger`)

| # | Operation | Justification |
|---|-----------|---------------|
| 5 | **rank1(below:)** | Foundational succinct primitive (Jacobson 1989, Vigna 2008); O(1) via popcount + mask |
| 6 | **select1(_:)** | Dual of rank; foundational for succinct structures |
| 7 | **prefixMask(count:)** | Required by rank; currently inlined in multiple places |
| 8 | **forEachSetBit(_:)** | Wegner/Kernighan kernel; currently duplicated in Bit.Vector and Bit.Vector.Static |
| 9 | **firstSetBit** | Semantic wrapper for trailingZeroBitCount with nil-for-zero |
| 10 | **lastSetBit** | Semantic wrapper for (bitWidth - 1 - leadingZeroBitCount) with nil-for-zero |

### 12.3 After These Additions, bit-primitives Is Complete

The package will then provide:

**Single-bit algebra:**
- All 4 fundamental Boolean operations (AND, OR, XOR, NOT)
- All 4 significant compound Boolean operations (NAND, NOR, XNOR, AND-NOT)
- Full Z₂ field structure (addition, multiplication, identities, inverses)
- All operations with dedicated hardware ISA instructions

**Word-level kernels:**
- Rank₁ and select₁ — the two foundational queries for bit vectors
- Prefix mask generation — the building block for rank and range extraction
- Set-bit enumeration — the O(popcount) iteration kernel
- First/last set bit — the scan primitives

**What this enables for downstream packages:**
- `swift-bit-storage-primitives` refactors Bit.Vector to delegate to word kernels (no API change)
- `swift-array-primitives` and `swift-set-primitives` can replace inlined word loops with kernel calls
- Future succinct data structure packages (Rank9, Elias-Fano) get correct, fast kernels for free

### 12.4 Implementation Notes

- All additions are `@inlinable`
- Single-bit operations: trivially composable from existing operators; zero runtime cost
- Word-level kernels: compile to hardware instructions (popcount → `POPCNT`, CTZ → `TZCNT`, CLZ → `LZCNT`)
- No new dependencies introduced
- Part A requires no new files (additions to `Bit.swift`)
- Part B requires new file(s) for the `FixedWidthInteger` extensions
- Source- and ABI-compatible (purely additive)

### 12.5 Architectural Restructuring

The completeness analysis revealed a deeper architectural issue: `swift-bit-storage-primitives` conflates three distinct concepts in one package.

#### 12.5.1 The Three Concepts

| Concept | Current Location | What It Is | Allocates? |
|---------|-----------------|------------|:----------:|
| **Bit algebra + word kernels** | bit-primitives | Z₂ field, Boolean ops, rank/select on words | No |
| **Packing / addressing math** | bit-storage-primitives (`Bit.Storage`, `Bit.Storage.Location`) | Map `Bit.Index` → `(word, offset, mask)` | No |
| **Owning container** | bit-storage-primitives (`Bit.Vector`, `Bit.Vector.Static`) | Allocate, own, and deallocate packed bit memory | **Yes** |

#### 12.5.2 Recommended Split: Two Packages

**`swift-bit-primitives`** (Tier 13) — all non-allocating bit math:

| What | Status |
|------|--------|
| `Bit` type + Z₂ algebra | Keep (existing) |
| `Bit.Order` | Keep (existing) |
| Affine ratios (`bitsPerWord`, `bitsPerByte`) | Keep (existing) |
| NAND, NOR, XNOR, AND-NOT | **Add** |
| Word-level kernels (rank, select, prefixMask, forEachSetBit, firstSetBit, lastSetBit) | **Add** |
| `Bit.Index` typealias (`Index<Bit>`) | **Move in** from bit-storage |
| `Bit.Packing<Word>` (renamed from `Bit.Storage`) | **Move in** from bit-storage, rename |
| `Bit.Packing.Location<Word>` (renamed from `Bit.Storage.Location`) | **Move in** from bit-storage, rename |
| Byte↔bit conversion initializers on `Bit.Index` | **Move in** from bit-storage |

Rationale: bit-primitives already imports Index_Primitives and Affine_Primitives. It already contains `Ratio<UInt, Bit>.bitsPerWord` — which IS packing math. Packing.Location is pure arithmetic using those same dependencies. The boundary between "bit algebra" and "bit addressing" is artificial for non-allocating math. The meaningful boundary is: **does it allocate?**

**`swift-bit-vector-primitives`** (Tier 14) — owning containers:

| What | Status |
|------|--------|
| `Bit.Vector` | **Move from** bit-storage |
| `Bit.Vector.Static<N>` | **Move from** bit-storage |
| Bulk ops (clearAll, setAll, popcount, forEachSetBit over multi-word) | **Move from** bit-storage |
| `withUnsafeWords`, `withUnsafeMutableWords` | **Move from** bit-storage |

Depends on: `swift-bit-primitives` (word kernels + Bit.Packing.Location)

**`swift-bit-storage-primitives`**: **RETIRED** — contents split between the above two.

#### 12.5.3 Why Not Three Packages?

A third package (`swift-bit-packing-primitives`) for just `Bit.Packing` and `Bit.Packing.Location` was considered and rejected:

1. **Too thin**: Only 2 types. Not sufficient for a standalone primitives package.
2. **Deps already present**: bit-primitives already imports Index_Primitives and Affine_Primitives — exactly what packing needs. No new dependencies.
3. **Precedent**: `Ratio<UInt, Bit>.bitsPerWord` (packing math) is already in bit-primitives. Moving packing in is consistent; separating it would require moving ratios out (breaking 15 dependents).
4. **Practical**: One fewer package, one fewer tier boundary, one fewer dependency edge.

#### 12.5.4 Required Renames

| Current | Renamed | Rationale |
|---------|---------|-----------|
| `Bit.Storage<Word>` | `Bit.Packing<Word>` | Not storage (doesn't own memory); it's packing requirements |
| `Bit.Storage.Location` | `Bit.Packing.Location` | Consistent with parent rename |

#### 12.5.5 Required Fixes

**Centralize conversions**: Replace all `Int(bitPattern: count.count)` / `Int(bitPattern: index.position)` with explicit boundary properties:

```swift
extension Bit.Index.Count {
    @inlinable public var intValue: Int { Int(rawValue.rawValue) }
}
```

**Fix Vector to use Location**: Vector subscript currently duplicates addressing math with raw shifts. Refactor to delegate to `Bit.Packing.Location`.

**Declare LSB-only packing**: Location currently assumes LSB-first (`mask = Word(1) << bitOffset`). Make this explicit. MSB interpretation is a presentation concern for higher layers.

#### 12.5.6 Migration Impact

| Downstream Package | Impact |
|-------------------|--------|
| `swift-memory-primitives` (Memory Pool) | Update import: `Bit_Storage_Primitives` → `Bit_Vector_Primitives` (for Vector) or just `Bit_Primitives` (for Packing) |
| `swift-buffer-primitives` (Buffer Core) | Same — update imports |
| `swift-array-primitives` | Uses `Bit.Storage<UInt>(count:bitsPerWord:)` → rename to `Bit.Packing<UInt>(count:bitsPerWord:)` |
| All 15 bit-primitives dependents | No breaking change (purely additive) |

### 12.6 Deferred Decisions

| Item | Rationale | Revisit When |
|------|-----------|-------------|
| `Bit.Word` protocol | Evaluate whether constraint bundling justifies a new protocol | During implementation of Part B |
| Rotation | General integer operation, not bit-specific | When `swift-numeric-primitives` scope is defined |
| rank0/select0 | Trivially derivable from rank1/select1 + complement | If downstream usage shows demand |
| `Bit.Mask<Word>` / `Bit.OneHotMask<Word>` types | Prefix mask works as a function; evaluate typed masks during implementation | During implementation |
| ManagedBuffer for Vector | Current raw pointer allocation works but is fragile | When bit-vector-primitives is created |

---

## References

### Hardware ISA Specifications

1. Intel Corporation. *Intel 64 and IA-32 Architectures Software Developer's Manual*. Vol. 2: Instruction Set Reference. 2024.
2. ARM Limited. *Arm Architecture Reference Manual for A-profile architecture*. DDI 0487. 2024.
3. RISC-V International. *RISC-V Bitmanip Extension*. Version 1.0.0. 2024.
4. Hilewitz, Y., & Lee, R. B. "Fast Bit Compression and Expansion with Parallel Extract and Parallel Deposit Instructions." *IEEE SBAC-PAD*, 2006.

### Language References

5. Apple Inc. *The Swift Programming Language: FixedWidthInteger Protocol*. 2024.
6. Rust Team. *The Rust Standard Library: Primitive Type u64*. 2024.
7. ISO/IEC 14882:2020. *Programming Languages — C++*. §20.15 (`<bit>` header).
8. GHC Team. *Data.Bits Module*. base-4.22.0.0. Hackage.

### Mathematical Foundations

9. Post, E. L. "The Two-Valued Iterative Systems of Mathematical Logic." *Annals of Mathematics Studies*, No. 5. Princeton University Press, 1941.
10. Stone, M. H. "The Theory of Representation for Boolean Algebras." *Transactions of the American Mathematical Society*, 40(1):37–111, 1936.
11. Birkhoff, G. *Lattice Theory*. American Mathematical Society Colloquium Publications, Vol. 25. 1940. (3rd ed. 1967.)
12. Shannon, C. E. "A Symbolic Analysis of Relay and Switching Circuits." *Transactions of the AIEE*, 57(12):713–723, 1938.

### Bit Manipulation

13. Warren, H. S., Jr. *Hacker's Delight*. 2nd ed. Addison-Wesley Professional, 2012.
14. Knuth, D. E. *The Art of Computer Programming*, Vol. 4A: Combinatorial Algorithms. Addison-Wesley, 2011. §7.1.3 "Bitwise Tricks and Techniques."

### Formal Verification

15. Barrett, C., Stump, A., & Tinelli, C. "The SMT-LIB Standard: Version 2.6." *Department of Computer Science, The University of Iowa*, 2017. Theory: FixedSizeBitVectors.
16. Kroening, D., & Strichman, O. *Decision Procedures: An Algorithmic Point of View*. 2nd ed. Springer, 2016. Ch. 6: "Bit Vectors."

### Succinct Data Structures and Word-Level Kernels

17. Jacobson, G. "Space-Efficient Static Trees and Graphs." *Proceedings of the 30th IEEE Symposium on Foundations of Computer Science (FOCS)*, 549–554, 1989. — Established rank/select on bit vectors as the core primitive for succinct structures.
18. Vigna, S. "Broadword Implementation of Rank/Select Queries." *Proceedings of the 7th International Workshop on Experimental Algorithms (WEA/SEA)*, LNCS 5038, 154–168. Springer, 2008. — Practical word-level rank/select kernels using parallel mask arithmetic.
19. Navarro, G. *Compact Data Structures: A Practical Approach*. Cambridge University Press, 2016. — Comprehensive treatment bridging theory and practice for succinct structures.
20. Raman, R., Raman, V., & Rao, S. S. "Succinct Indexable Dictionaries with Applications to Encoding k-ary Trees and Multisets." *ACM Transactions on Algorithms*, 3(4):43, 2007. (Conference version: SODA 2002.) — RRR: space-efficient bit vector supporting fast rank/select.
21. Lemire, D., Muła, W., & Kurz, N. "Faster Population Counts Using AVX2 Instructions." *The Computer Journal*, 61(1):111–120, 2018. — Performance context for vectorized popcount and bit enumeration.
22. Grossi, R., Gupta, A., & Vitter, J. S. "High-Order Entropy-Compressed Text Indexes." *Proceedings of the 14th Annual ACM-SIAM Symposium on Discrete Algorithms (SODA)*, 841–850, 2003. — Wavelet trees using rank/select as building blocks.
23. Ferragina, P. & Manzini, G. "Opportunistic Data Structures with Applications." *Proceedings of the 41st IEEE Symposium on Foundations of Computer Science (FOCS)*, 390–398, 2000. — FM-index: rank/select as core query primitive.

---

*Document created: 2026-02-03*
*Revised: 2026-02-03 (v2.0.0 — expanded scope to include word-level kernels)*
*Analysis scope: 2 packages, 11 source files, 6 external language/ISA comparisons, 16 Boolean functions, 23 references*

### Deferral

**Date**: 2026-03-15

**Reason**: The document reached RECOMMENDATION status with a complete addition set (4 single-bit operations, 6 word-level kernels) and an architectural restructuring plan (retire bit-storage-primitives, split into enhanced bit-primitives + bit-vector-primitives). Implementation has not started. The completeness findings were validated by the leaf package audit (Phase 2c included bit-primitives), which confirmed the same gaps. No new information has emerged to change the recommendations.

**Resume when**: Implementation capacity is available for the Part A (single-bit operations) and Part B (word-level kernels) additions, and/or when the bit-storage-primitives retirement is prioritized.
