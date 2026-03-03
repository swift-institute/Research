# Handler-Witness Conceptual Identity

<!--
---
version: 1.0.0
last_updated: 2026-03-03
status: DECISION
tier: 1
---
-->

## Context

During review of `swift-effects`' `EffectWithHandler` protocol, the term "Handler" triggered a conceptual connection: **handles and witnesses are related concepts**. Both provide evidence that something can be done. A witness *testifies* to a capability; a handler *handles* an operation. The question is whether this terminological resonance reflects a deeper structural identity.

The Swift Institute maintains two parallel systems:
- **swift-witnesses** (L1 primitives + L3 foundations): struct-of-closures representing capabilities
- **swift-effects** (L1 primitives + L3 foundations): effect types with handlers via continuations

Both use `Dependency.Key` + `@TaskLocal` scoping for lookup. The existing research document `protocol-witness-effects-capability-abstraction.md` analyzes *which to use when*. This document investigates the deeper question: *are they the same thing?*

**Trigger**: [RES-001] Terminological curiosity revealing potential conceptual unity.
**Scope**: Ecosystem-wide (conceptual, not code-changing).

## Question

**Are effect handlers and protocol witnesses the same concept at different levels of abstraction, and what does this identity (or distinction) mean for the Swift Institute's architecture?**

## Analysis

### Option A: They Are the Same Thing (Identity Thesis)

In programming language theory, both terms originate from proof theory:

| Term | Origin | Meaning |
|------|--------|---------|
| **Witness** | Constructive logic | A value that *proves* a proposition. If you claim "type T can be parsed," the witness is the parsing function itself. |
| **Handler** | Algebraic effects (Plotkin & Pretnar, 2009) | A value that *interprets* an operation. If an effect says "read input," the handler provides the implementation. |

Under the Curry-Howard correspondence, both are **proof objects**: values that provide evidence for a claim. The claim is "this capability/operation is implemented." The witness/handler is the implementation.

**Structural parallel in Swift Institute code:**

| Aspect | Witness (`swift-witnesses`) | Handler (`swift-effects`) |
|--------|---------------------------|--------------------------|
| What it is | Struct with closure properties | Struct conforming to `__EffectHandler` |
| What it proves | "This capability exists" | "This effect can be interpreted" |
| How it's found | `Witness.Context.current[Key.self]` | `Effect.Context.current[Key.self]` |
| How it's scoped | `Witness.Context.with { ... }` | `Effect.Context.with { ... }` |
| Multiple impls | Yes (test, live, preview) | Yes (test, live) |
| Key protocol | `Witness.Key` | `Dependency.Key` (aliased as `Effect.Context.Key`) |
| Value container | `Witness.Values` (UnsafeRawPointer, CoW) | `Dependency.Values` (Dictionary) |
| Test support | `Witness.Recording`, `.unimplemented()` | `Effect.Test.Handler`, `Effect.Test.Spy` |

This is not coincidence. Both are implementations of **dictionary-passing style** — the technique Wadler & Blott (1989) identified as the essence of typeclasses. A typeclass instance IS a witness IS a handler: a dictionary of operations keyed by type, passed implicitly through context.

**Supporting evidence**: `Effect.Context` is literally a type alias for `Dependency.Scope`:

```swift
// Effect.Context.swift
extension Effect.Context {
    public typealias Key = Dependency.Key
    public typealias Handlers = Dependency.Values
}
```

The effect system builds on the *same substrate* as the witness system. The handler lookup is witness lookup with different terminology.

### Option B: They Are Distinct (Separation Thesis)

Despite the structural parallel, there is a critical operational difference: **continuations**.

A witness closure is called and returns:
```swift
// Witness: direct call
let result = witness.parse(&input)
```

An effect handler receives a **suspended computation** and must resume it:
```swift
// Handler: continuation-based
func handle(_ effect: E, continuation: consuming Effect.Continuation.One<V, F>) async {
    let result = computeSomething(effect)
    await continuation.resume(returning: result)
}
```

This is not a surface difference. It changes the computational model:

| Property | Witness | Handler |
|----------|---------|---------|
| Control flow | Caller retains control | Control transfers to handler |
| Resumption | Implicit (function return) | Explicit (`continuation.resume`) |
| Multiplicity | Always resumes once | Can resume zero times (Exit), once (normal), or many (Multi) |
| Suspension | Synchronous | Async (requires suspension point) |
| Ownership | Closures are `@Sendable` and copyable | One-shot continuation is `~Copyable` |

Plotkin & Pretnar (2009) formalized this: a handler is a **generalized fold** over a free monad of operations. A witness is just a record of functions. The handler has strictly more structure because it can intercept, transform, or refuse to resume the computation.

### Option C: They Are Related by Adjunction (Unification Thesis)

The most precise characterization: **a witness is a handler that always resumes exactly once, synchronously**.

```
Witness ⊂ Handler
```

Every witness can be trivially lifted to a handler:
```swift
// Any witness closure can become a handler:
func handle(_ effect: E, continuation: consuming Effect.Continuation.One<V, Never>) async {
    let result = witness.operation(effect.arguments)
    await continuation.resume(returning: result)
}
```

But not every handler can be collapsed to a witness:
- `Effect.Exit.Handler` consumes the continuation without resuming (zero-shot)
- `Effect.Continuation.Multi` can resume multiple times (backtracking)
- Handlers can perform async work before resuming

The relationship is an **embedding**: witnesses embed into handlers, but handlers do not project onto witnesses. In categorical terms, there is a forgetful functor from handlers to witnesses (forget the continuation structure), with a left adjoint that freely adds continuation support.

### Comparison

| Criterion | A: Identity | B: Separation | C: Unification |
|-----------|-------------|---------------|----------------|
| Explains shared infrastructure | Yes | Partially | Yes |
| Explains operational differences | No | Yes | Yes |
| Explains terminology ("handle" ↔ "witness") | Yes | No | Yes |
| Actionable for architecture | Merge them? | Keep separate | Keep separate, document relationship |
| Theoretical precision | Low | Medium | High |

## Outcome

**Status**: DECISION

**Option C (Unification Thesis)**: A witness is a degenerate handler — a handler constrained to resume exactly once, synchronously. They share the same conceptual DNA (dictionary-passing, proof objects, capability evidence) and the same infrastructure (`Dependency.Key`, `@TaskLocal` scoping). The operational difference (continuation) is real and meaningful, justifying separate types and APIs.

### What "Handler" Means

The term "handler" in `EffectWithHandler` carries a precise meaning from algebraic effects theory: it is the **interpreter** of an effectful operation. When code performs an effect, it suspends, and the handler decides what happens next. The handler literally *handles* the situation — it has full control over whether, when, and how to resume.

A witness, by contrast, is *called* rather than *consulted*. The caller retains control. The witness provides a function; the caller invokes it. This is why witnesses feel like "capabilities" and handlers feel like "interceptors."

### Why the Terminology Resonated

The intuition that "handles" relates to "witness" is correct at the type-theoretic level: both are **values that provide evidence for an interface**. In Swift's compiler, protocol conformances are literally called "witness tables" — they are lookup tables of function pointers, exactly the same structure as a `Witness.Protocol` struct.

The connection runs deeper: Swift's runtime protocol witness tables are the compiler's version of what `swift-witnesses` makes explicit at the library level. And `__EffectHandler` conformances stored in `Dependency.Values` are witness tables for effects, looked up at runtime rather than compile time.

### Architectural Implication

The current separation is correct. Witnesses and handlers solve different problems:

- **Witness**: "I need a capability. Give me the function and I'll call it." → Direct, synchronous, the caller is in charge.
- **Handler**: "I want to perform an operation. Someone else decides what happens." → Indirect, async, the handler is in charge.

The shared `Dependency.Key` substrate correctly reflects that both are forms of capability evidence. The separate `Witness.Context` vs `Effect.Context` correctly reflects that they operate differently.

No code changes recommended. The architecture already embodies the correct relationship.

## References

- Wadler, P. & Blott, S. (1989). "How to make ad-hoc polymorphism less ad hoc." POPL 1989. — Typeclasses as dictionary passing.
- Plotkin, G. & Pretnar, M. (2009). "Handlers of Algebraic Effects." ESOP 2009. — Handlers as generalized folds.
- `protocol-witness-effects-capability-abstraction.md` — Structural comparison of witnesses vs effects for capability modeling.
- `swift-witness-primitives` — `Witness.Protocol`, witness composition.
- `swift-effect-primitives` — `Effect.Protocol`, `Effect.Handler`, `Effect.Continuation.One`.
- `swift-effects` — `EffectWithHandler`, `Effect.perform`.
