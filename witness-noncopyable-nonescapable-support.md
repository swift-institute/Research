# Witness ~Copyable and ~Escapable Support

<!--
---
version: 2.0.0
last_updated: 2026-02-24
status: RECOMMENDATION
tier: 3
changelog:
  - v2.0.0 (2026-02-24): Corrected three misidentified blockers. TaskLocal is NOT a blocker
    (stores class-ref chain, not ~Copyable value directly). SuppressedAssociatedTypes and
    Lifetimes experimental features are already enabled. Ownership.Shared already supports
    ~Copyable. Added Option E (additive closure-based API). Revised recommendation from
    "do not pursue" to "feasible but not yet justified."
  - v1.0.0 (2026-02-24): Initial analysis. Overstated compiler blockers.
---
-->

## Context

An audit of `swift-witnesses` (Layer 3) confirmed that all data structures use stdlib containers with `Copyable & Sendable` constraints, and that `Witness.Key`'s associated type `Value` inherits an implicit `Copyable` requirement via `Sendable`. The only `~Copyable` type in the package is `Witness.Scope`, which enforces linear usage of captured context — it does not store or vend `~Copyable` witness values.

The question arises: should the witness DI framework be extended to support `~Copyable` and/or `~Escapable` witness values?

## Question

Should `swift-witnesses` pursue `~Copyable` and/or `~Escapable` support for witness values (the `Value` associated type of `Witness.Key`), and if so, at what scope and timeline?

## Systematic Literature Review

### Research Questions

| ID | Question |
|----|----------|
| RQ1 | How do languages with substructural type systems handle dependency injection for move-only/linear types? |
| RQ2 | What are the theoretical constraints on sharing substructural values through environment-passing? |
| RQ3 | What is the current compiler support status for `~Copyable` and `~Escapable` in Swift's DI-relevant features? |
| RQ4 | What would a `~Copyable`-aware witness framework require, and at what cost? |

### Search Strategy

- **Swift Evolution**: All proposals mentioning `Copyable`, `Escapable`, `noncopyable`, `nonescapable` (SE-0390, SE-0427, SE-0432, SE-0437, SE-0446, SE-0499)
- **Swift Forums**: Pitches for suppressed associated types, `~Copyable` existential bugs, `TaskLocal` constraints
- **Rust ecosystem**: DI crates (`shaku`, `coi`, `dilib`, `runtime_injector`) and their handling of non-Clone types
- **Haskell**: Linear Haskell (`-XLinearTypes`), `linear-base`, `dep-t` (dependency monad transformer), `Ur`/`Dupable` semantics
- **OCaml**: Jane Street's OxCaml modal type system (`local_`, `unique_`, `once_`), ICFP 2024
- **Academic**: Substructural type systems (Walker 2004), ownership types (Clarke et al. 2013), capability-passing (Brachthäuser et al. 2020), linear types in practice (Bernardy et al. 2017)
- **Inclusion criteria**: Must address interaction between (a) substructural/ownership types and (b) dependency resolution, environment passing, or service location
- **Exclusion criteria**: Pure ownership-for-memory-safety without DI/environment implications

### Screening Results

52 sources identified, 31 included after screening. Sources span 2003–2026.

## Prior Art Survey

### Rust: Arc-Wrapping as Universal Pattern

Every Rust DI framework resolves the tension between ownership and sharing identically: wrap services in `Arc<dyn Trait>`. The `Arc` (atomic reference count) is `Clone` even when `T` is not, so the container can distribute shared references to non-Clone services.

| Crate | Erasure mechanism | Non-Clone support |
|-------|-------------------|-------------------|
| shaku | `Arc<dyn Interface>` | Yes, via Arc |
| coi | `Arc<dyn Trait>` | Yes, via Arc |
| dilib | `Arc<T>` singletons | Yes, via Arc |
| runtime_injector | `Arc<T>` default | Yes, via Arc |

No Rust DI framework attempts to store or inject truly move-only values directly. The community consensus: DI inherently requires sharing; sharing requires reference counting. Move-only types are wrapped before entering the container [Merino 2022, Bryan 2024].

This mirrors `swift-witnesses`' existing design: `Ownership.Shared<K.Value>` boxes values into reference-counted storage, and `UnsafeRawPointer` erases the concrete type. The `Shared` wrapper is Swift's equivalent of Rust's `Arc`.

### Haskell: Linear Reader Requires Dupable

The Reader monad (the standard Haskell DI mechanism) has type `Reader r a = r -> a`. In Linear Haskell, function arrows carry multiplicity: `Reader r a = r %1-> a` would require the environment `r` to be used exactly once — clearly wrong for DI, where the environment is read many times.

The `linear-base` library resolves this by requiring `Dupable r` for the linear Reader [Tweag 2021]. `Dupable` is the linear-types equivalent of `Copyable` — it permits structural contraction (using a value more than once). The `Ur a` wrapper (Unrestricted) promotes any value to unrestricted use: `Ur a %1-> b` is equivalent to `a -> b`.

The `dep-t` library (dependency transformer for Haskell) similarly requires its environment to be duplicable [dep-t 2022].

**Key insight**: Linear Haskell's answer to "linear types + DI" is that environments are inherently non-linear. Only the *resources acquired through them* should have linear discipline.

### OCaml: Modes Are About Resources, Not Environments

Jane Street's OxCaml introduces three modal axes — locality (`local`/`global`), uniqueness (`unique`/`shared`), and linearity (`once`/`many`) [Lorenzen et al. 2024]. Modes are fully inferred and backwards-compatible.

In OxCaml's functional style, environment records are naturally `shared many` (freely copyable, freely reusable). Modes become relevant when a service holds unique mutable state — then it would be `unique` or `exclusive`, preventing concurrent mutation. But the *reference to the service* in the environment remains shared.

### Capability-Passing: Second-Class Dependencies

Brachthäuser et al. (2020) formalize capability-passing style where capabilities (runtime tokens authorizing effects) are second-class values — they cannot escape their scope. This is the programming-language-theory formalization of scoped DI. The Effekt language implements this with intersection types and path-dependent types.

**Connection to `~Escapable`**: Second-class capabilities correspond to `~Escapable` dependencies in Swift. A `~Escapable` service reference guarantees the dependency cannot leak outside its intended scope — exactly what scoped DI containers enforce at runtime today.

## Theoretical Grounding

### Substructural Type Systems and Environment Passing

In the substructural type system taxonomy [Walker 2004]:

| System | Weakening (discard) | Contraction (duplicate) | Exchange (reorder) |
|--------|---------------------|------------------------|--------------------|
| Linear | No | No | Yes |
| Affine | Yes | No | Yes |
| Relevant | No | Yes | Yes |
| Ordered | No | No | No |
| Unrestricted | Yes | Yes | Yes |

Swift's `~Copyable` corresponds to **affine** typing: values can be discarded (via `deinit`) but not duplicated. `Copyable` is **unrestricted**.

Environment passing (the Reader pattern, TaskLocal propagation, DI) fundamentally requires **contraction** for owned access — the same environment is accessed by multiple consumers, each receiving an independent copy. This is a structural rule that affine and linear systems explicitly forbid.

However, **borrowed access does not require contraction**. Multiple consumers can simultaneously borrow from the same heap-allocated value (read-only access to `let value` in a reference-counted wrapper). This is not structural duplication — it is a view.

**Theorem** (informal): A type-erased heterogeneous container that supports lookup-by-key requires contraction on its element type for *owned* access (lookup returns a value while the container retains it). For *borrowed* access, the container can provide scoped borrows via closure-based APIs without contraction, provided the borrow does not outlive the container entry.

**Corollary**: A DI container can store `~Copyable` values in reference-counted wrappers (`Ownership.Shared`, Rust's `Arc`) and provide borrowed access to multiple consumers simultaneously, without violating affine constraints. The wrapper itself is `Copyable` (reference counting); the wrapped value is not.

### Formal Typing Rules

The current `Witness.Key` protocol has the effective typing:

```
Key : {
  Value : Copyable & Sendable
  liveValue : Value
  testValue : Value
  previewValue : Value
}
```

To support `~Copyable` values, the lookup operation changes:

```
Current (copying):
  lookup : (Key.Type, Mode) -> Key.Value           -- returns owned copy

Hypothetical (borrowing):
  lookup : (Key.Type, Mode) -> borrowing Key.Value  -- returns borrow
```

The borrowing variant has two possible expressions in Swift:

**Option 1: `@lifetime` annotation (experimental)**
```swift
func value<K: Witness.Key>(for key: K.Type, mode: Mode) -> @lifetime(self) K.Value
  where K.Value: ~Copyable & ~Escapable
```

**Option 2: Closure-scoped borrowing (no experimental features needed)**
```swift
func withValue<K: Witness.Key, R>(
    for key: K.Type,
    mode: Mode,
    _ body: (borrowing K.Value) -> R
) -> R
```

Option 2 is the `withUnsafeBufferPointer` pattern — the borrow is scoped to the closure, no lifetime annotations required.

### TaskLocal Propagation Is Not a Blocker

~~The TaskLocal propagation model (copy-on-fork) appears incompatible with `~Copyable` values.~~ **Corrected**: The `~Copyable` value never touches TaskLocal directly. The propagation chain is:

```
TaskLocal<Context>           -- Context: Copyable struct
  → values: Values           -- Values: Copyable struct (contains class ref)
    → _storage: _Storage     -- _Storage: class (reference, Copyable)
      → dict: [OID: Ptr]     -- Dictionary of pointers (Copyable)
        → Ownership.Shared   -- Shared: class (reference, Copyable)
          → let value: T     -- T: ~Copyable lives HERE (behind heap allocation)
```

TaskLocal copies `Context`, which copies the class reference to `_Storage`. The `~Copyable` value is behind a heap allocation and never moves. Multiple child tasks share the same `Ownership.Shared` instance via its reference count. This is structurally identical to Rust's `Arc<T>` pattern.

### The Bifurcation Theorem

There exists a fundamental bifurcation in DI value flow:

1. **Service references** (the DI container's domain): must be shared, duplicated across consumers, propagated to child tasks. Requires `Copyable` (or reference-counted wrapper).

2. **Resources vended by services** (the application's domain): may be unique, move-only, scoped. May be `~Copyable` and/or `~Escapable`.

Every language examined enforces this bifurcation:
- Rust: `Arc<dyn Service>` (copyable reference) → `Connection` (non-Clone resource)
- Haskell: `Ur ServiceHandle` (unrestricted reference) → `Handle` (linear resource)
- OCaml: `shared many` service record → `unique` mutable state
- Swift (proposed): `Copyable` witness struct → `~Copyable` return values

Attempting to collapse this bifurcation — making service references themselves `~Copyable` — contradicts the structural requirements of environment passing.

## Swift Compiler Status Assessment

### What Works (Swift 6.0+)

| Feature | Status | Source |
|---------|--------|--------|
| `~Copyable` structs and enums | Stable | SE-0390 |
| `~Copyable` generics | Stable | SE-0427 |
| `Optional<T: ~Copyable>` | Stable | SE-0437 |
| `Result<S: ~Copyable, F>` | Stable | SE-0437 |
| `~Copyable` protocol conformance | Stable | SE-0427 |
| `Sendable + ~Copyable` | Stable | SE-0390 |
| `consuming`/`borrowing` pattern matching | Stable | SE-0432 |
| `Equatable`/`Hashable` for `~Copyable` | Accepted | SE-0499 |

### What Does Not Work

| Feature | Status | Impact on DI | Source |
|---------|--------|--------------|--------|
| `any P & ~Copyable` existentials | Buggy (borrowing consumes) | Cannot type-erase `~Copyable` services via existential | swift/issues/85275 |
| `@lifetime` annotations (stable) | Experimental only (`Lifetimes` feature flag) | Needed for non-closure borrow returns | SE-0446 |
| `~Escapable` return from collections | Not yet supported | Cannot borrow `~Copyable` values from stdlib Dictionary | — |

### ~~Critical Blockers~~ Reassessed Feasibility (v2.0 correction)

The v1.0 analysis identified 4 "critical blockers." Three were incorrect:

| Claimed Blocker | v2.0 Status | Why |
|-----------------|-------------|-----|
| ~~`associatedtype Value: ~Copyable`~~ | **Available** | `SuppressedAssociatedTypes` + `WithDefaults` experimental features already enabled in `swift-witnesses/Package.swift` |
| ~~`TaskLocal<~Copyable>`~~ | **Not a blocker** | TaskLocal stores `Context` (Copyable struct with class ref). The `~Copyable` value lives behind `Ownership.Shared` on the heap. TaskLocal never touches it. |
| ~~Type-erased storage~~ | **Already works** | `Ownership.Shared<Value: ~Copyable & Sendable>` is already declared in `swift-ownership-primitives`. Pointer-based storage is type-agnostic. |
| `any P & ~Copyable` existentials | **Still buggy** | But not needed — generics work; `swift-witnesses` uses generic `K: Witness.Key`, not existentials. |

**Remaining constraints** (not blockers, design trade-offs):

1. **Access API must change for ~Copyable values**: The subscript getter `subscript[K.self] -> K.Value` returns an owned value, which requires `Copyable`. For `~Copyable` values, a closure-based `withValue(for:body:)` API is needed.
2. **`static var liveValue: Value { get }`**: Returns an owned value. For `~Copyable`, each call constructs a new instance (factory semantics). This is correct but means default values cannot be cached.
3. **`SuppressedAssociatedTypes` behavior**: With the legacy flag, `Value` is ALWAYS `~Copyable` in the type system. The existing subscript must be constrained: `where K.Value: Copyable`. With `SuppressedAssociatedTypesWithDefaults`, inference may default to Copyable per-conformer — exact semantics depend on toolchain version.
4. **All features are experimental**: `SuppressedAssociatedTypes`, `SuppressedAssociatedTypesWithDefaults`, `Lifetimes` are all behind feature flags. API designed around them may break with toolchain updates.

## Analysis

### Option A: Replace Entire API with ~Copyable-First Design

**Description**: Make `Value: ~Copyable` the only mode. Remove the owned-return subscript. All access goes through closure-scoped borrowing.

**Advantages**:
- Uniform API — one access pattern for all values
- Maximum type-safety

**Disadvantages**:
- Breaks all existing call sites (`Witness.Context[K.self]` → `Witness.Context.withValue(K.self) { ... }`)
- Worse ergonomics for the 99% case (Copyable service structs)
- Depends on experimental features for the protocol definition
- No other DI framework in any language uses borrow-only access as the primary API

**Assessment**: **Not justified.** The ergonomic cost for the common case far outweighs the benefit for the rare case. Services in a witness-based DI framework are struct-with-closures — inherently Copyable and Sendable.

### Option B: Pursue ~Escapable Scoped Dependencies

**Description**: Add `~Escapable` variants of scoped witness access, so that borrowed service references cannot escape their `Witness.Context.with` scope.

**Advantages**:
- Genuine safety improvement: compile-time enforcement that scoped overrides don't leak
- Aligns with the capability-passing model (second-class capabilities)
- `Witness.Scope` already enforces linear usage — `~Escapable` would complement this
- Does not require changing the storage model or `Witness.Key` protocol

**Disadvantages**:
- `@lifetime` annotations are still experimental
- `~Escapable` return from functions requires careful lifetime propagation
- Would be an additive API alongside existing `Copyable` access (dual API surface)
- Cognitive overhead: users must understand when to use `~Escapable` vs regular access

**Assessment**: **Promising but premature.** The theoretical fit is strong — scoped DI is precisely the use case for `~Escapable`. But the feature is experimental and the stable API surface is uncertain. Monitor SE-0446 follow-ups and `@lifetime` stabilization.

### Option C: Support ~Copyable Return Values from Copyable Services

**Description**: Keep `Witness.Key.Value: Copyable & Sendable` (service references remain copyable), but allow service methods to return `~Copyable` resources. No changes to `swift-witnesses` needed.

**Advantages**:
- Zero framework changes — already works today
- Matches the bifurcation pattern from every other language
- Services are shared references (correct); resources are unique values (correct)
- Users can already write `struct FileSystem: Witness.Key { func open() -> consuming FileHandle }` where `FileHandle: ~Copyable`

**Disadvantages**:
- Does not provide compile-time uniqueness of the service *reference* itself
- Users who want unique service references must enforce it manually

**Assessment**: **This is the correct design.** It matches the theoretical analysis, the cross-language consensus, and already works with zero changes.

### Option D: Do Nothing, Revisit When Compiler Matures

**Description**: Document the current design as intentional. Revisit when experimental features stabilize.

**Advantages**:
- No work
- Avoids premature commitment to experimental features

**Disadvantages**:
- No documentation of the rationale (resolved by this document existing)

**Assessment**: Acceptable but suboptimal — Option C captures the current design correctly, and Option E is worth prototyping when a concrete use case arises.

### Option E: Additive Closure-Based API for ~Copyable Values (NEW in v2.0)

**Description**: Suppress `Copyable` on `Witness.Key.Value`. Keep the existing subscript for `Copyable` values (add `where K.Value: Copyable` constraint). Add a new closure-based access path for `~Copyable` values. Existing conformers are unaffected.

**Concrete API shape**:

```swift
// Protocol change (requires SuppressedAssociatedTypes):
public protocol __WitnessKeyTest<Value>: Sendable {
    associatedtype Value: ~Copyable & Sendable = Self
    // ... existing requirements unchanged
}

// Existing API (Copyable values — unchanged call sites):
extension Witness.Values {
    public subscript<K: Witness.Key>(key: K.Type) -> K.Value
        where K.Value: Copyable { get set }
}

// New API (~Copyable values — closure-scoped borrowing):
extension Witness.Values {
    public func withValue<K: Witness.Key, R>(
        for key: K.Type,
        mode: Witness.Context.Mode,
        _ body: (borrowing K.Value) -> R
    ) -> R
}

// Convenience on Context:
extension Witness.Context {
    public static func withValue<K: Witness.Key, R>(
        _ key: K.Type,
        _ body: (borrowing K.Value) -> R
    ) -> R
}
```

**Storage**: No changes needed. `Ownership.Shared<Value: ~Copyable & Sendable>` already accepts `~Copyable` values. The `Unmanaged` / `UnsafeRawPointer` erasure is type-agnostic.

**Propagation**: No changes needed. TaskLocal stores `Context` (Copyable struct), which references `_Storage` (class). The `~Copyable` value is behind the heap allocation.

**Advantages**:
- Zero breaking changes — existing `Copyable` API preserved with `where` constraint
- Enables `~Copyable` witness values for consumers who need them
- Matches the Rust `Arc<T>` / Haskell `Ur` pattern: shared reference, borrowed access
- Storage and propagation already work — only the access API is new
- Closure-scoped borrowing needs no `@lifetime` annotations

**Disadvantages**:
- Depends on `SuppressedAssociatedTypes` (experimental)
- `SuppressedAssociatedTypesWithDefaults` semantics may shift across toolchain versions
- Dual API surface: subscript for Copyable, `withValue` for ~Copyable
- `static var liveValue: Value { get }` has factory semantics for ~Copyable (creates new instance each call) — cannot cache default values
- No concrete use case yet: witness values are struct-with-closures (inherently Copyable)

**Assessment**: **Technically feasible, not yet justified.** The infrastructure is ready — `Ownership.Shared`, pointer storage, TaskLocal propagation all work. The API shape is clean. But there is no concrete use case where a witness value itself (as opposed to resources it vends) needs to be `~Copyable`. The typical witness is `struct APIClient: Witness.Protocol { var fetch: @Sendable (Int) async throws(API.Error) -> Response }` — a pure value type. Pursue when a real use case emerges, validate with an experiment first.

### Comparison

| Criterion | A: ~Copyable-First | B: ~Escapable Scoping | C: ~Copyable Returns | D: Do Nothing | E: Additive API |
|-----------|--------------------|-----------------------|----------------------|---------------|-----------------|
| Compiler support | Experimental | Experimental | Works today | N/A | Experimental |
| Theoretical soundness | Sound (borrowed access) | Strong fit | Strong fit | N/A | Sound (borrowed access) |
| Cross-language precedent | No precedent | Capability-passing (Effekt) | Universal pattern | N/A | Rust `Arc<T>` pattern |
| Framework changes | Full rewrite | Additive API | None | None | Additive API |
| Breaking changes | Yes (all call sites) | No | No | No | No |
| Timeline | Now (experimental) | 6-18 months | Now | N/A | When use case emerges |
| User benefit | Marginal (worse ergonomics for 99% case) | Real (scope enforcement) | Real (resource safety) | None | Real (when needed) |
| Concrete use case exists | No | Yes (scoped overrides) | Yes (resource handles) | N/A | No |

## Formal Semantics Summary

### Current System

```
G |- Witness.Context.current[K] : K.Value
  where K : Witness.Key, K.Value : Copyable & Sendable
```

The lookup returns an owned `Copyable` value. Multiple lookups yield independent copies. The TaskLocal propagation rule:

```
G |- TaskLocal.withValue(v, op)
  where v : Copyable & Sendable
  -- child tasks receive a copy of v
```

### With Option C (No Change to Framework)

Service types remain `Copyable`. Return types may be `~Copyable`:

```
G |- service.open(path) : consuming FileHandle
  where FileHandle : ~Copyable
  -- caller takes ownership of the returned handle
```

The framework is not involved in the `~Copyable` flow — it happens at the application layer, which is the correct abstraction boundary.

### With Option E (Additive Closure-Based API)

```
G |- Witness.Context.withValue(K, body)
  where body : (borrowing K.Value) -> R
  -- borrow scoped to closure, no lifetime annotation needed
  -- K.Value : ~Copyable & Sendable
```

The borrow is structurally safe: the `Ownership.Shared` instance is retained for the duration of the closure, the closure receives a borrow of `shared.value`, and the borrow cannot escape because it is a closure parameter (not a return value).

### With Option B (Future, ~Escapable Scoping)

```
G |- Witness.Context.withBorrowed[K] : @lifetime(scope) borrowing K.Value
  where K.Value : ~Escapable
  -- returned reference cannot outlive the with-scope
```

This would require `@lifetime` stability and `~Escapable` protocol support. It adds a borrow-based access path alongside the existing copy-based path.

## Empirical Validation (Cognitive Dimensions)

| Dimension | Option A | Option B | Option C | Option E |
|-----------|----------|----------|----------|----------|
| **Visibility** | Low — new ownership concepts hidden in DI | Medium — scope boundaries become visible | High — existing patterns, nothing new | Medium — new API for new types only |
| **Consistency** | Low — breaks from every other DI framework | Medium — extends existing scoping | High — matches universal DI patterns | High — Copyable API unchanged, additive |
| **Viscosity** | Very high — all call sites change | Medium — additive, opt-in | Zero — no framework changes | Low — only new ~Copyable conformers use new API |
| **Role-expressiveness** | Medium — types express ownership but add noise | Medium — scopes express boundaries | High — simple, familiar | High — subscript for Copyable, closure for ~Copyable |
| **Error-proneness** | High — new ownership errors in DI context | Medium — new concept to learn | Low — existing patterns | Medium — must know which API to use |
| **Abstraction** | Over-abstraction for most services | Right level for scoped resources | Right level for general DI | Right level — additive complexity only where needed |

## Outcome

**Status**: RECOMMENDATION (revised v2.0)

### Primary Recommendation: Option C Now, Option E When Justified

**Today**: The witness framework should continue with `Copyable` witness values. The bifurcation pattern (Copyable service references, `~Copyable` resources returned by services) is the correct default and already works with zero changes.

**When a concrete use case emerges**: Option E (additive closure-based API) is technically feasible. The infrastructure is ready:
- `Ownership.Shared<Value: ~Copyable & Sendable>` — already supports ~Copyable
- Pointer-based type-erased storage — type-agnostic, works today
- TaskLocal propagation — stores class-ref chain, ~Copyable value is behind heap allocation
- `SuppressedAssociatedTypes` + `SuppressedAssociatedTypesWithDefaults` — already enabled
- `Lifetimes` — already enabled

The trigger for Option E is a real use case where a witness value *itself* (not resources it vends) must be `~Copyable`. Until that exists, the additive API is a solution looking for a problem.

### Secondary Recommendation: Monitor ~Escapable for Future Scoping (Option B)

`~Escapable` scoped dependencies remain the most promising future direction. Capability-passing style (second-class capabilities that cannot escape their scope) is the theoretical formalization of what `Witness.Context.with` already enforces at runtime.

**Action**: Track the following:
- `@lifetime` stabilization proposals
- `~Escapable` protocol conformance improvements
- SE-0446 follow-up proposals

### Corrected Understanding (v2.0)

The v1.0 analysis overstated the incompatibility between `~Copyable` and DI:

1. ~~DI environments require contraction (shared access), which ~Copyable forbids.~~ **Corrected**: DI requires *shared read access*, achievable through borrowed access to reference-counted wrappers (`Ownership.Shared`). Contraction applies to owned values, not borrows.

2. ~~TaskLocal is structurally incompatible with ~Copyable.~~ **Corrected**: TaskLocal stores the Copyable class-ref chain. The ~Copyable value lives behind heap allocation and is never copied by TaskLocal.

3. ~~Three compiler features are missing.~~ **Corrected**: All three are either available (experimental features already enabled) or not actually required (TaskLocal).

The revised position: `~Copyable` witness values are *feasible*, but the typical witness value (struct-with-closures) is inherently Copyable, so the feature lacks a concrete justification today.

### What This Means for `Witness.Scope`

`Witness.Scope: ~Copyable` is correctly designed. It uses `~Copyable` for the *scope token* (enforcing exactly-once consumption), not for the *witness values*. The scope token controls *when* values are accessed; the values themselves remain `Copyable` for shared access within that scope. This is the right use of `~Copyable` in a DI context.

## References

### Swift Evolution Proposals

- [SE-0390] Apple Inc. "Noncopyable structs and enums." Swift Evolution, 2023. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md
- [SE-0427] Apple Inc. "Noncopyable Generics." Swift Evolution, 2024. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md
- [SE-0432] Apple Inc. "Borrowing and consuming pattern matching for noncopyable types." Swift Evolution, 2024. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0432-noncopyable-switch.md
- [SE-0437] Apple Inc. "Noncopyable Standard Library Primitives." Swift Evolution, 2024. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md
- [SE-0446] Apple Inc. "Nonescapable Types." Swift Evolution, 2024. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md
- [SE-0499] Apple Inc. "Support ~Copyable, ~Escapable in simple standard library protocols." Swift Evolution, 2025. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md

### Swift Forums

- "Pitch: Suppressed Associated Types With Defaults." Swift Forums, 2025. https://forums.swift.org/t/pitch-suppressed-associated-types-with-defaults/83663
- "Calling borrowing func on existential results in consumption of value." Swift Forums, 2025. https://forums.swift.org/t/calling-borrowing-func-on-existential-results-in-consumption-of-value/84660
- "Copy of noncopyable typed value." Swift Forums, 2025. https://forums.swift.org/t/copy-of-noncopyable-typed-value-bug/84873

### Rust Ecosystem

- Merino, Julio. "Rust traits and dependency injection." 2022. https://jmmv.dev/2022/04/rust-traits-and-dependency-injection.html
- Bryan, Nick. "Using a type map for dependency injection in Rust." 2024. https://nickbryan.co.uk/software/using-a-type-map-for-dependency-injection-in-rust/
- AzureMarker. "Shaku: Compile-time dependency injection for Rust." GitHub. https://github.com/AzureMarker/shaku
- Diamond, M. and Vilim, M. "Rivet: Dependency Injection in Rust." Stanford CS242, 2017. https://stanford-cs242.github.io/f17/assets/projects/2017/diamondm-mvilim.pdf

### Haskell

- Bernardy, J.-P., Boespflug, M., Newton, R., Peyton Jones, S., and Spiwack, A. "Linear Haskell: practical linearity in a higher-order polymorphic language." POPL, 2018. https://arxiv.org/abs/1710.09756
- Tweag. "linear-base: Standard library for Linear Haskell." 2021. https://www.tweag.io/blog/2021-02-10-linear-base/
- "dep-t: Extracting dependencies from the environment." Hackage, 2022. https://hackage.haskell.org/package/dep-t

### OCaml

- Lorenzen, A., Dolan, S., Mayero, R., Rossberg, A., Xia, L., and Yallop, J. "Oxidizing OCaml with Modal Memory Management." ICFP, 2024. https://dl.acm.org/doi/10.1145/3674642
- Jane Street. "Oxidizing OCaml: Rust-Style Ownership." 2023. https://blog.janestreet.com/oxidizing-ocaml-ownership/
- OxCaml. "Modes Introduction." 2025. https://oxcaml.org/documentation/modes/intro/

### Academic

- Walker, David. "Substructural Type Systems." Ch. 1 in Advanced Topics in Types and Programming Languages, MIT Press, 2004.
- Clarke, D., Noble, J., and Wrigstad, T. "Ownership Types: A Survey." Springer LNCS, 2013. https://link.springer.com/chapter/10.1007/978-3-642-36946-9_3
- Brachthäuser, J., Schuster, P., and Ostermann, K. "Effects as Capabilities: Effect Handlers and Lightweight Effect Polymorphism." OOPSLA, 2020. https://dl.acm.org/doi/10.1145/3428194
- Brachthäuser, J., Schuster, P., and Ostermann, K. "Effekt: Capability-Passing Style for Type- and Effect-Safe, Extensible Effect Handlers in Scala." JFP, 2020. https://doi.org/10.1017/S0956796820000064
- Mazurak, K., Zhao, J., and Zdancewic, S. "Lightweight Linear Types in System F-pop." TLDI, 2010. https://www.cis.upenn.edu/~stevez/papers/MZZ10.pdf

### Ecosystem-Internal

- "Protocol Witness Effects Capability Abstraction." swift-institute Research, 2026. `/Users/coen/Developer/swift-institute/Research/protocol-witness-effects-capability-abstraction.md`
