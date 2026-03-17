# Converged Plan: Structural Type Primitives Decomposition

## Summary

Three independent macros, each corresponding to a distinct mathematical/CS operation, with shared enum infrastructure in a neutral support package:

- **`@Dual`** — categorical duality (category theory). Structural shape transformation: product ↔ coproduct.
- **`@Defunctionalize`** — first-order call algebra extraction (Reynolds 1972). Reifies higher-order operations as first-order syntax.
- **`@Witness`** — DI/test/observation composition (software engineering). Layered above defunctionalization.

## Key Decisions

- `@Dual` and `@Defunctionalize` are **separate macros** with distinct contracts and invariants. Defunctionalization is NOT a parameterization of duality (Option B rejected). Hiding defunctionalization inside @Witness leaves a real primitive unnamed (Option C rejected).
- **`@Dual` preserves literal field types**, including closure types. `case fetch((Int) -> String)` is the correct structural dual. Restricting closure fields would break the involution invariant.
- **`@Defunctionalize` excludes non-function fields.** Defunctionalization lowers higher-order to first-order. Already-first-order fields are not its concern.
- **`@Defunctionalize` generates only the call algebra** (the enum of operation tags + arguments). No apply/interpreter — downstream consumers provide their own interpretation. This is the reification step of Reynolds' transformation, which is the decisive part.
- **Effects not in the call algebra.** The enum captures *what operation* with *what arguments*. Async/throws/typed errors are properties of the operation signature, tracked downstream by @Witness.
- **`@Defunctionalize` on enums is an error.** One-way, partial, directional. Refunctionalization is a different concept.
- **Macro name = specification term. Generated type = call-site optimized.** `@Defunctionalize` → `T.Calls`. `@Dual` → `T.Dual`.
- **Enum infrastructure (prisms, discriminants, extraction) is cross-cutting codegen convention**, not part of either theory's contract. Any macro-generated enum receives standard utilities.
- **Shared codegen lives in a neutral support package**, not in swift-dual. The dependency graph must not encode false semantic relationships.

## Contracts

| | @Dual | @Defunctionalize | @Witness |
|---|---|---|---|
| **Input** | Product or coproduct type | Struct with ≥1 function-typed stored property | Struct with function-typed stored properties |
| **Output** | Structural dual | First-order call algebra | DI/test/observation scaffolding |
| **Invariant** | Shape preservation up to dualization | Higher-order ops reified as first-order sum | Practical composition over defunctionalized model |
| **Generated type** | `T.Dual` | `T.Calls` | Reuses call algebra + adds DI types |
| **Enum input** | Yes (→ handler struct `Dual<R>`) | Error | Error |
| **Closure fields** | Literal type preserved | Parameters extracted | Parameters extracted + effects tracked |
| **Value fields** | Included as cases | Excluded | Excluded from Calls |
| **Enum infra** | Yes (cross-cutting) | Yes (cross-cutting) | Yes (cross-cutting) |

## Package Architecture

```
swift-codegen-support/              Shared enum infrastructure (.target)
├── PrismCodegen                    PrismCase, generatePrism
├── CaseDiscriminantCodegen         Finite.Enumerable Case enum
├── ExtractionCodegen               extraction properties, Prisms struct
└── Utilities                       escapeIdentifier (extended for spaces)

swift-dual/                         @Dual macro
├── imports swift-codegen-support
├── StructExpansion                 struct → Dual enum
├── EnumExpansion                   enum → Dual<R> struct + match
└── tests

swift-defunctionalize/              @Defunctionalize macro
├── imports swift-codegen-support
├── StructExpansion                 struct → Calls enum (function fields only)
└── tests

swift-witnesses/                    @Witness macro (refactored)
├── imports swift-codegen-support
├── conceptually downstream of defunctionalization
├── adds: observe, unimplemented, mock, Key, Result, Outcome
└── tests
```

## Naming

| Concept | Name | Source |
|---------|------|--------|
| Macro: structural dual | `@Dual` | Category theory |
| Macro: call algebra extraction | `@Defunctionalize` | Reynolds 1972 |
| Macro: DI composition | `@Witness` | Protocol witness literature |
| Generated dual type | `T.Dual` | Category theory |
| Generated call algebra | `T.Calls` | Call-site readability |
| Case analysis function | `match` | Standard PL (Rust, Scala, ML) |
| Optic | `Prism` | van Laarhoven / Kmett |
| Tag enum | `Case` | Tagged union discriminant |

## Implementation Order

1. `swift-codegen-support` — shared enum infrastructure
2. `swift-dual` — @Dual macro (both directions)
3. `swift-defunctionalize` — @Defunctionalize macro
4. Refactor `swift-witnesses` — compose on defunctionalization + DI

## Agreed By

- Claude: Round 4
- ChatGPT: Round 4
