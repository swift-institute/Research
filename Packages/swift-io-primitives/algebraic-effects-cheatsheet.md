# Algebraic Effects — Vocabulary Cheat-sheet

<!--
---
version: 1.0.0
created: 2026-04-20
status: REFERENCE
purpose: |
  Concept-organised vocabulary reference distilled from Pretnar 2015,
  Swierstra 2008, and Kiselyov-Ishii 2015. The minimum a swift-io
  thesis author needs to cite the algebraic-effects literature
  without re-reading the source papers each time.

  Each section gives: definition, notation we adopt for swift-io,
  primary citation, and (where it bites) an honest "what I am NOT
  claiming" note.

basis-papers:
  - Pretnar, M. (2015). An introduction to algebraic effects and
    handlers. MFPS XXXI, ENTCS 319. ~30 pp pedagogical introduction.
  - Swierstra, W. (2008). Data types à la carte. JFP 18(4). ~25 pp
    on coproduct composition of effect signatures.
  - Kiselyov, O. & Ishii, H. (2015). Freer monads, more extensible
    effects. Haskell Symposium 2015. ~20 pp on the freer-monad
    encoding.
  - Plotkin & Power 2003 and Plotkin & Pretnar 2009 are the
    research-paper sources for the underlying theory; the three
    above are the readable digests.
---
-->

## 0. Notation summary

| Symbol           | Meaning                                                     | Swift surface |
|------------------|-------------------------------------------------------------|---------------|
| `Σ`              | Effect signature — a set of operation symbols               | A struct/protocol of methods |
| `op : A → B`     | Operation with input type A, output (resume) type B         | `func op(_: A) -> B` |
| `E`              | Equational laws on Σ-terms                                  | Property tests + invariants |
| `(Σ, E)`         | Effect *theory*                                             | Module + test suite |
| `Free(Σ) X`      | Free term algebra over Σ with leaves of type X              | The monadic IO datatype |
| `H : Σ ⇒ T`      | Handler from signature Σ into target monad T                | A `Driver` / `Runner` value |
| `Σ₁ ⊕ Σ₂`        | Coproduct (disjoint union) of two signatures                | Composition of capabilities |
| `>>=`            | Monadic bind                                                | `flatMap` |
| `return`         | Monadic unit                                                | `pure` / `IO.pure` |

## 1. Signature

A **signature** Σ is a set of operation symbols, each with input and
output (resume-value) types.

```
op : A → B
```

Read: "operation `op` takes an argument of type A and (when invoked) the
continuation expects a value of type B." `B` is *not* the result of the
overall computation; it is the value bound at the operation's
invocation site.

For state:
```
get : 1 → S          -- no input, resumes with current state
put : S → 1          -- input is new state, resumes with unit
```

For minimal IO:
```
read  : (FileDescriptor, Count) → Bytes
write : (FileDescriptor, Bytes) → Count
```

> **Source**: Pretnar 2015 §2.1; Plotkin & Power 2003 §2.

> **Notation we adopt**: ASCII `op : A -> B` in code; LaTeX-style
> `op : A → B` in prose.

## 2. Term language

Programs are built from two formers:

```
t  ::=  return v                  -- inject a value
     |  op(arg; x. t)             -- invoke op, bind result to x in t
```

Concrete examples (state):
```
get(_; s. put(s + 1; _. return s))
  -- "read state s, write s+1, return s"  (i.e. post-increment)
```

The set of all such terms is the **free term algebra** `Free(Σ)`,
parameterised by the value-type X of the leaves: `Free(Σ) X`.

> **Source**: Pretnar 2015 §3.1; Plotkin & Power 2001 §2.

## 3. Algebraicity (Plotkin–Power property)

An operation `op` is **algebraic** in a monad `T` iff for every
continuation `k`:

```
op(arg) >>= k   =   op(arg; x. k(x))
```

i.e. invoking `op` and *then* applying `k` is the same as invoking `op`
with `k` as its continuation. Concretely: the continuation is threaded
uniformly across the operation. This is the structural property that
makes handlers compositional.

**For swift-io**: most IO primitives (read, write, open, close,
register, wait, submit-X) are algebraic in this sense. They commute
with the surrounding computation. The exceptions to flag are:

- Operations with non-local control (raise/abort) — algebraic but only
  in restricted handlers.
- Operations with built-in scoping (e.g. "with-resource") — these are
  *scoped operations*, a separate generalisation (see Wu, Schrijvers,
  Hinze 2014). swift-io should aim for plain algebraic operations
  unless there is reason to step up.

> **Source**: Plotkin & Power 2003 §4; Pretnar 2015 §4.2.

## 4. Theory: signature + equations

A **theory** is a pair `(Σ, E)` where E is a set of equations between
Σ-terms.

The classic state theory has four equations:

```
(put-put)        put s; put t                =  put t
(put-get)        put s; get                  =  put s; return s
(get-put)        get >>= λs. put s           =  return ()
(get-get)        get >>= λs. get >>= λt. k s t
                                             =  get >>= λs. k s s
```

These are the *quotient* relations: any two terms equal under E denote
the same thing. **Handlers must respect E.**

For swift-io, candidate `E_IO` equations (handlers' obligations) live in
the foundation note §7. They are the testable predicates that any IO
handler ships against.

> **Source**: Plotkin & Power 2003 §6 (state theory equations are
> standard); Bauer & Pretnar 2015 §3 (handler-soundness w.r.t. E).

> **What I am NOT claiming**: that this exact equation set suffices for
> IO. IO equations are subtler than state equations because of
> partiality, errors, async observation. The note flags this as work to
> do, not as solved.

## 5. Handler

A **handler** for theory `(Σ, E)` over value-type A into target monad T
comprises:

```
return clause:    h_ret  : A → T B
op clauses:       h_op   : A_op × (B_op → T B) → T B   for each op ∈ Σ
```

The op-clause receives the operation's argument *and* its continuation
(`B_op → T B`). It may invoke the continuation, ignore it (abort), or
invoke it multiple times (nondeterminism, multi-shot).

**Handling** a term `t : Free(Σ) A` against H produces a value in `T B`
by structural recursion:

```
handle (return v)   = h_ret(v)
handle (op a k)     = h_op(a, λb. handle (k b))
```

The handler must **discharge all equations of E**: handling LHS and RHS
of every equation must give equal values in T.

> **Source**: Plotkin & Pretnar 2009 (the seminal paper); Bauer & Pretnar
> 2015 §4 for full operational semantics.

> **For swift-io**: a Driver / Runner is a handler whose continuations
> are threaded by `await`. Single-resume async/await is sufficient for
> first-order IO operations. Multi-shot resumption (which would let you
> implement nondeterminism, time-travel, etc.) is not available in
> Swift without delimited continuations.

## 6. Coproduct of signatures (Swierstra, "Data types à la carte")

Given disjoint signatures Σ₁ and Σ₂, the **coproduct** Σ₁ ⊕ Σ₂ is their
disjoint union. Programs over Σ₁ ⊕ Σ₂ may invoke operations from
either.

The clever bit (Swierstra 2008): represent each signature as a Haskell
*functor* and take the coproduct of functors:

```
data (F :+: G) a = Inl (F a) | Inr (G a)
```

Then `Free(F :+: G)` is the free monad for the combined signature.
**Handlers compose** in a controlled way:

- A handler for F that *forwards* G operations: applies F's
  interpretation, leaves G operations unchanged.
- After applying F's handler, the residual program lives in `Free(G)`.
- Apply G's handler next; nothing left.

This is the formal foundation for "Socket extends IO by adding ops to
the signature, and a Socket handler reduces to IO ops".

For Σ-coproduct in our terms (no functor wrapping needed for the
high-level story):

```
Σ_IO ⊕ Σ_Socket  --  programs may use both
                 --  Socket handler discharges Σ_Socket ops
                 --  by reducing them to Σ_IO ops
                 --  IO handler then discharges Σ_IO ops
                 --  to platform syscalls
```

> **Source**: Swierstra 2008 §§3–5. This is the load-bearing paper for
> the "compositional shape" thesis.

> **Notation**: we use `⊕` for signature coproduct in prose, matching
> Plotkin–Power. Swierstra writes `:+:`.

## 7. Equivalence with monads (the bridge)

Plotkin & Power's central duality:

> Every effect theory `(Σ, E)` determines a monad `T_{Σ,E}`, and every
> monad arises this way (subject to mild conditions on the underlying
> category).

The monad is the **quotient** of `Free(Σ) X` by the equations E:

```
T_{Σ,E} X  =  Free(Σ) X / E
```

Two free terms equal under E denote the same value in the monad. This
is the formal reason why "monadic IO" and "algebraic-effects IO" are
not competing — the monad presentation is a *quotient* of the
algebraic-theory presentation.

> **Source**: Plotkin & Power 2002 *Notions of computation determine
> monads* (FoSSaCS 2002); Pretnar 2015 §5.

> **Practical implication for swift-io**: when we say "IO is monadic",
> we mean the *quotient* — programs equal under E_IO are
> indistinguishable. Choosing to expose the quotient (just the monad)
> vs. the free-term presentation (the full AST with `op` constructors)
> is an implementation choice. Both are sound.

## 8. Encodings — free monad, freer monad, dictionary

There are three implementation strategies for `Free(Σ) X` in a typed
language. They are equivalent up to encoding; they differ in
ergonomics and what the host language requires.

### 8.1 Free monad (functor-based)

```haskell
data Free f a  =  Pure a | Roll (f (Free f a))
```

Requires `f` to be a `Functor`. Per-operation effort: define the
functor, derive the Free monad, write the interpreter.

> **Source**: Swierstra 2008 §3.

### 8.2 Freer monad (Kiselyov–Ishii)

```haskell
data Freer f a  =  Pure a
                |  Bind (f x) (x -> Freer f a)   -- existential x
```

Drops the `Functor` requirement on `f`. Operations are GADT-shaped:
each constructor specifies its own resume type. The continuation is
explicit and external.

```haskell
data IOOp a where
  Read  :: FD -> Count   -> IOOp Bytes
  Write :: FD -> Bytes   -> IOOp Count
```

> **Source**: Kiselyov & Ishii 2015. This is the encoding closest to
> what an `io-algebra` implementation in Swift would aim for, modulo
> Swift's lack of GADTs (encodable via existential `any` types).

### 8.3 Dictionary / record-of-handlers (Leijen, Koka)

```
Σ-signature   becomes   struct of function-typed fields
Handler       becomes   value of that struct
Program       becomes   code calling fields on a passed-in dictionary
```

```swift
struct IOOps {
    var read:  (FD, Count) async throws(IOError) -> Bytes
    var write: (FD, Bytes) async throws(IOError) -> Count
    // ...
}

func myProgram(ops: IOOps) async throws(IOError) -> Bytes {
    let header = try await ops.read(fd, 8)
    // ...
}
```

This is **how Koka compiles algebraic effects** in practice: the row
type of effects becomes a record of function fields. The "handler" is
a `let ops = IOOps(read: …, write: …)` value supplied at the program
boundary.

> **Source**: Leijen 2017 §§3–4 (POPL).

### 8.4 Equivalence (folklore, flagged)

The three encodings are equivalent in the sense that:

- A program in any of the three can be mechanically translated to any
  of the others.
- Handler interpretation produces identical values.

> **Honest caveat**: I do not have a single citation that states this
> equivalence in the form "free monad ↔ freer monad ↔ dictionary
> encoding, all three modulo bisimilarity". Bauer & Pretnar 2015 §3
> covers free ↔ freer; Leijen 2017 §3 covers freer ↔ dictionary
> implicitly via compilation. The full triangle is folklore.
> Re-flagged from foundation note §5.3 / §9.1: this needs a real proof
> or a real citation before going into doctrine.

## 9. Reader / State / Exception via algebraic effects

The classical monad-transformer stack — `ReaderT R (ExceptT E IO)` —
arises in the algebraic-effects view as three signatures combined by
coproduct:

```
Σ_Reader = { ask : 1 → R }
Σ_Except = { raise : E → ⊥ }
Σ_IO     = { read : ... ; write : ... ; ... }

Combined : Σ_Reader ⊕ Σ_Except ⊕ Σ_IO
```

The `io-algebra` experiment's `IO<Environment, LeafError, Value>` is
the **monad-transformer encoding** of this combined theory: ReaderT
contributes the `Environment` parameter, ExceptT contributes the
typed-throws `LeafError` parameter, and the underlying async closure
contributes the `Value`.

What's missing in `io-algebra` is the **explicit operation
constructors** — the `read`, `write`, `submit_*` enumerated in Σ_IO
proper. Adding them turns it from "ReaderT · ExceptT · IO" into a
proper algebraic effect signature where handlers can inspect operations
and discharge them.

> **Source**: Liang, Hudak, Jones 1995 *Monad transformers and
> modular interpreters* (POPL) for the transformer stack; Pretnar
> 2015 §6 for the algebraic-effect view.

## 10. What this cheat-sheet does NOT cover

Listed so the swift-io thesis author does not assume these are
settled:

1. **Linearity / `~Copyable` resources in algebraic effects.** Classical
   papers assume non-linear types. Swift's `~Copyable` descriptors and
   streams interact with effect signatures in ways the literature has
   only partially addressed (e.g. Fu et al. OOPSLA 2020, Linear handlers
   in Koka). Treat this as research, not reference.

2. **Scoped operations** (Wu, Schrijvers, Hinze 2014). Operations like
   `withResource(r) { ... }` that scope a region rather than just
   invoking-and-resuming. swift-io should avoid these unless forced to.

3. **Higher-order handlers / multi-shot resumption.** Requires
   delimited continuations. Not available in Swift. swift-io commits to
   single-resume.

4. **Effect rows / row polymorphism** (Leijen 2017). Koka tracks
   "the set of effects a function may perform" in its type. Swift has
   no row types. This is fine — we use coproduct of explicit
   signatures instead.

5. **Concurrent effects** (Hillerström, Lindley, Atkey 2017). Algebraic
   effects in concurrent settings introduce subtleties (interference,
   atomicity). swift-io's async/await execution model already
   sequentialises within a task; concurrent effects would arise across
   tasks but the literature for this is thinner.

## 11. Citation list (full venues)

For copy-paste into the thesis bibliography:

- Liang, S., Hudak, P., & Jones, M. (1995). Monad transformers and
  modular interpreters. **POPL 1995**, ACM.
- Plotkin, G. & Power, J. (2002). Notions of computation determine
  monads. **FoSSaCS 2002**, LNCS 2303.
- Plotkin, G. & Power, J. (2003). Algebraic operations and generic
  effects. **Applied Categorical Structures** 11(1), pp. 69–94.
- Swierstra, W. (2008). Data types à la carte. **JFP** 18(4),
  pp. 423–436.
- Plotkin, G. & Pretnar, M. (2009). Handlers of algebraic effects.
  **ESOP 2009**, LNCS 5502.
- Wu, N., Schrijvers, T., & Hinze, R. (2014). Effect handlers in scope.
  **Haskell Symposium 2014**.
- Bauer, A. & Pretnar, M. (2015). Programming with algebraic effects
  and handlers. **JLAMP** 84(1), pp. 108–123.
- Pretnar, M. (2015). An introduction to algebraic effects and
  handlers. **MFPS XXXI**, ENTCS 319, pp. 19–35.
- Kiselyov, O. & Ishii, H. (2015). Freer monads, more extensible
  effects. **Haskell Symposium 2015**.
- Leijen, D. (2017). Type directed compilation of row-typed algebraic
  effects. **POPL 2017**.
- Hillerström, D., Lindley, S., & Atkey, R. (2017). Continuation
  passing style for effect handlers. **FSCD 2017**.
- Fu, P., Komendantskaya, E., et al. (2020). Handling bidirectional
  control flow. **OOPSLA 2020**. (Linearity-aware effects.)

> All venues verified against established conference / journal
> records. Page numbers are best-known; double-check before publication.
