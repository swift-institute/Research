# IO Algebraic Effects — Theoretical Foundation

<!--
---
version: 1.0.0
created: 2026-04-20
status: DRAFT
purpose: |
  Establish the academic grounding for swift-io as the composable shape
  onto which Socket IO, File IO, Timer IO etc. are composed. Provides
  vocabulary and reference definitions for the forthcoming swift-io thesis
  and for consolidating the scattered research corpus.

cross-references:
  - ../../../swift-foundations/swift-io/Research/perfect-api.md
  - ../../../swift-foundations/swift-io/Research/io-architecture.md
  - io-witness-shape-selection.md
  - io-witness-design-literature-study.md
  - ../../../swift-foundations/swift-io/Experiments/io-algebra/Sources/IO.swift
  - ../../Research/effect-primitives-and-io-algebra-relation.md
---
-->

> **Cross-package note**: this document was moved from `swift-foundations/swift-io/Research/`
> to `swift-primitives/swift-io-primitives/Research/` on 2026-04-20.
> Body references to `perfect-api.md`, `io-architecture.md`,
> `io-research-corpus-audit.md`, `completion-queue-ownership-redesign.md`,
> and other swift-io-specific docs are still written in shorthand below;
> resolve those at `../../../swift-foundations/swift-io/Research/<file>`.
> References to `swift-io/Experiments/io-algebra/` resolve at
> `../../../swift-foundations/swift-io/Experiments/io-algebra/`.

## 1. Thesis

swift-io encodes an **algebraic theory of IO effects**, in the technical
sense of Plotkin–Power–Pretnar. The *signature* enumerates primitive IO
operations. The *equations* constrain their observable behaviour.
*Handlers* are law-preserving implementations. Socket IO, File IO,
Timer IO, and stream operations extend the core theory by **coproduct of
signatures**; their handlers compose modularly. Two programmatic
encodings discharge the same theory:

- **Free encoding** — programs as data, interpreters as folds
  (matches what the `io-algebra` experiment is reaching toward).
- **Direct / dictionary encoding** — programs as code, signatures as
  struct-of-closures, handlers as values (matches Shape F's
  capability + runner split).

These are not competitors. They are the syntactic and semantic
presentations of the same effect theory, and they coexist with no loss.

## 2. Why algebraic effects specifically

Of the candidate theoretical groundings —

| Tradition | Gives you | Misses |
|-----------|-----------|--------|
| Monadic IO (Wadler / SPJ) | First-class effectful values | Per-effect equational reasoning; modular composition |
| Linear types (Girard / Wadler) | Resource discipline | Effect *structure* (which ops, which laws) |
| Session types (Honda / Yoshida) | Protocol typing | Below-the-protocol IO primitives |
| CSP / π-calculus (Hoare / Milner) | Concurrency algebra | Stateful effect modelling |
| Continuations (Felleisen / Danvy) | Universal control substrate | Effect signatures as first-class objects |
| **Algebraic effects (Plotkin–Power–Pretnar)** | **Signature + laws + handlers + coproduct composition** | Needs delimited continuations for higher-order handlers (Swift constraint) |

— only algebraic effects provide all of (signature, laws, modular
handlers, compositional semantics). Crucially, "Socket ⊕ File ⊕ Timer"
is *the exact construction* that algebraic effects theory supplies
(Swierstra's *Data Types à la Carte*, Plotkin–Power's theory
coproducts). The match to the swift-io thesis is not approximate.

## 3. Primary literature

All citations below are to the published venue. Sources to pull before
writing anything load-bearing downstream:

**Foundational — effect algebra**
- Moggi, E. (1989). *Computational lambda-calculus and monads*. **LICS
  1989**. — Origin of monadic semantics.
- Plotkin, G. & Power, J. (2001). *Adequacy for algebraic effects*.
  **FoSSaCS 2001**, LNCS 2030. — Operational adequacy for effect
  theories.
- Plotkin, G. & Power, J. (2002). *Notions of computation determine
  monads*. **FoSSaCS 2002**, LNCS 2303. — Duality monad ↔ theory.
- Plotkin, G. & Power, J. (2003). *Algebraic operations and generic
  effects*. **Applied Categorical Structures** 11(1). — Algebraicity
  property; generic effects.

**Handlers**
- Plotkin, G. & Pretnar, M. (2009). *Handlers of algebraic effects*.
  **ESOP 2009**, LNCS 5502. — Seminal handler paper.
- Bauer, A. & Pretnar, M. (2015). *Programming with algebraic effects
  and handlers*. **JLAMP** 84(1). — The Eff language; operational
  semantics in full.
- Pretnar, M. (2015). *An introduction to algebraic effects and
  handlers*. **MFPS XXXI**, ENTCS 319. — Pedagogical on-ramp, ~30 pp.

**Free-monad / syntactic presentation**
- Swierstra, W. (2008). *Data types à la carte*. **JFP** 18(4). —
  Coproduct of functors for modular effect signatures.
- Kiselyov, O., Sabry, A., & Swords, C. (2013). *Extensible effects*.
  **Haskell Symposium 2013**.
- Kiselyov, O. & Ishii, H. (2015). *Freer monads, more extensible
  effects*. **Haskell Symposium 2015**. — The freer-monad
  construction; closest to the `io-algebra` encoding.

**Monad-transformer / continuation encodings (what `io-algebra`
actually is today)**
- Liang, S., Hudak, P., & Jones, M. (1995). *Monad transformers and
  modular interpreters*. **POPL 1995**. — ReaderT · ExceptT · IO stack.
- Atkey, R. (2009). *Parameterised notions of computation*. **JFP**
  19(3-4). — Indexed / parameterised effects.

**Implementation strategy (relevant to Shape F)**
- Wu, N., Schrijvers, T., & Hinze, R. (2014). *Effect handlers in
  scope*. **Haskell Symposium 2014**.
- Leijen, D. (2017). *Type-directed compilation of row-typed algebraic
  effects*. **POPL 2017**. — Koka's compilation strategy; how
  signatures become dictionaries in practice.

> **Suggested reading order for this session**: Pretnar (2015) for the
> vocabulary, Swierstra (2008) for coproduct composition, Kiselyov–Ishii
> (2015) for the freer-monad encoding. That's ~60 pages and covers
> everything the swift-io thesis needs to reference.

## 4. Core definitions

The definitions below are standard; sources are annotated inline. They
are the vocabulary the rest of this note uses.

### 4.1 Effect signature

A **signature** Σ is a set of operation symbols, each with an input type
and an output type: `op : A → B`.

For the classic state theory:

```
get : 1 → S
put : S → 1
```

For a minimal IO theory:

```
read  : (FileDescriptor, Count) → Bytes
write : (FileDescriptor, Bytes) → Count
open  : (Path, Flags)           → FileDescriptor
close : FileDescriptor          → 1
```

(Plotkin & Power 2003 §2; Pretnar 2015 §2.1.)

### 4.2 Free term algebra

Programs over Σ are terms built by:

```
t ::= return v            -- value injection
    | op(arg; x. t)       -- operation + continuation binding `x`
```

The set of all such terms is the **free Σ-algebra** over a value set A,
written `Free(Σ) A`. Categorically, it is the initial object in the
category of Σ-algebras (Plotkin & Power 2001; Swierstra 2008).

### 4.3 Algebraicity (Plotkin–Power)

An operation `op : A → T B` in a monad T is **algebraic** iff it
commutes with the monad's Kleisli extension:

```
op(a) >>= k  =  op(a; x. k(x))
```

i.e. the continuation is threaded uniformly. This is the property that
makes handlers work. Most IO primitives are algebraic in this sense.
(Plotkin & Power 2003 §4.)

### 4.4 Equational theory

A **theory** is a pair `(Σ, E)` where E is a set of equations between
Σ-terms. The state theory has:

```
put s ; put t           =  put t
put s ; get             =  put s ; return s
get >>= λs. put s       =  return ()
get >>= λs. get >>= λt. k s t  =  get >>= λs. k s s
```

(Plotkin & Power 2003 §6; standard ever since.)

Handlers **must preserve** E. This is the bite of "provably correct": a
handler is correct iff it discharges every equation of E as an equation
in the target theory.

### 4.5 Handler

Given `(Σ, E)` and a target monad T', a **handler** H comprises:

- **Return clause** `h_ret : A → T' B`
- **Operation clauses**, one per `op : P → Q` in Σ:
  `h_op : P × (Q → T' B) → T' B`

Handling `Free(Σ) A` via H yields `T' B` by folding the term tree.
(Plotkin & Pretnar 2009 §3; Bauer & Pretnar 2015 §4.)

### 4.6 Coproduct of theories

Given disjoint signatures Σ₁, Σ₂ with theories `(Σ₁, E₁)`, `(Σ₂, E₂)`,
their coproduct `Σ₁ ⊕ Σ₂` is the disjoint union with equation set
`E₁ ∪ E₂`. Terms may invoke operations from either signature; handlers
for one signature **pass through** operations of the other unchanged.

*This* is the formal construction behind "Socket ⊕ File ⊕ Timer". It is
exactly what modular effect composition needs and precisely what
Swierstra (2008) popularises as "data types à la carte". (Also Plotkin
& Power 2002; Hyland–Levy–Plotkin 2006 on combining effects.)

## 5. The two encodings

### 5.1 Free / syntactic encoding

```
Free(Σ) A  ::=  Pure A
             |  Do (op, args, continuation)
```

- A program **is** an AST.
- A handler **is** a fold.
- Manipulation of programs as data is available for free: retry,
  replay, logging, caching, parallelisation.
- Cost: every operation invocation allocates a node (mitigated by
  fusion; Kiselyov–Ishii 2015).

The `swift-io/Experiments/io-algebra/` experiment is **close to** this
encoding. It is, strictly, the *monad-transformer / Kleisli-closure*
form (ReaderT · ExceptT · IO — Liang–Hudak–Jones 1995), where
operations are collapsed into a single opaque closure
`(borrowing Env) async throws(E) -> A`. To become a pure free encoding,
it would need an explicit operation constructor rather than a closure
carrier. See `IO.swift` lines 44-48 (the file itself cites Moggi,
Liang–Hudak–Jones, and Atkey as the encoding's pedigree).

### 5.2 Direct / dictionary encoding

```
struct Σ_Handler {
  op₁: (P₁) async throws(E) -> Q₁
  op₂: (P₂) async throws(E) -> Q₂
  ...
}
```

- A program is code.
- A signature is a struct of function fields.
- A handler is a value of that struct type.
- Execution is direct: no AST, no allocation.
- Cost: programs are no longer first-class data, so
  replay/retry/logging must be built into the handler value.

Shape F is this encoding. The *capability* is the signature struct; the
*runner* is a handler value. The `@Witness` macro is a facility for
generating the struct mechanically from a protocol declaration.

### 5.3 The equivalence (subject to verification)

Standard effects-community folklore: for any `(Σ, E)`, programs in
`Free(Σ)` under handler H produce the same values as direct-encoded
programs under the corresponding dictionary value.

- Free → Direct: specialise `Free(Σ) A` against handler H; the
  interpretation is the direct-style program.
- Direct → Free: reify every dictionary call as a `Do` constructor; lift
  the program to `Free(Σ)`.

**Caveat**: I have not located a single citation that states this in
the exact form needed here. Bauer–Pretnar (2015) §3 treats handlers
operationally; Kiselyov–Ishii (2015) §2 treats the freer-monad
equivalence. Before this claim becomes doctrinal in the swift-io thesis,
locate a formal statement (or prove the one we need). Flagged as open
work item in §9.

## 6. Current swift-io operations mapped to a candidate Σ_IO

This is the applied half: the operations already implemented or planned
in `perfect-api.md` and `io-architecture.md`, recast as effect
signatures.

### 6.1 Σ_Blocking — thread-pool dispatch

```
dispatch : (Work → A) → A
```

Current form: `IO.run.blocking { computeHash(data) }`.
Handler: `IO.Blocking` thread pool.

### 6.2 Σ_Event — readiness (reactor)

```
register   : (FileDescriptor, ReadinessMask) → Token
wait       : Token → ReadinessSet
unregister : Token → 1
```

Current form: `IO.Event.Selector`, `IO.Event.Channel`, `IO.Event.Token`.
Handlers: kqueue on Darwin, epoll on Linux.

### 6.3 Σ_Completion — submit-result (proactor)

```
submit_read    : (FileDescriptor, Buffer, Offset) → Count
submit_write   : (FileDescriptor, Buffer, Offset) → Count
submit_accept  : FileDescriptor → FileDescriptor
submit_connect : (FileDescriptor, SocketAddress) → 1
submit_cancel  : CompletionToken → 1
```

Current form: `IO.Completion.{Read,Write,Accept,Connect}`.
Handler: `IO.Completion.Driver` — io_uring on Linux; today a
reactor-backed emulation elsewhere.

### 6.4 Σ_Stream — byte-stream operations (derived)

```
next   : Reader → Option<Span<Byte>>
write  : (Writer, Span<Byte>) → Count
flush  : Writer → 1
shutdown : {Reader, Writer} → 1
close    : {Reader, Writer} → 1
```

Current form: `IO.Reader`, `IO.Writer` (perfect-api.md §"IO.Reader and
IO.Writer API"). Handlers factor through Σ_Event or Σ_Completion
depending on the bound driver.

This "factor through" is the critical piece: a handler for Σ_Stream
given a handler for Σ_Event is a *transformation* between handler
algebras — exactly what algebraic-effects coproduct composition
supplies.

### 6.5 The full core theory

```
Σ_IO = Σ_Blocking  ⊕  Σ_Event  ⊕  Σ_Completion  ⊕  Σ_Stream
```

With consumer layers added by further coproduct:

```
Σ_Socket : { connect, accept, send, recv, shutdown }
Σ_File   : { open, close, read, write, seek, stat, fsync }
Σ_Timer  : { schedule, cancel, now }
Σ_Channel : { send, receive, close }  -- user-space channel
```

`Σ_Ecosystem = Σ_IO ⊕ Σ_Socket ⊕ Σ_File ⊕ Σ_Timer ⊕ Σ_Channel`.

Socket IO does not *depend on* swift-io; it *extends* swift-io's theory.
Its handler discharges Σ_Socket operations by reducing them to Σ_IO
operations. That is the formal content of the thesis sentence "socket
IO composes on swift-io".

## 7. Candidate equations E_IO

Draft only. These become handler obligations; the test suite asserts
them.

**Idempotence**
```
close(fd); close(fd)   =  close(fd)
shutdown(w); close(w)  =  close(w)
```

**Zero-operation triviality**
```
read(fd, 0)     =  return 0
write(fd, ∅)   =  return 0
```

**Readiness consistency**
```
register(fd, m); unregister(tok); register(fd, m)
  =  register(fd, m)                       -- modulo token identity
```

**Stream EOF terminality**
```
next(r) = None  ⟹  next(r) = None  forever
```

**Completion cancellation soundness**
```
submit_cancel(tok); await(tok)   =  await(tok)   -- cancelled or
                                                 -- already-completed;
                                                 -- no new effect
```

**Blocking transparency**
```
dispatch(λ_. return v)   =  return v
```

These need refinement (and some will turn out to be conditional on
handler class, e.g. Linux vs Darwin), but they establish the shape of E_IO.

## 8. Where the current tracks sit in the theory

### 8.1 `io-algebra` experiment

- **What it has**: `pure`, `map`, `flatMap`, `andThen`, `provide`,
  `local`, `ask`, `fail`, `from`. These are the **structural
  combinators** of the ReaderT · ExceptT · IO stack (Liang–Hudak–Jones
  1995).
- **What it lacks**: Σ — no enumerated operation constructors. Every
  effect is hidden inside the closure in `IO.run`. This is the
  Moggi-style "big IO monad", not yet a proper algebraic effect theory.
- **To make it algebraic**: introduce explicit operation constructors
  (`IO.read`, `IO.write`, …) that are defunctionalised rather than
  opaque closures, and/or adopt the freer-monad encoding (Kiselyov–Ishii
  2015 §3) so that handlers may inspect the operation.

### 8.2 Shape F

- **What it has**: capability structs (signature) + runner actors
  (handler). This is the direct/dictionary encoding of algebraic
  effects (Leijen 2017 §4).
- **What it lacks**: explicit naming of (Σ, E). The witnesses describe
  operations but not the equational theory they jointly satisfy.
- **To make it algebraic**: enumerate the signatures per witness; write
  the law set as handler-conformance tests; articulate the coproduct
  composition story (how a Socket runner combines with an Event runner).

### 8.3 Unified position

Both tracks implement algebraic effects, under different encodings. The
thesis does **not** require choosing between them. It requires naming
the theory they both implement, so that:

- Socket / File / Timer authors know what signature they are extending.
- Test suites can be written against the laws rather than the encoding.
- Cross-encoding interoperability is defined (a program written against
  the signature runs under either a free-encoded handler or a
  dictionary-encoded handler).

## 9. Caveats and open verification work

1. **Free ↔ dictionary equivalence citation.** Standard folklore; no
   single canonical paper locates the theorem in the precise form used
   in §5.3. Work item: find or write the proof.

2. **Delimited-continuation dependency.** Algebraic-effects literature
   (Bauer & Pretnar 2015 §5; Leijen 2017 §3) assumes delimited
   continuations as runtime support for *user-defined* handlers that
   resume operations non-trivially (nondeterminism, backtracking,
   multi-shot). Swift lacks native delimited continuations.
   - **For first-order IO** (single-resume handlers — read, write,
     syscall) this is fine; async/await is sufficient.
   - **For higher-order control** (user-defined resumable effects) you
     will hit the boundary.
   - Work item: state explicitly which fragment of algebraic effects
     swift-io commits to. Probably: "single-resume handlers on
     first-order signatures, with async/await as the underlying control
     mechanism."

3. **Session types on top.** Honda–Yoshida session types type *the
   protocol* that consumers implement using Σ_Socket etc. They are
   complementary to this foundation, not competing. A later research
   note may layer session types over Σ_Socket to give protocol-level
   guarantees.

4. **Equations vs. performance.** Some E_IO equations (e.g. zero-length
   read/write triviality) may not hold at the handler level if the
   handler does observable work (e.g. yielding). They will hold
   *extensionally* (same returned value) but not *operationally*. This
   distinction needs stating. (Plotkin–Power 2003 §7 discusses
   operational vs. equational.)

5. **`~Copyable` and linearity.** Algebraic-effects papers assume a
   non-linear lambda calculus. swift-io's ~Copyable resources
   (descriptors, streams) introduce linearity into the signature. The
   effects-with-linearity literature exists (e.g. Fu et al.,
   *Handling Bidirectional Control Flow*, OOPSLA 2020; work on linear
   effect handlers in Koka) but has not been surveyed here. Work item.

## 10. Next steps before consolidation

In order of dependency:

1. Read Pretnar (2015) *Introduction* — establish shared vocabulary.
2. Read Swierstra (2008) §§3–5 — confirm coproduct formalism.
3. Read Kiselyov & Ishii (2015) §§2–3 — confirm freer-monad encoding
   and its equivalence to handler semantics.
4. **Write `swift-io-thesis.md`** citing this note for vocabulary.
   Thesis sentence (candidate):

   > swift-io encodes the algebraic theory `(Σ_IO, E_IO)` of
   > composable IO effects (§6–7 of this note). Socket IO, File IO,
   > Timer IO, and Channel IO extend this theory by signature
   > coproduct. Programs are written against signatures; handlers
   > discharge them. Two encodings are supported: direct (witness
   > structs, Shape F) and free (monadic values, io-algebra). Both
   > preserve E_IO.

5. Formalise Σ_IO — each operation with input type, output type, and
   informal English law statement. Lives as its own research note,
   e.g. `io-effect-signature.md`.

6. Formalise E_IO — each law as an equation with both
   operational-semantics statement and property-test expression. Lives
   as `io-effect-laws.md`.

7. Re-audit the existing research corpus (the ~40 notes in
   `swift-io/Research/`) against the thesis, classifying each as
   *supports* / *supersedes prior* / *historical* / *relocates to
   {kernel,executors,primitives}/Research/*.

8. Rewrite one of the existing handlers (e.g. `IO.Event.Driver`
   kqueue) as an explicit `(Σ_Event, E_Event)` handler, with property
   tests asserting the laws. This proves the theory has operational
   weight and is not a coat of paint.

## 11. Existing-corpus cross-references

The 2026-04-20 corpus audit (`io-research-corpus-audit.md`) classified
12 existing notes as `supports-thesis`. The four most load-bearing are
re-cited here for direct consultation:

| Note | What it grounds |
|------|-----------------|
| `perfect-api.md` v3.0 | Consumer-facing surface of Σ_IO under the dictionary encoding. The Tier 0 three-word interface (`IO.run`, `IO.read`, `IO.write`) is the unified handler entry point. |
| `io-architecture.md` v1.2 | Concrete five-target implementation of the four signature components. Maps directly: Blocking → Σ_Blocking, Events → Σ_Event, Completions → Σ_Completion, Reader/Writer → Σ_Stream. |
| `io-witness-design-literature-study.md` v4.0 | Academic grounding for witness-as-capability and runner-as-handler — the same Plotkin–Power–Pretnar tradition this foundation note builds on, arrived at independently from the Shape F direction. |
| `completion-queue-ownership-redesign.md` v2.0 | Operational realisation of E_IO's "single-point-authority" law: one terminal outcome wins; no split serialisation. Demonstrates the law-preservation requirement biting in concrete code. |

The remaining 8 `supports-thesis` notes plus the 6 `supersedes-prior`
notes appear in the audit's per-classification tables.
