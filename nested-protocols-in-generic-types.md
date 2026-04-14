# Nested Protocols in Generic Types

<!--
---
version: 1.0.0
last_updated: 2026-02-13
status: DECISION
tier: 3
---
-->

## Context

The `Bit.Vector.Protocol` pattern in `swift-bit-vector-primitives` demonstrates that
nesting a protocol inside a non-generic namespace type eliminates boilerplate across
variant families. Five concrete types (`Bit.Vector`, `.Static`, `.Dynamic`, `.Bounded`,
`.Inline`) each conform to `Bit.Vector.Protocol` by implementing only 3–4 lines of
storage-specific accessors; all higher-level operations (`popcount`, `clearAll`,
`popFirst`, `allTrue`, etc.) are provided as default implementations on the protocol.

We want to apply the same pattern to `Buffer.Arena` in `swift-buffer-primitives`.
However, `Buffer.Arena` is nested inside `Buffer<Element: ~Copyable>`, a generic enum.
Attempting to declare `Buffer<Element>.Arena.Protocol` (or `Buffer<Element>.Protocol`)
produces:

```
error: protocol 'Protocol' cannot be nested in a generic context
```

This research investigates whether a compiler feature flag, experimental mode, or
alternative mechanism exists to lift this restriction.

**Trigger**: Implementation of `Buffer.Arena.Protocol` blocked by language limitation.

**Constraints**:
- Swift 6.2 nightly toolchains (February 2026)
- Local Swift compiler source at `https://github.com/swiftlang/swift`
- Ecosystem-wide impact: affects all generic namespace types (`Buffer<Element>`,
  `Storage<Element>`, and any future generic namespaces)

## Question

Can protocols be nested inside generic types in Swift, either through an existing
feature flag, experimental compiler mode, or planned language change?

## Analysis

### Option A: Existing Feature Flag

**Investigation**: Exhaustive search of the Swift compiler source.

The SE-0404 implementation (`NestedProtocols`) was an experimental feature flag
during development but has been fully adopted since Swift 5.10. It is no longer
listed in `include/swift/Basic/Features.def`.

The restriction for generic contexts is **hard-coded** with no gating flag:

```cpp
// lib/Sema/TypeCheckDeclPrimary.cpp:3006-3017
// We don't support protocols nested in generic contexts.
// This includes protocols nested in other protocols.
if (isa<ProtocolDecl>(NTD) && DC->isGenericContext()) {
  if (auto *OuterPD = DC->getSelfProtocolDecl())
    NTD->diagnose(diag::unsupported_nested_protocol_in_protocol, NTD,
                  OuterPD);
  else
    NTD->diagnose(diag::unsupported_nested_protocol_in_generic, NTD);

  NTD->setInvalid();
  return;
}
```

The `isGenericContext()` check (DeclContext.cpp:467–479) walks up the declaration
context hierarchy. Any ancestor with `getGenericParams()` returns true. This is
why `Bit.Vector` (non-generic struct) allows nesting but `Buffer<Element>` (generic
enum) does not — `Buffer.Arena` inherits its parent's generic context.

The helper `isUnsupportedNestedProtocol()` (DeclContext.cpp:1812) is a one-liner:

```cpp
bool DeclContext::isUnsupportedNestedProtocol() const {
  return isa<ProtocolDecl>(this) && getParent()->isGenericContext();
}
```

**Conclusion**: No feature flag exists. The restriction is unconditional.

### Option B: SE-0404 Future Directions

SE-0404 explicitly defers generic contexts to future work:

> "Allow nesting protocols in generic types — As mentioned in the Detailed Design
> section, there are potentially strategies that would allow nesting protocols within
> generic types, and one could certainly imagine ways to use that expressive capability.
> The community is invited to discuss potential approaches in a separate topic."

The proposal identifies two strategies:

#### B1: Generic Protocols

If `Container<T>` contains `protocol Element`, then `Container<Int>.Element` and
`Container<String>.Element` would be **distinct protocols**. This is effectively
"generic protocols."

The Generics Manifesto (`swift/docs/GenericsManifesto.md`) categorizes "Generic
protocols" as **"Unlikely"**. The fundamental problem: Swift's type system enforces
exactly one type witness per associated type within a conforming type. Generic
protocols would require a conforming type to potentially provide different witnesses
for different specializations of the same protocol — breaking this invariant.

#### B2: Mapping Generic Parameters to Associated Types

The outer type's generic parameters would be automatically translated into associated
types on the inner protocol. So:

```swift
struct Container<Element> {
    protocol Storage {
        func store(_ item: Element) // Element becomes an associatedtype
    }
}
```

would desugar to:

```swift
protocol Container_Storage {
    associatedtype Element
    func store(_ item: Element)
}
```

This is more tractable but requires significant compiler work: name mangling,
existential type identity, the relationship between the nested protocol's identity
and its enclosing type's generic arguments, and how conformances interact with
specialization.

**Status as of February 2026**: No formal pitch or proposal has been filed for
either approach. The SE-0404 acceptance announcement noted: "Several reviewers hoped
protocols nested in generic contexts are explored in the future, and nothing in this
proposal precludes that direction." (Holly Borla, Review Manager, August 2023)

### Option C: Compiler Source Modification

A local compiler fork could comment out the check at TypeCheckDeclPrimary.cpp:3008.
However, this would immediately expose the deeper issue: the compiler has no
infrastructure to represent a protocol that depends on enclosing generic parameters.
Type resolution, witness tables, conformance checking, and mangling all assume
protocols are not parameterized. This is not a simple "remove the guard" fix.

### Option D: Workarounds Within Current Swift

#### D1: Non-Generic Namespace Enum

Introduce a non-generic namespace between the generic parent and the protocol:

```swift
// Instead of Buffer<Element>.Arena.Protocol (forbidden):
enum ArenaProtocols {
    protocol Arena {
        associatedtype Element
        // ...
    }
}
```

**Problem**: Violates [API-NAME-001] (namespace structure). The protocol is no longer
discoverable at `Buffer.Arena.Protocol`.

#### D2: Top-Level Protocol with Explicit Associated Types

```swift
protocol __BufferArenaProtocol {
    associatedtype Element: ~Copyable
    var header: Buffer<Element>.Arena.Header { get }
    // ...
}

extension Buffer.Arena: __BufferArenaProtocol {}
```

**Problem**: Uses a double-underscore top-level name to avoid namespace pollution.
Cannot use the `Nest.Name` pattern. This is the Swift standard library's approach
(`Sequence`, `Collection`, etc. are all top-level).

#### D3: Protocol at the Non-Generic Ancestor Level

Place the protocol inside a non-generic ancestor if one exists:

```swift
enum Buffer<Element: ~Copyable> { ... }

// Not possible — Buffer itself IS the generic type.
// There is no non-generic ancestor to nest in.
```

**Problem**: `Buffer<Element>` is the root namespace. There is no non-generic parent.

#### D4: Parallel Non-Generic Enum Namespace

```swift
extension Buffer {
    enum Protocols {
        protocol Arena: ~Copyable { ... }
    }
}
```

This achieves `Buffer.Protocols.Arena` — close but not `Buffer.Arena.Protocol`.

**Problem**: Still violates ideal naming. Adds an intermediate namespace layer.

## Prior Art Survey

### Swift Evolution

| Source | Status | Relevance |
|--------|--------|-----------|
| [SE-0404](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0404-nested-protocols.md) (2023) | Accepted, Swift 5.10 | Allows non-generic contexts only |
| [Pitch: Nested Types in Protocols](https://forums.swift.org/t/4291) (2016) | Superseded by SE-0404 | First discussion; Slava Pestov identified generic context challenge |
| [Ease Restrictions on Protocol Nesting](https://forums.swift.org/t/5101) (2017) | Deferred | Karl Wagner's full draft; established "no captures" phased approach |
| [Generic Protocols Discussion](https://forums.swift.org/t/71770) (2024) | Discussion | Slava Pestov on why generic protocols are hard |
| [Generics Manifesto](https://github.com/apple/swift/blob/main/docs/GenericsManifesto.md) | Canonical | "Generic protocols" listed under "Unlikely" |
| [SE-0427: Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md) | Accepted | Relevant: `~Copyable` generics make this gap more visible |

### Related Languages

| Language | Nested Trait/Protocol in Generic Type | Mechanism |
|----------|--------------------------------------|-----------|
| Rust | **Yes** — traits can be defined inside `impl<T>` blocks (rare but legal) | Traits are monomorphized; no witness table sharing needed |
| Haskell | **N/A** — type classes are always top-level | Type classes have no nesting concept |
| OCaml | **Yes** — module types (signatures) can be nested inside functors | Functors are the generic mechanism; signatures are first-class |
| C++ | **Yes** — nested classes/concepts inside templates are fundamental | Templates are syntactic; no semantic protocol/witness system |
| Scala | **Yes** — traits inside generic classes create path-dependent types | `Container[Int]#Trait ≠ Container[String]#Trait` — explicitly supported |

Swift's restriction is **unusual** among languages that support both generics and
protocol-like abstractions. The key difference: Swift's protocol conformance model
requires global coherence (one witness table per conformance), which is harder to
maintain when the protocol itself is parameterized.

### Theoretical Grounding

The generic context restriction reflects a tension between two type-theoretic properties:

1. **Nominal identity**: In Swift, `P` is a unique protocol with a globally unique
   identity. Conformances are resolved at compile time against this identity.

2. **Parametric polymorphism**: Generic types create families of types (`Buffer<Int>`,
   `Buffer<String>`, etc.). Nesting a protocol inside a generic type would create
   families of protocols.

For approach B1 (generic protocols), the typing rule would be:

```
Γ ⊢ T : Type    Γ ⊢ Container<T>.P : Protocol
─────────────────────────────────────────────────
Γ ⊢ (S : Container<T>.P) ⟹ witness(S, Container<T>.P)
```

This requires the witness table to be indexed by both the conforming type *and*
the enclosing type's generic arguments — a **dependent** witness table. Swift's
current runtime does not support this.

For approach B2 (parameter-to-associated-type mapping), the desugaring is:

```
Container<T> { protocol P { f(x: T) } }
    ⟹
protocol Container_P { associatedtype T; f(x: T) }
```

This is sound but introduces a naming and identity question: is `Container_P` the
same protocol regardless of what `Container<X>` it came from? If yes, it's really
a top-level protocol with sugar. If no, we're back to generic protocols.

## Outcome

**Status**: DECISION

### Finding

**No feature flag, experimental mode, or planned language change currently enables
nesting protocols inside generic types in Swift.** The restriction is hard-coded in
the compiler with no bypass mechanism. The `NestedProtocols` feature flag from
SE-0404's development phase only covered non-generic contexts and has been absorbed
into the language since Swift 5.10.

### Recommendation for Buffer.Arena

Use **workaround D2** (top-level protocol with explicit associated types) as the
pragmatic solution:

```swift
/// Protocol for arena buffer variants.
///
/// Conformers: `Buffer.Arena`, `Buffer.Arena.Bounded`,
///             `Buffer.Arena.Inline`, `Buffer.Arena.Small`.
public protocol __BufferArenaProtocol<Element>: ~Copyable {
    associatedtype Element: ~Copyable
    // ... shared requirements
}
```

This matches the Swift standard library's established pattern (`Sequence`,
`Collection`, `IteratorProtocol` are all top-level despite being logically
scoped to their domain).

### Why This Works vs Bit.Vector.Protocol

| Aspect | `Bit.Vector` | `Buffer<Element>` |
|--------|-------------|-------------------|
| Generic? | No — concrete struct | Yes — `enum Buffer<Element: ~Copyable>` |
| Nesting allowed? | Yes (SE-0404) | No (generic context) |
| `isGenericContext()` | `false` | `true` (walks up to `Buffer<Element>`) |

The `Bit.Vector.Protocol` pattern works precisely because `Bit` and `Bit.Vector`
are both concrete, non-generic types. The pattern is inherently limited to
non-generic namespaces.

### Ecosystem Impact

Any future namespace type that needs to be generic (e.g., `Storage<Element>`,
`Buffer<Element>`) cannot use the nested protocol pattern. This is a permanent
constraint until Swift gains either generic protocols or parameter-to-associated-type
mapping — neither of which has a proposal in progress.

### Monitoring

- Watch Swift Forums for any pitch extending SE-0404 to generic contexts
- Watch `swiftlang/swift` for changes to `TypeCheckDeclPrimary.cpp:3006-3017`
- Track Generics Manifesto updates regarding "Generic protocols" status

## Compiler Source References

| File | Line(s) | Content |
|------|---------|---------|
| `include/swift/AST/DiagnosticsSema.def` | 2607–2612 | Diagnostic definitions |
| `lib/Sema/TypeCheckDeclPrimary.cpp` | 3006–3017 | Enforcement logic |
| `lib/AST/DeclContext.cpp` | 467–479 | `isGenericContext()` implementation |
| `lib/AST/DeclContext.cpp` | 1812–1814 | `isUnsupportedNestedProtocol()` |
| `lib/Sema/TypeCheckType.cpp` | 559–564 | Type resolution special-case |
| `include/swift/Basic/Features.def` | — | No `NestedProtocol` flag present |

## References

- Wagner, K. (2023). SE-0404: Allow Protocols to be Nested in Non-Generic Contexts. Swift Evolution.
- Wagner, K. (2016). "Nested Types in Protocols and Nesting Protocols in Types." Swift Forums.
- Wagner, K. (2017). "Ease Restrictions on Protocol Nesting." Swift Forums.
- Pestov, S. (2023). PR #69201: SE-0404 implementation. swiftlang/swift.
- Lattner, C. et al. Generics Manifesto. swiftlang/swift/docs/GenericsManifesto.md.
- Borla, H. (2023). "SE-0404 Acceptance." Swift Forums.
