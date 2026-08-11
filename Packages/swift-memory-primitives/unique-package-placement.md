# Unique Package Placement

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
tier: 3
---
-->

## Context

During extraction of `Pointer<T>.Owner` to top-level `Unique<T>`, a foundational question arose: **Where does `Unique` belong in the ecosystem?**

Currently, `Unique` lives in `swift-pointer-primitives`. But introducing a new top-level name typically warrants its own package per [PRIM-ORG-001]. This research investigates whether `Unique` belongs:
1. Nested under `Pointer` as `Pointer.Unique`
2. In `swift-reference-primitives` as `Reference.Unique`
3. As top-level `Unique` in `swift-pointer-primitives`
4. In a new `swift-ownership-primitives` package

**Trigger**: PR discussion on `Unique<T>` extraction
**Constraints**: Must respect tier hierarchy, semantic coherence, and ecosystem conventions

## Question

What is the correct semantic domain and package placement for `Unique<T>`?

---

## Prior Art Survey

### Rust

| Type | Domain | Package/Crate |
|------|--------|---------------|
| `Box<T>` | Unique ownership | `std::boxed` (separate module) |
| `Rc<T>` / `Arc<T>` | Shared ownership | `std::rc` / `std::sync` |
| `*const T` / `*mut T` | Raw pointers | `core::ptr` |

Rust separates unique ownership (`Box`) from shared ownership (`Rc`/`Arc`) and raw pointers (`*T`). `Box` is in its own module, not grouped with pointers.

### C++

| Type | Domain | Header |
|------|--------|--------|
| `unique_ptr<T>` | Unique ownership | `<memory>` |
| `shared_ptr<T>` | Shared ownership | `<memory>` |
| Raw pointers | Memory access | (builtin) |

C++ groups all smart pointers in `<memory>`, but the types have distinct semantics. `unique_ptr` and `shared_ptr` answer different ownership questions.

### Haskell

| Type | Domain | Module |
|------|--------|--------|
| `IORef` | Mutable reference | `Data.IORef` |
| `STRef` | Scoped mutable reference | `Control.Monad.ST` |
| `Ptr` | Foreign pointer | `Foreign.Ptr` |

Haskell separates mutable references from foreign pointers. Linear Haskell adds `Ur` (unrestricted/unique) as a distinct concept.

### Swift Standard Library

| Type | Domain | Module |
|------|--------|--------|
| `UnsafePointer<T>` | Raw memory access | Swift (builtin) |
| `ManagedBuffer` | Owned buffer | Swift (builtin) |
| No `Box<T>` equivalent | — | — |

Swift lacks a first-class unique ownership box. `ManagedBuffer` is the closest, but it's for buffer management, not general ownership.

### Academic Literature

Linear type systems (Wadler 1990, Walker 2005) distinguish:
- **Linear**: Used exactly once
- **Affine**: Used at most once (our `~Copyable`)
- **Unrestricted**: Used any number of times

Unique ownership (`Box`, `unique_ptr`, our `Unique`) corresponds to **affine ownership** of a heap location. This is orthogonal to:
- Memory addressing (pointers)
- Sharing (reference counting)

---

## Theoretical Grounding

### Semantic Domain Analysis

Per [PRIM-SCOPE-001], a semantic domain is defined by:
1. The conceptual question its types answer
2. The algebra they admit
3. The dependency set they require

#### Pointer Domain

**Question**: "What memory location does this access?"

**Types**: `Pointer<T>`, `Pointer<T>.Mutable`, `Pointer<T>.Buffer`

**Algebra**:
- Dereference: `ptr.pointee → T`
- Arithmetic: `ptr.advanced(by:) → Pointer<T>`
- Null-safety: Non-null invariant

**Dependencies**: Memory primitives (untyped addresses)

#### Reference Domain

**Question**: "How do I share access to a value?"

**Types**: `Reference.Box`, `Reference.Indirect`, `Reference.Weak`, `Reference.Unowned`

**Algebra**:
- Sharing: Multiple references to same storage
- Lifetime: Strong/weak/unowned reference relationships
- Mutability: Immutable (`Box`) vs mutable (`Indirect`)

**Dependencies**: None (Tier 0)

#### Proposed Ownership Domain

**Question**: "Who owns this value?"

**Types**: `Unique<T>` (unique), potentially `Shared<T>` as alias for `Reference.Box`

**Algebra**:
- Exclusive ownership: Only one owner
- Transfer: `take() → T` consumes ownership
- Deterministic cleanup: `deinit` runs exactly once
- Borrowing: `withValue`, `withMutableValue`

**Dependencies**: Pointer primitives (for implementation), but semantically independent

### Formal Typing Rules

```
Γ ⊢ v : T
─────────────────────────── (Unique-Intro)
Γ ⊢ Unique(v) : Unique<T>

Γ ⊢ u : Unique<T>
─────────────────────────── (Unique-Take)
Γ ⊢ u.take() : T, u consumed

Γ ⊢ u : Unique<T>    Γ, x : borrowing T ⊢ e : R
─────────────────────────────────────────────── (Unique-Borrow)
Γ ⊢ u.withValue { x in e } : R
```

The key property: `Unique<T>` enforces **affine** usage of heap storage. The value can be borrowed multiple times but consumed (via `take()` or `deinit`) exactly once.

This is fundamentally different from:
- **Pointers**: No ownership, just memory access
- **References**: Shared ownership via reference counting

---

## Analysis

### Option A: `Pointer.Unique`

**Description**: Keep `Unique` as `Pointer<T>.Unique` (nested typealias or struct).

**Advantages**:
- No package changes needed
- Implementation uses pointers internally

**Disadvantages**:
- Semantically incorrect: `Unique` is not "a kind of pointer"
- Violates semantic domain coherence: Pointer answers "where", Unique answers "who owns"
- Confuses users: Is this a pointer type or an ownership type?

**Verdict**: ❌ Rejected. Semantic mismatch too severe.

### Option B: `Reference.Unique`

**Description**: Place `Unique` in `swift-reference-primitives` as `Reference.Unique`.

**Advantages**:
- Both are heap-allocated value wrappers
- Joins the Reference type family

**Disadvantages**:
- Reference domain is about **sharing** — `Box`, `Indirect`, `Weak` all involve shared access
- `Unique` is about **not sharing** — exclusive ownership
- Would require pointer-primitives dependency in reference-primitives (currently Tier 0)
- Muddies the Reference taxonomy

**Verdict**: ❌ Rejected. Reference is the sharing domain; Unique is the non-sharing domain.

### Option C: Top-level `Unique` in `swift-pointer-primitives`

**Description**: Keep `Unique<T>` as a top-level type in `swift-pointer-primitives`.

**Advantages**:
- Already implemented
- Pragmatic — keeps implementation details together
- No new packages

**Disadvantages**:
- `swift-pointer-primitives` becomes semantically incoherent
- Package name doesn't describe its contents accurately
- Violates [PRIM-SCOPE-002]: "Can you describe the package's purpose in one sentence without using 'and'?"
  - Before: "Typed pointer primitives"
  - After: "Typed pointer primitives and unique ownership boxes" ❌

**Verdict**: ⚠️ Acceptable short-term, problematic long-term.

### Option D: New `swift-ownership-primitives` Package

**Description**: Create `swift-ownership-primitives` containing `Ownership.Unique`.

**Advantages**:
- Semantically pure: Ownership is a coherent domain
- Extensible: Could later add `Ownership.Shared` (alias to Reference.Box), `Ownership.Borrowed`, etc.
- Follows [PRIM-ORG-005]: "Is this a semantic subdomain?"—Yes, ownership is a real concept
- Clear package name describes contents

**Disadvantages**:
- Package proliferation
- Very small package (one type initially)
- Adds dependency complexity

**Tier Analysis**:
- `Unique` needs `Pointer.Mutable` for implementation
- `Pointer` is not Tier 0; pointer-primitives depends on memory-primitives, identity-primitives, index-primitives
- Therefore `swift-ownership-primitives` would be Tier 1+ (depends on pointer-primitives)

**Verdict**: ✓ Semantically correct, but may be over-engineering for one type.

### Option E: Top-level `Unique` in New `swift-unique-primitives` Package

**Description**: Create minimal `swift-unique-primitives` with just `Unique<T>`.

**Advantages**:
- Follows pattern of single-concept packages (like `swift-tagged-primitives`)
- Clear, focused package
- No namespace (`Ownership.Unique`), just `Unique`

**Disadvantages**:
- Very small package
- If we later add more ownership types, might need restructuring

**Tier Analysis**: Same as Option D — depends on pointer-primitives.

**Verdict**: ✓ Viable alternative to Option D.

---

## Comparison

| Criterion | A: Pointer.Unique | B: Reference.Unique | C: Unique in pointer | D: Ownership pkg | E: Unique pkg |
|-----------|-------------------|---------------------|----------------------|------------------|---------------|
| Semantic correctness | ❌ | ❌ | ⚠️ | ✓ | ✓ |
| Package coherence | ✓ | ❌ | ❌ | ✓ | ✓ |
| Minimal disruption | ✓ | ❌ | ✓ | ❌ | ❌ |
| Future extensibility | ❌ | ❌ | ❌ | ✓ | ⚠️ |
| Naming clarity | ❌ | ⚠️ | ✓ | ✓ | ✓ |
| Package proliferation | ✓ | ✓ | ✓ | ❌ | ❌ |

---

## Constraints

1. **Dependency Direction** [ARCH-DEP-001]: `Unique` implementation uses `Pointer.Mutable`, so any package containing `Unique` must depend on `pointer-primitives` or lower.

2. **Tier Hierarchy** [PRIM-ARCH-002]: Cannot create lateral dependencies. If `Unique` moves to a new package, it must be at a tier ≥ pointer-primitives' tier.

3. **Semantic Coherence** [PRIM-SCOPE-002]: Package contents must answer the same conceptual question.

4. **Relocation Principle** [PRIM-ORG-001]: Primitives migrate toward their semantic home as understanding deepens.

---

## Synthesis

The analysis reveals a tension between:
- **Semantic purity**: `Unique` is not a pointer, not a shared reference — it's unique ownership
- **Pragmatism**: Creating a new package for one type may be over-engineering

**Key insight from [PRIM-ORG-005]**: "Is this a semantic subdomain, or am I just avoiding a dependency?"

Ownership IS a semantic subdomain. It answers "who owns this value?" — a question distinct from "what address?" (Pointer) and "how is this shared?" (Reference).

However, [PRIM-SCOPE-002] also says: "Removing any type would leave a semantic gap." A package with one type feels incomplete.

**Resolution path**:

The Rust ecosystem demonstrates that ownership types form a coherent domain (`Box`, `Rc`, `Arc` could all live under "ownership"). Our `Reference.Box` and `Reference.Indirect` are effectively shared ownership types.

A unified taxonomy could be:
- `Ownership.Unique` — exclusive ownership (current `Unique`)
- `Ownership.Shared` — shared immutable ownership (alias to `Reference.Box`)
- `Ownership.Mutable` — shared mutable ownership (alias to `Reference.Indirect`)

But this would require significant restructuring.

---

## Recommendation (Pending User Input)

**Short-term**: Keep `Unique` as top-level in `swift-pointer-primitives` (Option C). Document the semantic debt.

**Long-term consideration**: When we have more ownership-related types, consider:
1. Creating `swift-ownership-primitives` with unified ownership taxonomy
2. Or accepting that `pointer-primitives` is really "memory-ownership-primitives"

**Question for user**:
1. Is the one-type package (`swift-unique-primitives`) acceptable?
2. Should we plan for an `Ownership` namespace even if it only has one type initially?
3. Or is the pragmatic "keep it in pointer-primitives" acceptable given the semantic debt?

---

## References

- Wadler, P. (1990). "Linear types can change the world!"
- Walker, D. (2005). "Substructural Type Systems" in *Advanced Topics in Types and Programming Languages*
- Rust Reference: `std::boxed::Box`
- C++ Reference: `std::unique_ptr`
- [PRIM-ORG-001] Relocation Principle
- [PRIM-ORG-005] Factor the Law, Not the Module
- [PRIM-SCOPE-001] Domain Identification
- [PRIM-SCOPE-002] Semantic Coherence Test

### Deferral

**Date**: 2026-03-15

**Reason**: The document reached a preliminary recommendation (Option C short-term: keep `Unique` in pointer-primitives) but awaits user input on three open questions about package placement strategy. Meanwhile, pointer-primitives was deprecated -- storage-primitives now uses stdlib pointer types directly. This deprecation invalidates the dependency analysis (Options A, C, D, E all assumed pointer-primitives as the implementation substrate). The placement question must be revisited in the context of the post-deprecation architecture.

**Resume when**: The ownership type taxonomy is revisited, or when additional ownership-related types (beyond `Unique`) emerge that would justify a dedicated package.
