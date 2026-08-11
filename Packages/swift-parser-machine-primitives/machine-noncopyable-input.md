# Machine ~Copyable Input Support

<!--
---
version: 1.0.0
last_updated: 2026-02-24
status: DECISION
---
-->

## Context

`Parser.Protocol.Input` was changed to `~Copyable & ~Escapable` in swift-parser-primitives (commit `ef96edb`). All primitives backtracking combinators (Peek, OneOf, Not, Many, etc.) were converted from copy-based to checkpoint/restore.

Parser Machine Compile Primitives (`Witness`, `Compiled`, `Prepared`) now fails to build because its generic constraint `P.Input: Parser.Input & Sendable` does not include `Copyable`. The underlying `Builder<Input, ...>` and `Expression<Input, ...>` structs have implicit `Copyable` requirements on their `Input` generic parameter.

**Trigger**: Build failure — 14 errors in `Parser Machine Compile Primitives`.

## Question

How should the Parser Machine infrastructure handle `Parser.Protocol.Input: ~Copyable & ~Escapable`?

## Constraints

1. `Parser.Protocol.Input` is `~Copyable & ~Escapable` — this is settled.
2. The Machine runtime already uses checkpoint/restore (`input.checkpoint`, `input.setPosition(to:)`) — compatible with ~Copyable.
3. `Input` is **never stored as a value** in the Machine infrastructure — it flows through `inout` parameters and closure signatures only.
4. `Input.Checkpoint` **is stored** (in `Frame` cases), but `Checkpoint` is a separate associated type constrained to `Sendable & Comparable` in `Input.Protocol`.

## Analysis

### How Input Flows Through the Machine

```
Parser.Machine.Compile.Witness<P>
    → stores closure: (P, inout Builder<P.Input, ...>) -> Expression<...>
        → Builder<Input, ...> wraps Machine.Builder<Leaf<Input, ...>, ...>
            → Leaf<Input, ...> stores closure: (inout Input) throws -> Value
                → Machine.Node.leaf(Leaf) stored in Machine.Program graph
                    → Graph.Sequential<Node, Node> backed by Array<Node>.Indexed
```

At every level, `Input` is a **generic type parameter** or **closure parameter type** — never a stored value. The only stored derivatives of Input are:

| Stored value | Type | Source | Copyable? |
|---|---|---|---|
| Leaf closure | `@Sendable (inout Input) throws -> Value` | Leaf.run | Always (function types are Copyable) |
| Checkpoint | `Input.Checkpoint: Sendable & Comparable` | Frame cases | Separate type, not Input |

### Option A: Copyable-Only Machine

Add `& Copyable` to the `P.Input` constraint in `Witness`, `Compiled`, and `Prepared`.

```swift
// Witness, Compiled, Prepared:
where P.Input: Parser_Primitives.Parser.Input & Sendable & Copyable,
```

**Changes**: 3 files in `Parser Machine Compile Primitives`.

**Advantages**:
- Minimal change, immediately fixes the build
- No cascade into Machine Primitives or other packages
- Explicit about what the compilation tier requires

**Disadvantages**:
- Machine execution becomes unavailable for ~Copyable inputs
- Stack-safe recursive parsing (the primary Machine use case) is blocked for ~Copyable input types
- Inconsistent: primitives combinators support ~Copyable, but Machine does not

### Option B: Full ~Copyable Threading

Add `& ~Copyable` to the `Input` generic parameter on all Parser Machine Core types, allowing `Input` to be non-copyable.

**Parser Machine Core Primitives changes** (1 package, ~6 files):

| Type | Current | Proposed | Rationale |
|---|---|---|---|
| `Leaf<Input>` | `Input: Parser.Input` | `Input: Parser.Input & ~Copyable` | Closure param only |
| `Builder<Input>` | `Input: Parser.Input` | `Input: Parser.Input & ~Copyable` | Type param only |
| `Expression<Input>` | `Input: Parser.Input` | `Input: Parser.Input & ~Copyable` | Type param only |
| `Parser<Input>` | `Input: Parser.Input` | `Input: Parser.Input & ~Copyable` | inout param only |
| `Reference<Input>` | `Input: Parser.Input` | `Input: Parser.Input & ~Copyable` | Type param only |
| `Node<Input>` | typealias → Leaf | inherits | — |
| `Program<Input>` | typealias → Leaf | inherits | — |
| `Frame<Input>` | typealias → Checkpoint | inherits | — |
| `run<Input>` | `Input: Parser.Input` | `Input: Parser.Input & ~Copyable` | inout param only |

**Parser Machine Compile Primitives changes** (1 package, 3 files):

| Type | Change |
|---|---|
| `Witness<P>` | P.Input flows through; no explicit Copyable needed |
| `Compiled<P>` | Same |
| `Prepared<P>` | Same |

**Machine Primitives cascade** — None needed if Leaf remains Sendable:

| Machine Primitives type | Constraint | Impact |
|---|---|---|
| `Machine.Node<Leaf, ...>` | `Leaf` (no constraint) | No change — Leaf is still Sendable |
| `Machine.Program<Leaf: Sendable, ...>` | `Leaf: Sendable` | No change — Leaf IS Sendable (stores only a closure) |
| `Machine.Builder<Leaf: Sendable, ...>` | `Leaf: Sendable` | No change |
| `Machine.Frame<..., Checkpoint, ...>` | `Checkpoint` (no constraint) | No change — Checkpoint is always Sendable |

**Key claim**: `Leaf<Input: ~Copyable>` remains Sendable because its only stored property is a `@Sendable` closure. Function types are always Copyable and Sendable regardless of their parameter types. Therefore Machine Primitives types that require `Leaf: Sendable` need **no changes**.

**Advantages**:
- Full ~Copyable support for Machine execution
- Stack-safe recursive parsing available for all input types
- Consistent with the primitives-level ~Copyable design

**Disadvantages**:
- More files touched (~9 vs 3)
- Relies on compiler correctly deriving Copyable/Sendable for structs whose ~Copyable generic parameter is unused in stored properties
- If the compiler does NOT auto-derive these, explicit conditional conformances are needed

### Compiler Unknowns

Option B depends on three compiler behaviors that need experimental validation:

1. **Closure types with ~Copyable parameters**: Is `@Sendable (inout T) throws -> U` a valid stored property when `T: ~Copyable`? Expected: yes — `inout` doesn't copy.

2. **Sendable derivation with phantom ~Copyable**: Does `struct Foo<T: ~Copyable>: Sendable { let f: @Sendable () -> Void }` compile? The struct's stored property is Sendable regardless of T. Expected: yes, but may need `@unchecked Sendable`.

3. **Copyable derivation with phantom ~Copyable**: Is `struct Foo<T: ~Copyable> { let f: Int }` Copyable? T is phantom. Expected: may need explicit `extension Foo: Copyable where T: ~Copyable {}` or similar unconditional conformance.

### Comparison

| Criterion | Option A: Copyable-only | Option B: Full ~Copyable |
|---|---|---|
| Build fix | Immediate | Immediate (same files + more) |
| Scope of change | 3 files, 1 package | ~9 files, 1 package |
| Machine Primitives cascade | None | None (Leaf stays Sendable) |
| ~Copyable Machine execution | Blocked | Supported |
| Compiler risk | None | Low — needs 3 behaviors validated |
| Consistency with primitives | Partial | Full |
| Reversibility | Easy (remove constraint later) | Easy (add constraint later) |

## Outcome

**Status**: DECISION — Option B implemented and validated.

**Decision**: Full ~Copyable threading through all Parser Machine types.

**Rationale**:

1. Input is never stored — the type parameter is phantom with respect to storage
2. The Machine Primitives cascade is avoided (Leaf stays Sendable)
3. It aligns with the ecosystem-level decision to make Parser.Protocol.Input ~Copyable

**Compiler unknowns resolved** — all three validated successfully by building:

1. Closure types with ~Copyable `inout` parameters compile and store correctly
2. Sendable derivation works — compiler auto-derives Sendable for structs whose ~Copyable generic parameter is not stored
3. Copyable derivation works — structs with phantom ~Copyable type parameters remain Copyable

**Implementation details**:

- **Parser Machine Core Primitives**: Added `& ~Copyable` to `Input` generic parameter on `Leaf`, `Builder`, `Expression`, `Parser`, `Reference`, and the `run`/`leaf` functions. All typealiases (`Node`, `Program`, `Frame`) inherit the change.
- **Parser Machine Combinator Primitives**: Added `& ~Copyable` to all combinator functions (`pure`, `tryMap`, `sequence`, `oneOf`, `many`, `optional`, `recursive`, `build`).
- **Parser Machine Memoization Primitives**: Added `& ~Copyable` to the memoized `run` function.
- **Parser Machine Compile Primitives**: No `~Copyable` annotation needed — `P.Input` inherits `~Copyable` from `Parser.Protocol`. The associated type path cannot be re-suppressed at the use site.
- **Parser Machine Parse Primitives**: Same as Compile — no annotation needed.
- **swift-parsers foundations combinators**: Added explicit `Input: Copyable` constraints to `Separated`, `Chain.Left`, `Chain.Right`, and `Expression.Climbing` — these use copy-based backtracking and inherently require Copyable inputs.

All 50 parser-machine-primitives tests pass. All 12 swift-parsers tests pass.

## References

- `swift-parser-primitives` commit `ef96edb` — Parser.Protocol.Input: ~Copyable & ~Escapable
- `swift-parsers/Research/parser-input-noncopyable-support.md` — original ~Copyable research
- Input.Protocol definition: `swift-input-primitives/.../Input.Protocol.swift`
